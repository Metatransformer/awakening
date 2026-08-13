extends RefCounted
## Spatial and atmosphere proof for the authored garrison floor plan.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_layout.gd \
##     --out=/tmp/garrison-layout/x.png --size=1280x720 --warmup=60


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the real garrison courtyard"):
		return
	Clock.running = false
	Clock.set_time(1, 12.0)
	await rig.wait_frames(45)

	var compound: GarrisonCompound = garrison.compound
	if not rig.check(compound != null, "the generated garrison compound exists"):
		return
	_prove_floor_plan(rig, compound)
	_prove_furnished_interiors(rig, compound)
	_prove_warm_lighting(rig, compound)
	_prove_elder_arrival(rig, compound)
	_prove_open_surface(rig, garrison, compound)
	var valley := garrison.get_node_or_null(^"EnclosedValleyTerrain") \
		as EnclosedValleyTerrain
	rig.check(valley != null and valley.baked_inner_mesh != null
		and valley.baked_mid_mesh != null and valley.baked_far_mesh != null,
		"the garrison reuses the three pre-baked enclosed-valley LOD bands")
	var game_camera := garrison.get_node_or_null(^"GameCamera") as Camera3D
	rig.check(game_camera != null and game_camera.far >= 300.0,
		"the garrison camera resolves the reused mountain skyline")
	Menu.close()
	Prompt.drop_focus()
	# HUD visibility is authority-owned and intentionally repairs direct external
	# writes every tree change. Announce a synthetic full-screen lookdev surface so
	# the contact sheet is clean through the same supported path as production UI.
	Bus.screen_opened.emit(&"garrison_lookdev")
	await rig.wait_frames(3)

	var camera := Camera3D.new()
	camera.fov = 56.0
	garrison.add_child(camera)
	camera.make_current()
	var out: String = rig.out_base().get_base_dir()

	# A plan-like overview and the player's south-gate arrival establish the
	# compound's overall shape before the tour moves into individual districts.
	_frame(camera, compound, Vector3(0.0, 30.0, 27.0), Vector3(0.0, 0.0, -1.0), 55.0)
	await _capture(rig, out, "layout_00_floorplan.png")
	_frame(camera, compound, Vector3(0.0, 1.75, 12.9), Vector3(-0.9, 1.2, 8.0), 52.0)
	await _capture(rig, out, "layout_01_elder_at_entrance.png")

	# The garden and craft district are deliberately separate destinations, not
	# counters pushed into a row. These views show their paths and silhouettes.
	_frame(camera, compound, Vector3(4.0, 9.5, 10.0), Vector3(-9.0, 0.8, 0.0), 58.0)
	await _capture(rig, out, "layout_02_garden_and_west_district.png")
	_frame(camera, compound, Vector3(-6.0, 5.2, 3.0), Vector3(-18.2, 1.2, -0.7), 62.0)
	await _capture(rig, out, "layout_03_craft_buildings.png")
	_frame(camera, compound, Vector3(4.5, 5.0, 10.5), Vector3(17.2, 1.3, 4.3), 60.0)
	await _capture(rig, out, "layout_04_quartermaster.png")

	# North wing exterior and enterable interiors.
	_frame(camera, compound, Vector3(0.0, 7.5, -3.0), Vector3(-6.0, 1.1, -13.7), 61.0)
	await _capture(rig, out, "layout_05_north_wing.png")
	_frame(camera, compound, Vector3(-14.1, 1.65, -10.2), Vector3(-19.0, 1.0, -13.0), 66.0)
	await _capture(rig, out, "layout_06_barracks_interior.png")
	_frame(camera, compound, Vector3(-6.9, 2.15, -11.35), Vector3(-6.9, 0.65, -15.0), 72.0)
	await _capture(rig, out, "layout_07_mess_hall_interior.png")
	camera.global_transform = compound.global_transform * compound.port(&"elder_room_camera")
	await _capture(rig, out, "layout_08_leader_quarters_interior.png")

	# Individual work interiors prove their own material identities and detail.
	_frame(camera, compound, Vector3(-14.65, 1.6, -4.6), Vector3(-19.2, 1.0, -4.8), 68.0)
	await _capture(rig, out, "layout_09_smithy_interior.png")
	_frame(camera, compound, Vector3(-14.7, 1.6, 2.75), Vector3(-19.2, 1.0, 3.4), 68.0)
	await _capture(rig, out, "layout_10_jewelcrafter_interior.png")
	_frame(camera, compound, Vector3(-13.25, 1.6, 11.1), Vector3(-18.2, 1.0, 11.2), 68.0)
	await _capture(rig, out, "layout_11_builder_interior.png")
	_frame(camera, compound, Vector3(13.15, 1.6, 4.3), Vector3(18.3, 1.0, 4.3), 68.0)
	await _capture(rig, out, "layout_12_quartermaster_interior.png")

	_frame(camera, compound, Vector3(0.0, 4.2, 7.0), Vector3(0.0, 1.2, 28.0), 61.0)
	await _capture(rig, out, "layout_13_open_surface_gate.png")

	# At night the courtyard stays comparatively cool while every enclosed room
	# becomes an amber destination; the smithy retains its hotter orange identity.
	Clock.set_time(1, 23.5)
	await rig.wait_frames(60)
	_frame(camera, compound, Vector3(0.0, 18.0, 21.0), Vector3(0.0, 0.8, -2.0), 58.0)
	await _capture(rig, out, "layout_14_warm_interiors_night.png")
	_frame(camera, compound, Vector3(-14.65, 1.6, -4.6), Vector3(-19.2, 1.0, -4.8), 68.0)
	await _capture(rig, out, "layout_15_smithy_warm_night.png")
	print("GARRISON FLOOR PLAN OK")


