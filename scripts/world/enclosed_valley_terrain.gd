class_name EnclosedValleyTerrain
extends Node3D
## Visual-only heightmap terrain shared by enclosed exterior sites.
##
## Three annular meshes spend vertices where the player can read them: a dense
## inward-facing cliff rim, a cheaper middle range, and a deliberately coarse
## skyline.  There is no geometry beneath the playable site and no collision;
## each room keeps ownership of its authored ground, movement, and boundaries.

const TERRAIN_SHADER: Shader = preload("res://assets/shaders/enclosed_valley_terrain.gdshader")

const INNER_ANGULAR_SEGMENTS := 128
const INNER_RADIAL_SEGMENTS := 16
## All band boundaries share the same angular vertices. Radial rows carry the
## actual outward LOD reduction; matching chords keep the horizon watertight.
const MID_ANGULAR_SEGMENTS := 128
const MID_RADIAL_SEGMENTS := 12
const FAR_ANGULAR_SEGMENTS := 128
const FAR_RADIAL_SEGMENTS := 8
const HEIGHTMAP_FLOOR := 0.10
const NORMAL_SAMPLE_METRES := 1.5
const LOD_SEAM_SKIRT_DEPTH := 1.5
const CLIFF_FACE_VERTICAL_SEGMENTS := 4
const CROWN_TREE_COUNT := 144

@export_range(20.0, 180.0, 1.0, "or_greater") var site_radius := 58.0
## Full side length represented by the square heightmap, in metres.
@export_range(160.0, 1200.0, 5.0, "or_greater") var world_span := 440.0
## Vertical datum for the terrain. Usually a little below the site's walkable Y.
@export_range(-80.0, 80.0, 0.5) var elevation := -9.0
@export_range(10.0, 180.0, 1.0, "or_greater") var height_scale := 38.0
@export_range(2.0, 30.0, 0.5, "or_greater") var inner_cliff_height := 20.0
@export_range(2.0, 30.0, 0.5, "or_greater") var inner_cliff_depth := 14.0
@export_range(-180.0, 180.0, 1.0) var yaw_degrees := 0.0
## Production rooms preload the three `.res` outputs of `bake_meshes`. The
## image-model heightmap is offline source art and is never decoded at runtime.
@export var baked_inner_mesh: ArrayMesh
@export var baked_mid_mesh: ArrayMesh
@export var baked_far_mesh: ArrayMesh

var _height_image: Image
var _visuals: Node3D
var _material: ShaderMaterial


func _ready() -> void:
	_rebuild()


## Reuses the same authored terrain around differently sized exterior rooms.
## `world_span_value` is the complete heightmap width, not its radius.
func configure_for_site(site_radius_value: float, world_span_value: float,
		elevation_value: float, yaw: float = 0.0) -> void:
	site_radius = maxf(site_radius_value, 20.0)
	world_span = maxf(world_span_value, site_radius * 2.0 + 80.0)
	elevation = elevation_value
	yaw_degrees = rad_to_deg(yaw)
	rotation.y = yaw
	if is_node_ready():
		_rebuild()


## Explicit rebuild hook for callers that tune exported height parameters at runtime.
func rebuild_terrain() -> void:
	if is_node_ready():
		_rebuild()


func triangle_count() -> int:
	var triangles := 0
	for mesh: ArrayMesh in [baked_inner_mesh, baked_mid_mesh, baked_far_mesh]:
		if mesh == null:
			continue
		for surface_index: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
	return triangles


