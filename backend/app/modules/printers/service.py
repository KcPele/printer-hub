"""Logical printer profiles (FRD §9, §10, §16)."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, NotFoundError
from app.core.pagination import PageParams, paginate
from app.modules.audit import service as audit
from app.modules.capabilities.schemas import PrinterCapabilities
from app.modules.connections import service as connections
from app.modules.connections.models import Connection
from app.modules.printers.models import Printer
from app.modules.printers.schemas import (
    PrinterCreate,
    PrinterRead,
    PrinterStatusDetail,
    PrinterStatusReport,
    PrinterUpdate,
)


def to_read(printer: Printer, printer_connections: list[Connection]) -> PrinterRead:
    return PrinterRead(
        id=printer.id,
        organization_id=printer.organization_id,
        friendly_name=printer.friendly_name,
        manufacturer=printer.manufacturer,
        model=printer.model,
        serial_number=printer.serial_number,
        location=printer.location,
        capabilities=(
            PrinterCapabilities.model_validate(printer.capabilities)
            if printer.capabilities is not None
            else None
        ),
        capabilities_updated_at=printer.capabilities_updated_at,
        status=printer.status,
        status_detail=PrinterStatusDetail.model_validate(printer.status_detail),
        auto_fallback_enabled=printer.auto_fallback_enabled,
        last_seen_at=printer.last_seen_at,
        connections=[connections.to_read(connection) for connection in printer_connections],
        default_connection_id=printer_connections[0].id if printer_connections else None,
        created_at=printer.created_at,
        updated_at=printer.updated_at,
    )


async def _flush_unique_serial(session: AsyncSession) -> None:
    try:
        await session.flush()
    except IntegrityError as exc:
        raise ConflictError(
            "printer.duplicate_serial",
            "A printer with this serial number is already registered. "
            "Add the new connection to it instead.",
        ) from exc


async def get(
    session: AsyncSession, *, organization_id: uuid.UUID, printer_id: uuid.UUID
) -> Printer:
    printer = await session.scalar(
        select(Printer).where(
            Printer.id == printer_id,
            Printer.organization_id == organization_id,
            Printer.deleted_at.is_(None),
        )
    )
    if printer is None:
        raise NotFoundError("printer.not_found", "Printer not found.")
    return printer


async def list_printers(
    session: AsyncSession, *, organization_id: uuid.UUID, params: PageParams
) -> tuple[list[Printer], str | None]:
    stmt = select(Printer).where(
        Printer.organization_id == organization_id, Printer.deleted_at.is_(None)
    )
    return await paginate(session, stmt, Printer.id, params)


async def create(
    session: AsyncSession,
    *,
    organization_id: uuid.UUID,
    actor_user_id: uuid.UUID,
    payload: PrinterCreate,
) -> Printer:
    now = datetime.now(UTC)
    printer = Printer(
        organization_id=organization_id,
        friendly_name=payload.friendly_name.strip(),
        manufacturer=payload.manufacturer,
        model=payload.model,
        serial_number=payload.serial_number,
        location=payload.location,
        capabilities=(
            payload.capabilities.model_dump(mode="json", by_alias=True)
            if payload.capabilities
            else None
        ),
        capabilities_updated_at=now if payload.capabilities else None,
        created_by_user_id=actor_user_id,
    )
    session.add(printer)
    await _flush_unique_serial(session)
    audit.record(
        session,
        action="printer.added",
        target_type="printer",
        target_id=printer.id,
        organization_id=organization_id,
        actor_user_id=actor_user_id,
        detail={"friendly_name": printer.friendly_name, "model": printer.model},
    )
    for connection in payload.connections:
        await connections.create(
            session, printer=printer, actor_user_id=actor_user_id, payload=connection
        )
    return printer


async def update(
    session: AsyncSession, *, printer: Printer, actor_user_id: uuid.UUID, payload: PrinterUpdate
) -> Printer:
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        setattr(printer, field, value)
    await _flush_unique_serial(session)
    if changes:
        audit.record(
            session,
            action="printer.updated",
            target_type="printer",
            target_id=printer.id,
            organization_id=printer.organization_id,
            actor_user_id=actor_user_id,
            detail={"changed": sorted(changes)},
        )
    return printer


async def remove(session: AsyncSession, *, printer: Printer, actor_user_id: uuid.UUID) -> None:
    """Soft delete: job history keeps pointing at the printer."""
    printer.deleted_at = datetime.now(UTC)
    audit.record(
        session,
        action="printer.removed",
        target_type="printer",
        target_id=printer.id,
        organization_id=printer.organization_id,
        actor_user_id=actor_user_id,
        detail={"friendly_name": printer.friendly_name},
    )
    await session.flush()


async def set_capabilities(
    session: AsyncSession, *, printer: Printer, capabilities: PrinterCapabilities
) -> Printer:
    """Store the capability snapshot a client obtained by probing the device."""
    printer.capabilities = capabilities.model_dump(mode="json", by_alias=True)
    printer.capabilities_updated_at = datetime.now(UTC)
    await session.flush()
    return printer


async def report_status(
    session: AsyncSession, *, printer: Printer, report: PrinterStatusReport
) -> Printer:
    printer.status = report.status
    if report.detail is not None:
        printer.status_detail = report.detail.model_dump(mode="json")
    printer.last_seen_at = datetime.now(UTC)
    await session.flush()
    return printer