func _prove_floor_plan(rig, compound: GarrisonCompound) -> void:
	var expected := [
		"Buildings/Barracks", "Buildings/MessHall", "Buildings/LeaderQuarters",
		"Buildings/Smithy", "Buildings/Jewelcrafter", "Buildings/BuilderWorkshop",
		"Buildings/Quartermaster", "Buildings/WestSupplyRoom",
		"Buildings/EastSupplyRoom", "Garden",
	]
	for path: String in expected:
		rig.check(compound.get_node_or_null(path) != null, "%s exists" % path)

	var smith := compound.port(&"smith_day").origin
	var jeweller := compound.port(&"jewelcrafter_day").origin
	var quartermaster := compound.port(&"quartermaster_day").origin
	var alchemist := compound.port(&"alchemist_day").origin
	rig.check(smith.x < -14.0 and jeweller.x < -14.0 and smith.z < jeweller.z,
		"smith and jeweller occupy distinct west-side buildings")
	rig.check(quartermaster.x > 12.0 and alchemist.x < -4.0 and alchemist.x > -11.0,
		"quartermaster anchors the east while alchemist works in the inner garden")
	rig.check(compound.get_node_or_null("Garden/GardenCropRow01") != null
		and compound.get_node_or_null("Garden/GardenWaterButt") != null
		and compound.get_node_or_null("Garden/AlchemistTrellisCanopy") != null,
		"the fenced garden has crops, water, paths, and an alchemist trellis")


func _prove_furnished_interiors(rig, compound: GarrisonCompound) -> void:
	rig.check(compound.get_node_or_null("Buildings/Barracks/BarracksDoorLintel") != null
		and compound.get_node_or_null("Buildings/Barracks/WeaponLocker") != null
		and compound.get_node_or_null("Buildings/Barracks/PlayerBunk") != null,
		"the barracks is an enclosed furnished sleeping room")
	rig.check(compound.get_node_or_null("Buildings/MessHall/MessTable") != null
		and compound.get_node_or_null("Buildings/MessHall/MessBenchNorth") != null
		and compound.get_node_or_null("Buildings/MessHall/ServingSideboard") != null,
		"the mess hall has communal seating and food storage")
	rig.check(compound.get_node_or_null("Buildings/LeaderQuarters/LeaderBedFrame") != null
		and compound.get_node_or_null("Buildings/LeaderQuarters/MapDesk") != null
		and compound.get_node_or_null("Buildings/LeaderQuarters/Bookcase") != null,
		"the leader has a private, furnished room")
	rig.check(compound.get_node_or_null("Buildings/Smithy/SmithChimney") != null
		and compound.get_node_or_null("Buildings/Jewelcrafter/JewelDisplayPlinth") != null
		and compound.get_node_or_null("Buildings/BuilderWorkshop/BuilderWorktable") != null
		and compound.get_node_or_null("Buildings/Quartermaster/CargoStackNorth") != null,
		"each trade building has profession-specific dressing")


