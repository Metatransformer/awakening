class_name ExplosiveBarrel
extends Node3D
## A reusable powder barrel: one authored collision body, one warning fuse and
## one blast. Every weapon reaches it through `apply_hit`, the same duck-typed
## seam used by Urn and the puzzle atoms; the blast sends a `Hit` back through
## that same seam instead of inventing a second damage component.

signal fuse_started(duration: float)
signal exploded(at: Vector3)

enum State { IDLE, CARRIED, THROWN, FUSING, SPENT }

## A direct blow leaves enough time to read the rising flame and move. Fire and
## nearby explosions are already consequences in motion, so their fuse is
## shorter, but still long enough to show two distinct warning beats.
const DIRECT_FUSE := 1.35
const CHAIN_FUSE := 0.62
const THROW_FUSE := 1.05
const AFTERGLOW := 0.82
## The same blast measurements Burst already teaches the player. A barrel is a
## new source for that sentence, not a second radius/damage balance table.
const BLAST_RADIUS := K.BOMB_RADIUS
const BLAST_DAMAGE := K.BOMB_DAMAGE
const BLAST_KNOCKBACK := K.BURST_KNOCKBACK

const BODY_H := 1.08
const BODY_R := 0.42
const FUSE_MARKS: Array[float] = [0.28, 0.55, 0.78, 0.93]

var _state := State.IDLE
var _carrier: Node3D
var _velocity := Vector3.ZERO
var _fuse_left := 0.0
var _fuse_total := 0.0
var _warning_step := 0
var _age := 0.0
var _afterglow := 0.0
var _explosion_count := 0
var _last_impact := Vector3.INF

var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _whole: Node3D
var _fuse_flame: MeshInstance3D
var _fuse_light: OmniLight3D
var _fuse_glow: StandardMaterial3D
var _blast: Node3D
var _blast_core: MeshInstance3D
var _blast_ring: MeshInstance3D
var _interactable: Interactable

var _flight_query := PhysicsRayQueryParameters3D.new()
var _blast_query := PhysicsShapeQueryParameters3D.new()
var _flight_exclusions: Array[RID] = []


func _ready() -> void:
	add_to_group(&"explosive_barrel")
	_build()
	_flight_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	_flight_query.collide_with_bodies = true
	_flight_query.collide_with_areas = true
	_reset_flight_exclusions()


## True only while a carry interaction may claim this barrel. A lit fuse is not
## quietly cancellable by picking it up.
func is_available() -> bool:
	return _state == State.IDLE


func is_fusing() -> bool:
	return _fuse_left > 0.0 and _state != State.SPENT


func has_exploded() -> bool:
	return _state == State.SPENT


func explosion_count() -> int:
	return _explosion_count


func is_carried_by(carrier: Node3D) -> bool:
	return _state == State.CARRIED and _carrier == carrier


func flight_centre() -> Vector3:
	return global_position + Vector3.UP * (BODY_H * 0.5)


func flight_exclusions() -> Array[RID]:
	var copy: Array[RID] = []
	copy.assign(_flight_exclusions)
	return copy


## The swept contact that ended the latest throw. This is the landing point a
## lob preview names; the barrel's Node3D origin is offset from it by its shape.
func last_impact_position() -> Vector3:
	return _last_impact


## WP2's whole carry contract. The prop follows one carrier but never reparents,
## so its world transform and ownership stay predictable for rooms and queries.
func begin_carry(carrier: Node3D) -> bool:
	if not is_available() or carrier == null or not is_instance_valid(carrier):
		return false
	_carrier = carrier
	_state = State.CARRIED
	# Keep the authored body hittable while it is in somebody's hands, but drop
	# its WORLD layer so it cannot become a moving wall against its carrier.
	_shape.set_deferred(&"disabled", false)
	_body.set_deferred(&"collision_layer", K.L_INTERACT)
	_set_interaction(false)
	_reset_flight_exclusions(carrier)
	return true


## Return a claim that never became a throw. The carrier identity prevents a
## stale owner from cancelling a barrel another actor has since claimed.
func cancel_carry(carrier: Node3D) -> bool:
	if _state != State.CARRIED or _carrier != carrier:
		return false
	_return_to_idle()
	return true


## Release from `origin` with a world-space velocity. Flight is raycast one
## physics segment at a time, as Arrow and BurstCast are, so a fast throw cannot
## tunnel through a stair lip or another prop.
func throw_from(origin: Vector3, velocity: Vector3) -> bool:
	if _state != State.CARRIED or velocity.length_squared() < 0.01:
		return false
	global_position = origin
	_velocity = velocity
	_last_impact = Vector3.INF
	_carrier = null
	_state = State.THROWN
	_shape.set_deferred(&"disabled", false)
	_body.set_deferred(&"collision_layer", K.L_WORLD | K.L_INTERACT)
	_start_fuse(THROW_FUSE)
	return true


