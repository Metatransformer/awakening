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
## The charge motes and release sparks are additive, so their ramps fade RGB to
## black as well as alpha. Alpha alone does not attenuate `BLEND_MODE_ADD`
## (CLAUDE.md §3). The broad sweep is deliberately different: alpha-MIX lets
## the room remain visible through a refracting water sheet, while HDR emission
## supplies the cobalt current lines and the bright leading edge.

## Cool near-white rather than #FFFFFF: overlapping translucent bands still
## retain their blue identity when glow blooms them together.
const WATER_WHITE := Color(0.82, 0.95, 1.00)
const WATER_LIGHT := Color(0.34, 0.76, 1.00)
const WATER_COBALT := Color(0.07, 0.32, 0.94)
const WATER_DEEP := Color(0.015, 0.055, 0.20)
## The subtle cool multiply pass beneath the sheet.
const COOL_SHADOW := Color(0.20, 0.27, 0.39)
## `HitFlash` multiplies this by its own HIT_ENERGY, so keep it saturated and
## below the near-white release head.
const WATER_BLADE := Color(0.08, 0.38, 0.92)

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

## The sweep, which is the effect. It is a moving water-energy sheet rather than
## a static ring: the tail stays BEHIND the blade and thins as the contact head
## travels.
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
## 0.48 s for the full turn. It finishes well inside the 0.68 s swing, and what
## keeps "the magic lags the sword" true is RING_TAIL below: the head closes the
## circle at 0.48 s and the last of the sheet is still fading afterwards, once
## the hero has his feet back.
const SWEEP_TIME := 0.48
## ContactHead and SpinSparks share this exact local point. It sits at the blade
## radius and hip height; the head's scale bridges the layered sheet around it.
const CONTACT_POINT := Vector3(0.0, 0.55, -SWEEP_RADIUS)

## --- the ring -----------------------------------------------------------------
##
## **Why this is a mesh and not particles any more, which is the whole change.**
## The ring used to be one small emitter on the turning pivot, laying world-space
## motes down behind it — the arc as the history of where the pen had been. It is
## a lovely idea and it cannot be made continuous, because a GPU emitter emits
## once per FRAME at wherever the pivot is that frame. At 60 fps the emitter
## steps ~0.37 m round a 10.7 m circumference; at the 30-odd fps this game
## actually hits in a lit room it steps 0.74 m, and no box extent wide enough to
## bridge that is still a thin ring. Every render of it came out as a string of
## blue beads with floor between them — the photographs are in /tmp/rings — and
## the fixes all pointed the same way: more particles, fatter particles, wider
## emitter, i.e. make each bead big enough to touch the next one. That is a
## dotted line arguing about dot size.
##
## The honest continuous version is an annulus of geometry built once, with a
## shader that only lights the part the blade has already passed. The sweep is a
## float going 0 → 1; frame rate cannot put holes in it because there is nothing
## being deposited.
##
## Particles remain only where discreteness helps: sparse shards leaving the
## moving contact head.
##
## **The shape, which is four swept bands and not one flat washer.**
##
## A single annulus lying on the floor reads as a decal from the gameplay camera.
## The disc therefore stays for top-down continuity while three vertical sheets
## stand on it at rising radii, each leaning outward as it climbs.
##
## Three rather than one for a reason worth keeping: a single vertical sheet is
## a cardboard cut-out from every angle except dead-on, and three at different
## radii, gains and current phases overlap into a front, middle, and back. That
## parallax between the sheets is the whole of the depth.
##
## A profile is [radial offset, height] from the band's base radius, swept round
## the circle. UV.y runs 0 at the first point to 1 at the last, so "0 is the root
## and 1 is the tip" holds for both kinds of band: the disc's tip is its outer
## edge, and a standing sheet's tip is its top. One falloff serves both.
const RING_BASE := 0.10
## The disc. Barely any rise left in it — it used to flare 0.34 m at the outer
## edge, which was the only way a lone sheet could avoid vanishing edge-on to a
## low camera, and the shells do that job properly now.
const DISC_RADIUS := 1.18
const DISC_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.00), Vector2(0.34, 0.01), Vector2(0.68, 0.06), Vector2(1.02, 0.22),
]
## The standing sheet profiles: cleanly up and outward, with no geometry
## displacement. Their 0.82 m cross-section gives the charged sweep more body
## than an ordinary sword trail without turning its silhouette into a wall.
const SHEET_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.00), Vector2(0.07, 0.26), Vector2(0.17, 0.55), Vector2(0.30, 0.82),
]
## Flat on the stone and wider than the energy sheet at both ends, so the cool
## multiply pass reads as ambient contrast rather than a hole in the floor.
const SCORCH_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.0), Vector2(0.60, 0.0), Vector2(1.20, 0.0), Vector2(1.80, 0.0),
]
## Base radius, current phase, brightness — one row per sheet. The LAG each one
## takes is derived from its index below. The radii straddle
## SWEEP_RADIUS (1.7) and the outermost tips land on `spin_reach` (2.1), so the
## sheet ends where the damage does. Gains keep the translucent layers distinct
## where they overlap instead of washing the cobalt body to white.
const SWEEP_SHEETS: Array[Vector3] = [
	Vector3(1.36, 0.37, 0.42),
	Vector3(1.62, 0.71, 0.50),
	Vector3(1.88, 0.13, 0.36),
]
## How many quads round the circle. 160 is ~4 cm of arc per segment at the outer
## edge, which is far finer than the shader's current lines and keeps the smooth
## sweep edge from looking faceted.
## A slight stagger keeps the layers distinct while leaving every edge inside
## ContactHead's rounded bridge. The outermost sheet trails the disc by ~4°.
const SHELL_LAG := 0.004
const RING_SEGMENTS := 160
## How much of the circle remains visible at once, in turns. 0.62 means the sheet
## behind the blade stretches most of the way back round and the head is always
## clearly the head — a longer tail closes the loop into a plain ring and loses
## the direction, a shorter one reads as a comet with no ring at all.
const RING_TAIL := 0.62
## The cool shadow lags further, and the dark band under the fading tail helps
## keep the ring legible on a torchlit floor.
const SCORCH_TAIL := 0.95
## The ring grows as it travels, so the energy leaves him rather than orbiting
## him. Scale, not radius, means the already-drawn
## arc expands with the head instead of the band spiralling outward.
const RING_GROW := Vector2(0.88, 1.10)

