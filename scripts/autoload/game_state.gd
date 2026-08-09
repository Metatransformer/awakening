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

## Stamina is what makes the dodge a decision -- see K.MAX_STAMINA for why this
## exists at all when the source material has no such thing. Unlike everything
## else here it is NOT save-able state: it refills on its own in a couple of
## seconds, so persisting it would only ever restore a number that is about to
## be 100 anyway.
var max_stamina: float = K.MAX_STAMINA
var stamina: float = K.MAX_STAMINA
## Counts down from K.STAMINA_DELAY after a spend. Regen is frozen while > 0.
var _stamina_hold: float = 0.0

var rupees: int = 0
## Metagame currency. Survives death; the bag in `Run` does not.
var gold: int = K.START_GOLD
## Bag capacity, in slots. Bought from the shop, so it lives here with the rest
## of the metagame rather than in `Run`, which is wiped every time you die.
var bag_slots: int = K.START_BAG_SLOTS
## Extra quarter-hearts the sword deals, bought from the smith.
var sword_bonus: int = 0
## Quarter-hearts subtracted from every blow taken, floored at 1 -- armour makes
## you last longer, never invincible.
var armour_level: int = 0
## Shop line id -> how many times it has been bought. Drives the price ramp and
## the per-line purchase limits. See ShopDb.
var upgrades: Dictionary[StringName, int] = {}
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
##
## SUPERSEDED by `loadout` below, and kept only because `save_game.gd` still
## round-trips it and old saves carry it. Nothing reads it to decide what is in
## the hero's hands any more. Do not add to it.
var c_items: Array[StringName] = [&"", &"", &""]

# --- Armaments --------------------------------------------------------------
## Two loadouts, each with a right hand and a left hand, exactly as Elden Ring
## arranges them. dpad up swaps the SET; dpad left/right cycle one hand within
## whatever you own.
##
## The alternate set is bow and arrows, which is the point of having two: the
## primary answers "something is in front of me" and the alternate answers
## "something is not". Swapping is one button rather than a menu, because a
## weapon switch you have to pause for is a weapon switch nobody makes.
##
## Ids, not Resources. The whole save file is ids (see save_game.gd), and a
## Resource reference here would be one more thing that cannot survive a scene
## change -- which is exactly what extraction is.
const PRIMARY := 0
const ALTERNATE := 1
const HAND_RIGHT := &"right"
const HAND_LEFT := &"left"

## What each hand may hold, in cycle order. `&""` is the empty hand and is a
## legitimate choice: two-handing the sword and dropping the shield is a real
## decision, not a broken state.
const RIGHT_POOL: Array[StringName] = [&"sword", &"bow", &"hookshot"]
const LEFT_POOL: Array[StringName] = [&"shield", &"arrow", &""]

