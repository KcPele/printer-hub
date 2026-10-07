import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.core.permissions import Role
from app.modules.users.schemas import UserSummary


class OrganizationSettings(BaseModel):
    """Organization policy. Job and document creation enforce these (FRD §19, §41)."""

    max_copies_per_job: int | None = Field(default=None, ge=1, le=9999)
    color_printing_roles: list[Role] = Field(default_factory=lambda: list(Role))
    # `local_only` keeps document bytes on client devices (FR-SEC-011).
    document_storage_mode: Literal["local_only", "cloud_allowed"] = "cloud_allowed"
    # Days a cloud document is kept. None keeps it until someone deletes it (FR-DOC-008).
    document_retention_days: int | None = Field(default=None, ge=0, le=3650)


class OrganizationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)


class OrganizationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    settings: OrganizationSettings | None = None


class OrganizationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    slug: str
    settings: OrganizationSettings
    created_at: datetime
    role: Role = Field(description="The caller's role in this organization")


class MemberRead(BaseModel):
    user: UserSummary
    role: Role
    joined_at: datetime


class MemberUpdate(BaseModel):
    role: Role


class InvitationCreate(BaseModel):
    email: EmailStr
    role: Role = Role.USER


class InvitationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    role: Role
    invited_by_user_id: uuid.UUID | None
    expires_at: datetime
    created_at: datetime


class InvitationCreated(InvitationRead):
    token: str = Field(description="Shown once. Share it with the invited person.")


class InvitationAccept(BaseModel):
    token: str = Field(min_length=1, max_length=512)
