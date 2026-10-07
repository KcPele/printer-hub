# Deploying the backend

The backend is one container. On start it applies database migrations, loads reference data, then serves the API with the background worker running inside the same process. It needs three services you host separately: PostgreSQL, Redis, and S3-compatible object storage (MinIO).

These steps use Dokploy. Any platform that builds a Dockerfile and sets environment variables works the same way.

## Application settings

| Setting | Value |
|---|---|
| Provider | GitHub, repository `printer-hub`, branch `main` |
| Build path | `/backend` |
| Build type | Dockerfile |
| Docker file | `./Dockerfile` |
| Container port (Domains tab) | `8000` |
| Health check path | `/api/v1/health/ready` |

With autodeploy on, every push to `main` builds and deploys. Migrations run before the API starts; if one fails the container exits and the previous deployment keeps serving.

## Environment variables

Set these in the Environment tab. Do not paste `backend/.env.example` as it is: its values are for a developer's laptop.

### Required

| Variable | Value |
|---|---|
| `PRINTERHUB_ENVIRONMENT` | `production` |
| `PRINTERHUB_SECRET_KEY` | A random string. Signs login tokens. |
| `PRINTERHUB_CREDENTIALS_ENCRYPTION_KEY` | A Fernet key. Encrypts stored printer credentials. |
| `PRINTERHUB_DATABASE_URL` | `postgresql://USER:PASSWORD@HOST:PORT/DATABASE` |
| `PRINTERHUB_REDIS_URL` | `redis://:PASSWORD@HOST:PORT/0` |
| `PRINTERHUB_S3_ENDPOINT_URL` | The MinIO address, reachable from phones |
| `PRINTERHUB_S3_ACCESS_KEY`, `PRINTERHUB_S3_SECRET_KEY` | A MinIO access key |
| `PRINTERHUB_S3_BUCKET` | An existing bucket |

Generate the two keys on your own machine:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

```bash
python3 -c "import base64, os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
```

Why each of these matters:

- **`PRINTERHUB_ENVIRONMENT=production`** makes the service refuse to start without its own secret keys. With `local`, it signs login tokens with a development key that is published in this repository, so anyone could sign in as any user.
- **Give PrinterHub its own database.** It creates tables named `users`, `sessions`, `jobs`, `documents`, and `alembic_version`. In a database shared with another application these collide.
- **The MinIO address must work from a phone.** Uploads and downloads go from the phone straight to MinIO with signed URLs; the API never carries file bytes. If the backend reaches MinIO at an internal address, set that as `PRINTERHUB_S3_ENDPOINT_URL` and the public one as `PRINTERHUB_S3_PUBLIC_ENDPOINT_URL`.
- **Keep a copy of the encryption key.** Stored printer credentials cannot be read without it.

### Push notifications

Pushes are written to the log until this is set.

| Variable | Value |
|---|---|
| `PRINTERHUB_PUSH_BACKEND` | `fcm` |
| `PRINTERHUB_FCM_SERVICE_ACCOUNT_JSON` | The service-account key, base64-encoded |

1. Firebase console → Project settings → **Service accounts** → **Generate new private key**. This downloads a file named like `printerhub-a2a7a-firebase-adminsdk-xxxxx.json`.
2. Encode it and copy it to the clipboard (macOS):

   ```bash
   base64 -i ~/Downloads/printerhub-a2a7a-firebase-adminsdk-xxxxx.json | tr -d '\n' | pbcopy
   ```

3. Paste the result as the value of `PRINTERHUB_FCM_SERVICE_ACCOUNT_JSON` and redeploy.
4. For iPhones: Project settings → Cloud Messaging → upload the APNs authentication key.

This key is not `google-services.json` or `GoogleService-Info.plist`. Those two configure the mobile apps and go into the app project. The backend rejects them with a message that says so.

### Optional

| Variable | Default | Purpose |
|---|---|---|
| `PRINTERHUB_CORS_ORIGINS` | `[]` | JSON list of web origins allowed to call the API. Mobile apps need none. |
| `PRINTERHUB_LOG_LEVEL` | `INFO` | |
| `WEB_CONCURRENCY` | `1` | Number of API processes. |
| `PRINTERHUB_EMBEDDED_WORKER` | `true` | Set `false` only when running the worker as its own container. |

## After the first deploy

Check it is healthy:

```bash
curl https://YOUR-DOMAIN/api/v1/health/ready
```

`{"status":"ok","database":"ok","redis":"ok"}` means the API reaches its database and Redis. Interactive API docs are at `/api/docs`.

Make yourself a platform administrator, who manages feature flags and the capability registry. Register an account through the API or the app, then in the container's terminal:

```bash
python -m scripts.promote_superuser you@example.com
```

Turn on default encryption for the bucket. With the MinIO client:

```bash
mc encrypt set sse-s3 ALIAS/BUCKET
```

## Operating

- **Logs** are JSON, one object per line. Each has a `request_id`, which also appears in every error response and in the `X-Request-ID` response header.
- **The worker** sends push notifications and deletes documents past their retention time. It logs `Starting worker for 3 functions` on start.
- **Client addresses.** The image trusts `X-Forwarded-For` from the platform's proxy, so rate limits and the audit log see real addresses. This assumes the container is reachable only through that proxy. If you publish its port directly, set `FORWARDED_ALLOW_IPS` to your proxy's address.

## Running the worker separately

One container is enough until push volume or document cleanup competes with API traffic. To split it, create a second application from the same repository and build path with this command, and set `PRINTERHUB_EMBEDDED_WORKER=false` on the API:

```bash
arq app.worker.WorkerSettings
```

## What to back up

- **PostgreSQL.** All application state.
- **The MinIO bucket.** Cloud documents.
- **The two secret keys.** Above all the encryption key.

Redis holds the task queue and rate-limit counters. Losing it drops queued push notifications and nothing else.
