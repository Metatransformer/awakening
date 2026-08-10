extends RefCounted
## Proves the thing the player actually complained about: pressing Escape in a
## REAL room opens the pause menu.
##
## The menu itself was already covered by tools/directors/critic_menu.gd, but
## that director drives scenes/ui/menu/_menu_test.tscn -- a harness that used to
## instance its own copy of pause_menu.tscn. So every check passed while the
## shipping game had no escape menu at all: the only PauseMenu in the project
## lived in the test scene. This director exists so that can never be true
## again. Point it at the garrison or dungeon, not at the harness.
##
## Run:
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/escape_in_game.gd \
##     --out=/tmp/esc/garrison.png --warmup=90

const KEY_ESC := 4194305  ## physical_keycode for Escape, as bound to `pause`.

var _fails := 0


func run(rig) -> void:
	# Closed on arrival. If the menu boots visible, every room in the game opens
	# behind a pause screen.
	_ck("A0 menu starts closed", not Menu.is_open)
	_ck("A1 tree starts unpaused", not rig.paused)
	await rig.capture("esc_00_before.png")

	# --- Escape opens it ------------------------------------------------------
	await _key(rig, KEY_ESC, 16)
	_ck("B0 Escape opened the menu", Menu.is_open)
	_ck("B1 Escape paused the tree", rig.paused)
	_ck("B2 the menu's Root Control is actually visible",
		Menu.get_node("Root").visible)
	_ck("B3 the root screen is the one showing",
		Menu.get_node("Root/Screens/RootScreen").visible)
	# A menu nothing is focused on is a menu the pad and keyboard cannot drive.
	var foc: Control = Menu.get_viewport().gui_get_focus_owner()
	_ck("B4 something is focused (%s)" % (foc.name if foc != null else "<null>"),
		foc != null)
	# The camera captures the pointer for look; the menu has to hand it back.
	_ck("B5 the mouse was released", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	await rig.capture("esc_01_open.png")

	# --- Escape closes it again -----------------------------------------------
	await _key(rig, KEY_ESC, 16)
	_ck("C0 Escape closed the menu", not Menu.is_open)
	_ck("C1 the tree resumed", not rig.paused)
	await rig.capture("esc_02_closed.png")

	# --- And it reopens. A menu that only works once is still broken. ---------
	await _key(rig, KEY_ESC, 16)
	_ck("D0 Escape reopened the menu", Menu.is_open)
	await rig.capture("esc_03_reopen.png")
	await _key(rig, KEY_ESC, 16)

	if _fails == 0:
		print("ESCAPE OK — all checks passed")
	else:
		print("ESCAPE FAIL — %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("ESCAPE FAIL %s" % label)


## Real InputEvents, not Input.action_press(): the pause menu listens in
## `_unhandled_input`, and action_press sets action state without dispatching an
## event, so _unhandled_input never runs (CLAUDE.md §3).
func _key(rig, code: int, settle: int = 8) -> void:
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
