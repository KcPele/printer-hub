# PrinterHub

Backend-first, mobile-first printer and scanner management. One backend, multiple clients, multiple ways to reach the printer.

The backend holds identity, organizations, printer profiles, job state, document metadata, notifications, and audit. It never connects to a printer: the mobile app (and later the web app) executes jobs on the local network and reports state.

## Repository

| Path | Contents |
|---|---|
| `backend/` | FastAPI service, background worker, printer simulator |
| `docs/` | Deployment guide, design spec, implementation plan |
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

`make dev` runs the background worker inside the API process, so that one command is the whole backend. Run `make help` for every command, including `make simulator`.

To run the API and the simulator in containers instead:

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

## Deploying

One container is the whole backend. It needs PostgreSQL, Redis, and S3-compatible storage. See [docs/deployment.md](docs/deployment.md) for the settings, the required environment variables, and push notification setup.

Every setting is an environment variable with the `PRINTERHUB_` prefix, defined in `backend/app/core/config.py`. Outside `local` and `test`, the service refuses to start until `PRINTERHUB_SECRET_KEY` and `PRINTERHUB_CREDENTIALS_ENCRYPTION_KEY` are set.

## Notifications

**Firebase Cloud Messaging (FCM)** is the one notification service. It reaches Android directly and iOS through APNs, so both platforms register an FCM token. Every push carries a small data payload (event type and IDs), which an open app uses to refresh itself. Screens that show shared state, such as printer status, refetch when opened and on a timer.

Pushes are written to the log until FCM is configured. [docs/deployment.md](docs/deployment.md#push-notifications) has the steps.

**Email** carries the 6-digit codes for password reset and email verification. It goes through any SMTP server and is written to the log until one is configured.

## Quality gates

```bash
make check      # ruff, mypy (strict), pytest
```

Tests run against the Docker Compose Postgres and Redis, in a separate `printerhub_test` database.

## Printer simulator

`make simulator` starts a fake Xerox VersaLink C7130 that speaks IPP and eSCL, for building clients without the hardware. See `backend/simulator/README.md`.
