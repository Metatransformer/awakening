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
##  * **The document case** — the top three of those slots, drawn as their own
##    row above the rest with what it means written on it (docs/GDD.md §3.1).
##    The case is the one thing on this screen that is worth reading BEFORE you
##    are in trouble, because it is the answer to "what happens if I do not make
##    it back", and §3.1's whole argument is that the answer has to be legible
##    for the entire run rather than rolled at the moment of death. So it is not
##    a mark on three cells: it is a card, with a caption, and A moves a stack
##    across the line in either direction.
##  * **A component mark.** A component and an ingredient compete for the same
##    cell, and which one you are looking at decides whether it is going to the
##    vendor or to the forge. The mark is the ◆ and the caption says which.
##  * **The workbench**, which is what survived. Read-only: this screen shows
##    the stock, the smith spends it.
##  * **The way out**, its fee, and the HOLD it now takes — Y, down for
##    `ROPE_HOLD` seconds, with the gauge. It moved here off the ITEMS screen, and the
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

## No `FRAME_SIZE` here any more. It was one of five identical copies and the
## paper doll needed the frame wider, so it lives in `MenuUtil.FRAME_SIZE` where
## all five screens read the same number — see the comment on it for why they
## have to.
##
## The hint carries four things and it is at its limit. "Hands change on ITEMS"
## is on it rather than under the WORN card because the misconception it heads
## off — that the doll is where you equip — is formed by looking at the doll and
## then looking for the verb, and the verbs are all on this line.
##
## A does two things on this screen and the hint names both in the order the
## focus meets them: on a bag cell it moves the stack across the document-case
## line, on the card below it fletches. One key, two objects, and the line has
## no room to say that twice.
const HINT := "↑↓←→ Look   E / A Pack / Fletch   Hold Y Escape   Esc / B Back   Hands change on ITEMS"

## The action the way out is held on: Y on the pad, Y on the keyboard.
##
## Not `ui_accept`. A is the universal forward press in every menu in this game
## and it is one row below on this very screen, where it fletches arrows — a
## thing you press repeatedly and on purpose. The run-ending control cannot be
## the same button as the repeatable one, and a HOLD on a DIFFERENT button is
## two independent reasons the fumble cannot happen.
const HOLD_ACTION := &"ui_hold"

## Seconds on Y. Longer than the shop's 0.5 s craft hold and the same length as
## the gate's descent, because those spend materials and this ends the run. [tune]
##
## It is a real hold and not ceremony: the thing it guards against is the press
## you make while reading something else on this screen.
const ROPE_HOLD := 0.9

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
## The cell's own numbers moved to `ItemGrid` when every other screen started
## drawing the same cell. Aliased here rather than deleted because the WORN
## column beside the grid matches the cell's text size on purpose — see the note
## where it is used — and a bare 16 there would drift the day the cell changes.
const CELL_NAME_PT := ItemGrid.NAME_PT
## Hard ceiling on cells drawn, so a corrupt `bag_slots` cannot build a grid
## taller than the frame and push the footer off the screen — which is exactly
## how the ITEMS screen broke the first time it was built.
## Four rows of four. That is the bought maximum, so it is also the tallest grid
## the frame was measured against.
const MAX_CELLS := 16

