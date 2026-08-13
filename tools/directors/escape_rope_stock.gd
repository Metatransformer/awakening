extends RefCounted
## Issue #199: counted Escape Rope stock, its real quartermaster row, dungeon
## provision pickups, and the v21 save boundary.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/escape_rope_stock.gd \
##     --out=/tmp/escape-rope-stock/x.png --size=1280x720 --warmup=60
##
## The Trade frames are one live screen held on one row: before purchase, after
## exactly one purchase, and after a full-stock refusal. The world frame is a
## real ProvisionPickup before the hero walks onto it. Slot 199 is deliberately
## outside the player's 0..2 list and is erased before and after the save beats.

const SAVE_SLOT := 199
const PURSE := 500
const LEGACY_KEYS := 5

var _fails := 0
var _out := ""
var _provision_edges := 0
var _old_gold := 0
var _old_rope := 0
var _old_rations: Dictionary[StringName, int] = {}
var _old_keys: Dictionary[int, int] = {}
var _old_run: Dictionary = {}
var _old_active_slot := -1
var _old_god_mode := false
var _old_warmth := false


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/escape-rope-stock/x.png").get_base_dir()
	_snapshot_state()
	Saves.erase(SAVE_SLOT)
	Saves.active_slot = -1
	Game.dev_god_mode = false
	Game.warmth_active = false
	Game.gold = PURSE
	Game.escape_ropes = 0
	Game.rations.clear()
	Game.clear_small_keys(false)
	Bus.gold_changed.emit(Game.gold)
	Bus.provisions_changed.emit()
	Bus.rations_changed.emit(Game.rations)

	if not Bus.provisions_changed.is_connected(_on_provisions_changed):
		Bus.provisions_changed.connect(_on_provisions_changed)

	await _trade(rig)
	await _public_stock(rig)
	await _pickups(rig)
	await _save_round_trip(rig)
	await _restore_state(rig)

	print("ESCAPE_ROPE_STOCK OK -- every check passed" if _fails == 0 \
		else "ESCAPE_ROPE_STOCK FAILED (%d)" % _fails)


# --- The real quartermaster board -------------------------------------------

func _trade(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null or garrison.vendor == null:
		_fail("the garrison has no live quartermaster")
		return
	_stand_at(rig, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	_ck("the quartermaster owns the interact prompt",
		await _until(rig, func() -> bool: return Prompt.focus == garrison.vendor, 120))
	await rig.tap(["interact"])
	_ck("the quartermaster offers her Trade service", await rig.talk("Trade"))
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		_fail("the quartermaster Trade screen did not open")
		return
	_ck("the live screen is quartermaster Trade",
		screen.mode == TradeScreen.Mode.TRADE and screen.catalogue == SupplyDb
		and screen.visible_catalogue_ids == SupplyDb.STOCK_IDS)
	var row := _row(screen, &"escape_rope")
	if row.is_empty():
		_fail("Trade has no ESCAPE ROPE row")
		screen.close()
		return
	_ck("the catalogue base price is exactly 60 gold",
		SupplyDb.ESCAPE_ROPE_GOLD == 60 and int(row["line"]["cost"]) == 60)
	_ck("the row consumes no material",
		(row["line"].get("parts", {}) as Dictionary).is_empty())
	_ck("the row reports live zero-of-nine stock",
		String(row["line"].get("detail", "")) == "0 / %d carried" % K.ESCAPE_ROPE_STACK)

	_ck("the Rope row can be aimed through the live focus chain",
		await _aim(rig, screen, &"escape_rope"))
	_assert_rendered_row(screen, "0 / %d carried" % K.ESCAPE_ROPE_STACK, true)
	await _capture(rig, "t_00_before.png")

	var gold_before := Game.gold
	var stock_before := Game.escape_ropes
	await rig.tap(["ui_accept"])
	await rig.wait_frames(12)
	_ck("a UI purchase adds exactly one Rope",
		Game.escape_ropes == stock_before + 1)
	_ck("a UI purchase costs exactly 60 current gold",
		Game.gold == gold_before - SupplyDb.ESCAPE_ROPE_GOLD)
	screen._refresh()
	await _aim(rig, screen, &"escape_rope")
	await _until(rig,
		func() -> bool: return absf(screen._shown_gold - float(Game.gold)) < 0.5, 180)
	_assert_rendered_row(screen, "1 / %d carried" % K.ESCAPE_ROPE_STACK, true)
	await _capture(rig, "t_01_after.png")

	Game.add_escape_ropes(K.ESCAPE_ROPE_STACK)
	screen._refresh()
	await _aim(rig, screen, &"escape_rope")
	var full_gold := Game.gold
	var full_stock := Game.escape_ropes
	await rig.tap(["ui_accept"])
	await rig.wait_frames(8)
	_ck("the full row visibly names its refusal",
		screen._tip != null and screen._tip.visible
		and screen._tip.note.text == "THE ROPE STOCK IS FULL"
		and screen._toast != null and screen._toast.is_visible_in_tree())
	_ck("a press at the stack ceiling spends no gold and adds no Rope",
		Game.gold == full_gold and Game.escape_ropes == full_stock)
	await _capture(rig, "t_02_full_refusal.png")
	await rig.tap(["ui_accept"])
	await rig.wait_frames(5)
	_ck("another full-stock press is still free",
		Game.gold == full_gold and Game.escape_ropes == full_stock)

	screen.close()
	await _until(rig, func() -> bool: return _screen(rig) == null, 90)
	await rig.wait_frames(6)


func _assert_rendered_row(screen, detail: String, affordable: bool) -> void:
	var row := _row(screen, &"escape_rope")
	var cell := _stock_cell(screen, row)
	var expected_icon := UiKit.action_icon("rope")
	var art := cell.get_node_or_null(^"Art") as TextureRect if cell != null else null
	var name_label := cell.get_node_or_null(^"Name") as Label if cell != null else null
	var sub := cell.get_node_or_null(^"Sub") as Label if cell != null else null
	_ck("the ESCAPE ROPE tile is visible and focusable",
		cell != null and cell.is_visible_in_tree()
		and cell.focus_mode == Control.FOCUS_ALL and cell.has_focus())
	_ck("the rendered tile names ESCAPE ROPE and 60 gold",
		name_label != null and name_label.text == "ESCAPE ROPE"
		and sub != null and sub.text == "60 ◇")
	_ck("the rendered tile uses the Rope action glyph",
		not expected_icon.is_empty() and art != null and art.visible
		and art.texture != null and art.texture.resource_path == expected_icon)
	_ck("the visible detail card reports the live stock and price",
		screen._tip != null and screen._tip.visible
		and screen._tip.title.text == "ESCAPE ROPE"
		and screen._tip.price.text == "60 ◇"
		and screen._tip.blurb.text.contains(detail))
	_ck("the visible detail card has no material rows",
		screen._tip != null and screen._tip.rows.get_child_count() == 0)
	if affordable:
		_ck("the rendered Rope row is affordable", screen._tip.note.text == "Affordable")


# --- Public counted-provision seam ------------------------------------------

func _public_stock(rig) -> void:
	Game.escape_ropes = 0
	_provision_edges = 0
	var added := Game.add_escape_ropes(99)
	_ck("the public add seam clamps to nine", added == K.ESCAPE_ROPE_STACK
		and Game.escape_ropes == K.ESCAPE_ROPE_STACK)
	_ck("the clamp emits one observable provision edge", _provision_edges == 1)
	_ck("adding past full returns zero and emits nothing",
		Game.add_escape_ropes(1) == 0 and _provision_edges == 1)
	_ck("spend removes exactly one",
		Game.spend_escape_rope() and Game.escape_ropes == K.ESCAPE_ROPE_STACK - 1
		and _provision_edges == 2)
	while Game.escape_ropes > 0:
		Game.spend_escape_rope()
	var edges_at_zero := _provision_edges
	_ck("zero stock refuses without another signal",
		not Game.spend_escape_rope() and Game.escape_ropes == 0
		and _provision_edges == edges_at_zero)
	await rig.wait_frames(2)


func _on_provisions_changed() -> void:
	_provision_edges += 1


# --- The physical dungeon provision ----------------------------------------

func _pickups(rig) -> void:
	var hero := _hero(rig)
	if hero == null:
		_fail("the garrison has no hero for the provision pickup")
		return
	# The quartermaster interaction leaves the hero in the clear aisle in front
	# of her counter. Keep the pickup on that readable patch and move the hero
	# farther down the aisle until collection is the beat under test; shifting the
	# pickup sideways put the proof camera inside the market's east wall.
	var away := hero.global_position
	var pickup_at := away
	hero.global_position = away + Vector3(0.0, 0.0, 4.0)

	Game.escape_ropes = K.ESCAPE_ROPE_STACK - 1
	Bus.provisions_changed.emit()
	var rope := ProvisionPickup.new()
	rope.name = "DirectorRopeProvision"
	rope.provision_id = &"escape_rope"
	rope.count = 2
	rig.scene().add_child(rope)
	rope.global_position = pickup_at
	await rig.wait_frames(4)
	_ck("a real Rope ProvisionPickup renders its coil and light",
		rope.visible and rope.get_node_or_null(^"Provision/LoopLeft") is MeshInstance3D
		and rope.get_node_or_null(^"ProvisionLight") is OmniLight3D)
	var cam := _pickup_camera(rig, pickup_at)
	await rig.wait_frames(8)
	await _capture(rig, "p_00_rope_pickup.png")

	hero.global_position = pickup_at
	await rig.wait_seconds(0.8)
	_ck("walking onto a Rope pickup fills only the remaining capacity",
		Game.escape_ropes == K.ESCAPE_ROPE_STACK)
	_ck("a successfully collected Rope pickup leaves the world",
		not is_instance_valid(rope))

	Game.rations.clear()
	_ck("the public ration seam fills exactly to its cap",
		Game.add_rations(&"hardtack", K.RATION_STACK + 7) == K.RATION_STACK
		and Game.ration_count(&"hardtack") == K.RATION_STACK)
	var ration := ProvisionPickup.new()
	ration.name = "DirectorHardtackProvision"
	ration.provision_id = &"hardtack"
	ration.count = 1
	rig.scene().add_child(ration)
	ration.global_position = pickup_at
	await rig.wait_seconds(0.55)
	_ck("a full ration stack refuses the physical pickup",
		Game.ration_count(&"hardtack") == K.RATION_STACK
		and is_instance_valid(ration) and ration.visible)

	hero.global_position = away
	if is_instance_valid(ration):
		ration.queue_free()
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	await rig.wait_frames(3)


func _pickup_camera(rig, at: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "EscapeRopeStockCamera"
	rig.scene().add_child(cam)
	cam.global_position = at + Vector3(0.0, 1.05, 1.85)
	cam.look_at(at + Vector3.UP * 0.45, Vector3.UP)
	cam.make_current()
	return cam


# --- Current and legacy save shapes -----------------------------------------

func _save_round_trip(rig) -> void:
	Saves.erase(SAVE_SLOT)
	Run.enter(199021)
	Run.level = 2
	Game.escape_ropes = 4
	Game.clear_small_keys(false)
	Game.set_small_keys_for_floor(1, 2, false)
	Game.set_small_keys_for_floor(2, 3, false)
	_ck("the disposable v21 slot writes through Saves.save", Saves.save(SAVE_SLOT))
	var current := _slot_json()
	_ck("the current slot is v21 and carries both counted states",
		int(current.get("version", 0)) == 21
		and int(current.get("escape_ropes", -1)) == 4
		and current.has("small_keys_by_floor"))

	Game.escape_ropes = 0
	Game.clear_small_keys(false)
	var loaded := Saves.load_slot(SAVE_SLOT)
	_ck("Saves.load_slot restores the current run", not loaded.is_empty())
	_ck("the save round trip preserves Rope stock", Game.escape_ropes == 4)
	_ck("the save round trip preserves keys on two floors",
		Game.small_keys_for_floor(1) == 2 and Game.small_keys_for_floor(2) == 3)

	# Rewrite the disposable current save into the exact additive predecessor:
	# legacy `small_keys`, no floor dictionary, and no counted Rope field.
	var legacy := current.duplicate(true)
	legacy["version"] = 20
	legacy.erase("escape_ropes")
	legacy.erase("small_keys_by_floor")
	legacy["small_keys"] = LEGACY_KEYS
	var legacy_run := legacy.get("run", {}) as Dictionary
	legacy_run["in_dungeon"] = true
	legacy_run["level"] = 3
	legacy["run"] = legacy_run
	_ck("the isolated v20 fixture rewrite succeeds", _write_slot_json(legacy))

	Game.escape_ropes = 8
	Game.set_small_keys_for_floor(1, 7, false)
	Game.set_small_keys_for_floor(2, 6, false)
	Game.set_small_keys_for_floor(4, 4, false)
	var migrated := Saves.load_slot(SAVE_SLOT)
	_ck("the v20 fixture remains readable", not migrated.is_empty())
	_ck("a legacy save missing Rope stock starts at zero", Game.escape_ropes == 0)
	_ck("legacy small_keys migrate only to the restored live floor",
		Run.level == 3 and Game.small_keys_for_floor(3) == LEGACY_KEYS
		and Game.small_keys_for_floor(1) == 0
		and Game.small_keys_for_floor(2) == 0
		and Game.small_keys_for_floor(4) == 0)
	Saves.erase(SAVE_SLOT)
	_ck("the disposable director slot is erased",
		not FileAccess.file_exists(Saves.slot_path(SAVE_SLOT)))
	await rig.wait_frames(2)


func _slot_json() -> Dictionary:
	var raw := FileAccess.get_file_as_string(Saves.slot_path(SAVE_SLOT))
	var parsed: Variant = JSON.parse_string(raw)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_slot_json(data: Dictionary) -> bool:
	var file := FileAccess.open(Saves.slot_path(SAVE_SLOT), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


# --- Cleanup and helpers -----------------------------------------------------

func _snapshot_state() -> void:
	_old_gold = Game.gold
	_old_rope = Game.escape_ropes
	_old_rations = Game.rations.duplicate()
	_old_keys = Game.small_keys_snapshot()
	_old_run = Run.snapshot()
	_old_active_slot = Saves.active_slot
	_old_god_mode = Game.dev_god_mode
	_old_warmth = Game.warmth_active


func _restore_state(rig) -> void:
	Saves.erase(SAVE_SLOT)
	Saves.active_slot = _old_active_slot
	if Bus.provisions_changed.is_connected(_on_provisions_changed):
		Bus.provisions_changed.disconnect(_on_provisions_changed)
	Game.gold = _old_gold
	Game.escape_ropes = _old_rope
	Game.rations = _old_rations.duplicate()
	Game.restore_small_keys(_old_keys)
	Game.dev_god_mode = _old_god_mode
	Game.warmth_active = _old_warmth
	Run.restore(_old_run, false)
	Bus.gold_changed.emit(Game.gold)
	Bus.provisions_changed.emit()
	Bus.rations_changed.emit(Game.rations)
	Game.announce_key_count()
	Game.garrison_changed.emit()
	await rig.wait_frames(2)


func _row(screen, id: StringName) -> Dictionary:
	for row: Dictionary in screen._rows:
		if row.get("kind") == &"buy" and row["line"]["id"] == id:
			return row
	return {}


func _stock_cell(screen, row: Dictionary) -> Button:
	if row.is_empty():
		return null
	var row_index: int = screen._rows.find(row)
	var stock_index: int = screen._stock_rows.find(row_index)
	return screen._stock_grid.cell_at(stock_index) if stock_index >= 0 else null


func _aim(rig, screen, id: StringName) -> bool:
	var row := _row(screen, id)
	if row.is_empty():
		return false
	screen._point_at(screen._rows.find(row))
	await rig.wait_frames(8)
	row = _row(screen, id)
	var cell := _stock_cell(screen, row)
	return not row.is_empty() and screen._cursor == screen._rows.find(row) \
		and cell != null and cell.has_focus()


func _screen(rig) -> TradeScreen:
	var found: Array[TradeScreen] = []
	for node: Node in _all(rig.scene()):
		if node is TradeScreen:
			found.append(node as TradeScreen)
	if found.size() > 1:
		_fail("%d Trade screens are open at once" % found.size())
	return found[0] if not found.is_empty() else null


func _hero(rig) -> Node3D:
	return rig.get_first_node_in_group(&"player") as Node3D


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found


func _stand_at(rig, where: Vector3, look_at: Vector3) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = where
	var to := K.flat(look_at - where)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI


func _until(rig, condition: Callable, frames: int) -> bool:
	for _i in frames:
		if condition.call():
			return true
		await rig.wait_frames(1)
	return condition.call()


func _capture(rig, file_name: String) -> void:
	var path := _out.path_join(file_name)
	await rig.capture(path)
	var image := Image.load_from_file(path)
	_ck("%s is a 1280x720 rendered frame" % file_name,
		image != null and image.get_size() == Vector2i(1280, 720))


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("ESCAPE_ROPE_STOCK ok %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_fails += 1
	print("ESCAPE_ROPE_STOCK FAIL %s" % label)
