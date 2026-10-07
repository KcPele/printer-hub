import uuid
from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel
from app.modules.jobs.models import JobType
from app.modules.jobs.schemas import CopySettings, PrintSettings, ScanSettings
from app.modules.presets.models import PresetScope


class _PresetCreateBase(ApiModel):
    name: str = Field(min_length=1, max_length=100)
    scope: PresetScope = PresetScope.PERSONAL
    printer_id: uuid.UUID | None = Field(
        default=None, description="Limit the preset to one printer; omit for all printers"
    )
    is_default: bool = False


class PrintPresetCreate(_PresetCreateBase):
    type: Literal[JobType.PRINT]
    settings: PrintSettings = Field(default_factory=PrintSettings)


class ScanPresetCreate(_PresetCreateBase):
    type: Literal[JobType.SCAN]
    settings: ScanSettings = Field(default_factory=ScanSettings)


class CopyPresetCreate(_PresetCreateBase):
    type: Literal[JobType.COPY]
    settings: CopySettings = Field(default_factory=CopySettings)


PresetCreate = Annotated[
    PrintPresetCreate | ScanPresetCreate | CopyPresetCreate, Field(discriminator="type")
]


class PresetUpdate(ApiModel):
    """Fields left out are unchanged. `settings` replaces the stored settings as a whole."""

    name: str | None = Field(default=None, min_length=1, max_length=100)
    settings: dict[str, Any] | None = Field(
        default=None, description="Validated against the preset's job type"
    )
    is_default: bool | None = None


class _PresetReadBase(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID
    owner_user_id: uuid.UUID | None
    scope: PresetScope
    name: str
    printer_id: uuid.UUID | None
    is_default: bool
    created_at: datetime
    updated_at: datetime


class PrintPresetRead(_PresetReadBase):
    type: Literal[JobType.PRINT]
    settings: PrintSettings


class ScanPresetRead(_PresetReadBase):
    type: Literal[JobType.SCAN]
    settings: ScanSettings


class CopyPresetRead(_PresetReadBase):
    type: Literal[JobType.COPY]
    settings: CopySettings


PresetRead = Annotated[
    PrintPresetRead | ScanPresetRead | CopyPresetRead, Field(discriminator="type")
]
