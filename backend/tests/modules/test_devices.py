import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import UserSession
from app.modules.devices.models import Device
from tests.factories import auth_headers, create_user

API = "/api/v1"

IPHONE = {
    "installation_id": "install-iphone-0001",
    "platform": "ios",
    "name": "Ada's iPhone",
    "model": "iPhone 17",
    "os_version": "26.0",
    "app_version": "1.0.0",
    "push_provider": "fcm",
    "push_token": "fcm-token-abc",
}


async def test_register_device_binds_it_to_the_session(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)

    response = await client.post(f"{API}/devices", headers=headers, json=IPHONE)

    assert response.status_code == 200
    body = response.json()
    assert body["push_enabled"] is True
    assert "push_token" not in body
    bound = await session.scalar(select(UserSession).where(UserSession.user_id == user.id))
    assert bound is not None
    assert str(bound.device_id) == body["id"]


async def test_registering_the_same_installation_updates_it(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)
    first = await client.post(f"{API}/devices", headers=headers, json=IPHONE)

    second = await client.post(
        f"{API}/devices", headers=headers, json={**IPHONE, "app_version": "1.1.0"}
    )

    assert second.json()["id"] == first.json()["id"]
    assert second.json()["app_version"] == "1.1.0"
    listing = await client.get(f"{API}/devices", headers=headers)
    assert len(listing.json()) == 1


async def test_registering_again_without_a_name_keeps_the_one_its_owner_gave(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)
    unnamed = {key: value for key, value in IPHONE.items() if key != "name"}
    first = await client.post(f"{API}/devices", headers=headers, json=unnamed)
    assert first.json()["name"] is None

    renamed = await client.patch(
        f"{API}/devices/{first.json()['id']}", headers=headers, json={"name": "Work phone"}
    )
    again = await client.post(f"{API}/devices", headers=headers, json=unnamed)

    assert renamed.json()["name"] == "Work phone"
    # Naming it changed nothing else: push is still on.
    assert renamed.json()["push_enabled"] is True
    assert again.json()["name"] == "Work phone"


async def test_push_fields_must_be_sent_together(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    payload = {key: value for key, value in IPHONE.items() if key != "push_provider"}

    response = await client.post(
        f"{API}/devices", headers=await auth_headers(session, user), json=payload
    )

    assert response.status_code == 422


async def test_push_token_moves_to_the_latest_account_on_a_shared_phone(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    alice, bob = await create_user(session), await create_user(session)
    await client.post(f"{API}/devices", headers=await auth_headers(session, alice), json=IPHONE)

    await client.post(f"{API}/devices", headers=await auth_headers(session, bob), json=IPHONE)

    devices = {
        device.user_id: device
        for device in await session.scalars(
            select(Device).execution_options(populate_existing=True)
        )
    }
    assert devices[alice.id].push_token is None
    assert devices[bob.id].push_token == "fcm-token-abc"


async def test_update_can_clear_push(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)
    device_id = (await client.post(f"{API}/devices", headers=headers, json=IPHONE)).json()["id"]

    response = await client.patch(
        f"{API}/devices/{device_id}",
        headers=headers,
        json={"push_provider": None, "push_token": None},
    )

    assert response.status_code == 200
    assert response.json()["push_enabled"] is False
    assert response.json()["name"] == "Ada's iPhone"


async def test_devices_are_private_to_their_owner(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    alice, bob = await create_user(session), await create_user(session)
    alice_headers = await auth_headers(session, alice)
    bob_headers = await auth_headers(session, bob)
    device_id = (await client.post(f"{API}/devices", headers=alice_headers, json=IPHONE)).json()[
        "id"
    ]

    assert (await client.get(f"{API}/devices", headers=bob_headers)).json() == []
    patched = await client.patch(
        f"{API}/devices/{device_id}", headers=bob_headers, json={"name": "Mine now"}
    )
    deleted = await client.delete(f"{API}/devices/{device_id}", headers=bob_headers)

    assert patched.status_code == 404
    assert deleted.status_code == 404
    assert patched.json()["code"] == "device.not_found"


async def test_delete_device(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)
    device_id = (await client.post(f"{API}/devices", headers=headers, json=IPHONE)).json()["id"]

    response = await client.delete(f"{API}/devices/{device_id}", headers=headers)

    assert response.status_code == 204
    assert (await client.get(f"{API}/devices", headers=headers)).json() == []
    # The session survives; only its device link is cleared.
    assert (await client.get(f"{API}/users/me", headers=headers)).status_code == 200
