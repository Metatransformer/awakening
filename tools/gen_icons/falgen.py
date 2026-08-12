#!/usr/bin/env python3
"""fal.ai image generator for this project's baked icon families.

Ported from ~/valenfeld's ``tools/gen_icons/falgen.py``. The generation half is
that file almost unchanged -- recraft-v3, rembg, trim-and-square -- because it
works and two copies that drift is worse than one copy that is a little generic.
What changed is the tail: every icon here lands on the Pal ramp via
``icon_crunch``, not on an adaptive 64-colour palette (see that module's header
and ``docs/STYLEGUIDE.md`` §7.10).

Per icon:
  1. recraft-v3 text-to-image   (plain near-black background, forced palette)
  2. fal rembg                  (cut the background -> transparent)
  3. PIL finalize               (trim alpha, centre on a square, resize)
  4. icon_crunch                (gather to `internal`, Pal ramp, 1px VOID rim)

Step 4 is not optional and there is no flag that skips it. An icon that has not
been through it is a sticker, and this repo has no full-bleed art family under
``assets/icons/`` for the exemption to serve.

THE KEY IS NEVER COMMITTED. $FAL_KEY, else ~/.config/awakening/fal_key, else
~/.config/valenfeld/fal_key (the same paid account; both games bill to it).
Fails loud with no key rather than silently writing nothing.

GENERATION IS AN AUTHOR-TIME BAKE. Runtime loads only the committed PNGs. A
build script writes a spec JSON; this reads it. Regenerating is opt-in per file:
an `out` that already exists is skipped unless --force, so re-running a builder
after adding one token costs one image and not forty.

Usage:
  python3 tools/gen_icons/falgen.py --prompt "..." --out /abs/x.png [--px 256] [--internal 64]
  python3 tools/gen_icons/falgen.py --batch tools/gen_icons/_specs_tracks.json
      specs: [{prompt, out, style?, color?[r,g,b], size?, px?, internal?, gain?, no_rembg?}, ...]
"""
from __future__ import annotations

import argparse, base64, io, json, os, pathlib, sys, time, urllib.request

import requests
from PIL import Image

import icon_crunch

RECRAFT = "https://fal.run/fal-ai/recraft-v3"
REMBG = "https://fal.run/fal-ai/imageutils/rembg"

## Where a key may live, in the order tried. The valenfeld path is last and is
## deliberate: it is the same fal account, and a second copy of a secret on this
## disk is a second copy to leak.
KEY_PATHS = (
    pathlib.Path.home() / ".config" / "awakening" / "fal_key",
    pathlib.Path.home() / ".config" / "valenfeld" / "fal_key",
)


def _key() -> str:
    env = os.environ.get("FAL_KEY")
    if env:
        return env.strip()
    for p in KEY_PATHS:
        if p.exists():
            return p.read_text().strip()
    sys.exit("FATAL: no fal key (set $FAL_KEY or write %s)" % KEY_PATHS[0])


def _post(url: str, body: dict, key: str) -> dict:
    r = requests.post(url, headers={"Authorization": f"Key {key}",
                                    "Content-Type": "application/json"},
                      data=json.dumps(body), timeout=240)
    if r.status_code != 200:
        raise RuntimeError(f"fal {url.split('/')[-1]} {r.status_code}: {r.text[:400]}")
    return r.json()


def _fetch(url: str) -> bytes:
    return urllib.request.urlopen(url, timeout=240).read()


def remove_bg(png: bytes, key: str) -> bytes:
    data_uri = "data:image/png;base64," + base64.b64encode(png).decode()
    return _fetch(_post(REMBG, {"image_url": data_uri}, key)["image"]["url"])


def _is_svg(b: bytes) -> bool:
    head = b[:256].lstrip()
    return head[:5] == b"<?xml" or head[:4] == b"<svg" or b"<svg" in head


def rasterize_svg(svg: bytes, px: int) -> bytes:
    """recraft's vector_* styles return a real SVG. Rasterise it locally, transparent."""
    import shutil, subprocess
    if shutil.which("rsvg-convert") is None:
        raise RuntimeError("rsvg-convert not on PATH (brew install librsvg)")
    r = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px)],
                       input=svg, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0 or not r.stdout:
        raise RuntimeError(f"rsvg-convert failed: {r.stderr.decode()[:200]}")
    return r.stdout


def keep_main_glyph(im: Image.Image, min_frac: float = 0.06) -> Image.Image:
    """Drop disconnected speckle, keeping the emblem and any real sub-part.

    Straight out of valenfeld's `falgen.py`, and it earns its passage here on the
    first bake it was missing from: `cracked_flint` came back with a four-pixel
    fleck of former background floating a third of a frame to the left of the
    stone, which `getbbox` then dutifully included -- so the icon was centred on
    the fleck and the stone sat off to one side.

    Keeps every opaque component at least `min_frac` of the largest, so a genuine
    two-part subject (a chisel AND a gem) survives and a crumb does not.
    Colour-agnostic: it cleans whatever rembg left behind regardless of hue."""
    from collections import deque
    src = im.convert("RGBA")
    px_ = src.load()
    w, h = src.size
    label = [0] * (w * h)
    sizes = {0: 0}
    cur = 0
    for sy in range(h):
        for sx in range(w):
            if label[sy * w + sx] or px_[sx, sy][3] < 24:
                continue
            cur += 1
            n = 0
            label[sy * w + sx] = cur
            dq = deque([(sx, sy)])
            while dq:
                x, y = dq.popleft()
                n += 1
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not label[j] and px_[nx, ny][3] >= 24:
                            label[j] = cur
                            dq.append((nx, ny))
            sizes[cur] = n
    if cur == 0:
        return src
    biggest = max(sizes.values())
    keep = {lab for lab, n in sizes.items() if lab and n >= min_frac * biggest}
    for y in range(h):
        for x in range(w):
            if label[y * w + x] not in keep:
                r, g, b, _ = px_[x, y]
                px_[x, y] = (r, g, b, 0)
    return src


