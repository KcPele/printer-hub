import uuid
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.organizations.models import Invitation, Membership
from tests.factories import (
    add_member,
    auth_headers,
    create_organization,
    create_user,
    member_headers,
)

API = "/api/v1"


async def test_creator_becomes_owner(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)

    response = await client.post(f"{API}/organizations", headers=headers, json={"name": "Acme"})

    assert response.status_code == 201
    body = response.json()
    assert body["role"] == "owner"
    assert body["slug"].startswith("acme-")
    assert body["settings"]["document_storage_mode"] == "cloud_allowed"
    listing = await client.get(f"{API}/organizations", headers=headers)
    assert [item["id"] for item in listing.json()] == [body["id"]]


async def test_non_member_sees_not_found(client: httpx.AsyncClient, session: AsyncSession) -> None:
    organization = await create_organization(session, await create_user(session))
    outsider = await auth_headers(session, await create_user(session))

    existing = await client.get(f"{API}/organizations/{organization.id}", headers=outsider)
    missing = await client.get(f"{API}/organizations/{uuid.uuid4()}", headers=outsider)

    assert existing.status_code == missing.status_code == 404
    assert existing.json()["code"] == missing.json()["code"] == "organization.not_found"


async def test_admin_can_update_settings_but_viewer_cannot(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    admin = await member_headers(session, organization, Role.ADMIN)
    viewer = await member_headers(session, organization, Role.VIEWER)
    payload = {
        "name": "Acme Renamed",
        "settings": {
            "max_copies_per_job": 25,
            "color_printing_roles": ["owner", "admin"],
            "document_storage_mode": "local_only",
            "document_retention_days": 7,
        },
    }

    denied = await client.patch(
        f"{API}/organizations/{organization.id}", headers=viewer, json=payload
    )
    allowed = await client.patch(
        f"{API}/organizations/{organization.id}", headers=admin, json=payload
    )

    assert denied.status_code == 403
    assert denied.json()["code"] == "permission.denied"
    assert allowed.status_code == 200
    assert allowed.json()["name"] == "Acme Renamed"
    assert allowed.json()["settings"] == payload["settings"]


async def test_invalid_settings_are_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)

    response = await client.patch(
        f"{API}/organizations/{organization.id}",
        headers=await auth_headers(session, owner),
        json={"settings": {"max_copies_per_job": 0}},
    )

    assert response.status_code == 422


