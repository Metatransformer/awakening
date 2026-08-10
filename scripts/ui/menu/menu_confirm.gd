class_name MenuConfirm
extends Control
## The one modal in the menu: "Overwrite slot 2?", "Erase slot 1?", "Quit?".
##
## It is its own focus context — it dims what is behind it, takes focus, and
## hands it back to whoever called `ask()` when it resolves. Destructive
## questions start focused on the safe answer.
##
## It carries the kit's paint of its own rather than inheriting the pause menu's
## Root theme, because it is raised over screens that have converted and screens
## that have not, and a modal that changes its face depending on which one asked
## the question is a modal the player stops reading.

signal resolved(accepted: bool)

const PANEL_WIDTH := 560

var _title: Label
var _body: Label
var _yes: Button
var _no: Button
var _return_focus: Control = null
var _pending := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	UITheme.prewarm()
	theme = UITheme.theme()

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	# The floating-card face, not the window face: this panel is raised OVER a
	# screen rather than being one, which is the distinction `hover_card` exists
	# for. `style_panel_opaque` would be the flat grey slab of a full-screen
	# gate -- lighter than every other surface in the menu, and borderless.
	frame.add_theme_stylebox_override("panel", UITheme.hover_card())
	frame.clip_contents = true
	frame.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(frame)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	frame.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)

	_title = Label.new()
	UITheme.apply_text_style(_title, UITheme.TYPE_H2, UITheme.TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_body = Label.new()
	UITheme.apply_text_style(_body, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.y = 52
	col.add_child(_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)

	_yes = Button.new()
	_yes.custom_minimum_size.x = 180
	UITheme.style_pill_button(_yes)
	# The strong rim, not the standard one. There are exactly two controls here
	# and one of them erases a save; which one the cursor is on is the single
	# most important thing the dialog draws.
	_yes.add_theme_stylebox_override("focus", UITheme.focus_rim(true))
	_yes.pressed.connect(_on_yes)
	buttons.add_child(_yes)

	_no = Button.new()
	_no.custom_minimum_size.x = 180
	UITheme.style_pill_button(_no)
	_no.add_theme_stylebox_override("focus", UITheme.focus_rim(true))
	_no.pressed.connect(_on_no)
	buttons.add_child(_no)

	MenuUtil.link_right(_yes, _no)
	_yes.focus_neighbor_top = _yes.get_path_to(_no)
	_yes.focus_neighbor_bottom = _yes.get_path_to(_no)
	_no.focus_neighbor_top = _no.get_path_to(_yes)
	_no.focus_neighbor_bottom = _no.get_path_to(_yes)


## Pose a question. `danger` starts focus on the safe answer so a mashed
## confirm cannot erase a save.
func ask(title: String, body: String, ok_text: String, cancel_text: String,
		danger: bool, return_focus: Control = null) -> void:
	_title.text = title
	_body.text = body
	_yes.text = ok_text
	_no.text = cancel_text
	# DANGER is on the WORD, not the box. The safe answer is the one that is
	# focused, and a red slab beside it would fight that -- the loudest thing in
	# a destructive dialog should be where the cursor already is.
	var yes_color: Color = UITheme.DANGER if danger else UITheme.TEXT
	for state in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color"]:
		_yes.add_theme_color_override(state, yes_color)
	_return_focus = return_focus
	_pending = true
	visible = true
	if danger:
		_no.grab_focus()
	else:
		_yes.grab_focus()


var is_asking: bool:
	get:
		return _pending


## Escape / B while the modal is up answers "no".
func cancel() -> void:
	_on_no()


func _on_yes() -> void:
	_finish(true)


func _on_no() -> void:
	_finish(false)


func _finish(accepted: bool) -> void:
	if not _pending:
		return
	_pending = false
	visible = false
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	resolved.emit(accepted)
