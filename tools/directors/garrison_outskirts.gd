extends RefCounted
## Visual and structural proof for the wooded homestead clearing between
## Highbridge and the visible Sunken Cut mine entrance.


func run(rig) -> void:
	var outskirts := rig.scene() as GarrisonOutskirts
	if outskirts == null:
		rig.fail("scene is not GarrisonOutskirts")
		return
	Clock.running = false
	Clock.set_time(1, 12.0)
	await rig.wait_frames(30)

	for id: StringName in [
		&"arrival", &"garrison_gate", &"bridge_end", &"sunken_cut",
		&"grove", &"clearing", &"toolshed", &"garden", &"fishing_hole",
		&"south_pond",
	]:
		var authored_port := outskirts.port(id)
		rig.check(authored_port.origin != Vector3.ZERO,
			"authored port %s exists" % id)

	var distance := 0.0
	for i: int in GarrisonOutskirts.PATH_POINTS.size() - 1:
		distance += GarrisonOutskirts.PATH_POINTS[i].distance_to(
			GarrisonOutskirts.PATH_POINTS[i + 1])
	rig.check(distance > 58.0, "main route crosses the full homestead")
	rig.check(outskirts.harvest_trees.size() == 18,
		"the west grove contains eighteen harvestable trees")
	for tree: HarvestTree in outskirts.harvest_trees:
		rig.check(tree.prompt == "CHOP TREE" and tree.hold_time > 0.0,
			"every grove tree exposes a held chop interaction")
		rig.check(tree.get_node_or_null(^"SolidTrunk/TrunkCollision") != null,
			"every grove tree has solid trunk collision")

	var homestead := outskirts.homestead
	if homestead == null:
		rig.fail("the authored homestead was not built")
		return
	rig.check(homestead.mine_portal != null,
		"the Sunken Cut mine has a visible authored portal")
	rig.check(homestead.bridge_obstruction != null,
		"the garrison bridge has a visible far boundary")
	rig.check(homestead.bridge_obstruction.get_node_or_null(
		^"BoundaryCollision/Collision") != null,
		"the player cannot walk off-screen over the bridge")
	rig.check(homestead.toolshed_anchor != null and homestead.garden_anchor != null,
		"toolshed and garden landmarks are authored")
	rig.check(homestead.central_statue != null,
		"the circular clearing has its statue landmark")
	rig.check(homestead.scenic_water.size() == 3,
		"river water and both scenic ponds use the authored water shader")
	var valley := outskirts.get_node_or_null(^"EnclosedValleyTerrain") \
		as EnclosedValleyTerrain
	rig.check(valley != null and valley.triangle_count() < 11000,
		"the enclosing heightmap terrain is present within its LOD triangle budget")
	if valley != null:
		rig.check(valley.baked_inner_mesh != null and valley.baked_mid_mesh != null
			and valley.baked_far_mesh != null,
			"all three terrain LOD bands are pre-baked resources")
		rig.check(valley.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"distant terrain remains visual-only and cannot alter authored traversal")
	var game_camera := outskirts.get_node_or_null(^"GameCamera") as Camera3D
	rig.check(game_camera != null and game_camera.far >= 300.0,
		"the gameplay camera can resolve the distant mountain skyline")
	var fishing_nodes := outskirts.find_children("*", "FishingHole", true, false)
	rig.check(fishing_nodes.size() == 1,
		"only the east pond owns the bounded fishing interaction")
	rig.check(outskirts.fishing_hole == fishing_nodes[0],
		"the public fishing-hole contract points at the east pond")
	await _verify_collisions(rig, outskirts)

	var cam := Camera3D.new()
	cam.fov = 48.0
	outskirts.add_child(cam)
	cam.make_current()
	var out: String = rig.out_base().get_base_dir()
	Prompt.drop_focus()
	# Use the production full-screen ownership path. Direct writes to Hud.visible
	# are deliberately repaired by Hud and produced contaminated proof frames.
	Bus.screen_opened.emit(&"outskirts_lookdev")
	await rig.wait_frames(3)

	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 87.0
	cam.global_transform = outskirts.port(&"vista_camera")
	await rig.wait_frames(6)
	await rig.capture(out.path_join("outskirts_00_homestead_overview.png"))

	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	var clearing := outskirts.port(&"clearing").origin
	cam.global_position = clearing + Vector3(13.0, 11.0, -15.0)
	cam.look_at(clearing + Vector3.UP * 1.4, Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_01_central_clearing.png"))

	var grove := outskirts.port(&"grove").origin
	cam.global_position = grove + Vector3(12.0, 13.5, 18.0)
	cam.look_at(grove + Vector3.UP * 3.3, Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_02_harvestable_grove.png"))

	var mine := homestead.mine_portal.global_position
	cam.global_position = mine + Vector3(-12.0, 11.5, -20.0)
	cam.look_at(mine + Vector3.UP * 2.7, Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_03_visible_mine.png"))

	var bridge := outskirts.port(&"garrison_gate").origin
	cam.global_position = bridge + Vector3(11.0, 12.0, -15.0)
	cam.look_at(bridge + Vector3(-4.0, 0.8, 3.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_04_garrison_bridge.png"))

	var garden := outskirts.port(&"garden").origin
	cam.global_position = garden + Vector3(-14.0, 10.0, -15.0)
	cam.look_at(garden + Vector3.UP * 1.2, Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_05_garden_toolshed.png"))

	var fishing := outskirts.port(&"fishing_hole").origin
	cam.global_position = fishing + Vector3(-12.0, 8.0, -12.0)
	cam.look_at(fishing + Vector3(0.0, 0.2, -2.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("outskirts_06_east_fishing_pond.png"))
	Bus.screen_closed.emit(&"outskirts_lookdev")
	print("OUTSKIRTS HOMESTEAD OK %.1f m" % distance)


func _verify_collisions(rig, outskirts: GarrisonOutskirts) -> void:
	var space := outskirts.get_world_3d().direct_space_state
	var bridge_from := OutskirtsHomestead.GARRISON_THRESHOLD + Vector3.UP * 0.9
	var bridge_to := OutskirtsHomestead.BRIDGE_END + Vector3(-2.0, 0.9, 1.4)
	var bridge_hit := space.intersect_ray(_ray(bridge_from, bridge_to))
	rig.check(not bridge_hit.is_empty(),
		"the bridge route ends at a physical boundary")
	if not bridge_hit.is_empty():
		var collider := bridge_hit[&"collider"] as Node
		rig.check(collider != null and collider.get_parent().name == &"BridgeBoundary",
			"the first bridge stop is the visible crossed-timber boundary")
		rig.check((bridge_hit[&"position"] as Vector3).distance_to(
			OutskirtsHomestead.BRIDGE_END) < 1.8,
			"bridge collision sits at the visible end rather than mid-span")

	var mine_hit := space.intersect_ray(_ray(
		OutskirtsHomestead.MINE_APPROACH + Vector3.UP * 1.0,
		OutskirtsHomestead.MINE_MOUTH + Vector3.UP * 1.0))
	rig.check(not mine_hit.is_empty(), "the mine portal has a solid interior stop")
	if not mine_hit.is_empty():
		var collider := mine_hit[&"collider"] as Node
		rig.check(collider != null and collider.name == &"MineInteriorCollision",
			"the mine collision corresponds to its visible dark threshold")

	var east_centre := OutskirtsHomestead.FISHING_CENTER + Vector3(0.5, 0.0, -2.25)
	var pond_hit := space.intersect_ray(_ray(
		east_centre + Vector3(-11.0, 0.65, 0.0),
		east_centre + Vector3(11.0, 0.65, 0.0)))
	rig.check(not pond_hit.is_empty(), "the east pond bank is physically bounded")


func _ray(from: Vector3, to: Vector3) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(from, to, K.L_WORLD)
	query.collide_with_areas = false
	query.hit_from_inside = false
	return query
