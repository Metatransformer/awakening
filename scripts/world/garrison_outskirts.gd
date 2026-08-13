class_name GarrisonOutskirts
extends Node3D
## The authored homestead clearing between Highbridge and the Sunken Cut.
## OutskirtsHomestead owns the place; this root owns gameplay state, transitions,
## stable ports, the one FishingHole, and the harvestable grove.

const HARVEST_PINES: Array[PackedScene] = [
	preload("res://assets/valenfeld/outskirts/tree_pine_01.glb"),
]
const MAPLE_GIANT: PackedScene = preload(
	"res://assets/valenfeld/forest/maple_giant.glb")
const VALLEY_INNER: ArrayMesh = preload(
	"res://assets/terrain/enclosed_valley_inner.res")
const VALLEY_MID: ArrayMesh = preload(
	"res://assets/terrain/enclosed_valley_mid.res")
const VALLEY_FAR: ArrayMesh = preload(
	"res://assets/terrain/enclosed_valley_far.res")

## Public route contract used by the surface map and visual proof.
static var PATH_POINTS: Array[Vector3] = [
	Vector3(-32.0, 0.14, 24.4),
	Vector3(-29.2, 0.12, 22.4),
	Vector3(-24.8, 0.10, 20.4),
	Vector3(-18.0, 0.10, 15.8),
	Vector3(-12.6, 0.09, 11.3),
	Vector3(-8.0, 0.09, 7.5),
	Vector3(-4.2, 0.08, 3.6),
	Vector3(0.0, 0.08, 0.0),
	Vector3(5.0, 0.09, 3.2),
	Vector3(10.5, 0.10, 7.6),
	Vector3(15.2, 0.10, 11.2),
	Vector3(21.0, 0.12, 17.0),
	Vector3(27.2, 0.15, 22.9),
]

## Eighteen usable trees form the west-side grove. Decorative boundary pines in
## OutskirtsHomestead make the forest read dense without turning every trunk into
## a prompt target; the daily selected-stump contract still spans this full set.
const TREE_POSITIONS: Array[Vector3] = [
	Vector3(-20.0, 0.10, 26.0), Vector3(-21.8, 0.10, 24.6),
	Vector3(-18.5, 0.10, 22.0), Vector3(-14.5, 0.10, 22.5),
	Vector3(-29.0, 0.10, 15.0), Vector3(-26.5, 0.10, 14.5),
	Vector3(-22.0, 0.10, 13.5), Vector3(-13.8, 0.10, 20.2),
	Vector3(-30.0, 0.10, 8.5), Vector3(-25.5, 0.10, 9.0),
	Vector3(-21.0, 0.10, 9.2), Vector3(-11.8, 0.10, 18.0),
	Vector3(-29.5, 0.10, 2.0), Vector3(-25.0, 0.10, 2.5),
	Vector3(-20.5, 0.10, 2.2), Vector3(-14.7, 0.10, 2.8),
	Vector3(-27.0, 0.10, -4.0), Vector3(-21.5, 0.10, -4.3),
]
const TREE_YAWS: Array[float] = [
	0.12, 1.04, 2.18, 0.62, 2.82, 1.57, 0.35, 2.44, 1.91,
	0.88, 2.68, 0.21, 1.30, 2.95, 0.54, 1.79, 2.30, 0.72,
]
const MAPLE_TREE_INDICES: Array[int] = [3, 14]

var garrison_gate: SurfaceTransition
var sunken_cut: SurfaceTransition
var blocked_path: SurfaceTransition
var fishing_hole: FishingHole
var homestead: OutskirtsHomestead
var harvest_trees: Array[HarvestTree] = []

var _built: bool = false


func _ready() -> void:
	if Flow.refuse_boot(self):
		return
	if _built:
		return
	_built = true
	_build()
	Atlas.register_surface(self)


func _exit_tree() -> void:
	Atlas.unregister_surface(self)


