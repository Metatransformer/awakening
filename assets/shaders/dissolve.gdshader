shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Enemy-death dissolve.
//
// Discards fragments through a 3D noise field driven by `progress`, with a hot
// emissive band trailing the leading edge and a charred band just behind that. Object
// space (not UV, not world space) feeds the noise so the pattern is stable across the
// mesh regardless of animation and doesn't slide as the corpse gets knocked around by
// its own death stagger before the tween finishes.
//
// Discard rather than alpha blending is deliberate: a dissolving enemy should read as
// "genuinely ceasing to exist, tile by tile" — decisive, matching the GDD's "the player
// must never wonder if a hit landed" feedback bar — not as a translucency effect that
// fights with whatever VFX or floor detail is behind it.

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform vec3 edge_color : source_color = vec3(1.0, 0.42, 0.08);
uniform float edge_width : hint_range(0.01, 0.5) = 0.08;
uniform float edge_emission_energy : hint_range(0.0, 20.0) = 6.0;

uniform vec3 burn_color : source_color = vec3(0.05, 0.02, 0.01);
uniform float burn_width : hint_range(0.0, 0.5) = 0.12;

uniform vec3 base_color : source_color = vec3(0.5, 0.5, 0.5);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;

uniform float noise_scale : hint_range(0.1, 10.0) = 2.2;

varying vec3 object_position;

void vertex() {
	// Object space, taken AFTER any skinning has moved VERTEX, so the dissolve pattern
	// stays glued to the mesh's own geometry rather than sliding across it in world
	// space while the corpse topples or slides from knockback.
	object_position = VERTEX;
}

// ---- 3D hashing / value noise ------------------------------------------------------

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm3(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		sum += value_noise3(p) * amp;
		p *= 2.05;
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	float n = fbm3(object_position * noise_scale);
	float d = n - progress;

	if (d < 0.0) {
		discard;
	}

	float glow = 1.0 - smoothstep(0.0, edge_width, d);
	float burn = 1.0 - smoothstep(edge_width, edge_width + burn_width, d);

	ALBEDO = mix(base_color, burn_color, burn);
	EMISSION = edge_color * glow * edge_emission_energy;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
