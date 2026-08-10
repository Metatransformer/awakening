class_name UpgradeLadder
extends VBoxContainer
## The counters' board, drawn as what it actually is: a row per THING, and along
## each row the rungs of that thing's ladder with arrows between them.
##
## ## Why the flat list was wrong
##
## Every counter in this game sells ladders. `CHEST - HEAVY` is not a purchase,
## it is the second of three rungs on one of eight tracks, and the flat board
## showed only the rung you could buy next — so a player looking at the smith saw
## twelve unrelated lines and no way to tell that four of them were pairs, that
## each had two more rungs behind it, or how far along any of them they already
## were. The shape of the decision was the one thing the screen did not draw.
##
## Here the shape IS the drawing: `CHEST` is one row, `HEAVY` and `LIGHT` are its
## two branches, and the three rungs of each are three cells with arrows between
## them. Bought rungs are lit and ticked, the next one carries its price, the ones
## after it are dim. What the player is choosing — which ladder to spend the next
## core on — is legible without reading a word.
##
## ## What it is not
##
## Not a screen (SCOPE §1 freezes those at zero) and not a shop. It knows nothing
## about gold, components or `Game`; it is handed rows and cells and it arranges
## them. The cursor, the prices, the affordability and the commit all stay in
## `TradeScreen`, exactly as they did when the board was a grid.
##
## The cells are `ItemCell`, the same button the bag is made of, in its compact
## size. That is deliberate to the point of being the reason this file exists
## rather than a `_draw()`: a rung on the smith's board and a stack in your bag
## are drawn by one function, so they cannot drift.

## The cursor landed on a cell. `line` indexes the catalogue's `lines()`, and is
## -1 for a rung that is not buyable — an owned one, or one further up the ladder.
signal cell_focused(line: int)
## A real press on a BUYABLE rung. Never emitted for -1.
signal cell_activated(line: int)

## A group is one row:
##
##   {"title": String, "tracks": Array}
##
## and a track is one chain of rungs inside it:
##
##   {"name": String, "line": int, "owned": int, "rungs": int}
##
##   name   the branch's own label ("HEAVY"), or "" when the row has one track
##   line   index into `lines()` of the NEXT buyable rung, or -1 when there is
##          none — a finished ladder, or one the counter is not offering
##   owned  how many rungs are already bought
##   rungs  how long the ladder is
##
## A track with `rungs == 1` is not a ladder at all — a draught, a bag slot, a
## bundle of arrows — and draws as a plain named cell rather than a numeral, so
## the repeatables on a counter still look like the things they are.

## Rungs are numbered, not named: the row already says what the ladder is, so
## spending the cell's one line of text on "CHEST - HEAVY" again would leave
## nowhere to put the number that distinguishes it from the cell beside it.
## Four is every ladder in the game (`K.JEWEL_MAX`); the fallback is arithmetic
## rather than a longer table so a fifth rung is a number, not a crash.
const NUMERALS := ["I", "II", "III", "IV", "V", "VI"]

const ARROW := "→"
const TICK := "✓"
## The row's name column. Fixed, so every chain on the board starts at the same x
## and the ladders read as columns of rungs rather than as ragged text.
const TITLE_W := 132

var _cells: Array[Button] = []
## Parallel to `_cells`: the catalogue line each reports, or -1.
var _line_of: Array[int] = []
## Parallel to `_cells`: which row each is on.
var _row_of: Array[int] = []
## The buyable lines in BOARD order, which is not `lines()` order — the smith's
## groups put the shield between the blade and the armour while `_board` puts it
## after. The cursor has to walk what the player can see, so this is the order it
## walks and `lines()` is only ever an index into the prices.
var _order: Array[int] = []
var _rows_built: int = 0

## Where the cursor goes out of the last row. The screen's, because only the
## screen knows what comes after its board.
var spill_down: Control = null


func _init() -> void:
	add_theme_constant_override("separation", 6)


