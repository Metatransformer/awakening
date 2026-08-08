shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Antialiased world-space grid for the arena floor.
//
// A test room needs readable distance: without a grid it is impossible to tell how far
// a lunge carried you, how wide the spin's radius really is, or whether knockback is
// doing anything. Derived from world position rather than UVs so the cell size stays
// exactly one metre no matter how the floor mesh is scaled.

uniform vec3 base_color : source_color = vec3(0.135, 0.145, 0.185);
uniform vec3 line_color : source_color = vec3(0.30, 0.34, 0.44);
uniform vec3 major_color : source_color = vec3(0.42, 0.47, 0.60);
uniform float cell_size = 1.0;
uniform float major_every = 5.0;
uniform float line_strength : hint_range(0.0, 1.0) = 0.85;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Returns 1.0 on a grid line, 0.0 between them, with derivative-based antialiasing so
// distant cells fade to flat colour instead of aliasing into moire.
float grid_line(vec2 coordinate) {
	vec2 derivative = fwidth(coordinate);
	vec2 distance_to_line = abs(fract(coordinate - 0.5) - 0.5) / max(derivative, vec2(0.0001));
	return 1.0 - min(min(distance_to_line.x, distance_to_line.y), 1.0);
}

void fragment() {
	vec2 cell = world_position.xz / cell_size;
	float minor = grid_line(cell);
	float major = grid_line(cell / major_every);

	vec3 albedo = mix(base_color, line_color, minor * line_strength);
	albedo = mix(albedo, major_color, major * line_strength);

	ALBEDO = albedo;
	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
}
