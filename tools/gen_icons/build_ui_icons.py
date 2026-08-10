#!/usr/bin/env python3
"""Build the menu glyphs as deterministic SVG source.

    python3 tools/gen_icons/build_ui_icons.py
    python3 tools/gen_icons/build_ui_icons.py --check

Two families, one generator, because they have to look like each other:

    actions/   the verbs -- what a VerbRow or a menu button DOES
    worn/      the eight body slots -- what a SlotTile beside the doll marks

Ported from ~/valenfeld's tools/gen_icons/build_campaign_action_icons.py, with
this game's vocabulary. The shared ones (back, coin, crafting, leave, read,
shops, trade, places) are its glyphs unchanged, so the two games draw the same
idea the same way.

WHY GENERATED, AND WHY 24px LINE ART

The slot art under assets/icons/slots/ is 256px painted illustration. At the 19px
a VerbRow gives an icon it turns to mud -- a dark smudge that reads as a
rendering fault, which is exactly what the first pass of this port looked like.
A row glyph has to be line art authored AT the size it is drawn.

One stroke weight, one colour, one cap and one join across BOTH families, so
thirty-seven icons read as one set instead of thirty-seven decisions. STROKE is
the theme's TEXT vellum: the glyph is a letterform in the row, not a picture.

Godot imports the committed SVGs directly -- no raster copy, no art service. The
--check mode is the drift gate: an icon edited by hand instead of here will fail
it, because a family that is half-generated is a family that stops matching.
"""
from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ICONS = ROOT / "assets" / "icons"
## UITheme.TEXT (0.902, 0.867, 0.788). The glyphs are authored in the body-text
## colour and tinted per-row by modulate when a row needs a different voice.
STROKE = "#e6ddc9"

# Fragments live in the same 24x24 space VerbRow's 19px slot samples from.
ACTIONS = {
    # --- shared with valenfeld, unchanged -------------------------------------
    "back": '<path d="M20 12H5M10 6l-6 6 6 6"/>',
    "coin": '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5c0 1.7 3.1 3 7 3s7-1.3 7-3V7"/>'
            '<path d="M5 12v5c0 1.7 3.1 3 7 3s7-1.3 7-3v-5"/>',
    "crafting": '<path d="m6 19 8.8-8.8M13 6l2.5-2.5L20 8l-2.5 2.5-2-2-2 2"/>'
                '<path d="m5 16 3 3-2 2-3-3zM5 5v3M3.5 6.5h3"/>',
    # The gate is an arch you go DOWN through, so the steps are the subject and
    # the arch is the frame. Without the steps this was a headstone.
    "descend": '<path d="M4 21V10a8 8 0 0 1 16 0v11"/>'
               '<path d="M8 11h8v3h-6v3H8z"/><path d="M2.5 21h19"/>',
    "leave": '<path d="M10 4h9v16h-9M14 12H3M7 8l-4 4 4 4"/>',
    "places": '<path d="M12 21s7-6.2 7-12a7 7 0 1 0-14 0c0 5.8 7 12 7 12z"/>'
              '<circle cx="12" cy="9" r="2.5"/>',
    "read": '<path d="M3 5.5c3-.8 6-.3 9 1.5v13c-3-1.8-6-2.3-9-1.5zM21 5.5c-3-.8-6-.3-9 1.5v13c3-1.8 6-2.3 9-1.5z"/>'
            '<path d="M12 7v13"/>',
    "shops": '<path d="M5 8h14l1 13H4zM8 9V7a4 4 0 0 1 8 0v2"/><path d="M4 12h16"/>',
    "trade": '<path d="M12 4v16M6 7h12M8 7 4.5 13h7zM16 7l-3.5 6h7zM8 20h8"/>',

    # --- ours -----------------------------------------------------------------
    # The bag is the whole pressure of the game, so it gets a real glyph rather
    # than a generic box: a mouth, a drawstring, and a body that reads as full.
    "bag": '<path d="M6 8h12l1.5 12H4.5zM9 8V6a3 3 0 0 1 6 0v2"/><path d="M9.5 12.5h5"/>',
    "bottle": '<path d="M10 3h4v3.5l3 5V21H7V11.5l3-5z"/><path d="M9.5 3h5M7 15h10"/>',
    # A bow is a "D" — curved limb, straight string — with an arrow resting
    # across it. Drawing the DRAW instead (limb bulging right, string pulled to
    # a point) made a symmetric diamond, because two mirrored curves meeting at
    # two points is a diamond no matter what the intent was.
    "bow": '<path d="M7 3a10 10 0 0 1 0 18"/><path d="M7 3v18"/>'
           '<path d="M3 12h18"/><path d="m17.5 8.5 3.5 3.5-3.5 3.5"/>',
    "chest": '<path d="M3 10a9 4.5 0 0 1 18 0v9H3z"/><path d="M3 12.5h18M10.5 12.5h3v4h-3z"/>',
    # Fletching is the arrow being MADE, so the FEATHERS are the subject. A
    # herringbone off the tail, drawn as open strokes: filled vanes merged into
    # one caterpillar at 19px. Horizontal, because as a diagonal shaft with a
    # head it was pixel-identical to `upgrade` at the size that matters.
    "fletch": '<path d="M3 12h16"/><path d="m16 9 3 3-3 3"/>'
              '<path d="M3 8.5 6 12l-3 3.5M6.5 8.5 9.5 12l-3 3.5"/>',
    # An anvil is only legible if the HORN is: a tapered nose on the left, a
    # waist under it, a splayed base. The hammer goes above and slightly right so
    # the two shapes do not share an edge at 19px, which is what muddied the
    # first pass into a single blob.
    "forge": '<path d="M2.5 11h11l4 3.5H9.5z"/><path d="M11 14.5v3.5M7 21h9l-1.5-3h-6z"/>'
             '<path d="M14 3.5h6.5M17.5 3.5v5"/>',
    "heart": '<path d="M12 20S3.5 14.5 3.5 8.8A4.3 4.3 0 0 1 12 6.6a4.3 4.3 0 0 1 8.5 2.2C20.5 14.5 12 20 12 20z"/>',
    # Launcher, taut line, HOOK. The hook is an asymmetric J -- one long arm,
    # one stub -- because anything symmetric on the end of a line reads as a
    # barbell, which is what two passes of this glyph looked like. The chain
    # ticks went too: three 1.6px strokes 3px apart are one grey block at 19px.
    "hookshot": '<path d="M3 6h5v6H3z"/><path d="M8 9h8"/>'
                '<path d="M16 9v6a3.5 3.5 0 0 1-7 0"/>',
    "jewel": '<path d="m12 3 6 5.5-6 12.5L6 8.5z"/><path d="M6 8.5h12M12 3l-3 5.5 3 12.5 3-12.5z"/>',
    "key": '<circle cx="7" cy="12" r="4"/><path d="M11 12h10M18 12v4M15 12v3"/>',
    # The locker is the footlocker in the hero's quarters: a lid, a hasp, feet.
    "locker": '<path d="M3 9h18v11H3zM3 9l2-4h14l2 4"/><path d="M10.5 13h3v3h-3z"/>',
    "map": '<path d="m3 6 6-2 6 2 6-2v14l-6 2-6-2-6 2z"/><path d="M9 4v14M15 6v14"/>',
    "options": '<circle cx="12" cy="12" r="3"/>'
               '<path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6 7.8 7.8M16.2 16.2l2.2 2.2M18.4 5.6l-2.2 2.2M7.8 16.2l-2.2 2.2"/>',
    "quit": '<path d="M12 3v9"/><path d="M6.5 6.5a8 8 0 1 0 11 0"/>',
    "resume": '<path d="m8 5 11 7-11 7z"/>',
    # The rope is the run ending, so the glyph is the way UP and out.
    "rope": '<path d="M12 21V6"/><path d="M8 9.5 12 6l4 3.5"/>'
            '<path d="M9 21h6M9.5 17.5h5M9.5 14h5M9.5 10.5h5"/>',
    "relic": '<path d="m12 3 2.4 5.6L20 11l-5.6 2.4L12 19l-2.4-5.6L4 11l5.6-2.4z"/>'
             '<path d="M19 17.5v3M17.5 19h3"/>',
    "save": '<path d="M4 4h13l3 3v13H4z"/><path d="M8 4v6h8V4M8 20v-6h8v6"/>',
    "shield": '<path d="M12 3 19.5 6v6c0 4.7-3.1 8.2-7.5 10-4.4-1.8-7.5-5.3-7.5-10V6z"/>'
              '<path d="M12 7.5v8"/>',
    "sword": '<path d="M18.5 2.5 8 13l3 3L21.5 5.5V2.5z"/><path d="m7 14 3 3-3.5 3.5-3-3z"/>'
             '<path d="m5.5 15.5 3 3"/>',
    "upgrade": '<path d="M12 20V6"/><path d="m6 12 6-6 6 6"/><path d="M6.5 21h11"/>',
}

