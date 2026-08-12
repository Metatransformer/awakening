shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The dungeon environment blooms HDR values above 1.05. Keep MIX blending so
// the broad transparent body stays translucent, then lift only its rendered RGB
// over that threshold: the cobalt interior glows softly and the bone rim blooms.
// The reference is not one milky sheet: darker water separates several bright,
// uneven current lines, and the room bends slightly through the translucent
// body. Keep all of that inside the existing MIX-blended ribbon so it still
// belongs below the charged spin's feedback budget.

uniform float interior_gain : hint_range(0.0, 4.0, 0.05) = 1.35;
uniform float rim_gain : hint_range(0.0, 5.0, 0.05) = 2.35;
uniform float shimmer_speed : hint_range(0.0, 20.0, 0.1) = 7.0;
uniform float refraction_strength : hint_range(0.0, 0.01, 0.0001) = 0.0022;
uniform vec4 water_highlight : source_color = vec4(0.345, 0.471, 0.784, 1.0);
uniform vec4 foam_highlight : source_color = vec4(0.847, 0.816, 0.722, 1.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

float current_line(float y, float centre, float width) {
	return 1.0 - smoothstep(width * 0.35, width, abs(y - centre));
}

void fragment() {
	float broad_wave = sin(UV.x * 18.0 - TIME * shimmer_speed + UV.y * 7.0);
	float fine_wave = sin(UV.x * 31.0 + TIME * shimmer_speed * 0.57 - UV.y * 11.0);
	float shimmer = 0.94 + broad_wave * 0.055 + fine_wave * 0.025;

	// Three clean parallel currents follow the same rounded blade arc. Their
	// brightness travels at different rates, but their positions do not wiggle:
	// the motion reads as light sliding over water rather than electrical noise.
	float flow_a = 0.78 + sin(UV.x * 13.0 - TIME * 5.2) * 0.22;
	float flow_b = 0.76 + sin(UV.x * 17.0 + TIME * 4.1 + 1.7) * 0.24;
	float flow_c = 0.80 + sin(UV.x * 21.0 - TIME * 6.4 + 3.1) * 0.20;
	float current_a = current_line(UV.y, 0.30, 0.050) * flow_a;
	float current_b = current_line(UV.y, 0.51, 0.062) * flow_b;
	float current_c = current_line(UV.y, 0.70, 0.046) * flow_c;
	float currents = clamp(current_a * 0.55 + current_b * 0.85 + current_c, 0.0, 1.0);

	float rim = smoothstep(0.66, 1.0, UV.y);
	float gain = mix(interior_gain, rim_gain, rim) * shimmer;
	float body = 1.0 - rim;

	// Bend the already-rendered room in two directions. The offset is deliberately
	// sub-pixel-to-few-pixel at 720p and disappears at the rim, where distortion
	// would soften the sword's readable cutting line.
	vec2 refract_wave = vec2(
		sin(UV.x * 21.0 - TIME * 6.0 + UV.y * 9.0),
		cos(UV.x * 15.0 + TIME * 4.7 - UV.y * 13.0));
	vec2 refract_uv = SCREEN_UV + refract_wave * refraction_strength * body;
	vec3 refracted_room = textureLod(screen_texture, refract_uv, 0.0).rgb;

	// Godot's unshaded path blooms HDR ALBEDO; EMISSION is not used here. Vertex
	// colour carries the broad cobalt-to-bone gradient. Currents add narrow blue
	// and pale foam bands above it, while the gaps remain mostly refracted room.
	vec3 base_light = COLOR.rgb * gain;
	vec3 current_light = mix(water_highlight.rgb, foam_highlight.rgb,
		current_c * 0.45) * currents * 1.15;
	float light_mix = 0.54 + rim * 0.46 + currents * body * 0.20;
	ALBEDO = mix(refracted_room, base_light + current_light, clamp(light_mix, 0.0, 1.0));
	ALPHA = clamp(COLOR.a * (0.58 + rim * 0.42 + currents * body * 0.70), 0.0, 1.0);
}
