extends RefCounted
## P2 — the roll. Run up to the cap, tap `context`, hold the stick through it.
##
## refs/REFERENCE.md §3.4: the roll is 6.55 m/s against a 4.37 m/s run, so the
## hero visibly GAINS on the camera through the roll and is reeled back in
## during the recovery. It also commits — the strip must not show him cancelling
## out of it early. `K.STICK_ACTION_GATE` (0.917) is why a half-stick walk
## cannot roll at all; the last two frames prove that.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.4)
	Input.action_press(&"move_up", 1.0)
	for i in 3:
		await rig.wait_seconds(0.4)
		await _shot(rig, "run")

	Input.action_press(&"context")
	await rig.wait_seconds(0.05)
	Input.action_release(&"context")
	for i in 7:
		await rig.wait_seconds(0.09)
		await _shot(rig, "roll")

	for i in 3:
		await rig.wait_seconds(0.12)
		await _shot(rig, "recover")
	Input.action_release(&"move_up")

	# Below the action gate: `context` must do nothing at all.
	await rig.wait_seconds(0.6)
	Input.action_press(&"move_up", 0.5)
	await rig.wait_seconds(0.6)
	Input.action_press(&"context")
	await rig.wait_seconds(0.05)
	Input.action_release(&"context")
	for i in 2:
		await rig.wait_seconds(0.35)
		await _shot(rig, "gated")
	Input.action_release(&"move_up")


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
