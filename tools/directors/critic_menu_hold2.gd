extends RefCounted
## CRITIC probe #3 — nail the held-input asymmetry down.
## Longer holds, plus an explicit ECHO key event to show the keyboard HAS a
## repeat path that the pad has none of.

const LIMIT := 32
const PAD_A := 0
const PAD_DDOWN := 12
const PAD_DLEFT := 13


func run(rig) -> void:
	for i in LIMIT:
		var c := _foc(rig)
		if c is Button and (c as Button).text == "Options":
			break
		await _pad(rig, PAD_DDOWN, 4)
	await _pad(rig, PAD_A, 14)
	await _pad(rig, PAD_A, 10)
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.name == "row_master":
			break
		await _pad(rig, PAD_DDOWN, 4)
	print("row=%s master=%.3f" % [_foc(rig).name, Settings.master_volume])

	# 5 seconds of held d-pad-left.
	var a: float = Settings.master_volume
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = PAD_DLEFT
	e.pressed = true
	e.pressure = 1.0
	Input.parse_input_event(e)
	await rig.wait_frames(300)
	var u := InputEventJoypadButton.new()
	u.device = 0
	u.button_index = PAD_DLEFT
	u.pressed = false
	Input.parse_input_event(u)
	await rig.wait_frames(10)
	print("HELD d-pad LEFT for 300 frames (~5 s): %.3f -> %.3f  = %d steps"
		% [a, Settings.master_volume, roundi((a - Settings.master_volume) / 0.01)])

	# Now feed 30 ECHO key events, which is what a real held ARROW KEY produces
	# via OS key repeat. If these move the slider, the keyboard has a repeat
	# path and the pad simply does not.
	var b: float = Settings.master_volume
	var kd := InputEventKey.new()
	kd.keycode = KEY_LEFT
	kd.physical_keycode = KEY_LEFT
	kd.pressed = true
	Input.parse_input_event(kd)
	await rig.wait_frames(4)
	for i in 30:
		var ke := InputEventKey.new()
		ke.keycode = KEY_LEFT
		ke.physical_keycode = KEY_LEFT
		ke.pressed = true
		ke.echo = true
		Input.parse_input_event(ke)
		await rig.wait_frames(2)
	var ku := InputEventKey.new()
	ku.keycode = KEY_LEFT
	ku.physical_keycode = KEY_LEFT
	ku.pressed = false
	Input.parse_input_event(ku)
	await rig.wait_frames(10)
	print("30 keyboard ECHO events: %.3f -> %.3f = %d steps"
		% [b, Settings.master_volume, roundi((b - Settings.master_volume) / 0.01)])
	await rig.capture("h2_master.png")

	# How many presses does 100%%->0%% take on a pad? Count them.
	Settings.set_volume(&"Master", 1.0)
	await rig.wait_frames(6)
	var n := 0
	while Settings.master_volume > 0.0 and n < 250:
		await _pad(rig, PAD_DLEFT, 1)
		n += 1
	print("PAD PRESSES to take Master 100%% -> 0%%: %d" % n)
	await rig.capture("h2_zeroed.png")
	print("HOLD2 done")


func _pad(rig, btn: int, settle: int = 8) -> void:
	var d := InputEventJoypadButton.new()
	d.device = 0
	d.button_index = btn
	d.pressed = true
	d.pressure = 1.0
	Input.parse_input_event(d)
	await rig.wait_frames(2)
	var u := InputEventJoypadButton.new()
	u.device = 0
	u.button_index = btn
	u.pressed = false
	Input.parse_input_event(u)
	await rig.wait_frames(settle)


func _foc(rig) -> Control:
	return rig.root.gui_get_focus_owner()
