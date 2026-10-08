import base64
import hashlib
from pathlib import Path

import httpx
import pytest

from simulator.ipp import Group, GroupTag, Message, Operation, Status, ValueTag, decode
from tests.simulator.conftest import ipp_request, send_ipp

PDF = b"%PDF-1.7 pretend document"
KEYWORD = ValueTag.KEYWORD
INTEGER = ValueTag.INTEGER


async def _print(
    sim: httpx.AsyncClient, *, copies: int = 1, **attributes: tuple[int, object]
) -> int:
    job = Group(GroupTag.JOB).add("copies", INTEGER, copies)
    response = await send_ipp(
        sim,
        ipp_request(
            Operation.PRINT_JOB,
            job=job,
            data=PDF,
            job_name=(ValueTag.NAME, "Invoice.pdf"),
            document_format=(ValueTag.MIME_MEDIA_TYPE, "application/pdf"),
            **attributes,
        ),
    )
    assert response.code == Status.OK
    job_group = response.group(GroupTag.JOB)
    assert job_group is not None
    job_id = job_group.first("job-id")
    assert isinstance(job_id, int)
    return job_id


async def _job_state(sim: httpx.AsyncClient, job_id: int) -> tuple[object, object]:
    response = await send_ipp(
        sim, ipp_request(Operation.GET_JOB_ATTRIBUTES, job_id=(INTEGER, job_id))
    )
    group = response.group(GroupTag.JOB)
    assert group is not None
    return group.first("job-state"), group.first("job-state-reasons")


async def test_printer_identifies_as_a_c7130(sim: httpx.AsyncClient) -> None:
    response = await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))

    assert response.code == Status.OK
    assert response.request_id == 7
    printer = response.group(GroupTag.PRINTER)
    assert printer is not None
    assert printer.first("printer-make-and-model") == "Xerox VersaLink C7130"
    assert printer.first("printer-state") == 3  # idle
    assert printer.get("printer-state-reasons") == ("none",)
    assert printer.first("color-supported") is True
    assert "two-sided-long-edge" in (printer.get("sides-supported") or ())
    assert "iso_a3_297x420mm" in (printer.get("media-supported") or ())
    assert printer.first("copies-supported") == (1, 999)
    assert printer.get("marker-colors") == ("black", "cyan", "magenta", "yellow")
    assert printer.get("marker-levels") == (82, 64, 71, 58)
    assert printer.first("printer-uri-supported") == "ipp://printer.local/ipp/print"


async def test_requested_attributes_limit_the_answer(sim: httpx.AsyncClient) -> None:
    response = await send_ipp(
        sim,
        ipp_request(
            Operation.GET_PRINTER_ATTRIBUTES,
            requested_attributes=(KEYWORD, ["printer-state", "marker-levels"]),
        ),
    )

    printer = response.group(GroupTag.PRINTER)
    assert printer is not None
    assert [attribute.name for attribute in printer.attributes] == [
        "printer-state",
        "marker-levels",
    ]


async def test_print_job_runs_to_completion(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"job_duration_seconds": 0})

    job_id = await _print(sim, copies=2)

    assert await _job_state(sim, job_id) == (9, "job-completed-successfully")
    state = (await sim.get("/sim/state")).json()
    assert state["print_jobs"] == [
        {
            "id": job_id,
            "name": "Invoice.pdf",
            "user": "anonymous",
            "state": 9,
            "document_format": "application/pdf",
            "size_bytes": len(PDF),
            "pages": None,
        }
    ]


async def test_pending_job_can_be_cancelled_once(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"job_duration_seconds": 3600})
    job_id = await _print(sim)
    assert (await _job_state(sim, job_id))[0] == 3  # pending

    cancelled = await send_ipp(sim, ipp_request(Operation.CANCEL_JOB, job_id=(INTEGER, job_id)))
    again = await send_ipp(sim, ipp_request(Operation.CANCEL_JOB, job_id=(INTEGER, job_id)))

    assert cancelled.code == Status.OK
    assert await _job_state(sim, job_id) == (7, "job-canceled-by-user")
    assert again.code == Status.CLIENT_ERROR_NOT_POSSIBLE


