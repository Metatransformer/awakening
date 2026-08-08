shader_type canvas_item;
render_mode blend_mix, unshaded;

// A single primitive that covers every circular readout in the HUD: the dodge ring, the
// charge ring, and the cooldown sweep over a spell slot.
//
// One shader instead of three because they are the same drawing with different radii --
// an arc that starts at twelve o'clock and runs clockwise. Setting `inner_radius` to 0
// turns the ring into a filled pie wedge, which is the cooldown sweep; leaving it at
// ~0.6 leaves a ring, which is the gauge. Anything that fills should also *say* it is
// filling, so the leading edge carries a bright head and the arc carries a bloom whose
// strength follows `glow` -- a bar that only changes length is invisible in peripheral
// vision, and both of these live in the corner of the eye while the player watches the
// middle of the screen.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
/// Radii in half-widths: 1.0 touches the edge of the rect, ~1.42 covers its corners.
uniform float inner_radius : hint_range(0.0, 2.0) = 0.62;
uniform float outer_radius : hint_range(0.0, 2.0) = 0.92;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/// Drawn under the fill for the whole ring, so an empty gauge still reads as a socket
/// waiting to be filled rather than as nothing at all.
uniform vec4 track_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform float head_glow : hint_range(0.0, 3.0) = 1.0;
/// Colour of the leading edge, when it must differ from the fill. The cooldown sweep is a
/// near-black veil, so a head taken from `fill_color` would be an invisible black line on
/// a dark tile -- exactly the boundary the player needs to see. Alpha 0 means "use
/// fill_color", so every gauge that wants one hot colour keeps setting only `fill_color`.
uniform vec4 head_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
/// Runs the arc anticlockwise. Used by nothing yet; kept because a "draining" reading is
/// the natural opposite of a "filling" one and costs one branch.
uniform bool reverse = false;
/// Rotates the twelve-o'clock start point, in turns.
uniform float start_turn : hint_range(0.0, 1.0) = 0.0;
/// Thin bright line on the outer edge. Gives the ring a rim so it reads as a carved
/// socket rather than a flat disc of colour.
uniform vec4 rim_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec4 base = COLOR;

	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float aa = fwidth(r) * 1.15 + 0.0015;

	// A pie wedge has no hole; skipping the inner smoothstep avoids the half-covered
	// texel that otherwise sits as a visible dot at dead centre.
	float inner_mask = inner_radius <= 0.0005
		? 1.0
		: smoothstep(inner_radius - aa, inner_radius + aa, r);
	float band = inner_mask * (1.0 - smoothstep(outer_radius - aa, outer_radius + aa, r));

	// 0 at twelve o'clock, increasing clockwise. UV.y grows downward, hence -p.y.
	float ang = fract(atan(p.x, -p.y) / TAU + 1.0 + start_turn);
	if (reverse) {
		ang = 1.0 - ang;
	}

	float swept = 1.0 - smoothstep(progress - 0.0025, progress + 0.0025, ang);
	if (progress >= 0.9995) {
		swept = 1.0;
	}
	if (progress <= 0.0005) {
		swept = 0.0;
	}

	vec4 track = vec4(track_color.rgb, track_color.a * band);
	vec4 fill = vec4(fill_color.rgb, fill_color.a * band * swept);

	float out_a = fill.a + track.a * (1.0 - fill.a);
	vec3 out_rgb = (fill.rgb * fill.a + track.rgb * track.a * (1.0 - fill.a)) / max(out_a, 0.0001);

	// Bloom bleeding off both edges of the swept arc.
	//
	// `edge_dist` is the distance from the band, in half-widths, and is 0 everywhere INSIDE
	// it -- max() of the two signed distances, both of which go negative within the band.
	// Multiplying by (1 - band) then confines the bloom to the outside, which is what makes
	// it a halo. Computing the two falloffs separately and summing them, as this did before,
	// gave exp(0) = 1 across every pixel outside the ring's hole -- so each gauge washed a
	// translucent square of its own fill colour over its whole rect, and a filled disc such
	// as the boon orb had `fill_color * glow` added on top of itself and clipped to white,
	// destroying the one thing the orb exists to say: which boon this is.
	float edge_dist = max(max(inner_radius - r, r - outer_radius), 0.0);
	float halo = exp(-pow(edge_dist * 8.0, 2.0)) * (1.0 - band);
	float bleed = halo * swept * glow * 0.5;

	// Bright head on the leading edge -- the part the eye actually tracks.
	vec3 hot = head_color.a > 0.0 ? head_color.rgb : fill_color.rgb;
	float dang = abs(ang - progress);
	dang = min(dang, 1.0 - dang);
	float head = exp(-pow(dang * 90.0, 2.0)) * band * head_glow;
	if (progress <= 0.0005 || progress >= 0.9995) {
		head = 0.0;
	}

	float rim = (1.0 - smoothstep(outer_radius - aa * 2.0, outer_radius, r))
		* smoothstep(outer_radius - aa * 4.0, outer_radius - aa * 2.0, r);

	out_rgb += fill_color.rgb * bleed + hot * (head * 1.6);
	out_rgb = mix(out_rgb, rim_color.rgb, rim * rim_color.a);
	out_a = clamp(out_a + bleed * 0.75 + head * 0.9 + rim * rim_color.a, 0.0, 1.0);

	COLOR = vec4(out_rgb * base.rgb, out_a * base.a);
}
