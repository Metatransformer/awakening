extends RefCounted
## **The maze room** — `docs/PUZZLES.md` §5.4, the carve and the one thing that
## reconfigures it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/maze.gd \
##     --out=/tmp/mz/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The carve is a **perfect maze**: every cell reachable from every other,
##      and exactly `rows*cols - 1` corridors — one fewer than the cell count,
##      which is the definition of a spanning tree and therefore of "no loops".
##   B  The room as dealt is **shut**: the prize is not walkable, so the lanterns
##      are not scenery.
##   C  A press moves two gates, the grid and the meshes agree, and **the
##      collider goes with the mesh** — a wall you can see and walk through, or
##      cannot see and cannot pass, is the worst bug this room can have.
##   D  Some press **opens it**, and `opened` fired exactly once.
##   F  And the hero **walks it**, mouth to prize, against the real colliders —
##      which is the beat that catches a gate whose mesh and collider parted ways,
##      or walls that sit off the grid the carve thinks it made.
##   E  **Two hundred rooms, every one solvable through the press rule.** The
##      beat this file exists for, and the direct descendant of `lights_out`'s
##      beat G: the failure this design invites is a layout that is only solvable
##      in a configuration the player cannot build, and it is invisible in every
##      frame.
##
## E is why A–D are not enough. A maze that carves, builds, lights and refuses
## looks exactly like a maze that works.

const SEED := 20260810
const R := 4
const C := 4

var out := ""
var _fails := 0
var _room: Node3D
## Counted from the moment the room is BUILT, not from beat D. The press in beat
## C can be the one that opens the maze, and a listener connected afterwards
## would report zero and call a working signal broken.
var _fired: int = 0
var _hero: Node3D


