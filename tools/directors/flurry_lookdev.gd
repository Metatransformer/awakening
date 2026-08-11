extends RefCounted
## Photographs the two clips the parry and the flurry attack are built on,
## because a filename is not a pose (dodge_lookdev.gd made this argument first,
## and swing_lookdev.gd paid for it).
##
## Both arrived as raw Mixamo exports named after the store page they came from —
## "Sword And Shield Block (1)" and "Sword And Shield Attack" — so the ONLY thing
## known about either before this ran was its hips track:
##
##   ex_parry        0.67 s. Rotation peaks at 0.20 and is spent by 0.50; the
##                   hips climb 0.41 -> 0.48 and hold. A short, planted shove.
##   ex_jump_attack  2.33 s. Crouches to 0.467 by 0.37, leaves the ground, apex
##                   1.00 at 0.83-0.90, comes down through a rotation spike at
##                   1.20, bottoms out in a deep landing crouch at 1.50, and is
##                   back on its feet by 2.10. A real leap with a strike in it.
##
## Those are translations and rotations. Whether the first reads as a SHIELD BASH
## rather than a punch, and whether the second's strike is overhead rather than
## horizontal, are render questions.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/flurry_lookdev.gd --out=/tmp/flurry/x.png
##
## Then tile each clip's burst into one strip:
##   for c in /tmp/flurry/*_0.png; do b=${c%_0.png}; \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=6x2 "${b}_sheet.png"; done

const CLIPS: Array[StringName] = [&"ex_parry", &"ex_jump_attack"]
## Tighter than dodge_lookdev's 0.18: the parry's whole read is a 0.2 s shove,
## and at that spacing it would get four frames of which two are the settle.
const FRAME_EVERY := 0.11
const FRAMES_MIN := 6
const FRAMES_MAX := 12


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/flurry/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("FLURRY FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_frames(10)

	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree != null:
		tree.active = false

	var skel: Skeleton3D = hero.skeleton()
	if skel == null:
		print("FLURRY FAIL no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null:
		print("FLURRY FAIL no AnimationPlayer")
		return

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("FLURRY FAIL no camera")
		return
	cam.set_physics_process(false)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("FLURRY %-18s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		var frames := clampi(int(round(length / FRAME_EVERY)), FRAMES_MIN, FRAMES_MAX)
		print("FLURRY %-18s len=%.2fs -> %d frames" % [clip, length, frames])
		for i in frames:
			player.play(clip)
			player.seek(length * (float(i) + 0.5) / float(frames), true)
			# Front-LEFT, which is the one place dodge_lookdev's camera would have
			# been wrong here: the shield is on the hero's left arm, and from
			# front-right the bash happens behind his own body.
			cam.global_position = hero.global_position + Vector3(-2.1, 1.7, 3.2)
			cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("%s_%d.png" % [clip, i]))

	if tree != null:
		tree.active = true
	print("FLURRY done: %d clips" % CLIPS.size())