## The ring shader. Alpha-MIX keeps the layered sweep translucent, while HDR
## emission makes its moving currents and leading edge bloom. It never writes
## depth, so the overlapping transparent bands do not flicker against each other.
##
## `head` is the sweep, in turns, and it is the only thing animated: a fragment
## whose UV.x is ahead of it has not been cut yet, one further behind than `tail`
## has faded out. It is allowed to run past 1.0 so the tail can finish crossing
## the seam after the head has closed the circle.
##
## Flow only modulates colour, emission, and a sub-pixel screen-texture sample.
## Geometry and alpha edges stay smooth, especially at the moving head.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled;

uniform float head = -1.0;
uniform float tail = 0.62;
uniform float burn = 1.0;
uniform vec3 crest : source_color = vec3(0.82, 0.95, 1.0);
uniform vec3 current : source_color = vec3(0.34, 0.76, 1.0);
uniform vec3 cobalt : source_color = vec3(0.07, 0.32, 0.94);
uniform vec3 deep : source_color = vec3(0.015, 0.055, 0.20);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying vec3 loc;
// Per-band, carried in the vertex colour: current phase, opacity gain, and lag.
varying float phase;
varying float gain;
varying float lag;

void vertex() {
	loc = VERTEX;
	phase = COLOR.r;
	gain = COLOR.g;
	lag = COLOR.b;
}