var loadout: Array[Dictionary] = [
	{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
	{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
]
var loadout_set: int = PRIMARY
## One-way world flags: chests opened, doors unlocked, puzzles solved.
var flags: Dictionary[StringName, bool] = {}


func reset() -> void:
	max_quarters = K.START_HEARTS * K.HEART
	quarters = max_quarters
	max_magic = 0
	magic = 0
	rupees = 0
	gold = K.START_GOLD
	bag_slots = K.START_BAG_SLOTS
	sword_bonus = 0
	armour_level = 0
	upgrades.clear()
	arrows = 0
	bombs = 0
	small_keys = 0
	has_boss_key = false
	has_map = false
	has_compass = false
	items.clear()
	c_items = [&"", &"", &""]
	loadout = [
		{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
		{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
	]
	loadout_set = PRIMARY
	flags.clear()
	Bus.gold_changed.emit(gold)
	Bus.key_count_changed.emit(small_keys)
	Bus.player_health_changed.emit(quarters, max_quarters)
	Bus.magic_changed.emit(magic, max_magic)
	stamina = max_stamina
	_stamina_hold = 0.0
	Bus.stamina_changed.emit(stamina, max_stamina)


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


# --- Stamina ----------------------------------------------------------------
## The only thing in this file that ticks. Regen is frozen for K.STAMINA_DELAY
## after a spend: the pause IS the tell that you are winded, and without it the
## bar refills so smoothly that it reads as no system at all.

func _process(delta: float) -> void:
	if _stamina_hold > 0.0:
		_stamina_hold = maxf(0.0, _stamina_hold - delta)
		return
	if stamina >= max_stamina:
		return
	stamina = minf(max_stamina, stamina + K.STAMINA_REGEN * delta)
	Bus.stamina_changed.emit(stamina, max_stamina)


## Spend, or refuse. Returns false when there is not enough, and the caller is
## expected to NOT perform the action -- otherwise the bar and the dodge
## disagree, which is worse than having no bar.
func spend_stamina(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if stamina < cost:
		return false
	stamina -= cost
	_stamina_hold = K.STAMINA_DELAY
	Bus.stamina_changed.emit(stamina, max_stamina)
	return true


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


func add_rupees(n: int) -> void:
	rupees = maxi(0, rupees + n)
	Bus.rupees_changed.emit(rupees)


# --- Gold -------------------------------------------------------------------
# The metagame currency. Survives death, buys gear, and pays the extraction fee.
# Separate from `rupees`, which is the in-dungeon pickup left over from the
# earlier design and is on its way out.

func add_gold(n: int) -> void:
	if n == 0:
		return
	gold = maxi(0, gold + n)
	Bus.gold_changed.emit(gold)


## Returns false and changes nothing if the player cannot afford it, so callers
## can use it as the check and the transaction at once.
func spend_gold(n: int) -> bool:
	if n <= 0:
		return true
	if gold < n:
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


# --- Armaments --------------------------------------------------------------

## What is in `hand` (Game.HAND_RIGHT / HAND_LEFT) in the live set.
func armament(hand: StringName) -> StringName:
	var set_data: Dictionary = loadout[clampi(loadout_set, 0, loadout.size() - 1)]
	return set_data.get(hand, &"")


## Swap primary <-> alternate. dpad up.
func swap_loadout() -> void:
	loadout_set = ALTERNATE if loadout_set == PRIMARY else PRIMARY
	_announce_loadout()


## Cycle one hand forward through what the player actually owns. dpad left/right.
##
## Ownership is checked here rather than at the UI, because the UI is not the
## only caller and a hand holding an item the player does not have is a bow that
## fires nothing while the icon insists otherwise.
func cycle_armament(hand: StringName, dir: int = 1) -> void:
	var pool: Array[StringName] = RIGHT_POOL if hand == HAND_RIGHT else LEFT_POOL
	var available: Array[StringName] = []
	for id in pool:
		if _armament_owned(id):
			available.append(id)
	if available.size() <= 1:
		return
	var current := armament(hand)
	var at := available.find(current)
	# An unowned current (sold, or a save from a different pool) lands at -1 and
	# a forward step from there is the first entry, which is the right answer.
	var next := available[posmod(at + signi(dir), available.size())]
	loadout[clampi(loadout_set, 0, loadout.size() - 1)][hand] = next
	_announce_loadout()


## The sword and the empty hand are always available; everything else has to be
## found or bought. `arrow` follows the bow -- carrying arrows you cannot fire
## is not a loadout, it is a slot that lies.
func _armament_owned(id: StringName) -> bool:
	match id:
		&"": return true
		&"sword": return true
		&"shield": return true
		&"arrow": return has(&"bow")
	return has(id)


func _announce_loadout() -> void:
	Bus.loadout_changed.emit(loadout_set, armament(HAND_RIGHT), armament(HAND_LEFT))


func set_flag(id: StringName) -> void:
	flags[id] = true


func flag(id: StringName) -> bool:
	return flags.get(id, false)
