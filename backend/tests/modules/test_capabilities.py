import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.capabilities import service
from app.modules.capabilities.schemas import CapabilityProfileWrite
from tests.factories import auth_headers, create_user

API = "/api/v1"

PROFILE = {
    "manufacturer": "Brother",
    "display_name": "HL-L2300 Series",
    "model_patterns": ["HL-L23*"],
    "capabilities": {"print": {"supported": True, "color": False}},
}


async def test_match_finds_the_xerox_c7130(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    await service.seed_built_in_profiles(session)
    headers = await auth_headers(session, await create_user(session))

    response = await client.get(
        f"{API}/capability-profiles/match",
        headers=headers,
        params={"manufacturer": "xerox", "model": "Xerox VersaLink C7130"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["display_name"] == "VersaLink C7100 Series"
    assert body["capabilities"]["print"]["color"] is True
    assert body["capabilities"]["scan"]["sources"] == ["platen", "adf"]
    # The wireless kit is optional hardware: unknown until probed.
    assert body["capabilities"]["connectivity"]["wifi"] is None
    assert "connectivity.wifi_direct" in body["optional_features"]
    assert body["capabilities"]["connectivity"]["nfc"] is True


async def test_match_reports_no_profile(client: httpx.AsyncClient, session: AsyncSession) -> None:
    await service.seed_built_in_profiles(session)

    response = await client.get(
        f"{API}/capability-profiles/match",
        headers=await auth_headers(session, await create_user(session)),
        params={"manufacturer": "Xerox", "model": "Phaser 3020"},
    )

    assert response.status_code == 404
    assert response.json()["code"] == "capability_profile.no_match"


async def test_seeding_is_idempotent(session: AsyncSession) -> None:
    assert await service.seed_built_in_profiles(session) == 1
    assert await service.seed_built_in_profiles(session) == 0
    [profile] = await service.list_profiles(session)
    assert profile.version == 1


async def test_most_specific_pattern_wins(session: AsyncSession) -> None:
    await service.create(
        session, CapabilityProfileWrite.model_validate({**PROFILE, "display_name": "Series"})
    )
    await service.create(
        session,
        CapabilityProfileWrite.model_validate(
            {**PROFILE, "display_name": "Exact", "model_patterns": ["HL-L2350DW"]}
        ),
    )

    profile = await service.match(session, manufacturer="brother", model="hl-l2350dw")

    assert profile.display_name == "Exact"


async def test_registry_is_managed_by_superusers_only(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    regular = await auth_headers(session, await create_user(session))
    admin = await auth_headers(session, await create_user(session, is_superuser=True))
    url = f"{API}/admin/capability-profiles"

    denied = await client.post(url, headers=regular, json=PROFILE)
    created = await client.post(url, headers=admin, json=PROFILE)

    assert denied.status_code == 403
    assert denied.json()["code"] == "permission.superuser_required"
    assert created.status_code == 201
    profile_id = created.json()["id"]
    assert created.json()["version"] == 1

    duplicate = await client.post(url, headers=admin, json=PROFILE)
    assert duplicate.status_code == 409

    replaced = await client.put(
        f"{url}/{profile_id}", headers=admin, json={**PROFILE, "notes": ["Mono laser"]}
    )
    assert replaced.json()["version"] == 2
    assert replaced.json()["notes"] == ["Mono laser"]

    listing = await client.get(f"{API}/capability-profiles", headers=regular)
    assert [item["display_name"] for item in listing.json()] == ["HL-L2300 Series"]

    assert (await client.delete(f"{url}/{profile_id}", headers=admin)).status_code == 204
    assert (await client.get(f"{API}/capability-profiles", headers=regular)).json() == []
