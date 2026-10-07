import uuid

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.crypto import decrypt_json
from app.core.permissions import Role
from app.modules.audit.models import AuditLog
from app.modules.connections.models import Connection
from tests.factories import (
    auth_headers,
    create_connection,
    create_organization,
    create_printer,
    create_user,
    member_headers,
)

API = "/api/v1"

SMB = {
    "type": "smb",
    "purposes": ["scan"],
    "configuration": {"host": "fileserver.local", "options": {"share": "scans"}},
    "credentials": {"username": "scanner", "password": "hunter2-secret"},
}


async def _setup(session: AsyncSession) -> tuple[str, dict[str, str], Connection]:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    connection = await create_connection(session, printer)
    url = f"{API}/organizations/{organization.id}/printers/{printer.id}/connections"
    return url, await auth_headers(session, owner), connection


async def test_credentials_are_encrypted_and_never_in_resource_responses(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, _ = await _setup(session)

    created = await client.post(url, headers=headers, json=SMB)

    assert created.status_code == 201
    body = created.json()
    assert body["has_credentials"] is True
    assert body["priority"] == 2
    listing = await client.get(url, headers=headers)
    assert "hunter2-secret" not in created.text + listing.text
    assert "credentials" not in body
    assert "encrypted_credentials" not in body
    stored = await session.get(Connection, uuid.UUID(body["id"]))
    assert stored is not None
    assert stored.encrypted_credentials is not None
    assert b"hunter2-secret" not in stored.encrypted_credentials
    assert decrypt_json(stored.encrypted_credentials)["password"] == "hunter2-secret"


async def test_reading_credentials_is_permissioned_and_audited(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    url = f"{API}/organizations/{organization.id}/printers/{printer.id}/connections"
    connection_id = (
        await client.post(url, headers=await auth_headers(session, owner), json=SMB)
    ).json()["id"]
    user = await member_headers(session, organization, Role.USER)
    viewer = await member_headers(session, organization, Role.VIEWER)

    denied = await client.get(f"{url}/{connection_id}/credentials", headers=viewer)
    allowed = await client.get(f"{url}/{connection_id}/credentials", headers=user)

    assert denied.status_code == 403
    assert allowed.status_code == 200
    assert allowed.json() == {"username": "scanner", "password": "hunter2-secret", "extra": {}}
    assert allowed.headers["Cache-Control"] == "no-store"
    accesses = list(
        await session.scalars(
            select(AuditLog).where(AuditLog.action == "connection.credentials_accessed")
        )
    )
    assert len(accesses) == 1
    assert "hunter2-secret" not in str(accesses[0].detail)


async def test_connection_without_credentials_has_none_to_read(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, connection = await _setup(session)

    response = await client.get(f"{url}/{connection.id}/credentials", headers=headers)

    assert response.status_code == 404
    assert response.json()["code"] == "connection.no_credentials"


async def test_update_connection_and_remove_credentials(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, _ = await _setup(session)
    connection_id = (await client.post(url, headers=headers, json=SMB)).json()["id"]

    config_only = await client.patch(
        f"{url}/{connection_id}",
        headers=headers,
        json={"configuration": {"host": "nas.local", "options": {"share": "inbox"}}},
    )
    cleared = await client.patch(
        f"{url}/{connection_id}", headers=headers, json={"credentials": None}
    )

    assert config_only.json()["configuration"]["host"] == "nas.local"
    assert config_only.json()["has_credentials"] is True
    assert cleared.json()["has_credentials"] is False
    assert cleared.json()["configuration"]["host"] == "nas.local"
    actions = list(await session.scalars(select(AuditLog.action)))
    assert "connection.modified" in actions
    assert "connection.credentials_changed" in actions


async def test_configuration_rejects_unknown_fields(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, _ = await _setup(session)

    response = await client.post(
        url,
        headers=headers,
        json={"type": "ipp", "purposes": ["print"], "configuration": {"password": "oops"}},
    )

    assert response.status_code == 422


async def test_reorder_sets_the_fallback_order(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, first = await _setup(session)
    second = (
        await client.post(url, headers=headers, json={"type": "airprint", "purposes": ["print"]})
    ).json()["id"]
    third = (
        await client.post(url, headers=headers, json={"type": "wifi_direct", "purposes": ["print"]})
    ).json()["id"]

    response = await client.put(
        f"{url}/priority", headers=headers, json={"connection_ids": [third, str(first.id), second]}
    )

    assert response.status_code == 200
    assert [c["type"] for c in response.json()] == ["wifi_direct", "ipps", "airprint"]
    assert [c["priority"] for c in response.json()] == [1, 2, 3]
    listing = await client.get(url, headers=headers)
    assert [c["id"] for c in listing.json()] == [third, str(first.id), second]


async def test_reorder_must_list_every_connection_exactly_once(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    url, headers, first = await _setup(session)
    second = (
        await client.post(url, headers=headers, json={"type": "airprint", "purposes": ["print"]})
    ).json()["id"]

    missing = await client.put(
        f"{url}/priority", headers=headers, json={"connection_ids": [second]}
    )
    foreign = await client.put(
        f"{url}/priority",
        headers=headers,
        json={"connection_ids": [second, str(uuid.uuid4())]},
    )
    duplicate = await client.put(
        f"{url}/priority", headers=headers, json={"connection_ids": [second, second]}
    )

    assert missing.status_code == foreign.status_code == duplicate.status_code == 422
    assert missing.json()["code"] == "connection.priority_mismatch"
    await session.refresh(first)
    assert first.priority == 1


async def test_health_report_records_success_and_failure(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    connection = await create_connection(session, printer)
    reporter = await member_headers(session, organization, Role.USER)
    url = (
        f"{API}/organizations/{organization.id}/printers/{printer.id}"
        f"/connections/{connection.id}/health"
    )

    ok = await client.post(url, headers=reporter, json={"health": "connected", "latency_ms": 42})
    assert ok.status_code == 200
    assert ok.json()["health"] == "connected"
    assert ok.json()["last_latency_ms"] == 42
    assert ok.json()["last_success_at"] is not None
    assert ok.json()["last_failure_at"] is None

    failed = await client.post(
        url, headers=reporter, json={"health": "auth_required", "error": "401 from printer"}
    )
    assert failed.json()["health"] == "auth_required"
    assert failed.json()["last_failure_at"] is not None
    assert failed.json()["last_error"] == "401 from printer"

    await session.refresh(printer)
    assert printer.last_seen_at is not None


async def test_remove_connection(client: httpx.AsyncClient, session: AsyncSession) -> None:
    url, headers, connection = await _setup(session)

    response = await client.delete(f"{url}/{connection.id}", headers=headers)

    assert response.status_code == 204
    assert (await client.get(url, headers=headers)).json() == []
    assert (await client.get(f"{url}/{connection.id}", headers=headers)).status_code == 404


async def test_connection_of_another_printer_is_not_found(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer_a = await create_printer(session, organization, friendly_name="A")
    printer_b = await create_printer(session, organization, friendly_name="B")
    connection_b = await create_connection(session, printer_b)

    response = await client.get(
        f"{API}/organizations/{organization.id}/printers/{printer_a.id}"
        f"/connections/{connection_b.id}",
        headers=await auth_headers(session, owner),
    )

    assert response.status_code == 404
    assert response.json()["code"] == "connection.not_found"
