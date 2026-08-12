class_name GarrisonCompound
extends Node3D
## Deterministic inner-fort geometry for the garrison hub. This node owns only
## structure and local-space ports; the surrounding Garrison owns cast and sky.

const KIT_FLOOR: PackedScene = preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL: PackedScene = preload("res://scenes/kit/wall_segment.tscn")
const KIT_PILLAR: PackedScene = preload("res://scenes/kit/pillar.tscn")

const MAT_WALL := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_FLOOR := preload("res://assets/materials/mat_floor.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")

const COMPOUND_SIZE := Vector2(45.0, 36.0)
const HALF_X := COMPOUND_SIZE.x * 0.5
const HALF_Z := COMPOUND_SIZE.y * 0.5
const WALL_HEIGHT := 6.6
const ROOF_HEIGHT := 3.45
const ROOF_THICKNESS := 0.24
const SERVICE_BAY := 5.0
const CLEAR_CIRCULATION := 4.0
const PARADE_SIZE := Vector2(17.0, 15.0)

const BARRACKS_FRONT_X := -14.0
const BARRACKS_BACK_X := -22.1
const BARRACKS_NORTH_Z := -9.2
const BARRACKS_SOUTH_Z := 13.6
const BUNK_X := -19.3

const ARCADE_FRONT_X := 13.0
const ARCADE_BACK_X := 22.1
const ARCADE_NORTH_Z := -11.5
const ARCADE_SOUTH_Z := 13.5

var player_bunk: BunkBed
var bunk_room: Node3D
var elder_quarters: Node3D

var _ports: Dictionary[StringName, Transform3D] = {}
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	_define_ports()
	_build_ground()
	_build_curtain()
	_build_gatehouse()
	_build_parade_yard()
	_build_barracks()
	_build_elder_quarters()
	_build_service_arcade()
	_build_north_range()
	_build_cross_corridors()


func port(id: StringName) -> Transform3D:
	if not _ports.has(id):
		push_error("GarrisonCompound: unknown port '%s'." % id)
		return Transform3D.IDENTITY
	return _ports[id]


func has_port(id: StringName) -> bool:
	return _ports.has(id)


func _define_ports() -> void:
	var hearth_at := Vector3(-1.0, 0.05, -1.0)
	_ports = {
		&"arrival": _port_at(Vector3(0.0, 0.05, 10.2), 0.0),
		&"gate": _port_at(Vector3(0.0, 0.05, 15.4), 0.0),
		&"quartermaster_day": _port_at(Vector3(15.3, 0.05, -9.0), -PI * 0.5),
		&"smith_day": _port_at(Vector3(15.3, 0.05, -4.0), -PI * 0.5),
		&"alchemist_day": _port_at(Vector3(15.3, 0.05, 1.0), -PI * 0.5),
		&"elder_day": _port_at(Vector3(15.3, 0.05, 6.0), -PI * 0.5),
		&"jewelcrafter_day": _port_at(Vector3(15.3, 0.05, 11.0), -PI * 0.5),
		&"builder_day": _port_at(Vector3(8.0, 0.05, -12.8), 0.0),
		&"hearth": _port_at(hearth_at, 0.0),
		&"quartermaster_bonfire": _facing_port(
			hearth_at + Vector3(-3.0, 0.0, 0.8), hearth_at),
		&"smith_bonfire": _facing_port(
			hearth_at + Vector3(-1.8, 0.0, -2.5), hearth_at),
		&"alchemist_bonfire": _facing_port(
			hearth_at + Vector3(1.8, 0.0, -2.5), hearth_at),
		&"elder_bonfire": _facing_port(
			hearth_at + Vector3(3.0, 0.0, 0.8), hearth_at),
		&"jewelcrafter_bonfire": _facing_port(
			hearth_at + Vector3(0.0, 0.0, 3.1), hearth_at),
		&"builder_bonfire": _facing_port(
			hearth_at + Vector3(0.0, 0.0, -3.2), hearth_at),
		&"quartermaster_sleep": _sleep_port(Vector3(BUNK_X, 0.58, -6.6), PI * 0.5),
		&"smith_sleep": _sleep_port(Vector3(BUNK_X, 0.58, -2.3), PI * 0.5),
		&"alchemist_sleep": _sleep_port(Vector3(BUNK_X, 0.58, 2.0), PI * 0.5),
		&"jewelcrafter_sleep": _sleep_port(Vector3(BUNK_X, 0.58, 6.3), PI * 0.5),
		&"player_bunk": _port_at(Vector3(-16.0, 0.05, 10.6), PI * 0.5),
		&"elder_sleep": _sleep_port(Vector3(-19.4, 0.58, -14.8), 0.0),
		&"builder_sleep": _sleep_port(Vector3(-12.6, 0.58, -16.3), 0.0),
		&"elder_room_camera": _camera_port(
			Vector3(-14.7, 2.25, -10.2), Vector3(-18.6, 1.0, -14.4)
		),
	}


