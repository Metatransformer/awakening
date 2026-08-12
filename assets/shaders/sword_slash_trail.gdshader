shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The dungeon environment blooms HDR values above 1.05. Keep MIX blending so
// the broad transparent body stays translucent, then lift only its rendered RGB
// over that threshold: the cobalt interior glows softly and the bone rim blooms.
// Two low-amplitude travelling waves keep the light sliding along the curve like
// a wet reflection instead of pulsing the whole attack brighter and darker.

uniform float interior_gain : hint_range(0.0, 4.0, 0.05) = 1.35;
uniform float rim_gain : hint_range(0.0, 5.0, 0.05) = 2.35;
uniform float shimmer_speed : hint_range(0.0, 20.0, 0.1) = 7.0;

void fragment() {
	float broad_wave = sin(UV.x * 18.0 - TIME * shimmer_speed + UV.y * 7.0);
	float fine_wave = sin(UV.x * 31.0 + TIME * shimmer_speed * 0.57 - UV.y * 11.0);
	float shimmer = 0.94 + broad_wave * 0.055 + fine_wave * 0.025;
	float rim = smoothstep(0.48, 1.0, UV.y);
	float gain = mix(interior_gain, rim_gain, rim) * shimmer;

	// Godot's unshaded path blooms HDR ALBEDO; EMISSION is not used here. Vertex
	// colour carries both the authored cobalt-to-bone gradient and its alpha fade.
	ALBEDO = COLOR.rgb * gain;
	ALPHA = COLOR.a;
}
