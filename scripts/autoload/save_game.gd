extends Node
## Autoload `Saves`. Three save slots, in the spirit of the source material.
##
## A slot captures everything in `Game` plus where the hero was standing, so
## loading drops you back in the right room. The menu package owns the UI; this
## owns the format, the slots, and the disk.

const DIR := "user://saves"
const SLOTS := 3
## Bumped to 2 when the forge landed: `upgrades` was never written at all (a v1
## save silently reloaded with every purchase undone) and `components` did not
## exist. `_read` refuses a version it does not recognise, so a v1 slot reads as
## empty rather than as a hero who lost his sharpenings — which is the honest
## failure, and there is no live save worth migrating in a dev build.
## Bumped to 3 when the bottles landed: a bottle is a purchase and what is in it
## was paid for, so both have to survive quitting exactly as a forge rung does.
## `_read` still refuses a version it does not recognise, so a v2 slot reads as
## empty rather than as a hero whose glass quietly vanished.
##
## Bumped to 4 by two changes at once, which is why this note is long.
##
## The **footlocker** (`Game.stash`) is purely additive: a v3 slot has no
## `stash` key and the honest reconstruction of a v3 hero is one whose locker is
## empty, which is exactly what `d.get("stash", {})` builds. On its own that bump
## would not have refused v3, and `READABLE` below exists so a future additive
## bump does not have to.
##
## The **gear split** is not additive, and it wins. A v3 slot holds
## `{"plate": 3}` — 3 HP of soak — and since `plate` became four
## pieces × two paths (docs/GDD.md §6.6) there is no honest place to put it.
## Spending it on one piece (`plate_chest_heavy` at rung 3) is 1.0 HP, a
## silent two-thirds cut to a number the player paid for. Spreading it over four
## pieces commits all four to heavy — the one thing §6.6 says can never be undone
## — on the player's behalf, without asking. Refusing reads as an empty slot,
## which is honest and loud; both alternatives read as a save that loaded fine
## and lied.
##
## So: **v3 is refused, not migrated**, and `READABLE` holds 4 alone.
## `max_stamina` joins the format in the same bump — Focus buys it now, so a slot
## that did not record it would reload the amulet as unpurchased.
##
## Bumped to 5 for `deaths`, and this is the additive bump the paragraph above
## anticipated: mercy climbs with how many times this save has died (GDD §7.1),
## and a v4 slot has no such key. `d.get("deaths", 0)` reconstructs it as a hero
## who has not died yet, which understates the number and never overstates it —
## the failure mode is a returning player getting slightly less forgiveness than
## they had earned, not a fresh save arriving pre-softened. So v4 stays readable.
##
## Bumped to 6 for `gold_earned`, and it is additive in the same way `deaths` was.
## `StoryDb` gates the garrison's later conversations on how much a save has ever
## earned, and a v5 slot has no such key. The reconstruction is `gold` — what is
## in the purse is a floor on what was earned into it — which understates a hero
## who has been spending and never overstates one. The failure mode is a returning
## player waiting one extra run for a line they had already paid for; the
## alternative, defaulting to 0, would take Aldric's story about the last cadet
## back off a save that had unlocked it. So v5 stays readable.
##
## Bumped to 7 for `wheel`, the kit wheel's eight bindings, and it is additive in
## exactly the way `deaths` and `gold_earned` were. A v6 slot has no such key and
## is reconstructed as the blank-plus-sword seed rather than as a wheel rebuilt
## out of `items` — see the read, which explains why guessing would be worse than
## an honest empty. The failure mode is a returning player pressing LB once and
## finding one slot filled, on a wheel whose entire teaching move is that you can
## see what is on it. So v6 stays readable.
## Bumped to 8 for `rations`, the quartermaster's food and drink (card #98), and
## it is additive in the same way `wheel` was. A v7 slot has no such key and comes
## back with an empty pack, which is the TRUTH about a hero who played before the
## counter stocked any — nothing is lost and nothing has to be guessed at. So v7
## stays readable, and so does everything v7 read.
##
## Bumped to 9 for transform ownership. A dungeon save deliberately points HOME
## because a slot holds no `Run`, but v8 paired that garrison destination with the
## live dungeon hero's position. `position_scene` now says which scene owns a
## transform, and `pos` / `yaw` are written and restored only when that owner is
## also the destination. v4-v8 remain readable, but their owner cannot be proved,
## so their transform is omitted on load and the authored spawn wins once.
##
## Bumped to 10 for resumable dungeon runs and a wall-clock last-played header.
## A v9 slot has no run snapshot and remains a conservative garrison load; v10
## records the actual dungeon as both destination and transform owner.
## Bumped to 11 for manual wishlist tracks. It is additive: v4-v10 have no pins
## and reconstruct honestly as an empty list, while current recipes stay derived.
## Bumped to 12 for garrison firewood and Warmth. It is additive: v11 has no
## payload and reconstructs as an empty, cold hearth.
## Bumped to 13 for Field Notes. It is additive: v4-v12 have no awarded
## observations or balance and reconstruct as zero/empty.
## Bumped to 14 for temporary overhealth. It is additive: v4-v13 have no such
## health and reconstruct as zero.
## Bumped to 15 for the additive fishing, supper, Well Fed and Connected fields
## inside the existing garrison payload. A v14 slot reconstructs them empty.
## Bumped to 16 for the health-points vocabulary. v15 remains readable: its
## health fields, permanent upgrade id and restorative draught id are migrated
## at the three narrow read seams below.
## Bumped to 17 for completed Field Notes. A v16 slot has only filed/awarded ids;
## each of those is also completed, while no other completion can be inferred.
## Bumped to 18 for durable utility tools. Older owned Woodsman's Axes migrate
## to full durability; the additive tool manifest is otherwise empty.
## Bumped to 19 so a non-dungeon Run snapshot is restored instead of discarded.
## Legacy carrying_firewood becomes a bag bundle after Run state is restored.
## Bumped to 20 for the additive persistent garden payload inside `garrison`.
## Older slots have no planted sites and reconstruct as an empty garden.
## Bumped to 21 for the additive quest payload. Older slots reconstruct only the
## quest outcomes already proved by their story, raid, tool, and supply state.
## Bumped to 22 for finite Glint Trial completion ids. v21 and older have no
## solved trial and therefore reconstruct with no Glint ranks or Glimmer.
const VERSION := 22
## Versions this build will still read. **Not every bump has to refuse the one
## before it** — a bump that only ADDS a key can list the older version here and
## let `d.get(key, default)` do the migration. v3 is absent only because the gear
## split changed the meaning of a key that was already in the file, which is the
## same reason v1 and v2 were refused.
const READABLE: Array[int] = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
const AUTOSAVE_INTERVAL := 300.0

