class_name BunkBed
extends Node3D
## A two-level timber billet. Decorative bunks share the same occupied-ready
## silhouette; the player's unit alone owns the real sleep and stash props.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

const WIDTH := 1.28
const LENGTH := 2.34
const POST_HEIGHT := 2.25
const POST := 0.14
const LOWER_DECK_Y := 0.34
const UPPER_DECK_Y := 1.42
const DECK_HEIGHT := 0.14
# The locker sits at the bunk's head, opposite the customer-side approach to
# the lower mattress. Keeping the two interaction radii apart prevents OPEN
# from stealing the SLEEP hold when the player stands beside their bed.
const LOCKER_Z := -1.72

@export var player_bunk: bool = false

var bed: Bed
var locker: Footlocker
var field_notes_book: FieldNotesBook
## Compatibility/readability footprint for directors that frame the former
## lean-to as a room. The bunk bay is open-front, not a separate scene.
var room := Vector2(4.2, LENGTH + 1.4)

var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	_build_frame()
	_build_collision()
	_build_bedding()
	if player_bunk:
		add_to_group(&"player_bunk")
		_build_player_props()


func _build_frame() -> void:
	var posts := Node3D.new()
	posts.name = "Posts"
	add_child(posts)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_visual_box(
				posts,
				"Post",
				Vector3(POST, POST_HEIGHT, POST),
				Vector3(sx * (WIDTH - POST) * 0.5, POST_HEIGHT * 0.5,
					sz * (LENGTH - POST) * 0.5),
				MAT_WOOD
			)

	var decks := Node3D.new()
	decks.name = "Decks"
	add_child(decks)
	for deck_y: float in [LOWER_DECK_Y, UPPER_DECK_Y]:
		_visual_box(
			decks,
			"TimberDeck",
			Vector3(WIDTH, DECK_HEIGHT, LENGTH),
			Vector3(0.0, deck_y, 0.0),
			MAT_WOOD
		)

	# The upper side rails and ladder are the medium-scale marks that keep this
	# from reading as two ordinary cots stacked by accident.
	for sx: float in [-1.0, 1.0]:
		_visual_box(
			decks,
			"UpperRail",
			Vector3(POST, 0.18, LENGTH - 0.30),
			Vector3(sx * WIDTH * 0.5, UPPER_DECK_Y + 0.34, 0.0),
			MAT_WOOD
		)

	var ladder := Node3D.new()
	ladder.name = "Ladder"
	add_child(ladder)
	var ladder_x := WIDTH * 0.5 + 0.06
	for z: float in [0.24, 0.92]:
		_visual_box(
			ladder,
			"Stile",
			Vector3(0.10, 1.48, 0.10),
			Vector3(ladder_x, 0.79, z),
			MAT_WOOD
		)
	for rung_y: float in [0.38, 0.70, 1.02, 1.34]:
		_visual_box(
			ladder,
			"Rung",
			Vector3(0.12, 0.09, 0.78),
			Vector3(ladder_x + 0.01, rung_y, 0.58),
			MAT_IRON
		)


func _build_collision() -> void:
	# One forgiving envelope makes the controller slide past the bunk instead of
	# catching separately on eight rails and posts.
	var body := StaticBody3D.new()
	body.name = "FrameCollision"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)
	_add_box_shape(
		body,
		Vector3(WIDTH + 0.20, UPPER_DECK_Y + 0.42, LENGTH),
		Vector3(0.0, (UPPER_DECK_Y + 0.42) * 0.5, 0.0)
	)
	if player_bunk:
		_add_box_shape(
			body,
			Vector3(Footlocker.WIDE, Footlocker.BODY_H + Footlocker.LID_H,
				Footlocker.DEEP),
			Vector3(0.0, (Footlocker.BODY_H + Footlocker.LID_H) * 0.5, LOCKER_Z)
		)


func _build_bedding() -> void:
	var bedding := Node3D.new()
	bedding.name = "Bedding"
	add_child(bedding)
	# Bed builds the lower mattress for the interactive unit. Every other bunk
	# receives both made-up berths and is visibly ready for an off-duty soldier.
	if not player_bunk:
		_decorative_berth(bedding, LOWER_DECK_Y)
	_decorative_berth(bedding, UPPER_DECK_Y)


func _decorative_berth(parent: Node3D, deck_y: float) -> void:
	var cloth := _cloth(Color(0.43, 0.36, 0.30))
	_visual_box(
		parent,
		"Mattress",
		Vector3(WIDTH - 0.16, 0.16, LENGTH - 0.18),
		Vector3(0.0, deck_y + 0.14, 0.0),
		cloth
	)
	_visual_box(
		parent,
		"Blanket",
		Vector3(WIDTH - 0.10, 0.09, LENGTH * 0.54),
		Vector3(0.0, deck_y + 0.25, LENGTH * 0.18),
		_cloth(Color(0.45, 0.19, 0.11))
	)
	_visual_box(
		parent,
		"Pillow",
		Vector3(WIDTH - 0.34, 0.13, 0.38),
		Vector3(0.0, deck_y + 0.25, -LENGTH * 0.35),
		_cloth(Color(0.74, 0.68, 0.56))
	)


func _build_player_props() -> void:
	bed = Bed.new()
	bed.name = "Bed"
	bed.position.y = 0.02
	# The frame keeps the controller almost two metres from its centre. Extend
	# only this lower berth's reach so it remains usable from the barracks aisle.
	bed.interaction_radius = 2.4
	add_child(bed)

	locker = Footlocker.new()
	locker.name = "Footlocker"
	locker.position = Vector3(0.0, 0.0, LOCKER_Z)
	locker.rotation.y = PI
	add_child(locker)

	field_notes_book = FieldNotesBook.new()
	field_notes_book.name = "FieldNotesBook"
	# Beside the lower berth, while the read volume itself reaches outward into
	# the aisle (see FieldNotesBook._build_interaction_shape).
	field_notes_book.position = Vector3(-1.18, 0.0, 0.42)
	field_notes_book.rotation.y = -0.10
	add_child(field_notes_book)


func _add_box_shape(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	body.add_child(collision)


func _visual_box(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		at: Vector3,
		material: Material
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


func _cloth(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	return material
