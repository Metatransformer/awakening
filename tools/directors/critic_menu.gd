extends RefCounted
## ROUND-2 CRITIC director. Written from scratch by the critic, not the builder.
##
## Rule of this file: every state change is caused by an INJECTED INPUT EVENT
## (keyboard key or gamepad button/axis). It never calls a method on the menu to
## make something happen — only to READ what happened. No mouse event is ever
## synthesized, not even a motion.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/critic_menu.gd \
##     --out=/tmp/critic2/burst/c.png --size=1280x720 --warmup=50 \
##     --settings=user://critic2.cfg

const LIMIT := 32

const PAD_A := 0
const PAD_B := 1
const PAD_X := 2
const PAD_Y := 3
const PAD_START := 6
const PAD_DUP := 11
const PAD_DDOWN := 12
const PAD_DLEFT := 13
const PAD_DRIGHT := 14

var _pass := 0
var _fail := 0
var _shot_n := 0


func run(rig) -> void:
	var menu = rig.current_scene.get_node("PauseMenu")
	var opts = rig.current_scene.get_node("PauseMenu/Root/Screens/OptionsScreen")
	var saves = rig.current_scene.get_node("PauseMenu/Root/Screens/SavesScreen")
	var confirm = rig.current_scene.get_node("PauseMenu/Root/Confirm")
	var listening = rig.current_scene.get_node("PauseMenu/Root/Listening")
	var notice = rig.current_scene.get_node("PauseMenu/Root/Notice")

	_dump_ui_actions("AFTER PauseMenu._ready()")

	# ============================================================ A. open state
	_ck("A1 menu open on ready", menu.is_open)
	_ck("A2 get_tree().paused == true", rig.paused)
	_ck("A3 CanvasLayer process_mode == ALWAYS (%d)" % menu.process_mode,
		menu.process_mode == Node.PROCESS_MODE_ALWAYS)
	_ck("A4 focus grabbed on open -> %s" % _nm(_foc(rig)), _foc(rig) != null)
	_ck("A5 mouse released on open (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _shot(rig, "root")

	# =============================================== B. LEFT STICK + A -> Options
	# A pad player mostly uses the stick, not the d-pad. Navigate with the
	# analogue axis only.
	var got := false
	for i in LIMIT:
		if _is_btn(_foc(rig), "Options"):
			got = true
			break
		await _axis(rig, JOY_AXIS_LEFT_Y, 1.0, 4)
	_ck("B1 left STICK alone reached 'Options' (%s)" % _nm(_foc(rig)), got)
	await _pad(rig, PAD_A, 14)
	_ck("B2 pad A opened Options", opts.visible)
	if not opts.visible:
		await _key(rig, KEY_ENTER, 14)   # fall back so the audit can continue
	await _shot(rig, "pad_options")

	# ==================================================== C. tab bar on the pad
	var tab0 := _nm(_foc(rig))
	await _pad(rig, PAD_DRIGHT, 12)
	await _pad(rig, PAD_DRIGHT, 12)
	var tab2 := _nm(_foc(rig))
	_ck("C1 D-pad right walked the tab bar (%s -> %s)" % [tab0, tab2], tab0 != tab2)
	await _shot(rig, "pad_tab_controls")

	# ========================================= D. rebind row + listen, pad only
	await _pad(rig, PAD_A, 12)          # confirm on a tab drops into the content
	var on_bind := false
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and str(c.name).begins_with("bind_"):
			on_bind = true
			break
		await _pad(rig, PAD_DDOWN, 4)
	_ck("D1 D-pad reached a rebind row (%s)" % _nm(_foc(rig)), on_bind)
	await _pad(rig, PAD_A, 12)
	_ck("D2 pad A opened the 'press a key' overlay", listening.visible)
	await _shot(rig, "pad_listen")
	await _pad(rig, PAD_B, 14)
	_ck("D3 pad B backed out of the overlay", not listening.visible)
	_ck("D4 pad B was NOT recorded / refused as a binding (notice='%s')"
		% _notice_text(notice), not notice.visible)
	await _shot(rig, "pad_listen_cancelled")
	# What DOES a non-B pad button do in there?
	await _pad(rig, PAD_A, 12)
	await _pad(rig, PAD_Y, 14)
	print("   probe: pad Y inside listen -> overlay=%s notice='%s'"
		% [listening.visible, _notice_text(notice)])
	if listening.visible:
		await _pad(rig, PAD_B, 12)

	# ============================================ E. slider -> the real AudioServer
	await _pad_up_to_tabs(rig)
	for i in LIMIT:
		if _is_btn(_foc(rig), "AUDIO"):
			break
		await _pad(rig, PAD_DLEFT, 5)
	_ck("E1 D-pad left returned to the AUDIO tab", _is_btn(_foc(rig), "AUDIO"))
	await _pad(rig, PAD_A, 12)
	var on_music := false
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.name == "row_music":
			on_music = true
			break
		await _pad(rig, PAD_DDOWN, 4)
	_ck("E2 D-pad reached the Music slider row", on_music)
	var bus := AudioServer.get_bus_index(&"Music")
	var db0 := AudioServer.get_bus_volume_db(bus)
	var v0: float = Settings.music_volume
	for i in 25:
		await _pad(rig, PAD_DLEFT, 2)
	await rig.wait_frames(8)
	var db1 := AudioServer.get_bus_volume_db(bus)
	_ck("E3 D-pad left moved Settings.music_volume (%.2f -> %.2f)"
		% [v0, Settings.music_volume], Settings.music_volume < v0 - 0.05)
	_ck("E4 the REAL AudioServer Music bus followed (%.1f dB -> %.1f dB)"
		% [db0, db1], db1 < db0 - 1.0)
	await _shot(rig, "pad_slider_music")
	for i in 60:
		await _pad(rig, PAD_DLEFT, 1)
	await rig.wait_frames(8)
	_ck("E5 slider at 0%% mutes the bus (vol=%.3f mute=%s)"
		% [Settings.music_volume, AudioServer.is_bus_mute(bus)],
		AudioServer.is_bus_mute(bus))
	await _shot(rig, "pad_slider_zero")

	# ================================================= F. conflicting rebind (kbd)
	await _pad_up_to_tabs(rig)
	for i in LIMIT:
		if _is_btn(_foc(rig), "CONTROLS"):
			break
		await _pad(rig, PAD_DRIGHT, 5)
	await _pad(rig, PAD_A, 10)
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.name == "bind_attack":
			break
		await _pad(rig, PAD_DDOWN, 4)
	var atk0: String = Settings.label_for(&"attack")
	await _pad(rig, PAD_A, 10)
	await _key(rig, KEY_K, 16)          # K belongs to Shield
	_ck("F1 conflicting rebind refused (attack still %s)"
		% Settings.label_for(&"attack"), Settings.label_for(&"attack") == atk0)
	_ck("F2 the refusal is SHOWN (notice visible=%s: '%s')"
		% [notice.visible, _notice_text(notice)],
		notice.visible and _notice_text(notice).length() > 0)
	await _shot(rig, "kb_rebind_conflict")
	await _pad(rig, PAD_A, 10)
	await _key(rig, KEY_N, 16)
	_ck("F3 a free key IS accepted (attack = %s)" % Settings.label_for(&"attack"),
		Settings.label_for(&"attack") == "N")
	await _shot(rig, "kb_rebind_accepted")

	# ================================== G. reset to defaults must not kill pad A
	for i in LIMIT:
		var c := _foc(rig)
		if c is Button and (c as Button).text == "Reset to Defaults":
			break
		await _pad(rig, PAD_DDOWN, 4)
	_ck("G1 D-pad reached 'Reset to Defaults'",
		_is_btn(_foc(rig), "Reset to Defaults"))
	await _pad(rig, PAD_A, 14)
	_ck("G2 reset restored attack to %s" % Settings.label_for(&"attack"),
		Settings.label_for(&"attack") == "J")
	_ck("G3 ui_accept still carries a pad button after reset_binds()",
		_has_joy(&"ui_accept"))
	await _shot(rig, "after_reset")

	# ==================================================== H. LOAD: empty slot
	await _pad(rig, PAD_B, 14)          # options -> root
	_ck("H0 pad B from Options returned to the ROOT screen (still open)",
		menu.is_open and rig.current_scene.get_node(
			"PauseMenu/Root/Screens/RootScreen").visible)
	for i in LIMIT:
		if _is_btn(_foc(rig), "Load Game"):
			break
		await _pad(rig, PAD_DDOWN, 4)
	await _pad(rig, PAD_A, 14)
	_ck("H1 pad A opened the Load screen", saves.visible)
	var empties := 0
	var locked := 0
	for card in _slots(saves):
		if card.is_empty:
			empties += 1
			if card.disabled and card.focus_mode == Control.FOCUS_NONE:
				locked += 1
	_ck("H2 empty slots locked in LOAD mode (%d/%d)" % [locked, empties],
		empties > 0 and locked == empties)
	# Actively try to land on one with the stick.
	var landed_empty := false
	for i in 14:
		await _axis(rig, JOY_AXIS_LEFT_Y, 1.0, 4)
		var c := _foc(rig)
		if c is MenuSlotRow and (c as MenuSlotRow).is_empty:
			landed_empty = true
		if c == null:
			break
	_ck("H3 stick never landed focus on an empty slot", not landed_empty)
	_ck("H4 focus never went null walking the Load screen", _foc(rig) != null)
	await _shot(rig, "pad_load")

	# ================================ I. SAVE + modal confirm, gamepad only
	await _pad(rig, PAD_B, 14)
	for i in LIMIT:
		if _is_btn(_foc(rig), "Save Game"):
			break
		await _pad(rig, PAD_DDOWN, 4)
	await _pad(rig, PAD_A, 14)
	_ck("I1 pad A opened the Save screen", saves.visible)
	# Focus lands on slot 1, which the harness already filled -> overwrite modal.
	await _pad(rig, PAD_A, 16)
	_ck("I2 pad A on a used slot raised the overwrite modal", confirm.is_asking)
	_ck("I3 modal starts focused on the SAFE answer (%s)" % _nm(_foc(rig)),
		_is_btn(_foc(rig), "Cancel"))
	await _shot(rig, "pad_confirm_overwrite")
	# A on the safe answer must resolve the modal -- proves A works in the modal.
	await _pad(rig, PAD_A, 16)
	_ck("I4 pad A dismissed the modal", not confirm.is_asking)
	# Now really do it: raise it again, D-pad LEFT onto Overwrite, A.
	await _pad(rig, PAD_A, 16)
	await _pad(rig, PAD_DLEFT, 8)
	var yes_focused := _is_btn(_foc(rig), "Overwrite")
	_ck("I5 D-pad reached the 'Overwrite' answer (%s)" % _nm(_foc(rig)), yes_focused)
	await _pad(rig, PAD_A, 20)
	_ck("I6 pad A committed the save (notice='%s')" % _notice_text(notice),
		not confirm.is_asking and notice.visible
			and _notice_text(notice).begins_with("Saved"))
	await _shot(rig, "pad_saved")

	# =============================================== J. close / reopen / mouse
	await _pad(rig, PAD_B, 14)          # saves -> root
	await _pad(rig, PAD_B, 16)          # root  -> closed
	_ck("J1 pad B at root closed the menu", not menu.is_open)
	_ck("J2 tree unpaused on close", not rig.paused)
	await _shot(rig, "closed")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await rig.wait_frames(6)
	await _pad(rig, PAD_START, 18)
	_ck("J3 pad START reopened the menu", menu.is_open)
	_ck("J4 mouse released on open (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_ck("J5 focus grabbed again on reopen (%s)" % _nm(_foc(rig)), _foc(rig) != null)
	await _shot(rig, "pad_reopened")
	await _pad(rig, PAD_START, 18)
	_ck("J6 pad START closed it again", not menu.is_open)
	_ck("J7 mouse CAPTURE restored on close (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	print("CRITIC2 %d passed, %d failed" % [_pass, _fail])


# --- injection ---------------------------------------------------------------

func _key(rig, code: int, settle: int = 6) -> void:
	var d := InputEventKey.new()
	d.keycode = code
	d.physical_keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await rig.wait_frames(2)
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await rig.wait_frames(settle)


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


func _axis(rig, axis: int, value: float, settle: int = 6) -> void:
	var d := InputEventJoypadMotion.new()
	d.device = 0
	d.axis = axis
	d.axis_value = value
	Input.parse_input_event(d)
	await rig.wait_frames(3)
	var u := InputEventJoypadMotion.new()
	u.device = 0
	u.axis = axis
	u.axis_value = 0.0
	Input.parse_input_event(u)
	await rig.wait_frames(settle)


# --- reading -----------------------------------------------------------------

func _foc(rig) -> Control:
	return rig.root.gui_get_focus_owner()


func _nm(c: Control) -> String:
	if c == null:
		return "<null>"
	if c is Button:
		return "%s '%s'" % [c.name, (c as Button).text]
	return String(c.name)


func _is_btn(c: Control, label: String) -> bool:
	return c is Button and (c as Button).text == label


func _notice_text(notice: Node) -> String:
	if notice == null or notice.get_child_count() == 0:
		return ""
	return notice.get_child(0).text


func _slots(n: Node) -> Array:
	var out: Array = []
	if n is MenuSlotRow:
		out.append(n)
	for c in n.get_children():
		out.append_array(_slots(c))
	return out


func _has_joy(action: StringName) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func _pad_up_to_tabs(rig) -> void:
	for i in LIMIT:
		var c := _foc(rig)
		if c != null and c.get_parent() != null and c.get_parent().name == "Tabs":
			return
		await _pad(rig, PAD_DUP, 4)
	_ck("could return to the tab bar on the D-pad", false)


func _dump_ui_actions(when: String) -> void:
	print("--- InputMap ui_* %s ---" % when)
	for a in ["ui_accept", "ui_cancel", "ui_select", "ui_left", "ui_right",
			"ui_up", "ui_down"]:
		var parts: Array = []
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				parts.append("KEY:%s" % OS.get_keycode_string((e as InputEventKey).keycode))
			elif e is InputEventJoypadButton:
				parts.append("JOYBTN:%d" % (e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion:
				parts.append("JOYAXIS:%d" % (e as InputEventJoypadMotion).axis)
			else:
				parts.append(e.get_class())
		print("    %-11s = %s" % [a, ", ".join(parts)])


func _shot(rig, label: String) -> void:
	_shot_n += 1
	await rig.capture("c_%02d_%s.png" % [_shot_n, label])


func _ck(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("FAIL %s" % what)
