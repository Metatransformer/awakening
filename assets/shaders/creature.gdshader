shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Procedural creature skin/armour surface for the enemy roster.
//
// A blind review called the Wretch "an unlit flat-green placeholder" and singled out the
// Brute's material as the worst offender: "candy clearcoat. Flat single-value red albedo,
// huge specular lobe, zero roughness variation, no texture, no wear. Better silhouette
// than A's blob, worse SURFACE than anything in A's scene." This shader replaces the flat
// StandardMaterial3D enemy.gd used to build with the same procedural-surface discipline as
// stone_floor.gdshader / wall_stone.gdshader — hashed value noise, fBm, fwidth-antialiased
// masks, derivative normal mapping — aimed at a skinned character instead of a static box.
//
// Domain choice matters here in a way it doesn't for the floor/wall: those sample world
// position because their geometry never moves. An enemy is a posed, animated Mixamo rig
// (see enemy_appearance.gd) that walks, turns, and re-poses every frame. Sampling world
// position — or even the mesh's own local VERTEX, which is the post-skinning position for
// a skinned mesh — would make every noise term crawl across the skin as the character
// animates, which reads as a broken shader, not a surface. UV is the one coordinate that
// stays fixed to the mesh regardless of pose, so every noise lookup below samples UV.
// Trade-off: the Paladin rig's UV atlas has seams between islands (arm/torso/etc.), so the
// macro mottling can show a faint discontinuity at an island border. Kept deliberately
// subtle (macro_strength default 0.16) so that seam stays under the noise floor at play
// distance — push it harder only once/if a seamless atlas exists to back it.
//
// enemy.gd's ENEMY_TARGET_LUMA normalisation is what makes the roster read by HUE instead
// of by brightness — [uniform tint_color] is that already-normalised colour, and every
// noise term below perturbs value/hue symmetrically around it (multiplicative, zero-mean)
// rather than biasing it up or down, so the archetype's luma stays centred on target
// instead of drifting away from what enemy.gd computed.

uniform vec3 tint_color : source_color = vec3(0.5, 0.5, 0.5);

// ---- optional real skin, for the Meshy monster roster ------------------------------
// Everything above this shader was written for archetypes that have no texture at all, and
// that is still the default. The monsters imported from Valenfeld (goblin/orc/kobold/
// skeleton/ogre/troll/wraith/golem — see enemy_appearance.gd's MONSTERS table) DO ship a
// painted basecolor, and the obvious way to show it — swapping their meshes to a
// StandardMaterial3D — would have cost them every effect that lives in this file: the hit
// flash, the death fade, the telegraph pulse and the exposed-window pulse are all driven
// through `flash_energy` / `fade_alpha` on THIS material by enemy.gd. So the texture comes
// in here instead, as an alternative source for the albedo term only. Every stage below —
// mottling, crevice darkening, wear, relief, flash, fade — runs identically either way.
//
// filter_nearest_mipmap is the lofi/PSX house rule (matching the Valenfeld material
// convention): chunky texels on purpose, but still mipmapped, because an unmipmapped 2K
// skin on a monster ten metres away aliases into sparkling noise.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
// Value control for a textured body, standing in for the ENEMY_TARGET_LUMA normalisation
// enemy.gd applies to flat archetype colours. A painted skin cannot be renormalised in the
// shader (there is no cheap way to know its mean), so this is the knob enemy.gd sets per
// monster to keep the roster from out-valuing the player.
uniform float albedo_gain : hint_range(0.0, 2.0) = 1.0;
// How much of `tint_color` washes over the texture. 0 = the painted skin as authored;
// 1 = fully tinted, for palette-swap variants (a frost troll off the same troll skin).
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
// Hard floor under roughness_base no matter how low an archetype's own value is (Brute
// ships body_roughness = 0.25 in brute.tscn). This, the noise-driven roughness_variation
// below, and the lowered `specular` default together are what stop a low roughness_base
// from reading as a tight mirror highlight the way it did on the old flat material.
uniform float roughness_floor : hint_range(0.0, 1.0) = 0.32;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.32;
uniform float roughness_noise_scale : hint_range(1.0, 40.0) = 9.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// Well under StandardMaterial3D's implicit 0.5 default specular reflectance — that default
// was a direct, independent contributor to the Brute's "huge specular lobe" complaint,
// on top of the roughness/metallic combination.
uniform float specular : hint_range(0.0, 1.0) = 0.3;

