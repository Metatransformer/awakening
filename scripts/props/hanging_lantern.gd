class_name HangingLantern
extends Node3D
## A ceiling lantern, separate from the floor puzzle Lantern. Its direct child
## body preserves Arrow and HeroCombat's one-parent `apply_hit` lookup; severing
## moves that body and the payload together under a deterministic gravity ray.

signal severed
signal impacted(at: Vector3)

const CHAIN_LENGTH := 1.28
const CAGE_H := 0.70
const CAGE_R := 0.31
const IMPACT_STANDOFF := 0.34

var _is_severed := false
var _has_impacted := false
var _velocity := Vector3.ZERO
var _age := 0.0

var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _payload: Node3D
var _chain: Node3D
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_build()
	_query.collision_mask = K.L_WORLD | K.L_INTERACT
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	_query.exclude = [_body.get_rid()]


func has_severed() -> bool:
	return _is_severed


func has_impacted() -> bool:
	return _has_impacted


## Only the bow cuts the link. `arrow_fire` is still an arrow; a sword, Burst,
## blast or generic fire may strike the cage without turning reach into a lie.
func apply_hit(hit: Hit) -> void:
	if hit == null or _is_severed:
		return
	if hit.kind != Hit.ARROW and hit.kind != Hit.ARROW_FIRE:
		return
	_is_severed = true
	_velocity = Vector3.DOWN * 0.35
	_chain.visible = false
	Bus.request_sfx.emit(&"container_break", _body.global_position)
	severed.emit()


func _physics_process(delta: float) -> void:
	_age += delta
	_tick_flame()
	if not _is_severed or _has_impacted:
		return
	_velocity.y -= K.GRAVITY * delta
	var from := _body.global_position
	var to := from + _velocity * delta
	_query.from = from
	_query.to = to
	var found := get_world_3d().direct_space_state.intersect_ray(_query)
	if found.is_empty():
		_move_payload(to)
		_payload.rotation.z += delta * 2.6
		return
	var normal := found["normal"] as Vector3
	var at := found["position"] as Vector3 + normal * IMPACT_STANDOFF
	_move_payload(at)
	_impact(found["collider"] as Node, found["position"] as Vector3)


func _move_payload(world_position: Vector3) -> void:
	_body.global_position = world_position
	_payload.global_position = world_position


func _impact(collider: Node, at: Vector3) -> void:
	if _has_impacted:
		return
	_has_impacted = true
	_velocity = Vector3.ZERO
	Bus.request_sfx.emit(&"weapon_impact_stab_1", at)
	var receiver := _damageable(collider)
	if receiver != null:
		receiver.call(&"apply_hit", Hit.make(K.HEALTH_POINT, at, &"fire", 2.0, 0.0,
			&"FALLING LANTERN"))
	impacted.emit(at)


## The same three questions Arrow asks: the collider, its health child, then the
## prop that directly owns the collider. Hanging lanterns never reach through a
## room to find a victim.
func _damageable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	var parent := node.get_parent()
	if parent != null and parent.has_method(&"apply_hit"):
		return parent
	return null


func _tick_flame() -> void:
	if _flame == null:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 7.1)
	_flame.scale = Vector3.ONE * lerpf(0.90, 1.12, pulse)
	_flame_mat.emission_energy_multiplier = lerpf(2.9, 3.8, pulse)
	_lamp.light_energy = lerpf(2.8, 3.5, pulse)


# --- Construction ------------------------------------------------------------

func _build() -> void:
	var iron := _mat(Color(0.12, 0.14, 0.16), 0.48, 0.78)
	var brass := _glow_mat(Pal.RUST, 0.42)
	var ceiling := _mat(Color(0.23, 0.22, 0.20), 0.98, 0.0)

	# The socket stays at the authored ceiling origin when the chain parts.
	_cyl(self, ceiling, 0.24, 0.10, Vector3(0.0, -0.05, 0.0), 8)
	_box(self, iron, Vector3(0.10, 0.20, 0.10), Vector3(0.0, -0.18, 0.0))

	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)
	for i in 7:
		var y := -0.28 - float(i) * (CHAIN_LENGTH - 0.22) / 6.0
		var link := _box(_chain, iron, Vector3(0.08, 0.18, 0.035),
			Vector3(0.0, y, 0.0), Vector3(0.0, 0.0, PI * 0.25))
		link.rotation.y = PI * 0.5 if i % 2 == 0 else 0.0

	_payload = Node3D.new()
	_payload.name = "Lantern"
	_payload.position = Vector3.DOWN * CHAIN_LENGTH
	add_child(_payload)

	_body = AnimatableBody3D.new()
	_body.name = "Body"
	_body.position = _payload.position
	_body.collision_layer = K.L_WORLD | K.L_INTERACT
	_body.collision_mask = 0
	add_child(_body)
	_shape = CollisionShape3D.new()
	var body_shape := CylinderShape3D.new()
	body_shape.radius = CAGE_R
	body_shape.height = CAGE_H
	_shape.shape = body_shape
	_body.add_child(_shape)

	_cyl(_payload, iron, CAGE_R * 1.14, 0.07,
		Vector3(0.0, -CAGE_H * 0.5, 0.0), 8)
	_cyl(_payload, iron, CAGE_R * 1.14, 0.07,
		Vector3(0.0, CAGE_H * 0.5, 0.0), 8)
	for i in 6:
		var a := TAU * float(i) / 6.0
		_box(_payload, brass, Vector3(0.045, CAGE_H, 0.045),
			Vector3(cos(a) * CAGE_R, 0.0, sin(a) * CAGE_R),
			Vector3(0.0, -a, 0.0))
	# A broken link falls with the payload, making the sever visible in a still.
	_box(_payload, iron, Vector3(0.08, 0.25, 0.04),
		Vector3(0.0, CAGE_H * 0.5 + 0.14, 0.0), Vector3(0.0, 0.0, 0.45))

	_flame_mat = _glow_mat(Pal.GOLD, 3.2)
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.14
	flame_mesh.height = 0.34
	flame_mesh.radial_segments = 7
	flame_mesh.rings = 4
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = flame_mesh
	_flame.material_override = _flame_mat
	_payload.add_child(_flame)

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.GOLD
	_lamp.light_energy = 3.1
	_lamp.omni_range = 5.8
	_lamp.omni_attenuation = 1.5
	_lamp.shadow_enabled = false
	_payload.add_child(_lamp)


func _mat(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	if is_zero_approx(metallic):
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _glow_mat(hue: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(hue.darkened(0.80), 0.84, 0.0)
	material.emission_enabled = true
	material.emission = hue
	material.emission_energy_multiplier = energy
	return material


func _box(parent: Node, material: Material, size: Vector3, at: Vector3,
		rotation_euler: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	mesh_instance.rotation = rotation_euler
	parent.add_child(mesh_instance)
	return mesh_instance


func _cyl(parent: Node, material: Material, radius: float, height: float,
		at: Vector3, segments: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance
