class_name FloorDb
extends RefCounted
## The four authored floors of the Descent, one row each, and nothing else.
##
## `docs/GDD.md` §5 makes the Descent finite: four floors, four bosses, an
## ending. §5.1 says how — floors stay **seeded and generated**
## (`scripts/world/dungeon.gd`) and each one gets a small manifest of room count,
## roster, tint and four guaranteed placements. Hand-authoring four floors is
## weeks of work that also deletes the run-to-run variety the loop depends on.
## Generated rooms, authored anchors, one dictionary per floor.
##
## **This file is data.** No node building, no scene-tree reference, no gameplay
## logic. The accessors at the bottom are table lookups and nothing more. The
## acceptance test for a fifth floor — if SCOPE ever allowed one, and it does not
## (`docs/SCOPE.md` §1) — is one row in `FLOORS`, not one `if` in the generator.
## If you find yourself writing `if level ==` against this table, the row is
## missing a field and the fix is here, not there.
##
## **`Prog` is still the only curve.** `scripts/core/progression.gd` owns every
## number that gets harder with depth: health, damage, wind-up, elite share, drop
## rolls, chest picks. What this table owns is what a *place* is — its name, its
## roster, its colour, and where its four doors go. Where a floor wants the
## endless curve's answer for a shape number it says so out loud
## (`ROOMS_FROM_PROG` / `PACK_FROM_PROG`) and defers. A manifest that quietly
## re-derived difficulty would be the second curve GDD §7 exists to forbid, and
## the symptom is always the same: a floor with tougher monsters and worse loot.
##
## **Levels past 4 are answered, not rejected.** The Long Descent (GDD §8) runs
## this same generator with no ceiling, so `get_floor()` returns the `ENDLESS`
## row for anything deeper than the last authored floor rather than failing. It
## is a real row with a real roster — it just defers its shape to `Prog` and has
## no boss, no vault and no authored anchors.


# --- Deferral sentinels -------------------------------------------------------
## A row saying "I am not authored to a length; ask the curve." Spelled as a
## named constant rather than a bare 0 so the row reads as a decision instead of
## as a value someone forgot to fill in.
const ROOMS_FROM_PROG := 0
const PACK_FROM_PROG := Vector2i.ZERO


