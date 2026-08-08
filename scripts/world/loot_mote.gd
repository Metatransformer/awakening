class_name LootMote
extends Area3D
## One dropped ingredient, lying on the floor waiting to be walked over.
##
## Why a physical pickup rather than crediting the bag the instant an enemy dies:
## the bag is the thing the player is deciding about, and a number that changes
## while you are still swinging teaches nothing. Making you walk back over the
## drop puts a beat between "I won the fight" and "I am richer", which is the
## beat the extraction decision lives in. It also gives a full bag somewhere to
## refuse from -- a mote you cannot pick up stays on the floor and pulses, which
## is a far better "you are full" than a toast.

## Seconds before the mote will answer a pickup. Long enough that the kill's own
## knockback does not sweep the hero through it before he has seen it land.
const ARM_TIME := 0.35
const BOB_SPEED := 2.2
const BOB_HEIGHT := 0.09
const SPIN_SPEED := 1.6

var item_id: StringName = &""

var _def: ItemDef
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _age: float = 0.0
var _refused: float = 0.0
var _taken: bool = false


## Drop one at `at`, with a short arc so it reads as having come off the corpse.
static func drop(parent: Node, id: StringName, at: Vector3,
		fling: Vector3 = Vector3.ZERO) -> LootMote:
	var m := LootMote.new()
	m.item_id = id
	parent.add_child(m)
	m.global_position = at
	if fling != Vector3.ZERO:
		var land := at + fling
		var tw := m.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(m):
				m.global_position = at.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.55,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
	return m


func _ready() -> void:
	_def = ItemDb.get_def(item_id)
	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.75
	cs.shape = sp
	add_child(cs)

	_build()


func _build() -> void:
	var tint: Color = _def.tint if _def != null else Color(0.8, 0.8, 0.8)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint
	_mat.emission_enabled = true
	_mat.emission = tint
	# 1.6 blew every pale drop out to flat white under the FILMIC curve, so the
	# one thing a mote has to tell you -- what it is -- was the thing it lost.
	# The OmniLight below does the "look here"; the surface does the colour.
	_mat.emission_energy_multiplier = 0.9
	_mat.roughness = 0.85
	# Faceted, never smooth: the whole kit is hard-edged and a smooth-shaded
	# pickup reads as an asset from a different game.
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_mesh = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.26, 0.34, 0.26)
	_mesh.mesh = pm
	_mesh.material_override = _mat
	_mesh.position.y = 0.28
	add_child(_mesh)

	# A very short-range light so a drop in an unlit corner is still findable.
	# Rarer drops carry further, which is the only "look over here" the game does.
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.1
	_light.omni_range = 1.4 + (0.6 * float(_def.rarity) if _def != null else 0.0)
	_light.omni_attenuation = 1.8
	_light.shadow_enabled = false
	_light.position.y = 0.3
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	if _taken:
		return

	var bob := sin(_age * BOB_SPEED) * BOB_HEIGHT
	_mesh.position.y = 0.28 + bob
	_mesh.rotation.y += SPIN_SPEED * delta
	_light.position.y = 0.3 + bob

	if _refused > 0.0:
		# Full bag. Pulse toward RUST rather than vanish -- the mote is still
		# there, and the player needs to know it is still there.
		_refused = maxf(0.0, _refused - delta)
		var p := 0.5 + 0.5 * sin(_age * 14.0)
		_mat.emission = Pal.RUST.lerp(_def.tint if _def != null else Pal.BONE, 1.0 - p)
		_mat.emission_energy_multiplier = 0.9 + p * 2.0
		return

	if _age < ARM_TIME:
		return
	for b in get_overlapping_bodies():
		if b.is_in_group(&"player"):
			_try_take()
			return


func _try_take() -> void:
	if Run.collect(item_id, 1) > 0:
		_taken = true
		_pop()
	else:
		_refused = 0.9


## Rise and fade. Cheap, but it is the only confirmation the player gets that the
## thing on the floor became the number in the corner.
func _pop() -> void:
	monitoring = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mesh, "position:y", _mesh.position.y + 0.9, 0.26) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_mesh, "scale", Vector3.ONE * 0.1, 0.26).set_ease(Tween.EASE_IN)
	tw.tween_property(_light, "light_energy", 0.0, 0.26)
	tw.chain().tween_callback(queue_free)
