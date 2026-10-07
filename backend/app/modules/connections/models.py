import enum
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import ForeignKey, LargeBinary, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin, str_enum


class ConnectionType(enum.StrEnum):
    IPP = "ipp"
    IPPS = "ipps"
    AIRPRINT = "airprint"
    ANDROID_PRINT = "android_print"
    MOPRIA = "mopria"
    ESCL = "escl"
    WIFI_DIRECT = "wifi_direct"
    USB = "usb"
    HTTP = "http"
    SNMP = "snmp"
    SMB = "smb"
    SFTP = "sftp"
    GATEWAY = "gateway"
    CLOUD_RELAY = "cloud_relay"


class ConnectionPurpose(enum.StrEnum):
    PRINT = "print"
    SCAN = "scan"
    STATUS = "status"


class ConnectionHealth(enum.StrEnum):
    """FR-CON-012."""

    CONNECTED = "connected"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"
    AUTH_REQUIRED = "auth_required"
    CONFIG_REQUIRED = "config_required"
    UNKNOWN = "unknown"


class Connection(Base, IdMixin, TimestampMixin):
    """One way to reach a printer. A printer usually has several."""

    __tablename__ = "connections"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE")
    )
    printer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("printers.id", ondelete="CASCADE"), index=True
    )
    type: Mapped[ConnectionType] = mapped_column(str_enum(ConnectionType))
    purposes: Mapped[list[str]]
    # Lower is preferred. Clients try connections in this order (FR-CON-009).
    priority: Mapped[int]
    # Shape: `connections.schemas.ConnectionConfiguration`. Holds nothing secret.
    configuration: Mapped[dict[str, Any]] = mapped_column(default=dict)
    # Fernet-encrypted JSON; see `app.core.crypto`.
    encrypted_credentials: Mapped[bytes | None] = mapped_column(LargeBinary)
    health: Mapped[ConnectionHealth] = mapped_column(
        str_enum(ConnectionHealth), default=ConnectionHealth.UNKNOWN
    )
    last_success_at: Mapped[datetime | None]
    last_failure_at: Mapped[datetime | None]
    last_latency_ms: Mapped[int | None]
    last_error: Mapped[str | None] = mapped_column(String(500))
