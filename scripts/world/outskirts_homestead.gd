class_name OutskirtsHomestead
extends Node3D
## Hand-authored set dressing and collision for the clearing between Highbridge
## and the Sunken Cut. Gameplay remains with GarrisonOutskirts: this component
## owns only the place -- terrain, water, silhouettes, paths, and stable sockets.

const MAT_GRASS := preload("res://assets/materials/mat_outskirts_grass.tres")
const MAT_PATH := preload("res://assets/materials/mat_outskirts_path.tres")
const MAT_CLIFF := preload("res://assets/materials/mat_outskirts_rock.tres")
const MAT_DARK_STONE := preload("res://assets/materials/mat_outskirts_rock.tres")
const MAT_WOOD := preload("res://assets/materials/mat_outskirts_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const WATER_SHADER: Shader = preload("res://assets/shaders/outskirts_water.gdshader")
const WATERFALL_SHADER: Shader = preload(
	"res://assets/shaders/outskirts_waterfall.gdshader")

const CAVE_MOUTH: PackedScene = preload(
	"res://assets/valenfeld/outskirts/cave_mouth.glb")
const TOOLSHED_MODEL: PackedScene = preload(
	"res://assets/valenfeld/outskirts/hearthstone_cottage.glb")
const LAMP_POST: PackedScene = preload(
	"res://assets/valenfeld/outskirts/lamp_post.glb")
const RUSTED_SPADE: PackedScene = preload(
	"res://assets/valenfeld/outskirts/rusted_spade.glb")
const WATERING_CAN: PackedScene = preload(
	"res://assets/valenfeld/outskirts/watering_can.glb")
const WOODEN_BARRELS: PackedScene = preload(
	"res://assets/valenfeld/outskirts/wooden_barrels.glb")
const WOODEN_BUCKET: PackedScene = preload(
	"res://assets/valenfeld/outskirts/wooden_bucket.glb")
const WOODEN_CRATE: PackedScene = preload(
	"res://assets/valenfeld/outskirts/wooden_crate.glb")
const BOULDERS: Array[PackedScene] = [
	preload("res://assets/valenfeld/outskirts/boulder_02.glb"),
	preload("res://assets/valenfeld/outskirts/boulder_03.glb"),
	preload("res://assets/valenfeld/outskirts/boulder_04.glb"),
	preload("res://assets/valenfeld/outskirts/boulder_05.glb"),
]
const FOREST_PINES: Array[PackedScene] = [
	preload("res://assets/valenfeld/outskirts/tree_pine_01.glb"),
	preload("res://assets/valenfeld/outskirts/tree_pine_04.glb"),
]
const FOREST_OAK: PackedScene = preload(
	"res://assets/valenfeld/outskirts/tree_oak_01.glb")
const TREE_STUMP: PackedScene = preload(
	"res://assets/valenfeld/outskirts/tree_stump.glb")
const WOODSMANS_AXE: PackedScene = preload(
	"res://assets/valenfeld/outskirts/woodsmans_axe.glb")
const FLOWERS: Array[PackedScene] = [
	preload("res://assets/valenfeld/outskirts/bellflower_blue.glb"),
	preload("res://assets/valenfeld/outskirts/daisy_white.glb"),
	preload("res://assets/valenfeld/outskirts/poppy_orange.glb"),
	preload("res://assets/valenfeld/outskirts/poppy_purple.glb"),
	preload("res://assets/valenfeld/outskirts/star_flower_white.glb"),
	preload("res://assets/valenfeld/outskirts/wildflower_spray_pink.glb"),
]
const UNDERGROWTH: Array[PackedScene] = [
	preload("res://assets/valenfeld/outskirts/meadow_grass_blades.glb"),
	preload("res://assets/valenfeld/outskirts/meadow_herb_tuft_a.glb"),
	preload("res://assets/valenfeld/outskirts/meadow_flower_white.glb"),
	preload("res://assets/valenfeld/outskirts/meadow_flower_yellow.glb"),
	preload("res://assets/valenfeld/outskirts/meadow_grass_wispy.glb"),
	preload("res://assets/valenfeld/outskirts/meadow_reed.glb"),
]

const CLEARING_CENTER := Vector3(0.0, 0.08, 0.0)
const GARRISON_APPROACH := Vector3(-29.2, 0.12, 22.4)
const GARRISON_THRESHOLD := Vector3(-32.0, 0.14, 24.4)
const BRIDGE_END := Vector3(-42.2, -0.18, 31.0)
const MINE_APPROACH := Vector3(27.2, 0.15, 22.9)
const MINE_MOUTH := Vector3(29.2, 0.18, 25.9)
const TOOLSHED_CENTER := Vector3(13.8, 0.05, -3.0)
const GARDEN_CENTER := Vector3(8.0, 0.06, -17.4)
const FISHING_CENTER := Vector3(27.0, 0.06, -2.5)
const SOUTH_POND_CENTER := Vector3(-0.5, 0.06, -27.0)
const GROVE_CENTER := Vector3(-18.0, 0.05, 6.0)

const SITE_HALF := Vector2(37.0, 32.0)
const PATH_WIDTH := 4.4
const POND_WATER_HEIGHT := 0.12

const PATH_SPINE: Array[Vector3] = [
	GARRISON_THRESHOLD,
	GARRISON_APPROACH,
	Vector3(-24.8, 0.10, 20.4),
	Vector3(-18.0, 0.10, 15.8),
	Vector3(-12.6, 0.09, 11.3),
	Vector3(-8.0, 0.09, 7.5),
	Vector3(-4.2, 0.08, 3.6),
	CLEARING_CENTER,
	Vector3(5.0, 0.09, 3.2),
	Vector3(10.5, 0.10, 7.6),
	Vector3(15.2, 0.10, 11.2),
	Vector3(21.0, 0.12, 17.0),
	MINE_APPROACH,
	MINE_MOUTH,
]

const DECORATIVE_TREE_POSITIONS: Array[Vector3] = [
	Vector3(-34.0, 0.0, 16.0), Vector3(-31.5, 0.0, 10.5),
	Vector3(-34.5, 0.0, 4.5), Vector3(-31.0, 0.0, -2.5),
	Vector3(-34.0, 0.0, -10.0), Vector3(-29.5, 0.0, -16.0),
	Vector3(-21.0, 0.0, 27.8), Vector3(-15.0, 0.0, 29.0),
	Vector3(-9.0, 0.0, 27.5), Vector3(-3.0, 0.0, 29.0),
	Vector3(5.0, 0.0, 29.2), Vector3(12.5, 0.0, 28.2),
	Vector3(18.5, 0.0, 27.8), Vector3(34.0, 0.0, 14.0),
	Vector3(34.5, 0.0, 6.5), Vector3(35.0, 0.0, -10.0),
	Vector3(32.0, 0.0, -18.0), Vector3(26.0, 0.0, -26.5),
	Vector3(18.0, 0.0, -29.0), Vector3(-14.0, 0.0, -29.0),
	Vector3(-22.0, 0.0, -25.5), Vector3(-31.5, 0.0, -21.0),
	Vector3(32.5, 0.0, 17.5), Vector3(21.5, 0.0, 29.0),
	Vector3(29.0, 0.0, -21.5), Vector3(10.0, 0.0, -28.5),
	Vector3(-7.0, 0.0, -29.0), Vector3(-35.0, 0.0, 17.5),
	Vector3(-27.4, 0.0, 32.2), Vector3(-25.5, 0.0, 30.0),
	Vector3(-18.0, 0.0, 32.0), Vector3(-11.5, 0.0, 31.5),
	Vector3(-5.5, 0.0, 33.0), Vector3(2.0, 0.0, 32.0),
	Vector3(9.0, 0.0, 29.2), Vector3(15.5, 0.0, 29.0),
	Vector3(34.0, 0.0, 20.5), Vector3(34.4, 0.0, 11.5),
	Vector3(34.7, 0.0, 2.0), Vector3(34.6, 0.0, -6.0),
	Vector3(35.0, 0.0, -15.0), Vector3(29.0, 0.0, -21.0),
	Vector3(22.0, 0.0, -28.3), Vector3(14.0, 0.0, -30.2),
	Vector3(4.0, 0.0, -31.0), Vector3(-16.0, 0.0, -32.5),
	Vector3(-25.0, 0.0, -29.0), Vector3(-33.5, 0.0, -24.0),
]

const FLOWER_POSITIONS: Array[Vector3] = [
	Vector3(-27.0, 0.0, 18.0), Vector3(-24.0, 0.0, 12.0),
	Vector3(-22.0, 0.0, 2.0), Vector3(-27.0, 0.0, -5.0),
	Vector3(-20.0, 0.0, -10.0), Vector3(-12.0, 0.0, -8.0),
	Vector3(-10.0, 0.0, 16.0), Vector3(-5.0, 0.0, 19.0),
	Vector3(-5.0, 0.0, -13.0), Vector3(1.0, 0.0, 15.0),
	Vector3(5.0, 0.0, 18.0), Vector3(8.0, 0.0, 13.0),
	Vector3(18.0, 0.0, 16.0), Vector3(22.0, 0.0, 11.0),
	Vector3(28.0, 0.0, 9.0), Vector3(21.0, 0.0, 1.0),
	Vector3(30.0, 0.0, -10.0), Vector3(23.0, 0.0, -14.0),
	Vector3(18.0, 0.0, -20.0), Vector3(14.0, 0.0, -26.0),
	Vector3(6.0, 0.0, -29.0), Vector3(-8.0, 0.0, -25.0),
	Vector3(-17.0, 0.0, -21.0), Vector3(-25.0, 0.0, -17.0),
]

# x, z, target height; negative height chooses the broad oak silhouette.
const DENSE_TREE_ROWS: Array[Vector3] = [
	Vector3(-32.5, 18.0, 8.9), Vector3(-28.0, 17.0, 7.2),
	Vector3(-26.0, 13.0, 9.4), Vector3(-23.0, 10.0, -6.4),
	Vector3(-32.0, 12.0, 8.0), Vector3(-28.0, 6.0, 9.1),
	Vector3(-24.0, 5.5, 6.0), Vector3(-31.0, 0.0, 8.8),
	Vector3(-27.0, -1.0, -7.0), Vector3(-23.0, -1.0, 9.5),
	Vector3(-18.0, -1.0, 7.8), Vector3(-31.0, -8.0, 8.1),
	Vector3(-26.5, -9.0, 9.3), Vector3(-21.0, -9.0, -6.4),
	Vector3(-17.0, -7.5, 8.7), Vector3(-32.0, -14.0, 7.4),
	Vector3(-27.0, -14.0, 9.0), Vector3(-21.5, -14.0, -6.2),
	Vector3(-16.0, -13.0, 8.6), Vector3(-17.5, 25.5, 7.5),
	Vector3(-12.0, 25.0, 9.0), Vector3(-6.5, 26.0, -7.0),
	Vector3(0.0, 26.0, 8.5), Vector3(6.5, 25.5, 6.2),
	Vector3(12.5, 24.5, 9.2), Vector3(17.0, 26.0, -7.6),
	Vector3(-15.0, -16.0, 8.4), Vector3(-20.0, -18.5, -6.8),
	Vector3(-25.0, -19.5, 9.1), Vector3(-28.0, -22.0, 7.2),
	Vector3(-13.0, -23.5, 9.0), Vector3(-11.0, -19.5, -5.8),
	Vector3(21.0, -15.0, -6.8), Vector3(22.0, -20.0, 8.7),
	Vector3(17.0, -26.0, 7.4), Vector3(25.0, -24.0, 9.3),
	Vector3(30.0, -18.0, -6.2), Vector3(20.5, 3.8, 7.0),
	Vector3(22.3, 6.3, 8.8), Vector3(29.5, 8.5, -6.4),
	Vector3(32.0, 3.5, 9.1),
]

const UNDERGROWTH_POSITIONS: Array[Vector3] = [
	Vector3(-33.0, 0.0, 21.0), Vector3(-30.0, 0.0, 15.0),
	Vector3(-32.0, 0.0, 7.0), Vector3(-30.0, 0.0, 0.0),
	Vector3(-31.0, 0.0, -7.0), Vector3(-29.0, 0.0, -14.0),
	Vector3(-20.0, 0.0, 23.0), Vector3(-13.0, 0.0, 24.0),
	Vector3(-7.0, 0.0, 22.0), Vector3(2.0, 0.0, 23.0),
	Vector3(11.0, 0.0, 23.0), Vector3(20.0, 0.0, 24.0),
	Vector3(32.0, 0.0, 17.0), Vector3(32.0, 0.0, 8.0),
	Vector3(32.0, 0.0, 0.0), Vector3(32.0, 0.0, -9.0),
	Vector3(29.0, 0.0, -17.0), Vector3(22.0, 0.0, -24.0),
	Vector3(12.0, 0.0, -29.0), Vector3(3.0, 0.0, -30.0),
	Vector3(-7.0, 0.0, -29.0), Vector3(-18.0, 0.0, -27.0),
	Vector3(-27.0, 0.0, -22.0), Vector3(-33.0, 0.0, -16.0),
]

var open_garrison_end: bool = false
var bridge_obstruction: Node3D
var mine_portal: Node3D
var toolshed_anchor: Node3D
var garden_anchor: Node3D
var central_statue: Statue
var scenic_water: Array[MeshInstance3D] = []

var _water_material: ShaderMaterial
var _river_water_material: ShaderMaterial
var _fishing_water_material: ShaderMaterial
var _scenic_pond_material: ShaderMaterial
var _soil_material: StandardMaterial3D
var _reed_material: StandardMaterial3D
var _mine_dark_material: StandardMaterial3D
var _ground_patch_material: StandardMaterial3D
var _crop_leaf_material: StandardMaterial3D
var _crop_ripe_material: StandardMaterial3D
var _path_material: StandardMaterial3D
var _harmonized_mesh_cache: Dictionary[String, Mesh] = {}
var _harmonized_material_cache: Dictionary[String, StandardMaterial3D] = {}
var _built: bool = false


func _ready() -> void:
	if _built:
		return
	_built = true
	_build()


func port(id: StringName) -> Transform3D:
	match id:
		&"arrival":
			return _facing(GARRISON_APPROACH, CLEARING_CENTER)
		&"garrison_gate":
			return _facing(GARRISON_THRESHOLD, BRIDGE_END)
		&"bridge_end", &"blocked_path":
			return _facing(BRIDGE_END + Vector3(1.3, 0.0, -0.8), BRIDGE_END)
		&"sunken_cut":
			return _facing(MINE_APPROACH, MINE_MOUTH)
		&"grove", &"timber_yard":
			return _facing(GROVE_CENTER, CLEARING_CENTER)
		&"fishing_hole":
			return _facing(FISHING_CENTER + Vector3(0.5, 0.0, 3.0),
				FISHING_CENTER + Vector3(0.5, 0.0, -2.25))
		&"clearing":
			return Transform3D(Basis.IDENTITY, CLEARING_CENTER)
		&"toolshed":
			return _facing(TOOLSHED_CENTER + Vector3(-5.0, 0.0, 1.0),
				TOOLSHED_CENTER)
		&"garden":
			return _facing(GARDEN_CENTER + Vector3(-2.0, 0.0, 7.0),
				GARDEN_CENTER)
		&"south_pond":
			return _facing(SOUTH_POND_CENTER + Vector3(0.0, 0.0, 7.0),
				SOUTH_POND_CENTER)
		&"vista_camera":
			var eye := Vector3(0.0, 55.0, 51.0)
			return Transform3D(Basis.IDENTITY, eye).looking_at(
				Vector3(0.0, 0.0, 1.0), Vector3.UP)
	push_error("OutskirtsHomestead: unknown port '%s'" % id)
	return Transform3D.IDENTITY


func _build() -> void:
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter(&"motion_amplitude", 0.025)
	_water_material.set_shader_parameter(&"motion_wavelength", 11.0)
	_water_material.set_shader_parameter(&"motion_speed", 0.28)
	_water_material.set_shader_parameter(&"flow_direction", Vector2(0.92, 0.38))
	_water_material.set_shader_parameter(&"fresnel_strength", 0.045)
	_water_material.set_shader_parameter(&"water_roughness", 0.74)
	_water_material.set_shader_parameter(&"water_specular", 0.12)
	_water_material.set_shader_parameter(&"deep_color", Vector3(0.045, 0.13, 0.14))
	_water_material.set_shader_parameter(&"body_color", Vector3(0.085, 0.22, 0.20))
	_water_material.set_shader_parameter(&"shallow_color", Vector3(0.16, 0.31, 0.24))
	# Rivers, fishing water, and the quiet south pond need different surface reads.
	# Sharing one shader keeps the language coherent; duplicated parameter sets stop
	# every body of water from reading like the same animated sheet.
	_river_water_material = _water_material.duplicate() as ShaderMaterial
	_river_water_material.set_shader_parameter(&"motion_amplitude", 0.030)
	_river_water_material.set_shader_parameter(&"motion_wavelength", 8.0)
	_river_water_material.set_shader_parameter(&"motion_speed", 0.46)
	_river_water_material.set_shader_parameter(&"flow_direction", Vector2(0.36, 0.93))
	_river_water_material.set_shader_parameter(&"fresnel_strength", 0.025)
	_river_water_material.set_shader_parameter(&"water_roughness", 0.82)
	_river_water_material.set_shader_parameter(&"water_specular", 0.08)
	_river_water_material.set_shader_parameter(&"deep_color", Vector3(0.035, 0.105, 0.12))
	_river_water_material.set_shader_parameter(&"body_color", Vector3(0.065, 0.17, 0.17))
	_river_water_material.set_shader_parameter(&"shallow_color", Vector3(0.12, 0.25, 0.21))

	_fishing_water_material = _water_material.duplicate() as ShaderMaterial
	_fishing_water_material.set_shader_parameter(&"motion_amplitude", 0.012)
	_fishing_water_material.set_shader_parameter(&"motion_wavelength", 15.0)
	_fishing_water_material.set_shader_parameter(&"motion_speed", 0.18)
	_fishing_water_material.set_shader_parameter(&"flow_direction", Vector2(0.78, -0.62))
	_fishing_water_material.set_shader_parameter(&"fresnel_strength", 0.045)
	_fishing_water_material.set_shader_parameter(&"water_roughness", 0.76)
	_fishing_water_material.set_shader_parameter(&"water_specular", 0.10)
	_fishing_water_material.set_shader_parameter(&"deep_color", Vector3(0.055, 0.14, 0.105))
	_fishing_water_material.set_shader_parameter(&"body_color", Vector3(0.10, 0.22, 0.15))
	_fishing_water_material.set_shader_parameter(&"shallow_color", Vector3(0.18, 0.32, 0.20))

	_scenic_pond_material = _water_material.duplicate() as ShaderMaterial
	_scenic_pond_material.set_shader_parameter(&"motion_amplitude", 0.018)
	_scenic_pond_material.set_shader_parameter(&"motion_wavelength", 12.0)
	_scenic_pond_material.set_shader_parameter(&"motion_speed", 0.22)
	_scenic_pond_material.set_shader_parameter(&"flow_direction", Vector2(-0.68, 0.73))
	_scenic_pond_material.set_shader_parameter(&"fresnel_strength", 0.05)
	_scenic_pond_material.set_shader_parameter(&"water_roughness", 0.72)
	_scenic_pond_material.set_shader_parameter(&"water_specular", 0.12)
	_scenic_pond_material.set_shader_parameter(&"deep_color", Vector3(0.045, 0.12, 0.125))
	_scenic_pond_material.set_shader_parameter(&"body_color", Vector3(0.08, 0.20, 0.18))
	_scenic_pond_material.set_shader_parameter(&"shallow_color", Vector3(0.15, 0.29, 0.22))

	_soil_material = _plain_material(Color(0.30, 0.18, 0.095), 0.94)
	_reed_material = _plain_material(Color(0.34, 0.40, 0.18), 0.94)
	_mine_dark_material = _plain_material(Color(0.035, 0.045, 0.065), 0.96)
	_ground_patch_material = _plain_material(Color(0.28, 0.34, 0.15), 0.95)
	_crop_leaf_material = _plain_material(Color(0.22, 0.42, 0.12), 0.92)
	_crop_ripe_material = _plain_material(Color(0.58, 0.34, 0.095), 0.86)
	_path_material = MAT_PATH

	var terrain := _group(self, &"Terrain")
	var water := _group(self, &"Water")
	var cliffs := _group(self, &"Cliffs")
	var landmarks := _group(self, &"Landmarks")
	var vegetation := _group(self, &"Vegetation")
	var details := _group(self, &"Details")

	_build_ground(terrain)
	_build_ground_patches(terrain)
	_build_paths(terrain)
	_build_water(water)
	_build_waterfalls(water)
	_build_boundaries(cliffs)
	_build_bridge(landmarks)
	_build_mine(landmarks)
	_build_central_clearing(landmarks)
	_build_toolshed(landmarks)
	_build_garden(landmarks)
	_build_fishing_docks(landmarks)
	_build_decorative_trees(vegetation)
	_build_logging_detail(vegetation)
	_build_meadow(vegetation)
	_build_rock_detail(details)
	_build_lighting(details)


func _build_ground(parent: Node3D) -> void:
	_box(parent, &"HomesteadGroundCollision", null,
		Vector3(SITE_HALF.x * 2.0, 0.9, SITE_HALF.y * 2.0),
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.45, 0.0)), true)
	var perimeter := PackedVector2Array([
		Vector2(-35.5, -21.0), Vector2(-29.0, -28.5),
		Vector2(-17.0, -32.0), Vector2(-2.0, -33.0),
		Vector2(14.0, -31.5), Vector2(28.0, -27.0),
		Vector2(35.0, -18.0), Vector2(37.0, -5.0),
		Vector2(36.0, 10.0), Vector2(32.5, 23.0),
		Vector2(27.0, 30.0), Vector2(13.0, 32.0),
		Vector2(-3.0, 32.0), Vector2(-18.0, 30.0),
		Vector2(-29.0, 27.0), Vector2(-35.0, 18.0),
		Vector2(-37.0, 3.0), Vector2(-37.0, -11.0),
	])
	_polygon_surface(parent, &"HomesteadGround", MAT_GRASS, perimeter,
		Vector3(0.0, 0.015, 0.0))


func _build_paths(parent: Node3D) -> void:
	for i: int in PATH_SPINE.size() - 1:
		_path_segment(parent, PATH_SPINE[i], PATH_SPINE[i + 1], PATH_WIDTH,
			StringName("MainPath%02d" % i))
	for branch: Dictionary in [
		{&"a": CLEARING_CENTER, &"b": TOOLSHED_CENTER + Vector3(-2.8, 0.0, 1.0),
			&"w": 3.3},
		{&"a": CLEARING_CENTER + Vector3(2.0, 0.0, -3.0),
			&"b": GARDEN_CENTER + Vector3(-1.0, 0.0, 5.5), &"w": 3.2},
		{&"a": CLEARING_CENTER + Vector3(5.0, 0.0, -1.0),
			&"b": TOOLSHED_CENTER + Vector3(-3.3, 0.0, 0.8), &"w": 3.0},
		{&"a": TOOLSHED_CENTER + Vector3(3.8, 0.0, -0.2),
			&"b": FISHING_CENTER + Vector3(0.5, 0.0, 3.0), &"w": 2.8},
		{&"a": GARDEN_CENTER + Vector3(0.0, 0.0, -5.8),
			&"b": SOUTH_POND_CENTER + Vector3(2.0, 0.0, 5.0), &"w": 2.7},
		{&"a": Vector3(-11.0, 0.0, 8.0),
			&"b": GROVE_CENTER + Vector3(0.0, 0.0, -1.0), &"w": 3.0},
	]:
		_path_segment(parent, branch[&"a"], branch[&"b"], branch[&"w"],
			&"BranchPath")
	_cylinder(parent, &"CentralPathRound", _path_material, 6.35, 0.06,
		Transform3D(Basis.IDENTITY, CLEARING_CENTER + Vector3.UP * 0.04), false, 24)