func _prove_warm_lighting(rig, compound: GarrisonCompound) -> void:
	var paths := [
		"Buildings/Barracks/InteriorLightNorth",
		"Buildings/MessHall/InteriorLight",
		"Buildings/LeaderQuarters/InteriorLight",
		"Buildings/Smithy/InteriorLight",
		"Buildings/Jewelcrafter/InteriorLight",
		"Buildings/BuilderWorkshop/InteriorLight",
		"Buildings/Quartermaster/InteriorLight",
		"Buildings/WestSupplyRoom/InteriorLight",
		"Buildings/EastSupplyRoom/InteriorLight",
	]
	for path: String in paths:
		var light := compound.get_node_or_null(path) as OmniLight3D
		rig.check(light != null and light.light_color.r > light.light_color.g
			and light.light_color.g > light.light_color.b,
			"%s uses a warm amber interior light" % path)
	var smith_light := compound.get_node_or_null(
		"Buildings/Smithy/InteriorLight") as OmniLight3D
	rig.check(smith_light != null and smith_light.light_color.g < 0.65,
		"the forge atmosphere is hotter orange than the other rooms")


func _prove_elder_arrival(rig, compound: GarrisonCompound) -> void:
	var elder := compound.port(&"elder_day")
	var arrival := compound.port(&"arrival")
	var hero := compound.get_tree().get_first_node_in_group(&"player") as Node3D
	rig.check(hero != null and K.plane(compound.to_local(hero.global_position)
		- arrival.origin).length() < 0.25,
		"the live hero spawn uses the compound arrival port")
	var to_arrival := K.plane(arrival.origin - elder.origin)
	var elder_forward := K.plane(elder.basis.z).normalized()
	rig.check(to_arrival.length() > 2.0 and to_arrival.length() < 2.6,
		"the elder waits in front of the garrison entrance")
	rig.check(elder_forward.dot(to_arrival.normalized()) > 0.9,
		"the elder faces the arriving hero")


func _prove_open_surface(rig, garrison: Garrison,
		compound: GarrisonCompound) -> void:
	rig.check(compound.get_node_or_null("SouthGatehouse/ExitBackstop") == null,
		"the south gate has no unloaded-space backstop")
	rig.check(compound.get_node_or_null("SouthGatehouse/RaisedPortcullis") != null,
		"the open raid arch carries a visibly raised portcullis")
	rig.check(garrison.outskirts != null and garrison.sunken_cut != null,
		"the homestead and Sunken Cut are live inside the garrison surface")
	rig.check(garrison.outskirts.garrison_gate == null
		and garrison.outskirts.blocked_path == null
		and garrison.outskirts.homestead.bridge_obstruction == null,
		"the embedded bridge has no loading transition or visual obstruction")
	var bridge_end := garrison.outskirts.to_global(OutskirtsHomestead.BRIDGE_END)
	rig.check(bridge_end.distance_to(Vector3(0.0, -0.10, 18.0)) < 0.001,
		"the timber bridge terminates exactly at the fort ground seam")
	rig.check(garrison.get_tree().get_nodes_in_group(&"player").size() == 1
		and garrison.find_children("*", "Camera3D", true, false).size() == 1
		and garrison.find_children("SurfaceAtmosphere", "SurfaceAtmosphere", true, false).size() == 1
		and garrison.find_children("EnclosedValleyTerrain", "EnclosedValleyTerrain", true, false).size() == 1,
		"the combined surface owns one hero, camera, atmosphere, and valley")


func _capture(rig, out: String, file_name: String) -> void:
	await rig.wait_frames(5)
	await rig.capture(out.path_join(file_name))


func _frame(camera: Camera3D, compound: GarrisonCompound, eye: Vector3,
		target: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.global_position = compound.to_global(eye)
	camera.look_at(compound.to_global(target), Vector3.UP)