# --- Tints --------------------------------------------------------------------
## ONE dungeon kit, FOUR TINTS is the entire variety budget (`docs/SCOPE.md` §1,
## and the no-list refuses a second kit explicitly). So the four entries below
## are the whole of this game's environmental variety and they have to carry it.
##
## Each tint is named, because "floor 3's colours" is a lookup and "Pale Ring" is
## a thing you can hold an opinion about. `TINTS.size()` is the number SCOPE
## freezes at 4; the Long Descent reuses `riven_dawn` rather than authoring a
## fifth.
##
## **The rule every one of these obeys: contrast is RANGE and HUE, never an
## absence of light** (GDD pillar 5, `docs/STYLEGUIDE.md` §1). A tint that makes
## the room darker is a bug, not a mood — this project already shipped that bug
## once, when stone albedo sat at 0.18–0.32 and the hero rendered as a black
## cut-out between sconces. So:
##
## - `stone` is a MULTIPLY against the kit's authored stone albedo
##   (`assets/materials/mat_wall.tres`, 0.265–0.398), and **every one of them has
##   a channel at 1.00**. A tint can rotate hue; it cannot turn the lights down.
## - `air` gets LIGHTER as you go deeper, not darker. Fog that is darker than the
##   geometry reads as dread; fog slightly lighter than it reads as depth
##   (STYLEGUIDE §4.6). The Chord Gate has the brightest air in the game because
##   it is a threshold to open sky and the player has to feel that before the
##   boss door opens.
## - `fire` is warm and `fill` is cool, always, and they get FURTHER apart as the
##   floors go on. Warmth only reads as warmth against something cooler; that hue
##   gap is what sells "magical" and it is what lets shadows stay coloured
##   instead of crushing to black.
## - No `fire` is `Pal.GOLD`. STYLEGUIDE §2 reserves that one hue for currency,
##   and a torch painted in it steals the only saturated colour the player owns.
##
## Keys:
##   `label`            String  — the palette's name, for lookdev captions
##   `stone`            Color   — multiply on kit stone albedo; max channel 1.00
##   `fire`             Color   — torch flame + omni light hue (per-floor
##                                override of `KitStyle.FIRE_COLOR`)
##   `fill`             Color   — the dungeon's one shadowless directional fill
##                                (`scenes/kit/dungeon_env.tscn`)
##   `air`              Color   — `fog_light_color` AND `background_color`. One
##                                value for both on purpose: STYLEGUIDE §4.6
##                                says a mismatch draws a visible horizon line,
##                                which is the exact thing fog exists to hide.
##                                (`env_dungeon.tres` currently ships them
##                                different — see the note in the report.)
##   `ambient`          Color   — `ambient_light_color`, cool blue-violet
##   `ambient_energy`   float   — never below the shipped 0.38
##   `fog_density`      float   — character, not depth. A smoky foundry is
##                                thicker than a dry resonance hall regardless of
##                                which is further down.
static var TINTS := {
	## The Cistern. Wet stone that has been under water for four centuries: the
	## green-blue is a mineral stain, not a filter. The coolest STONE in the set
	## against the game's baseline torch, so floor 1 teaches "warm pool, cool
	## room" before any floor complicates it.
	&"drowned_bronze": {
		"label": "Drowned Bronze",
		"stone": Color(0.86, 0.98, 1.00),
		"fire": Color(1.00, 0.74, 0.46),
		"fill": Color(0.58, 0.80, 0.96),
		"air": Color(0.1255, 0.1569, 0.1882),
		"ambient": Color(0.30, 0.34, 0.47),
		"ambient_energy": 0.38,
		"fog_density": 0.0062,
	},
	## The Foundry. The only floor whose STONE is warmer than the base — the
	## Imperium's furnaces cooked the walls, and brass-tinted masonry against the
	## hottest, most orange fire in the set would be one warm sheet. The fill is
	## therefore pushed to the coldest blue so far: the wider the hue gap, the
	## more the room reads as lit rather than as tinted.
	&"slag_light": {
		"label": "Slag Light",
		"stone": Color(1.00, 0.90, 0.78),
		"fire": Color(1.00, 0.62, 0.30),
		"fill": Color(0.52, 0.64, 0.98),
		"air": Color(0.1882, 0.1569, 0.1569),
		"ambient": Color(0.34, 0.34, 0.44),
		"ambient_energy": 0.42,
		"fog_density": 0.0075,
	},
	## The Hushing Choir. Bone and violet, and the thinnest, palest flame in the
	## game — a hall built to hold a note is not a hall anyone lit for comfort.
	## The clearest air of the four despite being the third floor down: you can
	## see the far end of a resonance hall, which is most of why it unnerves.
	&"pale_ring": {
		"label": "Pale Ring",
		"stone": Color(0.94, 0.93, 1.00),
		"fire": Color(1.00, 0.82, 0.60),
		"fill": Color(0.72, 0.66, 1.00),
		"air": Color(0.1569, 0.1569, 0.2196),
		"ambient": Color(0.34, 0.32, 0.50),
		"ambient_energy": 0.44,
		"fog_density": 0.0058,
	},
	## The Chord Gate. The stone stops being tinted, because you are nearly out of
	## the ground — the identity here is the widest hue gap in the game (the
	## coldest fill against a warm, near-gold fire) and the brightest air. The
	## deepest floor being the brightest is deliberate and it is the whole point
	## of the place: the Descent's last floor should not look like more of the
	## same, further down.
	&"riven_dawn": {
		"label": "Riven Dawn",
		"stone": Color(0.98, 0.98, 1.00),
		"fire": Color(1.00, 0.78, 0.52),
		"fill": Color(0.50, 0.66, 1.00),
		"air": Color(0.1569, 0.1882, 0.2510),
		"ambient": Color(0.32, 0.38, 0.56),
		"ambient_energy": 0.50,
		"fog_density": 0.0068,
	},
}


# --- Anchors ------------------------------------------------------------------
## The four guaranteed placements (GDD §5.1), as RULES a generator can satisfy —
## never coordinates. A coordinate would only be meaningful on a floor whose
## layout was authored, and the layouts are a seeded tree that is different every
## run (`Dungeon._plan`).
##
## An anchor rule reads:
##   `room`   StringName — which room. `&"entrance"` is the arrival cell,
##                         `&"deepest"` the cell furthest along the tree, and
##                         `&"mid_ring"` the cell whose distance is nearest half
##                         the deepest and which is neither of the other two.
##                         All three are things `Dungeon.rooms` already knows —
##                         `dist` is recorded per cell at plan time.
##   `at`     StringName — `&"wall"` mounts on a wall face, `&"floor"` stands on
##                         the ground.
##   `side`   StringName — walls only. `&"blank"` is any side of that room with
##                         no corridor doorway in it (a door punched through a
##                         doorway is a door you cannot lock). `&"far"` is the
##                         blank side pointing away from the room's own doorways,
##                         which is where the stair sits today.
##   `offset` Vector2    — fractions of `Dungeon.room_size`, so a room resize
##                         does not move anything off its wall. On a `&"wall"`
##                         it is (along the wall from its midpoint, proud of the
##                         face). On a `&"floor"` it is (x, z) from the room
##                         centre, in the room's local space.
##
## The four rows are shared rather than copy-pasted per floor because GDD §5.1
## fixes them for every floor: four copies of one arrangement is four places for
## it to drift. A floor that ever needs a different arrangement names a different
## anchor set in its row, which is the same move the tints make.
##
## Note there is no rule here for "does this floor have a vault". That question
## is answered by `vault_key(level)` being empty, which is GDD §5.3's own
## sentence and must stay the only answer — see the fork accessors below.
static var ANCHORS_STANDARD := {
	## The boss door REPLACES the stair (GDD §5.1), so it inherits the stair's
	## spot: the far wall of the deepest room, at the end of the longest walk. The
	## way down is behind the boss.
	&"boss_door": {
		"room": &"deepest", "at": &"wall", "side": &"far",
		"offset": Vector2(0.0, 0.0),
	},
	## Beside the boss door, not opposite it. The moment you can see the way down
	## is the moment you have the most to lose, and the floor's relic sitting in
	## the same glance is what makes that a decision instead of a corridor.
	&"deep_chest": {
		"room": &"deepest", "at": &"floor", "side": &"",
		"offset": Vector2(-0.22, 0.24),
	},
	## Near the entrance, because the shortcut's whole promise is that on your
	## fifth run you are past this floor in ninety seconds (GDD §5.3). A shortcut
	## you have to cross the floor to reach is not a shortcut.
	&"shortcut_door": {
		"room": &"entrance", "at": &"wall", "side": &"blank",
		"offset": Vector2(0.0, 0.0),
	},
	## The middle ring: far enough in that reaching it is a commitment, near
	## enough out that coming back for it on hour ten is a short trip.
	&"vault_door": {
		"room": &"mid_ring", "at": &"wall", "side": &"blank",
		"offset": Vector2(0.0, 0.0),
	},
	## `docs/PUZZLES.md` §5.2, the critical-path puzzle. **On the path to
	## `deepest`, around 0.7 of the way** -- far enough in that the walk home is
	## worth shortening, near enough out that a player who solves it has most of
	## the floor still ahead. A `&"floor"` anchor rather than a wall one because
	## what is anchored is the ROOM: the atoms stand in it and the gate goes on
	## the doorway that leads deeper, which is a corridor side the layout already
	## chose (`Dungeon._place_gate_room`).
	##
	## It is also the anchor the chord edge (§4) hangs off: the cycle's far end
	## has to be past this gate or the loop would be a shortcut you could walk
	## before solving anything.
	&"gate_room": {
		"room": &"gate_path", "at": &"floor", "side": &"",
		"offset": Vector2(0.0, 0.0),
	},
	## §5.3, the treasure puzzle. **Off the mid-ring**, on a blank wall, and it
	## shares that room with the vault door: two doors on two walls of one room
	## is the design, not a collision. The vault is opened by floor N+1's item
	## and the puzzle by a verb you already own, so the same room offers "come
	## back for this" and "earn this now" side by side, which is the most
	## interesting thing a middle room can say.
	##
	## Resolved AFTER `vault_door` (`Dungeon.ANCHOR_ORDER`), because the vault
	## wants two clear cells behind it and this wants one -- the greedier
	## structure has to pick its wall first or it is the one that fails to place.
	&"puzzle_room": {
		"room": &"mid_ring", "at": &"wall", "side": &"blank",
		"offset": Vector2(0.0, 0.0),
	},
}