func _build_ground_patches(parent: Node3D) -> void:
	var patches: Array[Vector4] = [
		Vector4(-27.0, 12.0, 7.5, 3.3), Vector4(-20.0, 4.0, 8.0, 3.8),
		Vector4(-26.0, -5.0, 7.0, 3.0), Vector4(-15.0, 18.0, 5.0, 2.7),
		Vector4(18.0, 17.0, 4.5, 2.4), Vector4(27.0, 9.0, 5.0, 2.6),
		Vector4(22.0, -13.0, 5.5, 2.9), Vector4(-16.0, -19.0, 5.0, 2.4),
	]
	for i: int in patches.size():
		var row := patches[i]
		_irregular_disc(parent, StringName("MossPatch%02d" % i),
			_ground_patch_material, Vector2(row.z, row.w),
			Vector3(row.x, 0.027, row.y), 18, float(i) * 0.83)


func _build_water(parent: Node3D) -> void:
	# Three separated channels establish a gorge without turning the playable
	# meadow into an island. Their inner banks stay outside the authored tree
	# line, while the west ribbon still reaches the river-fishing dock.
	_water_ribbon(parent, &"WestRiver", PackedVector2Array([
		Vector2(-39.6, -24.0), Vector2(-41.7, -15.0),
		Vector2(-41.2, -4.0), Vector2(-41.9, 7.5),
		Vector2(-40.4, 17.0), Vector2(-37.5, 23.0),
	]), 5.0, Vector3(0.0, -0.22, 0.0), _river_water_material, 0.47, true)
	_water_ribbon(parent, &"SouthRiver", PackedVector2Array([
		Vector2(-32.5, -32.6), Vector2(-23.0, -36.0),
		Vector2(-11.0, -37.2), Vector2(2.0, -37.0),
		Vector2(15.0, -35.8), Vector2(26.5, -31.6),
		Vector2(33.0, -25.0),
	]), 5.2, Vector3(0.0, -0.23, 0.0), _river_water_material, 1.31)
	_water_ribbon(parent, &"EastGorge", PackedVector2Array([
		Vector2(34.0, -25.0), Vector2(39.5, -17.0),
		Vector2(41.0, -7.0), Vector2(41.1, 4.0),
		Vector2(39.6, 15.0), Vector2(35.5, 24.5),
		Vector2(27.0, 30.5), Vector2(16.0, 33.5),
		Vector2(7.0, 35.2),
	]), 5.0, Vector3(0.0, -0.21, 0.0), _river_water_material, 2.17)
	_build_pond(parent, &"EastFishingPond",
		FISHING_CENTER + Vector3(0.5, 0.0, -2.25),
		Vector2(15.0, 10.5), 18, _fishing_water_material)
	_build_pond(parent, &"SouthFishingPond", SOUTH_POND_CENTER,
		Vector2(16.0, 10.0), 20, _scenic_pond_material)


