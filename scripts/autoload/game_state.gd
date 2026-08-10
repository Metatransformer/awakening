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
## Item id -> how many are in the footlocker in the hero's quarters. Persistent,
## for the same reason `components` is: everything in it already survived a run.
##
## Here rather than on `Run` because the whole point of it is that it does NOT
## die with the bag -- and here rather than folded into `components` because the
## bench is material the forge eats and this is merchandise the player decided
## not to sell yet. See `scripts/props/footlocker.gd`.
var stash: Dictionary[StringName, int] = {}
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

# --- The selected item ------------------------------------------------------
## Which bottle D-pad ↓ has stepped to, and X will use. An index into
## `bottle_contents`, so it means nothing until you own a bottle.
##
## THERE WAS A QUICK-SLOT BINDING SYSTEM HERE and it is gone. Four bindable D-pad
## directions, an ownership gate, an auto-bind on pickup, a bind cycle and a card
## on the equipment screen all existed to answer one question -- WHICH DIRECTION
## is the bow on -- and a cycle does not ask it. What binding bought was direct
## access: one press to the hookshot instead of two. What it cost was every
## player having to visit a menu before their new bow meant anything, and a HUD
## that had to draw four cells to say what one cell now says.
##
## Kept honest by `_clamp_item()` rather than by every caller: bottles are bought
## AND emptied AND (at the alchemist) rearranged, so an index that was valid when
## it was set is not an index that stays valid.
var item_selected: int = 0

# --- Armaments --------------------------------------------------------------
## Two loadouts, each with a right hand and a left hand, exactly as Elden Ring
## arranges them. Both the SET and the hands within it are changed on the
## equipment screen, which is the one place a change you have to look at belongs.
##
## In PLAY the thing that changes what is in the right hand is D-pad ← / →, which
## steps that hand through the weapons you own (`cycle_weapon`) without touching
## the set. D-pad ↑ swaps the set under it. The set is the pair; the ring is the
## one hand.
##
## The alternate set is bow and arrows, which is the point of having two: the
## primary answers "something is in front of me" and the alternate answers
## "something is not".
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
## What a new hero owns at boot, and it is **empty on purpose**.
##
## THE BOW AND THE HOOKSHOT USED TO BE IN HERE, with thirty arrows, as [test]
## scaffolding so the ranged items were reachable from a cold boot instead of
## from the chest that holds them. The comment that stood here said the kit was
## meant to be deleted and that deleting it was a two-line change; this is that
## deletion (docs/SCOPE.md M1, docs/GDD.md §5.2).
##
## What the kit was actually costing was every gate in the game. `has()` is the
## ownership check the smith, the locked doors and the boss drops all read, and
## a kit handed over in `_ready` made it answer yes on frame one — so nothing
## could be earned, the forge's bow and hookshot ladders sat on the counter from
## the first visit, and the equipment screen's "(not owned)" text described a
## state no player ever saw. The hero now starts with the sword, the shield and
## the rope: the first two are unconditional in `armament_owned()` and the third
## is a menu verb, so none of the three needs a row here.
##
## The constant survives the deletion because the NEXT thing handed over at boot
## goes here — a demo build that starts you with the bow, a debug loadout — and
## one empty array is a cheaper place for that than a new function. The arrows
## went with the bow: a quiver you cannot fire is a slot that lies, which is the
## same rule `armament_owned(&"arrow")` already keeps.
const STARTER_KIT: Array[StringName] = []


func _ready() -> void:
	_grant_starter_kit()


## Idempotent: `grant()` returns early on anything already owned and the bottle
## loop is a floor rather than an addition, so calling this from both boot and
## reset() cannot stack a second bottle onto one that already exists.
##
## The bottle is NOT scaffolding and did not go with the kit. K.BOTTLE_START is a
## design number (docs/METAGAME.md §6.6) — the alchemist needs an empty bottle
## before he will brew anything, and starting with one is what makes his counter
## a place you can use on your first trip rather than after a purchase. Note that
## K.BOTTLE_START's own comment still claims it expires with the starter kit;
## that comment is now wrong and `scripts/core/consts.gd` needs the correction.
func _grant_starter_kit() -> void:
	for id in STARTER_KIT:
		grant(id)
	while bottle_count() < K.BOTTLE_START:
		add_bottle()