## The Long Descent authors nothing. An empty anchor set means "generate as the
## dungeon did before the Descent existed" — the stair goes back in the deepest
## room and there are no locked doors, because there is no floor N+1 item to key
## one to and no relic below except the one in `LONG_DESCENT_RELIC`.
static var ANCHORS_ENDLESS := {}


# --- The floors ---------------------------------------------------------------
## One row per authored floor. `FLOORS.size()` is `docs/SCOPE.md` §1's frozen
## count of 4, which makes that line of the manifest checkable rather than
## arguable.
##
## Row keys:
##   `name`        String     — the room-name card (STYLEGUIDE §3). This does NOT
##                              replace `Prog.label()`: the HUD's depth readout
##                              stays "FLOOR 2", because a number is what you
##                              glance at and a name is what you arrive in.
##   `subtitle`    String     — one line, under the name, about what the place
##                              was. This is the whole flavour budget for the
##                              floor; spend it here and nowhere else.
##   `rooms`       int        — authored length, or `ROOMS_FROM_PROG` to defer.
##   `pack`        Vector2i   — authored (min, max) bodies per room, or
##                              `PACK_FROM_PROG` to defer.
##   `bands`       Dictionary — room distance from the entrance -> roster pool.
##   `bands_deep`  Array      — the pool for any distance past the last key.
##   `tint`        StringName — a key into `TINTS`.
##   `boss`        StringName — a `BossDb` id.
##   `boss_item`   StringName — what its earned great chest grants when opened
##                              (GDD §5.2). Also the key to this floor's shortcut
##                              and to floor N-1's vault; see the fork accessors.
##   `anchors`     Dictionary — an anchor set, above.
##   `relics`      Dictionary — slot -> relic id. `RelicDb` owns what they DO;
##                              this only says where they lie. Slots are
##                              `&"deep_chest"`, `&"vault"`, `&"boss"`.
##
## The rooms counts climb faster than `Prog.rooms()` would (which gives 6,6,7,7
## across these four) because the Descent has an END. An endless curve has to
## ration its escalation forever; a four-floor act can spend it, and the last
## floor being visibly longer than the first is most of how the act reads as
## descending rather than repeating.
static var FLOORS := {
	1: {
		"name": "The Cistern",
		"subtitle": "Vyr intake works, still flooded. The city it watered has been gone four hundred years; the water has not noticed.",
		"rooms": 6,
		## Deferred. `Prog.pack(1)` is (2, 4) and the Cistern's mouth has to stay
		## easy forever (GDD §7) — that is what makes a short cautious run a real
		## option rather than a wasted one. Authoring a number here that happened
		## to equal the curve's would be a second curve waiting to disagree.
		"pack": PACK_FROM_PROG,
		"bands": {
			0: [&"skeleton", &"skeleton", &"goblin"],
			1: [&"skeleton", &"goblin", &"goblin"],
			2: [&"goblin", &"goblin", &"skeleton"],
		},
		"bands_deep": [&"goblin", &"skeleton", &"goblin"],
		"tint": &"drowned_bronze",
		"boss": &"cistern_warden",
		"boss_item": &"bow",
		"anchors": ANCHORS_STANDARD,
		"relics": {
			&"deep_chest": &"tally_ledger",
			&"vault": &"still_head",
			&"boss": &"anvil_plate",
		},
	},
	2: {
		"name": "The Foundry",
		"subtitle": "Where the Imperium melted Vyr bronze down and poured it into shapes of its own. It is the only thing they ever did well down here.",
		"rooms": 8,
		"pack": PACK_FROM_PROG,
		## The goblin at distance 0 is not a leftover. `Prog.band` was built so the
		## deepest room of one floor OVERLAPS the first room of the next rather
		## than jumping, and the roster has to honour the same idea: the Foundry's
		## mouth should feel like the Cistern got worse, not like a different game
		## started. By distance 2 there is nothing from floor 1 left.
		"bands": {
			0: [&"kobold", &"kobold", &"goblin"],
			1: [&"kobold", &"kobold", &"orc"],
			2: [&"kobold", &"orc", &"orc"],
		},
		"bands_deep": [&"orc", &"orc", &"kobold"],
		"tint": &"slag_light",
		"boss": &"slag_ogre",
		# The Burst-Verse, not a satchel (`docs/GDD.md` §5.2). This id is what
		# floor 1's VAULT door names in its refusal (`FloorDb.vault_key`) and what
		# `PuzzleAtoms.TIER_ITEM[T2]` gates the cracked pillar on, so the three
		# have to agree on the spelling or the vault says "NEEDS A KEY".
		"boss_item": &"burst",
		"anchors": ANCHORS_STANDARD,
		"relics": {
			&"deep_chest": &"cinder_retort",
			# The Sustain-Verse, and it replaced `fletchers_jig` here rather than
			# being added beside it -- GDD §6.2 deleted the jig to PAY for this
			# row, and the two standing together would be a thirteenth relic in a
			# manifest frozen at twelve (`docs/SCOPE.md` §1).
			&"vault": &"sustain_verse",
			# `kiln_core`, NOT `glass_kiln_core`. GDD §6.2 prints the DISPLAY
			# name "Glass-Kiln Core"; `RelicDb` owns the id and spells it short.
			# The long form was written here from the table and it is not one of
			# the twelve -- the Lanternkeeper would have refused floor 2's boss
			# drop, and nothing would have said so until a player carried it up.
			&"boss": &"kiln_core",
		},
	},
	3: {
		"name": "The Hushing Choir",
		"subtitle": "A hall the Vyr built to hold one note. It is still holding it.",
		"rooms": 9,
		"pack": PACK_FROM_PROG,
		## GDD §7 gives this floor to the wraiths, but a floor of nothing but
		## wraiths is one fight nine times. The orcs at the mouth are the overlap
		## with the Foundry, and they thin out to nothing by the deep rooms — so
		## the floor's identity arrives as a REPLACEMENT you watch happen rather
		## than as a roster you were handed at the door.
		"bands": {
			0: [&"orc", &"orc", &"wraith"],
			1: [&"wraith", &"orc", &"wraith"],
			2: [&"wraith", &"wraith", &"orc"],
		},
		"bands_deep": [&"wraith", &"wraith", &"wraith"],
		"tint": &"pale_ring",
		"boss": &"bellwake",
		"boss_item": &"hookshot",
		"anchors": ANCHORS_STANDARD,
		"relics": {
			# The Ballast-Verse. `pillar_shard` was here and moved to floor 4's
			# BOSS (GDD §6.2 row 11) -- these two edits are one edit, and doing
			# only one of them leaves either a duplicate or a hole.
			&"deep_chest": &"ballast_verse",
			&"vault": &"warp_stone",
			&"boss": &"sounding_rod",
		},
	},
	4: {
		"name": "The Chord Gate",
		"subtitle": "The threshold the Vyr cut over Caer Vallen before they went up. The Society has spent two hundred years asking what is on the other side of it.",
		"rooms": 10,
		## The one authored pack override in the table, and the reason is the
		## roster rather than the depth. `Prog.pack(4)` is (3, 7), which is correct
		## for seven skeletons and absurd for seven iron knights: the curve counts
		## BODIES and this floor's bodies are the two heaviest in the game. Cutting
		## the count is not making the floor easier — `Prog` still gives every one
		## of them +75% health and +1 damage — it is keeping the room legible,
		## which is the same reason `Prog.pack` caps at 7 in the first place.
		"pack": Vector2i(2, 4),
		## `troll` and `knight_iron` are `Enemy.DEFS`' two heaviest ordinary bodies
		## (`enemy.gd:136` and `:144`) — the slow one with the longest wind-up in
		## the roster, and a soldier you cannot outpace.
		##
		## This note used to say they had NO row and that the floor therefore spawned
		## skeletons. That was true when the manifest was written and the card that
		## added the rows did not come back to correct it, so the doc outlived the gap
		## it was reporting — which is the exact failure CLAUDE.md §7 warns about,
		## since the next agent reads it and believes floor 4 is unfinished.
		"bands": {
			0: [&"wraith", &"troll", &"troll"],
			1: [&"troll", &"troll", &"knight_iron"],
			2: [&"troll", &"knight_iron", &"knight_iron"],
		},
		"bands_deep": [&"knight_iron", &"knight_iron", &"troll"],
		"tint": &"riven_dawn",
		"boss": &"riven_knight",
		"boss_item": &"far_lantern",
		"anchors": ANCHORS_STANDARD,
		## No `&"vault"` slot, and the absence IS the fact: floor 4 has no vault
		## because the boss room is the vault (GDD §5.3). Nothing here says so in
		## a branch — `vault_key(4)` comes out empty on its own, because there is
		## no floor 5 to lend it a key.
		"relics": {
			&"deep_chest": &"rope_drum",
			&"boss": &"pillar_shard",
		},
	},
}


