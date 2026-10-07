"""Print, scan, and copy jobs (FRD §11 to §15).

Clients execute jobs on the local network. This service records what they
intend to do and what they report, enforces organization policy, and keeps
the state machine honest.
"""

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime

from pydantic import TypeAdapter
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import idempotency
from app.core.errors import (
    AppError,
    ConflictError,
    NotFoundError,
    PermissionDeniedError,
    ValidationFailedError,
)
from app.core.pagination import PageParams, paginate
from app.core.permissions import Permission
from app.modules.capabilities.schemas import PrinterCapabilities
from app.modules.connections import service as connections
from app.modules.documents import service as documents
from app.modules.jobs import state
from app.modules.jobs.models import Job, JobEvent, JobStatus, JobType
from app.modules.jobs.schemas import (
    CopyJobCreate,
    JobEventCreate,
    JobRead,
    JobSyncError,
    JobSyncItem,
    JobSyncResult,
    PrintJobCreate,
    ScanJobCreate,
)
from app.modules.organizations.context import OrgContext
from app.modules.printers import service as printers
from app.modules.printers.models import Printer

AnyJobCreate = PrintJobCreate | ScanJobCreate | CopyJobCreate

_JOB_READ: TypeAdapter[JobRead] = TypeAdapter(JobRead)


def to_read(job: Job) -> JobRead:
    return _JOB_READ.validate_python(job, from_attributes=True)


@dataclass(frozen=True, slots=True)
class JobFilters:
    """FR-JOB-004."""

    printer_id: uuid.UUID | None = None
    user_id: uuid.UUID | None = None
    type: JobType | None = None
    statuses: Sequence[JobStatus] = ()
    submitted_from: datetime | None = None
    submitted_to: datetime | None = None


# --- Access ------------------------------------------------------------------


def _may_read(ctx: OrgContext, job: Job) -> bool:
    return job.user_id == ctx.user.id or ctx.has(Permission.JOBS_READ_ALL)


def _ensure_may_change(ctx: OrgContext, job: Job) -> None:
    if job.user_id != ctx.user.id and not ctx.has(Permission.JOBS_MANAGE_ALL):
        raise PermissionDeniedError(
            "permission.denied", "Only the job's owner or an operator can change this job."
        )


async def get(session: AsyncSession, ctx: OrgContext, job_id: uuid.UUID) -> Job:
    job = await session.scalar(
        select(Job).where(Job.id == job_id, Job.organization_id == ctx.organization.id)
    )
    if job is None or not _may_read(ctx, job):
        raise NotFoundError("job.not_found", "Job not found.")
    return job


async def list_jobs(
    session: AsyncSession, ctx: OrgContext, *, params: PageParams, filters: JobFilters
) -> tuple[list[Job], str | None]:
    stmt = select(Job).where(Job.organization_id == ctx.organization.id)
    if not ctx.has(Permission.JOBS_READ_ALL):
        stmt = stmt.where(Job.user_id == ctx.user.id)
    elif filters.user_id is not None:
        stmt = stmt.where(Job.user_id == filters.user_id)
    if filters.printer_id is not None:
        stmt = stmt.where(Job.printer_id == filters.printer_id)
    if filters.type is not None:
        stmt = stmt.where(Job.type == filters.type)
    if filters.statuses:
        stmt = stmt.where(Job.status.in_(filters.statuses))
    if filters.submitted_from is not None:
        stmt = stmt.where(Job.submitted_at >= filters.submitted_from)
    if filters.submitted_to is not None:
        stmt = stmt.where(Job.submitted_at < filters.submitted_to)
    return await paginate(session, stmt, Job.id, params)


async def list_events(session: AsyncSession, job: Job) -> list[JobEvent]:
    rows = await session.scalars(
        select(JobEvent).where(JobEvent.job_id == job.id).order_by(JobEvent.id)
    )
    return list(rows)


# --- Policy ------------------------------------------------------------------


def _enforce_policy(ctx: OrgContext, payload: AnyJobCreate) -> None:
    """Organization limits on what a member may submit (FRD §19, §41)."""
    if isinstance(payload, ScanJobCreate):
        return
    policy = ctx.settings
    limit = policy.max_copies_per_job
    if limit is not None and payload.settings.copies > limit:
        raise ValidationFailedError(
            "job.policy_violation",
            f"This organization allows at most {limit} copies per job.",
        )
    if payload.settings.color_mode != "monochrome" and ctx.role not in policy.color_printing_roles:
        raise PermissionDeniedError(
            "job.color_not_allowed",
            "Your role cannot print in color here. Choose black and white.",
        )


