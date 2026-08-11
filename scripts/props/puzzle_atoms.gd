class_name PuzzleAtoms
extends RefCounted
## The atom kit: the eight phase-1 puzzle props of `docs/PUZZLES.md` §2, as a
## table. **This file is data and a factory. It builds nothing and ticks
## nothing** -- the bodies live in `scripts/props/atoms/`, one file each, and
## every one of them is a `PuzzleAtom`.
##
## `docs/PUZZLES.md` §2 is emphatic that **nothing here is a mechanic**: an atom
## is a body that emits `solved` and a door that listens. That sentence is the
## whole architecture and this file is where it is enforced -- the table below
## says which VERB each atom answers to and what a door says while it is still
## unsolved, and there is no eighth column where behaviour could hide.
##
## ## The verb ladder is the only gate
##
## `docs/PUZZLES.md` §1: four puzzle verbs and one key, and no fifth. Every atom
## names its tier, and a generator picking atoms for floor N filters on
## `tier <= owned`. That filter is the whole of §0 rule 1 -- *a critical-path
## puzzle never asks for an item you do not own* -- and it is one comparison
## rather than a table of per-floor allow-lists that could drift from §1's.
##
## ## Why the refusals live here and not on the atom
##
## A door refuses; an atom does not. The atom is the thing the player acts on
## and it is standing in the room with them, so it has no reason to speak. The
## GATE is the thing they walked to and found shut, and GDD pillar 3 says that
## refusal has to name what is wanted -- "THE EYE IS SHUT", never "LOCKED".
## `PuzzleGate` composes its line out of `refusal` / `plural` below, so the eight
## refusals are eight rows rather than eight strings scattered through eight
## props.
##
## ## Phase 2 is deliberately absent
##
## `docs/PUZZLES.md` §2 lists four more -- crystal switch, torch, timed bars,
## sounding set -- and calls them flavour that is *not committed*. They are not
## stubbed here. A row with no body behind it is a row the generator would
## eventually pick.

## Tier of the verb ladder (`docs/PUZZLES.md` §1). The number is the tier, so
## `tier <= owned_tier` is the whole eligibility rule.
const T0 := 0  ## sword, shield, body, key. Owned from the start, always
const T1 := 1  ## bow -- the Cistern Warden
const T2 := 2  ## burst -- the Slag Ogre
const T3 := 3  ## hookshot -- the Bellwake

## Tier -> the item id that unlocks it, or `&""` for T0.
##
## The ids are `Game.has()`'s, and the two that matter are already `LockedDoor`
## rows -- so a gate keyed to a tier wears the mark of the tier's own item with
## no second sigil table. That reuse is the reason this is a lookup and not a
## `match` in the gate.
##
## T2 was `&"bomb_bag"` until M5. The satchel became a WORKING you cast
## (`docs/GDD.md` §5.2) and the id went with the noun; `Game.grant` translates
## the old spelling on the way in, so `BossDb`'s Slag Ogre row still hands the
## right thing over while it waits for its own one-word change.
const TIER_ITEM: Array[StringName] = [&"", &"bow", &"burst", &"hookshot"]

# --- The eight ----------------------------------------------------------------
## Ids, spelled once. Nothing outside this file writes one of these as a literal:
## a typo'd StringName is a puzzle that generates, builds and silently never
## solves, which is the failure mode with no visible symptom.
const SMALL_KEY := &"small_key"
const URN := &"urn"
const PRESSURE_PLATE := &"pressure_plate"
const PUSH_BLOCK := &"push_block"
const EYE_SWITCH := &"eye_switch"
const CRACKED_PILLAR := &"cracked_pillar"
const HOOK_RING := &"hook_ring"
const SUN_SOCKET := &"sun_socket"
const LANTERN := &"lantern"

