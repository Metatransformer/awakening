extends RefCounted
## M1, "Gates and gear" (docs/SCOPE.md §3): the hero starts with nothing ranged,
## the smith does not offer ladders for weapons that do not exist yet, and a
## locked door says which item it wants by name.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_gate_test.tscn \
##     --director=res://tools/directors/gate_locks.gd \
##     --out=/tmp/gates/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  A fresh `Game` owns the sword and the shield. No bow, no hookshot, no
##      arrows -- and `armament_owned(&"arrow")` says no too, because arrows
##      follow the bow.
##   B  The smith's counter has no `string` row, no `chain` row and no arrow row.
##      Photographed, because "the row is absent" is a claim about a screen.
##   C  A door keyed to the bow refuses, and the refusal NAMES THE BOW on the
##      HUD. Not "LOCKED". Photographed from the game camera, at the distance a
##      player stands at, with the hero in frame.
##   D  `Game.grant(&"bow")` grows the counter by exactly the bow's two lines,
##      and the same door now opens -- captured mid-swing and open.
##   E  The second door, keyed to the hookshot, is still shut and wearing a
##      different mark. One row in `LockedDoor.SIGILS` is the whole difference,
##      and that is the M6 acceptance test arriving four milestones early.
##
## C and D are the ones that matter and they are checked off `Hud._prompt` --
## what got DRAWN -- rather than off the door's own `prompt` field. A door whose
## refusal is correct in a member variable and never reaches the screen is
## exactly the bug this is here to catch, and it is invisible to any assertion
## made on the prop.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/gates/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# The proving ground ships four authored `RefCam`s for lookdev, one of them
	# `current`. Whichever of those and the GameCamera enters the tree last wins,
	# which is not a thing to leave to node order when the whole claim in C is
	# "photographed from the GAME camera at playing distance".
	var cam := _game_camera(rig)
	if cam == null:
		print("GATE FAIL there is no GameCamera in the scene")
		return
	cam.make_current()
	await rig.wait_frames(20)

	_fresh_kit()
	await _counter(rig, false)
	var bow_door: Node = _door(rig, ^"BowDoor")
	var hook_door: Node = _door(rig, ^"HookDoor")
	if bow_door == null or hook_door == null:
		print("GATE FAIL the fixture is missing a door")
		return

	await _refuses(rig, bow_door)
	Game.grant(&"bow")
	await rig.wait_frames(10)
	await _counter(rig, true)
	await _opens(rig, bow_door)
	await _still_locked(rig, hook_door)

	if _fails == 0:
		print("GATE OK")
	else:
		print("GATE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("GATE ok %s" % label)
	else:
		_fails += 1
		print("GATE FAIL %s" % label)


# --- A. What a fresh hero owns ----------------------------------------------

## `reset()` rather than trusting the boot state, because `reset()` is the one
## thing in the project that still means "a brand new game" and the claim is
## about a brand new game. It also proves the two are the same now: with
## STARTER_KIT emptied there is nothing `_ready` hands over that `reset` takes
## away, which is precisely what was NOT true while the kit existed.
func _fresh_kit() -> void:
	Game.reset()
	print("GATE fresh items=%s arrows=%d" % [Game.items, Game.arrows])
	_ck("A0 the starter kit is empty", Game.STARTER_KIT.is_empty())
	_ck("A1 he owns no bow", not Game.has(&"bow"))
	_ck("A2 he owns no hookshot", not Game.has(&"hookshot"))
	_ck("A3 he has no arrows (%d)" % Game.arrows, Game.arrows == 0)
	_ck("A4 the sword is his anyway", Game.armament_owned(&"sword"))
	_ck("A5 so is the shield", Game.armament_owned(&"shield"))
	# The one that would slip through: arrows hang off the bow, so an empty
	# quiver AND an unowned bow have to agree that the left hand cannot hold them.
	_ck("A6 arrows are not a loadout he can pick",
		not Game.armament_owned(&"arrow"))


# --- B and D. The smith's counter -------------------------------------------

## Open the real screen, not just `ShopDb.lines()`. The claim is that the rows
## are ABSENT, and absence is only visible on the thing that draws rows -- a
## filter that returned the right array while `TradeScreen` cached an older one
## would pass every assertion made against the array.
func _counter(rig, owns_bow: bool) -> void:
	var tag := "after" if owns_bow else "before"
	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.BUY, "SMITH", ShopDb)
	await rig.wait_frames(16)

	var ids: Array[StringName] = []
	for r in screen._rows:
		if r.get("kind") == &"buy":
			ids.append(r["line"]["id"])
	print("GATE counter(%s) rows=%s" % [tag, ids])

	if owns_bow:
		_ck("D0 the bow grew the string ladder", ids.has(&"string"))
		_ck("D1 and the arrow line with it", ids.has(&"arrows"))
		_ck("D2 the chain is STILL hidden -- one grant, one item",
			not ids.has(&"chain"))
		_ck("D3 the counter is seven lines now (%d)" % ids.size(), ids.size() == 7)
	else:
		_ck("B0 no string ladder for a bow he has not found",
			not ids.has(&"string"))
		_ck("B1 no chain ladder either", not ids.has(&"chain"))
		_ck("B2 and no arrows to buy for it", not ids.has(&"arrows"))
		# The rest of the board must be untouched. A filter that hid three lines
		# by hiding everything would pass all three checks above.
		_ck("B3 the five ungated lines are all there (%d)" % ids.size(),
			ids.size() == 5 and ids.has(&"edge") and ids.has(&"plate")
			and ids.has(&"guard") and ids.has(&"bag_slot") and ids.has(&"heart"))
		_ck("B4 ShopDb agrees the bow's lines are not stocked",
			not ShopDb.stocked(&"string") and not ShopDb.stocked(&"arrows"))

	await rig.capture(out.path_join("g_%s_counter_%s.png" % [
		"04" if owns_bow else "01", tag]))

	screen.close()
	# Wait for it to be GONE, not for a fixed count. The trade screen holds
	# `Prompt.block` for its whole life, so a screen still closing means the door
	# beats below find `Prompt.focus` null and report a gate bug they did not
	# cause -- mvp_loop.gd and forge_loop.gd both learned this the expensive way.
	for _i in 60:
		if not is_instance_valid(screen):
			break
		await rig.wait_frames(2)
	_ck("%s the smith's screen closed" % ("D4" if owns_bow else "B5"),
		not is_instance_valid(screen))
	await rig.wait_frames(8)


