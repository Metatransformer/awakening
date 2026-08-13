class_name MenuMapPanel
extends Control
## The MAP screen: the same active plan the corner minimap draws, big enough to
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
##  * **A view you can move.** The right stick pans it, the mouse drags it, and
##    the wheel or the left stick zooms it. Only worth having because the plan
##    is no longer fitted whole — see below.
##
## **Why it pans, when this paragraph used to say it never would.** It said there
## was nothing to pan, and while a floor fit its frame that was true. Two things
## grew under it: the maze room is about three times the floor area it was, and
## `Atlas.annexes` hangs the vault, the treasure chamber and the boss landing off
## the grid at fractional cells, which `Atlas.bounds()` folds in. A fit of THAT
## box is mostly empty margin with the rooms small in the middle of it, so the
## screen you open to read the floor properly had quietly stopped being readable.
##
## **Zoom ships with the pan, and the screen opens ZOOMED IN.** Those are one
## decision, not two. A pan on a fitted plan shows you nothing you were not
## already looking at -- the whole floor is on screen, so there is nothing
## off-frame to bring in -- and a pan-only screen therefore has to abandon the
## fit permanently. But the fit is the picture that answers "how much of this
## place is left" in one glance, and giving that up to gain a pan is a trade
## nobody asked for. So: `zoom == 1.0` IS the old fitted plan, to the pixel, and
## it is the bottom of the range; the screen opens at `OPEN_ZOOM`, where the plan
## is half again bigger than its frame and there is somewhere for the pan to go
## from the first frame the player sees. Nothing was taken away -- the
## whole-floor picture is one pull of the stick down, and it is now a place you
## can get back TO rather than the only place you can be.
##
## The view resets on every open (`refresh`). A map that remembered where you had
## dragged it would open on a corner of the floor with no landmark in it, and the
## first thing a player does with a map screen is look for where they are.
##
## Back is still the only focusable control, so the pad has somewhere to be — a
## screen with no focusable Control at all strands a stick user on nothing, which
## is the failure `MenuUtil.chain` exists to prevent. Panning deliberately does
## NOT go through focus: it is polled off `cam_*` in `_process`, so it cannot
## become the two-movers-on-one-press bug in CLAUDE.md §3's table.

signal back_requested

## The inset between the drawing surface and the plan inside it, in px. Named
## because the clamp has to measure the same box the draw call is given, and two
## copies of `-18.0` is two answers to how big the map is.
const PLAN_PAD := 18.0
## Where the view opens, as a multiple of the fitted pitch. Above 1.0 on purpose
## -- see the class note. 1.75 crops about a quarter off each side, which is
## enough that the stick has somewhere to go and little enough that the shape of
## the floor is still the first thing on the screen.
const OPEN_ZOOM := 1.75
## The bottom of the range IS the old fitted-whole plan, to the pixel: the whole
## floor inside the frame, which is the picture the zoom exists to give back.
const ZOOM_MIN := 1.0
## Four times the fit. Past this a room fills the frame and the map has stopped
## being a map -- the same argument `MapDraw.FOLLOW_SPAN` makes about 3.
const ZOOM_MAX := 4.0
## Pan speed at full stick deflection, in px/sec. The canvas is ~600 px across,
## so a shove crosses it in a little over a second.
const PAN_SPEED := 520.0
## Zoom units per second at full stick deflection: the whole range in ~1.7 s.
const ZOOM_SPEED := 1.8
## Per notch of the wheel. Multiplicative, so a notch feels the same size at
## every zoom.
const ZOOM_WHEEL := 1.14
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
const SURFACE_LEGEND_ROWS := [
	[&"gate", "Gate or passage"],
	[&"hearth", "The central hearth"],
	[&"service", "A staffed service"],
	[&"landmark", "A local landmark"],
	[&"dungeon", "The Sunken Cut"],
	[&"fishing", "Fishing water"],
	[&"grove", "Harvestable grove"],
]

var _band: Control
var _band_slot: VBoxContainer
var _sub: Label
var _canvas: Control
var _back: Button
## The header's row, so `PauseMenu` can drop the shared tab strip into it. See
## the same field on `MenuEquipPanel`.
var _hrow: HBoxContainer
var _legend_rows: Array[Dictionary] = []
var _key_rule: Control
## The view. `_zoom` multiplies `MapDraw.fit_pitch`; `_pan` is a pixel offset on
## the centred plan, clamped by `MapDraw.pan_limit` so the plan can never be
## pushed off its own frame.
var _zoom := OPEN_ZOOM
var _pan := Vector2.ZERO
var _map_debug: Dictionary = {}
## True between the press and the release of a left-drag on the plan.
var _dragging := false


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


## The top row of focusables — see `MenuPageTabs` and `PauseMenu._tab_row`.
##
## Back is the ONLY focusable in this screen's body, so it is both the landing
## target and the way out upwards. The strip remains focusable so paging is
## discoverable without a persistent control legend; hidden shoulders / Q / R
## are an additional route. `MenuUtil.chain` wires
## Back's ↑ back to itself; `link_body` overwrites that, and the order matters —
## `PauseMenu._enter_page` re-links after every refresh.
func tab_row() -> Array:
	return [_back] if _back != null else []


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
	# STOP, not IGNORE: this is the one surface on these screens the player
	# grabs. The panel's own root stays IGNORE -- a filter on a parent does not
	# gate its children, so nothing else on the screen becomes clickable.
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_plan)
	_canvas.gui_input.connect(_plan_input)
	split.add_child(_canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = LEGEND_W
	side.add_theme_constant_override(&"separation", 10)
	split.add_child(side)

	_sub = Label.new()
	UITheme.apply_text_style(_sub, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_sub)

	# The rule hides with the rows it heads. A scene with no active map draws no
	# key, because a KEY over nothing reads as a legend that failed to draw.
	_key_rule = UITheme.section_rule(side, "KEY")

	for row: Array in LEGEND_ROWS:
		_build_legend_row(side, row, Atlas.KIND_DUNGEON)
	for row: Array in SURFACE_LEGEND_ROWS:
		_build_legend_row(side, row, Atlas.KIND_SURFACE)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
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


func _build_legend_row(side: VBoxContainer, row: Array,
		kind: StringName) -> void:
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
		MapDraw.draw_legend_glyph(swatch, swatch.size * 0.5, LEGEND_GLYPH,
			id, kind))
	line.add_child(swatch)
	var label := Label.new()
	UITheme.apply_text_style(label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	label.text = String(row[1])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(label)
	_legend_rows.append({&"control": line, &"kind": kind, &"glyph": id})


func refresh() -> void:
	# The view resets on every open. See the class note.
	_zoom = OPEN_ZOOM
	_pan = Vector2.ZERO
	_dragging = false
	_map_debug.clear()
	_rebuild_band()
	if Atlas.has_map():
		# The floor's NAME, which the band cannot carry -- a band cell is a
		# number under a caption and "The Foundry" is neither. It is the title
		# of the column it heads, so it is typed as one; above ground the same
		# Label carries a sentence instead and drops back to prose.
		_sub.text = Atlas.map_title()
		UITheme.apply_text_style(_sub, UITheme.TYPE_H2, UITheme.TEXT)
	else:
		_sub.text = "There is no map for this place."
		UITheme.apply_text_style(_sub, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	var surface_glyphs := _surface_glyphs()
	for entry: Dictionary in _legend_rows:
		var row: Control = entry[&"control"]
		var kind: StringName = entry[&"kind"]
		var glyph: StringName = entry[&"glyph"]
		row.visible = Atlas.has_map() and kind == Atlas.map_kind() \
			and (kind != Atlas.KIND_SURFACE or surface_glyphs.has(glyph))
	if _key_rule != null:
		_key_rule.visible = Atlas.has_map()
	_canvas.queue_redraw()


## Four facts from the active plan. Dungeon counts come from the SAME `marks`
## the plan is drawn from, so the band cannot claim a chest the map is not
## showing -- the whole point of this screen sharing `MapDraw` with the corner
## minimap (see the class note) applied to its numbers as well as its shapes.
func _band_cells() -> Array:
	if not Atlas.has_map():
		return [
			{"label": "Floor", "value": "—"},
			{"label": "Rooms", "value": "—"},
			{"label": "Chests", "value": "—"},
			{"label": "Stair", "value": "—"},
		]
	if Atlas.map_kind() == Atlas.KIND_SURFACE:
		var plan := Atlas.surface_plan()
		var paths: Array = plan[&"paths"]
		var areas: Array = plan[&"areas"]
		var landmarks: Array = plan[&"landmarks"]
		return [
			{"label": "Map", "value": "Surface"},
			{"label": "Routes", "value": str(paths.size())},
			{"label": "Areas", "value": str(areas.size())},
			{"label": "Places", "value": str(landmarks.size())},
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


func _surface_glyphs() -> Array[StringName]:
	var glyphs: Array[StringName] = []
	if Atlas.map_kind() != Atlas.KIND_SURFACE:
		return glyphs
	for value: Variant in Atlas.surface_plan()[&"landmarks"]:
		if not value is Dictionary:
			continue
		var glyph := StringName((value as Dictionary).get(&"glyph", &""))
		if not glyphs.has(glyph):
			glyphs.append(glyph)
	return glyphs


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


# --- The view -----------------------------------------------------------------
# Pan and zoom, and the two devices that drive them. The stick is POLLED and the
# mouse is EVENT-DRIVEN, which is the split the input skill prescribes and not an
# inconsistency: an analog axis held at 40% for two seconds is a continuous
# quantity that has no events in the middle of it, and a drag is a stream of
# events that carries its own distance in `relative`.


## The right stick, and the left one for zoom, while this screen is up.
##
## `cam_*` and not a pair of actions of its own: the right stick MOVES THE VIEW
## everywhere else in this game, and a player who rebinds that expects the map to
## follow. The action's own 0.2 deadzone is what keeps a resting stick from
## drifting the plan -- `Input.get_vector` applies it, which is also why the null
## case in `tools/directors/map_pan.gd` reads exactly zero.
##
## Sign: pushing the stick right moves the VIEW right, so the plan slides LEFT
## under it. That is the camera convention this stick already has in the world.
## The mouse runs the other way (`_plan_input`) because a drag grabs the paper,
## and every map in every application does both.
func _process(delta: float) -> void:
	# `is_visible_in_tree`, not `visible`. The panel's own flag stays true after
	# the menu closes on the MAP tab -- `PauseMenu` hides `Root`, not the screen
	# inside it -- so a bare `visible` check would have the right stick panning a
	# map nobody is looking at while the player is steering the camera with it.
	if not is_visible_in_tree() or not Atlas.has_map():
		return
	var stick := Input.get_vector(&"cam_left", &"cam_right",
		&"cam_up", &"cam_down")
	# The left stick has nothing else to do on this screen -- Back is the only
	# focusable control and `ui_up`/`ui_down` land back on it -- so it is where
	# the zoom goes. Up is in, which is the way a map has zoomed since paper.
	var wheel := Input.get_axis(&"move_down", &"move_up")
	if stick == Vector2.ZERO and is_zero_approx(wheel):
		return
	if not is_zero_approx(wheel):
		_set_zoom(_zoom + wheel * ZOOM_SPEED * delta)
	if stick != Vector2.ZERO:
		_move_pan(-stick * PAN_SPEED * delta)
	_canvas.queue_redraw()


## The mouse: left-drag pans, wheel zooms. `accept_event()` on everything this
## takes, so a drag that wanders off the plan does not turn into a click on
## whatever is under it.
func _plan_input(event: InputEvent) -> void:
	if not Atlas.has_map():
		return
	var btn := event as InputEventMouseButton
	if btn != null:
		if btn.button_index == MOUSE_BUTTON_LEFT:
			_dragging = btn.pressed
			accept_event()
		elif btn.pressed and btn.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * ZOOM_WHEEL)
			_canvas.queue_redraw()
			accept_event()
		elif btn.pressed and btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / ZOOM_WHEEL)
			_canvas.queue_redraw()
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		# `relative`, not a start-point subtraction: the viewport hands the drag
		# to whichever Control took the press, and `relative` is already the
		# distance since the last motion event on it.
		_move_pan(motion.relative)
		_canvas.queue_redraw()
		accept_event()


## Zoom about the middle of the frame, so the thing the player is looking at
## stays where it is.
##
## `_pan` scales with the pitch, and that one line is the whole of "about the
## centre": `draw_map` centres the plan and then adds `_pan`, so the grid point
## under the box's centre is fixed exactly when `_pan` grows in step with the
## zoom. Derived rather than iterated -- an eyeballed factor here is a map that
## creeps sideways every time you scroll.
func _set_zoom(to: float) -> void:
	var was := _zoom
	_zoom = clampf(to, ZOOM_MIN, ZOOM_MAX)
	if is_zero_approx(was):
		return
	_pan *= _zoom / was
	_clamp_pan()


func _move_pan(by: Vector2) -> void:
	_pan += by
	_clamp_pan()


## Hold the plan against its own frame. `MapDraw.pan_limit` owns the rule and
## the reason it is not the obvious one.
func _clamp_pan() -> void:
	if not Atlas.has_map():
		_pan = Vector2.ZERO
		return
	var lim := MapDraw.active_pan_limit(_plan_box(), _zoom)
	_pan = Vector2(clampf(_pan.x, -lim.x, lim.x), clampf(_pan.y, -lim.y, lim.y))


## The rect the plan is drawn into. `_draw_plan` and `_clamp_pan` must be given
## the same box or the clamp is measuring a different map from the one on screen.
func _plan_box() -> Rect2:
	return Rect2(Vector2.ZERO, _canvas.size).grow(-PLAN_PAD)


## The view, for a director to read back. There is no other way to ask "did the
## stick move the plan" that does not either re-derive `MapDraw`'s arithmetic or
## count pixels, and a director wants both -- see `tools/directors/map_pan.gd`.
func view() -> Dictionary:
	return {&"zoom": _zoom, &"pan": _pan,
		&"limit": MapDraw.active_pan_limit(_plan_box(), _zoom)
			if Atlas.has_map() else Vector2.ZERO}


func map_debug() -> Dictionary:
	return _map_debug.duplicate()


func _draw_plan() -> void:
	var box := Rect2(Vector2.ZERO, _canvas.size)
	if box.size.x < 8.0 or box.size.y < 8.0:
		return
	# The plan sits in a sunken well, the same recess the kit gives every other
	# list and grid on these screens -- drawn rather than styled because this is
	# a `_draw` surface, not a PanelContainer.
	_canvas.draw_rect(box, UITheme.BG_INSET)
	_canvas.draw_rect(box, UITheme.EDGE_FAINT, false, 1.0)
	if not Atlas.has_map():
		return
	# `Pal.px` measures against the viewport height, not this Control's, so the
	# line weights here come out the same thickness as everything else the theme
	# draws at this resolution rather than scaling with the panel.
	var s_y: float = float(get_viewport().get_visible_rect().size.y)
	# The canvas can be resized by the container between the last clamp and this
	# draw, and a `_pan` clamped against the old box would let the plan sit off
	# its frame for a frame. Cheap, and it is the only place that knows the real
	# size. `false` is the fit; `_zoom`/`_pan` are the player's view on top of it.
	_clamp_pan()
	_map_debug = MapDraw.draw_map(
		_canvas, _plan_box(), s_y, _hero(), false, _zoom, _pan)


## The hero, or null in a scene that has none. The world is paused behind this
## screen but the tree is intact, so this is the same lookup the HUD does.
func _hero() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D
