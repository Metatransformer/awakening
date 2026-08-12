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
## Loaded by PATH and never named: a newly added `class_name` is not in the
## global class cache until the project is re-imported. The shrine is a scene,
## because its Interactable and replaceable effigies are authored composition.
const STONE_SCENE := "res://scenes/world/votive_shrine.tscn"
const BARS_SCRIPT := "res://scripts/props/barred_passage.gd"
## And the third, for the same reason: `docs/PUZZLES.md` §5.1's door.
const SHORTCUT_GATE_SCRIPT := "res://scripts/props/shortcut_gate.gd"

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
## and the two puzzle anchors come last: `gate_room` needs no wall at all (it
## claims a ROOM, and its gate goes on a doorway the layout already chose), and
## `puzzle_room` shares the middle room with the vault, so the vault -- which
## wants two clear cells against its one -- has to pick first or it is the one
## left without a wall.
const ANCHOR_ORDER: Array[StringName] = [
	&"boss_door", &"deep_chest", &"shortcut_door", &"vault_door",
	&"gate_room", &"puzzle_room",
]

## Anchors a floor is allowed to arrive without, and therefore the ones
## `_plan_anchors` may DROP when there is no wall with clear ground behind it.
##
## `docs/PUZZLES.md` §5.3: the treasure branch is *optional, richer, harder* and
## off the critical path, so a floor missing one still plays. The vault is not in
## here even though floor 4 has none — "this floor authors no vault" is the
## manifest's decision (`FloorDb.vault_key`), not a fallback for a floor that
## wanted one and could not fit it. The rest ARE the floor.
const OPTIONAL_ANCHORS: Array[StringName] = [&"puzzle_room"]

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
## How often a floor gets a maze room (`docs/PUZZLES.md` §5.4). Not every run:
## the room is a change of pace, and a change of pace that is always there is a
## room type.
@export var maze_chance: float = 0.5
## Chance a room has a bundle of arrows lying loose in it, on top of whatever a
## chest in that room might hold.
##
## This is the floor UNDER the bow. Chests are a detour and the fletching wants
## a bag with something in it, so a player who has neither — early, poor, and out
## of shots — would otherwise be holding a stick. A quarter of rooms means a
## short walk usually turns one up and never guarantees it. [tune]
@export var arrow_chance: float = 0.25
## Occasional room furniture that can become an enemy attack. Rolled from the
## floor stream with the rest of population, so the same run seed restores both
## the cluster and the one body assigned to use it.
@export var barrel_cluster_chance: float = 0.22

# --- The anchored landing ----------------------------------------------------
## Behind a boss door and behind a shortcut door there is a short passage and a
## small chamber with the way down in it. Small on purpose: it is a threshold,
## not a room, and the `Stairs` is the only thing in it.
const LAND_STUB := 4.0
const LAND_SIZE := 9.0

# --- The treasure chamber -----------------------------------------------------
## Behind the `puzzle_room` door: a stub, then a chamber with the floor's
## miniboss, a rich chest and a sounding stone in it (`docs/PUZZLES.md` §5.3).
##
## Wide enough to hold the arena the miniboss table authored, measured the way
## `_room_size_for` measures the boss's: `BossDb`'s radius, doubled, plus a
## skirt of stone. The skirt is TEN metres and not the boss chamber's four,
## because this room has to hold something the boss chamber does not -- the
## chest and the sounding stone stand OUTSIDE the seal ring, which is the whole
## reason they are unreachable until the miniboss is down. A four-metre skirt
## would leave a two-metre band behind a 7.5 m ring, and a 2.9 m sounding stone
## does not stand in two metres.
##
## The chamber is built to the miniboss it actually gets, never to a constant
## that would be wrong the first time a floor authored a bigger one.
const CHAMBER_STUB := 4.0
const CHAMBER_MIN := 13.0
const CHAMBER_SKIRT := 10.0

## How far apart in tree distance the two ends of the chord edge have to be
## (`docs/PUZZLES.md` §4: *"pick two rooms whose `dist` differs by >= 3"*). Below
## three the shortcut saves nothing and the loop is a doorway between neighbours.
const CHORD_SPAN := 3

## **The maze gets a room of its own size, and this is that size.**
##
## 27 m square: 729 m² against the ordinary room's 256, so a shade under three
## times the floor. The maze used to be squeezed into whatever 16 m room was
## going, which cost it twice over — 3 rows deep once the lantern apron was paid
## for, and 3.1 m cells, which together is a nine-cell letterbox of corridors
## narrower than the camera's boom. A room sized to the puzzle instead of the
## puzzle sized to the room is the whole of this change.
##
## The number is `MazeRoom.fits`'s answer for a 5x5 grid — 5 * 4.03 + 2 * 3.0 =
## 26.15 — with the rest as slack. It is a CEILING and not a promise:
## `_build_corridor` measures face to face, so two rooms whose halves sum past
## `spacing` share masonry and get **no corridor at all**, and the deepest room is
## a 30 m boss chamber. `_maze_room_size` is what reconciles the two.
const MAZE_ROOM := 27.0

## A metre of stone between two rooms' faces, at the least. Two rooms that meet
## exactly at their faces share a wall and read as one room, and `_build_corridor`
## gives up under half a metre and leaves them with no corridor.
const MAZE_CLEAR := 1.0

## The maze's cells, at `MAZE_ROOM`. Square now, because that room has depth to
## spare for the apron — the old 3x4 was letterboxed by a 16 m room, not by the
## design. 5x5 at `MazeRoom.CELL` is 20.15 m across, which leaves 3.4 m of clear
## floor on every side: the apron `MazeRoom.APRON` wants on the mouth side, and a
## walkway on the other three.
##
## A ceiling, like `MAZE_ROOM` — `_maze_grid` cuts the grid down to whatever room
## the floor could actually spare, and asks `MazeRoom.fits` rather than restating
## any of that arithmetic.
const MAZE_ROWS := 5
const MAZE_COLS := 5

## Below this a maze is not worth building: `Maze.plan` refuses to deal gates into
## a grid smaller than nine cells (it cannot find a layout that is both shut as
## dealt and openable), and a room that fell through to a plain maze would be a
## walk with no puzzle in it. The number is `Maze.plan`'s and is restated here
## only because a `const` cannot read one out of another script.
const MAZE_MIN_CELLS := 9

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
## The one extra edge that turns the tree into a graph (`docs/PUZZLES.md` §4):
## `{"near": Vector2i, "far": Vector2i, "dir": StringName, "node": Node}`, where
## `dir` runs near -> far and `near` is the shallow end the bars are on. Empty on
## a floor with no gate room, because the cycle IS the gate room's reward.
var chord: Dictionary = {}
## **The room widened for the maze, chosen in `_plan_maze`.**
##
## Untyped, because "this floor had nowhere to put one" has to be expressible and
## `Vector2i` has no null (CLAUDE.md §3 — `:=` cannot infer off a Variant either,
## so every read of this is `var x =`, not `var x :=`).
##
## Reserved at PLAN time and not at populate time, which is the ordering this
## whole change turns on: the room is 27 m instead of 16, and `_build_room` lays
## its masonry from `size_of(cell)`. A cell picked in `_populate` — where the maze
## used to be chosen — is a cell whose walls are already standing, so the maze
## would be a 20 m grid inside a 16 m room with its lanterns buried in the stone.
## That exact bug shipped once already for a different reason; see `MazeRoom.APRON`.
var maze_reserved = null
## The grid that room can hold, as (rows, cols). `MAZE_ROWS` x `MAZE_COLS` on a
## floor with the space for it, cut down by `_maze_grid` on one without.
var maze_grid: Vector2i = Vector2i(MAZE_ROWS, MAZE_COLS)
## Whether the roll said to actually build one there. The room is widened either
## way -- `pick_maze_cell(true)` exists so a director can place a maze on a seed
## whose roll said no, and it can only do that if the masonry it needs is already
## standing. A floor that rolled no therefore has one wide hall in it with
## ordinary bodies in it, which is a floor with some variety in its rooms and not
## a defect.
var _maze_rolled: bool = false

var _rng: RandomNumberGenerator
var _seed_salt: int = 0
## Grid cells spoken for by something built OUTSIDE the room tree -- a landing, a
## vault. Nothing may bud into one and no later anchor may point through one.
var _reserved: Dictionary = {}
## Rewards standing hidden in a room, waiting for that room's monsters to be
## beaten. `Vector2i -> Array[Dictionary{node, tier}]`, drained by
## `_arm_room_rewards`.
##
## A registry and not a direct wiring, because the two halves happen in the wrong
## order: `_place_deep_chest` puts a chest down while the anchors are being laid,
## and the bodies that guard it are not spawned until `_populate` walks the same
## cell hundreds of lines later. See `_hold_reward`.
var _held_rewards: Dictionary = {}


func _ready() -> void:
	# Running the scene straight from the editor or the capture harness has no
	# Run behind it. Start one rather than generating an unseeded floor.
	if not Run.in_dungeon:
		# Unless this floor is the scene the GAME BOOTED INTO, in which case
		# inventing a run is the bug: nobody chose it, the gate was never pressed,
		# and the line below is what turns "somebody launched the wrong scene"
		# into "the player is on floor 1 of a run they never started". Flow sends
		# them to the garrison; we build nothing at all. See `Flow.refuse_boot`.
		if Flow.refuse_boot(self):
			return
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
	# The chord between the tree and the anchors, and it has to be exactly there.
	# AFTER `_plan`, because it needs every room's `dist`; BEFORE `_plan_anchors`,
	# because the edge it adds punches two more doorways and `_pick_side` chooses
	# blank walls -- an anchor picked first would be a locked door with a corridor
	# driven through it. `deepest` and `path_to` are untouched by it: both read
	# `parent`, and the chord adds no parent.
	_plan_chord()
	# Anchors before the map, so that a future `_publish` that wants to mark the
	# vault or the boss door has them to mark. `_publish`'s own contract is only
	# that it runs after `_plan` and before `_build`, and it still does.
	_plan_anchors()
	# AFTER the anchors, because the maze may not take a room something else has
	# claimed and `placements` is where that is written down; BEFORE `_build`,
	# because it widens the room it picks and `_build_room` reads that width.
	_plan_maze()
	_publish()
	_build()
	_build_chord()
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

	# **One cell beside the entrance is held empty, and it is a fix rather than a
	# nicety.** The shortcut is anchored at the entrance by every row of
	# `FloorDb.ANCHORS` -- *"a shortcut you have to cross the floor to reach is not a
	# shortcut"* -- and its landing is `LAND_STUB + LAND_SIZE` = 13 m of stone driven
	# out through a blank wall. `_pick_side` asks `_clear_run` whether that room is
	# there and then takes the best wall it can find WHETHER OR NOT the clearance
	# exists, so a tree that spent all four of the entrance's walls left the shortcut
	# nowhere to go and the landing was laid inside the neighbour.
	#
	# Measured, on floor 2 of seed-as-shipped: room (0,0) had doors s, n and w, the
	# only free wall was e, and room (1,0) is a 27 m chamber whose west face is 4.5 m
	# past that wall. The landing was therefore built 8.5 m INSIDE it -- it
	# generated, it lit its sconce, and `cistern_floor --level=2` could open the door
	# and then not walk to the stair behind it (D10/D11). Nothing looked wrong in a
	# frame; the hero was simply jammed in a corner of somebody else's masonry.
	#
	# Held here rather than patched in `_pick_side`, because by the time that runs
	# the rooms exist and there is nothing left to choose. One cell is enough:
	# `_reach_for` answers 1 for a 16 m room and a 13 m landing at `spacing` 26.
	var keep_dirs: Array = DIRS.keys()
	var keep: StringName = keep_dirs[_rng.randi_range(0, keep_dirs.size() - 1)]
	var kept: Vector2i = entrance + DIRS[keep]

	var guard := 0
	while placed.size() < room_count and guard < 400:
		guard += 1
		# 70% of the time extend the frontier; otherwise branch off anywhere.
		var from: Vector2i = placed.back() if _rng.randf() < 0.7 \
			else placed[_rng.randi_range(0, placed.size() - 1)]

		var options: Array[StringName] = []
		for d: StringName in DIRS:
			if rooms.has(from + DIRS[d]) or from + DIRS[d] == kept:
				continue
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


## The chord edge -- **`docs/PUZZLES.md` §4, and the reason cycles belong in this
## game rather than in a general Zelda-like.**
##
## > *`dungeon.gd` builds a tree: every room has one `parent`, so every route is
## > out-and-back and nothing can ever surprise you spatially. The fix is one
## > extra edge. Pick two rooms whose `dist` differs by >= 3, connect them, and
## > block the connection from the near side only.*
##
## Three filters, and each one is a sentence of §4 or §5.2:
##
## - **Grid-adjacent, no tree edge.** A chord between rooms that are not
##   neighbours would need a corridor through a third room's masonry.
## - **`dist` differing by at least `CHORD_SPAN`.** A loop that saves two rooms
##   of walking is a door, not a shortcut.
## - **The far end at or past the gate room.** §5.2 says the cycle is the gate
##   room's REWARD, so the side you open it from has to be somewhere you only
##   reach by solving it. A chord whose far end sat before the gate would be a
##   loop the player walks for free on the way down.
##
## Ranked on the SHALLOW end, smallest first: *"the loop you open by solving the
## gate room comes out near the entrance, so beating the puzzle physically
## shortens the extraction walk."* That sentence is this sort key.
func _plan_chord() -> void:
	chord = {}
	# No gate room on this floor means no reward to attach the cycle to. An
	# unbarred second route through a floor is a generator being generous, which
	# is not what §4 asked for.
	if not FloorDb.anchors(Run.level).has(&"gate_room") \
			or not _anchor_keyed(&"gate_room"):
		return
	var gate = _room_for(&"gate_path")
	if gate == null or not rooms.has(gate):
		return
	var gate_dist := int(rooms[gate]["dist"])

	var best_near := Vector2i.ZERO
	var best_far := Vector2i.ZERO
	var best_dir: StringName = &""
	# (shallow end's dist, -span, near room's plan index). The third term is what
	# makes a tie deterministic rather than dependent on Dictionary order.
	var best_key := Vector3(1e9, 1e9, 1e9)

	for cell: Vector2i in rooms:
		for d: StringName in DIRS:
			var other: Vector2i = cell + DIRS[d]
			if not rooms.has(other) or rooms[cell]["doors"].has(d):
				continue
			var a := int(rooms[cell]["dist"])
			var b := int(rooms[other]["dist"])
			if absi(a - b) < CHORD_SPAN:
				continue
			# Every unordered pair is met twice, once from each end. Normalising
			# to (shallow, deep) here rather than skipping one direction is what
			# lets the loop not care which end it arrived from.
			var near := cell if a < b else other
			var far := other if a < b else cell
			if int(rooms[far]["dist"]) < gate_dist:
				continue
			var key := Vector3(float(mini(a, b)), -absf(float(a - b)),
				float(rooms[near]["index"]))
			if key.x < best_key.x \
					or (is_equal_approx(key.x, best_key.x) and key.y < best_key.y) \
					or (is_equal_approx(key.x, best_key.x)
						and is_equal_approx(key.y, best_key.y)
						and key.z < best_key.z):
				best_key = key
				best_near = near
				best_far = far
				best_dir = d if near == cell else _opposite(d)

	if best_dir == &"":
		# A short or straight floor can simply have no pair that qualifies. Not a
		# warning: `room_count` is the manifest's, and a five-room line has no two
		# neighbours three apart. The floor is then a tree, exactly as it was
		# before this function existed.
		return
	# Doors on BOTH sides, so `_build` punches two holes and lays one corridor --
	# the corridor rule is "whichever end is north or west builds it", and it does
	# not care that this edge is not in the tree.
	rooms[best_near]["doors"].append(best_dir)
	rooms[best_far]["doors"].append(_opposite(best_dir))
	chord = {"near": best_near, "far": best_far, "dir": best_dir, "node": null}


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


