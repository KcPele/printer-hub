"""HTTP surface of the simulated printer.

    uvicorn simulator.main:app --port 8631

See simulator/README.md.
"""

from typing import Annotated, Any, Literal

from fastapi import Body, FastAPI, HTTPException, Request, Response
from pydantic import BaseModel, Field

from simulator import auth, escl, printer
from simulator.fixtures import TINY_JPEG, make_pdf
from simulator.ipp import IppDecodeError, Message, Status, decode, encode
from simulator.state import MODEL, Faults, PrinterState

IPP_MEDIA_TYPE = "application/ipp"
XML_MEDIA_TYPE = "text/xml"

app = FastAPI(
    title="PrinterHub printer simulator",
    version="0.1.0",
    description=f"A fake {MODEL} that speaks IPP and eSCL, for client development.",
)
app.state.printer = PrinterState()


def _printer() -> PrinterState:
    current: PrinterState = app.state.printer
    return current


def _base_url(request: Request) -> str:
    return str(request.base_url).rstrip("/")


@app.get("/", tags=["info"])
async def describe(request: Request) -> dict[str, Any]:
    base = _base_url(request)
    return {
        "model": MODEL,
        "ipp": f"{base}/ipp/print",
        "escl": f"{base}/eSCL",
        "control": f"{base}/sim/state",
    }


# --- IPP ---------------------------------------------------------------------


@app.post("/ipp/print", tags=["ipp"])
async def ipp(request: Request) -> Response:
    """IPP over HTTP. Send and receive `application/ipp` bodies."""
    current = _printer()
    if not auth.authorized(
        current, request.headers.get("authorization"), request.method, request.url.path
    ):
        # Answered before the body is looked at, as a printer does.
        return Response(status_code=401, headers={"WWW-Authenticate": auth.challenge(current)})
    try:
        message = decode(await request.body())
    except IppDecodeError as error:
        failure = Message(code=Status.CLIENT_ERROR_BAD_REQUEST, request_id=0)
        return Response(encode(failure), media_type=IPP_MEDIA_TYPE, headers={"X-Error": str(error)})
    response = printer.handle(message, current, _base_url(request))
    # IPP reports errors inside a 200 response; the HTTP status stays OK.
    return Response(encode(response), media_type=IPP_MEDIA_TYPE)


# --- eSCL --------------------------------------------------------------------


def _require_escl() -> PrinterState:
    current = _printer()
    if current.faults.offline:
        raise HTTPException(503, "Printer is offline")
    if current.faults.escl_disabled:
        raise HTTPException(404, "eSCL is not enabled on this device")
    return current


@app.get("/eSCL/ScannerCapabilities", tags=["escl"])
async def scanner_capabilities() -> Response:
    return Response(escl.capabilities(_require_escl()), media_type=XML_MEDIA_TYPE)


@app.get("/eSCL/ScannerStatus", tags=["escl"])
async def scanner_status() -> Response:
    return Response(escl.status(_require_escl()), media_type=XML_MEDIA_TYPE)


@app.post("/eSCL/ScanJobs", status_code=201, tags=["escl"])
async def create_scan_job(request: Request) -> Response:
    """Start a scan. The `Location` header names the job to fetch pages from."""
    current = _require_escl()
    try:
        job = escl.create_job(current, (await request.body()).decode(errors="replace"))
    except escl.ScanRefused as refusal:
        raise HTTPException(refusal.status_code, refusal.reason) from refusal
    path = f"/eSCL/ScanJobs/{job.id}"
    location = {
        "path": path,
        # A name the client cannot look up, as some scanners give.
        "wrong_host": f"http://scanner-{job.id[:8]}.invalid{path}",
    }.get(current.scan_location, f"{_base_url(request)}{path}")
    return Response(status_code=201, headers={"Location": location})


