class_name UpgradeLadder
extends VBoxContainer
## A vertical, tabbed progression board. It arranges catalogue groups and tracks
## but never interprets payment or performs a purchase; `TradeScreen` remains the
## sole cursor mover and transaction owner.

## Non-negative selections index catalogue lines. Owned rungs use stable
## negative keys from -2 down; -1 remains "no selection".
signal cell_focused(selection: int)
signal cell_activated(line: int)
## Emitted after a tab switch with the first selectable node on the new tab.
## The screen updates its cursor/detail from this without stealing focus back
## from the tab strip.
signal tab_changed(first_selection: int)

const ARROW := "→"
const TICK := "✓"
const RUNG_SIZE := Vector2(112, 58)
const ROW_HEIGHT := 74
const ROW_ICON_PX := 42
const RUNG_ICON_PX := 46
const TITLE_WIDTH := 148

var _groups: Array[Dictionary] = []
var _cell_entries: Array[Dictionary] = []
var _tab_keys: Array[String] = []
var _tab_buttons: Array[Button] = []
var _active_tab := ""
var _tab_strip: HBoxContainer
var _body: VBoxContainer

var _cells: Array[Button] = []
var _line_of: Array[int] = []
var _selection_of: Array[int] = []
var _row_of: Array[int] = []
var _owned_details: Dictionary[int, Dictionary] = {}
var _labels_by_selection: Dictionary[int, String] = {}
var _order: Array[int] = []
var _rows_built := 0

## Where focus may spill below the board. Navigation arrows are still consumed
## and interpreted by `TradeScreen`; this seam is for compatibility with other
## focus chains and mouse-driven focus.
var spill_down: Control = null


func _init() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Rebuild from catalogue groups while keeping the active tab by string key.
## Missing `tab` values fall back to the existing group title contract.
func set_board(groups: Array, cells: Array) -> void:
	_groups.clear()
	for group: Dictionary in groups:
		_groups.append(group.duplicate(true))
	_cell_entries.clear()
	for entry: Dictionary in cells:
		_cell_entries.append(entry.duplicate(true))

	_tab_keys.clear()
	for group: Dictionary in _groups:
		var key := _tab_key(group)
		if not _tab_keys.has(key):
			_tab_keys.append(key)
	if not _tab_keys.has(_active_tab):
		_active_tab = _tab_keys[0] if not _tab_keys.is_empty() else ""

	_clear_children(self)
	_build_tabs()
	_body = VBoxContainer.new()
	_body.name = "Tracks"
	_body.add_theme_constant_override("separation", 9)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_body)
	_rebuild_active_body()


func cell_at(i: int) -> Button:
	return _cells[i] if i >= 0 and i < _cells.size() else null


func slot_of_line(line: int) -> int:
	return _line_of.find(line)


func cell_of_selection(selection: int) -> Button:
	if selection == -1:
		return null
	return cell_at(_selection_of.find(selection))


func owned_detail(selection: int) -> Dictionary:
	if not _owned_details.has(selection):
		return {}
	return _owned_details[selection]


func label_of_selection(selection: int) -> String:
	return _labels_by_selection.get(selection, "")


func count() -> int:
	return _cells.size()


func order() -> Array[int]:
	return _order


func row_of_line(line: int) -> int:
	var i := _line_of.find(line)
	return _row_of[i] if i >= 0 else -1


func row_of_selection(selection: int) -> int:
	var i := _selection_of.find(selection)
	return _row_of[i] if i >= 0 else -1


func first_line_of_row(row: int) -> int:
	for i in _cells.size():
		if _row_of[i] == row and _line_of[i] >= 0:
			return _line_of[i]
	return -1


func first_selection_of_row(row: int) -> int:
	for i in _cells.size():
		if _row_of[i] == row and _selection_of[i] != -1:
			return _selection_of[i]
	return -1


func row_count() -> int:
	return _rows_built


func first_selection() -> int:
	return _order[0] if not _order.is_empty() else -1