def _ensure_supported(printer: Printer, job_type: JobType) -> None:
    """Refuse a job the printer is known not to support. Unknown capabilities pass."""
    if printer.capabilities is None:
        return
    capabilities = PrinterCapabilities.model_validate(printer.capabilities)
    supported = {
        JobType.PRINT: capabilities.print.supported,
        JobType.SCAN: capabilities.scan.supported,
        JobType.COPY: capabilities.copy_.supported
        or (capabilities.print.supported and capabilities.scan.supported),
    }[job_type]
    if not supported:
        raise ValidationFailedError(
            "job.unsupported_by_printer", f"This printer does not support {job_type.value} jobs."
        )


# --- Create ------------------------------------------------------------------


def _create_scope(organization_id: uuid.UUID) -> str:
    return f"jobs.create:{organization_id}"


async def _resolve_connection(
    session: AsyncSession, printer: Printer, connection_id: uuid.UUID | None
) -> str | None:
    if connection_id is None:
        return None
    connection = await connections.get(session, printer=printer, connection_id=connection_id)
    return connection.type.value


async def _insert(session: AsyncSession, job: Job, *, reported_by: uuid.UUID) -> Job:
    session.add(job)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise ConflictError("job.id_conflict", "A job with this ID already exists.") from exc
    session.add(
        JobEvent(
            job_id=job.id,
            status=job.status,
            connection_id=job.connection_id,
            connection_type=job.connection_type,
            reported_by_user_id=reported_by,
            occurred_at=job.submitted_at,
        )
    )
    await session.flush()
    return job


async def submit(
    session: AsyncSession, ctx: OrgContext, *, payload: AnyJobCreate, idempotency_key: str
) -> tuple[Job, bool]:
    """Create a job, or return the one an earlier request with this key created.

    The second element is True for a replay.
    """
    scope = _create_scope(ctx.organization.id)
    existing_id = await idempotency.claim(
        session,
        user_id=ctx.user.id,
        scope=scope,
        key=idempotency_key,
        request_hash=idempotency.fingerprint(payload),
    )
    if existing_id is not None:
        return await get(session, ctx, existing_id), True

    printer = await printers.get(
        session, organization_id=ctx.organization.id, printer_id=payload.printer_id
    )
    _ensure_supported(printer, payload.type)
    _enforce_policy(ctx, payload)
    if payload.document_id is not None:
        # Register a document before the job that prints it.
        await documents.get(session, ctx, payload.document_id)

    job = Job(
        organization_id=ctx.organization.id,
        user_id=ctx.user.id,
        printer_id=printer.id,
        device_id=ctx.session.device_id,
        type=payload.type,
        execution_mode=payload.execution_mode,
        status=JobStatus.QUEUED,
        title=payload.title,
        settings=payload.settings.model_dump(mode="json"),
        document_id=payload.document_id,
        connection_id=payload.connection_id,
        connection_type=await _resolve_connection(session, printer, payload.connection_id),
        page_count=payload.page_count,
        submitted_at=payload.submitted_at or datetime.now(UTC),
    )
    if payload.id is not None:
        job.id = payload.id
    await _insert(session, job, reported_by=ctx.user.id)
    await idempotency.complete(
        session, user_id=ctx.user.id, scope=scope, key=idempotency_key, resource_id=job.id
    )
    return job, False


# --- State changes -----------------------------------------------------------


