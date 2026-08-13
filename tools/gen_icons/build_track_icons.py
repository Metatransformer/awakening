#!/usr/bin/env python3
"""Build the fal.ai batch for one icon per UPGRADE TRACK.

    python3 tools/gen_icons/build_track_icons.py
    python3 tools/gen_icons/falgen.py --batch tools/gen_icons/_specs_tracks.json

A track is a row on a counter's board -- `THE BLADE`, `CHEST`, `THE BAG` -- and
every counter in the game sells them (`Catalogue.groups`). Card #118: **one icon
per TRACK, not one per rung.** The rung numeral stays the distinguisher within a
track, so this is twenty-one pieces of art and not the ninety a per-rung set
would have been.

The token here is the `icon` key each `*_db.gd`'s `groups()` puts on its row, and
`UpgradeLadder` loads `assets/icons/tracks/<token>.png` from it. A row whose art
is missing draws its title alone, exactly as it did before this family existed --
a counter is playable before its icons are baked.

WHY PAINTED-AND-RAMPED AND NOT LINE ART

`assets/icons/actions/` is 24px line SVG and is the right answer for a `VerbRow`,
where the glyph sits at 19px beside a word and has to read as a letterform. A
track icon is the row's FACE: it sits at 44px in the title column with nothing
else in it, and the card asks for two saves to be told apart at a glance. Line
art at that size is thin and every row's stroke weight is identical, which is
precisely the "twelve unrelated lines" the ladder was built to stop being. These
are objects, lit, snapped to the Pal ramp -- the same treatment the HUD's item
glyphs get from `tools/scenes/_iconbake.gd`, and for the same reason.
"""
from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "icons" / "tracks"
SPEC = pathlib.Path(__file__).resolve().parent / "_specs_tracks.json"

## One style string for all twenty-one, and it is not negotiable per icon. The
## ramp throws colour away (only luminance survives `icon_crunch.posterise`), so
## what makes these look like ONE set is the lighting and the material -- warm
## key from the upper left, cold rim behind, dark iron and worn leather. That is
## the torchlight `_iconbake.gd` lights the HUD glyphs with, described in words.
## recraft's style id, and it was CHOSEN rather than defaulted. `falgen.py`'s
## default is `digital_illustration/engraving_color`, which valenfeld uses for
## crests; asked for a longsword it returns a carved bone every time, and the
## other two candidates were no better -- `realistic_image` draws a correct sword
## exactly one pixel wide (the "thin items do not survive" trap in
## STYLEGUIDE §5.2, arrived at from the other direction), and
## `digital_illustration/hand_drawn` returns a hilt with no blade on it. The
## un-suffixed base style is the one that draws objects. Four bakes of the same
## prompt are in the card; keep this here rather than re-buying that answer.
STYLE_ID = "digital_illustration"

STYLE = (
    "single object game icon, dark fantasy dungeon, weathered iron and old leather, "
    "warm torchlight key from the upper left, cold rim light from behind, "
    "heavy chiaroscuro, painted with a confident brush, no gloss, no glow"
)
TAIL = (
    "one isolated object centered and filling the frame, plain flat near-black background, "
    "strong readable silhouette, high contrast, readable at very small size, "
    "no text, no letters, no border, no frame, no hands, no character, no scenery, "
    "no cast shadow, no drop shadow"
)
## Long thin subjects only. A sword drawn upright is a three-pixel scratch at the
## size this is looked at -- the same lesson `_iconbake.gd`'s CROP table learned
## on the real models -- so the ones with a long axis are asked for on the
## diagonal, where the square frame gives them 1.4x the length to be wide in.
DIAGONAL = "laid diagonally corner to corner across the square frame"
LONG = {"blade", "chain", "tools", "fletching", "reforge"}

