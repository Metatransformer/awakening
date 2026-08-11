extends RefCounted
## Photographs the weapon rack from the angles that actually decide anything:
## a straight-on rack shot (scale vs the 1.65 m post), a close pass on the
## swords and on the shields (is the diffuse map bound, or is it grey?), and
## three stages of a hookshot flight (the chain cannot be judged from a model).
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://tools/scenes/_weapon_lookdev.tscn \
##     --director=res://tools/directors/weapon_lookdev.gd --out=/tmp/w/w.png

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

	var out: String = rig.arg("out", "/tmp/w/w.png").get_base_dir()
	var scene: Node3D = rig.scene()

	var cam := Camera3D.new()
	cam.fov = 50.0
	scene.add_child(cam)
	cam.make_current()

	await rig.wait_frames(12)

	# 1. The whole rack, with the hero-height post in frame.
	await _look(rig, cam, Vector3(0.4, 2.6, 6.4), Vector3(0.0, 0.85, 0.8))
	await rig.capture(out.path_join("w_00_rack.png"))

	# 2. Swords, close and low — texture detail and blade silhouette.
	await _look(rig, cam, Vector3(0.0, 1.05, -2.6), Vector3(0.0, 0.75, 0.0))
	await rig.capture(out.path_join("w_01_swords.png"))

	# 3. Shields, face-on. A bound diffuse is obvious here; grey is obvious too.
	#
	# THE EYE MOVED BACK 0.9 m ON 2026-08-11 (#55) and the arithmetic is the whole
	# reason. `Camera3D.fov` is the VERTICAL angle, so when `shoot.gd` stopped
	# rendering a 2.5:1 window and squeezing it into a 16:9 PNG, every horizontal
	# field in this file narrowed by a factor of 0.71 and nothing else changed. At
	# the old (0, 1.0, 4.3) the half-width at the shield plane was
	# tan(25 deg) * 16/9 * 2.73 m = 2.26 m; the rank runs to x = +-2.125 and the
	# end shields are 0.65-0.72 m across, so both of them fell off the edges --
	# `shield_knightly` and `kite_shield`, the two the sheet is least able to spare.
	# 3.6 m of distance puts the half-width at 2.98 m and the rank back inside it.
	# **Do not "fix" a crop like this by widening `fov`:** 2.5:1 needs a 99 deg
	# horizontal field, and a 99 deg lens on a rack of flat shields bows the ones
	# at the ends until the sheet is about the lens.
	await _look(rig, cam, Vector3(-0.25, 1.13, 5.16), Vector3(-0.25, 0.6, 1.6))
	await rig.capture(out.path_join("w_02_shields.png"))

	# 4. The hookshot pistol on its own.
	await _look(rig, cam, Vector3(0.55, 1.25, 3.95), Vector3(0.0, 1.05, 3.1))
	await rig.capture(out.path_join("w_03_hookshot.png"))

	# 5-7. The tether part-way out, nearly there, and anchored. `preview` draws
	# one instant without running gameplay, so these frames are deterministic.
	var tether = scene.get("tether")
	var from: Vector3 = scene.get("hook_from")
	var to: Vector3 = scene.get("hook_to")
	if tether != null:
		await _look(rig, cam, Vector3(-1.0, 2.3, 6.0), Vector3(1.2, 1.5, -1.0))
		for stage in [[0.35, "w_05_chain_35"], [0.75, "w_06_chain_75"], [1.0, "w_07_chain_anchored"]]:
			tether.preview(from, to, stage[0])
			await rig.wait_frames(3)
			await rig.capture(out.path_join(str(stage[1]) + ".png"))

		# 8. Close on the head biting the ring — the barb and the link
		# interlocking are the two details that separate a chain from a rope.
		tether.preview(from, to, 1.0)
		await _look(rig, cam, Vector3(2.3, 2.4, -1.2), Vector3(3.6, 2.1, -3.0))
		await rig.wait_frames(3)
		await rig.capture(out.path_join("w_08_head.png"))
	else:
		push_error("weapon_lookdev: scene exposed no `tether`")


func _look(rig, cam: Camera3D, eye: Vector3, at: Vector3) -> void:
	cam.position = eye
	cam.look_at(at, Vector3.UP)
	await rig.wait_frames(4)
