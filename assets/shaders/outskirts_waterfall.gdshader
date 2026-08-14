shader_type spatial;
// One broad downward body band and one narrow, muted foam band at the fall base.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.10, 0.24, 0.23);
uniform vec3 body_band_color : source_color = vec3(0.17, 0.34, 0.30);
uniform vec3 foam_color : source_color = vec3(0.58, 0.66, 0.57);
uniform float scroll_speed : hint_range(0.0, 1.5, 0.05) = 0.62;
uniform float water_roughness : hint_range(0.60, 1.0, 0.01) = 0.76;
uniform float water_specular : hint_range(0.0, 0.18, 0.01) = 0.10;

varying vec2 surface_uv;

void vertex() {
	surface_uv = UV;
}

void fragment() {
	float flow = sin((surface_uv.y * 1.35 - TIME * scroll_speed)
		* 6.2831853 + surface_uv.x * 0.72);
	float body_band = smoothstep(-0.38, 0.30, flow);
	vec3 color = mix(base_color, body_band_color, body_band);
	float foam_band = smoothstep(0.86, 0.96, surface_uv.y);
	color = mix(color, foam_color, foam_band);

	ALBEDO = color;
	ROUGHNESS = water_roughness;
	METALLIC = 0.0;
	SPECULAR = water_specular;
}
