extends RefCounted
## Photographs the ranged clips as pose strips, so picking one is a thing
## somebody looked at rather than a thing inferred from a filename.
##
## The whole point of the longbow pack is that "standing draw arrow" and
## "standing aim recoil" are guesses until you see them. CLAUDE.md §4 is blunt
## about this: never reason a pose out from bone tracks, render it and look.
##
## Each clip gets one PNG — four evenly spaced poses side by side, left to
## right, over the clip's own length. The AnimationTree is switched off for the
## duration so the AnimationPlayer can be scrubbed directly; the tree would
## otherwise overwrite the pose with the locomotion blend on the next frame.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/ranged_anim_lookdev.gd --out=/tmp/anim/x.png

## Clip, and the WEAPON to have in hand while it plays. `sword` is what the
## stand-in has always been photographed in.
##
## These used to name a D-pad direction (`item_left`, `item_up`) because each
## item lived on a bound button. They name the weapon itself now: the D-pad steps
## a ring, so "which button is the bow on" has no answer and `rig.draw_weapon`
## presses → until the right thing is in his hand.
const STRIPS := [
	{"clip": &"ss_casting_01", "item": &"bow", "label": "standin_casting"},
	{"clip": &"bow_draw_arrow", "item": &"bow", "label": "bow_draw_arrow"},
	{"clip": &"bow_aim_recoil", "item": &"bow", "label": "bow_aim_recoil"},
	{"clip": &"bow_aim_overdraw", "item": &"bow", "label": "bow_aim_overdraw"},
	{"clip": &"bow_equip", "item": &"bow", "label": "bow_equip"},
	{"clip": &"ex_hookshot_fire", "item": &"hookshot", "label": "hookshot_fire"},
]
const POSES := 4
## Turn off dead-on so the drawn arm reads. Straight at the lens hides the pull.
const FACE_OFFSET := 0.7


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

	var out: String = rig.arg("out", "/tmp/anim/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var player: AnimationPlayer = hero._anim_player
	var tree: AnimationTree = hero._tree
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	if cam == null or player == null or tree == null:
		print("ANIMLOOK FAIL no camera / no rig")
		return

	# Face him three-quarters to the lens, by the contract's heading formula.
	var to_cam: Vector3 = K.flat(cam.global_position - hero.global_position)
	hero.facing_yaw = atan2(to_cam.x, to_cam.z) + FACE_OFFSET
	await rig.wait_frames(20)

	var held := &""
	for strip in STRIPS:
		var clip: StringName = strip["clip"]
		var item: StringName = strip["item"]
		var label: String = strip["label"]

		if item != held:
			# Nothing is assigned behind the game's back (docs/CONTRACT.md §4.1),
			# so the D-pad is PRESSED until the ring lands on it. Stepping onto
			# the next weapon is also what puts the last one away, so there is no
			# separate stow press any more.
			await rig.draw_weapon(item)
			await rig.wait_frames(14)
			held = item
			hero.facing_yaw = atan2(to_cam.x, to_cam.z) + FACE_OFFSET
			await rig.wait_frames(6)

		if not player.has_animation(clip):
			print("ANIMLOOK FAIL missing clip %s" % clip)
			continue

		tree.active = false
		var length: float = player.get_animation(clip).length
		var sheet: Image = null
		for i in POSES:
			# The last pose sits a hair inside the end: a one-shot's final key is
			# often the neutral it blends back to, and photographing that gives a
			# strip whose last frame says nothing about the clip.
			var t: float = length * (float(i) / float(POSES - 1)) * 0.97
			player.play(clip)
			player.seek(t, true)
			player.pause()
			await rig.wait_frames(2)
			# Annotated, not inferred: an awaited call yields Variant, and `:=`
			# on one is the "cannot infer the type of X" parse error (CLAUDE.md §3).
			var frame: Image = await _grab(rig)
			if sheet == null:
				sheet = Image.create_empty(
					frame.get_width() * POSES, frame.get_height(), false, frame.get_format()
				)
			sheet.blit_rect(
				frame,
				Rect2i(Vector2i.ZERO, frame.get_size()),
				Vector2i(frame.get_width() * i, 0)
			)
		player.stop()
		tree.active = true
		await rig.wait_frames(6)

		var path := out.path_join("anim_%s.png" % label)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		sheet.save_png(path)
		print("ANIMLOOK %-18s len=%.2f -> %s" % [label, length, path])

	print("ANIMLOOK done")


## One rendered frame, halved. Four full-size frames side by side is a 5120 px
## image nobody can read; half scale keeps the whole strip legible at once.
func _grab(rig) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = rig.root.get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	return img
