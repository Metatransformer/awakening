extends RefCounted
## First person — BOTW's right-stick click, and the one mode in this project
## that is ENTIRELY pixels.
##
## Nothing about it can be trusted from state. "The camera is at the hero's eye"
## is true of a camera pointed at the inside of his skull, at the floor, or 40°
## off where the stick had it, and every one of those reads as a correct boolean.
## So this director asks the frames:
##
##   1. third person, for the before;
##   2. press it — the boom is gone, the hero is not in his own shot, and the
##      view is looking the SAME WAY the third-person camera was;
##   3. the stick still turns the head, both axes;
##   4. the hero cannot walk in here (he is rooted — hold move_up and the eye
##      must not travel);
##   5. press it again and the boom comes back, with the hero visible in it.
##
## The measured claims — boom length, hero visibility, eye position — are
## asserted, because a screenshot of a dark dungeon wall looks the same whether
## the camera is a metre from it or inside it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/first_person.gd \
##     --out=/tmp/fp/x.png --warmup=60

var _i := 0
var _fail := 0
var _cam: GameCamera = null
var _hero: Node3D = null


func run(rig) -> void:
	Input.use_accumulated_input = false
	_cam = rig.root.get_camera_3d() as GameCamera
	_hero = rig.root.get_tree().get_first_node_in_group(&"player") as Node3D
	if _cam == null or _hero == null:
		print("FP FAILED (no GameCamera or no hero)")
		return

	await rig.wait_seconds(0.5)
	var third_fwd := -_cam.global_transform.basis.z
	var boom_third := _cam.global_position.distance_to(_eye())
	_check("third person stands off on a boom (%.2f m)" % boom_third, boom_third > 1.2)
	_check("the hero is drawn in his own shot", _model_visible())
	await _shot(rig, "third")

	# --- 2. In ---------------------------------------------------------------
	_tap(&"first_person")
	await rig.wait_seconds(0.5)
	_check("the camera says it is in first person", _cam.first_person())
	var boom_fp := _cam.global_position.distance_to(_eye())
	_check("the boom is gone (%.3f m from the eye)" % boom_fp, boom_fp < 0.05)
	_check("the hero's model is not drawn", not _model_visible())

	# The whole reason first person is this camera with a zero boom: the yaw and
	# pitch the player was already holding ARE the head's. A mode that entered
	# facing anywhere else would make every glance start with a re-aim.
	var fp_fwd := -_cam.global_transform.basis.z
	var drift := rad_to_deg(third_fwd.angle_to(fp_fwd))
	_check("it looks the same way the boom did (%.1f° drift)" % drift, drift < 6.0)
	await _shot(rig, "fp_in")

	# --- 3. The stick still turns the head -----------------------------------
	for i in 3:
		Input.action_press(&"cam_left", 1.0)
		await rig.wait_seconds(0.3)
		Input.action_release(&"cam_left")
		await rig.wait_seconds(0.08)
		await _shot(rig, "fp_yaw")
	var turned := rad_to_deg(fp_fwd.angle_to(-_cam.global_transform.basis.z))
	_check("the stick turned the head (%.0f°)" % turned, turned > 30.0)

	Input.action_press(&"cam_up", 1.0)
	await rig.wait_seconds(0.35)
	Input.action_release(&"cam_up")
	await rig.wait_seconds(0.08)
	await _shot(rig, "fp_pitch")

	# --- 4. Rooted -----------------------------------------------------------
	# Not "he moves slowly": he does not move. `Hero._physics_process` reads the
	# stick as NEUTRAL while first person is up, so this is the claim that the
	# camera and the hero agree about what the mode is.
	var before := _hero.global_position
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.8)
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.2)
	var walked := before.distance_to(_hero.global_position)
	_check("he cannot walk in here (%.3f m over 0.8 s)" % walked, walked < 0.05)
	await _shot(rig, "fp_rooted")

	# --- 5. Back out ---------------------------------------------------------
	_tap(&"first_person")
	await rig.wait_seconds(0.6)
	_check("a second press leaves", not _cam.first_person())
	_check("the boom came back (%.2f m)" % _cam.global_position.distance_to(_eye()),
		_cam.global_position.distance_to(_eye()) > 1.2)
	_check("and the hero came back with it", _model_visible())
	await _shot(rig, "third_again")

	# The control for step 4, and it is not optional. "He did not move" passes
	# just as loudly when hero.gd failed to compile and the hero is a capsule
	# with no script on it — which is exactly what a concurrent edit to that file
	# produced here once, and the run reported a clean root.
	var t_before := _hero.global_position
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.8)
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.2)
	var t_walked := t_before.distance_to(_hero.global_position)
	_check("...and out here he walks again (%.2f m)" % t_walked, t_walked > 0.5)
	await _shot(rig, "third_walk")

	print("FP OK" if _fail == 0 else "FP FAILED (%d)" % _fail)


func _eye() -> Vector3:
	return _hero.global_position + Vector3.UP * K.HERO_EYE_Y


## `Hero._on_first_person_changed` hides the node it built as "Model" — the sword
## and shield hang off bone attachments underneath it and go with it.
func _model_visible() -> bool:
	var m := _hero.get_node_or_null(^"Model") as Node3D
	return m != null and m.visible


## A real event: GameCamera reads `first_person` in `_unhandled_input`, and
## `Input.action_press` dispatches no InputEvent at all (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("FP FAIL %s" % what)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
