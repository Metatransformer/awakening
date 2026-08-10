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
## The ring shader takes the same rule to its conclusion and never touches ALPHA
## at all — it holds ALPHA at 1.0 and does every fade in the colour, because
## black added to a framebuffer is exactly nothing whatever the blend func does.

## Ocarina's spin, which is a FIRE colour. Every one of these is kept clear of
## white on purpose, and the reason survives the change of hue.
##
## Additive blending SUMS, so N overlapping motes of colour c land as N*c and
## every channel reaching 1.0 clips. This effect was azul before, and the first
## render of it was a wall of WHITE blobs because (0.66, 0.88, 1.0) tripled is
## white in all three channels. Fire has the same trap with the channels
## permuted: keep BLUE far below red and the clip lands on amber instead of on
## white. FIRE tripled is (2.94, 0.90, 0.09) → clipped (1.0, 0.90, 0.09), which
## is a hot yellow-orange and still unmistakably fire. Judge these stacked,
## never one at a time.
##
## And the thing that is easy to forget: the FLOOR is one of the things being
## added to, and here it works AGAINST us in a way it did not when this was
## blue. A torchlit dungeon floor is already about (0.35, 0.25, 0.15) of warm
## stone, so a warm mote starts most of the way to clipping before a second one
## arrives. That is why FIRE_HOT — the only near-white value here — is the LIGHT
## colour, where nothing sums, and the motes use FIRE.
##
## FOUR stops, not two, because two is what made the first fire ring read as a
## flat orange decal: a real flame is white where it is hottest, light orange
## just off that, orange through the body and near-black at the tail, and the
## eye reads that ramp as DEPTH even on a shape with none. The shader picks
## along it by `heat` — proximity to the head, minus how far up the flame a
## fragment is — so the roots are white and the tips are ember, which is the
## right way round and the thing that gives a flat sheet a body.
##
## FIRE_WHITE is the one value here that would clip, and it is deliberately
## rationed: the shader only reaches it above heat 0.82, which is a few degrees
## behind the blade, and the flame shells carry a per-band `gain` under 1.0 so
## three of them overlapping at that angle still sum to under two. Judge these
## stacked, never one at a time.
const FIRE_WHITE := Color(1.00, 0.92, 0.76)
const FIRE_LIGHT := Color(1.00, 0.60, 0.16)
const FIRE_HOT := Color(1.00, 0.66, 0.26)
const FIRE := Color(0.98, 0.30, 0.03)
const FIRE_DEEP := Color(0.50, 0.07, 0.01)
## The scorch under the fire, and the only colour here that is SUBTRACTIVE. See
## SCORCH_SHADER for why the effect needs a dark pass at all.
const SOOT := Color(0.26, 0.15, 0.11)
## What the blade is tinted with. Not FIRE: `HitFlash` multiplies the tint by its
## own HIT_ENERGY of 2.4, so 0.30 of green comes back out at 0.72 and the steel
## reads white-hot with an orange edge. 0.22 survives the multiply at 0.45 and
## the blade stays the colour of a poker instead of a lightsaber.
const FIRE_BLADE := Color(0.95, 0.22, 0.02)

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

## The sweep, which is the effect. OOT's spin does not put a static ring on the
## floor — it drags a burning comet tail around the hero, and the tail is BEHIND
## the blade the whole way, thinning into embers as it goes.
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
## circle at 0.48 s and the last of the fire is still burning at ~0.78 s, after
## the hero has his feet back.
const SWEEP_TIME := 0.48

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
## Ocarina's is not a particle system at all. It is a textured ribbon swept round
## Link — one continuous piece of fire with a bright head and an ember tail — and
## the honest version of that here is the same thing: an annulus of geometry
## built once, with a shader that only lights the part of it the blade has
## already passed. The sweep is a float going 0 → 1; frame rate cannot put holes
## in it, because there is nothing being deposited.
##
## The particles did not go away, they went back to being what particles are good
## at: EMBERS spat off the head, which are meant to be discrete.
##
## **The shape, which is four swept bands and not one flat washer.**
##
## The first version of this was a single annulus lying on the floor. It read as
## a ring and it read as fire, and from the over-the-shoulder camera this game
## actually plays at it also read as a DECAL — a picture of fire printed on the
## flagstones, because that is exactly what one horizontal sheet is. Fire has a
## body. So the disc stayed, and three vertical shells now stand on it at rising
## radii, each leaning outward as it climbs.
##
## Three rather than one for a reason worth keeping: a single vertical sheet is
## a cardboard cut-out from every angle except dead-on, and three at different
## radii, gains and noise phases overlap into something with a front, a middle
## and a back. That parallax between the shells is the whole of the depth.
##
## A profile is [radial offset, height] from the band's base radius, swept round
## the circle. UV.y runs 0 at the first point to 1 at the last, so "0 is the root
## and 1 is the tip" holds for both kinds of band: the disc's tip is its outer
## edge, a shell's tip is the top of the flame. One falloff serves both.
const RING_BASE := 0.10
## The disc. Barely any rise left in it — it used to flare 0.34 m at the outer
## edge, which was the only way a lone sheet could avoid vanishing edge-on to a
## low camera, and the shells do that job properly now.
const DISC_RADIUS := 1.18
const DISC_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.00), Vector2(0.34, 0.01), Vector2(0.68, 0.06), Vector2(1.02, 0.22),
]
## The flame shells: up and outward, with most of the height in the middle of the
## climb so the tips lean rather than spike. 0.82 m tall, which is half the
## hero — tall enough to have presence past his knee, short enough that it is
## still a ring around him and not a wall he is standing inside.
const FLAME_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.00), Vector2(0.07, 0.26), Vector2(0.17, 0.55), Vector2(0.30, 0.82),
]
## Flat on the stone and wider than the flame at both ends. A scorch that only
## reaches as far as the fire looks like a hole in the floor; one that spills
## past it looks like the floor is dirty, which is the point.
const SCORCH_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.0), Vector2(0.60, 0.0), Vector2(1.20, 0.0), Vector2(1.80, 0.0),
]
## Base radius, noise phase, brightness — one row per shell. The LAG each one
## takes is derived from its index below. The radii straddle
## SWEEP_RADIUS (1.7) and the outermost tips land on `spin_reach` (2.1), so the
## fire ends where the damage does.
##
## The gains are the additive budget. Where the three shells overlap on screen
## they SUM, and 1.0 each would put 3.0 into every channel at the head and give
## back a white blob — the exact failure this file has already had once, in blue.
##
## They started at 0.62 / 0.72 / 0.55 and that was still too much: three shells
## whose plumes overlap on screen at the head, each carrying a near-white colour,
## summed to a white slab with a flame-shaped hole in the middle of it. These
## numbers are the ones that survived being photographed.
const FLAME_SHELLS: Array[Vector3] = [
	Vector3(1.36, 0.37, 0.42),
	Vector3(1.62, 0.71, 0.50),
	Vector3(1.88, 0.13, 0.36),
]
## How many quads round the circle. 160 is ~4 cm of arc per segment at the outer
## edge, which is far finer than the shader's own noise and keeps the ragged
## flame edge from looking faceted.
## How far behind the blade each successive shell's head sits, in turns. 0.012 is
## about 4°, so the outermost trails the disc by 13°.
const SHELL_LAG := 0.012
const RING_SEGMENTS := 160
## How much of the circle is burning at once, in turns. 0.62 means the fire
## behind the blade stretches most of the way back round and the head is always
## clearly the head — a longer tail closes the loop into a plain ring and loses
## the direction, a shorter one reads as a comet with no ring at all.
const RING_TAIL := 0.62
## The scorch lags further: soot does not go out when the flame does, and the
## dark band still sitting under the fading tail is most of what keeps the ring
## legible on a torchlit floor.
const SCORCH_TAIL := 0.95
## The ring grows as it burns, which is the last of the Ocarina read: the fire
## leaves him rather than orbiting him. Scale, not radius, so the already-drawn
## arc expands with the head instead of the band spiralling outward.
const RING_GROW := Vector2(0.88, 1.10)