## The shared sword / arrow / Burst resolution entry point.
func apply_hit(hit: Hit) -> void:
	if hit == null or _state == State.SPENT:
		return
	var reactive := hit.kind == &"bomb" or hit.kind == &"fire" \
		or hit.kind == Hit.ARROW_FIRE
	if _fuse_left > 0.0:
		if reactive:
			_shorten_fuse(CHAIN_FUSE)
		return
	_start_fuse(CHAIN_FUSE if reactive else DIRECT_FUSE)


func _physics_process(delta: float) -> void:
	_age += delta
	if _state == State.SPENT:
		_tick_afterglow(delta)
		return
	if _state == State.CARRIED:
		_follow_carrier()
		return
	if _state == State.THROWN:
		_fly(delta)
		if _state == State.SPENT:
			return
	if _fuse_left <= 0.0:
		return
	_fuse_left = maxf(0.0, _fuse_left - delta)
	_tick_fuse_telegraph()
	if _fuse_left <= 0.0:
		_explode()


func _follow_carrier() -> void:
	if _carrier == null or not is_instance_valid(_carrier):
		_return_to_idle()
		return
	var forward := -_carrier.global_transform.basis.z.normalized()
	global_position = _carrier.global_position + Vector3.UP * 1.08 + forward * 0.62


func _start_fuse(seconds: float) -> void:
	if _state == State.SPENT:
		return
	# A throw remains a throw until it lands; its fuse still burns in parallel.
	if _state != State.THROWN:
		if _state == State.CARRIED:
			_carrier = null
			_shape.set_deferred(&"disabled", false)
			_body.set_deferred(&"collision_layer", K.L_WORLD | K.L_INTERACT)
		_state = State.FUSING
	_set_interaction(false)
	_fuse_total = maxf(seconds, 0.05)
	_fuse_left = _fuse_total
	_warning_step = 0
	_fuse_flame.visible = true
	_fuse_light.visible = true
	Bus.request_sfx.emit(&"attack_prepare", global_position + Vector3.UP * BODY_H)
	fuse_started.emit(_fuse_total)


func _shorten_fuse(seconds: float) -> void:
	if _fuse_left <= 0.0 or _fuse_left <= seconds:
		return
	_fuse_left = seconds
	_fuse_total = seconds
	_warning_step = 1
	Bus.request_sfx.emit(&"attack_prepare", global_position + Vector3.UP * BODY_H)


func _tick_fuse_telegraph() -> void:
	var progress := 1.0 - _fuse_left / maxf(_fuse_total, 0.01)
	var beat_rate := lerpf(4.0, 15.0, progress)
	var pulse := 0.5 + 0.5 * sin(_age * beat_rate)
	_fuse_flame.scale = Vector3.ONE * lerpf(0.72, 1.65, progress) * lerpf(0.82, 1.12, pulse)
	_fuse_glow.emission_energy_multiplier = lerpf(1.8, 5.8, progress)
	_fuse_light.light_energy = lerpf(1.2, 5.5, progress) * lerpf(0.72, 1.0, pulse)
	while _warning_step < FUSE_MARKS.size():
		var mark: float = FUSE_MARKS[_warning_step]
		if progress < mark:
			break
		_warning_step += 1
		Bus.request_sfx.emit(&"attack_prepare", global_position + Vector3.UP * BODY_H)


func _fly(delta: float) -> void:
	_velocity.y -= K.GRAVITY * delta
	var centre := global_position + Vector3.UP * (BODY_H * 0.5)
	var next_centre := centre + _velocity * delta
	_flight_query.from = centre
	_flight_query.to = next_centre
	var found := get_world_3d().direct_space_state.intersect_ray(_flight_query)
	if found.is_empty():
		global_position += _velocity * delta
		rotation.y += delta * 4.5
		return

	_last_impact = found["position"] as Vector3
	var normal := found["normal"] as Vector3
	var support := BODY_H * 0.5 if absf(normal.y) > 0.55 else BODY_R
	global_position = _last_impact + normal * support \
		- Vector3.UP * (BODY_H * 0.5)
	_explode()


## Idempotent by state, before any signal or query. A chain can find the same
## barrel through more than one collider and still gets exactly one blast.
func _explode() -> void:
	if _state == State.SPENT:
		return
	_state = State.SPENT
	_explosion_count += 1
	_velocity = Vector3.ZERO
	_shape.set_deferred(&"disabled", true)
	_whole.visible = false
	_fuse_light.visible = false
	var at := global_position + Vector3.UP * (BODY_H * 0.48)
	_build_blast(at)
	_damage_overlaps(at)
	Bus.request_sfx.emit(&"jump_slam", at)
	Bus.request_shake.emit(K.SHAKE_CRIT, 0.26)
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	exploded.emit(at)


