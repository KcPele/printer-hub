"""Job request and response shapes.

Create and read models are discriminated unions on `type`, so each job type
carries its own typed `settings` in the OpenAPI contract.
"""

import uuid
from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel
from app.modules.capabilities.schemas import DuplexMode
from app.modules.jobs.models import ExecutionMode, JobStatus, JobType

ColorMode = Literal["auto", "color", "monochrome"]
Scaling = Literal["actual", "fit", "shrink", "custom"]
_PAGE_RANGES = r"^\d+(-\d+)?(,\d+(-\d+)?)*$"


class _Settings(ApiModel):
    model_config = ConfigDict(extra="forbid")


class PrintSettings(_Settings):
    """FR-PRN-005 to FR-PRN-016, FR-PRN-024."""

    copies: int = Field(default=1, ge=1, le=9999)
    color_mode: ColorMode = "auto"
    duplex: DuplexMode = DuplexMode.ONE_SIDED
    page_ranges: str | None = Field(
        default=None, pattern=_PAGE_RANGES, max_length=200, examples=["1-3,5"]
    )
    media_size: str | None = Field(default=None, max_length=64)
    media_type: str | None = Field(default=None, max_length=64)
    tray: str | None = Field(default=None, max_length=64)
    orientation: Literal["auto", "portrait", "landscape"] = "auto"
    scaling: Scaling = "fit"
    scale_percent: int | None = Field(default=None, ge=10, le=400)
    collate: bool = True
    quality: str | None = Field(default=None, max_length=32)
    finishing: list[str] = Field(default_factory=list, max_length=16)
    # The PIN itself stays on the device (FR-PRN-027); this only records that one was used.
    secure_print: bool = False


class ScanSettings(_Settings):
    """FR-SCN-004 to FR-SCN-008."""

    source: Literal["auto", "platen", "adf"] = "auto"
    duplex: bool = False
    color_mode: Literal["auto", "color", "grayscale", "black_and_white"] = "auto"
    resolution_dpi: int = Field(default=300, ge=50, le=2400)
    format: Literal["application/pdf", "image/jpeg", "image/png", "image/tiff"] = "application/pdf"
    media_size: str | None = Field(default=None, max_length=64)
    searchable_pdf: bool = False


class CopySettings(_Settings):
    """FR-CPY-002."""

    copies: int = Field(default=1, ge=1, le=9999)
    color_mode: ColorMode = "auto"
    source_duplex: bool = False
    output_duplex: DuplexMode = DuplexMode.ONE_SIDED
    media_size: str | None = Field(default=None, max_length=64)
    tray: str | None = Field(default=None, max_length=64)
    scaling: Scaling = "actual"
    scale_percent: int | None = Field(default=None, ge=10, le=400)
    collate: bool = True
    # How the client performs the copy (FR-CPY-003).
    method: Literal["native", "scan_then_print"] = "scan_then_print"


# --- Create ------------------------------------------------------------------


class _JobCreateBase(ApiModel):
    id: uuid.UUID | None = Field(
        default=None,
        description="Client-generated ID, so a job created offline keeps its identity",
    )
    printer_id: uuid.UUID
    execution_mode: ExecutionMode = ExecutionMode.LOCAL
    title: str | None = Field(default=None, max_length=255)
    document_id: uuid.UUID | None = None
    connection_id: uuid.UUID | None = Field(
        default=None, description="The connection the client intends to use first"
    )
    page_count: int | None = Field(default=None, ge=0, le=100_000)
    submitted_at: datetime | None = Field(
        default=None, description="When the user submitted the job, if earlier than now"
    )


class PrintJobCreate(_JobCreateBase):
    type: Literal[JobType.PRINT]
    settings: PrintSettings = Field(default_factory=PrintSettings)


class ScanJobCreate(_JobCreateBase):
    type: Literal[JobType.SCAN]
    settings: ScanSettings = Field(default_factory=ScanSettings)


class CopyJobCreate(_JobCreateBase):
    type: Literal[JobType.COPY]
    settings: CopySettings = Field(default_factory=CopySettings)


JobCreate = Annotated[PrintJobCreate | ScanJobCreate | CopyJobCreate, Field(discriminator="type")]


# --- Read --------------------------------------------------------------------


class _JobReadBase(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID
    user_id: uuid.UUID | None
    printer_id: uuid.UUID
    device_id: uuid.UUID | None
    execution_mode: ExecutionMode
    status: JobStatus
    title: str | None
    document_id: uuid.UUID | None
    output_document_id: uuid.UUID | None
    connection_id: uuid.UUID | None
    connection_type: str | None
    fallback_occurred: bool = Field(
        description="True when the job moved to a different connection after its first attempt"
    )
    retry_of_job_id: uuid.UUID | None
    printer_job_ref: str | None
    error_code: str | None
    error_message: str | None
    page_count: int | None
    submitted_at: datetime
    started_at: datetime | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PrintJobRead(_JobReadBase):
    type: Literal[JobType.PRINT]
    settings: PrintSettings


class ScanJobRead(_JobReadBase):
    type: Literal[JobType.SCAN]
    settings: ScanSettings


class CopyJobRead(_JobReadBase):
    type: Literal[JobType.COPY]
    settings: CopySettings


JobRead = Annotated[PrintJobRead | ScanJobRead | CopyJobRead, Field(discriminator="type")]


# --- Events ------------------------------------------------------------------


class JobEventCreate(ApiModel):
    """A state change observed by the client executing the job."""

    status: JobStatus
    connection_id: uuid.UUID | None = Field(
        default=None, description="The connection used for this attempt"
    )
    occurred_at: datetime | None = Field(
        default=None, description="When it happened on the device; defaults to now"
    )
    error_code: str | None = Field(
        default=None, max_length=100, examples=["ipp.client-error-not-possible"]
    )
    error_message: str | None = Field(default=None, max_length=500)
    printer_job_ref: str | None = Field(default=None, max_length=128)
    page_count: int | None = Field(default=None, ge=0, le=100_000)
    output_document_id: uuid.UUID | None = None
    # Small progress facts, for example pages or bytes received (FR-SCN-023).
    detail: dict[str, Any] = Field(default_factory=dict, max_length=16)


class JobEventRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: JobStatus
    connection_id: uuid.UUID | None
    connection_type: str | None
    error_code: str | None
    error_message: str | None
    reported_by_user_id: uuid.UUID | None
    detail: dict[str, Any]
    occurred_at: datetime
    created_at: datetime


# --- Batch sync --------------------------------------------------------------


class JobSyncItem(ApiModel):
    idempotency_key: str = Field(min_length=1, max_length=255)
    job: JobCreate
    events: list[JobEventCreate] = Field(default_factory=list, max_length=50)


class JobSyncRequest(ApiModel):
    """Jobs created while offline, with the state changes recorded on the device."""

    items: list[JobSyncItem] = Field(min_length=1, max_length=100)


class JobSyncError(ApiModel):
    code: str
    detail: str | None


class JobSyncResult(ApiModel):
    idempotency_key: str
    outcome: Literal["created", "replayed", "failed"]
    job: JobRead | None = None
    error: JobSyncError | None = None


class JobSyncResponse(ApiModel):
    results: list[JobSyncResult]
