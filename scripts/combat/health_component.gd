class_name HealthComponent
extends Node
## Hit points for anything that can be hurt. docs/CONTRACT.md §8.
##
## Counted in integer HP throughout, for both heroes and enemies.
##
## Invulnerability lives here rather than in each attacker, because the rule is
## a property of the victim: OOT gives you i-frames after a hit whatever hit you.

signal damaged(hit: Hit)
signal healed(amount: int)
signal died

@export var max_health_points: int = 16
## Seconds of invulnerability after a hit lands. K.IFRAME_TIME is the hero's.
@export var iframe_time: float = K.IFRAME_TIME
## Emit to the global bus as well. On for the hero; off for enemies, which would
## otherwise spam every listener.
@export var broadcast: bool = false

var health_points: int = 0
var dead: bool = false

var _invuln: float = 0.0


func _ready() -> void:
	if health_points <= 0:
		health_points = max_health_points


func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)


func is_invulnerable() -> bool:
	return _invuln > 0.0


## The one entry point. Returns true if the blow actually landed — callers use
## that to decide whether to play an impact, so a hit swallowed by i-frames does
## not spark and clang as though it connected.
func apply_hit(hit: Hit) -> bool:
	if dead or hit == null or _invuln > 0.0:
		return false
	if hit.amount <= 0:
		return false

	health_points = maxi(0, health_points - hit.amount)
	_invuln = iframe_time
	damaged.emit(hit)
	if broadcast:
		Bus.player_health_changed.emit(health_points, max_health_points)

	if health_points == 0:
		dead = true
		died.emit()
		if broadcast:
			Bus.player_died.emit()
	return true


func heal(amount: int) -> void:
	if dead or amount <= 0:
		return
	health_points = mini(max_health_points, health_points + amount)
	healed.emit(amount)
	if broadcast:
		Bus.player_health_changed.emit(health_points, max_health_points)


func fraction() -> float:
	return float(health_points) / float(maxi(max_health_points, 1))
