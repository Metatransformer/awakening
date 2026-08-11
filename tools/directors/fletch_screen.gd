extends RefCounted
## The FLETCHING card on the POUCH screen, driven by the pad and photographed.
##
## Three states, because the row means something different in each and only a
## picture says whether the difference reads:
##
##   empty  — nothing in the bag. "0/2 Cracked Flint + 0/2 Bone Shard".
##   ready  — the recipe is covered. The row offers "+5".
##   after  — pressed. The bag is lighter, the quiver is heavier, and both
##            numbers on this screen moved without a reload.
##
## It also checks the thing a screenshot cannot: that the card sits in the D-pad
## walk. The pouch is a gamepad screen — every control has to be reachable by
## holding one direction — and a new card wedged between the grid and the rope
## is exactly the change that silently orphans the way out.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/fletch_screen.gd \
##     --out=/tmp/fletch/f.png --size=1280x720 --warmup=50

var _fails: int = 0


func _fail(msg: String) -> void:
	_fails += 1
	push_error("FLETCH FAIL %s" % msg)
	print("FLETCH FAIL %s" % msg)


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	var out: String = rig.arg("out", "/tmp/fletch/f.png").get_base_dir()
	var pouch = Menu.get_node("Root/Screens/PouchScreen")
	if pouch == null:
		_fail("no PouchScreen")
		return

	# A live run, so the bag is a bag and the escape rope has a fee to print.
	Run.enter(20190920)
	Run.bag.clear()
	Run.premium = 0
	Game.arrows = 0
	Game.add_gold(400)

	# `_menu_test.tscn` opens the menu itself in `_ready`, and `open_pouch()` is a
	# TOGGLE — called on an already-open menu it closes it, which is correct
	# behaviour for the button and photographs a dungeon wall for a director that
	# does not know it. Close first, then open onto the pouch.
	if bool(Menu.get(&"_is_open")):
		Menu.call(&"close")
		await rig.wait_frames(6)
	Menu.call(&"open_pouch")
	await rig.wait_frames(12)
	pouch.call(&"refresh")
	await rig.wait_frames(6)
	await rig.capture(out.path_join("fl_empty.png"))

	# Found by name, not by path. The pouch's chrome has unnamed MarginContainers
	# in it, so a hardcoded path is a guess about how many wrappers deep the card
	# happens to sit — and it is a guess that breaks the day someone adds padding.
	var row := pouch.find_child("Fletch", true, false) as Control
	if row == null:
		_fail("the fletching card is not on the screen")
		return

	# Fill the bag with exactly the recipe and one thing it does not want, so the
	# grid to the left is not empty and the cost line has something to be read
	# against.
	for id: StringName in Fletching.RECIPE:
		Run.collect(id, int(Fletching.RECIPE[id]))
	Run.collect(&"rot_moss", 3)
	pouch.call(&"refresh")
	await rig.wait_frames(6)
	await rig.capture(out.path_join("fl_ready.png"))

	if not Fletching.can_fletch():
		_fail("bag holds the recipe and the bench still refuses: %s"
			% Fletching.cost_line())

	# Walk the focus down from the grid the way a pad does, and make sure the
	# bench and then the escape rope are both on the road.
	var reached: Array = await _walk_down(rig, pouch)
	if not reached.has("Fletch"):
		_fail("holding DOWN from the grid never lands on the bench")
	if not reached.has("Rope"):
		_fail("the bench swallowed the walk — the way out is unreachable")
	print("FOCUS walk reached %s" % str(reached))

	var bag_before: int = Run.bag.get(&"cracked_flint", 0)
	pouch.call(&"_do_fletch")
	await rig.wait_frames(8)
	await rig.capture(out.path_join("fl_after.png"))

	if Game.arrows != Fletching.BATCH:
		_fail("pressed fletch and the quiver reads %d" % Game.arrows)
	if Run.bag.get(&"cracked_flint", 0) >= bag_before:
		_fail("pressed fletch and the bag did not get lighter")
	# The screen must have repainted itself, not waited for a reopen.
	var cost := pouch.find_child("Cost", true, false) as Label
	if cost != null:
		print("COST line now: %s" % cost.text)

	print("FLETCHCHECK fails=%d arrows=%d" % [_fails, Game.arrows])


## Grab the first cell, then hold DOWN and record every control the focus lands
## on. The pouch's promise is that one direction reaches everything; this is the
## only way to check it that does not just re-read the wiring code.
func _walk_down(rig, pouch) -> Array:
	var seen: Array = []
	pouch.call(&"focus_first")
	await rig.wait_frames(2)
	for i in 24:
		var f: Control = pouch.get_viewport().gui_get_focus_owner()
		if f == null:
			break
		if not seen.has(f.name):
			seen.append(f.name)
		var next: Control = f.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null:
			break
		next.grab_focus()
		await rig.wait_frames(1)
		# Stop once the way out is on the list. NOT once "Back" is — the footer
		# button is built without a name, so it walks past as "@Button@NN" and a
		# check on the literal never fires.
		if seen.has("Rope"):
			break
	return seen
