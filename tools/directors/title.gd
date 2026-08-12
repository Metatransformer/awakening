extends RefCounted
## The front door: cold title, populated Continue picker, and the opening.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/title/title_screen.tscn \
##     --director=res://tools/directors/title.gd \
##     --out=/tmp/title/x.png --warmup=30
##
## The director temporarily owns `user://saves`: it preserves every slot's raw
## bytes, proves the no-save title, seeds three deterministic readable saves,
## proves their picker order/content/focus, then restores those bytes before it
## starts the existing NEW GAME/opening checks.

var out := ""
var _backup: Dictionary = {}
var _active_slot_backup := -1


func run(rig) -> void:
	out = rig.arg("out", "/tmp/title/x.png").get_base_dir()
	if not _stash(rig):
		return
	_clear_slots()

	var screen: Node = rig.scene()
	_refresh_title(screen)
	await rig.wait_frames(2)
	await _menu(rig)

	_seed_slots(rig)
	_refresh_title(screen)
	await rig.wait_frames(2)
	await _populated_picker(rig)

	# Restore before the long opening beat. Every normal exit from the populated
	# helper reaches here, including a failed check or a missing picker node.
	if not _restore(rig):
		return
	_refresh_title(screen)
	await rig.wait_frames(2)

	await _opening(rig)
	print("TITLE checks complete")


func _ck(rig, label: String, ok: bool) -> bool:
	if ok:
		print("  ok   %s" % label)
	else:
		rig.fail("TITLE %s" % label)
	return ok


# --- A + B. The cold menu ---------------------------------------------------

func _menu(rig) -> void:
	var screen: Node = rig.scene()
	_ck(rig, "A the title screen is the scene", screen is TitleScreen)

	var plate := screen.get_node_or_null(^"Plate") as TextureRect
	_ck(rig, "A the painting loaded", plate != null and plate.texture != null)

	var menu: Node = screen.get_node_or_null(^"Menu")
	_ck(rig, "A three buttons", menu != null and menu.get_child_count() == 3)
	if menu == null:
		return

	var labels: Array[String] = []
	for b: Node in menu.get_children():
		labels.append((b as Button).text)
	_ck(rig, "A the three are CONTINUE / NEW GAME / QUIT",
		labels == ["CONTINUE", "NEW GAME", "QUIT"])

	var any_save := false
	for i in Saves.SLOTS:
		any_save = any_save or Saves.has_save(i)
	var cont := menu.get_child(0) as Button
	_ck(rig, "B CONTINUE matches the empty disk (saves=%s)" % any_save,
		cont.disabled == not any_save)
	_ck(rig, "B empty CONTINUE is unfocusable",
		not any_save and cont.focus_mode == Control.FOCUS_NONE)
	_ck(rig, "B cold focus is on NEW GAME",
		(menu.get_child(1) as Button).has_focus())

	_ck(rig, "E the score is the overture", Music.mood_name() == "TITLE")
	await rig.capture("%s/01_title.png" % out)


# --- Populated Continue picker ---------------------------------------------

