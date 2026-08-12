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
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/escape_in_game.gd \
##     --out=/tmp/esc/garrison.png --warmup=90

const KEY_ESC := 4194305  ## physical_keycode for Escape, as bound to `pause`.
const KEY_I := 73         ## `inventory` — opens straight onto the pouch.
const KEY_M := 77         ## `map` — opens straight onto the map.
const KEY_E := 69         ## `interact` in the world, CONFIRM in every menu.
const KEY_DOWN := 4194322
## The tab strip's arrows. Q and R used to be here as `ui_tab_prev` /
## `ui_tab_next`; card #120 removed the shoulder ring and both keys with it, and
## paging is now ↑ onto the strip then ← / →.
const KEY_UP := 4194320
const KEY_LEFT := 4194319
const KEY_RIGHT := 4194321

## How many rows down the root list to hunt for one by name before giving up.
const ROW_LIMIT := 10

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

	await _one_press_screens(rig)
	await _e_confirms(rig)
	await _mouse(rig)
	await _over_a_screen(rig)

	if _fails == 0:
		print("ESCAPE OK — all checks passed")
	else:
		print("ESCAPE FAIL — %d check(s) failed" % _fails)


## **THE BUG THIS FILE WAS EXTENDED FOR.** A screen you reach in ONE press has
## nothing under it, so the press you use to LEAVE must leave.
##
## It used to pop onto the pause root instead: `open_pouch` called `open()` —
## which seeds the stack with ROOT — and then pushed INVENTORY on top, so Escape
## found two entries and walked you back onto a menu you never asked for.
func _one_press_screens(rig) -> void:
	await _key(rig, KEY_I, 16)
	_ck("E0 I opened the menu", Menu.is_open)
	_ck("E1 ...straight onto the pouch",
		Menu.get_node("Root/Screens/PouchScreen").visible)
	await rig.capture("esc_04_pouch.png")
	await _key(rig, KEY_ESC, 16)
	_ck("E2 Escape out of the pouch CLOSED the menu", not Menu.is_open)
	_ck("E3 ...it did not land on the pause root",
		not Menu.get_node("Root/Screens/RootScreen").visible)
	_ck("E4 the tree resumed", not rig.paused)

	await _key(rig, KEY_M, 16)
	_ck("F0 M opened straight onto the map",
		Menu.is_open and Menu.get_node("Root/Screens/MapScreen").visible)
	# The ring is EQUIP / INVENTORY / MAP / GARRISON and it is walked on the TAB STRIP now
	# (card #120): ↑ out of the page lands on the lit tab, → is the next page.
	# From the MAP that moves forward to GARRISON and ← comes back.
	await _key(rig, KEY_UP, 16)
	await _key(rig, KEY_RIGHT, 16)
	_ck("F1 the strip pages forward off the map",
		Menu.get_node("Root/Screens/GarrisonScreen").visible)
	await _key(rig, KEY_LEFT, 16)
	_ck("F2 ← pages back to it",
		Menu.get_node("Root/Screens/MapScreen").visible)
	await rig.capture("esc_05_map.png")
	# Paging REPLACES the top of the stack, so the one-press contract has to
	# survive a lap of the ring.
	await _key(rig, KEY_ESC, 16)
	_ck("F3 Escape after paging still CLOSED the menu", not Menu.is_open)


## E confirms, the way Enter and pad A do — and the screen stack still works
## when you got there the long way, through the root menu.
func _e_confirms(rig) -> void:
	await _key(rig, KEY_ESC, 16)
	if not await _focus_row(rig, "Inventory"):
		_ck("G0 could reach the 'Inventory' row on the root menu", false)
		await _key(rig, KEY_ESC, 16)
		return
	_ck("G0 could reach the 'Inventory' row on the root menu", true)
	await _key(rig, KEY_E, 16)
	_ck("G1 E confirmed the row (E is the world's interact key)",
		Menu.get_node("Root/Screens/PouchScreen").visible)
	await rig.capture("esc_06_e_confirm.png")
	# Reached FROM the root, so the root is where you came from and Escape owes
	# you a step back onto it — the opposite of the I/M case above.
	await _key(rig, KEY_ESC, 16)
	_ck("G2 Escape stepped back to the root, menu still open",
		Menu.is_open and Menu.get_node("Root/Screens/RootScreen").visible)
	await _key(rig, KEY_ESC, 16)
	_ck("G3 ...and the next Escape closed it", not Menu.is_open)