## Offline bake API. A small `@tool` script can save each returned ArrayMesh with
## `ResourceSaver.save(mesh, "res://assets/terrain/enclosed_valley_<band>.res")`.
## Rooms then preload those resources into the three `baked_*_mesh` properties, so
## shipping scenes never read the heightmap or rebuild vertices at runtime.
static func bake_meshes(heightmap_texture: Texture2D, site_radius_value: float,
		world_span_value: float, elevation_value: float, height_scale_value: float = 38.0,
		cliff_height_value: float = 20.0,
		cliff_depth_value: float = 14.0, gorge_angle_value: float = PI * 0.75,
		gorge_width_value: float = 0.34906585) -> Dictionary[StringName, ArrayMesh]:
	var baker := EnclosedValleyTerrain.new()
	baker.site_radius = maxf(site_radius_value, 20.0)
	baker.world_span = maxf(world_span_value, baker.site_radius * 2.0 + 80.0)
	baker.elevation = elevation_value
	baker.height_scale = maxf(height_scale_value, 10.0)
	baker.inner_cliff_height = maxf(cliff_height_value, 2.0)
	baker.inner_cliff_depth = maxf(cliff_depth_value, 2.0)
	baker._height_image = heightmap_texture.get_image()
	var meshes: Dictionary[StringName, ArrayMesh] = {}
	if baker._height_image == null or baker._height_image.is_empty():
		baker.free()
		return meshes
	var extents := baker._ring_extents()
	meshes[&"inner"] = baker._build_ring_mesh(baker.site_radius, extents.x,
		INNER_ANGULAR_SEGMENTS, INNER_RADIAL_SEGMENTS, 0.0, true,
		gorge_angle_value, gorge_width_value, true)
	meshes[&"mid"] = baker._build_ring_mesh(extents.x, extents.y,
		MID_ANGULAR_SEGMENTS, MID_RADIAL_SEGMENTS, 0.5, false, 0.0, 0.0, true)
	meshes[&"far"] = baker._build_ring_mesh(extents.y, baker.world_span * 0.5,
		FAR_ANGULAR_SEGMENTS, FAR_RADIAL_SEGMENTS, 1.0, false, 0.0, 0.0, false)
	baker.free()
	return meshes


func _rebuild() -> void:
	rotation.y = deg_to_rad(yaw_degrees)
	_ensure_visuals()
	for child: Node in _visuals.get_children():
		child.free()
	_material = ShaderMaterial.new()
	_material.shader = TERRAIN_SHADER

	if baked_inner_mesh != null and baked_mid_mesh != null and baked_far_mesh != null:
		_add_mesh_instance(&"InnerCliffs", baked_inner_mesh, true)
		_add_mesh_instance(&"MidMountains", baked_mid_mesh, false)
		_add_mesh_instance(&"FarMountains", baked_far_mesh, false)
		_build_cliff_crown_forest(baked_inner_mesh)
		return
	push_error("EnclosedValleyTerrain requires all three baked meshes")


func _ring_extents() -> Vector2:
	var outer_radius := world_span * 0.5
	var inner_end := maxf(site_radius + 42.0, outer_radius * 0.36)
	var mid_end := maxf(inner_end + 52.0, outer_radius * 0.68)
	inner_end = minf(inner_end, outer_radius - 72.0)
	mid_end = minf(mid_end, outer_radius - 24.0)
	return Vector2(inner_end, mid_end)


func _ensure_visuals() -> void:
	_visuals = get_node_or_null(^"Visuals") as Node3D
	if _visuals == null:
		_visuals = Node3D.new()
		_visuals.name = &"Visuals"
		add_child(_visuals)


