class_name GarrisonOutskirts
extends Node3D
## An open authored clearing between the garrison shelf and the Sunken Cut.
## Geometry is primitive and programmatic on purpose: this scene owns the route,
## collision, silhouettes, and ports while the shared surface layer owns sky,
## light, and atmosphere.

const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")
const MAT_PATH := preload("res://assets/materials/mat_flagstone_sunlit.tres")
const MAT_CLIFF := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_DARK_STONE := preload("res://assets/materials/mat_wall.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const PINE_GIANT: PackedScene = preload("res://assets/valenfeld/forest/pine_giant.glb")
const MAPLE_GIANT: PackedScene = preload("res://assets/valenfeld/forest/maple_giant.glb")

const PATH_WIDTH := 7.2
const GROUND_DEPTH := 0.9

## The critical route is a direct 72.5 m descent. Explicit points keep the
## gate, clearing landmark, and dungeon mouth legible to tools and directors.
const PATH_POINTS: Array[Vector3] = [
	Vector3(0.0, 8.0, 32.0),
	Vector3(0.0, 6.3, 12.0),
	Vector3(1.0, 3.5, -12.0),
	Vector3(3.0, 0.6, -40.0),
]

## Each sloped slab is broad enough to be a clearing rather than a corridor.
const GROUND_WIDTHS: Array[float] = [40.0, 44.0, 38.0]
const CLEARING_LANDMARK_POSITION := Vector3(-2.5, 6.3, 11.5)
const BLOCKED_SPUR_START := Vector3(2.4, 5.0, 1.5)
const BLOCKED_SPUR_END := Vector3(19.0, 4.45, 1.5)
const BLOCKED_BARRICADE_POSITION := Vector3(15.4, 4.55, 1.5)

## Two clustered stands make ten independently cuttable trees. The two source
## models use radically different authored units, so their visual scales are
## explicit per instance rather than hidden in HarvestTree.
const TREE_POSITIONS: Array[Vector3] = [
	Vector3(-12.0, 7.35, 24.0),
	Vector3(-17.5, 7.25, 23.0),
	Vector3(-14.2, 6.85, 18.0),
	Vector3(-19.0, 6.55, 15.0),
	Vector3(-15.2, 5.95, 9.0),
	Vector3(-17.2, 5.65, 6.5),
	Vector3(-19.0, 5.2, 2.5),
	Vector3(-13.8, 5.05, 1.0),
	Vector3(-17.6, 4.65, -2.0),
	Vector3(-15.4, 4.35, -5.0),
]
const TREE_YAWS: Array[float] = [
	0.12, 1.04, 2.18, 0.62, 2.82, 1.57, 0.35, 2.44, 1.91, 0.88,
]
const TREE_VISUAL_SCALES: Array[float] = [
	0.0054, 0.0050, 6.8, 0.0057, 0.0049, 0.0055, 0.0052, 7.2, 0.0058, 0.0051,
]
const PINE_TREE_INDICES: Array[int] = [2, 7]

var garrison_gate: SurfaceTransition
var sunken_cut: SurfaceTransition
var blocked_path: SurfaceTransition
var fishing_hole: FishingHole
var harvest_trees: Array[HarvestTree] = []

var _built: bool = false


func _ready() -> void:
	if Flow.refuse_boot(self):
		return
	if _built:
		return
	_built = true
	_build()


func port(id: StringName) -> Transform3D:
	match id:
		&"arrival":
			return Transform3D(Basis.IDENTITY, Vector3(0.0, 8.05, 30.2))
		&"garrison_gate":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 8.1, 33.1))
		&"sunken_cut":
			return Transform3D(Basis.IDENTITY, Vector3(3.0, 0.65, -39.0))
		&"blocked_path":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5),
				BLOCKED_BARRICADE_POSITION)
		# The old port id remains an alias for save-less director compatibility.
		&"grove", &"timber_yard":
			return Transform3D(Basis(Vector3.UP, PI * 0.5),
				Vector3(-9.0, 6.7, 17.5))
		&"fishing_hole":
			var spur_direction := (BLOCKED_SPUR_END - BLOCKED_SPUR_START).normalized()
			return Transform3D(Basis.looking_at(spur_direction, Vector3.UP),
				BLOCKED_SPUR_START + spur_direction * 5.0)
		&"vista_camera":
			var eye := Vector3(-1.5, 10.2, 24.0)
			var target := Vector3(3.0, 2.1, -31.0)
			return Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP)
	push_error("GarrisonOutskirts: unknown port '%s'" % id)
	return Transform3D.IDENTITY


