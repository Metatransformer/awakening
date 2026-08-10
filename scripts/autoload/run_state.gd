extends Node
## Autoload `Run`. What you are carrying right now, and what happens to it.
##
## This is the whole game in one file. Everything else -- the dungeon, the
## enemies, the vendor -- exists to move numbers through here.
##
## The loop:
##   enter()    you go down with an empty bag
##   collect()  drops and chests fill it
##   extract()  you pay a fee, get your health back, and keep the bag
##   die()      you keep nothing
##
## Why the fee scales with the bag rather than being flat: a flat fee is free
## insurance on a good run and a punishment on a bad one, so it makes the
## interesting decision (a rich bag deep in) the EASY one. Scaling it means the
## richer the bag, the more leaving costs, and the more staying is worth. That
## tension is the game.
##
## Gold lives in Game (it survives death and is the metagame currency). The bag
## lives here (it does not).

## id -> count. Never negative, never zero-valued -- an emptied entry is erased.
var bag: Dictionary[StringName, int] = {}
## True between enter() and extract()/die(). The extraction affordance, the
## death rule and the vendor all gate on it.
var in_dungeon: bool = false
## How deep. Room count since entering; drives drop quality and the fee.
var depth: int = 0
## Which floor of the Lower Worlds you are standing on. 1-based, and it does NOT
## reset between floors -- taking the stair down keeps the bag and raises this,
## which is the whole of the endless curve as far as the rest of the game is
## concerned (see Prog). It resets when the run ends, either way it ends.
##
## Separate from `depth` on purpose. `depth` is how far into THIS floor you have
## walked and is what the extraction fee reads; `level` is how many floors you
## have committed to and is what the monsters and the drop tables read. Folding
## them into one number would mean walking a long floor made the monsters
## stronger, which is a curve nobody chose.
var level: int = 1
## Gold earned ABOVE base value by sweeping loot while the chain was lit. See
## Heat. It rides with the bag and dies with it, and `bag_value()` folds it in --
## which is what makes the extraction fee rise on a hot run without a single line
## of fee code knowing that heat exists.
##
## A pot rather than a per-item stamp because the bag is `id -> count`, and
## keying it by (id, tier) instead would double the width of every loop that
## touches it to buy a distinction the player never makes. What the player
## compares is value PER SLOT, and a pot preserves that arithmetic exactly.
var premium: int = 0
## Monsters killed since `enter()`. Per RUN and not per floor: the stair keeps
## the bag, so it keeps the tally that sits next to the bag on the ending screen.
var kills: int = 0
## Name of whatever last hit the hero, stamped by `Hero.take_hit` off `Hit.source`
## and read once by `die()`. Empty until something connects.
##
## Here rather than on the hero because the hero is destroyed by the very scene
## change the ending screen is about to make, and this has to outlive him by
## exactly as long as it takes to say what he died to.
var last_attacker: StringName = &""
## What the run that just ended looked like, for `RunEndScreen`. Built by `die()`
## and `extract()` -- the only two functions that know -- because both of them
## then destroy the state it is made of: the bag is cleared, the components are
## moved to the bench, `level` goes back to 1. A screen that read `Run` directly
## would be reading the wreckage.
##
## Keys: extracted, contents, banked, value, premium, fee, kills, level, depth,
## killer. Empty before the first run ends.
var summary: Dictionary = {}
## Seeded per run so a dungeon can be replayed exactly.
var rng := RandomNumberGenerator.new()
var seed_used: int = 0

## Fraction of the bag's sale value the teleport costs. [tune]
const EXTRACT_RATE := 0.25
## Floor on the fee, so an empty-handed bail-out is not free. [tune]
const EXTRACT_MIN := 15


func _ready() -> void:
	reset()
	# The tally the ending screen prints. Counted here rather than read off Heat,
	# which has one too: Heat's is a CHAIN and it decays -- that is its whole job --
	# so it answers "how fast are you killing", never "how many did you kill".
	Bus.enemy_died.connect(_on_enemy_died)


func reset() -> void:
	bag.clear()
	premium = 0
	in_dungeon = false
	depth = 0
	level = 1
	kills = 0
	last_attacker = &""


