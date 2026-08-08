extends RefCounted
## Same question as tools/scenes/_facing.tscn, but asked of the LIVE hero with
## the locomotion blend pinned to a chosen speed: at which Model yaw does the
## rig show its back while the body's -Z points away from the camera?
func run(rig) -> void:
	await rig.wait_seconds(0.6)
	var hero = rig.scene().get_tree().get_first_node_in_group("player")
	var cam = rig.scene().get_viewport().get_camera_3d()
	hero.set_physics_process(false)
	cam.set_physics_process(false)
	hero.rotation.y = 0.0                      # body -Z points north
	hero.global_position = Vector3(0, 0.05, 2)
	cam.global_position = Vector3(0, 1.7, 6.2) # due south of him, looking north
	cam.look_at(Vector3(0, 1.25, 2), Vector3.UP)
	var model = hero.get_node("Model")
	var tree = hero.get_node("AnimTree")
	for pair in [[4.37, "run"], [0.0, "idle"]]:
		for off in [0.0, 90.0, 180.0, 270.0]:
			model.rotation.y = deg_to_rad(off)
			for f in 25:
				tree.set("parameters/Loco/blend_position", pair[0])
				await rig.wait_seconds(0.02)
			await rig.capture("o_%s_%03d.png" % [pair[1], int(off)])
