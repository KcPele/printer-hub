import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.tasks import MemoryTaskQueue
from tests.factories import auth_headers, create_organization, create_user

API = "/api/v1"


async def test_existing_user_is_notified_and_accepts_in_app(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    owner = await create_user(session, name="Olive Owner")
    organization = await create_organization(session, owner, name="Acme Print")
    invitee = await create_user(session)
    invitee_headers = await auth_headers(session, invitee)

    created = await client.post(
        f"{API}/organizations/{organization.id}/invitations",
        headers=await auth_headers(session, owner),
        json={"email": invitee.email, "role": "operator"},
    )

    notifications = (await client.get(f"{API}/notifications", headers=invitee_headers)).json()
    [notification] = notifications["items"]
    assert notification["type"] == "organization.invitation"
    assert notification["body"] == "Olive Owner invited you to join Acme Print."
    assert notification["data"]["invitation_id"] == created.json()["id"]
    # The secret token is never placed in a notification.
    assert created.json()["token"] not in str(notification)
    assert len(task_queue.named("push_notification")) == 1

    [pending] = (await client.get(f"{API}/invitations", headers=invitee_headers)).json()
    assert pending["organization_name"] == "Acme Print"
    assert pending["role"] == "operator"

    accepted = await client.post(
        f"{API}/invitations/{pending['id']}/accept", headers=invitee_headers
    )

    assert accepted.status_code == 200
    assert accepted.json()["role"] == "operator"
    assert (await client.get(f"{API}/invitations", headers=invitee_headers)).json() == []


async def test_someone_elses_invitation_cannot_be_accepted_by_id(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    invitee = await create_user(session)
    invitation_id = (
        await client.post(
            f"{API}/organizations/{organization.id}/invitations",
            headers=await auth_headers(session, owner),
            json={"email": invitee.email},
        )
    ).json()["id"]
    stranger = await auth_headers(session, await create_user(session))

    response = await client.post(f"{API}/invitations/{invitation_id}/accept", headers=stranger)

    assert response.status_code == 422
    assert response.json()["code"] == "invitation.invalid"
    assert (await client.get(f"{API}/invitations", headers=stranger)).json() == []


async def test_inviting_an_unregistered_email_sends_no_notification(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)

    response = await client.post(
        f"{API}/organizations/{organization.id}/invitations",
        headers=await auth_headers(session, owner),
        json={"email": "not-yet-registered@example.com"},
    )

    assert response.status_code == 201
    assert task_queue.enqueued == []
