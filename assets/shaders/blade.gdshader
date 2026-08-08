shader_type spatial;
render_mode cull_back;

// Polished metal for procedural weapon heads (see scripts/fx/weapon_builder.gd).
//
// A blind review called out that a flat grey box would look worse than no weapon at
// all — that is a material problem, not a mesh problem. Real PBR (high metallic, low
// roughness) already gives correct specular response to whatever lights are in the
// room, but the room's own key light is a DirectionalLight3D at energy 0.3
// (scenes/world/lighting_rig.tscn) — real, but easy to miss entirely on a small prop
// at isometric distance. This shader adds a second, sharper glint term keyed to that
// SAME light's actual direction (measured, not guessed — see below) so the weapon is
// guaranteed to visibly catch it, the same "readability cannot be left to scene
// lighting alone" reasoning as hero_rim.gdshader's flat fill on the player himself.

uniform vec3 albedo_tint : source_color = vec3(0.62, 0.65, 0.70);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.92;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.16;

// Glint: a tight specular-like highlight, independent of the engine's own PBR specular,
// so it survives even if the room's key light energy is tuned down further later.
uniform float glint_power : hint_range(1.0, 64.0) = 24.0;
uniform float glint_strength : hint_range(0.0, 4.0) = 1.6;
uniform vec3 glint_color : source_color = vec3(1.0, 0.92, 0.78);

// World-space direction FROM a lit surface TOWARD scenes/world/lighting_rig.tscn's Key
// DirectionalLight3D (rotation_degrees = (-55, -35, 0)). Computed with
// tools/inspect_light_dir.gd (Basis.from_euler(rotation) . z, since a DirectionalLight3D
// shines along its local -Z) rather than eyeballed, so this shader's highlight actually
// answers to the room's real key light instead of an angle that happens to look plausible.
uniform vec3 key_light_direction = vec3(-0.329, 0.819, 0.470);

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	// MODEL_MATRIX transform of object-space NORMAL/VERTEX into world space — the same
	// pattern hero_rim.gdshader already uses successfully in this project.
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo_tint;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;

	// Built entirely in world space (CAMERA_POSITION_WORLD, world_normal, world_pos) on
	// purpose: the fragment-shader built-ins VIEW/NORMAL are in VIEW space in Godot's
	// spatial shaders, and mixing those with a world-space key_light_direction would
	// silently compute the wrong angle instead of failing loudly.
	vec3 world_view = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 reflected = reflect(-world_view, normalize(world_normal));
	float glint = pow(clamp(dot(reflected, normalize(key_light_direction)), 0.0, 1.0), glint_power);
	EMISSION = glint_color * glint * glint_strength;
}
