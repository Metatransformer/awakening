class_name SmallKey
extends PuzzleAtom
## Atom 1 of 8 (`docs/PUZZLES.md` §2): the small key. **T0 -- you own it from
## the start, always**, which is what lets floor 1's critical path be a key hunt
## (§5.2) without breaking §0 rule 1.
##
## The key and the door are deliberately two objects. `PuzzleGate` with
## `needs_key` is the door; this is the key, and its `solved` means *the key has
## been found*. Modelling it the other way -- one prop that is a door with a
## button beside it -- would make the gate room a corridor with a pause in it,
## and the whole of §5.2 is that the Cistern's gate room is a HUNT.
##
## It is a pickup rather than an `Interactable`: `Game.add_key()` already exists
## and `Game.small_keys` is already on the HUD, so walking over it is the whole
## interaction and a prompt would be a button press between the player and a
## thing they can see they want. `LootMote` makes the same call for the same
## reason.

## Metres above the floor the key floats. Waist height on a 1.65 m hero, so it
## is inside the frame at the 5-degree camera pitch rather than down by his boots.
const HOVER := 0.85
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.07
const SPIN_SPEED := 1.1
const REVEAL_RISE := 0.30
const REVEAL_SCALE := 0.70
const REVEAL_TIME := 0.62
const LAMP_ENERGY := 2.2
const REVEAL_LAMP_ENERGY := 0.32
## How far the "look here" lamp carries. Short: a key in an unlit corner has to
## be findable, and a key that lit the room would be a waypoint.
const LAMP_RANGE := 3.4

var _body: Node3D
var _lamp: OmniLight3D
var _trigger: Area3D
var _age: float = 0.0
## `_process` is the only writer of the hover position; the reveal moves this
## offset instead so its rise composes with the ordinary bob.
var _reveal_offset: float = 0.0
var _revealed: bool = false
var _revealing: bool = false
var _reveal_tween: Tween


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.SMALL_KEY
	_build()
	# AFTER `_build`, because `restore_solved()` hides the model and `super()`
	# is what calls it. A key already taken this run must come back invisible,
	# not come back and then vanish on the frame after the player sees it.
	super()


func _process(delta: float) -> void:
	if is_solved() or _body == null:
		return
	_age += delta
	var bob := sin(_age * BOB_SPEED) * BOB_HEIGHT
	_body.position.y = HOVER + bob + _reveal_offset
	_body.rotation.y += SPIN_SPEED * delta
	if _lamp != null:
		_lamp.position.y = HOVER + bob + _reveal_offset


## Wake a staged key. Idempotent: a second wake cannot restart the motion, and a
## key already taken stays in its restored solved pose.
func reveal() -> void:
	if _revealed or is_solved():
		return
	_revealed = true
	_revealing = true
	armed = true
	_reveal_offset = -REVEAL_RISE
	if _body != null:
		_body.scale = Vector3.ONE * REVEAL_SCALE
		_body.position.y = HOVER + sin(_age * BOB_SPEED) * BOB_HEIGHT + _reveal_offset
	if _lamp != null:
		_lamp.light_energy = REVEAL_LAMP_ENERGY
		_lamp.position.y = HOVER + sin(_age * BOB_SPEED) * BOB_HEIGHT + _reveal_offset
	visible = true

	if _reveal_tween != null:
		_reveal_tween.kill()
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, ^"_reveal_offset", 0.0, REVEAL_TIME)
	if _body != null:
		_reveal_tween.tween_property(_body, ^"scale", Vector3.ONE, REVEAL_TIME)
	if _lamp != null:
		_reveal_tween.tween_property(_lamp, ^"light_energy", LAMP_ENERGY, REVEAL_TIME)
	_reveal_tween.chain().tween_callback(_finish_reveal)


## Public director-facing state: the reveal was accepted, and its motion is
## currently in flight. Neither exposes timing-sensitive transform values.
func is_revealed() -> bool:
	return _revealed


func is_revealing() -> bool:
	return _revealing


