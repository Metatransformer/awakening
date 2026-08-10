class_name MenuMapPanel
extends Control
## The MAP screen: the same floor plan the corner minimap draws, big enough to
## stop and read.
##
## **It is the same map, not a second one.** Both this and `Hud._draw_minimap`
## call `MapDraw.draw_map` on the same `Atlas`, and the only thing that differs
## is the size of the box. A menu map that re-derived the layout would be the
## one that goes stale — this project has a whole section of CLAUDE.md about
## building the same thing twice.
##
## What the size buys, and the only things this screen adds:
##
##  * **A legend.** At 6 px a chest glyph is a shape you learn by opening a
##    chest; at 20 px it is worth naming, and naming it here is what makes the
##    corner one readable. The legend is on the big screen precisely because
##    that is the screen the player is not in a hurry on.
##  * **The floor's NAME**, which the HUD's card also carries but the map does
##    not otherwise say. "The Foundry, 6 of 8 rooms" is a sentence about how far
##    through you are, and how far through you are is the whole reason to open
##    a map in this game.
##
## It is deliberately not interactive. There is nothing to pan (the plan is
## fitted whole), nothing to zoom (it is a schematic, not terrain), and no
## marker to place. The single focusable control is Back, so the pad has
## somewhere to be — a screen with no focusable Control at all strands a stick
## user on nothing, which is the failure `MenuUtil.chain` exists to prevent.

signal back_requested

const HINT := "M / Tab Close    Esc / B Back"
## The drawing surface, inside the frame's padding. Square-ish and tall enough
## that a 4x4 floor still gets a big room; the legend sits beside it rather than
## under it so the map keeps the height.
const CANVAS_MIN := Vector2(640, 430)
const LEGEND_W := 300
## Reference px per legend glyph, matched to what the row's text can sit beside.
const LEGEND_GLYPH := 22.0

## What each marker means, in the order the player meets them. `MapDraw` owns
## the shapes; this owns the words, and the ids are the join.
const LEGEND_ROWS := [
	[&"entrance", "Where you came in"],
	[&"chest", "Unopened chest"],
	[&"chest_open", "Chest you have emptied"],
	[&"arrows", "Arrows on the floor"],
	[&"stairs", "The stair down"],
]

var _band: Control
var _band_slot: VBoxContainer
var _sub: Label
var _canvas: Control
var _back: Button
## The header's row, so `PauseMenu` can drop the shared tab strip into it. See
## the same field on `MenuEquipPanel`.
var _hrow: HBoxContainer
var _legend_rows: Array[Control] = []
var _key_rule: Control


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No `theme` of its own: `PauseMenu` puts `UITheme.theme()` on Root and every
	# panel inherits it. This used to override a `menu_theme.tres` that Root
	# carried while the screens converted one at a time; they all have, so the
	# per-panel override went with the .tres.
	_build()
	# The plan only changes on a signal, so the surface only repaints on one.
	# There is no hero arrow to chase here: the world is paused behind this
	# screen, so the one thing that would want a frame ticker cannot move.
	Bus.map_changed.connect(func() -> void:
		if _canvas != null:
			_canvas.queue_redraw())


