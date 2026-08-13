extends RefCounted
## Issues #179/#180: the bedside Field Notes ledger and shared attention marks.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/field_notes_book.gd \
##     --out=/tmp/field_notes_book/x.png --size=1280x720 --warmup=60
##
## This is a real-scene proof. It addresses the real bedside Interactable,
## files through Game's single-entry API, and buys through SupplyDb rather than
## substituting director-owned affordability arithmetic.

var _out: String = "/tmp/field_notes_book"


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/field_notes_book/x.png").get_base_dir()
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "the proof scene is the real garrison"):
		return
	await rig.wait_frames(16)

	var book := _book_contract(rig, garrison)
	if book == null:
		return
	_prepare_three_states(book)
	await rig.wait_frames(4)
	await _book_world_frame(rig, garrison, book)
	await _book_screen(rig, garrison, book)
	await _npc_markers(rig, garrison)

	print("FIELD NOTES BOOK OK")


func _book_contract(rig, garrison: Garrison) -> FieldNotesBook:
	var bunk := garrison.house
	if not rig.check(bunk != null, "the garrison exposes the player bunk"):
		return null
	var book := bunk.field_notes_book
	if not rig.check(book != null, "the player bunk exposes its Field Notes book"):
		return null
	rig.check(book.get_parent() == bunk,
		"the book is owned only by the player bunk")
	rig.check(book.find_child("Dresser", true, false) != null,
		"a compact timber dresser exists under the ledger")
	rig.check(book.find_child("SocietyLedger", true, false) != null,
		"the dresser carries a visible Society ledger")
	rig.check(book.find_child("DresserCollision", true, false) is StaticBody3D,
		"the dresser has one forgiving world collision")
	rig.check(book.attention_marker is WorldAttentionMarker,
		"the book owns the shared WorldAttentionMarker class")
	var bed_gap := K.plane(book.global_position - bunk.bed.global_position).length()
	var locker_gap := K.plane(book.global_position - bunk.locker.global_position).length()
	rig.check(bed_gap > 0.8 and bed_gap < 1.8,
		"the dresser is bedside without occupying the bed (%.2f m)" % bed_gap)
	rig.check(locker_gap > 2.0,
		"the dresser stays separate from the footlocker (%.2f m)" % locker_gap)
	return book


func _prepare_three_states(book: FieldNotesBook) -> void:
	Game.completed_field_observations.clear()
	Game.awarded_field_observations.clear()
	Game.field_notes = 0
	var completed: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
	]
	Game.complete_field_observations(completed)
	Game.file_field_observation(FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID)
	book.refresh_attention_marker()


func _book_world_frame(rig, garrison: Garrison, book: FieldNotesBook) -> void:
	rig.check(book.attention_marker.visible,
		"one completed unfiled observation raises the bedside mark")
	var hero := _hero(garrison)
	if hero != null:
		hero.global_position = book.to_global(Vector3(0.0, 0.05, 1.15))
	await _capture_world(rig, book.global_position + Vector3.UP * 0.72,
		Vector3(4.2, 2.2, -2.2),
		_out.path_join("field_notes_book_world.png"))