## The paper doll's column. The frame grew from 1060 to `MenuUtil.FRAME_SIZE`'s
## 1220 to make room for exactly this, so the number is the width that was added
## less the separation beside it -- the grid's budget above is unchanged.
const DOLL_W := 152

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
## The same two arrays for the case's three cells, and its own grid. Parallel
## rather than one array with an offset: the two grids are two containers, each
## reports its own indices, and folding them into one range would mean every
## reader doing the arithmetic to find out which side of the line it is on.
var _case_ids: Array[StringName] = []
var _case_counts: Array[int] = []
var _case_grid: ItemGrid
var _header: Label
var _stock: GridContainer
var _stock_empty: Label
var _back: Button
var _detail_kind: Label
var _detail_name: Label
var _detail_value: Label
var _detail_blurb: Label
var _detail_legend: Label
var _rope: Button
var _rope_fee: Label
var _rope_bar: HoldBar
var _rope_say: Label
## Seconds of Y accumulated. Snapped to 0 on release, never decayed.
var _rope_hold: float = 0.0
## The hold starts DISARMED and arms on the first frame Y is up. Without it, a
## player who opens the pouch with Y already down (it is `jump` in the world)
## arrives on this screen part-way through leaving the dungeon.
var _rope_armed: bool = false
var _fletch: Button
var _fletch_have: Label
var _fletch_cost: Label


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
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	# The shared tab strip is inserted here by `PauseMenu` and there is no title
	# Label: the lit tab is the title. See `MenuPageTabs`.
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var hrow := _hrow
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

	# THE BENCH IS ON THE LEFT, UNDER the grid -- a ROW of its own, not a third
	# column beside it. Both halves of that sentence were paid for.
	#
	# "On the left" is measured, not guessed: with all four cards stacked on the
	# right the column wanted 627 px and the frame 801, inside a 720 px viewport.
	# Forty pixels of the header and forty of the bench rendered off the top and
	# bottom edges of the screen, and nothing complained -- the same failure the
	# ITEMS screen hit and the same one `_build_stock`'s own comment describes
	# surviving once already. The bench is the only card here that is not
	# focusable and not part of the extraction arithmetic, so it is the one that
	# moves.
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
	var carried := HBoxContainer.new()
	carried.name = "Carried"
	carried.add_theme_constant_override("separation", 16)
	left.add_child(carried)
	_build_doll(carried)
	_build_grid(carried)

	_build_stock(left)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = 340
	# 8 and not the 12 the other columns use. This column stacks four cards and
	# is the tallest thing on the screen -- it, not the frame's 604, is what sets
	# the pouch's height, and at 12 the footer's Back button ran off the bottom
	# of a 720p viewport. Four px a gap is the whole difference.
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	_build_detail(right)
	_build_fletch(right)
	_build_rope(right)

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


## The figure, and the three things hanging off it. Read-only: see
## `MenuPaperDoll`'s header for why equipping stays on the ITEMS screen.
##
## A fixed width rather than a share of the row. The bag grid beside it is four
## cells of a measured 140 px and it cannot give any of that back (see `COLS`);
## the doll gets the width the frame grew by and not a pixel of the grid's.
func _build_doll(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Worn"
	card.theme_type_variation = &"MenuSection"
	card.custom_minimum_size.x = DOLL_W
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "WORN"
	inner.add_child(caption)

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
	card.theme_type_variation = &"MenuSection"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	# THE CASE FIRST, and above. It is the top of the bag in the fiction and it
	# has to be the top of the picture, because the sentence this card makes when
	# you read it downwards is the design: this comes home, this does not.
	var case_cap := Label.new()
	case_cap.theme_type_variation = &"MenuHeading"
	case_cap.text = "THE DOCUMENT CASE  ·  COMES HOME"
	# CYAN is the way out (STYLEGUIDE §1), and the case is the other way out --
	# the one that works when you did not make it to the rope.
	case_cap.modulate = Pal.CYAN
	inner.add_child(case_cap)

	_case_grid = ItemGrid.new()
	_case_grid.name = "Case"
	_case_grid.columns = Run.CASE_SLOTS
	_case_grid.cell_focused.connect(_on_case_focused)
	_case_grid.cell_activated.connect(_on_case_activated)
	inner.add_child(_case_grid)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "CARRIED  ·  DIES WITH YOU"
	inner.add_child(caption)

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
## so the common case (a refresh after fletching) does not drop focus.
##
## The layout is `Run.slots_used()`'s: full stacks first, then the remainder.
## Anything that will not fit is dropped from the PICTURE only — it cannot happen
## while `bag_slots` and the grid agree, and if it ever does the header's number
## is still right, which is the number the fee is taken from.
##
## Two grids now, laid out from the same rule and from the two halves `Run` keeps
## — `Run.in_case(id)` and `Run.in_hold(id)`. The case's three cells are the
## bag's top three slots, so the HOLD is `bag_slots - CASE_SLOTS` and every slot
## the smith sells lands in it (`Run.hold_slots`).
func _fill_cells() -> void:
	var want := clampi(Run.hold_slots(), 1, MAX_CELLS)
	_lay_out(_cell_ids, _cell_counts, want, false)
	_lay_out(_case_ids, _case_counts, Run.CASE_SLOTS, true)

	# `capacity` is the point of this screen: the empty cells are the message.
	# Out of the case comes the bag; the case is never the last row.
	_case_grid.set_cells(_cells_of(_case_ids, _case_counts), Run.CASE_SLOTS)
	_grid.spill_down = _fletch
	_grid.set_cells(_cells_of(_cell_ids, _cell_counts), want)
	_case_grid.spill_down = _grid.cell_at(0)
	# Out of the bottom of the grid comes the bench, then the way out, and only
	# then Back. That order is the screen's argument in one column: here is what
	# you are carrying, here is what it can become, here is what it costs to keep
	# it, here is the door.
	_wire_focus()


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
			"mark": def.is_component(),
		})
	return entries


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
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


