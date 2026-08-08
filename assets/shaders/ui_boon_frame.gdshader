shader_type canvas_item;
render_mode blend_mix, unshaded;

// The ornament that turns a boon card from a dialog box into an artifact.
//
// The whole card is: a dark slab (theme StyleBox), this frame on top of it, and text
// inside it. Everything that varies per card -- the rarity tier -- varies through
// `accent`, `glow` and `shimmer` only, which is why the slab underneath can live in the
// Theme resource as one style shared by all three cards instead of four hand-tinted ones.
//
// What makes it read as forged rather than drawn: chamfered corners, a double rule with a
// gap between them, corner brackets that thicken where the rules turn, and a finial
// straddling the top edge. That last one is the highest-value detail per pixel -- a shape
// that crosses its own border cannot be a rectangle a layout engine produced.
//
// The shimmer is not decoration. It is the Legendary tell: `shimmer` scales with rarity,
// so a Legendary card is the only one on screen that MOVES, and movement wins the eye
// before colour does.

uniform vec2 panel_size = vec2(272.0, 220.0);
uniform vec4 accent : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform float corner_cut : hint_range(0.0, 40.0) = 16.0;
uniform float rule_width : hint_range(0.5, 6.0) = 1.6;
uniform float inner_inset : hint_range(2.0, 32.0) = 7.0;
uniform float bracket_length : hint_range(0.0, 90.0) = 34.0;
/// Outer bloom. Scales with rarity so Legendary is unmistakable across a dark screen.
uniform float glow : hint_range(0.0, 4.0) = 1.0;
/// Strength of the travelling highlight. 0 for Common, 1 for Legendary.
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer_speed : hint_range(0.0, 2.0) = 0.32;
/// Lifted by the card while hovered/focused, so the frame answers the pointer.
uniform float highlight : hint_range(0.0, 1.0) = 0.0;

float sd_chamfer_box(vec2 p, vec2 half_size, float cut) {
	vec2 d = abs(p) - half_size;
	float box = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	float diag = (abs(p.x) + abs(p.y)) - (half_size.x + half_size.y - cut);
	return max(box, diag);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float line_mask(float d, float aa) {
	return 1.0 - smoothstep(0.0, aa, d);
}

void fragment() {
	vec4 base = COLOR;
	vec2 px = (UV - 0.5) * panel_size;
	vec2 half_size = panel_size * 0.5;
	float aa = 1.0;

	float outer = sd_chamfer_box(px, half_size - vec2(rule_width), corner_cut);
	float inner = sd_chamfer_box(px, half_size - vec2(inner_inset + rule_width), max(corner_cut - inner_inset, 2.0));

	// Corner brackets: the same outer rule, thickened where the two rules turn a corner.
	vec2 corner_zone = abs(px) - (half_size - vec2(bracket_length));
	float in_corner = step(0.0, min(corner_zone.x, corner_zone.y));

	float outer_line = line_mask(abs(outer) - rule_width * (1.0 + in_corner * 0.9), aa);
	float inner_line = line_mask(abs(inner) - rule_width * 0.55, aa);

	// Finials straddling the top and bottom rules. A shape that crosses its own border is
	// the cheapest possible signal that a hand placed it.
	float top_finial = line_mask((abs(px.x) + abs(px.y + half_size.y)) - 10.0, aa);
	float bot_finial = line_mask((abs(px.x) + abs(px.y - half_size.y)) - 6.5, aa);
	float top_dash = line_mask(sd_box(vec2(abs(px.x) - 26.0, px.y + half_size.y), vec2(7.0, 1.4)), aa);

	float frame = clamp(outer_line + inner_line * 0.55 + top_finial + bot_finial + top_dash, 0.0, 1.0);

	// Travelling highlight along the diagonal, riding only the frame lines.
	float band = fract((px.x + px.y) / max(panel_size.x + panel_size.y, 1.0) + 0.5 - TIME * shimmer_speed);
	float sweep = exp(-pow((band - 0.5) * 7.0, 2.0)) * shimmer;

	float intensity = 0.72 + 0.28 * highlight + sweep * 1.4;
	vec3 rgb = mix(accent.rgb, vec3(1.0), clamp(sweep * 0.8 + highlight * 0.25, 0.0, 1.0));

	// Bloom outside the card body.
	float bloom = exp(-max(outer, 0.0) / max(glow * 5.0 + 1.0, 0.001)) * step(0.0, outer);
	float bloom_a = bloom * (0.28 + 0.32 * highlight) * clamp(glow * 0.4, 0.0, 1.2);

	float frame_a = frame * accent.a * intensity;
	float out_a = clamp(frame_a + bloom_a * (1.0 - frame_a), 0.0, 1.0);
	vec3 out_rgb = (rgb * frame_a + accent.rgb * bloom_a * (1.0 - frame_a)) / max(out_a, 0.0001);

	COLOR = vec4(out_rgb * base.rgb, out_a * base.a);
}
