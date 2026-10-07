import uuid
from datetime import datetime
from typing import Literal

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel
from app.modules.capabilities.schemas import PrinterCapabilities
from app.modules.connections.schemas import ConnectionCreate, ConnectionRead
from app.modules.printers.models import PrinterStatus


class Consumable(ApiModel):
    """Toner, ink, drum, and similar supplies (FR-MON-002)."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(max_length=100)
    kind: str = Field(max_length=32, description="toner, ink, drum, waste_toner, fuser, ...")
    color: str | None = Field(default=None, max_length=32)
    level_percent: int | None = Field(default=None, ge=0, le=100)
    state: Literal["ok", "low", "empty", "unknown"] = "unknown"


class TrayStatus(ApiModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(max_length=64)
    name: str = Field(max_length=100)
    media_size: str | None = Field(default=None, max_length=64)
    media_type: str | None = Field(default=None, max_length=64)
    state: Literal["ok", "low", "empty", "open", "unknown"] = "unknown"


class DeviceAlert(ApiModel):
    """FR-MON-004."""

    model_config = ConfigDict(extra="forbid")

    code: str = Field(max_length=64, description="For example media-jam, toner-low, door-open")
    severity: Literal["info", "warning", "error"] = "warning"
    message: str | None = Field(default=None, max_length=300)


class PrinterStatusDetail(ApiModel):
    model_config = ConfigDict(extra="forbid")

    consumables: list[Consumable] = Field(default_factory=list, max_length=32)
    trays: list[TrayStatus] = Field(default_factory=list, max_length=32)
    alerts: list[DeviceAlert] = Field(default_factory=list, max_length=32)
    scanner_state: Literal["idle", "busy", "error", "unavailable", "unknown"] = "unknown"


class PrinterCreate(ApiModel):
    friendly_name: str = Field(min_length=1, max_length=200)
    manufacturer: str | None = Field(default=None, max_length=100)
    model: str | None = Field(default=None, max_length=200)
    serial_number: str | None = Field(default=None, min_length=1, max_length=100)
    location: str | None = Field(default=None, max_length=200)
    capabilities: PrinterCapabilities | None = None
    # Every connection path the client verified while adding the printer.
    connections: list[ConnectionCreate] = Field(default_factory=list, max_length=16)


class PrinterUpdate(ApiModel):
    """Fields left out are unchanged."""

    friendly_name: str | None = Field(default=None, min_length=1, max_length=200)
    manufacturer: str | None = Field(default=None, max_length=100)
    model: str | None = Field(default=None, max_length=200)
    serial_number: str | None = Field(default=None, min_length=1, max_length=100)
    location: str | None = Field(default=None, max_length=200)
    auto_fallback_enabled: bool | None = None


class PrinterStatusReport(ApiModel):
    """Printer state as observed by a client on the local network."""

    status: PrinterStatus
    detail: PrinterStatusDetail | None = Field(
        default=None, description="Omit to keep the last reported detail"
    )


class PrinterRead(ApiModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    friendly_name: str
    manufacturer: str | None
    model: str | None
    serial_number: str | None
    location: str | None
    capabilities: PrinterCapabilities | None
    capabilities_updated_at: datetime | None
    status: PrinterStatus
    status_detail: PrinterStatusDetail
    auto_fallback_enabled: bool
    last_seen_at: datetime | None
    connections: list[ConnectionRead]
    default_connection_id: uuid.UUID | None = Field(
        description="The most preferred connection, if any"
    )
    created_at: datetime
    updated_at: datetime
