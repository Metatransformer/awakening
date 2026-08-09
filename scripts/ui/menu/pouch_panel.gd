class_name MenuPouchPanel
extends Control
## The POUCH screen: what you are carrying, drawn as the fixed number of slots
## you are actually carrying it in.
##
## This is deliberately NOT a list. A list of six rows and a list of twelve rows
## look the same at a glance, and the whole pressure in this game is the
## difference between them (docs/METAGAME.md §3). A grid of `Game.bag_slots`
## cells, most of them visibly empty or visibly not, answers "how much room is
## left" without the player reading a single number — and then the header gives
## them the number anyway, because the extraction fee is taken from it.
##
## Three things live here and nowhere else:
##
##  * **The bag**, slot by slot. Stacks occupy one cell until they overflow,
##    exactly as `Run.slots_used()` counts them, so the picture and the
##    arithmetic cannot disagree.
##  * **A component mark.** A component and an ingredient compete for the same
##    cell, and which one you are looking at decides whether it is going to the
##    vendor or to the forge. The mark is the ◆ and the caption says which.
##  * **The workbench**, which is what survived. Read-only: this screen shows
##    the stock, the smith spends it.
##  * **The way out**, and its fee. It moved here off the ITEMS screen, and the
##    HUD's gold total moved here too (hud.gd took it off the screen on purpose).
##    That is not three unrelated things sharing a frame: the bag's worth, the
##    purse and the fee ARE the extraction decision, and it is a decision made by
##    stopping and looking, not by glancing at a corner while running.
##
## It owns no state and changes none. Equipping is the ITEMS screen's job (the
## D-pad and the two hands), and the two are separate screens on purpose — one
## is what you are CARRYING and the other is what you are HOLDING, and a player
## who conflates them is a player who thinks the bag can be equipped.

signal back_requested
signal notice(text: String, is_error: bool)
## The player asked to leave. The channel happens in the WORLD, so the menu has
## to close whole rather than back out one screen.
signal use_requested

const FRAME_SIZE := Vector2(1060, 604)
const HINT := "↑↓←→ Look    Esc / B Back    The way out is in the right column"

## Cells per row. Twelve slots is the start, sixteen the bought maximum
## (K.START_BAG_SLOTS + ShopDb.LIMITS.bag_slot): four across is three clean rows
## at the low end and four at the high end, and four is as many as fit.
##
## Six across was the first try and it pushed the frame to ~1400 px inside a
## 1280 px viewport — the detail column and the Back button rendered off the
## right edge of the screen. A CenterContainer does not save you from a child
## whose minimum size is bigger than the screen; it just clips it. The width
## budget is: 1060 frame − 36 frame pad − 44 body pad − 24 split − 340 detail
## − 28 card pad = 588 for the grid, which is 4 × 140 with 8 between.
const COLS := 4
const CELL_MIN := Vector2(140, 88)
## Cell text is deliberately smaller than the theme's Label default. A cell is
## 140 px wide and half these names are two words, so 18 pt wrapped to three
## lines and shoved the ×count out through the bottom border.
const CELL_NAME_PT := 16
const CELL_COUNT_PT := 18
## Hard ceiling on cells drawn, so a corrupt `bag_slots` cannot build a grid
## taller than the frame and push the footer off the screen — which is exactly
## how the ITEMS screen broke the first time it was built.
## Four rows of four. That is the bought maximum, so it is also the tallest grid
## the frame was measured against.
const MAX_CELLS := 16

var _cells: Array[Button] = []
## Parallel to `_cells`: the item id in each, or &"" for an empty slot.
var _cell_ids: Array[StringName] = []
var _grid: GridContainer
var _header: Label
var _stock: Label
var _back: Button
var _detail_kind: Label
var _detail_name: Label
var _detail_value: Label
var _detail_blurb: Label
var _detail_legend: Label
var _rope: Button
var _rope_fee: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	# The bag changes while this screen is open in exactly one case that matters
	# — a director driving a run with the menu up — but it also changes under a
	# save load, and the workbench changes when a run banks. Redraw on the
	# signals rather than trusting `refresh()` on open to be the only way in.
	Bus.bag_changed.connect(func(_b: Dictionary, _v: int) -> void: refresh())
	Bus.components_changed.connect(func(_s: Dictionary) -> void: refresh())
	refresh()


# --- Chrome -----------------------------------------------------------------

