class_name MenuPaperDoll
extends VBoxContainer
## The hero, and what he is wearing, on one card.
##
##   compact (INVENTORY)            full (EQUIP)
##     ┌──────────────┐             ┌────────────────────────┐
##     │   ▟█▙        │             │        ▟█▙             │
##     │  ▟███▙  doll │             │       ▟███▙   doll     │
##     ├──────────────┤             ├───────────┬────────────┤
##     │▌ LEFT   Kite │             │▌ CHEST    │   AMULET  ▐│
##     │▌ RIGHT  Bow  │             │▌ ARMS     │   RING I  ▐│
##     │▌ ITEM   Red  │             │▌ LEGS     │   RING II ▐│
##     └──────────────┘             │▌ BOOTS    │  BRACELET ▐│
##                                  └───────────┴────────────┘
##
## **It is read-only, deliberately.** Changing a hand is the EQUIP screen's job
## and the D-pad's, and there is exactly one of each in this game -- a second
## place to equip would be a second `cycle_armament` caller to keep honest, which
## is the drift `ArmamentDb`'s header is about. Nothing here takes focus, so the
## focus loops both host screens build are untouched by the column appearing.
##
## ## Why the figure is the real hero now, and not a drawn one
##
## This was a `_draw()` of a stick figure, and the argument for it was that a
## SubViewport costs a second camera, a second light and an animation to freeze
## for a card that has to read at a glance. All three of those are true and all
## three are cheap: `DollStage` pays them once, renders only while its parent is
## visible, and what you get back is the character the player has been looking at
## for the whole run instead of a grey pictogram of him.
##
## The one thing the drawn doll did better was the LEADER LINES -- a wire from
## the CHEST plate to the figure's chest. Those do not survive a rendered body:
## a line ending on a shoulder that moves with the idle reads as a line that
## missed. What replaces them is order (see `SlotTile`): the armour column runs
## down the body, the jewel column runs in `Game.JEWEL_SLOTS` order.
##
## **Two sizes of the same doll, and only one doll.** A second paper doll is
## exactly the duplication CLAUDE.md §0 is about -- the two would agree on the
## day they were written and disagree by the second time a slot was added.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const UiKitScript := preload("res://scripts/ui/kit/ui_kit.gd")
const SlotTileScript := preload("res://scripts/ui/kit/slot_tile.gd")
const DollStageScript := preload("res://scripts/ui/kit/doll_stage.gd")

## `full` off is the pouch's card: the figure, the two hands, the bound bottle.
## `full` on is the equipment screen's: the figure with the eight worn slots
## under it, armour on the left and the jewelcrafter's work on the right.
##
## Read in `_ready`, so set it BEFORE `add_child`.
var full: bool = false

## The compact card's floor. 144 px is what the pouch's column is (its `DOLL_W`)
## and the three hand tiles are what sets the height.
const MIN_SIZE := Vector2(132, 300)
## The full card's floor. The equipment screen's `DOLL_W` is 284 and cannot grow
## -- the two hand cards beside it are a measured 228 each and the detail column
## is 360, inside a 1220 frame.
const FULL_MIN_SIZE := Vector2(268, 372)
## How tall the stage is before the tiles get the rest. Enough that a 1.65 m
## figure is a figure and not a token; the tiles are the information.
const STAGE_H := 200.0
const COMPACT_STAGE_H := 150.0

## The left column, top to bottom: the armour, in the order it is worn down the
## body. `ShopDb.groups()` puts the smith's board in this same order, so a player
## going from the counter to this screen finds the rows where they left them.
const ARMOUR: Array[StringName] = [&"chest", &"arms", &"legs", &"boots"]
## The right column: her four, in `Game.JEWEL_SLOTS` order.
const JEWELS: Array[StringName] = [&"amulet", &"ring1", &"ring2", &"bracelet"]
## Short enough for a 130 px tile. "SECOND RING" is not, and `JewelDb.BLANKS`
## has it at that length because a shop row has a whole line to spend.
const SLOT_NAMES := {
	&"chest": "CHEST", &"arms": "ARMS", &"legs": "LEGS", &"boots": "BOOTS",
	&"amulet": "AMULET", &"ring1": "RING I", &"ring2": "RING II",
	&"bracelet": "BRACELET",
}

