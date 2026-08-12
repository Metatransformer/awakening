extends RefCounted
## Photographs every run cycle in the library, with the sword and shield in his
## hands, so somebody can say which one a player would want to look at for the
## whole game.
##
## The run is the most-seen animation in the project by an enormous margin — it
## is what the hero is doing during almost every second of traversal — and it
## was picked the way `swing_lookdev` says not to pick things: off a filename.
## `ss_run_01` is the sword-and-shield pack's own run, chosen because the idle
## and walk came from that pack, and nobody has photographed it since.
##
## TWO ANGLES, and both are load-bearing:
##   - **3/4 front** reads the ARMS and what they are doing with the weapons.
##   - **SIDE** reads the two things a run lives or dies on and which are
##     invisible head-on: the forward LEAN of the torso, and the STRIDE — how
##     far the feet actually travel apart. A run photographed only from the
##     front is a man bouncing.
##
## The weapons are mounted for the same reason the strafe sheet is a burst: the
## question is not "is this a good run" in the abstract, it is "is this a good
## run FOR THIS HERO", and this hero has a metre of steel in his right fist and
## a shield strapped to his left forearm. A clip authored for empty hands can
## look fine bare and read as a man flapping once the props are on.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/run_lookdev.gd --out=/tmp/run/x.png
##
## Then tile each clip's burst into one strip (no ImageMagick on this machine):
##   for c in /tmp/run/*_front_0.png; do b=${c%_0.png}; \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=6x1 "${b}_sheet.png"; done

## Every full-speed run cycle the library holds. `ss_run_01` first because it is
## what ships, so the rest are judged against it rather than against each other.
const CLIPS: Array[StringName] = [
	&"ss_run_01",      # WAS the run blend point; kept here as the reference
	&"ss_run_02",      # second authored sword-and-shield run, supplied with 01
	&"ex_running",     # in use: the run blend point, decided on this sheet
	&"ex_fast_run",    # in use: the sprint blend point, here for the cadence
]

## Frames across each cycle. Six samples a ~0.65 s run at roughly every other
## contact, which is enough to see both feet plant and both arms reach their
## extremes — the four poses a run actually has.
const FRAMES := 6

## Where the lens sits relative to the hero, and how high it looks. Both cameras
## are at chest height rather than eye height: a run's information is in the
## hips and the knees, and a lens at 1.65 m looks down over the top of it.
## The side lens is on −X and not +X, which is not a taste call: the training
## room's raised ledge is on the hero's sword side, and a camera parked there
## sits INSIDE it — the first run of this director came back with six frames of
## stone slab and a hero visible from the shoulders up, forty metres away. −X
## presents his shield side to the lens across open floor.
const FRONT_OFFSET := Vector3(1.6, 1.35, 2.4)
const SIDE_OFFSET := Vector3(-3.2, 1.35, 0.0)
const LOOK_AT := Vector3(0.0, 0.95, 0.0)


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/run/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("RUN FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): 0 means heading
	# (0,0,+1), so he faces the front camera parked out on +Z and presents his
	# left side to the side camera out on +X.
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_frames(20)

	# The sword is the whole reason for this sheet, so refuse to shoot without
	# it rather than producing a bare-handed sheet that answers the wrong
	# question.
	if hero.combat == null or hero.combat.sword == null:
		print("RUN FAIL no sword mounted — this sheet is about the props")
		return
	if not (hero.combat.sword as Node3D).is_visible_in_tree():
		print("RUN FAIL the sword is not in his hand")
		return

	# The AnimationTree drives the rig every frame; it has to let go before the
	# AnimationPlayer can be scrubbed by hand, or the clip is overwritten with
	# the locomotion blend on the very next tick.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree != null:
		tree.active = false

	var skel: Skeleton3D = hero.skeleton()
	if skel == null:
		print("RUN FAIL no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null:
		print("RUN FAIL no AnimationPlayer")
		return

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("RUN FAIL no camera")
		return
	# GameCamera IS the Camera3D and re-derives its own transform in
	# _physics_process, so placing it and then waiting two frames places it
	# nowhere. Take its hands off the wheel first — swing_lookdev learned this
	# the expensive way.
	cam.set_physics_process(false)

	# The training room is authored dark and a run is read off limb silhouettes.
	# The hero's own KeyLight is a 3.4 m lamp tuned to keep him off black, not to
	# separate a trailing leg from the leg in front of it.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.2
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(1.5, 2.6, 2.0)
	rig.scene().add_child(lamp)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("RUN %-14s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		print("RUN %-14s len=%.3fs -> %d frames" % [clip, length, FRAMES])
		for angle in ["front", "side"]:
			var offset: Vector3 = FRONT_OFFSET if angle == "front" else SIDE_OFFSET
			for i in FRAMES:
				player.play(clip)
				# Sample inside the cycle rather than at its ends: frame 0 of a
				# Mixamo clip is the neutral pose every one of them shares, so a
				# burst that starts at 0 wastes a frame saying nothing.
				player.seek(length * (float(i) + 0.5) / float(FRAMES), true)
				cam.global_position = hero.global_position + offset
				cam.look_at(hero.global_position + LOOK_AT, Vector3.UP)
				await rig.wait_frames(2)
				await rig.capture(out.path_join("%s_%s_%d.png" % [clip, angle, i]))

	if tree != null:
		tree.active = true
	print("RUN done")