func _finish_reveal() -> void:
	_reveal_offset = 0.0
	_revealing = false
	_reveal_tween = null


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	# The grant and the solve are one event and it is `solve()` that guards
	# against a doubled physics callback (`PuzzleAtom.solve` is idempotent). The
	# grant must therefore sit INSIDE the guard, or a player standing in the
	# trigger for two frames walks away with two keys.
	# `armed` as well as `is_solved`, and the grant is what makes it matter.
	# `PuzzleAtom.solve()` already refuses while disarmed, so an unarmed key was
	# still handing out `Game.add_key(1)` on every pass and simply not counting
	# itself solved -- a free key with no puzzle behind it. `Dungeon`'s gate room
	# builds exactly that: the key is dark and disarmed until the sun socket
	# lights, and an invisible node's Area3D still collides.
	if is_solved() or not armed:
		return
	Game.add_key(1)
	Bus.request_sfx.emit(&"pickup", global_position)
	solve()


# --- The authored solve -------------------------------------------------------

func on_solved() -> void:
	_stop_reveal()
	if _trigger != null:
		# Deferred, always. This runs out of `body_entered`, and Godot refuses a
		# direct `monitoring` write while it is dispatching an area's own signal --
		# it is one error line during a screenshot run and the trigger stays live.
		_trigger.set_deferred(&"monitoring", false)
	if _body == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "position:y", HOVER + 0.9, 0.28).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "scale", Vector3.ONE * 0.05, 0.28).set_ease(Tween.EASE_IN)
	if _lamp != null:
		tw.tween_property(_lamp, "light_energy", 0.0, 0.28)


## Already taken. No rise, no fade, no noise -- it simply is not here.
func restore_solved() -> void:
	_stop_reveal()
	if _trigger != null:
		# Deferred, always. This runs out of `body_entered`, and Godot refuses a
		# direct `monitoring` write while it is dispatching an area's own signal --
		# it is one error line during a screenshot run and the trigger stays live.
		_trigger.set_deferred(&"monitoring", false)
	if _body != null:
		_body.visible = false
	if _lamp != null:
		_lamp.light_energy = 0.0


func _stop_reveal() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	_revealing = false


# --- Construction -------------------------------------------------------------

func _build() -> void:
	_trigger = Area3D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 0
	_trigger.collision_mask = K.L_PLAYER
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	# Generous. A key is small and the hero is fast; a radius that only just
	# reaches the model means running past it at speed misses it, and a pickup
	# you can outrun reads as a bug rather than as precision.
	sp.radius = 1.05
	cs.shape = sp
	cs.position.y = HOVER
	_trigger.add_child(cs)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)

	_body = Node3D.new()
	_body.name = "Key"
	_body.position.y = HOVER
	add_child(_body)

	# GOLD is currency and only currency (`docs/STYLEGUIDE.md` §2), so a small
	# key is BONE-white brass, lit. It has to be the pale thing in a green room,
	# which the Cistern's drowned-bronze tint gives it for nothing.
	var brass := _glow_mat(Pal.BONE, 1.6)
	# A bow, a shaft and two wards -- the silhouette of a key at 6 m, which is
	# the range it has to be identifiable at. Three boxes and a ring; anything
	# more is detail nobody sees at this size.
	for i in 8:
		var a := TAU * float(i) / 8.0
		_box(_body, brass, Vector3(0.062, 0.062, 0.055),
			Vector3(cos(a) * 0.13, sin(a) * 0.13 + 0.16, 0.0), Vector3(0.0, 0.0, a))
	_box(_body, brass, Vector3(0.055, 0.40, 0.055), Vector3(0.0, -0.14, 0.0))
	_box(_body, brass, Vector3(0.12, 0.055, 0.055), Vector3(0.05, -0.29, 0.0))
	_box(_body, brass, Vector3(0.09, 0.055, 0.055), Vector3(0.04, -0.19, 0.0))

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.BONE
	_lamp.light_energy = LAMP_ENERGY
	_lamp.omni_range = LAMP_RANGE
	_lamp.omni_attenuation = 1.7
	_lamp.shadow_enabled = false
	_lamp.position.y = HOVER
	add_child(_lamp)
