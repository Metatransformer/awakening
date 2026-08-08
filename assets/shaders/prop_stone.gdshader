shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural chiselled stone for scattered props — crates, sarcophagi, urns, rubble,
// barricades (see room.gd's _prop_material() / RoomDressing). A blind review called the
// props "untextured primitives"; this reuses the Voronoi/fBm/derivative-normal technique
// from stone_floor.gdshader and wall_stone.gdshader, recalibrated for a single hand-cut
// block instead of a paved floor or a coursed wall, plus a `seed` uniform so RoomDressing
// scattering ten instances of the same crate/urn/rubble mesh through a room doesn't render
// as ten identical clones.
//
// Object-space, always triplanar: unlike the floor (one dominant top face) or the wall
// (one dominant vertical face), a prop is a small, fully-visible 3D chunk where every face
// matters — a crate's side panels are as on-camera as its top. So this always blends three
// axis projections instead of gating triplanar behind a toggle the way stone_floor does.
// Object-space position (VERTEX, not world position) keeps the pattern fixed to the mesh
// regardless of where a room scatters or rotates the instance; `seed` is what actually
// decorrelates two otherwise-identical instances, not world placement — two crates built
// from the same mesh at two different room positions would already look coincidentally
// different by luck of world position, but two crates placed close together, or the same
// template reused across many procedurally generated rooms, would not without it.

uniform vec3 base_color_a : source_color = vec3(0.20, 0.185, 0.16);
uniform vec3 base_color_b : source_color = vec3(0.27, 0.25, 0.22);
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.22;

// Per-instance decorrelation, folded directly into every hash lookup below — see the
// voronoi()/stone_chunk() uses of `seed`.
//
// An `instance uniform`, not a plain uniform: this is the ONLY value that differs between
// two props in a room, and when it lived on the material, room.gd had to build a fresh
// ShaderMaterial per prop to hold it — ten props meant ten materials and ten draw calls
// that could never batch. Per-instance render data gives the same decorrelation for free.
// RoomDressing._apply_surface() draws it from the room's dressing RNG and sets it via
// GeometryInstance3D.set_instance_shader_parameter().
instance uniform float seed : hint_range(0.0, 1000.0) = 0.0;

// World metres per facet. Much smaller than the floor/wall scales: a whole prop is
// usually under a metre, so this wants 2-5 carved facets across a crate, not 30 flagstones.
uniform float facet_scale : hint_range(0.05, 2.0) = 0.35;
uniform float warp_strength : hint_range(0.0, 1.0) = 0.25;
uniform float jitter_amount : hint_range(0.0, 1.0) = 0.6;

// Seams are an AO term (the block's own colour, darkened) rather than an independent
// near-black colour — same reasoning as stone_floor's grout_darkening: a flat painted-on
// line reads as ink, a shaded gap between two facets of the same stone reads as real.
uniform float seam_darkening : hint_range(0.0, 1.0) = 0.55;
uniform float seam_width : hint_range(0.0, 0.3) = 0.06;

uniform vec3 grime_color : source_color = vec3(0.05, 0.055, 0.045);
uniform float grime_amount : hint_range(0.0, 1.0) = 0.4;

// Chipped edges: impact damage clustered near facet seams, same technique as the floor's
// mortar chipping — high-frequency noise breaks the clean Voronoi border so corners look
// knocked, not laser-cut.
uniform float chip_strength : hint_range(0.0, 1.0) = 0.55;
uniform float chip_scale : hint_range(1.0, 20.0) = 7.0;

// Low-frequency mineral banding across the whole prop, independent of facet_scale — what
// makes a sarcophagus or urn read as carved from one veined block rather than a flat grey
// mass. Direction is fixed (streaks run along local Y) rather than exposed per-instance,
// since every prop kind shares this one material family.
uniform float grain_scale : hint_range(1.0, 40.0) = 14.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.14;

uniform float bevel_height : hint_range(0.0, 0.2) = 0.015;
uniform float surface_bump_strength : hint_range(0.0, 0.5) = 0.16;
uniform float relief_strength : hint_range(0.0, 20.0) = 6.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_grime : hint_range(0.0, 1.0) = 0.95;
uniform float specular : hint_range(0.0, 1.0) = 0.4;

varying vec3 obj_position;
varying vec3 obj_normal;

