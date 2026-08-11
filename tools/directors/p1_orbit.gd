extends RefCounted
## P1 — the look controls, in the order they have to survive:
##
##   1. mouse orbit standing still (real InputEventMouseMotion, not a shortcut);
##   2. right-stick orbit the other way (cam_left);
##   3. pitch to the K.CAM_MAX_PITCH clamp and back down to K.CAM_MIN_PITCH;
##   4. run WITHOUT touching the look — K.CAM_AUTOSWING drifts back behind him;
##   5. a `z_target` tap with no target: Bus.camera_recenter, the OOT Parallel
##      snap, which is far faster than the drift in step 4;
##   6. the same snap off the OTHER route — a `shield` PULL with no target. On a
##      pad that is the left trigger, and it is the one a player actually finds.
##
## Step 4 is the one that catches a camera that fights the player: the autoswing
## must not start until `manual_hold_time` has elapsed since the last look.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0
var _cam: Camera3D = null


func run(rig) -> void:
	Input.use_accumulated_input = false
	# GameCamera ignores mouse motion unless the cursor is grabbed, and the
	# harness never grabs it (that would hijack the machine mid-capture). Opt in
	# so the synthetic motion below travels the real _unhandled_input path.
	_cam = rig.root.get_camera_3d()

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

	# Level the pitch again so steps 4 and 5 are shot from the playing angle
	# rather than from wherever the clamp test left the lens.
	await _drag(rig, Vector2(0.0, 12.0), 8)

	# 4. Steer off-axis, then run with hands OFF the look. Autoswing has to bring
	# the yaw back behind him on its own — and must not start before
	# `manual_hold_time` has elapsed, or it is fighting the player's own steering.
	# Short bursts keep him in the lit middle of the room; a long run just parks
	# him in a dark corner where nothing is legible.
	await _drag(rig, Vector2(-20.0, 0.0), 12)
	await _shot(rig, "offaxis")
	Input.action_press(&"move_up", 1.0)
	for i in 6:
		await rig.wait_seconds(0.28)
		await _shot(rig, "swing")
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.5)

	# 5. Knock it off-axis once more, then tap the camera button with nothing
	# lockable. Parallel recentres over CAM_DEFAULT_ANIM_TIME = 4 ticks, so these
	# frames are 0.05 s apart — any slower and the snap is over before the second
	# exposure.
	#
	# On a pad this is R3 — the standing toggle. Step 6 covers the trigger.
	#
	# `rig.tap`, which sends a real InputEventAction as well as setting the action
	# state (#40). `Targeting` reads this button in `_unhandled_input` — it queues
	# the press so a slow physics tick cannot drop the edge — and the harness's old
	# `Input.action_press` set the state while dispatching no InputEvent at all
	# (CLAUDE.md §3). This step photographed a camera that never moved for as long
	# as it was written that way, which is what carded #40; the local workaround it
	# grew is gone now that `rig.tap` is honest.
	await _drag(rig, Vector2(-22.0, 0.0), 12)
	await _shot(rig, "preZ")
	await rig.tap(["z_target"])
	await rig.wait_seconds(0.03)
	for i in 5:
		await rig.wait_seconds(0.05)
		await _shot(rig, "recenter")

	# 6. The other route in, and the one the pad actually uses: pull the GUARD
	# with nothing lockable. `Targeting._read_guard` acquires on the pull and,
	# finding nothing, recentres — once, on the pull, never on the rescan.
	#
	# `Input.action_press` is correct here where it was wrong above: the guard is
	# a HOLD and targeting.gd reads it by diffing `is_action_pressed` against a
	# stored `_shield_down`, precisely so that polled and synthetic presses behave
	# the same. shoot.gd has stripped the joypad bindings, so the trigger itself
	# cannot be pulled — the ACTION is what is under test.
	await _drag(rig, Vector2(24.0, 0.0), 12)
	await _shot(rig, "preGuard")
	Input.action_press(&"shield", 1.0)
	await rig.wait_seconds(0.03)
	for i in 5:
		await rig.wait_seconds(0.05)
		await _shot(rig, "guardRecenter")
	Input.action_release(&"shield")



## Push `count` real mouse-motion events, then let a physics tick consume them.
##
## The gate is opened only for the handful of milliseconds the synthetic events
## are in flight. Outside that window the camera ignores mouse motion (the
## cursor is not grabbed), so a stray twitch of the real mouse over the harness
## window cannot walk the yaw and silently invalidate the run — which is exactly
## how an earlier corridor sheet ended up showing the hero curving into a wall.
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


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