# --- C. The refusal ----------------------------------------------------------

func _refuses(rig, door) -> void:
	await _walk_up_to(rig, door)
	_ck("C0 the door owns the interact button", Prompt.focus == door)
	if Prompt.focus != door:
		return

	# What the HUD actually drew. `Hud._prompt` is the string on screen; the
	# door's own `prompt` field is only an input to it.
	var said: String = Hud._prompt
	print("GATE locked prompt=\"%s\"" % said)
	_ck("C1 the refusal names the bow (\"%s\")" % said, said.contains("BOW"))
	_ck("C2 and does not just say LOCKED", not said.contains("LOCKED"))
	# No keycap on a refusal: there is no verb, so "E TO NEEDS THE BOW" would be
	# telling the player to press a button that does nothing.
	_ck("C3 it is a statement, not a button prompt", not said.contains(" TO "))
	_ck("C4 the door is shut", not door.is_open())
	await rig.capture(out.path_join("g_02_locked.png"))

	# Press it anyway. A refusal the player cannot provoke is a refusal nobody
	# reads, and pressing is how you find out whether the door is really gated or
	# merely mislabelled.
	await rig.tap(["interact"])
	await rig.wait_frames(6)
	await rig.capture(out.path_join("g_03_refused.png"))
	await rig.wait_frames(24)
	_ck("C5 pressing it opened nothing", not door.is_open())
	_ck("C6 and wrote no flag", not Game.flag(door.flag_id()))


# --- D and E. The open -------------------------------------------------------

