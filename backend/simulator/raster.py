"""Reads PWG Raster and Apple Raster, to check the pages a client sent to print.

Both formats hold one picture per page. PWG Raster (PWG 5102.4) is what IPP Everywhere and
Mopria printers take; Apple Raster is what AirPrint printers take. They pack pixels the same way.
"""

import struct
from dataclasses import dataclass

PWG_SYNC = b"RaS2"
URF_SYNC = b"UNIRAST\x00"
_PWG_HEADER = 1796
_URF_HEADER = 32
# Larger than any sheet a printer takes at 1200 dpi; guards against a garbage header.
_MAX_PIXELS = 20_000


class RasterError(ValueError):
    """The bytes are not a raster document a printer could print."""


@dataclass(frozen=True, slots=True)
class RasterPage:
    width: int
    height: int
    bytes_per_pixel: int
    resolution: int
    # Empty when the reader was asked not to keep them.
    pixels: bytes


def _header(data: bytes, at: int, pwg: bool) -> tuple[int, int, int, int]:
    """Width, height, bytes per pixel, and resolution of the page whose header is at `at`."""
    if pwg:
        if not data[at : at + 64].startswith(b"PwgRaster\x00"):
            raise RasterError("page header does not start with PwgRaster")
        resolution, down = struct.unpack_from(">II", data, at + 276)
        width, height = struct.unpack_from(">II", data, at + 372)
        bits_per_color, bits_per_pixel, bytes_per_line = struct.unpack_from(">III", data, at + 384)
        if bits_per_color != 8:
            raise RasterError(f"{bits_per_color} bits per colour is not supported")
        if bytes_per_line != width * bits_per_pixel // 8:
            raise RasterError("BytesPerLine does not match the width")
        if resolution != down:
            raise RasterError("resolution differs across and down")
    else:
        bits_per_pixel = data[at]
        width, height, resolution = struct.unpack_from(">III", data, at + 12)
    if bits_per_pixel not in (8, 24):
        raise RasterError(f"{bits_per_pixel} bits per pixel is not supported")
    if not (0 < width <= _MAX_PIXELS and 0 < height <= _MAX_PIXELS):
        raise RasterError(f"page of {width} by {height} pixels")
    if resolution <= 0:
        raise RasterError("resolution is zero")
    return width, height, bits_per_pixel // 8, resolution


def _line(data: bytes, at: int, width: int, size: int, pwg: bool) -> tuple[bytes, int]:
    """One packed line starting at `at`: its pixels, and where the next thing starts."""
    out = bytearray()
    while len(out) < width * size:
        code = data[at]
        at += 1
        if code == 0x80:
            if pwg:
                raise RasterError("0x80 is not a count in PWG Raster")
            # Apple Raster: the rest of the line is white.
            out += b"\xff" * (width * size - len(out))
            break
        count = code + 1 if code < 0x80 else 257 - code
        length = size if code < 0x80 else count * size
        chunk = data[at : at + length]
        if len(chunk) != length:
            raise RasterError("the document ends in the middle of a line")
        at += length
        out += chunk * count if code < 0x80 else chunk
    if len(out) != width * size:
        raise RasterError("a line holds more pixels than the page is wide")
    return bytes(out), at


def read(data: bytes, *, keep_pixels: bool = True) -> list[RasterPage]:
    """The pages of a PWG Raster or Apple Raster document. Raises `RasterError` on anything else."""
    if data.startswith(PWG_SYNC):
        pwg, at, header_length = True, len(PWG_SYNC), _PWG_HEADER
    elif data.startswith(URF_SYNC):
        pwg, at, header_length = False, len(URF_SYNC) + 4, _URF_HEADER
    else:
        raise RasterError("neither PWG Raster nor Apple Raster")

    pages: list[RasterPage] = []
    try:
        while at < len(data):
            if at + header_length > len(data):
                raise RasterError("the document ends in the middle of a page header")
            width, height, size, resolution = _header(data, at, pwg)
            at += header_length
            rows: list[bytes] = []
            row = 0
            while row < height:
                repeats = data[at] + 1
                line, at = _line(data, at + 1, width, size, pwg)
                if row + repeats > height:
                    raise RasterError("more lines than the page is high")
                if keep_pixels:
                    rows.extend([line] * repeats)
                row += repeats
            pages.append(RasterPage(width, height, size, resolution, b"".join(rows)))
    except (IndexError, struct.error) as exc:
        raise RasterError("the document ends early") from exc

    if not pages:
        raise RasterError("the document has no pages")
    if not pwg:
        (declared,) = struct.unpack_from(">I", data, len(URF_SYNC))
        if declared not in (0, len(pages)):
            raise RasterError(
                f"the header promises {declared} pages, the document has {len(pages)}"
            )
    return pages