## The pointer is the right stick. It is captured while you play and handed back
## for exactly as long as a screen is up.
##
## The harness never grabs the cursor itself (GameCamera checks for a scripted
## SceneTree), so the capture is staged here. That is the whole test: the bug was
## that GameCamera released the pointer on `pause` BEFORE the menu — unhandled
## input runs deepest-first and the menu is an autoload — so the menu recorded
## "visible" as the state to restore and the mouse never came back.
func _mouse(rig) -> void:
	# **Setting the mode is only half the stage, and H1 failed for months on the
	# other half.** `GameCamera._ready` computes `may_capture = capture_mouse and
	# get_tree().get_script() == null`, which is false under every director, so the
	# camera declines to RE-take the pointer when the menu hands it back -- and H1
	# is exactly the assertion that it comes back. H0 passed because releasing needs
	# nobody's permission. So the fixture has to opt the camera in, the same way
	# `mouse_cursor.gd:57` and `p1_orbit.gd` already do; a red H1 was the harness
	# refusing to let the game do the thing being measured.
	var cam := rig.scene().get_viewport().get_camera_3d() as GameCamera
	if cam == null:
		_ck("H- there is a GameCamera to hand the pointer back to", false)
		return
	cam.may_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await rig.wait_frames(2)
	await _key(rig, KEY_ESC, 16)
	_ck("H0 opening released the pointer (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _key(rig, KEY_ESC, 16)
	_ck("H1 closing gave CAPTURE back (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	# Put the opt-in back where `_ready` left it before handing the run on. The
	# beats after this one press Escape too, and a camera left free to grab would
	# take the pointer between them -- which on this Mac means the harness window
	# swallowing the owner's mouse, the thing `may_capture` exists to prevent.
	cam.may_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await rig.wait_frames(2)


## One press, one response. The shop and the stash both close on `ui_cancel` OR
## `pause`, and Escape is bound to both — so the press that closed the vendor
## used to open the pause menu behind it in the same frame.
func _over_a_screen(rig) -> void:
	var shop = TradeScreen.open(rig.scene(), TradeScreen.Mode.TRADE, "TEST STALL",
		SupplyDb, &"", "Trade", SupplyDb.STOCK_IDS)
	await rig.wait_frames(12)
	_ck("I0 the shop is up", is_instance_valid(shop) and shop.is_inside_tree())
	_ck("I1 it took the pointer (mode=%d)" % Input.mouse_mode,
		Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	await rig.capture("esc_07_shop.png")

	await _key(rig, KEY_ESC, 24)
	_ck("I2 Escape closed the shop", not is_instance_valid(shop)
		or not shop.is_inside_tree())
	_ck("I3 ...and did NOT open the pause menu behind it", not Menu.is_open)
	await rig.capture("esc_08_shop_closed.png")
	if Menu.is_open:
		await _key(rig, KEY_ESC, 16)


## Walk the root list with the arrow keys until the focused control SAYS `label`.
## Returns false if it never lands on one, which is a real failure and not a
## flaky director: the list is a closed focus loop.
##
## Through `UiKit.label_of` and not `Button.text`. A root row is a composed
## VerbRow whose own `text` is empty — its label is a child Label — so matching
## on `.text` finds nothing at all. The kit ships this reader for exactly that.
func _focus_row(rig, label: String) -> bool:
	for i in ROW_LIMIT:
		# Annotated: `rig` is untyped, so `rig.root` is a Variant and `:=` cannot
		# infer (CLAUDE.md §3).
		var c: Control = rig.root.gui_get_focus_owner()
		if c != null and UiKit.label_of(c) == label:
			return true
		await _key(rig, KEY_DOWN, 6)
	return false


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
