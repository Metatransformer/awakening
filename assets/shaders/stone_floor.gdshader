shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural flagstone floor for the arena.
//
// The isometric camera means the floor is HALF THE SCREEN (see GDD §8) — a flat colour
// or a wireframe grid (grid_floor.gdshader) reads as a test level, not a place. This
// shader builds worn, individually-coloured flagstones with mortar joints, chipped
// edges, grime pooled in the cracks, and real derivative-based relief so the key light
// rakes across it and actually shows texture instead of a flat Lambert response.
//
// Everything is generated from world position, not mesh UVs — like grid_floor.gdshader,
// that means the pattern never stretches or seams no matter how the floor mesh is
// scaled, and different rooms sharing this material stay visually consistent without
// per-mesh UV unwrapping.

uniform vec3 base_color_a : source_color = vec3(0.22, 0.20, 0.18);
uniform vec3 base_color_b : source_color = vec3(0.29, 0.27, 0.24);
// Full +/- swing at the hash extremes (0.22 = +/-22%), not the old half-swing
// reading — see the tile_hash application below. This alone kills most of the
// "printed pattern" look: real paving is never one flat colour per stone.
uniform float tile_brightness_variation : hint_range(0.0, 1.0) = 0.22;
// Per-cell hue rotation in degrees, +/- at the hash extremes.
uniform float tile_hue_jitter_deg : hint_range(0.0, 30.0) = 6.0;

// World metres per raw Voronoi cell. Domain warping (see flagstones() below)
// merges several raw cells into each visually-read "stone" at roughly 3.9x
// this value in this shader's current warp/jitter configuration — that
// multiplier was measured empirically from a rendered screenshot (a 90px
// cell against a ~60px-tall, 1.73m-tall character), not derived from the
// warp math, so retune by eye/screenshot rather than assuming 1:1 or 2x.
// 0.077 -> ~0.077 * 3.9 =~ 0.30 m flagstones (target: real cobble, 25-35cm).
uniform float flagstone_scale : hint_range(0.02, 5.0, 0.005) = 0.077;
uniform float warp_strength : hint_range(0.0, 1.0) = 0.30;   // irregular tile silhouettes
uniform float jitter_amount : hint_range(0.0, 1.0) = 0.55;   // how far Voronoi points wander in-cell

// Grout is no longer an independent near-black colour (that reads as ink, not
// as a gap between stones). It's now an AO term: the stone's own albedo,
// darkened — see the flagstones() blend below.
uniform float grout_darkening : hint_range(0.0, 1.0) = 0.55;
uniform float mortar_width : hint_range(0.0, 0.3) = 0.05;

uniform vec3 grime_color : source_color = vec3(0.05, 0.06, 0.04);
uniform float grime_amount : hint_range(0.0, 1.0) = 0.35;