## The ring shader. Unshaded and additive like everything else here, and it never
## writes depth — a flat additive disc that occludes itself flickers along the
## seam where the two halves of the band meet.
##
## `head` is the sweep, in turns, and it is the only thing animated: a fragment
## whose UV.x is ahead of it has not been cut yet, one further behind than `tail`
## has burnt out. It is allowed to run past 1.0 so the tail can finish crossing
## the seam after the head has closed the circle.
##
## The noise is sampled on the LOCAL POSITION rather than on UV, and that is not
## a style choice. UV.x wraps from 1 back to 0 at the seam, so any noise keyed on
## it draws a hard vertical crack through the fire at the hero's front. Position
## has no seam — the ring is a closed loop in space whatever the parameterisation
## says.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled;

uniform float head = -1.0;
uniform float tail = 0.62;
uniform float burn = 1.0;
uniform vec3 white_hot : source_color = vec3(1.0, 0.92, 0.76);
uniform vec3 light : source_color = vec3(1.0, 0.60, 0.16);
uniform vec3 mid : source_color = vec3(0.98, 0.30, 0.03);
uniform vec3 ember : source_color = vec3(0.50, 0.07, 0.01);

varying vec3 loc;
// Per-band, carried in the vertex colour: which noise phase this band samples
// at, and how much of the additive budget it is allowed to spend.
varying float phase;
varying float gain;
varying float lag;

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
	phase = COLOR.r;
	gain = COLOR.g;
	lag = COLOR.b;
}