## Anything past the last authored floor. GDD §8: the Long Descent is the endless
## generated dungeon, entered from floor 4's shortcut, where "bands mix and the
## `Prog` curve runs without a ceiling". So this row authors nothing it does not
## have to — no length, no pack, no boss, no anchors — and reuses the Chord
## Gate's tint rather than spending a fifth against SCOPE's budget of four. That
## reuse is also the right read: you came through the Chord Gate to get here.
static var ENDLESS := {
	"name": "The Long Descent",
	"subtitle": "Past the Gate the works stop being anybody's. How far you got is the whole of what you bring back.",
	"rooms": ROOMS_FROM_PROG,
	"pack": PACK_FROM_PROG,
	"bands": {
		0: [&"kobold", &"orc", &"wraith"],
		1: [&"orc", &"wraith", &"troll"],
		2: [&"wraith", &"troll", &"knight_iron"],
	},
	"bands_deep": [&"troll", &"knight_iron", &"wraith"],
	"tint": &"riven_dawn",
	"boss": &"",
	"boss_item": &"",
	"anchors": ANCHORS_ENDLESS,
	"relics": {},
}

## The twelfth relic, which is the one thing in the Long Descent that is not
## generated (GDD §6.2, §8). It lives here as a named row rather than inside
## `ENDLESS.relics` because `ENDLESS` answers for EVERY level past 4, and a relic
## in that row would be a unique that drops on floor 5, 6, 7 and forever.
## `docs/GDD.md` §3 is explicit that there is no relic drop table.
static var LONG_DESCENT_RELIC := {
	"level": 10,
	"slot": &"deep_chest",
	"id": &"riven_chord",
}


