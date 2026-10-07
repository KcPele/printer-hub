import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.core.deps import SessionDep
from app.core.errors import problem_responses
from app.core.pagination import Page, PageParams
from app.core.permissions import Permission
from app.modules.capabilities.schemas import PrinterCapabilities
from app.modules.connections import service as connections
from app.modules.connections.schemas import (
    ConnectionCreate,
    ConnectionCredentials,
    ConnectionHealthReport,
    ConnectionPriorityUpdate,
    ConnectionRead,
    ConnectionUpdate,
)
from app.modules.organizations.deps import OrgContext, require
from app.modules.printers import service
from app.modules.printers.models import Printer
from app.modules.printers.schemas import (
    PrinterCreate,
    PrinterRead,
    PrinterStatusReport,
    PrinterUpdate,
)

router = APIRouter(prefix="/organizations/{org_id}/printers", tags=["printers"])
connections_router = APIRouter(
    prefix="/organizations/{org_id}/printers/{printer_id}/connections", tags=["connections"]
)

Reader = Annotated[OrgContext, Depends(require(Permission.PRINTERS_READ))]
Reporter = Annotated[OrgContext, Depends(require(Permission.PRINTERS_REPORT))]
Manager = Annotated[OrgContext, Depends(require(Permission.PRINTERS_MANAGE))]


async def _read(session: SessionDep, printer: Printer) -> PrinterRead:
    return service.to_read(printer, await connections.list_for_printer(session, printer.id))


# --- Printers ----------------------------------------------------------------


@router.post("", status_code=status.HTTP_201_CREATED, responses=problem_responses(409))
async def add_printer(payload: PrinterCreate, ctx: Manager, session: SessionDep) -> PrinterRead:
    """Register a printer together with the connection paths the client verified."""
    printer = await service.create(
        session, organization_id=ctx.organization.id, actor_user_id=ctx.user.id, payload=payload
    )
    return await _read(session, printer)


@router.get("")
async def list_printers(
    ctx: Reader, session: SessionDep, params: Annotated[PageParams, Depends()]
) -> Page[PrinterRead]:
    printers, next_cursor = await service.list_printers(
        session, organization_id=ctx.organization.id, params=params
    )
    grouped = await connections.list_for_printers(session, [printer.id for printer in printers])
    return Page(
        items=[service.to_read(printer, grouped[printer.id]) for printer in printers],
        next_cursor=next_cursor,
    )


@router.get("/{printer_id}")
async def get_printer(printer_id: uuid.UUID, ctx: Reader, session: SessionDep) -> PrinterRead:
    printer = await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)
    return await _read(session, printer)


@router.patch("/{printer_id}", responses=problem_responses(409))
async def update_printer(
    printer_id: uuid.UUID, payload: PrinterUpdate, ctx: Manager, session: SessionDep
) -> PrinterRead:
    printer = await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)
    printer = await service.update(
        session, printer=printer, actor_user_id=ctx.user.id, payload=payload
    )
    return await _read(session, printer)


@router.delete("/{printer_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_printer(printer_id: uuid.UUID, ctx: Manager, session: SessionDep) -> None:
    printer = await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)
    await service.remove(session, printer=printer, actor_user_id=ctx.user.id)


@router.put("/{printer_id}/capabilities")
async def report_capabilities(
    printer_id: uuid.UUID, payload: PrinterCapabilities, ctx: Reporter, session: SessionDep
) -> PrinterRead:
    """Replace the capability snapshot with what the client just probed."""
    printer = await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)
    printer = await service.set_capabilities(session, printer=printer, capabilities=payload)
    return await _read(session, printer)


@router.post("/{printer_id}/status")
async def report_status(
    printer_id: uuid.UUID, payload: PrinterStatusReport, ctx: Reporter, session: SessionDep
) -> PrinterRead:
    """Report printer state observed on the local network."""
    printer = await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)
    printer = await service.report_status(session, printer=printer, report=payload)
    return await _read(session, printer)


# --- Connections -------------------------------------------------------------


