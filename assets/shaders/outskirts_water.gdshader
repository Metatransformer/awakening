shader_type spatial;
// PS2-styled daylight water: three broad colour bands and one slow directional wave.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.055, 0.16, 0.17);
uniform vec3 body_color : source_color = vec3(0.10, 0.25, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.18, 0.34, 0.27);
uniform vec2 flow_direction = vec2(0.92, 0.38);
uniform float motion_amplitude : hint_range(0.0, 0.035, 0.001) = 0.024;
uniform float motion_wavelength : hint_range(4.0, 24.0, 0.5) = 11.0;
uniform float motion_speed : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float fresnel_strength : hint_range(0.0, 0.08, 0.005) = 0.045;
uniform float water_roughness : hint_range(0.60, 1.0, 0.01) = 0.72;
uniform float water_specular : hint_range(0.0, 0.18, 0.01) = 0.12;

varying vec3 world_position;
varying float surface_wave;

float directional_wave(vec2 point, float time_value) {
	vec2 direction = normalize(flow_direction);
	float phase = dot(point, direction) * 6.2831853 / motion_wavelength;
	return sin(phase - time_value * motion_speed);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_wave = directional_wave(world_position.xz, TIME);
	VERTEX.y += surface_wave * motion_amplitude;
}

void fragment() {
	vec2 direction = normalize(flow_direction);
	float phase = dot(world_position.xz, direction) * 6.2831853 / motion_wavelength;
	float slope = cos(phase - TIME * motion_speed)
		* motion_amplitude * 6.2831853 / motion_wavelength;
	vec3 world_normal = normalize(vec3(-direction.x * slope, 1.0,
		-direction.y * slope));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float body_mix = smoothstep(-0.34, -0.02, surface_wave);
	float shallow_mix = smoothstep(0.24, 0.48, surface_wave);
	vec3 color = mix(deep_color, body_color, body_mix);
	color = mix(color, shallow_color, shallow_mix);
	float facing = 1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fresnel = facing * facing;
	color = mix(color, shallow_color * 1.06, fresnel * fresnel_strength);

	ALBEDO = color;
	ROUGHNESS = water_roughness;
	METALLIC = 0.0;
	SPECULAR = water_specular;
}
