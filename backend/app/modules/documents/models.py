import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Index, String, Text, false
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin, str_enum


class DocumentSource(enum.StrEnum):
    UPLOAD = "upload"
    PRINTER_SCAN = "printer_scan"
    # Captured with the phone camera; never presented as a printer scan (FR-SCN-028).
    CAMERA_SCAN = "camera_scan"


class StorageMode(enum.StrEnum):
    # Bytes stay on the client device; the backend holds metadata only (FR-PRN-030).
    LOCAL = "local"
    # Bytes are in object storage.
    CLOUD = "cloud"


class UploadStatus(enum.StrEnum):
    NOT_APPLICABLE = "not_applicable"
    PENDING = "pending"
    UPLOADED = "uploaded"


class Document(Base, IdMixin, TimestampMixin):
    __tablename__ = "documents"
    __table_args__ = (
        Index("ix_documents_organization_id_owner_id", "organization_id", "owner_id"),
        Index("ix_documents_retention_expires_at", "retention_expires_at"),
    )

    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    owner_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    file_name: Mapped[str] = mapped_column(String(255))
    mime_type: Mapped[str] = mapped_column(String(127))
    size_bytes: Mapped[int] = mapped_column(BigInteger)
    page_count: Mapped[int | None]
    source: Mapped[DocumentSource] = mapped_column(str_enum(DocumentSource))
    storage_mode: Mapped[StorageMode] = mapped_column(str_enum(StorageMode))
    storage_key: Mapped[str | None] = mapped_column(String(500))
    upload_status: Mapped[UploadStatus] = mapped_column(str_enum(UploadStatus))
    checksum_sha256: Mapped[str | None] = mapped_column(String(64))
    # False keeps it to its owner; true lets every member of the organization see it.
    shared: Mapped[bool] = mapped_column(default=False, server_default=false())
    # Lowercased.
    tags: Mapped[list[str]] = mapped_column(default=list)
    ocr_text: Mapped[str | None] = mapped_column(Text)
    source_printer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("printers.id", ondelete="SET NULL")
    )
    # When set, the retention task deletes the document after this time (FR-DOC-008).
    retention_expires_at: Mapped[datetime | None]
    deleted_at: Mapped[datetime | None]
