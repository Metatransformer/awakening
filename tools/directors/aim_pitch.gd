extends RefCounted
## Can you aim UP with the hookshot?
##
## A hookshot that only aims in yaw cannot reach a ceiling ring, which is most of
## what a hookshot is for. The aim IS the camera (hero_ranged.gd), so this asks
## the camera the question: draw the item, push the right stick to each end of
## the pitch range, and report what the crosshair ray is actually pointed at.
##
## Prints `AIM FAIL ...` on any beat that did not happen, and photographs every
## extreme — a pitch number that moved is not proof that the view moved with it,
## and the failure this was written to find (the boom collapsing into the floor
## as the eye orbits under the hero) is only visible in the frame.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/aim_pitch.gd --out=/tmp/aim/x.png

var out := ""
var fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/aim/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera")
		return

	# dpad up draws the hookshot. Pressed, not set behind the game's back: aim
	# mode is raised by the draw, and that is half of what is under test.
	await rig.tap(["item_up"])
	await rig.wait_frames(20)
	_check("the hookshot is in his hand (%s)" % Game.armament(Game.HAND_RIGHT),
		Game.armament(Game.HAND_RIGHT) == &"hookshot")
	_check("the camera went over the shoulder", cam.aiming())
	_report(rig, hero, cam, "level")
	await rig.capture(out.path_join("a_00_level.png"))

	# Up. cam_up is the right stick pushed forward, which is "look up" with the
	# default (uninverted) mapping.
	await rig.hold(["cam_up"], 90)
	await rig.wait_frames(10)
	var up_pitch := _pitch(cam)
	var up_look := _look(cam)
	_report(rig, hero, cam, "full up")
	await rig.capture(out.path_join("a_01_up.png"))
	_check("the aim rose above horizontal (look.y = %.2f)" % up_look.y, up_look.y > 0.35)
	# Low, and it is meant to be: a 1.55 m boom orbiting 55 degrees under a
	# 1.66 m at-point puts the eye at knee height, which is what looking up from
	# behind a shoulder looks like. The bar is "did not sink through the floor",
	# not "stayed at head height".
	_check("the eye is above the floor (y = %.2f)" % cam.global_position.y,
		cam.global_position.y > 0.15)
	_check("the boom did not collapse into the hero (%.2f m)"
		% cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y),
		cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y) > 0.9)

	# Back down, past level, to the other end.
	await rig.hold(["cam_down"], 180)
	await rig.wait_frames(10)
	var down_look := _look(cam)
	_report(rig, hero, cam, "full down")
	await rig.capture(out.path_join("a_02_down.png"))
	_check("the aim dropped below horizontal (look.y = %.2f)" % down_look.y,
		down_look.y < -0.35)
	_check("the two extremes are actually different (%.1f deg apart)"
		% rad_to_deg(up_look.angle_to(down_look)),
		rad_to_deg(up_look.angle_to(down_look)) > 45.0)
	print("AIM pitch reached %.1f up, %.1f down" % [up_pitch, _pitch(cam)])

	print("AIM done, %d failure(s)" % fails)


## What the crosshair is over, and where the eye is to see it. Printed rather
## than asserted: these are the numbers that explain a failed frame.
func _report(rig, hero, cam, label: String) -> void:
	var look := _look(cam)
	var q := PhysicsRayQueryParameters3D.create(
		cam.global_position, cam.global_position + look * 40.0)
	q.collision_mask = K.L_WORLD
	q.exclude = [hero.get_rid()]
	var hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(q)
	var where := "nothing"
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		where = "%s at %.1f m" % [str(p.round()), cam.global_position.distance_to(p)]
	print("AIM %-9s pitch %6.1f  eye y %5.2f  boom %4.2f  look.y %5.2f  crosshair on %s"
		% [label, _pitch(cam), cam.global_position.y,
			cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y),
			look.y, where])


func _pitch(cam) -> float:
	return float(cam.get(&"_pitch"))


func _look(cam) -> Vector3:
	return -cam.global_transform.basis.z


func _check(what: String, ok: bool) -> void:
	if ok:
		print("AIM ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("AIM FAIL %s" % what)
