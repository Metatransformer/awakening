class_name GlintFae
extends Node3D
## A rigid Glint cameo fitted from its imported meshes, with a small procedural
## hover idle. The outer node keeps this project's `-basis.z` facing contract;
## the imported model's +Z art-facing correction lives on a child pivot.

const MODEL_PATH := "res://assets/models/creatures/glint.glb"
const TARGET_HEIGHT := 1.24

var _idle: Node3D = null
var _hero: Node3D = null
var _age: float = 0.0
var _fallback: bool = false


func _ready() -> void:
	_idle = Node3D.new()
	_idle.name = "Idle"
	add_child(_idle)
	if not _build_imported():
		_build_mote()


func _process(delta: float) -> void:
	if _idle == null or not is_instance_valid(_idle):
		return
	_age += delta
	_idle.position.y = TARGET_HEIGHT * 0.10 * sin(_age * 1.9)
	_idle.rotation = Vector3(
		0.10 * sin(_age * 2.3),
		0.45 * sin(_age * 0.9),
		0.12 * sin(_age * 1.5))
	_idle.scale = Vector3.ONE * (1.0 + 0.06 * sin(_age * 2.6))
	_face_hero()


func body_height() -> float:
	return TARGET_HEIGHT


func using_fallback() -> bool:
	return _fallback


func _build_imported() -> bool:
	if not ResourceLoader.exists(MODEL_PATH, "PackedScene"):
		return false
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		return false

	var fit := Node3D.new()
	fit.name = "Fit"
	fit.add_child(model)
	var state: Array = [false, AABB()]
	_collect_bounds(model, Transform3D.IDENTITY, state)
	if not bool(state[0]):
		fit.free()
		return false
	var bounds: AABB = state[1]
	if bounds.size.y <= 0.001:
		fit.free()
		return false
	var scale_i := TARGET_HEIGHT / bounds.size.y
	var centre := bounds.position + bounds.size * 0.5
	fit.scale = Vector3.ONE * scale_i
	fit.position = Vector3(-centre.x * scale_i,
		-bounds.position.y * scale_i, -centre.z * scale_i)

	var art_space := Node3D.new()
	art_space.name = "ArtSpace"
	# Valenfeld's source faces +Z. Keep that correction inside the art while the
	# GlintFae node itself continues to face along Godot/project forward (-Z).
	art_space.rotation.y = PI
	art_space.add_child(fit)
	_idle.add_child(art_space)
	return true


func _build_mote() -> void:
	_fallback = true
	var mote := MeshInstance3D.new()
	mote.name = "WarmMoteFallback"
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	mote.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = Pal.GOLD
	material.emission = Pal.GOLD
	material.emission_energy_multiplier = 3.0
	mote.material_override = material
	mote.position.y = TARGET_HEIGHT * 0.30
	_idle.add_child(mote)


func _face_hero() -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"player") as Node3D
	if _hero == null:
		return
	var toward := _hero.global_position - global_position
	toward.y = 0.0
	if toward.length_squared() <= 0.0001:
		return
	# Heading is (sin yaw, 0, cos yaw), while a Node3D faces -basis.z.
	global_rotation.y = atan2(toward.x, toward.z) + PI


static func _collect_bounds(node: Node, parent_xform: Transform3D,
		state: Array) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var found := xform * mesh_instance.mesh.get_aabb()
		state[1] = (state[1] as AABB).merge(found) if bool(state[0]) else found
		state[0] = true
	for child in node.get_children():
		_collect_bounds(child, xform, state)