## Two rooms are built wider than the rest — the deepest when a boss lives in it,
## and the maze's (`MAZE_ROOM`) — so a caller that needs a room's real footprint
## has to ask rather than read `room_size`. NOTE: `_publish` above still hands
## `Atlas` the DEFAULT size, so the minimap draws both of them at ordinary width.
## Cosmetic, and left alone here rather than fixed inside a merge.
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

## Turn the manifest's RULES into cells and wall sides.
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
		var cell = _room_for(StringName(rule.get("room", &"")), id)
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
		# **The alarm `_pick_side` does not raise itself.** It returns the best wall
		# it can find, which is not the same as a wall with the clearance asked for,
		# and the silence between those two is what built floor 2's shortcut landing
		# inside room (1, 0) -- see `_plan`, which now keeps a cell beside the
		# entrance so the shortcut always has one. This says so for every OTHER
		# anchor: a vault or a treasure chamber driven through a neighbour's masonry
		# looks exactly like one that fits until something walks to it.
		if _clear_run(cell, side, reach) < reach:
			# **And an OPTIONAL anchor is dropped rather than built through.** §5.3
			# says nothing behind the treasure gate is on the critical path, so a
			# floor without one is a poorer floor and a floor with one laid across
			# the shortcut's landing is a broken one. The two doors and the boss are
			# the floor, so those still go in under the warning -- there is nowhere
			# else for them to be, and a warning is the most this can honestly do.
			#
			# `_room_for` now scores a room that cannot hold the structure below one
			# that can, so reaching here at all means every candidate room was full.
			push_warning(("dungeon: anchor %s takes the %s wall of %s with %d clear "
				+ "cell(s) of %d needed -- its structure would be built through "
				+ "occupied grid and what is behind it unreachable%s. (Straight out "
				+ "only: a structure WIDER than its room also overhangs the two "
				+ "cells beside the run, which nothing checks.)")
				% [id, side, cell, _clear_run(cell, side, reach), reach,
					" -- dropped" if OPTIONAL_ANCHORS.has(id) else ""])
			if OPTIONAL_ANCHORS.has(id):
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
		# A treasure puzzle with nothing behind it is a door onto a chest, and
		# `docs/PUZZLES.md` §5.3 is emphatic that what is back there is the
		# floor's MINIBOSS. A floor without one does not get the anchor; that is
		# the same shape `vault_key` uses to say floor 4 has no vault.
		&"puzzle_room": return BossDb.miniboss_for(Run.level) != &""
		# The gate room needs a verb it is allowed to ask for. §5.2 caps it at
		# tier N-1, and floor 1's N-1 is T0 -- which `PuzzleAtoms.pool` always
		# answers with something, so this only ever refuses on a manifest whose
		# atom kit has been emptied. It is checked anyway: a gate room that
		# generated with no atoms would be a locked door with no key in the
		# world, on the critical path.
		&"gate_room": return not PuzzleAtoms.pool(_gate_tier()).is_empty()
	return true


## The verb ceiling for this floor's gate room: **tier N-1** (`docs/PUZZLES.md`
## §5.2), never anything the player does not own. `PuzzleAtoms.pool` takes the
## minimum of this and `Game.has()`, so §0 rule 1 stays one comparison in one
## place; this half is only the SHAPE's ceiling.
func _gate_tier() -> int:
	return maxi(Run.level - 1, PuzzleAtoms.T0)


## And the treasure puzzle's: **tier N** (§5.3). It is allowed to be richer than
## the critical path because it is optional -- a player without the verb simply
## meets a T0 puzzle instead, because `pool` clamps to what they own.
func _treasure_tier() -> int:
	return maxi(Run.level, PuzzleAtoms.T0)


## `&"entrance"`, `&"deepest"`, `&"mid_ring"`, `&"gate_path"` -- the four rooms
## the manifest is allowed to name. Returns `null` when the floor is too short to
## have one, which the caller reads as "skip this anchor".
func _room_for(kind: StringName, id: StringName = &""):
	match kind:
		&"entrance":
			return entrance
		&"deepest":
			return deepest
		&"gate_path":
			# `docs/PUZZLES.md` §5.2: on the PATH to `deepest`, around 0.7 of the
			# way. Taken off `path_to` and not off `dist`, and the difference is
			# the whole anchor -- a room merely 0.7 of the deepest DISTANCE can
			# be on a spur the player never walks, and a critical-path puzzle you
			# can stroll past is not a critical-path puzzle.
			var route := path_to(deepest)
			# Neither end of the route: the entrance carries the shortcut and the
			# deepest room is the arena. A floor whose path is two rooms long has
			# no middle and therefore no gate room -- the same "not placed" the
			# mid-ring answers on a short floor, and for the same reason.
			if route.size() < 3:
				return null
			var at := int(round(0.7 * float(route.size() - 1)))
			return route[clampi(at, 1, route.size() - 2)]
		&"mid_ring":
			# The cell whose distance is nearest half the deepest's, and which is
			# neither of the other two. Ties break on the plan index so the same
			# seed picks the same room every time.
			#
			# A room that already has an anchor in it is pushed to the back of the
			# queue rather than excluded. Floor 1 asks for TWO mid-ring anchors --
			# the vault (GDD §5.3) and the treasure puzzle (`docs/PUZZLES.md`
			# §5.3) -- and stacking both on the same room spent its last blank
			# wall on the first one and dropped the second with a warning. The
			# floor has more than one room at mid depth; this is the line that
			# uses them. It is a penalty and not a filter because a THIRD mid-ring
			# anchor on a short floor should still land somewhere.
			var want := float(rooms[deepest]["dist"]) * 0.5
			var used := {}
			for pid: StringName in placements:
				used[placements[pid]["cell"]] = true
			var best = null
			var best_key: Array[float] = [1e9, 1e9, 1e9, 1e9, 1e9]
			for cell: Vector2i in rooms:
				if cell == entrance or cell == deepest:
					continue
				# **A room with no wall the structure fits behind is not a placement,
				# so it outranks even "already has an anchor in it".** Sharing a room
				# is crowded; a room whose only blank wall backs onto occupied grid
				# is a chamber built THROUGH something.
				#
				# Floor 2 is what added this term. `puzzle_room` landed on (1, -1),
				# whose doors are [w, e, n] -- one blank wall, `s`, and the cell
				# behind it was already reserved by the shortcut landing. The alarm
				# in `_plan_anchors` said so ("0 clear cell(s) of 1 needed") and then
				# it was built anyway: a 26 m `TreasureChamber` whose west wall stood
				# at x = 13 straight across a landing spanning x = 8..21, so the
				# stair behind the shortcut could not be walked to. Two rooms at the
				# same depth were free the whole time.
				var key: Array[float] = [
					0.0 if _wall_room_for(cell, id) else 1.0,
					1.0 if used.has(cell) else 0.0,
					absf(float(rooms[cell]["dist"]) - want),
					# **Leave the maze the only kind of room it can use.**
					# `pick_maze_cell` needs a room with exactly one doorway, and a
					# tree this size has one or two. An anchor is indifferent between
					# two rooms at the same depth; the maze is not, so this breaks
					# that tie away from it -- ABOVE the plan index, because the
					# index is what decided such ties before and it decides for no
					# reason at all.
					#
					# Measured: with the one-door rule and without this term, the
					# treasure anchor took the single one-door room on floors 1 AND 2
					# and both printed "no room a maze fits in" -- §5.4's room gone
					# from half the game to settle a tie that had no stake in it.
					1.0 if (rooms[cell]["doors"] as Array).size() == 1 else 0.0,
					float(rooms[cell]["index"]),
				]
				if _key_before(key, best_key):
					best_key = key
					best = cell
			return best
	return null


## **Which way out of the room's middle the scatter chest goes, and it is not a
## constant.**
##
## It was `Vector3(0, 0, -size * 0.32)` — 32% of the way toward the room's north
## wall, whatever was standing on that wall. On floor 1 the vault door takes the
## north wall of room (0, -1), so the chest stood **2.9 m in front of it**, inside
## the door's own trigger and nearer to the player than the door: walk up to the one
## door in the game whose whole job is to name the thing worth going deeper for
## (GDD pillar 3) and the HUD says `E TO OPEN` on a chest. `cistern_floor --level=1`
## read that prompt as the vault's and filed a note blaming `LockedDoor.SIGILS`.
##
## So: a wall with **nothing** on it first, a wall with only a DOORWAY second, and
## the old constant last. A doorway is an opening and not an interactable, so a
## chest 2.9 m off one competes with nothing; an anchored wall carries a door, a
## chest or a gate, and every one of those has a trigger.
##
## Ties go to the floor's own generator, so a replayed seed puts it back.
func _chest_dir(cell: Vector2i) -> Vector3:
	var doors: Array = rooms[cell]["doors"]
	var anchors: Dictionary = rooms[cell]["anchors"]
	var empty: Array[StringName] = []
	var doorways: Array[StringName] = []
	for d: StringName in DIRS:
		if anchors.has(d):
			continue
		if doors.has(d):
			doorways.append(d)
		else:
			empty.append(d)
	var pool := empty if not empty.is_empty() else doorways
	if pool.is_empty():
		return Vector3.FORWARD
	var pick: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
	var step: Vector2i = DIRS[pick]
	return Vector3(float(step.x), 0.0, float(step.y))


## Is there a blank, unclaimed wall of `cell` with the clear ground `id`'s structure
## needs behind it? The question `_pick_side` answers with a wall; this only wants
## the yes or no, and it is asked while CHOOSING the room rather than after.
##
## `id` empty means "any anchor", which is the `reach = 1` case — a landing.
func _wall_room_for(cell: Vector2i, id: StringName) -> bool:
	var reach := _reach_for(id, cell)
	var doors: Array = rooms[cell]["doors"]
	var taken: Dictionary = rooms[cell]["anchors"]
	for d: StringName in DIRS:
		if doors.has(d) or taken.has(d):
			continue
		if _clear_run(cell, d, reach) >= reach:
			return true
	return false


## Lexicographic on however many components the key has, which is what the
## `is_equal_approx` ladder this replaced was spelling out by hand for three — and
## an array rather than a `Vector4` because the ladder grew past four the first time
## anyone added a term to it. Floats, so the comparisons are approximate on the way
## down and strict at the component that decides.
func _key_before(a: Array[float], b: Array[float]) -> bool:
	for i in mini(a.size(), b.size()):
		if not is_equal_approx(a[i], b[i]):
			return a[i] < b[i]
	return false


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
	elif id == &"puzzle_room":
		depth = CHAMBER_STUB + _chamber_size()
	var far_edge := size_of(cell) * 0.5 + depth
	return maxi(1, int(floor((far_edge + room_size * 0.5) / spacing)))


## How wide the treasure chamber is, off the miniboss the floor actually has.
## The same shape as `_room_size_for` and for the same reason: the number that
## decides how much stone to lay is the number the fight was authored with, asked
## once, so a bigger miniboss cannot come with a chamber that does not fit it.
func _chamber_size() -> float:
	var id := BossDb.miniboss_for(Run.level)
	if id == &"":
		return CHAMBER_MIN
	var row := BossDb.get_boss(id)
	var arena: Dictionary = row.get("arena", {})
	return maxf(CHAMBER_MIN,
		float(arena.get("radius", 7.5)) * 2.0 + CHAMBER_SKIRT)


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
	#
	# Card #38 widened the pool and left the peak alone: `light_energy` stays at
	# 6.5, two thirds of a room sconce, so the landmark is still dimmer than the
	# rooms at either end of it, while `light_range` goes to the room's 15 m
	# because 11 m in a tube whose walls are 1.5 m either side spends most of its
	# reach on masonry and dies well before the far door.
	#
	# It is a small win and it is written down as one. Measured on the demo path's
	# corridor with the flames held still: **40.0% of the frame under luminance 8
	# at range 11, 38.0% at range 15**, mean 19.6 -> 20.4, and the share above 64
	# 3.3% -> 3.7%. The corridor is the darkest frame on the path either way, and
	# that is the design rather than the defect — `room_range.gd` scores it, and
	# what it now has that it did not have before this card is a *real bright*,
	# because the rooms at both ends stopped being black. Raising the ENERGY would
	# have bought more and is the wrong lever: a hotter flame lifts the whole tube
	# toward `docs/STYLEGUIDE.md` §1 rule 1's one beige sheet.
	var side := 0 if (cell.x + cell.y) % 2 == 0 else 1
	var torch := ROOM_SCENE_TORCH.instantiate()
	torch.rng_seed = _salt(cell, d, 20)
	torch.light_range = 15.0
	torch.light_energy = 6.5
	torch.position = offs[side] + Vector3(0.0, KitStyle.SCONCE_Y, 0.0)
	torch.rotation.y = yaws[side]
	root.add_child(torch)


## The fewest sconces a room may be built with. Two walled sides' worth — which
## is what a room with one or two exits already got, and those rooms measured
## right (`tools/directors/room_range.gd`).
const ROOM_SCONCE_FLOOR := 4


