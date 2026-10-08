"""Document bytes the simulator returns for scans."""

import base64


def make_pdf(lines: list[str]) -> bytes:
    """A valid single-page A4 PDF showing `lines` of text."""

    def escape(text: str) -> str:
        return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    text = ["BT", "/F1 18 Tf", "72 760 Td", "24 TL"]
    text += [f"({escape(line)}) Tj T*" for line in lines]
    text.append("ET")
    stream = "\n".join(text).encode("latin-1", errors="replace")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    xref_at = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets:
        out += b"%010d 00000 n \n" % offset
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objects) + 1,
        xref_at,
    )
    return bytes(out)


# A scanned page: a grey heading and lines of "text" on white, 248 by 350.
PAGE_JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQAASABIAAD/wAALCAFeAPgBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QA"
    "tRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0"
    "NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2"
    "t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9sAQwAEBAQEBAQGBAQGCQYGBgkMCQkJCQwP"
    "DAwMDAwPEg8PDw8PDxISEhISEhISFRUVFRUVGRkZGRkcHBwcHBwcHBwc/90ABAAf/9oACAEBAAA/APv6iiiiiiiiiiii"
    "iiiiiiiiiiiiiiiiiiv/0Pv6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/0fv6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/"
    "0vv6iivij/hsP/qUf/J//wC5qP8AhsP/AKlH/wAn/wD7mo/4bD/6lH/yf/8Auaj/AIbD/wCpR/8AJ/8A+5qP+Gw/+pR/"
    "8n//ALmo/wCGw/8AqUf/ACf/APuaj/hsP/qUf/J//wC5qP8AhsP/AKlH/wAn/wD7mo/4bD/6lH/yf/8Auaj/AIbD/wCp"
    "R/8AJ/8A+5qP+Gw/+pR/8n//ALmo/wCGw/8AqUf/ACf/APuaj/hsP/qUf/J//wC5qP8AhsP/AKlH/wAn/wD7mo/4bD/6"
    "lH/yf/8Auau2+HX7SX/CfeMtP8Jf8I79g+3+b+/+1+bs8qJ5fueSmc7MfeGM59q+oaKKKKKKKKKKK//T+/qKK/FGiiii"
    "iiiiiiiiiivbP2df+Sx+H/8At7/9JJq/UKiiiiiiiiiiiv/U+/qKK+KP+GPP+pu/8kP/ALpo/wCGPP8Aqbv/ACQ/+6aP"
    "+GPP+pu/8kP/ALpo/wCGPP8Aqbv/ACQ/+6aP+GPP+pu/8kP/ALpo/wCGPP8Aqbv/ACQ/+6aP+GPP+pu/8kP/ALpo/wCG"
    "PP8Aqbv/ACQ/+6aP+GPP+pu/8kP/ALpo/wCGPP8Aqbv/ACQ/+6aP+GPP+pu/8kP/ALpo/wCGPP8Aqbv/ACQ/+6aP+GPP"
    "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"
    "9x//ABuj/hU/h3/n4vP++4//AI3R/wAKn8O/8/F5/wB9x/8Axuj/AIVP4d/5+Lz/AL7j/wDjdH/Cp/Dv/Pxef99x/wDx"
    "uj/hU/h3/n4vP++4/wD43R/wqfw7/wA/F5/33H/8bo/4VP4d/wCfi8/77j/+N0f8Kn8O/wDPxef99x//ABuj/hU/h3/n"
    "4vP++4//AI3R/wAKn8O/8/F5/wB9x/8Axuj/AIVP4d/5+Lz/AL7j/wDjdH/Cp/Dv/Pxef99x/wDxuj/hU/h3/n4vP++4"
    "/wD43R/wqfw7/wA/F5/33H/8bo/4VP4d/wCfi8/77j/+N0f8Kn8O/wDPxef99x//ABuj/hU/h3/n4vP++4//AI3R/wAK"
    "n8O/8/F5/wB9x/8Axuj/AIVP4d/5+Lz/AL7j/wDjdH/Cp/Dv/Pxef99x/wDxuj/hU/h3/n4vP++4/wD43Xp9FFf/1Pv6"
    "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/1fv6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/1vv6iiiiiiiiiiiiiiiiiiii"
    "iiiiiiiiiiv/1/v6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/0Pv6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/0fv6iiii"
    "iiiiiiiiiiiiiiiiiiiiiiiiiiv/0vv6iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiv/2Q=="
)
