"""Database engine, declarative base, and the request unit of work."""

import enum
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from datetime import datetime
from functools import lru_cache
from typing import Any

import sqlalchemy as sa
import structlog
from sqlalchemy import MetaData, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.core.config import get_settings
from app.core.ids import new_id

log = structlog.get_logger(__name__)

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

AfterCommitCallback = Callable[[], Awaitable[None]]
_AFTER_COMMIT_KEY = "after_commit_callbacks"


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
    type_annotation_map = {
        dict[str, Any]: JSONB,
        list[str]: JSONB,
        datetime: sa.DateTime(timezone=True),
    }
    # Load server-generated values (created_at, updated_at) with RETURNING, so
    # objects are complete after flush and never lazy-load.
    __mapper_args__ = {"eager_defaults": True}


class IdMixin:
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_id)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())


class CreatedAtMixin:
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


def str_enum(enum_cls: type[enum.StrEnum], length: int = 32) -> sa.Enum:
    """Column type storing a StrEnum as VARCHAR.

    Native PostgreSQL enums need a migration for every new member; a VARCHAR does not.
    """
    return sa.Enum(
        enum_cls,
        native_enum=False,
        length=length,
        create_constraint=False,
        values_callable=lambda cls: [member.value for member in cls],
    )


@lru_cache
def get_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(
        settings.database_url,
        pool_size=settings.database_pool_size,
        pool_pre_ping=True,
    )


@lru_cache
def get_session_factory() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(get_engine(), expire_on_commit=False)


def after_commit(session: AsyncSession, callback: AfterCommitCallback) -> None:
    """Run `callback` once the session's transaction has committed.

    Side effects that leave the database (live events, background tasks) go
    through here so a rolled-back request emits nothing.
    """
    session.info.setdefault(_AFTER_COMMIT_KEY, []).append(callback)


async def _run_after_commit(session: AsyncSession) -> None:
    callbacks: list[AfterCommitCallback] = session.info.pop(_AFTER_COMMIT_KEY, [])
    for callback in callbacks:
        try:
            await callback()
        except Exception:
            # The transaction is already committed; a failed side effect must
            # not turn a successful request into an error.
            log.exception("after_commit_callback_failed")


@asynccontextmanager
async def session_scope(
    factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    """One unit of work: commit on success, roll back on error, then run after-commit work."""
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except BaseException:
            await session.rollback()
            session.info.pop(_AFTER_COMMIT_KEY, None)
            raise
        await _run_after_commit(session)


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency providing the request's unit of work."""
    async with session_scope(get_session_factory()) as session:
        yield session