func _build_ground() -> void:
	var ground := _group(self, "Ground")
	_floor_slab(ground, "FortGround", COMPOUND_SIZE, Vector3.ZERO, MAT_GRASS, true)
	# Flush paving defines the routes without adding controller-catching kerbs or
	# duplicate floor collision over the compound's single ground slab.
	_floor_slab(
		ground, "ParadePaving", PARADE_SIZE, Vector3(0.0, 0.008, -0.5), MAT_FLOOR, false
	)
	_floor_slab(
		ground, "WestWalk", Vector2(CLEAR_CIRCULATION, 25.0),
		Vector3(-11.8, 0.009, 1.0), MAT_FLOOR, false
	)
	_floor_slab(
		ground, "EastWalk", Vector2(CLEAR_CIRCULATION, 27.0),
		Vector3(11.0, 0.009, 0.5), MAT_FLOOR, false
	)
	_floor_slab(
		ground, "NorthWalk", Vector2(27.0, CLEAR_CIRCULATION),
		Vector3(-0.5, 0.010, -10.1), MAT_FLOOR, false
	)
	_floor_slab(
		ground, "SouthWalk", Vector2(27.0, CLEAR_CIRCULATION),
		Vector3(-0.5, 0.010, 9.3), MAT_FLOOR, false
	)


func _build_curtain() -> void:
	var curtain := _group(self, "CurtainWall")
	# The northeast dogleg breaks the municipal rectangle: the north wall steps
	# inward before meeting the long east curtain.
	_wall(curtain, "NorthCurtain", 41.5, Vector3(-1.75, 0.0, -HALF_Z), 0.0, 7201)
	_wall(curtain, "NorthEastReturn", 4.0, Vector3(19.0, 0.0, -16.0),
		-PI * 0.5, 7202)
	_wall(curtain, "Dogleg", 3.5, Vector3(20.75, 0.0, -14.0), 0.0, 7203)
	_wall(curtain, "EastCurtain", 32.0, Vector3(HALF_X, 0.0, 2.0),
		-PI * 0.5, 7204)
	_wall(curtain, "WestCurtain", COMPOUND_SIZE.y,
		Vector3(-HALF_X, 0.0, 0.0), PI * 0.5, 7205)

	var gate_half := 3.0
	var south_run := (COMPOUND_SIZE.x - gate_half * 2.0) * 0.5
	var run_x := gate_half + south_run * 0.5
	_wall(curtain, "SouthCurtainWest", south_run,
		Vector3(-run_x, 0.0, HALF_Z), PI, 7206)
	_wall(curtain, "SouthCurtainEast", south_run,
		Vector3(run_x, 0.0, HALF_Z), PI, 7207)

	_pillar(curtain, "NorthWestTower", Vector3(-HALF_X, 0.0, -HALF_Z), 8.2)
	_pillar(curtain, "SouthWestTower", Vector3(-HALF_X, 0.0, HALF_Z), 8.2)
	_pillar(curtain, "SouthEastTower", Vector3(HALF_X, 0.0, HALF_Z), 8.2)
	_pillar(curtain, "DoglegTower", Vector3(19.0, 0.0, -HALF_Z), 8.2)
	_pillar(curtain, "EastShoulderTower", Vector3(HALF_X, 0.0, -14.0), 7.7)


func _build_gatehouse() -> void:
	var gatehouse := _group(self, "SouthGatehouse")
	var tower_size := Vector3(4.2, 7.4, 7.2)
	for sx: float in [-1.0, 1.0]:
		_solid_box(
			gatehouse,
			"GateTower",
			tower_size,
			Vector3(sx * 5.1, tower_size.y * 0.5, 15.4),
			MAT_WALL
		)
		_solid_box(
			gatehouse,
			"TowerCap",
			Vector3(4.7, 0.38, 7.7),
			Vector3(sx * 5.1, 7.45, 15.4),
			MAT_WALL
		)
	_solid_box(
		gatehouse,
		"PassageRoof",
		Vector3(6.0, 0.48, 7.2),
		Vector3(0.0, 5.25, 15.4),
		MAT_WOOD
	)
	# Open timber leaves make the gate legible without ever closing the six-metre
	# camera-safe passage.
	for sx: float in [-1.0, 1.0]:
		_visual_box(
			gatehouse,
			"OpenGateLeaf",
			Vector3(0.18, 3.5, 2.4),
			Vector3(sx * 2.72, 1.75, 16.8),
			MAT_WOOD,
			sx * deg_to_rad(22.0)
		)


func _build_parade_yard() -> void:
	var parade := _group(self, "ParadeYard")
	# The existing First Lantern statue is the compound's central landmark. Keep
	# the generated parade ground open around it instead of competing with a
	# second mast and plinth in the same sightline.
	for z: float in [-5.4, 4.4]:
		_visual_box(
			parade, "FormationLine", Vector3(12.0, 0.025, 0.16),
			Vector3(0.0, 0.035, z), MAT_WALL
		)


func _build_barracks() -> void:
	bunk_room = _group(self, "BunkRoom")
	var width := BARRACKS_FRONT_X - BARRACKS_BACK_X
	var length := BARRACKS_SOUTH_Z - BARRACKS_NORTH_Z
	_floor_slab(
		bunk_room, "BarracksDeck", Vector2(width, length),
		Vector3((BARRACKS_FRONT_X + BARRACKS_BACK_X) * 0.5, 0.012,
			(BARRACKS_NORTH_Z + BARRACKS_SOUTH_Z) * 0.5), MAT_FLOOR, false
	)
	_solid_box(
		bunk_room, "BarracksRoof", Vector3(width + 0.35, ROOF_THICKNESS, length + 0.4),
		Vector3((BARRACKS_FRONT_X + BARRACKS_BACK_X) * 0.5, ROOF_HEIGHT,
			(BARRACKS_NORTH_Z + BARRACKS_SOUTH_Z) * 0.5), MAT_WOOD
	)
	_wall(bunk_room, "BarracksNorthWall", width,
		Vector3((BARRACKS_FRONT_X + BARRACKS_BACK_X) * 0.5, 0.0,
			BARRACKS_NORTH_Z), 0.0, 7311, ROOF_HEIGHT)
	_wall(bunk_room, "BarracksSouthWall", width,
		Vector3((BARRACKS_FRONT_X + BARRACKS_BACK_X) * 0.5, 0.0,
			BARRACKS_SOUTH_Z), PI, 7312, ROOF_HEIGHT)
	for z: float in [-8.8, -1.2, 6.4, 13.2]:
		_solid_box(
			bunk_room, "FrontPost", Vector3(0.24, ROOF_HEIGHT, 0.24),
			Vector3(BARRACKS_FRONT_X + 0.15, ROOF_HEIGHT * 0.5, z), MAT_WOOD
		)

	var bunk_zs: Array[float] = [-6.6, -2.3, 2.0, 6.3, 10.6]
	for index: int in bunk_zs.size():
		var bunk := BunkBed.new()
		bunk.name = "PlayerBunk" if index == bunk_zs.size() - 1 else "Bunk%02d" % (index + 1)
		bunk.player_bunk = index == bunk_zs.size() - 1
		bunk.position = Vector3(BUNK_X, 0.02, bunk_zs[index])
		bunk.rotation.y = PI * 0.5
		bunk_room.add_child(bunk)
		if bunk.player_bunk:
			player_bunk = bunk
	_warm_light(bunk_room, Vector3(-17.2, 2.35, 1.8), 12.0)


