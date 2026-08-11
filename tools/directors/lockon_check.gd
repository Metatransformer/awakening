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
##   8. FREEING the target releases it too, in the same frame, with no cast
##      failure in the log (issue #59)
##
## Beat 4 is the one worth the trouble. A lock that only moves the camera is a
## camera hint, and this project shipped without a lock at all for long enough
## that "targeting exists" and "targeting does something" need separating.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
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
	await rig.tap(["z_target"])
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
	await rig.tap(["z_target"])
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
	# **Put him back first.** Beat 4 walks him 26 frames to the left, which under
	# an honest 16:9 frame carries the skeleton off the side of the screen -- and
	# `_best_candidate` searches SCREEN SPACE, so a flick then has nothing to find
	# and this beat failed on a lock-on that was working perfectly. It passed for as
	# long as the harness rendered a 2.5:1 window and squashed it into the PNG (#35):
	# the camera keeps its HEIGHT, so that window saw about 40% more of the yard
	# sideways than a player ever will, and the skeleton stayed in shot. The beat is
	# about the flick, not about how far off-screen the previous beat left things.
	hero.global_position = Vector3(0.0, 0.05, 8.0)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)

	# Straight at the switch entry point: the stick flick is read by polling and
	# action_press does not dispatch an event, but _read_stick_flick polls too.
	#
	# The direction is taken from where the OTHER body is relative to the one we
	# hold, which is the question `_best_candidate(side)` actually asks. It used to
	# be `1 if _screen_x(before) < 0 else -1` -- flick away from whichever half of
	# the screen the current target sits in -- and that is only the same thing while
	# the frame is wide enough to keep the hero between the two of them. On the
	# honest 16:9 frame the goblin sits just right of centre with the skeleton
	# further right again, so the old rule flicked LEFT into an empty half and
	# reported a switch failure against a lock-on that had done nothing wrong.
	var before = t.current_target
	var other: Node3D = b if before == a else a
	t._switch(1 if _screen_x(t, other) > _screen_x(t, before) else -1)
	await rig.wait_frames(8)
	if t.current_target == before:
		print("LOCK FAIL flick did not move the lock off %s" % _name_of(before))
	else:
		print("LOCK ok  flick moved the lock %s -> %s"
			% [_name_of(before), _name_of(t.current_target)])
	await rig.capture(out.path_join("lock_02_switched.png"))

	# --- 6. release ----------------------------------------------------------
	await rig.tap(["z_target"])
	await rig.wait_frames(4)
	if t.is_locked:
		print("LOCK FAIL second press did not release")
	else:
		print("LOCK ok  second press released")

	# --- 7. the target dying releases it -------------------------------------
	await rig.tap(["z_target"])
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

	# --- 8. the target being FREED under the lock ----------------------------
	#
	# Beat 7 is the game's own death, and it passes on the group: `Enemy` leaves
	# `targetable` as it dies and `_validate` drops the lock long before anything
	# is deleted. This beat is the other half — the body simply GONE — and it is
	# the one that caught issue #59: `boss_cistern.gd`'s section L frees the last
	# fight's boss while the hero still holds a lock on it, then asks
	# `hero.lock_target()`, and the answer was
	# `SCRIPT ERROR: Trying to cast a freed object` for one tick. **That run
	# passed with the error in its output**, which is why the beat is written to
	# ask the question at the exact instant it is unanswerable.
	#
	# `free()` and not `queue_free()`, deliberately: a queued free lands at the
	# end of the frame and `_validate` runs at 60 Hz against a harness drawing at
	# about 22, so `queue_free` + `wait_frames(1)` gives the sweep three chances
	# to close the window before this beat can look through it. The dangling-field
	# state would then be real in the game and absent from the director, which is
	# exactly the failure mode being fixed. An immediate free reproduces it on
	# demand — and if the lock is dropped on `tree_exiting`, both spellings are
	# equally safe.
	await rig.tap(["z_target"])
	await rig.wait_frames(6)
	if not t.is_locked:
		print("LOCK skip nothing left to lock for the freed-target beat")
	else:
		# Read the name BEFORE the free; asking a corpse for its `kind` is the
		# same class of error this beat exists to catch.
		var doomed: String = _name_of(t.current_target)
		(t.current_target as Node).free()
		# No `await`. Every line below runs in the same frame as the free, which
		# is the whole window.
		var after = hero.lock_target()
		if after != null:
			print("LOCK FAIL lock_target() still returns something after %s was freed"
				% doomed)
		else:
			print("LOCK ok  lock_target() is null the instant %s is freed" % doomed)
		if t.current_target != null:
			print("LOCK FAIL Targeting still holds %s after it left the tree" % doomed)
		elif t.is_locked:
			print("LOCK FAIL Targeting is still locked with no target")
		else:
			print("LOCK ok  the lock dropped on the frame the body left the tree")
	await rig.wait_frames(6)
	await rig.capture(out.path_join("lock_04_after_free.png"))
	print("LOCK done")



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