## The kit, in `docs/PUZZLES.md` §2's own order.
##
## Row keys:
##   `tier`     int        — which rung of §1's ladder the verb sits on.
##   `verb`     String     — the verb, in the player's words. Only the lookdev
##                           caption and the director's log read it.
##   `script`   String     — the body. Loaded by PATH and never named: these are
##                           `class_name`s added in the same change as this file,
##                           so naming one is a parse error until the project is
##                           re-imported (`CLAUDE.md` §3).
##   `refusal`  String     — what a gate says while ONE of these is unsolved.
##   `plural`   String     — and what it says while several are. "3 OF 4 EYES
##                           STILL SHUT" needs the noun on its own.
##   `state`    String     — and the word for what the unsolved ones ARE. It was
##                           hardcoded "SHUT" until the kit grew an atom that is
##                           never shut: "4 OF 9 LANTERNS STILL SHUT" is a door
##                           describing a thing the player is looking at, wrongly,
##                           which is worse than the "LOCKED" pillar 3 forbids.
##                           Optional; "SHUT" is right for the other eight.
##   `latching` bool       — does solving it stick? A plate does not: step off
##                           and it rises. Everything else in the kit is one-way,
##                           because a puzzle you can un-solve by walking away is
##                           a puzzle you have to re-solve on the way home, and
##                           §4 says the way home is the REWARD.
##   `gates`    bool       — may a generator hang a door on it? The urn cannot:
##                           it is rule 2's ammunition (§0), and a gate that
##                           wanted an urn broken would be a gate that opens by
##                           accident on the way past.
##
## `static var` rather than `const`: `Pal` colours would make this not a constant
## expression, and the rows below will grow one the first time an atom wants its
## hue from the table instead of from its own file (`CLAUDE.md` §3).
static var ATOMS := {
	## The oldest lock in the genre. The DOOR is a `PuzzleGate` with `needs_key`;
	## this row is the KEY, and its `solved` means "the key has been found".
	## Splitting them that way is what makes floor 1's gate room a HUNT (§5.2)
	## rather than a door with a button beside it.
	SMALL_KEY: {
		"tier": T0, "verb": "the key",
		"script": "res://scripts/props/atoms/small_key.gd",
		"refusal": "NEEDS A KEY", "plural": "KEYS",
		"latching": true, "gates": true,
	},
	## Rule 2's whole implementation (`docs/PUZZLES.md` §0): *every puzzle room is
	## solvable from a cold start with an empty pouch, because the urns beside it
	## hold exactly what it needs.* An urn is the reason a bow puzzle met with no
	## arrows is not a dead end.
	URN: {
		"tier": T0, "verb": "the sword",
		"script": "res://scripts/props/atoms/urn.gd",
		"refusal": "THE URN IS WHOLE", "plural": "URNS",
		"latching": true, "gates": false,
	},
	## The one atom in the kit that can go BACKWARDS, which is why `latching` is
	## a column and not an assumption.
	PRESSURE_PLATE: {
		"tier": T0, "verb": "your weight",
		"script": "res://scripts/props/atoms/pressure_plate.gd",
		"refusal": "THE PLATE IS UNPRESSED", "plural": "PLATES",
		"latching": false, "gates": true,
	},
	## A plate you can leave held. The block is the answer to the plate the
	## player cannot stand on and reach the door from, and that pair is the
	## oldest combinator in the genre (§3, nest).
	PUSH_BLOCK: {
		"tier": T0, "verb": "your shoulder",
		"script": "res://scripts/props/atoms/push_block.gd",
		"refusal": "THE BLOCK IS NOT SET", "plural": "BLOCKS",
		"latching": true, "gates": true,
	},
	EYE_SWITCH: {
		"tier": T1, "verb": "the bow",
		"script": "res://scripts/props/atoms/eye_switch.gd",
		"refusal": "THE EYE IS SHUT", "plural": "EYES",
		"latching": true, "gates": true,
	},
	## Built at M1, inert until M5, and **live since M5** (`docs/SCOPE.md` §3):
	## `BurstCast._wake_the_burstable` walks group `&"burstable"` inside the blast
	## radius and calls `burst()`. That was the entire integration -- one line in
	## the working, nothing in the prop -- which is what the year the row spent
	## inert bought. A prop with no verb is a prop; a verb with no prop is a dead
	## end, and the dead end is the expensive one.
	CRACKED_PILLAR: {
		"tier": T2, "verb": "a burst",
		"script": "res://scripts/props/atoms/cracked_pillar.gd",
		"refusal": "THE PILLAR STANDS", "plural": "PILLARS",
		"latching": true, "gates": true,
	},
	HOOK_RING: {
		"tier": T3, "verb": "the hookshot",
		"script": "res://scripts/props/atoms/hook_ring.gd",
		"refusal": "THE RING IS UNTOUCHED", "plural": "RINGS",
		"latching": true, "gates": true,
	},
	## In phase 1 ON PURPOSE (`docs/PUZZLES.md` §2). Floor 1's critical path is
	## T0-only, and without this every Cistern puzzle is a key, a plate or a
	## block -- haulage. It is the one T0 atom that asks the player to AIM.
	SUN_SOCKET: {
		"tier": T0, "verb": "your shield",
		"script": "res://scripts/props/atoms/sun_socket.gd",
		"refusal": "THE SOCKET IS DARK", "plural": "SOCKETS",
		"latching": true, "gates": true,
	},
	## The ninth, and phase 2's crystal switch grown up (`docs/PUZZLES.md` §2's
	## table). **Non-latching, and unlike the plate it is non-latching on
	## purpose** -- the whole of §3's sixth combinator is that pressing one turns
	## others OFF, and an atom that could only ever go one way could not be
	## coupled to anything.
	##
	## It never gates alone. `LanternGrid` is what a door hangs on, and a lone
	## lantern is a light switch (`Lantern`'s class note). `gates` is still true
	## because the GATE's side of the contract is unchanged: it adopts nine atoms
	## carrying its `puzzle_id` and opens when all nine are solved, which is
	## exactly "all nine lit" with no idea a grid exists.
	LANTERN: {
		"tier": T0, "verb": "any blow",
		"script": "res://scripts/props/atoms/lantern.gd",
		"refusal": "THE LANTERN IS DARK", "plural": "LANTERNS",
		"state": "DARK",
		"latching": false, "gates": true,
	},
}


