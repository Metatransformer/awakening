extends RefCounted
## **Lights out** — `docs/PUZZLES.md` §3, combinator 6 (*couple*), and the lantern
## that §2 added to the kit to serve it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/lights_out.gd \
##     --out=/tmp/lo/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The kit still validates with nine rows, and the lantern's is what §2 says
##      it is: T0, non-latching, gating, a refusal of its own.
##   B  A 3x3 grid builds nine lanterns, each carrying the GATE's `puzzle_id` and
##      its own `index` — and the gate adopts all nine with no idea a grid
##      exists, refuses with the kit's own plural, and is shut.
##   C  **The coupling.** Pressing a lantern flips it and its orthogonal
##      neighbours and NOTHING else: the centre moves five, a corner three, an
##      edge four. Checked cell by cell against a copy of the board taken before
##      the press, because "the right number changed" is a check that passes when
##      the wrong five change.
##   D  **A press is its own inverse.** Press twice and the board is exactly
##      where it was. This is the property the whole generator rests on.
##   E  **The board is always solvable, and this run proves it by solving it** —
##      not by arguing that a scramble made of presses must be pressable.
##      `solution()` is applied one press at a time and the grid ends lit out.
##   F  And the gate opened itself on the last lantern, through the ordinary
##      `PuzzleGate` count.
##   G  **Every board this floor can deal is solvable.** Two hundred deals off
##      real seeds, each one solved. This is the beat that exists because the
##      obvious implementation — deal each cell at random — ships a room that
##      cannot be finished on a seed nobody can predict.
##   H  **The answer is always corners**, and no dealt board is the one-dark trap
##      a playtester walked into (`LanternGrid`'s class note). Over the same two
##      hundred deals, because "the board I looked at read fine" is the check
##      that passes on 199 seeds.
##   I  **One swing is one press for the BOARD.** Two lanterns struck in a single
##      frame — which is what the spin's 2.1 m sphere does standing in a 2.3 m
##      grid — move one cross, not two.
##   J  **The room cannot be made unfinishable.** Eight blows that do not get the
##      board out and the grid points at one press, a real one, a corner.
##
## G–J are the reason this file is worth its length. Everything above them would
## pass against a random deal.

const SEED := 20260810
const GRID := 3

var out := ""
var _fails := 0
var _grid: Node
var _gate: Node
var _hero: Node3D


