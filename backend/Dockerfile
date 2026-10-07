# syntax=docker/dockerfile:1

# One container is the whole backend: on start it applies migrations, loads
# reference data, then serves the API with the background worker inside it.
# Override the command to run a piece on its own:
#   arq app.worker.WorkerSettings                              (worker only)
#   uvicorn simulator.main:app --host 0.0.0.0 --port 8631      (printer simulator)

FROM python:3.14-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app
# Dependencies change less often than code: install them in their own layer.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-dev --no-install-project


FROM python:3.14-slim
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home app
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY alembic.ini ./
COPY migrations ./migrations
COPY scripts ./scripts
COPY simulator ./simulator
COPY app ./app
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PRINTERHUB_LOG_JSON=true \
    PORT=8000 \
    # Trust X-Forwarded-For from the reverse proxy, so rate limits and the audit
    # log see real client addresses. This assumes the port is reachable only
    # through that proxy; narrow it if you publish the port directly.
    FORWARDED_ALLOW_IPS="*"
USER app
EXPOSE 8000
CMD ["sh", "scripts/start.sh"]
