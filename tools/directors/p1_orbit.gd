extends RefCounted
## P1 — the look controls, in the order they have to survive:
##
##   1. mouse orbit standing still (real InputEventMouseMotion, not a shortcut);
##   2. right-stick orbit the other way (cam_left);
##   3. pitch to the K.CAM_MAX_PITCH clamp and back down to K.CAM_MIN_PITCH;
##   4. run WITHOUT touching the look — K.CAM_AUTOSWING drifts back behind him;
##   5. a `z_target` tap with no target: Bus.camera_recenter, the OOT Parallel
##      snap, which is far faster than the drift in step 4.
##
## Step 4 is the one that catches a camera that fights the player: the autoswing
## must not start until `manual_hold_time` has elapsed since the last look.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0


func run(rig) -> void:
	Input.use_accumulated_input = false
	await rig.wait_seconds(0.4)
	await _shot(rig, "behind")

	# 1. Mouse orbit left, ~45 degrees a shot.
	for i in 5:
		await _drag(rig, Vector2(18.0, 0.0), 12)
		await _shot(rig, "mouse")

	# 2. Right stick, back the other way.
	for i in 4:
		Input.action_press(&"cam_left", 1.0)
		await rig.wait_seconds(0.25)
		Input.action_release(&"cam_left")
		await rig.wait_seconds(0.05)
		await _shot(rig, "stick")

	# 3. Pitch to the clamps and back.
	for i in 3:
		await _drag(rig, Vector2(0.0, 22.0), 10)
		await _shot(rig, "pitchup")
	for i in 3:
		await _drag(rig, Vector2(0.0, -22.0), 14)
		await _shot(rig, "pitchdn")

	# 4. Hands off the look: autoswing takes the yaw back while he runs.
	Input.action_press(&"move_up", 1.0)
	for i in 7:
		await rig.wait_seconds(0.4)
		await _shot(rig, "swing")
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.6)

	# 5. Orbit off-axis again, then tap Z with nothing lockable.
	for i in 3:
		await _drag(rig, Vector2(-20.0, 0.0), 12)
		await _shot(rig, "offaxis")
	Input.action_press(&"z_target")
	await rig.wait_seconds(0.05)
	Input.action_release(&"z_target")
	for i in 4:
		await rig.wait_seconds(0.06)
		await _shot(rig, "recenter")


## Push `count` real mouse-motion events, then let a physics tick consume them.
func _drag(rig, rel: Vector2, count: int) -> void:
	for i in count:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		ev.screen_relative = rel
		ev.velocity = rel * 60.0
		Input.parse_input_event(ev)
	await rig.wait_seconds(0.05)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
