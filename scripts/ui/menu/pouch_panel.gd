class_name MenuPouchPanel
extends Control
## The INVENTORY screen: what you are carrying, drawn as the fixed number of slots
## you are actually carrying it in.
##
## This is deliberately NOT a list. A list of six rows and a list of twelve rows
## look the same at a glance, and the whole pressure in this game is the
## difference between them (docs/METAGAME.md §3). A grid of `Game.bag_slots`
## cells, most of them visibly empty or visibly not, answers "how much room is
## left" without the player reading a single number — and then the header gives
## them the number anyway, because capacity pressure is the decision it serves.
##
## Three things live here and nowhere else:
##
##  * **The bag**, slot by slot. Stacks occupy one cell until they overflow,
##    exactly as `Run.slots_used()` counts them, so the picture and the
##    arithmetic cannot disagree.
##  * **The document case** — the top five of those slots, drawn as their own
##    row above the rest with what it means written on it (docs/GDD.md §3.1).
##    The case is the one thing on this screen that is worth reading BEFORE you
##    are in trouble, because it is the answer to "what happens if I do not make
##    it back", and §3.1's whole argument is that the answer has to be legible
##    for the entire run rather than rolled at the moment of death. So it is not
##    a mark on five cells: it is a card, with a caption, and A moves a stack
##    across the line in either direction.
##  * **A component mark.** A component and an ingredient compete for the same
##    cell, and which one you are looking at decides whether it is going to the
##    vendor or to the forge. The mark is the ◆ and the caption says which.
##  * **The workbench**, which is what survived. Read-only: this screen shows
##    the stock, the smith spends it.
##
## It owns no state and changes none. Equipping is the EQUIP screen's job (the
## D-pad and the two hands), and the two are separate screens on purpose — one
## is what you are CARRYING and the other is what you are HOLDING, and a player
## who conflates them is a player who thinks the bag can be equipped.

signal back_requested
signal notice(text: String, is_error: bool)
signal drop_requested(item_id: StringName, count: int, from_case: bool)

## No `FRAME_SIZE` here any more. It was one of five identical copies and the
## paper doll needed the frame wider, so it lives in `MenuUtil.FRAME_SIZE` where
## all five screens read the same number — see the comment on it for why they
## have to.

## Cells per row, and the same five every other collection screen in the game
## draws (`ItemGrid.columns`). It was four on both sides until card #120; the
## number now lives in `ItemGrid` for everyone, and this const survives only
## because this panel is the one that has to fight for the width.
##
## The bag holds `Game.bag_slots` (12 at the start, 16 bought out) less the
## case's 5, so the grid is 7 cells at the low end and 11 at the high end: two
## rows then three, where four across was three rows then four. One row shorter
## is the point — the whole bag is one glance instead of a scan.
##
## **Five used to be a fight and is not one any more.** With the old 140 px card
## the grid was 732 px, `Bag` 748, plus `Worn` 152 and 16 between made `Left` 916
## and the frame came out **1320 px inside a 1280 px viewport** — past the screen,
## silently, because a CenterContainer does not save you from a child whose
## minimum size is bigger than the screen, it clips it. The hundred px had to be
## taken off the paper doll and the detail column to make five fit at all.
##
## The shared cell is now a 60 px square, so the same five cells are **332 px**;
## the hover card carries the long name and detail the tighter strip elides.
## `DOLL_W` stays at its comfortable width and the bag keeps generous slack.
##
## The case draws at this width too. It is `Run.CASE_SLOTS` — five tiles in the
## same five-wide grid as every other row, which is exactly what the owner was
## looking at: *"we need the inventory to be 5 per row all rows."*
const COLS := ItemGrid.COLS
## The cell's own numbers moved to `ItemGrid` when every other screen started
## drawing the same cell. Aliased here rather than deleted because the WORN
## column beside the grid matches the cell's text size on purpose — see the note
## where it is used — and a bare 16 there would drift the day the cell changes.
const CELL_NAME_PT := ItemGrid.NAME_PT
## Hard ceiling on cells drawn, so a corrupt `bag_slots` cannot build a grid
## taller than the frame and push the footer off the screen — which is exactly
## how the EQUIP screen broke the first time it was built.
##
## Sixteen is `Game.bag_slots` at its bought maximum, which is the most the game
## can legitimately ask for; at `COLS` = 5 that is four rows rather than the four
## rows of four it used to be, and the real grid is smaller again because the
## case takes five of those slots off the top (`Run.hold_slots`). Kept at the
## bag's ceiling rather than lowered to the 11 the grid can actually be handed,
## because it is a guard against a corrupt number and not a layout constant.
const MAX_CELLS := 16

