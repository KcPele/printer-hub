"""Imports every model module so `Base.metadata` is complete.

Alembic and the test harness import this module. Add each new module's models here.
"""

from app.core.db import Base
from app.core.idempotency import IdempotencyRecord
from app.modules.audit.models import AuditLog
from app.modules.auth.models import UserSession
from app.modules.capabilities.models import CapabilityProfile
from app.modules.connections.models import Connection
from app.modules.devices.models import Device
from app.modules.documents.models import Document
from app.modules.feature_flags.models import FeatureFlag, FeatureFlagOverride
from app.modules.jobs.models import Job, JobEvent
from app.modules.notifications.models import Notification
from app.modules.organizations.models import Invitation, Membership, Organization
from app.modules.pairing.models import PairingToken
from app.modules.presets.models import Preset
from app.modules.printers.models import Printer
from app.modules.users.models import User

__all__ = [
    "AuditLog",
    "Base",
    "CapabilityProfile",
    "Connection",
    "Device",
    "Document",
    "FeatureFlag",
    "FeatureFlagOverride",
    "IdempotencyRecord",
    "Invitation",
    "Job",
    "JobEvent",
    "Membership",
    "Notification",
    "Organization",
    "PairingToken",
    "Preset",
    "Printer",
    "User",
    "UserSession",
]
