shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Solid tumbling debris — ice splinters, bone chips, gold slivers. Deliberately NOT
// billboarded: the whole point of a shard is that it has an axis, and an axis you can see
// rotate is what tells the eye the impact threw something rather than just flashing. The
// emitter aligns each shard's Y to its velocity (particle_flag_align_y) and spins it about
// that axis, so the silhouette changes as it flies.
//
// Shape comes from a view-dependent edge term rather than a texture: facing faces stay
// translucent and grazing faces blow out toward white, which reads as a hard crystalline
// facet catching the light. On a flat additive box it is the difference between a shard and
// a coloured brick.

uniform vec4 tint : source_color = vec4(0.6, 0.88, 1.0, 1.0);
uniform float tint_weight : hint_range(0.0, 1.0) = 1.0;
uniform float gain : hint_range(0.0, 6.0) = 2.0;
/// How strongly grazing angles blow out to white. Higher = thinner, harder facet edges.
uniform float facet_power : hint_range(0.5, 8.0) = 2.5;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
/// Floor on opacity so a shard viewed dead-on does not disappear entirely.
uniform float body_alpha : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float facet = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), facet_power);
	vec3 hue = mix(vec3(1.0), tint.rgb, tint_weight);
	vec3 hot = mix(hue, vec3(1.0), 0.85);

	ALBEDO = mix(hue, hot, facet) * COLOR.rgb * gain;
	ALPHA = clamp((body_alpha + facet * (1.0 - body_alpha)) * COLOR.a * alpha_mult, 0.0, 1.0);
}
