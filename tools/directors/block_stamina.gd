extends RefCounted
## Shield blocks are paid by the incoming blow's quarter-heart weight.
##
## This director holds one real hero in a frontal guard and sends `Hit`s through
## `DamageArea._deliver`, the same entry every live hitbox uses. Game processing
## is disabled for the measured beats so stamina regen cannot move either side
## of a subtraction between reads.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/block_stamina.gd --warmup=60

const HERO_AT := Vector3(0.0, 0.05, 7.4)
const FACE_MINUS_Z := PI

var _fails := 0


func run(rig) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		print("BLOCK STAMINA FAIL -- %d check(s) failed" % _fails)
		return
	var hero: Node3D = players[0]
	var combat = hero.get(&"combat")
	if combat == null:
		_fail("the hero has no combat component")
		print("BLOCK STAMINA FAIL -- %d check(s) failed" % _fails)
		return

	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	hero.rotation.y = FACE_MINUS_Z + PI
	hero.set(&"state", 0)  # Hero.MoveState.GROUND
	hero.velocity = Vector3.ZERO
	combat.set(&"blocking", true)
	combat.set(&"_parry_t", -1.0)
	hero.call(&"set_blocking", true)

	var game_process_mode := Game.process_mode
	Game.process_mode = Node.PROCESS_MODE_DISABLED
	Game.heal(Game.max_quarters)
	_prove_weight_scaling(hero)
	_prove_empty_bar_followup(hero, combat)
	Game.process_mode = game_process_mode

	if _fails == 0:
		print("BLOCK STAMINA OK")
	else:
		print("BLOCK STAMINA FAIL -- %d check(s) failed" % _fails)


func _prove_weight_scaling(hero: Node3D) -> void:
	var drain_two := _blocked_drain(hero, 2, 60.0)
	var drain_four := _blocked_drain(hero, 4, 60.0)
	var exact := is_equal_approx(drain_two, 2.0 * K.STAMINA_BLOCK_PER_QUARTER) \
		and is_equal_approx(drain_four, 4.0 * K.STAMINA_BLOCK_PER_QUARTER)
	if exact and is_equal_approx(drain_four, drain_two * 2.0):
		print("BLOCK STAMINA OK 4-quarter drain %.1f is twice 2-quarter drain %.1f"
			% [drain_four, drain_two])
	else:
		_fail("4-quarter drain %.1f is not twice 2-quarter drain %.1f"
			% [drain_four, drain_two])


func _prove_empty_bar_followup(hero: Node3D, combat) -> void:
	Game.heal(Game.max_quarters)
	Game.stamina = 1.0
	hero.set(&"_invuln", 0.0)
	var hp_before: int = Game.quarters
	var first_landed := DamageArea._deliver(hero, _frontal_hit(hero, 4))
	if not first_landed and Game.quarters == hp_before and is_zero_approx(Game.stamina):
		print("BLOCK STAMINA OK positive stamina blocked once and clamped to zero")
	else:
		_fail("low-stamina block landed=%s hp=%d->%d stamina=%.1f"
			% [first_landed, hp_before, Game.quarters, Game.stamina])

	# The first catch grants shield i-frames. Clear those before the control hit
	# so this beat measures the zero-stamina block query rather than immunity.
	hero.set(&"_invuln", 0.0)
	var hp_zero: int = Game.quarters
	var second_landed := DamageArea._deliver(hero, _frontal_hit(hero, 2))
	if second_landed and combat.get(&"blocking") and Game.quarters < hp_zero:
		print("BLOCK STAMINA OK second guarded frontal hit landed at zero stamina"
			+ " (hp %d -> %d)" % [hp_zero, Game.quarters])
	else:
		_fail("zero-stamina follow-up landed=%s guard=%s hp=%d->%d stamina=%.1f"
			% [second_landed, combat.get(&"blocking"), hp_zero, Game.quarters,
				Game.stamina])


func _blocked_drain(hero: Node3D, amount: int, start: float) -> float:
	Game.stamina = start
	hero.set(&"_invuln", 0.0)
	var hp_before: int = Game.quarters
	var landed := DamageArea._deliver(hero, _frontal_hit(hero, amount))
	if landed or Game.quarters != hp_before:
		_fail("%d-quarter scaling hit was not blocked (hp %d -> %d)"
			% [amount, hp_before, Game.quarters])
	return start - Game.stamina


func _frontal_hit(hero: Node3D, amount: int) -> Hit:
	var from := hero.global_position - hero.global_transform.basis.z * 2.0
	return Hit.make(amount, from, &"contact", 0.0, 0.0, &"DIRECTOR")


func _fail(msg: String) -> void:
	_fails += 1
	print("BLOCK STAMINA FAIL %s" % msg)
