"""Builders for test data. Each inserts and flushes, so rows are visible to API calls."""

import uuid
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.core.security import create_access_token, generate_token, hash_password, hash_token
from app.modules.auth.models import UserSession
from app.modules.connections.models import Connection, ConnectionType
from app.modules.organizations import service as organizations
from app.modules.organizations.models import Membership, Organization
from app.modules.organizations.schemas import OrganizationSettings
from app.modules.printers.models import Printer
from app.modules.users.models import User

PASSWORD = "correct-horse-battery"


@lru_cache
def _password_hash() -> str:
    # Argon2 is deliberately slow; hash the shared test password once.
    return hash_password(PASSWORD)


def unique_email(prefix: str = "user") -> str:
    return f"{prefix}-{uuid.uuid4().hex[:10]}@example.com"


async def create_user(session: AsyncSession, **overrides: Any) -> User:
    values: dict[str, Any] = {
        "email": unique_email(),
        "password_hash": _password_hash(),
        "name": "Test User",
    }
    values.update(overrides)
    user = User(**values)
    session.add(user)
    await session.flush()
    return user


async def auth_headers(session: AsyncSession, user: User) -> dict[str, str]:
    """Open a session for `user` and return its Authorization header."""
    user_session = UserSession(
        user_id=user.id,
        refresh_token_hash=hash_token(generate_token()),
        expires_at=datetime.now(UTC) + timedelta(days=1),
    )
    session.add(user_session)
    await session.flush()
    token, _ = create_access_token(user.id, user_session.id)
    return {"Authorization": f"Bearer {token}"}


async def create_organization(
    session: AsyncSession,
    owner: User,
    *,
    name: str = "Acme Print",
    settings: dict[str, Any] | None = None,
) -> Organization:
    organization, _ = await organizations.create(session, name=name, owner=owner)
    if settings is not None:
        organization.settings = OrganizationSettings(**settings).model_dump(mode="json")
        await session.flush()
    return organization


async def add_member(
    session: AsyncSession, organization: Organization, role: Role, **user_overrides: Any
) -> User:
    user = await create_user(session, **user_overrides)
    session.add(Membership(organization_id=organization.id, user_id=user.id, role=role))
    await session.flush()
    return user


async def member_headers(
    session: AsyncSession, organization: Organization, role: Role
) -> dict[str, str]:
    """Create a new member with `role` and return their Authorization header."""
    return await auth_headers(session, await add_member(session, organization, role))


async def create_printer(
    session: AsyncSession, organization: Organization, **overrides: Any
) -> Printer:
    values: dict[str, Any] = {
        "organization_id": organization.id,
        "friendly_name": "Office Xerox",
        "manufacturer": "Xerox",
        "model": "VersaLink C7130",
    }
    values.update(overrides)
    printer = Printer(**values)
    session.add(printer)
    await session.flush()
    return printer


async def create_connection(
    session: AsyncSession, printer: Printer, **overrides: Any
) -> Connection:
    values: dict[str, Any] = {
        "organization_id": printer.organization_id,
        "printer_id": printer.id,
        "type": ConnectionType.IPPS,
        "purposes": ["print"],
        "priority": 1,
        "configuration": {"host": "192.168.1.50", "port": 631, "path": "/ipp/print", "tls": True},
    }
    values.update(overrides)
    connection = Connection(**values)
    session.add(connection)
    await session.flush()
    return connection
