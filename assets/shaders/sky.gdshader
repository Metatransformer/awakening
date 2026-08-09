shader_type sky;
render_mode use_debanding;

// Valenfeld night sky.
//
// Replaces ProceduralSkyMaterial so the dome can carry a real starfield, drifting
// nebulae and two phase-lit moons on top of the day/night gradient. Every value that
// changes through the day is a uniform pushed from Main.gd::_update_sky, so the whole
// thing stays driven by the one world clock — this shader owns *look*, not timing.
//
// The sun and moon DISKS are drawn here (a custom sky shader does not auto-draw light
// disks the way ProceduralSkyMaterial did), positioned from the celestial direction
// vectors Main hands us — the same DirectionalLight3D nodes still light the terrain.

// ── gradient (the day/night keyframes) ───────────────────────────────────────
// top_color/horizon_color/ground_color/horizon_curve are pushed per-hour by Main._update_sky
// (the hand-tuned clock palette). The base dome now ALSO blends a Binbun-style day/sunset/night
// palette off the SUN HEIGHT (below) and folds these clock tints back in via `key_tint`, so the
// authored gold/pink dawn+dusk still reads while the transitions stay smooth + geometric.
uniform vec3 top_color : source_color = vec3(0.17, 0.45, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.86, 0.98);
uniform vec3 ground_color : source_color = vec3(0.30, 0.29, 0.27);
uniform float horizon_curve = 0.15;          // small = tight bright band hugging the horizon

// ── Binbun day/sunset/night palette (blended off the sun's elevation) ────────────
// Ported from the Binbun Godot Skies pack (CC0). `blend = sun_dir.y`: +1 sun overhead (day),
// ~0 sun at the horizon (sunrise/sunset), -1 sun set (night). Defaults are seeded from Main's
// tuned SKY_KEYS so noon stays azure and dusk stays gold/rose; EnvironmentBuilder overrides them.
uniform vec3 day_sky : source_color = vec3(0.40, 0.55, 0.80);
uniform vec3 day_horizon : source_color = vec3(0.64, 0.74, 0.85);
uniform vec3 sunset_sky : source_color = vec3(0.44, 0.32, 0.54);     // violet zenith at twilight
uniform vec3 sunset_horizon : source_color = vec3(1.00, 0.55, 0.30); // blazing gold/orange skyline
uniform vec3 night_sky : source_color = vec3(0.02, 0.03, 0.07);
uniform vec3 night_horizon : source_color = vec3(0.05, 0.06, 0.12);
uniform float sunset_exponent = 1.25;        // >1 widens the golden-hour band (sun lingers in sunset colour)
uniform float night_exponent = 3.0;          // how fast night closes in as the sun drops below the horizon
uniform float key_tint : hint_range(0.0, 1.0) = 0.40;   // how strongly the per-hour clock palette tints the dome

// ── night strength: 0 by day, 1 deep night — gates stars + nebulae ───────────
uniform float night : hint_range(0.0, 1.0) = 0.0;

// ── sun ──────────────────────────────────────────────────────────────────────
uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);  // unit vector toward the sun in the sky
uniform vec3 sun_color : source_color = vec3(1.0, 0.98, 0.93);
uniform float sun_energy = 1.0;
uniform float sun_radius = 0.046;             // angular radius (radians) — a soft swollen disk

// ── moons (Masser + Secunda) ─────────────────────────────────────────────────
uniform vec3 moon_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 moon_color : source_color = vec3(0.78, 0.83, 0.96);
uniform float moon_radius = 0.060;
uniform float moon_energy = 0.0;

uniform vec3 moon2_dir = vec3(0.5, 0.5, 0.6);
uniform vec3 moon2_color : source_color = vec3(0.95, 0.82, 0.62);
uniform float moon2_radius = 0.034;
uniform float moon2_energy = 0.0;

// ── the Wanderer: a rogue planet that creeps in over the campaign (Wanderer.gd) ──
// Far away it's drawn as a bright star (a tight glow core, tiny/zero disc); as it nears, the
// disc swells, cools toward a sea-glass blue-green, and self-lights into a quiet, unblinking
// world — deliberately small and understated, never the biggest thing in the sky. All driven
// from Main._update_sky off the world clock — see docs/archive/designs/the-wanderer.md.
uniform vec3 planet_dir = vec3(0.0, -1.0, 0.0);          // unit vector toward it (below horizon = hidden)
uniform vec3 planet_color : source_color = vec3(0.86, 0.89, 1.0);
uniform float planet_radius = 0.0;                        // angular radius of the disc (0 = a pure point/star)
uniform float planet_energy = 0.0;                        // overall visibility (0 = absent)
uniform float planet_glow = 2.4;                          // corona scale — large & soft when far (reads as a star)
uniform float planet_menace : hint_range(0.0, 1.0) = 0.0; // 0 pale star → 1 self-lit, storm-eyed, hot-rimmed

