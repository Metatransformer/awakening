class_name ItemDef
extends RefCounted
## One kind of thing you can carry, sell, or craft with.
##
## A plain RefCounted rather than a Resource: these are authored in code in
## ItemDb, there is no editor workflow that would benefit from .tres files, and
## a dictionary of RefCounteds is far easier to diff in a pull request than
## thirty binary resources. Promote to Resource the day a designer needs to add
## an item without touching GDScript.
##
## `value` is the base price the vendor pays. Everything else in the economy is
## derived from it -- the shop marks up, the extraction fee is a fraction of the
## bag -- so it is the one number that matters when balancing.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: StringName
var display_name: String
## Base sale price in gold. What the vendor pays, before any haggling.
var value: int
var rarity: Rarity
## How many fit in one bag slot. Bag pressure is the whole game, so this is a
## real balance lever, not bookkeeping.
var stack: int
## Drawn in the HUD bag and the shop list. PSX-era UI leans on colour to carry
## category because there is no room for icons at 320x240.
var tint: Color
## One line the vendor screen shows. Flavour, but it is also the only place the
## player learns what an ingredient is for.
var blurb: String


static func make(p_id: StringName, p_name: String, p_value: int,
		p_rarity: Rarity, p_stack: int, p_tint: Color, p_blurb: String) -> ItemDef:
	var d := ItemDef.new()
	d.id = p_id
	d.display_name = p_name
	d.value = p_value
	d.rarity = p_rarity
	d.stack = p_stack
	d.tint = p_tint
	d.blurb = p_blurb
	return d


func rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		_: return "Common"