func _build() -> void:
	var atmosphere := SurfaceAtmosphere.new()
	atmosphere.name = &"SurfaceAtmosphere"
	add_child(atmosphere)
	var generated := _group(self, &"Generated")
	var terrain := _group(generated, &"Terrain")
	var cliffs := _group(generated, &"Cliffs")
	var landmarks := _group(generated, &"Landmarks")
	var trees := _group(generated, &"Trees")
	var transitions := _group(generated, &"Transitions")

	_build_path(terrain)
	_build_cliffs(cliffs)
	_build_clearing_landmark(landmarks)
	_build_garrison(landmarks)
	_build_fishing_hole(landmarks)
	_build_sunken_cut(landmarks)
	_build_trees(trees)
	_build_transitions(transitions)


func _build_path(parent: Node3D) -> void:
	for i in PATH_POINTS.size() - 1:
		_build_walk_segment(parent, PATH_POINTS[i], PATH_POINTS[i + 1],
			GROUND_WIDTHS[i], StringName("ClearingTerrace%02d" % i))

	# Round path insets bury the rectangular visual overlaps at each terrace. They
	# are deliberately non-colliding: a horizontal collider laid over two sloped
	# runs creates a lip at its downhill edge even though all three top faces meet
	# exactly at the authored point.
	for i in range(1, PATH_POINTS.size() - 1):
		var point: Vector3 = PATH_POINTS[i]
		_cylinder(parent, StringName("ClearingLandmark%02d" % i), MAT_PATH,
			PATH_WIDTH * 0.54, 0.07, _at(point + Vector3.UP * 0.035), false, 12)

	# The east spur leaves the clearing through the gap between two shoulders and
	# passes the fishing pond before terminating against the outer cliff. Its own
	# broad slab keeps the detour spatially distinct without pretending to be a
	# second route.
	_build_walk_segment(parent, BLOCKED_SPUR_START, BLOCKED_SPUR_END,
		7.0, &"BlockedSpur", 5.2)
	var barricade := _group(parent, &"BlockedSpurBarricade")
	barricade.position = BLOCKED_BARRICADE_POSITION
	barricade.rotation.y = PI * 0.5
	_box(barricade, &"RubbleA", MAT_DARK_STONE, Vector3(2.0, 1.0, 1.3),
		_at(Vector3(-0.8, 0.45, 0.0), -0.2), false)
	_box(barricade, &"RubbleB", MAT_DARK_STONE, Vector3(1.8, 1.25, 1.2),
		_at(Vector3(0.8, 0.58, 0.0), 0.25), false)
	_box(barricade, &"CrossTimberA", MAT_WOOD, Vector3(4.5, 0.28, 0.30),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(24.0)),
			Vector3(0.0, 1.35, 0.0)), false)
	_box(barricade, &"CrossTimberB", MAT_WOOD, Vector3(4.5, 0.28, 0.30),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-24.0)),
			Vector3(0.0, 1.25, 0.08)), false)


func _build_walk_segment(parent: Node3D, from: Vector3, to: Vector3,
		ground_width: float, segment_name: StringName,
		path_width: float = PATH_WIDTH) -> void:
	var delta := to - from
	var basis := Basis.looking_at(delta.normalized(), Vector3.UP)
	var midpoint := (from + to) * 0.5
	var length := delta.length() + 1.2
	_box(parent, StringName("%sGround" % segment_name), MAT_GRASS,
		Vector3(ground_width, GROUND_DEPTH, length),
		Transform3D(basis, midpoint - basis.y * GROUND_DEPTH * 0.5), true)
	_box(parent, StringName("%sPath" % segment_name), MAT_PATH,
		Vector3(path_width, 0.07, length),
		Transform3D(basis, midpoint + basis.y * 0.035), false)


