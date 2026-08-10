extends RefCounted
## M1's second half (docs/SCOPE.md §3): **the atom kit.** The eight phase-1
## puzzle props of `docs/PUZZLES.md` §2, each a body that emits `solved`, and a
## door that listens with a refusal that names the verb.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/puzzle_atoms.gd \
##     --out=/tmp/atoms/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  `PuzzleAtoms.validate()` is clean: eight rows, every script on disk,
##      every tier on the ladder, eight distinct non-empty refusals.
##   B  All eight BUILD, through `PuzzleAtoms.make()` -- the same call a
##      generator makes -- and are photographed together, unsolved. This is the
##      lookdev half: eight props that are all grey boxes would pass every
##      assertion below and still be unshippable.
##   C  Each one solves by ITS OWN VERB, not by `solve()`:
##        key      the hero walks onto it, and `Game.small_keys` grows by one
##        urn      a blow through `apply_hit`, and arrows come out
##        plate    the hero stands on it -- and it RISES when he steps off,
##                 which is the one non-latching row in the table
##        block    two shoves, seating it on its mark
##        eye      a SWORD hit is refused and an ARROW opens it. That refusal is
##                 the entire T1 tier; without it the eye is a T0 atom with a
##                 label on it
##        pillar   `burst()`, and the shaft's collision is gone afterwards
##        ring     the firer's `on_bitten`, which is the one call in the game
##                 that can tell a marker it was caught
##        socket   the hero in the shaft with the guard up, aimed
##   D  A `PuzzleGate` adopts its three atoms by tag, refuses with a COUNT
##      ("3 OF 3 EYES STILL SHUT"), counts down as they land, and opens itself on
##      the last one. Photographed shut and open.
##   E  `PuzzleAtom.clear_run_flags()` wipes the run's atom flags and leaves the
##      permanent door flags alone -- which is what makes the gate room a puzzle
##      again on run two instead of a corridor.
##
## C is checked off each prop's own `is_solved()` AFTER driving the real
## mechanism, never off a direct `solve()`. A kit whose atoms all report solved
## when told to is a kit that proves nothing; the verbs are the product.

const CHAMBER_Y := 0.02

var out := ""
var _fails := 0
var _atoms: Dictionary = {}
var _gate: Node
var _hero: Node3D