void fragment() {
	// Four noise fields. `lick` decides where the flame TIPS reach, `flick` is
	// the flicker within the band, `rise` is the one that only matters on the
	// vertical shells — it scrolls DOWN the local Y, so the pattern climbs, and
	// without it a standing sheet has no vertical structure at all and reads as
	// a curtain. `ragged` bends the sweep boundary itself.
	//
	// All four are sampled on LOCAL POSITION, never on UV. UV.x wraps from 1 back
	// to 0 at the seam, so any noise keyed on it draws a hard vertical crack
	// through the fire at the hero's front; position has no seam, because the
	// ring is a closed loop in space whatever the parameterisation says. `phase`
	// offsets each band so the three shells do not flicker in lockstep, which is
	// what would collapse them back into one thick sheet.
	float lick = fbm(loc.xz * 2.6 + vec2(phase * 11.0, TIME * 1.6));
	float flick = fbm(loc.xz * 4.6 - vec2(TIME * 2.3, -phase * 7.0));
	float rise = fbm(vec2((loc.x + loc.z) * 3.2 + phase * 5.0, loc.y * 2.8 - TIME * 3.0));
	float ragged = (fbm(loc.xz * 3.1 + vec2(TIME * 0.9, phase * 3.0)) - 0.5) * 0.035;

	// How long ago the blade passed this angle, in turns. Negative means it has
	// not been here yet.
	//
	// `ragged` bends that boundary by about ±6°, and it is doing more work than
	// its size suggests. Without it the leading edge is a perfectly straight
	// radial cut, and a straight radial cut across a 1 m band photographs as a
	// paper WEDGE: the first render of this had a bright trapezoid at the head
	// that read as a hole in the effect rather than as the front of it.
	float age = head - UV.x - lag + ragged;
	float life = 1.0 - clamp(age / tail, 0.0, 1.0);
	if (age < 0.0) {
		life = 0.0;
	}
	// And the cut itself is softened over ~5° so the fire arrives rather than
	// appearing. Asymmetric on purpose: it opens fast, because the head IS the
	// blade and a blade does not have a gradient in front of it.
	float lead = smoothstep(-0.004, 0.012, age);

	// v = 0 at the band's root, 1 at its tip — the disc's outer edge, or the top
	// of a flame. The tip is eaten away by the noise, which is what makes both
	// read as licking flame instead of as a gradient-filled washer.
	float v = UV.y;
	// Split between a floor and the noise, and both halves matter: all floor and
	// every band is the same height and they read as walls, all noise and the
	// bands are eaten down to wisps with no body left to them.
	// The three weights sum to at most 0.70, and the 0.30 of falloff below takes
	// that to exactly 1.0 — which is the point. Let rim + falloff exceed 1 and the
	// hottest columns run all the way to the last row of vertices, where they are
	// cut off by the GEOMETRY: a flame with a flat top, which photographed as a
	// white brick sitting on the head of the sweep.
	float rim = 0.22 + 0.30 * lick + 0.18 * rise;
	float band = smoothstep(0.0, 0.18, v) * (1.0 - smoothstep(rim, rim + 0.30, v));

	// The head is a hot spot about 20° long, not a step: this is the blade
	// itself, and it is the brightest thing in the effect.
	float hot = exp(-max(age, 0.0) * 22.0);
	// 1.1, not the 1.6 it started at. The exponent is how much of the circle is
	// still lit, and at 1.6 the tail was gone within a third of a turn of the
	// head — a comet with no ring behind it. This is the number that decides
	// whether the effect reads as Saturn or as a shooting star.
	float body = pow(life, 1.1) * (0.50 + 0.60 * mix(flick, rise, 0.5));
	// The head is hot in COLOUR, only slightly hotter in BRIGHTNESS — and that
	// split is the whole fix for the white slab this had at first. Pushing both
	// at once means the fragment that is already being tinted toward white is
	// also the one being driven past 1.0, so it clips to pure white and the
	// flame shape inside it is lost. Let the ramp say "hot" and keep the
	// intensity in range.
	float i = band * lead * (body * 0.85 + hot * 0.50) * gain * burn;
	// A hard ceiling per band, because `gain` alone cannot stop three shells
	// OVERLAPPING on screen from summing past white at the one angle the effect
	// is for. Judge these numbers stacked, never one at a time.
	i = min(i, 0.66);

	// The colour ramp, and the `- v * 0.38` in it is the trick worth keeping:
	// heat falls off UP the flame as well as behind the head, so every band is
	// white at its root and ember at its tip. That vertical gradient is what a
	// real flame has and what makes even the flat disc read as something with a
	// near side and a far side.
	float heat = clamp(hot * 0.95 + life * 0.85 - v * 0.30, 0.0, 1.0);
	vec3 col = ember;
	col = mix(col, mid, smoothstep(0.08, 0.42, heat));
	col = mix(col, light, smoothstep(0.30, 0.66, heat));
	col = mix(col, white_hot, smoothstep(0.90, 1.00, heat));

	// ALPHA stays at 1.0 and every fade lives in the colour — black added to the
	// framebuffer is nothing, whatever the blend func does with alpha.
	ALBEDO = col * i;
	ALPHA = 1.0;
}
"""

## The scorch under the fire: the same sweep, drawn on the floor, MULTIPLYING.
##
## **Why a dark pass exists at all.** Everything else in this effect is additive,
## and additive light can only ever brighten what is behind it — so on the
## torchlit stone this game is mostly set on, the fire was competing with a floor
## that was already halfway to its own colour. The band read as a wash. A flame
## in life is legible because it darkens what it sits on as much as it lights it:
## it scorches, and it throws the surroundings into shadow by contrast. So a
## second, wider annulus lies on the flagstones under the flame and multiplies
## them toward soot.
##
## It is drawn BEFORE the fire (`render_priority = -1`), which is not optional:
## transparent passes composite in priority order, and a multiply landing after
## the additive pass would darken the flame itself instead of the floor.
##
## The identity for a multiply is WHITE, not black — the mirror of the rule for
## the additive passes, and the same trap. Every fade here therefore walks the
## colour back toward vec3(1.0), which is "leave the floor alone".
const SCORCH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled;

uniform float head = -1.0;
uniform float tail = 0.95;
uniform float burn = 1.0;
uniform vec3 soot : source_color = vec3(0.34, 0.20, 0.14);

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
	float ragged = (fbm(loc.xz * 2.4) - 0.5) * 0.05;
	float age = head - UV.x + ragged;
	float life = 1.0 - clamp(age / tail, 0.0, 1.0);
	if (age < 0.0) {
		life = 0.0;
	}

	// Soft at both rims, and softer than the flame's: this is a shadow, and a
	// shadow with a hard edge is a sticker.
	float v = UV.y;
	float band = smoothstep(0.0, 0.30, v) * (1.0 - smoothstep(0.55, 1.0, v));
	// The darkest point is a little BEHIND the head, not at it — under the flame
	// itself, where a real one would be blocking the most light.
	float dark = band * smoothstep(0.0, 0.10, age) * pow(life, 0.65) * burn;
	dark *= 0.55 + 0.45 * fbm(loc.xz * 3.6);

	ALBEDO = mix(vec3(1.0), soot, clamp(dark, 0.0, 1.0));
	ALPHA = 1.0;
}
"""

