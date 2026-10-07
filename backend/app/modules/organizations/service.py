"""Organizations, memberships, and invitations (FRD §19, §20)."""

import re
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import (
    ConflictError,
    NotFoundError,
    PermissionDeniedError,
    ValidationFailedError,
)
from app.core.permissions import Role
from app.core.security import generate_token, hash_token
from app.modules.audit import service as audit
from app.modules.organizations.models import Invitation, Membership, Organization
from app.modules.organizations.schemas import (
    InvitationCreate,
    OrganizationSettings,
    OrganizationUpdate,
)
from app.modules.users import service as users
from app.modules.users.models import User


def _slugify(name: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:60] or "org"
    return f"{base}-{secrets.token_hex(3)}"


def settings_of(organization: Organization) -> OrganizationSettings:
    return OrganizationSettings.model_validate(organization.settings)


# --- Organizations -----------------------------------------------------------


async def create(
    session: AsyncSession, *, name: str, owner: User
) -> tuple[Organization, Membership]:
    organization = Organization(
        name=name.strip(),
        slug=_slugify(name),
        settings=OrganizationSettings().model_dump(mode="json"),
    )
    session.add(organization)
    await session.flush()
    membership = Membership(organization_id=organization.id, user_id=owner.id, role=Role.OWNER)
    session.add(membership)
    audit.record(
        session,
        action="organization.created",
        target_type="organization",
        target_id=organization.id,
        organization_id=organization.id,
        actor_user_id=owner.id,
    )
    await session.flush()
    return organization, membership


async def list_for_user(
    session: AsyncSession, user_id: uuid.UUID
) -> list[tuple[Organization, Membership]]:
    rows = await session.execute(
        select(Organization, Membership)
        .join(Membership, Membership.organization_id == Organization.id)
        .where(Membership.user_id == user_id)
        .order_by(Organization.name)
    )
    return [(organization, membership) for organization, membership in rows]


async def get_membership(
    session: AsyncSession, *, organization_id: uuid.UUID, user_id: uuid.UUID
) -> tuple[Organization, Membership] | None:
    row = (
        await session.execute(
            select(Organization, Membership)
            .join(Membership, Membership.organization_id == Organization.id)
            .where(Organization.id == organization_id, Membership.user_id == user_id)
        )
    ).one_or_none()
    if row is None:
        return None
    organization, membership = row
    return organization, membership


async def update(
    session: AsyncSession, *, organization: Organization, actor: User, payload: OrganizationUpdate
) -> Organization:
    changed: list[str] = []
    if payload.name is not None and payload.name.strip() != organization.name:
        organization.name = payload.name.strip()
        changed.append("name")
    if payload.settings is not None:
        new_settings = payload.settings.model_dump(mode="json")
        if new_settings != organization.settings:
            organization.settings = new_settings
            changed.append("settings")
    if changed:
        audit.record(
            session,
            action="organization.updated",
            target_type="organization",
            target_id=organization.id,
            organization_id=organization.id,
            actor_user_id=actor.id,
            detail={"changed": changed},
        )
    await session.flush()
    return organization


async def delete_organization(session: AsyncSession, organization: Organization) -> None:
    """Delete the organization and, by cascade, everything it owns."""
    await session.delete(organization)
    await session.flush()


# --- Members -----------------------------------------------------------------


async def list_members(
    session: AsyncSession, organization_id: uuid.UUID
) -> list[tuple[Membership, User]]:
    rows = await session.execute(
        select(Membership, User)
        .join(User, User.id == Membership.user_id)
        .where(Membership.organization_id == organization_id)
        .order_by(User.name, User.email)
    )
    return [(membership, user) for membership, user in rows]


async def _get_member(
    session: AsyncSession, *, organization_id: uuid.UUID, user_id: uuid.UUID
) -> Membership:
    membership = await session.scalar(
        select(Membership)
        .where(Membership.organization_id == organization_id, Membership.user_id == user_id)
        .with_for_update()
    )
    if membership is None:
        raise NotFoundError("member.not_found", "That user is not a member of this organization.")
    return membership


async def _ensure_another_owner_remains(
    session: AsyncSession, *, organization_id: uuid.UUID, leaving_user_id: uuid.UUID
) -> None:
    other_owners = await session.scalar(
        select(func.count())
        .select_from(Membership)
        .where(
            Membership.organization_id == organization_id,
            Membership.role == Role.OWNER,
            Membership.user_id != leaving_user_id,
        )
    )
    if not other_owners:
        raise ConflictError("member.last_owner", "An organization must keep at least one owner.")


def _ensure_may_grant(actor_role: Role, role: Role) -> None:
    if role is Role.OWNER and actor_role is not Role.OWNER:
        raise PermissionDeniedError(
            "permission.owner_required", "Only an owner can grant or change the owner role."
        )


async def change_member_role(
    session: AsyncSession,
    *,
    organization_id: uuid.UUID,
    actor: User,
    actor_role: Role,
    user_id: uuid.UUID,
    role: Role,
) -> tuple[Membership, User]:
    membership = await _get_member(session, organization_id=organization_id, user_id=user_id)
    _ensure_may_grant(actor_role, role)
    _ensure_may_grant(actor_role, membership.role)
    previous = membership.role
    if previous is Role.OWNER and role is not Role.OWNER:
        await _ensure_another_owner_remains(
            session, organization_id=organization_id, leaving_user_id=user_id
        )
    membership.role = role
    if previous is not role:
        audit.record(
            session,
            action="member.role_changed",
            target_type="user",
            target_id=user_id,
            organization_id=organization_id,
            actor_user_id=actor.id,
            detail={"from": previous.value, "to": role.value},
        )
    await session.flush()
    user = await users.get_by_id(session, user_id)
    assert user is not None  # noqa: S101 - guaranteed by the membership foreign key
    return membership, user


