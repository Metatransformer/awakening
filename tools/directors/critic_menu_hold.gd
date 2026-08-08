extends RefCounted
## ROUND-2 CRITIC probe #2 — the things a pass/fail list does not cover.
##
## 1. HELD input. A real player holds the d-pad / stick / arrow key to drag a
##    slider. Injected taps hide whether the engine repeats a held pad input.
## 2. The Graphics and Game tabs, which the main audit never opens.

const LIMIT := 32
const PAD_A := 0
const PAD_B := 1
const PAD_DDOWN := 12
const PAD_DLEFT := 13
const PAD_DRIGHT := 14
const PAD_DUP := 11


func run(rig) -> void:
	var menu = rig.current_scene.get_node("PauseMenu")

	# root -> Options
	for i in LIMIT:
		if _is(_foc(rig), "Options"):
			break
		await _pad(rig, PAD_DDOWN, 4)
	await _pad(rig, PAD_A, 14)
	# down onto the Music row
	await _pad(rig, PAD_A, 10)
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.name == "row_music":
			break
		await _pad(rig, PAD_DDOWN, 4)
	print("focused row: %s  music=%.2f" % [_foc(rig).name, Settings.music_volume])

	# ---- 1a. HOLD the d-pad left for 90 frames (~1.5 s at 60 fps) ----------
	var v0: float = Settings.music_volume
	await _hold_pad(rig, PAD_DLEFT, 90)
	var v1: float = Settings.music_volume
	print("HOLD dpad-left 90 frames: %.3f -> %.3f  (delta %.3f, %d steps)"
		% [v0, v1, v0 - v1, roundi((v0 - v1) / 0.01)])

	# ---- 1b. HOLD the left stick left for 90 frames -------------------------
	var v2: float = Settings.music_volume
	await _hold_axis(rig, JOY_AXIS_LEFT_X, -1.0, 90)
	var v3: float = Settings.music_volume
	print("HOLD stick-left 90 frames: %.3f -> %.3f  (delta %.3f, %d steps)"
		% [v2, v3, v2 - v3, roundi((v2 - v3) / 0.01)])

	# ---- 1c. HOLD the arrow key (no OS echo when injected) ------------------
	var v4: float = Settings.music_volume
	await _hold_key(rig, KEY_LEFT, 90)
	var v5: float = Settings.music_volume
	print("HOLD key-left  90 frames: %.3f -> %.3f  (delta %.3f, %d steps)"
		% [v4, v5, v4 - v5, roundi((v4 - v5) / 0.01)])

	# ---- 1d. Does a HELD d-pad repeat FOCUS navigation? --------------------
	var before := _nm(_foc(rig))
	await _hold_pad(rig, PAD_DDOWN, 90)
	print("HOLD dpad-down 90 frames: focus %s -> %s" % [before, _nm(_foc(rig))])
	await rig.capture("h_01_after_holds.png")

	# ---- 2. the two tabs the main audit never opens -------------------------
	await _up_to_tabs(rig)
	for i in LIMIT:
		if _is(_foc(rig), "GRAPHICS"):
			break
		await _pad(rig, PAD_DRIGHT, 5)
	await rig.wait_frames(10)
	await rig.capture("h_02_graphics.png")
	# walk every row on this page and report what the pad lands on
	await _pad(rig, PAD_A, 10)
	for i in 8:
		print("   graphics row: %s" % _nm(_foc(rig)))
		await _pad(rig, PAD_DDOWN, 4)
	await rig.capture("h_03_graphics_walked.png")

	await _up_to_tabs(rig)
	for i in LIMIT:
		if _is(_foc(rig), "GAME"):
			break
		await _pad(rig, PAD_DRIGHT, 5)
	await rig.wait_frames(10)
	await rig.capture("h_04_game.png")

	# ---- 3. the fullscreen row: does a pad flick really resize the window? --
	await _pad(rig, PAD_A, 10)
	await _up_to_tabs(rig)
	for i in LIMIT:
		if _is(_foc(rig), "GRAPHICS"):
			break
		await _pad(rig, PAD_DLEFT, 5)
	await _pad(rig, PAD_A, 10)
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.name == "row_fullscreen":
			break
		await _pad(rig, PAD_DDOWN, 4)
	print("fullscreen row focused: %s ; mode before=%d Settings.fullscreen=%s"
		% [_nm(_foc(rig)), DisplayServer.window_get_mode(), Settings.fullscreen])
	await _pad(rig, PAD_DRIGHT, 16)
	print("after one D-pad RIGHT: window mode=%d Settings.fullscreen=%s"
		% [DisplayServer.window_get_mode(), Settings.fullscreen])
	await rig.capture("h_05_fullscreen_toggled.png")
	await _pad(rig, PAD_DLEFT, 16)
	print("after one D-pad LEFT : window mode=%d Settings.fullscreen=%s"
		% [DisplayServer.window_get_mode(), Settings.fullscreen])

	print("HOLDPROBE done")


# --- injection ---------------------------------------------------------------

func _pad(rig, btn: int, settle: int = 8) -> void:
	await _pad_set(rig, btn, true)
	await rig.wait_frames(2)
	await _pad_set(rig, btn, false)
	await rig.wait_frames(settle)


func _pad_set(rig, btn: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = btn
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _hold_pad(rig, btn: int, frames: int) -> void:
	await _pad_set(rig, btn, true)
	await rig.wait_frames(frames)
	await _pad_set(rig, btn, false)
	await rig.wait_frames(8)


func _hold_axis(rig, axis: int, value: float, frames: int) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await rig.wait_frames(frames)
	var z := InputEventJoypadMotion.new()
	z.device = 0
	z.axis = axis
	z.axis_value = 0.0
	Input.parse_input_event(z)
	await rig.wait_frames(8)


func _hold_key(rig, code: int, frames: int) -> void:
	var d := InputEventKey.new()
	d.keycode = code
	d.physical_keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await rig.wait_frames(frames)
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await rig.wait_frames(8)


# --- reading -----------------------------------------------------------------

func _foc(rig) -> Control:
	return rig.root.gui_get_focus_owner()


func _nm(c: Control) -> String:
	if c == null:
		return "<null>"
	if c is Button:
		return "%s '%s'" % [c.name, (c as Button).text]
	return String(c.name)


func _is(c: Control, label: String) -> bool:
	return c is Button and (c as Button).text == label


func _up_to_tabs(rig) -> void:
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.get_parent() != null and c.get_parent().name == "Tabs":
			return
		await _pad(rig, PAD_DUP, 4)
