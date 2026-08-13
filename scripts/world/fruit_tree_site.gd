class_name FruitTreeSite
extends Interactable
## One permanent orchard site. Game owns age and fruit cadence; this node keeps
## planting, tending, picking, and the tree's staged low-poly presentation local.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

var slot: int = -1

var _mound_material: StandardMaterial3D
var _stake: Node3D
var _tree_visuals: Node3D


func configure(p_slot: int) -> void:
	slot = p_slot


func _ready() -> void:
	prompt = "PLANT TREE"
	radius = 1.45
	_build_site()
	super()
	if slot < 0 or slot >= GardenDb.TREE_SITES:
		push_error("FruitTreeSite: invalid slot %d" % slot)
		enabled = false
		return
	repaint()


func activate(by: Node3D) -> void:
	activated.emit(by)
	var state := _state()
	var tree_id := StringName(state.get(&"tree_id", &""))
	if tree_id == &"":
		_offer_saplings()
		return
	if not _is_mature(state, tree_id):
		if not bool(state.get(&"watered", false)):
			if Game.water_tree(slot):
				Bus.request_message.emit("%s WATERED." % GardenDb.name_of(tree_id).to_upper())
			return
		Bus.request_message.emit("%s IS ALREADY TENDED." % GardenDb.name_of(tree_id).to_upper())
		return
	if bool(state.get(&"fruit_ready", false)):
		_pick_fruit(tree_id)
		return
	var dawns := maxi(int(state.get(&"next_fruit_day", Clock.day)) - Clock.day, 0)
	var suffix := "" if dawns == 1 else "S"
	Bus.request_message.emit("%s WILL FRUIT IN %d DAWN%s." \
		% [GardenDb.name_of(tree_id).to_upper(), dawns, suffix])


## Called by GarrisonGarden after the shared state notification.
func repaint() -> void:
	if slot < 0:
		return
	var state := _state()
	var tree_id := StringName(state.get(&"tree_id", &""))
	var watered := bool(state.get(&"watered", false))
	_mound_material.albedo_color = Color(0.075, 0.045, 0.028) if watered \
		else Color(0.19, 0.105, 0.052)
	_rebuild_tree(state, tree_id)
	if tree_id == &"":
		prompt = "PLANT TREE"
	elif not _is_mature(state, tree_id):
		prompt = ("TENDED %s" if watered else "WATER %s") \
			% GardenDb.name_of(tree_id).to_upper()
	elif bool(state.get(&"fruit_ready", false)):
		var fruit_id := GardenDb.produce_id(tree_id)
		prompt = "PICK %s" % GardenDb.name_of(fruit_id).to_upper()
	else:
		prompt = "CHECK %s" % GardenDb.name_of(tree_id).to_upper()
	if Prompt.focus == self:
		Prompt.drop_focus()


func _state() -> Dictionary:
	return Game.garden_tree(slot)


func _offer_saplings() -> void:
	var carried := _carried_saplings()
	if carried.is_empty():
		Bus.request_message.emit("NO SAPLINGS. BUY ONE FROM THE QUARTERMASTER.")
		return
	if carried.size() == 1:
		_plant_direct(carried[0])
		return
	var choices: Array = []
	for sapling_id: StringName in carried:
		choices.append({
			"label": GardenDb.name_of(sapling_id),
			"meta": "Sapling",
			"icon": UiKit.item_icon(sapling_id),
			"act": _choose_sapling.bind(sapling_id),
		})
	choices.append({
		"label": "Leave",
		"icon": UiKit.action_icon("leave"),
		"act": _leave_site,
	})
	DialogueBox.open(self, &"alchemist",
		PackedStringArray(["Choose a sapling for this site."]), choices)


func _carried_saplings() -> Array[StringName]:
	var carried: Array[StringName] = []
	for sapling_id: StringName in GardenDb.SAPLING_IDS:
		if int(Run.bag.get(sapling_id, 0)) > 0:
			carried.append(sapling_id)
	return carried


func _plant_direct(sapling_id: StringName) -> void:
	var tree_id := GardenDb.tree_for_sapling(sapling_id)
	if Game.plant_tree(slot, sapling_id):
		Bus.request_message.emit("%s PLANTED." % GardenDb.name_of(tree_id).to_upper())
	else:
		Bus.request_message.emit("THAT SAPLING IS NO LONGER IN YOUR BAG.")


func _choose_sapling(sapling_id: StringName) -> PackedStringArray:
	var tree_id := GardenDb.tree_for_sapling(sapling_id)
	if Game.plant_tree(slot, sapling_id):
		return PackedStringArray(["%s planted." % GardenDb.name_of(tree_id)])
	return PackedStringArray(["That sapling is no longer in your bag."])


func _leave_site() -> PackedStringArray:
	return PackedStringArray(["The tree site is left undisturbed."])


