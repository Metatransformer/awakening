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
## Everything rolls off `Run.rng`, which `Run.enter()` seeds. Same seed, same
## floor, same chest contents. A roguelike whose runs cannot be replayed cannot
## be debugged.
##
## ## Generated rooms, AUTHORED ANCHORS (docs/GDD.md §5.1)
##
## The shape of a floor is not this file's opinion any more. `FloorDb` owns the
## room count, the pack size and the roster table, and this file reads them --
## `Dungeon.BANDS` and `Dungeon.BAND_DEEP` are gone rather than kept beside
## `FloorDb.bands()`, because two tables answering one question is `CLAUDE.md`
## §0's duplicated metagame in miniature and the loser gets deleted.
##
## On top of the generated tree the manifest names four guaranteed placements,
## as RULES rather than coordinates (`FloorDb.ANCHORS_STANDARD`):
##
##   `boss_door`      the deepest room's far wall, **where the stair used to be**.
##                    The deepest room becomes the boss's arena, so it is built
##                    wider than the rest of the floor -- see `_room_size_for`.
##   `deep_chest`     beside it, carrying the floor's `deep_chest` relic.
##   `shortcut_door`  a blank wall of the entrance room. Floor N's OWN boss item
##                    opens it and it skips floor N (GDD §5.3, sentence one).
##   `vault_door`     a blank wall of the middle ring. Floor N+1's boss item opens
##                    it and behind it is the `Vault` prefab (sentence two).
##
## Both fork rules are one line each and both come off `FloorDb`, so they cannot
## drift from the sentences in the GDD. Floor 4 having no vault is not written
## here either: `FloorDb.vault_key(4)` is empty because there is no floor 5, and
## an anchor with no key is not placed.
##
## **Unauthored floors are unchanged.** The Long Descent's row authors no anchors
## (`FloorDb.ANCHORS_ENDLESS` is empty), so the deepest room gets its `Stairs` and
## its wraith exactly as it did before the Descent existed. `Stairs` keeps its job
## on every floor: behind a boss door and behind a shortcut door there is one, in
## a short landing, and pressing it is still the commitment.
##
## **The tint field is deliberately NOT read.** The zone/colour work is parked
## behind SCOPE §4.1's gate; a floor is its shape and its roster this round.

const ROOM_SCENE_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const ROOM_SCENE_CEIL := preload("res://scenes/kit/ceiling_slab.tscn")
const ROOM_SCENE_WALL := preload("res://scenes/kit/wall_segment.tscn")
const ROOM_SCENE_DOOR := preload("res://scenes/kit/doorway.tscn")
const ROOM_SCENE_TORCH := preload("res://scenes/kit/torch.tscn")
const ROOM_SCENE_PILLAR := preload("res://scenes/kit/pillar.tscn")

## Loaded by PATH, never named. `Vault` is a `class_name` added in the same change
## as this file, so it is not in the global script class cache until somebody runs
## `--import`; naming it here is a PARSE error that takes the whole floor down
## before its first frame. `boss_arena.gd` records the same lesson about `Boss`.
const VAULT_SCRIPT := "res://scripts/world/vault.gd"
const ARENA_SCRIPT := "res://scripts/world/boss_arena.gd"
const BOSS_DOOR_SCRIPT := "res://scripts/world/boss_door.gd"

## Grid steps, as (x, z) cells.
const DIRS := {
	&"n": Vector2i(0, -1),
	&"s": Vector2i(0, 1),
	&"w": Vector2i(-1, 0),
	&"e": Vector2i(1, 0),
}

## The order anchors are resolved in, and it is load-bearing rather than
## alphabetical: the boss door claims the deepest room's far wall first, so the
## chest beside it can be measured off a side that is already decided, and the
## vault -- which needs the most clear ground behind it -- picks before nothing.
const ANCHOR_ORDER: Array[StringName] = [
	&"boss_door", &"deep_chest", &"shortcut_door", &"vault_door",
]

@export_group("Layout")
## Fallback only. `_ready` asks `FloorDb` for the real number -- see the note
## there about why the manifest wins even when a seed is forced.
@export var room_count: int = 6
@export var room_size: float = 16.0
## Centre-to-centre. The difference from a room's size is the corridor length.
@export var spacing: float = 26.0
@export var door_span: float = 6.0
## Non-zero forces the LAYOUT, ignoring the run seed. For lookdev and bug repros.
##
## It no longer suppresses the manifest. It used to, and that was a second answer
## to "how big is this floor": a director that forced a seed to get a repeatable
## layout also silently got the export's room count instead of the Cistern's six,
## so the one harness able to check the manifest was the one that could not see it.
@export var seed_override: int = 0

@export_group("Population")
@export var enemies_min: int = 2
@export var enemies_max: int = 4
## Chance a non-entrance room holds a chest. The deep-chest anchor's room always
## does, anchor or no anchor.
@export var chest_chance: float = 0.55
## Chance a room has a bundle of arrows lying loose in it, on top of whatever a
## chest in that room might hold.
##
## This is the floor UNDER the bow. Chests are a detour and the fletching wants
## a bag with something in it, so a player who has neither — early, poor, and out
## of shots — would otherwise be holding a stick. A quarter of rooms means a
## short walk usually turns one up and never guarantees it. [tune]
@export var arrow_chance: float = 0.25

