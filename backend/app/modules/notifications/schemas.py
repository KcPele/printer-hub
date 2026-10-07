import uuid
from datetime import datetime

from pydantic import ConfigDict

from app.core.schemas import ApiModel


class NotificationRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID | None
    type: str
    title: str
    body: str
    data: dict[str, str]
    read_at: datetime | None
    created_at: datetime


class UnreadCount(ApiModel):
    unread: int