var _sword: Node3D
var _glow := HitFlash.new()
var _light: OmniLight3D
## What the sweep turns. The embers hang off this and nothing else does.
var _pivot: Node3D
## Motes drawn to the blade while the button is held. Parented to the sword, so
## they are emitted along whatever arc the hand is travelling.
var _gather: GPUParticles3D
## The fire itself: the disc and the three flame shells, one mesh, lit a slice at
## a time by RING_SHADER.
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
## The dark pass on the floor beneath it. A child of `_ring`, so it inherits the
## placement and the growth for free.
var _scorch: MeshInstance3D
var _scorch_mat: ShaderMaterial
## Embers thrown off the head of the fire. Parented to `_pivot` at
## `SWEEP_RADIUS`, NOT to the blade: the sword is animated and the animation is
## not a source of truth for where the effect should be — it dips, it
## foreshortens, and it belongs to a clip borrowed from another character. The
## pivot turns at a rate this file owns.
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
	_build_ring()
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
	_glow.glow(FIRE_BLADE, ramp * GLOW_FULL)
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
	_glow.glow(FIRE_BLADE, GLOW_FULL)

	# Both the fire and the embers are cut loose from the hero for the length of
	# the effect. They are placed where he is STANDING when he lets go and left
	# there: he is locked for the swing, but he is not locked afterwards, and a
	# ring that walked away with him would undo the one thing the world-space
	# particles were bought for.
	var yaw := global_transform.basis.get_euler().y
	_place(_ring, yaw)
	_place(_pivot, yaw)

	_tween = create_tween().set_parallel(true)

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
		_set_head(0.0)
		# Past 1.0 by a whole tail, at the SAME angular rate: the head closes the
		# circle at SWEEP_TIME and then keeps going, eating the tail out from under
		# itself until there is nothing left burning. That extra 0.62 of a turn is
		# where "the magic lags the sword" now lives.
		# Past 1.0 by the LONGEST tail of the two passes, at the same angular rate
		# throughout: the head closes the circle at SWEEP_TIME and then keeps going,
		# eating first the flame and then the scorch out from under itself until
		# there is nothing left. Running it only to the flame's tail would cut the
		# soot off mid-fade when `clear` hides the mesh.
		var span := SWEEP_TIME * (1.0 + SCORCH_TAIL)
		_tween.tween_method(_set_head, 0.0, 1.0 + SCORCH_TAIL, span)
		_tween.tween_property(
			_ring, ^"scale",
			Vector3(RING_GROW.y, 1.0, RING_GROW.y),
			span
		).from(Vector3(RING_GROW.x, 1.0, RING_GROW.x))

	if _pivot != null and _burst != null:
		_pivot.rotation.y = yaw
		_sweep(true)
		# NEGATIVE, so it goes clockwise seen from above — see SWEEP_RADIUS.
		# tween_property on the pivot rather than a per-frame rotation: the embers
		# have to come off the same head the shader is drawing, and a hand-rolled
		# tick would drift from it at whatever the frame rate was that second.
		_tween.tween_property(_pivot, ^"rotation:y", yaw - TAU, SWEEP_TIME).from(yaw)
		_tween.tween_callback(_sweep.bind(false)).set_delay(SWEEP_TIME)

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
	# The embers already in the air are deliberately NOT killed here — only their
	# emitter is. They are world-space and finish their own lifetimes, which is
	# the whole "the magic lags the sword" read: the hero has his feet back before
	# the last of the fire behind him has gone out.
	_sweep(false)


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


