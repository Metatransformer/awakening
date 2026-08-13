class_name GardenPlot
extends Interactable
## One authored garden bed. Game owns its crop state; this node owns the prompt,
## carried-seed choice, and the physical read of that state in the yard.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")

const BED_SIZE := 1.3
const FRAME_WIDTH := 0.12

var slot: int = -1

var _soil: MeshInstance3D
var _soil_material: StandardMaterial3D
var _crop_visuals: Node3D


## GarrisonGarden configures the stable save slot before this node enters the tree.
func configure(p_slot: int) -> void:
	slot = p_slot


func _ready() -> void:
	prompt = "PLANT"
	radius = 1.25
	_build_bed()
	super()
	if slot < 0 or slot >= GardenDb.PLOT_SLOTS:
		push_error("GardenPlot: invalid slot %d" % slot)
		enabled = false
		return
	repaint()


func activate(by: Node3D) -> void:
	activated.emit(by)
	var state := _state()
	var crop_id := StringName(state.get(&"crop_id", &""))
	if crop_id == &"":
		_offer_seeds()
		return
	if _is_ready(state, crop_id):
		_harvest(crop_id)
		return
	if not bool(state.get(&"watered", false)):
		if Game.water_plot(slot):
			Bus.request_message.emit("%s WATERED." % GardenDb.name_of(crop_id).to_upper())
		return
	Bus.request_message.emit("%s IS ALREADY TENDED." % GardenDb.name_of(crop_id).to_upper())


## Called by GarrisonGarden after the one shared garrison-state notification.
func repaint() -> void:
	if slot < 0:
		return
	var state := _state()
	var crop_id := StringName(state.get(&"crop_id", &""))
	var watered := bool(state.get(&"watered", false))
	_soil_material.albedo_color = Color(0.075, 0.045, 0.028) if watered \
		else Color(0.19, 0.105, 0.052)
	_rebuild_crop(state, crop_id)
	if crop_id == &"":
		prompt = "PLANT"
	elif _is_ready(state, crop_id):
		prompt = "HARVEST %s" % GardenDb.name_of(crop_id).to_upper()
	elif watered:
		prompt = "TENDED %s" % GardenDb.name_of(crop_id).to_upper()
	else:
		prompt = "WATER %s" % GardenDb.name_of(crop_id).to_upper()
	if Prompt.focus == self:
		Prompt.drop_focus()


func _state() -> Dictionary:
	return Game.garden_plot(slot)


func _offer_seeds() -> void:
	var carried := _carried_seeds()
	if carried.is_empty():
		Bus.request_message.emit("NO SEEDS. BUY SOME FROM THE QUARTERMASTER.")
		return
	if carried.size() == 1:
		_plant_direct(carried[0])
		return
	var choices: Array = []
	for seed_id: StringName in carried:
		choices.append({
			"label": GardenDb.name_of(seed_id),
			"meta": "Seed",
			"icon": UiKit.item_icon(seed_id),
			"act": _choose_seed.bind(seed_id),
		})
	choices.append({
		"label": "Leave",
		"icon": UiKit.action_icon("leave"),
		"act": _leave_bed,
	})
	DialogueBox.open(self, &"alchemist",
		PackedStringArray(["Choose a seed for this bed."]), choices)


func _carried_seeds() -> Array[StringName]:
	var carried: Array[StringName] = []
	for seed_id: StringName in GardenDb.SEED_IDS:
		if int(Run.bag.get(seed_id, 0)) > 0:
			carried.append(seed_id)
	return carried


func _plant_direct(seed_id: StringName) -> void:
	var crop_id := GardenDb.crop_for_seed(seed_id)
	if Game.plant_plot(slot, seed_id):
		Bus.request_message.emit("%s PLANTED." % GardenDb.name_of(crop_id).to_upper())
	else:
		Bus.request_message.emit("THAT SEED IS NO LONGER IN YOUR BAG.")


func _choose_seed(seed_id: StringName) -> PackedStringArray:
	var crop_id := GardenDb.crop_for_seed(seed_id)
	if Game.plant_plot(slot, seed_id):
		return PackedStringArray(["%s planted." % GardenDb.name_of(crop_id)])
	return PackedStringArray(["That seed is no longer in your bag."])


func _leave_bed() -> PackedStringArray:
	return PackedStringArray(["The bed is left undisturbed."])