async def test_only_owner_can_delete_organization(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    admin = await member_headers(session, organization, Role.ADMIN)
    owner_headers = await auth_headers(session, owner)

    denied = await client.delete(f"{API}/organizations/{organization.id}", headers=admin)
    deleted = await client.delete(f"{API}/organizations/{organization.id}", headers=owner_headers)

    assert denied.status_code == 403
    assert deleted.status_code == 204
    assert (await client.get(f"{API}/organizations", headers=owner_headers)).json() == []


async def test_members_are_listed_with_roles(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session, name="Olive Owner")
    organization = await create_organization(session, owner)
    await add_member(session, organization, Role.OPERATOR, name="Oscar Operator")

    response = await client.get(
        f"{API}/organizations/{organization.id}/members",
        headers=await auth_headers(session, owner),
    )

    assert response.status_code == 200
    assert [(m["user"]["name"], m["role"]) for m in response.json()] == [
        ("Olive Owner", "owner"),
        ("Oscar Operator", "operator"),
    ]


async def test_admin_can_change_roles_below_owner(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    admin = await member_headers(session, organization, Role.ADMIN)
    member = await add_member(session, organization, Role.USER)
    url = f"{API}/organizations/{organization.id}/members"

    promoted = await client.patch(f"{url}/{member.id}", headers=admin, json={"role": "operator"})
    grant_owner = await client.patch(f"{url}/{member.id}", headers=admin, json={"role": "owner"})
    demote_owner = await client.patch(f"{url}/{owner.id}", headers=admin, json={"role": "user"})

    assert promoted.status_code == 200
    assert promoted.json()["role"] == "operator"
    assert grant_owner.status_code == 403
    assert grant_owner.json()["code"] == "permission.owner_required"
    assert demote_owner.status_code == 403


async def test_regular_user_cannot_manage_members(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    user = await member_headers(session, organization, Role.USER)
    target = await add_member(session, organization, Role.USER)
    url = f"{API}/organizations/{organization.id}/members/{target.id}"

    changed = await client.patch(url, headers=user, json={"role": "admin"})
    removed = await client.delete(url, headers=user)

    assert changed.status_code == 403
    assert removed.status_code == 403


async def test_last_owner_cannot_be_demoted_or_leave(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    headers = await auth_headers(session, owner)
    url = f"{API}/organizations/{organization.id}/members/{owner.id}"

    demoted = await client.patch(url, headers=headers, json={"role": "admin"})
    left = await client.delete(url, headers=headers)

    assert demoted.status_code == 409
    assert left.status_code == 409
    assert left.json()["code"] == "member.last_owner"


async def test_owner_can_hand_over_ownership_and_leave(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    successor = await add_member(session, organization, Role.ADMIN)
    headers = await auth_headers(session, owner)
    url = f"{API}/organizations/{organization.id}/members"

    promoted = await client.patch(f"{url}/{successor.id}", headers=headers, json={"role": "owner"})
    left = await client.delete(f"{url}/{owner.id}", headers=headers)

    assert promoted.status_code == 200
    assert left.status_code == 204
    assert (
        await client.get(f"{API}/organizations/{organization.id}", headers=headers)
    ).status_code == 404


async def test_any_member_can_leave(client: httpx.AsyncClient, session: AsyncSession) -> None:
    organization = await create_organization(session, await create_user(session))
    viewer = await add_member(session, organization, Role.VIEWER)

    response = await client.delete(
        f"{API}/organizations/{organization.id}/members/{viewer.id}",
        headers=await auth_headers(session, viewer),
    )

    assert response.status_code == 204


async def test_invitation_flow(client: httpx.AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    owner_headers = await auth_headers(session, owner)
    invitee = await create_user(session, email="invitee@example.com")
    invitee_headers = await auth_headers(session, invitee)

    created = await client.post(
        f"{API}/organizations/{organization.id}/invitations",
        headers=owner_headers,
        json={"email": "Invitee@Example.com", "role": "operator"},
    )
    assert created.status_code == 201
    token = created.json()["token"]
    pending = await client.get(
        f"{API}/organizations/{organization.id}/invitations", headers=owner_headers
    )
    assert [item["email"] for item in pending.json()] == ["invitee@example.com"]
    assert "token" not in pending.json()[0]

    accepted = await client.post(
        f"{API}/invitations/accept", headers=invitee_headers, json={"token": token}
    )

    assert accepted.status_code == 200
    assert accepted.json()["role"] == "operator"
    assert accepted.json()["id"] == str(organization.id)
    # Single use.
    again = await client.post(
        f"{API}/invitations/accept", headers=invitee_headers, json={"token": token}
    )
    assert again.status_code == 422
    assert again.json()["code"] == "invitation.invalid"
    pending = await client.get(
        f"{API}/organizations/{organization.id}/invitations", headers=owner_headers
    )
    assert pending.json() == []


async def test_invitation_only_works_for_the_invited_email(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    token = (
        await client.post(
            f"{API}/organizations/{organization.id}/invitations",
            headers=await auth_headers(session, owner),
            json={"email": "intended@example.com"},
        )
    ).json()["token"]
    someone_else = await auth_headers(session, await create_user(session))

    response = await client.post(
        f"{API}/invitations/accept", headers=someone_else, json={"token": token}
    )

    assert response.status_code == 403
    assert response.json()["code"] == "invitation.email_mismatch"


async def test_expired_invitation_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    invitee = await create_user(session)
    token = (
        await client.post(
            f"{API}/organizations/{organization.id}/invitations",
            headers=await auth_headers(session, owner),
            json={"email": invitee.email},
        )
    ).json()["token"]
    await session.execute(
        update(Invitation).values(expires_at=datetime.now(UTC) - timedelta(minutes=1))
    )

    response = await client.post(
        f"{API}/invitations/accept",
        headers=await auth_headers(session, invitee),
        json={"token": token},
    )

    assert response.status_code == 422
    members = await session.scalars(
        select(Membership).where(Membership.organization_id == organization.id)
    )
    assert len(list(members)) == 1


async def test_reinviting_replaces_the_pending_invitation(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    headers = await auth_headers(session, owner)
    invitee = await create_user(session)
    url = f"{API}/organizations/{organization.id}/invitations"
    first = (await client.post(url, headers=headers, json={"email": invitee.email})).json()

    second = (
        await client.post(url, headers=headers, json={"email": invitee.email, "role": "admin"})
    ).json()

    assert len((await client.get(url, headers=headers)).json()) == 1
    invitee_headers = await auth_headers(session, invitee)
    stale = await client.post(
        f"{API}/invitations/accept", headers=invitee_headers, json={"token": first["token"]}
    )
    fresh = await client.post(
        f"{API}/invitations/accept", headers=invitee_headers, json={"token": second["token"]}
    )
    assert stale.status_code == 422
    assert fresh.json()["role"] == "admin"


async def test_cannot_invite_an_existing_member(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    member = await add_member(session, organization, Role.USER)

    response = await client.post(
        f"{API}/organizations/{organization.id}/invitations",
        headers=await auth_headers(session, owner),
        json={"email": member.email},
    )

    assert response.status_code == 409
    assert response.json()["code"] == "invitation.already_member"


async def test_admin_cannot_invite_an_owner(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))

    response = await client.post(
        f"{API}/organizations/{organization.id}/invitations",
        headers=await member_headers(session, organization, Role.ADMIN),
        json={"email": "new-owner@example.com", "role": "owner"},
    )

    assert response.status_code == 403


async def test_revoked_invitation_cannot_be_accepted(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    headers = await auth_headers(session, owner)
    invitee = await create_user(session)
    url = f"{API}/organizations/{organization.id}/invitations"
    created = (await client.post(url, headers=headers, json={"email": invitee.email})).json()

    revoked = await client.delete(f"{url}/{created['id']}", headers=headers)

    assert revoked.status_code == 204
    accepted = await client.post(
        f"{API}/invitations/accept",
        headers=await auth_headers(session, invitee),
        json={"token": created["token"]},
    )
    assert accepted.status_code == 422
