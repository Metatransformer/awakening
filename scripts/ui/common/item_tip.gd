class_name ItemTip
extends PanelContainer
## The hover card. **The one way this game says what a thing IS.**
##
## A cell has room for a picture, a name and one number (`ItemCell`). Everything
## else a player decides with — the rarity, the price, whether they can pay for
## it, what it is for, what it reads like — lives on this card, and the card
## follows the cursor: beside the cell it describes, never over it, never off the
## screen.
##
## It replaces the DETAIL COLUMN, which three screens each had their own copy of.
## The column was a hand's width of panel standing full height whatever it had to
## say — the longest blurb in the game is six lines (`lore_panes`) — and it was
## taking that width off the one thing the player came to look at. The counter
## gave its column up first (card #119); the owner then asked for the same of the
## bag and the locker, in the same breath as the square tiles: *"it needs to pop
## up when you hover over something in an inventory or an upgrade screen or a
## trader — you see it, rather than having that details thing show up on the right
## side."*
##
## **The placement is `TradeScreen._place_tip`'s, whole**, because that one has
## been walked at every cell of three boards on two input paths by
## `tools/directors/shop_tip.gd` and the four ways it can go wrong are already
## known. Moving it here rather than copying it is the whole point: a second
## placement solver is a second set of edge cases, and the edges — the rightmost
## column, the bottom row — are the only places this is hard.
##
## **What it does NOT own is what to say.** The screen writes the card, because
## the sentences are the screen's: the counter says a price and a recipe, the bag
## says what a stack is worth and whether A packs it, the locker says how the
## kind is split. A card that reached for the item itself would be a second place
## every item is interpreted.

## The card's width, which is what the detail COLUMN was. Kept to the pixel on
## purpose: it is what every blurb in the game has been wrapped and measured at
## (`tools/directors/lore_panes.gd` counts the lines), so moving the text out of
## the frame does not silently re-wrap forty paragraphs.
const WIDTH := 340
## Between the card and the cell it describes. The card must never sit ON the
## cell — that is the one thing a description of a thing must not hide.
const GAP := 12
## And never against the edge of the screen either.
const MARGIN := 12

## The cell the card is currently about. The screen sets this through
## `point_at`; the card reads its rect once a frame and nothing else.
var anchor: Control = null

var kicker: Label
var title: Label
var price: Label
## The one-word verdict — "Affordable", "Not enough gold", "◆ The forge eats
## this". Written with `say_note`, which sets the colour with the words: a note
## whose tone outlived its sentence is how a card ends up calling a refusal green.
var note: Label
## Whatever the screen wants between the note and the blurb — the counter's
## recipe rows, one component per line. Emptied by `clear`.
var rows: VBoxContainer
var blurb: Label


## Build the card and park it, hidden, as the LAST child of `parent` so it draws
## over everything that screen has.
##
## `MOUSE_FILTER_IGNORE` on every node in here, and it is load-bearing rather
## than tidy: the card floats over the board, so a card that took the pointer
## would steal `mouse_entered` from the cells underneath it and the mouse path
## would die the moment the card landed near the row below.
static func make(parent: Node) -> ItemTip:
	var tip := ItemTip.new()
	tip.name = "Tip"
	tip.add_theme_stylebox_override("panel", UITheme.tooltip_card())
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.custom_minimum_size = Vector2(WIDTH, 0)
	tip.size = Vector2(WIDTH, 0)
	tip.visible = false
	# The menus pause the tree. `_process` is where the card is placed, so a card
	# that inherited a paused parent's process mode would be a card that never
	# moved off the top-left corner of the pouch.
	tip.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(tip)
	return tip