func reset() -> void:
	max_quarters = K.START_HEARTS * K.HEART
	quarters = max_quarters
	# Focus raises this, so a reset has to put it back. It did not need clearing
	# while nothing could buy it.
	max_stamina = K.MAX_STAMINA
	stamina = max_stamina
	max_magic = 0
	magic = 0
	rupees = 0
	gold = K.START_GOLD
	bag_slots = K.START_BAG_SLOTS
	upgrades.clear()
	components.clear()
	stash.clear()
	arrows = 0
	bombs = 0
	small_keys = 0
	has_boss_key = false
	has_map = false
	has_compass = false
	items.clear()
	bottle_contents.clear()
	draughts.clear()
	item_selected = 0
	loadout = [
		{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
		{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
	]
	loadout_set = PRIMARY
	flags.clear()
	# Say that the hands and the selection emptied. Without this, resetting
	# cleared `items` and `loadout` in silence and every listener kept drawing
	# the gear it last heard about — a hero still wearing a stowed bow he no
	# longer owns. Announcing state is not optional for state nobody polls.
	_announce_loadout()
	Bus.item_selected_changed.emit(item_selected)
	Bus.bottles_changed.emit(bottle_contents)
	Bus.components_changed.emit(components)
	Bus.stash_changed.emit(stash)
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


## One more heart, from either faucet -- the smith's `heart` line or a Vigor
## amulet. Ceiling enforced HERE rather than in the two shops, so a third source
## cannot arrive and quietly raise it (K.HEART_MAX, and the note over K.SOAK_MAX
## about why ceilings belong to the number).
##
## Stored rather than derived, unlike soak and speed, and that is on purpose:
## `max_quarters` is read straight by the HUD, by `hurt` and by `heal`, and a
## Vigor amulet that returned its hearts from an accessor would need every one of
## those to change. The smith's heart line already worked this way; Vigor is the
## same purchase with a different sign over the counter.
func add_heart_container() -> void:
	if max_quarters >= K.HEART_MAX * K.HEART:
		return
	max_quarters += K.HEART
	quarters = max_quarters
	Bus.player_health_changed.emit(quarters, max_quarters)


## How many heart containers the player has. The unit the shops and the
## equipment screen both count in.
func heart_containers() -> int:
	return max_quarters / K.HEART


## More bar, from a Focus amulet. Stored for the same reason hearts are: the HUD
## and every `spend_stamina` caller read `max_stamina` directly.
func add_max_stamina(points: float) -> void:
	max_stamina = minf(K.STAMINA_MAX, max_stamina + points)
	stamina = max_stamina
	Bus.stamina_changed.emit(stamina, max_stamina)


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
	# `stamina_regen()`, not `K.STAMINA_REGEN`: the Wind bracelet lives in that
	# accessor and this is the only place the bar actually refills.
	stamina = minf(max_stamina, stamina + stamina_regen() * delta)
	Bus.stamina_changed.emit(stamina, max_stamina)


## Spend, or refuse. Returns false when there is not enough, and the caller is
## expected to NOT perform the action -- otherwise the bar and the dodge
## disagree, which is worse than having no bar.
##
## `partial` is the SWING rule, and it is a different rule (K.STAMINA_SWING).
## Strict, the bar must hold the whole cost or nothing happens: that is right for
## a dodge, where a roll that half happens is a death, and it is why three rolls
## from full is exactly three. Partial, any stamina above zero buys the action
## and the cost clamps at the floor -- so a chain is never interrupted between
## its own steps, it simply leaves you with nothing afterwards. Elden Ring prices
## attacks the second way and dodges the first, and the reason is legibility: a
## swing refused halfway through a combo reads as the game dropping an input,
## while an empty bar after the combo reads as a decision you made.
func spend_stamina(cost: float, partial: bool = false) -> bool:
	if cost <= 0.0:
		return true
	if stamina < cost and not partial:
		return false
	if stamina <= 0.0:
		return false
	stamina = maxf(0.0, stamina - cost)
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
# Twelve ladders (K.FORGE_MAX rungs each), bought at the smith with gold AND
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
## RETIRED 2026-08-09 by the four-piece split (docs/GDD.md §6.6). Kept as a
## spelling, not as a track: `ShopDb` no longer stocks it, nothing reads it, and
## a v3 slot that still holds it is REFUSED rather than migrated (see
## `SaveGame.VERSION` for why). Nothing may put it back in `FORGE_TRACKS`.
const FORGE_PLATE := &"plate"    ## the armour, until it became four
const FORGE_GUARD := &"guard"    ## the shield
const FORGE_STRING := &"string"  ## the bow
const FORGE_CHAIN := &"chain"    ## the hookshot

## The armour's four pieces and its two paths, spelled once.
##
## A track id is `plate_<piece>_<path>` and that is the WHOLE of the split's
## storage: `upgrades` stays `{track: int}`, no piece has a record of its own,
## and "which path did this piece commit to" is answered by asking which of the
## two siblings has a rung in it. Nothing new is saved (GDD §6.6).
const PLATE_PIECES: Array[StringName] = [&"chest", &"legs", &"arms", &"boots"]
const PLATE_HEAVY := &"heavy"
const PLATE_LIGHT := &"light"
const PLATE_TRACKS: Array[StringName] = [
	&"plate_chest_heavy", &"plate_chest_light",
	&"plate_legs_heavy", &"plate_legs_light",
	&"plate_arms_heavy", &"plate_arms_light",
	&"plate_boots_heavy", &"plate_boots_light",
]

## The jewelcrafter's four slots. Both rings draw on the same pair of paths on
## purpose -- two Edge rings and one of each are different builds, and that is
## where the variety comes from without a ninth path existing (GDD §6.6).
const JEWEL_SLOTS: Array[StringName] = [&"amulet", &"ring1", &"ring2", &"bracelet"]
const JEWEL_TRACKS: Array[StringName] = [
	&"jewel_amulet_vigor", &"jewel_amulet_focus",
	&"jewel_ring1_edge", &"jewel_ring1_swift",
	&"jewel_ring2_edge", &"jewel_ring2_swift",
	&"jewel_bracelet_ward", &"jewel_bracelet_wind",
]

const FORGE_TRACKS: Array[StringName] = [
	FORGE_EDGE, FORGE_GUARD, FORGE_STRING, FORGE_CHAIN,
	&"plate_chest_heavy", &"plate_chest_light",
	&"plate_legs_heavy", &"plate_legs_light",
	&"plate_arms_heavy", &"plate_arms_light",
	&"plate_boots_heavy", &"plate_boots_light",
]


## The two track ids a piece can commit to, heavy first.
static func plate_track(piece: StringName, path: StringName) -> StringName:
	return StringName("plate_%s_%s" % [piece, path])


static func jewel_track(slot: StringName, path: StringName) -> StringName:
	return StringName("jewel_%s_%s" % [slot, path])


## The other path for the same piece or slot -- `plate_chest_heavy` <->
## `plate_chest_light`. Empty for anything that is not a two-path track.
##
## String surgery rather than a lookup table because the table would be a
## sixteen-row restatement of the naming rule, and the two would drift. The rule
## is: everything up to the last underscore is WHICH THING, and after it is WHICH
## PATH. `_pair_of` is the only place that knows it.
static func sibling_of(track: StringName) -> StringName:
	var s := String(track)
	var cut := s.rfind("_")
	if cut < 0:
		return &""
	var stem := s.substr(0, cut)
	var path := s.substr(cut + 1)
	var pair := _pair_of(path)
	if pair == &"":
		return &""
	return StringName("%s_%s" % [stem, pair])


static func _pair_of(path: String) -> StringName:
	match path:
		"heavy": return PLATE_LIGHT
		"light": return PLATE_HEAVY
		"vigor": return &"focus"
		"focus": return &"vigor"
		"edge": return &"swift"
		"swift": return &"edge"
		"ward": return &"wind"
		"wind": return &"ward"
		_: return &""


## True once this piece or slot has taken a rung on the OTHER path, which closes
## this one for good. GDD §6.6: "A path you committed is a path you committed."
func path_closed(track: StringName) -> bool:
	var other := sibling_of(track)
	return other != &"" and int(upgrades.get(other, 0)) > 0


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
	var permanent := float(K.EDGE_DAMAGE[forge_level(FORGE_EDGE)])
	for slot: StringName in [&"ring1", &"ring2"]:
		permanent += K.JEWEL_EDGE_DAMAGE * float(jewel_level(jewel_track(slot, &"edge")))
	# Floored, then capped, then the draught on top. The cap is the NUMBER's
	# (K.EDGE_MAX), not the forge's and not the rings' -- see the note over
	# K.SOAK_MAX about faucets.
	return mini(int(floorf(permanent)), K.EDGE_MAX) \
		+ (K.DRAUGHT_EDGE if draught_left(DRAUGHT_EDGE_ID) > 0.0 else 0)


## Quarter-hearts subtracted from every blow taken. `Hero.hurt` floors the
## result at one -- armour makes you last longer, never invincible, and that
## floor is what stops Ironhide on a full plate ladder from being immunity.
func armour_soak() -> int:
	return int(floorf(armour_soak_exact())) \
		+ (K.DRAUGHT_PLATE if draught_left(DRAUGHT_PLATE_ID) > 0.0 else 0)


## The permanent soak before flooring, in quarter-hearts. Public because the
## shop's before/after line and the equipment screen both want to show the
## fraction -- a heavy chest rung that moves 0.7 -> 1.0 has to be able to SAY so,
## or it reads as a purchase that did nothing (see the note over K.PLATE_HEAVY_SOAK).
##
## Draughts are not in here. They are 45 seconds long; this is the build.
func armour_soak_exact() -> float:
	var total := 0.0
	for piece: StringName in PLATE_PIECES:
		total += K.PLATE_HEAVY_SOAK[forge_level(plate_track(piece, PLATE_HEAVY))]
		total += K.PLATE_LIGHT_SOAK[forge_level(plate_track(piece, PLATE_LIGHT))]
	total += K.JEWEL_WARD_SOAK * float(jewel_level(jewel_track(&"bracelet", &"ward")))
	return minf(total, K.SOAK_MAX)


## What every locomotion speed is multiplied by: heavy plate takes it away and a
## Swift ring buys it back.
##
## Clamped to 1.0 at the top. Pillar 1 -- `K.RUN_SPEED` is [oot], measured, and
## the feel is not negotiable -- so jewellery can undo a penalty and can never
## make the hero faster than the source material. Clamped to 0.5 at the bottom
## as a corrupt-save guard; the authored floor is 0.92.
func speed_mult() -> float:
	return clampf(speed_mult_raw(), 0.5, 1.0)


## The same product BEFORE the clamp. Public for one reason: the smith's
## before/after line has to be able to say that a heavy rung will cost you
## nothing because two Swift rings are already holding you at the ceiling.
## Multiplying the CLAMPED figure would print a drop that is not going to happen,
## which is a shop lying about its own prices.
func speed_mult_raw() -> float:
	var m := 1.0
	for piece: StringName in PLATE_PIECES:
		m *= K.PLATE_HEAVY_SPEED[forge_level(plate_track(piece, PLATE_HEAVY))]
	for slot: StringName in [&"ring1", &"ring2"]:
		m *= pow(K.JEWEL_SWIFT_SPEED, float(jewel_level(jewel_track(slot, &"swift"))))
	return m


## Stamina points a second, with the Wind bracelet on it. Read by `tick_stamina`;
## nothing else may read `K.STAMINA_REGEN` directly any more.
func stamina_regen() -> float:
	var rungs := jewel_level(jewel_track(&"bracelet", &"wind"))
	return K.STAMINA_REGEN * (1.0 + K.JEWEL_WIND_REGEN * float(rungs))


## How many rungs of a JEWEL path are bought. Separate from `forge_level` only
## because the ceiling differs -- `K.JEWEL_MAX` is 4, one deeper than a forge
## ladder, since a jewel has no rung 0 you already own (GDD §6.6).
func jewel_level(track: StringName) -> int:
	return clampi(int(upgrades.get(track, 0)), 0, K.JEWEL_MAX)


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


# --- The footlocker ---------------------------------------------------------
# The chest at the foot of the bed in the hero's quarters. Merchandise you
# carried home and decided not to sell yet.
#
# **It is the bag's shelf, not a second bag.** The only doors in and out are
# `Footlocker`'s screen, both sides of which go through `Run` -- so the bag's
# bookkeeping (the erase, the heat premium, the slot count) stays in the one
# file that owns it, exactly as `consume()` says. Nothing here ever creates an
# item; an ingredient that appeared in the locker without a run behind it would
# make the dungeon optional, which is the rule `add_component` keeps about the
# workbench and the same rule.
#
# It counts SLOTS the way the bag does -- `ceil(count / def.stack)` -- because
# it is the same objects on the same shelves and a locker that measured its
# space differently would be a second answer to "how much is a lot".

func stash_count(id: StringName) -> int:
	return int(stash.get(id, 0))


func stash_slots_used() -> int:
	var used := 0
	for id: StringName in stash:
		var def := ItemDb.get_def(id)
		var per: int = def.stack if def != null else 1
		used += int(ceil(float(stash[id]) / float(maxi(per, 1))))
	return used


func stash_full() -> bool:
	return stash_slots_used() >= K.STASH_SLOTS


## How many more of `id` the locker will take. Asked rather than assumed, so the
## screen can grey a row out instead of finding out halfway through a transfer.
func stash_room_for(id: StringName) -> int:
	var def := ItemDb.get_def(id)
	if def == null:
		return 0
	var per: int = maxi(def.stack, 1)
	var have := stash_count(id)
	# The part-filled stack this id already owns is free space nobody else can
	# use, so it is room whether or not a slot is left.
	var slack := (per - have % per) % per
	var free_slots := maxi(K.STASH_SLOTS - stash_slots_used(), 0)
	return slack + free_slots * per


## Put `n` of `id` in the locker. Returns how many fit -- a full locker is a real
## event the caller has to show, not an error to swallow (`Run.collect`'s rule).
func stash_add(id: StringName, n: int) -> int:
	if n <= 0 or ItemDb.get_def(id) == null:
		return 0
	var took := mini(n, stash_room_for(id))
	if took <= 0:
		return 0
	stash[id] = stash_count(id) + took
	Bus.stash_changed.emit(stash)
	return took


## Take `n` of `id` back off the shelf. Returns how many came out.
func stash_take(id: StringName, n: int) -> int:
	var have := stash_count(id)
	if have <= 0 or n <= 0:
		return 0
	var took := mini(n, have)
	if took >= have:
		stash.erase(id)
	else:
		stash[id] = have - took
	Bus.stash_changed.emit(stash)
	return took


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
	# The new bottle is on the ring the moment it is bought -- that is what a
	# cycle gives you for free, and it is what the auto-bind existed to fake.
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


## The item id for bottle `i`. Bottles are addressed one at a time and by index,
## because that is what the player reaches for: "the red one on ←", never "a
## bottle, whichever".
static func bottle_id(i: int) -> StringName:
	return StringName("bottle_%d" % (i + 1))


## The bottle an id names, or -1 for anything that is not a bottle you
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

## Finding a weapon puts it in the cycle and nothing else happens -- no auto-bind
## and no menu trip, because there is no longer a button for it to land on. The
## bow you just found is one press of D-pad → away, which is what the auto-bind
## was for.
func grant(item_id: StringName) -> void:
	if items.get(item_id, false):
		return
	items[item_id] = true
	Bus.item_acquired.emit(item_id)


## **THE ownership gate.** There is one, it is this, and there is no `has_item()`
## — docs/GDD.md §5.2 and docs/SCOPE.md M1 both name the check `Game.has_item()`
## in prose, but the function has been called `has()` since the item dictionary
## existed and adding a one-line alias would be the second implementation of a
## boolean (CLAUDE.md §0). The docs are what should move.
##
## Everything that asks "may this happen yet" comes through here:
##
##  * `ShopDb.lines()` hides the bow and hookshot forge ladders, and the arrow
##    stock line, until the item behind them is owned.
##  * `LockedDoor` refuses, and names the item it wants, off one call.
##  * `armament_owned()` gates the weapon ring, and hangs `&"arrow"` off the bow.
##
## Which is why the starter kit above is empty: a gate that answers yes at boot
## is not a gate, and this one function is the reason M1 is a deletion and three
## filters rather than a system.
func has(item_id: StringName) -> bool:
	return items.get(item_id, false)


# --- The selected item ------------------------------------------------------

## Which bottle is under D-pad ↓ right now, or `&""` if you own none.
func selected_item() -> StringName:
	_clamp_item()
	return bottle_id(item_selected) if bottle_count() > 0 else &""


## What is IN the selected bottle, or `&""` for empty and for no bottle at all.
## The HUD draws this; `selected_item()` is what names the glass around it.
func selected_potion() -> StringName:
	_clamp_item()
	return bottle(item_selected)


## D-pad ↓. Steps to the next bottle, wrapping.
##
## Steps through ALL of them, empties included, and that is deliberate: an empty
## bottle is a thing you own and are about to fill, and a cycle that silently
## skipped it would put the player's four bottles on a ring whose length changed
## every time they drank. A ring you can count is a ring you can use blind.
func cycle_item(dir: int = 1) -> void:
	var n := bottle_count()
	if n <= 1:
		return
	item_selected = posmod(_clamped_item() + signi(dir), n)
	Bus.item_selected_changed.emit(item_selected)


## X. Drink what is selected. Silent on an empty bottle and on no bottle at all,
## for the same reason the old unbound slot was: you know it is empty, the HUD
## cell says so, and a buzzer in the middle of a fight is the game shouting about
## a thing you already knew.
##
## A bottle is USED, never drawn. That asymmetry is why items and weapons are on
## different inputs at all: the bow is a thing you take out and then fire, and a
## draught is a thing you swallow. Making the bottle a two-press item -- draw it,
## then press the trigger -- would put the slowest input in the game on the
## button you reach for when you are about to die.
func use_selected_item() -> bool:
	if bottle_count() == 0:
		return false
	return drink_bottle(_clamped_item())


## D-pad ← / →. Step the right hand through the weapons you own.
##
## A thin wrapper over `cycle_armament`, which the equipment screen has always
## used, so the button and the menu are the same code and cannot drift. It exists
## as its own name because the CALLER means something different: the screen is
## editing a set, and this is the player reaching for a weapon.
func cycle_weapon(dir: int = 1) -> void:
	cycle_armament(HAND_RIGHT, dir)


## Put the sword back, whatever was in the right hand. Returns false if it was
## already there, so a caller can tell a real stow from a no-op.
##
## NOTHING CALLS THIS, and it is kept anyway -- with that said out loud, because
## a docstring listing callers it does not have is how the next reader gets
## misled. It was the light button's escape hatch (hero_combat `_begin`) until
## the sword became a stop on the weapon ring and ← / → became the way back. What
## it is here for is the case that has not been written yet: taking a drawn bow
## out of the hero's hands WITHOUT the player asking -- a cutscene, or a scene
## change that must not leave him aiming at a vendor. If that case never arrives,
## delete this rather than finding it a job.
func stow_item() -> bool:
	var live := clampi(loadout_set, 0, loadout.size() - 1)
	var held: StringName = loadout[live][HAND_RIGHT]
	if held == &"sword" or held == &"":
		return false
	loadout[live][HAND_RIGHT] = &"sword"
	_announce_loadout()
	return true


## The selection, forced back inside the bottles that exist. Bottles are bought,
## emptied and refilled, so an index that was valid when it was set is not an
## index that stays valid -- and the failure is silent (you press X and drink a
## bottle you were not looking at) rather than loud.
func _clamped_item() -> int:
	return clampi(item_selected, 0, maxi(0, bottle_count() - 1))


func _clamp_item() -> void:
	var at := _clamped_item()
	if at != item_selected:
		item_selected = at
		Bus.item_selected_changed.emit(item_selected)


# --- Armaments --------------------------------------------------------------

## What is in `hand` (Game.HAND_RIGHT / HAND_LEFT) in the live set.
func armament(hand: StringName) -> StringName:
	var set_data: Dictionary = loadout[clampi(loadout_set, 0, loadout.size() - 1)]
	return set_data.get(hand, &"")


## Swap primary <-> alternate. D-pad ↑, and the equipment screen's Swap Set
## button -- one function, so the two cannot disagree.
##
## ↑ is the direction Elden Ring spends on its spell row, which this game has no
## content for; a set swap is the coarsest gear change there is, so it gets the
## direction that is not stepping anything. If a third set is ever added this
## becomes a wrapping step; it is a bool toggle today because there are two.
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
