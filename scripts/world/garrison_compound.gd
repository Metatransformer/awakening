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
const CLEAR_CIRCULATION := 4.0
const PARADE_SIZE := Vector2(17.0, 15.0)
const PARADE_AT := Vector3(0.0, 0.0, -0.5)
const WEST_WALK_SIZE := Vector2(CLEAR_CIRCULATION, 25.0)
const WEST_WALK_AT := Vector3(-11.8, 0.0, 1.0)
const EAST_WALK_SIZE := Vector2(CLEAR_CIRCULATION, 27.0)
const EAST_WALK_AT := Vector3(11.0, 0.0, 0.5)
const NORTH_WALK_SIZE := Vector2(27.0, CLEAR_CIRCULATION)
const NORTH_WALK_AT := Vector3(-0.5, 0.0, -10.1)
const SOUTH_WALK_SIZE := Vector2(27.0, CLEAR_CIRCULATION)
const SOUTH_WALK_AT := Vector3(-0.5, 0.0, 9.3)

const BARRACKS_FRONT_X := -14.0
const BARRACKS_BACK_X := -22.1
const BARRACKS_NORTH_Z := -9.2
const BARRACKS_SOUTH_Z := 13.6
const BUNK_X := -19.3

const ELDER_QUARTERS_AT := Vector3(-18.2, 0.0, -13.8)
const ELDER_QUARTERS_SIZE := Vector2(8.0, 7.7)
const MESS_HALL_AT := Vector3(-9.0, 0.0, -14.4)
const MESS_HALL_SIZE := Vector2(9.0, 6.2)
const BUILDER_TRAINING_AT := Vector3(-0.4, 0.0, -14.2)
const BUILDER_TRAINING_SIZE := Vector2(6.8, 5.0)
const QUARTERMASTER_NOOK_AT := Vector3(17.3, 0.0, 9.5)
const QUARTERMASTER_NOOK_SIZE := Vector2(7.0, 5.8)
const JEWELCRAFTER_NOOK_AT := Vector3(17.4, 0.0, 1.5)
const JEWELCRAFTER_NOOK_SIZE := Vector2(6.4, 4.8)
const SMITH_NOOK_AT := Vector3(17.6, 0.0, -7.0)
const SMITH_NOOK_SIZE := Vector2(7.8, 7.8)
const ALCHEMIST_NOOK_AT := Vector3(7.5, 0.0, -13.3)
const ALCHEMIST_NOOK_SIZE := Vector2(7.0, 5.4)

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
	_build_service_nooks()
	_build_north_wing()
	_build_cross_corridors()


func port(id: StringName) -> Transform3D:
	if not _ports.has(id):
		push_error("GarrisonCompound: unknown port '%s'." % id)
		return Transform3D.IDENTITY
	return _ports[id]


func has_port(id: StringName) -> bool:
	return _ports.has(id)


