class_name ItemCell
extends RefCounted
## The cell. One button, built and painted in one place, used by every layout
## that shows more than one thing.
##
## `ItemGrid` was the first home for this and for a day it was the only one. Then
## the counters grew ladders (`UpgradeLadder`) and there were two containers
## wanting the same button — at which point the choice was either a base class
## nobody needs or a pair of statics. These are the statics. A cell has no state,
## no signals of its own and no idea what it is inside; the container it lives in
## owns focus, wiring and meaning.
##
## **A FULL cell is a SQUARE ICON TILE — Morrowind's bag, not a business card.**
## It was a 140x88 landscape card with a colour chip across the top, a 30 px
## glyph under it, the name under that and a number under that: four stacked
## bands, of which the picture got a fifth of the height. Five of them across is
## 732 px, which is why the pouch had to fight for its fifth column (#120) and
## why the vendor drew TWO per row. The owner, 2026-08-12: *"the inventory grids
## are too big rn -- should look like square style grids think morrowind"*, and
## then named the reference build: *"steal the inventory styles from valenfeld."*
##
## So the tile is `~/valenfeld`'s `ItemTile.gd`, in this game's vocabulary: the
## art fills the square, the item's own `tint` is the FRAME around it, the name
## rides a strip along the bottom and `sub` -- the count, the price, the tally --
## is a badge in the top-right corner over the art. Nothing is stacked; the
## picture gets the tile.
##
## **The tint moved from a chip to the border and it did not become decoration.**
## Card #118 gave the catalogue real art, but `icon_crunch.posterise` keeps
## LUMINANCE and throws hue away, so the ramp cannot draw the difference between a
## green agate and a blue sapphire. The glyph says what KIND of thing it is and
## the tint says WHICH, and neither is doing the other's job -- that argument is
## unchanged, and a 2 px frame all round is a bigger sample of the hue than the
## 8 px chip was.
##
## **The name stayed, and Morrowind's tile does not have one.** Twenty-eight items
## have art (`assets/icons/items/`) and the catalogue is bigger than that; a tile
## whose art has not been baked yet must not be a blank square. It is one line,
## trimmed with an ellipsis, and the hover card (`ItemTip`) is what says the rest
## -- which is the trade the whole card was made for.

## What a cell can say. Keys, all optional except `label`:
##
##   label   String      the name, drawn big and wrapped
##   sub     String      the corner badge — "×6", "120 ◇", "2/4", "✓"
##   tag     String      a SECOND badge, top-left, for the one screen that has
##                       two numbers about one tile: the receipt says both what
##                       a stack was worth and how many of it there were
##   tint    Color       the chip across the top
##   icon    String      a `res://` path — `UiKit.item_icon(id)`. Absent or ""
##                       draws the cell exactly as it drew before glyphs existed,
##                       which is what lets an item ship before its art does.
##   mark    bool        prefix the label with ◆
##   star    bool        prefix the label with ★ without replacing ◆
##   dim     bool        draw the whole cell at 55% — an empty slot, a sold-out
##                       line, a rung you cannot pay for
##
## A Dictionary rather than a Resource or a custom class on purpose: every
## producer of these builds them inline from a catalogue row or a bag entry and
## none of them wants a second type to keep in step.

## The three shapes a cell comes in. Three and not one because the thing on the
## cell is three different lengths: a stack's name and count, a rung's numeral,
## and a repeatable's name on a board of rungs.
enum Size {
	FULL,     ## the bag, the receipt, the vendor's stock -- a name and a number
	RUNG,     ## one step of a ladder: a numeral and a price
	NAMED,    ## a repeatable sitting in a row of rungs -- a name, at rung height
}

## The square. 84 and not valenfeld's 62 because this game's names are on the
## tile rather than in a filter strip above it, and "Emberblood" needs the width
## to survive the ellipsis. Five across is 5x84 + 4x8 = **452 px**, where five of
## the old card was 732 -- the 280 px that buys is what the detail COLUMN used to
## cost on two of these screens.
const SIZE := Vector2(84, 84)
## A rung on a ladder holds a numeral and a price, not a name, so it does not
## need the width a name needs. Six of these plus a title still fit across the
## counter's left pane, which four full cells would not.
const COMPACT_SIZE := Vector2(78, 62)
## Arrows and the draughts: things with no ladder, on a board made of ladders.
## Near rung height so the row does not grow around them, name width because the
## name is the whole of what they say. The extra ten pixels over `COMPACT_SIZE`
## are for the second line: "EMBERBLOOD DRAUGHT" wraps at this width whatever it
## is given, and at rung height exactly its price fell out through the bottom.
const NAMED_SIZE := Vector2(158, 72)

