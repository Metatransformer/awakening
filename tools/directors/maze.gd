extends RefCounted
## **The maze room** — `docs/PUZZLES.md` §5.4, the carve and the one thing that
## reconfigures it.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_maze_test.tscn \
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
## Match `Dungeon.MAZE_ROWS/COLS`. Square, because the maze's room is built to the
## maze (`Dungeon.MAZE_ROOM`) rather than the maze squeezed into a 16 m room --
## the apron still comes out of the depth, there is just depth to pay it with.
const R := 5
const C := 5

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

	# `--floor` runs beat G only: it needs the dungeon scene, and the fixture beats
	# need a room with nothing in it. One director, two hosts, chosen explicitly
	# rather than by sniffing the scene name.
	# `shoot.gd` gives a bare `--floor` the value "1". Compared as a string: `bool`
	# has no String constructor in GDScript and the call is a runtime error, not a
	# parse one -- so it survives every check that is not a run.
	if rig.arg("floor", "") != "":
		await _g_on_a_floor(rig)
		if _fails == 0:
			print("MAZE ok -- every check passed")
		else:
			print("MAZE FAIL -- %d check(s) failed" % _fails)
		return

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


## **The fixture has to be as big as the room the generator builds, and empty.**
##
## This used to be a function that took the proving ground's furniture out — a
## raised ledge, two pillars, two pushable blocks, two braziers — because a
## 12.4 x 9.3 m maze had nowhere in that showroom to stand clear of all of it, and
## beat F's walk cannot tell a maze wall it wedged against from a brazier: it just
## reports "stuck", which is a false failure and, worse, would mask a true one.
##
## Clearing is not enough any more. A 5x5 maze is 20.15 m across and the proving
## ground's interior is 20, so the rim would have stood in the fixture's own walls
## and the lantern apron would have put both lanterns a metre and a half BEHIND the
## south wall — the exact geometry `MazeRoom.APRON` documents as having shipped
## once, reproduced inside the instrument meant to catch it, and invisible because
## the fixture beats press the lanterns by reference. So the maze has its own
## fixture now (`scenes/rooms/_maze_test.tscn`, 27 m square = `Dungeon.MAZE_ROOM`)
## and this only checks it is the one running: standing this maze up in a 22 m
## showroom is a run whose every beat is a lie.
func _check_the_fixture(rig) -> void:
	# Untyped: `rig` is untyped, so everything off it is a Variant (CLAUDE.md §3).
	var chamber = rig.scene().get_node_or_null(^"Chamber/Floor")
	var span := 0.0
	if chamber != null:
		span = float(chamber.get(&"size").x)
	# The room the maze needs, asked of `MazeRoom` rather than restated -- the same
	# rule the generator's `pick_maze_cell` follows.
	var want := MazeRoom.CELL * float(maxi(R, C)) + MazeRoom.APRON * 2.0
	_ck("A- the fixture is a chamber the maze fits in (%.1f m of %.1f m needed)"
		% [span, want], span >= want)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("MAZE ok %s" % label)
	else:
		print("MAZE FAIL %s" % label)
		_fails += 1


# --- A. The carve -------------------------------------------------------------

func _a_carve(rig) -> void:
	_check_the_fixture(rig)
	var room := MazeRoom.new()
	room.name = "MazeRoom"
	room.rows = R
	room.cols = C
	# Centred on the chamber, exactly as `Dungeon.place_maze` centres it in a room.
	room.position = Vector3(0.0, 0.02, 0.0)
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
	_a3_rim(room, m)

	await _stand_in_the_apron(rig, room)
	await rig.capture(out.path_join("m_01_dealt.png"))


