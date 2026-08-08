shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Ground-projected shockwave / telegraph ring. Supersedes nova_decal.gdshader as the decal
// behind Vfx.ring(); that one is left in place for anything else that wants it.
//
// Three things changed, all of them about the ring reading as light on the floor rather than
// as a drawn hoop:
//
//  * ADDITIVE, and HDR. Godot's `unshaded` path outputs ALBEDO and ignores EMISSION, so the
//    old mix-blended decal could never exceed 1.0 and never crossed the environment's glow
//    threshold — it was a bright shape, not a glowing one. Here the leading edge is pushed
//    past 1.0 by `energy` and blooms, and being additive it only ever adds light to the
//    stone instead of painting over its texture.
//  * RAGGED, not perfect. The edge position, thickness AND brightness are modulated by hashed
//    angular noise, so the circle is never a clean circle and the hoop is never uniformly lit.
//    A geometrically perfect ring is the single most "programmer primitive" thing a spell can
//    put on the floor.
//  * NOTHING VARIES BY ANGLE ALONE INSIDE THE DISC. This is the rule the two previous versions
//    both broke. Any term that is a function of angle but not of radius is, by construction, a
//    radial streak that runs all the way to the centre — and a ring of those is a pie chart, no
//    matter how they are hashed or how many there are. Everything inside the rim is therefore
//    driven by 2D noise in (angle, radius), which breaks into patches instead.
//
// Apply to a flat XZ mesh spanning -1..1 (PlaneMesh). Vfx drives the size purely by node
// scale, so `edge_width` is in local 0..1 units and Vfx converts from metres.

uniform vec4 ring_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
/// Output multiplier on the leading edge. Above ~1.2 the rim blooms.
uniform float energy : hint_range(0.0, 8.0) = 2.4;
uniform float edge_width : hint_range(0.01, 0.6) = 0.12;
/// Tint left inside the swept area. Kept low: Vfx.ring() also backs enemy telegraphs, which
/// are often 3 m across, and a solid disc that size hides the floor and the enemy on it.
uniform float interior_alpha : hint_range(0.0, 1.0) = 0.16;
/// Pop-in, hold, residual mark and final fade, all on one tweened uniform.
uniform float alpha_mult : hint_range(0.0, 1.0) = 0.0;
/// How far behind the rim the swept wake trails, in local 0..1 units.
uniform float wake_length : hint_range(0.05, 1.0) = 0.42;
/// Per-instance, so two overlapping rings never break up identically.
uniform float seed : hint_range(0.0, 100.0) = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash21(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7)) + seed * 13.7) * 43758.5453123);
}

/// Value noise over (angle, radius). `cells_a` must be a whole number: the angular cell index
/// is wrapped modulo it, which is what makes the pattern continuous across atan()'s -PI/+PI
/// discontinuity instead of showing a seam running out to the rim.
float polar_noise(float turns, float rad, float cells_a, float cells_r) {
	vec2 x = vec2(turns * cells_a, rad * cells_r);
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a0 = mod(i.x, cells_a);
	float a1 = mod(i.x + 1.0, cells_a);
	float s00 = hash21(vec2(a0, i.y));
	float s10 = hash21(vec2(a1, i.y));
	float s01 = hash21(vec2(a0, i.y + 1.0));
	float s11 = hash21(vec2(a1, i.y + 1.0));
	return mix(mix(s00, s10, f.x), mix(s01, s11, f.x), f.y);
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	if (r > 1.02) {
		discard;
	}

	float turns = atan(p.y, p.x) / TAU;

	// RIM: angle-only noise is fine here and only here. The rim is a closed curve with no
	// interior, so deforming it by angle wobbles the outline rather than drawing spokes.
	// The deformation is a fraction of the RADIUS, not of the edge thickness — tied to
	// thickness it vanished on any ring wider than a couple of metres and the circle came
	// back out perfect.
	float rw = polar_noise(turns, 0.0, 6.0, 1.0) - 0.5;
	float rw2 = polar_noise(turns, 0.0, 17.0, 1.0) - 0.5;
	float rim = 0.925 + rw * 0.10 + rw2 * 0.035;

	// INTERIOR: 2D, always. Two octaves whose cells are subdivided radially as well as
	// angularly, so the swept area breaks into patches that are visibly detached from the
	// centre. Cell sizes converge as r drops, but the area there is tiny and the fill is
	// faint, so it reads as fine mottling rather than as a hub.
	float coarse = polar_noise(turns, r, 19.0, 4.0);
	float fine = polar_noise(turns, r, 41.0, 9.0);
	float patch = mix(coarse, fine, 0.45);
	// Polar cells necessarily converge at r = 0, and a bench frame showed the last trace of
	// the old failure surviving there as a small starburst at the hub. Fading the modulation
	// out toward its own mean over the innermost third removes it: the centre goes smooth
	// rather than spoked, which is also what the middle of a passed wave should look like.
	patch = mix(0.5, patch, smoothstep(0.0, 0.34, r));

	float w = edge_width * (0.55 + coarse);
	float band = 1.0 - smoothstep(0.0, w, abs(r - rim));
	band *= band;
	// Brightness varies around the rim. This matters more than the geometric wobble: an
	// evenly lit hoop reads as a drawn circle however wavy it is, while an unevenly lit one
	// reads as something burning along its length.
	band *= 0.3 + (rw + 0.5) * 1.45;

	// Swept wake behind the rim, mottled by the 2D noise.
	float wake = smoothstep(rim - wake_length, rim, r) * (1.0 - smoothstep(rim, rim + w, r));
	wake *= 0.25 + patch * 1.15;

	// Faint, roughly flat fill over the whole affected area so a telegraph's footprint is
	// legible. Deliberately NOT a centre-weighted gradient: that made a lit dish with a hot
	// spot in the middle, which is not what a wave passing through the floor looks like.
	float inside = (1.0 - smoothstep(rim - 0.06, rim + 0.02, r)) * (0.3 + patch * 1.0);

	float lit = clamp(band + wake * 0.5, 0.0, 1.0);
	vec3 hot = mix(ring_color.rgb, vec3(1.0), 0.8);
	vec3 body = mix(ring_color.rgb, hot, lit);

	ALBEDO = body * mix(0.4, energy, lit);
	ALPHA = clamp((band + wake * 0.38 + inside * interior_alpha) * alpha_mult, 0.0, 1.0);
}