def finalize(png: bytes, px: int) -> bytes:
    """Kill the rembg halo, trim to the glyph, centre it on a square, resize.

    The halo cut is `icon_crunch`'s alpha threshold and NOT valenfeld's 40. They
    have to be the same number: anything between the two survives the trim, is
    counted by `getbbox`, and is then dropped by the posterise -- so the icon is
    centred on a bounding box holding pixels the finished PNG does not have.
    Measured on the first blade bake: the glyph sat in the top two thirds of its
    frame with empty space under it."""
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    data = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = data[x, y]
            if a < 128:
                data[x, y] = (r, g, b, 0)
    # Before `getbbox`, not after: a stray fleck the trim has already counted is
    # a fleck the icon is centred on.
    im = keep_main_glyph(im)
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    # A hair of air, or the rim dilation runs off the frame edge.
    pad = int(side * 0.06)
    framed = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    framed.paste(canvas, (pad, pad))
    framed = framed.resize((px, px), Image.LANCZOS)
    buf = io.BytesIO()
    framed.save(buf, "PNG")
    return buf.getvalue()


def generate(prompt: str, out_path: str, style: str, color, size: int, px: int,
             internal: int, gain: float, do_rembg: bool) -> None:
    key = _key()
    t0 = time.time()
    body = {"prompt": prompt, "image_size": {"width": size, "height": size}, "style": style}
    if color:
        body["colors"] = [{"r": int(color[0]), "g": int(color[1]), "b": int(color[2])}]
    data = _post(RECRAFT, body, key)
    imgs = data.get("images") or []
    if not imgs:
        raise RuntimeError(f"no images: {json.dumps(data)[:300]}")
    png = _fetch(imgs[0]["url"])
    steps = "gen"
    if _is_svg(png):
        png = rasterize_svg(png, max(size, 1024)); steps += "+svg"
    elif do_rembg:
        png = remove_bg(png, key); steps += "+rembg"
    png = finalize(png, px); steps += "+fin"
    png = icon_crunch.crunch(png, internal, px, gain); steps += "+pal"
    out = pathlib.Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    print(f"  ok {out.name}  ({len(png)//1024}kb, {time.time()-t0:.1f}s, {steps}, {internal}px grid)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt"); ap.add_argument("--out")
    ap.add_argument("--style", default="digital_illustration/engraving_color")
    ap.add_argument("--color", help="r,g,b 0-255")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--px", type=int, default=icon_crunch.DEFAULT_SIZE)
    ap.add_argument("--internal", type=int, default=icon_crunch.DEFAULT_INTERNAL)
    ap.add_argument("--gain", type=float, default=1.0)
    ap.add_argument("--no-rembg", action="store_true")
    ap.add_argument("--batch")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--force", action="store_true", help="regenerate even if out exists")
    ap.add_argument("--only", help="comma-separated output stems to (re)build")
    a = ap.parse_args()

    def parse_color(c):
        if not c:
            return None
        return [int(x) for x in (c if isinstance(c, list) else c.split(","))]

    if a.batch:
        from concurrent.futures import ThreadPoolExecutor
        specs = json.loads(pathlib.Path(a.batch).read_text())
        if a.only:
            want = {s.strip() for s in a.only.split(",")}
            specs = [s for s in specs if pathlib.Path(s["out"]).stem in want]
        elif not a.force:
            specs = [s for s in specs if not pathlib.Path(s["out"]).exists()]
        print(f"batch: {len(specs)} icons, {a.workers} workers")

        def run(s):
            try:
                generate(s["prompt"], s["out"], s.get("style", a.style),
                         parse_color(s.get("color")), s.get("size", a.size),
                         s.get("px", a.px), s.get("internal", a.internal),
                         float(s.get("gain", a.gain)),
                         not s.get("no_rembg", a.no_rembg))
                return True
            except Exception as e:
                print(f"  XX {s['out'].split('/')[-1]} FAILED: {e}")
                return False

        with ThreadPoolExecutor(max_workers=a.workers) as ex:
            results = list(ex.map(run, specs))
        ok = sum(1 for r in results if r)
        print(f"done: {ok}/{len(specs)} ok")
        if ok < len(specs):
            sys.exit(1)
    else:
        if not a.prompt or not a.out:
            sys.exit("need --prompt and --out (or --batch)")
        generate(a.prompt, a.out, a.style, parse_color(a.color), a.size, a.px,
                 a.internal, a.gain, not a.no_rembg)


if __name__ == "__main__":
    main()
