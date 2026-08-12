extends Node
## Autoload `Run`. What you are carrying right now, and what happens to it.
##
## This is the whole game in one file. Everything else -- the dungeon, the
## enemies, the vendor -- exists to move numbers through here.
##
## The loop:
##   enter()    you go down with an empty bag
##   collect()  drops and chests fill it
##   extract()  you pay a fee, carry your health home, and keep the bag
##   die()      you keep what is in the document case, and nothing else
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
##
## This is the WHOLE bag, case included. `cased` below says which of it is in the
## case; every consumer that only wants to know what you are carrying (the fee,
## the vendor, the HUD, the fletching bench) reads this and never has to know the
## case exists.
var bag: Dictionary[StringName, int] = {}
## id -> how many of that id are in the **document case** (docs/GDD.md §3.1). A
## strict subset of `bag`: an id in here is in the bag too, and never by more.
##
## A subset rather than a second container, and that is the decision this whole
## feature turns on. The fee, the vendor's total, the heat premium, the receipt
## and `slots_used()` are all arithmetic over "what you are carrying", and every
## one of them would have needed a second term the day the case became a bag of
## its own -- which is the drift CLAUDE.md §0 is about. What the case actually is
## is a MARK on three of the slots, so it is stored as one.
##
## Cleared with the bag. `_case_trim()` is what keeps the subset true: anything
## that takes items out of `bag` by any door calls it rather than remembering to
## adjust this by hand.
var cased: Dictionary[StringName, int] = {}
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
## Keys: extracted, contents, banked, kept, kept_value, value, premium, fee,
## kills, level, depth, killer. Empty before the first run ends.
var summary: Dictionary = {}
## Seeded per run so a dungeon can be replayed exactly.
var rng := RandomNumberGenerator.new()
var seed_used: int = 0
## Stable generated-room ids visited on this floor. The dungeon rebuilds from
## `seed_used` + `level`, so names such as `Room_2_-1` survive a save/load even
## though the Node instances do not.
var visited_rooms: Dictionary[StringName, bool] = {}
## Version of the nested run payload inside a `Saves` slot. Kept separate from
## the outer save version so a future dungeon-state migration has an explicit
## seam instead of having to infer its shape from whichever app version wrote it.
const SNAPSHOT_VERSION := 1

## The seed the NEXT run will use, if non-zero. Consumed and cleared by `enter()`.
##
## `enter()` already takes a seed, but nothing that STARTS a run is a function
## call a test can reach: the run begins when the player finishes a 0.9 s hold on
## the garrison gate, and `Npc.activate` calls `Flow.enter_dungeon()` with no
## argument. So a director driving the real gate had no way to choose a floor,
## and a seed-dependent bug in the dungeon could only be hunted by re-running
## until it showed up. That is what #36 cost: a chest beat that failed two runs
## in three and could not be summoned on demand.
##
## Cleared on use rather than left set, so a harness that pins one floor cannot
## silently pin every run after it.
var seed_next: int = 0

## Slots of the bag that are the Society's document case, counted off the top.
##
## **Three of twelve, and it is not a dice roll** (docs/GDD.md §3.1). The case is
## legible for the whole run, so the player knows at every moment exactly what
## they would keep -- which is what makes packing a decision rather than a
## consolation prize handed out at the moment of death.
##
## It is not a `Game` field and it is not bought: the four bag slots the smith
## sells all land in the HOLD (`hold_slots()`), because a case that grew with the
## bag would hand the player back the catastrophe the cap exists to pose.
const CASE_SLOTS := 3

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
	# The Quiet Room's site. It lives here and not on the Dungeon because the
	# Echo is a property of the RUN, and a floor generator that knew which boons
	# the player was carrying would be the first of a dozen such places.
	Bus.room_entered.connect(_on_room_entered)


func reset() -> void:
	Game.clear_boss_key()
	bag.clear()
	cased.clear()
	visited_rooms.clear()
	premium = 0
	in_dungeon = false
	depth = 0
	level = 1
	kills = 0
	last_attacker = &""
	summary = {}
	seed_used = 0
	seed_next = 0
	rng.seed = 0


func _on_enemy_died(_enemy: Node3D, _position: Vector3) -> void:
	if in_dungeon:
		kills += 1


# --- Entering and leaving ---------------------------------------------------

## Start a run. Pass a seed to replay one; 0 picks a fresh one and records it.
func enter(run_seed: int = 0) -> void:
	Game.clear_boss_key()
	bag.clear()
	cased.clear()
	visited_rooms.clear()
	premium = 0
	depth = 0
	# Every NEW run starts at the top. A restored snapshot bypasses `enter()`;
	# allowing this path to start on floor 7 would make the forge optional
	# (docs/GDD.md §4).
	level = 1
	kills = 0
	last_attacker = &""
	summary = {}
	in_dungeon = true
	# Fresh puzzles. Atom flags live in `Game.flags` alongside the door flags, and
	# those are permanent on purpose -- a shortcut you opened stays open across
	# saves. A PLATE must not: `docs/PUZZLES.md` §5.2 is that you solve the gate
	# room on the way down and walk the cycle home, once, this run. Solved on run
	# nine, the gate room would be a corridor. See `PuzzleAtom.clear_run_flags`.
	PuzzleAtom.clear_run_flags()
	# A full blue bar, because the bar is a per-TRIP budget and this is the start
	# of a trip (K.MAGIC_SPIN). Note that `descend_floor` deliberately does NOT do
	# this: taking the stair is the same trip getting longer, and a floor change
	# that handed back four more spins would make the stair a refill station and
	# the budget meaningless on exactly the floors it is supposed to bite.
	Game.fill_magic()
	if run_seed == 0:
		run_seed = seed_next
	seed_next = 0
	seed_used = run_seed if run_seed != 0 else _fresh_seed()
	rng.seed = seed_used
	Bus.bag_changed.emit(bag, bag_value())
	Bus.run_started.emit(seed_used)
	Bus.level_changed.emit(level)