@app.get("/eSCL/ScanJobs/{job_id}/NextDocument", tags=["escl"])
async def next_document(job_id: str) -> Response:
    """The next scanned page. Returns 404 once every page has been delivered."""
    current = _require_escl()
    job = current.scan_jobs.get(job_id)
    if job is None or job.pages_served >= job.pages_total:
        raise HTTPException(404, "No more pages")
    if job.busy_left > 0:
        job.busy_left -= 1
        raise HTTPException(503, "The page is still being scanned")
    job.busy_left = current.scan_busy_responses
    job.pages_served += 1
    if job.document_format == "image/jpeg":
        return Response(TINY_JPEG, media_type="image/jpeg")
    page = make_pdf(
        [
            "PrinterHub simulated scan",
            f"Source: {job.source}",
            f"Page {job.pages_served} of {job.pages_total}",
        ]
    )
    return Response(page, media_type="application/pdf")


@app.delete("/eSCL/ScanJobs/{job_id}", tags=["escl"])
async def cancel_scan_job(job_id: str) -> Response:
    current = _require_escl()
    if current.scan_jobs.pop(job_id, None) is None:
        raise HTTPException(404, "No such scan job")
    return Response(status_code=200)


# --- Control -----------------------------------------------------------------


class FaultsPatch(BaseModel):
    offline: bool | None = None
    paper_jam: bool | None = None
    door_open: bool | None = None
    adf_empty: bool | None = None
    escl_disabled: bool | None = None
    ipp_1_1_only: bool | None = None


class StatePatch(BaseModel):
    faults: FaultsPatch | None = None
    toner: dict[str, Annotated[int, Field(ge=0, le=100)]] | None = None
    job_duration_seconds: float | None = Field(default=None, ge=0, le=3600)
    adf_pages: int | None = Field(default=None, ge=1, le=50)
    document_formats: list[str] | None = Field(default=None, min_length=1)
    auth: Literal["none", "basic", "digest"] | None = None
    auth_user: str | None = None
    auth_password: str | None = None
    scan_busy_responses: int | None = Field(default=None, ge=0, le=60)
    scan_location: Literal["absolute", "path", "wrong_host"] | None = None


def _snapshot(current: PrinterState) -> dict[str, Any]:
    return {
        "model": MODEL,
        "faults": vars(current.faults),
        "toner": current.toner,
        "job_duration_seconds": current.job_duration_seconds,
        "adf_pages": current.adf_pages,
        "document_formats": list(current.document_formats),
        "auth": current.auth,
        "scan_busy_responses": current.scan_busy_responses,
        "scan_location": current.scan_location,
        "printer_state_reasons": current.printer_state_reasons(),
        "print_jobs": [
            {
                "id": job.id,
                "name": job.name,
                "user": job.user,
                "state": current.job_state(job),
                "document_format": job.document_format,
                "size_bytes": job.size_bytes,
                "pages": job.pages,
            }
            for job in current.print_jobs.values()
        ],
        "scan_jobs": [
            {"id": job.id, "pages_served": job.pages_served, "pages_total": job.pages_total}
            for job in current.scan_jobs.values()
        ],
    }


@app.get("/sim/state", tags=["control"])
async def get_state() -> dict[str, Any]:
    return _snapshot(_printer())


@app.patch("/sim/state", tags=["control"])
async def patch_state(patch: Annotated[StatePatch, Body()]) -> dict[str, Any]:
    """Switch faults on or off and adjust supplies, to exercise a client's error handling."""
    current = _printer()
    if patch.faults is not None:
        for name, value in patch.faults.model_dump(exclude_none=True).items():
            setattr(current.faults, name, value)
        if not current.faults.paper_jam:
            # Clearing the jam lets stopped jobs finish.
            for job in current.print_jobs.values():
                job.jammed = False
    if patch.toner is not None:
        current.toner.update(patch.toner)
    if patch.job_duration_seconds is not None:
        current.job_duration_seconds = patch.job_duration_seconds
    if patch.adf_pages is not None:
        current.adf_pages = patch.adf_pages
    if patch.document_formats is not None:
        current.document_formats = tuple(patch.document_formats)
    for name in ("auth", "auth_user", "auth_password", "scan_busy_responses", "scan_location"):
        value = getattr(patch, name)
        if value is not None:
            setattr(current, name, value)
    return _snapshot(current)


@app.post("/sim/reset", tags=["control"])
async def reset() -> dict[str, Any]:
    """Return the printer to its factory state: no jobs, no faults, full defaults."""
    app.state.printer = PrinterState()
    return _snapshot(_printer())


__all__ = ["Faults", "app"]
