extends RefCounted
## Every button the HUD names, said twice: once for a keyboard, once for a pad.
##
## Run it in TOWN, because town is the only room that draws the controls legend.
## It parks the hero at the PAWNBROKER itself rather than asking whoever runs it
## to stand somewhere first: the prompt bar is the surface most likely to be
## wrong -- it is the only one that composes a sentence around the glyph -- and a
## surface that is only under test when the operator remembers to walk over is
## not under test. Three surfaces, and they are the three that name inputs:
##
##   1. the key caps under the hands and the item cross;
##   2. the legend along the bottom;
##   3. the interact prompt above it.
##
## The device is flipped by pushing REAL events through `Input.parse_input_event`
## rather than by poking `Settings.using_pad`, because the thing most likely to
## be wrong is the watcher itself — its thresholds are what stop a resting stick
## or a bumped mouse from flipping the whole HUD mid-fight.
##
## Needs `--keep-pad`: shoot.gd strips joypad bindings by default and the caps
## are read from the live InputMap, so without it the pad frames come out blank.
##   godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn \
##       --director=res://tools/directors/pad_prompts.gd --keep-pad \
##       --out=/tmp/pad/x.png --warmup=60

## Actions whose cap has to differ between the two devices. `interact` is the
## one the prompt line prints, so it is the load-bearing one.
const WATCH := [&"attack", &"use_item", &"shield", &"context", &"interact",
	&"z_target", &"item_up", &"inventory"]

var _fail := 0
## The last thing the prompt bar was TOLD to say. Taken off the signal rather
## than rebuilt from `Glyph` here, because rebuilding it would only prove this
## file agrees with itself -- the wording lives in `Prompt._say_prompt`.
var _line := ""


func run(rig) -> void:
	Input.use_accumulated_input = false
	Bus.prompt_changed.connect(func(t: String) -> void: _line = t)
	await rig.wait_seconds(0.6)
	_stand_at_vendor(rig)
	await rig.wait_seconds(0.4)

	var keys := _caps()
	_check("keyboard", keys, false)
	_check_line("keyboard")
	await rig.capture("f_00_keyboard.png")

	# A face button. This is what a player pressing anything on a pad sends.
	_push(_pad_button(JOY_BUTTON_A))
	await rig.wait_seconds(0.25)
	var pad := _caps()
	_check("pad", pad, true)
	_check_line("pad")
	await rig.capture("f_01_pad.png")

	for action: StringName in WATCH:
		if keys.get(action, "") == pad.get(action, ""):
			_fail += 1
			print("PAD FAIL %s reads '%s' on both devices" % [action, keys.get(action, "")])
		if String(pad.get(action, "")).is_empty():
			_fail += 1
			print("PAD FAIL %s has no pad cap" % action)

	# Resting-stick drift must NOT count as the player reaching for the pad, and
	# the mirror of it: a nudged mouse must not throw the HUD back to keyboard
	# while a pad is in hand. Both of those are live bugs on a naive watcher.
	_push(_stick(JOY_AXIS_RIGHT_X, 0.18))
	_push(_mouse_move(Vector2(1.0, 0.0)))
	await rig.wait_seconds(0.2)
	if not Settings.using_pad:
		_fail += 1
		print("PAD FAIL drift threw the HUD back to the keyboard")
	await rig.capture("f_02_drift_ignored.png")

	# A real keypress does flip it back, and every cap has to follow.
	_push(_key(KEY_W))
	await rig.wait_seconds(0.25)
	if Settings.using_pad:
		_fail += 1
		print("PAD FAIL a keypress did not take the HUD back to the keyboard")
	if _caps() != keys:
		_fail += 1
		print("PAD FAIL the caps did not come back to what they were")
	# W is a MOVE key, so the press that flips the device also walks the hero off
	# the vendor. Let go and put him back before reading the prompt, or the beat
	# reports an empty line and blames the wording for a body that wandered.
	_push(_key(KEY_W, false))
	_stand_at_vendor(rig)
	await rig.wait_seconds(0.3)
	_check_line("back")
	await rig.capture("f_03_back_to_keyboard.png")

	print("PAD OK" if _fail == 0 else "PAD FAILED (%d)" % _fail)


func _caps() -> Dictionary:
	var out := {}
	for action: StringName in WATCH:
		out[action] = Glyph.cap(action)
	return out


func _check(what: String, caps: Dictionary, want_pad: bool) -> void:
	if Settings.using_pad != want_pad:
		_fail += 1
		print("PAD FAIL expected %s, Settings.using_pad = %s" % [what, Settings.using_pad])
	print("  %-8s %s" % [what, caps])


## The prompt bar, standing at the PAWNBROKER. Two things have to hold and they
## fail separately: the sentence has to be ABOUT the person ("TO TALK", not the
## shop's menu), and the glyph in front of it has to be the button on the device
## in hand -- which is exactly the pairing a hardcoded "(E)" got wrong.
func _check_line(what: String) -> void:
	if not _line.ends_with(" TO TALK"):
		_fail += 1
		print("PAD FAIL %s prompt reads '%s', wanted '<button> TO TALK'" % [what, _line])
	elif _line.begins_with(Glyph.cap(&"interact") + " "):
		print("  %-8s prompt '%s'" % [what, _line])
	else:
		_fail += 1
		print("PAD FAIL %s prompt reads '%s', but interact is on '%s'" % [
			what, _line, Glyph.cap(&"interact")])


## Park the hero in front of the vendor so there is a prompt to photograph.
## Teleported, not walked: pathing a body across town is a second thing that can
## fail and it is not the thing under test (the note in mvp_loop says the same).
func _stand_at_vendor(rig) -> void:
	var town := rig.scene() as Town
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D
	if town == null or hero == null:
		_fail += 1
		print("PAD FAIL not in town -- there is no vendor to stand at")
		return
	var at := town.vendor.global_position + Vector3(0.0, 0.0, 1.6)
	hero.global_position = Vector3(at.x, 0.05, at.z)


func _push(e: InputEvent) -> void:
	Input.parse_input_event(e)


func _pad_button(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.pressed = true
	return e


func _stick(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _mouse_move(rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.screen_relative = rel
	return e
