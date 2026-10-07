import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.feature_flags import service
from app.modules.feature_flags.schemas import FeatureFlagWrite
from tests.factories import (
    auth_headers,
    create_organization,
    create_user,
    member_headers,
)

API = "/api/v1"
ADMIN = f"{API}/admin/feature-flags"


async def test_override_beats_the_global_value(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    admin = await auth_headers(session, await create_user(session, is_superuser=True))
    pilot = await create_organization(session, await create_user(session), name="Pilot")
    other = await create_organization(session, await create_user(session), name="Other")
    pilot_member = await member_headers(session, pilot, Role.VIEWER)
    other_member = await member_headers(session, other, Role.VIEWER)

    created = await client.put(
        f"{ADMIN}/scan_to_email",
        headers=admin,
        json={"description": "Send scans by email.", "enabled": False},
    )
    await client.put(f"{ADMIN}/direct_ipp", headers=admin, json={"enabled": True})
    overridden = await client.put(
        f"{ADMIN}/scan_to_email/overrides/{pilot.id}", headers=admin, json={"enabled": True}
    )

    assert created.status_code == 200
    assert overridden.json()["overrides"] == [{"organization_id": str(pilot.id), "enabled": True}]
    pilot_flags = await client.get(
        f"{API}/organizations/{pilot.id}/feature-flags", headers=pilot_member
    )
    other_flags = await client.get(
        f"{API}/organizations/{other.id}/feature-flags", headers=other_member
    )
    assert pilot_flags.json() == {"flags": {"direct_ipp": True, "scan_to_email": True}}
    assert other_flags.json() == {"flags": {"direct_ipp": True, "scan_to_email": False}}

    # Turning the flag on globally, then switching the pilot off, still honors the override.
    await client.put(f"{ADMIN}/scan_to_email", headers=admin, json={"enabled": True})
    await client.put(
        f"{ADMIN}/scan_to_email/overrides/{pilot.id}", headers=admin, json={"enabled": False}
    )
    assert await service.is_enabled(session, "scan_to_email", pilot.id) is False
    assert await service.is_enabled(session, "scan_to_email", other.id) is True

    cleared = await client.delete(f"{ADMIN}/scan_to_email/overrides/{pilot.id}", headers=admin)
    assert cleared.status_code == 204
    assert await service.is_enabled(session, "scan_to_email", pilot.id) is True


async def test_unknown_flag_is_off(session: AsyncSession) -> None:
    organization = await create_organization(session, await create_user(session))

    assert await service.is_enabled(session, "does_not_exist", organization.id) is False


async def test_flags_are_managed_by_superusers_only(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    await create_organization(session, owner)
    headers = await auth_headers(session, owner)

    assert (await client.get(ADMIN, headers=headers)).status_code == 403
    assert (
        await client.put(f"{ADMIN}/secure_print", headers=headers, json={"enabled": True})
    ).status_code == 403


async def test_flag_keys_are_validated_and_flags_can_be_deleted(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    admin = await auth_headers(session, await create_user(session, is_superuser=True))

    bad = await client.put(f"{ADMIN}/Not-A-Key", headers=admin, json={"enabled": True})
    await client.put(f"{ADMIN}/temporary", headers=admin, json={"enabled": True})
    listed = await client.get(ADMIN, headers=admin)
    deleted = await client.delete(f"{ADMIN}/temporary", headers=admin)
    missing = await client.delete(f"{ADMIN}/temporary", headers=admin)

    assert bad.status_code == 422
    assert [flag["key"] for flag in listed.json()] == ["temporary"]
    assert deleted.status_code == 204
    assert missing.status_code == 404
    assert missing.json()["code"] == "feature_flag.not_found"


async def test_override_for_an_unknown_flag_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    admin = await auth_headers(session, await create_user(session, is_superuser=True))
    organization = await create_organization(session, await create_user(session))

    response = await client.put(
        f"{ADMIN}/nope/overrides/{organization.id}", headers=admin, json={"enabled": True}
    )

    assert response.status_code == 404


async def test_seeding_adds_missing_flags_and_keeps_operator_choices(
    session: AsyncSession,
) -> None:
    organization = await create_organization(session, await create_user(session))
    created = await service.seed_built_in_flags(session)
    assert created > 0
    flags = await service.resolve(session, organization.id)
    assert flags["direct_ipp"] is True
    assert flags["scan_to_email"] is False

    # An operator turns a flag on; seeding again must not turn it back off.
    await service.upsert(session, "scan_to_email", FeatureFlagWrite(enabled=True))
    assert await service.seed_built_in_flags(session) == 0
    assert (await service.resolve(session, organization.id))["scan_to_email"] is True
