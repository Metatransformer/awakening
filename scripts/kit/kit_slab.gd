@tool
class_name KitSlab
extends StaticBody3D
## A rectangular stone slab. Floors, ceilings, raised ledges and step platforms are
## all the same primitive at different thicknesses — a ledge is just a floor whose
## sides you can see.
##
## The slab's TOP face sits at local y = 0 and it extends downward by `thickness`,
## so placing a floor is `position.y = 0`, a ledge is `position.y = 1.2`, and a
## ceiling is `position.y = K.CEIL_ROOM` with `ceiling = true`.
##
## Two material slots, and the split matters: `face_material` goes on the up/down
## faces and `edge_material` on the four sides. The stone shaders derive their
## pattern from world position, so a floor shader (XZ projection) is wrong on a
## vertical face and a wall shader (horizontal coursing) is wrong on a floor. One
## mesh, two surfaces, no compromise.

@export var size := Vector2(20.0, 20.0):
	set(v):
		size = v
		_rebuild()
@export var thickness := KitStyle.FLOOR_THICKNESS:
	set(v):
		thickness = v
		_rebuild()
## Ceilings only need their underside; skipping the top face halves the triangles
## and stops the ceiling slab from shadow-casting a lid over the room above.
@export var ceiling := false:
	set(v):
		ceiling = v
		_rebuild()
@export var face_material: Material:
	set(v):
		face_material = v
		_rebuild()
@export var edge_material: Material:
	set(v):
		edge_material = v
		_rebuild()
@export var uv_scale := KitStyle.UV_SCALE:
	set(v):
		uv_scale = v
		_rebuild()
## Off for decorative slabs that sit inside other collision (e.g. a ceiling the
## player can never reach) — one less shape in the broad phase.
@export var solid := true:
	set(v):
		solid = v
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

	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var lo := Vector3(-hx, -thickness, -hz)
	var hi := Vector3(hx, 0.0, hz)

	var mesh := ArrayMesh.new()

	var faces := SurfaceTool.new()
	faces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_mask := KitGeo.F_NY if ceiling else (KitGeo.F_PY | KitGeo.F_NY)
	KitGeo.box(faces, lo, hi, uv_scale, face_mask)
	faces.generate_tangents()
	faces.set_material(face_material)
	faces.commit(mesh)

	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	KitGeo.box(edges, lo, hi, uv_scale, KitGeo.F_PX | KitGeo.F_NX | KitGeo.F_PZ | KitGeo.F_NZ)
	edges.generate_tangents()
	edges.set_material(edge_material)
	edges.commit(mesh)

	_mi.mesh = mesh

	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, thickness, size.y)
	_col.shape = shape
	_col.position = Vector3(0.0, -thickness * 0.5, 0.0)
	_col.disabled = not solid


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
