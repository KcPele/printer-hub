import uuid
from datetime import datetime
from typing import Any

from pydantic import ConfigDict

from app.core.schemas import ApiModel
from app.modules.audit.models import AuditOutcome


class AuditLogRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    actor_user_id: uuid.UUID | None
    action: str
    target_type: str
    target_id: uuid.UUID | None
    outcome: AuditOutcome
    detail: dict[str, Any]
    ip: str | None
    created_at: datetime
