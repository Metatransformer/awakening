class_name BoltThrower
extends Node3D
## The saved raid authority chooses when and whom this mechanism may shoot.
## This node supplies only the live presentation and the ordinary Hit.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const RETRY_GRACE := 0.12

var _pivot: Node3D
var _weapon: Node3D
var _muzzle: Marker3D
var _recoil_tween: Tween
var _pending_id: StringName = &""
var _retry_left: float = 0.0
var _retry_window: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not Game.raid_active():
		_pending_id = &""
		_retry_left = 0.0
		_retry_window = 0.0
		return

	if _pending_id != &"":
		_retry_left -= delta
		_retry_window -= delta
		if _retry_window <= 0.0:
			_pending_id = &""
			return
		if _retry_left <= 0.0:
			_attempt(_pending_id)
		return

	var target_id: StringName = Game.raid_live_defense_target(delta)
	if target_id == &"":
		return
	_pending_id = target_id
	_retry_window = K.ENEMY_IFRAME_TIME + RETRY_GRACE
	_attempt(target_id)


func _attempt(target_id: StringName) -> void:
	var target := _find_raider(target_id)
	if target == null:
		_retry_left = 0.05
		return
	_aim_at(target.head_point())
	_fire_presentation(target.head_point())
	var hit := Hit.make(
		maxi(target.health.max_quarters, target.health.quarters),
		_muzzle.global_position, &"bolt", K.KNOCKBACK_HEAVY, 0.25,
		&"BOLT-THROWER", 1.0, 1.0)
	if target.health.apply_hit(hit):
		_pending_id = &""
		_retry_left = 0.0
		_retry_window = 0.0
	else:
		# The saved cooldown has already selected this target. Keep that decision
		# through the ordinary enemy iframe instead of inventing another shot clock.
		_retry_left = K.ENEMY_IFRAME_TIME + 0.02


func _find_raider(target_id: StringName) -> RaidRaider:
	for node: Node in get_tree().get_nodes_in_group(&"raid_raider"):
		var raider := node as RaidRaider
		if raider != null and raider.raid_id == target_id \
				and raider.health != null and not raider.health.dead:
			return raider
	return null


func _aim_at(world_target: Vector3) -> void:
	var direction := world_target - _pivot.global_position
	if direction.length() <= 0.001:
		return
	var up := Vector3.FORWARD \
		if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	_pivot.look_at(world_target, up)


func _fire_presentation(world_target: Vector3) -> void:
	Bus.request_sfx.emit(&"crossbow_shoot", _muzzle.global_position)
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_weapon.position = Vector3.ZERO
	_recoil_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_weapon, ^"position:z", 0.28, 0.055)
	_recoil_tween.tween_property(_weapon, ^"position:z", 0.0, 0.16)
	_spawn_tracer(_muzzle.global_position, world_target)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var span := to - from
	if span.length() <= 0.001:
		return
	var tracer := MeshInstance3D.new()
	tracer.name = &"BoltTracer"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.018
	mesh.height = span.length()
	mesh.radial_segments = 6
	tracer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Pal.BONE
	material.emission_enabled = true
	material.emission = Pal.GOLD
	material.emission_energy_multiplier = 3.5
	material.roughness = 0.55
	tracer.material_override = material
	var direction := span.normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	get_tree().current_scene.add_child(tracer)
	tracer.global_transform = Transform3D(
		Basis.looking_at(direction, up) * Basis(Vector3.RIGHT, -PI * 0.5),
		(from + to) * 0.5)
	var tween := tracer.create_tween()
	tween.tween_property(tracer, ^"transparency", 1.0, 0.12)
	tween.tween_callback(tracer.queue_free)


func _build() -> void:
	var base := Node3D.new()
	base.name = &"Carriage"
	add_child(base)
	_box(base, &"Bed", MAT_WOOD, Vector3(1.45, 0.22, 1.75),
		Vector3(0.0, 0.62, 0.0))
	for x: float in [-0.56, 0.56]:
		for z: float in [-0.58, 0.58]:
			var leg := _box(base, &"SplayedLeg", MAT_WOOD,
				Vector3(0.16, 0.82, 0.16), Vector3(x, 0.34, z))
			leg.rotation.z = deg_to_rad(-10.0 * signf(x))
	_box(base, &"IronTurntable", MAT_IRON, Vector3(0.74, 0.12, 0.74),
		Vector3(0.0, 0.79, 0.0))
	_add_signal_lamp(base)

	_pivot = Node3D.new()
	_pivot.name = &"AimPivot"
	_pivot.position = Vector3(0.0, 1.12, 0.0)
	add_child(_pivot)
	_weapon = Node3D.new()
	_weapon.name = &"CrossbowMechanism"
	_pivot.add_child(_weapon)
	_box(_weapon, &"Stock", MAT_WOOD, Vector3(0.24, 0.24, 2.65),
		Vector3(0.0, 0.0, -0.55))
	_box(_weapon, &"IronRail", MAT_IRON, Vector3(0.08, 0.08, 2.25),
		Vector3(0.0, 0.17, -0.72))
	for x: float in [-0.82, 0.82]:
		var arm := _box(_weapon, &"BowArm", MAT_WOOD,
			Vector3(1.45, 0.13, 0.16), Vector3(x * 0.47, 0.03, -1.58))
		arm.rotation.y = deg_to_rad(12.0 * signf(x))
	_box(_weapon, &"BowBinding", MAT_IRON, Vector3(0.26, 0.32, 0.26),
		Vector3(0.0, 0.02, -1.58))
	_box(_weapon, &"String", _flat(Pal.BONE.darkened(0.40)),
		Vector3(1.92, 0.025, 0.025), Vector3(0.0, 0.04, -1.72))

	for x: float in [-0.31, 0.31]:
		var wheel := _cylinder(_weapon, &"CrankWheel", MAT_IRON, 0.30, 0.08,
			Vector3(x, -0.04, 0.23), 12)
		wheel.rotation.z = PI * 0.5
	_box(_weapon, &"CrankHandle", MAT_WOOD, Vector3(0.72, 0.07, 0.07),
		Vector3(0.0, -0.15, 0.23))

	_muzzle = Marker3D.new()
	_muzzle.name = &"Muzzle"
	_muzzle.position = Vector3(0.0, 0.10, -1.92)
	_weapon.add_child(_muzzle)


func _add_signal_lamp(parent: Node3D) -> void:
	# A small readiness lamp keeps the defensive silhouette readable during the
	# nighttime event without turning the mechanism into a second floodlight.
	var material := StandardMaterial3D.new()
	material.albedo_color = Pal.GOLD.darkened(0.35)
	material.emission_enabled = true
	material.emission = Pal.GOLD
	material.emission_energy_multiplier = 4.0
	material.roughness = 0.65
	_box(parent, &"ReadyLamp", material, Vector3(0.18, 0.28, 0.18),
		Vector3(0.62, 1.34, -0.68))
	var light := OmniLight3D.new()
	light.name = &"ReadyGlow"
	light.position = Vector3(0.62, 1.42, -0.68)
	light.light_color = Pal.GOLD
	light.light_energy = 3.5
	light.light_indirect_energy = 0.0
	light.light_volumetric_fog_energy = 0.0
	light.omni_range = 5.5
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	parent.add_child(light)


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, at: Vector3, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
