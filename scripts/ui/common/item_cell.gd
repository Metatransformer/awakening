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
## the top, the name under it, and one line saying whatever this screen is about.
## That chip is the same colour the mote on the floor glowed and the same colour
## the name prints in everywhere else: one hue per thing, across every screen, is
## the only icon set this game has.

## What a cell can say. Keys, all optional except `label`:
##
##   label   String      the name, drawn big and wrapped
##   sub     String      the line under it — "×6", "120 ◇", "2/4", "✓"
##   tint    Color       the chip across the top
##   mark    bool        prefix the label with ◆
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
	# The diamond means "a counter in town wants this, the vendor does not". At
	# cell size it is one bit of information and that is the bit that matters:
	# do not sell it. WHICH counter is the detail pane's job.
	var text := String(e.get("label", ""))
	name_label.text = ("◆ " + text) if bool(e.get("mark", false)) else text
	sub.text = String(e.get("sub", ""))
	sub.modulate = e.get("sub_tint", Color.WHITE)
	b.modulate = Color(1, 1, 1, 0.55) if bool(e.get("dim", false)) else Color.WHITE
