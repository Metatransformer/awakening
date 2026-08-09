class_name Dungeon
extends Node3D
## Generates one floor of the Lower Worlds: rooms on a grid, corridors between
## them, and everything worth walking to.
##
## The layout is a random tree, not a maze. Every room is reachable, there are no
## loops, and there are no dead ends that hold nothing -- because the only reason
## to walk down a branch is that something is at the end of it, and the extraction
## fee means every step you take is bought. A maze with empty corners is a maze
## that punishes curiosity, which is the exact opposite of what this loop needs.
##
## Two extraction pads: the one you arrived on, and one in the furthest room. The
## far pad is the whole risk curve in one object -- it is next to the best chest,
## and walking to it costs you the walk back if you change your mind.
##
## Everything rolls off `Run.rng`, which `Run.enter()` seeds. Same seed, same
## floor, same chest contents. A roguelike whose runs cannot be replayed cannot
## be debugged.

const ROOM_SCENE_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const ROOM_SCENE_CEIL := preload("res://scenes/kit/ceiling_slab.tscn")
const ROOM_SCENE_WALL := preload("res://scenes/kit/wall_segment.tscn")
const ROOM_SCENE_DOOR := preload("res://scenes/kit/doorway.tscn")
const ROOM_SCENE_TORCH := preload("res://scenes/kit/torch.tscn")
const ROOM_SCENE_PILLAR := preload("res://scenes/kit/pillar.tscn")

## Grid steps, as (x, z) cells.
const DIRS := {
	&"n": Vector2i(0, -1),
	&"s": Vector2i(0, 1),
	&"w": Vector2i(-1, 0),
	&"e": Vector2i(1, 0),
}

@export_group("Layout")
## Floor 1's shape. Every floor after it asks `Prog` instead -- see `_ready`.
@export var room_count: int = 6
@export var room_size: float = 16.0
## Centre-to-centre. The difference from `room_size` is the corridor length.
@export var spacing: float = 26.0
@export var door_span: float = 6.0
## Non-zero forces a layout, ignoring the run seed. For lookdev and bug repros.
@export var seed_override: int = 0

@export_group("Population")
@export var enemies_min: int = 2
@export var enemies_max: int = 4
## Chance a non-entrance room holds a chest. The furthest room always does.
@export var chest_chance: float = 0.55
## Chance a room has a bundle of arrows lying loose in it, on top of whatever a
## chest in that room might hold.
##
## This is the floor UNDER the bow. Chests are a detour and the fletching wants
## a bag with something in it, so a player who has neither — early, poor, and out
## of shots — would otherwise be holding a stick. A quarter of rooms means a
## short walk usually turns one up and never guarantees it. [tune]
@export var arrow_chance: float = 0.25

## cell -> {"doors": Array[StringName], "index": int, "dist": int, "node": Node3D}
var rooms: Dictionary = {}
## The cell the player arrives in.
var entrance: Vector2i = Vector2i.ZERO
## The cell furthest from the entrance along the tree.
var deepest: Vector2i = Vector2i.ZERO

var _rng: RandomNumberGenerator
var _seed_salt: int = 0


func _ready() -> void:
	# Running the scene straight from the editor or the capture harness has no
	# Run behind it. Start one rather than generating an unseeded floor.
	if not Run.in_dungeon:
		Run.enter(seed_override)
	_rng = RandomNumberGenerator.new()
	# `Run.floor_seed()`, not `Run.seed_used`: the same run seed has to give a
	# DIFFERENT floor each time you descend, and the same one every time you
	# replay that seed. Mixing the level in does both; reusing the run seed
	# would generate the identical floor over and over as you went down.
	_rng.seed = seed_override if seed_override != 0 else Run.floor_seed()
	_seed_salt = int(_rng.seed & 0xffff)

	# The floor's whole shape, from one place. Nothing here has a curve of its
	# own -- see scripts/core/progression.gd for why that matters.
	if seed_override == 0:
		room_count = Prog.rooms(Run.level)
		var pack := Prog.pack(Run.level)
		enemies_min = pack.x
		enemies_max = pack.y

	_plan()
	_build()
	_populate()


# --- Layout -----------------------------------------------------------------

