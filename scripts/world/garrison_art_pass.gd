class_name GarrisonArtPass
extends RefCounted
## Deterministic decorative layer for the authored garrison collision scaffold.

const MAT_COBBLE: Material = preload("res://assets/materials/mat_garrison_cobble.tres")
const MAT_DIRT: Material = preload("res://assets/materials/mat_garrison_dirt.tres")
const MAT_EARTH: Material = preload("res://assets/materials/mat_garrison_earth.tres")
const MAT_RUSTIC_STONE: Material = preload("res://assets/materials/mat_garrison_rustic_stone.tres")
const MAT_PLASTER: Material = preload("res://assets/materials/mat_garrison_plaster.tres")
const MAT_MOSSY_ROCK: Material = preload("res://assets/materials/mat_garrison_mossy_rock.tres")
const MAT_CEILING: Material = preload("res://assets/materials/mat_garrison_ceiling.tres")
const MAT_IRON: Material = preload("res://assets/materials/mat_iron.tres")

const KIT_TORCH: PackedScene = preload("res://scenes/kit/torch.tscn")

const COLUMN_WOOD: PackedScene = preload("res://assets/props/garrison_architecture/column-wood.glb")
const WALL_WOOD: PackedScene = preload("res://assets/props/garrison_architecture/wall-pane-wood.glb")
const WALL_WINDOW: PackedScene = preload("res://assets/props/garrison_architecture/wall-pane-wood-window.glb")
const WALL_PAINTED_WINDOW: PackedScene = preload("res://assets/props/garrison_architecture/wall-pane-painted-wood-window.glb")
const FENCE_WOOD: PackedScene = preload("res://assets/props/garrison_architecture/fence-wood.glb")
const STRUCTURE_WALL: PackedScene = preload("res://assets/props/garrison_architecture/structure-wall.glb")
const TREE_SHRUB: PackedScene = preload("res://assets/props/garrison_architecture/tree-shrub.glb")
const CRATE_ROPES: PackedScene = preload("res://assets/props/garrison_architecture/detail-crate-ropes.glb")
const PULLEY: PackedScene = preload("res://assets/props/garrison_architecture/pulley.glb")

const BOULDER_1: PackedScene = preload("res://assets/props/garrison_rocks/boulder_1_tl.glb")
const BOULDER_5: PackedScene = preload("res://assets/props/garrison_rocks/boulder_5_tr.glb")
const BOULDER_8: PackedScene = preload("res://assets/props/garrison_rocks/boulder_8_bl.glb")
const ROCK_1: PackedScene = preload("res://assets/props/garrison_rocks/rock_1_tl.glb")
const ROCK_3: PackedScene = preload("res://assets/props/garrison_rocks/rock_3_br.glb")
const ROCK_6: PackedScene = preload("res://assets/props/garrison_rocks/rock_6_tr.glb")

const TABLE_LARGE: PackedScene = preload("res://assets/props/booth/Table_Large.gltf")
const BENCH: PackedScene = preload("res://assets/props/booth/Bench.gltf")
const BED_TWIN_2: PackedScene = preload("res://assets/props/booth/Bed_Twin2.gltf")
const BOOKCASE_2: PackedScene = preload("res://assets/props/booth/Bookcase_2.gltf")
const CABINET: PackedScene = preload("res://assets/props/booth/Cabinet.gltf")
const CHAIR_1: PackedScene = preload("res://assets/props/booth/Chair_1.gltf")
const STOOL: PackedScene = preload("res://assets/props/booth/Stool.gltf")
const MUG: PackedScene = preload("res://assets/props/booth/Mug.gltf")
const TABLE_PLATE: PackedScene = preload("res://assets/props/booth/Table_Plate.gltf")
const POT_1: PackedScene = preload("res://assets/props/booth/Pot_1.gltf")
const CHANDELIER: PackedScene = preload("res://assets/props/booth/Chandelier.gltf")
const BANNER_1: PackedScene = preload("res://assets/props/booth/Banner_1.gltf")
const BANNER_2: PackedScene = preload("res://assets/props/booth/Banner_2.gltf")
const FARM_CRATE_EMPTY: PackedScene = preload("res://assets/props/booth/FarmCrate_Empty.gltf")
const FARM_CRATE_APPLE: PackedScene = preload("res://assets/props/booth/FarmCrate_Apple.gltf")
const FARM_CRATE_CARROT: PackedScene = preload("res://assets/props/booth/FarmCrate_Carrot.gltf")
const CARROT: PackedScene = preload("res://assets/props/booth/Carrot.gltf")
const ROPE_1: PackedScene = preload("res://assets/props/booth/Rope_1.gltf")
const BUCKET_WOODEN_1: PackedScene = preload("res://assets/props/booth/Bucket_Wooden_1.gltf")
const PICKAXE_BRONZE: PackedScene = preload("res://assets/props/booth/Pickaxe_Bronze.gltf")
const AXE_BRONZE: PackedScene = preload("res://assets/props/booth/Axe_Bronze.gltf")
const SCROLL_1: PackedScene = preload("res://assets/props/booth/Scroll_1.gltf")
const SCROLL_2: PackedScene = preload("res://assets/props/booth/Scroll_2.gltf")
const CANDLESTICK_TRIPLE: PackedScene = preload("res://assets/props/booth/CandleStick_Triple.gltf")
const BAG: PackedScene = preload("res://assets/props/booth/Bag.gltf")
const PEG_RACK: PackedScene = preload("res://assets/props/booth/Peg_Rack.gltf")
const SHIELD_WOODEN: PackedScene = preload("res://assets/props/booth/Shield_Wooden.gltf")
const SHELF_SIMPLE: PackedScene = preload("res://assets/props/booth/Shelf_Simple.gltf")
const WORKBENCH: PackedScene = preload("res://assets/props/booth/Workbench.gltf")
const BARREL: PackedScene = preload("res://assets/props/booth/Barrel.gltf")
const CHEST_WOOD: PackedScene = preload("res://assets/props/booth/Chest_Wood.gltf")
const CRATE_WOODEN: PackedScene = preload("res://assets/props/booth/Crate_Wooden.gltf")
const CAULDRON: PackedScene = preload("res://assets/props/booth/Cauldron.gltf")
const WHETSTONE: PackedScene = preload("res://assets/props/booth/Whetstone.gltf")
const WEAPON_STAND: PackedScene = preload("res://assets/props/booth/WeaponStand.gltf")
const LANTERN_WALL: PackedScene = preload("res://assets/props/booth/Lantern_Wall.gltf")

const WATERING_CAN: PackedScene = preload("res://assets/props/garrison_farm/watering_can_metal_01.glb")
const RUSTED_SPADE: PackedScene = preload("res://assets/props/garrison_farm/rusted_spade_01.glb")
const WOODEN_BUCKET: PackedScene = preload("res://assets/props/garrison_farm/wooden_bucket_01.glb")
const WOODEN_CRATE: PackedScene = preload("res://assets/props/garrison_farm/wooden_crate_01.glb")


static func build(compound: GarrisonCompound) -> void:
	if compound.get_node_or_null(^"ArtPass") != null:
		return
	var art_pass := _group(compound, &"ArtPass")
	_build_terrain(compound, art_pass)
	_build_architecture(compound, art_pass)
	_build_interiors(compound, art_pass)
	_build_garden(art_pass)
	_build_practicals(art_pass)
	_build_perimeter_torches(art_pass)
	_build_night_fills(art_pass)
	_build_gate_mechanism(art_pass)
	_build_gate_vista(art_pass)


