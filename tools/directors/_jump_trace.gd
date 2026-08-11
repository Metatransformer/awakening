extends RefCounted
## The jump POSE against the jump HEIGHT, in the same frame.
##
## The numbers and the picture have to be checked together or they cover for
## each other: an arc can measure perfectly while the hero plays an anticipation
## crouch on the way up, and a pose can look right while he never leaves the
## floor. So every capture here is named with the height it was taken at —
## `p03_dy+0.55.png` is the pose at 0.55 m off the ground — and a sheet of them
## reads as a flipbook you can check against the arc.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/_jump_trace.gd --out=/tmp/jt/x.png
##   ffmpeg -y -i /tmp/jt/p%02d.png -filter_complex tile=6x2 /tmp/jt/sheet.png

## Every Nth physics frame. 3 gives ~12 poses across a 0.60 s arc.
const EVERY := 3


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/jt/x.png").get_base_dir()
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.set(&"facing_yaw", 0.0)

	var cam := hero.get_viewport().get_camera_3d()
	if cam != null:
		cam.set_physics_process(false)

	# Hud is an autoload and draws over every frame; a pose sheet does not want
	# a key-cap legend across the bottom of all twelve.
	if Hud != null:
		Hud.visible = false

	await rig.wait_seconds(0.8)
	var y0: float = hero.global_position.y

	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")

	var shot := 0
	for i in 40:
		if i % EVERY == 0 and shot < 12:
			var dy: float = hero.global_position.y - y0
			# Close and level with his chest: the question is what the limbs are
			# doing, and a high angle flattens a tuck into a crouch.
			cam.global_position = hero.global_position + Vector3(1.9, 0.9, 3.0)
			cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
			await rig.capture(out.path_join("p%02d.png" % shot))
			print("TRACE p%02d dy=%+.3f vy=%+.2f floor=%s" % [
				shot, dy, hero.velocity.y, hero.is_on_floor()])
			shot += 1
		await rig.physics_frame
	print("TRACE done")
