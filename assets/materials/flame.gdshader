shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The torch flame. A single Y-billboarded quad with a procedural teardrop.
//
// Why not a particle system: OOT torch fire is one animated sprite card. A GPU
// particle plume reads as a modern engine effect — soft, volumetric, smeary. A
// hard-edged card with a wobbling silhouette reads as 1998, and it costs one quad.
//
// Y-billboard rather than full billboard: the flame must stay vertical. A fully
// camera-facing card tips over as the third-person camera pitches down, and a
// leaning flame is instantly wrong.
//
// Written to ALBEDO, not EMISSION — `unshaded` outputs ALBEDO and ignores EMISSION
// entirely (the same trap fx_additive.gdshader documents). `energy` pushes it above
// 1.0 so the Environment glow pass has something to bloom into a halo.

uniform vec3 core_color : source_color = vec3(1.0, 0.94, 0.62);
uniform vec3 mid_color : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 edge_color : source_color = vec3(0.95, 0.26, 0.04);
uniform float energy : hint_range(0.0, 8.0) = 2.6;
uniform float speed : hint_range(0.0, 12.0) = 5.0;
// Sideways lick of the flame tip, in UV units.
uniform float wobble : hint_range(0.0, 0.5) = 0.11;
// Width of the flame at its widest, in UV units (quad is 1 wide).
uniform float girth : hint_range(0.05, 0.6) = 0.30;
// Ragged edge. 0 = a clean lozenge, 1 = a torn, guttering fire.
uniform float turbulence : hint_range(0.0, 1.0) = 0.55;

// Decorrelates torches so a row of them doesn't pulse in unison. Set per torch via
// GeometryInstance3D.set_instance_shader_parameter() — an instance uniform, so every
// flame in the dungeon still shares ONE material and stays batchable.
instance uniform float seed : hint_range(0.0, 100.0) = 0.0;

float hash1(vec2 p) {
	p = fract(p * vec2(123.31, 456.71));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// Y-axis billboard: rebuild the modelview basis so local X tracks the camera's
	// right vector projected onto the ground plane, local Y stays world up.
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(vec3(cam_right.x, 0.0, cam_right.z));
	vec3 fwd = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(fwd * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	float t = TIME * speed + seed * 13.7;

	// h: 0 at the wick, 1 at the tip.
	float h = 1.0 - UV.y;
	float x = UV.x - 0.5;

	// Teardrop: pinched at the wick, widest around a third of the way up, tapering
	// to nothing at the tip.
	float w = girth * sqrt(max(0.0, 1.0 - h)) * (0.30 + 0.70 * smoothstep(0.0, 0.28, h));

	// The tip licks sideways; the base is anchored to the wick.
	float lick = sin(t + h * 4.1) * 0.6 + sin(t * 1.73 + h * 7.3) * 0.4;
	float ox = lick * wobble * h * h;

	// Scrolling noise tears the silhouette so it guts and flares.
	float n = value_noise(vec2(UV.x * 3.0 + seed, h * 5.0 - TIME * speed * 0.55));
	w *= 1.0 + (n - 0.5) * 2.0 * turbulence * h;

	float d = abs(x - ox) / max(w, 0.001);

	float body = 1.0 - smoothstep(0.45, 1.0, d);
	float core = (1.0 - smoothstep(0.0, 0.62, d)) * (1.0 - smoothstep(0.10, 0.72, h));

	vec3 col = mix(edge_color, mid_color, body);
	col = mix(col, core_color, core * core);

	// The tip fades out instead of stopping at a hard line.
	float tip = 1.0 - smoothstep(0.72, 1.0, h);

	ALBEDO = col * energy * (0.55 + 0.45 * core);
	ALPHA = body * tip;
}
