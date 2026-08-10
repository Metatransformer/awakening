class_name Fletching
extends RefCounted
## Arrows, made underground out of what the floor already gave you.
##
## The smith still sells arrows for gold and that line is not going anywhere.
## This is the other half of the same problem and it is the half that mattered:
## running dry on floor six with a full bag used to mean the bow was a decoration
## until you extracted, and "go home to reload" is not a decision, it is a walk.
##
## ## Why it costs ingredients and not gold
##
## The recipe eats the two commonest things on the enemy table -- the two you
## have the most of and the two you were least glad to see land. So the trade the
## player is actually offered is *the floor of my bag, for shots*, which is the
## extraction fee's question (slots against worth) pointed at a second resource,
## and it finally gives the bottom of the drop table a job. A Bone Shard that can
## become an arrow is no longer only 4 gold of dead weight.
##
## It also runs the right way round: fletching FREES slots. A bag that is one
## stack from full and a quiver that is empty are the same problem now, and they
## solve each other.
##
## ## Priced above the shop, on purpose
##
## 24 gold of ingredients for 5 arrows is 4.8 gold a shot; the smith's ARROWS X10
## is 4.0. Convenience underground is the thing being sold, so it costs more. A
## recipe that undercut the shop would kill the shop line, and the shop line is
## what a player with a purse and an empty bag is supposed to reach for.
##
## Lives on the POUCH screen next to the escape rope, because both are verbs
## the bag can perform on itself and neither is something you hold.

## What one batch costs, out of the bag. Both are COMMON on `ItemDb.ENEMY_DROPS`
## (weights 18 and 34) and neither is a component, so fletching never competes
## with the forge for material -- the smith's ladders and the quiver eat from
## different ends of the same table, which is what keeps either from being the
## obvious thing to do with a pull. [tune]
const RECIPE := {
	&"cracked_flint": 2,  # the heads
	&"bone_shard": 2,     # the shafts
}
## Arrows per batch, before the Fletcher's Jig is on the bench. Half a shop
## bundle: enough to change the next fight, not enough that one bag makes the
## smith irrelevant. [tune]
##
## **Read `batch()`, not this.** The constant is the un-donated number and the
## function is what the bench actually cuts.
const BATCH := 5


## Arrows one batch yields right now.
##
## `RelicDb.fletch_yield()` hands `BATCH` straight back until the Fletcher's Jig
## is in the Society's ledger, and 7 after (GDD §6.2, relic 6) -- so this is the
## unlock adopted with no branch, and there is exactly one place in the codebase
## that knows the jig exists. A caller that wrote `if RelicDb.donated(...)`
## would be the unlock implemented twice, and the next tuning pass would move
## only one of them.
##
## Public because the pouch prints the yield next to the button: what the recipe
## PAYS OUT is part of the price, and a screen that says 5 over a bench that cuts
## 7 is the shop lying about its own numbers.
static func batch() -> int:
	return RelicDb.fletch_yield(BATCH)


## What you are short, id -> how many more. Empty means the bag can pay.
## Returned rather than a bool so the screen can say WHICH thing is missing --
## "you need two more Cracked Flint" is an instruction and "you cannot" is not.
static func short() -> Dictionary:
	var out: Dictionary[StringName, int] = {}
	for id: StringName in RECIPE:
		var need: int = RECIPE[id]
		var have: int = Run.bag.get(id, 0)
		if have < need:
			out[id] = need - have
	return out


## Room left in the quiver. `Game.max_arrows` is bought, so this grows.
static func quiver_room() -> int:
	return maxi(0, Game.max_arrows - Game.arrows)


static func can_fletch() -> bool:
	return short().is_empty() and quiver_room() > 0


## Make one batch. Returns the arrows that actually landed, or 0 if it refused.
##
## A partial batch is honest and deliberate: with three arrows of room left you
## still pay the full recipe and still get three, because the alternative is
## either refusing a player who asked for arrows or inventing a fractional cost.
## The screen says how many will land before the press, so nobody is surprised.
##
## Ingredients come out BEFORE the arrows go in, and the whole thing is checked
## first: a fletch that half-succeeded would be a bag that paid for nothing.
static func fletch() -> int:
	if not can_fletch():
		return 0
	for id: StringName in RECIPE:
		var need: int = RECIPE[id]
		if Run.consume(id, need) < need:
			# Unreachable while `short()` is the gate above, and loud rather than
			# silent if that ever stops being true -- a bag that was charged for a
			# batch it did not get is the one failure here nobody would notice.
			push_error("Fletching: bag was short on '%s' after can_fletch() passed" % id)
			return 0
	var made := mini(batch(), quiver_room())
	Game.add_arrows(made)
	return made


## The recipe as a sentence, with what you are carrying against what it wants.
## "2/2 Cracked Flint + 0/2 Bone Shard" -- one line that is both the price and
## the reason the button is going to refuse.
static func cost_line() -> String:
	var parts: Array[String] = []
	for id: StringName in RECIPE:
		var need: int = RECIPE[id]
		var def := ItemDb.get_def(id)
		var label: String = def.display_name if def != null else String(id)
		parts.append("%d/%d %s" % [mini(Run.bag.get(id, 0), need), need, label])
	return "  +  ".join(parts)


## Why it will not fletch, or "" when it will. The screen prints this instead of
## greying the row out: a disabled control says you cannot and never says what to
## do about it, and here there is always something to do about it.
static func refusal() -> String:
	if quiver_room() <= 0:
		return "The quiver is full. %d is all it holds." % Game.max_arrows
	var lack := short()
	if lack.is_empty():
		return ""
	var parts: Array[String] = []
	for id: StringName in lack:
		var def := ItemDb.get_def(id)
		var label: String = def.display_name if def != null else String(id)
		parts.append("%d more %s" % [int(lack[id]), label])
	return "You need " + " and ".join(parts) + "."