func _build_waterfalls(parent: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = WATERFALL_SHADER
	material.set_shader_parameter(&"base_color", Vector3(0.09, 0.22, 0.21))
	material.set_shader_parameter(&"body_band_color", Vector3(0.16, 0.33, 0.29))
	material.set_shader_parameter(&"foam_color", Vector3(0.56, 0.64, 0.55))
	material.set_shader_parameter(&"scroll_speed", 0.62)
	material.set_shader_parameter(&"water_roughness", 0.78)
	material.set_shader_parameter(&"water_specular", 0.10)
	for row: Vector4 in [Vector4(35.6, 15.0, 3.5, 6.4),
			Vector4(7.0, 34.8, 2.4, 4.6)]:
		var fall := MeshInstance3D.new()
		fall.name = &"GorgeWaterfall"
		var quad := QuadMesh.new()
		quad.size = Vector2(row.z, row.w)
		fall.mesh = quad
		fall.material_override = material
		fall.position = Vector3(row.x, row.w * 0.5 - 0.18, row.y)
		fall.rotation.y = PI * 0.5 if absf(row.x) > 30.0 else 0.0
		parent.add_child(fall)


func _build_pond(parent: Node3D, pond_name: StringName, centre: Vector3,
		size: Vector2, rocks: int, water_material: ShaderMaterial) -> void:
	var pond := _group(parent, pond_name)
	pond.position = centre
	_irregular_disc(pond, &"DarkBasin", MAT_DARK_STONE, size * 0.53,
		Vector3(0.0, -0.03, 0.0), 28, float(pond_name.hash()) * 0.0001)
	_irregular_water(pond, &"Surface", water_material, size * 0.48,
		Vector3(0.0, POND_WATER_HEIGHT, 0.0), 32,
		float(pond_name.hash()) * 0.0001)
	_build_pond_barrier(pond, size, rocks)
	for i: int in rocks:
		var angle := TAU * float(i) / float(rocks) + sin(float(i) * 2.4) * 0.07
		if absf(wrapf(angle - PI * 0.5, -PI, PI)) < 0.38:
			continue
		var radius_x := size.x * 0.50
		var radius_z := size.y * 0.50
		var position := Vector3(cos(angle) * radius_x, 0.04,
			sin(angle) * radius_z)
		_model(pond, StringName("BankRock%02d" % i), BOULDERS[i % BOULDERS.size()],
			position, angle, Vector3.ONE * (0.55 + float(i % 4) * 0.08))
	for i: int in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		_cylinder(pond, StringName("Reed%02d" % i), _reed_material,
			0.035, 0.75 + float(i % 3) * 0.12,
			Transform3D(Basis(Vector3.UP, float(i) * 0.8),
				Vector3(side * size.x * 0.37 + float(i % 3) * 0.22,
					0.38, -size.y * 0.37 + float(i) * 0.22)), false, 6)


func _build_pond_barrier(parent: Node3D, size: Vector2, segments: int) -> void:
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		if absf(wrapf(angle - PI * 0.5, -PI, PI)) < 0.34:
			continue
		var radius := Vector2(size.x * 0.49, size.y * 0.49)
		var point := Vector3(cos(angle) * radius.x, 0.48,
			sin(angle) * radius.y)
		var arc := TAU * maxf(radius.x, radius.y) / float(segments)
		_box(parent, &"BankCollision", null, Vector3(arc * 0.78, 1.1, 0.75),
			Transform3D(Basis(Vector3.UP, -angle), point), true)


func _build_boundaries(parent: Node3D) -> void:
	# Collision follows the authored shoreline instead of a submerged rectangle.
	var boundary := PackedVector3Array([
		Vector3(-35.5, 0.0, -21.0), Vector3(-29.0, 0.0, -28.5),
		Vector3(-17.0, 0.0, -32.0), Vector3(-2.0, 0.0, -33.0),
		Vector3(14.0, 0.0, -31.5), Vector3(28.0, 0.0, -27.0),
		Vector3(35.0, 0.0, -18.0), Vector3(37.0, 0.0, -5.0),
		Vector3(36.0, 0.0, 10.0), Vector3(32.5, 0.0, 23.0),
		Vector3(27.0, 0.0, 30.0), Vector3(13.0, 0.0, 32.0),
		Vector3(-3.0, 0.0, 32.0), Vector3(-18.0, 0.0, 30.0),
		Vector3(-29.0, 0.0, 27.0), Vector3(-35.0, 0.0, 18.0),
		Vector3(-37.0, 0.0, 3.0), Vector3(-37.0, 0.0, -11.0),
	])
	for i: int in boundary.size():
		var a := boundary[i]
		var b := boundary[(i + 1) % boundary.size()]
		# The northwest aperture is the only route through the gorge wall.
		if (a.z >= 18.0 and b.z >= 18.0 and minf(a.x, b.x) < -28.0):
			continue
		var delta := b - a
		var yaw := atan2(delta.x, delta.z)
		_box(parent, &"ShorelineCollision", null,
			Vector3(1.3, 4.6, delta.length() + 0.8),
			Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3.UP * 1.7), true)

	# Broad stone terraces sit beneath the loose boulder language. The missing
	# northwest run preserves Highbridge as a deliberate aperture rather than a
	# break in a visibly repeated ring.
	var shelf_runs: Array[Vector4] = [
		Vector4(-27.0, -29.2, 9.5, -0.95), Vector4(-13.0, -32.4, 10.0, -1.42),
		Vector4(3.0, -32.8, 11.0, -1.62), Vector4(20.0, -29.2, 10.0, -2.02),
		Vector4(33.0, -19.0, 8.0, -2.72), Vector4(36.0, -3.5, 10.0, PI),
		Vector4(34.2, 15.5, 9.0, 2.75), Vector4(23.0, 29.0, 10.0, 2.02),
		Vector4(7.0, 31.5, 11.0, 1.58), Vector4(-10.0, 30.5, 9.0, 1.43),
		Vector4(-35.2, 7.0, 10.0, 0.05), Vector4(-34.0, -12.5, 9.0, 0.36),
	]
	for i: int in shelf_runs.size():
		var row := shelf_runs[i]
		var point := Vector3(row.x, 0.0, row.y)
		var outward := Vector3(point.x, 0.0, point.z).normalized()
		var lower := _group(parent, StringName("LowerCliffShelf%02d" % i))
		lower.position = point + outward * 0.55
		lower.rotation.y = row.w
		_irregular_disc(lower, &"StoneShelf", MAT_CLIFF,
			Vector2(row.z * 0.52, 2.1 + float(i % 3) * 0.30),
			Vector3(0.0, -0.10, 0.0), 18, float(i) * 0.61)
		if i % 3 != 1:
			var upper := _group(parent, StringName("UpperCliffShelf%02d" % i))
			upper.position = point + outward * 2.0 + Vector3.UP * 0.32
			upper.rotation.y = row.w + sin(float(i) * 1.7) * 0.09
			_irregular_disc(upper, &"StoneShelf", MAT_CLIFF,
				Vector2(row.z * 0.36, 1.55 + float(i % 2) * 0.25),
				Vector3.ZERO, 16, float(i) * 0.93 + 0.4)

	# Rocks are grouped into geological shelves instead of evenly spaced edging.
	var visual_positions: Array[Vector3] = [
		Vector3(-33.0, 0.0, -20.5), Vector3(-30.0, 0.0, -25.0),
		Vector3(-24.0, 0.0, -29.0), Vector3(-18.0, 0.0, -31.0),
		Vector3(-7.0, 0.0, -32.3), Vector3(2.0, 0.0, -32.7),
		Vector3(14.0, 0.0, -31.0), Vector3(25.0, 0.0, -27.5),
		Vector3(32.0, 0.0, -22.0), Vector3(36.0, 0.0, -15.0),
		Vector3(36.5, 0.0, -6.0), Vector3(36.3, 0.0, 4.0),
		Vector3(35.0, 0.0, 13.0), Vector3(32.5, 0.0, 22.0),
		Vector3(27.0, 0.0, 29.5), Vector3(17.0, 0.0, 31.5),
		Vector3(6.0, 0.0, 32.0), Vector3(-4.0, 0.0, 32.0),
		Vector3(-16.0, 0.0, 30.5), Vector3(-36.0, 0.0, 12.0),
		Vector3(-37.0, 0.0, 2.0), Vector3(-36.5, 0.0, -9.0),
	]
	for i: int in visual_positions.size():
		var point := visual_positions[i]
		var scale := Vector3(1.35 + float(i % 3) * 0.25,
			1.05 + float(i % 4) * 0.18, 1.45 + float((i + 2) % 3) * 0.22)
		_model(parent, StringName("CliffBoulder%02d" % i),
			BOULDERS[i % BOULDERS.size()], point - Vector3.UP * 0.28,
			float(i) * 0.71, scale)
		if i % 2 == 0:
			var outward := Vector3(signf(point.x), 0.0, signf(point.z)).normalized()
			_model(parent, StringName("CliffCrown%02d" % i),
				BOULDERS[(i + 2) % BOULDERS.size()],
				point + outward * 1.2 + Vector3.UP * (0.25 + float(i % 3) * 0.16),
				float(i) * -0.48, Vector3.ONE * (0.95 + float(i % 3) * 0.18))
	_build_mine_cliff(parent)


func _build_mine_cliff(parent: Node3D) -> void:
	# A broad, stepped northern wall makes the Sunken Cut an actual cut into land.
	for row: Dictionary in [
		{&"p": Vector3(23.7, 1.0, 28.6), &"s": Vector3(2.7, 2.5, 2.2), &"y": 0.2},
		{&"p": Vector3(20.0, 0.6, 30.0), &"s": Vector3(2.2, 2.0, 2.5), &"y": 1.1},
		{&"p": Vector3(16.0, 0.4, 30.6), &"s": Vector3(2.0, 1.6, 2.2), &"y": 2.0},
		{&"p": Vector3(34.0, 1.0, 27.0), &"s": Vector3(2.8, 2.5, 2.5), &"y": 0.8},
		{&"p": Vector3(36.0, 0.6, 23.0), &"s": Vector3(2.3, 2.0, 2.6), &"y": 1.7},
	]:
		_model(parent, &"MineCliffMass", BOULDERS[int(row[&"y"] * 10.0) % BOULDERS.size()],
			row[&"p"], row[&"y"], row[&"s"])


