class_name ShopDb
extends RefCounted
## What the smith sells. Eight lines, and every one of them changes a number the
## player can feel inside one run.
##
## Two shapes of line, on one list on purpose:
##
##  * **Stock** -- arrows, a bag slot, a heart container. Gold only. These are
##    things the smith HAS, and money is the whole transaction.
##  * **Forge** -- the five gear ladders (docs/METAGAME.md §6.5). Gold AND
##    components, because the smith cannot make a longer chain out of coin. The
##    rung sits in `Game.upgrades` and the gear reads it back through the
##    accessors on `Game`; nothing here knows what an arc or a draw time is.
##
## One list rather than two screens because the player is answering one question
## -- what is the best thing I can afford right now -- and splitting the answer
## across two menus makes them hold half of it in their head.
##
## Prices are set against the drop tables rather than against each other: a good
## run extracts with roughly 250-450 gold of ingredients, so the cheap lines are
## affordable after one run and the expensive ones after two or three. The
## component costs are the second dial, and they are the slower one: gold you can
## grind, but a Cold Iron Core has to be found.
##
## Everything here is PERMANENT and lives on `Game`, because the only things
## worth buying with money that survives death are things that also survive it.

## Purchases you can only make so many times, and how many. Every forge track is
## capped at K.FORGE_MAX because that is how many rungs its ladder has -- the
## limit is not a balance choice here, it is the length of the table.
const LIMITS := {
	&"bag_slot": 4,
	&"heart": 3,
	&"edge": K.FORGE_MAX,
	&"plate": K.FORGE_MAX,
	&"guard": K.FORGE_MAX,
	&"string": K.FORGE_MAX,
	&"chain": K.FORGE_MAX,
}

## track id -> the recipe for each rung, in order. Index 0 is what rung ONE
## costs, so `PARTS[track][owned]` is always "what the next one costs".
##
## Read the columns, not the rows: grit is the cheap, common tax on the two
## melee ladders; plate is armour's spine and the shield's second ingredient;
## coil belongs to the two things under tension, the bow and the chain. **Every
## third rung wants a Cold Iron Core**, which is the pacing gate -- the top of
## any ladder is an event, and which ladder gets the core is the only genuinely
## hard spending decision the smith ever poses.
const PARTS := {
	&"edge": [
		{&"whetstone_grit": 3},
		{&"whetstone_grit": 6, &"riveted_plate": 2},
		{&"whetstone_grit": 10, &"cold_iron_core": 1},
	],
	&"plate": [
		{&"riveted_plate": 3},
		{&"riveted_plate": 6, &"whetstone_grit": 2},
		{&"riveted_plate": 10, &"cold_iron_core": 1},
	],
	&"guard": [
		{&"riveted_plate": 2, &"whetstone_grit": 2},
		{&"riveted_plate": 5, &"whetstone_grit": 4},
		{&"riveted_plate": 8, &"cold_iron_core": 1},
	],
	&"string": [
		{&"tension_coil": 3},
		{&"tension_coil": 6, &"whetstone_grit": 2},
		{&"tension_coil": 10, &"cold_iron_core": 1},
	],
	&"chain": [
		{&"tension_coil": 4},
		{&"tension_coil": 8, &"riveted_plate": 3},
		{&"tension_coil": 12, &"cold_iron_core": 1},
	],
}


## One catalogue line. `cost` grows with `Game.upgrades[id]` for the repeatables,
## so the third sharpening is not the same price as the first, and `parts` is the
## component half of the same bill -- empty for anything the smith just has.
##
## `detail` is the sentence that says what the rung DOES, in the unit the player
## feels it in, with the number they have now and the number they would have.
## A line that only says "SHARPEN BLADE" is asking them to take it on faith.
static func lines() -> Array[Dictionary]:
	return [
		{
			"id": &"arrows",
			"label": "ARROWS X10",
			"cost": 40,
			"parts": {},
			"blurb": "Fletched from something that used to fly.",
			"detail": _arrow_detail(),
		},
		{
			"id": &"bag_slot",
			"label": "BAG SLOT",
			"cost": _scaled(140, &"bag_slot", 1.6),
			"parts": {},
			"blurb": "One more thing you can carry, and lose.",
			"detail": "%d slots -> %d" % [Game.bag_slots, Game.bag_slots + 1],
		},
		{
			"id": &"heart",
			"label": "HEART CONTAINER",
			"cost": _scaled(320, &"heart", 1.5),
			"parts": {},
			"blurb": "One more heart. It does not grow back on its own.",
			"detail": "%d hearts -> %d" % [
				Game.max_quarters / K.HEART, Game.max_quarters / K.HEART + 1],
		},
		_forge(&"edge", "SHARPEN THE BLADE", 120, 2.1,
			"Takes a quarter-heart more off whatever it meets.",
			K.EDGE_DAMAGE, "+%d", "quarters"),
		_forge(&"plate", "TEMPER THE ARMOUR", 140, 2.1,
			"Every blow lands a quarter-heart lighter. Never lighter than one.",
			K.PLATE_SOAK, "-%d", "quarters soaked"),
		_forge(&"guard", "BIND THE SHIELD", 110, 2.2,
			"A wider face. It catches what comes in off the shoulder.",
			K.GUARD_ARC, "%.0f", "degree guard"),
		_forge(&"string", "STRING THE BOW", 130, 2.1,
			"Draws faster. The shot owns you for less of the fight.",
			K.BOW_DRAW, "%.2f", "s draw"),
		_forge(&"chain", "LENGTHEN THE CHAIN", 150, 2.1,
			"More chain on the drum. The far side gets closer.",
			K.CHAIN_REACH, "%.1f", "m reach"),
	]


