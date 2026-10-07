"""Test harness.

Tests run against the Postgres and Redis from docker-compose.yml, in a
dedicated `printerhub_test` database and Redis database 15. The schema is built
by running the Alembic migrations. Each test runs inside one transaction that
is rolled back afterwards, so tests never see each other's rows.
"""

import asyncio
import os
from collections.abc import AsyncIterator, Iterator

os.environ["PRINTERHUB_ENVIRONMENT"] = "test"
os.environ["PRINTERHUB_DATABASE_URL"] = os.environ.get(
    "PRINTERHUB_TEST_DATABASE_URL",
    "postgresql+asyncpg://printerhub:printerhub@localhost:5433/printerhub_test",
)
os.environ["PRINTERHUB_REDIS_URL"] = os.environ.get(
    "PRINTERHUB_TEST_REDIS_URL", "redis://localhost:6380/15"
)
os.environ["PRINTERHUB_STORAGE_BACKEND"] = "memory"
os.environ["PRINTERHUB_PUSH_BACKEND"] = "log"
os.environ["PRINTERHUB_LOG_LEVEL"] = "WARNING"
os.environ["PRINTERHUB_CORS_ORIGINS"] = "[]"

import httpx
import pytest
from alembic import command
from alembic.config import Config
from fastapi import FastAPI
from sqlalchemy import make_url, text
from sqlalchemy.ext.asyncio import (
    AsyncConnection,
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import get_settings
from app.core.db import get_engine, get_session, session_scope
from app.core.redis import get_redis
from app.main import create_app


async def _ensure_test_database() -> None:
    url = make_url(get_settings().database_url)
    database = url.database or ""
    if not database.endswith("_test"):
        raise RuntimeError(f"Refusing to run tests against database {database!r}")
    admin = create_async_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    async with admin.connect() as connection:
        exists = await connection.scalar(
            text("SELECT 1 FROM pg_database WHERE datname = :name"), {"name": database}
        )
        if not exists:
            await connection.execute(text(f'CREATE DATABASE "{database}"'))
    await admin.dispose()


def _run_migrations() -> None:
    config = Config("alembic.ini")
    config.attributes["configure_logger"] = False
    command.upgrade(config, "head")


@pytest.fixture(scope="session")
async def engine() -> AsyncIterator[AsyncEngine]:
    await _ensure_test_database()
    engine = get_engine()
    async with engine.begin() as connection:
        await connection.execute(text("DROP SCHEMA public CASCADE"))
        await connection.execute(text("CREATE SCHEMA public"))
    # Alembic's env.py calls asyncio.run, which needs a thread without a running loop.
    await asyncio.to_thread(_run_migrations)
    yield engine
    await engine.dispose()


@pytest.fixture
async def connection(engine: AsyncEngine) -> AsyncIterator[AsyncConnection]:
    async with engine.connect() as connection:
        transaction = await connection.begin()
        yield connection
        await transaction.rollback()


@pytest.fixture
def session_factory(connection: AsyncConnection) -> async_sessionmaker[AsyncSession]:
    # Sessions join the test's outer transaction; their commits release a
    # savepoint, so the final rollback still discards everything.
    return async_sessionmaker(
        bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )


@pytest.fixture
async def session(
    session_factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    """A session for arranging and asserting data directly."""
    async with session_factory() as session:
        yield session


@pytest.fixture(scope="session")
def app_instance() -> FastAPI:
    return create_app()


@pytest.fixture
def app(
    app_instance: FastAPI, session_factory: async_sessionmaker[AsyncSession]
) -> Iterator[FastAPI]:
    async def _get_session() -> AsyncIterator[AsyncSession]:
        async with session_scope(session_factory) as session:
            yield session

    app_instance.dependency_overrides[get_session] = _get_session
    yield app_instance
    app_instance.dependency_overrides.clear()


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[httpx.AsyncClient]:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.fixture(autouse=True)
async def _clean_redis() -> None:
    await get_redis().flushdb()
