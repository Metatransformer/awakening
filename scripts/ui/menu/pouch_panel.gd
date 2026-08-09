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
const HINT := "↑↓←→ Look   A Fletch   Hold Y Escape   Esc / B Back   Hands change on ITEMS"

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

## The paper doll's column. The frame grew from 1060 to `MenuUtil.FRAME_SIZE`'s
## 1220 to make room for exactly this, so the number is the width that was added
## less the separation beside it -- the grid's budget above is unchanged.
const DOLL_W := 144

## The header's row, so `PauseMenu` can drop the shared tab strip into it. See
## the same field on `MenuEquipPanel`.
var _hrow: HBoxContainer

var _doll: MenuPaperDoll
## Slot key (&"left" / &"right" / &"item") -> the Label naming what is in it.
var _worn: Dictionary[StringName, Label] = {}

var _cells: Array[Button] = []
## Parallel to `_cells`: the item id in each, or &"" for an empty slot.
var _cell_ids: Array[StringName] = []
var _grid: GridContainer
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
	# The doll redraws itself off these, but the three lines naming its slots are
	# this screen's, and ITEMS is one shoulder press away.
	Bus.loadout_changed.connect(
		func(_s: int, _r: StringName, _l: StringName) -> void: _paint_doll())
	Bus.item_selected_changed.connect(func(_i: int) -> void: _paint_doll())
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

	# Doll, then grid: the figure on the far left, what it is carrying beside it,
	# and what any of that is worth on the right. Left to right, the screen is a
	# sentence about you.
	var left := HBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	split.add_child(left)
	_build_doll(left)
	_build_grid(left)
	# THE BENCH IS ON THE LEFT, under the grid, and it is here for room rather
	# than for meaning -- though the meaning survives the move, since what made it
	# home sits directly under what has not yet.
	#
	# Measured, not guessed: with all four cards stacked on the right the column
	# wanted 627 px and the frame 801, inside a 720 px viewport. Forty pixels of
	# the header and forty of the bench rendered off the top and bottom edges of
	# the screen, and nothing complained -- the same failure the ITEMS screen hit
	# and the same one `_build_stock`'s own comment describes surviving once
	# already. The bench is the only card here that is not focusable and not part
	# of the extraction arithmetic, so it is the one that moves.
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

	_doll = MenuPaperDoll.new()
	_doll.name = "Doll"
	inner.add_child(_doll)

	# One line per slot, under the figure that draws it. The figure says WHICH
	# hand by where the box is; the line says what is in it, because two 40 px
	# bakes of a sword and a hookshot are not tellable apart by everyone.
	for key: StringName in [&"left", &"right", &"item"]:
		var row := Label.new()
		row.name = "Worn_%s" % key
		row.theme_type_variation = &"MenuSlotStat"
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Smaller than the theme's default for the same reason the bag cells are
		# (see CELL_NAME_PT): this column is 144 px wide and "RIGHT · Knightly
		# Sword" is the longest thing that has to fit in it.
		row.add_theme_font_size_override("font_size", CELL_NAME_PT)
		inner.add_child(row)
		_worn[key] = row


