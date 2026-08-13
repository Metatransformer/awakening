extends RefCounted
## Director for tools/shoot.gd (docs/CONTRACT.md §9). Drives the EQUIPMENT
## screen with nothing but injected keyboard events and photographs every state
## worth arguing about.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://scripts/ui/menu/_equip_director.gd \
##     --out=/abs/out/f.png --size=1280x720 --warmup=60
##
## What it is actually testing, beyond "does it draw":
##
##  * the four slots are reachable by keyboard alone, in a closed focus graph
##  * confirming a slot cycles THAT hand, in THAT set -- including the set the
##    player is not currently holding, which is the whole point of having two
##  * the ownership gate holds from the UI side: a slot cannot be cycled onto an
##    armament the player has never found, no matter how many times you press A
##  * the live-set mark follows Game.loadout_set
##  * the D-pad cycles agree with the screen: `cycle_weapon` walks the same pool
##    the right-hand slot walks, `cycle_item` walks the bottles, and X drinks
##    the one that is selected
##
## THE ITEM BUTTONS CARD IS GONE and half this director went with it. It used to
## prove that finding a bow auto-bound it to ↑, that binding it to ↓ moved it
## rather than cloning it, and that pressing a bound button drew and re-stowed.
## None of those are propositions any more -- there is nothing to bind -- and a
## director that kept asserting them would have been proving a screen that no
## longer exists.

const NAV_LIMIT := 20

var _pass := 0
var _fail := 0
## Set by `Bus.escape_rope_used`. See the note where it is armed.
var _rope_fired := false


func _on_rope_fired() -> void:
	_rope_fired = true