func _build_ring_mesh(inner_radius: float, outer_radius: float,
		angular_segments: int, radial_segments: int, lod_band: float,
		add_cliff_face: bool, opening_angle: float,
		opening_width: float, add_outer_skirt: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_stride := angular_segments + 1
	for radial_index: int in radial_segments + 1:
		var radial_t := float(radial_index) / float(radial_segments)
		var radius := lerpf(inner_radius, outer_radius, radial_t)
		for angular_index: int in angular_segments + 1:
			var angle := TAU * float(angular_index) / float(angular_segments)
			# Break the near edge into rock shelves while converging quickly to the
			# heightmap grid. The cliff no longer reads as a perfect retaining cylinder.
			var edge_blend := 1.0 - smoothstep(0.0, 0.18, radial_t) \
				if add_cliff_face else 0.0
			var vertex_radius := radius + _cliff_edge_offset(angle) * edge_blend
			var point := Vector2(cos(angle), sin(angle)) * vertex_radius
			_add_surface_vertex(surface, point, lod_band)

	for radial_index: int in radial_segments:
		for angular_index: int in angular_segments:
			var near_a := radial_index * vertex_stride + angular_index
			var near_b := near_a + 1
			var far_a := near_a + vertex_stride
			var far_b := far_a + 1
			# Godot treats clockwise winding as front-facing. This order presents the
			# heightfield to cameras inside/above the basin, never as an overhead shell.
			surface.add_index(near_a)
			surface.add_index(far_a)
			surface.add_index(near_b)
			surface.add_index(far_a)
			surface.add_index(far_b)
			surface.add_index(near_b)

	var ring_vertex_count := (radial_segments + 1) * (angular_segments + 1)
	if add_cliff_face:
		_add_inner_cliff_face(surface, inner_radius, angular_segments, lod_band,
			opening_angle, opening_width, ring_vertex_count)
	if add_outer_skirt:
		var skirt_first_index := ring_vertex_count
		if add_cliff_face:
			skirt_first_index += (angular_segments + 1) \
				* (CLIFF_FACE_VERTICAL_SEGMENTS + 1)
		_add_lod_seam_skirt(surface, outer_radius, angular_segments, lod_band,
			skirt_first_index)

	var mesh := ArrayMesh.new()
	surface.commit(mesh)
	return mesh


func _add_mesh_instance(node_name: StringName, mesh: ArrayMesh,
		casts_shadow: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	_visuals.add_child(instance)


func _build_cliff_crown_forest(source_mesh: ArrayMesh) -> void:
	# Four MultiMeshes replace hundreds of imported scene nodes. The crowns sample
	# the baked inner mesh itself, so shipping rooms never decode the heightmap.
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _plain_forest_material(Color(0.16, 0.09, 0.045))
	var crown_meshes: Array[CylinderMesh] = []
	for layer: int in 3:
		var crown := CylinderMesh.new()
		crown.top_radius = 0.03
		crown.bottom_radius = 0.90 - float(layer) * 0.13
		crown.height = 1.0
		crown.radial_segments = 7
		crown.material = _plain_forest_material(
			Color(0.055 + float(layer) * 0.012,
				0.14 + float(layer) * 0.018, 0.065))
		crown_meshes.append(crown)
	var baked_vertices := _mesh_vertices(source_mesh)
	var transforms: Array[Transform3D] = []
	for i: int in CROWN_TREE_COUNT:
		var angle := TAU * float(i) / float(CROWN_TREE_COUNT) \
			+ sin(float(i) * 2.17) * 0.035
		var radius := site_radius + 5.0 + float(i % 5) * 7.2 \
			+ sin(float(i) * 1.31) * 2.4
		var flat := Vector2(cos(angle), sin(angle)) * radius
		var ground_y := _nearest_baked_height(baked_vertices, flat)
		var height := 7.0 + float(i % 7) * 0.72
		var width := 0.84 + float((i * 3) % 5) * 0.055
		transforms.append(Transform3D(Basis.IDENTITY.scaled(
			Vector3(width, height, width)),
			Vector3(flat.x, ground_y + height * 0.5, flat.y)))
	_add_forest_multimesh(&"CliffForestTrunks", trunk_mesh, transforms)
	for layer: int in 3:
		var crowns: Array[Transform3D] = []
		for trunk: Transform3D in transforms:
			var height := trunk.basis.y.length()
			var width := trunk.basis.x.length()
			var layer_height := height * (0.34 - float(layer) * 0.035)
			var layer_width := width * (3.9 - float(layer) * 0.55)
			var base := trunk.origin - Vector3.UP * height * 0.5
			crowns.append(Transform3D(Basis.IDENTITY.scaled(
				Vector3(layer_width, layer_height, layer_width)),
				base + Vector3.UP * height * (0.48 + float(layer) * 0.20)))
		_add_forest_multimesh(StringName("CliffForestCrown%d" % layer),
			crown_meshes[layer], crowns)


func _add_forest_multimesh(node_name: StringName, mesh: Mesh,
		transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 270.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_visuals.add_child(instance)


func _mesh_vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	if mesh.get_surface_count() == 0:
		return vertices
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() > Mesh.ARRAY_VERTEX:
		vertices = arrays[Mesh.ARRAY_VERTEX]
	return vertices


func _nearest_baked_height(vertices: PackedVector3Array, point: Vector2) -> float:
	var best_distance := INF
	var best_y := elevation
	for vertex: Vector3 in vertices:
		var distance := Vector2(vertex.x, vertex.z).distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_y = vertex.y
	return best_y


func _plain_forest_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


## The bands now share identical angular boundary vertices; this short downward
## overlap is still cheap insurance against precision cracks at extreme distance.
func _add_lod_seam_skirt(surface: SurfaceTool, radius: float,
		angular_segments: int, lod_band: float, first_index: int) -> void:
	for angular_index: int in angular_segments + 1:
		var angle := TAU * float(angular_index) / float(angular_segments)
		var direction := Vector2(cos(angle), sin(angle))
		var point := direction * radius
		var top_y := _terrain_height_at(point.x, point.y)
		var outward_normal := Vector3(direction.x, 0.1, direction.y).normalized()
		var uv_x := float(angular_index) / float(angular_segments)
		for wall_y: float in [top_y, top_y - LOD_SEAM_SKIRT_DEPTH]:
			surface.set_normal(outward_normal)
			surface.set_uv(Vector2(uv_x, inverse_lerp(top_y - LOD_SEAM_SKIRT_DEPTH,
				top_y, wall_y)))
			surface.set_color(Color(clampf((top_y - elevation) / height_scale,
				0.0, 1.0), 1.0, lod_band, 1.0))
			surface.add_vertex(Vector3(point.x, wall_y, point.y))
	for angular_index: int in angular_segments:
		var top_a: int = first_index + angular_index * 2
		var bottom_a: int = top_a + 1
		var top_b: int = top_a + 2
		var bottom_b: int = top_a + 3
		surface.add_index(top_a)
		surface.add_index(top_b)
		surface.add_index(bottom_a)
		surface.add_index(bottom_a)
		surface.add_index(top_b)
		surface.add_index(bottom_b)


func _add_surface_vertex(surface: SurfaceTool, point: Vector2,
		lod_band: float) -> void:
	var y := _terrain_height_at(point.x, point.y)
	var normal := _normal_at(point.x, point.y)
	var normalized_height := clampf((y - elevation) / maxf(height_scale, 0.001), 0.0, 1.0)
	var slope := 1.0 - clampf(normal.y, 0.0, 1.0)
	surface.set_normal(normal)
	surface.set_uv(Vector2(0.5 + point.x / world_span,
		0.5 + point.y / world_span))
	surface.set_color(Color(normalized_height, slope, lod_band, 1.0))
	surface.add_vertex(Vector3(point.x, y, point.y))


func _add_inner_cliff_face(surface: SurfaceTool, radius: float,
		angular_segments: int, lod_band: float, opening_angle: float,
		opening_width: float, first_index: int) -> void:
	for angular_index: int in angular_segments + 1:
		var angle := TAU * float(angular_index) / float(angular_segments)
		var direction := Vector2(cos(angle), sin(angle))
		var edge_radius := radius + _cliff_edge_offset(angle)
		var edge_point := direction * edge_radius
		var top_y := _terrain_height_at(edge_point.x, edge_point.y)
		var bottom_y := top_y - inner_cliff_depth
		var uv_x := float(angular_index) / float(angular_segments)
		for vertical_index: int in CLIFF_FACE_VERTICAL_SEGMENTS + 1:
			var vertical_t := float(vertical_index) / float(CLIFF_FACE_VERTICAL_SEGMENTS)
			# Alternating inset ledges make the near wall read as fractured geology
			# from gameplay height. End rows stay exact at the authored lip/base.
			var ledge_profile := sin(vertical_t * PI)
			var ledge_offset := ledge_profile * (
				sin(angle * 7.0 + float(vertical_index) * 1.31) * 1.65
				+ sin(angle * 17.0 - float(vertical_index) * 0.83) * 0.70)
			var point := direction * (edge_radius + ledge_offset)
			var wall_y := lerpf(top_y, bottom_y, vertical_t)
			var inward_normal := Vector3(-direction.x,
				sin(angle * 9.0 + float(vertical_index) * 1.7) * 0.34,
				-direction.y).normalized()
			surface.set_normal(inward_normal)
			surface.set_uv(Vector2(uv_x, inverse_lerp(bottom_y, top_y, wall_y)))
			surface.set_color(Color(clampf((top_y - elevation) / height_scale,
				0.0, 1.0), 1.0, lod_band, 1.0))
			surface.add_vertex(Vector3(point.x, wall_y, point.y))

	for angular_index: int in angular_segments:
		var cell_angle := TAU * (float(angular_index) + 0.5) \
			/ float(angular_segments)
		if opening_width > 0.0 and _angle_distance(cell_angle,
				opening_angle) < opening_width * 0.5:
			continue
		for vertical_index: int in CLIFF_FACE_VERTICAL_SEGMENTS:
			var stride := CLIFF_FACE_VERTICAL_SEGMENTS + 1
			var top_a: int = first_index + angular_index * stride + vertical_index
			var bottom_a: int = top_a + 1
			var top_b: int = top_a + stride
			var bottom_b: int = top_b + 1
			# The inner wall faces the playable centre, opposite the terrain's radial face.
			# Godot's clockwise front face needs the complementary order to the top shell.
			surface.add_index(top_a)
			surface.add_index(top_b)
			surface.add_index(bottom_a)
			surface.add_index(bottom_a)
			surface.add_index(top_b)
			surface.add_index(bottom_b)


func _normal_at(x: float, z: float) -> Vector3:
	var left := _terrain_height_at(x - NORMAL_SAMPLE_METRES, z)
	var right := _terrain_height_at(x + NORMAL_SAMPLE_METRES, z)
	var back := _terrain_height_at(x, z - NORMAL_SAMPLE_METRES)
	var front := _terrain_height_at(x, z + NORMAL_SAMPLE_METRES)
	return Vector3(left - right, NORMAL_SAMPLE_METRES * 2.0,
		back - front).normalized()


func _terrain_height_at(x: float, z: float) -> float:
	var half_span := world_span * 0.5
	var sample_u := clampf(0.5 + x / world_span, 0.0, 1.0)
	var sample_v := clampf(0.5 + z / world_span, 0.0, 1.0)
	var source_height := _sample_height(sample_u, sample_v)
	var authored_height := pow(clampf((source_height - HEIGHTMAP_FLOOR) \
		/ (1.0 - HEIGHTMAP_FLOOR), 0.0, 1.0), 1.28) * height_scale
	var radius := Vector2(x, z).length()
	var radial_t := clampf((radius - site_radius) \
		/ maxf(half_span - site_radius, 0.001), 0.0, 1.0)
	var angle := atan2(z, x)
	var cliff_variation := 0.78 + sin(angle * 5.0 + 0.7) * 0.14 \
		+ sin(angle * 11.0 - 1.4) * 0.08
	var lip_floor := inner_cliff_height * cliff_variation \
		* (1.0 - smoothstep(0.0, 0.11, radial_t))
	var enclosing_rise := smoothstep(0.0, 0.22, radial_t) * 5.0
	return elevation + maxf(authored_height, lip_floor) + enclosing_rise


func _sample_height(u: float, v: float) -> float:
	var width := _height_image.get_width()
	var height := _height_image.get_height()
	var px := clampf(u, 0.0, 1.0) * float(width - 1)
	var py := clampf(v, 0.0, 1.0) * float(height - 1)
	var x0 := int(floorf(px))
	var y0 := int(floorf(py))
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var tx := px - float(x0)
	var ty := py - float(y0)
	var a := _luminance(_height_image.get_pixel(x0, y0))
	var b := _luminance(_height_image.get_pixel(x1, y0))
	var c := _luminance(_height_image.get_pixel(x0, y1))
	var d := _luminance(_height_image.get_pixel(x1, y1))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


static func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b + PI, 0.0, TAU) - PI)


static func _cliff_edge_offset(angle: float) -> float:
	return sin(angle * 5.0 + 0.3) * 3.2 \
		+ sin(angle * 11.0 - 1.1) * 1.45 \
		+ sin(angle * 23.0 + 2.4) * 0.62
