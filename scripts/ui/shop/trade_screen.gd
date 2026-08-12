class_name TradeScreen
extends Control
## The vendor, the smith, the alchemist, the jewelcrafter and the Lanternkeeper,
## which are the same screen pointed in five directions.
##
## SELL reads the bag. BUY reads a CATALOGUE, handed in at `open()` -- `ShopDb`
## for the smith, `AlchemyDb` for the alchemist, `JewelDb` for the jewelcrafter --
## and they are interchangeable because they expose the same catalogue contract.
## Nothing below this line
## asks which counter it is standing at, and that is the whole reason there is one
## screen: the recipe column, the per-token affordability colouring and the
## refusal footer are subtle, they took three passes to get right, and a second
## shop screen would have been a second place for all of it to drift.
##
## **It draws cells, not a list, and the cell is the bag's** (`ItemCell`).
## Until 2026-08-09 this screen was a column of canvas-drawn rows: the same objects
## the pouch drew as tinted cells arrived at the vendor as lines of text, so a
## player looking at their bag and then at what it was worth was reading two
## different UIs about one set of things. The cell is the pouch's, which means an
## ingredient has the same colour chip and the same ◆ in both places. That is the
## only icon set this game has.
##
## The two sides arrange that cell differently, because they are two different
## shapes of thing:
##
##  * **SELL** is an `ItemGrid` -- four across, one cell per stack. A stack you
##    own has no rungs; it is just a thing with a price on it.
##  * **BUY** is an `UpgradeLadder` -- a row per thing the counter sells, with
##    that thing's rungs along it and arrows between them. Every counter here
##    sells ladders and the flat board could not say so: it showed the rung you
##    could buy next and nothing else, so the smith's eight armour lines read as
##    eight unrelated purchases instead of four pieces with two answers each.
##
## Not two screens and not a branch anywhere below `_build_body` and `_move`:
## the cursor, the prices, the recipe column, the affordability colouring, the
## refusal footer and the hold all run over `_rows` and neither arrangement can
## see them.
##
## The frame, the header and the footer are the game's ONE menu look -- since the
## Gallery Vellum port that is `UITheme` and `UiKit`, and a shop that did not use
## it was a shop that looked like a different program. What the kit brings that
## the old chrome did not: a `PlateHeader` naming the counter and the act, and a
## `StatBand` under it carrying the four numbers you decide with, so the answer to
## "can I afford anything on this board" is on screen before you walk it.
##
## The BOARD is untouched by that. `ItemCell` and `UpgradeLadder` still draw it,
## still through the `MenuSlot` / `MenuValue` variation names -- those are painted
## in kit tokens now (`UITheme._style_shared_cells`) so the bag cell looks the same
## in the pouch and at the counter, which is the promise `ItemCell`'s header makes.
##
## One board, one cursor, one number that moves. The player is answering "what is
## this worth" over and over, so the price is the only thing that is ever GOLD and
## the purse is the only thing that animates.

enum Mode { SELL, BUY }

const ROLL_TIME := 0.25
## Cells across. Four is the pouch's, and the pouch's was measured against this
## same frame width -- see the note on `MenuPouchPanel.COLS`.
const COLS := 4
## The detail column, in the same pixels the pouch's is.
const DETAIL_W := 340

var mode: Mode = Mode.SELL
var title: String = "VENDOR"
## The catalogue behind a BUY screen: the ShopDb, AlchemyDb, JewelDb or RelicDb
## script itself, so its statics can be called through it. **Through the handle,
## never bare** -- a static call written inside `Catalogue` binds to `Catalogue`
## at parse time and the subclass's override never runs (CLAUDE.md §3). Unused by
## SELL, which reads `Run.bag`.
var catalogue: GDScript = null

## One entry per cell, in grid order. Kinds: &"item" and &"all" on the SELL side,
## &"buy" on the other. Rebuilt whole after every transaction rather than mutated:
## a sold-out stack has to leave the board, and a cursor pointing at a row that no
## longer exists is the classic shop-screen crash.
var _rows: Array[Dictionary] = []
var _cursor: int = 0
var _shown_gold: float = 0.0
var _refuse: float = -1.0
var _closing: bool = false

var _grid: ItemGrid
var _ladder: UpgradeLadder
var _scroll: ScrollContainer
## The buyable lines in BOARD order. On the SELL side that is just 0..n-1; on a
## BUY counter the ladder's rows are not in `lines()` order (the smith's groups
## put the shield between the blade and the armour), and the cursor has to walk
## what the player can see.
var _order: Array[int] = []
## The `StatBand` and the slot it is rebuilt into. The purse inside it rolls, so
## it is written per frame through `UiKit.band_value` rather than rebuilt — see
## `StatBand.set_value`.
var _header: Control
var _band: Control
var _band_slot: VBoxContainer
var _empty: Label
var _d_kind: Label
var _d_name: Label
var _d_price: Label
var _d_blurb: Label
var _recipe: VBoxContainer
var _hint: Label
var _hold_bar: HoldBar
## The refusal message, when there is one. A `FooterToast`, built on the failed
## press and freed when it times out, rather than a permanent Label that spends
## most of its life empty and reserving a line.
var _toast: Control
var _toast_slot: VBoxContainer
## The catalogue line the toast is about, so `_refresh` can re-ask whether it is
## still true. Empty on the SELL side, which has nothing to re-ask.
var _refuse_line: Dictionary = {}


