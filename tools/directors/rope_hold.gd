extends RefCounted
## Escape Rope ownership, driven end to end in a real dungeon.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/rope_hold.gd \
##     --out=/tmp/rope/r.png --size=1280x720 --warmup=60
##
## The player opens the root menu, reaches Equipment with keyboard input, holds
## the deliberate menu guard, and then watches the real world-owned EscapeRope.
## Two Ropes prove both outcomes: interruption keeps the run but not the spent
## Rope; the next completed channel ends the run. Neither path spends gold.

const NAV_LIMIT := 24

var out := ""
var _fails := 0
var _fired_count := 0


func _on_used() -> void:
	_fired_count += 1


func run(rig) -> void:
	out = rig.arg("out", "/tmp/rope/r.png").get_base_dir()
	await rig.wait_frames(30)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("A0 there is no hero in this room")
		return
	var hero = players[0]
	var rope: EscapeRope = hero.rope
	_ck("A0 the room booted into a run", Run.in_dungeon)
	_ck("A1 the hero carries the real EscapeRope", rope != null)
	if rope == null:
		return

	Game.dev_god_mode = false
	Game.add_escape_ropes(2)
	Game.add_gold(200)
	var stock_before := Game.escape_ropes
	var gold_before := Game.gold
	_ck("A2 at least two Ropes were provisioned (%d)" % stock_before,
		stock_before >= 2)
	Bus.escape_rope_used.connect(_on_used)

	# --- Reach Equipment through player input -------------------------------
	await _open_equipment(rig)
	var equip: MenuEquipPanel = Menu.get_node("Root/Screens/EquipScreen")
	_ck("B0 Escape opened the root and keyboard input reached Equipment",
		Menu.is_open and equip.visible)
	var rope_row := equip.find_child("Rope", true, false) as Button
	_ck("B1 Equipment renders the Escape Rope row", rope_row != null)
	_ck("B2 Inventory renders no Escape Rope row",
		Menu.get_node("Root/Screens/PouchScreen").find_child("Rope", true, false) == null)
	await _nav_to_button(rig, "Escape Rope")
	await rig.capture(out.path_join("r_00_equipment_idle.png"))

	# A tap is still only a tap.
	await rig.hold_seconds([&"ui_hold"], 0.08)
	await rig.wait_frames(8)
	_ck("C0 a tap leaves the menu and stock untouched",
		Menu.is_open and Run.in_dungeon and Game.escape_ropes == stock_before)
	_ck("C1 the released gauge snapped to zero",
		is_zero_approx(equip._rope_hold))

	# --- First Rope: consume at world-channel start, then interrupt ----------
	Input.action_press(&"ui_hold")
	for _i in 120:
		await rig.wait_frames(1)
		if equip._rope_hold >= MenuEquipPanel.ROPE_HOLD * 0.45:
			break
	_ck("D0 the Equipment hold gauge became visible (%.2f)" % equip._rope_hold,
		equip._rope_hold > 0.0 and Menu.is_open)
	await rig.capture(out.path_join("r_01_equipment_mid_hold.png"))
	await _wait_for_menu_close(rig)
	Input.action_release(&"ui_hold")
	await rig.wait_frames(6)

	_ck("D1 the hold emitted use and closed the whole menu",
		_fired_count == 1 and not Menu.is_open and not rig.paused)
	_ck("D2 the real Rope is channelling in the world", rope.active())
	_ck("D3 exactly one Rope was consumed at channel start (%d -> %d)" % [
			stock_before, Game.escape_ropes],
		Game.escape_ropes == stock_before - 1)
	_ck("D4 Rope extraction charged no gold (%d)" % Game.gold,
		Game.gold == gold_before)
	await rig.capture(out.path_join("r_02_world_channel.png"))

	rope.cancel()
	await rig.wait_frames(8)
	_ck("E0 interruption kept the run active", Run.in_dungeon and not rope.active())
	_ck("E1 a broken Rope was not returned",
		Game.escape_ropes == stock_before - 1)
	_ck("E2 interruption still charged no gold", Game.gold == gold_before)
	await rig.capture(out.path_join("r_03_interrupted.png"))

	# --- Second Rope: same player route, completed ---------------------------
	await _open_equipment(rig)
	await _nav_to_button(rig, "Escape Rope")
	Input.action_press(&"ui_hold")
	await _wait_for_menu_close(rig)
	Input.action_release(&"ui_hold")
	await rig.wait_frames(6)
	_ck("F0 the second deliberate hold started a second world channel",
		_fired_count == 2 and rope.active())
	_ck("F1 the second start consumed exactly one more Rope",
		Game.escape_ropes == stock_before - 2)
	_ck("F2 gold is still unchanged at the second channel start",
		Game.gold == gold_before)

	await rig.wait_seconds(rope.channel_time() + 0.3)
	await rig.wait_frames(40)
	_ck("G0 the completed Rope channel ended the run", not Run.in_dungeon)
	_ck("G1 Rope extraction left gold unchanged", Game.gold == gold_before)
	await rig.capture(out.path_join("r_04_ended.png"))
	Bus.escape_rope_used.disconnect(_on_used)

	if _fails == 0:
		print("ROPE OK — Equipment hold, counted stock, interrupt, completion, no gold")
	else:
		print("ROPE FAIL %d check(s)" % _fails)


func _open_equipment(rig) -> void:
	await _key(rig, KEY_ESCAPE, 16)
	await _nav_to_button(rig, "Equipment")
	await _key(rig, KEY_ENTER, 16)


func _wait_for_menu_close(rig) -> void:
	for _i in 180:
		if not Menu.is_open:
			return
		await rig.wait_frames(1)
	_fail("the 0.9-second Equipment hold never closed the menu")


func _nav_to_button(rig, label: String) -> void:
	for _i in NAV_LIMIT:
		var focused: Control = rig.root.gui_get_focus_owner()
		if focused is Button and UiKit.label_of(focused as Button) == label:
			return
		await _key(rig, KEY_DOWN, 2)
	_fail("keyboard focus could not reach '%s'" % label)


func _key(rig, code: int, settle: int = 8) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await rig.wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await rig.wait_frames(settle)


func _ck(what: String, ok: bool) -> void:
	if ok:
		print("PASS %s" % what)
	else:
		_fails += 1
		print("ROPE FAIL %s" % what)


func _fail(msg: String) -> void:
	_fails += 1
	print("ROPE FAIL %s" % msg)
