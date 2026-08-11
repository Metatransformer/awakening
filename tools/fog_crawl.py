#!/usr/bin/env python3
"""Card #66 — turn `tools/directors/fog_crawl.gd`'s sequences into things an eye
can judge.

    tools/quiet.sh --path . -s tools/shoot.gd -- \
      --scene=res://scenes/rooms/dungeon.tscn \
      --director=res://tools/directors/fog_crawl.gd \
      --out=/tmp/fog/x.png --size=1280x720
    python3 tools/fog_crawl.py /tmp/fog

The director photographs consecutive 1280x720 frames under six conditions. This
reads each sequence back and writes, per condition:

  range_x1.png     the per-pixel temporal RANGE (max - min over the sequence),
                   UNAMPLIFIED. This is literally the amount of light that
                   moves. If it is black, nothing moved that a person could see.
  range_x12.png    the same at gain 12, so the SHAPE of what moves is visible —
                   is it a coherent bank of fog, or scattered speckle?
  flip_2x2.png     four consecutive frames of the hottest 320x180 window, 2x
                   nearest, in a 2x2 grid. The flipbook: read it as four
                   photographs of the same wall and see whether they differ.
  flip_4x.png      the worst adjacent PAIR, hottest 160x90 window, 4x nearest,
                   side by side. If the artefact cannot be found here it cannot
                   be found at 1:1 on a screen.

...and prints the numbers that bound the question: how many pixels move, by how
much, how often, how bright the ground they move against is (a step of 8/255 on
a value of 20 is a 40% swing; on 200 it is 4%), and how clustered they are.

Deliberately NOT a pass/fail. Card #66 is a looking card; the verdict is in
docs/STYLEGUIDE.md §4.5 and it was written by somebody who opened these files.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

STEP = 8  # one RGB555 step, in 0..255 bytes
WIN = (320, 180)  # hot window for the 2x2 flipbook, in source pixels
WIN_TIGHT = (160, 90)  # hot window for the 4x pair
GAIN = 12


def load_seq(d: Path) -> tuple[list[Path], np.ndarray]:
    # `f[0-9][0-9]` and not `f*`: this script's own `flip_2x2.png` and
    # `flip_4x.png` land in the same directory and a bare `f*` swallowed them,
    # which fails as a shape mismatch three calls later.
    paths = sorted(d.glob("f[0-9][0-9].png"))
    if len(paths) < 2:
        return paths, np.empty((0,))
    arrs = [np.asarray(Image.open(p).convert("RGB"), dtype=np.uint8) for p in paths]
    return paths, np.stack(arrs)  # (F, H, W, 3)


def hot_window(mask: np.ndarray, win: tuple[int, int]) -> tuple[int, int]:
    """Top-left of the window containing the most flagged pixels."""
    h, w = mask.shape
    ww, wh = win
    ii = np.zeros((h + 1, w + 1), dtype=np.int64)
    ii[1:, 1:] = np.cumsum(np.cumsum(mask.astype(np.int64), axis=0), axis=1)
    ys = np.arange(0, h - wh + 1, 4)
    xs = np.arange(0, w - ww + 1, 4)
    sums = (ii[np.ix_(ys + wh, xs + ww)] - ii[np.ix_(ys, xs + ww)]
            - ii[np.ix_(ys + wh, xs)] + ii[np.ix_(ys, xs)])
    if sums.max() == 0:
        return (w - ww) // 2, (h - wh) // 2
    iy, ix = np.unravel_index(int(sums.argmax()), sums.shape)
    return int(xs[ix]), int(ys[iy])


def zoom(img: np.ndarray, factor: int) -> np.ndarray:
    return np.repeat(np.repeat(img, factor, axis=0), factor, axis=1)


def analyse(name: str, d: Path) -> dict | None:
    paths, seq = load_seq(d)
    if seq.size == 0:
        print(f"fog_crawl: {name}: fewer than two frames in {d}")
        return None
    f, h, w, _ = seq.shape
    n = h * w
    s16 = seq.astype(np.int16)

    # Per-pixel temporal range, taken as the largest per-channel excursion.
    rng = (s16.max(axis=0) - s16.min(axis=0)).max(axis=2)  # (H, W) int16

    moved = rng > 0
    at_step = rng >= STEP
    two_step = rng >= 2 * STEP

    # Adjacent-frame churn: what changes between two frames a viewer actually
    # sees one after the other. This is the number the walking conditions are
    # about — a moving camera re-quantizes the whole buffer every frame, and the
    # fog's share of that is the question.
    diffs = np.abs(np.diff(s16, axis=0)).max(axis=3)  # (F-1, H, W)
    churn = (diffs >= STEP).sum(axis=(1, 2))
    flips = (diffs > 0).sum(axis=0)  # per pixel, how many boundaries it moved on

    # How bright is the ground the artefact moves against? A step of 8/255 on a
    # pixel sitting at 20 is a 40% swing and a step on 200 is 4%; the same pixel
    # count means very different things at the two ends.
    base = s16.mean(axis=0).max(axis=2)
    lit = base[at_step]
    weber = float(np.median(STEP / np.maximum(lit, 1.0))) if lit.size else 0.0

    # Clustering. §4.5 upscales 480x270 to 1280x720, so ONE internal texel is a
    # 2.67 px block: an artefact born in the buffer must come out blocky. A high
    # neighbour fraction is that block; a low one is per-output-pixel speckle,
    # which would mean the artefact is NOT the buffer's.
    nb = np.zeros_like(at_step)
    nb[1:, :] |= at_step[:-1, :]
    nb[:-1, :] |= at_step[1:, :]
    nb[:, 1:] |= at_step[:, :-1]
    nb[:, :-1] |= at_step[:, 1:]
    clustered = float((at_step & nb).sum()) / max(int(at_step.sum()), 1)

    worst = int(churn.argmax()) if churn.size else 0

    # --- the pictures ---------------------------------------------------------
    out = d
    Image.fromarray(np.repeat(rng.clip(0, 255).astype(np.uint8)[:, :, None], 3, 2)).save(
        out / "range_x1.png")
    Image.fromarray(np.repeat((rng * GAIN).clip(0, 255).astype(np.uint8)[:, :, None], 3, 2)).save(
        out / "range_x12.png")

    hx, hy = hot_window(at_step if at_step.any() else moved, WIN)
    tiles = []
    for k in range(4):
        i = min(worst + k, f - 1)
        tiles.append(zoom(seq[i, hy:hy + WIN[1], hx:hx + WIN[0]], 2))
    grid = np.zeros((WIN[1] * 4, WIN[0] * 4, 3), dtype=np.uint8)
    grid[:WIN[1] * 2, :WIN[0] * 2] = tiles[0]
    grid[:WIN[1] * 2, WIN[0] * 2:] = tiles[1]
    grid[WIN[1] * 2:, :WIN[0] * 2] = tiles[2]
    grid[WIN[1] * 2:, WIN[0] * 2:] = tiles[3]
    Image.fromarray(grid).save(out / "flip_2x2.png")

    tx, ty = hot_window(at_step if at_step.any() else moved, WIN_TIGHT)
    sl = (slice(ty, ty + WIN_TIGHT[1]), slice(tx, tx + WIN_TIGHT[0]))
    a = zoom(seq[worst][sl], 4)
    b = zoom(seq[min(worst + 1, f - 1)][sl], 4)
    Image.fromarray(np.concatenate([a, b], axis=1)).save(out / "flip_4x.png")

    # The same crop with every pixel that moved on that boundary painted red.
    # This is the "even knowing exactly where to look" panel: it says how DENSE
    # the artefact is inside the worst neighbourhood in the frame, which is the
    # thing the eye is actually being asked to detect.
    marked = zoom(seq[worst][sl], 4).copy()
    m = zoom(diffs[min(worst, len(diffs) - 1)][sl] >= STEP, 4)
    marked[m] = (255, 0, 0)
    Image.fromarray(np.concatenate([b, marked], axis=1)).save(out / "where_4x.png")

    # Densest 32x32 neighbourhood anywhere in the frame. A scattered 0.7% is
    # dust; a local 60% is a patch that crawls, and only this number separates
    # them.
    bh, bw = h // 32, w // 32
    blocks = at_step[:bh * 32, :bw * 32].reshape(bh, 32, bw, 32).sum(axis=(1, 3))
    dens = float(blocks.max()) / (32 * 32)

    # A trace of the loudest pixels, so a period in the jitter shows itself.
    order = np.argsort(rng, axis=None)[::-1][:6]
    traces = []
    for idx in order:
        y, x = divmod(int(idx), w)
        ch = int(np.argmax(s16[:, y, x].max(0) - s16[:, y, x].min(0)))
        traces.append(f"    ({x:4d},{y:3d}) ch{ch}: "
                      + " ".join(f"{v:3d}" for v in s16[:, y, x, ch]))

    print(f"\n=== {name}  ({f} frames, {w}x{h}) ===")
    print(f"  temporal range   any:{int(moved.sum()):7d} px ({100*moved.mean():5.2f}%)   "
          f">=1 step:{int(at_step.sum()):6d} ({100*at_step.mean():5.3f}%)   "
          f">=2 steps:{int(two_step.sum()):5d}   max:{int(rng.max()):3d}/255")
    print(f"  adjacent churn   >= 1 step per frame pair: "
          f"min {int(churn.min()):7d}  med {int(np.median(churn)):7d}  "
          f"max {int(churn.max()):7d}   ({100*float(np.median(churn))/n:5.2f}% of frame)")
    if at_step.any():
        print(f"  flicker rate     of the {int(at_step.sum())} px at >= 1 step: "
              f"median {int(np.median(flips[at_step]))} of {f-1} frame boundaries; "
              f"{int((flips[at_step] >= (f-1)*0.5).sum())} move on half or more")
        print(f"  contrast         those px sit at median value "
              f"{int(np.median(lit)):3d}/255, so one step is a "
              f"{100*weber:4.1f}% swing; clustered fraction {clustered:.2f}")
        print(f"  local density    densest 32x32 neighbourhood in the frame is "
              f"{100*dens:5.1f}% moving pixels")
    print("  loudest pixels, frame by frame (a period shows up here):")
    for t in traces:
        print(t)
    return {"name": name, "any": int(moved.sum()), "step": int(at_step.sum()),
            "max": int(rng.max()), "churn": int(np.median(churn)), "n": n}


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/fog")
    order = ["ship_still", "noreproj_still", "native_still", "play_still",
             "ship_walk", "noreproj_walk"]
    dirs = [d for d in (root / o for o in order) if d.is_dir()]
    dirs += sorted(d for d in root.iterdir()
                   if d.is_dir() and d.name not in order)
    rows = []
    for d in dirs:
        r = analyse(d.name, d)
        if r:
            rows.append(r)
    if not rows:
        print(f"fog_crawl: nothing to read under {root}")
        return 1
    print(f"\n{'condition':<18}{'range>0':>10}{'>=1 step':>10}{'max':>6}"
          f"{'churn/pair':>12}")
    for r in rows:
        print(f"{r['name']:<18}{r['any']:>10}{r['step']:>10}{r['max']:>6}"
              f"{r['churn']:>12}")
    print(f"\n(frame is {rows[0]['n']} px; one RGB555 step is {STEP}/255)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