## One horizontal node on the current track, wrapping within that track only.
func horizontal_selection(selection: int, direction: int) -> int:
	var row := row_of_selection(selection)
	if row < 0 or direction == 0:
		return selection
	var in_row: Array[int] = []
	for i in _selection_of.size():
		if _row_of[i] == row and _selection_of[i] != -1:
			in_row.append(_selection_of[i])
	var at := in_row.find(selection)
	if at < 0 or in_row.is_empty():
		return selection
	return in_row[(at + signi(direction) + in_row.size()) % in_row.size()]


# --- Tabs --------------------------------------------------------------------

func focus_current_tab() -> bool:
	var button := current_tab_button()
	if button == null or button.get_viewport() == null:
		return false
	button.grab_focus()
	return true


func focus_is_tab() -> bool:
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return owner != null and _tab_buttons.has(owner)


func current_tab_button() -> Button:
	var at := _tab_keys.find(_active_tab)
	return _tab_buttons[at] if at >= 0 and at < _tab_buttons.size() else null


## Cycle and wrap the tab strip. Returns the new tab's first selection.
func cycle_tab(direction: int) -> int:
	if _tab_keys.is_empty() or direction == 0:
		return first_selection()
	var at := maxi(_tab_keys.find(_active_tab), 0)
	var next := (at + signi(direction) + _tab_keys.size()) % _tab_keys.size()
	_activate_tab(_tab_keys[next])
	var button := current_tab_button()
	if button != null:
		button.grab_focus()
	return first_selection()


func _build_tabs() -> void:
	_tab_strip = HBoxContainer.new()
	_tab_strip.name = "Tabs"
	_tab_strip.add_theme_constant_override("separation", 2)
	_tab_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tab_strip)
	_tab_buttons.clear()
	for key: String in _tab_keys:
		var button := Button.new()
		button.name = "Tab_%s" % key.to_snake_case()
		button.text = key
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0, 44)
		button.focus_entered.connect(_on_tab_focused.bind(key))
		button.pressed.connect(_on_tab_pressed.bind(key))
		_tab_strip.add_child(button)
		_tab_buttons.append(button)
	_paint_tabs()
	MenuUtil.chain_row(_tab_buttons)


func _paint_tabs() -> void:
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		var active := _tab_keys[i] == _active_tab
		UITheme.style_tab_button(button, active)
		# Selected and focused need distinct shapes or entering tab mode is invisible.
		button.add_theme_stylebox_override("focus", UITheme.tab_box("focused"))


func _on_tab_focused(key: String) -> void:
	_activate_tab(key)


func _on_tab_pressed(key: String) -> void:
	_activate_tab(key)


func _activate_tab(key: String) -> void:
	if key == _active_tab or not _tab_keys.has(key):
		return
	_active_tab = key
	_paint_tabs()
	_rebuild_active_body()
	tab_changed.emit(first_selection())


func _tab_key(group: Dictionary) -> String:
	var title := String(group.get("title", "")).strip_edges()
	var key := String(group.get("tab", title)).strip_edges()
	return key if not key.is_empty() else (title if not title.is_empty() else "UPGRADES")


# --- Rows and rungs -----------------------------------------------------------

func _rebuild_active_body() -> void:
	if _body == null:
		return
	_clear_children(_body)
	_cells.clear()
	_line_of.clear()
	_selection_of.clear()
	_row_of.clear()
	_owned_details.clear()
	_labels_by_selection.clear()
	_order.clear()
	_rows_built = 0
	for group: Dictionary in _groups:
		if _tab_key(group) != _active_tab:
			continue
		var tracks: Array = group.get("tracks", [])
		for track: Dictionary in tracks:
			_add_track_row(group, track, tracks.size() > 1)
			_rows_built += 1
	for selection: int in _selection_of:
		if selection != -1:
			_order.append(selection)
	_wire_focus()


