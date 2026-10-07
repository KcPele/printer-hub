#!/bin/sh
# Container entry point: bring the database up to date, then serve.
set -e

alembic upgrade head
python -m scripts.seed

# WEB_CONCURRENCY sets the number of API processes (default 1).
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers
