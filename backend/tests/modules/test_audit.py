import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.audit.models import AuditLog
from tests.factories import (
    PASSWORD,
    add_member,
    auth_headers,
    create_organization,
    create_user,
    member_headers,
)

API = "/api/v1"


async def test_membership_changes_are_audited(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    member = await add_member(session, organization, Role.USER)
    headers = await auth_headers(session, owner)

    await client.patch(
        f"{API}/organizations/{organization.id}/members/{member.id}",
        headers={**headers, "User-Agent": "PrinterHub-Test/1.0"},
        json={"role": "admin"},
    )

    response = await client.get(
        f"{API}/organizations/{organization.id}/audit-logs",
        headers=headers,
        params={"action": "member.role_changed"},
    )
    assert response.status_code == 200
    [entry] = response.json()["items"]
    assert entry["actor_user_id"] == str(owner.id)
    assert entry["target_type"] == "user"
    assert entry["target_id"] == str(member.id)
    assert entry["outcome"] == "success"
    assert entry["detail"] == {"from": "user", "to": "admin"}
    assert entry["ip"] == "127.0.0.1"


async def test_failed_change_leaves_no_audit_entry(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)

    response = await client.patch(
        f"{API}/organizations/{organization.id}/members/{owner.id}",
        headers=await auth_headers(session, owner),
        json={"role": "viewer"},
    )

    assert response.status_code == 409
    entries = await session.scalars(
        select(AuditLog).where(AuditLog.action == "member.role_changed")
    )
    assert list(entries) == []


async def test_audit_log_requires_permission(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    organization = await create_organization(session, await create_user(session))
    url = f"{API}/organizations/{organization.id}/audit-logs"

    operator = await client.get(
        url, headers=await member_headers(session, organization, Role.OPERATOR)
    )
    admin = await client.get(url, headers=await member_headers(session, organization, Role.ADMIN))

    assert operator.status_code == 403
    assert admin.status_code == 200


async def test_audit_log_is_paginated_newest_first(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)
    headers = await auth_headers(session, owner)
    for name in ("One", "Two", "Three"):
        await client.patch(
            f"{API}/organizations/{organization.id}", headers=headers, json={"name": name}
        )
    url = f"{API}/organizations/{organization.id}/audit-logs"

    first = (await client.get(url, headers=headers, params={"limit": 2})).json()
    second = (
        await client.get(url, headers=headers, params={"limit": 2, "cursor": first["next_cursor"]})
    ).json()

    assert len(first["items"]) == 2
    assert first["next_cursor"] is not None
    actions = [item["action"] for item in first["items"] + second["items"]]
    assert actions == [
        "organization.updated",
        "organization.updated",
        "organization.updated",
        "organization.created",
    ]
    assert second["next_cursor"] is None


async def test_invalid_cursor_is_rejected(client: httpx.AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session)
    organization = await create_organization(session, owner)

    response = await client.get(
        f"{API}/organizations/{organization.id}/audit-logs",
        headers=await auth_headers(session, owner),
        params={"cursor": "not-a-cursor"},
    )

    assert response.status_code == 422
    assert response.json()["code"] == "pagination.invalid_cursor"


async def test_login_is_audited(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)

    await client.post(f"{API}/auth/login", json={"email": user.email, "password": PASSWORD})

    entry = await session.scalar(select(AuditLog).where(AuditLog.action == "user.logged_in"))
    assert entry is not None
    assert entry.actor_user_id == user.id
    assert entry.organization_id is None
