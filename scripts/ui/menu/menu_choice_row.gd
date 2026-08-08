class_name MenuChoiceRow
extends Button
## One settings row that cycles a fixed set of values: "MSAA   ‹  4x  ›".
##
## Deliberately not an OptionButton: a popup is a second focus context to escape
## from, and on a pad it is a trap. Left/Right cycle, Confirm cycles forward,
## and the current value is always on screen.
##
## Holding a direction repeats, for the same reason the slider does — a pad
## sends one event for a held D-pad — but at a deliberately slower, FLAT rate.
## A four-option list that accelerated would blow straight past the value the
## player wanted; a hundred-step slider that did not would take a hundred
## presses. Different widgets, different repeat.

signal choice_changed(index: int)

const ROW_HEIGHT := 46
const TITLE_WIDTH := 260
const VALUE_WIDTH := 200
const PAD_X := 16
const PAD_Y := 4

## Seconds a direction must be held before it starts cycling on its own. Longer
## than the slider's: one press must stay one step for much longer here.
@export var repeat_delay := 0.5
## Steps per second while held. Flat — no ramp.
@export var repeat_rate := 5.0

var options: Array[String] = []

var _title: Label
var _value: Label
var _index := 0
var _quiet := false
var _dir := 0
var _held := 0.0
var _accum := 0.0


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

	_value = Label.new()
	_value.theme_type_variation = &"MenuValue"
	_value.custom_minimum_size.x = VALUE_WIDTH
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_value)

	pressed.connect(_on_pressed)
	_refresh_text()
	# The repeat is polled, not event-driven — see _process().
	set_process(true)


func setup(title: String, choices: Array[String], start_index: int) -> void:
	options = choices
	_index = clampi(start_index, 0, maxi(choices.size() - 1, 0))
	if not is_node_ready():
		await ready
	_title.text = title
	_refresh_text()


var index: int:
	get:
		return _index
	set(v):
		set_index_silent(v)


func set_index_silent(v: int) -> void:
	_index = clampi(v, 0, maxi(options.size() - 1, 0))
	_refresh_text()


## Initial press only; the hold is polled below. Echo is not accepted, so a held
## arrow key and a held D-pad cycle at exactly the same rate.
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", false):
		_begin(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right", false):
		_begin(1)
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not has_focus():
		_release()
		return
	var dir := (1 if Input.is_action_pressed(&"ui_right") else 0) \
		- (1 if Input.is_action_pressed(&"ui_left") else 0)
	if dir == 0:
		_release()
		return
	if dir != _dir:
		_dir = dir
		_held = 0.0
		_accum = 0.0
		return
	_held += delta
	if _held < repeat_delay:
		return
	_accum += delta
	var period := 1.0 / maxf(repeat_rate, 0.001)
	while _accum >= period:
		_accum -= period
		_cycle(dir)


func _begin(dir: int) -> void:
	_dir = dir
	_held = 0.0
	_accum = 0.0
	_cycle(dir)


func _release() -> void:
	_dir = 0
	_held = 0.0
	_accum = 0.0


func _on_pressed() -> void:
	_cycle(1)


func _cycle(dir: int) -> void:
	if options.size() <= 1:
		return
	_index = (_index + dir + options.size()) % options.size()
	_refresh_text()
	if not _quiet:
		choice_changed.emit(_index)


func _refresh_text() -> void:
	if _value == null:
		return
	if options.is_empty():
		_value.text = "—"
		return
	_value.text = "‹  %s  ›" % options[clampi(_index, 0, options.size() - 1)]
