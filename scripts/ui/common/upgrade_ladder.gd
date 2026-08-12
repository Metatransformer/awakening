class_name UpgradeLadder
extends HFlowContainer
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
##
## ## Card #118, and the three things it changed
##
## The structure above survived the card and the RENDERING did not. What the
## owner saw was "a horizontal list with ugly icons, ugly text", and each of the
## three complaints has an answer here:
##
## 1. **Every row has a face.** `UiKit.TRACK` art, 44px, at the head of the row,
##    from the `icon` token the catalogue's `groups()` puts on it. Not from the
##    title -- a title is display text and two of the jeweller's rows are the same
##    object in two places on the body.
## 2. **The board is not a stack.** This is an `HFlowContainer` of fixed-width
##    PLATES, so the counter reads as a wall of cards, two abreast at 1280 and one
##    on a narrow pane, instead of twelve full-width lines. It was a
##    `VBoxContainer`; that is the whole diff for the layout, because every row
##    was already its own subtree.
## 3. **A bought ladder looks bought, from across the room.** Two things carry it,
##    and they are deliberately both SHAPE rather than both colour:
##    - the row's face brightens with the row's progress (`_ROW_DIM` -> full),
##      so a save's column of icons is lit or dark before a word is read;
##    - **an unclimbed rung is ABSENT, not greyed.** It draws as an empty socket
##      a third the width of a cell, so a fresh track is a face and two dots and a
##      finished one is a face and four filled cells. The old board drew every
##      rung at full size whatever its state, which is why a maxed track and a
##      fresh one differed by a tick and a dim and by nothing you could see at
##      arm's length.

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
## One plate. Fixed and not expanding, which is what makes the flow a GRID: two
## of these plus the flow separation is 1144 px, and the upgrade board's pane at
## 1280 is about 1180 -- so a counter lays out two abreast and drops to one when
## the pane is narrower, with no breakpoint written down anywhere.
const PLATE_W := 566
## The row's face. 44 and not the 19 a `VerbRow` gives a glyph: this art is
## painted objects on the Pal ramp (`UiKit.TRACK`), and at 19px a painted object
## is the dark smudge that made the first port of the kit look broken.
const FACE_PX := 44
## The face of a row with nothing bought on it. Not zero -- an unstarted track is
## still an offer, and a row with no picture at all would read as broken rather
## than as untouched.
const _ROW_DIM := 0.34
## An unclimbed rung, drawn as the hole where a cell will go. A third of
## `ItemCell.COMPACT_SIZE` wide, so the row's LENGTH is a picture of how far up
## the ladder the player is.
const SOCKET := Vector2(26, 62)

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
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 10)


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
	var tracks: Array = g.get("tracks", [])

	# A PLATE, not a line. The tile styleboxes are the same ones the paper doll's
	# sockets wear, so a row on a board and a slot beside the hero are the same
	# object at two sizes — see `UITheme.tile_plate`.
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.tile_plate())
	plate.custom_minimum_size = Vector2(PLATE_W, 0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)

	_add_face(row, g, tracks)

	var title := Label.new()
	title.theme_type_variation = &"MenuHeading"
	title.text = String(g.get("title", ""))
	# The face is ADDED to the title column rather than taken out of it: at
	# 132-44-8 = 80 px "THE BLADE" wrapped to two lines and the row grew a line
	# taller than its neighbours, which is the ragged edge TITLE_W exists to stop.
	title.custom_minimum_size = Vector2(TITLE_W - 28, 0)
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

	for t: Dictionary in tracks:
		_add_track(flow, t, cells)


## The row's face, and how brightly it is lit.
##
## Alpha runs `_ROW_DIM` -> 1.0 with the FRACTION of the row's rungs that are
## bought, counted across all its branches. That fraction and not "has the player
## bought anything": a chest one rung up and a chest finished are different
## amounts of owning it, and the card's acceptance test is two saves told apart at
## a glance without reading a word. A column of faces at four different
## brightnesses is that picture.
##
## A group with no `icon` gets no face and no gap where one would have been — the
## title simply starts at the plate's edge. That is what keeps a counter playable
## before its art is baked (`UiKit.track_icon` returns "" for a missing token).
func _add_face(row: Node, g: Dictionary, tracks: Array) -> void:
	var path := UiKit.track_icon(String(g.get("icon", "")))
	if path.is_empty():
		return
	var owned := 0
	var total := 0
	for t: Dictionary in tracks:
		owned += mini(int(t.get("owned", 0)), maxi(int(t.get("rungs", 1)), 1))
		total += maxi(int(t.get("rungs", 1)), 1)
	var lit: float = float(owned) / float(maxi(total, 1))
	var face := KitIcon.rect(UiKit.resolve_icon(path), FACE_PX,
		lerpf(_ROW_DIM, 1.0, lit))
	row.add_child(face)


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
	var solo := rungs == 1
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
		# A rung above the next buyable one is not a cell. See `_socket`.
		if i > owned or (i == owned and line < 0 and not solo):
			chain.add_child(_socket())
			continue
		chain.add_child(_rung(t, i, owned, rungs, line, entry))


## A rung the player has not reached: the HOLE where a cell will go.
##
## The old board drew this as a full-size `ItemCell` carrying a numeral, a dim and
## no price, and that is the single thing card #118 is most about. A four-rung
## ladder with nothing bought and a four-rung ladder finished were the same
## SHAPE — four cells wide, four numerals — differing only in a tick and 45% of
## alpha, so two saves at different progressions photographed identically at arm's
## length. Absent instead of greyed, the row's own length is the progress bar: a
## fresh track is a face and three dots, a finished one is a face and four cells.
##
## It carries no numeral. The numeral distinguishes rungs of a track you are
## climbing; on a rung you cannot see yet it is a label for nothing.
func _socket() -> Control:
	var hole := Panel.new()
	hole.custom_minimum_size = SOCKET
	# BG_DARKER and not a cell fill: a socket is a RECESS, the same darker glass
	# behind a fainter hairline that `UITheme.well()` sinks the whole board into.
	hole.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.BG_DARKER, 2, 2, 2, 2))
	hole.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.focus_mode = Control.FOCUS_NONE
	hole.modulate = Color(1, 1, 1, 0.45)
	return hole


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
		# Full strength and never dimmed: this is the half of the row that says
		# what the player HAS, and it is the half two saves are told apart by.
		e = {"label": NUMERALS[i] if i < NUMERALS.size() else str(i + 1),
			"sub": TICK, "tint": Pal.MOSS}
	elif is_next:
		e = {"label": NUMERALS[i] if i < NUMERALS.size() else str(i + 1),
			"sub": String(entry.get("sub", "")),
			"tint": entry.get("tint", Pal.GOLD),
			"dim": bool(entry.get("dim", false))}
	else:
		# The last rung of a ladder the counter has finished offering — bought out
		# to the top, or a branch that closed. `_add_track` sends everything ABOVE
		# the next buyable rung to `_socket` instead, so this arm no longer draws
		# the "not yet" cells it was written for; what reaches it is a rung that
		# exists and has no line, and it stays a cell because the row is still
		# showing you a ladder you own the whole of.
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