## The compound owns these walks and footprints, so it also owns their map
## geometry. Every point is converted from the same constants used to build the
## fort; the HUD never carries a shadow copy of this layout.
func surface_map_plan() -> Dictionary:
	var paths: Array[Dictionary] = [
		_surface_path(_walk_line(WEST_WALK_AT, WEST_WALK_SIZE, false)),
		_surface_path(_walk_line(EAST_WALK_AT, EAST_WALK_SIZE, false)),
		_surface_path(_walk_line(NORTH_WALK_AT, NORTH_WALK_SIZE, true)),
		_surface_path(_walk_line(SOUTH_WALK_AT, SOUTH_WALK_SIZE, true)),
	]
	var barracks_size := Vector2(BARRACKS_FRONT_X - BARRACKS_BACK_X,
		BARRACKS_SOUTH_Z - BARRACKS_NORTH_Z)
	var barracks_at := Vector3((BARRACKS_FRONT_X + BARRACKS_BACK_X) * 0.5,
		0.0, (BARRACKS_NORTH_Z + BARRACKS_SOUTH_Z) * 0.5)
	var areas: Array[Dictionary] = [
		_surface_rect(Vector3.ZERO, COMPOUND_SIZE, &"ground"),
		_surface_rect(PARADE_AT, PARADE_SIZE, &"ground"),
		_surface_rect(barracks_at, barracks_size, &"footprint"),
		_surface_rect(ELDER_QUARTERS_AT, ELDER_QUARTERS_SIZE, &"footprint"),
		_surface_rect(MESS_HALL_AT, MESS_HALL_SIZE, &"footprint"),
		_surface_rect(BUILDER_TRAINING_AT, BUILDER_TRAINING_SIZE, &"footprint"),
		_surface_rect(QUARTERMASTER_NOOK_AT, QUARTERMASTER_NOOK_SIZE, &"footprint"),
		_surface_rect(JEWELCRAFTER_NOOK_AT, JEWELCRAFTER_NOOK_SIZE, &"footprint"),
		_surface_rect(SMITH_NOOK_AT, SMITH_NOOK_SIZE, &"footprint"),
		_surface_rect(ALCHEMIST_NOOK_AT, ALCHEMIST_NOOK_SIZE, &"footprint"),
	]
	var landmarks: Array[Dictionary] = []
	paths.make_read_only()
	areas.make_read_only()
	landmarks.make_read_only()
	var plan: Dictionary = {
		&"view_range": 52.0,
		&"paths": paths,
		&"areas": areas,
		&"landmarks": landmarks,
	}
	plan.make_read_only()
	return plan


