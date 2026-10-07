import uuid

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.realtime.pusher import sign_channel_auth
from app.core.config import get_settings
from app.core.permissions import Role
from tests.factories import (
    add_member,
    auth_headers,
    create_organization,
    create_user,
    member_headers,
)

API = "/api/v1"
SOCKET_ID = "1234.5678"


async def _authorize(
    client: httpx.AsyncClient, headers: dict[str, str], channel: str, socket_id: str = SOCKET_ID
) -> httpx.Response:
    return await client.post(
        f"{API}/realtime/auth",
        headers=headers,
        data={"socket_id": socket_id, "channel_name": channel},
    )


async def test_config_describes_the_connection(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)

    response = await client.get(f"{API}/realtime/config", headers=await auth_headers(session, user))

    assert response.status_code == 200
    assert response.json() == {
        "provider": "pusher",
        "app_key": "printerhub-key",
        "host": "localhost",
        "port": 6001,
        "use_tls": False,
        "auth_endpoint": "/api/v1/realtime/auth",
        "channels": {
            "user": f"private-user-{user.id}",
            "organization": "private-org-{organization_id}",
            "organization_jobs": "private-org-{organization_id}-jobs",
        },
    }
    assert "secret" not in response.text


async def test_user_may_subscribe_to_own_channel(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    channel = f"private-user-{user.id}"

    response = await _authorize(client, await auth_headers(session, user), channel)

    settings = get_settings()
    assert response.status_code == 200
    assert response.json()["auth"] == sign_channel_auth(
        settings.soketi_app_key,
        settings.soketi_app_secret.get_secret_value(),
        SOCKET_ID,
        channel,
    )


async def test_user_may_not_subscribe_to_another_users_channel(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    alice, bob = await create_user(session), await create_user(session)

    response = await _authorize(
        client, await auth_headers(session, alice), f"private-user-{bob.id}"
    )

    assert response.status_code == 403
    assert response.json()["code"] == "realtime.channel_forbidden"


async def test_organization_channels_follow_permissions(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    user = await member_headers(session, organization, Role.USER)
    operator = await member_headers(session, organization, Role.OPERATOR)
    outsider = await auth_headers(session, await create_user(session))
    org_channel = f"private-org-{organization.id}"
    jobs_channel = f"private-org-{organization.id}-jobs"

    assert (await _authorize(client, user, org_channel)).status_code == 200
    assert (await _authorize(client, user, jobs_channel)).status_code == 403
    assert (await _authorize(client, operator, jobs_channel)).status_code == 200
    assert (await _authorize(client, outsider, org_channel)).status_code == 403


async def test_removed_member_loses_channel_access(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    member = await add_member(session, organization, Role.USER)
    member_auth = await auth_headers(session, member)
    await client.delete(
        f"{API}/organizations/{organization.id}/members/{member.id}",
        headers=await auth_headers(session, owner),
    )

    response = await _authorize(client, member_auth, f"private-org-{organization.id}")

    assert response.status_code == 403


async def test_unknown_channels_and_bad_socket_ids_are_refused(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)

    assert (await _authorize(client, headers, "presence-everyone")).status_code == 403
    assert (await _authorize(client, headers, f"private-org-{uuid.uuid4()}x")).status_code == 403
    assert (
        await _authorize(client, headers, f"private-user-{user.id}", socket_id="1234.5678:evil")
    ).status_code == 403


async def test_authorization_requires_sign_in(client: httpx.AsyncClient) -> None:
    response = await client.post(
        f"{API}/realtime/auth", data={"socket_id": SOCKET_ID, "channel_name": "private-user-x"}
    )

    assert response.status_code == 401