## Grow a tree of rooms by repeatedly budding off an existing one. Biased toward
## the most recently placed room, which produces long walks with short spurs
## rather than a blob around the entrance.
func _plan() -> void:
	rooms.clear()
	entrance = Vector2i.ZERO
	rooms[entrance] = {"doors": [] as Array, "index": 0, "dist": 0}
	var placed: Array[Vector2i] = [entrance]

	var guard := 0
	while placed.size() < room_count and guard < 400:
		guard += 1
		# 70% of the time extend the frontier; otherwise branch off anywhere.
		var from: Vector2i = placed.back() if _rng.randf() < 0.7 \
			else placed[_rng.randi_range(0, placed.size() - 1)]

		var options: Array[StringName] = []
		for d: StringName in DIRS:
			if not rooms.has(from + DIRS[d]):
				options.append(d)
		if options.is_empty():
			continue

		var dir: StringName = options[_rng.randi_range(0, options.size() - 1)]
		var cell: Vector2i = from + DIRS[dir]
		rooms[cell] = {
			"doors": [] as Array,
			"index": placed.size(),
			"dist": int(rooms[from]["dist"]) + 1,
		}
		rooms[from]["doors"].append(dir)
		rooms[cell]["doors"].append(_opposite(dir))
		placed.append(cell)

	deepest = entrance
	for cell: Vector2i in rooms:
		if int(rooms[cell]["dist"]) > int(rooms[deepest]["dist"]):
			deepest = cell


static func _opposite(d: StringName) -> StringName:
	match d:
		&"n": return &"s"
		&"s": return &"n"
		&"w": return &"e"
	return &"w"


func centre_of(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * spacing, 0.0, float(cell.y) * spacing)


# --- Geometry ---------------------------------------------------------------

func _build() -> void:
	for cell: Vector2i in rooms:
		_build_room(cell)
	# Corridors are shared, so only the room on the north/west side of an edge
	# builds one. Otherwise every corridor gets built twice, in the same place.
	for cell: Vector2i in rooms:
		for d: StringName in rooms[cell]["doors"]:
			var step: Vector2i = DIRS[d]
			if step.x > 0 or step.y > 0:
				_build_corridor(cell, d)


func _build_room(cell: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Room_%d_%d" % [cell.x, cell.y]
	root.position = centre_of(cell)
	add_child(root)
	rooms[cell]["node"] = root

	var half := room_size * 0.5
	var doors: Array = rooms[cell]["doors"]

	var floor_slab := ROOM_SCENE_FLOOR.instantiate()
	floor_slab.size = Vector2(room_size, room_size)
	root.add_child(floor_slab)

	var ceil_slab := ROOM_SCENE_CEIL.instantiate()
	ceil_slab.size = Vector2(room_size, room_size)
	ceil_slab.position.y = K.CEIL_ROOM
	root.add_child(ceil_slab)

	# A wall's finished face looks down its local +Z, so the yaw here is "which
	# way does this wall look", not "which way does it run". See KitWall's header.
	var sides := {
		&"n": {"yaw": 0.0, "at": Vector3(0.0, 0.0, -half)},
		&"s": {"yaw": PI, "at": Vector3(0.0, 0.0, half)},
		&"w": {"yaw": PI * 0.5, "at": Vector3(-half, 0.0, 0.0)},
		&"e": {"yaw": -PI * 0.5, "at": Vector3(half, 0.0, 0.0)},
	}
	for d: StringName in sides:
		_build_side(root, cell, d, float(sides[d]["yaw"]), sides[d]["at"],
			doors.has(d))

	_build_room_torches(root, cell, doors, half)


## One side of a room: a solid run, or two runs flanking a doorway.
func _build_side(root: Node3D, cell: Vector2i, d: StringName, yaw: float,
		at: Vector3, has_door: bool) -> void:
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))   ## the wall's local +X in world

	if not has_door:
		var w := ROOM_SCENE_WALL.instantiate()
		w.length = room_size
		w.height = K.CEIL_ROOM
		w.rng_seed = _salt(cell, d, 1)
		w.position = at
		w.rotation.y = yaw
		root.add_child(w)
		return

	var seg := (room_size - door_span) * 0.5
	if seg > 0.4:
		for s in [-1.0, 1.0]:
			var w := ROOM_SCENE_WALL.instantiate()
			w.length = seg
			w.height = K.CEIL_ROOM
			w.rng_seed = _salt(cell, d, 2 if s < 0.0 else 3)
			w.position = at + along * (s * (door_span + seg) * 0.5)
			w.rotation.y = yaw
			root.add_child(w)

	var door := ROOM_SCENE_DOOR.instantiate()
	door.span = door_span
	door.height = K.CEIL_ROOM
	door.rng_seed = _salt(cell, d, 4)
	door.position = at
	door.rotation.y = yaw
	root.add_child(door)


