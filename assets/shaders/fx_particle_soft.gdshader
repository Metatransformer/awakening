shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// The workhorse draw material for every spell particle: a camera-facing additive quad
// with a procedural radial falloff and a depth-aware soft edge.
//
// WHY a shader instead of StandardMaterial3D + a gradient texture:
//   1. Soft particles. A hard-edged quad intersecting the floor draws a visible straight
//      seam, which is the single clearest "this is a billboard" tell at this camera angle.
//      Fading the quad out as it approaches the depth buffer removes the seam entirely and
//      is the difference between a puff sitting *in* the room and a sticker laid over it.
//   2. HDR headroom. Godot's unshaded path outputs ALBEDO directly and ignores EMISSION, so
//      a material capped at albedo 1.0 can never cross glow_hdr_threshold (1.0 in
//      spellblade_env.tres) and never blooms. `gain` pushes the core above 1.0 so the
//      effect actually leaks light into the image.
//   3. No texture asset. The falloff is one pow() — sharper and cheaper than sampling a
//      64px gradient, and `core` retunes it per layer instead of per texture.
//
// `tint` is written at runtime by Vfx from the *caller's* colour, never baked in: the same
// fireball scene backs Destruction's orange bolt and Necromancy's green one, and an ember
// that ignored the school colour would be a lie about which spell just went off.
// `tint_weight` is authored per layer instead — a white-hot core wants 0.4, an ember wants
// 1.0 — so a layer can stay near-white while still reading as the right element.

uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.25, 1.0);
/// 0 = ignore the caller's colour (stays white), 1 = fully take it.
uniform float tint_weight : hint_range(0.0, 1.0) = 1.0;
/// Multiplier on the output. Above ~1.2 the particle crosses the glow threshold and blooms.
uniform float gain : hint_range(0.0, 6.0) = 2.0;
/// Radial falloff exponent. 1 = flat disc, 4 = tight hot point with a wide soft skirt.
uniform float core : hint_range(0.5, 8.0) = 2.2;
/// Anisotropy on the falloff. (1,1) is a round blob; (1, 0.08) fades only across the quad's
/// width and leaves its length solid, which is how the thunder bolt's shaft stays a shaft
/// instead of becoming a very tall ellipse.
uniform vec2 falloff_scale = vec2(1.0, 1.0);
/// Whole-effect fade, tweened by Vfx for one-shot quads (flash frames, cores).
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
/// Metres of depth over which the quad fades out against solid geometry. 0 disables.
uniform float soft_distance : hint_range(0.0, 4.0) = 0.5;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

void vertex() {
	// Particle billboard, mirroring Godot's own BILLBOARD_PARTICLES codegen so a draw pass
	// and a lone MeshInstance3D using this same material behave identically. INSTANCE_CUSTOM.x
	// carries the per-particle rotation angle written by ParticleProcessMaterial's
	// angle/angular_velocity; for a plain mesh it is 0 and the spin term collapses to identity.
	float a = INSTANCE_CUSTOM.x;
	mat4 spin = mat4(
		vec4(cos(a), -sin(a), 0.0, 0.0),
		vec4(sin(a), cos(a), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	// Column lengths carry both the per-particle scale and the emitter node's scale, which is
	// how one impact scene serves a 0.5 m blade spark and a 3 m detonation.
	mat4 keep_scale = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * spin * keep_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length((UV - vec2(0.5)) * 2.0 * falloff_scale);
	float mask = pow(clamp(1.0 - r, 0.0, 1.0), core);

	// Soft-particle depth fade. Godot's depth buffer is already 0..1 in NDC, so the depth
	// sample goes straight into ndc.z without the usual *2-1 remap.
	float soft = 1.0;
	if (soft_distance > 0.001) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		view.xyz /= view.w;
		soft = clamp((-view.z - (-VERTEX.z)) / soft_distance, 0.0, 1.0);
	}

	// COLOR is the ParticleProcessMaterial colour ramp (white-with-alpha by design, so the
	// ramp shapes brightness over life while the hue stays the caller's).
	vec3 hue = mix(vec3(1.0), tint.rgb, tint_weight);
	ALBEDO = hue * COLOR.rgb * gain;
	ALPHA = clamp(mask * COLOR.a * alpha_mult * soft, 0.0, 1.0);
}
