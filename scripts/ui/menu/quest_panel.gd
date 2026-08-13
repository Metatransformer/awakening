class_name MenuQuestPanel
extends Control
## Read-only journal for accepted quests and their authored objectives.

signal back_requested

const LIST_WIDTH := 410.0

var _hrow: HBoxContainer
var _band_slot: VBoxContainer
var _list_scroll: ScrollContainer
var _list_body: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
var _back: Button
var _rows: Array[Button] = []
var _visible_ids: Array[StringName] = []
var _selected_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.quests_changed.connect(_on_quests_changed)
	refresh()


## Where PauseMenu inserts the shared focusable page strip.
func tab_host() -> HBoxContainer:
	return _hrow


## The strip lands on the first journal row, or Back when the journal is empty.
func tab_row() -> Array:
	if not _rows.is_empty():
		return [_rows[0]]
	return [_back] if _back != null else []


func focus_first() -> void:
	if not _rows.is_empty():
		_rows[0].grab_focus()
	elif _back != null:
		_back.grab_focus()


func refresh() -> void:
	if _list_body == null:
		return
	var previous_id := _selected_id
	var previous_list_scroll := _list_scroll.scroll_vertical
	_visible_ids.clear()
	for quest_id: StringName in QuestDb.journal_ids():
		_visible_ids.append(quest_id)

	_rebuild_band()
	UITheme.clear_children(_list_body)
	_rows.clear()
	if _visible_ids.is_empty():
		_selected_id = &""
		_add_empty_list()
	else:
		_selected_id = previous_id if _visible_ids.has(previous_id) else _visible_ids[0]
		for quest_id: StringName in _visible_ids:
			_add_quest_row(quest_id)
	_wire_focus()
	_rebuild_detail()
	_list_scroll.scroll_vertical = previous_list_scroll \
		if _selected_id == previous_id else 0
	if _selected_id != previous_id:
		_detail_scroll.scroll_vertical = 0


func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override(&"separation", 0)
	frame.add_child(col)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 14, 6, 14, 0))
	col.add_child(header)
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var header_gap := Control.new()
	header_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(header_gap)

	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override(&"separation", 0)
	col.add_child(_band_slot)

	var body := HBoxContainer.new()
	body.name = "JournalBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 1)
	col.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.name = "QuestList"
	list_panel.custom_minimum_size.x = LIST_WIDTH
	list_panel.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 0, 0, 0, 0))
	body.add_child(list_panel)
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override(&"separation", 0)
	list_panel.add_child(list_col)
	var list_heading_pad := MarginContainer.new()
	list_heading_pad.add_theme_constant_override("margin_left", 20)
	list_heading_pad.add_theme_constant_override("margin_right", 20)
	list_heading_pad.add_theme_constant_override("margin_top", 12)
	list_heading_pad.add_theme_constant_override("margin_bottom", 8)
	list_col.add_child(list_heading_pad)
	var list_heading := Label.new()
	list_heading.text = "JOURNAL"
	UITheme.apply_text_style(list_heading, UITheme.TYPE_H3, UITheme.ACCENT_DIM)
	list_heading_pad.add_child(list_heading)

	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "QuestScroll"
	_list_scroll.focus_mode = Control.FOCUS_NONE
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_col.add_child(_list_scroll)
	var list_inset := MarginContainer.new()
	list_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_inset.add_theme_constant_override("margin_left", 8)
	list_inset.add_theme_constant_override("margin_right", 8)
	list_inset.add_theme_constant_override("margin_bottom", 10)
	_list_scroll.add_child(list_inset)
	_list_body = VBoxContainer.new()
	_list_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_body.add_theme_constant_override(&"separation", 0)
	list_inset.add_child(_list_body)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "QuestDetail"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.FRAME_FACE_SOLID, 0, 0, 0, 0))
	body.add_child(detail_panel)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.focus_mode = Control.FOCUS_NONE
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_scroll)
	var detail_inset := MarginContainer.new()
	detail_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		detail_inset.add_theme_constant_override("margin_" + side, 28)
	for side: String in ["top", "bottom"]:
		detail_inset.add_theme_constant_override("margin_" + side, 18)
	_detail_scroll.add_child(detail_inset)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override(&"separation", 8)
	detail_inset.add_child(_detail_body)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer.add_child(footer_row)
	var footer_gap := Control.new()
	footer_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_gap)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.focus_mode = Control.FOCUS_ALL
	_back.pressed.connect(_on_back_pressed)
	footer_row.add_child(_back)


func _rebuild_band() -> void:
	UITheme.clear_children(_band_slot)
	var active := 0
	var ready := 0
	var complete := 0
	for quest_id: StringName in _visible_ids:
		match Game.quest_status(quest_id):
			QuestState.Status.ACTIVE:
				active += 1
			QuestState.Status.READY:
				ready += 1
			QuestState.Status.COMPLETED:
				complete += 1
	UiKit.stat_band(_band_slot, [
		{"label": "Active", "value": str(active)},
		{"label": "Ready", "value": str(ready),
			"tone": UITheme.SUCCESS if ready > 0 else null},
		{"label": "Complete", "value": str(complete)},
		{"label": "Total", "value": str(_visible_ids.size())},
	])


func _add_empty_list() -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 12)
	_list_body.add_child(pad)
	var label := Label.new()
	label.text = "No quests recorded."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	pad.add_child(label)