# --- The anchored landing ----------------------------------------------------
## Behind a boss door and behind a shortcut door there is a short passage and a
## small chamber with the way down in it. Small on purpose: it is a threshold,
## not a room, and the `Stairs` is the only thing in it.
const LAND_STUB := 4.0
const LAND_SIZE := 9.0

## cell -> {"doors": Array[StringName], "index": int, "dist": int,
##          "parent": Vector2i, "size": float, "anchors": Dictionary, "node": Node3D}
var rooms: Dictionary = {}
## The cell the player arrives in.
var entrance: Vector2i = Vector2i.ZERO
## The cell furthest from the entrance along the tree.
var deepest: Vector2i = Vector2i.ZERO
## anchor id -> {"cell": Vector2i, "side": StringName, "offset": Vector2,
##               "node": Node}. Empty on an unauthored floor.
var placements: Dictionary = {}

var _rng: RandomNumberGenerator
var _seed_salt: int = 0
## Grid cells spoken for by something built OUTSIDE the room tree -- a landing, a
## vault. Nothing may bud into one and no later anchor may point through one.
var _reserved: Dictionary = {}


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

	# The floor's whole shape, from one place -- and that place is the manifest
	# now, not this file. `FloorDb` defers to `Prog` for anything it did not
	# author (`ROOMS_FROM_PROG` / `PACK_FROM_PROG`), so `Prog` is still the only
	# difficulty CURVE and levels past the last authored floor still answer.
	room_count = FloorDb.rooms(Run.level)
	var pack := FloorDb.pack(Run.level)
	enemies_min = pack.x
	enemies_max = pack.y

	_plan()
	# Anchors before the map, so that a future `_publish` that wants to mark the
	# vault or the boss door has them to mark. `_publish`'s own contract is only
	# that it runs after `_plan` and before `_build`, and it still does.
	_plan_anchors()
	_publish()
	_build()
	_build_anchors()
	_populate()


# --- Layout -----------------------------------------------------------------

## Grow a tree of rooms by repeatedly budding off an existing one. Biased toward
## the most recently placed room, which produces long walks with short spurs
## rather than a blob around the entrance.
func _plan() -> void:
	rooms.clear()
	entrance = Vector2i.ZERO
	rooms[entrance] = {
		"doors": [] as Array, "index": 0, "dist": 0, "parent": entrance,
		"size": room_size, "anchors": {},
	}
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
			"parent": from,
			"size": room_size,
			"anchors": {},
		}
		rooms[from]["doors"].append(dir)
		rooms[cell]["doors"].append(_opposite(dir))
		placed.append(cell)

	deepest = entrance
	for cell: Vector2i in rooms:
		if int(rooms[cell]["dist"]) > int(rooms[deepest]["dist"]):
			deepest = cell

	# The deepest room is the boss's arena on an authored floor, and an arena is
	# a circle the table sized (11 m for the Warden, 13 for the Bellwake). A 16 m
	# room cannot hold one: the seal ring would come up outside the masonry and
	# the fight would happen through a wall. So the chamber is built to fit the
	# ring with two metres of stone to spare -- and it still clears its
	# neighbours, because a 26 m grid puts the next room's near face 18 m out and
	# the widest chamber in the game reaches 15.
	rooms[deepest]["size"] = _room_size_for(deepest)


static func _opposite(d: StringName) -> StringName:
	match d:
		&"n": return &"s"
		&"s": return &"n"
		&"w": return &"e"
	return &"w"


func centre_of(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * spacing, 0.0, float(cell.y) * spacing)


## Hand the plan to `Atlas`, which is what the minimap and the MAP screen draw.
##
## Between `_plan` and `_build` on purpose: the map is a picture of the LAYOUT,
## and the layout is finished the moment `_plan` returns. Publishing after the
## geometry would tie the map's existence to a build step it has no stake in, and
## publishing from inside `_build_room` would mean a floor that failed halfway
## through building had half a map.
##
## Markers are added later, by `_populate`, as each thing is actually placed --
## never predicted from the same roll twice. A map that said "chest" because the
## generator was ABOUT to roll one is a map that lies the first time the two
## rolls are reordered.
func _publish() -> void:
	Atlas.open_floor(Run.level, spacing, room_size, door_span, entrance)
	for cell: Vector2i in rooms:
		Atlas.add_room(cell, rooms[cell]["doors"])
	Atlas.mark(entrance, Atlas.M_ENTRANCE)


## The deepest room is built wider than the rest when a boss lives in it, so a
## caller that needs a room's real footprint has to ask rather than read
## `room_size`. NOTE: `_publish` above still hands `Atlas` the DEFAULT size, so
## the minimap draws the arena at ordinary width. Cosmetic, and left alone here
## rather than fixed inside a merge.
func size_of(cell: Vector2i) -> float:
	return float(rooms.get(cell, {}).get("size", room_size))


## How wide the deepest room has to be. `BossDb`'s authored arena radius plus a
## two-metre skirt, or the ordinary room on a floor with no boss.
func _room_size_for(cell: Vector2i) -> float:
	if cell == entrance:
		return room_size
	var id := FloorDb.boss(Run.level)
	if id == &"" or FloorDb.anchor(Run.level, &"boss_door").is_empty():
		return room_size
	var row := BossDb.get_boss(id)
	if row.is_empty():
		return room_size
	var arena: Dictionary = row.get("arena", {})
	return maxf(room_size, float(arena.get("radius", 11.0)) * 2.0 + 4.0)