func _build_corridor(cell: Vector2i, d: StringName) -> void:
	var step: Vector2i = DIRS[d]
	var axis := Vector3(float(step.x), 0.0, float(step.y))
	var length := spacing - room_size
	if length < 0.5:
		return

	var root := Node3D.new()
	root.name = "Corr_%d_%d_%s" % [cell.x, cell.y, d]
	root.position = centre_of(cell) + axis * (spacing * 0.5)
	add_child(root)

	var w := K.CORRIDOR_W
	var running_z := absf(axis.z) > 0.5
	var size := Vector2(w, length) if running_z else Vector2(length, w)

	var floor_slab := ROOM_SCENE_FLOOR.instantiate()
	floor_slab.size = size
	root.add_child(floor_slab)

	var ceil_slab := ROOM_SCENE_CEIL.instantiate()
	ceil_slab.size = size
	ceil_slab.position.y = K.CEIL_CORRIDOR
	root.add_child(ceil_slab)

	# Side walls face inward, so the pair is (+90, -90) about the corridor's axis.
	var yaws := [PI * 0.5, -PI * 0.5] if running_z else [0.0, PI]
	var offs := [Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0)] if running_z \
		else [Vector3(0, 0, -w * 0.5), Vector3(0, 0, w * 0.5)]
	for i in 2:
		var seg := ROOM_SCENE_WALL.instantiate()
		seg.length = length
		seg.height = K.CEIL_CORRIDOR
		seg.rng_seed = _salt(cell, d, 10 + i)
		seg.position = offs[i]
		seg.rotation.y = yaws[i]
		root.add_child(seg)

	# One sconce per corridor, on alternating sides, so a corridor is a dark
	# stretch with a single landmark rather than an evenly-lit tube.
	var side := 0 if (cell.x + cell.y) % 2 == 0 else 1
	var torch := ROOM_SCENE_TORCH.instantiate()
	torch.rng_seed = _salt(cell, d, 20)
	torch.light_range = 8.0
	torch.light_energy = 7.0
	torch.position = offs[side] + Vector3(0.0, KitStyle.SCONCE_Y, 0.0)
	torch.rotation.y = yaws[side]
	root.add_child(torch)


func _build_room_torches(root: Node3D, cell: Vector2i, doors: Array,
		half: float) -> void:
	var sides := {
		&"n": {"yaw": 0.0, "at": Vector3(0.0, 0.0, -half)},
		&"s": {"yaw": PI, "at": Vector3(0.0, 0.0, half)},
		&"w": {"yaw": PI * 0.5, "at": Vector3(-half, 0.0, 0.0)},
		&"e": {"yaw": -PI * 0.5, "at": Vector3(half, 0.0, 0.0)},
	}
	var n := 0
	for d: StringName in sides:
		var yaw: float = sides[d]["yaw"]
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		# A walled side gets two sconces; a doorway side gets none, so the exits
		# read as the dark holes they are.
		if doors.has(d):
			continue
		for s in [-1.0, 1.0]:
			var t := ROOM_SCENE_TORCH.instantiate()
			t.rng_seed = _salt(cell, d, 30 + n)
			t.cast_shadow = n < 2
			t.position = sides[d]["at"] + along * (s * room_size * 0.26) \
				+ Vector3(0.0, KitStyle.SCONCE_Y, 0.0)
			t.rotation.y = yaw
			root.add_child(t)
			n += 1


## A stable per-piece seed. Two walls sharing a seed are visibly identical, and
## a floor whose seeds came from a running counter reshuffles every stone the
## moment you add a room.
func _salt(cell: Vector2i, d: StringName, slot: int) -> int:
	return absi(_seed_salt + cell.x * 7919 + cell.y * 104729
		+ int(d.hash() % 997) * 31 + slot * 13) % 100000 + 1


# --- Population -------------------------------------------------------------

