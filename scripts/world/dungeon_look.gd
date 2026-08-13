extends RefCounted
## Runtime-only visual identity for authored dungeon tint keys.
##
## This layer is deliberately downstream of generation and population: it reads
## stable room facts and never touches the generator's RNG, collision, or layout.

const WALL_TEXTURE: Texture2D = preload(
	"res://assets/valenfeld/cistern/Textures/cistern_wall_soft.png")
const STRUCTURE_TEXTURE: Texture2D = preload(
	"res://assets/valenfeld/cistern/Textures/cistern_wall.png")
const FLOOR_TEXTURE: Texture2D = preload(
	"res://assets/valenfeld/cistern/Textures/cistern_floor.png")
const MOSS_TEXTURE: Texture2D = preload(
	"res://assets/valenfeld/cistern/Textures/cistern_moss.png")
const WATER_TEXTURE: Texture2D = preload(
	"res://assets/valenfeld/cistern/Textures/water.png")
const WATER_SCENE: PackedScene = preload(
	"res://assets/valenfeld/cistern/water.glb")
const COLUMN_SCENE: PackedScene = preload(
	"res://assets/valenfeld/cistern/column-damaged.glb")
const HOIST_SCENE: PackedScene = preload(
	"res://assets/valenfeld/cistern/pulley-crate.glb")

const CARDINALS: Array[StringName] = [&"n", &"e", &"s", &"w"]
const WALL_UV_SCALE := Vector3(0.12, 0.12, 0.12)
const FLOOR_UV_SCALE := Vector3(0.16, 0.16, 0.16)
const PROP_UV_SCALE := Vector3.ONE
const BAY_INSET := 0.45
const RUNNEL_LENGTH := 4.8


static func apply(dungeon: Node3D, level: int, rooms: Dictionary) -> void:
	# The manifest key is the routing seam; levels are allowed to move between
	# looks without teaching this visual layer about floor numbers.
	match FloorDb.tint_key(level):
		&"drowned_bronze":
			_apply_drowned_bronze(dungeon, level, rooms)
		_:
			return


static func _apply_drowned_bronze(dungeon: Node3D, level: int,
		rooms: Dictionary) -> void:
	var tint: Dictionary = FloorDb.tint(level)
	var materials: Dictionary = _make_materials()
	_retint_atmosphere(dungeon, tint)
	_retint_kit(dungeon, tint, materials)

	var look := Node3D.new()
	look.name = &"CisternLook"
	dungeon.add_child(look)
	_dress_rooms(dungeon, look, rooms, materials)
	_dress_corridors(dungeon, look, materials)


static func _retint_atmosphere(dungeon: Node3D, tint: Dictionary) -> void:
	var scene_root: Node = dungeon.get_parent()
	if scene_root == null:
		return
	var world: WorldEnvironment = null
	var fill: DirectionalLight3D = null
	for node: Node in _tree(scene_root):
		if world == null and node is WorldEnvironment:
			world = node as WorldEnvironment
		elif fill == null and node is DirectionalLight3D and node.name == &"Fill":
			fill = node as DirectionalLight3D

	# The scene resource is shared by every floor. The instance gets its own copy
	# before any floor-specific values are written.
	if world != null and world.environment != null:
		var environment := world.environment.duplicate(true) as Environment
		world.environment = environment
		var air: Color = tint.get("air", Color(0.1255, 0.1569, 0.1882))
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = air
		environment.ambient_light_color = tint.get("ambient", Color(0.30, 0.34, 0.47))
		environment.ambient_light_energy = float(tint.get("ambient_energy", 0.38))
		environment.fog_enabled = true
		environment.fog_light_color = air
		var fog_density := float(tint.get("fog_density", 0.0062))
		environment.fog_density = fog_density
		environment.volumetric_fog_density = fog_density
		# The inherited volume was warm enough to turn every nominally cool surface
		# sepia. Drowned Bronze uses blue-grey particulate air so warm pools remain
		# local keys instead of becoming a full-screen colour grade.
		environment.volumetric_fog_albedo = Color(
			air.r * 2.8, air.g * 2.8, air.b * 2.8, 1.0)
		environment.adjustment_brightness = 1.06
		environment.adjustment_contrast = 1.08
		environment.adjustment_saturation = 1.0
		environment.ssao_enabled = false
		environment.glow_enabled = false

	if fill != null:
		fill.light_color = tint.get("fill", Color(0.58, 0.80, 0.96))
		fill.light_energy = 0.32
		fill.light_specular = 0.0

	# Progression doors and stairs own other OmniLight colours. Only the authored
	# torch class is part of the floor palette, and its energy remains untouched.
	var fire: Color = tint.get("fire", Color(1.0, 0.74, 0.46))
	for node: Node in _tree(dungeon):
		if node is KitTorch:
			(node as KitTorch).light_color = fire


