class_name GarrisonOutskirts
extends Node3D
## A short authored descent between the garrison shelf and the Sunken Cut.
## Geometry is primitive and programmatic on purpose: this scene owns the route,
## collision, silhouettes, and ports while the shared surface layer owns sky,
## light, and atmosphere.

const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")
const MAT_PATH := preload("res://assets/materials/mat_flagstone_sunlit.tres")
const MAT_CLIFF := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_DARK_STONE := preload("res://assets/materials/mat_wall.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const TREE_LARGE: PackedScene = preload("res://assets/valenfeld/forest/tree-large.glb")
const TREE_SHRUB: PackedScene = preload("res://assets/valenfeld/forest/tree-shrub.glb")

const PATH_WIDTH := 4.6
const CORRIDOR_WIDTH := 10.5
const GROUND_DEPTH := 0.9
const CLIFF_THICKNESS := 6.0
const CLIFF_HEIGHT := 9.6

## 79.4 m of authored switchback. Explicit points keep ports, collision, and
## visual wayfinding reproducible without coupling them to an RNG call order.
const PATH_POINTS: Array[Vector3] = [
	Vector3(0.0, 8.0, 32.0),
	Vector3(-4.5, 7.0, 23.0),
	Vector3(-8.0, 5.8, 13.0),
	Vector3(-5.5, 4.6, 4.0),
	Vector3(2.5, 3.4, -5.0),
	Vector3(8.0, 2.3, -15.0),
	Vector3(5.0, 1.3, -27.0),
	Vector3(3.0, 0.6, -40.0),
]

## x/y/z are authored ground positions; w is a small silhouette scale change.
const TREE_SPECS: Array[Vector4] = [
	Vector4(-2.0, 5.65, 14.0, 0.84),
	Vector4(-10.0, 4.65, 5.0, 1.02),
	Vector4(2.2, 1.85, -20.0, 1.05),
	Vector4(8.8, 1.05, -30.0, 0.82),
]

var garrison_gate: SurfaceTransition
var sunken_cut: SurfaceTransition
var blocked_path: SurfaceTransition
var timber_yard: TimberYard
var fishing_hole: FishingHole

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
				Vector3(15.0, 2.2, -2.55))
		&"timber_yard":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(0.65, 7.48, 25.4))
		&"fishing_hole":
			var spur_direction := (Vector3(18.2, 1.9, -1.85)
				- Vector3(2.5, 3.4, -5.0)).normalized()
			return Transform3D(Basis.looking_at(spur_direction, Vector3.UP),
				Vector3(2.5, 3.4, -5.0) + spur_direction * 2.0)
		&"vista_camera":
			var eye := Vector3(-2.8, 8.8, 2.0)
			var target := Vector3(4.8, 1.8, -25.0)
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
	_build_garrison(landmarks)
	_build_timber_yard(landmarks)
	_build_fishing_hole(landmarks)
	_build_sunken_cut(landmarks)
	_build_trees(trees)
	_build_transitions(transitions)


func _build_path(parent: Node3D) -> void:
	for i in PATH_POINTS.size() - 1:
		_build_walk_segment(parent, PATH_POINTS[i], PATH_POINTS[i + 1],
			CORRIDOR_WIDTH, StringName("Main%02d" % i))

	# Round path insets bury the rectangular visual overlaps at each turn. They
	# are deliberately non-colliding: a horizontal collider laid over two sloped
	# runs creates a lip at its downhill edge even though all three top faces meet
	# exactly at the authored point.
	for i in range(1, PATH_POINTS.size() - 1):
		var point: Vector3 = PATH_POINTS[i]
		_cylinder(parent, StringName("LandingPath%02d" % i), MAT_PATH,
			PATH_WIDTH * 0.54, 0.07, _at(point + Vector3.UP * 0.035), false, 12)

	# The spur is obvious from the vista and now reaches the spring-fed pool before
	# the original blocked continuation. Its independent slab gives it a real
	# downhill grade rather than painted dirt.
	_build_walk_segment(parent, Vector3(2.5, 3.4, -5.0),
		Vector3(18.2, 1.9, -1.85), 4.8, &"BlockedSpur")
	# Keep the named visual seam the outskirts proof already photographs, but put
	# it on the far bank where it now reads behind the pool. `blocked_path` below
	# remains the physical stop and transition authority a little farther on.
	var barricade := _group(parent, &"BlockedSpurBarricade")
	barricade.position = Vector3(15.25, 2.2, -2.50)
	_box(barricade, &"CrossTimberA", MAT_WOOD, Vector3(4.5, 0.28, 0.30),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(24.0)),
			Vector3(0.0, 1.35, 0.0)), false)
	_box(barricade, &"CrossTimberB", MAT_WOOD, Vector3(4.5, 0.28, 0.30),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-24.0)),
			Vector3(0.0, 1.25, 0.08)), false)


func _build_walk_segment(parent: Node3D, from: Vector3, to: Vector3,
		ground_width: float, segment_name: StringName) -> void:
	var delta := to - from
	var basis := Basis.looking_at(delta.normalized(), Vector3.UP)
	var midpoint := (from + to) * 0.5
	var length := delta.length() + 1.2
	_box(parent, StringName("%sGround" % segment_name), MAT_GRASS,
		Vector3(ground_width, GROUND_DEPTH, length),
		Transform3D(basis, midpoint - basis.y * GROUND_DEPTH * 0.5), true)
	_box(parent, StringName("%sPath" % segment_name), MAT_PATH,
		Vector3(PATH_WIDTH, 0.07, length),
		Transform3D(basis, midpoint + basis.y * 0.035), false)


