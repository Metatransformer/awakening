class_name MazeRoom
extends Node3D
## The maze with pixels: `Maze`'s grid stood up as wall segments, with a lantern
## per reconfigurable gate. `docs/PUZZLES.md` §5.4.
##
## ## What the player does
##
## Walk in. The minimap shows a maze, and the way to the prize is walled off. The
## lanterns are out in the open near the mouth — strike one and **a wall
## somewhere in the maze lifts while another drops**. The room is a puzzle
## because the map cannot answer it: the map shows the maze that is, and the
## question is which maze to make.
##
## ## Why the lantern and not a new prop
##
## The kit already has an atom that toggles (`Lantern`, `docs/PUZZLES.md` §2) and
## a combinator for atoms that interfere with each other (§3, *couple*). A maze
## switch would be a tenth atom that did what the ninth already does, and §8's
## count is a ceiling that only stays a ceiling if the answer to "this is nearly
## the same as X" is to use X.
##
## The one thing this file does NOT do is gate a door on the lanterns. There is
## no `PuzzleGate` here and the lanterns carry no `puzzle_id`: the reward is on
## the far side of the maze and the lock is the *geometry*. A gate as well would
## be asking the player to solve it twice.

## Metres per maze cell. Two things set this and they pull opposite ways: a
## corridor you cannot swing a sword in is a corridor the sword does not work in
## (the maze takes enemies later, `docs/PUZZLES.md` §5.4), and the grid has to FIT
## inside its dungeon room with the lantern apron and a walkway round it.
##
## **3.1 x 1.3 = 4.03**, and the 30% is the point rather than a rounding: at 3.1 a
## corridor was ~2.6 m of clear floor against a 1.65 m hero, which is a hedge maze
## -- the walls are inside the camera's boom the whole time and every cell is a
## turn. 4.03 leaves ~3.5 m, so a corridor reads as a corridor and the walk
## between decisions is long enough that the layout registers as one.
##
## It does NOT fit a 16 m room any more, and that is deliberate: the maze claims a
## room built wider (`Dungeon.MAZE_ROOM`). 3.6 was the first number ever tried
## here and it was backed out because it did not fit the ordinary room; the answer
## this time was to size the room to the maze rather than the maze to the room.
const CELL := 4.03
const WALL_H := 4.0

## **The clear ground the maze needs on the mouth side, inside the dungeon room.**
## The lantern row stands in it, and the hero has to be able to walk up to a
## lantern and swing at it without standing in the doorway.
##
## This constant exists because it was once a bare `+ 3.0` inside
## `_build_lanterns` with nothing anywhere checking that the room had 3 m to give.
## It did not: a 16 m room puts its south wall at z = 8.0 and the lanterns landed
## at z = 9.2, **a metre past the masonry and off the floor slab**. The room
## generated, carved, lit and photographed perfectly, the director's own beats all
## passed -- they press the lanterns by reference, and the fixture room they run in
## has no walls to be outside of -- and the puzzle could not be pressed by a
## player at all. The chest hung on `opened`, so it never landed, and the symptom
## on the minimap was a chest marker in a room with no chest in it.
##
## The maze is centred in its room, so an apron on the mouth side is an equal band
## of floor on the far side whether it is wanted or not; `fits` charges for both
## rather than pretending otherwise.
const APRON := 3.0

## And the band on the other two sides, which only has to be walkable: a room's
## door can open onto any of them, and a maze pressed against a doorway is a
## corridor the floor's critical path dead-ends in.
const WALKWAY := 1.6

## The dungeon's own wall, not a box. `KitWall` is a `StaticBody3D` already, with
## the masonry, the plinth and the collider the rest of the floor is built from --
## a maze of untextured slabs reads as programmer geometry standing in a real
## room, and the first frame of this room showed exactly that.
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")

## How many walls the lanterns move. Two is the shipped number and it is a
## deliberate floor rather than a tuning default: with one gate the room is a
## light switch, and the interference that makes it a puzzle needs a second wall
## to interfere with.
const GATES := 2

## Cells. Still a room inside a dungeon room and not a level — but the room it
## sits in is `Dungeon.MAZE_ROOM` wide now, so the grid is square rather than the
## 3x4 letterbox the 16 m room forced. `Dungeon.MAZE_ROWS/COLS` is the number the
## generator actually uses; these are the defaults a hand-placed one gets.
@export var rows: int = 5
@export var cols: int = 5


## **Will a maze of this shape fit in a room this wide, apron and all?**
##
## Asked here rather than restated at the call site, which is the whole point:
## `Dungeon.pick_maze_cell` used to check `cols * CELL + 2.0` — the maze's own
## width and a token walkway — and that arithmetic knew nothing about the lantern
## apron, so it happily chose a room the lanterns could not stand in. One place
## owns the footprint now, and it is the file that lays the room out.
static func fits(size: float, r: int, c: int) -> bool:
	return size >= maxf(float(r) * CELL + APRON * 2.0,
		float(c) * CELL + WALKWAY * 2.0)

