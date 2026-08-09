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

const NAV_LIMIT := 20

var _pass := 0
var _fail := 0


func run(rig) -> void:
	# The autoload, not a scene-local instance. There is exactly one PauseMenu in
	# the project now; a harness that instanced its own is how this project once
	# ended up with a menu that existed only in its own test scene.
	var menu: PauseMenu = Menu
	var equip: MenuEquipPanel = menu.get_node("Root/Screens/EquipScreen")

	# A fresh Game owns nothing, which is the state the ownership gate is for.
	# The screen has to be honest about it BEFORE anything is granted.
	Game.reset()
	await rig.wait_frames(4)

	await _nav_to_button(rig, "Equipment")
	await _key(rig, KEY_ENTER, 12)
	_check("the items screen is showing", equip.visible)
	_check("focus landed inside it, not on nothing", _focused(rig) != null)
	_check("a new game has three unbound item buttons",
		Game.quick(0) == &"" and Game.quick(1) == &"" and Game.quick(2) == &"")
	await rig.capture("eq_00_unowned.png")

	# --- Binding refuses what you have not found -----------------------------
	# Focus opens on the ← item button. Mash confirm: owning nothing bindable,
	# the only thing in the pool is the empty binding, so it must stay unbound
	# -- five times, not just once.
	for i in 5:
		await _key(rig, KEY_ENTER, 3)
	_check("an unowned item cannot be bound to a button (still %s)"
		% ("unbound" if Game.quick(Game.QUICK_LEFT) == &"" else Game.quick(Game.QUICK_LEFT)),
		Game.quick(Game.QUICK_LEFT) == &"")
	await rig.capture("eq_01_refused.png")

	# --- Finding the bow binds it, without anyone opening a menu -------------
	Game.grant(&"bow")
	Game.add_arrows(18)
	await rig.wait_frames(6)
	_check("finding the bow bound it to the first free button (%s)"
		% Game.quick(Game.QUICK_LEFT), Game.quick(Game.QUICK_LEFT) == &"bow")
	Game.grant(&"hookshot")
	await rig.wait_frames(4)
	_check("finding the hookshot took the NEXT button, it did not overwrite (%s)"
		% Game.quick(Game.QUICK_UP), Game.quick(Game.QUICK_UP) == &"hookshot")
	equip.refresh()
	await rig.wait_frames(4)
	await rig.capture("eq_02_owned.png")

	# --- Pressing a bound button draws it, and puts it away ------------------
	Game.use_quick(Game.QUICK_LEFT)
	await rig.wait_frames(4)
	_check("the ← button drew the bow (right hand is %s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"bow")
	Game.use_quick(Game.QUICK_LEFT)
	await rig.wait_frames(4)
	_check("pressing it again put the bow away (right hand is %s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"sword")

	# One item, one button: binding the bow onto ↑ must take it OFF ←.
	Game.bind_quick(Game.QUICK_UP, &"bow")
	_check("binding an item to a second button moved it rather than cloning it",
		Game.quick(Game.QUICK_UP) == &"bow" and Game.quick(Game.QUICK_LEFT) == &"")
	Game.bind_quick(Game.QUICK_LEFT, &"bow")
	Game.bind_quick(Game.QUICK_UP, &"hookshot")
	equip.refresh()
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

	# --- Back ----------------------------------------------------------------
	await _key(rig, KEY_ESCAPE, 12)
	_check("Escape backed out to the root screen, it did not close the menu",
		menu.is_open and not equip.visible)

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
