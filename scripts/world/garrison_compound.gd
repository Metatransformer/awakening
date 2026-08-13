class_name GarrisonCompound
extends Node3D
## Deterministic inner-fort geometry for the garrison hub. This node owns only
## structure and local-space ports; the surrounding Garrison owns cast and sky.

const KIT_FLOOR: PackedScene = preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL: PackedScene = preload("res://scenes/kit/wall_segment.tscn")

const MAT_WALL := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_FLOOR := preload("res://assets/materials/mat_floor.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")
const MAT_PROP := preload("res://assets/materials/mat_prop.tres")
const MAT_EMBER := preload("res://assets/materials/mat_ember.tres")
const MAT_ROOF_TILES := preload("res://assets/materials/mat_garrison_roof_tiles.tres")
const MAT_CEILING := preload("res://assets/materials/mat_garrison_ceiling.tres")

const COMPOUND_SIZE := Vector2(54.0, 44.0)
const WALL_HEIGHT := 6.6
const ROOF_HEIGHT := 3.45
const ROOF_THICKNESS := 0.24
const DOOR_CLEARANCE := 2.55
const PARADE_SIZE := Vector2(16.0, 15.0)
const PARADE_AT := Vector3(1.0, 0.0, 0.0)
const GATE_WALK_SIZE := Vector2(5.0, 27.0)
const GATE_WALK_AT := Vector3(0.0, 0.0, 4.0)

const BARRACKS_AT := Vector3(-18.55, 0.0, -13.2)
const BARRACKS_SIZE := Vector2(9.7, 12.2)
const BUNK_X := -19.3
const BUNK_ZS: Array[float] = [-16.75, -14.60, -12.45, -10.30, -8.15]

const MESS_HALL_AT := Vector3(-6.9, 0.0, -15.95)
const MESS_HALL_SIZE := Vector2(9.0, 9.7)
const LEADER_QUARTERS_AT := Vector3(13.2, 0.0, -14.6)
const LEADER_QUARTERS_SIZE := Vector2(9.2, 10.0)
const SMITHY_AT := Vector3(-19.325, 0.0, -4.6)
const SMITHY_SIZE := Vector2(9.75, 6.5)
const JEWELCRAFTER_AT := Vector3(-19.725, 0.0, 3.2)
const JEWELCRAFTER_SIZE := Vector2(10.55, 6.3)
const BUILDER_WORKSHOP_AT := Vector3(-18.4, 0.0, 11.325)
const BUILDER_WORKSHOP_SIZE := Vector2(10.8, 6.95)
const QUARTERMASTER_AT := Vector3(18.8, 0.0, 4.3)
const QUARTERMASTER_SIZE := Vector2(11.8, 9.0)
const WEST_SUPPLY_AT := Vector3(-9.2, 0.0, 16.0)
const WEST_SUPPLY_SIZE := Vector2(7.6, 8.2)
const EAST_SUPPLY_AT := Vector3(9.2, 0.0, 15.65)
const EAST_SUPPLY_SIZE := Vector2(7.6, 7.5)
const GARDEN_AT := Vector3(-7.7, 0.0, 0.0)
const GARDEN_SIZE := Vector2(7.5, 8.5)

var player_bunk: BunkBed
var barracks_storage_chest: Footlocker
var bunk_room: Node3D
var elder_quarters: Node3D
var open_surface_gate: bool = false

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
	_build_buildings()
	_build_garden()
	GarrisonArtPass.build(self)


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
		_surface_path([Vector3(0.0, 0.0, 15.4), Vector3(0.0, 0.0, -9.8)]),
		_surface_path([Vector3(-13.7, 0.0, -10.0), Vector3(0.0, 0.0, -9.8),
			Vector3(12.7, 0.0, -9.6)]),
		_surface_path([Vector3(-14.45, 0.0, -4.6), Vector3(-12.0, 0.0, -4.6),
			Vector3(-12.0, 0.0, 11.1), Vector3(-13.0, 0.0, 11.1)]),
		_surface_path([Vector3(0.0, 0.0, 8.8), Vector3(12.9, 0.0, 8.8),
			Vector3(12.9, 0.0, 4.3)]),
	]
	var areas: Array[Dictionary] = [
		_surface_rect(Vector3.ZERO, COMPOUND_SIZE, &"ground"),
		_surface_rect(PARADE_AT, PARADE_SIZE, &"ground"),
		_surface_rect(BARRACKS_AT, BARRACKS_SIZE, &"footprint"),
		_surface_rect(MESS_HALL_AT, MESS_HALL_SIZE, &"footprint"),
		_surface_rect(LEADER_QUARTERS_AT, LEADER_QUARTERS_SIZE, &"footprint"),
		_surface_rect(SMITHY_AT, SMITHY_SIZE, &"footprint"),
		_surface_rect(JEWELCRAFTER_AT, JEWELCRAFTER_SIZE, &"footprint"),
		_surface_rect(BUILDER_WORKSHOP_AT, BUILDER_WORKSHOP_SIZE, &"footprint"),
		_surface_rect(QUARTERMASTER_AT, QUARTERMASTER_SIZE, &"footprint"),
		_surface_rect(WEST_SUPPLY_AT, WEST_SUPPLY_SIZE, &"footprint"),
		_surface_rect(EAST_SUPPLY_AT, EAST_SUPPLY_SIZE, &"footprint"),
		_surface_rect(GARDEN_AT, GARDEN_SIZE, &"garden"),
	]
	var landmarks: Array[Dictionary] = []
	paths.make_read_only()
	areas.make_read_only()
	landmarks.make_read_only()
	var plan: Dictionary = {
		&"view_range": 60.0,
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
		&"quartermaster_day": _port_at(Vector3(15.0, 0.05, 3.35), -PI * 0.5),
		&"jewelcrafter_day": _port_at(Vector3(-16.0, 0.05, 1.85), PI * 0.5),
		&"smith_day": _port_at(Vector3(-16.0, 0.05, -5.75), PI * 0.5),
		&"alchemist_day": _port_at(Vector3(-7.2, 0.05, -2.0), 0.0),
		&"elder_day": _port_at(Vector3(-0.9, 0.05, 8.0), 0.0),
		&"builder_day": _port_at(Vector3(-15.6, 0.05, 11.1), PI * 0.5),
		&"barracks_storage": _port_at(Vector3(-15.1, 0.05, -8.25), PI),
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
			Vector3(BUNK_X, 0.58, BUNK_ZS[0]), PI * 0.5, 1.72),
		&"smith_sleep": _sleep_port(Vector3(BUNK_X, 0.58, BUNK_ZS[1]),
			PI * 0.5, 1.44),
		&"alchemist_sleep": _sleep_port(
			Vector3(BUNK_X, 0.58, BUNK_ZS[2]), PI * 0.5, 1.82),
		&"jewelcrafter_sleep": _sleep_port(
			Vector3(BUNK_X, 0.58, BUNK_ZS[3]), PI * 0.5, 1.63),
		&"player_bunk": _port_at(Vector3(-17.25, 0.05, BUNK_ZS[4]), PI * 0.5),
		&"elder_sleep": _sleep_port(Vector3(11.3, 0.58, -14.8), 0.0, 1.74),
		&"builder_sleep": _sleep_port(Vector3(-16.0, 0.58, -16.2),
			-PI * 0.5, 1.82),
		&"elder_room_camera": _camera_port(
			Vector3(12.7, 2.15, -9.9), Vector3(12.2, 1.0, -14.3)
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
		ground, "GateWalk", GATE_WALK_SIZE,
		GATE_WALK_AT + Vector3.UP * 0.009, MAT_FLOOR, false
	)


