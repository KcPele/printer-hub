import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID | None
    type: str
    title: str
    body: str
    data: dict[str, str]
    read_at: datetime | None
    created_at: datetime


class UnreadCount(BaseModel):
    unread: int
