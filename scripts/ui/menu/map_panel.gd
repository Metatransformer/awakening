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

var _title: Label
var _sub: Label
var _canvas: Control
var _back: Button
## The header's row, so `PauseMenu` can drop the shared tab strip into it. See
## the same field on `MenuEquipPanel`.
var _hrow: HBoxContainer
var _legend_rows: Array[Control] = []


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	# The tab strip goes in first and the panel's own title does not exist: the
	# lit tab IS the title. See `build_tabs`.
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)
	# Which floor, on the right, where POUCH keeps its slots-and-worth. The two
	# screens' headers read the same way on purpose: tabs on the left, the one
	# number this screen is about on the right.
	_title = Label.new()
	_title.theme_type_variation = &"MenuValue"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hrow.add_child(_title)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
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
	_sub.theme_type_variation = &"MenuMuted"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_sub)

	var key := Label.new()
	key.theme_type_variation = &"MenuHeading"
	key.text = "KEY"
	side.add_child(key)

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
		label.theme_type_variation = &"MenuMuted"
		label.text = String(row[1])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		_legend_rows.append(line)

	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var hint := Label.new()
	hint.theme_type_variation = &"MenuHint"
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
	if Atlas.has_floor():
		_title.text = Prog.label(Atlas.level)
		# Rooms SEEN over rooms that exist. It gives away the floor's length,
		# which the fitted bounds already give away, and it is the number the
		# player opened this screen to find: how much of this place is left.
		_sub.text = "%s\n%d of %d rooms walked" % [
			FloorDb.name_of(Atlas.level), Atlas.explored_count(),
			Atlas.rooms.size()]
	else:
		_title.text = "ABOVE GROUND"
		# In town, and it says so rather than showing an empty frame. A blank
		# panel reads as a screen that failed to load.
		_sub.text = "You are above ground. There is nothing down here to chart."
	for row in _legend_rows:
		row.visible = Atlas.has_floor()
	_canvas.queue_redraw()


func focus_first() -> void:
	if _back != null:
		_back.grab_focus()


func _draw_plan() -> void:
	var box := Rect2(Vector2.ZERO, _canvas.size)
	if box.size.x < 8.0 or box.size.y < 8.0:
		return
	_canvas.draw_rect(box, Color(Pal.VOID, 0.55))
	_canvas.draw_rect(box, Pal.ASH, false, 1.0)
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
