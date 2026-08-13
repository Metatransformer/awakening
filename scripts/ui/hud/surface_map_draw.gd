class_name SurfaceMapDraw
extends RefCounted
## Draws authored exterior plans as a north-up, player-following local radar.
## Geometry stays with the scene that owns it; this helper only projects the
## immutable world-space plan into the HUD's compact map frame.

const PATH_W := 3.0
const PATH_SPUR_W := 2.0
const AREA_W := 1.0
const HERO_G := 6.0
const GLYPH_G := 7.0

const GLYPHS: Array[StringName] = [
	&"gate", &"entrance", &"hearth", &"service", &"landmark",
	&"dungeon", &"fishing", &"grove",
]


static func valid_plan(plan: Dictionary) -> bool:
	if plan.is_empty() or float(plan.get(&"view_range", 0.0)) <= 0.0:
		return false
	return plan.get(&"paths", null) is Array \
		and plan.get(&"areas", null) is Array \
		and plan.get(&"landmarks", null) is Array


## Returns facts measured from the plan that actually reached this draw path.
## Hud exposes the result to proof tooling, so a director never needs a second
## fixture table describing what the surface map ought to contain.
static func draw_map(ci: CanvasItem, box: Rect2, s_y: float,
		plan: Dictionary, player: Node3D) -> Dictionary:
	if player == null or not is_instance_valid(player) or not valid_plan(plan):
		return {}
	var view_range := float(plan[&"view_range"])
	var pixels_per_metre := minf(box.size.x, box.size.y) / view_range
	if pixels_per_metre <= 0.0:
		return {}
	var paths: Array = plan[&"paths"]
	var areas: Array = plan[&"areas"]
	var landmarks: Array = plan[&"landmarks"]
	var player_at := player.global_position

	for value: Variant in areas:
		if value is Dictionary:
			_draw_area(ci, box, player_at, pixels_per_metre, value as Dictionary,
				s_y)
	for value: Variant in paths:
		if value is Dictionary:
			_draw_path(ci, box, player_at, pixels_per_metre, value as Dictionary,
				s_y)
	var drawn_landmarks := 0
	for value: Variant in landmarks:
		if value is Dictionary and _draw_landmark(ci, box, player_at,
				pixels_per_metre, value as Dictionary, s_y):
			drawn_landmarks += 1
	_draw_player(ci, box, player, s_y)

	return {
		&"path_count": paths.size(),
		&"area_count": areas.size(),
		&"landmark_count": landmarks.size(),
		&"visible_landmark_count": drawn_landmarks,
		&"view_range": view_range,
		&"player_centered": true,
	}


static func _draw_path(ci: CanvasItem, box: Rect2, player_at: Vector3,
		pixels_per_metre: float, entry: Dictionary, s_y: float) -> void:
	var value: Variant = entry.get(&"points", null)
	if not value is PackedVector3Array:
		return
	var points := value as PackedVector3Array
	if points.size() < 2:
		return
	var kind := StringName(entry.get(&"kind", &"path"))
	var width := Pal.px(PATH_SPUR_W if kind == &"spur" else PATH_W, s_y)
	var color := Color(Pal.ASH, 0.72) if kind == &"spur" \
		else Color(Pal.MOTH, 0.62)
	var clip := box.grow(-width * 0.5)
	for i in points.size() - 1:
		var a := _project(points[i], player_at, box, pixels_per_metre)
		var z := _project(points[i + 1], player_at, box, pixels_per_metre)
		var clipped := _clip_segment(a, z, clip)
		if clipped.size() == 2:
			ci.draw_line(clipped[0], clipped[1], color, width)