## A wall-clock seed with enough resolution for two runs started in one second.
## The fallback makes the freshness contract exact even when the clock repeats.
func _fresh_seed() -> int:
	var candidate: int = int(Time.get_unix_time_from_system() * 1000000.0) % 0x7fffffff
	candidate = maxi(candidate, 1)
	if candidate == seed_used:
		candidate = 1 if candidate == 0x7ffffffe else candidate + 1
	return candidate


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
	visited_rooms.clear()
	Bus.level_changed.emit(level)


## Take the stair up without ending the run. This is the exact inverse of a
## descent above floor 1: all per-trip state stays live, while the destination
## floor starts with fresh depth and visited-room state.
func ascend_floor() -> void:
	if not in_dungeon or level <= 1:
		return
	level -= 1
	depth = 0
	visited_rooms.clear()
	Bus.level_changed.emit(level)


## The seed for the floor you are standing on. Same run seed plus same level
## always builds the same floor, so a bug two floors down is reproducible from
## the one number the run reports.
func floor_seed() -> int:
	return absi(seed_used + level * 2654435761) % 0x7fffffff


## Plain-data representation of the live run. The generated tree is rebuilt
## from the seed and floor; only the decisions and counters that cannot be
## derived from that tree belong here.
func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"in_dungeon": in_dungeon,
		"seed_used": seed_used,
		"level": level,
		"depth": depth,
		"bag": bag.duplicate(),
		"cased": cased.duplicate(),
		"premium": premium,
		"kills": kills,
		"magic": Game.magic,
		"stamina": Game.stamina,
		"visited_rooms": visited_rooms.keys(),
		"rng_state": rng.state,
	}


## Restore a run snapshot written by `snapshot`. JSON erases StringName keys
## and typed dictionaries, so every collection is rebuilt rather than assigned.
## Empty input means there is no resumable run and deliberately clears any live
## one the caller may have been standing in.
func restore(saved: Dictionary) -> bool:
	if saved.is_empty() or int(saved.get("version", 0)) != SNAPSHOT_VERSION:
		reset()
		return false

	bag = _restore_counts(saved.get("bag", {}))
	var restored_case := _restore_counts(saved.get("cased", {}))
	cased.clear()
	for id: StringName in restored_case:
		var n := mini(int(restored_case[id]), int(bag.get(id, 0)))
		if n > 0:
			cased[id] = n

	in_dungeon = bool(saved.get("in_dungeon", false))
	seed_used = int(saved.get("seed_used", 0))
	level = maxi(int(saved.get("level", 1)), 1)
	depth = maxi(int(saved.get("depth", 0)), 0)
	premium = maxi(int(saved.get("premium", 0)), 0)
	kills = maxi(int(saved.get("kills", 0)), 0)
	Game.magic = clampi(int(saved.get("magic", Game.max_magic)), 0, Game.max_magic)
	Game.stamina = clampf(float(saved.get("stamina", Game.max_stamina)),
		0.0, Game.max_stamina)
	last_attacker = &""
	summary = {}
	seed_next = 0
	visited_rooms.clear()
	var raw_visited: Variant = saved.get("visited_rooms", [])
	if raw_visited is Array:
		for raw_id: Variant in raw_visited:
			if raw_id is not String and raw_id is not StringName:
				continue
			var room_id := StringName(raw_id)
			if String(room_id).begins_with("Room_"):
				visited_rooms[room_id] = true

	rng.seed = seed_used
	var raw_state: Variant = saved.get("rng_state", null)
	if raw_state is int or raw_state is float:
		rng.state = int(raw_state)

	# A load replaces every value at once; listeners should redraw once from the
	# completed state rather than observe the half-restored intermediate values.
	Bus.bag_changed.emit(bag, bag_value())
	Bus.level_changed.emit(level)
	Bus.depth_changed.emit(depth)
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	return true


func _restore_counts(raw: Variant) -> Dictionary[StringName, int]:
	var restored: Dictionary[StringName, int] = {}
	if raw is not Dictionary:
		return restored
	var source := raw as Dictionary
	for raw_id: Variant in source:
		if raw_id is not String and raw_id is not StringName:
			continue
		var id := StringName(raw_id)
		if id == &"" or ItemDb.get_def(id) == null:
			continue
		var raw_count: Variant = source[raw_id]
		if raw_count is not int and raw_count is not float:
			continue
		var count := int(raw_count)
		if count > 0:
			restored[id] = count
	return restored