void vertex() {
	// Object space, not world space (contrast stone_floor/wall_stone's world_position) —
	// see the header comment: the pattern must stay fixed to the mesh regardless of where
	// or how a room instance places/rotates it, so `seed` alone controls variety.
	obj_position = VERTEX;
	obj_normal = normalize(NORMAL);
}

// ---- hashing / value noise (mirrors stone_floor.gdshader) --------------------------------

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

// Jittered Voronoi, seed folded into the per-cell jitter so two different seeds produce
// genuinely different facet layouts (not just different colours on the same fracture
// lines) — the strongest form of per-instance decorrelation available here.
void voronoi(vec2 p, out float f1, out float f2, out vec2 cell_id) {
	vec2 base = floor(p);
	f1 = 8.0;
	f2 = 8.0;
	cell_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = base + vec2(float(x), float(y));
			vec2 jitter = (hash2(cell + seed * 7.0) - 0.5) * jitter_amount;
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

// Builds the chiselled-stone pattern for one 2D projection of object-space position.
void stone_chunk(vec2 p, out vec3 albedo, out float height, out float rough) {
	vec2 seeded_p = p + vec2(seed * 3.1, seed * 5.9);
	vec2 warp = vec2(fbm(seeded_p * 0.8 + 11.0), fbm(seeded_p * 0.8 - 7.0)) - 0.5;
	vec2 wp = seeded_p / facet_scale + warp * warp_strength;

	float f1, f2;
	vec2 cell_id;
	voronoi(wp, f1, f2, cell_id);

	float edge = f2 - f1;
	float edge_deriv = fwidth(edge);
	float seam_mask = 1.0 - smoothstep(seam_width, seam_width + edge_deriv * 1.5, edge);

	float chip_noise = fbm(wp * chip_scale + cell_id * 3.7 + seed * 1.3);
	float chip_mask = smoothstep(0.35, 1.0, chip_noise) * chip_strength;
	seam_mask = clamp(seam_mask + chip_mask * (1.0 - smoothstep(seam_width, seam_width * 3.0, edge)), 0.0, 1.0);

	float facet_hash = hash1(cell_id + seed * 9.7);
	vec3 stone = mix(base_color_a, base_color_b, facet_hash);
	stone *= 1.0 + (facet_hash - 0.5) * 2.0 * brightness_variation;

	// Mineral banding: low-frequency streaks along local Y, independent of the facet
	// pattern so it reads as the block's own material rather than another edge system.
	float grain = fbm(vec2(p.x * grain_scale, p.y * grain_scale * 0.25) + seed * 2.3);
	stone *= 1.0 + (grain - 0.5) * 2.0 * grain_strength;

	float grime_noise = fbm(wp * 1.6 + seed * 4.1);
	float grime_mask = clamp(seam_mask * 0.75 + grime_noise * grime_amount - 0.3, 0.0, 1.0) * grime_amount;
	vec3 tile_color = mix(stone, grime_color, grime_mask);

	vec3 seam = stone * seam_darkening;
	albedo = mix(tile_color, seam, seam_mask);

	float bevel = smoothstep(0.0, seam_width * 2.5, edge) * bevel_height;
	float fine = (fbm(wp * 9.0 + seed * 6.6) - 0.5) * surface_bump_strength;
	height = bevel + fine - seam_mask * bevel_height * 0.6;

	rough = mix(roughness_base, roughness_grime, max(seam_mask, grime_mask));
}

void fragment() {
	vec3 n = abs(obj_normal);
	vec3 w = pow(n, vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);

	vec3 ax, ay, az;
	float hx, hy, hz;
	float rx, ry, rz;
	stone_chunk(obj_position.zy, ax, hx, rx);
	stone_chunk(obj_position.xz, ay, hy, ry);
	stone_chunk(obj_position.xy, az, hz, rz);

	vec3 albedo = ax * w.x + ay * w.y + az * w.z;
	float height = hx * w.x + hy * w.y + hz * w.z;
	float rough = rx * w.x + ry * w.y + rz * w.z;

	// Derivative normal mapping, same technique as stone_floor/wall_stone: perturb the
	// lighting normal from the screen-space slope of the procedural height field instead
	// of sampling a normal texture that doesn't exist.
	vec2 slope = vec2(dFdx(height), dFdy(height)) * relief_strength;
	NORMAL_MAP = vec3(slope * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = specular;
}
