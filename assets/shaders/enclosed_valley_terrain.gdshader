shader_type spatial;
// Broad world-space variation keeps each LOD ring in the same warm daylight
// family. Vertex colour carries normalized height (R), slope (G), and depth band (B).
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 valley_grass : source_color = vec3(0.19, 0.27, 0.12);
uniform vec3 forest_moss : source_color = vec3(0.11, 0.18, 0.075);
uniform vec3 warm_rock : source_color = vec3(0.30, 0.285, 0.245);
uniform vec3 high_rock : source_color = vec3(0.40, 0.385, 0.325);
uniform vec3 summit_dust : source_color = vec3(0.45, 0.435, 0.35);
uniform float rock_slope_start : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float rock_slope_end : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float summit_start : hint_range(0.0, 1.0, 0.01) = 0.73;
uniform float summit_end : hint_range(0.0, 1.0, 0.01) = 0.94;

varying vec3 terrain_data;
varying vec3 terrain_world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	terrain_data = COLOR.rgb;
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float height = terrain_data.r;
	float slope = terrain_data.g;
	float lod_band = terrain_data.b;
	vec2 world_uv = terrain_world_position.xz;

	// The shortest pattern is about eighteen metres across; nothing resolves into
	// sub-two-metre grain or distant sparkle.
	float broad = value_noise(world_uv * 0.024);
	float local_shape = value_noise(world_uv * 0.055 + vec2(4.7, -2.3));
	float variation = mix(broad, local_shape, 0.34);
	vec3 lowland = mix(forest_moss, valley_grass,
		smoothstep(0.20, 0.80, variation));
	vec3 rock = mix(warm_rock, high_rock,
		clamp(height * 0.76 + variation * 0.16, 0.0, 1.0));
	float rock_mask = smoothstep(rock_slope_start, rock_slope_end, slope);
	rock_mask = max(rock_mask, smoothstep(0.50, 0.88, height) * 0.34);
	vec3 color = mix(lowland, rock, rock_mask);

	// Nearby cliff faces retain geological weight through broad strata and blocks,
	// never high-frequency procedural grain.
	float cliff_face = smoothstep(0.76, 0.96, slope);
	float strata = sin(terrain_world_position.y * 0.32 + broad * 2.1) * 0.5 + 0.5;
	float blocks = value_noise(world_uv * 0.060 + vec2(
		terrain_world_position.y * 0.018, -terrain_world_position.y * 0.014));
	vec3 fractured_rock = mix(warm_rock * 0.78, high_rock,
		clamp(blocks * 0.62 + strata * 0.38, 0.0, 1.0));
	color = mix(color, fractured_rock, cliff_face * 0.82);

	float summit_mask = smoothstep(summit_start, summit_end, height);
	summit_mask *= 1.0 - smoothstep(0.36, 0.76, slope);
	color = mix(color, summit_dust, summit_mask * 0.54);
	color *= mix(0.94, 1.05, variation);

	// Mid and far are explicit depth bands: each is lighter and more restrained,
	// but both stay warm green/olive rather than drifting to neutral or cyan haze.
	float mid_band = smoothstep(0.18, 0.52, lod_band);
	float far_band = smoothstep(0.72, 0.96, lod_band);
	float local_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 warm_desaturated = vec3(local_luma * 1.02,
		local_luma * 1.01, local_luma * 0.86);
	color = mix(color, warm_desaturated, mid_band * 0.14);
	color += vec3(0.045, 0.046, 0.034) * mid_band;
	local_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	warm_desaturated = vec3(local_luma * 1.025,
		local_luma * 1.01, local_luma * 0.84);
	color = mix(color, warm_desaturated, far_band * 0.12);
	color += vec3(0.028, 0.029, 0.021) * far_band;

	ALBEDO = color;
	ROUGHNESS = mix(0.95, 0.84, rock_mask);
	METALLIC = 0.0;
	SPECULAR = 0.16;
	AO = mix(0.92, 1.0, broad);
}
