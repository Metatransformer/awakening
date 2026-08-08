shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Screen-space refraction shell for fire and shock impacts.
//
// Everything else in the FX vocabulary adds photons. This adds nothing — it displaces the
// image behind it, which is the one channel that cannot be mistaken for "a bright thing was
// drawn here". A detonation that bends the pillar behind it reads as a pressure event; the
// same detonation with one more additive sprite reads as more sprite. It is also the cheapest
// effect here: one screen sample, no lighting, no particles.
//
// Shaped as an expanding *shell*, not a disc: the displacement peaks in a ring and falls to
// zero at the centre, so the middle of the blast stays readable (the enemy you just hit must
// remain visible) while the boundary shears. `wave` is tweened 0 -> 1 by Vfx and drives both
// the ring's radius and its decay, so one uniform animates the whole thing.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

/// 0 at the impact frame, 1 when the shell has passed. Tweened by Vfx.
uniform float wave : hint_range(0.0, 1.0) = 0.0;
/// Peak screen-space displacement, in UV units, at wave = 0.
uniform float strength : hint_range(0.0, 0.2) = 0.035;
/// Half-width of the shell as a fraction of the quad's radius.
uniform float shell_width : hint_range(0.02, 0.6) = 0.28;
/// Extra warm lift where the air is thickest. Small on purpose — this is a distortion, not
/// a glow; the glow layers are the additive particles.
uniform vec4 bloom_tint : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float bloom_amount : hint_range(0.0, 1.0) = 0.12;

void vertex() {
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 keep_scale = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * keep_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;

	// The shell sweeps outward across the quad as `wave` runs 0 -> 1.
	float front = mix(0.15, 1.05, wave);
	float shell = 1.0 - smoothstep(0.0, shell_width, abs(r - front));
	// Fade out at the quad boundary so the effect never shows a rectangular edge, and fade
	// the whole thing as the wave completes.
	shell *= (1.0 - smoothstep(0.85, 1.0, r)) * (1.0 - wave);

	vec2 dir = r > 0.0001 ? d / max(r, 0.0001) : vec2(0.0);
	vec2 offset = dir * shell * strength;
	vec3 behind = texture(screen_tex, SCREEN_UV + offset).rgb;

	ALBEDO = behind + bloom_tint.rgb * shell * bloom_amount;
	ALPHA = clamp(shell * 1.4, 0.0, 1.0);
}
