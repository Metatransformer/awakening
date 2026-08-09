extends RefCounted
## Which way round is the bow in his fist?
##
## The hand mount in `HeroCombat._mount_loadout` shipped at rot (-96, 0, 90),
## copied off the hookshot's pitch, and at full draw the bow reads BACKWARDS —
## the limbs sweep toward the archer instead of away from him, which is the one
## thing about a bow every player can see is wrong even if they have never held
## one.
##
## The model's own axes, measured off the GLB and not guessed:
##
##   +Y  is the limbs, 1.52 m of them, grip at the origin and the tips at ±0.76.
##   +X  is the DEPTH of the curve — the mesh runs from -0.02 to +0.24, with the
##       grip on the -X edge. The tips are the +X end, and on a strung bow the
##       tips are where the STRING is, so +X points at the archer and the limbs
##       bow away toward the target.
##   +Z  is the flat, 3.8 cm of it. Nothing hangs off it.
##
## So the target grip is: local +X back down the hero's facing, local +Y up.
##
## Which is exactly the number a render is for, because +X being the string side
## rather than the back is a coin-flip nobody can read off an AABB — I got it
## backwards first time, and the two candidates it chooses between measure 8.5°
## and 171.5° off the shot, so the numbers alone will confidently pick whichever
## one you assumed. Look at where the string is.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/bow_grip.gd --out=/tmp/bowgrip/x.png

## The rotation that ships, and the deltas swept on top of it.
##
## The sweep is about the model's OWN +Y — the limb axis — and it has to be,
## because that is the only spin that leaves the limbs vertical while it turns
## the bow's plane. Adding to the Euler instead does not do that: Godot composes
## rotation_degrees as Y*X*Z, so none of the three components is "about the
## limbs" once the -96 pitch is in there, which is why the first sweep of this
## director produced six candidates that were each wrong in a different way.
##
## Only the rotation is swept. The grip is at the model's origin, so unlike the
## hookshot — whose mesh hangs off one side of its own origin, and whose roll
## therefore moved the whole body out of his fist — a bow can be spun about its
## own handle without leaving the hand.
## What ships. Spin 0 is therefore the shipped grip, and every other entry is a
## candidate against it — including -180, which is the quarter turn this mount
## carried before and the reason the director exists.
const BASE := Vector3(6.0, 180.0, -90.0)
const SPINS: Array[float] = [0.0, -90.0, 90.0, 180.0]
## The held pose, and how far into it to scrub. A bow judged in the rest pose is
## a bow judged in the one stance where his hand is at his side and the limbs are
## nowhere near the shot: the question is what full draw looks like.
const CLIP := &"bow_aim_overdraw"


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/bowgrip/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	var player: AnimationPlayer = hero._anim_player
	var tree: AnimationTree = hero._tree
	if cam == null or player == null or tree == null:
		print("BOWGRIP FAIL no camera / no rig")
		return

	# dpad left draws the bow. Nothing cycles behind the game's back
	# (docs/CONTRACT.md §4.1), so the button is pressed like a player would.
	await rig.tap(["item_left"])
	await rig.wait_frames(24)
	if hero.combat == null or hero.combat.bow == null:
		print("BOWGRIP FAIL no bow model mounted")
		return
	var model: Node3D = hero.combat.bow
	if not model.is_visible_in_tree():
		print("BOWGRIP FAIL the bow is not in his hand (left hand holds %s)"
			% Game.armament(Game.HAND_RIGHT))
		return

	# The tree is switched off so the AnimationPlayer can be parked at full draw.
	# Left on, the locomotion blend overwrites the pose on the next frame and
	# every candidate is photographed in the idle.
	tree.active = false
	player.play(CLIP)
	player.seek(player.get_animation(CLIP).length * 0.6, true)
	player.pause()

	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.4
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)
	cam.set_physics_process(false)
	Engine.time_scale = 0.0

	var fwd: Vector3 = -hero.global_transform.basis.z
	for i in SPINS.size():
		model.basis = Basis.from_euler(BASE * (PI / 180.0)) \
			* Basis(Vector3.UP, deg_to_rad(SPINS[i]))
		await rig.wait_frames(4)
		# Broadside to the bow's FLAT, which is the one angle that shows which way
		# the limbs sweep. Shot from his left, where the bow arm is.
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		var at: Vector3 = model.global_position
		lamp.global_position = at - side * 1.2 + Vector3.UP * 1.0
		await _shot(rig, at, cam, -side * 1.9 + Vector3.UP * 0.15,
			out.path_join("b_%02d_side.png" % i))
		await _shot(rig, at, cam, Vector3.UP * 1.9 + fwd * 0.05,
			out.path_join("b_%02d_above.png" % i))
		_measure(hero, model, i)

	Engine.time_scale = 1.0
	tree.active = true


## The two angles that decide it, in the hero's own terms.
##
## `sweep` is how far the limbs' curve (+X) sits off the direction of the shot:
## 0 is a bow pointing its back at the target, 180 is the bow on backwards.
## `up` is how far the limbs (+Y) sit off vertical — a bow lying on its side
## still reads as wrong even when the sweep is right.
func _measure(hero, model: Node3D, i: int) -> void:
	var basis := model.global_transform.basis.orthonormalized()
	var sweep: Vector3 = basis.x
	var limbs: Vector3 = basis.y
	var fwd: Vector3 = K.flat(-hero.global_transform.basis.z)
	var flat := K.flat(sweep)
	var off := 180.0
	if flat != Vector3.ZERO:
		off = rad_to_deg(fwd.angle_to(flat))
	print("BOWGRIP %02d spin %6.1f  euler %-24s sweep %5.1f deg off the shot, limbs %5.1f deg off vertical"
		% [i, SPINS[i], str((model.rotation_degrees).round()), off,
			rad_to_deg(limbs.angle_to(Vector3.UP))])


func _shot(rig, at: Vector3, cam, offset: Vector3, path: String) -> void:
	cam.global_position = at + offset
	cam.look_at(at, Vector3.UP)
	cam.fov = 40.0
	await rig.wait_frames(2)
	await rig.capture(path)
