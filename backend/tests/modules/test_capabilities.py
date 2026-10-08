import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.capabilities import service
from app.modules.capabilities.schemas import CapabilityProfileWrite
from app.modules.capabilities.seed import BUILT_IN_PROFILES
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
    assert await service.seed_built_in_profiles(session) == len(BUILT_IN_PROFILES)
    assert await service.seed_built_in_profiles(session) == 0
    profiles = await service.list_profiles(session)
    assert len(profiles) == len(BUILT_IN_PROFILES)
    assert {profile.version for profile in profiles} == {1}


@pytest.mark.parametrize(
    ("manufacturer", "model", "family"),
    [
        # As printers name themselves over IPP, with and without the maker's name.
        ("Xerox", "Xerox VersaLink C7130", "VersaLink C7100 Series"),
        ("Xerox", "VersaLink C405", "VersaLink"),
        ("Xerox", "AltaLink C8055", "AltaLink and WorkCentre"),
        ("Xerox", "Xerox B215 Multifunction Printer", "B and C series"),
        ("HP", "HP LaserJet Pro MFP M428fdw", "LaserJet Pro MFP"),
        ("HP", "HP Color LaserJet Pro MFP M479fdw", "LaserJet Pro MFP"),
        ("HP", "HP LaserJet Pro M404dn", "LaserJet"),
        ("HP", "HP OfficeJet Pro 9010 series", "OfficeJet"),
        ("HP", "HP DeskJet 2700 series", "DeskJet, ENVY, and Smart Tank"),
        ("hp", "HP ENVY 6000 series", "DeskJet, ENVY, and Smart Tank"),
        ("Epson", "EPSON ET-2850 Series", "EcoTank"),
        ("EPSON", "EPSON L3250 Series", "EcoTank"),
        ("Epson", "EPSON WF-4830 Series", "Expression and WorkForce"),
        ("Canon", "Canon TS8300 series", "PIXMA"),
        ("Canon", "Canon MG3600 series", "PIXMA"),
        ("Canon", "Canon G3020 series", "PIXMA"),
        ("Canon", "Canon GX7000 series", "MAXIFY"),
        ("Canon", "Canon MF640C Series", "i-SENSYS and imageCLASS MF"),
        ("Canon", "Canon iR-ADV C5535", "imageRUNNER"),
        ("Brother", "Brother MFC-L2710DW series", "MFC-L and DCP-L lasers"),
        ("Brother", "Brother HL-L2350DW series", "HL-L lasers"),
        ("Brother", "Brother MFC-J4540DW", "MFC-J and DCP-J inkjets"),
        ("Kyocera", "Kyocera ECOSYS M5526cdw", "ECOSYS"),
        ("Kyocera", "TASKalfa 2554ci", "TASKalfa"),
        ("Ricoh", "RICOH IM C3000", "IM and MP"),
        ("Ricoh", "MP C3004", "IM and MP"),
        ("Ricoh", "RICOH M C250FW", "SP and M series"),
        ("Ricoh", "M 320F", "SP and M series"),
        ("Ricoh", "RICOH SP C261SFNw", "SP and M series"),
        ("Lexmark", "Lexmark MC3224adwe", "MB, MC, MX, and CX"),
        ("Lexmark", "Lexmark CX431adw", "MB, MC, MX, and CX"),
        ("Lexmark", "Lexmark C3224dw", "B, C, MS, and CS"),
        ("Lexmark", "Lexmark MS431dn", "B, C, MS, and CS"),
        ("Samsung", "Samsung M2070 Series", "Xpress and ProXpress"),
        ("Konica Minolta", "KONICA MINOLTA bizhub C300i", "bizhub"),
        ("Sharp", "SHARP MX-3071", "MX and BP"),
    ],
)
async def test_each_family_is_matched_by_its_models(
    session: AsyncSession, manufacturer: str, model: str, family: str
) -> None:
    await service.seed_built_in_profiles(session)

    profile = await service.match(session, manufacturer=manufacturer, model=model)

    assert profile.display_name == family


async def test_the_catalogue_lists_the_most_popular_families_first(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    await service.seed_built_in_profiles(session)

    response = await client.get(
        f"{API}/capability-profiles",
        headers=await auth_headers(session, await create_user(session)),
    )

    assert response.status_code == 200
    families = response.json()
    assert families[0]["display_name"] == "VersaLink C7100 Series"
    assert [f["popularity"] for f in families] == sorted(
        (f["popularity"] for f in families), reverse=True
    )
    first = families[0]
    assert first["category"] == "office_multifunction"
    assert first["summary"].startswith("A3 colour multifunction")
    assert any("Mopria scanning" in tip for tip in first["setup_tips"])
    # Every family says what kind of machine it is and how to set it up.
    assert all(f["summary"] and f["setup_tips"] for f in families)
    assert {f["category"] for f in families} == {
        "office_multifunction",
        "office_printer",
        "home_multifunction",
        "home_printer",
    }


async def test_a_home_family_is_not_assumed_to_read_pdf(session: AsyncSession) -> None:
    await service.seed_built_in_profiles(session)

    home = await service.match(session, manufacturer="Epson", model="EPSON ET-2850 Series")
    office = await service.match(session, manufacturer="HP", model="HP LaserJet Pro M404dn")

    assert "application/pdf" not in home.capabilities["print"]["document_formats"]
    assert "image/pwg-raster" in home.capabilities["print"]["document_formats"]
    assert "print.document_formats" in home.optional_features
    assert "application/pdf" in office.capabilities["print"]["document_formats"]
    assert office.capabilities["scan"]["supported"] is False
    assert "print.color" in office.optional_features


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
