"""Saved print, scan, and copy settings (FRD §17)."""

import uuid

from pydantic import BaseModel, TypeAdapter, ValidationError
from sqlalchemy import ColumnElement, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import FieldError, NotFoundError, PermissionDeniedError, ValidationFailedError
from app.core.permissions import Permission
from app.modules.jobs.models import JobType
from app.modules.jobs.schemas import CopySettings, PrintSettings, ScanSettings
from app.modules.organizations.context import OrgContext
from app.modules.presets.models import Preset, PresetScope
from app.modules.presets.schemas import (
    CopyPresetCreate,
    PresetRead,
    PresetUpdate,
    PrintPresetCreate,
    ScanPresetCreate,
)
from app.modules.printers import service as printers

AnyPresetCreate = PrintPresetCreate | ScanPresetCreate | CopyPresetCreate

_PRESET_READ: TypeAdapter[PresetRead] = TypeAdapter(PresetRead)
_SETTINGS_MODEL: dict[JobType, type[BaseModel]] = {
    JobType.PRINT: PrintSettings,
    JobType.SCAN: ScanSettings,
    JobType.COPY: CopySettings,
}


def to_read(preset: Preset) -> PresetRead:
    return _PRESET_READ.validate_python(preset, from_attributes=True)


def _visible(ctx: OrgContext) -> list[ColumnElement[bool]]:
    return [
        Preset.organization_id == ctx.organization.id,
        or_(Preset.scope == PresetScope.ORGANIZATION, Preset.owner_user_id == ctx.user.id),
    ]


def _ensure_may_write(ctx: OrgContext, scope: PresetScope) -> None:
    needed = (
        Permission.PRESETS_MANAGE_ORG
        if scope is PresetScope.ORGANIZATION
        else Permission.JOBS_CREATE
    )
    if not ctx.has(needed):
        raise PermissionDeniedError(
            "permission.denied",
            f"Your role does not allow this action (requires {needed.value}).",
        )


async def get(session: AsyncSession, ctx: OrgContext, preset_id: uuid.UUID) -> Preset:
    preset: Preset | None = await session.scalar(
        select(Preset).where(Preset.id == preset_id, *_visible(ctx))
    )
    if preset is None:
        raise NotFoundError("preset.not_found", "Preset not found.")
    return preset


async def list_presets(
    session: AsyncSession,
    ctx: OrgContext,
    *,
    type: JobType | None = None,
    printer_id: uuid.UUID | None = None,
) -> list[Preset]:
    """Presets the caller can use: their own and the organization's.

    With `printer_id`, returns presets for that printer and presets for all printers.
    """
    stmt = select(Preset).where(*_visible(ctx))
    if type is not None:
        stmt = stmt.where(Preset.type == type)
    if printer_id is not None:
        stmt = stmt.where(or_(Preset.printer_id == printer_id, Preset.printer_id.is_(None)))
    return list(await session.scalars(stmt.order_by(Preset.name, Preset.id)))


async def _clear_other_defaults(session: AsyncSession, preset: Preset) -> None:
    """Keep one default per scope, owner, printer, and job type."""
    await session.execute(
        update(Preset)
        .where(
            Preset.organization_id == preset.organization_id,
            Preset.scope == preset.scope,
            Preset.owner_user_id.is_not_distinct_from(preset.owner_user_id),
            Preset.printer_id.is_not_distinct_from(preset.printer_id),
            Preset.type == preset.type,
            Preset.id != preset.id,
            Preset.is_default,
        )
        .values(is_default=False)
    )


async def create(session: AsyncSession, ctx: OrgContext, payload: AnyPresetCreate) -> Preset:
    _ensure_may_write(ctx, payload.scope)
    if payload.printer_id is not None:
        await printers.get(
            session, organization_id=ctx.organization.id, printer_id=payload.printer_id
        )
    preset = Preset(
        organization_id=ctx.organization.id,
        owner_user_id=ctx.user.id if payload.scope is PresetScope.PERSONAL else None,
        scope=payload.scope,
        type=payload.type,
        name=payload.name.strip(),
        settings=payload.settings.model_dump(mode="json"),
        printer_id=payload.printer_id,
        is_default=payload.is_default,
    )
    session.add(preset)
    await session.flush()
    if preset.is_default:
        await _clear_other_defaults(session, preset)
    return preset


def _validated_settings(job_type: JobType, settings: dict[str, object]) -> dict[str, object]:
    try:
        return _SETTINGS_MODEL[job_type].model_validate(settings).model_dump(mode="json")
    except ValidationError as exc:
        raise ValidationFailedError(
            "preset.invalid_settings",
            f"These settings are not valid for a {job_type.value} preset.",
            errors=[
                FieldError(
                    field="settings." + ".".join(str(part) for part in error["loc"]),
                    message=error["msg"],
                    code=error["type"],
                )
                for error in exc.errors()
            ],
        ) from exc


async def update_preset(
    session: AsyncSession, ctx: OrgContext, preset: Preset, payload: PresetUpdate
) -> Preset:
    _ensure_may_write(ctx, preset.scope)
    if payload.name is not None:
        preset.name = payload.name.strip()
    if payload.settings is not None:
        preset.settings = _validated_settings(preset.type, payload.settings)
    if payload.is_default is not None:
        preset.is_default = payload.is_default
    await session.flush()
    if payload.is_default:
        await _clear_other_defaults(session, preset)
    return preset


async def delete(session: AsyncSession, ctx: OrgContext, preset: Preset) -> None:
    _ensure_may_write(ctx, preset.scope)
    await session.delete(preset)
    await session.flush()
