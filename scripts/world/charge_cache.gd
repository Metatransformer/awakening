class_name ChargeCache
extends Area3D
## A cache of Burst charges on the floor. Walk over it and they go in the pouch.
##
## **This is `docs/PUZZLES.md` §0 rule 2 for the working**, and it exists because
## the rule was unmet: *every puzzle room is solvable from a cold start with an
## empty pouch, because the urns beside it hold exactly what it needs.* Floor 2's
## shortcut is a cracked pillar and the only answer to a cracked pillar is a
## Burst; charges could be bought in the garrison (`AlchemyDb`) and nowhere else,
## so a player who descended with none met a door with no legal way through.
## `docs/ITEMS.md` §8 D13 is the defect and card #29 is this file.
##
## **It is `ArrowBundle`'s shape, not `LootMote`'s, and that is the whole design
## decision.** A mote goes in the BAG -- a slot, heat, gold, dead on death. A
## charge is none of those: it lives on `Game`, it survives the run, it costs no
## slot, and nobody ever sold one to a pawnbroker. Routing ammunition through the
## bag would put the extraction fee on the thing that opens the door.
##
## **What it is NOT is a second supply channel.** `Dungeon` rolls arrow bundles
## across rooms; nothing rolls these, and nothing should. GDD §6.5 makes charges
## a stock you paid for before you left, and a floor that scattered them would
## undo the "how deep were you planning to go" decision `Game.charges` is written
## to protect. There is exactly one of these underground and it stands beside the
## door that demands it -- `Dungeon._shortcut_pillar_brace`. See `HOLDS`.

## What one cache is worth. **Two, not one**: one charge and one missed arc is
## the same dead end this prop was built to close, and a player meeting the
## working's parabola for the first time in a corridor is exactly who this is
## for. Two, not three, because three is `AlchemyDb.CHARGE_BATCH` -- the floor
## must not be a cheaper counter. [tune]
const HOLDS := 2

const ARM_TIME := 0.35
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.06
## How many glyphs are actually modelled. Three reads as "more than one" from
## across a room; the COUNT is on the pickup message, the same bargain
## `ArrowBundle.SHAFTS` strikes.
const GLYPHS := 3
## Each one, in metres. `BurstCast.MOTE_R` is 0.11 and this is deliberately under
## it: a cache that drew three full-size motes would read as three live castings
## lying on the floor with their fuses out, which is a thing the player should
## never be looking at. It is not much under it, though — at 0.075 the three
## overlapped into one blob at the 4 m the room is actually seen from, which the
## first pass of `charge_supply.gd`'s beat C photographed.
const GLYPH_R := 0.09
## How far each glyph sits from the middle, as a multiple of its own radius. Wide
## enough that three read as three; narrow enough that they still sit in the
## cradle rather than beside it.
const GLYPH_SPREAD := 2.1

## Where the "look here" light hangs, and how hard. Above the glyphs rather than
## inside them, for `arrow_bundle.gd`'s measured reason: an omni at the object's
## own height saturates the object it is meant to be showing you.
const LIGHT_Y := 0.48
const LIGHT_ENERGY := 0.55
const LIGHT_RANGE := 1.6

## Charges granted on pickup.
@export var count: int = HOLDS

var _rig: Node3D
var _light: OmniLight3D
var _age: float = 0.0
var _refused: float = 0.0
var _taken: bool = false


## Drop one at `at`, optionally flung along `fling` the way an urn spills what was
## inside it. Mirrors `ArrowBundle.drop` exactly so a placer that already knows
## how to lay out supply does not have to learn a second shape.
static func drop(parent: Node, at: Vector3, n: int = HOLDS,
		fling: Vector3 = Vector3.ZERO) -> ChargeCache:
	var c := ChargeCache.new()
	c.name = "ChargeCache"
	c.count = maxi(n, 1)
	parent.add_child(c)
	c.global_position = at
	if fling != Vector3.ZERO:
		var land := at + fling
		var tw := c.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(c):
				c.global_position = at.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.55,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
	return c


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


