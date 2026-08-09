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
## Seeded per run so a dungeon can be replayed exactly.
var rng := RandomNumberGenerator.new()
var seed_used: int = 0

## Fraction of the bag's sale value the teleport costs. [tune]
const EXTRACT_RATE := 0.25
## Floor on the fee, so an empty-handed bail-out is not free. [tune]
const EXTRACT_MIN := 15


func _ready() -> void:
	reset()


func reset() -> void:
	bag.clear()
	premium = 0
	in_dungeon = false
	depth = 0
	level = 1


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


## Teleport out. Returns false if the player cannot afford it -- the caller
## shows the refusal, because only it knows whether that is a UI beep or a
## vendor line.
func extract() -> bool:
	if not in_dungeon:
		return false
	var fee := extract_cost()
	if Game.gold < fee:
		Bus.extract_refused.emit(fee, Game.gold)
		return false

	Game.spend_gold(fee)
	in_dungeon = false
	# The fee was charged on the WHOLE bag, components included, and only then
	# are they sorted out of it. That order is the rule: you pay to carry a
	# component home exactly as you pay to carry a pearl home, so choosing the
	# component is a choice about slots and never a way to dodge the toll.
	var banked := bank_components()
	# Getting your health back is what makes extracting feel like relief rather
	# than retreat. It is also the only heal in the game, which is what stops a
	# player from grinding one room forever.
	Game.heal(Game.max_quarters)
	Bus.run_ended.emit(true, bag.duplicate(), bag_value())
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


## Die. The bag is gone; gold and anything bought with it survives.
func die() -> void:
	if not in_dungeon:
		return
	var lost := bag.duplicate()
	var lost_value := bag_value()
	bag.clear()
	# The heat premium dies with the bag it was earned into. It is the same
	# gold; there was never a second container.
	premium = 0
	in_dungeon = false
	depth = 0
	# You wake up in town: broke, but alive. Leaving health at zero would mean
	# the next thing that touched you killed you again before you could sell.
	Game.heal(Game.max_quarters)
	Bus.bag_changed.emit(bag, 0)
	Bus.run_ended.emit(false, lost, lost_value)


## What leaving costs right now.
func extract_cost() -> int:
	return maxi(EXTRACT_MIN, int(round(bag_value() * EXTRACT_RATE)))


func can_extract() -> bool:
	return in_dungeon and Game.gold >= extract_cost()


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
func line_value(id: StringName) -> int:
	var def := ItemDb.get_def(id)
	if def == null or not bag.has(id):
		return 0
	var base := def.value * int(bag[id])
	return base + _premium_share(base)


## The premium riding on `base` gold of flat value. Rounded down at the last
## stack so repeated partial sells can never pay out more premium than exists.
func _premium_share(base: int) -> int:
	if premium <= 0 or base <= 0:
		return 0
	var whole := base_value()
	if whole <= 0:
		return 0
	return mini(premium, int(round(premium * float(base) / float(whole))))


func bag_count() -> int:
	var n := 0
	for id: StringName in bag:
		n += int(bag[id])
	return n


## Hand the whole bag to the vendor. Returns what it paid.
func sell_all() -> int:
	var paid := bag_value()
	if paid <= 0:
		return 0
	var sold := bag.duplicate()
	bag.clear()
	# `paid` is bag_value(), which already includes the premium -- emptying the
	# bag empties the pot with it, and neither is counted twice.
	premium = 0
	Game.add_gold(paid)
	Bus.bag_changed.emit(bag, 0)
	Bus.items_sold.emit(sold, paid)
	return paid


## Sell one stack. Used by the vendor screen when the player picks a line.
func sell(id: StringName, count: int = -1) -> int:
	var have: int = bag.get(id, 0)
	if have <= 0:
		return 0
	var def := ItemDb.get_def(id)
	if def == null:
		return 0
	var n: int = have if count < 0 else mini(count, have)
	var base := def.value * n
	# Prorated, and taken out of the pot in the same breath: sell half the bag
	# and half the heat you earned goes with it.
	var share := _premium_share(base)
	var paid := base + share
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
