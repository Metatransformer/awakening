extends RefCounted
## What each button means from behind a raised shield — the whole of the remap,
## driven through real input rather than by calling the methods.
##
## THE MOVE THIS PROVES. The parry used to be `shield + attack`. It is `shield +
## A` now (`interact`), and the point of moving it was never the parry — it was
## the SWORD: while the guard rewrote what RB meant, a player behind a shield
## could not swing at the thing they were guarding against without dropping the
## shield on an earlier frame and pressing on a later one. So there are two
## halves to check and the second is the one that was actually broken:
##
##   * **A behind the guard parries** — and only behind the guard.
##   * **RB and RT behind the guard SWING**, straight through, no frame spent
##     lowering anything. This is the half the remap was for.
##   * **A behind the guard does not talk to the world.** One press cannot both
##     catch a blow and open the chest standing in it (`Prompt._guarding`).
##   * **A with the shield down still opens the chest**, which is the regression
##     the line above is one typo away from causing.
##
## EVERY BEAT GOES THROUGH `rig.press` / `rig.hold`, deliberately, and that is
## the difference between this director and `parry_dodge.gd` — which calls
## `combat._parry()` by hand because it is measuring the milliseconds between a
## press and a blow, and cannot afford the frame boundary. This one is measuring
## the BINDING. A beat here that called the method would assert nothing at all:
## the entire claim is about which button arrives where, so the button has to be
## pressed. (`rig._send` does the `InputEventAction` half as well as the action
## state — CLAUDE.md §3's `Input.action_press` row.)
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/guard_buttons.gd --out=/tmp/guard/x.png

## The hero's heading yaw for -Z. `facing_yaw` IS the heading and the heading is
## `(sin y, 0, cos y)`, so -Z is PI (`docs/CONTRACT.md` §2.5).
const FACE_MINUS_Z := PI
const HERO_AT := Vector3(0.0, 0.05, 7.4)

## Frames spent holding `shield` before the beat's real press. The guard is
## raised in `HeroCombat._physics_process`, so it needs at least one physics tick
## between the trigger going down and the button that reads `blocking` — and
## `rig.press` only guarantees a RENDER frame. Six is slack, not superstition:
## a beat that fired its press on the frame the guard came up would fail
## intermittently and read as a race in the game.
const GUARD_SETTLE := 6

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/guard/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _parry_is_on_a(rig, out)
	await _a_alone_does_not_parry(rig)
	await _rb_swings_out_of_the_block(rig, out)
	await _rt_swings_out_of_the_block(rig)
	await _guard_takes_the_button_off_the_world(rig)
	await _shield_down_still_talks(rig)

	if _fails == 0:
		print("GUARD OK -- every check passed")


# --- Beat one: A behind the guard is the parry --------------------------------

