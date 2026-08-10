extends RefCounted
## Is the light attack a three-step chain, or one swing pressed three times?
##
## Four claims, each of which fails loudly:
##   1. Three presses in a row land three blows. If the buffer is broken the
##      second and third presses are eaten and only one hit registers.
##   2. The three blows are DIFFERENT swings — step three is the finisher and
##      hurts more than step one. Same damage means the chain is cosmetic.
##   3. The chain LAPSES. Wait out `chain_window` and the next press is step one
##      again, not a free finisher. Without this the third swing is simply the
##      attack button after a pause, which is a worse light attack.
##   4. The heavy does not slot into the chain. Charge, then press light: the
##      light must be step one. Otherwise the finisher is reachable by mashing
##      whatever, and there is no chain to learn.
##
## **The charge is on the TRIGGER (`heavy`), not on a held `attack`.** This file
## used to hold `attack` past `charge_time` and assert two blows out of it — the
## light the press threw and the spin the release threw — because for a while the
## heavy really was the attack button held. That arrangement is gone
## (`HeroCombat._tick_heavy_button`): `attack` is the chain and nothing else, and
## the trigger is tap-for-overhead / hold-for-spin. The old beat kept failing
## against a game that was working, which is the same class of lie as a green
## proof aimed one layer above the code — see tools/directors/sword_contact.gd.
##
## This director proves the CHAIN, not the poses. It deliberately photographs
## almost nothing: capture() stalls the game clock for longer than the chain
## window, so a run that screenshots between steps drops the chain and reports a
## failure it caused itself. What the three swings LOOK like is
## tools/directors/swing_lookdev.gd's job, and it renders every frame of all
## three clips.
##
## Damage is read off the post's `struck` signal, NOT off its `total_damage`.
## The post clears its running total after `readout_reset` (4 s) of quiet, so a
## director that diffs the total across a pause measures the RESET — the first
## version of this file reported a swing dealing -2, which is how that was
## caught. The signal reports each blow's amount and cannot drift.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_combo.gd --out=/tmp/p4c/x.png

## Seconds to wait after a blow lands before pressing again. In SECONDS, not
## frames: the thing being cleared is `chain_buffer_from`, a fraction of a swing
## measured in seconds, and rig.wait_frames counts PROCESS frames whose rate
## depends on the machine. Contact is at 0.22 of a 0.60 s swing and the buffer
## opens at 0.35, so this lands the press around the middle of the recovery.
const AFTER_CONTACT := 0.12
## Long enough to be past chain_window (0.34 s) and past the tail of the
## finisher, which is the longest swing in the chain.
const LAPSE := 1.2

