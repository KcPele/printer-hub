import uuid

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.modules.feature_flags.models import FeatureFlag, FeatureFlagOverride
from app.modules.feature_flags.schemas import (
    FeatureFlagOverrideRead,
    FeatureFlagRead,
    FeatureFlagWrite,
)
from app.modules.feature_flags.seed import BUILT_IN_FLAGS


async def resolve(session: AsyncSession, organization_id: uuid.UUID) -> dict[str, bool]:
    """Every flag's value for one organization: its override, else the global value."""
    rows = await session.execute(
        select(FeatureFlag.key, FeatureFlag.enabled, FeatureFlagOverride.enabled)
        .outerjoin(
            FeatureFlagOverride,
            (FeatureFlagOverride.flag_key == FeatureFlag.key)
            & (FeatureFlagOverride.organization_id == organization_id),
        )
        .order_by(FeatureFlag.key)
    )
    return {key: override if override is not None else enabled for key, enabled, override in rows}


async def is_enabled(session: AsyncSession, key: str, organization_id: uuid.UUID) -> bool:
    return (await resolve(session, organization_id)).get(key, False)


async def _get(session: AsyncSession, key: str) -> FeatureFlag:
    flag = await session.get(FeatureFlag, key)
    if flag is None:
        raise NotFoundError("feature_flag.not_found", "Feature flag not found.")
    return flag


async def _to_read(session: AsyncSession, flags: list[FeatureFlag]) -> list[FeatureFlagRead]:
    overrides: dict[str, list[FeatureFlagOverrideRead]] = {flag.key: [] for flag in flags}
    if flags:
        rows = await session.scalars(
            select(FeatureFlagOverride)
            .where(FeatureFlagOverride.flag_key.in_(overrides))
            .order_by(FeatureFlagOverride.id)
        )
        for override in rows:
            overrides[override.flag_key].append(FeatureFlagOverrideRead.model_validate(override))
    return [
        FeatureFlagRead(
            key=flag.key,
            description=flag.description,
            enabled=flag.enabled,
            overrides=overrides[flag.key],
            updated_at=flag.updated_at,
        )
        for flag in flags
    ]


async def list_flags(session: AsyncSession) -> list[FeatureFlagRead]:
    flags = list(await session.scalars(select(FeatureFlag).order_by(FeatureFlag.key)))
    return await _to_read(session, flags)


async def upsert(session: AsyncSession, key: str, payload: FeatureFlagWrite) -> FeatureFlagRead:
    flag = await session.get(FeatureFlag, key)
    if flag is None:
        flag = FeatureFlag(key=key)
        session.add(flag)
    flag.description = payload.description
    flag.enabled = payload.enabled
    await session.flush()
    return (await _to_read(session, [flag]))[0]


async def delete_flag(session: AsyncSession, key: str) -> None:
    await session.delete(await _get(session, key))
    await session.flush()


async def set_override(
    session: AsyncSession, *, key: str, organization_id: uuid.UUID, enabled: bool
) -> FeatureFlagRead:
    flag = await _get(session, key)
    await session.execute(
        insert(FeatureFlagOverride)
        .values(flag_key=key, organization_id=organization_id, enabled=enabled)
        .on_conflict_do_update(
            index_elements=["flag_key", "organization_id"], set_={"enabled": enabled}
        )
    )
    return (await _to_read(session, [flag]))[0]


async def clear_override(session: AsyncSession, *, key: str, organization_id: uuid.UUID) -> None:
    await _get(session, key)
    await session.execute(
        delete(FeatureFlagOverride).where(
            FeatureFlagOverride.flag_key == key,
            FeatureFlagOverride.organization_id == organization_id,
        )
    )


async def seed_built_in_flags(session: AsyncSession) -> int:
    """Insert built-in flags that do not exist yet. Existing flags keep their values."""
    existing = set(await session.scalars(select(FeatureFlag.key)))
    created = 0
    for key, (enabled, description) in BUILT_IN_FLAGS.items():
        if key not in existing:
            session.add(FeatureFlag(key=key, enabled=enabled, description=description))
            created += 1
    await session.flush()
    return created
