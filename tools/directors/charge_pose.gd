extends RefCounted
## What the hero looks like while the spin is winding up.
##
## `charge_pose_time` is a FRAME of `ss_slash_01` held for as long as the button
## is down (hero.gd §Charge), and there is no way to pick that number except by
## looking: "the bottom of the swing, blade out to his left" is a silhouette, and
## the clip's own timeline says nothing about where the arm is. So this shoots
## two sheets.
##
##   a_*  the clip SCRUBBED across its whole length, from the same 3/4 front
##        camera swing_lookdev uses. Read the frame you want off these; the
##        filename carries the timestamp to put in `charge_pose_time`.
##   b_*  the LIVE hold, from the game camera, with the button actually held.
##        This is the one that matters — the scrub is the clip alone, and the
##        hold is that clip eased in over whatever the locomotion was doing. A
##        pose that reads in `a` and not in `b` is not a pose the player will
##        ever see.
##
##        It used to be that clip blended under a light swing that was still
##        finishing, because the press that started the hold threw one. It does
##        not any more: one pull of the trigger is one blow, and the wind-up is
##        now the FIRST thing the player sees rather than something arriving
##        under a swing. That makes this sheet a stricter test than it was —
##        there is no swing left to hide a weak pose behind.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/charge_pose.gd --out=/tmp/pose/x.png
##
## NEVER pass --headless. There is no rendering device and every frame comes out
## empty, silently (CLAUDE.md §2).

## How many samples across the clip. 14 over a ~1.3 s slash is a frame every
## 0.09 s, which is fine enough to land on a follow-through that lasts about a
## fifth of a second.
const SCRUB := 14


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/pose/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("POSE FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): 0 means heading
	# (0,0,+1), so he faces a camera parked out on +Z.
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_frames(20)

	var clip: StringName = hero.get(&"clip_attack")
	var held: float = float(hero.get(&"charge_pose_time"))

	# --- a: the clip, scrubbed -------------------------------------------------
	# The AnimationTree drives the rig every frame and has to let go before the
	# AnimationPlayer can be scrubbed by hand, or the pose is overwritten with the
	# locomotion blend on the very next tick.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	var skel: Skeleton3D = hero.skeleton()
	if skel == null:
		print("POSE FAIL no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null or not player.has_animation(clip):
		print("POSE FAIL no AnimationPlayer with %s on it" % clip)
		return
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("POSE FAIL no camera")
		return

	if tree != null:
		tree.active = false
	# GameCamera IS the Camera3D and re-derives its transform in _physics_process,
	# so placing it and waiting places it nowhere. Take its hands off the wheel.
	cam.set_physics_process(false)

	var length := player.get_animation(clip).length
	print("POSE %s is %.2f s; charge_pose_time is %.2f" % [clip, length, held])
	for i in SCRUB:
		var t := length * float(i) / float(SCRUB - 1)
		player.play(clip)
		player.seek(t, true)
		# 3/4 front, close enough that the blade is legible against the body —
		# from behind, every swing is a sword briefly appearing beside his head.
		cam.global_position = hero.global_position + Vector3(1.5, 1.5, 2.6)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.wait_frames(2)
		await rig.capture(out.path_join("a_%02d_t%.2f.png" % [i, t]))

	# --- b: the live hold ------------------------------------------------------
	player.stop()
	cam.set_physics_process(true)
	if tree != null:
		tree.active = true
	await rig.wait_seconds(1.2)

	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("POSE FAIL no HeroCombat on the Hero")
		return

	# `heavy`, not `attack`: the wind-up lives on the trigger. RB charges nothing.
	Input.action_press(&"heavy")
	# Wait on the ARMED FLAG, not on a frame count: capture() stalls the frame
	# clock, so N frames of waiting is not N/60 of a second of holding.
	var lit := false
	for i in 10:
		await rig.wait_frames(6)
		await rig.capture(out.path_join("b_%02d_hold.png" % i))
		lit = bool(combat.get(&"charged"))
		if lit:
			break
	# Two more once it is armed — the pose has to still be there at the top of the
	# hold, not just on the way into it.
	for i in 2:
		await rig.wait_frames(10)
		await rig.capture(out.path_join("b_armed_%d.png" % i))
	Input.action_release(&"heavy")

	if not lit:
		print("POSE FAIL the hold never armed — the b sheet is of a tap")
		return
	print("POSE OK — read charge_pose_time off the a_ sheet, judge it on the b_ sheet")
