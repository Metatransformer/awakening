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

## What the thing is FOR, which is the only question the economy asks of it.
##
##  * `INGREDIENT` is merchandise. It exists to be sold; its `value` is the point.
##  * `COMPONENT` is material. A bench eats it -- the forge (ShopDb) or the
##    alchemist (AlchemyDb) -- and extraction sorts it out of the bag into
##    `Game.components` instead of handing it to the vendor. It still has a
##    `value`, because the extraction fee is a share of what you are carrying and
##    a component you carried is something you carried.
##
## WHICH bench is `bench`, and it is a label rather than a second kind, because
## every rule that matters -- banked on extraction, lost on death, never sold --
## is the same for both. One catalogue, one drop path, one workbench.
##
## One catalogue, one drop path, one LootMote. The kind is a label on the row,
## not a second inventory: a component and a pearl compete for the same bag slot,
## and that competition IS the decision this whole system exists to create.
enum Kind { INGREDIENT, COMPONENT }

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
var kind: Kind = Kind.INGREDIENT
## Who wants it, for COMPONENTs only: `&"forge"` or `&"alchemy"`. Nothing
## branches on this except the words a screen prints -- the pouch's caption and
## the counter it sends you to. A material the wrong counter refused would be a
## rule; this is a signpost.
var bench: StringName = BENCH_FORGE

const BENCH_FORGE := &"forge"
const BENCH_ALCHEMY := &"alchemy"


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


## Same fields, different kind. A separate constructor rather than an eighth
## positional argument, so the catalogue reads as two lists and a reader can see
## at a glance which rows the forge cares about.
static func part(p_id: StringName, p_name: String, p_value: int,
		p_rarity: Rarity, p_stack: int, p_tint: Color, p_blurb: String) -> ItemDef:
	var d := make(p_id, p_name, p_value, p_rarity, p_stack, p_tint, p_blurb)
	d.kind = Kind.COMPONENT
	return d


## Same again, for the counter that brews rather than the one that hammers.
static func brew(p_id: StringName, p_name: String, p_value: int,
		p_rarity: Rarity, p_stack: int, p_tint: Color, p_blurb: String) -> ItemDef:
	var d := part(p_id, p_name, p_value, p_rarity, p_stack, p_tint, p_blurb)
	d.bench = BENCH_ALCHEMY
	return d


func is_component() -> bool:
	return kind == Kind.COMPONENT


## "THE FORGE" / "THE ALCHEMIST", for a screen that has to tell the player where
## to take the thing. Empty for merchandise, which goes to the vendor.
func bench_name() -> String:
	if not is_component():
		return ""
	return "THE ALCHEMIST" if bench == BENCH_ALCHEMY else "THE FORGE"


## The short tag a recipe column uses: "GRIT", "PLATE", "CORE". A forge row has
## to name two or three components inside a third of a shop row, and "Whetstone
## Grit x10" does not fit anywhere the eye can run down it.
##
## The LAST WORD of the display name, and the four component names are chosen so
## that last word is unique across the catalogue. If a fifth component ever ends
## in a word one of these already uses, give this an explicit table rather than
## renaming the thing to suit the UI.
func code() -> String:
	var words := display_name.split(" ", false)
	return (words[words.size() - 1] if words.size() > 0 else display_name).to_upper()


func rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		_: return "Common"
