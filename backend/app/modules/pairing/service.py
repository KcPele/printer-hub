"""QR and NFC pairing (FR-MOB-009, FR-MOB-011, FR-CON-014)."""

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import PermissionDeniedError, ValidationFailedError
from app.core.permissions import Permission, role_has
from app.core.security import generate_token, hash_token
from app.modules.audit import service as audit
from app.modules.organizations import service as organizations
from app.modules.pairing.models import PairingToken
from app.modules.printers import service as printers
from app.modules.printers.models import Printer
from app.modules.users.models import User


async def create_token(
    session: AsyncSession, *, printer: Printer, actor_user_id: uuid.UUID
) -> tuple[str, datetime]:
    token = generate_token()
    expires_at = datetime.now(UTC) + timedelta(seconds=get_settings().pairing_token_ttl_seconds)
    session.add(
        PairingToken(
            organization_id=printer.organization_id,
            printer_id=printer.id,
            token_hash=hash_token(token),
            created_by_user_id=actor_user_id,
            expires_at=expires_at,
        )
    )
    audit.record(
        session,
        action="pairing_token.created",
        target_type="printer",
        target_id=printer.id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
    )
    await session.flush()
    return token, expires_at


async def redeem(session: AsyncSession, *, token: str, user: User) -> Printer:
    """Exchange a pairing token for the printer profile it points at.

    Pairing identifies a printer; it does not grant access. The caller must
    already belong to the printer's organization.
    """
    invalid = ValidationFailedError(
        "pairing.token_invalid", "This pairing code is not valid or has expired."
    )
    pairing = await session.scalar(
        select(PairingToken).where(PairingToken.token_hash == hash_token(token)).with_for_update()
    )
    if (
        pairing is None
        or pairing.redeemed_at is not None
        or pairing.expires_at <= datetime.now(UTC)
    ):
        raise invalid

    membership = await organizations.get_membership(
        session, organization_id=pairing.organization_id, user_id=user.id
    )
    if membership is None or not role_has(membership[1].role, Permission.PRINTERS_READ):
        raise PermissionDeniedError(
            "pairing.not_a_member",
            "Join this printer's organization before pairing with it.",
        )

    printer = await printers.get(
        session, organization_id=pairing.organization_id, printer_id=pairing.printer_id
    )
    pairing.redeemed_at = datetime.now(UTC)
    await session.flush()
    return printer


async def purge_expired(session: AsyncSession) -> None:
    await session.execute(
        delete(PairingToken).where(PairingToken.expires_at < datetime.now(UTC) - timedelta(days=1))
    )