async def _printer(session: SessionDep, ctx: OrgContext, printer_id: uuid.UUID) -> Printer:
    return await service.get(session, organization_id=ctx.organization.id, printer_id=printer_id)


@connections_router.post("", status_code=status.HTTP_201_CREATED)
async def add_connection(
    printer_id: uuid.UUID, payload: ConnectionCreate, ctx: Manager, session: SessionDep
) -> ConnectionRead:
    printer = await _printer(session, ctx, printer_id)
    connection = await connections.create(
        session, printer=printer, actor_user_id=ctx.user.id, payload=payload
    )
    return connections.to_read(connection)


@connections_router.get("")
async def list_connections(
    printer_id: uuid.UUID, ctx: Reader, session: SessionDep
) -> list[ConnectionRead]:
    """Connections in fallback order, most preferred first."""
    printer = await _printer(session, ctx, printer_id)
    rows = await connections.list_for_printer(session, printer.id)
    return [connections.to_read(connection) for connection in rows]


@connections_router.put("/priority")
async def set_connection_priority(
    printer_id: uuid.UUID, payload: ConnectionPriorityUpdate, ctx: Manager, session: SessionDep
) -> list[ConnectionRead]:
    """Set the order in which clients try connections (FR-CON-009, FR-CON-011)."""
    printer = await _printer(session, ctx, printer_id)
    rows = await connections.reorder(
        session, printer=printer, actor_user_id=ctx.user.id, connection_ids=payload.connection_ids
    )
    return [connections.to_read(connection) for connection in rows]


@connections_router.get("/{connection_id}")
async def get_connection(
    printer_id: uuid.UUID, connection_id: uuid.UUID, ctx: Reader, session: SessionDep
) -> ConnectionRead:
    printer = await _printer(session, ctx, printer_id)
    connection = await connections.get(session, printer=printer, connection_id=connection_id)
    return connections.to_read(connection)


@connections_router.patch("/{connection_id}")
async def update_connection(
    printer_id: uuid.UUID,
    connection_id: uuid.UUID,
    payload: ConnectionUpdate,
    ctx: Manager,
    session: SessionDep,
) -> ConnectionRead:
    printer = await _printer(session, ctx, printer_id)
    connection = await connections.update(
        session,
        printer=printer,
        connection_id=connection_id,
        actor_user_id=ctx.user.id,
        payload=payload,
    )
    return connections.to_read(connection)


@connections_router.delete("/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_connection(
    printer_id: uuid.UUID, connection_id: uuid.UUID, ctx: Manager, session: SessionDep
) -> None:
    printer = await _printer(session, ctx, printer_id)
    await connections.delete(
        session, printer=printer, connection_id=connection_id, actor_user_id=ctx.user.id
    )


@connections_router.get("/{connection_id}/credentials")
async def read_connection_credentials(
    printer_id: uuid.UUID,
    connection_id: uuid.UUID,
    ctx: Annotated[OrgContext, Depends(require(Permission.CONNECTIONS_USE_CREDENTIALS))],
    session: SessionDep,
    response: Response,
) -> ConnectionCredentials:
    """Stored credentials, for a client about to use the connection.

    Every read is written to the audit log. Keep the result in platform
    secure storage (FR-MOB-018).
    """
    printer = await _printer(session, ctx, printer_id)
    credentials = await connections.read_credentials(
        session, printer=printer, connection_id=connection_id, actor_user_id=ctx.user.id
    )
    response.headers["Cache-Control"] = "no-store"
    return credentials


@connections_router.post("/{connection_id}/health")
async def report_connection_health(
    printer_id: uuid.UUID,
    connection_id: uuid.UUID,
    payload: ConnectionHealthReport,
    ctx: Reporter,
    session: SessionDep,
) -> ConnectionRead:
    """Report the outcome of using or testing a connection (FR-CON-012, FR-ONB-005)."""
    printer = await _printer(session, ctx, printer_id)
    connection = await connections.report_health(
        session, printer=printer, connection_id=connection_id, report=payload
    )
    return connections.to_read(connection)
