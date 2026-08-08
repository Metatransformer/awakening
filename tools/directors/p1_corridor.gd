extends RefCounted
## P1 — the wall case. Run the length of the chamber, through the 2.4 m doorway,
## down the 4 m corridor to the end wall, then turn round and come back.
##
## This is the shot the camera cannot fake. The boom wants 4.13 m
## (K.CAM_DIST_MAX) and the corridor is 4 m wide with a hard end wall, so:
##   * approaching the doorway no yaw clears at all — the boom has to pull in;
##   * inside the corridor the walls sit either side of the boom, not behind it;
##   * at the end wall the camera has nowhere to go and must sit close without
##     ever showing the far side of the geometry.
## Every frame in this strip must be inside the room. One frame looking through
## a wall fails the whole package.
##
## Waits are in SECONDS: the harness renders uncapped, physics is 60 Hz.

var _i := 0


func run(rig) -> void:
	await rig.wait_seconds(0.4)
	await _shot(rig, "start")

	# z 6 -> the doorway at z -10 -> the corridor end wall near z -26.
	Input.action_press(&"move_up", 1.0)
	for i in 15:
		await rig.wait_seconds(0.5)
		await _shot(rig, "north")

	Input.action_release(&"move_up")
	await rig.wait_seconds(0.5)
	await _shot(rig, "endwall")

	# Turn round in the corridor — the camera now has the end wall behind it.
	Input.action_press(&"move_down", 1.0)
	for i in 6:
		await rig.wait_seconds(0.6)
		await _shot(rig, "south")
	Input.action_release(&"move_down")
	await rig.wait_seconds(0.6)
	await _shot(rig, "rest")


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
