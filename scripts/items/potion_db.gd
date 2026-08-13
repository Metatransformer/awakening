class_name PotionDb
extends RefCounted
## What can be in a bottle, and what happens when you drink it.
##
## Three draughts, and they are deliberately the three things the forge already
## sells: health, damage, soak. A potion that did something no rung does would
## need its own number in K, its own accessor on `Game`, and its own line in
## every screen that reads one -- and the player would have to learn a fourth
## kind of good. These instead **borrow the forge's own accessors**: Emberblood
## adds to `Game.sword_bonus()` and Ironhide to `Game.armour_soak()`, so a
## draught is worth two rungs for its 45 seconds and not one consumer of either
## number knows that potions exist.
##
## The catalogue is here; the SLOTS are on `Game` (`Game.bottle_contents`) and
## the price is at the counter (`AlchemyDb`). This file answers "what is it" and
## "what does it do", and nothing else.
##
## `tint` is the colour the bottle draws in the HUD cell and on the alchemist's
## row. One hue per thing, the same rule the ingredients follow -- at 320x240
## colour is the whole icon set.

## Every draught, in the order the alchemist lists them.
const IDS: Array[StringName] = [
	&"health_draught", &"ironhide_draught", &"emberblood_draught",
]

const DEFS := {
	&"health_draught": {
		"name": "Health Draught",
		"short": "HP",
		"tint": Color(0.88, 0.25, 0.22),
		"blurb": "Thick, and warm going down. Eight HP, and it does not ask "
			+ "where you are standing.",
	},
	&"ironhide_draught": {
		"name": "Ironhide Draught",
		"short": "HIDE",
		"tint": Color(0.35, 0.47, 0.78),
		"blurb": "Your skin goes grey and stops arguing with things that hit it.",
	},
	&"emberblood_draught": {
		"name": "Emberblood Draught",
		"short": "EMBER",
		"tint": Color(0.95, 0.55, 0.18),
		"blurb": "The blade does not change. What swings it does.",
	},
}


static func has(id: StringName) -> bool:
	return DEFS.has(id)


static func name_of(id: StringName) -> String:
	if not DEFS.has(id):
		return "Empty Bottle"
	var d: Dictionary = DEFS[id]
	return String(d["name"])


## Five letters at most: it is drawn inside a 64 px HUD cell under a glass
## outline, and anything longer stops being a word and becomes a smudge.
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
		# Full stops, not semicolons, anywhere a draught's text can reach: three
		# short sentences read at a glance and a clause chain does not, and the
		# trade screen draws these at HUD size.
		return "Empty. The alchemist fills it. The dungeon is what makes you want it full."
	var d: Dictionary = DEFS[id]
	return String(d["blurb"])


## The sentence that says what it DOES, in the unit the player feels it in --
## the same contract the smith's `detail` keeps. Generated from K rather than
## written out, because a line that claims "+2" while the constant says 3 is
## worse than no line at all.
static func effect_of(id: StringName) -> String:
	match id:
		&"health_draught":
			return "+%d HP, at once" % K.DRAUGHT_HEAL
		&"ironhide_draught":
			return "-%d HP off every blow, %ds" % [K.DRAUGHT_PLATE, int(K.DRAUGHT_TIME)]
		&"emberblood_draught":
			return "+%d HP a swing, %ds" % [K.DRAUGHT_EDGE, int(K.DRAUGHT_TIME)]
	return ""


## Drink it. Returns false if `id` is not a draught, so the caller can keep the
## bottle rather than emptying it into nothing.
##
## The two lasting ones are started here and TICKED on `Game`, next to stamina,
## because `Game` is the only thing in the project that already has a clock and
## a second one would be a second thing to pause wrongly.
static func apply(id: StringName) -> bool:
	match id:
		&"health_draught":
			Game.heal(K.DRAUGHT_HEAL)
		&"ironhide_draught", &"emberblood_draught":
			# Re-drinking REPLACES the clock rather than stacking it. Stacking
			# would make the answer to every hard fight "drink all four", which
			# is the one thing four slots must not be for.
			Game.start_draught(id, K.DRAUGHT_TIME)
		_:
			return false
	Bus.potion_drunk.emit(id)
	return true
