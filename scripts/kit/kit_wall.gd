@tool
class_name KitWall
extends StaticBody3D
## One run of dungeon wall, built as a backing slab plus a running-bond field of
## individually protruding blocks (see KitGeo.block_field).
##
## Local frame: the wall runs along local X, centred on the origin, rises from
## local y = 0, and its FINISHED FACE looks down local +Z. The slab lives behind it
## in negative Z. So to wall the north side of a room you place the segment at
## z = -half_depth with no rotation; the east side is rotated -90 degrees about Y.
##
## Collision is a single box covering slab + relief, not per-block. The hero should
## slide along a wall, not catch on every stone.

@export var length := 8.0:
	set(v):
		length = v
		_rebuild()
@export var height := K.CEIL_ROOM:
	set(v):
		height = v
		_rebuild()
@export var thickness := KitStyle.WALL_THICKNESS:
	set(v):
		thickness = v
		_rebuild()
@export var course_h := KitStyle.COURSE_H:
	set(v):
		course_h = v
		_rebuild()
@export var block_w := KitStyle.BLOCK_W:
	set(v):
		block_w = v
		_rebuild()
@export var joint := KitStyle.JOINT:
	set(v):
		joint = v
		_rebuild()
@export var relief := KitStyle.RELIEF:
	set(v):
		relief = v
		_rebuild()
## A wider, proud course along the bottom of the wall. Reads as a plinth and, more
## usefully, hides the seam where wall meets floor from a low third-person camera.
@export var plinth_h := 0.45:
	set(v):
		plinth_h = v
		_rebuild()
@export var plinth_relief := 0.26:
	set(v):
		plinth_relief = v
		_rebuild()
## Changing this reshuffles every block width and protrusion in this segment.
## Two walls sharing a seed are visibly identical; give neighbours different seeds.
@export var rng_seed := 1:
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
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = K.L_WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_ensure_children()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var hl := length * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Backing slab. Its visible +Z face is what shows through the joints as mortar.
	KitGeo.box(st, Vector3(-hl, 0.0, -thickness), Vector3(hl, height, 0.0), uv_scale)

	if plinth_h > 0.01:
		KitGeo.box(st,
			Vector3(-hl, 0.0, -0.08), Vector3(hl, plinth_h, plinth_relief),
			uv_scale, KitGeo.F_NO_BACK)

	KitGeo.block_field(st, -hl, hl, plinth_h, height,
		course_h, block_w, joint, relief, rng, uv_scale)

	st.generate_tangents()
	st.set_material(material)

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	_mi.mesh = mesh

	var depth: float = thickness + maxf(relief, plinth_relief)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, height, depth)
	_col.shape = shape
	_col.position = Vector3(0.0, height * 0.5, -thickness + depth * 0.5)


func _ensure_children() -> void:
	_mi = get_node_or_null(^"Mesh") as MeshInstance3D
	if _mi == null:
		_mi = MeshInstance3D.new()
		_mi.name = "Mesh"
		add_child(_mi)
	_col = get_node_or_null(^"Shape") as CollisionShape3D
	if _col == null:
		_col = CollisionShape3D.new()
		_col.name = "Shape"
		add_child(_col)
