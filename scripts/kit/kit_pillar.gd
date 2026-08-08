@tool
class_name KitPillar
extends StaticBody3D
## A square dungeon pillar: flared base, banded shaft, flared capital.
##
## Square, not round. OOT's interior columns are chunky rectangular prisms whose
## corners catch a hard highlight from a nearby torch — a cylinder would smooth
## that highlight into a gradient and lose the N64 read. The base and capital
## flares also give the camera package something with a real silhouette to occlude
## against when it swings around the room.
##
## Rises from local y = 0. Collision is one box at shaft width; the base flare is
## small enough to walk over and catching on it would feel bad.

@export var height := K.CEIL_ROOM:
	set(v):
		height = v
		_rebuild()
@export var width := 1.1:
	set(v):
		width = v
		_rebuild()
@export var base_h := 0.55:
	set(v):
		base_h = v
		_rebuild()
@export var base_flare := 0.3:
	set(v):
		base_flare = v
		_rebuild()
@export var cap_h := 0.5:
	set(v):
		cap_h = v
		_rebuild()
@export var cap_flare := 0.34:
	set(v):
		cap_flare = v
		_rebuild()
## Proud bands girdling the shaft. Reads as stacked drums of stone.
@export var bands := 2:
	set(v):
		bands = v
		_rebuild()
@export var band_h := 0.22:
	set(v):
		band_h = v
		_rebuild()
@export var band_flare := 0.11:
	set(v):
		band_flare = v
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

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw := width * 0.5
	# Base: two stepped plinths, wider at the ground.
	_slab(st, hw + base_flare, 0.0, base_h * 0.55)
	_slab(st, hw + base_flare * 0.55, base_h * 0.55, base_h)
	# Shaft.
	_slab(st, hw, base_h, height - cap_h)
	# Capital, mirrored.
	_slab(st, hw + cap_flare * 0.55, height - cap_h, height - cap_h * 0.45)
	_slab(st, hw + cap_flare, height - cap_h * 0.45, height)

	var span := (height - cap_h) - base_h
	for i in bands:
		var t := float(i + 1) / float(bands + 1)
		var y := base_h + span * t
		_slab(st, hw + band_flare, y - band_h * 0.5, y + band_h * 0.5)

	st.generate_tangents()
	st.set_material(material)

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	_mi.mesh = mesh

	var shape := BoxShape3D.new()
	shape.size = Vector3(width + band_flare, height, width + band_flare)
	_col.shape = shape
	_col.position = Vector3(0.0, height * 0.5, 0.0)


func _slab(st: SurfaceTool, half: float, y0: float, y1: float) -> void:
	KitGeo.box(st, Vector3(-half, y0, -half), Vector3(half, y1, half), uv_scale)


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
