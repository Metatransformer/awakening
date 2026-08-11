class_name RationDb
extends RefCounted
## Food and drink: what the quartermaster issues, and what sitting down with it
## gives back.
##
## **Two rows, and they are deliberately the two bars the HUD already draws** --
## the red one and the blue one. A ration that did something no bar shows would
## need its own meter, its own accessor and its own thing for the player to learn,
## which is the argument `PotionDb` opens with and it did not stop being true for
## a cheaper item. Hardtack calls `Game.heal`, Small Beer calls
## `Game.restore_magic`, and nothing downstream of either knows rations exist.
##
## ## Why this is not a fourth draught
##
## A draught is instant, it is brewed out of things you found, and it lives in
## glass you had to buy. A ration is none of those: it is bought with coin, it
## stacks twenty deep, and **it takes twelve seconds of standing still**
## (`K.MEAL_TIME`). That last one is the entire item. The draughts answer the
## fight you are in; a ration answers the corridor after it, and the reason it
## does not compete with the alchemist is that you cannot drink one while anything
## is looking at you.
##
## It is a **stopgap and it says so** (`docs/METAGAME.md` §6.4). The hero starts
## with one bottle and meets the alchemist only after a boss is dead, so the first
## hours of a save have exactly one answer to a half-empty heart row, which is
## walking home. This is the second one, and it is meant to stop mattering: by the
## time you own three bottles, twelve seconds is a price you stop wanting to pay.
##
## The catalogue is here; the STACKS are on `Game` (`Game.rations`), the meal
## clock is on `Game` beside the draughts', and the price is at the counter
## (`SupplyDb`). This file answers "what is it" and "what does it do", nothing
## else -- the same division `PotionDb` keeps, deliberately and exactly.
##
## `tint` is the colour the ration draws in the HUD cell and on her row. One hue
## per thing, the rule the ingredients and the draughts both follow: at 320x240
## colour is the whole icon set.

## Both rations, in the order the quartermaster lists them. Food first: it is the
## one a player reaches for without being taught what the blue bar is.
const IDS: Array[StringName] = [&"hardtack", &"small_beer"]

## What a ration puts back, named as the bar rather than as a number. Read by
## `apply_tick` and by `effect_of`, so the row and the effect cannot disagree.
const HEALS := &"heals"
const RESTORES := &"restores"

const DEFS := {
	&"hardtack": {
		"name": "Hardtack",
		"short": "FOOD",
		"kind": HEALS,
		"tint": Color(0.82, 0.66, 0.38),
		"blurb": "Issue biscuit, baked twice and kept dry. It is not food so much "
			+ "as a reason to sit down.",
	},
	&"small_beer": {
		"name": "Small Beer",
		"short": "DRINK",
		"kind": RESTORES,
		"tint": Color(0.52, 0.62, 0.44),
		"blurb": "Weak enough to march on. Whatever the workings take out of a "
			+ "man, a cup of this puts a little of it back.",
	},
}


static func has(id: StringName) -> bool:
	return DEFS.has(id)


static func name_of(id: StringName) -> String:
	if not DEFS.has(id):
		return ""
	var d: Dictionary = DEFS[id]
	return String(d["name"])


## Five letters at most, for `PotionDb.short_of`'s reason: it is drawn inside a
## 64 px HUD cell and anything longer stops being a word and becomes a smudge.
static func short_of(id: StringName) -> String:
	if not DEFS.has(id):
		return ""
	var d: Dictionary = DEFS[id]
	return String(d["short"])


static func tint_of(id: StringName) -> Color:
	if not DEFS.has(id):
		return Pal.ASH
	var d: Dictionary = DEFS[id]
	return d["tint"]


static func blurb_of(id: StringName) -> String:
	if not DEFS.has(id):
		return ""
	var d: Dictionary = DEFS[id]
	return String(d["blurb"])


## Which bar this one feeds. `&""` for an id that is not a ration.
static func kind_of(id: StringName) -> StringName:
	if not DEFS.has(id):
		return &""
	var d: Dictionary = DEFS[id]
	return d["kind"]


## What it DOES, in the unit the player feels it in, and **it names the time**.
## The other two numbers are the item; a line that said "+1 heart" and left the
## twelve seconds out would be describing a cheaper Heart Draught, which is
## exactly the thing this must not read as. Generated from K rather than written
## out, for `PotionDb.effect_of`'s reason: a line claiming "+2" over a constant
## that says 3 is worse than no line at all.
static func effect_of(id: StringName) -> String:
	match kind_of(id):
		HEALS:
			return "+%.1f hearts over %ds, seated" % [
				float(K.MEAL_HEAL) / float(K.HEART), int(K.MEAL_TIME)]
		RESTORES:
			return "+%d magic over %ds, seated  (one spin)" % [
				K.MEAL_MAGIC, int(K.MEAL_TIME)]
	return ""


## How many TICKS a whole ration is, and what one of them pays.
##
## Derived from the two constants rather than stored, so the pair can never round
## to something that does not add up to the whole ration: `per_tick` is what
## `Game._tick_meal` hands to the bar, and `ticks()` is what the clock counts. At
## MEAL_TIME 12 / MEAL_TICK 3 that is four ticks of one quarter-heart, or four of
## three magic.
static func ticks() -> int:
	return maxi(1, int(round(K.MEAL_TIME / K.MEAL_TICK)))


## What one tick of `id` puts back, in that bar's own unit. Integer, and the
## remainder is deliberately dropped rather than accumulated: a tick that
## sometimes pays 1 and sometimes 2 is a bar that jitters, and both totals here
## divide evenly by `ticks()` on purpose (see K.MEAL_HEAL / K.MEAL_MAGIC).
static func per_tick(id: StringName) -> int:
	match kind_of(id):
		HEALS:
			return maxi(1, int(K.MEAL_HEAL / ticks()))
		RESTORES:
			return maxi(1, int(K.MEAL_MAGIC / ticks()))
	return 0


## Pay one tick of `id` into whichever bar it feeds. Returns false for an id that
## is not a ration, so the caller can end a meal it cannot serve rather than
## ticking forever against nothing.
##
## **This is the only thing in the project that calls `Game.restore_magic`**, and
## that accessor exists only because this does (`docs/SCOPE.md` §2, owner
## directive 2026-08-11). If this file goes, so does it.
static func apply_tick(id: StringName) -> bool:
	var amount := per_tick(id)
	if amount <= 0:
		return false
	match kind_of(id):
		HEALS:
			Game.heal(amount)
		RESTORES:
			Game.restore_magic(amount)
		_:
			return false
	return true