func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	# `edge_to_edge`, like the other two tabbed screens: the strip, the band and
	# the footer reach the frame's edge and the body owns its inset.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 14, 6, 14, 0))
	col.add_child(header)
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	# The tab strip goes in first and the panel's own title does not exist: the
	# lit tab IS the title. See `build_tabs`.
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)

	# "How much of this place is left" is the question this screen is opened
	# with, and it used to be answered by one right-aligned floor label plus a
	# line of prose beside the legend. It is four numbers, and they go in a
	# `StatBand` under the strip, exactly where POUCH keeps its four -- the
	# tabbed screens' headers read the same way on purpose.
	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override("separation", 0)
	col.add_child(_band_slot)
	_rebuild_band()

	var body := MarginContainer.new()
	for side_name in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side_name, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.add_theme_constant_override(&"separation", 24)
	body.add_child(split)

	_canvas = Control.new()
	_canvas.name = "Plan"
	_canvas.custom_minimum_size = CANVAS_MIN
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_plan)
	split.add_child(_canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = LEGEND_W
	side.add_theme_constant_override(&"separation", 10)
	split.add_child(side)

	_sub = Label.new()
	UITheme.apply_text_style(_sub, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_sub)

	# The rule hides with the rows it heads. Above ground there is no floor to
	# chart, and a KEY over nothing reads as a legend that failed to draw.
	_key_rule = UITheme.section_rule(side, "KEY")

	for row: Array in LEGEND_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 12)
		side.add_child(line)
		# The glyph is drawn by MapDraw, into a Control sized to it, so the key
		# and the map cannot show two different chests.
		var swatch := Control.new()
		swatch.custom_minimum_size = Vector2(LEGEND_GLYPH * 1.6, LEGEND_GLYPH * 1.6)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id: StringName = row[0]
		swatch.draw.connect(func() -> void:
			MapDraw.draw_legend_glyph(swatch, swatch.size * 0.5, LEGEND_GLYPH, id))
		line.add_child(swatch)
		var label := Label.new()
		UITheme.apply_text_style(label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
		label.text = String(row[1])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		_legend_rows.append(line)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var hint := Label.new()
	UITheme.apply_text_style(hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	hint.text = HINT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frow.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.focus_mode = Control.FOCUS_ALL
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)
	MenuUtil.chain([_back], true)


func refresh() -> void:
	_rebuild_band()
	if Atlas.has_floor():
		# The floor's NAME, which the band cannot carry -- a band cell is a
		# number under a caption and "The Foundry" is neither. It is the title
		# of the column it heads, so it is typed as one; above ground the same
		# Label carries a sentence instead and drops back to prose.
		_sub.text = FloorDb.name_of(Atlas.level)
		UITheme.apply_text_style(_sub, UITheme.TYPE_H2, UITheme.TEXT)
	else:
		# In the garrison, and it says so rather than showing an empty frame. A
		# blank panel reads as a screen that failed to load.
		_sub.text = "You are above ground. There is nothing down here to chart."
		UITheme.apply_text_style(_sub, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	for row in _legend_rows:
		row.visible = Atlas.has_floor()
	if _key_rule != null:
		_key_rule.visible = Atlas.has_floor()
	_canvas.queue_redraw()


## The four numbers, or four dashes above ground. Counted off the SAME `marks`
## the plan is drawn from, so the band cannot claim a chest the map is not
## showing -- the whole point of this screen sharing `MapDraw` with the corner
## minimap (see the class note) applied to its numbers as well as its shapes.
func _band_cells() -> Array:
	if not Atlas.has_floor():
		return [
			{"label": "Floor", "value": "—"},
			{"label": "Rooms", "value": "—"},
			{"label": "Chests", "value": "—"},
			{"label": "Stair", "value": "—"},
		]
	var walked := Atlas.explored_count()
	var total := Atlas.rooms.size()
	var shut := _marked(Atlas.M_CHEST)
	var stair := _marked(Atlas.M_STAIRS) > 0
	return [
		{"label": "Floor", "value": Prog.label(Atlas.level)},
		{"label": "Rooms", "value": "%d / %d" % [walked, total],
			"tone": UITheme.SUCCESS if walked >= total else null},
		{"label": "Chests", "value": "%d shut" % shut,
			"tone": UITheme.WARNING if shut > 0 else null},
		{"label": "Stair", "value": "found" if stair else "not yet",
			"tone": UITheme.SUCCESS if stair else null},
	]


func _rebuild_band() -> void:
	if _band_slot == null:
		return
	for child in _band_slot.get_children():
		child.queue_free()
		_band_slot.remove_child(child)
	_band = UiKit.stat_band(_band_slot, _band_cells())


## How many cells carry `id`. `Atlas.marks` only holds cells the player has been
## in, so this counts what is CHARTED, not what exists -- which is the honest
## number for a map and the one the legend beside it describes.
func _marked(id: StringName) -> int:
	var n := 0
	for cell: Vector2i in Atlas.marks:
		for got: StringName in Atlas.marks[cell]:
			if got == id:
				n += 1
	return n


func focus_first() -> void:
	if _back != null:
		_back.grab_focus()


func _draw_plan() -> void:
	var box := Rect2(Vector2.ZERO, _canvas.size)
	if box.size.x < 8.0 or box.size.y < 8.0:
		return
	# The plan sits in a sunken well, the same recess the kit gives every other
	# list and grid on these screens -- drawn rather than styled because this is
	# a `_draw` surface, not a PanelContainer.
	_canvas.draw_rect(box, UITheme.BG_INSET)
	_canvas.draw_rect(box, UITheme.EDGE_FAINT, false, 1.0)
	if not Atlas.has_floor():
		return
	# `Pal.px` measures against the viewport height, not this Control's, so the
	# line weights here come out the same thickness as everything else the theme
	# draws at this resolution rather than scaling with the panel.
	var s_y: float = float(get_viewport().get_visible_rect().size.y)
	MapDraw.draw_map(_canvas, box.grow(-18.0), s_y, _hero())


## The hero, or null in a scene that has none. The world is paused behind this
## screen but the tree is intact, so this is the same lookup the HUD does.
func _hero() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D
