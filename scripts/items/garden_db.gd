class_name GardenDb
extends RefCounted
## Code-authored authority for the garrison garden's fixed sites and plants.

const PLOT_SLOTS: int = 4
const TREE_SITES: int = 2
const PLOT_COUNT: int = PLOT_SLOTS
const TREE_SITE_COUNT: int = TREE_SITES

const CROP_IDS: Array[StringName] = [&"turnip", &"cabbage", &"sunpepper"]
const TREE_IDS: Array[StringName] = [&"apple", &"pear"]
const SEED_IDS: Array[StringName] = [
	&"turnip_seed", &"cabbage_seed", &"sunpepper_seed",
]
const SAPLING_IDS: Array[StringName] = [&"apple_sapling", &"pear_sapling"]
const CROP_SEED_IDS: Array[StringName] = SEED_IDS
const TREE_SAPLING_IDS: Array[StringName] = SAPLING_IDS
const PLANTING_IDS: Array[StringName] = [
	&"turnip_seed", &"cabbage_seed", &"sunpepper_seed",
	&"apple_sapling", &"pear_sapling",
]
const PRODUCE_IDS: Array[StringName] = [
	&"turnip", &"cabbage", &"sunpepper", &"apple", &"pear",
]

const _CROPS: Dictionary = {
	&"turnip": {
		"name": "Turnip", "planting_id": &"turnip_seed", "growth": 2,
		"yield": 1, "tint": Color(0.78, 0.72, 0.84), "value": 2,
	},
	&"cabbage": {
		"name": "Cabbage", "planting_id": &"cabbage_seed", "growth": 3,
		"yield": 1, "tint": Color(0.42, 0.68, 0.38), "value": 3,
	},
	&"sunpepper": {
		"name": "Sunpepper", "planting_id": &"sunpepper_seed", "growth": 4,
		"yield": 1, "tint": Color(0.92, 0.48, 0.18), "value": 4,
	},
}
const _TREES: Dictionary = {
	&"apple": {
		"name": "Apple", "planting_id": &"apple_sapling", "growth": 4,
		"cadence": 3, "yield": 2, "tint": Color(0.78, 0.24, 0.20),
		"value": 12,
	},
	&"pear": {
		"name": "Pear", "planting_id": &"pear_sapling", "growth": 5,
		"cadence": 4, "yield": 2, "tint": Color(0.66, 0.76, 0.26),
		"value": 16,
	},
}


static func crop_ids() -> Array[StringName]:
	return CROP_IDS.duplicate()


static func tree_ids() -> Array[StringName]:
	return TREE_IDS.duplicate()


static func planting_ids() -> Array[StringName]:
	return PLANTING_IDS.duplicate()


static func produce_ids() -> Array[StringName]:
	return PRODUCE_IDS.duplicate()


static func is_crop(id: StringName) -> bool:
	return _CROPS.has(id)


static func is_tree(id: StringName) -> bool:
	return _TREES.has(id)


static func is_seed(id: StringName) -> bool:
	return SEED_IDS.has(id)


static func is_sapling(id: StringName) -> bool:
	return SAPLING_IDS.has(id)


static func is_planting(id: StringName) -> bool:
	return PLANTING_IDS.has(id)


static func is_produce(id: StringName) -> bool:
	return PRODUCE_IDS.has(id)


static func crop_for_seed(seed_id: StringName) -> StringName:
	for crop_id: StringName in CROP_IDS:
		if planting_id(crop_id) == seed_id:
			return crop_id
	return &""


static func tree_for_sapling(sapling_id: StringName) -> StringName:
	for tree_id: StringName in TREE_IDS:
		if planting_id(tree_id) == sapling_id:
			return tree_id
	return &""


static func planting_id(id: StringName) -> StringName:
	var definition := _definition(id)
	return StringName(definition.get("planting_id", &""))


static func produce_id(id: StringName) -> StringName:
	var plant_id := _plant_id(id)
	return plant_id if is_crop(plant_id) or is_tree(plant_id) else &""


static func produce_for_crop(crop_id: StringName) -> StringName:
	return produce_id(crop_id) if is_crop(crop_id) else &""


static func produce_for_tree(tree_id: StringName) -> StringName:
	return produce_id(tree_id) if is_tree(tree_id) else &""


static func name_of(id: StringName) -> String:
	var plant_id := _plant_id(id)
	var definition := _definition(plant_id)
	var base_name := String(definition.get("name", ""))
	if is_seed(id):
		return "%s Seed" % base_name
	if is_sapling(id):
		return "%s Sapling" % base_name
	return base_name


static func tint_of(id: StringName) -> Color:
	return _definition(_plant_id(id)).get("tint", Pal.ASH) as Color


static func growth_days(id: StringName) -> int:
	return maxi(0, int(_definition(_plant_id(id)).get("growth", 0)))


static func cadence_days(id: StringName) -> int:
	return maxi(0, int(_definition(_plant_id(id)).get("cadence", 0)))


static func harvest_yield(id: StringName) -> int:
	return maxi(0, int(_definition(_plant_id(id)).get("yield", 0)))


static func planting_stack(id: StringName) -> int:
	if is_seed(id):
		return 12
	if is_sapling(id):
		return 2
	return 0


static func planting_value(id: StringName) -> int:
	return maxi(0, int(_definition(_plant_id(id)).get("value", 0))) \
		if is_planting(id) else 0


static func row(id: StringName) -> Dictionary:
	var plant_id := _plant_id(id)
	var definition := _definition(plant_id)
	if definition.is_empty():
		return {}
	var out := definition.duplicate(true)
	out["id"] = plant_id
	out["produce_id"] = plant_id
	out["type"] = &"crop" if is_crop(plant_id) else &"tree"
	return out


static func _plant_id(id: StringName) -> StringName:
	if is_crop(id) or is_tree(id):
		return id
	var crop_id := crop_for_seed(id)
	if crop_id != &"":
		return crop_id
	return tree_for_sapling(id)


static func _definition(id: StringName) -> Dictionary:
	var raw: Variant = _CROPS.get(id, _TREES.get(id, {}))
	return raw as Dictionary if raw is Dictionary else {}