static func _retint_kit(dungeon: Node3D, tint: Dictionary,
		materials: Dictionary) -> void:
	var stone: Color = tint.get("stone", Color.WHITE)
	var wall_material: StandardMaterial3D = materials[&"wall"]
	var structure_material: StandardMaterial3D = materials[&"structure"]
	var floor_material: StandardMaterial3D = materials[&"floor"]
	var ceiling_material: StandardMaterial3D = materials[&"ceiling"]
	wall_material.albedo_color *= stone
	structure_material.albedo_color *= stone
	floor_material.albedo_color *= stone
	ceiling_material.albedo_color *= stone

	for node: Node in _tree(dungeon):
		if node is KitWall:
			(node as KitWall).material = materials[&"wall"]
		elif node is KitDoorway:
			(node as KitDoorway).material = materials[&"structure"]
		elif node is KitPillar:
			(node as KitPillar).material = materials[&"structure"]
		elif node is KitSlab:
			var slab := node as KitSlab
			slab.edge_material = materials[&"wall"]
			slab.face_material = materials[&"ceiling"] if slab.ceiling \
				else materials[&"floor"]
		elif node is Lantern:
			_retint_lantern(node as Lantern)


static func _retint_lantern(lantern: Lantern) -> void:
	# Keep the flame's gold/midnight state legible, but fold the cage itself into
	# Drowned Bronze so a grid reads as a puzzle rather than a red prop explosion.
	for node: Node in _tree(lantern):
		if not node is MeshInstance3D:
			continue
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface: int in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface) as StandardMaterial3D
			if material != null and material.emission_enabled \
					and material.emission.is_equal_approx(Pal.RUST):
				material.emission = Color(0.30, 0.19, 0.10)
				material.albedo_color = Color(0.16, 0.10, 0.07)


static func _make_materials() -> Dictionary:
	var materials: Dictionary = {}
	materials[&"wall"] = _material(WALL_TEXTURE,
		Color(0.95, 1.08, 1.20), true, WALL_UV_SCALE)
	materials[&"structure"] = _material(STRUCTURE_TEXTURE,
		Color(0.95, 1.08, 1.20), true, WALL_UV_SCALE)
	materials[&"floor"] = _material(FLOOR_TEXTURE,
		Color(0.52, 0.62, 0.64), true, FLOOR_UV_SCALE)
	materials[&"ceiling"] = _material(WALL_TEXTURE,
		Color(0.75, 0.86, 0.96), true, WALL_UV_SCALE)
	materials[&"moss"] = _material(MOSS_TEXTURE,
		Color(0.30, 0.38, 0.36), true, WALL_UV_SCALE)
	materials[&"water"] = _material(WATER_TEXTURE,
		Color(0.34, 0.48, 0.52), false, PROP_UV_SCALE)
	materials[&"bronze"] = _material(null,
		Color(0.15, 0.12, 0.095), false, PROP_UV_SCALE)
	materials[&"bronze_wear"] = _material(null,
		Color(0.29, 0.23, 0.15), false, PROP_UV_SCALE)
	materials[&"verdigris"] = _material(null,
		Color(0.13, 0.20, 0.18), false, PROP_UV_SCALE)
	materials[&"mineral"] = _material(null,
		Color(0.44, 0.50, 0.47), false, PROP_UV_SCALE)
	materials[&"drain_metal"] = _material(null,
		Color(0.38, 0.36, 0.30), false, PROP_UV_SCALE)
	materials[&"recess"] = _material(null,
		Color(0.035, 0.050, 0.060), false, PROP_UV_SCALE)
	materials[&"source_cache"] = {}
	return materials


