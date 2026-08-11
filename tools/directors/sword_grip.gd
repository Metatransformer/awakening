extends RefCounted
## Which way does the blade FACE in his fist?
##
## The grip position was settled long ago (hero_combat.gd `_mount_loadout`), and
## this director does not touch it. The open question is the roll about the
## blade's own long axis: a sword held with the FLAT toward the enemy is a
## paddle, and at a distance it reads as a stick, because the silhouette a
## one-hander is supposed to have — a thin line edge-on, a wide face in profile —
## is exactly inverted.
##
## The convention the candidates are expressed in comes from weapon_models.gd:
##   blade runs along the model's +Y, the flat of the blade lies in its XY plane.
## So the model's local +Z is the blade's FACE NORMAL, and spinning about local
## +Y is the only rotation that changes which way it points without disturbing
## the grip. That is why the candidates below are a base euler plus a spin, and
## not four hand-written eulers: every one of them holds the sword in the same
## place, and differs only in the thing under test.
##
## `_measure` prints the face normal against the hero's own facing, because the
## question "is the edge forward" has a number and a render should not have to be
## squinted at for it. 90 deg off his facing means the edge leads; 0 means the
## flat does.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/sword_grip.gd --out=/tmp/sword/x.png

## The grip as it ships, unchanged across every candidate.
const BASE_POS := Vector3(0.0, 0.04, 0.02)
const BASE_ROT := Vector3(-6.0, 6.0, -90.0)

## Degrees about the BLADE's own axis (model local +Y). 0 is what ships; -90 is
## what shipped before, the flat carried edge-on to the camera.
const SPINS: Array[float] = [0.0, 90.0, -90.0, 180.0]


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

	var out: String = rig.arg("out", "/tmp/sword/x.png").get_base_dir()
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	if hero.combat == null or hero.combat.sword == null:
		print("SWORD FAIL no sword model mounted")
		return
	var model: Node3D = hero.combat.sword
	if not model.is_visible_in_tree():
		print("SWORD FAIL the sword is not in his hand")
		return

	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		print("SWORD FAIL no camera")
		return

	# Same three concessions hookshot_grip makes, for the same reasons: a lamp
	# because the room is authored dark, the camera off its own physics because
	# the gameplay rig frames the hero and not his hand, and time stopped because
	# the idle breathes and a drifting fist makes the candidates incomparable.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.4
	lamp.omni_range = 4.5
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)
	# The player's own view, kept before the camera is taken over. A grip is
	# judged close up, but it is SEEN from back here, and the two disagree: at
	# 2.5 m and 60 degrees of lens a blade edge-on is a pencil line.
	var game_view: Transform3D = cam.global_transform
	var game_fov: float = cam.fov
	cam.set_physics_process(false)
	Engine.time_scale = 0.0

	for i in SPINS.size():
		model.position = BASE_POS
		model.basis = _basis_for(SPINS[i])
		await rig.wait_frames(4)

		# Framed on the middle of the BLADE, not the fist: the roll is legible in
		# the blade's width and nowhere else, and a shot centred on his hand puts
		# most of the evidence out of frame.
		var blade: Vector3 = model.global_transform.basis.y.normalized()
		var at: Vector3 = model.global_position + blade * 0.35
		var fwd: Vector3 = _facing(hero)
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		lamp.global_position = at + side * 1.0 + Vector3.UP * 0.9

		await _shot(rig, at, cam, fwd * 0.95 + Vector3.UP * 0.12,
			out.path_join("s_%02d_front.png" % i))
		await _shot(rig, at, cam, side * 0.95 + Vector3.UP * 0.12,
			out.path_join("s_%02d_side.png" % i))

		cam.global_transform = game_view
		cam.fov = game_fov
		await rig.wait_frames(2)
		await rig.capture(out.path_join("s_%02d_game.png" % i))
		_measure(hero, model, i)

	Engine.time_scale = 1.0
	print("SWORD done — front/side pairs per spin in %s" % out)


## Compose the shipped grip with a spin about the blade's own axis.
##
## Post-multiplying is what makes this a spin in the MODEL's frame rather than
## the socket's: pre-multiplying would swing the whole sword around the hand and
## move the grip, which is the one thing this sweep must hold still.
func _basis_for(spin_deg: float) -> Basis:
	var base := Basis.from_euler(Vector3(
		deg_to_rad(BASE_ROT.x), deg_to_rad(BASE_ROT.y), deg_to_rad(BASE_ROT.z)))
	return base * Basis(Vector3.UP, deg_to_rad(spin_deg))


## Where the hero is actually looking. `facing_yaw` is the HEADING yaw, so the
## direction is (sin y, 0, cos y) — CONTRACT §2.5. Reading -basis.z instead would
## be the same number only once the body has finished turning to meet it, and
## these captures happen with the world stopped mid-turn.
func _facing(hero) -> Vector3:
	var y: float = hero.facing_yaw
	return Vector3(sin(y), 0.0, cos(y)).normalized()


## The euler to paste into hero_combat, plus the two angles that decide it.
func _measure(hero, model: Node3D, i: int) -> void:
	var e: Vector3 = _basis_for(SPINS[i]).get_euler()
	var face: Vector3 = model.global_transform.basis.z.normalized()
	var blade: Vector3 = model.global_transform.basis.y.normalized()
	var fwd: Vector3 = _facing(hero)
	var flat := K.flat(face)
	var off := 0.0
	if flat != Vector3.ZERO:
		off = rad_to_deg(K.flat(fwd).angle_to(flat))
	print("SWORD spin %+6.1f  rot(%.1f, %.1f, %.1f)  face %5.1f deg off facing  blade %5.1f deg up"
		% [SPINS[i], rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z), off,
			rad_to_deg(asin(clampf(blade.y, -1.0, 1.0)))])


func _shot(rig, at: Vector3, cam, offset: Vector3, path: String) -> void:
	cam.global_position = at + offset
	cam.look_at(at, Vector3.UP)
	cam.fov = 40.0
	await rig.wait_frames(2)
	await rig.capture(path)
