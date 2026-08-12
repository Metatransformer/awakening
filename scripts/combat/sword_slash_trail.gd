class_name SwordSlashTrail
extends Node3D
## A short world-space ribbon swept by the mounted sword itself.
##
## This is deliberately geometry, not particles: every section joins two real
## points on the blade, so a diagonal or overhead clip leaves the surface that
## clip actually cut instead of stamping the same horizontal crescent on every
## move. WeaponModels' contract puts the pommel at the holder origin and the
## 0.92 m blade on local +Y; INNER_Y and OUTER_Y stay inside that measured span.

class TrailSample:
	var inner: Vector3
	var outer: Vector3
	var expires_at: float

	func _init(inner_point: Vector3, outer_point: Vector3, expiry: float) -> void:
		inner = inner_point
		outer = outer_point
		expires_at = expiry


const TRAIL_SHADER := preload("res://assets/shaders/sword_slash_trail.gdshader")
## At most 22 sampled spans / 23 blade poses. Render-only curve subdivision adds
## smoothness between them without lengthening the trail's history or lifetime.
const MAX_SECTIONS := 22
const CURVE_SUBDIVISIONS := 4
const RAILS_PER_ROW := 5
const INNER_Y := 0.12
const OUTER_Y := 0.88
## Reject near-identical physics samples. Without this, hit-stop can stack a
## bright knot of zero-area quads at one point on the blade.
const MIN_SAMPLE_DISTANCE := 0.025
## Keep enough recent sweep to read as an arc while the blade is moving. The
## separate FOLLOW_THROUGH ceiling below is what governs the post-swing tail.
const SAMPLE_MEMORY := 0.20
## Five 60 Hz physics frames: the blade has passed, the afterimage hangs for one
## glance, then every remaining section is gone.
const FOLLOW_THROUGH := 0.083

## Public proof seam. A serial advances only when HeroCombat accepts an ordinary
## light swing. `section_count` is the bounded sampled history, while
## `render_section_count` exposes the denser curve used to draw it.
var stroke_serial: int = 0
var section_count: int = 0
var render_section_count: int = 0

var _blade: Node3D = null
var _mesh_instance: MeshInstance3D = null
var _mesh: ArrayMesh = null
var _samples: Array[TrailSample] = []
var _stroke_t: float = 0.0
var _active_start: float = 0.0
var _active_end: float = 0.0
var _follow_end: float = 0.0
var _intensity: float = 1.0


func _ready() -> void:
	# The samples below are world points. Top-level identity keeps them world
	# points even though HeroCombat owns this node and the hero turns underneath.
	top_level = true
	global_transform = Transform3D.IDENTITY

	_mesh = ArrayMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Ribbon"
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = _material()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.visible = false
	add_child(_mesh_instance)
	set_physics_process(false)


func bind(blade_holder: Node3D) -> void:
	_blade = blade_holder


## Begin one accepted LIGHT1/2/3 stroke. `active_window` is the same fractional
## slice that owns sword damage, so the picture never leads the live blade.
func begin_stroke(duration: float, active_window: Vector2,
		finisher: bool = false) -> void:
	if _blade == null or not is_instance_valid(_blade):
		return
	stroke_serial += 1
	_stroke_t = 0.0
	_active_start = maxf(duration * active_window.x, 0.0)
	_active_end = maxf(duration * active_window.y, _active_start)
	_follow_end = _active_end + FOLLOW_THROUGH
	# Same timing on all three strokes. The finisher only lifts opacity modestly;
	# its larger combat read still comes from the clip, damage and hit-stop.
	_intensity = 1.14 if finisher else 1.0
	_samples.clear()
	section_count = 0
	_rebuild_mesh()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_stroke_t += delta
	_prune_expired()
	if _stroke_t >= _active_start and _stroke_t <= _active_end:
		_sample_blade()
	_rebuild_mesh()

	# Waiting for the active slice is the one intentional empty-processing phase.
	# Once the stroke and its five-frame tail are over, an empty trail sleeps.
	if _stroke_t >= _follow_end and _samples.is_empty():
		set_physics_process(false)


func _sample_blade() -> void:
	if _blade == null or not is_instance_valid(_blade) or not _blade.is_visible_in_tree():
		return
	var inner := _blade.global_transform * Vector3(0.0, INNER_Y, 0.0)
	var outer := _blade.global_transform * Vector3(0.0, OUTER_Y, 0.0)
	if not _samples.is_empty():
		var previous: TrailSample = _samples[-1]
		var moved := maxf(previous.inner.distance_to(inner), previous.outer.distance_to(outer))
		if moved < MIN_SAMPLE_DISTANCE:
			return

	# No section may survive beyond the shared follow-through ceiling. Recent
	# samples retain the crescent during the cut; all of it leaves together soon
	# after the blade passes instead of hanging through the recovery pose.
	var expiry := minf(_stroke_t + SAMPLE_MEMORY, _follow_end)
	_samples.append(TrailSample.new(inner, outer, expiry))
	while _samples.size() > MAX_SECTIONS + 1:
		_samples.pop_front()


