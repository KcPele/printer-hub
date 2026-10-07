"""Mounts every module router under the versioned API prefix."""

from fastapi import APIRouter

from app.core.errors import problem_responses
from app.modules.health.router import router as health_router

API_V1_PREFIX = "/api/v1"

api_router = APIRouter(prefix=API_V1_PREFIX, responses=problem_responses(401, 403, 404, 422))
api_router.include_router(health_router)
