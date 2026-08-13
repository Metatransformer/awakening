class_name GardenState
extends RefCounted
## Persistent mutable state and atomic bag transactions for the garden.

signal changed

var _plots: Array[Dictionary] = []
var _trees: Array[Dictionary] = []


func _init() -> void:
	_plots = _empty_plots()
	_trees = _empty_trees()


func reset() -> void:
	var was_changed := not _is_reset()
	_plots = _empty_plots()
	_trees = _empty_trees()
	if was_changed:
		changed.emit()


func snapshot() -> Dictionary:
	return {
		"plots": _plots.duplicate(true),
		"trees": _trees.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	var restored_plots := _empty_plots()
	var raw_plots: Variant = data.get("plots", [])
	if raw_plots is Array:
		for slot in mini((raw_plots as Array).size(), GardenDb.PLOT_SLOTS):
			var raw: Variant = (raw_plots as Array)[slot]
			if raw is Dictionary:
				restored_plots[slot] = _restore_plot(raw as Dictionary)

	var restored_trees := _empty_trees()
	var raw_trees: Variant = data.get("trees", [])
	if raw_trees is Array:
		for site in mini((raw_trees as Array).size(), GardenDb.TREE_SITES):
			var raw: Variant = (raw_trees as Array)[site]
			if raw is Dictionary:
				restored_trees[site] = _restore_tree(raw as Dictionary)

	var was_changed := restored_plots != _plots or restored_trees != _trees
	_plots = restored_plots
	_trees = restored_trees
	if was_changed:
		changed.emit()


func plot(slot: int) -> Dictionary:
	return _plots[slot].duplicate(true) if _valid_plot_slot(slot) else {}


func tree(site: int) -> Dictionary:
	return _trees[site].duplicate(true) if _valid_tree_site(site) else {}


func plant_plot(slot: int, seed_id: StringName, _current_day: int = 0) -> bool:
	if not _valid_plot_slot(slot) or not GardenDb.is_seed(seed_id):
		return false
	var crop_id := GardenDb.crop_for_seed(seed_id)
	if crop_id == &"" or StringName(_plots[slot]["crop_id"]) != &"" \
			or int(Run.bag.get(seed_id, 0)) < 1:
		return false
	if Run.consume(seed_id, 1) != 1:
		return false
	_plots[slot] = _empty_plot()
	_plots[slot]["crop_id"] = crop_id
	changed.emit()
	return true


func water_plot(slot: int, _current_day: int = 0) -> bool:
	if not _valid_plot_slot(slot):
		return false
	var crop_id := StringName(_plots[slot]["crop_id"])
	if crop_id == &"" or _plot_ready(_plots[slot]) or bool(_plots[slot]["watered"]):
		return false
	_plots[slot]["watered"] = true
	changed.emit()
	return true


func harvest_plot(slot: int, _current_day: int = 0) -> bool:
	if not _valid_plot_slot(slot) or not _plot_ready(_plots[slot]):
		return false
	var crop_id := StringName(_plots[slot]["crop_id"])
	var amount := GardenDb.harvest_yield(crop_id)
	if amount <= 0 or Run.room_for(crop_id) < amount:
		return false
	if Run.collect(crop_id, amount) != amount:
		return false
	_plots[slot] = _empty_plot()
	changed.emit()
	return true


func plant_tree(site: int, sapling_id: StringName, _current_day: int = 0) -> bool:
	if not _valid_tree_site(site) or not GardenDb.is_sapling(sapling_id):
		return false
	var tree_id := GardenDb.tree_for_sapling(sapling_id)
	if tree_id == &"" or StringName(_trees[site]["tree_id"]) != &"" \
			or int(Run.bag.get(sapling_id, 0)) < 1:
		return false
	if Run.consume(sapling_id, 1) != 1:
		return false
	_trees[site] = _empty_tree()
	_trees[site]["tree_id"] = tree_id
	changed.emit()
	return true


func water_tree(site: int, _current_day: int = 0) -> bool:
	if not _valid_tree_site(site):
		return false
	var tree_id := StringName(_trees[site]["tree_id"])
	if tree_id == &"" or _tree_mature(_trees[site]) \
			or bool(_trees[site]["watered"]):
		return false
	_trees[site]["watered"] = true
	changed.emit()
	return true


func harvest_tree(site: int, current_day: int = 0) -> bool:
	if not _valid_tree_site(site) or not bool(_trees[site]["fruit_ready"]):
		return false
	var tree_id := StringName(_trees[site]["tree_id"])
	var amount := GardenDb.harvest_yield(tree_id)
	if amount <= 0 or Run.room_for(tree_id) < amount:
		return false
	if Run.collect(tree_id, amount) != amount:
		return false
	_trees[site]["fruit_ready"] = false
	_trees[site]["next_fruit_day"] = maxi(0, current_day) \
		+ GardenDb.cadence_days(tree_id)
	changed.emit()
	return true


func advance_dawn(day: int) -> void:
	var did_change := false
	for plot_state: Dictionary in _plots:
		var crop_id := StringName(plot_state["crop_id"])
		if crop_id == &"" or _plot_ready(plot_state):
			continue
		if bool(plot_state["watered"]):
			plot_state["growth"] = mini(int(plot_state["growth"]) + 1,
				GardenDb.growth_days(crop_id))
			plot_state["watered"] = false
			did_change = true

	for tree_state: Dictionary in _trees:
		var tree_id := StringName(tree_state["tree_id"])
		if tree_id == &"":
			continue
		if not _tree_mature(tree_state):
			if bool(tree_state["watered"]):
				tree_state["age"] = mini(int(tree_state["age"]) + 1,
					GardenDb.growth_days(tree_id))
				tree_state["watered"] = false
				if _tree_mature(tree_state):
					tree_state["next_fruit_day"] = maxi(0, day) \
						+ GardenDb.cadence_days(tree_id)
				did_change = true
		elif not bool(tree_state["fruit_ready"]) \
				and day >= int(tree_state["next_fruit_day"]):
			tree_state["fruit_ready"] = true
			did_change = true
	if did_change:
		changed.emit()


func _restore_plot(raw: Dictionary) -> Dictionary:
	var restored := _empty_plot()
	var crop_id := _valid_id(raw.get("crop_id", &""), true)
	if crop_id == &"":
		return restored
	restored["crop_id"] = crop_id
	restored["growth"] = clampi(_safe_int(raw.get("growth", 0)), 0,
		GardenDb.growth_days(crop_id))
	restored["watered"] = _safe_bool(raw.get("watered", false)) \
		and not _plot_ready(restored)
	return restored


func _restore_tree(raw: Dictionary) -> Dictionary:
	var restored := _empty_tree()
	var tree_id := _valid_id(raw.get("tree_id", &""), false)
	if tree_id == &"":
		return restored
	restored["tree_id"] = tree_id
	restored["age"] = clampi(_safe_int(raw.get("age", 0)), 0,
		GardenDb.growth_days(tree_id))
	var mature := _tree_mature(restored)
	restored["watered"] = _safe_bool(raw.get("watered", false)) and not mature
	restored["fruit_ready"] = _safe_bool(raw.get("fruit_ready", false)) and mature
	restored["next_fruit_day"] = maxi(0,
		_safe_int(raw.get("next_fruit_day", 0))) if mature else 0
	return restored


func _plot_ready(plot_state: Dictionary) -> bool:
	var crop_id := StringName(plot_state.get("crop_id", &""))
	return GardenDb.is_crop(crop_id) \
		and int(plot_state.get("growth", 0)) >= GardenDb.growth_days(crop_id)


func _tree_mature(tree_state: Dictionary) -> bool:
	var tree_id := StringName(tree_state.get("tree_id", &""))
	return GardenDb.is_tree(tree_id) \
		and int(tree_state.get("age", 0)) >= GardenDb.growth_days(tree_id)


func _valid_id(raw: Variant, crop: bool) -> StringName:
	if raw is not String and raw is not StringName:
		return &""
	var id := StringName(raw)
	return id if (GardenDb.is_crop(id) if crop else GardenDb.is_tree(id)) else &""


func _safe_int(raw: Variant) -> int:
	return int(raw) if raw is int or raw is float else 0


func _safe_bool(raw: Variant) -> bool:
	return bool(raw) if raw is bool else false


func _valid_plot_slot(slot: int) -> bool:
	return slot >= 0 and slot < GardenDb.PLOT_SLOTS


func _valid_tree_site(site: int) -> bool:
	return site >= 0 and site < GardenDb.TREE_SITES


func _is_reset() -> bool:
	return _plots == _empty_plots() and _trees == _empty_trees()


func _empty_plots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _slot in GardenDb.PLOT_SLOTS:
		out.append(_empty_plot())
	return out


func _empty_trees() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _site in GardenDb.TREE_SITES:
		out.append(_empty_tree())
	return out


func _empty_plot() -> Dictionary:
	return {"crop_id": &"", "growth": 0, "watered": false}


func _empty_tree() -> Dictionary:
	return {
		"tree_id": &"", "age": 0, "watered": false,
		"fruit_ready": false, "next_fruit_day": 0,
	}
