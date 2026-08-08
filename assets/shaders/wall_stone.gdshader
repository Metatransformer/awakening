shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural ashlar masonry for arena walls — the vertical counterpart to
// stone_floor.gdshader, built with the same hashing/derivative-normal techniques so
// floor and wall read as one coherent material family instead of two different looks
// bolted together.
//
// Walls in this project are plain axis-aligned BoxMesh slabs (see test_room.tscn), so
// this reads world position directly rather than mesh UVs: the coursing stays
// horizontal and the grime gradient stays vertical on every wall in the room without
// per-wall UV setup.

uniform vec3 base_color_a : source_color = vec3(0.20, 0.19, 0.21);
uniform vec3 base_color_b : source_color = vec3(0.27, 0.26, 0.29);
uniform float block_brightness_variation : hint_range(0.0, 1.0) = 0.18;

uniform float block_width : hint_range(0.2, 4.0) = 1.5;
uniform float block_height : hint_range(0.1, 2.0) = 0.55;
uniform float course_jitter : hint_range(0.0, 0.5) = 0.12; // per-block size wobble, hand-cut look

// Grout is an AO term — the block's own albedo, darkened — not an independent
// near-black colour. A flat painted-on colour is exactly what read as
// "electrical tape wrapped around a paper tube" on the pillars; a shaded,
// same-hue groove reads as a real gap between two blocks of stone instead.
uniform float grout_darkening : hint_range(0.0, 1.0) = 0.55;
uniform float mortar_width : hint_range(0.0, 0.3) = 0.06;

uniform vec3 grime_color : source_color = vec3(0.035, 0.045, 0.03);
uniform float grime_height : hint_range(0.0, 6.0) = 2.0; // world-space Y where grime fades out
uniform float grime_amount : hint_range(0.0, 1.0) = 0.5;
uniform float streak_frequency : hint_range(0.5, 10.0) = 3.5;
uniform float streak_strength : hint_range(0.0, 1.0) = 0.35;

uniform float chip_strength : hint_range(0.0, 1.0) = 0.35;
uniform float bevel_depth : hint_range(0.0, 0.2) = 0.035;
uniform float surface_bump_strength : hint_range(0.0, 0.5) = 0.12;
uniform float relief_strength : hint_range(0.0, 20.0) = 5.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_grime : hint_range(0.0, 1.0) = 0.98;
uniform float specular : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ---- hashing / value noise (mirrors stone_floor.gdshader) -------------------------

float hash1(vec2 p) {
	p = fract(p * vec2(123.31, 456.71));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash1(p), hash1(p + vec2(17.13, 5.7)));
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

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	// Pick the wall's own horizontal axis: whichever world axis the face normal is
	// NOT aligned with is the axis that runs along the wall face. This keeps coursing
	// horizontal on every wall in the room (north/south run along X, east/west run
	// along Z) without hand-tuning UVs per wall segment — the same "derive it from
	// world space" trick grid_floor.gdshader uses for its cell size.
	float u = abs(world_normal.x) > abs(world_normal.z) ? world_position.z : world_position.x;
	float v = world_position.y;

	float course = floor(v / block_height);
	// Running-bond offset: every other course shifts half a block so vertical joints
	// don't line up. Real masonry avoids that for structural reasons; it also reads as
	// far less "grid-like" to the eye than stacked bond does.
	float row_offset = mod(course, 2.0) * block_width * 0.5;
	vec2 wp = vec2(u + row_offset, v);

	vec2 cell = floor(wp / vec2(block_width, block_height));
	vec2 cell_hash = hash2(cell);
	vec2 local = fract(wp / vec2(block_width, block_height)) - 0.5;
	// Each block's apparent size wobbles a little so coursing looks hand-cut rather
	// than extruded.
	vec2 wobble = (cell_hash - 0.5) * course_jitter;
	vec2 edge_dist = 0.5 - abs(local - wobble);
	float edge = min(edge_dist.x, edge_dist.y);
	float edge_deriv = fwidth(edge);
	float mortar_mask = 1.0 - smoothstep(mortar_width, mortar_width + edge_deriv * 1.5, edge);

	// Chipped block corners, same technique as the floor.
	float chip_noise = fbm(wp * 5.0 + cell * 4.1);
	float chip_mask = smoothstep(0.4, 1.0, chip_noise) * chip_strength;
	mortar_mask = clamp(mortar_mask + chip_mask * (1.0 - smoothstep(mortar_width, mortar_width * 3.0, edge)), 0.0, 1.0);

	float block_id = hash1(cell);
	vec3 stone = mix(base_color_a, base_color_b, block_id);
	stone *= 1.0 + (block_id - 0.5) * block_brightness_variation;

	// Vertical moisture/grime gradient: walls read as TALL when the lower reaches are
	// visibly damp and the upper stone stays dry — a flat grime tint over the whole
	// wall reads as "dirty texture", not "height", and this game's whole camera
	// argument is that verticality has to be sold through material, not perspective.
	float height_fade = 1.0 - smoothstep(0.0, grime_height, v);
	float streaks = fbm(vec2(u * streak_frequency, v * 0.15));
	float streak_mask = smoothstep(0.4, 0.9, streaks) * streak_strength * height_fade;
	float grime_mask = clamp(mortar_mask * 0.6 + height_fade * grime_amount + streak_mask, 0.0, 1.0);

	vec3 tinted = mix(stone, grime_color, grime_mask);
	// AO-based grout instead of a fixed near-black paint colour — see the uniform
	// comment above. Darkening the block's own colour keeps the joint reading as a
	// shaded gap rather than an ink line drawn on top of the stone.
	vec3 grout = stone * grout_darkening;
	vec3 albedo = mix(tinted, grout, mortar_mask);

	float bevel = smoothstep(0.0, mortar_width * 2.5, edge) * bevel_depth;
	float fine = (fbm(wp * 8.0) - 0.5) * surface_bump_strength;
	float height = bevel + fine - mortar_mask * bevel_depth * 0.6;

	// Cheap relief via derivative normal mapping rather than true parallax occlusion:
	// this camera is a fixed 40° isometric pitch that rarely grazes a wall at a steep
	// angle, so parallax's per-pixel raymarch would spend GPU time on a depth cue the
	// player can barely perceive from that angle. Derivative normals give the same
	// "this is not flat" read for a fraction of the cost.
	vec2 slope = vec2(dFdx(height), dFdy(height)) * relief_strength;
	NORMAL_MAP = vec3(slope * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;

	ALBEDO = albedo;
	ROUGHNESS = mix(roughness_base, roughness_grime, grime_mask);
	METALLIC = 0.0;
	SPECULAR = specular;
}