## The fletching bench. The one thing on this screen that turns the bag into
## something other than money.
##
## It is a card and not a cell verb, and that distinction is the whole reason it
## fits here. `_make_cell` says a cell does nothing when pressed and that is
## still true: you cannot drop, sort or use an item, because the vendor buys
## them and the forge eats them, both in the garrison. What this adds is a verb
## belonging to the BAG, not to any item in it — the same shape the escape rope
## already has, sitting directly below it for the same reason. Both spend the
## bag; one spends it on getting out and one spends it on staying in.
##
## Why it lives on the pouch at all: the recipe eats the cheapest two things in
## the grid to the left, so the price and the stock are the same picture. Putting
## it on the ITEMS screen would mean reading a cost on one screen against a
## quantity on another, and the whole argument of this screen is that the
## extraction decision is made by stopping and LOOKING at what you have.
func _build_fletch(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Fletch"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "FLETCHING"
	inner.add_child(caption)

	_fletch = Button.new()
	_fletch.name = "Fletch"
	_fletch.theme_type_variation = &"MenuRow"
	_fletch.focus_mode = Control.FOCUS_ALL
	_fletch.text = "➶  Fletch Arrows"
	inner.add_child(_fletch)

	_fletch_have = Label.new()
	_fletch_have.name = "Have"
	_fletch_have.theme_type_variation = &"MenuValue"
	_fletch_have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fletch_have.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fletch_have.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fletch.add_child(_fletch_have)
	_fletch_have.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fletch_have.offset_right = -16

	# The recipe, under the row rather than only in the detail pane, for the same
	# reason the rope's fee is: "fletch arrows" and "fletch arrows for two flint
	# and two bone shard, and you have one flint" are different sentences, and the
	# second one is the only one you can act on.
	_fletch_cost = Label.new()
	_fletch_cost.name = "Cost"
	_fletch_cost.theme_type_variation = &"MenuSlotStat"
	_fletch_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_fletch_cost)

	_fletch.pressed.connect(_do_fletch)
	_fletch.focus_entered.connect(_describe_fletch)
	_fletch.mouse_entered.connect(_describe_fletch)


## Make a batch, or say why not. Repeatable: the row keeps focus and the screen
## repaints, so a player with a bag full of shards can sit here and fill the
## quiver a batch at a time and watch both numbers move. That is deliberate —
## the cost is visible on every press, so there is nothing to protect them from.
func _do_fletch() -> void:
	var why := Fletching.refusal()
	if not why.is_empty():
		notice.emit(why, true)
		Bus.request_sfx.emit(&"craft_fail", Vector3.ZERO)
		return
	var made := Fletching.fletch()
	if made <= 0:
		notice.emit("The fletching failed.", true)
		return
	Bus.request_sfx.emit(&"craft_success", Vector3.ZERO)
	notice.emit("Fletched %d arrows. %d in the quiver." % [made, Game.arrows], false)
	refresh()
	_describe_fletch()


func _describe_fletch() -> void:
	_detail_kind.text = "THE BENCH"
	_detail_name.text = "Fletch Arrows"
	# `batch()`, never `BATCH`. The constant is the un-donated yield; the
	# Fletcher's Jig raises it, and a panel reading the const says 5 over a bench
	# that cuts 7.
	_detail_value.text = "%d arrows  ·  %d / %d in the quiver" \
		% [Fletching.batch(), Game.arrows, Game.max_arrows]
	_detail_blurb.text = "Flint for the heads, bone for the shafts. It is what " \
		+ "the bottom of the bag is for, and it is the only reason to be glad " \
		+ "of a shard."
	var why := Fletching.refusal()
	_detail_legend.text = why if not why.is_empty() else \
		"Costs slots, not gold. The smith is cheaper; the smith is also upstairs."


