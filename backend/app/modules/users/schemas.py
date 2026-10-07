import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class UserPreferences(BaseModel):
    theme: Literal["system", "light", "dark"] = "system"
    default_organization_id: uuid.UUID | None = None
    default_printer_id: uuid.UUID | None = None
    # Notification types the user does not want pushed to their devices.
    muted_notification_types: list[str] = Field(default_factory=list, max_length=50)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    email_verified_at: datetime | None = Field(
        description="Null until the email address is verified with the emailed code"
    )
    name: str
    preferences: UserPreferences
    is_superuser: bool
    created_at: datetime


class UserUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    preferences: UserPreferences | None = None


class UserSummary(BaseModel):
    """The public face of a user inside an organization."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    name: str
