"""IPP binary encoding and decoding (RFC 8010), limited to what the simulator needs."""

import enum
import struct
from dataclasses import dataclass, field

IppScalar = int | bool | str | bytes | tuple[int, ...]


class GroupTag(enum.IntEnum):
    OPERATION = 0x01
    JOB = 0x02
    END = 0x03
    PRINTER = 0x04
    UNSUPPORTED = 0x05


class ValueTag(enum.IntEnum):
    NO_VALUE = 0x13
    INTEGER = 0x21
    BOOLEAN = 0x22
    ENUM = 0x23
    OCTET_STRING = 0x30
    RESOLUTION = 0x32
    RANGE_OF_INTEGER = 0x33
    TEXT = 0x41
    NAME = 0x42
    KEYWORD = 0x44
    URI = 0x45
    CHARSET = 0x47
    NATURAL_LANGUAGE = 0x48
    MIME_MEDIA_TYPE = 0x49


class Operation(enum.IntEnum):
    PRINT_JOB = 0x0002
    VALIDATE_JOB = 0x0004
    CANCEL_JOB = 0x0008
    GET_JOB_ATTRIBUTES = 0x0009
    GET_JOBS = 0x000A
    GET_PRINTER_ATTRIBUTES = 0x000B


class Status(enum.IntEnum):
    OK = 0x0000
    CLIENT_ERROR_BAD_REQUEST = 0x0400
    CLIENT_ERROR_NOT_POSSIBLE = 0x0404
    CLIENT_ERROR_NOT_FOUND = 0x0406
    CLIENT_ERROR_DOCUMENT_FORMAT_NOT_SUPPORTED = 0x040A
    SERVER_ERROR_OPERATION_NOT_SUPPORTED = 0x0501
    SERVER_ERROR_SERVICE_UNAVAILABLE = 0x0502


class IppDecodeError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class Attribute:
    name: str
    tag: int
    values: tuple[IppScalar, ...]


@dataclass(slots=True)
class Group:
    tag: int
    attributes: list[Attribute] = field(default_factory=list)

    def add(self, name: str, tag: int, *values: IppScalar) -> Group:
        self.attributes.append(Attribute(name, tag, values))
        return self

    def get(self, name: str) -> tuple[IppScalar, ...] | None:
        for attribute in self.attributes:
            if attribute.name == name:
                return attribute.values
        return None

    def first(self, name: str) -> IppScalar | None:
        values = self.get(name)
        return values[0] if values else None


@dataclass(slots=True)
class Message:
    """An IPP request or response. `code` is the operation ID or the status code."""

    code: int
    request_id: int
    groups: list[Group] = field(default_factory=list)
    data: bytes = b""
    version: tuple[int, int] = (2, 0)

    def group(self, tag: int) -> Group | None:
        return next((group for group in self.groups if group.tag == tag), None)


_INTEGER_TAGS = (ValueTag.INTEGER, ValueTag.ENUM)


def _encode_value(tag: int, value: IppScalar) -> bytes:
    if tag in _INTEGER_TAGS:
        return struct.pack(">i", value)
    if tag == ValueTag.BOOLEAN:
        return b"\x01" if value else b"\x00"
    if tag == ValueTag.RANGE_OF_INTEGER:
        assert isinstance(value, tuple)  # noqa: S101
        return struct.pack(">ii", *value)
    if tag == ValueTag.RESOLUTION:
        assert isinstance(value, tuple)  # noqa: S101
        return struct.pack(">iib", *value)
    if tag == ValueTag.NO_VALUE:
        return b""
    if isinstance(value, bytes):
        return value
    return str(value).encode()


def _decode_value(tag: int, raw: bytes) -> IppScalar:
    try:
        if tag in _INTEGER_TAGS:
            return int(struct.unpack(">i", raw)[0])
        if tag == ValueTag.BOOLEAN:
            return raw != b"\x00"
        if tag == ValueTag.RANGE_OF_INTEGER:
            return tuple(struct.unpack(">ii", raw))
        if tag == ValueTag.RESOLUTION:
            return tuple(struct.unpack(">iib", raw))
    except struct.error as exc:
        raise IppDecodeError(f"bad value for tag 0x{tag:02x}") from exc
    if tag == ValueTag.OCTET_STRING:
        return raw
    return raw.decode(errors="replace")


def encode(message: Message) -> bytes:
    out = bytearray(struct.pack(">bbHi", *message.version, message.code, message.request_id))
    for group in message.groups:
        out.append(group.tag)
        for attribute in group.attributes:
            for index, value in enumerate(attribute.values):
                # Additional values of a multi-valued attribute carry an empty name.
                name = attribute.name.encode() if index == 0 else b""
                encoded = _encode_value(attribute.tag, value)
                out.append(attribute.tag)
                out += struct.pack(">H", len(name)) + name
                out += struct.pack(">H", len(encoded)) + encoded
    out.append(GroupTag.END)
    return bytes(out) + message.data


def decode(data: bytes) -> Message:
    if len(data) < 9:
        raise IppDecodeError("message shorter than the IPP header")
    major, minor, code, request_id = struct.unpack(">bbHi", data[:8])
    message = Message(code=code, request_id=request_id, version=(major, minor))
    position = 8
    group: Group | None = None
    pending: tuple[str, int, list[IppScalar]] | None = None

    def flush() -> None:
        nonlocal pending
        if pending is not None and group is not None:
            name, tag, values = pending
            group.attributes.append(Attribute(name, tag, tuple(values)))
        pending = None

    try:
        while True:
            tag = data[position]
            position += 1
            if tag == GroupTag.END:
                flush()
                break
            if tag < 0x10:  # delimiter: a new attribute group begins
                flush()
                group = Group(tag)
                message.groups.append(group)
                continue
            (name_length,) = struct.unpack(">H", data[position : position + 2])
            position += 2
            name = data[position : position + name_length].decode()
            position += name_length
            (value_length,) = struct.unpack(">H", data[position : position + 2])
            position += 2
            raw = data[position : position + value_length]
            if len(raw) != value_length:
                raise IppDecodeError("truncated attribute value")
            position += value_length
            value = _decode_value(tag, raw)
            if name_length == 0 and pending is not None:
                pending[2].append(value)
            else:
                flush()
                pending = (name, tag, [value])
    except (IndexError, struct.error) as exc:
        raise IppDecodeError("truncated message") from exc

    message.data = data[position:]
    return message