func _build_curtain() -> void:
	var curtain := _group(self, "CurtainWall")
	var connectors := _group(curtain, "PerimeterConnectors")
	var towers := _group(curtain, "JunctionTowers")
	# Occupied rooms own almost the entire defensive edge. These short runs close
	# only the air gaps between their exterior envelopes.
	_wall_between(connectors, "BarracksMessConnector",
		Vector3(-13.7, 0.0, -19.3), Vector3(-11.4, 0.0, -20.8), 7201)
	_wall_between(connectors, "MessLeaderConnector",
		Vector3(-2.4, 0.0, -20.8), Vector3(8.6, 0.0, -19.6), 7202)
	_round_tower(towers, "NorthJunctionBastion", Vector3(3.1, 0.0, -19.4),
		2.2, 7.8, 1.9, true)

	# The eastern edge deliberately walks outward in two steps between the leader
	# and depot instead of recreating a rectangular enclosing wall.
	_wall_between(connectors, "LeaderEastStep",
		Vector3(17.8, 0.0, -9.6), Vector3(21.6, 0.0, -9.6), 7203)
	_wall_between(connectors, "LeaderSouthStep",
		Vector3(21.6, 0.0, -9.6), Vector3(21.6, 0.0, -5.0), 7204)
	_wall_between(connectors, "LeaderOuterStep",
		Vector3(21.6, 0.0, -5.0), Vector3(24.0, 0.0, -5.0), 7205)
	_wall_between(connectors, "QuartermasterNorthReturn",
		Vector3(24.0, 0.0, -5.0), Vector3(24.0, 0.0, -0.2), 7206)
	_round_tower(towers, "LeaderDoglegBastion", Vector3(21.6, 0.0, -9.6),
		2.35, 8.0, 2.0, true)
	_round_tower(towers, "EastStepBastion", Vector3(24.0, 0.0, -5.0),
		2.2, 7.7, 1.9, true)

	_wall_between(connectors, "QuartermasterSupplyConnector",
		Vector3(24.7, 0.0, 8.8), Vector3(13.0, 0.0, 11.9), 7207)
	_round_tower(towers, "QuartermasterTurnBastion", Vector3(24.1, 0.0, 8.4),
		2.4, 7.9, 2.05, true)

	_wall_between(connectors, "BuilderJewellerConnector",
		Vector3(-23.8, 0.0, 7.85), Vector3(-25.0, 0.0, 6.35), 7208)
	_wall_between(connectors, "JewellerSmithConnector",
		Vector3(-25.0, 0.0, 0.05), Vector3(-24.2, 0.0, -1.35), 7209)
	_wall_between(connectors, "SmithBarracksConnector",
		Vector3(-24.2, 0.0, -7.85), Vector3(-23.4, 0.0, -7.1), 7210)
	_round_tower(towers, "WestCraftBastion", Vector3(-24.4, 0.0, 7.1),
		2.1, 7.5, 1.8, true)
	_round_tower(towers, "WestMidBastion", Vector3(-24.6, 0.0, -0.65),
		2.0, 7.4, 1.7, true)


