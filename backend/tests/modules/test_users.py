import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories import auth_headers, create_user

API = "/api/v1"


async def test_update_profile_and_preferences(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session, name="Before")
    headers = await auth_headers(session, user)

    response = await client.patch(
        f"{API}/users/me",
        headers=headers,
        json={
            "name": "After",
            "preferences": {"theme": "dark", "muted_notification_types": ["job.completed"]},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "After"
    assert body["preferences"]["theme"] == "dark"
    assert body["preferences"]["muted_notification_types"] == ["job.completed"]
    assert (await client.get(f"{API}/users/me", headers=headers)).json() == body


async def test_new_user_has_default_preferences(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)

    response = await client.get(f"{API}/users/me", headers=await auth_headers(session, user))

    assert response.json()["preferences"] == {
        "theme": "system",
        "default_organization_id": None,
        "default_printer_id": None,
        "muted_notification_types": [],
    }


async def test_invalid_preference_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)

    response = await client.patch(
        f"{API}/users/me",
        headers=await auth_headers(session, user),
        json={"preferences": {"theme": "neon"}},
    )

    assert response.status_code == 422
