class_name DungeonRoom
extends Node3D
## One room, built from the P6 kit at run time.
##
## Wall placement follows KitWall's local frame exactly (scripts/kit/kit_wall.gd):
## the run is along local X, the FINISHED FACE looks down local +Z, and it rises
## from y = 0. So the north wall sits at z = -half with no rotation, and each
## following side is another -90 degrees. Getting this backwards builds a room
## whose masonry all faces out into the void — it renders, it just looks like
## untextured grey boxes from the inside.
##
## Doors are barred until the room is clear. That is what makes "clear the room"
## a thing the player does rather than a thing they can walk past, and it is the
## unit the extraction fee is priced in (docs/METAGAME.md §6).

signal exit_taken(dir: int)
signal room_cleared

const SIZE := 18.0
const HALF := SIZE * 0.5
const CEIL := K.CEIL_ROOM

const SC_FLOOR := "res://scenes/kit/floor_slab.tscn"
const SC_CEIL := "res://scenes/kit/ceiling_slab.tscn"
const SC_WALL := "res://scenes/kit/wall_segment.tscn"
const SC_DOOR := "res://scenes/kit/doorway.tscn"
const SC_TORCH := "res://scenes/kit/torch.tscn"

## The sealed-door bars. Unshaded, so they hold this colour whatever the room's
## torches are doing, and hot enough to catch the eye without out-shining them.
const BAR_COLOR := Color(1.0, 0.38, 0.14, 1.0)
const BAR_COUNT := 6
const BAR_WIDTH := 0.09

var data: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var is_cleared: bool = false

var _rng := RandomNumberGenerator.new()
var _barriers: Array[Node3D] = []
var _triggers: Array[Area3D] = []
var _live_enemies: int = 0


## Yaw, in radians, for the wall on side `dir` so its finished face looks inward.
static func wall_yaw(dir: int) -> float:
	match dir:
		DungeonMap.Dir.N: return 0.0
		DungeonMap.Dir.E: return -PI * 0.5
		DungeonMap.Dir.S: return PI
		_: return PI * 0.5


## Centre of the wall on side `dir`, at floor level.
static func wall_centre(dir: int) -> Vector3:
	match dir:
		DungeonMap.Dir.N: return Vector3(0, 0, -HALF)
		DungeonMap.Dir.E: return Vector3(HALF, 0, 0)
		DungeonMap.Dir.S: return Vector3(0, 0, HALF)
		_: return Vector3(-HALF, 0, 0)


## Inward unit vector from the wall on side `dir`.
static func inward(dir: int) -> Vector3:
	match dir:
		DungeonMap.Dir.N: return Vector3(0, 0, 1)
		DungeonMap.Dir.E: return Vector3(-1, 0, 0)
		DungeonMap.Dir.S: return Vector3(0, 0, -1)
		_: return Vector3(1, 0, 0)


## Where the hero stands when he arrives through the door on side `dir`.
func entry_point(dir: int) -> Vector3:
	return wall_centre(dir) + inward(dir) * 2.6 + Vector3.UP * 0.05


func setup(p_data: Dictionary, p_cell: Vector2i, seed_val: int) -> void:
	data = p_data
	cell = p_cell
	_rng.seed = seed_val


func _ready() -> void:
	_build_shell()
	_build_walls()
	_build_torches()
	_spawn_contents()
	# The entrance is pre-cleared, and a room whose roster rolled empty must not
	# soft-lock the player behind its own barriers.
	if _live_enemies == 0:
		_clear_room(true)


# --- Geometry ---------------------------------------------------------------

func _build_shell() -> void:
	var floor_node := _instance(SC_FLOOR)
	if floor_node != null:
		floor_node.set(&"size", Vector2(SIZE, SIZE))
		floor_node.position = Vector3.ZERO
		add_child(floor_node)

	var ceil_node := _instance(SC_CEIL)
	if ceil_node != null:
		ceil_node.set(&"size", Vector2(SIZE, SIZE))
		ceil_node.position = Vector3(0, CEIL, 0)
		add_child(ceil_node)


func _build_walls() -> void:
	var exits: Array = data.get("exits", [])
	for dir: int in [DungeonMap.Dir.N, DungeonMap.Dir.E, DungeonMap.Dir.S, DungeonMap.Dir.W]:
		var has_exit: bool = exits.has(dir)
		var node := _instance(SC_DOOR if has_exit else SC_WALL)
		if node == null:
			continue
		node.set(&"span" if has_exit else &"length", SIZE)
		node.set(&"height", CEIL)
		node.position = wall_centre(dir)
		node.rotation.y = wall_yaw(dir)
		add_child(node)
		if has_exit:
			_build_door(dir)


