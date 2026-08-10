@tool
class_name Fence
extends StaticBody3D
## A run of wooden fence, for the edge of garrison.
##
## Local frame matches `KitWall`'s deliberately: the run goes along local X,
## centred on the origin, rising from local y = 0, with its face looking down
## local +Z. So the four sides of a yard are placed exactly the way the four
## walls of a room are, and nobody has to learn a second convention.
##
## **Why a fence and not the masonry wall.** The garrison used to be a walled
## stone courtyard at night, which read as one more interior — the same kit, the
## same dark, the same stone as the dungeon. Valenfeld is a frontier town above
## the shaft, and the only contrast the game gets for free is that the surface
## is *outside* and the Lower Worlds are not. A fence you can see the sky over
## is most of that contrast, and it costs one prop.
##
## Placeholder, on purpose (`docs/SCOPE.md` §3 — the gate is a played hour, not
## a look). The model is the village kit's single fence panel, repeated. When
## the garrison gets art, this file is what gets replaced, and nothing else has
## to.

const MODEL := "res://assets/props/fence/Prop_WoodenFence_Single.gltf"

## Metres of fence. Panels are repeated to cover it and the last one is clipped
## by the collision box rather than by scaling, because a stretched panel reads
## as a different fence and the seam is what says "this is a repeat".
@export var length := 10.0:
	set(v):
		length = v
		_rebuild()
## Collider height, in metres. **0 means "measure the panel"**, which is what you
## want -- the village kit's panel is 0.84 m and a 1.6 m collider would have put an
## invisible wall a metre above a fence you can see over. Only override it if a run
## needs to block something the art does not.
@export var height := 0.0:
	set(v):
		height = v
		_rebuild()
## Panels are jittered off true by this many degrees, alternating, so a long run
## does not read as one extruded ribbon. Small: this is a fence somebody built,
## not a fence somebody abandoned.
@export var lean_deg := 1.6:
	set(v):
		lean_deg = v
		_rebuild()
@export var rng_seed := 1:
	set(v):
		rng_seed = v
		_rebuild()

var _built := false


func _ready() -> void:
	collision_layer = K.L_WORLD
	collision_mask = 0
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for c in get_children():
		c.queue_free()

	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_warning("Fence: %s did not load; the yard will have no edge." % MODEL)
		return

	# Measure the panel rather than hardcoding its width. The kit models come from
	# assorted sources at assorted native sizes, and a hardcoded pitch is a gap
	# that opens the first time one is re-exported (the same reason
	# `Enemy._build_model` measures height instead of taking a scale factor).
	var probe := packed.instantiate() as Node3D
	var span := _span(probe)
	probe.queue_free()
	var pitch := span.x
	if pitch <= 0.01:
		pitch = 2.0
	var tall := height if height > 0.01 else span.y
	if tall <= 0.01:
		tall = 1.0

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var n := int(ceil(length / pitch))
	var start := -length * 0.5 + pitch * 0.5
	for i in n:
		var panel := packed.instantiate() as Node3D
		panel.position = Vector3(start + float(i) * pitch, 0.0, 0.0)
		# Alternating lean, plus a little noise, so the eye reads individual
		# panels instead of a ribbon. Rotation about X tips it toward/away from
		# the viewer, which is the axis a leaning fence actually leans on.
		var side := 1.0 if i % 2 == 0 else -1.0
		panel.rotation.x = deg_to_rad(lean_deg * side * rng.randf_range(0.5, 1.0))
		panel.rotation.y = deg_to_rad(rng.randf_range(-1.2, 1.2))
		add_child(panel)

	# One box for the whole run. The hero should slide along a fence, not catch on
	# every post -- the same call KitWall makes, for the same reason.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, tall, 0.35)
	col.shape = box
	col.position.y = tall * 0.5
	add_child(col)


## Size of a subtree's mesh bounds, in its own space. Panels are authored centred
## on X and standing on y = 0, but not all of them are, so this measures the AABB
## rather than trusting it. X is the repeat pitch; Y is the collider height.
static func _span(n: Node) -> Vector3:
	var span := Vector3.ZERO
	for mi in _meshes(n):
		var aabb := mi.mesh.get_aabb() if mi.mesh != null else AABB()
		var s := aabb.size * mi.scale
		span = span.max(s)
	return span


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