void fragment() {
	// How long ago the blade passed this angle, in turns. Negative means it has
	// not been here yet. No noise touches age: the leading edge is one smooth
	// contact seam shared with the rounded ContactHead mesh.
	float age = head - UV.x - lag;
	float life = 1.0 - clamp(age / tail, 0.0, 1.0);
	if (age < 0.0) {
		life = 0.0;
	}
	float lead = smoothstep(-0.004, 0.014, age);

	// v = 0 at the band's root and 1 at its outer/top edge. Smooth falloff keeps
	// every layer's silhouette clean; the motion lives inside the sheet.
	float v = UV.y;
	float band = smoothstep(0.0, 0.13, v) * (1.0 - smoothstep(0.76, 1.0, v));

	// Three clean parallel currents run through the body. Their fixed centre
	// lines keep the sheet rounded rather than wiggly; only their intensity and
	// the sub-pixel refraction flow.
	float along = UV.x * 6.2831853;
	float line_a = 0.22;
	float line_b = 0.48;
	float line_c = 0.70;
	float current_a = exp(-pow((v - line_a) * 18.0, 2.0));
	float current_b = exp(-pow((v - line_b) * 20.0, 2.0));
	float current_c = exp(-pow((v - line_c) * 22.0, 2.0));
	float currents = clamp(max(current_a, max(current_b, current_c)), 0.0, 1.0);
	currents *= 0.72 + 0.28 * sin(along * 7.0 - TIME * 8.0 + phase * 13.0);

	float hot = exp(-max(age, 0.0) * 24.0);
	float body = pow(life, 1.08);
	float alpha = band * lead * (body * 0.58 + hot * 0.34) * gain * burn;
	alpha = clamp(alpha, 0.0, 0.72);

	float energy = clamp(body * 0.36 + currents * 0.62 + hot * 0.92, 0.0, 1.0);
	vec3 col = mix(deep, cobalt, smoothstep(0.04, 0.40, energy));
	col = mix(col, current, smoothstep(0.34, 0.72, energy));
	col = mix(col, crest, smoothstep(0.76, 1.0, energy));

	// Refraction is intentionally sub-pixel and confined to the body. It makes
	// the layer read as water without moving its outline or its leading seam.
	vec2 flow = vec2(
		sin((loc.x + loc.z) * 5.0 - TIME * 4.2 + phase * 6.0),
		cos((loc.x - loc.z) * 4.0 + TIME * 3.6 + phase * 8.0)
	);
	vec2 refract_uv = clamp(SCREEN_UV + flow * 0.00115 * band * body,
		vec2(0.001), vec2(0.999));
	vec3 behind = textureLod(screen_texture, refract_uv, 0.0).rgb;

	ALBEDO = mix(behind, col, 0.38 + currents * 0.18 + hot * 0.10);
	EMISSION = col * (0.38 + currents * 1.55 + hot * 3.25) * gain * burn;
	ALPHA = alpha;
}
"""

## The cool shadow under the sheet: the same sweep, drawn on the floor and
## MULTIPLYING.
##
## **Why a dark pass exists at all.** The HDR translucent sheet brightens the
## torchlit stone this game is mostly set on, so its body needs a small amount of
## cool contrast. A second, wider annulus lies on the flagstones under the sweep
## and multiplies them toward blue-grey.
##
## It is drawn BEFORE the sheet (`render_priority = -1`), which is not optional:
## transparent passes composite in priority order, and a multiply landing after
## the MIX pass would darken the energy itself instead of the floor.
##
## The identity for a multiply is WHITE, not black. Every fade here therefore
## walks the colour back toward vec3(1.0), which is "leave the floor alone".
const SCORCH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled;

uniform float head = -1.0;
uniform float tail = 0.95;
uniform float burn = 1.0;
uniform vec3 cool_shadow : source_color = vec3(0.20, 0.27, 0.39);

varying vec3 loc;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.60 + vnoise(p * 2.7) * 0.28 + vnoise(p * 6.1) * 0.12;
}

void vertex() {
	loc = VERTEX;
}

void fragment() {
	// The shadow shares the sheet's clean leading seam. Noise only modulates the
	// interior darkness; it never moves the outline.
	float age = head - UV.x;
	float life = 1.0 - clamp(age / tail, 0.0, 1.0);
	if (age < 0.0) {
		life = 0.0;
	}

	// Soft at both rims, and softer than the sheet's: this is a shadow, and a
	// shadow with a hard edge is a sticker.
	float v = UV.y;
	float band = smoothstep(0.0, 0.30, v) * (1.0 - smoothstep(0.55, 1.0, v));
	// The darkest point is a little BEHIND the head, not at it — under the sheet
	// itself, where the energy body would be blocking the most light.
	float dark = band * smoothstep(0.0, 0.10, age) * pow(life, 0.65) * burn;
	dark *= 0.55 + 0.45 * fbm(loc.xz * 3.6);

	ALBEDO = mix(vec3(1.0), cool_shadow, clamp(dark, 0.0, 1.0));
	ALPHA = 1.0;
}
"""