func _populated_picker(rig) -> void:
	var screen: Node = rig.scene()
	var menu := screen.get_node_or_null(^"Menu") as VBoxContainer
	if not _ck(rig, "P the populated title still has its first menu", menu != null):
		return
	var cont := menu.get_child(0) as Button
	_ck(rig, "P CONTINUE is enabled and focused with readable saves",
		not cont.disabled and cont.focus_mode == Control.FOCUS_ALL and cont.has_focus())

	cont.pressed.emit()
	await rig.wait_frames(2)
	var picker := screen.get_node_or_null(^"Picker") as VBoxContainer
	if not _ck(rig, "P CONTINUE opens the picker",
		picker != null and picker.visible and not menu.visible):
		return
	var rows := picker.get_node_or_null(^"Rows") as VBoxContainer
	if not _ck(rig, "P all three readable saves are listed",
		rows != null and rows.get_child_count() == 3):
		return

	var order: Array[int] = []
	for child: Node in rows.get_children():
		order.append(int(child.get("slot")))
	_ck(rig, "P rows sort newest-first, independent of slot/stamp order (%s)" % [order],
		order == [2, 1, 0])

	var newest := rows.get_child(0) as Button
	var tied_newer_stamp := rows.get_child(1) as Button
	var home := rows.get_child(2) as Button
	_ck(rig, "P focus enters on the newest row", newest.has_focus())
	_ck(rig, "P newest row has slot, last played, dungeon progress and grouped gold",
		_row_has(newest, [
			"SLOT 3",
			"LAST PLAYED  2026-08-10 12:45",
			"PROGRESS  FLOOR 3 · DEPTH 5",
			"GOLD  1,250",
		]))
	_ck(rig, "P tied numeric times fall back to descending ISO stamp",
		_row_has(tied_newer_stamp, [
			"SLOT 2",
			"LAST PLAYED  2026-08-11 18:30",
			"PROGRESS  FLOOR 2 · DEPTH 4",
			"GOLD  900",
		]))
	_ck(rig, "P garrison row says GARRISON and exposes every required field",
		_row_has(home, [
			"SLOT 1",
			"LAST PLAYED  2026-08-09 08:15",
			"PROGRESS  GARRISON",
			"GOLD  75",
		]))

	var back := picker.get_node_or_null(^"Back") as Button
	if not _ck(rig, "P the picker has BACK", back != null):
		return
	back.pressed.emit()
	await rig.wait_frames(2)
	_ck(rig, "P Back restores the first menu and CONTINUE focus",
		menu.visible and not picker.visible and cont.has_focus())

	# Re-open after proving Back so the proof frame is the state under review.
	cont.pressed.emit()
	await rig.wait_frames(2)
	rows = picker.get_node_or_null(^"Rows") as VBoxContainer
	var reopened_newest := rows.get_child(0) as Button if rows != null else null
	_ck(rig, "P reopening restores newest-row focus",
		reopened_newest != null and reopened_newest.has_focus())
	await rig.capture("%s/01_picker.png" % out)
	back.pressed.emit()
	await rig.wait_frames(2)


func _row_has(row: Button, wanted: Array[String]) -> bool:
	var found: Array[String] = []
	_collect_label_text(row, found)
	for text: String in wanted:
		if not found.has(text):
			return false
	return row.is_visible_in_tree()


func _collect_label_text(node: Node, found: Array[String]) -> void:
	if node is Label:
		found.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_label_text(child, found)


# --- C..F. The opening ------------------------------------------------------

func _opening(rig) -> void:
	# Straight at `Flow` rather than at the button: this beat tests the transition
	# and narration, while the title controls were exercised above.
	Game.set_flag(&"reported_for_duty")
	Flow.new_game()

	var up: bool = await rig.until(func() -> bool:
		return _cutscene(rig) != null, 6.0)
	_ck(rig, "C the cutscene came up", up)
	var cut := _cutscene(rig)
	if cut == null:
		return

	_ck(rig, "C a new game cleared the flags",
		not Game.flag(&"reported_for_duty"))

	await rig.until(func() -> bool:
		return _here(rig).contains("garrison"), 6.0)
	_ck(rig, "C the garrison is built behind it",
		_here(rig).contains("garrison"))
	var stopped: bool = await rig.until(func() -> bool: return rig.paused, 3.0)
	_ck(rig, "C and it is stopped while the opening plays", stopped)

	var line := cut.get_node_or_null(^"Line") as Label
	_ck(rig, "D there is a line on screen", line != null and not line.text.is_empty())
	if line == null:
		return

	var first := line.text
	_ck(rig, "D beat 1 is Kael on the road", first.contains("Kael"))
	_ck(rig, "D the narrator is saying it", Voice.line() == "opening")
	_ck(rig, "E and the score is the prologue", Music.mood_name() == "PROLOGUE")
	await rig.capture("%s/02_opening_1.png" % out)

	var turned: bool = await rig.until(func() -> bool:
		return line.text != first, 14.0)
	_ck(rig, "D beat 2 arrived on the same clip", turned)
	await rig.until(func() -> bool: return line.modulate.a > 0.98, 2.0)
	_ck(rig, "D beat 2 is the posting to Highbridge",
		line.text.contains("Highbridge"))
	_ck(rig, "D the same take is still under it", Voice.line() == "opening")
	await rig.capture("%s/03_opening_2.png" % out)

	cut.skip()
	var landed: bool = await rig.until(func() -> bool:
		return not rig.paused and rig.get_first_node_in_group(&"player") != null, 8.0)
	_ck(rig, "F it ends in the garrison, running, with a hero", landed)

	await rig.wait_seconds(1.2)
	_ck(rig, "F the picture is gone", _cutscene(rig) == null)
	_ck(rig, "E the town theme took over", Music.mood_name() == "CALM")
	_ck(rig, "E and it is the town track, not the overture",
		Music.current_track().contains("town"))
	await rig.capture("%s/04_garrison.png" % out)