// ── tuning ────────────────────────────────────────────────────────────────────
uniform float star_brightness = 1.0;
uniform float nebula_intensity = 0.55;

// Night weather patterns. WeatherSystem selects bounded, seeded parameter sets per front;
// this master shader only renders those parameters (the generator never authors shader variants).
uniform float aurora_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aurora_seed = 0.0;
uniform float aurora_speed : hint_range(0.005, 0.12) = 0.035;
uniform vec3 aurora_color_a : source_color = vec3(0.38, 0.72, 0.66);
uniform vec3 aurora_color_b : source_color = vec3(0.40, 0.48, 0.82);
uniform float shooting_star_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float shooting_star_seed = 0.0;
uniform float shooting_star_rate : hint_range(0.04, 0.5) = 0.18;

// ── volumetric cloud deck (Binbun parallax technique — replaces the flat cirrus veil) ──────
// Billowing clouds projected onto a high flat deck, sampled from two drifting seamless noise
// layers, with a fake-parallax depth offset so they read 3D rather than painted-on. WeatherSystem
// still pushes cover/colour/offset/flash every frame (the contract is unchanged), so the deck
// follows the weather front (sheer scud when clear → a closed overcast lid in a storm), the
// day/night cycle and the wind. The two noise textures are generated in EnvironmentBuilder.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.12;  // 0 = bare wisps, 1 = thick overcast lid
uniform vec3 cloud_color : source_color = vec3(1.0);      // lit cloud colour (day white → night blue-grey)
uniform vec2 cloud_offset = vec2(0.0);                    // wind drift, accumulated by WeatherSystem
uniform float cloud_flash = 0.0;                          // lightning whiten
uniform sampler2D cloud_noise_a : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_noise_b : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float cloud_tiling = 0.05;            // deck scale — smaller = larger, slower cloud forms
uniform float cloud_depth = 0.35;             // parallax push along the view ray (the 3D feel)
uniform float cloud_shape_exp = 1.6;          // >1 sharpens billows toward harder edges

// ── hashing / value noise ─────────────────────────────────────────────────────
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// 3 octaves (was 5). The sky shader is the heaviest per-pixel cost on screen — fbm is still called
// by nebula() + both moons at NIGHT (the cloud deck now reads cheap seamless TEXTURES, not fbm), so
// a full night sky dominates the GPU. On weaker GPUs a full-sky frame at 5 octaves could blow past
// the driver watchdog → a TDR reset (the "game freezes / torn black frame when you look at the sky"
// report, 2026-06-22). 3 octaves nearly halves the cost; nebula posterizes + thresholds its output
// (floor(...*5)/5, smoothstep) so the lost high-frequency detail is invisible. The summed amplitude
// drops (0.875 vs 0.969 max), which the existing thresholds already tolerate. Don't push back to 5.
float fbm(vec3 p) {
	float a = 0.0;
	float w = 0.5;
	for (int i = 0; i < 3; i++) {
		a += w * vnoise(p);
		p *= 2.02;
		w *= 0.5;
	}
	return a;
}

// One scattered shell of stars. Each grid cell may hold a single jittered star whose
// brightness/tint/twinkle come from the cell hash, so the field is stable frame to
// frame but shimmers. Painterly look (AESTHETIC.md — the PS1 blocky framing is retired):
// each star is a soft round pinprick with a gaussian-ish falloff and a gentle breathing
// twinkle, so the field reads like the concept art's night, not chunky aliased tiles.
vec3 star_layer(vec3 dir, float scale, float thresh, float sz, float t) {
	vec3 p = dir * scale;
	vec3 id = floor(p);
	vec3 rnd = hash33(id);
	if (rnd.z < thresh) {
		return vec3(0.0);
	}
	vec3 f = fract(p) - 0.5;
	vec3 jitter = (hash33(id + 17.1) - 0.5) * 0.7;   // keep the star inside its cell (no edge clip)
	vec3 q = f - jitter;
	// round footprint, smooth falloff to zero — a soft glowing point, no hard rim
	float d = length(q);
	float core = smoothstep(sz, sz * 0.25, d);
	core *= core;                                                  // tighten the bright centre
	float bright = (rnd.z - thresh) / (1.0 - thresh + 1e-3);
	// smooth breathing twinkle
	float twinkle = 0.72 + 0.28 * sin(t * (1.5 + rnd.x * 3.0) + rnd.y * 6.2831);
	vec3 tint = mix(vec3(0.75, 0.83, 1.0), vec3(1.0, 0.90, 0.76), rnd.x);  // continuous warm↔cool spread
	return tint * core * bright * twinkle;
}