// ---- mottled albedo: two fBm scales -----------------------------------------------
uniform float macro_noise_scale : hint_range(0.5, 20.0) = 3.2; // large blotches: bruising, hide/scale pattern, patina
uniform float macro_strength : hint_range(0.0, 1.0) = 0.16;
uniform float micro_noise_scale : hint_range(1.0, 80.0) = 22.0; // fine grain: pores, weave, hammered-metal texture
uniform float micro_strength : hint_range(0.0, 1.0) = 0.10;
// Small per-blotch hue rotation so the mottling doesn't read as a pure brightness filter —
// same technique as stone_floor's tile_hue_jitter_deg, at a much smaller default so it
// never fights the hue-only identity rule enemy.gd's luma normalisation relies on.
uniform float hue_jitter_deg : hint_range(0.0, 15.0) = 3.0;

// ---- crevice darkening, driven by the surface normal -------------------------------
// No baked AO/curvature map exists (no texture assets at all), so this fakes cavity
// shading from the posed normal itself: fwidth(NORMAL) spikes wherever the normal is
// changing fast from one pixel to the next — armpits, the waist bend, armour seams, the
// neck — regardless of the rig's current pose, since it is recomputed from the actual
// interpolated normal every frame instead of read from a baked map. It does not
// distinguish concave from convex (a sharp convex edge spikes it too), but in practice a
// creature's visible crevices ARE the sharp-normal-change areas, so it reads correctly at
// the subtle strength this is tuned to.
uniform float crevice_strength : hint_range(0.0, 1.0) = 0.35;
uniform float crevice_sharpness : hint_range(0.5, 8.0) = 2.2;
// Maps the raw fwidth(NORMAL) magnitude (small — typically well under 1.0) into a usable
// 0..1 range before the pow() above. Retune by eye/screenshot against the Paladin rig's
// actual vertex density, same as flagstone_scale's calibration note in stone_floor.
uniform float crevice_curvature_scale : hint_range(0.5, 20.0) = 3.0;

// ---- wear: scuffing on armoured archetypes ------------------------------------------
// 0 = pristine. enemy.gd derives this from the existing body_metallic export (an
// archetype already declares "hard armoured surface" via metallic > 0 — Brute ships 0.7,
// Caster 0.6, Wretch the default 0.0), so no new per-archetype scene wiring is needed.
// Wear reveals as pale scraped patches biased toward upward-facing, convex surfaces
// (shoulders, knuckles, a helm) — the places that actually rub against things — using the
// crevice term above, inverted, times a "faces up" bias, times its own scratch-streak
// noise, so it reads as directional scuffing rather than a uniform bleach.
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float wear_scale : hint_range(1.0, 60.0) = 16.0;
uniform vec3 wear_color : source_color = vec3(0.74, 0.70, 0.62);

