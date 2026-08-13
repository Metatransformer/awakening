extends Node
## Autoload `Game`. The save-able truth about the run: health, magic, keys,
## items, world flags. Nothing in here touches the scene tree.
##
## Health is counted and presented as integer HP.

const GarrisonRaidStateScript := preload(
	"res://scripts/systems/garrison_raid_state.gd")
const GardenStateScript := preload("res://scripts/systems/garden_state.gd")

signal garrison_changed
signal garrison_raid_restoring

## Local developer-only state. Deliberately absent from Saves.
var dev_god_mode: bool = false

var max_health_points: int = K.START_HEALTH_POINTS
var health_points: int = K.START_HEALTH_POINTS
var temporary_overhealth: int = 0

## The blue bar. **Full from the first frame of a new save**, which is a change
## from the meter this started as: it was OOT's, granted by a Great Fairy, and
## `unlock_magic` sat here for months with nothing in the game ever calling it.
##
## It is on from the start because of what it now prices. Magic is the cost of
## the charged spin (K.MAGIC_SPIN), and the spin is in the player's hands on the
## first floor -- a resource that gates a move you already have cannot be a
## reward you find later without the move being free until you find it, which is
## exactly the state that got reported as cheesing.
##
## The one rule that makes it work: **it does not regenerate underground.**
## `Run.enter`, `Run.extract` and `Run.die` fill it and nothing else does, so
## what the bar measures is how much of this TRIP you have spent. Contrast
## stamina above, which comes back in two seconds and therefore prices rhythm
## rather than frequency.
var max_magic: int = K.MAX_MAGIC
var magic: int = K.MAX_MAGIC

## Stamina is what makes the dodge a decision -- see K.MAX_STAMINA for why this
## exists at all when the source material has no such thing. Unlike everything
## else here it is NOT save-able state: it refills on its own in a couple of
## seconds, so persisting it would only ever restore a number that is about to
## be 100 anyway.
var max_stamina: float = K.MAX_STAMINA
var stamina: float = K.MAX_STAMINA
## Counts down from K.STAMINA_DELAY after a spend. Regen is frozen while > 0.
var _stamina_hold: float = 0.0
## Fractions of an HP that mercy has forgiven but not yet spent. See
## `_softened`. Not saved: it is less than 1 HP of credit, and
## a number in the save file for it would be the accessibility toggle leaving
## archaeology behind.
var _mercy_carry: float = 0.0

var rupees: int = 0
## How many times this save has died. Bumped by `Run.die()`.
##
## It exists for one reason -- it is the dial mercy turns (GDD §7.1, `mercy_rate`)
## -- and it is saved because a resistance that reset every time the player
## quit would be forgiveness the stuck player has to earn again every evening.
## Nothing else reads it, and nothing else should: a death count on a HUD or a
## plaque would be the game keeping score of the thing §7.1 exists to stop
## keeping score of.
var deaths: int = 0
## Metagame currency. Survives death; the bag in `Run` does not.
var gold: int = K.START_GOLD
## Every coin this save has ever been GIVEN, and never a coin back.
##
## Separate from `gold` above because the two answer different questions and the
## difference is the whole point: `gold` is what you can spend and it goes down
## every time you do, and this is how far you have got, which cannot. `StoryDb`
## gates the garrison's later conversations on it (`StoryDb.met`) — an old man's
## story that vanished the moment you bought a sharpening would be a bug the
## player could cause and never explain.
##
## Not seeded with `K.START_GOLD`: the purse you arrive with was not earned.
var gold_earned: int = 0
## Society Field Notes already filed through the bedside book. Completion and
## filing are separate permanent sets: a run-end records what happened, while
## the book awards its authored value exactly once when the player files it.
var field_notes: int = 0
var completed_field_observations: Dictionary[StringName, bool] = {}
var awarded_field_observations: Dictionary[StringName, bool] = {}
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
## Manually pinned recipe tracks. Keys are Wishlist's stable catalogue namespace
## plus authored line id; current ingredients remain derived from catalogue data.
var wishlist_lines: Dictionary[StringName, bool] = {}
## Component id -> how many are on the workbench. Persistent: components that
## reached the garrison survive death, because they were already paid for by the
## run that carried them home (`Run.extract` banks them). Components still in
## the bag when you die are gone with it.
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
## Burst charges (`docs/GDD.md` §6.5). **This is the field that used to be
## `bombs`, renamed and not added to** -- the working replaced the satchel, so
## the counted resource behind it is the same counted resource with the noun the
## design settled on. `docs/SCOPE.md` §1 allows the working "no new save field
## beyond the ones an owned item and a counted resource already need", and this
## is that field; `save_game.gd` still reads the old `bombs` key so a save made
## before the rename keeps its stock.
##
## Bought from the alchemist and **never refilled underground**: there is no
## rest, and saving/loading restores the same trip budget rather than refreshing
## it. A resource that came back mid-run would soften the walk home that
## `docs/METAGAME.md` §2 is built on.
var charges: int = 0
var max_charges: int = K.BURST_CHARGES_MAX
## Carried Escape Ropes. Provision stock, not an item, ration or run-bag line.
var escape_ropes: int = 0

# --- Bottles (docs/METAGAME.md §6.6) ----------------------------------------
## What is in each bottle you own, in order. The ARRAY'S SIZE is how many
## bottles you have -- there is no separate count, because a count and a list
## that can disagree is a bottle that exists in the HUD and not in the fridge.
## `&""` is an empty bottle, and an empty bottle is the thing the alchemist
## needs before he will brew anything.
##
## Persistent, like gold and the workbench: a bottle is a purchase and what is
## in it was paid for in the garrison. Death does not take it -- what death
## takes is the bag (docs/METAGAME.md §5), and a bottle is not in the bag. That
## is deliberate and it is the reason a draught is worth brewing before a deep
## run.
var bottle_contents: Array[StringName] = []

# --- Rations (docs/METAGAME.md §6.4) ----------------------------------------
## Ration id -> how many are in the pack, capped at `K.RATION_STACK` each. The
## quartermaster's food and drink; see `RationDb` for what they do.
##
## A DICTIONARY of stacks rather than a second `bottle_contents`-shaped array,
## because the two items are the opposite shape to a draught: what limits a
## draught is the glass it is in (a slot), and what limits a ration is the stack
## and the twelve seconds it takes to eat. There are two ids and there will not be
## a third without a design change, so the dictionary is doing one job -- keeping
## "which ration" and "how many" in one place that `save_game.gd` can write out as
## it stands.
##
## Persistent, like `bottle_contents` and for the same reason: a ration is a
## purchase made in the garrison. Death takes the BAG (docs/METAGAME.md §5), and
## the pack is not the bag.
var rations: Dictionary[StringName, int] = {}

## The meal in progress: which ration is being eaten, how long is left of it, and
## how long until the next tick pays out. `&""` is nobody eating.
##
## **This is a clock, and it goes here beside the draughts' clock rather than on
## the hero for the reason spelled out on `draughts`**: this file is the one thing
## in the project with a tick, a clamp and a signal already, and a second timer
## living on an actor is a second thing to leave running through a scene change.
## The hero owns the POSE and the cancel; `Game` owns the counter.
##
## Not saved. Twelve seconds of sitting restored by a load would be a meal you
## spend the loading screen on, which is the argument `draughts` makes and the
## same answer: `cancel_meal()` runs on `reset()` and on every scene change that
## touches the hero.
var meal_id: StringName = &""
var meal_left: float = 0.0
## How many of the meal's ticks have already been paid into a bar. A COUNT and not
## a second countdown -- see `_tick_meal` for why the countdown was wrong.
var _meal_paid: int = 0

## Draught id -> seconds left, for the two that last. Ticked in `_process`
## beside stamina. Not saved: a 45-second buff restored by a load is a buff you
## spend the loading screen on, and every other timer in the game is the same.
##
## **Ballast's soak window rides in here too** (`BALLAST_ID`), and it is not a
## draught. This is the game's one table of "a thing that is true right now and
## will not be shortly", with one tick, one clamp and one signal; a second timer
## dictionary for a working would be a second `_tick_draughts` to forget to call
## and a second way for a window to be left running through a scene change. What
## the field is named after is the only thing that ever used it, which is a worse
## reason to fork it than to widen this note.
var draughts: Dictionary[StringName, float] = {}
## Spelled once, here, for the same reason FORGE_* is: `sword_bonus()` and
## `armour_soak()` below read these ids, and a typo in either would be a potion
## that costs a slot and does nothing.
const DRAUGHT_EDGE_ID := &"emberblood_draught"
const DRAUGHT_PLATE_ID := &"ironhide_draught"
## Ballast's window (`docs/GDD.md` §6.5). Deliberately NOT spelled
## `ballast_draught`: it is not brewed, not bottled and not on the alchemist's
## board, so it is not a row in `PotionDb` and never will be.
##
## **It has a slot on the HUD's draught row anyway** (#39). It used to be kept out
## of that row by the row deriving itself from `PotionDb.IDS`, and the argument
## written here was that the health bar was enough -- a blow that costs 1 HP
## instead of 3 HP, and the stack that left the bag paying for it. That
## is inference, not an instrument: it says a ward is up only once you have
## already been hit by something, and it never says HOW LONG IS LEFT, which for an
## eight-second window bought with a bag stack is the only question the player is
## actually asking. So the row is derived from `LASTING_IDS` below instead.
const BALLAST_ID := &"ballast"