# --- Reading the kit ----------------------------------------------------------

## Every atom id, in `docs/PUZZLES.md` §2's order. Built off the table rather
## than written out beside it -- a hand-kept parallel list is the list that is
## one day missing an atom nobody notices for a month (`BossDb.all()` records the
## same lesson).
static func all() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ATOMS.keys():
		out.append(k as StringName)
	return out


static func row(id: StringName) -> Dictionary:
	return ATOMS.get(id, {})


static func has_atom(id: StringName) -> bool:
	return ATOMS.has(id)


static func tier(id: StringName) -> int:
	return int(row(id).get("tier", T0))


static func verb(id: StringName) -> String:
	return String(row(id).get("verb", ""))


static func latching(id: StringName) -> bool:
	return bool(row(id).get("latching", true))


static func gates(id: StringName) -> bool:
	return bool(row(id).get("gates", true))


## What a gate says while `left` of `total` are still unsolved.
##
## One sentence for one, a count for several. The count matters more than it
## looks: a player at a three-eye gate who has hit two needs to know the door
## is *counting*, or the third eye reads as the first one having come undone.
static func refusal_for(id: StringName, left: int = 1, total: int = 1) -> String:
	var r := row(id)
	if r.is_empty():
		return "IT WILL NOT OPEN"
	if total <= 1 or left <= 1:
		return String(r["refusal"])
	return "%d OF %d %s STILL %s" % [left, total, String(r["plural"]),
		String(r.get("state", "SHUT"))]


## What an **ordered** gate says (`docs/PUZZLES.md` §3, combinator 2 --
## *sequence*): which one of the run is next, counting from 1.
##
## A separate sentence rather than a longer `refusal_for`, because the two say
## opposite things with the same numbers. *"2 OF 3 EYES STILL SHUT"* is how many
## are LEFT; *"THE 2ND OF 3 EYES IS NEXT"* is which one to hit. A player who read
## the first line at an ordered gate would learn the count and nothing about the
## order, which is the whole of what this combinator asks them for.
static func refusal_next_for(id: StringName, at: int, total: int) -> String:
	var r := row(id)
	if r.is_empty():
		return "IT WILL NOT OPEN"
	# One of its kind cannot be a sequence, so it falls back to the plain line
	# rather than saying "THE 1ST OF 1".
	if total <= 1:
		return String(r["refusal"])
	return "THE %s OF %d %s IS NEXT" % [ordinal(at), total, String(r["plural"])]


## `1` -> `1ST`. Public because a placer or a director naming a run's position
## should read the same words the door does.
##
## The teens are the reason this is not `n % 10` alone -- 11TH, 12TH, 13TH -- and
## a gate will never have thirteen of one atom, which is exactly the argument
## that leaves the bug in. It costs one line.
static func ordinal(n: int) -> String:
	var tail := "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: tail = "ST"
			2: tail = "ND"
			3: tail = "RD"
	return "%d%s" % [n, tail]


## The item a gate wearing this atom's tier should carry as its MARK.
##
## `LockedDoor.SIGILS` is keyed on item id and already holds rows for the bow,
## the bomb bag and the hookshot, so a T1 gate wears the bow's moss crescent for
## free and a T0 gate falls through to the keyhole. That is one table doing two
## jobs rather than a second sigil table that could disagree with the first about
## what a bow looks like.
static func mark_item(id: StringName) -> StringName:
	var t := tier(id)
	return TIER_ITEM[t] if t >= 0 and t < TIER_ITEM.size() else &""


