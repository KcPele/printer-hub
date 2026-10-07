# PrinterHub Backend MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared API-first backend covering all 20 items of FRD §55.1.

**Architecture:** A FastAPI modular monolith. Each domain module owns `models`, `schemas`, `service`, and `router`. Shared infrastructure lives in `app/core`. External systems (push, object storage) sit behind adapters with in-memory fakes.

**Tech Stack:** Python 3.14, FastAPI, Pydantic v2, SQLAlchemy 2 async, asyncpg, Alembic, PostgreSQL 17, Redis 7, MinIO, Soketi, arq, structlog, uv, ruff, mypy, pytest.

**Spec:** `docs/superpowers/specs/2026-10-07-backend-mvp-design.md`

## Global Constraints

- Python `>=3.14`. All commands run from `backend/` through `uv run`.
- Base path `/api/v1`. Organization resources nest under `/api/v1/organizations/{org_id}/`.
- Errors are RFC 9457 `application/problem+json` with a stable `code`.
- IDs are UUIDv7 from `app.core.ids.new_id()`.
- Routers hold no business logic and no queries. Services never import FastAPI.
- Every organization-owned query filters by `organization_id` taken from `OrgContext`.
- Secrets never appear in logs or API responses.
- `ruff check`, `ruff format --check`, `mypy`, and `pytest` pass before every commit.
- Host ports: Postgres `5433`, Redis `6380`, MinIO `9000`/`9001`, API `8000`, simulator `8631`. Soketi `6001` only under the optional `realtime` profile.
- FCM is the only push service. Live WebSocket events are optional and may be dropped, so user-facing changes always go out as notifications.
- Commits follow Conventional Commits.

## Shared interfaces

These names are fixed. Every task uses them as written.

```python
# app/core/config.py
class Settings(BaseSettings): ...          # env prefix PRINTERHUB_
def get_settings() -> Settings

# app/core/ids.py
def new_id() -> uuid.UUID                   # UUIDv7

# app/core/db.py
class Base(DeclarativeBase)
class IdMixin                               # id: Mapped[uuid.UUID]
class TimestampMixin                        # created_at, updated_at
async def get_session() -> AsyncIterator[AsyncSession]   # commit, then flush after-commit work
def after_commit(session, callback: Callable[[], Awaitable[None]]) -> None

# app/core/errors.py
class AppError(Exception)                   # status, code, title, detail, errors
class NotFoundError, ConflictError, PermissionDeniedError,
      UnauthorizedError, ValidationFailedError, RateLimitedError
def register_exception_handlers(app: FastAPI) -> None

# app/core/security.py
def hash_password(password: str) -> str
def verify_password(password: str, password_hash: str) -> bool
def create_access_token(user_id: UUID, session_id: UUID) -> tuple[str, int]
def decode_access_token(token: str) -> AccessClaims      # .user_id, .session_id
def generate_token() -> str
def hash_token(token: str) -> str

# app/core/crypto.py
def encrypt_json(data: dict[str, Any]) -> bytes
def decrypt_json(blob: bytes) -> dict[str, Any]

# app/core/pagination.py
class Page[T](BaseModel)                    # items, next_cursor
class PageParams                            # limit, cursor
async def paginate(session, stmt, model, params) -> tuple[list[M], str | None]

# app/core/permissions.py
class Role(StrEnum)                         # owner, admin, operator, user, viewer
class Permission(StrEnum)
def role_has(role: Role, permission: Permission) -> bool

# app/core/deps.py
SessionDep, ClientInfoDep

# app/modules/auth/deps.py
Auth, CurrentUser, SuperUser               # AuthContext has .user and .session

# app/modules/organizations/deps.py
@dataclass class OrgContext                 # organization, membership, user, session, role, settings
def require(permission: Permission) -> dependency returning OrgContext

# app/core/events.py
def org_channel(organization_id: UUID) -> str         # private-org-{id}
def org_jobs_channel(organization_id: UUID) -> str    # private-org-{id}-jobs
def user_channel(user_id: UUID) -> str                # private-user-{id}
def emit(session, channels: Sequence[str], type: str, data: dict[str, Any]) -> None

# app/adapters/realtime/base.py
class RealtimePublisher(Protocol):
    async def publish(self, channels: Sequence[str], event: str, data: dict[str, Any]) -> None
    def authorize(self, socket_id: str, channel: str) -> str

# app/core/tasks.py
def enqueue(session, task_name: str, **kwargs: Any) -> None   # runs after commit

# app/modules/audit/service.py
def record(session, *, action: str, target_type: str, target_id: UUID | None,
           organization_id: UUID | None, actor_user_id: UUID | None,
           outcome: str = "success", detail: dict | None = None) -> None
```

---

### Task M0: Foundation