# --- Accessors ----------------------------------------------------------------
# Lookups, not logic. Everything below is one line off a row, which is the
# property that keeps the table honest: the moment an accessor needs a branch of
# its own, the row was missing a field.

## The authored Descent. `docs/SCOPE.md` §1 freezes this at 4.
static func floor_count() -> int:
	return FLOORS.size()


## Is this one of the four, or are we in the Long Descent?
static func is_authored(level: int) -> bool:
	return FLOORS.has(level)


## The row for a level, always. Never null and never an empty dictionary: the
## endless mode runs this same generator with no ceiling, and a caller that had
## to null-check every field would grow the branch this file exists to prevent.
static func get_floor(level: int) -> Dictionary:
	return FLOORS.get(level, ENDLESS)


static func name_of(level: int) -> String:
	return get_floor(level).get("name", "")


static func subtitle_of(level: int) -> String:
	return get_floor(level).get("subtitle", "")


## The name a floor is ANNOUNCED by — the loading card and the HUD's top-left
## card, which GDD §3 names as the two callers and the only two.
##
## Both drew `Prog.NAME` until this line existed, so every one of the four floors
## arrived as THE SUNKEN CUT and the names in this table were read by nothing but
## `MapPanel`. GDD §3 pre-authorised the wiring in so many words: *"the day the
## Cistern and the Foundry become real places rather than a table in this document
## … the same two callers draw it."* They are real places; `Dungeon` builds all
## four.
##
## `Prog.NAME` does not go away and is not superseded. It is the name of the SHAFT,
## and the shaft is still what is signed over the garrison gate (`Npc._plate`) —
## one way down, four places it passes through. Nor does this replace
## `Prog.label()`: the depth readout stays on the card's second line, because a
## number is what you glance at and a name is what you arrive in.
##
## Separated from `name_of` by exactly one thing, the fallback. A surface that
## announces a place cannot draw an empty string, so a row with no `name` gets the
## shaft's. `name_of` stays literal because `MapPanel` wants it literal — a blank
## line on a map is a row that simply is not drawn, which is the right answer there
## and the wrong one here.
##
## No `to_upper()`: `CanvasText` uppercases in both `draw_text` and `width`, so the
## table's title case renders as THE CISTERN and measures as it. Upper-casing here
## would only make this file's copy of the string disagree with `MapPanel`'s.
static func announced_name(level: int) -> String:
	var n := name_of(level)
	return n if n != "" else Prog.NAME


