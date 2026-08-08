extends RefCounted
## P2 — the reversal. Run north at the cap, then slam the stick south.
##
## refs/REFERENCE.md §3.3: past ~135° off the heading OOT does not steer, it
## kills speed and re-orients. That is why an about-face reads as its own move.
## The strip should show the run, a planted skid with `ss_180_turn_01` over it,
## and only then acceleration the other way — not a smooth arc.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.4)
	Input.action_press(&"move_up", 1.0)
	for i in 3:
		await rig.wait_seconds(0.45)
		await _shot(rig, "run_n")

	# Full reversal. The camera is still looking north, so `move_down` is a
	# camera-relative 180 whatever the hero happens to be facing.
	Input.action_release(&"move_up")
	Input.action_press(&"move_down", 1.0)
	for i in 6:
		await rig.wait_seconds(0.1)
		await _shot(rig, "turn")

	for i in 5:
		await rig.wait_seconds(0.3)
		await _shot(rig, "run_s")
	Input.action_release(&"move_down")
	for i in 2:
		await rig.wait_seconds(0.35)
		await _shot(rig, "settle")


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