## What the bench can do right now, live on the row. Enabled even when it will
## refuse, exactly like the rope — a greyed row says you cannot and never says
## what you are short of, and here you are always short of something nameable.
func _paint_fletch() -> void:
	if _fletch == null:
		return
	_fletch_cost.text = Fletching.cost_line()
	var ready := Fletching.can_fletch()
	_fletch_have.text = "+%d" % mini(Fletching.batch(), Fletching.quiver_room()) \
		if ready else "—"
	_fletch_have.modulate = Color.WHITE if ready else Pal.RUST
	_fletch_cost.modulate = Color.WHITE if ready else Color(1, 1, 1, 0.55)


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
## the fumble the hold was guarding against.
##
## **So the hold came back, here.** The row does not fire on A — it fires on Y
## held for `ROPE_HOLD` seconds, anywhere on this screen, with the gauge every
## other hold in the game uses. What A does now is say so, because a control that
## does nothing when you press the button everything else answers to is a control
## the player files a bug about (`HoldGauge`'s whole opening argument).
##
## Why the world channel is still there and this is not a replacement for it:
## they guard different things. The channel is INTERRUPTIBLE — something swinging
## at you can break it, which is what makes leaving a decision made in a room
## rather than in a menu. This is the FUMBLE guard: the menu is paused, so no
## amount of holding in here can be interrupted by anything, and a hold whose
## only job is to be deliberate is exactly the right shape for a press made one
## row below the button you spam to fletch arrows.
func _build_rope(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Use"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
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

	# CYAN, because the way out is CYAN and nothing else is (STYLEGUIDE §1) —
	# the same colour the rope's slats climb the hero in and the same colour the
	# HUD's extraction ring closes in. One hold, drawn twice, in one hue.
	_rope_bar = HoldBar.new()
	_rope_bar.name = "Hold"
	_rope_bar.col = Pal.CYAN
	_rope_bar.pin_to_bottom_of(_rope)

	# The instruction, on the row. `HoldGauge`'s rule is that a hold says it in
	# language AND in shape, because either one alone has already shipped as a bug
	# here: the word with no bar was a player tapping and filing "it doesn't
	# work", and the bar with no word is a player watching something fill without
	# knowing they are the one filling it.
	_rope_say = Label.new()
	_rope_say.name = "Say"
	_rope_say.theme_type_variation = &"MenuSlotStat"
	_rope_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_rope_say)

	_rope.pressed.connect(_on_rope_pressed)
	_rope.focus_entered.connect(_describe_rope)
	_rope.mouse_entered.connect(_describe_rope)


## The hold, ticked while this screen is up.
##
## `_process`, polling `Input`, and not `_unhandled_input`: a hold is a duration
## and there is no event for "still down". It is also the only thing that works
## here — the menu pauses the tree and `Input.action_press` (which every director
## drives this with) sets action STATE and dispatches no InputEvent at all
## (CLAUDE.md §3). This node reaches `_process` while paused because PauseMenu is
## PROCESS_MODE_ALWAYS and children inherit it.
##
## Held ANYWHERE on the screen, not only with the row focused. The row is a
## readout of a decision you make by looking at the grid and the header, and
## making the player navigate to it first would put a focus move between reading
## the number and acting on it.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		# Hidden is not the same as un-processed: a Control keeps ticking when its
		# parent screen is swapped out, and without this the pouch would fill its
		# gauge from another screen's Y press.
		_reset_hold()
		return

	if not Input.is_action_pressed(HOLD_ACTION):
		_rope_armed = true
		_reset_hold()
		return
	if not _rope_armed:
		return

	# Refused on the FIRST frame of the press, never after a full second of
	# holding. Making a player hold something down to be told no is the one thing
	# worse than a dead button: it costs them the second AND teaches them the
	# gauge is a lie.
	var why := _rope_refusal()
	if not why.is_empty():
		_rope_armed = false
		notice.emit(why, true)
		Bus.request_sfx.emit(&"craft_fail", Vector3.ZERO)
		return

	_rope_hold += delta
	if _rope_hold >= ROPE_HOLD:
		# Disarmed, so a button still down through the scene change cannot be read
		# as the beginning of a second one.
		_rope_armed = false
		_reset_hold()
		_use_rope()
		return
	_rope_bar.progress = _rope_hold / ROPE_HOLD