var _sword: Node3D
var _glow := HitFlash.new()
var _light: OmniLight3D
## What the shared contact head and sparks turn.
var _pivot: Node3D
## Motes drawn to the blade while the button is held. Parented to the sword, so
## they are emitted along whatever arc the hand is travelling.
var _gather: GPUParticles3D
## The water sheet itself: the disc and three standing layers in one mesh, lit a
## slice at a time by RING_SHADER.
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
## The dark pass on the floor beneath it. A child of `_ring`, so it inherits the
## placement and the growth for free.
var _scorch: MeshInstance3D
var _scorch_mat: ShaderMaterial
## Rounded leading contact and its aligned sparks. Both are children of `_pivot`
## at CONTACT_POINT, not of the animated sword: the borrowed clip dips and
## foreshortens, while this release clock owns the exact effect seam.
var _contact_head: MeshInstance3D
var _sparks: GPUParticles3D
## Facing captured on release. `_set_head` combines it with the clamped first
## turn so shader, pivot, head visibility, and spark emission cannot drift.
var _release_yaw: float = 0.0
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
	_build_ring()
	_build_sparks()
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
	_glow.glow(WATER_BLADE, ramp * GLOW_FULL)
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
	_glow.glow(WATER_BLADE, GLOW_FULL)

	# Both the sheet and the sparks are cut loose from the hero for the length of
	# the effect. They are placed where he is STANDING when he lets go and left
	# there: he is locked for the swing, but he is not locked afterwards, and a
	# ring that walked away with him would undo the one thing the world-space
	# particles were bought for.
	var yaw := global_transform.basis.get_euler().y
	_release_yaw = yaw
	_place(_ring, yaw)
	_place(_pivot, yaw)

	_tween = create_tween().set_parallel(true)

	var span := SWEEP_TIME * (1.0 + SCORCH_TAIL)
	if _ring_mat != null and _ring != null:
		_ring.visible = true
		_ring_mat.set_shader_parameter(&"burn", 1.0)
		if _scorch_mat != null:
			_scorch_mat.set_shader_parameter(&"burn", 1.0)
		# ON THE RELEASE FRAME, not a tenth of a second after it. There used to be a
		# SWEEP_DELAY of 0.10 here to let the animation's wind-up catch up, and what
		# it actually bought was a beat of nothing between the button coming up and
		# the magic appearing — the release is the moment the player is watching for
		# and it has to be the moment something happens.
		# Past 1.0 by the LONGEST tail of the two passes, at the same angular rate
		# throughout: the head closes the circle at SWEEP_TIME and then keeps going,
		# eating first the water sheet and then its cool shadow until nothing is
		# left. Running only to RING_TAIL would cut the shadow off mid-fade.
		_tween.tween_property(
			_ring, ^"scale",
			Vector3(RING_GROW.y, 1.0, RING_GROW.y),
			span
		).from(Vector3(RING_GROW.x, 1.0, RING_GROW.x))

	# One tween calls one clock for the shader, clockwise pivot, rounded head, and
	# spark emission. Values past 1.0 only consume the visual tail.
	_set_head(0.0)
	_tween.tween_method(_set_head, 0.0, 1.0 + SCORCH_TAIL, span)

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
	if _ring != null:
		_ring.visible = false
	_set_head(-1.0)
	# The sparks already in the air are deliberately NOT killed here — only their
	# emitter stops. They are world-space and finish their own lifetimes, which is
	# the whole "the magic lags the sword" read: the hero has his feet back before
	# the last blue-white shard behind him has gone out.
	if _pivot != null:
		_pivot.top_level = false
		_pivot.position = Vector3.ZERO
		_pivot.rotation = Vector3.ZERO
		_pivot.scale = Vector3.ONE
	_release_yaw = 0.0


# --- internals --------------------------------------------------------------