func _prune_expired() -> void:
	while not _samples.is_empty() and _samples[0].expires_at <= _stroke_t:
		_samples.pop_front()


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()
	section_count = maxi(_samples.size() - 1, 0)
	render_section_count = 0
	_mesh_instance.visible = section_count > 0
	if section_count == 0:
		return

	# Physics sampling owns the history and its strict cap. Four Catmull-Rom
	# subdivisions are render-only: they round the silhouette without changing
	# combat timing, lifetime, or the amount of state retained between frames.
	var smooth_inners := PackedVector3Array()
	var smooth_outers := PackedVector3Array()
	var smooth_expiries := PackedFloat32Array()
	var last_sample := _samples.size() - 1
	for sample_index in last_sample:
		var p0: TrailSample = _samples[maxi(sample_index - 1, 0)]
		var p1: TrailSample = _samples[sample_index]
		var p2: TrailSample = _samples[sample_index + 1]
		var p3: TrailSample = _samples[mini(sample_index + 2, last_sample)]
		for subdivision in CURVE_SUBDIVISIONS:
			var t := float(subdivision) / float(CURVE_SUBDIVISIONS)
			smooth_inners.append(p1.inner.cubic_interpolate(p2.inner, p0.inner, p3.inner, t))
			smooth_outers.append(p1.outer.cubic_interpolate(p2.outer, p0.outer, p3.outer, t))
			smooth_expiries.append(lerpf(p1.expires_at, p2.expires_at, t))
	var final_sample: TrailSample = _samples[last_sample]
	smooth_inners.append(final_sample.inner)
	smooth_outers.append(final_sample.outer)
	smooth_expiries.append(final_sample.expires_at)
	render_section_count = smooth_inners.size() - 1

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row_index in smooth_inners.size():
		var life := clampf((smooth_expiries[row_index] - _stroke_t) / SAMPLE_MEMORY,
			0.0, 1.0)
		var along := float(row_index) / float(render_section_count)
		# Collapse the oldest blade span into the tip path. That pointed tail is
		# what turns a rectangular motion smear into a crescent.
		var width := smoothstep(0.0, 0.30, along)
		var outer := smooth_outers[row_index]
		var inner := outer.lerp(smooth_inners[row_index], width)
		var tail_fade := smoothstep(0.0, 0.28, along)
		var alpha := life * tail_fade * _intensity

		# Five rails extend the interior fade roughly twice as far beneath the
		# cutting edge. The extra blade width lives almost entirely in this soft
		# falloff, so the slash feels thicker without becoming a white slab.
		vertices.append(inner)
		vertices.append(inner.lerp(outer, 0.24))
		vertices.append(inner.lerp(outer, 0.52))
		vertices.append(inner.lerp(outer, 0.78))
		vertices.append(outer)
		uvs.append(Vector2(along, 0.0))
		uvs.append(Vector2(along, 0.24))
		uvs.append(Vector2(along, 0.52))
		uvs.append(Vector2(along, 0.78))
		uvs.append(Vector2(along, 1.0))
		colors.append(Color(Pal.MOTH.r, Pal.MOTH.g, Pal.MOTH.b, 0.0))
		colors.append(Color(Pal.MOTH.r, Pal.MOTH.g, Pal.MOTH.b, 0.04 * alpha))
		colors.append(Color(Pal.COBALT.r, Pal.COBALT.g, Pal.COBALT.b, 0.18 * alpha))
		# Cobalt under the bone-white rim gives the cut a cool flash without using
		# extraction cyan or turning every light attack into charged-spin VFX.
		colors.append(Color(Pal.COBALT.r, Pal.COBALT.g, Pal.COBALT.b, 0.48 * alpha))
		colors.append(Color(Pal.BONE.r, Pal.BONE.g, Pal.BONE.b, 0.72 * alpha))

	for i in render_section_count:
		var a := i * RAILS_PER_ROW
		var b := a + RAILS_PER_ROW
		for band in RAILS_PER_ROW - 1:
			indices.append_array(PackedInt32Array([
				a + band, a + band + 1, b + band + 1,
				a + band, b + band + 1, b + band,
			]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TRAIL_SHADER
	return material
