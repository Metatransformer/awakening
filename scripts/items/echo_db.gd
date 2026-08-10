class_name EchoDb
extends RefCounted
## The twelve Echoes (`docs/PUZZLES.md` §6), as data and as the one place their
## tuning numbers live.
##
## > **An Echo costs a bag slot, and that is the only thing it costs.**
##
## An Echo is a run-scoped boon that **bends a rule the game already runs**. It
## is worth 0 gold, so it does not raise the extraction fee; it dies with the
## run; and it never moves damage, speed, max health, max stamina or soak, which
## is the boundary that keeps a found thing from quietly replacing a bought one
## (GDD §6.6, pillar 4).
##
## ## Why an Echo is an `ItemDef` and not a second inventory
##
## "It costs a bag slot" is the whole design, and the bag is `Run.bag`. Give an
## Echo a catalogue row with `value: 0` and every sentence in §6 falls out of
## arithmetic that already exists: `Run.collect` takes a slot for it,
## `base_value()` adds nothing for it so `extract_cost()` is untouched, the mote
## refuses and pulses on a full bag exactly as a pearl does, and the pouch draws
## it beside everything else. A parallel `Game.echoes` array would have needed a
## slot rule, a fee rule, a full-bag rule and a drop rule of its own -- four
## copies of four rules that are already right.
##
## The one thing that does NOT fall out is the lifetime. `Run.bank_echoes()` is
## where an Echo goes quiet, and it is the mirror of `bank_relics()`.
##
## ## Where the effects are
##
## **Not here.** This file is a table; the twelve rules are bent at the twelve
## sites that own them, each one asking `Run.echo(...)` for the number. That is
## deliberate and it is the same split `BossDb` makes: a central `apply_echoes()`
## would be a thirteenth place that has an opinion about Heat's window, the
## extraction fee and the arrow count, and it would drift from all three.
##
## The `bends` column names the rule and the site so the next person can find it
## without grepping. `docs/PUZZLES.md` §6.2's last paragraph is the reason the
## NUMBERS are here rather than in the doc: a doc that restates a number is a doc
## that will disagree with the code.

## The prefix every Echo id carries. `Run.bank_echoes` and `ItemDb` both need to
## answer "is this an Echo" without a table lookup on a bag that may hold ids the
## catalogue has never heard of, and one spelling of the prefix is cheaper than
## two membership tests that could disagree.
const PREFIX := "echo_"

## How many a pedestal offers. `docs/PUZZLES.md` §6: *every Echo pickup is a
## choice of three*, one prefab, three sites.
const OFFER := 3

## The floor `long_chord` is first offered on (§6.1, row 12). It is worth nothing
## unless you have already committed, so offering it on floor 1 would be offering
## a blank.
const LONG_CHORD_FLOOR := 3


# --- The twelve ---------------------------------------------------------------
## Ids, spelled once. Nothing outside this file writes one as a literal: a
## typo'd StringName is an Echo that is picked up, occupies a slot and bends
## nothing, which is the failure mode with no visible symptom (`PuzzleAtoms`
## records the same lesson about its eight).
const HELD_NOTE := &"echo_held_note"
const ANSWERING_STRIKE := &"echo_answering_strike"
const SLOW_FADE := &"echo_slow_fade"
const SECOND_WIND := &"echo_second_wind"
const BLAZING_TITHE := &"echo_blazing_tithe"
const UNBROKEN_ROPE := &"echo_unbroken_rope"
const COLD_LEDGER := &"echo_cold_ledger"
const DEEP_POCKET := &"echo_deep_pocket"
const QUIET_ROOM := &"echo_quiet_room"
const RETURNING_SHAFT := &"echo_returning_shaft"
const FULL_CUP := &"echo_full_cup"
const LONG_CHORD := &"echo_long_chord"

