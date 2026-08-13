extends RefCounted
## Visual and structural proof for the open, cliff-partitioned clearing between
## the compound and the Sunken Cut.

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
	rig.check(absf(GarrisonOutskirts.PATH_POINTS[0].x
		- GarrisonOutskirts.PATH_POINTS[-1].x) < 5.0,
		"the critical path is a direct descent rather than a switchback")
	rig.check(outskirts.harvest_trees.size() == 10,
		"the west grove contains ten harvestable trees")
	for tree: HarvestTree in outskirts.harvest_trees:
		rig.check(tree.prompt == "CHOP TREE" and tree.hold_time > 0.0,
			"every grove tree exposes a held chop interaction")
		rig.check(tree.get_node_or_null(^"SolidTrunk/TrunkCollision") != null,
			"every grove tree has solid trunk collision")
	for shoulder: String in ["GroveShoulderUpper", "GroveShoulderLower",
			"EastSpurShoulderNorth", "EastSpurShoulderSouth"]:
		rig.check(outskirts.get_node_or_null(
			NodePath("Generated/Cliffs/%s" % shoulder)) != null,
			"the clearing includes cliff partition %s" % shoulder)

	var cam := Camera3D.new()
	cam.fov = 58.0
	outskirts.add_child(cam)
	cam.make_current()
	var out: String = rig.out_base().get_base_dir()

	cam.global_position = Vector3(0.0, 17.5, 34.0)
	cam.look_at(Vector3(0.0, 4.0, -3.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_00_open_clearing.png"))

	cam.global_transform = outskirts.port(&"vista_camera")
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_01_direct_route.png"))

	var grove_target: Vector3 = outskirts.port(&"grove").origin
	cam.global_position = grove_target + Vector3(10.0, 5.8, 9.0)
	cam.look_at(grove_target + Vector3(0.0, 2.8, 0.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_02_tree_grove.png"))

	var fishing := outskirts.fishing_hole as FishingHole
	if fishing == null:
		rig.fail("the authored fishing hole was not built")
		return
	var obstruction := outskirts.get_node_or_null(
		NodePath("Generated/Terrain/BlockedSpurBarricade/CrossTimberA")) as Node3D
	if not rig.check(obstruction != null,
			"the blocked-spur structure remains beyond the fishing landmark"):
		return
	cam.global_position = fishing.to_global(Vector3(0.0, 5.4, 5.0))
	cam.look_at(fishing.to_global(Vector3(0.0, 0.45, -2.25)), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_03_fishing_pond.png"))

	var spur_direction: Vector3 = (GarrisonOutskirts.BLOCKED_SPUR_END \
		- GarrisonOutskirts.BLOCKED_SPUR_START).normalized()
	cam.global_position = obstruction.global_position - spur_direction * 7.0 \
		+ Vector3.UP * 1.5
	cam.look_at(obstruction.global_position, Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_04_blocked_spur.png"))

	cam.global_position = Vector3(3.0, 2.2, -31.0)
	cam.look_at(outskirts.port(&"sunken_cut").origin + Vector3(0.0, 1.8, -2.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_05_sunken_cut.png"))
	print("OUTSKIRTS OK %.1f m" % distance)
