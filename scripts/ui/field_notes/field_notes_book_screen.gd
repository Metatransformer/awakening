class_name FieldNotesBookScreen
extends Control
## The bedside ledger: all five authored observations on the left, the selected
## literal note on the right. Doctrine purchases remain Aldric's service.

const SCREEN_ID: StringName = &"field_notes_book"
const LAYER: int = 70
const READY_STATE: StringName = &"READY"
const AWAITING_STATE: StringName = &"AWAITING"
const FILED_STATE: StringName = &"FILED"

var host: Node = null

var _selected: int = 0
var _closing: bool = false
var _rows: Array[Button] = []
var _frame: PanelContainer
var _balance: Label
var _title: Label
var _state: Label
var _objective: Label
var _waiting: Label
var _body: Label
var _reward: Label
var _action: Label


static func open(from: Node) -> FieldNotesBookScreen:
	var layer := CanvasLayer.new()
	layer.name = "FieldNotesBookLayer"
	layer.layer = LAYER
	var screen := FieldNotesBookScreen.new()
	screen.host = from
	layer.add_child(screen)
	var parent: Node = from.get_tree().current_scene
	if parent == null:
		parent = from.get_tree().root
	parent.add_child(layer)
	return screen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.prewarm()
	theme = UITheme.theme()
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	Bus.field_observations_completed.connect(
		func(_ids: Array[StringName]) -> void: refresh())
	Bus.field_notes_awarded.connect(
		func(_ids: Array[StringName], _new_balance: int) -> void: refresh())
	Bus.input_device_changed.connect(func(_pad: bool) -> void: _paint_note())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Prompt.block(self)
	Bus.screen_opened.emit(SCREEN_ID)
	refresh()
	if not _rows.is_empty():
		_rows[0].grab_focus.call_deferred()


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(SCREEN_ID)


func close() -> void:
	if _closing:
		return
	_closing = true
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


func refresh() -> void:
	_balance.text = "%d FIELD NOTE%s" % [Game.field_notes,
		"" if Game.field_notes == 1 else "S"]
	for i: int in _rows.size():
		_paint_row(i)
	_paint_note()


func row_count() -> int:
	return _rows.size()


func selected_observation_id() -> StringName:
	if _selected < 0 or _selected >= FieldNotesDb.OBSERVATION_IDS.size():
		return &""
	return FieldNotesDb.OBSERVATION_IDS[_selected]


func observation_state(id: StringName) -> StringName:
	if Game.has_field_observation(id):
		return FILED_STATE
	if Game.field_observation_ready_to_file(id):
		return READY_STATE
	return AWAITING_STATE


func select_observation(id: StringName) -> bool:
	var index: int = FieldNotesDb.OBSERVATION_IDS.find(id)
	if index < 0:
		return false
	_select(index)
	return true


func file_selected() -> bool:
	var id := selected_observation_id()
	if observation_state(id) != READY_STATE:
		return false
	var filed: bool = Game.file_field_observation(id)
	# The typed award event refreshes the live screen. This direct refresh keeps
	# the public seam deterministic even if it is exercised outside the tree.
	if filed and not is_inside_tree():
		refresh()
	return filed


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _frame == null:
		return
	var room := size - Vector2(48.0, 48.0)
	_frame.custom_minimum_size = Vector2(
		clampf(room.x, 820.0, 1160.0), clampf(room.y, 500.0, 620.0))


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Pal.VOID, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_frame = PanelContainer.new()
	_frame.name = "LedgerFrame"
	_frame.add_theme_stylebox_override("panel", _book_box(Color(0.20, 0.085, 0.045),
		Pal.GOLD, 12, 3))
	centre.add_child(_frame)

	var cover_margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		cover_margin.add_theme_constant_override("margin_" + side, 18)
	_frame.add_child(cover_margin)

	var spread := HBoxContainer.new()
	spread.name = "OpenSpread"
	spread.add_theme_constant_override("separation", 10)
	cover_margin.add_child(spread)

	var left := _page(spread, "ObservationPage")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.88
	var left_margin := left.get_child(0) as MarginContainer
	_build_left_page(left_margin.get_child(0) as VBoxContainer)

	var gutter := ColorRect.new()
	gutter.name = "SpineGutter"
	gutter.custom_minimum_size.x = 8.0
	gutter.color = Color(0.18, 0.08, 0.04, 0.65)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(gutter)

	var right := _page(spread, "NotePage")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.12
	var right_margin := right.get_child(0) as MarginContainer
	_build_right_page(right_margin.get_child(0) as VBoxContainer)


func _page(parent: Node, page_name: String) -> PanelContainer:
	var page := PanelContainer.new()
	page.name = page_name
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", _book_box(UITheme.PARCHMENT,
		Color(0.36, 0.24, 0.14), 3, 1))
	parent.add_child(page)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	return page