func _damage_overlaps(at: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = BLAST_RADIUS
	_blast_query.shape = sphere
	_blast_query.transform = Transform3D(Basis.IDENTITY, at)
	_blast_query.collision_mask = K.L_PLAYER | K.L_ENEMY | K.L_INTERACT
	_blast_query.collide_with_bodies = true
	_blast_query.collide_with_areas = true

	var seen: Dictionary = {}
	for row in get_world_3d().direct_space_state.intersect_shape(_blast_query, 64):
		var receiver := _damage_receiver(row.get("collider") as Node)
		if receiver == null or receiver == self:
			continue
		var id := receiver.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var hit := Hit.make(BLAST_DAMAGE, at, &"bomb", BLAST_KNOCKBACK, 0.18,
			&"EXPLOSIVE BARREL")
		if receiver.has_method(&"take_hit"):
			receiver.call(&"take_hit", hit)
		else:
			receiver.call(&"apply_hit", hit)


## Arrow/hero-combat's resolution ladder, extended only by the hero's existing
## `take_hit` contract. One parent level is deliberate: the room is not a victim.
func _damage_receiver(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"take_hit") or node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	var parent := node.get_parent()
	if parent != null and (parent.has_method(&"take_hit") \
			or parent.has_method(&"apply_hit")):
		return parent
	return null


func _tick_afterglow(delta: float) -> void:
	_afterglow += delta
	if _blast != null:
		var t := clampf(_afterglow / AFTERGLOW, 0.0, 1.0)
		# The blast has to reach gameplay size inside the first readable beat. A
		# slow swell photographed as a coin-sized spark after the barrel vanished,
		# which made the payoff look smaller than the warning that earned it.
		_blast_core.scale = Vector3.ONE * lerpf(0.50, 3.6, minf(t / 0.18, 1.0))
		_blast_core.visible = t < 0.55
		_blast_ring.scale = Vector3.ONE * lerpf(0.50, 3.2, minf(t / 0.35, 1.0))
		_blast_ring.visible = t < 0.78
	if _afterglow >= AFTERGLOW:
		queue_free()


func _on_pickup(by: Node3D) -> void:
	var hero := by as Hero
	if hero == null or hero.ranged == null:
		return
	hero.ranged.take_barrel(self)


func _on_interactable_ready() -> void:
	# Prompt overlap comes from this Area's PLAYER mask. Keeping it off every
	# query layer prevents an interaction radius from becoming a huge hitbox.
	_interactable.collision_layer = 0


func _set_interaction(active: bool) -> void:
	if _interactable != null:
		_interactable.enabled = active


func _reset_flight_exclusions(carrier: Node3D = null) -> void:
	_flight_exclusions.clear()
	if _body != null:
		_flight_exclusions.append(_body.get_rid())
	if _interactable != null:
		_flight_exclusions.append(_interactable.get_rid())
	var collision_carrier := carrier as CollisionObject3D
	if collision_carrier != null:
		_flight_exclusions.append(collision_carrier.get_rid())
	_flight_query.exclude = _flight_exclusions


func _return_to_idle() -> void:
	_carrier = null
	_velocity = Vector3.ZERO
	_state = State.IDLE
	_shape.set_deferred(&"disabled", false)
	_body.set_deferred(&"collision_layer", K.L_WORLD | K.L_INTERACT)
	_reset_flight_exclusions()
	_set_interaction(true)


# --- Construction ------------------------------------------------------------

func _build() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "Body"
	_body.collision_layer = K.L_WORLD | K.L_INTERACT
	_body.collision_mask = 0
	add_child(_body)
	_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = BODY_R
	cylinder.height = BODY_H
	_shape.shape = cylinder
	_shape.position.y = BODY_H * 0.5
	_body.add_child(_shape)

	_interactable = Interactable.new()
	_interactable.name = &"Pickup"
	_interactable.prompt = "PICK UP BARREL"
	_interactable.radius = 1.65
	_interactable.activated.connect(_on_pickup)
	# The Area scans the player for Prompt, but is not itself a weapon/flight
	# target. The barrel's authored Body remains on L_INTERACT for those hits.
	_interactable.ready.connect(_on_interactable_ready, CONNECT_ONE_SHOT)
	add_child(_interactable)

	_whole = Node3D.new()
	_whole.name = "Barrel"
	add_child(_whole)
	var timber := _mat(Color(0.35, 0.20, 0.10), 0.96, 0.0)
	var timber_light := _mat(Color(0.49, 0.29, 0.14), 0.96, 0.0)
	var iron := _mat(Color(0.15, 0.16, 0.17), 0.48, 0.72)
	var tar := _mat(Pal.VOID, 1.0, 0.0)
	var danger := _mat(Pal.RUST, 0.90, 0.0)

	# Alternating faceted staves leave dark seams at gameplay distance. The two
	# iron hoops are geometry rather than painted bands, matching Urn's stacked
	# courses and the kit's hard-edged silhouette language.
	for i in 10:
		var a := TAU * float(i) / 10.0
		var stave_mat := timber_light if i % 2 == 0 else timber
		_box(_whole, stave_mat, Vector3(0.10, BODY_H * 0.92, 0.24),
			Vector3(cos(a) * BODY_R * 0.86, BODY_H * 0.50,
				sin(a) * BODY_R * 0.86), Vector3(0.0, -a, 0.0))
	_cyl(_whole, timber, BODY_R * 0.98, 0.10, Vector3(0.0, 0.05, 0.0), 10)
	_cyl(_whole, timber, BODY_R * 0.98, 0.10, Vector3(0.0, BODY_H - 0.05, 0.0), 10)
	for y: float in [0.23, BODY_H - 0.23]:
		_cyl(_whole, iron, BODY_R * 1.035, 0.075, Vector3(0.0, y, 0.0), 10)
	_cyl(_whole, tar, 0.08, 0.035, Vector3(0.0, BODY_H + 0.02, 0.0), 8)
	_box(_whole, iron, Vector3(0.035, 0.36, 0.035),
		Vector3(0.0, BODY_H + 0.19, 0.0), Vector3(0.0, 0.0, -0.18))
	# The crossed RUST mark names danger while the fuse is still cold. It is
	# raised geometry so it survives the same distant torchlight as Urn's courses.
	for tilt: float in [-0.62, 0.62]:
		_box(_whole, danger, Vector3(0.055, 0.43, 0.025),
			Vector3(0.0, BODY_H * 0.53, -BODY_R * 0.93),
			Vector3(0.0, 0.0, tilt))

	_fuse_glow = _glow_mat(Pal.RUST, 2.0)
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.10
	flame_mesh.height = 0.24
	flame_mesh.radial_segments = 7
	flame_mesh.rings = 4
	_fuse_flame = MeshInstance3D.new()
	_fuse_flame.name = "FuseFlame"
	_fuse_flame.mesh = flame_mesh
	_fuse_flame.material_override = _fuse_glow
	_fuse_flame.position = Vector3(0.055, BODY_H + 0.40, 0.0)
	_fuse_flame.visible = false
	_whole.add_child(_fuse_flame)

	_fuse_light = OmniLight3D.new()
	_fuse_light.name = "FuseLight"
	_fuse_light.light_color = Pal.RUST
	_fuse_light.light_energy = 1.2
	_fuse_light.omni_range = 4.8
	_fuse_light.shadow_enabled = false
	_fuse_light.position = _fuse_flame.position
	_fuse_light.visible = false
	add_child(_fuse_light)


func _build_blast(at: Vector3) -> void:
	_blast = Node3D.new()
	_blast.name = "Explosion"
	add_child(_blast)
	_blast.top_level = true
	_blast.global_position = at
	var hot := _glow_mat(Color(1.0, 0.72, 0.22), 7.0)
	var rust := _glow_mat(Pal.RUST, 4.0)
	_blast_core = _sphere(_blast, hot, 0.42, Vector3.ZERO)
	_blast_core.scale = Vector3.ONE * 0.25
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.82
	ring_mesh.bottom_radius = 0.82
	ring_mesh.height = 0.07
	ring_mesh.radial_segments = 12
	_blast_ring = MeshInstance3D.new()
	_blast_ring.mesh = ring_mesh
	_blast_ring.material_override = rust
	_blast_ring.position.y = 0.05
	_blast_ring.scale = Vector3.ONE * 0.35
	_blast.add_child(_blast_ring)
	var light := OmniLight3D.new()
	light.light_color = Pal.RUST
	light.light_energy = 9.0
	light.omni_range = BLAST_RADIUS * 2.6
	light.shadow_enabled = false
	_blast.add_child(light)
	for i in 9:
		var a := TAU * float(i) / 9.0
		var ember := _box(_blast, rust, Vector3(0.07, 0.07, 0.07), Vector3.ZERO)
		var landing := Vector3(cos(a) * 1.8, -0.25, sin(a) * 1.8)
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(ember):
				ember.position = landing * t + Vector3.UP * sin(t * PI) * 1.25,
			0.0, 1.0, 0.48)


func _mat(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	if is_zero_approx(metallic):
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _glow_mat(hue: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(hue.darkened(0.78), 0.84, 0.0)
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


func _sphere(parent: Node, material: Material, radius: float,
		at: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance
