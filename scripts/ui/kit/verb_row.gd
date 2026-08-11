class_name VerbRow
extends RefCounted
## One row of a verb list — the grammar that replaces a stack of identical
## full-width buttons.
##
##     ┌─┬──────┬──────────────────────────────┬────────────┬───┐
##     │▌│ icon │ Label                        │ meta       │ › │   44px
##     └─┴──────┴──────────────────────────────┴────────────┴───┘
##      ▲                                        ▲            ▲
##      │ 3px edge, transparent → HIGHLIGHT      │            │ submenu only
##      │ on hover/focus. A fill lift in a       │ THE POINT of this component.
##      │ ten-row list reads as noise; a lit     │ Cost, count, duration,
##      │ edge reads as a cursor.                │ consequence — one column the
##      │                                        │ eye scans, instead of five
##      │                                        │ sentences it has to parse.
##
## The row IS a Button, so focus, keyboard activation and gamepad navigation come
## for free. Its children sit under `mouse_filter = IGNORE` so every click lands
## on the Button and not on a Label.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const KitIconScript := preload("res://scripts/ui/kit/kit_icon.gd")

const HEIGHT := 44
const ICON_PX := 19
const EDGE_PX := 3
## A disabled control is exempt from the 4.5:1 contrast floor, which is what buys
## us this dim. The REASON text is not exempt, and is re-lit below.
const REFUSED_ALPHA := 0.38


static func build(parent: Node, config: Dictionary) -> Button:
	var label_text := String(config.get("label", ""))
	if label_text.is_empty():
		push_error("[VerbRow] reason=a verb row requires a label; row omitted")
		return null

	var refused := String(config.get("refused", ""))
	var is_refused := not refused.is_empty()
	var is_primary := bool(config.get("primary", false))

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.theme = UITheme.theme()
	row.text = ""
	# NOT `flat = true`. `flat` suppresses the stylebox draw entirely, which would
	# silently swallow every override installed below and leave the row with no
	# hover edge — and a structural check cannot see that, because the overrides
	# are still *present*. The overrides already replace the theme's plate, so
	# `flat` buys nothing and risks that.
	#
	# A refused row is inert but still READ: it holds its place so the menu's
	# shape stays stable between visits. That stability is the whole point.
	row.focus_mode = Control.FOCUS_NONE if is_refused else Control.FOCUS_ALL
	row.disabled = is_refused
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_refused else Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		row.add_theme_stylebox_override(state, _row_box(state, is_refused))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 18)
	row.add_child(pad)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	line.add_theme_constant_override("separation", 12)
	pad.add_child(line)

	var icon := KitIconScript.resolve(config.get("icon"))
	row.set_meta("verb_has_icon", icon != null)
	if icon != null:
		line.add_child(KitIconScript.rect(icon, ICON_PX, 1.0 if is_primary else 0.82))

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Exactly one row per panel earns the display face. Two primaries is no primary.
	UITheme.apply_text_style(name_label,
		UITheme.TYPE_H2 if is_primary else UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	line.add_child(name_label)
	# Kept as a handle for the same reason `verb_meta` is: the row's own
	# `Button.text` is empty, so the only way anything outside this file can ask
	# what FACE a row ended up in is to be given the Label. `DialogueBox` uses it
	# to prove its option list is one typeface (`choice_faces`).
	row.set_meta(&"verb_name", name_label)

	# The meta column. A refused row spends it on the REASON.
	#
	# Built whenever the caller PASSED a `meta` key, even an empty one, so a row
	# whose cost is not known until the panel refreshes has somewhere to write it
	# (`set_meta_text`). A Label conjured on the second call would land after the
	# chevron instead of before it.
	var meta_text := refused if is_refused else String(config.get("meta", ""))
	if not meta_text.is_empty() or (config.has("meta") and not is_refused):
		var meta := Label.new()
		meta.text = meta_text
		meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_text_style(meta, UITheme.TYPE_PARAGRAPH_2,
			UITheme.DANGER if is_refused else UITheme.TEXT_DIM)
		if is_refused:
			# Cancel the row-wide dim for this one child. The row may be greyed;
			# the explanation may not. A reason nobody can read is no reason.
			meta.modulate.a = minf(1.0 / REFUSED_ALPHA, 4.0)
		line.add_child(meta)
		row.set_meta(&"verb_meta", meta)

	if bool(config.get("submenu", false)):
		var chev := Label.new()
		chev.text = "›"
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_text_style(chev, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT_DIM)
		line.add_child(chev)

	if is_refused:
		row.modulate.a = REFUSED_ALPHA
	else:
		var on_press: Variant = config.get("on_press")
		if on_press is Callable and (on_press as Callable).is_valid():
			row.pressed.connect(on_press as Callable)
		elif on_press != null:
			push_error("[VerbRow] label='%s' reason=on_press is not a valid Callable" % label_text)

	# The row's OWN Button.text is empty — everything visible is the line above,
	# so the label, the meta and the chevron can be laid out in columns instead of
	# crammed into one string. That leaves the row with no name a harness can
	# match on, and every keyboard-navigation director in this repo finds a
	# control by asking "is this the button that says X". So the label is stamped
	# here, and `UiKit.label_of()` is the one reader of it.
	row.set_meta(&"verb_label", label_text)

	if parent != null:
		parent.add_child(row)
	return row


## The row plate, for a row the kit cannot compose.
##
## `VerbRow` is a composition — icon, label, meta — and a settings row that owns
## an HSlider, or cycles a value on left/right, is not that shape. What it IS is
## the same PLATE, and a settings row painted a second way would put two row
## voices on one screen. So the box is public; `UiKit.style_row_button` hangs
## all five states off it.
static func row_box(state: String) -> StyleBoxFlat:
	return _row_box(state, false)


## The row plate.
##
## StyleBoxFlat carries ONE border colour for every side, so the top hairline and
## the left edge share it by construction. That is the design, not a limitation
## worked around: it is the "a hairline, or HIGHLIGHT when armed" law expressed
## on a row.
static func _row_box(state: String, refused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = true
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = EDGE_PX
	box.border_width_top = 1
	box.border_color = UITheme.GRAY_3
	box.corner_radius_top_right = UITheme.RADIUS
	box.corner_radius_bottom_right = UITheme.RADIUS
	if refused:
		return box
	match state:
		"hover", "focus", "pressed":
			box.bg_color = Color(
				UITheme.HIGHLIGHT.r, UITheme.HIGHLIGHT.g, UITheme.HIGHLIGHT.b, 0.09)
			box.border_color = UITheme.HIGHLIGHT
	return box


## Rewrite a row's meta column after the fact, for a cost that MOVES — a batch
## size that follows the bag, a toll that follows the purse.
##
## Requires the row to have been built with a `meta` key, even an empty one.
##
## This is NOT the refusal law's back door. A row that cannot be used at all
## should be built `refused`, which also makes it inert and unfocusable. This is
## for the rows that stay usable and merely cost something different than they
## did a moment ago — and for the handful that are deliberately kept live while
## they will refuse, so the panel beside them can say what you are short of
## (`MenuPouchPanel._build_rope` argues that case at length).
static func set_meta_text(row: Button, text: String, tone: Variant = null) -> void:
	if row == null or not row.has_meta(&"verb_meta"):
		return
	var label := row.get_meta(&"verb_meta") as Label
	if label == null:
		return
	label.text = text
	var color: Color = UITheme.TEXT_DIM
	if tone is Color:
		color = tone as Color
	label.add_theme_color_override("font_color", color)
