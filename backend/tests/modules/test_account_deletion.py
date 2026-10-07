import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.storage.memory import MemoryStorage
from app.core.permissions import Role
from app.core.tasks import MemoryTaskQueue
from app.modules.audit.models import AuditLog
from app.modules.documents.models import Document
from app.modules.jobs.models import Job
from app.modules.organizations.models import Membership, Organization
from app.modules.users.models import User
from tests.factories import PASSWORD, add_member, auth_headers, create_user
from tests.modules.test_jobs import create_job, make_scene

API = "/api/v1"


async def _delete(
    client: httpx.AsyncClient, headers: dict[str, str], password: str = PASSWORD
) -> httpx.Response:
    return await client.post(f"{API}/account/delete", headers=headers, json={"password": password})


async def _cloud_document(client: httpx.AsyncClient, url: str, headers: dict[str, str]) -> str:
    response = await client.post(
        f"{url}/documents",
        headers=headers,
        json={
            "file_name": "Private.pdf",
            "mime_type": "application/pdf",
            "size_bytes": 10,
            "storage_mode": "cloud",
        },
    )
    assert response.status_code == 201
    storage_key: str = (
        f"organizations/{response.json()['organization_id']}/documents/{response.json()['id']}"
    )
    return storage_key


async def test_wrong_password_deletes_nothing(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)

    response = await _delete(client, headers, password="not-my-password")

    assert response.status_code == 422
    assert response.json()["code"] == "account.password_incorrect"
    assert (await client.get(f"{API}/users/me", headers=headers)).status_code == 200


async def test_deleting_removes_the_account_and_its_solo_organization(
    client: httpx.AsyncClient,
    session: AsyncSession,
    task_queue: MemoryTaskQueue,
    storage: MemoryStorage,
) -> None:
    scene = await make_scene(session)
    email = scene.owner.email
    await create_job(client, scene)
    org_url = f"{API}/organizations/{scene.organization.id}"
    storage_key = await _cloud_document(client, org_url, scene.headers)
    storage.put(storage_key, 10)

    response = await _delete(client, scene.headers)

    assert response.status_code == 204
    assert (await client.get(f"{API}/users/me", headers=scene.headers)).status_code == 401
    login = await client.post(f"{API}/auth/login", json={"email": email, "password": PASSWORD})
    assert login.status_code == 401
    for model in (User, Organization, Membership, Job, Document):
        assert await session.scalar(select(func.count()).select_from(model)) == 0
    # The stored file is queued for removal from the bucket.
    [cleanup] = task_queue.named("delete_stored_objects")
    assert cleanup.kwargs == {"keys": [storage_key]}
    # The address is free to register again.
    again = await client.post(
        f"{API}/auth/register", json={"email": email, "password": PASSWORD, "name": "Back"}
    )
    assert again.status_code == 201


async def test_last_owner_of_a_shared_organization_must_hand_over_first(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session, name="Acme Print")
    colleague = await add_member(session, scene.organization, Role.ADMIN)

    blocked = await _delete(client, scene.headers)

    assert blocked.status_code == 409
    assert blocked.json()["code"] == "account.sole_owner"
    assert "Acme Print" in blocked.json()["detail"]
    assert (await client.get(f"{API}/users/me", headers=scene.headers)).status_code == 200

    await client.patch(
        f"{API}/organizations/{scene.organization.id}/members/{colleague.id}",
        headers=scene.headers,
        json={"role": "owner"},
    )
    assert (await _delete(client, scene.headers)).status_code == 204
    colleague_headers = await auth_headers(session, colleague)
    remaining = await client.get(
        f"{API}/organizations/{scene.organization.id}", headers=colleague_headers
    )
    assert remaining.status_code == 200


async def test_member_leaving_a_shared_organization_takes_only_what_is_theirs(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)
    member = await add_member(session, scene.organization, Role.USER)
    member_headers = await auth_headers(session, member)
    org_url = f"{API}/organizations/{scene.organization.id}"
    job = await create_job(client, scene, headers=member_headers, title="Member.pdf")
    member_key = await _cloud_document(client, org_url, member_headers)
    owner_key = await _cloud_document(client, org_url, scene.headers)

    response = await _delete(client, member_headers)

    assert response.status_code == 204
    # The organization and the owner's documents are untouched.
    documents = await client.get(f"{org_url}/documents", headers=scene.headers)
    assert len(documents.json()["items"]) == 1
    [cleanup] = task_queue.named("delete_stored_objects")
    assert cleanup.kwargs == {"keys": [member_key]}
    assert owner_key not in cleanup.kwargs["keys"]
    # The job stays as the organization's record, without the person.
    kept = (await client.get(f"{org_url}/jobs/{job['id']}", headers=scene.headers)).json()
    assert kept["title"] == "Member.pdf"
    assert kept["user_id"] is None
    members = await client.get(f"{org_url}/members", headers=scene.headers)
    assert len(members.json()) == 1
    audit = await client.get(
        f"{org_url}/audit-logs", headers=scene.headers, params={"action": "member.account_deleted"}
    )
    assert len(audit.json()["items"]) == 1


async def test_pending_invitations_to_the_address_are_removed(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    leaver = await create_user(session)
    invitations_url = f"{API}/organizations/{scene.organization.id}/invitations"
    await client.post(invitations_url, headers=scene.headers, json={"email": leaver.email})

    await _delete(client, await auth_headers(session, leaver))

    assert (await client.get(invitations_url, headers=scene.headers)).json() == []


async def test_deleting_an_organization_queues_its_files_for_removal(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)
    org_url = f"{API}/organizations/{scene.organization.id}"
    first = await _cloud_document(client, org_url, scene.headers)
    second = await _cloud_document(client, org_url, scene.headers)
    await client.post(
        f"{org_url}/documents",
        headers=scene.headers,
        json={"file_name": "Local.pdf", "mime_type": "application/pdf", "size_bytes": 5},
    )

    response = await client.delete(org_url, headers=scene.headers)

    assert response.status_code == 204
    [cleanup] = task_queue.named("delete_stored_objects")
    assert sorted(cleanup.kwargs["keys"]) == sorted([first, second])
    assert await session.scalar(select(func.count()).select_from(AuditLog)) is not None
