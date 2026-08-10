class_name MenuPageTabs
extends HBoxContainer
## The tab strip across the top of the three inspection screens — ITEMS, POUCH,
## MAP — and the only thing on screen that says the shoulder buttons page
## between them.
##
## **Why the three panels share one strip class rather than three headers.** A
## tab strip whose active tab is drawn one way on POUCH and another way on MAP
## is a strip the player stops trusting, and three copies of "which one is lit"
## is three chances to leave one behind when a fourth screen arrives. One class,
## one `set_active`, three instances.
##
## **The tabs are Buttons and they never take focus.** `FOCUS_NONE`, deliberately:
## each of these three screens already has a closed focus loop of its own (the
## bag grid, the two hands, the Back button) and a strip that could be reached
## with the stick would land a pad user in a row they then have to escape from
## downwards. The shoulder buttons page; the stick moves inside the page. Those
## are two different jobs and they stay on two different inputs. A mouse can
## still click a tab, because a mouse has no such loop to fall out of.
##
## The caps at either end are read from the LIVE InputMap through `Glyph`, the
## same way the HUD's key caps are. `ui_tab_prev` / `ui_tab_next` are registered
## at runtime by `PauseMenu._ensure_pad_ui_actions`, so the strip has to ask what
## they ended up bound to rather than print a remembered "LB".
##
## **Painted by explicit override, not by a theme variation.** The three screens
## moved onto `UITheme` one at a time, so for a while some of them rendered
## through `menu_theme.tres` and some through `UITheme.theme()`. A strip that got
## its look from a named variation would then have been lit one way on ITEMS and
## another on MAP — the exact thing the class note above says must never happen.
## Overrides are theme-independent, so the strip looked the same in both worlds
## and looks the same now that the last screen has converted.

## A tab was clicked. Carries a `PauseMenu.Screen` value — the strip is told
## which screens it lists, so it can hand back the one that was picked rather
## than an index the panel would have to translate.
signal picked(screen: int)

const SEP := 6


var _buttons: Array[Button] = []
var _screens: Array[int] = []
var _prev_cap: Label
var _next_cap: Label


## `pages` is an Array of [screen: int, label: String] pairs, in ring order.
func setup(pages: Array, active: int) -> void:
	add_theme_constant_override(&"separation", SEP)
	_prev_cap = _cap()
	add_child(_prev_cap)
	for page: Array in pages:
		var b := Button.new()
		b.text = String(page[1])
		# See the class note: clickable, never focusable.
		b.focus_mode = Control.FOCUS_NONE
		var screen: int = int(page[0])
		b.pressed.connect(func() -> void: picked.emit(screen))
		add_child(b)
		_buttons.append(b)
		_screens.append(screen)
	_next_cap = _cap()
	add_child(_next_cap)
	set_active(active)
	refresh_caps()


func _cap() -> Label:
	var l := Label.new()
	UITheme.apply_text_style(l, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Re-read the bindings. Called on setup and whenever the player picks up a pad,
## because "LB" and "Q" are the same button on two devices and the strip has to
## name the one in their hands (docs/CONTRACT.md §"the two ways this table has
## lied").
func refresh_caps() -> void:
	if _prev_cap == null:
		return
	var p := Glyph.cap(&"ui_tab_prev")
	var n := Glyph.cap(&"ui_tab_next")
	_prev_cap.text = ("%s ‹" % p) if not p.is_empty() else ""
	_next_cap.text = ("› %s" % n) if not n.is_empty() else ""


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
	# Never focused (FOCUS_NONE), but a focus stylebox left unset falls through
	# to the ambient theme's, which is a bordered box on one of the two themes
	# this strip has to live under.
	b.add_theme_stylebox_override("focus", UITheme.tab_box("unselected"))
	b.add_theme_font_override("font", UITheme.display_font())
	b.add_theme_font_size_override("font_size", int(UITheme.TYPE_LABEL_MD["size"]))
	var idle: Color = UITheme.HIGHLIGHT if active else UITheme.TEXT_DIM
	b.add_theme_color_override("font_color", idle)
	b.add_theme_color_override("font_hover_color", UITheme.HIGHLIGHT)
	b.add_theme_color_override("font_pressed_color", UITheme.HIGHLIGHT)
	b.add_theme_color_override("font_focus_color", idle)
