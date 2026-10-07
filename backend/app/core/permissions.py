"""Roles and the permissions each one grants (FRD §19).

Roles are cumulative: each role holds everything the role below it holds.
"Own" resources (a user's own jobs and documents) need no permission beyond
membership; the `*_ALL` permissions extend access to other members' resources.
"""

import enum


class Role(enum.StrEnum):
    OWNER = "owner"
    ADMIN = "admin"
    OPERATOR = "operator"
    USER = "user"
    VIEWER = "viewer"


class Permission(enum.StrEnum):
    ORG_READ = "org.read"
    ORG_UPDATE = "org.update"
    ORG_DELETE = "org.delete"
    MEMBERS_READ = "members.read"
    MEMBERS_MANAGE = "members.manage"
    PRINTERS_READ = "printers.read"
    # Report status, capabilities, and connection health observed by a client.
    PRINTERS_REPORT = "printers.report"
    # Add, edit, and remove printers, connections, and their credentials.
    PRINTERS_MANAGE = "printers.manage"
    JOBS_CREATE = "jobs.create"
    JOBS_READ_ALL = "jobs.read_all"
    JOBS_MANAGE_ALL = "jobs.manage_all"
    DOCUMENTS_CREATE = "documents.create"
    DOCUMENTS_READ_ALL = "documents.read_all"
    DOCUMENTS_MANAGE_ALL = "documents.manage_all"
    PRESETS_MANAGE_ORG = "presets.manage_org"
    AUDIT_READ = "audit.read"


_VIEWER = frozenset(
    {
        Permission.ORG_READ,
        Permission.MEMBERS_READ,
        Permission.PRINTERS_READ,
        Permission.JOBS_READ_ALL,
    }
)
_USER = frozenset(
    {
        Permission.ORG_READ,
        Permission.MEMBERS_READ,
        Permission.PRINTERS_READ,
        Permission.PRINTERS_REPORT,
        Permission.JOBS_CREATE,
        Permission.DOCUMENTS_CREATE,
    }
)
_OPERATOR = _USER | {
    Permission.JOBS_READ_ALL,
    Permission.JOBS_MANAGE_ALL,
    Permission.DOCUMENTS_READ_ALL,
}
_ADMIN = _OPERATOR | {
    Permission.ORG_UPDATE,
    Permission.MEMBERS_MANAGE,
    Permission.PRINTERS_MANAGE,
    Permission.DOCUMENTS_MANAGE_ALL,
    Permission.PRESETS_MANAGE_ORG,
    Permission.AUDIT_READ,
}
_OWNER = _ADMIN | {Permission.ORG_DELETE}

ROLE_PERMISSIONS: dict[Role, frozenset[Permission]] = {
    Role.VIEWER: _VIEWER,
    Role.USER: _USER,
    Role.OPERATOR: _OPERATOR,
    Role.ADMIN: _ADMIN,
    Role.OWNER: _OWNER,
}


def role_has(role: Role, permission: Permission) -> bool:
    return permission in ROLE_PERMISSIONS[role]
