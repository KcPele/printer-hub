import struct

import pytest

from simulator.ipp import (
    Group,
    GroupTag,
    IppDecodeError,
    Message,
    Operation,
    ValueTag,
    decode,
    encode,
)


def _attribute(tag: int, name: str, value: bytes) -> bytes:
    return (
        bytes([tag])
        + struct.pack(">H", len(name))
        + name.encode()
        + struct.pack(">H", len(value))
        + value
    )


# A Get-Printer-Attributes request assembled by hand from RFC 8010 §3,
# so the codec is checked against the wire format and not only against itself.
HAND_BUILT = (
    b"\x02\x00"  # version 2.0
    b"\x00\x0b"  # operation: Get-Printer-Attributes
    b"\x00\x00\x00\x2a"  # request-id 42
    b"\x01"  # operation-attributes-tag
    + _attribute(0x47, "attributes-charset", b"utf-8")
    + _attribute(0x48, "attributes-natural-language", b"en")
    + _attribute(0x45, "printer-uri", b"ipp://printer.local/ipp/print")
    + _attribute(0x44, "requested-attributes", b"printer-state")
    + _attribute(0x44, "", b"printer-make-and-model")  # additional value: empty name
    + b"\x03"  # end-of-attributes-tag
)


def test_decode_hand_built_request() -> None:
    message = decode(HAND_BUILT)

    assert message.version == (2, 0)
    assert message.code == Operation.GET_PRINTER_ATTRIBUTES
    assert message.request_id == 42
    operation = message.group(GroupTag.OPERATION)
    assert operation is not None
    assert operation.first("attributes-charset") == "utf-8"
    assert operation.get("requested-attributes") == ("printer-state", "printer-make-and-model")
    assert message.data == b""


def test_encode_produces_the_hand_built_bytes() -> None:
    group = Group(GroupTag.OPERATION)
    group.add("attributes-charset", ValueTag.CHARSET, "utf-8")
    group.add("attributes-natural-language", ValueTag.NATURAL_LANGUAGE, "en")
    group.add("printer-uri", ValueTag.URI, "ipp://printer.local/ipp/print")
    group.add("requested-attributes", ValueTag.KEYWORD, "printer-state", "printer-make-and-model")

    assert encode(Message(Operation.GET_PRINTER_ATTRIBUTES, 42, [group])) == HAND_BUILT


def test_round_trip_of_every_value_type_and_document_data() -> None:
    job = Group(GroupTag.JOB)
    job.add("copies", ValueTag.INTEGER, 3)
    job.add("print-quality", ValueTag.ENUM, 5)
    job.add("color-supported", ValueTag.BOOLEAN, True)
    job.add("copies-supported", ValueTag.RANGE_OF_INTEGER, (1, 999))
    job.add("printer-resolution", ValueTag.RESOLUTION, (600, 600, 3))
    job.add("job-name", ValueTag.NAME, "Invoice é.pdf")
    job.add("job-password", ValueTag.OCTET_STRING, b"\x00\x01\x02")
    job.add("negative", ValueTag.INTEGER, -1)
    message = Message(Operation.PRINT_JOB, 9, [job], data=b"%PDF-1.7\x03 body with a 0x03 byte")

    decoded = decode(encode(message))

    assert decoded.groups == [job]
    assert decoded.data == message.data
    assert decoded.code == Operation.PRINT_JOB


@pytest.mark.parametrize(
    "data",
    [b"", b"\x02\x00\x00\x0b", HAND_BUILT[:-1], HAND_BUILT[:30]],
    ids=["empty", "short-header", "missing-end-tag", "cut-mid-attribute"],
)
def test_truncated_messages_are_rejected(data: bytes) -> None:
    with pytest.raises(IppDecodeError):
        decode(data)
