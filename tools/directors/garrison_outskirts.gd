extends RefCounted
## Visual and structural proof for the bounded descent between the compound and
## the Sunken Cut. Cameras cover every authored decision point rather than one
## flattering overview.

func run(rig) -> void:
	var outskirts := rig.scene() as GarrisonOutskirts
	if outskirts == null:
		rig.fail("scene is not GarrisonOutskirts")
		return
	await rig.wait_frames(30)
	for id: StringName in [&"arrival", &"garrison_gate", &"sunken_cut", &"blocked_path",
			&"fishing_hole"]:
		var port := outskirts.port(id)
		if port.origin == Vector3.ZERO:
			rig.fail("missing authored port %s" % id)
	var distance := 0.0
	for i in GarrisonOutskirts.PATH_POINTS.size() - 1:
		distance += GarrisonOutskirts.PATH_POINTS[i].distance_to(
			GarrisonOutskirts.PATH_POINTS[i + 1])
	if distance < 70.0:
		rig.fail("main path is only %.1f m" % distance)

	var cam := Camera3D.new()
	cam.fov = 58.0
	outskirts.add_child(cam)
	cam.make_current()
	var out: String = rig.out_base().get_base_dir()

	cam.global_position = Vector3(0.0, 10.2, 27.0)
	cam.look_at(Vector3(-4.0, 5.1, 5.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_00_gate_descent.png"))

	cam.global_transform = outskirts.port(&"vista_camera")
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_01_switchback.png"))

	var fishing := outskirts.fishing_hole as FishingHole
	if fishing == null:
		rig.fail("the authored fishing hole was not built")
		return
	var obstruction := outskirts.get_node_or_null(
		NodePath("Generated/Terrain/BlockedSpurBarricade/CrossTimberA")) as Node3D
	if not rig.check(obstruction != null,
			"the far blocked-spur structure remains behind the fishing landmark"):
		return
	cam.global_position = fishing.to_global(Vector3(0.0, 5.4, 5.0))
	cam.look_at(fishing.to_global(Vector3(0.0, 0.45, -2.25)), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_02_pond_and_blocked_spur.png"))

	cam.global_position = Vector3(3.0, 2.2, -31.0)
	cam.look_at(outskirts.port(&"sunken_cut").origin + Vector3(0.0, 1.8, -2.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_03_sunken_cut.png"))
	print("OUTSKIRTS OK %.1f m" % distance)