func _build_bridge(parent: Node3D) -> void:
	var bridge := _group(parent, &"GarrisonBridge")
	var delta := BRIDGE_END - GARRISON_THRESHOLD
	var direction := delta.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var yaw := atan2(direction.x, direction.z)
	var length := delta.length()
	var count := int(ceil(length / 0.62))
	for i: int in count:
		var t := (float(i) + 0.5) / float(count)
		var position := GARRISON_THRESHOLD.lerp(BRIDGE_END, t)
		_box(bridge, StringName("BridgePlank%02d" % i), MAT_WOOD,
			Vector3(4.2, 0.18, 0.52),
			Transform3D(Basis(Vector3.UP, yaw), position), false)
	for side: float in [-1.0, 1.0]:
		for i: int in 6:
			var t := float(i) / 5.0
			var position := GARRISON_THRESHOLD.lerp(BRIDGE_END, t) \
				+ right * side * 2.0
			_cylinder(bridge, &"RailPost", MAT_WOOD, 0.11, 1.35,
				Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.58), true, 8)
		var rail_mid := (GARRISON_THRESHOLD + BRIDGE_END) * 0.5 \
			+ right * side * 2.0 + Vector3.UP * 0.92
		_box(bridge, &"BridgeRail", MAT_WOOD, Vector3(0.16, 0.16, length),
			Transform3D(Basis(Vector3.UP, yaw), rail_mid), true)
	# Unlike the stepped horizontal planks, one horizontal collision box leaves a
	# controller-catching end face wherever the endpoints differ in Y. Pitch the
	# hidden deck through both authored endpoints so its walk surface follows them.
	var deck_center := (GARRISON_THRESHOLD + BRIDGE_END) * 0.5 - Vector3.UP * 0.06
	var deck_basis := Basis.looking_at(delta.normalized(), Vector3.UP)
	_box(bridge, &"BridgeDeckCollision", null, Vector3(4.3, 0.18, length),
		Transform3D(deck_basis, deck_center), true)

	if open_garrison_end:
		# The authored fort slab and bridge deck meet at the same mathematical edge.
		# A capsule can catch on that zero-overlap contact even though no ray sees a
		# wall, so carry the bridge floor beneath the final plank into the gate slab.
		_box(bridge, &"BridgeGateSeamCollision", null, Vector3(4.3, 0.30, 1.4),
			Transform3D(Basis(Vector3.UP, yaw),
				BRIDGE_END + direction * 0.55 - Vector3.UP * 0.05), true)
		return
	bridge_obstruction = _group(bridge, &"BridgeBoundary")
	bridge_obstruction.position = BRIDGE_END + direction * 0.2
	bridge_obstruction.rotation.y = yaw
	_box(bridge_obstruction, &"CrossTimberA", MAT_WOOD, Vector3(4.8, 0.24, 0.28),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(24.0)),
			Vector3(0.0, 1.15, 0.0)), false)
	_box(bridge_obstruction, &"CrossTimberB", MAT_WOOD, Vector3(4.8, 0.24, 0.28),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-24.0)),
			Vector3(0.0, 1.15, 0.08)), false)
	_box(bridge_obstruction, &"BoundaryCollision", null, Vector3(5.0, 3.0, 0.8),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, 0.0)), true)


func _build_mine(parent: Node3D) -> void:
	mine_portal = _group(parent, &"SunkenCutMine")
	mine_portal.position = MINE_MOUTH
	# The imported landmark supplies the rock silhouette; the timber and darkness
	# make the playable entrance readable even before its materials finish warming.
	_model(mine_portal, &"CaveMouthModel", CAVE_MOUTH,
		Vector3(0.0, 2.85, 1.6), PI, Vector3(5.8, 5.8, 4.6))
	_cylinder(mine_portal, &"MineDarknessArch", _mine_dark_material, 1.85, 0.20,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(0.0, 2.35, 0.35)), false, 28)
	_box(mine_portal, &"MineDarknessLower", _mine_dark_material,
		Vector3(3.65, 2.35, 0.20),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, 0.35)), false)
	_box(mine_portal, &"MineInteriorCollision", null, Vector3(5.2, 5.0, 0.7),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.4, -0.15)), true)
	for side: float in [-1.0, 1.0]:
		_box(mine_portal, &"MinePost", MAT_WOOD, Vector3(0.38, 4.25, 0.44),
			Transform3D(Basis(Vector3.FORWARD, side * 0.04),
				Vector3(side * 2.35, 2.0, -0.75)), false)
	_box(mine_portal, &"MineLintel", MAT_WOOD, Vector3(5.35, 0.42, 0.48),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, -0.75)), false)
	for i: int in 8:
		var t := float(i) / 7.0
		var position := MINE_APPROACH.lerp(MINE_MOUTH + Vector3(0.0, 0.0, -1.0), t)
		var direction := (MINE_MOUTH - MINE_APPROACH).normalized()
		var yaw := atan2(direction.x, direction.z)
		_box(parent, &"MineSleeper", MAT_WOOD, Vector3(2.7, 0.12, 0.28),
			Transform3D(Basis(Vector3.UP, yaw), position + Vector3.UP * 0.10), false)
	for side: float in [-1.0, 1.0]:
		_var_rail(parent, side)
	_model(parent, &"MineCrateA", WOODEN_CRATE,
		MINE_MOUTH + Vector3(-5.0, 0.0, -2.5), 0.4, Vector3.ONE * 1.25)
	_model(parent, &"MineBarrelA", WOODEN_BARRELS,
		MINE_MOUTH + Vector3(5.0, 0.0, -2.0), -0.25, Vector3.ONE * 0.38)


func _var_rail(parent: Node3D, side: float) -> void:
	var a := MINE_APPROACH
	var b := MINE_MOUTH + Vector3(0.0, 0.0, -1.0)
	var direction := (b - a).normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var midpoint := (a + b) * 0.5 + right * side * 0.72 + Vector3.UP * 0.18
	var yaw := atan2(direction.x, direction.z)
	_box(parent, &"MineRail", MAT_IRON, Vector3(0.10, 0.10, a.distance_to(b)),
		Transform3D(Basis(Vector3.UP, yaw), midpoint), false)


func _build_central_clearing(parent: Node3D) -> void:
	var clearing := _group(parent, &"CentralClearing")
	clearing.position = CLEARING_CENTER
	central_statue = Statue.new()
	central_statue.name = &"LanternbearerStatue"
	central_statue.scale = Vector3.ONE * 0.78
	central_statue.position = Vector3(0.0, 0.02, 0.0)
	clearing.add_child(central_statue)
	_build_campfire(clearing, Vector3(0.0, 0.0, -3.6))
	for row: Dictionary in [
		{&"p": Vector3(-4.3, 0.18, -2.8), &"y": 0.35},
		{&"p": Vector3(4.3, 0.18, -2.8), &"y": -0.35},
		{&"p": Vector3(-4.2, 0.18, 3.1), &"y": 2.75},
		{&"p": Vector3(4.2, 0.18, 3.1), &"y": -2.75},
	]:
		_build_bench(clearing, row[&"p"], row[&"y"])
	for i: int in 16:
		if i in [1, 2, 5, 6, 13, 14, 15]:
			continue
		var angle := TAU * float(i) / 16.0
		var point := Vector3(cos(angle) * 7.35, 0.0, sin(angle) * 7.35)
		_build_short_fence(clearing, point, -angle + PI * 0.5, 2.6)


func _build_campfire(parent: Node3D, position: Vector3) -> void:
	var fire := _group(parent, &"Campfire")
	fire.position = position
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		_model(fire, &"FireRingRock", BOULDERS[i % BOULDERS.size()],
			Vector3(cos(angle) * 0.72, 0.05, sin(angle) * 0.72), angle,
			Vector3.ONE * 0.24)
	for angle: float in [-0.58, 0.58]:
		_box(fire, &"FireLog", MAT_WOOD, Vector3(0.24, 0.24, 1.55),
			Transform3D(Basis(Vector3.UP, angle), Vector3(0.0, 0.22, 0.0)), false)
	var flame_material := _plain_material(Color(0.95, 0.31, 0.06), 0.45)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.18, 0.02)
	flame_material.emission_energy_multiplier = 2.0
	_cylinder(fire, &"Flame", flame_material, 0.25, 0.75,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, 0.0)), false, 7)
	var light := OmniLight3D.new()
	light.name = &"FireLight"
	light.position = Vector3(0.0, 1.0, 0.0)
	light.light_color = Color(1.0, 0.43, 0.18)
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.shadow_enabled = false
	fire.add_child(light)


func _build_toolshed(parent: Node3D) -> void:
	toolshed_anchor = _group(parent, &"Toolshed")
	toolshed_anchor.position = TOOLSHED_CENTER
	toolshed_anchor.rotation.y = -0.35
	_model(toolshed_anchor, &"ToolshedModel", TOOLSHED_MODEL,
		Vector3(0.0, 2.7, 0.0), PI, Vector3(3.55, 2.85, 3.3))
	_box(toolshed_anchor, &"ToolshedCollision", null, Vector3(6.2, 4.9, 5.7),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.35, 0.0)), true)
	_model(toolshed_anchor, &"ToolBarrels", WOODEN_BARRELS,
		Vector3(4.2, 0.05, 1.6), 0.2, Vector3.ONE * 0.62)
	_model(toolshed_anchor, &"ToolCrate", WOODEN_CRATE,
		Vector3(-4.0, 0.05, 1.8), -0.4, Vector3.ONE * 1.35)
	_model(toolshed_anchor, &"ToolSpade", RUSTED_SPADE,
		Vector3(-3.1, 0.58, 2.9), 0.2, Vector3.ONE * 1.2)


