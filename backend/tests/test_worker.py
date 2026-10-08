import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from arq import Retry
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app import worker
from app.adapters.email.memory import MemoryEmailSender
from app.adapters.push.base import PushOutcome
from app.adapters.push.memory import MemoryPushProvider
from app.adapters.storage.memory import MemoryStorage
from app.core import idempotency
from app.core.db import session_scope
from app.core.idempotency import IdempotencyRecord
from app.core.tasks import MemoryTaskQueue, enqueue
from app.modules.auth.models import UserSession
from app.modules.devices.models import Device, DevicePlatform, PushProviderName
from app.modules.notifications import service as notifications
from app.modules.notifications.models import NotificationType
from tests.factories import auth_headers, create_user


@pytest.fixture(autouse=True)
def _worker_uses_the_test_transaction(
    monkeypatch: pytest.MonkeyPatch, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    monkeypatch.setattr(worker, "get_session_factory", lambda: session_factory)


async def _notification_for_device(session: AsyncSession, token: str) -> tuple[Any, Device]:
    user = await create_user(session)
    device = Device(
        user_id=user.id,
        installation_id=f"install-{uuid.uuid4().hex}",
        platform=DevicePlatform.IOS,
        push_provider=PushProviderName.FCM,
        push_token=token,
    )
    session.add(device)
    notification = await notifications.notify(
        session, user_id=user.id, type=NotificationType.JOB_COMPLETED, title="T", body="B"
    )
    return notification, device


async def test_push_task_delivers(session: AsyncSession, push: MemoryPushProvider) -> None:
    notification, _ = await _notification_for_device(session, "token-1")

    await worker.push_notification({}, str(notification.id))

    assert [token for token, _ in push.sent] == ["token-1"]


async def test_push_task_retries_failed_devices_with_backoff(
    session: AsyncSession, push: MemoryPushProvider, task_queue: MemoryTaskQueue
) -> None:
    notification, device = await _notification_for_device(session, "token-flaky")
    push.outcomes = {"token-flaky": PushOutcome.FAILED}

    await worker.push_notification({}, str(notification.id))

    [retry] = task_queue.named("push_notification")
    assert retry.kwargs == {
        "notification_id": str(notification.id),
        "device_ids": [str(device.id)],
        "attempt": 2,
    }
    assert retry.defer_by == timedelta(seconds=30)

    task_queue.enqueued.clear()
    await worker.push_notification({}, str(notification.id), [str(device.id)], 3)
    assert task_queue.enqueued[0].defer_by == timedelta(seconds=120)


async def test_push_task_gives_up_after_the_last_attempt(
    session: AsyncSession, push: MemoryPushProvider, task_queue: MemoryTaskQueue
) -> None:
    notification, device = await _notification_for_device(session, "token-flaky")
    push.outcomes = {"token-flaky": PushOutcome.FAILED}

    await worker.push_notification(
        {}, str(notification.id), [str(device.id)], worker.MAX_PUSH_ATTEMPTS
    )

    assert task_queue.enqueued == []


async def test_enqueue_waits_for_commit(
    session_factory: async_sessionmaker[AsyncSession], task_queue: MemoryTaskQueue
) -> None:
    async with session_scope(session_factory) as work:
        enqueue(work, "example_task", item_id="1")
        assert task_queue.enqueued == []
    assert [task.name for task in task_queue.enqueued] == ["example_task"]

    async def failing_request() -> None:
        async with session_scope(session_factory) as work:
            enqueue(work, "example_task", item_id="2")
            raise RuntimeError("request failed")

    task_queue.enqueued.clear()
    with pytest.raises(RuntimeError):
        await failing_request()
    assert task_queue.enqueued == []


async def test_purge_expired_records(session: AsyncSession) -> None:
    user = await create_user(session)
    await auth_headers(session, user)  # a live session
    long_ago = datetime.now(UTC) - timedelta(days=45)
    session.add(
        UserSession(
            user_id=user.id, refresh_token_hash="a" * 64, expires_at=long_ago, revoked_at=None
        )
    )
    session.add(
        UserSession(
            user_id=user.id,
            refresh_token_hash="b" * 64,
            expires_at=datetime.now(UTC) + timedelta(days=1),
            revoked_at=long_ago,
        )
    )
    await idempotency.claim(session, user_id=user.id, scope="s", key="live", request_hash="h")
    session.add(
        IdempotencyRecord(
            user_id=user.id,
            scope="s",
            key="expired",
            request_hash="h",
            expires_at=datetime.now(UTC) - timedelta(hours=1),
        )
    )
    await session.flush()

    await worker.purge_expired_records({})

    assert await session.scalar(select(func.count()).select_from(UserSession)) == 1
    assert list(await session.scalars(select(IdempotencyRecord.key))) == ["live"]


async def test_purge_expired_documents_with_nothing_to_do() -> None:
    assert await worker.purge_expired_documents({}) == 0


async def test_send_email_task_delivers(mailbox: MemoryEmailSender) -> None:
    await worker.send_email({}, "ada@example.com", "Subject", "Body")

    [message] = mailbox.sent
    assert (message.to, message.subject, message.text) == ("ada@example.com", "Subject", "Body")
    # An email queued before emails had HTML has none, and is sent all the same.
    assert message.html is None


async def test_send_email_task_delivers_the_html_with_the_text(mailbox: MemoryEmailSender) -> None:
    await worker.send_email({}, "ada@example.com", "Subject", "Body", "<p>Body</p>")

    [message] = mailbox.sent
    assert (message.text, message.html) == ("Body", "<p>Body</p>")


async def test_send_email_task_retries_with_a_growing_delay(mailbox: MemoryEmailSender) -> None:
    mailbox.failure = ConnectionError("mail server unreachable")

    with pytest.raises(Retry) as first:
        await worker.send_email({"job_try": 1}, "ada@example.com", "Subject", "Body")
    with pytest.raises(Retry) as third:
        await worker.send_email({"job_try": 3}, "ada@example.com", "Subject", "Body")

    assert first.value.defer_score == 20_000
    assert third.value.defer_score == 60_000


async def test_send_email_task_gives_up_after_the_last_attempt(
    mailbox: MemoryEmailSender,
) -> None:
    mailbox.failure = ConnectionError("mail server unreachable")

    await worker.send_email(
        {"job_try": worker.MAX_EMAIL_ATTEMPTS}, "ada@example.com", "Subject", "Body"
    )

    assert mailbox.sent == []


async def test_delete_stored_objects_task(storage: MemoryStorage) -> None:
    storage.put("a", 1)
    storage.put("b", 1)
    storage.put("keep", 1)

    await worker.delete_stored_objects({}, ["a", "b", "already-gone"])

    assert list(storage.objects) == ["keep"]
