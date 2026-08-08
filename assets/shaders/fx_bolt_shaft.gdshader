shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// The shaft of a thunder strike.
//
// This exists because fx_particle_soft.gdshader with an anisotropic falloff — which is what
// the shaft used first — produces a bar of light with two perfectly straight, perfectly
// parallel edges and a constant brightness from top to bottom. That is a laser, not a
// discharge, and it is the same failure as a torus standing in for an explosion: a primitive
// wearing an emissive material.
//
// Lightning reads as lightning because of three things, none of which is the glow:
//   1. The centreline WANDERS. Three octaves of value noise along the shaft's height offset
//      it sideways, so the bolt kinks. The lowest octave does most of the work; the highest
//      only roughens the edge.
//   2. It is BRIGHTER IN PLACES. Discharge is not uniform along its length, and a bar that is
//      is read by the eye as a solid object.
//   3. It has a HARD CORE inside a SOFT GLOW. One falloff gives a fuzzy tube; two, with the
//      inner one narrow and clipped, give the overexposed white filament that makes the thing
//      look hot rather than merely bright.
//
// Applied to a tall QuadMesh whose UV.y runs 0 at the ground to 1 at the top of the strike.
// Billboarded exactly like fx_particle_soft so the two never disagree about which way a quad
// faces.

uniform vec4 tint : source_color = vec4(0.75, 0.7, 1.0, 1.0);
uniform float tint_weight : hint_range(0.0, 1.0) = 0.45;
/// Output multiplier. Above ~1.2 the core crosses the glow threshold and blooms.
uniform float gain : hint_range(0.0, 6.0) = 1.7;
/// Whole-effect fade, tweened by Vfx.
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
/// Sideways wander of the centreline, in quad half-widths. At 0 this is a straight bar again.
uniform float jitter : hint_range(0.0, 1.0) = 0.42;
/// Half-width of the white filament, in quad half-widths.
uniform float core_width : hint_range(0.005, 0.4) = 0.055;
/// Half-width of the surrounding glow.
uniform float glow_width : hint_range(0.05, 1.0) = 0.42;
/// Metres of fade where the bolt leaves the top of the quad, so it goes off into the dark
/// instead of ending on a cut edge.
uniform float top_fade : hint_range(0.0, 0.6) = 0.22;
/// Per-instance, so two simultaneous strikes are not the same bolt twice.
uniform float seed : hint_range(0.0, 100.0) = 0.0;
uniform float soft_distance : hint_range(0.0, 4.0) = 0.4;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

float hash11(float n) {
	return fract(sin(n * 12.9898 + 78.233 + seed * 7.1) * 43758.5453123);
}

float noise11(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

void vertex() {
	float a = INSTANCE_CUSTOM.x;
	mat4 spin = mat4(
		vec4(cos(a), -sin(a), 0.0, 0.0),
		vec4(sin(a), cos(a), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 keep_scale = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * spin * keep_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// UV.y is 1 at the top of a Godot QuadMesh; flip so h = 0 is the ground contact, which is
	// where the bolt should be pinned and where the kinks should die out.
	float h = 1.0 - UV.y;

	float wander = (noise11(h * 3.5) - 0.5) * 1.0
		+ (noise11(h * 9.0 + 17.0) - 0.5) * 0.45
		+ (noise11(h * 23.0 + 43.0) - 0.5) * 0.18;
	// Pinned at the ground, free at the top: a strike that wanders at the point of contact
	// looks like it missed.
	wander *= jitter * smoothstep(0.0, 0.22, h);

	float d = abs((UV.x - 0.5) * 2.0 - wander);

	float core = 1.0 - smoothstep(0.0, core_width, d);
	float glow = 1.0 - smoothstep(0.0, glow_width, d);
	glow *= glow;

	// Brightness varies along the length, and a couple of segments nearly gutter out.
	float flicker = 0.45 + 0.75 * noise11(h * 6.0 + 91.0);
	float ends = smoothstep(1.0, 1.0 - top_fade, h);

	float mask = clamp((core * 1.3 + glow * 0.55) * flicker * ends, 0.0, 1.0);

	float soft = 1.0;
	if (soft_distance > 0.001) {
		float dep = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dep, 1.0);
		view.xyz /= view.w;
		soft = clamp((-view.z - (-VERTEX.z)) / soft_distance, 0.0, 1.0);
	}

	// The filament stays near-white whatever the caster's colour is; the glow around it takes
	// the tint. Electricity that is fully the school colour reads as a beam.
	vec3 hue = mix(vec3(1.0), tint.rgb, tint_weight * (1.0 - core * 0.7));
	ALBEDO = hue * gain;
	ALPHA = clamp(mask * alpha_mult * soft, 0.0, 1.0);
}
