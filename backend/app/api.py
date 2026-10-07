"""Mounts every module router under the versioned API prefix."""

from fastapi import APIRouter

from app.core.errors import problem_responses
from app.modules.audit.router import router as audit_router
from app.modules.auth.router import router as auth_router
from app.modules.devices.router import router as devices_router
from app.modules.health.router import router as health_router
from app.modules.organizations.router import invitations_router
from app.modules.organizations.router import router as organizations_router
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
):
    api_router.include_router(router)
