import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.deps import SessionDep
from app.core.errors import PermissionDeniedError, problem_responses
from app.core.permissions import Permission
from app.modules.auth.deps import CurrentUser
from app.modules.organizations import service
from app.modules.organizations.deps import OrgContext, require
from app.modules.organizations.models import Membership, Organization
from app.modules.organizations.schemas import (
    InvitationAccept,
    InvitationCreate,
    InvitationCreated,
    InvitationRead,
    MemberRead,
    MemberUpdate,
    MyInvitationRead,
    OrganizationCreate,
    OrganizationRead,
    OrganizationUpdate,
)
from app.modules.users.models import User
from app.modules.users.schemas import UserSummary

router = APIRouter(prefix="/organizations", tags=["organizations"])
invitations_router = APIRouter(prefix="/invitations", tags=["organizations"])


def _organization_read(organization: Organization, membership: Membership) -> OrganizationRead:
    return OrganizationRead(
        id=organization.id,
        name=organization.name,
        slug=organization.slug,
        settings=service.settings_of(organization),
        created_at=organization.created_at,
        role=membership.role,
    )


def _member_read(membership: Membership, user: User) -> MemberRead:
    return MemberRead(
        user=UserSummary.model_validate(user),
        role=membership.role,
        joined_at=membership.created_at,
    )


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_organization(
    payload: OrganizationCreate, user: CurrentUser, session: SessionDep
) -> OrganizationRead:
    """Create an organization. The caller becomes its owner."""
    organization, membership = await service.create(session, name=payload.name, owner=user)
    return _organization_read(organization, membership)


@router.get("")
async def list_organizations(user: CurrentUser, session: SessionDep) -> list[OrganizationRead]:
    """Organizations the caller belongs to."""
    rows = await service.list_for_user(session, user.id)
    return [_organization_read(organization, membership) for organization, membership in rows]


@router.get("/{org_id}")
async def get_organization(
    ctx: Annotated[OrgContext, Depends(require(Permission.ORG_READ))],
) -> OrganizationRead:
    return _organization_read(ctx.organization, ctx.membership)


@router.patch("/{org_id}")
async def update_organization(
    payload: OrganizationUpdate,
    ctx: Annotated[OrgContext, Depends(require(Permission.ORG_UPDATE))],
    session: SessionDep,
) -> OrganizationRead:
    organization = await service.update(
        session, organization=ctx.organization, actor=ctx.user, payload=payload
    )
    return _organization_read(organization, ctx.membership)


@router.delete("/{org_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_organization(
    ctx: Annotated[OrgContext, Depends(require(Permission.ORG_DELETE))], session: SessionDep
) -> None:
    """Delete the organization with all its printers, jobs, and documents."""
    await service.delete_organization(session, ctx.organization)


@router.get("/{org_id}/members")
async def list_members(
    ctx: Annotated[OrgContext, Depends(require(Permission.MEMBERS_READ))], session: SessionDep
) -> list[MemberRead]:
    rows = await service.list_members(session, ctx.organization.id)
    return [_member_read(membership, user) for membership, user in rows]


@router.patch("/{org_id}/members/{user_id}", responses=problem_responses(409))
async def change_member_role(
    user_id: uuid.UUID,
    payload: MemberUpdate,
    ctx: Annotated[OrgContext, Depends(require(Permission.MEMBERS_MANAGE))],
    session: SessionDep,
) -> MemberRead:
    membership, user = await service.change_member_role(
        session,
        organization_id=ctx.organization.id,
        actor=ctx.user,
        actor_role=ctx.role,
        user_id=user_id,
        role=payload.role,
    )
    return _member_read(membership, user)


@router.delete(
    "/{org_id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=problem_responses(409),
)
async def remove_member(
    user_id: uuid.UUID,
    ctx: Annotated[OrgContext, Depends(require(Permission.ORG_READ))],
    session: SessionDep,
) -> None:
    """Remove a member. Any member may remove themselves to leave."""
    if user_id != ctx.user.id and not ctx.has(Permission.MEMBERS_MANAGE):
        raise PermissionDeniedError(
            "permission.denied",
            f"Your role does not allow this action (requires {Permission.MEMBERS_MANAGE.value}).",
        )
    await service.remove_member(
        session,
        organization_id=ctx.organization.id,
        actor=ctx.user,
        actor_role=ctx.role,
        user_id=user_id,
    )


@router.post(
    "/{org_id}/invitations",
    status_code=status.HTTP_201_CREATED,
    responses=problem_responses(409),
)
async def create_invitation(
    payload: InvitationCreate,
    ctx: Annotated[OrgContext, Depends(require(Permission.MEMBERS_MANAGE))],
    session: SessionDep,
) -> InvitationCreated:
    """Invite someone by email. The token appears only in this response."""
    invitation, token = await service.invite(
        session,
        organization_id=ctx.organization.id,
        actor=ctx.user,
        actor_role=ctx.role,
        payload=payload,
    )
    return InvitationCreated(**InvitationRead.model_validate(invitation).model_dump(), token=token)


@router.get("/{org_id}/invitations")
async def list_invitations(
    ctx: Annotated[OrgContext, Depends(require(Permission.MEMBERS_MANAGE))], session: SessionDep
) -> list[InvitationRead]:
    invitations = await service.list_pending_invitations(session, ctx.organization.id)
    return [InvitationRead.model_validate(invitation) for invitation in invitations]


@router.delete("/{org_id}/invitations/{invitation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_invitation(
    invitation_id: uuid.UUID,
    ctx: Annotated[OrgContext, Depends(require(Permission.MEMBERS_MANAGE))],
    session: SessionDep,
) -> None:
    await service.revoke_invitation(
        session, organization_id=ctx.organization.id, actor=ctx.user, invitation_id=invitation_id
    )


@invitations_router.get("")
async def list_my_invitations(user: CurrentUser, session: SessionDep) -> list[MyInvitationRead]:
    """Pending invitations sent to the caller's email address."""
    rows = await service.list_invitations_for_user(session, user)
    return [
        MyInvitationRead(
            id=invitation.id,
            organization_id=organization.id,
            organization_name=organization.name,
            role=invitation.role,
            expires_at=invitation.expires_at,
            created_at=invitation.created_at,
        )
        for invitation, organization in rows
    ]


@invitations_router.post("/{invitation_id}/accept", responses=problem_responses(409))
async def accept_my_invitation(
    invitation_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> OrganizationRead:
    """Accept one of the caller's pending invitations from inside the app."""
    organization, membership = await service.accept_invitation_by_id(
        session, invitation_id=invitation_id, user=user
    )
    return _organization_read(organization, membership)


@invitations_router.post("/accept", responses=problem_responses(409))
async def accept_invitation(
    payload: InvitationAccept, user: CurrentUser, session: SessionDep
) -> OrganizationRead:
    """Join with the token from an invitation link. The caller's email must match."""
    organization, membership = await service.accept_invitation(
        session, token=payload.token, user=user
    )
    return _organization_read(organization, membership)
