extends RefCounted
## P1 — the look controls, measured. Runs headless (no captures).
##
## A contact sheet can show that the camera moved; it cannot show that the pitch
## stopped exactly at K.CAM_MAX_PITCH, or that a Z tap closed the whole yaw error
## in four ticks rather than merely drifting in the right direction. Those are
## numbers, so this prints numbers.
##
##   godot --headless --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/rooms/playtest.tscn \
##       --director=res://tools/directors/p1_look_audit.gd --warmup=20

var _cam: Camera3D = null


func run(rig) -> void:
	var hero: Node3D = rig.get_first_node_in_group(&"player")
	_cam = rig.root.get_camera_3d()
	Input.use_accumulated_input = false
	await rig.wait_seconds(0.4)

	print("start yaw=%6.1f pitch=%5.1f fov=%4.1f" % [_yaw_deg(), _pitch_deg(), _cam.fov])

	# Mouse yaw. The raw burst is 12 x 18 px x 0.0035 = 43.3 deg, then scaled by
	# the player's Settings.camera_sensitivity, so the absolute figure is a
	# preference and not an assertion — what matters is that it moves, keeps its
	# sign, and stays smooth.
	for i in 4:
		await _drag(rig, Vector2(18.0, 0.0), 12)
	print("after 4 mouse bursts yaw=%6.1f (wrapped; sensitivity %.2f)"
			% [_yaw_deg(), Settings.camera_sensitivity])

	# Right stick the other way: 170 deg/s.
	for i in 4:
		Input.action_press(&"cam_left", 1.0)
		await rig.wait_seconds(0.25)
		Input.action_release(&"cam_left")
		await rig.wait_seconds(0.05)
	print("after 4 stick bursts yaw=%6.1f" % _yaw_deg())

	# Pitch hard into both clamps and check they hold.
	for i in 6:
		await _drag(rig, Vector2(0.0, 30.0), 12)
	print("pitch pinned up   = %5.1f (clamp %5.1f)" % [_pitch_deg(), K.CAM_MAX_PITCH])
	for i in 12:
		await _drag(rig, Vector2(0.0, -30.0), 12)
	print("pitch pinned down = %5.1f (clamp %5.1f)" % [_pitch_deg(), K.CAM_MIN_PITCH])
	for i in 6:
		await _drag(rig, Vector2(0.0, 30.0), 12)

	# Autoswing: knock the yaw off-axis, run, hands off the look.
	await _drag(rig, Vector2(-14.0, 0.0), 12)
	await _drag(rig, Vector2(-14.0, 0.0), 12)
	var err0 := _behind_err_deg(hero)
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(1.6)
	Input.action_release(&"move_up")
	print("autoswing err %5.1f -> %5.1f deg over 1.6 s of running" % [err0, _behind_err_deg(hero)])
	await rig.wait_seconds(0.5)

	# Parallel: a Z tap with nothing lockable must close the whole error inside the
	# 4 ticks of CAM_DEFAULT_ANIM_TIME, and pull the FOV toward CAM_FOV_PARALLEL
	# while it does.
	#
	# **Both of these lines used to print numbers that could not mean what they
	# said** — this was the one director that never worked around #40. The presses
	# were `Input.action_press`, which sets action state and dispatches no
	# `InputEvent` (CLAUDE.md §3), and `Targeting` reads `z_target` in
	# `_unhandled_input`; so nothing was ever delivered, and the audit reported
	# "recentre err 52.9 -> 52.9 deg" and "held fov=60.0" as though the camera had
	# been asked and declined. `rig.tap` sends the event now.
	#
	# ONE TAP, and no hold. `z_target` is a TOGGLE that `Targeting` owns
	# (docs/CONTRACT.md §4), and the parallel FOV is keyed off the recentre TIMER
	# rather than off the button being down (`GameCamera._apply_parallel` says so in
	# as many words) — so "hold Z and read the FOV" measures nothing at all, and a
	# second press would only fire a second recentre. What is honest here is the
	# LOW-WATER MARK across the recentre: 4 ticks of a 0.25 s FOV blend cannot
	# arrive at 45, so the assertion is that it leaves CAM_FOV in the direction of
	# CAM_FOV_PARALLEL and comes back.
	await _drag(rig, Vector2(-22.0, 0.0), 12)
	var before := _behind_err_deg(hero)
	var fov0 := _cam.fov
	await rig.tap(["z_target"])
	var fov_low := _cam.fov
	for i in 12:
		await rig.wait_seconds(4.0 * K.TICK / 12.0)
		fov_low = minf(fov_low, _cam.fov)
	print("Z tap recentre err %5.1f -> %5.1f deg in 4 ticks" % [before, _behind_err_deg(hero)])
	print("Z tap fov %4.1f -> %4.1f low (free %4.1f, parallel %4.1f)"
			% [fov0, fov_low, K.CAM_FOV, K.CAM_FOV_PARALLEL])


func _yaw_deg() -> float:
	return rad_to_deg(wrapf(_cam.get(&"_yaw"), -PI, PI))


func _pitch_deg() -> float:
	return _cam.get(&"_pitch")


## How far the camera is from sitting squarely behind the hero, in degrees.
func _behind_err_deg(hero: Node3D) -> float:
	return absf(rad_to_deg(wrapf(_cam.behind_yaw() - _cam.get(&"_yaw"), -PI, PI)))


func _drag(rig, rel: Vector2, count: int) -> void:
	_cam.mouse_look_requires_capture = false
	for i in count:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		ev.screen_relative = rel
		Input.parse_input_event(ev)
	await rig.wait_seconds(0.05)
	_cam.mouse_look_requires_capture = true
