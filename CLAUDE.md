# PrinterHub

Backend-first, mobile-first printer and scanner platform. This repo is a monorepo: `backend/` exists today; `mobile/`, `web/`, and `packages/` join later.

**The backend never talks to a printer.** Clients run print and scan jobs on the local network and report state. Anything that needs to reach a printer belongs in a client or in `backend/simulator/`.

## Where things are

| Need | Read |
|---|---|
| Product requirements, FR-* IDs | `PrinterHub_FRD_v2.0_Mobile_First.md` (3,000 lines: grep for the FR ID or section) |
| Backend architecture and the reasons behind it | `docs/superpowers/specs/2026-10-07-backend-mvp-design.md` |
| Milestones and fixed interface names | `docs/superpowers/plans/2026-10-07-backend-mvp.md` |
| Commands | `make help` |
| API contract | `backend/openapi.json`, or `/api/docs` on a running server |

## Working in `backend/`

Run everything through `make` from the repo root, or `uv run <cmd>` from `backend/`. Python is 3.14, managed by uv.

A change is done when `make check` passes (ruff, mypy strict, pytest). Tests need `make infra` running.

### Module shape

Each domain lives in `backend/app/modules/<name>/` with four files:

- `models.py` — SQLAlchemy tables.
- `schemas.py` — Pydantic request and response models.
- `service.py` — business rules, queries, audit writes, event emission. Plain async functions taking `session` first. No FastAPI imports.
- `router.py` — HTTP mapping only: parse input, call the service, return a schema.

A module reaches another module through its `service`, never its `models` queries or `router`.

Adding a module: create the four files, import the models in `app/models.py`, mount the router in `app/api.py`, run `make migration m="..."`, review the generated file.

### Rules that hold everywhere

- **Tenancy.** Every organization-owned route takes `ctx: Annotated[OrgContext, Depends(require(Permission.X))]` from `app/modules/organizations/deps.py`. Every query in its service filters by `ctx.organization.id`. A resource in another organization is a 404, the same as a missing one.
- **Unit of work.** The session dependency commits. Services call `await session.flush()` to get IDs and surface constraint errors; they leave `commit()` to the dependency.
- **Side effects after commit.** Live events go through `events.emit(session, channels, type, data)` and background tasks through `tasks.enqueue(session, ...)`. Both wait for the commit, so a failed request emits nothing. Use `db.after_commit` for any new kind of side effect.
- **Live events are thin.** An event carries a type, IDs, and the new status; clients refetch through REST. Pick channels with the helpers in `app/core/events.py`: the channel decides who can see the event, so job events go to the jobs channel and the owner's user channel, never the organization-wide one.
- **FCM is the notification channel.** A user-facing notification is an in-app row plus an FCM push whose data payload carries the event type and IDs, so an open app can refresh from it. Live events through `events.emit` reach clients only when the optional Soketi backend is on (`PRINTERHUB_REALTIME_BACKEND=soketi`); with the default `none` they are dropped. Anything a user must learn about goes out as a notification, never as a live event alone.
- **Routers return schemas.** Build the response with `Schema.model_validate(obj)` inside the endpoint. Relationships are loaded explicitly in the service; nothing lazy-loads.
- **Errors.** Raise an `AppError` subclass from `app/core/errors.py` with a dotted `code` such as `job.invalid_transition`. Codes are API contract: add new ones, keep existing ones stable.
- **Audit.** A service that changes membership, permissions, printers, connections, or credentials calls `audit.record(...)` in the same transaction.
- **Enums.** Declare a `StrEnum` and map it with `db.str_enum(...)`. It stores a VARCHAR, so a new member needs no migration.
- **IDs and time.** IDs come from `ids.new_id()` (UUIDv7, sortable by creation). Datetimes are timezone-aware UTC.
- **Secrets.** Connection credentials go through `crypto.encrypt_json` and stay out of every response schema. Log with structlog key-value pairs; the redaction processor keys off names like `password` and `token`, so name sensitive fields accordingly.
- **Pagination.** List endpoints take `PageParams` and return `Page[Schema]` via `pagination.paginate`.
- **Idempotency.** A `POST` that creates a job or document reads the `Idempotency-Key` header through `app/core/idempotency.py`.

### Migrations

`make migration m="..."` autogenerates from the models. Read the result before committing: check index and constraint names, and add data backfills by hand. One migration per change, never edit a migration that has been merged.

### Tests

- Tests exercise behavior through the HTTP API with the `client` fixture. Reach for a direct service or unit test when the logic is pure (state machines, codecs, permission maps).
- Each test runs in a rolled-back transaction on one connection, so requests inside a test are sequential.
- Arrange data with `tests/factories.py`. After an API call changes a row you hold, `await session.refresh(obj)`.
- Object storage, push, and live events use the in-memory fakes. Assert on emitted events with the `realtime` fixture. Tests marked `integration` hit MinIO.
- Use `@example.com` addresses; the email validator rejects reserved TLDs such as `.test`.

### Adapters

`app/adapters/push`, `app/adapters/realtime`, and `app/adapters/storage` each define a protocol in `base.py`, real implementations, and an in-memory fake. Services depend on the protocol. A new provider is a new file plus one branch in the factory function.

## Conventions

- Conventional Commits (`feat(jobs): ...`, `fix(auth): ...`). One logical change per commit.
- Regenerate the contract with `make openapi` whenever a route or schema changes; CI fails on a stale `openapi.json`.
- Local infrastructure uses offset host ports (Postgres 5433, Redis 6380) so it coexists with locally installed services.
- Settings are `PRINTERHUB_*` environment variables defined in `backend/app/core/config.py`. Add new ones there and to `backend/.env.example`.