## Cut a node loose from the hero and stand it where he is, facing where he
## faces. `top_level` is what makes the ring stay put once it is drawn; setting
## it here rather than at build time keeps the node riding the hero while it is
## idle, so the first frame of a spin is never at the world origin.
func _place(node: Node3D, yaw: float) -> void:
	if node == null:
		return
	node.top_level = true
	node.global_position = global_position
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = Vector3.ONE


## Where the release is, in turns round the circle. This is the single clock for
## the shader, pivot rotation, contact-head visibility, and spark emission.
## Values above 1 keep consuming the mesh tail but clamp the moving seam at the
## completed turn; -1 parks everything before the next release.
func _set_head(t: float) -> void:
	if _ring_mat != null:
		_ring_mat.set_shader_parameter(&"head", t)
	if _scorch_mat != null:
		_scorch_mat.set_shader_parameter(&"head", t)
	if _pivot != null:
		# Negative is clockwise seen from above. Clamp to one turn so the contact
		# seam stops while the ring and shadow finish fading behind it.
		_pivot.rotation.y = _release_yaw - clampf(t, 0.0, 1.0) * TAU
	var active := t >= 0.0 and t < 1.0
	if _contact_head != null:
		_contact_head.visible = active
	if _sparks != null:
		_sparks.emitting = active


func _set_glow(e: float) -> void:
	_glow.glow(WATER_BLADE, e)


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
	_light.light_color = WATER_LIGHT
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
		[0.0, Color(WATER_DEEP.r, WATER_DEEP.g, WATER_DEEP.b, 0.0)],
		[0.3, WATER_DEEP],
		# Brightest as it ARRIVES: the blue energy is going into the sword. Keep
		# this below the release head because the motes crowd at the blade.
		[0.85, WATER_COBALT],
		# To BLACK, not just to transparent — alpha does not attenuate ADD.
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_gather.process_material = pm
	_gather.draw_pass_1 = _quad(0.055)
	_gather.material_override = _mote_material()
	# Up the blade, so the motes converge on steel rather than on his knuckles.
	_gather.position = Vector3(0.0, 0.55, 0.0)
	_sword.add_child(_gather)


## The water-energy sweep: four bands in one mesh, lit a slice at a time by
## RING_SHADER.
##
## The geometry is deliberately dumb — profiles swept round a circle, UV.x once
## round, UV.y root-to-tip. There is no emitter here, nothing is deposited, and
## the frame rate therefore cannot put a hole in the ring, which is the one thing
## the particle version could never promise.
##
## Angles are laid out so UV.x = 0 is the hero's FORWARD and UV.x rises clockwise
## seen from above, because that is the direction the blade travels (see
## SWEEP_RADIUS). A Node3D's forward is -Z (docs/CONTRACT.md §2.5), so the point
## at angle phi is (r·sin phi, y, -r·cos phi): phi = 0 gives (0, y, -r), dead
## ahead, and a small positive phi swings it toward +X, which is his right.
func _build_ring() -> void:
	var mesh := ArrayMesh.new()
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	# The disc first — the Saturn read, and the only band that survives being
	# looked at from straight above.
	_sweep_band(v, uv, cols, idx, DISC_RADIUS, DISC_PROFILE, 0.0, 0.90)
	# Then the sheets standing on it. x = base radius, y = current phase, z = gain.
	# Each sheet out from the middle is dealt a little more LAG, so their heads are
	# staggered instead of arriving as one front. Three sheets that all start at
	# the same angle read as three parallel walls however much flow is on them;
	# staggered by a few degrees, they read as one thick current being dragged
	# round, which is the entire point of having three.
	for k in SWEEP_SHEETS.size():
		var sheet: Vector3 = SWEEP_SHEETS[k]
		_sweep_band(v, uv, cols, idx, sheet.x, SHEET_PROFILE, sheet.y, sheet.z,
			RING_BASE, SHELL_LAG * float(k + 1))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	# The per-band constants ride in the vertex colour rather than in a uniform,
	# because all four bands are ONE surface with one material: a uniform can only
	# say one thing per draw, and splitting them into four surfaces to say four
	# things would be four draw calls for a decoration.
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = _shader(RING_SHADER)
	_ring_mat.set_shader_parameter(&"head", -1.0)
	_ring_mat.set_shader_parameter(&"tail", RING_TAIL)
	_ring_mat.set_shader_parameter(&"burn", 1.0)
	_ring_mat.set_shader_parameter(&"crest", WATER_WHITE)
	_ring_mat.set_shader_parameter(&"current", WATER_LIGHT)
	_ring_mat.set_shader_parameter(&"cobalt", WATER_COBALT)
	_ring_mat.set_shader_parameter(&"deep", WATER_DEEP)

	_ring = MeshInstance3D.new()
	_ring.name = "SpinRing"
	_ring.mesh = mesh
	_ring.material_override = _ring_mat
	# Shadow casting off for the same reason the blade light casts none: this is
	# a glow, not a lamp.
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)

	_build_scorch()