## Also the only beat with pixels, and it is carrying a second question: the
## parry's CLIP. `Swing.PARRY` maps to `Hero.clip_parry` (`ex_parry`) and fires
## the `SwingParry` one-shot, and "the parry does not seem to be animating" is a
## thing that gets said about a move whose whole visible life is 0.5 s. So the
## one-shot's own `active` flag is asserted — not a screenshot of a pose, which
## cannot tell a played clip from a held one — and the frames are captured
## across the window so the shove can be looked at.
func _parry_is_on_a(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	await rig.wait_frames(20)
	Bus.camera_recenter.emit()

	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the shield never went up -- every beat below is meaningless")
		rig.release(&"shield")
		return
	await rig.capture(out.path_join("guard_00_shield_up.png"))

	await rig.hold([&"interact"], 4)
	await rig.wait_physics_frames(1)
	var t: float = combat.get(&"_parry_t")
	if t < 0.0:
		_fail("A behind a raised shield did not parry")
	else:
		print("GUARD parry started  _parry_t=%.3f" % t)
	# The guard comes DOWN on the same tick the parry starts -- that is the price
	# of the move and `HeroCombat._parry` does it by hand rather than waiting for
	# the next `want_block` pass. Asserted here because it is the one thing about
	# the remap that could have been lost in moving the press.
	if bool(combat.get(&"blocking")):
		_fail("the shield is still up on the frame the parry started")

	# THE CLIP. `active` is the one-shot's own read-only flag, so this is the
	# animation tree answering rather than the caller asserting what it asked for.
	var tree: AnimationTree = hero.get(&"_tree")
	if tree == null:
		_fail("the hero has no AnimationTree -- the parry cannot be animating")
	else:
		var live := bool(tree.get("parameters/SwingParry/active"))
		print("GUARD parry clip  SwingParry.active=%s clip=%s"
			% [live, hero.get(&"clip_parry")])
		if not live:
			_fail("the parry fired and the SwingParry one-shot is not running --"
				+ " the clip is not hooked up")

	# Across the shove, which is 0.00-0.43 of `ex_parry` (build_anim_lib's TRIM
	# note). Four frames spread over the window, so a still body shows up as four
	# identical PNGs rather than as one ambiguous one.
	for i in 4:
		await rig.wait_frames(4)
		await rig.capture(out.path_join("guard_01_parry_%d.png" % i))

	rig.release(&"shield")
	await _reset(rig, hero)


# --- Beat two: and NOT from neutral -------------------------------------------

## The gate is the whole binding. Without it A would be a parry the player could
## throw at any moment, which is the thing `shield + attack` was at least never
## guilty of, and the button would mean two things with nothing to tell them
## apart.
func _a_alone_does_not_parry(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	if bool(combat.get(&"blocking")):
		_fail("the guard is still up going into the neutral beat")
		return

	await rig.hold([&"interact"], 4)
	await rig.wait_physics_frames(2)
	if combat.get(&"_parry_t") >= 0.0:
		_fail("A with no shield up threw a parry")
	await _reset(rig, hero)


# --- Beat three: RB out of a block is the SWORD -------------------------------

## THE BEAT THE REMAP EXISTS FOR. Under the old binding this press produced a
## 0.62 s commitment with no hitbox on it; it has to produce a swing now.
func _rb_swings_out_of_the_block(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	Game.stamina = K.MAX_STAMINA

	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the shield never went up for the RB beat")
		rig.release(&"shield")
		return

	await rig.hold([&"attack"], 4)
	await rig.wait_physics_frames(1)
	var swing: float = combat.get(&"_swing_t")
	var parry: float = combat.get(&"_parry_t")
	print("GUARD block->RB  _swing_t=%.3f _parry_t=%.3f" % [swing, parry])
	if parry >= 0.0:
		_fail("RB out of a block still comes out as the parry")
	if swing < 0.0:
		_fail("RB out of a block swung nothing -- the sword is still unreachable"
			+ " from behind the guard")
	await rig.capture(out.path_join("guard_02_block_to_rb.png"))

	rig.release(&"shield")
	await _reset(rig, hero)


# --- Beat four: and so is RT --------------------------------------------------

## The heavy comes out on the RELEASE (`project.godot`, `heavy`), so this beat
## has to let go before it can assert anything -- a press-and-check would read a
## wind-up as a failure.
func _rt_swings_out_of_the_block(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	Game.stamina = K.MAX_STAMINA

	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the shield never went up for the RT beat")
		rig.release(&"shield")
		return

	await rig.hold([&"heavy"], 4)
	await rig.wait_physics_frames(2)
	var swing: float = combat.get(&"_swing_t")
	var parry: float = combat.get(&"_parry_t")
	print("GUARD block->RT  _swing_t=%.3f _parry_t=%.3f" % [swing, parry])
	if parry >= 0.0:
		_fail("RT out of a block came out as the parry")
	if swing < 0.0:
		_fail("RT out of a block swung nothing")

	rig.release(&"shield")
	await _reset(rig, hero)


# --- Beat five: the guard takes A off the world -------------------------------

## One press, two claimants, and the stance is the entire arbitration. This is
## the beat that catches the ordering bug the disarm exists for: `HeroCombat`
## drops the guard on the tick the parry starts, so a `Prompt` that merely
## ignored presses while `_guarding` would let this one through 0.62 s later, as
## the recovery ends -- having both parried AND opened the chest. So the wait
## below is deliberately longer than `K.PARRY_WINDOW + K.PARRY_RECOVER`, with the
## button still held for all of it.
func _guard_takes_the_button_off_the_world(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var chest := _prop(rig, hero)
	await rig.wait_physics_frames(4)
	# `_armed` only comes back on a RELEASE, and it starts false. A beat that
	# pressed without ever having been seen to let go would pass for the wrong
	# reason.
	await rig.wait_frames(4)
	if Prompt.focus != chest:
		_fail("the test prop never became the focus -- beat five proves nothing")
		chest.queue_free()
		return

	await rig.press(&"shield")
	await rig.wait_frames(GUARD_SETTLE)
	if not bool(combat.get(&"blocking")):
		_fail("the shield never went up for the world beat")
		rig.release(&"shield")
		chest.queue_free()
		return

	await rig.press(&"interact")
	await rig.wait_physics_frames(2)
	if combat.get(&"_parry_t") < 0.0:
		_fail("A at a prop, behind a raised shield, did not parry")
	# Held all the way through the window AND the recovery, which is where the
	# naive version of this leaks.
	await rig.wait_seconds(K.PARRY_WINDOW + K.PARRY_RECOVER + 0.25)
	rig.release(&"interact")
	rig.release(&"shield")
	await rig.wait_frames(4)

	print("GUARD guarded press  activations=%d" % _opened)
	if _opened != 0:
		_fail("the press that parried also activated the prop %d time(s)"
			% _opened)
	chest.queue_free()
	await _reset(rig, hero)


# --- Beat six: and hands it back ----------------------------------------------

## The regression the beat above is one typo away from causing. A shield that
## took the interact button and never gave it back is a game you cannot open a
## chest in, and it would be invisible to every other beat here.
func _shield_down_still_talks(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var chest := _prop(rig, hero)
	await rig.wait_physics_frames(4)
	await rig.wait_frames(4)
	if Prompt.focus != chest:
		_fail("the test prop never became the focus -- beat six proves nothing")
		chest.queue_free()
		return

	await rig.hold([&"interact"], 4)
	await rig.wait_frames(4)
	print("GUARD unguarded press  activations=%d" % _opened)
	if _opened != 1:
		_fail("A with the shield down activated the prop %d time(s), wanted 1"
			% _opened)
	chest.queue_free()
	await rig.wait_frames(4)


# --- Plumbing -----------------------------------------------------------------

var _opened: int = 0


## A bare `Interactable` planted on the hero. Bare on purpose: a real chest
## carries loot, a sound and a lid, and none of those are what is being asked
## about here -- the question is only whether the button reaches it.
func _prop(rig, hero: Node3D) -> Interactable:
	_opened = 0
	var it := Interactable.new()
	it.prompt = "TEST"
	it.radius = 2.4
	rig.current_scene.add_child(it)
	it.global_position = hero.global_position
	it.activated.connect(func(_by: Node3D) -> void: _opened += 1)
	return it


## The hero, planted and idle. Same shape as `parry_dodge._hero` and for the same
## reason: a beat that inherits the last one's swing measures the last one.
func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		return null
	var hero: Node3D = players[0]
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	if hero.get(&"state") == 4:  # Hero.MoveState.ATTACK
		hero.call(&"end_commitment")
	hero.set(&"state", 0)  # GROUND
	var combat = hero.get(&"combat")
	if combat != null:
		combat.set(&"_swing_t", -1.0)
		combat.set(&"_parry_t", -1.0)
		combat.set(&"_riposte_t", 0.0)
		combat.set(&"_flurry_t", 0.0)
		combat.set(&"_buffer", -1)
		combat.set(&"_charge_t", -1.0)
		# The blade's window closes with it, or the next beat's swing starts
		# with a live Area3D already on the hero.
		var box: Area3D = combat.get(&"_hitbox")
		if box != null:
			box.monitoring = false
	return hero


## Everything up, and enough frames for `Prompt._armed` to come back. Every beat
## ends with this because they all share one set of buttons, and a trigger left
## down leaks into the next beat as a guard nobody asked for.
func _reset(rig, hero: Node3D) -> void:
	rig.release(&"shield")
	rig.release(&"interact")
	rig.release(&"attack")
	rig.release(&"heavy")
	await rig.wait_frames(6)
	if hero != null and hero.get(&"state") == 4:
		hero.call(&"end_commitment")
	await rig.wait_frames(6)


func _fail(msg: String) -> void:
	_fails += 1
	print("GUARD FAIL %s" % msg)
