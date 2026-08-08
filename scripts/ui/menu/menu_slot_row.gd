class_name MenuSlotRow
extends Button
## One save slot card, filled entirely from `Saves.peek(slot)`.
##
## A used slot shows hearts, rupees, keys, room and timestamp. An empty one says
## "Empty" and — in Load mode — disables itself, so loading nothing is
## impossible rather than merely discouraged.

const CARD_HEIGHT := 118
const PAD_X := 18
const PAD_Y := 12

var slot: int = 0
var is_empty := true
var header: Dictionary = {}

var _title: Label
var _stamp: Label
var _stats: HBoxContainer
var _empty_label: Label


func _init() -> void:
	theme_type_variation = &"MenuSlot"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = CARD_HEIGHT


func _ready() -> void:
	var col := VBoxContainer.new()
	col.name = "Col"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = PAD_X
	col.offset_right = -PAD_X
	col.offset_top = PAD_Y
	col.offset_bottom = -PAD_Y

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	_title = Label.new()
	_title.theme_type_variation = &"MenuSlotTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)

	_stamp = Label.new()
	_stamp.theme_type_variation = &"MenuMuted"
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_stamp)

	_stats = HBoxContainer.new()
	_stats.theme_type_variation = &"MenuStatRow"
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_stats)

	_empty_label = Label.new()
	_empty_label.theme_type_variation = &"MenuMuted"
	_empty_label.text = "Empty"
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_empty_label)

	refresh()


func setup(s: int) -> void:
	slot = s
	if not is_node_ready():
		await ready
	refresh()


## Re-read the slot header from disk and redraw the card.
func refresh() -> void:
	if _title == null:
		return
	header = Saves.peek(slot)
	is_empty = bool(header.get("empty", true))
	_title.text = "SLOT %d" % (slot + 1)

	for child in _stats.get_children():
		child.queue_free()

	if is_empty:
		_stamp.text = ""
		_stats.visible = false
		_empty_label.visible = true
		_empty_label.text = "Corrupt save — erase to reuse" if header.get("corrupt", false) else "Empty"
		return

	_stats.visible = true
	_empty_label.visible = false
	_stamp.text = String(header.get("stamp", ""))
	_add_stat("HEARTS", MenuUtil.hearts_text(
		float(header.get("hearts", 0.0)), float(header.get("max_hearts", 0.0))))
	# JSON hands every number back as a float; rupees and keys are counters.
	_add_stat("RUPEES", "%d" % int(header.get("rupees", 0)))
	_add_stat("KEYS", "%d" % int(header.get("keys", 0)))
	var room := String(header.get("room", ""))
	_add_stat("ROOM", room if room != "" else "—")


func _add_stat(caption: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.theme_type_variation = &"MenuStatCol"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap := Label.new()
	cap.theme_type_variation = &"MenuHint"
	cap.text = caption
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)

	var val := Label.new()
	val.theme_type_variation = &"MenuValue"
	val.text = value
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(val)

	_stats.add_child(col)
