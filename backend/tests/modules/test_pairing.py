from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.pairing.models import PairingToken
from tests.factories import (
    auth_headers,
    create_connection,
    create_organization,
    create_printer,
    create_user,
    member_headers,
)

API = "/api/v1"


async def test_pairing_token_resolves_to_the_printer_once(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    await create_connection(session, printer, encrypted_credentials=b"ciphertext")
    member = await member_headers(session, organization, Role.USER)

    created = await client.post(
        f"{API}/organizations/{organization.id}/printers/{printer.id}/pairing-tokens",
        headers=await auth_headers(session, owner),
    )
    assert created.status_code == 201
    payload = created.json()["payload"]
    assert payload["printer_id"] == str(printer.id)
    assert created.json()["deep_link"] == f"printerhub://pair?token={payload['token']}"
    assert set(payload) == {"v", "token", "printer_id", "organization_id"}

    redeemed = await client.post(
        f"{API}/pairing/redeem", headers=member, json={"token": payload["token"]}
    )

    assert redeemed.status_code == 200
    body = redeemed.json()["printer"]
    assert body["id"] == str(printer.id)
    assert body["connections"][0]["has_credentials"] is True
    assert "ciphertext" not in redeemed.text

    again = await client.post(
        f"{API}/pairing/redeem", headers=member, json={"token": payload["token"]}
    )
    assert again.status_code == 422
    assert again.json()["code"] == "pairing.token_invalid"


async def test_expired_pairing_token_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    headers = await auth_headers(session, owner)
    token = (
        await client.post(
            f"{API}/organizations/{organization.id}/printers/{printer.id}/pairing-tokens",
            headers=headers,
        )
    ).json()["payload"]["token"]
    await session.execute(
        update(PairingToken).values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )

    response = await client.post(f"{API}/pairing/redeem", headers=headers, json={"token": token})

    assert response.status_code == 422


async def test_pairing_does_not_grant_access_to_outsiders(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    printer = await create_printer(session, organization)
    token = (
        await client.post(
            f"{API}/organizations/{organization.id}/printers/{printer.id}/pairing-tokens",
            headers=await auth_headers(session, owner),
        )
    ).json()["payload"]["token"]
    outsider = await auth_headers(session, await create_user(session))

    response = await client.post(f"{API}/pairing/redeem", headers=outsider, json={"token": token})

    assert response.status_code == 403
    assert response.json()["code"] == "pairing.not_a_member"
    # The refusal does not consume the token.
    member = await member_headers(session, organization, Role.USER)
    assert (
        await client.post(f"{API}/pairing/redeem", headers=member, json={"token": token})
    ).status_code == 200


async def test_only_managers_create_pairing_tokens(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    printer = await create_printer(session, organization)

    response = await client.post(
        f"{API}/organizations/{organization.id}/printers/{printer.id}/pairing-tokens",
        headers=await member_headers(session, organization, Role.USER),
    )

    assert response.status_code == 403