## The tree path from the entrance to `cell`, inclusive at both ends. Public
## because it is the only honest way to walk a generated floor: a director that
## made straight for an anchor would be measuring line of sight, not reachability.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not rooms.has(cell):
		return out
	var at := cell
	var guard := 0
	while guard < 400:
		guard += 1
		out.push_front(at)
		if at == entrance:
			break
		at = rooms[at]["parent"]
	return out


# --- Anchors -----------------------------------------------------------------

## Turn the manifest's four RULES into four cells and four wall sides.
##
## Nothing here decides what an anchor IS -- that is `_build_anchors` -- and
## nothing here invents a floor's contents. An anchor with no key (`vault_key`
## on floor 4) and an anchor with no room to sit in (a `mid_ring` on a two-room
## floor) are both simply not placed, which is how the table says "this floor
## does not have one" without a branch.
func _plan_anchors() -> void:
	placements.clear()
	_reserved.clear()
	var table := FloorDb.anchors(Run.level)
	if table.is_empty():
		return

	for id: StringName in ANCHOR_ORDER:
		if not table.has(id) or not _anchor_keyed(id):
			continue
		var rule: Dictionary = table[id]
		# Untyped on purpose: `_room_for` answers `null` on a floor too short to
		# have a middle ring, and `:=` cannot infer a type from a Variant
		# (CLAUDE.md §3).
		var cell = _room_for(StringName(rule.get("room", &"")))
		if cell == null or not rooms.has(cell):
			continue
		var offset: Vector2 = rule.get("offset", Vector2.ZERO)
		if StringName(rule.get("at", &"floor")) != &"wall":
			placements[id] = {"cell": cell, "side": &"", "offset": offset,
				"node": null}
			continue
		var reach := _reach_for(id, cell)
		var side := _pick_side(cell, StringName(rule.get("side", &"blank")), reach)
		if side == &"":
			push_warning("dungeon: no wall for anchor %s in room %s" % [id, cell])
			continue
		rooms[cell]["anchors"][side] = id
		_reserve(cell, side, reach)
		placements[id] = {"cell": cell, "side": side, "offset": offset,
			"node": null}


## Does this anchor have anything to be? The two doors are only real if the
## manifest gave them a key, and the two rules that answer that are `FloorDb`'s,
## one line each, so they cannot disagree with GDD §5.3.
func _anchor_keyed(id: StringName) -> bool:
	match id:
		&"boss_door": return FloorDb.boss(Run.level) != &""
		&"shortcut_door": return FloorDb.shortcut_key(Run.level) != &""
		&"vault_door": return FloorDb.vault_key(Run.level) != &""
	return true


## `&"entrance"`, `&"deepest"`, `&"mid_ring"` -- the three rooms the manifest is
## allowed to name. Returns `null` when the floor is too short to have one, which
## the caller reads as "skip this anchor".
func _room_for(kind: StringName):
	match kind:
		&"entrance":
			return entrance
		&"deepest":
			return deepest
		&"mid_ring":
			# The cell whose distance is nearest half the deepest's, and which is
			# neither of the other two. Ties break on the plan index so the same
			# seed picks the same room every time.
			var want := float(rooms[deepest]["dist"]) * 0.5
			var best = null
			var best_key := Vector2(1e9, 1e9)
			for cell: Vector2i in rooms:
				if cell == entrance or cell == deepest:
					continue
				var key := Vector2(absf(float(rooms[cell]["dist"]) - want),
					float(rooms[cell]["index"]))
				if key.x < best_key.x or (is_equal_approx(key.x, best_key.x)
						and key.y < best_key.y):
					best_key = key
					best = cell
			return best
	return null


## How many grid cells of empty ground this anchor needs behind its wall.
##
## Measured from what is actually built rather than guessed: a room at cell `k`
## presents its near face at `k * spacing - room_size / 2`, so every `k` whose
## face falls inside the structure has to be empty. A vault is 45 m deep and
## therefore wants two cells; a landing is 13 m and wants one.
func _reach_for(id: StringName, cell: Vector2i) -> int:
	var depth := LAND_STUB + LAND_SIZE
	if id == &"vault_door":
		depth = _vault_depth()
	var far_edge := size_of(cell) * 0.5 + depth
	return maxi(1, int(floor((far_edge + room_size * 0.5) / spacing)))


## `Vault`'s total depth, asked of the prefab rather than restated here. Read off
## the script's constants so the two cannot drift -- a vault that grew a room and
## a clearance rule that did not is a vault built through a corridor.
func _vault_depth() -> float:
	var script := load(VAULT_SCRIPT) as GDScript
	if script == null:
		return 45.0
	var consts := script.get_script_constant_map()
	return float(consts.get("TOTAL_DEPTH", 45.0))


