class_name FlourishVfx
extends Node3D
## What a PARRY and a PERFECT DODGE look like. Fire and forget, like `ImpactVfx`:
## `FlourishVfx.parry(scene, at)` / `FlourishVfx.dodge(scene, at)` build a
## short-lived Node3D at a world position and free themselves.
##
## **Two effects that must not look like each other**, because they are the two
## halves of the same lesson and a player has to be able to tell at a glance
## which one they just got:
##
##   PARRY   is an IMPACT. Gold, hot, loud, centred on the shield, and thrown
##           outward — something arrived and was thrown back. It borrows
##           `ImpactVfx`'s starburst language on purpose: the crit and the parry
##           are the game's two "that went through" moments, and they should be
##           spoken in the same vocabulary.
##   DODGE   is an ABSENCE. Cold, thin, quiet, centred on the hero's feet, and a
##           ring that expands and thins rather than a burst that snaps. Nothing
##           was hit, so nothing bursts. The slow-motion is the real cue and this
##           is what tells you which frame it started on.
##
## **Everything here runs on the wall clock**, and that is not optional. Both
## effects fire in the same breath as something that stops time — the parry asks
## for `K.HITSTOP_HEAVY`, the dodge asks for `K.SLOWMO_SCALE` — and a Tween
## receives a delta of zero at `Engine.time_scale = 0`. `ImpactVfx` carries the
## long version of this note and the bug it cost.
##
## MIX blending and nothing near `#FFFFFF` (STYLEGUIDE §7.2), same as everything
## else in this folder: alpha does not attenuate ADD over a near-black dungeon
## floor (CLAUDE.md §3), so shapes change and materials do not.

## How long the NODE lives. Longer than either animation so nothing pops out
## while its motes are still falling.
const DURATION := 0.9

## The parry's ring: metres, and the seconds it takes to get there. Fast — this
## is a shockwave off a shield boss, not a smoke ring.
const PARRY_RING_R := 1.9
const PARRY_RING_TIME := 0.22
## The star, on `ImpactVfx`'s timings so the two read as the same event class.
const PARRY_STAR_R := 1.15
const PARRY_STAR_OPEN := 0.05
const PARRY_STAR_SHUT := 0.19

## The dodge's ring is WIDER and SLOWER than the parry's and it is drawn flat on
## the floor rather than billboarded. Wider because it is the hero's whole body
## the effect is about rather than one point on it; slower because the thing it
## is announcing is that there is suddenly time.
const DODGE_RING_R := 2.6
const DODGE_RING_TIME := 0.42

## Segments around a ring. 40 is smooth at 2.6 m and still one draw call.
const RING_SEGMENTS := 40

## One 64x64 radial falloff, shared by every mote of every flourish. Same
## reasoning as `ImpactVfx._tex` — a texture per parry would allocate inside the
## one frame of the game that is already doing the most work.
static var _soft: GradientTexture2D = null

var _born_ms: int = 0
## The two animated pieces. Either may be null: a dodge has no star.
var _ring: MeshInstance3D = null
var _star: MeshInstance3D = null
var _ring_r: float = 1.0
var _ring_time: float = 0.3
var _star_r: float = 1.0
## Radians/sec the ring turns as it grows. The parry's turns; the dodge's does
## not — a spinning ring reads as force, and the dodge has none.
var _ring_spin: float = 0.0


## The parry: a gold shock off the shield, plus the burst.
##
## `at` is the point ON THE SHIELD, not the hero's centre — `HeroCombat` offsets
## it toward the blow. The whole read of a parry is that the catch happened at a
## specific place on the player's body, which is the same argument
## `Enemy._impact_point` makes from the other side of a blow.
static func parry(parent: Node, at: Vector3) -> FlourishVfx:
	var root := _mount(parent, at)
	if root == null:
		return null
	root._ring_r = PARRY_RING_R
	root._ring_time = PARRY_RING_TIME
	root._ring_spin = 3.1
	root._ring = _ring_mesh(Pal.GOLD, Pal.BONE, 0.16, true)
	root._ring.scale = Vector3.ZERO
	root.add_child(root._ring)

	root._star_r = PARRY_STAR_R
	root._star = _star_mesh(at)
	root._star.scale = Vector3.ZERO
	root.add_child(root._star)

	root.add_child(_sparks())
	return root


