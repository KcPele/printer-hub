"""Writes every vector form of the PrinterHub mark from one description.

The mark is a printer seen from the front: a sheet going in at the top, the
body, and a printed sheet coming out. It is described once, below, as a few
rounded rectangles on a 1024 grid, and written out as:

- SVG, for the app itself and for the iOS icon bundles
- Android vector drawables, for the launcher icon and the launch screen

Bitmaps (the launcher icons for old Android versions, the store icon, and
the iOS launch image) are drawn from the SVG by
`packages/app_ui/tool/render_brand_test.dart`.

Run both with `make app-brand`.
"""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]

MINT = "#46D7B7"
INK = "#1A1A1A"
WHITE = "#FFFFFF"

# Launcher backgrounds. Development and staging differ, so a tester can tell
# at a glance which build is which.
BACKGROUNDS = {"main": MINT, "development": "#FB7746", "staging": "#4856EB"}


def rounded(x: float, y: float, w: float, h: float, r: float) -> str:
    """A rounded rectangle as path data that SVG and Android both read."""
    return (
        f"M{x + r},{y}H{x + w - r}A{r},{r} 0 0 1 {x + w},{y + r}"
        f"V{y + h - r}A{r},{r} 0 0 1 {x + w - r},{y + h}"
        f"H{x + r}A{r},{r} 0 0 1 {x},{y + h - r}"
        f"V{y + r}A{r},{r} 0 0 1 {x + r},{y}Z"
    )


def circle(cx: float, cy: float, r: float) -> str:
    return (
        f"M{cx - r},{cy}A{r},{r} 0 1 0 {cx + r},{cy}"
        f"A{r},{r} 0 1 0 {cx - r},{cy}Z"
    )


def mark(accent: str = MINT) -> list[tuple[str, str]]:
    """The shapes of the mark, back to front, as (path, colour)."""
    return [
        # The sheet going in.
        (rounded(352, 188, 320, 250, 40), WHITE),
        # The body.
        (rounded(204, 372, 616, 336, 88), INK),
        # The light that says it is ready.
        (circle(716, 470, 30), accent),
        # The slot, a little wider than the sheet coming out of it.
        (rounded(296, 548, 432, 52, 26), "#000000"),
        # The printed sheet.
        (rounded(332, 574, 360, 262, 40), WHITE),
        (rounded(388, 652, 248, 32, 16), accent),
        (rounded(388, 720, 160, 32, 16), accent),
    ]


def svg(shapes: list[tuple[str, str]], *, size: int = 1024) -> str:
    paths = "\n".join(f'  <path d="{d}" fill="{fill}"/>' for d, fill in shapes)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 1024 1024" fill="none">\n{paths}\n</svg>\n'
    )


def android_vector(
    shapes: list[tuple[str, str]], *, dp: int, scale: float, comment: str
) -> str:
    offset = (dp - 1024 * scale) / 2
    paths = "\n".join(
        f'    <path\n        android:pathData="{d}"\n        android:fillColor="{fill}"/>'
        for d, fill in shapes
    )
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- {comment}
     Written by tool/brand/generate.py. Change the mark there. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{dp}dp"
    android:height="{dp}dp"
    android:viewportWidth="{dp}"
    android:viewportHeight="{dp}">
  <group android:scaleX="{scale}"
      android:scaleY="{scale}"
      android:translateX="{offset:g}"
      android:translateY="{offset:g}">
{paths}
  </group>
</vector>
"""


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print(f"wrote {path.relative_to(APP)}")


def main() -> None:
    brand = APP / "packages/app_ui/assets/brand"
    tile = [(rounded(0, 0, 1024, 1024, 232), MINT), *mark()]

    # For the app: the mark alone, on a full square, and on a rounded tile.
    write(brand / "mark.svg", svg(mark()))
    write(brand / "icon.svg", svg([(rounded(0, 0, 1024, 1024, 0), MINT), *mark()]))
    write(brand / "tile.svg", svg(tile))

    # iOS: the icon bundle draws its own background and takes the mark.
    for bundle in ("AppIcon", "AppIcon-dev", "AppIcon-stg"):
        write(APP / f"ios/Runner/AppIcons/{bundle}.icon/Assets/Logo.svg", svg(mark()))

    # Android: the mark sits in the middle two thirds of an adaptive icon,
    # which is the part every launcher shape keeps.
    for flavor, background in BACKGROUNDS.items():
        res = APP / f"android/app/src/{flavor}/res"
        write(
            res / "drawable/ic_launcher_foreground.xml",
            android_vector(
                mark(accent=MINT if flavor == "main" else WHITE),
                dp=108,
                scale=0.082,
                comment="The launcher icon's foreground.",
            ),
        )
        write(
            res / "values/ic_launcher_background.xml",
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="ic_launcher_background">{background}</color>\n'
            "</resources>\n",
        )

    write(
        APP / "android/app/src/main/res/drawable/ic_launch_image.xml",
        android_vector(
            tile, dp=128, scale=0.125, comment="The mark shown while the app starts."
        ),
    )


if __name__ == "__main__":
    main()
