shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Attack telegraph — the single most important readability surface in the combat loop
// (GDD §3: "telegraph is visible from the isometric camera... the difference between
// hard and unfair"). Renders a ring/arc outline plus a radial fill-sweep that grows
// with `fill_progress`, so a wind-up visibly "charges" on the ground the same way the
// HUD's cooldown sweep charges — same visual language, different surface.
//
// Apply to a flat quad/plane mesh (e.g. a QuadMesh laid in the XZ plane) whose Node3D
// origin sits at the telegraph's centre on the floor. Additive + unshaded so it stays
// legible over dark stone regardless of local lighting, and never reads as "a light is
// falling on the floor" — it reads as "this specific patch of ground is dangerous".

uniform vec3 outline_color : source_color = vec3(1.0, 0.18, 0.1);
uniform vec3 fill_color : source_color = vec3(1.0, 0.55, 0.2);

uniform float shape_radius : hint_range(0.2, 10.0) = 2.0;
uniform float ring_width : hint_range(0.01, 1.0) = 0.12;

uniform float outline_intensity : hint_range(0.0, 10.0) = 3.0;
uniform float fill_intensity : hint_range(0.0, 10.0) = 5.0;

// 0 = wind-up just started, 1 = the strike is about to land. Drive this from the
// enemy's telegraph timer.
uniform float fill_progress : hint_range(0.0, 1.0) = 0.0;

// 0..360, start == 0 and end == 360 gives a full ring (the common case).
uniform float arc_start_degrees : hint_range(0.0, 360.0) = 0.0;
uniform float arc_end_degrees : hint_range(0.0, 360.0) = 360.0;

uniform float edge_softness : hint_range(0.5, 4.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.15;

// Vertex-normal offset so this decal never z-fights the floor it's resting on. A fixed
// world-Y bump would need re-tuning per room; biasing along the mesh's own normal is
// robust to floor height and to ramps/uneven ground without ever needing a second look.
uniform float y_bias : hint_range(0.0, 0.1) = 0.012;

varying vec2 local_xy;

void vertex() {
	VERTEX += NORMAL * y_bias;
	local_xy = VERTEX.xz;
}

void fragment() {
	float radius = length(local_xy);
	// atan's branch cut sits along local -X; fwidth(angle) spikes to a huge value on
	// that single line because adjacent pixels jump from ~0 to ~360. Clamping the
	// derivative caps that spike to a hard (but correctly positioned, single-pixel)
	// edge instead of a blown-out soft gradient band across a chunk of the shape.
	float angle = degrees(atan(local_xy.y, local_xy.x)) + 180.0; // 0..360
	float aa_angle = min(fwidth(angle), 6.0) * edge_softness;

	float arc_mask = 1.0;
	if (arc_end_degrees < 359.999 || arc_start_degrees > 0.001) {
		float a0 = arc_start_degrees;
		float a1 = arc_end_degrees;
		if (a1 >= a0) {
			arc_mask = smoothstep(a0 - aa_angle, a0 + aa_angle, angle)
					* (1.0 - smoothstep(a1 - aa_angle, a1 + aa_angle, angle));
		} else {
			// Arc wraps through the 0/360 seam (e.g. start = 300, end = 60).
			arc_mask = max(
					smoothstep(a0 - aa_angle, a0 + aa_angle, angle),
					1.0 - smoothstep(a1 - aa_angle, a1 + aa_angle, angle));
		}
	}

	// Outline ring: the constant "danger footprint" the player reads at a glance the
	// instant the telegraph arms, independent of wind-up progress.
	float ring_d = abs(radius - shape_radius) - ring_width * 0.5;
	float ring_aa = fwidth(ring_d) * edge_softness;
	float ring_mask = 1.0 - smoothstep(0.0, ring_aa, ring_d);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
	float outline = ring_mask * arc_mask * pulse;

	// Fill sweep: a radial wipe across the disc, growing with fill_progress. Same
	// technique as a cooldown radial, just projected onto the ground instead of drawn
	// in the HUD, so a slow wind-up visibly fills in before it lands.
	float sweep_angle = fill_progress * 360.0;
	float sweep_mask = 1.0 - smoothstep(sweep_angle - aa_angle, sweep_angle + aa_angle, angle);
	float disc_mask = 1.0 - smoothstep(shape_radius - ring_aa, shape_radius, radius);
	float fill_mask = disc_mask * sweep_mask * arc_mask;

	vec3 color = outline_color * outline + fill_color * fill_mask;
	float energy = outline * outline_intensity + fill_mask * fill_intensity;

	ALBEDO = color;
	EMISSION = color * energy;
	ALPHA = clamp(outline + fill_mask, 0.0, 1.0);
}
