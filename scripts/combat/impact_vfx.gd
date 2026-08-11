class_name ImpactVfx
extends Node3D
## What a blow leaves **at the spot it landed on the body**, sized by how hard it
## hit. Fire and forget: `ImpactVfx.spawn(parent, at, weight, crit)` builds a
## short-lived Node3D at a world position and frees itself.
##
## `weight` is `K`'s one impact number — 0 for a jab, 1 for a committed blow —
## so this scales with every other channel of the hit and cannot fall out of step
## with the shake or the launch. See `K.SHAKE_TAP` for the whole argument.
##
## **Two effects, not one.** A jab gets scuff and nothing else; the crit adds the
## star on top of it. They are separate because they are separate events: the
## scuff says *you connected*, and the star says *that one went through*.
##
## **The star retracts, it does not fade, and that is not a style choice.**
## CLAUDE.md §3: alpha does not attenuate `BLEND_MODE_ADD`, so a bright burst
## faded out over a near-black dungeon floor is an opaque pale slab at every
## opacity — this project has shipped that bug before. The fix in that table is
## *change the shape, not the material*, so the spikes grow out and pull back in.
## It is also simply what the reference does: the burst in Breath of the Wild's
## critical hit snaps open and snaps shut, it never dissolves.
##
## Everything here is `BLEND_MODE_MIX` and unshaded for the same reason, and
## nothing goes near `#FFFFFF` (STYLEGUIDE §7.2) — the core is `Pal.BONE`.

## Longer than any particle's life or any tween, because it is when the NODE
## dies. Cleanup that fires while motes are still on screen pops them out.
const DURATION := 0.85

## The star's whole life, seconds: it snaps open in `STAR_OPEN` and pulls back in
## over the rest. Under a quarter of a second in total — a crit flash you have
## time to look at is a crit flash that reads as a UI element.
const STAR_OPEN := 0.055
const STAR_SHUT := 0.17

## Spikes on the star. Twelve alternating long/short, jittered per impact, so it
## reads as a burst rather than as a snowflake — a regular star is the tell of a
## placeholder that STYLEGUIDE §7.10 names.
const STAR_SPIKES := 12

## Metres, at weight 1. The star is drawn around the impact POINT, not around the
## body, so this is sized against a torso and not against a room: 0.95 m across
## a 1.65 m-scale body is a burst that covers the chest and leaves the head and
## the legs readable. The first pass at 2.4 m hid the entire monster behind its
## own hit and there was nothing left to watch fly.
const STAR_RADIUS := 0.95
## And the floor under it. A crit on a troll and a crit on a goblin are the same
## EVENT, so the star does not scale with the body — only with the blow.
const STAR_MIN := 0.55

## One 64x64 radial falloff, built once and shared by every mote of every impact
## in the game. A soft edge is the difference between grit and confetti, and
## building a texture per landed blow would allocate on every swing of a chain.
static var _soft: GradientTexture2D = null

## The star, and when it was born, on the WALL CLOCK.
##
## **A Node with `_process` rather than a Tween, and this is the whole reason.**
## `Feel.hitstop` stops the world by setting `Engine.time_scale = 0`, and a crit
## asks for `K.HITSTOP_HEAVY` — nine frames — in the same breath as it asks for
## this burst. At `time_scale = 0` a Tween receives a delta of zero, so the first
## cut of this effect was built at scale zero and stayed there for the entire
## freeze, then popped open afterwards: **the crit flash was invisible for
## exactly the nine frames the crit exists to hold the player's eye on.**
##
## `Feel._tick_shake` already carries the same note about the same problem, and
## the same fix: measure against the wall clock, which a stopped world does not
## stop. So the star's whole life is `Time.get_ticks_msec()`, and it opens *into*
## the freeze the way the reference does.
var _star_node: MeshInstance3D = null
var _star_size: float = 0.0
var _born_ms: int = 0


