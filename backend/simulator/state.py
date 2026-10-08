"""The simulated printer's mutable state."""

import time
import uuid
from dataclasses import dataclass, field

# IPP job-state values (RFC 8011 §5.3.7).
JOB_PENDING = 3
JOB_PROCESSING = 5
JOB_PROCESSING_STOPPED = 6
JOB_CANCELED = 7
JOB_COMPLETED = 9

# IPP printer-state values (RFC 8011 §5.4.11).
PRINTER_IDLE = 3
PRINTER_PROCESSING = 4
PRINTER_STOPPED = 5

MODEL = "Xerox VersaLink C7130"


@dataclass(slots=True)
class PrintJob:
    id: int
    name: str
    user: str
    document_format: str
    copies: int
    size_bytes: int
    created_at: float
    # Fixed at submission, so changing the simulator's speed never rewrites history.
    duration_seconds: float
    canceled: bool = False
    # Set when the job was submitted into a jam; it stays stopped.
    jammed: bool = False
    # Counted from the document when it is a raster; unknown for a PDF or JPEG.
    pages: int | None = None


@dataclass(slots=True)
class ScanJob:
    id: str
    source: str
    document_format: str
    pages_total: int
    pages_served: int = 0
    # How many more times the next page answers "busy" before it is handed over.
    busy_left: int = 0


@dataclass
class Faults:
    """Conditions a tester can switch on to exercise client error handling."""

    offline: bool = False
    paper_jam: bool = False
    door_open: bool = False
    adf_empty: bool = False
    # Turns the eSCL endpoints off, as on firmware that does not expose them.
    escl_disabled: bool = False
    # Answers IPP 2.0 requests with "version not supported", like a printer from before 2010.
    ipp_1_1_only: bool = False


DOCUMENT_FORMATS = (
    "application/pdf",
    "image/jpeg",
    "image/urf",
    "image/pwg-raster",
    "application/octet-stream",
)


@dataclass
class PrinterState:
    faults: Faults = field(default_factory=Faults)
    # Percent remaining per toner colour.
    toner: dict[str, int] = field(
        default_factory=lambda: {"black": 82, "cyan": 64, "magenta": 71, "yellow": 58}
    )
    # Seconds a newly submitted print job takes to complete.
    job_duration_seconds: float = 4.0
    # Pages the document feeder holds for one scan.
    adf_pages: int = 3
    # What the printer accepts. Remove application/pdf to stand in for a printer that only
    # takes pictures of pages, as many home printers do.
    document_formats: tuple[str, ...] = DOCUMENT_FORMATS
    # How IPP asks who is printing: "none", "basic", or "digest".
    auth: str = "none"
    auth_user: str = "printer"
    auth_password: str = "secret"  # noqa: S105 - a made-up password for a made-up printer
    # Changes with every reset, as a real printer's does with every challenge.
    auth_nonce: str = field(default_factory=lambda: uuid.uuid4().hex)
    # Times each scanned page answers "busy" (503) before it arrives.
    scan_busy_responses: int = 0
    # How the scanner names a new job in Location: "absolute", "path", or "wrong_host".
    scan_location: str = "absolute"
    uuid: str = field(default_factory=lambda: str(uuid.uuid4()))
    print_jobs: dict[int, PrintJob] = field(default_factory=dict)
    scan_jobs: dict[str, ScanJob] = field(default_factory=dict)
    _next_job_id: int = 1

    def new_print_job(
        self,
        *,
        name: str,
        user: str,
        document_format: str,
        copies: int,
        size_bytes: int,
        pages: int | None = None,
    ) -> PrintJob:
        job = PrintJob(
            id=self._next_job_id,
            name=name,
            user=user,
            document_format=document_format,
            copies=copies,
            size_bytes=size_bytes,
            created_at=time.monotonic(),
            duration_seconds=self.job_duration_seconds,
            jammed=self.faults.paper_jam,
            pages=pages,
        )
        self._next_job_id += 1
        self.print_jobs[job.id] = job
        return job

    def job_state(self, job: PrintJob) -> int:
        if job.canceled:
            return JOB_CANCELED
        if job.jammed:
            return JOB_PROCESSING_STOPPED
        elapsed = time.monotonic() - job.created_at
        if elapsed >= job.duration_seconds:
            return JOB_COMPLETED
        if elapsed >= job.duration_seconds * 0.25:
            return JOB_PROCESSING
        return JOB_PENDING

    def job_state_reasons(self, job: PrintJob) -> list[str]:
        return {
            JOB_CANCELED: ["job-canceled-by-user"],
            JOB_PROCESSING_STOPPED: ["printer-stopped"],
            JOB_COMPLETED: ["job-completed-successfully"],
            JOB_PROCESSING: ["job-printing"],
        }.get(self.job_state(job), ["none"])

    def printer_state(self) -> int:
        if self.faults.paper_jam or self.faults.door_open:
            return PRINTER_STOPPED
        states = {self.job_state(job) for job in self.print_jobs.values()}
        return PRINTER_PROCESSING if JOB_PROCESSING in states else PRINTER_IDLE

    def printer_state_reasons(self) -> list[str]:
        reasons = []
        if self.faults.paper_jam:
            reasons.append("media-jam-error")
        if self.faults.door_open:
            reasons.append("door-open-error")
        reasons += [
            "toner-empty-error" if level == 0 else "toner-low-warning"
            for level in self.toner.values()
            if level <= 10
        ]
        return list(dict.fromkeys(reasons)) or ["none"]

    def is_scanning(self) -> bool:
        return any(job.pages_served < job.pages_total for job in self.scan_jobs.values())