## Rooms on this floor. Authored, or the curve's answer where the row defers.
static func rooms(level: int) -> int:
	var n: int = get_floor(level).get("rooms", ROOMS_FROM_PROG)
	return Prog.rooms(level) if n == ROOMS_FROM_PROG else n


## Bodies per room as (min, max). Authored, or the curve's answer where the row
## defers — which is every floor but the Chord Gate. See that row for why it is
## the exception.
static func pack(level: int) -> Vector2i:
	var p: Vector2i = get_floor(level).get("pack", PACK_FROM_PROG)
	return Prog.pack(level) if p == PACK_FROM_PROG else p


## The whole roster table: room distance from the entrance -> pool of kinds.
##
## Keyed on DISTANCE, not on `Prog.band()`. GDD §7: "Rooms carry a distance from
## the entrance, and that distance and the floor's own manifest choose what
## spawns." The split is deliberate — `Prog` owns how HARD a body is at this
## depth (health, damage, wind-up, elite share) and the manifest owns WHICH body
## it is. Keying the roster off the band number too would put the floor's
## identity inside the difficulty curve, and then re-tuning one would silently
## re-cast the other.
static func bands(level: int) -> Dictionary:
	return get_floor(level).get("bands", {})


## The pool for one room, with the past-the-last-key fallback applied here rather
## than at every call site. One place owns the rule "deeper than the table means
## `bands_deep`", the same way `Dungeon.BANDS`/`BAND_DEEP` did.
static func roster(level: int, room_dist: int) -> Array:
	var row: Dictionary = get_floor(level)
	var deep: Array = row.get("bands_deep", [])
	var table: Dictionary = row.get("bands", {})
	return table.get(maxi(room_dist, 0), deep)


## The floor's colour identity. Returns the TINT, not its key, because every
## caller wants the values and a second `TINTS[...]` lookup out in the kit is a
## second place to typo a key.
static func tint(level: int) -> Dictionary:
	var key: StringName = get_floor(level).get("tint", &"")
	return TINTS.get(key, {})


static func tint_key(level: int) -> StringName:
	return get_floor(level).get("tint", &"")


static func boss(level: int) -> StringName:
	return get_floor(level).get("boss", &"")


## What opening this floor boss's earned great chest grants (GDD §5.2). Empty in
## the Long Descent, which has no boss — and that emptiness is load-bearing,
## because it is what makes `vault_key(4)` come out right without a branch.
static func boss_item(level: int) -> StringName:
	return get_floor(level).get("boss_item", &"")


## GDD §5.3, first sentence: *the shortcut on floor N is opened by floor N's own
## boss item, and skips floor N.* One line, so it cannot drift from the rule.
##
## Floor 4's shortcut therefore takes the Far Lantern and leads to the Long
## Descent (GDD §8) — that falls out of the table rather than being special-cased,
## because the Far Lantern IS floor 4's boss item.
static func shortcut_key(level: int) -> StringName:
	return boss_item(level)


## GDD §5.3, second sentence: *the vault on floor N is opened by floor N+1's boss
## item, and holds a relic.* Also one line, and for the same reason.
##
## Floor 4 comes out empty on its own: there is no floor 5, so `get_floor(5)`
## returns `ENDLESS`, whose `boss_item` is empty. "Floor 4 has no vault" is not a
## rule written anywhere in this file — it is what the two sentences already say.
static func vault_key(level: int) -> StringName:
	return boss_item(level + 1)


static func has_vault(level: int) -> bool:
	return vault_key(level) != &""


## The guaranteed placements for this floor, as rules. See `ANCHORS_STANDARD`.
## Empty in the Long Descent, which means "generate as before".
static func anchors(level: int) -> Dictionary:
	return get_floor(level).get("anchors", {})


static func anchor(level: int, id: StringName) -> Dictionary:
	return anchors(level).get(id, {})


## Slot -> relic id for this floor. `RelicDb` owns what each one does; this owns
## only where it lies. A missing slot means there is nothing there, which is how
## floor 4 says it has no vault relic.
static func relics(level: int) -> Dictionary:
	return get_floor(level).get("relics", {})


static func relic_in(level: int, slot: StringName) -> StringName:
	return relics(level).get(slot, &"")
