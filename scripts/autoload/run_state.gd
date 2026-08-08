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
	in_dungeon = false
	depth = 0


# --- Entering and leaving ---------------------------------------------------

## Start a run. Pass a seed to replay one; 0 picks a fresh one and records it.
func enter(run_seed: int = 0) -> void:
	bag.clear()
	depth = 0
	in_dungeon = true
	seed_used = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_used
	Bus.bag_changed.emit(bag, bag_value())
	Bus.run_started.emit(seed_used)


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
	# Getting your health back is what makes extracting feel like relief rather
	# than retreat. It is also the only heal in the game, which is what stops a
	# player from grinding one room forever.
	Game.heal(Game.max_quarters)
	Bus.run_ended.emit(true, bag.duplicate(), bag_value())
	return true


## Die. The bag is gone; gold and anything bought with it survives.
func die() -> void:
	if not in_dungeon:
		return
	var lost := bag.duplicate()
	var lost_value := bag_value()
	bag.clear()
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
func collect(id: StringName, count: int = 1) -> int:
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


## What the vendor would pay for everything in the bag.
func bag_value() -> int:
	var total := 0
	for id: StringName in bag:
		var def := ItemDb.get_def(id)
		if def != null:
			total += def.value * int(bag[id])
	return total


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
	var paid := def.value * n

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