func _opens(rig, door) -> void:
	await _walk_up_to(rig, door)
	var said: String = Hud._prompt
	print("GATE unlocked prompt=\"%s\"" % said)
	_ck("D5 the prompt is the verb now (\"%s\")" % said, said.contains("OPEN"))
	_ck("D6 and has stopped naming the bow", not said.contains("BOW"))

	var announced: Array[StringName] = []
	door.opened.connect(func(where: StringName) -> void: announced.append(where))

	await rig.tap(["interact"])
	# Mid-swing, because the whole claim about the open is that it is AUTHORED --
	# a door that teleported to its end pose would photograph identically at the
	# other two shutter times. Which is exactly what the first run of this beat
	# produced, so the angle is now MEASURED rather than assumed: a leaf that is
	# already at its end stop 0.25 s after the press is a snap wearing a tween.
	# NINE frames, for a tween that takes 0.85 s. The rig does not run at 60 Hz --
	# this scene renders at roughly 22, so a frame count here buys about 45 ms of
	# tween, not 17, and the first version of this beat waited 24 frames and
	# photographed a door that had finished opening a third of a second earlier.
	await rig.wait_frames(9)
	var leaf: Node3D = door.get_node("PivotR")
	var mid := absf(rad_to_deg(leaf.rotation.y))
	print("GATE mid-swing leaf=%.1f deg" % mid)
	_ck("D6b the leaves are genuinely mid-swing (%.1f deg)" % mid,
		mid > 4.0 and mid < 48.0)
	await rig.capture(out.path_join("g_05_swinging.png"))
	await rig.wait_frames(100)

	_ck("D7 the door opened", door.is_open())
	_ck("D8 it told the placer where it goes (%s)" % [announced],
		announced.size() == 1 and announced[0] == &"cistern_shortcut")
	_ck("D9 it wrote its one-way flag (%s)" % door.flag_id(),
		Game.flag(door.flag_id()))
	_ck("D10 and stopped offering itself", not door.enabled)
	await rig.capture(out.path_join("g_06_open.png"))

	# A door that stays open has to stay open. Re-activating it must not replay
	# the swing, and the flag is what a re-entered floor reads.
	door.activate(rig.get_nodes_in_group(&"player")[0])
	await rig.wait_frames(10)
	_ck("D11 activating an open door does nothing", door.is_open())


func _still_locked(rig, door) -> void:
	await _walk_up_to(rig, door)
	var said: String = Hud._prompt
	print("GATE second door prompt=\"%s\"" % said)
	_ck("E0 the hookshot door is still shut", not door.is_open())
	_ck("E1 and names ITS item, not the bow's (\"%s\")" % said,
		said.contains("HOOKSHOT"))
	_ck("E2 the two doors do not share a flag",
		door.flag_id() != StringName("door_open_cistern_shortcut"))
	# The mark and its hue come out of one dictionary row. If this ever reads the
	# same as the bow's, the table stopped doing the work and something branched.
	# Called through the door itself rather than through the `LockedDoor` class
	# name. A director is loaded at runtime off the global class cache, and a
	# class_name added in the same change as its director is not in that cache
	# until the project is re-imported -- so naming it here is a parse error that
	# takes the whole run down before its first frame. The handle always works.
	var mark: Dictionary = door.sigil_of(&"hookshot")
	var bow_mark: Dictionary = door.sigil_of(&"bow")
	print("GATE sigils hookshot=%s bow=%s" % [mark, bow_mark])
	_ck("E3 the two sigils differ in shape and hue",
		mark["shape"] != bow_mark["shape"] and mark["hue"] != bow_mark["hue"])
	await rig.capture(out.path_join("g_07_hookshot.png"))


# --- Helpers -----------------------------------------------------------------

## Stand the hero where a player would stand: a stride and a half out from the
## leaves, facing them, with the camera settled behind him. Teleported rather
## than walked -- pathing synthetic input across a chamber is its own project and
## what is under test is the gate, not the locomotion (forge_loop.gd's
## `_stand_at` makes the same trade for the same reason).
##
## `facing_yaw` as well as `rotation.y`: the hero turns toward his own heading
## every frame, so setting only the node is undone before the shutter opens
## (docs/CONTRACT.md §2.5 -- facing is measured, not derived).
func _walk_up_to(rig, door) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	var at: Vector3 = door.global_position + Vector3(0.0, 0.05, 1.9)
	hero.global_position = at
	var to := K.flat(door.global_position - at)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	# Snap the boom behind him instead of letting it swing round over the next
	# second -- a capture taken during that swing is a capture of the camera, not
	# of the door.
	Bus.camera_recenter.emit()
	# Wait for THIS door to own the button rather than for "something" to: the
	# hero has just teleported out of the other door's trigger and the exit takes
	# a physics frame or two to register, during which `Prompt.focus` is still
	# the door he left. A `focus != null` wait breaks instantly on the wrong one.
	for _i in 90:
		if Prompt.focus == door:
			break
		await rig.wait_frames(2)
	await rig.wait_frames(30)


func _door(rig, path: NodePath) -> Node:
	return rig.scene().get_node_or_null(path)


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