## Everything that rides in `draughts`, in the order the HUD draws it. **This is
## the draught row's slot list**, and it lives here rather than in `hud.gd`
## because the ids do -- `Hud._draught_slots` used to walk `PotionDb.IDS` and keep
## its own `id == DRAUGHT_PLATE_ID or id == DRAUGHT_EDGE_ID` filter, which is a
## second copy of this list wearing a different hat: it could not have grown by a
## slot without being edited, whatever it was reading the names from (#39,
## docs/HUD_PLAN.md §15.16).
##
## Order is Ironhide, Emberblood, Ballast rather than alphabetical or historical:
## the two brewed ones stay adjacent and in `PotionDb.IDS` order, so a player who
## learned the row before Ballast existed finds both where they left them.
const LASTING_IDS: Array[StringName] = [
	DRAUGHT_PLATE_ID, DRAUGHT_EDGE_ID, BALLAST_ID,
]

## Small Keys belong to the floor where they were found. `small_keys` remains the
## compatibility surface for gates and directors, but reads and assignments are
## always redirected to the floor `Run.level` names right now.
const SMALL_KEYS_PER_FLOOR_MAX := 99
var small_keys_by_floor: Dictionary[int, int] = {}
var small_keys: int:
	get:
		return small_keys_for_floor(Run.level)
	set(value):
		set_small_keys_for_floor(Run.level, value)
var has_boss_key: bool = false
## The authored floor whose Boss Key is currently held. A run can backtrack, so
## the boolean alone is not enough to stop floor 2's key opening floor 1's door.
var boss_key_level: int = 0
var has_map: bool = false
var has_compass: bool = false

## Item ids the player owns, e.g. &"hookshot".
var items: Dictionary[StringName, bool] = {}
## Durable utility tool id -> uses remaining. Zero is retained as the durable
## fact that a tool was made and broke; positive entries mirror into `items`.
var tool_durabilities: Dictionary[StringName, int] = {}

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
## **All six of the ring's stops** (`docs/CONTRACT.md` §4.1, `docs/SCOPE.md` §1 --
## sword, bow, hookshot, Burst, Sustain, Ballast, and a seventh costs a sixth).
## The three workings go in here and nowhere else: a working is a usable item, so
## what makes it castable is a row in this array, a row in `ArmamentDb`, and
## `armament_owned()` saying you own it. There is no casting layer and this line
## is the proof of it.
##
## This array is the manifest's **ring stops: 6** row, spelled out. Six is where
## counting stops being free, so a seventh entry here is not a feature, it is an
## amendment to `docs/SCOPE.md` -- and the argument it has to beat is CONTRACT
## §4.1's, which chose a ring over bindable slots precisely because a ring can be
## counted.
const RIGHT_POOL: Array[StringName] = [&"sword", &"bow", &"hookshot",
	&"burst", &"sustain", &"ballast"]
const LEFT_POOL: Array[StringName] = [&"shield", &"arrow", &""]

