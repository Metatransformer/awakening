class_name UpgradeDetail
extends PanelContainer
## Persistent, display-only progression inspector. It asks the live catalogue
## for affordability and component counts but never mutates catalogue or game
## state; purchases remain entirely in `TradeScreen`.

const WIDTH := 306
const COMPONENT_ICON_PX := 30
const READY := "✓"
const MISSING := "×"

var _state: Label
var _title: Label
var _price: Label
var _verdict: Label
var _stats_heading: Label
var _detail: Label
var _blurb: Label
var _recipe_rows: VBoxContainer


func _init() -> void:
	name = "UpgradeDetail"
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", UITheme.frame(UITheme.FRAME_FACE_SOLID, true))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	_state = _label(col, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	_title = _label(col, UITheme.TYPE_H2, UITheme.TEXT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price = _label(col, UITheme.TYPE_LABEL_LG, UITheme.ACCENT)
	_verdict = _label(col, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add_rule(col)
	_stats_heading = _label(col, UITheme.TYPE_CAPTION, UITheme.ACCENT_DIM)
	_detail = _label(col, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb = _label(col, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add_rule(col)
	var recipe_heading := _label(col, UITheme.TYPE_CAPTION, UITheme.ACCENT_DIM)
	recipe_heading.text = "RECIPE"
	_recipe_rows = VBoxContainer.new()
	_recipe_rows.add_theme_constant_override("separation", 7)
	_recipe_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_recipe_rows)
	show_empty()


func show_empty() -> void:
	_state.text = "UPGRADE"
	_title.text = "Select a progression node"
	_price.text = ""
	_set_verdict("", UITheme.TEXT_DIM)
	_stats_heading.text = "UPGRADE"
	_detail.text = ""
	_blurb.text = ""
	_clear_recipe()
	_add_recipe_note("No materials")


## Refresh every field from one selected progression row and the live catalogue
## handle. `row` may be a buyable catalogue row or an owned rung description.
func describe(row: Dictionary, catalogue: GDScript) -> void:
	if row.is_empty() or catalogue == null:
		show_empty()
		return

	var kind: StringName = row.get("kind", &"")
	var line: Dictionary = row.get("line", {})
	var is_owned := kind == &"owned"
	var is_locked := kind == &"locked"
	_state.text = "OWNED" if is_owned else ("LOCKED" if is_locked else "AVAILABLE")
	_title.text = String(row.get("label", "Upgrade"))
	if is_owned:
		_price.text = "Owned"
		_set_verdict("Owned", UITheme.SUCCESS)
	elif is_locked:
		_price.text = "—"
		_set_verdict("Locked", UITheme.DANGER)
	else:
		var cost := int(row.get("price", line.get("cost", 0)))
		_price.text = catalogue.format_currency(cost)
		var affordable: bool = catalogue.can_buy(line)
		if affordable:
			_set_verdict("Affordable", UITheme.SUCCESS)
		else:
			var said: String = catalogue.refusal(line)
			_set_verdict(said if not said.is_empty() else "Unavailable", UITheme.DANGER)

	var detail_text := String(row.get("detail", line.get("detail", "")))
	var blurb_text := String(row.get("blurb", line.get("blurb", "")))
	_stats_heading.text = "STATS" if _reads_as_stat_result(detail_text) else "UPGRADE"
	_detail.text = detail_text if not detail_text.is_empty() else "No stat change listed."
	_blurb.text = blurb_text
	_fill_recipe(line, catalogue, is_owned)


func _fill_recipe(line: Dictionary, catalogue: GDScript, is_owned: bool) -> void:
	_clear_recipe()
	if is_owned or line.is_empty():
		_add_recipe_note("No materials")
		return
	var parts: Dictionary = line.get("parts", {})
	if parts.is_empty():
		_add_recipe_note("Gold only" if int(line.get("cost", 0)) > 0 else "No materials")
		return
	for id: StringName in parts:
		var definition := ItemDb.get_def(id)
		var need := int(parts[id])
		# Through the live handle: catalogues may count a bench, the run bag, or
		# another store, and a direct inventory guess would disagree with can_buy.
		var have: int = catalogue.part_count(line, id)
		var ready := have >= need
		_add_component(id,
			definition.display_name if definition != null else String(id).capitalize(),
			need, have, ready)


func _add_component(id: StringName, display_name: String, need: int,
		have: int, ready: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe_rows.add_child(row)

	var icon_path := UiKit.item_icon(id)
	var icon := TextureRect.new()
	icon.texture = UiKit.resolve_icon(icon_path) if not icon_path.is_empty() else null
	icon.custom_minimum_size = Vector2(COMPONENT_ICON_PX, COMPONENT_ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := _label(words, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT)
	name_label.text = display_name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var tally := _label(words, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	tally.text = "Required: %d    Owned: %d" % [need, have]

	var mark := _label(row, UITheme.TYPE_H2,
		UITheme.SUCCESS if ready else UITheme.DANGER)
	mark.text = READY if ready else MISSING
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _add_recipe_note(text: String) -> void:
	var note := _label(_recipe_rows, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	note.text = text


func _reads_as_stat_result(text: String) -> bool:
	return text.contains("->") or text.contains("→") or text.contains(" / ")


func _set_verdict(text: String, tone: Color) -> void:
	_verdict.text = text
	UITheme.apply_text_style(_verdict, UITheme.TYPE_CAPTION, tone)


func _clear_recipe() -> void:
	for child in _recipe_rows.get_children():
		_recipe_rows.remove_child(child)
		child.queue_free()


func _add_rule(parent: Node) -> void:
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _label(parent: Node, style: Dictionary, tone: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(label, style, tone)
	parent.add_child(label)
	return label
