extends RefCounted
## The health and stamina bars, shot so the stamina claim is checkable rather
## than asserted.
##
## The bar is only worth drawing if it is telling the truth about the dodge, so
## this rolls until the roll is REFUSED and captures each step. K.STAMINA_ROLL
## is 34 of 100, so the sequence is: three rolls, then a fourth press that must
## do nothing, then regen back to full.
##
## What each frame has to show:
##   00_full     bar at 100, three roll boundaries visible
##   01/02/03    one roll spent each, BONE while >= one roll remains
##   04_spent    under K.STAMINA_ROLL, so the fill turns RUST
##   05_refused  `context` pressed at 32/100 — the hero must NOT roll, and the
##               bar must not move. If he rolls here the bar is a decoration.
##   06/07_regen K.STAMINA_DELAY has passed and the bar is climbing again
##
## Health is captured alongside so the ghost drain and the HP ticks are in
## the same sheet — Game.damage() is called directly, because taking a real hit
## needs an enemy and this is a UI shot, not a combat shot.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.5)
	await _shot(rig, "full")

	# Three rolls. Each needs a committed run — K.STICK_ACTION_GATE means a
	# half-stick walk cannot roll at all, so hold the stick fully the whole time.
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.35)

	for i in 3:
		# rig.tap, not raw Input: a press issued straight after a capture lands
		# one frame stale and every polled button ignores it. See shoot.gd hold().
		await rig.tap([&"context"])
		# Long enough for the roll to finish, short enough that regen has not
		# refilled the spend we are trying to photograph.
		await rig.wait_seconds(0.30)
		await _shot(rig, "roll%d" % (i + 1))

	# The refusal. Stamina is driven straight to just under one roll rather than
	# counted down by rolling: K.STAMINA_REGEN refills 46/sec and a roll takes
	# K.ROLL_TIME, so "roll until empty" is a race the regen wins, and a test
	# that depends on losing that race is a flaky test.
	var hero: Node = rig.get_first_node_in_group(&"player")
	Game.stamina = K.STAMINA_ROLL - 2.0
	Game._stamina_hold = 3.0          # freeze regen for the length of the check
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	await rig.wait_seconds(0.05)
	await _shot(rig, "spent")

	var before: float = Game.stamina
	await rig.tap([&"context"])
	await rig.wait_seconds(0.12)
	await _shot(rig, "refused")

	# Two things have to hold, and the second is the one that matters: the bar
	# did not move, AND the hero did not actually roll. Checking only the number
	# would pass even if the roll happened for free.
	var rolled: bool = hero != null and int(hero.state) == 2   # MoveState.ROLL
	if rolled or Game.stamina < before - 0.01:
		push_error("HUD VITALS: roll at %.1f stamina was NOT refused (now %.1f, rolling=%s)"
			% [before, Game.stamina, rolled])
	else:
		print("HUD VITALS: roll refused at %.1f stamina, hero did not roll — correct"
			% before)
	Game._stamina_hold = 0.0

	Input.action_release(&"move_up")

	# Regen: K.STAMINA_DELAY of nothing, then a climb to full.
	await rig.wait_seconds(0.6)
	await _shot(rig, "regen1")
	await rig.wait_seconds(0.8)
	await _shot(rig, "regen2")

	# Health, so the ghost and the ticks land in the same sheet. Two separate
	# hits inside GHOST_HOLD, which must read as one 5 HP loss.
	Game.damage(3)
	await rig.wait_seconds(0.10)
	Game.damage(2)
	await rig.wait_seconds(0.12)
	await _shot(rig, "hurt_ghost")
	await rig.wait_seconds(0.70)
	await _shot(rig, "hurt_settled")

	# Down to the low-health state: <= 3 HP pulses VITAL<->BONE and the
	# empty track goes VOID.
	Game.damage(4)
	await rig.wait_seconds(0.80)
	await _shot(rig, "low")


func _shot(rig, tag: String) -> void:
	await rig.capture("v_%02d_%s.png" % [_i, tag])
	_i += 1