async def test_get_jobs_separates_active_from_finished(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"job_duration_seconds": 0})
    finished = await _print(sim)
    await sim.patch("/sim/state", json={"job_duration_seconds": 3600})
    active = await _print(sim)

    not_completed = await send_ipp(sim, ipp_request(Operation.GET_JOBS))
    completed = await send_ipp(
        sim, ipp_request(Operation.GET_JOBS, which_jobs=(KEYWORD, "completed"))
    )

    def job_ids(message: Message) -> list[object]:
        return [group.first("job-id") for group in message.groups if group.tag == GroupTag.JOB]

    assert job_ids(not_completed) == [active]
    assert job_ids(completed) == [finished]


async def test_validation_errors(sim: httpx.AsyncClient) -> None:
    bad_format = await send_ipp(
        sim,
        ipp_request(
            Operation.VALIDATE_JOB,
            document_format=(ValueTag.MIME_MEDIA_TYPE, "application/msword"),
        ),
    )
    bad_media = await send_ipp(
        sim,
        ipp_request(
            Operation.PRINT_JOB,
            job=Group(GroupTag.JOB).add("media", KEYWORD, "iso_b0_1000x1414mm"),
            data=PDF,
        ),
    )
    too_many = await send_ipp(
        sim,
        ipp_request(Operation.VALIDATE_JOB, job=Group(GroupTag.JOB).add("copies", INTEGER, 5000)),
    )
    no_document = await send_ipp(sim, ipp_request(Operation.PRINT_JOB))
    valid = await send_ipp(sim, ipp_request(Operation.VALIDATE_JOB))

    assert bad_format.code == Status.CLIENT_ERROR_DOCUMENT_FORMAT_NOT_SUPPORTED
    # The error the FRD uses as its example of one needing translation (FR-ERR-001).
    assert bad_media.code == Status.CLIENT_ERROR_NOT_POSSIBLE
    assert too_many.code == Status.CLIENT_ERROR_BAD_REQUEST
    assert no_document.code == Status.CLIENT_ERROR_BAD_REQUEST
    assert valid.code == Status.OK
    assert (await sim.get("/sim/state")).json()["print_jobs"] == []


async def test_unknown_job_and_unsupported_operation(sim: httpx.AsyncClient) -> None:
    missing = await send_ipp(sim, ipp_request(Operation.GET_JOB_ATTRIBUTES, job_id=(INTEGER, 999)))
    unsupported = await send_ipp(sim, ipp_request(0x0010))  # Pause-Printer

    assert missing.code == Status.CLIENT_ERROR_NOT_FOUND
    assert unsupported.code == Status.SERVER_ERROR_OPERATION_NOT_SUPPORTED


async def test_malformed_request_is_answered_in_ipp(sim: httpx.AsyncClient) -> None:
    response = await sim.post("/ipp/print", content=b"not ipp at all")

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/ipp"
    assert int.from_bytes(response.content[2:4]) == Status.CLIENT_ERROR_BAD_REQUEST


# --- Faults ------------------------------------------------------------------


async def test_paper_jam_stops_the_job_until_cleared(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"job_duration_seconds": 0, "faults": {"paper_jam": True}})

    job_id = await _print(sim)

    assert await _job_state(sim, job_id) == (6, "printer-stopped")
    printer = (await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))).group(
        GroupTag.PRINTER
    )
    assert printer is not None
    assert printer.first("printer-state") == 5  # stopped
    assert printer.get("printer-state-reasons") == ("media-jam-error",)

    await sim.patch("/sim/state", json={"faults": {"paper_jam": False}})
    assert (await _job_state(sim, job_id))[0] == 9


