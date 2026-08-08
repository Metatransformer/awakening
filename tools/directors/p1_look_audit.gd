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

	# Parallel: a Z tap with nothing lockable must close the whole error in the
	# 4 ticks of CAM_DEFAULT_ANIM_TIME, and drop the FOV to CAM_FOV_PARALLEL.
	await _drag(rig, Vector2(-22.0, 0.0), 12)
	var before := _behind_err_deg(hero)
	Input.action_press(&"z_target")
	await rig.wait_seconds(0.03)
	Input.action_release(&"z_target")
	await rig.wait_seconds(4.0 * K.TICK + 0.02)
	print("Z tap recentre err %5.1f -> %5.1f deg in 4 ticks" % [before, _behind_err_deg(hero)])

	Input.action_press(&"z_target")
	await rig.wait_seconds(0.6)
	print("Z held fov=%4.1f (free %4.1f, parallel %4.1f)" % [_cam.fov, K.CAM_FOV, K.CAM_FOV_PARALLEL])
	Input.action_release(&"z_target")


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