var _hits: Array[int] = []
## Whether `combat.charged` was actually up at the moment the hold was released.
## Sampled inside _charge_and_land, asserted in run() — a charge that never
## armed still throws two blows, just the wrong second one.
var _charge_seen: bool = false


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/p4c/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	var fails := 0

	if hero == null:
		print("COMBO FAIL no Hero in the scene")
		return
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("COMBO FAIL no HeroCombat on the Hero")
		return
	var post: Node = scene.get_node_or_null(^"PostA")
	if post == null:
		print("COMBO FAIL no PostA to hit")
		return
	post.connect(&"struck", _on_struck)

	await rig.wait_frames(24)
	# Placed, not walked. A director measuring the chain must not also be
	# measuring the pathing — see p4_heavy.gd.
	var post_pos: Vector3 = (post as Node3D).global_position
	hero.global_position = post_pos + Vector3(0.0, 0.05, 1.1)
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(20)
	await rig.capture(out.path_join("c_00_ready.png"))

	# --- the pace, which is also the animation speed -------------------------
	# `Hero.request_attack` plays the clip at `clip_len / duration`, so there is
	# no separate animation knob: `swing_time` IS how fast the swing looks. That
	# makes it silently retunable by anyone who reads the name as "lockout" —
	# hence measuring it here rather than trusting the export. Measured, not
	# asserted against a literal, because the number is a tuning value and a
	# director that fails when the designer tunes it is a director nobody keeps.
	# What IS asserted is that the clock the hero actually spends in the swing
	# matches the export — a clip whose speed scale never got set would sail past
	# while the state sat there, and the printed number would still look right.
	var want: float = combat.get(&"swing_time")
	var got := await _time_one_swing(rig, hero)
	print("COMBO pace swing_time=%.2fs, measured %.2fs (chain scale %s)"
		% [want, got, combat.get(&"chain_time_scale")])
	if absf(got - want) > 0.10:
		print("COMBO FAIL the swing owned the hero for %.2fs, not swing_time's %.2fs"
			% [got, want]); fails += 1
	await rig.wait_seconds(LAPSE)

	# --- the chain, three presses -------------------------------------------
	# NOT A FRAME IS CAPTURED IN HERE. capture() awaits frame_post_draw and then
	# writes a PNG to disk, and the game clock runs the whole time — enough of it
	# that a screenshot between steps drops the chain window on the floor. The
	# first version of this file photographed each step and reported step two as
	# never landing, which is a director measuring its own screenshots.
	var step: Array[int] = []
	for i in 3:
		step.append(await _press_and_land(rig, "attack"))
		if i < 2:
			# Press again while the swing is still running: the buffer is what
			# turns this into step two rather than a dropped input.
			await rig.wait_seconds(AFTER_CONTACT)
	print("COMBO chain dmg step1=%d step2=%d step3=%d" % [step[0], step[1], step[2]])

	# --- the chain lapses ----------------------------------------------------
	await rig.wait_seconds(LAPSE)
	var after_lapse := await _press_and_land(rig, "attack")
	print("COMBO after lapse dmg=%d (step1 was %d)" % [after_lapse, step[0]])
	await rig.capture(out.path_join("c_02_after_lapse.png"))

	# --- the charge does not feed the chain ----------------------------------
	# One blow out of the held trigger — the spin the RELEASE threw — and then a
	# light, which must come back as step one.
	await rig.wait_seconds(LAPSE)
	var charge_blow := await _charge_and_land(rig, combat)
	await rig.wait_seconds(LAPSE)
	var after_heavy := await _press_and_land(rig, "attack")
	print("COMBO charge: release dmg=%d, then light dmg=%d (step1 was %d)"
		% [charge_blow, after_heavy, step[0]])
	await rig.capture(out.path_join("c_03_after_heavy.png"))

	for i in 3:
		if step[i] <= 0:
			print("COMBO FAIL chain step %d never landed" % (i + 1)); fails += 1
	if step[2] <= step[0]:
		print("COMBO FAIL finisher (%d) does not out-damage step one (%d)"
			% [step[2], step[0]]); fails += 1
	if after_lapse != step[0]:
		print("COMBO FAIL after the window lapsed the swing dealt %d, not step one's %d"
			% [after_lapse, step[0]]); fails += 1
	if not _charge_seen:
		print("COMBO FAIL the trigger was held well past charge_time and never charged"
			+ " (magic %d/%d — an empty bar refuses to arm, by design)"
			% [Game.magic, Game.max_magic]); fails += 1
	if charge_blow <= step[0]:
		print("COMBO FAIL the charge release (%d) does not out-damage step one (%d)"
			% [charge_blow, step[0]]); fails += 1
	if after_heavy != step[0]:
		print("COMBO FAIL a light after a heavy dealt %d, not step one's %d — the heavy feeds the chain"
			% [after_heavy, step[0]]); fails += 1

	print("COMBO %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


## Wall-clock seconds the hero spends in MoveState.ATTACK for one light swing.
##
## `swing_time` is both the lockout AND the animation speed (`Hero.request_attack`
## scales the clip by `clip_len / duration`), so this one number is the whole
## claim that the chain slowed down. Timed with `Time.get_ticks_msec` rather than
## counted in frames because the harness renders uncapped.
func _time_one_swing(rig, hero: Node) -> float:
	var attack: int = 4  # Hero.MoveState.ATTACK — the enum is not exported.
	await rig.tap(["attack"])
	for _i in 240:
		if int(hero.get(&"state")) == attack:
			break
		await rig.wait_frames(1)
	var t0 := Time.get_ticks_msec()
	for _i in 600:
		if int(hero.get(&"state")) != attack:
			break
		await rig.wait_frames(1)
	return float(Time.get_ticks_msec() - t0) / 1000.0


## Press `action` and return what the resulting blow dealt, or 0 if nothing
## landed. The wait is on the BLOW, not on a frame count: a swing that is slower
## than expected should read as slow, not as a miss.
func _press_and_land(rig, action: String) -> int:
	var before := _hits.size()
	await rig.tap([action])
	for _i in 240:
		if _hits.size() > before:
			return _hits[before]
		await rig.wait_frames(1)
	return 0


## Hold the TRIGGER past `charge_time` and let go. Returns what the release
## dealt, or 0 if nothing came out.
##
## ONE blow, not two. Holding the trigger throws nothing on the press — the press
## edge only starts the wind-up clock — so there is no light swing to straddle
## the release any more.
##
## Driven with Input.action_press/release rather than rig.hold_seconds because
## the blow has to be waited for AFTER the button is up. Polled actions read a
## synthetic press fine (this is `is_action_pressed`, not `_unhandled_input` —
## see CLAUDE.md §3).
##
## The spin is priced in magic now (`K.MAGIC_SPIN`), so the bar is filled first.
## A director that inherited a spent bar from whatever ran before it would get
## the overhead instead — a real swing, a smaller number, and a failure that has
## nothing to do with the chain.
func _charge_and_land(rig, combat: Node) -> int:
	Game.fill_magic()
	var before := _hits.size()
	Input.action_press(&"heavy")
	# Past the charge, with margin: `charge_time` is an export and this must not
	# become a director that fails when someone tunes it by a frame.
	var wind: float = float(combat.get(&"charge_time")) + 0.35
	await rig.wait_seconds(wind)
	_charge_seen = bool(combat.get(&"charged"))
	Input.action_release(&"heavy")
	for _i in 240:
		if _hits.size() > before:
			break
		await rig.wait_frames(1)
	return _hits[before] if _hits.size() > before else 0
