extends RefCounted
## Does lock-on actually lock on? Prints `LOCK FAIL ...` on any beat that did not
## happen, and photographs the ones that did.
##
## The beats, in the order a player meets them:
##   1. an empty press recentres and locks nothing
##   2. a press with an enemy in front acquires it
##   3. the hero turns to FACE the target and the camera frames it
##   4. the stick strafes -- travel and facing come apart
##   5. a flick switches to the other enemy
##   6. a second press releases
##   7. killing the target releases it (the group is the authority)
##
## Beat 4 is the one worth the trouble. A lock that only moves the camera is a
## camera hint, and this project shipped without a lock at all for long enough
## that "targeting exists" and "targeting does something" need separating.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/lockon_check.gd --out=/tmp/lock/x.png

## Degrees of facing error we will call "looking at it".
const FACE_TOL := 22.0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/lock/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 8.0)
	await rig.wait_frames(12)

	var t = hero.targeting
	if t == null:
		print("LOCK FAIL hero has no targeting node")
		return

	# --- 1. empty press ------------------------------------------------------
	_press(t)
	await rig.wait_frames(4)
	if t.is_locked:
		print("LOCK FAIL locked onto something with nothing in range")
	else:
		print("LOCK ok  empty press locked nothing")

	# --- spawn two, offset so one is clearly left of the other ---------------
	var a := Enemy.new()
	a.kind = &"goblin"
	a.drop_seed = 41
	scene.add_child(a)
	a.global_position = Vector3(-1.8, 0.05, 3.2)

	var b := Enemy.new()
	b.kind = &"skeleton"
	b.drop_seed = 42
	scene.add_child(b)
	b.global_position = Vector3(2.2, 0.05, 3.4)
	await rig.wait_frames(30)

	# The hero has to be LOOKING at them for a screen-space scan to see them.
	hero.global_position = Vector3(0.0, 0.05, 8.0)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)

	# --- 2. acquire ----------------------------------------------------------
	_press(t)
	await rig.wait_frames(6)
	if not t.is_locked:
		print("LOCK FAIL press with two enemies in the cone acquired nothing")
		return
	var first = t.current_target
	print("LOCK ok  acquired %s" % _name_of(first))

	# --- 3. facing and framing ----------------------------------------------
	await rig.wait_frames(50)
	var err := _facing_error(hero, first)
	if err > FACE_TOL:
		print("LOCK FAIL hero is %.1f deg off the target (tol %.1f)" % [err, FACE_TOL])
	else:
		print("LOCK ok  hero faces the target, %.1f deg off" % err)
	await rig.capture(out.path_join("lock_00_acquired.png"))

	# --- 4. strafe: travel and facing must come apart ------------------------
	# Hold "left" for a beat and check he circles rather than turning away.
	Input.action_press(&"move_left", 1.0)
	await rig.wait_frames(26)
	var travel: Vector3 = K.flat(hero.velocity)
	var face_err := _facing_error(hero, first)
	Input.action_release(&"move_left")

	if travel.length() < 0.5:
		print("LOCK FAIL strafe input produced no movement (%.2f m/s)" % travel.length())
	elif face_err > FACE_TOL:
		print("LOCK FAIL hero turned away while strafing, %.1f deg off" % face_err)
	else:
		var between := rad_to_deg(travel.normalized().angle_to(
			-hero.global_transform.basis.z))
		print("LOCK ok  strafing at %.2f m/s, %.0f deg off his own facing, still %.1f deg on target"
			% [travel.length(), between, face_err])
		if between < 30.0:
			print("LOCK FAIL travel and facing are the same vector -- not strafing, just running")
	await rig.capture(out.path_join("lock_01_strafe.png"))

	# --- 5. switch -----------------------------------------------------------
	# Straight at the switch entry point: the stick flick is read by polling and
	# action_press does not dispatch an event, but _read_stick_flick polls too.
	var before = t.current_target
	t._switch(1 if _screen_x(t, before) < 0.0 else -1)
	await rig.wait_frames(8)
	if t.current_target == before:
		print("LOCK FAIL flick did not move the lock off %s" % _name_of(before))
	else:
		print("LOCK ok  flick moved the lock %s -> %s"
			% [_name_of(before), _name_of(t.current_target)])
	await rig.capture(out.path_join("lock_02_switched.png"))

	# --- 6. release ----------------------------------------------------------
	_press(t)
	await rig.wait_frames(4)
	if t.is_locked:
		print("LOCK FAIL second press did not release")
	else:
		print("LOCK ok  second press released")

	# --- 7. the target dying releases it -------------------------------------
	_press(t)
	await rig.wait_frames(6)
	if not t.is_locked:
		print("LOCK FAIL could not re-acquire for the death test")
	else:
		var victim = t.current_target
		var hp := _health(victim)
		if hp == null:
			print("LOCK skip %s has no HealthComponent" % _name_of(victim))
		else:
			hp.apply_hit(Hit.make(9999, hero.global_position, &"sword", 0.0))
			await rig.wait_frames(30)
			if t.is_locked and t.current_target == victim:
				print("LOCK FAIL still locked onto a dead target")
			else:
				print("LOCK ok  the lock dropped when the target died")
	await rig.capture(out.path_join("lock_03_after_death.png"))
	print("LOCK done")


## The button, not the binding. `Input.action_press` sets action state but
## dispatches NO InputEvent (CLAUDE.md §3), and Targeting reads the press in
## _unhandled_input precisely so it cannot miss an edge -- so a director has to
## deliver a real event or nothing happens at all.
func _press(t) -> void:
	var ev := InputEventAction.new()
	ev.action = &"z_target"
	ev.pressed = true
	Input.parse_input_event(ev)


func _facing_error(hero, target) -> float:
	if target == null or not is_instance_valid(target):
		return 999.0
	var to := K.flat(target.global_position - hero.global_position)
	if to == Vector3.ZERO:
		return 0.0
	return rad_to_deg(K.flat(-hero.global_transform.basis.z).angle_to(to))


func _screen_x(t, node) -> float:
	# Annotated, not inferred: `t` is untyped so get_viewport() returns Variant,
	# and indexing a Variant is the "cannot infer the type of X" parse error
	# CLAUDE.md §3 lists. A director that fails to PARSE fails to `new()`, which
	# surfaces as "Nonexistent function 'new' in base 'GDScript'" -- a message
	# that points nowhere near the real line.
	var cam: Camera3D = t.get_viewport().get_camera_3d()
	if cam == null or node == null:
		return 0.0
	var half: float = float(cam.get_viewport().size.x) * 0.5
	return cam.unproject_position(node.global_position).x - half


func _health(n: Node) -> HealthComponent:
	for c in n.get_children():
		if c is HealthComponent:
			return c
	return null


func _name_of(n: Node) -> String:
	if n == null:
		return "<null>"
	var kind = n.get(&"kind")
	return String(kind) if kind != null else n.name
