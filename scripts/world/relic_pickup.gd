class_name RelicPickup
extends RefCounted
## How a relic leaves a deep chest, a vault or a boss's body and gets into the
## bag.
##
## **It is a `LootMote` and nothing else.** That is the whole design decision in
## this file, and it is worth writing down because "the unique object needs its
## own pickup" is the obvious wrong answer: everything a relic pickup has to do
## on the floor, an ingredient mote already does, and the one behaviour that
## matters most -- *refusing VISIBLY on a full bag* (docs/GDD.md pillar 3) -- is
## the one that would have been reimplemented worst. `LootMote._try_take` calls
## `Run.collect`, and when the bag has no slot it sets `_refused` and the thing
## on the floor pulses RUST instead of vanishing. A second pickup class would
## have had to grow that pulse a second time, and the second copy is where "the
## relic disappeared and I never got it" comes from.
##
## So this is a PLACER, not a node. Three things it adds over calling
## `LootMote.drop` directly, and there are only three:
##
##  1. **It asks whether the relic is still down there.** `RelicDb.outstanding()`
##     is false once the thing is in your hand or in the Society's ledger, and a
##     room that placed one anyway would mint a second copy of an object there is
##     one of. A floor calls `place()` unconditionally and gets nothing back when
##     the relic is already gone -- which is also the whole of "a relic lost on
##     death goes back where it came from": nothing was written on death, so this
##     answers true again and the room puts it back with no code.
##  2. **It takes the heat off.** `LootMote.drop` stamps `Heat.multiplier()` at
##     the drop, which is right for merchandise and wrong here: there is no such
##     thing as a hot relic, the vendor pays nothing for one, and a premium
##     banked against it would be heat the bag never earned. `Run.bank_relics`
##     says this out loud on the other side of the trip.
##  3. **It reads the floor manifest**, so a room says "put whatever is in my
##     vault here" rather than naming a relic twice (`FloorDb` owns where a
##     relic lies, `RelicDb` owns what it does).
##
## No `_ready`, no scene, no `.tscn`. If this file ever grows a node, check that
## what you are adding is not already on `LootMote`.

## Drop the relic `id` at `at`, or nothing if it is not down there any more.
##
## Returns the mote so a caller can hold onto it (a chest that wants to fling it,
## a director that wants to check it is still lying there after a refusal), and
## `null` for every reason it did not place: not one of the twelve, already in
## the bag, already donated.
static func place(parent: Node, id: StringName, at: Vector3,
		fling: Vector3 = Vector3.ZERO) -> LootMote:
	if not RelicDb.outstanding(id):
		return null
	var mote := LootMote.drop(parent, id, at, fling)
	# See (2) above. Written after `drop` rather than passed in, because `drop`
	# is the merchandise path and giving it a "this one is cold" argument would
	# put a relic-shaped hole in a function that has nothing to do with relics.
	mote.heat_mult = 1.0
	return mote


## "Put whatever floor `level` keeps behind `slot` here." The call an anchor
## actually wants: a deep chest asks once, and a floor with no relic behind that
## anchor places nothing rather than having to know how many relics it has.
##
## `slot` is a `FloorDb` anchor id (`&"deep_chest"`, `&"vault"`, `&"boss"`),
## which is the same vocabulary `RelicDb.SOURCE_*` uses -- deliberately, so the
## manifest and the catalogue cannot drift into two names for one hole.
static func place_anchor(parent: Node, level: int, slot: StringName, at: Vector3,
		fling: Vector3 = Vector3.ZERO) -> LootMote:
	var id := FloorDb.relic_in(level, slot)
	if id == &"":
		return null
	return place(parent, id, at, fling)


## Is there a relic waiting behind this anchor right now? What a chest asks
## before it decides whether it is the interesting chest -- and what the
## Sounding-Rod's hum will read once `chest_hums()` is wired into the chest
## (see the NEEDS note in this file's report).
static func pending(level: int, slot: StringName) -> bool:
	return RelicDb.outstanding(FloorDb.relic_in(level, slot))
