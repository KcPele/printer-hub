import enum
import uuid
from typing import Any

from sqlalchemy import ForeignKey, Index, String, false
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin, str_enum
from app.modules.jobs.models import JobType


class PresetScope(enum.StrEnum):
    # Visible to its owner only.
    PERSONAL = "personal"
    # Visible to every member; managed by administrators.
    ORGANIZATION = "organization"


class Preset(Base, IdMixin, TimestampMixin):
    """Saved job settings (FRD §17)."""

    __tablename__ = "presets"
    __table_args__ = (
        Index("ix_presets_organization_id_owner_user_id", "organization_id", "owner_user_id"),
    )

    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    # Set for personal presets, null for organization presets.
    owner_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE")
    )
    scope: Mapped[PresetScope] = mapped_column(str_enum(PresetScope))
    type: Mapped[JobType] = mapped_column(str_enum(JobType))
    name: Mapped[str] = mapped_column(String(100))
    # Same shape as the settings of a job of this `type`.
    settings: Mapped[dict[str, Any]]
    # Null applies the preset to every printer.
    printer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("printers.id", ondelete="CASCADE")
    )
    # The preset a client preselects for its scope, printer, and type (FR-AUT-003).
    is_default: Mapped[bool] = mapped_column(default=False, server_default=false())
