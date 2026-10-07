import enum
import uuid
from typing import Any

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, CreatedAtMixin, IdMixin, str_enum


class AuditOutcome(enum.StrEnum):
    SUCCESS = "success"
    FAILURE = "failure"


class AuditLog(Base, IdMixin, CreatedAtMixin):
    """Append-only record of who did what to which target (FRD §27)."""

    __tablename__ = "audit_logs"
    __table_args__ = (Index("ix_audit_logs_organization_id_id", "organization_id", "id"),)

    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    # Dotted verb, for example `printer.created` or `member.role_changed`.
    action: Mapped[str] = mapped_column(String(100), index=True)
    target_type: Mapped[str] = mapped_column(String(50))
    target_id: Mapped[uuid.UUID | None]
    outcome: Mapped[AuditOutcome] = mapped_column(str_enum(AuditOutcome, length=16))
    detail: Mapped[dict[str, Any]] = mapped_column(default=dict)
    ip: Mapped[str | None] = mapped_column(String(64))
    user_agent: Mapped[str | None] = mapped_column(String(500))
