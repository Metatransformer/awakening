class_name SpinVfx
extends Node3D
## The look of the charged spin attack: the blade taking on light as you hold
## the button, and the ring that leaves the hero when you let go.
##
## Driven entirely by HeroCombat's hold clock — see `charge`, `fire` and
## `clear`. Nothing in here decides anything; it is the charge state, rendered.
##
## **Why the glow is HitFlash and not a second material walk.** A GLB is loaded
## once and instanced many times and every instance shares the loaded Mesh's
## materials, so writing emission onto `mi.get_active_material(0)` lights up
## every copy of that sword in the scene. HitFlash already solved exactly that
## for the enemy wind-up tell (per-surface override, remembers the baseline,
## restores it). A charging blade is the same problem with a different colour,
## so it is the same object — a second copy of that walk is how the two drift
## apart and one of them stops restoring.
##
## **Why the particles are additive but ramp their COLOUR, not their alpha.**
## Alpha does not attenuate `BLEND_MODE_ADD` (CLAUDE.md §3): a half-transparent
## additive quad over a near-black dungeon floor is exactly as bright as an
## opaque one, which is how this project has produced a glowing slab before. The
## fade out of every gradient here therefore walks the RGB to black as well as
## the alpha to zero, so it is still a fade with the blend mode ignoring alpha.

## Azul, and every one of these is kept well clear of white ON PURPOSE.
##
## This is the thing that had to be rendered to be believed. Additive blending
## SUMS, so N overlapping particles of colour c land on the framebuffer as N*c,
## and every channel that reaches 1.0 clips. A pale blue that looks correct as a
## single mote — (0.66, 0.88, 1.0), which is what the old charge light used —
## becomes (1.0, 1.0, 1.0) the moment three of them stack, and a burst is
## nothing BUT stacked particles. The first render of this effect was a wall of
## white blobs for exactly that reason.
##
## The fix is to keep red far below blue at every stop. (0.06, 0.26, 0.95)
## tripled is (0.18, 0.78, 2.85), which clips to (0.18, 0.78, 1.0) — still
## unmistakably blue. Judge these numbers stacked, never one at a time.
##
## And the thing that is easy to forget: the FLOOR is one of the things being
## added to. This dungeon is torchlit, so a mote lands on roughly (0.35, 0.25,
## 0.15) of warm stone before anything else stacks on it. AZUL_HOT rendered as a
## white dot with a blue rim for exactly that reason — 0.62 of green plus the
## floor's own is over 1.0 before a second particle arrives. AZUL_HOT is
## therefore the LIGHT colour, where nothing sums, and the motes and the blade
## use AZUL.
const AZUL_HOT := Color(0.30, 0.62, 1.0)
const AZUL := Color(0.06, 0.26, 0.95)
const AZUL_DEEP := Color(0.02, 0.06, 0.45)

## How hot the blade's emission goes at a full charge. HitFlash multiplies this
## by its own HIT_ENERGY, so 1.0 here is as bright as a landed blow.
const GLOW_FULL := 0.85
## How long the blade STAYS lit after the release, and how long it then takes to
## give the light back. Together these are 0.77 s against a 0.90 s spin, and that
## is the point: a fade that starts at the release is dark by the time the blade
## comes round the back, and the frames the player is actually watching — the
## middle of the sweep — are of an ordinary sword. The charge is spent AT the
## end of the swing, not at the start of it.
const GLOW_HOLD := 0.42
const GLOW_FADE := 0.35

## The blade light at a full charge, and the spike it takes on release. Half
## this game is a room lit by two sconces, so this light is doing as much work
## as the particles are.
const LIGHT_FULL := 2.6
const LIGHT_BURST := 7.0

## The sweep, which is the effect. OOT's spin does not put a ring on the floor —
## it drags a comet tail around the hero, and the tail is BEHIND the blade the
## whole way. So the emitter is a single blob parked at the blade's radius on a
## pivot that turns, and the motes are left in world space as it goes; the arc is
## the history of where the emitter has been, not a shape anybody authored.
##
## Clockwise seen from above, which is NEGATIVE rotation about +Y: the right-hand
## rule takes +Z toward +X, and with +X right and +Z toward the bottom of a
## top-down view that is counter-clockwise. Getting this backwards is not subtle
## and it is not a taste question — the trail would lead the sword instead of
## following it.
## 1.7 m, which is the blade's own reach and not a decoration's. `spin_reach` is
## 2.1 m from the hero's centre, so an arc drawn any tighter than this promises a
## circle smaller than the one the damage actually cuts — and the first version,
## at 0.55 m, drew a puddle around his boots that a player would read as a
## self-buff rather than as a swing.
const SWEEP_RADIUS := 1.7
const SWEEP_DELAY := 0.10
const SWEEP_TIME := 0.62

