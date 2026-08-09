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
## Shop line id -> how many times it has been bought. Drives the price ramp, the
## per-line purchase limits, and every forge ladder. See ShopDb.
##
## The forge tracks live in here rather than as five more `var`s because a rung
## is a PURCHASE, and the smith already knows how to count purchases. The gear
## reads them through the accessors below and never indexes this directly.
var upgrades: Dictionary[StringName, int] = {}
## Component id -> how many are on the workbench. Persistent: components that
## reached town survive death, because they were already paid for by the run
## that carried them home (`Run.extract` banks them). Components still in the
## bag when you die are gone with it.
var components: Dictionary[StringName, int] = {}
var arrows: int = 0
var max_arrows: int = 30
var bombs: int = 0
var max_bombs: int = 20

# --- Bottles (docs/METAGAME.md §6.6) ----------------------------------------
## What is in each bottle you own, in order. The ARRAY'S SIZE is how many
## bottles you have -- there is no separate count, because a count and a list
## that can disagree is a bottle that exists in the HUD and not in the fridge.
## `&""` is an empty bottle, and an empty bottle is the thing the alchemist
## needs before he will brew anything.
##
## Persistent, like gold and the workbench: a bottle is a purchase and what is
## in it was paid for in town. Death does not take it -- what death takes is the
## bag (docs/METAGAME.md §5), and a bottle is not in the bag. That is deliberate
## and it is the reason a draught is worth brewing before a deep run.
var bottle_contents: Array[StringName] = []

## Draught id -> seconds left, for the two that last. Ticked in `_process`
## beside stamina. Not saved: a 45-second buff restored by a load is a buff you
## spend the loading screen on, and every other timer in the game is the same.
var draughts: Dictionary[StringName, float] = {}
## Spelled once, here, for the same reason FORGE_* is: `sword_bonus()` and
## `armour_soak()` below read these ids, and a typo in either would be a potion
## that costs a slot and does nothing.
const DRAUGHT_EDGE_ID := &"emberblood_draught"
const DRAUGHT_PLATE_ID := &"ironhide_draught"

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
##
## The BOTTLES are appended to this at runtime by `quick_pool()` -- they are not
## in `items`, there are between one and four of them, and which ones exist is a
## thing the player changes at the alchemist. A const cannot answer that.
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
## [test] One empty bottle, for the same reason and with the same expiry date as
## STARTER_KIT: without it the alchemist's brew lines are unreachable until you
## have found the glass for a bottle, and the thing worth exercising is the brew.
## The other three are earned. See K.BOTTLE_START.


func _ready() -> void:
	_grant_starter_kit()


## Idempotent: `grant()` returns early on anything already owned, and the arrow
## top-up is a floor rather than an addition, so calling this from both boot and
## reset() cannot stack thirty arrows onto a quiver that already had them.
func _grant_starter_kit() -> void:
	for id in STARTER_KIT:
		grant(id)
	if arrows < STARTER_ARROWS:
		add_arrows(STARTER_ARROWS - arrows)
	while bottle_count() < K.BOTTLE_START:
		add_bottle()


func reset() -> void:
	max_quarters = K.START_HEARTS * K.HEART
	quarters = max_quarters
	max_magic = 0
	magic = 0
	rupees = 0
	gold = K.START_GOLD
	bag_slots = K.START_BAG_SLOTS
	upgrades.clear()
	components.clear()
	arrows = 0
	bombs = 0
	small_keys = 0
	has_boss_key = false
	has_map = false
	has_compass = false
	items.clear()
	bottle_contents.clear()
	draughts.clear()
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
	Bus.bottles_changed.emit(bottle_contents)
	Bus.components_changed.emit(components)
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
	_tick_draughts(delta)
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


## Hand stamina back outside the regen curve. A kill calls this (see Heat), and
## it deliberately does NOT touch `_stamina_hold`: the winded pause is the tell
## that you spent something, and clearing it on every kill would make a chain
## read as "stamina is off now" rather than as a reward. The refund lands on top
## of whatever the regen was already going to do.
func refund_stamina(amount: float) -> void:
	if amount <= 0.0 or stamina >= max_stamina:
		return
	stamina = minf(max_stamina, stamina + amount)
	Bus.stamina_changed.emit(stamina, max_stamina)


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


