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
##   4. The heavy does not slot into the chain. Press heavy, then light: the
##      light must be step one. Otherwise the finisher is reachable by mashing
##      whatever, and there is no chain to learn.
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
## depends on the machine. Contact is at 0.22 of a 0.46 s swing and the buffer
## opens at 0.35, so this lands the press around the middle of the recovery.
const AFTER_CONTACT := 0.12
## Long enough to be past chain_window (0.34 s) and past the tail of the
## finisher, which is the longest swing in the chain.
const LAPSE := 1.2

var _hits: Array[int] = []


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

	# --- the heavy does not feed the chain -----------------------------------
	await rig.wait_seconds(LAPSE)
	var heavy := await _press_and_land(rig, "heavy_attack")
	await rig.wait_seconds(LAPSE)
	var after_heavy := await _press_and_land(rig, "attack")
	print("COMBO heavy dmg=%d then light dmg=%d (step1 was %d)"
		% [heavy, after_heavy, step[0]])
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
	if heavy <= step[0]:
		print("COMBO FAIL heavy (%d) does not out-damage step one (%d)"
			% [heavy, step[0]]); fails += 1
	if after_heavy != step[0]:
		print("COMBO FAIL a light after a heavy dealt %d, not step one's %d — the heavy feeds the chain"
			% [after_heavy, step[0]]); fails += 1

	print("COMBO %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


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
