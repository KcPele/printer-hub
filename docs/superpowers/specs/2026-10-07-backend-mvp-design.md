# PrinterHub Backend MVP — Design

**Date:** 2026-10-07
**Status:** Approved
**Source requirements:** `PrinterHub_FRD_v2.0_Mobile_First.md` §6.1, §50, §55.1, §58

## 1. Goal

Build the shared, API-first backend that PrinterHub Mobile and the later Web/PWA both consume. It covers all 20 items of FRD §55.1.

The backend never talks to a printer. Clients execute print and scan operations on the local network and report state. The backend owns identity, tenancy, printer profiles, job state, document metadata, notifications, and audit.

## 2. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Scope | Full §55.1 MVP, built in milestones | Each milestone is tested and runnable on its own |
| Auth | Built-in email + password | No vendor dependency; magic link, passkey, and OAuth can be added behind the same session model |
| Dev infrastructure | Docker Compose on alternate host ports | Reproducible; does not collide with Homebrew Postgres and Redis |
| Version control | Git, Conventional Commits, one commit per milestone | Local only, no remote |
| Architecture | Modular monolith | One deployable; module boundaries keep a later split possible |

## 3. Stack

- Python 3.14, FastAPI, Pydantic v2, pydantic-settings
- SQLAlchemy 2 (async) with asyncpg, Alembic migrations
- PostgreSQL 17, Redis 7, MinIO (S3-compatible) in Docker Compose
- arq for background work, wrapped behind `app/core/tasks.py`
- structlog for JSON logs
- argon2-cffi for password hashing, PyJWT for tokens, cryptography (Fernet) for credential encryption
- boto3 for S3 presigning and object calls
- httpx for outbound HTTP (APNs, FCM)
- uv, ruff, mypy (strict), pytest, pytest-asyncio, pre-commit

## 4. Repository layout

```
printer-hub/
├── CLAUDE.md
├── README.md
├── Makefile
├── docker-compose.yml
├── docs/superpowers/{specs,plans}/
└── backend/
    ├── pyproject.toml
    ├── Dockerfile
    ├── alembic.ini
    ├── migrations/
    ├── openapi.json            # exported contract, checked in
    ├── app/
    │   ├── main.py             # app factory
    │   ├── api.py              # mounts every module router under /api/v1
    │   ├── worker.py           # arq worker settings
    │   ├── core/               # config, db, security, errors, logging, ids,
    │   │                       # pagination, idempotency, permissions, events,
    │   │                       # redis, crypto, ratelimit, tasks
    │   ├── adapters/
    │   │   ├── push/           # base, log, apns, fcm
    │   │   └── storage/        # base, s3, memory
    │   └── modules/
    │       └── <module>/       # router, schemas, models, service
    ├── simulator/              # fake Xerox C7130 (IPP + eSCL)
    ├── scripts/                # export_openapi, seed
    └── tests/
```

`mobile/`, `web/`, and `packages/` join the monorepo later.

## 5. Module design

Each module has the same four files.

| File | Responsibility | May import |
|---|---|---|
| `models.py` | SQLAlchemy tables | `core` |
| `schemas.py` | Pydantic request and response shapes | `core` |
| `service.py` | Business rules, queries, audit writes, event emission | `core`, own `models`, other modules' `service` |
| `router.py` | HTTP mapping only: parse, call service, return schema | `core`, own `service` and `schemas` |

Routers contain no business logic and no queries. Services never import FastAPI.

Modules: `auth`, `users`, `organizations`, `devices`, `printers`, `connections`, `capabilities`, `pairing`, `jobs`, `presets`, `documents`, `notifications`, `audit`, `feature_flags`, `events`, `health`.

## 6. Cross-cutting rules

### 6.1 API conventions

- Base path `/api/v1`. Breaking changes go to `/api/v2`.
- Organization-owned resources are nested: `/api/v1/organizations/{org_id}/printers`.
- Errors use RFC 9457 `application/problem+json` with a stable machine `code` (for example `job.invalid_transition`). Clients map codes to human-readable text (FR-ERR-001).
- Lists use cursor pagination: `?limit=&cursor=` returns `{items, next_cursor}`.
- IDs are UUIDv7, so ordering by ID is ordering by creation time.
- Timestamps are UTC, ISO 8601.
- `backend/openapi.json` is exported from the app and checked in. CI fails when it is stale.

### 6.2 Authentication and sessions

