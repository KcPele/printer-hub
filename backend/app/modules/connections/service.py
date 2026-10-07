"""Connection profiles: the ways a printer can be reached (FRD §8)."""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.crypto import decrypt_json, encrypt_json
from app.core.errors import NotFoundError, ValidationFailedError
from app.modules.audit import service as audit
from app.modules.connections.models import Connection, ConnectionHealth
from app.modules.connections.schemas import (
    ConnectionCreate,
    ConnectionCredentials,
    ConnectionHealthReport,
    ConnectionRead,
    ConnectionUpdate,
)
from app.modules.printers.models import Printer

_HEALTHY = frozenset({ConnectionHealth.CONNECTED, ConnectionHealth.DEGRADED})


def to_read(connection: Connection) -> ConnectionRead:
    return ConnectionRead.model_validate(
        {
            **{
                column.key: getattr(connection, column.key)
                for column in Connection.__table__.columns
                if column.key != "encrypted_credentials"
            },
            "has_credentials": connection.encrypted_credentials is not None,
        }
    )


async def list_for_printers(
    session: AsyncSession, printer_ids: Sequence[uuid.UUID]
) -> dict[uuid.UUID, list[Connection]]:
    """Connections grouped by printer, most preferred first."""
    grouped: dict[uuid.UUID, list[Connection]] = {printer_id: [] for printer_id in printer_ids}
    if not printer_ids:
        return grouped
    rows = await session.scalars(
        select(Connection)
        .where(Connection.printer_id.in_(printer_ids))
        .order_by(Connection.priority, Connection.id)
    )
    for connection in rows:
        grouped[connection.printer_id].append(connection)
    return grouped


async def list_for_printer(session: AsyncSession, printer_id: uuid.UUID) -> list[Connection]:
    return (await list_for_printers(session, [printer_id]))[printer_id]


async def get(session: AsyncSession, *, printer: Printer, connection_id: uuid.UUID) -> Connection:
    connection = await session.scalar(
        select(Connection).where(
            Connection.id == connection_id, Connection.printer_id == printer.id
        )
    )
    if connection is None:
        raise NotFoundError("connection.not_found", "Connection not found.")
    return connection


async def find_in_organization(
    session: AsyncSession, *, organization_id: uuid.UUID, connection_id: uuid.UUID
) -> Connection | None:
    result: Connection | None = await session.scalar(
        select(Connection).where(
            Connection.id == connection_id, Connection.organization_id == organization_id
        )
    )
    return result


async def create(
    session: AsyncSession, *, printer: Printer, actor_user_id: uuid.UUID, payload: ConnectionCreate
) -> Connection:
    priority = payload.priority
    if priority is None:
        highest = await session.scalar(
            select(func.max(Connection.priority)).where(Connection.printer_id == printer.id)
        )
        priority = (highest or 0) + 1
    connection = Connection(
        organization_id=printer.organization_id,
        printer_id=printer.id,
        type=payload.type,
        purposes=[purpose.value for purpose in payload.purposes],
        priority=priority,
        configuration=payload.configuration.model_dump(mode="json"),
        encrypted_credentials=_encrypt(payload.credentials),
    )
    session.add(connection)
    audit.record(
        session,
        action="connection.created",
        target_type="connection",
        target_id=connection.id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
        detail={"printer_id": str(printer.id), "type": payload.type.value},
    )
    await session.flush()
    return connection


def _encrypt(credentials: ConnectionCredentials | None) -> bytes | None:
    if credentials is None:
        return None
    return encrypt_json(credentials.model_dump(mode="json"))


async def update(
    session: AsyncSession,
    *,
    printer: Printer,
    connection_id: uuid.UUID,
    actor_user_id: uuid.UUID,
    payload: ConnectionUpdate,
) -> Connection:
    connection = await get(session, printer=printer, connection_id=connection_id)
    fields = payload.model_fields_set
    if "purposes" in fields and payload.purposes is not None:
        connection.purposes = [purpose.value for purpose in payload.purposes]
    if "configuration" in fields and payload.configuration is not None:
        connection.configuration = payload.configuration.model_dump(mode="json")
    if fields & {"purposes", "configuration"}:
        audit.record(
            session,
            action="connection.modified",
            target_type="connection",
            target_id=connection.id,
            organization_id=printer.organization_id,
            actor_user_id=actor_user_id,
            detail={"changed": sorted(fields & {"purposes", "configuration"})},
        )
    if "credentials" in fields:
        connection.encrypted_credentials = _encrypt(payload.credentials)
        audit.record(
            session,
            action="connection.credentials_changed",
            target_type="connection",
            target_id=connection.id,
            organization_id=printer.organization_id,
            actor_user_id=actor_user_id,
            detail={"removed": payload.credentials is None},
        )
    await session.flush()
    return connection


async def delete(
    session: AsyncSession, *, printer: Printer, connection_id: uuid.UUID, actor_user_id: uuid.UUID
) -> None:
    connection = await get(session, printer=printer, connection_id=connection_id)
    await session.delete(connection)
    audit.record(
        session,
        action="connection.removed",
        target_type="connection",
        target_id=connection_id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
        detail={"printer_id": str(printer.id), "type": connection.type.value},
    )
    await session.flush()


async def read_credentials(
    session: AsyncSession, *, printer: Printer, connection_id: uuid.UUID, actor_user_id: uuid.UUID
) -> ConnectionCredentials:
    """Decrypt a connection's credentials for a client about to use it. Audited."""
    connection = await get(session, printer=printer, connection_id=connection_id)
    if connection.encrypted_credentials is None:
        raise NotFoundError(
            "connection.no_credentials", "This connection has no stored credentials."
        )
    audit.record(
        session,
        action="connection.credentials_accessed",
        target_type="connection",
        target_id=connection.id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
    )
    return ConnectionCredentials.model_validate(decrypt_json(connection.encrypted_credentials))


async def reorder(
    session: AsyncSession,
    *,
    printer: Printer,
    actor_user_id: uuid.UUID,
    connection_ids: Sequence[uuid.UUID],
) -> list[Connection]:
    """Set the fallback order. `connection_ids` must list every connection exactly once."""
    connections = await list_for_printer(session, printer.id)
    by_id = {connection.id: connection for connection in connections}
    if len(connection_ids) != len(by_id) or set(connection_ids) != set(by_id):
        raise ValidationFailedError(
            "connection.priority_mismatch",
            "List every connection of this printer exactly once.",
        )
    for position, connection_id in enumerate(connection_ids, start=1):
        by_id[connection_id].priority = position
    audit.record(
        session,
        action="connection.priority_changed",
        target_type="printer",
        target_id=printer.id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
        detail={"order": [str(connection_id) for connection_id in connection_ids]},
    )
    await session.flush()
    return [by_id[connection_id] for connection_id in connection_ids]


async def report_health(
    session: AsyncSession,
    *,
    printer: Printer,
    connection_id: uuid.UUID,
    report: ConnectionHealthReport,
) -> Connection:
    connection = await get(session, printer=printer, connection_id=connection_id)
    now = datetime.now(UTC)
    connection.health = report.health
    connection.last_latency_ms = report.latency_ms
    if report.health in _HEALTHY:
        connection.last_success_at = now
        connection.last_error = None
        printer.last_seen_at = now
    else:
        connection.last_failure_at = now
        connection.last_error = report.error
    await session.flush()
    return connection