var _sword: Node3D
var _glow := HitFlash.new()
var _light: OmniLight3D
## What the sweep turns. The trail hangs off this and nothing else does.
var _pivot: Node3D
## Motes drawn to the blade while the button is held. Parented to the sword, so
## they are emitted along whatever arc the hand is travelling.
var _gather: GPUParticles3D
## The trail. Parented to `_pivot` at `SWEEP_RADIUS`, NOT to the blade: the sword
## is animated and the animation is not a source of truth for where the effect
## should be — it dips, it foreshortens, and it belongs to a clip borrowed from
## another character. The pivot turns at a rate this file owns.
var _burst: GPUParticles3D
var _tween: Tween
## The last value `charge` was given, so `fire` knows whether there is anything
## to fade FROM. A release with no hold behind it must not flash the room.
var _held: float = 0.0


## Take ownership of the blade. `sword` is HeroCombat's mounted holder, not the
## raw model — the light and the gather ride it so that stowing the sword takes
## the whole effect with it (holder visibility cascades).
func bind(sword: Node3D) -> void:
	_sword = sword
	if _sword == null:
		return
	_glow.bind(self, _sword)
	_build_light()
	_build_gather()
	_build_burst()
	clear()


## Where the hold is, 0 at the press and 1 once it is armed. Called every frame
## of the hold rather than tweened: the wind-up can be interrupted on any frame,
## and an interrupted tween that has already been killed leaves a lit blade.
func charge(t01: float) -> void:
	var t := clampf(t01, 0.0, 1.0)
	_held = t
	_kill()
	# Squared, so the first half of the hold is nearly dark and the light all
	# arrives near the top. A linear ramp reads as "the sword is on" from the
	# first frame and gives the player nothing to time the release against.
	var ramp := t * t
	_glow.glow(AZUL, ramp * GLOW_FULL)
	if _light != null:
		_light.visible = t > 0.0
		_light.light_energy = ramp * LIGHT_FULL
	if _gather != null:
		_gather.emitting = t > 0.0
		# The motes arrive faster as the charge fills. amount_ratio rather than
		# `amount`, because changing `amount` restarts the whole system and the
		# motes already in flight vanish every frame the ramp moves.
		_gather.amount_ratio = clampf(0.25 + ramp * 0.75, 0.0, 1.0)


## Let it go, spinning. The trail is drawn round him over SWEEP_TIME and the
## blade keeps its light for as long as the swing needs it, then gives it back.
func fire() -> void:
	_kill()
	if _gather != null:
		_gather.emitting = false
	if _light != null:
		_light.visible = true
		_light.light_energy = LIGHT_BURST
	_glow.glow(AZUL, GLOW_FULL)

	_tween = create_tween().set_parallel(true)
	if _pivot != null and _burst != null:
		_pivot.rotation.y = 0.0
		# NEGATIVE, so it goes clockwise seen from above — see SWEEP_RADIUS.
		# tween_property on the pivot rather than a per-frame rotation: the arc's
		# evenness IS the effect, and a hand-rolled tick would lay the ribbon down
		# at whatever the frame rate was that second.
		_tween.tween_property(_pivot, ^"rotation:y", -TAU, SWEEP_TIME) \
			.from(0.0).set_delay(SWEEP_DELAY)
		# The delay is the blade catching up. `fire` is called on the frame the
		# swing STARTS, and the clip spends its first tenth of a second turning
		# into the sweep — starting the trail on that frame draws it out of a hero
		# who has not moved yet.
		_tween.tween_callback(_sweep.bind(true)).set_delay(SWEEP_DELAY)
		_tween.tween_callback(_sweep.bind(false)).set_delay(SWEEP_DELAY + SWEEP_TIME)

	_tween.tween_method(_set_glow, GLOW_FULL, 0.0, GLOW_FADE).set_delay(GLOW_HOLD)
	# The light spikes and settles back to its charged level immediately — that
	# spike is the release itself — and then rides the blade down with the glow.
	_tween.tween_method(_set_light, LIGHT_BURST, LIGHT_FULL, 0.12)
	_tween.tween_method(_set_light, LIGHT_FULL, 0.0, GLOW_FADE).set_delay(GLOW_HOLD)
	_tween.chain().tween_callback(clear)
	_held = 0.0


## Nothing is being held and nothing is being swung. Safe to call on a frame
## where that was already true, which is why HeroCombat's shop gate can call it
## blindly.
func clear() -> void:
	_held = 0.0
	_glow.restore()
	if _light != null:
		_light.light_energy = 0.0
		_light.visible = false
	if _gather != null:
		_gather.emitting = false
	# The trail is deliberately NOT killed here — only its emitter is. The motes
	# already laid down are world-space and finish their own lifetimes, which is
	# the whole "the magic lags the sword" read: the hero has his feet back before
	# the arc behind him has finished burning.
	_sweep(false)


