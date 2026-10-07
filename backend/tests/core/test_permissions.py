import itertools

import pytest

from app.core.permissions import ROLE_PERMISSIONS, Permission, Role, role_has

_LADDER = [Role.USER, Role.OPERATOR, Role.ADMIN, Role.OWNER]


def test_each_role_holds_everything_the_role_below_holds() -> None:
    for lower, higher in itertools.pairwise(_LADDER):
        assert ROLE_PERMISSIONS[lower] < ROLE_PERMISSIONS[higher]


def test_every_role_is_mapped() -> None:
    assert set(ROLE_PERMISSIONS) == set(Role)


def test_owner_holds_every_permission() -> None:
    assert ROLE_PERMISSIONS[Role.OWNER] == set(Permission)


@pytest.mark.parametrize(
    ("role", "permission", "expected"),
    [
        (Role.VIEWER, Permission.PRINTERS_READ, True),
        (Role.VIEWER, Permission.JOBS_CREATE, False),
        (Role.VIEWER, Permission.PRINTERS_REPORT, False),
        (Role.USER, Permission.JOBS_CREATE, True),
        (Role.USER, Permission.JOBS_READ_ALL, False),
        (Role.OPERATOR, Permission.JOBS_MANAGE_ALL, True),
        (Role.OPERATOR, Permission.PRINTERS_MANAGE, False),
        (Role.ADMIN, Permission.MEMBERS_MANAGE, True),
        (Role.ADMIN, Permission.AUDIT_READ, True),
        (Role.ADMIN, Permission.ORG_DELETE, False),
        (Role.OWNER, Permission.ORG_DELETE, True),
    ],
)
def test_role_matrix(role: Role, permission: Permission, expected: bool) -> None:
    assert role_has(role, permission) is expected
