"""IPP operations of the simulated printer."""

from simulator import state as s
from simulator.ipp import Group, GroupTag, Message, Operation, Status
from simulator.ipp import ValueTag as V
from simulator.state import PrinterState, PrintJob

DOCUMENT_FORMATS = (
    "application/pdf",
    "image/jpeg",
    "image/urf",
    "image/pwg-raster",
    "application/octet-stream",
)
MEDIA = (
    "iso_a4_210x297mm",
    "iso_a3_297x420mm",
    "iso_a5_148x210mm",
    "na_letter_8.5x11in",
    "na_legal_8.5x14in",
    "na_ledger_11x17in",
)
MAX_COPIES = 999
_DOTS_PER_INCH = 3


def _response(request: Message, status: Status) -> Message:
    operation = Group(GroupTag.OPERATION)
    operation.add("attributes-charset", V.CHARSET, "utf-8")
    operation.add("attributes-natural-language", V.NATURAL_LANGUAGE, "en")
    return Message(code=status, request_id=request.request_id, groups=[operation])


def _error(request: Message, status: Status, message: str) -> Message:
    response = _response(request, status)
    response.groups[0].add("status-message", V.TEXT, message)
    return response


def _requested(request: Message) -> set[str] | None:
    """The attribute names the client asked for, or None for all of them."""
    operation = request.group(GroupTag.OPERATION)
    values = operation.get("requested-attributes") if operation else None
    if not values or "all" in values:
        return None
    return {str(value) for value in values}


def _filter(group: Group, wanted: set[str] | None) -> Group:
    if wanted is not None:
        group.attributes = [a for a in group.attributes if a.name in wanted]
    return group


def _printer_attributes(printer: PrinterState, base_url: str) -> Group:
    ipp_url = base_url.replace("http://", "ipp://").replace("https://", "ipps://")
    colors = list(printer.toner)
    g = Group(GroupTag.PRINTER)
    g.add("printer-uri-supported", V.URI, f"{ipp_url}/ipp/print")
    g.add("uri-security-supported", V.KEYWORD, "tls" if ipp_url.startswith("ipps") else "none")
    g.add("uri-authentication-supported", V.KEYWORD, "none")
    g.add("printer-name", V.NAME, "Simulated C7130")
    g.add("printer-info", V.TEXT, "PrinterHub simulator")
    g.add("printer-make-and-model", V.TEXT, s.MODEL)
    g.add("printer-device-id", V.TEXT, "MFG:Xerox;MDL:VersaLink C7130;CMD:PDF,URF,PWGRaster;")
    g.add("printer-uuid", V.URI, f"urn:uuid:{printer.uuid}")
    g.add("printer-more-info", V.URI, base_url)
    g.add("printer-state", V.ENUM, printer.printer_state())
    g.add("printer-state-reasons", V.KEYWORD, *printer.printer_state_reasons())
    g.add("printer-is-accepting-jobs", V.BOOLEAN, not printer.faults.door_open)
    g.add("queued-job-count", V.INTEGER, len(_active_jobs(printer)))
    g.add("ipp-versions-supported", V.KEYWORD, "1.1", "2.0")
    g.add("operations-supported", V.ENUM, *(int(operation) for operation in Operation))
    g.add("charset-configured", V.CHARSET, "utf-8")
    g.add("charset-supported", V.CHARSET, "utf-8")
    g.add("natural-language-configured", V.NATURAL_LANGUAGE, "en")
    g.add("document-format-supported", V.MIME_MEDIA_TYPE, *DOCUMENT_FORMATS)
    g.add("document-format-default", V.MIME_MEDIA_TYPE, "application/pdf")
    g.add("color-supported", V.BOOLEAN, True)
    g.add("print-color-mode-supported", V.KEYWORD, "auto", "color", "monochrome")
    g.add("print-color-mode-default", V.KEYWORD, "auto")
    g.add("sides-supported", V.KEYWORD, "one-sided", "two-sided-long-edge", "two-sided-short-edge")
    g.add("sides-default", V.KEYWORD, "one-sided")
    g.add("media-supported", V.KEYWORD, *MEDIA)
    g.add("media-default", V.KEYWORD, MEDIA[0])
    g.add("media-source-supported", V.KEYWORD, "auto", "tray-1", "tray-2", "by-pass-tray")
    g.add("copies-supported", V.RANGE_OF_INTEGER, (1, MAX_COPIES))
    g.add("copies-default", V.INTEGER, 1)
    g.add(
        "printer-resolution-supported",
        V.RESOLUTION,
        (600, 600, _DOTS_PER_INCH),
        (1200, 1200, _DOTS_PER_INCH),
    )
    g.add("print-quality-supported", V.ENUM, 3, 4, 5)
    g.add("finishings-supported", V.ENUM, 3)
    g.add("marker-names", V.NAME, *(f"{color.capitalize()} Toner" for color in colors))
    g.add("marker-colors", V.NAME, *colors)
    g.add("marker-types", V.KEYWORD, *("toner" for _ in colors))
    g.add("marker-levels", V.INTEGER, *(printer.toner[color] for color in colors))
    return g


def _active_jobs(printer: PrinterState) -> list[PrintJob]:
    done = (s.JOB_COMPLETED, s.JOB_CANCELED)
    return [job for job in printer.print_jobs.values() if printer.job_state(job) not in done]