## The eight worn slots, as the PIECE rather than the body part. A tile already
## says "CHEST" in words directly under the glyph, so a torso outline would be
## the caption drawn twice; what the player cannot read off the caption is what
## kind of thing goes there, and that is what these draw.
##
## Drawn front-on and symmetric, because they sit in a stacked column where a
## row of leaning shapes reads as a wobble.
WORN = {
    # A cuirass: shoulder line, waist taper, a V neckline and a belt. The first
    # pass had a centre seam and a chest line instead, which at 19px is a
    # four-pane window -- two straight lines beat the silhouette outright.
    "chest": '<path d="M7 4h10l1.5 4.5-1.5 1.5v9H7v-9L5.5 8.5z"/>'
             '<path d="M9.5 4 12 7.5 14.5 4"/><path d="M7.5 15.5h9"/>',
    # A vambrace, laced. Not a whole arm -- the caption says ARMS, the glyph
    # says the thing you buy for them.
    "arms": '<path d="M8.5 4h7l1 6-1.5 9h-6L7.5 10z"/>'
            '<path d="M9 8h6M9.5 12h5M10 16h4"/>',
    # Greaves: two plates over a shin, with the knee line that stops the pair
    # reading as the numeral II.
    "legs": '<path d="M6 4h5v7l-1 9H6.5L6 11z"/><path d="M13 4h5l-.5 7-.5 9h-3.5l-1-9z"/>'
            '<path d="M6.2 10.5h4.7M13.4 10.5h4.4"/>',
    # A boot, in profile -- the ONE asymmetric glyph in the family, because a
    # symmetric boot is a bucket.
    "boots": '<path d="M8 3h5v9l5 4v4H8z"/><path d="M8 16h6"/><path d="M8 20h10"/>',
    # A pendant on a cord. The cord is the whole tell: without it the drop is a
    # gem, which is what `jewel` already means in the other family.
    # Kept NARROW and short: a wide cord arc over a small drop is a wishbone,
    # which is what the first pass read as at every size.
    "amulet": '<path d="M8 3.5 12 8l4-4.5"/><path d="m12 8 4 5-4 7-4-7z"/>',
    # A band, seen at an angle, with the stone on top. A flat circle is `coin`.
    "ring": '<ellipse cx="12" cy="14.5" rx="5.5" ry="6"/><path d="m12 4 2.5 3-2.5 2.5L9.5 7z"/>',
    # A bangle: an OPEN band, so it is not the ring at a different size. The gap
    # is at the bottom where a bracelet's clasp is.
    "bracelet": '<path d="M8.5 19.5a7.5 7.5 0 1 1 7 0"/><path d="M8.5 19.5h2M13.5 19.5h2"/>',
}

FAMILIES = {"actions": ACTIONS, "worn": WORN}


def render(fragment: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
        'viewBox="0 0 24 24" fill="none">\n'
        f'  <g stroke="{STROKE}" stroke-width="1.6" stroke-linecap="round" '
        f'stroke-linejoin="round" opacity="0.92">{fragment}</g>\n'
        '</svg>\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if committed SVGs drift")
    args = parser.parse_args()
    mismatches: list[str] = []
    total = 0
    for family, glyphs in sorted(FAMILIES.items()):
        out = ICONS / family
        if not args.check:
            out.mkdir(parents=True, exist_ok=True)
        for name, fragment in sorted(glyphs.items()):
            path = out / f"{name}.svg"
            expected = render(fragment)
            if args.check:
                if not path.exists() or path.read_text(encoding="utf-8") != expected:
                    mismatches.append(path.relative_to(ROOT).as_posix())
            else:
                path.write_text(expected, encoding="utf-8")
            total += 1
    if args.check and mismatches:
        print("ui icons drifted from the generator:")
        for name in mismatches:
            print("  %s" % name)
        print("re-run: python3 tools/gen_icons/build_ui_icons.py")
        return 1
    print("ui icons: %d glyphs in %d families %s" % (
        total, len(FAMILIES), "checked" if args.check else "written"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