## Whose voice this counter speaks in -- a key in `Voice.LINES`, or `&""` for a
## keeper nobody has recorded.
##
## The screen owns two of the three cues and the `Npc` owns the first, and the
## split is not arbitrary: `hello` happens when you address a person, which is
## something the person knows about, and `deal` and `farewell` happen on a press
## that landed and on the screen coming down, which are things only this file
## knows about. Passing the id down beats a signal back up -- the alternative was
## `Bus.trade_committed`, a signal whose only listener would be the node that
## opened the screen it came from.
var speaker: StringName = &""

## The screen makes its own CanvasLayer. A Control parented to a Node3D never
## draws, and every caller here is a prop standing in a 3D garrison.
## `db` is the catalogue for a BUY screen and defaults to the smith's, which is
## what every existing caller meant.
static func open(host: Node, screen_mode: Mode, screen_title: String,
		db: GDScript = null, voice: StringName = &"") -> TradeScreen:
	var layer := CanvasLayer.new()
	layer.name = "TradeLayer"
	# Above the HUD (50), below the pause menu (100). The pause menu no longer
	# opens over this screen at all -- Escape and Start both CLOSE it, and one
	# press gets one response (see PauseMenu._unhandled_input) -- but the order is
	# still the right one for anything that raises the menu while a shop is up.
	layer.layer = 60
	var s := TradeScreen.new()
	s.mode = screen_mode
	s.title = screen_title
	s.catalogue = db if db != null else ShopDb
	s.speaker = voice
	layer.add_child(s)
	host.get_tree().current_scene.add_child(layer)
	return s


## THE POINTER IS FREED HERE AND PUT BACK NOWHERE — `GameCamera._settle_pointer`
## owns the way back. This screen used to save what it found and restore it, and
## that is precisely how mouse look died: it opens off a `DialogueBox`'s Trade
## option, so what it found was the box's own release, and it put "visible" back
## every time the player walked away from a counter.


func _ready() -> void:
	# A Control parented straight to a CanvasLayer is outside the viewport's
	# Control tree, so anchors alone never resolve and it sits at size (0,0).
	# Size it from the viewport and keep it there.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.prewarm()
	theme = UITheme.theme()
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)

	_shown_gold = float(Game.gold)
	_refresh()
	Bus.wishlist_changed.connect(_refresh)
	Settings.changed.connect(func(section: StringName, key: StringName,
			_value: Variant) -> void:
		if section == &"game" and key == &"auto_wishlist":
			_refresh())
	# The camera captures the pointer for look. Hand it back or not one cell on
	# this screen can be clicked.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Prompt.block(self)
	Bus.screen_opened.emit(&"trade")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"trade")


func close() -> void:
	if _closing:
		return
	_closing = true
	# Said over the screen coming down rather than after it, so the goodbye
	# overlaps the walk away instead of following it. In `close` and not
	# `_exit_tree` because this has to be the player LEAVING: `_exit_tree` also
	# runs when the garrison is torn down for the descent, and the smith calling
	# "take care" at a black screen would be the counter talking to nobody.
	Voice.say(speaker, &"farewell")
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# --- Building ----------------------------------------------------------------

## Darken the world rather than hide it. You are standing in the garrison while
## you do this, and the shop is a conversation, not a menu screen.
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Pal.VOID, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	# `edge_to_edge`, because the header plate, the band and the footer all reach
	# the frame edge; the BODY between them owns its own inset.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	centre.add_child(frame)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	frame.add_child(stack)

	_build_header(stack)
	_build_body(stack)
	_build_footer(stack)


## Who this is and what they do, then the four numbers you decide with.
##
## The old header was the counter's name and the purse on one line. It told you
## nothing you could act on: whether anything on the board was affordable was a
## question you answered by walking it, and at the smith that is eleven presses.
func _build_header(parent: Node) -> void:
	# Empty kicker, filled by the first `_refresh`. It cannot be filled here: what
	# this counter DOES is read off its own board, and the board has not been built
	# yet. The Setting Bench shipped a header reading BUY over a footer reading
	# SET for exactly that reason -- at `_ready()` her four rows are all unbought
	# blanks, none of which carries a recipe.
	_header = UiKit.plate_header(parent, {
		"kicker": "",
		"title": _counter_name(),
		"emblem": UiKit.action_icon(_emblem()),
	})
	# The band is rebuilt by `_refresh`, because what is affordable changes with
	# every purchase. The slot is what survives that.
	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override("separation", 0)
	_band_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_band_slot)


## The counter's name as a name, not as shouting. `Npc.COUNTERS` writes these in
## caps -- "THE FORGE" -- which was right when the title was a 38 px slab and is
## wrong in a display serif. Godot's own `String.capitalize()` cannot do this: it
## inserts a space before every interior capital, so "THE FORGE" comes back as
## "T H E   F O R G E".
func _counter_name() -> String:
	var words: Array[String] = []
	for word in title.strip_edges().to_lower().split(" ", false):
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(words)


## The act, in the counter's own word, for the kicker: SELL here, FORGE at the
## smith, BREW at the alchemist, SET at the bench, RECORD at the lantern.
##
## Asked of the CATALOGUE and of the board as it stands -- never of which db this
## is. A counter with nothing on it that eats materials says BUY, and it says so
## because none of its rows carry a recipe, not because this screen recognised it.
## Read off `_rows` rather than `lines()` so it answers for the board the player is
## actually looking at, which is why `_refresh` is what writes it.
func _act() -> String:
	if mode == Mode.SELL:
		return "Sell"
	for row in _rows:
		if _db().crafts(row["line"]):
			return _db().craft_verb()
	return "Buy"


## The header glyph. `Catalogue.emblem()` for a counter, and the trade glyph for
## the quartermaster, who has no catalogue at all.
func _emblem() -> String:
	return "trade" if mode == Mode.SELL else String(_db().emblem())