func port(id: StringName) -> Transform3D:
	if homestead != null and is_instance_valid(homestead):
		return homestead.port(id)
	# These constants also make ports safe during scene construction and cold map
	# queries before OutskirtsHomestead has entered the tree.
	match id:
		&"arrival":
			return _facing(OutskirtsHomestead.GARRISON_APPROACH,
				OutskirtsHomestead.CLEARING_CENTER)
		&"garrison_gate":
			return _facing(OutskirtsHomestead.GARRISON_THRESHOLD,
				OutskirtsHomestead.BRIDGE_END)
		&"bridge_end", &"blocked_path":
			return _facing(OutskirtsHomestead.BRIDGE_END + Vector3(1.3, 0.0, -0.8),
				OutskirtsHomestead.BRIDGE_END)
		&"sunken_cut":
			return _facing(OutskirtsHomestead.MINE_APPROACH,
				OutskirtsHomestead.MINE_MOUTH)
		&"grove", &"timber_yard":
			return _facing(OutskirtsHomestead.GROVE_CENTER,
				OutskirtsHomestead.CLEARING_CENTER)
		&"fishing_hole":
			return _facing(OutskirtsHomestead.FISHING_CENTER + Vector3(0.5, 0.0, 3.0),
				OutskirtsHomestead.FISHING_CENTER + Vector3(0.5, 0.0, -2.25))
		&"clearing":
			return Transform3D(Basis.IDENTITY, OutskirtsHomestead.CLEARING_CENTER)
		&"toolshed":
			return _facing(OutskirtsHomestead.TOOLSHED_CENTER + Vector3(-5.0, 0.0, 1.0),
				OutskirtsHomestead.TOOLSHED_CENTER)
		&"garden":
			return _facing(OutskirtsHomestead.GARDEN_CENTER + Vector3(-2.0, 0.0, 7.0),
				OutskirtsHomestead.GARDEN_CENTER)
		&"south_pond":
			return _facing(OutskirtsHomestead.SOUTH_POND_CENTER + Vector3(0.0, 0.0, 7.0),
				OutskirtsHomestead.SOUTH_POND_CENTER)
		&"vista_camera":
			var eye := Vector3(0.0, 55.0, 51.0)
			return Transform3D(Basis.IDENTITY, eye).looking_at(
				Vector3(0.0, 0.0, 1.0), Vector3.UP)
	push_error("GarrisonOutskirts: unknown port '%s'" % id)
	return Transform3D.IDENTITY


## Authored public terrain is immediately visible on the surface map. Garden and
## grove areas are shapes, while every landmark is derived from a live world port.
func surface_map_plan() -> Dictionary:
	var paths: Array[Dictionary] = [
		_surface_path(PackedVector3Array(PATH_POINTS), &"path"),
		_surface_path(PackedVector3Array([
			OutskirtsHomestead.CLEARING_CENTER,
			OutskirtsHomestead.TOOLSHED_CENTER,
			OutskirtsHomestead.FISHING_CENTER,
		]), &"spur"),
		_surface_path(PackedVector3Array([
			OutskirtsHomestead.CLEARING_CENTER,
			OutskirtsHomestead.GARDEN_CENTER,
			OutskirtsHomestead.SOUTH_POND_CENTER,
		]), &"spur"),
	]
	var areas: Array[Dictionary] = [_grove_area(), _garden_area()]
	var landmarks: Array[Dictionary] = [
		_surface_landmark(port(&"garrison_gate").origin, &"gate"),
		_surface_landmark(port(&"clearing").origin, &"landmark"),
		_surface_landmark(port(&"sunken_cut").origin, &"dungeon"),
		_surface_landmark(port(&"fishing_hole").origin, &"fishing"),
		_surface_landmark(port(&"grove").origin, &"grove"),
		_surface_landmark(port(&"toolshed").origin, &"landmark"),
		_surface_landmark(port(&"garden").origin, &"landmark"),
		_surface_landmark(port(&"south_pond").origin, &"landmark"),
	]
	paths.make_read_only()
	areas.make_read_only()
	landmarks.make_read_only()
	var plan: Dictionary = {
		&"title": "Garrison Outskirts",
		&"view_range": 78.0,
		&"paths": paths,
		&"areas": areas,
		&"landmarks": landmarks,
	}
	plan.make_read_only()
	return plan


func _build() -> void:
	var atmosphere := SurfaceAtmosphere.new()
	atmosphere.name = &"SurfaceAtmosphere"
	add_child(atmosphere)
	var valley := EnclosedValleyTerrain.new()
	valley.name = &"EnclosedValleyTerrain"
	valley.baked_inner_mesh = VALLEY_INNER
	valley.baked_mid_mesh = VALLEY_MID
	valley.baked_far_mesh = VALLEY_FAR
	valley.gorge_angle_degrees = 135.0
	valley.gorge_width_degrees = 20.0
	valley.configure_for_site(58.0, 440.0, -9.0, 0.0)
	add_child(valley)

	homestead = OutskirtsHomestead.new()
	homestead.name = &"Homestead"
	add_child(homestead)

	var gameplay := Node3D.new()
	gameplay.name = &"Gameplay"
	add_child(gameplay)
	_build_fishing_hole(gameplay)
	_build_trees(gameplay)
	_build_transitions(gameplay)


