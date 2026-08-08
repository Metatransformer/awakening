shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

// Rim light applied as a material OVERLAY on the player, so the character always carries
// a bright edge regardless of what is behind him.
//
// On a fixed isometric camera the player cannot pan the view to recover a lost character,
// so silhouette separation has to be guaranteed by the shading rather than by luck of
// background. A critic pass found the Paladin sitting at almost exactly the floor's
// luminance and disappearing behind pillars; this is the fix that does not depend on the
// scene's lighting cooperating.
//
// Overlay rather than a replaced material: it composites additively on top of whatever
// the imported character material is, so swapping in a different character model keeps
// the effect for free.

// Key-side rim: warm, strong. This is the one that does the separating.
uniform vec3 warm_color : source_color = vec3(1.0, 0.88, 0.66);
uniform float warm_intensity : hint_range(0.0, 4.0) = 1.25;

// Opposite-side rim: cool, subtle. Two-tone edges read as sculpted rather than glowing.
uniform vec3 cool_color : source_color = vec3(0.56, 0.71, 1.0);
uniform float cool_intensity : hint_range(0.0, 4.0) = 0.5;

// Higher power = tighter edge. Below ~2 the whole model glows and looks like a ghost.
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;

// Flat fill across the whole model, on top of the rim.
//
// This exists because readability cannot be left to the scene lighting. Measured on the
// real frame, the player rendered at luma 22 against a floor at 40 - the protagonist was
// the darkest thing on screen. A culled key light did not reach the skinned mesh reliably,
// so brightness moves here, where it is a number this shader controls directly and which
// affects nothing except the character carrying this overlay.
uniform vec3 fill_color : source_color = vec3(1.0, 0.95, 0.88);
uniform float fill_strength : hint_range(0.0, 2.0) = 0.0;

// World-space direction the warm rim comes from, matching the scene's key light.
uniform vec3 warm_direction = vec3(-0.5, 0.35, -0.8);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Fresnel: brightest where the surface turns away from the viewer, i.e. the silhouette.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);

	// Split the rim by which side of the character it falls on so the two tints do not
	// muddy into one colour across the whole edge.
	float key_side = clamp(dot(world_normal, normalize(warm_direction)) * 0.5 + 0.5, 0.0, 1.0);

	vec3 tint = warm_color * warm_intensity * key_side
		+ cool_color * cool_intensity * (1.0 - key_side);

	// Written to ALBEDO, not EMISSION. This shader is `unshaded`, and in unshaded mode
	// Godot outputs ALBEDO and ignores EMISSION completely — everything this shader
	// computed was being discarded, which is why raising fill_strength from 0.3 to 1.2
	// moved the measured player luminance by 0.7 of a level.
	ALBEDO = tint * rim + fill_color * fill_strength;
	// The fill must contribute to alpha or an additive-blended overlay shows nothing where
	// the rim term is zero, which is most of the model.
	ALPHA = clamp(rim + fill_strength, 0.0, 1.0);
}
