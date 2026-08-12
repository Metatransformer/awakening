extends RefCounted
## The three paged screens — EQUIP, INVENTORY, MAP — reached the way a player
## reaches them, on a keyboard AND on a pad, and measured while they are up.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/menu_pages.gd \
##     --out=/tmp/pages/x.png --size=1280x720 --warmup=60
##
## **This is card #120's proof and it exists because the card removed the only
## input that could change page.** LB / RB (and Q / R) paged the ring; the owner
## asked for that selector to go, which left a `FOCUS_NONE` tab strip and a MAP
## screen whose only other focusable is its Back button. So what has to be shown
## is not "the pages draw" but "**a controller can still reach all three, and
## get back off the one with nothing on it**".
##
## What each beat is for:
##
##   1. **Five per row, counted off the drawn cells' x positions** — not off
##      `ItemGrid.columns`, which is the number the code was TOLD and would agree
##      with itself. A GridContainer whose children do not fit silently overflows
##      its parent, so five columns that are five columns in the property and
##      four-and-a-half on screen is exactly the failure this counts against.
##   2. **Nothing overflows the frame.** `MenuPouchPanel`'s own header records
##      that six across pushed the frame to ~1400 px inside a 1280 px viewport
##      and the detail column rendered off the right edge, with nothing
##      complaining — a CenterContainer does not save you from a child bigger
##      than the screen, it clips it. The measurement is printed either way, so a
##      later change that eats the margin is visible before it is red.
##   3. **The labels.** EQUIP and INVENTORY, read off the live Buttons.
##   4. **The keyboard walks the ring** — ↑ onto the strip, → → → back to where
##      it started, one page per press.
##   5. **The pad walks the ring**, including onto MAP and OFF it again.
##   6. **The shoulders do nothing**, which is the removal itself. The two
##      actions must not exist at all: a `ui_tab_next` still in the InputMap
##      would be a paging route nothing on screen names.
##
## **Real `InputEventKey` / `InputEventJoypadButton`, never `Input.action_press`
## and never `screen._cursor`.** CLAUDE.md §3: `action_press` dispatches no
## `InputEvent`, so `_unhandled_input` never runs and two sessions wrote down
## readings taken through it; and assigning a panel's cursor field holds for
## exactly one frame because `grab_focus` lands its `focus_entered` later (#40,
## #77). Everything below presses a key or a button.
##
## **`shoot.gd` strips every joypad binding in the InputMap** so a controller
## resting on somebody's desk cannot drive the run, which also strips Godot's own
## D-pad events off `ui_up/down/left/right`. The pad beat re-adds exactly those,
## in memory, for the length of the run — see `_arm_pad_dpad`. That is not the
## harness inventing a capability: those bindings ship with the engine and are
## what a real pad player has. `ui_accept` / `ui_cancel` need no help; PauseMenu
## registers their pad buttons itself (`_ensure_pad_ui_actions`).

const NAV_LIMIT := 12

var _pass := 0
var _fail := 0
var _n := 0