## The four numbers, per side.
##
## SELL is about the bag: what it is worth, how full it is, and how much of that
## worth is heat the vendor will not pay twice. BUY is about the board: how many
## lines there are and how many of them you can actually pay for -- the one thing
## the old header made you walk eleven cells to learn.
func _band_cells() -> Array:
	var purse := {"key": &"purse", "label": "Purse",
		"value": "%d ◇" % int(round(_shown_gold)), "icon": UiKit.action_icon("coin")}
	if mode == Mode.SELL:
		var used := Run.slots_used()
		return [
			purse,
			{"label": "Bag", "value": "%d ◇" % Run.bag_value(),
				"icon": UiKit.action_icon("bag")},
			{"label": "Slots", "value": "%d / %d" % [used, Game.bag_slots],
				"tone": UITheme.WARNING if used >= Game.bag_slots else null},
			{"label": "Heat", "value": "+%d ◇" % Run.premium,
				"tone": UITheme.WARNING if Run.premium > 0 else null},
		]
	var afford := 0
	for row in _rows:
		if bool(row["ok"]):
			afford += 1
	return [
		purse,
		{"label": "Lines", "value": str(_rows.size())},
		{"label": "Affordable", "value": str(afford),
			"tone": UITheme.SUCCESS if afford > 0 else UITheme.DANGER},
		# Follows the cursor, so the number you are deciding about is in the band
		# as well as in the detail pane -- the band is where the eye already is,
		# because the purse it must be weighed against is one cell to the left.
		{"key": &"cost", "label": "This line", "value": "—"},
	]


func _rebuild_band() -> void:
	if _band_slot == null:
		return
	UITheme.clear_children(_band_slot)
	_band = UiKit.stat_band(_band_slot, _band_cells())


