import fnmatch
import uuid

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, NotFoundError
from app.modules.capabilities.models import CapabilityProfile
from app.modules.capabilities.schemas import CapabilityProfileWrite
from app.modules.capabilities.seed import BUILT_IN_PROFILES


def _apply(profile: CapabilityProfile, payload: CapabilityProfileWrite) -> None:
    profile.manufacturer = payload.manufacturer
    profile.display_name = payload.display_name
    profile.model_patterns = payload.model_patterns
    profile.capabilities = payload.capabilities.model_dump(mode="json")
    profile.optional_features = payload.optional_features
    profile.notes = payload.notes
    profile.category = payload.category
    profile.summary = payload.summary
    profile.popularity = payload.popularity
    profile.setup_tips = payload.setup_tips


def _content(profile: CapabilityProfile) -> tuple[object, ...]:
    """Everything a client reads from a profile, to tell whether it changed."""
    return (
        profile.model_patterns,
        profile.capabilities,
        profile.optional_features,
        profile.notes,
        profile.category,
        profile.summary,
        profile.popularity,
        profile.setup_tips,
    )


async def list_profiles(
    session: AsyncSession, *, manufacturer: str | None = None
) -> list[CapabilityProfile]:
    # The catalogue's order: the families most people have first.
    stmt = select(CapabilityProfile).order_by(
        CapabilityProfile.popularity.desc(),
        CapabilityProfile.manufacturer,
        CapabilityProfile.display_name,
    )
    if manufacturer is not None:
        stmt = stmt.where(func.lower(CapabilityProfile.manufacturer) == manufacturer.lower())
    return list(await session.scalars(stmt))


async def match(session: AsyncSession, *, manufacturer: str, model: str) -> CapabilityProfile:
    """Find the profile for a reported manufacturer and model name.

    When several profiles match, the one with the longest matching pattern
    wins, so a specific model beats its series.
    """
    best: tuple[int, CapabilityProfile] | None = None
    lowered = model.lower()
    for profile in await list_profiles(session, manufacturer=manufacturer):
        for pattern in profile.model_patterns:
            if fnmatch.fnmatchcase(lowered, pattern.lower()) and (
                best is None or len(pattern) > best[0]
            ):
                best = (len(pattern), profile)
    if best is None:
        raise NotFoundError(
            "capability_profile.no_match", "No capability profile matches this printer."
        )
    return best[1]


async def get(session: AsyncSession, profile_id: uuid.UUID) -> CapabilityProfile:
    profile = await session.get(CapabilityProfile, profile_id)
    if profile is None:
        raise NotFoundError("capability_profile.not_found", "Capability profile not found.")
    return profile


async def _flush_unique(session: AsyncSession) -> None:
    try:
        await session.flush()
    except IntegrityError as exc:
        raise ConflictError(
            "capability_profile.duplicate",
            "A profile with this manufacturer and name already exists.",
        ) from exc


async def create(session: AsyncSession, payload: CapabilityProfileWrite) -> CapabilityProfile:
    profile = CapabilityProfile()
    _apply(profile, payload)
    session.add(profile)
    await _flush_unique(session)
    return profile


async def replace(
    session: AsyncSession, profile_id: uuid.UUID, payload: CapabilityProfileWrite
) -> CapabilityProfile:
    profile = await get(session, profile_id)
    _apply(profile, payload)
    profile.version += 1
    await _flush_unique(session)
    return profile


async def delete(session: AsyncSession, profile_id: uuid.UUID) -> None:
    await session.delete(await get(session, profile_id))
    await session.flush()


async def seed_built_in_profiles(session: AsyncSession) -> int:
    """Insert or refresh the built-in profiles. Safe to run repeatedly."""
    changed = 0
    for payload in BUILT_IN_PROFILES:
        existing = await session.scalar(
            select(CapabilityProfile).where(
                CapabilityProfile.manufacturer == payload.manufacturer,
                CapabilityProfile.display_name == payload.display_name,
            )
        )
        if existing is None:
            await create(session, payload)
            changed += 1
            continue
        before = _content(existing)
        _apply(existing, payload)
        after = _content(existing)
        if before != after:
            existing.version += 1
            changed += 1
    await session.flush()
    return changed
