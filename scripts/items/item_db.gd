class_name ItemDb
extends RefCounted
## The catalogue. Every ingredient, and the tables that decide what drops.
##
## Values are spread across roughly one order of magnitude (4 to 90) on purpose.
## The extraction decision is only interesting when the bag's worth is uncertain,
## and it is only uncertain when a single rare drop can outweigh a full run of
## common ones. A flat table turns "do I leave now?" into arithmetic.

## id -> ItemDef. Built once, on first access.
static var _items: Dictionary = {}


static func all() -> Dictionary:
	if _items.is_empty():
		_build()
	return _items


static func get_def(id: StringName) -> ItemDef:
	return all().get(id, null) as ItemDef


static func _add(d: ItemDef) -> void:
	_items[d.id] = d


static func _build() -> void:
	const C := ItemDef.Rarity.COMMON
	const U := ItemDef.Rarity.UNCOMMON
	const R := ItemDef.Rarity.RARE

	_add(ItemDef.make(&"bone_shard", "Bone Shard", 4, C, 20,
		Color(0.86, 0.84, 0.74), "Splinters of something that used to walk."))
	_add(ItemDef.make(&"rot_moss", "Rot Moss", 6, C, 20,
		Color(0.42, 0.55, 0.30), "Grows only where the air does not move."))
	_add(ItemDef.make(&"cracked_flint", "Cracked Flint", 8, C, 20,
		Color(0.48, 0.50, 0.56), "Still sparks. Barely."))
	_add(ItemDef.make(&"grave_wax", "Grave Wax", 11, C, 15,
		Color(0.85, 0.79, 0.55), "Burns with a smell you will remember."))

	_add(ItemDef.make(&"iron_scrap", "Iron Scrap", 18, U, 12,
		Color(0.62, 0.60, 0.58), "Someone's armour, once. Smiths pay for it."))
	_add(ItemDef.make(&"ghost_silk", "Ghost Silk", 24, U, 12,
		Color(0.72, 0.78, 0.86), "Weightless. Cold to hold."))
	_add(ItemDef.make(&"ember_gland", "Ember Gland", 32, U, 10,
		Color(0.86, 0.42, 0.20), "Warm hours after the thing that grew it died."))

	_add(ItemDef.make(&"deep_amber", "Deep Amber", 55, R, 6,
		Color(0.93, 0.66, 0.16), "There is a shape inside. Do not look long."))
	_add(ItemDef.make(&"void_pearl", "Void Pearl", 78, R, 4,
		Color(0.55, 0.38, 0.78), "Light falls in and does not come back."))
	_add(ItemDef.make(&"kings_signet", "King's Signet", 90, R, 2,
		Color(0.95, 0.86, 0.42), "The Lower Worlds had a king. This is all that is left."))


# --- Drop tables ------------------------------------------------------------

## Weighted table for an ordinary enemy. Weights are relative, not percentages,
## so adding an entry never requires rebalancing the others.
const ENEMY_DROPS := {
	&"bone_shard": 34,
	&"rot_moss": 26,
	&"cracked_flint": 18,
	&"grave_wax": 12,
	&"iron_scrap": 7,
	&"ghost_silk": 3,
}

## Chests are the reason to explore off the critical path, so their floor is
## higher and their ceiling is where the run-defining drops live.
const CHEST_DROPS := {
	&"grave_wax": 20,
	&"iron_scrap": 24,
	&"ghost_silk": 20,
	&"ember_gland": 16,
	&"deep_amber": 12,
	&"void_pearl": 6,
	&"kings_signet": 2,
}


## Pick one id from a weight table. `rng` is passed in so a seeded run is
## reproducible -- a roguelike that cannot replay a seed cannot be debugged.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0
	for w: int in table.values():
		total += w
	if total <= 0:
		return &""
	var pick := rng.randi_range(1, total)
	for id: StringName in table:
		pick -= int(table[id])
		if pick <= 0:
			return id
	return table.keys().back()
