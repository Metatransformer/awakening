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
## (the maze takes enemies later, `docs/PUZZLES.md` §5.4), and a 4x4 maze has to
## FIT inside a 16 m dungeon room with a walkway round it. 3.1 leaves ~2.6 m of
## clear corridor against a 1.65 m hero, and 12.4 m across the room. 3.6 was the
## first number here and it did not fit -- `Dungeon.pick_maze_cell` refused every
## room on the floor, which is the correct failure but not a shipped room.
const CELL := 3.1
const WALL_H := 4.0

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

## Cells. Odd-ish and small — this is a room inside a dungeon room, not a level.
@export var rows: int = 5
@export var cols: int = 5

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
			# The outer rim is carved through in exactly one place, the mouth, and
			# that hole is cut here rather than in the grid: the grid's job is
			# connectivity between cells and the rim is not between anything.
			if _is_rim_hole(i, bit):
				continue
			var seg := _wall(i, bit)
			if gate_keys.has(key):
				seg.name = "Gate%d" % int(gate_keys[key])
				_segments[key] = seg
			add_child(seg)

	_apply_gates()


## The mouth's own north wall is the doorway. Every other rim wall stands.
func _is_rim_hole(i: int, bit: int) -> bool:
	return bit == Maze.N and i == maze.mouth + maze.cols


func _wall(i: int, bit: int) -> Node3D:
	var horizontal := bit == Maze.N
	var here := cell_centre(i)
	# The wall sits on the cell's own face, half a cell out along the axis it
	# blocks. Derived from `cell_centre` rather than restated, so a change to
	# `CELL` cannot leave the walls and the grid disagreeing about where a
	# corridor is.
	var at := here + (Vector3(0.0, 0.0, -CELL * 0.5) if horizontal
		else Vector3(-CELL * 0.5, 0.0, 0.0))

	var w := KIT_WALL.instantiate()
	w.name = "W_%d_%d" % [i, bit]
	# One cell plus the thickness, so the corners close. A maze with hairline gaps
	# at every junction is a maze the player tries to squeeze through.
	w.length = CELL + float(w.thickness)
	w.height = WALL_H
	# Off the cell and the bit, so the same wall gets the same stones every time
	# the floor is rebuilt inside a run.
	w.rng_seed = i * 7 + bit
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
	for i in maze.gates.size():
		var lamp := PuzzleAtoms.make(PuzzleAtoms.LANTERN, &"") as Lantern
		if lamp == null:
			continue
		lamp.name = "MazeLamp%d" % i
		lamp.index = i
		# Lit means the gate it owns is OPEN. The dealt board is every gate shut,
		# so they all start dark and the room reads as "nothing is on yet".
		lamp.starts_lit = false
		lamp.position = Vector3(float(i) * 2.4 - span * 0.5, 0.0,
			mouth_point().z + 3.0)
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