## Set before `_ready` to deal off a run's own stream. Left null it makes its own
## from `Run.rng`, so a replayed seed gives the same maze.
var rng: RandomNumberGenerator

var maze: Maze
var _segments: Dictionary = {}      ## "cell:bit" -> Node3D
var _lamps: Array[Lantern] = []

## The maze opened up. Fires once, on the press that first connects the mouth to
## the prize — `Dungeon` hangs the loot on this (§5.2's rule that a puzzle pays).
signal opened


func _ready() -> void:
	add_to_group(&"maze_room")
	if rng == null:
		rng = Run.rng
	maze = Maze.new()
	maze.carve(rng, rows, cols)
	# A grid too small or too tangled to admit a legal gate layout builds as a
	# plain maze rather than as a broken one. `Maze.plan` is the half that knows
	# what "legal" means and it is the only place that decision is made.
	var ok := maze.plan(rng, GATES)
	# No floor slab: this room stands INSIDE a dungeon room that already has one,
	# and a second slab 8 cm up is a lip the hero catches on.
	_build_walls()
	if ok:
		_build_lanterns()
	else:
		push_warning("maze_room: no legal gate layout at %dx%d -- plain maze" %
			[rows, cols])


# --- Geometry -----------------------------------------------------------------

## The centre of a cell, in this node's local space. The grid's origin cell sits
## at the north-west, and +Z runs south, so the mouth comes out at +Z — the side
## the player arrives from.
func cell_centre(i: int) -> Vector3:
	var r := i / maze.cols
	var c := i % maze.cols
	return Vector3(
		(float(c) - float(maze.cols - 1) * 0.5) * CELL,
		0.0,
		(float(r) - float(maze.rows - 1) * 0.5) * CELL)


## Where the player walks in, and where the reward stands.
func mouth_point() -> Vector3:
	return cell_centre(maze.mouth) + Vector3(0.0, 0.0, CELL * 0.5)


func prize_point() -> Vector3:
	return cell_centre(maze.prize)


## One `KitWall` per standing wall. Not a single merged mesh: a gate has to be
## able to disappear on its own, and the collider has to go with it — a maze
## whose walls vanish visually and still stop the hero is the worst possible
## version of this room.
func _build_walls() -> void:
	var gate_keys := {}
	for i in maze.gates.size():
		gate_keys["%d:%d" % [maze.gates[i]["cell"], maze.gates[i]["bit"]]] = i

	for i in maze.rows * maze.cols:
		for bit: int in [Maze.N, Maze.W]:
			var key := "%d:%d" % [i, bit]
			var standing := (maze.walls[i] & bit) != 0 or gate_keys.has(key)
			if not standing:
				continue
			var seg := _wall(i, bit)
			if gate_keys.has(key):
				seg.name = "Gate%d" % int(gate_keys[key])
				_segments[key] = seg
			add_child(seg)

	_build_rim()
	_apply_gates()


## **The south and east rim, which the grid has nowhere to put.**
##
## Every wall in `Maze.walls` is some cell's north or west face, which covers the
## interior exactly once and is why that scheme was chosen. What it cannot express
## is the two far edges: the grid's south edge is the north face of a row that does
## not exist and its east edge the west face of a column that does not exist.
## Neither has a byte to live in, so neither was ever built, and **the maze shipped
## standing open along two of its four sides** — the player could step in anywhere
## along the bottom or the right, and where the carve had put the prize in the last
## row or the last column they could walk straight onto it with the lanterns still
## dark and nothing there, because the chest hangs on `opened`.
##
## `Maze.reach` never modelled those holes — `_neighbours` only ever steps to a
## cell inside the grid — so the solvability proof in `Maze.plan` was correct about
## a room that was not the one being built. This pass makes the geometry the room
## the proof is about.
func _build_rim() -> void:
	# The mouth is the one hole in the rim, and it is cut here rather than in the
	# grid: the grid's job is connectivity BETWEEN cells, and the rim is not
	# between anything.
	for c in maze.cols:
		var i := (maze.rows - 1) * maze.cols + c
		if i == maze.mouth:
			continue
		add_child(_wall(i, Maze.N, true))
	for r in maze.rows:
		add_child(_wall(r * maze.cols + maze.cols - 1, Maze.W, true))


