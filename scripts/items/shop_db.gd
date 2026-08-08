class_name ShopDb
extends RefCounted
## What the smith sells. Five lines, and every one of them changes a number the
## player can feel inside one run.
##
## Prices are set against the drop tables rather than against each other: a good
## run extracts with roughly 250-450 gold of ingredients, so the cheap lines are
## affordable after one run and the expensive ones after two or three. That is
## the whole pacing dial -- if a run pays for everything, the shop stops being a
## reason to go back down.
##
## Everything here is PERMANENT and lives on `Game`, because the only things
## worth buying with money that survives death are things that also survive it.

## Purchases you can only make so many times, and how many.
const LIMITS := {
	&"sharpen": 3,
	&"temper": 2,
	&"bag_slot": 4,
	&"heart": 3,
}


## One catalogue line. `cost` grows with `Game.upgrades[id]` for the repeatables,
## so the third sharpening is not the same price as the first.
static func lines() -> Array[Dictionary]:
	return [
		{
			"id": &"arrows",
			"label": "ARROWS X10",
			"cost": 40,
			"blurb": "Fletched from something that used to fly.",
		},
		{
			"id": &"bag_slot",
			"label": "BAG SLOT",
			"cost": _scaled(140, &"bag_slot", 1.6),
			"blurb": "One more thing you can carry, and lose.",
		},
		{
			"id": &"sharpen",
			"label": "SHARPEN BLADE",
			"cost": _scaled(220, &"sharpen", 1.7),
			"blurb": "Takes a quarter-heart more off whatever it meets.",
		},
		{
			"id": &"temper",
			"label": "TEMPER ARMOUR",
			"cost": _scaled(260, &"temper", 1.8),
			"blurb": "Every blow lands a quarter-heart lighter.",
		},
		{
			"id": &"heart",
			"label": "HEART CONTAINER",
			"cost": _scaled(320, &"heart", 1.5),
			"blurb": "One more heart. It does not grow back on its own.",
		},
	]


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
	return Game.gold >= int(line["cost"])


## Take the money and apply the effect. Returns false if it could not happen, so
## the caller can play a refusal instead of a chime.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	if not Game.spend_gold(int(line["cost"])):
		return false

	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	match id:
		&"arrows":
			Game.add_arrows(10)
		&"bag_slot":
			Game.bag_slots += 1
		&"sharpen":
			Game.sword_bonus += 1
		&"temper":
			Game.armour_level += 1
		&"heart":
			Game.add_heart_container()
	Bus.item_acquired.emit(id)
	return true