## Settle an extraction. Returns false only when there is no run to leave.
##
## **It cannot fail on money.** The fee is capped at the purse (`extract_charge`),
## so a toll bigger than your gold takes all of it and extraction still works. The
## old version refused, and refusing was the one outcome the design never wanted:
## the fee scales with the bag, so the player it stopped was the player holding
## the best run of the night, and it stopped them with no way to comply --
## nothing underground sells, and dying to clear the debt loses the bag the fee
## was charged for. See `extract_charge` for why the cap is the right shape.
func extract() -> bool:
	if not in_dungeon:
		return false
	var fee := extract_charge()

	Game.clear_boss_key()
	Game.spend_gold(fee)
	in_dungeon = false
	# **The refill the whole bar is built around**: you leave, and the blue comes
	# back. It lands here rather than only in the next `enter()` so a player
	# standing in the garrison sees a full meter -- a bar that stayed empty
	# between runs would read as a bar that is broken, and the garrison is where
	# the player looks at their gear.
	Game.fill_magic()
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
	# And the Echoes go quiet, after the toll like everything else -- though the
	# toll never noticed them, because an Echo is worth 0 gold. The order still
	# matters for the RECEIPT: `carried` was snapshotted above, so the run's tones
	# are listed on it, which is the only place they are ever written down.
	bank_echoes()
	# Folded into `banked` so the receipt draws a relic as "TO THE BENCH" instead
	# of a gold figure. Those are the wrong three words for the Society's hall and
	# the right SENTENCE -- that column means "this line is not money", and a relic
	# priced in gold on the receipt is the exact lie GDD §6.3 forbids.
	banked.merge(recovered)
	_end_summary(true, carried, carried_value, banked, fee)
	# Same reason as in `die()`: the next run starts at the top, and until the
	# number says so the HUD in the garrison is reporting a floor nobody is
	# standing on.
	level = 1
	Bus.level_changed.emit(level)
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
	_case_trim()

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
		# Belt only: `case_fits` refuses a relic the case slot, so there is never a
		# cased relic to trim. Called anyway, because "the subset is true after
		# anything leaves the bag" is a rule with no exceptions in it.
		_case_trim()
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
	return _relic_toll_of(bag)


## Die. **The case comes home; the other nine slots are gone.** Gold and anything
## bought with it survives, as it always did.
##
## Added 2026-08-10 (docs/GDD.md §3.1). Death used to take the whole bag, which is
## harsher than Souls -- you cannot walk back for it -- and harsher than any
## roguelite this game is measured against, all of which pay something for every
## run. Forty minutes for nothing is how a loop gets closed, and three slots is
## the smallest answer that is not a dice roll.
##
## The case's contents are handled EXACTLY as an extraction handles the bag, one
## call short: components in it go to the bench, ingredients stay in the bag to be
## sold, and the heat premium follows the merchandise that survived. What is not
## repeated is `bank_relics` -- a relic cannot be in the case (`case_fits`), so on
## a death every relic you were carrying is still down there, which is the
## paragraph below.
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
	Game.clear_boss_key()
	# The dial mercy turns (GDD §7.1). Counted here rather than off
	# `Bus.player_died` because that fires for a death in the garrison too, and
	# this is the only place that knows a RUN ended.
	Game.deaths += 1
	var kept := case_contents()
	var lost: Dictionary[StringName, int] = {}
	for id: StringName in bag:
		var n := in_hold(id)
		if n > 0:
			lost[id] = n
	var lost_value := _value_of(lost)
	# Measured before the pot is split, because `_premium_share` divides by the
	# bag as it stands and the bag is about to be nine slots smaller.
	var lost_hot := _premium_share(_base_of(lost) - _relic_toll_of(lost))

	# The heat premium follows the merchandise. What the floor kept takes its
	# share of the pot with it and the case keeps the rest -- the same
	# proration `sell()` and `bank_components` do, because it is the same rule:
	# heat is earned per gold of loot and it cannot outlive the loot.
	premium = maxi(0, premium - lost_hot)
	bag.clear()
	bag.merge(kept)
	# The case survives the death holding exactly what it held; it is the bag
	# around it that is gone.
	cased.clear()
	cased.merge(kept)
	# The case's components reach the bench the same way an extraction's do. This
	# is the ONE place a component survives a death, and it survives because the
	# player packed it, which is the decision §3.1 exists to create.
	var banked := bank_components()
	_end_summary(false, lost, lost_value, banked, 0, kept, lost_hot)
	in_dungeon = false
	# Dying is a way of leaving the dungeon, so the bar comes back the same way it
	# does on an extraction. Withholding it would be a second punishment stacked
	# on losing the bag, and it would land on the run AFTER the bad one.
	Game.fill_magic()
	depth = 0
	# Back to the top of the Lower Worlds, and it is reset HERE rather than left
	# for the next `enter()` to do. Between the two the player is standing in the
	# garrison with the HUD still saying FLOOR 4, which is a floor nobody is on
	# -- the run that reached it is over and the next one starts at 1 by rule.
	# The ending screen has already been handed the number it needs (`_end_summary` above).
	level = 1
	Bus.level_changed.emit(level)
	# You wake up in the garrison: broke, but alive. Leaving health at zero
	# would mean the next thing that touched you killed you again before you
	# could sell.
	Game.heal(Game.max_quarters)
	# `bag_value()`, not 0. The bag is not empty any more -- the case is in it --
	# and a HUD told the bag is worth nothing over a case holding two Void Pearls
	# is the first thing a player would file a bug about.
	Bus.bag_changed.emit(bag, bag_value())
	Bus.run_ended.emit(false, lost, lost_value)
	if not banked.is_empty():
		Bus.components_banked.emit(banked)


