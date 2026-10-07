import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from app.core.deps import SessionDep
from app.core.errors import problem_responses
from app.core.idempotency import REPLAYED_HEADER, IdempotencyKey
from app.core.pagination import Page, PageParams
from app.core.permissions import Permission
from app.modules.jobs import service
from app.modules.jobs.models import JobStatus, JobType
from app.modules.jobs.schemas import (
    JobCreate,
    JobEventCreate,
    JobEventRead,
    JobRead,
    JobSyncRequest,
    JobSyncResponse,
)
from app.modules.jobs.service import JobFilters
from app.modules.organizations.deps import OrgContext, require

router = APIRouter(prefix="/organizations/{org_id}/jobs", tags=["jobs"])

Member = Annotated[OrgContext, Depends(require(Permission.ORG_READ))]
Submitter = Annotated[OrgContext, Depends(require(Permission.JOBS_CREATE))]


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    responses={
        status.HTTP_200_OK: {
            "model": JobRead,
            "description": "Replay: the job an earlier request with this key created",
        },
        **problem_responses(400, 409),
    },
)
async def create_job(
    payload: JobCreate,
    ctx: Submitter,
    session: SessionDep,
    key: IdempotencyKey,
    response: Response,
) -> JobRead:
    """Record a job the client is about to execute.

    Send a fresh `Idempotency-Key` per job and reuse it on every retry of the
    request, so a lost response never creates a second job (FR-PRN-022).
    """
    job, replayed = await service.submit(session, ctx, payload=payload, idempotency_key=key)
    if replayed:
        response.status_code = status.HTTP_200_OK
        response.headers[REPLAYED_HEADER] = "true"
    return service.to_read(job)


@router.post("/batch")
async def sync_jobs(
    payload: JobSyncRequest, ctx: Submitter, session: SessionDep
) -> JobSyncResponse:
    """Upload jobs and their state history recorded while offline.

    Items are independent: one failing does not affect the others. The call
    is safe to repeat.
    """
    return JobSyncResponse(results=await service.sync_batch(session, ctx, payload.items))


@router.get("")
async def list_jobs(
    ctx: Member,
    session: SessionDep,
    params: Annotated[PageParams, Depends()],
    printer_id: uuid.UUID | None = None,
    user_id: Annotated[
        uuid.UUID | None, Query(description="Ignored unless the caller may read all jobs")
    ] = None,
    type: JobType | None = None,
    status: Annotated[list[JobStatus] | None, Query()] = None,
    submitted_from: datetime | None = None,
    submitted_to: datetime | None = None,
) -> Page[JobRead]:
    """Job history, newest first. Members without `jobs.read_all` see only their own jobs."""
    jobs, next_cursor = await service.list_jobs(
        session,
        ctx,
        params=params,
        filters=JobFilters(
            printer_id=printer_id,
            user_id=user_id,
            type=type,
            statuses=status or (),
            submitted_from=submitted_from,
            submitted_to=submitted_to,
        ),
    )
    return Page(items=[service.to_read(job) for job in jobs], next_cursor=next_cursor)


@router.get("/{job_id}")
async def get_job(job_id: uuid.UUID, ctx: Member, session: SessionDep) -> JobRead:
    return service.to_read(await service.get(session, ctx, job_id))


@router.get("/{job_id}/events")
async def list_job_events(
    job_id: uuid.UUID, ctx: Member, session: SessionDep
) -> list[JobEventRead]:
    """Every reported state change and connection attempt, oldest first."""
    job = await service.get(session, ctx, job_id)
    return [JobEventRead.model_validate(event) for event in await service.list_events(session, job)]


@router.post("/{job_id}/events", responses=problem_responses(409))
async def report_job_event(
    job_id: uuid.UUID, payload: JobEventCreate, ctx: Member, session: SessionDep
) -> JobRead:
    """Report a state change from the client executing the job.

    Name the connection used on each attempt. When it differs from the
    previous one the job is marked as having fallen back (FR-CON-010).
    """
    job = await service.get(session, ctx, job_id)
    return service.to_read(await service.record_event(session, ctx, job, payload))


@router.post("/{job_id}/cancel", responses=problem_responses(409))
async def cancel_job(job_id: uuid.UUID, ctx: Member, session: SessionDep) -> JobRead:
    job = await service.get(session, ctx, job_id)
    return service.to_read(await service.cancel(session, ctx, job))


@router.post(
    "/{job_id}/retry",
    status_code=status.HTTP_201_CREATED,
    responses={
        status.HTTP_200_OK: {
            "model": JobRead,
            "description": "Replay of an earlier retry with this key",
        },
        **problem_responses(400, 409),
    },
)
async def retry_job(
    job_id: uuid.UUID,
    ctx: Submitter,
    session: SessionDep,
    key: IdempotencyKey,
    response: Response,
) -> JobRead:
    """Create a new job with the same settings as a failed or cancelled one."""
    job = await service.get(session, ctx, job_id)
    new_job, replayed = await service.retry(session, ctx, job, idempotency_key=key)
    if replayed:
        response.status_code = status.HTTP_200_OK
        response.headers[REPLAYED_HEADER] = "true"
    return service.to_read(new_job)
