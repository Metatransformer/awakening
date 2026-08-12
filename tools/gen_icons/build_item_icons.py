#!/usr/bin/env python3
"""Build the fal.ai batch for the things the BAG holds.

    python3 tools/gen_icons/build_item_icons.py            # write the spec
    python3 tools/gen_icons/build_item_icons.py --check    # coverage against ItemDb
    python3 tools/gen_icons/falgen.py --batch tools/gen_icons/_specs_items.json

One icon per id in `ItemDb`, drawn in the same lighting and snapped to the same
Pal ramp as `tools/gen_icons/build_track_icons.py`, so a stack in the bag and a
row on a counter's board belong to one set.

WHAT IS DELIBERATELY NOT HERE

**The armaments.** `sword_knightly`, `kite_shield`, `bow_knightly`, `arrow` and
`hookshot_pistol` already have glyphs, and they are RENDERS OF THE REAL MODELS
(`tools/scenes/_iconbake.gd` -> `assets/ui/icons/hud/`). Generating a second,
prettier sword here would put two swords in the game that do not match each
other and let the HUD drift from the thing in the player's hand -- which is the
whole argument that bake exists to win (`docs/STYLEGUIDE.md` §5.2). `UIKit.ITEM`
resolves those five out of the HUD directory, so a bag cell showing your sword
shows the icon the HUD shows.

**The relics and the Echoes.** Twenty-four unique named objects, each with its
own paragraph in `RelicDb` / `EchoDb`, and both wear a reserved rarity colour
that already tells them apart from everything else on screen. They want authored
art per object, not a table of one-line prompts, and they are a card of their
own. `--check` reports them as KNOWN GAPS, never as failures.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "icons" / "items"
SPEC = pathlib.Path(__file__).resolve().parent / "_specs_items.json"
ITEM_DB = ROOT / "scripts" / "items" / "item_db.gd"

## The same two sentences `build_track_icons.py` uses, and the sameness is the
## point: one lighting rig described in words is what makes forty icons from two
## builders look like one set after the ramp has thrown their colour away.
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

## id -> what the object IS. Written off each row's own description line in
## `ItemDb._build`, because the flavour is the design of record for what the
## thing looks like and a second invented description here would be a second
## answer to the same question.
ITEMS = {
    # --- ingredients: what the bag carries out and the vendor buys ------------
    "bone_shard": "a handful of pale splintered bone fragments",
    "rot_moss": "a clump of damp dark green moss torn off a stone",
    "cracked_flint": "a single split grey flint nodule, one sharp fresh fractured face catching the light",
    "grave_wax": "a lump of soft yellowed tallow wax with a wick in it",
    "iron_scrap": "a torn twisted piece of rusted iron armour plate",
    "ghost_silk": "a weightless drifting hank of pale translucent spider silk",
    "ember_gland": "a fist-sized organic sac glowing dull red from within",
    "deep_amber": "a large rounded polished amber nugget, one small dark insect suspended inside it",
    "void_pearl": "one perfectly round black pearl that swallows the light on it",
    "kings_signet": "a heavy signet RING, a thick metal band seen at an angle with a flat oval seal face carrying a worn crest",

    # --- pot gems: merchandise, not bench material ---------------------------
    # Asked for by CUT, not by colour, and that is the one thing to preserve if
    # these are ever re-prompted. `icon_crunch.posterise` keeps LUMINANCE and
    # throws hue away, so "clouded green agate" and "deep blue sapphire" come
    # back as the same grey lump -- four cells the player cannot tell apart,
    # which is worse than the tint chip they sit above. A cut is a silhouette,
    # and a silhouette is the thing that survives the ramp.
    "moss_agate": "one smooth tumbled oval agate pebble, unfaceted, banded",
    "tide_sapphire": "one rectangular emerald-cut sapphire, step-cut, sharp straight facet edges and square corners",
    "blood_ruby": "one round brilliant-cut ruby seen from above, a circle of triangular facets radiating from the table",

    # --- components: what the forge eats -------------------------------------
    "whetstone_grit": "a small heap of coarse grey sharpening grit and stone dust",
    "riveted_plate": "a cut rectangle of steel breastplate with three rivets in it",
    "tension_coil": "a tightly wound bright steel spring coil",
    "cold_iron_core": "a heavy pale blue-white iron ingot core, frost on its surface",

    # --- materials: what the alchemist eats ----------------------------------
    "fired_cullet": "a small heap of sharp broken glass shards with clean straight edges",
    "bitter_root": "a single forked taproot vegetable pulled from the ground, long tapering root with fine hairs and a cut leafy crown",
    "ash_resin": "a bead of amber-brown tree resin weeping down burnt bark",
    "mourning_dew": "a stoppered glass phial of clear pale blue water",

    # --- stones: what the jewelcrafter eats ----------------------------------
    "silver_wire": "a loose coil of fine drawn silver wire",
    "cut_gemstone": "one large marquise-cut gemstone, a long pointed almond shape with faceted sides, standing upright",
}

## Exposure on the ramp for subjects that are dark by nature. Same knob and same
## reason as `_iconbake.gd`'s GAIN -- the ramp cuts are absolute luminance and a
## black pearl is not.
GAIN = {
    "void_pearl": 1.9,
    "rot_moss": 1.5,
    "bitter_root": 1.6,
    "iron_scrap": 1.3,
    "blood_ruby": 1.4,
    "tide_sapphire": 1.4,
}

## The five that are rendered from the real models instead. See the header.
ARMAMENTS = ("sword_knightly", "kite_shield", "bow_knightly", "arrow", "hookshot_pistol")


def specs() -> list[dict]:
    return [
        {
            "prompt": f"{subject}; {STYLE}; {TAIL}.",
            "out": str(OUT_DIR / f"{token}.png"),
            "style": "digital_illustration",
            "px": 256,
            "internal": 64,
            "gain": GAIN.get(token, 1.0),
        }
        for token, subject in ITEMS.items()
    ]


def _db_ids() -> tuple[set[str], set[str]]:
    """Every id `ItemDb._build` adds directly, and the two families it loops in.

    Parsed rather than imported, because the alternative is booting Godot to ask
    a question a regex answers in a millisecond. It is a COVERAGE check, so a
    parse that misses a row shows up as a spurious gap and never as a false OK."""
    src = ITEM_DB.read_text()
    direct = set(re.findall(r'ItemDef\.(?:make|part|brew|gem)\(&"(\w+)"', src))
    looped = set()
    if "for row in RelicDb.RELICS" in src:
        looped |= {"<the twelve relics>"}
    if "for id in EchoDb.all()" in src:
        looped |= {"<the twelve Echoes>"}
    return direct, looped


def check() -> int:
    direct, looped = _db_ids()
    have = {p.stem for p in OUT_DIR.glob("*.png")}
    missing = sorted(direct - set(ITEMS))
    orphan = sorted(have - set(ITEMS))
    unbaked = sorted(set(ITEMS) - have)
    for name in sorted(looped):
        print(f"GAP     {name} — authored art, a card of their own")
    for token in unbaked:
        print(f"UNBAKED {token} — run falgen.py --batch {SPEC.name}")
    for token in orphan:
        print(f"ORPHAN  {token}.png — no ItemDb row wants it")
    for token in missing:
        print(f"MISSING {token} — in ItemDb, no prompt in this file")
    ok = not missing and not orphan
    print(f"{len(direct)} catalogue rows, {len(ITEMS)} prompts, {len(have)} baked — "
          f"{'OK' if ok else 'FAIL'}")
    # An UNBAKED token is not a failure: the runtime falls back to the tint chip,
    # so a freshly-authored item is fully playable before anyone spends on art.
    # A MISSING prompt or an ORPHAN file is drift between two lists, and is.
    return 0 if ok else 1


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        sys.exit(check())
    rows = specs()
    SPEC.write_text(json.dumps(rows, indent=2) + "\n")
    print(f"wrote {len(rows)} item-icon specs -> {SPEC}")
    print(f"next: python3 tools/gen_icons/falgen.py --batch {SPEC}")


if __name__ == "__main__":
    main()