func _build_left_page(parent: VBoxContainer) -> void:
	var kicker := _label("SOCIETY FIELD LEDGER", UITheme.TYPE_H3, UITheme.INK_DIM)
	parent.add_child(kicker)
	var heading := _label("Field Notes", UITheme.TYPE_TITLE, UITheme.INK)
	parent.add_child(heading)
	_balance = _label("", UITheme.TYPE_H2, UITheme.INK)
	_balance.name = "NoteBalance"
	parent.add_child(_balance)
	parent.add_child(_rule())

	var list := VBoxContainer.new()
	list.name = "ObservationRows"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	parent.add_child(list)
	for i: int in FieldNotesDb.OBSERVATION_IDS.size():
		var row := Button.new()
		row.name = "Observation%02d" % (i + 1)
		row.focus_mode = Control.FOCUS_ALL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size.y = 62.0
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(_select.bind(i))
		row.focus_entered.connect(_select.bind(i))
		row.mouse_entered.connect(func() -> void:
			if not _closing:
				row.grab_focus())
		_rows.append(row)
		list.add_child(row)
	for i: int in _rows.size():
		_rows[i].focus_neighbor_top = _rows[(i - 1 + _rows.size()) % _rows.size()].get_path()
		_rows[i].focus_neighbor_bottom = _rows[(i + 1) % _rows.size()].get_path()

	var close_cap := Glyph.cap(&"ui_cancel")
	if close_cap.is_empty():
		close_cap = "ESC"
	var footer := _label("%s  CLOSE" % close_cap, UITheme.TYPE_CAPTION, UITheme.INK_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(footer)


func _build_right_page(parent: VBoxContainer) -> void:
	var kicker := _label("SELECTED OBSERVATION", UITheme.TYPE_H3, UITheme.INK_DIM)
	parent.add_child(kicker)
	_title = _label("", UITheme.TYPE_H1, UITheme.INK)
	_title.name = "NoteTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_title)
	_state = _label("", UITheme.TYPE_H3, UITheme.INK_DIM)
	_state.name = "NoteState"
	parent.add_child(_state)
	parent.add_child(_rule())

	var objective_heading := _label("OBJECTIVE", UITheme.TYPE_H3, UITheme.INK_DIM)
	parent.add_child(objective_heading)
	_objective = _label("", UITheme.TYPE_PARAGRAPH_1, UITheme.INK)
	_objective.name = "ObjectiveText"
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_objective)

	_waiting = _label("", UITheme.TYPE_PARAGRAPH_2, UITheme.INK_DIM)
	_waiting.name = "WaitingText"
	_waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_waiting)

	var note_heading := _label("FIELD NOTE", UITheme.TYPE_H3, UITheme.INK_DIM)
	parent.add_child(note_heading)
	_body = _label("", UITheme.TYPE_PARAGRAPH_1, UITheme.INK)
	_body.name = "NoteBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_body)

	parent.add_child(_rule())
	_reward = _label("", UITheme.TYPE_PARAGRAPH_2, UITheme.INK)
	_reward.name = "RewardStatus"
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_reward)
	_action = _label("", UITheme.TYPE_CONTROL_PROMINENT, Pal.GOLD)
	_action.name = "FileAction"
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(_action)


func _select(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	_selected = index
	for i: int in _rows.size():
		_paint_row(i)
	_paint_note()


func _paint_row(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var id: StringName = FieldNotesDb.OBSERVATION_IDS[index]
	var state := observation_state(id)
	var row := _rows[index]
	row.text = "%02d  %s  ·  %s" % [index + 1, String(state),
		FieldNotesDb.display_text(id)]
	var ink := UITheme.INK_DIM
	if state == READY_STATE:
		ink = Pal.GOLD
	elif state == FILED_STATE:
		ink = UITheme.INK
	for key: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		row.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		var selected: bool = index == _selected
		var fill := Color(0.38, 0.27, 0.16, 0.13 if not selected else 0.28)
		var edge := Pal.GOLD if state == READY_STATE else Color(0.34, 0.23, 0.14)
		row.add_theme_stylebox_override(key, _book_box(fill, edge,
			4, 2 if selected else 1))


func _paint_note() -> void:
	if _title == null:
		return
	var id := selected_observation_id()
	var definition := FieldNotesDb.observation_definition(id)
	var state := observation_state(id)
	_title.text = String(definition.get("label", ""))
	_state.text = String(state)
	_state.add_theme_color_override("font_color",
		Pal.GOLD if state == READY_STATE else UITheme.INK_DIM)
	_objective.text = FieldNotesDb.observation_objective_text(id)
	_waiting.text = FieldNotesDb.observation_waiting_text(id)
	_body.text = FieldNotesDb.observation_note_body(id)
	var value := FieldNotesDb.observation_note_value(id)
	match state:
		AWAITING_STATE:
			_reward.text = "AWAITING · Filing reward: %d Field Note" % value
		READY_STATE:
			_reward.text = "READY TO FILE · Reward: %d Field Note" % value
		FILED_STATE:
			_reward.text = "FILED · %d Field Note awarded" % value
	var cap := Glyph.cap(&"interact")
	if cap.is_empty():
		cap = "READ"
	_action.text = "%s  FILE THIS ENTRY" % cap if state == READY_STATE else ""


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		file_selected()
	# Arrow events are deliberately left to the focused Buttons. Moving here as
	# well would give one press two navigators (CLAUDE.md §3).


func _label(text: String, style: Dictionary, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(label, style, color)
	return label


func _rule() -> HSeparator:
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 1)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.32, 0.22, 0.13, 0.60)
	rule.add_theme_stylebox_override("separator", line)
	return rule


func _book_box(fill: Color, edge: Color, radius: int,
		border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12.0
	box.content_margin_top = 8.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 8.0
	return box
