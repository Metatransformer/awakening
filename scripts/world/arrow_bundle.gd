class_name ArrowBundle
extends Area3D
## A tied bundle of arrows on the floor. Walk over it and they go in the quiver.
##
## **It is not a LootMote and it must not become one.** A mote goes in the BAG,
## which means it takes a slot, carries heat, is worth gold, and dies with the
## run. Arrows are none of those things: they live on `Game`, they survive death,
## they cost no slot, and nobody ever sold one. Routing them through the bag
## would put ammunition on the extraction fee -- you would pay a quarter of your
## arrows' worth to carry them home -- and it would make a full bag refuse the
## one pickup that a player with an empty quiver most needs.
##
## So this shares the mote's *language* and none of its plumbing: the same
## walk-over with no button (docs/CONTRACT.md -- there is no pick-up button), the
## same short arm delay, the same bob, the same rise-and-fade on take, and the
## same refuse-in-place pulse when it cannot be taken. What differs is what a
## refusal MEANS. A mote is refused by a full bag and that is a decision you made;
## a bundle is refused by a full quiver, which is not a problem -- it is a bundle
## you should come back for, so it stays lit and stays put.
##
## No magnetism. Heat pulls loot to you because sweeping a chain is a skill the
## window is too short for; arrows are supply, they are not on a clock, and a
## quiver that hoovers itself across the room would make the bundle's PLACEMENT
## meaningless. Placement is the whole point -- see `Dungeon._place_supply`.

## How many arrows a floor bundle carries. Two batches of fletching, or a fifth
## of a full quiver: enough to get the bow back into a fight, not enough to make
## the smith's line or the recipe pointless. [tune]
const FLOOR_COUNT := 6
## What a chest coughs up. Richer than the floor because a chest is a detour you
## chose and the floor is a thing you walked past. [tune]
const CHEST_COUNT := 10

const ARM_TIME := 0.35
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.06
## How many shafts are actually modelled. Three reads as "a bundle" from across
## the room; the COUNT is on the pickup message, not in the geometry, because
## ten arrows drawn as ten arrows is a bird's nest at this scale.
const SHAFTS := 3

## Where the "look here" light hangs, and how hard. ABOVE the shafts, not inside
## them: an omni sitting at the tie is a light source the camera stares straight
## into, and it saturates the arrowheads it is supposed to be showing you — the
## first two passes lost the heads in a white flare and only the fletching read.
## Up here it pools on the floor and rakes the shafts from above, which is the
## job. `_build` and `_process` both read this, because they used to hold two
## different numbers for the same lamp.
const LIGHT_Y := 0.52
const LIGHT_ENERGY := 0.55
const LIGHT_RANGE := 1.6

## Arrows granted on pickup.
@export var count: int = FLOOR_COUNT
## Is this bundle the one the floor plan is advertising?
##
## True for the bundle `Dungeon._populate` lies in a room, which is the one that
## got an `Atlas` marker. False for one a chest spat out (`drop`), which never
## had a marker of its own -- and if it cleared one on pickup it would erase the
## floor bundle still lying six metres away in the same room, and the map would
## be telling the player they had already swept a room they had not.
var mapped: bool = true

var _rig: Node3D
var _light: OmniLight3D
var _age: float = 0.0
var _refused: float = 0.0
var _taken: bool = false


## Drop one at `at`, optionally flung along `fling` the way a chest fans its
## contents. Mirrors `LootMote.drop` so a caller that already knows how to spill
## loot does not have to learn a second shape.
static func drop(parent: Node, at: Vector3, n: int = FLOOR_COUNT,
		fling: Vector3 = Vector3.ZERO) -> ArrowBundle:
	var b := ArrowBundle.new()
	b.name = "ArrowBundle"
	b.count = maxi(n, 1)
	b.mapped = false
	parent.add_child(b)
	b.global_position = at
	if fling != Vector3.ZERO:
		var land := at + fling
		var tw := b.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(b):
				b.global_position = at.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.55,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
	return b


func _ready() -> void:
	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.8
	cs.shape = sp
	add_child(cs)

	_build()


