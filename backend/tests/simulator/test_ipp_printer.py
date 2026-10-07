import httpx

from simulator.ipp import Group, GroupTag, Message, Operation, Status, ValueTag
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
    assert state["print_jobs"] == [{"id": job_id, "name": "Invoice.pdf", "state": 9}]


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