func _build_cliffs(parent: Node3D) -> void:
	# The six outer faces contain the broad slabs without squeezing their centre.
	_build_cliff_wall(parent, &"OuterWestUpper", Vector3(-23.0, 0.0, 35.0),
		Vector3(-23.0, 0.0, 10.0), 6.0, 11.0, 4.5)
	_build_cliff_wall(parent, &"OuterEastUpper", Vector3(23.0, 0.0, 35.0),
		Vector3(23.0, 0.0, 10.0), 6.0, 11.5, 4.2)
	_build_cliff_wall(parent, &"OuterWestMiddle", Vector3(-25.0, 0.0, 12.0),
		Vector3(-25.0, 0.0, -12.0), 6.0, 11.0, 1.8)
	_build_cliff_wall(parent, &"OuterEastMiddle", Vector3(25.0, 0.0, 12.0),
		Vector3(25.0, 0.0, -12.0), 6.0, 10.5, 1.8)
	_build_cliff_wall(parent, &"OuterWestLower", Vector3(-21.0, 0.0, -10.0),
		Vector3(-15.0, 0.0, -42.0), 6.0, 10.5, -1.1)
	_build_cliff_wall(parent, &"OuterEastLower", Vector3(23.0, 0.0, -10.0),
		Vector3(21.0, 0.0, -42.0), 6.0, 11.0, -1.1)
	_cylinder(parent, &"OuterWestLowerJoint", MAT_CLIFF, 4.0, 10.5,
		_at(Vector3(-22.5, 4.15, -11.0), 0.14), true, 7)
	_cylinder(parent, &"OuterEastLowerJoint", MAT_CLIFF, 4.0, 10.8,
		_at(Vector3(23.5, 4.3, -11.0), -0.11), true, 7)
	_cylinder(parent, &"SunkenCutButtressWest", MAT_CLIFF, 4.0, 10.0,
		_at(Vector3(-11.0, 3.9, -41.0), 0.21), true, 7)
	_cylinder(parent, &"SunkenCutButtressEast", MAT_CLIFF, 4.0, 10.6,
		_at(Vector3(17.0, 4.2, -41.0), -0.17), true, 7)

	# Three interior shoulders partition side spaces while their gaps preserve a
	# generous direct route and a near-continuous view of the dungeon mouth.
	_build_cliff_wall(parent, &"GroveShoulderUpper", Vector3(-12.0, 0.0, 15.0),
		Vector3(-11.0, 0.0, 6.0), 4.5, 4.8, 4.4)
	_build_cliff_wall(parent, &"GroveShoulderLower", Vector3(-11.0, 0.0, 2.0),
		Vector3(-10.0, 0.0, -9.0), 4.5, 5.0, 2.3)
	_build_cliff_wall(parent, &"EastSpurShoulderNorth", Vector3(12.0, 0.0, 15.0),
		Vector3(13.0, 0.0, 8.0), 5.5, 5.0, 4.2)
	_build_cliff_wall(parent, &"EastSpurShoulderSouth", Vector3(13.0, 0.0, -4.0),
		Vector3(14.0, 0.0, -13.0), 5.5, 5.0, 1.5)


func _build_cliff_wall(parent: Node3D, wall_name: StringName, from: Vector3,
		to: Vector3, width: float, height: float, base_y: float) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var forward := flat.normalized()
	var yaw := atan2(forward.x, forward.z) + PI
	var centre := (from + to) * 0.5
	centre.y = base_y + height * 0.5
	_box(parent, wall_name, MAT_CLIFF,
		Vector3(width, height, flat.length() + 1.5),
		_at(centre, yaw), true)


func _build_garrison(parent: Node3D) -> void:
	var fort := _group(parent, &"UpperGarrison")
	# One continuous shelf makes the silhouette explicitly non-explorable and is
	# the back cap that prevents leaving the route behind the arrival point.
	_box(fort, &"GateApron", MAT_PATH, Vector3(6.2, GROUND_DEPTH, 4.2),
		_at(Vector3(0.0, 8.0 - GROUND_DEPTH * 0.5, 33.6)), true)
	_box(fort, &"CliffShelf", MAT_CLIFF, Vector3(26.0, 4.2, 10.0),
		_at(Vector3(0.0, 9.9, 39.5)), true)
	_box(fort, &"GateMouth", MAT_IRON, Vector3(4.6, 4.7, 0.35),
		_at(Vector3(0.0, 9.8, 34.32)), false)
	for side: float in [-1.0, 1.0]:
		_box(fort, StringName("GateTower%s" % ("R" if side > 0.0 else "L")),
			MAT_CLIFF, Vector3(5.0, 7.8, 5.4),
			_at(Vector3(5.6 * side, 15.8, 38.0)), true)
		_box(fort, StringName("Curtain%s" % ("R" if side > 0.0 else "L")),
			MAT_CLIFF, Vector3(7.0, 5.2, 3.0),
			_at(Vector3(10.5 * side, 14.5, 40.0)), true)
	_box(fort, &"Gatehouse", MAT_CLIFF, Vector3(6.2, 8.8, 4.6),
		_at(Vector3(0.0, 16.0, 39.0)), true)
	for x: float in [-10.5, -6.8, -3.0, 0.0, 3.0, 6.8, 10.5]:
		_box(fort, StringName("Merlon%s" % str(x)), MAT_CLIFF,
			Vector3(1.4, 1.5, 1.6), _at(Vector3(x, 20.0 if absf(x) < 3.1 else 19.1,
				38.9)), false)


