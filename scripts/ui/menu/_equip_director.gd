extends RefCounted
## Director for tools/shoot.gd (docs/CONTRACT.md §9). Drives the EQUIPMENT
## screen with nothing but injected keyboard events and photographs every state
## worth arguing about.
##
##   godot --path . -s tools/shoot.gd -- \
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
	Game.fill_bottle(&"heart_draught")
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

	# --- Swap Set ------------------------------------------------------------
	await _nav_to_button(rig, "Swap Set")
	await _key(rig, KEY_ENTER, 12)
	_check("Swap Set changed the live loadout (%d -> %d)" % [live_before, Game.loadout_set],
		Game.loadout_set != live_before)
	await rig.capture("eq_05_swapped.png")

	# --- The way out, which is on the POUCH now ------------------------------
	# It used to be on this screen and it is not any more: the bag's worth, the
	# purse and the fee are one decision, so they are on one screen (pouch_panel
	# owns all three, hud.gd draws none of them). The assertions did not move
	# with it for one commit, which is exactly how a director ends up proving a
	# button that is no longer there.
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape backed out of Equipment to the root", not equip.visible)
	await _nav_to_button(rig, "Pouch")
	await _key(rig, KEY_ENTER, 12)
	_check("the pouch screen is showing", pouch.visible)

	# The rope has to be REACHABLE by keyboard alone, like everything else on
	# this screen -- it is the only control in the menu that ends a run, and a
	# pad user who cannot get focus onto it cannot leave the dungeon at all.
	await _nav_to_button(rig, "◈  Escape Rope")
	_check("the Escape Rope is reachable by keyboard",
		_focused(rig) != null and (_focused(rig) as Button).text.ends_with("Escape Rope"))
	await rig.capture("eq_06_rope.png")

	# This scene is not a dungeon. Using it must refuse, and must NOT close the
	# menu -- "the menu ate my button press" is the failure mode the notice and
	# this assertion exist for.
	await _key(rig, KEY_ENTER, 10)
	_check("using the rope outside a run refused, and the menu stayed open",
		menu.is_open and pouch.visible and not Run.in_dungeon)

	# Underground, the row has to name the price. `in_dungeon` is set directly
	# rather than by running Run.enter(): this is a menu test scene with no
	# dungeon in it, and the rope reads exactly two facts -- are you in a run,
	# and can you pay.
	Run.in_dungeon = true
	pouch.refresh()
	await rig.wait_frames(4)
	_check("in a run the rope names the fee (%d gold)" % Run.extract_cost(),
		Run.extract_cost() >= 15)
	await rig.capture("eq_07_rope_fee.png")

	# Too poor to leave. This must refuse and SAY SO, not silently do nothing:
	# being unable to afford the way out is a legible failure state by design
	# (METAGAME §5), and a dead button is not legible.
	Game.spend_gold(Game.gold)
	pouch.refresh()
	await rig.wait_frames(4)
	await _key(rig, KEY_ENTER, 10)
	_check("too poor to leave: refused, still in the run, menu still open",
		Run.in_dungeon and menu.is_open and pouch.visible)
	await rig.capture("eq_08_rope_broke.png")
	Run.in_dungeon = false

	# --- Back ----------------------------------------------------------------
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape backed out to the root screen, it did not close the menu",
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
		if c is Button and (c as Button).text == label:
			return
		await _key(rig, KEY_DOWN, 3)
	_check("could reach button '%s' by keyboard" % label, false)


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("FAIL %s" % what)
