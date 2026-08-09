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

# --- Quick slots: the C-buttons ---------------------------------------------
## What is bound to D-pad ←, ↑ and → — Ocarina's C-buttons, in that order.
##
## Pressing one puts the bound item in the RIGHT hand; pressing it again puts
## it away. That is what a C-button does in the source material: C-right with
## the bow *draws the bow*, it does not open a menu. Binding is direct access,
## which is the whole reason it beats cycling — you reach for the hookshot
## because you want the hookshot, not because it is two presses from the sword.
##
## `&""` is an unbound slot and is not an error; a new game has three of them.
const QUICK_SLOTS := 3
const QUICK_LEFT := 0
const QUICK_UP := 1
const QUICK_RIGHT := 2
## What may be bound, in bind-cycle order. The empty binding is first so
## clearing a slot is one press past the end rather than a separate verb.
const QUICK_POOL: Array[StringName] = [&"", &"bow", &"hookshot"]

var quick_slots: Array[StringName] = [&"", &"", &""]

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


# --- The starter kit --------------------------------------------------------
## [test] Gear the player would otherwise have to FIND, handed over at boot so
## the ranged items can be exercised without playing a full run to a chest.
##
## This is scaffolding and it is meant to be deleted. It is one constant and one
## call precisely so that deleting it is a two-line change: empty the array and
## the game goes back to a hero with a sword, three empty C-buttons and an
## alternate loadout that names a bow he has not found — which is the real
## starting state and the one the equipment screen's "(not owned)" text exists
## to describe.
##
## `grant()` auto-binds each item to the first free C-button in order, so the
## bow lands on dpad ← and the hookshot on dpad ↑ with no extra wiring.
const STARTER_KIT: Array[StringName] = [&"bow", &"hookshot"]
## Enough to miss with. A quiver you can empty in one fight turns a test of the
## bow into a test of the arrow economy.
const STARTER_ARROWS := 30


func _ready() -> void:
	_grant_starter_kit()


