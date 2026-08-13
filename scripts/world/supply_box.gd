class_name SupplyBox
extends Interactable
## The garrison's one deposit point for provisions carried home in the Run bag.
## Reserve state belongs to Game; this prop only presents it and asks Game for
## one atomic transfer when activated.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")

const WIDE := 1.8
const DEEP := 1.0
const BODY_H := 0.82

var _firewood_tokens: Array[Node3D] = []
var _food_tokens: Array[Node3D] = []
var attention_marker: WorldAttentionMarker


func _ready() -> void:
	prompt = "DEPOSIT SUPPLIES"
	radius = 2.0
	super()
	_build()
	attention_marker = WorldAttentionMarker.new()
	attention_marker.name = &"AttentionMarker"
	attention_marker.position.y = BODY_H + 0.72
	attention_marker.visible = false
	add_child(attention_marker)
	Game.garrison_changed.connect(_repaint)
	Game.quests_changed.connect(
		func(_quest_id: StringName) -> void: _refresh_attention_marker())
	_repaint()
	_refresh_attention_marker()


func activate(by: Node3D) -> void:
	activated.emit(by)
	var carried_supplies := _has_carried_supplies()
	var receipt: Dictionary = Game.deposit_supplies()
	var firewood_units := int(receipt.get(&"firewood_units", 0))
	var food_units := int(receipt.get(&"food_units", 0))
	if firewood_units > 0 and food_units > 0:
		Bus.request_message.emit("SUPPLIES STORED: %d FOOD, %d FIREWOOD."
			% [food_units, firewood_units])
	elif food_units > 0:
		Bus.request_message.emit("FOOD STORED: %d. RESERVE: %d / %d."
			% [food_units, Game.fish_stock, Game.FISH_CAP])
	elif firewood_units > 0:
		Bus.request_message.emit("FIREWOOD STORED: %d. RESERVE: %d / %d."
			% [firewood_units, Game.firewood_stock, Game.FIREWOOD_CAP])
	elif carried_supplies:
		Bus.request_message.emit("GARRISON STORES ARE FULL. SUPPLIES REMAIN IN YOUR BAG.")
	else:
		Bus.request_message.emit("NO SUPPLIES TO DEPOSIT.")


func _has_carried_supplies() -> bool:
	for id: StringName in SupplyCargoDb.SUPPLY_IDS:
		if int(Run.bag.get(id, 0)) > 0:
			return true
	return false


func _repaint() -> void:
	for i: int in _firewood_tokens.size():
		_firewood_tokens[i].visible = i < Game.firewood_stock
	for i: int in _food_tokens.size():
		_food_tokens[i].visible = i < Game.fish_stock


func _refresh_attention_marker() -> void:
	if attention_marker == null:
		return
	var symbol: String = QuestDb.marker_for_target(QuestDb.TARGET_SUPPLY_BOX)
	attention_marker.set_symbol(symbol)
	attention_marker.visible = not symbol.is_empty()


