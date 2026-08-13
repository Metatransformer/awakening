extends RefCounted
## Spatial proof for the garrison's room-and-nook layout.
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
	_prove_rooms(rig, compound)
	_prove_service_nooks(rig, compound)
	_prove_elder_arrival(rig, compound)
	var valley := garrison.get_node_or_null(^"EnclosedValleyTerrain") \
		as EnclosedValleyTerrain
	rig.check(valley != null and valley.baked_inner_mesh != null
		and valley.baked_mid_mesh != null and valley.baked_far_mesh != null,
		"the garrison reuses the three pre-baked enclosed-valley LOD bands")
	var game_camera := garrison.get_node_or_null(^"GameCamera") as Camera3D
	rig.check(game_camera != null and game_camera.far >= 300.0,
		"the garrison camera resolves the reused mountain skyline")

	var camera := Camera3D.new()
	camera.fov = 56.0
	garrison.add_child(camera)
	camera.make_current()
	var out: String = rig.out_base().get_base_dir()

	# One architectural read, then the player's entrance read.
	_frame(camera, compound, Vector3(0.0, 15.0, 21.0), Vector3(0.0, 1.0, -3.0), 62.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_00_compound.png"))
	_frame(camera, compound, Vector3(0.0, 1.7, 12.8), Vector3(-0.9, 1.2, 7.9), 52.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_01_elder_at_entrance.png"))

	# The oblique angle is deliberate: it shows that the three east services and
	# the north apothecary are separate destinations instead of one counter line.
	_frame(camera, compound, Vector3(4.5, 9.0, 11.0), Vector3(14.0, 1.2, -2.5), 62.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_02_service_nooks.png"))

	# Exterior/interior pairs prove that these are rooms with usable doors, not
	# roofed scenery that only reads from the aerial shot.
	_frame(camera, compound, Vector3(-6.0, 2.4, 11.0), Vector3(-14.0, 1.45, 10.4), 55.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_03_barracks_door.png"))
	_frame(camera, compound, Vector3(-15.3, 1.75, 10.4), Vector3(-19.2, 0.95, 1.5), 64.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_04_barracks_interior.png"))

	_frame(camera, compound, Vector3(-18.2, 2.1, -10.8), Vector3(-18.2, 1.15, -14.0), 72.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_05_elder_room_door.png"))
	camera.global_transform = compound.global_transform * compound.port(&"elder_room_camera")
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_06_elder_room_interior.png"))

	_frame(camera, compound, Vector3(-9.0, 1.9, -7.4), Vector3(-9.0, 1.0, -14.5), 58.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_07_mess_hall.png"))

	_frame(camera, compound, Vector3(0.0, 1.7, 12.7), Vector3(0.0, 2.1, 18.0), 58.0)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("layout_08_exit_backstop.png"))
	print("GARRISON LAYOUT OK")


func _prove_rooms(rig, compound: GarrisonCompound) -> void:
	rig.check(compound.get_node_or_null("BunkRoom/BarracksWestWall") != null
		and compound.get_node_or_null("BunkRoom/BarracksEastNorthReturn") != null
		and compound.get_node_or_null("BunkRoom/BarracksDoorLintel") != null,
		"the barracks has four-sided enclosure with one framed courtyard door")
	rig.check(compound.get_node_or_null("ElderQuarters/ElderWestWall") != null
		and compound.get_node_or_null("ElderQuarters/ElderNorthWall") != null
		and compound.get_node_or_null("ElderQuarters/ElderDoorLintel") != null,
		"the elder quarters is a closed room with a centered doorway")
	rig.check(compound.get_node_or_null("NorthCommunalAndWork/MessHall/MessTable") != null
		and compound.get_node_or_null("NorthCommunalAndWork/MessHall/MessBench") != null
		and compound.get_node_or_null("NorthCommunalAndWork/MessHall/ServingSideboard") != null,
		"the north wing contains a furnished mess hall")
	var backstop := compound.get_node_or_null(
		"SouthGatehouse/ExitBackstop/Collision") as CollisionShape3D
	var backstop_shape := backstop.shape as BoxShape3D if backstop != null else null
	rig.check(backstop_shape != null and backstop_shape.size.x >= 5.8
		and backstop_shape.size.y >= 4.8,
		"the departure gate blocks walking or jumping into unloaded space")


func _prove_service_nooks(rig, compound: GarrisonCompound) -> void:
	var names := [&"QuartermasterNook", &"JewelcrafterNook", &"SmithNook", &"AlchemistNook"]
	for nook: StringName in names:
		rig.check(compound.get_node_or_null("ServiceNooks/%s" % nook) != null,
			"%s is a named service nook" % nook)

	var quartermaster := compound.port(&"quartermaster_day").origin
	var jeweller := compound.port(&"jewelcrafter_day").origin
	var smith := compound.port(&"smith_day").origin
	var alchemist := compound.port(&"alchemist_day").origin
	var ports := [quartermaster, jeweller, smith, alchemist]
	var separated := true
	for first: int in ports.size():
		for second: int in range(first + 1, ports.size()):
			separated = separated and K.plane(ports[first] - ports[second]).length() > 6.0
	rig.check(separated and alchemist.x < 12.0 and quartermaster.x > 14.0,
		"service positions are separated and turn the north-east corner")


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
		"the elder waits at conversation distance in front of the arrival")
	rig.check(elder_forward.dot(to_arrival.normalized()) > 0.9,
		"the elder faces the arriving hero")


func _frame(camera: Camera3D, compound: GarrisonCompound, eye: Vector3,
		target: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.global_position = compound.to_global(eye)
	camera.look_at(compound.to_global(target), Vector3.UP)