func _build_body(parent: Node) -> void:
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	parent.add_child(pad)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	pad.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)

	# A WELL, not a panel. The board is a recess in the frame -- darker glass
	# behind a fainter hairline -- which is what makes a grid of cells read as
	# things sitting IN something rather than a second window floating on the first.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.well())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	UITheme.section_rule(inner,
		"IN THE BAG" if mode == Mode.SELL else "ON THE BOARD")

	# SELL is a grid of what is in the bag; BUY is a ladder per thing on offer.
	# Two arrangements of the SAME cell (`ItemCell`) rather than two screens,
	# because the two sides differ in exactly one way: a stack you own has no
	# rungs and a thing the counter makes longer has nothing else.
	if mode == Mode.SELL:
		_grid = ItemGrid.new()
		_grid.name = "Board"
		_grid.columns = COLS
		# The cursor is this screen's, not the grid's -- see `_tick_input`. It
		# still reports a look, because the mouse can land on a cell the stick
		# never crossed and the detail pane has to follow it.
		_grid.cell_focused.connect(_on_cell_looked)
		inner.add_child(_grid)
	else:
		# The smith's board is eight rows on a fresh save and eleven once the bow
		# and the hookshot are found, which is taller than the frame. It scrolls
		# rather than shrinking the cells: a rung you cannot read is worse than a
		# rung you have to scroll to, and `_point_at` keeps the cursor in view so
		# a pad player never touches the scrollbar.
		_scroll = ScrollContainer.new()
		_scroll.name = "BoardScroll"
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.add_child(_scroll)
		UITheme.style_scrollbar(_scroll)
		# The board is not the only thing that decides how tall the board is: a
		# refusal builds a toast into the footer, the footer grows, and this
		# viewport loses a line off its bottom. The scroll offset does not move
		# with it, so the cell the cursor is ON gets clipped in half at exactly
		# the moment the counter is explaining why it said no. Re-ask on every
		# resize rather than at the toast's call site -- the toast is one of
		# several things down there that can change height.
		_scroll.resized.connect(_keep_cursor_in_view)

		_ladder = UpgradeLadder.new()
		_ladder.name = "Board"
		_ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ladder.cell_focused.connect(_on_cell_looked)
		_scroll.add_child(_ladder)

	_empty = Label.new()
	_empty.text = "Nothing to sell." if mode == Mode.SELL else "Sold out."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(_empty, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	inner.add_child(_empty)

	_build_detail(split)


## The one place a blurb, a price or a recipe is ever spelled out. A grid cell has
## room for a name and one number; everything else the player needs to decide with
## lives here, beside it, and never on the cell.
func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	UITheme.style_panel(card, UITheme.BG_INSET)
	card.custom_minimum_size = Vector2(DETAIL_W, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	# The kicker/title/number stack of a `PlateHeader`, written out by hand rather
	# than composed: this one is REWRITTEN on every cursor move, and a component
	# that rebuilds its own nodes would throw away the layout sixty times a second
	# while a stick is held.
	_d_kind = Label.new()
	UITheme.apply_text_style(_d_kind, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	col.add_child(_d_kind)

	_d_name = Label.new()
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(_d_name, UITheme.TYPE_H1, UITheme.TEXT)
	col.add_child(_d_name)

	_d_price = Label.new()
	UITheme.apply_text_style(_d_price, UITheme.TYPE_LABEL_XL, UITheme.ACCENT)
	col.add_child(_d_price)

	# The bill, one component per row: what it wants and what the bench has.
	# **Per row, never per line.** A recipe you are one core short of and a recipe
	# you have none of look identical if the whole thing just greys out, and the
	# difference between them is a whole run's worth of where to go looking.
	_recipe = VBoxContainer.new()
	_recipe.add_theme_constant_override("separation", 2)
	col.add_child(_recipe)

	_d_blurb = Label.new()
	_d_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(_d_blurb, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	col.add_child(_d_blurb)


## The line that says which button does what, and -- on a cell that wants one --
## that this one is a HOLD.
##
## The word and the gauge are one statement made twice, in language and in shape,
## exactly as the interact prompt makes it. Either alone has shipped as a bug
## here: "A TO DESCEND" with no bar was a player tapping and filing "descend
## doesn't work", and a bar with no word is a player watching something fill
## without knowing they are the one filling it.
##
## The refusal is a `FooterToast` and NOT the hint line recoloured, which is what
## it used to be. Those are two different statements — one is "here is what the
## buttons do", the other is "here is why that press did nothing" — and spending
## one line on both meant the control hint disappeared at the exact moment a
## confused player was looking for it.
func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	parent.add_child(footer)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	footer.add_child(row)

	# Above the hint, because the toast reports on the board and the hint reports
	# on the pad — and because a toast that appeared BELOW the hint would push the
	# hint up under the player's eye every time a press was refused.
	_toast_slot = VBoxContainer.new()
	_toast_slot.add_theme_constant_override("separation", 0)
	_toast_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_toast_slot)

	_hint = Label.new()
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	row.add_child(_hint)

	_hold_bar = HoldBar.new()
	_hold_bar.col = Pal.GOLD
	row.add_child(_hold_bar)


# --- Rows --------------------------------------------------------------------

## The catalogue this screen is buying from, never null. A screen built by hand
## (a director, a test) that forgot to set one still gets the smith rather than a
## crash in the middle of a build.
func _db() -> GDScript:
	return catalogue if catalogue != null else ShopDb


## The rows of the board, never empty while the counter has lines.
##
## `Catalogue.groups()` documents its default as "one row holding every line" and
## then returns `[]`, because it cannot do otherwise: a bare `lines()` written
## inside `Catalogue` binds to `Catalogue.lines()` at parse time and hands back
## the base class's empty list (CLAUDE.md §3, the same trap that shipped a smith
## saying HOLD ENT TO CRAFT). There is no virtual dispatch to climb back down to
## the subclass.
##
## So the default is built HERE, where the handle exists and the call does
## dispatch. That matters beyond tidiness: `Catalogue` promises a new counter
## costs a `lines()` and nothing else, and the Lanternkeeper took that promise at
## its word -- twelve relics, no `groups()`, and a board with nothing drawn on it
## for as long as she has existed. A sixth catalogue gets the grid it was told it
## would get.
func _board() -> Array:
	var db := _db()
	var groups: Array = db.groups()
	if not groups.is_empty():
		return groups
	return [Catalogue.flat_group("", db.lines())]


func _refresh() -> void:
	_rows.clear()
	if mode == Mode.SELL:
		_build_sell_rows()
	else:
		_build_buy_rows()

	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))

	var cells: Array = []
	for i in _rows.size():
		var row := _rows[i]
		cells.append({
			"index": i,
			"label": String(row["label"]),
			"sub": String(row["sub"]),
			"tint": row["color"],
			"sub_tint": row.get("sub_tint", Color.WHITE),
			"mark": bool(row.get("mark", false)),
			"star": bool(row.get("star", false)),
			"dim": not bool(row["ok"]),
		})
	if mode == Mode.SELL:
		_grid.set_cells(cells)
		_grid.visible = not _rows.is_empty()
		_order.clear()
		for i in _rows.size():
			_order.append(i)
	else:
		_ladder.set_board(_board(), cells)
		# The BOARD decides, not `_rows`. A catalogue can hand back twelve lines
		# and a board that draws none of them, and the pane that results is blank
		# with no words on it -- which is what the Lanternkeeper shipped: twelve
		# rows, an empty left pane, and "Sold out." suppressed because `_rows` was
		# not empty. A counter with nothing ON it says so.
		_scroll.visible = _ladder.count() > 0
		_order = _ladder.order().duplicate()
	_empty.visible = _rows.is_empty() if mode == Mode.SELL else not _scroll.visible

	# A refresh can retire the line the cursor was on -- a finished ladder loses
	# its buyable rung, a committed piece loses its whole losing branch. Landing
	# on the row that is still there beats snapping back to the top of the board.
	if not _order.is_empty() and not _order.has(_cursor):
		_cursor = _order[mini(_at(), _order.size() - 1)]
	# After the board, because both of these are read off it: the BUY band counts
	# what is affordable, and the kicker asks whether anything here is crafted.
	_drop_stale_refusal()
	UiKit.plate_kicker(_header, _act())
	_rebuild_band()
	_point_at(_cursor)


## Where the cursor is in BOARD order, or 0 when it is nowhere.
func _at() -> int:
	var i := _order.find(_cursor)
	return maxi(i, 0)


func _build_sell_rows() -> void:
	var wished := Wishlist.wishlisted_ids()
	var unmarked: Array[StringName] = []
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var keep := def.is_component() or RelicDb.is_relic(id) or wished.has(id)
		if not keep and Run.line_value(id) > 0:
			unmarked.append(id)
		_rows.append({
			"kind": &"item",
			"id": id,
			"label": def.display_name,
			"count": int(Run.bag[id]),
			# Not def.value * n: a stack carries its share of the run's heat
			# premium, and the cell has to name the gold that will actually land
			# or the screen is lying about its own prices.
			"price": Run.line_value(id),
			"sub": "%d ◇" % Run.line_value(id),
			"color": Pal.rarity_color(int(def.rarity)),
			"mark": def.is_component(),
			"star": wished.has(id),
			"blurb": def.blurb,
			"ok": true,
		})
	_rows.sort_custom(func(a, b) -> bool: return a["price"] > b["price"])
	var bulk_price := Run.sale_value(unmarked)
	if bulk_price > 0:
		_rows.append({
			"kind": &"all",
			"label": "SELL UNMARKED",
			"count": 0,
			"price": bulk_price,
			"sub": "%d ◇" % bulk_price,
			"color": Pal.BONE,
			"blurb": "Sell every unmarked stack. Components, relics and wished-for loot stay put.",
			"ids": unmarked,
			"ok": true,
		})


func _build_buy_rows() -> void:
	for line in _db().lines():
		var left: int = _db().remaining(line["id"])
		var cost := int(line["cost"])
		var pinned := Wishlist.is_line_pinned(_db(), line)
		var sub := ("%d ◇" % cost) if cost > 0 else String(line.get("tally", ""))
		if pinned:
			sub = "★ " + sub
		_rows.append({
			"kind": &"buy",
			"line": line,
			"label": String(line["label"]),
			"count": left,
			"price": cost,
			# The price, when there is one. A counter that charges nothing has no
			# price column: the Lanternkeeper's board printed "0 ◇" twelve times,
			# a number repeated down the whole screen to say a thing the header
			# already says. What goes there instead is the LINE's business and
			# nobody else's -- `tally` is hers, holding the ladder's tick on a
			# relic that is in. Read off the line rather than derived from
			# `remaining() == 0`, which is also true of a maxed jewel slot whose
			# Recut row is free and is the opposite of done.
			"sub": sub,
			"sub_tint": Color.WHITE if cost > 0 else Pal.MOSS,
			"color": Pal.BONE,
			# The blurb says what the thing IS; the detail says what the number
			# DOES, in the unit the player feels. A forge line without the second
			# sentence is asking them to buy on faith.
			"blurb": "%s   %s" % [line["blurb"], line.get("detail", "")],
			"parts": line.get("parts", {}),
			"ok": _db().can_buy(line),
		})


# --- The cursor --------------------------------------------------------------

## Move the cursor and make the screen agree with it: the cell takes focus (which
## is what draws the highlight, out of the theme, exactly as it does in the pause
## menu) and the detail pane describes it.
func _point_at(i: int) -> void:
	_cursor = clampi(i, 0, maxi(_rows.size() - 1, 0))
	var cell: Button = null
	if mode == Mode.SELL:
		cell = _grid.cell_at(_cursor)
	else:
		cell = _ladder.cell_at(_ladder.slot_of_line(_cursor))
	if cell != null and cell.get_viewport() != null:
		cell.grab_focus()
		# The board is taller than the frame. Following the cursor is what makes
		# the scrollbar something the player never has to know about.
		#
		# DEFERRED, because the common caller is `_refresh`, which has just torn
		# the board down and rebuilt it: the new cell is in the tree but the
		# containers have not laid out yet, so it is still at (0,0) with zero
		# size and scrolling to it scrolls to the top every time.
		if _scroll != null:
			_scroll.ensure_control_visible.call_deferred(cell)
	_describe()


## Put the cursor's cell back in the viewport after something else changed the
## viewport's size. Deferred for the same reason `_point_at` defers: on a resize
## frame the containers have not finished laying out, and scrolling to a rect
## that has not moved yet scrolls to where the cell used to be.
func _keep_cursor_in_view() -> void:
	if mode == Mode.SELL or _scroll == null or _ladder == null:
		return
	var cell := _ladder.cell_at(_ladder.slot_of_line(_cursor))
	if cell != null and cell.get_viewport() != null:
		_scroll.ensure_control_visible.call_deferred(cell)


## The mouse landed on a cell. Follow it — a click is also a look.
func _on_cell_looked(index: int) -> void:
	if index >= 0 and index != _cursor:
		_point_at(index)


func _describe() -> void:
	for c in _recipe.get_children():
		c.queue_free()
	if _rows.is_empty():
		_d_kind.text = ""
		_d_name.text = ""
		_d_price.text = ""
		_d_blurb.text = ""
		UiKit.band_value(_band, &"cost", "—")
		return

	var row := _rows[_cursor]
	_d_name.text = String(row["label"])
	_d_blurb.text = String(row["blurb"])

	match row["kind"]:
		&"item":
			var def := ItemDb.get_def(row["id"])
			_d_kind.text = "%s  ·  %s" % [def.rarity_name().to_upper(),
				def.bench_name() if def.is_component() else "INGREDIENT"]
			_d_price.text = "%d ◇  for ×%d" % [int(row["price"]), int(row["count"])]
			_d_blurb.text += "  " + Wishlist.usage_sentence(row["id"])
		&"all":
			_d_kind.text = "EVERY STACK"
			_d_price.text = "%d ◇" % int(row["price"])
		&"buy":
			var left: int = int(row["count"])
			_d_kind.text = "%d LEFT" % left if left >= 0 else ""
			_d_price.text = "%d ◇" % int(row["price"])
			_fill_recipe(row["line"])
			# SUCCESS/DANGER off `ok`, which is the catalogue's own answer and
			# accounts for MATERIALS as well as coin. Colouring it by comparing the
			# price to the purse would call a recipe you cannot fill affordable.
			UiKit.band_value(_band, &"cost", "%d ◇" % int(row["price"]),
				UITheme.SUCCESS if bool(row["ok"]) else UITheme.DANGER)


func _fill_recipe(catalogue_line: Dictionary) -> void:
	var parts: Dictionary = catalogue_line.get("parts", {})
	if parts.is_empty():
		return
	for id: StringName in parts:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var need := int(parts[id])
		# Through the live catalogue handle: bare static calls do not dispatch to
		# overrides. Most recipes read the persistent workbench; the smith's
		# fletching line spends the run bag and overrides this one seam.
		var have: int = _db().part_count(catalogue_line, id)

		var line := HBoxContainer.new()
		_recipe.add_child(line)

		# The name carries what the recipe WANTS and the right-hand figure what
		# the bench HAS. Spelled "have 3" rather than shown as "3 / 4", because
		# a bare pair of numbers reads either way round and the first version of
		# this row printed 120/4 for a recipe wanting four of a hundred and
		# twenty — which looks exactly like being short.
		var what := Label.new()
		what.text = "%s ×%d" % [def.display_name, need]
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_text_style(what, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT)
		line.add_child(what)

		# Green when the bench covers it, red when it does not, PER COMPONENT.
		# A recipe you are one core short of and a recipe you have none of look
		# identical if the whole line just greys out, and the difference between
		# them is a whole run's worth of where to go looking.
		#
		# The kit's SUCCESS/DANGER rather than `Pal.MOSS`/`Pal.RUST`: this is a
		# status tick on a menu, not something in the world. The PSX pair stays
		# where it belongs — the HUD, the motes, the world at native resolution.
		var tally := Label.new()
		tally.text = "have %d" % have
		UITheme.apply_text_style(tally, UITheme.TYPE_PARAGRAPH_2,
			UITheme.SUCCESS if have >= need else UITheme.DANGER)
		line.add_child(tally)


# --- Input -------------------------------------------------------------------
## Polled, not event-driven. Two reasons, and the second is the real one:
##
##  1. Held-direction repeat is a timer, and a timer next to `_unhandled_input`
##     is two clocks for one behaviour.
##  2. `Input.action_press()` -- what the capture harness drives the game with --
##     sets action STATE and never synthesises an InputEvent, so anything that
##     only listens to `_unhandled_input` cannot be exercised by a tool. A screen
##     that can only be tested by a human is a screen that does not get tested.
##
## This is also why the cursor is `_cursor` and not the focus owner: Godot's own
## focus navigation runs off InputEvents, so a board driven by `grab_focus` alone
## would be invisible to every director in `tools/`. Focus follows the cursor
## rather than leading it.
##
## Both edges start DISARMED, which is what stops the interact press that opened
## this screen -- still held -- from buying the top line on arrival.

const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.09

## Seconds on the button for a commit that eats materials. Shorter than the
## gate's 0.9 s and deliberately so: the gate is guarding against a press you made
## while walking past, and this is guarding against the cursor being one cell from
## where you thought it was. Long enough to be a decision, short enough that
## brewing four draughts in a row is not a chore.
const CRAFT_HOLD := 0.5

## How long a refusal stays on the footer.
##
## Long enough to READ. The old 0.45 s was tuned for a one-word recolour of the
## hint line; "NEED 2 COLD IRON CORES" is a sentence, and a sentence that leaves
## before it is finished is the same as no sentence.
const REFUSE_TIME := 1.8

var _armed_accept: bool = false
var _armed_cancel: bool = false
var _armed_jump: bool = false
var _repeat: float = 0.0
## 0..1 on the selected cell's commit. See `_hold_time`.
var _hold: float = 0.0


## Seconds this cell wants on the button, 0 to fire on press.
##
## **Held: the commits you cannot undo.** A forge rung, a blown bottle, a brew and
## a set stone all eat components -- a Cold Iron Core is a thing you FOUND, and
## spending one on the wrong ladder because the cursor was a cell off is the only
## shop mistake this game cannot give back (docs/METAGAME.md §6.5). SELL
## UNMARKED is here for the same reason from the other side: it is one press that
## can empty most of the bag.
##
## **Tapped: everything else.** Arrows, a bag slot, a jewel blank, selling one
## stack. Gold is grindable and a single line is re-buyable, and a hold on every
## cell would be ceremony -- which is worse than no hold at all, because a player
## who holds through twelve harmless confirms stops reading the one that mattered.
func _hold_time(i: int) -> float:
	if i < 0 or i >= _rows.size():
		return 0.0
	var row := _rows[i]
	if row["kind"] == &"all":
		return CRAFT_HOLD
	if row["kind"] == &"buy" and _db().crafts(row["line"]):
		return CRAFT_HOLD
	return 0.0


## The board owns its four arrows, and takes them before the GUI layer runs.
##
## **Until this existed, one press of RIGHT moved the cursor TWO cells**, because
## two different things moved it. `_step` polls the action below; and Godot's own
## focus navigation reads the same `ui_left/right/up/down` off the InputEvent in
## `Viewport::_gui_input_event`, walks the focused cell to its
## `focus_neighbor_*` (which `UpgradeLadder._wire_focus` and `ItemGrid` wire on
## purpose, for the mouse and for spill), and the `focus_entered` that lands runs
## `_look` -> `cell_focused` -> `_on_cell_looked` -> `_point_at`. The docstring
## under `_tick_input` says focus follows the cursor rather than leading it. It
## did both.
##
## The cost was not cosmetic. A double step over a board with an EVEN number of
## reachable lines never lands on an odd one, so half of every counter was
## unreachable: on the Lanternkeeper's twelve relics the cursor ran
## 0,2,4,6,8,10,0,2,… for as many presses as you like and **six of the twelve
## could not be selected, and therefore could not be donated at all**. Found by
## `relic_donate.gd`'s G8 while card #74 was being settled, and confirmed to be
## the GAME and not the harness by driving it with a real `InputEventKey` for
## `KEY_RIGHT` -- no `action_press`, no `InputEventAction`, exactly the bytes the
## OS delivers -- which stepped by two in exactly the same way.
##
## `_input` and NOT `_unhandled_input`: the GUI phase sits between the two, and
## the GUI phase is the thing being headed off. Marking the event handled leaves
## the ACTION STATE untouched -- `Input` set that before dispatch -- so `_step`'s
## poll below reads the press exactly as it always did.
func _input(event: InputEvent) -> void:
	if _closing:
		return
	if (event.is_action(&"ui_left") or event.is_action(&"ui_right")
			or event.is_action(&"ui_up") or event.is_action(&"ui_down")):
		get_viewport().set_input_as_handled()


func _tick_input(delta: float) -> void:
	if _closing:
		return

	var cancel := Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(&"pause")
	if not cancel:
		_armed_cancel = true
	elif _armed_cancel:
		_armed_cancel = false
		close()
		return

	var accept := Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"interact")
	if not accept:
		_armed_accept = true
	var jump := Input.is_action_pressed(&"jump")
	if not jump:
		_armed_jump = true
	elif _armed_jump and not _wishlist_key().is_empty():
		_armed_jump = false
		Game.toggle_wishlist_line(_wishlist_key())
	if _rows.is_empty():
		return

	var step := _step(delta)
	if step != Vector2i.ZERO:
		_move(step)
		# Progress does not travel. Sliding onto the next cell with the button
		# down would arrive there half-committed, which is the exact accident the
		# hold exists to prevent.
		_hold = 0.0

	if accept and _armed_accept:
		var need := _hold_time(_cursor)
		if need <= 0.0:
			_armed_accept = false
			_commit()
		else:
			_hold += delta
			if _hold >= need:
				_hold = 0.0
				# Disarmed, so the button still being down after a brew does not
				# start brewing the next one.
				_armed_accept = false
				_commit()
	elif _hold > 0.0:
		# Snapped to zero, not decayed, for the reason `Prompt` gives: a bar that
		# drains says "keep going", and letting go was the opposite of that.
		_hold = 0.0