func _pick_fruit(tree_id: StringName) -> void:
	var fruit_id := GardenDb.produce_id(tree_id)
	var amount := GardenDb.harvest_yield(tree_id)
	if Run.room_for(fruit_id) < amount:
		Bus.request_message.emit("BAG FULL — MAKE ROOM FOR %s." \
			% GardenDb.name_of(fruit_id).to_upper())
		return
	if Game.harvest_tree(slot):
		Bus.request_message.emit("%d %s PICKED." \
			% [amount, GardenDb.name_of(fruit_id).to_upper()])


func _is_mature(state: Dictionary, tree_id: StringName) -> bool:
	return int(state.get(&"age", 0)) >= GardenDb.growth_days(tree_id)


func _growth_fraction(state: Dictionary, tree_id: StringName) -> float:
	if tree_id == &"":
		return 0.0
	var days := maxf(float(GardenDb.growth_days(tree_id)), 1.0)
	return clampf(float(state.get(&"age", 0)) / days, 0.0, 1.0)


func _build_site() -> void:
	_mound_material = StandardMaterial3D.new()
	_mound_material.albedo_color = Color(0.19, 0.105, 0.052)
	_mound_material.roughness = 1.0
	var mound := MeshInstance3D.new()
	mound.name = &"PlantingMound"
	var mound_mesh := CylinderMesh.new()
	mound_mesh.top_radius = 0.52
	mound_mesh.bottom_radius = 0.64
	mound_mesh.height = 0.14
	mound_mesh.radial_segments = 10
	mound.mesh = mound_mesh
	mound.material_override = _mound_material
	mound.position.y = 0.07
	add_child(mound)

	_stake = Node3D.new()
	_stake.name = &"NurseryStake"
	add_child(_stake)
	_box(_stake, &"Stake", MAT_WOOD, Vector3(0.08, 1.0, 0.08),
		Vector3(0.28, 0.52, 0.0))
	_box(_stake, &"Tie", MAT_IRON, Vector3(0.34, 0.045, 0.06),
		Vector3(0.12, 0.48, 0.0))

	_tree_visuals = Node3D.new()
	_tree_visuals.name = &"TreeVisuals"
	add_child(_tree_visuals)


func _rebuild_tree(state: Dictionary, tree_id: StringName) -> void:
	for child: Node in _tree_visuals.get_children():
		child.queue_free()
	if tree_id == &"":
		_stake.visible = true
		return
	var fraction := maxf(_growth_fraction(state, tree_id), 0.08)
	var mature := _is_mature(state, tree_id)
	_stake.visible = not mature
	var trunk_height := lerpf(0.48, 2.20, fraction)
	var trunk_radius := lerpf(0.055, 0.19, fraction)
	_cylinder(_tree_visuals, &"Trunk", MAT_WOOD, trunk_radius,
		trunk_height, Vector3(0.0, 0.14 + trunk_height * 0.5, 0.0), 8)
	if fraction < 0.18:
		return
	var leaf_tint := Color(0.22, 0.48, 0.18).lerp(
		GardenDb.tint_of(tree_id), 0.10).darkened(0.08)
	var leaf_material := _material(leaf_tint, 0.08)
	var crown_scale := lerpf(0.22, 1.0, fraction)
	var crown_y := 0.14 + trunk_height
	var crowns: Array[Vector3] = [
		Vector3(0.0, 0.16, 0.0), Vector3(-0.42, -0.06, 0.08),
		Vector3(0.38, -0.02, 0.12), Vector3(0.05, -0.08, -0.38),
	]
	for i: int in crowns.size():
		var crown := _sphere(_tree_visuals, &"Crown", leaf_material, 0.58,
			crowns[i] * crown_scale + Vector3.UP * crown_y, 8, 4)
		crown.scale = Vector3(1.0, 0.76, 0.88) * crown_scale
	if mature and bool(state.get(&"fruit_ready", false)):
		_build_fruit(tree_id, crown_y)


func _build_fruit(tree_id: StringName, crown_y: float) -> void:
	var fruit_id := GardenDb.produce_id(tree_id)
	var fruit_material := _material(GardenDb.tint_of(fruit_id), 0.48)
	var positions: Array[Vector3] = [
		Vector3(-0.62, crown_y - 0.24, 0.52),
		Vector3(0.64, crown_y - 0.15, 0.36),
		Vector3(-0.24, crown_y - 0.36, -0.61),
		Vector3(0.51, crown_y + 0.06, -0.52),
		Vector3(0.04, crown_y + 0.38, 0.54),
	]
	for at: Vector3 in positions:
		var fruit := _sphere(_tree_visuals, &"RipeFruit", fruit_material,
			0.17, at, 7, 4)
		fruit.scale.y = 0.86


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, at: Vector3, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, node_name: StringName, material: Material,
		radius: float, at: Vector3, segments: int, rings: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance
