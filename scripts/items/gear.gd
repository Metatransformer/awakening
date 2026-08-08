class_name Gear
extends RefCounted
## The smith's two upgrade ladders (docs/METAGAME.md §8).
##
## Every rung costs gold **and** ingredients, so advancement always spends
## something finite and the two tracks genuinely compete for the same haul.
##
## Blade damage is in QUARTER hearts (K.QUARTER; 4 == one heart), matching the
## Hit interface in docs/CONTRACT.md §8. Armour adds heart containers.

enum Track { BLADE, ARMOR }

## Model ids handed to WeaponModels.make(), so a tier-up is visible in the
## hero's hand the moment it is bought.
const BLADE_MODELS: Array[StringName] = [
	&"sword_crude", &"sword_common", &"sword_elegant", &"sword_noble", &"sword_knightly",
]
const BLADE_NAMES: Array[String] = [
	"Crude Blade", "Common Blade", "Elegant Blade", "Noble Blade", "Knightly Blade",
]
## Damage per swing, in quarter-hearts.
const BLADE_DAMAGE: Array[int] = [2, 3, 4, 6, 8]

const ARMOR_NAMES: Array[String] = [
	"Travelling Clothes", "Padded Jerkin", "Ringmail", "Scaled Harness", "Knight's Plate",
]
## Total heart containers at each armour tier.
const ARMOR_HEARTS: Array[int] = [3, 4, 5, 6, 7]

const MAX_TIER := 4

## Cost to go FROM tier i TO tier i+1. Index 0 is the first purchase.
## [gold, {ingredient_id: count}]
const BLADE_COSTS: Array = [
	[120, {LootDB.BONE_SHARD: 6, LootDB.GOBLIN_FANG: 4}],
	[320, {LootDB.GOBLIN_FANG: 8, LootDB.KOBOLD_ICHOR: 5}],
	[700, {LootDB.ORC_PLATE: 6, LootDB.GRAVE_EMBER: 3}],
	[1500, {LootDB.GRAVE_EMBER: 4, LootDB.WRAITH_CORE: 2}],
]
const ARMOR_COSTS: Array = [
	[100, {LootDB.BONE_SHARD: 8}],
	[300, {LootDB.KOBOLD_ICHOR: 6, LootDB.ORC_PLATE: 4}],
	[700, {LootDB.ORC_PLATE: 5, LootDB.GRAVE_EMBER: 3}],
	[1400, {LootDB.GRAVE_EMBER: 3, LootDB.WRAITH_CORE: 2}],
]


static func costs_for(track: Track) -> Array:
	return BLADE_COSTS if track == Track.BLADE else ARMOR_COSTS


static func name_for(track: Track, tier: int) -> String:
	var t := clampi(tier, 0, MAX_TIER)
	return BLADE_NAMES[t] if track == Track.BLADE else ARMOR_NAMES[t]


static func blade_damage(tier: int) -> int:
	return BLADE_DAMAGE[clampi(tier, 0, MAX_TIER)]


static func blade_model(tier: int) -> StringName:
	return BLADE_MODELS[clampi(tier, 0, MAX_TIER)]


static func armor_hearts(tier: int) -> int:
	return ARMOR_HEARTS[clampi(tier, 0, MAX_TIER)]


## Gold price of the next rung, or -1 if the track is maxed.
static func next_gold(track: Track, tier: int) -> int:
	if tier >= MAX_TIER:
		return -1
	return int(costs_for(track)[tier][0])


## Ingredients the next rung consumes, or {} if maxed.
static func next_materials(track: Track, tier: int) -> Dictionary:
	if tier >= MAX_TIER:
		return {}
	return costs_for(track)[tier][1]


## One line of "what this buys you", for the smith's UI. Concrete numbers, not
## adjectives — the player is choosing between two tracks and needs to compare.
static func next_effect(track: Track, tier: int) -> String:
	if tier >= MAX_TIER:
		return "Nothing finer exists down here."
	if track == Track.BLADE:
		return "Damage %d -> %d quarter-hearts" % [blade_damage(tier), blade_damage(tier + 1)]
	return "Hearts %d -> %d" % [armor_hearts(tier), armor_hearts(tier + 1)]
