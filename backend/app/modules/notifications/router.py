import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.deps import SessionDep
from app.core.pagination import Page, PageParams
from app.modules.auth.deps import CurrentUser
from app.modules.notifications import service
from app.modules.notifications.schemas import NotificationRead, UnreadCount

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
async def list_notifications(
    user: CurrentUser,
    session: SessionDep,
    params: Annotated[PageParams, Depends()],
    unread_only: bool = False,
) -> Page[NotificationRead]:
    """The caller's notifications across all organizations, newest first."""
    items, next_cursor = await service.list_for_user(
        session, user.id, params=params, unread_only=unread_only
    )
    return Page(
        items=[NotificationRead.model_validate(item) for item in items], next_cursor=next_cursor
    )


@router.get("/unread-count")
async def get_unread_count(user: CurrentUser, session: SessionDep) -> UnreadCount:
    return UnreadCount(unread=await service.unread_count(session, user.id))


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(user: CurrentUser, session: SessionDep) -> None:
    await service.mark_all_read(session, user.id)


@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> NotificationRead:
    notification = await service.mark_read(
        session, user_id=user.id, notification_id=notification_id
    )
    return NotificationRead.model_validate(notification)
