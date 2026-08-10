#!/usr/bin/env python3
"""Cut the flat background off a character portrait and trim it to the figure.

    python3 tools/cut_portrait.py ~/Downloads/smith.png assets/ui/portraits/smith.png

The portraits arrive as 1024x1024 RGB with no alpha and a flat backdrop -- white
on four of them, black on the other two. A dialogue box composites them over a
LIVE courtyard, so the backdrop has to go, and a rectangle of it is the one
mistake that would be visible in every conversation in the game.

**Flood fill from the border, not a colour key.** The alchemist's hood and the
elder's cloak are within a few levels of their own black backdrop; keying on
colour punches holes straight through both of them. A fill that can only reach
pixels CONNECTED to the edge takes the backdrop and leaves the figure, however
dark the figure is -- which is also why the tolerance below can afford to be
generous enough to catch the anti-aliased fringe.

The alpha is feathered by one pixel at the boundary. Without it the pixel art's
own hard edge picks up a bright halo of the backdrop it was drawn against, which
reads as a cut-out sticker rather than a portrait.
"""

import sys
from collections import deque

from PIL import Image

# How far from the sampled backdrop colour still counts as backdrop, as a squared
# distance in RGB. **Two numbers, chosen by which backdrop it is**, and the gap
# between them is the whole difficulty of this job:
#
#   - On WHITE, nothing in these portraits is anywhere near the backdrop, so the
#     tolerance can be wide -- and it has to be, because the anti-aliased fringe
#     around a dreadlock is a gradient the whole way to white and a tight cut
#     leaves a bright halo around the hair.
#   - On BLACK, the elder's robe and the alchemist's hood are within a few levels
#     of the backdrop and connected to it at the bottom edge. A wide tolerance
#     floods straight up through the cloth: the first pass took most of the
#     elder's robe and left him wearing a hole. Tight, and a hair of backdrop is
#     left behind -- which is invisible, because the panel it sits over is dark.
TOLERANCE_LIGHT = 72 * 72
TOLERANCE_DARK = 15 * 15


def cut(src: str, dst: str, pad: int = 8) -> None:
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    # The backdrop colour is the modal colour of the whole BORDER, not of the four
    # corners. Two of these portraits are drawn on white and two on black -- but
    # the smith and the pawnbroker are also cut off by the bottom edge, so their
    # lower corners are dark clothing and a corner vote ties 2-2 and picks the
    # coat. Sampling the full border outvotes the two corners the figure is in.
    border = [px[x, y][:3] for x in range(w) for y in (0, h - 1)]
    border += [px[x, y][:3] for y in range(h) for x in (0, w - 1)]
    counts: dict = {}
    for c in border:
        # Quantised, so a backdrop that dithers by a level or two still counts as
        # one colour rather than as three hundred near-ties.
        k = (c[0] >> 3, c[1] >> 3, c[2] >> 3)
        counts[k] = counts.get(k, 0) + 1
    top = max(counts, key=counts.get)
    bg = (top[0] << 3, top[1] << 3, top[2] << 3)

    tol = TOLERANCE_DARK if sum(bg) < 3 * 64 else TOLERANCE_LIGHT

    def near(c) -> bool:
        return sum((int(a) - int(b)) ** 2 for a, b in zip(c[:3], bg)) <= tol

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near(px[x, y]):
                q.append((x, y))
                seen[y * w + x] = 1
    for y in range(h):
        for x in (0, w - 1):
            if near(px[x, y]):
                q.append((x, y))
                seen[y * w + x] = 1

    while q:
        x, y = q.popleft()
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and near(px[nx, ny]):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    # **Despeckle.** A flood can only reach what is connected to the border, and
    # the backdrop is not always connected to itself: white gets caught in the
    # crook of a dreadlock and between two strands of the jewelcrafter's hair,
    # ringed by dark pixels the fill cannot cross. Those survive as bright specks
    # ALONG THE SILHOUETTE, which is exactly where the eye is. So: any remaining
    # pocket of backdrop-coloured pixels smaller than a fingernail goes too.
    #
    # Only on the LIGHT backdrops, and that asymmetry is deliberate: on black,
    # every enclosed pocket of near-black is a shadow inside a robe, and cutting
    # those is how you put holes in the elder. A speck of leftover black on a
    # dark panel is not worth one hole in a garment.
    POCKET = 400
    for sy in range(h if tol == TOLERANCE_LIGHT else 0):
        for sx in range(w):
            if seen[sy * w + sx] or not near(px[sx, sy]):
                continue
            pocket = []
            seen[sy * w + sx] = 1
            f = deque([(sx, sy)])
            while f:
                x, y = f.popleft()
                pocket.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]
                            and near(px[nx, ny])):
                        seen[ny * w + nx] = 1
                        f.append((nx, ny))
            if len(pocket) <= POCKET:
                for x, y in pocket:
                    px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)

    # Half-alpha on every kept pixel that touches a cut one: one pixel of feather,
    # which is the difference between a portrait and a sticker.
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                # Asked of the ALPHA and not of `seen`: the despeckle pass above
                # marks the pockets it decided to KEEP as seen too.
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        r, g, b, _a = px[x, y]
        px[x, y] = (r, g, b, 150)

    box = im.getbbox()
    if box is not None:
        l, t, r, b = box
        im = im.crop((max(l - pad, 0), max(t - pad, 0),
                      min(r + pad, w), min(b + pad, h)))
    im.save(dst)
    print("%s -> %s  %s  bg=%s" % (src, dst, im.size, bg))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    cut(sys.argv[1], sys.argv[2])
