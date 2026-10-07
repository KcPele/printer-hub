# PrinterHub

Backend-first, mobile-first printer and scanner management. One backend, multiple clients, multiple ways to reach the printer.

The backend holds identity, organizations, printer profiles, job state, document metadata, notifications, and audit. It never connects to a printer: the mobile app (and later the web app) executes jobs on the local network and reports state.

## Repository

| Path | Contents |
|---|---|
| `backend/` | FastAPI service, background worker, printer simulator |
| `docs/` | Design spec and implementation plan |
| `PrinterHub_FRD_v2.0_Mobile_First.md` | Functional requirements |

## Quick start

Requirements: [uv](https://docs.astral.sh/uv/), Docker.

```bash
make setup      # install dependencies, create backend/.env
make infra      # start Postgres, Redis, MinIO
make migrate    # create the schema
make seed       # load capability profiles and feature flags
make dev        # API on http://localhost:8000
```

Interactive API docs: <http://localhost:8000/api/docs>.

Run `make help` for every command, including `make worker` and `make simulator`.

To run the whole stack in containers instead:

```bash
docker compose --profile app up -d --build
```

## Local services

| Service | Host address | Credentials |
|---|---|---|
| PostgreSQL | `localhost:5433` | `printerhub` / `printerhub` |
| Redis | `localhost:6380` | none |
| MinIO API | `localhost:9000` | `printerhub` / `printerhub-dev-secret` |
| MinIO console | <http://localhost:9001> | same |
| API | <http://localhost:8000> | |
| Printer simulator | <http://localhost:8631> | |

Ports are offset from the defaults so they coexist with locally installed Postgres and Redis.

## Using hosted services

Every setting is an environment variable with the `PRINTERHUB_` prefix. `backend/.env.example` lists them. To point the backend at a hosted database or object store, set the matching variables in `backend/.env`; no code changes are needed.

Outside `local` and `test`, the service refuses to start until `PRINTERHUB_SECRET_KEY` and `PRINTERHUB_CREDENTIALS_ENCRYPTION_KEY` are set.

## Quality gates

```bash
make check      # ruff, mypy (strict), pytest
```

Tests run against the Docker Compose Postgres and Redis, in a separate `printerhub_test` database.

## Printer simulator

`make simulator` starts a fake Xerox VersaLink C7130 that speaks IPP and eSCL, for building clients without the hardware. See `backend/simulator/README.md`.
