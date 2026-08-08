#!/usr/bin/env python3
"""Blind A/B compositor + contact sheets for the visual gauntlet.

The critic never learns which panel is ours. The orchestrator holds the key.

  # blind pair — writes ab.png and a key file the critic is not given
  python3 tools/ab.py ab --ours build/shot.png --ref refs/screens/x.png \
      --out runs/r1/ab.png --key runs/r1/.key.json --seed 7

  # contact sheet — animation cannot be judged from one frame
  python3 tools/ab.py sheet --out runs/r1/sheet.png build/f_*.png
"""

import argparse
import glob
import json
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

BG = (24, 24, 27)
FG = (240, 240, 245)
PANEL_H = 720


def _font(size):
    for p in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                pass
    return ImageFont.load_default()


def _fit(path, height=PANEL_H):
    im = Image.open(path).convert("RGB")
    w = max(1, round(im.width * height / im.height))
    return im.resize((w, height), Image.LANCZOS)


def cmd_ab(args):
    rng = random.Random(args.seed)
    ours = _fit(args.ours)
    ref = _fit(args.ref)

    flip = rng.random() < 0.5
    left, right = (ref, ours) if flip else (ours, ref)
    left_is = "ref" if flip else "ours"
    right_is = "ours" if flip else "ref"

    gap, pad, label_h = 16, 24, 56
    W = left.width + right.width + gap + pad * 2
    H = PANEL_H + pad * 2 + label_h
    canvas = Image.new("RGB", (W, H), BG)
    canvas.paste(left, (pad, pad + label_h))
    canvas.paste(right, (pad + left.width + gap, pad + label_h))

    d = ImageDraw.Draw(canvas)
    f = _font(38)
    d.text((pad + left.width // 2 - 12, pad + 6), "A", fill=FG, font=f)
    d.text((pad + left.width + gap + right.width // 2 - 12, pad + 6), "B", fill=FG, font=f)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    canvas.save(args.out)

    key = {"A": left_is, "B": right_is, "ours": args.ours, "ref": args.ref}
    if args.key:
        os.makedirs(os.path.dirname(os.path.abspath(args.key)) or ".", exist_ok=True)
        with open(args.key, "w") as fh:
            json.dump(key, fh, indent=2)
    print(json.dumps(key))


def cmd_sheet(args):
    paths = []
    for pat in args.frames:
        paths.extend(sorted(glob.glob(pat)) if any(c in pat for c in "*?[") else [pat])
    paths = [p for p in paths if os.path.exists(p)]
    if not paths:
        sys.exit("sheet: no frames matched")

    cols = args.cols or min(4, len(paths))
    rows = (len(paths) + cols - 1) // cols
    cell_h = args.cell
    tiles = [_fit(p, cell_h) for p in paths]
    cell_w = max(t.width for t in tiles)

    pad, label_h = 10, 26
    W = cols * (cell_w + pad) + pad
    H = rows * (cell_h + label_h + pad) + pad
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    f = _font(18)
    for i, (t, p) in enumerate(zip(tiles, paths)):
        c, r = i % cols, i // cols
        x = pad + c * (cell_w + pad)
        y = pad + r * (cell_h + label_h + pad)
        d.text((x + 2, y + 2), "%02d  %s" % (i, os.path.basename(p)), fill=FG, font=f)
        canvas.paste(t, (x, y + label_h))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    canvas.save(args.out)
    print(args.out)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("ab")
    a.add_argument("--ours", required=True)
    a.add_argument("--ref", required=True)
    a.add_argument("--out", required=True)
    a.add_argument("--key")
    a.add_argument("--seed", type=int, default=0)
    a.set_defaults(fn=cmd_ab)

    s = sub.add_parser("sheet")
    s.add_argument("frames", nargs="+")
    s.add_argument("--out", required=True)
    s.add_argument("--cols", type=int, default=0)
    s.add_argument("--cell", type=int, default=300)
    s.set_defaults(fn=cmd_sheet)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
