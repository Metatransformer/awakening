class_name FieldNotesBook
extends Interactable
## The Society ledger kept beside the player's bunk. Completion lives in
## `Game`; this prop presents the book and reacts to its typed state changes.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

const TOP_Y: float = 0.76
const COVER_SIZE := Vector3(0.42, 0.035, 0.54)
const COVER_OPEN: float = -0.34
const COVER_CLOSED: float = 0.0

var attention_marker: WorldAttentionMarker

var _cover: Node3D
var _screen: FieldNotesBookScreen = null
var _focus_rim: MeshInstance3D


func _ready() -> void:
	prompt = "READ"
	radius = 0.8
	_build_interaction_shape()
	super()
	_build_dresser()
	_build_ledger()
	attention_marker = WorldAttentionMarker.new()
	attention_marker.name = "AttentionMarker"
	attention_marker.position = Vector3(0.0, 1.44, 0.0)
	add_child(attention_marker)
	Bus.field_observations_completed.connect(
		func(_ids: Array[StringName]) -> void: refresh_attention_marker())
	Bus.field_notes_awarded.connect(
		func(_ids: Array[StringName], _balance: int) -> void: refresh_attention_marker())
	Saves.loaded.connect(func(_slot: int) -> void: refresh_attention_marker())
	refresh_attention_marker()


func activate(by: Node3D) -> void:
	if is_instance_valid(_screen):
		return
	activated.emit(by)
	_screen = FieldNotesBookScreen.open(self)
	_screen.tree_exited.connect(_on_screen_closed)
	_swing_cover(COVER_OPEN)


func on_focus(on: bool) -> void:
	if _focus_rim != null:
		_focus_rim.visible = on


func refresh_attention_marker() -> void:
	if attention_marker != null:
		attention_marker.visible = not Game.ready_field_observations().is_empty()


func _on_screen_closed() -> void:
	_screen = null
	if is_inside_tree():
		_swing_cover(COVER_CLOSED)


func _swing_cover(to: float) -> void:
	if _cover == null:
		return
	var tween := create_tween()
	tween.tween_property(_cover, "rotation:x", to, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The trigger sits on the aisle side of the dresser. The visible ledger remains
## bedside, while its volume stays clear of the bed's broad sleep sphere and the
## footlocker's opening sphere at the bunk's head.
func _build_interaction_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "ReadVolume"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 1.15, 0.72)
	collision.shape = shape
	# Local +Z faces out through the barracks' open front once the book is placed
	# by BunkBed. The player reads from the aisle, not from inside the berth.
	collision.position = Vector3(0.0, 0.58, 0.96)
	add_child(collision)


func _build_dresser() -> void:
	var dresser := Node3D.new()
	dresser.name = "Dresser"
	add_child(dresser)

	# Four legs and a shallow carcass keep the silhouette open underneath. It is
	# a bedside table, not another chest competing with the footlocker.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(dresser, "Leg", Vector3(0.10, 0.62, 0.10),
				Vector3(sx * 0.27, 0.31, sz * 0.20), MAT_WOOD)
	_box(dresser, "Carcass", Vector3(0.64, 0.30, 0.50),
		Vector3(0.0, 0.50, 0.0), MAT_WOOD)
	_box(dresser, "Top", Vector3(0.78, 0.08, 0.64),
		Vector3(0.0, TOP_Y - 0.04, 0.0), MAT_WOOD)
	_box(dresser, "DrawerPull", Vector3(0.18, 0.06, 0.04),
		Vector3(0.0, 0.54, 0.27), MAT_IRON)

	# One forgiving collision block, inset from the legs, slides the hero around
	# the table instead of catching the controller on four tiny solids.
	var body := StaticBody3D.new()
	body.name = "DresserCollision"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	dresser.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.62, 0.66, 0.48)
	collision.shape = shape
	collision.position.y = 0.33
	body.add_child(collision)


func _build_ledger() -> void:
	var ledger := Node3D.new()
	ledger.name = "SocietyLedger"
	ledger.position = Vector3(0.0, TOP_Y, 0.0)
	ledger.rotation.y = -0.12
	add_child(ledger)

	var page_mat := _material(Color(0.78, 0.72, 0.58), 0.98)
	var cover_mat := _material(Color(0.22, 0.10, 0.055), 0.90)
	var gold_mat := _material(Pal.GOLD, 0.76)
	_box(ledger, "Pages", Vector3(0.38, 0.075, 0.49),
		Vector3(0.0, 0.07, 0.0), page_mat)
	_box(ledger, "LowerCover", COVER_SIZE,
		Vector3(0.0, 0.018, 0.0), cover_mat)
	_box(ledger, "Spine", Vector3(0.055, 0.11, 0.54),
		Vector3(-0.21, 0.065, 0.0), cover_mat)

	_cover = Node3D.new()
	_cover.name = "UpperCoverHinge"
	_cover.position = Vector3(-COVER_SIZE.x * 0.5, 0.115, 0.0)
	ledger.add_child(_cover)
	_box(_cover, "UpperCover", COVER_SIZE,
		Vector3(COVER_SIZE.x * 0.5, 0.0, 0.0), cover_mat)
	# A simple gold Society ledger device survives at gameplay distance while a
	# line of physical cover text would only become buffer-soft noise.
	_box(_cover, "SocietyDevice", Vector3(0.15, 0.012, 0.20),
		Vector3(COVER_SIZE.x * 0.5, 0.024, 0.0), gold_mat)

	_focus_rim = _box(ledger, "FocusRim", Vector3(0.50, 0.14, 0.62),
		Vector3(0.0, 0.07, 0.0), _rim_material())
	_focus_rim.visible = false


func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _rim_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(Pal.GOLD, 0.14)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	return material