func _build_cliffs(parent: Node3D) -> void:
	for i in PATH_POINTS.size() - 1:
		var from: Vector3 = PATH_POINTS[i]
		var to: Vector3 = PATH_POINTS[i + 1]
		var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
		var forward := flat.normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var midpoint := (from + to) * 0.5
		var yaw := atan2(forward.x, forward.z) + PI
		var basis := Basis(Vector3.UP, yaw)
		for side: float in [-1.0, 1.0]:
			var height := CLIFF_HEIGHT + float((i + int(side > 0.0)) % 3) * 0.65
			var centre := midpoint + right * side \
				* (CORRIDOR_WIDTH * 0.5 + CLIFF_THICKNESS * 0.5 - 0.15)
			centre.y = minf(from.y, to.y) - 1.2 + height * 0.5
			var side_name := "R" if side > 0.0 else "L"
			_box(parent, StringName("Cliff%s%02d" % [side_name, i]), MAT_CLIFF,
				Vector3(CLIFF_THICKNESS, height, flat.length() + 4.0),
				Transform3D(basis, centre), true)

	# Faceted outcrops seal the outside corners of the switchbacks. Without them,
	# two correct segment colliders still leave a diagonal body-width crack.
	for i in PATH_POINTS.size():
		var before: Vector3 = PATH_POINTS[maxi(i - 1, 0)]
		var after: Vector3 = PATH_POINTS[mini(i + 1, PATH_POINTS.size() - 1)]
		var tangent := Vector3(after.x - before.x, 0.0, after.z - before.z).normalized()
		var right := tangent.cross(Vector3.UP).normalized()
		for side: float in [-1.0, 1.0]:
			var height := CLIFF_HEIGHT + float((i + 1) % 2) * 0.8
			var at := PATH_POINTS[i] + right * side * 7.35
			at.y = PATH_POINTS[i].y - 1.1 + height * 0.5
			_cylinder(parent, StringName("Outcrop%02d%s" % [i,
				"R" if side > 0.0 else "L"]), MAT_CLIFF, 2.9, height,
				_at(at, float(i) * 0.19), true, 7)

	# This shoulder hides the lower run from the gate. The path slips left around
	# it; only at the fourth point does the mouth of the Cut enter the frame.
	_box(parent, &"VistaBlind", MAT_CLIFF, Vector3(7.8, 11.0, 11.5),
		_at(Vector3(3.0, 8.0, 8.4), deg_to_rad(-8.0)), true)


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


func _build_timber_yard(parent: Node3D) -> void:
	timber_yard = TimberYard.new()
	timber_yard.name = &"TimberYard"
	timber_yard.transform = port(&"timber_yard")
	parent.add_child(timber_yard)


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
	for i in TREE_SPECS.size():
		var spec: Vector4 = TREE_SPECS[i]
		var tree := _group(parent, StringName("Tree%02d" % i))
		tree.position = Vector3(spec.x, spec.y, spec.z)
		tree.rotation.y = float(i) * 0.73
		var scale_factor := spec.w
		_cylinder(tree, &"Trunk", MAT_WOOD, 0.24 * scale_factor,
			3.5 * scale_factor, _at(Vector3.UP * 1.75 * scale_factor), true, 7)
		# The path geometry stays deliberately primitive, but the foliage uses the
		# same CC0 Kenney silhouettes Valenfeld's forest biome already proved.
		var packed: PackedScene = TREE_SHRUB if i % 3 == 2 else TREE_LARGE
		var model := packed.instantiate() as Node3D
		model.name = &"ValenfeldTree"
		model.scale = Vector3.ONE * (3.2 * scale_factor)
		tree.add_child(model)


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

	# The port and refusal remain the contract for the dead route, now authored on
	# the far bank beyond the pool. The big rubble slab is the fixed collision;
	# crossed timber and loose stones in front remain visual-only.
	_box(blocked_path, &"CollapseBackstop", MAT_DARK_STONE,
		Vector3(5.0, 3.3, 1.0), _at(Vector3(0.0, 1.55, -2.25)), true)
	var obstruction := _group(blocked_path, &"ObstructionVisual")
	_box(obstruction, &"RubbleLeft", MAT_DARK_STONE, Vector3(2.2, 1.45, 1.25),
		_at(Vector3(-1.25, 0.7, -1.65), -0.18), false)
	_box(obstruction, &"RubbleRight", MAT_DARK_STONE, Vector3(2.4, 1.8, 1.15),
		_at(Vector3(1.1, 0.85, -1.7), 0.23), false)
	_box(obstruction, &"CrossTimberA", MAT_WOOD, Vector3(5.2, 0.3, 0.34),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(18.0)),
			Vector3(0.0, 1.75, -1.35)), false)
	_box(obstruction, &"CrossTimberB", MAT_WOOD, Vector3(4.7, 0.28, 0.31),
		Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-22.0)),
			Vector3(0.15, 1.55, -1.18)), false)
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