func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	var hrow := HBoxContainer.new()
	header.add_child(hrow)
	var title := Label.new()
	title.theme_type_variation = &"MenuTitle"
	title.text = "POUCH"
	hrow.add_child(title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(gap)
	# Slots and worth, in the header, because they are the two numbers the
	# extraction decision is made out of and neither should require a focus.
	_header = Label.new()
	_header.theme_type_variation = &"MenuValue"
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(_header)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	split.add_child(left)
	_build_grid(left)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = 340
	right.add_theme_constant_override("separation", 12)
	split.add_child(right)
	_build_detail(right)
	_build_rope(right)
	_build_stock(right)

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
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


func _build_grid(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Bag"
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "CARRIED"
	inner.add_child(caption)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(_grid)


## Rebuild the cell buttons to match `Game.bag_slots`. Called from `refresh()`
## rather than once from `_build`, because a bag slot bought at the smith has to
## show up as a new empty cell the next time the screen opens — the grid IS the
## capacity, so it cannot be built once and trusted.
func _rebuild_cells() -> void:
	var want := clampi(Game.bag_slots, 1, MAX_CELLS)
	if _cells.size() == want:
		return
	for c in _cells:
		c.queue_free()
	_cells.clear()
	_cell_ids.clear()
	for i in want:
		_cells.append(_make_cell(i))
		_cell_ids.append(&"")
	_wire_focus()


func _make_cell(index: int) -> Button:
	var b := Button.new()
	b.name = "Cell_%d" % index
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = CELL_MIN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta(&"cell", index)
	_grid.add_child(b)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 7
	col.offset_right = -7
	col.offset_top = 4
	col.offset_bottom = -4

	# The chip is the item's own tint, which is the same colour the mote on the
	# floor glowed and the same colour the vendor list prints its name in. Three
	# screens, one hue per thing: that consistency is the only icon set this
	# game has for ingredients.
	var chip := ColorRect.new()
	chip.name = "Chip"
	chip.custom_minimum_size = Vector2(0, 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip)

	var label := Label.new()
	label.name = "Name"
	label.theme_type_variation = &"MenuSlotStat"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", CELL_NAME_PT)
	col.add_child(label)

	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = &"MenuValue"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", CELL_COUNT_PT)
	col.add_child(count)

	# A cell does nothing when pressed and that is correct: there is no verb here.
	# You cannot drop, sort or use a bag item — the vendor buys them and the
	# forge eats them, both in town. Saying so beats a button that beeps.
	b.pressed.connect(func() -> void: _describe(b))
	b.focus_entered.connect(func() -> void: _describe(b))
	b.mouse_entered.connect(func() -> void: _describe(b))
	return b


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	_detail_kind = Label.new()
	_detail_kind.theme_type_variation = &"MenuHint"
	col.add_child(_detail_kind)

	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"MenuSlotTitle"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_name)

	_detail_value = Label.new()
	_detail_value.theme_type_variation = &"MenuValue"
	col.add_child(_detail_value)

	_detail_blurb = Label.new()
	_detail_blurb.theme_type_variation = &"MenuSlotStat"
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_blurb)

	_detail_legend = Label.new()
	_detail_legend.theme_type_variation = &"MenuHint"
	_detail_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_legend)


