import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Path, status

from app.core.deps import SessionDep
from app.core.permissions import Permission
from app.modules.auth.deps import SuperUser
from app.modules.feature_flags import service
from app.modules.feature_flags.schemas import (
    FeatureFlagOverrideWrite,
    FeatureFlagRead,
    FeatureFlagWrite,
    ResolvedFlags,
)
from app.modules.organizations.deps import OrgContext, require

router = APIRouter(tags=["feature-flags"])
admin_router = APIRouter(prefix="/admin/feature-flags", tags=["admin"])

FlagKey = Annotated[str, Path(pattern=r"^[a-z][a-z0-9_]{1,99}$")]


@router.get("/organizations/{org_id}/feature-flags")
async def get_feature_flags(
    ctx: Annotated[OrgContext, Depends(require(Permission.ORG_READ))], session: SessionDep
) -> ResolvedFlags:
    """Flags as they apply to this organization. Treat a flag that is absent as off."""
    return ResolvedFlags(flags=await service.resolve(session, ctx.organization.id))


@admin_router.get("")
async def list_feature_flags(_: SuperUser, session: SessionDep) -> list[FeatureFlagRead]:
    return await service.list_flags(session)


@admin_router.put("/{key}")
async def put_feature_flag(
    key: FlagKey, payload: FeatureFlagWrite, _: SuperUser, session: SessionDep
) -> FeatureFlagRead:
    """Create a flag or change its global value."""
    return await service.upsert(session, key, payload)


@admin_router.delete("/{key}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_feature_flag(key: FlagKey, _: SuperUser, session: SessionDep) -> None:
    await service.delete_flag(session, key)


@admin_router.put("/{key}/overrides/{organization_id}")
async def put_feature_flag_override(
    key: FlagKey,
    organization_id: uuid.UUID,
    payload: FeatureFlagOverrideWrite,
    _: SuperUser,
    session: SessionDep,
) -> FeatureFlagRead:
    """Set a flag for one organization, whatever its global value."""
    return await service.set_override(
        session, key=key, organization_id=organization_id, enabled=payload.enabled
    )


@admin_router.delete("/{key}/overrides/{organization_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_feature_flag_override(
    key: FlagKey, organization_id: uuid.UUID, _: SuperUser, session: SessionDep
) -> None:
    await service.clear_override(session, key=key, organization_id=organization_id)