## Cell text is smaller than the theme's Label default, and smaller again since
## the tile went square: 84 px of width is about eleven characters at 13 pt, and
## the label TRIMS rather than wraps (a second line would eat the picture). What
## a trimmed name costs is paid back by the hover card.
const NAME_PT := 13
const SUB_PT := 14
const COMPACT_NAME_PT := 17
const COMPACT_SUB_PT := 14

## The glyph, in a FULL cell only. A rung carries a numeral and a price in 62 px
## of height and has no room for a picture.
##
## On a square tile this is a FLOOR and not the size: the art is anchored to the
## tile and takes everything the frame and the name strip do not, which is what
## makes it read as a thing sitting in a slot rather than a stamp in the middle
## of one. `ICON_PX` survives as the minimum the art may shrink to.
const ICON_PX := 30

## The tile's inner geometry. `TILE_PAD` is the gap between the tint frame and
## the art; `TILE_NAME_H` is the strip along the bottom the name owns, which the
## art stops above rather than being drawn under -- a name over the picture is a
## name you have to read twice.
const TILE_PAD := 5.0
const TILE_NAME_H := 16.0
## The tint frame. Two pixels, because one disappears against a busy icon and
## three starts to read as a coloured tile rather than a framed picture.
const TILE_EDGE_PX := 2

## The empty cell's label. An empty slot is DIMMED, never hidden — a grid that
## shrank as you spent would stop being a picture of your capacity, which is the
## whole reason the bag is drawn this way (docs/METAGAME.md §3).
const EMPTY_LABEL := "—"



## A blank cell, parented nowhere.
##
## **Two layouts, one entry point.** A FULL cell is the square tile — art anchored
## to the whole square, the name on a strip along the bottom, the number badged
## into a corner. A RUNG or a NAMED cell is the old stacked column, unchanged,
## because a ladder's cell says a numeral and a price and has no picture to give
## the room to. `paint` reads the shape back off `&"cell_shape"` rather than
## guessing from the size, so a caller that resizes a tile cannot silently send it
## down the wrong painter.
static func make(shape: Size = Size.FULL) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta(&"cell_shape", int(shape))
	b.text = ""
	if shape == Size.FULL:
		_build_tile(b)
	else:
		_build_stack(b, shape)
	return b


## The square tile. Nothing here is in a Container: every part is anchored to the
## button's own rect, which is what lets the art and the badge OVERLAP instead of
## queueing up in a column. A `MenuSlot`'s content margins do not apply to a
## Button's children, so the geometry below is the whole geometry.
static func _build_tile(b: Button) -> void:
	b.custom_minimum_size = SIZE
	# Square and never stretched. A tile that grew to fill its column would stop
	# being square the moment the well beside it changed width, and five tiles of
	# different widths is not a grid.
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.clip_contents = true

	# The tint frame, built as a Panel with its own StyleBox rather than painted
	# into the Button's: the Button's five state boxes come from the `MenuSlot`
	# variation and carry the hover/focus vocabulary the whole kit shares, and a
	# per-cell override of them would trade the focus rim for the item's hue.
	var edge := Panel.new()
	edge.name = "Edge"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.focus_mode = Control.FOCUS_NONE
	b.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.focus_mode = Control.FOCUS_NONE
	art.visible = false
	b.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = TILE_PAD
	art.offset_top = TILE_PAD
	art.offset_right = -TILE_PAD
	art.offset_bottom = -TILE_NAME_H

	# The name strip. One line, TRIMMED and not wrapped: a second line would come
	# out of the picture, and the picture is why the tile is square.
	var label := Label.new()
	label.name = "Name"
	label.theme_type_variation = &"MenuSlotStat"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", NAME_PT)
	b.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 3
	label.offset_right = -3
	label.offset_top = -(TILE_NAME_H + 1.0)
	label.offset_bottom = -1

	# The number, badged into the top-right corner OVER the art -- the count in
	# the bag, the price at a counter. It is the one thing on the tile that is
	# drawn on top of the picture, so it carries a shadow: a gold "×6" over the
	# lit rim of a lantern is otherwise unreadable at exactly the moment it
	# matters.
	var sub := Label.new()
	sub.name = "Sub"
	sub.theme_type_variation = &"MenuValue"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_size_override("font_size", SUB_PT)
	sub.add_theme_constant_override("outline_size", 4)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_child(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left = 4
	sub.offset_right = -5
	sub.offset_top = 2
	sub.offset_bottom = 2 + float(SUB_PT) + 6.0

	# The second badge, top-LEFT, and empty on every screen but the receipt. Built
	# for all of them rather than only where it is used: `paint` writes cells that
	# already exist, and a node only some callers have is a `get_node` only some
	# callers survive.
	var tag := Label.new()
	tag.name = "Tag"
	tag.theme_type_variation = &"MenuSlotStat"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", SUB_PT)
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tag.offset_left = 5
	tag.offset_right = -4
	tag.offset_top = 2
	tag.offset_bottom = 2 + float(SUB_PT) + 6.0


## A rung on a ladder, or a repeatable sitting in a row of rungs. The stacked
## column the FULL cell used to be, kept whole for the shapes that still want it.
static func _build_stack(b: Button, shape: Size) -> void:
	b.custom_minimum_size = NAMED_SIZE if shape == Size.NAMED else COMPACT_SIZE
	# A ladder is measured by its rungs, and a cell that grew to fill the row
	# would put a hand's width between two steps of one ladder and make them look
	# like two ladders.
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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

	var chip := ColorRect.new()
	chip.name = "Chip"
	chip.custom_minimum_size = Vector2(0, 6)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip)

	var label := Label.new()
	label.name = "Name"
	label.theme_type_variation = &"MenuSlotStat"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", COMPACT_NAME_PT)
	col.add_child(label)

	var sub := Label.new()
	sub.name = "Sub"
	sub.theme_type_variation = &"MenuValue"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_size_override("font_size", COMPACT_SUB_PT)
	col.add_child(sub)


