import xml.etree.ElementTree as ET

import httpx

NS = {
    "scan": "http://schemas.hp.com/imaging/escl/2011/05/03",
    "pwg": "http://www.pwg.org/schemas/2010/12/sm",
}


def _settings(source: str = "Platen", fmt: str = "application/pdf", resolution: int = 300) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
        'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">'
        "<pwg:Version>2.63</pwg:Version>"
        f"<pwg:InputSource>{source}</pwg:InputSource>"
        f"<scan:DocumentFormatExt>{fmt}</scan:DocumentFormatExt>"
        "<scan:ColorMode>RGB24</scan:ColorMode>"
        f"<scan:XResolution>{resolution}</scan:XResolution>"
        f"<scan:YResolution>{resolution}</scan:YResolution>"
        "</scan:ScanSettings>"
    )


async def _start(
    sim: httpx.AsyncClient,
    source: str = "Platen",
    fmt: str = "application/pdf",
    resolution: int = 300,
) -> httpx.Response:
    return await sim.post(
        "/eSCL/ScanJobs",
        content=_settings(source, fmt, resolution),
        headers={"Content-Type": "text/xml"},
    )


def _path(location: str) -> str:
    return location.removeprefix("http://printer.local")


async def test_capabilities_describe_platen_and_feeder(sim: httpx.AsyncClient) -> None:
    response = await sim.get("/eSCL/ScannerCapabilities")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/xml")
    root = ET.fromstring(response.text)  # noqa: S314 - our own simulator's output
    assert root.findtext("pwg:MakeAndModel", namespaces=NS) == "Xerox VersaLink C7130"
    assert root.find("scan:Platen/scan:PlatenInputCaps", NS) is not None
    assert root.find("scan:Adf/scan:AdfSimplexInputCaps", NS) is not None
    assert root.find("scan:Adf/scan:AdfDuplexInputCaps", NS) is not None
    resolutions = [
        int(element.text or 0) for element in root.findall("scan:Platen//scan:XResolution", NS)
    ]
    assert resolutions == [150, 200, 300, 400, 600]
    formats = [e.text for e in root.findall("scan:Platen//pwg:DocumentFormat", NS)]
    assert formats == ["application/pdf", "image/jpeg"]


async def test_platen_scan_delivers_one_page(sim: httpx.AsyncClient) -> None:
    created = await _start(sim)

    assert created.status_code == 201
    job = _path(created.headers["Location"])
    assert job.startswith("/eSCL/ScanJobs/")

    page = await sim.get(f"{job}/NextDocument")
    done = await sim.get(f"{job}/NextDocument")

    assert page.status_code == 200
    assert page.headers["content-type"] == "application/pdf"
    assert page.content.startswith(b"%PDF-1.4")
    assert page.content.rstrip().endswith(b"%%EOF")
    assert b"Page 1 of 1" in page.content
    assert done.status_code == 404


async def test_feeder_scan_delivers_every_page_then_stops(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"adf_pages": 3})
    job = _path((await _start(sim, source="Feeder")).headers["Location"])

    pages = []
    while (response := await sim.get(f"{job}/NextDocument")).status_code == 200:
        pages.append(response.content)

    assert len(pages) == 3
    assert b"Page 3 of 3" in pages[2]
    assert response.status_code == 404


async def test_status_tracks_a_running_scan(sim: httpx.AsyncClient) -> None:
    def state(xml: str) -> tuple[str | None, str | None]:
        root = ET.fromstring(xml)  # noqa: S314
        return root.findtext("pwg:State", namespaces=NS), root.findtext(
            "scan:AdfState", namespaces=NS
        )

    assert state((await sim.get("/eSCL/ScannerStatus")).text) == ("Idle", "ScannerAdfLoaded")

    job = _path((await _start(sim, source="Feeder")).headers["Location"])
    assert state((await sim.get("/eSCL/ScannerStatus")).text)[0] == "Processing"
    busy = await _start(sim)
    assert busy.status_code == 503

    cancelled = await sim.delete(job)
    assert cancelled.status_code == 200
    assert state((await sim.get("/eSCL/ScannerStatus")).text)[0] == "Idle"
    assert (await sim.get(f"{job}/NextDocument")).status_code == 404


async def test_jpeg_output(sim: httpx.AsyncClient) -> None:
    job = _path((await _start(sim, fmt="image/jpeg")).headers["Location"])

    page = await sim.get(f"{job}/NextDocument")

    assert page.headers["content-type"] == "image/jpeg"
    assert page.content[:2] == b"\xff\xd8"  # JPEG start-of-image marker
    assert page.content[-2:] == b"\xff\xd9"  # end-of-image marker


async def test_unsupported_settings_are_rejected(sim: httpx.AsyncClient) -> None:
    assert (await _start(sim, fmt="image/tiff")).status_code == 400
    assert (await _start(sim, resolution=1234)).status_code == 400
    assert (await _start(sim, source="Camera")).status_code == 400


async def test_empty_feeder_refuses_feeder_scans_only(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"faults": {"adf_empty": True}})

    feeder = await _start(sim, source="Feeder")
    platen = await _start(sim, source="Platen")
    status = ET.fromstring((await sim.get("/eSCL/ScannerStatus")).text)  # noqa: S314

    assert feeder.status_code == 409
    assert platen.status_code == 201
    assert status.findtext("scan:AdfState", namespaces=NS) == "ScannerAdfEmpty"


async def test_firmware_without_escl_exposes_no_scanner(sim: httpx.AsyncClient) -> None:
    await sim.patch("/sim/state", json={"faults": {"escl_disabled": True}})

    assert (await sim.get("/eSCL/ScannerCapabilities")).status_code == 404
    assert (await sim.get("/eSCL/ScannerStatus")).status_code == 404
    assert (await _start(sim)).status_code == 404
    # Printing is unaffected.
    assert (await sim.get("/sim/state")).json()["faults"]["escl_disabled"] is True


async def test_reset_restores_factory_state(sim: httpx.AsyncClient) -> None:
    await sim.patch(
        "/sim/state", json={"faults": {"paper_jam": True}, "toner": {"black": 1}, "adf_pages": 9}
    )
    await _start(sim)

    state = (await sim.post("/sim/reset")).json()

    assert state["faults"] == {
        "offline": False,
        "paper_jam": False,
        "door_open": False,
        "adf_empty": False,
        "escl_disabled": False,
    }
    assert state["toner"]["black"] == 82
    assert state["adf_pages"] == 3
    assert state["scan_jobs"] == []


async def test_root_lists_the_endpoints(sim: httpx.AsyncClient) -> None:
    info = (await sim.get("/")).json()

    assert info["model"] == "Xerox VersaLink C7130"
    assert info["ipp"] == "http://printer.local/ipp/print"
    assert info["escl"] == "http://printer.local/eSCL"