## A walled side gets two sconces; a holed side gets none, **unless the room would
## otherwise be dark, in which case a hole gets its flanks lit instead**.
##
## ## What the floor is for, and the frame that put it here (card #38)
##
## The first clause is the old rule and it is a good one: an exit should read as
## the dark hole it is, and a locked door brings its own cold lamp that a torch
## beside it would fight. What it lacked was a floor. The number of unlit sides is
## the number of exits and nothing capped it, so floor 1's **entrance room** —
## three doorways, and the shortcut-door anchor on the fourth wall — was built
## with **zero sconces of its own**, lit only by the gate's cold lamp and whatever
## spilled in through the corridors. Measured off the demo path: 76.3% of that
## frame under luminance 8, mean 8.6/255, 1.5% above 64, and the hero a black
## cut-out against a black wall — `docs/STYLEGUIDE.md` §17's old failure in the
## same words. Its neighbour (0,1) was built the same way for the same reason.
##
## ## Why the fix is a floor and not more fire everywhere
##
## The first cut of this lit every holed side. It moved the shortcut room to mean
## 48.9 and it also moved the rooms that were *already right* — the plain
## generated room went 35.4 → 60.2 with four torches across its back wall, which
## is §1 rule 1's "one beige sheet" in orange. So the flanking only happens where
## the count comes up short: a room with two or more solid sides is built exactly
## as it was, and its histogram does not move at all.
##
## ## Why flanking a hole is more range than lighting a wall, not less
##
## `_build_side` already splits a holed side into two flank walls with a gap
## between them. A sconce on the middle of each flank puts a pool at either end
## and leaves the doorway the darkest thing in shot, so the exit stops being a
## dark hole in a black wall — no information — and becomes a dark hole between
## two fires, which is a silhouette. Nothing global moves: no ambient, no
## exposure, no albedo. The dark end and the lit end are both still in frame.
##
## The cold lamp keeps its job. A flank sconce sits half a door plus half a flank
## from the middle of the wall — five metres on a sixteen-metre side — so it is
## nowhere near "beside" the lamp, and §1 rule 2 wants that warmth there anyway:
## a cold light reads as cold only against something warmer.
func _build_room_torches(root: Node3D, cell: Vector2i, doors: Array,
		anchors: Dictionary, half: float) -> void:
	var sides := _sides_of(cell)
	var solid: Array[StringName] = []
	var holed: Array[StringName] = []
	for d: StringName in sides:
		if doors.has(d) or anchors.has(d):
			holed.append(d)
		else:
			solid.append(d)

	# A flank too narrow to be a wall gets nothing, using `_build_side`'s own
	# threshold rather than a second opinion about it — a sconce bolted to a
	# quarter-metre of masonry hangs in the doorway.
	var flank := (half * 2.0 - door_span) * 0.5
	var order := solid.duplicate()
	if flank > 0.4:
		for d: StringName in _lit_holes(holed, anchors):
			if order.size() * 2 >= ROOM_SCONCE_FLOOR:
				break
			order.append(d)

	var n := 0
	for d: StringName in order:
		var s: Dictionary = sides[d]
		var yaw: float = s["yaw"]
		var along := along_of(yaw)
		# A solid side spreads its pair wide across the whole run; a holed side
		# puts one on the middle of each flank, which is closer in.
		var off := (door_span + flank) * 0.5 if holed.has(d) else half * 0.52
		for s2 in [-1.0, 1.0]:
			var t := ROOM_SCENE_TORCH.instantiate()
			t.rng_seed = _salt(cell, d, 30 + n)
			# Two shadow-casters a room, and never one of the flank sconces this
			# card added. A shadowed omni is six cube faces of geometry a frame
			# (`KitTorch`'s header), and a flank torch stands a metre from a
			# doorway pointing across it, so most of what it would resolve is the
			# jamb. Measured at the entrance-room pose on the shared seed: **955
			# draw calls with the flanks casting, 564 without** — against 556 for
			# the room as it was built before this card, so the fire is close to
			# free and the shadows were not. The frame got brighter for losing
			# them (mean 33.2 -> 35.8) and no shadow anyone could name went with
			# them.
			t.cast_shadow = n < 2 and not holed.has(d)
			t.position = s["at"] + along * (s2 * off) \
				+ Vector3(0.0, KitStyle.SCONCE_Y, 0.0)
			t.rotation.y = yaw
			root.add_child(t)
			n += 1


## Which holes to light first when a room comes up short, and it is an ordering
## rather than a set because the floor usually stops after one or two.
##
## **An anchored side first.** It is the wall the room is *about* — a shortcut
## door, a vault, a boss door — so it is the wall the player walks up to and
## reads, and it is the one that has to hold a silhouette. Then **the side facing
## it**, so the fire is at two ends of the room and the middle is the dark, rather
## than two adjacent walls lighting one corner and leaving the diagonal black.
## Whatever is left keeps `_sides_of`'s order, which is stable, so the same seed
## builds the same room.
func _lit_holes(holed: Array[StringName],
		anchors: Dictionary) -> Array[StringName]:
	const OPPOSITE := {&"n": &"s", &"s": &"n", &"w": &"e", &"e": &"w"}
	var first: Array[StringName] = []
	var rest: Array[StringName] = []
	for d: StringName in holed:
		if anchors.has(d):
			first.append(d)
		else:
			rest.append(d)
	# `first + rest` on two `Array[StringName]`s comes back as a plain `Array`,
	# which then will not assign to a typed return. Two appends keep the element
	# type.
	var order: Array[StringName] = []
	order.append_array(first)
	order.append_array(rest)
	if not order.is_empty():
		var facing: StringName = OPPOSITE[order[0]]
		if order.has(facing):
			order.erase(facing)
			order.insert(1, facing)
	return order


## A stable per-piece seed. Two walls sharing a seed are visibly identical, and
## a floor whose seeds came from a running counter reshuffles every stone the
## moment you add a room.
func _salt(cell: Vector2i, d: StringName, slot: int) -> int:
	return absi(_seed_salt + cell.x * 7919 + cell.y * 104729
		+ int(d.hash() % 997) * 31 + slot * 13) % 100000 + 1


# --- The six anchors -----------------------------------------------------------

func _build_anchors() -> void:
	for id: StringName in ANCHOR_ORDER:
		if not placements.has(id):
			continue
		match id:
			&"boss_door": _place_boss(id)
			&"deep_chest": _place_deep_chest(id)
			&"shortcut_door": _place_shortcut(id)
			&"vault_door": _place_vault(id)
			&"gate_room": _place_gate_room(id)
			&"puzzle_room": _place_puzzle_room(id)


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

	_build_landing(spot, cell, p["side"], "BossLanding")


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
	# Tier 2, whichever way it is gated below: it rolls the rich table, and on an
	# authored floor it carries that floor's `deep_chest` relic. If anything in the
	# dungeon earns the big flash it is this.
	#
	# **Two gates, because this anchor lands in two different kinds of room.**
	#
	# On an authored floor `deep_chest` and `boss_door` routinely pick the SAME
	# cell -- the deepest one -- and `_place_boss` puts the arena in it, so
	# `_populate` skips the room entirely (no pack, on purpose: the boss is the
	# room). There is therefore no `RoomWatch` there and never will be, and a chest
	# left to `_hold_reward` would fall through to `_release_unclaimed_rewards` and
	# be standing open the moment the player walks in -- the richest chest on the
	# floor, free, two metres from the boss door. That is exactly what the probe on
	# seed 20260811 found. The boss IS the thing in that room, so the boss is what
	# it waits for.
	#
	# On a floor where the anchor lands somewhere else it is an ordinary room with
	# an ordinary pack, and it waits for the pack like every other chest. Note that
	# `_populate` has not run yet -- the anchors go down first -- so this cannot
	# wire itself to those monsters and does not try. See `_hold_reward`.
	var arena := root.get_node_or_null(^"Arena")
	var boss := (arena.call(&"boss") as Node3D) if arena != null else null
	if boss != null:
		chest.visible = false
		chest.enabled = false
		boss.connect(&"died_at", func(_where: Vector3) -> void:
			RewardVfx.land(chest, RewardVfx.MAJOR))
	elif arena != null:
		# The arena is there but built no body -- the boss is already dead this run
		# and the floor was re-entered. The chest was earned; hand it over with no
		# ceremony, the same way the treasure chamber's does.
		RewardVfx.show_now(chest)
	else:
		_hold_reward(cell, chest, RewardVfx.MAJOR)

	var relic := FloorDb.relic_in(Run.level, &"deep_chest")
	if relic == &"":
		return
	chest.activated.connect(func(_by: Node3D) -> void:
		RelicPickup.place(get_tree().current_scene, relic,
			chest.global_position + Vector3.UP * 0.7,
			-far * 1.3))


# --- The two forks ------------------------------------------------------------

## GDD §5.3, sentence one: *the shortcut on floor N is opened by floor N's own
## boss item, and skips floor N.* The second half is still one line -- what is
## behind the door is the same `Stairs` every other way down in the game uses, so
## "skips this floor" is `Run.level + 1` and not a second descent path.
##
## **The first half stopped being a line and became a puzzle** (`docs/PUZZLES.md`
## §5.1). It was a `LockedDoor` keyed on `FloorDb.shortcut_key`, which is the
## exact shape that document opens by refusing: *a door that opens because you own
## item X is a check, not a puzzle.* Now the door is a `ShortcutGate` and the item
## has to be **used** in front of it -- one atom of exactly tier N, one gesture,
## and the door swings on it.
##
## Three things this shape does not share with §5.2's gate room, each of them a
## sentence in §5.1:
##
## - **Exactly tier N, never "N or above"** (§1). `_shortcut_pool` is that word
##   `exactly`; `PuzzleAtoms.pool()` is the wrong function here and would let a
##   seed put the hookshot on floor 1's shortcut, delaying GDD §5.3's ninety
##   seconds by two floors.
## - **Not seed-driven.** §5.2's prefab is rolled because a replayed gate room
##   should surprise; this one must NOT, because the whole promise being kept is
##   that on your fifth run you are past this floor in ninety seconds, and a
##   ninety-second route you have to read first is not one. The tier picks the
##   prefab and nothing else does.
## - **A straight solve, not a cycle.** You already own the item. The puzzle is
##   the receipt, not the challenge -- one atom, in front of the door, done.
##
## Floor 4 keeps the `LockedDoor`, and that is §1 rather than an omission: its
## shortcut takes the **Far Lantern**, which *"has no verb and never gets one --
## it is the last door in the game and a pure lock, which is the correct shape for
## a thing that ends Act I."* `_shortcut_pool` comes back empty for it and this
## function falls through to what was always there.
func _place_shortcut(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var key := FloorDb.shortcut_key(Run.level)
	if key == &"":
		return
	var spot := _wall_spot(p)
	var tag := StringName("shortcut_%d" % Run.level)
	var pool := _shortcut_pool()

	var door: Node3D = null
	if pool.is_empty():
		# The Far Lantern's floor. See the class note above.
		door = _place_locked(p, "ShortcutDoor", key, "", tag)
		if door == null:
			return
	else:
		door = _build_shortcut_gate(p, spot, tag)
		if door == null or not _shortcut_prefab(rooms[cell]["node"], spot, tag,
				pool[0]):
			return

	var landing := _build_landing(spot, cell, p["side"], "ShortcutLanding")
	_land_shortcut_rewards(landing, door)


## The `ShortcutGate` itself, in the entrance room's blank wall.
##
## Loaded by PATH and never named, the same way `VAULT_SCRIPT` and `BARS_SCRIPT`
## are: `ShortcutGate` is a `class_name` added in the same change as this call, so
## it is not in the global script class cache until somebody runs `--import` and
## naming it is a parse error that takes the whole floor down (`CLAUDE.md` §3).
##
## `mark_tier` is set BEFORE the node enters the tree, because `PuzzleGate._ready`
## reads it to choose `key_item` and `LockedDoor._ready` carves the medallion off
## that -- a tier assigned afterwards is a mark on a glyph already cut.
func _build_shortcut_gate(p: Dictionary, spot: Dictionary,
		tag: StringName) -> Node3D:
	var script := load(SHORTCUT_GATE_SCRIPT) as GDScript
	if script == null:
		push_error("dungeon: %s failed to load" % SHORTCUT_GATE_SCRIPT)
		return null
	var root: Node3D = rooms[p["cell"]]["node"]
	var gate: Node3D = script.new()
	gate.name = "ShortcutDoor"
	gate.set(&"puzzle_id", tag)
	gate.set(&"mark_tier", _shortcut_tier())
	# `destination` is the flag's identity (`ShortcutGate.flag_id`), and it is the
	# SAME string the `LockedDoor` wrote before this card. A shortcut opened on a
	# save made last week is still open.
	gate.set(&"destination", tag)
	gate.position = spot["pos"]
	gate.rotation.y = float(spot["yaw"])
	root.add_child(gate)
	p["node"] = gate
	return gate


## **Exactly** tier N (`docs/PUZZLES.md` §1), and the emphasis is the design.
##
## Not `PuzzleAtoms.pool()`, which answers *at or below* and clamps to what the
## player owns -- both of those are §5.2's rules and both are wrong here. This
## shape's verb is the floor's own boss item and the player is expected to arrive
## without it: the refusal ("THE EYE IS SHUT") is the door telling them what the
## Warden is holding.
##
## Comes back **empty** for any floor whose tier is off §1's ladder, which is
## floor 4 and the Long Descent -- see `_place_shortcut`.
func _shortcut_pool() -> Array[StringName]:
	var want := _shortcut_tier()
	var out: Array[StringName] = []
	if want <= PuzzleAtoms.T0 or want >= PuzzleAtoms.TIER_ITEM.size():
		return out
	for atom: StringName in PuzzleAtoms.all():
		if PuzzleAtoms.tier(atom) == want and PuzzleAtoms.gates(atom):
			out.append(atom)
	return out


## Floor N's shortcut is opened by floor N's verb, so the tier IS the level.
## One line, for the same reason `FloorDb.shortcut_key` is one line.
func _shortcut_tier() -> int:
	return Run.level


## The shortcut's prefabs (`docs/PUZZLES.md` §5.1), in tier order: `eye_high` is
## T1, `pillar_brace` is T2, `ring_span` is T3. **Picked by tier, not by seed** --
## see `_place_shortcut`, and note there is no `--shortcut-prefab=` twin of
## `--gate-prefab=`. That flag exists because the gate room's pick IS a roll and a
## director could otherwise only photograph its own seed's draw; here the floor
## number is the pick, so `tools/directors/shortcut_puzzle.gd` rebuilds at levels
## 1, 2, 3 and 4 and gets all four answers with no debug hook at all.
##
## There are three and not four. §1 gives floor 4's shortcut the **Far Lantern**,
## which has no verb, so there is no T0 row to write -- and a T0 row written
## anyway would be a prefab the generator can never pick and no director can ever
## photograph. Three is under `docs/SCOPE.md` §1's ceiling, which is what a
## ceiling is for.
##
## An `Array` of names rather than a `Dictionary` keyed on atom ids, for the
## reason `CLAUDE.md` §3 gives: a `const` Dictionary holding another class's
## constants is not a constant expression, and the error it throws names the
## assignment rather than the lookup.
const SHORTCUT_PREFABS: Array[StringName] = [
	&"eye_high", &"pillar_brace", &"ring_span",
]

## How high the shortcut's eye sits. Above the sword's reach and below the
## sconces, so the only thing in the kit that answers it is an arrow -- and the
## same 2.05 m `tools/directors/convert_arrow.gd` stands its two eyes at, because
## a shot the player has already learned to take should be the same shot.
const EYE_Y := 2.05

## How many eyes `_gate_eye_row` builds, and how many arrows the urn beside them
## holds. **Two per eye** (card #43).
##
## The ratio is `ShortcutCache`'s, deliberately: that one holds two charges for a
## one-charge pillar because *"one charge and one missed arc puts the player back
## at the pillar with nothing"* (`docs/PUZZLES.md` §5.1). Every required shot may
## be missed once, and a row that needs three of them gets six.
##
## Written as `EYES * 2` and not as `6`, and NOT left to `ArrowBundle.FLOOR_COUNT`
## which happens to be the same number today. Both of those would decouple the
## supply from the demand: `FLOOR_COUNT` is tagged `[tune]` and a pass that took
## it to four would silently thin the critical path to one spare arrow across
## three shots, with nothing in either file saying the two were related.
##
## Six is also the TIGHTEST urn in the game per shot it has to pay for --
## `_shortcut_eye_high`'s pot hands the same six over for a single eye. It is a
## floor under a guarantee, not a handout, which is why it stays well inside
## `Game.max_arrows` (30) and does not make `Fletching.RECIPE` or the smith's
## line pointless (`ArrowBundle.FLOOR_COUNT`'s own note). [tune]
const EYE_ROW_EYES := 3
const EYE_ROW_ARROWS := EYE_ROW_EYES * 2

## How far a WALL-MOUNTED atom has to stand off the masonry to be reachable.
##
## **A flush atom renders perfectly and cannot be hit**, which is the worst shape
## a bug can have here. `KitWall` collides with ONE box covering the slab and its
## relief -- `scripts/kit/kit_wall.gd`: `depth = thickness + max(relief,
## plinth_relief)` -- so the stone stands `plinth_relief` (0.26 m) proud of the
## *visible* face over the whole height, not just along the plinth course it is
## named for. `_wall_spot` hands back a point a further 0.05 m back into the
## reveal, so the stone's front face is 0.31 m along `facing` from `spot["pos"]`.
##
## `EyeSwitch`'s own box reaches 0.20 m forward of its origin, so at the 0.12 m
## this used to sit at, the plate ended a centimetre INSIDE the wall's collider
## and the ray from the hero stopped on masonry. `shortcut_puzzle.gd` printed
## exactly that -- a 3.40 m line of sight ending on `Room_0_0`'s wall body -- and
## the beat read as "the arrow missed" when nothing had missed.
##
## At 0.55 the origin clears the stone by 0.24 m and the plate by 0.44 m. The
## hook ring gets the same treatment for the same reason: its bracket has to
## clear that stone before a chain can reach it, and a ring that only answers a
## director calling `on_bitten()` directly is a ring nobody can shoot.
const WALL_STANDOFF := 0.55


func _shortcut_prefab(root: Node3D, spot: Dictionary, tag: StringName,
		atom: StringName) -> bool:
	var tier := PuzzleAtoms.tier(atom)
	print("dungeon: shortcut prefab %s (T%d)"
		% [SHORTCUT_PREFABS[clampi(tier - 1, 0, SHORTCUT_PREFABS.size() - 1)], tier])
	# `if`, not `match`: a match pattern has to be a constant expression and
	# another class's `const StringName` is not one (`CLAUDE.md` §3).
	if atom == PuzzleAtoms.CRACKED_PILLAR:
		return _shortcut_pillar_brace(root, spot, tag)
	if atom == PuzzleAtoms.HOOK_RING:
		return _shortcut_ring_span(root, spot, tag)
	return _shortcut_eye_high(root, spot, tag)


## T1, `eye_high` -- **the bow.** One eye set into the wall beside the door at
## 2.05 m, which is above the sword's reach and below the sconces, so the only
## thing in the kit that answers it is an arrow.
##
## The eye is built looking down its own -Z (`EyeSwitch._build` puts the pupil at
## `z = -0.14`), and the door's `facing` points INTO the room, so `atan2(-f.x, -f.z)`
## turns the node's forward onto `facing` and the eye looks at the player standing
## in the room (`docs/CONTRACT.md` §2.5). The gate room's eye row does the opposite
## turn because its eyes are on the FAR wall looking back.
##
## **The urn is §0 rule 2 and it is not optional**: *every puzzle room is solvable
## from a cold start with an empty pouch, because the urns beside it hold exactly
## what it needs.* A bow puzzle met with no arrows is a dead end. Its tag is its
## own -- `PuzzleAtoms.gates(URN)` is false, so a gate would never adopt it, but a
## flag keyed on a node NAME is one rename from being a different flag.
func _shortcut_eye_high(root: Node3D, spot: Dictionary, tag: StringName) -> bool:
	var facing: Vector3 = spot["facing"]
	var along := along_of(float(spot["yaw"]))
	var at: Vector3 = spot["pos"]
	var eye := PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, tag)
	if eye == null:
		return false
	eye.name = "ShortcutEye"
	eye.position = at + along * 2.3 + facing * WALL_STANDOFF \
		+ Vector3(0.0, EYE_Y, 0.0)
	eye.rotation.y = atan2(-facing.x, -facing.z)
	root.add_child(eye)

	var pot := PuzzleAtoms.make(PuzzleAtoms.URN,
		StringName("%s_pot" % tag))
	if pot != null:
		pot.name = "ShortcutUrn"
		pot.position = at + along * 2.3 + facing * 1.5
		root.add_child(pot)
	return true