func _build() -> void:
	_build_collision()
	var crate := Node3D.new()
	crate.name = &"ProvisionCrate"
	add_child(crate)
	_box(crate, &"Floor", MAT_WOOD, Vector3(WIDE, 0.16, DEEP),
		Vector3(0.0, 0.18, 0.0))
	_box(crate, &"Back", MAT_WOOD, Vector3(WIDE, BODY_H, 0.14),
		Vector3(0.0, 0.18 + BODY_H * 0.5, -DEEP * 0.5 + 0.07))
	_box(crate, &"Front", MAT_WOOD, Vector3(WIDE, 0.34, 0.14),
		Vector3(0.0, 0.35, DEEP * 0.5 - 0.07))
	for sx: float in [-1.0, 1.0]:
		_box(crate, &"Side", MAT_WOOD, Vector3(0.14, BODY_H, DEEP),
			Vector3(sx * (WIDE * 0.5 - 0.07), 0.18 + BODY_H * 0.5, 0.0))
		_box(crate, &"IronCorner", MAT_IRON, Vector3(0.10, BODY_H + 0.08, 0.17),
			Vector3(sx * (WIDE * 0.5 + 0.012), 0.18 + BODY_H * 0.5,
				DEEP * 0.5 + 0.012))
	_box(crate, &"Divider", MAT_IRON, Vector3(0.08, BODY_H * 0.72, DEEP * 0.82),
		Vector3(0.0, 0.20 + BODY_H * 0.36, -0.03))

	# A low sign keeps the crate readable from the gate: crossed logs on the left,
	# fish and produce on the right. These are physical motifs, not floating UI.
	var sign := Node3D.new()
	sign.name = &"SupplyMarks"
	sign.position = Vector3(0.0, 0.66, DEEP * 0.5 + 0.02)
	crate.add_child(sign)
	for angle: float in [-0.82, 0.82]:
		var log_basis := Basis(Vector3.FORWARD, angle)
		_cylinder(sign, &"FirewoodMark", MAT_IRON, 0.055, 0.52,
			Transform3D(log_basis, Vector3(-0.46, 0.0, 0.04)), 8)
	_build_fish(sign, &"FishMark", Vector3(0.36, 0.05, 0.04), 0.62)
	_build_produce(sign, &"ProduceMark", Vector3(0.62, -0.04, 0.04), 0.68)

	var stock := Node3D.new()
	stock.name = &"VisibleStock"
	crate.add_child(stock)
	for i: int in Game.FIREWOOD_CAP:
		var bundle := Node3D.new()
		bundle.name = StringName("Firewood%d" % (i + 1))
		bundle.position = Vector3(-0.44, 0.76 + float(i) * 0.14,
			-0.20 + float(i % 2) * 0.25)
		stock.add_child(bundle)
		_firewood_tokens.append(bundle)
		for z: float in [-0.09, 0.09]:
			var basis := Basis(Vector3.FORWARD, PI * 0.5)
			_cylinder(bundle, &"Log", MAT_WOOD, 0.075, 0.62,
				Transform3D(basis, Vector3(0.0, 0.0, z)), 8)
		_box(bundle, &"Binding", MAT_IRON, Vector3(0.10, 0.17, 0.26),
			Vector3.ZERO)
	for i: int in Game.FISH_CAP:
		var provision := Node3D.new()
		provision.name = StringName("Food%d" % (i + 1))
		provision.position = Vector3(0.43, 0.77 + float(i) * 0.13,
			-0.20 + float(i % 2) * 0.24)
		provision.rotation.y = -0.20 + float(i) * 0.18
		stock.add_child(provision)
		_food_tokens.append(provision)
		if i % 2 == 0:
			_build_fish(provision, &"Fish", Vector3.ZERO, 0.88)
		else:
			_build_produce(provision, &"Produce", Vector3.ZERO, 1.0)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = &"CrateBody"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = &"Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDE, BODY_H + 0.18, DEEP)
	collision.shape = shape
	collision.position = Vector3(0.0, (BODY_H + 0.18) * 0.5, 0.0)
	body.add_child(collision)
	add_child(body)


func _build_fish(parent: Node3D, node_name: StringName, at: Vector3,
		scale_factor: float) -> Node3D:
	var fish := Node3D.new()
	fish.name = node_name
	fish.position = at
	fish.scale = Vector3.ONE * scale_factor
	parent.add_child(fish)
	var body := _sphere(fish, &"Body", MAT_IRON, 0.16,
		Transform3D(Basis.IDENTITY, Vector3(0.05, 0.0, 0.0)))
	body.scale = Vector3(1.55, 0.72, 0.34)
	var tail_basis := Basis(Vector3.FORWARD, PI * 0.5)
	var tail := _cone(fish, &"Tail", MAT_IRON, 0.13, 0.24,
		Transform3D(tail_basis, Vector3(-0.24, 0.0, 0.0)), 4)
	tail.scale.z = 0.42
	return fish


func _build_produce(parent: Node3D, node_name: StringName, at: Vector3,
		scale_factor: float) -> Node3D:
	var produce := Node3D.new()
	produce.name = node_name
	produce.position = at
	produce.scale = Vector3.ONE * scale_factor
	parent.add_child(produce)
	var bulb := _sphere(produce, &"Bulb", MAT_GRASS, 0.15,
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.025, 0.0)))
	bulb.scale = Vector3(0.92, 0.82, 0.62)
	for angle: float in [-0.55, 0.0, 0.55]:
		var leaf_basis := Basis(Vector3.FORWARD, angle)
		var leaf := _cone(produce, &"Leaf", MAT_GRASS, 0.075, 0.24,
			Transform3D(leaf_basis, Vector3(sin(angle) * 0.08, 0.16, 0.0)), 5)
		leaf.scale.z = 0.52
	return produce


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


func _sphere(parent: Node3D, node_name: StringName, material: Material,
		radius: float, local_transform: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = local_transform
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, local_transform: Transform3D,
		sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = local_transform
	parent.add_child(instance)
	return instance


func _cone(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, local_transform: Transform3D,
		sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = local_transform
	parent.add_child(instance)
	return instance
