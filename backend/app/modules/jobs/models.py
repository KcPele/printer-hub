import enum
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import ForeignKey, Index, String, false, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, CreatedAtMixin, IdMixin, TimestampMixin, str_enum


class JobType(enum.StrEnum):
    PRINT = "print"
    SCAN = "scan"
    COPY = "copy"


class ExecutionMode(enum.StrEnum):
    # The client talks to the printer and reports state (FR-MOB-001).
    LOCAL = "local"
    # Document or instructions pass through PrinterHub services.
    CLOUD = "cloud"


class JobStatus(enum.StrEnum):
    QUEUED = "queued"
    PROCESSING = "processing"
    SCANNING = "scanning"
    PRINTING = "printing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Job(Base, IdMixin, TimestampMixin):
    """A print, scan, or copy job and its current state (FRD §15)."""

    __tablename__ = "jobs"
    __table_args__ = (
        Index("ix_jobs_organization_id_user_id", "organization_id", "user_id"),
        Index("ix_jobs_organization_id_status", "organization_id", "status"),
    )

    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    printer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("printers.id", ondelete="CASCADE"), index=True
    )
    # The client installation executing the job.
    device_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("devices.id", ondelete="SET NULL")
    )
    type: Mapped[JobType] = mapped_column(str_enum(JobType))
    execution_mode: Mapped[ExecutionMode] = mapped_column(str_enum(ExecutionMode))
    status: Mapped[JobStatus] = mapped_column(str_enum(JobStatus), default=JobStatus.QUEUED)
    # Display name, usually the file name. Kept here because a local-mode
    # document may never be registered with the backend.
    title: Mapped[str | None] = mapped_column(String(255))
    # Shape depends on `type`; see `jobs.schemas`.
    settings: Mapped[dict[str, Any]]
    document_id: Mapped[uuid.UUID | None]
    output_document_id: Mapped[uuid.UUID | None]
    connection_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("connections.id", ondelete="SET NULL")
    )
    # Snapshot, so history stays readable after the connection is removed.
    connection_type: Mapped[str | None] = mapped_column(String(32))
    fallback_occurred: Mapped[bool] = mapped_column(default=False, server_default=false())
    retry_of_job_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("jobs.id", ondelete="SET NULL")
    )
    # The job identifier assigned by the printer, for example the IPP job-id.
    printer_job_ref: Mapped[str | None] = mapped_column(String(128))
    error_code: Mapped[str | None] = mapped_column(String(100))
    error_message: Mapped[str | None] = mapped_column(String(500))
    page_count: Mapped[int | None]
    submitted_at: Mapped[datetime] = mapped_column(server_default=func.now())
    started_at: Mapped[datetime | None]
    completed_at: Mapped[datetime | None]


class JobEvent(Base, IdMixin, CreatedAtMixin):
    """One reported state change or attempt. Append-only."""

    __tablename__ = "job_events"

    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id", ondelete="CASCADE"), index=True)
    status: Mapped[JobStatus] = mapped_column(str_enum(JobStatus))
    connection_id: Mapped[uuid.UUID | None]
    connection_type: Mapped[str | None] = mapped_column(String(32))
    error_code: Mapped[str | None] = mapped_column(String(100))
    error_message: Mapped[str | None] = mapped_column(String(500))
    reported_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    detail: Mapped[dict[str, Any]] = mapped_column(default=dict)
    # When the client observed the change; may be well before `created_at` after offline use.
    occurred_at: Mapped[datetime]