// ---- fine surface relief: same derivative-normal technique as stone_floor/wall_stone ---
uniform float surface_bump_strength : hint_range(0.0, 0.5) = 0.12;
uniform float relief_strength : hint_range(0.0, 20.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;

// ---- hit flash / death fade — replaces StandardMaterial3D.emission / albedo_color.a -----
// Deliberately zero at rest. The constraint on this shader is no baked-in glow: enemy rim
// lighting is a separate additive overlay (hero_rim.gdshader via _apply_rim_overlay()),
// and an earlier pass turned enemies into glowing blobs by routing identity through
// material emission — this must not repeat that. flash_energy is only ever non-zero for
// the handful of frames enemy.gd's _flash() tween is running.
//
// These three are `instance uniform`s, not plain uniforms, and that is what lets every
// enemy of an archetype SHARE one material. They are the only values on this shader that
// differ between two Wretches standing next to each other; when they lived on the material,
// enemy.gd had to build a fresh ShaderMaterial per enemy just to hold them — a room of
// twenty-four cost twenty-four materials (plus twenty-four rim overlays), none of which
// could batch with each other. Driven through
// GeometryInstance3D.set_instance_shader_parameter(), never through the material.
instance uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
instance uniform float flash_energy : hint_range(0.0, 4.0) = 0.0;

// 1.0 = fully solid, 0.0 = fully gone. Driven by enemy.gd's death fade. Implemented below
// as a dithered discard rather than real alpha blending so a LIVE enemy — the common case,
// every enemy, every frame — stays on the cheap opaque/depth-tested path; only a dying
// enemy, for its ~1s death_linger window, pays the discard cost.
instance uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

// ---- hashing / value noise (mirrors stone_floor.gdshader / wall_stone.gdshader) --------

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

void fragment() {
	vec2 uv = UV;

	// ---- mottled albedo: macro blotches + micro grain, hue-preserving ------------------
	float macro_n = fbm(uv * macro_noise_scale);
	float micro_n = fbm(uv * micro_noise_scale + 19.0);

	// A textured monster starts from its painted skin, a flat archetype from its tint. The
	// mottling then perturbs whichever one it is, identically — it is multiplicative and
	// zero-mean, so it adds surface variation without dragging either source off its value.
	vec3 base = tint_color;
	if (use_albedo_texture) {
		vec3 skin = texture(albedo_texture, uv).rgb * albedo_gain;
		base = mix(skin, skin * tint_color * 2.0, tint_strength);
	}

	vec3 hsv = rgb2hsv(base);
	hsv.z = clamp(hsv.z
		* (1.0 + (macro_n - 0.5) * 2.0 * macro_strength)
		* (1.0 + (micro_n - 0.5) * 2.0 * micro_strength), 0.0, 1.0);
	hsv.x = fract(hsv.x + (fbm(uv * macro_noise_scale + 7.0) - 0.5) * (hue_jitter_deg / 360.0));
	vec3 albedo = hsv2rgb(hsv);

	// ---- roughness variation: the whole body is no longer one specular value -----------
	float rough_n = fbm(uv * roughness_noise_scale + 31.0);
	float rough = clamp(
		roughness_base + (rough_n - 0.5) * 2.0 * roughness_variation,
		roughness_floor, 1.0);

	// ---- crevice AO from the posed normal ------------------------------------------------
	vec3 n = normalize(NORMAL);
	float curvature = length(fwidth(n));
	float crevice = pow(clamp(curvature * crevice_curvature_scale, 0.0, 1.0), crevice_sharpness);
	albedo *= 1.0 - crevice * crevice_strength;
	rough = clamp(rough + crevice * crevice_strength * 0.3, roughness_floor, 1.0);

	// ---- wear: pale scuffing on convex, upward-facing surfaces --------------------------
	if (wear > 0.001) {
		float faces_up = clamp(dot(n, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5, 0.0, 1.0);
		float convex = 1.0 - crevice; // inverse of the same curvature term used for crevice AO
		float scratch = fbm(uv * wear_scale + 41.0);
		float scratch_mask = smoothstep(0.55, 0.85, scratch);
		float wear_mask = clamp(wear * convex * mix(0.4, 1.0, faces_up) * scratch_mask, 0.0, 1.0);
		albedo = mix(albedo, wear_color, wear_mask);
		rough = clamp(rough + wear_mask * 0.25, roughness_floor, 1.0);
	}

	ALBEDO = clamp(albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = rough;
	METALLIC = clamp(metallic, 0.0, 1.0);
	SPECULAR = specular;

	// ---- fine surface relief: same derivative-normal technique as stone_floor -----------
	float bump = (fbm(uv * micro_noise_scale * 1.6) - 0.5) * surface_bump_strength;
	vec2 slope = vec2(dFdx(bump), dFdy(bump)) * relief_strength;
	NORMAL_MAP = vec3(slope * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;

	EMISSION = flash_color * flash_energy;

	if (fade_alpha < 0.999) {
		// Dithered discard instead of real alpha blending — see the fade_alpha uniform
		// comment above for why this matters for the common (fully-alive) case.
		float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (dither > fade_alpha) {
			discard;
		}
	}
}