# --- The forge --------------------------------------------------------------
# Five ladders (K.FORGE_MAX rungs each), bought at the smith with gold AND
# components. Everything below is a READ of `upgrades`; ShopDb is the only thing
# that writes a rung, because a rung is a purchase and purchases have one till.
#
# Each accessor answers in the unit the gear actually uses, so no consumer ever
# indexes a K array or knows what a "level" is. That indirection is the whole
# point: when the shield's upgrade stops being an arc and becomes something
# else, `guard_arc()` changes and hero_combat.gd does not.

## Forge track ids. Spelled once, here, and used by ShopDb, the pouch screen and
## the save file -- three places that have already drifted apart once in this
## repo over how &"bow" is spelled (see ArmamentDb's header).
const FORGE_EDGE := &"edge"      ## the sword
const FORGE_PLATE := &"plate"    ## the armour
const FORGE_GUARD := &"guard"    ## the shield
const FORGE_STRING := &"string"  ## the bow
const FORGE_CHAIN := &"chain"    ## the hookshot
const FORGE_TRACKS: Array[StringName] = [
	FORGE_EDGE, FORGE_PLATE, FORGE_GUARD, FORGE_STRING, FORGE_CHAIN,
]


## How many rungs of `track` are bought, clamped so a corrupt save can never
## index a K array off the end.
func forge_level(track: StringName) -> int:
	return clampi(int(upgrades.get(track, 0)), 0, K.FORGE_MAX)


## Quarter-hearts the sword adds. Named `sword_bonus` for years; it is a
## function now because the number has a ladder behind it.
##
## Emberblood is added HERE rather than anywhere downstream, and that is the
## whole design of the draught: the swing, the HUD, the enemy's health bar and
## the smith's own "+2 -> +3" line all read this one function, so a potion that
## makes the blade bite harder needed no code in any of them.
func sword_bonus() -> int:
	return K.EDGE_DAMAGE[forge_level(FORGE_EDGE)] \
		+ (K.DRAUGHT_EDGE if draught_left(DRAUGHT_EDGE_ID) > 0.0 else 0)


## Quarter-hearts subtracted from every blow taken. `Hero.hurt` floors the
## result at one -- armour makes you last longer, never invincible, and that
## floor is what stops Ironhide on a full plate ladder from being immunity.
func armour_soak() -> int:
	return K.PLATE_SOAK[forge_level(FORGE_PLATE)] \
		+ (K.DRAUGHT_PLATE if draught_left(DRAUGHT_PLATE_ID) > 0.0 else 0)


## Half-angle, in degrees, of the arc the raised shield covers.
func guard_arc() -> float:
	return K.GUARD_ARC[forge_level(FORGE_GUARD)]


## Seconds a bow shot owns the hero, start to finish.
func bow_draw_time() -> float:
	return K.BOW_DRAW[forge_level(FORGE_STRING)]


## Metres the hookshot's chain reaches. Rung 3 is the Longshot.
func hook_reach() -> float:
	return K.CHAIN_REACH[forge_level(FORGE_CHAIN)]


# --- Components -------------------------------------------------------------
# The workbench stock. Filled by `Run.extract()` sorting them out of the bag,
# emptied by the forge. Never by anything else: a component that appeared
# without a run behind it would make the dungeon optional.

func component_count(id: StringName) -> int:
	return int(components.get(id, 0))


func add_component(id: StringName, n: int = 1) -> void:
	if n <= 0:
		return
	components[id] = component_count(id) + n
	Bus.components_changed.emit(components)


## Take `n` off the bench. Returns false and changes NOTHING when there are not
## enough, so a caller can use it as the check and the transaction at once --
## the same contract `spend_gold` keeps, for the same reason.
func spend_component(id: StringName, n: int) -> bool:
	if n <= 0:
		return true
	var have := component_count(id)
	if have < n:
		return false
	if have == n:
		components.erase(id)
	else:
		components[id] = have - n
	Bus.components_changed.emit(components)
	return true