func _build_garden(parent: Node3D) -> void:
	garden_anchor = _group(parent, &"Garden")
	garden_anchor.position = GARDEN_CENTER
	# Four stable plot sockets visually match issue #189 without owning its state.
	for row: int in 2:
		for column: int in 2:
			var plot := _group(garden_anchor,
				StringName("PlotSocket%d%d" % [row, column]))
			plot.position = Vector3(-3.2 + float(column) * 6.4, 0.10,
				-2.1 + float(row) * 4.2)
			_box(plot, &"Soil", _soil_material, Vector3(5.0, 0.18, 2.9),
				Transform3D.IDENTITY, false)
			for furrow: int in 5:
				_box(plot, &"Furrow", MAT_WOOD, Vector3(0.08, 0.06, 2.55),
					Transform3D(Basis.IDENTITY,
						Vector3(-2.0 + float(furrow), 0.11, 0.0)), false)
				for seedling: int in 3:
					var plant_position := Vector3(-2.0 + float(furrow), 0.25,
						-0.8 + float(seedling) * 0.8)
					_cylinder(plot, &"CropStem", _crop_leaf_material, 0.055, 0.48,
						Transform3D(Basis.IDENTITY, plant_position), false, 6)
					_cylinder(plot, &"CropLeaf", _crop_leaf_material, 0.15, 0.32,
						Transform3D(Basis(Vector3.FORWARD,
							(-0.55 if seedling % 2 == 0 else 0.55)),
							plant_position + Vector3(0.0, 0.10, 0.0)), false, 6)
					if (row + column + furrow + seedling) % 4 == 0:
						_cylinder(plot, &"RipeCrop", _crop_ripe_material, 0.10, 0.20,
							Transform3D(Basis.IDENTITY,
								plant_position + Vector3.UP * 0.28), false, 7)
	for side: float in [-1.0, 1.0]:
		_build_short_fence(garden_anchor, Vector3(side * 7.3, 0.0, 0.0),
			PI * 0.5, 10.8)
	_build_short_fence(garden_anchor, Vector3(-5.1, 0.0, -5.4), 0.0, 4.4)
	_build_short_fence(garden_anchor, Vector3(4.8, 0.0, -5.4), 0.0, 5.0)
	_build_short_fence(garden_anchor, Vector3(-4.7, 0.0, 5.4), 0.0, 5.0)
	_build_short_fence(garden_anchor, Vector3(4.7, 0.0, 5.4), 0.0, 5.0)
	_model(garden_anchor, &"WateringCan", WATERING_CAN,
		Vector3(5.4, 0.15, 4.3), -0.35, Vector3.ONE * 1.8)
	_model(garden_anchor, &"GardenBucket", WOODEN_BUCKET,
		Vector3(6.0, 0.08, 3.5), 0.5, Vector3.ONE * 1.15)
	_build_well(garden_anchor, Vector3(6.2, 0.0, -4.1))


func _build_well(parent: Node3D, position: Vector3) -> void:
	var well := _group(parent, &"GardenWell")
	well.position = position
	for i: int in 10:
		var angle := TAU * float(i) / 10.0
		_model(well, &"WellStone", BOULDERS[i % BOULDERS.size()],
			Vector3(cos(angle) * 1.0, 0.08, sin(angle) * 1.0), angle,
			Vector3.ONE * 0.28)
	for side: float in [-1.0, 1.0]:
		_cylinder(well, &"WellPost", MAT_WOOD, 0.10, 2.4,
			Transform3D(Basis.IDENTITY, Vector3(side * 1.15, 1.15, 0.0)), false, 8)
	_box(well, &"WellBeam", MAT_WOOD, Vector3(2.7, 0.18, 0.18),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.25, 0.0)), false)


func _build_fishing_docks(parent: Node3D) -> void:
	# FishingHole owns the one interactive east dock. These two remain scenic.
	var river_dock := _group(parent, &"RiverFishingDock")
	river_dock.position = Vector3(-34.0, 0.0, -12.0)
	river_dock.rotation.y = PI * 0.5
	_build_timber_dock(river_dock, 4.0, 2.0)
	var south_dock := _group(parent, &"SouthPondDock")
	south_dock.position = SOUTH_POND_CENTER + Vector3(-1.0, 0.15, 4.6)
	_build_timber_dock(south_dock, 3.7, 2.1)


func _build_timber_dock(parent: Node3D, length: float, width: float) -> void:
	var plank_count := maxi(5, int(ceil(length / 0.48)))
	for i: int in plank_count:
		var z := -length * float(i) / float(plank_count - 1)
		var skew := sin(float(i) * 2.37) * 0.045
		_box(parent, StringName("DockPlank%02d" % i), MAT_WOOD,
			Vector3(width + cos(float(i)) * 0.08, 0.15, 0.42),
			Transform3D(Basis(Vector3.UP, skew), Vector3(0.0, 0.11, z)), false)
	for x: float in [-width * 0.44, width * 0.44]:
		for z: float in [0.0, -length * 0.52, -length]:
			_cylinder(parent, &"DockPost", MAT_WOOD, 0.10, 1.35,
				Transform3D(Basis.IDENTITY, Vector3(x, -0.18, z)), false, 8)


func _build_decorative_trees(parent: Node3D) -> void:
	var pine_a: Array[Dictionary] = []
	var pine_b: Array[Dictionary] = []
	var oaks: Array[Dictionary] = []
	for i: int in DECORATIVE_TREE_POSITIONS.size():
		var placement: Dictionary = {
			&"p": DECORATIVE_TREE_POSITIONS[i],
			&"y": float(i) * 0.83,
			&"h": 8.0 + float(i % 5) * 0.65,
		}
		if i % 9 == 6:
			oaks.append(placement)
		elif i % FOREST_PINES.size() == 0:
			pine_a.append(placement)
		else:
			pine_b.append(placement)
	for i: int in DENSE_TREE_ROWS.size():
		var row := DENSE_TREE_ROWS[i]
		var oak := row.z < 0.0
		var position := Vector3(row.x, 0.0, row.y)
		var coordinate_hash: int = int(row.x * 738.0) ^ int(row.y * 1931.0)
		var yaw := fposmod(float(coordinate_hash) * 0.0001, TAU)
		var placement: Dictionary = {&"p": position, &"y": yaw, &"h": absf(row.z)}
		if oak:
			oaks.append(placement)
		else:
			pine_a.append(placement)
	_batch_normalized_models(parent, &"PineA", FOREST_PINES[0], pine_a, 32.0)
	_batch_normalized_models(parent, &"PineB", FOREST_PINES[1], pine_b, 32.0)
	_batch_normalized_models(parent, &"Oak", FOREST_OAK, oaks, 32.0)


func _build_logging_detail(parent: Node3D) -> void:
	var yard := _group(parent, &"LoggingYard")
	for row: Dictionary in [
		{&"p": Vector3(-31.0, 0.0, 12.0), &"y": 0.2, &"s": 1.05},
		{&"p": Vector3(-25.0, 0.0, -1.8), &"y": 1.4, &"s": 0.82},
		{&"p": Vector3(-18.0, 0.0, 11.5), &"y": 2.6, &"s": 0.92},
		{&"p": Vector3(-29.0, 0.0, -7.0), &"y": 0.7, &"s": 0.72},
	]:
		_normalized_model(yard, &"OldStump", TREE_STUMP, row[&"p"], row[&"y"],
			0.65 * float(row[&"s"]))
	var rack := _group(yard, &"TimberRack")
	rack.position = Vector3(-12.5, 0.0, 13.0)
	rack.rotation.y = 0.42
	for i: int in 6:
		_cylinder(rack, &"CutLog", MAT_WOOD, 0.27 + float(i % 2) * 0.04, 3.4,
			Transform3D(Basis(Vector3.FORWARD, PI * 0.5),
				Vector3(-1.2 + float(i % 3) * 1.2,
					0.3 + float(i / 3) * 0.52, 0.0)), false, 10)
	for side: float in [-1.0, 1.0]:
		_box(rack, &"RackBrace", MAT_WOOD, Vector3(0.16, 1.6, 0.16),
			Transform3D(Basis(Vector3.FORWARD, side * 0.25),
				Vector3(side * 2.1, 0.65, 0.0)), false)
	_model(yard, &"WoodsmansAxe", WOODSMANS_AXE,
		Vector3(-30.4, 0.72, 12.1), -0.2, Vector3.ONE * 1.45)


func _build_meadow(parent: Node3D) -> void:
	var flowers_by_source: Array[Array] = []
	flowers_by_source.resize(FLOWERS.size())
	for i: int in flowers_by_source.size():
		flowers_by_source[i] = []
	for i: int in FLOWER_POSITIONS.size():
		flowers_by_source[i % FLOWERS.size()].append({
			&"p": FLOWER_POSITIONS[i], &"y": float(i) * 1.37,
			&"s": Vector3.ONE * (1.7 + float(i % 3) * 0.35),
		})
	for i: int in FLOWERS.size():
		_batch_scaled_models(parent, StringName("Flower%02d" % i), FLOWERS[i],
			flowers_by_source[i])
	var undergrowth_by_source: Array[Array] = []
	undergrowth_by_source.resize(UNDERGROWTH.size())
	for i: int in undergrowth_by_source.size():
		undergrowth_by_source[i] = []
	for i: int in UNDERGROWTH_POSITIONS.size():
		undergrowth_by_source[i % UNDERGROWTH.size()].append({
			&"p": UNDERGROWTH_POSITIONS[i], &"y": float(i) * 0.97,
			&"s": Vector3.ONE * (0.8 + float(i % 4) * 0.12),
		})
	for i: int in UNDERGROWTH.size():
		_batch_scaled_models(parent, StringName("Undergrowth%02d" % i),
			UNDERGROWTH[i], undergrowth_by_source[i])


func _build_rock_detail(parent: Node3D) -> void:
	var positions: Array[Vector3] = [
		Vector3(-27.0, 0.1, 24.0), Vector3(-22.0, 0.1, 18.0),
		Vector3(-27.0, 0.1, 7.0), Vector3(-23.0, 0.1, -7.0),
		Vector3(-16.0, 0.1, -16.0), Vector3(-8.0, 0.1, 15.0),
		Vector3(4.0, 0.1, 19.0), Vector3(12.0, 0.1, 17.0),
		Vector3(20.0, 0.1, 13.0), Vector3(29.0, 0.1, 11.0),
		Vector3(25.0, 0.1, -12.0), Vector3(20.0, 0.1, -22.0),
		Vector3(12.0, 0.1, -28.0), Vector3(-10.0, 0.1, -27.0),
		Vector3(-21.0, 0.1, -23.0), Vector3(-30.0, 0.1, -17.0),
	]
	for i: int in positions.size():
		_model(parent, StringName("FieldRock%02d" % i), BOULDERS[i % BOULDERS.size()],
			positions[i], float(i) * 0.69, Vector3.ONE * (0.5 + float(i % 4) * 0.12))