func _harvest(crop_id: StringName) -> void:
	var produce_id := GardenDb.produce_id(crop_id)
	var amount := GardenDb.harvest_yield(crop_id)
	if Run.room_for(produce_id) < amount:
		Bus.request_message.emit("BAG FULL — MAKE ROOM FOR %s." \
			% GardenDb.name_of(produce_id).to_upper())
		return
	if Game.harvest_plot(slot):
		Bus.request_message.emit("%d %s HARVESTED." \
			% [amount, GardenDb.name_of(produce_id).to_upper()])


func _is_ready(state: Dictionary, crop_id: StringName) -> bool:
	return float(state.get(&"growth", 0.0)) >= float(GardenDb.growth_days(crop_id))


func _growth_fraction(state: Dictionary, crop_id: StringName) -> float:
	if crop_id == &"":
		return 0.0
	var days := maxf(float(GardenDb.growth_days(crop_id)), 1.0)
	return clampf(float(state.get(&"growth", 0.0)) / days, 0.0, 1.0)


func _build_bed() -> void:
	_soil_material = StandardMaterial3D.new()
	_soil_material.albedo_color = Color(0.19, 0.105, 0.052)
	_soil_material.roughness = 1.0
	_soil = _box(self, &"Soil", _soil_material,
		Vector3(BED_SIZE - FRAME_WIDTH * 2.0, 0.10, BED_SIZE - FRAME_WIDTH * 2.0),
		Vector3(0.0, 0.07, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(self, &"BedFrame", MAT_WOOD,
			Vector3(FRAME_WIDTH, 0.18, BED_SIZE),
			Vector3(side * (BED_SIZE - FRAME_WIDTH) * 0.5, 0.10, 0.0))
		_box(self, &"BedFrame", MAT_WOOD,
			Vector3(BED_SIZE - FRAME_WIDTH * 2.0, 0.18, FRAME_WIDTH),
			Vector3(0.0, 0.10, side * (BED_SIZE - FRAME_WIDTH) * 0.5))
	_crop_visuals = Node3D.new()
	_crop_visuals.name = &"CropVisuals"
	add_child(_crop_visuals)


func _rebuild_crop(state: Dictionary, crop_id: StringName) -> void:
	for child: Node in _crop_visuals.get_children():
		child.queue_free()
	if crop_id == &"":
		return
	if bool(state.get(&"watered", false)):
		var water_material := _material(Color(0.16, 0.42, 0.48), 0.24)
		for z: float in [-0.34, 0.0, 0.34]:
			_box(_crop_visuals, &"WaterSheen", water_material,
				Vector3(0.78, 0.012, 0.075), Vector3(0.0, 0.135, z))
	var fraction := _growth_fraction(state, crop_id)
	var ready := _is_ready(state, crop_id)
	var crop_tint := GardenDb.tint_of(crop_id)
	var foliage_tint := Color(0.24, 0.52, 0.20).lerp(crop_tint, 0.16)
	var leaf_material := _material(foliage_tint.darkened(0.12), 0.10)
	var stem_material := _material(foliage_tint.darkened(0.38), 0.0)
	var height := lerpf(0.12, 0.68, maxf(fraction, 0.08))
	var positions: Array[Vector3] = [
		Vector3(-0.32, 0.0, -0.28), Vector3(0.30, 0.0, -0.26),
		Vector3(-0.27, 0.0, 0.27), Vector3(0.29, 0.0, 0.29),
		Vector3(0.0, 0.0, 0.02),
	]
	for i: int in positions.size():
		var root := Node3D.new()
		root.name = StringName("Plant%d" % (i + 1))
		root.position = positions[i] + Vector3.UP * 0.12
		root.rotation.y = float(i) * 1.17
		_crop_visuals.add_child(root)
		_cylinder(root, &"Stem", stem_material, 0.025, height,
			Vector3(0.0, height * 0.5, 0.0), 6)
		if fraction >= 0.20:
			var leaf_scale := lerpf(0.10, 0.24, fraction)
			for side: float in [-1.0, 1.0]:
				var leaf := _sphere(root, &"Leaf", leaf_material, 0.5,
					Vector3(side * leaf_scale * 0.62, height * 0.68, 0.0), 7, 3)
				leaf.scale = Vector3(leaf_scale, leaf_scale * 0.42, leaf_scale * 0.70)
		if ready:
			var produce_id := GardenDb.produce_id(crop_id)
			var produce_material := _material(GardenDb.tint_of(produce_id), 0.42)
			var fruit := _sphere(root, &"RipeProduce", produce_material, 0.10,
				Vector3(0.0, height + 0.04, 0.0), 7, 4)
			fruit.scale.y = 0.82


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
	mesh.top_radius = radius * 0.82
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
