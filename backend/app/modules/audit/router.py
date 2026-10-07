import uuid
from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.deps import SessionDep
from app.core.pagination import Page, PageParams
from app.core.permissions import Permission
from app.modules.audit import service
from app.modules.audit.schemas import AuditLogRead
from app.modules.organizations.deps import OrgContext, require

router = APIRouter(prefix="/organizations/{org_id}/audit-logs", tags=["audit"])


@router.get("")
async def list_audit_logs(
    ctx: Annotated[OrgContext, Depends(require(Permission.AUDIT_READ))],
    session: SessionDep,
    params: Annotated[PageParams, Depends()],
    action: str | None = None,
    actor_user_id: uuid.UUID | None = None,
    target_type: str | None = None,
    target_id: uuid.UUID | None = None,
) -> Page[AuditLogRead]:
    items, next_cursor = await service.list_for_organization(
        session,
        organization_id=ctx.organization.id,
        params=params,
        action=action,
        actor_user_id=actor_user_id,
        target_type=target_type,
        target_id=target_id,
    )
    return Page(
        items=[AuditLogRead.model_validate(item) for item in items], next_cursor=next_cursor
    )
