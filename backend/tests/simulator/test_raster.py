from pathlib import Path

import pytest

from simulator import raster

FIXTURES = Path(__file__).parent / "fixtures"
"""Two pages of 40 by 30 pixels (`*.raw`), as written by the `rastertopwg` filter of macOS."""


@pytest.mark.parametrize(
    ("name", "bytes_per_pixel"),
    [("rgb.pwg", 3), ("rgb.urf", 3), ("gray.pwg", 1), ("gray.urf", 1)],
)
def test_reads_what_the_system_filter_writes(name: str, bytes_per_pixel: int) -> None:
    pages = raster.read((FIXTURES / name).read_bytes())

    assert [(p.width, p.height, p.bytes_per_pixel, p.resolution) for p in pages] == [
        (40, 30, bytes_per_pixel, 300)
    ] * 2
    raw = (FIXTURES / f"{name.split('.')[0]}.raw").read_bytes()
    assert b"".join(page.pixels for page in pages) == raw


def test_counts_pages_without_keeping_them() -> None:
    pages = raster.read((FIXTURES / "rgb.pwg").read_bytes(), keep_pixels=False)

    assert len(pages) == 2
    assert pages[0].pixels == b""


def _urf(*, pages: int = 1, body: bytes = b"\x00\x00\x07", width: int = 1) -> bytes:
    header = bytes([8, 0, 1, 0]) + bytes(8) + width.to_bytes(4) + (1).to_bytes(4)
    return b"UNIRAST\x00" + pages.to_bytes(4) + header + (300).to_bytes(4) + bytes(8) + body


def test_apple_raster_fills_the_rest_of_a_line_with_white() -> None:
    page = raster.read(_urf(width=4, body=b"\x00\x00\x09\x80"))[0]

    assert page.pixels == b"\x09\xff\xff\xff"


@pytest.mark.parametrize(
    ("data", "reason"),
    [
        (b"%PDF-1.7", "neither"),
        (b"RaS2", "no pages"),
        (b"RaS2" + b"NotRaster\x00" + bytes(1786), "PwgRaster"),
        (_urf(body=b""), "ends early"),
        (_urf(body=b"\x00\x05"), "middle of a line"),
        (_urf(body=b"\x00\x01\x07"), "more pixels"),
        (_urf(body=b"\x01\x00\x07"), "more lines"),
        (_urf(pages=3), "promises 3 pages"),
        (_urf() + b"\x08", "middle of a page header"),
        (_urf(width=0), "0 by 1"),
        (b"UNIRAST\x00" + bytes(4) + bytes([16]) + bytes(31), "bits per pixel"),
    ],
)
def test_refuses_what_a_printer_could_not_print(data: bytes, reason: str) -> None:
    with pytest.raises(raster.RasterError, match=reason):
        raster.read(data)


def test_refuses_a_pwg_header_that_contradicts_itself() -> None:
    good = bytearray((FIXTURES / "gray.pwg").read_bytes())

    def broken(offset: int, value: int) -> bytes:
        copy = bytearray(good)
        copy[4 + offset : 4 + offset + 4] = value.to_bytes(4)
        return bytes(copy)

    with pytest.raises(raster.RasterError, match="bits per colour"):
        raster.read(broken(384, 1))
    with pytest.raises(raster.RasterError, match="BytesPerLine"):
        raster.read(broken(392, 7))
    with pytest.raises(raster.RasterError, match="across and down"):
        raster.read(broken(280, 600))
    with pytest.raises(raster.RasterError, match="resolution is zero"):
        raster.read(_zero_resolution(good))
    with pytest.raises(raster.RasterError, match="0x80"):
        raster.read(bytes(good[: 4 + 1796]) + b"\x00\x80")


def _zero_resolution(good: bytearray) -> bytes:
    copy = bytearray(good)
    copy[4 + 276 : 4 + 284] = bytes(8)
    return bytes(copy)