static func _draw_area(ci: CanvasItem, box: Rect2, player_at: Vector3,
		pixels_per_metre: float, entry: Dictionary, s_y: float) -> void:
	var world_points: PackedVector3Array
	var points_value: Variant = entry.get(&"points", null)
	if points_value is PackedVector3Array:
		world_points = points_value as PackedVector3Array
	else:
		var centre_value: Variant = entry.get(&"center", null)
		var size_value: Variant = entry.get(&"size", null)
		if not centre_value is Vector3 or not size_value is Vector2:
			return
		var centre := centre_value as Vector3
		var area_size := size_value as Vector2
		var yaw := float(entry.get(&"yaw", 0.0))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw)) * area_size.x * 0.5
		var down := Vector3(sin(yaw), 0.0, cos(yaw)) * area_size.y * 0.5
		world_points = PackedVector3Array([
			centre - right - down, centre + right - down,
			centre + right + down, centre - right + down,
		])
	if world_points.size() < 3:
		return
	var projected: Array[Vector2] = []
	for point: Vector3 in world_points:
		projected.append(_project(point, player_at, box, pixels_per_metre))
	var clipped := _clip_polygon(projected, box)
	if clipped.size() < 3:
		return
	var kind := StringName(entry.get(&"kind", &"ground"))
	var fill := Color(Pal.MOTH, 0.11)
	if kind == &"footprint":
		fill = Color(Pal.ASH, 0.34)
	elif kind == &"water":
		fill = Color(Pal.ASH, 0.24)
	elif kind == &"grove":
		fill = Color(Pal.MOTH, 0.17)
	ci.draw_colored_polygon(PackedVector2Array(clipped), fill)
	var width := Pal.px(AREA_W, s_y)
	for i in clipped.size():
		ci.draw_line(clipped[i], clipped[(i + 1) % clipped.size()],
			Color(Pal.ASH, 0.62), width)


static func _draw_landmark(ci: CanvasItem, box: Rect2, player_at: Vector3,
		pixels_per_metre: float, entry: Dictionary, s_y: float) -> bool:
	var position_value: Variant = entry.get(&"position", null)
	var glyph := StringName(entry.get(&"glyph", &""))
	if not position_value is Vector3 or not GLYPHS.has(glyph):
		return false
	var at := _project(position_value as Vector3, player_at, box,
		pixels_per_metre)
	var g := Pal.px(GLYPH_G, s_y)
	# A clipped half-symbol is no longer a symbol. Cull it as one unit while it
	# crosses the edge; paths and area fills are the shapes that may be clipped.
	if not box.encloses(Rect2(at - Vector2.ONE * g, Vector2.ONE * g * 2.0)):
		return false
	match glyph:
		&"gate", &"entrance":
			_draw_gate(ci, at, g)
		&"hearth":
			_draw_hearth(ci, at, g)
		&"service":
			_draw_service(ci, at, g)
		&"landmark":
			_draw_landmark_ring(ci, at, g)
		&"dungeon":
			_draw_dungeon(ci, at, g)
		&"fishing":
			_draw_fishing(ci, at, g)
		&"grove":
			_draw_grove(ci, at, g)
	return true


static func _draw_gate(ci: CanvasItem, at: Vector2, g: float) -> void:
	var width := maxf(g * 0.16, 1.0)
	ci.draw_line(at + Vector2(-g * 0.46, g * 0.42),
		at + Vector2(-g * 0.46, -g * 0.12), Pal.BONE, width)
	ci.draw_line(at + Vector2(g * 0.46, g * 0.42),
		at + Vector2(g * 0.46, -g * 0.12), Pal.BONE, width)
	ci.draw_arc(at + Vector2(0.0, -g * 0.10), g * 0.46, PI, TAU, 8,
		Pal.BONE, width)


static func _draw_hearth(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_circle(at + Vector2(0.0, g * 0.18), g * 0.36, Pal.ASH)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -g * 0.52),
		at + Vector2(-g * 0.32, g * 0.24),
		at + Vector2(g * 0.32, g * 0.24),
	]), Pal.RUST)


static func _draw_service(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -g * 0.48), at + Vector2(g * 0.48, 0.0),
		at + Vector2(0.0, g * 0.48), at + Vector2(-g * 0.48, 0.0),
	]), Pal.MOTH)
	ci.draw_circle(at, g * 0.13, Pal.VOID)


static func _draw_landmark_ring(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_arc(at, g * 0.42, 0.0, TAU, 12, Pal.MOTH, maxf(g * 0.15, 1.0))
	ci.draw_circle(at, g * 0.11, Pal.BONE)


static func _draw_dungeon(ci: CanvasItem, at: Vector2, g: float) -> void:
	var step := g / 3.0
	for i in 3:
		ci.draw_rect(Rect2(at.x - g * 0.5, at.y - g * 0.5 + step * i,
			step * float(i + 1), maxf(step * 0.7, 1.0)), Pal.BONE)


static func _draw_fishing(ci: CanvasItem, at: Vector2, g: float) -> void:
	var width := maxf(g * 0.13, 1.0)
	for offset: float in [-0.22, 0.22]:
		ci.draw_arc(at + Vector2(0.0, g * offset), g * 0.45, 0.15, PI - 0.15,
			8, Pal.MOTH, width)


static func _draw_grove(ci: CanvasItem, at: Vector2, g: float) -> void:
	for offset: float in [-0.28, 0.28]:
		ci.draw_colored_polygon(PackedVector2Array([
			at + Vector2(g * offset, -g * 0.48),
			at + Vector2(g * (offset - 0.27), g * 0.30),
			at + Vector2(g * (offset + 0.27), g * 0.30),
		]), Pal.MOTH)


static func _draw_player(ci: CanvasItem, box: Rect2, player: Node3D,
		s_y: float) -> void:
	var at := box.get_center()
	var forward_3d := -player.global_transform.basis.z
	var forward := Vector2(forward_3d.x, forward_3d.z)
	if forward.length_squared() < 0.0001:
		forward = Vector2.UP
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var g := Pal.px(HERO_G, s_y)
	for pass_i in 2:
		var radius := g * (0.68 if pass_i == 0 else 0.54)
		ci.draw_colored_polygon(PackedVector2Array([
			at + forward * radius,
			at - forward * radius * 0.72 + side * radius * 0.62,
			at - forward * radius * 0.72 - side * radius * 0.62,
		]), Color(Pal.VOID, 0.96) if pass_i == 0 else Pal.BONE)


static func _project(world: Vector3, player_at: Vector3, box: Rect2,
		pixels_per_metre: float) -> Vector2:
	var offset := world - player_at
	# World +X is map-right and world +Z is map-down, hence north (-Z) is up.
	return box.get_center() + Vector2(offset.x, offset.z) * pixels_per_metre


static func _clip_segment(a: Vector2, z: Vector2, box: Rect2) -> Array[Vector2]:
	var delta := z - a
	var p := PackedFloat32Array([-delta.x, delta.x, -delta.y, delta.y])
	var q := PackedFloat32Array([
		a.x - box.position.x, box.end.x - a.x,
		a.y - box.position.y, box.end.y - a.y,
	])
	var low := 0.0
	var high := 1.0
	for i in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return []
			continue
		var t := q[i] / p[i]
		if p[i] < 0.0:
			low = maxf(low, t)
		else:
			high = minf(high, t)
		if low > high:
			return []
	return [a + delta * low, a + delta * high]


static func _clip_polygon(points: Array[Vector2], box: Rect2) -> Array[Vector2]:
	var output := points
	for edge in 4:
		output = _clip_polygon_edge(output, box, edge)
		if output.is_empty():
			break
	return output


static func _clip_polygon_edge(points: Array[Vector2], box: Rect2,
		edge: int) -> Array[Vector2]:
	var output: Array[Vector2] = []
	if points.is_empty():
		return output
	var previous := points[-1]
	var previous_inside := _inside_edge(previous, box, edge)
	for current: Vector2 in points:
		var current_inside := _inside_edge(current, box, edge)
		if current_inside != previous_inside:
			output.append(_edge_intersection(previous, current, box, edge))
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output


static func _inside_edge(point: Vector2, box: Rect2, edge: int) -> bool:
	match edge:
		0: return point.x >= box.position.x
		1: return point.x <= box.end.x
		2: return point.y >= box.position.y
		_: return point.y <= box.end.y


static func _edge_intersection(a: Vector2, z: Vector2, box: Rect2,
		edge: int) -> Vector2:
	var delta := z - a
	if edge < 2:
		var x := box.position.x if edge == 0 else box.end.x
		var t := (x - a.x) / delta.x if not is_zero_approx(delta.x) else 0.0
		return Vector2(x, a.y + delta.y * t)
	var y := box.position.y if edge == 2 else box.end.y
	var t := (y - a.y) / delta.y if not is_zero_approx(delta.y) else 0.0
	return Vector2(a.x + delta.x * t, y)
