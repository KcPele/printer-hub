import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.modules.auth.models import UserSession
from app.modules.users.models import User
from tests.factories import PASSWORD, auth_headers, create_user, unique_email

API = "/api/v1"


async def _register(client: httpx.AsyncClient, email: str | None = None) -> httpx.Response:
    return await client.post(
        f"{API}/auth/register",
        json={"email": email or unique_email(), "password": PASSWORD, "name": "Ada Lovelace"},
    )


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def test_register_creates_account_and_signs_in(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    response = await _register(client, "Ada@Example.com")

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "ada@example.com"
    assert body["tokens"]["token_type"] == "bearer"
    assert "password" not in response.text.lower().replace("password_hash", "")

    me = await client.get(f"{API}/users/me", headers=_bearer(body["tokens"]["access_token"]))
    assert me.status_code == 200
    assert me.json()["name"] == "Ada Lovelace"

    stored = await session.scalar(select(User).where(User.email == "ada@example.com"))
    assert stored is not None
    assert stored.password_hash.startswith("$argon2id$")


async def test_register_rejects_duplicate_email_case_insensitively(
    client: httpx.AsyncClient,
) -> None:
    await _register(client, "dup@example.com")

    response = await _register(client, "DUP@example.com")

    assert response.status_code == 409
    assert response.json()["code"] == "auth.email_taken"


async def test_register_rejects_short_password(client: httpx.AsyncClient) -> None:
    response = await client.post(
        f"{API}/auth/register",
        json={"email": unique_email(), "password": "short", "name": "Ada"},
    )

    assert response.status_code == 422
    assert response.json()["errors"][0]["field"] == "body.password"


async def test_login_returns_tokens(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)

    response = await client.post(
        f"{API}/auth/login", json={"email": user.email.upper(), "password": PASSWORD}
    )

    assert response.status_code == 200
    assert response.json()["user"]["id"] == str(user.id)


async def test_login_failure_does_not_reveal_whether_account_exists(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)

    wrong_password = await client.post(
        f"{API}/auth/login", json={"email": user.email, "password": "not-the-password"}
    )
    unknown_email = await client.post(
        f"{API}/auth/login", json={"email": unique_email(), "password": PASSWORD}
    )

    assert wrong_password.status_code == unknown_email.status_code == 401
    assert (
        wrong_password.json()["code"] == unknown_email.json()["code"] == "auth.invalid_credentials"
    )
    assert wrong_password.json()["detail"] == unknown_email.json()["detail"]


async def test_login_rejects_inactive_account(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session, is_active=False)

    response = await client.post(
        f"{API}/auth/login", json={"email": user.email, "password": PASSWORD}
    )

    assert response.status_code == 401


async def test_login_is_rate_limited(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)
    attempts = get_settings().login_rate_limit_attempts
    payload = {"email": user.email, "password": "not-the-password"}

    for _ in range(attempts):
        assert (await client.post(f"{API}/auth/login", json=payload)).status_code == 401
    blocked = await client.post(f"{API}/auth/login", json=payload)

    assert blocked.status_code == 429
    assert blocked.json()["code"] == "rate_limited"
    assert int(blocked.headers["Retry-After"]) > 0


async def test_requests_without_a_token_are_rejected(client: httpx.AsyncClient) -> None:
    response = await client.get(f"{API}/users/me")

    assert response.status_code == 401
    assert response.json()["code"] == "auth.missing_token"
    assert response.headers["WWW-Authenticate"] == "Bearer"


async def test_refresh_rotates_the_refresh_token(client: httpx.AsyncClient) -> None:
    tokens = (await _register(client)).json()["tokens"]

    refreshed = await client.post(
        f"{API}/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert refreshed.status_code == 200
    new_tokens = refreshed.json()
    assert new_tokens["refresh_token"] != tokens["refresh_token"]
    assert new_tokens["session_id"] == tokens["session_id"]
    me = await client.get(f"{API}/users/me", headers=_bearer(new_tokens["access_token"]))
    assert me.status_code == 200


async def test_reusing_a_rotated_refresh_token_revokes_the_session(
    client: httpx.AsyncClient,
) -> None:
    tokens = (await _register(client)).json()["tokens"]
    new_tokens = (
        await client.post(f"{API}/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).json()

    replay = await client.post(
        f"{API}/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert replay.status_code == 401
    assert replay.json()["code"] == "auth.refresh_token_reused"
    # The legitimate holder is signed out too: the token may have been stolen.
    me = await client.get(f"{API}/users/me", headers=_bearer(new_tokens["access_token"]))
    assert me.status_code == 401
    again = await client.post(
        f"{API}/auth/refresh", json={"refresh_token": new_tokens["refresh_token"]}
    )
    assert again.status_code == 401


async def test_unknown_refresh_token_is_rejected(client: httpx.AsyncClient) -> None:
    response = await client.post(f"{API}/auth/refresh", json={"refresh_token": "nope"})

    assert response.status_code == 401
    assert response.json()["code"] == "auth.refresh_token_invalid"


async def test_logout_invalidates_the_access_token(client: httpx.AsyncClient) -> None:
    tokens = (await _register(client)).json()["tokens"]
    headers = _bearer(tokens["access_token"])

    assert (await client.post(f"{API}/auth/logout", headers=headers)).status_code == 204

    after = await client.get(f"{API}/users/me", headers=headers)
    assert after.status_code == 401
    assert after.json()["code"] == "auth.session_revoked"


async def test_sessions_can_be_listed_and_revoked(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    phone = await auth_headers(session, user)
    laptop = await auth_headers(session, user)

    listing = await client.get(f"{API}/auth/sessions", headers=phone)
    sessions = listing.json()
    assert len(sessions) == 2
    assert [item["is_current"] for item in sessions].count(True) == 1
    other = next(item for item in sessions if not item["is_current"])

    revoked = await client.delete(f"{API}/auth/sessions/{other['id']}", headers=phone)

    assert revoked.status_code == 204
    assert (await client.get(f"{API}/users/me", headers=laptop)).status_code == 401
    assert (await client.get(f"{API}/users/me", headers=phone)).status_code == 200


async def test_a_user_cannot_revoke_another_users_session(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    alice, bob = await create_user(session), await create_user(session)
    alice_headers = await auth_headers(session, alice)
    bob_headers = await auth_headers(session, bob)
    bob_session = await session.scalar(select(UserSession).where(UserSession.user_id == bob.id))
    assert bob_session is not None

    await client.delete(f"{API}/auth/sessions/{bob_session.id}", headers=alice_headers)

    assert (await client.get(f"{API}/users/me", headers=bob_headers)).status_code == 200


async def test_change_password_signs_out_other_sessions(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    current = await auth_headers(session, user)
    other = await auth_headers(session, user)

    response = await client.post(
        f"{API}/auth/password/change",
        headers=current,
        json={"current_password": PASSWORD, "new_password": "a-brand-new-password"},
    )

    assert response.status_code == 204
    assert (await client.get(f"{API}/users/me", headers=current)).status_code == 200
    assert (await client.get(f"{API}/users/me", headers=other)).status_code == 401
    old = await client.post(f"{API}/auth/login", json={"email": user.email, "password": PASSWORD})
    new = await client.post(
        f"{API}/auth/login", json={"email": user.email, "password": "a-brand-new-password"}
    )
    assert old.status_code == 401
    assert new.status_code == 200


async def test_change_password_requires_the_current_password(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)

    response = await client.post(
        f"{API}/auth/password/change",
        headers=await auth_headers(session, user),
        json={"current_password": "wrong-password", "new_password": "a-brand-new-password"},
    )

    assert response.status_code == 422
    assert response.json()["code"] == "auth.current_password_incorrect"
