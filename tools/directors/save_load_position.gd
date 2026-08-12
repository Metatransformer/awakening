extends RefCounted
## A legacy dungeon save comes home without bringing dungeon coordinates with it.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/save_load_position.gd \
##     --out=/tmp/save_load_position/frame.png --warmup=1 --meet
##
## The v8 failure paired two individually honest facts that did not belong
## together: `scene` was the garrison because those saves carried no `Run`, while
## `pos` / `yaw` came from the live dungeon hero. Loading that pair could put
## Kael outside the authored hub. This director gives the floor transform a
## conspicuous fingerprint, saves, loads, resumes through Flow, and proves the
## garrison kept the transform authored in its scene.
##
## The load also leaves Kessa's introduction owed. Its camera and dialogue are
## allowed to take the frame, but neither may move Kael off the authored spawn.
## One frame records that composition rather than treating a log as visual proof.
##
## This writes the real `user://saves`. All three slots are backed up as exact
## bytes before the first erase and restored on every ordinary failure return.

const SLOT := 0
const FAR_POSITION := Vector3(321.25, 17.5, -456.75)
const FAR_YAW := 1.2345
const POSITION_EPSILON := 0.20
const YAW_EPSILON := 0.01

var _fails := 0
var _backup: Dictionary = {}
var _old_active_slot := -1


func run(rig) -> void:
	if not _stash_slots():
		_verdict()
		return

	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1

	# The opening itself is over, but Kessa has not been introduced. The other
	# three introductions stay met so the first dialogue after loading has only
	# one honest answer.
	Game.set_flag(Garrison.INTRO_FLAG)
	for who: StringName in [&"smith", &"alchemist", &"jewelcrafter"]:
		Game.set_flag(StoryDb.intro_flag(who))
	Game.flags.erase(StoryDb.intro_flag(&"quartermaster"))

	var original_hero := _hero(rig)
	_ck("A0 the starting garrison has a hero", original_hero != null)
	if original_hero == null:
		await _finish(rig)
		return
	var authored_position := original_hero.global_position
	var authored_yaw := original_hero.global_rotation.y
	_ck("A1 Kessa's introduction is pending before the run",
		StoryDb.pending_introduction() == &"quartermaster")

	Flow.enter_dungeon(100100)
	var entered: bool = await rig.until(func() -> bool:
		return _scene_path(rig) == Flow.DUNGEON and not Flow.busy, 8.0)
	_ck("B0 the run reached the dungeon", entered and Run.in_dungeon)
	if not entered:
		await _finish(rig)
		return
	# `Flow.busy` ends before the loading card's fade-out tween. Starting another
	# transition inside that visual tail leaves the old card present when the
	# garrison transition chooses which overlay to fade. A player cannot open the
	# save menu under the loading card, so settle the same boundary here.
	var dungeon_visible: bool = await rig.until(_flow_overlay_clear, 2.0)
	_ck("B0b the dungeon loading card has cleared", dungeon_visible)
	if not dungeon_visible:
		await _finish(rig)
		return

	var dungeon_hero := _hero(rig)
	_ck("B1 the live dungeon has a hero", dungeon_hero != null)
	if dungeon_hero == null:
		await _finish(rig)
		return
	dungeon_hero.global_position = FAR_POSITION
	dungeon_hero.global_rotation.y = FAR_YAW
	_ck("B2 the live hero carries the distinctive dungeon position",
		dungeon_hero.global_position.is_equal_approx(FAR_POSITION))
	_ck("B3 the live hero carries the distinctive dungeon yaw",
		absf(wrapf(dungeon_hero.global_rotation.y - FAR_YAW, -PI, PI)) < YAW_EPSILON)

	var wrote := Saves.save(SLOT)
	_ck("C0 the dungeon slot writes", wrote)
	if not wrote:
		await _finish(rig)
		return
	var written := _slot_json(SLOT)
	_ck("C1 it is the current save format", int(written.get("version", 0)) == Saves.VERSION)
	_ck("C2 a current run's destination is the dungeon",
		String(written.get("scene", "")) == Flow.DUNGEON)
	_ck("C3 its transform owner is the dungeon",
		String(written.get("position_scene", "")) == Flow.DUNGEON)
	_ck("C4 the owned dungeon position is persisted", written.has("pos"))
	_ck("C5 the owned dungeon yaw is persisted", written.has("yaw"))

	# Recreate the exact shape an existing v8 slot can carry: a garrison
	# destination paired with an unowned dungeon transform. The migration must
	# read the permanent Game state without trusting those legacy coordinates.
	var legacy := written.duplicate(true)
	legacy["version"] = 8
	legacy["scene"] = Flow.GARRISON
	legacy.erase("position_scene")
	legacy.erase("run")
	legacy["pos"] = [FAR_POSITION.x, FAR_POSITION.y, FAR_POSITION.z]
	legacy["yaw"] = FAR_YAW
	_ck("C6 the legacy v8 regression slot writes", _write_slot_json(SLOT, legacy))

	var dest: Dictionary = Saves.load_slot(SLOT)
	_ck("D0 the legacy v8 slot remains readable", not dest.is_empty())
	_ck("D1 the returned destination is the garrison",
		String(dest.get("scene", "")) == Flow.GARRISON)
	_ck("D2 the returned destination does not manufacture a position",
		not dest.has("pos"))
	_ck("D3 the returned destination does not manufacture a yaw",
		not dest.has("yaw"))
	_ck("D4 Kessa is still unmet while the load is in flight",
		StoryDb.pending_introduction() == &"quartermaster"
		and not Game.flag(StoryDb.intro_flag(&"quartermaster")))

	var resumed: bool = await Flow.resume(dest)
	_ck("E0 Flow accepted the restored destination", resumed)
	if not resumed:
		await _finish(rig)
		return
	var garrison_visible: bool = await rig.until(_flow_overlay_clear, 2.0)
	_ck("E0b the garrison fade has cleared", garrison_visible)
	if not garrison_visible:
		await _finish(rig)
		return
	_ck("E1 the load ended in the garrison", _scene_path(rig) == Flow.GARRISON
		and rig.scene() is Garrison)
	_ck("E2 the dungeon run was abandoned", not Run.in_dungeon)

	var loaded_hero := _hero(rig)
	_ck("E3 the loaded garrison has a hero", loaded_hero != null)
	if loaded_hero == null:
		await _finish(rig)
		return
	_check_authored_transform("E4", loaded_hero, authored_position, authored_yaw)
	_ck("E5 he is nowhere near the dungeon coordinate (%.1f m away)"
		% loaded_hero.global_position.distance_to(FAR_POSITION),
		loaded_hero.global_position.distance_to(FAR_POSITION) > 100.0)

	var appeared: bool = await rig.until(func() -> bool:
		return rig.dialogue() != null, 5.0)
	_ck("F0 the pending quartermaster introduction appears", appeared)
	var box := rig.dialogue() as DialogueBox
	_ck("F1 Aldric opens the introduction", box != null and box.speaker == &"elder")
	var cam := _convo_camera(rig)
	_ck("F2 the introduction owns the rendered camera",
		cam != null and rig.scene().get_viewport().get_camera_3d() == cam)
	if cam != null:
		var settled: bool = await rig.until(func() -> bool:
			return is_instance_valid(cam) and cam.settled(), 3.0)
		_ck("F3 the introduction composition settles", settled)
	_check_authored_transform("F4", loaded_hero, authored_position, authored_yaw)

	var out: String = rig.arg("out", "/tmp/save_load_position/frame.png")
	await rig.capture(out.get_base_dir().path_join("save_load_position.png"))
	await _finish(rig)