## The perfect dodge: a cold ring opening on the floor under the hero.
##
## Flat on the ground rather than billboarded, and that is the whole difference
## in silhouette between the two effects. A billboard is a thing happening AT
## you; a ring on the floor is a thing happening AROUND you, which is what a
## dodge is — and it stays legible under the hero's own body, where a facing
## quad would be hidden by him.
static func dodge(parent: Node, at: Vector3) -> FlourishVfx:
	var root := _mount(parent, at + Vector3(0.0, 0.06, 0.0))
	if root == null:
		return null
	root._ring_r = DODGE_RING_R
	root._ring_time = DODGE_RING_TIME
	root._ring_spin = 0.0
	# FROST into CYAN. The project's cold pair, and the only two colours in the
	# palette that cannot be confused with the gold every impact in the game is
	# already using.
	root._ring = _ring_mesh(Pal.FROST, Pal.CYAN, 0.09, false)
	# Laid flat. The mesh is authored in XY, so a quarter turn about X puts it on
	# the floor — the same rotation `SlamVfx` uses for the same reason.
	root._ring.rotation.x = -PI * 0.5
	root._ring.scale = Vector3.ZERO
	root.add_child(root._ring)
	return root


static func _mount(parent: Node, at: Vector3) -> FlourishVfx:
	if parent == null or not parent.is_inside_tree():
		push_warning("FlourishVfx: no live parent; the reaction happened unseen")
		return null
	var root := FlourishVfx.new()
	root.name = "FlourishVfx"
	# The freeze is the moment this belongs to. Processed with everything else,
	# the cue would appear only once the hit-stop it is the reason for had ended.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.global_position = at
	return root


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec() - _born_ms) / 1000.0
	if t >= DURATION:
		queue_free()
		return

	if _ring != null:
		# The ring GROWS and THINS. It never fades: see the class docstring and
		# CLAUDE.md §3. Thinning is done by squashing the mesh's own thickness,
		# which is a shape change and therefore survives the MIX blend.
		var u := clampf(t / _ring_time, 0.0, 1.0)
		if u >= 1.0:
			if _ring.visible:
				_ring.visible = false
		else:
			# Ease-out, hard. A shockwave is fastest on the frame it leaves.
			var e := 1.0 - pow(1.0 - u, 3.0)
			# The ring's thickness is baked into the mesh's Z; scaling that down
			# as it grows is what makes it read as a wave rather than a hoop.
			_ring.scale = Vector3(
				_ring_r * e, _ring_r * e, maxf(1.0 - u * u, 0.02))
			_ring.rotation.z = t * _ring_spin

	if _star != null:
		# `ImpactVfx`'s curve, deliberately: snap past full, settle, retract.
		var hold := PARRY_STAR_OPEN * 0.6
		var k := 0.0
		if t < PARRY_STAR_OPEN:
			var u := t / PARRY_STAR_OPEN
			k = (1.0 - pow(1.0 - u, 3.0)) * 1.14
		elif t < PARRY_STAR_OPEN + hold:
			k = lerpf(1.14, 1.0, (t - PARRY_STAR_OPEN) / hold)
		elif t < PARRY_STAR_OPEN + hold + PARRY_STAR_SHUT:
			var u := (t - PARRY_STAR_OPEN - hold) / PARRY_STAR_SHUT
			k = 1.0 - u * u
		else:
			if _star.visible:
				_star.visible = false
			return
		_star.scale = Vector3.ONE * _star_r * maxf(k, 0.0)
		_star.rotation.z = -t * 2.0


# --- The shapes ---------------------------------------------------------------

