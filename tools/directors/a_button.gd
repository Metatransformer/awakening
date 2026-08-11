extends RefCounted
## The A button, which is now two buttons — the dodge AND the interact — and the
## rule that decides which one you get.
##
## Nothing here is visible in a still frame, which is exactly why it needs a
## director rather than an eye: the whole feature is a press that does one thing
## in one place and a different thing two metres away. The frames are captured
## anyway, because "the shop opened" and "the shop opened while the hero rolled
## through the vendor" print the same log line.
##
## A/Cross presses `context` and `interact` together, so that pair IS the button
## here. `shoot.gd` strips every joypad binding for the run (see
## `_deafen_the_gamepad`), so the pad cannot be driven directly and pressing both
## keyboard halves on the same frame is the faithful stand-in — it produces the
## identical InputMap state the pad would.
##
## Five beats, and the last two are the ones that would have shipped broken:
##
##   1. At the vendor, A talks and does NOT roll.
##   2. B closes the screen it opened. B does nothing else in the world.
##   3. Two metres away, the same A rolls.
##   4. Held at the gate, A fills the gate's ring and does NOT wind up a sprint.
##   5. On a KEYBOARD, Shift at the vendor still rolls — the arbitration only
##      fires when one press reached both actions, which never happens there.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/a_button.gd --out=/tmp/abtn/x.png

## Both halves of one A press.
const A := ["context", "interact"]

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/abtn/x.png").get_base_dir()
	await rig.wait_frames(30)

	await _talk_beats_roll(rig)
	await _b_closes(rig)
	await _roll_when_free(rig)
	await _hold_at_gate(rig)
	await _keyboard_still_rolls(rig)

	print("A-BTN done fails=%d" % _fails)


# --- 1. The thing in reach wins ---------------------------------------------

func _talk_beats_roll(rig) -> void:
	var garrison := rig.scene() as Garrison
	var hero := _hero(rig)
	_stand_at(rig, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	await _await_focus(rig)
	if Prompt.focus == null:
		_fail("nothing owns the button at the vendor — beat 1 proves nothing")
		return

	var was: Vector3 = hero.global_position
	# Watched every frame rather than sampled after the fact. A roll is 0.4 s
	# long and its recovery puts the hero back roughly where he started, so a
	# check made afterwards would miss the one thing this beat exists to catch.
	var rolled := await _press_a_watching_state(rig, hero, 24)

	print("A-BTN vendor rolled=%s moved=%.2f screen=%s" % [
		rolled, was.distance_to(hero.global_position), Prompt.blocked])
	await rig.capture(out.path_join("a_01_talk.png"))
	if rolled:
		_fail("A rolled the hero at the vendor — the thing in reach must win")
	if not Prompt.blocked:
		_fail("A did not open the vendor's screen")


# --- 2. B is the way out, and only that -------------------------------------

func _b_closes(rig) -> void:
	await rig.tap(["ui_cancel"])
	await rig.wait_frames(14)
	print("A-BTN after_cancel blocked=%s" % Prompt.blocked)
	await rig.capture(out.path_join("a_02_closed.png"))
	if Prompt.blocked:
		_fail("B did not close the screen")

	# B in the world. It used to roll; it must now be silent, because "B closes
	# this" is only true everywhere if B means nothing anywhere else.
	var hero := _hero(rig)
	_stand_clear(rig)
	await rig.wait_frames(20)
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.4)
	var rolled := await _watch_state(rig, hero, 24, func() -> void:
		await rig.tap(["ui_cancel"]))
	Input.action_release(&"move_up")
	await rig.wait_frames(10)
	print("A-BTN b_in_world rolled=%s" % rolled)
	if rolled:
		_fail("B still rolls in the world — it is ui_cancel and nothing else")


# --- 3. Step away and the same button dodges --------------------------------

func _roll_when_free(rig) -> void:
	var hero := _hero(rig)
	_stand_clear(rig)
	await _await_no_focus(rig)
	if Prompt.focus != null:
		_fail("could not find ground clear of every Interactable")
		return

	# The free roll needs a near-full deflection (K.STICK_ACTION_GATE), so he has
	# to be running before the press — this is not a standing dodge and gating it
	# on a walk is what `p2_roll` proves.
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.4)
	var rolled := await _press_a_watching_state(rig, hero, 24)
	Input.action_release(&"move_up")
	await rig.wait_frames(20)

	print("A-BTN free rolled=%s" % rolled)
	await rig.capture(out.path_join("a_03_roll.png"))
	if not rolled:
		_fail("A did not roll with nothing in reach")


# --- 4. The held half, at the one prompt that measures a hold ----------------

func _hold_at_gate(rig) -> void:
	var garrison := rig.scene() as Garrison
	var hero := _hero(rig)

	# The negative control FIRST, on clear ground: a held A must reach a sprint,
	# otherwise "no sprint at the gate" is not evidence of anything.
	_stand_clear(rig)
	await _await_no_focus(rig)
	Input.action_press(&"move_up", 1.0)
	var ran := await _watch_sprint(rig, hero, 0.6)
	Input.action_release(&"move_up")
	await rig.wait_frames(10)
	print("A-BTN control sprinted=%s" % ran)
	if not ran:
		_fail("a held A did not sprint on clear ground — beat 4 proves nothing")

	_stand_at(rig, garrison.gate.global_position + Vector3(0.0, 0.0, 1.8),
		garrison.gate.global_position)
	await _await_focus(rig)
	if Prompt.focus == null:
		_fail("nothing owns the button at the gate")
		return

	# 0.6 s: comfortably past `sprint_hold_time` (0.18) and comfortably short of
	# the gate's own 0.9 s, so this beat tests the HOLD and not the descent
	# — mvp_loop owns the descent. The stick is held too, because a sprint needs
	# somewhere to go and the failure being hunted is a hero who runs at a gate
	# he is trying to open.
	Input.action_press(&"move_up", 1.0)
	var sprinted := await _watch_sprint(rig, hero, 0.6)
	Input.action_release(&"move_up")
	await rig.wait_frames(10)

	print("A-BTN gate sprinted=%s still_focused=%s" % [
		sprinted, Prompt.focus != null])
	await rig.capture(out.path_join("a_04_gate_hold.png"))
	if sprinted:
		_fail("a held A wound up a sprint while the gate owned the button")