**Files:**
- Create: `.gitignore`, `.editorconfig`, `.pre-commit-config.yaml`, `Makefile`, `docker-compose.yml`, `README.md`, `CLAUDE.md`
- Create: `backend/pyproject.toml`, `backend/.env.example`, `backend/alembic.ini`, `backend/migrations/env.py`, `backend/migrations/script.py.mako`
- Create: `backend/app/main.py`, `backend/app/api.py`
- Create: `backend/app/core/{config,ids,db,errors,logging,security,crypto,pagination,redis,ratelimit}.py`
- Create: `backend/app/modules/health/router.py`
- Test: `backend/tests/conftest.py`, `backend/tests/test_health.py`, `backend/tests/core/test_{security,crypto,errors,ids}.py`

**Produces:** every `app/core` interface above except `permissions`, `deps`, `events`, `tasks`.

- [ ] Scaffold the repo files and `uv sync`.
- [ ] `docker compose up -d` and confirm Postgres, Redis, and MinIO report healthy.
- [ ] Write core tests: password hash round trip, token hash determinism, access-token round trip and expiry, Fernet round trip, UUIDv7 ordering, problem+json shape for `AppError` and for request validation errors.
- [ ] Implement core modules until they pass.
- [ ] Write `test_health.py`: `/api/v1/health/live` returns 200; `/api/v1/health/ready` returns 200 and reports `database` and `redis` as `ok`.
- [ ] Implement the app factory, health router, and test fixtures (`client`, `session`, migrated test database, per-test rollback).
- [ ] Run `make check`. Commit `chore: scaffold backend foundation`.

### Task M1: Auth, users, sessions, devices

**Files:**
- Create: `backend/app/modules/{users,auth,devices}/{models,schemas,service,router}.py`
- Create: `backend/app/modules/auth/deps.py`
- Create: `backend/migrations/versions/*_users_sessions_devices.py`
- Test: `backend/tests/modules/test_{auth,users,devices}.py`, `backend/tests/factories.py`

