#[compute]
#version 450

// lofi_post.glsl — a PSX/PS2 retro *preview* pass (two-stage), driven by scripts/world/LoFiEffect.gd
// as a CompositorEffect over the HDR colour buffer.
//
//   stage 0: PIXELATE + colour-QUANTISE + ordered DITHER the pristine colour into a scratch image.
//            Each thread reads its NxN block's top-left texel, so a whole block collapses to one
//            colour (the crunchy low-res look) with no read/write race on the colour buffer.
//   stage 1: blend the scratch back over the original by `dial` (0 = untouched, 1 = full retro).
//
// Quantise preserves the >1.0 HDR overflow so bright FX still feed the later glow pass; only the
// visible [0,1] range is posterised. Cheap + approximate ON PURPOSE — a look-test, not the final
// word. Refine here later (affine-warp, per-block sort, tuned palette) without touching the wiring.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform image2D scratch_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float pixel_size;   // block edge in pixels (1 = no pixelation)
	float levels;       // colour steps per channel

	float dither;       // ordered-dither strength (0..1)
	float dial;         // master blend: 0 = off, 1 = full retro
	float stage;        // 0 = pixelate/quantise -> scratch, 1 = blend -> colour
	float _pad;
} params;

// 4x4 Bayer ordered-dither matrix, normalised to [0,1).
const float BAYER[16] = float[16](
	 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	if (params.stage < 0.5) {
		// --- Stage 0: pixelate + quantise + dither into the scratch image. -----------------
		int ps = max(1, int(params.pixel_size));
		ivec2 block = (uv / ps) * ps;               // top-left texel of this pixel's block
		vec3 c = imageLoad(color_image, block).rgb;

		vec3 over = max(c - 1.0, vec3(0.0));        // keep HDR overflow for the later glow pass
		vec3 vis = clamp(c, 0.0, 1.0);
		vec3 g = pow(vis, vec3(1.0 / 2.2));         // perceptual space for an even posterise

		float lv = max(2.0, params.levels);
		float d = (BAYER[(uv.x & 3) + ((uv.y & 3) << 2)] - 0.5) * params.dither / (lv - 1.0);
		g = clamp(g + d, 0.0, 1.0);
		g = round(g * (lv - 1.0)) / (lv - 1.0);     // posterise

		vec3 outc = pow(g, vec3(2.2)) + over;
		imageStore(scratch_image, uv, vec4(outc, 1.0));
		return;
	}

	// --- Stage 1: blend the retro scratch over the pristine colour by `dial`. ---------------
	vec4 orig = imageLoad(color_image, uv);
	vec3 lofi = imageLoad(scratch_image, uv).rgb;
	vec3 outc = mix(orig.rgb, lofi, clamp(params.dial, 0.0, 1.0));
	imageStore(color_image, uv, vec4(outc, orig.a));
}
