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
## The look is not negotiable per caller. The item's own `tint` as a chip across
## the top, the glyph under it, the name under that, and one line saying whatever
## this screen is about. That chip is the same colour the mote on the floor glowed
## and the same colour the name prints in everywhere else: one hue per thing,
## across every screen.
##
## **The chip did not go when the glyphs arrived, and that is deliberate.** This
## header used to end "one hue per thing is the only icon set this game has", and
## card #118 gave the catalogue real art -- but `icon_crunch.posterise` keeps
## LUMINANCE and throws hue away, so the ramp cannot draw the difference between a
## green agate and a blue sapphire. The prompts answer half of that by asking for
## the four stones by CUT; the chip answers the other half. The glyph says what
## KIND of thing it is and the chip says WHICH, and neither is doing the other's
## job.

## What a cell can say. Keys, all optional except `label`:
##
##   label   String      the name, drawn big and wrapped
##   sub     String      the line under it — "×6", "120 ◇", "2/4", "✓"
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

const SIZE := Vector2(140, 88)
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

## Cell text is smaller than the theme's Label default. A cell is 140 px wide and
## half these names are two words; at 18 pt they wrapped to three lines and shoved
## the sub-line out through the bottom border.
const NAME_PT := 16
const SUB_PT := 18
const COMPACT_NAME_PT := 17
const COMPACT_SUB_PT := 14

## The glyph, in a FULL cell only. A rung carries a numeral and a price in 62 px
## of height and has no room for a picture; a bag stack has 88 px and its picture
## is the fastest thing on the cell to read.
const ICON_PX := 30

## The empty cell's label. An empty slot is DIMMED, never hidden — a grid that
## shrank as you spent would stop being a picture of your capacity, which is the
## whole reason the bag is drawn this way (docs/METAGAME.md §3).
const EMPTY_LABEL := "—"


## A blank cell, parented nowhere.
static func make(shape: Size = Size.FULL) -> Button:
	var compact := shape != Size.FULL
	var b := Button.new()
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	match shape:
		Size.RUNG: b.custom_minimum_size = COMPACT_SIZE
		Size.NAMED: b.custom_minimum_size = NAMED_SIZE
		_: b.custom_minimum_size = SIZE
	# Only the grid's cells stretch. A ladder is measured by its rungs and a cell
	# that grew to fill the row would put a hand's width between two steps of one
	# ladder and make them look like two ladders.
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if compact \
		else Control.SIZE_EXPAND_FILL

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
	chip.custom_minimum_size = Vector2(0, 6 if compact else 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip)

	# Built for every shape and hidden on the compact ones, rather than built
	# conditionally: `paint` is called on cells that already exist, so a node
	# that only some shapes have is a `get_node` that only some shapes survive.
	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.focus_mode = Control.FOCUS_NONE
	art.visible = false
	col.add_child(art)

	var label := Label.new()
	label.name = "Name"
	label.theme_type_variation = &"MenuSlotStat"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",
		COMPACT_NAME_PT if compact else NAME_PT)
	col.add_child(label)

	var sub := Label.new()
	sub.name = "Sub"
	sub.theme_type_variation = &"MenuValue"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_size_override("font_size",
		COMPACT_SUB_PT if compact else SUB_PT)
	col.add_child(sub)
	return b


## Write `e` onto a cell made by `make`. An empty Dictionary is the empty slot.
static func paint(b: Button, e: Dictionary) -> void:
	var chip := b.get_node("Col/Chip") as ColorRect
	var art := b.get_node("Col/Art") as TextureRect
	var name_label := b.get_node("Col/Name") as Label
	var sub := b.get_node("Col/Sub") as Label

	if e.is_empty():
		chip.color = Color(Pal.ASH, 0.35)
		art.visible = false
		name_label.text = EMPTY_LABEL
		name_label.modulate = Color(1, 1, 1, 0.4)
		sub.text = ""
		b.modulate = Color(1, 1, 1, 0.55)
		return

	# The glyph is a FULL cell's, and `b.custom_minimum_size` is what says which
	# shape this is — reading the node we built rather than a flag the caller
	# might not have passed, so a compact cell handed an icon quietly drops it
	# instead of squeezing a picture in on top of its numeral.
	var art_path := String(e.get("icon", ""))
	var full := b.custom_minimum_size == SIZE
	art.texture = UiKit.resolve_icon(art_path) if (full and not art_path.is_empty()) else null
	art.visible = art.texture != null

	chip.color = e.get("tint", Pal.ASH)
	name_label.modulate = Color.WHITE
	# The diamond means "a counter in the garrison wants this, the vendor does
	# not". At cell size it is one bit of information and that is the bit that
	# matters: do not sell it. WHICH counter is the detail pane's job.
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