## Freeze what the run looked like, for `RunEndScreen`.
##
## Called by `die()` and `extract()` as their FIRST act, before either starts
## dismantling the run -- the bag, the premium pot, the floor number and the
## in_dungeon flag are all about to change, and every one of them is on the
## receipt. The screen does not draw until a frame or two later (Flow holds on
## the killing blow first), by which point reading `Run` live would report the
## state of a player standing in the garrison.
func _end_summary(extracted: bool, contents: Dictionary, value: int,
		banked: Dictionary, fee: int, kept: Dictionary = {},
		hot: int = -1) -> void:
	summary = {
		"extracted": extracted,
		"contents": contents.duplicate(),
		# The document case's contents, and what they are worth. **Only ever
		# non-empty on a death**, because that is the only ending where the case
		# means anything: an extraction brings the whole bag home and a "what you
		# kept" column beside it would be the receipt reading itself back. This is
		# the receipt's second column (docs/SCOPE.md MF).
		"kept": kept.duplicate(),
		"kept_value": _value_of(kept),
		# Which of those lines went to the bench rather than the vendor. Only ever
		# non-empty on an extraction -- components you were carrying die with the
		# bag, same as everything else in it (see `bank_components`).
		"banked": banked.duplicate(),
		"value": value,
		# The heat riding on `contents` -- not the pot, which on a death has
		# already been split between the case and the floor by the time this runs.
		# An extraction passes -1 and means the whole of it, because the whole bag
		# is what came back.
		"premium": premium if hot < 0 else hot,
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
## The Cold Ledger (`EchoDb.COLD_LEDGER`) is the one term here that is not a
## relic: it charges on `base_value()` instead of `bag_value()`, so Heat's stamp
## rides home untaxed. It is the only Echo that cuts GDD §2's central coupling
## and it is MEANT to be strong -- it dies with the run and it cost a slot, which
## is the whole reason found power is allowed to exist (`docs/PUZZLES.md` §6.2).
func extract_cost() -> int:
	var taxed := base_value() if has_echo(EchoDb.COLD_LEDGER) else bag_value()
	return maxi(EXTRACT_MIN, int(round(taxed * RelicDb.extract_rate(EXTRACT_RATE))))


## What actually leaves the purse: the toll, or everything you have, whichever is
## smaller. **This is the number the player pays and the number on the receipt.**
##
## The cap exists because the uncapped toll had no way to be complied with. It
## rises with the bag, and the bag can only be sold in the garrison, so a toll
## past your gold was a wall you could only walk further away from -- every mote
## you picked up made it taller, and the one escape (dying) destroyed the bag
## you were trying to bank. That is not a priced decision, it is a soft-lock
## with a number printed on it.
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


# --- Echoes -------------------------------------------------------------------
## `docs/PUZZLES.md` §6. An Echo is an ordinary bag line with `value: 0` (see
## `ItemDb._echo`), so everything about carrying one -- the slot, the refusal on
## a full bag, the death -- is arithmetic that already existed. What lives here
## is the two things that are not: **asking whether one is held**, and **the
## moment it goes quiet**.

## True while this Echo is in the bag. The one membership test; twelve sites read
## it and none of them touches `bag` directly.
func has_echo(id: StringName) -> bool:
	return bag.get(id, 0) > 0


## The Echo's tuning number if it is held, `fallback` if it is not.
##
## **This is how a bent rule reads at its site.** `Heat` asks
## `Run.echo(EchoDb.HELD_NOTE, 0.0)` and multiplies; nothing anywhere writes
## `if Run.has_echo(...) : window = 4.0`, because a number inlined at the site is
## a number `EchoDb`'s table no longer owns and §6.2's last paragraph is about
## exactly that. `has_echo` is for the on/off rules, which have no number at all.
func echo(id: StringName, fallback: float = 0.0) -> float:
	return EchoDb.value_of(id) if has_echo(id) else fallback


## Every Echo in the bag right now. The pedestal reads it so it never offers a
## stone the player is already carrying.
func echoes_held() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in bag:
		if EchoDb.is_echo(id):
			out[id] = int(bag[id])
	return out


## The Echoes go quiet. Returns what left, so the receipt can say so.
##
## The mirror of `bank_relics`, and the exact opposite outcome: a relic leaves
## the bag to become permanent, an Echo leaves it to become nothing. *"It does
## not survive the run. Home, garrison or death — it goes quiet"*
## (`docs/PUZZLES.md` §6), and GDD pillar 4 is why -- permanence is bought, never
## found, so a boon that outlived the walk home would be a found permanent.
##
## No premium arithmetic, exactly as `bank_relics` has none: an Echo is worth 0
## gold, so it never earned a share of the heat pot and `_premium_share`'s
## denominator does not move when it leaves.
##
## `die()` needs no equivalent -- the whole bag goes there anyway.
func bank_echoes() -> Dictionary:
	var moved: Dictionary[StringName, int] = {}
	for id: StringName in bag.keys():
		if not EchoDb.is_echo(id):
			continue
		moved[id] = int(bag[id])
		bag.erase(id)
	if not moved.is_empty():
		Bus.bag_changed.emit(bag, bag_value())
	return moved


## The Quiet Room (`EchoDb.QUIET_ROOM`): the first enemy in each room you enter
## is held for a beat, so every room opens on your terms.
##
## The NEAREST body rather than a random one, because "the first enemy" is the
## one that reached you -- holding something across the room that had not noticed
## you yet would be an Echo the player never sees work.
func _on_room_entered(_room_id: StringName) -> void:
	var seconds := echo(EchoDb.QUIET_ROOM)
	if seconds <= 0.0 or not in_dungeon:
		return
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if hero == null:
		return
	var best: Node = null
	var best_d := 1e9
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var body := node as Node3D
		if body == null or not body.has_method(&"freeze"):
			continue
		var d := hero.global_position.distance_squared_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	if best != null:
		best.call(&"freeze", seconds)


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
		if not _place(id, def):
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


## Put ONE of `id` in the bag. Returns false when nothing has room for it.
##
## **The case fills first, and that is the forgiving default on purpose.** A case
## that started empty and had to be packed by hand would be a mercy only for the
## player who reads menus, and the player MF exists for is the one who died five
## rooms down forty minutes into their first run (docs/GDD.md §3.1). Filling it as
## you go means the case is never idle; the decision arrives the moment it is
## full and something better than what is in it comes off the floor, which is the
## moment worth making a decision out of. `stow()` is that decision.
##
## Room in an existing part-stack costs no slot, in either region -- the same rule
## the bag has always had, applied twice because the two regions count their slots
## separately (`slots_used`).
func _place(id: StringName, def: ItemDef) -> bool:
	var per: int = stack_of(id)
	var have: int = bag.get(id, 0)
	if case_fits(id):
		var packed: int = cased.get(id, 0)
		if (packed > 0 and packed % per != 0) or case_slots_used() < CASE_SLOTS:
			cased[id] = packed + 1
			bag[id] = have + 1
			return true
	var held: int = have - int(cased.get(id, 0))
	if (held > 0 and held % per != 0) or hold_slots_used() < hold_slots():
		bag[id] = have + 1
		return true
	return false


# --- The document case (docs/GDD.md §3.1) -----------------------------------
# Three slots off the top of the bag. What is in them comes home; what is not,
# does not. Nine slots still die, which is what keeps §2's question -- is this
# worth the walk back -- a question.

## How many of `id` are in the case right now.
func in_case(id: StringName) -> int:
	return int(cased.get(id, 0))


## How many of `id` you are carrying OUTSIDE the case. The half that dies.
func in_hold(id: StringName) -> int:
	return int(bag.get(id, 0)) - in_case(id)


## Slots of the case that are spoken for. Counted the way the bag counts, because
## it is the same shelves: a part-stack is a whole slot.
func case_slots_used() -> int:
	return _slots_of(cased)


## Slots outside the case, and how many there are. The bag slots the smith sells
## all land here -- see `CASE_SLOTS`.
func hold_slots_used() -> int:
	var held: Dictionary[StringName, int] = {}
	for id: StringName in bag:
		var n := in_hold(id)
		if n > 0:
			held[id] = n
	return _slots_of(held)


func hold_slots() -> int:
	return maxi(Game.bag_slots - CASE_SLOTS, 0)


## **May this thing go in the case at all?**
##
## A relic does not fit -- it is a broken lump of Vyr machinery, not a document --
## and that one line is what keeps the hardest question in the design being asked
## (docs/GDD.md §3.1). An Echo will not fit either for the same reason
## (docs/PUZZLES.md §6) -- **and it has item rows now, so this is where it is
## refused.** An Echo is a run-scoped tone that dies with the run by design; a
## case slot is the promise that a thing comes home, and the two cannot both be
## true of one bag line.
func case_fits(id: StringName) -> bool:
	return not RelicDb.is_relic(id) and not EchoDb.is_echo(id)


## Why `id` cannot go in the case, in the player's words, or "" when it can.
func case_refusal(id: StringName) -> String:
	if not case_fits(id):
		return "The case takes documents. That is not one."
	if in_hold(id) <= 0:
		return "There is none of that outside the case."
	if case_room_for(id) <= 0:
		return "The case is full. Take something out of it first."
	return ""


## How many more of `id` the case will take: the slack in the part-stack it
## already holds, plus whatever whole slots are free. `Game.stash_room_for`'s
## shape, and for the same reason -- asked rather than assumed, so a screen can
## refuse before it starts a move it cannot finish.
func case_room_for(id: StringName) -> int:
	var def := ItemDb.get_def(id)
	if def == null or not case_fits(id):
		return 0
	var per: int = maxi(def.stack, 1)
	var have := in_case(id)
	var slack: int = (per - have % per) % per
	return slack + maxi(CASE_SLOTS - case_slots_used(), 0) * per


## Move up to `n` of `id` into the case (-1 for as many as will go). Returns how
## many moved. Nothing enters or leaves the bag here -- the case is a mark on what
## is already in it.
##
## **Refused whole when it would cost a slot the bag does not have.** Splitting a
## stack across the two regions costs a cell, because the two count separately,
## and a move that quietly overflowed would put a stack in the bag that the pouch
## has no cell to draw -- items that exist in the arithmetic and nowhere on the
## screen. The screens move a whole cell at a time, so this is the guard rather
## than the common case.
func stow(id: StringName, n: int = -1) -> int:
	var held := in_hold(id)
	if held <= 0 or not case_fits(id):
		return 0
	var want: int = held if n < 0 else mini(n, held)
	var moved: int = mini(want, case_room_for(id))
	if moved <= 0:
		return 0
	if _slots_with(id, in_case(id) + moved) > Game.bag_slots:
		return 0
	cased[id] = in_case(id) + moved
	Bus.bag_changed.emit(bag, bag_value())
	return moved


## Take up to `n` of `id` back out of the case. It stays in the bag; it just
## stops being the half that comes home.
func unstow(id: StringName, n: int = -1) -> int:
	var have := in_case(id)
	if have <= 0:
		return 0
	var moved: int = have if n < 0 else mini(n, have)
	if _slots_with(id, have - moved) > Game.bag_slots:
		return 0
	if moved >= have:
		cased.erase(id)
	else:
		cased[id] = have - moved
	Bus.bag_changed.emit(bag, bag_value())
	return moved


## What the case is holding, as its own dictionary. The receipt's second column
## and `die()` both want it, and neither should be iterating `cased` itself.
func case_contents() -> Dictionary[StringName, int]:
	return cased.duplicate()


## Slots `counts` would occupy, at this game's one stacking rule.
## Slots a set of counts costs. **Both regions count through here**, which is why
## the two rules that bend a slot live here and not at the two call sites.
##
##  * The Long Chord (`EchoDb.LONG_CHORD`) makes every OTHER Echo weightless. It
##    still costs its own slot, which is what makes it worth nothing until you
##    have already committed (`docs/PUZZLES.md` §6.2).
##  * `stack_of` carries the Deep Pocket, so this and `_place` agree about how
##    tall a stack is by construction. Two readers of one rule is how a bag ends
##    up saying "full" while a stack still has room.
func _slots_of(counts: Dictionary) -> int:
	var chord := has_echo(EchoDb.LONG_CHORD)
	var used := 0
	for id: StringName in counts:
		if chord and EchoDb.is_echo(id) and id != EchoDb.LONG_CHORD:
			continue
		used += int(ceil(float(counts[id]) / float(stack_of(id))))
	return used


## Slots the whole bag would occupy if `in_case` of `id` were in the case. The
## only reason this exists is the split-stack guard in `stow`/`unstow`.
func _slots_with(id: StringName, in_case_now: int) -> int:
	var total := 0
	for k: StringName in bag:
		var def := ItemDb.get_def(k)
		var per: int = maxi(def.stack if def != null else 1, 1)
		var whole: int = bag[k]
		var c: int = in_case_now if k == id else int(cased.get(k, 0))
		c = clampi(c, 0, whole)
		total += int(ceil(float(c) / float(per)))
		total += int(ceil(float(whole - c) / float(per)))
	return total


## Force the subset true again after something left the bag by any door -- a
## sale, a deposit in the footlocker, a fletching. Called by every one of them
## rather than each remembering to adjust `cased` itself, which is the same
## argument `consume()` makes about `bag` having exactly one writer.
##
## It takes from the HOLD first, because a clamp only bites once the hold's share
## of that id is gone. That is the right default in both places it happens: the
## bench eats the loose shards before the packed ones, and a sale in the garrison
## is emptying a bag that already came home.
func _case_trim() -> void:
	for id: StringName in cased.keys():
		var have: int = bag.get(id, 0)
		if have <= 0:
			cased.erase(id)
		elif int(cased[id]) > have:
			cased[id] = have


## Remove up to `requested_count` from the one displayed case or hold cell the
## player selected. The region is authoritative: dropping a loose stack cannot
## reach the packed count of the same id, while dropping a packed stack removes
## that same count from both `cased` and the containing bag total.
##
## The returned multiplier carries this slice's proportional Heat premium back
## onto the ordinary world pickup. Recollecting it therefore rounds through the
## same `collect` arithmetic instead of minting a second premium.
func drop_stack(id: StringName, requested_count: int,
		from_case: bool) -> Dictionary[StringName, Variant]:
	var dropped: Dictionary[StringName, Variant] = {}
	if id == &"" or requested_count <= 0:
		return dropped
	var def := ItemDb.get_def(id)
	if def == null:
		return dropped
	var available: int = in_case(id) if from_case else in_hold(id)
	if available <= 0:
		return dropped

	var n: int = mini(requested_count, available)
	var base := 0 if RelicDb.is_relic(id) or def.value <= 0 else def.value * n
	var share := _premium_share(base)
	var heat_mult := 1.0 + float(share) / float(base) if base > 0 else 1.0
	var have: int = bag.get(id, 0)
	if n >= have:
		bag.erase(id)
	else:
		bag[id] = have - n
	if from_case:
		var packed: int = cased.get(id, 0)
		if n >= packed:
			cased.erase(id)
		else:
			cased[id] = packed - n
	_case_trim()
	premium = maxi(0, premium - share)
	Bus.bag_changed.emit(bag, bag_value())
	dropped[&"id"] = id
	dropped[&"count"] = n
	dropped[&"heat_mult"] = heat_mult
	return dropped


## Burn `count` of `id` out of the bag without selling it. Returns how many were
## actually taken, which is 0 when the bag is short -- the caller decides whether
## that is a beep or a sentence.
##
## The premium share goes with them, exactly as it does in `sell()`. Heat is
## earned per gold of merchandise; take merchandise out of the bag by any door
## and the pot has to shrink with it, or the stacks that are left would inherit
## a bonus they never earned and the vendor would pay for arrows.
##
## The fletching calls this, and so does `steal_slot` below. It is on Run rather
## than on Fletching because the bag's bookkeeping -- the erase, the premium, the
## signal -- is Run's and nobody else's, and a second writer of `bag` is how the
## two halves of a total start to disagree.
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
	_case_trim()
	Bus.bag_changed.emit(bag, bag_value())
	return n


## **The Thief takes a slot** (docs/BESTIARY.md §3, behaviour 4). Returns
## `{"id": StringName, "count": int}` for what left, or `{}` when there was
## nothing here to take.
##
## Three rules, and each one is a decision rather than an implementation detail:
##
##  * **The HOLD only. The document case is never reachable.** The case is the
##    game's one promise -- what is in it comes home (GDD §3.1) -- and a monster
##    that could reach into it would make packing meaningless in exactly the
##    moment packing is supposed to pay. Nine slots is plenty to steal from, and
##    a player who has packed the good things is a player who prepared.
##  * **The richest slot it can reach**, not a random one. That is what makes
##    chasing it a real question: a thief that took the cheapest line would
##    always be worth ignoring, and an enemy with one right answer is the thing
##    `docs/PUZZLES.md` §10.6 rules out.
##  * **Merchandise only.** A relic is not loot and an Echo is worth 0 gold, so
##    neither can ever be the richest slot -- but both are refused explicitly
##    rather than left to the arithmetic, because "the goblin ran off with the
##    only one of these there is" is a sentence this game must never produce.
##
## The removal goes through `consume` like every other door out of the bag, so
## the heat premium follows the merchandise and `bag_changed` fires once. A slot
## is up to one stack (`stack_of`), which is the same unit `slots_used` counts
## in -- steal a 20-deep pile of shards and you lose the pile, not the cell.
func steal_slot() -> Dictionary:
	return _take_slot(true)


## Is there anything a thief could take? The same scan without the taking, and
## the exact counterpart of `burnable()` below — both exist because the caller
## has to be able to refuse BEFORE it commits.
##
## **This is what stops a thief miming at an empty hold.** `Enemy._tick_chase`
## reaches for the bag ahead of the swing, so without this question a goblin
## carrying nothing spent an empty-handed run reaching, whiffing, waiting out
## `K.THIEF_REGRAB` and reaching again — a monster in the fight that could not
## attack. And it is not merely a bug fix: GDD §2's question is *is what I am
## carrying worth more than the walk back*, and a body that asks it of a player
## carrying nothing is asking nothing at all.
func stealable() -> bool:
	return not _take_slot(true, true).is_empty()


## **The Ballast-Verse burns a slot** (`docs/GDD.md` §6.5 -- "burn the cheapest
## stack in the bag for a soak window"). Same three rules as the thief above,
## same door out of the bag, and the ONE difference is which end of the bag it
## reaches into: the cheapest line rather than the richest.
##
## That difference is the design and not a preference. The thief has to hurt or
## chasing it is not a question; Ballast has to be affordable in the moment or
## nobody would ever cast it, and a working that ate your Deep Amber would be a
## button the player learns never to press. What it still costs is real -- it is
## a slot, and a slot is a slot whatever is in it, so the fee and the walk home
## both notice.
##
## Returns `{"id": ..., "count": ...}` for what burned, or `{}` when the hold was
## empty -- which is the caller's cue to refuse the cast and keep the charge.
func burn_slot() -> Dictionary:
	return _take_slot(false)


## Is there anything Ballast could burn? The same scan without the taking, so the
## cast can refuse BEFORE it spends a charge -- a working that goes off, finds an
## empty hold and quietly costs you a charge is the pouch lying at the worst
## moment, which is the argument `_read_burst` already makes about the quiver.
func burnable() -> bool:
	return not _take_slot(false, true).is_empty()


## The one walk over the hold, from both ends. Written once because the callers
## differ by a comparison, and two copies of "which slots may be taken" is how a
## relic or an Echo eventually becomes stealable in one of them.
##
## `dry` answers the question without emptying the bag to find out. It returns
## the row it WOULD take, so a caller that wants to name it in a prompt can.
func _take_slot(richest: bool, dry: bool = false) -> Dictionary:
	var best_id: StringName = &""
	var best_n := 0
	var best_worth := -1
	for id: StringName in bag:
		if RelicDb.is_relic(id) or EchoDb.is_echo(id):
			continue
		var held := in_hold(id)
		if held <= 0:
			continue
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var n: int = mini(held, stack_of(id))
		var worth: int = def.value * n
		# `best_worth < 0` is the first candidate and takes it either way, so the
		# cheapest search does not need a sentinel of its own.
		var better := worth > best_worth if richest else (best_worth < 0 or worth < best_worth)
		if better:
			best_worth = worth
			best_id = id
			best_n = n
	if best_id == &"" or best_n <= 0:
		return {}
	if dry:
		return {"id": best_id, "count": best_n}
	var took := consume(best_id, best_n)
	if took <= 0:
		return {}
	return {"id": best_id, "count": took}


## Slots consumed. A stack of 20 bone shards with stack==20 is one slot; the
## twenty-first starts a second.
##
## The two regions are counted SEPARATELY and added, which is the one place the
## case changes an old number: a stack split across the case and the hold sits in
## two cells and costs two slots. That is what the pouch draws, and the picture
## and the arithmetic are not allowed to disagree (`MenuPouchPanel`'s opening
## argument).
func slots_used() -> int:
	return case_slots_used() + hold_slots_used()


## How many of `id` fit in one slot, right now.
##
## The Deep Pocket doubles it for COMMON rows only: *it does not add a slot -- it
## changes what is worth bending down for*, which is the more interesting half of
## the bag (`docs/PUZZLES.md` §6.1, row 8). Public because `slots_used` and
## `collect` are two readers of the same rule and must not each have an opinion.
func stack_of(id: StringName) -> int:
	var def := ItemDb.get_def(id)
	var per: int = def.stack if def != null else 1
	if def != null and def.rarity == ItemDef.Rarity.COMMON:
		var mult := echo(EchoDb.DEEP_POCKET, 1.0)
		if mult > 1.0:
			per = int(round(float(per) * mult))
	return maxi(per, 1)


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
	return _base_of(bag)


## What an arbitrary slice of the bag is worth, heat included -- the figure the
## receipt prints over a column.
##
## Split out of `bag_value()` the day the bag started ending a run in two pieces
## (`die()`): what the floor kept and what the case brought home are each a
## sub-bag, and each has to carry its own share of the same pot. Passing `bag`
## itself gives exactly `bag_value()`, which is the check that this is one
## arithmetic and not two.
func _value_of(slice: Dictionary) -> int:
	var flat := _base_of(slice)
	return flat + _premium_share(flat - _relic_toll_of(slice))


func _base_of(slice: Dictionary) -> int:
	var total := 0
	for id: StringName in slice:
		var def := ItemDb.get_def(id)
		if def != null:
			total += def.value * int(slice[id])
	return total


func _relic_toll_of(slice: Dictionary) -> int:
	var total := 0
	for id: StringName in slice:
		if not RelicDb.is_relic(id):
			continue
		var def := ItemDb.get_def(id)
		if def != null:
			total += def.value * int(slice[id])
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
	return _merchandise_sale_price(base, _premium_share(base))


func _merchandise_sale_price(base: int, premium_share: int) -> int:
	return int(round(float(base + premium_share)
		* RelicDb.vendor_price_mult() * Game.warmth_sell_mult()))


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
	var ids: Array[StringName] = []
	for id: StringName in bag:
		if not RelicDb.is_relic(id):
			ids.append(id)
	return sell_ids(ids)


## What selling every stack named by `ids` will pay, including the exact share
## of the current heat premium and the live vendor multiplier.
func sale_value(ids: Array[StringName]) -> int:
	var sold := _sale_slice(ids)
	if sold.is_empty():
		return 0
	var base := _base_of(sold)
	return _merchandise_sale_price(base, _premium_share(base))


## Atomically sell the explicit id set. Run owns the bag bookkeeping; callers
## decide policy (for example, which marked items a bulk action protects).
func sell_ids(ids: Array[StringName]) -> int:
	var sold := _sale_slice(ids)
	if sold.is_empty():
		return 0
	var base := _base_of(sold)
	var share := _premium_share(base)
	var paid := _merchandise_sale_price(base, share)
	if paid <= 0:
		return 0
	for id: StringName in sold:
		bag.erase(id)
	premium = maxi(0, premium - share)
	_case_trim()
	Game.add_gold(paid)
	Bus.bag_changed.emit(bag, bag_value())
	Bus.items_sold.emit(sold, paid)
	return paid


func _sale_slice(ids: Array[StringName]) -> Dictionary[StringName, int]:
	var sold: Dictionary[StringName, int] = {}
	for id: StringName in ids:
		if sold.has(id) or RelicDb.is_relic(id):
			continue
		var def := ItemDb.get_def(id)
		var count: int = bag.get(id, 0)
		if def != null and count > 0:
			sold[id] = count
	return sold


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
	var paid := _merchandise_sale_price(base, share)
	premium -= share

	if n >= have:
		bag.erase(id)
	else:
		bag[id] = have - n
	_case_trim()
	Game.add_gold(paid)
	Bus.bag_changed.emit(bag, bag_value())
	Bus.items_sold.emit({id: n}, paid)
	return paid


## Whether this generated room was already entered on the current floor.
func has_visited_room(room_id: StringName) -> bool:
	return visited_rooms.has(room_id)


## Record the entrance without charging depth. The entrance is visible from the
## first frame, but depth still means rooms walked into beyond that starting cell.
func remember_room(room_id: StringName) -> void:
	if room_id != &"":
		visited_rooms[room_id] = true


## Called by the dungeon on first entry. Returns false for a room restored from
## a save (or revisited normally), which is what keeps depth from climbing twice.
func enter_room(room_id: StringName) -> bool:
	if room_id == &"" or visited_rooms.has(room_id):
		return false
	visited_rooms[room_id] = true
	depth += 1
	Bus.depth_changed.emit(depth)
	return true
