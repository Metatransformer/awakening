extends RefCounted
## Roll sweep for the sword and the shield, shot from the front while blocking.
##
## What this had to learn the hard way, all worth keeping:
##
##  1. Do not borrow the gameplay camera. The camera rig re-solves its transform
##     every frame, so every `cam.global_position = ...` is overwritten before
##     the capture and none of the framing you asked for is what you get.
##  2. Do not shoot by torchlight, and do not overcorrect either. The first lit
##     pass blew the shield to pure white, and a white disc has no readable form.
##  3. Sweep the axis that can actually be wrong -- and for a shield that is TWO
##     axes, not one. Yaw decides which face points at the enemy (180 is right;
##     0 shows the wooden inner face and its straps). Roll about the shield's own
##     face normal decides whether the kite point hangs DOWN or sticks out
##     sideways, and getting that wrong is what "off kilter" looks like.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/shield_lookdev.gd --out=/tmp/sl/x.png
##     [--target=shield|sword]

## Shield: yaw is settled at 180, so this sweeps the roll about its face normal.
const SHIELD_ROLLS := [-90.0, 0.0, 90.0, 180.0]
## Sword: the mount that reads correctly is (-96, 6, 0); this sweeps 90-degree
## steps of the roll about the blade axis on top of it.
const SWORD_ROLLS := [-90.0, 0.0, 90.0, 180.0]

const VIEWS := [
	{"name": "front", "eye": Vector3(-0.30, 1.25, -2.3), "aim": Vector3(0.0, 1.05, 0.0)},
	{"name": "left", "eye": Vector3(-2.2, 1.25, -0.3), "aim": Vector3(0.0, 1.05, 0.0)},
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/sl/x.png").get_base_dir()
	var target: String = rig.arg("target", "shield")
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	await rig.wait_frames(24)

	if hero == null:
		push_error("shield_lookdev: no Hero")
		return
	var combat = hero.get("combat")
	if combat == null:
		push_error("shield_lookdev: no combat node")
		return
	var holder: Node3D = combat.get(target) as Node3D
	if holder == null:
		push_error("shield_lookdev: '%s' did not mount" % target)
		return

	var model := holder.get_child(0) as Node3D
	if model != null:
		print("SIZE %s extent=%.2fm" % [target, WeaponModels.extent(model)])

	var cam := Camera3D.new()
	cam.fov = 50.0
	scene.add_child(cam)
	cam.make_current()

	# Enough to separate the weapon from the tabard, not enough to clip it.
	var key := OmniLight3D.new()
	key.light_energy = 3.2
	key.omni_range = 8.0
	scene.add_child(key)
	key.global_position = hero.global_position + Vector3(-1.8, 2.4, -2.2)

	if target == "shield":
		Input.action_press(&"shield")
	await rig.wait_frames(30)

	var base: Vector3 = holder.rotation_degrees
	var rolls: Array = SHIELD_ROLLS if target == "shield" else SWORD_ROLLS
	for roll: float in rolls:
		# Post-multiply so the roll happens about the model's OWN axis, not the
		# bone's. Setting Euler z directly rotates in the bone's frame, which is
		# the rotated FBX space and means something different.
		holder.transform.basis = Basis.from_euler(
			Vector3(deg_to_rad(base.x), deg_to_rad(base.y), deg_to_rad(base.z))
		) * Basis(Vector3.FORWARD, deg_to_rad(roll))
		for view in VIEWS:
			cam.global_position = hero.global_position + (view["eye"] as Vector3)
			cam.look_at(hero.global_position + (view["aim"] as Vector3), Vector3.UP)
			await rig.wait_frames(3)
			await rig.capture(out.path_join("%s_%+04d_%s.png" % [
				target, int(roll), view["name"]]))

	if target == "shield":
		Input.action_release(&"shield")
	key.queue_free()
	cam.queue_free()
	print("SHIELDCHECK target=%s rolls=%d views=%d" % [target, rolls.size(), VIEWS.size()])