async def test_low_and_empty_toner_are_reported(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"toner": {"black": 4, "cyan": 0}})

    printer = (await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))).group(
        GroupTag.PRINTER
    )

    assert printer is not None
    assert printer.get("marker-levels") == (4, 0, 71, 58)
    assert printer.get("printer-state-reasons") == ("toner-low-warning", "toner-empty-error")


async def test_open_door_refuses_jobs(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"faults": {"door_open": True}})

    response = await send_ipp(sim, ipp_request(Operation.PRINT_JOB, data=PDF))
    printer = (await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))).group(
        GroupTag.PRINTER
    )

    assert response.code == Status.SERVER_ERROR_SERVICE_UNAVAILABLE
    assert printer is not None
    assert printer.first("printer-is-accepting-jobs") is False


async def test_offline_printer_answers_nothing_useful(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"faults": {"offline": True}})

    ipp = await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))
    scanner = await sim.get("/eSCL/ScannerStatus")

    assert ipp.code == Status.SERVER_ERROR_SERVICE_UNAVAILABLE
    assert ipp.group(GroupTag.PRINTER) is None
    assert scanner.status_code == 503


# --- What a client must cope with on other printers ---------------------------

FIXTURES = Path(__file__).parent / "fixtures"
MIME = ValueTag.MIME_MEDIA_TYPE


async def _printer_group(sim: httpx.AsyncClient) -> Group:
    response = await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))
    group = response.group(GroupTag.PRINTER)
    assert group is not None
    return group


async def test_says_which_raster_it_takes(sim: httpx.AsyncClient) -> None:
    printer = await _printer_group(sim)

    assert printer.get("pwg-raster-document-type-supported") == ("sgray_8", "srgb_8")
    assert printer.get("pwg-raster-document-resolution-supported") == ((300, 300, 3), (600, 600, 3))
    assert printer.first("pwg-raster-document-sheet-back") == "rotated"
    assert "RS300-600" in (printer.get("urf-supported") or ())


async def test_can_stand_in_for_a_printer_without_pdf(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"document_formats": ["image/urf", "image/jpeg"]})

    printer = await _printer_group(sim)
    assert printer.get("document-format-supported") == ("image/urf", "image/jpeg")
    assert printer.first("document-format-default") == "image/urf"
    assert printer.get("pwg-raster-document-type-supported") is None

    refused = await send_ipp(
        sim, ipp_request(Operation.VALIDATE_JOB, document_format=(MIME, "application/pdf"))
    )
    assert refused.code == Status.CLIENT_ERROR_DOCUMENT_FORMAT_NOT_SUPPORTED


@pytest.mark.parametrize(
    ("name", "document_format"),
    [("rgb.pwg", "image/pwg-raster"), ("gray.urf", "image/urf")],
)
async def test_counts_the_pages_of_a_raster_document(
    sim: httpx.AsyncClient, name: str, document_format: str
) -> None:
    job = Group(GroupTag.JOB).add("copies", INTEGER, 3)
    response = await send_ipp(
        sim,
        ipp_request(
            Operation.PRINT_JOB,
            job=job,
            data=(FIXTURES / name).read_bytes(),
            document_format=(MIME, document_format),
        ),
    )

    assert response.code == Status.OK
    group = response.group(GroupTag.JOB)
    assert group is not None
    assert group.first("job-impressions") == 6
    printed = (await sim.get("/sim/state")).json()["print_jobs"][0]
    assert printed["pages"] == 2
    assert printed["document_format"] == document_format


@pytest.mark.parametrize(
    "data",
    [
        b"%PDF-1.7 not a raster",
        # The other raster format under the wrong name.
        (FIXTURES / "rgb.urf").read_bytes(),
        # Cut off part way through.
        (FIXTURES / "rgb.pwg").read_bytes()[:2000],
    ],
)
async def test_refuses_a_raster_document_it_cannot_read(
    sim: httpx.AsyncClient, data: bytes
) -> None:
    response = await send_ipp(
        sim,
        ipp_request(Operation.PRINT_JOB, data=data, document_format=(MIME, "image/pwg-raster")),
    )

    assert response.code == Status.CLIENT_ERROR_DOCUMENT_FORMAT_ERROR
    assert (await sim.get("/sim/state")).json()["print_jobs"] == []