func _on_enemy_died(_enemy: Node3D, _position: Vector3) -> void:
	if in_dungeon:
		kills += 1


# --- Entering and leaving ---------------------------------------------------

## Start a run. Pass a seed to replay one; 0 picks a fresh one and records it.
func enter(run_seed: int = 0) -> void:
	bag.clear()
	premium = 0
	depth = 0
	# Every run starts at the top. The Lower Worlds are not a save file you
	# resume -- what you keep between runs is gold and what gold bought, and if
	# a run could start on floor 7 the forge would be optional (docs/GDD.md §4).
	level = 1
	kills = 0
	last_attacker = &""
	summary = {}
	in_dungeon = true
	seed_used = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_used
	Bus.bag_changed.emit(bag, bag_value())
	Bus.run_started.emit(seed_used)
	Bus.level_changed.emit(level)


## Take the stair down. The bag comes with you and so does everything in it --
## that is the entire point, and it is what makes the stair a DECISION rather
## than a corridor: everything you are carrying is now riding on a harder floor.
##
## Not a new run. `enter()` would clear the bag, and the seed stays the one the
## run started with so the whole descent replays from a single number: the floor
## is generated from `floor_seed()`, which mixes in the level.
func descend_floor() -> void:
	if not in_dungeon:
		return
	level += 1
	# `depth` is per-floor -- how far into THIS floor you have walked. The fee
	# rides on the bag, which is untouched, so arriving on a new floor does not
	# make leaving cheaper.
	depth = 0
	Bus.level_changed.emit(level)


## The seed for the floor you are standing on. Same run seed plus same level
## always builds the same floor, so a bug two floors down is reproducible from
## the one number the run reports.
func floor_seed() -> int:
	return absi(seed_used + level * 2654435761) % 0x7fffffff


## Teleport out. Returns false only when there is no run to leave.
##
## **It cannot fail on money.** The fee is capped at the purse (`extract_charge`),
## so a toll bigger than your gold takes all of it and the rope still works. The
## old version refused, and refusing was the one outcome the design never wanted:
## the fee scales with the bag, so the player it stopped was the player holding
## the best run of the night, and it stopped them with no way to comply --
## nothing underground sells, and dying to clear the debt loses the bag the fee
## was charged for. See `extract_charge` for why the cap is the right shape.
func extract() -> bool:
	if not in_dungeon:
		return false
	var fee := extract_charge()

	Game.spend_gold(fee)
	in_dungeon = false
	# Snapshotted BEFORE the components leave, because the ending screen is a
	# receipt for the run and a component you carried out is the single best thing
	# on it. `bank_components` erases those lines from the bag, so a screen built
	# from the bag afterwards would list a haul with the best of it missing and no
	# hint that anything had gone anywhere.
	var carried := bag.duplicate()
	var carried_value := bag_value()
	# The fee was charged on the WHOLE bag, components included, and only then
	# are they sorted out of it. That order is the rule: you pay to carry a
	# component home exactly as you pay to carry a pearl home, so choosing the
	# component is a choice about slots and never a way to dodge the toll.
	var banked := bank_components()
	# The relics leave the bag after the toll too, and for the same reason: you pay
	# to carry the only one of these there is home exactly as you pay to carry a
	# pearl home. `bank_relics` is the moment a relic stops being a thing you can
	# lose (docs/GDD.md §3).
	var recovered := bank_relics()
	# Folded into `banked` so the receipt draws a relic as "TO THE BENCH" instead
	# of a gold figure. Those are the wrong three words for the Society's hall and
	# the right SENTENCE -- that column means "this line is not money", and a relic
	# priced in gold on the receipt is the exact lie GDD §6.3 forbids.
	banked.merge(recovered)
	_end_summary(true, carried, carried_value, banked, fee)
	# Same reason as in `die()`: the next run starts at the top, and until the
	# number says so the HUD in town is reporting a floor nobody is standing on.
	level = 1
	Bus.level_changed.emit(level)
	# Getting your health back is what makes extracting feel like relief rather
	# than retreat. It is also the only heal in the game, which is what stops a
	# player from grinding one room forever.
	Game.heal(Game.max_quarters)
	Bus.run_ended.emit(true, carried, carried_value)
	if not banked.is_empty():
		Bus.components_banked.emit(banked)
	return true