func run(rig) -> void:
	out = rig.arg("out", "/tmp/atoms/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# A run, so the atom flags start clean and `Run.enter`'s own wipe is the thing
	# that put them there. A director inheriting a previous session's flags would
	# see half the kit already solved.
	Run.enter(90210)

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	_gate = rig.scene().get_node_or_null(^"Gate")
	if _hero == null or _gate == null:
		print("ATOM FAIL the fixture is missing the hero or the gate")
		return

	_a_table()
	_b_build(rig)
	await rig.wait_physics_frames(8)
	await _shoot_kit(rig, "01_kit_unsolved.png")

	await _c_key(rig)
	await _c_urn(rig)
	await _c_plate(rig)
	await _c_block(rig)
	await _c_eye(rig)
	await _c_pillar(rig)
	await _c_ring(rig)
	await _c_socket(rig)
	await _shoot_kit(rig, "02_kit_solved.png")

	await _d_gate(rig)
	_e_flags()

	if _fails == 0:
		print("ATOM OK the eight atoms answer their own verbs and the gate counts")
	else:
		print("ATOM FAIL %d checks failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("ATOM FAIL %s" % label)


# --- A. The table -------------------------------------------------------------

func _a_table() -> void:
	var problems := PuzzleAtoms.validate()
	_ck("the kit validates (%d problems)" % problems.size(), problems.is_empty())
	for p in problems:
		print("       %s" % p)
	# §0 rule 1 in one line: a player who owns nothing may still be asked for four
	# atoms, and never for the bow's.
	var t0 := PuzzleAtoms.pool(PuzzleAtoms.T3)
	_ck("an empty pouch pools only T0 gating atoms (%s)" % [t0],
		not t0.has(PuzzleAtoms.EYE_SWITCH) and t0.has(PuzzleAtoms.SMALL_KEY))
	_ck("the urn never gates", not t0.has(PuzzleAtoms.URN))


# --- B. Eight props -----------------------------------------------------------

## Where each atom stands.
##
## The proving ground is NOT an empty box: it has a raised ledge over the whole
## of x > 3, a stair up to it around x = 2, two 7 m pillars at x = -7 and two
## step blocks in the south-west corner. Everything here lives in the clear
## rectangle that is left -- roughly x in [-8.5, 1], z in [-4.5, 4] -- because a
## prop clipped into the ledge photographs as a broken prop, and because the hero
## has to be able to STAND on the plate and in the shaft.
func _plan() -> Array:
	return [
		[PuzzleAtoms.SMALL_KEY, Vector3(-2.2, CHAMBER_Y, 0.8), 0.0, &""],
		[PuzzleAtoms.URN, Vector3(-3.0, CHAMBER_Y, 3.4), 0.0, &""],
		[PuzzleAtoms.PRESSURE_PLATE, Vector3(0.4, CHAMBER_Y, 3.4), 0.0, &""],
		# Shoved along +X, so its mark lands in open floor rather than under the
		# key. `mark_offset` is set after the build, below.
		[PuzzleAtoms.PUSH_BLOCK, Vector3(-8.0, CHAMBER_Y, 0.0), 0.0, &""],
		# Facing the hero, who arrives from +Z. Built looking down -Z
		# (`EyeSwitch`'s construction note), so a half-turn points it back.
		[PuzzleAtoms.EYE_SWITCH, Vector3(-8.0, 1.7, -4.2), PI, &"demo"],
		[PuzzleAtoms.CRACKED_PILLAR, Vector3(-5.0, CHAMBER_Y, -4.2), 0.0, &""],
		# `HookTarget`'s convention is +Z out of the mounting face, which is the
		# firer's and not this project's -- so a ring facing the room needs NO
		# rotation where the eye beside it needs half a turn. That asymmetry is
		# real and documented in both files; it is not a mistake here.
		[PuzzleAtoms.HOOK_RING, Vector3(-2.6, 2.2, -4.2), 0.0, &"demo"],
		# Turned to face the room. Its grate and its pool are on its own -Z, so an
		# unrotated socket would put the shaft in the north wall -- and it is the
		# rotated case that matters, because `catch_point()` going through
		# `to_global` instead of a bare offset is only visible once one is turned.
		# Placed so the CATCH lands at z = +1 in open floor: the hero has to be
		# able to stand in it, and half the ground is a ledge.
		[PuzzleAtoms.SUN_SOCKET, Vector3(-0.4, CHAMBER_Y, -4.0), PI, &"demo"],
	]


func _b_build(rig) -> void:
	for spec in _plan():
		var id: StringName = spec[0]
		var node := PuzzleAtoms.make(id, spec[3] as StringName)
		if node == null:
			_ck("%s builds" % id, false)
			continue
		# Transform BEFORE the tree. Three of these read `global_position` while
		# they build -- the block's home, the socket's beam, the ring's anchor --
		# and a node placed after `_ready` has already built itself at the origin.
		node.position = spec[1] as Vector3
		node.rotation.y = spec[2] as float
		node.name = String(id).to_pascal_case()
		if id == PuzzleAtoms.PUSH_BLOCK:
			node.set(&"mark_offset", Vector3(3.6, 0.0, 0.0))
		rig.scene().add_child(node)
		_atoms[id] = node
	_ck("all eight built (%d)" % _atoms.size(), _atoms.size() == 8)

	# Two more eyes, so the gate has a SET and its refusal has something to count.
	# Same tag, different `index` -- which is the whole reason `index` is on
	# `PuzzleAtom`: three eyes sharing one flag would be a gate that opens on the
	# first arrow, and nothing about the frame would look wrong.
	for i in 2:
		var extra := PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, &"demo")
		extra.position = Vector3(-6.4 + float(i + 1) * 1.9, 1.7, -8.6)
		extra.rotation.y = PI
		extra.set(&"index", i + 1)
		extra.name = "EyeSwitch%d" % (i + 1)
		rig.scene().add_child(extra)
		_atoms["eye_%d" % (i + 1)] = extra


func _atom(id) -> Node3D:
	return _atoms.get(id) as Node3D


func _solved(id) -> bool:
	var a := _atom(id)
	return a != null and bool(a.call(&"is_solved"))


# --- C. Eight verbs -----------------------------------------------------------

## Walk onto it. The real pickup path -- `Game.add_key` sits inside the atom's own
## overlap guard, and a director that called `solve()` would skip the one line
## that hands out the key.
func _c_key(rig) -> void:
	var before := Game.small_keys
	var key := _atom(PuzzleAtoms.SMALL_KEY)
	await _stand_at(rig, key.global_position)
	await rig.wait_physics_frames(10)
	_ck("the key is taken by walking onto it", _solved(PuzzleAtoms.SMALL_KEY))
	_ck("and the ring grew by exactly one (%d -> %d)" % [before, Game.small_keys],
		Game.small_keys == before + 1)


## One blow, any blow. Through `apply_hit`, which is the ONE damage path
## (`docs/CONTRACT.md` §8) and the same entry the sword's scan and the arrow both
## use -- an urn that answered a private `break_me()` would be an urn only this
## director can break.
func _c_urn(rig) -> void:
	var urn := _atom(PuzzleAtoms.URN)
	urn.call(&"apply_hit", Hit.make(K.QUARTER, urn.global_position + Vector3.BACK,
		&"sword", 0.0, 0.0, &"DIRECTOR"))
	await rig.wait_physics_frames(6)
	_ck("the urn breaks to a blow through apply_hit", _solved(PuzzleAtoms.URN))
	# Rule 2 (`docs/PUZZLES.md` §0): the ammunition is what makes a cold-start
	# puzzle solvable, so an urn that breaks and spills nothing is the rule
	# failing quietly.
	var bundles := 0
	for n in rig.scene().get_children():
		if n is ArrowBundle:
			bundles += 1
	_ck("and arrows came out of it (%d bundles)" % bundles, bundles > 0)


## Stand on it, then step off. **The one atom in the kit that goes backwards** --
## and the only check in this file that asserts something UN-happens.
func _c_plate(rig) -> void:
	var plate := _atom(PuzzleAtoms.PRESSURE_PLATE)
	await _stand_at(rig, plate.global_position)
	await rig.wait_physics_frames(12)
	_ck("the plate presses under the hero", _solved(PuzzleAtoms.PRESSURE_PLATE))
	await _stand_at(rig, plate.global_position + Vector3(0.0, 0.0, 4.0))
	await rig.wait_physics_frames(12)
	_ck("and RISES when he steps off", not _solved(PuzzleAtoms.PRESSURE_PLATE))
	_ck("a non-latching atom wrote no flag",
		not Game.flag(plate.call(&"flag_id")))


## Two shoves down its own axis. `push_to` is the half of the block below the
## sensing, and it is deliberately public so the SEATING can be proved without a
## hero leaning on it for a second and a half of director time.
func _c_block(rig) -> void:
	var block := _atom(PuzzleAtoms.PUSH_BLOCK)
	var mark: Vector3 = block.get(&"mark_offset")
	# Off the mark's dominant axis, not off Z. Written the other way it silently
	# shoved with a ZERO direction the moment the fixture put the mark along X,
	# and `push_to` correctly refused every time.
	var dir := Vector3(signf(mark.x), 0.0, 0.0) if absf(mark.x) >= absf(mark.z) \
		else Vector3(0.0, 0.0, signf(mark.z))
	for i in 4:
		block.call(&"push_to", dir)
		await rig.wait_seconds(0.45)
	_ck("the block seats on its mark after being shoved", _solved(PuzzleAtoms.PUSH_BLOCK))


## A sword is refused, an arrow opens it. **This pair is the T1 tier**: an eye
## that any blow tripped would be a T0 atom that `PuzzleAtoms.pool()` hands out
## to a player who has never seen a bow.
func _c_eye(rig) -> void:
	var eye := _atom(PuzzleAtoms.EYE_SWITCH)
	eye.call(&"apply_hit", Hit.make(K.QUARTER, eye.global_position + Vector3.BACK,
		&"sword", 0.0, 0.0, &"DIRECTOR"))
	await rig.wait_physics_frames(6)
	_ck("a SWORD blow does not open the eye", not _solved(PuzzleAtoms.EYE_SWITCH))
	eye.call(&"apply_hit", Hit.make(K.QUARTER, eye.global_position + Vector3.BACK,
		&"arrow", 0.0, 0.0, &"DIRECTOR"))
	await rig.wait_physics_frames(6)
	_ck("an ARROW does", _solved(PuzzleAtoms.EYE_SWITCH))


## `burst()`, which is the entry point M5's bomb will call and nothing else can.
## The collision check is the point of the atom: §3's third combinator is the
## pillar holding a slab over the way ON, so a pillar that "solved" while still
## standing in the doorway would be a puzzle that opened nothing.
func _c_pillar(rig) -> void:
	var pillar := _atom(PuzzleAtoms.CRACKED_PILLAR)
	_ck("the pillar is in group burstable, for M5's bomb to find",
		pillar.is_in_group(&"burstable"))
	pillar.call(&"burst")
	await rig.wait_seconds(1.0)
	_ck("burst() topples it", _solved(PuzzleAtoms.CRACKED_PILLAR))
	_ck("and its collision is GONE, not merely hidden",
		pillar.get_node_or_null(^"Shaft") == null)


## The firer telling the ring it won the aim-assist. That call is new in this
## change (`HeroRanged._fire_hookshot`) and it is the ONLY way a marker with no
## collision of its own can learn it was caught.
func _c_ring(rig) -> void:
	var ring := _atom(PuzzleAtoms.HOOK_RING)
	var target := ring.call(&"target") as HookTarget
	_ck("the ring registers as hookable", target != null
		and target.is_in_group(&"hookable"))
	if target != null:
		target.on_bitten(_hero)
	await rig.wait_physics_frames(6)
	_ck("and solves when the hook bites it", _solved(PuzzleAtoms.HOOK_RING))


## Stand in the shaft, guard up, pointed at the socket. The only T0 atom that
## asks the player to aim (`docs/PUZZLES.md` §2), and the only one that makes the
## shield a tool.
func _c_socket(rig) -> void:
	var socket := _atom(PuzzleAtoms.SUN_SOCKET)
	var catch: Vector3 = socket.call(&"catch_point")

	# A fixed camera behind the catch, looking at the socket.
	#
	# Not decoration: a guarding hero steers to the CAMERA's forward every frame
	# (`Hero._tick_camera_facing`), so `facing_yaw` set by hand is overwritten
	# within a frame of the shield going up. Aiming the lens is how a player aims
	# this puzzle, and it is the only way a director can aim it either.
	var cam := Camera3D.new()
	cam.name = "SocketCam"
	cam.position = catch + Vector3(0.0, 2.4, 4.0)
	rig.scene().add_child(cam)
	cam.look_at(socket.global_position + Vector3.UP, Vector3.UP)
	cam.make_current()

	await _stand_at(rig, catch)
	await rig.wait_physics_frames(30)
	_ck("standing in the shaft with the guard DOWN does nothing",
		not _solved(PuzzleAtoms.SUN_SOCKET))
	# The real button. `HeroCombat` polls `shield` and owns the decision -- a
	# director that wrote `hero.blocking` directly would be overwritten by the
	# next combat tick and would prove nothing about the guard.
	#
	# Pressed by hand rather than through `rig.hold_seconds` so the bounce can be
	# photographed WHILE it is happening: the reflected shaft is the whole read of
	# this atom and it goes out the instant the socket lights.
	Input.action_press(&"shield")
	await rig.wait_seconds(0.25)
	await rig.capture("02b_socket_bounce.png")
	await rig.wait_seconds(1.1)
	Input.action_release(&"shield")
	_ck("raising the shield reflects it into the socket",
		_solved(PuzzleAtoms.SUN_SOCKET))
	cam.queue_free()
	var game_cam := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	if game_cam != null:
		game_cam.make_current()


## Put the hero on a spot and let the physics settle. Teleported rather than
## walked: this director is about the PROPS, and eight walks across a 22 m
## chamber is four minutes of harness time proving the movement code again.
func _stand_at(rig, at: Vector3) -> void:
	_hero.global_position = Vector3(at.x, at.y + 0.05, at.z)
	_hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_physics_frames(6)


# --- D. The door that listens -------------------------------------------------

func _d_gate(rig) -> void:
	# Five: the eye, the ring and the socket from the plan, plus the two extra
	# eyes. All built AFTER the gate's own `_ready`, which is the case adoption
	# from the gate's end alone cannot cover -- `PuzzleAtom._offer` is the other
	# half, and this number is the only thing that proves it runs.
	var watched: Array = _gate.call(&"atoms")
	_ck("the gate adopted all five tagged atoms by tag alone (%d)" % watched.size(),
		watched.size() == 5)

	# The eye this director already opened in C is one of the three, so the count
	# starts at two. That is the interesting case, not the trivial one: a refusal
	# that says "3 OF 3" whatever has happened is a string, not a count.
	var line: String = _gate.call(&"refusal_line")
	_ck("the refusal names the verb and COUNTS: \"%s\"" % line,
		line.contains("EYES") and line.begins_with("2 OF 3"))
	_ck("and the gate is shut", not bool(_gate.call(&"unlocked")))

	await _look_at_gate(rig)
	# What the HUD actually DREW, not what the gate holds in a field. A refusal
	# that is correct in a member variable and never reaches the screen is exactly
	# the bug `gate_locks.gd` was written around, and it is invisible to any
	# assertion made on the prop.
	_ck("the gate owns the interact button", Prompt.focus == _gate)
	var said: String = Hud._prompt
	_ck("and the count is on the SCREEN: \"%s\"" % said, said == line)
	# No keycap on a refusal: there is no verb, so "E TO 2 OF 3 EYES STILL SHUT"
	# would be telling the player to press a button that does nothing.
	_ck("as a statement, not a button prompt", not said.contains(" TO "))
	await rig.capture("03_gate_refuses.png")

	var opened := [false]
	_gate.connect(&"opened", func(_w): opened[0] = true)

	_atoms["eye_1"].call(&"apply_hit", Hit.make(K.QUARTER, Vector3.ZERO, &"arrow"))
	await rig.wait_physics_frames(6)
	line = _gate.call(&"refusal_line")
	_ck("one down, the line follows: \"%s\"" % line, line == "THE EYE IS SHUT")

	_atoms["eye_2"].call(&"apply_hit", Hit.make(K.QUARTER, Vector3.ZERO, &"arrow"))
	await rig.wait_seconds(1.2)
	_ck("the last atom opens the gate by itself", opened[0]
		and bool(_gate.call(&"is_open")))
	await rig.capture("04_gate_open.png")


func _look_at_gate(rig) -> void:
	# From inside the room, at the distance a player stands at. The refusal is a
	# claim about a DOOR and the plate over it, and a shot from the ceiling would
	# prove neither.
	await _stand_at(rig, Vector3(0.0, CHAMBER_Y, -8.1))
	_hero.set(&"facing_yaw", PI)
	await rig.wait_frames(24)


# --- E. Per-run flags ---------------------------------------------------------

func _e_flags() -> void:
	var door_flag := StringName("door_open_atom_demo")
	Game.set_flag(door_flag)
	var atom_flags := 0
	for k: StringName in Game.flags.keys():
		if String(k).begins_with("atom_"):
			atom_flags += 1
	_ck("solved atoms left run flags behind (%d)" % atom_flags, atom_flags > 0)
	PuzzleAtom.clear_run_flags()
	var left := 0
	for k: StringName in Game.flags.keys():
		if String(k).begins_with("atom_"):
			left += 1
	_ck("clear_run_flags() wipes them", left == 0)
	# The door flag is PERMANENT and must survive -- a shortcut you opened stays
	# open across saves, and a wipe that took it would undo the whole of M1's
	# first half.
	_ck("and leaves the permanent door flags alone", Game.flag(door_flag))


# --- Photography --------------------------------------------------------------

## The whole kit in one frame, from a camera that can see both rows. Built here
## rather than authored into the fixture because it exists for exactly two shots
## and a stray `current` camera in a scene file is a thing every other director
## using that scene then has to fight.
func _shoot_kit(rig, path: String) -> void:
	var cam := rig.scene().get_node_or_null(^"KitCam") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "KitCam"
		cam.fov = 66.0
		# INSIDE the chamber. The ceiling slab is at y = 7 and a camera above it
		# is outside the room: the slab occludes the near half and the shot comes
		# back as a letterboxed band of far wall. It cost one render to find and
		# it is invisible in any assertion.
		cam.position = Vector3(-3.4, 5.2, 9.4)
		rig.scene().add_child(cam)
		cam.look_at(Vector3(-3.6, 0.9, -3.0), Vector3.UP)
	cam.make_current()
	await rig.wait_frames(20)
	await rig.capture(path)
	var game_cam := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	if game_cam != null:
		game_cam.make_current()
	await rig.wait_frames(6)
