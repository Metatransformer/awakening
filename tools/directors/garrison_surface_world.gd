extends RefCounted
## Structural and gameplay-height visual proof for the seamless Highbridge surface.


func run(rig) -> void:
	var world := rig.scene() as Garrison
	if not rig.check(world != null, "combined proof loaded the production Garrison"):
		return
	await rig.wait_frames(30)
	var outside := world.outskirts
	var terrain := world.get_node_or_null(^"EnclosedValleyTerrain") \
		as EnclosedValleyTerrain
	rig.check(outside != null and outside.embedded_in_garrison,
		"outskirts gameplay is embedded inside the production garrison")
	rig.check(world.sunken_cut == outside.sunken_cut,
		"the production descent points at the embedded visible mine")
	rig.check(outside.garrison_gate == null and outside.blocked_path == null,
		"there is no loading transition or blocked bridge in the combined world")
	rig.check(world.compound.get_node_or_null(^"SouthGatehouse/ExitBackstop") == null,
		"the fort gate passage is physically open")
	rig.check(world.compound.get_node_or_null(^"ArtPass/GateVista") == null,
		"the old fake gate vista was replaced by the real homestead")
	rig.check(terrain != null and terrain.baked_inner_mesh != null
		and terrain.baked_mid_mesh != null and terrain.baked_far_mesh != null,
		"one combined baked heightmap terrain encloses the whole surface")
	if terrain != null:
		_prove_lod_seams(rig, terrain)
	_prove_single_owners(rig, world)
	_prove_layout_and_map(rig, world)
	_prove_legacy_transform(rig)
	await _capture_world(rig, world)
	print("GARRISON SURFACE WORLD OK")


func _prove_single_owners(rig, world: Garrison) -> void:
	rig.check(world.get_tree().get_nodes_in_group(&"player").size() == 1,
		"the combined surface has exactly one Hero")
	rig.check(world.find_children("*", "GameCamera", true, false).size() == 1,
		"the combined surface has exactly one production camera")
	rig.check(world.find_children("SurfaceAtmosphere", "SurfaceAtmosphere", true,
		false).size() == 1, "the combined surface has exactly one atmosphere")
	rig.check(world.find_children("EnclosedValleyTerrain", "EnclosedValleyTerrain",
		true, false).size() == 1, "the combined surface has exactly one valley")
	rig.check(Atlas.map_provider() == world,
		"only the Garrison composition root publishes the Atlas map")


func _prove_layout_and_map(rig, world: Garrison) -> void:
	var bridge := world.outskirts.to_global(OutskirtsHomestead.BRIDGE_END)
	rig.check(bridge.distance_to(Vector3(0.0, -0.10, 18.0)) < 0.001,
		"the homestead bridge and fort threshold share one exact seam")
	var mine := world.outskirts.global_port(&"sunken_cut").origin
	rig.check(mine.distance_to(world.gate.global_position) > 45.0,
		"the visible mine is a real journey beyond the open gate")
	var plan := world.surface_map_plan()
	var glyphs: Array[StringName] = []
	for landmark: Dictionary in plan[&"landmarks"]:
		glyphs.append(StringName(landmark[&"glyph"]))
	rig.check(String(plan[&"title"]) == "Highbridge Garrison"
		and float(plan[&"view_range"]) >= 120.0,
		"the merged map owns the whole Highbridge surface")
	rig.check(glyphs.count(&"gate") == 1 and glyphs.has(&"dungeon")
		and glyphs.has(&"fishing") and glyphs.has(&"grove"),
		"the combined map contains one fort gate plus mine, pond, and grove")