func _build_gatehouse() -> void:
	var gatehouse := _group(self, "SouthGatehouse")
	for sx: float in [-1.0, 1.0]:
		_round_tower(gatehouse, "GateTowerWest" if sx < 0.0 else "GateTowerEast",
			Vector3(sx * 4.9, 0.0, 16.25), 2.4, 7.15, 1.9, false)
	_solid_box(
		gatehouse,
		"PassageRoof",
		Vector3(6.0, 0.48, 7.2),
		Vector3(0.0, 5.25, 15.4),
		MAT_WALL
	)
	# Open timber leaves make the gate legible without ever closing the six-metre
	# camera-safe passage. There is no closed portcullis visual: the departure
	# boundary is a gameplay seam, while raid attackers must visibly use this arch.
	for sx: float in [-1.0, 1.0]:
		_visual_box(
			gatehouse,
			"OpenGateLeaf",
			Vector3(0.18, 3.5, 2.4),
			Vector3(sx * 2.72, 1.75, 16.8),
			MAT_WOOD,
			sx * deg_to_rad(22.0)
		)

	if not open_surface_gate:
		# The standalone compound retains its deliberate held-transition boundary.
		# A composition root opens this passage only when it supplies real terrain.
		var backstop := StaticBody3D.new()
		backstop.name = &"ExitBackstop"
		backstop.collision_layer = K.L_PLAYER_BOUNDARY
		backstop.collision_mask = 0
		backstop.position = Vector3(0.0, 2.45, 18.0)
		var collision := CollisionShape3D.new()
		collision.name = &"Collision"
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.8, 4.9, 0.36)
		collision.shape = shape
		backstop.add_child(collision)
		gatehouse.add_child(backstop)
	_visual_box(gatehouse, "RaisedPortcullis", Vector3(5.5, 0.08, 0.10),
		Vector3(0.0, 5.32, 17.88), MAT_IRON)


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


func _build_buildings() -> void:
	var buildings := _group(self, "Buildings")
	_build_barracks(buildings)
	_build_mess_hall(buildings)
	_build_leader_quarters(buildings)
	_build_smithy(buildings)
	_build_jewelcrafter(buildings)
	_build_builder_workshop(buildings)
	_build_quartermaster(buildings)
	_build_supply_rooms(buildings)


func _build_barracks(buildings: Node3D) -> void:
	bunk_room = _group(buildings, "Barracks")
	_room_shell(bunk_room, "Barracks", BARRACKS_AT, BARRACKS_SIZE,
		&"east", 3.0, 7310, ROOF_HEIGHT, 2.8)
	_gabled_roof(bunk_room, "Barracks", BARRACKS_AT, BARRACKS_SIZE,
		ROOF_HEIGHT + 0.16, deg_to_rad(20.0))
	_exterior_parapet(bunk_room, &"BarracksNorthParapet",
		Vector3(-23.4, 0.0, -19.3), Vector3(-13.7, 0.0, -19.3))
	_exterior_parapet(bunk_room, &"BarracksWestParapet",
		Vector3(-23.4, 0.0, -19.3), Vector3(-23.4, 0.0, -7.1))
	for index: int in BUNK_ZS.size():
		var bunk := BunkBed.new()
		bunk.name = "PlayerBunk" if index == BUNK_ZS.size() - 1 \
			else "Bunk%02d" % (index + 1)
		bunk.player_bunk = index == BUNK_ZS.size() - 1
		bunk.position = Vector3(BUNK_X, 0.02, BUNK_ZS[index])
		bunk.rotation.y = PI * 0.5
		bunk_room.add_child(bunk)
		if bunk.player_bunk:
			player_bunk = bunk
	barracks_storage_chest = Footlocker.new()
	barracks_storage_chest.name = &"BarracksStorageChest"
	barracks_storage_chest.position = Vector3(-15.1, 0.02, -8.25)
	barracks_storage_chest.rotation.y = PI
	bunk_room.add_child(barracks_storage_chest)
	_solid_box(bunk_room, "WeaponLocker", Vector3(0.70, 1.85, 1.55),
		Vector3(-14.35, 0.925, -15.75), MAT_WOOD)
	_visual_box(bunk_room, "WeaponRack", Vector3(0.18, 1.35, 1.75),
		Vector3(-14.0, 1.35, -13.8), MAT_IRON)
	_solid_box(bunk_room, "BuilderBunk", Vector3(2.2, 0.42, 1.15),
		Vector3(-16.0, 0.23, -16.2), MAT_WOOD)
	_visual_box(bunk_room, "BuilderBlanket", Vector3(2.0, 0.14, 1.02),
		Vector3(-16.0, 0.51, -16.2), MAT_FLOOR)
	_visual_box(bunk_room, "BarracksRunner", Vector3(0.9, 0.035, 7.4),
		Vector3(-16.6, 0.055, -12.0), MAT_PROP)
	_interior_light(bunk_room, "InteriorLightNorth",
		Vector3(-17.2, 2.35, -14.9), 7.0)
	_interior_light(bunk_room, "InteriorLightSouth",
		Vector3(-17.2, 2.35, -9.0), 6.5)


func _build_mess_hall(buildings: Node3D) -> void:
	var mess := _group(buildings, "MessHall")
	_room_shell(mess, "MessHall", MESS_HALL_AT, MESS_HALL_SIZE,
		&"south", 0.0, 7340, ROOF_HEIGHT, 3.0)
	_gabled_roof(mess, "MessHall", MESS_HALL_AT, MESS_HALL_SIZE,
		ROOF_HEIGHT + 0.16, deg_to_rad(17.0), false)
	_exterior_parapet(mess, &"MessNorthParapet",
		Vector3(-11.4, 0.0, -20.8), Vector3(-2.4, 0.0, -20.8))
	_door_canopy(mess, "MessHall", Vector3(-6.9, 2.85, -10.85),
		Vector3(3.8, 0.16, 1.5), 0.0)
	_solid_box(mess, "MessTable", Vector3(5.2, 0.82, 1.05),
		Vector3(-6.9, 0.41, -14.4), MAT_WOOD)
	_solid_box(mess, "MessBenchNorth", Vector3(5.0, 0.46, 0.40),
		Vector3(-6.9, 0.23, -15.35), MAT_WOOD)
	_solid_box(mess, "MessBenchSouth", Vector3(2.8, 0.46, 0.40),
		Vector3(-8.0, 0.23, -13.45), MAT_WOOD)
	_solid_box(mess, "ServingSideboard", Vector3(2.8, 1.0, 0.55),
		Vector3(-9.2, 0.5, -17.05), MAT_WOOD)
	_solid_box(mess, "PantryBarrels", Vector3(1.15, 1.15, 1.15),
		Vector3(-3.25, 0.575, -16.75), MAT_WOOD)
	for x: float in [-8.6, -6.9, -5.2]:
		_visual_box(mess, "TableSetting", Vector3(0.42, 0.06, 0.42),
			Vector3(x, 0.86, -14.4), MAT_PROP)
	_visual_box(mess, "HearthGlow", Vector3(1.1, 0.12, 0.45),
		Vector3(-10.75, 0.15, -15.8), MAT_EMBER)
	_interior_light(mess, "InteriorLight", Vector3(-6.9, 2.3, -14.2), 7.0)


func _build_leader_quarters(buildings: Node3D) -> void:
	elder_quarters = _group(buildings, "LeaderQuarters")
	_room_shell(elder_quarters, "Leader", LEADER_QUARTERS_AT,
		LEADER_QUARTERS_SIZE, &"south", -0.5, 7370, ROOF_HEIGHT, 2.8)
	_gabled_roof(elder_quarters, "Leader", LEADER_QUARTERS_AT,
		LEADER_QUARTERS_SIZE, ROOF_HEIGHT + 0.16, deg_to_rad(24.0))
	_exterior_parapet(elder_quarters, &"LeaderNorthParapet",
		Vector3(8.6, 0.0, -19.6), Vector3(17.8, 0.0, -19.6))
	_exterior_parapet(elder_quarters, &"LeaderEastParapet",
		Vector3(17.8, 0.0, -19.6), Vector3(17.8, 0.0, -9.6))
	_door_canopy(elder_quarters, "Leader", Vector3(12.7, 2.85, -9.45),
		Vector3(3.5, 0.16, 1.55), 0.0)
	_solid_box(elder_quarters, "LeaderBedFrame", Vector3(1.2, 0.38, 2.25),
		Vector3(11.3, 0.19, -14.8), MAT_WOOD)
	_visual_box(elder_quarters, "LeaderMattress", Vector3(1.08, 0.16, 2.12),
		Vector3(11.3, 0.46, -14.8), MAT_FLOOR)
	_solid_box(elder_quarters, "MapDesk", Vector3(2.0, 0.86, 0.82),
		Vector3(14.3, 0.43, -15.2), MAT_WOOD)
	_visual_box(elder_quarters, "MapWeight", Vector3(0.28, 0.18, 0.28),
		Vector3(14.3, 0.95, -15.2), MAT_IRON)
	_solid_box(elder_quarters, "Bookcase", Vector3(0.55, 2.0, 2.25),
		Vector3(16.35, 1.0, -12.8), MAT_WOOD)
	_floor_slab(elder_quarters, "LeaderRug", Vector2(3.0, 2.2),
		Vector3(13.1, 0.035, -12.5), MAT_PROP, false)
	_visual_box(elder_quarters, "WallMap", Vector3(2.4, 1.45, 0.05),
		Vector3(12.9, 1.65, -17.56), MAT_PROP)
	_solid_box(elder_quarters, "LeaderChest", Vector3(1.45, 0.72, 0.72),
		Vector3(14.8, 0.36, -10.15), MAT_WOOD)
	_interior_light(elder_quarters, "InteriorLight",
		Vector3(12.8, 2.25, -13.6), 7.0)


func _build_smithy(buildings: Node3D) -> void:
	var smithy := _group(buildings, "Smithy")
	_room_shell(smithy, "Smith", SMITHY_AT, SMITHY_SIZE,
		&"east", 0.0, 7400, ROOF_HEIGHT, 3.0)
	_gabled_roof(smithy, "Smith", SMITHY_AT, SMITHY_SIZE,
		ROOF_HEIGHT + 0.16, deg_to_rad(19.0))
	_exterior_parapet(smithy, &"SmithWestParapet",
		Vector3(-24.2, 0.0, -7.85), Vector3(-24.2, 0.0, -1.35))
	_door_canopy(smithy, "Smith", Vector3(-14.3, 2.82, -4.6),
		Vector3(1.5, 0.16, 3.7), PI * 0.5)
	_solid_box(smithy, "SmithChimney", Vector3(1.15, 6.0, 1.15),
		Vector3(-20.7, 3.0, -6.6), MAT_WALL)
	_visual_box(smithy, "SmithChimneyCap", Vector3(1.45, 0.30, 1.45),
		Vector3(-20.7, 6.05, -6.6), MAT_IRON)
	_solid_box(smithy, "CoalBin", Vector3(1.25, 0.72, 1.35),
		Vector3(-20.55, 0.36, -2.25), MAT_WOOD)
	_solid_box(smithy, "ForgeBasin", Vector3(1.9, 0.82, 1.55),
		Vector3(-19.2, 0.41, -6.5), MAT_PROP)
	_visual_box(smithy, "ForgeCoals", Vector3(1.45, 0.12, 1.05),
		Vector3(-19.2, 0.88, -6.5), MAT_EMBER)
	_visual_box(smithy, "ToolRack", Vector3(0.12, 1.35, 2.2),
		Vector3(-21.91, 1.35, -4.15), MAT_IRON)
	_interior_light(smithy, "InteriorLight",
		Vector3(-18.9, 1.45, -5.9), 4.6, Color(1.0, 0.62, 0.34), 3.4)


