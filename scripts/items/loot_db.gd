class_name LootDB
extends RefCounted
## The ingredient table and the drop tables, in one place.
##
## Declared in code rather than as six .tres files on purpose: docs/METAGAME.md
## is the source of truth for these numbers, and a single table next to the
## lookup is the version a human can diff against that document. Six separate
## resource files would drift silently.
##
## Everything is built once and cached — `LootDB.get_item(&"bone_shard")`.

const BONE_SHARD := &"bone_shard"
const GOBLIN_FANG := &"goblin_fang"
const KOBOLD_ICHOR := &"kobold_ichor"
const ORC_PLATE := &"orc_plate"
const GRAVE_EMBER := &"grave_ember"
const WRAITH_CORE := &"wraith_core"

static var _items: Dictionary[StringName, LootItem] = {}


static func _build() -> void:
	if not _items.is_empty():
		return
	# id, name, sell, stack, band, colour, description
	# Bands and sell values are docs/METAGAME.md §4. The two band-1 items are
	# consumed by recipes at EVERY tier, which is what stops them decaying into
	# vendor trash once the player is deep.
	var table: Array[LootItem] = [
		LootItem.make(BONE_SHARD, "Bone Shard", 6, 9, 1,
			Color(0.86, 0.84, 0.74),
			"Splintered and dry. Every smith in the Lower Worlds wants them by the sackful."),
		LootItem.make(GOBLIN_FANG, "Goblin Fang", 10, 9, 1,
			Color(0.78, 0.66, 0.32),
			"Still warm. Holds an edge better than it has any right to."),
		LootItem.make(KOBOLD_ICHOR, "Kobold Ichor", 22, 9, 2,
			Color(0.36, 0.78, 0.44),
			"Congeals into a lacquer that eats rust."),
		LootItem.make(ORC_PLATE, "Orc Scale-Plate", 34, 6, 2,
			Color(0.42, 0.47, 0.56),
			"Torn from a shoulder. Someone hammered this flat the hard way."),
		LootItem.make(GRAVE_EMBER, "Grave Ember", 60, 4, 3,
			Color(1.0, 0.52, 0.22),
			"Cold to the touch and burning underneath. Chests this deep are never empty."),
		LootItem.make(WRAITH_CORE, "Wraith Core", 110, 3, 3,
			Color(0.55, 0.42, 0.92),
			"What is left when something that hated you stops existing."),
	]
	for it in table:
		_items[it.id] = it


static func get_item(id: StringName) -> LootItem:
	_build()
	return _items.get(id, null)


static func all() -> Array[LootItem]:
	_build()
	var out: Array[LootItem] = []
	for id in _items:
		out.append(_items[id])
	return out


static func sell_value(id: StringName) -> int:
	var it := get_item(id)
	return it.sell_value if it != null else 0


static func display_name(id: StringName) -> String:
	var it := get_item(id)
	return it.display_name if it != null else String(id)


static func color_of(id: StringName) -> Color:
	var it := get_item(id)
	return it.color if it != null else Color.WHITE


# --- Drop tables -------------------------------------------------------------

## What each enemy kind drops. Weighted rolls of (id, min, max, chance).
## Kept small and legible: an enemy is recognisable by what it gives you.
const ENEMY_DROPS := {
	&"skeleton": [[BONE_SHARD, 1, 2, 0.90], [GOBLIN_FANG, 1, 1, 0.10]],
	&"goblin": [[GOBLIN_FANG, 1, 2, 0.85], [BONE_SHARD, 1, 1, 0.25]],
	&"kobold": [[KOBOLD_ICHOR, 1, 2, 0.80], [GOBLIN_FANG, 1, 1, 0.30]],
	&"orc": [[ORC_PLATE, 1, 1, 0.75], [KOBOLD_ICHOR, 1, 2, 0.35]],
	&"wraith": [[WRAITH_CORE, 1, 1, 0.55], [GRAVE_EMBER, 1, 1, 0.45]],
}

## Chests, by depth band. Deeper chests are the only reliable Grave Ember
## source, which is what makes pushing past room 3 worth the extraction fee.
const CHEST_DROPS := {
	1: [[BONE_SHARD, 2, 4, 1.0], [GOBLIN_FANG, 1, 3, 0.70]],
	2: [[GOBLIN_FANG, 2, 3, 0.80], [KOBOLD_ICHOR, 1, 3, 0.70], [GRAVE_EMBER, 1, 1, 0.35]],
	3: [[ORC_PLATE, 1, 2, 0.70], [GRAVE_EMBER, 1, 2, 0.65], [WRAITH_CORE, 1, 1, 0.20]],
}


## Roll a drop table into a flat list of (id, count) pairs.
## `rng` is passed in so a run can be reproduced from its seed.
static func roll(table: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for entry in table:
		var id: StringName = entry[0]
		var lo: int = entry[1]
		var hi: int = entry[2]
		var chance: float = entry[3]
		if rng.randf() > chance:
			continue
		var n := rng.randi_range(lo, hi)
		if n > 0:
			out.append([id, n])
	return out


static func roll_enemy(kind: StringName, rng: RandomNumberGenerator) -> Array:
	var table: Array = ENEMY_DROPS.get(kind, [])
	return roll(table, rng)


static func roll_chest(band: int, rng: RandomNumberGenerator) -> Array:
	var table: Array = CHEST_DROPS.get(clampi(band, 1, 3), [])
	return roll(table, rng)
