import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.deps import SessionDep
from app.core.permissions import Permission
from app.modules.jobs.models import JobType
from app.modules.organizations.deps import OrgContext, require
from app.modules.presets import service
from app.modules.presets.schemas import PresetCreate, PresetRead, PresetUpdate

router = APIRouter(prefix="/organizations/{org_id}/presets", tags=["presets"])

Member = Annotated[OrgContext, Depends(require(Permission.ORG_READ))]


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_preset(payload: PresetCreate, ctx: Member, session: SessionDep) -> PresetRead:
    """Save settings as a preset.

    A `personal` preset belongs to the caller. An `organization` preset is
    shared with every member and needs `presets.manage_org`.
    """
    return service.to_read(await service.create(session, ctx, payload))


@router.get("")
async def list_presets(
    ctx: Member,
    session: SessionDep,
    type: JobType | None = None,
    printer_id: uuid.UUID | None = None,
) -> list[PresetRead]:
    """The caller's personal presets and the organization's shared ones."""
    presets = await service.list_presets(session, ctx, type=type, printer_id=printer_id)
    return [service.to_read(preset) for preset in presets]


@router.get("/{preset_id}")
async def get_preset(preset_id: uuid.UUID, ctx: Member, session: SessionDep) -> PresetRead:
    return service.to_read(await service.get(session, ctx, preset_id))


@router.patch("/{preset_id}")
async def update_preset(
    preset_id: uuid.UUID, payload: PresetUpdate, ctx: Member, session: SessionDep
) -> PresetRead:
    preset = await service.get(session, ctx, preset_id)
    return service.to_read(await service.update_preset(session, ctx, preset, payload))


@router.delete("/{preset_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_preset(preset_id: uuid.UUID, ctx: Member, session: SessionDep) -> None:
    preset = await service.get(session, ctx, preset_id)
    await service.delete(session, ctx, preset)