## **The rim is solid, on all four sides, with one hole in it.**
##
## Measured off the WALL NODES' positions, not off `Maze.walls`, and that is the
## entire point of the beat. The grid stores two bits per cell — a north and a
## west — so its south and east edges have no byte to live in, and for a while the
## room simply did not build them: `Maze.reach` proved a sealed maze while
## `_build_walls` stood up one that was open along its whole bottom and right-hand
## side. Every integer beat in this file passed, because every integer beat asks
## the grid. This one asks the geometry.
func _a3_rim(room: Node3D, m: Maze) -> void:
	var half_x := float(m.cols) * MazeRoom.CELL * 0.5
	var half_z := float(m.rows) * MazeRoom.CELL * 0.5
	var count := {"n": 0, "s": 0, "w": 0, "e": 0}
	# A wall standing ON an edge line, within a wall's thickness of it. Cell
	# centres are a whole cell in from those lines, so nothing interior can be
	# miscounted.
	for child in room.get_children():
		var n3 := child as Node3D
		if n3 == null or not n3.name.begins_with("W_"):
			continue
		var p := n3.position
		if absf(p.z + half_z) < 0.5:
			count["n"] += 1
		elif absf(p.z - half_z) < 0.5:
			count["s"] += 1
		elif absf(p.x + half_x) < 0.5:
			count["w"] += 1
		elif absf(p.x - half_x) < 0.5:
			count["e"] += 1
	_ck("A3 the rim is solid on all four sides -- N%d S%d W%d E%d, of %d/%d"
		% [count["n"], count["s"], count["w"], count["e"], m.cols, m.rows],
		count["n"] == m.cols and count["s"] == m.cols - 1
			and count["w"] == m.rows and count["e"] == m.rows)
	# ...and exactly one hole, at the mouth. `s` is one short above; this says the
	# short one is the right one.
	var mouth_x: float = room.call(&"cell_centre", m.mouth).x
	var plugged := false
	for child in room.get_children():
		var n3 := child as Node3D
		if n3 == null or not n3.name.begins_with("W_"):
			continue
		if absf(n3.position.z - half_z) < 0.5 and absf(n3.position.x - mouth_x) < 0.5:
			plugged = true
	_ck("A4 and the one hole in it is the mouth", not plugged)


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

	await _stand_in_the_apron(rig, _room)
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

	# Standing in the mouth cell looking down the corridor that just opened, which
	# is the one frame the apron shot cannot give: the apron shows the lanterns and
	# the rim, and this shows what pressing them DID.
	var route := _route(m)
	if route.size() > 1:
		await _look_from(rig, _room.call(&"cell_centre", route[0]),
			_room.call(&"cell_centre", route[1]))
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

## Stand the hero on one cell and face them at another, both in the maze's local
## space. The follow camera rides the hero and there is no second camera in this
## project; a director that added one would be shooting a frame nobody ever sees.
## An overhead of the layout is what the minimap is for.
##
## **Two cells and not "a cell and a distance back".** It used to take a metre
## count and stand the hero that far along +Z, which put the lens outside the room
## the moment the maze grew: the mouth is now 10.07 m out from the centre and the
## apron behind it is 3.4 m, against a 4.13 m boom (`K.CAM_DIST_MAX`). Every shot
## south of the mouth collapses to `hard_min_distance` and photographs the inside
## of the hero's hood. Standing on a cell can't: every cell is inside the maze.
func _look_from(rig, stand: Vector3, at: Vector3) -> void:
	if _hero == null:
		return
	var stop := stand + _room.global_position
	stop.y = 0.15
	_hero.global_position = stop
	var to := K.flat(at + _room.global_position - _hero.global_position)
	if to != Vector3.ZERO:
		_hero.facing_yaw = atan2(to.x, to.z)
		_hero.rotation.y = _hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)


# --- G. On a real floor -------------------------------------------------------

