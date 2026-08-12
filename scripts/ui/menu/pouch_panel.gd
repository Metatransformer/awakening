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
##    `ROPE_HOLD` seconds, with the gauge. It moved here off the EQUIP screen, and the
##    HUD's gold total moved here too (hud.gd took it off the screen on purpose).
##    That is not three unrelated things sharing a frame: the bag's worth, the
##    purse and the fee ARE the extraction decision, and it is a decision made by
##    stopping and looking, not by glancing at a corner while running.
##
## It owns no state and changes none. Equipping is the EQUIP screen's job (the
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

## The action the way out is held on: Y on the pad, Y on the keyboard.
##
## Not `ui_accept`. A is the universal forward press in every menu in this game,
## including packing a stack on this screen. The run-ending control cannot be
## the same button as an ordinary menu action; a HOLD on a DIFFERENT button is
## what keeps the fumble from ending a run.
const HOLD_ACTION := &"ui_hold"

## Seconds on Y. Longer than the shop's 0.5 s craft hold and the same length as
## the gate's descent, because those spend materials and this ends the run. [tune]
##
## It is a real hold and not ceremony: the thing it guards against is the press
## you make while reading something else on this screen.
const ROPE_HOLD := 0.9

## Cells per row, and the same five every other collection screen in the game
## draws (`ItemGrid.columns`). It was four on both sides until card #120; the
## number now lives in `ItemGrid` for everyone, and this const survives only
## because this panel is the one that has to fight for the width.
##
## The bag holds `Game.bag_slots` (12 at the start, 16 bought out) less the
## case's 3, so the grid is 9 cells at the low end and 13 at the high end: two
## rows then three, where four across was three rows then four. One row shorter
## is the point — the whole bag is one glance instead of a scan.
##
## **Five did not fit, and the fifth column was not paid for by shrinking
## anything.** Measured with the doll still beside the grid: `Grid` 732 px
## (5 × 140 + 4 × 8), `Bag` 748, plus `Worn` 152 and 16 between made `Left` 916,
## and the frame came out **1320 px inside a 1280 px viewport** — past the
## screen, and 100 px past the 1220 `MenuUtil.FRAME_SIZE` the other four screens
## draw at. A CenterContainer does not save you from a child whose minimum size
## is bigger than the screen; it clips it, silently, which is how six across got
## as far as being drawn the first time. The hundred came out of `DOLL_W` and
## `DETAIL_W`, and `_build` records the re-layout that was tried first and
## measured worse.
##
## The cell's 140 px is not a lever. It is what a two-word item name needs
## without wrapping, and `ItemGrid` owns it for every screen at once.
const COLS := 5
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
## case takes three of those slots off the top (`Run.hold_slots`). Kept at the
## bag's ceiling rather than lowered to the 13 the grid can actually be handed,
## because it is a guard against a corrupt number and not a layout constant.
const MAX_CELLS := 16

## The paper doll's column, and `MenuPaperDoll.MIN_SIZE.x` exactly. The frame grew
## from 1060 to `MenuUtil.FRAME_SIZE`'s 1220 to make room for this column, and it
## was 152 -- twenty px of comfort over the doll's own floor -- until card #120
## needed a fifth cell in the bag. Twenty of the hundred came from here.
##
## It is AT the floor now, so the next thing this screen has to find room for
## cannot come out of the doll: below 132 the compact card's two hand tiles start
## eliding the item name, which is the only thing on them worth reading.
const DOLL_W := 132