## Which way the stick went this frame, one press or one repeat tick. Both axes
## are answered as -1/0/+1 and what a step MEANS is `_move`'s business, because
## the two sides of this screen are laid out differently and neither of them is
## "add one to an index": down a grid is four cells, down a board of ladders is
## however many rungs the row you are on happens to have.
func _step(delta: float) -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_action_just_pressed(&"ui_right"):
		d.x = 1
	elif Input.is_action_just_pressed(&"ui_left"):
		d.x = -1
	elif Input.is_action_just_pressed(&"ui_down"):
		d.y = 1
	elif Input.is_action_just_pressed(&"ui_up"):
		d.y = -1
	if d != Vector2i.ZERO:
		_repeat = REPEAT_DELAY
		return d

	var held := Vector2i.ZERO
	if Input.is_action_pressed(&"ui_right"):
		held.x = 1
	elif Input.is_action_pressed(&"ui_left"):
		held.x = -1
	elif Input.is_action_pressed(&"ui_down"):
		held.y = 1
	elif Input.is_action_pressed(&"ui_up"):
		held.y = -1
	if held == Vector2i.ZERO:
		return Vector2i.ZERO
	_repeat -= delta
	if _repeat > 0.0:
		return Vector2i.ZERO
	_repeat = REPEAT_RATE
	return held


