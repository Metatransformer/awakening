#!/usr/bin/env python3
"""The one post-process every generated icon in this repo passes through.

Ported from ~/valenfeld's ``tools/gen_icons/icon_crunch.py``, with the half that
matters here replaced. Valenfeld crunches to an ADAPTIVE 64-colour palette,
which is right for a game whose UI is full colour. This one snaps to the Pal
ramp and grows a one-pixel VOID rim, because ``docs/STYLEGUIDE.md`` §7.10 bans
bought icon sets and demands glyphs authored *in the palette* -- and a 256px
painted render dropped into a 5-bit HUD is exactly the sticker that rule exists
to keep out.

    low-res gather (LANCZOS) -> Pal ramp posterise -> 1px VOID dilate -> NEAREST upscale

That is `tools/scenes/_iconbake.gd`'s `_posterise` + `_dilate`, on the CPU, for
art that arrives as a PNG instead of as a render. Same ramp, same cuts, same
alpha threshold, same rim -- so a generated glyph and a baked one photograph as
one family. The ramp is READ OUT OF `scripts/ui/style.gd` at import, not copied
here: two spellings of VOID is how a palette drifts.

The adaptive path survives as ``--adaptive`` because valenfeld's slot art under
``assets/icons/slots/`` was crunched that way and re-crunching it would change
thirteen committed files for nothing.

Usage:
  python3 tools/gen_icons/icon_crunch.py path/to/icon.png [...]
  python3 tools/gen_icons/icon_crunch.py --check path/to/icon.png [...]
"""
from __future__ import annotations

import argparse
import io
import re
from pathlib import Path
from typing import Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
STYLE_GD = ROOT / "scripts" / "ui" / "style.gd"

## Rendered large and knocked down: 256px of PNG on a 64px grid. Same numbers the
## slot art already committed under assets/icons/ uses, so the two families sit
## at the same pixel size in a cell.
DEFAULT_INTERNAL = 64
DEFAULT_SIZE = 256
## Only for --adaptive. The ramp path has four colours and no knob.
DEFAULT_COLORS = 64

## The grids a family in this repo is allowed to gather on. 32 is a HUD glyph,
## 64 the ordinary UI icon, 96 a plate that is looked at rather than glanced at.
SUPPORTED_INTERNALS = (32, 64, 96)

## `_iconbake.gd`'s RAMP and CUTS, and they must stay that pair. Four levels is
## what the styleguide's dither budget affords; the cuts are absolute luminance,
## which is why `gain` exists for art that arrives underexposed.
RAMP_NAMES = ("VOID", "ASH", "MOTH", "BONE")
CUTS = (0.16, 0.38, 0.66)


def _pal() -> dict[str, tuple[int, int, int]]:
    """The palette, read off `scripts/ui/style.gd` rather than copied.

    `Pal` is the single owner of these bytes (every channel a multiple of 8, see
    its header). A Python copy of the hexes would be a second owner, and the one
    thing this repo has actually paid for is two places holding one fact."""
    src = STYLE_GD.read_text()
    out: dict[str, tuple[int, int, int]] = {}
    for name, hexes in re.findall(r'const (\w+) := Color\("([0-9a-fA-F]{6})"\)', src):
        out[name] = tuple(int(hexes[i:i + 2], 16) for i in (0, 2, 4))
    missing = [n for n in RAMP_NAMES if n not in out]
    if missing:
        raise RuntimeError(f"{STYLE_GD} no longer defines {missing} — the ramp cannot be read")
    return out


def ramp() -> list[tuple[int, int, int]]:
    pal = _pal()
    return [pal[n] for n in RAMP_NAMES]


def _luminance(r: int, g: int, b: int) -> float:
    # Godot's Color.get_luminance weights, so a pixel lands on the same ramp step
    # here as it would in `_iconbake.gd`.
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def posterise(image: Image.Image, gain: float = 1.0) -> Image.Image:
    """Snap every surviving pixel onto the Pal ramp; clear everything under half alpha.

    Alpha is THRESHOLDED, not blended. A half-transparent edge pixel dithers into
    whatever is behind the cell and the silhouette goes soft, which is the one
    thing a small glyph cannot afford.

    Luminance is un-premultiplied first: PIL's resize averages RGB and alpha
    independently, so a pixel the silhouette only half covers comes back with
    half the COLOUR as well as half the alpha. The alpha half is wanted; the
    colour half is a lie, and it is worst on exactly the one-pixel-wide shaft
    that needed the help."""
    steps = ramp()
    rgba = image.convert("RGBA")
    src = rgba.load()
    out = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    dst = out.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = src[x, y]
            if a < 128:
                continue
            lum = _luminance(r, g, b) / max(a / 255.0, 0.001) * gain
            step = len(steps) - 1
            for i, cut in enumerate(CUTS):
                if lum < cut:
                    step = i
                    break
            dst[x, y] = (*steps[step], 255)
    return out


def dilate(image: Image.Image) -> Image.Image:
    """Grow the silhouette by one pixel of VOID.

    The same trick as the 1px dark outline the HUD uses everywhere else: it gives
    a thin glyph a body and separates it from whatever the cell is filled with.
    Without it a blade is a scratch."""
    void = _pal()["VOID"]
    src = image.convert("RGBA")
    px = src.load()
    out = src.copy()
    dst = out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 128:
                continue
            touching = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 128:
                        touching = True
                        break
                if touching:
                    break
            if touching:
                dst[x, y] = (*void, 255)
    return out


