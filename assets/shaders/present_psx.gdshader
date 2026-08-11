shader_type canvas_item;
render_mode unshaded;

// The present pass for docs/STYLEGUIDE.md §4.5: take the 480x270 internal 3D
// buffer, scale it to the window with SHARP BILINEAR, and quantize to RGB555
// through a 4x4 Bayer cell measured in INTERNAL pixels (§4.4).
//
// One pass does both on purpose. §4.4 demands the dither cell equal one internal
// pixel; the only place where "one internal pixel" is still a knowable quantity
// is here, where `UV * src_size` is exactly that coordinate. Dither in a second
// pass over the upscaled image and each cell covers 2.67 output pixels at 720p,
// which is a grain overlay -- the thing §4.4 spends a paragraph refusing.
//
// The material is built in code by `scripts/ui/screen_present.gd`; nothing
// instances this by hand.

uniform vec2 src_size = vec2(480.0, 270.0);
/// 0 disables the quantizer and leaves a plain sharp-bilinear present. It exists
/// so a director can photograph the upscale and the colour depth apart -- they
/// are two separate claims in §4.4/§4.5 and they fail differently.
uniform bool quantize = true;

// §4.4's table, verbatim. Ordered, never noise: a noise dither reads as film
// grain or TAA, which is the fastest tell that a PSX look is a filter over a
// normal game rather than a pipeline.
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

void fragment() {
	vec2 px = UV * src_size;
	vec2 fl = floor(px) + 0.5;      // the texel centre this fragment sits in
	vec2 d = px - fl;               // -0.5 .. 0.5, distance from it in texels
	vec2 w = max(fwidth(px), vec2(1e-6));  // texels crossed per OUTPUT pixel

	// SHARP BILINEAR. Sit on the texel centre across the whole texel, then ramp
	// to the boundary over exactly one output pixel, and let the LINEAR sampler
	// do the blend. Raw nearest shimmers at 720p's 2.67x (§4.5); plain bilinear
	// is a blur; integer-only pillarboxes.
	//
	// **§4.5's four lines are wrong and this is not them.** As written there --
	//     uv = (fl + clamp(px - fl, -0.5, 0.5) / fwidth(px)) / src_size
	// -- the clamp is applied BEFORE the divide, so it never clamps anything:
	// `px - fl` is already inside +/-0.5 by construction. The divide then scales
	// that to +/-1.33 texels at 720p, which walks the sample past the NEXT
	// texel's centre and blends two neighbours the fragment is not inside. It
	// does not sharpen; it smears, doubled. The clamp has to happen on the
	// already-divided distance -- equivalently, on `d` against a region that
	// shrinks by half an output pixel, which is the form below.
	vec2 r = max(vec2(0.5) - w * 0.5, vec2(0.0));
	vec2 uv = (fl + (d - clamp(d, -r, r)) / w) / src_size;

	vec3 c = texture(TEXTURE, uv).rgb;

	if (quantize) {
		// 15-bit RGB555: 5 bits per channel, 31 steps. The cell index is read off
		// `px` -- INTERNAL pixels -- so one Bayer cell is 4x4 internal pixels no
		// matter what the window is doing.
		ivec2 p = ivec2(mod(floor(px), 4.0));
		float b = (BAYER[p.y * 4 + p.x] / 16.0) - 0.5;
		c = floor(c * 31.0 + b + 0.5) / 31.0;
	}

	COLOR = vec4(c, 1.0);
}
