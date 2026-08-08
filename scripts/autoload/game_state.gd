extends Node
## Autoload `Game`. The save-able truth about the run: health, magic, keys,
## items, world flags. Nothing in here touches the scene tree.
##
## Health is counted in QUARTER hearts (K.QUARTER), like the source material —
## a heart is K.HEART == 4 quarters, and the HUD draws quarter-heart states.

var max_quarters: int = K.START_HEARTS * K.HEART
var quarters: int = K.START_HEARTS * K.HEART

var max_magic: int = 0  ## 0 until the magic meter is unlocked
var magic: int = 0

var gold: int = 0
var arrows: int = 0
var max_arrows: int = 30
var bombs: int = 0
var max_bombs: int = 20

var small_keys: int = 0
var has_boss_key: bool = false
var has_map: bool = false
var has_compass: bool = false

## Item ids the player owns, e.g. &"hookshot".
var items: Dictionary[StringName, bool] = {}
## The three C-button slots the HUD draws and item_left/up/right fire.
var c_items: Array[StringName] = [&"", &"", &""]
## One-way world flags: chests opened, doors unlocked, puzzles solved.
var flags: Dictionary[StringName, bool] = {}

# --- Metagame (docs/METAGAME.md) --------------------------------------------
## The dungeon bag. Limited slots; the first K.BELT_SLOTS survive death.
var bag: Bag = null
## The town stash. Unlimited on purpose — bag pressure belongs in the dungeon,
## which is where the interesting decision is. id -> count.
var stash: Dictionary[StringName, int] = {}

var blade_tier: int = 0
var armor_tier: int = 0

## Live run state. `rooms_cleared` drives both the depth band and the fee.
var in_dungeon: bool = false
var rooms_cleared: int = 0
var run_seed: int = 0


func _ready() -> void:
	bag = Bag.new()
	bag.changed.connect(func() -> void: Bus.bag_changed.emit())


func reset() -> void:
	max_quarters = K.START_HEARTS * K.HEART
	quarters = max_quarters
	max_magic = 0
	magic = 0
	gold = 0
	arrows = 0
	bombs = 0
	small_keys = 0
	has_boss_key = false
	has_map = false
	has_compass = false
	items.clear()
	c_items = [&"", &"", &""]
	flags.clear()
	if bag != null:
		bag.clear()
	stash.clear()
	blade_tier = 0
	armor_tier = 0
	in_dungeon = false
	rooms_cleared = 0
	Bus.key_count_changed.emit(small_keys)
	Bus.player_health_changed.emit(quarters, max_quarters)
	Bus.magic_changed.emit(magic, max_magic)


# --- Health -----------------------------------------------------------------

func damage(amount_quarters: int) -> void:
	if amount_quarters <= 0:
		return
	quarters = maxi(0, quarters - amount_quarters)
	Bus.player_health_changed.emit(quarters, max_quarters)
	if quarters == 0:
		Bus.player_died.emit()


func heal(amount_quarters: int) -> void:
	quarters = mini(max_quarters, quarters + amount_quarters)
	Bus.player_health_changed.emit(quarters, max_quarters)


func add_heart_container() -> void:
	max_quarters += K.HEART
	quarters = max_quarters
	Bus.player_health_changed.emit(quarters, max_quarters)


# --- Magic ------------------------------------------------------------------

func unlock_magic() -> void:
	max_magic = K.MAX_MAGIC
	magic = max_magic
	Bus.magic_changed.emit(magic, max_magic)


func spend_magic(cost: int) -> bool:
	if cost <= 0:
		return true
	if magic < cost:
		return false
	magic -= cost
	Bus.magic_changed.emit(magic, max_magic)
	return true


func restore_magic(amount: int) -> void:
	magic = mini(max_magic, magic + amount)
	Bus.magic_changed.emit(magic, max_magic)


# --- Consumables ------------------------------------------------------------

func add_arrows(n: int) -> void:
	arrows = clampi(arrows + n, 0, max_arrows)
	Bus.ammo_changed.emit(&"arrows", arrows)


func add_bombs(n: int) -> void:
	bombs = clampi(bombs + n, 0, max_bombs)
	Bus.ammo_changed.emit(&"bombs", bombs)


## Spend one unit of a consumable. Returns false if the player has none.
func spend_ammo(id: StringName) -> bool:
	match id:
		&"arrows":
			if arrows <= 0:
				return false
			arrows -= 1
		&"bombs":
			if bombs <= 0:
				return false
			bombs -= 1
		_:
			return true
	Bus.ammo_changed.emit(id, arrows if id == &"arrows" else bombs)
	return true


## Add (or, with a negative n, remove) gold. Never goes below zero.
func add_gold(n: int) -> void:
	gold = maxi(0, gold + n)
	Bus.gold_changed.emit(gold)


## Spend gold if the player has it. Returns false and changes nothing if not —
## callers rely on this being atomic, so never pre-check and then subtract.
func spend_gold(n: int) -> bool:
	if n < 0 or gold < n:
		return false
	gold -= n
	Bus.gold_changed.emit(gold)
	return true


# --- Keys -------------------------------------------------------------------

func add_key(n: int = 1) -> void:
	small_keys += n
	Bus.key_count_changed.emit(small_keys)


func spend_key() -> bool:
	if small_keys <= 0:
		return false
	small_keys -= 1
	Bus.key_count_changed.emit(small_keys)
	return true


# --- Items and flags --------------------------------------------------------

func grant(item_id: StringName) -> void:
	if items.get(item_id, false):
		return
	items[item_id] = true
	# Auto-assign a newly found item to the first empty C slot, as OOT does.
	for i in c_items.size():
		if c_items[i] == &"":
			c_items[i] = item_id
			Bus.c_items_changed.emit(c_items)
			break
	Bus.item_acquired.emit(item_id)