## The dark pass, parented UNDER the ring so that placing and growing the sheet
## takes the scorch with it — the shadow of a thing does not lag behind it.
func _build_scorch() -> void:
	var mesh := ArrayMesh.new()
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	_sweep_band(v, uv, cols, idx, DISC_RADIUS - 0.34, SCORCH_PROFILE, 0.0, 1.0, 0.02)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_scorch_mat = ShaderMaterial.new()
	_scorch_mat.shader = _shader(SCORCH_SHADER)
	_scorch_mat.set_shader_parameter(&"head", -1.0)
	_scorch_mat.set_shader_parameter(&"tail", SCORCH_TAIL)
	_scorch_mat.set_shader_parameter(&"burn", 1.0)
	_scorch_mat.set_shader_parameter(&"cool_shadow", COOL_SHADOW)
	# BEFORE the sheet. See SCORCH_SHADER — a multiply composited afterwards
	# would darken the energy instead of the floor.
	_scorch_mat.render_priority = -1

	_scorch = MeshInstance3D.new()
	_scorch.name = "SpinScorch"
	_scorch.mesh = mesh
	_scorch.material_override = _scorch_mat
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(_scorch)


## Sweep one profile round the circle and append it to the arrays.
##
## `profile` is [radial offset, height] from `radius`, root first and tip last.
## `phase`, `gain` and `lag` go into the vertex colour for the shader to read per
## band — three numbers, three channels, one draw call.
func _sweep_band(
	v: PackedVector3Array, uv: PackedVector2Array, cols: PackedColorArray,
	idx: PackedInt32Array, radius: float, profile: Array[Vector2],
	phase: float, gain: float, base: float = RING_BASE, lag: float = 0.0
) -> void:
	var rows := profile.size()
	var first := v.size()
	for i in RING_SEGMENTS + 1:
		var f := float(i) / float(RING_SEGMENTS)
		var ang := f * TAU
		var sn := sin(ang)
		var cs := cos(ang)
		for j in rows:
			var pt: Vector2 = profile[j]
			var r := radius + pt.x
			v.push_back(Vector3(r * sn, base + pt.y, -r * cs))
			uv.push_back(Vector2(f, float(j) / float(rows - 1)))
			cols.push_back(Color(phase, gain, lag, 1.0))

	# The seam column is DUPLICATED (RING_SEGMENTS + 1 columns for RING_SEGMENTS
	# quads) so the last quad can reach UV.x = 1.0. Sharing one column would wrap
	# its U back to 0 and the final quad would be textured with the entire ring
	# squeezed backwards into it.
	for i in RING_SEGMENTS:
		for j in rows - 1:
			var a := first + i * rows + j
			var b := a + rows
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])


## One Shader per source string. Built here rather than authored as a .gdshader
## so the effect owns its own look and does not depend on a resource nobody can
## find in six months — the same call the dot texture makes.
func _shader(src: String) -> Shader:
	var sh := Shader.new()
	sh.code = src
	return sh


