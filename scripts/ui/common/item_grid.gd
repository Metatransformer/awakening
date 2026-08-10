class_name ItemGrid
extends GridContainer
## A grid of item cells. **The one way this game draws a collection of things.**
##
## The pouch was a grid and everything else was a list, and the two did not look
## like the same game: the bag was cells with the item's own tint on top, and the
## vendor, the smith, the alchemist, the jewelcrafter, the footlocker and the
## receipt were rows of text that could have come out of a console. A player
## looking at their bag and then at what the vendor would give them for it was
## reading two different UIs about the same objects.
##
## So there is one control and every one of those screens builds cells with it.
## The cell is the pouch's cell, because the pouch's is the one that was already
## right: the item's tint as a chip across the top, the name (with ◆ when a
## counter in the garrison wants it and the vendor does not), and a line under
## it that says the thing this particular screen is about — a stack count in the
## bag, a price at a counter, `2/4` at a bench.
##
## **It is a GridContainer and not a screen.** SCOPE §1 freezes new UI screens at
## zero; this is a control the existing screens put inside the cards they already
## have. It owns no state that outlives a `set_cells()` call, it never reads
## `Game` or `Run`, and it decides nothing — the caller says what the cells are
## and what happens when one is pressed. A grid that reached for the bag itself
## would be a second place the bag is interpreted.
##
## Focus is per cell and wired left-to-right, top-to-bottom, with the ends of a
## row joined to the next so a stick flick never dead-ends in the middle of a
## collection.

## Emitted when the cursor lands on a cell, by pad, mouse or click. `index` is
## into the array last handed to `set_cells`, and is -1 for a padding cell.
##
## Every screen using this draws a detail pane off this signal rather than off
## the press, because the detail is what the cell is FOR — a player moving the
## stick across their bag is reading, not choosing.
signal cell_focused(index: int)
## Emitted on a real press of a cell that carries an index. Screens with no verb
## (the pouch, the receipt) simply do not connect it.
signal cell_activated(index: int)

## What a cell can say. Keys, all optional except `label`:
##
##   label   String      the name, drawn big and wrapped
##   sub     String      the line under it — "×6", "120 ◇", "2/4"
##   tint    Color       the chip across the top; the item's own colour
##   mark    bool        prefix the label with ◆
##   dim     bool        draw the whole cell at 55% — an empty slot, a sold-out
##                       line, a rung you cannot pay for
##   index   int         what `cell_focused` reports; defaults to the position
##
## A Dictionary rather than a Resource or a custom class on purpose: every
## producer of these builds them inline from a catalogue row or a bag entry and
## none of them wants a second type to keep in step.

## The cell itself lives in `ItemCell`, because the ladders at the counters
## (`UpgradeLadder`) draw the same button in a different arrangement and two
## containers building "the same" cell is exactly how two cells happen. These are
## aliases so the callers that already read `ItemGrid.NAME_PT` keep working.
const CELL_MIN := ItemCell.SIZE
const NAME_PT := ItemCell.NAME_PT
const SUB_PT := ItemCell.SUB_PT
const EMPTY_LABEL := ItemCell.EMPTY_LABEL

## Where the cursor goes out of the BOTTOM row. Set by the screen, because only
## the screen knows what comes after its collection — the bench and the way out
## under the pouch's bag, the Back button under the receipt's. Left null, the
## bottom row simply has nothing below it.
var spill_down: Control = null

var _cells: Array[Button] = []
## Parallel to `_cells`. The index each reports, or -1 for a padding cell.
var _index_of: Array[int] = []


func _init() -> void:
	columns = 4
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)


## Draw `entries`, padding with empty cells up to `capacity`.
##
## `capacity` is the bag's and the locker's case: the number of cells is the
## number of slots you own, most of them visibly empty, and that picture is the
## information. Leave it at 0 for a collection that has no capacity — a shop
## board, a receipt — and the grid is exactly as big as its contents.
##
## Buttons are REUSED across calls when the count has not changed. Freeing and
## rebuilding them would drop focus on every refresh, and every screen here
## refreshes after a transaction the player made with the stick still on the
## cell they bought from.
func set_cells(entries: Array, capacity: int = 0) -> void:
	var want: int = maxi(entries.size(), capacity)
	_resize(want)
	for i in want:
		var e: Dictionary = entries[i] if i < entries.size() else {}
		_index_of[i] = int(e.get("index", i)) if not e.is_empty() else -1
		_paint(_cells[i], e)
	_wire_focus()


## The cell at a position, for a screen that has to reach into the focus chain —
## joining the grid's top row to a tab strip above it, or its last row to a Back
## button. Null when the position does not exist.
func cell_at(i: int) -> Button:
	return _cells[i] if i >= 0 and i < _cells.size() else null


func count() -> int:
	return _cells.size()


## Put the cursor on the first cell that carries an index, so a screen opening on
## a half-empty bag does not start focused on a blank.
func focus_first() -> bool:
	for i in _cells.size():
		if _index_of[i] >= 0:
			_cells[i].grab_focus()
			return true
	if not _cells.is_empty():
		_cells[0].grab_focus()
		return true
	return false


# --- Building ----------------------------------------------------------------

func _resize(want: int) -> void:
	while _cells.size() > want:
		_cells.pop_back().queue_free()
		_index_of.pop_back()
	while _cells.size() < want:
		_index_of.append(-1)
		_cells.append(_make(_cells.size()))


func _make(at: int) -> Button:
	var b := ItemCell.make()
	b.name = "Cell_%d" % at
	b.set_meta(&"at", at)
	add_child(b)
	b.pressed.connect(func() -> void: _on_press(b))
	b.focus_entered.connect(func() -> void: _report(b))
	b.mouse_entered.connect(func() -> void: _report(b))
	return b


func _paint(b: Button, e: Dictionary) -> void:
	ItemCell.paint(b, e)


# --- Focus -------------------------------------------------------------------

## Left/right WRAPS inside a row; down leaves the grid at the bottom.
##
## This is the pouch's wiring, moved here whole, and both halves of it are
## load-bearing. Godot's spatial focus detection gets the middle of a grid right
## on its own and gets the ENDS wrong: at the right-hand edge it finds nothing to
## the right and the cursor stops, which in a four-wide bag means the stick dies
## every fourth cell. And the last row has to hand focus to whatever the screen
## put underneath it, or the grid is a trap you can only leave with B.
##
## The wrap is per row and reads `n` rather than `columns` at the end, so a short
## last row wraps within itself instead of walking off into a cell that is not
## there.
func _wire_focus() -> void:
	var n := _cells.size()
	if n == 0:
		return
	for i in n:
		var row := i / columns
		var col := i % columns
		var wide: int = mini(columns, n - row * columns)
		MenuUtil.link_right(_cells[i], _cells[row * columns + (col + 1) % wide])
		var below := (row + 1) * columns + col
		if below < n:
			MenuUtil.link_down(_cells[i], _cells[below])
		elif spill_down != null:
			MenuUtil.link_down(_cells[i], spill_down)


func _report(b: Button) -> void:
	cell_focused.emit(_index_of[int(b.get_meta(&"at"))])


func _on_press(b: Button) -> void:
	var idx := _index_of[int(b.get_meta(&"at"))]
	# A press reports focus too, because a click is also a look: the mouse can
	# land on a cell the stick never crossed, and the detail pane has to follow.
	cell_focused.emit(idx)
	if idx >= 0:
		cell_activated.emit(idx)