## Snapped to zero, not decayed. A bar that drains says "keep going", and letting
## go was the opposite of that (`trade_screen._tick_input` says the same).
func _reset_hold() -> void:
	_rope_hold = 0.0
	if _rope_bar != null:
		_rope_bar.progress = 0.0


## Why the rope will not work right now, or "" if it will.
##
## Being poor is no longer on this list. It was, and it was the game's one dead
## end -- the rope told a player holding the best bag of the night that it wanted
## more gold than they had, in a place where nothing sells. The fee is capped at
## the purse now (`Run.extract_charge`); what used to be a refusal is `_rope_warning`
## below, which is a sentence about a price rather than a locked door.
func _rope_refusal() -> String:
	if not Run.in_dungeon:
		return "You are already home."
	return ""


## What the player should know before they hold, or "" if the price is ordinary.
## Not a refusal: the hold works either way, and the track under it stays drawn.
func _rope_warning() -> String:
	if not Run.extract_takes_all():
		return ""
	return "The rope wants %d and you have %d. It will take all of it." \
		% [Run.extract_cost(), Game.gold]


## A on the row. It does not leave — it points at the button that does.
##
## The alternative was to make the row unfocusable, and that is worse: the row
## is where the fee and the detail pane live, and a player who cannot put the
## cursor on the way out has no way to read what leaving costs. So it keeps the
## focus and answers the universal confirm with the one sentence that is useful.
func _on_rope_pressed() -> void:
	var why := _rope_refusal()
	if not why.is_empty():
		notice.emit(why, true)
		return
	notice.emit("Hold %s to use the rope." % _hold_glyph(), false)


## The hold button, named off the LIVE InputMap and on the device in the player's
## hands (`Glyph`). Both bindings happen to be "Y" today; this file is not the
## place that decides that, and a line reading "Hold Y" to somebody who rebound
## it is the bug Glyph exists to prevent.
func _hold_glyph() -> String:
	var e := Glyph.event_for(HOLD_ACTION, Settings != null and Settings.using_pad)
	if e == null:
		e = Glyph.event_for(HOLD_ACTION, false)
	return Glyph.long(e) if e != null else "Y"


## Leaving is not something to do from inside a menu screen: the channel happens
## in the world and the player has to be able to see it. So the menu closes and
## the hero's rope node takes it from there (`Bus.escape_rope_used`).
func _use_rope() -> void:
	var why := _rope_refusal()
	if not why.is_empty():
		notice.emit(why, true)
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
	# The CHARGE, not the toll — this is the line that answers "what does leaving
	# cost", so it has to name the gold that actually goes. When the two differ
	# the blurb below spells out why, so the smaller number is never a mystery.
	_detail_value.text = "%d gold" % Run.extract_charge()
	_detail_blurb.text = "It pulls you home and heals what the dark took. " \
		+ "The fee is a quarter of what you are carrying, and the fee is why " \
		+ "the greedy run is a decision."
	var warn := _rope_warning()
	if not warn.is_empty():
		# The whole purse is a real price and it earns a whole sentence. It is not
		# a refusal and never stops the hold, so it reads as a cost being named —
		# which is what it is.
		_detail_blurb.text += "  " + warn \
			+ " You will reach the garrison broke, with a bag to sell."
	# Both halves of the way out, in the order the player meets them: the hold in
	# here, then the channel out there. They are separate on purpose — one cannot
	# be fumbled, the other can be interrupted (see `_build_rope`).
	_detail_legend.text = "Hold %s. Then it takes a moment, and a blow that lands breaks it." \
		% _hold_glyph()


