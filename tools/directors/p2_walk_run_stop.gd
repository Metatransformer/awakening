extends RefCounted
## P2 — the locomotion ramp: stand, ease onto the stick, break into a full run,
## then release and stop hard.
##
## The point of the sheet is that there is NO walk/run switch. The stick is held
## at 0.55 for the walk pass and 1.0 for the run pass, and `K.speed_for_stick()`
## turns that into a continuous speed; the animation blend just follows the
## speed. Watch stride length and body lean change across the strip, not a clip
## swap.
##
## All waits are in SECONDS. The shoot harness renders uncapped (~300 fps here)
## while physics stays at 60 Hz, so counting rendered frames would compress
## every beat to a sixth of its intended length.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.5)
	await _shot(rig, "idle")

	# Half deflection -> ~1.1 m/s. A walk, out of the same code path as the run.
	Input.action_press(&"move_up", 0.55)
	for i in 4:
		await rig.wait_seconds(0.5)
		await _shot(rig, "walk")

	# Full deflection -> the 4.37 m/s run cap, reached over K.ACCEL.
	Input.action_press(&"move_up", 1.0)
	for i in 5:
		await rig.wait_seconds(0.32)
		await _shot(rig, "run")

	# Stick released: K.DECEL kills the speed in ~0.13 s and the camera coasts
	# the rest of the way in on its own.
	Input.action_release(&"move_up")
	for i in 5:
		await rig.wait_seconds(0.14)
		await _shot(rig, "stop")


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
