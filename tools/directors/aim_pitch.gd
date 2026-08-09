extends RefCounted
## Can you aim UP with the hookshot, and does the eye STAY PUT while you do it?
##
## A hookshot that only aims in yaw cannot reach a ceiling ring, which is most of
## what a hookshot is for. The aim IS the camera (hero_ranged.gd), so this asks
## the camera the question: raise the item, push the right stick to each end of
## the pitch range, and report what the crosshair ray is actually pointed at.
##
## The second half is what the numbers here are really for. The sight used to be
## an ORBIT: the eye swung around a pivot at the hero's shoulder on a 1.55 m arm,
## so pushing the stick from one end of the pitch range to the other moved the
## camera itself from y=0.32 (below his knees) to y=2.75 (over his head). The aim
## was correct at both ends and the stance was unusable between them, because the
## world heaved every time the crosshair moved. `EYE_TRAVEL` is the bar that
## failure would not clear.
##
## Prints `AIM FAIL ...` on any beat that did not happen, and photographs every
## extreme — a pitch number that moved is not proof that the view moved with it,
## and an eye height is not proof that the frame is legible.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/aim_pitch.gd --out=/tmp/aim/x.png

## Metres the eye may wander over the whole 110° of pitch. Generous — the rig
## still eases, the hero still breathes under the at-point's lag — and still an
## order of magnitude under the 2.43 m the orbit used to travel.
const EYE_TRAVEL := 0.35

var out := ""
var fails := 0
var eye_lo := 99.0
var eye_hi := -99.0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/aim/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera")
		return

	# dpad up draws the hookshot. Pressed, not set behind the game's back.
	await rig.tap(["item_up"])
	await rig.wait_frames(20)
	_check("the hookshot is in his hand (%s)" % Game.armament(Game.HAND_RIGHT),
		Game.armament(Game.HAND_RIGHT) == &"hookshot")
	# Selecting it must NOT zoom. Carrying a grapple pistol across a room in a
	# 42-degree sight is what this half of the fix removed, and a negative check
	# is the only thing that keeps it removed.
	_check("selecting it did not zoom", not cam.aiming())
	await rig.capture(out.path_join("a_00_carried.png"))

	# The TRIGGER raises it, and it is held down for the whole sweep — released,
	# the chain goes out and the stance ends before the stick has moved. Pressed
	# through `Input` rather than `rig.hold` because this hold has to outlive
	# several beats, and `hold` releases at the end of its own.
	_press(rig, &"use_item")
	await rig.wait_frames(20)
	_check("the trigger put the camera over the shoulder", cam.aiming())
	_report(rig, hero, cam, "level")
	await rig.capture(out.path_join("a_01_level.png"))

	# Up. cam_up is the right stick pushed forward, which is "look up" with the
	# default (uninverted) mapping.
	await rig.hold(["cam_up"], 90)
	await rig.wait_frames(10)
	var up_pitch := _pitch(cam)
	var up_look := _look(cam)
	_report(rig, hero, cam, "full up")
	await rig.capture(out.path_join("a_02_up.png"))
	_check("the aim rose above horizontal (look.y = %.2f)" % up_look.y, up_look.y > 0.35)
	_check("the boom did not collapse into the hero (%.2f m)"
		% cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y),
		cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y) > 0.9)

	# Back down, past level, to the other end.
	await rig.hold(["cam_down"], 180)
	await rig.wait_frames(10)
	var down_look := _look(cam)
	_report(rig, hero, cam, "full down")
	await rig.capture(out.path_join("a_03_down.png"))
	_check("the aim dropped below horizontal (look.y = %.2f)" % down_look.y,
		down_look.y < -0.35)
	_check("the two extremes are actually different (%.1f deg apart)"
		% rad_to_deg(up_look.angle_to(down_look)),
		rad_to_deg(up_look.angle_to(down_look)) > 45.0)
	# The whole point. The aim swung 106 degrees; the eye must not have gone with
	# it. This is measured across every `_report`, so it covers the sweep and not
	# just its two ends.
	_check("the eye held still through the sweep (%.2f m of travel, %.2f..%.2f)"
		% [eye_hi - eye_lo, eye_lo, eye_hi], eye_hi - eye_lo < EYE_TRAVEL)
	print("AIM pitch reached %.1f up, %.1f down" % [up_pitch, _pitch(cam)])

	# And letting go puts it back. The chain goes out on this release — that is
	# the hookshot's whole contract — so the wait is long enough for the shot to
	# play out and the stance to end with it.
	_release(rig, &"use_item")
	await rig.wait_frames(140)
	_check("releasing the trigger left aim mode", not cam.aiming())
	await rig.capture(out.path_join("a_04_released.png"))

	print("AIM done, %d failure(s)" % fails)


## Hold an action across beats. `rig.hold` releases at the end of its own, which
## is no use for a trigger that has to stay down through three of them.
func _press(_rig, action: StringName) -> void:
	if InputMap.has_action(action):
		Input.action_press(action)


func _release(_rig, action: StringName) -> void:
	if InputMap.has_action(action):
		Input.action_release(action)


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
	eye_lo = minf(eye_lo, cam.global_position.y)
	eye_hi = maxf(eye_hi, cam.global_position.y)
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