## The fee, live. It is on the row rather than only in the detail pane because
## it is the whole decision: "leave" and "leave for 340 gold" are different
## sentences and the player should not have to focus the row to read the second.
##
## The row never greys out. The only thing that can refuse it now is being in
## garrison, and there the fee reads "—" rather than a number, which says it on
## its own. An expensive rope is not a disabled rope: the price is the message.
func _paint_rope() -> void:
	if _rope == null:
		return
	# The empty track is drawn whenever the hold is POSSIBLE and hidden when it is
	# not — `HoldGauge` calls that the pre-press tell, and it is only a tell if its
	# absence means something. It stays drawn under a rope that will empty you:
	# that hold works, and hiding the track would say the opposite.
	var ready := _rope_refusal().is_empty()
	_rope_bar.visible = ready
	if not ready:
		_rope_say.text = _rope_refusal()
		_rope_say.modulate = Pal.RUST
	else:
		var warn := _rope_warning()
		_rope_say.text = warn if not warn.is_empty() \
			else "Hold %s to climb out." % _hold_glyph()
		# RUST on a line that still ends in a hold you can do. It means "this
		# costs you everything", not "this will not work" — and the track under
		# it, still drawn, is what tells the two apart.
		_rope_say.modulate = Pal.RUST if not warn.is_empty() else Color.WHITE
	if not Run.in_dungeon:
		_rope_fee.text = "—"
		_rope_fee.modulate = Color(1, 1, 1, 0.5)
		return
	# The charge, for the same reason the detail pane shows it: this figure is a
	# promise about the purse and it has to be the one that comes true.
	_rope_fee.text = "%d ◇" % Run.extract_charge()
	_rope_fee.modulate = Pal.RUST if Run.extract_takes_all() else Color.WHITE


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
	_stock.columns = 4
	_stock.add_theme_constant_override("h_separation", 14)
	_stock.add_theme_constant_override("v_separation", 2)
	col.add_child(_stock)

	# The empty case cannot live in the grid: a GridContainer has no column
	# span, so one long sentence in cell 0 would set the width of column 1.
	_stock_empty = Label.new()
	_stock_empty.theme_type_variation = &"MenuSlotStat"
	_stock_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_empty.text = "Nothing yet. Components reach the bench by reaching the garrison."
	col.add_child(_stock_empty)


## The column BELOW the grid. The grid wires itself (left/right wraps within a
## row, down leaves the bottom row through `spill_down`); this wires what it
## leaves into, and closes the loop from Back back to the top left. Every cell
## and every button is reachable by holding one direction — the same guarantee
## the ITEMS screen makes, and for the same reason.
func _wire_focus() -> void:
	# The loop closes on the CASE's first cell, not the bag's, because the case is
	# now the top of the screen and Back's job is to return you to the top.
	var first := _case_grid.cell_at(0)
	if first == null:
		first = _grid.cell_at(0)
	if first == null:
		return
	MenuUtil.link_down(_fletch, _rope)
	MenuUtil.link_down(_rope, _back)
	_fletch.focus_neighbor_left = ^"."
	_fletch.focus_neighbor_right = ^"."
	_rope.focus_neighbor_left = ^"."
	_rope.focus_neighbor_right = ^"."
	_back.focus_neighbor_bottom = _back.get_path_to(first)
	_back.focus_next = _back.get_path_to(first)
	_back.focus_neighbor_left = ^"."
	_back.focus_neighbor_right = ^"."


# --- State ------------------------------------------------------------------

## Called every time the screen is entered. It re-disarms the hold as well as
## placing the cursor: the press that OPENED the pouch is not the press that
## leaves the dungeon, and `inventory` is Select while the hold is Y only until
## somebody rebinds one of them.
func focus_first() -> void:
	_rope_armed = false
	_reset_hold()
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


## The bag's cells, for a director that wants to count what is drawn rather than
## what the panel believes. Public because "the grid IS the capacity" is a claim
## worth being able to check from outside.
func grid() -> ItemGrid:
	return _grid


func refresh() -> void:
	_fill_cells()
	_paint_doll()
	_paint_header()
	_paint_fletch()
	_paint_rope()
	_paint_stock()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _fletch:
		_describe_fletch()
	elif focused == _rope:
		_describe_rope()
	else:
		# The cursor is on a cell, or on nothing at all because the screen has
		# only just been built. Either way the detail pane describes a cell, and
		# the grid is the one that knows which button is which index.
		_describe_focus(focused)


## Which cell the focus is on, and which side of the line, after a refresh that
## did not go through either grid's own signal. The grids hand out their own
## buttons, so asking them beats keeping a parallel array of them here — the
## parallel array was what `_cells` used to be, and it was one more thing that
## could disagree with what is drawn. A focus on neither grid describes the
## case's first cell, because that is where `focus_first` puts the cursor.
func _describe_focus(focused: Control) -> void:
	for i in _case_grid.count():
		if _case_grid.cell_at(i) == focused:
			_describe(i, true)
			return
	for i in _grid.count():
		if _grid.cell_at(i) == focused:
			_describe(i, false)
			return
	_describe(0, true)