## No `Atlas` marker, unlike a floor arrow bundle.
##
## `ArrowBundle.mapped` exists because `Dungeon._populate` advertises the bundle
## it lies in a room and has to un-advertise it on pickup. These are never rolled
## into a room -- the only one in the game spills out of the urn braced against
## floor 2's shortcut, and it is three metres from a door the map already draws.
## A second marker there would say "supply somewhere in this room" about a thing
## the player is standing on.
func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.position.y = 0.14
	add_child(_rig)

	# The working's own glyph, at the working's own hue. This is the one thing
	# the pickup has to say and a tint cannot say it -- "gold means rare" is the
	# rarity ramp (`Pal.RARITY`) and means nothing about ammunition -- so it is
	# said by the SILHOUETTE, and the silhouette is the same faceted mote the
	# player watches leave his hand (`burst_cast.gd:_build`).
	var burn := StandardMaterial3D.new()
	burn.albedo_color = Pal.RUST.lerp(Pal.GOLD, 0.45)
	burn.emission_enabled = true
	burn.emission = Pal.RUST.lerp(Pal.GOLD, 0.35)
	# Emission well under 1.0 and MIX, never ADD. `CLAUDE.md` §3: alpha does not
	# attenuate an additive material, and a bright shell over this project's
	# near-black floor is an opaque slab at every opacity.
	burn.emission_energy_multiplier = 0.9
	burn.roughness = 0.6
	for i in GLYPHS:
		var sm := SphereMesh.new()
		sm.radius = GLYPH_R
		sm.height = GLYPH_R * 2.0
		# Faceted, never smooth. The whole kit is hard-edged and `burst_cast.gd`
		# draws its mote at exactly these counts -- a smooth ball here would read
		# as an asset from a different game.
		sm.radial_segments = 8
		sm.rings = 4
		var mi := MeshInstance3D.new()
		mi.name = "Glyph%d" % i
		mi.mesh = sm
		mi.material_override = burn
		# A triangle on the floor, not a stack. Three glyphs in a column is one
		# glyph from every angle the camera actually has (`docs/CONTRACT.md` §1.2
		# pitches it 5 degrees), and the count is what makes this read as a cache
		# rather than as a live casting somebody left lying there.
		var a := TAU * float(i) / float(GLYPHS)
		mi.position = Vector3(cos(a) * GLYPH_R * GLYPH_SPREAD, 0.0,
			sin(a) * GLYPH_R * GLYPH_SPREAD)
		_rig.add_child(mi)

	# The cradle. Three loose glyphs read as spillage; a band under them reads as
	# something a person set down -- `ArrowBundle`'s cord, and the same reason.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.20, 0.17, 0.15)
	iron.roughness = 1.0
	iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var dish := MeshInstance3D.new()
	dish.name = "Cradle"
	var cm := CylinderMesh.new()
	cm.top_radius = GLYPH_R * (GLYPH_SPREAD + 1.1)
	cm.bottom_radius = GLYPH_R * (GLYPH_SPREAD + 0.7)
	cm.height = 0.05
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = iron
	dish.mesh = cm
	dish.position.y = -GLYPH_R * 0.7
	_rig.add_child(dish)

	# Same "look here" the bundles use, at the WORKING's hue rather than
	# `ArrowBundle`'s neutral bone. The bundle is deliberately colourless so it is
	# never mistaken for a rare drop; this one has the opposite job, because the
	# only reason to walk to it is that you recognise what it feeds. Rust-gold is
	# not on `Pal.RARITY`, so it still collides with no loot tier.
	_light = OmniLight3D.new()
	_light.light_color = Pal.RUST.lerp(Pal.GOLD, 0.35)
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
	_rig.position.y = 0.14 + bob
	_rig.rotation.y += 0.7 * delta
	_light.position.y = LIGHT_Y + bob

	if _refused > 0.0:
		# Pouch full. Pulse and STAY -- unlike a full bag, this is not a decision
		# the player has to unmake, it is a cache to come back for. It also means
		# a player who arrives at the shortcut already stocked does not have his
		# spare quietly clamped away by `add_charges`.
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


## `Game.add_charges()` and nothing else. It is the seam the alchemist's counter
## already uses (`AlchemyDb._charge_line`), it clamps at `max_charges`, and it is
## what emits `Bus.ammo_changed` -- so the HUD cell under the working updates for
## the same reason it does after a purchase. A second path that wrote `charges`
## directly would be a counter the HUD does not redraw.
func _take() -> void:
	var room: int = maxi(0, Game.max_charges - Game.charges)
	if room <= 0:
		_refused = 0.9
		return
	var got: int = mini(count, room)
	Game.add_charges(got)
	_taken = true
	Bus.request_sfx.emit(&"pickup", global_position)
	Bus.request_message.emit("Charges  +%d" % got)
	_pop()


## Rise and fade, same as a bundle. The only confirmation that the thing on the
## floor became the number under the working.
func _pop() -> void:
	monitoring = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_rig, "position:y", _rig.position.y + 0.8, 0.26) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_rig, "scale", Vector3.ONE * 0.1, 0.26).set_ease(Tween.EASE_IN)
	tw.tween_property(_light, "light_energy", 0.0, 0.26)
	tw.chain().tween_callback(queue_free)
