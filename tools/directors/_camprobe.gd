extends RefCounted
## Diagnostic: print where the camera rig actually put the Camera3D relative to
## the hero. SpringArm3D's cast axis is the kind of thing that is faster to
## measure than to remember, and a wrong guess reads as a lighting or pitch bug.


func run(rig) -> void:
	await rig.wait_frames(30)
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero")
	var cam_rig: Node3D = scene.get_node_or_null(^"GameCamera")
	if hero == null or cam_rig == null:
		print("PROBE missing nodes hero=", hero, " rig=", cam_rig)
		return
	var arm := cam_rig.get_node_or_null(^"SpringArm3D") as SpringArm3D
	var cam := rig.scene().get_viewport().get_camera_3d() as Camera3D
	print("PROBE hero_pos=", hero.global_position, " hero_rot_y_deg=", rad_to_deg(hero.rotation.y))
	print("PROBE pivot_pos=", cam_rig.global_position, " pivot_rot=", cam_rig.rotation)
	print("PROBE arm_rot_deg=", Vector3(rad_to_deg(arm.rotation.x), rad_to_deg(arm.rotation.y), rad_to_deg(arm.rotation.z)))
	print("PROBE arm_len=", arm.spring_length, " arm_child_local=", cam.position)
	print("PROBE cam_global=", cam.global_position)
	print("PROBE cam_to_hero=", hero.global_position - cam.global_position)
	print("PROBE cam_forward=", -cam.global_transform.basis.z)
	print("PROBE cam_fov=", cam.fov)