## One wall segment on a cell's face. `far` picks which of the two faces on that
## axis: the near one (the cell's own north or west, the only two it owns) or the
## far one, which is how `_build_rim` reaches the south and east edges no cell has
## a bit for.
func _wall(i: int, bit: int, far: bool = false) -> Node3D:
	var horizontal := bit == Maze.N
	var here := cell_centre(i)
	# The wall sits on the cell's face, half a cell out along the axis it blocks.
	# Derived from `cell_centre` rather than restated, so a change to `CELL` cannot
	# leave the walls and the grid disagreeing about where a corridor is.
	var s := 1.0 if far else -1.0
	var at := here + (Vector3(0.0, 0.0, s * CELL * 0.5) if horizontal
		else Vector3(s * CELL * 0.5, 0.0, 0.0))

	var w := KIT_WALL.instantiate()
	w.name = "W_%d_%d%s" % [i, bit, "f" if far else ""]
	# One cell plus the thickness, so the corners close. A maze with hairline gaps
	# at every junction is a maze the player tries to squeeze through.
	w.length = CELL + float(w.thickness)
	w.height = WALL_H
	# Off the cell and the bit, so the same wall gets the same stones every time
	# the floor is rebuilt inside a run. The far faces are salted apart from the
	# near ones or a rim segment would be a stone-for-stone twin of the interior
	# wall on the other side of its cell.
	w.rng_seed = i * 7 + bit + (1024 if far else 0)
	# `KitWall` builds from -thickness to 0 in its own Z, so the finished face is
	# at the origin and the mass is behind it. Half a thickness forward puts the
	# wall centred on the grid line instead of hanging off one side of it.
	#
	# `transform`, not `global_transform`: the node is not in the tree yet, and
	# `global_transform` on a detached node logs an error and hands back identity.
	w.rotation.y = 0.0 if horizontal else PI * 0.5
	w.position = at + w.transform.basis.z * (float(w.thickness) * 0.5)
	return w


# --- The verb -----------------------------------------------------------------

## The lanterns stand OUTSIDE the maze, in a row by the mouth. Inside would be
## the version of this room where you have to walk the maze to change the maze,
## which sounds better and plays as a slog: every press would cost a round trip
## through a layout you already read.
func _build_lanterns() -> void:
	var span := float(maze.gates.size() - 1) * 2.4
	# **Half way across the apron**, not a flat three metres past the mouth. The
	# old number put them through the room's south wall on every real floor; see
	# `APRON`. Half the apron is the one depth that cannot: the apron is by
	# definition floor the room has, and the middle of it is clear of both the
	# maze's rim and the masonry.
	var z := mouth_point().z + APRON * 0.5
	for i in maze.gates.size():
		var lamp := PuzzleAtoms.make(PuzzleAtoms.LANTERN, &"") as Lantern
		if lamp == null:
			continue
		lamp.name = "MazeLamp%d" % i
		lamp.index = i
		# Lit means the gate it owns is OPEN. The dealt board is every gate shut,
		# so they all start dark and the room reads as "nothing is on yet".
		lamp.starts_lit = false
		lamp.position = Vector3(float(i) * 2.4 - span * 0.5, 0.0, z)
		add_child(lamp)
		lamp.pressed.connect(_on_pressed.bind(i))
		_lamps.append(lamp)


## **The interference.** Lantern `i` opens its own gate and shuts the next one
## along — which is what stops the room from being two independent light
## switches. With N gates and one press moving two of them, the player has to
## think about the order, exactly as the lights-out grid asks them to.
##
## The lantern does not toggle itself here (its `press()` self-toggle only fires
## with nothing connected, see `lantern.gd`), so this function owns every state
## change and there is one place to read.
func _on_pressed(_lamp: Lantern, i: int) -> void:
	var was := maze.solved()
	var next := (i + 1) % maze.gates.size()
	maze.set_gate(i, false)
	if next != i:
		maze.set_gate(next, true)
	for j in _lamps.size():
		_lamps[j].set_lit(not bool(maze.gates[j]["shut"]))
	_apply_gates()
	if not was and maze.solved():
		Bus.request_sfx.emit(&"glint_bell", global_position)
		opened.emit()


## Push the grid's state onto the meshes. One direction only: the grid decides,
## the walls follow. A gate that was toggled by writing to the node and read back
## off `visible` would be a second source of truth, and the day they disagreed
## the symptom would be a wall you can see and walk through.
func _apply_gates() -> void:
	for g in maze.gates:
		var seg := _segments.get("%d:%d" % [g["cell"], g["bit"]]) as Node3D
		if seg == null:
			continue
		var shut := bool(g["shut"])
		seg.visible = shut
		# The collider goes with the mesh, deferred because this can be reached
		# from inside a physics callback and Godot will not take a shape change
		# there.
		seg.set_deferred(&"collision_layer", K.L_WORLD if shut else 0)


# --- What a director asks it --------------------------------------------------

func lantern(i: int) -> Lantern:
	return _lamps[i] if i >= 0 and i < _lamps.size() else null


func is_open() -> bool:
	return maze != null and maze.solved()
