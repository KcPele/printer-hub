"""Imports every model module so `Base.metadata` is complete.

Alembic and the test harness import this module. Add each new module's models here.
"""

from app.core.db import Base
from app.modules.audit.models import AuditLog
from app.modules.auth.models import UserSession
from app.modules.devices.models import Device
from app.modules.organizations.models import Invitation, Membership, Organization
from app.modules.users.models import User

__all__ = [
    "AuditLog",
    "Base",
    "Device",
    "Invitation",
    "Membership",
    "Organization",
    "User",
    "UserSession",
]