## Move the cursor one step.
##
## Left and right always mean ONE cell, on both sides. Up and down mean "the next
## thing", which is a row of four in the bag's grid and the next ladder on a
## counter -- a player at the smith wanting the next piece of armour should not
## have to press through three rungs of the one they are on to reach it.
##
## Both axes wrap. Holding one direction visits everything and never dead-ends,
## which is the guarantee the pouch's grid makes and the reason this screen moves
## its own cursor at all (see `_tick_input`).
func _move(d: Vector2i) -> void:
	if _order.is_empty():
		return
	if d.x != 0:
		var i := (_at() + d.x + _order.size()) % _order.size()
		_point_at(_order[i])
		return
	if d.y == 0:
		return
	if mode == Mode.SELL:
		_point_at((_cursor + d.y * COLS + _rows.size()) % _rows.size())
		return

	# The next row that has anything buyable on it. Rows CAN be dead -- a fully
	# climbed ladder still draws, because a row that vanished when you finished it
	# would take the record of finishing it with it -- so this walks past them
	# rather than parking the cursor on a rung with no price.
	var rows := _ladder.row_count()
	if rows <= 0:
		return
	var at := _ladder.row_of_line(_cursor)
	for n in rows:
		at = (at + d.y + rows) % rows
		var line := _ladder.first_line_of_row(at)
		if line >= 0:
			_point_at(line)
			return