## Ember emitter on or off. Off also parks the pivot back at the hero's facing,
## so the next spin starts in front of him rather than wherever the last one
## happened to stop.
func _sweep(on: bool) -> void:
	if _burst == null:
		return
	_burst.emitting = on
	if not on and _pivot != null:
		_pivot.top_level = false
		_pivot.rotation.y = 0.0


## Where the blade is, in turns round the circle. Both passes read the same
## number — the scorch is the same sweep with a longer memory, and giving it its
## own clock is how the shadow ends up lagging the thing casting it. -1 parks it
## before the start, which draws nothing at all.
func _set_head(t: float) -> void:
	if _ring_mat != null:
		_ring_mat.set_shader_parameter(&"head", t)
	if _scorch_mat != null:
		_scorch_mat.set_shader_parameter(&"head", t)


func _set_glow(e: float) -> void:
	# FIRE_BLADE, not FIRE_HOT — see the constant. HitFlash multiplies the tint by
	# 2.4, so a colour with 0.66 of green in it comes out of the tonemapper as a
	# white-hot blade with an orange edge, which is a lightsaber, not a charged
	# sword.
	_glow.glow(FIRE_BLADE, e)


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
	_light.light_color = FIRE_HOT
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
		[0.0, Color(FIRE_DEEP.r, FIRE_DEEP.g, FIRE_DEEP.b, 0.0)],
		[0.3, FIRE_DEEP],
		# Brightest as it ARRIVES, which is the read: the fire is going into the
		# sword. Peaks at FIRE rather than FIRE_HOT because this is the moment the
		# motes are most crowded, and crowded is where the sum whitens.
		[0.85, FIRE],
		# To BLACK, not just to transparent — alpha does not attenuate ADD.
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_gather.process_material = pm
	_gather.draw_pass_1 = _quad(0.055)
	_gather.material_override = _mote_material()
	# Up the blade, so the motes converge on steel rather than on his knuckles.
	_gather.position = Vector3(0.0, 0.55, 0.0)
	_sword.add_child(_gather)


## The fire: four swept bands in one mesh, lit a slice at a time by RING_SHADER.
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
	# Then the shells standing on it. x = base radius, y = noise phase, z = gain.
	# Each shell out from the middle is dealt a little more LAG, so their heads are
	# staggered instead of arriving as one front. Three sheets that all start at
	# the same angle read as three parallel walls however much noise is on them;
	# staggered by a few degrees each, the same three read as one plume being
	# dragged round, which is the entire point of having three.
	for k in FLAME_SHELLS.size():
		var shell: Vector3 = FLAME_SHELLS[k]
		_sweep_band(v, uv, cols, idx, shell.x, FLAME_PROFILE, shell.y, shell.z,
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
	_ring_mat.set_shader_parameter(&"white_hot", FIRE_WHITE)
	_ring_mat.set_shader_parameter(&"light", FIRE_LIGHT)
	_ring_mat.set_shader_parameter(&"mid", FIRE)
	_ring_mat.set_shader_parameter(&"ember", FIRE_DEEP)

	_ring = MeshInstance3D.new()
	_ring.name = "SpinRing"
	_ring.mesh = mesh
	_ring.material_override = _ring_mat
	# Shadow casting off for the same reason the blade light casts none: this is
	# a glow, not a lamp — and a 4 m disc of shadow-casting fire in a torchlit
	# room is both expensive and nonsense.
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)

	_build_scorch()