## Deliberately called from boot and NOT from `reset()`. `reset()` means "a
## fresh save owns nothing", several directors assert exactly that, and a kit
## that reappeared on every reset would make the assertion untestable rather
## than true. Idempotent anyway: `grant()` returns early on anything already
## owned and the arrow top-up is a floor rather than an addition.
func _grant_starter_kit() -> void:
	for id in STARTER_KIT:
		grant(id)
	if arrows < STARTER_ARROWS:
		add_arrows(STARTER_ARROWS - arrows)


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
	quick_slots = [&"", &"", &""]
	loadout = [
		{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
		{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
	]
	loadout_set = PRIMARY
	flags.clear()
	# Say that the hands and the buttons emptied. Without this, resetting cleared
	# `items` and `loadout` in silence and every listener kept drawing the gear
	# it last heard about — a hero still wearing a stowed bow he no longer owns,
	# and item buttons still labelled with it. Announcing state is not optional
	# for state nobody polls.
	_announce_loadout()
	Bus.quick_slots_changed.emit(quick_slots)
	Bus.ammo_changed.emit(&"arrows", arrows)
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
	# Auto-bind a newly found item to the first empty C slot, as the source
	# material does. Finding the bow and then having to open a menu before you
	# can shoot it is the one thing Ocarina never makes you do.
	if QUICK_POOL.has(item_id):
		for i in quick_slots.size():
			if quick_slots[i] == &"":
				bind_quick(i, item_id)
				break
	Bus.item_acquired.emit(item_id)


func has(item_id: StringName) -> bool:
	return items.get(item_id, false)


# --- Quick slots ------------------------------------------------------------

func quick(slot: int) -> StringName:
	if slot < 0 or slot >= quick_slots.size():
		return &""
	return quick_slots[slot]


## Put `item_id` on a C-button. Refuses anything unowned, because a button that
## draws a bow you have never found is a button that lies about your inventory.
func bind_quick(slot: int, item_id: StringName) -> bool:
	if slot < 0 or slot >= quick_slots.size():
		return false
	if item_id != &"" and not (QUICK_POOL.has(item_id) and has(item_id)):
		return false
	# One item, one button. Binding something already on another slot MOVES it
	# rather than duplicating it -- two buttons that draw the same bow is two
	# buttons doing one button's job.
	for i in quick_slots.size():
		if i != slot and quick_slots[i] == item_id and item_id != &"":
			quick_slots[i] = &""
	quick_slots[slot] = item_id
	Bus.quick_slots_changed.emit(quick_slots)
	return true


## Cycle a slot's binding forward through what the player owns. The bind UI.
func cycle_quick_bind(slot: int, dir: int = 1) -> void:
	if slot < 0 or slot >= quick_slots.size():
		return
	var available: Array[StringName] = []
	for id in QUICK_POOL:
		if id == &"" or has(id):
			available.append(id)
	if available.size() <= 1:
		return
	var at := available.find(quick(slot))
	bind_quick(slot, available[posmod(at + signi(dir), available.size())])


## Press a C-button: draw what is bound there, or put it away if it is already
## out. An unbound slot does nothing at all -- deliberately silent, because a
## refusal noise on a button you never assigned is noise about your own choice.
func use_quick(slot: int) -> void:
	var id := quick(slot)
	if id == &"" or not has(id):
		return
	var live := clampi(loadout_set, 0, loadout.size() - 1)
	# Indexing an untyped Dictionary hands back Variant, so the comparison has
	# to be annotated or the parser cannot infer `stow`. See CLAUDE.md §3.
	var held: StringName = loadout[live][HAND_RIGHT]
	loadout[live][HAND_RIGHT] = &"sword" if held == id else id
	_announce_loadout()


# --- Armaments --------------------------------------------------------------

## What is in `hand` (Game.HAND_RIGHT / HAND_LEFT) in the live set.
func armament(hand: StringName) -> StringName:
	var set_data: Dictionary = loadout[clampi(loadout_set, 0, loadout.size() - 1)]
	return set_data.get(hand, &"")


## Swap primary <-> alternate. dpad up.
func swap_loadout() -> void:
	loadout_set = ALTERNATE if loadout_set == PRIMARY else PRIMARY
	_announce_loadout()


## What is in `hand` of a SPECIFIC set. `armament()` only answers about the live
## one; the equipment screen shows both at once.
func armament_in(set_index: int, hand: StringName) -> StringName:
	var data: Dictionary = loadout[clampi(set_index, 0, loadout.size() - 1)]
	return data.get(hand, &"")


## Cycle one hand forward through what the player actually owns. dpad left/right.
##
## Ownership is checked here rather than at the UI, because the UI is not the
## only caller and a hand holding an item the player does not have is a bow that
## fires nothing while the icon insists otherwise.
##
## `set_index` defaults to the live set, which is what the D-pad wants. The
## equipment screen passes an explicit one so it can edit the set you are not
## holding without making it live for a frame.
func cycle_armament(hand: StringName, dir: int = 1, set_index: int = -1) -> void:
	var target := clampi(set_index if set_index >= 0 else loadout_set, 0, loadout.size() - 1)
	var pool: Array[StringName] = RIGHT_POOL if hand == HAND_RIGHT else LEFT_POOL
	var available: Array[StringName] = []
	for id in pool:
		if armament_owned(id):
			available.append(id)
	if available.size() <= 1:
		return
	var current := armament_in(target, hand)
	var at := available.find(current)
	# An unowned current (sold, or a save from a different pool) lands at -1 and
	# a forward step from there is the first entry, which is the right answer.
	var next := available[posmod(at + signi(dir), available.size())]
	loadout[target][hand] = next
	_announce_loadout()


## The sword and the empty hand are always available; everything else has to be
## found or bought. `arrow` follows the bow -- carrying arrows you cannot fire
## is not a loadout, it is a slot that lies.
##
## Public because the equipment screen has to be able to SAY "not owned" on a
## slot, and a UI that re-derives ownership from its own rules is a UI that will
## eventually disagree with the gate.
func armament_owned(id: StringName) -> bool:
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