async def test_can_stand_in_for_a_printer_that_only_speaks_ipp_1_1(
    sim: httpx.AsyncClient,
) -> None:
    await sim.patch("/sim/state", json={"faults": {"ipp_1_1_only": True}})

    refused = await send_ipp(sim, ipp_request(Operation.GET_PRINTER_ATTRIBUTES))
    assert refused.code == Status.SERVER_ERROR_VERSION_NOT_SUPPORTED
    assert refused.version == (1, 1)

    old = ipp_request(Operation.GET_PRINTER_ATTRIBUTES)
    accepted = await send_ipp(sim, bytes([1, 1]) + old[2:])
    assert accepted.code == Status.OK


async def _post_ipp(sim: httpx.AsyncClient, authorization: str | None = None) -> httpx.Response:
    headers = {"Content-Type": "application/ipp"}
    if authorization is not None:
        headers["Authorization"] = authorization
    return await sim.post(
        "/ipp/print", content=ipp_request(Operation.GET_PRINTER_ATTRIBUTES), headers=headers
    )


async def test_asks_for_a_basic_password(sim: httpx.AsyncClient) -> None:
    await sim.patch(
        "/sim/state", json={"auth": "basic", "auth_user": "ada", "auth_password": "s3cret"}
    )

    asked = await _post_ipp(sim)
    assert asked.status_code == 401
    assert asked.headers["www-authenticate"] == 'Basic realm="PrinterHub simulator"'

    signed = "Basic " + base64.b64encode(b"ada:s3cret").decode()
    accepted = await _post_ipp(sim, signed)
    assert accepted.status_code == 200
    printer = decode(accepted.content).group(GroupTag.PRINTER)
    assert printer is not None
    assert printer.first("uri-authentication-supported") == "basic"

    assert (
        await _post_ipp(sim, "Basic " + base64.b64encode(b"ada:wrong").decode())
    ).status_code == 401
    assert (await _post_ipp(sim, "Digest username=ada")).status_code == 401


async def test_asks_for_a_digest_signature(sim: httpx.AsyncClient) -> None:
    await sim.patch(
        "/sim/state", json={"auth": "digest", "auth_user": "ada", "auth_password": "s3cret"}
    )

    asked = await _post_ipp(sim)
    assert asked.status_code == 401
    challenge = asked.headers["www-authenticate"]
    nonce = challenge.split('nonce="')[1].split('"')[0]
    assert challenge.startswith('Digest realm="PrinterHub simulator"')

    def md5(text: str) -> str:
        return hashlib.md5(text.encode(), usedforsecurity=False).hexdigest()

    def signed(password: str, *, uri: str = "/ipp/print", user: str = "ada") -> str:
        ha1 = md5(f"{user}:PrinterHub simulator:{password}")
        response = md5(f"{ha1}:{nonce}:00000001:abc:auth:{md5(f'POST:{uri}')}")
        return (
            f'Digest username="{user}", realm="PrinterHub simulator", nonce="{nonce}", '
            f'uri="{uri}", qop=auth, nc=00000001, cnonce="abc", response="{response}"'
        )

    assert (await _post_ipp(sim, signed("s3cret"))).status_code == 200
    assert (await _post_ipp(sim, signed("wrong"))).status_code == 401
    assert (await _post_ipp(sim, signed("s3cret", uri="/other"))).status_code == 401
    assert (await _post_ipp(sim, signed("s3cret", user="eve"))).status_code == 401
    assert (await _post_ipp(sim, "Basic YWRhOnMzY3JldA==")).status_code == 401