func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.position.y = 0.16
	add_child(_rig)

	# Real arrows, not a proxy prism. This is the one pickup in the game whose
	# identity cannot be carried by a tint -- "gold means rare" says nothing about
	# ammunition -- so it has to be carried by the silhouette, and the silhouette
	# has to be the same object that leaves the bow.
	for i in SHAFTS:
		var shaft := WeaponModels.make(Arrow.MODEL_ID)
		if shaft == null:
			break
		shaft.name = "Shaft%d" % i
		# Flat, fanned, and all pointing the same way. `Arrow.MODEL_PITCH` is the
		# quarter turn that lays this model along the -Z it flies down, so a
		# bundle is three of those splayed about Y from the tie — which is what a
		# bundle of arrows looks like and, more usefully, is the SAME silhouette
		# the player sees leave the bow.
		#
		# Three upright shafts was the first version and it was one shaft: rotating
		# a vertical arrow about Y spins it in place, so the fan collapsed and the
		# pickup read as a single spear stuck in the floor.
		shaft.rotation.x = Arrow.MODEL_PITCH
		# Ten degrees, not twenty. A bundle is arrows held together; twenty splayed
		# the heads 45 cm apart on a 70 cm shaft and the pickup read as a starburst
		# — three arrows thrown down, not three arrows tied.
		shaft.rotate_y(deg_to_rad(-10.0 + 10.0 * float(i)))
		# Stacked a few millimetres apart so the three do not z-fight where they
		# cross under the cord. Millimetres: at 2 cm they floated as separate
		# objects at the size this is actually seen from.
		shaft.position = Vector3(0.0, 0.013 * float(i), 0.10)
		_rig.add_child(shaft)

	# The cord. Three loose shafts read as litter; one band across them reads as
	# something a person tied, which is the difference between "dropped" and
	# "stashed".
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.21, 0.13, 0.08)
	cord_mat.roughness = 1.0
	cord_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var cord := MeshInstance3D.new()
	cord.name = "Cord"
	var cm := CylinderMesh.new()
	# A band, not a barrel. Three shafts stacked are about 1.5 cm through, so the
	# tie is 5 cm across and 4 cm tall; the first pass was 10 cm across and read as
	# a keg the arrows had been stuck into.
	cm.top_radius = 0.026
	cm.bottom_radius = 0.026
	cm.height = 0.042
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = cord_mat
	cord.mesh = cm
	# Banded ACROSS the shafts, which now lie along -Z: the cylinder's own axis is
	# +Y, so it stays upright and the shafts pass through it. Tied near the middle
	# of the group, which is where a person ties a bundle and is also the only
	# place that does not hide either the heads or the fletching.
	cord.position = Vector3(0.0, 0.013, 0.12)
	_rig.add_child(cord)

	# Same "look here" the motes use, in a neutral bone rather than an item tint,
	# so a bundle is never mistaken for a rare drop across a room. Short range:
	# this is supply, not treasure.
	#
	# Deliberately DIMMER than a mote's 1.1, and hung above rather than in. A mote
	# is an emissive prism and its light reads as the object glowing; these are
	# ordinary lit materials on a thing 4 cm thick, so the same energy lights the
	# FLOOR instead. The same trap loot_mote.gd records at its emission line.
	_light = OmniLight3D.new()
	_light.light_color = Pal.BONE
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 2.2
	_light.shadow_enabled = false
	_light.position.y = LIGHT_Y
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	if _taken:
		return

	var bob := sin(_age * BOB_SPEED) * BOB_HEIGHT
	_rig.position.y = 0.16 + bob
	_rig.rotation.y += 0.7 * delta
	_light.position.y = LIGHT_Y + bob

	if _refused > 0.0:
		# Quiver full. Pulse and stay: unlike a full bag, this is not a decision
		# the player has to unmake, it is a bundle to come back for after a fight.
		_refused = maxf(0.0, _refused - delta)
		_light.light_energy = LIGHT_ENERGY + (0.5 + 0.5 * sin(_age * 14.0)) * 1.1
		return

	_light.light_energy = LIGHT_ENERGY
	if _age < ARM_TIME:
		return
	for b in get_overlapping_bodies():
		if b.is_in_group(&"player"):
			_take()
			return


func _take() -> void:
	var room: int = maxi(0, Game.max_arrows - Game.arrows)
	if room <= 0:
		_refused = 0.9
		return
	var got: int = mini(count, room)
	Game.add_arrows(got)
	_taken = true
	# Off the map entirely, unlike an opened chest, which greys out. A chest is
	# a landmark you remember a room by; a bundle of arrows off the floor is
	# nothing, and a permanent grey arrow in a room would be the map advertising
	# somewhere there is no reason to go back to.
	if mapped:
		Atlas.replace_at(global_position, Atlas.M_ARROWS, &"")
	Bus.request_sfx.emit(&"pickup", global_position)
	Bus.request_message.emit("Arrows  +%d" % got)
	_pop()


## Rise and fade, same as a mote. The only confirmation that the thing on the
## floor became the number under the bow.
func _pop() -> void:
	monitoring = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_rig, "position:y", _rig.position.y + 0.8, 0.26) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_rig, "scale", Vector3.ONE * 0.1, 0.26).set_ease(Tween.EASE_IN)
	tw.tween_property(_light, "light_energy", 0.0, 0.26)
	tw.chain().tween_callback(queue_free)