## Build a forge line. `ladder` is the K array the track reads and `unit` is a
## format string for ONE of its entries, so the detail text is generated from the
## same table the gear obeys -- a screen that hardcoded "+3 quarters" would be
## the next thing to drift when the tuning moves.
## `fmt` formats one rung's number and `noun` names the unit ONCE, at the end:
## "8.7 -> 11.9 m reach", not "8.7 m reach -> 11.9 m reach". The unit on both
## sides pushed the shop's blurb line past the width of the panel, and a line
## the player has to read twice to find the one number that changed is worse
## than the shorter one anyway.
static func _forge(id: StringName, label: String, base: int, growth: float,
		blurb: String, ladder: Array, fmt: String, noun: String) -> Dictionary:
	var lvl: int = Game.forge_level(id)
	var recipes: Array = PARTS[id]
	var detail := fmt % ladder[lvl]
	if lvl < recipes.size():
		detail = "%s -> %s %s" % [detail, fmt % ladder[lvl + 1], noun]
	else:
		detail = "%s %s  (finished)" % [detail, noun]
	return {
		"id": id,
		"label": label,
		"cost": _scaled(base, id, growth),
		"parts": next_parts(id),
		"blurb": blurb,
		"detail": detail,
	}


## What the NEXT rung of `id` costs in components, or `{}` when the ladder is
## finished or `id` is not a forge track.
static func next_parts(id: StringName) -> Dictionary:
	if not PARTS.has(id):
		return {}
	var recipes: Array = PARTS[id]
	var owned: int = Game.forge_level(id)
	if owned >= recipes.size():
		return {}
	return recipes[owned]


static func _arrow_detail() -> String:
	return "%d / %d arrows" % [Game.arrows, Game.max_arrows]


static func _scaled(base: int, id: StringName, factor: float) -> int:
	var owned: int = Game.upgrades.get(id, 0)
	return int(round(base * pow(factor, float(owned))))


## How many more of `id` the player may buy. -1 means unlimited.
static func remaining(id: StringName) -> int:
	if not LIMITS.has(id):
		return -1
	return maxi(0, int(LIMITS[id]) - int(Game.upgrades.get(id, 0)))


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


## Why a line is refused, in one phrase, for the footer. The screen used to say
## "NOT ENOUGH GOLD" for every refusal, which was a lie two thirds of the time
## the moment components existed -- and a shop that misreports the reason sends
## the player back down for the wrong thing.
static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return "NOTHING LEFT TO DO THERE"
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return "THE QUIVER IS FULL"
	var parts: Dictionary = line.get("parts", {})
	for pid: StringName in parts:
		if Game.component_count(pid) < int(parts[pid]):
			var def := ItemDb.get_def(pid)
			var what: String = def.display_name if def != null else String(pid)
			return "NOT ENOUGH %s" % what.to_upper()
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Take the money AND the components, then apply the effect. Returns false if it
## could not happen, so the caller can play a refusal instead of a chime.
##
## The order matters and it is checked-then-charged: `can_buy` has already said
## the whole bill is payable, so nothing below can leave a player half-charged
## for a rung they did not get.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	var parts: Dictionary = line.get("parts", {})
	if not Game.spend_gold(int(line["cost"])):
		return false
	for pid: StringName in parts:
		Game.spend_component(pid, int(parts[pid]))

	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	match id:
		&"arrows":
			Game.add_arrows(10)
		&"bag_slot":
			Game.bag_slots += 1
		&"heart":
			Game.add_heart_container()
		_:
			# Every forge track. There is nothing to apply: the rung IS the
			# effect, and the gear reads it off Game the next time it spawns.
			# Adding a per-track branch here would be a second place that has to
			# agree with K's ladders, and it would eventually not.
			Bus.gear_forged.emit(id, Game.upgrades[id])
	Bus.item_acquired.emit(id)
	return true
