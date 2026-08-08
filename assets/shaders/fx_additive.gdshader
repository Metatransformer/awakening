shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The one material every additive procedural effect in the game renders with.
//
// Vfx used to build a fresh StandardMaterial3D per effect node — a burst alone allocated
// eight of them (one core sphere plus seven sparks), each one a separate RID, a separate
// shader uniform buffer, and therefore a separate draw call that could never batch with
// its neighbours. A busy fight measured 90 fps -> 25 fps almost entirely on that churn.
//
// Colour and fade are `instance uniform`s rather than plain uniforms, which is the whole
// point: per-instance values live in the instance's own data buffer instead of in the
// material, so a hundred effects of a hundred different colours still share ONE material
// and stay batchable. Callers drive them through
// GeometryInstance3D.set_instance_shader_parameter(), never through a material.
//
// Written to ALBEDO, not EMISSION: this shader is `unshaded`, and unshaded mode outputs
// ALBEDO and ignores EMISSION entirely — the same trap hero_rim.gdshader documents.
// fx_energy is what pushes the value above 1.0 so the glow pass has something to bloom.

// rgb = tint, a = current opacity. One vec4 rather than a colour plus a separate alpha
// so a fade costs a single instance-uniform write per frame instead of two.
instance uniform vec4 fx_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Overdrive above 1.0 for the bloom pass. Capped by the caller at Vfx.MAX_EMISSION for
// the same reason the old _emissive() capped it: an effect that clips to flat white has
// stopped communicating its own shape.
instance uniform float fx_energy : hint_range(0.0, 8.0) = 2.0;

// Soft radial falloff across the mesh's UVs, so a quad or a plane reads as a glow rather
// than as a hard-edged card. 0 leaves the surface flat, which is what the crescent
// slash arc and the ground streak want.
instance uniform float fx_falloff : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float mask = 1.0;
	if (fx_falloff > 0.001) {
		// Distance from the UV centre, so the effect fades out toward its own rim.
		float r = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
		mask = mix(1.0, 1.0 - r * r, fx_falloff);
	}
	ALBEDO = fx_color.rgb * fx_energy * mask;
	ALPHA = fx_color.a * mask;
}
