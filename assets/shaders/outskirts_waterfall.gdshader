shader_type spatial;
// Falling water sheet (waterfalls — WaterFeatures.dress). Streaks scroll DOWN the sheet in UV space
// (u across the flow, v along the 3D arc — see WaterFeatures._overlay_ribbon), so the motion reads
// correctly on any drop angle without per-fall tuning. Same stylized no-texture recipe as
// water.gdshader: value-noise streaks + a crest tint + fresnel rim; opaque (depth-writes) on purpose.
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.55, 0.72, 0.78);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float scroll_speed = 2.6;    // UV-v per second — the fall rate of the streaks
uniform float streak_scale = 5.0;    // streak frequency across the sheet (per UV-u)
uniform float water_roughness = 0.18;

varying vec2 suv;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	suv = UV;
}

void fragment() {
	float t = TIME * scroll_speed;
	// long vertical streaks: stretched noise scrolling down-flow, a second octave for shimmer
	float s = vnoise(vec2(suv.x * streak_scale, suv.y * 1.4 - t));
	s += 0.5 * vnoise(vec2(suv.x * streak_scale * 2.3 + 7.0, suv.y * 3.1 - t * 1.6));
	s /= 1.5;
	vec3 col = mix(base_color, foam_color, smoothstep(0.35, 0.8, s));
	float fr = 1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	col = mix(col, foam_color, fr * fr * 0.5);
	ALBEDO = col;
	ROUGHNESS = water_roughness;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	RIM = 0.3;
}
