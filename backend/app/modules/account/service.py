"""Deleting an account and everything that belongs only to it.

App stores require that an account created in the app can be deleted in the
app. This spans several modules, so it lives in one place.
"""

import structlog
from anyio import to_thread
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, ValidationFailedError
from app.core.permissions import Role
from app.core.security import verify_password
from app.modules.audit import service as audit
from app.modules.documents import service as documents
from app.modules.organizations import service as organizations
from app.modules.users.models import User

log = structlog.get_logger(__name__)


async def delete_account(session: AsyncSession, *, user: User, password: str) -> None:
    """Delete the user's account.

    What goes with it:
    - Organizations where the user is the only member, with their printers,
      jobs, documents, and stored files.
    - The user's own documents and stored files in shared organizations.
    - Sessions, devices, notifications, personal presets, and pending invitations.

    What stays, without the user's identity: jobs and audit entries in shared
    organizations, which are those organizations' records.

    Refused while the user is the last owner of an organization that has other
    members, because deleting would leave it without anyone able to manage it.
    """
    if not await to_thread.run_sync(verify_password, password, user.password_hash):
        raise ValidationFailedError("account.password_incorrect", "The password is incorrect.")

    memberships = await organizations.list_for_user(session, user.id)
    solo, stranded = [], []
    for organization, membership in memberships:
        if await organizations.member_count(session, organization.id) == 1:
            solo.append(organization)
        elif membership.role is Role.OWNER and not await organizations.has_another_owner(
            session, organization_id=organization.id, user_id=user.id
        ):
            stranded.append(organization)

    if stranded:
        names = ", ".join(sorted(organization.name for organization in stranded))
        raise ConflictError(
            "account.sole_owner",
            f"You are the only owner of: {names}. "
            "Make another member an owner, or delete the organization, then try again.",
        )

    for organization, _ in memberships:
        if organization not in solo:
            audit.record(
                session,
                action="member.account_deleted",
                target_type="user",
                target_id=user.id,
                organization_id=organization.id,
            )
    for organization in solo:
        await organizations.delete_organization(session, organization)

    await documents.delete_all_owned_by(session, user.id)
    await organizations.delete_invitations_for_email(session, user.email)
    audit.record(session, action="user.deleted", target_type="user", target_id=user.id)
    # Sessions, devices, notifications, memberships, and personal presets go by cascade.
    await session.delete(user)
    await session.flush()
    log.info("account_deleted", user_id=str(user.id), organizations_deleted=len(solo))
