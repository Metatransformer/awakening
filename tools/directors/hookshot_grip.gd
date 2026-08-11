extends RefCounted
## How does the hookshot sit in his fist?
##
## It shipped lying on its right side: the hand mount in `HeroCombat._mount_loadout`
## carried no roll (z = 0) where the sword carries -90, and the barrel is the
## whole read of a grapple pistol — a player has to be able to see which way it
## is going to fire.
##
## The candidates are rendered rather than reasoned about. The rig's rest pose is
## expressed in a rotated FBX space, so the bone matrices read as nonsense on
## paper; every socket number in this project was settled by looking at exactly
## these frames (see the note at the top of hero_combat.gd).
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/hookshot_grip.gd --out=/tmp/grip/x.png

## Candidates for the hand mount: `pos` is the socket-space offset, `rot` the
## euler in degrees. The first entry is what shipped.
##
## The roll matters twice over. The obvious half is which way up the pistol is —
## it shipped lying on its side. The half that only a render shows is that the
## MESH is offset from its own origin, perpendicular to the barrel: rolling it
## swings the whole body around the fist, so the roll that stands it upright also
## decides whether it sits in his hand or floats above it. That is what the
## position offsets here are chasing.
const CANDIDATES: Array[Dictionary] = [
	{"pos": Vector3(0.07, 0.08, 0.02), "rot": Vector3(-66.0, 6.0, 90.0)},  # what ships
	{"pos": Vector3(0.0, 0.05, 0.02), "rot": Vector3(-96.0, 6.0, 0.0)},    # what shipped before
	{"pos": Vector3(0.07, 0.08, 0.02), "rot": Vector3(-66.0, 6.0, 0.0)},   # seated, no roll
	{"pos": Vector3(0.07, 0.08, 0.02), "rot": Vector3(-66.0, 6.0, -90.0)}, # seated, rolled the other way
	{"pos": Vector3(0.0, 0.05, 0.02), "rot": Vector3(-66.0, 6.0, 90.0)},   # rolled but not re-seated
]


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

	var out: String = rig.arg("out", "/tmp/grip/x.png").get_base_dir()
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]

	# D-pad → steps the ring to it. The STOWED mount is a different node with its
	# own rotation, so drawing is what puts the one under test on screen.
	await rig.draw_weapon(&"hookshot")
	await rig.wait_frames(24)
	if hero.combat == null or hero.combat.hookshot == null:
		print("GRIP FAIL no hookshot model mounted")
		return
	var model: Node3D = hero.combat.hookshot
	if not model.is_visible_in_tree():
		print("GRIP FAIL the hookshot is not in his hand (right hand holds %s)"
			% Game.armament(Game.HAND_RIGHT))
		return

	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		print("GRIP FAIL no camera")
		return

	# A lookdev lamp on the model. The dungeon is authored dark on purpose and a
	# 30 cm pistol in his fist reads as a black smudge under it — which is a fine
	# room and a useless reference frame.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.2
	lamp.omni_range = 4.0
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)
	# The camera is driven by hand from here. Aim mode has it on his shoulder,
	# which is the one angle where the hand is hidden behind his own arm.
	cam.set_physics_process(false)
	# And the world stops. The hookshot brace is a LOOPING clip, so the fist
	# drifts a few centimetres every frame — at 34 cm and 34 degrees of lens that
	# walked the subject to the edge of the frame between placing the camera and
	# the capture two frames later. Freezing time is what makes these comparable
	# to each other, which is the entire point of a candidate sweep.
	Engine.time_scale = 0.0

	for i in CANDIDATES.size():
		var c := CANDIDATES[i]
		model.position = c["pos"]
		model.rotation_degrees = c["rot"]
		await rig.wait_frames(4)
		# Broadside to the BARREL, not to the hero. The first pass framed these
		# from a fixed point behind his shoulder and I read them exactly wrong:
		# the candidate whose barrel pointed straight down his facing was the
		# foreshortened one, and it looked like the pistol was aimed at the sky.
		# A view perpendicular to the barrel cannot be fooled that way.
		var barrel: Vector3 = model.global_transform.basis.z.normalized()
		var side: Vector3 = barrel.cross(Vector3.UP).normalized()
		# The socket IS the hand bone — the model's parent (see HeroCombat._mount).
		var hand: Node3D = model.get_parent() as Node3D
		lamp.global_position = model.global_position + side * 0.9 + Vector3.UP * 0.8
		# Framed on the FIST rather than on the model's origin: what is being
		# judged here is whether the pistol is in his hand, and centring on the
		# thing whose placement is in question hides exactly that.
		await _shot(rig, hand, cam, side * 0.62 + Vector3.UP * 0.05,
			out.path_join("g_%02d_side.png" % i))
		await _shot(rig, hand, cam, Vector3.UP * 0.58 - barrel * 0.14,
			out.path_join("g_%02d_above.png" % i))
		_measure(hero, model, i)

	Engine.time_scale = 1.0


## Where the barrel is actually pointing, in the hero's own terms.
##
## The model's local +Z is the direction it fires (weapon_models.gd), so this is
## the one number a render cannot lie about: how far off the hero's facing the
## barrel sits, and whether it is angled up at the ceiling or down at his feet.
## The shot itself comes from the camera, so this is cosmetic — but a grapple
## pistol visibly pointing somewhere other than where the chain goes is the same
## bug as a monster walking backwards.
func _measure(hero, model: Node3D, i: int) -> void:
	var c: Dictionary = CANDIDATES[i]
	var barrel: Vector3 = model.global_transform.basis.z.normalized()
	var fwd: Vector3 = -hero.global_transform.basis.z
	var flat := K.flat(barrel)
	var off := 180.0
	if flat != Vector3.ZERO:
		off = rad_to_deg(K.flat(fwd).angle_to(flat))
	print("GRIP %02d pos %s rot %s  barrel %5.1f deg off his facing, %5.1f deg %s"
		% [i, str(c["pos"]), str(c["rot"]), off,
			absf(rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0)))),
			"up" if barrel.y > 0.0 else "down"])


## One close frame from `offset`, centred on `subject`.
##
## The stance holds the hand up beside his ear, and a shot aimed at chest height
## put the whole thing at the top edge of the frame with his back filling the
## rest — you cannot settle a 90 degree roll off a silhouette.
func _shot(rig, subject: Node3D, cam, offset: Vector3, path: String) -> void:
	var at: Vector3 = subject.global_position
	cam.global_position = at + offset
	cam.look_at(at, Vector3.UP)
	cam.fov = 34.0
	await rig.wait_frames(2)
	await rig.capture(path)
