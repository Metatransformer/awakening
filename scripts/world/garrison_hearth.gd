class_name GarrisonHearth
extends Interactable
## Central deposit point and presentation of the already-resolved bonfire state.

const MAT_STONE := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_EMBER := preload("res://assets/materials/mat_ember.tres")
const MAT_FLAME := preload("res://assets/materials/mat_flame.tres")

var _stock_bundles: Array[Node3D] = []
var _embers: Node3D
var _flames: Node3D
var _fire_light: OmniLight3D


func _ready() -> void:
	prompt = "STACK FIREWOOD"
	radius = 2.3
	super()
	_build()
	Game.garrison_changed.connect(_repaint)
	Clock.garrison_phase_changed.connect(_on_phase_changed)
	Clock.minute_changed.connect(_on_minute_changed)
	_repaint()


func activate(_by: Node3D) -> void:
	if not Game.carrying_firewood:
		Bus.request_message.emit("YOU ARE NOT CARRYING FIREWOOD.")
		return
	if Game.firewood_stock >= Game.FIREWOOD_CAP:
		Bus.request_message.emit("THE GARRISON HEARTH IS FULL.")
		return
	if Game.deposit_firewood():
		Bus.request_message.emit("FIREWOOD STACKED. HEARTH STOCK: %d / %d."
			% [Game.firewood_stock, Game.FIREWOOD_CAP])


func _on_phase_changed(_phase: StringName) -> void:
	_repaint()


func _on_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	_repaint()


func _repaint() -> void:
	for i: int in _stock_bundles.size():
		_stock_bundles[i].visible = i < Game.firewood_stock
	var fueled: bool = Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE \
		and Game.last_bonfire_day == Clock.day and Game.warmth_active
	if _flames != null:
		_flames.visible = fueled
	if _embers != null:
		_embers.visible = Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE \
			and not fueled
	if _fire_light != null:
		_fire_light.visible = fueled


func _build() -> void:
	var ring := Node3D.new()
	ring.name = &"StoneFireRing"
	add_child(ring)
	for i: int in 12:
		var angle: float = float(i) * TAU / 12.0
		var at := Vector3(cos(angle) * 0.82, 0.18, sin(angle) * 0.82)
		_box(ring, &"RingStone", MAT_STONE, Vector3(0.48, 0.32, 0.34),
			Transform3D(Basis(Vector3.UP, -angle), at))

	_embers = Node3D.new()
	_embers.name = &"ColdEmbers"
	add_child(_embers)
	for at: Vector3 in [Vector3(-0.28, 0.13, -0.12), Vector3(0.18, 0.12, 0.16),
			Vector3(0.02, 0.14, -0.30)]:
		_sphere(_embers, &"Ember", MAT_EMBER, 0.16,
			Transform3D(Basis.IDENTITY, at))

	_flames = Node3D.new()
	_flames.name = &"BonfireFlames"
	add_child(_flames)
	for row: Vector4 in [Vector4(-0.24, 0.46, 0.0, 0.28),
			Vector4(0.22, 0.55, 0.06, 0.34), Vector4(0.0, 0.72, -0.16, 0.40)]:
		_sphere(_flames, &"Flame", MAT_FLAME, row.w,
			Transform3D(Basis.IDENTITY, Vector3(row.x, row.y, row.z)))

	_fire_light = OmniLight3D.new()
	_fire_light.name = &"BonfireLight"
	_fire_light.light_color = Color(1.0, 0.46, 0.16)
	_fire_light.light_energy = 5.2
	_fire_light.omni_range = 8.0
	_fire_light.omni_attenuation = 1.35
	_fire_light.shadow_enabled = false
	_fire_light.position = Vector3(0.0, 0.65, 0.0)
	add_child(_fire_light)

	var stock := Node3D.new()
	stock.name = &"FirewoodStock"
	stock.position = Vector3(1.35, 0.0, 0.0)
	add_child(stock)
	for i: int in Game.FIREWOOD_CAP:
		var bundle := Node3D.new()
		bundle.name = StringName("Bundle%d" % (i + 1))
		bundle.position = Vector3(0.0, 0.17 + float(i) * 0.28, 0.0)
		stock.add_child(bundle)
		_stock_bundles.append(bundle)
		for z: float in [-0.18, 0.18]:
			var basis := Basis(Vector3.FORWARD, PI * 0.5)
			_cylinder(bundle, &"Log", MAT_WOOD, 0.13, 0.95,
				Transform3D(basis, Vector3(0.0, 0.0, z)), 8)


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


func _sphere(parent: Node3D, node_name: StringName, material: Material,
		radius: float, local_transform: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.1
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