- Passwords hashed with Argon2id.
- Access token: JWT, HS256, 15 minutes, carries `sub` (user ID) and `sid` (session ID).
- Refresh token: opaque random 256-bit value, 30 days, stored as a SHA-256 hash on the session row, rotated on every refresh.
- Reuse of a rotated refresh token revokes the session.
- Each request checks that the session is not revoked, so session revocation (FR-AUTH-004) takes effect immediately.
- Login and registration are rate limited in Redis per IP and per email.

### 6.3 Tenancy and authorization

- Every organization-owned table has `organization_id`.
- A single dependency, `require(Permission.X)`, resolves the caller's membership in the path organization and checks the permission. It returns an `OrgContext` that services use for every query.
- Roles: `owner`, `admin`, `operator`, `user`, `viewer`. The role-to-permission map lives in `app/core/permissions.py`.
- Organization policy lives in `organizations.settings`: `max_copies_per_job`, `color_printing_roles`, `document_storage_mode`, `document_retention_days`. Job and document creation enforce it.
- Platform-level administration (feature flags, capability registry) requires `users.is_superuser`.

### 6.4 Unit of work, events, and side effects

- One database session per request. The session dependency commits on success and rolls back on error.
- Services queue domain events and background tasks on the session. They are published only after the commit succeeds, so a rolled-back request emits nothing.
- Live events go to Redis pub/sub channel `org:{id}:events` and reach clients through an SSE endpoint.

### 6.5 Idempotency

- `POST` endpoints that create jobs or documents accept an `Idempotency-Key` header. Job creation requires it.
- The key, a hash of the request body, and the response are stored in `idempotency_keys` in the same transaction as the created row.
- Same key and same body replays the stored response with `Idempotent-Replayed: true`. Same key and a different body returns `422`.
- A unique constraint on `(user_id, key)` resolves concurrent duplicates.

### 6.6 Security

- Connection credentials are Fernet-encrypted at rest and never returned by the API.
- A log processor redacts values of sensitive keys (`password`, `token`, `authorization`, `secret`, `pin`, `credentials`).
- Document bytes never pass through the API. Clients upload and download through presigned URLs.
- Pairing tokens are single-use, expire in 10 minutes, and are stored hashed.

## 7. Data model

| Table | Key columns |
|---|---|
| `users` | email (unique, lowercased), password_hash, name, preferences, is_active, is_superuser |
| `sessions` | user_id, device_id, refresh_token_hash, previous_refresh_token_hash, user_agent, ip, expires_at, revoked_at, last_used_at |
| `organizations` | name, slug, settings |
| `memberships` | organization_id, user_id, role — unique (organization_id, user_id) |
| `invitations` | organization_id, email, role, token_hash, invited_by, expires_at, accepted_at |
| `devices` | user_id, installation_id, platform, name, model, os_version, app_version, push_provider, push_token, last_seen_at |
| `printers` | organization_id, friendly_name, manufacturer, model, serial_number, location, capabilities, status, status_detail, auto_fallback_enabled, default_connection_id, last_seen_at, deleted_at |
| `connections` | organization_id, printer_id, type, purposes, priority, configuration, encrypted_credentials, health, last_success_at, last_failure_at, last_latency_ms, last_error |
| `capability_profiles` | manufacturer, model_patterns, display_name, capabilities, notes, version |
| `pairing_tokens` | organization_id, printer_id, token_hash, created_by, expires_at, redeemed_at |
| `jobs` | organization_id, user_id, printer_id, device_id, type, execution_mode, status, settings, document_id, output_document_id, connection_id, connection_type, fallback_occurred, retry_of_job_id, printer_job_ref, error_code, error_message, page_count, submitted_at, started_at, completed_at |
| `job_events` | job_id, status, connection_id, detail, occurred_at |
| `idempotency_keys` | user_id, key, request_hash, response_status, response_body, expires_at |
| `presets` | organization_id, owner_user_id, scope, type, name, settings, printer_id, is_default |
| `documents` | organization_id, owner_id, file_name, mime_type, size_bytes, page_count, source, storage_mode, storage_key, upload_status, checksum_sha256, tags, ocr_text, source_printer_id, retention_expires_at, deleted_at |
| `notifications` | user_id, organization_id, type, title, body, data, read_at |
| `audit_logs` | organization_id, actor_user_id, action, target_type, target_id, outcome, detail, ip, user_agent |
| `feature_flags` | key, description, enabled |
| `feature_flag_overrides` | flag_key, organization_id, enabled |

Every table has `id` (UUIDv7), `created_at`, and, where rows change, `updated_at`.