async def remove_member(
    session: AsyncSession,
    *,
    organization_id: uuid.UUID,
    actor: User,
    actor_role: Role,
    user_id: uuid.UUID,
) -> None:
    """Remove a member. The caller decides whether `actor` may do this to others."""
    membership = await _get_member(session, organization_id=organization_id, user_id=user_id)
    if actor.id != user_id:
        _ensure_may_grant(actor_role, membership.role)
    if membership.role is Role.OWNER:
        await _ensure_another_owner_remains(
            session, organization_id=organization_id, leaving_user_id=user_id
        )
    await session.delete(membership)
    audit.record(
        session,
        action="member.left" if actor.id == user_id else "member.removed",
        target_type="user",
        target_id=user_id,
        organization_id=organization_id,
        actor_user_id=actor.id,
    )
    await session.flush()


# --- Invitations -------------------------------------------------------------


async def invite(
    session: AsyncSession,
    *,
    organization_id: uuid.UUID,
    actor: User,
    actor_role: Role,
    payload: InvitationCreate,
) -> tuple[Invitation, str]:
    """Create an invitation and return it with its one-time token."""
    _ensure_may_grant(actor_role, payload.role)
    email = users.normalize_email(payload.email)

    existing_user = await users.get_by_email(session, email)
    if existing_user is not None:
        already_member = await get_membership(
            session, organization_id=organization_id, user_id=existing_user.id
        )
        if already_member is not None:
            raise ConflictError("invitation.already_member", "That person is already a member.")

    # A new invitation replaces any pending one for the same address.
    await session.execute(
        delete(Invitation).where(
            Invitation.organization_id == organization_id,
            Invitation.email == email,
            Invitation.accepted_at.is_(None),
        )
    )
    token = generate_token()
    invitation = Invitation(
        organization_id=organization_id,
        email=email,
        role=payload.role,
        token_hash=hash_token(token),
        invited_by_user_id=actor.id,
        expires_at=datetime.now(UTC) + timedelta(days=get_settings().invitation_ttl_days),
    )
    session.add(invitation)
    audit.record(
        session,
        action="invitation.created",
        target_type="invitation",
        target_id=invitation.id,
        organization_id=organization_id,
        actor_user_id=actor.id,
        detail={"email": email, "role": payload.role.value},
    )
    await session.flush()
    return invitation, token


async def list_pending_invitations(
    session: AsyncSession, organization_id: uuid.UUID
) -> list[Invitation]:
    rows = await session.scalars(
        select(Invitation)
        .where(
            Invitation.organization_id == organization_id,
            Invitation.accepted_at.is_(None),
            Invitation.expires_at > datetime.now(UTC),
        )
        .order_by(Invitation.id.desc())
    )
    return list(rows)


async def revoke_invitation(
    session: AsyncSession, *, organization_id: uuid.UUID, actor: User, invitation_id: uuid.UUID
) -> None:
    invitation = await session.scalar(
        select(Invitation).where(
            Invitation.id == invitation_id,
            Invitation.organization_id == organization_id,
            Invitation.accepted_at.is_(None),
        )
    )
    if invitation is None:
        raise NotFoundError("invitation.not_found", "Invitation not found.")
    await session.delete(invitation)
    audit.record(
        session,
        action="invitation.revoked",
        target_type="invitation",
        target_id=invitation_id,
        organization_id=organization_id,
        actor_user_id=actor.id,
        detail={"email": invitation.email},
    )
    await session.flush()


async def accept_invitation(
    session: AsyncSession, *, token: str, user: User
) -> tuple[Organization, Membership]:
    invitation = await session.scalar(
        select(Invitation).where(Invitation.token_hash == hash_token(token)).with_for_update()
    )
    if (
        invitation is None
        or invitation.accepted_at is not None
        or invitation.expires_at <= datetime.now(UTC)
    ):
        raise ValidationFailedError(
            "invitation.invalid", "This invitation is not valid or has expired."
        )
    if invitation.email != user.email:
        raise PermissionDeniedError(
            "invitation.email_mismatch", "This invitation was sent to a different email address."
        )

    existing = await get_membership(
        session, organization_id=invitation.organization_id, user_id=user.id
    )
    if existing is not None:
        raise ConflictError("invitation.already_member", "You are already a member.")

    membership = Membership(
        organization_id=invitation.organization_id, user_id=user.id, role=invitation.role
    )
    session.add(membership)
    invitation.accepted_at = datetime.now(UTC)
    audit.record(
        session,
        action="member.joined",
        target_type="user",
        target_id=user.id,
        organization_id=invitation.organization_id,
        actor_user_id=user.id,
        detail={"role": invitation.role.value, "invitation_id": str(invitation.id)},
    )
    await session.flush()
    organization = await session.get(Organization, invitation.organization_id)
    assert organization is not None  # noqa: S101 - guaranteed by the invitation foreign key
    return organization, membership