func _build_lighting(parent: Node3D) -> void:
	var positions: Array[Vector3] = [
		Vector3(-24.0, 0.0, 19.0), Vector3(-9.0, 0.0, 8.0),
		Vector3(8.0, 0.0, 9.0), Vector3(21.0, 0.0, 15.0),
		Vector3(19.0, 0.0, -8.0), Vector3(13.0, 0.0, -22.0),
		Vector3(-7.0, 0.0, -20.0), Vector3(-25.0, 0.0, -13.0),
	]
	for i: int in positions.size():
		var lamp := _model(parent, StringName("PathLamp%02d" % i), LAMP_POST,
			positions[i], float(i % 4) * PI * 0.5, Vector3.ONE,
			Vector3(0.0, 2.8, 0.0))
		var light := OmniLight3D.new()
		light.name = &"LampGlow"
		light.position = Vector3(0.0, 4.3, 0.0)
		light.light_color = Color(1.0, 0.64, 0.28)
		light.light_energy = 0.35
		light.omni_range = 5.5
		light.shadow_enabled = false
		lamp.add_child(light)


func _build_bench(parent: Node3D, position: Vector3, yaw: float) -> void:
	var bench := _group(parent, &"Bench")
	bench.position = position
	bench.rotation.y = yaw
	_box(bench, &"Seat", MAT_WOOD, Vector3(2.8, 0.18, 0.55),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)), false)
	_box(bench, &"Back", MAT_WOOD, Vector3(2.8, 0.65, 0.14),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.86, 0.23)), false)
	for side: float in [-1.0, 1.0]:
		_box(bench, &"Leg", MAT_WOOD, Vector3(0.18, 0.65, 0.18),
			Transform3D(Basis.IDENTITY, Vector3(side * 1.1, 0.30, 0.0)), false)


func _build_short_fence(parent: Node3D, position: Vector3, yaw: float,
		length: float) -> void:
	var fence := _group(parent, &"FenceRun")
	fence.position = position
	fence.rotation.y = yaw
	var posts := maxi(2, int(ceil(length / 2.1)) + 1)
	for i: int in posts:
		var x := -length * 0.5 + length * float(i) / float(posts - 1)
		_cylinder(fence, &"Post", MAT_WOOD, 0.10, 1.10,
			Transform3D(Basis.IDENTITY, Vector3(x, 0.5, 0.0)), true, 8)
	for height: float in [0.38, 0.78]:
		_box(fence, &"Rail", MAT_WOOD, Vector3(length, 0.12, 0.12),
			Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.0)), true)


func _path_segment(parent: Node3D, from: Vector3, to: Vector3, width: float,
		node_name: StringName) -> void:
	var flat_from := Vector3(from.x, 0.07, from.z)
	var flat_to := Vector3(to.x, 0.07, to.z)
	var delta := flat_to - flat_from
	var yaw := atan2(delta.x, delta.z)
	_box(parent, node_name, _path_material, Vector3(width, 0.055, delta.length() + 0.8),
		Transform3D(Basis(Vector3.UP, yaw), (flat_from + flat_to) * 0.5), false)


func _water_plane(parent: Node3D, node_name: StringName, size: Vector2,
		position: Vector3, subdivisions: int) -> MeshInstance3D:
	var water := MeshInstance3D.new()
	water.name = node_name
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	water.mesh = plane
	water.material_override = _water_material
	water.position = position
	parent.add_child(water)
	scenic_water.append(water)
	return water


func _irregular_water(parent: Node3D, node_name: StringName, material: Material,
		radius: Vector2, position: Vector3, segments: int,
		phase: float) -> MeshInstance3D:
	var water := _polygon_disc(parent, node_name, material, radius,
		position, segments, phase)
	scenic_water.append(water)
	return water