func _commit() -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	var done := false
	match row["kind"]:
		&"item":
			done = Run.sell(row["id"]) > 0
		&"all":
			done = Run.sell_ids(row["ids"]) > 0
		&"buy":
			done = _db().buy(row["line"])

	if done:
		# The purchase that just landed answers whatever the last refusal said.
		_end_refusal()
		# On the press that WORKED, never on the press. A keeper who says "good
		# price" over a refusal is worse than one who says nothing.
		Voice.say(speaker, &"deal")
	else:
		_show_refusal()
	_refresh()


## Say why the press did nothing, in the counter's words.
##
## Ask the CATALOGUE rather than assuming money. Once a line can be refused for
## four different reasons, a hardcoded "NOT ENOUGH GOLD" sends the player back
## down for the wrong thing.
func _show_refusal() -> void:
	_end_refusal()
	var why := "Nothing there"
	if mode == Mode.BUY and _cursor >= 0 and _cursor < _rows.size():
		_refuse_line = _rows[_cursor]["line"]
		var said: String = _db().refusal(_refuse_line)
		why = said if said != "" else "Not enough gold"
	_refuse = 0.0
	_toast = UiKit.footer_toast(_toast_slot, why, UITheme.DANGER)


## Take the refusal down: the clock, the message and the line it was about.
##
## One function and not three assignments at each site, because the three have to
## move together — an earlier version cleared the node from inside the show path
## and took the remembered line with it, which left `_drop_stale_refusal` with
## nothing to re-ask and the stale message on screen for its full 1.8 s.
func _end_refusal() -> void:
	_refuse = -1.0
	_refuse_line = {}
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = null