## The rounded leading seam and sparse blue-white shards released from it.
func _build_sparks() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SpinSweep"
	add_child(_pivot)
	_build_contact_head()

	_sparks = GPUParticles3D.new()
	_sparks.name = "SpinSparks"
	# Sparse enough to read as individual directional shards, not particle fog.
	_sparks.amount = 26
	_sparks.lifetime = 0.42
	# NOT one_shot. The emitter runs for the length of the sweep and is switched
	# off by hand at the end of it; a one-shot would dump every spark at whatever
	# angle the pivot happened to be at.
	_sparks.one_shot = false
	# 0.0: sparks come out evenly across the sweep rather than in gouts.
	_sparks.explosiveness = 0.0
	_sparks.randomness = 0.45
	# World space, and this is the load-bearing flag. In local space every spark
	# would ride the pivot round and they would be a rigid arm sweeping the room
	# instead of luminous shards left behind by the head.
	_sparks.local_coords = false
	_sparks.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_sparks.emitting = false

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	# At the front of the sweep, +X is clockwise tangent, -Z is outward, and +Y
	# is up. A narrow spread preserves that directional read around the turn.
	pm.direction = Vector3(1.0, 0.52, -0.72).normalized()
	pm.spread = 17.0
	pm.initial_velocity_min = 4.2
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0.0, -4.8, 0.0)
	pm.damping_min = 0.6
	pm.damping_max = 1.4
	pm.scale_min = 0.65
	pm.scale_max = 1.15
	pm.scale_curve = _shrink_curve()
	# Align the QuadMesh's long Y axis to velocity so each particle is a moving
	# streak rather than a camera-facing dot.
	pm.particle_flag_align_y = true
	pm.color_ramp = _ramp([
		[0.0, WATER_WHITE],
		[0.32, WATER_LIGHT],
		[0.78, WATER_COBALT],
		# To BLACK as well as transparent because the material is additive.
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_sparks.process_material = pm
	_sparks.draw_pass_1 = _spark_quad()
	_sparks.material_override = _spark_material()
	_sparks.position = CONTACT_POINT
	_pivot.add_child(_sparks)


## A compact rounded bridge across the layered sheet. It is narrow along the
## tangent but spans the sheet radially and vertically, so it reads as the
## converged front of the sweep rather than a detached orb.
func _build_contact_head() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	# Translucent enough to merge with the sheet instead of photographing as an
	# opaque white orb; HDR emission supplies the shine and bloom.
	mat.albedo_color = Color(WATER_LIGHT.r, WATER_LIGHT.g, WATER_LIGHT.b, 0.18)
	mat.emission_enabled = true
	mat.emission = WATER_LIGHT
	mat.emission_energy_multiplier = 2.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true

	_contact_head = MeshInstance3D.new()
	_contact_head.name = "ContactHead"
	_contact_head.mesh = mesh
	_contact_head.material_override = mat
	_contact_head.position = CONTACT_POINT
	# A compact point of convergence. The surrounding sheet already supplies the
	# broad crest; stretching this mesh across it photographs as a detached oval.
	_contact_head.scale = Vector3(0.14, 0.22, 0.14)
	_contact_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact_head.visible = false
	_pivot.add_child(_contact_head)


## The charge motes stay soft and round: they converge into the blade and never
## pretend to be the directional release sparks.
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
	# charge particle renders plain white.
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_texture()
	m.disable_receive_shadows = true
	return m


## Velocity-aligned particle billboard for the release shards.
func _spark_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _streak_texture()
	m.disable_receive_shadows = true
	return m


## A narrow luminous shard. The radial alpha texture rounds its ends while the
## elongated quad and align-Y flag preserve a streak silhouette.
func _streak_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, WATER_WHITE)
	g.set_offset(1, 1.0)
	g.set_color(1, Color(WATER_WHITE.r, WATER_WHITE.g, WATER_WHITE.b, 0.0))
	g.add_point(0.42, Color(WATER_WHITE.r, WATER_WHITE.g, WATER_WHITE.b, 0.88))

	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 16
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## A soft round dot for the charge gather, built rather than imported so the
## effect owns its own look.
func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, WATER_WHITE)
	g.set_offset(1, 1.0)
	g.set_color(1, Color(WATER_WHITE.r, WATER_WHITE.g, WATER_WHITE.b, 0.0))
	# A middle stop, so the falloff is a soft dot with a hot centre rather than a
	# linear cone that reads as a blurry blob.
	g.add_point(0.35, Color(WATER_WHITE.r, WATER_WHITE.g, WATER_WHITE.b, 0.75))

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


func _spark_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.036, 0.25)
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
