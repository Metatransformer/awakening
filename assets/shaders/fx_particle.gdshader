shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Material for FxPool's MultiMesh particle fields — impact sparks, healing motes, and the
// fireball's trail.
//
// These used to be individual MeshInstance3D nodes: a single burst spawned seven shards,
// each allocating its own BoxMesh, its own StandardMaterial3D and its own Tween, then
// freeing all three a third of a second later. Every one of them was also its own draw
// call. Routed through a MultiMesh instead, any number of live particles is ONE draw call
// with zero per-particle allocation — FxPool integrates them on the CPU in a flat loop.
//
// Per-particle tint and fade arrive as the MultiMesh instance colour, which reaches a
// spatial shader as the COLOR varying. That is why this is a separate shader from
// fx_additive.gdshader: instance uniforms address a GeometryInstance3D, and every particle
// in a field shares one of those, so per-particle values have to travel as instance colour
// instead.

uniform float fx_energy : hint_range(0.0, 8.0) = 3.0;

// Billboard the quad toward the camera. Motes and trail puffs are flat cards, and a card
// that keeps its world orientation turns edge-on and vanishes as the isometric camera
// swings. The shard field leaves this at 0 — a spark's whole job is to point along the
// direction it was thrown.
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		// Standard camera-facing basis, with the instance's own scale re-applied
		// afterwards so the MultiMesh transform's size still counts.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * fx_energy;
	ALPHA = COLOR.a;
}