## Build the effect under `parent` at world position `at`.
##
## `weight` is 0..1 (`K`'s impact weight). `crit` adds the star — it is passed in
## rather than derived from `weight` because the caller has already rolled it:
## the crit IS the launch (`Enemy._try_launch`), and two places deciding the same
## thing is one place for them to disagree.
static func spawn(parent: Node, at: Vector3, weight: float,
		crit: bool = false) -> ImpactVfx:
	if parent == null or not parent.is_inside_tree():
		push_warning("ImpactVfx: no live parent; the blow landed with no mark")
		return null
	var w := clampf(weight, 0.0, 1.0)

	var root := ImpactVfx.new()
	root.name = "ImpactVfx"
	# Hit-stop is the impact this burst BELONGS to. Processed with everything
	# else, the mark would appear only once the freeze it is the reason for had
	# ended -- i.e. never, as far as the player's eye is concerned.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.global_position = at

	root.add_child(_scuff(w))
	if crit:
		root._star_size = maxf(STAR_RADIUS * w, STAR_MIN)
		root._star_node = _star(at)
		root._star_node.scale = Vector3.ZERO
		root.add_child(root._star_node)
	return root


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()


## The star's whole life, on the wall clock. See `_star_node`.
func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec() - _born_ms) / 1000.0
	if t >= DURATION:
		queue_free()
		return
	if _star_node == null:
		return

	# Snap out past full, settle back, then retract to nothing. The overshoot is
	# the snap: a star that eases to its final size reads as a thing being placed
	# rather than a thing going off. The retract is not a fade -- see the class
	# docstring, and CLAUDE.md §3's ADD-over-black trap.
	var hold := STAR_OPEN * 0.6
	var k := 0.0
	if t < STAR_OPEN:
		# Cubic ease-out, so the burst is at three quarters of its size in the
		# first fifth of the open. It has to be THERE on the frame after the blow.
		var u := t / STAR_OPEN
		k = (1.0 - pow(1.0 - u, 3.0)) * 1.12
	elif t < STAR_OPEN + hold:
		k = lerpf(1.12, 1.0, (t - STAR_OPEN) / hold)
	elif t < STAR_OPEN + hold + STAR_SHUT:
		var u := (t - STAR_OPEN - hold) / STAR_SHUT
		k = 1.0 - u * u
	else:
		if _star_node.visible:
			_star_node.visible = false
		return
	_star_node.scale = Vector3.ONE * _star_size * maxf(k, 0.0)
	# Turned in its own plane as it opens, so two crits in a row are not the same
	# stamp twice. Cheap, and it is most of what stops the shape reading as a UI
	# element pasted onto the world.
	_star_node.rotation.z = t * 2.4


## The mark on the body: a tight spray of hard chips thrown off the contact
## point. This is the half that fires on EVERY landed blow, so it is deliberately
## cheap and deliberately small — at weight 0 it is eight motes over a third of a
## second, which is a scuff and not an explosion.
##
## Emitted from a small sphere rather than a point: a point source reads as a
## single puff sitting in front of the body, and the thing being drawn is a patch
## of a body that just got hit.
static func _scuff(w: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Scuff"
	# 8 at a jab, 26 at a committed blow. The COUNT is most of what "bigger hit,
	# bigger impact" reads as -- size alone just makes the same puff blurrier.
	p.amount = int(lerpf(8.0, 26.0, w))
	p.lifetime = lerpf(0.26, 0.42, w)
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = true
	p.fixed_fps = 30
	var reach := lerpf(0.5, 1.1, w)
	p.visibility_aabb = AABB(Vector3(-reach, -reach, -reach), Vector3.ONE * reach * 2.0)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = lerpf(0.08, 0.16, w)
	m.direction = Vector3.UP
	# Wide, because a blow scatters. Not fully spherical: the motes that would go
	# straight down are inside the body and never seen, so the spray is biased up
	# and out where there is something to look at.
	m.spread = 105.0
	m.initial_velocity_min = lerpf(1.1, 2.4, w)
	m.initial_velocity_max = lerpf(2.6, 5.4, w)
	# Real gravity, so the chips arc and fall. They are debris, not sparks.
	m.gravity = Vector3(0.0, -K.GRAVITY * 0.42, 0.0)
	m.damping_min = 2.2
	m.damping_max = 4.6
	m.scale_min = lerpf(0.55, 0.9, w)
	m.scale_max = lerpf(0.95, 1.7, w)
	# Chips SHRINK as they die. Growing debris reads as smoke.
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.55, 0.82), Vector2(1.0, 0.2)])
	# BONE at the moment of contact, cooling through MOTH to ASH -- the impact is
	# lit by the blow and then it is just grit falling in a dark room.
	var tint := Pal.BONE.lerp(Pal.MOTH, 0.35)
	m.color_ramp = _fade(tint, 0.04, 0.5, lerpf(0.6, 0.85, w))
	p.process_material = m
	p.draw_pass_1 = _billboard(tint, lerpf(0.05, 0.1, w))
	p.emitting = true
	return p