func _build_elder_quarters() -> void:
	elder_quarters = _group(self, "ElderQuarters")
	var room_center := Vector3(-18.2, 0.0, -13.8)
	var room_size := Vector2(8.0, 7.7)
	_floor_slab(elder_quarters, "ElderDeck", room_size,
		room_center + Vector3(0.0, 0.013, 0.0), MAT_FLOOR, false)
	_solid_box(
		elder_quarters, "ElderRoof", Vector3(room_size.x + 0.3, ROOF_THICKNESS,
			room_size.y + 0.3),
		room_center + Vector3(0.0, ROOF_HEIGHT, 0.0), MAT_WOOD
	)
	_wall(elder_quarters, "ElderEastWall", room_size.y,
		Vector3(-14.2, 0.0, room_center.z), -PI * 0.5, 7321, ROOF_HEIGHT)
	# Two returns frame a broad south opening; the camera remains outside the room
	# while the elder and furniture remain unmistakably in separate quarters.
	_wall(elder_quarters, "ElderSouthWestJamb", 2.0,
		Vector3(-21.2, 0.0, -9.95), PI, 7322, ROOF_HEIGHT)
	_wall(elder_quarters, "ElderSouthEastJamb", 1.4,
		Vector3(-14.9, 0.0, -9.95), PI, 7323, ROOF_HEIGHT)
	_solid_box(
		elder_quarters, "ElderBedFrame", Vector3(1.2, 0.38, 2.25),
		Vector3(-19.4, 0.19, -14.8), MAT_WOOD
	)
	_visual_box(
		elder_quarters, "ElderMattress", Vector3(1.08, 0.16, 2.12),
		Vector3(-19.4, 0.46, -14.8), MAT_FLOOR
	)
	_solid_box(
		elder_quarters, "MapTable", Vector3(1.8, 0.86, 0.82),
		Vector3(-16.1, 0.43, -15.4), MAT_WOOD
	)
	_visual_box(
		elder_quarters, "MapWeight", Vector3(0.28, 0.18, 0.28),
		Vector3(-16.1, 0.95, -15.4), MAT_IRON
	)
	_warm_light(elder_quarters, Vector3(-18.0, 2.2, -13.4), 7.0)


func _build_service_arcade() -> void:
	var arcade := _group(self, "ServiceArcade")
	var width := ARCADE_BACK_X - ARCADE_FRONT_X
	var length := ARCADE_SOUTH_Z - ARCADE_NORTH_Z
	_floor_slab(
		arcade, "ArcadeDeck", Vector2(width, length),
		Vector3((ARCADE_FRONT_X + ARCADE_BACK_X) * 0.5, 0.014,
			(ARCADE_NORTH_Z + ARCADE_SOUTH_Z) * 0.5), MAT_FLOOR, false
	)
	_solid_box(
		arcade, "ArcadeRoof", Vector3(width + 0.3, ROOF_THICKNESS, length + 0.35),
		Vector3((ARCADE_FRONT_X + ARCADE_BACK_X) * 0.5, ROOF_HEIGHT,
			(ARCADE_NORTH_Z + ARCADE_SOUTH_Z) * 0.5), MAT_WOOD
	)
	# Dividers stop at x=17.2, leaving a continuous four-metre covered corridor
	# in front of all five service nooks.
	for z: float in [-11.5, -6.5, -1.5, 3.5, 8.5, 13.5]:
		_wall(arcade, "NookDivider", 5.0, Vector3(19.7, 0.0, z), 0.0,
			7400 + int((z + 11.5) / SERVICE_BAY), ROOF_HEIGHT)
	for index: int in 5:
		var z := -9.0 + float(index) * SERVICE_BAY
		_solid_box(
			arcade, "ServiceCounter", Vector3(0.72, 1.02, 3.35),
			Vector3(17.6, 0.51, z), MAT_WOOD
		)
		_build_service_marker(arcade, index, Vector3(20.7, 0.0, z))
	for z: float in [-11.2, -3.0, 5.2, 13.2]:
		_solid_box(
			arcade, "ArcadePost", Vector3(0.24, ROOF_HEIGHT, 0.24),
			Vector3(ARCADE_FRONT_X + 0.16, ROOF_HEIGHT * 0.5, z), MAT_WOOD
		)


func _build_service_marker(parent: Node3D, index: int, at: Vector3) -> void:
	match index:
		0:
			_solid_box(parent, "QuartermasterCrate", Vector3(1.2, 1.05, 1.2),
				at + Vector3(0.0, 0.525, 0.0), MAT_WOOD)
		1:
			_solid_box(parent, "SmithHearth", Vector3(1.5, 1.2, 1.25),
				at + Vector3(0.0, 0.6, 0.0), MAT_WALL)
			_visual_box(parent, "SmithAnvil", Vector3(0.75, 0.28, 0.38),
				at + Vector3(-0.55, 1.02, 0.0), MAT_IRON)
		2:
			_solid_box(parent, "AlchemistShelf", Vector3(0.48, 1.8, 2.4),
				at + Vector3(0.65, 0.9, 0.0), MAT_WOOD)
		3:
			_solid_box(parent, "ElderLectern", Vector3(0.9, 1.15, 0.72),
				at + Vector3(0.0, 0.575, 0.0), MAT_WOOD)
		4:
			_solid_box(parent, "JewelDisplay", Vector3(1.55, 0.92, 0.82),
				at + Vector3(0.0, 0.46, 0.0), MAT_IRON)