## The dark pass, parented UNDER the ring so that placing and growing the fire
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
	_scorch_mat.set_shader_parameter(&"soot", SOOT)
	# BEFORE the fire. See SCORCH_SHADER — a multiply composited after the
	# additive pass darkens the flame instead of the floor.
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


## The embers thrown off the head of the fire.
##
## This is the entire surviving job of the old trail emitter, and it is the job
## particles were always right for: discrete sparks flung outward and upward off
## the leading edge, dying at their own rates. Their count is a tenth of what the
## ribbon needed because nothing here has to JOIN UP — a gap between two sparks
## is two sparks, whereas a gap in a ring is a broken ring.
func _build_burst() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SpinSweep"
	add_child(_pivot)

	_burst = GPUParticles3D.new()
	_burst.name = "SpinEmbers"
	_burst.amount = 90
	# Longer than the sweep that throws them, and longer than the ring's own burn,
	# so the last sparks are still falling after the fire has gone out.
	_burst.lifetime = 0.85
	# NOT one_shot. The emitter runs for the length of the sweep and is switched
	# off by hand at the end of it; a one-shot would dump every spark at whatever
	# angle the pivot happened to be at.
	_burst.one_shot = false
	# 0.0: sparks come out evenly across the sweep rather than in gouts.
	_burst.explosiveness = 0.0
	_burst.randomness = 0.6
	# World space, and this is the load-bearing flag. In local space every spark
	# would ride the pivot round and they would be a rigid arm sweeping the room
	# instead of embers left in the air.
	_burst.local_coords = false
	_burst.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_burst.emitting = false

	var pm := ParticleProcessMaterial.new()
	# A small wafer at the blade's radius. It no longer has to be wide enough to
	# bridge a frame's worth of travel — that was the ribbon's problem and the
	# ribbon is a mesh now — so this is back to being a point-ish source.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.10, 0.04, 0.16)
	# Local -Z at the emitter, which — with the emitter parked out along the
	# pivot's -Z — points directly AWAY from the hero, and tilted up: these are
	# sparks off a fire and fire throws them upward.
	pm.direction = Vector3(0.0, 0.55, -1.0)
	pm.spread = 26.0
	pm.initial_velocity_min = 1.1
	pm.initial_velocity_max = 2.6
	pm.radial_accel_min = 0.2
	pm.radial_accel_max = 1.0
	pm.tangential_accel_min = 0.0
	pm.tangential_accel_max = 0.8
	# Real gravity, unlike the old ribbon, and for the opposite reason. A trail
	# that sagged turned the ring into a spiral staircase; a SPARK that does not
	# arc over and fall is not a spark, it is a floating dot. The ring's flatness
	# is the mesh's job now, so these are free to behave.
	pm.gravity = Vector3(0.0, -3.2, 0.0)
	pm.damping_min = 0.4
	pm.damping_max = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.scale_curve = _shrink_curve()
	# No white stop. A white first stop is invisible as a decision and fatal as a
	# result: it is the brightest thing on screen at the exact frame the most
	# sparks overlap.
	pm.color_ramp = _ramp([
		[0.0, FIRE_HOT],
		[0.35, FIRE],
		[0.8, FIRE_DEEP],
		[1.0, Color(0.0, 0.0, 0.0, 0.0)],
	])
	_burst.process_material = pm
	# Small. An ember is a speck; the fire it comes off is the ring.
	_burst.draw_pass_1 = _quad(0.075)
	_burst.material_override = _mote_material()
	# Out at the blade's radius and at hip height. -Z because that is the hero's
	# forward (docs/CONTRACT.md §2.5), so the sweep starts in front of him.
	_burst.position = Vector3(0.0, 0.55, -SWEEP_RADIUS)
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
