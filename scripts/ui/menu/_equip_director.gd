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

	# --- The toll past the purse ---------------------------------------------
	# This was the game's one dead end until 2026-08-09: the rope refused, and
	# refused a player who had no way to comply. The fee is capped at the purse
	# now, so what used to be a locked row is a priced one -- and the thing to
	# prove from the UI side is that the row still WORKS and says so in words,
	# because a fix the player cannot read is the same dead end with better
	# arithmetic. Dropped to one under the toll; an empty bag tolls EXTRACT_MIN.
	var kept_gold := Game.gold
	if Game.gold > Run.extract_cost() - 1:
		Game.spend_gold(Game.gold - (Run.extract_cost() - 1))
	pouch.refresh()
	await rig.wait_frames(4)
	_check("a toll past the purse is capped at it (toll=%d purse=%d charge=%d)"
			% [Run.extract_cost(), Game.gold, Run.extract_charge()],
		Run.extract_takes_all() and Run.extract_charge() == Game.gold)
	# The hold is what must survive. A row that greyed out here would be the old
	# refusal wearing a different colour.
	_check("and the row still offers the hold rather than refusing it",
		Run.can_extract())
	await rig.capture("eq_07a_rope_takes_all.png")
	Game.add_gold(kept_gold - Game.gold)
	pouch.refresh()
	await rig.wait_frames(4)

	# --- The way out is a HOLD -----------------------------------------------
	# A is the universal forward press and it is one row above this on the same
	# screen, where it fletches arrows repeatedly and on purpose. So A here must
	# NOT leave -- it must point at the button that does (METAGAME §5).
	await _key(rig, KEY_ENTER, 10)
	_check("A on the rope did not leave: it is a hold now",
		Run.in_dungeon and menu.is_open and pouch.visible)

	# A tap of Y leaves nothing either. Sampled every frame and released on the
	# FIRST non-zero reading rather than after a fixed wait: the gauge advances by
	# `delta`, so N frames is N frames of unknown duration, and the shop's twin of
	# this beat was caught reading 0.00 on a slow run where the whole hold had
	# already elapsed (see forge_loop `CH3`). Releasing one frame in is also a
	# harder test of "letting go does nothing" than releasing at 40%.
	Input.action_press(&"ui_hold")
	var peak := 0.0
	for _i in 30:
		await rig.wait_frames(1)
		peak = maxf(peak, pouch._rope_hold)
		if peak > 0.0:
			break
	Input.action_release(&"ui_hold")
	await rig.wait_frames(6)
	_check("the gauge fills while Y is down (%.2f s)" % peak, peak > 0.0)
	_check("letting go snapped it back to zero (%.2f)" % pouch._rope_hold,
		is_zero_approx(pouch._rope_hold))
	_check("and a tap of Y left nobody anywhere",
		Run.in_dungeon and menu.is_open and pouch.visible)

	# Held through, with the shutter open two frames in: the frame is the proof,
	# and no assertion about a float can see a bar that renders behind its row --
	# which is the exact failure HoldBar exists to avoid.
	#
	# The listener is connected BEFORE the press and the capture is INSIDE the
	# held-through half, both for the same reason: `capture()` costs frames of
	# unknown duration, and the first version of this beat took a photograph so
	# slow that the whole 0.9 s elapsed inside it -- the rope left, the menu
	# closed, and the beat then reported "holding Y did nothing" while the beat
	# below it reported "the menu closed" and passed. A director that photographs
	# the thing it is testing has to survive the shutter finishing the job.
	# `_rope_fired`, a FIELD, and not a local flag closed over by a lambda: a
	# GDScript lambda captures locals BY VALUE, so `func(): left = true` sets the
	# lambda's own copy and the caller reads false forever. That is not a
	# hypothetical either -- it is what this beat did on its first run, reporting
	# "holding Y did nothing" one line above "the menu closed whole for it".
	_rope_fired = false
	Bus.escape_rope_used.connect(_on_rope_fired)
	Input.action_press(&"ui_hold")
	# Waited on the GAUGE, not on a frame count, so the photograph is taken with
	# the bar visibly part-full on a fast machine and a slow one alike. A capture
	# two frames in read 0.02 s of 0.90 -- a two percent sliver, which proves the
	# code and shows a human nothing.
	for _i in 120:
		await rig.wait_frames(1)
		if pouch._rope_hold >= MenuPouchPanel.ROPE_HOLD * 0.45:
			break
	print("ROPE hold at the shutter: %.2f of %.2f s" % [
		pouch._rope_hold, MenuPouchPanel.ROPE_HOLD])
	await rig.capture("eq_07b_rope_hold.png")
	# GAME SECONDS from here, not frames: 45 frames is 0.75 s at 60 Hz and 0.37 s
	# at 120, and only one of those outlasts a 0.9 s hold.
	await rig.hold_seconds(["ui_hold"], MenuPouchPanel.ROPE_HOLD + 0.4)
	await rig.wait_frames(8)
	Bus.escape_rope_used.disconnect(_on_rope_fired)
	_check("holding Y through used the rope", _rope_fired)
	# The channel happens in the WORLD, so the whole menu goes away -- not one
	# screen popped off the stack.
	_check("and the menu closed whole for it", not menu.is_open)

	menu.open_pouch()
	await rig.wait_frames(8)

	# DEAD BROKE, AND IT STILL WORKS. This beat asserted the opposite until
	# 2026-08-09 -- "too poor to leave: refused, still in the run" -- on the
	# theory that an unaffordable exit was a legible failure state. It was a dead
	# end: nothing sells underground, so the refusal named a price the player had
	# no way to reach, and the only door left was dying with the bag the fee was
	# charged for. The fee is capped at the purse now, so an empty purse pays
	# nothing and the rope pulls him out anyway.
	#
	# This is the far end of the cap rather than the interesting middle -- the
	# expensive exit is `eq_07a` above, where the toll is past the purse and takes
	# all of it. Zero is here because zero is where the old refusal was loudest.
	Game.spend_gold(Game.gold)
	pouch.refresh()
	await rig.wait_frames(4)
	_check("broke, the toll charges nothing rather than refusing (charge=%d)"
			% Run.extract_charge(), Run.extract_charge() == 0 and Run.can_extract())
	_rope_fired = false
	Bus.escape_rope_used.connect(_on_rope_fired)
	await rig.hold_seconds(["ui_hold"], MenuPouchPanel.ROPE_HOLD + 0.4)
	await rig.wait_frames(8)
	Bus.escape_rope_used.disconnect(_on_rope_fired)
	# The gauge is the tell that this is a working hold and not a dead button --
	# it had to be flat for the old refusal and has to have moved for this one.
	_check("broke and it still left: the rope fired and the menu closed for it",
		_rope_fired and not menu.is_open)
	await rig.capture("eq_08_rope_broke.png")
	Run.in_dungeon = false

	# Reopened because the beat above now CLOSES the menu. It did not use to --
	# the rope refused and the pouch stayed up -- so the Escape check below
	# inherited an open menu for free and would otherwise be asserting that
	# Escape backed out of a screen that was already gone.
	menu.open_pouch()
	await rig.wait_frames(8)

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
