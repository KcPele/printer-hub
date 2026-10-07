"""Background worker. Run with: arq app.worker.WorkerSettings"""

import uuid
from datetime import timedelta
from typing import TYPE_CHECKING, Any, ClassVar, cast

import structlog
from arq import cron
from arq.connections import RedisSettings

from app.core import idempotency
from app.core.config import get_settings
from app.core.db import get_engine, get_session_factory, session_scope
from app.core.logging import configure_logging
from app.core.tasks import get_task_queue
from app.modules.auth import service as auth
from app.modules.documents import service as documents
from app.modules.notifications import service as notifications
from app.modules.organizations import service as organizations
from app.modules.pairing import service as pairing

if TYPE_CHECKING:
    from arq.typing import WorkerCoroutine

log = structlog.get_logger(__name__)

MAX_PUSH_ATTEMPTS = 4
_PUSH_RETRY_BASE_SECONDS = 30


async def push_notification(
    _ctx: dict[str, Any],
    notification_id: str,
    device_ids: list[str] | None = None,
    attempt: int = 1,
) -> None:
    """Push a notification to its user's devices, retrying only the ones that failed."""
    async with session_scope(get_session_factory()) as session:
        failed = await notifications.deliver_push(
            session,
            uuid.UUID(notification_id),
            device_ids=[uuid.UUID(value) for value in device_ids] if device_ids else None,
        )
    if not failed:
        return
    if attempt >= MAX_PUSH_ATTEMPTS:
        log.warning("push_gave_up", notification_id=notification_id, devices=len(failed))
        return
    await get_task_queue().enqueue(
        notifications.PUSH_TASK,
        defer_by=timedelta(seconds=_PUSH_RETRY_BASE_SECONDS * 2 ** (attempt - 1)),
        notification_id=notification_id,
        device_ids=[str(device_id) for device_id in failed],
        attempt=attempt + 1,
    )


async def purge_expired_documents(_ctx: dict[str, Any]) -> int:
    """Delete documents past their retention time, with their stored files (FR-DOC-008)."""
    total = 0
    while True:
        async with session_scope(get_session_factory()) as session:
            purged = await documents.purge_expired(session)
        total += purged
        if purged == 0:
            break
    if total:
        log.info("documents_purged", count=total)
    return total


async def purge_expired_records(_ctx: dict[str, Any]) -> None:
    """Remove rows that have outlived their purpose: used keys, dead sessions, old tokens."""
    async with session_scope(get_session_factory()) as session:
        await idempotency.purge_expired(session)
        await auth.purge_dead_sessions(session)
        await pairing.purge_expired(session)
        await organizations.purge_stale_invitations(session)


async def _startup(_ctx: dict[str, Any]) -> None:
    configure_logging()


async def _shutdown(_ctx: dict[str, Any]) -> None:
    await get_engine().dispose()


class WorkerSettings:
    functions: ClassVar[list[Any]] = [push_notification]
    cron_jobs: ClassVar[list[Any]] = [
        cron(cast("WorkerCoroutine", purge_expired_documents), minute={5, 20, 35, 50}),
        cron(cast("WorkerCoroutine", purge_expired_records), hour=3, minute=40),
    ]
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url)
    on_startup = _startup
    on_shutdown = _shutdown
    max_jobs = 20
    job_timeout = 120
