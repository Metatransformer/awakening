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
		b.theme_type_variation = &"MenuTab"
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
	l.theme_type_variation = &"MenuHint"
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
		_buttons[i].theme_type_variation = (
			&"MenuTabActive" if _screens[i] == screen else &"MenuTab")
