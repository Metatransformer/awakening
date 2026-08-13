shader_type spatial;
// One restrained material across every LOD ring. Vertex colour carries the CPU-baked
// normalized height (R), world-up slope (G), and LOD band (B), so distant terrain
// keeps the same palette without extra height/normal texture samples per pixel.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 valley_grass : source_color = vec3(0.17, 0.23, 0.095);
uniform vec3 forest_moss : source_color = vec3(0.075, 0.12, 0.052);
uniform vec3 warm_rock : source_color = vec3(0.25, 0.245, 0.215);
uniform vec3 high_rock : source_color = vec3(0.36, 0.365, 0.34);
uniform vec3 summit_dust : source_color = vec3(0.48, 0.50, 0.48);
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
	// World-mapped frequencies keep pattern scale stable across all three meshes. The
	// fine octave fades outward so the coarse skyline cannot shimmer in motion.
	vec2 world_uv = terrain_world_position.xz;
	float broad = value_noise(world_uv * 0.027);
	float fine = value_noise(world_uv * 0.11) * (1.0 - lod_band * 0.72);
	float cliff_strata = value_noise(vec2(
		(terrain_world_position.x + terrain_world_position.z) * 0.035,
		terrain_world_position.y * 0.18));
	float grain = mix(broad, fine, 0.42);
	grain = mix(grain, cliff_strata, smoothstep(0.42, 0.78, slope) * 0.55);

	vec3 lowland = mix(forest_moss, valley_grass, smoothstep(0.22, 0.78, grain));
	vec3 rock = mix(warm_rock, high_rock, height * 0.72 + grain * 0.18);
	float rock_mask = smoothstep(rock_slope_start, rock_slope_end, slope);
	rock_mask = max(rock_mask, smoothstep(0.48, 0.86, height) * 0.34);
	vec3 color = mix(lowland, rock, rock_mask);
	// Cliff faces receive broad strata, fractured blocks, and dark seams in world
	// space. This is intentionally geometric in scale: it keeps a tall nearby wall
	// from collapsing into one taupe polygon without adding a texture dependency.
	float cliff_face = smoothstep(0.76, 0.96, slope);
	float strata = sin(terrain_world_position.y * 1.18
		+ value_noise(world_uv * 0.07) * 3.0) * 0.5 + 0.5;
	float blocks = value_noise(world_uv * 0.16
		+ vec2(terrain_world_position.y * 0.035, -terrain_world_position.y * 0.025));
	float seam = 1.0 - smoothstep(0.07, 0.16, abs(strata - 0.47));
	vec3 fractured_rock = mix(warm_rock * 0.66, high_rock * 0.94,
		clamp(blocks * 0.72 + strata * 0.28, 0.0, 1.0));
	fractured_rock *= mix(1.0, 0.58, seam * 0.52);
	color = mix(color, fractured_rock, cliff_face * 0.84);

	float summit_mask = smoothstep(summit_start, summit_end, height);
	summit_mask *= 1.0 - smoothstep(0.36, 0.76, slope);
	color = mix(color, summit_dust, summit_mask * 0.62);
	color *= mix(0.89, 1.08, grain);
	// Atmospheric restraint is baked into the far band instead of adding another
	// translucent pass: distant silhouettes stay legible while harmonising with fog.
	color = mix(color, vec3(0.33, 0.36, 0.36), lod_band * 0.20);

	ALBEDO = color;
	ROUGHNESS = mix(0.94, 0.82, rock_mask);
	METALLIC = 0.0;
	SPECULAR = 0.18;
	AO = mix(0.82, 1.0, broad);
}
