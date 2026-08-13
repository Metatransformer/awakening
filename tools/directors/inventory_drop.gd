extends RefCounted
## Item-local Inventory actions, end to end through the real menu and world pickup.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/inventory_drop.gd \
##     --out=/tmp/inventory-drop/x.png --size=1280x720 --warmup=60

const ITEM := &"iron_scrap"
const CASE_COUNT := 60
const HOLD_COUNT := 6
const TOTAL_COUNT := CASE_COUNT + HOLD_COUNT
## Seven shares cleanly across 756 base value: the six-piece hold cell carries
## exactly one premium, so the removal and recollection arithmetic are visible
## as exact integers rather than hidden behind a zero-premium control.
const PREMIUM := 7

var _out: String = ""


func run(rig: Variant) -> void:
	_out = rig.arg("out", "/tmp/inventory-drop/x.png").get_base_dir()
	Input.use_accumulated_input = false
	var scene: Node = rig.scene()
	var hero := scene.get_tree().get_first_node_in_group(&"player") as Hero
	var menu: PauseMenu = Menu
	var pouch := menu.get_node("Root/Screens/PouchScreen") as MenuPouchPanel
	if not _check(rig, hero != null, "A0 the dungeon has a real Hero"):
		return
	if not _check(rig, pouch != null, "A1 the autoload Menu has its Inventory panel"):
		return

	await _prepare(rig, scene, menu)
	var def := ItemDb.get_def(ITEM)
	if not _check(rig, def != null, "A2 Iron Scrap is a valid catalogue item"):
		return
	_check(rig, Run.in_case(ITEM) == CASE_COUNT and Run.in_hold(ITEM) == HOLD_COUNT,
		"A3 setup split one id across case and hold")
	_check(rig, _motes(scene).is_empty(),
		"A4 null control: the floor starts with no LootMote")
	_check(rig, is_equal_approx(_forward_distance(Vector3.ZERO, Vector3.FORWARD,
			Vector3.FORWARD * 2.0), 2.0)
		and _forward_distance(Vector3.ZERO, Vector3.FORWARD,
			-Vector3.FORWARD) < 0.0,
		"A5 spatial calibration reads a known forward point and rejects a rear point")

	await rig.tap([&"inventory"])
	await rig.wait_frames(12)
	if not _check(rig, menu.is_open and pouch.visible,
			"B0 the real Inventory action opened the real screen"):
		return
	var actions := pouch.get_node("ItemActions") as Control
	var context := pouch.get_node("ItemActions/Frame/Pad/Buttons/Context") as Button
	var drop := pouch.get_node("ItemActions/Frame/Pad/Buttons/Drop") as Button
	var action_back := pouch.get_node("ItemActions/Frame/Pad/Buttons/Back") as Button
	if not _check(rig, actions != null and context != null and drop != null
			and action_back != null, "B1 Inventory built its local item-action card"):
		return
	_check(rig, _footer_buttons(pouch) == 1 and pouch._back.text == "Back",
		"B2 the persistent footer contains Back and no Drop action")

	var occupied := pouch._grid.cell_at(0) as Button
	var empty := pouch._grid.cell_at(1) as Button
	if not _check(rig, occupied != null and empty != null,
			"B3 the hold drew one occupied and one empty tile"):
		return
	occupied.grab_focus()
	await rig.wait_frames(3)
	_check(rig, occupied.has_focus() and pouch._selected_id == ITEM
		and pouch._selected_count == HOLD_COUNT and not pouch._selected_from_case,
		"B4 the stronger tile cursor selects the exact displayed hold stack")
	var focus_style := occupied.get_theme_stylebox("focus") as StyleBoxFlat
	_check(rig, focus_style != null and focus_style.border_width_left >= 3
		and focus_style.bg_color.a >= 0.75
		and focus_style.border_color.is_equal_approx(UITheme.HIGHLIGHT),
		"B4a focused MenuSlot uses a neutral selected fill and thick off-white rim")
	await _capture(rig, "inventory_selected_tile.png")

	var before_back_case := Run.in_case(ITEM)
	var before_back_hold := Run.in_hold(ITEM)
	var before_back_premium := Run.premium
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(3)
	_check(rig, actions.visible and context.text == "Pack"
		and _viewport_focus(pouch) == action_back,
		"B5 controller confirm opens Pack / Drop / Back with safe Back focused")
	_check(rig, _card_is_beside(actions, occupied),
		"B6 the action card is anchored beside its exact source tile")
	await _capture(rig, "inventory_actions_hold.png")
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(3)
	_check(rig, not actions.visible and occupied.has_focus(),
		"B7 the default Back action closes the card and restores source-tile focus")
	_check(rig, Run.in_case(ITEM) == before_back_case
		and Run.in_hold(ITEM) == before_back_hold and Run.premium == before_back_premium,
		"B8 Back preserves the exact stack and premium")

	empty.grab_focus()
	await rig.wait_frames(2)
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(3)
	_check(rig, not actions.visible and empty.has_focus(),
		"B9 activating an empty tile offers no item actions")
	_check(rig, Run.in_case(ITEM) == before_back_case
		and Run.in_hold(ITEM) == before_back_hold,
		"B10 empty activation leaves both inventory regions untouched")

	# Drive the Button's mouse-facing signal after focus is deliberately elsewhere.
	# ItemGrid owns the press and emits the same `cell_activated` signal as A; the
	# pouch no longer has a mouse flag or a mouse-only selection branch.
	_mouse_activate(occupied)
	await rig.wait_frames(3)
	_check(rig, actions.visible and context.text == "Pack"
		and pouch._selected_id == ITEM and pouch._selected_count == HOLD_COUNT
		and not pouch._selected_from_case and _viewport_focus(pouch) == action_back,
		"B11 mouse activation converges on the same hold card and safe focus")
	_check(rig, Run.in_case(ITEM) == before_back_case
		and Run.in_hold(ITEM) == before_back_hold,
		"B12 opening actions by mouse does not silently Pack")
	await rig.tap([&"ui_cancel"])
	await rig.wait_frames(3)
	_check(rig, not actions.visible and occupied.has_focus() and menu.is_open,
		"B13 ui_cancel is local Back and restores the mouse source without leaving Inventory")

	var total_before := Run.bag_count()
	var base_before := Run.base_value()
	var premium_before := Run.premium
	var cased_before := Run.in_case(ITEM)
	var hero_at := hero.global_position
	var forward := K.plane(-hero.global_transform.basis.z).normalized()
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(2)
	drop.grab_focus()
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(8)
	_check(rig, not menu.is_open, "C0 local Drop hands control back to the world")
	_check(rig, Run.bag_count() == total_before - HOLD_COUNT
		and Run.in_hold(ITEM) == 0,
		"C1 the hold drop removed exactly the displayed six-piece stack")
	_check(rig, Run.in_case(ITEM) == cased_before,
		"C2 dropping the hold did not reduce the same id's cased count")

	var motes := _motes(scene)
	if not _check(rig, motes.size() == 1,
			"C3 the world handoff spawned exactly one ordinary LootMote"):
		return
	var mote: LootMote = motes[0]
	var removed_premium: int = premium_before - Run.premium
	var removed_base: int = def.value * HOLD_COUNT
	var expected_mult := 1.0 + float(removed_premium) / float(removed_base)
	_check(rig, mote.item_id == ITEM and mote.count == HOLD_COUNT,
		"C4 the mote carries the selected hold id and displayed count")
	_check(rig, is_equal_approx(mote.heat_mult, expected_mult),
		"C5 the mote carries the removed stack's exact Heat multiplier")

	await rig.wait_seconds(0.55)
	var planar := K.plane(mote.global_position - hero_at)
	var forward_m := _forward_distance(hero_at, forward, mote.global_position)
	var lateral_m := (planar - forward * forward_m).length()
	_check(rig, forward_m > 2.0 and forward_m < 2.6 and lateral_m < 0.12,
		"C6 the fling landed forward and away (forward=%.2f lateral=%.2f)"
			% [forward_m, lateral_m])
	_check(rig, planar.length() > 0.90,
		"C7 the landed mote is beyond the 0.75 m pickup radius (%.2f m)"
			% planar.length())
	_check(rig, absf(mote.global_position.y - hero_at.y) < 0.08,
		"C8 the mote landed at floor level instead of floating")
	await _capture(rig, "inventory_drop_landed.png")
	await rig.wait_seconds(K.HEAT_COOL_TIME + 0.25)
	_check(rig, is_equal_approx(mote.heat(), expected_mult),
		"C9 an inventory premium remains stamped while the ordinary pickup waits")

	var recollected := await _walk_to_mote(rig, scene, hero, mote, total_before)
	_check(rig, recollected, "D0 real movement walked the Hero back over the mote")
	_check(rig, Run.bag_count() == total_before and Run.base_value() == base_before,
		"D1 recollection restored the count and total base value")
	_check(rig, Run.premium == premium_before,
		"D2 recollection restored the carried premium without minting")
	await rig.wait_seconds(0.35)
	_check(rig, _motes(scene).is_empty(),
		"D3 the collected ordinary pickup left no duplicate mote")

	# The protected side gets the same local card and the same PauseMenu handoff;
	# only the region flag changes, so the existing drop transaction trims cased.
	await rig.tap([&"inventory"])
	await rig.wait_frames(12)
	var case_cell := pouch._case_grid.cell_at(0) as Button
	if not _check(rig, menu.is_open and case_cell != null,
			"E0 Inventory reopened with an occupied case tile"):
		return
	case_cell.grab_focus()
	await rig.wait_frames(2)
	var case_stack: int = pouch._selected_count
	var case_before: int = Run.in_case(ITEM)
	var bag_before: int = Run.bag_count()
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(3)
	_check(rig, actions.visible and context.text == "Unpack"
		and pouch._selected_from_case and case_stack > 0,
		"E1 a case activation offers Unpack / Drop / Back for that case stack")
	drop.grab_focus()
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(8)
	_check(rig, not menu.is_open, "E2 the case-side local Drop returns to the world")
	_check(rig, Run.in_case(ITEM) == case_before - case_stack,
		"E3 case Drop reduced the protected count by the displayed stack")
	_check(rig, Run.bag_count() == bag_before - case_stack,
		"E4 case Drop removed the same stack from the bag total")
	var case_motes := _motes(scene)
	_check(rig, case_motes.size() == 1 and case_motes[0].item_id == ITEM
		and case_motes[0].count == case_stack,
		"E5 the existing world handoff spawned the exact selected case stack")
	print("INVENTORY DROP director completed")


func _prepare(rig: Variant, scene: Node, menu: PauseMenu) -> void:
	if menu.is_open:
		menu.close()
	for enemy: Node in scene.get_tree().get_nodes_in_group(&"enemy"):
		enemy.queue_free()
	for mote: LootMote in _motes(scene):
		mote.queue_free()
	await rig.wait_frames(4)
	if not Run.in_dungeon:
		Run.enter(166)
	Heat.reset()
	Run.bag.clear()
	Run.cased.clear()
	Run.premium = 0
	var taken: int = Run.collect(ITEM, TOTAL_COUNT)
	Run.premium = PREMIUM
	Bus.bag_changed.emit(Run.bag, Run.bag_value())
	_check(rig, taken == TOTAL_COUNT, "setup put the full deterministic stack in the bag")
	await rig.wait_frames(4)


func _footer_buttons(pouch: MenuPouchPanel) -> int:
	var count := 0
	for child: Node in pouch._back.get_parent().get_children():
		if child is Button:
			count += 1
	return count


func _viewport_focus(control: Control) -> Control:
	return control.get_viewport().gui_get_focus_owner()


func _card_is_beside(actions: Control, source: Control) -> bool:
	var frame := actions.get_node("Frame") as PanelContainer
	if frame == null:
		return false
	var card_rect := frame.get_global_rect()
	var source_rect := source.get_global_rect()
	return not card_rect.intersects(source_rect) \
		and card_rect.position.x >= 0.0 and card_rect.position.y >= 0.0 \
		and card_rect.end.x <= actions.get_viewport_rect().size.x \
		and card_rect.end.y <= actions.get_viewport_rect().size.y


