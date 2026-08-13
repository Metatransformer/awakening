extends CanvasLayer
## Always-available, local-only developer console. Every command mutates live
## in-process state; there is no network, shell, or file access here.

const HISTORY_LIMIT := 50
const COMMANDS: Array[Dictionary] = [
	{"name": "help", "args": "", "description": "list developer commands"},
	{"name": "god", "args": "", "description": "toggle invulnerability and free resources"},
	{"name": "tp", "args": "<town|dungeon|dungeon2|dungeon3>", "description": "developer travel without autosaving"},
	{"name": "grant", "args": "<item_id>", "description": "grant a validated item or resource"},
	{"name": "upgrade", "args": "<upgrade_id>", "description": "advance one authored upgrade rung for free"},
	{"name": "puzzles", "args": "", "description": "list developer puzzle fixtures"},
	{"name": "puzzle", "args": "<puzzle_id>", "description": "open and reset a puzzle fixture"},
]

const COL_OK := Color(0.65, 0.88, 0.64)
const COL_WARN := Color(0.95, 0.66, 0.38)
const COL_INFO := Color(0.72, 0.82, 0.94)

var _open: bool = false
var _paused_before_open: bool = false
var _mouse_before_open: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _focus_before_open: Control = null

var _root: Control
var _status: Label
var _input_box: TextEdit
var _completion: ItemList
var _matches: Array[Dictionary] = []
var _completion_index: int = 0

var _history: Array[String] = []
var _history_index: int = -1
var _history_draft: String = ""


func _ready() -> void:
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	print("[DevConsole] armed — press ` to open.")


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	if key.keycode == KEY_QUOTELEFT and not key.alt_pressed \
			and not key.meta_pressed and not key.ctrl_pressed \
			and not key.shift_pressed:
		if _open:
			_close_console()
		else:
			_open_console()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return

	if key.keycode == KEY_ESCAPE:
		_close_console()
		get_viewport().set_input_as_handled()
		return
	if _completion.visible:
		if key.keycode == KEY_UP:
			_move_completion(-1)
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_DOWN:
			_move_completion(1)
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_TAB or key.keycode == KEY_ENTER \
				or key.keycode == KEY_KP_ENTER:
			_accept_completion()
			get_viewport().set_input_as_handled()
			return
	if key.keycode == KEY_UP:
		_navigate_history(-1)
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_DOWN:
		_navigate_history(1)
		get_viewport().set_input_as_handled()
		return
	if (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) \
			and not key.shift_pressed:
		_submit()
		get_viewport().set_input_as_handled()


func _open_console() -> void:
	_open = true
	_paused_before_open = get_tree().paused
	_mouse_before_open = Input.get_mouse_mode()
	_focus_before_open = get_viewport().gui_get_focus_owner()
	_root.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_input_box.editable = true
	_input_box.grab_focus()
	_set_status("Type /help for commands.", COL_INFO)
	_update_completion()


func _close_console() -> void:
	_open = false
	_root.visible = false
	_hide_completion()
	_input_box.release_focus()
	Input.set_mouse_mode(_mouse_before_open)
	get_tree().paused = _paused_before_open
	if is_instance_valid(_focus_before_open) and _focus_before_open.is_inside_tree():
		_focus_before_open.grab_focus()
	_focus_before_open = null


func _submit() -> void:
	var line := _input_box.text.strip_edges()
	if line == "":
		return
	if not line.begins_with("/"):
		_set_status("Commands begin with /. Type /help for the list.", COL_WARN)
		return
	if _history.is_empty() or _history.back() != line:
		_history.append(line)
		if _history.size() > HISTORY_LIMIT:
			_history.pop_front()
	_history_index = -1
	_history_draft = ""
	_hide_completion()
	_run_command(line)
	if _open:
		_input_box.text = ""
		_move_caret_end()
		_input_box.grab_focus()


func _run_command(line: String) -> void:
	var parts := line.substr(1).strip_edges().split(" ", false)
	if parts.is_empty():
		_show_help()
		return
	var command := String(parts[0]).to_lower()
	var argument := StringName(parts[1]) if parts.size() > 1 else &""
	match command:
		"help":
			_show_help()
		"god":
			_show_result(DevCommands.toggle_god())
		"grant":
			_show_result(DevCommands.grant(argument))
		"upgrade":
			_show_result(DevCommands.upgrade(argument))
		"tp":
			_dev_travel(argument)
		"puzzles":
			_show_puzzles()
		"puzzle":
			_open_puzzle(argument)
		_:
			_set_status("Unknown command '/%s'. Type /help." % command, COL_WARN)


func _dev_travel(destination: StringName) -> void:
	if Flow.busy:
		_set_status("Flow is already changing scenes.", COL_WARN)
		return
	match destination:
		&"town":
			_close_console()
			Flow.dev_to_town()
		&"dungeon":
			_close_console()
			Flow.dev_to_dungeon(1)
		&"dungeon2":
			_close_console()
			Flow.dev_to_dungeon(2)
		&"dungeon3":
			_close_console()
			Flow.dev_to_dungeon(3)
		_:
			_set_status("Usage: /tp <town|dungeon|dungeon2|dungeon3>", COL_WARN)