## Which tier the player can currently be asked for.
##
## `Game.has()` is THE ownership gate (`scripts/autoload/game_state.gd`), so this
## walks the ladder through it rather than off the floor number -- a player who
## took floor 1's shortcut on run five owns the bow without having played floor 2,
## and a tier derived from depth would refuse them a bow puzzle they can solve.
static func owned_tier() -> int:
	var best := T0
	for t in range(1, TIER_ITEM.size()):
		if Game.has(TIER_ITEM[t]):
			best = t
	return best


## The atoms a puzzle on this floor may use, filtered to what the player owns.
##
## `max_tier` is the shape's own ceiling (§5: a gate room is `<= N-1`, a treasure
## puzzle `<= N`, a shortcut exactly N) and `owned_tier()` is the player's. The
## MINIMUM of the two is the pool, and taking the minimum here rather than at
## three call sites is what stops §0 rule 1 from being three rules.
static func pool(max_tier: int, want_gating: bool = true) -> Array[StringName]:
	var ceiling: int = mini(max_tier, owned_tier())
	var out: Array[StringName] = []
	for id in all():
		if tier(id) > ceiling:
			continue
		if want_gating and not gates(id):
			continue
		out.append(id)
	return out


## Build one, unparented and unplaced. The caller positions it and wires it.
##
## Loaded by path off the row (see the row docs). Returns `null` for an unknown
## id rather than a fallback atom: a puzzle that asked for an atom that does not
## exist has a broken plan, and quietly handing it an urn would ship a gate that
## opens itself.
static func make(id: StringName, puzzle: StringName = &"") -> Node3D:
	var r := row(id)
	if r.is_empty():
		push_error("PuzzleAtoms: no row for %s" % id)
		return null
	var script := load(String(r["script"])) as GDScript
	if script == null:
		push_error("PuzzleAtoms: %s failed to load" % r["script"])
		return null
	var node := script.new() as Node3D
	if node == null:
		push_error("PuzzleAtoms: %s is not a Node3D" % r["script"])
		return null
	node.set(&"atom_id", id)
	node.set(&"puzzle_id", puzzle)
	return node


## Fail loudly rather than late. Called by the atom director and by
## `puzzle_loop`, the same way `BossDb.validate()` is called by the boss ones.
##
## What it can check is what a table can be wrong about: a row pointing at a
## script that is not on disk, a tier off the end of the ladder, a refusal that
## is empty (a gate that says nothing is GDD pillar 3's exact failure), and the
## count `docs/PUZZLES.md` §8 froze at eight.
static func validate() -> PackedStringArray:
	var out := PackedStringArray()
	# Nine: phase 1's eight, plus the lantern, which is phase 2's crystal switch
	# cashed in against §8's ceiling by the owner's amendment of 2026-08-10. The
	# check stays an EQUALITY rather than becoming a `<=`: the number is a ceiling
	# somebody argued for, and a bound that only complains when it is exceeded
	# would let the kit drift to nine by accident, which is how a frozen manifest
	# stops being frozen.
	if ATOMS.size() != 9:
		out.append("the kit is %d atoms -- PUZZLES.md §8 freezes it at 9"
			% ATOMS.size())
	var seen_refusals: Dictionary = {}
	for id in all():
		var r := row(id)
		var path := String(r["script"])
		if not ResourceLoader.exists(path):
			out.append("%s: no body at %s" % [id, path])
		var t := int(r["tier"])
		if t < T0 or t >= TIER_ITEM.size():
			out.append("%s: tier %d is off the ladder (PUZZLES.md §1)" % [id, t])
		if String(r["refusal"]).strip_edges().is_empty():
			out.append("%s: an empty refusal is a door that says LOCKED (pillar 3)"
				% id)
		# Two atoms with the same refusal is a gate that cannot tell the player
		# which of the two it is waiting on.
		var key := String(r["refusal"])
		if seen_refusals.has(key):
			out.append("%s: refuses in the same words as %s" % [id, seen_refusals[key]])
		seen_refusals[key] = id
	# §1's diagonal: the ladder has to cover every tier a floor's critical path
	# can ask for, and floor 1's is T0-only. An empty T0 pool would mean floor 1
	# has no puzzle it is allowed to build.
	var t0 := 0
	for id in all():
		if tier(id) == T0 and gates(id):
			t0 += 1
	if t0 < 2:
		out.append("only %d gating T0 atom(s) -- floor 1's critical path is T0-only"
			% t0)
	return out
