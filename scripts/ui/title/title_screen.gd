class_name TitleScreen
extends Control
## The first screen. Three answers to one question: carry on, start over, leave.
##
## CONTINUE opens the readable saves, newest first. The title menu itself stays
## fixed at CONTINUE / NEW GAME / QUIT so a player's history never moves its
## first decision under their hands. `Flow` owns everything past a slot press;
## nothing here calls `change_scene_to_file` (docs/CONTRACT.md §7).

const BG := "res://assets/ui/title/title_bg.jpg"
const TITLE_SAVE_ROW := preload("res://scripts/ui/title/title_save_row.gd")

## The name, split where it wants to break. `Cinzel` is a capitals face and the
## project's display voice (`UITheme.display_font`); the subtitle is the same
## face, smaller and letterspaced, so the two lines read as one inscription.
const TITLE := "THE LOWER WORLDS"
const SUBTITLE := "A W A K E N I N G"

## Baselines as fractions of the frame. The picker starts higher than the small
## title menu so three compact rows and Back fit in the 720p director frame.
const TITLE_Y := 0.20
const MENU_Y := 0.55
const PICKER_Y := 0.39
const BUTTON_W := 300.0

var _bg: TextureRect
var _menu: VBoxContainer
var _continue: Button
var _new_game: Button
var _quit: Button

var _picker: VBoxContainer
var _rows_box: VBoxContainer
var _back: Button
var _rows: Array[Button] = []
var _headers: Array[Dictionary] = []
var _failed_slots: Dictionary = {}
var _transition_locked := false


func _ready() -> void:
	name = "TitleScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UITheme.prewarm()
	theme = UITheme.theme()
	# The game captures the pointer for camera look. Nothing has yet on the first
	# frame of the process, but a future quit-to-title returns through this node.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_headers = _readable_headers()
	_build()
	_sync_interactions()
	# The container still has zero-sized children during `_ready`; defer the rim
	# until the first layout pass has established the button rectangles.
	await get_tree().process_frame
	_focus_main_default()


# --- Look -------------------------------------------------------------------

func _build() -> void:
	_bg = TextureRect.new()
	_bg.name = "Plate"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Crop, do not letterbox. See the same note in `Cutscene._build`.
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG):
		_bg.texture = load(BG) as Texture2D
	else:
		push_error("TitleScreen: no such image %s" % BG)
	add_child(_bg)

	# A column of shade down the middle, not a wash over everything. The
	# painting's two halves are the reason the type is centred at all.
	var scrim := TextureRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	var ramp := GradientTexture2D.new()
	ramp.fill = GradientTexture2D.FILL_LINEAR
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(1.0, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.30, 0.70, 1.0])
	g.colors = PackedColorArray([
		Color(Pal.VOID, 0.0),
		Color(Pal.VOID, 0.62),
		Color(Pal.VOID, 0.62),
		Color(Pal.VOID, 0.0),
	])
	ramp.gradient = g
	scrim.texture = ramp
	add_child(scrim)

	var col := VBoxContainer.new()
	col.name = "Name"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	col.anchor_top = TITLE_Y
	col.offset_top = 0.0
	col.offset_bottom = 0.0
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(_inscription(TITLE, 54))
	col.add_child(_inscription(SUBTITLE, 24, UITheme.ACCENT))

	_build_main_menu()
	_build_picker()


func _build_main_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_menu.anchor_top = MENU_Y
	_menu.offset_top = 0.0
	_menu.offset_bottom = 0.0
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 14)
	add_child(_menu)

	_continue = _button("CONTINUE", _on_continue, _menu)
	_new_game = _button("NEW GAME", _on_new_game, _menu)
	_quit = _button("QUIT", _on_quit, _menu)


func _build_picker() -> void:
	_picker = VBoxContainer.new()
	_picker.name = "Picker"
	_picker.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_picker.anchor_top = PICKER_Y
	_picker.anchor_bottom = PICKER_Y
	_picker.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker.add_theme_constant_override("separation", 10)
	_picker.visible = false
	add_child(_picker)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override("separation", 8)
	_rows_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker.add_child(_rows_box)

	_back = _button("BACK", _on_back, _picker)
	_back.name = "Back"


