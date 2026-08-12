extends RefCounted
## Resumable dungeon autosaves and the five-minute cadence.
##
## This director proves the v10 contract through the real transition/save/load
## paths, then restores every byte that was present in the user's three slots.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/autosave.gd \
##     --out=/tmp/save/x.png --warmup=60

var _i := 0
var _backup: Dictionary = {}
var _active_before := -1


func run(rig) -> void:
	if not _stash(rig):
		return
	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1
	await rig.wait_seconds(0.2)

	# --- A. Transition saves point at the live dungeon ----------------------
	Flow.enter_dungeon(4242)
	await _settle(rig)
	_check(rig, "A1 entering started seed 4242", Run.in_dungeon and Run.seed_used == 4242)
	_check(rig, "A2 entering claimed slot 0", Saves.active_slot == 0 and Saves.has_save(0))
	_check(rig, "A3 the underground transition records the dungeon",
		_scene_of(0) == Flow.DUNGEON)
	var head := Saves.peek(0)
	var entered_data := _data(0)
	var entered_run: Dictionary = entered_data.get("run", {}) as Dictionary
	_check(rig, "A4 the v10 header exposes wall-clock and progress metadata",
		(head.get("last_played_unix", null) is int
			or head.get("last_played_unix", null) is float)
		and bool(head.get("in_dungeon", false))
		and String(head.get("scene", "")) == Flow.DUNGEON)
	_check(rig, "A5 the nested run payload carries its own version",
		int(entered_run.get("version", 0)) == Run.SNAPSHOT_VERSION)
	await _shot(rig, "entered")

	# Floor 2 makes a restored level distinguishable from the default. The bag
	# crosses this transition through the normal Run contract.
	Flow.descend()
	await _settle(rig)
	var dungeon := rig.scene().get_node_or_null("Dungeon") as Dungeon
	if dungeon == null:
		rig.fail("B0 the descended scene has no generated Dungeon")
		_restore(rig)
		return
	var hero := rig.get_first_node_in_group(&"player") as Node3D
	if hero == null:
		rig.fail("B0 the descended scene has no hero")
		_restore(rig)
		return

	# Enter one real generated room. Its stable Room_x_y id and the saved hero
	# transform exercise the trigger's restored-visited path after regeneration.
	var target := _first_room_beyond_entrance(dungeon)
	if target == null:
		rig.fail("B0 floor 2 has no generated room beyond its entrance")
		_restore(rig)
		return
	hero.global_position = target.global_position + Vector3(0.0, 0.05, 0.0)
	await rig.wait_physics_frames(8)
	var room_id := StringName(target.name)
	_check(rig, "B1 entering a generated room records its stable id",
		Run.has_visited_room(room_id) and Saves.current_room == room_id)
	_check(rig, "B2 that first entry advances depth once", Run.depth == 1)

	Run.collect(&"bone_shard", 6)
	# Collection fills the document case first by design; move four into the hold
	# so the fixture proves both regions survive rather than assuming an empty case.
	Run.unstow(&"bone_shard", 4)
	Run.premium = 17
	Run.kills = 3
	Game.magic = maxi(Game.max_magic - 1, 0)
	Game.stamina = 13.5
	_check(rig, "B3 the test bag and case were established",
		Run.bag.get(&"bone_shard", 0) == 6 and Run.cased.get(&"bone_shard", 0) == 2)
	_check(rig, "B4 the populated dungeon save writes", Saves.save(0))

	var wanted_seed := Run.seed_used
	var wanted_level := Run.level
	var wanted_depth := Run.depth
	var wanted_pos := hero.global_position
	var wanted_magic := Game.magic
	var wanted_stamina := Game.stamina
	var wanted_played := _played_of(0)
	var saved_head := Saves.peek(0)
	_check(rig, "B5 peek reports floor, depth and room",
		int(saved_head.get("level", 0)) == wanted_level
		and int(saved_head.get("depth", -1)) == wanted_depth
		and StringName(saved_head.get("room", "")) == room_id)
	await _shot(rig, "saved_run")

	# --- C. Restore data, rebuild the same floor, place the hero -------------
	Run.reset()
	var dest := Saves.load_slot(0)
	_check(rig, "C1 load explicitly identifies a restored dungeon run",
		bool(dest.get("run_restored", false)) and bool(dest.get("in_dungeon", false)))
	_check(rig, "C2 seed, floor and depth survive the read",
		Run.seed_used == wanted_seed and Run.level == wanted_level and Run.depth == wanted_depth)
	_check(rig, "C3 bag, case, premium and kills survive the read",
		Run.bag.get(&"bone_shard", 0) == 6
		and Run.cased.get(&"bone_shard", 0) == 2
		and Run.premium == 17 and Run.kills == 3)
	_check(rig, "C3b magic and stamina do not refill on a dungeon load",
		Game.magic == wanted_magic and is_equal_approx(Game.stamina, wanted_stamina))
	_check(rig, "C4 visited room ids survive the read", Run.has_visited_room(room_id))

	var resumed := await Flow.resume(dest)
	await rig.wait_physics_frames(6)
	var rebuilt := rig.scene().get_node_or_null("Dungeon") as Dungeon
	var restored_hero := rig.get_first_node_in_group(&"player") as Node3D
	_check(rig, "C5 Flow resume rebuilt a dungeon", resumed and rebuilt != null)
	_check(rig, "C6 the rebuilt run kept the saved seed and floor",
		Run.in_dungeon and Run.seed_used == wanted_seed and Run.level == wanted_level)
	_check(rig, "C7 the hero was placed at the saved transform",
		restored_hero != null and restored_hero.global_position.distance_to(wanted_pos) < 0.05)
	_check(rig, "C8 loading onto the visited room did not count it twice",
		Run.depth == wanted_depth)
	_check(rig, "C9 the load-time autosave kept the saved room metadata",
		StringName(Saves.peek(0).get("room", "")) == room_id)
	await _shot(rig, "resumed_run")

	# --- D. Five active minutes use the existing autosave policy ------------
	await rig.wait_seconds(0.05)
	var cadence_wrote := Saves._debug_advance_autosave(Saves.AUTOSAVE_INTERVAL)
	_check(rig, "D1 a synthetic five active minutes writes the active slot",
		cadence_wrote and Saves.active_slot == 0 and _played_of(0) > wanted_played)
	_check(rig, "D2 cadence preserves the dungeon destination", _scene_of(0) == Flow.DUNGEON)

	# --- E. No active slot plus three occupied slots still declines ----------
	for i in Saves.SLOTS:
		Saves.save(i)
	Saves.active_slot = -1
	var declined := not Saves.autosave()
	_check(rig, "E1 all three occupied with no active slot declines", declined)
	await _shot(rig, "declined")

	_restore(rig)
	print("AUTOSAVE COMPLETE")


