from typing import Any

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from tests.factories import create_printer, member_headers
from tests.modules.test_jobs import Scene, make_scene

API = "/api/v1"


def _url(scene: Scene) -> str:
    return f"{API}/organizations/{scene.organization.id}/presets"


def _print_preset(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "type": "print",
        "name": "A4 Black & White Duplex",
        "settings": {"color_mode": "monochrome", "duplex": "two_sided_long_edge"},
    }
    body.update(overrides)
    return body


async def test_personal_preset_is_private_to_its_owner(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    alice = await member_headers(session, scene.organization, Role.USER)
    bob = await member_headers(session, scene.organization, Role.USER)

    created = await client.post(_url(scene), headers=alice, json=_print_preset())

    assert created.status_code == 201
    preset = created.json()
    assert preset["scope"] == "personal"
    assert preset["settings"]["copies"] == 1
    assert [p["id"] for p in (await client.get(_url(scene), headers=alice)).json()] == [
        preset["id"]
    ]
    assert (await client.get(_url(scene), headers=bob)).json() == []
    assert (await client.get(f"{_url(scene)}/{preset['id']}", headers=bob)).status_code == 404
    assert (await client.delete(f"{_url(scene)}/{preset['id']}", headers=bob)).status_code == 404


async def test_organization_preset_is_shared_but_admin_managed(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    user = await member_headers(session, scene.organization, Role.USER)
    body = _print_preset(scope="organization", name="Office Default")

    denied = await client.post(_url(scene), headers=user, json=body)
    created = await client.post(_url(scene), headers=scene.headers, json=body)

    assert denied.status_code == 403
    assert created.status_code == 201
    preset = created.json()
    assert preset["owner_user_id"] is None
    assert [p["name"] for p in (await client.get(_url(scene), headers=user)).json()] == [
        "Office Default"
    ]
    renamed = await client.patch(
        f"{_url(scene)}/{preset['id']}", headers=user, json={"name": "Mine"}
    )
    assert renamed.status_code == 403


async def test_viewer_can_read_but_not_create_presets(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    viewer = await member_headers(session, scene.organization, Role.VIEWER)

    assert (await client.get(_url(scene), headers=viewer)).status_code == 200
    assert (await client.post(_url(scene), headers=viewer, json=_print_preset())).status_code == 403


async def test_one_default_per_printer_and_type(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    printer_id = str(scene.printer.id)

    async def create(**overrides: Any) -> dict[str, Any]:
        response = await client.post(
            _url(scene), headers=scene.headers, json=_print_preset(**overrides)
        )
        assert response.status_code == 201, response.text
        body: dict[str, Any] = response.json()
        return body

    first = await create(name="First", printer_id=printer_id, is_default=True)
    second = await create(name="Second", printer_id=printer_id, is_default=True)
    all_printers = await create(name="Everywhere", is_default=True)
    scan = (
        await client.post(
            _url(scene),
            headers=scene.headers,
            json={"type": "scan", "name": "Scan", "printer_id": printer_id, "is_default": True},
        )
    ).json()

    defaults = {
        preset["name"]: preset["is_default"]
        for preset in (await client.get(_url(scene), headers=scene.headers)).json()
    }
    assert defaults == {"First": False, "Second": True, "Everywhere": True, "Scan": True}

    # Promoting the first one demotes the second.
    await client.patch(
        f"{_url(scene)}/{first['id']}", headers=scene.headers, json={"is_default": True}
    )
    second_now = await client.get(f"{_url(scene)}/{second['id']}", headers=scene.headers)
    assert second_now.json()["is_default"] is False
    assert all_printers["is_default"] is True
    assert scan["is_default"] is True


async def test_list_filters_by_type_and_printer(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    other = await create_printer(session, scene.organization, friendly_name="Other")
    await client.post(
        _url(scene),
        headers=scene.headers,
        json=_print_preset(name="Here", printer_id=str(scene.printer.id)),
    )
    await client.post(
        _url(scene),
        headers=scene.headers,
        json=_print_preset(name="There", printer_id=str(other.id)),
    )
    await client.post(_url(scene), headers=scene.headers, json=_print_preset(name="Anywhere"))
    await client.post(_url(scene), headers=scene.headers, json={"type": "scan", "name": "Receipt"})

    for_printer = await client.get(
        _url(scene), headers=scene.headers, params={"printer_id": str(scene.printer.id)}
    )
    scans = await client.get(_url(scene), headers=scene.headers, params={"type": "scan"})

    assert [p["name"] for p in for_printer.json()] == ["Anywhere", "Here", "Receipt"]
    assert [p["name"] for p in scans.json()] == ["Receipt"]


async def test_update_validates_settings_against_the_preset_type(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    preset = (await client.post(_url(scene), headers=scene.headers, json=_print_preset())).json()
    url = f"{_url(scene)}/{preset['id']}"

    invalid = await client.patch(
        url, headers=scene.headers, json={"settings": {"resolution_dpi": 300}}
    )
    valid = await client.patch(
        url, headers=scene.headers, json={"name": "Draft", "settings": {"copies": 3}}
    )

    assert invalid.status_code == 422
    assert invalid.json()["code"] == "preset.invalid_settings"
    assert invalid.json()["errors"][0]["field"] == "settings.resolution_dpi"
    assert valid.json()["name"] == "Draft"
    assert valid.json()["settings"]["copies"] == 3
    assert valid.json()["settings"]["color_mode"] == "auto"  # settings are replaced as a whole


async def test_preset_for_an_unknown_printer_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene_a = await make_scene(session, name="A")
    scene_b = await make_scene(session, name="B")

    response = await client.post(
        _url(scene_a),
        headers=scene_a.headers,
        json=_print_preset(printer_id=str(scene_b.printer.id)),
    )

    assert response.status_code == 404
    assert response.json()["code"] == "printer.not_found"


async def test_delete_preset(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    preset = (await client.post(_url(scene), headers=scene.headers, json=_print_preset())).json()

    response = await client.delete(f"{_url(scene)}/{preset['id']}", headers=scene.headers)

    assert response.status_code == 204
    assert (await client.get(_url(scene), headers=scene.headers)).json() == []
