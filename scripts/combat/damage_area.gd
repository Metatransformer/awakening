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

	# Marked before the outcome is known, not after: "once per activation" is a
	# property of the SWING, and a blow the shield ate is still a blow this swing
	# has spent. Marking on success instead would leave the window retrying every
	# frame and land the moment the victim's i-frames lapsed, which is a swing
	# that hits you for standing still.
	_already_hit.append(id)

	var hit := Hit.make(amount, global_position, kind, knockback, stun)
	# Only a blow that actually landed is announced. Blocked and i-framed blows
	# must not spark and clang as though they connected.
	if _deliver(body, hit):
		connected.emit(body, hit)


## Hand `hit` to whatever `body` uses to take damage, and say whether it landed.
##
## There are TWO victim entry points and that is deliberate, not drift. An enemy
## keeps its health in a `HealthComponent` child. The hero cannot: his health
## lives in `Game` so it survives the scene change that extracting causes, and a
## component on his body would die with the dungeon along with the whole reason
## to extract (`Hero.take_hit`). So the single damage path is THIS function --
## one deliverer, asked in one order -- and not a single victim class.
##
## Both halves of that were broken until now, in ways that looked like design:
##
##   * `hp.is_dead` -- HealthComponent has `dead`, and has never had an
##     `is_dead`. The read raised "Invalid access to property or key" and aborted
##     this function one line before the damage, for every blow in the game, in
##     both directions, for as long as the file has existed.
##   * Only HealthComponent was ever consulted, so the hero -- who has none --
##     could not be hurt by anything that swings a DamageArea. The box-built
##     placeholder enemy (`Crawler`, since deleted) was the only thing that could
##     touch him, because it reached around this file and called `take_hit`
##     itself. The GLB monsters all swing DamageAreas, and every one of them was
##     harmless from the day the roster landed until this was fixed.
##
## Neither shows up in a log. The swing plays, the hitbox opens and closes on
## schedule, and the only thing that never moves is the health number -- which is
## why `tools/directors/monster_feel.gd` watches the number and not the
## animation, on both sides of the fight.
static func _deliver(body: Node, hit: Hit) -> bool:
	# The hero first: he is the one who defines his own rules -- i-frames, the
	# shield's arc, the roll's immunity -- and `take_hit` returns false when one
	# of them ate the blow, which is exactly what the caller needs to know.
	if body.has_method(&"take_hit"):
		return bool(body.call(&"take_hit", hit))
	var hp := _health_of(body)
	if hp == null or hp.dead:
		return false
	return hp.apply_hit(hit)


static func _health_of(body: Node) -> HealthComponent:
	for c in body.get_children():
		if c is HealthComponent:
			return c
	return null


func _enter_tree() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