signal saved(slot: int)
signal loaded(slot: int)
## Fired by `autosave()` only, and separately from `saved`, because the HUD says
## something about one of them and must not say it about the other: a manual
## save is made with the menu open and needs no notice, and an autosave happens
## behind a fade with nobody's hand on a button. `slot` is -1 when the autosave
## declined (see `autosave`), so a listener can stay silent rather than claim
## something was written.
signal autosaved(slot: int)

## Set by the dungeon package when it changes rooms, so a save knows where to
## put you back. Falls back to the current scene if nobody sets it.
var current_room: StringName = &""
var current_scene_path: String = ""

var active_slot: int = -1
var _autosave_elapsed := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func _process(delta: float) -> void:
	_advance_autosave(delta)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Header for the slot-select screen. Never returns null — an empty slot
## reports `empty = true` so the UI can draw "New Game" without branching.
func peek(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"empty": true, "slot": slot}
	var d := _read(slot)
	if d.is_empty():
		return {"empty": true, "slot": slot, "corrupt": true}
	var raw_run: Variant = d.get("run", {})
	var run_data: Dictionary = raw_run as Dictionary if raw_run is Dictionary else {}
	var has_run := not run_data.is_empty()
	var underground := has_run and bool(run_data.get("in_dungeon", false))
	var saved_level := maxi(int(run_data.get("level", 1)), 1) if underground else 1
	# v15 and earlier used these two field names. They are fallbacks only: peek's
	# returned live header uses the health-points schema below.
	var health_points := int(d.get("health_points", d.get("quarters", 0)))
	var max_health_points := int(
		d.get("max_health_points", d.get("max_quarters", 0)))
	return {
		"empty": false,
		"slot": slot,
		"health_points": health_points,
		"max_health_points": max_health_points,
		"gold": d.get("gold", 0),
		"keys": d.get("small_keys", 0),
		"last_played_unix": d.get("last_played_unix", 0),
		"in_dungeon": underground,
		"floor": saved_level,
		"level": saved_level,
		"depth": maxi(int(run_data.get("depth", 0)), 0) if underground else 0,
		"room": d.get("room", "") if underground else "",
		"scene": d.get("scene", Flow.GARRISON) if has_run else Flow.GARRISON,
		"items": (d.get("items", {}) as Dictionary).keys(),
		"played": d.get("played", 0.0),
		"stamp": d.get("stamp", ""),
	}