func _open_puzzle(id: StringName) -> void:
	if id == &"":
		_set_status("Usage: /puzzle <puzzle_id>. Use /puzzles for ids.", COL_WARN)
		return
	if not DevPuzzleCatalogue.has_fixture(id):
		_set_status("Unknown puzzle '%s'. Use /puzzles for valid ids." % String(id),
			COL_WARN)
		return
	if Flow.busy:
		_set_status("Flow is already changing scenes.", COL_WARN)
		return
	_close_console()
	Flow.dev_open_puzzle(id)


func _show_puzzles() -> void:
	var stock: Array[String] = []
	for id: StringName in PuzzleAtoms.all():
		stock.append(String(id))
	var complex: Array[String] = []
	for fixture: Dictionary in DevPuzzleCatalogue.all():
		var id: StringName = fixture["id"]
		if not PuzzleAtoms.has_atom(id):
			complex.append(String(id))
	_set_status("Puzzle fixtures (%d):\nStock atoms: %s\nComplex grammars: %s" % [
		stock.size() + complex.size(), ", ".join(stock), ", ".join(complex),
	], COL_INFO)


func _show_help() -> void:
	var lines: Array[String] = ["Developer commands:"]
	for command: Dictionary in COMMANDS:
		var usage := "/%s" % command["name"]
		if command["args"] != "":
			usage += " %s" % command["args"]
		lines.append("%-42s %s" % [usage, command["description"]])
	lines.append("Type / to autocomplete · Up/Down history · Esc or ` closes")
	_set_status("\n".join(lines), COL_INFO)


func _show_result(result: Dictionary) -> void:
	_set_status(String(result.get("message", "")),
		COL_OK if bool(result.get("ok", false)) else COL_WARN)


func _update_completion() -> void:
	if not _open:
		return
	var text := _input_box.text
	if not text.begins_with("/") or text.contains(" ") or text.contains("\n"):
		_hide_completion()
		return
	var token := text.substr(1).to_lower()
	_matches.clear()
	for command: Dictionary in COMMANDS:
		if String(command["name"]).begins_with(token):
			_matches.append(command)
	if _matches.is_empty():
		_hide_completion()
		return
	_completion.clear()
	for command: Dictionary in _matches:
		var usage := "/%s" % command["name"]
		if command["args"] != "":
			usage += " %s" % command["args"]
		_completion.add_item("%-42s — %s" % [usage, command["description"]])
	_completion_index = 0
	_completion.select(0)
	_completion.visible = true


func _move_completion(direction: int) -> void:
	if _matches.is_empty():
		return
	_completion_index = wrapi(_completion_index + direction, 0, _matches.size())
	_completion.select(_completion_index)
	_completion.ensure_current_is_visible()


func _accept_completion() -> void:
	if _matches.is_empty():
		return
	var command: Dictionary = _matches[_completion_index]
	_input_box.text = "/%s%s" % [command["name"],
		" " if command["args"] != "" else ""]
	_hide_completion()
	_move_caret_end()
	_input_box.grab_focus()


func _on_completion_clicked(index: int, _position: Vector2,
		_mouse_button_index: int) -> void:
	_completion_index = index
	_accept_completion()


func _hide_completion() -> void:
	if _completion != null:
		_completion.visible = false
		_completion.clear()
	_matches.clear()
	_completion_index = 0


func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index == -1:
		if direction > 0:
			return
		_history_draft = _input_box.text
		_history_index = _history.size() - 1
	else:
		_history_index += direction
		if _history_index < 0:
			_history_index = 0
			return
		if _history_index >= _history.size():
			_history_index = -1
			_input_box.text = _history_draft
			_move_caret_end()
			return
	_input_box.text = _history[_history_index]
	_move_caret_end()


func _move_caret_end() -> void:
	var line := _input_box.get_line_count() - 1
	_input_box.set_caret_line(line)
	_input_box.set_caret_column(_input_box.get_line(line).length())


func _set_status(message: String, color: Color) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", color)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -500.0
	panel.offset_right = 500.0
	panel.offset_top = 36.0
	panel.custom_minimum_size = Vector2(1000.0, 0.0)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "DEVELOPER CONSOLE"
	title.focus_mode = Control.FOCUS_NONE
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	column.add_child(title)

	_status = Label.new()
	_status.text = "Type /help for commands."
	_status.focus_mode = Control.FOCUS_NONE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0.0, 62.0)
	column.add_child(_status)

	_input_box = TextEdit.new()
	_input_box.name = "Command"
	_input_box.custom_minimum_size = Vector2(0.0, 92.0)
	_input_box.placeholder_text = "/help"
	_input_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input_box.focus_mode = Control.FOCUS_ALL
	_input_box.text_changed.connect(_update_completion)
	column.add_child(_input_box)

	_completion = ItemList.new()
	_completion.name = "Autocomplete"
	_completion.custom_minimum_size = Vector2(0.0, 220.0)
	_completion.focus_mode = Control.FOCUS_NONE
	_completion.visible = false
	_completion.item_clicked.connect(_on_completion_clicked)
	_completion.item_activated.connect(func(index: int) -> void:
		_completion_index = index
		_accept_completion())
	column.add_child(_completion)

	var hint := Label.new()
	hint.text = "Type / to autocomplete · ↑↓ choose/history · Tab/Enter accept · Esc / ` close"
	hint.focus_mode = Control.FOCUS_NONE
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
	column.add_child(hint)
