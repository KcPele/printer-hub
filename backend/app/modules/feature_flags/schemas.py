import uuid
from datetime import datetime

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel


class FeatureFlagWrite(ApiModel):
    description: str = Field(default="", max_length=500)
    enabled: bool = False


class FeatureFlagOverrideWrite(ApiModel):
    enabled: bool


class FeatureFlagOverrideRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    organization_id: uuid.UUID
    enabled: bool


class FeatureFlagRead(ApiModel):
    key: str
    description: str
    enabled: bool
    overrides: list[FeatureFlagOverrideRead]
    updated_at: datetime


class ResolvedFlags(ApiModel):
    flags: dict[str, bool] = Field(
        description="Every known flag with its value for this organization",
        examples=[{"direct_ipp": True, "scan_to_email": False}],
    )
