class_name PatronEffigy
extends Node3D
## A replaceable visual shell for one member of the Votive Court. Prototype
## geometry is isolated below Model/Prototype so final art can replace it without
## changing the scene path or the shrine's answering API.

const ASH := Color(0.30, 0.31, 0.32)
const DARK_ASH := Color(0.22, 0.23, 0.24)
const PatronDbScript := preload("res://scripts/items/patron_db.gd")

@export var patron_id: StringName = PatronDbScript.LADY_LONG_WATER:
	set(value):
		patron_id = value
		if is_node_ready():
			_rebuild()

@export var broken: bool = false:
	set(value):
		broken = value
		if is_node_ready():
			_apply_answering_state()

@onready var _prototype: Node3D = $Model/Prototype
@onready var _answer_light: OmniLight3D = $AnswerLight

var _answering: bool = false
var _stone_material: StandardMaterial3D = null
var _dark_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group(&"patron_effigy")
	_rebuild()


func set_patron(id: StringName) -> void:
	patron_id = id


func set_answering(active: bool) -> void:
	_answering = active
	if is_node_ready():
		_apply_answering_state()


func _rebuild() -> void:
	for child in _prototype.get_children():
		_prototype.remove_child(child)
		child.queue_free()

	_stone_material = _make_material(ASH)
	_dark_material = _make_material(DARK_ASH)
	var kind: StringName = PatronDbScript.row(patron_id).get("kind", &"basin")
	match kind:
		&"basin":
			_build_lady()
		&"door":
			_build_guest()
		&"harrow":
			_build_harrow()
		&"mountain":
			_build_mountain()
		&"neighbor":
			_build_neighbor()
		&"walker":
			_build_walker()
		&"vallen":
			_build_vallen()
		_:
			_build_lady()
	_apply_answering_state()


