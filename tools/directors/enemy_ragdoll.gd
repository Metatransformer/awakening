extends RefCounted
## Visual and state-machine proof for articulated enemy launches.
##
## One living goblin proves launch -> settle -> animated recovery, and a second
## proves freeze interrupts physics. One skeleton killed by a heavy hit proves a
## corpse stays physical and carries that pose through cleanup. All cross an
## explicit side-on camera, because an end-on throw hides the silhouette.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/enemy_ragdoll.gd \
##     --out=/tmp/enemy-ragdoll/x.png

const FOE_AT := Vector3(-2.7, 0.05, 2.4)
const HERO_PARK := Vector3(0.0, 0.05, 26.0)
const CAMERA_EYE := Vector3(0.0, 1.75, 7.8)
const CAMERA_AIM := Vector3(0.0, 1.05, 2.4)


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/enemy-ragdoll/x.png").get_base_dir()
	var scene: Node = rig.current_scene
	var heroes: Array[Node] = rig.get_nodes_in_group(&"player")
	if not rig.check(not heroes.is_empty(), "ragdoll proof has no player to park"):
		return
	(heroes[0] as Node3D).global_position = HERO_PARK

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 45.0
	camera.global_position = CAMERA_EYE
	camera.look_at(CAMERA_AIM, Vector3.UP)
	camera.make_current()
	await rig.wait_frames(8)

	await _living_launch(rig, scene, out)
	await _freeze_abort(rig, scene, out)
	await _corpse_launch(rig, scene, out)
	print("RAGDOLL OK")


func _living_launch(rig, scene: Node, out: String) -> void:
	var foe := Enemy.new()
	foe.kind = &"goblin"
	foe.drop_seed = 10301
	scene.add_child(foe)
	foe.global_position = FOE_AT
	await rig.wait_physics_frames(4)

	if not rig.check(foe.ragdoll_bone_count() >= 14,
			"goblin built only %d physical bones" % foe.ragdoll_bone_count()):
		foe.queue_free()
		return
	foe._launch(Vector3.RIGHT, 1.0)
	await rig.wait_physics_frames(2)
	rig.check(foe.is_ragdoll_active(), "living launch did not start physical bones")
	var probe: PhysicalBone3D = foe._ragdoll._bodies[7]
	var probe_start := probe.global_basis.get_rotation_quaternion()
	var visual_skeleton: Skeleton3D = foe._ragdoll._visual_skeleton
	var visual_probe_id := visual_skeleton.find_bone("LeftArm")
	var visual_start := visual_skeleton.get_bone_global_pose(visual_probe_id) \
		.basis.get_rotation_quaternion()

	for shot: int in 3:
		await rig.wait_physics_frames(7)
		if shot == 0:
			var turned := rad_to_deg(probe_start.angle_to(
				probe.global_basis.get_rotation_quaternion()))
			var visual_turned := rad_to_deg(visual_start.angle_to(visual_skeleton \
				.get_bone_global_pose(visual_probe_id).basis.get_rotation_quaternion()))
			print("RAGDOLL articulation physical=%.1f visual=%.1f deg"
				% [turned, visual_turned])
			rig.check(turned > 8.0,
				"physical forearm moved only %.1f degrees" % turned)
			rig.check(visual_turned > 8.0,
				"rendered forearm moved only %.1f degrees" % visual_turned)
		await rig.capture(out.path_join("ragdoll_0%d_living_air.png" % shot))

	var recovered: bool = await rig.until(func() -> bool:
		return is_instance_valid(foe) and not foe.is_ragdoll_active() \
			and foe.state != Enemy.State.LAUNCHED, 5.0)
	rig.check(recovered, "living ragdoll never blended back to enemy AI")
	if is_instance_valid(foe):
		await rig.capture(out.path_join("ragdoll_03_living_recovered.png"))
		foe.queue_free()
	await rig.wait_frames(4)


func _freeze_abort(rig, scene: Node, out: String) -> void:
	var foe := Enemy.new()
	foe.kind = &"goblin"
	foe.drop_seed = 10303
	scene.add_child(foe)
	foe.global_position = FOE_AT
	await rig.wait_physics_frames(4)
	foe._launch(Vector3.RIGHT, 1.0)
	await rig.wait_physics_frames(4)
	rig.check(foe.is_ragdoll_active(), "freeze proof never entered ragdoll")
	foe.freeze(0.35)
	await rig.wait_physics_frames(2)
	rig.check(foe.is_frozen(), "freeze did not interrupt a launched enemy")
	rig.check(not foe.is_ragdoll_active(), "freeze left physical bones active")
	await rig.capture(out.path_join("ragdoll_04_freeze_abort.png"))
	foe.queue_free()
	await rig.wait_frames(4)


func _corpse_launch(rig, scene: Node, out: String) -> void:
	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 10302
	scene.add_child(foe)
	foe.global_position = FOE_AT
	await rig.wait_physics_frames(4)

	var hit := Hit.make(foe.health.max_health_points + 4,
		foe.global_position + Vector3.LEFT * 1.2 + Vector3.UP * 0.8,
		&"sword", K.KNOCKBACK_HEAVY, K.STUN_LIGHT)
	foe.health.apply_hit(hit)
	await rig.wait_physics_frames(2)
	rig.check(foe.state == Enemy.State.DEAD, "heavy kill did not enter DEAD")
	rig.check(foe.is_ragdoll_active(), "killing blow did not start physical bones")
	rig.check(foe.ragdoll_bone_count() >= 14,
		"skeleton built only %d physical bones" % foe.ragdoll_bone_count())

	for shot: int in 4:
		await rig.wait_physics_frames(7)
		await rig.capture(out.path_join("ragdoll_1%d_corpse_air.png" % shot))
	rig.check(foe.is_ragdoll_active(), "corpse ragdoll stopped before cleanup")
	var before_sink := foe.global_position.y
	await rig.wait_seconds(1.9)
	rig.check(not foe.is_ragdoll_active(), "corpse physics stayed live during sink")
	rig.check(foe.global_position.y < before_sink - 0.05,
		"corpse pose did not follow its cleanup sink")
	await rig.capture(out.path_join("ragdoll_14_corpse_sink.png"))
	if is_instance_valid(foe):
		foe.queue_free()
	await rig.wait_frames(4)