## Move every component out of the bag and onto the workbench. Returns what
## moved, so the arrival can say so.
##
## Ingredients are merchandise and components are material, and extraction is
## where the two part company: the vendor never sees a component and the forge
## never sees a pearl. One rule, applied once, at the one moment the bag stops
## being at risk -- which is also why `die()` does not call this. Components you
## were still carrying die with the bag, like everything else in it. That is not
## a punishment bolted on; it is the same sentence the bag has always served,
## and exempting the forge from it would quietly delete the reason to leave.
func bank_components() -> Dictionary:
	var moved: Dictionary[StringName, int] = {}
	# The premium's share has to be measured against the bag as it stands NOW --
	# `_premium_share` divides by `base_value()`, and by the time the components
	# are out of the bag that denominator is a different number. Measure first,
	# move second.
	var leaving := 0
	for id: StringName in bag:
		if not ItemDb.is_component(id):
			continue
		var def := ItemDb.get_def(id)
		if def != null:
			leaving += def.value * int(bag[id])
	if leaving <= 0:
		return moved
	var share := _premium_share(leaving)

	for id: StringName in bag.keys():
		if not ItemDb.is_component(id):
			continue
		var n: int = bag[id]
		moved[id] = n
		bag.erase(id)
		Game.add_component(id, n)

	# Heat is paid on what you sweep, and a component you swept hot was worth
	# more to carry. It banked as gold-equivalent nothing, so its share of the
	# pot leaves with it -- otherwise the remaining merchandise would carry heat
	# it never earned and the vendor would pay for it.
	premium = maxi(0, premium - share)
	Bus.bag_changed.emit(bag, bag_value())
	return moved


## Move every relic out of the bag and onto the Society's shelf. Returns what
## moved, so the receipt can say so.
##
## The mirror of `bank_components`, one floor up: a relic is neither merchandise
## nor material, so extraction is where it parts company with both. `RelicDb`
## keeps it as a flag rather than an inventory row (see its note on `recover`),
## which is why nothing is added anywhere here -- the id leaving the bag and the
## flag going up ARE the same event.
##
## No premium arithmetic, unlike `bank_components`. A relic never earned a share
## of the heat pot -- `RelicPickup` collects at 1.0 and there is no such thing as
## a hot relic -- and `_premium_share` already divides by the merchandise half of
## the bag, so taking the relic out leaves every other line's share exactly where
## it was.
func bank_relics() -> Dictionary:
	var moved: Dictionary[StringName, int] = {}
	for id: StringName in bag.keys():
		if not RelicDb.is_relic(id):
			continue
		moved[id] = int(bag[id])
		bag.erase(id)
		RelicDb.recover(id)
	if not moved.is_empty():
		Bus.bag_changed.emit(bag, bag_value())
	return moved


## The gold-weight of the relics in the bag right now.
##
## Public because three separate things have to subtract it and none of them
## should be summing the bag themselves: the vendor pays nothing for a relic, so
## every number that describes what the vendor would pay has this taken off it,
## while the number the ROPE reads (`bag_value`) keeps it. See `ItemDb.RELIC_TOLL`
## for why a relic weighs anything at all.
func relic_toll() -> int:
	var total := 0
	for id: StringName in bag:
		if not RelicDb.is_relic(id):
			continue
		var def := ItemDb.get_def(id)
		if def != null:
			total += def.value * int(bag[id])
	return total


## Die. The bag is gone; gold and anything bought with it survives.
##
## **A relic in the bag is NOT destroyed here** (docs/GDD.md §3). Nothing is set
## and nothing needs to be: the held flag was never raised, so `RelicDb.held()`
## and `donated()` both still answer false, which is precisely the state that
## means "still down there" -- `RelicPickup.place` reads it and puts the thing
## back in the room it was placed in the next time that floor is built. The sting
## is the walk. A permanently missable unique in a game that takes your bag would
## be a corrupt save rather than tension, and the way to guarantee that can never
## happen is for losing one to require no code at all.
func die() -> void:
	if not in_dungeon:
		return
	var lost := bag.duplicate()
	var lost_value := bag_value()
	_end_summary(false, lost, lost_value, {}, 0)
	bag.clear()
	# The heat premium dies with the bag it was earned into. It is the same
	# gold; there was never a second container.
	premium = 0
	in_dungeon = false
	depth = 0
	# Back to the top of the Lower Worlds, and it is reset HERE rather than left
	# for the next `enter()` to do. Between the two the player is standing in town
	# with the HUD still saying FLOOR 4, which is a floor nobody is on -- the run
	# that reached it is over and the next one starts at 1 by rule. The ending
	# screen has already been handed the number it needs (`_end_summary` above).
	level = 1
	Bus.level_changed.emit(level)
	# You wake up in town: broke, but alive. Leaving health at zero would mean
	# the next thing that touched you killed you again before you could sell.
	Game.heal(Game.max_quarters)
	Bus.bag_changed.emit(bag, 0)
	Bus.run_ended.emit(false, lost, lost_value)


## Freeze what the run looked like, for `RunEndScreen`.
##
## Called by `die()` and `extract()` as their FIRST act, before either starts
## dismantling the run -- the bag, the premium pot, the floor number and the
## in_dungeon flag are all about to change, and every one of them is on the
## receipt. The screen does not draw until a frame or two later (Flow holds on the
## killing blow first), by which point reading `Run` live would report the state of
## a player standing in town.
func _end_summary(extracted: bool, contents: Dictionary, value: int,
		banked: Dictionary, fee: int) -> void:
	summary = {
		"extracted": extracted,
		"contents": contents.duplicate(),
		# Which of those lines went to the bench rather than the vendor. Only ever
		# non-empty on an extraction -- components you were carrying die with the
		# bag, same as everything else in it (see `bank_components`).
		"banked": banked.duplicate(),
		"value": value,
		"premium": premium,
		"fee": fee,
		"kills": kills,
		"level": level,
		"depth": depth,
		"killer": last_attacker,
	}


## What leaving costs right now.
##
## The rate comes through `RelicDb` unconditionally -- it hands back `EXTRACT_RATE`
## untouched until the Rope-Drum is recorded and 0.20 after, so there is no `if`
## here and never should be. A caller that wrote `if RelicDb.donated(...)` would
## be the unlock implemented twice, and the next tuning pass would move one copy.
func extract_cost() -> int:
	return maxi(EXTRACT_MIN, int(round(bag_value() * RelicDb.extract_rate(EXTRACT_RATE))))


## What actually leaves the purse: the toll, or everything you have, whichever is
## smaller. **This is the number the player pays and the number on the receipt.**
##
## The cap exists because the uncapped toll had no way to be complied with. It
## rises with the bag, and the bag can only be sold in town, so a toll past your
## gold was a wall you could only walk further away from -- every mote you picked
## up made it taller, and the one escape (dying) destroyed the bag you were
## trying to bank. That is not a priced decision, it is a soft-lock with a number
## printed on it.
##
## Capping keeps the whole of what the fee is FOR. A rich run still costs
## everything you own to bank; it just cannot cost more than that. The greed
## curve is unchanged right up to the purse and then flattens, and where it
## flattens the player is walking out of the Lower Worlds with nothing but the
## bag -- broke, and now made to sell it. Which is the loop.
func extract_charge() -> int:
	return mini(extract_cost(), maxi(Game.gold, 0))


## True when the toll is past the purse, so leaving will take every coin. The UI
## says so before the hold rather than after the charge: "it costs 36" and "it
## costs everything you have" are different sentences and the second one is a
## decision.
func extract_takes_all() -> bool:
	return in_dungeon and extract_cost() >= Game.gold and Game.gold > 0


## Whether the rope can work at all. Poverty is not one of the answers any more
## and there is no `Game.gold` term left here -- see `extract_charge`. Kept as a
## function because the HUD, the pouch and the rope all ask, and a rule about
## when leaving is possible should have exactly one home.
func can_extract() -> bool:
	return in_dungeon


