class_name TradeScreen
extends Control
## The vendor, the smith, the alchemist, the jewelcrafter and the Lanternkeeper,
## which are the same screen pointed in five directions.
##
## SELL reads the bag. BUY reads a CATALOGUE, handed in at `open()` -- `ShopDb`
## for the smith, `AlchemyDb` for the alchemist, `JewelDb` for the jewelcrafter --
## and they are interchangeable because they expose the same five statics
## (`lines`, `remaining`, `can_buy`, `refusal`, `buy`). Nothing below this line
## asks which counter it is standing at, and that is the whole reason there is one
## screen: the recipe column, the per-token affordability colouring and the
## refusal footer are subtle, they took three passes to get right, and a second
## shop screen would have been a second place for all of it to drift.
##
## **It draws a GRID, not a list, and the grid is the bag's** (`ItemGrid`).
## Until 2026-08-09 this screen was a column of PixelFont rows: the same objects
## the pouch drew as tinted cells arrived at the vendor as lines of text, so a
## player looking at their bag and then at what it was worth was reading two
## different UIs about one set of things. The grid is the pouch's, cell for cell,
## which means an ingredient has the same colour chip and the same ◆ in both
## places. That is the only icon set this game has.
##
## The frame, the header and the footer are the pause menu's theme
## (`scenes/ui/menu/menu_theme.tres`) for the same reason -- it is the game's one
## menu look, and a shop that did not use it was a shop that looked like a
## different program.
##
## One board, one cursor, one number that moves. The player is answering "what is
## this worth" over and over, so the price is the only thing that is ever GOLD and
## the purse is the only thing that animates.

enum Mode { SELL, BUY }

const THEME_PATH := "res://scenes/ui/menu/menu_theme.tres"
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
var _gold_label: Label
var _empty: Label
var _d_kind: Label
var _d_name: Label
var _d_price: Label
var _d_blurb: Label
var _recipe: VBoxContainer
var _hint: Label
var _hold_bar: HoldBar


## The screen makes its own CanvasLayer. A Control parented to a Node3D never
## draws, and every caller here is a prop standing in a 3D town.
## `db` is the catalogue for a BUY screen and defaults to the smith's, which is
## what every existing caller meant.
static func open(host: Node, screen_mode: Mode, screen_title: String,
		db: GDScript = null) -> TradeScreen:
	var layer := CanvasLayer.new()
	layer.name = "TradeLayer"
	# Above the HUD (50), below the pause menu (100): pausing out of the shop
	# should still put the pause menu on top of it.
	layer.layer = 60
	var s := TradeScreen.new()
	s.mode = screen_mode
	s.title = screen_title
	s.catalogue = db if db != null else ShopDb
	layer.add_child(s)
	host.get_tree().current_scene.add_child(layer)
	return s


func _ready() -> void:
	# A Control parented straight to a CanvasLayer is outside the viewport's
	# Control tree, so anchors alone never resolve and it sits at size (0,0).
	# Size it from the viewport and keep it there.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = load(THEME_PATH) as Theme
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)

	_shown_gold = float(Game.gold)
	_refresh()
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
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# --- Building ----------------------------------------------------------------

## Darken the world rather than hide it. You are standing in the town while you
## do this, and the shop is a conversation, not a menu screen.
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
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	centre.add_child(frame)

	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"MenuStack"
	frame.add_child(stack)

	_build_header(stack)
	_build_body(stack)
	_build_footer(stack)


func _build_header(parent: Node) -> void:
	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	parent.add_child(header)

	var row := HBoxContainer.new()
	header.add_child(row)

	var name_label := Label.new()
	name_label.theme_type_variation = &"MenuTitle"
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# The purse. The only number on this screen that animates, because it is the
	# only one the player's own press moved.
	_gold_label = Label.new()
	_gold_label.theme_type_variation = &"MenuValue"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_gold_label)


func _build_body(parent: Node) -> void:
	var pad := MarginContainer.new()
	pad.theme_type_variation = &"MenuBodyPad"
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(pad)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	pad.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)

	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "IN THE BAG" if mode == Mode.SELL else "ON THE BOARD"
	inner.add_child(caption)

	_grid = ItemGrid.new()
	_grid.name = "Board"
	_grid.columns = COLS
	# The cursor is this screen's, not the grid's -- see `_tick_input`. The grid
	# still reports a look, because the mouse can land on a cell the stick never
	# crossed and the detail pane has to follow it.
	_grid.cell_focused.connect(_on_cell_looked)
	inner.add_child(_grid)

	_empty = Label.new()
	_empty.theme_type_variation = &"MenuMuted"
	_empty.text = "Nothing to sell." if mode == Mode.SELL else "Sold out."
	inner.add_child(_empty)

	_build_detail(split)