func _paint_doll() -> void:
	if _doll == null:
		return
	_doll.queue_redraw()
	(_worn[&"left"] as Label).text = "LEFT · %s" \
		% ArmamentDb.slot_name(Game.armament(Game.HAND_LEFT))
	(_worn[&"right"] as Label).text = "RIGHT · %s" \
		% ArmamentDb.slot_name(Game.armament(Game.HAND_RIGHT))
	var potion := Game.selected_potion()
	(_worn[&"item"] as Label).text = "ITEM · %s" % (
		PotionDb.name_of(potion) if potion != &"" else "Empty bottle")


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
## still true: you cannot drop, sort or use an item, because the vendor buys them
## and the forge eats them, both in town. What this adds is a verb belonging to
## the BAG, not to any item in it — the same shape the escape rope already has,
## sitting directly below it for the same reason. Both spend the bag; one spends
## it on getting out and one spends it on staying in.
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
	_detail_value.text = "%d arrows  ·  %d / %d in the quiver" \
		% [Fletching.BATCH, Game.arrows, Game.max_arrows]
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
	_fletch_have.text = "+%d" % mini(Fletching.BATCH, Fletching.quiver_room()) \
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
func _rope_refusal() -> String:
	if not Run.in_dungeon:
		return "You are already home."
	var fee := Run.extract_cost()
	if Game.gold < fee:
		return "The rope wants %d gold and you have %d." % [fee, Game.gold]
	return ""


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
	var fee := Run.extract_cost()
	_detail_value.text = "%d gold" % fee
	_detail_blurb.text = "It pulls you home and heals what the dark took. " \
		+ "The fee is a quarter of what you are carrying, and the fee is why " \
		+ "the greedy run is a decision."
	# Both halves of the way out, in the order the player meets them: the hold in
	# here, then the channel out there. They are separate on purpose — one cannot
	# be fumbled, the other can be interrupted (see `_build_rope`).
	_detail_legend.text = "Hold %s. Then it takes a moment, and a blow that lands breaks it." \
		% _hold_glyph() if Game.gold >= fee \
		else "You cannot afford to leave. Sell, or die trying."


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
	# The empty track is drawn whenever the hold is POSSIBLE and hidden when it is
	# not — `HoldGauge` calls that the pre-press tell, and it is only a tell if its
	# absence means something. A track under a rope you cannot afford would say
	# "hold me" about a button that is going to refuse.
	var ready := _rope_refusal().is_empty()
	_rope_bar.visible = ready
	_rope_say.text = "Hold %s to climb out." % _hold_glyph() if ready \
		else _rope_refusal()
	_rope_say.modulate = Color.WHITE if ready else Pal.RUST
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

	# Two columns, not one line per material. The bench held four things when
	# this was a single autowrapping Label; the alchemist's four brought it to
	# eight, and eight rows grew the right column until the frame was 872 px
	# tall inside a 720 px viewport -- the bottom half of the list rendered off
	# the screen and nothing complained. Pairing them keeps the tallest bench
	# the same height as the forge-only one was, so adding a ninth material
	# costs half a row instead of a whole one.
	_stock = GridContainer.new()
	_stock.name = "BenchGrid"
	_stock.columns = 2
	_stock.add_theme_constant_override("h_separation", 14)
	_stock.add_theme_constant_override("v_separation", 2)
	col.add_child(_stock)

	# The empty case cannot live in the grid: a GridContainer has no column
	# span, so one long sentence in cell 0 would set the width of column 1.
	_stock_empty = Label.new()
	_stock_empty.theme_type_variation = &"MenuSlotStat"
	_stock_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_empty.text = "Nothing yet. Components reach the bench by reaching town."
	col.add_child(_stock_empty)


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
			# Out of the bottom of the grid comes the bench, then the way out,
			# and only then Back. That order is the screen's argument in one
			# column: here is what you are carrying, here is what it can become,
			# here is what it costs to keep it, here is the door.
			MenuUtil.link_down(_cells[i], _fletch)
	MenuUtil.link_down(_fletch, _rope)
	MenuUtil.link_down(_rope, _back)
	_fletch.focus_neighbor_left = ^"."
	_fletch.focus_neighbor_right = ^"."
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

## Called every time the screen is entered. It re-disarms the hold as well as
## placing the cursor: the press that OPENED the pouch is not the press that
## leaves the dungeon, and `inventory` is Select while the hold is Y only until
## somebody rebinds one of them.
func focus_first() -> void:
	_rope_armed = false
	_reset_hold()
	if not _cells.is_empty():
		_cells[0].grab_focus()


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


func refresh() -> void:
	_rebuild_cells()
	_fill_cells()
	_paint_doll()
	_paint_header()
	_paint_fletch()
	_paint_rope()
	_paint_stock()
	var focused := get_viewport().gui_get_focus_owner()
	if _cells.has(focused):
		_describe(focused as Button)
	elif focused == _fletch:
		_describe_fletch()
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
	# The diamond is the bench mark. It is the same glyph the rope row uses for
	# "this does something", and here it means "a counter in town wants this,
	# the vendor does not" -- which is the only thing you need to know about a
	# cell while the bag is filling up. WHICH counter is in the detail pane; at
	# cell size it is one bit of information and the bit that matters is "do not
	# sell it".
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
		def.bench_name() if part else "INGREDIENT"]
	_detail_name.text = def.display_name
	_detail_value.text = "%d ◇  ·  %d per slot" % [def.value * n, def.stack]
	_detail_blurb.text = def.blurb
	# WHICH bench, by name. Two counters eat components now and they are at
	# opposite ends of the yard; a caption that said "the forge" over a Fired
	# Cullet would send the player to the wrong one.
	_detail_legend.text = ("%s eats this. It goes to the workbench when you reach "
		+ "town, not to the vendor.") % def.bench_name().capitalize() if part else \
		("The vendor buys this. What it is worth is a quarter of what leaving costs.")
