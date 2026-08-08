shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Rolling smoke for fire impacts, and the only *subtractive-feeling* layer in the FX
// vocabulary: everything else in this game is additive and therefore only ever brightens
// the frame. A fire that only adds light reads as a flashbulb. Something dark that boils
// upward and occludes the bloom behind it is what makes the flash read as combustion.
//
// Mottled by two octaves of cheap value noise scrolling against each other rather than by a
// texture: a smoke puff that is a smooth radial gradient reads as a soft ball, and eight
// soft balls read as a cartoon cloud. The noise breaks the silhouette so the puffs merge
// into one mass instead of stacking as discs.

uniform vec4 tint : source_color = vec4(0.35, 0.2, 0.14, 1.0);
/// 0 = neutral charcoal, 1 = fully takes the caster's spell colour. Kept low by default:
/// smoke that is as saturated as the flame stops reading as smoke.
uniform float tint_weight : hint_range(0.0, 1.0) = 0.3;
/// Base darkness the tint is mixed over.
uniform vec3 soot : source_color = vec3(0.05, 0.045, 0.05);
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.5, 8.0) = 3.0;
uniform float churn : hint_range(0.0, 2.0) = 0.35;
uniform float soft_distance : hint_range(0.0, 4.0) = 0.9;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
	float r = length(UV - vec2(0.5)) * 2.0;
	float mask = smoothstep(1.0, 0.25, r);

	vec2 p = UV * noise_scale;
	float n = value_noise(p + vec2(TIME * churn, TIME * churn * 0.6));
	n = mix(n, value_noise(p * 2.3 - vec2(TIME * churn * 0.4, 0.0)), 0.5);
	// Erode the silhouette with the noise so the edge is ragged, not circular.
	mask *= smoothstep(0.18, 0.72, n * 0.65 + mask * 0.55);

	float soft = 1.0;
	if (soft_distance > 0.001) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		view.xyz /= view.w;
		soft = clamp((-view.z - (-VERTEX.z)) / soft_distance, 0.0, 1.0);
	}

	// A little of the flame colour survives in the thickest part of each puff, as if lit
	// from inside by the fire it came off.
	vec3 body = mix(soot, tint.rgb, tint_weight * n);
	ALBEDO = body;
	ALPHA = clamp(mask * COLOR.a * opacity * alpha_mult * soft, 0.0, 1.0);
}