func _populate() -> void:
	for cell: Vector2i in rooms:
		var root: Node3D = rooms[cell].get("node")
		if root == null:
			continue
		_add_room_trigger(root, cell)

		# The entrance room stays empty. It used to hold the extraction pad; the
		# way out is the Homeward Charm now (scripts/items/homeward_charm.gd),
		# so there is no room you have to walk back to.
		if cell == entrance:
			continue

		var dist := int(rooms[cell]["dist"])
		# One number for "how dangerous is this room allowed to be": the floor
		# plus how far into it you have walked. Keeping the roster and the elite
		# roll on the SAME number is what makes the deepest room of floor 1
		# overlap with the first room of floor 2 rather than jump.
		var band := Prog.band(Run.level, dist)
		var elite_chance := Prog.elite_chance(Run.level)
		var count := _rng.randi_range(enemies_min, enemies_max)
		for i in count:
			var spot := _scatter(i, count, room_size * 0.30)
			# The deepest room opens with a wraith, whatever else it rolls. The
			# end of a run should be a thing you recognise on sight, and a room
			# that happened to roll three goblins does not read as the bottom.
			var kind: StringName = &"wraith" if (cell == deepest and i == 0) \
				else _roll_kind(band)
			# At most one elite in a room. The point of an elite is that it is
			# THE thing in the room; two of them is just a harder room, and the
			# separation rule has to keep them both legible besides.
			var elite := i == 0 and _rng.randf() < elite_chance
			_spawn_foe(root, kind, spot, elite)

		var wants_chest := cell == deepest or _rng.randf() < chest_chance
		if wants_chest:
			var chest := Chest.new()
			chest.picks = Prog.chest_picks(Run.level, cell == deepest)
			chest.position = Vector3(0.0, 0.0, -room_size * 0.32)
			root.add_child(chest)

		# Arrows on the floor, opposite the chest and away from the door line, so
		# picking them up is a step off the path you were already walking rather
		# than something you collect by accident on the way through. Rolled here
		# and not inside the chest branch: a room with no chest is exactly the
		# room a dry quiver needs supply in.
		if _rng.randf() < arrow_chance:
			var bundle := ArrowBundle.new()
			bundle.count = ArrowBundle.FLOOR_COUNT
			bundle.position = Vector3(room_size * 0.30, 0.0, -room_size * 0.24)
			root.add_child(bundle)

		# The way down, in the deepest room, beside the best chest. Deliberately
		# next to the reward and at the end of the longest walk: the moment you
		# can go deeper is the moment you have the most to lose.
		if cell == deepest:
			var down := Stairs.new()
			down.position = Vector3(0.0, 0.0, room_size * 0.26)
			root.add_child(down)

		if _rng.randf() < 0.35:
			for i in 2:
				var p := ROOM_SCENE_PILLAR.instantiate()
				p.height = K.CEIL_ROOM
				p.position = Vector3(room_size * (0.30 if i == 0 else -0.30),
					0.0, room_size * 0.30)
				root.add_child(p)


## What each depth band is allowed to spawn.
##
## Bands, not scaling. The monsters do not get stronger because the player did;
## they get stronger because the player walked further in. That is what makes
## the map worth reading and what keeps a first run's shallow rooms genuinely
## easy on a tenth run -- level-scaling would flatten both (docs/GDD.md §5).
##
## `crawler` is the box-built enemy; the rest are `Enemy` kinds driven by the
## monster models. The crawler stays as the shallow-water fight so the entrance
## rooms still open with something readable and cheap.
const BANDS := {
	1: [&"crawler", &"crawler", &"goblin"],
	2: [&"crawler", &"goblin", &"skeleton"],
	3: [&"goblin", &"skeleton", &"skeleton", &"kobold"],
	4: [&"skeleton", &"kobold", &"kobold", &"orc"],
}
## Anything deeper than the last band.
const BAND_DEEP: Array[StringName] = [&"kobold", &"orc", &"orc", &"wraith"]


func _roll_kind(dist: int) -> StringName:
	var pool: Array = BANDS.get(maxi(dist, 1), BAND_DEEP)
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _spawn_foe(root: Node3D, kind: StringName, at: Vector3,
		elite: bool = false) -> void:
	# `position`, not `global_position`: the room root is already placed at its
	# cell centre, and `at` is the scatter offset inside it. Assigning a global
	# here would stack every room's spawns on top of the entrance.
	if kind == &"crawler":
		var c := Crawler.new()
		c.position = at
		root.add_child(c)
		return
	var e := Enemy.new()
	e.kind = kind
	e.drop_seed = _rng.randi()
	e.level = Run.level
	e.elite = elite
	e.position = at
	root.add_child(e)


## Ring-scatter with a jitter, rather than uniform random: a uniform scatter puts
## two crawlers on top of each other often enough to look like a bug.
func _scatter(i: int, total: int, radius: float) -> Vector3:
	var a := TAU * (float(i) + _rng.randf_range(-0.18, 0.18)) / float(maxi(total, 1))
	var r := radius * _rng.randf_range(0.55, 1.0)
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## Counts a room the first time the player walks into it. Depth drives the
## extraction fee's sense of "how far in am I", so it has to be entry-driven and
## not layout-driven -- a room you never opened never happened.
func _add_room_trigger(root: Node3D, cell: Vector2i) -> void:
	var area := Area3D.new()
	area.name = "Trigger"
	area.collision_layer = 0
	area.collision_mask = K.L_PLAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(room_size * 0.9, K.CEIL_ROOM, room_size * 0.9)
	cs.shape = box
	cs.position.y = K.CEIL_ROOM * 0.5
	area.add_child(cs)
	root.add_child(area)

	var visited := [cell == entrance]
	area.body_entered.connect(func(body: Node3D) -> void:
		if not body.is_in_group(&"player") or visited[0]:
			return
		visited[0] = true
		Run.descend()
		Bus.room_entered.emit(StringName(root.name)))
