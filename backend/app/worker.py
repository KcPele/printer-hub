"""Background worker. Run with: arq app.worker.WorkerSettings"""

import uuid
from datetime import timedelta
from typing import TYPE_CHECKING, Any, ClassVar, cast

import structlog
from arq import Retry, cron
from arq.connections import RedisSettings

from app.adapters.email import get_email_sender
from app.adapters.email.base import EmailMessage
from app.adapters.storage import get_object_storage
from app.core import idempotency
from app.core.config import get_settings
from app.core.db import get_engine, get_session_factory, session_scope
from app.core.logging import configure_logging
from app.core.tasks import get_task_queue
from app.modules.auth import email_codes
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


MAX_EMAIL_ATTEMPTS = 5
_EMAIL_RETRY_BASE_SECONDS = 20


async def send_email(ctx: dict[str, Any], to: str, subject: str, text: str) -> None:
    """Send one email, retrying with a growing delay while the mail server is unreachable."""
    attempt = int(ctx.get("job_try", 1))
    try:
        await get_email_sender().send(EmailMessage(to=to, subject=subject, text=text))
    except Exception as error:
        if attempt >= MAX_EMAIL_ATTEMPTS:
            log.error("email_gave_up", subject=subject, error=type(error).__name__)
            return
        log.warning("email_failed", subject=subject, attempt=attempt, error=type(error).__name__)
        raise Retry(defer=_EMAIL_RETRY_BASE_SECONDS * attempt) from error


async def delete_stored_objects(_ctx: dict[str, Any], keys: list[str]) -> None:
    """Delete files from object storage after their documents were deleted."""
    storage = get_object_storage()
    for key in keys:
        await storage.delete(key)


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
        await email_codes.purge_expired(session)
        await auth.purge_dead_sessions(session)
        await pairing.purge_expired(session)
        await organizations.purge_stale_invitations(session)


async def _startup(_ctx: dict[str, Any]) -> None:
    configure_logging()


async def _shutdown(_ctx: dict[str, Any]) -> None:
    await get_engine().dispose()


class WorkerSettings:
    functions: ClassVar[list[Any]] = [push_notification, send_email, delete_stored_objects]
    cron_jobs: ClassVar[list[Any]] = [
        cron(cast("WorkerCoroutine", purge_expired_documents), minute={5, 20, 35, 50}),
        cron(cast("WorkerCoroutine", purge_expired_records), hour=3, minute=40),
    ]
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url)
    on_startup = _startup
    on_shutdown = _shutdown
    max_jobs = 20
    max_tries = MAX_EMAIL_ATTEMPTS
    job_timeout = 120