func run(rig) -> void:
	out = rig.arg("out", "/tmp/mz/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Run.enter(SEED)
	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	if _hero == null:
		_hero = rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D

	await _a_carve(rig)
	_b_dealt_shut()
	await _c_press(rig)
	await _d_opens(rig)
	await _f_walk(rig)
	_e_every_room()

	if _fails == 0:
		print("MAZE ok -- every check passed")
	else:
		print("MAZE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("MAZE ok %s" % label)
	else:
		print("MAZE FAIL %s" % label)
		_fails += 1


# --- A. The carve -------------------------------------------------------------

func _a_carve(rig) -> void:
	var room := MazeRoom.new()
	room.name = "MazeRoom"
	room.rows = R
	room.cols = C
	room.position = Vector3(0.0, 0.02, -2.0)
	rig.scene().add_child(room)
	_room = room
	room.opened.connect(func() -> void: _fired += 1)
	await rig.wait_frames(20)

	var m: Maze = room.maze
	# Every cell reachable from cell 0. A carve that stranded a cell would be a
	# maze with a room nobody can enter, and the recursive backtracker only
	# guarantees it if the stack logic is right.
	var stranded := 0
	for i in R * C:
		if not m.reach(0, i):
			stranded += 1
	_ck("A0 every cell is reachable from every other (%d stranded)" % stranded,
		stranded == 0)

	# Spanning tree: N cells, N-1 corridors, no loops. This is the property that
	# makes it a MAZE rather than an open field with pillars, and counting the
	# holes is the cheapest way to assert it.
	var corridors := 0
	for i in R * C:
		if i % C > 0 and (m.walls[i] & Maze.W) == 0:
			corridors += 1
		if i / C > 0 and (m.walls[i] & Maze.N) == 0:
			corridors += 1
	_ck("A1 and it is a spanning tree -- %d corridors for %d cells, so no loops"
		% [corridors, R * C], corridors == R * C - 1)
	_ck("A2 it planned %d gates" % m.gates.size(), m.gates.size() == MazeRoom.GATES)
	print("MAZE mouth=%d prize=%d gates=%s" % [m.mouth, m.prize, m.gates])

	await _look(rig, room.cell_centre(m.mouth) + room.global_position, 5.5)
	await rig.capture(out.path_join("m_01_dealt.png"))


# --- B. Shut as dealt ---------------------------------------------------------

func _b_dealt_shut() -> void:
	# The whole reason the room is a puzzle and not a corridor. If this passes by
	# accident on one seed, beat E is what catches it.
	_ck("B0 the prize is NOT walkable as dealt -- the lanterns are the lock",
		not bool(_room.call(&"is_open")))
	for i in MazeRoom.GATES:
		var lamp = _room.call(&"lantern", i)
		_ck("B1.%d lantern %d is dark, matching its shut gate" % [i, i],
			lamp != null and not bool(lamp.call(&"is_solved")))


# --- C. One press -------------------------------------------------------------

func _c_press(rig) -> void:
	var m: Maze = _room.get(&"maze")
	var lamp = _room.call(&"lantern", 0)
	if lamp == null:
		_ck("C0 lantern 0 exists", false)
		return
	lamp.call(&"apply_hit", null)
	await rig.wait_frames(10)

	_ck("C0 the pressed gate opened", not bool(m.gates[0]["shut"]))
	_ck("C1 and the next one shut -- the interference, not two light switches",
		bool(m.gates[1 % m.gates.size()]["shut"]))

	# **The mesh and the collider move together.** Checked by looking at the node
	# rather than by trusting `_apply_gates`, because the whole class of bug here
	# is a wall whose two halves disagreed.
	await rig.wait_frames(4)
	var wrong := 0
	for g in m.gates:
		var seg := _room.get_node_or_null(
			NodePath("Gate%d" % m.gates.find(g))) as Node3D
		if seg == null:
			continue
		var shut := bool(g["shut"])
		if seg.visible != shut:
			wrong += 1
		if (int(seg.get(&"collision_layer")) != 0) != shut:
			wrong += 1
	_ck("C2 every gate's mesh AND collider match the grid (%d wrong)" % wrong,
		wrong == 0)

	await _look(rig, _room.call(&"mouth_point") + _room.global_position, 5.5)
	await rig.capture(out.path_join("m_02_pressed.png"))


# --- D. It opens --------------------------------------------------------------

func _d_opens(rig) -> void:
	var m: Maze = _room.get(&"maze")
	# Try every lantern in turn until the maze is walkable. That IS the player's
	# search -- there is no solver here and there should not be one, because the
	# set of reachable configurations is small on purpose.
	var pressed := 0
	for i in m.gates.size() * 2:
		if bool(_room.call(&"is_open")):
			break
		var lamp = _room.call(&"lantern", i % m.gates.size())
		lamp.call(&"apply_hit", null)
		pressed += 1
		await rig.wait_seconds(0.4)
	_ck("D0 some press opens the way to the prize (%d presses)" % pressed,
		bool(_room.call(&"is_open")))
	# Once. A signal that fired on every press after the first would put a chest
	# on the floor per swing, and §5.2's loot rule hangs on this edge.
	_ck("D1 and `opened` fired exactly once across the whole run (%d)" % _fired,
		_fired == 1)

	await _look(rig, _room.call(&"mouth_point") + _room.global_position, 5.5)
	await rig.capture(out.path_join("m_03_open.png"))


# --- F. Walk it ---------------------------------------------------------------

## **The proof that no frame can give.** A 3.6 m corridor and a follow camera
## cannot photograph a wall moving — every close-up puts the lens inside masonry,
## and the first pass of this director shot exactly that. So instead of looking at
## the gate, the hero WALKS from the mouth to the prize, cell by cell, through
## `move_and_collide` against the real colliders.
##
## That is strictly stronger than the picture would have been. It fails if a gate
## left its collider standing while its mesh vanished, if the walls sit off the
## grid line, if a corridor is too narrow for the hero's capsule, or if the
## carve's idea of "open" and the geometry's disagree — none of which any of the
## integer beats above can see, and the last of which is the whole risk of
## building a grid and a room out of the same numbers twice.
func _f_walk(rig) -> void:
	var m: Maze = _room.get(&"maze")
	if _hero == null:
		_ck("F0 there is a hero to walk", false)
		return
	var route := _route(m)
	_ck("F0 the open maze has a route, mouth to prize (%d cells)" % route.size(),
		route.size() > 1)
	if route.size() < 2:
		return

	var body := _hero as CharacterBody3D
	_hero.global_position = _room.call(&"cell_centre", route[0]) \
		+ _room.global_position + Vector3(0.0, 0.1, 0.0)
	await rig.wait_frames(4)

	var stuck := -1
	for step in range(1, route.size()):
		var target: Vector3 = _room.call(&"cell_centre", route[step]) \
			+ _room.global_position
		var arrived := false
		for _i in 90:
			var to := target - _hero.global_position
			to.y = 0.0
			if to.length() < 0.35:
				arrived = true
				break
			# Small steps through the physics server, not a teleport. A teleport
			# would walk through every wall in the room and report success.
			body.move_and_collide(to.normalized() * 0.12)
			await rig.wait_frames(1)
		if not arrived:
			stuck = step
			break
	_ck("F1 and the hero WALKS it, through the real colliders (stuck at %d)"
		% stuck, stuck < 0)

	await rig.wait_frames(10)
	await rig.capture(out.path_join("m_04_at_the_prize.png"))


## The cells from mouth to prize in the CURRENT configuration, by breadth-first
## search over the same `blocked` the room was built from.
func _route(m: Maze) -> Array[int]:
	var shut := m.shut_now()
	var prev := {m.mouth: -1}
	var queue: Array[int] = [m.mouth]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == m.prize:
			var out_r: Array[int] = []
			var walk_i := at
			while walk_i >= 0:
				out_r.push_front(walk_i)
				walk_i = int(prev[walk_i])
			return out_r
		for n in [at - m.cols, at + m.cols, at - 1, at + 1]:
			if n < 0 or n >= m.rows * m.cols or prev.has(n):
				continue
			# Row wrap is not adjacency. `blocked` answers true for a non-adjacent
			# pair anyway, but the guard keeps the intent visible.
			if absi(n % m.cols - at % m.cols) > 1:
				continue
			if m.blocked(at, n, shut):
				continue
			prev[n] = at
			queue.append(n)
	return []


# --- E. Every room this floor can deal ----------------------------------------

## **Two hundred rooms, each one checked against the press rule.**
##
## The failure this design invites is not "the maze is disconnected" — the carve
## cannot do that — it is a gate layout whose only solution needs two gates open
## at once, which `MazeRoom._on_pressed` can never produce. A room like that
## generates, builds, lights, and refuses forever, and every frame of it looks
## correct.
##
## Run on the grid alone. Standing two hundred mazes up would take minutes to
## prove a sentence about integers.
func _e_every_room() -> void:
	var bad_shut := 0
	var bad_open := 0
	var refused := 0
	for i in 200:
		Run.enter(SEED + i * 7919)
		var m := Maze.new()
		m.carve(Run.rng, R, C)
		if not m.plan(Run.rng, MazeRoom.GATES):
			refused += 1
			continue
		# As dealt it must be shut...
		if m.solved():
			bad_shut += 1
		# ...and one of the configurations a press can build must open it.
		var any := false
		for g in m.gates.size():
			for j in m.gates.size():
				m.set_gate(j, j != g)
			if m.solved():
				any = true
				break
		if not any:
			bad_open += 1
	_ck("E0 no dealt room is already open (%d bad)" % bad_shut, bad_shut == 0)
	_ck("E1 every dealt room opens through a reachable configuration (%d bad)"
		% bad_open, bad_open == 0)
	# A refusal is legal -- `Maze.plan` builds a plain maze rather than a broken
	# one -- but a floor where it happens often is a floor of corridors, and that
	# is a design fact worth printing rather than hiding.
	print("MAZE %d/200 layouts refused (built plain)" % refused)
	_ck("E2 and it refuses rarely enough to be a puzzle room (%d/200)" % refused,
		refused < 40)


# --- Camera -------------------------------------------------------------------

func _look(rig, at: Vector3, back: float) -> void:
	if _hero == null:
		return
	# Standing IN the maze, looking down a corridor -- the view the player has.
	# The follow camera rides the hero and there is no second camera in this
	# project; a director that added one would be shooting a frame nobody ever
	# sees. An overhead of the layout is what the minimap is for.
	var stop := at + Vector3(0.0, 0.0, back)
	stop.y = 0.15
	_hero.global_position = stop
	var to := K.flat(at - _hero.global_position)
	if to != Vector3.ZERO:
		_hero.facing_yaw = atan2(to.x, to.z)
		_hero.rotation.y = _hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
