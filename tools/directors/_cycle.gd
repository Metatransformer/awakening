extends RefCounted
var _i := 0
func run(rig) -> void:
	await rig.wait_frames(20)
	Input.action_press(&"move_up", 1.0)
	await rig.wait_frames(40)
	for i in 12:
		await rig.wait_frames(4)
		await rig.capture("f_%02d.png" % _i)
		_i += 1
	Input.action_release(&"move_up")
