import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.modules.printers.schemas import PrinterRead


class PairingPayload(BaseModel):
    """Content to encode in the QR code. Holds no credentials (FR-SEC-013)."""

    v: int = 1
    token: str
    printer_id: uuid.UUID
    organization_id: uuid.UUID


class PairingTokenCreated(BaseModel):
    payload: PairingPayload
    deep_link: str
    expires_at: datetime


class PairingRedeem(BaseModel):
    token: str = Field(min_length=1, max_length=512)


class PairingResult(BaseModel):
    printer: PrinterRead