## The detail column: what the focused cell is, what it is worth, and the way out
## under it. 340 until card #120, when the other eighty px of the fifth cell came
## from here.
##
## Eighty was affordable because this column is TEXT and the text wraps: every
## label in `_build_detail` and `_build_rope` is `AUTOWRAP_WORD_SMART`, and the
## column had ~250 px of unused HEIGHT under the blurb to wrap into (`Right` is
## the tallest thing on the screen only because it is `EXPAND_FILL`, not because
## it is full). A blurb one line longer and a breadcrumb that wraps is what the
## fifth bag cell cost, and the fifth bag cell is the picture the screen is FOR.
const DETAIL_W := 260

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
## The `StatBand` and the slot it is rebuilt into. It replaced `_header`, which
## was one right-aligned string carrying three numbers.
var _band: Control
var _band_slot: VBoxContainer
var _stock: GridContainer
var _stock_empty: Label
var _back: Button
var _detail_kind: Label
var _detail_name: Label
var _detail_value: Label
var _detail_blurb: Label
var _detail_legend: Label
var _rope: Button
var _rope_bar: HoldBar
var _rope_say: Label
## Seconds of Y accumulated. Snapped to 0 on release, never decayed.
var _rope_hold: float = 0.0
## The hold starts DISARMED and arms on the first frame Y is up. Without it, a
## player who opens the pouch with Y already down (it is `jump` in the world)
## arrives on this screen part-way through leaving the dungeon.
var _rope_armed: bool = false


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

	# The four numbers the extraction decision is made out of, in a `StatBand`
	# under the tab strip. They were one right-aligned string in the header row —
	# "4 / 12 SLOTS   BAG 334 ◇   PURSE 30 ◇" — which is three answers the eye has
	# to parse a sentence to separate, and it had no room for the fee at all. The
	# fee lived only on the rope row, two feet away from the purse it is measured
	# against, and this screen's whole argument (see the class doc) is that those
	# numbers ARE one decision.
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
	left.add_child(carried)
	_build_doll(carried)
	_build_grid(carried)

	_build_stock(left)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = DETAIL_W
	# 8 and not the 12 the other columns use. This is the tallest column on the
	# is the tallest thing on the screen -- it, not the frame's 604, is what sets
	# the pouch's height, and at 12 the footer's Back button ran off the bottom
	# of a 720p viewport. Four px a gap is the whole difference.
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	_build_detail(right)
	_build_rope(right)

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
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


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
	# has to be the top of the picture, because the sentence this card makes when
	# you read it downwards is the design: this comes home, this does not.
	# A styled Label rather than a `section_rule`, because the rule is gold and
	# this caption is CYAN: the way out is CYAN and nothing else is (STYLEGUIDE
	# §1), and the case is the OTHER way out — the one that works when you did not
	# make it to the rope. That colour is load-bearing and a divider would eat it.
	var case_cap := Label.new()
	case_cap.text = "THE DOCUMENT CASE  ·  COMES HOME"
	UITheme.apply_text_style(case_cap, UITheme.TYPE_H3, Pal.CYAN)
	inner.add_child(case_cap)

	_case_grid = ItemGrid.new()
	_case_grid.name = "Case"
	_case_grid.columns = Run.CASE_SLOTS
	_case_grid.cell_focused.connect(_on_case_focused)
	_case_grid.cell_activated.connect(_on_case_activated)
	inner.add_child(_case_grid)

	UITheme.section_rule(inner, "CARRIED  ·  DIES WITH YOU")

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
	_grid.spill_down = _rope
	_grid.set_cells(_cells_of(_cell_ids, _cell_counts), want)
	_case_grid.spill_down = _grid.cell_at(0)
	# Out of the bottom of the grid comes the way out, then Back: the bag spills
	# directly into the only verb this screen owns.
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
			"star": Wishlist.is_wishlisted(ids[i]),
		})
	return entries


