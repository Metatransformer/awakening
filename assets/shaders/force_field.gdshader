shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Sealed-door energy barrier — the visual promise that "doors seal, clear all enemies,
// doors open" (GDD §1) is actually enforced, not just a gameplay flag the player has no
// way to see. Unshaded + additive because this is pure energy, not a lit surface: it
// should read the same in a dark room as a bright one, and should never occlude or
// darken anything behind it, only add light to it.
//
// Apply to a flat quad or cylinder-section mesh spanning the doorway. cast_shadow must
// be set to OFF on the MeshInstance3D node (not a shader concern) so a see-through
// field doesn't throw a shadow onto the floor.

uniform vec3 field_color : source_color = vec3(0.25, 0.55, 1.0);
uniform vec3 rim_color : source_color = vec3(0.65, 0.9, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;

uniform float hex_scale : hint_range(1.0, 20.0) = 6.0;
uniform float hex_line_width : hint_range(0.0, 0.5) = 0.08;
uniform float scroll_speed : hint_range(0.0, 5.0) = 0.6;

uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.15;

uniform float energy_intensity : hint_range(0.0, 10.0) = 2.5;
uniform float alpha_base : hint_range(0.0, 1.0) = 0.55;

// Soft-particle depth fade: how many world units of overlap with the floor (or any
// surface behind the field) it takes to fully fade the seam.
uniform float depth_fade_distance : hint_range(0.05, 4.0) = 0.6;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	// Hex energy pattern in the field's own local XY plane, scrolling upward over
	// time. Classic axial hex-grid distance: fold space into whichever of two
	// interleaved rectangular lattices is closer — cheap, no trig, matters because
	// this runs on every pixel of what is usually a large additive quad.
	vec2 uv = VERTEX.xy * hex_scale;
	uv.y += TIME * scroll_speed;

	vec2 s = vec2(1.0, 1.7320508);
	vec2 h = s * 0.5;
	vec2 a = mod(uv, s) - h;
	vec2 b = mod(uv - h, s) - h;
	vec2 nearest = (dot(a, a) < dot(b, b)) ? a : b;
	float hex_d = length(nearest);
	float hex_aa = fwidth(hex_d) * 1.5;
	float hex_mask = 1.0 - smoothstep(hex_line_width, hex_line_width + hex_aa, hex_d);

	// Cheap frame-holding flicker (one random value per ~1/flicker_speed seconds
	// rather than a smooth sine) — a shield audibly "humming" reads as barely alive,
	// which is the point: it's a wall the player is meant to want gone.
	float flicker_seed = floor(TIME * flicker_speed);
	float rnd = fract(sin(flicker_seed * 12.9898) * 43758.5453);
	float flicker = 1.0 + (rnd - 0.5) * flicker_strength;

	// Fresnel rim — NORMAL and VIEW are both view-space in the fragment stage, so
	// 1 - NdotV brightens grazing edges without any extra transform.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);

	vec3 color = mix(field_color, rim_color, fresnel);
	float energy = (0.35 + hex_mask * 0.65) * energy_intensity * flicker;

	// Soft-particle depth fade: without this the flat plane cuts a hard, very visible
	// straight line where it meets the floor mesh. Reconstruct the scene's view-space
	// depth at this screen pixel from the depth buffer and compare it against this
	// fragment's own view-space depth; fade to nothing as they converge.
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float pixel_depth = -VERTEX.z;
	float depth_fade = clamp((scene_depth - pixel_depth) / depth_fade_distance, 0.0, 1.0);

	float alpha = alpha_base * (0.3 + fresnel * 0.7 + hex_mask * 0.3) * depth_fade;

	ALBEDO = color;
	EMISSION = color * energy;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
