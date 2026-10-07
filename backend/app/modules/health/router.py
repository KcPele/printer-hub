"""Liveness and readiness probes."""

from typing import Literal

import structlog
from fastapi import APIRouter, Response, status
from sqlalchemy import text

from app.core.deps import SessionDep
from app.core.redis import get_redis
from app.core.schemas import ApiModel

log = structlog.get_logger(__name__)
router = APIRouter(prefix="/health", tags=["health"])

ComponentStatus = Literal["ok", "unavailable"]


class Liveness(ApiModel):
    status: Literal["ok"] = "ok"


class Readiness(ApiModel):
    status: ComponentStatus
    database: ComponentStatus
    redis: ComponentStatus


@router.get("/live")
async def live() -> Liveness:
    """The process is running."""
    return Liveness()


@router.get("/ready", responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"model": Readiness}})
async def ready(session: SessionDep, response: Response) -> Readiness:
    """The process can reach its dependencies and serve traffic."""
    database: ComponentStatus = "ok"
    redis: ComponentStatus = "ok"
    try:
        await session.execute(text("SELECT 1"))
    except Exception:
        log.exception("readiness_database_failed")
        database = "unavailable"
    try:
        await get_redis().ping()
    except Exception:
        log.exception("readiness_redis_failed")
        redis = "unavailable"

    healthy = database == "ok" and redis == "ok"
    if not healthy:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return Readiness(status="ok" if healthy else "unavailable", database=database, redis=redis)