**Endpoints:**
- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`
- `POST /auth/password/change`, `GET /auth/sessions`, `DELETE /auth/sessions/{id}`
- `GET /users/me`, `PATCH /users/me`
- `POST /devices`, `GET /devices`, `PATCH /devices/{id}`, `DELETE /devices/{id}`

**Test cases:**
- Register returns tokens; duplicate email returns 409 `auth.email_taken`; weak password returns 422.
- Login with wrong password returns 401 `auth.invalid_credentials`, same response for unknown email.
- Refresh rotates the token; the old refresh token then revokes the session.
- A revoked session's access token returns 401.
- Password change revokes every other session.
- Login is rate limited after the configured number of attempts.
- Device registration is an upsert on `(user_id, installation_id)`; one user cannot read or change another user's device.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Commit `feat(auth): add accounts, sessions, and device registration`.

### Task M2: Organizations, RBAC, invitations, audit

**Files:**
- Create: `backend/app/core/permissions.py`
- Create: `backend/app/modules/{organizations,audit}/{models,schemas,service,router}.py`
- Create: `backend/app/modules/organizations/deps.py` (`OrgContext`, `require`)
- Create: `backend/migrations/versions/*_organizations_audit.py`
- Test: `backend/tests/modules/test_{organizations,rbac,audit}.py`, `backend/tests/core/test_permissions.py`

**Endpoints:**
- `POST /organizations`, `GET /organizations`, `GET|PATCH|DELETE /organizations/{org_id}`
- `GET /organizations/{org_id}/members`, `PATCH|DELETE /organizations/{org_id}/members/{user_id}`
- `POST|GET /organizations/{org_id}/invitations`, `DELETE /organizations/{org_id}/invitations/{id}`
- `POST /invitations/accept`
- `GET /organizations/{org_id}/audit-logs`

**Test cases:**
- The creator becomes `owner`. A non-member gets 404 for the organization, not 403.
- Role matrix: `viewer` cannot change settings; `admin` can manage members; only `owner` can delete the organization or change an owner.
- The last owner cannot be removed or demoted.
- An invitation token is single-use, expires, and only works for the invited email.
- Membership and settings changes write audit rows; `audit.read` is required to list them.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Commit `feat(orgs): add organizations, roles, invitations, and audit log`.

### Task M3: Printers, connections, capabilities, pairing

**Files:**
- Create: `backend/app/modules/{printers,connections,capabilities,pairing}/{models,schemas,service,router}.py`
- Create: `backend/app/modules/capabilities/seed.py` (Xerox VersaLink C7100 series profile)
- Create: `backend/migrations/versions/*_printers_connections_capabilities.py`
- Test: `backend/tests/modules/test_{printers,connections,capabilities,pairing}.py`

**Endpoints (under `/organizations/{org_id}`):**
- `POST|GET /printers`, `GET|PATCH|DELETE /printers/{id}`
- `PUT /printers/{id}/capabilities`, `POST /printers/{id}/status`
- `POST|GET /printers/{id}/connections`, `GET|PATCH|DELETE /printers/{id}/connections/{cid}`
- `PUT /printers/{id}/connections/priority`, `POST /printers/{id}/connections/{cid}/health`
- `POST /printers/{id}/pairing-tokens`
- Global: `POST /pairing/redeem`, `GET /capability-profiles`, `GET /capability-profiles/match`
- Superuser: `POST|PATCH|DELETE /admin/capability-profiles`

**Test cases:**
- A printer in organization A is invisible from organization B.
- Capability payloads are validated against `PrinterCapabilities`; an unknown `schema_version` returns 422.
- Connection credentials are encrypted in the database and absent from every response.
- Priority reorder rejects a list that does not match the printer's connections.
- A health report updates `last_success_at` or `last_failure_at`.
- A status report updates the printer and its `last_seen_at`.
- Profile match finds the C7130 for manufacturer `Xerox` and model `VersaLink C7130`.
- A pairing token redeems once, fails after expiry, and returns no credentials.
- Deleting a printer is a soft delete.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Commit `feat(printers): add printer profiles, connections, capability registry, and pairing`.

### Task M4: Jobs, idempotency, live events

**Files:**
- Create: `backend/app/core/{events,idempotency}.py`
- Create: `backend/app/adapters/realtime/{base,null,pusher,memory}.py`
- Create: `backend/app/modules/jobs/{models,schemas,service,router,state}.py`
- Create: `backend/app/modules/realtime/{schemas,service,router}.py`
- Modify: `docker-compose.yml` (add `soketi`), `backend/app/core/config.py`, `backend/.env.example`
- Modify: `backend/app/modules/printers/service.py`, `backend/app/modules/connections/service.py` (emit events)
- Create: `backend/migrations/versions/*_jobs_idempotency.py`
- Test: `backend/tests/modules/test_{jobs,jobs_batch,realtime,job_state}.py`, `backend/tests/core/test_idempotency.py`, `backend/tests/adapters/test_realtime_pusher.py`

**Endpoints:**
- Under `/organizations/{org_id}`: `POST /jobs` (requires `Idempotency-Key`), `GET /jobs`, `GET /jobs/{id}`, `POST /jobs/{id}/events`, `POST /jobs/{id}/cancel`, `POST /jobs/{id}/retry`, `POST /jobs/batch`
- `GET /realtime/config`, `POST /realtime/auth`

**Test cases:**
- State machine: forward transitions pass, backward transitions and any transition out of a terminal state raise `job.invalid_transition`.
- Same key and body returns the same job with `Idempotent-Replayed: true`; same key with a different body returns 422; a missing key returns 400.
- Organization policy: copies above `max_copies_per_job` returns 422 `job.policy_violation`; color by a role outside `color_printing_roles` returns 403.
- A `user` sees only their own jobs; `operator` and above see all and can cancel any.
- A second event on a different connection sets `fallback_occurred`.
- Retry is allowed only from `failed` or `cancelled` and links `retry_of_job_id`.
- Batch sync applies each item on its own and reports per-item results; replaying the batch changes nothing.
- A job event publishes `job.updated` to the organization jobs channel and the owner's user channel after commit, and nothing when the request fails.
- A status report publishes `printer.status_changed` to the organization channel.
- Channel authorization: a member may subscribe to their organization channel; a `user` role is refused the jobs channel; nobody may subscribe to another user's channel; an unknown channel is refused.
- The Pusher publisher signs requests so that a reference implementation of the signature verifies, and signs channel authorizations as `key:hmac_sha256(secret, "socket_id:channel")`.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Publish one event to a local Soketi container (`docker compose --profile realtime up -d`) and confirm it is accepted.
- [ ] Commit `feat(jobs): add job model, idempotency, batch sync, and live events`.

### Task M5: Presets, documents, object storage

**Files:**
- Create: `backend/app/adapters/storage/{base,s3,memory}.py`
- Create: `backend/app/modules/{presets,documents}/{models,schemas,service,router}.py`
- Create: `backend/migrations/versions/*_presets_documents.py`
- Test: `backend/tests/modules/test_{presets,documents}.py`, `backend/tests/adapters/test_storage.py`

**Endpoints (under `/organizations/{org_id}`):**
- `POST|GET /presets`, `GET|PATCH|DELETE /presets/{id}`
- `POST|GET /documents`, `GET|PATCH|DELETE /documents/{id}`
- `POST /documents/{id}/complete-upload`, `GET /documents/{id}/download-url`

**Test cases:**
- Personal presets are visible only to their owner; organization presets need `presets.manage_org` to change.
- One default preset per `(owner, printer, type)`.
- A `local` document stores metadata only and has no upload URL.
- A `cloud` document returns a presigned upload URL; `complete-upload` fails with 409 until the object exists.
- `document_storage_mode = local_only` rejects cloud documents.
- `document_retention_days` sets `retention_expires_at`.
- Search matches file name, tag, and OCR text.
- Delete removes the object and soft-deletes the row.
- The S3 adapter round trips against MinIO (marked `integration`).

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Commit `feat(documents): add presets, document metadata, and object storage`.

### Task M6: Notifications, push, worker, feature flags

**Files:**
- Create: `backend/app/core/tasks.py`, `backend/app/worker.py`
- Create: `backend/app/adapters/push/{base,log,fcm,memory}.py`
- Create: `backend/app/modules/{notifications,feature_flags}/{models,schemas,service,router}.py`
- Create: `backend/app/modules/notifications/tasks.py`, `backend/app/modules/documents/tasks.py`
- Modify: `backend/app/modules/jobs/service.py`, `backend/app/modules/organizations/service.py` (emit notifications)
- Create: `backend/migrations/versions/*_notifications_feature_flags.py`
- Test: `backend/tests/modules/test_{notifications,feature_flags}.py`, `backend/tests/adapters/test_push_fcm.py`, `backend/tests/test_worker_tasks.py`

**Endpoints:**
- `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`
- `GET /organizations/{org_id}/feature-flags`
- Superuser: `GET|PUT|DELETE /admin/feature-flags/{key}`, `PUT|DELETE /admin/feature-flags/{key}/overrides/{org_id}`

**Test cases:**
- A job reaching `completed` or `failed` creates one notification for the job owner and enqueues a push task.
- A user's notification preferences suppress push for a disabled event type.
- The push task sends to every device with a token and clears a token the provider rejects.
- A push carries a data payload with the notification type and related IDs.
- FCM provider exchanges a service-account JWT for an access token, caches it, and maps `UNREGISTERED` to an invalid token.
- Flag resolution: organization override beats the global default; an unknown flag is absent.
- The retention task deletes expired documents and their objects.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Commit `feat(notifications): add notifications, push providers, worker, and feature flags`.

### Task M7: Simulator, contract, packaging

**Files:**
- Create: `backend/simulator/{__init__,main,ipp,escl,state,fixtures}.py`
- Create: `backend/scripts/{export_openapi,seed}.py`, `backend/openapi.json`
- Create: `backend/Dockerfile`, `backend/.dockerignore`, `.github/workflows/backend-ci.yml`
- Modify: `docker-compose.yml` (add `api`, `worker`, `simulator` under the `app` profile), `README.md`, `CLAUDE.md`
- Test: `backend/tests/simulator/test_{ipp,escl,control}.py`, `backend/tests/test_openapi.py`

**Test cases:**
- The IPP codec round trips an encoded request.
- Get-Printer-Attributes returns `printer-make-and-model` containing `VersaLink C7130`.
- Print-Job returns a job ID; Get-Job-Attributes reports it completing; Cancel-Job works on a pending job.
- With the paper-jam fault on, Print-Job leaves the job stopped and `printer-state-reasons` reports `media-jam`.
- eSCL: capabilities XML lists Platen and Feeder; a scan job returns `201` with `Location`; `NextDocument` returns pages, then `404`.
- With eSCL disabled, `/eSCL/ScannerCapabilities` returns `404`.
- `openapi.json` matches the running app.

- [ ] Write the tests, watch them fail, implement, run `make check`.
- [ ] Build the Docker image and start the full stack with `docker compose --profile app up -d`.
- [ ] Walk the smoke flow against the running API: register, create organization, add printer, create job, report completion.
- [ ] Commit `feat(simulator): add printer simulator, OpenAPI contract, and packaging`.

## Self-review

| Spec section | Task |
|---|---|
| §6.1 API conventions | M0 (errors, pagination, IDs), M7 (OpenAPI export) |
| §6.2 Authentication and sessions | M1 |
| §6.3 Tenancy and authorization | M2; policy enforcement in M4 and M5 |
| §6.4 Unit of work and events | M0 (`after_commit`), M4 (`events`, Soketi publisher, channel auth), M6 (`tasks`) |
| §6.5 Idempotency | M4 |
| §6.6 Security | M0 (crypto, redaction), M3 (credentials, pairing), M5 (presigned URLs) |
| §8 Capability schema | M3 |
| §9 Job model | M4 |
| §10 Documents and storage | M5; retention task in M6 |
| §11 Notifications and push | M6 |
| §12 Simulator | M7 |
| §13 Testing | M0 harness; every task |