func _make_material(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.96
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _apply_answering_state() -> void:
	var may_answer := _answering and not broken and patron_id != PatronDbScript.VALLEN
	var hue := PatronDbScript.color_of(patron_id)
	for material in [_stone_material, _dark_material]:
		if material == null:
			continue
		material.emission_enabled = may_answer
		material.emission = hue
		material.emission_energy_multiplier = 0.38 if may_answer else 0.0
	_answer_light.visible = may_answer
	_answer_light.light_color = hue
	_answer_light.light_energy = 0.75 if may_answer else 0.0


# --- Six presences and one broken maker --------------------------------------

func _build_lady() -> void:
	_cylinder(0.25, 0.34, 0.16, Vector3(0.0, 0.08, 0.0), _dark_material)
	_cylinder(0.37, 0.44, 0.22, Vector3(0.0, 0.27, 0.0), _stone_material)
	_cylinder(0.44, 0.44, 0.08, Vector3(0.0, 0.42, 0.0), _stone_material)
	_cylinder(0.30, 0.30, 0.025, Vector3(0.0, 0.468, 0.0), _dark_material)
	_cylinder(0.10, 0.14, 0.54, Vector3(0.0, 0.73, 0.16), _stone_material)
	_sphere(0.16, Vector3(0.0, 1.06, 0.16), _stone_material, 8, 4)


func _build_guest() -> void:
	_box(Vector3(0.58, 1.14, 0.16), Vector3(0.0, 0.66, 0.0), _dark_material)
	_box(Vector3(0.13, 1.38, 0.22), Vector3(-0.34, 0.69, 0.0), _stone_material)
	_box(Vector3(0.13, 1.38, 0.22), Vector3(0.34, 0.69, 0.0), _stone_material)
	_box(Vector3(0.82, 0.13, 0.22), Vector3(0.0, 1.38, 0.0), _stone_material)
	_sphere(0.055, Vector3(0.18, 0.70, -0.11), _stone_material, 6, 3)
	_cylinder(0.035, 0.05, 0.28, Vector3(-0.22, 0.26, -0.15), _stone_material)
	_sphere(0.09, Vector3(-0.22, 0.43, -0.15), _dark_material, 6, 3)


func _build_harrow() -> void:
	_cylinder(0.045, 0.055, 1.36, Vector3(-0.05, 0.78, 0.0), _stone_material,
		Vector3(0.0, 0.0, -0.13))
	_box(Vector3(0.50, 0.07, 0.08), Vector3(0.02, 1.10, 0.0), _stone_material,
		Vector3(0.0, 0.0, 0.08))
	_box(Vector3(0.25, 0.30, 0.10), Vector3(0.05, 0.17, 0.0), _dark_material,
		Vector3(0.0, 0.0, -0.10))
	_sphere(0.15, Vector3(-0.10, 1.40, 0.0), _stone_material, 7, 4)
	_cylinder(0.025, 0.04, 0.40, Vector3(0.22, 0.63, 0.02), _dark_material,
		Vector3(0.0, 0.0, 0.62))
	_sphere(0.07, Vector3(0.36, 0.77, 0.02), _dark_material, 6, 3)


func _build_mountain() -> void:
	_cylinder(0.36, 0.43, 0.38, Vector3(0.0, 0.19, 0.0), _stone_material)
	_cylinder(0.28, 0.34, 0.34, Vector3(-0.04, 0.54, 0.0), _dark_material,
		Vector3(0.0, 0.0, 0.07))
	_cylinder(0.19, 0.27, 0.31, Vector3(0.03, 0.87, 0.0), _stone_material,
		Vector3(0.0, 0.0, -0.08))
	_cylinder(0.10, 0.18, 0.27, Vector3(-0.02, 1.16, 0.0), _dark_material)
	_box(Vector3(0.05, 0.50, 0.05), Vector3(0.0, 0.46, -0.22), _stone_material,
		Vector3(0.0, 0.0, 0.10))


func _build_neighbor() -> void:
	_box(Vector3(0.54, 0.10, 0.48), Vector3(-0.08, 0.57, 0.0), _stone_material)
	_box(Vector3(0.54, 0.68, 0.10), Vector3(-0.08, 0.96, 0.18), _dark_material)
	for x in [-0.27, 0.11]:
		_box(Vector3(0.09, 0.55, 0.09), Vector3(x, 0.275, 0.14), _stone_material)
	_box(Vector3(0.22, 0.46, 0.25), Vector3(0.29, 0.23, 0.08), _dark_material)
	_box(Vector3(0.34, 0.08, 0.31), Vector3(0.29, 0.50, 0.08), _stone_material)


func _build_walker() -> void:
	_cylinder(0.31, 0.38, 0.29, Vector3(-0.10, 0.145, 0.0), _stone_material)
	_cylinder(0.22, 0.29, 0.27, Vector3(-0.13, 0.42, 0.0), _dark_material,
		Vector3(0.0, 0.0, 0.07))
	_cylinder(0.14, 0.21, 0.24, Vector3(-0.09, 0.67, 0.0), _stone_material)
	_cylinder(0.035, 0.045, 1.55, Vector3(0.30, 0.79, 0.0), _stone_material,
		Vector3(0.0, 0.0, -0.08))
	_sphere(0.075, Vector3(0.36, 1.57, 0.0), _dark_material, 6, 3)


func _build_vallen() -> void:
	# The maker and anvil are visibly interrupted: the upper body is offset and
	# the anvil's top is split into two mismatched stones.
	_box(Vector3(0.48, 0.20, 0.38), Vector3(0.12, 0.10, 0.0), _dark_material)
	_box(Vector3(0.20, 0.42, 0.23), Vector3(0.12, 0.35, 0.0), _stone_material)
	_box(Vector3(0.36, 0.13, 0.34), Vector3(-0.05, 0.60, 0.0), _stone_material,
		Vector3(0.0, 0.0, 0.14))
	_box(Vector3(0.25, 0.13, 0.34), Vector3(0.27, 0.57, 0.0), _dark_material,
		Vector3(0.0, 0.0, -0.18))
	_box(Vector3(0.38, 0.62, 0.24), Vector3(-0.13, 1.02, 0.08), _stone_material,
		Vector3(0.0, 0.0, 0.12))
	_sphere(0.18, Vector3(0.02, 1.42, 0.08), _dark_material, 7, 4)
	_box(Vector3(0.12, 0.55, 0.12), Vector3(0.25, 1.00, 0.06), _dark_material,
		Vector3(0.0, 0.0, -0.60))


# --- Primitive builders ------------------------------------------------------

func _box(size: Vector3, at: Vector3, material: StandardMaterial3D,
		rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation = rotation_value
	_prototype.add_child(instance)
	return instance


func _cylinder(top_radius: float, bottom_radius: float, height: float,
		at: Vector3, material: StandardMaterial3D,
		rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation = rotation_value
	_prototype.add_child(instance)
	return instance


func _sphere(radius: float, at: Vector3, material: StandardMaterial3D,
		radial_segments: int, rings: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	_prototype.add_child(instance)
	return instance
