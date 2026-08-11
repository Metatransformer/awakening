extends RefCounted
## Two jobs, both diagnostic.
##
## 1. SHIELD PLACEMENT. The shield mounts edge-on and floating off the forearm.
##    Rather than reason about the rig's rotated FBX rest space -- which is what
##    produced the wrong number in the first place -- sweep candidate rotations
##    and photograph each one. The image decides, exactly as _facing.tscn decided
##    the hero's yaw.
##
## 2. WHY THE SWORD LANDS NOTHING. Prints the hero's position, each post's
##    position and distance, the hitbox's world centre and radius, and what the
##    Area3D actually reports overlapping while the swing is live. `total_hits=0`
##    with no error means one of those numbers disagrees with the picture, and
##    this is the cheapest way to find out which.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_shield_sweep.gd --out=/tmp/p4s/x.png

const CANDIDATES := [
	Vector3(0, 90, 100),    # what is in the code now, for reference
	Vector3(0, 0, 0),
	Vector3(90, 0, 0),
	Vector3(-90, 0, 0),
	Vector3(0, 90, 0),
	Vector3(0, -90, 0),
	Vector3(90, 90, 0),
	Vector3(-90, 90, 0),
	Vector3(0, 0, 90),
	Vector3(90, 0, 90),
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/p4s/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D

	await rig.wait_frames(24)

	if hero == null:
		push_error("sweep: no Hero")
		return
	var combat = hero.get("combat")
	if combat == null:
		push_error("sweep: hero has no combat node")
		return

	# --- Part 2 first: the geometry the hitbox is working with ---------------
	print("DIAG hero_pos=%v facing=%v" % [
		hero.global_position, -hero.global_transform.basis.z])
	for name in ["PostA", "PostB", "PostC"]:
		var post: Node3D = scene.get_node_or_null(NodePath(name)) as Node3D
		if post != null:
			print("DIAG %s pos=%v dist=%.2f layer=%d" % [
				name, post.global_position,
				hero.global_position.distance_to(post.global_position),
				post.collision_layer if "collision_layer" in post else -1,
			])
	var box: Area3D = combat.get_node_or_null(^"SwordHitbox") as Area3D
	if box != null:
		var shape: CollisionShape3D = box.get_child(0) as CollisionShape3D
		print("DIAG hitbox mask=%d shape_centre=%v world=%v radius=%.2f" % [
			box.collision_mask, shape.position,
			shape.global_position, (shape.shape as SphereShape3D).radius,
		])

	# --- Shield sweep --------------------------------------------------------
	# The training room is lit by torches, which is right for the game and
	# useless for a placement judgement -- the first sweep was unreadable.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 14.0
	lamp.omni_range = 6.0
	scene.add_child(lamp)
	lamp.global_position = hero.global_position + Vector3(-1.2, 1.9, -1.2)

	var shield = combat.get("shield")
	if shield == null:
		push_error("sweep: no shield mounted")
	else:
		var cam := scene.get_viewport().get_camera_3d()
		for i in CANDIDATES.size():
			shield.rotation_degrees = CANDIDATES[i]
			# Tight on the left forearm. At 1.3 m the shield was a few pixels
			# wide; the whole question is which way its face points, so the
			# camera has to be close enough for a face to have a direction.
			if cam != null:
				cam.fov = 45.0
				cam.global_position = hero.global_position + Vector3(-0.85, 1.35, -0.75)
				cam.look_at(hero.global_position + Vector3(-0.18, 1.02, 0.0), Vector3.UP)
			await rig.wait_frames(4)
			await rig.capture(out.path_join("s_%02d_%d_%d_%d.png" % [
				i, int(CANDIDATES[i].x), int(CANDIDATES[i].y), int(CANDIDATES[i].z)]))
		shield.rotation_degrees = CANDIDATES[0]
	lamp.queue_free()

	# --- Swing at a post, reporting overlaps live ----------------------------
	# Placed rather than walked. The first run had the hero stroll straight down
	# the middle and stop 2.63 m from the nearest post while the hitbox reaches
	# 1.58 m -- the swing was never given anything to hit, which reads as "the
	# sword is broken" and is really "the test missed".
	var post_a: Node3D = scene.get_node_or_null(^"PostA") as Node3D
	if post_a != null:
		var toward := (hero.global_position - post_a.global_position).normalized()
		hero.global_position = post_a.global_position + toward * 1.05
		hero.set("facing_yaw", atan2(-toward.x, -toward.z))
		await rig.wait_frames(8)
		print("DIAG placed dist=%.2f" % hero.global_position.distance_to(post_a.global_position))

	# `hold` for two frames rather than `tap`: a press and release inside one
	# frame can be missed by is_action_just_pressed in _physics_process.
	await rig.hold(["attack"], 2)
	for i in 10:
		await rig.wait_frames(2)
		if box != null:
			var bodies := box.get_overlapping_bodies()
			print("DIAG f%d swinging=%s monitoring=%s overlaps=%d %s" % [
				i, str(combat.get("swinging")), str(box.monitoring), bodies.size(),
				", ".join(bodies.map(func(b: Node) -> String: return b.name)),
			])
	await rig.wait_frames(20)
	await rig.capture(out.path_join("s_hit.png"))

	var hits := 0
	for name in ["PostA", "PostB", "PostC"]:
		var post: Node = scene.get_node_or_null(NodePath(name))
		if post != null:
			hits += int(post.get(&"hit_count"))
	print("P4CHECK total_hits=%d" % hits)