func _build_jewelcrafter(buildings: Node3D) -> void:
	var jeweller := _group(buildings, "Jewelcrafter")
	const JEWEL_ROOF := 3.18
	_room_shell(jeweller, "Jewel", JEWELCRAFTER_AT, JEWELCRAFTER_SIZE,
		&"east", -0.45, 7430, JEWEL_ROOF, 2.7)
	_exterior_parapet(jeweller, &"JewelWestParapet",
		Vector3(-25.0, 0.0, 0.05), Vector3(-25.0, 0.0, 6.35))
	_solid_box(jeweller, "JewelDisplayPlinth", Vector3(1.1, 0.82, 1.1),
		Vector3(-20.35, 0.41, 1.0), MAT_WALL)
	_solid_box(jeweller, "JewelDisplayPlinthTall", Vector3(0.85, 1.10, 0.85),
		Vector3(-20.6, 0.55, 5.2), MAT_WALL)
	_solid_box(jeweller, "JewelStorageShelf", Vector3(0.50, 1.85, 2.3),
		Vector3(-21.55, 0.925, 3.1), MAT_WOOD)
	_visual_box(jeweller, "DisplayCloth", Vector3(1.0, 0.06, 1.0),
		Vector3(-20.35, 0.85, 1.0), MAT_PROP)
	# An off-centre grille makes the small display frontage read differently
	# from every other courtyard door without turning it into an open shed.
	for z: float in [4.65, 5.25, 5.85]:
		_visual_box(jeweller, "JewelDisplayPost", Vector3(0.18, 2.15, 0.18),
			Vector3(-14.38, 1.15, z), MAT_IRON)
	_interior_light(jeweller, "InteriorLight", Vector3(-18.3, 2.15, 3.2),
		6.2, Color(1.0, 0.62, 0.42), 3.8)
	_interior_light(jeweller, "DisplayLight", Vector3(-20.2, 1.55, 4.6),
		3.5, Color(0.82, 0.55, 0.90), 1.5)


func _build_builder_workshop(buildings: Node3D) -> void:
	var workshop := _group(buildings, "BuilderWorkshop")
	_room_shell(workshop, "Builder", BUILDER_WORKSHOP_AT,
		BUILDER_WORKSHOP_SIZE, &"east", -0.225, 7460, ROOF_HEIGHT, 2.8)
	_gabled_roof(workshop, "Builder", BUILDER_WORKSHOP_AT,
		BUILDER_WORKSHOP_SIZE, ROOF_HEIGHT + 0.16, deg_to_rad(16.0))
	_exterior_parapet(workshop, &"BuilderWestParapet",
		Vector3(-23.8, 0.0, 7.85), Vector3(-23.8, 0.0, 14.8))
	_exterior_parapet(workshop, &"BuilderSouthParapet",
		Vector3(-23.8, 0.0, 14.8), Vector3(-13.0, 0.0, 14.8))
	_solid_box(workshop, "BuilderWorktable", Vector3(3.2, 0.88, 1.15),
		Vector3(-17.8, 0.44, 10.4), MAT_WOOD)
	_solid_box(workshop, "TimberStack", Vector3(3.3, 0.65, 0.85),
		Vector3(-17.4, 0.325, 13.65), MAT_WOOD)
	for x: float in [-20.7, -18.8]:
		_solid_box(workshop, "WorkPost", Vector3(0.32, 2.2, 0.32),
			Vector3(x, 1.1, 9.0), MAT_WOOD)
		_visual_box(workshop, "WorkCrossbar", Vector3(1.25, 0.18, 0.22),
			Vector3(x, 1.7, 9.0), MAT_IRON)
	for offset: float in [-0.9, 0.0, 0.9]:
		_visual_box(workshop, "TimberBeam", Vector3(3.6, 0.20, 0.20),
			Vector3(-19.2, 0.78 + offset * 0.16, 12.8 + offset), MAT_WOOD,
			deg_to_rad(8.0))
	_interior_light(workshop, "InteriorLight",
		Vector3(-17.1, 2.3, 11.0), 7.0)


func _build_quartermaster(buildings: Node3D) -> void:
	var depot := _group(buildings, "Quartermaster")
	_room_shell(depot, "Quartermaster", QUARTERMASTER_AT, QUARTERMASTER_SIZE,
		&"west", 0.0, 7490, 3.25, 3.1)
	_exterior_parapet(depot, &"QuartermasterEastParapet",
		Vector3(24.7, 0.0, -0.2), Vector3(24.7, 0.0, 8.8))
	_door_canopy(depot, "Quartermaster", Vector3(12.75, 2.75, 4.3),
		Vector3(1.55, 0.16, 3.9), PI * 0.5)
	_solid_box(depot, "CargoStackNorth", Vector3(2.2, 1.5, 1.6),
		Vector3(19.7, 0.75, 1.5), MAT_WOOD)
	_solid_box(depot, "CargoStackSouth", Vector3(2.6, 1.1, 1.8),
		Vector3(19.4, 0.55, 7.2), MAT_WOOD)
	_solid_box(depot, "DepotShelves", Vector3(0.55, 1.9, 4.0),
		Vector3(21.45, 0.95, 4.3), MAT_WOOD)
	_solid_box(depot, "BarrelStack", Vector3(1.4, 1.2, 1.4),
		Vector3(16.7, 0.6, 7.7), MAT_WOOD)
	_solid_box(depot, "LedgerDesk", Vector3(2.2, 0.86, 0.85),
		Vector3(16.8, 0.43, 1.4), MAT_WOOD)
	_visual_box(depot, "Ledger", Vector3(0.72, 0.06, 0.48),
		Vector3(16.8, 0.9, 1.4), MAT_PROP)
	_interior_light(depot, "InteriorLight", Vector3(17.5, 2.15, 4.3), 8.0)


