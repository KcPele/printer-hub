"""Organization-scoped authorization."""

import uuid
from collections.abc import Awaitable, Callable

import structlog

from app.core.deps import SessionDep
from app.core.errors import NotFoundError, PermissionDeniedError
from app.core.permissions import Permission, role_has
from app.modules.auth.deps import Auth
from app.modules.organizations import service
from app.modules.organizations.context import OrgContext


def require(permission: Permission) -> Callable[..., Awaitable[OrgContext]]:
    """Dependency factory: the caller must hold `permission` in `{org_id}`.

    A non-member gets 404, the same as for an organization that does not
    exist, so organization IDs cannot be probed.
    """

    async def dependency(org_id: uuid.UUID, auth: Auth, session: SessionDep) -> OrgContext:
        found = await service.get_membership(session, organization_id=org_id, user_id=auth.user.id)
        if found is None:
            raise NotFoundError("organization.not_found", "Organization not found.")
        organization, membership = found
        structlog.contextvars.bind_contextvars(organization_id=str(organization.id))
        if not role_has(membership.role, permission):
            raise PermissionDeniedError(
                "permission.denied",
                f"Your role does not allow this action (requires {permission.value}).",
            )
        return OrgContext(
            organization=organization,
            membership=membership,
            user=auth.user,
            session=auth.session,
        )

    return dependency


__all__ = ["OrgContext", "require"]