func _define_ports() -> void:
	var hearth_at := Vector3(-1.0, 0.05, -1.0)
	_ports = {
		&"arrival": _port_at(Vector3(0.0, 0.05, 10.2), 0.0),
		&"gate": _port_at(Vector3(0.0, 0.05, 15.4), 0.0),
		&"quartermaster_day": _port_at(Vector3(15.3, 0.05, 9.5), -PI * 0.5),
		&"jewelcrafter_day": _port_at(Vector3(15.3, 0.05, 1.5), -PI * 0.5),
		&"smith_day": _port_at(Vector3(15.0, 0.05, -7.0), -PI * 0.5),
		&"alchemist_day": _port_at(Vector3(7.5, 0.05, -12.5), 0.0),
		&"elder_day": _port_at(Vector3(-0.9, 0.05, 8.0), 0.0),
		&"builder_day": _port_at(Vector3(-0.4, 0.05, -13.2), 0.0),
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
		&"quartermaster_sleep": _sleep_port(
			Vector3(BUNK_X, 0.58, -6.6), PI * 0.5, 1.72),
		&"smith_sleep": _sleep_port(Vector3(BUNK_X, 0.58, -2.3), PI * 0.5, 1.44),
		&"alchemist_sleep": _sleep_port(
			Vector3(BUNK_X, 0.58, 2.0), PI * 0.5, 1.82),
		&"jewelcrafter_sleep": _sleep_port(
			Vector3(BUNK_X, 0.58, 6.3), PI * 0.5, 1.63),
		&"player_bunk": _port_at(Vector3(-16.0, 0.05, 10.6), PI * 0.5),
		&"elder_sleep": _sleep_port(Vector3(-19.4, 0.58, -14.8), 0.0, 1.74),
		&"builder_sleep": _sleep_port(Vector3(-12.6, 0.58, -16.3), 0.0, 1.82),
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
		ground, "ParadePaving", PARADE_SIZE,
		PARADE_AT + Vector3.UP * 0.008, MAT_FLOOR, false
	)
	_floor_slab(
		ground, "WestWalk", WEST_WALK_SIZE,
		WEST_WALK_AT + Vector3.UP * 0.009, MAT_FLOOR, false
	)
	_floor_slab(
		ground, "EastWalk", EAST_WALK_SIZE,
		EAST_WALK_AT + Vector3.UP * 0.009, MAT_FLOOR, false
	)
	_floor_slab(
		ground, "NorthWalk", NORTH_WALK_SIZE,
		NORTH_WALK_AT + Vector3.UP * 0.010, MAT_FLOOR, false
	)
	_floor_slab(
		ground, "SouthWalk", SOUTH_WALK_SIZE,
		SOUTH_WALK_AT + Vector3.UP * 0.010, MAT_FLOOR, false
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

	# DEPART is a deliberate held transition, not an open-world seam. A collision
	# plane behind the prompt keeps a player who ignores it inside authored space;
	# the iron grille makes that boundary visible instead of feeling like an
	# invisible wall. It fills the opening up to the passage roof, so jumping does
	# not turn the road beyond the scene into an escape route.
	var backstop := StaticBody3D.new()
	backstop.name = &"ExitBackstop"
	backstop.collision_layer = K.L_WORLD
	backstop.collision_mask = 0
	backstop.position = Vector3(0.0, 2.45, 18.0)
	var collision := CollisionShape3D.new()
	collision.name = &"Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8, 4.9, 0.36)
	collision.shape = shape
	backstop.add_child(collision)
	gatehouse.add_child(backstop)
	for x: float in [-2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4]:
		_visual_box(gatehouse, "PortcullisBar", Vector3(0.16, 4.9, 0.18),
			Vector3(x, 2.45, 17.9), MAT_IRON)
	for y: float in [1.15, 2.55, 3.95]:
		_visual_box(gatehouse, "PortcullisBrace", Vector3(5.5, 0.16, 0.20),
			Vector3(0.0, y, 17.88), MAT_IRON)


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
	_wall(bunk_room, "BarracksWestWall", length,
		Vector3(BARRACKS_BACK_X, 0.0,
			(BARRACKS_NORTH_Z + BARRACKS_SOUTH_Z) * 0.5), PI * 0.5,
		7313, ROOF_HEIGHT)
	# The east wall stops around one 2.8 m opening aligned with the player bunk.
	_wall(bunk_room, "BarracksEastNorthReturn", 18.2,
		Vector3(BARRACKS_FRONT_X, 0.0, -0.1), -PI * 0.5, 7314, ROOF_HEIGHT)
	_wall(bunk_room, "BarracksEastSouthReturn", 1.8,
		Vector3(BARRACKS_FRONT_X, 0.0, 12.7), -PI * 0.5, 7315, ROOF_HEIGHT)
	_solid_box(
		bunk_room, "BarracksDoorLintel", Vector3(0.28, 0.65, 2.8),
		Vector3(BARRACKS_FRONT_X, 3.125, 10.4), MAT_WALL
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
	_warm_light(bunk_room, Vector3(-17.2, 2.35, 9.8), 8.0)


func _build_elder_quarters() -> void:
	elder_quarters = _group(self, "ElderQuarters")
	var room_center := ELDER_QUARTERS_AT
	var room_size := ELDER_QUARTERS_SIZE
	_floor_slab(elder_quarters, "ElderDeck", room_size,
		room_center + Vector3(0.0, 0.013, 0.0), MAT_FLOOR, false)
	_solid_box(
		elder_quarters, "ElderRoof", Vector3(room_size.x + 0.3, ROOF_THICKNESS,
			room_size.y + 0.3),
		room_center + Vector3(0.0, ROOF_HEIGHT, 0.0), MAT_WOOD
	)
	_wall(elder_quarters, "ElderEastWall", room_size.y,
		Vector3(-14.2, 0.0, room_center.z), -PI * 0.5, 7321, ROOF_HEIGHT)
	_wall(elder_quarters, "ElderWestWall", room_size.y,
		Vector3(-22.2, 0.0, room_center.z), PI * 0.5, 7322, ROOF_HEIGHT)
	_wall(elder_quarters, "ElderNorthWall", room_size.x,
		Vector3(room_center.x, 0.0, -17.65), 0.0, 7323, ROOF_HEIGHT)
	# Equal returns keep the 2.6 m south doorway centered on the room and map table.
	_wall(elder_quarters, "ElderSouthWestReturn", 2.7,
		Vector3(-20.85, 0.0, -9.95), PI, 7324, ROOF_HEIGHT)
	_wall(elder_quarters, "ElderSouthEastReturn", 2.7,
		Vector3(-15.55, 0.0, -9.95), PI, 7325, ROOF_HEIGHT)
	_solid_box(
		elder_quarters, "ElderDoorLintel", Vector3(2.6, 0.65, 0.28),
		Vector3(-18.2, 3.125, -9.95), MAT_WALL
	)
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


func _build_service_nooks() -> void:
	var services := _group(self, "ServiceNooks")

	var quartermaster := _group(services, "QuartermasterNook")
	_floor_slab(quartermaster, "QuartermasterDeck", QUARTERMASTER_NOOK_SIZE,
		QUARTERMASTER_NOOK_AT + Vector3.UP * 0.014, MAT_FLOOR, false)
	_solid_box(quartermaster, "QuartermasterRoof",
		Vector3(QUARTERMASTER_NOOK_SIZE.x + 0.3, ROOF_THICKNESS,
			QUARTERMASTER_NOOK_SIZE.y + 0.3),
		QUARTERMASTER_NOOK_AT + Vector3.UP * ROOF_HEIGHT, MAT_WOOD)
	_wall(quartermaster, "QuartermasterBackWall", QUARTERMASTER_NOOK_SIZE.y,
		Vector3(20.8, 0.0, QUARTERMASTER_NOOK_AT.z), -PI * 0.5, 7401, ROOF_HEIGHT)
	_wall(quartermaster, "QuartermasterNorthWall", QUARTERMASTER_NOOK_SIZE.x,
		Vector3(QUARTERMASTER_NOOK_AT.x, 0.0, 6.6), 0.0, 7402, ROOF_HEIGHT)
	_wall(quartermaster, "QuartermasterSouthWall", QUARTERMASTER_NOOK_SIZE.x,
		Vector3(QUARTERMASTER_NOOK_AT.x, 0.0, 12.4), PI, 7403, ROOF_HEIGHT)

	var jeweller := _group(services, "JewelcrafterNook")
	_floor_slab(jeweller, "JewelcrafterDeck", JEWELCRAFTER_NOOK_SIZE,
		JEWELCRAFTER_NOOK_AT + Vector3.UP * 0.014, MAT_FLOOR, false)
	_solid_box(jeweller, "JewelcrafterRoof",
		Vector3(JEWELCRAFTER_NOOK_SIZE.x + 0.3, ROOF_THICKNESS,
			JEWELCRAFTER_NOOK_SIZE.y + 0.3),
		JEWELCRAFTER_NOOK_AT + Vector3.UP * ROOF_HEIGHT, MAT_WOOD)
	_wall(jeweller, "JewelcrafterBackWall", JEWELCRAFTER_NOOK_SIZE.y,
		Vector3(20.6, 0.0, JEWELCRAFTER_NOOK_AT.z), -PI * 0.5, 7411, ROOF_HEIGHT)
	# Short returns and front posts make this a lighter display pavilion.
	_wall(jeweller, "JewelcrafterNorthReturn", 3.5,
		Vector3(18.85, 0.0, -0.9), 0.0, 7412, ROOF_HEIGHT)
	_wall(jeweller, "JewelcrafterSouthReturn", 3.5,
		Vector3(18.85, 0.0, 3.9), PI, 7413, ROOF_HEIGHT)
	for z: float in [-0.75, 3.75]:
		_solid_box(jeweller, "JewelcrafterFrontPost", Vector3(0.24, ROOF_HEIGHT, 0.24),
			Vector3(14.35, ROOF_HEIGHT * 0.5, z), MAT_WOOD)

	var smithy := _group(services, "SmithNook")
	_floor_slab(smithy, "SmithDeck", SMITH_NOOK_SIZE,
		SMITH_NOOK_AT + Vector3.UP * 0.014, MAT_FLOOR, false)
	_solid_box(smithy, "SmithRoof",
		Vector3(SMITH_NOOK_SIZE.x + 0.3, ROOF_THICKNESS,
			SMITH_NOOK_SIZE.y + 0.3),
		SMITH_NOOK_AT + Vector3.UP * ROOF_HEIGHT, MAT_WOOD)
	_wall(smithy, "SmithBackWall", SMITH_NOOK_SIZE.y,
		Vector3(21.5, 0.0, SMITH_NOOK_AT.z), -PI * 0.5, 7421, ROOF_HEIGHT)
	_wall(smithy, "SmithNorthWall", SMITH_NOOK_SIZE.x,
		Vector3(SMITH_NOOK_AT.x, 0.0, -10.9), 0.0, 7422, ROOF_HEIGHT)
	_wall(smithy, "SmithSouthWall", SMITH_NOOK_SIZE.x,
		Vector3(SMITH_NOOK_AT.x, 0.0, -3.1), PI, 7423, ROOF_HEIGHT)

	var apothecary := _group(services, "AlchemistNook")
	_floor_slab(apothecary, "AlchemistDeck", ALCHEMIST_NOOK_SIZE,
		ALCHEMIST_NOOK_AT + Vector3.UP * 0.014, MAT_FLOOR, false)
	_solid_box(apothecary, "AlchemistRoof",
		Vector3(ALCHEMIST_NOOK_SIZE.x + 0.3, ROOF_THICKNESS,
			ALCHEMIST_NOOK_SIZE.y + 0.3),
		ALCHEMIST_NOOK_AT + Vector3.UP * ROOF_HEIGHT, MAT_WOOD)
	_wall(apothecary, "AlchemistBackWall", ALCHEMIST_NOOK_SIZE.x,
		Vector3(ALCHEMIST_NOOK_AT.x, 0.0, -16.0), 0.0, 7431, ROOF_HEIGHT)
	_wall(apothecary, "AlchemistWestWall", ALCHEMIST_NOOK_SIZE.y,
		Vector3(4.0, 0.0, ALCHEMIST_NOOK_AT.z), PI * 0.5, 7432, ROOF_HEIGHT)
	_wall(apothecary, "AlchemistEastWall", ALCHEMIST_NOOK_SIZE.y,
		Vector3(11.0, 0.0, ALCHEMIST_NOOK_AT.z), -PI * 0.5, 7433, ROOF_HEIGHT)


func _build_north_wing() -> void:
	var north := _group(self, "NorthCommunalAndWork")
	var mess := _group(north, "MessHall")
	_floor_slab(mess, "MessHallDeck", MESS_HALL_SIZE,
		MESS_HALL_AT + Vector3.UP * 0.015, MAT_FLOOR, false)
	_solid_box(mess, "MessHallRoof",
		Vector3(MESS_HALL_SIZE.x + 0.3, ROOF_THICKNESS, MESS_HALL_SIZE.y + 0.3),
		MESS_HALL_AT + Vector3.UP * ROOF_HEIGHT, MAT_WOOD)
	_wall(mess, "MessHallWestWall", MESS_HALL_SIZE.y,
		Vector3(-13.5, 0.0, MESS_HALL_AT.z), PI * 0.5, 7501, ROOF_HEIGHT)
	_wall(mess, "MessHallEastWall", MESS_HALL_SIZE.y,
		Vector3(-4.5, 0.0, MESS_HALL_AT.z), -PI * 0.5, 7502, ROOF_HEIGHT)
	_wall(mess, "MessHallNorthWall", MESS_HALL_SIZE.x,
		Vector3(MESS_HALL_AT.x, 0.0, -17.5), 0.0, 7503, ROOF_HEIGHT)
	_wall(mess, "MessHallSouthWestReturn", 2.5,
		Vector3(-12.25, 0.0, -11.3), PI, 7504, ROOF_HEIGHT)
	_wall(mess, "MessHallSouthEastReturn", 2.5,
		Vector3(-5.75, 0.0, -11.3), PI, 7505, ROOF_HEIGHT)
	_solid_box(mess, "MessHallDoorLintel", Vector3(4.0, 0.65, 0.28),
		Vector3(-9.0, 3.125, -11.3), MAT_WALL)
	_solid_box(mess, "MessTable", Vector3(4.8, 0.82, 1.1),
		Vector3(-9.0, 0.41, -14.4), MAT_WOOD)
	for z: float in [-13.3, -15.5]:
		_solid_box(mess, "MessBench", Vector3(4.6, 0.46, 0.42),
			Vector3(-9.0, 0.23, z), MAT_WOOD)
	_solid_box(mess, "ServingSideboard", Vector3(2.8, 1.0, 0.55),
		Vector3(-9.0, 0.5, -16.9), MAT_WOOD)
	_warm_light(mess, Vector3(-9.0, 2.3, -14.2), 8.0)

	var training := _group(north, "BuilderTrainingPocket")
	_floor_slab(training, "TrainingDeck", BUILDER_TRAINING_SIZE,
		BUILDER_TRAINING_AT + Vector3.UP * 0.015, MAT_FLOOR, false)
	for x: float in [-2.7, -0.4, 1.9]:
		_solid_box(training, "TrainingPost", Vector3(0.34, 2.25, 0.34),
			Vector3(x, 1.125, -16.0), MAT_WOOD)
		_visual_box(training, "TrainingCrossbar", Vector3(1.35, 0.20, 0.24),
			Vector3(x, 1.72, -16.0), MAT_IRON)


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


func _sleep_port(bed_center: Vector3, yaw: float, sleeper_height: float) -> Transform3D:
	# Keep yaw as the authored facing basis, then tip only the person art in its
	# local space: +Z is the model's face and +Y runs from feet to head.
	var facing_basis := Basis(Vector3.UP, yaw)
	var face_up_art_basis := Basis(Vector3.RIGHT, -PI * 0.5)
	var sleep_basis := facing_basis * face_up_art_basis
	var head_direction: Vector3 = sleep_basis.y.normalized()
	var feet_at: Vector3 = bed_center - head_direction * sleeper_height * 0.5
	return Transform3D(sleep_basis, feet_at)


func _camera_port(at: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)


func _walk_line(at: Vector3, walk_size: Vector2,
		horizontal: bool) -> Array[Vector3]:
	var half := (walk_size.x if horizontal else walk_size.y) * 0.5
	var axis := Vector3.RIGHT if horizontal else Vector3.FORWARD
	return [at - axis * half, at + axis * half]


func _surface_path(local_points: Array[Vector3]) -> Dictionary:
	var world_points := PackedVector3Array()
	for point: Vector3 in local_points:
		world_points.append(to_global(point))
	var path: Dictionary = {&"kind": &"path", &"points": world_points}
	path.make_read_only()
	return path


func _surface_rect(at: Vector3, rect_size: Vector2,
		kind: StringName) -> Dictionary:
	var half := rect_size * 0.5
	var points := PackedVector3Array([
		to_global(at + Vector3(-half.x, 0.0, -half.y)),
		to_global(at + Vector3(half.x, 0.0, -half.y)),
		to_global(at + Vector3(half.x, 0.0, half.y)),
		to_global(at + Vector3(-half.x, 0.0, half.y)),
	])
	var area: Dictionary = {&"kind": kind, &"points": points}
	area.make_read_only()
	return area
