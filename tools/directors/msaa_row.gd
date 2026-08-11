extends RefCounted
## Card #57, the other half — **what does the options menu actually offer?**
## `msaa_clamp.gd` proved the driver clamps 8x to 4x; this proves the row stopped
## pretending otherwise, on screen and under the player's own keys.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/msaa_row.gd \
##     --out=/tmp/msaa_row/x.png --size=1280x720 --warmup=50 \
##     --settings=user://msaa_row.cfg
##
## Every state change is an injected input event, per `critic_menu.gd`'s rule:
## the director reads the menu, it never drives it by calling methods on it.
## KEYBOARD events and not pad ones: `shoot.gd._deafen_the_gamepad` strips every
## joypad binding out of the InputMap for the life of a run (CLAUDE.md §3), so a
## director that presses pad buttons presses nothing and every beat fails on a
## menu that was working. That is what the first version of this file did.
##
## ## Both directions, per CLAUDE.md §2
##
## An assertion that "the row does not offer 8x" is worth nothing until it has
## been shown to fire when a row *does*. Beat D builds the pre-#57 row — the full
## four-name list — hands it to the same predicate, and requires a FAIL. A check
## that cannot fail is not a check.

const LIMIT := 32

var _pass := 0
var _fail := 0
var _shot_n := 0


func run(rig) -> void:
	var opts = Menu.get_node("Root/Screens/OptionsScreen")

	var vendor := RenderingServer.get_video_adapter_vendor()
	var cap: int = Settings.max_msaa()
	print("MSAAROW adapter=%s vendor=%s os=%s -> Settings.max_msaa()=%d"
		% [RenderingServer.get_video_adapter_name(), vendor, OS.get_name(), cap])

	# ------------------------------------------------- A. reach the GRAPHICS tab
	for i in LIMIT:
		if _is_btn(_foc(rig), "Options"):
			break
		await _key(rig, KEY_DOWN, 4)
	await _key(rig, KEY_ENTER, 14)
	_ck("A1 Enter opened Options", opts.visible)
	for i in LIMIT:
		if _is_btn(_foc(rig), "GRAPHICS"):
			break
		await _key(rig, KEY_RIGHT, 6)
	_ck("A2 Right reached the GRAPHICS tab", _is_btn(_foc(rig), "GRAPHICS"))
	await rig.wait_frames(8)
	await _shot(rig, "graphics_tab")

	# ------------------------------------------------------------ B. the row
	var row: MenuChoiceRow = _msaa_row(opts)
	if row == null:
		_ck("B1 the MSAA row exists", false)
		_report()
		return
	print("MSAAROW row '%s' offers %s" % [row.name, str(row.options)])
	_ck("B1 the row offers exactly the notches the GPU renders (%s)"
		% str(row.options), _honest(row.options, cap))

	# ------------------------------------------ C. cycling cannot reach a lie
	await _key(rig, KEY_ENTER, 10)          # confirm on the tab drops into content
	var on_row := false
	for i in LIMIT:
		if _foc(rig) == row:
			on_row = true
			break
		await _key(rig, KEY_DOWN, 4)
	_ck("C1 Down reached the MSAA row (%s)" % _nm(_foc(rig)), on_row)
	if on_row:
		# Walk it to the far end and past it. `MenuChoiceRow` clamps rather than
		# wraps, so this settles on the highest notch the row has.
		for i in 8:
			await _key(rig, KEY_RIGHT, 6)
		await rig.wait_frames(10)
		_ck("C2 cycling right settles at %d, not above the GPU's cap %d"
			% [Settings.msaa, cap], Settings.msaa == cap)
		await _shot(rig, "msaa_row_max")

	# --------------------------------- D. the check has to be able to fail (§2)
	#
	# The pre-#57 row, built here from the constant the panel slices, handed to
	# the same predicate. If this passes, B1 above was measuring nothing.
	var lying: Array[String] = MenuOptionsPanel.MSAA_NAMES.duplicate()
	_ck("D1 the SAME check FAILS on the pre-#57 four-notch row (%s)" % str(lying),
		cap >= MenuOptionsPanel.MSAA_NAMES.size() - 1 or not _honest(lying, cap))

	# ------------------------- E. a settings.cfg from an 8x-capable machine
	var was: int = Settings.msaa
	Settings.msaa = MenuOptionsPanel.MSAA_NAMES.size() - 1
	Settings.apply_video()
	_ck("E1 a stored msaa=%d is clamped to %d rather than left dangling"
		% [MenuOptionsPanel.MSAA_NAMES.size() - 1, Settings.msaa],
		Settings.msaa == cap)
	Settings.msaa = was
	Settings.apply_video()

	_report()


# --- Reading ------------------------------------------------------------------

## Is this list of notches honest about `cap`? It must end at the cap and it must
## not stop short of it.
func _honest(names: Array[String], cap: int) -> bool:
	return names.size() == cap + 1


func _msaa_row(from: Node) -> MenuChoiceRow:
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MenuChoiceRow and str(n.name).begins_with("row_anti"):
			return n as MenuChoiceRow
		for c in n.get_children():
			stack.append(c)
	return null


func _foc(rig) -> Control:
	return rig.root.gui_get_focus_owner()


func _nm(c: Control) -> String:
	return "null" if c == null else str(c.name)


func _is_btn(c: Control, label: String) -> bool:
	return c is Button and UiKit.label_of(c as Button) == label


# --- Driving ------------------------------------------------------------------

func _key(rig, code: int, frames: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code as Key
	down.physical_keycode = code as Key
	down.pressed = true
	Input.parse_input_event(down)
	await rig.wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code as Key
	up.physical_keycode = code as Key
	up.pressed = false
	Input.parse_input_event(up)
	await rig.wait_frames(frames)


func _shot(rig, tag: String) -> void:
	_shot_n += 1
	await rig.capture("%s/msaarow_%02d_%s.png"
		% [rig.arg("out", "/tmp/msaa_row/x.png").get_base_dir(), _shot_n, tag])


func _ck(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("MSAAROW %s %s" % ["PASS" if ok else "FAIL", what])


func _report() -> void:
	print("MSAAROW %d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		print("MSAAROW FAIL -- see the lines above")
