class_name MenuOptionsPanel
extends Control
## The Options screen: Audio / Graphics / Controls / Game.
##
## It owns no state. Every widget reads its value out of `Settings` when the
## screen opens and writes straight back through the Settings API — this panel
## never touches AudioServer, the window, or the InputMap itself
## (docs/CONTRACT.md §8). That is also why values survive close-and-reopen: on
## open we re-read, we never cache.
##
## Tabs activate on FOCUS, not on confirm, so a pad user sweeping left/right
## along the tab bar sees the page change under them.

signal back_requested
signal rebind_requested(action: StringName)
signal notice(text: String, is_error: bool)
## A row settled on a value — the menu answers with a click on the UI bus.
signal value_settled

enum Tab { AUDIO, GRAPHICS, CONTROLS, GAME }

const TAB_NAMES: Array[String] = ["AUDIO", "GRAPHICS", "CONTROLS", "GAME"]

const MSAA_NAMES: Array[String] = ["Off", "2x", "4x", "8x"]
const SHADOW_NAMES: Array[String] = ["Off", "Low", "Medium", "High"]
const ONOFF: Array[String] = ["Off", "On"]

const HINT := "↑↓ / D-pad Select    ←→ Adjust    E / A Confirm    Esc / B Back"

var _tab := Tab.AUDIO
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _back: Button
var _rows: Array[Control] = []
## The one caption on this screen that repaints without a rebuild. See
## `_build_game`'s mercy row.
var _mercy_says: Label = null
var _bind_rows: Array[MenuBindRow] = []
var _applying := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chrome()
	Settings.changed.connect(_on_settings_changed)
	_set_tab(Tab.AUDIO, true)


# --- Chrome -----------------------------------------------------------------

func _build_chrome() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	# Header
	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"MenuTitle"
	title.text = "OPTIONS"
	header.add_child(title)

	# Tab bar
	var tab_pad := MarginContainer.new()
	tab_pad.theme_type_variation = &"MenuTabPad"
	col.add_child(tab_pad)
	var bar := HBoxContainer.new()
	bar.name = "Tabs"
	bar.theme_type_variation = &"MenuTabBar"
	tab_pad.add_child(bar)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.theme_type_variation = &"MenuTab"
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.focus_entered.connect(func() -> void: _set_tab(idx, false))
		b.pressed.connect(func() -> void: _enter_content())
		bar.add_child(b)
		_tab_buttons.append(b)
	MenuUtil.chain_row(_tab_buttons)

	# Body
	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.theme_type_variation = &"MenuList"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# Footer
	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var hint := Label.new()
	hint.theme_type_variation = &"MenuHint"
	hint.text = HINT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frow.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


# --- Tabs -------------------------------------------------------------------

func current_tab() -> int:
	return _tab


func open_tab(t: int) -> void:
	_set_tab(t, true)


func _set_tab(t: int, move_focus: bool) -> void:
	var want := clampi(t, 0, TAB_NAMES.size() - 1) as Tab
	if want == _tab and not _rows.is_empty():
		# Already showing it — do not tear the page down under the player's
		# focus just because focus wandered back onto the tab.
		if move_focus:
			_tab_buttons[_tab].grab_focus()
		return
	_tab = want
	for i in _tab_buttons.size():
		_tab_buttons[i].theme_type_variation = (
			&"MenuTabActive" if i == _tab else &"MenuTab")
	_rebuild()
	if move_focus and _tab_buttons.size() > 0:
		_tab_buttons[_tab].grab_focus()


func _enter_content() -> void:
	var first := MenuUtil.first_focusable(_rows)
	if first:
		first.grab_focus()


## Focus entry point when the screen opens: the active tab, so left/right
## immediately does something useful.
func focus_first() -> void:
	if _tab_buttons.size() > 0:
		_tab_buttons[_tab].grab_focus()


# --- Content ----------------------------------------------------------------

func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows.clear()
	_bind_rows.clear()
	# Freed above. A stale handle here would be a lambda writing into a queued
	# node on the tab the player just left.
	_mercy_says = null

	match _tab:
		Tab.AUDIO: _build_audio()
		Tab.GRAPHICS: _build_graphics()
		Tab.CONTROLS: _build_controls()
		Tab.GAME: _build_game()

	_wire_focus()


func _wire_focus() -> void:
	var focusables: Array[Control] = []
	for r in _rows:
		if r.focus_mode != Control.FOCUS_NONE:
			focusables.append(r)
	MenuUtil.chain(focusables, true)
	if focusables.is_empty():
		return
	var tab_btn: Button = _tab_buttons[_tab]
	# Down out of the tab bar lands on the first row; down off the last row
	# lands on Back; down off Back returns to the tab bar. No dead ends.
	for b in _tab_buttons:
		MenuUtil.link_down(b, focusables[0])
	MenuUtil.link_down(focusables[focusables.size() - 1], _back)
	_back.focus_neighbor_bottom = _back.get_path_to(tab_btn)
	_back.focus_next = _back.get_path_to(tab_btn)
	_back.focus_neighbor_left = ^"."
	_back.focus_neighbor_right = ^"."
	focusables[0].focus_neighbor_top = focusables[0].get_path_to(tab_btn)
	focusables[0].focus_previous = focusables[0].get_path_to(tab_btn)


