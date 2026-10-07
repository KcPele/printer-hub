import uuid
from datetime import datetime

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel
from app.modules.connections.models import ConnectionHealth, ConnectionPurpose, ConnectionType


class ConnectionConfiguration(ApiModel):
    """Where and how to reach the printer. Never holds secrets."""

    model_config = ConfigDict(extra="forbid")

    host: str | None = Field(default=None, max_length=255)
    port: int | None = Field(default=None, ge=1, le=65535)
    path: str | None = Field(default=None, max_length=500)
    tls: bool | None = None
    # DNS-SD service instance name, for connections found by discovery.
    service_name: str | None = Field(default=None, max_length=255)
    # Network name, for Wi-Fi Direct.
    ssid: str | None = Field(default=None, max_length=64)
    # Adapter-specific non-secret settings, for example an SMB share name.
    options: dict[str, str] = Field(default_factory=dict, max_length=32)


class ConnectionCredentials(ApiModel):
    """Secrets for a connection. Encrypted at rest; returned only by the credentials endpoint."""

    model_config = ConfigDict(extra="forbid")

    username: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, max_length=1024)
    extra: dict[str, str] = Field(default_factory=dict, max_length=16)


class ConnectionCreate(ApiModel):
    type: ConnectionType
    purposes: list[ConnectionPurpose] = Field(min_length=1, max_length=3)
    configuration: ConnectionConfiguration = Field(default_factory=ConnectionConfiguration)
    credentials: ConnectionCredentials | None = None
    # Omit to add the connection as the last fallback.
    priority: int | None = Field(default=None, ge=1, le=1000)


class ConnectionUpdate(ApiModel):
    """Fields left out are unchanged. Send `credentials: null` to remove stored credentials."""

    purposes: list[ConnectionPurpose] | None = Field(default=None, min_length=1, max_length=3)
    configuration: ConnectionConfiguration | None = None
    credentials: ConnectionCredentials | None = None


class ConnectionRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    printer_id: uuid.UUID
    type: ConnectionType
    purposes: list[ConnectionPurpose]
    priority: int
    configuration: ConnectionConfiguration
    has_credentials: bool
    health: ConnectionHealth
    last_success_at: datetime | None
    last_failure_at: datetime | None
    last_latency_ms: int | None
    last_error: str | None
    created_at: datetime
    updated_at: datetime


class ConnectionPriorityUpdate(ApiModel):
    connection_ids: list[uuid.UUID] = Field(
        min_length=1, description="Every connection of the printer, most preferred first"
    )


class ConnectionHealthReport(ApiModel):
    """What a client observed when it used or tested the connection."""

    health: ConnectionHealth
    latency_ms: int | None = Field(default=None, ge=0, le=600_000)
    error: str | None = Field(default=None, max_length=500)
