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
## Magnetism waits out `drop`'s 0.42 s fling tween. Both write global_position,
## and the tween wins, so a mote that started pulling early would visibly stall
## for the overlap and then jerk.
const MAGNET_ARM := 0.45

var item_id: StringName = &""
## What the chain was worth at the instant this came off the corpse. It COOLS on
## the floor over K.HEAT_COOL_TIME back to 1.0, which is the rule that makes
## sweeping-while-fighting the mastery move: the loot goes cold whether or not
## you do, so backing off to be safe is paid for in the only currency the game
## has. See Heat.
var heat_mult: float = 1.0

var _def: ItemDef
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _age: float = 0.0
var _refused: float = 0.0
var _taken: bool = false
## Cached for the magnet. Re-fetched whenever it goes invalid, which it does on
## every scene change -- a mote outlives nothing, but the lookup is per-frame
## per-mote and a dungeon floor can hold a lot of them.
var _hero: Node3D = null


## Drop one at `at`, with a short arc so it reads as having come off the corpse.
static func drop(parent: Node, id: StringName, at: Vector3,
		fling: Vector3 = Vector3.ZERO) -> LootMote:
	var m := LootMote.new()
	m.item_id = id
	# Stamped at the drop, not read at the pickup. The chain that earned this is
	# the chain that was live when the thing died.
	m.heat_mult = Heat.multiplier()
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

	# Hot loot spins faster and burns brighter, and both fade as it cools. The
	# TINT is untouched on purpose: tint is what the thing IS (rarity, and the
	# glow radius the styleguide hangs on it), and recolouring a Bone Shard gold
	# because you were on a streak would make the HUD's one honest "look over
	# here" tell you the wrong thing. Heat changes the ENERGY, not the hue.
	var hot := heat()
	var bob := sin(_age * BOB_SPEED * hot) * BOB_HEIGHT
	_mesh.position.y = 0.28 + bob
	_mesh.rotation.y += SPIN_SPEED * hot * delta
	_light.position.y = 0.3 + bob

	if _refused > 0.0:
		# Full bag. Pulse toward RUST rather than vanish -- the mote is still
		# there, and the player needs to know it is still there.
		_refused = maxf(0.0, _refused - delta)
		var p := 0.5 + 0.5 * sin(_age * 14.0)
		_mat.emission = Pal.RUST.lerp(_def.tint if _def != null else Pal.BONE, 1.0 - p)
		_mat.emission_energy_multiplier = 0.9 + p * 2.0
		return

	if hot > 1.0:
		_mat.emission_energy_multiplier = 0.9 + (hot - 1.0) * 1.6
		_light.light_energy = 1.1 + (hot - 1.0) * 1.4

	if _age < ARM_TIME:
		return
	_magnetise(delta)
	for b in get_overlapping_bodies():
		if b.is_in_group(&"player"):
			_try_take()
			return


## What this is worth right now: the heat it was killed at, decaying to base over
## K.HEAT_COOL_TIME. Also drives the glow, so "that one is still hot" is a thing
## you can see across a room rather than a number you have to remember.
func heat() -> float:
	if heat_mult <= 1.0:
		return 1.0
	var t: float = clampf(_age / K.HEAT_COOL_TIME, 0.0, 1.0)
	return lerpf(heat_mult, 1.0, t)


## Drag toward the hero while the chain is lit. This is the change that makes a
## chain survivable: without it the loop is kill, halt, hoover, and the window is
## gone before you have picked up what you earned. The pull is a POSITION nudge,
## not a force -- the mote is an Area3D with no body, and the existing overlap
## test then takes it exactly as if you had walked over it.
func _magnetise(delta: float) -> void:
	var reach := Heat.magnet_range()
	if reach <= 0.0 or _age < MAGNET_ARM:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"player") as Node3D
		if _hero == null:
			return
	var to := _hero.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > reach or d < 0.01:
		return
	global_position += to / d * K.HEAT_MAGNET_SPEED * delta


func _try_take() -> void:
	if Run.collect(item_id, 1, heat()) > 0:
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
