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
const VERSION := 2

signal saved(slot: int)
signal loaded(slot: int)

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
		"magic": Game.magic,
		"max_magic": Game.max_magic,
		"gold": Game.gold,
		"bag_slots": Game.bag_slots,
		# Every permanent purchase, forge rungs included -- the ladders live in
		# `upgrades` (see Game.FORGE_*), so one key carries all five.
		"upgrades": Game.upgrades,
		"components": Game.components,
		"arrows": Game.arrows,
		"bombs": Game.bombs,
		"small_keys": Game.small_keys,
		"has_boss_key": Game.has_boss_key,
		"has_map": Game.has_map,
		"has_compass": Game.has_compass,
		"items": Game.items,
		"quick_slots": Game.quick_slots,
		"loadout": Game.loadout,
		"loadout_set": Game.loadout_set,
		"flags": Game.flags,
		"room": String(current_room),
		"scene": current_scene_path if current_scene_path != "" else _scene_path(),
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


## Restore `Game` from a slot and return where the hero should be placed.
## Returns an empty dictionary if the slot is missing or unreadable — changing
## scenes is the caller's job, since only it knows how it wants to transition.
func load_slot(slot: int) -> Dictionary:
	var d := _read(slot)
	if d.is_empty():
		return {}

	Game.max_quarters = d.get("max_quarters", K.START_HEARTS * K.HEART)
	Game.quarters = d.get("quarters", Game.max_quarters)
	Game.max_magic = d.get("max_magic", 0)
	Game.magic = d.get("magic", 0)
	Game.gold = d.get("gold", 0)
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
	# "c_items" is the pre-C-button name; a save written under it still loads.
	var slots: Array = d.get("quick_slots", d.get("c_items", []))
	for i in mini(slots.size(), Game.quick_slots.size()):
		Game.quick_slots[i] = StringName(slots[i])

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
	Bus.quick_slots_changed.emit(Game.quick_slots)
	Bus.components_changed.emit(Game.components)
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
	if parsed is Dictionary and (parsed as Dictionary).get("version", 0) == VERSION:
		return parsed
	return {}


func _scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path if cs else ""
