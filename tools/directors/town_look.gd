extends RefCounted
## Close reads of the two people and the gate, from the height the player sees
## them at. A shopkeeper only has to survive one distance: standing-in-front-of.

func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/tl/x.png").get_base_dir()
	var town: Town = rig.scene()
	await rig.wait_frames(24)

	var cam := Camera3D.new()
	cam.fov = 50.0
	town.add_child(cam)
	cam.make_current()

	var subjects := [
		{"name": "vendor", "at": town.vendor, "eye": Vector3(0.6, 1.6, 3.0)},
		{"name": "smith", "at": town.smith, "eye": Vector3(-0.6, 1.6, 3.0)},
		{"name": "gate", "at": town.gate, "eye": Vector3(0.0, 2.0, 6.0)},
	]
	for s in subjects:
		var node: Node3D = s["at"]
		cam.global_position = node.global_position + (s["eye"] as Vector3)
		cam.look_at(node.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)
		await rig.wait_frames(3)
		await rig.capture(out.path_join("tl_%s.png" % s["name"]))
	print("TOWNLOOK done")
