class_name MenuSliderRow
extends Button
## One settings row that holds a slider: "Master   [======----]   90%".
##
## The ROW is the focusable thing, not the slider — so every row in the menu
## focuses, highlights and navigates identically, and a pad user never has to
## know that this one happens to contain a different widget.
##
## Left/Right adjust, and HOLDING left or right repeats and accelerates — on a
## key, a D-pad or the stick, identically. That last part is the whole reason
## the repeat is polled: a pad emits one event for a five-second hold, so an
## event-driven slider costs one press per step.
##
## The value is always printed next to the bar; a settings screen where you
## cannot read the number is broken.

signal value_changed(value: float)
## Fired ONCE when the player lets go — mouse drag end, or the held direction
## (key, D-pad or stick) going back to zero. Never per repeat step, or a sweep
## would machine-gun the click.
## The menu answers this with a click on the UI bus so the level can be heard.
signal settled(value: float)

enum Format { PERCENT, MULTIPLIER, DEGREES, RAW }

const ROW_HEIGHT := 46
const TITLE_WIDTH := 260
const VALUE_WIDTH := 96
const PAD_X := 16
const PAD_Y := 4

## Seconds a direction must be held before the repeat starts. Below this, one
## press is one step, so a tap still nudges by exactly one.
@export var repeat_delay := 0.35
## Steps per second the moment the repeat starts…
@export var repeat_rate_start := 12.0
## …ramping to this once the player has clearly committed to a long sweep.
@export var repeat_rate_max := 40.0
## Seconds spent ramping from `repeat_rate_start` to `repeat_rate_max`.
@export var repeat_ramp := 1.2

var format: Format = Format.PERCENT

var _title: Label
var _slider: HSlider
var _value: Label
var _dirty := false
var _quiet := false
# Held-repeat state. -1 / 0 / +1, seconds held, and the leftover fraction of a
# repeat period carried between frames so the rate is exact, not frame-quantised.
var _dir := 0.0
var _held := 0.0
var _accum := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = ROW_HEIGHT
	clip_contents = false


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

	UiKit.style_row_button(self)

	_title = Label.new()
	UITheme.apply_text_style(_title, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	_title.custom_minimum_size.x = TITLE_WIDTH
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)

	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The row owns focus; the slider is only a display + mouse target.
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider.value_changed.connect(_on_slider_value_changed)
	_slider.drag_started.connect(_on_drag_started)
	_slider.drag_ended.connect(_on_drag_ended)
	box.add_child(_slider)

	_value = Label.new()
	UITheme.apply_text_style(_value, UITheme.TYPE_LABEL_MD, UITheme.ACCENT)
	_value.custom_minimum_size.x = VALUE_WIDTH
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_value)

	_refresh_text()
	# The repeat is polled, not event-driven — see _process().
	set_process(true)


## Configure the row. Call before or after _ready(); both work.
func setup(title: String, min_v: float, max_v: float, step_v: float, fmt: Format) -> void:
	format = fmt
	if not is_node_ready():
		await ready
	_title.text = title
	_slider.min_value = min_v
	_slider.max_value = max_v
	_slider.step = step_v
	_refresh_text()


var value: float:
	get:
		return _slider.value if _slider else 0.0
	set(v):
		set_value_silent(v)


## Push a value in from Settings without echoing it back out as a change.
func set_value_silent(v: float) -> void:
	if _slider == null:
		return
	_quiet = true
	_slider.value = v
	_quiet = false
	_refresh_text()


## Only the INITIAL press is event-driven. Echo is deliberately NOT accepted:
## the OS repeat that produces it exists for keyboards alone, and letting it
## through as well as the poll below would make an arrow key move at double a
## D-pad's speed. One repeat source, both devices.
func _gui_input(event: InputEvent) -> void:
	if _slider == null:
		return
	if event.is_action_pressed(&"ui_left", false):
		_begin(-1.0)
		accept_event()
	elif event.is_action_pressed(&"ui_right", false):
		_begin(1.0)
		accept_event()


## Held-input repeat, POLLED once a frame.
##
## A joypad emits exactly ONE event when a button is held or a stick is pushed —
## there is no key-echo behind it — so an adjust driven off press events costs
## one press per step. That made a 100-step volume slider a hundred D-pad
## presses while an arrow key swept it in a second, and the footer claimed both
## devices did the same thing. Polling `Input` is the only source that treats a
## held button, a held stick and a held key identically.
##
## This runs while the tree is paused because the menu's CanvasLayer is
## PROCESS_MODE_ALWAYS and the rows inherit it.
func _process(delta: float) -> void:
	if _slider == null or not is_visible_in_tree() or not has_focus():
		_release()
		return
	var dir := (1.0 if Input.is_action_pressed(&"ui_right") else 0.0) \
		- (1.0 if Input.is_action_pressed(&"ui_left") else 0.0)
	if is_zero_approx(dir):
		_release()
		return
	if not is_equal_approx(dir, _dir):
		# Reversed without passing through zero, or arrived at this row with the
		# direction already down. Start the delay again rather than firing at
		# whatever rate the previous direction had wound up to.
		_dir = dir
		_held = 0.0
		_accum = 0.0
		return
	_held += delta
	if _held < repeat_delay:
		return
	_accum += delta
	var rate := lerpf(repeat_rate_start, repeat_rate_max,
		clampf((_held - repeat_delay) / repeat_ramp, 0.0, 1.0))
	var period := 1.0 / maxf(rate, 0.001)
	while _accum >= period:
		_accum -= period
		_nudge(dir)


func _begin(dir: float) -> void:
	_dir = dir
	_held = 0.0
	_accum = 0.0
	_nudge(dir)


## Direction back to zero: wind the repeat down and settle ONCE, not per step.
func _release() -> void:
	_dir = 0.0
	_held = 0.0
	_accum = 0.0
	_settle()


func _nudge(dir: float) -> void:
	var step: float = _slider.step if _slider.step > 0.0 else 0.05
	_slider.value = clampf(_slider.value + dir * step, _slider.min_value, _slider.max_value)


func _settle() -> void:
	if not _dirty:
		return
	_dirty = false
	settled.emit(_slider.value)


func _on_slider_value_changed(v: float) -> void:
	_refresh_text()
	if _quiet:
		return
	_dirty = true
	value_changed.emit(v)


func _on_drag_started() -> void:
	# Clicking the bar should also move focus here, or the highlight lies.
	if focus_mode != Control.FOCUS_NONE:
		grab_focus()


func _on_drag_ended(changed: bool) -> void:
	if changed:
		_dirty = true
	_settle()


func _refresh_text() -> void:
	if _value == null or _slider == null:
		return
	match format:
		Format.PERCENT:
			_value.text = MenuUtil.percent(_slider.value)
		Format.MULTIPLIER:
			_value.text = MenuUtil.multiplier(_slider.value)
		Format.DEGREES:
			_value.text = MenuUtil.signed_degrees(_slider.value)
		_:
			_value.text = String.num(_slider.value, 2)
