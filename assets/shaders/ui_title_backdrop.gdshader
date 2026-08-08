shader_type canvas_item;
render_mode unshaded;

// Backdrop for the title screen: a dark stone wall with something burning below it.
//
// Drawn rather than painted because the title has to look like the game, and the game's look
// is a compositor pass over a 3D scene that a menu does not have. The parts that survive
// into 2D are the ones this reproduces: a warm low key light, heavy falloff into black at
// the edges, and the coarse dither the PSX conditioning leaves on every gradient. A photo
// or a gradient texture would be smooth, and smooth is the one thing the look is not.
//
// No sampling, no texture, no noise texture — three cheap analytic terms and an ordered
// dither. This runs full-screen behind a menu on the loading frame, so it is deliberately
// something the GPU can do without touching memory.

// Where the fire is, in UV space. Below the frame on purpose: the player should see the
// glow of something they have not reached.
uniform vec2 glow_center = vec2(0.5, 1.16);
uniform vec4 glow_color : source_color = vec4(0.52, 0.23, 0.08, 1.0);
uniform vec4 wall_color : source_color = vec4(0.036, 0.033, 0.032, 1.0);
uniform float glow_radius : hint_range(0.1, 2.0) = 0.60;
uniform float glow_strength : hint_range(0.0, 3.0) = 0.44;

// How hard the edges go to black. The menu sits in the middle, so this is what puts it on a
// stage instead of on a wall.
uniform float vignette : hint_range(0.0, 2.0) = 1.55;

// Amplitude of the slow flicker, and how fast it breathes. Kept well under a tenth: a title
// screen is looked at for thirty seconds and anything that pulses visibly becomes the only
// thing on it.
uniform float flicker : hint_range(0.0, 0.25) = 0.055;
uniform float flicker_speed : hint_range(0.0, 4.0) = 0.9;

// Quantisation steps per channel, matching the PSX conditioning's colour depth. The dither
// below is what stops that banding into stripes across a full-screen gradient.
uniform float levels : hint_range(4.0, 64.0) = 14.0;

// 4x4 ordered Bayer, the same trick the lofi compute pass uses, evaluated rather than
// sampled. Returns a value in [0,1) that varies per screen pixel.
float bayer(vec2 pixel) {
	vec2 cell = mod(floor(pixel), 4.0);
	int index = int(cell.y) * 4 + int(cell.x);
	float table[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0);
	return table[index] / 16.0;
}

void fragment() {
	vec2 uv = UV;

	// Aspect-corrected so the glow is a circle on an ultrawide rather than an ellipse.
	float aspect = max(SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 1e-6), 1e-6);
	vec2 offset = (uv - glow_center) * vec2(aspect, 1.0);

	float distance = length(offset) / glow_radius;
	float glow = exp(-distance * distance * 2.2);

	float breathe = 1.0 + flicker * sin(TIME * flicker_speed)
		+ flicker * 0.4 * sin(TIME * flicker_speed * 2.7 + 1.3);

	vec3 color = wall_color.rgb + glow_color.rgb * glow * glow_strength * breathe;

	// A second, much wider and dimmer lobe so the wall is not uniformly flat above the fire.
	color += glow_color.rgb * exp(-distance * 0.55) * 0.022;

	vec2 centered = (uv - 0.5) * 2.0;
	float falloff = 1.0 - vignette * dot(centered, centered) * 0.35;
	color *= clamp(falloff, 0.0, 1.0);

	// Dither BEFORE quantising, not after: adding noise to an already-banded image only
	// makes the bands noisy, where offsetting the value that gets rounded is what breaks a
	// band into an interleaved pair of the two levels either side of it.
	float threshold = (bayer(FRAGCOORD.xy) - 0.5) / levels;
	color = floor((color + threshold) * levels + 0.5) / levels;

	COLOR = vec4(color, 1.0);
}
