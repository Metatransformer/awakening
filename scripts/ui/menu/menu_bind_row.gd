class_name MenuBindRow
extends Button
## One row of the controls list: "Attack        J        X".
##
## Left column is the action, middle is the keyboard/mouse binding as Settings
## reports it, right is the gamepad binding decoded from the live InputMap.
## Pressing the row asks the menu to start listening for a new key.

signal rebind_requested(action: StringName)

const ROW_HEIGHT := 44
const TITLE_WIDTH := 250
const KEY_WIDTH := 190
const PAD_WIDTH := 150
const PAD_X := 16
const PAD_Y := 3

var action: StringName = &""

var _title: Label
var _key: Label
var _pad: Label


func _init() -> void:
	theme_type_variation = &"MenuRow"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = ROW_HEIGHT


func _ready() -> void:
	var box := HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = PAD_X
	box.offset_right = -PAD_X
	box.offset_top = PAD_Y
	box.offset_bottom = -PAD_Y

	_title = Label.new()
	_title.custom_minimum_size.x = TITLE_WIDTH
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	_key = Label.new()
	_key.theme_type_variation = &"MenuValue"
	_key.custom_minimum_size.x = KEY_WIDTH
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_key)

	_pad = Label.new()
	_pad.theme_type_variation = &"MenuMuted"
	_pad.custom_minimum_size.x = PAD_WIDTH
	_pad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pad)

	pressed.connect(func() -> void: rebind_requested.emit(action))
	refresh()


func setup(a: StringName) -> void:
	action = a
	if not is_node_ready():
		await ready
	refresh()


## Re-read both columns straight out of Settings / InputMap.
func refresh() -> void:
	if _title == null:
		return
	_title.text = MenuUtil.action_title(action)
	_key.text = MenuUtil.key_label(action)
	_pad.text = MenuUtil.pad_label(action)
