class_name SlamVfx
extends RefCounted
## The dust ring an air slam throws out, and nothing else. Fire and forget:
## `SlamVfx.spawn(parent, at, radius)` builds a short-lived Node3D of particles
## at a world position and frees it when the last mote has died.
##
## Ported from ~/valenfeld's JumpAttackImpactFX, which had the structure right —
## a fast leading crest, a slower body behind it, a dust column and a spray of
## grit, all soft billboards — and re-coloured, because that project's shockwave
## is lit ochre daylight and this one goes off on a torchlit dungeon floor.
##
## **Everything here is MIX, never ADD.** SpinVfx's blade motes are additive and
## its docstring is thirty lines about what that costs; this effect is dust, and
## dust does not emit. Additive would also break it in exactly the way this
## project has broken it before (CLAUDE.md §3): alpha does not attenuate ADD, so
## the fade-out of every mote would be a fade to a solid pale slab on a floor
## that is nearly black. STYLEGUIDE §7.5 bans the glow outright, which is the
## same answer arrived at from the other end.
##
## **No torus, no decal, no mesh ring.** The circle is made only of particles
## moving outward from a shared centre, so it breaks up the way a real one does.
## A ring mesh scaled up over 0.3 s is the tell of a placeholder, and this
## project's anti-slop list (STYLEGUIDE §7.10) names impact treatments like it.

## Longer than any particle's life, because it is when the NODE dies, and a
## cleanup that fires while the last motes are still fading pops them out.
const DURATION := 0.7
## Radius bounds. The floor stops a zero-radius call producing an invisible
## effect that reads as "the slam did nothing"; the ceiling stops a caller's
## arithmetic error filling the room with dust.
const MIN_RADIUS := 0.6
const MAX_RADIUS := 6.0

## STYLEGUIDE §2, and they are the palette entries a lit dust cloud would
## actually be over this floor: BONE is the game's white and the crest catches
## the torches, MOTH is the body of it, ASH is the grit. Nothing here goes near
## #FFFFFF, which §7.2 bans outright.
##
## BONE is still not a colour to paint a cloud in. The first pass tinted the
## crest 65% of the way to BONE and held it at 0.94 alpha, and on a torchlit
## floor that is not pale dust, it is white cotton wool — RENDERED AND LOOKED AT,
## it filled the lower third of the frame and hid the hero at the one moment the
## player is looking at him. The peaks below are all under 0.65 for that reason:
## dust in a dark room is something you see THROUGH.
const BONE := Color(0.847, 0.816, 0.722)
const MOTH := Color(0.502, 0.471, 0.408)
const ASH := Color(0.282, 0.251, 0.314)

## One 64x64 radial falloff, built once and shared by every quad in every slam.
## A soft edge is the whole difference between dust and confetti, and building it
## per impact would allocate a texture per press.
static var _soft: GradientTexture2D = null


## Build the effect under `parent` at `at`, sized to `radius`. Returns the root
## so a director can look at it; nothing in the game keeps the reference.
static func spawn(parent: Node, at: Vector3, radius: float) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		push_warning("SlamVfx: no live parent; the impact went off with no dust")
		return null
	var r := clampf(radius, MIN_RADIUS, MAX_RADIUS)

	var root := Node3D.new()
	root.name = "SlamVfx"
	# Hit-stop is a paused tree (Feel.hitstop), and the impact this belongs to is
	# the thing that ASKED for the pause. Frozen with everything else, the dust
	# would appear only once the freeze it is the reason for had ended.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.global_position = at

	root.add_child(_ring(&"Crest", r, true))
	root.add_child(_ring(&"Body", r, false))
	root.add_child(_column(r))
	root.add_child(_grit(r))

	var done := root.create_tween()
	done.tween_interval(DURATION)
	done.tween_callback(root.queue_free)
	return root


