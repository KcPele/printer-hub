import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.client import current_client
from app.core.pagination import PageParams, paginate
from app.modules.audit.models import AuditLog, AuditOutcome


def record(
    session: AsyncSession,
    *,
    action: str,
    target_type: str,
    target_id: uuid.UUID | None = None,
    organization_id: uuid.UUID | None = None,
    actor_user_id: uuid.UUID | None = None,
    outcome: AuditOutcome = AuditOutcome.SUCCESS,
    detail: dict[str, Any] | None = None,
) -> None:
    """Add an audit entry to the current transaction.

    The entry commits or rolls back with the change it describes. Keep
    `detail` free of secrets and document content.
    """
    client = current_client.get()
    session.add(
        AuditLog(
            organization_id=organization_id,
            actor_user_id=actor_user_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            outcome=outcome,
            detail=detail or {},
            ip=client.ip,
            user_agent=client.user_agent,
        )
    )


async def list_for_organization(
    session: AsyncSession,
    *,
    organization_id: uuid.UUID,
    params: PageParams,
    action: str | None = None,
    actor_user_id: uuid.UUID | None = None,
    target_type: str | None = None,
    target_id: uuid.UUID | None = None,
) -> tuple[list[AuditLog], str | None]:
    stmt = select(AuditLog).where(AuditLog.organization_id == organization_id)
    if action is not None:
        stmt = stmt.where(AuditLog.action == action)
    if actor_user_id is not None:
        stmt = stmt.where(AuditLog.actor_user_id == actor_user_id)
    if target_type is not None:
        stmt = stmt.where(AuditLog.target_type == target_type)
    if target_id is not None:
        stmt = stmt.where(AuditLog.target_id == target_id)
    return await paginate(session, stmt, AuditLog.id, params)
