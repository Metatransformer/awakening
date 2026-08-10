extends RefCounted
## First person, steered by the MOUSE — and put back straight by the right
## button.
##
## `first_person.gd` already covers the stance itself (the boom collapses, the
## hero is not in his own shot, the move stick pops you out). This one covers the
## half of it a keyboard-and-mouse player actually touches, which had two holes
## in it:
##
##   1. the mouse is the right stick in here. Same `_look_input`, both axes, and
##      the cursor is GRABBED on the way in rather than only once at spawn — a
##      pause menu or a shop hands the pointer back, and stepping into the mode
##      whose whole content is looking around must not depend on nothing having
##      taken it.
##   2. RMB — `shield`, the same action the left trigger fires — is OOT's Z, and
##      the fourth thing Z does is put the camera back behind the hero. It was
##      SILENT in first person: `GameCamera._apply_parallel` refused every
##      recentre while `_fp01 > 0`, so the one mode with no boom to read a room
##      off was also the one with no way to face forward again.
##   3. and the guard itself stands down in here, which is what makes (2) work at
##      all. Guarding pins the hero's facing to the lens, so a shield raised from
##      inside his head would rotate his rooted, invisible body onto whatever the
##      player had just glanced at — and the recentre would then have no error
##      left to close.
##
## The frames are the proof for the look; the angles are asserted because a dark
## garrison wall photographs identically from 40° off.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/fp_look.gd \
##     --out=/tmp/fplook/x.png --warmup=60

var _i := 0
var _fail := 0
var _cam: GameCamera = null
var _hero: Node3D = null


func run(rig) -> void:
	Input.use_accumulated_input = false
	_cam = rig.root.get_camera_3d() as GameCamera
	_hero = rig.root.get_tree().get_first_node_in_group(&"player") as Node3D
	if _cam == null or _hero == null:
		print("FPLOOK FAILED (no GameCamera or no hero)")
		return

	# A full second before the first press, and a second press if the first did
	# not take. The garrison's boot fade holds `Prompt.blocked` for a while after
	# the warmup frames are done, and `_tick_first_person` drops the stance
	# immediately while anything owns the screen — one run in three landed the tap
	# inside that window and reported a dead toggle. The retry is the honest
	# reading: the mode is not broken, the press was early.
	await rig.wait_seconds(1.0)
	_tap(&"first_person")
	await rig.wait_seconds(0.5)
	if not _cam.first_person():
		_tap(&"first_person")
		await rig.wait_seconds(0.5)
	_check("in first person", _cam.first_person())
	await _shot(rig, "fp_in")

	# --- 1. The mouse turns the head ----------------------------------------
	var yaw0 := _yaw_deg()
	for i in 4:
		await _drag(rig, Vector2(26.0, 0.0), 10)
		await _shot(rig, "mouse_yaw")
	var turned := absf(wrapf(_yaw_deg() - yaw0, -180.0, 180.0))
	_check("the mouse turned the head (%.0f°)" % turned, turned > 30.0)

	var pitch0 := _pitch_deg()
	await _drag(rig, Vector2(0.0, -30.0), 10)
	await _shot(rig, "mouse_pitch")
	var lifted := _pitch_deg() - pitch0
	# Up on the mouse must LOOK UP. The sign is worth asserting rather than the
	# magnitude alone: `_apply_look` inverts through `Settings.invert_camera_y`,
	# and an inverted default would still move the frame and still photograph.
	_check("and pitched it up (%+.0f°)" % lifted, lifted > 6.0)

	# --- 2. RMB puts it back ------------------------------------------------
	# Zero it first, so the shove below is measured from his facing rather than
	# from wherever step 1 happened to leave the head. Without this the two
	# rotations partly cancel and the "before" error is whatever arithmetic falls
	# out — which is exactly how this beat first read 36° when it meant 168°.
	Input.action_press(&"shield", 1.0)
	await rig.wait_seconds(0.3)
	Input.action_release(&"shield")
	await rig.wait_seconds(0.2)

	# Deliberately shoved a long way off: a recentre that only closes a few
	# degrees is indistinguishable from the camera drifting on its own.
	await _drag(rig, Vector2(40.0, -30.0), 12)
	var facing := _behind_deg()
	var err_before := absf(wrapf(_yaw_deg() - facing, -180.0, 180.0))
	var pitch_before := _pitch_deg()
	var hero_before := _hero_yaw_deg()
	_check("shoved off his facing first (%.0f°)" % err_before, err_before > 45.0)
	await _shot(rig, "preRMB")

	# `Input.action_press`, not a parsed InputEventAction: the guard is a HOLD and
	# `Targeting._read_guard` reads it by diffing `is_action_pressed` against a
	# stored flag, exactly so a polled press behaves like a real trigger pull.
	Input.action_press(&"shield", 1.0)
	await rig.wait_seconds(0.03)
	for i in 4:
		await rig.wait_seconds(0.05)
		await _shot(rig, "rmb_recenter")
	Input.action_release(&"shield")
	await rig.wait_seconds(0.1)

	var err_after := absf(wrapf(_yaw_deg() - _behind_deg(), -180.0, 180.0))
	_check("RMB put the view back down his facing (%.0f° -> %.0f°)"
		% [err_before, err_after], err_after < 6.0)
	# The other half of "reset": a face-forward that leaves you staring at the
	# ceiling has not faced you forward. Only in here — out on the boom the pitch
	# is the shot and the player picked it.
	_check("and levelled the pitch (%+.0f° -> %+.0f°, rest %+.0f°)"
		% [pitch_before, _pitch_deg(), -_cam.pitch_deg],
		absf(_pitch_deg() + _cam.pitch_deg) < 4.0)
	# The control. If the hero had turned to the lens instead, `err_after` would
	# also read ~0 and this whole beat would pass while doing the opposite thing.
	var hero_moved := absf(wrapf(_hero_yaw_deg() - hero_before, -180.0, 180.0))
	_check("the CAMERA moved, not the hero (%.1f° of body)" % hero_moved,
		hero_moved < 3.0)
	_check("and he is still in first person", _cam.first_person())
	await _shot(rig, "postRMB")

	# --- 3. Out again, and the guard comes back -----------------------------
	_tap(&"first_person")
	await rig.wait_seconds(0.5)
	_check("a second press leaves", not _cam.first_person())
	Input.action_press(&"shield", 1.0)
	await rig.wait_seconds(0.35)
	_check("and out here RMB raises the shield again", _blocking())
	await _shot(rig, "third_guard")
	Input.action_release(&"shield")
	await rig.wait_seconds(0.3)

	print("FPLOOK OK" if _fail == 0 else "FPLOOK FAILED (%d)" % _fail)