func _add_track_row(group: Dictionary, track: Dictionary, multi_branch: bool) -> void:
	var panel := PanelContainer.new()
	panel.name = "Track_%d" % _rows_built
	panel.add_theme_stylebox_override("panel", UITheme.stone_track())
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 9)
	identity.custom_minimum_size.x = TITLE_WIDTH
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(identity)

	var icon_path := UiKit.track_icon(String(group.get("icon", "")))
	if not icon_path.is_empty():
		identity.add_child(KitIcon.rect(UiKit.resolve_icon(icon_path), ROW_ICON_PX, 0.92))

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = TITLE_WIDTH - ROW_ICON_PX - 9
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = _row_title(group, track, multi_branch)
	UITheme.apply_text_style(title, UITheme.TYPE_H3, UITheme.ACCENT_DIM)
	identity.add_child(title)

	var chain := HBoxContainer.new()
	chain.add_theme_constant_override("separation", 5)
	chain.size_flags_horizontal = Control.SIZE_SHRINK_END
	chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chain)
	_add_rungs(chain, group, track, icon_path)


func _row_title(group: Dictionary, track: Dictionary, multi_branch: bool) -> String:
	var group_title := String(group.get("title", "")).strip_edges()
	var branch := String(track.get("name", "")).strip_edges()
	if multi_branch and not branch.is_empty():
		return "%s — %s" % [group_title, branch]
	return group_title if not group_title.is_empty() else branch


func _add_rungs(chain: HBoxContainer, group: Dictionary, track: Dictionary,
		icon_path: String) -> void:
	var line := int(track.get("line", -1))
	var owned := maxi(int(track.get("owned", 0)), 0)
	var rungs := maxi(int(track.get("rungs", 1)), 1)
	var entry: Dictionary = (_cell_entries[line] if line >= 0
		and line < _cell_entries.size() else {})
	for rank in rungs:
		if rank > 0:
			_add_connector(chain, rank <= owned)
		var state := &"owned" if rank < owned else (
			&"available" if rank == owned and line >= 0 else &"locked")
		chain.add_child(_make_rung(group, track, rank, line, entry, state, icon_path))


func _add_connector(chain: HBoxContainer, reached: bool) -> void:
	var arrow := Label.new()
	arrow.text = ARROW
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size.x = 18
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(arrow, UITheme.TYPE_PARAGRAPH_1,
		UITheme.SUCCESS if reached else Color(UITheme.TEXT_DIM, 0.46))
	chain.add_child(arrow)


func _make_rung(group: Dictionary, track: Dictionary, rank: int, line: int,
		entry: Dictionary, state: StringName, icon_path: String) -> Button:
	var button := Button.new()
	button.name = "Rung_%d_%d" % [_rows_built, rank]
	button.custom_minimum_size = RUNG_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	_style_rung(button)

	if not icon_path.is_empty():
		var art := TextureRect.new()
		art.texture = UiKit.resolve_icon(icon_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.modulate = Color(1, 1, 1, 0.11)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = (RUNG_SIZE.x - RUNG_ICON_PX) * 0.5
		art.offset_right = -(RUNG_SIZE.x - RUNG_ICON_PX) * 0.5
		art.offset_top = 4
		art.offset_bottom = -8

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 5
	col.offset_bottom = -5

	var name_label := Label.new()
	name_label.text = _rung_name(group, track, rank)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(name_label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT)
	col.add_child(name_label)

	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 4)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(status)
	_add_rung_status(status, state, entry)

	var slot := _cells.size()
	var selection := -1
	if state == &"owned":
		selection = -2 - slot
	elif state == &"available":
		selection = line
	button.focus_mode = Control.FOCUS_ALL if selection != -1 else Control.FOCUS_NONE
	button.mouse_filter = (Control.MOUSE_FILTER_STOP if selection != -1
		else Control.MOUSE_FILTER_IGNORE)
	button.modulate = Color.WHITE if state != &"locked" else Color(1, 1, 1, 0.48)
	button.set_meta(&"at", slot)
	_cells.append(button)
	_line_of.append(line if state == &"available" else -1)
	_selection_of.append(selection)
	_row_of.append(_rows_built)
	if state == &"owned":
		_owned_details[selection] = _make_owned_detail(
			_rung_name(group, track, rank), group, track, rank, entry)
	if selection != -1:
		_labels_by_selection[selection] = _rung_name(group, track, rank)
		button.focus_entered.connect(_look.bind(button))
		button.mouse_entered.connect(_look.bind(button))
		if state == &"available":
			button.pressed.connect(_press.bind(button))
	return button


