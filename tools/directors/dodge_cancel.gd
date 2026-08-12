extends RefCounted
## How long is the hero NOT his own after a dodge, and after a jump?
##
## The complaint this exists to settle is "the roll takes a bit too long to get
## out of", and that is a claim about SECONDS between a press and a swing — a
## pose cannot settle it and neither can a screenshot. So everything here is
## timed on the PHYSICS clock (`_now`), which is the clock the state
## machine actually advances on; rendered frames are a property of the panel
## (see `rig.wait_frames`) and this director ran on a 120 Hz one.
##
## Six beats, and two of them are controls:
##
##   1. CONTROL — the clock can see an immediate press. Tap attack from a
##      standing start and the latency must be ~0. Without this, every number
##      below could be the director's own press pipeline and not the game's.
##   2. Roll, press attack deep inside it, and time roll-start -> ATTACK. The
##      window is the last `dodge_cancel_time` of `roll_recover_time`, so the
##      answer should be `roll_time + roll_recover_time - dodge_cancel_time`.
##   3. NULL CASE — the same beat with `dodge_cancel_time` and
##      `dodge_buffer_grace` set to zero, which is the game exactly as it was
##      before this card. The swing must NEVER come out: the old code refused it
##      in `request_attack` and dropped the press on the floor. A director that
##      reports an improvement here is reporting one it invented, and CLAUDE.md
##      §2 has six of those on the board already.
##   4. The dodge is still COMMITTED to locomotion. Hold the stick through a
##      whole dodge and press nothing: it must still take the full
##      `roll_time + roll_recover_time`. This is what separates a cancel window
##      from "the recovery got shorter", and it is the design in one measurement.
##   5. The shield comes back up in the window and NOT before it.
##   6. The jump's landing tail, measured off the one-shot's own `active` flag,
##      with its own null case: `jump_land_time` set past the clip's length is
##      the old behaviour, and it must read visibly longer.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/dodge_cancel.gd --out=/tmp/dodge/x.png

