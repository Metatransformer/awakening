class_name HealthComponent
extends Node
## Anything that can be hurt owns one of these. docs/CONTRACT.md §8.
##
## Health is in QUARTER hearts everywhere, including for enemies — one scale for
## the whole game means a sword's damage number reads the same wherever it lands.
##
## The hero's health lives in `Game` so it survives a scene change; set
## `use_game_state` and this becomes a thin proxy onto it rather than a second,
## competing copy that will drift.

signal damaged(hit: Hit)
signal died
signal healed(amount: int)

@export var max_quarters: int = 4 * K.HEART
## Route reads and writes to the Game autoload instead of the local field.
@export var use_game_state: bool = false
## Seconds of invulnerability after a hit lands. [oot] K.IFRAME_TIME.
@export var iframe_time: float = K.IFRAME_TIME
## Enemies flash but do not get i-frames by default — a swarm that all become
## briefly invincible makes a crowd feel spongy instead of dangerous.
@export var use_iframes: bool = false

var quarters: int = 0
var is_dead: bool = false

var _iframe: float = 0.0


func _ready() -> void:
	if use_game_state:
		quarters = Game.quarters
	else:
		quarters = max_quarters


func _process(delta: float) -> void:
	if _iframe > 0.0:
		_iframe = maxf(_iframe - delta, 0.0)


func current() -> int:
	return Game.quarters if use_game_state else quarters


func maximum() -> int:
	return Game.max_quarters if use_game_state else max_quarters


func fraction() -> float:
	var m := maximum()
	return 0.0 if m <= 0 else float(current()) / float(m)


func is_invulnerable() -> bool:
	return _iframe > 0.0


func apply_hit(hit: Hit) -> void:
	if is_dead or hit == null or hit.amount <= 0:
		return
	if use_iframes and _iframe > 0.0:
		return

	if use_game_state:
		# Game.damage owns the health-changed signal and the death signal for
		# the player; do not duplicate either here.
		Game.damage(hit.amount)
	else:
		quarters = maxi(0, quarters - hit.amount)

	if use_iframes:
		_iframe = iframe_time

	damaged.emit(hit)
	Bus.hit_landed.emit(get_parent(), hit.amount, hit.from)

	if current() <= 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	if use_game_state:
		Game.heal(amount)
	else:
		quarters = mini(maximum(), quarters + amount)
	healed.emit(amount)


## Re-sync a proxying component after the armour tier changed max hearts.
func refresh() -> void:
	if use_game_state:
		is_dead = Game.quarters <= 0
