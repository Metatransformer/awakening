extends RefCounted
## Photographs the dodge clips and the thrust candidates, because neither
## question can be answered from a filename.
##
## Two things are being asked here:
##
##   1. **Which clips are the four dodges.** The Pro Sword and Shield Pack ships
##      no roll of any kind — 52 clips, not one of them a dodge — so the roll has
##      always been `ex_roll_to_run`, a forward dive, played for the backstep and
##      the sidehop too. The longbow set has a real four-way dodge set. Whether
##      those read as dodges on THIS rig, and which way each one actually travels,
##      is a render question.
##   2. **Which clip is the thrust.** The dash attack needs a blade going forward,
##      and `ss_slash_05` / `ss_attack_03` / `ss_attack_04` are names, not poses.
##      swing_lookdev.gd made this same mistake's fix for the heavy.
##
## Camera sits front-right, same as swing_lookdev, for the same reason: from
## behind, a backstep and a sidehop are both "the hero gets smaller".
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/dodge_lookdev.gd --out=/tmp/dodge/x.png
##
## Then tile each clip's burst into one strip:
##   for c in /tmp/dodge/*_0.png; do b=${c%_0.png}; \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=6x1 "${b}_sheet.png"; done

const CLIPS: Array[StringName] = [
	# In use, and the thing the challengers are judged against.
	&"ex_roll_to_run", &"bow_dodge_back",
	&"bow_dodge_left", &"bow_dodge_right",
	# The owner's four. The measured tracks already say `ex_dodge_left/right` are
	# the same Mixamo clip as the longbow pair — 0.97 s, 1.04 m and 1.07 m, to the
	# centimetre — so what is actually in question for those two is the *pose*:
	# the longbow export may be carrying a bow the standing one is not. That is a
	# render question and nothing else can answer it.
	&"ex_backflip", &"ex_dive_forward",
	&"ex_dodge_left", &"ex_dodge_right",
]

## A dodge is over in a second and its whole read is in the middle of it, so this
## samples tighter than swing_lookdev's 0.35 s — at that spacing a 0.97 s sidehop
## gets three frames and none of them is the hop.
const FRAME_EVERY := 0.18
const FRAMES_MIN := 6
const FRAMES_MAX := 12


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	var out: String = rig.arg("out", "/tmp/dodge/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("DODGE FAIL no node in group `player`")
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
		print("DODGE FAIL no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null:
		print("DODGE FAIL no AnimationPlayer")
		return

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("DODGE FAIL no camera")
		return
	cam.set_physics_process(false)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("DODGE %-22s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		var frames := clampi(int(round(length / FRAME_EVERY)), FRAMES_MIN, FRAMES_MAX)
		print("DODGE %-22s len=%.2fs -> %d frames" % [clip, length, frames])
		for i in frames:
			player.play(clip)
			player.seek(length * (float(i) + 0.5) / float(frames), true)
			# Further out than swing_lookdev's 2.6 m: a dodge THROWS the body, and
			# a frame cropped at the knees cannot show you which way it went.
			cam.global_position = hero.global_position + Vector3(1.9, 1.8, 3.4)
			cam.look_at(hero.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("%s_%d.png" % [clip, i]))

	if tree != null:
		tree.active = true
	print("DODGE done: %d clips" % CLIPS.size())