func save(slot: int) -> bool:
	var hero := get_tree().get_first_node_in_group(&"player")
	var destination_scene := _save_scene()
	var position_scene := _scene_path()

	var d := {
		"version": VERSION,
		"stamp": Time.get_datetime_string_from_system(false, true),
		"played": Time.get_ticks_msec() / 1000.0,
		"last_played_unix": Time.get_unix_time_from_system(),
		"health_points": Game.health_points,
		"max_health_points": Game.max_health_points,
		"temporary_overhealth": Game.temporary_overhealth,
		# A Focus amulet raises this permanently, so it is a purchase and it saves.
		# Well Fed is carried in `garrison`; it must never become a saved purchase.
		"max_stamina": Game.max_stamina - Game.well_fed_bonus(),
		# The SIZE of the blue bar saves; how much is in it does not, for the reason
		# `stamina` is absent from this block -- see the loader. A `"magic"` key was
		# written here and it is gone rather than left unread: a save field nothing
		# restores is the next reader's wrong conclusion about what persists.
		"max_magic": Game.max_magic,
		"gold": Game.gold,
		# The LIFETIME total, which is what the garrison's conversations are gated
		# on (`StoryDb`). It is not derivable from anything else in this block —
		# `gold` is what survived the spending — so it has to be its own key.
		"gold_earned": Game.gold_earned,
		"field_notes": Game.field_notes,
		"completed_field_observations": Game.completed_field_observations.keys(),
		"awarded_field_observations": Game.awarded_field_observations.keys(),
		"solved_glint_trials": Game.solved_glint_trials.keys(),
		"deaths": Game.deaths,
		"bag_slots": Game.bag_slots,
		# Every permanent purchase, forge rungs included -- the ladders live in
		# `upgrades` (see Game.FORGE_TRACKS), so one key carries all twelve, and
		# the jewelcrafter's eight after it.
		"upgrades": Game.upgrades,
		"garrison": Game.garrison_snapshot(),
		# One authoritative surface/dungeon clock. Weather derives from day, so no
		# second weather payload can drift from it.
		"clock": Clock.snapshot(),
		# Stable catalogue namespace + line ids only. Ingredient ids are rebuilt
		# from each catalogue's current recipe after load.
		"wishlist_lines": Game.wishlist_save_data(),
		"components": Game.components,
		# The footlocker. Merchandise the player carried home and chose not to
		# sell -- it already survived a run, so it has to survive a quit.
		"stash": Game.stash,
		# The array's size is how many bottles there are, so one key carries both
		# the glass and the contents. The DRAUGHT CLOCKS are deliberately not
		# saved -- see Game.draughts.
		"bottles": Game.bottle_contents,
		"arrows": Game.arrows,
		# Was "bombs". The satchel became a working (GDD §6.5) and the field went
		# with the noun; the READ below still answers to the old key, so this is a
		# rename rather than the new save field `docs/SCOPE.md` §1 refuses.
		"charges": Game.charges,
		# The pack: ration id -> how many. The MEAL is deliberately not here --
		# twelve seconds of sitting restored by a load would be a meal you spend
		# the loading screen on, which is the bargain `draughts` already struck
		# (see `Game.meal_id`).
		"rations": Game.rations,
		"small_keys": Game.small_keys,
		"has_boss_key": Game.has_boss_key,
		"boss_key_level": Game.boss_key_level,
		"has_map": Game.has_map,
		"has_compass": Game.has_compass,
		"items": Game.items,
		"tool_durability": Game.tool_durabilities,
		"item_selected": Game.item_selected,
		# The kit wheel's eight bindings. A flat array of ids, which is the whole
		# reason the wheel encodes a bottle as a `bottle_N` token rather than as a
		# typed record -- the save file is ids everywhere else and this row did
		# not have to invent a shape for itself.
		"wheel": Game.wheel,
		"loadout": Game.loadout,
		"loadout_set": Game.loadout_set,
		"flags": Game.flags,
		"quests": Game.quest_snapshot(),
		"run": Run.snapshot(),
		"room": String(current_room),
		"scene": destination_scene,
		# Proof of which scene owns the live hero transform. v9 used this to keep
		# dungeon coordinates out of a garrison destination; v10 records the actual
		# dungeon as both owner and destination because its Run now travels too.
		"position_scene": position_scene,
	}
	# Never pair coordinates from one scene with another. This remains the v9
	# compatibility guard and protects any future non-player save context too.
	if hero is Node3D and position_scene == destination_scene:
		var pos := (hero as Node3D).global_position
		d["pos"] = [pos.x, pos.y, pos.z]
		d["yaw"] = (hero as Node3D).global_rotation.y
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Saves: cannot write slot %d" % slot)
		return false
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	active_slot = slot
	_autosave_elapsed = 0.0
	saved.emit(slot)
	return true


