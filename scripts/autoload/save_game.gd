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
## `{"plate": 3}` — three quarter-hearts of soak — and since `plate` became four
## pieces × two paths (docs/GDD.md §6.6) there is no honest place to put it.
## Spending it on one piece (`plate_chest_heavy` at rung 3) is 1.0 quarters, a
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
const VERSION := 5
## Versions this build will still read. **Not every bump has to refuse the one
## before it** — a bump that only ADDS a key can list the older version here and
## let `d.get(key, default)` do the migration. v3 is absent only because the gear
## split changed the meaning of a key that was already in the file, which is the
## same reason v1 and v2 were refused.
const READABLE: Array[int] = [4, 5]

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


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


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
	return {
		"empty": false,
		"slot": slot,
		"hearts": float(d.get("quarters", 0)) / float(K.HEART),
		"max_hearts": float(d.get("max_quarters", 0)) / float(K.HEART),
		"gold": d.get("gold", 0),
		"keys": d.get("small_keys", 0),
		"room": d.get("room", ""),
		"items": (d.get("items", {}) as Dictionary).keys(),
		"played": d.get("played", 0.0),
		"stamp": d.get("stamp", ""),
	}


func save(slot: int) -> bool:
	var hero := get_tree().get_first_node_in_group(&"player")
	var pos := Vector3.ZERO
	var yaw := 0.0
	if hero and hero is Node3D:
		pos = (hero as Node3D).global_position
		yaw = (hero as Node3D).global_rotation.y

	var d := {
		"version": VERSION,
		"stamp": Time.get_datetime_string_from_system(false, true),
		"played": Time.get_ticks_msec() / 1000.0,
		"quarters": Game.quarters,
		"max_quarters": Game.max_quarters,
		# A Focus amulet raises this permanently, so it is a purchase and it saves.
		"max_stamina": Game.max_stamina,
		"magic": Game.magic,
		"max_magic": Game.max_magic,
		"gold": Game.gold,
		"deaths": Game.deaths,
		"bag_slots": Game.bag_slots,
		# Every permanent purchase, forge rungs included -- the ladders live in
		# `upgrades` (see Game.FORGE_TRACKS), so one key carries all twelve, and
		# the jewelcrafter's eight after it.
		"upgrades": Game.upgrades,
		"components": Game.components,
		# The footlocker. Merchandise the player carried home and chose not to
		# sell -- it already survived a run, so it has to survive a quit.
		"stash": Game.stash,
		# The array's size is how many bottles there are, so one key carries both
		# the glass and the contents. The DRAUGHT CLOCKS are deliberately not
		# saved -- see Game.draughts.
		"bottles": Game.bottle_contents,
		"arrows": Game.arrows,
		"bombs": Game.bombs,
		"small_keys": Game.small_keys,
		"has_boss_key": Game.has_boss_key,
		"has_map": Game.has_map,
		"has_compass": Game.has_compass,
		"items": Game.items,
		"item_selected": Game.item_selected,
		"loadout": Game.loadout,
		"loadout_set": Game.loadout_set,
		"flags": Game.flags,
		"room": String(current_room),
		"scene": _save_scene(),
		"pos": [pos.x, pos.y, pos.z],
		"yaw": yaw,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Saves: cannot write slot %d" % slot)
		return false
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	active_slot = slot
	saved.emit(slot)
	return true


## Where a load should put you back — and it is NEVER a dungeon.
##
## A slot captures `Game` and nothing of `Run`: no bag, no floor, no run seed,
## no `in_dungeon`. That is deliberate and it is METAGAME §5. The run's contents
## are the thing you are gambling; a save you could reload from the third floor
## would let a player undo the extraction decision the whole game is built on,
## and the fee would stop being a decision. So the run is not savable, and the
## honest thing for the recorded scene to say is where the surviving state
## actually belongs.
##
## Without this a save written underground reloaded into the dungeon scene with
## `Run.in_dungeon` false: a generated floor with no run behind it, no bag, no
## fee and no way out that would answer. It looked like a corrupted save and it
## was really a save that had told the truth about the wrong half of the game.
func _save_scene() -> String:
	if Run != null and Run.in_dungeon:
		return Flow.GARRISON
	if current_scene_path != "":
		return current_scene_path
	return _scene_path()


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


## Restore `Game` from a slot and return where the hero should be placed.
## Returns an empty dictionary if the slot is missing or unreadable — changing
## scenes is the caller's job, since only it knows how it wants to transition.
func load_slot(slot: int) -> Dictionary:
	var d := _read(slot)
	if d.is_empty():
		return {}

	Game.max_quarters = d.get("max_quarters", K.START_HEARTS * K.HEART)
	Game.quarters = d.get("quarters", Game.max_quarters)
	# Clamped rather than trusted: `K.STAMINA_MAX` is the ceiling every Focus
	# purchase already respects, and a hand-edited slot must not out-buy the shop.
	Game.max_stamina = minf(K.STAMINA_MAX,
		float(d.get("max_stamina", K.MAX_STAMINA)))
	Game.stamina = Game.max_stamina
	Game.max_magic = d.get("max_magic", 0)
	Game.magic = d.get("magic", 0)
	Game.gold = d.get("gold", 0)
	Game.deaths = int(d.get("deaths", 0))
	Game.bag_slots = int(d.get("bag_slots", K.START_BAG_SLOTS))
	# JSON has no StringName and no typed Dictionary, so both of these come back
	# as plain String keys in an untyped Dictionary. Rebuild rather than assign:
	# `Game.upgrades` is Dictionary[StringName, int] and a String key in it makes
	# `forge_level(&"edge")` miss every time — a hero who paid for the ladder and
	# reloads holding the bare blade.
	Game.upgrades.clear()
	for k in (d.get("upgrades", {}) as Dictionary):
		Game.upgrades[StringName(k)] = int((d["upgrades"] as Dictionary)[k])
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
		Game.bottle_contents.append(potion if PotionDb.has(potion) else &"")
	Game.arrows = d.get("arrows", 0)
	Game.bombs = d.get("bombs", 0)
	Game.small_keys = d.get("small_keys", 0)
	Game.has_boss_key = d.get("has_boss_key", false)
	Game.has_map = d.get("has_map", false)
	Game.has_compass = d.get("has_compass", false)

	Game.items.clear()
	for k in (d.get("items", {}) as Dictionary):
		Game.items[StringName(k)] = true
	Game.flags.clear()
	for k in (d.get("flags", {}) as Dictionary):
		Game.flags[StringName(k)] = true
	# `quick_slots` / `c_items` were the two names the D-pad BINDINGS were saved
	# under. There are no bindings any more (Game.item_selected), so an old save
	# simply drops them -- the ring is derived from what you own, and what you own
	# is in "items" and "bottles", which still load. The selection itself is
	# clamped on read rather than trusted: a save with four bottles restored into
	# a game with one is a `bottle_contents[3]` on the first press of X.
	Game.item_selected = int(d.get("item_selected", 0))

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

	active_slot = slot
	current_room = StringName(d.get("room", ""))
	current_scene_path = d.get("scene", "")

	# Push the restored state at everyone who draws it.
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	Bus.key_count_changed.emit(Game.small_keys)
	Bus.gold_changed.emit(Game.gold)
	Bus.item_selected_changed.emit(Game.item_selected)
	Bus.bottles_changed.emit(Game.bottle_contents)
	Bus.components_changed.emit(Game.components)
	Bus.stash_changed.emit(Game.stash)
	Bus.loadout_changed.emit(Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT))
	loaded.emit(slot)

	var p: Array = d.get("pos", [0, 0, 0])
	return {
		"scene": current_scene_path,
		"room": current_room,
		"pos": Vector3(p[0], p[1], p[2]),
		"yaw": d.get("yaw", 0.0),
	}


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