func _prove_legacy_transform(rig) -> void:
	var previous_scene_path := Saves.current_scene_path
	var legacy_destination := {
		"scene": Flow.OUTSKIRTS,
		"pos": GarrisonSurfaceLayout.LEGACY_BRIDGE_END,
		"yaw": GarrisonSurfaceLayout.LEGACY_ARRIVAL_YAW,
	}
	var migrated := Flow._migrate_legacy_outskirts_destination(legacy_destination)
	var seam := GarrisonSurfaceLayout.transform_legacy_position(
		GarrisonSurfaceLayout.LEGACY_BRIDGE_END)
	rig.check(seam.distance_to(GarrisonSurfaceLayout.EMBEDDED_BRIDGE_END) < 0.001,
		"legacy outskirts coordinates migrate through the exact bridge seam")
	rig.check(String(migrated.get("scene", "")) == Flow.GARRISON
		and (migrated.get("pos", Vector3.ZERO) as Vector3).distance_to(seam) < 0.001
		and Saves.current_scene_path == Flow.GARRISON,
		"the live resume migration canonicalizes legacy scene and position ownership")
	var old_forward := Basis(Vector3.UP,
		GarrisonSurfaceLayout.LEGACY_ARRIVAL_YAW).z
	var migrated_yaw := GarrisonSurfaceLayout.transform_legacy_yaw(
		GarrisonSurfaceLayout.LEGACY_ARRIVAL_YAW)
	var expected_forward := GarrisonSurfaceLayout.outskirts_world_transform().basis \
		* old_forward
	rig.check(Basis(Vector3.UP, migrated_yaw).z.dot(expected_forward) > 0.999,
		"legacy outskirts yaw migrates with the embedded area")
	rig.check(is_equal_approx(float(migrated.get("yaw", 999.0)), migrated_yaw),
		"the live resume migration rotates the legacy facing into combined space")
	Saves.current_scene_path = previous_scene_path


func _prove_lod_seams(rig, terrain: EnclosedValleyTerrain) -> void:
	var inner := _vertices(terrain.baked_inner_mesh)
	var mid := _vertices(terrain.baked_mid_mesh)
	var far := _vertices(terrain.baked_far_mesh)
	var stride := EnclosedValleyTerrain.INNER_ANGULAR_SEGMENTS + 1
	var inner_row := EnclosedValleyTerrain.INNER_RADIAL_SEGMENTS * stride
	var mid_row := EnclosedValleyTerrain.MID_RADIAL_SEGMENTS * stride
	var inner_mid_error := 0.0
	var mid_far_error := 0.0
	for i: int in stride:
		inner_mid_error = maxf(inner_mid_error, inner[inner_row + i].distance_to(mid[i]))
		mid_far_error = maxf(mid_far_error, mid[mid_row + i].distance_to(far[i]))
	rig.check(inner_mid_error <= 0.00001 and mid_far_error <= 0.00001,
		"all 129 vertices match exactly across both terrain LOD rings")


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _capture_world(rig, world: Garrison) -> void:
	Menu.close()
	Prompt.drop_focus()
	Bus.screen_opened.emit(&"garrison_surface_world")
	var production_camera := world.get_node_or_null(^"GameCamera") as Camera3D
	var camera := Camera3D.new()
	camera.fov = 55.0
	world.add_child(camera)
	camera.make_current()
	var outside := world.outskirts
	var out: String = rig.out_base().get_base_dir()
	_frame(camera, world.gate.global_position + Vector3(0.0, 2.5, -6.5),
		outside.global_port(&"arrival").origin + Vector3.UP * 1.2)
	await _shot(rig, out, "surface_00_gate_to_homestead.png")
	_frame(camera, outside.global_port(&"arrival").origin + Vector3.UP * 2.0,
		world.gate.global_position + Vector3.UP * 2.7)
	await _shot(rig, out, "surface_01_homestead_to_fort.png")
	var clearing := outside.global_port(&"clearing").origin
	_frame(camera, clearing + Vector3(12.0, 7.0, -14.0), clearing + Vector3.UP * 1.2)
	await _shot(rig, out, "surface_02_clearing.png")
	var mine := outside.homestead.mine_portal.global_position
	_frame(camera, mine + outside.global_basis * Vector3(-11.0, 7.0, -17.0),
		mine + Vector3.UP * 2.4)
	await _shot(rig, out, "surface_03_visible_mine.png")
	var grove := outside.global_port(&"grove").origin
	_frame(camera, grove + outside.global_basis * Vector3(9.0, 7.0, 13.0),
		grove + Vector3.UP * 3.0)
	await _shot(rig, out, "surface_04_dense_grove.png")
	var pond := outside.global_port(&"fishing_hole").origin
	_frame(camera, pond + outside.global_basis * Vector3(-10.0, 6.0, -10.0),
		pond + Vector3.UP * 0.6)
	await _shot(rig, out, "surface_05_fishing_pond.png")
	if production_camera != null:
		production_camera.make_current()
	camera.queue_free()
	await rig.wait_frames(2)


func _frame(camera: Camera3D, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)


func _shot(rig, out: String, file_name: String) -> void:
	await rig.wait_frames(5)
	await rig.capture(out.path_join(file_name))