func _init() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	# The kicker/title/number stack of a `PlateHeader`, written out by hand rather
	# than composed: this one is REWRITTEN on every cursor move, and a component
	# that rebuilds its own nodes would throw away the layout sixty times a second
	# while a stick is held.
	kicker = Label.new()
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(kicker, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	col.add_child(kicker)

	title = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(title, UITheme.TYPE_H1, UITheme.TEXT)
	col.add_child(title)

	price = Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(price, UITheme.TYPE_LABEL_XL, UITheme.ACCENT)
	col.add_child(price)

	note = Label.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(note, UITheme.TYPE_CAPTION, UITheme.SUCCESS)
	col.add_child(note)

	rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	col.add_child(rows)

	# No `SIZE_EXPAND_FILL`, which the detail column had: the card is exactly as
	# tall as what it is saying, and a blurb that asked for the leftovers of a
	# height nothing is setting would have nothing to expand into.
	blurb = Label.new()
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(blurb, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	col.add_child(blurb)


## Blank every line and drop the recipe rows. Called by a screen at the top of
## its describe, so a field the new cell does not set cannot keep the last one's
## text — which is exactly how a price ends up on a card describing an empty slot.
func clear() -> void:
	kicker.text = ""
	title.text = ""
	price.text = ""
	note.text = ""
	blurb.text = ""
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()


## The verdict line, with its colour. One call, because the two are one statement:
## `UITheme.apply_text_style` is what carries the tone, and a screen that set the
## text here and the style somewhere else is a screen with a stale colour in it.
func say_note(text: String, tone: Color = UITheme.SUCCESS) -> void:
	note.text = text
	UITheme.apply_text_style(note, UITheme.TYPE_CAPTION, tone)


## Describe `cell`. The card shows itself and starts following that rect.
func point_at(cell: Control) -> void:
	anchor = cell
	visible = cell != null
	if cell != null:
		_place()


## Stop describing anything. A card describing nothing is not an empty card, it
## is no card — a bordered rectangle of nothing beside an empty board is the
## screen saying "sold out" twice.
func hide_tip() -> void:
	anchor = null
	visible = false


## Placed per FRAME and not on the cursor move, for the reason `TradeScreen`'s
## `_point_at` defers its scroll: on the frame the cursor moves the containers
## have not laid out, the new cell is still at (0,0) with zero size, and a card
## placed against that rect is a card in the top-left corner. Reading the rect
## once a frame also means the card follows the board when it SCROLLS under a
## held direction, which nothing else would tell it about.
func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if not visible:
		return
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
		return
	# The card is exactly its content, every frame. A Control outside a Container
	# grows to its minimum size on its own and never shrinks back, so a six-line
	# relic blurb would leave the card six lines tall over the two-line one after
	# it -- assigned rather than left alone.
	var want := Vector2(WIDTH, get_combined_minimum_size().y)
	if not size.is_equal_approx(want):
		size = want
	# Solved every frame and ASSIGNED only when it moves. The solve is twenty
	# float operations; `set_position` is a layout notification, and a card that
	# re-laid itself out sixty times a second while a stick was held would be the
	# expensive half. Recomputing rather than caching the answer is also what
	# makes the placement self-correcting — `shop_tip.gd`'s Z2 shoves the card by
	# hand and requires it back, which a cache keyed on the cell would fail.
	var spot := spot_for(anchor.get_global_rect(), size, get_viewport_rect().size)
	if not position.is_equal_approx(spot):
		position = spot


## Where the card goes, given the cell it is about.
##
## Four places are tried in order — right of the cell, left of it, under it,
## over it — and the first one that fits the whole card inside the viewport wins.
## Right first because a board reads left to right and the eye is already
## travelling that way; under-and-over are the fallbacks for the rightmost and
## leftmost columns, which is exactly the case card #119 asks to be tested at.
## Each candidate is clamped only on the axis it does NOT depend on, so clamping
## can never slide the card back over the cell it was placed off.
##
## Static and pure, so a director can ask it the same question the widget asks.
static func spot_for(cell: Rect2, tip: Vector2, view: Vector2) -> Vector2:
	var lo := Vector2(MARGIN, MARGIN)
	var hi := Vector2(maxf(MARGIN, view.x - tip.x - MARGIN),
		maxf(MARGIN, view.y - tip.y - MARGIN))
	# Centred on the cell along the free axis, then pulled back inside the frame.
	var mid_y := clampf(cell.get_center().y - tip.y * 0.5, lo.y, hi.y)
	var mid_x := clampf(cell.get_center().x - tip.x * 0.5, lo.x, hi.x)
	var tries: Array[Vector2] = [
		Vector2(cell.end.x + GAP, mid_y),               # right of the cell
		Vector2(cell.position.x - GAP - tip.x, mid_y),  # left of it
		Vector2(mid_x, cell.end.y + GAP),               # under it
		Vector2(mid_x, cell.position.y - GAP - tip.y),  # over it
	]
	for at: Vector2 in tries:
		if at.x >= lo.x and at.x <= hi.x and at.y >= lo.y and at.y <= hi.y:
			return at
	# Nothing fits cleanly -- a cell taller than the gaps around it, or a card
	# taller than the screen. Take the corner furthest from the cell and clamp:
	# overlapping is still the worst outcome, so the LAST resort is the one that
	# keeps the two apart rather than the one that keeps the card square.
	return Vector2(
		lo.x if cell.get_center().x > view.x * 0.5 else hi.x,
		lo.y if cell.get_center().y > view.y * 0.5 else hi.y)
