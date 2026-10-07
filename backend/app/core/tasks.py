"""Background work, queued for the worker process (`app/worker.py`)."""

from dataclasses import dataclass, field
from datetime import timedelta
from functools import lru_cache
from typing import Any, Protocol

from arq import create_pool
from arq.connections import ArqRedis, RedisSettings
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import after_commit


class TaskQueue(Protocol):
    async def enqueue(
        self, task_name: str, *, defer_by: timedelta | None = None, **kwargs: Any
    ) -> None: ...


class ArqTaskQueue:
    def __init__(self, redis_url: str) -> None:
        self._settings = RedisSettings.from_dsn(redis_url)
        self._pool: ArqRedis | None = None

    async def enqueue(
        self, task_name: str, *, defer_by: timedelta | None = None, **kwargs: Any
    ) -> None:
        if self._pool is None:
            self._pool = await create_pool(self._settings)
        await self._pool.enqueue_job(task_name, _defer_by=defer_by, **kwargs)


@dataclass(frozen=True, slots=True)
class EnqueuedTask:
    name: str
    kwargs: dict[str, Any]
    defer_by: timedelta | None = None


@dataclass
class MemoryTaskQueue:
    """Records tasks instead of queueing them. Used by tests."""

    enqueued: list[EnqueuedTask] = field(default_factory=list)

    async def enqueue(
        self, task_name: str, *, defer_by: timedelta | None = None, **kwargs: Any
    ) -> None:
        self.enqueued.append(EnqueuedTask(task_name, kwargs, defer_by))

    def named(self, task_name: str) -> list[EnqueuedTask]:
        return [task for task in self.enqueued if task.name == task_name]


@lru_cache
def get_task_queue() -> TaskQueue:
    settings = get_settings()
    if settings.tasks_backend == "memory":
        return MemoryTaskQueue()
    return ArqTaskQueue(settings.redis_url)


def enqueue(session: AsyncSession, task_name: str, **kwargs: Any) -> None:
    """Queue `task_name` once the session's transaction commits.

    Arguments are serialized, so pass IDs as strings rather than model objects.
    """

    async def send() -> None:
        await get_task_queue().enqueue(task_name, **kwargs)

    after_commit(session, send)