## Pick a wall for an anchor.
##
## `&"blank"` is any side with no corridor doorway in it (a door punched through
## a doorway is a door you cannot lock) and no anchor already on it. `&"far"`
## additionally prefers the side pointing away from the room's own doorways,
## which is where the stair sits today.
##
## Clearance beats both. A door with a vault behind it that runs through the next
## room is worse than a door on a less pleasing wall, so sides are filtered to
## those with `reach` empty cells behind them first, and only ranked afterwards.
func _pick_side(cell: Vector2i, mode: StringName, reach: int) -> StringName:
	var doors: Array = rooms[cell]["doors"]
	var taken: Dictionary = rooms[cell]["anchors"]
	var away := Vector2.ZERO
	for d: StringName in doors:
		var step: Vector2i = DIRS[d]
		away += Vector2(float(step.x), float(step.y))

	var roomy: Array[StringName] = []
	var any: Array[StringName] = []
	var best_run := -1
	for d: StringName in DIRS:
		if doors.has(d) or taken.has(d):
			continue
		var run := _clear_run(cell, d, reach)
		if run > best_run:
			best_run = run
			any = [d]
		elif run == best_run:
			any.append(d)
		if run >= reach:
			roomy.append(d)
	var pool := roomy if not roomy.is_empty() else any
	if pool.is_empty():
		return &""
	if mode != &"far":
		# Deterministic, off the floor's own generator, so the same seed puts the
		# shortcut on the same wall every replay.
		return pool[_rng.randi_range(0, pool.size() - 1)]

	var best: StringName = pool[0]
	var best_dot := 1e9
	for d: StringName in pool:
		var step: Vector2i = DIRS[d]
		var dot := away.dot(Vector2(float(step.x), float(step.y)))
		if dot < best_dot:
			best_dot = dot
			best = d
	return best


## Empty grid cells in a straight line out of `cell`, counted up to `limit`.
## Reserved cells count as occupied: two anchors whose structures crossed would
## be two doors into one corridor.
func _clear_run(cell: Vector2i, d: StringName, limit: int) -> int:
	var step: Vector2i = DIRS[d]
	var n := 0
	for k in range(1, limit + 1):
		var at := cell + step * k
		if rooms.has(at) or _reserved.has(at):
			break
		n += 1
	return n


func _reserve(cell: Vector2i, d: StringName, reach: int) -> void:
	var step: Vector2i = DIRS[d]
	for k in range(1, reach + 1):
		_reserved[cell + step * k] = true


func anchor_node(id: StringName) -> Node:
	return placements.get(id, {}).get("node")


func anchor_cell(id: StringName) -> Vector2i:
	return placements.get(id, {}).get("cell", entrance)


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


## The four wall planes of a room, in the room's own space. `yaw` is "which way
## does this wall LOOK" -- a wall's finished face runs down its local +Z, so the
## north wall at -Z looks back into the room. See KitWall's header.
func _sides_of(cell: Vector2i) -> Dictionary:
	var half := size_of(cell) * 0.5
	return {
		&"n": {"yaw": 0.0, "at": Vector3(0.0, 0.0, -half)},
		&"s": {"yaw": PI, "at": Vector3(0.0, 0.0, half)},
		&"w": {"yaw": PI * 0.5, "at": Vector3(-half, 0.0, 0.0)},
		&"e": {"yaw": -PI * 0.5, "at": Vector3(half, 0.0, 0.0)},
	}