## `docs/PUZZLES.md` §6.1, in its own order: five on tempo, five on depth, two on
## the carrying itself. That split is the design and not an accident of listing
## (§6.2), so `validate()` checks it.
##
## Row keys:
##   `name`   String     — what the pedestal and the pouch call it.
##   `axis`   StringName — `&"heat"`, `&"depth"` or `&"both"`. §6.2's split, as a
##                         column, so the balance claim is checkable.
##   `line`   String     — one sentence, in the player's words, on the stone.
##   `bends`  String     — the RULE it bends and the site that reads it. For a
##                         reader, not for code.
##   `value`  float      — the tuning number, or 0.0 where the rule is a flat
##                         on/off. The site multiplies or compares; nothing here
##                         does arithmetic.
##   `floor`  int        — the shallowest floor it may be offered on. 1 for
##                         eleven of them; see `LONG_CHORD_FLOOR`.
##
## `static var`, not `const`: the rows hold no other class's constants today but
## they will the first time one wants a `Pal` hue, and a const Dictionary that
## holds one is not a constant expression (`CLAUDE.md` §3).
static var ECHOES := {
	# --- How fast: the Heat axis (GDD §2) ------------------------------------
	HELD_NOTE: {
		"name": "The Held Note", "axis": &"heat", "floor": 1,
		"line": "The chain's leash stops shortening.",
		"bends": "K.HEAT_TIER_WINDOW -- `Heat._on_enemy_died` reads tier 1's "
			+ "window at every tier instead of its own",
		"value": 1.0,
	},
	ANSWERING_STRIKE: {
		"name": "The Answering Strike", "axis": &"heat", "floor": 1,
		"line": "A blow you turn feeds the chain, as a kill does.",
		"bends": "Bus.shield_blocked -- `Heat._on_blocked` advances the chain, "
			+ "the same wiring that already lets a blocked blow keep it alive",
		"value": 0.0,
	},
	SLOW_FADE: {
		"name": "The Slow Fade", "axis": &"heat", "floor": 1,
		"line": "What you drop stays hot until you sweep it.",
		"bends": "K.HEAT_COOL_TIME -- `LootMote.heat()` stops decaying toward 1.0",
		"value": 0.0,
	},
	SECOND_WIND: {
		"name": "The Second Wind", "axis": &"heat", "floor": 1,
		"line": "A kill gives the whole breath back, not a share of it.",
		"bends": "K.STAMINA_KILL -- `Heat._on_enemy_died` refunds "
			+ "`Game.max_stamina`. A rule about kills; the BAR is untouched",
		"value": 0.0,
	},
	BLAZING_TITHE: {
		"name": "The Blazing Tithe", "axis": &"heat", "floor": 1,
		"line": "At a blaze, what dies leaves one more.",
		"bends": "`Enemy._drop_loot` rolls one extra mote while `Heat.tier` is "
			+ "at the top. The top tier finally pays in quantity, not only rate",
		"value": 1.0,
	},

	# --- How deep: the space axis (GDD §2) -----------------------------------
	UNBROKEN_ROPE: {
		"name": "The Unbroken Rope", "axis": &"depth", "floor": 1,
		"line": "Nothing that lands can break the way out.",
		"bends": "`Hero._on_damaged` stops calling `EscapeRope.cancel()` "
			+ "(docs/METAGAME.md §5)",
		"value": 0.0,
	},
	COLD_LEDGER: {
		"name": "The Cold Ledger", "axis": &"depth", "floor": 1,
		"line": "The toll is read off the flat price. Heat is not taxed.",
		"bends": "`Run.extract_cost()` charges on `base_value()` rather than "
			+ "`bag_value()`. The one Echo that cuts GDD §2's central coupling",
		"value": 0.0,
	},
	DEEP_POCKET: {
		"name": "The Deep Pocket", "axis": &"depth", "floor": 1,
		"line": "Common things stack twice as high.",
		"bends": "`Run.collect` / `Run.slots_used` double `ItemDef.stack` for "
			+ "COMMON rows. It does not add a SLOT",
		"value": 2.0,
	},
	QUIET_ROOM: {
		"name": "The Quiet Room", "axis": &"depth", "floor": 1,
		"line": "The first thing in a room waits a beat for you.",
		"bends": "Bus.room_entered -- `Run._hush_room` calls `Enemy.freeze` on "
			+ "the nearest body. Seconds",
		"value": 1.1,
	},
	RETURNING_SHAFT: {
		"name": "The Returning Shaft", "axis": &"depth", "floor": 1,
		"line": "An arrow comes back out of what it killed.",
		"bends": "`Enemy._die` gives one arrow back when the killing blow was "
			+ "`&\"arrow\"` (docs/METAGAME.md §4.6)",
		"value": 1.0,
	},

	# --- Both axes: the two that are about the Echoes themselves -------------
	FULL_CUP: {
		"name": "The Full Cup", "axis": &"both", "floor": 1,
		"line": "Drunk at a blaze, the bottle stays full.",
		"bends": "`Game.drink_bottle` keeps the contents while `Heat.tier` is "
			+ "at the top",
		"value": 0.0,
	},
	LONG_CHORD: {
		"name": "The Long Chord", "axis": &"both", "floor": LONG_CHORD_FLOOR,
		"line": "Every other tone you carry stops weighing anything.",
		"bends": "`Run.slots_used` stops counting the OTHER Echoes. The only "
			+ "one whose value is a function of the others (§6.2)",
		"value": 0.0,
	},
}


# --- Reading the table --------------------------------------------------------