# --- The bag ----------------------------------------------------------------

## Put `count` of `id` in the bag. Returns how many actually fit -- a full bag
## is a real event the caller should show, not an error to swallow.
##
## `heat_mult` is what the chain was worth when this was swept off the floor
## (LootMote carries it; see Heat). Anything above 1.0 lands in `premium`. It is
## a parameter rather than a read of Heat.multiplier() because the mote's heat is
## the heat it was KILLED at, cooling on the floor -- by the time you reach it
## the live chain may be hotter or dead, and neither is what this pickup is worth.
func collect(id: StringName, count: int = 1, heat_mult: float = 1.0) -> int:
	var def := ItemDb.get_def(id)
	if def == null or count <= 0:
		return 0

	var taken := 0
	while taken < count:
		var have: int = bag.get(id, 0)
		# Room in an existing stack costs no slot.
		if have > 0 and have % def.stack != 0:
			bag[id] = have + 1
		elif slots_used() < Game.bag_slots:
			bag[id] = have + 1
		else:
			break
		taken += 1

	if taken > 0:
		var bonus := int(round(def.value * taken * (maxf(heat_mult, 1.0) - 1.0)))
		if bonus > 0:
			premium += bonus
			Bus.heat_banked.emit(bonus)
		Bus.bag_changed.emit(bag, bag_value())
		Bus.loot_gained.emit(id, taken)
	if taken < count:
		Bus.bag_full.emit()
	return taken


## Burn `count` of `id` out of the bag without selling it. Returns how many were
## actually taken, which is 0 when the bag is short -- the caller decides whether
## that is a beep or a sentence.
##
## The premium share goes with them, exactly as it does in `sell()`. Heat is
## earned per gold of merchandise; take merchandise out of the bag by any door
## and the pot has to shrink with it, or the stacks that are left would inherit
## a bonus they never earned and the vendor would pay for arrows.
##
## Only the fletching calls this today. It is on Run rather than on Fletching
## because the bag's bookkeeping -- the erase, the premium, the signal -- is
## Run's and nobody else's, and a second writer of `bag` is how the two halves
## of a total start to disagree.
func consume(id: StringName, count: int = 1) -> int:
	var have: int = bag.get(id, 0)
	if have <= 0 or count <= 0:
		return 0
	var def := ItemDb.get_def(id)
	if def == null:
		return 0
	var n: int = mini(count, have)
	premium -= _premium_share(def.value * n)
	premium = maxi(premium, 0)
	if n >= have:
		bag.erase(id)
	else:
		bag[id] = have - n
	Bus.bag_changed.emit(bag, bag_value())
	return n


## Slots consumed. A stack of 20 bone shards with stack==20 is one slot; the
## twenty-first starts a second.
func slots_used() -> int:
	var used := 0
	for id: StringName in bag:
		var def := ItemDb.get_def(id)
		var per: int = def.stack if def != null else 1
		used += int(ceil(float(bag[id]) / float(maxi(per, 1))))
	return used


func is_full() -> bool:
	return slots_used() >= Game.bag_slots


## What the vendor would pay for everything in the bag, heat included. This is
## THE number: the HUD headline, the extraction fee, and the vendor's SELL
## EVERYTHING line are all this function, which is why the premium is folded in
## here rather than bolted onto each of them.
func bag_value() -> int:
	return base_value() + premium


## The same bag at flat, un-lit prices. Only the premium arithmetic needs this.
func base_value() -> int:
	var total := 0
	for id: StringName in bag:
		var def := ItemDb.get_def(id)
		if def != null:
			total += def.value * int(bag[id])
	return total


