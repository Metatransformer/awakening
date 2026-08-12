extends RefCounted
## The two face buttons, after A and B stopped pretending to be one button.
##
## Pad A owns `interact` in the world and `ui_accept` in a screen. Behind a
## raised shield its world press is the parry, and Prompt disarms the vendor for
## that whole press. Pad B owns `context` in the world and `ui_cancel` in a
## screen. The stance or screen decides what each physical button means; A and B
## never arbitrate with one another.
##
## `shoot.gd` strips joypad bindings so a controller on the host cannot disturb
## a run. PAD_A and PAD_B therefore drive both action states a physical pad
## button would reach. The keyboard control is different on purpose: it injects
## real E and Space key events through the live InputMap, proving those keys are
## separate rather than merely proving two action names can be pressed.
##
## Five beats:
##   1. At the vendor, unguarded A talks and neither parries nor rolls.
##   2. Guarding on clear ground, A parries.
##   3. Guarding at the vendor, that same A parries and never opens the screen.
##   4. B closes a screen without rolling, then rolls in the moving world.
##   5. Keyboard E talks; keyboard Space rolls; neither owns the other's action.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/a_button.gd \
##     --out=/tmp/abtn/x.png --warmup=60

const PAD_A: Array[StringName] = [&"interact", &"ui_accept"]
const PAD_B: Array[StringName] = [&"context", &"ui_cancel"]
const GUARD_SETTLE := 6
const STATE_GROUND := 0
const STATE_ATTACK := 4

var out: String = ""
var _fails: int = 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/abtn/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(30)

	await _pad_a_talks(rig)
	await _pad_a_parries(rig)
	await _guarded_a_refuses_vendor(rig)
	await _pad_b_owns_dodge_and_cancel(rig)
	await _keyboard_is_separate(rig)

	print("A-BTN done fails=%d" % _fails)


# --- 1. Pad A talks when the shield is down ---------------------------------

func _pad_a_talks(rig) -> void:
	var hero := _hero(rig)
	var garrison := rig.scene() as Garrison
	if hero == null or garrison == null:
		return
	await _reset(rig, hero)
	_stand_at(hero, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	if not await _wait_for_focus(rig, garrison.vendor):
		_fail("pad A vendor beat has no vendor focus")
		return

	var combat = hero.get(&"combat")
	var rolled := await _watch_roll(rig, hero, func() -> void:
		await rig.tap(PAD_A))
	await rig.wait_physics_frames(2)
	print("A-BTN pad_a vendor blocked=%s parry=%.3f rolled=%s" % [
		Prompt.blocked, float(combat.get(&"_parry_t")), rolled])
	await rig.capture(out.path_join("a_01_pad_a_vendor.png"))
	if not Prompt.blocked:
		_fail("unguarded pad A did not open the vendor conversation")
	if float(combat.get(&"_parry_t")) >= 0.0:
		_fail("unguarded pad A parried at the vendor")
	if rolled:
		_fail("pad A rolled at the vendor")


# --- 2. Behind a guard, pad A is the parry ----------------------------------

func _pad_a_parries(rig) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	await _close_screen(rig)
	await _reset(rig, hero)
	_stand_clear(rig, hero)
	if not await _wait_for_no_focus(rig):
		_fail("clear-ground parry beat still has an Interactable focus")
		return

	var combat = hero.get(&"combat")
	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the guard never rose for pad A's clear-ground parry")
		rig.release(&"shield")
		return

	# No screen exists in this beat, so only A's world action has a receiver;
	# `ui_accept` is the same physical button's meaning after a screen opens. Keep
	# it down through an explicit physics tick: this window can render four frames
	# before one physics frame, so a frame-counted tap can disappear between polls.
	await rig.press(&"interact")
	await rig.wait_physics_frames(2)
	var parry: float = combat.get(&"_parry_t")
	rig.release(&"interact")
	print("A-BTN pad_a clear parry=%.3f blocked=%s" % [parry, Prompt.blocked])
	await rig.capture(out.path_join("a_02_pad_a_parry.png"))
	if parry < 0.0:
		_fail("guarded pad A did not parry on clear ground")
	if Prompt.blocked:
		_fail("clear-ground parry opened a screen")
	rig.release(&"shield")
	await _reset(rig, hero)


# --- 3. The guard takes A away from the vendor ------------------------------

func _guarded_a_refuses_vendor(rig) -> void:
	var hero := _hero(rig)
	var garrison := rig.scene() as Garrison
	if hero == null or garrison == null:
		return
	await _reset(rig, hero)
	_stand_at(hero, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	if not await _wait_for_focus(rig, garrison.vendor):
		_fail("guarded pad A beat has no vendor focus")
		return

	var combat = hero.get(&"combat")
	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the guard never rose at the vendor")
		rig.release(&"shield")
		return

	# The world half of physical A. `ui_accept` has no receiver until a screen is
	# up; keeping `interact` down is the load-bearing part because Prompt must
	# carry its refusal past the tick where the parry itself drops the guard.
	await rig.press(&"interact")
	await rig.wait_physics_frames(2)
	var parry: float = combat.get(&"_parry_t")
	print("A-BTN pad_a guarded_vendor parry=%.3f blocked=%s" % [
		parry, Prompt.blocked])
	await rig.capture(out.path_join("a_03_guarded_vendor_parry.png"))
	if parry < 0.0:
		_fail("guarded pad A at the vendor did not parry")
	if Prompt.blocked:
		_fail("guarded pad A opened the vendor on the parry edge")

	# Longer than the complete parry. A naive live-guard check leaks here because
	# HeroCombat lowers `blocking` as soon as the parry starts. Prompt._armed must
	# remember the refusal until this exact press is released.
	await rig.wait_seconds(K.PARRY_WINDOW + K.PARRY_RECOVER + 0.25)
	if Prompt.blocked:
		_fail("the held parry press opened the vendor during recovery")
	await rig.capture(out.path_join("a_04_guarded_vendor_stayed_closed.png"))
	rig.release(&"interact")
	rig.release(&"shield")
	await _reset(rig, hero)


# --- 4. Pad B is cancel in a screen and dodge in the world ------------------

func _pad_b_owns_dodge_and_cancel(rig) -> void:
	var hero := _hero(rig)
	var garrison := rig.scene() as Garrison
	if hero == null or garrison == null:
		return
	await _reset(rig, hero)
	_stand_at(hero, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	if not await _wait_for_focus(rig, garrison.vendor):
		_fail("pad B close beat has no vendor focus")
		return
	await rig.tap(PAD_A)
	if not await _wait_for_blocked(rig, true):
		_fail("pad B close beat could not open the vendor first")
		return

	var rolled_closed := await _watch_roll(rig, hero, func() -> void:
		await rig.tap(PAD_B))
	if not await _wait_for_blocked(rig, false):
		_fail("pad B did not close the vendor conversation")
	print("A-BTN pad_b close blocked=%s rolled=%s" % [
		Prompt.blocked, rolled_closed])
	await rig.capture(out.path_join("a_05_pad_b_closed.png"))
	if rolled_closed:
		_fail("pad B rolled through the screen it closed")

	await _reset(rig, hero)
	_stand_clear(rig, hero)
	if not await _wait_for_no_focus(rig):
		_fail("pad B world beat still has an Interactable focus")
		return
	await rig.press(&"move_up")
	await rig.wait_seconds(0.4)
	var rolled_world := await _watch_roll(rig, hero, func() -> void:
		await rig.tap(PAD_B))
	rig.release(&"move_up")
	print("A-BTN pad_b world blocked=%s rolled=%s" % [
		Prompt.blocked, rolled_world])
	await rig.capture(out.path_join("a_06_pad_b_roll.png"))
	if not rolled_world:
		_fail("pad B did not roll in the moving world")
	if Prompt.blocked:
		_fail("pad B opened a screen in the clear world")
	await _reset(rig, hero)


# --- 5. E and Space reach the live InputMap as different keys ---------------

func _keyboard_is_separate(rig) -> void:
	_check_key("E", KEY_E, &"interact", &"context")
	_check_key("Space", KEY_SPACE, &"context", &"interact")

	var hero := _hero(rig)
	var garrison := rig.scene() as Garrison
	if hero == null or garrison == null:
		return
	await _reset(rig, hero)
	_stand_at(hero, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	if not await _wait_for_focus(rig, garrison.vendor):
		_fail("keyboard E beat has no vendor focus")
		return

	var combat = hero.get(&"combat")
	var e_rolled := await _watch_roll(rig, hero, func() -> void:
		await _tap_key(rig, KEY_E))
	await rig.wait_physics_frames(2)
	print("A-BTN key_e blocked=%s parry=%.3f rolled=%s" % [
		Prompt.blocked, float(combat.get(&"_parry_t")), e_rolled])
	await rig.capture(out.path_join("a_07_key_e_vendor.png"))
	if not Prompt.blocked:
		_fail("keyboard E did not open the vendor conversation")
	if float(combat.get(&"_parry_t")) >= 0.0:
		_fail("keyboard E parried without a guard")
	if e_rolled:
		_fail("keyboard E rolled at the vendor")

	await _close_screen(rig)
	await _reset(rig, hero)
	_stand_clear(rig, hero)
	if not await _wait_for_no_focus(rig):
		_fail("keyboard Space beat still has an Interactable focus")
		return
	await rig.press(&"move_up")
	await rig.wait_seconds(0.4)
	var space_rolled := await _watch_roll(rig, hero, func() -> void:
		await _tap_key(rig, KEY_SPACE))
	rig.release(&"move_up")
	print("A-BTN key_space blocked=%s rolled=%s" % [
		Prompt.blocked, space_rolled])
	await rig.capture(out.path_join("a_08_key_space_roll.png"))
	if not space_rolled:
		_fail("keyboard Space did not roll in the moving world")
	if Prompt.blocked:
		_fail("keyboard Space opened a world screen")
	await _reset(rig, hero)


# --- Instruments ------------------------------------------------------------

func _hero(rig) -> Hero:
	var players: Array[Node] = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		return null
	return players[0] as Hero


func _reset(rig, hero: Hero) -> void:
	for action: StringName in [
		&"shield", &"interact", &"ui_accept", &"context", &"ui_cancel", &"move_up"
	]:
		rig.release(action)
	await rig.wait_physics_frames(3)
	if hero.state == STATE_ATTACK:
		hero.end_commitment()
	hero.state = STATE_GROUND
	hero.velocity = Vector3.ZERO
	hero.sprinting = false
	var combat = hero.get(&"combat")
	if combat != null:
		combat.set(&"_parry_t", -1.0)
		combat.set(&"_swing_t", -1.0)
	# State is the behavioral assertion, but the previous dodge one-shot can
	# remain visible after the state is reset. Let that authored pose settle so a
	# later vendor frame cannot look like the button rolled when its state did not.
	await rig.wait_seconds(1.0)


func _stand_at(hero: Hero, at: Vector3, look: Vector3) -> void:
	hero.global_position = Vector3(at.x, 0.05, at.z)
	hero.velocity = Vector3.ZERO
	var heading: Vector3 = K.flat(look - hero.global_position).normalized()
	if heading != Vector3.ZERO:
		hero.facing_yaw = atan2(heading.x, heading.z)
		hero.rotation.y = hero.facing_yaw + PI


func _stand_clear(rig, hero: Hero) -> void:
	var garrison := rig.scene() as Garrison
	var at := garrison.vendor.global_position + Vector3(0.0, 0.0, 9.0)
	_stand_at(hero, at, at + (at - garrison.vendor.global_position))


func _watch_roll(rig, hero: Hero, act: Callable) -> bool:
	var seen := _is_rolling(hero)
	await act.call()
	for _i in 24:
		await rig.wait_frames(1)
		if _is_rolling(hero):
			seen = true
	return seen


func _is_rolling(hero: Hero) -> bool:
	return hero.state == Hero.MoveState.ROLL or hero.state == Hero.MoveState.ROLL_RECOVER


func _wait_for_focus(rig, expected: Node) -> bool:
	for _i in 50:
		if Prompt.focus == expected:
			return true
		await rig.wait_frames(2)
	return false


func _wait_for_no_focus(rig) -> bool:
	for _i in 50:
		if Prompt.focus == null:
			return true
		await rig.wait_frames(2)
	return false


func _wait_for_blocked(rig, wanted: bool) -> bool:
	for _i in 60:
		if Prompt.blocked == wanted:
			return true
		await rig.wait_frames(2)
	return false


func _close_screen(rig) -> void:
	if not Prompt.blocked:
		return
	await rig.tap(PAD_B)
	if not await _wait_for_blocked(rig, false):
		_fail("pad B could not close the active screen during reset")


func _tap_key(rig, code: int) -> void:
	await rig.wait_frames(1)
	_key(code, true)
	await rig.wait_physics_frames(2)
	_key(code, false)
	await rig.wait_physics_frames(1)


func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _check_key(label: String, code: int, owns: StringName, must_not_own: StringName) -> void:
	var actions := _actions_for_key(code)
	print("A-BTN key %s actions=%s" % [label, actions])
	if not actions.has(owns):
		_fail("%s is not bound to %s in the live InputMap" % [label, owns])
	if actions.has(must_not_own):
		_fail("%s is also bound to %s; the keyboard actions are no longer separate"
			% [label, must_not_own])


func _actions_for_key(code: int) -> Array[StringName]:
	var actions: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey \
					and (event as InputEventKey).physical_keycode == code:
				actions.append(action)
	return actions


func _fail(why: String) -> void:
	_fails += 1
	print("A-BTN FAIL %s" % why)
