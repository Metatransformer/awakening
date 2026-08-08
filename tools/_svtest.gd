extends Node
## Exercises Settings + Saves for real: writes, reads back, and checks the
## values survived the round trip. Safe to delete once the menu package has
## its own coverage.
func _ready() -> void:
	await get_tree().process_frame
	var fails := 0

	# --- audio buses exist and volume actually reaches them -----------------
	for b in [&"Master", &"Music", &"SFX", &"UI"]:
		if AudioServer.get_bus_index(b) < 0:
			print("FAIL bus missing: ", b); fails += 1
	Settings.set_volume(&"Music", 0.25)
	var idx := AudioServer.get_bus_index(&"Music")
	var want := linear_to_db(0.25)
	if absf(AudioServer.get_bus_volume_db(idx) - want) > 0.01:
		print("FAIL music bus db=", AudioServer.get_bus_volume_db(idx), " want ", want); fails += 1
	Settings.set_volume(&"Music", 0.0)
	if not AudioServer.is_bus_mute(idx):
		print("FAIL zero volume did not mute"); fails += 1
	Settings.set_volume(&"Music", 0.7)

	# --- settings persist ---------------------------------------------------
	Settings.camera_sensitivity = 1.75
	Settings.shadow_quality = 1
	Settings.save_settings()
	Settings.camera_sensitivity = 0.0
	Settings.shadow_quality = 3
	Settings.load_settings()
	if not is_equal_approx(Settings.camera_sensitivity, 1.75):
		print("FAIL sensitivity did not persist: ", Settings.camera_sensitivity); fails += 1
	if Settings.shadow_quality != 1:
		print("FAIL shadow_quality did not persist: ", Settings.shadow_quality); fails += 1

	# --- rebinding, including the conflict rule -----------------------------
	var e := InputEventKey.new()
	e.physical_keycode = KEY_G
	if not Settings.rebind(&"attack", e):
		print("FAIL could not rebind attack to G"); fails += 1
	if Settings.label_for(&"attack") != "G":
		print("FAIL label_for(attack)=", Settings.label_for(&"attack")); fails += 1
	var dup := InputEventKey.new()
	dup.physical_keycode = KEY_G
	if Settings.rebind(&"shield", dup):
		print("FAIL conflicting bind was accepted"); fails += 1
	Settings.reset_binds()
	if Settings.label_for(&"attack") != "J":
		print("FAIL reset_binds did not restore J, got ", Settings.label_for(&"attack")); fails += 1

	# --- save slots ---------------------------------------------------------
	Game.reset()
	Game.add_gold(137)
	Game.add_key(2)
	Game.grant(&"hookshot")
	Game.damage(3)
	Saves.current_room = &"room_04"
	if not Saves.save(1):
		print("FAIL could not write slot 1"); fails += 1
	var head := Saves.peek(1)
	if head.get("gold") != 137 or head.get("keys") != 2:
		print("FAIL peek wrong: ", head); fails += 1
	if not (head.get("items") as Array).has("hookshot"):
		print("FAIL peek lost items: ", head); fails += 1

	Game.reset()
	if Game.gold != 0:
		print("FAIL reset did not clear"); fails += 1
	var where := Saves.load_slot(1)
	if Game.gold != 137 or Game.small_keys != 2 or not Game.has(&"hookshot"):
		print("FAIL load did not restore: gold=", Game.gold, " keys=", Game.small_keys); fails += 1
	if Game.quarters != Game.max_quarters - 3:
		print("FAIL health not restored: ", Game.quarters); fails += 1
	if String(where.get("room", "")) != "room_04":
		print("FAIL room not restored: ", where); fails += 1
	if Saves.peek(2).get("empty") != true:
		print("FAIL empty slot 2 not reported empty"); fails += 1
	Saves.erase(1)
	if Saves.has_save(1):
		print("FAIL erase did not remove slot"); fails += 1

	print("SVTEST ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
