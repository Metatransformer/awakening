class_name LootItem
extends Resource
## One kind of dungeon ingredient. See docs/METAGAME.md §4.
##
## An ingredient is deliberately BOTH money and power: `sell_value` is what the
## vendor pays, and the same item id appears in the smith's recipes. That double
## use is the whole economy — you never sell something without also declining to
## forge with it.

@export var id: StringName = &""
@export var display_name: String = ""
## What the vendor pays for one. The only gold faucet in the game.
@export var sell_value: int = 1
## How many fit in one bag slot. Rarer things stack shallower, so a good haul
## costs more slots — bag pressure scales with how well the run went.
@export var max_stack: int = 9
## Depth band this drops in (1..3). Authoring-time, never scaled to the player.
@export var band: int = 1
## Drives the pickup mesh and the UI swatch. These are the only art an
## ingredient has, so the colours must be distinguishable at a glance in a dark
## room — that is a readability requirement, not decoration.
@export var color: Color = Color.WHITE
@export var description: String = ""


static func make(p_id: StringName, p_name: String, p_sell: int, p_stack: int,
		p_band: int, p_color: Color, p_desc: String) -> LootItem:
	var it := LootItem.new()
	it.id = p_id
	it.display_name = p_name
	it.sell_value = p_sell
	it.max_stack = p_stack
	it.band = p_band
	it.color = p_color
	it.description = p_desc
	return it
