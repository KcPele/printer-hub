from collections.abc import AsyncIterator

import httpx
import pytest

from simulator.ipp import Group, GroupTag, Message, ValueTag, decode, encode
from simulator.main import app


@pytest.fixture
async def sim() -> AsyncIterator[httpx.AsyncClient]:
    """A client for a freshly reset simulated printer."""
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://printer.local") as client:
        await client.post("/sim/reset")
        yield client


def ipp_request(
    operation: int,
    *,
    job: Group | None = None,
    data: bytes = b"",
    **operation_attributes: tuple[int, object],
) -> bytes:
    """Encode an IPP request. Attribute keywords use `_` where IPP uses `-`."""
    group = Group(GroupTag.OPERATION)
    group.add("attributes-charset", ValueTag.CHARSET, "utf-8")
    group.add("attributes-natural-language", ValueTag.NATURAL_LANGUAGE, "en")
    group.add("printer-uri", ValueTag.URI, "ipp://printer.local/ipp/print")
    for name, (tag, value) in operation_attributes.items():
        values = value if isinstance(value, list) else [value]
        group.add(name.replace("_", "-"), tag, *values)
    groups = [group] + ([job] if job else [])
    return encode(Message(code=operation, request_id=7, groups=groups, data=data))


async def send_ipp(sim: httpx.AsyncClient, body: bytes) -> Message:
    response = await sim.post(
        "/ipp/print", content=body, headers={"Content-Type": "application/ipp"}
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/ipp"
    return decode(response.content)