## The crit: a ragged star that snaps open at the impact point and pulls back in.
##
## `at` seeds the jitter, so the spikes differ between impacts without a
## RandomNumberGenerator per hit and without `randf()` making a director's frames
## non-reproducible. Two crits in the same spot look the same; nobody has ever
## noticed that in a game and every director run depends on it.
static func _star(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = &"Star"
	mi.mesh = _star_mesh(at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	# Unshaded and billboarded: this is a flash, not a lit object, and it must
	# read the same whichever side of the body the camera is on.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# MIX, never ADD. See the class docstring, and CLAUDE.md §3.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# **Depth-tested, deliberately.** The first cut set `no_depth_test` to stop
	# the star z-fighting the chest it is centred on, and the render caught what
	# that actually costs: the burst drew straight through the HERO, who was
	# nearer the camera than the body he had just hit. A crit flash painted over
	# the player's own character is worse than a little z-fighting, and there is
	# no z-fighting to fix anyway -- `Enemy._impact_point` already lifts the star
	# off the mesh by the body's capsule radius, so it sits in front of the
	# silhouette rather than inside it.
	mat.render_priority = 1
	mi.material_override = mat
	# Sized and animated by `_process`, on the wall clock. See `_star_node`.
	return mi


## The star itself, as polygons. A fan of thin triangles from a small core out to
## alternating long and short tips, in the XY plane for the billboard to turn.
##
## Drawn rather than textured because STYLEGUIDE §7.10 asks for procedural
## polygons over sprite sets, and because a quad with a star painted on it is the
## exact placeholder tell §7.10 names for impact treatments.
static func _star_mesh(at: Vector3) -> ArrayMesh:
	# Deterministic per impact position. See `_star`.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 16.0))

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	# The core is BONE and the tips are GOLD: white-hot at the contact point,
	# warm at the edges. Same read as the reference and the same two colours the
	# rest of this project's fire uses (`SpinVfx`).
	var core := Pal.BONE
	var tip := Pal.GOLD

	for i in STAR_SPIKES:
		var a := TAU * float(i) / float(STAR_SPIKES)
		# Alternating long and short, then jittered. Without the alternation it is
		# a sun; without the jitter it is a snowflake. It wants to be neither.
		var long := (i % 2) == 0
		var r := (1.0 if long else 0.52) * rng.randf_range(0.78, 1.0)
		# Thin, and thinner on the long spikes, so the burst has needles in it
		# rather than a ring of wedges.
		var half := (0.055 if long else 0.1) * TAU / float(STAR_SPIKES) * 6.0
		var inner := 0.13

		var t_pt := Vector3(sin(a) * r, cos(a) * r, 0.0)
		var b1 := Vector3(sin(a - half) * inner, cos(a - half) * inner, 0.0)
		var b2 := Vector3(sin(a + half) * inner, cos(a + half) * inner, 0.0)
		verts.append_array([b1, t_pt, b2])
		# Alpha to zero at the tip: the needle thins out AND fades along its own
		# length, which is what stops twelve triangles reading as twelve
		# triangles. This is a gradient across the shape, not an opacity on the
		# material, so it survives the MIX blend the class docstring insists on.
		colors.append_array([
			Color(core.r, core.g, core.b, 0.95),
			Color(tip.r, tip.g, tip.b, 0.0),
			Color(core.r, core.g, core.b, 0.95),
		])

	# The hot core, so the middle is a disc and not a hole where twelve triangle
	# bases meet.
	var ring := 10
	for i in ring:
		var a0 := TAU * float(i) / float(ring)
		var a1 := TAU * float(i + 1) / float(ring)
		verts.append_array([
			Vector3.ZERO,
			Vector3(sin(a0) * 0.2, cos(a0) * 0.2, 0.0),
			Vector3(sin(a1) * 0.2, cos(a1) * 0.2, 0.0),
		])
		colors.append_array([
			Color(core.r, core.g, core.b, 1.0),
			Color(core.r, core.g, core.b, 0.25),
			Color(core.r, core.g, core.b, 0.25),
		])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Shared building blocks --------------------------------------------------
# Local copies rather than imports, which is this project's pattern for particle
# effects and not an oversight: `SlamVfx` and `SpinVfx` each carry their own, and
# every one of them is four lines whose values are tuned to the effect around it.

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


## The shared radial falloff. Built on first use and kept for the process.
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