def crunch(png: bytes, internal: int = DEFAULT_INTERNAL, size: int = DEFAULT_SIZE,
           gain: float = 1.0, adaptive: int = 0, rim: bool = True) -> bytes:
    """Gather, posterise, rim, upscale. `adaptive` > 0 takes valenfeld's colour path."""
    if internal <= 0 or size <= 0:
        raise ValueError("internal and size must both be positive")
    if internal > size:
        raise ValueError(f"internal resolution {internal} cannot exceed output size {size}")

    with Image.open(io.BytesIO(png)) as source:
        source.load()
        rgba = source.convert("RGBA")

    small = rgba.resize((internal, internal), Image.Resampling.LANCZOS)
    if adaptive:
        alpha = small.getchannel("A").point(lambda v: 0 if v < 8 else v)
        quant = small.convert("RGB").quantize(colors=adaptive,
                                              dither=Image.Dither.FLOYDSTEINBERG).convert("RGBA")
        quant.putalpha(alpha)
        small = quant
    else:
        small = posterise(small, gain)
        if rim:
            small = dilate(small)

    crunched = small.resize((size, size), Image.Resampling.NEAREST)
    buffer = io.BytesIO()
    crunched.save(buffer, "PNG")
    return buffer.getvalue()


def crunch_path(path: str | Path, internal: int = DEFAULT_INTERNAL,
                size: int | None = None, gain: float = 1.0, adaptive: int = 0) -> None:
    target = Path(path)
    with Image.open(target) as image:
        image.load()
        if image.width != image.height:
            raise ValueError(f"icon crunch requires a square source: {target} is {image.size}")
        output_size = size or image.width
    target.write_bytes(crunch(target.read_bytes(), internal, output_size, gain, adaptive))


def is_crunched_image(image: Image.Image, internal: int = DEFAULT_INTERNAL) -> bool:
    """Detect the low-resolution grid `crunch` leaves behind.

    Grid only, and deliberately: the ramp check lives in `is_palette_image`
    because valenfeld's imported slot art is on the grid and NOT on the ramp, and
    conflating the two would fail thirteen files this repo chose to keep."""
    if image.width != image.height or internal <= 0 or internal > image.width:
        return False
    mode = "RGBA" if "A" in image.getbands() or "transparency" in image.info else "RGB"
    normalized = image.convert(mode)
    small = normalized.resize((internal, internal), Image.Resampling.NEAREST)
    rebuilt = small.resize(normalized.size, Image.Resampling.NEAREST)
    return rebuilt.tobytes() == normalized.tobytes()


def canonical_internal_for_image(image: Image.Image) -> int | None:
    for internal in SUPPORTED_INTERNALS:
        if is_crunched_image(image, internal):
            return internal
    return None


def is_palette_image(image: Image.Image) -> bool:
    """Every opaque pixel is one of the four ramp entries."""
    steps = set(ramp())
    rgba = image.convert("RGBA")
    for count, colour in (rgba.getcolors(maxcolors=1 << 16) or [(0, None)]):
        if colour is None:
            return False
        if colour[3] >= 128 and colour[:3] not in steps:
            return False
    return True


# A family is a FOLDER, so `--check assets/icons/tracks` has to mean the 22
# PNGs in it. Without this the checker took files only, the docs told people to
# point it at a directory, and it answered `Is a directory` -- a green tick
# nobody could get and so a check nobody ran.
def _expand(paths: Iterable[str]) -> list[Path]:
    out: list[Path] = []
    for raw_path in paths:
        path = Path(raw_path)
        if path.is_dir():
            out.extend(sorted(path.glob("*.png")))
        else:
            out.append(path)
    return out


def _run(paths: Iterable[str], *, check: bool, internal: int, gain: float,
         adaptive: int) -> int:
    failed = False
    for path in _expand(paths):
        try:
            if check:
                with Image.open(path) as image:
                    image.load()
                    grid = canonical_internal_for_image(image)
                    pal_ok = is_palette_image(image)
                ok = grid is not None
                note = f"{grid}px grid" if ok else "SMOOTH"
                note += ", on ramp" if pal_ok else ", off ramp"
                print(f"{'OK  ' if ok else 'FAIL'} {path}  ({note})")
                failed |= not ok
            else:
                crunch_path(path, internal, None, gain, adaptive)
                how = f"{adaptive}c adaptive" if adaptive else "Pal ramp"
                print(f"CRUNCHED {path} ({internal}px/{how})")
        except Exception as exc:
            print(f"ERROR {path}: {exc}")
            failed = True
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--internal", type=int, default=DEFAULT_INTERNAL)
    parser.add_argument("--gain", type=float, default=1.0,
                        help="exposure on the ramp for art that arrives dark")
    parser.add_argument("--adaptive", type=int, default=0, metavar="COLORS",
                        help="valenfeld's colour path instead of the Pal ramp")
    args = parser.parse_args()
    return _run(args.paths, check=args.check, internal=args.internal,
                gain=args.gain, adaptive=args.adaptive)


if __name__ == "__main__":
    raise SystemExit(main())
