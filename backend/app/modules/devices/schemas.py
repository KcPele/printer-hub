import uuid
from datetime import datetime
from typing import Self

from pydantic import ConfigDict, Field, computed_field, model_validator

from app.core.schemas import ApiModel
from app.modules.devices.models import DevicePlatform, PushProviderName


class _PushFields(ApiModel):
    push_provider: PushProviderName | None = None
    push_token: str | None = Field(default=None, min_length=1, max_length=512)

    @model_validator(mode="after")
    def _provider_and_token_travel_together(self) -> Self:
        if (self.push_provider is None) != (self.push_token is None):
            raise ValueError("push_provider and push_token must be set together")
        return self


class DeviceRegister(_PushFields):
    installation_id: str = Field(min_length=8, max_length=128)
    platform: DevicePlatform
    name: str | None = Field(
        default=None,
        max_length=200,
        description="Leave out to keep the name the device already has",
    )
    model: str | None = Field(default=None, max_length=200)
    os_version: str | None = Field(default=None, max_length=64)
    app_version: str | None = Field(default=None, max_length=64)


class DeviceUpdate(_PushFields):
    """Fields left out are unchanged. Send both push fields as null to stop push."""

    name: str | None = Field(default=None, max_length=200)
    os_version: str | None = Field(default=None, max_length=64)
    app_version: str | None = Field(default=None, max_length=64)


class DeviceRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    installation_id: str
    platform: DevicePlatform
    name: str | None
    model: str | None
    os_version: str | None
    app_version: str | None
    push_provider: PushProviderName | None
    # The token itself is write-only.
    push_token: str | None = Field(exclude=True)
    last_seen_at: datetime
    created_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def push_enabled(self) -> bool:
        return self.push_token is not None