func _build_fishing_hole(parent: Node3D) -> void:
	fishing_hole = FishingHole.new()
	fishing_hole.name = &"FishingHole"
	fishing_hole.build_pool_visuals = false
	fishing_hole.transform = port(&"fishing_hole")
	parent.add_child(fishing_hole)


func _build_trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = &"HarvestableGrove"
	parent.add_child(trees)
	harvest_trees.clear()
	for i: int in TREE_POSITIONS.size():
		var tree := HarvestTree.new()
		tree.name = StringName("HarvestTree%02d" % i)
		tree.position = TREE_POSITIONS[i]
		tree.rotation.y = TREE_YAWS[i]
		var packed := HARVEST_PINES[i % HARVEST_PINES.size()]
		var scale_factor := 1.0
		var normalize_visual := true
		var target_height := 7.4 + float(i % 5) * 0.52
		if MAPLE_TREE_INDICES.has(i):
			packed = MAPLE_GIANT
			scale_factor = 0.0048 + float(i % 3) * 0.0003
			normalize_visual = false
		tree.configure(i, TREE_POSITIONS.size(), packed, scale_factor,
			normalize_visual, target_height)
		trees.add_child(tree)
		harvest_trees.append(tree)


func _build_transitions(parent: Node3D) -> void:
	var transitions := Node3D.new()
	transitions.name = &"Transitions"
	parent.add_child(transitions)

	garrison_gate = SurfaceTransition.new()
	garrison_gate.name = &"GarrisonGate"
	garrison_gate.destination = SurfaceTransition.Destination.GARRISON
	garrison_gate.radius = 3.0
	garrison_gate.transform = port(&"garrison_gate")
	transitions.add_child(garrison_gate)

	sunken_cut = SurfaceTransition.new()
	sunken_cut.name = &"SunkenCutTransition"
	sunken_cut.destination = SurfaceTransition.Destination.SUNKEN_CUT
	sunken_cut.radius = 3.2
	sunken_cut.transform = port(&"sunken_cut")
	transitions.add_child(sunken_cut)

	# A player may walk onto the bridge before choosing RETURN, but the far end is
	# always a visible, solid boundary. This dead-end prompt animates its timbers.
	blocked_path = SurfaceTransition.new()
	blocked_path.name = &"BridgeBoundary"
	blocked_path.destination = SurfaceTransition.Destination.BLOCKED
	blocked_path.radius = 2.6
	blocked_path.transform = port(&"blocked_path")
	if homestead.bridge_obstruction != null:
		blocked_path.bind_obstruction(homestead.bridge_obstruction)
	transitions.add_child(blocked_path)


func _surface_path(local_points: PackedVector3Array,
		kind: StringName) -> Dictionary:
	var world_points := PackedVector3Array()
	for point: Vector3 in local_points:
		world_points.append(to_global(point))
	var path: Dictionary = {&"kind": kind, &"points": world_points}
	path.make_read_only()
	return path


func _surface_landmark(local_position: Vector3,
		glyph: StringName) -> Dictionary:
	var landmark: Dictionary = {
		&"glyph": glyph,
		&"position": to_global(local_position),
	}
	landmark.make_read_only()
	return landmark


func _grove_area() -> Dictionary:
	return _area_from_points(TREE_POSITIONS, &"grove", 2.5)


func _garden_area() -> Dictionary:
	var points: Array[Vector3] = [
		OutskirtsHomestead.GARDEN_CENTER + Vector3(-8.0, 0.0, -6.0),
		OutskirtsHomestead.GARDEN_CENTER + Vector3(8.0, 0.0, -6.0),
		OutskirtsHomestead.GARDEN_CENTER + Vector3(8.0, 0.0, 6.0),
		OutskirtsHomestead.GARDEN_CENTER + Vector3(-8.0, 0.0, 6.0),
	]
	return _area_from_points(points, &"garden", 0.0)


func _area_from_points(points_in: Array[Vector3], kind: StringName,
		margin: float) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for point: Vector3 in points_in:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
	var points := PackedVector3Array([
		to_global(Vector3(min_x - margin, 0.0, min_z - margin)),
		to_global(Vector3(max_x + margin, 0.0, min_z - margin)),
		to_global(Vector3(max_x + margin, 0.0, max_z + margin)),
		to_global(Vector3(min_x - margin, 0.0, max_z + margin)),
	])
	var area: Dictionary = {&"kind": kind, &"points": points}
	area.make_read_only()
	return area


func _facing(origin: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin).looking_at(target, Vector3.UP)