## The actual live scene. `current_scene_path` remains only as the harness
## fallback for trees attached without `SceneTree.current_scene`; a real v10 save
## never rewrites a dungeon destination to the garrison.
func _save_scene() -> String:
	var actual := _scene_path()
	return actual if actual != "" else current_scene_path


## Commit the metagame without anyone asking. Called by `Flow` on every scene
## transition — into the dungeon, down a floor, and home whether you walked out
## or were carried (game_flow.gd `_go`).
##
## WHICH SLOT is the whole question here, and the rule is that an autosave never
## destroys a save a player made by hand:
##
##   1. the slot you are already playing, if you have saved or loaded one;
##   2. otherwise the first EMPTY slot, which it then keeps (step 1 from here on);
##   3. otherwise nothing at all, and it says so with slot -1.
##
## Step 3 is a player who has filled all three slots deliberately and manages
## them by hand. Picking one to overwrite for them — oldest, first, any of it —
## is the autosave deciding which of their saves mattered least, and it will
## eventually be wrong about a save they cannot get back.
func autosave() -> bool:
	var slot := active_slot
	if slot < 0:
		for i in SLOTS:
			if not has_save(i):
				slot = i
				break
	if slot < 0:
		autosaved.emit(-1)
		return false
	var ok := save(slot)
	autosaved.emit(slot if ok else -1)
	return ok


## Small director seam: exercise the cadence without waiting five real minutes.
## It goes through the same eligibility checks and the same `autosave()` policy
## as `_process`; callers cannot nominate a slot or bypass a full-slot refusal.
func _debug_advance_autosave(seconds: float) -> bool:
	return _advance_autosave(seconds)


func _advance_autosave(seconds: float) -> bool:
	if seconds <= 0.0 or get_tree().paused or Flow.busy:
		return false
	if get_tree().get_first_node_in_group(&"player") == null:
		return false
	_autosave_elapsed += seconds
	if _autosave_elapsed < AUTOSAVE_INTERVAL:
		return false
	# A declined autosave gets another try in five minutes, not on every frame.
	# Successful writes reset this to zero inside `save()`.
	_autosave_elapsed -= AUTOSAVE_INTERVAL
	return autosave()


