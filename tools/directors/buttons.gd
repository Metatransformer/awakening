extends RefCounted
## Can you get your sword back?
##
## Drawing an item here is STICKY — a D-pad press puts the hookshot in his hand
## and it stays there while you walk around aiming it, which is not what OOT's
## momentary C-buttons do. That is a deliberate trade (you can aim on the move),
## and it buys one specific failure: a mode you cannot leave. "I select the
## hookshot and then I want my sword back" is the whole reason this file exists.
##
## The claims:
##   1. A D-pad press draws the item, and it is still drawn a couple of seconds
##      and a walk later. Sticky is the feature, not an accident.
##   2. `use_item` fires what is drawn. It is the item's button.
##   3. `attack` — the sword — puts the item away AND swings, on the SAME press.
##      Not "the next press swings": the press that cancels must also land the
##      blow, or the escape hatch costs a beat in the fight it is needed in.
##   4. With the sword out and nothing locked, `use_item` is silent. It is not a
##      second attack button; the lunge is what it becomes under a lock, and
##      p4_lunge.gd measures that in metres.
##
## Every beat is photographed. "The hookshot is out" is a claim about his hands.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/buttons.gd --out=/tmp/btn/x.png

var out := ""
var fails := 0
var _hits: Array[int] = []


func run(rig) -> void:
	out = rig.arg("out", "/tmp/btn/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var combat: Node = hero.get(&"combat")
	if combat == null:
		_fail("no HeroCombat on the Hero")
		return
	var post: Node = rig.scene().get_node_or_null(^"PostA")
	if post == null:
		_fail("no PostA to swing at")
		return
	post.connect(&"struck", func(amount: int, _from: Vector3) -> void:
		_hits.append(amount))

	# In reach and facing it, placed rather than walked — a director measuring
	# the buttons must not also be measuring the pathing (see p4_charge.gd).
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5).
	var post_pos: Vector3 = (post as Node3D).global_position
	hero.global_position = post_pos + Vector3(0.0, 0.05, 1.1)
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(30)

	_check("he starts with the sword (right hand holds %s)"
		% Game.armament(Game.HAND_RIGHT), String(combat.get(&"equipped")) == "")
	await rig.capture(out.path_join("b_00_sword.png"))

	# --- 1. the draw is sticky ----------------------------------------------
	# dpad up. The starter kit auto-binds the hookshot to the second C slot
	# (game_state.gd `grant`), which is `item_up`.
	await rig.tap(["item_up"])
	await rig.wait_frames(24)
	_check("dpad up drew the hookshot (%s)" % Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "hookshot")
	_check("the camera went over the shoulder", bool(hero.call(&"aiming")))
	await rig.capture(out.path_join("b_01_drawn.png"))

	# Two seconds of standing there and a walk. A mode that quietly expires is
	# as bad as one you cannot leave, and both read identically in one frame.
	await rig.wait_seconds(2.0)
	await rig.hold(["move_left"], 30)
	await rig.wait_frames(20)
	_check("it is still drawn after 2 s and a walk (%s)"
		% Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "hookshot")
	await rig.capture(out.path_join("b_02_still_drawn.png"))

	# --- 2. use_item is HELD, and the release is what fires -------------------
	# Aimed at the wall rather than the post: what is being checked is that the
	# button reaches the item at all. Where the chain GOES is ranged_kit.gd's.
	#
	# The hold half is the bug this beat grew for. The trigger used to fire on the
	# press, so pulling RT to bring the pistol up and line up a ring sent the chain
	# out before the stick had moved — you could not aim the thing you were aiming.
	# A tap alone cannot tell the two apart, because a tap presses AND releases.
	await rig.wait_frames(1)
	Input.action_press(&"use_item")
	var fired_while_held := false
	for _i in 60:
		await rig.wait_frames(1)
		if bool(hero.call(&"hooking")):
			fired_while_held = true
			break
	_check("holding use_item did not fire the chain", not fired_while_held)
	_check("holding it brought the hookshot up instead (stance=%s)"
		% hero.call(&"aim_item"), String(hero.call(&"aim_item")) == "hookshot")
	await rig.capture(out.path_join("b_02b_braced.png"))

	Input.action_release(&"use_item")
	var fired := false
	for _i in 30:
		await rig.wait_frames(1)
		if bool(hero.call(&"hooking")):
			fired = true
			break
	_check("releasing use_item fired the hookshot", fired)
	await rig.capture(out.path_join("b_03_fired.png"))
	# Let the pull finish and put him back on the post.
	for _i in 180:
		if not bool(hero.call(&"hooking")):
			break
		await rig.wait_frames(1)
	await rig.wait_frames(30)
	# And he lowers it. The item is still in his hand — that is the sticky draw
	# above — but the BRACE is over, because the brace belongs to the trigger.
	_check("he came out of the brace after the shot (stance=%s)"
		% hero.call(&"aim_item"), String(hero.call(&"aim_item")) == "")
	_check("the hookshot is still in his hand (%s)"
		% Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "hookshot")
	hero.global_position = post_pos + Vector3(0.0, 0.05, 1.1)
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(30)

	# --- 3. attack takes the sword back AND swings ---------------------------
	_check("the hookshot survived the pull and is still in his hand",
		String(combat.get(&"equipped")) == "hookshot")
	var mark := _hits.size()
	await rig.tap(["attack"])
	# Checked on the frame after the press, before waiting for the blow: the
	# claim is that the stow happens on the SAME press, and a check made after
	# a 30-frame wait cannot tell that from a stow that took half a second.
	await rig.wait_frames(2)
	var stowed := String(combat.get(&"equipped")) == ""
	_check("that press put the hookshot away (right hand holds %s)"
		% Game.armament(Game.HAND_RIGHT), stowed)
	var landed := 0
	for _i in 90:
		await rig.wait_frames(1)
		if _hits.size() > mark:
			landed = _hits[mark]
			break
	_check("the same press also landed a sword blow (%d damage)" % landed, landed > 0)
	await rig.capture(out.path_join("b_04_sword_back.png"))

	# --- 4. use_item with the sword out and no lock is silent ----------------
	await rig.wait_seconds(1.4)
	_check("nothing is locked", hero.call(&"lock_target") == null)
	mark = _hits.size()
	var where: Vector3 = hero.global_position
	await rig.tap(["use_item"])
	await rig.wait_seconds(1.2)
	_check("use_item with the sword out and no lock swung nothing (%d blow(s))"
		% (_hits.size() - mark), _hits.size() == mark)
	_check("...and did not move him (%.2f m)"
		% where.distance_to(hero.global_position),
		where.distance_to(hero.global_position) < 0.3)
	await rig.capture(out.path_join("b_05_silent.png"))

	print("BUTTONS done, %d failure(s)" % fails)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("BUTTONS ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("BUTTONS FAIL %s" % what)
