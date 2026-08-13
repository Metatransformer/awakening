class_name LobTargeter
extends Node3D
## One world-space landing mark shared by the two arcing throws. Prediction is
## stepped from HeroRanged's physics tick; this node owns no input or HUD state.

const MARK_LIFT := 0.035

var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	top_level = true
	_build_marker()
	hide_target()


func hide_target() -> void:
	visible = false


func target_visible() -> bool:
	return visible


func target_position() -> Vector3:
	return global_position


## Reproduce BurstCast's point flight, stand-off, bounce and settle rule. A hit
## is not enough: the marker names the final place the mote will come to rest.
func predict_burst(space: PhysicsDirectSpaceState3D, origin: Vector3,
		velocity: Vector3, exclusions: Array[RID]) -> bool:
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	_query.exclude = exclusions

	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var point := origin
	var last_normal := Vector3.UP
	var steps := ceili(K.BOMB_FUSE / step)
	for _i in steps:
		velocity.y -= K.GRAVITY * K.BURST_GRAVITY_SCALE * step
		_query.from = point
		_query.to = point + velocity * step
		var hit := space.intersect_ray(_query)
		if hit.is_empty():
			point = _query.to
			continue
		last_normal = hit["normal"] as Vector3
		point = (hit["position"] as Vector3) + last_normal * BurstCast.MOTE_R
		velocity = velocity.bounce(last_normal) * BurstCast.BOUNCE
		if velocity.length() < BurstCast.SETTLE_SPEED:
			_show_target(point - last_normal * BurstCast.MOTE_R, last_normal)
			return true
	hide_target()
	return false


## A thrown barrel ends on its first swept collision, so this predictor does
## too. The horizon stops at the live throw fuse: a collision after that would
## preview a landing the real barrel can never reach.
func predict_barrel(space: PhysicsDirectSpaceState3D, centre: Vector3,
		velocity: Vector3, exclusions: Array[RID]) -> bool:
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	_query.exclude = exclusions

	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var steps := ceili(ExplosiveBarrel.THROW_FUSE / step)
	for _i in steps:
		velocity.y -= K.GRAVITY * step
		_query.from = centre
		_query.to = centre + velocity * step
		var hit := space.intersect_ray(_query)
		if not hit.is_empty():
			_show_target(hit["position"] as Vector3, hit["normal"] as Vector3)
			return true
		centre = _query.to
	hide_target()
	return false


func _show_target(point: Vector3, normal: Vector3) -> void:
	if not point.is_finite() or not normal.is_finite() or normal.length_squared() < 0.01:
		hide_target()
		return
	var up := normal.normalized()
	var x := up.cross(Vector3.FORWARD)
	if x.length_squared() < 0.01:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(up).normalized()
	global_transform = Transform3D(Basis(x, up, z), point + up * MARK_LIFT)
	visible = true


func _build_marker() -> void:
	name = &"LobTargeter"
	var material := StandardMaterial3D.new()
	material.albedo_color = Pal.RUST
	material.roughness = 0.72
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = Pal.GOLD
	material.emission_energy_multiplier = 1.15
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A landing promise must survive the carried prop crossing the sightline.
	# The geometry still sits on the real surface; only its depth test is waived.
	material.no_depth_test = true

	var ring := MeshInstance3D.new()
	ring.name = &"LandingRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.29
	torus.outer_radius = 0.36
	torus.rings = 16
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var tick_sizes: Array[Vector3] = [
		Vector3(0.18, 0.025, 0.055), Vector3(0.18, 0.025, 0.055),
		Vector3(0.055, 0.025, 0.18), Vector3(0.055, 0.025, 0.18),
	]
	var tick_positions: Array[Vector3] = [
		Vector3(0.43, 0.0, 0.0), Vector3(-0.43, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.43), Vector3(0.0, 0.0, -0.43),
	]
	for i in tick_sizes.size():
		var tick := MeshInstance3D.new()
		tick.name = StringName("LandingTick%d" % (i + 1))
		var box := BoxMesh.new()
		box.size = tick_sizes[i]
		tick.mesh = box
		tick.position = tick_positions[i]
		tick.material_override = material
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tick)