// Drifting interstellar clouds, banded along a tilted "galactic" plane so they read as
// a Milky Way arc rather than an even wash. Colour walks indigo → magenta → teal.
vec3 nebula(vec3 dir, float t) {
	vec3 q = dir * 2.2;
	float base = fbm(q + vec3(0.0, 0.0, t * 0.004));
	// `det` was a second 3-octave fbm, but nebula posterizes its output to 5 hard bands below
	// (floor(...*5)/5) — so the fine octaves were thrown away anyway. A single value-noise lookup,
	// scaled by 0.85 to match fbm's amplitude (3-octave max ≈0.875, mean ≈0.44 ≈ vnoise mean 0.5×0.85),
	// gives the same banded wash for a third of the per-pixel noise cost — the dominant night-sky GPU
	// saving. Don't restore the fbm here: the posterize hides the detail, and the smoothstep threshold
	// (0.42) sits right at the mean, so amplitude is matched on purpose to keep coverage identical.
	float det = vnoise(q * 3.1 + base * 1.4) * 0.85;
	// Painterly Milky Way (AESTHETIC.md — the posterized hard-band PS1 wash is retired): a SMOOTH
	// faint wash hugging a narrow galactic arc, in desaturated night hues. The old version — 5 hard
	// floor() bands of saturated indigo/magenta across a wide band — read as flat cartoon blobs
	// filling the dome (user, 2026-07-02); this reads as a distant hazy star-river instead.
	float clouds = smoothstep(0.46, 1.05, base * 0.6 + det * 0.6);
	vec3 band_n = normalize(vec3(0.35, 0.84, 0.40));
	float band = 1.0 - smoothstep(0.0, 0.34, abs(dot(dir, band_n)));   // narrow arc, not half the sky
	clouds *= band * band;                                             // nothing off-arc — no stray blobs
	vec3 indigo = vec3(0.16, 0.15, 0.30);
	vec3 rose = vec3(0.28, 0.18, 0.26);
	vec3 teal = vec3(0.12, 0.20, 0.28);
	vec3 col = mix(indigo, rose, smoothstep(0.30, 0.80, det));
	col = mix(col, teal, smoothstep(0.40, 0.92, base) * 0.6);
	return col * clouds;
}

vec3 aurora(vec3 dir, float t) {
	// A northern curtain: several warped vertical ribbons, softened at the zenith and horizon.
	float north = smoothstep(-0.25, 0.72, -dir.z);
	float height = smoothstep(0.08, 0.34, dir.y) * (1.0 - smoothstep(0.82, 1.0, dir.y));
	float phase = atan(dir.x, -dir.z) * 4.0 + aurora_seed * 0.017;
	float warp = vnoise(vec3(phase * 0.35, dir.y * 4.0, t * aurora_speed)) * 2.0 - 1.0;
	float ribbons = pow(0.5 + 0.5 * sin(phase * 2.1 + warp * 3.2 + t * aurora_speed * 4.0), 5.0);
	float veil = smoothstep(0.28, 0.82, vnoise(vec3(phase * 0.18, dir.y * 2.2, t * aurora_speed + aurora_seed)));
	vec3 tint = mix(aurora_color_a, aurora_color_b, clamp(dir.y + warp * 0.16, 0.0, 1.0));
	return tint * (ribbons * 0.72 + veil * 0.28) * north * height;
}

vec3 shooting_star(vec3 dir, float t) {
	// One cheap analytic streak per time cell. Most cells stay dormant; rate controls frequency.
	float cell = floor(t * shooting_star_rate);
	float active = step(0.76, hash13(vec3(cell, shooting_star_seed, 19.7)));
	float age = fract(t * shooting_star_rate) / max(shooting_star_rate, 0.001); // seconds into this event cell
	float life = smoothstep(0.02, 0.08, age) * (1.0 - smoothstep(0.48, 0.72, age));
	vec3 rnd = hash33(vec3(cell + shooting_star_seed, 7.1, 3.4));
	vec3 origin = normalize(vec3(mix(-0.75, 0.75, rnd.x), mix(0.38, 0.88, rnd.y), mix(-0.9, 0.35, rnd.z)));
	vec3 tangent = normalize(vec3(0.8, -0.34, 0.22));
	vec3 head = normalize(origin + tangent * age * 0.48);
	float along = dot(dir - head, tangent);
	float across = length((dir - head) - tangent * along);
	float tail = smoothstep(-0.18, -0.005, along) * (1.0 - smoothstep(-0.005, 0.018, along));
	float line = exp(-across * 900.0) * tail;
	float core = exp(-length(dir - head) * 420.0);
	return vec3(0.72, 0.84, 1.0) * (line * 1.5 + core * 2.5) * active * life;
}