## One of the two rings. `lead` is the fast bright crest that draws the circle;
## the other is the slower, heavier body that follows it out and settles.
##
## They are two emitters rather than one with a wide velocity range because the
## crest wants a SHORT life and the body a long one, and lifetime is per-emitter.
## One emitter split down the middle gives a ring that is either gone before it
## has expanded or still hanging when the hero is up and moving again.
static func _ring(id: StringName, radius: float, lead: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = id
	p.amount = clampi(int(radius * (26.0 if lead else 18.0)), 32, 90)
	p.lifetime = 0.34 if lead else 0.46
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = true
	# 30 is the project's frame budget for a thing nobody is looking at closely,
	# and a dust puff read at 60 Hz looks identical.
	p.fixed_fps = 30
	p.visibility_aabb = _bounds(radius, 1.2)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius * (0.26 if lead else 0.20)
	m.emission_ring_inner_radius = radius * (0.15 if lead else 0.05)
	m.emission_ring_height = 0.05 if lead else 0.10
	m.direction = Vector3.UP
	m.spread = 12.0 if lead else 26.0
	m.initial_velocity_min = 0.08
	m.initial_velocity_max = 0.28 if lead else 0.48
	m.gravity = Vector3(0.0, -0.6 if lead else -1.3, 0.0)
	# Radial acceleration, not initial velocity, is what keeps the crest CIRCULAR
	# while it grows: every mote is pushed away from the one shared centre, so the
	# shape cannot drift the way a spray of independent velocities does. The
	# min/max spread is what stops the edge being a drawn line.
	#
	# SIZE THIS AGAINST THE HITBOX. Under constant acceleration the crest travels
	# `0.5 * drive * life^2`, and the first pass drove it at radius * 26 — 80 m/s^2
	# for 0.42 s, which is seven metres of dust announcing a 2.6 m hit. The ring is
	# the player's read of what the slam reached, so it has to stop near where the
	# damage did: at radius * 11 the crest covers ~2 m and lands just outside the
	# emission ring's own 0.8 m, i.e. the edge of the sphere `_slam_targets` swept.
	var drive := radius * (11.0 if lead else 8.0)
	m.radial_accel_min = drive * 0.82
	m.radial_accel_max = drive * 1.16
	m.damping_min = 1.8 if lead else 2.3
	m.damping_max = 2.8 if lead else 3.5
	m.scale_min = 0.72 if lead else 0.88
	m.scale_max = 1.25 if lead else 1.55
	m.scale_curve = _curve([
		Vector2(0.0, 0.42 if lead else 0.54), Vector2(0.18, 1.24 if lead else 1.38),
		Vector2(0.72, 1.0), Vector2(1.0, 0.48 if lead else 0.62)])
	var tint := BONE.lerp(MOTH, 0.72) if lead else MOTH.lerp(ASH, 0.3)
	m.color_ramp = _fade(tint, 0.05, 0.58 if lead else 0.46, 0.62 if lead else 0.5)
	p.process_material = m
	p.draw_pass_1 = _billboard(tint, clampf(radius * 0.075, 0.12, 0.24))
	p.position = Vector3(0.0, 0.07 if lead else 0.04, 0.0)
	p.emitting = true
	return p


## The column of dust straight up out of the point of impact. This is the part
## that reads as WEIGHT — a ring alone says the floor was touched, and the plume
## says it was hit.
##
## It is a SLEEVE around the impact, not a plug in the middle of it, and the
## inner radius below is the whole reason. Emitted from a filled disc at half-
## metre quads it put a soft white ball exactly where the hero is standing, and
## since he is rooted through `slam_recover` it rode his shoulder for the length
## of the recovery — a bright blob on the pose the move exists to show.
static func _column(radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Column"
	p.amount = clampi(int(radius * 9.0), 18, 32)
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.88
	p.local_coords = true
	p.fixed_fps = 30
	p.visibility_aabb = _bounds(radius, 1.8)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius * 0.42
	m.emission_ring_inner_radius = radius * 0.20
	m.emission_ring_height = 0.08
	m.direction = Vector3.UP
	m.spread = 56.0
	m.initial_velocity_min = 0.65
	m.initial_velocity_max = 1.65
	m.gravity = Vector3(0.0, -2.2, 0.0)
	m.radial_accel_min = radius * 2.0
	m.radial_accel_max = radius * 4.2
	m.damping_min = 1.6
	m.damping_max = 2.8
	m.scale_min = 0.7
	m.scale_max = 1.35
	# Dust GROWS as it disperses, which is the opposite of the ring's curve and
	# the reason they are separate emitters. Fading is left to the colour ramp.
	m.scale_curve = _curve([Vector2(0.0, 0.45), Vector2(0.32, 1.0), Vector2(1.0, 1.3)])
	var haze := MOTH.lerp(ASH, 0.4)
	m.color_ramp = _fade(haze, 0.03, 0.34, 0.4)
	p.process_material = m
	p.draw_pass_1 = _billboard(haze, clampf(radius * 0.085, 0.12, 0.26))
	p.position = Vector3(0.0, 0.06, 0.0)
	p.emitting = true
	return p


## Chips of floor. Few, fast, heavy, and gone — this is the layer that gives the
## impact a hard edge against three layers of soft dust.
static func _grit(radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Grit"
	p.amount = clampi(int(radius * 7.0), 12, 24)
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.96
	p.local_coords = true
	p.fixed_fps = 30
	p.visibility_aabb = _bounds(radius, 2.2)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius * 0.24
	m.emission_ring_inner_radius = 0.0
	m.emission_ring_height = 0.05
	m.direction = Vector3.UP
	m.spread = 46.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.2
	# Real gravity, unlike every other layer here. Grit is the one thing in the
	# effect heavy enough to arc, and the arc is what says it is a chip of stone
	# rather than more dust.
	m.gravity = Vector3(0.0, -K.GRAVITY * 0.4, 0.0)
	m.radial_accel_min = radius * 2.8
	m.radial_accel_max = radius * 5.6
	m.damping_min = 0.4
	m.damping_max = 1.0
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.76, 0.82), Vector2(1.0, 0.18)])
	# The one layer that keeps a high peak: it is ASH, it is 6 cm across, and it is
	# the only hard edge in four layers of haze. Faint grit is no grit.
	m.color_ramp = _fade(ASH, 0.01, 0.68, 0.9)
	p.process_material = m
	p.draw_pass_1 = _billboard(ASH, clampf(radius * 0.05, 0.06, 0.13))
	p.position = Vector3(0.0, 0.05, 0.0)
	p.emitting = true
	return p


## Particles are culled against the emitter's AABB, not against where they end
## up, so a ring that expands 3 m out of a default box vanishes the moment the
## camera looks slightly away. Sized to the reach, every time.
static func _bounds(radius: float, height: float) -> AABB:
	var reach := radius * 1.35 + 0.8
	return AABB(Vector3(-reach, -0.6, -reach),
		Vector3(reach * 2.0, height + 0.6, reach * 2.0))


static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


## In at `rise`, held, then out to nothing. The alpha reaching 0 at the end is
## not optional — a particle that dies at full opacity pops, and a ring of them
## popping together is the single most obvious way this effect can look cheap.
##
## `peak` is per layer and it is the dial that decides whether this is dust or a
## smoke bomb; see the note on the palette constants. It was a fixed 0.94 and
## every layer was opaque.
static func _fade(c: Color, rise: float, hold: float, peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, rise, hold, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		Color(c.r, c.g, c.b, peak),
		Color(c.r, c.g, c.b, peak * 0.72),
		Color(c.r, c.g, c.b, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _billboard(c: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	# Unshaded: the dungeon's lighting is per-vertex on a two-triangle quad, so a
	# lit billboard is a quad taking one light sample and flickering as it moves.
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
	g.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.94),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	# White here is a MASK, not a colour — it multiplies the albedo above, which
	# is a palette entry. Nothing renders at #FFFFFF (STYLEGUIDE §7.2).
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_soft = t
	return _soft
