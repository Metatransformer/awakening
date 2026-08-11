extends RefCounted
## Photographs every swing clip in the library so somebody can say what each one
## actually DOES with the sword.
##
## The library ships 9 swing clips under names that carry no information —
## `ss_attack_03` could be an overhead, a thrust or a horizontal sweep, and the
## only two the game uses were chosen off their filename and duration. That is
## the same mistake as reading facing off a rest-pose bone track (CLAUDE.md §4):
## the answer is in the render, not in the metadata.
##
## FRAMES is a burst, not a screenshot, for the reason strafe_lookdev gives: a
## single frame cannot tell you whether a wind-up reads. An overhead and a
## horizontal sweep are indistinguishable at the moment of contact and obvious
## three frames earlier.
##
## The camera sits front-right rather than behind. From behind, every swing is a
## sword briefly appearing beside the hero's head; from 3/4 front you can see
## which way the blade travels and how far the body commits to it.
##
## Shot in the training room, not the garrison: the garrison is lit for night
## and the hero reads as a silhouette in it, which is exactly the information a
## swing lookdev needs to keep.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/swing_lookdev.gd --out=/tmp/swing/x.png
##
## Then tile each clip's burst into one strip (no ImageMagick on this machine):
##   for c in /tmp/swing/*_0.png; do b=${c%_0.png}; \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=5x1 "${b}_sheet.png"; done

## Every swing in the library, with the two the game already uses first so they
## are the reference the rest are judged against.
const CLIPS: Array[StringName] = [
	# The spin, first because it is the only clip here from another character's
	# moveset: the sword-and-shield set has no 360 in it at all, so the charged
	# release borrows one (build_anim_lib.gd §ONLY). It was picked over
	# `ax_melee_attack_360_high` and `gs_high_spin_attack_1` in this very sheet —
	# the high one swings behind the body and the greatsword one is posed around
	# a two-handed hilt. Neither is baked any more; re-add them to ONLY if the
	# choice ever wants re-litigating.
	&"ax_melee_attack_360_low",  # in use: the charged spin attack
	&"ss_slash_01",     # in use: light attack
	&"ss_attack_01",    # in use: heavy attack
	&"ss_slash_02", &"ss_slash_03", &"ss_slash_04", &"ss_slash_05",
	&"ss_attack_02", &"ss_attack_03", &"ss_attack_04",
	&"ss_kick_01", &"ss_power_up_01",
	# The `ex_` set, which CONTRACT.md §2 lists and nothing has ever played.
	# At 4.53 s and 2.73 s these are almost certainly MULTI-HIT sequences —
	# whole combos in one clip — which is a different thing from the single
	# swings above and would be built a different way.
	&"ex_sword_combo_light", &"ex_sword_combo_heavy",
]

## Roughly a frame every 0.35 s of clip, so a 1 s swing gets the 5 that read an
## arc and a 4.5 s combo gets enough to count the hits in it. A fixed count
## would photograph the long clips too sparsely to see where one swing ends and
## the next begins — which is the entire question being asked of them.
const FRAME_EVERY := 0.35
const FRAMES_MIN := 5
const FRAMES_MAX := 13


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/swing/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("SWING FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): 0 means heading
	# (0,0,+1), so he faces the camera parked out on +Z.
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_frames(10)

	# The AnimationTree drives the rig every frame; it has to let go before the
	# AnimationPlayer can be scrubbed by hand, or the clip is overwritten with
	# the locomotion blend on the very next tick.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree != null:
		tree.active = false

	var skel: Skeleton3D = hero.skeleton()
	if skel == null:
		print("SWING FAIL no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null:
		print("SWING FAIL no AnimationPlayer")
		return

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("SWING FAIL no camera")
		return
	# GameCamera IS the Camera3D and re-derives its own transform in
	# _physics_process, so placing it and then waiting two frames places it
	# nowhere. Take its hands off the wheel first — this is why the first run of
	# this director came back with a hero 40 px tall in a wide shot of the
	# garrison.
	cam.set_physics_process(false)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("SWING %-16s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		var frames := clampi(int(round(length / FRAME_EVERY)), FRAMES_MIN, FRAMES_MAX)
		print("SWING %-22s len=%.2fs -> %d frames" % [clip, length, frames])
		for i in frames:
			player.play(clip)
			# Sample inside the clip rather than at its ends: frame 0 of a Mixamo
			# clip is the neutral T-adjacent pose every one of them shares, so a
			# burst that starts at 0 wastes a frame saying nothing.
			player.seek(length * (float(i) + 0.5) / float(frames), true)
			# Close enough that the blade is legible: the hero is 1.65 m and this
			# sits ~3.3 m out, so he fills most of the frame height.
			cam.global_position = hero.global_position + Vector3(1.5, 1.5, 2.6)
			cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("%s_%d.png" % [clip, i]))

	if tree != null:
		tree.active = true
	print("SWING done: %d clips" % CLIPS.size())