def _job_attributes(printer: PrinterState, job: PrintJob, base_url: str) -> Group:
    ipp_url = base_url.replace("http://", "ipp://").replace("https://", "ipps://")
    g = Group(GroupTag.JOB)
    g.add("job-id", V.INTEGER, job.id)
    g.add("job-uri", V.URI, f"{ipp_url}/ipp/print/{job.id}")
    g.add("job-state", V.ENUM, printer.job_state(job))
    g.add("job-state-reasons", V.KEYWORD, *printer.job_state_reasons(job))
    g.add("job-name", V.NAME, job.name)
    g.add("job-originating-user-name", V.NAME, job.user)
    g.add("job-k-octets", V.INTEGER, max(1, job.size_bytes // 1024))
    g.add("copies", V.INTEGER, job.copies)
    return g


def _text(group: Group | None, name: str) -> str | None:
    value = group.first(name) if group else None
    return value if isinstance(value, str) else None


def _validate(request: Message) -> tuple[Status, str] | None:
    operation = request.group(GroupTag.OPERATION)
    job = request.group(GroupTag.JOB)
    document_format = _text(operation, "document-format")
    if document_format is not None and document_format not in DOCUMENT_FORMATS:
        return (
            Status.CLIENT_ERROR_DOCUMENT_FORMAT_NOT_SUPPORTED,
            f"Unsupported document format: {document_format}",
        )
    copies = job.first("copies") if job else None
    if isinstance(copies, int) and not 1 <= copies <= MAX_COPIES:
        return Status.CLIENT_ERROR_BAD_REQUEST, f"copies must be between 1 and {MAX_COPIES}"
    media = _text(job, "media")
    if media is not None and media not in MEDIA:
        return Status.CLIENT_ERROR_NOT_POSSIBLE, f"Unsupported media: {media}"
    return None


def _find_job(request: Message, printer: PrinterState) -> PrintJob | None:
    operation = request.group(GroupTag.OPERATION)
    if operation is None:
        return None
    job_id = operation.first("job-id")
    if job_id is None:
        job_uri = str(operation.first("job-uri") or "")
        tail = job_uri.rsplit("/", 1)[-1]
        job_id = int(tail) if tail.isdigit() else None
    return printer.print_jobs.get(job_id) if isinstance(job_id, int) else None


def handle(request: Message, printer: PrinterState, base_url: str) -> Message:
    """Run one IPP operation against the simulated printer."""
    if printer.faults.offline:
        return _error(request, Status.SERVER_ERROR_SERVICE_UNAVAILABLE, "Printer is offline")

    if request.code == Operation.GET_PRINTER_ATTRIBUTES:
        response = _response(request, Status.OK)
        response.groups.append(_filter(_printer_attributes(printer, base_url), _requested(request)))
        return response

    if request.code in (Operation.VALIDATE_JOB, Operation.PRINT_JOB):
        problem = _validate(request)
        if problem is not None:
            return _error(request, *problem)
        if request.code == Operation.VALIDATE_JOB:
            return _response(request, Status.OK)
        if printer.faults.door_open:
            return _error(
                request, Status.SERVER_ERROR_SERVICE_UNAVAILABLE, "Close the front door to print"
            )
        if not request.data:
            return _error(request, Status.CLIENT_ERROR_BAD_REQUEST, "Print-Job carried no document")
        operation = request.group(GroupTag.OPERATION)
        job_group = request.group(GroupTag.JOB)
        copies = job_group.first("copies") if job_group else None
        job = printer.new_print_job(
            name=_text(operation, "job-name") or "Untitled",
            user=_text(operation, "requesting-user-name") or "anonymous",
            document_format=_text(operation, "document-format") or "application/octet-stream",
            copies=copies if isinstance(copies, int) else 1,
            size_bytes=len(request.data),
        )
        response = _response(request, Status.OK)
        response.groups.append(_job_attributes(printer, job, base_url))
        return response

    if request.code == Operation.GET_JOBS:
        which = _text(request.group(GroupTag.OPERATION), "which-jobs")
        active = _active_jobs(printer)
        jobs = (
            [job for job in printer.print_jobs.values() if job not in active]
            if which == "completed"
            else active
        )
        response = _response(request, Status.OK)
        wanted = _requested(request)
        response.groups += [
            _filter(_job_attributes(printer, job, base_url), wanted) for job in jobs
        ]
        return response

    if request.code in (Operation.GET_JOB_ATTRIBUTES, Operation.CANCEL_JOB):
        found = _find_job(request, printer)
        if found is None:
            return _error(request, Status.CLIENT_ERROR_NOT_FOUND, "No such job")
        if request.code == Operation.CANCEL_JOB:
            if printer.job_state(found) in (s.JOB_COMPLETED, s.JOB_CANCELED):
                return _error(
                    request, Status.CLIENT_ERROR_NOT_POSSIBLE, "The job has already finished"
                )
            found.canceled = True
            return _response(request, Status.OK)
        response = _response(request, Status.OK)
        response.groups.append(
            _filter(_job_attributes(printer, found, base_url), _requested(request))
        )
        return response

    return _error(
        request,
        Status.SERVER_ERROR_OPERATION_NOT_SUPPORTED,
        f"Operation 0x{request.code:04x} is not supported",
    )
