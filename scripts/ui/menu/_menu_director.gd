extends RefCounted
## Director for tools/shoot.gd (docs/CONTRACT.md §9). Drives the pause menu with
## nothing but injected KEYBOARD events — no mouse, no direct method calls on the
## menu — and captures a frame at every state worth arguing about.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://scripts/ui/menu/_menu_director.gd \
##     --out=/abs/out/f.png --size=1280x720 --warmup=60
##
## THIS DIRECTOR MUTATES SETTINGS ON PURPOSE — it drags the Music slider to the
## floor and rebinds `attack` onto N — and both of those used to land in the
## player's real `user://settings.cfg`, because `Settings.rebind()` saves. That
## is how the sword died on RB: shoot.gd strips the pad bindings for the run, so
## the saved `attack` had no pad event left in it, and every later boot replayed
## a keyboard-only bind over the shipped one. shoot.gd now sandboxes
## `Settings.path` for every run, so this is safe by construction and needs no
## flag here. Do not "helpfully" make these steps read-only — proving the rebind
## flow actually rebinds is what the director is for.
##
## Every navigation step goes through Input.parse_input_event(), so the InputMap,
## the focus graph and the pause state are all exercised for real. Assertions
## print PASS/FAIL lines to stdout — a menu that looks right in a screenshot but
## does not actually pause the tree is still broken.

const NAV_LIMIT := 40

var _pass := 0
var _fail := 0
var _shots: Array[String] = []