func _first_room_beyond_entrance(dungeon: Dungeon) -> Node3D:
	for cell: Vector2i in dungeon.rooms:
		if cell == dungeon.entrance:
			continue
		var data: Dictionary = dungeon.rooms[cell]
		var room := data.get("node") as Node3D
		if room != null:
			return room
	return null


## Wait for the scene node to change, then for the autosave at `_go`'s tail.
func _settle(rig) -> void:
	var was: Node = rig.scene()
	for i in 300:
		await rig.wait_seconds(0.05)
		if rig.scene() != was and not Flow.busy:
			break
	await rig.wait_seconds(0.8)


func _scene_of(slot: int) -> String:
	var d := _data(slot)
	return String(d.get("scene", ""))


func _played_of(slot: int) -> float:
	return float(Saves.peek(slot).get("played", -1.0))


func _data(slot: int) -> Dictionary:
	var raw := _raw(slot)
	if raw == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed as Dictionary if parsed is Dictionary else {}


func _raw(slot: int) -> String:
	var f := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _stash(rig) -> bool:
	_active_before = Saves.active_slot
	for i in Saves.SLOTS:
		var exists := FileAccess.file_exists(Saves.slot_path(i))
		var bytes := PackedByteArray()
		if exists:
			var file := FileAccess.open(Saves.slot_path(i), FileAccess.READ)
			if file == null:
				rig.fail("could not back up the user's save slot %d" % i)
				return false
			bytes = file.get_buffer(file.get_length())
			file.close()
		_backup[i] = {"exists": exists, "bytes": bytes}
	return true


func _restore(rig) -> void:
	for i in Saves.SLOTS:
		var saved: Dictionary = _backup.get(i, {})
		if not bool(saved.get("exists", false)):
			Saves.erase(i)
			_check(rig, "real slot %d restored as absent" % (i + 1),
				not FileAccess.file_exists(Saves.slot_path(i)))
			continue
		var f := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
		if f == null:
			rig.fail("could not restore the user's save slot %d" % i)
			continue
		var bytes: PackedByteArray = saved.get("bytes", PackedByteArray())
		f.store_buffer(bytes)
		f.close()
		_check(rig, "real slot %d bytes restored exactly" % (i + 1),
			_read_bytes(i) == bytes)
	Saves.active_slot = _active_before


func _read_bytes(slot: int) -> PackedByteArray:
	var file := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _check(rig, what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		rig.fail(what)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