## The grid says a cell was looked at; the detail pane says what it is.
func _on_cell_focused(index: int) -> void:
	_describe(maxi(index, 0), false)


func _on_case_focused(index: int) -> void:
	_describe(maxi(index, 0), true)


## A on a carried cell packs that stack into the case.
##
## A whole cell at a time, in both directions. Per-item packing would be the more
## flexible verb and it is the wrong one: the case is three slots and the choice
## §3.1 wants you making is *which things*, not how many of a thing — and a
## part-stack moved on its own costs a slot on each side of the line for nothing.
func _on_hold_activated(index: int) -> void:
	if index < 0 or index >= _cell_ids.size():
		return
	var id: StringName = _cell_ids[index]
	if id == &"":
		return
	if Run.stow(id, _cell_counts[index]) <= 0:
		var why := Run.case_refusal(id)
		notice.emit(why if why != "" else "That will not fit in the case.", true)
		return
	notice.emit("%s packed. It comes home." % ItemDb.get_def(id).display_name, false)
	refresh()


## A on a cased cell takes it back out. It stays in the bag — it just stops being
## the half that survives you, which is the trade every third slot is about.
func _on_case_activated(index: int) -> void:
	if index < 0 or index >= _case_ids.size():
		return
	var id: StringName = _case_ids[index]
	if id == &"":
		return
	if Run.unstow(id, _case_counts[index]) <= 0:
		notice.emit("There is no room in the bag for that outside the case.", true)
		return
	notice.emit("%s unpacked. It dies with you now."
		% ItemDb.get_def(id).display_name, false)
	refresh()


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
		row.theme_type_variation = &"MenuSlotStat"
		row.text = "%s  ×%d" % [def.display_name, have]
		_stock.add_child(row)
		any = true
	_stock.visible = any
	_stock_empty.visible = not any


func _describe(index: int, case_side: bool) -> void:
	var ids: Array[StringName] = _case_ids if case_side else _cell_ids
	var counts: Array[int] = _case_counts if case_side else _cell_counts
	if _detail_name == null or index < 0 or index >= ids.size():
		return
	var id: StringName = ids[index]
	# The case's three slots are the bag's first three, so the number the player
	# reads is continuous across the line even though the cells are two grids.
	var slot := index + 1 if case_side else index + 1 + Run.CASE_SLOTS

	if id == &"":
		_detail_kind.text = "CASE %d" % slot if case_side else "SLOT %d" % slot
		_detail_name.text = "Empty"
		_detail_value.text = ""
		if case_side:
			_detail_blurb.text = "Room in the case. Whatever is in here when you " \
				+ "die is what comes home with your body."
			_detail_legend.text = "Press A on anything below to pack it. " \
				+ "Relics will not fit."
		else:
			_detail_blurb.text = "Room for one more stack. Nothing is refused while " \
				+ "there is a cell like this one."
			_detail_legend.text = "Walk over a drop to fill it. There is no pick-up button."
		return

	var def := ItemDb.get_def(id)
	var n: int = counts[index]
	var part := def.is_component()
	_detail_kind.text = "%s %d  ·  %s  ·  %s" % [
		"CASE" if case_side else "SLOT", slot, def.rarity_name().to_upper(),
		def.bench_name() if part else "INGREDIENT"]
	_detail_name.text = def.display_name
	_detail_value.text = "%d ◇  ·  %d per slot" % [def.value * n, def.stack]
	_detail_blurb.text = def.blurb
	# WHICH bench, by name. Two counters eat components now and they are at
	# opposite ends of the yard; a caption that said "the forge" over a Fired
	# Cullet would send the player to the wrong one.
	var fate := ("%s eats this. It goes to the workbench when you reach "
		+ "garrison, not to the vendor.") % def.bench_name().capitalize() if part else \
		("The vendor buys this. What it is worth is a quarter of what leaving costs.")
	# The verb, on the end, and phrased as the consequence rather than the key —
	# what A does here is decide whether this survives you.
	_detail_legend.text = fate + ("   A takes it out of the case." if case_side
		else "   A packs it into the case.")