## What one stack is worth, carrying its share of the premium. The vendor screen
## prices its lines with this so the row and the gold that lands agree; a line
## that said 72 and paid 91 reads as a bug however welcome the extra is.
##
## **Zero for a relic**, which is the whole of "no relic sells" as a number: the
## row draws 0 and `sell()` below refuses the press. A relic still weighs on
## `bag_value()` and therefore on the fee (`ItemDb.RELIC_TOLL`), and those two
## facts are not in tension -- the rope charges by what you are hauling, the
## vendor pays for what he can resell, and a relic is the one thing in the game
## where those are different numbers.
##
## The market multiplier rides here rather than in `bag_value`, so a lit square
## makes SELLING better and never makes LEAVING cheaper. The relic that makes
## leaving cheaper is the Rope-Drum and it is a different relic.
func line_value(id: StringName) -> int:
	var def := ItemDb.get_def(id)
	if def == null or not bag.has(id) or RelicDb.is_relic(id):
		return 0
	var base := def.value * int(bag[id])
	return int(round((base + _premium_share(base)) * RelicDb.vendor_price_mult()))


## The premium riding on `base` gold of flat value. Rounded down at the last
## stack so repeated partial sells can never pay out more premium than exists.
##
## The denominator is the MERCHANDISE half of the bag, relics taken off. Heat is
## earned per gold of sellable loot; a relic earned none of it and cannot carry
## any away, so leaving its weight in the divisor would quietly shrink every real
## stack's share for as long as one was in the bag.
func _premium_share(base: int) -> int:
	if premium <= 0 or base <= 0:
		return 0
	var whole := base_value() - relic_toll()
	if whole <= 0:
		return 0
	return mini(premium, int(round(premium * float(base) / float(whole))))


func bag_count() -> int:
	var n := 0
	for id: StringName in bag:
		n += int(bag[id])
	return n


## Hand the whole bag to the vendor. Returns what it paid.
##
## **Relics stay.** He will not take one and the row does not empty -- SELL
## EVERYTHING means everything he BUYS, and a bag that came back holding one thing
## says why on its own. Their weight comes off the payout for the same reason
## `line_value` answers 0: the toll and the sale price are different numbers and
## only one of them is his (GDD §6.3).
func sell_all() -> int:
	var paid := int(round((bag_value() - relic_toll()) * RelicDb.vendor_price_mult()))
	if paid <= 0:
		return 0
	var sold: Dictionary[StringName, int] = {}
	for id: StringName in bag.keys():
		if RelicDb.is_relic(id):
			continue
		sold[id] = int(bag[id])
		bag.erase(id)
	# `paid` was the whole merchandise value, premium included -- emptying the
	# sellable half empties the pot with it, and neither is counted twice.
	premium = 0
	Game.add_gold(paid)
	Bus.bag_changed.emit(bag, bag_value())
	Bus.items_sold.emit(sold, paid)
	return paid


## Sell one stack. Used by the vendor screen when the player picks a line.
##
## **A relic is refused here, and 0 is the refusal.** The screen already draws a
## failed commit as its footer's "why not" line, so the vendor saying no costs no
## UI: he simply never pays for one. This is the enforcement point rather than a
## check on the screen because the bag's bookkeeping is this file's and nobody
## else's -- a rule about what may leave the bag that lived in `TradeScreen` would
## be a rule the next caller of `sell()` did not know about.
func sell(id: StringName, count: int = -1) -> int:
	var have: int = bag.get(id, 0)
	if have <= 0 or RelicDb.is_relic(id):
		return 0
	var def := ItemDb.get_def(id)
	if def == null:
		return 0
	var n: int = have if count < 0 else mini(count, have)
	var base := def.value * n
	# Prorated, and taken out of the pot in the same breath: sell half the bag
	# and half the heat you earned goes with it.
	var share := _premium_share(base)
	# A lit square pays more for the same stack. Unconditional -- `vendor_price_mult`
	# is 1.0 until the Pillar-Shard is recorded.
	var paid := int(round((base + share) * RelicDb.vendor_price_mult()))
	premium -= share

	if n >= have:
		bag.erase(id)
	else:
		bag[id] = have - n
	Game.add_gold(paid)
	Bus.bag_changed.emit(bag, bag_value())
	Bus.items_sold.emit({id: n}, paid)
	return paid


## Called by the dungeon when the player walks into a new room.
func descend() -> void:
	depth += 1
	Bus.depth_changed.emit(depth)