## T2, `pillar_brace` -- **a burst.** A cracked pillar standing in the door's own
## mouth, holding it shut with its body.
##
## `CrackedPillar`'s class note says this is what it is for: *"Not a door -- a
## wall. §3's third combinator is the pillar that holds a slab over the way on,
## and the fall is the opening."* It is on `K.L_WORLD` and not `L_INTERACT`, so it
## blocks the way without stealing the door's prompt, and `on_solved()` frees the
## shaft -- the opening is the fall, with no second thing to press.
##
## `SHAFT_R + 0.85` out from the face: clear of the leaves, which swing INTO the
## room (`LockedDoor.OPEN_DEG`), and still inside the 2.4 m doorway, so it reads
## as bracing the door rather than standing near it.
##
## **The urn is §0 rule 2 and it is not optional**, exactly as it is not optional
## beside the eye above -- and this one was missing for a week, which is
## `docs/ITEMS.md` §8 D13 and card #29. Burst charges are bought in the garrison
## (`AlchemyDb`) and *nowhere else*: a player who descended with an empty pouch
## stood in front of a pillar with no legal way through and no way to earn one,
## which is the one thing GDD pillar 2 forbids. The urn holds a `ChargeCache` and
## the sword breaks the urn, so the answer is reachable from a cold start.
##
## It holds **charges and not arrows**, and the difference between this line and
## `_shortcut_eye_high`'s is the whole of `Urn`'s class note: *what it holds is
## decided by the placer.* A room that rolled for its contents would make rule 2
## a probability.
func _shortcut_pillar_brace(root: Node3D, spot: Dictionary,
		tag: StringName) -> bool:
	var facing: Vector3 = spot["facing"]
	var along := along_of(float(spot["yaw"]))
	var pillar := PuzzleAtoms.make(PuzzleAtoms.CRACKED_PILLAR, tag)
	if pillar == null:
		return false
	pillar.name = "ShortcutPillar"
	var out: float = pillar.get_script().get_script_constant_map() \
		.get("SHAFT_R", 0.42) + 0.85
	pillar.position = spot["pos"] + facing * out
	root.add_child(pillar)

	# Off to the side of the doorway and further into the room than the pillar,
	# for two reasons that point the same way: the blast has a 1.94 m radius
	# (`K.BOMB_RADIUS`) and an urn inside it would be smashed by the cast that
	# needed its contents, and a player has to be able to see the supply while
	# standing where he reads the refusal. `_shortcut_eye_high` puts its pot at
	# `along * 2.3`; this one goes the same distance sideways and a little
	# further out, which clears the leaves' swing as well.
	#
	# Its own tag, like the eye's pot: `PuzzleAtoms.gates(URN)` is false so no
	# gate would ever adopt it, but a flag keyed on a node NAME is one rename
	# from being a different flag.
	var pot := PuzzleAtoms.make(PuzzleAtoms.URN, StringName("%s_pot" % tag))
	if pot != null:
		pot.name = "ShortcutCache"
		pot.set(&"holds", &"charges")
		pot.position = spot["pos"] + along * 2.3 + facing * 2.6
		root.add_child(pot)
	return true


## T3, `ring_span` -- **the hookshot.** One ring bolted above the lintel, where
## nothing that is not a chain reaches it.
##
## `HookRing` builds along its own **+Z** (the bracket runs out from the wall), so
## this is `atan2(f.x, f.z)` -- the opposite turn from the eye above, and the two
## sitting three functions apart is deliberate: they are the two conventions in the
## kit and the one thing this project has paid for three times is assuming which
## way a prop faces (`CLAUDE.md` §4).
##
## `K.DOOR_H + 0.6` puts it at 3.8 m, over the door and well under `K.CEIL_ROOM`.
## `HookRing` widens its own `snap_radius` to 2.2 m for exactly this shot.
func _shortcut_ring_span(root: Node3D, spot: Dictionary,
		tag: StringName) -> bool:
	var facing: Vector3 = spot["facing"]
	var ring := PuzzleAtoms.make(PuzzleAtoms.HOOK_RING, tag)
	if ring == null:
		return false
	ring.name = "ShortcutRing"
	ring.position = spot["pos"] + facing * WALL_STANDOFF \
		+ Vector3(0.0, K.DOOR_H + 0.6, 0.0)
	ring.rotation.y = atan2(facing.x, facing.z)
	root.add_child(ring)
	return true


## §5.1's other two rewards, standing in the landing behind the door.
##
## `docs/PUZZLES.md` §5.2's amendment is a rule for all three shapes, not a prop
## for one of them: *a solved puzzle drops something you can carry out.* So the
## shortcut pays **the way down, +1 Echo and a chest** -- the same three columns
## §5.2's table gives it -- and both of the new two land on `opened`.
##
## Behind the door rather than in front of it, and flanking the stair rather than
## beside the atom: the reward for a shortcut is the walk you did not take, and a
## chest on the near side would be a chest the player loots and then leaves by the
## way they came.
##
## The already-open case is not a nicety. `ShortcutGate` keeps `LockedDoor`'s
## PERMANENT flag, so on every run after the one that solved it the door comes up
## posed open and `opened` never fires -- and §6's table pays the Echo for *taking*
## the shortcut, every run, not for having once solved it.
func _land_shortcut_rewards(landing: Node3D, door: Node3D) -> void:
	if landing == null or door == null:
		return
	var back := LAND_STUB + LAND_SIZE

	var chest := Chest.new()
	chest.name = "ShortcutChest"
	chest.picks = Prog.chest_picks(Run.level, false)
	chest.position = Vector3(-3.0, 0.0, back - 2.3)
	# Facing back toward the mouth, so the fan of motes lands in the floor between
	# the chest and the stair instead of in the back wall.
	chest.rotation.y = PI
	chest.visible = false
	chest.enabled = false
	landing.add_child(chest)

	var stone: Node3D = _make_stone(&"shortcut")
	if stone != null:
		stone.position = Vector3(3.0, 0.0, back - 2.5)
		# Turned back at the stair, which is where the player is standing when they
		# decide. The Votive Court opens its shallow effigy arc toward local -Z.
		stone.rotation.y = atan2(stone.position.x, stone.position.z - LAND_STUB)
		landing.add_child(stone)
		door.connect(&"opened", func(_where: StringName) -> void: stone.call(&"offer"))
	door.connect(&"opened", func(_where: StringName) -> void: _land_prize(chest))
	if bool(door.call(&"is_open")):
		_land_prize(chest)
		if stone != null:
			stone.call(&"offer")


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

	# Read off the prefab's own constants, the same way `_vault_depth` does and
	# for the same reason: a vault that grows a fourth room and a map that still
	# draws three is the drift this trick exists to make impossible.
	var c := script.get_script_constant_map()
	var link := float(c.get("LINK", 4.0))
	var chamber := float(c.get("ROOM", 11.0))
	var gap := float(c.get("GAP", 4.0))
	var parts: Array = [{"len": link, "wide": K.CORRIDOR_W, "room": false}]
	for i in int(c.get("ROOMS", 3)):
		if i > 0:
			parts.append({"len": gap, "wide": K.CORRIDOR_W, "room": false})
		parts.append({"len": chamber, "wide": chamber, "room": true})
	_publish_annex(vault, cell, side, float(c.get("CEIL", K.CEIL_CORRIDOR)),
		parts)

	# The prize is minted when the door opens, not when the floor is built --
	# `Vault.reveal()` carries the reason. The already-open case is not a
	# nicety: `LockedDoor` records `door_open_<destination>` and comes back open
	# on the next visit, and a vault you have opened and not emptied has to still
	# have its relic in it.
	if door != null:
		door.opened.connect(func(_where: StringName) -> void: vault.call(&"reveal"))
		if door.is_open():
			vault.call(&"reveal")


# --- The gate room ------------------------------------------------------------

