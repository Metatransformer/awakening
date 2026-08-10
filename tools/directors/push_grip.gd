extends RefCounted
## **The grip.** A hero who leans on a push block takes hold of it and walks it
## along for as long as he keeps pressing -- Ocarina's block -- and lets go the
## moment he lets go of the stick.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/push_grip.gd \
##     --out=/tmp/grip/x.png --warmup=60
##
## `tools/directors/puzzle_atoms.gd` proves the block SEATS, by calling `push_to`
## four times with no hero in the room at all. That is the right test for the
## seating and it is no test of this: everything the grip changes lives between
## the stick and the stone, and a director that shoves the block itself skips all
## of it. So this one presses a direction and never touches the block.
##
## What it claims:
##
##   A  Leaning takes hold. After `PUSH_DELAY` of pressing into it the hero is
##      gripping and the block has moved its first cell.
##   B  **It keeps going.** One unbroken press walks it three or more cells --
##      with no second `PUSH_DELAY` between them, which is the whole difference
##      from re-approaching a block per metre.
##   C  **He travels with it.** The gap between hero and stone at the end of that
##      push is the gap he grabbed it at. He is not chasing it and it is not
##      dragging him through it.
##   D  He squares up. Grabbed off-centre by a third of a metre, he is pulled
##      onto the face's centre-line rather than sliding off its corner.
##   E  Letting go lets go. The stick comes off, the grip drops, the block stops.
##   F  Brushing past does not grab. Walking ACROSS the face for a second and a
##      half moves nothing -- the guard `PUSH_DELAY` was written for, which the
##      grip must not have quietly spent.
##
## The camera is the GAME camera the whole way through, and the push direction is
## read off it rather than assumed. The stick is camera-relative (`Hero._camera_
## relative`), so a director that pressed `move_up` and asserted about world -Z
## would be a director that starts lying the first time the fixture's camera is
## nudged.

## How long to lean before A is judged. Comfortably past `PushBlock.PUSH_DELAY`
## (0.30 s) plus the first cell's slide.
const GRAB_TIME := 1.1
## The unbroken push after the grab. At `GRIP_SPEED` (1.46 m/s) over a 1.2 m
## cell that is a bit over three more cells.
const PUSH_TIME := 3.0
## Where he grabs it from, across the face. Big enough that a hero who did not
## square up would be visibly on the corner.
const OFF_CENTRE := 0.34

var out := ""
var _fails := 0
var _hero: Node3D
var _block: Node3D
var _axis := Vector3.FORWARD