## Which way a wall FACES, into the room. `-basis.z is forward` is the contract
## everything reads facing through (docs/CONTRACT.md §2.5); this is the same
## convention stated for a wall, whose finished face is its +Z.
static func facing_of(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


static func along_of(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _build_room(cell: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Room_%d_%d" % [cell.x, cell.y]
	root.position = centre_of(cell)
	add_child(root)
	rooms[cell]["node"] = root

	var size := size_of(cell)
	var doors: Array = rooms[cell]["doors"]
	var anchors: Dictionary = rooms[cell]["anchors"]

	var floor_slab := ROOM_SCENE_FLOOR.instantiate()
	floor_slab.size = Vector2(size, size)
	root.add_child(floor_slab)

	var ceil_slab := ROOM_SCENE_CEIL.instantiate()
	ceil_slab.size = Vector2(size, size)
	ceil_slab.position.y = K.CEIL_ROOM
	root.add_child(ceil_slab)

	var sides := _sides_of(cell)
	for d: StringName in sides:
		var s: Dictionary = sides[d]
		# An anchored side is punched exactly like a corridor side. The hole has
		# to exist before the door can fill it -- a LockedDoor stood against solid
		# masonry is a prop, not a gate.
		_build_side(root, cell, d, float(s["yaw"]), s["at"], size,
			doors.has(d) or anchors.has(d))

	_build_room_torches(root, cell, doors, anchors, size * 0.5)


## One side of a room: a solid run, or two runs flanking a doorway.
func _build_side(root: Node3D, cell: Vector2i, d: StringName, yaw: float,
		at: Vector3, size: float, has_door: bool) -> void:
	var along := along_of(yaw)

	if not has_door:
		var w := ROOM_SCENE_WALL.instantiate()
		w.length = size
		w.height = K.CEIL_ROOM
		w.rng_seed = _salt(cell, d, 1)
		w.position = at
		w.rotation.y = yaw
		root.add_child(w)
		return

	var seg := (size - door_span) * 0.5
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


## The corridor between two rooms, measured FACE TO FACE rather than assumed.
##
## It used to be `spacing - room_size`, which was right while every room was the
## same width and silently wrong the moment the deepest one became a 26 m boss
## chamber: the corridor kept its old length and drove ten metres into the
## chamber's floor.
func _build_corridor(cell: Vector2i, d: StringName) -> void:
	var step: Vector2i = DIRS[d]
	var other := cell + step
	if not rooms.has(other):
		return
	var axis := Vector3(float(step.x), 0.0, float(step.y))
	var here := size_of(cell) * 0.5
	var there := size_of(other) * 0.5
	var length := (centre_of(other) - centre_of(cell)).length() - here - there
	if length < 0.5:
		return

	var root := Node3D.new()
	root.name = "Corr_%d_%d_%s" % [cell.x, cell.y, d]
	root.position = centre_of(cell) + axis * (here + length * 0.5)
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
	torch.light_range = 11.0
	torch.light_energy = 6.5
	torch.position = offs[side] + Vector3(0.0, KitStyle.SCONCE_Y, 0.0)
	torch.rotation.y = yaws[side]
	root.add_child(torch)


func _build_room_torches(root: Node3D, cell: Vector2i, doors: Array,
		anchors: Dictionary, half: float) -> void:
	var n := 0
	var sides := _sides_of(cell)
	for d: StringName in sides:
		var s: Dictionary = sides[d]
		var yaw: float = s["yaw"]
		var along := along_of(yaw)
		# A walled side gets two sconces; a doorway side gets none, so the exits
		# read as the dark holes they are. An anchored side is an exit too -- and
		# a locked door brings its own cold lamp, which is the one light in the
		# room that must not have a torch beside it.
		if doors.has(d) or anchors.has(d):
			continue
		for s2 in [-1.0, 1.0]:
			var t := ROOM_SCENE_TORCH.instantiate()
			t.rng_seed = _salt(cell, d, 30 + n)
			t.cast_shadow = n < 2
			t.position = s["at"] + along * (s2 * half * 0.52) \
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


# --- The four anchors ---------------------------------------------------------

func _build_anchors() -> void:
	for id: StringName in ANCHOR_ORDER:
		if not placements.has(id):
			continue
		match id:
			&"boss_door": _place_boss(id)
			&"deep_chest": _place_deep_chest(id)
			&"shortcut_door": _place_shortcut(id)
			&"vault_door": _place_vault(id)


## Where an anchored WALL prop stands, in its room's local space. `offset` is
## (along the wall from its midpoint, proud of the face) in fractions of the
## room's size, exactly as `FloorDb`'s anchor spec words it.
func _wall_spot(p: Dictionary) -> Dictionary:
	var cell: Vector2i = p["cell"]
	var side: StringName = p["side"]
	var s: Dictionary = _sides_of(cell)[side]
	var yaw: float = s["yaw"]
	var at: Vector3 = s["at"]
	var offset: Vector2 = p["offset"]
	var size := size_of(cell)
	# 50 mm back into the reveal, the same as `_boss_test.tscn`'s doors, so the
	# doorway's surround frames the leaves instead of the leaves standing proud
	# of it.
	var pos := at + along_of(yaw) * (offset.x * size) \
		+ facing_of(yaw) * (offset.y * size - 0.05)
	return {"yaw": yaw, "pos": pos, "facing": facing_of(yaw)}


## The direction "further in" for the room holding the boss door: out through
## that door. Floor anchors are authored in this frame, which is the only frame
## in which "beside the boss door" means anything on a generated floor.
func _far_dir(cell: Vector2i) -> Vector3:
	for id: StringName in placements:
		var p: Dictionary = placements[id]
		if p["cell"] != cell or p["side"] == &"":
			continue
		if id == &"boss_door":
			return -facing_of(float(_sides_of(cell)[p["side"]]["yaw"]))
	# No boss door on this floor: point away from the room's own doorways, which
	# is the same rule `&"far"` uses.
	var away := Vector3.ZERO
	for d: StringName in rooms[cell]["doors"]:
		var step: Vector2i = DIRS[d]
		away += Vector3(float(step.x), 0.0, float(step.y))
	return -away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD


# --- Boss door + arena --------------------------------------------------------

## GDD §5.1: the boss door replaces the stair, and behind it is floor N+1. So the
## deepest room becomes the arena, the door goes on its far wall, and the way
## down is a `Stairs` in the landing on the other side of the door.
##
## The door is added BEFORE the arena and both are children of the room root, so
## the arena's `door_path` can be a plain `../BossDoor` -- `BossArena._ready`
## resolves it on the frame it enters the tree, which is before anything this
## function does afterwards could set it.
func _place_boss(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var root: Node3D = rooms[cell]["node"]
	var spot := _wall_spot(p)
	var boss_id := FloorDb.boss(Run.level)

	var door_script := load(BOSS_DOOR_SCRIPT) as GDScript
	var arena_script := load(ARENA_SCRIPT) as GDScript
	if door_script == null or arena_script == null:
		push_error("dungeon: the boss scripts failed to load")
		return

	var pos: Vector3 = spot["pos"]
	var facing: Vector3 = spot["facing"]
	var door: Node3D = door_script.new()
	door.name = "BossDoor"
	door.set(&"boss_id", boss_id)
	door.position = pos
	door.rotation.y = float(spot["yaw"])
	root.add_child(door)
	p["node"] = door

	var arena: Node3D = arena_script.new()
	arena.name = "Arena"
	arena.set(&"boss_id", boss_id)
	arena.set(&"door_path", NodePath("../BossDoor"))
	# Across the room from the way in, between the player and the door -- so the
	# thing holding the way down is a silhouette in the far half of the frame the
	# moment the room seals.
	arena.set(&"boss_offset", -facing * 5.0)
	root.add_child(arena)

	_build_landing(spot, cell, "BossLanding")


## Beside the boss door, carrying the floor's `deep_chest` relic.
##
## The relic is hooked to the chest's `activated` signal rather than put inside
## `Chest`: `RelicPickup.place` already refuses to mint a second copy of a unique
## the player is carrying or has donated, and a chest that knew about relics
## would be a second placer of them (`scripts/world/chest.gd` is not this card's
## to edit, and does not need to be).
func _place_deep_chest(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var root: Node3D = rooms[cell]["node"]
	var far := _far_dir(cell)
	var right := Vector3.UP.cross(far).normalized()
	var offset: Vector2 = p["offset"]
	var size := size_of(cell)

	var chest := Chest.new()
	chest.name = "DeepChest"
	chest.picks = Prog.chest_picks(Run.level, true)
	chest.position = right * (offset.x * size) + far * (offset.y * size)
	# Facing back down the room, so the fan of motes it throws lands in the floor
	# the player is standing on rather than in the far wall.
	chest.rotation.y = atan2(-far.x, -far.z)
	root.add_child(chest)
	p["node"] = chest

	var relic := FloorDb.relic_in(Run.level, &"deep_chest")
	if relic == &"":
		return
	chest.activated.connect(func(_by: Node3D) -> void:
		RelicPickup.place(get_tree().current_scene, relic,
			chest.global_position + Vector3.UP * 0.7,
			-far * 1.3))


# --- The two forks ------------------------------------------------------------

## GDD §5.3, sentence one: *the shortcut on floor N is opened by floor N's own
## boss item, and skips floor N.* Both halves are one line: the key is
## `FloorDb.shortcut_key`, and what is behind the door is the same `Stairs` every
## other way down in the game uses, so "skips this floor" is `Run.level + 1` and
## not a second descent path.
func _place_shortcut(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var key := FloorDb.shortcut_key(Run.level)
	if _place_locked(p, "ShortcutDoor", key, "", StringName(
			"shortcut_%d" % Run.level)) == null:
		return
	_build_landing(_wall_spot(p), cell, "ShortcutLanding")


## GDD §5.3, sentence two: *the vault on floor N is opened by floor N+1's boss
## item, and holds a relic.* Floor 4 never reaches this function -- `vault_key(4)`
## is empty because there is no floor 5, and `_anchor_keyed` drops the anchor.
func _place_vault(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var side: StringName = p["side"]
	var key := FloorDb.vault_key(Run.level)
	if _place_locked(p, "VaultDoor", key, "The Vault", StringName(
			"vault_%d" % Run.level)) == null:
		return

	var script := load(VAULT_SCRIPT) as GDScript
	if script == null:
		push_error("dungeon: %s failed to load" % VAULT_SCRIPT)
		return
	var spot := _wall_spot(p)
	var pos: Vector3 = spot["pos"]
	var door: Node = rooms[cell]["node"].get_node_or_null(^"VaultDoor")
	var vault: Node3D = script.new()
	vault.name = "Vault"
	vault.set(&"level", Run.level)
	vault.set(&"rng_seed", _salt(cell, side, 55))
	# The prefab is authored with its mouth at the origin and its rooms running
	# down local +Z, so one rotation puts it behind any wall on any floor. A node
	# turned by `yaw + PI` maps local +Z to `-facing`, which is out of the room.
	vault.position = centre_of(cell) + pos
	vault.rotation.y = float(spot["yaw"]) + PI
	add_child(vault)

	# The prize is minted when the door opens, not when the floor is built --
	# `Vault.reveal()` carries the reason. The already-open case is not a
	# nicety: `LockedDoor` records `door_open_<destination>` and comes back open
	# on the next visit, and a vault you have opened and not emptied has to still
	# have its relic in it.
	if door != null:
		door.opened.connect(func(_where: StringName) -> void: vault.call(&"reveal"))
		if door.is_open():
			vault.call(&"reveal")


## A `LockedDoor` in an anchored hole. Deliberately dumb, as the class says: it
## emits `opened(destination)` and the placer decides what the tag means. Here
## the tag means nothing at all -- what is behind the door is already standing
## there -- which is exactly the case the base class was written for.
func _place_locked(p: Dictionary, node_name: String, key: StringName,
		label: String, tag: StringName) -> Node3D:
	if key == &"":
		return null
	var cell: Vector2i = p["cell"]
	var root: Node3D = rooms[cell]["node"]
	var spot := _wall_spot(p)
	var pos: Vector3 = spot["pos"]
	var door := LockedDoor.new()
	door.name = node_name
	door.key_item = key
	door.label = label
	door.destination = tag
	door.position = pos
	door.rotation.y = float(spot["yaw"])
	root.add_child(door)
	p["node"] = door
	return door


## The threshold behind a boss door or a shortcut door: a stub of corridor, a
## small chamber, and the way down.
##
## Built as a child of the Dungeon rather than of the room, with its local +Z
## pointing out through the wall, so every piece below is authored once in
## door-space instead of four times with different signs.
func _build_landing(spot: Dictionary, cell: Vector2i, node_name: String) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = centre_of(cell) + spot["pos"]
	root.rotation.y = float(spot["yaw"]) + PI
	add_child(root)

	var tag := StringName(node_name)
	var w := K.CORRIDOR_W
	var h := K.CEIL_CORRIDOR
	var half := LAND_SIZE * 0.5
	var mid := LAND_STUB + half

	_slab(root, Vector2(w, LAND_STUB), Vector3(0.0, 0.0, LAND_STUB * 0.5), h)
	_slab(root, Vector2(LAND_SIZE, LAND_SIZE), Vector3(0.0, 0.0, mid), h)

	# The stub's two sides. A wall's face is its local +Z, so the one on -X looks
	# toward +X and vice versa.
	for s: float in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_wall(root, LAND_STUB, h, Vector3(s * w * 0.5, 0.0, LAND_STUB * 0.5),
			PI * 0.5 * -s, _salt(cell, tag, 60 + i))

	# The chamber: two sides, a back, and the front split around the stub's hole.
	for s: float in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_wall(root, LAND_SIZE, h, Vector3(s * half, 0.0, mid), PI * 0.5 * -s,
			_salt(cell, tag, 62 + i))
	_wall(root, LAND_SIZE, h, Vector3(0.0, 0.0, LAND_STUB + LAND_SIZE), PI,
		_salt(cell, tag, 64))
	var flank := (LAND_SIZE - w) * 0.5
	if flank > 0.4:
		for s: float in [-1.0, 1.0]:
			var i := 1 if s > 0.0 else 0
			_wall(root, flank, h, Vector3(s * (w + flank) * 0.5, 0.0, LAND_STUB),
				0.0, _salt(cell, tag, 66 + i))

	# One sconce on the back wall. It is the only warm light past the door, which
	# is what makes an opened door read as somewhere you can now go.
	var torch := ROOM_SCENE_TORCH.instantiate()
	torch.rng_seed = _salt(cell, tag, 68)
	torch.light_range = 10.0
	torch.light_energy = 6.5
	torch.position = Vector3(0.0, KitStyle.SCONCE_Y, LAND_STUB + LAND_SIZE - 0.1)
	torch.rotation.y = PI
	root.add_child(torch)

	# The way down. `Stairs` faces its own -Z -- the flight is in the back half of
	# the pit, descending toward the viewer -- and the viewer comes through the
	# door, which is this node's -Z. So it needs no turn of its own.
	var down := Stairs.new()
	down.name = "Down"
	down.position = Vector3(0.0, 0.0, mid + 0.6)
	root.add_child(down)


func _slab(root: Node3D, size: Vector2, at: Vector3, ceiling: float) -> void:
	var f := ROOM_SCENE_FLOOR.instantiate()
	f.size = size
	f.position = at
	root.add_child(f)
	var c := ROOM_SCENE_CEIL.instantiate()
	c.size = size
	c.position = at + Vector3(0.0, ceiling, 0.0)
	root.add_child(c)


func _wall(root: Node3D, length: float, height: float, at: Vector3, yaw: float,
		salt: int) -> void:
	var w := ROOM_SCENE_WALL.instantiate()
	w.length = length
	w.height = height
	w.rng_seed = salt
	w.position = at
	w.rotation.y = yaw
	root.add_child(w)


# --- Population -------------------------------------------------------------

func _populate() -> void:
	var has_boss := placements.has(&"boss_door")
	var boss_cell := anchor_cell(&"boss_door")

	for cell: Vector2i in rooms:
		var root: Node3D = rooms[cell].get("node")
		if root == null:
			continue
		_add_room_trigger(root, cell)

		# The entrance room stays empty. It used to hold the extraction pad; the
		# way out is the Escape Rope now (scripts/items/escape_rope.gd),
		# so there is no room you have to walk back to.
		if cell == entrance:
			continue
		# The boss's chamber holds the boss, its chest and nothing else. A
		# three-beat fight plus four bodies is not a harder fight, it is an
		# unreadable one -- SCOPE §6 names the boss ballooning as risk one and a
		# pack in the arena is the same mistake by another route.
		if has_boss and cell == boss_cell:
			continue

		var size := size_of(cell)
		var dist := int(rooms[cell]["dist"])
		# The manifest chooses WHICH body (`FloorDb.roster`, keyed on distance from
		# the entrance) and `Prog` chooses how hard it is (`elite_chance`, and the
		# health/damage/wind-up curve inside `Enemy`). Keeping those two apart is
		# what lets a floor be re-cast without being re-tuned.
		var elite_chance := Prog.elite_chance(Run.level)
		var count := _rng.randi_range(enemies_min, enemies_max)
		for i in count:
			var spot := _scatter(i, count, size * 0.30)
			var kind := _roll_kind(dist)
			# At most one elite in a room. The point of an elite is that it is
			# THE thing in the room; two of them is just a harder room, and the
			# separation rule has to keep them both legible besides.
			var elite := i == 0 and _rng.randf() < elite_chance
			_spawn_foe(root, kind, spot, elite)

		# The deep-chest anchor already put one in its room. On a floor with no
		# anchors at all the deepest room still gets the good chest, which is what
		# the Long Descent has always done.
		var anchored: bool = placements.has(&"deep_chest") \
			and anchor_cell(&"deep_chest") == cell
		if not anchored and (cell == deepest or _rng.randf() < chest_chance):
			var chest := Chest.new()
			chest.picks = Prog.chest_picks(Run.level, cell == deepest)
			chest.position = Vector3(0.0, 0.0, -size * 0.32)
			root.add_child(chest)
			Atlas.mark(cell, Atlas.M_CHEST)

		# Arrows on the floor, opposite the chest and away from the door line, so
		# picking them up is a step off the path you were already walking rather
		# than something you collect by accident on the way through. Rolled here
		# and not inside the chest branch: a room with no chest is exactly the
		# room a dry quiver needs supply in.
		if _rng.randf() < arrow_chance:
			var bundle := ArrowBundle.new()
			bundle.count = ArrowBundle.FLOOR_COUNT
			bundle.position = Vector3(size * 0.30, 0.0, -size * 0.24)
			root.add_child(bundle)
			Atlas.mark(cell, Atlas.M_ARROWS)

		# The way down, in the deepest room, beside the best chest -- on a floor
		# with no boss. On an authored floor the boss door replaced it and the
		# stair is in the landing behind that door (GDD §5.1).
		if cell == deepest and not placements.has(&"boss_door"):
			var down := Stairs.new()
			down.position = Vector3(0.0, 0.0, size * 0.26)
			root.add_child(down)
			Atlas.mark(cell, Atlas.M_STAIRS)

		if _rng.randf() < 0.35:
			for i in 2:
				var p := ROOM_SCENE_PILLAR.instantiate()
				p.height = K.CEIL_ROOM
				p.position = Vector3(size * (0.30 if i == 0 else -0.30),
					0.0, size * 0.30)
				root.add_child(p)


## What this floor is allowed to spawn at this distance from the entrance.
##
## One line, because the table moved. `Dungeon.BANDS` and `Dungeon.BAND_DEEP`
## lived here and are DELETED: `FloorDb.bands()` says the same thing per floor,
## the past-the-last-key fallback is `FloorDb.roster`'s, and two tables answering
## one question is exactly the duplication `CLAUDE.md` §0 says to resolve by
## deleting the loser rather than by landing both.
##
## Keyed on DISTANCE and not on `Prog.band()`, which is the split GDD §7 asks
## for: the curve owns how hard a body is at this depth, the manifest owns which
## body it is. The deepest room no longer opens with a hard-coded wraith either --
## floor 1's `bands_deep` is the Cistern's own answer to "what is at the bottom".
func _roll_kind(dist: int) -> StringName:
	var pool: Array = FloorDb.roster(Run.level, dist)
	if pool.is_empty():
		return &"skeleton"
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _spawn_foe(root: Node3D, kind: StringName, at: Vector3,
		elite: bool = false) -> void:
	# `position`, not `global_position`: the room root is already placed at its
	# cell centre, and `at` is the scatter offset inside it. Assigning a global
	# here would stack every room's spawns on top of the entrance.
	var e := Enemy.new()
	e.kind = kind
	e.drop_seed = _rng.randi()
	e.level = Run.level
	e.elite = elite
	e.position = at
	root.add_child(e)


## Ring-scatter with a jitter, rather than uniform random: a uniform scatter puts
## two monsters on top of each other often enough to look like a bug.
func _scatter(i: int, total: int, radius: float) -> Vector3:
	var a := TAU * (float(i) + _rng.randf_range(-0.18, 0.18)) / float(maxi(total, 1))
	var r := radius * _rng.randf_range(0.55, 1.0)
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## Counts a room the first time the player walks into it. Depth drives the
## extraction fee's sense of "how far in am I", so it has to be entry-driven and
## not layout-driven -- a room you never opened never happened.
func _add_room_trigger(root: Node3D, cell: Vector2i) -> void:
	var size := size_of(cell)
	var area := Area3D.new()
	area.name = "Trigger"
	area.collision_layer = 0
	area.collision_mask = K.L_PLAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size * 0.9, K.CEIL_ROOM, size * 0.9)
	cs.shape = box
	cs.position.y = K.CEIL_ROOM * 0.5
	area.add_child(cs)
	root.add_child(area)

	var visited := [cell == entrance]
	# The arrival cell is on the map before the player has taken a step. It is
	# the room they are standing in -- fogging it would mean the first thing the
	# minimap ever shows is a blank frame -- and it is already counted as visited
	# for the depth tally, so this is the same fact said to the same rule.
	if cell == entrance:
		Atlas.see(cell)
	area.body_entered.connect(func(body: Node3D) -> void:
		if not body.is_in_group(&"player"):
			return
		# OUTSIDE the `visited` gate. Fog is per-room and the depth tally is
		# per-FIRST-entry, and folding them together would mean a room re-entered
		# after a `close_floor` (a load into a live run) stayed dark forever.
		Atlas.see(cell)
		if visited[0]:
			return
		visited[0] = true
		Run.descend()
		Bus.room_entered.emit(StringName(root.name)))