## `docs/PUZZLES.md` §5.2, and `docs/SCOPE.md` §3 calls it the demo: **the
## Cistern's T0 gate room, a key hunt, with its cycle back to the entrance.**
##
## Three objects and one nest (§3, combinator 1 -- *one atom's reward is
## another's input*):
##
## - a **sun socket** on the far wall, the one T0 atom that asks the player to
##   aim, standing where its beam falls across the middle of the room;
## - the **small key**, dark and unarmed until the socket lights, off to one side
##   so finding it is a second beat and not a consolation prize;
## - a **`PuzzleGate` with `needs_key`** in the doorway the floor continues
##   through, so the door is on the critical path by construction rather than by
##   a placement that happens to be in the way.
##
## The gate watches the KEY and not the socket. Both would be true and one is
## redundant -- the key cannot be reached without the socket -- and a gate whose
## refusal said "THE SOCKET IS DARK" while a key floated in plain sight would be
## telling the player about the wrong half of their own puzzle.
##
## The sounding stone (§6) is dark until the door swings. The Echo is the reward
## for the gate, not for the socket.
func _place_gate_room(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var root: Node3D = rooms[cell]["node"]
	var tag := StringName("gate_%d" % Run.level)

	# The doorway that carries on toward the boss, and no other. A critical-path
	# puzzle whose door is on a spur is a puzzle you walk around, which is the
	# entire distinction §5.2 draws between this shape and the treasure one.
	var onward := _step_toward(cell, deepest)
	if onward == &"":
		push_warning("dungeon: gate room %s has no way on to %s" % [cell, deepest])
		return
	var spot := _wall_spot({"cell": cell, "side": onward, "offset": Vector2.ZERO})
	var facing: Vector3 = spot["facing"]
	var along := along_of(float(spot["yaw"]))
	var half := size_of(cell) * 0.5

	var gate := PuzzleGate.new()
	gate.name = "GateDoor"
	gate.puzzle_id = tag
	gate.needs_key = true
	gate.mark_tier = PuzzleAtoms.T0
	gate.destination = tag
	gate.position = spot["pos"]
	gate.rotation.y = float(spot["yaw"])
	root.add_child(gate)
	p["node"] = gate

	var key := PuzzleAtoms.make(PuzzleAtoms.SMALL_KEY, tag)
	if key == null:
		return
	key.name = "GateKey"
	key.position = along * (half - 2.2) + facing * 1.0
	key.set(&"armed", false)
	root.add_child(key)
	key.visible = false

	# **The prefab.** `docs/PUZZLES.md` §8 promised twelve of these and the room
	# had exactly one for a while; this is the table that makes the promise real.
	#
	# Every prefab ends the same way -- it WAKES THE KEY -- and that is the whole
	# reason the table is safe to add. The door's contract does not move: it
	# watches one key, `needs_key` stays true, its refusal keeps naming the key
	# rather than whichever half of the puzzle happens to be in the room this run,
	# and §5.2's spine (and the director that proves it) is unchanged. What varies
	# is the puzzle in front of the key, which is the thing a player replaying
	# floor 1 for the fifth time actually sees.
	var made := _gate_prefab(root, cell, tag, spot, key)
	if not made:
		return

	var prize := Chest.new()
	prize.name = "GateChest"
	prize.picks = Prog.chest_picks(Run.level, false)
	prize.position = along * (half - 2.6) - facing * (half - 3.0)
	prize.rotation.y = atan2(-prize.position.x, -prize.position.z)
	# It ARRIVES on the solve, Ocarina's own beat -- the room chimes and a chest is
	# suddenly standing where there was floor. Not "present but refuses to open":
	# a shut chest with no stated reason is `LockedDoor`'s LOCKED, the exact
	# failure GDD pillar 3 forbids, and there is no honest line to put on it
	# because the thing it is waiting for is the puzzle the player is inside.
	# `enabled` is `Interactable`'s own switch, so it cannot take focus either.
	prize.visible = false
	prize.enabled = false
	root.add_child(prize)

	var stone: Node3D = _make_stone(&"gate")
	if stone != null:
		stone.position = -along * (half - 2.4) - facing * (half - 4.2)
		# Aimed at the middle of the room. The Votive Court's effigy arc opens along
		# its own -Z, so an unaimed shrine in a corner offers the player its back.
		# Forward points along `v` at
		# `atan2(-v.x, -v.z)` (docs/CONTRACT.md §2.5), and `v` here is the way home.
		stone.rotation.y = atan2(stone.position.x, stone.position.z)
		root.add_child(stone)
		gate.opened.connect(func(_where: StringName) -> void: stone.call(&"offer"))
	gate.opened.connect(func(_where: StringName) -> void: _land_prize(prize))

	# The restore case -- a floor re-entered inside one run brings its atoms back
	# from their flags and `restore_solved()` deliberately emits nothing
	# (`PuzzleAtom._ready`) -- is each prefab's own business, and every one of them
	# handles it the same way: check `is_solved` after wiring the signal. Without
	# that the key stays dark for ever on the second visit and the room is a locked
	# door with no key in it.


## The gate room's puzzle prefabs (`docs/PUZZLES.md` §8), one function each.
##
## Picked by `(shape ceiling, owned verb)` through `PuzzleAtoms.pool`, which is
## §0 rule 1 in one call -- a prefab never appears on a floor whose player cannot
## own its verb, so the critical path is never blocked by a seed.
##
## Each one returns `true` if it built, and every one of them ends by connecting
## something to `_wake_key`. **That is the contract**, and the reason a table can
## be added under a shipped door without touching the door: the room varies, the
## reward path does not.
const GATE_PREFABS: Array[StringName] = [&"sun_nest", &"lights_out", &"eye_row"]


func _gate_prefab(root: Node3D, cell: Vector2i, tag: StringName,
		spot: Dictionary, key: Node3D) -> bool:
	var pool := PuzzleAtoms.pool(_gate_tier())
	var open_to: Array[StringName] = []
	for name_i: StringName in GATE_PREFABS:
		if _prefab_fits(name_i, pool):
			open_to.append(name_i)
	if open_to.is_empty():
		# `sun_nest` is T0 and `pool` always answers T0 with something, so this is
		# a manifest whose atom kit has been emptied. Refuse loudly rather than
		# building a door with no key in the world, on the critical path.
		push_warning("dungeon: no gate prefab fits floor %d" % Run.level)
		return false
	# `--gate-prefab=lights_out` forces one. Not a debug hook bolted on: the pick is
	# seed-driven, so without this a director can only ever photograph whichever
	# prefab its own seed happened to draw, and the other two ship unproven. Read
	# from the command line rather than an export because the room is built in
	# `_ready`, before any director gets to touch the node.
	var forced := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gate-prefab="):
			forced = a.substr(14)
	var pick: StringName = open_to[_rng.randi_range(0, open_to.size() - 1)]
	if forced != "" and open_to.has(StringName(forced)):
		pick = StringName(forced)
	print("dungeon: gate prefab %s" % pick)
	match pick:
		&"lights_out": return _gate_lights_out(root, cell, tag, spot, key)
		&"eye_row": return _gate_eye_row(root, cell, tag, spot, key)
	return _gate_sun_nest(root, cell, tag, spot, key)


## What each prefab needs in the pool. Read off the SAME `pool` the placer uses,
## so a prefab can never be picked for a floor whose verb the player lacks.
func _prefab_fits(name_i: StringName, pool: Array) -> bool:
	match name_i:
		&"lights_out": return pool.has(PuzzleAtoms.LANTERN)
		&"eye_row": return pool.has(PuzzleAtoms.EYE_SWITCH)
	return pool.has(PuzzleAtoms.SUN_SOCKET)


## Prefab 1, the original: a beam off the grate, bounced off the shield into a
## socket. T0, and the one atom in the kit that asks the player to AIM.
##
## The socket stands against the wall OPPOSITE the door, looking back at it, so
## its beam runs the length of the room and the catch lands where the player
## already walks. `SunSocket` authors the grate and the catch off its own forward
## (`catch_offset`, `beam_from`), so aiming the prop is one rotation and the
## geometry cannot be positioned wrong -- see that file's class note.
##
## A tag of its own, and NOT the gate's: `PuzzleGate._adopt` collects every atom
## carrying its own `puzzle_id`, so a socket sharing the tag would be adopted and
## the door's refusal would name the wrong half of the nest. The tag is still not
## empty, because `PuzzleAtom.flag_id()` falls back to the node NAME and a per-run
## flag keyed on a name is one rename away from being a different flag.
func _gate_sun_nest(root: Node3D, cell: Vector2i, _tag: StringName,
		spot: Dictionary, key: Node3D) -> bool:
	var facing: Vector3 = spot["facing"]
	var half := size_of(cell) * 0.5
	var socket := PuzzleAtoms.make(PuzzleAtoms.SUN_SOCKET,
		StringName("gate_%d_nest" % Run.level))
	if socket == null:
		return false
	socket.name = "GateSocket"
	socket.position = facing * (half - 1.3)
	# Forward is `-basis.z`, so a node whose `facing_of(yaw)` is `facing` looks
	# back along `-facing` -- at the door (docs/CONTRACT.md §2.5).
	socket.rotation.y = atan2(facing.x, facing.z)
	root.add_child(socket)
	socket.connect(&"solved", func(_a) -> void: _wake_key(key))
	# A floor re-entered inside one run restores its atoms from their flags, and
	# `restore_solved()` deliberately emits nothing -- so the key has to be woken
	# by hand for a socket that was already lit when the room rebuilt.
	if bool(socket.call(&"is_solved")):
		_wake_key(key)
	return true


## Prefab 2, lights out (`docs/PUZZLES.md` §3, combinator 6). A 3x3 of lanterns
## in the middle of the room: strike one and its orthogonal neighbours flip too,
## and the key wakes when the board is lit out.
##
## **The grid gets a tag of its own, not the gate's**, for the same reason the
## socket does -- nine adopted lanterns would make the door refuse with "4 OF 9
## LANTERNS STILL DARK" and never mention the key it is actually watching. That
## is why `LanternGrid` has a `lit_out` signal: this arrangement is a NEST, not
## the door-counts-the-atoms one the grid's class note describes.
func _gate_lights_out(root: Node3D, cell: Vector2i, _tag: StringName,
		spot: Dictionary, key: Node3D) -> bool:
	var facing: Vector3 = spot["facing"]
	var half := size_of(cell) * 0.5
	var grid := LanternGrid.new()
	grid.name = "GateLights"
	grid.puzzle_id = StringName("gate_%d_nest" % Run.level)
	# Off the middle, toward the far wall: the board wants the player to walk INTO
	# it and read it from inside, and a grid against the door is one the player
	# reads over their shoulder while standing at the thing it opens.
	grid.position = facing * (half * 0.42)
	root.add_child(grid)
	grid.lit_out.connect(func() -> void: _wake_key(key))
	if bool(grid.call(&"is_lit_out")):
		_wake_key(key)
	return true


## Prefab 3, a row of eyes -- **`docs/PUZZLES.md` §3, combinator 2, *sequence*,
## and since card #44 it is actually one.** **T1**: it only appears once the
## player owns the Bow, which on floor 1 means never and on floor 2 means always
## -- `_prefab_fits` reads the same pool the ceiling does, so this cannot strand
## a floor.
##
## ## The order, and why the DOOR owns it
##
## This header said *"relaxed to 'all of them'"* for a release, and that was the
## honest label on a row you could shoot in any order. It is a real sequence now:
## `gate.ordered = true`, the eyes are handed to the door with `watch()`, and
## `index` runs left to right along the wall. Shoot them out of order and
## `PuzzleGate._break_the_sequence` puts the whole row back — the lit ones go dark
## — and the door's refusal names the one it wants next.
##
## **The eyes join the door's set, and the sun socket deliberately does not.**
## §9's fourth decision says an atom the key cannot be reached without is
## redundant in the set and would make the refusal name the wrong half — *THE
## SOCKET IS DARK* beside a key you can see. Both halves of that reasoning invert
## here. A sequence has to be counted somewhere, and `PuzzleGate` is the thing in
## this project that counts atoms; and the gate room's key is `visible = false`
## until the row is finished, so there is no key in sight for the eye to be the
## wrong half OF. While the row is unfinished the door names an eye, which is the
## only object the player can act on; the frame the row completes, the key appears
## and the door starts naming that instead (`PuzzleGate._the_sequence` skips a
## kind with one member, which is what makes that handover automatic).
##
## `needs_key` and the key hunt are untouched: the door still refuses without the
## key and still spends it. The row is a second thing it counts, not a second
## contract.
##
## Three, spread along the wall OPPOSITE the door and looking back down the room
## at it -- the same arrangement `_gate_sun_nest` uses and for its reason: the
## shot runs the length of the room, so the player is firing across the floor
## they already walk rather than at the wall they are standing against. (This
## note used to say "the wall the door is in", which the arithmetic below has
## never done: `facing` points INTO the room from the doorway.)
##
## ## The height, and the facing, and which of the two was actually wrong
##
## They stood at `y = 0` -- half sunk in the floor, a switch you could trip over,
## below the sword's reach and below anything a bow is aimed at. That is fixed
## here: `EYE_Y`, the same 2.05 m the shortcut's eye and `convert_arrow.gd`'s
## pair use, because a shot the player has already learned to take should be the
## same shot. It is not cosmetic -- a real arrow fired at the old row went into
## the floor in front of it, and `tools/directors/gate_eye_row.gd` beat E is that
## arrow.
##
## **The facing was already right, and this is the record of it having been
## measured rather than argued.** Card #27 said `atan2(facing.x, facing.z)`
## pointed the pupils into the stone. It does not, and `CLAUDE.md` §4's rule cuts
## both ways -- you do not get to *break* a facing from a code comment either.
## `facing` is the way a wall looks INTO the room (`facing_of`), so a node given
## that yaw has `basis.z == facing` and therefore `-basis.z == -facing`, which
## from the FAR wall is back down the room. Measured on the built nodes, before
## anything here changed: forward `(0.00, -1.00)` on all three, dotted with the
## way to the middle of the room `0.91 / 1.00 / 0.91`, and a ray out of each
## eye's own nose travelling its full 1.20 m without meeting stone. Photographed
## too, which is the half no number replaces: `g_02_eye_close.png` shows three
## pale pupils facing the camera out of three sockets sitting in the floor.
## `_shortcut_eye_high` takes the opposite turn because its eye is in the wall
## the door is in; these two are the kit's two conventions and both are correct.
##
## The standoff is the third fix and it comes from card #5: `KitWall` collides
## with one box covering the slab *and* its 0.26 m relief, so a wall prop has to
## clear that or it renders perfectly and no arrow can reach it. 0.9 m was clear
## by luck; `WALL_STANDOFF` is clear on purpose, and it is the number every other
## wall-mounted atom in this file is placed with.
##
## ## The urn is §0 rule 2 and it is not optional (card #43)
##
## *Every puzzle room is solvable from a cold start with an empty pouch, because
## the urns beside it hold exactly what it needs.* Both shortcut prefabs carry
## that sentence and this one shipped without it -- three eyes that only an arrow
## opens, and no arrows anywhere in the room.
##
## **It is worse here than at either shortcut, not better.** A shortcut is
## optional by construction: a player who cannot open it walks the long way. This
## gate stands **in the doorway the floor continues through** (`_place_gate_room`
## picks `_step_toward(cell, deepest)` and nothing else), so there is no
## walk-around. Arrows do have other underground sources -- `arrow_chance` per
## room, chests, `Fletching.RECIPE` out of the bag -- and every one of them is a
## *probability*, which is the exact thing rule 2 exists to refuse. Card #29 made
## the same argument about scattering Burst charges across a floor.
##
## Its tag is its own -- `PuzzleAtoms.gates(URN)` is false so the gate would never
## adopt it, but a flag keyed on a node NAME is one rename from being a different
## flag, and `_shortcut_eye_high` and `_shortcut_pillar_brace` both say so too.
func _gate_eye_row(root: Node3D, cell: Vector2i, tag: StringName,
		spot: Dictionary, key: Node3D) -> bool:
	var facing: Vector3 = spot["facing"]
	var along := along_of(float(spot["yaw"]))
	var half := size_of(cell) * 0.5
	var nest := StringName("gate_%d_nest" % Run.level)
	# The door, so the row can be handed to it -- see the ORDER note in the class
	# comment. `_place_gate_room` built it before it called this, and it is the
	# only `PuzzleGate` in the room.
	var gate := root.get_node_or_null(^"GateDoor") as PuzzleGate
	if gate != null:
		gate.ordered = true
	var eyes: Array[Node3D] = []
	for i in EYE_ROW_EYES:
		var eye := PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, nest)
		if eye == null:
			return false
		eye.name = "GateEye%d" % i
		# **`index` runs LEFT to RIGHT as the player reads the wall**, which is the
		# example §3's table gives for this combinator verbatim -- *"three eyes, left
		# to right"*. `along_of(yaw)` is the doorway's own left (a viewer's right is
		# `facing x UP`, which works out to `-along`), so index 0 has to sit at
		# `+along` and count down. Written the other way the row is a sequence the
		# player answers backwards, and nothing in the frame says why.
		eye.index = i
		eye.position = facing * (half - WALL_STANDOFF) \
			+ along * (1.0 - float(i)) * 3.2 + Vector3(0.0, EYE_Y, 0.0)
		eye.rotation.y = atan2(facing.x, facing.z)
		root.add_child(eye)
		eyes.append(eye)
		# Wired by hand rather than by tag, which is exactly what `watch()` is for.
		# The row keeps its own `puzzle_id` -- `_adopt` must not collect it, or a
		# second prefab sharing the gate's tag would join this sequence.
		if gate != null:
			gate.watch(eye)
	# The key wakes on the LAST one. Counted here rather than by a second
	# `PuzzleGate`, because a door watching the eyes and a door watching the key
	# would be two doors, and §5.2 wants one.
	var lit := func() -> void:
		for e in eyes:
			if not bool(e.call(&"is_solved")):
				return
		_wake_key(key)
	for e in eyes:
		e.connect(&"solved", func(_a) -> void: lit.call())
	lit.call()

	# The supply. See the class note -- this is §0 rule 2, on the critical path.
	#
	# Placed off `spot["pos"]`, which is the GATE's wall, so it stands on the near
	# side of the door the room is about to refuse: the player reads *THE KEY IS
	# ELSEWHERE*, turns round, and the answer is in the same look as the question.
	# `_shortcut_pillar_brace` puts its cache at `along * 2.3 + facing * 2.6` for
	# that reason and this is the same offset within a few centimetres.
	#
	# Three numbers are load-bearing and none of them is arbitrary:
	#
	# * `along * 2.6` is OFF THE DOOR LINE. The doorway is 2.4 m wide and the
	#   leaves swing INTO the room (`LockedDoor.OPEN_DEG`), so anything inside
	#   ~1.2 m of the centre line is either in the opening or under a leaf.
	# * `facing * 2.2` is far enough out of the reveal to be visible from inside
	#   the room and near enough to the door to be in frame while reading it.
	# * Both put it BEHIND the firing line. The eyes are on the far wall at
	#   `facing * (half - WALL_STANDOFF)` and the player shoots up the room at
	#   them; an urn out in the middle of that would eat arrows aimed at the row.
	var pot := PuzzleAtoms.make(PuzzleAtoms.URN, StringName("%s_pot" % tag))
	if pot != null:
		pot.name = "GateUrn"
		# Spelled out rather than left to `Urn`'s default, exactly as
		# `_shortcut_pillar_brace` spells out `&"charges"`: what an urn holds is
		# the PLACER's decision (`Urn`'s class note), and a rule-2 guarantee
		# resting on someone else's default is a guarantee one edit from gone.
		pot.set(&"holds", &"arrows")
		pot.set(&"amount", EYE_ROW_ARROWS)
		pot.position = spot["pos"] + along * 2.6 + facing * 2.2
		root.add_child(pot)
	return true