func _build_north_range() -> void:
	var north := _group(self, "NorthTrainingAndStores")
	var size := Vector2(27.0, 6.2)
	var centre := Vector3(-0.5, 0.0, -14.6)
	_floor_slab(north, "NorthDeck", size, centre + Vector3(0.0, 0.015, 0.0),
		MAT_FLOOR, false)
	_solid_box(
		north, "NorthRoof", Vector3(size.x + 0.4, ROOF_THICKNESS, size.y + 0.3),
		centre + Vector3(0.0, ROOF_HEIGHT, 0.0), MAT_WOOD
	)
	for x: float in [-13.7, -5.0, 4.0, 13.0]:
		_solid_box(
			north, "RangePost", Vector3(0.25, ROOF_HEIGHT, 0.25),
			Vector3(x, ROOF_HEIGHT * 0.5, -11.65), MAT_WOOD
		)
	# Medium store masses occupy the back line; the entire south edge remains a
	# clear lateral connection between west billets and east services.
	for x: float in [-10.8, -8.9, -7.0]:
		_solid_box(
			north, "StoreCrate", Vector3(1.35, 1.25, 1.35),
			Vector3(x, 0.625, -16.2), MAT_WOOD
		)
	for x: float in [5.6, 8.6, 11.6]:
		_solid_box(
			north, "TrainingPost", Vector3(0.34, 2.25, 0.34),
			Vector3(x, 1.125, -15.7), MAT_WOOD
		)
		_visual_box(
			north, "TrainingCrossbar", Vector3(1.35, 0.20, 0.24),
			Vector3(x, 1.72, -15.7), MAT_IRON
		)


func _build_cross_corridors() -> void:
	var corridors := _group(self, "CrossCorridors")
	# These two roof runs close the perimeter route south of the parade yard while
	# keeping the gatehouse axis and every square metre over the yard open to sky.
	for sx: float in [-1.0, 1.0]:
		var x := sx * 8.5
		_solid_box(
			corridors, "SouthGalleryRoof", Vector3(11.0, ROOF_THICKNESS, 3.4),
			Vector3(x, ROOF_HEIGHT, 11.8), MAT_WOOD
		)
		for post_x: float in [x - 5.2, x + 5.2]:
			_solid_box(
				corridors, "SouthGalleryPost", Vector3(0.24, ROOF_HEIGHT, 0.24),
				Vector3(post_x, ROOF_HEIGHT * 0.5, 10.2), MAT_WOOD
			)


func _floor_slab(
		parent: Node3D,
		node_name: String,
		size: Vector2,
		at: Vector3,
		material: Material,
		solid: bool
	) -> KitSlab:
	var slab := KIT_FLOOR.instantiate() as KitSlab
	slab.name = node_name
	slab.size = size
	slab.face_material = material
	slab.edge_material = MAT_WALL
	slab.solid = solid
	slab.position = at
	parent.add_child(slab)
	return slab


func _wall(
		parent: Node3D,
		node_name: String,
		length: float,
		at: Vector3,
		yaw: float,
		seed: int,
		height: float = WALL_HEIGHT
	) -> KitWall:
	var wall := KIT_WALL.instantiate() as KitWall
	wall.name = node_name
	wall.length = length
	wall.height = height
	wall.rng_seed = seed
	wall.material = MAT_WALL
	wall.position = at
	wall.rotation.y = yaw
	parent.add_child(wall)
	return wall


func _pillar(
		parent: Node3D, node_name: String, at: Vector3, height: float
	) -> KitPillar:
	var pillar := KIT_PILLAR.instantiate() as KitPillar
	pillar.name = node_name
	pillar.height = height
	pillar.material = MAT_WALL
	pillar.position = at
	parent.add_child(pillar)
	return pillar


func _solid_box(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		at: Vector3,
		material: Material,
		yaw: float = 0.0
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	body.position = at
	body.rotation.y = yaw

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)
	return body


func _visual_box(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		at: Vector3,
		material: Material,
		yaw: float = 0.0
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = at
	mesh_instance.rotation.y = yaw
	parent.add_child(mesh_instance)
	return mesh_instance


func _group(parent: Node3D, node_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	parent.add_child(group)
	return group


func _warm_light(parent: Node3D, at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = &"NightLantern"
	light.light_color = Color(1.0, 0.62, 0.30)
	light.light_energy = 3.6
	light.omni_range = reach
	light.position = at
	parent.add_child(light)


func _port_at(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _facing_port(at: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)


func _sleep_port(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(PI * 0.5, yaw, 0.0)), at)


func _camera_port(at: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)