static func _build_terrain(compound: GarrisonCompound, art_pass: Node3D) -> void:
	var terrain := _group(art_pass, &"Terrain")
	# Replace the two broad prototype sheets with a route hierarchy over the one
	# retained FortGround collision slab.
	_hide_named_visuals(compound, [&"ParadePaving", &"GateWalk"])
	var plaza := MeshInstance3D.new()
	plaza.name = &"CobblePlaza"
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 7.1
	plaza_mesh.bottom_radius = 7.1
	plaza_mesh.height = 0.034
	plaza_mesh.radial_segments = 12
	plaza.mesh = plaza_mesh
	plaza.material_override = MAT_COBBLE
	plaza.position = Vector3(1.0, 0.042, 0.0)
	terrain.add_child(plaza)

	_ground_segment(terrain, &"GateSpineSouth", Vector2(0.0, 17.72),
		Vector2(-0.10, 12.6), 4.9, MAT_COBBLE, 0.043)
	_ground_segment(terrain, &"GateSpineMiddle", Vector2(-0.10, 12.8),
		Vector2(0.25, 7.9), 4.55, MAT_COBBLE, 0.045)
	_ground_segment(terrain, &"GateSpinePlaza", Vector2(0.25, 8.2),
		Vector2(0.85, 5.6), 4.25, MAT_COBBLE, 0.047)

	_ground_segment(terrain, &"SpurBarracks", Vector2(-3.2, -5.4),
		Vector2(-13.65, -12.35), 2.25, MAT_DIRT)
	_ground_segment(terrain, &"SpurMess", Vector2(-1.7, -5.7),
		Vector2(-6.9, -10.95), 2.2, MAT_COBBLE)
	_ground_segment(terrain, &"SpurLeader", Vector2(5.6, -4.8),
		Vector2(12.7, -9.48), 2.25, MAT_DIRT)
	_ground_segment(terrain, &"SpurGarden", Vector2(-5.5, 0.25),
		Vector2(-3.98, 0.1), 2.05, MAT_DIRT)
	_ground_segment(terrain, &"SpurWestCraft", Vector2(-5.2, -2.1),
		Vector2(-12.3, -4.55), 2.25, MAT_COBBLE)
	_ground_segment(terrain, &"SpurSmith", Vector2(-12.2, -4.55),
		Vector2(-14.35, -4.6), 2.1, MAT_DIRT)
	_ground_segment(terrain, &"SpurJeweller", Vector2(-11.9, -3.7),
		Vector2(-14.35, 3.0), 2.05, MAT_DIRT)
	_ground_segment(terrain, &"SpurBuilder", Vector2(-5.3, 4.6),
		Vector2(-12.9, 11.05), 2.25, MAT_COBBLE)
	_ground_segment(terrain, &"SpurQuartermaster", Vector2(6.4, 2.6),
		Vector2(12.85, 4.3), 2.3, MAT_COBBLE)
	_ground_segment(terrain, &"SpurWestSupply", Vector2(-2.6, 6.0),
		Vector2(-9.95, 11.82), 2.2, MAT_DIRT)
	_ground_segment(terrain, &"SpurEastSupply", Vector2(3.9, 6.0),
		Vector2(10.05, 11.82), 2.2, MAT_DIRT)

	_visual_box(terrain, &"GardenEarth", Vector3(3.25, 0.026, 7.75),
		Vector3(-9.3, 0.048, 0.25), MAT_EARTH)
	for row: int in 3:
		_visual_box(terrain, "GardenCultivatedRow%02d" % (row + 1),
			Vector3(0.74, 0.025, 5.0),
			Vector3(-10.55 + float(row), 0.164, 1.2), MAT_EARTH)
	# Short irregular wear strokes soften the thresholds without rectangular decals.
	_ground_segment(terrain, &"SmithWear", Vector2(-14.5, -6.35),
		Vector2(-15.5, -7.55), 2.0, MAT_DIRT, 0.049)
	_ground_segment(terrain, &"BuilderWear", Vector2(-12.9, 9.15),
		Vector2(-14.25, 7.85), 1.9, MAT_DIRT, 0.049)
	_ground_segment(terrain, &"QuartermasterWear", Vector2(12.75, 6.35),
		Vector2(11.25, 7.8), 2.0, MAT_DIRT, 0.049)