func _build_supply_rooms(buildings: Node3D) -> void:
	var west := _group(buildings, "WestSupplyRoom")
	_room_shell(west, "WestSupply", WEST_SUPPLY_AT, WEST_SUPPLY_SIZE,
		&"north", -0.75, 7520, 3.15, 2.7)
	_exterior_parapet(west, &"WestSupplySouthParapet",
		Vector3(-13.0, 0.0, 20.1), Vector3(-5.4, 0.0, 20.1))
	_solid_box(west, "SupplyCrates", Vector3(2.2, 1.3, 1.45),
		Vector3(-10.9, 0.65, 15.4), MAT_WOOD)
	_solid_box(west, "SupplyBarrels", Vector3(1.25, 1.15, 1.25),
		Vector3(-7.2, 0.575, 16.1), MAT_WOOD)
	_visual_box(west, "SupplySacks", Vector3(1.8, 0.52, 1.1),
		Vector3(-10.7, 0.27, 13.2), MAT_PROP)
	_interior_light(west, "InteriorLight", Vector3(-9.2, 1.9, 15.2), 5.0,
		Color(1.0, 0.58, 0.28), 2.5)

	var east := _group(buildings, "EastSupplyRoom")
	_room_shell(east, "EastSupply", EAST_SUPPLY_AT, EAST_SUPPLY_SIZE,
		&"north", 0.85, 7550, 3.28, 3.0)
	_exterior_parapet(east, &"EastSupplySouthParapet",
		Vector3(5.4, 0.0, 19.4), Vector3(13.0, 0.0, 19.4))
	_solid_box(east, "CargoStack", Vector3(2.6, 1.0, 1.6),
		Vector3(10.8, 0.5, 16.25), MAT_WOOD)
	_solid_box(east, "TallCrate", Vector3(1.15, 1.75, 1.15),
		Vector3(6.8, 0.875, 15.5), MAT_WOOD)
	_visual_box(east, "HangingRack", Vector3(2.1, 0.18, 0.55),
		Vector3(9.1, 2.15, 17.3), MAT_IRON)
	_visual_box(east, "SupplyBundles", Vector3(1.65, 0.48, 1.3),
		Vector3(7.2, 0.25, 13.2), MAT_PROP)
	_interior_light(east, "InteriorLight", Vector3(9.2, 1.95, 15.0), 5.0,
		Color(1.0, 0.65, 0.32), 2.4)


func _build_garden() -> void:
	var garden := _group(self, "Garden")
	_floor_slab(garden, "GardenGround", GARDEN_SIZE,
		GARDEN_AT + Vector3.UP * 0.012, MAT_GRASS, false)
	# Low perimeter rails stop at a north gate and an east gate. Both openings
	# are obvious from the court, and neither turns the garden into a collision
	# pocket around the alchemist's customer side.
	_solid_box(garden, "GardenFenceWest", Vector3(0.16, 0.62, GARDEN_SIZE.y),
		Vector3(-11.45, 0.31, 0.0), MAT_WOOD)
	_solid_box(garden, "GardenFenceSouth", Vector3(GARDEN_SIZE.x, 0.62, 0.16),
		Vector3(-7.7, 0.31, 4.25), MAT_WOOD)
	_solid_box(garden, "GardenFenceNorthWest", Vector3(2.6, 0.62, 0.16),
		Vector3(-10.15, 0.31, -4.25), MAT_WOOD)
	_solid_box(garden, "GardenFenceNorthEast", Vector3(2.6, 0.62, 0.16),
		Vector3(-5.25, 0.31, -4.25), MAT_WOOD)
	_solid_box(garden, "GardenFenceEastNorth", Vector3(0.16, 0.62, 3.1),
		Vector3(-3.95, 0.31, -2.7), MAT_WOOD)
	_solid_box(garden, "GardenFenceEastSouth", Vector3(0.16, 0.62, 3.1),
		Vector3(-3.95, 0.31, 2.7), MAT_WOOD)

	for row: int in 3:
		var x := -10.55 + float(row) * 1.0
		_visual_box(garden, "GardenCropRow%02d" % (row + 1),
			Vector3(0.78, 0.10, 5.0), Vector3(x, 0.10, 1.2), MAT_WOOD)
		for plant: int in 4:
			_visual_box(garden, "GardenPlantMass%02d_%02d" % [row + 1, plant + 1],
				Vector3(0.62, 0.38 + 0.06 * float((row + plant) % 2), 0.55),
				Vector3(x, 0.29, -0.45 + float(plant) * 1.1), MAT_GRASS)

	_solid_box(garden, "GardenWaterButt", Vector3(0.8, 0.72, 0.8),
		Vector3(-5.2, 0.41, 2.85), MAT_WOOD)
	_visual_box(garden, "GardenWaterRim", Vector3(1.35, 0.16, 1.35),
		Vector3(-5.2, 0.88, 2.85), MAT_IRON)
	for index: int in 4:
		_visual_box(garden, "GardenPathBoard%02d" % (index + 1),
			Vector3(0.85, 0.08, 1.3), Vector3(-4.55 - float(index) * 0.9,
				0.08, 0.05), MAT_WOOD, PI * 0.5)

	for x: float in [-8.9, -5.5]:
		for z: float in [-3.75, -1.75]:
			_solid_box(garden, "AlchemistTrellisPost", Vector3(0.16, 2.5, 0.16),
				Vector3(x, 1.25, z), MAT_WOOD)
	_visual_box(garden, "AlchemistTrellisCanopy", Vector3(3.7, 0.16, 2.3),
		Vector3(-7.2, 2.55, -2.75), MAT_WOOD)
	_interior_light(garden, "GardenTaskLight", Vector3(-7.2, 2.1, -2.2), 3.6,
		Color(0.78, 0.86, 0.48), 1.15)