## 8. Normalized capability schema

`PrinterCapabilities` is a versioned Pydantic model stored as JSON on `printers.capabilities`. Sections: `print`, `scan`, `copy`, `status`, `connectivity`, `protocols`.

Two sources feed it:

1. **Probed snapshot.** The client probes the printer and `PUT`s the result. This is the source of truth for enabling features (FRD §6.4).
2. **Registry profile.** `capability_profiles` holds vendor baselines matched by manufacturer and model pattern. It tells clients what to probe for and which features are optional hardware. It ships seeded with the Xerox VersaLink C7100 series profile from FRD §62.

## 9. Job model

One `jobs` table covers print, scan, and copy.

Statuses: `queued`, `processing`, `printing`, `scanning`, `completed`, `failed`, `cancelled`.

Rules:

- Transitions only move forward. `completed`, `failed`, and `cancelled` are terminal.
- A client may skip intermediate states, which supports reporting after an offline period.
- Each transition appends a `job_events` row with the connection used. A connection change after the first attempt sets `fallback_occurred`.
- Retry creates a new job with `retry_of_job_id`. The original stays terminal.
- Clients may supply the job ID, so jobs created offline keep their identity.
- `POST /jobs/batch` accepts jobs with their event history for sync after reconnect. Each item carries its own idempotency key and succeeds or fails on its own.

## 10. Documents and storage

- `storage_mode` is `local` (metadata only, bytes stay on the device) or `cloud`.
- Cloud flow: create metadata, receive a presigned `PUT` URL, upload, call `complete-upload`, which verifies the object exists.
- Download returns a presigned `GET` URL.
- Organization policy `document_storage_mode = local_only` rejects cloud documents.
- A scheduled worker task deletes objects and rows past `retention_expires_at`.
- Encryption at rest is enforced with bucket default encryption.

## 11. Notifications and push

- A notification is an in-app row, a live event, and a push to each of the user's registered devices.
- `PushProvider` has three implementations: `LogPushProvider` (development), `ApnsPushProvider`, `FcmPushProvider`. Configuration selects them.
- Push is sent from the arq worker. Tokens the provider reports as invalid are cleared from the device row.
- Triggers in the MVP: job completed, job failed, scan ready, organization invitation.

## 12. Printer simulator

A separate FastAPI app in `backend/simulator/` that behaves like a Xerox VersaLink C7130 for client development:

- IPP over HTTP: Get-Printer-Attributes, Validate-Job, Print-Job, Get-Job-Attributes, Get-Jobs, Cancel-Job.
- eSCL: ScannerCapabilities, ScannerStatus, ScanJobs, NextDocument.
- Control API to inject faults: offline, paper jam, ADF empty, low toner, eSCL disabled.

It shares no code with `app/`.

## 13. Testing

- Tests run against real Postgres and Redis from Docker Compose, in a separate `printerhub_test` database.
- The schema is built by running Alembic migrations, so migrations are tested.
- Each test runs inside a transaction that is rolled back.
- Storage and push use in-memory fakes. APNs and FCM providers are tested against `httpx.MockTransport`.
- Services and HTTP behavior are tested through the API with `httpx.AsyncClient`.
- CI runs ruff, mypy, pytest, and the OpenAPI staleness check.

## 14. Out of scope for this build

- Magic link, passkey, OAuth, MFA, password reset by email
- Printer groups and per-user printer sharing
- Scan routing rules, workflow templates, cloud storage integrations
- Usage analytics, quotas beyond `max_copies_per_job`
- Gateway and cloud relay coordination
- Document conversion, server-side OCR, thumbnails
- Email delivery

Each is left with a clear extension point and none blocks the mobile MVP.

## 15. Milestones

| # | Milestone | FRD §55.1 items |
|---|---|---|
| M0 | Foundation: repo, tooling, config, DB, errors, logging, health, test harness | 17 |
| M1 | Auth, users, sessions, devices | 1, 2, 4 |
| M2 | Organizations, memberships, invitations, RBAC, audit | 2, 3, 16 |
| M3 | Printers, connections, capability schema and registry, pairing | 5, 6, 7, 19 |
| M4 | Jobs, idempotency, live events, batch sync | 8, 9, 13, 14 |
| M5 | Presets, documents, object storage | 10, 11, 12 |
| M6 | Notifications, push providers, worker, feature flags | 15, 18 |
| M7 | Simulator, OpenAPI export, Docker image, CI, docs | 17, 20 |