## The way out. The only control on this screen that ENDS something — everything
## above it is a picture of what you are carrying, and this spends it.
##
## It sits directly under the grid it is priced from, which is why it moved here
## from the ITEMS screen: the fee is a quarter of the bag, and the bag is what
## the left column draws. On the other screen the number had nothing beside it.
##
## It is not one of the three bindable buttons and it never will be. Extraction
## used to be a hold on a rune pad precisely so it could not be triggered by a
## fumble (METAGAME §5); putting it on a D-pad direction would hand back exactly
## the fumble the hold was guarding against. Two deliberate presses in a paused
## menu, then a channel you can be knocked out of, is the same guarantee by
## other means.
func _build_rope(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Use"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "THE WAY OUT"
	inner.add_child(caption)

	_rope = Button.new()
	_rope.name = "Rope"
	_rope.theme_type_variation = &"MenuRow"
	_rope.focus_mode = Control.FOCUS_ALL
	_rope.text = "◈  Escape Rope"
	inner.add_child(_rope)

	_rope_fee = Label.new()
	_rope_fee.name = "Fee"
	_rope_fee.theme_type_variation = &"MenuValue"
	_rope_fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rope_fee.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rope_fee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rope.add_child(_rope_fee)
	_rope_fee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rope_fee.offset_right = -16

	_rope.pressed.connect(_use_rope)
	_rope.focus_entered.connect(_describe_rope)
	_rope.mouse_entered.connect(_describe_rope)


## Leaving is not something to do from inside a menu screen: the channel happens
## in the world and the player has to be able to see it. So the menu closes and
## the hero's rope node takes it from there (`Bus.escape_rope_used`).
func _use_rope() -> void:
	if not Run.in_dungeon:
		notice.emit("You are already home.", true)
		return
	var fee := Run.extract_cost()
	if Game.gold < fee:
		notice.emit("The rope wants %d gold and you have %d." % [fee, Game.gold], true)
		return
	use_requested.emit()
	Bus.escape_rope_used.emit()


func _describe_rope() -> void:
	# NOT "THE WAY OUT" — that is the caption on the section directly below this
	# panel, and with the rope focused the screen said it twice, one line apart.
	# The kind line is metadata everywhere else on this screen ("SLOT 1 · COMMON
	# · INGREDIENT"), so it says the two things about the rope that are not
	# obvious from the button: it costs no slot, and it is deliberately not
	# bindable (escape_rope.gd — one D-pad press that ends the run is the fumble
	# the channel exists to prevent).
	_detail_kind.text = "ALWAYS CARRIED  ·  NOT BINDABLE"
	_detail_name.text = "Escape Rope"
	if not Run.in_dungeon:
		_detail_value.text = ""
		_detail_blurb.text = "Cold, and quiet. It only wakes underground."
		_detail_legend.text = "Nothing to leave."
		return
	var fee := Run.extract_cost()
	_detail_value.text = "%d gold" % fee
	_detail_blurb.text = "It pulls you home and heals what the dark took. " \
		+ "The fee is a quarter of what you are carrying, and the fee is why " \
		+ "the greedy run is a decision."
	_detail_legend.text = "Takes a moment. A blow that lands breaks it." \
		if Game.gold >= fee else "You cannot afford to leave. Sell, or die trying."


## The fee, live. It is on the row rather than only in the detail pane because
## it is the whole decision: "leave" and "leave for 340 gold" are different
## sentences and the player should not have to focus the row to read the second.
##
## The row stays ENABLED when you cannot afford it. A greyed-out control tells
## you nothing about why; pressing it and being told "the rope wants 340 gold
## and you have 190" tells you exactly what to do about it.
func _paint_rope() -> void:
	if _rope == null:
		return
	if not Run.in_dungeon:
		_rope_fee.text = "—"
		_rope_fee.modulate = Color(1, 1, 1, 0.5)
		return
	var fee := Run.extract_cost()
	_rope_fee.text = "%d ◇" % fee
	_rope_fee.modulate = Color.WHITE if Game.gold >= fee else Pal.RUST


## What made it home. Not focusable and not editable — it is the answer to "can
## I afford the next rung", shown next to the bag it came out of.
func _build_stock(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Bench"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "WORKBENCH"
	col.add_child(caption)

	_stock = Label.new()
	_stock.theme_type_variation = &"MenuSlotStat"
	_stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_stock)


## Grid focus, wired by hand: left/right wraps within a row, up/down walks the
## column and the bottom row falls to Back, which closes the loop to the top
## left. Every cell is reachable by holding one direction — the same guarantee
## the ITEMS screen makes, and for the same reason.
func _wire_focus() -> void:
	var n := _cells.size()
	if n == 0:
		return
	var rows := int(ceil(float(n) / float(COLS)))
	for i in n:
		var row := i / COLS
		var col := i % COLS
		var wide: int = mini(COLS, n - row * COLS)
		var right := row * COLS + (col + 1) % wide
		MenuUtil.link_right(_cells[i], _cells[right])
		var below := (row + 1) * COLS + col
		if below < n:
			MenuUtil.link_down(_cells[i], _cells[below])
		else:
			# Out of the bottom of the grid comes the way out, and only then Back.
			# That order is the screen's argument in one column: here is what you
			# are carrying, here is what it costs to keep it, here is the door.
			MenuUtil.link_down(_cells[i], _rope)
	MenuUtil.link_down(_rope, _back)
	_rope.focus_neighbor_left = ^"."
	_rope.focus_neighbor_right = ^"."
	_back.focus_neighbor_bottom = _back.get_path_to(_cells[0])
	_back.focus_next = _back.get_path_to(_cells[0])
	_back.focus_neighbor_left = ^"."
	_back.focus_neighbor_right = ^"."
	# `rows` only exists to make the intent above legible in a debugger; the
	# wiring reads `n` directly so a short last row cannot walk off the end.
	assert(rows >= 1)


# --- State ------------------------------------------------------------------

func focus_first() -> void:
	if not _cells.is_empty():
		_cells[0].grab_focus()


func refresh() -> void:
	_rebuild_cells()
	_fill_cells()
	_paint_header()
	_paint_rope()
	_paint_stock()
	var focused := get_viewport().gui_get_focus_owner()
	if _cells.has(focused):
		_describe(focused as Button)
	elif focused == _rope:
		_describe_rope()
	elif not _cells.is_empty():
		_describe(_cells[0])


## Lay the bag out over the cells the way `Run.slots_used()` counts it: full
## stacks first, then the remainder. Anything that will not fit in the drawn
## grid is dropped from the PICTURE only — it cannot happen while `bag_slots`
## and the grid agree, and if it ever does the header's number is still right,
## which is the number the fee is taken from.
func _fill_cells() -> void:
	for i in _cell_ids.size():
		_cell_ids[i] = &""
	var at := 0
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var per: int = maxi(def.stack, 1)
		var left: int = Run.bag[id]
		while left > 0 and at < _cell_ids.size():
			_cell_ids[at] = id
			_cells[at].set_meta(&"count", mini(left, per))
			left -= per
			at += 1
	for i in _cells.size():
		_paint_cell(_cells[i])


func _paint_cell(b: Button) -> void:
	var index: int = b.get_meta(&"cell")
	var id: StringName = _cell_ids[index]
	var chip := b.get_node("Col/Chip") as ColorRect
	var name_label := b.get_node("Col/Name") as Label
	var count := b.get_node("Col/Count") as Label

	if id == &"":
		chip.color = Color(Pal.ASH, 0.35)
		name_label.text = "—"
		name_label.modulate = Color(1, 1, 1, 0.4)
		count.text = ""
		# Dimmed, never hidden. An empty cell that vanished would make the grid
		# shrink as you spend, and the shrinking grid is the one thing this
		# screen exists to NOT do.
		b.modulate = Color(1, 1, 1, 0.55)
		return

	var def := ItemDb.get_def(id)
	chip.color = def.tint
	name_label.modulate = Color.WHITE
	b.modulate = Color.WHITE
	# The diamond is the forge mark. It is the same glyph the rope row uses for
	# "this does something", and here it means "the smith wants this", which is
	# the only thing you need to know about a cell while the bag is filling up.
	name_label.text = ("◆ " + def.display_name) if def.is_component() else def.display_name
	count.text = "×%d" % int(b.get_meta(&"count", 1))


## Three numbers, and this screen is now the only place two of them are said.
##
## The HUD used to print a running gold total in the corner and it was taken out
## on purpose (see hud.gd `_draw_bag`): money on screen turns a dungeon into an
## accounting exercise. So the bag's worth and the purse live HERE, where the
## player has stopped to look at them, which is where a decision about money is
## actually made. That is also why the pouch got its own button.
##
## BAG and PURSE are labelled rather than left as two bare figures with a diamond
## each. Unlabelled, they read as one number that changed, and the whole point of
## showing them together is that they are the two sides of the extraction trade.
func _paint_header() -> void:
	var used := Run.slots_used()
	var full := used >= Game.bag_slots
	_header.text = "%d / %d SLOTS      BAG %d ◇      PURSE %d ◇" \
		% [used, Game.bag_slots, Run.bag_value(), Game.gold]
	# The only colour on the header, and it means one thing: the next mote you
	# walk over is going to stay on the floor.
	_header.modulate = Pal.RUST if full else Color.WHITE


func _paint_stock() -> void:
	var lines: Array[String] = []
	for id in ItemDb.components():
		var have := Game.component_count(id)
		if have <= 0:
			continue
		var def := ItemDb.get_def(id)
		lines.append("%s  ×%d" % [def.display_name, have])
	_stock.text = "\n".join(lines) if not lines.is_empty() \
		else "Nothing yet. Components reach the bench by reaching town."


func _describe(b: Button) -> void:
	if b == null or _detail_name == null:
		return
	var index: int = b.get_meta(&"cell")
	var id: StringName = _cell_ids[index]

	if id == &"":
		_detail_kind.text = "SLOT %d" % (index + 1)
		_detail_name.text = "Empty"
		_detail_value.text = ""
		_detail_blurb.text = "Room for one more stack. Nothing is refused while " \
			+ "there is a cell like this one."
		_detail_legend.text = "Walk over a drop to fill it. There is no pick-up button."
		return

	var def := ItemDb.get_def(id)
	var n: int = b.get_meta(&"count", 1)
	var part := def.is_component()
	_detail_kind.text = "SLOT %d  ·  %s  ·  %s" % [
		index + 1, def.rarity_name().to_upper(),
		"COMPONENT" if part else "INGREDIENT"]
	_detail_name.text = def.display_name
	_detail_value.text = "%d ◇  ·  %d per slot" % [def.value * n, def.stack]
	_detail_blurb.text = def.blurb
	_detail_legend.text = ("The forge eats this. It goes to the workbench when you "
		+ "reach town, not to the vendor.") if part else \
		("The vendor buys this. What it is worth is a quarter of what leaving costs.")