func _heading(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"MenuHeading"
	l.text = text
	l.focus_mode = Control.FOCUS_NONE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	_rows.append(l)


## Returns the label, for the one caption that has to change without the panel
## being rebuilt — mercy's, which says what the toggle above it is doing.
func _caption(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"MenuHint"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.focus_mode = Control.FOCUS_NONE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	_rows.append(l)
	return l


func _slider(title: String, minv: float, maxv: float, step: float,
		fmt: MenuSliderRow.Format, value: float,
		on_change: Callable) -> MenuSliderRow:
	var row := MenuSliderRow.new()
	# A stable node name so a director can steer to a named row by keyboard.
	row.name = "row_" + title.to_snake_case()
	_content.add_child(row)
	row.setup(title, minv, maxv, step, fmt)
	row.set_value_silent(value)
	row.value_changed.connect(func(v: float) -> void:
		if not _applying:
			on_change.call(v))
	row.settled.connect(func(_v: float) -> void: value_settled.emit())
	_rows.append(row)
	return row


func _choice(title: String, names: Array[String], index: int,
		on_change: Callable) -> MenuChoiceRow:
	var row := MenuChoiceRow.new()
	row.name = "row_" + title.to_snake_case()
	_content.add_child(row)
	row.setup(title, names, index)
	row.choice_changed.connect(func(i: int) -> void:
		if not _applying:
			on_change.call(i)
		value_settled.emit())
	_rows.append(row)
	return row


# --- Audio ------------------------------------------------------------------

func _build_audio() -> void:
	_heading("Volume")
	_caption("Changes take effect immediately and are kept between sessions.")
	_slider("Master", 0.0, 1.0, 0.01, MenuSliderRow.Format.PERCENT,
		Settings.get_volume(&"Master"),
		func(v: float) -> void: Settings.set_volume(&"Master", v))
	_slider("Music", 0.0, 1.0, 0.01, MenuSliderRow.Format.PERCENT,
		Settings.get_volume(&"Music"),
		func(v: float) -> void: Settings.set_volume(&"Music", v))
	_slider("Sound Effects", 0.0, 1.0, 0.01, MenuSliderRow.Format.PERCENT,
		Settings.get_volume(&"SFX"),
		func(v: float) -> void: Settings.set_volume(&"SFX", v))
	_slider("Interface", 0.0, 1.0, 0.01, MenuSliderRow.Format.PERCENT,
		Settings.get_volume(&"UI"),
		func(v: float) -> void: Settings.set_volume(&"UI", v))


# --- Graphics ---------------------------------------------------------------

func _build_graphics() -> void:
	_heading("Display")
	_choice("Fullscreen", ONOFF, 1 if Settings.fullscreen else 0,
		func(i: int) -> void:
			Settings.fullscreen = i == 1
			_apply_video())
	_choice("V-Sync", ONOFF, 1 if Settings.vsync else 0,
		func(i: int) -> void:
			Settings.vsync = i == 1
			_apply_video())

	_heading("Quality")
	_slider("Resolution Scale", 0.5, 1.0, 0.05, MenuSliderRow.Format.PERCENT,
		Settings.resolution_scale,
		func(v: float) -> void:
			Settings.resolution_scale = v
			_apply_video())
	_choice("Anti-Aliasing (MSAA)", MSAA_NAMES, Settings.msaa,
		func(i: int) -> void:
			Settings.msaa = i
			_apply_video())
	_choice("Shadow Quality", SHADOW_NAMES, Settings.shadow_quality,
		func(i: int) -> void:
			Settings.shadow_quality = i
			_apply_video())

	_heading("Camera")
	_slider("Field of View Offset", -10.0, 15.0, 1.0, MenuSliderRow.Format.DEGREES,
		Settings.fov_offset,
		func(v: float) -> void:
			Settings.fov_offset = v
			Settings.save_settings())
	_caption("Added to the base %d° dungeon FOV." % roundi(K.CAM_FOV))


func _apply_video() -> void:
	Settings.apply_video()
	Settings.save_settings()


# --- Controls ---------------------------------------------------------------

func _build_controls() -> void:
	_heading("Controls")
	_caption("Select a row, then press the key you want. Gamepad bindings are fixed.")
	_column_header()
	for action in Settings.rebindable_actions():
		var row := MenuBindRow.new()
		row.name = "bind_" + String(action)
		_content.add_child(row)
		row.setup(action)
		row.rebind_requested.connect(func(a: StringName) -> void: rebind_requested.emit(a))
		_rows.append(row)
		_bind_rows.append(row)

	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.custom_minimum_size.y = 46
	reset.pressed.connect(_on_reset_binds)
	_content.add_child(reset)
	_rows.append(reset)


func _column_header() -> void:
	var row := HBoxContainer.new()
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := Label.new()
	a.theme_type_variation = &"MenuHint"
	a.text = "ACTION"
	a.custom_minimum_size.x = MenuBindRow.TITLE_WIDTH + MenuBindRow.PAD_X
	row.add_child(a)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var k := Label.new()
	k.theme_type_variation = &"MenuHint"
	k.text = "KEYBOARD"
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.custom_minimum_size.x = MenuBindRow.KEY_WIDTH
	row.add_child(k)
	var p := Label.new()
	p.theme_type_variation = &"MenuHint"
	p.text = "GAMEPAD"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.custom_minimum_size.x = MenuBindRow.PAD_WIDTH + MenuBindRow.PAD_X
	row.add_child(p)
	_content.add_child(row)
	_rows.append(row)


func _on_reset_binds() -> void:
	Settings.reset_binds()
	refresh_binds()
	notice.emit("Controls reset to defaults.", false)


## Re-read every bind row from Settings / InputMap.
func refresh_binds() -> void:
	for row in _bind_rows:
		if is_instance_valid(row):
			row.refresh()


# --- Game -------------------------------------------------------------------

func _build_game() -> void:
	_heading("Camera")
	_choice("Invert Camera Y", ONOFF, 1 if Settings.invert_camera_y else 0,
		func(i: int) -> void:
			Settings.invert_camera_y = i == 1
			Settings.save_settings())
	_slider("Camera Sensitivity", 0.2, 3.0, 0.05, MenuSliderRow.Format.MULTIPLIER,
		Settings.camera_sensitivity,
		func(v: float) -> void:
			Settings.camera_sensitivity = v
			Settings.save_settings())
	_slider("Camera Shake", 0.0, 1.5, 0.05, MenuSliderRow.Format.PERCENT,
		Settings.camera_shake,
		func(v: float) -> void:
			Settings.camera_shake = v
			Settings.save_settings())
	_caption("Shake at 0% disables screen quake entirely.")

	_heading("Combat")
	_choice("Letterbox On Target", ONOFF, 1 if Settings.letterbox_on_target else 0,
		func(i: int) -> void:
			Settings.letterbox_on_target = i == 1
			Settings.save_settings())
	_choice("Controller Rumble", ONOFF, 1 if Settings.rumble else 0,
		func(i: int) -> void:
			Settings.rumble = i == 1
			Settings.save_settings())

	# The slider that goes the other way (docs/GDD.md §7.1). In OPTIONS and named
	# plainly, which is the whole design decision: Hades can make this a boon
	# because Hades has gods who talk to you, and inventing an NPC to hand a mercy
	# over would break §6.1's five-counters-no-dialogue garrison. It is on the
	# GAME tab under Combat rather than in a tab of its own because a settings
	# page that quarantines its accessibility row is a page that has made the row
	# a confession.
	_heading("Mercy")
	# The live number, not the design. A player who turns this on deserves to
	# know exactly what it did, and a caption that said "a small resistance"
	# while the rate was 22.5% would be the menu being coy about the one setting
	# it should be plainest about. Off, it says what it would be -- the offer,
	# before the acceptance. It is repainted on the press rather than left to the
	# next rebuild, because a row whose own caption disagrees with it for as long
	# as the screen stays open reads as a toggle that did not take.
	#
	# A MEMBER and not a local the lambda closes over: GDScript captures locals
	# BY VALUE when the lambda is built, so a `var says` declared above the
	# `_choice` call would be captured as null and the caption would never move
	# (CLAUDE.md §3 is full of traps of exactly this shape).
	_choice("Mercy", ONOFF, 1 if Settings.mercy else 0,
		func(i: int) -> void:
			Settings.mercy = i == 1
			Settings.save_settings()
			if _mercy_says != null:
				_mercy_says.text = _mercy_caption())
	_mercy_says = _caption(_mercy_caption())


## What mercy is doing, or would do. Computed from `K` and `Game.deaths` rather
## than written out, so the sentence cannot outlive a tuning change.
func _mercy_caption() -> String:
	var rate := minf(K.MERCY_BASE + K.MERCY_PER_DEATH * float(Game.deaths),
		K.MERCY_MAX)
	var what := "Softens every blow by %.0f%%" % (rate * 100.0)
	# Never "you have died 7 times". §7.1 puts this in options and not in the
	# fiction precisely so nobody is handed a tally of their failures; the number
	# it drives is the player's business, the count behind it is not.
	if rate < K.MERCY_MAX:
		what += ", and by a little more each time you fall"
	what += ". Nothing is disabled: every ending, plaque and relic stays open."
	return what if Settings.mercy else what.replace("Softens", "Would soften")


# --- Re-entry ---------------------------------------------------------------

## Called every time the screen becomes visible. Rebuilding from Settings is
## what makes "open, change, close, reopen" show the values you left behind.
func refresh_all() -> void:
	_rebuild()


func _on_settings_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if not is_visible_in_tree():
		return
	if section == &"controls":
		refresh_binds()