## Draw the board. `cells` is parallel to the catalogue's `lines()` and supplies
## what a BUYABLE rung says — its `sub` (the price), its `tint` and its `dim`
## (cannot pay for it). Owned and future rungs are the ladder's own to draw,
## because nothing in `lines()` describes a rung you are not being offered.
func set_board(groups: Array, cells: Array) -> void:
	for c in get_children():
		c.queue_free()
	_cells.clear()
	_line_of.clear()
	_row_of.clear()
	_order.clear()
	_rows_built = 0

	for g: Dictionary in groups:
		_add_row(g, cells)
		_rows_built += 1
	for i in _cells.size():
		if _line_of[i] >= 0:
			_order.append(_line_of[i])
	_wire_focus()


## The cell at a flat position, for a screen joining this into its focus chain.
func cell_at(i: int) -> Button:
	return _cells[i] if i >= 0 and i < _cells.size() else null


## Where in the flat cell order the buyable rung for `line` sits, or -1. The
## screen's cursor counts CATALOGUE LINES, and the board has cells that are not
## lines — this is the translation between the two, and it is the reason the
## cursor never lands on a rung the player already owns.
func slot_of_line(line: int) -> int:
	return _line_of.find(line)


func count() -> int:
	return _cells.size()


## The buyable lines in the order they appear on the board, left to right and top
## to bottom. The screen's cursor steps through THIS, never through `lines()`.
func order() -> Array[int]:
	return _order


## Which row `line` sits on, or -1. Up and down move by a row, because a row is
## one thing the counter sells and stepping a cell at a time through a four-rung
## ladder to reach the next piece of armour is four presses to answer one
## question.
func row_of_line(line: int) -> int:
	var i := _line_of.find(line)
	return _row_of[i] if i >= 0 else -1


## The first buyable line on `row`, or -1 when that row has none — a fully
## climbed ladder, which the cursor skips over rather than stopping on.
func first_line_of_row(row: int) -> int:
	for i in _cells.size():
		if _row_of[i] == row and _line_of[i] >= 0:
			return _line_of[i]
	return -1


func row_count() -> int:
	return _rows_built


# --- Building ----------------------------------------------------------------

