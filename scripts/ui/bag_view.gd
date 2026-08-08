class_name BagView
extends Control
## The dungeon bag, drawn as a row of slots.
##
## Slot COUNT is the whole tension of a run (docs/METAGAME.md §5), so the empty
## slots are drawn as loudly as the full ones — the player needs to read "two
## left" at a glance, mid-fight, without opening anything.
##
## The first K.BELT_SLOTS are outlined in gold: those are what survives death,
## and if that distinction is not visible the death rule is just a cruel
## surprise instead of a decision about what to put where.

const SLOT := 40.0
const GAP := 4.0

const BG := Color(0.07, 0.07, 0.09, 0.82)
const BORDER := Color(0.35, 0.33, 0.30, 0.9)
const BELT_BORDER := Color(0.92, 0.76, 0.30, 0.95)

var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var n: int = Game.bag.size() if Game.bag != null else K.BAG_SLOTS
	custom_minimum_size = Vector2(n * (SLOT + GAP), SLOT + 18.0)
	Bus.bag_changed.connect(queue_redraw)


func _draw() -> void:
	if Game.bag == null:
		return
	for i in Game.bag.size():
		var at := Vector2(i * (SLOT + GAP), 14.0)
		var box := Rect2(at, Vector2(SLOT, SLOT))
		var belt := Game.bag.is_belt(i)
		draw_rect(box, BG, true)
		draw_rect(box, BELT_BORDER if belt else BORDER, false, 2.0 if belt else 1.0)

		if belt:
			draw_string(_font, at + Vector2(1, -2), "BELT",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BELT_BORDER)

		if Game.bag.is_empty_at(i):
			continue

		var id := Game.bag.id_at(i)
		var n := Game.bag.count_at(i)
		var swatch := box.grow(-7.0)
		draw_rect(swatch, LootDB.color_of(id), true)
		draw_rect(swatch, Color(0, 0, 0, 0.5), false, 1.0)
		draw_string(_font, at + Vector2(3.0, SLOT - 3.0), str(n),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
