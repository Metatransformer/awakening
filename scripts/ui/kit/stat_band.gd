class_name StatBand
extends RefCounted
## The numbers that let a player choose BEFORE committing to the primary verb.
##
##     ┌──────────┬──────────┬──────────┬──────────┬──────────┐
##     │  ◇ 308   │  4 / 12  │  ◇ 1450  │   ◇ 77   │   +96    │
##     │   BAG    │  SLOTS   │  PURSE   │   FEE    │   HEAT   │
##     └──────────┴──────────┴──────────┴──────────┴──────────┘
##       equal cells, hairline-separated, one row, never wraps
##
## MAX_CELLS is the design, not a technicality. Seven cells is a spreadsheet;
## three is a sentence you should have written as prose. Over the cap the surplus
## is DROPPED and named in a warning rather than silently squeezed below
## legibility — a band that quietly degrades is how "4-6" becomes 9 over a year
## of small additions.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const KitIconScript := preload("res://scripts/ui/kit/kit_icon.gd")

const MAX_CELLS := 6
const MIN_CELLS := 4
const ICON_PX := 13
## The only colours a cell may take. Named here rather than checked inline, so
## the restriction is one list a reader can see and not a condition buried in a
## factory.
const TONES: Array[Color] = [UITheme.SUCCESS, UITheme.DANGER, UITheme.WARNING]


static func build(parent: Node, cells: Array) -> Control:
	if cells.is_empty():
		push_warning("[StatBand] reason=no cells supplied; band omitted")
		return null

	var rows: Array[Dictionary] = []
	for value: Variant in cells:
		if not value is Dictionary:
			push_error("[StatBand] reason=every cell must be a Dictionary; got %s"
				% type_string(typeof(value)))
			continue
		rows.append(value as Dictionary)

	if rows.size() > MAX_CELLS:
		var dropped: Array[String] = []
		for extra: Dictionary in rows.slice(MAX_CELLS):
			dropped.append(String(extra.get("label", extra.get("value", "?"))))
		push_warning("[StatBand] cells=%d max=%d dropped=%s reason=a stat band is capped; author fewer cells or split the panel"
			% [rows.size(), MAX_CELLS, ", ".join(dropped)])
		rows = rows.slice(0, MAX_CELLS)
	elif rows.size() < MIN_CELLS:
		push_warning("[StatBand] cells=%d min=%d reason=under four cells this wants to be prose, not a band"
			% [rows.size(), MIN_CELLS])

	var band := PanelContainer.new()
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.custom_minimum_size.y = 54.0
	band.add_theme_stylebox_override("panel", _band_box())

	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(line)

	for index in rows.size():
		if index > 0:
			line.add_child(_divider())
		line.add_child(_cell(rows[index]))

	if parent != null:
		parent.add_child(band)
	return band


static func _cell(row: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 4)
	var tooltip := String(row.get("tooltip", ""))
	if not tooltip.is_empty():
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.tooltip_text = tooltip

	var value_line := HBoxContainer.new()
	value_line.alignment = BoxContainer.ALIGNMENT_CENTER
	value_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_line.add_theme_constant_override("separation", 5)
	cell.add_child(value_line)

	if not row.has("value"):
		push_error("[StatBand] label='%s' reason=a cell needs a value; rendering a dash"
			% row.get("label", "?"))
	if String(row.get("label", "")).is_empty():
		push_error("[StatBand] value='%s' reason=a cell needs a caption; an unlabelled number is a riddle"
			% row.get("value", "?"))

	# `tone` takes ONLY the semantic tier. Anything else is a panel inventing its
	# own status palette, which is the exact drift the tier exists to stop — so it
	# is refused, not quietly honoured.
	var value_color: Color = UITheme.TEXT
	var tone: Variant = row.get("tone")
	if tone != null:
		if tone is Color and TONES.has(tone as Color):
			value_color = tone as Color
		else:
			push_error("[StatBand] label='%s' tone=%s reason=tone must be UITheme.SUCCESS/DANGER/WARNING; falling back to TEXT"
				% [row.get("label", "?"), tone])

	var icon := KitIconScript.resolve(row.get("icon"))
	if icon != null:
		var art := KitIconScript.rect(icon, ICON_PX)
		art.modulate = value_color
		value_line.add_child(art)

	var value := Label.new()
	value.text = String(row.get("value", "—"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(value, UITheme.TYPE_PARAGRAPH_1, value_color)
	value_line.add_child(value)

	var caption := Label.new()
	caption.text = String(row.get("label", "")).to_upper()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(caption, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	cell.add_child(caption)
	return cell


static func _divider() -> Control:
	var rule := ColorRect.new()
	rule.color = UITheme.GRAY_3
	rule.custom_minimum_size = Vector2(1, 0)
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func _band_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UITheme.GRAY_1
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.border_color = UITheme.GRAY_3
	box.content_margin_top = 10
	box.content_margin_bottom = 9
	box.content_margin_left = 2
	box.content_margin_right = 2
	return box
