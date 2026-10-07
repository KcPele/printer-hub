import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.deps import SessionDep
from app.core.permissions import Permission
from app.modules.auth.deps import CurrentUser
from app.modules.connections import service as connections
from app.modules.organizations.deps import OrgContext, require
from app.modules.pairing import service
from app.modules.pairing.schemas import (
    PairingPayload,
    PairingRedeem,
    PairingResult,
    PairingTokenCreated,
)
from app.modules.printers import service as printers

router = APIRouter(tags=["pairing"])


@router.post(
    "/organizations/{org_id}/printers/{printer_id}/pairing-tokens",
    status_code=status.HTTP_201_CREATED,
)
async def create_pairing_token(
    printer_id: uuid.UUID,
    ctx: Annotated[OrgContext, Depends(require(Permission.PRINTERS_MANAGE))],
    session: SessionDep,
) -> PairingTokenCreated:
    """Create a short-lived, single-use pairing code to show as a QR code."""
    printer = await printers.get(
        session, organization_id=ctx.organization.id, printer_id=printer_id
    )
    token, expires_at = await service.create_token(
        session, printer=printer, actor_user_id=ctx.user.id
    )
    return PairingTokenCreated(
        payload=PairingPayload(
            token=token, printer_id=printer.id, organization_id=printer.organization_id
        ),
        deep_link=f"printerhub://pair?token={token}",
        expires_at=expires_at,
    )


@router.post("/pairing/redeem")
async def redeem_pairing_token(
    payload: PairingRedeem, user: CurrentUser, session: SessionDep
) -> PairingResult:
    """Resolve a scanned pairing code to its printer profile and connections."""
    printer = await service.redeem(session, token=payload.token, user=user)
    return PairingResult(
        printer=printers.to_read(printer, await connections.list_for_printer(session, printer.id))
    )
