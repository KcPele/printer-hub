import uuid
from datetime import datetime
from typing import Literal

from pydantic import ConfigDict, EmailStr, Field

from app.core.permissions import Role
from app.core.schemas import ApiModel
from app.modules.users.schemas import UserSummary


class OrganizationSettings(ApiModel):
    """Organization policy. Job and document creation enforce these (FRD §19, §41)."""

    max_copies_per_job: int | None = Field(default=None, ge=1, le=9999)
    color_printing_roles: list[Role] = Field(default_factory=lambda: list(Role))
    # `local_only` keeps document bytes on client devices (FR-SEC-011).
    document_storage_mode: Literal["local_only", "cloud_allowed"] = "cloud_allowed"
    # Days a cloud document is kept. None keeps it until someone deletes it (FR-DOC-008).
    document_retention_days: int | None = Field(default=None, ge=0, le=3650)


class OrganizationCreate(ApiModel):
    name: str = Field(min_length=1, max_length=200)


class OrganizationUpdate(ApiModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    settings: OrganizationSettings | None = None


class OrganizationRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    slug: str
    settings: OrganizationSettings
    created_at: datetime
    role: Role = Field(description="The caller's role in this organization")


class MemberRead(ApiModel):
    user: UserSummary
    role: Role
    joined_at: datetime


class MemberUpdate(ApiModel):
    role: Role


class InvitationCreate(ApiModel):
    email: EmailStr
    role: Role = Role.USER


class InvitationRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    role: Role
    invited_by_user_id: uuid.UUID | None
    expires_at: datetime
    created_at: datetime


class InvitationCreated(InvitationRead):
    token: str = Field(description="Shown once. Share it with the invited person.")


class MyInvitationRead(ApiModel):
    """An invitation as seen by the person invited."""

    id: uuid.UUID
    organization_id: uuid.UUID
    organization_name: str
    role: Role
    expires_at: datetime
    created_at: datetime


class InvitationAccept(ApiModel):
    token: str = Field(min_length=1, max_length=512)
