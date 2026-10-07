# PrinterHub

# dont ever say in your commit message, co-authored by claude

Backend-first, mobile-first printer and scanner platform. This repo is a monorepo: `backend/` and `packages/api-client/` exist today; `mobile/` and `web/` join later.

**The backend never talks to a printer.** Clients run print and scan jobs on the local network and report state. Anything that needs to reach a printer belongs in a client or in `backend/simulator/`.

## Where things are

| Need | Read |
|---|---|
| Product requirements, FR-* IDs | `PrinterHub_FRD_v2.0_Mobile_First.md` (3,000 lines: grep for the FR ID or section) |
| Backend architecture and the reasons behind it | `docs/superpowers/specs/2026-10-07-backend-mvp-design.md` |
| Milestones and fixed interface names | `docs/superpowers/plans/2026-10-07-backend-mvp.md` |
| Commands | `make help` |
| Hosting, environment variables, push setup | `docs/deployment.md` |
| Printer simulator endpoints and faults | `backend/simulator/README.md` |
| API contract | `backend/openapi.json`, or `/api/docs` on a running server |
| Calling the API from an app | `packages/api-client/README.md` |

## Working in `backend/`

Run everything through `make` from the repo root, or `uv run <cmd>` from `backend/`. Python is 3.14, managed by uv.

A change is done when `make check` passes (ruff, mypy strict, pytest). Tests need `make infra` running.

### Module shape

Each domain lives in `backend/app/modules/<name>/` with four files:

- `models.py` — SQLAlchemy tables.
- `schemas.py` — Pydantic request and response models, subclassing `ApiModel` from `app/core/schemas.py`.
- `service.py` — business rules, queries, audit writes, event emission. Plain async functions taking `session` first. No FastAPI imports.
- `router.py` — HTTP mapping only: parse input, call the service, return a schema.

A module reaches another module through its `service`, never its `models` queries or `router`.

Adding a module: create the four files, import the models in `app/models.py`, mount the router in `app/api.py`, run `make migration m="..."`, review the generated file.

### Rules that hold everywhere

- **Tenancy.** Every organization-owned route takes `ctx: Annotated[OrgContext, Depends(require(Permission.X))]` from `app/modules/organizations/deps.py`. Every query in its service filters by `ctx.organization.id`. A resource in another organization is a 404, the same as a missing one.
- **Unit of work.** The session dependency commits. Services call `await session.flush()` to get IDs and surface constraint errors; they leave `commit()` to the dependency.
- **Side effects after commit.** Background tasks go through `tasks.enqueue(session, ...)`, which waits for the commit, so a failed request sends nothing. Use `db.after_commit` for any new kind of side effect.
- **One process.** The arq worker runs inside the API process (`embedded_worker`), so the deployment is a single container. A task function lives in `app/worker.py`, opens its own `session_scope`, and takes string arguments.
- **FCM is the only channel to clients.** A user-facing notification is an in-app row plus an FCM push whose data payload carries the event type and IDs, so an open app can refresh from it. There is no WebSocket server; shared state such as printer status is refetched by clients.
- **Routers return schemas.** Build the response with `Schema.model_validate(obj)` inside the endpoint. Relationships are loaded explicitly in the service; nothing lazy-loads.
- **A failure that must leave a mark.** Raising rolls the request back. When a rejected request still has to change something (a wrong code counts as an attempt, a replayed refresh token revokes the session), call `await session.commit()` just before raising, with a comment saying why. These are the only places a service commits.
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
- Object storage, push, email, and the task queue use in-memory fakes, exposed as the `storage`, `push`, `mailbox`, and `task_queue` fixtures. A request that should notify someone is asserted on `task_queue`; delivery is asserted by calling the worker function and reading `push`. Tests marked `integration` hit MinIO.
- Use `@example.com` addresses; the email validator rejects reserved TLDs such as `.test`.

### Adapters

`app/adapters/push`, `app/adapters/email`, and `app/adapters/storage` each define a protocol in `base.py`, real implementations, and an in-memory fake. Services depend on the protocol. A new provider is a new file plus one branch in the factory function.

## Conventions

- Conventional Commits (`feat(jobs): ...`, `fix(auth): ...`). One logical change per commit.
- Run `make openapi` whenever a route or schema changes. It rewrites `backend/openapi.json` and the client types in `packages/api-client/src/schema.d.ts`; commit both. CI fails when either is stale.
- The contract is the source of the apps' types. When a generated type is looser than the API's behavior, fix the backend schema or `_polish_contract` in `app/main.py`, never the generated file.
- Apps call the API only through `@printerhub/api-client`.
- Local infrastructure uses offset host ports (Postgres 5433, Redis 6380) so it coexists with locally installed services.
- `main` deploys to production on push. The container runs `scripts/start.sh`: migrations, seed, then the API. A migration on `main` runs against the live database on the next deploy.
- `backend/simulator/` shares no code with `backend/app/`. Keep it that way: it stands in for hardware.
- Settings are `PRINTERHUB_*` environment variables defined in `backend/app/core/config.py`. Add new ones there and to `backend/.env.example`.
