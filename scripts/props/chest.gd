class_name Chest
extends StaticBody3D
## A dungeon chest. Walk up, press `interact`, get ingredients.
##
## Contents are rolled from the depth BAND, not from the room, so a chest found
## deep is worth the walk back (docs/METAGAME.md §5). Band-2+ chests are the
## only reliable Grave Ember source, which is what pays for pushing past the
## point where the extraction fee starts to hurt.
##
## Dimensions are docs/CONTRACT.md §1: 1.1 wide x 0.8 deep x 0.8 tall.

signal opened(contents: Array)

const W := 1.1
const D := 0.8
const H := 0.8

@export var band: int = 1
@export var chest_seed: int = 0
## Set false for the town chest / tutorial chest that should always give the
## same thing. Unused at MVP but the hook costs nothing.
@export var randomize_contents: bool = true

var is_open: bool = false

var _lid: Node3D
var _prompt: Area3D
var _rng := RandomNumberGenerator.new()
var _player_near: bool = false


static func spawn(parent: Node3D, at: Vector3, p_band: int, seed_val: int) -> Chest:
	var c := Chest.new()
	c.band = p_band
	c.chest_seed = seed_val
	parent.add_child(c)
	c.global_position = at
	return c


func _ready() -> void:
	add_to_group(&"chest")
	add_to_group(&"interactable")
	collision_layer = K.L_WORLD
	_rng.seed = chest_seed if chest_seed != 0 else randi()

	_build_geometry()
	_build_prompt()


func _build_geometry() -> void:
	var wood := load("res://assets/materials/mat_wood.tres") as Material
	var iron := load("res://assets/materials/mat_iron.tres") as Material

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W, H * 0.62, D)
	body.mesh = box
	body.material_override = wood
	body.position = Vector3(0, H * 0.31, 0)
	add_child(body)

	# Iron banding, so the chest reads as a chest at the distance the camera
	# actually sits (2.5-4 m) rather than as a brown box.
	for x in [-W * 0.3, W * 0.3]:
		var band_mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.08, H * 0.66, D + 0.03)
		band_mesh.mesh = b
		band_mesh.material_override = iron
		band_mesh.position = Vector3(x, H * 0.31, 0)
		add_child(band_mesh)

	_lid = Node3D.new()
	_lid.name = "Lid"
	# Hinge at the BACK edge, so rotating the pivot swings the lid up and back
	# the way a real chest opens. Rotating the mesh itself would spin it in place.
	_lid.position = Vector3(0, H * 0.62, -D * 0.5)
	add_child(_lid)

	var lid_mesh := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(W, H * 0.30, D)
	lid_mesh.mesh = lb
	lid_mesh.material_override = wood
	lid_mesh.position = Vector3(0, H * 0.15, D * 0.5)
	_lid.add_child(lid_mesh)

	var latch := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.18, 0.16, 0.06)
	latch.mesh = lm
	latch.material_override = iron
	latch.position = Vector3(0, 0.02, D + 0.01)
	_lid.add_child(latch)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, D)
	col.shape = shape
	col.position = Vector3(0, H * 0.5, 0)
	add_child(col)


func _build_prompt() -> void:
	_prompt = Area3D.new()
	_prompt.name = "Reach"
	_prompt.collision_layer = K.L_INTERACT
	_prompt.collision_mask = K.L_PLAYER
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.9
	col.shape = sphere
	col.position = Vector3(0, 0.6, 0)
	_prompt.add_child(col)
	add_child(_prompt)
	_prompt.body_entered.connect(_on_near)
	_prompt.body_exited.connect(_on_far)


func _on_near(body: Node3D) -> void:
	if is_open or not body.is_in_group(&"player"):
		return
	_player_near = true
	Bus.request_message.emit("Open  [E]")


func _on_far(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_player_near = false
		Bus.request_message.emit("")


func _unhandled_input(event: InputEvent) -> void:
	if is_open or not _player_near:
		return
	if event.is_action_pressed(&"interact"):
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	_player_near = false
	Bus.request_message.emit("")

	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_lid, ^"rotation:x", deg_to_rad(-105.0), 0.45)

	var contents := LootDB.roll_chest(band, _rng) if randomize_contents else []
	# Spawn slightly above the chest mouth so pickups arc out where the player
	# can see them, rather than inside the geometry.
	var mouth := global_position + Vector3.UP * (H + 0.25)
	for c in contents:
		LootPickup.spawn(get_parent() as Node3D, c[0], c[1], mouth, _rng)

	Bus.chest_opened.emit(StringName("chest_%d" % get_instance_id()), &"ingredients")
	Bus.request_sfx.emit(&"chest_open", global_position)
	opened.emit(contents)