func _book_screen(rig, garrison: Garrison, book: FieldNotesBook) -> void:
	var hero := _hero(garrison)
	if not rig.check(hero != null, "the real garrison hero exists"):
		return
	var read_at := book.to_global(Vector3(0.0, 0.05, 0.96))
	hero.global_position = read_at
	_face(hero, book.global_position)
	Bus.camera_recenter.emit()
	var focused: bool = await rig.until(func() -> bool: return Prompt.focus == book)
	if not rig.check(focused, "the aisle-side READ volume wins Prompt arbitration"):
		return
	await rig.tap(["interact"])
	var opened: bool = await rig.until(func() -> bool: return _screens(garrison).size() == 1)
	if not rig.check(opened, "READ opens exactly one FieldNotesBookScreen"):
		return
	var screens := _screens(garrison)
	rig.check(screens.size() == 1,
		"there is exactly one live book screen instance")
	var screen := screens[0]
	await rig.wait_frames(10)

	rig.check(screen.row_count() == FieldNotesDb.OBSERVATION_IDS.size()
		and screen.row_count() == 5,
		"the left page has exactly five authored rows")
	rig.check(screen.observation_state(FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID)
		== FieldNotesBookScreen.FILED_STATE,
		"the filed observation renders FILED")
	rig.check(screen.observation_state(FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
		== FieldNotesBookScreen.READY_STATE,
		"the completed unfiled observation renders READY")
	rig.check(screen.observation_state(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
		== FieldNotesBookScreen.AWAITING_STATE,
		"an unfinished observation renders AWAITING")
	rig.check(screen._body.text
		== FieldNotesDb.observation_note_body(FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID)
		and not screen._body.text.is_empty(),
		"a filed note body remains fully readable")

	# The focused Controls own arrows. One real GUI navigation event must move
	# both focus and selection exactly once, with no director field assignment.
	var first := screen._rows[0]
	if get_viewport_focus(screen) != first:
		first.grab_focus()
		await rig.wait_frames(2)
	await rig.tap(["ui_down"])
	await rig.wait_frames(3)
	rig.check(screen.selected_observation_id()
		== FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
		"one DOWN event selects the next row exactly once")
	rig.check(get_viewport_focus(screen) == screen._rows[1],
		"the READY row owns live keyboard/gamepad focus")
	rig.check(screen._body.text
		== FieldNotesDb.observation_note_body(FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID),
		"the focused READY row paints its authored note body")

	# shoot.gd removes physical pad bindings to silence a plugged-in controller.
	# Add only the A button in memory so Glyph can prove the live pad path without
	# restoring any drifting axes.
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"interact", pad_a)
	Settings.using_pad = true
	Bus.input_device_changed.emit(true)
	await rig.wait_frames(3)
	rig.check(screen._action.text.begins_with("A "),
		"the READY action uses the live interact Glyph (A on pad)")

	rig.still_the_frame()
	await rig.wait_frames(3)
	await rig.capture(_out.path_join("field_notes_book_spread.png"))

	var balance_before := Game.field_notes
	await rig.tap(["interact"])
	await rig.wait_frames(5)
	rig.check(Game.has_field_observation(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID),
		"interact files only the selected READY observation")
	rig.check(Game.field_notes == balance_before + 1,
		"filing increments the displayed authoritative balance once")
	rig.check(screen.observation_state(FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
		== FieldNotesBookScreen.FILED_STATE,
		"the open screen refreshes READY to FILED")
	rig.check(not book.attention_marker.visible,
		"filing the last READY entry clears the world marker")
	var once := Game.field_notes
	await rig.tap(["interact"])
	await rig.wait_frames(3)
	rig.check(Game.field_notes == once,
		"replayed filing input is idempotent")

	InputMap.action_erase_event(&"interact", pad_a)
	Settings.using_pad = false
	Bus.input_device_changed.emit(false)
	await rig.tap(["ui_cancel"])
	var closed: bool = await rig.until(func() -> bool: return _screens(garrison).is_empty())
	rig.check(closed and not Prompt.screen_up,
		"cancel closes the only screen and releases world prompts")


func _npc_markers(rig, garrison: Garrison) -> void:
	var npcs: Array[Npc] = []
	for node: Node in _all(garrison):
		if node is Npc and (node as Npc).role != Npc.Role.GATE:
			npcs.append(node as Npc)
	var shared := not npcs.is_empty()
	for npc: Npc in npcs:
		shared = shared and npc.attention_marker is WorldAttentionMarker \
			and npc.attention_marker.position.y > npc.head_y() + 0.8
	rig.check(shared,
		"every non-gate NPC owns the shared mark above the authored crown")

	var vendor := garrison.vendor
	if not rig.check(vendor != null, "the representative quartermaster is staffed"):
		return
	var day_transform := vendor.global_transform
	vendor.set_activity(Npc.ACTIVITY_WORKING, day_transform)
	Game.upgrades.erase(&"bag_slot")
	Game.upgrades.erase(&"heart")
	Game.gold = 0
	Bus.gold_changed.emit(Game.gold)
	await rig.wait_frames(3)
	rig.check(not vendor.has_affordable_progression()
		and not vendor.attention_marker.visible,
		"an unaffordable progression counter has no mark")

	var bag_line := _catalogue_line(SupplyDb, &"bag_slot")
	if not rig.check(not bag_line.is_empty(),
			"the representative bill is a real visible SupplyDb line"):
		return
	Game.gold = int(bag_line["cost"])
	Bus.gold_changed.emit(Game.gold)
	await rig.wait_frames(3)
	rig.check(SupplyDb.remaining(&"bag_slot") > 0 and SupplyDb.can_buy(bag_line),
		"the authoritative catalogue says the bill is affordable")
	rig.check(vendor.has_affordable_progression()
		and vendor.attention_marker.visible,
		"that catalogue answer raises the NPC mark")

	var hero := _hero(garrison)
	if hero != null:
		hero.global_position = vendor.global_position + Vector3(-2.8, 0.05, 0.0)
	await _capture_world(rig, vendor.global_position + Vector3.UP * 1.1,
		Vector3(-4.2, 1.9, -1.6), _out.path_join("npc_attention.png"))

	rig.check(SupplyDb.buy(bag_line),
		"the representative purchase commits through SupplyDb.buy")
	await rig.wait_frames(4)
	rig.check(not vendor.attention_marker.visible,
		"the mark disappears when the affordable bill is purchased")

	# Re-open eligibility, then close the service. This is the other event-driven
	# removal edge and proves set_activity does not leave stale attention behind.
	Game.gold = 1000
	Bus.gold_changed.emit(Game.gold)
	await rig.wait_frames(3)
	rig.check(vendor.attention_marker.visible,
		"a later affordable rung can raise the mark again")
	vendor.set_activity(Npc.ACTIVITY_BONFIRE, day_transform)
	await rig.wait_frames(3)
	rig.check(not vendor.current_services_open()
		and not vendor.attention_marker.visible,
		"service closure removes the mark immediately")
	vendor.set_activity(Npc.ACTIVITY_WORKING, day_transform)


func _catalogue_line(db: GDScript, id: StringName) -> Dictionary:
	for line: Dictionary in db.lines():
		if StringName(line.get("id", &"")) == id:
			return line
	return {}


func _capture_world(rig, target: Vector3, offset: Vector3, path: String) -> void:
	var scene: Node = rig.scene()
	var keep: Camera3D = scene.get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.fov = 50.0
	scene.add_child(camera)
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	await rig.wait_frames(5)
	rig.still_the_frame()
	await rig.wait_frames(3)
	await rig.capture(path)
	if keep != null:
		keep.make_current()
	camera.queue_free()
	await rig.wait_frames(2)


func _hero(garrison: Garrison) -> Hero:
	return garrison.get_tree().get_first_node_in_group(&"player") as Hero


func _face(hero: Hero, target: Vector3) -> void:
	var to := K.flat(target - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.facing_yaw = atan2(to.x, to.z)
	hero.rotation.y = hero.facing_yaw + PI


func get_viewport_focus(screen: Control) -> Control:
	return screen.get_viewport().gui_get_focus_owner()


func _screens(root: Node) -> Array[FieldNotesBookScreen]:
	var found: Array[FieldNotesBookScreen] = []
	for node: Node in _all(root):
		if node is FieldNotesBookScreen:
			found.append(node as FieldNotesBookScreen)
	return found


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found
