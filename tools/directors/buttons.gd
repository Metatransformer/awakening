extends RefCounted
## Can you get your sword back?
##
## Drawing an item here is STICKY — a D-pad press puts the hookshot in his hand
## and it stays there while you walk around carrying it, which is not what OOT's
## momentary C-buttons do. That is a deliberate trade (the item is on the move
## with you), and it buys one specific failure: a mode you cannot leave. "I
## select the hookshot and then I want my sword back" is the whole reason this
## file exists.
##
## THE ANSWER CHANGED and this director changed with it. It used to be `attack`:
## the light swing stowed whatever was drawn and swung on the same press, an
## escape hatch bolted to the sword button. There are no quick slots now — the
## D-pad steps a RING, and the sword is a stop on it — so the way out is ← or →,
## the same button that put the hookshot there. The old hatch had to go with the
## hatch's reason: both shoulder buttons belong to whatever is in the right hand,
## so `attack` with a bow drawn FIRES THE BOW rather than stowing it.
##
## Carrying it is not AIMING it — that is the trigger, and only for as long as
## the trigger is down (hero_ranged.gd). The two get checked separately below,
## the sticky one positively and the sight negatively, because the version of
## this file that only asked about stickiness passed happily while selecting a
## hookshot zoomed the game permanently into a sight.
##
## The claims:
##   1. D-pad → draws the item, and it is still drawn a couple of seconds and a
##      walk later. Sticky is the feature, not an accident.
##   2. `heavy` fires what is drawn, on the RELEASE. It is the item's button.
##   3. `attack` with an item drawn does NOT hand the sword back. Both shoulders
##      belong to the hand, and the hand is full.
##   4. D-pad → gets the sword back — the ring wraps, so a player who can find
##      the hookshot can find his way off it with the same finger.
##   5. Sword out, nothing locked: `attack` lands the light swing and `heavy`
##      lands the heavy. `heavy` used to be deliberately silent here, which was
##      a trigger the player stopped pulling; the light/heavy split fixed it.
##   6. X drinks the selected bottle, and it does not touch the hand.
##
## Every beat is photographed. "The hookshot is out" is a claim about his hands.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/buttons.gd --out=/tmp/btn/x.png

