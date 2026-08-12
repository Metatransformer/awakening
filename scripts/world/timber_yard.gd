class_name TimberYard
extends Interactable
## Exterior hold-to-chop landmark. The campaign day and carried bundle live on
## `Game`; this node only presents and commits that authoritative state.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const MAT_STONE := preload("res://assets/materials/mat_wall_sunlit.tres")

var _axe_pivot: Node3D
var _fresh_stack: Node3D
var _depleted_stack: Node3D


func _ready() -> void:
	prompt = "CHOP FIREWOOD"
	hold_time = 1.2
	radius = 2.4
	super()
	_build()
	Game.garrison_changed.connect(_repaint)
	Clock.minute_changed.connect(_on_minute_changed)
	_repaint()


func activate(_by: Node3D) -> void:
	if not Game.flag(StoryDb.told_flag(&"elder", &"timber_duty")):
		Bus.request_message.emit("YOU NEED AN AXE. SPEAK TO ALDRIC.")
		return
	if not Game.has(ShopDb.WOODSMAN_AXE_ID):
		Bus.request_message.emit("BRANNOC HAS YOUR AXE ORDER.")
		return
	if Clock.garrison_phase() != WorldClock.GARRISON_DAYTIME:
		Bus.request_message.emit("CHOP FIREWOOD DURING DAYTIME.")
		return
	if Game.carrying_firewood:
		Bus.request_message.emit("YOU ARE ALREADY CARRYING FIREWOOD.")
		return
	if Game.firewood_stock >= Game.FIREWOOD_CAP:
		Bus.request_message.emit("THE GARRISON HEARTH IS FULL.")
		return
	if Game.timber_completed_day == Clock.day:
		Bus.request_message.emit("TODAY'S BUNDLE IS ALREADY CUT.")
		return
	if Game.chop_firewood(Clock.day, Clock.garrison_phase()):
		Bus.request_message.emit("FIREWOOD CUT. CARRY IT TO THE GARRISON HEARTH.")


func on_hold(t01: float) -> void:
	if _axe_pivot == null:
		return
	_axe_pivot.rotation.z = lerpf(-0.85, 0.75, smoothstep(0.0, 1.0, t01))


func _on_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	_repaint()


func _repaint() -> void:
	var depleted: bool = Game.timber_completed_day == Clock.day
	if _fresh_stack != null:
		_fresh_stack.visible = not depleted
	if _depleted_stack != null:
		_depleted_stack.visible = depleted
	if _axe_pivot != null:
		_axe_pivot.visible = Game.has(ShopDb.WOODSMAN_AXE_ID)
		_axe_pivot.rotation.z = -0.85


func _build() -> void:
	var block := StaticBody3D.new()
	block.name = &"ChoppingBlock"
	block.collision_layer = K.L_WORLD
	block.collision_mask = 0
	add_child(block)
	_cylinder(block, &"Block", MAT_WOOD, 0.62, 0.82,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.41, 0.0)), 12)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.62
	shape.height = 0.82
	collision.shape = shape
	collision.position.y = 0.41
	block.add_child(collision)

	var rack := Node3D.new()
	rack.name = &"LogRack"
	rack.position = Vector3(-1.35, 0.0, -0.15)
	add_child(rack)
	for x: float in [-0.72, 0.72]:
		_box(rack, &"RackPost", MAT_WOOD, Vector3(0.14, 1.35, 0.14),
			Transform3D(Basis.IDENTITY, Vector3(x, 0.675, 0.0)))
	_box(rack, &"RackRail", MAT_IRON, Vector3(1.7, 0.12, 0.12),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.42, 0.0)))

	_fresh_stack = Node3D.new()
	_fresh_stack.name = &"FreshRounds"
	rack.add_child(_fresh_stack)
	for i: int in 6:
		var row: int = floori(float(i) / 3.0)
		var column: int = i % 3
		var basis := Basis(Vector3.FORWARD, PI * 0.5)
		_cylinder(_fresh_stack, &"Round", MAT_WOOD, 0.23, 0.9,
			Transform3D(basis, Vector3(-0.48 + float(column) * 0.48,
				0.25 + float(row) * 0.42, 0.0)), 10)

	_depleted_stack = Node3D.new()
	_depleted_stack.name = &"SplitEnds"
	rack.add_child(_depleted_stack)
	for x: float in [-0.38, 0.18]:
		_box(_depleted_stack, &"SplitWood", MAT_WOOD, Vector3(0.42, 0.13, 0.18),
			Transform3D(Basis(Vector3.UP, x), Vector3(x, 0.12, 0.0)))

	var stone_pad := MeshInstance3D.new()
	stone_pad.name = &"StonePad"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.0
	pad_mesh.bottom_radius = 1.08
	pad_mesh.height = 0.08
	pad_mesh.radial_segments = 12
	stone_pad.mesh = pad_mesh
	stone_pad.material_override = MAT_STONE
	stone_pad.position = Vector3(0.0, 0.04, 0.0)
	add_child(stone_pad)

	_axe_pivot = Node3D.new()
	_axe_pivot.name = &"AxeProp"
	_axe_pivot.position = Vector3(0.25, 0.95, 0.0)
	add_child(_axe_pivot)
	_box(_axe_pivot, &"Handle", MAT_WOOD, Vector3(0.09, 1.05, 0.09),
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.48, 0.0)))
	_box(_axe_pivot, &"Head", MAT_IRON, Vector3(0.52, 0.22, 0.12),
		Transform3D(Basis.IDENTITY, Vector3(0.13, 0.0, 0.0)))


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, local_transform: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
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