## Drop a refusal that has stopped being true.
##
## The message outlives the press by design — long enough to read a sentence like
## "NEED 2 COLD IRON CORES" — and in that window the board can change under it: a
## rung bought on another track frees a component, an extraction stocks the bench.
## A red line saying you cannot afford something you can now afford is worse than
## no line, so `_refresh` re-asks the catalogue rather than letting the clock run.
func _drop_stale_refusal() -> void:
	if _refuse < 0.0 or _refuse_line.is_empty():
		return
	if _db().can_buy(_refuse_line):
		_end_refusal()


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	if not is_equal_approx(_shown_gold, float(Game.gold)):
		var step: float = maxf(1.0, absf(Game.gold - _shown_gold)) * (delta / ROLL_TIME)
		_shown_gold = move_toward(_shown_gold, float(Game.gold), step)
	if _refuse >= 0.0:
		_refuse += delta
		if _refuse > REFUSE_TIME:
			_end_refusal()
	_paint_chrome()


func _paint_chrome() -> void:
	UiKit.band_value(_band, &"purse", "%d ◇" % int(round(_shown_gold)))

	var need := _hold_time(_cursor)
	_hold_bar.visible = need > 0.0
	_hold_bar.progress = (_hold / need) if need > 0.0 else 0.0

	# Buttons come off the live InputMap through `Glyph`, not written in: this
	# line said ENTER and ESC on a pad, under a game whose HUD had already learned
	# not to.
	var accept_cap := Glyph.cap(&"ui_accept")
	if accept_cap.is_empty():
		accept_cap = "ENT"
	var leave_cap := Glyph.cap(&"ui_cancel")
	if leave_cap.is_empty():
		leave_cap = "ESC"
	# The hint says what the BUTTONS do and nothing else. Why a press was refused
	# is the footer toast's line (`_show_refusal`) — see `_build_footer`.
	if need > 0.0:
		_hint.text = "Hold %s to %s    %s Leave" % [accept_cap, _verb(), leave_cap]
	else:
		_hint.text = "%s %s    %s Leave" % [accept_cap, _verb(), leave_cap]
	var wishlist_key := _wishlist_key()
	if not wishlist_key.is_empty():
		var jump_cap := Glyph.cap(&"jump")
		if jump_cap.is_empty():
			jump_cap = "F"
		_hint.text += "    %s %s" % [jump_cap,
			"Unwishlist" if Game.is_wishlist_line_pinned(wishlist_key) else "Wishlist"]


func _wishlist_key() -> StringName:
	if mode != Mode.BUY or _cursor < 0 or _cursor >= _rows.size():
		return &""
	var row := _rows[_cursor]
	if row.get("kind") != &"buy":
		return &""
	var line: Dictionary = row["line"]
	var parts: Dictionary = line.get("parts", {})
	if parts.is_empty():
		return &""
	return Wishlist.line_key(_db(), line)


## The label of the cell the cursor is on, or "" when the board is empty.
##
## For the directors. A beat that wants a particular line used to reach it by
## counting presses from the top, and that count is a lie the moment the board
## changes length — the smith hides ARROWS until you own a bow, so `mvp_loop`'s
## "second line is the bag slot" quietly became "the heart container" and the run
## still went green. A beat can now walk the board and stop when it recognises
## where it is. Read-only, and the shipped screen never calls it.
func cursor_label() -> String:
	if _cursor < 0 or _cursor >= _rows.size():
		return ""
	return String(_rows[_cursor]["label"])


## How many cells the board has, so a walk over it terminates.
func line_count() -> int:
	return _rows.size()


## What the selected cell does, in the counter's own word: FORGE at the smith,
## BREW at the alchemist, SET at the jewelcrafter, BUY for anything they merely
## have in stock, SELL on the other side of the shop. Asked of the catalogue
## rather than decided here, so a sixth counter names its own act without this
## file learning about it.
func _verb() -> String:
	if _cursor < 0 or _cursor >= _rows.size():
		return "Sell" if mode == Mode.SELL else "Buy"
	var row := _rows[_cursor]
	match row["kind"]:
		&"all":
			return "Sell all"
		&"buy":
			# Both questions asked of the catalogue HERE rather than folded into
			# one helper on it: a static calling a static inside `Catalogue` binds
			# to `Catalogue`, so the smith's FORGE never came back. See the note
			# on `Catalogue.craft_verb`.
			var line: Dictionary = row["line"]
			# A line may name its own verb, and Reforge and Recut do: they are held
			# presses at a counter whose held word is FORGE, and "HOLD ENT TO FORGE"
			# over a row that puts the plate BACK in the fire is the footer saying
			# the opposite of what the press does.
			if line.has("verb"):
				return String(line["verb"])
			# The counter's own word, in the counter's own case. Not capitalized
			# to match the rest of the footer: FORGE, BREW and SET are what these
			# people call the act, `forge_loop` CH1b checks that this line says
			# so, and a screen that quietly title-cased the smith's word would
			# make that check a lie about the thing it is testing.
			return _db().craft_verb() if _db().crafts(line) else "Buy"
	return "Sell"