# --- 5. The keyboard is not in the arbitration ------------------------------

func _keyboard_still_rolls(rig) -> void:
	var garrison := rig.scene() as Garrison
	var hero := _hero(rig)
	# Standing AT the vendor, which is the case that would break if the rule were
	# "a focus refuses the dodge" rather than "one press reached both actions".
	_stand_at(rig, garrison.vendor.global_position + Vector3(2.0, 0.0, 1.6),
		garrison.vendor.global_position)
	await _await_focus(rig)
	if Prompt.focus == null:
		_fail("the vendor does not own the button — beat 5 proves nothing")
		return

	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.4)
	var rolled := await _watch_state(rig, hero, 24, func() -> void:
		await rig.tap(["context"]))
	Input.action_release(&"move_up")
	await rig.wait_frames(20)

	print("A-BTN keyboard rolled=%s blocked=%s" % [rolled, Prompt.blocked])
	await rig.capture(out.path_join("a_05_keyboard.png"))
	if not rolled:
		_fail("Shift stopped rolling near an Interactable — the keyboard shares nothing")
	if Prompt.blocked:
		_fail("Shift opened the vendor's screen")


# --- Instruments ------------------------------------------------------------

## Press A and report whether the hero entered a ROLL at any point in the window.
func _press_a_watching_state(rig, hero: Hero, frames: int) -> bool:
	return await _watch_state(rig, hero, frames, func() -> void:
		await rig.tap(A))


## Run `act`, then watch `frames` frames for the roll state. The watch has to
## outlast the act: `tap` returns two frames in and the roll runs for 0.4 s.
func _watch_state(rig, hero: Hero, frames: int, act: Callable) -> bool:
	var seen := _is_rolling(hero)
	await act.call()
	for _i in frames:
		await rig.wait_frames(1)
		if _is_rolling(hero):
			seen = true
	return seen


## Hold A for `seconds` and report whether the hero ever reached a sprint.
##
## The hold and the sampling are the SAME loop, deliberately. `sprinting` is
## recomputed every physics frame and is false again the instant the button comes
## up, so there is nothing left to read once a `rig.hold_seconds` returns — it has
## to be watched while it is held.
##
## The first version of this ran the sampler as a lambda alongside `hold_seconds`
## and it silently reported `false` for a hero who was visibly running: GDScript
## lambdas capture by VALUE, so the `seen = true` inside the closure wrote to a
## copy and the caller read the original. Nothing errored. The negative control
## below is the only reason it was caught, which is what a negative control is
## for — do not delete it, and do not reach for a closure here again.
##
## The clock is wall time rather than a frame count because the game measures the
## hold in seconds (`Hero.sprint_hold_time`) and this window renders uncapped, so
## a hold counted in frames is a hold of unknown length.
func _watch_sprint(rig, hero: Hero, seconds: float) -> bool:
	await rig.wait_frames(1)
	for a in A:
		Input.action_press(a)
	var seen := false
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await rig.wait_frames(1)
		if hero.sprinting:
			seen = true
	for a in A:
		Input.action_release(a)
	await rig.wait_frames(2)
	return seen


func _is_rolling(hero: Hero) -> bool:
	var s: int = hero.state
	return s == Hero.MoveState.ROLL or s == Hero.MoveState.ROLL_RECOVER


func _await_focus(rig) -> void:
	for _i in 40:
		if Prompt.focus != null:
			return
		await rig.wait_frames(2)


func _await_no_focus(rig) -> void:
	for _i in 40:
		if Prompt.focus == null:
			return
		await rig.wait_frames(2)


## Somewhere in the garrison square with nothing in reach. Measured off the
## vendor rather than hardcoded, so a garrison that moves its furniture does not
## quietly turn beat 3 into a second copy of beat 1.
func _clear_ground(rig) -> Vector3:
	var garrison := rig.scene() as Garrison
	return garrison.vendor.global_position + Vector3(0.0, 0.0, 9.0)


## Stand clear and FACE AWAY from the vendor. The beats that need clear ground
## all run forward for half a second before they press anything, and the stick is
## camera-relative — pointed the other way that run walks straight back into the
## quartermaster's radius, and the beat then fails for a reason that has nothing to
## do with the button. It cannot pass wrongly (a focus refuses the roll, so the
## drift shows up as a FAIL) but it can waste an afternoon.
func _stand_clear(rig) -> void:
	var garrison := rig.scene() as Garrison
	var at := _clear_ground(rig)
	_stand_at(rig, at, at + (at - garrison.vendor.global_position))


func _hero(rig) -> Hero:
	return rig.scene().get_tree().get_first_node_in_group(&"player") as Hero


func _stand_at(rig, at: Vector3, look_at = null) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = Vector3(at.x, 0.05, at.z)
	if look_at != null:
		var to := K.flat(look_at - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI


func _fail(why: String) -> void:
	_fails += 1
	print("A-BTN FAIL %s" % why)