func has(item_id: StringName) -> bool:
	return items.get(item_id, false)


func equip(slot: int, item_id: StringName) -> void:
	if slot < 0 or slot >= c_items.size():
		return
	c_items[slot] = item_id
	Bus.c_items_changed.emit(c_items)


func set_flag(id: StringName) -> void:
	flags[id] = true


func flag(id: StringName) -> bool:
	return flags.get(id, false)


# --- Stash ------------------------------------------------------------------

func stash_add(id: StringName, n: int) -> void:
	if n <= 0:
		return
	stash[id] = stash.get(id, 0) + n
	Bus.stash_changed.emit()


func stash_count(id: StringName) -> int:
	return stash.get(id, 0)


## Remove from the stash. Returns false and changes nothing if short, so a
## caller can never half-pay for a recipe.
func stash_take(id: StringName, n: int) -> bool:
	if stash.get(id, 0) < n:
		return false
	stash[id] = stash[id] - n
	if stash[id] <= 0:
		stash.erase(id)
	Bus.stash_changed.emit()
	return true


func stash_total_value() -> int:
	var v := 0
	for id in stash:
		v += LootDB.sell_value(id) * stash[id]
	return v


# --- Vendor: ingredients -> gold, the game's only gold faucet ---------------

## Sell `n` of one ingredient out of the stash. Returns gold earned.
func sell(id: StringName, n: int) -> int:
	var have: int = stash.get(id, 0)
	var sold := mini(have, n)
	if sold <= 0:
		return 0
	stash_take(id, sold)
	var earned := LootDB.sell_value(id) * sold
	add_gold(earned)
	return earned


## Sell the whole stash. Convenient, and deliberately a little bit of a trap —
## everything you sell is something you are no longer able to forge with.
func sell_all() -> int:
	var earned := 0
	for id in stash.keys():
		earned += LootDB.sell_value(id) * stash[id]
	stash.clear()
	if earned > 0:
		add_gold(earned)
	Bus.stash_changed.emit()
	return earned


# --- Smith: gold + ingredients -> power -------------------------------------

func gear_tier(track: Gear.Track) -> int:
	return blade_tier if track == Gear.Track.BLADE else armor_tier


## What is missing before this rung can be bought: {"gold": n, <id>: n, ...}.
## Empty means it is affordable right now.
func craft_shortfall(track: Gear.Track) -> Dictionary:
	var tier := gear_tier(track)
	var out: Dictionary = {}
	if tier >= Gear.MAX_TIER:
		return {&"maxed": 1}
	var price := Gear.next_gold(track, tier)
	if gold < price:
		out[&"gold"] = price - gold
	var mats := Gear.next_materials(track, tier)
	for id in mats:
		var need: int = mats[id]
		var have: int = stash.get(id, 0)
		if have < need:
			out[id] = need - have
	return out


func can_craft(track: Gear.Track) -> bool:
	return craft_shortfall(track).is_empty()


## Buy the next rung. All-or-nothing: nothing is spent unless everything is
## available, so a partial purchase can never strand the player.
func craft(track: Gear.Track) -> bool:
	if not can_craft(track):
		return false
	var tier := gear_tier(track)
	var price := Gear.next_gold(track, tier)
	var mats := Gear.next_materials(track, tier)

	if not spend_gold(price):
		return false
	for id in mats:
		stash_take(id, mats[id])

	var new_tier := tier + 1
	if track == Gear.Track.BLADE:
		blade_tier = new_tier
	else:
		armor_tier = new_tier
		# Armour is heart containers. Fill them — you just paid for the safety,
		# you should feel it before you walk back down.
		max_quarters = Gear.armor_hearts(new_tier) * K.HEART
		quarters = max_quarters
		Bus.player_health_changed.emit(quarters, max_quarters)

	Bus.gear_changed.emit(int(track), new_tier)
	return true


# --- Run lifecycle ----------------------------------------------------------

func start_run(new_seed: int = 0) -> void:
	run_seed = new_seed if new_seed != 0 else randi()
	in_dungeon = true
	rooms_cleared = 0
	bag.clear()
	quarters = max_quarters
	Bus.player_health_changed.emit(quarters, max_quarters)
	Bus.run_started.emit()
	Bus.run_depth_changed.emit(rooms_cleared, K.band_for_room(rooms_cleared))


func room_cleared() -> void:
	rooms_cleared += 1
	Bus.run_depth_changed.emit(rooms_cleared, K.band_for_room(rooms_cleared))


func depth_band() -> int:
	return K.band_for_room(rooms_cleared)


func extract_fee() -> int:
	return K.extract_fee(rooms_cleared)


func can_afford_extract() -> bool:
	return gold >= extract_fee()


## Leave with the haul. `paid` charges the teleport fee; walking out is free.
## Everything in the bag moves to the stash.
func end_run_extracted(paid: bool) -> bool:
	if paid and not spend_gold(extract_fee()):
		return false
	_bank(bag.drain())
	in_dungeon = false
	Bus.run_ended.emit(&"extracted" if paid else &"walked_out", rooms_cleared)
	return true


## Death. The belt survives, the rest of the bag is gone, gold is untouched.
## Returns what was lost, so the player is told exactly what it cost.
func end_run_died() -> Dictionary:
	var lost := bag.drop_all_but_belt()
	_bank(bag.drain())
	in_dungeon = false
	quarters = max_quarters
	Bus.player_health_changed.emit(quarters, max_quarters)
	Bus.run_ended.emit(&"died", rooms_cleared)
	return lost


func _bank(haul: Dictionary) -> void:
	for id in haul:
		stash[id] = stash.get(id, 0) + haul[id]
	if not haul.is_empty():
		Bus.stash_changed.emit()