func _room_shell(
		parent: Node3D,
		label: String,
		at: Vector3,
		size: Vector2,
		door_side: StringName,
		door_offset: float,
		seed: int,
		roof_height: float,
		door_width: float
	) -> void:
	_floor_slab(parent, "%sDeck" % label, size,
		at + Vector3.UP * 0.014, MAT_FLOOR, false)
	_solid_box(parent, "%sRoof" % label,
		Vector3(size.x + 0.30, ROOF_THICKNESS, size.y + 0.30),
		at + Vector3.UP * roof_height, MAT_CEILING)
	# Flat-roof rooms keep the warm timber ceiling below and receive a weathered
	# tile cap above, avoiding an exterior made from exposed interior planks.
	_visual_box(parent, "%sRoofTileCap" % label,
		Vector3(size.x + 0.48, 0.08, size.y + 0.48),
		at + Vector3.UP * (roof_height + ROOF_THICKNESS * 0.5 + 0.04), MAT_ROOF_TILES)

	var west_x := at.x - size.x * 0.5
	var east_x := at.x + size.x * 0.5
	var north_z := at.z - size.y * 0.5
	var south_z := at.z + size.y * 0.5
	var lintel_height := roof_height - DOOR_CLEARANCE
	var lintel_y := DOOR_CLEARANCE + lintel_height * 0.5
	match door_side:
		&"north", &"south":
			_wall(parent, "%sWestWall" % label, size.y,
				Vector3(west_x, 0.0, at.z), PI * 0.5, seed, roof_height)
			_wall(parent, "%sEastWall" % label, size.y,
				Vector3(east_x, 0.0, at.z), -PI * 0.5, seed + 1, roof_height)
			var door_x := at.x + door_offset
			var door_left := door_x - door_width * 0.5
			var door_right := door_x + door_width * 0.5
			var west_return := door_left - west_x
			var east_return := east_x - door_right
			var door_z := north_z if door_side == &"north" else south_z
			var opposite_z := south_z if door_side == &"north" else north_z
			var door_yaw := 0.0 if door_side == &"north" else PI
			var opposite_yaw := PI if door_side == &"north" else 0.0
			var side_word := "North" if door_side == &"north" else "South"
			var opposite_word := "South" if door_side == &"north" else "North"
			_wall(parent, "%s%sWall" % [label, opposite_word], size.x,
				Vector3(at.x, 0.0, opposite_z), opposite_yaw, seed + 2, roof_height)
			_wall(parent, "%s%sWestReturn" % [label, side_word], west_return,
				Vector3(west_x + west_return * 0.5, 0.0, door_z),
				door_yaw, seed + 3, roof_height)
			_wall(parent, "%s%sEastReturn" % [label, side_word], east_return,
				Vector3(door_right + east_return * 0.5, 0.0, door_z),
				door_yaw, seed + 4, roof_height)
			_solid_box(parent, "%sDoorLintel" % label,
				Vector3(door_width, lintel_height, 0.28),
				Vector3(door_x, lintel_y, door_z), MAT_WALL)
		&"east", &"west":
			_wall(parent, "%sNorthWall" % label, size.x,
				Vector3(at.x, 0.0, north_z), 0.0, seed, roof_height)
			_wall(parent, "%sSouthWall" % label, size.x,
				Vector3(at.x, 0.0, south_z), PI, seed + 1, roof_height)
			var door_z := at.z + door_offset
			var door_north := door_z - door_width * 0.5
			var door_south := door_z + door_width * 0.5
			var north_return := door_north - north_z
			var south_return := south_z - door_south
			var door_x := east_x if door_side == &"east" else west_x
			var opposite_x := west_x if door_side == &"east" else east_x
			var door_yaw := -PI * 0.5 if door_side == &"east" else PI * 0.5
			var opposite_yaw := PI * 0.5 if door_side == &"east" else -PI * 0.5
			var side_word := "East" if door_side == &"east" else "West"
			var opposite_word := "West" if door_side == &"east" else "East"
			_wall(parent, "%s%sWall" % [label, opposite_word], size.y,
				Vector3(opposite_x, 0.0, at.z), opposite_yaw, seed + 2, roof_height)
			_wall(parent, "%s%sNorthReturn" % [label, side_word], north_return,
				Vector3(door_x, 0.0, north_z + north_return * 0.5),
				door_yaw, seed + 3, roof_height)
			_wall(parent, "%s%sSouthReturn" % [label, side_word], south_return,
				Vector3(door_x, 0.0, door_south + south_return * 0.5),
				door_yaw, seed + 4, roof_height)
			_solid_box(parent, "%sDoorLintel" % label,
				Vector3(0.28, lintel_height, door_width),
				Vector3(door_x, lintel_y, door_z), MAT_WALL)
		_:
			push_error("GarrisonCompound: unsupported room door side '%s'." % door_side)