func _add_row(g: Dictionary, cells: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var title := Label.new()
	title.theme_type_variation = &"MenuHeading"
	title.text = String(g.get("title", ""))
	title.custom_minimum_size = Vector2(TITLE_W, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)

	# A row with more branches than fit does not clip and does not squash the
	# cells — it wraps. That matters for the default board a catalogue gets
	# without authoring any groups at all: one row holding every line, which
	# wraps into the grid the counters had before this file existed.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flow)

	var tracks: Array = g.get("tracks", [])
	for t: Dictionary in tracks:
		_add_track(flow, t, cells)


func _add_track(parent: Node, t: Dictionary, cells: Array) -> void:
	var chain := HBoxContainer.new()
	chain.add_theme_constant_override("separation", 2)
	parent.add_child(chain)

	# A one-rung track carries its own name ON the cell, so a tag beside it would
	# print the same words twice -- which is exactly what the arrows row did.
	var branch := String(t.get("name", "")) if int(t.get("rungs", 1)) > 1 else ""
	if not branch.is_empty():
		var tag := Label.new()
		tag.theme_type_variation = &"MenuMuted"
		tag.text = branch
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chain.add_child(tag)

	var line: int = int(t.get("line", -1))
	var owned: int = int(t.get("owned", 0))
	var rungs: int = maxi(int(t.get("rungs", 1)), 1)
	var entry: Dictionary = cells[line] if line >= 0 and line < cells.size() else {}

	for i in rungs:
		if i > 0:
			var arrow := Label.new()
			arrow.theme_type_variation = &"MenuMuted"
			arrow.text = ARROW
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			# The arrow between two rungs you have already climbed is lit; the
			# rest of the chain is not. The row's progress is readable off the
			# connectors alone, from across the screen, before any cell is read.
			arrow.modulate = Pal.MOSS if i <= owned else Color(Pal.ASH, 0.7)
			chain.add_child(arrow)
		chain.add_child(_rung(t, i, owned, rungs, line, entry))


## One rung. Three states and they are three different questions: *done*, *this
## is what it costs*, *not yet*.
func _rung(t: Dictionary, i: int, owned: int, rungs: int, line: int,
		entry: Dictionary) -> Button:
	# A one-rung track is a repeatable, not a ladder: arrows, a draught, a bottle.
	# It keeps the full-size named cell it had on the old board, because its name
	# IS the information and there is no numeral that would mean anything.
	var solo := rungs == 1
	var b := ItemCell.make(ItemCell.Size.NAMED if solo else ItemCell.Size.RUNG)
	var is_next := i == owned and line >= 0

	var e: Dictionary = {}
	if solo:
		e = entry.duplicate()
		if e.is_empty():
			e = {"label": String(t.get("name", "")), "sub": "", "dim": true}
	elif i < owned:
		e = {"label": NUMERALS[i] if i < NUMERALS.size() else str(i + 1),
			"sub": TICK, "tint": Pal.MOSS}
	elif is_next:
		e = {"label": NUMERALS[i] if i < NUMERALS.size() else str(i + 1),
			"sub": String(entry.get("sub", "")),
			"tint": entry.get("tint", Pal.GOLD),
			"dim": bool(entry.get("dim", false))}
	else:
		# Not yet reachable. Dimmed and priced at nothing, because the price of a
		# rung two above the one you are on is a number that will have changed by
		# the time you can pay it, and printing it now is a promise the counter
		# does not keep.
		e = {"label": NUMERALS[i] if i < NUMERALS.size() else str(i + 1),
			"sub": "", "tint": Color(Pal.ASH, 0.5), "dim": true}

	ItemCell.paint(b, e)
	# Only a buyable rung answers. An owned one has nothing left to sell and a
	# future one is not on offer, and a cursor that stopped on either would be a
	# cursor the player has to press through to reach the thing they came for.
	var reports: int = line if (solo or is_next) and line >= 0 else -1
	b.focus_mode = Control.FOCUS_ALL if reports >= 0 else Control.FOCUS_NONE
	b.set_meta(&"at", _cells.size())
	_cells.append(b)
	_line_of.append(reports)
	_row_of.append(_rows_built)
	if reports >= 0:
		b.pressed.connect(func() -> void: _press(b))
		b.focus_entered.connect(func() -> void: _look(b))
		b.mouse_entered.connect(func() -> void: _look(b))
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# --- Focus -------------------------------------------------------------------

## The focusable cells, chained in reading order and wrapped end to end.
##
## Reading order and not spatial, which is the opposite of what a grid wants and
## right for the same reason: the cells here are not on a lattice. A row can hold
## one cell or eight, the focusable ones are scattered along each chain wherever
## that ladder happens to have got to, and Godot's spatial search across that
## finds plausible-looking neighbours that skip whole tracks. A flat chain of the
## cells that can actually be reached is the only wiring that visits all of them.
func _wire_focus() -> void:
	var live: Array[Button] = []
	for i in _cells.size():
		if _line_of[i] >= 0:
			live.append(_cells[i])
	if live.is_empty():
		return
	for i in live.size():
		var nxt := live[(i + 1) % live.size()]
		MenuUtil.link_right(live[i], nxt)
	if spill_down != null:
		MenuUtil.link_down(live[live.size() - 1], spill_down)


func _look(b: Button) -> void:
	cell_focused.emit(_line_of[int(b.get_meta(&"at"))])


func _press(b: Button) -> void:
	var line := _line_of[int(b.get_meta(&"at"))]
	cell_focused.emit(line)
	if line >= 0:
		cell_activated.emit(line)