## **A floor that generates one.** Everything above runs on a maze the director
## stood up by hand; this is the beat that says `Dungeon` places one, in a room
## that had nothing else in it, with its chest hidden until the way opens.
##
## Run separately, on the dungeon scene:
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/maze.gd --floor \
##     --out=/tmp/mzf/x.png --warmup=60
## **The beat this director did not have, and the bug it did not catch.**
##
## G4 above presses the lanterns by holding a reference to them. That proves the
## wiring and nothing about the world: for as long as this room has existed, both
## lanterns spawned at `mouth_point().z + 3.0`, which on every 16 m room on every
## floor is **1.2 m past the south wall** — off the floor slab, inside the
## masonry, unreachable. G4 passed anyway, every time, and so did the whole
## fixture half of this file, because `_atom_test.tscn` is a room with no walls to
## be outside of. What shipped was a chest marker on the minimap over a room whose
## puzzle could not be touched.
##
## So this asks two things a reference-press cannot: is the lantern inside the
## room's own footprint, and can the **hero walk to it** from the mouth and land a
## blow.
func _g_lanterns_are_reachable(rig, dungeon, room: Node3D, cell) -> void:
	var half: float = float(dungeon.call(&"size_of", cell)) * 0.5
	var origin: Vector3 = room.get_parent().global_position
	var outside := 0
	for i in MazeRoom.GATES:
		var lamp = room.call(&"lantern", i)
		if lamp == null:
			outside += 1
			continue
		var at: Vector3 = lamp.global_position - origin
		if absf(at.x) > half or absf(at.z) > half:
			outside += 1
			print("MAZE lantern %d at room-local %s, room half %.2f" % [i, at, half])
	_ck("G3a every lantern stands INSIDE its room, on the floor (%d outside)"
		% outside, outside == 0)

	# And the hero reaches one. Walked, not teleported -- a lantern half inside the
	# wall is inside the room's footprint and still unhittable.
	#
	# From the far end of the apron, not from the mouth: the mouth is a metre from
	# lantern 1, so a walk that started there would pass whatever the lanterns'
	# positions were. Crossing the room is the claim worth making.
	var lamp0 = room.call(&"lantern", 0)
	if lamp0 == null or _hero == null:
		_ck("G3b the hero can walk to a lantern and hit it", false)
		return
	var z: float = float(room.call(&"mouth_point").z) + MazeRoom.APRON * 0.5
	_hero.global_position = room.global_position + Vector3(-5.0, 0.15, z)
	await rig.wait_frames(4)
	var target: Vector3 = lamp0.global_position
	var near := false
	for _i in 300:
		var to := target - _hero.global_position
		to.y = 0.0
		# A lantern is a body on a post; stop at arm's length rather than trying to
		# stand inside it. `Lantern.CAGE_R` plus a hero is about a metre.
		if to.length() < 1.1:
			near = true
			break
		_step(to.normalized() * 0.12)
		await rig.wait_frames(1)
	_ck("G3b the hero WALKS the room to a lantern (gap %.2f m)"
		% (_hero.global_position - target).length(), near)


## One step against the real colliders, sliding off whatever it grazes.
##
## `move_and_collide` alone stops dead on contact, so a hero who clipped a lantern
## post on the way past another one simply stood there for the rest of the beat
## and the director reported the room unreachable. Sliding is what a player does
## with a stick in their hand, so it is what the proof should do.
func _step(motion: Vector3) -> void:
	var body := _hero as CharacterBody3D
	var hit := body.move_and_collide(motion)
	if hit == null:
		return
	var left := motion.slide(hit.get_normal())
	left.y = 0.0
	if left.length() > 0.001:
		body.move_and_collide(left)