## The live cutscene lives on Flow's CanvasLayer, not under the changing scene.
func _here(rig) -> String:
	var s: Node = rig.current_scene
	return s.scene_file_path if s != null else ""


func _cutscene(rig) -> Cutscene:
	for layer: Node in rig.root.get_node(^"Flow").get_children():
		if layer is CanvasLayer:
			for child: Node in (layer as CanvasLayer).get_children():
				if child is Cutscene:
					return child
	return null


# --- Save fixture -----------------------------------------------------------

func _seed_slots(rig) -> void:
	var rows: Array[Dictionary] = [
		{
			"slot": 0,
			"stamp": "2026-08-09T08:15:00",
			"last_played_unix": 200,
			"gold": 75,
			"in_dungeon": false,
			"level": 1,
			"depth": 0,
		},
		{
			"slot": 1,
			"stamp": "2026-08-11T18:30:00",
			"last_played_unix": 200,
			"gold": 900,
			"in_dungeon": true,
			"level": 2,
			"depth": 4,
		},
		{
			"slot": 2,
			"stamp": "2026-08-10T12:45:00",
			"last_played_unix": 300,
			"gold": 1250,
			"in_dungeon": true,
			"level": 3,
			"depth": 5,
		},
	]
	for row: Dictionary in rows:
		_seed_slot(rig, row)
	Saves.active_slot = -1


func _seed_slot(rig, head: Dictionary) -> void:
	var slot := int(head["slot"])
	if not _ck(rig, "P fixture slot %d starts from a readable save" % (slot + 1),
		Saves.save(slot)):
		return
	var raw := FileAccess.get_file_as_string(Saves.slot_path(slot))
	var parsed: Variant = JSON.parse_string(raw)
	if not _ck(rig, "P fixture slot %d parsed" % (slot + 1), parsed is Dictionary):
		return
	var data := parsed as Dictionary
	data["stamp"] = head["stamp"]
	data["last_played_unix"] = head["last_played_unix"]
	data["gold"] = head["gold"]
	if bool(head["in_dungeon"]):
		var run: Dictionary = data.get("run", {}) as Dictionary
		run["in_dungeon"] = true
		run["level"] = head["level"]
		run["depth"] = head["depth"]
		data["run"] = run
		data["scene"] = Flow.DUNGEON
		data["room"] = "Room_1_0"
	else:
		data["run"] = {}
		data["scene"] = Flow.GARRISON
		data["room"] = ""

	var file := FileAccess.open(Saves.slot_path(slot), FileAccess.WRITE)
	if not _ck(rig, "P fixture slot %d opened for seeding" % (slot + 1), file != null):
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	var peek: Dictionary = Saves.peek(slot)
	_ck(rig, "P fixture slot %d is readable after seeding" % (slot + 1),
		not bool(peek.get("empty", true)) and not bool(peek.get("corrupt", false)))


func _refresh_title(screen: Node) -> void:
	if screen != null and screen.has_method(&"_refresh_saves"):
		screen.call(&"_refresh_saves", true)


func _clear_slots() -> void:
	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1


func _stash(rig) -> bool:
	_active_slot_backup = Saves.active_slot
	for i in Saves.SLOTS:
		var exists := FileAccess.file_exists(Saves.slot_path(i))
		var bytes := PackedByteArray()
		if exists:
			var file := FileAccess.open(Saves.slot_path(i), FileAccess.READ)
			if not _ck(rig, "P real slot %d opened for backup" % (i + 1), file != null):
				return false
			bytes = file.get_buffer(file.get_length())
			file.close()
		_backup[i] = {"exists": exists, "bytes": bytes}
	return true


func _restore(rig) -> bool:
	var restored := true
	for i in Saves.SLOTS:
		var saved: Dictionary = _backup.get(i, {})
		if not bool(saved.get("exists", false)):
			Saves.erase(i)
			restored = _ck(rig, "P absent real slot %d restored as absent" % (i + 1),
				not FileAccess.file_exists(Saves.slot_path(i))) and restored
			continue
		var file := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
		if not _ck(rig, "P real slot %d opened for restore" % (i + 1), file != null):
			restored = false
			continue
		var bytes: PackedByteArray = saved.get("bytes", PackedByteArray())
		file.store_buffer(bytes)
		file.close()
		restored = _ck(rig, "P real slot %d bytes restored exactly" % (i + 1),
			_read_bytes(i) == bytes) and restored
	Saves.active_slot = _active_slot_backup
	return restored


func _read_bytes(slot: int) -> PackedByteArray:
	var file := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes
