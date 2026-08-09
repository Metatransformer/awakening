extends RefCounted
## Does the loadout read right in the poses the player actually sees?
##
## Not a sweep -- a verdict. Idle, blocking, and mid-swing, from the front and
## from the left, with the settled mounts in place. A weapon that only looks
## correct in the pose you tuned it in is not correct.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/loadout_check.gd --out=/tmp/lc/x.png

const VIEWS := [
	{"name": "front", "eye": Vector3(-0.30, 1.25, -2.3)},
	{"name": "left", "eye": Vector3(-2.2, 1.25, -0.3)},
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/lc/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	await rig.wait_frames(24)
	if hero == null:
		push_error("loadout_check: no Hero")
		return

	var cam := Camera3D.new()
	cam.fov = 50.0
	scene.add_child(cam)
	cam.make_current()
	var key := OmniLight3D.new()
	key.light_energy = 3.2
	key.omni_range = 8.0
	scene.add_child(key)
	key.global_position = hero.global_position + Vector3(-1.8, 2.4, -2.2)

	var shoot := func(tag: String) -> void:
		for view in VIEWS:
			cam.global_position = hero.global_position + (view["eye"] as Vector3)
			cam.look_at(hero.global_position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("lc_%s_%s.png" % [tag, view["name"]]))

	await shoot.call("idle")

	Input.action_press(&"shield")
	await rig.wait_frames(28)
	await shoot.call("block")
	Input.action_release(&"shield")
	await rig.wait_frames(24)

	# Mid-swing. The damage window is 0.22-0.62 of a 0.60 s swing, so a handful
	# of frames after the press lands inside it.
	await rig.hold(["attack"], 2)
	await rig.wait_frames(7)
	await shoot.call("swing")

	await rig.wait_frames(40)
	key.queue_free()
	cam.queue_free()
	print("LOADOUTCHECK done")
