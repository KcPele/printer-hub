import enum
import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, CreatedAtMixin, IdMixin


class NotificationType(enum.StrEnum):
    JOB_COMPLETED = "job.completed"
    JOB_FAILED = "job.failed"
    JOB_CANCELLED = "job.cancelled"
    SCAN_READY = "scan.ready"
    ORGANIZATION_INVITATION = "organization.invitation"


class Notification(Base, IdMixin, CreatedAtMixin):
    __tablename__ = "notifications"
    __table_args__ = (Index("ix_notifications_user_id_id", "user_id", "id"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    type: Mapped[str] = mapped_column(String(64))
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(String(500))
    # IDs the client needs to open the right screen. String values only, as FCM requires.
    data: Mapped[dict[str, str]] = mapped_column(default=dict)
    read_at: Mapped[datetime | None]