var out := ""
var fails := 0
var _hits: Array[int] = []


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

	# Where he spawned: open floor with room in every direction. The hookshot beat
	# below needs somewhere for the chain to GO, and the post he stands at for the
	# sword beats is 1.1 m away — a chain fired at that arrives, pulls him nowhere
	# and lets go inside two frames, which from outside is indistinguishable from
	# a button that did nothing.
	var home: Vector3 = hero.global_position

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
	# D-pad →, stepped until the hookshot is in his hand. Not one press of a known
	# direction any more — the ring's length is however many weapons he owns, so
	# the rig presses until it lands (tools/shoot.gd `draw_weapon`).
	_check("the ring reached the hookshot", await rig.draw_weapon(&"hookshot"))
	await rig.wait_frames(24)
	_check("D-pad → drew the hookshot (%s)" % Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "hookshot")
	# And it does NOT zoom. The draw is sticky; the SIGHT is not. Selecting the
	# hookshot used to drop the camera onto his shoulder and narrow the lens for
	# as long as you carried it, so this beat's own "still drawn after 2 s and a
	# walk" was a walk taken down a gun sight.
	_check("selecting it did not zoom", not bool(hero.call(&"aiming")))
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

	# --- 2. heavy is HELD, and the release is what fires -------------------
	# Aimed at the wall rather than the post: what is being checked is that the
	# button reaches the item at all. Where the chain GOES is ranged_kit.gd's.
	#
	# Put back on OPEN FLOOR first, and not on the post's mark.
	#
	# Two things conspire here and both are about the chain having somewhere to
	# go. The walk above no longer lands in the same place twice — `move_left` is
	# camera-relative, and carrying an item no longer pins the camera the way
	# aiming one does (hero_ranged.gd), so autoswing drifts the lens while he
	# walks and "left" rotates under him; it wandered about a metre between runs.
	# And the sword beats' mark is 1.1 m from a post he is facing. From either of
	# those the chain bites instantly, pulls him nowhere and lets go inside a
	# couple of frames, and a `hooking()` poll straddles the whole event and
	# reports that the release does not fire the hookshot. It fires. There was
	# nothing to fire it at. A beat about a BUTTON must not also be a measurement
	# of the room.
	#
	# The hold half is the bug this beat grew for. The trigger used to fire on the
	# press, so pulling RT to bring the pistol up and line up a ring sent the chain
	# out before the stick had moved — you could not aim the thing you were aiming.
	# A tap alone cannot tell the two apart, because a tap presses AND releases.
	hero.global_position = home
	hero.velocity = Vector3.ZERO
	await rig.wait_frames(20)

	Input.action_press(&"heavy")
	var fired_while_held := false
	for _i in 60:
		await rig.wait_frames(1)
		if bool(hero.call(&"hooking")):
			fired_while_held = true
			break
	_check("holding heavy did not fire the chain", not fired_while_held)
	_check("holding it brought the hookshot up instead (stance=%s)"
		% hero.call(&"aim_item"), String(hero.call(&"aim_item")) == "hookshot")
	_check("and the trigger is what zoomed", bool(hero.call(&"aiming")))
	await rig.capture(out.path_join("b_02b_braced.png"))

	Input.action_release(&"heavy")
	var fired := false
	# 90 frames, not 30. At 30 this beat failed roughly one run in two whenever
	# the machine had a second Godot on it, and the failure reads as "the release
	# does not fire the hookshot" — a damning, entirely false claim about the
	# button. The chain leaving is not frame-budgeted; the window has no business
	# being tight.
	for _i in 90:
		await rig.wait_frames(1)
		if bool(hero.call(&"hooking")):
			fired = true
			break
	_check("releasing heavy fired the hookshot", fired)
	await rig.capture(out.path_join("b_03_fired.png"))
	# Let the pull finish.
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

	# --- 3. attack does NOT hand the sword back ------------------------------
	# The negative half of the redesign, and the reason it is checked at all: for
	# most of this project's life `attack` WAS the escape hatch, and a reader of
	# hero_combat could still reasonably expect it to be. Both shoulder buttons
	# belong to whatever is in the right hand now, so this press goes to the
	# hookshot and the sword stays where it is.
	#
	# On open floor, deliberately. He is holding a grapple and this beat presses
	# its trigger; standing him at the post would fire a chain into it and make
	# the position, not the button, the thing under test.
	hero.global_position = home
	hero.velocity = Vector3.ZERO
	await rig.wait_frames(20)
	await rig.tap(["attack"])
	await rig.wait_frames(6)
	_check("attack with an item drawn did not stow it (%s)"
		% Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "hookshot")
	for _i in 180:
		if not bool(hero.call(&"hooking")):
			break
		await rig.wait_frames(1)
	await rig.wait_frames(20)

	# --- 4. the D-pad is the way out -----------------------------------------
	# The ring wraps, so → gets back to the sword without the player ever needing
	# to know how many weapons he owns. This is the whole answer to the question
	# in the docstring, and it is one finger.
	_check("the ring came back round to the sword",
		await rig.draw_weapon(&"sword"))
	await rig.wait_frames(20)
	_check("the sword is in his hand again (%s)" % Game.armament(Game.HAND_RIGHT),
		String(combat.get(&"equipped")) == "")
	hero.global_position = post_pos + Vector3(0.0, 0.05, 1.1)
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("b_04_sword_back.png"))

	# --- 5. both shoulders swing, and neither is silent ----------------------
	# `heavy` used to do NOTHING here: with the sword out and nothing locked it
	# was deliberately quiet, because it was the item button and there was no
	# item. A trigger that is inert four fifths of the time is a trigger the
	# player stops pulling, which is what the light/heavy split undid.
	_check("nothing is locked", hero.call(&"lock_target") == null)
	var mark := _hits.size()
	await rig.tap(["attack"])
	var light := await _wait_for_hit(rig, mark)
	_check("attack landed the light swing (%d damage)" % light, light > 0)
	await rig.capture(out.path_join("b_05_light.png"))

	await rig.wait_seconds(1.4)
	mark = _hits.size()
	var where: Vector3 = hero.global_position
	await rig.tap(["heavy"])
	var heavy := await _wait_for_hit(rig, mark)
	_check("heavy landed the heavy swing (%d damage)" % heavy, heavy > 0)
	_check("the heavy hits harder than the light (%d vs %d)" % [heavy, light],
		heavy >= light)
	# It is a swing, not a lunge: the leap belongs to a LOCK, and p4_lunge.gd
	# measures that in metres. Unlocked, his feet stay where they were.
	_check("...and unlocked it did not carry him (%.2f m)"
		% where.distance_to(hero.global_position),
		where.distance_to(hero.global_position) < 0.6)
	await rig.capture(out.path_join("b_06_heavy.png"))

	# --- 6. X drinks, and leaves the hand alone ------------------------------
	# The item button is not a hand button, and the whole reason bottles came off
	# the weapon ring is that using one must never cost you the sword.
	while Game.bottle_count() < 1:
		Game.add_bottle()
	Game.fill_bottle(&"health_draught")
	Game.damage(4)
	await rig.wait_frames(10)
	var hurt := Game.health_points
	await rig.tap(["use_item"])
	await rig.wait_frames(20)
	_check("X drank the selected bottle (%d -> %d HP)" % [hurt, Game.health_points],
		Game.health_points > hurt)
	_check("drinking left the sword in his hand (%s)"
		% Game.armament(Game.HAND_RIGHT), String(combat.get(&"equipped")) == "")
	await rig.capture(out.path_join("b_07_drank.png"))

	print("BUTTONS done, %d failure(s)" % fails)


## Wait up to 90 frames for a blow to land on the post, and answer with its
## damage. 90 rather than 30 for the same reason the chain window is 90: a swing
## landing is not frame-budgeted, and a tight window turns a busy machine into a
## damning, false claim about a button.
func _wait_for_hit(rig, mark: int) -> int:
	for _i in 90:
		await rig.wait_frames(1)
		if _hits.size() > mark:
			return _hits[mark]
	return 0


func _check(what: String, ok: bool) -> void:
	if ok:
		print("BUTTONS ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("BUTTONS FAIL %s" % what)
