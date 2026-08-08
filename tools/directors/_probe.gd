extends RefCounted
func run(rig) -> void:
	await rig.wait_frames(20)
	var hero = rig.scene().get_tree().get_first_node_in_group("player")
	var cam = rig.scene().get_viewport().get_camera_3d()
	Input.action_press(&"move_up", 1.0)
	for i in 14:
		await rig.wait_frames(10)
		print("t=%2d hero=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) yaw=%.1f cam=(%.2f,%.2f,%.2f) camfwd=(%.2f,%.2f,%.2f) fov=%.1f" % [
			i, hero.global_position.x, hero.global_position.y, hero.global_position.z,
			hero.velocity.x, hero.velocity.y, hero.velocity.z, rad_to_deg(hero.facing_yaw),
			cam.global_position.x, cam.global_position.y, cam.global_position.z,
			-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.y, -cam.global_transform.basis.z.z, cam.fov])
	Input.action_release(&"move_up")
	await rig.capture("probe.png")
