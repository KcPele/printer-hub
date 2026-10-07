import enum
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import ForeignKey, Index, String, text, true
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin, str_enum


class PrinterStatus(enum.StrEnum):
    ONLINE = "online"
    OFFLINE = "offline"
    SLEEPING = "sleeping"
    UNREACHABLE = "unreachable"
    UNKNOWN = "unknown"


class Printer(Base, IdMixin, TimestampMixin):
    """One physical device, however many ways there are to reach it (FR-CON-008)."""

    __tablename__ = "printers"
    __table_args__ = (
        # A device is registered once per organization (FR-MOB-003).
        Index(
            "uq_printers_organization_id_serial_number",
            "organization_id",
            "serial_number",
            unique=True,
            postgresql_where=text("serial_number IS NOT NULL AND deleted_at IS NULL"),
        ),
    )

    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    friendly_name: Mapped[str] = mapped_column(String(200))
    manufacturer: Mapped[str | None] = mapped_column(String(100))
    model: Mapped[str | None] = mapped_column(String(200))
    serial_number: Mapped[str | None] = mapped_column(String(100))
    location: Mapped[str | None] = mapped_column(String(200))
    # Shape: `capabilities.schemas.PrinterCapabilities`. Null until a client probes the device.
    capabilities: Mapped[dict[str, Any] | None]
    capabilities_updated_at: Mapped[datetime | None]
    status: Mapped[PrinterStatus] = mapped_column(
        str_enum(PrinterStatus), default=PrinterStatus.UNKNOWN
    )
    # Shape: `printers.schemas.PrinterStatusDetail`.
    status_detail: Mapped[dict[str, Any]] = mapped_column(
        default=dict, server_default=text("'{}'::jsonb")
    )
    auto_fallback_enabled: Mapped[bool] = mapped_column(default=True, server_default=true())
    last_seen_at: Mapped[datetime | None]
    created_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    deleted_at: Mapped[datetime | None]