## A flat annulus in the XY plane, hot on the inner edge and transparent at the
## outer one, with its thickness carried in Z so `_process` can squash it.
##
## The Z trick is the whole reason this is an ArrayMesh and not a TorusMesh: a
## torus is a solid of revolution and there is no way to thin one without
## rebuilding it, which is an allocation per parry.
static func _ring_mesh(inner_c: Color, outer_c: Color, width: float,
		billboarded: bool) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in RING_SEGMENTS:
		var a0 := TAU * float(i) / float(RING_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(RING_SEGMENTS)
		# Unit radius; `_process` scales it. The half-width is carried in the
		# vertex's own offset so the scale's Z component thins the band.
		var i0 := Vector3(sin(a0) * (1.0 - width), cos(a0) * (1.0 - width), 0.0)
		var i1 := Vector3(sin(a1) * (1.0 - width), cos(a1) * (1.0 - width), 0.0)
		var o0 := Vector3(sin(a0), cos(a0), 0.0)
		var o1 := Vector3(sin(a1), cos(a1), 0.0)
		verts.append_array([i0, o0, o1, i0, o1, i1])
		var hot := Color(inner_c.r, inner_c.g, inner_c.b, 0.9)
		var cold := Color(outer_c.r, outer_c.g, outer_c.b, 0.0)
		colors.append_array([hot, cold, cold, hot, cold, hot])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = &"Ring"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _flat_mat(billboarded)
	return mi


## The parry's burst. `ImpactVfx._star_mesh`'s shape with fewer, longer spikes:
## eight rather than twelve, because a parry is one hard direction of force and
## a twelve-point star is an explosion.
##
## `at` seeds the jitter so the spikes differ between parries without a
## `randf()` making a director's frames non-reproducible — the same trade
## `ImpactVfx` makes and the same reason.
static func _star_mesh(at: Vector3) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 16.0))
	var spikes := 8

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var core := Pal.BONE
	var tip := Pal.GOLD
	for i in spikes:
		var a := TAU * float(i) / float(spikes)
		var long := (i % 2) == 0
		var r := (1.0 if long else 0.46) * rng.randf_range(0.8, 1.0)
		var half := (0.07 if long else 0.13) * TAU / float(spikes) * 6.0
		var inner := 0.15
		verts.append_array([
			Vector3(sin(a - half) * inner, cos(a - half) * inner, 0.0),
			Vector3(sin(a) * r, cos(a) * r, 0.0),
			Vector3(sin(a + half) * inner, cos(a + half) * inner, 0.0),
		])
		colors.append_array([
			Color(core.r, core.g, core.b, 0.95),
			Color(tip.r, tip.g, tip.b, 0.0),
			Color(core.r, core.g, core.b, 0.95),
		])

	var disc := 10
	for i in disc:
		var a0 := TAU * float(i) / float(disc)
		var a1 := TAU * float(i + 1) / float(disc)
		verts.append_array([
			Vector3.ZERO,
			Vector3(sin(a0) * 0.22, cos(a0) * 0.22, 0.0),
			Vector3(sin(a1) * 0.22, cos(a1) * 0.22, 0.0),
		])
		colors.append_array([
			Color(core.r, core.g, core.b, 1.0),
			Color(core.r, core.g, core.b, 0.3),
			Color(core.r, core.g, core.b, 0.3),
		])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = &"Star"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _flat_mat(true)
	return mi


## Depth-TESTED and billboard-optional. The depth test is deliberate and it is
## `ImpactVfx`'s hard-won note: a `no_depth_test` flash painted straight through
## the hero, who is nearer the camera than the thing he hit. The shield point is
## already outside his silhouette, so there is nothing to fix by turning it off.
static func _flat_mat(billboarded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	if billboarded:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.render_priority = 1
	return m


## The steel that comes off a caught blade. Small, fast, and gravity-bound —
## these are chips of two edges meeting, not an explosion.
static func _sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Sparks"
	p.amount = 22
	p.lifetime = 0.34
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = true
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-1.4, -1.4, -1.4), Vector3.ONE * 2.8)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.1
	m.direction = Vector3.UP
	m.spread = 120.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 7.0
	m.gravity = Vector3(0.0, -K.GRAVITY * 0.5, 0.0)
	m.damping_min = 3.0
	m.damping_max = 6.0
	m.scale_min = 0.5
	m.scale_max = 1.1
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.5, 0.8), Vector2(1.0, 0.15)])
	var tint := Pal.GOLD.lerp(Pal.BONE, 0.4)
	m.color_ramp = _fade(tint, 0.03, 0.4, 0.9)
	p.process_material = m
	p.draw_pass_1 = _billboard(tint, 0.075)
	p.emitting = true
	return p


# --- Shared building blocks --------------------------------------------------
# Local copies, which is this project's pattern for particle effects and not an
# oversight: `SlamVfx`, `SpinVfx` and `ImpactVfx` each carry their own, and every
# one of them is four lines tuned to the effect around it.

static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _fade(c: Color, rise: float, hold: float, peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, rise, hold, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		Color(c.r, c.g, c.b, peak),
		Color(c.r, c.g, c.b, peak * 0.7),
		Color(c.r, c.g, c.b, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _billboard(c: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _tex()
	m.disable_receive_shadows = true
	q.material = m
	return q


static func _tex() -> GradientTexture2D:
	if _soft != null:
		return _soft
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.width = 64
	_soft.height = 64
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	return _soft
