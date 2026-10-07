"""The verified caller of an organization-scoped request."""

from dataclasses import dataclass

from app.core.permissions import Permission, Role, role_has
from app.modules.auth.models import UserSession
from app.modules.organizations.models import Membership, Organization
from app.modules.organizations.schemas import OrganizationSettings
from app.modules.users.models import User


@dataclass(frozen=True, slots=True)
class OrgContext:
    """A user confirmed as a member of an organization.

    Routers obtain it from `organizations.deps.require`; services take it as
    the source of both the tenant boundary and the caller's permissions.
    """

    organization: Organization
    membership: Membership
    user: User
    session: UserSession

    @property
    def role(self) -> Role:
        return self.membership.role

    @property
    def settings(self) -> OrganizationSettings:
        return OrganizationSettings.model_validate(self.organization.settings)

    def has(self, permission: Permission) -> bool:
        return role_has(self.membership.role, permission)