## Seconds any single measurement is allowed before it is called a miss. Well
## past a whole dodge (0.82) and a whole jump clip (1.67).
const LIMIT := 3.0
## Seconds into the ROLL that the attack button goes down. Deep inside the
## travel, far from the cancel window, so what is being measured is the game
## honouring an old press and not the director happening to press on the right
## frame.
const PRESS_AT := 0.30
## Slack allowed on a predicted latency, in seconds. Two physics ticks plus the
## frame the press pipeline costs.
const SLACK := 0.06


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/dodge/x.png").get_base_dir()
	var hero: Node3D = rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D
	if not rig.check(hero != null, "DODGE no hero in the scene"):
		return
	var tree: AnimationTree = hero.get_node_or_null(^"AnimTree") as AnimationTree
	if not rig.check(tree != null, "DODGE no AnimTree on the hero"):
		return

	# The measured lengths, read off the hero rather than off K, so a director
	# left behind by a tuning pass reports the mismatch instead of failing.
	var roll_t: float = hero.get(&"roll_time")
	var recover_t: float = hero.get(&"roll_recover_time")
	var cancel_t: float = hero.get(&"dodge_cancel_time")
	var full := roll_t + recover_t
	print("DODGE roll=%.2f recover=%.2f cancel=%.2f (whole dodge %.2f)"
		% [roll_t, recover_t, cancel_t, full])

	# Stamina is what refuses a dodge, and three rolls empty the bar
	# (K.STAMINA_ROLL). Every beat below tops it back up rather than sharing one
	# bar across six, because a beat that fails on an empty gauge fails for a
	# reason that has nothing to do with the cancel window.
	await rig.wait_frames(30)

	# --- 1. CONTROL: the clock sees an immediate press -----------------------
	_refill()
	var free_latency := await _attack_latency(rig, hero)
	print("DODGE control: standing attack at %.3f s" % free_latency)
	rig.check(free_latency >= 0.0 and free_latency <= SLACK * 2.0,
		"DODGE control: a standing attack took %.3f s — the instrument is measuring itself, not the game"
			% free_latency)

	# --- 2. attack out of a roll --------------------------------------------
	await _settle(rig, hero)
	var want := full - cancel_t
	var cancelled := await _roll_then_attack(rig, hero)
	print("DODGE roll -> attack at %.3f s (want ~%.3f)" % [cancelled, want])
	await rig.capture(out.path_join("d_00_cancelled.png"))
	if rig.check(cancelled >= 0.0,
			"DODGE the swing never came out of the roll — the press was eaten"):
		rig.check(absf(cancelled - want) <= SLACK,
			"DODGE roll -> attack was %.3f s, wanted %.3f +/- %.2f" % [cancelled, want, SLACK])
		rig.check(cancelled < full - 0.02,
			"DODGE roll -> attack (%.3f) is not shorter than the whole dodge (%.3f) — nothing was cancelled"
				% [cancelled, full])

	# --- 3. NULL CASE: the game as it was, which must NOT cancel -------------
	# Both knobs to zero is the old code and not an approximation of it: with no
	# window `request_attack` refuses for the whole dodge, and with no buffer
	# `HeroCombat._press` drops the refused press exactly as it always did.
	await _settle(rig, hero)
	var combat: Node = hero.get(&"combat")
	if rig.check(combat != null, "DODGE no HeroCombat on the hero"):
		var keep_cancel := cancel_t
		var keep_buffer: float = combat.get(&"dodge_buffer_grace")
		hero.set(&"dodge_cancel_time", 0.0)
		combat.set(&"dodge_buffer_grace", 0.0)
		var old := await _roll_then_attack(rig, hero)
		hero.set(&"dodge_cancel_time", keep_cancel)
		combat.set(&"dodge_buffer_grace", keep_buffer)
		print("DODGE null case (cancel=0 buffer=0): %s"
			% ["never swung" if old < 0.0 else "swung at %.3f s" % old])
		rig.check(old < 0.0,
			"DODGE null case swung at %.3f s with the window shut — this director is measuring its own press timing, not the cancel"
				% old)

	# --- 4. the dodge is still committed to LOCOMOTION -----------------------
	# Same roll, same held stick, no button. If the window were simply a shorter
	# recovery this would come back at `full - cancel_t` too, and the whole
	# "you cannot cancel a roll into a run" half of the design would be gone.
	await _settle(rig, hero)
	var quiet := await _roll_duration(rig, hero)
	print("DODGE stick held, no press: dodge lasted %.3f s (want ~%.3f)" % [quiet, full])
	rig.check(quiet >= 0.0 and absf(quiet - full) <= SLACK,
		"DODGE an uncancelled dodge lasted %.3f s, wanted the full %.3f — the recovery got shorter for everyone"
			% [quiet, full])

	# --- 5. the shield in the window, and not before -------------------------
	await _settle(rig, hero)
	var guard := await _roll_then_guard(rig, hero)
	print("DODGE roll -> shield up at %.3f s (want ~%.3f)" % [guard, want])
	await rig.capture(out.path_join("d_01_guard.png"))
	if rig.check(guard >= 0.0, "DODGE the shield never came back up after the roll"):
		rig.check(guard >= roll_t,
			"DODGE the shield came up at %.3f s, inside the %.2f s dive — the roll is being played under a block pose"
				% [guard, roll_t])
		rig.check(absf(guard - want) <= SLACK,
			"DODGE roll -> shield was %.3f s, wanted %.3f +/- %.2f" % [guard, want, SLACK])

	# --- 6. the jump's landing tail, and its own null case -------------------
	#
	# BOTH JUMPS, and the first version of this beat measured only one of them —
	# it held the stick, so every jump it threw was the RUNNING one, and it came
	# back reporting the cut saved 0.03 s. Which was true of `ex_jump_running`:
	# that clip is 1.45 s from a 0.47 offset, so once the ~0.60 s of air is taken
	# off there is only ~0.38 s of tail to cut and the cut plus its fade is about
	# the same length. `ex_jump` is the standing one and it is 1.67 s from 0.50 —
	# ~0.57 s of tail, half again as long — and it is the one a player meets when
	# they hop in place. Measuring the short clip and reporting the answer as
	# "the jump" would have retired this whole knob on a number about the other
	# clip entirely.
	var keep_land: float = hero.get(&"jump_land_time")
	for standing in [true, false]:
		var which := "standing" if standing else "running"
		await _settle(rig, hero)
		var cut := await _jump_tail(rig, hero, tree, standing)
		if standing:
			await rig.capture(out.path_join("d_02_landed.png"))
		# Past the whole clip, so nothing is ever cut and the tail runs to its own
		# end — the behaviour every build before this card had.
		hero.set(&"jump_land_time", 9.0)
		await _settle(rig, hero)
		var uncut := await _jump_tail(rig, hero, tree, standing)
		hero.set(&"jump_land_time", keep_land)
		print("DODGE %s jump tail: cut %.3f s vs uncut %.3f s" % [which, cut, uncut])
		if rig.check(cut >= 0.0 and uncut >= 0.0,
				"DODGE the %s jump one-shot never went inactive — `active` is not the flag to read"
					% which):
			rig.check(cut < uncut,
				"DODGE the cut %s tail (%.3f) is no shorter than the uncut one (%.3f) — jump_land_time does nothing"
					% [which, cut, uncut])

	print("DODGE %s -- %d check(s) failed" % ["OK" if rig.fails == 0 else "FAIL", rig.fails])