uniform float chip_strength : hint_range(0.0, 1.0) = 0.40;
uniform float bevel_height : hint_range(0.0, 0.2) = 0.012;
uniform float surface_bump_strength : hint_range(0.0, 0.5) = 0.15;
uniform float relief_strength : hint_range(0.0, 20.0) = 5.5;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_grime : hint_range(0.0, 1.0) = 0.90;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Second, much-lower-frequency mask (real-world metres, independent of
// flagstone_scale) for regional character — damp patches and dirt drifts —
// so the floor doesn't read as infinitely uniform paving.
uniform float regional_mask_scale : hint_range(1.0, 30.0) = 8.0; // metres per fbm cycle
uniform float regional_albedo_strength : hint_range(0.0, 1.0) = 0.15; // +/- albedo swing
uniform float regional_roughness_strength : hint_range(0.0, 1.0) = 0.35; // damp -> shinier

// Off by default: the floor mesh in this project is a flat BoxMesh top face, so a
// single XZ projection is exact and three times cheaper. Flip this on only if the
// material ends up on a ramp, stair, or other non-flat floor geometry.
uniform bool enable_triplanar = false;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ---- hashing / value noise --------------------------------------------------------

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

// ---- cheap HSV hue rotation for per-cell colour jitter ----------------------------
// Only the hue channel is touched; luminance jitter is handled separately by
// tile_brightness_variation so the two effects stay independently tunable.

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// Jittered Voronoi. Returns the nearest (f1) and second-nearest (f2) point distances
// plus the id of the nearest cell — f2 - f1 approximates distance-to-border, which is
// what carves the mortar groove without needing an explicit edge-finding pass.
void voronoi(vec2 p, out float f1, out float f2, out vec2 cell_id) {
	vec2 base = floor(p);
	f1 = 8.0;
	f2 = 8.0;
	cell_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = base + vec2(float(x), float(y));
			vec2 jitter = (hash2(cell) - 0.5) * jitter_amount;
			vec2 point = cell + 0.5 + jitter;
			float d = length(point - p);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				cell_id = cell;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
}

// Builds the flagstone pattern for one 2D projection. Called once for a flat floor, or
// up to three times (one per triplanar axis) when enable_triplanar is on.
void flagstones(vec2 p, out vec3 albedo, out float height, out float rough) {
	// Domain-warp before the Voronoi lookup: a plain jittered grid still reads as "a
	// grid" at a glance. Warping the sample point with a slow fbm gives each flagstone
	// an irregular, hand-cut silhouette instead of a uniform paver size.
	vec2 warp = vec2(fbm(p * 0.6 + 11.0), fbm(p * 0.6 - 7.0)) - 0.5;
	vec2 wp = p / flagstone_scale + warp * warp_strength;

	float f1, f2;
	vec2 cell_id;
	voronoi(wp, f1, f2, cell_id);

	float edge = f2 - f1;
	// Antialiased mortar mask — same discipline as grid_floor.gdshader: derive the AA
	// width from screen-space derivatives so joints stay crisp up close and don't
	// shimmer into moire at distance or on a grazing isometric angle.
	float edge_deriv = fwidth(edge);
	float mortar_mask = 1.0 - smoothstep(mortar_width, mortar_width + edge_deriv * 1.5, edge);

	// Chipped edges: break the clean Voronoi border with high-frequency noise so
	// corners look worn and knocked rather than laser-cut.
	float chip_noise = fbm(wp * 6.0 + cell_id * 3.7);
	float chip_mask = smoothstep(0.35, 1.0, chip_noise) * chip_strength;
	mortar_mask = clamp(mortar_mask + chip_mask * (1.0 - smoothstep(mortar_width, mortar_width * 3.0, edge)), 0.0, 1.0);

	float tile_hash = hash1(cell_id);
	vec3 stone = mix(base_color_a, base_color_b, tile_hash);
	// Full +/-tile_brightness_variation swing at the hash extremes (tile_hash-0.5
	// ranges +/-0.5, so the *2.0 restores the full stated percentage).
	stone *= 1.0 + (tile_hash - 0.5) * 2.0 * tile_brightness_variation;

	// Independent hue hash so luminance and hue don't co-vary with the same seed
	// (that would just look like a second brightness pass, not a colour pass).
	float hue_hash = hash1(cell_id + vec2(31.7, 91.3));
	vec3 stone_hsv = rgb2hsv(stone);
	stone_hsv.x = fract(stone_hsv.x + (hue_hash - 0.5) * (tile_hue_jitter_deg / 360.0));
	stone = hsv2rgb(stone_hsv);

	// Grime pools in the grooves and in a handful of low, shaded tiles — never
	// uniformly, which is what makes it read as accumulated dirt instead of a colour
	// filter over the whole floor.
	float grime_noise = fbm(wp * 1.7 + 5.0);
	float grime_mask = clamp(mortar_mask * 0.8 + grime_noise * grime_amount - 0.3, 0.0, 1.0) * grime_amount;
	vec3 tile_color = mix(stone, grime_color, grime_mask);

	// Grout as an AO term (same hue as the stone it sits between, just darker) instead
	// of an independent near-black colour — a flat near-black line reads as ink drawn
	// on top of the floor, not as a gap between two physical stones.
	vec3 grout = stone * grout_darkening;
	albedo = mix(tile_color, grout, mortar_mask);

	// Height field feeding the derivative normal map below: each tile is a gentle
	// raised plateau (bevel_height) that dips into the mortar groove, plus fine
	// surface noise so even flat, even light still shows texture.
	float bevel = smoothstep(0.0, mortar_width * 2.5, edge) * bevel_height;
	float fine = (fbm(wp * 9.0) - 0.5) * surface_bump_strength;
	height = bevel + fine - mortar_mask * bevel_height * 0.6;

	rough = mix(roughness_base, roughness_grime, max(mortar_mask, grime_mask));
}

void fragment() {
	vec3 albedo;
	float height;
	float rough;

	if (enable_triplanar) {
		vec3 n = abs(world_normal);
		vec3 w = pow(n, vec3(4.0));
		w /= (w.x + w.y + w.z + 0.0001);

		vec3 ax, ay, az;
		float hx, hy, hz;
		float rx, ry, rz;
		flagstones(world_position.zy, ax, hx, rx);
		flagstones(world_position.xz, ay, hy, ry);
		flagstones(world_position.xy, az, hz, rz);

		albedo = ax * w.x + ay * w.y + az * w.z;
		height = hx * w.x + hy * w.y + hz * w.z;
		rough = rx * w.x + ry * w.y + rz * w.z;
	} else {
		flagstones(world_position.xz, albedo, height, rough);
	}

	// Regional character: a second, much larger-scale fbm (real-world metres, not
	// flagstone-relative) so the floor has damp patches and dirt drifts instead of
	// reading as infinite, uniform paving no matter how far the camera pans. Damp
	// patches darken the albedo a little and lower roughness so they actually catch
	// a specular highlight instead of just looking like a paint blotch.
	float regional_noise = fbm(world_position.xz / regional_mask_scale) - 0.5; // -0.5..0.5
	albedo *= 1.0 + regional_noise * 2.0 * regional_albedo_strength;
	float damp_amount = clamp(-regional_noise * 2.0, 0.0, 1.0);
	rough = mix(rough, rough * 0.5, damp_amount * regional_roughness_strength);

	// Derivative normal mapping: perturb the lighting normal from the screen-space
	// slope of the procedural height field instead of sampling a normal texture that
	// doesn't exist. NORMAL_MAP is tangent-space (matches the mesh's own UV/tangent
	// basis), so this plays correctly with the key light raking across the floor.
	vec2 slope = vec2(dFdx(height), dFdy(height)) * relief_strength;
	NORMAL_MAP = vec3(slope * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = specular;
}
