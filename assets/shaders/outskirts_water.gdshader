shader_type spatial;
// Stylized BotW-flavoured water (AESTHETIC §2/§3 — procedural surface, no flat plastic).
// One shader for ocean, tarns and rivers. The look is built from FOUR cheap procedural
// layers, no textures: rolling swell displaces the mesh (real 3D undulation), fine
// scrolling ripples perturb the NORMAL so the sun scatters across it, a crest→trough
// colour ramp tints shallow vs deep, and a fresnel rim brightens the grazing edges.
// Opaque on purpose: a see-through plane skips the depth write and draws ON TOP of the
// land it should sit in (see Main._build_ocean). Mood rides on light, not murk.
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 shallow_color : source_color = vec3(0.17, 0.55, 0.60);
uniform vec3 deep_color : source_color = vec3(0.05, 0.22, 0.36);
uniform float wave_amp = 0.30;        // metres of VERTEX swell — set 0 on coarse meshes (the far
                                      // ocean) or the wave aliases into spikes between sparse verts
uniform float swell_normal = 0.5;     // strength of the swell in the SHADING normal (per-pixel,
                                      // tessellation-independent) — carries the wave look on flat geometry
uniform float wave_len = 13.0;        // swell wavelength in metres
uniform float wave_speed = 0.75;
uniform float ripple_scale = 0.45;    // fine-ripple frequency (per metre)
uniform float ripple_strength = 0.55;
uniform float ripple_speed = 0.6;
uniform float fresnel_strength = 0.55;
uniform float water_roughness = 0.06; // low → crisp sun glint
uniform float water_specular = 0.95;
uniform float detail_fade_start = 40.0;  // metres from camera where fine ripple detail begins to fade
uniform float detail_fade_end = 220.0;   // metres where ripples are fully flattened — no unfiltered
                                          // per-pixel noise left to alias into the "sparkly" far-water look
uniform float swell_fade_start = 200.0;  // metres where the coarse crossing-swell pattern begins to fade —
                                          // beyond this the 3-direction sine sum in swell() is unmasked by
                                          // any noise and reads as a moiré/cross-hatch lattice from above
uniform float swell_fade_end = 900.0;    // metres where swell's contribution to colour/normal is fully flat

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	// 3 octaves (was 4). fbm is called 3× per water pixel (ripple value + its two finite-difference
	// taps for the normal), so dropping the finest octave cuts ~25% of the per-pixel noise across all
	// water on screen. The lost octave is sub-ripple detail — imperceptible on the stylized surface.
	for (int k = 0; k < 3; k++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// Sum of three crossing directional swells — a cheap Gerstner stand-in for the height.
float swell(vec2 p, float t) {
	float h = sin(dot(p, vec2(1.0, 0.35)) / wave_len + t);
	h += 0.6 * sin(dot(p, vec2(-0.4, 1.0)) / (wave_len * 0.7) + t * 1.3);
	h += 0.4 * sin(dot(p, vec2(0.7, -0.7)) / (wave_len * 1.5) + t * 0.8);
	return h;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += swell(wpos.xz, t) * wave_amp;   // plane/disc sit y-up → object y is world up
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = wpos.xz;

	// Fine ripple detail is per-pixel screen-frequency noise with no mip chain behind it — at
	// distance many ripple cycles land inside one pixel and it aliases into the "too-high-res,
	// sparkly" look instead of blurring away like a mipmapped texture would. Fade the fine detail
	// out with camera distance (a cheap stand-in for LOD) so far water reads as smooth swell.
	float cam_dist = length(wpos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(detail_fade_start, detail_fade_end, cam_dist);
	// second, farther fade for the coarse swell itself — detail only hides the fbm ripple noise that
	// masks swell()'s periodicity; past that range with nothing left to mask it, its fixed 3-direction
	// sine sum aliases into a visible moiré lattice on aerial/top-down water (e.g. the overworld ocean)
	float swell_detail = 1.0 - smoothstep(swell_fade_start, swell_fade_end, cam_dist);

	// coarse swell normal (analytic finite difference) — kept at full strength near, eased far out
	// so distant water still shows broad swell shape, just no high-frequency crawl
	float e = 0.6;
	float sx = swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t);
	float sz = swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t);
	vec3 n = vec3(-sx * swell_normal * mix(0.6, 1.0, detail) * swell_detail, 1.0, -sz * swell_normal * mix(0.6, 1.0, detail) * swell_detail);

	// fine scrolling ripples scattered across the surface — faded to zero at distance
	float rt = TIME * ripple_speed;
	vec2 rp = p * ripple_scale;
	float r0 = fbm(rp + vec2(rt, rt * 0.3));
	float rx = fbm(rp + vec2(0.18, 0.0) + vec2(rt, rt * 0.3)) - r0;
	float rz = fbm(rp + vec2(0.0, 0.18) + vec2(rt, rt * 0.3)) - r0;
	n += vec3(-rx, 0.0, -rz) * ripple_strength * 7.0 * detail;
	n = normalize(n);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// crest→trough colour, then brighten the grazing fresnel edges
	float crest = clamp(0.5 + swell(p, t) * 0.22 * swell_detail + (r0 - 0.5) * 0.4 * detail, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, crest);
	float fr = 1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fres = fr * fr * fr;   // = pow(fr, 3.0), exact, cheaper than a transcendental pow
	col = mix(col, shallow_color * 1.35, fres * fresnel_strength);

	ALBEDO = col;
	// blur the sun glint on far water too — a crisp low-roughness specular on a per-pixel-aliased
	// normal is what reads as sparkly noise from a distance; roughen it as detail fades
	ROUGHNESS = mix(water_roughness, 0.5, 1.0 - detail);
	METALLIC = 0.0;
	SPECULAR = water_specular;
	RIM = 0.25;
}