## Roll, then press attack `PRESS_AT` into it, and answer how long after the
## roll STARTED the hero reached MoveState.ATTACK. -1.0 if he never did.
func _roll_then_attack(rig, hero: Node3D) -> float:
	var t0 := await _start_roll(rig, hero)
	if t0 < 0.0:
		return -1.0
	await rig.wait_seconds(PRESS_AT)
	# The whole press, issued and let go while he is still deep in the dive. What
	# is being measured is whether the game REMEMBERS it — a button left held
	# would be re-read on the frame the window opens and would prove nothing.
	await rig.hold(["attack"], 4)
	var ok := await _until(rig,
		func() -> bool: return int(hero.get(&"state")) == Hero.MoveState.ATTACK, LIMIT)
	var landed := _now() - t0
	rig.release(&"move_up")
	return landed if ok else -1.0


## Roll with the stick held and nothing else pressed, and answer how long the
## whole thing took to hand him back to GROUND.
func _roll_duration(rig, hero: Node3D) -> float:
	var t0 := await _start_roll(rig, hero)
	if t0 < 0.0:
		return -1.0
	var ok := await _until(rig,
		func() -> bool: return int(hero.get(&"state")) == Hero.MoveState.GROUND, LIMIT)
	var done := _now() - t0
	rig.release(&"move_up")
	return done if ok else -1.0


## Roll, then hold the shield from `PRESS_AT` on, and answer when it actually
## came up. The button STAYS DOWN here, unlike the swing: a guard is a held
## stance and the question is which frame the game lets it be true on.
func _roll_then_guard(rig, hero: Node3D) -> float:
	var t0 := await _start_roll(rig, hero)
	if t0 < 0.0:
		return -1.0
	await rig.wait_seconds(PRESS_AT)
	await rig.press(&"shield")
	var ok := await _until(rig,
		func() -> bool: return bool(hero.get(&"blocking")), LIMIT)
	var up := _now() - t0
	rig.release(&"shield")
	rig.release(&"move_up")
	return up if ok else -1.0


## Latency from an attack press to MoveState.ATTACK. The control beat is the only
## caller: point it at a standing hero, where the honest answer is "immediately",
## and check that immediately is what comes back.
func _attack_latency(rig, hero: Node3D) -> float:
	await rig.hold(["attack"], 4)
	var t0 := _now()
	var ok := await _until(rig,
		func() -> bool: return int(hero.get(&"state")) == Hero.MoveState.ATTACK, LIMIT)
	return (_now() - t0) if ok else -1.0