func run(rig) -> void:
	# The autoload, not a scene-local instance. There is exactly one PauseMenu in
	# the project now; a harness that instanced its own is how this project once
	# ended up with a menu that existed only in its own test scene.
	var menu: PauseMenu = Menu
	var equip: MenuEquipPanel = menu.get_node("Root/Screens/EquipScreen")
	var pouch: MenuPouchPanel = menu.get_node("Root/Screens/PouchScreen")

	# A fresh Game owns nothing, which is the state the ownership gate is for.
	# The screen has to be honest about it BEFORE anything is granted.
	Game.reset()
	await rig.wait_frames(4)

	await _nav_to_button(rig, "Equipment")
	await _key(rig, KEY_ENTER, 12)
	_check("the items screen is showing", equip.visible)
	_check("focus landed inside it, not on nothing", _focused(rig) != null)
	await rig.capture("eq_00_unowned.png")

	# --- The ring refuses what you have not found ----------------------------
	# Focus opens on the primary right hand. Mash confirm: owning nothing but the
	# sword, the pool the cycle walks is one entry long, so the hand must not
	# move -- five times, not just once. This is `cycle_armament`'s own early
	# return, seen from the screen, and it is the same gate D-pad → hits.
	await _nav_to_slot(rig, "Slot_0_right")
	for i in 5:
		await _key(rig, KEY_ENTER, 3)
	_check("an unowned weapon cannot be cycled onto (right hand is still %s)"
		% Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT),
		Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT) == &"sword")
	Game.cycle_weapon(1)
	_check("D-pad → refuses for the same reason, owning only the sword",
		Game.armament(Game.HAND_RIGHT) == &"sword")
	await rig.capture("eq_01_refused.png")

	# --- Finding a weapon puts it on the ring, and nothing else happens ------
	# There is no auto-bind to check any more. What replaced it is this: the bow
	# is one press of → away the moment it is granted, with no menu trip.
	Game.grant(&"bow")
	Game.add_arrows(18)
	Game.grant(&"hookshot")
	await rig.wait_frames(6)
	Game.cycle_weapon(1)
	_check("→ stepped the right hand off the sword (%s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) != &"sword")
	Game.cycle_weapon(1)
	Game.cycle_weapon(1)
	_check("three steps around a three-weapon ring came back to the sword (%s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"sword")
	Game.cycle_weapon(-1)
	_check("← is the other way round the same ring (%s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"hookshot")
	Game.cycle_weapon(1)
	equip.refresh()
	await rig.wait_frames(4)
	await rig.capture("eq_02_owned.png")

	# --- The item selection, which is a different ring on a different button --
	# Weapons are DRAWN and items are USED, and the two must not share a cycle:
	# stepping the bottles cannot be allowed to disturb the hand.
	var hand_before := Game.armament(Game.HAND_RIGHT)
	while Game.bottle_count() < 2:
		Game.add_bottle()
	Game.fill_bottle(&"health_draught")
	await rig.wait_frames(4)
	_check("↓ steps the bottles", Game.bottle_count() >= 2)
	var item_before := Game.item_selected
	Game.cycle_item(1)
	_check("↓ moved the selection (%d -> %d)" % [item_before, Game.item_selected],
		Game.item_selected != item_before)
	_check("stepping the items left the right hand alone (%s)" % hand_before,
		Game.armament(Game.HAND_RIGHT) == hand_before)
	Game.cycle_item(1)
	_check("the item ring wraps back to where it started",
		Game.item_selected == item_before)
	_check("X drinks the selected bottle", Game.use_selected_item())
	await rig.wait_frames(4)

	# --- The hands, below --------------------------------------------------
	await _nav_to_slot(rig, "Slot_0_right")
	var right_before := Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT)
	await _key(rig, KEY_ENTER, 10)
	_check("confirming the right-hand slot cycled it (%s -> %s)"
		% [right_before, Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT)],
		Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT) != right_before)
	_check("cycling the right hand left the LEFT hand alone",
		Game.armament_in(Game.PRIMARY, Game.HAND_LEFT) == &"shield")
	await rig.capture("eq_03_cycled.png")

	# --- Editing the set the player is NOT holding ---------------------------
	# Down from the primary row lands on the alternate row's same column.
	var live_before := Game.loadout_set
	var alt_before := Game.armament_in(Game.ALTERNATE, Game.HAND_RIGHT)
	var primary_held := Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT)
	await _key(rig, KEY_DOWN, 8)
	await _key(rig, KEY_ENTER, 10)
	_check("the alternate set was edited (%s -> %s)"
		% [alt_before, Game.armament_in(Game.ALTERNATE, Game.HAND_RIGHT)],
		Game.armament_in(Game.ALTERNATE, Game.HAND_RIGHT) != alt_before)
	_check("editing the alternate set did not make it live",
		Game.loadout_set == live_before)
	_check("editing the alternate set did not disturb the primary (%s)" % primary_held,
		Game.armament_in(Game.PRIMARY, Game.HAND_RIGHT) == primary_held)
	await rig.capture("eq_04_alternate.png")

	# --- The worn column -----------------------------------------------------
	# The eight slots nothing else in the game shows together. Owning none of
	# them is `eq_00_unowned` above; this is the state the doll exists for -- some
	# pieces climbed, some committed the other way, some never started.
	#
	# Granted straight into `upgrades` rather than through the smith, on purpose:
	# what is being proved here is that the DOLL reads the rungs, and routing it
	# through two counters would make a failure ambiguous between the two.
	# By name, not by path: half the containers between here and it are built
	# unnamed, so the path is the theme's business and not a thing to assert on.
	var doll := equip.find_child("Doll", true, false) as MenuPaperDoll
	_check("the worn column is on the screen", doll != null and doll.visible)
	Game.upgrades[&"plate_chest_heavy"] = 2
	Game.upgrades[&"plate_boots_light"] = 1
	Game.upgrades[&"jewel_ring1_edge"] = 3
	Game.upgrades[&"jewel_bracelet_wind"] = 1
	Bus.item_acquired.emit(&"plate_chest_heavy")
	await rig.wait_frames(6)
	_check("chest committed HEAVY, so LIGHT is shut",
		Game.path_closed(Game.plate_track(&"chest", Game.PLATE_LIGHT)))
	_check("boots went the other way and shut HEAVY",
		Game.path_closed(Game.plate_track(&"boots", Game.PLATE_HEAVY)))
	_check("the ring is three rungs up EDGE",
		Game.jewel_level(Game.jewel_track(&"ring1", &"edge")) == 3)
	# Nothing was granted for legs, arms, the amulet or the second ring, and the
	# doll has to say so rather than drawing four plates that look finished.
	_check("four slots are still untouched",
		Game.forge_level(Game.plate_track(&"legs", Game.PLATE_HEAVY)) == 0
		and Game.forge_level(Game.plate_track(&"arms", Game.PLATE_LIGHT)) == 0
		and Game.jewel_level(Game.jewel_track(&"amulet", &"vigor")) == 0
		and Game.jewel_level(Game.jewel_track(&"ring2", &"swift")) == 0)
	# The soak the plate bought has to be on the stat block in the same frame --
	# one screen, two readers of the same accessor (see `_refresh_stats`).
	equip.refresh()
	await rig.wait_frames(4)
	_check("the stat block moved with it (%.1f soaked)" % Game.armour_soak_exact(),
		Game.armour_soak_exact() > 0.0)
	await rig.capture("eq_05a_worn.png")

	# --- Swap Set ------------------------------------------------------------
	await _nav_to_button(rig, "Swap Set")
	await _key(rig, KEY_ENTER, 12)
	_check("Swap Set changed the live loadout (%d -> %d)" % [live_before, Game.loadout_set],
		Game.loadout_set != live_before)
	await rig.capture("eq_05_swapped.png")

	# --- Provisions and Rope belong to Equipment -----------------------------
	Game.add_charges(2)
	Game.add_rations(&"hardtack", 4)
	Game.add_rations(&"small_beer", 5)
	equip.refresh()
	await rig.wait_frames(4)

	await _nav_to_button(rig, "Escape Rope")
	var rope_row := equip.find_child("Rope", true, false) as Button
	_check("the Escape Rope is reachable on Equipment by keyboard",
		rope_row != null and _focused(rig) == rope_row)
	var equip_blob := " ".join(_all_text(equip)).to_upper()
	_check("Equipment visibly carries every provision number",
		equip_blob.contains("PROVISIONS")
		and equip_blob.contains("ARROWS")
		and equip_blob.contains("%d / %d" % [Game.arrows, Game.max_arrows])
		and equip_blob.contains("BURST CHARGES")
		and equip_blob.contains("%d / %d" % [Game.charges, Game.max_charges])
		and equip_blob.contains("HARDTACK")
		and equip_blob.contains("SMALL BEER"))
	var pouch_blob := " ".join(_all_text(pouch)).to_upper()
	_check("Inventory owns neither Rope nor the old TO LEAVE fee",
		pouch.find_child("Rope", true, false) == null
		and not pouch_blob.contains("ESCAPE ROPE")
		and not pouch_blob.contains("TO LEAVE"))
	await rig.capture("eq_06_provisions.png")

	# Refusal order starts with location, even while stock is also empty.
	await _key(rig, KEY_ENTER, 8)
	_check("already home refuses without closing Equipment",
		menu.is_open and equip.visible and not Run.in_dungeon)

	# Underground with zero stock refuses on the first held frame and never moves
	# the gauge. The row stays focusable so the detail card can explain why.
	Run.in_dungeon = true
	Game.escape_ropes = 0
	Bus.provisions_changed.emit()
	await rig.wait_frames(4)
	Input.action_press(&"ui_hold")
	await rig.wait_frames(2)
	Input.action_release(&"ui_hold")
	await rig.wait_frames(4)
	_check("zero Rope stock refused immediately and left the gauge at zero",
		menu.is_open and equip.visible and is_zero_approx(equip._rope_hold))
	_check("the empty Rope row remains focused for its explanation",
		_focused(rig) == rope_row)
	await rig.capture("eq_07_rope_empty.png")

	# Signal-driven stock repaint, including the live count in the detail card.
	Game.add_escape_ropes(2)
	await rig.wait_frames(4)
	equip_blob = " ".join(_all_text(equip)).to_upper()
	_check("Rope stock repainted live (2 / %d)" % K.ESCAPE_ROPE_STACK,
		equip_blob.contains("2 / %d" % K.ESCAPE_ROPE_STACK))
	_check("the Rope detail says counted, no-gold, interruptible and not refunded",
		equip_blob.contains("CONSUMED WHEN THE WORLD CHANNEL BEGINS")
		and equip_blob.contains("COSTS NO GOLD")
		and equip_blob.contains("CAN BE INTERRUPTED")
		and equip_blob.contains("NOT RETURNED"))

	# Use a real EscapeRope in this menu harness. It consumes on begin(), after
	# Equipment emits use and PauseMenu has closed.
	var real_rope := EscapeRope.new()
	real_rope.name = "DirectorEscapeRope"
	rig.scene().add_child.call_deferred(real_rope)
	await rig.wait_frames(4)
	var gold_before := Game.gold
	_rope_fired = false
	Bus.escape_rope_used.connect(_on_rope_fired)

	# A and a short Y tap are both harmless.
	await _key(rig, KEY_ENTER, 6)
	await rig.hold_seconds([&"ui_hold"], 0.08)
	await rig.wait_frames(4)
	_check("confirm and a short hold do not use a stocked Rope",
		menu.is_open and Game.escape_ropes == 2 and not real_rope.active())

	Input.action_press(&"ui_hold")
	for _i in 120:
		await rig.wait_frames(1)
		if equip._rope_hold >= MenuEquipPanel.ROPE_HOLD * 0.45:
			break
	_check("the stocked hold visibly fills (%.2f)" % equip._rope_hold,
		equip._rope_hold > 0.0)
	await rig.capture("eq_08_rope_mid_hold.png")
	for _i in 180:
		if not menu.is_open:
			break
		await rig.wait_frames(1)
	Input.action_release(&"ui_hold")
	await rig.wait_frames(6)
	Bus.escape_rope_used.disconnect(_on_rope_fired)

	_check("the stocked hold emitted use and closed the whole menu",
		_rope_fired and not menu.is_open)
	_check("the real EscapeRope consumed exactly one at channel start",
		real_rope.active() and Game.escape_ropes == 1)
	_check("the real Rope channel charged no gold", Game.gold == gold_before)
	real_rope.cancel()
	Run.in_dungeon = false

	# Reopen Inventory directly for its one-press Back contract below.
	menu.open_pouch()
	await rig.wait_frames(8)

	# --- Back ----------------------------------------------------------------
	# `open_pouch` goes through `_open_onto`, which CLEARS the stack: the pouch
	# reached in one press (I) has nothing underneath it, so Escape leaves outright
	# rather than surfacing onto a root the player never went through
	# (`PauseMenu._open_onto`, commit bb3fe8d). This beat asserted the old
	# behaviour and had been failing since that landed.
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape left outright from a pouch opened in one press",
		not menu.is_open)

	# And the two-press route still backs out one level, which is the half of the
	# rule the assertion above cannot see.
	menu.open()
	await rig.wait_frames(8)
	await _nav_to_button(rig, "Inventory")
	await _key(rig, KEY_ENTER, 12)
	_check("...but from the root it is still a level to back out of", pouch.visible)
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape backed out onto the root, it did not close the menu",
		menu.is_open and not pouch.visible)

	print("EQUIP %d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		print("EQUIP FAIL %d assertion(s)" % _fail)


# --- Keyboard-only navigation -----------------------------------------------

func _key(rig, code: int, settle: int = 6) -> void:
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


func _focused(rig) -> Control:
	return rig.root.gui_get_focus_owner()


## Walk DOWN until the named slot has focus. Slots are named Slot_<set>_<hand>.
func _nav_to_slot(rig, node_name: String) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c != null and c.name == node_name:
			return
		await _key(rig, KEY_DOWN if i % 2 == 0 else KEY_RIGHT, 3)
	_check("could reach slot '%s' by keyboard" % node_name, false)


func _nav_to_button(rig, label: String) -> void:
	for i in NAV_LIMIT:
		var c := _focused(rig)
		if c is Button and UiKit.label_of(c as Button) == label:
			return
		await _key(rig, KEY_DOWN, 3)
	_check("could reach button '%s' by keyboard" % label, false)


func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var label := root as Label
	if label != null and not label.text.strip_edges().is_empty():
		out.append(label.text)
	for child in root.get_children():
		out.append_array(_all_text(child))
	return out


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("FAIL %s" % what)
