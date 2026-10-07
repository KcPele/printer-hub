import uuid
from datetime import datetime

from pydantic import Field

from app.core.schemas import ApiModel
from app.modules.printers.schemas import PrinterRead


class PairingPayload(ApiModel):
    """Content to encode in the QR code. Holds no credentials (FR-SEC-013)."""

    v: int = 1
    token: str
    printer_id: uuid.UUID
    organization_id: uuid.UUID


class PairingTokenCreated(ApiModel):
    payload: PairingPayload
    deep_link: str
    expires_at: datetime


class PairingRedeem(ApiModel):
    token: str = Field(min_length=1, max_length=512)


class PairingResult(ApiModel):
    printer: PrinterRead