## The paper doll's column, and twenty px of comfort over `MenuPaperDoll.MIN_SIZE.x`.
## The frame grew from 1060 to `MenuUtil.FRAME_SIZE`'s 1220 to make room for this
## column; card #120 borrowed twenty of it for the fifth bag cell and left the
## doll AT its floor, where the compact card's two hand tiles start eliding the
## item name. Card #156's square tiles handed it back.
const DOLL_W := 152

## The workbench column. The old detail pane is the shared hover card now.
const RIGHT_W := 260

## The header's row, so `PauseMenu` can drop the shared tab strip into it. See
## the same field on `MenuEquipPanel`.
var _hrow: HBoxContainer

var _doll: MenuPaperDoll

## What is in each drawn cell, in grid order: the item id and how many of it are
## in that one cell. `&""` for a slot the bag has not filled. This is the screen's
## own model — `ItemGrid` holds no state of its own and hands back the index into
## this array, which is what `_describe` reads.
var _cell_ids: Array[StringName] = []
var _cell_counts: Array[int] = []
var _grid: ItemGrid
## The same two arrays for the case's five cells, and its own grid. Parallel
## rather than one array with an offset: the two grids are two containers, each
## reports its own indices, and folding them into one range would mean every
## reader doing the arithmetic to find out which side of the line it is on.
var _case_ids: Array[StringName] = []
var _case_counts: Array[int] = []
var _case_grid: ItemGrid
## The `StatBand` and the slot it is rebuilt into. It replaced `_header`, which
## was one right-aligned string carrying three numbers.
var _band: Control
var _band_slot: VBoxContainer
var _stock: GridContainer
var _stock_empty: Label
var _drop: Button
var _back: Button
## The hover card. It replaced five labels in a column on the right — see
## `RIGHT_W` — and it is fed from `_describe` and from nowhere else.
var _tip: ItemTip
## The cell last described by focus, hover or click. The index and side are the
## identity; id/count are refreshed from the live arrays before Drop can emit.
var _selected_index: int = -1
var _selected_from_case: bool = false
var _selected_id: StringName = &""
var _selected_count: int = 0
## `ItemGrid` deliberately treats every press as activation. Inventory needs one
## extra distinction: a mouse click selects for the adjacent Drop verb, while A
## keeps its existing pack/unpack action.
var _mouse_cell_press: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No `theme` of its own: `PauseMenu` puts `UITheme.theme()` on Root and every
	# panel inherits it. This used to override a `menu_theme.tres` that Root
	# carried while the screens converted one at a time; they all have, so the
	# per-panel override went with the .tres.
	_build()
	# The bag changes while this screen is open in exactly one case that matters
	# — a director driving a run with the menu up — but it also changes under a
	# save load, and the workbench changes when a run banks. Redraw on the
	# signals rather than trusting `refresh()` on open to be the only way in.
	Bus.bag_changed.connect(func(_b: Dictionary, _v: int) -> void: refresh())
	Bus.components_changed.connect(func(_s: Dictionary) -> void: refresh())
	Bus.wishlist_changed.connect(refresh)
	Settings.changed.connect(func(section: StringName, key: StringName,
			_value: Variant) -> void:
		if section == &"game" and key == &"auto_wishlist":
			refresh())
	# The bench prints the quiver, and the quiver fills from the world — walk over
	# a bundle with this screen open and the row has to stop offering a batch it
	# no longer has room for.
	Bus.ammo_changed.connect(func(_id: StringName, _n: int) -> void: refresh())
	# `loadout_changed` / `item_selected_changed` are NOT hooked here any more:
	# the doll owns those, and the three lines that used to need them are its
	# tiles now. Two subscribers repainting the same card is how a screen ends up
	# doing its work twice per press.
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
	# `edge_to_edge`, like the Items screen and the counters: the tab strip, the
	# stat band and the footer reach the frame's edge; the body owns its inset.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 14, 6, 14, 0))
	col.add_child(header)
	# The shared tab strip is inserted here by `PauseMenu` and there is no title
	# Label: the lit tab is the title. See `MenuPageTabs`.
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)

	# Four inventory facts in a StatBand under the tab strip. They were one
	# right-aligned sentence that the eye had to parse to separate.
	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override("separation", 0)
	col.add_child(_band_slot)
	_rebuild_band()

	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)

	# THE BENCH IS ON THE LEFT, UNDER the grid -- a ROW of its own, not a third
	# column beside it. Both halves of that sentence were paid for.
	#
	# "On the left" is measured, not guessed: with all four cards stacked on the
	# right the column wanted 627 px and the frame 801, inside a 720 px viewport.
	# Forty pixels of the header and forty of the bench rendered off the top and
	# bottom edges of the screen, and nothing complained -- the same failure the
	# EQUIP screen hit and the same one `_build_stock`'s own comment describes
	# surviving once already. The bench is the only card here that is not
	# focusable, so it is the one that moves.
	#
	# "Under, not beside" is the other half, and it was paid for by a merge: the
	# bench arrived on the left in the same week the paper doll did, and three
	# cards in one row wanted 948 px of a 776 px budget -- frame 1362 in a 1280
	# viewport, forge_loop's B4 red. A row costs width the screen has none of and
	# height the screen has plenty of: `Right` is 474 px tall and this side was
	# 329, so there were 145 px of vertical slack sitting unused next to a
	# horizontal overflow. The bench is the card that can spend it, because it is
	# the only one whose content is a list rather than a shape.
	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	split.add_child(left)

	# Doll, then grid: the figure on the far left, what it is carrying beside it,
	# and what any of that is worth on the right. Left to right, the screen is a
	# sentence about you.
	#
	# **The fifth column (card #120) was paid for out of THIS row's two
	# neighbours, and the reason is that the row itself has no height to trade.**
	# The obvious move was to drop the doll below the bag, where `Bench` was
	# measured at 128 px inside an 816 px column with ~690 px of width doing
	# nothing. It works and it is wrong: the compact doll's own floor is 300 px
	# tall (`MenuPaperDoll.MIN_SIZE`), so under the bag it stacks instead of
	# sitting beside it -- measured `Frame` **1220x900 in a 720 px viewport**, with
	# the bound bottle and the Back button both rendered below the bottom edge and
	# nothing complaining. Beside the bag the doll is free: the
	# card is 342 px tall and so is the doll, so the row costs the taller of two
	# things that are the same height.
	#
	# So the 100 px came out of `DOLL_W` and `DETAIL_W` instead, both of which had
	# slack the picture could show you. See those two consts.
	var carried := HBoxContainer.new()
	carried.name = "Carried"
	carried.add_theme_constant_override("separation", 16)
	# The row takes the column's whole height now that the bench is not under it,
	# so the bag is ONE open well from the case down to the footer -- the field a
	# bag bought up to sixteen slots grows into, instead of a 342 px box with a
	# band of nothing beneath it.
	carried.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(carried)
	_build_doll(carried)
	_build_grid(carried)


	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = RIGHT_W
	# Compact enough for the complete component manifest at 720p.
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	# **The bench came back up the screen with card #156.** It was moved UNDER the
	# bag because three cards in this row wanted 948 px of a 776 px budget (see
	# the note on `Left` above) -- and then the detail column left this side
	# entirely for the hover card, so the bench is a list that fits in what is left.
	# The row that held it is gone,
	# which is 51 px of height back for the bag.
	_build_stock(right)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_drop = Button.new()
	_drop.name = "Drop"
	_drop.text = "Drop"
	_drop.custom_minimum_size.x = 160
	_drop.disabled = true
	_drop.pressed.connect(_on_drop_pressed)
	_drop.focus_entered.connect(_describe_selected)
	frow.add_child(_drop)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)

	# LAST, and a child of the panel rather than of the frame: it has to draw over
	# the bag, the doll and the footer alike, and a card inside the frame would be
	# clipped by it at the two edges where the placement most often lands.
	_tip = ItemTip.make(self)


## The figure, and the three things hanging off it. Read-only: see
## `MenuPaperDoll`'s header for why equipping stays on the EQUIP screen.
##
## A fixed width rather than a share of the row. The bag grid beside it is five
## cells of a measured 140 px and it cannot give any of that back (see `COLS`);
## the doll gets `DOLL_W` and not a pixel of the grid's.
func _build_doll(parent: Node) -> void:
	# A column, not a card. See the same note on `MenuEquipPanel._build_doll`:
	# nested boxes inside a boxed frame are the read the kit undoes, and their
	# padding is width this screen has never had to spare.
	var inner := VBoxContainer.new()
	inner.name = "Worn"
	inner.custom_minimum_size.x = DOLL_W
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	parent.add_child(inner)

	UITheme.section_rule(inner, "WORN")

	# The three "LEFT · Kite Shield" lines that used to sit under the figure are
	# gone: they are the doll's own three `SlotTile`s now, which say the same
	# thing with the slot's glyph beside it and the empty case drawn rather than
	# spelled. Two places naming the same hand is how one of them goes stale.
	_doll = MenuPaperDoll.new()
	_doll.name = "Doll"
	inner.add_child(_doll)


func _paint_doll() -> void:
	# The doll repaints itself off `Bus` (see its `_ready`). This stays as the
	# screen's one-shot hook — `_refresh` calls it on open, when no signal has
	# fired yet and the card would otherwise show the previous run's hands.
	if _doll != null:
		_doll.repaint()


func _build_grid(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Bag"
	# A `well()`, not a raised card: the bag is a thing you reach INTO, and the
	# recess is what tells the two grids apart from the columns beside them now
	# that nothing else here is boxed.
	card.add_theme_stylebox_override("panel", UITheme.well())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	# THE CASE FIRST, and above. It is the top of the bag in the fiction and it
	# has to be the top of the picture.
	# A styled Label rather than a `section_rule`, because the rule is gold and
	# this caption is CYAN: the way out is CYAN and nothing else is (STYLEGUIDE
	# §1), and the case is the OTHER way out — the one that works when you did not
	# make it to the rope. That colour is load-bearing and a divider would eat it.
	var case_cap := Label.new()
	case_cap.text = "DOCUMENT CASE"
	UITheme.apply_text_style(case_cap, UITheme.TYPE_H3, Pal.CYAN)
	inner.add_child(case_cap)

	_case_grid = ItemGrid.new()
	_case_grid.name = "Case"
	# `COLS`, not a second layout width. The case holds five, and its cells share
	# the same five-wide grid and tile size as the row below it. See `COLS`.
	_case_grid.columns = COLS
	_case_grid.cell_focused.connect(_on_case_focused)
	_case_grid.cell_activated.connect(_on_case_activated)
	inner.add_child(_case_grid)

	UITheme.section_rule(inner, "BAG")

	# `ItemGrid` rather than a GridContainer full of hand-built cells. The cell
	# below used to be written out here, and it is the cell every other screen
	# in the game now draws too (scripts/ui/common/item_grid.gd) — the bag is
	# where the look was settled, so the bag is where it was taken from.
	_grid = ItemGrid.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.cell_focused.connect(_on_cell_focused)
	_grid.cell_activated.connect(_on_hold_activated)
	inner.add_child(_grid)


## The bag, laid over `Game.bag_slots` cells.
##
## Called from `refresh()` rather than once from `_build`, because a bag slot
## bought at the smith has to show up as a new empty cell the next time the
## screen opens — the grid IS the capacity, so it cannot be built once and
## trusted. `ItemGrid.set_cells` reuses the buttons when the count has not moved,
## so the common case does not drop focus.
##
## The layout is `Run.slots_used()`'s: full stacks first, then the remainder.
## Anything that will not fit is dropped from the PICTURE only — it cannot happen
## while `bag_slots` and the grid agree, and if it ever does the header's number
## is still right.
##
## Two grids now, laid out from the same rule and from the two halves `Run` keeps
## — `Run.in_case(id)` and `Run.in_hold(id)`. The case's five cells are the
## bag's top five slots, so the HOLD is `bag_slots - CASE_SLOTS` and every slot
## the smith sells lands in it (`Run.hold_slots`).
func _fill_cells() -> void:
	var want := clampi(Run.hold_slots(), 1, MAX_CELLS)
	_lay_out(_cell_ids, _cell_counts, want, false)
	_lay_out(_case_ids, _case_counts, Run.CASE_SLOTS, true)

	# `capacity` is the point of this screen: the empty cells are the message.
	# Out of the case comes the bag; the case is never the last row.
	_case_grid.set_cells(_cells_of(_case_ids, _case_counts), Run.CASE_SLOTS)
	_grid.spill_down = _back
	_grid.set_cells(_cells_of(_cell_ids, _cell_counts), want)
	_wire_cell_selection(_case_grid, true)
	_wire_cell_selection(_grid, false)
	_case_grid.spill_down = _grid.cell_at(0)
	# Out of the bottom of the bag comes the footer directly.
	_wire_focus()


## `ItemGrid` reports padding cells as -1 because most collections do not care
## which empty position was crossed. Inventory does: an empty selected cell must
## disable Drop, so this panel adds the exact cell position without changing the
## shared grid contract. Focus, hover and click all describe the same cell.
func _wire_cell_selection(grid_of: ItemGrid, case_side: bool) -> void:
	for i in grid_of.count():
		var cell := grid_of.cell_at(i)
		if cell == null or cell.has_meta(&"pouch_selection"):
			continue
		cell.set_meta(&"pouch_selection", true)
		var index := i
		cell.focus_entered.connect(func() -> void: _describe(index, case_side))
		cell.mouse_entered.connect(func() -> void: _describe(index, case_side))
		cell.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_mouse_cell_press = true)
		cell.pressed.connect(func() -> void:
			_describe(index, case_side)
			_mouse_cell_press = false)


## One region's cells, in grid order: the item id and how many are in that cell.
## `case_side` picks which half of each stack is being laid out — the packed one
## or the loose one — which is why a stack split across the line draws twice, in
## two cells, exactly as `Run.slots_used()` counts it.
func _lay_out(ids: Array[StringName], counts: Array[int], want: int,
		case_side: bool) -> void:
	ids.resize(want)
	counts.resize(want)
	ids.fill(&"")
	counts.fill(0)
	var at := 0
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var per: int = maxi(def.stack, 1)
		var left: int = Run.in_case(id) if case_side else Run.in_hold(id)
		while left > 0 and at < want:
			ids[at] = id
			counts[at] = mini(left, per)
			left -= per
			at += 1


func _cells_of(ids: Array[StringName], counts: Array[int]) -> Array:
	var entries: Array = []
	for i in ids.size():
		if ids[i] == &"":
			continue
		var def := ItemDb.get_def(ids[i])
		entries.append({
			"index": i,
			"label": def.display_name,
			"sub": "×%d" % counts[i],
			"tint": def.tint,
			"icon": UiKit.item_icon(ids[i]),
			"mark": def.is_component(),
			"star": Wishlist.is_wishlisted(ids[i]),
		})
	return entries


## What made it home. Not focusable and not editable — it is the answer to "can
## I afford the next rung", shown next to the bag it came out of.
func _build_stock(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.name = "Bench"
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	UITheme.section_rule(col, "WORKBENCH")

	# Four columns, not one line per material. The bench held four things when
	# this was a single autowrapping Label; the alchemist's four brought it to
	# eight, and eight rows grew the right column until the frame was 872 px
	# tall inside a 720 px viewport -- the bottom half of the list rendered off
	# the screen and nothing complained.
	#
	# It was two columns while the card was a 160 px sliver in a row of three.
	# Now that it has the whole width under the doll and the grid, four fits: the
	# full eight-material bench is two rows instead of four, which is what keeps
	# this side under `Right`'s 474 px and the frame at the height it was before
	# the bench moved at all. A ninth material still costs a quarter of a row.
	_stock = GridContainer.new()
	_stock.name = "BenchGrid"
	# Two, not the four it had while the bench spanned the whole width under the
	# bag. `RIGHT_W` is 260 and a component's "Whetstone Grit  ×12" wants half of
	# that; four columns here would push the column wider than the frame allows.
	_stock.columns = 2
	_stock.add_theme_constant_override("h_separation", 14)
	_stock.add_theme_constant_override("v_separation", 2)
	col.add_child(_stock)

	# The empty case cannot live in the grid: a GridContainer has no column
	# span, so one long sentence in cell 0 would set the width of column 1.
	_stock_empty = Label.new()
	UITheme.apply_text_style(_stock_empty, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_stock_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_empty.text = "Nothing yet. Components reach the bench by reaching the garrison."
	col.add_child(_stock_empty)


## The bag's bottom row reaches the footer directly; Back closes onto the case's
## first cell, and Drop remains the adjacent contextual branch.
func _wire_focus() -> void:
	# The loop closes on the CASE's first cell, not the bag's, because the case is
	# now the top of the screen and Back's job is to return you to the top.
	var first := _case_grid.cell_at(0)
	if first == null:
		first = _grid.cell_at(0)
	if first == null:
		return
	MenuUtil.link_right(_drop, _back)
	var last := _grid.cell_at(_grid.count() - 1)
	if last != null:
		_drop.focus_neighbor_top = _drop.get_path_to(last)
	_drop.focus_neighbor_bottom = _drop.get_path_to(first)
	_back.focus_neighbor_bottom = _back.get_path_to(first)
	_back.focus_next = _back.get_path_to(first)
	_back.focus_neighbor_right = ^"."


# --- State ------------------------------------------------------------------

## Called every time the screen is entered.
func focus_first() -> void:
	# On the case, deliberately. The first thing the screen should say when it
	# opens is what survives you (docs/GDD.md §3.1) — a cursor that started in the
	# hold would put the answer one flick away from a player who never asked.
	var first := _case_grid.cell_at(0)
	if first == null:
		first = _grid.cell_at(0)
	if first != null:
		first.grab_focus()


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


## The top row of focusables, landing target first — `PauseMenu` joins these to
## the tab strip so ↑ leaves the page through them and ↓ off a tab comes back
## down onto the first (card #120, `MenuPageTabs`).
##
## The CASE's five cells and not the bag's. The case is the top of the picture
## and the row `focus_first` already opens on, so it is the row a player leaves
## upwards through; the bag's own top row exits upwards INTO the case, which is
## the move it has always made.
##
## Re-read on every page entry rather than cached: `ItemGrid` frees and rebuilds
## its buttons when the slot count changes, so a held reference is a link into a
## freed node one bag slot from now.
func tab_row() -> Array:
	var out: Array = []
	for i in Run.CASE_SLOTS:
		var c := _case_grid.cell_at(i)
		if c != null:
			out.append(c)
	if out.is_empty():
		var first := _grid.cell_at(0)
		if first != null:
			out.append(first)
	return out


## The bag's cells, for a director that wants to count what is drawn rather than
## what the panel believes. Public because "the grid IS the capacity" is a claim
## worth being able to check from outside.
func grid() -> ItemGrid:
	return _grid


func refresh() -> void:
	_fill_cells()
	_sync_selected_cell()
	_paint_doll()
	_paint_header()
	_paint_stock()
	var focused := get_viewport().gui_get_focus_owner()
	if not _describe_focus(focused) and _selected_index < 0:
		# The cursor is on a cell, or on nothing at all because the screen has
		# only just been built. Either way the detail pane describes a cell, and
		# the grid is the one that knows which button is which index.
		_describe(0, true)


## Which cell the focus is on, and which side of the line, after a refresh that
## did not go through either grid's own signal. The grids hand out their own
## buttons, so asking them beats keeping a parallel array of them here — the
## parallel array was what `_cells` used to be, and it was one more thing that
## could disagree with what is drawn. A focus on neither grid describes the
## case's first cell, because that is where `focus_first` puts the cursor.
func _describe_focus(focused: Control) -> bool:
	for i in _case_grid.count():
		if _case_grid.cell_at(i) == focused:
			_describe(i, true)
			return true
	for i in _grid.count():
		if _grid.cell_at(i) == focused:
			_describe(i, false)
			return true
	return false


## The grid says a cell was looked at; the detail pane says what it is.
func _on_cell_focused(index: int) -> void:
	if index >= 0:
		_describe(index, false)


func _on_case_focused(index: int) -> void:
	if index >= 0:
		_describe(index, true)


func _select_cell(index: int, case_side: bool) -> void:
	_selected_index = index
	_selected_from_case = case_side
	_selected_id = &""
	_selected_count = 0
	var ids: Array[StringName] = _case_ids if case_side else _cell_ids
	var counts: Array[int] = _case_counts if case_side else _cell_counts
	if index >= 0 and index < ids.size():
		var id: StringName = ids[index]
		var count: int = counts[index]
		if id != &"" and count > 0 and ItemDb.get_def(id) != null:
			_selected_id = id
			_selected_count = count
	if _drop != null:
		_drop.disabled = _selected_id == &"" or _selected_count <= 0


func _sync_selected_cell() -> void:
	_select_cell(_selected_index, _selected_from_case)


func _describe_selected() -> void:
	if _selected_index >= 0:
		_describe(_selected_index, _selected_from_case)


func _on_drop_pressed() -> void:
	_sync_selected_cell()
	if _selected_id == &"" or _selected_count <= 0:
		return
	drop_requested.emit(_selected_id, _selected_count, _selected_from_case)


## A on a carried cell packs that stack into the case.
##
## A whole cell at a time, in both directions. Per-item packing would be the more
## flexible verb and it is the wrong one: the case is five slots and the choice
## §3.1 wants you making is *which things*, not how many of a thing — and a
## part-stack moved on its own costs a slot on each side of the line for nothing.
func _on_hold_activated(index: int) -> void:
	if _mouse_cell_press:
		return
	if index < 0 or index >= _cell_ids.size():
		return
	var id: StringName = _cell_ids[index]
	if id == &"":
		return
	if Run.stow(id, _cell_counts[index]) <= 0:
		var why := Run.case_refusal(id)
		notice.emit(why if why != "" else "That will not fit in the case.", true)
		return
	notice.emit("%s packed." % ItemDb.get_def(id).display_name, false)
	refresh()


## A on a cased cell takes it back out. It stays in the bag.
func _on_case_activated(index: int) -> void:
	if _mouse_cell_press:
		return
	if index < 0 or index >= _case_ids.size():
		return
	var id: StringName = _case_ids[index]
	if id == &"":
		return
	if Run.unstow(id, _case_counts[index]) <= 0:
		notice.emit("There is no room in the bag for that outside the case.", true)
		return
	notice.emit("%s unpacked." % ItemDb.get_def(id).display_name, false)
	refresh()


## Four useful inventory facts.
##
## The HUD used to print a running gold total in the corner and it was taken out
## on purpose (see hud.gd `_draw_bag`): money on screen turns a dungeon into an
## accounting exercise. So the bag's worth and the purse live HERE, where the
## player has stopped to look at them, which is where a decision about money is
## actually made. That is also why the pouch got its own button.
##
## BAG and PURSE are labelled rather than left as two bare figures with a diamond
## each. Unlabelled, they read as one number that changed.
## Slots goes WARNING at the brim. Safe reports the document-case occupancy
## already drawn immediately below the band.
func _band_cells() -> Array:
	var used := Run.slots_used()
	return [
		{"key": &"slots", "label": "Slots",
			"value": "%d / %d" % [used, Game.bag_slots],
			"icon": UiKit.action_icon("bag"),
			"tone": UITheme.WARNING if used >= Game.bag_slots else null},
		{"key": &"worth", "label": "Bag", "value": "%d ◇" % Run.bag_value()},
		{"key": &"purse", "label": "Purse", "value": "%d ◇" % Game.gold,
			"icon": UiKit.action_icon("coin")},
		{"key": &"safe", "label": "Safe",
			"value": "%d / %d" % [Run.case_slots_used(), Run.CASE_SLOTS]},
	]


func _rebuild_band() -> void:
	if _band_slot == null:
		return
	for child in _band_slot.get_children():
		child.queue_free()
		_band_slot.remove_child(child)
	_band = UiKit.stat_band(_band_slot, _band_cells())


func _paint_header() -> void:
	_rebuild_band()


func _paint_stock() -> void:
	for old in _stock.get_children():
		old.queue_free()
		# queue_free() is next-frame; the grid is repainted every time the
		# screen opens, so without this the freed rows are still children and
		# the columns double.
		_stock.remove_child(old)
	var any := false
	for id in ItemDb.components():
		var have := Game.component_count(id)
		if have <= 0:
			continue
		var def := ItemDb.get_def(id)
		var row := Label.new()
		UITheme.apply_text_style(row, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT)
		row.text = "%s  ×%d" % [def.display_name, have]
		_stock.add_child(row)
		any = true
	_stock.visible = any
	_stock_empty.visible = not any


## What the cursor is on, said on the hover card beside it.
##
## The card is anchored to the CELL, which is why this takes the grid as well as
## the index: `ItemGrid.cell_for` is the only thing that knows which button is
## reporting a given slot, and a bag laid out over slots has holes in it.
func _describe(index: int, case_side: bool) -> void:
	var ids: Array[StringName] = _case_ids if case_side else _cell_ids
	var counts: Array[int] = _case_counts if case_side else _cell_counts
	var grid_of: ItemGrid = _case_grid if case_side else _grid
	_select_cell(index, case_side)
	if _tip == null or index < 0 or index >= ids.size():
		return
	var id: StringName = ids[index]
	# The case's five slots are the bag's first five, so the number the player
	# reads is continuous across the line even though the cells are two grids.
	var slot := index + 1 if case_side else index + 1 + Run.CASE_SLOTS

	_tip.clear()
	_tip.point_at(grid_of.cell_for(index))

	if id == &"":
		_tip.kicker.text = "CASE %d" % slot if case_side else "SLOT %d" % slot
		_tip.title.text = "Empty"
		if case_side:
			_tip.blurb.text = "Room for one more stack."
			_tip.say_note("Press A on a Bag item to pack it. " \
				+ "Relics will not fit.", UITheme.TEXT_DIM)
		else:
			_tip.blurb.text = "Room for one more stack. Nothing is refused while " \
				+ "there is a cell like this one."
			_tip.say_note("Walk over a drop to fill it. There is no pick-up button.",
				UITheme.TEXT_DIM)
		return

	var def := ItemDb.get_def(id)
	var n: int = counts[index]
	var part := def.is_component()
	var supply := def.is_supply()
	var kind_label := def.bench_name() if part else "SUPPLY" if supply else "INGREDIENT"
	_tip.kicker.text = "%s %d  ·  %s  ·  %s" % [
		"CASE" if case_side else "SLOT", slot, def.rarity_name().to_upper(),
		kind_label]
	_tip.title.text = def.display_name
	_tip.price.text = "%d ◇  ·  %d per slot" % [def.value * n, def.stack]
	_tip.blurb.text = "%s  %s" % [def.blurb, Wishlist.usage_sentence(id)]
	# WHICH bench, by name. Two counters eat components now and they are at
	# opposite ends of the yard; a caption that said "the forge" over a Fired
	# Cullet would send the player to the wrong one.
	var fate := "Take this to the south-gate supply box." if supply else \
		(("%s eats this. It goes to the workbench when you reach "
		+ "garrison, not to the vendor.") % def.bench_name().capitalize() if part else \
		("The vendor buys this. What it is worth is a quarter of what leaving costs."))
	# The verb, on the end, and phrased as the consequence rather than the key —
	# what A does here is decide whether this survives you.
	_tip.say_note(fate + ("   A takes it out of the case." if case_side
		else "   A packs it into the case.")
		+ "   Drop throws this displayed stack onto the floor.", UITheme.TEXT_DIM)