## Jump, and answer how long after TOUCHDOWN the jump one-shot stopped
## contributing to the pose.
##
## Read off the node's own `active` parameter rather than off a timer of the
## director's, because what the player sees is the BLEND: `jump_land_time` only
## arms the cut and the one-shot's `fadeout_time` (0.22) is the rest of it.
##
## `standing` picks WHICH clip: `_fire_jump` reads the speed the hero is carrying
## at launch against `jump_run_speed_gate`, so a standing jump has to leave from
## a standing start. The stick then goes down in the AIR — the cut only fires
## once the player is asking for something (`Hero._tick_jump_cut`), and a hand
## off the stick would measure the deliberately-uncut case in both halves.
func _jump_tail(rig, hero: Node3D, tree: AnimationTree, standing: bool) -> float:
	if not standing:
		await rig.press(&"move_up")
		await rig.wait_seconds(0.25)
	await rig.tap(["jump"])
	# Off the ground first, or "he has landed" is true on the press frame.
	if not await _until(rig,
			func() -> bool: return not bool(hero.call(&"is_on_floor")), 1.0):
		rig.release(&"move_up")
		return -1.0
	if standing:
		await rig.press(&"move_up")
	if not await _until(rig,
			func() -> bool: return bool(hero.call(&"is_on_floor")), LIMIT):
		rig.release(&"move_up")
		return -1.0
	var t0 := _now()
	# Whichever of the two jump one-shots the launch speed picked. Asking both is
	# cheaper than re-deriving `jump_run_speed_gate` here and getting it wrong.
	var ok := await _until(rig, func() -> bool:
		return not bool(tree.get("parameters/Jump/active")) \
			and not bool(tree.get("parameters/JumpRun/active")), LIMIT)
	var gone := _now() - t0
	rig.release(&"move_up")
	return gone if ok else -1.0


## Hold the stick forward and tap `context`, which is the dodge. Answers the
## timestamp MoveState.ROLL was first seen at, or -1.0 if it never was — a roll
## refused for stamina or for the stick gate would otherwise be timed as if it
## had happened.
##
## The stick is left HELD on purpose and each caller releases it: a dodge that
## the player is still asking to run out of is the case the commitment rule is
## about, and letting go would make beat 4 a measurement of a released stick.
func _start_roll(rig, hero: Node3D) -> float:
	await rig.press(&"move_up")
	# Long enough that the hero has a wish direction and is moving, short enough
	# that `sprint_hold_time` has nothing to do with it — the context tap below
	# is a separate button from the stick.
	await rig.wait_seconds(0.25)
	await rig.tap(["context"])
	if not await _until(rig,
			func() -> bool: return int(hero.get(&"state")) == Hero.MoveState.ROLL, 1.0):
		rig.release(&"move_up")
		rig.fail("DODGE the roll never started — stamina, or the stick gate")
		return -1.0
	return _now()


## Wait on the physics clock until `test` answers true. False if it never did
## inside `limit` seconds.
func _until(rig, test: Callable, limit: float) -> bool:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var waited := 0.0
	while waited < limit:
		await rig.wait_physics_frames(1)
		waited += step
		if test.call():
			return true
	return false


## The physics-tick counter, in seconds.
##
## EVERY TIMESTAMP IN THIS FILE IS TAKEN FROM HERE, and the first version was not:
## each beat added up the pieces of its own wait — `PRESS_AT`, plus a
## `_time_until` that started counting only after `rig.hold` had returned. The
## four rendered frames the press itself costs fell down the gap between them, and
## the roll-cancel beat came back 0.06 s early and failed a check that was
## correct. One monotonic clock read at both ends cannot lose time between calls,
## whatever the caller did in between; the residual error is the one physics tick
## each end is detected within.
##
## `Engine.get_physics_frames()` and not `Time.get_ticks_msec()`, which is the
## wall clock and would count a shader compile as game time.
func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## Put the stamina bar back. Three rolls empty it (K.STAMINA_ROLL against
## K.MAX_STAMINA) and this director throws five.
func _refill() -> void:
	Game.stamina = Game.max_stamina


## Hand the hero back to himself before the next beat starts, and refill the bar.
##
## THE FIRST VERSION OF THIS DIRECTOR DID NOT HAVE IT and it cost the run's most
## important beat. `_attack_latency` returns the moment `state` reaches ATTACK —
## 0.017 s in — and the swing it started is `swing_time` (0.60 s) long, so the
## roll beat below it pressed the dodge button 0.25 s into a swing, was correctly
## refused by `_try_start_roll`, and reported "the swing never came out of the
## roll". Which was true, and had nothing to do with the cancel window.
func _settle(rig, hero: Node3D) -> void:
	_refill()
	var ok := await _until(rig, func() -> bool:
		return int(hero.get(&"state")) == Hero.MoveState.GROUND \
			and bool(hero.call(&"is_on_floor")), LIMIT)
	if not ok:
		rig.fail("DODGE the hero never came back to GROUND between beats")
	# The stamina spent by whatever we just waited out is what this second refill
	# is for; the one above is so a beat that hangs still hangs with a full bar.
	_refill()
