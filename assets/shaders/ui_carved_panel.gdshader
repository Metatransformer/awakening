shader_type canvas_item;
render_mode blend_mix, unshaded;

// The furniture the HUD is mounted on: a carved stone slab with a hard near-black keyline,
// a warm parchment-tan emboss lit from the top and dropped into shadow at the bottom, an
// incised groove set in from the border, and enough grain that it does not read as a flat
// rectangle of colour.
//
// This exists because a StyleBoxFlat can do a rounded rect with a border and nothing else,
// and a rounded rect with a border is the single most recognisable "programmer UI" shape
// there is. Two things buy most of the way out: a hard outer keyline (the plate is cut from
// something, and this is the cut) and a two-tone directional bevel (a surface with a light
// hitting it, rather than a fill). It is the same read the 9-patch plates in
// assets/ui/plates carry, drawn live instead of baked, so a plate that has to resize with
// its content still matches the ones that do not.
//
// Corners are barely chamfered rather than rounded: the kit's rule (after Valenfeld, see
// resources/ui/spellblade_theme.tres) is square corners, and 5 px of 45-degree cut reads as
// a dressed edge on a stone block rather than as a radius somebody left at the default.
//
// Sizes are in PIXELS, so the chamfer and the bevel stay put whether the plate is 300 px or
// 700 px wide -- which means `panel_size` has to be pushed in from code on every resize.
// UiCarvedPanel (scripts/ui/carved_panel.gd) owns that, and is the only intended way to use
// this shader.

uniform vec2 panel_size = vec2(320.0, 120.0);
uniform float corner_cut : hint_range(0.0, 48.0) = 5.0;
uniform vec4 base_color : source_color = vec4(0.055, 0.049, 0.043, 0.96);
/// Darkening applied toward the bottom of the slab. Cheap, and it is what stops the fill
/// from looking like a flat colour.
uniform float depth : hint_range(0.0, 1.0) = 0.40;
uniform vec4 bevel_light : source_color = vec4(0.600, 0.520, 0.380, 0.62);
uniform vec4 bevel_dark : source_color = vec4(0.175, 0.152, 0.117, 0.85);
uniform float bevel_width : hint_range(0.0, 8.0) = 4.0;
/// The hard outer rim. Near-black and opaque, drawn over everything else including the
/// corners -- one dark keyline is what separates a carved object from a filled shape.
uniform vec4 keyline_color : source_color = vec4(0.035, 0.028, 0.020, 1.0);
uniform float keyline_width : hint_range(0.0, 4.0) = 1.0;
/// The inlay is the line that says somebody made this on purpose. A dark incised groove
/// rather than a bright rule: gold is heading text in this kit and never chrome, so a gold
/// hairline here would make the plate compete with the words on it.
uniform vec4 inlay_color : source_color = vec4(0.030, 0.024, 0.018, 0.70);
uniform float inlay_inset : hint_range(0.0, 24.0) = 6.0;
uniform float inlay_width : hint_range(0.0, 4.0) = 1.0;
uniform float grain : hint_range(0.0, 0.3) = 0.070;
/// Rim glow outside the slab, used to lift the plate off a busy floor.
uniform vec4 halo_color : source_color = vec4(0.0, 0.0, 0.0, 0.60);
uniform float halo_size : hint_range(0.0, 24.0) = 8.0;

float sd_chamfer_box(vec2 p, vec2 half_size, float cut) {
	vec2 d = abs(p) - half_size;
	float box = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	float diag = (abs(p.x) + abs(p.y)) - (half_size.x + half_size.y - cut);
	return max(box, diag);
}

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base = COLOR;
	vec2 px = (UV - 0.5) * panel_size;
	vec2 half_size = panel_size * 0.5;

	float d = sd_chamfer_box(px, half_size, corner_cut);
	float aa = 1.0;

	float inside = 1.0 - smoothstep(-aa, aa, d);

	// Slab fill: darker at the bottom, so the plate has a direction to it.
	vec3 fill = base_color.rgb * mix(1.0 + depth * 0.35, 1.0 - depth, UV.y);
	fill *= 1.0 + (hash21(floor(px)) - 0.5) * grain * 2.0;

	// Bevel: the band of the slab hugging its own border is the chamfer face, and which face
	// it is depends on WHICH EDGE the pixel is nearest -- top or left catches the key light,
	// bottom or right falls into shadow.
	//
	// It used to pick the tone from UV.y alone, which left the whole left and right edges
	// half-lit and turned the rim into a soft vertical glow. Beside the baked 9-patch plates
	// (assets/ui/plates), which decide by corner distance, that read as a different material
	// on the same HUD -- polished where the slots were chiselled. This is the same decision
	// those make, so both now carve the same way.
	float d_tl = min(px.x + half_size.x, px.y + half_size.y);
	float d_br = min(half_size.x - px.x, half_size.y - px.y);
	float edge_band = smoothstep(-bevel_width, -bevel_width * 0.15, d) * inside;
	vec4 bevel = d_tl <= d_br ? bevel_light : bevel_dark;
	fill = mix(fill, bevel.rgb, edge_band * bevel.a);

	// Inlay: a hairline following the same chamfered outline, set in from the border.
	float inlay_d = abs(d + inlay_inset) - inlay_width;
	float inlay = (1.0 - smoothstep(0.0, aa, inlay_d)) * inside;
	fill = mix(fill, inlay_color.rgb, inlay * inlay_color.a);

	// Keyline last, so it wins at the corners where the two bevel faces meet. Drawn from the
	// outer edge inward rather than as another band around the bevel: the rim of a carved
	// plate is the cut itself, and a cut is the outermost thing there is.
	float key = smoothstep(-keyline_width, 0.0, d) * inside;
	fill = mix(fill, keyline_color.rgb, key * keyline_color.a);

	// Outer halo, drawn beyond the slab so the plate separates from a busy floor.
	float halo = exp(-max(d, 0.0) / max(halo_size, 0.001)) * (1.0 - inside);

	float slab_a = inside * base_color.a;
	float halo_a = halo * halo_color.a;
	float out_a = slab_a + halo_a * (1.0 - slab_a);
	vec3 out_rgb = (fill * slab_a + halo_color.rgb * halo_a * (1.0 - slab_a)) / max(out_a, 0.0001);

	COLOR = vec4(out_rgb * base.rgb, out_a * base.a);
}