func _g_on_a_floor(rig) -> void:
	# Untyped: `rig` is untyped, so everything off it is a Variant (CLAUDE.md §3).
	var dungeon = rig.scene().get_tree().get_first_node_in_group(&"dungeon")
	if dungeon == null:
		dungeon = rig.scene().get_node_or_null(^"Dungeon")
	if dungeon == null:
		_ck("G0 there is a dungeon to look in", false)
		return
	var found: Node3D = null
	for n in rig.scene().get_tree().get_nodes_in_group(&"maze_room"):
		found = n as Node3D
		break
	if found == null:
		# The roll said no on this seed, which is legal. Place one through the
		# dungeon's OWN placer rather than skipping the beat -- a director that
		# quietly passed on the unlucky seeds would be proving `maze_chance` and
		# nothing else.
		var pick = dungeon.call(&"pick_maze_cell", true)
		if pick == null:
			_ck("G0 the floor has a room a maze fits in", false)
			return
		dungeon.call(&"place_maze", pick)
		await rig.wait_frames(20)
		for n in rig.scene().get_tree().get_nodes_in_group(&"maze_room"):
			found = n as Node3D
			break
	if found == null:
		_ck("G0 the floor placed a maze", false)
		return
	_ck("G0 the floor placed a maze", true)
	# Which room it landed in, read back off the dungeon rather than remembered:
	# on a lucky seed the maze was placed by `_populate` and this beat never saw
	# the cell go by.
	var cell = null
	for c: Vector2i in dungeon.rooms:
		if dungeon.rooms[c].get("node") == found.get_parent():
			cell = c
			break
	if cell == null:
		_ck("G0a and the dungeon knows which room it is in", false)
		return
	_ck("G1 shut as generated", not bool(found.call(&"is_open")))
	# **The room is built to the maze, and the maze is cut to the room.** Printed
	# and then asserted, because the interesting case is the one that shrank: a
	# room next door to a 30 m boss chamber cannot be 27 m, so `Dungeon._maze_grid`
	# hands back fewer cells instead of the floor handing back no maze. The failure
	# that shape invites is a grid one size too big for the room it was cut for --
	# which is the lantern-in-the-masonry bug again, arrived at by arithmetic.
	var fm: Maze = found.get(&"maze")
	var room_w: float = float(dungeon.call(&"size_of", cell))
	print("MAZE room %s is %.1f m wide, grid %dx%d, cell %.2f m"
		% [cell, room_w, fm.rows, fm.cols, MazeRoom.CELL])
	_ck("G1a and the room it is in is wide enough for the grid it got",
		MazeRoom.fits(room_w, fm.rows, fm.cols))
	_ck("G1b with enough cells to be a puzzle (%d)" % (fm.rows * fm.cols),
		fm.rows * fm.cols >= 9)
	var chest = found.get_parent().get_node_or_null(^"MazeChest")
	_ck("G2 with a chest standing hidden at the prize",
		chest != null and not chest.visible)
	# The room it landed in has to be one nothing else wanted. An anchor buried
	# in masonry is a floor that cannot be finished.
	var siblings := 0
	for c in found.get_parent().get_children():
		if c is PuzzleGate or c is LockedDoor:
			siblings += 1
	_ck("G3 in a room with no door anchor in it (%d)" % siblings, siblings == 0)

	# **The arrival frame, shot first.** This is the picture that should have shown
	# the bug and never got taken: the room as the player walks into it, standing
	# in the apron looking north at the mouth, with the two lanterns in front of
	# them. It used to be shot last and from +11 m, which on a 16 m room is three
	# metres outside the south wall -- the lens inside the masonry, the frame
	# black, and a floor's worth of unreachable lanterns invisible in it. Shot
	# before the walking beats as well, because the floor has bodies on it and a
	# goblin finding the hero mid-beat turns the last frame into a death screen.
	await _stand_in_the_apron(rig, found)
	await rig.capture(out.path_join("m_05_on_a_floor.png"))

	await _g_lanterns_are_reachable(rig, dungeon, found, cell)

	var lamp = found.call(&"lantern", 0)
	if lamp != null:
		for _i in 4:
			if bool(found.call(&"is_open")):
				break
			lamp.call(&"apply_hit", null)
			await rig.wait_seconds(0.4)
			lamp = found.call(&"lantern", 1)
	_ck("G4 and the lanterns open it", bool(found.call(&"is_open")))
	await rig.wait_frames(30)
	_ck("G5 which is what lands the chest -- the puzzle pays (§5.2)",
		chest != null and chest.visible)
	await _stand_in_the_apron(rig, found)
	await rig.capture(out.path_join("m_06_lanterns_lit.png"))


## The player's own view of the apron: standing at its west end looking east down
## it, with both lanterns in shot and the maze's rim running along the left.
##
## **Along the apron rather than across it, and that is forced, not a preference.**
## The boom is 4.13 m (`K.CAM_DIST_MAX`) and the apron is 3.4 m deep, so a shot
## taken facing the maze puts the lens through the room's south wall — it
## collapses to `hard_min_distance` and the frame is the inside of the hero's
## hood, which is precisely what the first version of this shot produced. Along
## the room's 27 m width there is boom room to spare.
##
## Used by the fixture beats as well as the floor ones now: the apron is the same
## depth in both, so a shot that fits one fits the other, and the fixture's frames
## are then the same picture the floor's are.
func _stand_in_the_apron(rig, room: Node3D) -> void:
	if _hero == null or room == null:
		return
	var z: float = float(room.call(&"mouth_point").z) + MazeRoom.APRON * 0.5
	_hero.global_position = room.global_position + Vector3(-5.0, 0.15, z)
	_hero.facing_yaw = atan2(1.0, 0.0)
	_hero.rotation.y = _hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
