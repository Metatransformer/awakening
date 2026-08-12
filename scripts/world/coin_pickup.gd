class_name CoinPickup
extends Area3D
## Money on the floor. Walk over it and it goes straight into `Game.gold`.
##
## **It is not a LootMote.** A mote occupies the Run bag, carries heat and can
## be lost before extraction. A coin is already money: it never enters the bag,
## never pays an extraction fee and never touches the legacy `Game.rupees`.
##
## It shares the pickup language already established by `LootMote.drop` and
## `ArrowBundle.drop`: a short thrown arc, an arm delay, a bob and spin while it
## waits, then the existing pickup cue/message and a rise-and-fade on collection.

## A small ambient-pot payout. Rich enough to notice, far below even one useful
## bag line, and callers can author a different value through `drop`. [tune]
const DEFAULT_AMOUNT := 5
const ARM_TIME := 0.35
const BOB_SPEED := 2.2
const BOB_HEIGHT := 0.07
const SPIN_SPEED := 2.4

@export var amount: int = DEFAULT_AMOUNT

var _rig: Node3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _age: float = 0.0
var _taken: bool = false


## Drop one at `at`, optionally flung along `fling` on the same visible arc as
## the other physical rewards.
static func drop(parent: Node, at: Vector3, amount: int = DEFAULT_AMOUNT,
		fling: Vector3 = Vector3.ZERO) -> CoinPickup:
	var coin := CoinPickup.new()
	coin.name = "CoinPickup"
	coin.amount = maxi(amount, 1)
	parent.add_child(coin)
	coin.global_position = at
	if fling != Vector3.ZERO:
		var land: Vector3 = at + fling
		var tween: Tween = coin.create_tween()
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(coin):
				coin.global_position = at.lerp(land, t) \
					+ Vector3.UP * sin(t * PI) * 0.55,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
	return coin


func _ready() -> void:
	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	collision.shape = sphere
	add_child(collision)

	_build()


func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.position.y = 0.22
	add_child(_rig)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Pal.GOLD
	_mat.emission_enabled = true
	_mat.emission = Pal.GOLD
	_mat.emission_energy_multiplier = 0.22
	_mat.metallic = 0.65
	_mat.roughness = 0.38
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mesh = MeshInstance3D.new()
	_mesh.name = "Coin"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.035
	disc.radial_segments = 10
	disc.rings = 1
	_mesh.mesh = disc
	_mesh.material_override = _mat
	# CylinderMesh stands on Y. Turn its thin edge upright so rotation around Y
	# alternates face and edge, the silhouette that says "spinning coin".
	_mesh.rotation.x = PI * 0.5
	_rig.add_child(_mesh)


func _process(delta: float) -> void:
	_age += delta
	if _taken:
		return

	_rig.position.y = 0.22 + sin(_age * BOB_SPEED) * BOB_HEIGHT
	_rig.rotation.y += SPIN_SPEED * delta

	if _age < ARM_TIME:
		return
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			_take()
			return


func _take() -> void:
	_taken = true
	Game.add_gold(amount)
	Bus.request_sfx.emit(&"pickup", global_position)
	Bus.request_message.emit("Gold  +%d" % amount)
	_pop()


## Rise and fade so the physical coin visibly becomes the purse update.
func _pop() -> void:
	monitoring = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rig, "position:y", _rig.position.y + 0.8, 0.26) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "scale", Vector3.ONE * 0.65, 0.26) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(_mat, "albedo_color:a", 0.0, 0.26)
	tween.chain().tween_callback(queue_free)