func _mouse_activate(button: Button) -> void:
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	button.gui_input.emit(mouse_down)
	button.pressed.emit()


func _walk_to_mote(rig: Variant, scene: Node, hero: Hero, mote: LootMote,
		wanted_count: int) -> bool:
	var toward := K.plane(mote.global_position - hero.global_position).normalized()
	if toward == Vector3.ZERO:
		return false
	var viewport := hero.get_viewport()
	var original_camera := viewport.get_camera_3d()
	var walk_camera := Camera3D.new()
	scene.add_child(walk_camera)
	walk_camera.global_position = hero.global_position - toward * 3.5 + Vector3.UP * 2.2
	walk_camera.look_at(hero.global_position + toward * 2.0 + Vector3.UP * 0.5,
		Vector3.UP)
	walk_camera.make_current()
	await rig.wait_frames(3)
	await rig.press(&"move_up")
	var collected: bool = await rig.until(
		func() -> bool: return Run.bag_count() == wanted_count, 3.0)
	rig.release(&"move_up")
	hero.velocity = Vector3.ZERO
	if original_camera != null and is_instance_valid(original_camera):
		original_camera.make_current()
	walk_camera.queue_free()
	await rig.wait_frames(3)
	return collected


func _motes(scene: Node) -> Array[LootMote]:
	var out: Array[LootMote] = []
	for node: Node in scene.get_tree().get_nodes_in_group(LootMote.NAME_GROUP):
		var mote := node as LootMote
		if mote != null and is_instance_valid(mote):
			out.append(mote)
	return out


func _forward_distance(origin: Vector3, forward: Vector3, point: Vector3) -> float:
	return K.plane(point - origin).dot(forward.normalized())


func _capture(rig: Variant, file_name: String) -> void:
	if rig.arg("no-capture", "0") == "1":
		return
	await rig.capture(_out.path_join(file_name))


func _check(rig: Variant, ok: bool, message: String) -> bool:
	if ok:
		print("  ok   %s" % message)
	else:
		rig.fail(message)
	return ok
