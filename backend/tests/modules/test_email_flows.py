import re
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.tasks import MemoryTaskQueue
from app.modules.audit.models import AuditLog
from app.modules.auth.email_codes import EmailCode
from tests.factories import PASSWORD, auth_headers, create_organization, create_user, unique_email

API = "/api/v1"
NEW_PASSWORD = "a-brand-new-password"


def last_email(task_queue: MemoryTaskQueue) -> dict[str, str]:
    emails = task_queue.named("send_email")
    assert emails, "no email was queued"
    return emails[-1].kwargs


def code_from(task_queue: MemoryTaskQueue) -> str:
    match = re.search(r"\b(\d{6})\b", last_email(task_queue)["text"])
    assert match is not None
    return match.group(1)


def wrong(code: str) -> str:
    return f"{(int(code) + 1) % 1_000_000:06d}"


async def _register(client: httpx.AsyncClient, email: str) -> dict[str, str]:
    response = await client.post(
        f"{API}/auth/register", json={"email": email, "password": PASSWORD, "name": "Ada"}
    )
    assert response.status_code == 201
    assert response.json()["user"]["email_verified_at"] is None
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


# --- Email verification ------------------------------------------------------


async def test_registration_emails_a_code_that_verifies_the_address(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    email = unique_email()
    headers = await _register(client, email)

    message = last_email(task_queue)
    assert message["to"] == email
    assert message["subject"] == "Verify your PrinterHub email address"
    code = code_from(task_queue)

    verified = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": code})

    assert verified.status_code == 200
    assert verified.json()["email_verified_at"] is not None
    # The code is stored hashed, never as sent.
    stored = await session.scalar(select(EmailCode))
    assert stored is not None
    assert code not in stored.code_hash
    assert stored.consumed_at is not None
    # Verifying again is harmless.
    again = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": code})
    assert again.status_code == 200


async def test_wrong_codes_are_refused_and_exhaust_the_code(
    client: httpx.AsyncClient, task_queue: MemoryTaskQueue
) -> None:
    headers = await _register(client, unique_email())
    code = code_from(task_queue)
    attempts = get_settings().email_code_max_attempts

    for _ in range(attempts):
        response = await client.post(
            f"{API}/auth/email/verify", headers=headers, json={"code": wrong(code)}
        )
        assert response.status_code == 422
        assert response.json()["code"] == "auth.code_invalid"

    # Even the right code is dead after too many wrong guesses.
    exhausted = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": code})
    assert exhausted.status_code == 422


async def test_resend_replaces_the_previous_code(
    client: httpx.AsyncClient, task_queue: MemoryTaskQueue
) -> None:
    headers = await _register(client, unique_email())
    first = code_from(task_queue)

    resent = await client.post(f"{API}/auth/email/resend", headers=headers)
    second = code_from(task_queue)

    assert resent.status_code == 204
    assert len(task_queue.named("send_email")) == 2
    old = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": first})
    new = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": second})
    # The two codes could collide by chance one time in a million.
    assert first == second or old.status_code == 422
    assert new.status_code == 200


async def test_expired_code_is_refused(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    headers = await _register(client, unique_email())
    code = code_from(task_queue)
    await session.execute(
        update(EmailCode).values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )

    response = await client.post(f"{API}/auth/email/verify", headers=headers, json={"code": code})

    assert response.status_code == 422


async def test_resend_is_rate_limited_and_skipped_once_verified(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    verified = await auth_headers(session, await create_user(session))
    assert (await client.post(f"{API}/auth/email/resend", headers=verified)).status_code == 204
    assert task_queue.named("send_email") == []

    headers = await _register(client, unique_email())
    limit = get_settings().email_code_rate_limit_attempts
    statuses = [
        (await client.post(f"{API}/auth/email/resend", headers=headers)).status_code
        for _ in range(limit + 1)
    ]
    assert statuses == [204] * limit + [429]


async def test_malformed_code_is_rejected_before_any_lookup(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    headers = await auth_headers(session, await create_user(session, email_verified_at=None))

    for bad in ("12345", "1234567", "12a456", ""):
        response = await client.post(
            f"{API}/auth/email/verify", headers=headers, json={"code": bad}
        )
        assert response.status_code == 422
        assert response.json()["code"] == "request.validation_failed"


# --- Invitations need a verified address -------------------------------------


async def test_unverified_account_cannot_claim_invitations_by_email_alone(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    # Someone registers with the invitee's address but cannot read their mail.
    squatter = await create_user(session, email="invitee@example.com", email_verified_at=None)
    squatter_headers = await auth_headers(session, squatter)
    task_queue.enqueued.clear()

    invitation = (
        await client.post(
            f"{API}/organizations/{organization.id}/invitations",
            headers=await auth_headers(session, owner),
            json={"email": "invitee@example.com", "role": "admin"},
        )
    ).json()

    listing = await client.get(f"{API}/invitations", headers=squatter_headers)
    accepted = await client.post(
        f"{API}/invitations/{invitation['id']}/accept", headers=squatter_headers
    )

    assert listing.status_code == 403
    assert listing.json()["code"] == "auth.email_not_verified"
    assert accepted.status_code == 403
    # And they are told nothing about the organization.
    assert task_queue.named("push_notification") == []
    notifications = await client.get(f"{API}/notifications", headers=squatter_headers)
    assert notifications.json()["items"] == []


# --- Password reset ----------------------------------------------------------


async def test_password_reset_flow(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    user = await create_user(session, name="Ada", email_verified_at=None)
    old_session = await auth_headers(session, user)

    requested = await client.post(f"{API}/auth/password/forgot", json={"email": user.email.upper()})
    assert requested.status_code == 204
    message = last_email(task_queue)
    assert message["to"] == user.email
    assert message["subject"] == "Your PrinterHub password reset code"
    assert "Hi Ada" in message["text"]

    reset = await client.post(
        f"{API}/auth/password/reset",
        json={"email": user.email, "code": code_from(task_queue), "new_password": NEW_PASSWORD},
    )

    assert reset.status_code == 204
    old = await client.post(f"{API}/auth/login", json={"email": user.email, "password": PASSWORD})
    new = await client.post(
        f"{API}/auth/login", json={"email": user.email, "password": NEW_PASSWORD}
    )
    assert old.status_code == 401
    assert new.status_code == 200
    # Every existing session is signed out, and the inbox is now proven.
    assert (await client.get(f"{API}/users/me", headers=old_session)).status_code == 401
    assert new.json()["user"]["email_verified_at"] is not None
    actions = set(await session.scalars(select(AuditLog.action)))
    assert "user.password_reset" in actions


async def test_reset_code_works_once(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    user = await create_user(session)
    await client.post(f"{API}/auth/password/forgot", json={"email": user.email})
    body = {"email": user.email, "code": code_from(task_queue), "new_password": NEW_PASSWORD}
    await client.post(f"{API}/auth/password/reset", json=body)

    again = await client.post(
        f"{API}/auth/password/reset", json={**body, "new_password": "yet-another-password"}
    )

    assert again.status_code == 422
    assert again.json()["code"] == "auth.code_invalid"


async def test_forgot_password_does_not_reveal_whether_an_account_exists(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    inactive = await create_user(session, is_active=False)

    unknown = await client.post(f"{API}/auth/password/forgot", json={"email": unique_email()})
    disabled = await client.post(f"{API}/auth/password/forgot", json={"email": inactive.email})

    assert unknown.status_code == disabled.status_code == 204
    assert unknown.content == disabled.content == b""
    assert task_queue.named("send_email") == []
    # A reset attempt for an unknown address fails the same way as a wrong code.
    response = await client.post(
        f"{API}/auth/password/reset",
        json={"email": unique_email(), "code": "123456", "new_password": NEW_PASSWORD},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "auth.code_invalid"


async def test_guessing_a_reset_code_locks_it(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    user = await create_user(session)
    await client.post(f"{API}/auth/password/forgot", json={"email": user.email})
    code = code_from(task_queue)
    body = {"email": user.email, "new_password": NEW_PASSWORD}

    for _ in range(get_settings().email_code_max_attempts):
        guess = await client.post(f"{API}/auth/password/reset", json={**body, "code": wrong(code)})
        assert guess.status_code == 422
    correct_but_late = await client.post(f"{API}/auth/password/reset", json={**body, "code": code})

    assert correct_but_late.status_code in (422, 429)
    login = await client.post(f"{API}/auth/login", json={"email": user.email, "password": PASSWORD})
    assert login.status_code == 200  # the password never changed


async def test_reset_requests_are_rate_limited(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    limit = get_settings().email_code_rate_limit_attempts

    statuses = [
        (await client.post(f"{API}/auth/password/forgot", json={"email": user.email})).status_code
        for _ in range(limit + 1)
    ]

    assert statuses == [204] * limit + [429]


async def test_reset_rejects_a_weak_new_password(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    user = await create_user(session)
    await client.post(f"{API}/auth/password/forgot", json={"email": user.email})

    response = await client.post(
        f"{API}/auth/password/reset",
        json={"email": user.email, "code": code_from(task_queue), "new_password": "short"},
    )

    assert response.status_code == 422
    assert response.json()["errors"][0]["field"] == "body.new_password"