func _add_quest_row(quest_id: StringName) -> void:
	var quest: QuestDef = QuestDb.get_def(quest_id)
	if quest == null:
		return
	var status: int = Game.quest_status(quest_id)
	var row: Button = UiKit.verb_row(_list_body, {
		"label": quest.title,
		"meta": QuestDb.status_label(status),
		"on_press": _select_quest.bind(quest_id),
	})
	row.name = "Quest_%s" % String(quest_id)
	UiKit.verb_meta(row, QuestDb.status_label(status), _status_tone(status))
	row.focus_entered.connect(_select_quest.bind(quest_id))
	row.mouse_entered.connect(_select_quest.bind(quest_id))
	_rows.append(row)


func _wire_focus() -> void:
	if _rows.is_empty():
		MenuUtil.chain([_back], true)
		return
	MenuUtil.chain(_rows, false)
	for row: Button in _rows:
		row.focus_neighbor_left = ^"."
		row.focus_neighbor_right = row.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_selected_row())
	_back.focus_neighbor_right = ^"."
	_back.focus_neighbor_top = _back.get_path_to(_rows[_rows.size() - 1])
	_back.focus_previous = _back.get_path_to(_rows[_rows.size() - 1])
	_back.focus_neighbor_bottom = _back.get_path_to(_rows[0])
	_back.focus_next = _back.get_path_to(_rows[0])


func _select_quest(quest_id: StringName) -> void:
	if quest_id == _selected_id:
		return
	_selected_id = quest_id
	_rebuild_detail()
	_detail_scroll.scroll_vertical = 0
	if _back != null:
		_back.focus_neighbor_left = _back.get_path_to(_selected_row())


func _selected_row() -> Button:
	var at := _visible_ids.find(_selected_id)
	return _rows[at] if at >= 0 and at < _rows.size() else _rows[0]


func _rebuild_detail() -> void:
	UITheme.clear_children(_detail_body)
	if _selected_id == &"":
		var empty := Label.new()
		empty.text = "Speak with the garrison residents..."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_text_style(empty, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT_DIM)
		_detail_body.add_child(empty)
		return

	var quest: QuestDef = QuestDb.get_def(_selected_id)
	if quest == null:
		_selected_id = &""
		_rebuild_detail()
		return
	var status: int = Game.quest_status(_selected_id)
	var kicker := Label.new()
	kicker.text = String(quest.category).to_upper()
	UITheme.apply_text_style(kicker, UITheme.TYPE_CAPTION, UITheme.ACCENT_DIM)
	_detail_body.add_child(kicker)
	var title := Label.new()
	title.text = quest.title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(title, UITheme.TYPE_H1, UITheme.ACCENT)
	_detail_body.add_child(title)
	var status_label := Label.new()
	status_label.text = QuestDb.status_label(status)
	UITheme.apply_text_style(status_label, UITheme.TYPE_PARAGRAPH_2,
		_status_tone(status))
	_detail_body.add_child(status_label)
	var summary := Label.new()
	summary.text = quest.summary
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(summary, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	_detail_body.add_child(summary)

	UITheme.section_rule(_detail_body, "OBJECTIVES")
	var current_objective: Dictionary = Game.quest_active_objective(_selected_id)
	var current_id := StringName(current_objective.get("id", &""))
	for objective: Dictionary in quest.objectives:
		_add_objective(objective, status, current_id)


func _add_objective(objective: Dictionary, quest_status: int,
		current_id: StringName) -> void:
	var objective_id := StringName(objective.get("id", &""))
	var goal: int = int(objective.get("goal", 0))
	var progress: int = Game.quest_progress(_selected_id, objective_id)
	var complete: bool = quest_status == QuestState.Status.READY \
		or quest_status == QuestState.Status.COMPLETED or progress >= goal
	var current: bool = not complete and quest_status == QuestState.Status.ACTIVE \
		and objective_id == current_id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	_detail_body.add_child(row)
	var mark := Label.new()
	mark.custom_minimum_size.x = 18
	mark.text = "✓" if complete else ("◆" if current else "·")
	UITheme.apply_text_style(mark, UITheme.TYPE_PARAGRAPH_1,
		UITheme.SUCCESS if complete else (UITheme.HIGHLIGHT if current else UITheme.TEXT_DIM))
	row.add_child(mark)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = String(objective.get("label", ""))
	UITheme.apply_text_style(label,
		UITheme.TYPE_CONTROL_PROMINENT if current else UITheme.TYPE_PARAGRAPH_1,
		UITheme.SUCCESS if complete else (UITheme.HIGHLIGHT if current else UITheme.TEXT_DIM))
	row.add_child(label)
	if goal > 1:
		var count := Label.new()
		count.text = "%d / %d" % [mini(progress, goal), goal]
		UITheme.apply_text_style(count, UITheme.TYPE_PARAGRAPH_2,
			UITheme.SUCCESS if complete else (UITheme.HIGHLIGHT if current else UITheme.TEXT_DIM))
		row.add_child(count)


func _status_tone(status: int) -> Color:
	match status:
		QuestState.Status.READY, QuestState.Status.COMPLETED:
			return UITheme.SUCCESS
		QuestState.Status.FAILED:
			return UITheme.DANGER
		QuestState.Status.ACTIVE:
			return UITheme.HIGHLIGHT
		_:
			return UITheme.TEXT_DIM


func _on_quests_changed(_quest_id: StringName) -> void:
	refresh()


func _on_back_pressed() -> void:
	back_requested.emit()