## A puzzle's chest lands. §5.2's third reward — see `_place_gate_room`,
## `_land_shortcut_rewards` and `place_maze`, which are the three callers.
##
## The drop, the flash, the shake and the sound all live in `RewardVfx` now, so
## a chest that arrives because you solved a puzzle and a chest that arrives
## because you beat the room are the same event to the player -- which is the
## point. All three of these are tier 1: they pay `Prog.chest_picks(level,
## false)`, the ordinary table, and a tier-2 flash over an ordinary chest is the
## announcement lying about the contents.
func _land_prize(prize: Node3D) -> void:
	RewardVfx.land(prize, RewardVfx.MINOR)


# --- Held rewards ---------------------------------------------------------------
#
# **A chest does not stand next to the thing guarding it.** Until this, the
# generator put a room's chest down at build time and it was lootable from the
# moment the player walked in -- so the reward for a fight was collectable
# without having the fight, and the three puzzle chests above (which have always
# waited) read as the exception rather than the rule.
#
# Two halves, because they happen at opposite ends of generation: `_hold_reward`
# hides the prize whenever it is placed, and `_arm_room_rewards` hangs it on that
# room's `RoomWatch` once `_populate` knows what is standing in there.


## Put `prize` away until its room is beaten. Call this at placement time, from
## wherever the prize is built.
##
## `tier` is a `RewardVfx` tier and it is decided HERE, by the placer, because
## the placer is the only thing that knows what it just put in the chest --
## `Prog.chest_picks(level, true)` and a boss door next to it is tier 2, an
## ordinary room's roll is tier 1.
func _hold_reward(cell: Vector2i, prize: Node3D, tier: int) -> void:
	if prize == null:
		return
	prize.visible = false
	# `Interactable`'s own switch. Without it the chest keeps its trigger sphere
	# and can take the interact prompt through its own invisibility -- the player
	# gets `E TO OPEN` standing in an empty corner.
	prize.set(&"enabled", false)
	if not _held_rewards.has(cell):
		_held_rewards[cell] = []
	var held: Array = _held_rewards[cell]
	held.append({"node": prize, "tier": tier})


## Hang everything held for `cell` on that room's watcher, and forget it.
##
## `watch` null means there is nothing in the room to defeat, so there is nothing
## to wait for: the prize simply exists, with no flash. A ceremony for a room the
## player has not done anything to is the cue teaching them the wrong lesson.
func _arm_room_rewards(cell: Vector2i, watch: RoomWatch) -> void:
	if not _held_rewards.has(cell):
		return
	var held: Array = _held_rewards[cell]
	_held_rewards.erase(cell)
	for entry: Dictionary in held:
		var prize: Node3D = entry["node"]
		var tier: int = entry["tier"]
		if watch == null:
			RewardVfx.show_now(prize)
			continue
		watch.cleared.connect(func() -> void: RewardVfx.land(prize, tier))


## Nobody claimed these. Make them real anyway, silently.
##
## `_populate` `continue`s past the entrance, the boss cell and the maze cell
## before it ever spawns a body, so an anchor that lands in one of those would
## leave its chest hidden for the whole run with nothing able to reveal it -- a
## reward the player can walk through. There is no honest ceremony to give them
## either: this runs while the floor is still behind the loading card, where a
## flash would fire at nobody. `RewardVfx.show_now` is exactly that case.
func _release_unclaimed_rewards() -> void:
	for cell: Vector2i in _held_rewards:
		for entry: Dictionary in _held_rewards[cell]:
			RewardVfx.show_now(entry["node"] as Node3D)
	_held_rewards.clear()


## Wake the key through its own reveal when it is the shipped pickup. The
## fallback keeps prefab wiring generic for any other Node3D reward.
func _wake_key(key: Node3D) -> void:
	if key == null or not is_instance_valid(key):
		return
	if key is SmallKey:
		var small_key := key as SmallKey
		if small_key.is_solved() or small_key.is_revealed():
			return
		small_key.reveal()
	else:
		key.visible = true
		key.set(&"armed", true)
	Bus.request_sfx.emit(&"glint_bell", key.global_position)


## Which door out of `cell` leads on toward `target`, along the TREE. Empty when
## `cell` is not on that path or is its end.
##
## Off `path_to` and not off the grid: two rooms can be neighbours on the grid
## without a door between them (that is what the chord edge is), and a step that
## trusted adjacency would put the gate in a wall.
func _step_toward(cell: Vector2i, target: Vector2i) -> StringName:
	var route := path_to(target)
	var i := route.find(cell)
	if i < 0 or i + 1 >= route.size():
		return &""
	var step := route[i + 1] - cell
	for d: StringName in DIRS:
		if DIRS[d] == step:
			return d
	return &""


## One votive shrine, dark. `auto_offer` is off at every generated site: the
## blessing is a REWARD (§6's table -- shortcut, gate room, treasure puzzle),
## and a court that answered on floor-build would reveal three unsolved rewards.
func _make_stone(stone_id: StringName) -> Node3D:
	var packed := load(STONE_SCENE) as PackedScene
	if packed == null:
		push_error("dungeon: %s failed to load" % STONE_SCENE)
		return null
	var stone := packed.instantiate() as Node3D
	if stone == null:
		push_error("dungeon: %s root is not Node3D" % STONE_SCENE)
		return null
	stone.name = "SoundingStone_%s" % stone_id
	stone.set(&"stone_id", stone_id)
	stone.set(&"auto_offer", false)
	return stone


# --- The treasure puzzle ------------------------------------------------------

## `docs/PUZZLES.md` §5.3: *optional, richer, harder* -- a puzzle on the mid-ring's
## blank wall, and behind it the floor's **miniboss** (§7), a rich chest and an
## Echo. Nothing here is on the critical path, so GDD §5.1's *"walking in, filling
## twelve slots and roping out is a complete run"* survives untouched.
##
## The puzzle is §3's first combinator, the **nest**: a pressure plate across the
## room from the door, and a push block to hold it down. It is the oldest pair in
## the genre and it only works because `PressurePlate` does not latch -- stand on
## it yourself and you cannot also be at the door.
##
## The block is deliberately **not** one of the gate's atoms. `mark_offset` zero
## means it draws no chalk square and never solves; it is furniture with weight,
## and `PushBlock`'s own class note is about exactly this case. A gate that
## watched it would be a gate waiting for a solve that is not coming.
func _place_puzzle_room(id: StringName) -> void:
	var p: Dictionary = placements[id]
	var cell: Vector2i = p["cell"]
	var root: Node3D = rooms[cell]["node"]
	var spot := _wall_spot(p)
	var facing: Vector3 = spot["facing"]
	var along := along_of(float(spot["yaw"]))
	var half := size_of(cell) * 0.5
	var tag := StringName("treasure_%d" % Run.level)

	# §5.3 allows tier <= N and §0 rule 1 clamps that to what the player owns;
	# `PuzzleAtoms.pool` is both of those in one call. The plate is preferred
	# because it is the only atom in the kit with a partner built for it -- every
	# other pick is a straight gate on one body, which is still a §3 shape and is
	# what the richer floors will replace as their prefabs land.
	var pool := PuzzleAtoms.pool(_treasure_tier())
	if pool.is_empty():
		return
	var pick: StringName = PuzzleAtoms.PRESSURE_PLATE if \
		pool.has(PuzzleAtoms.PRESSURE_PLATE) \
		else pool[_rng.randi_range(0, pool.size() - 1)]

	var gate := PuzzleGate.new()
	gate.name = "TreasureGate"
	gate.puzzle_id = tag
	gate.mark_tier = PuzzleAtoms.tier(pick)
	gate.destination = tag
	gate.position = spot["pos"]
	gate.rotation.y = float(spot["yaw"])
	root.add_child(gate)
	p["node"] = gate

	# Across the room from the door, on purpose: "the plate you cannot stand on
	# and reach the door from" is the whole nest, and a plate within arm's reach
	# of the gate would make the block ornamental.
	var atom := PuzzleAtoms.make(pick, tag)
	if atom == null:
		return
	atom.name = "TreasureAtom"
	atom.position = facing * (half - 3.5)
	atom.rotation.y = atan2(facing.x, facing.z)
	root.add_child(atom)

	if pick == PuzzleAtoms.PRESSURE_PLATE:
		var block := PuzzleAtoms.make(PuzzleAtoms.PUSH_BLOCK,
			StringName("treasure_%d_weight" % Run.level))
		if block != null:
			block.name = "TreasureBlock"
			# Three shoves away along the wall's own axis. `PushBlock.STEP` is the
			# grid, so a whole number of steps lands it dead centre on the plate --
			# a block placed off the grid can never seat, and the failure looks like
			# a plate that does not register rather than like a placement bug.
			# Read off the script's own constant map rather than restated here --
			# the same trick `_vault_depth` uses, and for the same reason: a block
			# whose stride grew and a placement rule that did not is a block that
			# can never seat, and the symptom is a plate that looks broken.
			var step: float = block.get_script().get_script_constant_map() \
				.get("STEP", 1.2)
			block.position = atom.position + along * (step * 3.0)
			block.set(&"mark_offset", Vector3.ZERO)
			root.add_child(block)

	_place_chamber(cell, p["side"], spot)


## What is behind the treasure gate: a stub, a chamber, the miniboss in it, and
## the chest and the Echo standing OUTSIDE its seal ring.
##
## Outside the ring is the whole reward structure and it is geometry, not a lock:
## `BossArena` fences a circle of `BossDb`'s authored radius, and `CHAMBER_SKIRT`
## is sized so the band between that fence and the back wall holds a chest and a
## sounding stone. A player sealed in with the Sluice-Keeper can see both and
## reach neither.
func _place_chamber(cell: Vector2i, side: StringName,
		spot: Dictionary) -> void:
	var boss_id := BossDb.miniboss_for(Run.level)
	if boss_id == &"":
		return
	var script := load(ARENA_SCRIPT) as GDScript
	if script == null:
		push_error("dungeon: %s failed to load" % ARENA_SCRIPT)
		return
	var size := _chamber_size()
	var root := _build_chamber(spot, cell, side, "TreasureChamber", size)
	var mid := CHAMBER_STUB + size * 0.5
	var back := CHAMBER_STUB + size

	var arena: Node3D = script.new()
	arena.name = "MinibossArena"
	arena.set(&"boss_id", boss_id)
	# **`&""`, not `&"boss"`.** §7: a miniboss drops nothing but the chest behind
	# it, and `BossArena._replace_lost_relic` would otherwise put floor N's BOSS
	# relic on the floor of a spent miniboss chamber -- the boss's drop handed out
	# behind an optional puzzle.
	arena.set(&"relic_slot", &"")
	# Deeper in, away from the stub: the first thing through the hole should be a
	# silhouette on the far side of the room, not a shape already on top of you.
	arena.set(&"boss_offset", Vector3(0.0, 0.0, 4.5))
	# No `door_path`. `BossArena` treats that as a valid fixture and falls back to
	# its own `boss_dead_*` flag, which is what remembers a miniboss killed
	# earlier in the run. The gate in front is a `PuzzleGate` and has no `unseal`.
	arena.position = Vector3(0.0, 0.0, mid)
	root.add_child(arena)

	# **Both rewards hang on the KILL, not on the gate.** §5.3's list is miniboss +
	# chest + Echo, and either of them arriving when the door opened would pay the
	# puzzle for the fight it was gating. Read once and shared, because the chest
	# and the stone now ask the arena the same two questions.
	#
	# NOT a `RoomWatch`: the chamber is not a `rooms[]` cell -- it hangs off the
	# treasure gate and its one body belongs to the arena, which already publishes
	# `died_at` and `is_spent`. A watcher here would be a second answer to a
	# question that has one.
	var boss := arena.call(&"boss") as Node3D
	var spent := bool(arena.call(&"is_spent"))

	var chest := Chest.new()
	chest.name = "TreasureChest"
	# The rich table -- the same one the deep chest draws from. §5.3's promise is
	# that this branch pays for the extra work, and `Prog` already owns what
	# "richer" means at each depth.
	chest.picks = Prog.chest_picks(Run.level, true)
	chest.position = Vector3(-3.6, 0.0, back - 2.4)
	chest.rotation.y = PI
	chest.visible = false
	chest.enabled = false
	root.add_child(chest)
	if boss != null:
		# Tier 2. It is the rich table, behind a puzzle, behind a miniboss.
		boss.connect(&"died_at", func(_where: Vector3) -> void:
			RewardVfx.land(chest, RewardVfx.MAJOR))
	else:
		# Either the miniboss is already dead this run and the floor was re-entered
		# (`spent`), or the arena declined to build one at all. Both end the same
		# way and both must: a chest nothing can ever reveal is a reward the player
		# can see through and never open. No flash -- see `RewardVfx.show_now`.
		if not spent:
			push_warning(("dungeon: treasure chamber on floor %d has no miniboss; "
				+ "its chest is revealed with no fight to earn it") % Run.level)
		RewardVfx.show_now(chest)

	var stone: Node3D = _make_stone(&"treasure")
	if stone != null:
		stone.position = Vector3(3.6, 0.0, back - 2.6)
		# Turned back toward the arena, for the same reason the gate room's is: the
		# player arrives from the mouth and the court has to face them when
		# the fight ends. The chest opposite gets `rotation.y = PI` for this.
		stone.rotation.y = atan2(stone.position.x, stone.position.z - mid)
		root.add_child(stone)
		if boss != null:
			boss.connect(&"died_at",
				func(_where: Vector3) -> void: stone.call(&"offer"))
		elif spent:
			# Already killed this run and the floor was re-entered. The stone's own
			# flag is what stops a second offer; this only re-opens the one that was
			# never taken.
			stone.call(&"offer")