## One line of the name. Cinzel with a heavy outline: the sky behind the top line
## is the brightest part of the frame and a serif face on cloud needs one.
func _inscription(text: String, px: int, tint: Color = UITheme.TEXT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(l, UITheme.TYPE_TITLE, tint)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(Pal.VOID, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(Pal.VOID, 0.55))
	return l


func _button(text: String, on_press: Callable, parent: Container) -> Button:
	var b := Button.new()
	UITheme.style_pill_button(b)
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(BUTTON_W, 0.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


# --- Saves ------------------------------------------------------------------

## Re-read the disk and re-derive what is reachable. The optional focus is the
## least invasive in-process seam used by the title director to prove cold and
## populated disks without loading a second scene.
func _refresh_saves(focus_default := false) -> void:
	_headers = _readable_headers()
	if _picker.visible:
		_rebuild_picker()
	_sync_interactions()
	if focus_default:
		if _picker.visible:
			_focus_first_picker()
		else:
			_focus_main_default()


func _readable_headers() -> Array[Dictionary]:
	var headers: Array[Dictionary] = []
	for i in Saves.SLOTS:
		var head: Dictionary = Saves.peek(i)
		if bool(head.get("empty", true)) or bool(head.get("corrupt", false)):
			continue
		head = head.duplicate()
		head["slot"] = i
		headers.append(head)

	# Numeric write time is authoritative. Legacy/matching write times fall back
	# to the ISO stamp, then the physical slot keeps the result deterministic.
	headers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := float(a.get("last_played_unix", 0.0))
		var b_time := float(b.get("last_played_unix", 0.0))
		if a_time != b_time:
			return a_time > b_time
		var a_stamp := String(a.get("stamp", ""))
		var b_stamp := String(b.get("stamp", ""))
		if a_stamp != b_stamp:
			return a_stamp > b_stamp
		return int(a.get("slot", 0)) < int(b.get("slot", 0))
	)
	return headers


func _rebuild_picker() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()

	for head: Dictionary in _headers:
		var row := TITLE_SAVE_ROW.new() as Button
		var slot := int(head.get("slot", -1))
		row.name = "Slot%d" % (slot + 1)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_rows_box.add_child(row)
		row.call(&"setup", head)
		row.pressed.connect(func() -> void: _on_slot_pressed(slot))
		_rows.append(row)
	_sync_interactions()
	_wire_picker_focus()


# --- Views and focus --------------------------------------------------------

func _show_picker() -> void:
	_refresh_saves()
	if _headers.is_empty():
		_focus_main_default()
		return
	_rebuild_picker()
	_menu.visible = false
	_picker.visible = true
	_focus_first_picker.call_deferred()


func _show_main() -> void:
	_picker.visible = false
	_menu.visible = true
	_focus_main_default.call_deferred()


func _focus_main_default() -> void:
	var first := _continue if not _continue.disabled else _new_game
	first.grab_focus()


func _focus_first_picker() -> void:
	for row: Button in _rows:
		if not row.disabled and row.focus_mode != Control.FOCUS_NONE:
			row.grab_focus()
			return
	_back.grab_focus()


func _wire_picker_focus() -> void:
	var focusable: Array[Button] = []
	for row: Button in _rows:
		if not row.disabled and row.focus_mode != Control.FOCUS_NONE:
			focusable.append(row)

	for i in focusable.size():
		var row := focusable[i]
		var up: Control = focusable[i - 1] if i > 0 else _back
		var down: Control = focusable[i + 1] if i < focusable.size() - 1 else _back
		row.focus_neighbor_top = row.get_path_to(up)
		row.focus_neighbor_bottom = row.get_path_to(down)
		row.focus_previous = row.get_path_to(up)
		row.focus_next = row.get_path_to(down)
		row.focus_neighbor_left = ^"."
		row.focus_neighbor_right = ^"."

	if focusable.is_empty():
		_back.focus_neighbor_top = ^"."
		_back.focus_neighbor_bottom = ^"."
		_back.focus_previous = ^"."
		_back.focus_next = ^"."
	else:
		_back.focus_neighbor_top = _back.get_path_to(focusable.back())
		_back.focus_neighbor_bottom = _back.get_path_to(focusable.front())
		_back.focus_previous = _back.get_path_to(focusable.back())
		_back.focus_next = _back.get_path_to(focusable.front())
	_back.focus_neighbor_left = ^"."
	_back.focus_neighbor_right = ^"."


func _unhandled_input(event: InputEvent) -> void:
	if _picker.visible and not _transition_locked and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_main()


# --- Actions ----------------------------------------------------------------

func _on_continue() -> void:
	if _transition_locked or _headers.is_empty():
		return
	_show_picker()


func _on_slot_pressed(slot: int) -> void:
	if _transition_locked or _failed_slots.has(slot):
		return
	_lock()
	# The slot passed `peek` and can still fail the full read. Refuse only that
	# row and return an operable picker instead of leaving every choice dead.
	if not await Flow.continue_game(slot):
		_failed_slots[slot] = true
		_unlock()
		_wire_picker_focus()
		_focus_first_picker()


func _on_back() -> void:
	if not _transition_locked:
		_show_main()


func _on_new_game() -> void:
	if _transition_locked:
		return
	_lock()
	Flow.new_game()


func _on_quit() -> void:
	if _transition_locked:
		return
	_lock()
	get_tree().quit()


## Deaden both title views for a transition. A second press during Flow's fade
## is a second travel request, so both the visible and hidden controls lock.
func _lock() -> void:
	_transition_locked = true
	_sync_interactions()


func _unlock() -> void:
	_transition_locked = false
	_sync_interactions()


func _sync_interactions() -> void:
	if _continue == null:
		return
	_continue.disabled = _transition_locked or _headers.is_empty()
	_continue.focus_mode = Control.FOCUS_NONE if _continue.disabled else Control.FOCUS_ALL
	_continue.tooltip_text = "No saved game." if _headers.is_empty() else ""
	_new_game.disabled = _transition_locked
	_new_game.focus_mode = Control.FOCUS_NONE if _transition_locked else Control.FOCUS_ALL
	_quit.disabled = _transition_locked
	_quit.focus_mode = Control.FOCUS_NONE if _transition_locked else Control.FOCUS_ALL

	for row: Button in _rows:
		var failed := _failed_slots.has(int(row.get("slot")))
		row.disabled = _transition_locked or failed
		row.focus_mode = Control.FOCUS_NONE if row.disabled else Control.FOCUS_ALL
		row.tooltip_text = "That save could not be loaded." if failed else ""
		row.modulate.a = 0.45 if failed else 1.0
	_back.disabled = _transition_locked
	_back.focus_mode = Control.FOCUS_NONE if _transition_locked else Control.FOCUS_ALL

	var alpha := 0.4 if _transition_locked else 1.0
	_menu.modulate.a = alpha
	_picker.modulate.a = alpha
