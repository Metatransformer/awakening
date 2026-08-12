class_name MenuPageTabs
extends HBoxContainer
## The tab strip across the top of the three inspection screens — EQUIP,
## INVENTORY, MAP — and **the only thing that changes page**.
##
## **Why the three panels share one strip class rather than three headers.** A
## tab strip whose active tab is drawn one way on INVENTORY and another way on
## MAP is a strip the player stops trusting, and three copies of "which one is
## lit" is three chances to leave one behind when a fourth screen arrives. One
## class, one `set_active`, three instances.
##
## **The tabs take focus, and landing on one CHANGES THE PAGE.** Both halves of
## that are new (card #120) and both are forced by the same removal. This strip
## used to be `FOCUS_NONE` with an `LB ‹ … › RB` cap at either end, because the
## SHOULDERS paged and the stick moved inside the page — two jobs on two inputs,
## and a strip a pad could not reach was the correct shape for that arrangement.
## The owner asked for the shoulder ring to go (playtest 2026-08-12), and a
## `FOCUS_NONE` strip with no shoulders behind it is a strip a controller cannot
## use at all: the MAP panel's only other focusable control is its Back button,
## so a pad player who paged to MAP could never page off it.
##
## So the strip is where paging lives, and the mechanism is the one that costs
## the fewest presses once you are on it:
##
##   * **↑ out of the top of the page** lands on the lit tab (`link_body`).
##   * **← / →** walks the tabs and wraps, and each arrival IS the page change —
##     one press per page, the same as one shoulder press used to be.
##   * **↓** drops back into the page body, on the control ↑ came out of.
##   * A mouse still clicks a tab, which grabs focus and therefore takes the
##     same path. One mover, whichever device is driving.
##
## **Paging on FOCUS and not on A** is deliberate. Requiring a confirm makes a
## page change three presses (↑, →, A) instead of two, and there is nothing to
## confirm: a tab is not a verb, it is where you are, and the screen behind it
## is the only preview of it that could exist. `PauseMenu._go_page` keeps the
## focus ON the strip afterwards — see `focus_home` and `_paged_from_tabs` there
## — so the arrows keep paging until the player presses ↓.
##
## **This is not the double-mover trap** (CLAUDE.md §3, the `TradeScreen` row).
## That one polls `ui_left/right` in `_process` AND lets its cells take focus, so
## one press steps the cursor twice. Nothing in the pause menu polls the arrows:
## every panel here navigates by `focus_neighbor_*` alone, and this strip adds a
## reaction to focus rather than a second reader of the press.
##
## **Painted by explicit override, not by a theme variation.** The three screens
## moved onto `UITheme` one at a time, so for a while some of them rendered
## through `menu_theme.tres` and some through `UITheme.theme()`. A strip that got
## its look from a named variation would then have been lit one way on EQUIP and
## another on MAP — the exact thing the class note above says must never happen.
## Overrides are theme-independent, so the strip looked the same in both worlds
## and looks the same now that the last screen has converted.

## A tab was reached — by stick, by keyboard or by mouse. Carries a
## `PauseMenu.Screen` value: the strip is told which screens it lists, so it can
## hand back the one that was picked rather than an index the panel would have to
## translate.
signal picked(screen: int)

const SEP := 6
## The one line on screen that says the strip is navigable. It replaced the
## `Q ‹` / `› R` caps that named the shoulder buttons, and it is a caption rather
## than a glyph pair because what has to be taught is now a ROUTE (get onto the
## strip, then walk it) and not a button. Dim, at the far end, so it reads as
## instructions about the row rather than as a fourth tab.
const NAV_HINT := "↑  ← →  PAGE"


var _buttons: Array[Button] = []
var _screens: Array[int] = []
## The screen this strip's own panel draws. Every strip is `set_active`d to the
## CURRENT page, but only the current page's panel is visible — so on screen the
## lit tab is always this one, and it is where ↑ out of the body has to land.
var _home: int = -1
var _hint: Label
## True while `focus_home` is putting the cursor back after a page change. The
## `focus_entered` that lands is not a new request to page and must not be
## re-emitted as one — `PauseMenu._go_page` would ignore it anyway (same screen),
## but a signal that fires for a move the code made rather than the player is a
## signal the next reader will misread.
var _restoring := false


