class_name SupplyCargoDb
extends RefCounted
## Stable code-authored catalogue for provisions carried in the Run bag.
##
## These rows are not editor Resources because they have no per-instance state
## or Inspector workflow. IDs, fishing tiers, and fight tuning live together so
## the pond, bag, and garrison crate cannot each invent a different fish.

const FIREWOOD_ID: StringName = &"firewood_bundle"
const POND_SHINER_ID: StringName = &"pond_shiner"
const RIVER_PERCH_ID: StringName = &"river_perch"
const SILVER_TROUT_ID: StringName = &"silver_trout"
const CROWN_PIKE_ID: StringName = &"crown_pike"

const CATEGORY_FIREWOOD: StringName = &"firewood"
const CATEGORY_FOOD: StringName = &"food"

const FISH_IDS: Array[StringName] = [
	POND_SHINER_ID,
	RIVER_PERCH_ID,
	SILVER_TROUT_ID,
	CROWN_PIKE_ID,
]
const SUPPLY_IDS: Array[StringName] = [
	FIREWOOD_ID,
	POND_SHINER_ID,
	RIVER_PERCH_ID,
	SILVER_TROUT_ID,
	CROWN_PIKE_ID,
	&"turnip",
	&"cabbage",
	&"sunpepper",
	&"apple",
	&"pear",
]
const FOOD_IDS: Array[StringName] = [
	POND_SHINER_ID,
	RIVER_PERCH_ID,
	SILVER_TROUT_ID,
	CROWN_PIKE_ID,
	&"turnip",
	&"cabbage",
	&"sunpepper",
	&"apple",
	&"pear",
]

const _FIREWOOD_ROW: Dictionary = {
	"id": FIREWOOD_ID,
	"name": "Firewood Bundle",
	"tier": 0,
	"food_units": 0,
	"category": CATEGORY_FIREWOOD,
}
const _FISH_ROWS: Array[Dictionary] = [
	{"id": POND_SHINER_ID, "name": "Pond Shiner", "tier": 1,
		"food_units": 1, "category": CATEGORY_FOOD},
	{"id": RIVER_PERCH_ID, "name": "River Perch", "tier": 2,
		"food_units": 1, "category": CATEGORY_FOOD},
	{"id": SILVER_TROUT_ID, "name": "Silver Trout", "tier": 3,
		"food_units": 1, "category": CATEGORY_FOOD},
	{"id": CROWN_PIKE_ID, "name": "Crown Pike", "tier": 4,
		"food_units": 1, "category": CATEGORY_FOOD},
]

## Relative tier weights, not percentages. Keeping the authored values visible
## makes tuning reviewable; `roll_fish` validates and normalizes a copy.
const _SPOT_TIER_WEIGHTS: Dictionary = {
	1: [75, 20, 4, 1],
	2: [48, 32, 15, 5],
	3: [25, 34, 28, 13],
	4: [10, 25, 37, 28],
}

## Every rate is per second. Tiers narrow the hook window and ask for faster,
## more accurate steering without changing the fight vocabulary.
const _TIER_TUNING: Dictionary = {
	1: {"hook_window": 1.20, "run_interval": 1.55, "initial_tension": 0.20,
		"tension_recovery": 0.32, "correct_reel_rate": 0.29,
		"no_reel_escape_rate": 0.08, "wrong_tension_gain": 0.28,
		"neutral_tension_gain": 0.15},
	2: {"hook_window": 1.00, "run_interval": 1.30, "initial_tension": 0.24,
		"tension_recovery": 0.28, "correct_reel_rate": 0.24,
		"no_reel_escape_rate": 0.09, "wrong_tension_gain": 0.34,
		"neutral_tension_gain": 0.19},
	3: {"hook_window": 0.82, "run_interval": 1.05, "initial_tension": 0.29,
		"tension_recovery": 0.23, "correct_reel_rate": 0.19,
		"no_reel_escape_rate": 0.10, "wrong_tension_gain": 0.40,
		"neutral_tension_gain": 0.24},
	4: {"hook_window": 0.68, "run_interval": 0.82, "initial_tension": 0.35,
		"tension_recovery": 0.18, "correct_reel_rate": 0.15,
		"no_reel_escape_rate": 0.12, "wrong_tension_gain": 0.47,
		"neutral_tension_gain": 0.30},
}


static func fish_ids() -> Array[StringName]:
	return FISH_IDS.duplicate()


static func food_ids() -> Array[StringName]:
	return FOOD_IDS.duplicate()


static func all_supply_ids() -> Array[StringName]:
	return SUPPLY_IDS.duplicate()


static func is_fish(id: StringName) -> bool:
	return FISH_IDS.has(id)


static func is_supply(id: StringName) -> bool:
	return SUPPLY_IDS.has(id)


static func row(id: StringName) -> Dictionary:
	if id == FIREWOOD_ID:
		return _FIREWOOD_ROW.duplicate(true)
	for fish_row: Dictionary in _FISH_ROWS:
		if fish_row["id"] == id:
			return fish_row.duplicate(true)
	if GardenDb.is_produce(id):
		return {
			"id": id,
			"name": GardenDb.name_of(id),
			"tier": 0,
			"food_units": 1,
			"category": CATEGORY_FOOD,
		}
	return {}


static func name_of(id: StringName) -> String:
	var supply_row := row(id)
	return String(supply_row.get("name", ""))


static func tier_of(id: StringName) -> int:
	var supply_row := row(id)
	return int(supply_row.get("tier", 0))


static func food_units(id: StringName) -> int:
	var supply_row := row(id)
	return maxi(0, int(supply_row.get("food_units", 0)))


## Firewood and food are the first two crate destinations. Future crop and
## fruit rows extend the catalogue by declaring their category, not by teaching
## every depositor another list of IDs.
static func category_of(id: StringName) -> StringName:
	var supply_row := row(id)
	return StringName(supply_row.get("category", &""))


static func tuning(id: StringName) -> Dictionary:
	return tuning_for_tier(tier_of(id)) if is_fish(id) else {}


static func tuning_for_tier(tier: int) -> Dictionary:
	var raw: Variant = _TIER_TUNING.get(tier, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## Pure authored-data seam for previews, directors, and distribution tests.
static func tier_weights_for_spot(spot_level: int) -> Array[int]:
	var level := clampi(spot_level, 1, 4)
	var raw: Variant = _SPOT_TIER_WEIGHTS.get(level, [])
	var weights: Array[int] = []
	if raw is Array:
		for weight: Variant in raw:
			weights.append(int(weight))
	return weights


static func roll_fish(spot_level: int,
		rng: RandomNumberGenerator) -> StringName:
	if rng == null:
		return &""
	var authored := tier_weights_for_spot(spot_level)
	if authored.size() != FISH_IDS.size():
		return &""
	var weights: Array[float] = []
	var total := 0.0
	for weight: int in authored:
		var valid_weight := maxf(float(weight), 0.0)
		weights.append(valid_weight)
		total += valid_weight
	if total <= 0.0:
		return &""
	for i in weights.size():
		weights[i] /= total
	var pick := rng.randf()
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0:
			return FISH_IDS[i]
	return FISH_IDS.back()
