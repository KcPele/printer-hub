import uuid
from datetime import datetime
from typing import Annotated

from pydantic import AfterValidator, ConfigDict, Field

from app.core.schemas import ApiModel
from app.modules.documents.models import DocumentSource, StorageMode, UploadStatus

# FR-PRN-001: directly printable formats plus those a client can convert.
ALLOWED_MIME_TYPES = frozenset(
    {
        "application/pdf",
        "image/jpeg",
        "image/png",
        "image/tiff",
        "text/plain",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    }
)


def _normalize_tags(tags: list[str]) -> list[str]:
    cleaned = [tag.strip().lower() for tag in tags]
    if any(not tag or len(tag) > 50 for tag in cleaned):
        raise ValueError("tags must be 1 to 50 characters")
    return list(dict.fromkeys(cleaned))


Tags = Annotated[list[str], Field(max_length=20), AfterValidator(_normalize_tags)]


class DocumentCreate(ApiModel):
    id: uuid.UUID | None = Field(
        default=None, description="Client-generated ID, for documents created offline"
    )
    file_name: str = Field(min_length=1, max_length=255)
    mime_type: str = Field(max_length=127)
    size_bytes: int = Field(ge=1)
    page_count: int | None = Field(default=None, ge=0, le=100_000)
    source: DocumentSource = DocumentSource.UPLOAD
    storage_mode: StorageMode = StorageMode.LOCAL
    checksum_sha256: str | None = Field(default=None, pattern=r"^[0-9a-f]{64}$")
    tags: Tags = Field(default_factory=list)
    source_printer_id: uuid.UUID | None = None
    # Text recognized on the device. Accepted for cloud documents only: for a
    # local document the content, including its text, stays on the device.
    ocr_text: str | None = Field(default=None, max_length=1_000_000)


class DocumentUpdate(ApiModel):
    """Fields left out are unchanged."""

    file_name: str | None = Field(default=None, min_length=1, max_length=255)
    tags: Tags | None = None
    page_count: int | None = Field(default=None, ge=0, le=100_000)
    ocr_text: str | None = Field(default=None, max_length=1_000_000)


class DocumentRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID
    owner_id: uuid.UUID | None
    file_name: str
    mime_type: str
    size_bytes: int
    page_count: int | None
    source: DocumentSource
    storage_mode: StorageMode
    upload_status: UploadStatus
    checksum_sha256: str | None
    tags: list[str]
    has_ocr_text: bool
    source_printer_id: uuid.UUID | None
    retention_expires_at: datetime | None
    created_at: datetime
    updated_at: datetime


class UploadInstructions(ApiModel):
    """Send the file bytes with this request, then call `complete-upload`."""

    url: str
    method: str
    headers: dict[str, str]
    expires_at: datetime


class DocumentCreated(DocumentRead):
    upload: UploadInstructions | None = Field(
        description="Present for cloud documents; null for local ones"
    )


class DownloadLink(ApiModel):
    url: str
    expires_at: datetime