## The one place a blurb, a price or a recipe is ever spelled out. A grid cell has
## room for a name and one number; everything else the player needs to decide with
## lives here, beside it, and never on the cell.
func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.custom_minimum_size = Vector2(DETAIL_W, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	_d_kind = Label.new()
	_d_kind.theme_type_variation = &"MenuMuted"
	col.add_child(_d_kind)

	_d_name = Label.new()
	_d_name.theme_type_variation = &"MenuHeading"
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_d_name)

	_d_price = Label.new()
	_d_price.theme_type_variation = &"MenuValue"
	col.add_child(_d_price)

	# The bill, one component per row: what it wants and what the bench has.
	# **Per row, never per line.** A recipe you are one core short of and a recipe
	# you have none of look identical if the whole thing just greys out, and the
	# difference between them is a whole run's worth of where to go looking.
	_recipe = VBoxContainer.new()
	_recipe.add_theme_constant_override("separation", 2)
	col.add_child(_recipe)

	_d_blurb = Label.new()
	_d_blurb.theme_type_variation = &"MenuSlotStat"
	_d_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_d_blurb)


## The line that says which button does what, and -- on a cell that wants one --
## that this one is a HOLD.
##
## The word and the gauge are one statement made twice, in language and in shape,
## exactly as the interact prompt makes it. Either alone has shipped as a bug
## here: "A TO DESCEND" with no bar was a player tapping and filing "descend
## doesn't work", and a bar with no word is a player watching something fill
## without knowing they are the one filling it.
func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	parent.add_child(footer)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	footer.add_child(row)

	_hint = Label.new()
	_hint.theme_type_variation = &"MenuHint"
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
			"mark": bool(row.get("mark", false)),
			"dim": not bool(row["ok"]),
		})
	_grid.set_cells(cells)
	_empty.visible = _rows.is_empty()
	_grid.visible = not _rows.is_empty()
	_point_at(_cursor)


func _build_sell_rows() -> void:
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
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
			"blurb": def.blurb,
			"ok": true,
		})
	_rows.sort_custom(func(a, b) -> bool: return a["price"] > b["price"])
	if not _rows.is_empty():
		_rows.append({
			"kind": &"all",
			"label": "SELL EVERYTHING",
			"count": 0,
			"price": Run.bag_value(),
			"sub": "%d ◇" % Run.bag_value(),
			"color": Pal.BONE,
			"blurb": "Empty the bag. The smith is two doors down.",
			"ok": true,
		})


