extends RefCounted
## Proof director for the half of the pad fix that critic_menu.gd only checks
## indirectly: what a NON-cancel pad button does inside the "press a key"
## overlay. The Controls page says "Gamepad bindings are fixed", so pressing X
## in there must refuse and SAY so — not silently displace the pad binding.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://scripts/ui/menu/_pad_bind_probe.gd \
##     --out=/tmp/critic/pad/p.png --size=1280x720 --warmup=50 \
##     --settings=user://critic_scratch.cfg

const PAD_A := JOY_BUTTON_A
const PAD_X := JOY_BUTTON_X
const PAD_DDOWN := JOY_BUTTON_DPAD_DOWN
const PAD_DRIGHT := JOY_BUTTON_DPAD_RIGHT
const LIMIT := 30

var _n := 0


func run(rig) -> void:
	var menu = Menu
	var listen = Menu.get_node("Root/Listening")
	var notice = Menu.get_node("Root/Notice")

	# Root -> Options, by pad only.
	for i in LIMIT:
		var c := _focused(rig)
		if c is Button and (c as Button).text == "Options":
			break
		await _pad(rig, PAD_DDOWN, 4)
	await _pad(rig, PAD_A, 14)
	var opts = Menu.get_node("Root/Screens/OptionsScreen")
	_check("pad A alone opened Options", opts.visible)

	# Options -> Controls tab, by pad only.
	for i in LIMIT:
		var c := _focused(rig)
		if c is Button and (c as Button).text == "CONTROLS":
			break
		await _pad(rig, PAD_DRIGHT, 6)
	for i in LIMIT:
		var c := _focused(rig)
		if c != null and str(c.name).begins_with("bind_"):
			break
		await _pad(rig, PAD_DDOWN, 4)
	var row := _focused(rig)
	var action := StringName(str(row.name).substr(5))
	var pad_before := MenuUtil.pad_label(action)
	var key_before := Settings.label_for(action)
	_check("pad D-pad alone reached bind row %s (pad=%s key=%s)"
		% [action, pad_before, key_before], row != null)

	await _pad(rig, PAD_A, 12)
	_check("pad A opened the listen overlay", listen.visible)
	await _shot(rig, "listen_open")

	# The moment of truth: X is not cancel, so it is a binding attempt.
	await _pad(rig, PAD_X, 16)
	var msg: String = notice.get_child(0).text if notice.visible else ""
	print("   after pad X in listen: overlay=%s notice='%s'" % [listen.visible, msg])
	_check("pad X did NOT stick as a binding (pad column still %s)"
		% MenuUtil.pad_label(action), MenuUtil.pad_label(action) == pad_before)
	_check("keyboard binding untouched (%s)" % Settings.label_for(action),
		Settings.label_for(action) == key_before)
	_check("the overlay closed instead of waiting forever", not listen.visible)
	_check("the refusal is SHOWN: '%s'" % msg,
		msg == "Gamepad bindings cannot be changed.")
	await _shot(rig, "pad_bind_refused")
	_check("menu still open and usable after the refusal", menu.is_open)


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


func _focused(rig) -> Control:
	return rig.root.gui_get_focus_owner()


func _shot(rig, label: String) -> void:
	await rig.capture("p_%02d_%s.png" % [_n, label])
	_n += 1


func _check(what: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + what)