static func _material(texture: Texture2D, color: Color, triplanar: bool,
		uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = color
	_configure_material(material, triplanar, uv_scale)
	return material


static func _configure_material(material: StandardMaterial3D,
		triplanar: bool, uv_scale: Vector3) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.roughness = 1.0
	material.normal_enabled = false
	material.normal_texture = null
	material.emission_enabled = false
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.texture_repeat = true
	material.uv1_scale = uv_scale
	material.uv1_triplanar = triplanar
	material.uv1_world_triplanar = triplanar


static func _dress_rooms(dungeon: Node3D, look: Node3D, rooms: Dictionary,
		materials: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(rooms[a]["index"]) < int(rooms[b]["index"]))

	var deepest_cell := Vector2i.ZERO
	var deepest_distance := -1
	var gate_cell: Variant = null
	var placements: Dictionary = dungeon.get(&"placements")
	if placements.has(&"gate_room"):
		gate_cell = placements[&"gate_room"].get("cell")
	for cell: Vector2i in cells:
		var room: Dictionary = rooms[cell]
		var distance := int(room["dist"])
		if distance > deepest_distance:
			deepest_distance = distance
			deepest_cell = cell

	for cell: Vector2i in cells:
		var room: Dictionary = rooms[cell]
		var index := int(room["index"])
		var side: StringName = _quiet_side(cell, room)
		var lateral := _bay_offset(cell, room, side)
		var full_frame: bool = index == 0 or cell == deepest_cell \
			or (gate_cell != null and cell == gate_cell)
		if gate_cell != null and cell == gate_cell:
			# Gate prefabs own the room centre. Wrap the hydraulic frame onto the
			# adjoining wall and tuck it into the quiet corner so both silhouettes
			# remain readable from the playable route.
			var gate_corner := _gate_corner(room, side)
			side = gate_corner[&"side"]
			lateral = gate_corner[&"lateral"]
		elif not full_frame and float(room.get("size", 16.0)) >= 24.0:
			lateral = _ordinary_route_corner(room, side)
		_build_bay(look, cell, room, side, lateral, full_frame, materials)


static func _quiet_side(cell: Vector2i, room: Dictionary) -> StringName:
	var doors: Array = room.get("doors", [])
	var anchors: Dictionary = room.get("anchors", {})
	var index := int(room.get("index", 0))
	var first := posmod(index + cell.x * 3 + cell.y * 5, CARDINALS.size())
	for offset: int in CARDINALS.size():
		var side: StringName = CARDINALS[(first + offset) % CARDINALS.size()]
		if index == 0 and side == &"s":
			continue
		if not doors.has(side) and not anchors.has(side):
			return side
	# The entrance can have a hole on all four sides. It still uses the stable
	# priority, then shifts the bay out of the doorway lane below.
	return CARDINALS[first]


static func _gate_corner(room: Dictionary, quiet_side: StringName) -> Dictionary:
	var edge := maxf(float(room.get("size", 16.0)) * 0.5 - 3.1, 2.8)
	match quiet_side:
		&"n":
			return {&"side": &"e", &"lateral": -edge}
		&"s":
			return {&"side": &"e", &"lateral": -edge}
		&"e":
			return {&"side": &"n", &"lateral": edge}
		_:
			return {&"side": &"n", &"lateral": -edge}


static func _bay_offset(cell: Vector2i, room: Dictionary,
		side: StringName) -> float:
	var doors: Array = room.get("doors", [])
	var anchors: Dictionary = room.get("anchors", {})
	if int(room.get("index", 0)) == 0 and side == &"s":
		return maxf(float(room.get("size", 16.0)) * 0.5 - 3.1, 2.8)
	if not doors.has(side) and not anchors.has(side):
		return 0.0
	var size := float(room.get("size", 16.0))
	var sign_value := -1.0 if posmod(cell.x + cell.y + int(room["index"]), 2) == 0 \
		else 1.0
	return sign_value * maxf(size * 0.5 - 3.1, 2.8)


static func _ordinary_route_corner(room: Dictionary, side: StringName) -> float:
	var size := float(room.get("size", 16.0))
	var edge := maxf(size * 0.5 - 3.1, 2.8)
	var yaw := float(_wall(size, side)["yaw"])
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var strongest := 0.0
	for door: StringName in room.get("doors", []):
		var toward := Vector3.ZERO
		match door:
			&"n": toward = Vector3(0.0, 0.0, -1.0)
			&"s": toward = Vector3(0.0, 0.0, 1.0)
			&"w": toward = Vector3(-1.0, 0.0, 0.0)
			_: toward = Vector3(1.0, 0.0, 0.0)
		var alignment := along.dot(toward)
		if absf(alignment) > absf(strongest):
			strongest = alignment
	return signf(strongest) * edge if not is_zero_approx(strongest) else 0.0


static func _build_bay(look: Node3D, cell: Vector2i, room: Dictionary,
		side: StringName, lateral: float, full_frame: bool,
		materials: Dictionary) -> void:
	var room_node := room.get("node") as Node3D
	if room_node == null:
		return
	var wall: Dictionary = _wall(float(room.get("size", 16.0)), side)
	var yaw := float(wall["yaw"])
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var inward := Vector3(sin(yaw), 0.0, cos(yaw))

	# Each room gets its own namespace so the proof-facing semantic names stay
	# exact instead of Godot silently renaming sibling `CisternBay` nodes.
	var room_look := Node3D.new()
	room_look.name = "RoomLook_%02d" % int(room["index"])
	look.add_child(room_look)
	_damp_course(room_look, room_node.position, float(room.get("size", 16.0)),
		int(room["index"]), materials[&"moss"])
	var bay := Node3D.new()
	bay.name = &"CisternBay"
	bay.position = room_node.position + (wall["at"] as Vector3) \
		+ along * lateral + inward * BAY_INSET
	bay.rotation.y = yaw
	bay.set_meta(&"cell", cell)
	bay.set_meta(&"room_index", int(room["index"]))
	bay.set_meta(&"side", side)
	bay.set_meta(&"lateral", lateral)
	room_look.add_child(bay)

	# Every added element stays in the wall's 1.5 m perimeter band and has no
	# collision, leaving the room's central combat and doorway space unchanged.
	_box(bay, &"MineralStain", Vector3(5.6, 0.82, 0.06),
		Vector3(0.0, 0.52, -0.39), materials[&"moss"])
	_chipped_lip(bay, "WallLip", -0.12, int(room["index"]), 0,
		materials[&"structure"])
	_chipped_lip(bay, "WalkLip", 1.03, int(room["index"]), 1,
		materials[&"structure"])

	var water := WATER_SCENE.instantiate() as Node3D
	if water != null:
		water.name = &"WaterRunnel"
		water.position = Vector3(RUNNEL_LENGTH * 0.5, 0.04, 0.0)
		water.scale = Vector3(RUNNEL_LENGTH, 0.20, 1.0)
		_sanitize_import(water, materials[&"water"], materials)
		bay.add_child(water)

	if full_frame:
		_overflow_frame(bay, int(room["index"]), materials)
	else:
		_ordinary_structure(bay, int(room["index"]), materials)


static func _damp_course(room_look: Node3D, room_position: Vector3,
		room_size: float, room_index: int, material: StandardMaterial3D) -> void:
	var course := Node3D.new()
	course.name = &"DampCourse"
	room_look.add_child(course)
	var doorway_gap := 3.4
	var half_length := (room_size - doorway_gap) * 0.5 - 0.15
	for side_index: int in CARDINALS.size():
		var side: StringName = CARDINALS[side_index]
		var wall: Dictionary = _wall(room_size, side)
		var yaw := float(wall["yaw"])
		var inward := Vector3(sin(yaw), 0.0, cos(yaw))
		var side_course := Node3D.new()
		side_course.name = "Damp_%s" % side
		side_course.position = room_position + (wall["at"] as Vector3) + inward * 0.08
		side_course.rotation.y = yaw
		course.add_child(side_course)
		for half_index: int in 2:
			var direction := -1.0 if half_index == 0 else 1.0
			var gap_a := 0.10 + float(posmod(room_index + side_index + half_index, 3)) * 0.025
			var gap_b := 0.10 + float(posmod(room_index * 2 + side_index + half_index, 3)) * 0.025
			var usable_length := half_length - gap_a - gap_b
			var base_length := usable_length / 3.0
			var length_bias := float(posmod(room_index + side_index * 2 + half_index, 3) - 1) * 0.16
			var cursor := doorway_gap * 0.5
			for segment: int in 3:
				var length := base_length
				if segment == 0:
					length += length_bias
				elif segment == 1:
					length -= length_bias * 0.35
				else:
					length -= length_bias * 0.65
				var seed := room_index * 17 + side_index * 7 + half_index * 3 + segment * 5
				var height := 0.54 + float(posmod(seed, 6)) * 0.095
				var base := 0.015 + float(posmod(seed + 2, 4)) * 0.028
				var depth := 0.07 + float(posmod(seed + 1, 3)) * 0.012
				var x := direction * (cursor + length * 0.5)
				var z := float(posmod(seed, 3) - 1) * 0.012
				_box(side_course,
					StringName("DampSegment_%d_%d" % [half_index, segment]),
					Vector3(length, height, depth),
					Vector3(x, base + height * 0.5, z), material)
				cursor += length
				if segment == 0:
					cursor += gap_a
				elif segment == 1:
					cursor += gap_b


static func _chipped_lip(bay: Node3D, prefix: String, z: float,
		room_index: int, lip_index: int, material: StandardMaterial3D) -> void:
	var cursor := -2.615
	for segment: int in 4:
		var length_step := posmod(room_index * 2 + lip_index + segment, 2)
		var length := 1.17 + float(length_step) * 0.04
		var height_step := posmod(room_index + lip_index * 2 + segment, 3)
		var height := 0.22 + float(height_step) * 0.055
		_box(bay, StringName("%s_%d" % [prefix, segment]),
			Vector3(length, height, 0.18), Vector3(cursor + length * 0.5, height * 0.5, z),
			material)
		cursor += length
		if segment < 3:
			var gap_step := posmod(room_index + lip_index + segment, 3)
			cursor += 0.09 + float(gap_step) * 0.02


static func _overflow_frame(bay: Node3D, room_index: int,
		materials: Dictionary) -> void:
	var frame := Node3D.new()
	frame.name = &"OverflowFrame"
	bay.add_child(frame)
	# A dark hydraulic mouth makes the paired piers one readable silhouette; it
	# also keeps the imported columns from dissolving into the same wall texture.
	_box(frame, &"OverflowMouth", Vector3(4.35, 2.45, 0.10),
		Vector3(0.0, 1.27, -0.36), materials[&"recess"])
	_box(frame, &"OverflowSpill", Vector3(1.15, 1.92, 0.08),
		Vector3(0.0, 0.98, -0.29), materials[&"water"])
	for x: float in [-2.05, 2.05]:
		var column := COLUMN_SCENE.instantiate() as Node3D
		if column == null:
			continue
		column.name = &"OverflowPier"
		column.position = Vector3(x, 0.0, 0.40)
		column.scale = Vector3.ONE * 3.4
		_sanitize_import(column, materials[&"structure"], materials)
		frame.add_child(column)
		var suffix := "L" if x < 0.0 else "R"
		_box(frame, StringName("OverflowFoot_%s" % suffix),
			Vector3(0.98, 0.34, 0.86), Vector3(x, 0.17, 0.40),
			materials[&"structure"])
		_box(frame, StringName("OverflowCap_%s" % suffix),
			Vector3(0.92, 0.28, 0.80), Vector3(x, 2.88, 0.40),
			materials[&"structure"])
	var lintel := _box(frame, &"BronzeLintel", Vector3(5.05, 0.52, 0.62),
		Vector3(0.0, 3.18, 0.14), materials[&"bronze"])
	# The beam is assembled around the stone caps, not painted across them. Dark
	# bronze carries the mass; small collars and a worn lower edge expose the load.
	for joint_x: float in [-1.42, 1.42]:
		_box(frame, &"LintelJoint", Vector3(0.16, 0.60, 0.68),
			Vector3(joint_x, 3.18, 0.14), materials[&"bronze_wear"])
	_box(frame, &"LintelWearEdge", Vector3(4.35, 0.055, 0.66),
		Vector3(0.0, 2.91, 0.14), materials[&"bronze_wear"])
	if room_index != 0:
		var condition_sign := -1.0 if room_index % 2 == 0 else 1.0
		lintel.rotation.z = condition_sign * 0.065
		_box(frame, &"StrippedLintelPatch", Vector3(0.46, 0.07, 0.34),
			Vector3(condition_sign * 1.62, 3.45, 0.14),
			materials[&"verdigris"])
		var brace := _box(frame, &"BentHoistBrace", Vector3(0.10, 0.62, 0.12),
			Vector3(condition_sign * 0.32, 2.87, 0.43), materials[&"bronze"])
		brace.rotation.z = condition_sign * 0.22

	var hoist := HOIST_SCENE.instantiate() as Node3D
	if hoist != null:
		hoist.name = &"OverflowHoist"
		hoist.position = Vector3(0.0, 3.15, 0.46)
		hoist.scale = Vector3.ONE * 2.20
		_sanitize_import(hoist, null, materials)
		frame.add_child(hoist)
	var pulley := MeshInstance3D.new()
	pulley.name = &"OverflowPulley"
	var pulley_mesh := TorusMesh.new()
	pulley_mesh.inner_radius = 0.14
	pulley_mesh.outer_radius = 0.25
	pulley_mesh.rings = 8
	pulley_mesh.ring_segments = 6
	pulley.mesh = pulley_mesh
	pulley.position = Vector3(0.0, 3.03, 0.47)
	pulley.rotation.x = PI * 0.5
	pulley.material_override = materials[&"bronze_wear"]
	pulley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(pulley)
	_box(frame, &"HoistRopeLead", Vector3(1.16, 0.055, 0.055),
		Vector3(-0.58, 3.03, 0.47), materials[&"bronze"])
	var grip_position := _overflow_bucket(frame, room_index, materials)
	var chain_top := Vector3(0.0, 3.04, 0.43)
	var chain_delta := chain_top - grip_position
	var chain := _box(frame, &"HoistChain",
		Vector3(0.07, chain_delta.length(), 0.07),
		(grip_position + chain_top) * 0.5, materials[&"bronze"])
	chain.rotation.z = -atan2(chain_delta.x, chain_delta.y)


static func _overflow_bucket(frame: Node3D, room_index: int,
		materials: Dictionary) -> Vector3:
	var bucket := Node3D.new()
	bucket.name = &"OverflowBucket"
	var bucket_height := 1.45 if room_index == 0 \
		else 0.54 + float(posmod(room_index, 2)) * 0.10
	var bucket_tilt := 0.0 if room_index == 0 \
		else (-0.075 if room_index % 2 == 0 else 0.075)
	bucket.position = Vector3(0.0, bucket_height, 0.43)
	bucket.rotation.z = bucket_tilt
	frame.add_child(bucket)

	var basin := MeshInstance3D.new()
	basin.name = &"BucketBasin"
	var basin_mesh := CylinderMesh.new()
	basin_mesh.top_radius = 0.38
	basin_mesh.bottom_radius = 0.27
	basin_mesh.height = 0.58
	basin_mesh.radial_segments = 6
	basin_mesh.cap_top = false
	basin.mesh = basin_mesh
	basin.material_override = materials[&"bronze"]
	basin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bucket.add_child(basin)

	var interior := MeshInstance3D.new()
	interior.name = &"BucketInterior"
	var interior_mesh := CylinderMesh.new()
	interior_mesh.top_radius = 0.31
	interior_mesh.bottom_radius = 0.31
	interior_mesh.height = 0.035
	interior_mesh.radial_segments = 6
	interior.mesh = interior_mesh
	interior.position.y = 0.245
	interior.material_override = materials[&"recess"]
	interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bucket.add_child(interior)

	for side: float in [-1.0, 1.0]:
		var bail := _box(bucket,
			StringName("BucketBail_%s" % ("L" if side < 0.0 else "R")),
			Vector3(0.052, 0.34, 0.052), Vector3(side * 0.285, 0.42, 0.0),
			materials[&"bronze"])
		bail.rotation.z = side * 0.13
	_box(bucket, &"BucketBailGrip", Vector3(0.60, 0.055, 0.055),
		Vector3(0.0, 0.59, 0.0), materials[&"bronze"])
	var rim := MeshInstance3D.new()
	rim.name = &"BucketRim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.32
	rim_mesh.outer_radius = 0.39
	rim_mesh.rings = 6
	rim_mesh.ring_segments = 4
	rim.mesh = rim_mesh
	rim.position.y = 0.255
	rim.material_override = materials[&"bronze"]
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bucket.add_child(rim)
	for patch_index: int in 2:
		_box(bucket, StringName("VerdigrisPatch_%d" % patch_index),
			Vector3(0.11, 0.026, 0.045),
			Vector3(-0.20 + float(patch_index) * 0.37, 0.273, 0.35),
			materials[&"verdigris"])
	return bucket.position + Vector3(
		-sin(bucket_tilt) * 0.59, cos(bucket_tilt) * 0.59, 0.0)


static func _ordinary_structure(bay: Node3D, index: int,
		materials: Dictionary) -> void:
	var drain := Node3D.new()
	drain.name = &"ServiceDrain"
	var drain_x := 0.72 if index % 2 == 0 else -0.72
	drain.position.x = drain_x
	bay.add_child(drain)
	_box(drain, &"DrainRunoff", Vector3(0.84, 1.62, 0.055),
		Vector3(0.0, 2.49, -0.385), materials[&"moss"])
	_box(drain, &"DrainWetTrail", Vector3(1.20, 1.94, 0.058),
		Vector3(0.0, 2.55, -0.39), materials[&"mineral"])
	_box(drain, &"DrainMouth", Vector3(2.22, 1.82, 0.08),
		Vector3(0.0, 0.98, -0.34), materials[&"recess"])
	_box(drain, &"DrainSpill", Vector3(0.82, 1.55, 0.06),
		Vector3(0.0, 0.76, -0.27), materials[&"water"])
	_box(drain, &"DrainApron", Vector3(0.86, 0.05, 0.92),
		Vector3(0.0, 0.055, 0.08), materials[&"water"])
	_box(drain, &"DrainLintel", Vector3(2.38, 0.24, 0.24),
		Vector3(0.0, 1.94, -0.16), materials[&"drain_metal"])
	for side: float in [-1.0, 1.0]:
		_box(drain, StringName("DrainCheek_%s" % ("L" if side < 0.0 else "R")),
			Vector3(0.26, 1.72, 0.24), Vector3(side * 1.06, 0.98, -0.16),
			materials[&"structure"])
	for slat: int in 3:
		_box(drain, StringName("DrainBar_%d" % slat), Vector3(0.085, 1.44, 0.10),
			Vector3((float(slat) - 1.0) * 0.36, 0.98, -0.20),
			materials[&"drain_metal"])
	if index % 2 == 0:
		_box(bay, &"StructuralPier", Vector3(0.72, 2.15, 0.62),
			Vector3(-2.05, 1.075, 0.10), materials[&"structure"])
	else:
		_box(bay, &"LintelFragment", Vector3(2.35, 0.42, 0.58),
			Vector3(1.30, 2.25, 0.10), materials[&"structure"])


static func _dress_corridors(dungeon: Node3D, look: Node3D,
		materials: Dictionary) -> void:
	var corridors: Array[Node3D] = []
	for child: Node in dungeon.get_children():
		if child is Node3D and child.name.begins_with("Corr_"):
			corridors.append(child as Node3D)
	corridors.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.name) < String(b.name))

	for corridor: Node3D in corridors:
		var slab: KitSlab = null
		for child: Node in corridor.get_children():
			if child is KitSlab and not (child as KitSlab).ceiling:
				slab = child as KitSlab
				break
		if slab == null:
			continue
		var drain := Node3D.new()
		drain.name = &"CorridorDrain"
		drain.transform = corridor.transform
		look.add_child(drain)
		var running_z := slab.size.y >= slab.size.x
		var length := maxf(slab.size.x, slab.size.y) - 0.8
		var width := minf(slab.size.x, slab.size.y)
		var size := Vector3(0.42, 0.055, length) if running_z \
			else Vector3(length, 0.055, 0.42)
		var position := Vector3(-width * 0.5 + 0.32, 0.03, 0.0) if running_z \
			else Vector3(0.0, 0.03, -width * 0.5 + 0.32)
		_box(drain, &"DrainageStrip", size, position, materials[&"water"])