func _gabled_roof(parent: Node3D, label: String, at: Vector3,
		size: Vector2, base_y: float, pitch: float, ridge_along_z: bool = true) -> void:
	# The flat collider below remains a reliable ceiling; these lightweight roof
	# planes create distinct civic silhouettes without adding snaggy collision.
	var half_run := (size.x if ridge_along_z else size.y) * 0.5
	var panel_run := half_run / cos(pitch)
	var rise := tan(pitch) * half_run
	for side: float in [-1.0, 1.0]:
		if ridge_along_z:
			var panel := _visual_box(parent, "%sRoofPitch" % label,
				Vector3(panel_run + 0.35, 0.18, size.y + 0.55),
				at + Vector3(side * size.x * 0.25, base_y + rise * 0.5, 0.0),
				MAT_ROOF_TILES)
			panel.rotation.z = -side * pitch
		else:
			var panel := _visual_box(parent, "%sRoofPitch" % label,
				Vector3(size.x + 0.55, 0.18, panel_run + 0.35),
				at + Vector3(0.0, base_y + rise * 0.5, side * size.y * 0.25),
				MAT_ROOF_TILES)
			panel.rotation.x = side * pitch
	var ridge_size := Vector3(0.24, 0.28, size.y + 0.7) if ridge_along_z \
		else Vector3(size.x + 0.7, 0.28, 0.24)
	_visual_box(parent, "%sRoofRidge" % label, ridge_size,
		at + Vector3(0.0, base_y + rise + 0.05, 0.0), MAT_ROOF_TILES)


func _exterior_parapet(parent: Node3D, parapet_name: StringName,
		from: Vector3, to: Vector3) -> void:
	var group := _group(parent, parapet_name)
	var delta := to - from
	var length := delta.length()
	var midpoint := (from + to) * 0.5
	var yaw := atan2(-delta.z, delta.x)
	_visual_box(group, &"ParapetCourse", Vector3(length, 0.38, 0.38),
		midpoint + Vector3.UP * 3.52, MAT_WALL, yaw)
	var merlons := maxi(2, ceili(length / 1.5))
	for index: int in merlons:
		var t := (float(index) + 0.5) / float(merlons)
		var at := from.lerp(to, t) + Vector3.UP * 3.93
		_visual_box(group, "Merlon%02d" % (index + 1), Vector3(0.72, 0.58, 0.52),
			at, MAT_WALL, yaw)


func _door_canopy(parent: Node3D, label: String, at: Vector3,
		size: Vector3, yaw: float) -> void:
	_visual_box(parent, "%sDoorCanopy" % label, size, at, MAT_WOOD, yaw)
	for side: float in [-1.0, 1.0]:
		var offset := Vector3(side * size.x * 0.42, -0.65, 0.0)
		if absf(yaw) > 0.1:
			offset = Vector3(0.0, -0.65, side * size.z * 0.42)
		_visual_box(parent, "%sCanopyPost" % label, Vector3(0.14, 1.3, 0.14),
			at + offset, MAT_WOOD)


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


func _wall_between(parent: Node3D, node_name: String, from: Vector3,
		to: Vector3, seed: int) -> KitWall:
	var delta := to - from
	var yaw := atan2(-delta.z, delta.x)
	return _wall(parent, node_name, delta.length(), (from + to) * 0.5, yaw, seed)


func _round_tower(parent: Node3D, node_name: String, at: Vector3,
		visual_radius: float, height: float, collision_radius: float,
		junction: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	body.position = at
	parent.add_child(body)
	body.add_to_group(&"garrison_round_tower")
	if junction:
		body.add_to_group(&"garrison_junction_tower")

	var core := MeshInstance3D.new()
	core.name = &"TowerCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = visual_radius
	core_mesh.bottom_radius = visual_radius
	core_mesh.height = height
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.material_override = MAT_WALL
	core.position.y = height * 0.5
	body.add_child(core)

	var belt := MeshInstance3D.new()
	belt.name = &"TowerBelt"
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = visual_radius + 0.14
	belt_mesh.bottom_radius = visual_radius + 0.14
	belt_mesh.height = 0.34
	belt_mesh.radial_segments = 12
	belt.mesh = belt_mesh
	belt.material_override = MAT_WALL
	belt.position.y = 2.15
	body.add_child(belt)

	var cap := MeshInstance3D.new()
	cap.name = &"TowerCap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = visual_radius + 0.38
	cap_mesh.bottom_radius = visual_radius + 0.38
	cap_mesh.height = 0.34
	cap_mesh.radial_segments = 12
	cap.mesh = cap_mesh
	cap.material_override = MAT_WALL
	cap.position.y = height + 0.05
	body.add_child(cap)

	var collision := CollisionShape3D.new()
	collision.name = &"Shape"
	var shape := CylinderShape3D.new()
	shape.radius = collision_radius
	shape.height = height
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	return body


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


func _interior_light(
		parent: Node3D,
		node_name: String,
		at: Vector3,
		reach: float,
		color: Color = Color(1.0, 0.72, 0.48),
		energy: float = 2.9
	) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = minf(energy, 3.5)
	light.light_indirect_energy = 0.25
	light.omni_range = minf(reach, 5.2)
	light.omni_attenuation = 1.75
	light.shadow_enabled = false
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