var loadout: Array[Dictionary] = [
	{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
	{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
]
var loadout_set: int = PRIMARY

# --- The kit wheel ----------------------------------------------------------
## Eight slots, held on LB, pointed at with the right stick or the mouse, and
## committed on the RELEASE. Each holds one thing the hero owns, and the wheel
## does not care which kind: a right-hand armament goes into the right hand, a
## bottle becomes the selected item that X drinks. `wheel_select()` is the one
## place that decides which, off the id alone.
##
## **This is not the quick-slot system CONTRACT §4.1 deleted**, and the
## difference is worth writing down because the argument that deleted it is a
## good one and still stands. What killed the D-pad bindings was that every
## direction meant *whatever you last decided* — you had to REMEMBER which of
## four buttons the bow was on, and you had to visit a menu before a bow you
## just found meant anything at all. A wheel answers both, and it is the only
## shape that does: it **shows you every binding while you hold it**, so there is
## nothing to remember, and `wheel_auto_bind()` puts a new item on a free slot at
## the moment it is picked up, so the menu trip is optional rather than the price
## of admission. The three D-pad rings are untouched (`cycle_weapon`,
## `cycle_item`, `swap_loadout`); the wheel is a faster door onto the same two
## fields, never a second copy of them.
##
## **Eight, and the number is doing work.** Six is the weapon ring's ceiling
## (`RIGHT_POOL`, `docs/SCOPE.md` §1) and four is the bottle ceiling
## (`K.BOTTLE_MAX`), so ten is what a player can own — and eight is deliberately
## short of it. A wheel with a slot for everything is a wheel you never curate,
## which is the same failure as a hotbar: the point of holding LB is that the
## four things you actually reach for are each a flick away, and a flick has to
## be a DIRECTION rather than a search. Eight sectors are the eight compass
## points, which is the largest set a thumb can hit blind. A ninth is not a
## constant, it is an amendment to that sentence.
##
## Entries are the SAME id vocabulary `Hud._draw_item_glyph` already reads — an
## armament id, or a `bottle_N` token from `bottle_id()`. That is why routing is
## a pure function of the entry (`bottle_index(id) >= 0` and nothing else) and
## why the HUD needed no new drawing rule to put one in a cell. A second
## encoding here — a Dictionary with a "kind", a parallel array of types — would
## be a second answer to a question `bottle_index` has answered since the HUD
## drew its first cell.
const WHEEL_SLOTS := 8
var wheel: Array[StringName] = _blank_wheel()

## One-way world flags: chests opened, doors unlocked, puzzles solved.
var flags: Dictionary[StringName, bool] = {}

# --- Garrison life ----------------------------------------------------------

const FIREWOOD_CAP: int = 3
const FISH_CAP: int = 3
const FISH_DAILY_CAP: int = 3
const WELL_FED_STAMINA: float = 15.0

var firewood_stock: int = 0:
	set(value):
		firewood_stock = clampi(value, 0, FIREWOOD_CAP)
## Compatibility view for scenes migrating to the supply crate. The Run bag is
## authoritative; this property is never saved or restored as separate state.
var carrying_firewood: bool:
	get:
		return int(Run.bag.get(SupplyCargoDb.FIREWOOD_ID, 0)) > 0
var timber_completed_day: int = 0
var warmth_active: bool = false
var last_bonfire_day: int = 0
var fish_stock: int = 0
var fish_caught_day: int = 0
var fish_units_today: int = 0
var fed_active: bool = false
var last_supper_day: int = 0
var well_fed_ready: bool = false
var well_fed_trip: bool = false
var connected_days: Dictionary[StringName, int] = {}
var _garrison_raid := GarrisonRaidStateScript.new()
var _garden := GardenStateScript.new()


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
	_garrison_raid.changed.connect(_on_garrison_raid_changed)
	_garden.changed.connect(_on_garden_changed)
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
	_seed_wheel()
	while bottle_count() < K.BOTTLE_START:
		add_bottle()


func reset() -> void:
	dev_god_mode = false
	max_health_points = K.START_HEALTH_POINTS
	health_points = max_health_points
	temporary_overhealth = 0
	# Focus raises this, so a reset has to put it back. It did not need clearing
	# while nothing could buy it.
	max_stamina = K.MAX_STAMINA
	stamina = max_stamina
	max_magic = K.MAX_MAGIC
	magic = max_magic
	rupees = 0
	# A new save has died no times. Mercy stays switched on if the player had it
	# on -- that is a preference and lives in `Settings` -- but it goes back to its
	# smallest setting, because the trouble it was answering belonged to the run
	# that is being thrown away.
	deaths = 0
	_mercy_carry = 0.0
	gold = K.START_GOLD
	gold_earned = 0
	field_notes = 0
	completed_field_observations.clear()
	awarded_field_observations.clear()
	bag_slots = K.START_BAG_SLOTS
	upgrades.clear()
	wishlist_lines.clear()
	components.clear()
	stash.clear()
	arrows = 0
	charges = 0
	escape_ropes = 0
	small_keys_by_floor.clear()
	has_boss_key = false
	boss_key_level = 0
	has_map = false
	has_compass = false
	items.clear()
	tool_durabilities.clear()
	bottle_contents.clear()
	rations.clear()
	# Through `cancel_meal` rather than by clearing the three fields, so the hero
	# hears about it and stands up. A reset that left `meal_id` set would root him
	# on a save he no longer belongs to.
	cancel_meal()
	draughts.clear()
	item_selected = 0
	loadout = [
		{HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},
		{HAND_RIGHT: &"bow", HAND_LEFT: &"arrow"},
	]
	loadout_set = PRIMARY
	# The wheel is bindings, and a binding is a claim about something you own —
	# a new save owns none of it. Blanked and reseeded rather than left alone,
	# because the failure of leaving it is silent and specific: the wheel would
	# still show the last hero's hookshot, and releasing on it would be refused
	# by `wheel_ready` with no explanation the player could see.
	wheel = _blank_wheel()
	_seed_wheel()
	flags.clear()
	restore_garrison({})
	# Say that the hands and the selection emptied. Without this, resetting
	# cleared `items` and `loadout` in silence and every listener kept drawing
	# the gear it last heard about — a hero still wearing a stowed bow he no
	# longer owns. Announcing state is not optional for state nobody polls.
	_announce_loadout()
	Bus.item_selected_changed.emit(item_selected)
	Bus.wheel_changed.emit(wheel)
	Bus.bottles_changed.emit(bottle_contents)
	Bus.rations_changed.emit(rations)
	Bus.components_changed.emit(components)
	Bus.stash_changed.emit(stash)
	Bus.ammo_changed.emit(&"arrows", arrows)
	Bus.ammo_changed.emit(&"charges", charges)
	Bus.provisions_changed.emit()
	Bus.gold_changed.emit(gold)
	Bus.key_count_changed.emit(small_keys)
	Bus.player_health_changed.emit(health_points, max_health_points)
	Bus.temporary_overhealth_changed.emit(temporary_overhealth)
	Bus.magic_changed.emit(magic, max_magic)
	Bus.wishlist_changed.emit()
	garrison_changed.emit()
	stamina = max_stamina
	_stamina_hold = 0.0
	Bus.stamina_changed.emit(stamina, max_stamina)


func has_field_observation(id: StringName) -> bool:
	return FieldNotesDb.is_observation(id) \
		and bool(awarded_field_observations.get(id, false))


func has_completed_field_observation(id: StringName) -> bool:
	return FieldNotesDb.is_observation(id) \
		and bool(completed_field_observations.get(id, false))


func field_observation_ready_to_file(id: StringName) -> bool:
	return has_completed_field_observation(id) and not has_field_observation(id)


## Authored order is book order. The saved dictionaries remain sets so neither
## JSON ordering nor the order producers happened to fire can reorder the book.
func ready_field_observations() -> Array[StringName]:
	var ready: Array[StringName] = []
	for id: StringName in FieldNotesDb.OBSERVATION_IDS:
		if field_observation_ready_to_file(id):
			ready.append(id)
	return ready


## Finish observations carried home by a run without touching currency. Input
## order is receipt order; invalid, repeated and already-completed ids are
## ignored. One typed event exposes the completed transaction to the bedside
## marker without making it poll permanent state.
func complete_field_observations(ids: Array[StringName]) -> Array[StringName]:
	var newly_completed: Array[StringName] = []
	for id: StringName in ids:
		if not FieldNotesDb.is_observation(id) \
				or has_completed_field_observation(id) or newly_completed.has(id):
			continue
		completed_field_observations[id] = true
		newly_completed.append(id)
	if not newly_completed.is_empty():
		Bus.field_observations_completed.emit(newly_completed)
	return newly_completed


## File one completed entry from the bedside book. The definition, not the UI,
## owns its value; readiness makes retries and replayed input harmless.
func file_field_observation(id: StringName) -> bool:
	if not _file_field_observation(id):
		return false
	var filed: Array[StringName] = [id]
	Bus.field_notes_awarded.emit(filed, field_notes)
	return true


## Compatibility/dev batch seam. It retains the old convenient behaviour while
## preserving the new invariant: every awarded observation is completed first.
## One batch emits one award signal so listeners never see a half-filed balance.
func award_field_observations(ids: Array[StringName]) -> Array[StringName]:
	complete_field_observations(ids)
	var newly_awarded: Array[StringName] = []
	for id: StringName in ids:
		if not newly_awarded.has(id) and _file_field_observation(id):
			newly_awarded.append(id)
	if not newly_awarded.is_empty():
		Bus.field_notes_awarded.emit(newly_awarded, field_notes)
	return newly_awarded


func _file_field_observation(id: StringName) -> bool:
	if not field_observation_ready_to_file(id):
		return false
	awarded_field_observations[id] = true
	field_notes += FieldNotesDb.observation_note_value(id)
	return true


func garrison_snapshot() -> Dictionary:
	return {
		"firewood_stock": firewood_stock,
		"timber_completed_day": timber_completed_day,
		"warmth_active": warmth_active,
		"last_bonfire_day": last_bonfire_day,
		"fish_stock": fish_stock,
		"fish_caught_day": fish_caught_day,
		"fish_units_today": fish_units_today,
		"fed_active": fed_active,
		"last_supper_day": last_supper_day,
		"well_fed_ready": well_fed_ready,
		"well_fed_trip": well_fed_trip,
		"connected_days": connected_days.duplicate(),
		"raid": _garrison_raid.snapshot(),
		"garden": _garden.snapshot(),
	}


func restore_garrison(data: Dictionary) -> void:
	# A pause-menu load may happen while the old courtyard and its live enemy
	# mirrors still exist. Tell that scene to discard them before replacing the
	# campaign authority so teardown cannot write stale combat state into the save.
	garrison_raid_restoring.emit()
	var previous_raid: Dictionary = _garrison_raid.snapshot()
	var restored_stock: int = clampi(int(data.get("firewood_stock", 0)),
		0, FIREWOOD_CAP)
	var restored_timber_day: int = maxi(0, int(data.get("timber_completed_day", 0)))
	var restored_warmth: bool = bool(data.get("warmth_active", false))
	var restored_bonfire_day: int = maxi(0, int(data.get("last_bonfire_day", 0)))
	var restored_fish: int = clampi(int(data.get("fish_stock", 0)), 0, FISH_CAP)
	var restored_fish_day: int = maxi(0, int(data.get("fish_caught_day", 0)))
	var restored_fish_today: int = clampi(int(data.get("fish_units_today", 0)),
		0, FISH_DAILY_CAP)
	var restored_fed: bool = bool(data.get("fed_active", false))
	var restored_supper_day: int = maxi(0, int(data.get("last_supper_day", 0)))
	var restored_ready: bool = bool(data.get("well_fed_ready", false))
	var restored_trip: bool = bool(data.get("well_fed_trip", false))
	var restored_connected: Dictionary[StringName, int] = {}
	var raw_connected: Variant = data.get("connected_days", {})
	if raw_connected is Dictionary:
		for raw_who: Variant in raw_connected:
			if raw_who is not String and raw_who is not StringName:
				continue
			var restored_who := StringName(raw_who)
			var restored_day := maxi(0, int((raw_connected as Dictionary)[raw_who]))
			if restored_who != &"" and restored_day > 0:
				restored_connected[restored_who] = restored_day
	var changed: bool = restored_stock != firewood_stock \
		or restored_timber_day != timber_completed_day \
		or restored_warmth != warmth_active \
		or restored_bonfire_day != last_bonfire_day \
		or restored_fish != fish_stock \
		or restored_fish_day != fish_caught_day \
		or restored_fish_today != fish_units_today \
		or restored_fed != fed_active \
		or restored_supper_day != last_supper_day \
		or restored_ready != well_fed_ready \
		or restored_trip != well_fed_trip \
		or restored_connected != connected_days
	var raw_raid: Variant = data.get("raid", {})
	_garrison_raid.restore(raw_raid as Dictionary if raw_raid is Dictionary else {})
	changed = changed or previous_raid != _garrison_raid.snapshot()
	firewood_stock = restored_stock
	timber_completed_day = restored_timber_day
	warmth_active = restored_warmth
	last_bonfire_day = restored_bonfire_day
	fish_stock = restored_fish
	fish_caught_day = restored_fish_day
	fish_units_today = restored_fish_today
	fed_active = restored_fed
	last_supper_day = restored_supper_day
	well_fed_ready = restored_ready
	well_fed_trip = restored_trip
	connected_days = restored_connected
	var raw_garden: Variant = data.get("garden", {})
	_garden.restore(raw_garden as Dictionary if raw_garden is Dictionary else {})
	if changed:
		garrison_changed.emit()


func garden_plot(slot: int) -> Dictionary:
	return _garden.plot(slot)


func garden_tree(site: int) -> Dictionary:
	return _garden.tree(site)


func plant_plot(slot: int, seed_id: StringName) -> bool:
	return _garden.plant_plot(slot, seed_id, Clock.day)


func water_plot(slot: int) -> bool:
	return _garden.water_plot(slot, Clock.day)


func harvest_plot(slot: int) -> bool:
	return _garden.harvest_plot(slot, Clock.day)


func plant_tree(site: int, sapling_id: StringName) -> bool:
	return _garden.plant_tree(site, sapling_id, Clock.day)


func water_tree(site: int) -> bool:
	return _garden.water_tree(site, Clock.day)


func harvest_tree(site: int) -> bool:
	return _garden.harvest_tree(site, Clock.day)


func advance_garden_dawn(day: int) -> void:
	_garden.advance_dawn(day)


func _on_garden_changed() -> void:
	garrison_changed.emit()


func raid_arm(at_day: int, at_hour: float) -> bool:
	return _garrison_raid.arm(at_day, at_hour)


func raid_observe_hour(at_day: int, at_hour: int) -> void:
	_garrison_raid.observe_time(at_day, float(at_hour))


func raid_phase() -> StringName:
	return _garrison_raid.phase()


func raid_status() -> Dictionary:
	return _garrison_raid.status()


func raid_scheduled_day() -> int:
	return _garrison_raid.scheduled_raid_day()


func raid_attack_hour() -> int:
	return GarrisonRaidStateScript.ATTACK_HOUR


func raid_integrity() -> int:
	return _garrison_raid.integrity()


func raid_integrity_fraction() -> float:
	return _garrison_raid.integrity_fraction()


func raid_active() -> bool:
	return _garrison_raid.is_active()


func raid_terminal() -> bool:
	return _garrison_raid.is_terminal()


func raid_defense_built() -> bool:
	return _garrison_raid.defense_built()


func raid_ledger_stolen() -> bool:
	return _garrison_raid.ledger_stolen()


func raid_build_defense() -> bool:
	return _garrison_raid.build_defense()


func raid_restore_ledger() -> bool:
	return _garrison_raid.restore_ledger()


func raid_set_live_scene_ownership(owns_simulation: bool) -> void:
	_garrison_raid.set_live_scene_ownership(owns_simulation)


func raid_live_defense_target(delta: float) -> StringName:
	return _garrison_raid.live_defense_target(delta)


func raid_attacker_records() -> Array[Dictionary]:
	return _garrison_raid.attacker_records()


func raid_sync_attacker(raider_id: StringName, hp: int, route_progress: float,
		objective_cooldown: float) -> bool:
	return _garrison_raid.sync_attacker(
		raider_id, hp, route_progress, objective_cooldown)


func raid_report_damage(raider_id: StringName, amount: int) -> bool:
	return _garrison_raid.damage_attacker(raider_id, amount)


func raid_report_kill(raider_id: StringName) -> bool:
	return _garrison_raid.kill_attacker(raider_id)


func raid_objective_attack(raider_id: StringName) -> bool:
	return _garrison_raid.objective_attack(raider_id)


func raid_sleep_crosses_attack(target_day: int, target_hour: float) -> bool:
	return _garrison_raid.crosses_attack_boundary(
		Clock.day, Clock.hour, target_day, target_hour)


func _on_garrison_raid_changed() -> void:
	garrison_changed.emit()


func _deliver_raid_notices() -> void:
	if get_tree().paused or Flow.busy or Prompt.blocked:
		return
	if _garrison_raid.consume_advance_notice():
		Bus.request_message.emit("ALDRIC: RAIDERS WILL STRIKE AT 23:00.")
		return
	if not _garrison_raid.consume_urgent_notice():
		return
	Bus.request_global_sfx.emit(&"raid_horn")
	if Run.in_dungeon:
		Bus.request_message.emit(
			"THE GARRISON IS UNDER ATTACK. EXTRACT WITH THE ESCAPE ROPE OR PRESS ON.")
	else:
		Bus.request_message.emit("THE GARRISON IS UNDER ATTACK. TO THE COURTYARD.")


func can_chop_firewood(at_day: int, phase: StringName) -> bool:
	return at_day > 0 \
		and phase == WorldClock.GARRISON_DAYTIME \
		and timber_completed_day != at_day


func chop_firewood(at_day: int, phase: StringName) -> bool:
	if not can_chop_firewood(at_day, phase):
		return false
	if Run.collect(SupplyCargoDb.FIREWOOD_ID, 1) != 1:
		return false
	timber_completed_day = at_day
	garrison_changed.emit()
	return true


## Deprecated compatibility door for the old hearth prompt. Depositing is now
## one central-crate transaction, so this may move fish in the same call.
func deposit_firewood() -> bool:
	var receipt := deposit_supplies()
	return int(receipt.get(&"firewood_units", 0)) > 0


## Read-only prompt seam. It answers whether at least one carried provision can
## enter its reserve without rolling a day or consuming anything from the bag.
func supply_deposit_available() -> bool:
	for id: StringName in SupplyCargoDb.SUPPLY_IDS:
		if int(Run.bag.get(id, 0)) <= 0:
			continue
		match SupplyCargoDb.category_of(id):
			SupplyCargoDb.CATEGORY_FIREWOOD:
				if firewood_stock < FIREWOOD_CAP:
					return true
			SupplyCargoDb.CATEGORY_FOOD:
				var units := SupplyCargoDb.food_units(id)
				if units > 0 and fish_stock + units <= FISH_CAP:
					return true
	return false


## Move every carried provision that fits, in catalogue order. Reserve state is
## announced once after all Run.consume calls so observers never draw a
## half-deposited crate.
func deposit_supplies() -> Dictionary:
	var moved: Dictionary[StringName, int] = {}
	var firewood_units := 0
	var food_units := 0
	for id: StringName in SupplyCargoDb.SUPPLY_IDS:
		var carried: int = Run.bag.get(id, 0)
		if carried <= 0:
			continue
		match SupplyCargoDb.category_of(id):
			SupplyCargoDb.CATEGORY_FIREWOOD:
				var firewood_room := FIREWOOD_CAP - firewood_stock
				var firewood_to_move := mini(carried, firewood_room)
				var firewood_moved := Run.consume(id, firewood_to_move)
				if firewood_moved > 0:
					moved[id] = firewood_moved
					firewood_stock += firewood_moved
					firewood_units += firewood_moved
			SupplyCargoDb.CATEGORY_FOOD:
				var units_per_item := SupplyCargoDb.food_units(id)
				if units_per_item <= 0:
					continue
				var items_to_move := mini(carried,
					floori(float(FISH_CAP - fish_stock) / float(units_per_item)))
				var items_moved := Run.consume(id, items_to_move)
				if items_moved > 0:
					var added_units := items_moved * units_per_item
					moved[id] = items_moved
					fish_stock += added_units
					food_units += added_units
	var receipt := {
		&"moved": moved,
		&"firewood_units": firewood_units,
		&"food_units": food_units,
	}
	if not moved.is_empty():
		garrison_changed.emit()
	return receipt


## Spend stored hearth stock as one checked mutation. Tool recipes use this
## after their complete gold/material/firewood bill has been found affordable.
func consume_stored_firewood(amount: int) -> bool:
	if amount <= 0:
		return true
	if firewood_stock < amount:
		return false
	firewood_stock -= amount
	garrison_changed.emit()
	return true


func fish_space() -> int:
	return FISH_CAP - fish_stock


func fishing_remaining_today(at_day: int) -> int:
	if at_day <= 0:
		return 0
	# Read-only callers include the always-live pause-menu panel. Looking at a
	# different civil day must not rewrite the campaign state behind a save or a
	# fishing attempt; the next successful banking operation owns that rollover.
	if at_day != fish_caught_day:
		return FISH_DAILY_CAP
	return FISH_DAILY_CAP - fish_units_today


func can_catch_fish(at_day: int, fish_id: StringName = &"") -> bool:
	if at_day <= 0 or (fish_id != &"" and not SupplyCargoDb.is_fish(fish_id)):
		return false
	var units := SupplyCargoDb.food_units(fish_id) if fish_id != &"" else 1
	return units > 0 and units <= fishing_remaining_today(at_day)


func record_fish_catch(fish_id: StringName, at_day: int) -> bool:
	if not can_catch_fish(at_day, fish_id):
		return false
	if Run.collect(fish_id, 1) != 1:
		return false
	_sync_fishing_day(at_day)
	fish_units_today += SupplyCargoDb.food_units(fish_id)
	garrison_changed.emit()
	return true


## Deprecated query shape retained only while callers move from anonymous Fish
## units to exact catalogue IDs. It never considers the garrison reserve.
func can_bank_fish(units: int, at_day: int) -> bool:
	return units == 1 and can_catch_fish(at_day)


## Deprecated refusal: an anonymous unit cannot become an exact carried fish.
## New catches must call record_fish_catch with the rolled catalogue ID.
func bank_fish(_units: int, _at_day: int) -> int:
	return 0


func _sync_fishing_day(at_day: int) -> void:
	if at_day > 0 and at_day != fish_caught_day:
		fish_caught_day = at_day
		fish_units_today = 0


func resolve_bonfire(at_day: int) -> bool:
	if at_day <= maxi(last_bonfire_day, last_supper_day):
		return false
	var fueled: bool = firewood_stock > 0
	if fueled:
		firewood_stock -= 1
	var served: bool = fish_stock > 0
	if served:
		fish_stock -= 1
	warmth_active = fueled
	fed_active = served
	last_bonfire_day = at_day
	last_supper_day = at_day
	if served:
		well_fed_ready = true
	garrison_changed.emit()
	return true


func record_substantive_conversation(who: StringName, at_day: int) -> bool:
	if who == &"" or at_day <= 0 or at_day <= int(connected_days.get(who, 0)):
		return false
	connected_days[who] = at_day
	garrison_changed.emit()
	return true


func morale_causes(who: StringName, at_day: int) -> PackedStringArray:
	var causes := PackedStringArray()
	if warmth_active:
		causes.append("Warm")
	if fed_active:
		causes.append("Fed")
	var connected_day := int(connected_days.get(who, 0))
	if connected_day > 0 and at_day >= connected_day and at_day <= connected_day + 1:
		causes.append("Connected")
	return causes


func morale_label(who: StringName, at_day: int) -> String:
	match morale_causes(who, at_day).size():
		1:
			return "Uneasy"
		2:
			return "Steady"
		3:
			return "High"
	return "Low"


func begin_well_fed_trip() -> void:
	var changed: bool = well_fed_ready or well_fed_trip
	well_fed_trip = well_fed_ready
	well_fed_ready = false
	resync_maxima(true)
	if changed:
		garrison_changed.emit()


func end_well_fed_trip() -> void:
	var changed := well_fed_trip
	well_fed_trip = false
	resync_maxima(false)
	if changed:
		garrison_changed.emit()


func well_fed_bonus() -> float:
	return WELL_FED_STAMINA if well_fed_trip else 0.0


func warmth_sell_mult() -> float:
	return 1.10 if warmth_active else 1.0


func trade_purchase_price(base: int) -> int:
	if base <= 0:
		return 0
	var multiplier: float = 0.90 if warmth_active else 1.0
	return maxi(1, int(round(float(base) * multiplier)))


func is_wishlist_line_pinned(key: StringName) -> bool:
	return wishlist_lines.get(key, false)


## Toggle one stable recipe track. True means it is pinned after the change.
func toggle_wishlist_line(key: StringName) -> bool:
	if key == &"":
		return false
	if wishlist_lines.has(key):
		wishlist_lines.erase(key)
	else:
		wishlist_lines[key] = true
	Bus.wishlist_changed.emit()
	return wishlist_lines.has(key)


## JSON-facing list. No labels, indices, Resources or derived item ids persist.
func wishlist_save_data() -> Array[String]:
	var out: Array[String] = []
	for key: StringName in wishlist_lines:
		out.append(String(key))
	out.sort()
	return out


## Rebuild StringName keys from JSON strings and announce the completed load
## once. Kept public so a disk-free director can prove the reconstruction seam.
func restore_wishlist_lines(raw: Array) -> void:
	wishlist_lines.clear()
	for value: Variant in raw:
		var key := StringName(value)
		if key != &"":
			wishlist_lines[key] = true
	Bus.wishlist_changed.emit()


# --- Health -----------------------------------------------------------------

func damage(amount_health_points: int) -> void:
	if dev_god_mode or amount_health_points <= 0:
		return
	var remaining: int = _softened(amount_health_points)
	if temporary_overhealth > 0:
		var absorbed := mini(temporary_overhealth, remaining)
		set_temporary_overhealth(temporary_overhealth - absorbed)
		remaining -= absorbed
	if remaining <= 0:
		return
	health_points = maxi(0, health_points - remaining)
	Bus.player_health_changed.emit(health_points, max_health_points)
	if health_points == 0:
		Bus.player_died.emit()


## What fraction of a blow mercy forgives right now, 0.0 when it is off.
##
## The rate is on `Game` and the switch is on `Settings`, which is the split GDD
## §7.1 describes: how forgiving it is comes from how much trouble this save is
## in, and whether it is on at all is the player's preference and survives the
## save being deleted.
func mercy_rate() -> float:
	if Settings == null or not Settings.mercy:
		return 0.0
	return minf(K.MERCY_BASE + K.MERCY_PER_DEATH * float(deaths), K.MERCY_MAX)


## The blow after mercy, in whole HP.
##
## **The carry is the whole of this function.** Health is integer HP and a
## 5% resistance on a 2 HP blow is a tenth of one: rounded per hit it is
## nought every single time, so the toggle would be a switch that does nothing
## for the first several hours and then, somewhere past 25%, starts halving
## things. So the fraction ACCUMULATES across blows and is spent as whole HP
## when it comes due -- one blow in ten lands for 1 HP less, which is
## small enough that the player never has to understand the carry, and it is
## honest: over a fight, exactly the advertised fraction is forgiven.
##
## Never below 1 HP, and never on a blow that was already one. `Hero` keeps
## the same floor for armour and for the same reason (GDD §7.1 caps this well
## short of invulnerable): a hit that can be reduced to nothing stops being a
## reason to move.
func _softened(amount: int) -> int:
	var rate := mercy_rate()
	if rate <= 0.0 or amount <= K.HEALTH_POINT:
		return amount
	_mercy_carry += float(amount) * rate
	# Only what the floor leaves room for is actually spent, so a big carry over a
	# 1 HP blow is banked rather than thrown away.
	var forgive := mini(int(floorf(_mercy_carry)), amount - K.HEALTH_POINT)
	if forgive <= 0:
		return amount
	_mercy_carry -= float(forgive)
	return amount - forgive


func heal(amount_health_points: int) -> void:
	health_points = mini(max_health_points, health_points + amount_health_points)
	Bus.player_health_changed.emit(health_points, max_health_points)


func set_temporary_overhealth(amount_health_points: int) -> void:
	temporary_overhealth = maxi(0, amount_health_points)
	Bus.temporary_overhealth_changed.emit(temporary_overhealth)


## The maxima are STORED rather than returned from an accessor, unlike soak and
## speed, and that is on purpose: `max_health_points` is read straight by the HUD,
## by
## `hurt` and by `heal`, and `max_stamina` by every `spend_stamina` caller. What
## follows is the one function that writes them.
##
## **Re-derive both stored maxima from `upgrades`.** The one place that knows how
## much max HP and stamina the ladders add up to.
##
## It used to be two `+=` calls -- a health line that added 4 HP and a Focus
## rung that added points -- and that shape can only ever count UP. Recut (GDD
## §6.6) takes a rung back off a jewel, and a maximum that was accumulated cannot
## be un-accumulated without the shop doing the arithmetic a second time and
## getting the odd Vigor rung wrong. Derived, the answer is the same however you
## arrived at it, and Recut is one call.
##
## `fill` tops both bars up, which is what a PURCHASE does -- a health upgrade you
## just paid for arrives full. A Recut passes false: the maxima come down, the bars are
## clamped to them, and nobody is healed for changing their mind.
func resync_maxima(fill: bool = false) -> void:
	var permanent_health_points := K.START_HEALTH_POINTS \
		+ int(upgrades.get(&"health", 0)) * K.HEALTH_UPGRADE_POINTS \
		+ jewel_level(jewel_track(&"amulet", &"vigor")) \
		* K.JEWEL_VIGOR_HEALTH_POINTS
	# Ceiling enforced HERE rather than in the two shops, so a third source cannot
	# arrive and quietly raise it (K.MAX_HEALTH_POINTS, and the note over
	# K.SOAK_MAX about why ceilings belong to the number).
	max_health_points = mini(permanent_health_points, K.MAX_HEALTH_POINTS)
	health_points = max_health_points if fill \
		else clampi(health_points, 0, max_health_points)
	var permanent_stamina := minf(K.STAMINA_MAX, K.MAX_STAMINA
		+ K.JEWEL_FOCUS_STAMINA
		* float(jewel_level(jewel_track(&"amulet", &"focus"))))
	max_stamina = permanent_stamina + well_fed_bonus()
	stamina = max_stamina if fill else minf(stamina, max_stamina)
	Bus.player_health_changed.emit(health_points, max_health_points)
	Bus.stamina_changed.emit(stamina, max_stamina)


# --- Magic ------------------------------------------------------------------

## Top the bar right up. **The only way magic ever comes back**, and its three
## callers are all on `Run` -- entering a dungeon, extracting from one, and
## dying in one. There is deliberately no trickle, no potion and no drop: the
## whole reason the spin is priced in magic rather than in stamina is that magic
## is a per-TRIP budget, and anything that refills it underground turns it back
## into a cooldown (see K.MAGIC_SPIN).
##
## Named for the intent rather than spelled `restore_magic(max_magic)` at three
## call sites, so a fourth caller has to say out loud that it is filling the bar.
func fill_magic() -> void:
	# Repairs an old save, which is the one path that can arrive here with a dead
	# meter: `max_magic` was 0 until the bar was switched on and the loader reads
	# whatever the file holds. Without this the blue bar would be a black slot for
	# anyone who had played before.
	if max_magic <= 0:
		max_magic = K.MAX_MAGIC
	magic = max_magic
	Bus.magic_changed.emit(magic, max_magic)


## Pay for a spin. **All or nothing**, unlike `spend_stamina`'s partial mode, and
## the difference is the point: a swing that goes out on the last drop of stamina
## is Elden Ring's "you are never told no mid-commitment", but the spin has not
## been committed to yet at the moment this is asked -- the wind-up is still in
## the player's hand. A half-priced spin would be a budget of four-and-a-bit,
## which is a budget nobody can count.
func spend_magic(cost: int) -> bool:
	if dev_god_mode or cost <= 0:
		return true
	if magic < cost:
		return false
	magic -= cost
	Bus.magic_changed.emit(magic, max_magic)
	return true

## Hand back SOME magic. **This function was refused for months and it is here on
## an owner directive** (2026-08-11, `docs/SCOPE.md` §2); the note that stood in
## its place said "an API that can hand back some magic is an invitation to hang a
## drop or a potion off it", and the invitation has now been accepted on purpose.
## What is written below is the fence that replaced the wall.
##
## **It has exactly one caller and the type system cannot say so, so this can.**
## `RationDb.apply_tick` calls it, Small Beer is the only ration that feeds this
## bar, and the drink costs `K.MEAL_TIME` seconds of sitting perfectly still --
## which is the thing that keeps `K.MAGIC_SPIN`'s argument standing (read its note
## before you add a second caller). What the bar defends is that the fourth spin
## of a trip is a decision you can see coming. A refill you buy in the garrison,
## carry down a slot, and pay for with a room you have already cleared does not
## touch that. A refill that is free, fast, or dropped by a body does.
##
## So: **no drop, no font, no pickup, and nothing that pays this without a clock
## in front of it.** A second caller is an amendment to SCOPE §2, not a line of
## code.
##
## Clamped rather than checked, so a tick near the top of the bar is a partial
## fill and never a refusal -- the same shape `add_charges` and `add_arrows` have.
func restore_magic(amount: int) -> void:
	if amount <= 0 or magic >= max_magic:
		return
	magic = clampi(magic + amount, 0, max_magic)
	Bus.magic_changed.emit(magic, max_magic)


# --- Stamina ----------------------------------------------------------------
## The only thing in this file that ticks. Regen is frozen for K.STAMINA_DELAY
## after a spend: the pause IS the tell that you are winded, and without it the
## bar refills so smoothly that it reads as no system at all.

func _process(delta: float) -> void:
	_garrison_raid.observe_time(Clock.day, Clock.hour)
	_deliver_raid_notices()
	_garrison_raid.tick(delta)
	_tick_draughts(delta)
	_tick_meal(delta)
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
	if dev_god_mode or cost <= 0.0:
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


func add_charges(n: int) -> void:
	charges = clampi(charges + n, 0, max_charges)
	Bus.ammo_changed.emit(&"charges", charges)


## Put Rope provision stock in the carried stack. Returns exactly how many fit.
func add_escape_ropes(n: int) -> int:
	if n <= 0:
		return 0
	var was := escape_ropes
	escape_ropes = clampi(escape_ropes + n, 0, K.ESCAPE_ROPE_STACK)
	var added := escape_ropes - was
	if added > 0:
		Bus.provisions_changed.emit()
	return added


## Spend the Rope when its world channel begins. God mode keeps the same
## no-decrement behavior as ammunition.
func spend_escape_rope() -> bool:
	if dev_god_mode:
		return true
	if escape_ropes <= 0:
		return false
	escape_ropes -= 1
	Bus.provisions_changed.emit()
	return true


## Spend one unit of a consumable. Returns false if the player has none.
func spend_ammo(id: StringName) -> bool:
	if dev_god_mode:
		return true
	match id:
		&"arrows":
			if arrows <= 0:
				return false
			arrows -= 1
		&"charges":
			if charges <= 0:
				return false
			charges -= 1
		_:
			return true
	Bus.ammo_changed.emit(id, ammo_count(id))
	return true


## How many of `id` are left. One reader, because the HUD, the equipment screen
## and the item that spends it must not each pick their own field -- the count
## and the cell drawing it disagreeing is the class of bug that only shows up
## when the number is nearly gone.
func ammo_count(id: StringName) -> int:
	match id:
		&"arrows": return arrows
		&"charges": return charges
	return 0


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
	# A NEGATIVE n is a fine (the extraction fee takes this door), so the lifetime
	# tally only ever counts the positive side. Otherwise "gold earned" would be
	# net worth, which is the number `gold` already is.
	if n > 0:
		gold_earned += n
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


## Roll back a validated purchase without counting the returned coin as earnings.
func refund_gold(n: int) -> void:
	if n <= 0:
		return
	gold += n
	Bus.gold_changed.emit(gold)


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


## HP the sword adds. Named `sword_bonus` for years; it is a
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


## HP subtracted from every blow taken. `Hero.hurt` floors the
## result at one -- armour makes you last longer, never invincible, and that
## floor is what stops Ironhide on a full plate ladder from being immunity.
## Ballast is added HERE, on top of the cap, exactly as Ironhide is: `SOAK_MAX`
## is the ceiling on what you can BUILD (see its note about faucets), and a
## window you paid a stack of merchandise for is not a build. Stacking it with a
## draught is allowed and is meant to be -- both are consumed, and `Hero.hurt`
## still floors every blow at 1 HP, so the two together are a very good
## eight seconds and never immunity.
func armour_soak() -> int:
	return int(floorf(armour_soak_exact())) \
		+ (K.DRAUGHT_PLATE if draught_left(DRAUGHT_PLATE_ID) > 0.0 else 0) \
		+ (K.BALLAST_SOAK if draught_left(BALLAST_ID) > 0.0 else 0)


## The permanent soak before flooring, in HP. Public because the
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
	var rungs: int = jewel_level(jewel_track(&"bracelet", &"wind"))
	var regen: float = K.STAMINA_REGEN \
		* (1.0 + K.JEWEL_WIND_REGEN * float(rungs))
	return FieldNotesDb.stamina_regen(regen)


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


func stash_capacity() -> int:
	var ranks := int(upgrades.get(ElderUpgradeDb.LOCKER_ID, 0))
	return K.STASH_SLOTS + ranks * ElderUpgradeDb.LOCKER_SLOTS_PER_RANK


func stash_full() -> bool:
	return stash_slots_used() >= stash_capacity()


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
	var free_slots := maxi(stash_capacity() - stash_slots_used(), 0)
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
	#
	# It is on the WHEEL too, if there is room. The bind has to happen after the
	# append and not before: `wheel_bindable` asks `bottle_index`, which answers
	# for bottles that exist, so a token bound for glass the alchemist has not
	# blown yet would be refused.
	wheel_auto_bind(bottle_id(bottle_contents.size() - 1))
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
	# The Full Cup (`EchoDb.FULL_CUP`): a draught drunk while BLAZING is not
	# spent. Speed buys back the one thing you had to purchase in the garrison,
	# and only while the leash is shortest -- so it is a reward for the chain
	# rather than a fifth bottle (`docs/PUZZLES.md` §6.1, row 11). The bottle is
	# still a loadout and never a currency; this is the same sentence the
	# docstring above makes, said once more by an Echo.
	if Heat.blazing() and Run.has_echo(EchoDb.FULL_CUP):
		return true
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


## How long this window is when it is FULL -- the denominator `draught_left()` is
## the numerator of, and the only thing anything needs to draw a clock rather than
## a number of seconds.
##
## A function and not a table, deliberately: the durations are already spelled in
## `K` and a `{id: seconds}` dictionary here would be a second place for them to
## be wrong. It is also not stored beside the running window -- #39's brief is
## that `draughts` stays the one table of what is running, and a remembered
## "started at" would be a second timer table by another name.
##
## Ballast is 8 s against a draught's 45 (`K.BALLAST_TIME`, and the note over it
## says why they are that far apart). The HUD used to divide every slot by
## `K.DRAUGHT_TIME` flat, so a Ballast slot fed through that would open at 8/45 --
## ONE tile of four, on a window that is running at full strength -- and go dark
## two seconds in. A clock that starts at nearly empty is worse than no clock.
func draught_span(id: StringName) -> float:
	return K.BALLAST_TIME if id == BALLAST_ID else K.DRAUGHT_TIME


func start_draught(id: StringName, seconds: float) -> void:
	draughts[id] = seconds
	Bus.draught_changed.emit(id, seconds)


# --- Rations and the meal (docs/METAGAME.md §6.4) ---------------------------

## How many of `id` are in the pack. One reader, for `ammo_count`'s reason: the
## HUD cell, the counter's refusal and the thing that spends it must not each
## pick their own field.
func ration_count(id: StringName) -> int:
	return int(rations.get(id, 0))


## Put `n` in the pack, clamped at the stack. Returns how many actually FIT --
## the counter needs that to refuse a purchase that would be thrown away, and
## `add_arrows` gets away without it only because the arrow line checks the
## quiver itself.
func add_rations(id: StringName, n: int) -> int:
	if not RationDb.has(id) or n <= 0:
		return 0
	var was := ration_count(id)
	var now := clampi(was + n, 0, K.RATION_STACK)
	if now == was:
		return 0
	rations[id] = now
	Bus.rations_changed.emit(rations)
	return now - was


## Every ration you are carrying at least one of, in `RationDb.IDS` order. The
## carry ring and the wheel both walk this, so an emptied stack leaves both in
## the same step rather than in two.
func ration_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RationDb.IDS:
		if ration_count(id) > 0:
			out.append(id)
	return out


## Eat one. **Consumed on the FIRST tick, not on the last** -- see `_tick_meal`.
func _spend_ration(id: StringName) -> bool:
	var have := ration_count(id)
	if have <= 0:
		return false
	if have == 1:
		rations.erase(id)
	else:
		rations[id] = have - 1
	Bus.rations_changed.emit(rations)
	return true


## Is the hero eating right now? The hero reads this to root himself and to hold
## the seated pose; the HUD reads it to draw the gauge.
func eating() -> bool:
	return meal_id != &""


## How far through the meal, 0 to 1. For the gauge, and for a director that wants
## to assert a meal is actually running down.
func meal_progress() -> float:
	if not eating() or K.MEAL_TIME <= 0.0:
		return 0.0
	return clampf(1.0 - meal_left / K.MEAL_TIME, 0.0, 1.0)


## **Sit down and start eating `id`.** False if there is none of it, if a meal is
## already running, or if the bar it feeds is already full.
##
## The last refusal is the one worth naming: eating at full health is not a
## mistake the player should be allowed to make silently. A ration spent for
## nothing is twenty seconds of a stack thrown away for a press, and unlike a
## bottle there is no cell that would have shown them it did nothing.
##
## The ration is **taken out of the pack here**, before a single tick has paid
## out, and that is deliberate: a meal cancelled at nine seconds has cost you the
## biscuit and paid you three quarters of it. Refunding the item on a cancel would
## make interruption free, and the whole item is that it is not.
func begin_meal(id: StringName) -> bool:
	if eating() or not RationDb.has(id) or ration_count(id) <= 0:
		return false
	match RationDb.kind_of(id):
		RationDb.HEALS:
			if health_points >= max_health_points:
				return false
		RationDb.RESTORES:
			if magic >= max_magic:
				return false
	if not _spend_ration(id):
		return false
	meal_id = id
	meal_left = K.MEAL_TIME
	_meal_paid = 0
	Bus.meal_changed.emit(meal_id, meal_left)
	return true


## Stand up. Silent and idempotent -- every caller is an interruption (a step, a
## swing, a blow, a scene change) and none of them wants to check first.
##
## **No refund**, see `begin_meal`. What you keep is the ticks that already paid.
func cancel_meal() -> void:
	if not eating():
		return
	meal_id = &""
	meal_left = 0.0
	_meal_paid = 0
	Bus.meal_changed.emit(&"", 0.0)


## The meal's clock, ticked beside the draughts' for the reason `draughts` gives:
## one `_process`, one place to forget to call.
##
## **How many ticks are OWED is derived from `meal_left`, and that is the whole
## design of this function.** It ran off a second countdown for an afternoon --
## `_meal_tick -= delta`, wrapping by `+= MEAL_TICK` -- and that is a quiet way to
## lose the last tick of every meal. The two clocks fall due on the same frame
## (`Sigma delta >= 12` ends the meal and also owes tick four), but they are not the
## same arithmetic: `meal_left` is one long chain of subtractions and `_meal_tick`
## is that chain with three additions folded into it, so whether the final tick
## lands before `meal_left` clamps to zero comes down to a float ULP. Half the
## time the player eats a whole biscuit and gets three quarters of it.
##
## Derived, there is nothing to disagree with. `ceil` and not `floor`: any elapsed
## time past a boundary owes that tick, and at `meal_left == 0` it owes all four.
## The loop is still a loop so a frame long enough to span two ticks -- a scene
## load, a stall -- pays both instead of dropping one.
func _tick_meal(delta: float) -> void:
	if not eating():
		return
	meal_left = maxf(0.0, meal_left - delta)
	var due := RationDb.ticks() - int(ceil(meal_left / K.MEAL_TICK))
	while _meal_paid < due:
		_meal_paid += 1
		if not RationDb.apply_tick(meal_id):
			# An id the catalogue does not know. Ending rather than ticking
			# against nothing, which is the state a hand-edited save could reach.
			cancel_meal()
			return
	Bus.meal_changed.emit(meal_id, meal_left)
	if meal_left <= 0.0:
		cancel_meal()


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

func small_keys_for_floor(floor_number: int) -> int:
	if floor_number <= 0:
		return 0
	return int(small_keys_by_floor.get(floor_number, 0))


func set_small_keys_for_floor(floor_number: int, count: int,
		announce: bool = true) -> void:
	if floor_number <= 0:
		return
	var safe_count := clampi(count, 0, SMALL_KEYS_PER_FLOOR_MAX)
	if safe_count <= 0:
		small_keys_by_floor.erase(floor_number)
	else:
		small_keys_by_floor[floor_number] = safe_count
	if announce:
		announce_key_count()


## Plain integer-keyed data for JSON. The save layer may serialize the keys as
## strings; `restore_small_keys` accepts either representation on the way back.
func small_keys_snapshot() -> Dictionary[int, int]:
	return small_keys_by_floor.duplicate()


func restore_small_keys(raw: Variant) -> void:
	small_keys_by_floor.clear()
	if raw is not Dictionary:
		return
	var source := raw as Dictionary
	for raw_floor: Variant in source:
		var floor_number := 0
		if raw_floor is int:
			floor_number = int(raw_floor)
		elif raw_floor is String and (raw_floor as String).is_valid_int():
			floor_number = (raw_floor as String).to_int()
		else:
			continue
		var raw_count: Variant = source[raw_floor]
		if floor_number <= 0 or (raw_count is not int and raw_count is not float):
			continue
		var count := clampi(int(raw_count), 0, SMALL_KEYS_PER_FLOOR_MAX)
		if count > 0:
			small_keys_by_floor[floor_number] = count


func clear_small_keys(announce: bool = true) -> void:
	small_keys_by_floor.clear()
	if announce:
		announce_key_count()


func announce_key_count() -> void:
	Bus.key_count_changed.emit(small_keys)


## One lifecycle seam for a fresh run and either run ending.
func clear_run_keys(announce: bool = true) -> void:
	small_keys_by_floor.clear()
	has_boss_key = false
	boss_key_level = 0
	if announce:
		announce_key_count()


func add_key(n: int = 1) -> void:
	if n <= 0:
		return
	set_small_keys_for_floor(Run.level, small_keys + n)


func spend_key() -> bool:
	if small_keys <= 0:
		return false
	set_small_keys_for_floor(Run.level, small_keys - 1)
	return true


func add_boss_key() -> void:
	if has_boss_key and boss_key_level == Run.level:
		return
	has_boss_key = true
	boss_key_level = Run.level
	Bus.item_acquired.emit(&"boss_key")
	announce_key_count()


func has_boss_key_for(level: int) -> bool:
	return has_boss_key and boss_key_level == level


func spend_boss_key() -> bool:
	if not has_boss_key_for(Run.level):
		return false
	clear_boss_key()
	return true


func clear_boss_key() -> void:
	has_boss_key = false
	boss_key_level = 0
	announce_key_count()


# --- Items and flags --------------------------------------------------------

## Finding a weapon puts it in the cycle and nothing else happens -- no auto-bind
## and no menu trip, because there is no longer a button for it to land on. The
## bow you just found is one press of D-pad → away, which is what the auto-bind
## was for.
func grant(item_id: StringName) -> void:
	if ToolDb.has(item_id):
		if tool_usable(item_id):
			return
		craft_tool(item_id)
		return
	if items.get(item_id, false):
		return
	items[item_id] = true
	# **The auto-bind, and it is a no-op for most of what comes through here.**
	# `wheel_bindable` refuses the map, the compass and everything else that is
	# not a stop on the right-hand ring, so this line does not need a filter of
	# its own — which is the point of routing off the id rather than off the
	# call site. A bow found underground is on the wheel before the chest shuts.
	wheel_auto_bind(item_id)
	Bus.item_acquired.emit(item_id)


## **THE ownership gate.** There is one, it is this, and there is no `has_item()`
## — docs/GDD.md §5.2 and docs/SCOPE.md M1 both name the check `Game.has_item()`
## in prose, but the function has been called `has()` since the item dictionary
## existed and adding a one-line alias would be the second implementation of a
## boolean (CLAUDE.md §0). The docs are what should move.
##
## Everything that asks "may this happen yet" comes through here:
##
##  * `ShopDb.lines()` hides the bow and hookshot forge ladders, and
##    `SupplyDb.lines()` hides the quartermaster's arrow stock line (it was the
##    smith's until card #91), until the item behind them is owned.
##  * `LockedDoor` refuses, and names the item it wants, off one call.
##  * `armament_owned()` gates the weapon ring, and hangs `&"arrow"` off the bow.
##
## Which is why the starter kit above is empty: a gate that answers yes at boot
## is not a gate, and this one function is the reason M1 is a deletion and three
## filters rather than a system.
func has(item_id: StringName) -> bool:
	return items.get(item_id, false)


# --- Durable utility tools -------------------------------------------------

func tool_durability(id: StringName) -> int:
	if not ToolDb.has(id):
		return 0
	return clampi(int(tool_durabilities.get(id, 0)), 0,
		ToolDb.max_durability(id))


func tool_max_durability(id: StringName) -> int:
	return ToolDb.max_durability(id)


func tool_known(id: StringName) -> bool:
	return ToolDb.has(id) and tool_durabilities.has(id)


func tool_usable(id: StringName) -> bool:
	return ToolDb.has(id) and tool_durability(id) > 0 and has(id)


## First craft and reforge are the same state transition: full durability,
## compatibility ownership restored, and the ordinary acquisition notice.
func craft_tool(id: StringName) -> bool:
	var maximum := tool_max_durability(id)
	if maximum <= 0:
		return false
	tool_durabilities[id] = maximum
	items[id] = true
	Bus.item_acquired.emit(id)
	garrison_changed.emit()
	return true


func spend_tool_use(id: StringName) -> bool:
	if not tool_usable(id):
		return false
	var remaining := tool_durability(id) - 1
	tool_durabilities[id] = remaining
	if remaining <= 0:
		items.erase(id)
	garrison_changed.emit()
	return true


# --- The selected item ------------------------------------------------------

## **Everything D-pad ↓ steps through: the bottles you own, then the rations you
## are carrying.** `item_selected` indexes THIS, not `bottle_contents`.
##
## Bottles first, and that ordering is load-bearing rather than cosmetic. For
## every index below `bottle_count()` this list is exactly what the ring was
## before rations existed, so an old save's `item_selected`, every director that
## asserts a bottle index, and `bottle_index()` itself all keep meaning what they
## meant. A ration appended at the end can only ever lengthen the ring.
##
## Rebuilt on each call rather than cached, for `wheel_pool`'s reason: a stack
## that empties, a bottle that is bought and a ration that is eaten all change it,
## and a stored copy is a fourth place for "what am I carrying" to be answered
## differently.
func carry_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in bottle_count():
		out.append(bottle_id(i))
	out.append_array(ration_ids())
	return out


func carry_count() -> int:
	return bottle_count() + ration_ids().size()


## Which thing is under D-pad ↓ right now, or `&""` if you carry nothing. A
## `bottle_N` token, or a ration id.
func selected_item() -> StringName:
	_clamp_item()
	var ids := carry_ids()
	return ids[item_selected] if item_selected < ids.size() else &""


## What is IN the selected bottle, or `&""` for an empty one, for no bottle at
## all, and for a ration -- a ration is not in glass, and every caller of this is
## drawing the liquid inside one. The HUD draws this; `selected_item()` is what
## names the vessel around it.
func selected_potion() -> StringName:
	_clamp_item()
	return bottle(item_selected) if item_selected < bottle_count() else &""


## The ration under D-pad ↓, or `&""` when the selection is a bottle. The mirror
## of `selected_potion`, and the two are never both non-empty.
func selected_ration() -> StringName:
	var id := selected_item()
	return id if RationDb.has(id) else &""


## D-pad ↓. Steps to the next thing you carry, wrapping.
##
## Steps through ALL of them, empty bottles included, and that is deliberate: an
## empty bottle is a thing you own and are about to fill, and a cycle that
## silently skipped it would put the player's four bottles on a ring whose length
## changed every time they drank. A ring you can count is a ring you can use
## blind.
##
## An EMPTIED ration stack is the one thing that does leave the ring, and it has
## to: unlike glass, there is no such thing as an empty biscuit. Eating your last
## one shortens the ring by a stop, `_clamp_item` catches the selection, and the
## HUD's count says so on the same frame.
func cycle_item(dir: int = 1) -> void:
	var n := carry_count()
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
##
## **A RATION IS THE EXCEPTION TO EVERY WORD ABOVE, and that is the item.** It is
## not swallowed on the press: it sits the hero down for `K.MEAL_TIME` and any
## step, swing or blow stands him back up with the rest of it uneaten. So the
## paragraph above — "the button you reach for when you are about to die" — is
## exactly what a ration is NOT for, and the difference is meant to be felt on the
## first press rather than read anywhere. Routed off the id here for
## `wheel_select`'s reason: neither the X button, the wheel nor a director should
## have to know which of the two the selection is.
func use_selected_item() -> bool:
	var id := selected_item()
	if id == &"":
		return false
	if RationDb.has(id):
		return begin_meal(id)
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


## The selection, forced back inside what you are actually carrying. Bottles are
## bought, emptied and refilled and ration stacks run out, so an index that was
## valid when it was set is not an index that stays valid -- and the failure is
## silent (you press X and drink a bottle you were not looking at) rather than
## loud. Eating the last biscuit is the shortest path to it: the ring loses its
## final stop while the cursor is standing on it.
func _clamped_item() -> int:
	return clampi(item_selected, 0, maxi(0, carry_count() - 1))


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
		# The two Verses are READ at the alchemist's counter, not picked up, so
		# there is no `items` row to find and `has()` would answer no forever.
		# `knows_working()` is the accessor `RelicDb` built for exactly this and
		# it is asked HERE rather than at the ring, the HUD and the equipment
		# screen separately -- the ownership question has one reader for the
		# reason the docstring above gives.
		&"sustain": return RelicDb.knows_working(&"sustain")
		&"ballast": return RelicDb.knows_working(&"ballast")
	return has(id)


func _announce_loadout() -> void:
	Bus.loadout_changed.emit(loadout_set, armament(HAND_RIGHT), armament(HAND_LEFT))


# --- The kit wheel ----------------------------------------------------------

## Eight empty slots. `Array[StringName].resize()` fills with `&""`, which is
## exactly what an empty slot is, so there is no second spelling of "nothing
## here" for a reader to get wrong.
static func _blank_wheel() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(WHEEL_SLOTS)
	return out


## What a hero who owns nothing has on the wheel: the sword, and nothing else.
##
## The sword is not in `items` and never will be — `armament_owned` answers for
## it unconditionally — so it has no `grant()` to auto-bind off, and both the
## cold boot and `reset()` have to say so themselves. A wheel that came up empty
## on a fresh save would teach the player, on the one screen where they are
## learning what it is for, that it is a place for things they do not have yet.
##
## Idempotent, and silent: `wheel_auto_bind` returns -1 on a wheel that already
## holds the sword, and emits nothing when it does.
func _seed_wheel() -> void:
	wheel_auto_bind(&"sword")


## What is on `slot`, or `&""`. Out-of-range answers `&""` rather than throwing:
## every caller here is drawing a cell or committing a release, and both want
## "nothing" for a slot that is not there.
func wheel_at(slot: int) -> StringName:
	return wheel[slot] if slot >= 0 and slot < wheel.size() else &""


## **May `id` go on the wheel at all** — and this is the "smart choice between
## weapon and item" asked as one question instead of two.
##
## A bottle token answers yes through `bottle_index`, which is already the
## project's parser for one (`bottle_id` writes them, `Hud._draw_item_glyph`
## reads them), and it answers no for a bottle you do not own — so a save
## carrying `bottle_4` into a game with three bottles cannot bind it back.
## Everything else has to be a stop on the RIGHT-hand ring.
##
## The left hand is deliberately not bindable. `LEFT_POOL` is shield / arrows /
## empty, and none of the three is a thing you *reach for* mid-fight: arrows
## follow the bow, and dropping the shield is a decision you make on the
## equipment screen with both hands visible. A wheel that offered them would be
## offering a way to two-hand the sword by accident.
##
## A RATION answers yes while you are carrying one, by the same rule and for the
## same reason a bottle does: it is a stop on the carry ring, so it is a thing the
## flick is for. Binding is gated on the stack (you cannot put food you have never
## bought on the wheel) but an existing binding SURVIVES the stack emptying -- see
## `wheel_ready` for why those two are deliberately different answers.
func wheel_bindable(id: StringName) -> bool:
	if bottle_index(id) >= 0:
		return true
	if RationDb.has(id):
		return ration_count(id) > 0
	return RIGHT_POOL.has(id)


## Which slot `id` is on, or -1. An id is on the wheel at most once — see
## `wheel_bind`.
func wheel_slot_of(id: StringName) -> int:
	if id == &"":
		return -1
	return wheel.find(id)


## Put `id` on `slot`. `&""` clears it. False when nothing moved.
##
## **Binding a thing that is already somewhere else SWAPS the two slots** rather
## than leaving a duplicate behind. Two cells holding the bow is the wheel
## lying about how much you own, and it is worse than that on a release: the
## player flicks at the sector they remember and lands on the copy they forgot
## about. The swap is also what makes rearranging the wheel one press instead of
## two — you never have to clear a slot before filling it.
func wheel_bind(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= wheel.size():
		return false
	if id != &"" and not wheel_bindable(id):
		return false
	if wheel[slot] == id:
		return false
	var was := wheel_slot_of(id)
	var displaced := wheel[slot]
	wheel[slot] = id
	if was >= 0 and was != slot:
		wheel[was] = displaced
	Bus.wheel_changed.emit(wheel)
	return true


func wheel_clear(slot: int) -> bool:
	return wheel_bind(slot, &"")


## **Auto-bind on pickup.** The first free slot, or -1 if the wheel is full or
## already holds it. Returns the slot so the caller can say where it landed.
##
## This is the half of the wheel that answers CONTRACT §4.1's second complaint —
## that the old bindings made every player visit a menu before a new item meant
## anything. A bow found on floor 3 is on the wheel before the chest lid is shut.
##
## **It never displaces an existing binding**, and a full wheel is a silent no
## rather than an eviction: the eight things on there are the eight the player
## chose, and a pickup that quietly threw one out would be the wheel editing
## itself behind their back at the worst possible moment. `-1` is what the
## equipment screen exists for.
func wheel_auto_bind(id: StringName) -> int:
	if not wheel_bindable(id) or wheel_slot_of(id) >= 0:
		return -1
	var free := wheel.find(&"")
	if free < 0:
		return -1
	wheel[free] = id
	Bus.wheel_changed.emit(wheel)
	return free


## Is what is on `slot` usable right now? The HUD dims a slot that is not.
##
## A slot can go cold without the binding changing: a working is READ at the
## alchemist's counter rather than picked up (`armament_owned`), and a bottle
## can be sold out from under a `bottle_N` token. Both are drawn — a wheel that
## silently hid the Sustain stop until you had read it would never teach anyone
## that the stop exists.
##
## An EMPTY bottle is ready. It is a thing you own and can select; what is in it
## is the cell's business, not the wheel's.
##
## A ration goes cold when the stack runs out, which makes it the one binding here
## that can be emptied by being USED. It is drawn cold and **kept**, not cleared:
## the slot is where the player decided food goes, and buying five more at the
## counter should light their own flick back up rather than hand them an empty
## wheel to re-bind. Same argument the Verses get one line down, arrived at from
## the other direction.
func wheel_ready(slot: int) -> bool:
	var id := wheel_at(slot)
	if id == &"":
		return false
	if bottle_index(id) >= 0:
		return true
	if RationDb.has(id):
		return ration_count(id) > 0
	return armament_owned(id)


## **The release.** Commit the slot the player let go on, and route it by what
## it is: a bottle becomes the selection X drinks, an armament goes into the
## right hand of the live set.
##
## One function and one `if`, because the routing is not a decision the CALLER
## should be making — the equipment screen, the HUD's release and a director all
## hand over a slot index and none of them should have to know that Sustain is a
## weapon and Ironhide is not. That knowledge is `bottle_index`, and it is here.
##
## **It does not use anything.** Selecting a bottle is not drinking it and
## drawing the bow is not firing it — the same split `_tick_dpad` is built on,
## and the one thing Ocarina's C-buttons got wrong (pulling the bow out was also
## loosing an arrow at whatever you were facing).
##
## False means NOTHING MOVED: an empty slot, a cold one, or the thing you were
## already holding. Callers use it for the confirmation click, which is why
## "already there" and "refused" answer the same — neither is a change and
## neither should click.
func wheel_select(slot: int) -> bool:
	var id := wheel_at(slot)
	if id == &"":
		return false
	# A bottle AND a ration both land here, and they land the same way: both are
	# stops on the carry ring, so committing either one is a move of
	# `item_selected` and nothing else. `carry_ids().find()` is asked rather than
	# `bottle_index` alone, because that is the list the index means -- see
	# `carry_ids`.
	var at := carry_ids().find(id)
	if at >= 0:
		if at == item_selected:
			return false
		item_selected = at
		Bus.item_selected_changed.emit(item_selected)
		return true
	if not armament_owned(id):
		return false
	var live := clampi(loadout_set, 0, loadout.size() - 1)
	if loadout[live][HAND_RIGHT] == id:
		return false
	loadout[live][HAND_RIGHT] = id
	_announce_loadout()
	return true


## Everything that could go on the wheel right now, in the order the equipment
## screen offers it: the owned right-hand ring first, then everything on the carry
## ring -- the bottles you have, then the rations you are carrying.
##
## Derived rather than written down, for the reason `cycle_armament` derives its
## own: a hand-kept list here would be a second answer to "what do you own", and
## the first thing it would get wrong is the two Verses, which are not in
## `items` at all.
func wheel_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RIGHT_POOL:
		if armament_owned(id):
			out.append(id)
	out.append_array(carry_ids())
	return out


func set_flag(id: StringName) -> void:
	flags[id] = true


func flag(id: StringName) -> bool:
	return flags.get(id, false)
