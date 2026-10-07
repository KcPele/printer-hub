import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.core.deps import SessionDep
from app.core.errors import problem_responses
from app.modules.auth.deps import CurrentUser, SuperUser
from app.modules.capabilities import service
from app.modules.capabilities.schemas import CapabilityProfileRead, CapabilityProfileWrite

router = APIRouter(prefix="/capability-profiles", tags=["capabilities"])
admin_router = APIRouter(prefix="/admin/capability-profiles", tags=["admin"])


@router.get("")
async def list_profiles(
    _: CurrentUser, session: SessionDep, manufacturer: str | None = None
) -> list[CapabilityProfileRead]:
    profiles = await service.list_profiles(session, manufacturer=manufacturer)
    return [CapabilityProfileRead.model_validate(profile) for profile in profiles]


@router.get("/match")
async def match_profile(
    _: CurrentUser,
    session: SessionDep,
    manufacturer: Annotated[str, Query(min_length=1, max_length=100)],
    model: Annotated[str, Query(min_length=1, max_length=200)],
) -> CapabilityProfileRead:
    """The vendor baseline for a discovered printer: what to expect and what to probe."""
    profile = await service.match(session, manufacturer=manufacturer, model=model)
    return CapabilityProfileRead.model_validate(profile)


@admin_router.post("", status_code=status.HTTP_201_CREATED, responses=problem_responses(409))
async def create_profile(
    payload: CapabilityProfileWrite, _: SuperUser, session: SessionDep
) -> CapabilityProfileRead:
    profile = await service.create(session, payload)
    return CapabilityProfileRead.model_validate(profile)


@admin_router.put("/{profile_id}", responses=problem_responses(409))
async def replace_profile(
    profile_id: uuid.UUID, payload: CapabilityProfileWrite, _: SuperUser, session: SessionDep
) -> CapabilityProfileRead:
    profile = await service.replace(session, profile_id, payload)
    return CapabilityProfileRead.model_validate(profile)


@admin_router.delete("/{profile_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile(profile_id: uuid.UUID, _: SuperUser, session: SessionDep) -> None:
    await service.delete(session, profile_id)