func run(rig) -> void:
	out = rig.arg("out", "/tmp/grip/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Run.enter(90210)

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	if _hero == null:
		print("GRIP FAIL the fixture has no hero")
		return
	await rig.wait_physics_frames(4)

	# The push runs down the camera's own forward, snapped to the grid the block
	# moves on. Anything else and "press towards it" means a different direction
	# to the director than it does to the player.
	var cam: Camera3D = rig.scene().get_viewport().get_camera_3d()
	_axis = _cardinal(K.flat(-cam.global_transform.basis.z))

	# `mark_offset = ZERO` -- the block has no mark and cannot solve, so the push
	# never ends. A block that seated after two cells would take B's runway away
	# and pass C by standing still.
	_block = PuzzleAtoms.make(PuzzleAtoms.PUSH_BLOCK, &"")
	_block.set(&"mark_offset", Vector3.ZERO)
	# INSIDE the proving ground's clear rectangle (`puzzle_atoms.gd` §B names it:
	# x in [-8.5, 1], z in [-4.5, 4]). The hero stands 1.6 m back from this and
	# the runway runs the other way, so both ends have to be inside it -- a hero
	# spawned at z = 4.6 lands in the wall and is depenetrated sideways onto the
	# block's corner, which reads exactly like a grip that failed to hold.
	_block.position = Vector3(-2.0, 0.02, 2.0)
	_block.name = "Block"
	rig.scene().add_child(_block)
	await rig.wait_physics_frames(4)

	var side := _axis.cross(Vector3.UP)
	_hero.global_position = _block.global_position - _axis * 1.6 + side * OFF_CENTRE
	await rig.wait_physics_frames(10)
	await rig.capture("01_before.png")

	await _a_grab(rig)
	await _bcd_walk(rig)
	await _e_let_go(rig)
	await _f_brush(rig)

	if _fails == 0:
		print("GRIP OK he takes hold, walks it along, and lets go when he does")
	else:
		print("GRIP FAIL %d checks failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("GRIP FAIL %s" % label)


# --- A. The grab --------------------------------------------------------------

var _grab_gap := 0.0
var _grab_at := Vector3.ZERO


func _a_grab(rig) -> void:
	_ck("he is not gripping anything before he leans", not _is_gripping())
	var home := _face()
	_press(rig)
	await rig.wait_seconds(GRAB_TIME)
	_grab_gap = _gap()
	_grab_at = _face()
	_ck("leaning takes hold of it", _is_gripping())
	# Under way, not finished. A cell takes `STEP / GRIP_SPEED` (0.82 s) and the
	# grab lands somewhere inside a window a few frames wide, so "the first cell
	# has COMPLETED by now" is a claim about the harness's timing rather than
	# about the block. How far it actually gets is B's business.
	_ck("and the first cell is under way (%.2f m)" % home.distance_to(_grab_at),
		home.distance_to(_grab_at) >= PushBlock.STEP * 0.4)
	await rig.capture("02_grabbed.png")


# --- B, C, D. The walk --------------------------------------------------------

func _bcd_walk(rig) -> void:
	# The stick is NOT re-pressed here: `_a_grab` left it down and this is the
	# same unbroken hold, which is the claim.
	await rig.wait_seconds(PUSH_TIME)
	var cells := _grab_at.distance_to(_face()) / PushBlock.STEP
	_ck("one unbroken press walks it %.1f cells" % cells, cells >= 3.0)
	_ck("he still has hold at the end of it", _is_gripping())
	_ck("the gap he grabbed it at is the gap he has (%.2f m -> %.2f m)"
		% [_grab_gap, _gap()], absf(_gap() - _grab_gap) <= 0.2)
	# D. Across the axis, not along it: he started a third of a metre off centre.
	var side := _axis.cross(Vector3.UP)
	var drift := absf(K.flat(_face() - _hero.global_position).dot(side))
	_ck("and he is square on the face, not on its corner (%.2f m off)" % drift,
		drift <= 0.12)
	await rig.capture("03_walked.png")


# --- E. Letting go ------------------------------------------------------------

func _e_let_go(rig) -> void:
	_release()
	var dropped: bool = await rig.until(func() -> bool: return not _is_gripping(), 1.0)
	_ck("the stick comes off and so does he", dropped)
	# Past the tail of any cell that was already in flight when he let go: the
	# claim is that the block STOPS, not that it stops mid-slide.
	await rig.wait_seconds(1.2)
	var rest := _face()
	await rig.wait_seconds(0.6)
	_ck("and the block stops where it was left", rest.distance_to(_face()) < 0.01)
	await rig.capture("04_let_go.png")


# --- F. Brushing past ---------------------------------------------------------

func _f_brush(rig) -> void:
	var side := _axis.cross(Vector3.UP)
	_hero.global_position = _face() - _axis * 1.5 - side * 1.4
	await rig.wait_physics_frames(10)
	var home := _face()
	# ACROSS the face, through the probe and out the other side.
	_press(rig, side)
	await rig.wait_seconds(1.5)
	_release()
	_ck("walking past it does not grab it", not _is_gripping())
	_ck("and does not move it", home.distance_to(_face()) < 0.01)


# --- Instruments --------------------------------------------------------------

## Press the stick along a world direction, through the same two actions a player
## has. Camera-relative in the hero, so this inverts the camera's yaw to work out
## which pair of actions adds up to the direction asked for.
func _press(rig, dir: Vector3 = Vector3.ZERO) -> void:
	var want := dir if dir != Vector3.ZERO else _axis
	var cam: Camera3D = rig.scene().get_viewport().get_camera_3d()
	var fwd := K.flat(-cam.global_transform.basis.z).normalized()
	var right := K.flat(cam.global_transform.basis.x).normalized()
	_release()
	# One action per axis, at the strength the projection asks for. A cardinal
	# push comes out as a single full-strength action, which is what a player
	# holding one key produces.
	var f := want.dot(fwd)
	var r := want.dot(right)
	if absf(f) > 0.02:
		Input.action_press(&"move_up" if f > 0.0 else &"move_down", absf(f))
	if absf(r) > 0.02:
		Input.action_press(&"move_right" if r > 0.0 else &"move_left", absf(r))


func _release() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _is_gripping() -> bool:
	return _hero.has_method(&"gripping") and bool(_hero.call(&"gripping"))


## Where the stone actually is. `PushBlock` moves its BODY and leaves the root
## where it was placed, so the root's position is the block's home and says
## nothing about how far it has travelled.
func _face() -> Vector3:
	var p: Vector3 = _block.call(&"grip_anchor")
	return p


## Hero to stone, along the push axis only.
func _gap() -> float:
	return K.flat(_face() - _hero.global_position).dot(_axis)


func _cardinal(v: Vector3) -> Vector3:
	if absf(v.x) >= absf(v.z):
		return Vector3(signf(v.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(v.z))
