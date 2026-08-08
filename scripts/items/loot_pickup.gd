class_name LootPickup
extends Area3D
## An ingredient lying on the dungeon floor.
##
## The important behaviour is what happens when the bag is FULL: the pickup
## refuses to vanish and starts pulsing instead. It must never silently delete
## itself, because "I cannot carry this" is information the player has to act
## on — that moment is the whole point of a limited bag (docs/METAGAME.md §1).

## Seconds before a spawned pickup can be collected. Stops a kill from
## instantly hoovering drops into the bag before the player sees them land.
@export var arm_delay: float = 0.35
@export var spin_speed: float = 2.2
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.6

var item_id: StringName = &""
var count: int = 1

var _mesh: MeshInstance3D
var _light: OmniLight3D
var _base_y: float = 0.0
var _t: float = 0.0
var _armed: bool = false
var _refused: float = 0.0


static func spawn(parent: Node3D, id: StringName, n: int, at: Vector3,
		rng: RandomNumberGenerator = null) -> LootPickup:
	var p := LootPickup.new()
	p.item_id = id
	p.count = n
	parent.add_child(p)
	# Scatter a little so a two-item drop does not stack into one unreadable blob.
	var jitter := Vector3.ZERO
	if rng != null:
		jitter = Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.45, 0.45))
	p.global_position = at + jitter + Vector3.UP * 0.45
	return p


func _ready() -> void:
	add_to_group(&"loot_pickup")
	collision_layer = K.L_INTERACT
	collision_mask = K.L_PLAYER
	monitoring = true

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	col.shape = sphere
	add_child(col)

	var tint := LootDB.color_of(item_id)

	_mesh = MeshInstance3D.new()
	var gem := PrismMesh.new()
	gem.size = Vector3(0.26, 0.34, 0.26)
	_mesh.mesh = gem
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.25
	mat.roughness = 0.28
	# Emissive because the dungeon is genuinely black between torches — an
	# unlit pickup on an unlit floor is simply not findable.
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.6
	_mesh.material_override = mat
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.1
	_light.omni_range = 2.4
	_light.shadow_enabled = false
	add_child(_light)

	_base_y = global_position.y
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(arm_delay).timeout.connect(func() -> void: _armed = true)


func _process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y += spin_speed * delta
	global_position.y = _base_y + sin(_t * bob_speed) * bob_height

	if _refused > 0.0:
		# Bag-full pulse. Red-shifted and fast, so it reads as a refusal rather
		# than as ordinary idle shimmer.
		_refused = maxf(_refused - delta, 0.0)
		_light.light_energy = 1.1 + absf(sin(_t * 14.0)) * 2.4
		_light.light_color = LootDB.color_of(item_id).lerp(Color(1, 0.25, 0.2), 0.6)
	else:
		_light.light_energy = 1.1 + sin(_t * 3.0) * 0.25
		_light.light_color = LootDB.color_of(item_id)

	# Keep trying while the player stands on it, so clearing a slot picks it up
	# without having to step off and back on.
	if _armed and _refused <= 0.0 and has_overlapping_bodies():
		for b in get_overlapping_bodies():
			if b.is_in_group(&"player"):
				_try_collect()
				break


func _on_body_entered(body: Node3D) -> void:
	if _armed and body.is_in_group(&"player"):
		_try_collect()


func _try_collect() -> void:
	var leftover := Game.bag.add(item_id, count)
	if leftover >= count:
		# Nothing fit. Stay on the floor and say so.
		_refused = 0.9
		Bus.loot_overflowed.emit(item_id, count)
		return
	var taken := count - leftover
	Bus.loot_collected.emit(item_id, taken)
	Bus.request_sfx.emit(&"pickup", global_position)
	if leftover > 0:
		# Partial pickup: a stack topped off but the rest did not fit.
		count = leftover
		_refused = 0.9
		Bus.loot_overflowed.emit(item_id, leftover)
		return
	queue_free()