## The stone behind a treasure gate. `_build_landing`'s bigger sibling, and
## deliberately a separate function rather than a parameterised one: a landing is
## a threshold with a stair in it and this is a room, they share four helper
## calls, and folding them together would put five flags on the one that is only
## ever called twice.
##
## Built as a child of the Dungeon with its local +Z pointing out through the
## wall, so every piece below is authored once in door-space instead of four
## times with different signs.
func _build_chamber(spot: Dictionary, cell: Vector2i, side: StringName,
		node_name: String, size: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = centre_of(cell) + spot["pos"]
	root.rotation.y = float(spot["yaw"]) + PI
	add_child(root)

	var tag := StringName(node_name)
	var w := K.CORRIDOR_W
	# Room height throughout, INCLUDING the stub -- unlike `_build_landing`, which
	# is corridor height end to end. Two different ceilings would leave a two-metre
	# slot above the stub's mouth that is open to the void, visible from inside the
	# chamber the moment the player turns round.
	var h := K.CEIL_ROOM
	var half := size * 0.5
	var mid := CHAMBER_STUB + half

	_slab(root, Vector2(w, CHAMBER_STUB), Vector3(0.0, 0.0, CHAMBER_STUB * 0.5), h)
	_slab(root, Vector2(size, size), Vector3(0.0, 0.0, mid), h)

	# The stub's two sides. A wall's face is its local +Z, so the one on -X looks
	# toward +X and vice versa.
	for s: float in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_wall(root, CHAMBER_STUB, h, Vector3(s * w * 0.5, 0.0, CHAMBER_STUB * 0.5),
			PI * 0.5 * -s, _salt(cell, tag, 70 + i))

	for s: float in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		_wall(root, size, h, Vector3(s * half, 0.0, mid), PI * 0.5 * -s,
			_salt(cell, tag, 72 + i))
	_wall(root, size, h, Vector3(0.0, 0.0, CHAMBER_STUB + size), PI,
		_salt(cell, tag, 74))
	var flank := (size - w) * 0.5
	if flank > 0.4:
		for s: float in [-1.0, 1.0]:
			var i := 1 if s > 0.0 else 0
			_wall(root, flank, h, Vector3(s * (w + flank) * 0.5, 0.0, CHAMBER_STUB),
				0.0, _salt(cell, tag, 76 + i))

	# Two sconces on the back wall, flanking the chest. They are the only warm
	# light in here -- the arena's seal brings its own cold one -- so the far side
	# of the room reads as the place with the prize in it from the doorway.
	for s: float in [-1.0, 1.0]:
		var i := 1 if s > 0.0 else 0
		var t := ROOM_SCENE_TORCH.instantiate()
		t.rng_seed = _salt(cell, tag, 78 + i)
		t.cast_shadow = false
		t.light_range = 12.0
		t.light_energy = 6.5
		t.position = Vector3(s * half * 0.55, KitStyle.SCONCE_Y,
			CHAMBER_STUB + size - 0.1)
		t.rotation.y = PI
		root.add_child(t)

	_publish_annex(root, cell, side, h, [
		{"len": CHAMBER_STUB, "wide": w, "room": false},
		{"len": size, "wide": size, "room": true},
	])
	return root


# --- The chord ----------------------------------------------------------------

## Bar the chord edge from the shallow side. The corridor itself was built by
## `_build` like any other, because as far as the geometry is concerned this edge
## is an ordinary door between two rooms -- what makes it a cycle is that one end
## of it does not open.
func _build_chord() -> void:
	if chord.is_empty():
		return
	var near: Vector2i = chord["near"]
	var d: StringName = chord["dir"]
	var root: Node3D = rooms[near]["node"]
	var script := load(BARS_SCRIPT) as GDScript
	if script == null:
		push_error("dungeon: %s failed to load" % BARS_SCRIPT)
		return
	var s: Dictionary = _sides_of(near)[d]
	var yaw: float = s["yaw"]
	var bars: Node3D = script.new()
	bars.name = "ChordBars"
	bars.set(&"tag", StringName("chord_%d" % Run.level))
	# Set back into the reveal by the same 50 mm every anchored door in this file
	# uses, so the kit doorway's surround frames the ironwork.
	bars.position = s["at"] + facing_of(yaw) * -0.05
	# The wall's own yaw and no turn of its own. `facing_of(yaw)` is the wall's +Z
	# and points INTO the room; a Node3D's forward is `-basis.z`, so a prop set to
	# the same yaw looks OUT of the room and down the corridor
	# (docs/CONTRACT.md §2.5). That vector is the whole one-way rule --
	# `BarredPassage` measures which side the player is on against it, and a prop
	# turned the other way would be a chord that only opens from the side it is
	# meant to refuse.
	bars.rotation.y = yaw
	root.add_child(bars)
	chord["node"] = bars


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
##
## Returns that root, because §5.1's chest and sounding stone stand in the
## shortcut's landing and want to be authored in the same door-space everything
## else in here is (`_land_shortcut_rewards`). `_place_boss` ignores it.
func _build_landing(spot: Dictionary, cell: Vector2i, side: StringName,
		node_name: String) -> Node3D:
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

	_publish_annex(root, cell, side, h, [
		{"len": LAND_STUB, "wide": w, "room": false},
		{"len": LAND_SIZE, "wide": LAND_SIZE, "room": true},
	])
	return root


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

## **Pick the room and widen it, before a stone of it is laid.**
##
## Two decisions, deliberately split: WHICH room the maze may have, and whether
## this floor gets one. The first is made for every floor and the room is widened
## either way, because `pick_maze_cell(true)` is a director's way of placing a
## maze on a seed whose roll said no — and a maze can only go into a room that was
## already built wide enough to hold it. The roll is remembered in `_maze_rolled`
## and read by `_populate`.
func _plan_maze() -> void:
	maze_reserved = null
	maze_grid = Vector2i(MAZE_ROWS, MAZE_COLS)
	# Rolled here rather than inside `pick_maze_cell` so that the pick and the roll
	# come off `_rng` in a fixed order -- a roll that only happened on some floors
	# would shift every later draw and change the whole floor, not just the maze.
	_maze_rolled = _rng.randf() < maze_chance
	var cell = pick_maze_cell(true)
	if cell == null:
		_maze_rolled = false
		# **Say which filter emptied the pool.** This was a bare "no room fits in",
		# and three floor-1 seeds in five printing it is either the one-doorway rule
		# being too strict or the anchors having eaten the floor -- two different
		# problems with one message, and no way to tell them apart without a
		# breakpoint. `PUZZLES.md` §5.4's room going missing is worth a sentence.
		var spare := 0
		var lone := 0
		var taken := {}
		for id: StringName in placements:
			taken[placements[id]["cell"]] = true
		for c: Vector2i in rooms:
			if c == entrance or c == deepest or taken.has(c):
				continue
			spare += 1
			if (rooms[c]["doors"] as Array).size() == 1:
				lone += 1
		push_warning(("dungeon: no room on level %d a maze fits in -- %d room(s) of "
			+ "%d spare after the anchors, %d of those with the one doorway the rim "
			+ "needs") % [Run.level, spare, rooms.size(), lone])
		return
	maze_reserved = cell
	var size := _maze_room_size(cell)
	maze_grid = _maze_grid(size)
	rooms[cell]["size"] = size


## One plain room per floor becomes a maze (`docs/PUZZLES.md` §5.4), or none.
##
## **Plain is the requirement, and it is not fussiness.** A maze fills its room
## wall to wall; dropped on an anchored room it would bury the gate, the chest or
## the sounding stone inside masonry, and the symptom would be a floor whose
## critical path silently cannot be finished. Anchors are placed before
## `_plan_maze` runs, so `placements` is already the authority on which rooms are
## spoken for and this only has to read it.
##
## The entrance and the deepest room are excluded for reasons of their own: the
## entrance is deliberately empty, and `deepest` is where the good chest and the
## boss live.
##
## `forced` skips the roll. It is what a director calls, and after `_plan_maze`
## has run it answers the room that was actually widened -- asking a second time
## and getting a different, 16 m room would hand back a room the maze does not fit
## in, which is the bug this whole reordering exists to remove.
func pick_maze_cell(forced: bool = false):
	if maze_reserved != null:
		return maze_reserved if forced or _maze_rolled else null
	if not forced and not _maze_rolled:
		return null
	var taken := {}
	for id: StringName in placements:
		taken[placements[id]["cell"]] = true
	var free: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		if cell == entrance or cell == deepest or taken.has(cell):
			continue
		# **ONE doorway, because the maze only has one hole.**
		#
		# `MazeRoom._build_rim` closes the grid on all four sides and cuts exactly
		# one opening — the mouth — and the solvability proof in `Maze.plan` is
		# about that room and no other (its own comment says so: two holes and
		# `Maze.reach` is answering a question about a grid nobody built). The maze
		# fills its room wall to wall. So a maze in a room with two doorways stands
		# a rim across one of them, and a room the floor's tree passes THROUGH
		# becomes a wall across the dungeon.
		#
		# Measured on floor 3: the maze took (1, -1), doors [w, e, n, s], on the
		# path to the Bellwake. The critical path arrives by the west door and the
		# rim was in it, so the boss chamber, the deep chest and the way down were
		# all unreachable ON FOOT IN THE GAME, and the leaf behind the east door
		# with it. Ten of `cistern_floor --level=3`'s checks went red off that one
		# fact, and only the first of them was the fault.
		#
		# This is also just the room `MazeRoom`'s own design describes — "the reward
		# is on the far side of the maze and the lock is the geometry" only reads as
		# a puzzle in a room you enter and leave by the mouth. A leaf, in other
		# words; the requirement was always there and nothing enforced it.
		#
		# The mouth is rotated onto whichever side that doorway is (`place_maze`),
		# so this costs the three-in-four floors whose one-door rooms do not happen
		# to face south — which is what refusing them instead would have cost.
		if (rooms[cell]["doors"] as Array).size() != 1:
			continue
		# It has to FIT -- and `MazeRoom` is the only thing that knows what fitting
		# means, so it is asked rather than second-guessed. This line used to read
		# `size_of(cell) < MAZE_COLS * MazeRoom.CELL + 2.0`, which measured the
		# maze and a token walkway and knew nothing about the lantern apron. It
		# passed every 16 m room on the floor and the lanterns spawned outside the
		# masonry in all of them: a puzzle nobody could press, holding a chest
		# nobody could open. Restating another script's geometry is what did it.
		#
		# Measured against the size the room WILL BE, not the size it is: this runs
		# before `_build` and the room is about to be rebuilt to `_maze_room_size`.
		var grid := _maze_grid(_maze_room_size(cell))
		if grid.x * grid.y < MAZE_MIN_CELLS:
			continue
		free.append(cell)
	if free.is_empty():
		return null
	# Widest first. Every candidate below holds a legal maze, but only some of them
	# hold the whole one -- a floor that put a 3x4 maze in a corner while a room
	# with space for 5x5 stood empty would be obeying the letter of `fits` and
	# throwing the room away. Ties go to the die, so the choice is still the seed's.
	var best := 0.0
	for one: Vector2i in free:
		best = maxf(best, _maze_room_size(one))
	var widest: Array[Vector2i] = []
	for one: Vector2i in free:
		if _maze_room_size(one) >= best - 0.01:
			widest.append(one)
	return widest[_rng.randi_range(0, widest.size() - 1)]


## **How wide the maze's room may actually be built here.**
##
## `MAZE_ROOM`, unless a neighbour is in the way. `_build_corridor` measures face
## to face and gives up below half a metre, so two rooms whose half-widths sum past
## `spacing` do not get a short corridor — they get **none at all**, and a room
## with no corridor into it is a room the floor's critical path may run through and
## nobody can reach. Nothing had to check this while every room was 16 m and the
## one exception was `deepest`, which is sized to clear by construction.
##
## It bites for real: the Bellwake's chamber is 30 m, so 13.5 + 15 leaves 28.5 m
## wanted out of a 26 m grid. **The first spelling of this refused those cells
## outright and that was wrong** — measured, one floor in five then had nowhere to
## put a maze at all, because a six-room tree with four anchors on it has one or
## two spare rooms and the boss's neighbour is usually one of them. Shrinking the
## room and cutting the grid down to match loses a couple of cells on those floors;
## refusing loses the room.
func _maze_room_size(cell: Vector2i) -> float:
	var room := MAZE_ROOM
	for d: StringName in DIRS:
		var other: Vector2i = cell + DIRS[d]
		if not rooms.has(other):
			continue
		room = minf(room, (spacing - MAZE_CLEAR - size_of(other) * 0.5) * 2.0)
	return maxf(room, room_size)


## The biggest grid `MazeRoom` will admit in a room this wide, capped at the
## shipped `MAZE_ROWS` x `MAZE_COLS`. Rows and columns are cut independently
## because they are charged differently — the lantern apron comes out of the DEPTH
## and only a walkway out of the width — and `MazeRoom` owns both numbers, so this
## reads them off it rather than repeating them.
func _maze_grid(size: float) -> Vector2i:
	var r := mini(MAZE_ROWS, int(floor((size - MazeRoom.APRON * 2.0) / MazeRoom.CELL)))
	var c := mini(MAZE_COLS,
		int(floor((size - MazeRoom.WALKWAY * 2.0) / MazeRoom.CELL)))
	if r < 1 or c < 1 or not MazeRoom.fits(size, r, c):
		return Vector2i.ZERO
	return Vector2i(r, c)


## Build it, and hang the loot on it opening.
##
## Public, and `pick_maze_cell` is too: `maze_chance` means a given seed may not
## place one, and a director that could only photograph the lucky seeds would be
## proving the roll rather than the room. `tools/directors/maze.gd` beat G asks
## for a free cell and places one itself, through this exact function -- and gets
## `maze_reserved` back, the room `_plan_maze` widened, which is the only room on
## the floor a maze fits in.
func place_maze(cell: Vector2i) -> void:
	var root: Node3D = rooms[cell]["node"]
	var maze := MazeRoom.new()
	maze.name = "MazeRoom"
	# The grid the ROOM can hold, not the ceiling -- `_plan_maze` already measured
	# it against the room's neighbours and this is where that measurement is spent.
	maze.rows = maze_grid.x
	maze.cols = maze_grid.y
	# Off the floor's own stream, so a replayed seed deals the same maze -- the
	# same reason `SoundingStone.offer` and `LanternGrid` use it.
	maze.rng = _rng
	# **Turn the mouth to face the room's doorway.**
	#
	# The grid is authored with its one opening at +Z (`MazeRoom.cell_centre`), and
	# nothing used to move it, so the maze faced south whatever side the player
	# came in by — three floors in four entering through solid rim. `pick_maze_cell`
	# guarantees exactly one doorway; this points the hole at it.
	#
	# `yaw + PI` and not `yaw`, per CLAUDE.md §4: `_sides_of` gives the yaw a wall
	# FACES, which is inward, and the mouth has to face out. s(PI)->0, n(0)->PI,
	# e(-PI/2)->PI/2, w(PI/2)->-PI/2. Checked against `facing_of`, not derived from
	# the rest pose of anything.
	# Public function, so the count is asserted here too rather than trusted from
	# `pick_maze_cell`. A director placing a maze by hand on a two-door room would
	# otherwise silently rebuild the bug this warning names.
	var doors: Array = rooms[cell]["doors"]
	if doors.size() != 1:
		push_warning(("dungeon: maze into %s, which has %d doorways -- the rim has "
			+ "one hole and will stand across the other %d, and anything behind "
			+ "them is unreachable")
			% [cell, doors.size(), maxi(doors.size() - 1, 0)])
	var side: StringName = doors[0] if not doors.is_empty() else &"s"
	maze.rotation.y = float(_sides_of(cell)[side]["yaw"]) + PI
	root.add_child(maze)

	var prize := Chest.new()
	prize.name = "MazeChest"
	prize.picks = Prog.chest_picks(Run.level, false)
	# Through the maze's transform. `prize_point` is in MAZE space and the chest is
	# a sibling in ROOM space; those were the same thing only while the maze sat
	# unrotated at the room's origin, and the line above just stopped being true.
	prize.position = maze.transform * maze.prize_point()
	prize.visible = false
	prize.enabled = false
	root.add_child(prize)
	# The chest is already standing in the deepest cell, hidden. It lands when the
	# way to it opens rather than when the player reaches it: §5.2's loot rule is
	# that solving the puzzle is what pays, and a chest that appeared on arrival
	# would read as a reward for walking.
	maze.opened.connect(func() -> void: _land_prize(prize))
	Atlas.mark(cell, Atlas.M_CHEST)


# Ambient urns are room texture with a small guaranteed payout, not puzzle
# supply. Their placement and contents live on a private stream so adding one
# here can never reshuffle a pack, chest, pillar or floor layout. [tune]
const AMBIENT_POT_SECOND_CHANCE := 0.35
const AMBIENT_POT_WALL_INSET := 0.75
const AMBIENT_POT_REWARDS := [
	{"id": &"coins", "weight": 44, "amount": 5},
	{"id": &"moss_agate", "weight": 20, "amount": 1},
	{"id": &"hearts", "weight": 12, "amount": 2},
	{"id": &"arrows", "weight": 10, "amount": 3},
	{"id": &"tide_sapphire", "weight": 7, "amount": 1},
	{"id": &"charges", "weight": 5, "amount": 1},
	{"id": &"blood_ruby", "weight": 2, "amount": 1},
]


## Put one urn against a blank wall, and sometimes a second against another.
## A blank side has neither doorway nor anchor, so its centre is outside both
## traffic lanes by construction; one pot per side keeps the centre readable.
func _place_ambient_pots(root: Node3D, cell: Vector2i) -> void:
	var sides := _ambient_pot_sides(cell)
	if sides.is_empty():
		return

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = _salt(cell, &"ambient_pot", 0)
	var first: StringName = sides[first_rng.randi_range(0, sides.size() - 1)]
	sides.erase(first)
	_place_ambient_pot(root, cell, first, 0, first_rng)

	if sides.is_empty():
		return
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = _salt(cell, &"ambient_pot", 1)
	if second_rng.randf() >= AMBIENT_POT_SECOND_CHANCE:
		return
	var second: StringName = sides[second_rng.randi_range(0, sides.size() - 1)]
	_place_ambient_pot(root, cell, second, 1, second_rng)


func _ambient_pot_sides(cell: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	var doors: Array = rooms[cell]["doors"]
	var anchors: Dictionary = rooms[cell]["anchors"]
	for side: StringName in DIRS:
		if not doors.has(side) and not anchors.has(side):
			out.append(side)
	return out


func _place_ambient_pot(root: Node3D, cell: Vector2i, side: StringName,
		slot: int, rng: RandomNumberGenerator) -> void:
	# Floor + cell + slot is the atom's stable persistence identity. The node name
	# stays short for instruments and is never used as the solved flag.
	var tag := StringName("ambient_pot_f%d_%d_%d_%d"
		% [Run.level, cell.x, cell.y, slot])
	var pot := PuzzleAtoms.make(PuzzleAtoms.URN, tag)
	if pot == null:
		return
	pot.name = "AmbientUrn%d" % slot
	pot.set(&"index", slot)
	var reward := _ambient_pot_reward(rng)
	pot.set(&"holds", reward["id"])
	pot.set(&"amount", reward["amount"])
	var wall: Dictionary = _sides_of(cell)[side]
	pot.position = wall["at"] + facing_of(float(wall["yaw"])) \
		* AMBIENT_POT_WALL_INSET
	root.add_child(pot)


## Weights total 100 and every interval has a reward: ambient pots never roll
## empty. The placer writes the result onto Urn; Urn itself remains non-random.
func _ambient_pot_reward(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi_range(1, 100)
	var ceiling := 0
	for row: Dictionary in AMBIENT_POT_REWARDS:
		ceiling += int(row["weight"])
		if roll <= ceiling:
			return row
	return AMBIENT_POT_REWARDS.back() as Dictionary


func _populate() -> void:
	var has_boss := placements.has(&"boss_door")
	var boss_cell := anchor_cell(&"boss_door")
	# Untyped on purpose: `pick_maze_cell` answers `null` when the floor has no
	# room to spare, and `:=` cannot infer a type from a Variant (CLAUDE.md §3).
	# The choice itself was made back in `_plan_maze`, before the masonry went up;
	# this only reads it.
	var maze_cell = pick_maze_cell()

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
		# The maze fills its room wall to wall, so it gets no scatter and no
		# chest of its own -- both would land inside masonry. Its reward hangs on
		# the maze opening instead, which is `docs/PUZZLES.md` §5.2's rule that a
		# puzzle pays rather than merely letting you past.
		if cell == maze_cell:
			place_maze(cell)
			continue

		var size := size_of(cell)
		_place_ambient_pots(root, cell)
		var dist := int(rooms[cell]["dist"])
		# Rolled once for the room and shared by the chest and the arrows, because
		# the arrows are placed OPPOSITE the chest and `_chest_dir` draws from the
		# floor's generator -- calling it twice would answer twice and the two would
		# stop being opposite. Rolled outside the chest branch for the same reason
		# the arrows are: a room with no chest still needs the direction.
		var chest_dir := _chest_dir(cell)
		# The manifest chooses WHICH body (`FloorDb.roster`, keyed on distance from
		# the entrance) and `Prog` chooses how hard it is (`elite_chance`, and the
		# health/damage/wind-up curve inside `Enemy`). Keeping those two apart is
		# what lets a floor be re-cast without being re-tuned.
		var elite_chance := Prog.elite_chance(Run.level)
		var count := _rng.randi_range(enemies_min, enemies_max)
		var has_barrel_cluster := _rng.randf() < barrel_cluster_chance
		if has_barrel_cluster:
			_place_barrel_cluster(root, size, chest_dir)
		# The watcher is built BEFORE the bodies and told about each one as it is
		# made, rather than handed a list afterwards. `Enemy._ready` runs the frame
		# it is added -- a body that woke up, was hit and died inside the same
		# generation pass would be a body the watcher never heard of, and a room
		# that could then never clear.
		var watch: RoomWatch = null
		if count > 0:
			watch = RoomWatch.attach(root, StringName(root.name))
		var thrower_assigned := false
		for i in count:
			var spot := _scatter(i, count, size * 0.30)
			var kind := _roll_kind(dist)
			# At most one elite in a room. The point of an elite is that it is
			# THE thing in the room; two of them is just a harder room, and the
			# separation rule has to keep them both legible besides.
			var elite := i == 0 and _rng.randf() < elite_chance
			var make_thrower := has_barrel_cluster and not elite and not thrower_assigned
			if make_thrower:
				thrower_assigned = true
			watch.add(_spawn_foe(root, kind, spot, elite,
				&"thrower" if make_thrower else &""))

		# The deep-chest anchor already put one in its room. On a floor with no
		# anchors at all the deepest room still gets the good chest, which is what
		# the Long Descent has always done.
		var anchored: bool = placements.has(&"deep_chest") \
			and anchor_cell(&"deep_chest") == cell
		if not anchored and (cell == deepest or _rng.randf() < chest_chance):
			var chest := Chest.new()
			# Named, because the next thing to read this node is an instrument. It
			# was a bare `Chest.new()` and the reading that found the bug below came
			# back as `/root/DungeonRun/Dungeon/Room_0_-1/@Area3D@2750`.
			chest.name = "RoomChest"
			chest.picks = Prog.chest_picks(Run.level, cell == deepest)
			chest.position = chest_dir * (size * 0.32)
			root.add_child(chest)
			# **The map still says there is a chest here from the moment the room
			# comes out of the fog**, even though the chest itself does not exist
			# until the room is beaten. That is deliberate and it is `place_maze`'s
			# precedent: the mark is what makes a room worth walking into, and a
			# minimap that only admitted to a chest once you had already earned it
			# would be telling you things you can see.
			Atlas.mark(cell, Atlas.M_CHEST)
			# The deepest room's chest rolls the rich table (`chest_picks(.., true)`
			# on the line above), so it announces itself as one.
			_hold_reward(cell, chest,
				RewardVfx.MAJOR if cell == deepest else RewardVfx.MINOR)

		# Arrows on the floor, opposite the chest and away from the door line, so
		# picking them up is a step off the path you were already walking rather
		# than something you collect by accident on the way through. Rolled here
		# and not inside the chest branch: a room with no chest is exactly the
		# room a dry quiver needs supply in.
		if _rng.randf() < arrow_chance:
			var bundle := ArrowBundle.new()
			bundle.name = "RoomArrows"
			bundle.count = ArrowBundle.FLOOR_COUNT
			# Across the room's middle from the chest, plus a stride to one side so
			# the two are not on one line. Derived from `chest_dir` instead of the
			# constants this used to be, which were opposite a chest that no longer
			# always stands where they were written against.
			var side_step := Vector3(-chest_dir.z, 0.0, chest_dir.x)
			bundle.position = -chest_dir * (size * 0.24) + side_step * (size * 0.30)
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

		# LAST in the room's pass, so it catches both this room's own chest and
		# anything an anchor stood here hundreds of lines ago (`_place_deep_chest`).
		_arm_room_rewards(cell, watch)

	# Anything still held belongs to a cell the loop above never reached the
	# population of -- the entrance, the boss chamber, the maze. See the function.
	_release_unclaimed_rewards()


## Two or three props against a quiet side of the room. `_chest_dir` prefers a
## blank wall, so its lane is already away from every doorway; the side offset
## keeps this cluster away from both the centre path and the chest standing on
## the wall axis. All rolls use `_rng`, including which side of that axis wins.
func _place_barrel_cluster(root: Node3D, size: float, quiet_dir: Vector3) -> void:
	var count := _rng.randi_range(2, 3)
	var side := Vector3(-quiet_dir.z, 0.0, quiet_dir.x)
	if _rng.randf() < 0.5:
		side = -side
	var centre := quiet_dir * (size * 0.31) + side * (size * 0.19)
	for i in count:
		var barrel := ExplosiveBarrel.new()
		barrel.name = "RoomBarrel%d" % i
		var offset := (float(i) - float(count - 1) * 0.5) * 1.05
		barrel.position = centre + side * offset
		root.add_child(barrel)


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


## Hands the body back so the caller can put it on the room's `RoomWatch`. It
## used to return nothing, which was fine while nothing in the game knew a room
## could be finished.
func _spawn_foe(root: Node3D, kind: StringName, at: Vector3,
		elite: bool = false, foe_behaviour: StringName = &"") -> Enemy:
	# `position`, not `global_position`: the room root is already placed at its
	# cell centre, and `at` is the scatter offset inside it. Assigning a global
	# here would stack every room's spawns on top of the entrance.
	var e := Enemy.new()
	e.kind = kind
	e.drop_seed = _rng.randi()
	e.level = Run.level
	e.elite = elite
	# Before `add_child`, because `_ready` resolves and latches the behaviour.
	e.behaviour = foe_behaviour
	e.position = at
	root.add_child(e)
	return e


## Ring-scatter with a jitter, rather than uniform random: a uniform scatter puts
## two monsters on top of each other often enough to look like a bug.
func _scatter(i: int, total: int, radius: float) -> Vector3:
	var a := TAU * (float(i) + _rng.randf_range(-0.18, 0.18)) / float(maxi(total, 1))
	var r := radius * _rng.randf_range(0.55, 1.0)
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## Put a structure that hangs off a wall on the map, and hang the triggers that
## take it out of the fog.
##
## Everything behind an anchored door -- both landings, the treasure chamber and
## the vault's three rooms -- was invisible to the minimap and to the MAP screen
## until this existed, because none of it is in `rooms` and `_publish` only walks
## `rooms`. Going through a boss door meant walking off the edge of the map.
##
## `parts` runs outward from the wall, in metres: `_build_landing`'s stub and
## chamber, the vault's link/room/gap/room/gap/room. `root`'s local +Z points out
## through that wall (every builder in this file sets `yaw + PI` for exactly
## that), so one box per part lands without a single per-compass sign -- the same
## trick the geometry above it is authored with.
##
## `face` is `size_of(cell) * 0.5` and not the door's own position: the door is
## set 50 mm back into the reveal (`_wall_spot`) and a schematic that carried
## that would be lying with more precision.
func _publish_annex(root: Node3D, cell: Vector2i, side: StringName,
		height: float, parts: Array) -> void:
	if side == &"":
		return
	var index := Atlas.add_annex(cell, side, size_of(cell) * 0.5, parts)
	var at := 0.0
	for i in parts.size():
		var part: Dictionary = parts[i]
		var run := float(part["len"])
		var area := Area3D.new()
		area.name = "MapTrigger%d" % i
		area.collision_layer = 0
		area.collision_mask = K.L_PLAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# 0.9 across, full length. Across, because a trigger the exact width of
		# the room pokes into the masonry either side; along, because the boxes
		# are butted end to end and a gap between two of them is a stride of
		# corridor that never lights up.
		box.size = Vector3(float(part["wide"]) * 0.9, height, run)
		cs.shape = box
		cs.position = Vector3(0.0, height * 0.5, at + run * 0.5)
		area.add_child(cs)
		root.add_child(area)
		# `slot`, captured by value. `i` is the loop's own variable and a lambda
		# that closed over it would report the last box from every trigger.
		var slot := i
		area.body_entered.connect(func(body: Node3D) -> void:
			if body.is_in_group(&"player"):
				Atlas.see_annex(index, slot))
		at += run


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

	var room_id := StringName(root.name)
	var visited := [cell == entrance or Run.has_visited_room(room_id)]
	# The arrival cell is on the map before the player has taken a step. It is
	# the room they are standing in -- fogging it would mean the first thing the
	# minimap ever shows is a blank frame -- and it is already counted as visited
	# for the depth tally, so this is the same fact said to the same rule.
	if cell == entrance:
		Run.remember_room(room_id)
		Saves.current_room = room_id
		Atlas.see(cell)
	area.body_entered.connect(func(body: Node3D) -> void:
		if not body.is_in_group(&"player"):
			return
		# Current room is positional metadata, not first-entry progression. A
		# revisit still becomes the room the next save should name.
		Saves.current_room = room_id
		# OUTSIDE the `visited` gate. Fog is per-room and the depth tally is
		# per-FIRST-entry, and folding them together would mean a room re-entered
		# after a `close_floor` (a load into a live run) stayed dark forever.
		Atlas.see(cell)
		if visited[0]:
			return
		visited[0] = Run.enter_room(room_id)
		if visited[0]:
			Bus.room_entered.emit(room_id))
