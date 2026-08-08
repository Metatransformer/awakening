shader_type canvas_item;
render_mode blend_mix, unshaded;

// The icon in a spell slot, drawn as a signed-distance field instead of imported art.
//
// There is no icon art in this project, and four letters ("E F N M") is not a silhouette
// -- at isometric-HUD size the eye cannot tell one glyph from another without reading it,
// which is exactly what a spell bar must not require mid-fight. So the sigil encodes the
// SLOT ROLE, not the spell: every school answers the same four questions in the same
// order (GDD 2.3), so a dart always means "cheap and fast" and a starburst always means
// "the special", whichever school is equipped. Colour then carries which school it is.
//
// Four shapes, chosen to be distinguishable by outline alone at 40 px:
//   0 SHORT   two stacked chevrons -- fast, repeatable
//   1 HEAVY   a downward spike with a crossguard -- one committed blow
//   2 AREA    concentric rings -- something expanding outward from you
//   3 SPECIAL a four-point starburst -- an event

uniform int sigil : hint_range(0, 3) = 0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/// Drops to ~0.35 when the spell is unaffordable or cooling, so "I cannot use this" is a
/// brightness change the player reads pre-attentively rather than a number they parse.
uniform float energy : hint_range(0.0, 2.0) = 1.0;
/// Extra bloom on the selected slot.
uniform float pulse : hint_range(0.0, 2.0) = 0.0;
uniform float scale : hint_range(0.4, 1.6) = 1.0;

float sd_segment(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - w;
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sd_ring(vec2 p, float rad, float w) {
	return abs(length(p) - rad) - w;
}

float chevron(vec2 p, float y, float w) {
	float a = sd_segment(p, vec2(-0.62, y + 0.30), vec2(0.0, y - 0.16), w);
	float b = sd_segment(p, vec2(0.62, y + 0.30), vec2(0.0, y - 0.16), w);
	return min(a, b);
}

void fragment() {
	vec4 base = COLOR;
	vec2 p = (UV - 0.5) * 2.0 / max(scale, 0.0001);

	float d = 1.0;
	if (sigil == 0) {
		d = min(chevron(p, -0.34, 0.085), chevron(p, 0.22, 0.085));
	} else if (sigil == 1) {
		// Elongated diamond blade plus a crossguard bar.
		float blade = (abs(p.x) * 1.75 + abs(p.y) * 0.80) - 0.66;
		float guard = sd_box(p - vec2(0.0, -0.22), vec2(0.60, 0.075));
		d = min(blade, guard);
	} else if (sigil == 2) {
		d = min(sd_ring(p, 0.74, 0.075), sd_ring(p, 0.38, 0.075));
		d = min(d, length(p) - 0.10);
	} else {
		float a = atan(p.y, p.x);
		float star = length(p) - (0.24 + 0.68 * pow(abs(cos(a * 2.0)), 2.2));
		d = min(star, length(p) - 0.17);
	}

	float aa = fwidth(d) * 1.1 + 0.004;
	float body = 1.0 - smoothstep(-aa, aa, d);
	float halo = exp(-max(d, 0.0) * 6.0);

	// Hot core, tinted edges: the same trick the VFX use so magic reads as emissive
	// against dark stone rather than as a flat coloured shape.
	vec3 core = mix(tint.rgb, vec3(1.0), 0.55);
	vec3 rgb = mix(tint.rgb, core, body);
	float alpha = clamp(body + halo * (0.30 + pulse * 0.45), 0.0, 1.0);

	rgb *= (0.45 + 0.55 * energy) * (1.0 + pulse * 0.5);
	alpha *= clamp(0.35 + 0.65 * energy, 0.0, 1.0);

	COLOR = vec4(rgb * base.rgb, alpha * tint.a * base.a);
}
