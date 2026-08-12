class_name MenuSlotRow
extends Button
## One save slot card, filled entirely from `Saves.peek(slot)`.
##
## A used slot shows hearts, gold, keys, room and timestamp. An empty one says
## "Empty" and — in Load mode — disables itself, so loading nothing is
## impossible rather than merely discouraged.
##
## In Load mode that unusable card follows the kit's REFUSAL LAW (see
## `VerbRow`): it stays on screen at 38% with its reason readable at full
## contrast, rather than vanishing. Three slots that become one slot when you
## switch to LOAD is a screen that has moved under the player's hands — the row
## has to hold its place and say why it cannot be picked.
##
## The card's PLATE comes from the `MenuSlot` variation, which both themes
## define (`UITheme._style_shared_cells`). Its type is set by explicit override,
## so the card reads the same on a converted screen and an unconverted one.

const CARD_HEIGHT := 118
const PAD_X := 18
const PAD_Y := 12
## Matches `VerbRow.REFUSED_ALPHA`. One number, two components, same law.
const REFUSED_ALPHA := 0.38

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
	UITheme.apply_text_style(_title, UITheme.TYPE_LABEL_MD, UITheme.TEXT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)

	_stamp = Label.new()
	UITheme.apply_text_style(_stamp, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_stamp)

	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 34)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_stats)

	_empty_label = Label.new()
	UITheme.apply_text_style(_empty_label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
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
	# JSON hands every number back as a float; gold and keys are counters.
	_add_stat("GOLD", "%d" % int(header.get("gold", 0)))
	_add_stat("KEYS", "%d" % int(header.get("keys", 0)))
	var room := String(header.get("room", ""))
	_add_stat("ROOM", room if room != "" else "—")


## The card is unusable and says so. `reason` empty puts it back.
##
## The reason's own modulate is pushed the other way so it lands at full DANGER
## contrast through the dimmed card -- the same trick, and the same reason, as
## `VerbRow`'s meta column: what a refused row is FOR is the sentence explaining
## it, and dimming that with the rest hides the only useful thing on the row.
func refuse(reason: String) -> void:
	if _empty_label == null:
		return
	if reason.is_empty():
		modulate.a = 1.0
		_empty_label.modulate.a = 1.0
		if is_empty:
			UITheme.apply_text_style(_empty_label, UITheme.TYPE_PARAGRAPH_2,
				UITheme.TEXT_DIM)
		return
	modulate.a = REFUSED_ALPHA
	_empty_label.visible = true
	_empty_label.text = reason
	UITheme.apply_text_style(_empty_label, UITheme.TYPE_PARAGRAPH_2, UITheme.DANGER)
	_empty_label.modulate.a = minf(1.0 / REFUSED_ALPHA, 4.0)


## A caption over a number, in the band's voice -- the same shape the header
## bands use, because a slot card IS four stats about a save.
func _add_stat(caption: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var val := Label.new()
	UITheme.apply_text_style(val, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	val.text = value
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(val)

	var cap := Label.new()
	UITheme.apply_text_style(cap, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	cap.text = caption
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)

	_stats.add_child(col)
