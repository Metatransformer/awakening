shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

// Ground-projected shockwave/nova decal — critic gap #5: "Frost nova... make it a
// ground-projected decal, not a ring mesh. Hard white leading edge... falling to a
// translucent [colour] interior; punch radial crack lines through it with a cheap angular
// Voronoi mask so it reads as fracturing ice rather than a hoop."
//
// Backs Vfx.ring() in scripts/fx/vfx.gd. Apply to a flat mesh lying in the XZ plane (a
// PlaneMesh works well — its default orientation already faces +Y) centred on the node's
// local origin, spanning -1..1 so the shader's own `r` = 1.0 always lands exactly on the
// mesh boundary. Vfx.ring() drives the visible size purely via Node3D.scale (uniform on
// X/Z) rather than any shader uniform, so `edge_width` below is defined in local (0..1)
// units and Vfx.ring() converts its desired *world* edge thickness into that space by
// dividing by the current radius before setting the uniform.
//
// Generic by design, not frost-specific: `ring_color` comes from the caller, and the
// leading edge always blows out toward white regardless of hue, so this reads correctly
// whether it's frost cyan, a fire-orange shockwave, or an enemy telegraph colour.

// The four values that differ from one ring to the next are `instance uniform`s, so every
// ring in the game — five enemy telegraphs, a frost nova and a fireball footprint all
// overlapping — shares ONE ShaderMaterial and stays batchable. A plain uniform would force
// Vfx.ring() back to allocating a material per effect, which is the exact per-effect
// resource churn this pass exists to remove. Driven via
// GeometryInstance3D.set_instance_shader_parameter(), never through the material.
instance uniform vec4 ring_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
instance uniform float edge_width : hint_range(0.01, 0.6) = 0.12;

// Vfx.ring() tweens this 0 -> 1 as the effect pops in, holds it while the ring expands,
// eases it down to a low "residual mark" value once the expansion finishes, then finally
// to 0 to release the node — one value drives pop-in, hold, and the lingering floor mark.
instance uniform float alpha_mult : hint_range(0.0, 1.0) = 0.0;

// Per-instance so two overlapping rings (e.g. two enemies telegraphing at once) don't
// crack in perfect lockstep.
instance uniform float crack_seed : hint_range(0.0, 100.0) = 0.0;

// Constant across every caller, so these stay on the shared material.
uniform float edge_emission : hint_range(0.0, 16.0) = 6.0;
uniform float interior_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float crack_count : hint_range(4.0, 48.0) = 16.0;
uniform float crack_sharpness : hint_range(1.0, 48.0) = 20.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float _hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	// Cheap angular Voronoi: slice the disc into wedges, jitter each wedge's border by a
	// per-wedge hash, and light up a thin band around that jittered border. Reads as
	// jagged fracture lines radiating from the centre rather than a perfect pinwheel.
	float angle = atan(p.y, p.x); // -PI..PI
	float slice = (angle / TAU) * crack_count + crack_seed;
	float cell = floor(slice);
	float f = fract(slice);
	float jitter = _hash(cell) * 0.6 + 0.2;
	float border_dist = abs(f - jitter);
	float crack_line = 1.0 - smoothstep(0.0, 1.0 / crack_sharpness, border_dist);
	// Cracks fade out toward the exact centre (nothing to fracture with zero radius) and
	// don't punch past the leading edge.
	crack_line *= smoothstep(0.0, 0.2, r) * (1.0 - smoothstep(0.85, 1.0, r));

	// Hard white leading edge over a thin band at the rim, translucent colour inside it.
	float band = smoothstep(1.0 - edge_width, 1.0, r) * (1.0 - smoothstep(1.0, 1.0 + edge_width * 0.25, r));
	vec3 hot = mix(ring_color.rgb, vec3(1.0), 0.9);
	vec3 base_color = mix(ring_color.rgb, hot, band);
	base_color = mix(base_color, vec3(1.0), crack_line * 0.85);

	float emission_amt = mix(1.1, edge_emission, band);
	emission_amt = mix(emission_amt, edge_emission * 0.6, crack_line);

	float a = mix(interior_alpha * (1.0 - r * 0.2), 1.0, band);
	a = max(a, crack_line * 0.8);
	a *= alpha_mult;

	ALBEDO = base_color;
	EMISSION = base_color * emission_amt;
	ALPHA = clamp(a, 0.0, 1.0);
}