## `pages` is an Array of [screen: int, label: String] pairs, in ring order.
## `active` is this panel's own screen — see `_home`.
func setup(pages: Array, active: int) -> void:
	add_theme_constant_override(&"separation", SEP)
	_home = active
	for page: Array in pages:
		var b := Button.new()
		b.text = String(page[1])
		b.name = "Tab_%s" % String(page[1])
		# See the class note: focusable now, and arriving is the page change.
		b.focus_mode = Control.FOCUS_ALL
		var screen: int = int(page[0])
		b.pressed.connect(func() -> void: _report(screen))
		b.focus_entered.connect(func() -> void: _report(screen))
		add_child(b)
		_buttons.append(b)
		_screens.append(screen)
	# ← / → wrap around the three, so the ring the shoulders used to walk is
	# still a ring — it is just walked with the stick now.
	MenuUtil.chain_row(_buttons)
	# ↑ on the strip does nothing. There is nothing above it but the frame's
	# header, and an unset neighbour hands the move to Godot's spatial search,
	# which would find whatever the theme happens to put up there next.
	for b in _buttons:
		b.focus_neighbor_top = ^"."
	_hint = Label.new()
	_hint.name = "NavHint"
	_hint.text = NAV_HINT
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)
	set_active(active)


func _report(screen: int) -> void:
	if _restoring:
		return
	picked.emit(screen)


## Join the strip to the page under it. `row` is the panel's top row of
## focusables, landing target first (`PauseMenu` reads it off `tab_row()`).
##
## Called again after every `refresh()`, because two of the three panels rebuild
## their top row from the live bag and a link into a freed Button is a cursor
## that walks into nothing.
func link_body(row: Array) -> void:
	var entry: Control = null
	for c: Control in row:
		if c != null:
			entry = c
			break
	if entry == null:
		return
	var home := home_button()
	for b in _buttons:
		b.focus_neighbor_bottom = b.get_path_to(entry)
		b.focus_next = b.get_path_to(entry)
	if home == null:
		return
	for c: Control in row:
		if c == null:
			continue
		c.focus_neighbor_top = c.get_path_to(home)
		c.focus_previous = c.get_path_to(home)


## This panel's own tab — the lit one whenever this panel is the one on screen.
func home_button() -> Button:
	for i in _buttons.size():
		if _screens[i] == _home:
			return _buttons[i]
	return null


## Put the cursor back on this panel's tab after a page change, without that
## arrival being read as another page change. See `_restoring`.
func focus_home() -> void:
	var b := home_button()
	if b == null:
		return
	_restoring = true
	b.grab_focus()
	_restoring = false


func set_active(screen: int) -> void:
	for i in _buttons.size():
		_paint(_buttons[i], _screens[i] == screen)


## THE tab voice: no fill, ever. An idle tab is bare text, the live one is the
## same text lit and underlined. `UITheme.tab_box` owns the rule; this only says
## which of its three states a tab is in.
##
## The underline is HIGHLIGHT (off-white) rather than gold, and so is the live
## tab's label. Gold in this UI is TEXT that carries a VALUE — a price, a count,
## a kicker — and a lit tab is neither; it is where you are. Colouring it gold
## put the loudest colour on screen on the one thing the player already knows.
func _paint(b: Button, active: bool) -> void:
	b.add_theme_stylebox_override("normal",
		UITheme.tab_box("selected" if active else "unselected"))
	b.add_theme_stylebox_override("hover",
		UITheme.tab_box("selected" if active else "hovered"))
	b.add_theme_stylebox_override("pressed", UITheme.tab_box("selected"))
	# The focused tab is the lit one by construction — arriving on a tab is what
	# makes it the page — so `focus` cannot be told apart from `selected` by
	# WHICH tab it is on. It is told apart by the fill `tab_box("focused")` adds,
	# and that fill is load-bearing rather than decoration: with `focus` set to
	# `selected`'s box, the strip shot before and after ↑ out of the bag came back
	# byte-identical, so the one press that moves the cursor between "the arrows
	# move inside the page" and "the arrows change the page" showed the player
	# nothing at all.
	b.add_theme_stylebox_override("focus", UITheme.tab_box("focused"))
	b.add_theme_font_override("font", UITheme.display_font())
	b.add_theme_font_size_override("font_size", int(UITheme.TYPE_LABEL_MD["size"]))
	var idle: Color = UITheme.HIGHLIGHT if active else UITheme.TEXT_DIM
	b.add_theme_color_override("font_color", idle)
	b.add_theme_color_override("font_hover_color", UITheme.HIGHLIGHT)
	b.add_theme_color_override("font_pressed_color", UITheme.HIGHLIGHT)
	b.add_theme_color_override("font_focus_color", UITheme.HIGHLIGHT)