## token -> what the object IS. Ordered by counter so a reader can see the whole
## board's vocabulary at once.
TRACKS = {
    # --- the smith (`ShopDb.groups`) -----------------------------------------
    # The hilt and the top of the blade, NOT the whole sword. A whole sword
    # drawn in a square is a three-pixel scratch (STYLEGUIDE §5.2 learned this
    # on the real model; the first bake here reproduced it exactly, and so did
    # `realistic_image` when the style was being chosen). What makes a sword
    # read is the guard and the pommel.
    "blade": "a broad heavy double-edged steel sword with a thick wide blade, a plain cross guard and a round pommel",
    "shield": "a battered heater shield seen face on with a riveted iron boss",
    # The four plate pieces are `Game.PLATE_PIECES`. Each is the PIECE and not a
    # body part: a `chest` here is a cuirass, the same noun split
    # `assets/icons/worn/` already draws.
    "chest": "a polished steel breastplate cuirass with riveted shoulder straps, front view, hard metal plate, not cloth",
    "legs": "a pair of articulated steel plate leg armour greaves with hinged knee guards, standing upright side by side, bare polished metal, no leather, no footwear",
    "arms": "a pair of armoured steel vambraces crossed",
    "boots": "a pair of heavy armoured leather and steel boots",
    "bow": "a wooden recurve longbow, strung with a taut bowstring, held upright, no arrow nocked",
    # `THE CHAIN` is the hookshot ladder. The GRAPPLE is the readable half -- a
    # length of chain alone is a texture, not an object.
    "chain": "one large iron grappling hook with three curved prongs, hanging from a single taut length of heavy chain",
    "tools": "a woodsman's felling axe with a worn ash haft",
    "fletching": "three goose-fletched arrows bundled, heads up",
    # The undo row. A hammer over an anvil, because what it sells is the smith
    # putting a finished piece BACK in the fire.
    "reforge": "a blacksmith's hammer resting across a small anvil",

    # --- the jewelcrafter (`JewelDb.groups`) ---------------------------------
    "amulet": "a heavy pendant amulet on a chain, one set stone",
    # Both rings share this. `FIRST RING` and `SECOND RING` are the same object
    # in two places on the body, and two near-identical drawings would be a
    # distinction the player has to squint at instead of read.
    "ring": "a thick banded metal ring set with a single faceted stone",
    "bracelet": "a wide hinged metal bracelet cuff with an inset stone",
    # Not a workshop scene. Two bakes of chisel-and-mallet returned a framed
    # picture and then a plank with a dot beside it -- a tool ARRANGEMENT is a
    # composition, and a composition is what does not survive 44px. The thing
    # this row sells is a jewel being unmade, so the object is the jewel.
    "recut": "one large faceted teardrop gemstone with a deep crack splitting it down the middle, filling the frame",

    # --- the quartermaster (`SupplyDb.groups`) -------------------------------
    "bag": "a bulging buckled leather satchel with a shoulder strap",

    # --- the alchemist (`AlchemyDb.groups`) ----------------------------------
    "glass": "an empty corked round-bottomed glass bottle",
    "draughts": "a stoppered apothecary vial three quarters full of dark liquid",

    # --- the elder (`ElderUpgradeDb.groups`) ---------------------------------
    "quarters": "a low wooden barracks cot with a folded blanket",
    "reveille": "a hanging iron hand bell with a rope pull",

    # --- the lanternkeeper (`RelicDb.groups`) --------------------------------
    # One icon for all twelve floors' rows: the row's title is the floor and the
    # cells are the relics, so the glyph says "a relic goes here" and nothing
    # finer. Twelve near-identical lanterns would be twelve rows of noise.
    "relic": "an ornate broken brass lantern, its glass cracked, unlit",
}

## Icons whose subject is dark iron on dark leather land in the bottom two ramp
## steps and photograph as a smudge -- the same exposure problem
## `_iconbake.gd`'s GAIN exists for, and the same fix. Absent means 1.0.
GAIN = {
    "blade": 1.4,
    "chain": 1.8,
    "reforge": 1.4,
    "tools": 1.3,
    "recut": 1.3,
}


def specs() -> list[dict]:
    rows = []
    for token, subject in TRACKS.items():
        framing = f"{subject}, {DIAGONAL}" if token in LONG else subject
        rows.append({
            "prompt": f"{framing}; {STYLE}; {TAIL}.",
            "out": str(OUT_DIR / f"{token}.png"),
            "style": STYLE_ID,
            "px": 256,
            "internal": 64,
            "gain": GAIN.get(token, 1.0),
        })
    return rows


def main() -> None:
    rows = specs()
    SPEC.write_text(json.dumps(rows, indent=2) + "\n")
    print(f"wrote {len(rows)} track-icon specs -> {SPEC}")
    print(f"next: python3 tools/gen_icons/falgen.py --batch {SPEC}")


if __name__ == "__main__":
    main()
