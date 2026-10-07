"""eSCL (AirScan) documents of the simulated scanner."""

import re
import uuid

from simulator.state import MODEL, PrinterState, ScanJob

NAMESPACES = (
    'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
    'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"'
)
FORMATS = ("application/pdf", "image/jpeg")
RESOLUTIONS = (150, 200, 300, 400, 600)
# Scan area in 1/300 inch: A3 on the platen, 297 x 432 mm in the feeder.
_MAX_WIDTH, _MAX_HEIGHT = 3508, 5100


def _input_caps(tag: str) -> str:
    resolutions = "".join(
        f"<scan:DiscreteResolution><scan:XResolution>{r}</scan:XResolution>"
        f"<scan:YResolution>{r}</scan:YResolution></scan:DiscreteResolution>"
        for r in RESOLUTIONS
    )
    formats = "".join(f"<pwg:DocumentFormat>{f}</pwg:DocumentFormat>" for f in FORMATS)
    modes = "".join(
        f"<scan:ColorMode>{mode}</scan:ColorMode>"
        for mode in ("RGB24", "Grayscale8", "BlackAndWhite1")
    )
    return (
        f"<scan:{tag}InputCaps>"
        f"<scan:MinWidth>16</scan:MinWidth><scan:MaxWidth>{_MAX_WIDTH}</scan:MaxWidth>"
        f"<scan:MinHeight>16</scan:MinHeight><scan:MaxHeight>{_MAX_HEIGHT}</scan:MaxHeight>"
        "<scan:SettingProfiles><scan:SettingProfile>"
        f"<scan:ColorModes>{modes}</scan:ColorModes>"
        f"<scan:DocumentFormats>{formats}</scan:DocumentFormats>"
        "<scan:SupportedResolutions><scan:DiscreteResolutions>"
        f"{resolutions}"
        "</scan:DiscreteResolutions></scan:SupportedResolutions>"
        "</scan:SettingProfile></scan:SettingProfiles>"
        f"</scan:{tag}InputCaps>"
    )


def capabilities(printer: PrinterState) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f"<scan:ScannerCapabilities {NAMESPACES}>"
        "<pwg:Version>2.63</pwg:Version>"
        f"<pwg:MakeAndModel>{MODEL}</pwg:MakeAndModel>"
        f"<scan:UUID>{printer.uuid}</scan:UUID>"
        f"<scan:Platen>{_input_caps('Platen')}</scan:Platen>"
        "<scan:Adf>"
        f"{_input_caps('AdfSimplex')}"
        f"{_input_caps('AdfDuplex')}"
        "<scan:FeederCapacity>130</scan:FeederCapacity>"
        "<scan:AdfOptions><scan:AdfOption>DetectPaperLoaded</scan:AdfOption>"
        "<scan:AdfOption>Duplex</scan:AdfOption></scan:AdfOptions>"
        "</scan:Adf>"
        "</scan:ScannerCapabilities>"
    )


def adf_state(printer: PrinterState) -> str:
    if printer.faults.paper_jam:
        return "ScannerAdfJam"
    return "ScannerAdfEmpty" if printer.faults.adf_empty else "ScannerAdfLoaded"


def status(printer: PrinterState) -> str:
    jobs = "".join(
        "<scan:JobInfo>"
        f"<pwg:JobUri>/eSCL/ScanJobs/{job.id}</pwg:JobUri>"
        f"<pwg:JobUuid>{job.id}</pwg:JobUuid>"
        f"<pwg:ImagesCompleted>{job.pages_served}</pwg:ImagesCompleted>"
        f"<pwg:ImagesToTransfer>{job.pages_total - job.pages_served}</pwg:ImagesToTransfer>"
        f"<pwg:JobState>{'Completed' if job.pages_served >= job.pages_total else 'Processing'}"
        "</pwg:JobState></scan:JobInfo>"
        for job in printer.scan_jobs.values()
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f"<scan:ScannerStatus {NAMESPACES}>"
        "<pwg:Version>2.63</pwg:Version>"
        f"<pwg:State>{'Processing' if printer.is_scanning() else 'Idle'}</pwg:State>"
        f"<scan:AdfState>{adf_state(printer)}</scan:AdfState>"
        f"<scan:Jobs>{jobs}</scan:Jobs>"
        "</scan:ScannerStatus>"
    )


def _setting(xml: str, name: str) -> str | None:
    match = re.search(rf"<(?:\w+:)?{name}>\s*([^<]+?)\s*</(?:\w+:)?{name}>", xml)
    return match.group(1) if match else None


class ScanRefused(Exception):
    """The scanner cannot start this job. `status_code` is the HTTP status to return."""

    def __init__(self, status_code: int, reason: str) -> None:
        super().__init__(reason)
        self.status_code = status_code
        self.reason = reason


def create_job(printer: PrinterState, settings_xml: str) -> ScanJob:
    """Start a scan from an eSCL `ScanSettings` document."""
    source = _setting(settings_xml, "InputSource") or "Platen"
    document_format = (
        _setting(settings_xml, "DocumentFormatExt")
        or _setting(settings_xml, "DocumentFormat")
        or "application/pdf"
    )
    resolution = _setting(settings_xml, "XResolution")
    if source not in ("Platen", "Feeder"):
        raise ScanRefused(400, f"Unknown InputSource: {source}")
    if document_format not in FORMATS:
        raise ScanRefused(400, f"Unsupported DocumentFormat: {document_format}")
    if resolution is not None and (not resolution.isdigit() or int(resolution) not in RESOLUTIONS):
        raise ScanRefused(400, f"Unsupported resolution: {resolution}")
    if printer.is_scanning():
        raise ScanRefused(503, "The scanner is busy")
    if source == "Feeder" and printer.faults.paper_jam:
        raise ScanRefused(409, "Paper jam in the document feeder")
    if source == "Feeder" and printer.faults.adf_empty:
        raise ScanRefused(409, "The document feeder is empty")

    job = ScanJob(
        id=str(uuid.uuid4()),
        source=source,
        document_format=document_format,
        pages_total=printer.adf_pages if source == "Feeder" else 1,
    )
    printer.scan_jobs[job.id] = job
    return job