static func _build_architecture(compound: GarrisonCompound, art_pass: Node3D) -> void:
	var architecture := _group(art_pass, &"Architecture")
	# Occupied buildings use a lighter, warmer masonry family than the defensive
	# curtain. Keeping the curtain dark makes the rooms read as authored places
	# inside the fort instead of one continuous stone bunker.
	var buildings := compound.get_node_or_null(^"Buildings")
	if buildings != null:
		for node: Node in buildings.find_children("*", "KitWall", true, false):
			var wall_material: Material = MAT_RUSTIC_STONE
			var room_path := String(node.get_path())
			if ("LeaderQuarters" in room_path or "MessHall" in room_path
					or "Jewelcrafter" in room_path):
				wall_material = MAT_PLASTER
			(node as KitWall).material = wall_material
	_hide_named_visuals(compound, [
	])

	var frames := _group(architecture, &"DoorFrames")
	# Keep the entire imported jamb profile backed by the real wall returns. The
	# chase camera only collides with that authored shell, so proud decor may not
	# protrude into the mathematical opening.
	_door_frame(frames, &"Barracks", Vector3(-13.86, 0.04, -12.0),
		Vector3(-13.86, 0.04, -8.4), 3.25)
	_door_frame(frames, &"Mess", Vector3(-8.55, 0.04, -11.04),
		Vector3(-5.25, 0.04, -11.04), 3.25)
	_door_frame(frames, &"Leader", Vector3(11.15, 0.04, -9.55),
		Vector3(14.25, 0.04, -9.55), 3.25)
	_door_frame(frames, &"Smith", Vector3(-14.38, 0.04, -6.15),
		Vector3(-14.38, 0.04, -3.05), 3.2)
	_door_frame(frames, &"Jewel", Vector3(-14.38, 0.04, 1.35),
		Vector3(-14.38, 0.04, 4.15), 3.0)
	_door_frame(frames, &"Builder", Vector3(-12.94, 0.04, 9.55),
		Vector3(-12.94, 0.04, 12.65), 3.25)
	_door_frame(frames, &"Quartermaster", Vector3(12.84, 0.04, 2.6),
		Vector3(12.84, 0.04, 6.0), 3.1)
	_door_frame(frames, &"WestSupply", Vector3(-11.35, 0.04, 11.88),
		Vector3(-8.55, 0.04, 11.88), 3.0)
	_door_frame(frames, &"EastSupply", Vector3(8.55, 0.04, 11.88),
		Vector3(11.55, 0.04, 11.88), 3.1)

	var facades := _group(architecture, &"Facades")
	_facade_panel(facades, WALL_WINDOW, &"BarracksWindowNorth",
		Vector3(-13.56, 0.08, -15.65), -PI * 0.5, Vector3(1.65, 3.0, 0.8))
	_facade_panel(facades, WALL_WOOD, &"BarracksPanelSouth",
		Vector3(-13.80, 0.08, -7.95), -PI * 0.5, Vector3(1.45, 3.0, 0.8))
	_facade_panel(facades, WALL_WOOD, &"MessPanelWest", Vector3(-10.0, 0.08, -10.98),
		PI, Vector3(1.7, 3.0, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"MessWindowEast", Vector3(-3.9, 0.08, -10.98),
		PI, Vector3(1.7, 3.0, 0.8))
	_facade_panel(facades, WALL_PAINTED_WINDOW, &"LeaderWindowWest",
		Vector3(9.55, 0.08, -9.48), PI, Vector3(1.6, 3.0, 0.8))
	_facade_panel(facades, WALL_PAINTED_WINDOW, &"LeaderWindowEast",
		Vector3(15.85, 0.08, -9.48), PI, Vector3(1.6, 3.0, 0.8))
	_facade_panel(facades, WALL_WOOD, &"SmithPanelNorth", Vector3(-14.31, 0.08, -7.1),
		-PI * 0.5, Vector3(1.35, 3.0, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"SmithWindowSouth", Vector3(-14.31, 0.08, -1.7),
		-PI * 0.5, Vector3(1.25, 3.0, 0.8))
	_facade_panel(facades, WALL_PAINTED_WINDOW, &"JewelWindowNorth",
		Vector3(-14.31, 0.08, 0.25), -PI * 0.5, Vector3(1.25, 2.75, 0.8))
	_facade_panel(facades, WALL_PAINTED_WINDOW, &"JewelWindowSouth",
		Vector3(-14.31, 0.08, 5.45), -PI * 0.5, Vector3(1.2, 2.75, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"BuilderWindowNorth",
		Vector3(-12.87, 0.08, 8.35), -PI * 0.5, Vector3(1.45, 3.0, 0.8))
	_facade_panel(facades, WALL_WOOD, &"BuilderPanelSouth",
		Vector3(-12.87, 0.08, 13.95), -PI * 0.5, Vector3(1.35, 3.0, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"QuartermasterWindowNorth",
		Vector3(12.77, 0.08, 0.75), PI * 0.5, Vector3(1.55, 2.9, 0.8))
	_facade_panel(facades, WALL_WOOD, &"QuartermasterPanelSouth",
		Vector3(12.77, 0.08, 7.75), PI * 0.5, Vector3(1.45, 2.9, 0.8))
	_facade_panel(facades, WALL_WOOD, &"WestSupplyPanelWest",
		Vector3(-12.25, 0.08, 11.81), 0.0, Vector3(1.25, 2.75, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"WestSupplyWindowEast",
		Vector3(-6.8, 0.08, 11.81), 0.0, Vector3(1.35, 2.75, 0.8))
	_facade_panel(facades, WALL_WINDOW, &"EastSupplyWindowWest",
		Vector3(6.45, 0.08, 11.81), 0.0, Vector3(1.45, 2.85, 0.8))
	_facade_panel(facades, WALL_WOOD, &"EastSupplyPanelEast",
		Vector3(12.25, 0.08, 11.81), 0.0, Vector3(1.25, 2.85, 0.8))

	# Stone aprons sit on blank exterior walls; they add material depth without
	# becoming a second architectural collision shell.
	_asset(facades, STRUCTURE_WALL, &"SmithStoneApron",
		Vector3(-21.92, 0.04, -4.6), PI * 0.5, Vector3(4.8, 1.1, 0.35), MAT_RUSTIC_STONE)
	_asset(facades, STRUCTURE_WALL, &"QuartermasterStoneApron",
		Vector3(21.92, 0.04, 4.3), -PI * 0.5, Vector3(5.4, 1.0, 0.35), MAT_RUSTIC_STONE)
	_asset(facades, BANNER_1, &"BarracksFacadeBanner",
		Vector3(-13.45, 1.55, -15.7), -PI * 0.5, Vector3(0.8, 0.8, 0.8))
	_asset(facades, BANNER_2, &"LeaderFacadeBanner",
		Vector3(15.75, 1.55, -9.34), PI, Vector3(0.9, 0.9, 0.9))
	_asset(facades, BANNER_1, &"QuartermasterFacadeBanner",
		Vector3(12.65, 1.5, 0.7), PI * 0.5, Vector3(0.72, 0.72, 0.72))


static func _build_interiors(compound: GarrisonCompound, art_pass: Node3D) -> void:
	var hidden: Array[StringName] = [
		&"WeaponLocker", &"WeaponRack", &"BuilderBunk", &"MessTable",
		&"MessBenchNorth", &"MessBenchSouth", &"ServingSideboard",
		&"PantryBarrels", &"TableSetting", &"LeaderBedFrame",
		&"LeaderMattress", &"MapDesk", &"MapWeight", &"Bookcase",
		&"LeaderChest", &"CoalBin", &"ForgeBasin", &"ForgeCoals",
		&"ToolRack", &"JewelStorageShelf", &"BuilderWorktable",
		&"CargoStackNorth", &"CargoStackSouth", &"DepotShelves",
		&"BarrelStack", &"LedgerDesk", &"Ledger", &"SupplyCrates",
		&"SupplyBarrels", &"SupplySacks", &"CargoStack", &"TallCrate",
		&"HangingRack", &"SupplyBundles", &"GardenWaterButt",
		&"GardenWaterRim",
		&"AlchemistTrellisPost", &"AlchemistTrellisCanopy",
		&"TimberStack", &"WorkPost", &"WorkCrossbar", &"TimberBeam",
		&"GardenFenceWest", &"GardenFenceSouth", &"GardenFenceNorthWest",
		&"GardenFenceNorthEast", &"GardenFenceEastNorth", &"GardenFenceEastSouth",
	]
	for row: int in 3:
		for plant: int in 4:
			hidden.append(StringName("GardenPlantMass%02d_%02d" % [row + 1, plant + 1]))
	_hide_named_visuals(compound, hidden)

	var interiors := _group(art_pass, &"Interiors")
	_build_barracks_interior(_group(interiors, &"Barracks"))
	_build_mess_interior(_group(interiors, &"MessHall"))
	_build_leader_interior(_group(interiors, &"LeaderQuarters"))
	_build_smith_interior(_group(interiors, &"Smithy"))
	_build_jeweller_interior(_group(interiors, &"Jewelcrafter"))
	_build_builder_interior(_group(interiors, &"BuilderWorkshop"))
	_build_quartermaster_interior(_group(interiors, &"Quartermaster"))
	_build_supply_interiors(_group(interiors, &"SupplyRooms"))


static func _build_barracks_interior(room: Node3D) -> void:
	_asset(room, WEAPON_STAND, &"BarracksWeaponStand", Vector3(-14.65, 0.04, -15.65),
		PI * 0.5, Vector3(0.85, 0.85, 0.85))
	_asset(room, PEG_RACK, &"BarracksPegRack", Vector3(-14.02, 1.45, -14.8),
		-PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, SHIELD_WOODEN, &"BarracksShieldNorth", Vector3(-14.03, 1.2, -10.15),
		-PI * 0.5, Vector3(0.8, 0.8, 0.8))
	_asset(room, SHIELD_WOODEN, &"BarracksShieldSouth", Vector3(-14.05, 1.2, -9.25),
		-PI * 0.5, Vector3(0.72, 0.72, 0.72))
	_asset(room, BAG, &"BarracksKitBagA", Vector3(-14.65, 0.04, -9.0),
		deg_to_rad(18.0), Vector3(0.8, 0.8, 0.8))
	_asset(room, BAG, &"BarracksKitBagB", Vector3(-15.25, 0.04, -9.1),
		deg_to_rad(-24.0), Vector3(0.7, 0.7, 0.7))
	_asset(room, STOOL, &"BarracksStool", Vector3(-15.0, 0.04, -10.0),
		0.0, Vector3(0.85, 0.85, 0.85))
	_asset(room, CHANDELIER, &"BarracksChandelierNorth", Vector3(-17.7, 3.25, -14.5),
		0.0, Vector3(0.85, 0.85, 0.85))
	_asset(room, CHANDELIER, &"BarracksChandelierSouth", Vector3(-17.7, 3.25, -10.2),
		0.0, Vector3(0.85, 0.85, 0.85))


static func _build_mess_interior(room: Node3D) -> void:
	_asset(room, TABLE_LARGE, &"MessImportedTable", Vector3(-6.9, 0.04, -14.4),
		0.0, Vector3(1.45, 1.0, 1.0))
	_asset(room, BENCH, &"MessImportedBenchNorth", Vector3(-6.9, 0.04, -15.4),
		0.0, Vector3(1.45, 1.0, 1.0))
	# The south bench is shorter and offset west, leaving a direct 1.2 m door lane.
	_asset(room, BENCH, &"MessImportedBenchSouth", Vector3(-8.2, 0.04, -13.38),
		0.0, Vector3(0.82, 1.0, 1.0))
	for index: int in 3:
		var setting_x := -8.35 + float(index) * 1.45
		_asset(room, TABLE_PLATE, "MessPlate%02d" % (index + 1),
			Vector3(setting_x, 0.91, -14.35), 0.0, Vector3(0.72, 0.72, 0.72))
		_asset(room, MUG, "MessMug%02d" % (index + 1),
			Vector3(setting_x + 0.35, 0.91, -14.05), deg_to_rad(float(index) * 35.0),
			Vector3(0.7, 0.7, 0.7))
	_asset(room, POT_1, &"MessServingPot", Vector3(-5.1, 0.91, -14.55),
		0.0, Vector3(0.8, 0.8, 0.8))
	_asset(room, WORKBENCH, &"MessSideboard", Vector3(-9.2, 0.04, -16.75),
		PI, Vector3(1.05, 0.9, 0.9))
	_asset(room, CABINET, &"MessPantryCabinet", Vector3(-4.3, 0.04, -16.8),
		PI, Vector3(0.9, 0.9, 0.9))
	_asset(room, BARREL, &"MessPantryBarrel", Vector3(-3.45, 0.04, -16.65),
		deg_to_rad(12.0), Vector3(0.9, 0.9, 0.9))
	_asset(room, CAULDRON, &"MessCornerCauldron", Vector3(-10.25, 0.04, -15.8),
		0.0, Vector3(0.8, 0.8, 0.8))
	_asset(room, CHANDELIER, &"MessChandelier", Vector3(-6.9, 3.25, -14.45),
		0.0, Vector3(1.0, 1.0, 1.0))


static func _build_leader_interior(room: Node3D) -> void:
	_asset(room, BED_TWIN_2, &"LeaderImportedBed", Vector3(11.3, 0.04, -14.8),
		0.0, Vector3(1.0, 1.0, 1.0))
	_asset(room, TABLE_LARGE, &"LeaderMapTable", Vector3(14.35, 0.04, -15.15),
		0.0, Vector3(0.82, 0.9, 0.78))
	_asset(room, CHAIR_1, &"LeaderDeskChair", Vector3(14.35, 0.04, -14.0),
		PI, Vector3(0.85, 0.85, 0.85))
	_asset(room, SCROLL_1, &"LeaderMapScroll", Vector3(14.0, 0.88, -15.1),
		deg_to_rad(8.0), Vector3(0.8, 0.8, 0.8))
	_asset(room, SCROLL_2, &"LeaderOrdersScroll", Vector3(14.55, 0.88, -15.2),
		deg_to_rad(-15.0), Vector3(0.72, 0.72, 0.72))
	_asset(room, CANDLESTICK_TRIPLE, &"LeaderDeskCandles", Vector3(15.0, 0.88, -15.1),
		0.0, Vector3(0.7, 0.7, 0.7))
	_asset(room, BOOKCASE_2, &"LeaderBookcase", Vector3(16.35, 0.04, -13.0),
		-PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, CABINET, &"LeaderCabinet", Vector3(15.75, 0.04, -16.85),
		PI, Vector3(0.85, 0.85, 0.85))
	_asset(room, CHEST_WOOD, &"LeaderImportedChest", Vector3(15.75, 0.04, -10.25),
		PI, Vector3(0.9, 0.9, 0.9))
	_asset(room, CHANDELIER, &"LeaderChandelier", Vector3(12.75, 3.25, -13.55),
		0.0, Vector3(0.95, 0.95, 0.95))


static func _build_smith_interior(room: Node3D) -> void:
	_asset(room, PEG_RACK, &"SmithWallPegRack", Vector3(-21.75, 1.45, -4.15),
		PI * 0.5, Vector3(1.0, 1.0, 1.0))
	_asset(room, WEAPON_STAND, &"SmithWeaponStand", Vector3(-20.6, 0.04, -2.25),
		PI, Vector3(0.9, 0.9, 0.9))
	_asset(room, WHETSTONE, &"SmithWhetstone", Vector3(-17.7, 0.04, -6.65),
		PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, BUCKET_WOODEN_1, &"SmithQuenchBucket", Vector3(-18.15, 0.04, -6.75),
		0.0, Vector3(0.85, 0.85, 0.85))
	_asset(room, BARREL, &"SmithCoalBarrelA", Vector3(-20.85, 0.04, -2.2),
		deg_to_rad(10.0), Vector3(0.85, 0.85, 0.85))
	_asset(room, BARREL, &"SmithCoalBarrelB", Vector3(-21.2, 0.04, -2.95),
		deg_to_rad(-12.0), Vector3(0.75, 0.75, 0.75))
	_asset(room, PICKAXE_BRONZE, &"SmithWallPickaxe", Vector3(-21.72, 1.45, -5.35),
		PI * 0.5, Vector3(0.85, 0.85, 0.85))
	_asset(room, AXE_BRONZE, &"SmithWallAxe", Vector3(-21.70, 1.35, -3.35),
		PI * 0.5, Vector3(0.85, 0.85, 0.85))
	_asset(room, CAULDRON, &"SmithForgeCauldron", Vector3(-19.2, 0.86, -6.5),
		0.0, Vector3(0.92, 0.92, 0.92))
	_asset(room, WORKBENCH, &"SmithDetailBench", Vector3(-20.3, 0.04, -4.55),
		PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, LANTERN_WALL, &"SmithWallLantern", Vector3(-14.48, 1.8, -7.25),
		-PI * 0.5, Vector3(0.8, 0.8, 0.8))


static func _build_jeweller_interior(room: Node3D) -> void:
	_asset(room, SHELF_SIMPLE, &"JewelImportedShelf", Vector3(-21.55, 0.04, 3.1),
		PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, CABINET, &"JewelCabinet", Vector3(-20.55, 0.04, 5.75),
		0.0, Vector3(0.82, 0.82, 0.82))
	_asset(room, STOOL, &"JewelStool", Vector3(-18.4, 0.04, 4.85),
		deg_to_rad(12.0), Vector3(0.82, 0.82, 0.82))
	_asset(room, CANDLESTICK_TRIPLE, &"JewelCounterCandles", Vector3(-20.35, 0.9, 1.0),
		0.0, Vector3(0.62, 0.62, 0.62))
	_asset(room, SCROLL_2, &"JewelCounterLedger", Vector3(-20.1, 0.9, 1.25),
		deg_to_rad(22.0), Vector3(0.65, 0.65, 0.65))
	_asset(room, CHEST_WOOD, &"JewelStrongbox", Vector3(-19.8, 0.04, 0.45),
		0.0, Vector3(0.7, 0.7, 0.7))
	_asset(room, BAG, &"JewelPouchA", Vector3(-19.15, 0.04, 0.65),
		deg_to_rad(-20.0), Vector3(0.58, 0.58, 0.58))
	_asset(room, BAG, &"JewelPouchB", Vector3(-18.75, 0.04, 0.55),
		deg_to_rad(25.0), Vector3(0.52, 0.52, 0.52))
	_asset(room, BANNER_2, &"JewelBanner", Vector3(-14.48, 1.45, 5.45),
		-PI * 0.5, Vector3(0.68, 0.68, 0.68))
	_asset(room, LANTERN_WALL, &"JewelWallLantern", Vector3(-14.47, 1.8, 0.35),
		-PI * 0.5, Vector3(0.7, 0.7, 0.7))


static func _build_builder_interior(room: Node3D) -> void:
	_asset(room, WORKBENCH, &"BuilderImportedWorkbench", Vector3(-17.8, 0.04, 10.4),
		0.0, Vector3(1.2, 1.0, 1.0))
	_asset(room, PULLEY, &"BuilderPulley", Vector3(-19.75, 2.45, 9.0),
		0.0, Vector3(1.2, 1.2, 1.2))
	_asset(room, CRATE_ROPES, &"BuilderRopedCrate", Vector3(-20.45, 0.04, 12.75),
		deg_to_rad(-12.0), Vector3(0.95, 0.95, 0.95))
	_asset(room, PICKAXE_BRONZE, &"BuilderPickaxe", Vector3(-18.65, 0.92, 10.25),
		deg_to_rad(18.0), Vector3(0.8, 0.8, 0.8))
	_asset(room, AXE_BRONZE, &"BuilderAxe", Vector3(-17.6, 0.92, 10.35),
		deg_to_rad(-25.0), Vector3(0.8, 0.8, 0.8))
	_asset(room, ROPE_1, &"BuilderCoiledRope", Vector3(-19.55, 0.04, 13.55),
		0.0, Vector3(0.9, 0.9, 0.9))
	_asset(room, CRATE_WOODEN, &"BuilderCrateA", Vector3(-20.65, 0.04, 11.25),
		deg_to_rad(8.0), Vector3(0.85, 0.85, 0.85))
	_asset(room, WOODEN_CRATE, &"BuilderCrateB", Vector3(-19.8, 0.04, 11.75),
		deg_to_rad(-15.0), Vector3(0.7, 0.7, 0.7))
	_asset(room, LANTERN_WALL, &"BuilderWallLantern", Vector3(-12.98, 1.8, 8.25),
		-PI * 0.5, Vector3(0.72, 0.72, 0.72))
	# Short, staggered stock beside the solid timber proxy reads as usable lumber,
	# not the former wall-height black beam pile.
	for index: int in 5:
		_visual_box(room, "BuilderLumber%02d" % (index + 1),
			Vector3(2.9 - float(index % 2) * 0.35, 0.18, 0.24),
			Vector3(-17.4, 0.18 + float(index) * 0.19,
				13.52 + float(index % 2) * 0.18), MAT_CEILING, deg_to_rad(4.0))


static func _build_quartermaster_interior(room: Node3D) -> void:
	_asset(room, CRATE_ROPES, &"QuartermasterCargoNorth", Vector3(19.7, 0.04, 1.5),
		deg_to_rad(10.0), Vector3(1.15, 1.15, 1.15))
	_asset(room, FARM_CRATE_APPLE, &"QuartermasterAppleCrate", Vector3(20.1, 0.04, 6.9),
		deg_to_rad(-8.0), Vector3(0.9, 0.9, 0.9))
	_asset(room, CRATE_WOODEN, &"QuartermasterCrate", Vector3(19.25, 0.04, 7.35),
		deg_to_rad(13.0), Vector3(1.0, 1.0, 1.0))
	_asset(room, BARREL, &"QuartermasterBarrelA", Vector3(17.0, 0.04, 7.75),
		0.0, Vector3(0.9, 0.9, 0.9))
	_asset(room, BARREL, &"QuartermasterBarrelB", Vector3(18.0, 0.04, 8.0),
		deg_to_rad(18.0), Vector3(0.8, 0.8, 0.8))
	_asset(room, CHEST_WOOD, &"QuartermasterChest", Vector3(20.75, 0.04, 2.65),
		-PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(room, SHELF_SIMPLE, &"QuartermasterShelves", Vector3(21.45, 0.04, 4.45),
		-PI * 0.5, Vector3(1.0, 1.0, 1.0))
	_asset(room, TABLE_LARGE, &"QuartermasterLedgerDesk", Vector3(16.9, 0.04, 1.35),
		0.0, Vector3(0.7, 0.85, 0.7))
	_asset(room, CHAIR_1, &"QuartermasterChair", Vector3(16.9, 0.04, 0.55),
		0.0, Vector3(0.82, 0.82, 0.82))
	_asset(room, SCROLL_1, &"QuartermasterLedger", Vector3(16.85, 0.86, 1.35),
		deg_to_rad(-12.0), Vector3(0.72, 0.72, 0.72))
	_asset(room, CHANDELIER, &"QuartermasterChandelier", Vector3(18.0, 3.05, 4.3),
		0.0, Vector3(1.0, 1.0, 1.0))


static func _build_supply_interiors(rooms: Node3D) -> void:
	var west := _group(rooms, &"WestSupply")
	_asset(west, CRATE_WOODEN, &"WestCrateA", Vector3(-11.7, 0.04, 15.6),
		deg_to_rad(8.0), Vector3(1.0, 1.0, 1.0))
	_asset(west, WOODEN_CRATE, &"WestCrateB", Vector3(-10.65, 0.04, 16.4),
		deg_to_rad(-12.0), Vector3(0.85, 0.85, 0.85))
	_asset(west, FARM_CRATE_CARROT, &"WestProduceCrate", Vector3(-11.7, 0.9, 15.65),
		deg_to_rad(5.0), Vector3(0.8, 0.8, 0.8))
	_asset(west, BARREL, &"WestBarrelA", Vector3(-7.0, 0.04, 16.6),
		0.0, Vector3(0.9, 0.9, 0.9))
	_asset(west, BARREL, &"WestBarrelB", Vector3(-6.25, 0.04, 16.25),
		deg_to_rad(18.0), Vector3(0.78, 0.78, 0.78))
	_asset(west, BAG, &"WestSupplyBagA", Vector3(-12.0, 0.04, 13.45),
		deg_to_rad(-20.0), Vector3(0.8, 0.8, 0.8))
	_asset(west, BAG, &"WestSupplyBagB", Vector3(-11.35, 0.04, 13.5),
		deg_to_rad(25.0), Vector3(0.7, 0.7, 0.7))
	_asset(west, CHANDELIER, &"WestSupplyChandelier", Vector3(-9.2, 2.95, 15.4),
		0.0, Vector3(0.78, 0.78, 0.78))

	var east := _group(rooms, &"EastSupply")
	_asset(east, CHEST_WOOD, &"EastSupplyChest", Vector3(11.8, 0.04, 16.65),
		PI, Vector3(0.95, 0.95, 0.95))
	_asset(east, CRATE_ROPES, &"EastRopedCargo", Vector3(7.05, 0.04, 16.45),
		deg_to_rad(15.0), Vector3(0.95, 0.95, 0.95))
	_asset(east, FARM_CRATE_EMPTY, &"EastEmptyCrate", Vector3(6.25, 0.04, 15.65),
		deg_to_rad(-10.0), Vector3(0.82, 0.82, 0.82))
	_asset(east, SHELF_SIMPLE, &"EastSupplyShelf", Vector3(12.55, 0.04, 14.8),
		-PI * 0.5, Vector3(0.9, 0.9, 0.9))
	_asset(east, BAG, &"EastSupplyBag", Vector3(7.2, 0.04, 13.6),
		deg_to_rad(25.0), Vector3(0.82, 0.82, 0.82))
	_asset(east, ROPE_1, &"EastSupplyRope", Vector3(11.8, 0.04, 13.6),
		0.0, Vector3(0.85, 0.85, 0.85))
	_asset(east, PEG_RACK, &"EastHangingRack", Vector3(9.2, 1.9, 17.45),
		PI, Vector3(1.0, 1.0, 1.0))


static func _build_garden(art_pass: Node3D) -> void:
	var garden := _group(art_pass, &"GardenDressing")
	for row: int in 3:
		for plant: int in 4:
			var carrot_at := Vector3(-10.55 + float(row), 0.18,
				-0.45 + float(plant) * 1.12)
			_asset(garden, CARROT, "Carrot%02d_%02d" % [row + 1, plant + 1],
				carrot_at, deg_to_rad(float((row * 4 + plant) % 5) * 11.0 - 22.0),
				Vector3(0.45, 0.45, 0.45))
	_asset(garden, FARM_CRATE_CARROT, &"GardenCarrotCrate", Vector3(-10.6, 0.05, 3.55),
		deg_to_rad(8.0), Vector3(0.78, 0.78, 0.78))
	_asset(garden, FARM_CRATE_APPLE, &"GardenProduceCrate", Vector3(-9.65, 0.05, 3.65),
		deg_to_rad(-12.0), Vector3(0.7, 0.7, 0.7))
	_asset(garden, WATERING_CAN, &"GardenWateringCan", Vector3(-5.25, 0.05, 2.8),
		deg_to_rad(-18.0), Vector3(0.72, 0.72, 0.72))
	_asset(garden, RUSTED_SPADE, &"GardenSpade", Vector3(-5.75, 0.05, 3.35),
		deg_to_rad(12.0), Vector3(0.78, 0.78, 0.78))
	_asset(garden, WOODEN_BUCKET, &"GardenBucket", Vector3(-5.0, 0.05, 3.45),
		0.0, Vector3(0.72, 0.72, 0.72))
	_asset(garden, WOODEN_CRATE, &"GardenWorkingCrate", Vector3(-6.1, 0.05, 3.55),
		deg_to_rad(9.0), Vector3(0.68, 0.68, 0.68))

	_asset(garden, TREE_SHRUB, &"GardenShrubNorthWest", Vector3(-10.8, 0.04, -3.7),
		deg_to_rad(15.0), Vector3(1.05, 1.05, 1.05))
	_asset(garden, TREE_SHRUB, &"GardenShrubSouthWest", Vector3(-10.9, 0.04, 3.75),
		deg_to_rad(-28.0), Vector3(0.9, 0.9, 0.9))
	_asset(garden, TREE_SHRUB, &"GardenShrubSouthEast", Vector3(-4.45, 0.04, 3.7),
		deg_to_rad(42.0), Vector3(0.82, 0.82, 0.82))
	# Imported rails match every authored collision span. The split north/east
	# sides keep their generous gates, so the garden reads as a destination rather
	# than a pen whose invisible rails surprise the player.
	_asset(garden, FENCE_WOOD, &"GardenFenceWestVisualNorth",
		Vector3(-11.45, 0.04, -2.2), PI * 0.5, Vector3(3.4, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceWestVisualSouth",
		Vector3(-11.45, 0.04, 2.15), PI * 0.5, Vector3(3.4, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceSouthVisualWest",
		Vector3(-9.55, 0.04, 4.25), 0.0, Vector3(3.2, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceSouthVisualEast",
		Vector3(-5.85, 0.04, 4.25), 0.0, Vector3(3.2, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceNorthVisualWest",
		Vector3(-10.15, 0.04, -4.25), 0.0, Vector3(2.3, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceNorthVisualEast",
		Vector3(-5.25, 0.04, -4.25), 0.0, Vector3(2.3, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceEastVisualNorth",
		Vector3(-3.95, 0.04, -2.7), PI * 0.5, Vector3(2.75, 0.72, 0.72))
	_asset(garden, FENCE_WOOD, &"GardenFenceEastVisualSouth",
		Vector3(-3.95, 0.04, 2.7), PI * 0.5, Vector3(2.75, 0.72, 0.72))


static func _build_practicals(art_pass: Node3D) -> void:
	var practicals := _group(art_pass, &"WarmThresholds")
	# Every occupied building announces itself with a small visible source and a
	# restrained pool at the threshold. Interiors remain the brightest warm zones.
	_practical(practicals, &"Barracks", Vector3(-13.28, 1.78, -12.4), -PI * 0.5, 8101)
	_practical(practicals, &"Mess", Vector3(-6.9, 1.78, -10.72), PI, 8102)
	_practical(practicals, &"Leader", Vector3(12.7, 1.82, -9.16), PI, 8103,
		1.45, 3.25)
	_practical(practicals, &"Smith", Vector3(-14.12, 1.78, -4.6), -PI * 0.5,
		8104, 1.55, 3.3, Color(1.0, 0.54, 0.27))
	_practical(practicals, &"Jewel", Vector3(-14.12, 1.76, 3.2), -PI * 0.5, 8105)
	_practical(practicals, &"Builder", Vector3(-12.62, 1.78, 11.1), -PI * 0.5, 8106)
	_practical(practicals, &"Quartermaster", Vector3(12.5, 1.78, 4.3), PI * 0.5,
		8107)
	_practical(practicals, &"WestSupply", Vector3(-9.2, 1.72, 11.48), 0.0,
		8108, 1.1, 2.8)
	_practical(practicals, &"EastSupply", Vector3(9.2, 1.72, 11.48), 0.0,
		8109, 1.1, 2.8)


static func _practical(
		parent: Node3D,
		practical_name: StringName,
		at: Vector3,
		yaw: float,
		seed: int,
		energy: float = 1.25,
		reach: float = 3.0,
		color: Color = Color(1.0, 0.72, 0.46)
	) -> void:
	_wall_torch(parent, StringName("%sThresholdTorch" % practical_name), at, yaw,
		seed, energy, reach, color)


static func _build_perimeter_torches(art_pass: Node3D) -> void:
	var torches := _group(art_pass, &"PerimeterTorches")
	var warm := Color(1.0, 0.68, 0.38)
	# The shoulder pair reads from both directions through the open six-metre
	# passage. The approach pair picks the arch out from the inner courtyard.
	_wall_torch(torches, &"GateShoulderWestTorch", Vector3(-2.55, 2.35, 15.55),
		PI * 0.5, 8201, 2.0, 5.2, warm, true, true)
	_wall_torch(torches, &"GateShoulderEastTorch", Vector3(2.55, 2.35, 15.55),
		-PI * 0.5, 8202, 2.0, 5.2, warm, true, true)
	_wall_torch(torches, &"GateApproachWestTorch", Vector3(-5.35, 2.35, 13.08),
		PI, 8203, 1.75, 4.8, warm, true)
	_wall_torch(torches, &"GateApproachEastTorch", Vector3(5.35, 2.35, 13.08),
		PI, 8204, 1.75, 4.8, warm, true)

	# Junction towers carry the rhythm around every turn in the irregular wall.
	_wall_torch(torches, &"NorthJunctionTorch", Vector3(3.1, 2.35, -17.22),
		0.0, 8210, 1.65, 4.8, warm)
	_wall_torch(torches, &"LeaderDoglegTorch", Vector3(19.28, 2.35, -9.35),
		-PI * 0.5, 8211, 1.65, 4.7, warm)
	_wall_torch(torches, &"EastStepTorch", Vector3(21.83, 2.35, -4.65),
		-PI * 0.5, 8212, 1.65, 4.7, warm)
	_wall_torch(torches, &"QuartermasterTurnTorch", Vector3(21.72, 2.35, 8.15),
		-PI * 0.5, 8213, 1.7, 4.9, warm)
	_wall_torch(torches, &"WestCraftTurnTorch", Vector3(-22.28, 2.35, 7.0),
		PI * 0.5, 8214, 1.65, 4.7, warm)
	_wall_torch(torches, &"WestMidTurnTorch", Vector3(-22.58, 2.35, -0.55),
		PI * 0.5, 8215, 1.65, 4.7, warm)

	# Courtyard-facing pockets bridge the longer dark gaps between destinations.
	_wall_torch(torches, &"NorthBarracksPocketTorch", Vector3(-13.62, 2.35, -17.0),
		PI * 0.5, 8220, 1.45, 4.5, warm)
	_wall_torch(torches, &"NorthLeaderPocketTorch", Vector3(9.75, 2.35, -9.48),
		0.0, 8221, 1.45, 4.5, warm)
	_wall_torch(torches, &"WestSupplyShoulderTorch", Vector3(-11.35, 2.3, 11.72),
		PI, 8222, 1.5, 4.6, warm)
	_wall_torch(torches, &"EastSupplyShoulderTorch", Vector3(11.55, 2.3, 11.72),
		PI, 8223, 1.5, 4.6, warm)


static func _wall_torch(
		parent: Node3D,
		torch_name: StringName,
		at: Vector3,
		yaw: float,
		seed: int,
		energy: float,
		reach: float,
		color: Color,
		gate: bool = false,
		embers: bool = false
	) -> KitTorch:
	var torch := KIT_TORCH.instantiate() as KitTorch
	if torch == null:
		push_error("GarrisonArtPass: KitTorch scene did not instantiate as KitTorch.")
		return null
	torch.name = torch_name
	torch.mode = KitTorch.Mode.SCONCE
	torch.position = at
	torch.rotation.y = yaw
	torch.rng_seed = seed
	torch.light_color = color
	torch.light_energy = energy
	torch.light_range = reach
	torch.light_attenuation = 1.75
	torch.flicker = 0.07
	torch.flicker_speed = 6.2
	torch.cast_shadow = false
	torch.embers = embers
	parent.add_child(torch)
	torch.add_to_group(&"garrison_wall_torch")
	if gate:
		torch.add_to_group(&"garrison_gate_torch")
	return torch


static func _build_night_fills(art_pass: Node3D) -> void:
	var fills := _group(art_pass, &"NightFills")
	var cool := Color(0.38, 0.52, 0.78)
	_night_fill(fills, &"GatePlazaFill", Vector3(0.0, 4.0, 10.0), 1.75, 14.0, cool)
	_night_fill(fills, &"WestCraftGardenFill", Vector3(-10.5, 3.0, 0.5),
		1.45, 14.5, cool)
	_night_fill(fills, &"NorthWingFill", Vector3(0.0, 4.0, -11.5),
		1.55, 16.0, cool)
	_night_fill(fills, &"EastQuartermasterFill", Vector3(12.5, 3.0, 3.5),
		1.45, 14.5, cool)
	_night_fill(fills, &"SupplyPocketFill", Vector3(0.0, 3.5, 13.5),
		1.25, 12.5, cool)


static func _night_fill(parent: Node3D, fill_name: StringName, at: Vector3,
		energy: float, reach: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = fill_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.05
	light.light_specular = 0.1
	light.shadow_enabled = false
	parent.add_child(light)
	light.add_to_group(&"garrison_night_fill")


static func _build_gate_mechanism(art_pass: Node3D) -> void:
	var mechanism := _group(art_pass, &"RaisedGateMechanism")
	_asset(mechanism, PULLEY, &"GateWinchPulleyWest", Vector3(-2.15, 4.65, 15.15),
		PI * 0.5, Vector3(0.78, 0.78, 0.78), MAT_IRON)
	_asset(mechanism, PULLEY, &"GateWinchPulleyEast", Vector3(2.15, 4.65, 15.15),
		-PI * 0.5, Vector3(0.78, 0.78, 0.78), MAT_IRON)
	_visual_box(mechanism, &"RaisedGateUpperCrossbar", Vector3(5.45, 0.16, 0.18),
		Vector3(0.0, 4.5, 15.28), MAT_IRON)
	_visual_box(mechanism, &"RaisedGateLowerCrossbar", Vector3(5.45, 0.13, 0.16),
		Vector3(0.0, 4.12, 15.28), MAT_IRON)
	_visual_box(mechanism, &"GateWinchRopeWest", Vector3(0.055, 0.72, 0.055),
		Vector3(-2.15, 4.38, 15.24), MAT_CEILING)
	_visual_box(mechanism, &"GateWinchRopeEast", Vector3(0.055, 0.72, 0.055),
		Vector3(2.15, 4.38, 15.24), MAT_CEILING)
	# The teeth remain visibly raised above head height and carry no collision;
	# raid actors still traverse the open arch instead of ghosting through a gate.
	for index: int in 9:
		_visual_box(mechanism, "RaisedGateTooth%02d" % (index + 1),
			Vector3(0.13, 0.82, 0.15),
			Vector3(-2.4 + float(index) * 0.6, 3.75, 15.28), MAT_IRON)


static func _build_gate_vista(art_pass: Node3D) -> void:
	var terrain_dressing := _group(art_pass, &"TerrainDressing")
	_asset(terrain_dressing, ROCK_1, &"WestCurtainRock", Vector3(-21.2, 0.03, -8.0),
		deg_to_rad(20.0), Vector3(0.85, 0.65, 0.8), MAT_MOSSY_ROCK)
	_asset(terrain_dressing, ROCK_3, &"BuilderCornerRock", Vector3(-21.0, 0.03, 8.4),
		deg_to_rad(-32.0), Vector3(0.72, 0.6, 0.8), MAT_MOSSY_ROCK)
	_asset(terrain_dressing, ROCK_6, &"NorthEastCornerRock", Vector3(20.7, 0.03, -10.7),
		deg_to_rad(46.0), Vector3(0.8, 0.7, 0.75), MAT_MOSSY_ROCK)
	_asset(terrain_dressing, ROCK_1, &"SouthEastCornerRock", Vector3(21.0, 0.03, 10.2),
		deg_to_rad(-8.0), Vector3(0.7, 0.55, 0.7), MAT_MOSSY_ROCK)
	_asset(terrain_dressing, TREE_SHRUB, &"WestCurtainShrub",
		Vector3(-21.3, 0.03, -6.8), deg_to_rad(35.0), Vector3(0.78, 0.78, 0.78))
	_asset(terrain_dressing, TREE_SHRUB, &"BuilderCornerShrub",
		Vector3(-21.1, 0.03, 7.5), deg_to_rad(-20.0), Vector3(0.9, 0.9, 0.9))
	_asset(terrain_dressing, TREE_SHRUB, &"QuartermasterCornerShrub",
		Vector3(21.1, 0.03, 9.1), deg_to_rad(12.0), Vector3(0.82, 0.82, 0.82))

	var vista := _group(art_pass, &"GateVista")
	# A broad, buried exterior apron guarantees the gate frames authored terrain
	# from every playable angle. The collision backstop remains inside the arch;
	# this surface is visual-only and cannot become an escape route.
	_visual_box(vista, &"VistaGround", Vector3(34.0, 0.24, 19.0),
		Vector3(0.0, -0.10, 27.0), MAT_DIRT)
	_ground_segment(vista, &"VistaRoadNear", Vector2(0.0, 18.45),
		Vector2(0.25, 21.8), 4.15, MAT_DIRT, 0.032)
	_ground_segment(vista, &"VistaRoadMiddle", Vector2(0.25, 21.6),
		Vector2(1.25, 25.0), 3.8, MAT_COBBLE, 0.034)
	_ground_segment(vista, &"VistaRoadBend", Vector2(1.2, 24.8),
		Vector2(2.45, 27.25), 3.4, MAT_DIRT, 0.036)

	# Buried earth fills only the gaps below the irregular rock silhouette.
	_visual_box(vista, &"VistaBermCenter", Vector3(10.5, 1.2, 3.6),
		Vector3(1.0, 0.18, 29.3), MAT_DIRT, deg_to_rad(3.0))
	_visual_box(vista, &"VistaBermWest", Vector3(10.0, 1.0, 3.8),
		Vector3(-8.6, 0.12, 29.8), MAT_DIRT, deg_to_rad(-8.0))
	_visual_box(vista, &"VistaBermEast", Vector3(10.5, 1.1, 3.8),
		Vector3(10.2, 0.14, 29.4), MAT_DIRT, deg_to_rad(11.0))

	_asset(vista, BOULDER_1, &"VistaBoulderCenterA", Vector3(-2.8, 0.0, 28.8),
		deg_to_rad(18.0), Vector3(3.0, 2.3, 2.6), MAT_MOSSY_ROCK)
	_asset(vista, BOULDER_5, &"VistaBoulderCenterB", Vector3(0.8, 0.15, 29.5),
		deg_to_rad(-27.0), Vector3(3.4, 2.7, 2.9), MAT_MOSSY_ROCK)
	_asset(vista, BOULDER_8, &"VistaBoulderCenterC", Vector3(4.2, -0.05, 28.5),
		deg_to_rad(41.0), Vector3(2.8, 2.15, 2.5), MAT_MOSSY_ROCK)
	_asset(vista, ROCK_3, &"VistaRockCenterFront", Vector3(2.1, 0.1, 27.5),
		deg_to_rad(-12.0), Vector3(2.15, 1.55, 1.8), MAT_MOSSY_ROCK)
	_asset(vista, ROCK_6, &"VistaRockCenterHigh", Vector3(-0.9, 1.05, 30.25),
		deg_to_rad(32.0), Vector3(2.25, 1.7, 1.9), MAT_MOSSY_ROCK)

	_asset(vista, BOULDER_8, &"VistaBoulderWestInner", Vector3(-6.4, 0.05, 29.2),
		deg_to_rad(-38.0), Vector3(2.8, 2.1, 2.7), MAT_MOSSY_ROCK)
	_asset(vista, BOULDER_5, &"VistaBoulderWestOuter", Vector3(-10.3, -0.1, 30.0),
		deg_to_rad(24.0), Vector3(3.6, 2.45, 3.0), MAT_MOSSY_ROCK)
	_asset(vista, ROCK_1, &"VistaRockWestEdge", Vector3(-13.5, 0.0, 28.4),
		deg_to_rad(55.0), Vector3(2.35, 1.65, 2.1), MAT_MOSSY_ROCK)
	_asset(vista, BOULDER_1, &"VistaBoulderEastInner", Vector3(7.0, 0.05, 29.5),
		deg_to_rad(35.0), Vector3(3.0, 2.2, 2.5), MAT_MOSSY_ROCK)
	_asset(vista, BOULDER_8, &"VistaBoulderEastOuter", Vector3(10.8, -0.05, 29.8),
		deg_to_rad(-18.0), Vector3(3.7, 2.55, 3.1), MAT_MOSSY_ROCK)
	_asset(vista, ROCK_3, &"VistaRockEastEdge", Vector3(14.0, 0.0, 28.7),
		deg_to_rad(-47.0), Vector3(2.4, 1.7, 2.15), MAT_MOSSY_ROCK)
	_asset(vista, TREE_SHRUB, &"VistaShrubWest", Vector3(-7.7, 0.05, 27.2),
		deg_to_rad(20.0), Vector3(1.25, 1.25, 1.25))
	_asset(vista, TREE_SHRUB, &"VistaShrubCenter", Vector3(5.4, 0.05, 27.4),
		deg_to_rad(-30.0), Vector3(1.1, 1.1, 1.1))
	_asset(vista, TREE_SHRUB, &"VistaShrubEast", Vector3(11.9, 0.05, 27.1),
		deg_to_rad(44.0), Vector3(1.3, 1.3, 1.3))


static func _group(parent: Node, group_name: StringName) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	parent.add_child(group)
	return group


static func _asset(
		parent: Node3D,
		scene: PackedScene,
		asset_name: StringName,
		at: Vector3,
		yaw: float = 0.0,
		asset_scale: Vector3 = Vector3.ONE,
		material_override: Material = null
	) -> Node3D:
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		push_error("GarrisonArtPass: '%s' did not instantiate as Node3D." % asset_name)
		return null
	instance.name = asset_name
	instance.position = at
	instance.rotation.y = yaw
	instance.scale = asset_scale
	_make_decorative(instance, material_override, _asset_casts_sun_shadow(scene))
	parent.add_child(instance)
	return instance


static func _asset_casts_sun_shadow(scene: PackedScene) -> bool:
	return (scene == BOULDER_1 or scene == BOULDER_5 or scene == BOULDER_8
		or scene == ROCK_1 or scene == ROCK_3 or scene == ROCK_6
		or scene == TREE_SHRUB or scene == FENCE_WOOD or scene == STRUCTURE_WALL)


static func _make_decorative(node: Node, material_override: Material,
		casts_sun_shadow: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if casts_sun_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if material_override != null:
			mesh_instance.material_override = material_override
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionPolygon3D:
		(node as CollisionPolygon3D).disabled = true
	for child: Node in node.get_children():
		_make_decorative(child, material_override, casts_sun_shadow)


static func _visual_box(
		parent: Node3D,
		box_name: StringName,
		size: Vector3,
		at: Vector3,
		material: Material,
		yaw: float = 0.0
	) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = box_name
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material
	visual.position = at
	visual.rotation.y = yaw
	parent.add_child(visual)
	return visual


static func _ground_segment(
		parent: Node3D,
		segment_name: StringName,
		from: Vector2,
		to: Vector2,
		width: float,
		material: Material,
		y: float = 0.04
	) -> MeshInstance3D:
	var delta := to - from
	var length := delta.length()
	var direction := delta / maxf(length, 0.001)
	var side := Vector2(-direction.y, direction.x)
	var steps := maxi(3, ceili(length / 1.15))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(segment_name.hash()) & 0x7fffffff
	var edges: Array[Vector2] = []
	for index: int in steps + 1:
		var t := float(index) / float(steps)
		var endpoint_fade := sin(t * PI)
		var center := from.lerp(to, t) + side * rng.randf_range(-0.13, 0.13) * endpoint_fade
		var half_width := width * 0.5 * rng.randf_range(0.88, 1.07)
		if index == 0 or index == steps:
			half_width *= 0.84
		edges.append(center - side * half_width)
		edges.append(center + side * half_width)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in steps:
		var left_a := edges[index * 2]
		var right_a := edges[index * 2 + 1]
		var left_b := edges[(index + 1) * 2]
		var right_b := edges[(index + 1) * 2 + 1]
		var v_start := float(index) / float(steps) * length * 0.32
		var v_end := float(index + 1) / float(steps) * length * 0.32
		_add_ground_vertex(surface, left_a, y, Vector2(0.0, v_start))
		_add_ground_vertex(surface, left_b, y, Vector2(0.0, v_end))
		_add_ground_vertex(surface, right_a, y, Vector2(width * 0.32, v_start))
		_add_ground_vertex(surface, right_a, y, Vector2(width * 0.32, v_start))
		_add_ground_vertex(surface, left_b, y, Vector2(0.0, v_end))
		_add_ground_vertex(surface, right_b, y, Vector2(width * 0.32, v_end))
	surface.generate_tangents()
	var segment := MeshInstance3D.new()
	segment.name = segment_name
	segment.mesh = surface.commit()
	segment.material_override = material
	parent.add_child(segment)
	return segment


static func _add_ground_vertex(surface: SurfaceTool, point: Vector2, y: float, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(Vector3(point.x, y, point.y))


static func _hide_named_visuals(compound: Node, names: Array[StringName]) -> void:
	for node: Node in compound.find_children("*", "", true, false):
		if not names.has(node.name):
			continue
		if node is MeshInstance3D:
			(node as MeshInstance3D).hide()
			continue
		for child: Node in node.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).hide()


static func _facade_panel(
		parent: Node3D,
		scene: PackedScene,
		panel_name: StringName,
		at: Vector3,
		yaw: float,
		panel_scale: Vector3
	) -> Node3D:
	return _asset(parent, scene, panel_name, at, yaw, panel_scale)


static func _column(
		parent: Node3D,
		column_name: StringName,
		at: Vector3,
		height: float
	) -> Node3D:
	return _asset(parent, COLUMN_WOOD, column_name, at, 0.0, Vector3(1.0, height, 1.0))


static func _door_frame(
		parent: Node3D,
		frame_name: StringName,
		first: Vector3,
		second: Vector3,
		height: float
	) -> void:
	_column(parent, StringName("%sColumnA" % frame_name), first, height)
	_column(parent, StringName("%sColumnB" % frame_name), second, height)
	var span := second - first
	var midpoint := (first + second) * 0.5 + Vector3.UP * height
	_visual_box(parent, StringName("%sLintel" % frame_name),
		Vector3(span.length() + 0.28, 0.20, 0.22), midpoint, MAT_CEILING,
		atan2(span.z, span.x))