func run(rig) -> void:
	var menu: PauseMenu = Menu

	# --- Root -----------------------------------------------------------------
	_check("menu opened on ready", menu.is_open)
	_check("tree is paused while the menu is up", rig.paused)
	await _shot(rig, "01_root.png")

	# --- Options: Audio -------------------------------------------------------
	await _nav_to_button(rig, "Options")
	await _key(rig, KEY_ENTER, 10)
	await _shot(rig, "02_options_audio.png")

	# Down out of the tab bar and onto the Master row, then drag it left with the
	# arrow keys — this is the whole "slider shows its value" claim, by keyboard.
	await _nav_down_to(rig, "row_music")
	for i in 14:
		await _key(rig, KEY_LEFT, 2)
	await rig.wait_frames(6)
	_check("Music volume moved through Settings (%.2f)" % Settings.music_volume,
		Settings.music_volume < 0.6)
	_check("the bus followed the slider",
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
			< linear_to_db(0.6))
	await _shot(rig, "03_options_audio_slider.png")

	# --- Options: Graphics ----------------------------------------------------
	await _nav_up_to_tabs(rig)
	await _key(rig, KEY_RIGHT, 10)
	await _shot(rig, "04_options_graphics.png")

	# --- Options: Controls ----------------------------------------------------
	await _key(rig, KEY_RIGHT, 10)
	await _shot(rig, "05_options_controls.png")

	# Rebind Attack onto a key another action ALREADY OWNS. Settings.rebind()
	# answers false; the menu has to SAY so rather than quietly doing nothing.
	#
	# The owned key is looked up, not hardcoded, because a hardcoded one rots
	# into a test that passes vacuously. This step used to press K "which Shield
	# already owns" — shield's keyboard binding had since become Mouse2, nothing
	# owned K, so the rebind was correctly ACCEPTED and the assertion had been
	# testing the layout rather than the conflict rule. If no rebindable action
	# owns a key at all, that is reported as its own failure: a silent skip here
	# is indistinguishable from a pass.
	var taken := _a_key_owned_by_another_action(&"attack")
	_check("there is a key owned by another action to collide with", taken != KEY_NONE)
	var attack_before: String = Settings.label_for(&"attack")
	await _nav_down_to(rig, "bind_attack")
	await _key(rig, KEY_ENTER, 8)
	await _shot(rig, "06_rebind_listening.png")
	await _key(rig, taken, 10)
	_check("conflicting rebind on %s was refused (attack still %s)"
			% [OS.get_keycode_string(taken), Settings.label_for(&"attack")],
		Settings.label_for(&"attack") == attack_before)
	await _shot(rig, "07_rebind_conflict.png")

	# Now a key nobody owns.
	await _key(rig, KEY_ENTER, 8)
	await _key(rig, KEY_N, 12)
	_check("free key was accepted (attack = %s)" % Settings.label_for(&"attack"),
		Settings.label_for(&"attack") == "N")
	await _shot(rig, "08_rebind_accepted.png")

	# --- Options: Game --------------------------------------------------------
	await _nav_up_to_tabs(rig)
	await _key(rig, KEY_RIGHT, 10)
	await _shot(rig, "09_options_game.png")

	# --- Cancel backs out ONE level -------------------------------------------
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape from Options returned to the root menu, not out of the menu",
		menu.is_open)
	await _shot(rig, "10_back_to_root.png")

	# --- Saves: save mode -----------------------------------------------------
	await _nav_to_button(rig, "Save Game")
	await _key(rig, KEY_ENTER, 12)
	await _shot(rig, "11_saves_save.png")

	# Slot 1 already holds a save, so confirm first.
	await _key(rig, KEY_ENTER, 12)
	await _shot(rig, "12_confirm_overwrite.png")
	await _key(rig, KEY_ESCAPE, 10)   # answer "no"
	await _key(rig, KEY_ESCAPE, 12)   # back to root

	# --- Saves: load mode -----------------------------------------------------
	await _nav_to_button(rig, "Load Game")
	await _key(rig, KEY_ENTER, 12)
	var saves: Node = Menu.get_node("Root/Screens/SavesScreen")
	_check("empty slot is unreachable in Load mode", _empty_slot_locked(saves))
	await _shot(rig, "13_saves_load.png")

	# Right off a slot reaches its Erase button; erasing asks first, and starts
	# focused on the safe answer.
	await _key(rig, KEY_RIGHT, 6)
	await _key(rig, KEY_ENTER, 12)
	await _shot(rig, "13b_confirm_erase.png")
	await _key(rig, KEY_ESCAPE, 10)   # answer "keep"
	await _key(rig, KEY_ESCAPE, 12)

	# --- Close, and give the pointer back -------------------------------------
	# Pretend the camera rig owns the mouse, the way it will in game.
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape at root closed the menu", not menu.is_open)
	_check("tree resumed on close", not rig.paused)
	await _shot(rig, "14_closed.png")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await rig.wait_frames(4)
	await _key(rig, KEY_ESCAPE, 14)
	_check("menu reopened with Escape", menu.is_open)
	_check("mouse released on open", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _shot(rig, "15_reopened.png")

	# The music slider must still be where we left it two screens and one close
	# ago — the screen re-reads Settings, it does not cache.
	await _nav_to_button(rig, "Options")
	await _key(rig, KEY_ENTER, 12)
	# Options reopens on the tab you left it on, so walk the tab bar back to
	# Audio with the arrow keys before looking for the Music row.
	await _nav_up_to_tabs(rig)
	await _nav_to_tab(rig, "Audio")
	await _nav_down_to(rig, "row_music")
	_check("music value survived close + reopen (%.2f)" % Settings.music_volume,
		Settings.music_volume < 0.6)
	await _shot(rig, "16_values_persisted.png")

	await _key(rig, KEY_ESCAPE, 10)
	await _key(rig, KEY_ESCAPE, 14)
	# THE MENU DOES NOT PUT THE POINTER BACK, and that is the fix rather than the
	# regression. It used to restore what it found on the way in, which is how
	# mouse look died the first time (`GameCamera._settle_pointer` tells the
	# whole story). The way back is derived from what is still up and belongs to
	# the camera — and THIS SCENE HAS NO CAMERA, so the honest assertion here is
	# that closing left the cursor free rather than that something re-took it.
	# `tools/directors/mouse_cursor.gd` is where the real path is proved, in the
	# garrison, with a camera in it.
	_check("the menu left the pointer free (nothing here wants it)",
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	print("DIRECTOR %d passed, %d failed" % [_pass, _fail])
	print("DIRECTOR_SHOTS %s" % ", ".join(_shots))


# --- Keyboard-only navigation -----------------------------------------------

## Inject a real key press+release. Both keycode and physical_keycode are set so
## the ui_* actions (keycode-bound) and the game actions (physical-bound) both
## see it, exactly as a real keyboard would.
func _key(rig, code: int, settle: int = 6) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await rig.wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await rig.wait_frames(settle)


func _focused(rig) -> Control:
	return rig.root.gui_get_focus_owner()


## Walk DOWN until a Button with this text has focus.
func _nav_to_button(rig, label: String) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c is Button and UiKit.label_of(c as Button) == label:
			return
		await _key(rig, KEY_DOWN, 3)
	_check("could reach button '%s' by keyboard" % label, false)


## Walk DOWN until the node with this name has focus.
func _nav_down_to(rig, node_name: String) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c != null and c.name == node_name:
			return
		await _key(rig, KEY_DOWN, 3)
	_check("could reach row '%s' by keyboard" % node_name, false)


## Walk RIGHT along the tab bar until the named tab has focus.
func _nav_to_tab(rig, label: String) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c is Button and UiKit.label_of(c as Button) == label:
			return
		await _key(rig, KEY_RIGHT, 4)
	_check("could reach the '%s' tab by keyboard" % label, false)


## Walk UP until focus is back on the options tab bar.
func _nav_up_to_tabs(rig) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c != null and c.get_parent() != null and c.get_parent().name == "Tabs":
			return
		await _key(rig, KEY_UP, 3)
	_check("could return to the tab bar by keyboard", false)


func _empty_slot_locked(saves: Node) -> bool:
	for card in _find_slots(saves):
		if card.is_empty:
			if not card.disabled or card.focus_mode != Control.FOCUS_NONE:
				return false
	return true


func _find_slots(n: Node) -> Array:
	var out: Array = []
	if n is MenuSlotRow:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_slots(c))
	return out


# --- Reporting --------------------------------------------------------------

func _shot(rig, name: String) -> void:
	await rig.capture(name)
	_shots.append(name)


## A physical keycode currently bound to some rebindable action other than
## `mine` — i.e. one `Settings.rebind()` is obliged to refuse. KEY_NONE if the
## layout has no keyboard binding to collide with at all.
##
## Only keys count. The conflict rule is per device class, so offering it a
## mouse button or a pad face button would test the wrong branch — and under
## shoot.gd the pad bindings are stripped anyway.
func _a_key_owned_by_another_action(mine: StringName) -> Key:
	for action in Settings.rebindable_actions():
		if action == mine:
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				return (e as InputEventKey).physical_keycode
	return KEY_NONE


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("FAIL %s" % what)