# --- internals --------------------------------------------------------------

## Emitter on or off. Off also parks the pivot back at the hero's facing, so the
## next spin starts its arc in front of him rather than wherever the last one
## happened to stop.
func _sweep(on: bool) -> void:
	if _burst == null:
		return
	_burst.emitting = on
	if not on and _pivot != null:
		_pivot.rotation.y = 0.0


func _set_glow(e: float) -> void:
	# AZUL, not AZUL_HOT. HitFlash multiplies the tint by 2.4, so a colour with
	# 0.62 of green in it comes out of the tonemapper as a white-hot blade with a
	# blue edge — which is a lightsaber, not a charged sword. AZUL's 0.26 of green
	# survives the multiply at 0.62 and the blade stays blue at full charge.
	_glow.glow(AZUL, e)


func _set_light(e: float) -> void:
	if _light != null:
		_light.light_energy = e


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## The light on the blade. Built once and hidden rather than made and freed per
## charge: a light spawned mid-frame under a BoneAttachment3D shows up at the
## origin for one frame, which reads as a flash at the hero's feet.
func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "SpinGlow"
	_light.light_color = AZUL_HOT
	_light.light_energy = 0.0
	_light.omni_range = 2.6
	# A charging sword throwing hard shadows around a torchlit room is both
	# expensive and wrong — this is a glow, not a lamp.
	_light.shadow_enabled = false
	# 0.6 m up the blade. The holder's origin is the POMMEL and the blade runs
	# along +Y (weapon_models.gd §sword); a light left at the origin lights his
	# fist and the sword reads as unlit.
	_light.position = Vector3(0.0, 0.6, 0.0)
	_light.visible = false
	_sword.add_child(_light)


func _build_gather() -> void:
	_gather = GPUParticles3D.new()
	_gather.name = "SpinGather"
	# 30, not 48. The camera in this game rides just over the hero's shoulder, so
	# anything on the blade is a couple of metres from the lens and a count that
	# reads as a sprinkle in a lookdev reads as fog in the actual shot.
	_gather.amount = 30
	_gather.lifetime = 0.55
	_gather.explosiveness = 0.0
	_gather.randomness = 0.7
	# World space. The whole read of the gather is that the motes are LEFT
	# BEHIND by a moving blade — in local space they ride the hand and the
	# effect turns into a static cloud stuck to the sword.
	_gather.local_coords = false
	_gather.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_gather.emitting = false

	var pm := ParticleProcessMaterial.new()
	# Born on a shell around the blade and pulled IN. Negative radial accel is
	# the whole effect: the sword is taking light out of the room, which is the
	# opposite of every other particle system in this project and is why a
	# charge reads as gathering rather than as burning.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.75
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.35
	pm.radial_accel_min = -4.5
	pm.radial_accel_max = -2.2
	pm.tangential_accel_min = 0.8
	pm.tangential_accel_max = 2.4
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.2
	pm.damping_max = 0.8
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.scale_curve = _shrink_curve()
	pm.color_ramp = _ramp([
		[0.0, Color(AZUL_DEEP.r, AZUL_DEEP.g, AZUL_DEEP.b, 0.0)],
		[0.3, AZUL_DEEP],
		# Brightest as it ARRIVES, which is the read: the light is going into the
		# sword. Peaks at AZUL rather than AZUL_HOT because this is the moment the
		# motes are most crowded, and crowded is where the sum whitens.
		[0.85, AZUL],
		# To BLACK, not just to transparent — alpha does not attenuate ADD.
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_gather.process_material = pm
	_gather.draw_pass_1 = _quad(0.055)
	_gather.material_override = _mote_material()
	# Up the blade, so the motes converge on steel rather than on his knuckles.
	_gather.position = Vector3(0.0, 0.55, 0.0)
	_sword.add_child(_gather)


## The trail: one blob of motes on a turning pivot, left behind in world space.
##
## Everything about this shape comes from that one decision. There is no ring
## emitter, no 360 of particles born at once, and no authored circle anywhere —
## the arc is where the emitter HAS BEEN, which is why it always trails the blade
## instead of appearing around it. The first pass did author the circle (an
## EMISSION_SHAPE_RING, all 54 at once) and it read as a shockwave: correct
## radius, no direction, no sense that a sword had gone past.
func _build_burst() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SpinSweep"
	add_child(_pivot)

	_burst = GPUParticles3D.new()
	_burst.name = "SpinTrail"
	# Dense, because this one is a RIBBON and a ribbon with gaps in it is a dotted
	# line. The count that was too high for a burst is about right for a trail:
	# these are spread along 10.7 m of arc instead of stacked on one radius.
	_burst.amount = 150
	# Longer than the sweep that lays it down, so the head of the arc is still
	# burning when the tail is halfway gone — and, deliberately, still burning
	# after the hero has control back. The magic lags the sword.
	_burst.lifetime = 0.55
	# NOT one_shot. The emitter runs for the length of the sweep and is switched
	# off by hand at the end of it; a one-shot would dump the whole ribbon at
	# whatever angle the pivot happened to be at.
	_burst.one_shot = false
	# 0.0 is the whole point: particles come out EVENLY across the sweep. Any
	# explosiveness at all clumps them into bursts and the arc goes dotted.
	_burst.explosiveness = 0.0
	_burst.randomness = 0.4
	# World space, and this is the load-bearing flag. In local space every mote
	# would ride the pivot round and the trail would be a rigid arm sweeping the
	# room instead of a tail being left behind.
	_burst.local_coords = false
	_burst.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_burst.emitting = false

	var pm := ParticleProcessMaterial.new()
	# A small blob at the blade's radius, not a ring. The blob is the pen; the
	# pivot is the hand. Slightly taller than it is wide so the arc has a bit of
	# body to it rather than reading as a wire.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.10, 0.22, 0.10)
	# Local -Z at the emitter, which — with the emitter parked out along the
	# pivot's -Z — points directly AWAY from the hero. This is the "outwards" half
	# of the move: the arc grows as it sweeps rather than riding one radius.
	pm.direction = Vector3(0.0, 0.12, -1.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.6
	# Almost nothing. The outward push is the initial velocity above; radial accel
	# here is measured from the EMITTER, which is itself out at SWEEP_RADIUS, so a
	# big number here would blow the ribbon apart sideways rather than widen the
	# circle.
	pm.radial_accel_min = 0.4
	pm.radial_accel_max = 1.4
	pm.tangential_accel_min = 0.0
	pm.tangential_accel_max = 0.6
	# A slight settle, so the tail sinks toward the floor as it dies instead of
	# hanging in the air at hip height like a smoke ring.
	pm.gravity = Vector3(0.0, -1.6, 0.0)
	pm.damping_min = 1.0
	pm.damping_max = 2.5
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _shrink_curve()
	# No white stop. A white first stop is invisible as a decision and fatal as a
	# result: it is the brightest thing on screen at the exact frame the most
	# particles overlap, so the opening of the arc — the one part the whole effect
	# is for — was the one part that had no colour in it at all.
	pm.color_ramp = _ramp([
		[0.0, AZUL],
		[0.4, AZUL],
		[0.8, AZUL_DEEP],
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_burst.process_material = pm
	_burst.draw_pass_1 = _quad(0.17)
	_burst.material_override = _mote_material()
	# Out at the blade's radius and at hip height. -Z because that is the hero's
	# forward (docs/CONTRACT.md §2.5: a Node3D's forward is -basis.z), so the
	# sweep starts in front of him and comes round.
	_burst.position = Vector3(0.0, 0.75, -SWEEP_RADIUS)
	_pivot.add_child(_burst)


## One shared look for both systems: unshaded, additive, billboarded, and
## textured with a soft radial falloff.
##
## The texture is the load-bearing part. An untextured QuadMesh under ADD is a
## hard-edged bright SQUARE — the single most recognisable "programmer particle"
## there is, and no amount of tuning the process material hides it.
func _mote_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The colour comes from the process material's ramp, which arrives as vertex
	# colour. Without this the ramp is computed and then thrown away, and every
	# particle in both systems renders plain white.
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_texture()
	m.disable_receive_shadows = true
	return m


## A soft round dot, built rather than imported so the effect owns its own look
## and does not depend on a texture nobody can find in six months.
func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	# A middle stop, so the falloff is a soft dot with a hot centre rather than a
	# linear cone that reads as a blurry blob.
	g.add_point(0.35, Color(1.0, 1.0, 1.0, 0.75))

	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


## Full size at birth, gone by death. Shared shape for both systems: a particle
## that pops out at full size is the other half of the square-quad tell.
func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = c
	return ct


## `stops` is [[offset, Color], ...] in ascending offset order. Gradient ships
## with two points already in it, so the first two stops overwrite rather than
## append — adding blindly leaves a stray white point at offset 1.0 and every
## particle ends its life flashing white.
func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	for i in stops.size():
		var offset: float = stops[i][0]
		var color: Color = stops[i][1]
		if i < 2:
			g.set_offset(i, offset)
			g.set_color(i, color)
		else:
			g.add_point(offset, color)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