## Every Echo id, in `docs/PUZZLES.md` §6.1's order. Built off the table rather
## than written out beside it -- see `BossDb.all()` for the lesson.
static func all() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ECHOES.keys():
		out.append(k as StringName)
	return out


static func row(id: StringName) -> Dictionary:
	return ECHOES.get(id, {})


## Cheap enough to call on every line of a bag. Deliberately a prefix test rather
## than a dictionary lookup: `Run.bank_echoes` walks the bag, and the bag is the
## one place an id the catalogue has never heard of can turn up.
static func is_echo(id: StringName) -> bool:
	return String(id).begins_with(PREFIX)


static func name_of(id: StringName) -> String:
	return String(row(id).get("name", "An Echo"))


static func line_of(id: StringName) -> String:
	return String(row(id).get("line", ""))


## The tuning number, or `fallback` when this Echo is not held. **This is the
## accessor every site uses**, through `Run.echo()`, so a rule that is bent reads
## the same way as a rule that is not.
static func value_of(id: StringName) -> float:
	return float(row(id).get("value", 0.0))


static func floor_of(id: StringName) -> int:
	return int(row(id).get("floor", 1))


# --- What a pedestal offers ---------------------------------------------------

## Three ids, or fewer when the pool is nearly exhausted.
##
## `held` is what the player is already carrying, and it is filtered out for the
## obvious reason: a second copy of an on/off rule bends nothing and the slot is
## the price. That makes the pool shrink over a run, which is right -- a player
## who has taken four Echoes is choosing from eight, and by the Chord Gate the
## offer is genuinely narrow.
##
## Seeded off `rng` rather than off the global generator so a replayed seed
## offers the same three stones. A roguelike whose runs cannot be replayed cannot
## be debugged (`Dungeon`'s header says the same).
static func offer(rng: RandomNumberGenerator, level: int,
		held: Dictionary = {}) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id in all():
		if held.has(id):
			continue
		if level < floor_of(id):
			continue
		pool.append(id)
	# Fisher-Yates off the run's own generator. `Array.shuffle()` uses the global
	# RNG, which is exactly the reproducibility hole this file is avoiding.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(OFFER, pool.size()))


# --- Proving the table --------------------------------------------------------

## Every rule this file claims about itself, checked. Empty when the table is
## sound; `puzzle_loop` fails on a non-empty result, exactly as the boss
## directors do with `BossDb.validate()`.
static func validate() -> PackedStringArray:
	var out := PackedStringArray()

	# `docs/PUZZLES.md` §8 freezes the count at twelve, with the same discipline
	# as the relics: no thirteenth.
	if ECHOES.size() != 12:
		out.append("the pool is %d -- PUZZLES.md §8 freezes it at 12"
			% ECHOES.size())

	# §6.2: five push on tempo, five on depth, two on the carrying itself. An
	# Echo pool that leaned one way would quietly make one of GDD §2's two axes
	# the real game, and that is the kind of drift a listing hides.
	var axes := {&"heat": 0, &"depth": 0, &"both": 0}
	var seen_names: Dictionary = {}
	for id in all():
		var r := row(id)
		if not is_echo(id):
			out.append("%s: an Echo id must begin with %s" % [id, PREFIX])
		var axis: StringName = r.get("axis", &"")
		if not axes.has(axis):
			out.append("%s: axis %s is not one of heat/depth/both" % [id, axis])
		else:
			axes[axis] += 1
		if String(r.get("line", "")).strip_edges().is_empty():
			out.append("%s: no line -- the stone has nothing to say" % id)
		# Two Echoes with the same name is a pedestal offering the same stone
		# twice, and the player cannot tell which one they took.
		var n := String(r.get("name", ""))
		if seen_names.has(n):
			out.append("%s: same name as %s" % [id, seen_names[n]])
		seen_names[n] = id
		# The catalogue has to know it or `Run.collect` refuses the pickup and the
		# pedestal is a prop you cannot take from.
		var def := ItemDb.get_def(id)
		if def == null:
			out.append("%s: no ItemDb row -- Run.collect would refuse it" % id)
		elif def.value != 0:
			# §6, first bullet: worth 0 gold, so it cannot raise the fee. The
			# moment this is non-zero an Echo starts taxing the walk home and
			# nothing anywhere says so.
			out.append("%s: value %d -- an Echo is worth 0 gold (§6)"
				% [id, def.value])
		elif def.stack != 1:
			out.append("%s: stacks %d -- an Echo costs a whole slot (§6)"
				% [id, def.stack])
	if axes[&"heat"] != 5 or axes[&"depth"] != 5 or axes[&"both"] != 2:
		out.append("the axes are %d/%d/%d -- §6.2 says 5 heat, 5 depth, 2 both"
			% [axes[&"heat"], axes[&"depth"], axes[&"both"]])
	return out