func _check_authored_transform(tag: String, hero: Node3D,
		authored_position: Vector3, authored_yaw: float) -> void:
	var position_error := hero.global_position.distance_to(authored_position)
	var yaw_error := absf(wrapf(hero.global_rotation.y - authored_yaw, -PI, PI))
	_ck("%s the hero remains at the authored garrison spawn (%.3f m out)"
		% [tag, position_error], position_error < POSITION_EPSILON)
	_ck("%s the hero keeps the authored garrison yaw (%.3f rad out)"
		% [tag, yaw_error], yaw_error < YAW_EPSILON)


func _hero(rig) -> Node3D:
	return rig.get_first_node_in_group(&"player") as Node3D


func _scene_path(rig) -> String:
	var scene: Node = rig.scene()
	return scene.scene_file_path if scene != null else ""


func _convo_camera(rig) -> ConvoCamera:
	var scene: Node = rig.scene()
	if scene == null:
		return null
	return scene.find_child("ConvoCamera", true, false) as ConvoCamera


func _flow_overlay_clear() -> bool:
	var veil := Flow.get("_veil") as ColorRect
	return Flow.get("_card") == null and (veil == null or veil.color.a < 0.01)


func _slot_json(slot: int) -> Dictionary:
	var raw := FileAccess.get_file_as_string(Saves.slot_path(slot))
	var parsed: Variant = JSON.parse_string(raw)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_slot_json(slot: int, data: Dictionary) -> bool:
	var file := FileAccess.open(Saves.slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


## Preserve absence separately from contents: an existing zero-byte slot must
## come back as an existing zero-byte slot, not be mistaken for no slot.
func _stash_slots() -> bool:
	_old_active_slot = Saves.active_slot
	var ok := true
	for i in Saves.SLOTS:
		var path := Saves.slot_path(i)
		if not FileAccess.file_exists(path):
			_backup[i] = {"exists": false, "bytes": PackedByteArray()}
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_ck("S%d the existing slot can be backed up" % i, false)
			ok = false
			continue
		var bytes := f.get_buffer(f.get_length())
		f.close()
		_backup[i] = {"exists": true, "bytes": bytes}
	return ok


func _restore_slots() -> void:
	for i in Saves.SLOTS:
		var row: Dictionary = _backup.get(i, {})
		var path := Saves.slot_path(i)
		if not bool(row.get("exists", false)):
			if FileAccess.file_exists(path):
				var removed := DirAccess.remove_absolute(path)
				_ck("Z%d the originally absent slot is removed" % i, removed == OK)
			continue
		var bytes: PackedByteArray = row.get("bytes", PackedByteArray())
		if FileAccess.file_exists(path) and _read_bytes(path) == bytes:
			_ck("Z%d the original slot bytes are restored exactly" % i, true)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			_ck("Z%d the original slot can be restored" % i, false)
			continue
		f.store_buffer(bytes)
		f.close()
		_ck("Z%d the original slot bytes are restored exactly" % i,
			FileAccess.file_exists(path) and _read_bytes(path) == bytes)
	Saves.active_slot = _old_active_slot


func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return bytes


func _finish(rig) -> void:
	# A timed-out transition can still have an autosave queued after `busy` drops.
	# Let that write land before restoring the real files, or cleanup itself can
	# be overwritten on the next frame by the operation the failed check started.
	if Flow.busy:
		await rig.until(func() -> bool: return not Flow.busy, 3.0)
	await rig.wait_frames(2)
	_restore_slots()
	_verdict()


func _verdict() -> void:
	print("SAVE_LOAD_POSITION OK -- every check passed" if _fails == 0
		else "SAVE_LOAD_POSITION FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("SAVE_LOAD_POSITION FAIL %s" % label)
