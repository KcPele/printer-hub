import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.audit.models import AuditLog
from app.modules.printers.models import Printer
from tests.factories import (
    auth_headers,
    create_connection,
    create_organization,
    create_printer,
    create_user,
    member_headers,
)

API = "/api/v1"

CAPABILITIES = {
    "schema_version": 1,
    "print": {
        "supported": True,
        "color": True,
        "duplex_modes": ["one_sided", "two_sided_long_edge"],
        "media_sizes": ["iso_a4_210x297mm", "iso_a3_297x420mm"],
        "trays": [{"id": "tray-1", "name": "Tray 1", "media_size": "iso_a4_210x297mm"}],
        "document_formats": ["application/pdf"],
    },
    "scan": {"supported": True, "sources": ["platen", "adf"], "resolutions_dpi": [300, 600]},
    "copy": {"supported": True},
    "protocols": {"ipp": True, "ipps": True, "escl": False},
    "connectivity": {"ethernet": True, "wifi": False},
}


async def test_add_printer_with_verified_connections(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)

    response = await client.post(
        f"{API}/organizations/{organization.id}/printers",
        headers=await auth_headers(session, owner),
        json={
            "friendly_name": "Office Xerox",
            "manufacturer": "Xerox",
            "model": "VersaLink C7130",
            "serial_number": "XRX-0001",
            "location": "Reception",
            "capabilities": CAPABILITIES,
            "connections": [
                {
                    "type": "ipps",
                    "purposes": ["print", "status"],
                    "configuration": {"host": "192.168.1.50", "port": 631, "tls": True},
                },
                {"type": "airprint", "purposes": ["print"]},
                {"type": "escl", "purposes": ["scan"], "configuration": {"host": "192.168.1.50"}},
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "unknown"
    assert body["capabilities"]["print"]["color"] is True
    assert body["capabilities"]["copy"] == {"supported": True, "native_remote_control": False}
    assert body["capabilities"]["protocols"]["airprint"] is None
    assert [c["type"] for c in body["connections"]] == ["ipps", "airprint", "escl"]
    assert [c["priority"] for c in body["connections"]] == [1, 2, 3]
    assert body["default_connection_id"] == body["connections"][0]["id"]
    actions = set(await session.scalars(select(AuditLog.action)))
    assert {"printer.added", "connection.created"} <= actions


async def test_duplicate_serial_number_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    await create_printer(session, organization, serial_number="XRX-0001")

    response = await client.post(
        f"{API}/organizations/{organization.id}/printers",
        headers=await auth_headers(session, owner),
        json={"friendly_name": "Same device again", "serial_number": "XRX-0001"},
    )

    assert response.status_code == 409
    assert response.json()["code"] == "printer.duplicate_serial"


async def test_printers_are_invisible_across_organizations(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    alice, bob = await create_user(session), await create_user(session)
    org_a = await create_organization(session, alice, name="A")
    org_b = await create_organization(session, bob, name="B")
    printer = await create_printer(session, org_a)
    bob_headers = await auth_headers(session, bob)

    # Bob cannot reach org A at all, and org A's printer is not in org B.
    foreign_org = await client.get(
        f"{API}/organizations/{org_a.id}/printers/{printer.id}", headers=bob_headers
    )
    wrong_org = await client.get(
        f"{API}/organizations/{org_b.id}/printers/{printer.id}", headers=bob_headers
    )
    listing = await client.get(f"{API}/organizations/{org_b.id}/printers", headers=bob_headers)

    assert foreign_org.status_code == 404
    assert wrong_org.status_code == 404
    assert wrong_org.json()["code"] == "printer.not_found"
    assert listing.json()["items"] == []


async def test_only_managers_can_add_or_change_printers(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    printer = await create_printer(session, organization)
    operator = await member_headers(session, organization, Role.OPERATOR)
    url = f"{API}/organizations/{organization.id}/printers"

    created = await client.post(url, headers=operator, json={"friendly_name": "Nope"})
    renamed = await client.patch(
        f"{url}/{printer.id}", headers=operator, json={"friendly_name": "Nope"}
    )
    removed = await client.delete(f"{url}/{printer.id}", headers=operator)
    listed = await client.get(url, headers=operator)

    assert created.status_code == renamed.status_code == removed.status_code == 403
    assert listed.status_code == 200


async def test_update_printer(client: httpx.AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization, location="Reception")

    response = await client.patch(
        f"{API}/organizations/{organization.id}/printers/{printer.id}",
        headers=await auth_headers(session, owner),
        json={"friendly_name": "Front Desk", "auto_fallback_enabled": False},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["friendly_name"] == "Front Desk"
    assert body["auto_fallback_enabled"] is False
    assert body["location"] == "Reception"
    assert body["model"] == "VersaLink C7130"


async def test_remove_printer_is_a_soft_delete(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization, serial_number="XRX-0001")
    headers = await auth_headers(session, owner)
    url = f"{API}/organizations/{organization.id}/printers"

    response = await client.delete(f"{url}/{printer.id}", headers=headers)

    assert response.status_code == 204
    assert (await client.get(f"{url}/{printer.id}", headers=headers)).status_code == 404
    assert (await client.get(url, headers=headers)).json()["items"] == []
    await session.refresh(printer)
    assert printer.deleted_at is not None
    # The serial number is free again for a re-added device.
    readded = await client.post(
        url, headers=headers, json={"friendly_name": "Back again", "serial_number": "XRX-0001"}
    )
    assert readded.status_code == 201


async def test_report_capabilities_replaces_the_snapshot(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    printer = await create_printer(session, organization)
    user = await member_headers(session, organization, Role.USER)

    response = await client.put(
        f"{API}/organizations/{organization.id}/printers/{printer.id}/capabilities",
        headers=user,
        json=CAPABILITIES,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["capabilities"]["scan"]["sources"] == ["platen", "adf"]
    assert body["capabilities_updated_at"] is not None


async def test_capabilities_are_validated(client: httpx.AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    headers = await auth_headers(session, owner)
    url = f"{API}/organizations/{organization.id}/printers/{printer.id}/capabilities"

    future_version = await client.put(url, headers=headers, json={"schema_version": 2})
    unknown_field = await client.put(
        url, headers=headers, json={"print": {"supported": True, "holographic": True}}
    )
    bad_enum = await client.put(url, headers=headers, json={"scan": {"sources": ["drum"]}})

    assert future_version.status_code == 422
    assert unknown_field.status_code == 422
    assert bad_enum.status_code == 422


async def test_viewer_cannot_report(client: httpx.AsyncClient, session: AsyncSession) -> None:
    organization = await create_organization(session, await create_user(session))
    printer = await create_printer(session, organization)

    response = await client.post(
        f"{API}/organizations/{organization.id}/printers/{printer.id}/status",
        headers=await member_headers(session, organization, Role.VIEWER),
        json={"status": "online"},
    )

    assert response.status_code == 403


async def test_status_report_updates_printer(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    printer = await create_printer(session, organization)
    headers = await member_headers(session, organization, Role.USER)
    url = f"{API}/organizations/{organization.id}/printers/{printer.id}/status"
    report = {
        "status": "online",
        "detail": {
            "consumables": [
                {
                    "name": "Black Toner",
                    "kind": "toner",
                    "color": "black",
                    "level_percent": 12,
                    "state": "low",
                }
            ],
            "trays": [{"id": "tray-1", "name": "Tray 1", "state": "empty"}],
            "alerts": [{"code": "media-empty", "severity": "warning"}],
            "scanner_state": "idle",
        },
    }

    first = await client.post(url, headers=headers, json=report)

    assert first.status_code == 200
    body = first.json()
    assert body["status"] == "online"
    assert body["last_seen_at"] is not None
    assert body["status_detail"]["consumables"][0]["level_percent"] == 12
    assert body["status_detail"]["alerts"][0]["code"] == "media-empty"

    # A report without detail keeps the last known detail.
    offline = await client.post(url, headers=headers, json={"status": "offline"})
    assert offline.json()["status"] == "offline"
    assert offline.json()["status_detail"]["trays"][0]["state"] == "empty"


async def test_printer_list_is_paginated(client: httpx.AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    for number in range(3):
        printer = await create_printer(session, organization, friendly_name=f"Printer {number}")
        await create_connection(session, printer)
    headers = await auth_headers(session, owner)
    url = f"{API}/organizations/{organization.id}/printers"

    first = (await client.get(url, headers=headers, params={"limit": 2})).json()
    second = (
        await client.get(url, headers=headers, params={"limit": 2, "cursor": first["next_cursor"]})
    ).json()

    names = [item["friendly_name"] for item in first["items"] + second["items"]]
    assert names == ["Printer 2", "Printer 1", "Printer 0"]
    assert all(len(item["connections"]) == 1 for item in first["items"])
    assert second["next_cursor"] is None
    assert await session.scalar(select(Printer).limit(1)) is not None
