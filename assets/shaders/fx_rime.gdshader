shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Ground rime left by a frost impact: needles of ice crystallising outward from the point
// of contact, then sublimating away.
//
// Frost is the one element whose *aftermath* is as characteristic as its impact — fire
// leaves smoke that drifts off, shock leaves nothing at all, but ice leaves a mark on the
// floor. GDD §8 notes the floor is half the screen at this camera angle, so a decal is the
// cheapest way to make a spell feel like it happened *to the room* rather than in front of
// it. Distinct from nova_decal.gdshader on purpose: that one is a hard-edged expanding
// shockwave ring, this is a static crystalline patch with no leading edge, so a Frost Nova
// reads as a wave that passed and a crust it left behind, not as two rings.
//
// Apply to a flat XZ mesh spanning -1..1 (a PlaneMesh works as-is). `growth` animates the
// crystals reaching outward; `alpha_mult` fades the whole patch.

uniform vec4 rime_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
/// 0 = nothing, 1 = needles have reached the mesh boundary. Tweened by Vfx.
uniform float growth : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
/// Angular cell count for the crystal grain. MUST be a whole number — the noise wraps modulo
/// it to stay seamless across atan()'s discontinuity.
uniform float needle_count : hint_range(6.0, 64.0) = 22.0;
/// Per-instance so two overlapping rime patches do not crystallise in lockstep.
uniform float seed : hint_range(0.0, 100.0) = 0.0;
/// Output multiplier. Godot's `unshaded` path writes ALBEDO straight to the frame and
/// ignores EMISSION entirely, so brightness — and therefore whether this crosses the
/// environment's glow threshold of 1.0 and blooms — has to be carried by ALBEDO itself.
uniform float energy : hint_range(0.0, 6.0) = 1.3;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash21(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7)) + seed * 9.3) * 43758.5453123);
}

/// Value noise over (angle, radius), wrapped modulo `cells_a` so there is no seam where
/// atan() flips. See fx_shockwave.gdshader for the long version of why the radial axis is
/// not optional: noise that varies by angle alone IS a spoke, and a disc of spokes is a
/// starburst. The first version of this shader drew literal radial needles and read as a
/// dandelion clock rather than as ice.
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
	if (r > 1.0) {
		discard;
	}

	float turns = atan(p.y, p.x) / TAU;

	// How far the frost has crawled at this angle. Angle-only is correct for a boundary —
	// it deforms the outline of the patch, it does not put structure inside it.
	float front = growth * (0.5 + 0.5 * polar_noise(turns, 0.0, 9.0, 1.0));
	float crust = 1.0 - smoothstep(front - 0.3, front, r);

	// The plate itself: two octaves of 2D grain, so it breaks into facets and holes the way
	// ice does when it takes a surface unevenly.
	float grain = polar_noise(turns, r, needle_count, needle_count * 0.4);
	float fine = polar_noise(turns, r, needle_count * 2.0, needle_count * 0.9);
	float facets = mix(grain, fine, 0.4);
	crust *= clamp(0.25 + facets * 1.25, 0.0, 1.0);

	// The growing edge runs brighter than the body — crystal tips catch the light, and it is
	// what makes the patch look like it is still spreading rather than painted on.
	float edge = (1.0 - smoothstep(0.0, 0.18, abs(r - front))) * (0.25 + fine * 1.25);

	float mask = clamp(crust * 0.8 + edge * 0.45, 0.0, 1.0);
	vec3 body = mix(rime_color.rgb, vec3(1.0), clamp(edge, 0.0, 1.0) * 0.7);

	ALBEDO = body * energy * (0.5 + clamp(edge, 0.0, 1.0) * 0.85);
	ALPHA = clamp(mask * alpha_mult, 0.0, 1.0);
}
