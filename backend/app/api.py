"""Mounts every module router under the versioned API prefix."""

from fastapi import APIRouter

from app.core.errors import problem_responses
from app.modules.audit.router import router as audit_router
from app.modules.auth.router import router as auth_router
from app.modules.capabilities.router import admin_router as capabilities_admin_router
from app.modules.capabilities.router import router as capabilities_router
from app.modules.devices.router import router as devices_router
from app.modules.documents.router import router as documents_router
from app.modules.feature_flags.router import admin_router as feature_flags_admin_router
from app.modules.feature_flags.router import router as feature_flags_router
from app.modules.health.router import router as health_router
from app.modules.jobs.router import router as jobs_router
from app.modules.notifications.router import router as notifications_router
from app.modules.organizations.router import invitations_router
from app.modules.organizations.router import router as organizations_router
from app.modules.pairing.router import router as pairing_router
from app.modules.presets.router import router as presets_router
from app.modules.printers.router import connections_router
from app.modules.printers.router import router as printers_router
from app.modules.users.router import router as users_router

API_V1_PREFIX = "/api/v1"

api_router = APIRouter(prefix=API_V1_PREFIX, responses=problem_responses(401, 403, 404, 422))

for router in (
    health_router,
    auth_router,
    users_router,
    devices_router,
    organizations_router,
    invitations_router,
    audit_router,
    printers_router,
    connections_router,
    pairing_router,
    capabilities_router,
    capabilities_admin_router,
    jobs_router,
    presets_router,
    documents_router,
    notifications_router,
    feature_flags_router,
    feature_flags_admin_router,
):
    api_router.include_router(router)