func _build_buy_rows() -> void:
	for line in _db().lines():
		var left: int = _db().remaining(line["id"])
		_rows.append({
			"kind": &"buy",
			"line": line,
			"label": String(line["label"]),
			"count": left,
			"price": int(line["cost"]),
			"sub": "%d ◇" % int(line["cost"]),
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
	var cell := _grid.cell_at(_cursor)
	if cell != null and cell.get_viewport() != null:
		cell.grab_focus()
	_describe()


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
		&"all":
			_d_kind.text = "EVERY STACK"
			_d_price.text = "%d ◇" % int(row["price"])
		&"buy":
			var left: int = int(row["count"])
			_d_kind.text = "%d LEFT" % left if left >= 0 else ""
			_d_price.text = "%d ◇" % int(row["price"])
			_fill_recipe(row.get("parts", {}))


func _fill_recipe(parts: Dictionary) -> void:
	if parts.is_empty():
		return
	for id: StringName in parts:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var need := int(parts[id])
		var have := Game.component_count(id)

		var line := HBoxContainer.new()
		_recipe.add_child(line)

		# The name carries what the recipe WANTS and the right-hand figure what
		# the bench HAS. Spelled "have 3" rather than shown as "3 / 4", because
		# a bare pair of numbers reads either way round and the first version of
		# this row printed 120/4 for a recipe wanting four of a hundred and
		# twenty — which looks exactly like being short.
		var what := Label.new()
		what.theme_type_variation = &"MenuSlotStat"
		what.text = "%s ×%d" % [def.display_name, need]
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(what)

		var tally := Label.new()
		tally.theme_type_variation = &"MenuSlotStat"
		tally.text = "have %d" % have
		# Green when the bench covers it, red when it does not, PER COMPONENT.
		# A recipe you are one core short of and a recipe you have none of look
		# identical if the whole line just greys out, and the difference between
		# them is a whole run's worth of where to go looking.
		tally.modulate = Pal.MOSS if have >= need else Pal.RUST
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

var _armed_accept: bool = false
var _armed_cancel: bool = false
var _repeat: float = 0.0
## 0..1 on the selected cell's commit. See `_hold_time`.
var _hold: float = 0.0


## Seconds this cell wants on the button, 0 to fire on press.
##
## **Held: the commits you cannot undo.** A forge rung, a blown bottle, a brew and
## a set stone all eat components -- a Cold Iron Core is a thing you FOUND, and
## spending one on the wrong ladder because the cursor was a cell off is the only
## shop mistake this game cannot give back (docs/METAGAME.md §6.5). SELL
## EVERYTHING is here for the same reason from the other side: it is one press
## that empties the bag.
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
	if _rows.is_empty():
		return

	var step := _step(delta)
	if step != 0:
		# Wraps in reading order across the whole board, so holding one direction
		# still visits every cell -- the guarantee the pouch's grid makes, kept
		# here even though this screen moves the cursor itself.
		_point_at((_cursor + step + _rows.size()) % _rows.size())
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


## How far the cursor moves this frame, in cells. Left/right is one; up/down is a
## whole row, which is what makes a grid navigable with the same four directions a
## list used.
func _step(delta: float) -> int:
	var d := 0
	if Input.is_action_just_pressed(&"ui_right"):
		d = 1
	elif Input.is_action_just_pressed(&"ui_left"):
		d = -1
	elif Input.is_action_just_pressed(&"ui_down"):
		d = COLS
	elif Input.is_action_just_pressed(&"ui_up"):
		d = -COLS
	if d != 0:
		_repeat = REPEAT_DELAY
		return d

	var held := 0
	if Input.is_action_pressed(&"ui_right"):
		held = 1
	elif Input.is_action_pressed(&"ui_left"):
		held = -1
	elif Input.is_action_pressed(&"ui_down"):
		held = COLS
	elif Input.is_action_pressed(&"ui_up"):
		held = -COLS
	if held == 0:
		return 0
	_repeat -= delta
	if _repeat > 0.0:
		return 0
	_repeat = REPEAT_RATE
	return held


func _commit() -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	var done := false
	match row["kind"]:
		&"item":
			done = Run.sell(row["id"]) > 0
		&"all":
			done = Run.sell_all() > 0
		&"buy":
			done = _db().buy(row["line"])

	if not done:
		_refuse = 0.0
	_refresh()


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	if not is_equal_approx(_shown_gold, float(Game.gold)):
		var step: float = maxf(1.0, absf(Game.gold - _shown_gold)) * (delta / ROLL_TIME)
		_shown_gold = move_toward(_shown_gold, float(Game.gold), step)
	if _refuse >= 0.0:
		_refuse += delta
		if _refuse > 0.45:
			_refuse = -1.0
	_paint_chrome()


func _paint_chrome() -> void:
	_gold_label.text = "%d ◇" % int(round(_shown_gold))

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
	var hint := "%s %s    %s Leave" % [accept_cap, _verb(), leave_cap]
	if need > 0.0:
		hint = "Hold %s to %s    %s Leave" % [accept_cap, _verb(), leave_cap]
	if _refuse >= 0.0:
		# Ask the catalogue WHY rather than assuming money. Once a line can be
		# refused for four different reasons, a hardcoded "NOT ENOUGH GOLD" sends
		# the player back down for the wrong thing.
		hint = "Nothing there"
		if mode == Mode.BUY and _cursor >= 0 and _cursor < _rows.size():
			var why: String = _db().refusal(_rows[_cursor]["line"])
			hint = why if why != "" else "Not enough gold"
	_hint.text = hint
	_hint.modulate = Pal.RUST if _refuse >= 0.0 else Color.WHITE


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
			# The counter's own word, in the counter's own case. Not capitalized
			# to match the rest of the footer: FORGE, BREW and SET are what these
			# people call the act, `forge_loop` CH1b checks that this line says
			# so, and a screen that quietly title-cased the smith's word would
			# make that check a lie about the thing it is testing.
			return _db().craft_verb() if _db().crafts(line) else "Buy"
	return "Sell"