func run(rig) -> void:
	out = rig.arg("out", "/tmp/lo/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Run.enter(SEED)

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	if _hero == null:
		_hero = rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D

	_a_table()
	await _b_build(rig)
	await _c_coupling(rig)
	await _d_involution(rig)
	await _e_solve(rig)
	_g_every_board()
	await _i_one_swing(rig)
	await _j_hint(rig)

	if _fails == 0:
		print("LIGHTS ok -- every check passed")
	else:
		print("LIGHTS FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("LIGHTS ok %s" % label)
	else:
		print("LIGHTS FAIL %s" % label)
		_fails += 1


# --- A. The row ---------------------------------------------------------------

func _a_table() -> void:
	var problems := PuzzleAtoms.validate()
	_ck("A0 the kit validates at nine (%d problems)" % problems.size(),
		problems.is_empty())
	for p in problems:
		print("       %s" % p)
	var row := PuzzleAtoms.row(PuzzleAtoms.LANTERN)
	_ck("A1 the lantern has a row", not row.is_empty())
	_ck("A2 it is T0 -- floor 1's critical path may ask for it (§1)",
		PuzzleAtoms.tier(PuzzleAtoms.LANTERN) == PuzzleAtoms.T0)
	# The whole combinator rests on this one bool. A latching lantern is a grid
	# that can only ever get brighter.
	_ck("A3 and NON-latching, which is what makes it couplable",
		not PuzzleAtoms.latching(PuzzleAtoms.LANTERN))
	_ck("A4 a door may hang on it", PuzzleAtoms.gates(PuzzleAtoms.LANTERN))
	_ck("A5 an empty pouch can be asked for one (§0 rule 1)",
		PuzzleAtoms.pool(PuzzleAtoms.T0).has(PuzzleAtoms.LANTERN))


# --- B. Nine posts and one door -----------------------------------------------

func _b_build(rig) -> void:
	var gate := PuzzleGate.new()
	gate.name = "LightsGate"
	gate.puzzle_id = &"lights"
	gate.position = Vector3(-4.2, 0.0, -8.4)
	rig.scene().add_child(gate)
	_gate = gate

	var grid := LanternGrid.new()
	grid.name = "LightsGrid"
	grid.puzzle_id = &"lights"
	grid.rows = GRID
	grid.cols = GRID
	# Chamber centre, not out by the west wall. A 3x3 board is 4.6 m across and the
	# follow camera sits behind the hero: pushed against a wall, half the frame is
	# masonry and the board never reads as a grid. The first pass shot exactly that.
	grid.position = Vector3(0.0, 0.02, -1.2)
	rig.scene().add_child(grid)
	_grid = grid
	await rig.wait_frames(20)

	var board: Array = grid.call(&"board")
	_ck("B0 the grid built %d lanterns" % board.size(),
		board.size() == GRID * GRID)
	print("LIGHTS dealt %s -- %d lit" % [_show(board), grid.call(&"lit_count")])
	# The scramble is allowed to be light, but a board that came out ALREADY done
	# would make every beat below vacuous.
	_ck("B1 and it dealt a board that is not already solved",
		not bool(grid.call(&"is_lit_out")))

	# **The gate has no idea a grid exists.** Nine atoms carrying its tag, adopted
	# by the same `watch` that adopts one key.
	var watched: Array = _gate.call(&"atoms")
	_ck("B2 the gate adopted all nine as ordinary atoms (%d)" % watched.size(),
		watched.size() == GRID * GRID)
	var indices := {}
	for a in watched:
		indices[int(a.get(&"index"))] = true
	# Distinct indices are not cosmetic: `PuzzleAtom.flag_id` is keyed on them,
	# and nine lanterns sharing a flag is a grid whose cells forget separately.
	_ck("B3 each with its own index (%d distinct)" % indices.size(),
		indices.size() == GRID * GRID)
	var line: String = _gate.call(&"refusal_line")
	print("LIGHTS refusal=\"%s\"" % line)
	_ck("B4 and it refuses in the kit's own words (\"%s\")" % line,
		line.contains("LANTERN"))
	_ck("B5 the gate is shut", not bool(_gate.call(&"is_open")))

	await _look(rig, grid, 8.2)
	await rig.capture(out.path_join("l_01_dealt.png"))


# --- C. The coupling ----------------------------------------------------------

## Press one, and check the board CELL BY CELL against what the rule says should
## have moved. Counting how many changed is the check that passes when the wrong
## five change.
func _c_coupling(rig) -> void:
	var centre := (GRID * GRID) / 2
	await _press_and_check(rig, centre, 5, "C0 the centre flips five")
	await _press_and_check(rig, 0, 3, "C1 a corner flips three -- clipped, not wrapped")
	await _press_and_check(rig, 1, 4, "C2 an edge flips four")
	await _look(rig, _grid, 8.2)
	await rig.capture(out.path_join("l_02_pressed.png"))


func _press_and_check(rig, at: int, want: int, label: String) -> void:
	var before: Array = (_grid.call(&"board") as Array).duplicate()
	var lamp: Node = _grid.call(&"cell", at)
	if lamp == null:
		_ck(label, false)
		return
	# The REAL verb, through `apply_hit`, not `press()` -- the sword is what the
	# player has and the arc is what reaches the post.
	lamp.call(&"apply_hit", null)
	await rig.wait_frames(8)
	var after: Array = _grid.call(&"board")
	var want_set := {}
	for i in _cross(at):
		want_set[i] = true
	var wrong := 0
	for i in before.size():
		var moved: bool = before[i] != after[i]
		if moved != want_set.has(i):
			wrong += 1
	_ck("%s, and only those (%d wrong)" % [label, wrong],
		wrong == 0 and want_set.size() == want)
	# Past the lantern's own re-arm, or the next press is swallowed.
	await rig.wait_seconds(0.4)


## The rule, spelled a SECOND time on purpose. If this director shared
## `LanternGrid._cross` it would be checking the code against itself, and a
## neighbourhood that was wrong in both places would pass every beat above.
func _cross(at: int) -> Array:
	var r := at / GRID
	var c := at % GRID
	var out_i: Array = [at]
	if r > 0:
		out_i.append(at - GRID)
	if r < GRID - 1:
		out_i.append(at + GRID)
	if c > 0:
		out_i.append(at - 1)
	if c < GRID - 1:
		out_i.append(at + 1)
	return out_i


# --- D. A press is its own inverse --------------------------------------------

## The property the generator is built on: scrambling by pressing means the
## scramble can be undone by pressing. If this were false the whole solvability
## argument in `LanternGrid`'s class note would be false with it.
func _d_involution(rig) -> void:
	var before: Array = (_grid.call(&"board") as Array).duplicate()
	var lamp: Node = _grid.call(&"cell", 4)
	lamp.call(&"apply_hit", null)
	await rig.wait_seconds(0.45)
	lamp.call(&"apply_hit", null)
	await rig.wait_frames(8)
	var after: Array = _grid.call(&"board")
	_ck("D0 pressing the same lantern twice returns the board exactly",
		_same(before, after))
	await rig.wait_seconds(0.4)


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


# --- E/F. Solve it, and the door opens ----------------------------------------

func _e_solve(rig) -> void:
	var plan: Array = _grid.call(&"solution")
	print("LIGHTS solution %s (%d presses)" % [plan, plan.size()])
	_ck("E0 the board has a solution", not plan.is_empty())
	if plan.is_empty():
		return

	var opened := [false]
	_gate.connect(&"opened", func(_w: StringName) -> void: opened[0] = true)

	for at: int in plan:
		var lamp: Node = _grid.call(&"cell", at)
		# **Press until it takes, not for a fixed time.** One press per re-arm
		# window is the rule -- a director that pressed faster than the prop allows
		# would be proving a puzzle the player cannot play -- but a wall-clock sleep
		# of `REARM` + a bit is a coin flip on a cold run, where one stalled frame
		# swallows the blow and the walk silently drops a press. A cold-import run
		# failed E1 exactly that way. So: swing, and if the board did not move,
		# wait out the window and swing again.
		for _try in 6:
			var before: Array = (_grid.call(&"board") as Array).duplicate()
			lamp.call(&"apply_hit", null)
			await rig.wait_frames(6)
			if (_grid.call(&"board") as Array) != before:
				break
			await rig.wait_seconds(0.4)
		await rig.wait_seconds(0.4)
	await rig.wait_frames(30)

	print("LIGHTS final %s" % [_show(_grid.call(&"board"))])
	_ck("E1 walking the solution lights every lantern",
		bool(_grid.call(&"is_lit_out")))
	# The point of building it out of ordinary atoms: nothing taught the door
	# about grids, and it opened anyway.
	_ck("F0 and the gate opened itself, through the ordinary atom count",
		opened[0] and bool(_gate.call(&"is_open")))
	await _look(rig, _grid, 8.2)
	await rig.capture(out.path_join("l_03_lit_out.png"))
	await _look(rig, _gate, 5.0)
	await rig.capture(out.path_join("l_04_gate_open.png"))


# --- G. Every board this floor can deal ---------------------------------------

## **Two hundred deals, every one solved.** The beat this file exists for.
##
## Not a fuzz test bolted on: a lights-out generator has exactly one way to be
## catastrophically wrong, and it is invisible in every frame and every other
## check. A board dealt cell-by-cell at random is unsolvable three times in four
## on a 5x5, and the failure arrives as a player standing in a critical-path room
## that cannot be finished, on one seed, months later.
##
## Run headlessly against the grid's own arithmetic rather than by building two
## hundred rooms — the thing under test is the DEAL and the SOLVER, and standing
## eighteen hundred lanterns up to say so would take ten minutes to prove the
## same sentence.
func _g_every_board() -> void:
	var bad := 0
	var worst := 0
	var total := 0
	var off_corner := 0
	var one_dark := 0
	var corners := [0, GRID - 1, (GRID - 1) * GRID, GRID * GRID - 1]
	for i in 200:
		# A real seed each time, through `Run.enter`, so this is the same RNG the
		# floor generator hands the grid and not a private one that could differ.
		Run.enter(SEED + i * 7919)
		var g := LanternGrid.new()
		g.rows = GRID
		g.cols = GRID
		g.call(&"_deal")
		# `_build` never runs, so `board()` is empty -- drive the solver off the
		# dealt array directly, which is what `_build` would have posed.
		var dealt: Array = g.get(&"_dealt")
		var plan: Array = _solve_array(dealt)
		if plan.is_empty():
			bad += 1
		for at in plan:
			if not corners.has(at):
				off_corner += 1
		if dealt.count(false) == 1:
			one_dark += 1
		total += plan.size()
		worst = maxi(worst, plan.size())
		g.free()
	_ck("G0 every one of 200 dealt boards is solvable (%d unsolvable)" % bad,
		bad == 0)
	print("LIGHTS solutions avg %.1f presses, longest %d"
		% [float(total) / 200.0, worst])
	# A dial that does nothing is a dial somebody will turn. If the hardest board
	# in two hundred is one press, the scramble is not scrambling.
	_ck("G1 and they are not all trivial (longest %d presses)" % worst, worst >= 3)
	# **H.** The playtest fix, checked over the whole seed space rather than over
	# the one board this run happened to draw.
	_ck("H0 every press of every answer is a corner (%d off-corner)" % off_corner,
		off_corner == 0)
	# The trap itself: a board showing one dark lantern reads as one blow from
	# done and is four or five, none of them on the dark one.
	_ck("H1 and no dealt board is the one-dark trap (%d dealt)" % one_dark,
		one_dark == 0)
	Run.enter(SEED)


# --- I/J. One swing, and a room that cannot be made unfinishable --------------

## A board of its own for each beat below, off to the side and with no gate over
## it: E left the first grid lit out and its door open, and a beat that pressed
## THAT board would be proving things about a solved puzzle.
## Stood where the first one was -- E has had its four frames and the beats below
## want the same framing, not a board out in the void past the north wall. The
## first grid goes with it: nine lanterns and nine more in one room is a photo
## nobody can read.
func _spare(rig, label: String) -> Node:
	if is_instance_valid(_grid):
		_grid.queue_free()
		await rig.wait_frames(4)
	var g := LanternGrid.new()
	g.name = label
	g.rows = GRID
	g.cols = GRID
	g.puzzle_id = &"lights_spare"
	g.position = Vector3(0.0, 0.02, -1.2)
	rig.scene().add_child(g)
	_grid = g
	await rig.wait_frames(12)
	return g


## **Two lanterns, one frame, one press.** This is what the spin attack does:
## `HeroCombat._scan` damages everything overlapping the blade in a single pass,
## and the spin's sphere is 2.1 m over a full circle while the posts stand 2.3 m
## apart. Without the guard, one spin in the middle of the board moves four or
## five crosses at once and the player's read of the room is gone.
##
## Struck cell by cell against a copy, like C -- "the board moved a bit less"
## would pass with the wrong cross taken.
func _i_one_swing(rig) -> void:
	var g: Node = await _spare(rig, "SpareSwing")
	var before: Array = (g.call(&"board") as Array).duplicate()
	# No await between them, so both land inside one process frame -- the same
	# thing `_scan`'s loop does.
	(g.call(&"cell", 0) as Node).call(&"apply_hit", null)
	(g.call(&"cell", GRID * GRID - 1) as Node).call(&"apply_hit", null)
	await rig.wait_frames(8)
	var after: Array = g.call(&"board")
	var want := {}
	for i in _cross(0):
		want[i] = true
	var wrong := 0
	for i in before.size():
		if (before[i] != after[i]) != want.has(i):
			wrong += 1
	_ck("I0 two lanterns struck in one frame move ONE cross (%d wrong)" % wrong,
		wrong == 0)
	g.queue_free()


## The safety net. Eight presses that do not finish the board and the grid starts
## pointing -- at a press that is really in the answer, and at a corner, because
## a corner is the move whose consequences a player can see all of.
##
## The centre, eight times: an even number of presses on one cell is the board it
## started from (D), so this arrives at `HINT_AFTER` with the dealt board still
## on the posts and nothing solved by accident.
func _j_hint(rig) -> void:
	var g: Node = await _spare(rig, "SpareHint")
	var lit := [false]
	g.connect(&"lit_out", func() -> void: lit[0] = true)
	var centre := (GRID * GRID) / 2
	for _p in 8:
		await _swing(rig, g, centre)
	_ck("J0 eight presses that do not solve it (solved=%s)" % lit[0], not lit[0])

	var hinted: Array = []
	for i in GRID * GRID:
		var lamp: Node = g.call(&"cell", i)
		if lamp != null and bool(lamp.get(&"_hinted")):
			hinted.append(i)
	_ck("J1 and the grid is pointing at exactly one lantern (%s)" % [hinted],
		hinted.size() == 1)
	# **Two frames, top of the breath and bottom of it, one camera.** The tell has
	# to be visible and not merely true in a bool -- and a pulse cannot be proved
	# by one photograph, because a single frame of a lantern breathing is a
	# lantern. Framed on the post that is pointing rather than on the whole board:
	# the tell is brass, and at board distance brass is four pixels.
	var post: Node = g.call(&"cell", hinted[0])
	await _look(rig, post as Node3D, 4.6)
	# Let the follow camera finish easing in, or the pair differs by a camera move
	# and proves nothing about a lantern.
	await rig.wait_seconds(1.2)
	# Restart the breath so its phase is known: `Lantern.set_hint` zeroes the
	# clock, and a cosine at HINT_RATE tops out half a period later.
	post.call(&"set_hint", false)
	post.call(&"set_hint", true)
	await rig.wait_seconds(PI / Lantern.HINT_RATE)
	print("LIGHTS hint post %d at screen %s" % [hinted[0], _screen(rig, post)])
	await rig.capture(out.path_join("l_05_hint_on.png"))
	# **The pair is swelled-versus-none, not swelled-versus-ebbed.** A lit lantern's
	# lamp flickers every frame by design, so two frames of the same board differ
	# all over and a pulse cannot be picked out of that. The hinted post here is
	# dark, and a dark post has nothing else moving on it -- so every pixel that
	# changes between these two frames is the tell.
	post.call(&"set_hint", false)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("l_06_hint_off.png"))
	if hinted.size() != 1:
		g.queue_free()
		return
	var plan: Array = g.call(&"solution")
	_ck("J2 which is really in the answer (%s of %s)" % [hinted[0], plan],
		plan.has(hinted[0]))
	var corners := [0, GRID - 1, (GRID - 1) * GRID, GRID * GRID - 1]
	_ck("J3 and it is a corner (%d)" % hinted[0], corners.has(hinted[0]))

	# It has to stop pointing when the room is done, or an opened door still has a
	# lantern breathing "not yet" underneath it.
	for at: int in plan:
		await _swing(rig, g, at)
	await rig.wait_frames(10)
	var still := 0
	for i in GRID * GRID:
		var lamp: Node = g.call(&"cell", i)
		if lamp != null and bool(lamp.get(&"_hinted")):
			still += 1
	_ck("J4 the hint clears when the board comes out (%d still pointing, lit_out=%s)"
		% [still, g.call(&"is_lit_out")], still == 0 and bool(g.call(&"is_lit_out")))
	g.queue_free()


## Swing until the board moves. Same reason E does: a wall-clock sleep of `REARM`
## plus a bit is a coin flip on a cold run, and a swallowed blow here would drop
## a press out of the count `HINT_AFTER` is watching.
func _swing(rig, g: Node, at: int) -> void:
	var lamp: Node = g.call(&"cell", at)
	if lamp == null:
		return
	for _try in 6:
		var before: Array = (g.call(&"board") as Array).duplicate()
		lamp.call(&"apply_hit", null)
		await rig.wait_frames(6)
		if (g.call(&"board") as Array) != before:
			break
		await rig.wait_seconds(0.4)
	await rig.wait_seconds(0.4)


## The same first-row brute force `LanternGrid.solution()` runs, over a plain
## array. Spelled here rather than called for the reason C's `_cross` is: a
## solver checked against itself proves nothing.
func _solve_array(start: Array) -> Array:
	var n := GRID * GRID
	for mask in 1 << GRID:
		var work: Array = start.duplicate()
		var plan: Array = []
		for c in GRID:
			if mask & (1 << c):
				plan.append(c)
				_flip(work, c)
		for r in range(1, GRID):
			for c in GRID:
				if not work[(r - 1) * GRID + c]:
					plan.append(r * GRID + c)
					_flip(work, r * GRID + c)
		var done := true
		for i in n:
			if not work[i]:
				done = false
				break
		if done:
			return plan
	return []


func _flip(board: Array, at: int) -> void:
	for i in _cross(at):
		board[i] = not board[i]


# --- Camera -------------------------------------------------------------------

## Where a post's cage lands in the frame, so a reader of the log knows which
## pixels to go and look at. A capture nobody can locate the subject in is a
## capture that proves whatever you already believed.
func _screen(rig, at: Node) -> Vector2i:
	var cam: Camera3D = rig.scene().get_viewport().get_camera_3d()
	var n := at as Node3D
	if cam == null or n == null:
		return Vector2i(-1, -1)
	return Vector2i(cam.unproject_position(
		n.global_position + Vector3(0.0, Lantern.POST_H + Lantern.CAGE_H * 0.5, 0.0)))

func _show(board: Array) -> String:
	var s := ""
	for i in board.size():
		if i > 0 and i % GRID == 0:
			s += "/"
		s += "O" if board[i] else "."
	return s


func _look(rig, at: Node3D, back: float) -> void:
	if _hero == null or at == null:
		return
	var stop := at.global_position + Vector3(0.0, 0.0, back)
	stop.y = 0.15
	_hero.global_position = stop
	var to := K.flat(at.global_position - _hero.global_position)
	if to != Vector3.ZERO:
		_hero.facing_yaw = atan2(to.x, to.z)
		_hero.rotation.y = _hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
