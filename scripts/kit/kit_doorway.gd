@tool
class_name KitDoorway
extends StaticBody3D
## A wall run with a door opening punched through it, plus the proud stone surround
## that makes the opening read as a PORTAL rather than a hole.
##
## Same local frame as KitWall: runs along local X, finished face down local +Z,
## rises from local y = 0. The opening is centred on local X and is a genuine hole
## through the full thickness, so a corridor on the far side is visible through it.
##
## The surround (jambs + header + keystone) is the piece doing the OOT work. In
## refs/screens/dungeon_forest_entrance_hall_01.png the door is framed by stacked
## rectangular mouldings that step forward from the wall; that stepping is what
## catches torchlight and tells the player "this is the way out" from across a
## dark room.

@export var span := 6.0:
	set(v):
		span = v
		_rebuild()
@export var height := K.CEIL_ROOM:
	set(v):
		height = v
		_rebuild()
@export var thickness := KitStyle.WALL_THICKNESS:
	set(v):
		thickness = v
		_rebuild()
@export var opening_w := K.DOOR_W:
	set(v):
		opening_w = v
		_rebuild()
@export var opening_h := K.DOOR_H:
	set(v):
		opening_h = v
		_rebuild()
## Width of the stone moulding running up each side of the opening.
@export var frame_w := 0.55:
	set(v):
		frame_w = v
		_rebuild()
## How far the moulding steps forward off the wall face.
@export var frame_depth := 0.34:
	set(v):
		frame_depth = v
		_rebuild()
@export var plinth_h := 0.45:
	set(v):
		plinth_h = v
		_rebuild()
@export var rng_seed := 11:
	set(v):
		rng_seed = v
		_rebuild()
@export var material: Material:
	set(v):
		material = v
		_rebuild()
@export var uv_scale := KitStyle.UV_SCALE:
	set(v):
		uv_scale = v
		_rebuild()

var _mi: MeshInstance3D


func _ready() -> void:
	collision_layer = K.L_WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_shapes()
	_ensure_mesh()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var hs := span * 0.5
	var ho := opening_w * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- backing slab, in three pieces around the hole -----------------------
	KitGeo.box(st, Vector3(-hs, 0.0, -thickness), Vector3(-ho, height, 0.0), uv_scale)
	KitGeo.box(st, Vector3(ho, 0.0, -thickness), Vector3(hs, height, 0.0), uv_scale)
	KitGeo.box(st, Vector3(-ho, opening_h, -thickness), Vector3(ho, height, 0.0), uv_scale)

	# --- reveals: the inner faces of the passage itself ----------------------
	# Without these the wall is paper-thin at the opening and you see straight
	# through the slab's own back face.
	KitGeo.box(st, Vector3(-ho - 0.02, 0.0, -thickness), Vector3(-ho, opening_h, 0.0),
		uv_scale, KitGeo.F_PX)
	KitGeo.box(st, Vector3(ho, 0.0, -thickness), Vector3(ho + 0.02, opening_h, 0.0),
		uv_scale, KitGeo.F_NX)
	KitGeo.box(st, Vector3(-ho, opening_h, -thickness), Vector3(ho, opening_h + 0.02, 0.0),
		uv_scale, KitGeo.F_NY)

	# --- block field on the two flanks and over the lintel -------------------
	if plinth_h > 0.01:
		KitGeo.box(st, Vector3(-hs, 0.0, -0.08), Vector3(-ho, plinth_h, 0.26),
			uv_scale, KitGeo.F_NO_BACK)
		KitGeo.box(st, Vector3(ho, 0.0, -0.08), Vector3(hs, plinth_h, 0.26),
			uv_scale, KitGeo.F_NO_BACK)
	KitGeo.block_field(st, -hs, -ho - frame_w, plinth_h, height,
		KitStyle.COURSE_H, KitStyle.BLOCK_W, KitStyle.JOINT, KitStyle.RELIEF, rng, uv_scale)
	KitGeo.block_field(st, ho + frame_w, hs, plinth_h, height,
		KitStyle.COURSE_H, KitStyle.BLOCK_W, KitStyle.JOINT, KitStyle.RELIEF, rng, uv_scale)
	KitGeo.block_field(st, -hs, hs, opening_h + frame_w, height,
		KitStyle.COURSE_H, KitStyle.BLOCK_W, KitStyle.JOINT, KitStyle.RELIEF, rng, uv_scale)

	# --- the surround: two stepped mouldings, outer then inner ---------------
	var d1 := frame_depth
	var d0 := frame_depth * 0.55
	var w1 := frame_w
	var w0 := frame_w * 1.7
	_frame_ring(st, ho, opening_h, w0, d0, uv_scale)
	_frame_ring(st, ho, opening_h, w1, d1, uv_scale)

	# Keystone.
	KitGeo.box(st,
		Vector3(-0.42, opening_h + frame_w - 0.06, -0.08),
		Vector3(0.42, opening_h + frame_w + 0.5, frame_depth + 0.14),
		uv_scale, KitGeo.F_NO_BACK)

	st.generate_tangents()
	st.set_material(material)

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	_mi.mesh = mesh

	# --- collision: two jambs and a lintel -----------------------------------
	var depth := thickness + frame_depth
	var cz := -thickness + depth * 0.5
	var flank := (span - opening_w) * 0.5
	_add_shape(Vector3(flank, height, depth), Vector3(-(ho + flank * 0.5), height * 0.5, cz))
	_add_shape(Vector3(flank, height, depth), Vector3(ho + flank * 0.5, height * 0.5, cz))
	var lintel_h := height - opening_h
	if lintel_h > 0.01:
		_add_shape(Vector3(opening_w, lintel_h, depth),
			Vector3(0.0, opening_h + lintel_h * 0.5, cz))


## One rectangular moulding hugging the opening: left jamb, right jamb, header.
func _frame_ring(st: SurfaceTool, ho: float, oh: float, w: float, d: float, s: float) -> void:
	KitGeo.box(st, Vector3(-ho - w, 0.0, -0.08), Vector3(-ho, oh + w, d), s, KitGeo.F_NO_BACK)
	KitGeo.box(st, Vector3(ho, 0.0, -0.08), Vector3(ho + w, oh + w, d), s, KitGeo.F_NO_BACK)
	KitGeo.box(st, Vector3(-ho, oh, -0.08), Vector3(ho, oh + w, d), s, KitGeo.F_NO_BACK)


func _ensure_mesh() -> void:
	_mi = get_node_or_null(^"Mesh") as MeshInstance3D
	if _mi == null:
		_mi = MeshInstance3D.new()
		_mi.name = "Mesh"
		add_child(_mi)


func _clear_shapes() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			remove_child(c)
			c.queue_free()


func _add_shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)
