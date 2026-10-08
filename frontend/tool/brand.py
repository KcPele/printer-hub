"""Draws the web app's icons and its share image from the app's own mark.

    python3 frontend/tool/brand.py      (from the repository root; needs Pillow)

It reads the mark the phone app uses (`printerhub/packages/app_ui/assets/brand`
and the store icon) and writes to `frontend/public/`. Run it again when the
mark changes.
"""

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "frontend" / "public"
MINT, INK, MUTED, WHITE = (70, 215, 183), (26, 26, 26), (94, 99, 102), (255, 255, 255)
# Any bold and regular sans will do; this one comes with macOS.
FONT = "/System/Library/Fonts/Avenir Next.ttc"
BOLD, REGULAR = 0, 7


def main() -> None:
    shutil.copy(ROOT / "printerhub/packages/app_ui/assets/brand/tile.svg", OUT / "favicon.svg")
    icon = Image.open(ROOT / "printerhub/android/app/src/main/ic_launcher-playstore.png").convert("RGBA")
    icon.resize((180, 180), Image.LANCZOS).convert("RGB").save(OUT / "apple-touch-icon.png", optimize=True)
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "icon-192.png", optimize=True)
    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png", optimize=True)
    icon.resize((64, 64), Image.LANCZOS).save(OUT / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])

    # What a link to the site unfurls as: 1200 by 630.
    card = Image.new("RGB", (1200, 630), WHITE)
    draw = ImageDraw.Draw(card)
    draw.rectangle([0, 0, 1200, 14], fill=MINT)
    side = 232
    mask = Image.new("L", (side * 4, side * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, side * 4 - 1, side * 4 - 1], radius=int(side * 4 * 0.2266), fill=255
    )
    card.paste(
        icon.resize((side, side), Image.LANCZOS).convert("RGB"),
        (90, 120),
        mask.resize((side, side), Image.LANCZOS),
    )

    def text(at: tuple[int, int], words: str, size: int, face: int, fill: tuple[int, int, int]) -> None:
        draw.text(at, words, font=ImageFont.truetype(FONT, size, index=face), fill=fill)

    text((370, 128), "PrinterHub", 104, BOLD, INK)
    text((374, 262), "Print, scan and copy from your phone.", 40, REGULAR, MUTED)
    text((90, 420), "Find a printer, tap it, use it.", 62, BOLD, INK)
    text((92, 512), "Works with AirPrint, Mopria and IPP printers on your network.", 34, REGULAR, MUTED)
    card.save(OUT / "og-image.png", optimize=True)


if __name__ == "__main__":
    main()
