"""In-app notifications and their delivery as push (FRD §24, FR-MOB-020).

A notification is a row the user can read in the app and a push to each of
their devices. The push carries the notification's `type` and IDs as data, so
an open app can refresh the affected screen.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.push import get_push_provider
from app.adapters.push.base import PushMessage, PushOutcome
from app.core import tasks
from app.core.errors import NotFoundError
from app.core.pagination import PageParams, paginate
from app.modules.devices import service as devices
from app.modules.notifications.models import Notification, NotificationType
from app.modules.users import service as users
from app.modules.users.schemas import UserPreferences

PUSH_TASK = "push_notification"


async def notify(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    type: NotificationType,
    title: str,
    body: str,
    organization_id: uuid.UUID | None = None,
    data: dict[str, str] | None = None,
) -> Notification:
    """Create a notification and queue its push.

    A type the user has muted still appears in their in-app list; it is only
    kept off their devices.
    """
    notification = Notification(
        user_id=user_id,
        organization_id=organization_id,
        type=type.value,
        title=title,
        body=body,
        data=data or {},
    )
    session.add(notification)
    await session.flush()

    user = await users.get_by_id(session, user_id)
    muted = (
        UserPreferences.model_validate(user.preferences).muted_notification_types if user else []
    )
    if type.value not in muted:
        tasks.enqueue(session, PUSH_TASK, notification_id=str(notification.id))
    return notification


async def deliver_push(
    session: AsyncSession,
    notification_id: uuid.UUID,
    *,
    device_ids: list[uuid.UUID] | None = None,
) -> list[uuid.UUID]:
    """Push a notification to the user's devices.

    Returns the devices where delivery failed for a temporary reason, so the
    caller can try those again. A device whose token is permanently invalid
    has the token cleared.
    """
    notification = await session.get(Notification, notification_id)
    if notification is None:
        return []
    message = PushMessage(
        title=notification.title,
        body=notification.body,
        data={
            **notification.data,
            "type": notification.type,
            "notification_id": str(notification.id),
        },
    )
    provider = get_push_provider()
    retry: list[uuid.UUID] = []
    for device in await devices.list_push_targets(session, notification.user_id):
        if device_ids is not None and device.id not in device_ids:
            continue
        assert device.push_token is not None  # noqa: S101 - filtered by list_push_targets
        outcome = await provider.send(device.push_token, message)
        if outcome is PushOutcome.INVALID_TOKEN:
            await devices.clear_push_token(session, device.id)
        elif outcome is PushOutcome.FAILED:
            retry.append(device.id)
    return retry


async def list_for_user(
    session: AsyncSession, user_id: uuid.UUID, *, params: PageParams, unread_only: bool = False
) -> tuple[list[Notification], str | None]:
    stmt = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        stmt = stmt.where(Notification.read_at.is_(None))
    return await paginate(session, stmt, Notification.id, params)


async def unread_count(session: AsyncSession, user_id: uuid.UUID) -> int:
    count = await session.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user_id, Notification.read_at.is_(None))
    )
    return count or 0


async def mark_read(
    session: AsyncSession, *, user_id: uuid.UUID, notification_id: uuid.UUID
) -> Notification:
    notification = await session.scalar(
        select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user_id
        )
    )
    if notification is None:
        raise NotFoundError("notification.not_found", "Notification not found.")
    if notification.read_at is None:
        notification.read_at = datetime.now(UTC)
        await session.flush()
    return notification


async def mark_all_read(session: AsyncSession, user_id: uuid.UUID) -> None:
    await session.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.read_at.is_(None))
        .values(read_at=datetime.now(UTC))
    )