async def record_event(
    session: AsyncSession,
    ctx: OrgContext,
    job: Job,
    report: JobEventCreate,
    *,
    skip_stale: bool = False,
) -> Job:
    """Apply a state change reported by the executing client.

    Reporting the terminal status a job already has is accepted and changes
    nothing, so a client can safely resend a completion it is unsure arrived.
    With `skip_stale`, any report the job has already moved past is ignored
    instead of rejected; batch sync uses this to replay history.
    """
    _ensure_may_change(ctx, job)
    if job.status in state.TERMINAL and report.status == job.status:
        return job
    if skip_stale and state.is_stale(job.status, report.status):
        return job
    state.validate_transition(job.type, job.status, report.status)

    printer = await printers.get(
        session, organization_id=ctx.organization.id, printer_id=job.printer_id
    )
    occurred_at = report.occurred_at or datetime.now(UTC)
    connection_type = await _resolve_connection(session, printer, report.connection_id)

    if report.connection_id is not None:
        if job.connection_id is not None and job.connection_id != report.connection_id:
            job.fallback_occurred = True
        job.connection_id = report.connection_id
        job.connection_type = connection_type
    if report.status is not JobStatus.QUEUED and job.started_at is None:
        job.started_at = occurred_at
    if report.status in state.TERMINAL:
        job.completed_at = occurred_at
    if report.printer_job_ref is not None:
        job.printer_job_ref = report.printer_job_ref
    if report.page_count is not None:
        job.page_count = report.page_count
    if report.output_document_id is not None:
        await documents.get(session, ctx, report.output_document_id)
        job.output_document_id = report.output_document_id
    if report.status is JobStatus.FAILED:
        job.error_code = report.error_code
        job.error_message = report.error_message
    job.status = report.status

    session.add(
        JobEvent(
            job_id=job.id,
            status=report.status,
            connection_id=report.connection_id,
            connection_type=connection_type,
            error_code=report.error_code,
            error_message=report.error_message,
            reported_by_user_id=ctx.user.id,
            detail=report.detail,
            occurred_at=occurred_at,
        )
    )
    await session.flush()
    return job


async def cancel(session: AsyncSession, ctx: OrgContext, job: Job) -> Job:
    """Mark a job cancelled (FR-PRN-020, FR-JOB-005).

    The client holding the job stops it at the printer where the connection
    allows; the backend records the decision.
    """
    return await record_event(session, ctx, job, JobEventCreate(status=JobStatus.CANCELLED))


async def retry(
    session: AsyncSession, ctx: OrgContext, job: Job, *, idempotency_key: str
) -> tuple[Job, bool]:
    """Create a new job from a failed or cancelled one (FR-PRN-021)."""
    _ensure_may_change(ctx, job)
    scope = f"jobs.retry:{job.id}"
    existing_id = await idempotency.claim(
        session,
        user_id=ctx.user.id,
        scope=scope,
        key=idempotency_key,
        request_hash=str(job.id),
    )
    if existing_id is not None:
        return await get(session, ctx, existing_id), True

    if job.status not in (JobStatus.FAILED, JobStatus.CANCELLED):
        raise ConflictError("job.not_retryable", "Only a failed or cancelled job can be retried.")
    # The printer may have been removed since the original job ran.
    await printers.get(session, organization_id=ctx.organization.id, printer_id=job.printer_id)

    new_job = Job(
        organization_id=job.organization_id,
        user_id=ctx.user.id,
        printer_id=job.printer_id,
        device_id=ctx.session.device_id,
        type=job.type,
        execution_mode=job.execution_mode,
        status=JobStatus.QUEUED,
        title=job.title,
        settings=job.settings,
        document_id=job.document_id,
        page_count=job.page_count,
        retry_of_job_id=job.id,
        submitted_at=datetime.now(UTC),
    )
    await _insert(session, new_job, reported_by=ctx.user.id)
    await idempotency.complete(
        session, user_id=ctx.user.id, scope=scope, key=idempotency_key, resource_id=new_job.id
    )
    return new_job, False


# --- Batch sync --------------------------------------------------------------


async def sync_batch(
    session: AsyncSession, ctx: OrgContext, items: Sequence[JobSyncItem]
) -> list[JobSyncResult]:
    """Apply jobs and their history recorded while a client was offline (FR-OFF-003).

    Each item succeeds or fails on its own. Sending the same batch again
    changes nothing.
    """
    results: list[JobSyncResult] = []
    for item in items:
        try:
            async with session.begin_nested():
                job, replayed = await submit(
                    session, ctx, payload=item.job, idempotency_key=item.idempotency_key
                )
                for report in sorted(
                    item.events,
                    key=lambda event: event.occurred_at or datetime.max.replace(tzinfo=UTC),
                ):
                    job = await record_event(session, ctx, job, report, skip_stale=True)
            results.append(
                JobSyncResult(
                    idempotency_key=item.idempotency_key,
                    outcome="replayed" if replayed else "created",
                    job=to_read(job),
                )
            )
        except AppError as error:
            results.append(
                JobSyncResult(
                    idempotency_key=item.idempotency_key,
                    outcome="failed",
                    error=JobSyncError(code=error.code, detail=error.detail),
                )
            )
    return results
