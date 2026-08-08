extends RefCounted
## Does the sword exist, sit in the hand, swing, and hurt the post?
##
## The socket offsets in HeroCombat were found with this: the rig's rest pose is
## in a rotated FBX space, so the only honest way to place a weapon is to render
## it, look, and adjust. Frames 00-02 are the ones that answer "is it in his
## hand or growing out of his wrist".
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_combat.gd --out=/tmp/p4/x.png

func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/p4/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D

	await rig.wait_frames(24)
	await rig.capture(out.path_join("c_00_idle.png"))

	# Close on the hands. If the sword or shield is misplaced, this is where it
	# is obvious and nowhere else.
	var cam := scene.get_viewport().get_camera_3d()
	if hero != null and cam != null:
		var eye: Vector3 = hero.global_position + Vector3(1.5, 1.5, 1.5)
		cam.global_position = eye
		cam.look_at(hero.global_position + Vector3(0, 1.1, 0), Vector3.UP)
		await rig.wait_frames(3)
		await rig.capture(out.path_join("c_01_hands_right.png"))

		cam.global_position = hero.global_position + Vector3(-1.5, 1.4, 1.5)
		cam.look_at(hero.global_position + Vector3(0, 1.1, 0), Vector3.UP)
		await rig.wait_frames(3)
		await rig.capture(out.path_join("c_02_hands_left.png"))

	# Hand the camera back to whatever owns it, then play for real.
	await rig.wait_frames(6)

	# Walk onto the nearest post, then swing. A swing that lands has to move the
	# post's readout — that number is the proof, not the pose.
	await rig.hold(["move_up"], 40)
	await rig.capture(out.path_join("c_03_approach.png"))

	# The swing, sampled across its window: wind-up, contact, recovery.
	await rig.tap(["attack"])
	for i in 6:
		await rig.wait_frames(3)
		await rig.capture(out.path_join("c_04_swing_%d.png" % i))

	await rig.wait_frames(20)
	await rig.capture(out.path_join("c_05_after.png"))

	# Three more swings, to show the readout accumulating rather than one lucky hit.
	for i in 3:
		await rig.tap(["attack"])
		await rig.wait_frames(30)
	await rig.capture(out.path_join("c_06_combo.png"))

	# Shield up, held. This is a blend, not a one-shot, so it must persist.
	await rig.hold(["shield"], 26)
	await rig.capture(out.path_join("c_07_block.png"))
	await rig.hold(["shield"], 26)
	await rig.capture(out.path_join("c_08_block_held.png"))

	# And down again — a shield that never lowers is as wrong as one that never rises.
	await rig.wait_frames(24)
	await rig.capture(out.path_join("c_09_lowered.png"))

	var posts := 0
	var hits := 0
	for name in ["PostA", "PostB", "PostC"]:
		var post: Node = scene.get_node_or_null(NodePath(name))
		if post != null:
			posts += 1
			hits += int(post.get(&"hit_count"))
	print("P4CHECK posts=%d total_hits=%d" % [posts, hits])
