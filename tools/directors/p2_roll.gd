extends RefCounted
## P2 — the roll, shot so the speed claim is checkable rather than asserted.
##
## Frames 00-02 are a steady run and frames 03-09 are the roll, captured at the
## SAME 0.09 s cadence. refs/REFERENCE.md §3.4 puts the roll at 6.55 m/s against
## a 4.37 m/s run, so the hero has to visibly travel further between roll frames
## than between run frames — about 0.59 m per frame instead of 0.39 m. If the
## two halves of the strip step by the same amount, the roll is a costume, not a
## move.
##
## It also commits: nothing in 03-12 may show him steering or cancelling out.
## And `K.STICK_ACTION_GATE` (0.917) means a half-stick walk cannot roll at all,
## which is what the last two frames are for — `context` is pressed there and
## must do nothing.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.4)
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.35)   # K.ACCEL needs 0.16 s to reach the cap
	for i in 3:
		await rig.wait_seconds(0.09)
		await _shot(rig, "run")

	Input.action_press(&"context")
	await rig.wait_seconds(0.04)
	Input.action_release(&"context")
	for i in 7:
		await rig.wait_seconds(0.09)
		await _shot(rig, "roll")

	for i in 3:
		await rig.wait_seconds(0.12)
		await _shot(rig, "recover")
	Input.action_release(&"move_up")

	# Below the action gate: `context` must do nothing at all.
	await rig.wait_seconds(0.7)
	Input.action_press(&"move_left", 0.5)
	await rig.wait_seconds(0.7)
	await _shot(rig, "walk")
	Input.action_press(&"context")
	await rig.wait_seconds(0.04)
	Input.action_release(&"context")
	for i in 2:
		await rig.wait_seconds(0.3)
		await _shot(rig, "gated")
	Input.action_release(&"move_left")


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