## Write `e` onto a cell made by `make`. An empty Dictionary is the empty slot.
static func paint(b: Button, e: Dictionary) -> void:
	if int(b.get_meta(&"cell_shape", int(Size.FULL))) == int(Size.FULL):
		_paint_tile(b, e)
	else:
		_paint_stack(b, e)


static func _paint_tile(b: Button, e: Dictionary) -> void:
	var edge := b.get_node("Edge") as Panel
	var art := b.get_node("Art") as TextureRect
	var name_label := b.get_node("Name") as Label
	var sub := b.get_node("Sub") as Label
	var tag := b.get_node("Tag") as Label

	tag.text = String(e.get("tag", ""))
	if e.is_empty():
		edge.add_theme_stylebox_override("panel", _frame(Color(Pal.ASH, 0.30)))
		art.visible = false
		name_label.text = EMPTY_LABEL
		name_label.modulate = Color(1, 1, 1, 0.4)
		sub.text = ""
		b.modulate = Color(1, 1, 1, 0.55)
		return

	var tint: Color = e.get("tint", Pal.ASH)
	edge.add_theme_stylebox_override("panel", _frame(tint))

	var art_path := String(e.get("icon", ""))
	art.texture = UiKit.resolve_icon(art_path) if not art_path.is_empty() else null
	art.visible = art.texture != null

	name_label.modulate = Color.WHITE
	# The diamond means "a counter in the garrison wants this, the vendor does
	# not". At tile size it is one bit of information and that is the bit that
	# matters: do not sell it. WHICH counter is the hover card's job.
	var text := String(e.get("label", ""))
	var prefix := ""
	if bool(e.get("mark", false)):
		prefix += "◆"
	if bool(e.get("star", false)):
		prefix += "★"
	name_label.text = (prefix + " " + text) if not prefix.is_empty() else text
	sub.text = String(e.get("sub", ""))
	sub.modulate = e.get("sub_tint", Color.WHITE)
	b.modulate = Color(1, 1, 1, 0.55) if bool(e.get("dim", false)) else Color.WHITE


static func _paint_stack(b: Button, e: Dictionary) -> void:
	var chip := b.get_node("Col/Chip") as ColorRect
	var name_label := b.get_node("Col/Name") as Label
	var sub := b.get_node("Col/Sub") as Label

	if e.is_empty():
		chip.color = Color(Pal.ASH, 0.35)
		name_label.text = EMPTY_LABEL
		name_label.modulate = Color(1, 1, 1, 0.4)
		sub.text = ""
		b.modulate = Color(1, 1, 1, 0.55)
		return

	chip.color = e.get("tint", Pal.ASH)
	name_label.modulate = Color.WHITE
	var text := String(e.get("label", ""))
	var prefix := ""
	if bool(e.get("mark", false)):
		prefix += "◆ "
	if bool(e.get("star", false)):
		prefix += "★ "
	name_label.text = prefix + text
	sub.text = String(e.get("sub", ""))
	sub.modulate = e.get("sub_tint", Color.WHITE)
	b.modulate = Color(1, 1, 1, 0.55) if bool(e.get("dim", false)) else Color.WHITE


## The tint frame around a tile: the item's own hue as a hairline box with
## nothing inside it.
##
## Transparent fill and NOT a tinted one. The plate under it is the `MenuSlot`
## variation's, and that plate is what changes on hover, on focus and on a press;
## a filled overlay would sit on top of every one of those and the tile would
## stop answering the cursor.
static func _frame(tint: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = tint
	sb.set_border_width_all(TILE_EDGE_PX)
	sb.set_corner_radius_all(UITheme.RADIUS)
	sb.anti_aliasing = false
	return sb