## Can the bench pay a whole recipe? Checked before spending ANY of it, because
## a recipe half-paid is a player robbed.
func can_afford_parts(parts: Dictionary) -> bool:
	for id: StringName in parts:
		if component_count(id) < int(parts[id]):
			return false
	return true


# --- Bottles and draughts (docs/METAGAME.md §6.6) ---------------------------
# Four slots, at most, and what is in each. The alchemist writes them; the
# D-pad empties them. Nothing else touches `bottle_contents` -- a potion that
# appeared without a brew behind it would make the counter optional, which is
# the same rule the workbench keeps about the dungeon.

func bottle_count() -> int:
	return bottle_contents.size()


## What is in bottle `i`, or `&""` for an empty one and for an index you do not
## own. The two answer the same because every caller is drawing a cell: a bottle
## you have not bought and a bottle you have not filled are both "nothing here".
func bottle(i: int) -> StringName:
	if i < 0 or i >= bottle_contents.size():
		return &""
	return bottle_contents[i]


func empty_bottles() -> int:
	var n := 0
	for c in bottle_contents:
		if c == &"":
			n += 1
	return n


## Blow another one. Refuses past K.BOTTLE_MAX -- the cap is the design, not a
## sanity check (see K.BOTTLE_MAX).
func add_bottle() -> bool:
	if bottle_contents.size() >= K.BOTTLE_MAX:
		return false
	bottle_contents.append(&"")
	# Straight onto the first free button, exactly as a found item is (`grant`).
	# A bottle you paid for and then have to go and bind in a menu is a bottle
	# you do not have in the fight you bought it for.
	for i in quick_slots.size():
		if quick_slots[i] == &"":
			bind_quick(i, bottle_id(bottle_contents.size() - 1))
			break
	Bus.bottles_changed.emit(bottle_contents)
	return true


## Put `potion` in the first empty bottle. Returns its index, or -1 when every
## bottle is full -- the caller shows the refusal, because only the alchemist
## knows whether that would have cost the player their money.
func fill_bottle(potion: StringName) -> int:
	for i in bottle_contents.size():
		if bottle_contents[i] == &"":
			bottle_contents[i] = potion
			Bus.bottles_changed.emit(bottle_contents)
			return i
	return -1


## Drink bottle `i`. The bottle empties and STAYS -- glass is not a consumable,
## and a draught that ate its own bottle would make the four slots a currency
## instead of a loadout.
##
## Returns false when there is nothing in it, so the caller can play a refusal
## rather than a swallow.
func drink_bottle(i: int) -> bool:
	var potion := bottle(i)
	if potion == &"":
		return false
	if not PotionDb.apply(potion):
		return false
	bottle_contents[i] = &""
	Bus.bottles_changed.emit(bottle_contents)
	return true


## The quick-slot id for bottle `i`. Bottles bind one at a time and by index,
## because that is what the player reaches for: "the red one on ←", never "a
## bottle, whichever".
static func bottle_id(i: int) -> StringName:
	return StringName("bottle_%d" % (i + 1))


## The bottle a quick-slot id names, or -1 for anything that is not a bottle you
## own. Parsed rather than looked up, so owning three bottles and owning four is
## not two different tables.
func bottle_index(id: StringName) -> int:
	var s := String(id)
	if not s.begins_with("bottle_"):
		return -1
	var n := s.substr(7)
	if not n.is_valid_int():
		return -1
	var i := n.to_int() - 1
	return i if i >= 0 and i < bottle_contents.size() else -1


# --- Draughts ---------------------------------------------------------------

func draught_left(id: StringName) -> float:
	return float(draughts.get(id, 0.0))


func start_draught(id: StringName, seconds: float) -> void:
	draughts[id] = seconds
	Bus.draught_changed.emit(id, seconds)