func _build_clearing_landmark(parent: Node3D) -> void:
	var waystone := _group(parent, &"ClearingWaystone")
	waystone.position = CLEARING_LANDMARK_POSITION
	_cylinder(waystone, &"Footing", MAT_DARK_STONE, 1.2, 0.35,
		_at(Vector3.UP * 0.175, 0.12), true, 8)
	_box(waystone, &"Marker", MAT_CLIFF, Vector3(1.15, 3.2, 0.75),
		_at(Vector3(0.0, 1.85, 0.0), 0.08), true)
	_box(waystone, &"IronFace", MAT_IRON, Vector3(0.48, 0.62, 0.08),
		_at(Vector3(-0.03, 2.35, 0.4), 0.08), false)


func _build_fishing_hole(parent: Node3D) -> void:
	fishing_hole = FishingHole.new()
	fishing_hole.name = &"FishingHole"
	fishing_hole.transform = port(&"fishing_hole")
	parent.add_child(fishing_hole)


func _build_sunken_cut(parent: Node3D) -> void:
	var cut := _group(parent, &"SunkenCut")
	# A dark face closes the route physically. Pale outer teeth and a near-black
	# inner plane make the destination readable without owning any atmosphere.
	_box(cut, &"EndCliff", MAT_DARK_STONE, Vector3(24.0, 12.0, 6.0),
		_at(Vector3(3.0, 4.8, -44.2)), true)
	_box(cut, &"Mouth", MAT_IRON, Vector3(5.0, 5.2, 0.3),
		_at(Vector3(3.0, 2.65, -41.15)), false)
	for side: float in [-1.0, 1.0]:
		_box(cut, StringName("PortalStone%s" % ("R" if side > 0.0 else "L")),
			MAT_CLIFF, Vector3(2.5, 7.6, 3.2),
			_at(Vector3(6.5 * side + 3.0, 3.8, -40.8), side * 0.08), true)
		_box(cut, StringName("IronTooth%s" % ("R" if side > 0.0 else "L")),
			MAT_IRON, Vector3(0.24, 3.8, 0.28),
			_at(Vector3(5.15 * side + 3.0, 2.2, -40.92)), false)
	_box(cut, &"PortalLintel", MAT_DARK_STONE, Vector3(9.2, 2.2, 3.2),
		_at(Vector3(3.0, 6.4, -40.8)), true)
	_box(cut, &"Threshold", MAT_PATH, Vector3(5.0, 0.16, 2.8),
		_at(Vector3(3.0, 0.52, -39.8)), true)


func _build_trees(parent: Node3D) -> void:
	harvest_trees.clear()
	for i in TREE_POSITIONS.size():
		var tree := HarvestTree.new()
		tree.name = StringName("HarvestTree%02d" % i)
		tree.position = TREE_POSITIONS[i]
		tree.rotation.y = TREE_YAWS[i]
		var packed: PackedScene = PINE_GIANT if PINE_TREE_INDICES.has(i) else MAPLE_GIANT
		tree.configure(i, TREE_POSITIONS.size(), packed, TREE_VISUAL_SCALES[i])
		parent.add_child(tree)
		harvest_trees.append(tree)


func _build_transitions(parent: Node3D) -> void:
	garrison_gate = SurfaceTransition.new()
	garrison_gate.name = &"GarrisonGate"
	garrison_gate.destination = SurfaceTransition.Destination.GARRISON
	garrison_gate.radius = 3.0
	garrison_gate.transform = port(&"garrison_gate")
	parent.add_child(garrison_gate)

	sunken_cut = SurfaceTransition.new()
	sunken_cut.name = &"SunkenCutTransition"
	sunken_cut.destination = SurfaceTransition.Destination.SUNKEN_CUT
	sunken_cut.radius = 3.1
	sunken_cut.transform = port(&"sunken_cut")
	parent.add_child(sunken_cut)

	blocked_path = SurfaceTransition.new()
	blocked_path.name = &"BlockedPath"
	blocked_path.destination = SurfaceTransition.Destination.BLOCKED
	blocked_path.radius = 3.0
	blocked_path.transform = port(&"blocked_path")

	# The slab is the fixed collision. The separately authored terrain barricade
	# remains visual feedback, so EXAMINE can rattle it without moving collision.
	_box(blocked_path, &"CollapseBackstop", MAT_DARK_STONE,
		Vector3(5.0, 3.3, 1.0), _at(Vector3(0.0, 1.55, -2.25)), true)
	var obstruction := get_node(
		NodePath("Generated/Terrain/BlockedSpurBarricade")) as Node3D
	blocked_path.bind_obstruction(obstruction)
	parent.add_child(blocked_path)


func _group(parent: Node3D, node_name: StringName) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	parent.add_child(group)
	return group


func _at(position: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)


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
