"""The normalized printer capability model (FRD §31, §55.1 item 7).

One shape describes any printer, whatever its vendor or protocol. Clients
build it by probing the device and enable features from it, never from the
model name alone (FRD §6.4).

`None` on a tri-state field means "not probed yet", which is different from
`False` ("probed, absent").
"""

import enum
import uuid
from datetime import datetime
from typing import Literal

from pydantic import ConfigDict, Field

from app.core.schemas import ApiModel

CAPABILITY_SCHEMA_VERSION = 1


class DuplexMode(enum.StrEnum):
    ONE_SIDED = "one_sided"
    TWO_SIDED_LONG_EDGE = "two_sided_long_edge"
    TWO_SIDED_SHORT_EDGE = "two_sided_short_edge"


class ScanSource(enum.StrEnum):
    PLATEN = "platen"
    ADF = "adf"


class ScanColorMode(enum.StrEnum):
    COLOR = "color"
    GRAYSCALE = "grayscale"
    BLACK_AND_WHITE = "black_and_white"


class _Section(ApiModel):
    model_config = ConfigDict(extra="forbid")


class MediaTray(_Section):
    id: str = Field(max_length=64)
    name: str = Field(max_length=100)
    media_size: str | None = Field(default=None, max_length=64)
    media_type: str | None = Field(default=None, max_length=64)


class PrintCapabilities(_Section):
    supported: bool = False
    color: bool = False
    duplex_modes: list[DuplexMode] = Field(default_factory=list)
    # IPP media names where known, for example `iso_a4_210x297mm`.
    media_sizes: list[str] = Field(default_factory=list, max_length=200)
    media_types: list[str] = Field(default_factory=list, max_length=100)
    trays: list[MediaTray] = Field(default_factory=list, max_length=32)
    finishing: list[str] = Field(default_factory=list, max_length=64)
    resolutions_dpi: list[int] = Field(default_factory=list, max_length=32)
    quality_modes: list[str] = Field(default_factory=list, max_length=16)
    # MIME types the printer accepts directly.
    document_formats: list[str] = Field(default_factory=list, max_length=64)
    max_copies: int | None = Field(default=None, ge=1)
    collation: bool = False
    secure_print: bool = False


class ScanCapabilities(_Section):
    supported: bool = False
    sources: list[ScanSource] = Field(default_factory=list)
    adf_duplex: bool = False
    color_modes: list[ScanColorMode] = Field(default_factory=list)
    resolutions_dpi: list[int] = Field(default_factory=list, max_length=32)
    document_formats: list[str] = Field(default_factory=list, max_length=64)
    max_width_mm: float | None = Field(default=None, gt=0)
    max_height_mm: float | None = Field(default=None, gt=0)


class CopyCapabilities(_Section):
    supported: bool = False
    # False means copy is performed as scan-then-print by the client (FR-CPY-003).
    native_remote_control: bool = False


class StatusCapabilities(_Section):
    reporting: bool = False
    consumables: bool = False
    trays: bool = False


class Connectivity(_Section):
    ethernet: bool | None = None
    wifi: bool | None = None
    wifi_direct: bool | None = None
    nfc: bool | None = None
    # Proximity and discovery only, never a print transport (FR-MOB-010).
    ble_beacon: bool | None = None
    usb: bool | None = None


class Protocols(_Section):
    ipp: bool | None = None
    ipps: bool | None = None
    airprint: bool | None = None
    mopria: bool | None = None
    escl: bool | None = None
    snmp: bool | None = None
    http_ews: bool | None = None
    smb_scan: bool | None = None


class PrinterCapabilities(_Section):
    schema_version: Literal[1] = 1
    print: PrintCapabilities = Field(default_factory=PrintCapabilities)
    scan: ScanCapabilities = Field(default_factory=ScanCapabilities)
    copy_: CopyCapabilities = Field(default_factory=CopyCapabilities, alias="copy")
    status: StatusCapabilities = Field(default_factory=StatusCapabilities)
    connectivity: Connectivity = Field(default_factory=Connectivity)
    protocols: Protocols = Field(default_factory=Protocols)

    model_config = ConfigDict(extra="forbid", populate_by_name=True, serialize_by_alias=True)


class ProfileCategory(enum.StrEnum):
    """What kind of machine a family is, for browsing the catalogue."""

    OFFICE_MULTIFUNCTION = "office_multifunction"
    OFFICE_PRINTER = "office_printer"
    HOME_MULTIFUNCTION = "home_multifunction"
    HOME_PRINTER = "home_printer"


class CapabilityProfileWrite(ApiModel):
    manufacturer: str = Field(min_length=1, max_length=100)
    display_name: str = Field(min_length=1, max_length=200)
    category: ProfileCategory = ProfileCategory.OFFICE_MULTIFUNCTION
    # One line saying what the family is, shown in the catalogue.
    summary: str | None = Field(default=None, max_length=200)
    # Higher is listed first.
    popularity: int = Field(default=0, ge=0, le=1000)
    # Case-insensitive glob patterns matched against the reported model name.
    model_patterns: list[str] = Field(min_length=1, max_length=32)
    capabilities: PrinterCapabilities
    # Dotted paths into `capabilities` that depend on optional hardware and
    # must be confirmed by probing, for example `connectivity.wifi`.
    optional_features: list[str] = Field(default_factory=list, max_length=64)
    notes: list[str] = Field(default_factory=list, max_length=32)
    # What to do on the printer so that it can be found and used, in the
    # order to do it. Written for the person holding the phone.
    setup_tips: list[str] = Field(default_factory=list, max_length=16)


class CapabilityProfileRead(CapabilityProfileWrite):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    version: int
    updated_at: datetime