## Run the clocks down. The only thing announced is the one that MATTERS -- a
## draught running out -- rather than a signal every frame: the HUD reads
## `draught_left()` while it draws its bar, the same way it reads health.
func _tick_draughts(delta: float) -> void:
	if draughts.is_empty():
		return
	for id: StringName in draughts.keys():
		var left := float(draughts[id]) - delta
		if left > 0.0:
			draughts[id] = left
			continue
		draughts.erase(id)
		Bus.draught_changed.emit(id, 0.0)


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


## Everything bindable RIGHT NOW, in bind-cycle order: the const pool, then one
## entry per bottle you own. A function rather than a const because the bottles
## are bought (see QUICK_POOL), and every caller that used to read QUICK_POOL
## reads this instead -- there is one answer to "what can go on a button" and
## the bind cycle, the ownership gate and the auto-bind all ask it here.
func quick_pool() -> Array[StringName]:
	var pool: Array[StringName] = QUICK_POOL.duplicate()
	for i in bottle_contents.size():
		pool.append(bottle_id(i))
	return pool


## Can `id` go on a button? The empty binding always can; an item has to be
## owned and a bottle has to exist. This is the gate `bind_quick` keeps, pulled
## out so the equipment screen can grey a row without re-deriving the rule.
func quick_bindable(id: StringName) -> bool:
	if id == &"":
		return true
	if bottle_index(id) >= 0:
		return true
	return QUICK_POOL.has(id) and has(id)


## Put `item_id` on a C-button. Refuses anything unowned, because a button that
## draws a bow you have never found is a button that lies about your inventory.
func bind_quick(slot: int, item_id: StringName) -> bool:
	if slot < 0 or slot >= quick_slots.size():
		return false
	if not quick_bindable(item_id):
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
	for id in quick_pool():
		if quick_bindable(id):
			available.append(id)
	if available.size() <= 1:
		return
	var at := available.find(quick(slot))
	bind_quick(slot, available[posmod(at + signi(dir), available.size())])


## Press a C-button: draw what is bound there, or put it away if it is already
## out. An unbound slot does nothing at all -- deliberately silent, because a
## refusal noise on a button you never assigned is noise about your own choice.
##
## A BOTTLE is drunk, not drawn. That asymmetry is the point of binding one: the
## bow is a thing you take out and then use, and a draught is a thing you use.
## Making the bottle a two-press item -- draw it, then press the use button --
## would put the slowest input in the game on the button you reach for when you
## are about to die.
func use_quick(slot: int) -> void:
	var id := quick(slot)
	var bottle_at := bottle_index(id)
	if bottle_at >= 0:
		# An empty bottle on a button is silent for the same reason an unbound
		# one is: you know it is empty, the HUD cell says so, and a buzzer in the
		# middle of a fight is the game shouting about a thing you already knew.
		drink_bottle(bottle_at)
		return
	if id == &"" or not has(id):
		return
	var live := clampi(loadout_set, 0, loadout.size() - 1)
	# Indexing an untyped Dictionary hands back Variant, so the comparison has
	# to be annotated or the parser cannot infer `stow`. See CLAUDE.md §3.
	var held: StringName = loadout[live][HAND_RIGHT]
	loadout[live][HAND_RIGHT] = &"sword" if held == id else id
	_announce_loadout()


## Put the sword back, whatever was in the right hand. Returns false if it was
## already there, so a caller can tell a real stow from a no-op.
##
## The escape hatch for a sticky draw. `use_quick` is a TOGGLE, which means the
## only way out of a drawn hookshot used to be remembering which of three D-pad
## directions you pressed to draw it -- and the player who wants their sword back
## is by definition the player who is not thinking about the D-pad. The attack
## button calls this, so the way out is the button you were already reaching for.
func stow_item() -> bool:
	var live := clampi(loadout_set, 0, loadout.size() - 1)
	var held: StringName = loadout[live][HAND_RIGHT]
	if held == &"sword" or held == &"":
		return false
	loadout[live][HAND_RIGHT] = &"sword"
	_announce_loadout()
	return true


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