var _stage: DollStage
## Slot key -> the tile drawing it. Rebuilt only when the SET of slots changes,
## which is never — so `_paint` edits the tiles in place rather than clearing the
## column, and a repaint cannot steal focus or reflow the card.
var _tiles: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = FULL_MIN_SIZE if full else MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)

	_stage = DollStageScript.new()
	_stage.custom_minimum_size.y = STAGE_H if full else COMPACT_STAGE_H
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage)
	# Mounted after the stage is in the tree: the rig's AABB is measured through
	# global transforms, and a rig parented to a detached viewport has none.
	_stage.mount(DollStageScript.hero_rig())

	if full:
		_build_worn()
	else:
		_build_hands()
	_paint()

	# The three things that can change what is drawn here, and the only three.
	# The world is paused behind this screen, so there is nothing to poll for --
	# but the EQUIP tab is two presses away (↑ onto the strip, then ←/→) and a
	# hand changed there has to be on the card when the player pages back.
	Bus.loadout_changed.connect(
		func(_s: int, _r: StringName, _l: StringName) -> void: _paint())
	Bus.bottles_changed.connect(func(_c: Array) -> void: _paint())
	Bus.item_selected_changed.connect(func(_i: int) -> void: _paint())
	# The eight worn slots only ever change at a counter, and a counter is a
	# different screen -- but the menu is not torn down between the two, so the
	# card has to hear about it rather than repaint on open.
	if full:
		Bus.item_acquired.connect(func(_id: StringName) -> void: _paint())


# --- construction --------------------------------------------------------------

## The eight worn slots, as two columns under the figure.
##
## A GridContainer and not two VBoxes: the two columns have to share a baseline
## row by row, or CHEST and AMULET drift apart the moment one of them wraps, and
## a doll whose two sides are half a tile out reads as a layout bug.
func _build_worn() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	for i in ARMOUR.size():
		_tiles[ARMOUR[i]] = _tile(grid, ARMOUR[i], false)
		_tiles[JEWELS[i]] = _tile(grid, JEWELS[i], true)


## The two hands and the bound bottle. They are the part of your kit that costs
## no bag slot, which is why they are on the figure and not in the grid.
func _build_hands() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	for key: StringName in [&"left", &"right", &"item"]:
		_tiles[key] = SlotTileScript.build(col, {"caption": _hand_caption(key)})


static func _hand_caption(key: StringName) -> String:
	match key:
		&"left": return "LEFT HAND"
		&"right": return "RIGHT HAND"
		_: return "ITEM"


func _tile(parent: Node, slot: StringName, jewel: bool) -> Button:
	return SlotTileScript.build(parent, {
		"caption": String(SLOT_NAMES.get(slot, slot)),
		"icon": UiKitScript.worn_icon(slot),
		"mirror": jewel,
		"pips": Vector2i(0, K.JEWEL_MAX if jewel else K.FORGE_MAX),
	})


# --- painting -------------------------------------------------------------------

## Repaint from `Game`. The card does this for itself on every signal that can
## change it; a host screen only needs to call it on open, before any of those
## have fired.
func repaint() -> void:
	_paint()


func _paint() -> void:
	if _tiles.is_empty():
		return
	if full:
		for i in ARMOUR.size():
			_paint_worn(ARMOUR[i], false)
			_paint_worn(JEWELS[i], true)
		return
	_paint_hand(&"left", Game.armament(Game.HAND_LEFT))
	_paint_hand(&"right", Game.armament(Game.HAND_RIGHT))
	var potion := Game.selected_potion()
	SlotTileScript.repaint(_tiles.get(&"item"), {
		"value": PotionDb.name_of(potion) if potion != &"" else "",
		"edge": PotionDb.tint_of(potion) if potion != &"" else null,
		"icon": UiKitScript.action_icon("bottle"),
	})


func _paint_hand(key: StringName, id: StringName) -> void:
	SlotTileScript.repaint(_tiles.get(key), {
		# `slot_name`, not `name_of`: this column is 132 px wide and the tile has
		# one line for it.
		"value": ArmamentDb.slot_name(id) if id != &"" else "",
		"icon": ArmamentDb.icon(id),
	})


## One worn slot's three facts: which path it committed to, how far up that path
## it is, and — by the tile still being drawn at all — that it exists.
func _paint_worn(slot: StringName, jewel: bool) -> void:
	var paths: Array = JewelDb.PATHS[slot] if jewel \
		else [Game.PLATE_HEAVY, Game.PLATE_LIGHT]
	var rungs: int = K.JEWEL_MAX if jewel else K.FORGE_MAX
	# "Which path did this commit to" is not stored anywhere -- it is answered by
	# asking which of the two siblings has a rung in it (game_state.gd's note over
	# PLATE_PIECES). One reader of that rule per screen; this is this screen's.
	var path: StringName = &""
	var level := 0
	for p: StringName in paths:
		var track: StringName = Game.jewel_track(slot, p) if jewel \
			else Game.plate_track(slot, p)
		var n: int = Game.jewel_level(track) if jewel else Game.forge_level(track)
		if n > 0:
			path = p
			level = n
			break

	var tag := ""
	if level > 0:
		tag = String(JewelDb.PATH_INFO[path]["label"]) if jewel \
			else String(path).to_upper()
	SlotTileScript.repaint(_tiles.get(slot), {
		"value": tag,
		"pips": Vector2i(level, rungs),
	})
