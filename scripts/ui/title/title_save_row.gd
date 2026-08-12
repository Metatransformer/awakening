extends Button
## Compact title-screen presentation for one readable `Saves.peek(slot)` header.
## The parent owns ordering and actions; this component owns only the four lines
## a returning player needs to identify a save.

const ROW_SIZE := Vector2(680.0, 84.0)
const PAD_X := 16
const PAD_Y := 9

var slot := -1
var header: Dictionary = {}

var _title: Label
var _last_played: Label
var _progress: Label
var _gold: Label


func _init() -> void:
	theme_type_variation = &"MenuSlot"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = ROW_SIZE


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAD_X)
	margin.add_theme_constant_override("margin_right", PAD_X)
	margin.add_theme_constant_override("margin_top", PAD_Y)
	margin.add_theme_constant_override("margin_bottom", PAD_Y)
	add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Content"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(_title, UITheme.TYPE_H3, UITheme.ACCENT)
	row.add_child(_title)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var facts := VBoxContainer.new()
	facts.name = "Facts"
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	facts.add_theme_constant_override("separation", 1)
	row.add_child(facts)

	_last_played = _fact("LastPlayed")
	facts.add_child(_last_played)
	_progress = _fact("Progress")
	facts.add_child(_progress)
	_gold = _fact("Gold")
	facts.add_child(_gold)

	_refresh()


func setup(head: Dictionary) -> void:
	header = head.duplicate()
	slot = int(header.get("slot", -1))
	if is_node_ready():
		_refresh()


func _fact(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(label, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	return label


func _refresh() -> void:
	if _title == null:
		return
	_title.text = "SLOT %d" % (slot + 1)
	_last_played.text = "LAST PLAYED  %s" % _friendly_stamp(
		String(header.get("stamp", "")))
	_progress.text = "PROGRESS  %s" % _progress_text(header)
	_gold.text = "GOLD  %s" % _grouped_int(int(header.get("gold", 0)))


## The stamp is already local wall-clock text. Formatting it directly avoids
## converting it through Unix time and applying a timezone for a second time.
func _friendly_stamp(stamp: String) -> String:
	if stamp.is_empty():
		return "UNKNOWN"
	var friendly := stamp.replace("T", " ")
	return friendly.substr(0, mini(16, friendly.length()))


func _progress_text(head: Dictionary) -> String:
	if not bool(head.get("in_dungeon", false)):
		return "GARRISON"
	return "FLOOR %d · DEPTH %d" % [
		int(head.get("level", 1)),
		int(head.get("depth", 0)),
	]


func _grouped_int(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = ",%s%s" % [digits.substr(digits.length() - 3, 3), grouped]
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped
