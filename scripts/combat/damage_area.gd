class_name DamageArea
extends Area3D
## A swing's business end. An Area3D that is OFF by default and only deals
## damage during an explicit active window.
##
## Two rules that matter:
##   * **Once per activation.** A swing that overlaps for 8 physics frames must
##     deal damage once, not eight times. `_already_hit` is cleared on activate,
##     not on deactivate, so a re-swing into the same target connects again.
##   * **It is not a trigger volume.** It never moves anything itself; it finds
##     a HealthComponent and calls `apply_hit`, which is the single damage path
##     in docs/CONTRACT.md §8.

signal connected(victim: Node3D, hit: Hit)

## Damage in quarter-hearts. Set per swing — the hero reads it off the blade tier.
@export var amount: int = 2
@export var knockback: float = K.KNOCKBACK_LIGHT
@export var stun: float = 0.15
@export var kind: StringName = &"sword"

var active: bool = false

var _already_hit: Array[int] = []


func _ready() -> void:
	add_to_group(&"hitbox")
	monitoring = false
	monitorable = false


## Open the window. Call `deactivate()` when the swing's damage frames end.
func activate() -> void:
	_already_hit.clear()
	active = true
	monitoring = true
	# Bodies already inside when the window opens must still be hit — the
	# `body_entered` signal will not fire for them.
	_sweep.call_deferred()


func deactivate() -> void:
	active = false
	monitoring = false


func _sweep() -> void:
	if not active:
		return
	for b in get_overlapping_bodies():
		_try_hit(b)


func _on_body_entered(body: Node3D) -> void:
	if active:
		_try_hit(body)


func _try_hit(body: Node3D) -> void:
	if not active or body == null:
		return
	var id := body.get_instance_id()
	if _already_hit.has(id):
		return

	var hp := _health_of(body)
	# `dead`, not `is_dead`. HealthComponent has never had an `is_dead` and this
	# read threw on EVERY overlap -- "Invalid access to property or key
	# 'is_dead'" -- which aborted _try_hit before apply_hit and silently dropped
	# every blow in the game, both ways. It is invisible from the log because
	# combat still LOOKS like it is happening: the swing plays, the hitbox opens,
	# the error scrolls past in a run nobody reads, and only the health number
	# stays put. tools/directors/monster_feel.gd checks the number now.
	if hp == null or hp.dead:
		return
	_already_hit.append(id)

	var hit := Hit.make(amount, global_position, kind, knockback, stun)
	hp.apply_hit(hit)
	connected.emit(body, hit)


static func _health_of(body: Node) -> HealthComponent:
	for c in body.get_children():
		if c is HealthComponent:
			return c
	return null


func _enter_tree() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