func _water_ribbon(parent: Node3D, node_name: StringName,
		centreline: PackedVector2Array, width: float, position: Vector3,
		material: Material, phase: float,
		register_as_scenic_water: bool = false) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var distance := 0.0
	for i: int in centreline.size():
		var previous := centreline[maxi(0, i - 1)]
		var next := centreline[mini(centreline.size() - 1, i + 1)]
		var tangent := (next - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var local_width := width * (1.0 + sin(float(i) * 2.11 + phase) * 0.10)
		if i > 0:
			distance += centreline[i].distance_to(centreline[i - 1])
		for side: float in [-1.0, 1.0]:
			var point := centreline[i] + normal * local_width * 0.5 * side
			vertices.append(Vector3(point.x, 0.0, point.y))
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.0 if side < 0.0 else 1.0, distance / 8.0))
	if centreline.size() >= 2:
		for i: int in centreline.size() - 1:
			var a := i * 2
			indices.append_array(PackedInt32Array([
				a, a + 2, a + 1,
				a + 1, a + 2, a + 3,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := MeshInstance3D.new()
	water.name = node_name
	water.mesh = mesh
	water.material_override = material
	water.position = position
	parent.add_child(water)
	# The public proof contract counts one river system plus the two ponds; the
	# other ribbons are disconnected visual reaches of that same river system.
	if register_as_scenic_water:
		scenic_water.append(water)
	return water


func _irregular_disc(parent: Node3D, node_name: StringName, material: Material,
		radius: Vector2, position: Vector3, segments: int,
		phase: float) -> MeshInstance3D:
	return _polygon_disc(parent, node_name, material, radius, position,
		segments, phase)


func _polygon_disc(parent: Node3D, node_name: StringName, material: Material,
		radius: Vector2, position: Vector3, segments: int,
		phase: float) -> MeshInstance3D:
	var perimeter := PackedVector2Array()
	for i: int in segments:
		var angle := TAU * float(i) / float(segments)
		var wobble := 1.0 + sin(angle * 3.0 + phase) * 0.045 \
			+ sin(angle * 7.0 - phase * 0.7) * 0.025
		perimeter.append(Vector2(cos(angle) * radius.x * wobble,
			sin(angle) * radius.y * wobble))
	return _polygon_surface(parent, node_name, material, perimeter, position)


func _polygon_surface(parent: Node3D, node_name: StringName, material: Material,
		perimeter: PackedVector2Array, position: Vector3) -> MeshInstance3D:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	var max_extent := 1.0
	for point: Vector2 in perimeter:
		max_extent = maxf(max_extent, maxf(absf(point.x), absf(point.y)))
	for point: Vector2 in perimeter:
		vertices.append(Vector3(point.x, 0.0, point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + point.x / (max_extent * 2.0),
			0.5 + point.y / (max_extent * 2.0)))
	for i: int in perimeter.size():
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % perimeter.size() + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _batch_normalized_models(parent: Node3D, batch_name: StringName,
		packed: PackedScene, placements: Array[Dictionary], cell_size: float) -> void:
	if placements.is_empty():
		return
	var template := packed.instantiate() as Node3D
	if template == null:
		return
	parent.add_child(template)
	_harmonize_model(template, _model_family(packed))
	var bounds := _model_bounds(template)
	var parts: Array[Dictionary] = []
	var can_batch := _collect_model_parts(template, template, parts)
	parent.remove_child(template)
	template.free()
	if not can_batch or parts.is_empty() or bounds.size.y <= 0.001:
		for i: int in placements.size():
			var row := placements[i]
			_normalized_model(parent, StringName("%sFallback%02d" % [batch_name, i]),
				packed, row[&"p"], row[&"y"], row[&"h"])
		return
	var cells: Dictionary = {}
	for row: Dictionary in placements:
		var point: Vector3 = row[&"p"]
		var cell := Vector2i(floori((point.x + 48.0) / cell_size),
			floori((point.z + 48.0) / cell_size))
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(row)
	for cell_key: Variant in cells:
		var transforms: Array[Transform3D] = []
		for row: Dictionary in cells[cell_key]:
			var factor: float = row[&"h"] / bounds.size.y
			var base_center := Vector3(bounds.position.x + bounds.size.x * 0.5,
				bounds.position.y, bounds.position.z + bounds.size.z * 0.5)
			var holder := Transform3D(Basis(Vector3.UP, row[&"y"]), row[&"p"])
			var model := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor),
				-base_center * factor)
			transforms.append(holder * model)
		_emit_model_multimeshes(parent,
			StringName("%s_%d_%d" % [batch_name, cell_key.x, cell_key.y]),
			parts, transforms, 96.0)


func _batch_scaled_models(parent: Node3D, batch_name: StringName,
		packed: PackedScene, placements: Array) -> void:
	if placements.is_empty():
		return
	var template := packed.instantiate() as Node3D
	if template == null:
		return
	parent.add_child(template)
	_harmonize_model(template, _model_family(packed))
	var parts: Array[Dictionary] = []
	var can_batch := _collect_model_parts(template, template, parts)
	parent.remove_child(template)
	template.free()
	if not can_batch or parts.is_empty():
		for i: int in placements.size():
			var row: Dictionary = placements[i]
			_model(parent, StringName("%sFallback%02d" % [batch_name, i]), packed,
				row[&"p"], row[&"y"], row[&"s"])
		return
	# Meadow batches split once across the site's long axis. It is enough spatial
	# granularity for culling without turning four flowers into four draw calls.
	for half: int in 2:
		var transforms: Array[Transform3D] = []
		for row_variant: Variant in placements:
			var row: Dictionary = row_variant
			var point: Vector3 = row[&"p"]
			if (point.x >= 0.0) != (half == 1):
				continue
			var holder := Transform3D(Basis(Vector3.UP, row[&"y"]), point)
			var scale_value: Vector3 = row[&"s"]
			var model := Transform3D(Basis.IDENTITY.scaled(scale_value), Vector3.ZERO)
			transforms.append(holder * model)
		if not transforms.is_empty():
			_emit_model_multimeshes(parent, StringName("%s_Half%d" % [batch_name, half]),
				parts, transforms, 80.0)


func _collect_model_parts(root_node: Node3D, node: Node,
		parts: Array[Dictionary]) -> bool:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface: int in mesh_instance.mesh.get_surface_count():
			# MultiMesh preserves materials embedded in the Mesh resource, but it
			# cannot preserve a different override for every surface.
			if mesh_instance.get_surface_override_material(surface) != null:
				return false
		parts.append({
			&"mesh": mesh_instance.mesh,
			&"xform": root_node.global_transform.affine_inverse() \
				* mesh_instance.global_transform,
			&"override": mesh_instance.material_override,
		})
	for child: Node in node.get_children():
		if not _collect_model_parts(root_node, child, parts):
			return false
	return true


func _emit_model_multimeshes(parent: Node3D, batch_name: StringName,
		parts: Array[Dictionary], model_transforms: Array[Transform3D],
		visibility_end: float) -> void:
	for part_index: int in parts.size():
		var part := parts[part_index]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = part[&"mesh"]
		multimesh.instance_count = model_transforms.size()
		for i: int in model_transforms.size():
			multimesh.set_instance_transform(i,
				model_transforms[i] * (part[&"xform"] as Transform3D))
		var instance := MultiMeshInstance3D.new()
		instance.name = StringName("%s_Part%02d" % [batch_name, part_index])
		instance.multimesh = multimesh
		instance.material_override = part[&"override"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = visibility_end
		instance.visibility_range_fade_mode = \
			GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.lod_bias = 0.75
		parent.add_child(instance)


func _model(parent: Node3D, node_name: StringName, packed: PackedScene,
		position: Vector3, yaw: float, scale_value: Vector3,
		model_offset: Vector3 = Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation.y = yaw
	parent.add_child(holder)
	var model := packed.instantiate() as Node3D
	if model == null:
		return holder
	model.name = &"Model"
	model.position = model_offset
	model.scale = scale_value
	holder.add_child(model)
	_harmonize_model(model, _model_family(packed))
	return holder


func _normalized_model(parent: Node3D, node_name: StringName, packed: PackedScene,
		position: Vector3, yaw: float, target_height: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation.y = yaw
	parent.add_child(holder)
	var model := packed.instantiate() as Node3D
	if model == null:
		return holder
	model.name = &"Model"
	holder.add_child(model)
	var bounds := _model_bounds(model)
	if bounds.size.y > 0.001:
		var factor := target_height / bounds.size.y
		var base_center := Vector3(
			bounds.position.x + bounds.size.x * 0.5,
			bounds.position.y,
			bounds.position.z + bounds.size.z * 0.5)
		model.scale = Vector3.ONE * factor
		model.position = -base_center * factor
	_harmonize_model(model, _model_family(packed))
	return holder


func _model_family(packed: PackedScene) -> StringName:
	var file_name := packed.resource_path.get_file()
	if file_name == "hearthstone_cottage.glb":
		return &"cottage"
	if file_name == "cave_mouth.glb":
		return &"cave"
	if file_name.begins_with("boulder_"):
		return &"boulder"
	if file_name.begins_with("tree_"):
		return &"tree"
	if file_name.begins_with("meadow_") or file_name.contains("flower") \
			or file_name.begins_with("poppy_") or file_name == "daisy_white.glb":
		return &"foliage"
	if file_name == "lamp_post.glb":
		return &"lamp"
	if file_name in ["rusted_spade.glb", "watering_can.glb", "woodsmans_axe.glb"]:
		return &"tool"
	if file_name in ["wooden_barrels.glb", "wooden_bucket.glb", "wooden_crate.glb"]:
		return &"wood_prop"
	return &"prop"


func _harmonize_model(node: Node, family: StringName) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var source_mesh := mesh_instance.mesh
		mesh_instance.mesh = _harmonized_mesh(source_mesh, family)
		if mesh_instance.material_override != null:
			mesh_instance.material_override = _harmonized_material(
				mesh_instance.material_override, family)
		for surface: int in source_mesh.get_surface_count():
			var source_override := mesh_instance.get_surface_override_material(surface)
			if source_override != null:
				mesh_instance.set_surface_override_material(surface,
					_harmonized_material(source_override, family))
	for child: Node in node.get_children():
		_harmonize_model(child, family)


func _harmonized_mesh(source: Mesh, family: StringName) -> Mesh:
	var key := "%d:%s" % [source.get_instance_id(), family]
	if _harmonized_mesh_cache.has(key):
		return _harmonized_mesh_cache[key]
	var mesh := source.duplicate(false) as Mesh
	if mesh == null:
		return source
	for surface: int in source.get_surface_count():
		mesh.surface_set_material(surface,
			_harmonized_material(source.surface_get_material(surface), family))
	_harmonized_mesh_cache[key] = mesh
	return mesh


func _harmonized_material(source: Material, family: StringName) -> Material:
	if not source is StandardMaterial3D:
		return source
	var standard := source as StandardMaterial3D
	var key := "%d:%s" % [standard.get_instance_id(), family]
	if _harmonized_material_cache.has(key):
		return _harmonized_material_cache[key]
	var material := standard.duplicate(false) as StandardMaterial3D
	if material == null:
		return source
	var multiplier := _family_color_multiplier(family)
	material.albedo_color = Color(
		standard.albedo_color.r * multiplier.r,
		standard.albedo_color.g * multiplier.g,
		standard.albedo_color.b * multiplier.b,
		standard.albedo_color.a)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var roughness_band := _family_roughness_band(family)
	material.roughness = clampf(material.roughness,
		roughness_band.x, roughness_band.y)
	var true_metal := standard.metallic >= 0.45
	if not true_metal:
		material.metallic = 0.0
		material.metallic_specular = minf(material.metallic_specular, 0.25)
	var source_name := standard.resource_name.to_lower()
	var wood_surface := family in [&"tree", &"wood_prop"] \
		or source_name.contains("wood") or source_name.contains("timber")
	material.normal_scale = minf(material.normal_scale, 0.30 if wood_surface else 0.45)
	material.texture_filter = \
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_harmonized_material_cache[key] = material
	return material


func _family_color_multiplier(family: StringName) -> Color:
	match family:
		&"cottage":
			return Color(0.98, 0.94, 0.86, 1.0)
		&"cave", &"boulder":
			return Color(0.94, 0.92, 0.86, 1.0)
		&"tree":
			return Color(0.92, 0.96, 0.86, 1.0)
		&"foliage":
			return Color(0.95, 0.98, 0.90, 1.0)
		&"lamp", &"tool":
			return Color(0.95, 0.91, 0.84, 1.0)
		&"wood_prop":
			return Color(0.96, 0.91, 0.82, 1.0)
	return Color(0.97, 0.95, 0.90, 1.0)


func _family_roughness_band(family: StringName) -> Vector2:
	match family:
		&"cottage":
			return Vector2(0.78, 0.92)
		&"cave", &"boulder":
			return Vector2(0.82, 0.95)
		&"tree", &"wood_prop":
			return Vector2(0.78, 0.92)
		&"foliage":
			return Vector2(0.84, 0.96)
		&"lamp", &"tool":
			return Vector2(0.72, 0.88)
	return Vector2(0.80, 0.94)


func _model_bounds(root_node: Node3D) -> AABB:
	var points := PackedVector3Array()
	_collect_model_points(root_node, root_node, points)
	if points.is_empty():
		return AABB()
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector3 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _collect_model_points(root_node: Node3D, node: Node,
		points: PackedVector3Array) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var box := mesh_instance.mesh.get_aabb()
		var to_root := root_node.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		for x: float in [box.position.x, box.end.x]:
			for y: float in [box.position.y, box.end.y]:
				for z: float in [box.position.z, box.end.z]:
					points.append(to_root * Vector3(x, y, z))
	for child: Node in node.get_children():
		_collect_model_points(root_node, child, points)


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, local_transform: Transform3D, solid: bool) -> Node3D:
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = K.L_WORLD
		body.collision_mask = 0
		holder = body
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.transform = local_transform
	parent.add_child(holder)
	if material != null:
		var instance := MeshInstance3D.new()
		instance.name = &"Mesh"
		var mesh := BoxMesh.new()
		mesh.size = size
		instance.mesh = mesh
		instance.material_override = material
		holder.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = &"Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		holder.add_child(collision)
	return holder


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, local_transform: Transform3D, solid: bool,
		sides: int) -> Node3D:
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = K.L_WORLD
		body.collision_mask = 0
		holder = body
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.transform = local_transform
	parent.add_child(holder)
	var instance := MeshInstance3D.new()
	instance.name = &"Mesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	holder.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = &"Collision"
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		holder.add_child(collision)
	return holder


func _plain_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.metallic = 0.0
	material.metallic_specular = 0.10
	material.roughness = roughness
	return material


func _group(parent: Node3D, node_name: StringName) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	parent.add_child(group)
	return group


func _facing(origin: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin).looking_at(target, Vector3.UP)