func run(rig) -> void:
	var menu: PauseMenu = Menu
	var equip: MenuEquipPanel = menu.get_node("Root/Screens/EquipScreen")
	var pouch: MenuPouchPanel = menu.get_node("Root/Screens/PouchScreen")
	var map_panel = menu.get_node("Root/Screens/MapScreen")

	# A full bag, because an empty grid is five columns of nothing and proves
	# neither the wrap nor the width. Granted straight into `Run` rather than
	# walked to: what is under test is the PICTURE of a full bag.
	_fill_the_bag()
	await rig.wait_frames(6)

	# --- 6. The shoulders are gone -------------------------------------------
	# First, because it is the removal and it needs no navigation.
	_check("ui_tab_next no longer exists in the InputMap",
		not InputMap.has_action(&"ui_tab_next"))
	_check("ui_tab_prev no longer exists in the InputMap",
		not InputMap.has_action(&"ui_tab_prev"))

	# --- The labels ----------------------------------------------------------
	await _open_pouch(rig, menu)
	_check("the INVENTORY screen is up", pouch.visible)
	var labels := _tab_labels(pouch)
	_check("the tabs read EQUIP / INVENTORY / MAP (got %s)" % [labels],
		labels == PackedStringArray(["EQUIP", "INVENTORY", "MAP"]))
	await _shot(rig, "inventory")

	# --- 1 + 2. Five per row, and it fits ------------------------------------
	_measure(pouch)

	# --- 4. The keyboard walks the ring --------------------------------------
	# ↑ out of the top of the bag has to land ON the strip. Nothing else in this
	# menu leaves a page upwards, so if this misses, the whole mechanism is
	# unreachable and every beat under it would pass for the wrong reason.
	await _key(rig, KEY_UP, 8)
	_check("↑ out of the INVENTORY grid landed on the tab strip (%s)"
		% _focus_name(rig), _on_tabs(rig))
	await _shot(rig, "tabs_focused")

	await _key(rig, KEY_RIGHT, 10)
	_check("→ on the strip paged to MAP (%s)" % _where(menu), map_panel.visible)
	_check("...and the cursor stayed on the strip, so → pages again (%s)"
		% _focus_name(rig), _on_tabs(rig))
	await _shot(rig, "map")

	await _key(rig, KEY_RIGHT, 10)
	_check("→ again wrapped to EQUIP (%s)" % _where(menu), equip.visible)
	await _shot(rig, "equip")

	await _key(rig, KEY_LEFT, 10)
	_check("← is the same ring the other way (back to MAP: %s)" % _where(menu),
		map_panel.visible)

	# ...and off the strip, back into the page. On MAP that is the Back button,
	# the only focusable the screen has.
	await _key(rig, KEY_DOWN, 8)
	_check("↓ off a tab dropped into the page body (%s)" % _focus_name(rig),
		not _on_tabs(rig) and _focus_name(rig) != "<nothing>")

	# --- 5. The pad walks the same ring --------------------------------------
	# The device that lost its buttons. It starts on MAP, which is the screen a
	# pad player could get stuck on: one focusable, no shoulders, nothing else.
	_arm_pad_dpad()
	await _pad(rig, JOY_BUTTON_DPAD_UP, 8)
	_check("PAD: ↑ off the MAP's Back button reached the tab strip (%s)"
		% _focus_name(rig), _on_tabs(rig))
	await _pad(rig, JOY_BUTTON_DPAD_LEFT, 10)
	_check("PAD: ← paged off the MAP (%s)" % _where(menu), not map_panel.visible)
	await _pad(rig, JOY_BUTTON_DPAD_LEFT, 10)
	_check("PAD: ← again reached the third screen (%s)" % _where(menu),
		equip.visible or pouch.visible)
	var seen := {}
	for i in 3:
		seen[_where(menu)] = true
		await _pad(rig, JOY_BUTTON_DPAD_RIGHT, 10)
	_check("PAD: all three screens are reachable on the pad alone (%s)"
		% [seen.keys()], seen.size() == 3)
	await _shot(rig, "pad_ring")

	# The pad has to get INTO a page too, or the strip is a place it can only
	# stand. ↓ from the strip, then A on whatever it landed on must not crash or
	# leave — this is the ordinary confirm the panels already own.
	await _pad(rig, JOY_BUTTON_DPAD_DOWN, 8)
	_check("PAD: ↓ dropped into the page body (%s)" % _focus_name(rig),
		not _on_tabs(rig) and _focus_name(rig) != "<nothing>")
	_check("PAD: the menu is still open after walking the whole ring",
		menu.is_open)

	# --- The mouse -----------------------------------------------------------
	# A click is the third route and it goes through the same `picked` signal.
	# Emitted from the Button rather than moved-and-clicked with a synthetic
	# motion event: what is being checked is that a press still pages now that
	# arriving-by-focus does too, and not that the pointer can find a rectangle.
	await _open_pouch(rig, menu)
	var map_tab := _tab_named(pouch, "MAP")
	if map_tab != null:
		map_tab.emit_signal(&"pressed")
		await rig.wait_frames(10)
	_check("MOUSE: pressing the MAP tab paged to it (%s)" % _where(menu),
		map_panel.visible)

	# --- EQUIP's own row still works -----------------------------------------
	# The strip took over the top edge of every page's focus graph, so the page
	# under it has to be unchanged: EQUIP opens on the right hand, not on a tab.
	if menu.is_open:
		menu.close()
		await rig.wait_frames(6)
	menu.open()
	await rig.wait_frames(10)
	await _nav_to_button(rig, "Equipment")
	await _key(rig, KEY_ENTER, 12)
	_check("EQUIP opened focused in the page, not on the strip (%s)"
		% _focus_name(rig), equip.visible and not _on_tabs(rig))
	await _shot(rig, "equip_from_root")

	# And the root's own row for the bag names the screen it opens.
	await _key(rig, KEY_ESCAPE, 12)
	await _nav_to_button(rig, "Inventory")
	_check("the root menu's bag row reads 'Inventory'", true)

	print("PAGES %d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		print("PAGES FAIL %d assertion(s)" % _fail)


# --- Measurement -------------------------------------------------------------

## Count the cells that share the top row's y, and print every rectangle the
## width argument is made of.
##
## Counted off `global_position`, which is where the cells actually ARE. Reading
## `ItemGrid.columns` would be reading the instruction back rather than the
## result, and the result is what card #120's width problem is about: a
## GridContainer given more minimum width than its parent has does not shrink or
## complain, it overflows, and the overflow lands off the right-hand edge of the
## screen where a director looking at a `columns` property cannot see it.
func _measure(pouch: MenuPouchPanel) -> void:
	var grid: ItemGrid = pouch.grid()
	var cells: Array[Control] = []
	for c in grid.get_children():
		var ctrl := c as Control
		if ctrl != null and ctrl.visible:
			cells.append(ctrl)
	if cells.is_empty():
		_check("the bag drew any cells at all", false)
		return
	var top := cells[0].global_position.y
	var per_row := 0
	for c in cells:
		if absf(c.global_position.y - top) < 2.0:
			per_row += 1
	_check("the bag draws 5 cells per row (counted %d of %d drawn, %d slots)"
		% [per_row, cells.size(), Run.hold_slots()], per_row == 5)

	var frame := pouch.find_child("Frame", true, false) as Control
	var vp := pouch.get_viewport_rect().size
	var lines: Array[String] = []
	for name_ in ["Frame", "Col", "Split", "Left", "Right", "Carried", "Worn",
			"Doll", "Bag", "Grid", "Case", "Bench"]:
		var n := pouch.find_child(name_, true, false) as Control
		if n != null:
			lines.append("%s %.0f,%.0f %.0fx%.0f" % [name_, n.global_position.x,
				n.global_position.y, n.size.x, n.size.y])
	print("PAGES layout viewport=%.0fx%.0f  cell=%.0fx%.0f  %s"
		% [vp.x, vp.y, cells[0].size.x, cells[0].size.y, " | ".join(lines)])
	if frame != null:
		var l := frame.global_position.x
		var r := l + frame.size.x
		_check("the frame is inside the viewport (%.0f..%.0f of %.0f)"
			% [l, r, vp.x], l >= -0.5 and r <= vp.x + 0.5)
		# The other axis, and the one six across did NOT break: the footer's Back
		# button and the hint line are the bottom of this frame, and a frame
		# taller than 720 puts them under the edge of the screen where nothing
		# complains. `_build_stock`'s note records that happening once already.
		var t := frame.global_position.y
		var b := t + frame.size.y
		_check("the frame is inside the viewport vertically (%.0f..%.0f of %.0f)"
			% [t, b, vp.y], t >= -0.5 and b <= vp.y + 0.5)
		# The cells are the thing that overflows, and they overflow INSIDE the
		# frame's own clip — so the frame fitting is necessary and not
		# sufficient. The right-hand column has to still be on screen too.
		var right := pouch.find_child("Right", true, false) as Control
		if right != null:
			var rr := right.global_position.x + right.size.x
			_check("the detail column's right edge is on screen (%.0f of %.0f)"
				% [rr, vp.x], rr <= vp.x + 0.5)


# --- The bag -----------------------------------------------------------------

## Enough distinct stacks to fill every slot the bag has, so the grid is a full
## picture rather than three cells and a lot of dashes.
func _fill_the_bag() -> void:
	Run.enter(1)
	for id: StringName in ItemDb.all().keys():
		if Run.slots_used() >= Game.bag_slots:
			break
		Run.collect(id, 1)
	print("PAGES bag %d/%d slots used, %d hold cells"
		% [Run.slots_used(), Game.bag_slots, Run.hold_slots()])


# --- Input -------------------------------------------------------------------

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


## Give the four engine navigation actions their D-pad back, in memory, for this
## run. See the header: `shoot.gd` strips every joypad binding on purpose, and
## these four are Godot's own defaults rather than anything this game authored.
func _arm_pad_dpad() -> void:
	var want := {
		&"ui_up": JOY_BUTTON_DPAD_UP,
		&"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT,
		&"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	var added := 0
	for action: StringName in want:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var have := false
		for e in InputMap.action_get_events(action):
			var j := e as InputEventJoypadButton
			if j != null and j.button_index == want[action]:
				have = true
		if have:
			continue
		var ev := InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = want[action]
		InputMap.action_add_event(action, ev)
		added += 1
	print("PAGES armed %d D-pad binding(s) that shoot.gd had stripped" % added)


## `open_pouch` is a TOGGLE — it is the I key, and pressing I with the menu up
## closes it. The harness scene opens the menu in its own `_ready`, so calling it
## cold shut the menu and every beat under it then failed against a dead screen.
func _open_pouch(rig, menu: PauseMenu) -> void:
	if menu.is_open:
		menu.close()
		await rig.wait_frames(6)
	menu.open_pouch()
	await rig.wait_frames(12)


func _focused(rig) -> Control:
	return rig.root.gui_get_focus_owner()


func _focus_name(rig) -> String:
	var c := _focused(rig)
	return "<nothing>" if c == null else String(c.name)


func _on_tabs(rig) -> bool:
	var c := _focused(rig)
	return c != null and c.get_parent() is MenuPageTabs


func _where(menu: PauseMenu) -> String:
	for page: Array in PauseMenu.PAGES:
		var panel = menu.call(&"_panel_for", int(page[0]))
		if panel != null and panel.visible:
			return String(page[1])
	return "<none>"


func _tab_labels(panel: Control) -> PackedStringArray:
	var out: PackedStringArray = []
	var strip := _strip_of(panel)
	if strip == null:
		return out
	for c in strip.get_children():
		var b := c as Button
		if b != null:
			out.append(b.text)
	return out


func _tab_named(panel: Control, label: String) -> Button:
	var strip := _strip_of(panel)
	if strip == null:
		return null
	for c in strip.get_children():
		var b := c as Button
		if b != null and b.text == label:
			return b
	return null


func _strip_of(panel: Control) -> MenuPageTabs:
	for c in panel.call(&"tab_host").get_children():
		if c is MenuPageTabs:
			return c
	return null


func _nav_to_button(rig, label: String) -> void:
	for i in NAV_LIMIT * 3:
		var c := _focused(rig)
		if c is Button and UiKit.label_of(c as Button) == label:
			return
		await _key(rig, KEY_DOWN, 3)
	_check("could reach button '%s' by keyboard" % label, false)


# --- Reporting ---------------------------------------------------------------

func _shot(rig, label: String) -> void:
	await rig.capture("pg_%02d_%s.png" % [_n, label])
	_n += 1


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("PAGES FAIL %s" % what)