## Restore `Game` from a slot and return where the hero should be placed.
## Returns an empty dictionary if the slot is missing or unreadable — changing
## scenes is the caller's job, since only it knows how it wants to transition.
func load_slot(slot: int) -> Dictionary:
	var d := _read(slot)
	if d.is_empty():
		return {}

	# v15 and earlier stored the same integer values under the old field names.
	Game.max_health_points = int(d.get(
		"max_health_points", d.get("max_quarters", K.START_HEALTH_POINTS)))
	Game.health_points = int(d.get(
		"health_points", d.get("quarters", Game.max_health_points)))
	# Clamped rather than trusted: `K.STAMINA_MAX` is the ceiling every Focus
	# purchase already respects, and a hand-edited slot must not out-buy the shop.
	Game.max_stamina = minf(K.STAMINA_MAX,
		float(d.get("max_stamina", K.MAX_STAMINA)))
	# Garrison/legacy default. A valid v10 dungeon snapshot overwrites this after
	# all permanent fields have been rebuilt.
	Game.stamina = Game.max_stamina
	# Keep reading the compatibility field so a pre-blue-bar zero remains valid,
	# but never let a saved larger number define the live ceiling. Upgrade ranks
	# are loaded below and `resync_maxima` is the sole authority after that.
	var saved_max_magic := int(d.get("max_magic", K.MAX_MAGIC))
	Game.max_magic = K.MAX_MAGIC if saved_max_magic <= 0 \
		else clampi(saved_max_magic, K.MAX_MAGIC, K.MAGIC_MAX)
	Game.magic = Game.max_magic
	Game.gold = d.get("gold", 0)
	# A v5 slot has no lifetime tally and falls back to the purse — see the note on
	# VERSION. NOT clamped up to `gold` on a v6 slot, which would be the obvious
	# belt and would be wrong: a save that has never earned anything is still
	# holding `K.START_GOLD`, so `max(earned, gold)` would credit every new hero
	# with a haul they were given.
	Game.gold_earned = int(d.get("gold_earned", Game.gold))
	Game.deaths = int(d.get("deaths", 0))
	Game.bag_slots = int(d.get("bag_slots", K.START_BAG_SLOTS))
	# JSON has no StringName and no typed Dictionary, so both of these come back
	# as plain String keys in an untyped Dictionary. Rebuild rather than assign:
	# `Game.upgrades` is Dictionary[StringName, int] and a String key in it makes
	# `forge_level(&"edge")` miss every time — a hero who paid for the ladder and
	# reloads holding the bare blade.
	Game.upgrades.clear()
	for k in (d.get("upgrades", {}) as Dictionary):
		var upgrade_id := StringName(k)
		# v15 and earlier called the permanent +4 HP ladder "heart". Collapse it
		# into the live id instead of retaining a duplicate runtime key.
		if upgrade_id == &"heart":
			upgrade_id = &"health"
		Game.upgrades[upgrade_id] = maxi(
			int(Game.upgrades.get(upgrade_id, 0)),
			int((d["upgrades"] as Dictionary)[k]))
	# Stored capacity alone cannot reveal whether it includes the old 12-cell
	# baseline, so rebuild that baseline from the purchased rank without reducing
	# a larger explicit stored value.
	var bag_slot_rank: int = clampi(int(Game.upgrades.get(&"bag_slot", 0)),
		0, int(SupplyDb.LIMITS[&"bag_slot"]))
	Game.bag_slots = maxi(Game.bag_slots, K.START_BAG_SLOTS + bag_slot_rank)
	var bed_rank: int = clampi(
		int(Game.upgrades.get(ElderUpgradeDb.BED_ID, 0)),
		0, int(ElderUpgradeDb.LIMITS[ElderUpgradeDb.BED_ID]))
	var maximum_overhealth: int = bed_rank * ElderUpgradeDb.BED_OVERHEALTH_PER_RANK
	Game.temporary_overhealth = clampi(
		int(d.get("temporary_overhealth", 0)), 0, maximum_overhealth)
	# Doctrines share the upgrade store, but unlike forge tracks each has exactly
	# one rung. Clamp loaded state at the definition boundary so no save can turn
	# an effect into a multiplier by carrying rank 2 or higher.
	var owned_doctrines: int = 0
	for doctrine_id: StringName in FieldNotesDb.DOCTRINE_IDS:
		var rank: int = clampi(int(Game.upgrades.get(doctrine_id, 0)),
			0, FieldNotesDb.DOCTRINE_RANKS)
		if rank <= 0:
			Game.upgrades.erase(doctrine_id)
		else:
			Game.upgrades[doctrine_id] = rank
			owned_doctrines += rank
	# Glint ranks are one-rung purchases. Trial ids are the only backing value,
	# so sanitize both sides and remove any edited excess in reverse authored
	# order before the derived balance or maxima can observe it.
	for glint_id: StringName in GlintDb.UPGRADE_IDS:
		var glint_rank := clampi(
			int(Game.upgrades.get(glint_id, 0)), 0, GlintDb.RANKS)
		if glint_rank <= 0:
			Game.upgrades.erase(glint_id)
		else:
			Game.upgrades[glint_id] = glint_rank
	Game.solved_glint_trials.clear()
	var raw_glint_trials: Variant = d.get("solved_glint_trials", [])
	if raw_glint_trials is Array:
		for raw_id: Variant in raw_glint_trials:
			if raw_id is not String and raw_id is not StringName:
				continue
			var trial_id := StringName(raw_id)
			if GlintDb.TRIAL_IDS.has(trial_id):
				Game.solved_glint_trials[trial_id] = true
	var excess_glint_spent := Game.glint_spent() - Game.solved_glint_trials.size()
	for i: int in range(GlintDb.UPGRADE_IDS.size() - 1, -1, -1):
		if excess_glint_spent <= 0:
			break
		var remove_id: StringName = GlintDb.UPGRADE_IDS[i]
		if int(Game.upgrades.get(remove_id, 0)) <= 0:
			continue
		Game.upgrades.erase(remove_id)
		excess_glint_spent -= 1
	# JSON rebuild and catalogue validation are both required: a plain String key
	# would never match a StringName observation, and an unknown id must not mint a
	# note merely because it appeared in a hand-edited slot.
	Game.awarded_field_observations.clear()
	var raw_observations: Variant = d.get("awarded_field_observations", [])
	if raw_observations is Array:
		for raw_id: Variant in raw_observations:
			if raw_id is not String and raw_id is not StringName:
				continue
			var observation_id: StringName = StringName(raw_id)
			if FieldNotesDb.is_observation(observation_id):
				Game.awarded_field_observations[observation_id] = true
	# Completion is additive in v17. Earlier saves can prove only that every
	# already-awarded entry was completed; missing state otherwise stays empty.
	Game.completed_field_observations.clear()
	var raw_completed: Variant = d.get("completed_field_observations", [])
	if raw_completed is Array:
		for raw_id: Variant in raw_completed:
			if raw_id is not String and raw_id is not StringName:
				continue
			var observation_id: StringName = StringName(raw_id)
			if FieldNotesDb.is_observation(observation_id):
				Game.completed_field_observations[observation_id] = true
	for observation_id: StringName in Game.awarded_field_observations:
		Game.completed_field_observations[observation_id] = true
	var raw_field_notes: Variant = d.get("field_notes", 0)
	var saved_field_notes: int = int(raw_field_notes) \
		if raw_field_notes is int or raw_field_notes is float else 0
	var filed_value: int = 0
	for observation_id: StringName in Game.awarded_field_observations:
		filed_value += FieldNotesDb.observation_note_value(observation_id)
	var maximum_balance: int = maxi(0,
		filed_value - owned_doctrines * FieldNotesDb.DOCTRINE_COST)
	Game.field_notes = clampi(saved_field_notes, 0, maximum_balance)
	var raw_garrison: Variant = d.get("garrison", {})
	var legacy_carrying_firewood: bool = int(d.get("version", 0)) < VERSION \
		and raw_garrison is Dictionary \
		and bool((raw_garrison as Dictionary).get("carrying_firewood", false))
	Game.restore_garrison(raw_garrison as Dictionary if raw_garrison is Dictionary else {})
	# Upgrades own the permanent ceilings; the garrison payload owns the temporary
	# trip bit. Derive them without healing saved health, then fill the two
	# garrison-default resources before Run.restore optionally replaces a valid
	# dungeon snapshot's spent amounts.
	Game.resync_maxima(false)
	Game.stamina = Game.max_stamina
	Game.fill_magic()
	Clock.restore(d.get("clock", {}) as Dictionary)
	Game.restore_wishlist_lines(d.get("wishlist_lines", []) as Array)
	Game.components.clear()
	for k in (d.get("components", {}) as Dictionary):
		Game.components[StringName(k)] = int((d["components"] as Dictionary)[k])
	# Same rebuild, same reason. A v3 slot has no "stash" key at all and comes
	# back with an empty locker, which is the truth about a hero who never had
	# one -- see the note on READABLE.
	Game.stash.clear()
	for k in (d.get("stash", {}) as Dictionary):
		Game.stash[StringName(k)] = int((d["stash"] as Dictionary)[k])
	# Rebuilt element by element for the reason `upgrades` is: JSON has no
	# StringName, so an assigned array would come back full of Strings and
	# `bottle_index()` would parse fine while `PotionDb.has()` missed every
	# lookup -- a bottle that draws as full and refuses to be drunk. Clamped to
	# K.BOTTLE_MAX so a hand-edited slot cannot hand out a fifth.
	Game.bottle_contents.clear()
	for c in (d.get("bottles", []) as Array):
		if Game.bottle_contents.size() >= K.BOTTLE_MAX:
			break
		var potion := StringName(c)
		# v15 and earlier used the old restorative draught id. Convert it before
		# catalogue validation so the bottle remains full and drinkable.
		if potion == &"heart_draught":
			potion = &"health_draught"
		Game.bottle_contents.append(potion if PotionDb.has(potion) else &"")
	# Rebuilt key by key for `upgrades`' reason -- JSON has no StringName, so an
	# assigned dictionary comes back keyed by String and `RationDb.has()` misses
	# every lookup: food that draws in the cell and cannot be eaten. Sieved
	# through the catalogue and clamped to the stack, so a hand-edited slot cannot
	# hand out an id that does not exist or a twenty-first biscuit.
	Game.rations.clear()
	for k in (d.get("rations", {}) as Dictionary):
		var rid := StringName(k)
		if not RationDb.has(rid):
			continue
		var n := clampi(int((d["rations"] as Dictionary)[k]), 0, K.RATION_STACK)
		if n > 0:
			Game.rations[rid] = n
	Game.arrows = d.get("arrows", 0)
	# The old key is the FALLBACK, not a second field: a save written before
	# Burst had a name carried its stock under "bombs", and dropping it would
	# quietly empty the pouch of anyone who had bought some.
	Game.charges = d.get("charges", d.get("bombs", 0))
	Game.small_keys = d.get("small_keys", 0)
	Game.has_boss_key = d.get("has_boss_key", false)
	Game.boss_key_level = maxi(int(d.get("boss_key_level", 0)), 0)
	Game.has_map = d.get("has_map", false)
	Game.has_compass = d.get("has_compass", false)

	Game.items.clear()
	for k in (d.get("items", {}) as Dictionary):
		Game.items[StringName(k)] = true
	# Tool state is rebuilt through the authoritative catalogue. Keep valid zero
	# entries (broken is known), clamp positive uses, and restore the compatibility
	# ownership gate only for usable tools.
	Game.tool_durabilities.clear()
	var raw_tool_durability: Variant = d.get("tool_durability", {})
	if raw_tool_durability is Dictionary:
		for raw_id: Variant in raw_tool_durability:
			if raw_id is not String and raw_id is not StringName:
				continue
			var tool_id := StringName(raw_id)
			if not ToolDb.has(tool_id):
				continue
			var uses := clampi(int((raw_tool_durability as Dictionary)[raw_id]),
				0, ToolDb.max_durability(tool_id))
			Game.tool_durabilities[tool_id] = uses
	# The axe predates durability. This applies to pre-v18 slots and to a current
	# payload missing the additive key, so legacy ownership never loads broken.
	if Game.has(ToolDb.WOODSMAN_AXE_ID) \
			and not Game.tool_durabilities.has(ToolDb.WOODSMAN_AXE_ID):
		Game.tool_durabilities[ToolDb.WOODSMAN_AXE_ID] = \
			ToolDb.max_durability(ToolDb.WOODSMAN_AXE_ID)
	for tool_id: StringName in ToolDb.TOOL_IDS:
		if Game.tool_durability(tool_id) > 0:
			Game.items[tool_id] = true
		else:
			Game.items.erase(tool_id)
	Game.flags.clear()
	for k in (d.get("flags", {}) as Dictionary):
		Game.flags[StringName(k)] = true
	# The old boss-count arrival path could latch the smith before maker's marks
	# existed. That downstream arrival fact makes restoring its prerequisite honest.
	if Game.flag(StoryDb.arrival_flag(&"smith")) and not Game.has(StoryDb.SMITH_TOKEN):
		Game.items[StoryDb.SMITH_TOKEN] = true
	# `quick_slots` / `c_items` were the two names the D-pad BINDINGS were saved
	# under. There are no bindings any more (Game.item_selected), so an old save
	# simply drops them -- the ring is derived from what you own, and what you own
	# is in "items" and "bottles", which still load. The selection itself is
	# clamped on read rather than trusted: a save with four bottles restored into
	# a game with one is a `bottle_contents[3]` on the first press of X.
	Game.item_selected = int(d.get("item_selected", 0))

	# The kit wheel. Rebuilt slot by slot through `wheel_bind` rather than
	# assigned wholesale, and that is not defensiveness for its own sake -- the
	# bind is the only thing that knows a `bottle_4` token is meaningless in a
	# game with three bottles, and it is the only thing that refuses a duplicate.
	# JSON hands back plain Strings, so every entry needs the StringName anyway.
	#
	# A save written before the wheel existed has no "wheel" key: the loop does
	# not run, and what survives is the blank-plus-sword `Game.reset()` seeded,
	# which is exactly what an old save should come back as. The auto-bind then
	# fills it from `items` on the next pickup rather than at load time -- a load
	# that silently rebuilt the wheel out of everything you own would overwrite a
	# curated one on the first save/load cycle after this landed.
	#
	# This runs AFTER "items" and "bottles" above, and the order is load-bearing
	# for the same reason `add_bottle`'s is: `wheel_bindable` asks what you own.
	var bound: Array = d.get("wheel", [])
	if not bound.is_empty():
		Game.wheel.fill(&"")
		for i in mini(bound.size(), Game.wheel.size()):
			Game.wheel_bind(i, StringName(bound[i]))

	# Armaments. Read defensively and per-hand rather than assigning the array
	# wholesale: JSON hands back plain Strings in untyped Dictionaries, and a
	# save written before the loadout existed has no "loadout" key at all, so
	# the default sword/shield + bow/arrows has to survive being loaded over.
	var sets: Array = d.get("loadout", [])
	for i in mini(sets.size(), Game.loadout.size()):
		var src: Dictionary = sets[i]
		for hand: StringName in [Game.HAND_RIGHT, Game.HAND_LEFT]:
			if src.has(hand) or src.has(String(hand)):
				var raw = src.get(hand, src.get(String(hand), &""))
				Game.loadout[i][hand] = StringName(raw)
	Game.loadout_set = clampi(int(d.get("loadout_set", Game.PRIMARY)),
		0, Game.loadout.size() - 1)

	# v10 introduced the Run payload. A valid snapshot now restores at home too,
	# because that is where undeposited supply cargo waits in the same bag. Whether
	# the destination is a dungeon remains a separate, explicit result below.
	var raw_run: Variant = d.get("run", {})
	var run_data: Dictionary = raw_run as Dictionary if raw_run is Dictionary else {}
	var save_version := int(d.get("version", 0))
	var restored_run := false
	if save_version >= 10 and not run_data.is_empty():
		restored_run = Run.restore(run_data)
	else:
		Run.reset()
	var restored_dungeon := restored_run and Run.in_dungeon
	# The legacy bit lived outside the bag. Migrate only at home, after restoring
	# the bag it must join; the dedicated Run seam also preserves it if that old
	# bag was already full rather than deleting another carried item on load.
	if not restored_dungeon and legacy_carrying_firewood:
		Run.ensure_legacy_cargo(SupplyCargoDb.FIREWOOD_ID, 1)
	# v12 slots written before Boss Keys carried a floor tag have only the bool.
	# Bind that legacy held key to the restored floor; outside a live run it is
	# invalid inventory and `Run.reset()` has already cleared it.
	if restored_dungeon and Game.has_boss_key and Game.boss_key_level <= 0:
		Game.boss_key_level = Run.level
	# Quest migration needs every fact it can conservatively prove: flags,
	# garrison/raid state, durable tools, and the restored Run bag. Keep it after
	# all four, so carried Firewood can never be confused with saved Fish or with
	# the pre-restore bag from the slot that was just left.
	Game.restore_quests(d.get("quests", {}))

	active_slot = slot
	current_room = StringName(d.get("room", ""))
	current_scene_path = d.get("scene", "")

	# Push the restored state at everyone who draws it.
	Bus.player_health_changed.emit(Game.health_points, Game.max_health_points)
	Bus.temporary_overhealth_changed.emit(Game.temporary_overhealth)
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	Bus.key_count_changed.emit(Game.small_keys)
	Bus.gold_changed.emit(Game.gold)
	Bus.item_selected_changed.emit(Game.item_selected)
	Bus.wheel_changed.emit(Game.wheel)
	Bus.bottles_changed.emit(Game.bottle_contents)
	Bus.rations_changed.emit(Game.rations)
	Bus.components_changed.emit(Game.components)
	Bus.stash_changed.emit(Game.stash)
	Bus.loadout_changed.emit(Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT))
	Game.garrison_changed.emit()
	loaded.emit(slot)

	var destination := {
		"scene": current_scene_path,
		"room": current_room,
		"run_restored": restored_dungeon,
		"in_dungeon": restored_dungeon,
		"level": Run.level if restored_dungeon else 1,
		"depth": Run.depth if restored_dungeon else 0,
	}
	# v4-v8 have a transform but no proof of which scene owns it. They remain
	# readable, but loading them once conservatively keeps the destination scene's
	# authored spawn and rotation. A v9+ transform is valid only inside its owner.
	if save_version >= 9 \
			and String(d.get("position_scene", "")) == current_scene_path:
		var p: Array = d.get("pos", [])
		if p.size() >= 3:
			destination["pos"] = Vector3(p[0], p[1], p[2])
		if d.has("yaw"):
			destination["yaw"] = float(d["yaw"])
	return destination


func erase(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if active_slot == slot:
		active_slot = -1


func _read(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and READABLE.has(int((parsed as Dictionary).get("version", 0))):
		return parsed
	return {}


func _scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path if cs else ""