static func _sanitize_import(root: Node3D, role_material: StandardMaterial3D,
		materials: Dictionary) -> void:
	_strip_collision(root)
	var source_cache: Dictionary = materials[&"source_cache"]
	for node: Node in _tree(root):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if role_material != null:
			mesh_instance.material_override = role_material
			continue
		if mesh_instance.mesh == null:
			mesh_instance.material_override = materials[&"bronze"]
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.get_active_material(surface)
			var sanitized := _sanitized_source(source, source_cache,
				materials[&"bronze"])
			mesh_instance.set_surface_override_material(surface, sanitized)


static func _sanitized_source(source: Material, cache: Dictionary,
		fallback: StandardMaterial3D) -> StandardMaterial3D:
	if not source is StandardMaterial3D:
		return fallback
	var key := str(source.get_instance_id())
	if cache.has(key):
		return cache[key]
	var material := source.duplicate(true) as StandardMaterial3D
	_configure_material(material, false, PROP_UV_SCALE)
	material.albedo_color = Color(
		material.albedo_color.r * 0.68,
		material.albedo_color.g * 0.64,
		material.albedo_color.b * 0.56,
		1.0)
	if material.albedo_texture == null and material.albedo_color.is_equal_approx(Color.WHITE):
		material.albedo_color = fallback.albedo_color
	cache[key] = material
	return material


static func _strip_collision(root: Node) -> void:
	for child: Node in root.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			child.free()
		else:
			_strip_collision(child)


static func _box(parent: Node3D, node_name: StringName, size: Vector3,
		position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _wall(size: float, side: StringName) -> Dictionary:
	var half := size * 0.5
	match side:
		&"n":
			return {"yaw": 0.0, "at": Vector3(0.0, 0.0, -half)}
		&"s":
			return {"yaw": PI, "at": Vector3(0.0, 0.0, half)}
		&"w":
			return {"yaw": PI * 0.5, "at": Vector3(-half, 0.0, 0.0)}
		_:
			return {"yaw": -PI * 0.5, "at": Vector3(half, 0.0, 0.0)}


static func _tree(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child: Node in root.get_children():
		nodes.append_array(_tree(child))
	return nodes