func _build_door(dir: int) -> void:
	var centre := wall_centre(dir)
	var into := inward(dir)

	# A portcullis of light rather than a pane of it. A full-opening quad — at
	# any opacity, in any blend mode — reads as a solid slab from two metres
	# away and hides the room beyond; bars say "sealed, and it will open"
	# without taking the view away. One MeshInstance holds them all so the
	# dissolve still has a single material to fade.
	var barrier := StaticBody3D.new()
	barrier.collision_layer = K.L_WORLD
	barrier.position = centre + into * 0.35 + Vector3.UP * (K.DOOR_H * 0.5)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BAR_COLOR

	var bars := MeshInstance3D.new()
	bars.mesh = _bar_mesh()
	bars.material_override = mat
	bars.rotation.y = wall_yaw(dir)
	barrier.add_child(bars)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(K.DOOR_W + 0.4, K.DOOR_H, 0.5)
	col.shape = shape
	col.rotation.y = wall_yaw(dir)
	barrier.add_child(col)

	add_child(barrier)
	_barriers.append(barrier)

	# The trigger sits just OUTSIDE the barrier line, so the player has to
	# actually walk into the opening to leave.
	var trigger := Area3D.new()
	trigger.collision_layer = K.L_INTERACT
	trigger.collision_mask = K.L_PLAYER
	trigger.monitoring = false
	trigger.position = centre + into * 0.9 + Vector3.UP * 1.0
	var tcol := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(K.DOOR_W, 2.4, 1.4)
	tcol.shape = tshape
	tcol.rotation.y = wall_yaw(dir)
	trigger.add_child(tcol)
	add_child(trigger)
	trigger.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group(&"player"):
			exit_taken.emit(dir))
	_triggers.append(trigger)


## Vertical bars plus a lintel, as one mesh centred on the door's midpoint.
static func _bar_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_h := K.DOOR_H * 0.5
	var step := K.DOOR_W / float(BAR_COUNT)
	for i in BAR_COUNT:
		var x := -K.DOOR_W * 0.5 + step * (float(i) + 0.5)
		_add_box(st, Vector3(x, 0.0, 0.0), Vector3(BAR_WIDTH, K.DOOR_H, BAR_WIDTH))
	_add_box(st, Vector3(0.0, half_h - BAR_WIDTH, 0.0),
		Vector3(K.DOOR_W, BAR_WIDTH, BAR_WIDTH))
	_add_box(st, Vector3(0.0, -half_h + BAR_WIDTH, 0.0),
		Vector3(K.DOOR_W, BAR_WIDTH, BAR_WIDTH))
	st.generate_normals()
	return st.commit()


static func _add_box(st: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in indices:
		st.add_vertex(verts[i] + at)


func _build_torches() -> void:
	var exits: Array = data.get("exits", [])
	for dir: int in [DungeonMap.Dir.N, DungeonMap.Dir.E, DungeonMap.Dir.S, DungeonMap.Dir.W]:
		if exits.has(dir):
			continue
		# Two sconces per blank wall, off-centre, so the room has pools of light
		# with dark between them rather than even coverage.
		for offset in [-HALF * 0.45, HALF * 0.45]:
			var torch := _instance(SC_TORCH)
			if torch == null:
				return
			var along := Vector3(1, 0, 0).rotated(Vector3.UP, wall_yaw(dir))
			torch.position = wall_centre(dir) + along * offset \
				+ inward(dir) * 0.35 + Vector3.UP * KitStyle.SCONCE_Y
			torch.rotation.y = wall_yaw(dir)
			torch.set(&"rng_seed", _rng.randi_range(1, 9999))
			add_child(torch)


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_error("DungeonRoom: missing kit scene %s" % path)
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


# --- Contents ---------------------------------------------------------------

func _spawn_contents() -> void:
	var band: int = data.get("band", 1)

	var kinds: Array = data.get("enemies", [])
	if not data.get("cleared", false):
		for i in kinds.size():
			var pos := _scatter_point(i, kinds.size())
			var e := Enemy.spawn(self, kinds[i], pos, _rng.randi())
			_live_enemies += 1
			e.died_at.connect(_on_enemy_died)

	if data.get("has_chest", false):
		var chest_pos := Vector3(
			_rng.randf_range(-HALF * 0.5, HALF * 0.5), 0.0,
			_rng.randf_range(-HALF * 0.5, HALF * 0.5))
		var c := Chest.spawn(self, chest_pos, band, _rng.randi())
		c.rotation.y = _rng.randf_range(-PI, PI)


## Spread spawns around a ring so a group does not arrive as one clump the
## player can hit with a single swing.
func _scatter_point(i: int, total: int) -> Vector3:
	var angle := TAU * (float(i) / maxf(float(total), 1.0)) + _rng.randf_range(-0.3, 0.3)
	var radius := _rng.randf_range(HALF * 0.30, HALF * 0.62)
	return Vector3(cos(angle) * radius, 0.1, sin(angle) * radius)


func _on_enemy_died(_pos: Vector3) -> void:
	_live_enemies = maxi(_live_enemies - 1, 0)
	if _live_enemies == 0 and not is_cleared:
		_clear_room(false)


func _clear_room(silent: bool) -> void:
	is_cleared = true
	data["cleared"] = true
	for b in _barriers:
		if is_instance_valid(b):
			_dissolve(b)
	for t in _triggers:
		if is_instance_valid(t):
			t.monitoring = true
	if not silent:
		Bus.request_sfx.emit(&"door_open", global_position)
	room_cleared.emit()


func _dissolve(barrier: Node3D) -> void:
	# Retract the bars rather than deleting them: the player has to SEE the way
	# open, or clearing a room feels like nothing happened.
	var bars := barrier.get_child(0) as MeshInstance3D
	if bars == null:
		barrier.queue_free()
		return
	var mat := bars.material_override as StandardMaterial3D
	if barrier is StaticBody3D:
		(barrier as StaticBody3D).collision_layer = 0
	var retract := func(t: float) -> void:
		bars.scale.y = t
		mat.albedo_color = BAR_COLOR * t
	var tw := create_tween()
	tw.tween_method(retract, 1.0, 0.0, 0.45)
	tw.tween_callback(barrier.queue_free)
