shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 rust_albedo : source_color = vec4(0.72, 0.22, 0.09, 1.0);
uniform vec4 warmth : source_color = vec4(1.0, 0.54, 0.24, 1.0);
uniform float focus : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	float warp = sin(UV.x * 94.0) * sin(UV.y * 72.0);
	float cloth = 0.97 + warp * 0.025;
	ALBEDO = rust_albedo.rgb * cloth;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.5 + 0.5 * sin(TIME * 1.15);
	float glow = emission_strength * (0.62 + pulse * 0.18 + rim * 0.28);
	glow *= 1.0 + focus * 1.35;
	EMISSION = warmth.rgb * glow;
}