func _build_detail(parent: Node) -> void:
	# The kicker / title / value stack of a `PlateHeader`, by hand: this pane is
	# rewritten on every cursor move, and a `PlateHeader` is a panel's IDENTITY,
	# built once. Same call as `MenuEquipPanel._build_detail`.
	var col := VBoxContainer.new()
	col.name = "Detail"
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	_detail_kind = Label.new()
	UITheme.apply_text_style(_detail_kind, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	col.add_child(_detail_kind)

	_detail_name = Label.new()
	UITheme.apply_text_style(_detail_name, UITheme.TYPE_H1, UITheme.TEXT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_name)

	_detail_value = Label.new()
	UITheme.apply_text_style(_detail_value, UITheme.TYPE_LABEL_MD, UITheme.ACCENT)
	col.add_child(_detail_value)

	_detail_blurb = Label.new()
	UITheme.apply_text_style(_detail_blurb, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_blurb)

	_detail_legend = Label.new()
	UITheme.apply_text_style(_detail_legend, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_detail_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_legend)


## The way out. The only control on this screen that ENDS something — everything
## above it is a picture of what you are carrying, and this spends it.
##
## It sits directly under the grid it is priced from, which is why it moved here
## from the EQUIP screen: the fee is a quarter of the bag, and the bag is what
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
## only job is to be deliberate is exactly the right shape for a run-ending press.
func _build_rope(parent: Node) -> void:
	var inner := VBoxContainer.new()
	inner.name = "Use"
	inner.add_theme_constant_override("separation", 6)
	parent.add_child(inner)

	UITheme.section_rule(inner, "THE WAY OUT")

	# `primary`: the display face, on the one row this screen exists to lead you
	# to. Exactly one per panel, and on the pouch it is not in doubt — everything
	# above this row is a picture of what you are carrying, and this is the row
	# that spends it.
	#
	# Live even when it will refuse, for the reason the class doc argues: the fee
	# and the refusal are things you READ, and a `refused` row cannot be focused
	# to be read. The meta column carries the toll — see `_paint_rope`.
	_rope = UiKit.verb_row(inner, {
		"label": "Escape Rope",
		"icon": UiKit.action_icon("rope"),
		"meta": "",
		"primary": true,
	})
	_rope.name = "Rope"

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
	UITheme.apply_text_style(_rope_say, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
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
		UiKit.verb_meta(_rope, "—")
		return
	# The charge, for the same reason the detail pane shows it: this figure is a
	# promise about the purse and it has to be the one that comes true.
	#
	# WARNING, not DANGER, when it takes everything: the hold still works. DANGER
	# on this screen means "this will not happen", and the difference between
	# "this empties you" and "this is refused" is the whole reason the empty track
	# stays drawn under the row above.
	UiKit.verb_meta(_rope, "%d ◇" % Run.extract_charge(),
		UITheme.WARNING if Run.extract_takes_all() else UITheme.ACCENT)


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
	_stock.columns = 4
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


## The column BELOW the grid. The grid wires itself (left/right wraps within a
## row, down leaves the bottom row through `spill_down`); this wires what it
## leaves into, and closes the loop from Back back to the top left. Every cell
## and every button is reachable by holding one direction — the same guarantee
## the EQUIP screen makes, and for the same reason.
func _wire_focus() -> void:
	# The loop closes on the CASE's first cell, not the bag's, because the case is
	# now the top of the screen and Back's job is to return you to the top.
	var first := _case_grid.cell_at(0)
	if first == null:
		first = _grid.cell_at(0)
	if first == null:
		return
	MenuUtil.link_down(_rope, _back)
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


## The top row of focusables, landing target first — `PauseMenu` joins these to
## the tab strip so ↑ leaves the page through them and ↓ off a tab comes back
## down onto the first (card #120, `MenuPageTabs`).
##
## The CASE's three cells and not the bag's. The case is the top of the picture
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
	_paint_doll()
	_paint_header()
	_paint_rope()
	_paint_stock()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _rope:
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
## Slots, worth, purse, fee — the extraction decision, in the order you make it:
## how full am I, what is it worth, what have I got, what will leaving cost.
##
## Slots goes WARNING at the brim and it means one thing: the next mote you walk
## over is going to stay on the floor. The fee goes WARNING when it takes the
## whole purse, which is a different statement from "you cannot leave" and has to
## look like one — DANGER on this band would say the door was shut.
func _band_cells() -> Array:
	var used := Run.slots_used()
	var fee := "—"
	var fee_tone: Variant = null
	if Run.in_dungeon:
		fee = "%d ◇" % Run.extract_charge()
		fee_tone = UITheme.WARNING if Run.extract_takes_all() else null
	return [
		{"key": &"slots", "label": "Slots",
			"value": "%d / %d" % [used, Game.bag_slots],
			"icon": UiKit.action_icon("bag"),
			"tone": UITheme.WARNING if used >= Game.bag_slots else null},
		{"key": &"worth", "label": "Bag", "value": "%d ◇" % Run.bag_value()},
		{"key": &"purse", "label": "Purse", "value": "%d ◇" % Game.gold,
			"icon": UiKit.action_icon("coin")},
		{"key": &"fee", "label": "To leave", "value": fee, "tone": fee_tone},
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
	_detail_blurb.text = "%s  %s" % [def.blurb, Wishlist.usage_sentence(id)]
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