func _style_rung(button: Button) -> void:
	button.add_theme_stylebox_override("normal",
		UITheme.hud_box(Color(0.035, 0.034, 0.033, 0.78), 6, 5, 6, 5))
	button.add_theme_stylebox_override("hover",
		UITheme.hud_box(Color(0.11, 0.108, 0.104, 0.88), 6, 5, 6, 5))
	button.add_theme_stylebox_override("pressed",
		UITheme.hud_box(Color(0.16, 0.157, 0.151, 0.92), 6, 6, 6, 4))
	button.add_theme_stylebox_override("focus", UITheme.focus_rim(true))


func _add_rung_status(parent: HBoxContainer, state: StringName, entry: Dictionary) -> void:
	if state == &"locked":
		var lock_path := UiKit.action_icon("lock")
		if not lock_path.is_empty():
			var lock := TextureRect.new()
			lock.texture = UiKit.resolve_icon(lock_path)
			lock.custom_minimum_size = Vector2(17, 17)
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(lock)
			return
	_add_status_label(parent,
		(TICK + " OWNED") if state == &"owned" else (
			String(entry.get("sub", "AVAILABLE")) if state == &"available" else "LOCKED"),
		UITheme.SUCCESS if state == &"owned" else (
			UITheme.DANGER if state == &"available" and bool(entry.get("dim", false))
			else UITheme.WARNING if state == &"available" else UITheme.TEXT_DIM))


func _add_status_label(parent: Node, text: String, tone: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(label, UITheme.TYPE_CAPTION, tone)
	parent.add_child(label)


func _rung_name(group: Dictionary, track: Dictionary, rank: int) -> String:
	var names: Array = track.get("rung_names", [])
	if rank >= 0 and rank < names.size():
		var authored := String(names[rank]).strip_edges()
		if not authored.is_empty():
			return authored
	var branch := String(track.get("name", "")).strip_edges()
	var group_title := String(group.get("title", "")).strip_edges()
	var base := branch if not branch.is_empty() else group_title
	return "%s %d" % [base if not base.is_empty() else "Upgrade", rank + 1]


func _make_owned_detail(label: String, group: Dictionary, track: Dictionary,
		rank: int, entry: Dictionary) -> Dictionary:
	var detail: Dictionary = {
		"kind": &"owned",
		"label": label,
		"state": &"owned",
		"blurb": String(entry.get("blurb", "Already purchased.")),
		# The catalogue entry describes the LIVE next/aggregate result, not this
		# historical rung. Repeating it here made rung one of a finished sword say
		# "+3 quarters (finished)". Be explicit rather than showing false stats.
		"detail": "Rung %d of %d completed." % [rank + 1,
			maxi(int(track.get("rungs", 1)), 1)],
		"group": String(group.get("title", "")),
		"branch": String(track.get("name", "")),
		"rank": rank + 1,
		"rungs": maxi(int(track.get("rungs", 1)), 1),
		"price": 0,
		"parts": {},
	}
	detail.make_read_only()
	return detail


# --- Focus reports -----------------------------------------------------------

func _wire_focus() -> void:
	for row in _rows_built:
		var live: Array = []
		for i in _cells.size():
			if _row_of[i] == row and _selection_of[i] != -1:
				live.append(_cells[i])
		MenuUtil.chain_row(live)
	if not _order.is_empty() and current_tab_button() != null:
		MenuUtil.link_down(current_tab_button(), cell_of_selection(_order[0]))
	if spill_down != null and not _order.is_empty():
		MenuUtil.link_down(cell_of_selection(_order[_order.size() - 1]), spill_down)


func _look(button: Button) -> void:
	cell_focused.emit(_selection_of[int(button.get_meta(&"at"))])


func _press(button: Button) -> void:
	var line := _line_of[int(button.get_meta(&"at"))]
	cell_focused.emit(line)
	if line >= 0:
		cell_activated.emit(line)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
