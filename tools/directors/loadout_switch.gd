extends RefCounted
## Does the D-pad actually change what is in the hero's hands?
##
## Prints `LOADOUT FAIL ...` on any beat that did not happen, and photographs
## both sets so "the bow is equipped" is a thing somebody saw on the model
## rather than a boolean that flipped.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/loadout_switch.gd --out=/tmp/load/x.png


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/load/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# The honest empty state, asked for out loud. `Game` hands out a [test]
	# starter kit at boot (game_state.gd STARTER_KIT) so the ranged items can be
	# exercised without playing to a chest, and everything below this line is
	# about what the hero owns BEFORE he has found anything. reset() is the one
	# thing that still means "a brand new game".
	Game.reset()

	var hero = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 4.0)
	await rig.wait_frames(12)
	var combat = hero.combat

	# Before anything is granted, the hero must be carrying nothing he has not
	# found. This one was caught by LOOKING at a frame that every assertion in
	# this file had already passed: the bow was slung across his chest from the
	# first boot, because both mounts are built at _ready and the stow mount was
	# shown whenever the item was not in hand, owned or not.
	if _visible(_stow(combat, &"bow")):
		rig.fail("LOADOUT FAIL a bow is on his back before he has found one")
	if _visible(_stow(combat, &"hookshot")):
		rig.fail("LOADOUT FAIL a hookshot is on his hip before he has found one")

	# The bow has to be OWNED before it can be cycled to -- that is the point of
	# the ownership gate, and a test that skips it tests nothing.
	Game.grant(&"bow")
	Game.add_arrows(12)
	await rig.wait_frames(4)
	if not _visible(_stow(combat, &"bow")):
		rig.fail("LOADOUT FAIL the granted bow did not appear stowed on his back")

	# --- default: the primary set --------------------------------------------
	print("LOADOUT set=%d right=%s left=%s" % [Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT)])
	if Game.armament(Game.HAND_RIGHT) != &"sword":
		rig.fail("LOADOUT FAIL primary right hand is not the sword")
	if not _visible(combat.sword):
		rig.fail("LOADOUT FAIL sword model is not shown in the primary set")
	if not _visible(combat.shield):
		rig.fail("LOADOUT FAIL shield model is not shown in the primary set")
	Bus.camera_recenter.emit()
	await rig.wait_frames(34)
	await rig.capture(out.path_join("loadout_00_primary.png"))

	# --- dpad up: the alternate set ------------------------------------------
	Game.swap_loadout()
	await rig.wait_frames(6)
	print("LOADOUT set=%d right=%s left=%s" % [Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT)])
	if Game.loadout_set != Game.ALTERNATE:
		rig.fail("LOADOUT FAIL dpad up did not reach the alternate set")
	if Game.armament(Game.HAND_RIGHT) != &"bow":
		rig.fail("LOADOUT FAIL alternate right hand is not the bow")
	if Game.armament(Game.HAND_LEFT) != &"arrow":
		rig.fail("LOADOUT FAIL alternate left hand is not arrows")
	if _visible(combat.sword):
		rig.fail("LOADOUT FAIL sword is still in hand while the bow is equipped")
	if not _visible(combat.bow):
		rig.fail("LOADOUT FAIL bow model is not in hand on the alternate set")
	if _visible(combat.shield):
		rig.fail("LOADOUT FAIL shield is still strapped on with arrows in the off hand")
	await rig.wait_frames(30)
	await rig.capture(out.path_join("loadout_01_alternate.png"))

	# --- dpad right: cycle the right hand within the set ---------------------
	Game.grant(&"hookshot")
	var before := Game.armament(Game.HAND_RIGHT)
	Game.cycle_armament(Game.HAND_RIGHT)
	await rig.wait_frames(6)
	var after := Game.armament(Game.HAND_RIGHT)
	if after == before:
		rig.fail("LOADOUT FAIL cycling the right hand changed nothing (still %s)" % before)
	else:
		print("LOADOUT ok  right hand cycled %s -> %s" % [before, after])
	await rig.wait_frames(24)
	await rig.capture(out.path_join("loadout_02_cycled.png"))

	# --- ownership gate ------------------------------------------------------
	# A fresh Game owns no bow, so the alternate set must refuse to cycle TO one.
	Game.items.erase(&"bow")
	Game.items.erase(&"hookshot")
	Game.loadout[Game.ALTERNATE][Game.HAND_RIGHT] = &"sword"
	var gated := Game.armament(Game.HAND_RIGHT)
	Game.cycle_armament(Game.HAND_RIGHT)
	if Game.armament(Game.HAND_RIGHT) != gated:
		rig.fail("LOADOUT FAIL cycled to an armament the player does not own (%s)"
			% Game.armament(Game.HAND_RIGHT))
	else:
		print("LOADOUT ok  cycling refused an unowned armament")

	# --- swap back, and check it survives a round trip -----------------------
	Game.swap_loadout()
	if Game.loadout_set != Game.PRIMARY:
		rig.fail("LOADOUT FAIL did not swap back to primary")
	else:
		print("LOADOUT ok  swapped back to primary, right=%s left=%s"
			% [Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT)])
	print("LOADOUT done")


## `visible` is per-node and these models hang off BoneAttachment sockets, so a
## parent hidden higher up would still report visible=true. is_visible_in_tree
## is the question actually being asked: can the player see it.
func _visible(n: Node3D) -> bool:
	return n != null and is_instance_valid(n) and n.is_visible_in_tree()


## The body-mounted copy of a two-mount item -- the bow on the back, the
## hookshot on the hip. `combat.bow` is only ever the in-hand one.
func _stow(combat, id: StringName) -> Node3D:
	var pair: Dictionary = combat._items.get(id, {})
	return pair.get("stow", null) as Node3D
