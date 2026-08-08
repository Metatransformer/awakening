extends RefCounted
## Two things at once, both of which have to be judged by eye:
##   1. Does the hero run the way he is heading? (W should send him AWAY from
##      the camera — we should be looking at his back, not his face or his ribs.)
##   2. Do the training posts register, rock, and read out a hit?
##
##   godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/orch_facing_and_posts.gd --out=/tmp/f.png

func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/f.png").get_base_dir()

	await rig.wait_frames(20)
	await rig.capture(out.path_join("f_00_rest.png"))

	# Forward. If the rig yaw is wrong this is where it shows.
	await rig.hold(["move_up"], 22)
	await rig.capture(out.path_join("f_01_fwd.png"))
	await rig.hold(["move_up"], 22)
	await rig.capture(out.path_join("f_02_fwd.png"))

	# Strafe left, then right — a sideways heading catches a 90 deg error that
	# a straight run forward can hide.
	await rig.hold(["move_left"], 26)
	await rig.capture(out.path_join("f_03_left.png"))
	await rig.hold(["move_right"], 34)
	await rig.capture(out.path_join("f_04_right.png"))

	# Back toward the camera.
	await rig.hold(["move_down"], 26)
	await rig.capture(out.path_join("f_05_back.png"))

	# Hit the posts directly. The sword does not exist yet, so drive the damage
	# contract by hand — this is exactly the call P4's hitbox will make.
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero")
	var from: Vector3 = hero.global_position if hero else Vector3.ZERO
	for name in ["PostA", "PostB", "PostC"]:
		var post: Node = scene.get_node_or_null(NodePath(name))
		if post and post.has_method("strike"):
			post.strike(2, from)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("f_06_struck.png"))

	# A heavier follow-up, to show the readout accumulating and the wobble
	# scaling with damage rather than being a fixed twitch.
	for name in ["PostA", "PostB"]:
		var post: Node = scene.get_node_or_null(NodePath(name))
		if post and post.has_method("strike"):
			post.strike(8, from)
	await rig.wait_frames(8)
	await rig.capture(out.path_join("f_07_struck2.png"))
	await rig.wait_frames(40)
	await rig.capture(out.path_join("f_08_settled.png"))