# --- Reads -------------------------------------------------------------------

## Where the lens LOOKS, flattened. Read off the transform rather than the
## camera's private `_yaw` so this measures the frame the player sees.
func _yaw_deg() -> float:
	var f := K.flat(-_cam.global_transform.basis.z)
	if f == Vector3.ZERO:
		return 0.0
	return rad_to_deg(atan2(f.x, f.z))


## Elevation of the VIEW, positive when looking up — which is the opposite sign
## to the camera's own `_pitch`. That is not a slip: `_pitch` is how far the EYE
## sits above the at-point, and an eye above the hero looks DOWN at him. So the
## resting view elevation in here is `-pitch_deg`, and "up on the mouse looks up"
## reads as a rising number the way a player would say it.
func _pitch_deg() -> float:
	return rad_to_deg(asin(clampf(-_cam.global_transform.basis.z.y, -1.0, 1.0)))


## The direction the hero's body is pointing, in the same frame as `_yaw_deg`.
func _behind_deg() -> float:
	var f := K.flat(-_hero.global_transform.basis.z)
	if f == Vector3.ZERO:
		return 0.0
	return rad_to_deg(atan2(f.x, f.z))


func _hero_yaw_deg() -> float:
	return _behind_deg()


func _blocking() -> bool:
	var c = _hero.get("combat")
	if c == null:
		return false
	return bool(c.get("blocking"))


# --- Input -------------------------------------------------------------------

## A real event: `GameCamera` reads `first_person` in `_unhandled_input`, and
## `Input.action_press` dispatches no InputEvent at all (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Push `count` real mouse-motion events, then let a physics tick consume them.
## The capture gate is opened only while they are in flight — outside that window
## a stray twitch of the real mouse over the harness window must not walk the yaw.
func _drag(rig, rel: Vector2, count: int) -> void:
	_cam.mouse_look_requires_capture = false
	for i in count:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		ev.screen_relative = rel
		ev.velocity = rel * 60.0
		Input.parse_input_event(ev)
	await rig.wait_seconds(0.05)
	_cam.mouse_look_requires_capture = true


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("FPLOOK FAIL %s" % what)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