// A moon as a lit sphere billboarded toward the camera: build the near-hemisphere
// normal across the disk, light it from the sun direction (real phases), and texture
// it with maria + craters. `sdir` is the sun direction so the two moons phase apart.
vec3 render_moon(vec3 dir, vec3 mdir, float radius, vec3 mcol, vec3 sdir) {
	float ang = acos(clamp(dot(dir, mdir), -1.0, 1.0));
	if (ang > radius * 1.9) {
		return vec3(0.0);
	}
	vec3 up = abs(mdir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tx = normalize(cross(up, mdir));
	vec3 ty = cross(mdir, tx);
	vec2 uv = vec2(dot(dir - mdir, tx), dot(dir - mdir, ty)) / radius;
	float r2 = dot(uv, uv);
	vec3 col = vec3(0.0);
	if (r2 < 1.0) {
		float zz = sqrt(1.0 - r2);
		// near-hemisphere outward normal points back toward the viewer (−mdir at centre)
		vec3 n = normalize(tx * uv.x + ty * uv.y - mdir * zz);
		float lit = clamp(dot(n, sdir), 0.0, 1.0);
		lit = lit * lit;                    // sharpen the terminator into a clean crescent
		lit = max(lit, 0.09);               // earthshine keeps the dark limb barely visible
		float maria = fbm(n * 6.0) * 0.5 + 0.55;
		float crater = smoothstep(0.34, 0.40, vnoise(n * 15.0));
		float surf = maria * mix(0.78, 1.0, crater);
		col = mcol * lit * surf * mix(0.7, 1.0, zz);   // limb darkening
	}
	float halo = smoothstep(radius * 1.9, radius, ang) * 0.10;   // soft atmospheric ring
	col += mcol * halo;
	return col;
}

// The sun: a soft-edged disk plus a tight inner glow and a wide warm corona, pushed
// well past 1.0 so the environment bloom blossoms around it into a "pretty" sun.
vec3 render_sun(vec3 dir, vec3 sdir, vec3 scol, float radius) {
	float ang = acos(clamp(dot(dir, sdir), -1.0, 1.0));
	float core = smoothstep(radius, radius * 0.55, ang);
	float inner = exp(-ang * 24.0);
	float corona = exp(-ang * 6.5);
	return scol * (core * 7.0 + inner * 1.7 + corona * 0.35);
}

// The Wanderer. Two parts that cross-fade over the approach: a GLOW (a tight star core + a soft
// corona — when the disc is tiny this is the whole body, a bright star) and a lit DISC that
// swells as `radius` grows. `menace` self-lights the disc (so it glows ominously even on its
// night side), reddens a churning storm eye, and adds a hot rim + atmosphere ring — turning the
// pale star into a sullen, bleeding world. `sdir` is the sun direction (real day-side phase).
vec3 render_planet(vec3 dir, vec3 pdir, float radius, vec3 pcol, vec3 sdir, float glow, float menace) {
	float ang = acos(clamp(dot(dir, pdir), -1.0, 1.0));
	vec3 col = vec3(0.0);

	// glow / corona — when the disc is sub-pixel (far) this alone reads as a bright star.
	float gcore = exp(-ang * 130.0);
	float ghalo = exp(-ang * 18.0);
	col += pcol * (gcore * 2.6 + ghalo * 0.45 * glow);

	// the lit disc — only meaningful once it has grown some angular size
	if (radius > 0.0004 && ang < radius * 1.3) {
		vec3 up = abs(pdir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 tx = normalize(cross(up, pdir));
		vec3 ty = cross(pdir, tx);
		vec2 uv = vec2(dot(dir - pdir, tx), dot(dir - pdir, ty)) / radius;
		float r2 = dot(uv, uv);
		if (r2 < 1.0) {
			float zz = sqrt(1.0 - r2);
			vec3 n = normalize(tx * uv.x + ty * uv.y - pdir * zz);
			float lit = clamp(dot(n, sdir), 0.0, 1.0);
			lit = max(lit, mix(0.18, 0.62, menace));      // self-lit floor grows with menace
			// banded, churning surface; a cool, unblinking "eye" boils in as it nears
			float bands = fbm(n * vec3(2.2, 7.5, 2.2)) * 0.5 + 0.5;
			float storm = smoothstep(0.52, 0.86, vnoise(n * 9.0));
			vec3 surf = pcol * mix(0.7, 1.2, bands);
			surf = mix(surf, vec3(0.15, 0.95, 0.85), storm * menace);
			col = surf * lit * mix(0.82, 1.0, zz);         // limb darkening
			col += pcol * pow(1.0 - zz, 3.0) * menace * 0.6;  // faint glowing rim when close
		}
		// thin atmosphere ring hugging the limb — faint when far, still subdued when near
		float ring = max(smoothstep(radius * 1.3, radius * 1.02, ang) - smoothstep(radius * 1.02, radius * 0.97, ang), 0.0);
		col += pcol * ring * (0.2 + menace * 0.4);
	}
	return col;
}

// One drifting cloud layer: read the seamless noise, then re-map by coverage so a low cover
// keeps only the densest cores (scattered puffs) and a high cover floods the whole field into a
// closed lid. `cloud_shape_exp` hardens the billow edges. Returns a height/density 0..1.
float cloud_layer(sampler2D tex, vec2 uv, float density) {
	float h = texture(tex, uv).r;
	h = clamp((h - (1.0 - density)) / max(density, 0.001), 0.0, 1.0);
	return pow(h, cloud_shape_exp);
}

// Billowing cloud deck (Binbun parallax technique). The view ray is projected onto a flat high
// deck (dir.xz / dir.y), sampled in two drifting noise layers, then each sample point is pushed
// ALONG the ray by its own height and re-sampled — that second offset read is what fakes 3D
// parallax, so the clouds have depth and edges that slide as you turn instead of reading painted-
// on. The two layers multiply (min/×) so only where both agree do you get solid cloud, breaking up
// the noise into believable masses. Cover raises the deck density; the deck fades into the horizon
// haze. Returns coverage 0..1.
float clouds_3d(vec3 dir) {
	if (dir.y < 0.03) {
		return 0.0;
	}
	float density = mix(0.45, 1.30, cloud_cover);          // cover → how much of the sky fills in
	float deck = 1.0 / max(dir.y, 0.04);                   // flat-deck distance (huge near the horizon)
	vec2 base = dir.xz * deck * cloud_tiling;
	vec2 p1 = base + cloud_offset;
	vec2 p2 = base + cloud_offset * 0.5;                   // second layer drifts slower → shearing forms
	float h1 = cloud_layer(cloud_noise_a, p1, density);
	float h2 = cloud_layer(cloud_noise_b, p2, density);
	// parallax: shift the sample points by their sampled height and read again
	p1 += dir.xz * h1 * cloud_depth;
	p2 += dir.xz * h2 * cloud_depth;
	h1 = cloud_layer(cloud_noise_a, p1, density);
	h2 = cloud_layer(cloud_noise_b, p2, density);
	float c = min(h1, h1 * h2);
	c *= smoothstep(0.03, 0.22, dir.y);                    // melt into the horizon haze
	return clamp(c, 0.0, 1.0);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// base gradient (Binbun day/sunset/night palette, blended off the sun's elevation, with the
	// hand-tuned clock palette folded back in via key_tint). `blend` is +1 sun overhead → 0 at the
	// horizon (the golden hour) → -1 sun set. day_amt picks day-vs-sunset; night_amt closes night in.
	float blend = clamp(sun_dir.y, -1.0, 1.0);
	float day_amt = pow(clamp(blend, 0.0, 1.0), sunset_exponent);
	float night_amt = pow(clamp(1.0 + blend, 0.0, 1.0), night_exponent);
	vec3 zen = mix(sunset_sky, day_sky, day_amt);
	zen = mix(night_sky, zen, night_amt);
	vec3 hor = mix(sunset_horizon, day_horizon, day_amt);
	hor = mix(night_horizon, hor, night_amt);
	// fold the per-hour clock tints (Main's SKY_KEYS) back in so the authored dawn/dusk still reads
	hor = mix(hor, horizon_color, key_tint);
	zen = mix(zen, top_color, key_tint * 0.6);

	// tight bright band at the horizon grading up to the zenith colour
	float t = pow(max(up, 0.0), horizon_curve);
	vec3 col = mix(hor, zen, t);
	if (up < 0.0) {
		// Below the horizon: a LUMINOUS aerial continuation, NOT a dark ground disc — so looking DOWN
		// from a sky island (or while levitating/gliding) still sees full atmosphere in every
		// direction, never a hard 180° cut into void. The dome gently deepens toward the nadir but
		// stays bright haze; `ground_color` (the dark earthy tint Main pushes) now only faintly
		// flavours straight-down so the uniform stays meaningful — it no longer paints the whole
		// underside dark. On the overworld this lower half is hidden behind terrain anyway. (2026-06-29)
		float d = clamp(-up, 0.0, 1.0);
		col = mix(hor, mix(hor * 0.70, ground_color, 0.25), d * d);
	}

	// keep stars/nebulae out of the ground and fade them in only as night falls
	float above = smoothstep(-0.04, 0.09, up);
	float nightmask = night * above;
	if (nightmask > 0.001) {
		col += nebula(dir, TIME) * nebula_intensity * nightmask;
		col += aurora(dir, TIME) * aurora_intensity * nightmask;
		col += shooting_star(dir, TIME) * shooting_star_intensity * nightmask;
		vec3 st = vec3(0.0);
		// SUBTLE starfield (2026-06-22, user: "make the night sky more subtle"): the field used to
		// be a wall of fat blocky squares packing the whole dome. Pulled WAY back — much higher
		// per-cell thresholds (far fewer stars) + smaller footprints (sz) so each star is a fine
		// pinprick, not a chunky tile, and the sky reads mostly DARK with scattered points. Keeps the
		// PS1 hard-edged quantized look, just sparse. Don't fatten sz / drop thresh back — that's the
		// "too busy" night the user rejected.
		st += star_layer(dir, 150.0, 0.965, 0.10, TIME);
		st += star_layer(dir, 300.0, 0.978, 0.07, TIME * 1.4);
		st += star_layer(dir, 85.0,  0.945, 0.13, TIME * 0.6) * 1.2;    // the sparse bright ones
		col += st * star_brightness * nightmask;
	}

	// Volumetric cloud deck — over the gradient + stars (so cloud occludes the night sky), but
	// UNDER the sun/moon discs so they punch through. Gilds gold toward a low sun (sunrise/sunset)
	// and whitens on a lightning flash.
	float cc = clouds_3d(dir);
	if (cc > 0.001) {
		// Shade the mass painterly: dense cores darken toward a shadowed base while thin edges stay
		// lit, so a cloud reads as a volume with a bright rim instead of a flat cut-out shape.
		vec3 ccol = cloud_color * mix(1.06, 0.72, smoothstep(0.15, 0.9, cc));
		float sd = max(dot(dir, sun_dir), 0.0);
		ccol += sun_color * pow(sd, 5.0) * 0.7 * clamp(sun_energy, 0.0, 1.0);  // warm gilding near the sun
		ccol += vec3(0.7, 0.8, 1.0) * cloud_flash;                            // lightning lights the deck
		col = mix(col, ccol, smoothstep(0.0, 1.0, cc));                        // soft blend, no hard edge
	}

	// sun disk — fades out as it crosses below the horizon
	float sun_vis = sun_energy * smoothstep(-0.08, 0.06, sun_dir.y);
	if (sun_vis > 0.001) {
		col += render_sun(dir, sun_dir, sun_color, sun_radius) * sun_vis;
	}

	// the two moons, each gated by its own horizon crossing
	if (moon_energy > 0.001) {
		float v = moon_energy * smoothstep(-0.08, 0.05, moon_dir.y);
		col += render_moon(dir, moon_dir, moon_radius, moon_color, sun_dir) * v;
	}
	if (moon2_energy > 0.001) {
		float v = moon2_energy * smoothstep(-0.08, 0.05, moon2_dir.y);
		col += render_moon(dir, moon2_dir, moon2_radius, moon2_color, sun_dir) * v;
	}

	// the Wanderer — visible day AND night (Main blends its energy from the night strength when
	// far up toward always-on when near), fading out as it crosses below the horizon.
	if (planet_energy > 0.001) {
		float pv = planet_energy * smoothstep(-0.06, 0.05, planet_dir.y);
		col += render_planet(dir, planet_dir, planet_radius, planet_color, sun_dir, planet_glow, planet_menace) * pv;
	}

	COLOR = col;
}
