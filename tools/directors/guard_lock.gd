extends RefCounted
## Does holding the left trigger do what holding Z does?
##
## OOT's Z is two things at once and they are easy to separate by accident: it
## locks onto what you are fighting, AND — with nothing to lock — it pins your
## facing so the stick becomes a strafe and "roll backwards" has a backwards to
## mean. The shield is on the left trigger here, which is the same index finger
## on the same shoulder, so it carries both.
##
## The claims:
##   1. Pulling the trigger raises the guard AND acquires the best candidate.
##   2. Held, it keeps looking. Take the target away and it finds the next one
##      without the player letting go — that is what makes it auto-target rather
##      than a one-shot acquire.
##   3. Releasing drops the guard and the lock it raised.
##   4. An R3 toggle-lock SURVIVES a guard press and release. The trigger owns
##      only its own lock; a deliberate toggle underneath it is the player's
##      standing decision.
##   5. The trigger's own lock is enough to buy the LUNGE. That is the point of
##      putting targeting on the guard hand: brace and leap with one finger.
##   6. With nothing lockable, guarding still pins the facing. Measured against
##      an UNGUARDED control given identical inputs: unguarded, holding left
##      turns him to face left; guarded, he slides left still facing forward.
##   7. Guarding with a neutral stick, the dodge is a BACKSTEP — he travels
##      behind himself and does not turn to look where he went.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/guard_lock.gd --out=/tmp/guard/x.png

## Frames given to the GameCamera to settle after the hero is moved. The stick is
## read camera-relative, so this is not padding — it is what makes "left" mean
## left. p4_lunge.gd pays the same 60 for the same reason.
const SETTLE := 60

var out := ""
var fails := 0
## Damage read off the post's `struck` signal rather than off its `total_damage`,
## which self-clears after a few seconds of quiet — a director that diffs the
## total across a long beat measures the reset.
var _hits: Array[int] = []
## The GameCamera rig, for the diagnostic print in `_strafe`.
var _rig_cam: Node = null


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	out = rig.arg("out", "/tmp/guard/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(24)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var combat: Node = hero.get(&"combat")
	var scene: Node = rig.scene()
	var post := scene.get_node_or_null(^"PostA") as Node3D
	_rig_cam = scene.get_node_or_null(^"GameCamera")
	if combat == null or post == null:
		_fail("no HeroCombat or no PostA")
		return

	# --- 1. the trigger raises the guard and takes the target ----------------
	# Staged looking down -Z from the middle of the floor, which is the one spot
	# with ALL THREE posts inside the acquire cone: PostC dead centre, PostA 41°
	# left, PostB 30° right, and the 60° cone is measured off the CAMERA's
	# forward, not the hero's. That matters for beat 2 rather than this one — a
	# lock swings the camera onto its target, so if the first acquire is off to
	# one side the survivors end up ~100° off the lens and the re-scan correctly
	# finds nothing. Facing the middle one, the camera barely moves and the other
	# two stay in shot.
	_stand_at(hero, Vector3(0.0, 0.05, 5.0), PI)
	await rig.wait_frames(SETTLE)
	_check("nothing is locked to begin with", hero.lock_target() == null)

	Input.action_press(&"shield")
	await rig.wait_frames(24)
	_check("the guard is up", bool(combat.get(&"blocking")))
	_check("the guard took a target (%s)" % _name(hero.lock_target()),
		hero.lock_target() != null)
	await rig.capture(out.path_join("g_00_guard_locked.png"))

	# --- 2. held, it keeps looking -------------------------------------------
	# The target is taken away rather than killed: `_validate` drops a lock whose
	# target leaves the `targetable` group, which is exactly the path a death
	# takes (enemy.gd leaves the group as it dies) without needing something in
	# the room to actually die.
	# Annotated, not inferred: `hero` is untyped here, so lock_target() gives back
	# a Variant and `:=` cannot infer (CLAUDE.md §3).
	var first: Node3D = hero.lock_target()
	if first != null:
		(first as Node).remove_from_group(&"targetable")
	await rig.wait_frames(30)
	var second: Node3D = hero.lock_target()
	_check("with the trigger still down it found another target (%s -> %s)"
		% [_name(first), _name(second)], second != null and second != first)
	await rig.capture(out.path_join("g_01_reacquired.png"))

	# --- 3. letting go drops both --------------------------------------------
	Input.action_release(&"shield")
	await rig.wait_frames(24)
	_check("the guard came down", not bool(combat.get(&"blocking")))
	_check("the lock went with it (%s)" % _name(hero.lock_target()),
		hero.lock_target() == null)
	await rig.capture(out.path_join("g_02_released.png"))

	# --- 4. an R3 toggle survives a guard --------------------------------------
	await _z_target(rig)
	var toggled: Node3D = hero.lock_target()
	_check("R3 locked something (%s)" % _name(toggled), toggled != null)
	Input.action_press(&"shield")
	await rig.wait_frames(20)
	Input.action_release(&"shield")
	await rig.wait_frames(20)
	_check("the toggled lock survived a guard press and release (%s)"
		% _name(hero.lock_target()), hero.lock_target() == toggled and toggled != null)
	# Back to nothing held, for the beats below.
	await _z_target(rig)
	_check("R3 let go again", hero.lock_target() == null)

	# --- 5. the guard is what makes the lunge reachable ----------------------
	# `heavy` with the sword out is an overhead swing on the spot UNLESS something
	# is locked, and then it is the leap (p4_lunge.gd owns that claim). Before
	# this change the only way to satisfy it was an R3 toggle; the point of
	# putting targeting on the trigger is that the guard now does it, so "brace
	# and leap at him" is one hand. The 1.5 m of closed distance below is what
	# tells the two apart — an overhead closes nothing.
	#
	# PostA has to be the only lockable thing for the same reason p4_lunge.gd
	# clears the room: acquisition is scored in SCREEN space, so from the middle
	# of the floor a different post wins and the leap is measured at a target
	# this director is not watching.
	for other in ["PostB", "PostC"]:
		var n: Node = scene.get_node_or_null(NodePath(other))
		if n != null:
			n.remove_from_group(&"targetable")
	post.connect(&"struck", _on_struck)
	_stand(hero, post, 4.2)
	await rig.wait_frames(SETTLE)
	Input.action_press(&"shield")
	# Given a second rather than a fixed 24 frames. The guard re-scans every
	# `guard_rescan` (0.15 s) and scores candidates in SCREEN space, so how long
	# the acquire takes depends on where the last beat left the camera — which is
	# why a fixed wait passed four runs and then reported "acquired nothing".
	await _wait_for_lock(rig, hero, post, 1.0)
	_check("the guard acquired PostA (%s)" % _name(hero.lock_target()),
		hero.lock_target() == post)
	var gap_before := _gap(hero, post)
	_hits.clear()
	await rig.tap(["heavy"])
	await rig.wait_frames(45)
	var gap_after := _gap(hero, post)
	Input.action_release(&"shield")
	var dmg := 0
	for h in _hits:
		dmg += h
	print("GUARD lunge from behind the guard: %.2f m -> %.2f m (closed %.2f m) dmg=%d"
		% [gap_before, gap_after, gap_before - gap_after, dmg])
	_check("the trigger's own lock buys the lunge — it closed %.2f m"
		% (gap_before - gap_after), gap_before - gap_after > 1.5)
	_check("...and landed the blow (dmg=%d)" % dmg, dmg > 0)
	await rig.capture(out.path_join("g_03_guard_lunge.png"))
	await rig.wait_frames(30)

	# --- 6. with nothing lockable, the guard still pins the facing -----------
	# Everything leaves the group, so what is under test is Z-Parallel — the half
	# of holding Z that has nothing to do with locking onto anything.
	for n in rig.get_nodes_in_group(&"targetable"):
		(n as Node).remove_from_group(&"targetable")
	await rig.wait_frames(20)

	# `await` on a coroutine yields a Variant, so both of these are annotated.
	var free_walk: Dictionary = await _strafe(rig, hero, post, false, "g_04_free_walk.png")
	var guarded: Dictionary = await _strafe(rig, hero, post, true, "g_05_guarded_strafe.png")
	print("GUARD holding left: free    hero turned %.0f deg, camera %.0f deg, went %.2f m sideways / %.2f m forward"
		% [free_walk.turned, free_walk.cam, free_walk.side, free_walk.fore])
	print("GUARD holding left: guarded hero turned %.0f deg, camera %.0f deg, went %.2f m sideways / %.2f m forward"
		% [guarded.turned, guarded.cam, guarded.side, guarded.fore])
	# Measured RELATIVE TO THE LENS, and that is the honest quantity rather than
	# a softened one. Guarding pins the facing to the camera, so the question is
	# whether the STICK turned him, and the camera does not sit perfectly still
	# while he moves: it arcs around obstructions (`_swing_bias_deg`, up to 78°),
	# which is a shot the player can see happening and is the same behaviour the
	# bow gets. Autoswing IS off under the guard — measured, rig `_yaw` moved 0°
	# across the whole strafe — so what is left is the occlusion arc alone.
	var free_stick: float = free_walk.turned - free_walk.cam
	var guard_stick: float = absf(guarded.turned - guarded.cam)
	_check("unguarded, holding left turns him to face it (%.0f deg of it his own)"
		% free_stick, free_stick > 45.0)
	_check("guarded, the stick turns him %.0f deg — he only follows the lens"
		% guard_stick, guard_stick < 12.0)
	# Without this the previous claim passes on a hero pinned against a wall, who
	# also does not turn. What is asserted is only that he MOVED, and moved
	# laterally — not that the travel is purely lateral. The training room is
	# cluttered and a body sliding along a block converts sideways travel into
	# diagonal; the free control does the same thing (1.22 m across, 0.78 m
	# along), so a "sideways beats forward" test measures the furniture.
	_check("...and he was free to move while he did not turn (%.2f m of it sideways)"
		% guarded.side, guarded.side > 0.5)

	# --- 7. the guarded backstep ---------------------------------------------
	_stand(hero, post, 4.2)
	await rig.wait_frames(SETTLE)
	Input.action_press(&"shield")
	await rig.wait_frames(20)
	await _settle_facing(rig, hero)
	var yaw0: float = hero.facing_yaw
	var fwd0: Vector3 = -hero.global_transform.basis.z
	var at: Vector3 = hero.global_position
	await rig.tap(["context"])
	# Photographed on the STATE, not on a frame count. This frame is the one that
	# matters in the whole director: `Block` is a blend sitting above the roll
	# one-shot in the animation tree, so if the guard did not drop for the dodge
	# the hero slides backwards in a standing block pose instead of diving. A
	# fixed wait cannot be trusted to land inside a 0.62 s roll on a machine
	# running two engines at once — it is what put the last pass's "backstep"
	# frame a full roll late, showing a man standing still.
	await _wait_for_state(rig, hero, Hero.MoveState.ROLL, 30)
	# A moment INTO the dive rather than on its first frame: the state flips
	# before the clip has wound up, and a photograph of a man beginning to crouch
	# does not tell you which pose he is crouching into. Counted in SECONDS, not
	# frames — the roll is 0.62 s of game time, and ten frames is a quarter of it
	# on an idle machine and all of it on a busy one, which is how this landed in
	# ROLL_RECOVER on a rerun that changed nothing.
	await rig.wait_seconds(0.15)
	_check("the dodge is a ROLL and not a block-pose slide (%d)" % int(hero.state),
		hero.state == Hero.MoveState.ROLL)
	await rig.capture(out.path_join("g_06_backstep_roll.png"))
	# Read the moment the dodge ENDS, not a fixed wait later. The claim is about
	# the roll: he must not spin round to look at where he is going. Once he is
	# back on his feet the guard comes up and pins his facing to the lens again,
	# and the lens has just travelled 4 m sideways behind him — so a yaw sampled
	# a second afterwards reports a legitimate camera-follow as a spin.
	await _wait_for_state(rig, hero, Hero.MoveState.GROUND, 120)
	var moved := Vector3(hero.global_position.x - at.x, 0.0, hero.global_position.z - at.z)
	# Metres travelled along -forward. K.flat NORMALISES, so the projection is
	# taken against the raw vector and the flattened forward, not the other way.
	var back := -K.flat(fwd0).dot(moved)
	var turned := absf(rad_to_deg(wrapf(hero.facing_yaw - yaw0, -PI, PI)))
	print("GUARD backstep travelled %.2f m, %.2f m of it backwards, turning %.0f deg"
		% [moved.length(), back, turned])
	_check("a neutral-stick dodge behind the guard went BACKWARDS (%.2f m)" % back,
		back > 0.8)
	_check("...without turning him to look at where he went (%.0f deg)" % turned,
		turned < 20.0)
	await rig.wait_frames(4)
	_check("the guard comes back up on landing", bool(combat.get(&"blocking")))
	await rig.capture(out.path_join("g_07_guard_returns.png"))
	Input.action_release(&"shield")

	print("GUARD done, %d failure(s)" % fails)


## Hold `move_left` for half a second, with or without the guard, and report how far
## the hero's facing swung and where he actually went — decomposed against the
## facing he STARTED with, since under the guard that facing is the whole point.
##
## The shot is taken mid-hold with everything still held down. Taken after the
## release, as the first pass did, it photographs a man standing at ease and
## proves nothing about the stance being measured.
func _strafe(rig, hero, post: Node3D, guard: bool, shot: String) -> Dictionary:
	_stand(hero, post, 4.2)
	await rig.wait_frames(SETTLE)
	if guard:
		Input.action_press(&"shield")
		await rig.wait_frames(20)
	# Wait for the body to STOP turning before the clock starts. Under the guard
	# the hero steers to the camera heading, and after a beat that moved him the
	# camera is still swinging round behind him — so a yaw sampled straight after
	# the trigger catches the tail of that convergence and reports it as the
	# stick having turned him. It read 0 deg from a cold start and 37 deg when
	# the beat before it had left the camera somewhere else.
	await _settle_facing(rig, hero)
	var cam := hero.get_viewport().get_camera_3d() as Node3D
	var rig_cam: Node = _rig_cam
	var cam_yaw0 := _cam_yaw(cam)
	var rig_yaw0 := float(rig_cam.get(&"_yaw")) if rig_cam != null else 0.0
	var bias0 := float(rig_cam.get(&"_swing_bias_deg")) if rig_cam != null else 0.0
	var yaw0: float = hero.facing_yaw
	var fwd0 := K.flat(-hero.global_transform.basis.z)
	var right0 := Vector3(-fwd0.z, 0.0, fwd0.x)
	var at: Vector3 = hero.global_position

	# Kept short on purpose. The training room is about 12 m across and the run is
	# 4.5 m/s, so a longer hold walks him into a wall and a wall flatters the
	# "guarded, he does not turn" claim by stopping him dead.
	Input.action_press(&"move_left")
	await rig.wait_frames(20)
	await rig.capture(out.path_join(shot))
	await rig.wait_frames(10)
	Input.action_release(&"move_left")
	await rig.wait_frames(6)

	var moved := Vector3(hero.global_position.x - at.x, 0.0, hero.global_position.z - at.z)
	var turned := absf(rad_to_deg(wrapf(hero.facing_yaw - yaw0, -PI, PI)))
	if guard:
		Input.action_release(&"shield")
		await rig.wait_frames(10)
	# The camera's own swing is reported alongside, because "the guard did not
	# hold his facing" and "the camera moved and he followed it, correctly" are
	# different bugs with the same symptom and only this number tells them apart.
	var cam_turned := absf(rad_to_deg(wrapf(_cam_yaw(cam) - cam_yaw0, -PI, PI)))
	if rig_cam != null:
		print("GUARD   [diag] guard=%s rig _yaw moved %.0f deg, wall-swing bias %.0f -> %.0f deg"
			% [guard, absf(rad_to_deg(wrapf(float(rig_cam.get(&"_yaw")) - rig_yaw0, -PI, PI))),
				bias0, float(rig_cam.get(&"_swing_bias_deg"))])
	return {"turned": turned, "cam": cam_turned,
		"side": absf(right0.dot(moved)), "fore": fwd0.dot(moved)}


## The camera's flat heading as a yaw, in the same convention as facing_yaw.
func _cam_yaw(cam: Node3D) -> float:
	if cam == null:
		return 0.0
	var f := K.flat(-cam.global_transform.basis.z)
	return atan2(f.x, f.z)


## Spin until the hero has locked onto `want`, or `secs` of game time run out.
func _wait_for_lock(rig, hero, want: Node3D, secs: float) -> void:
	var left := secs
	while left > 0.0:
		if hero.lock_target() == want:
			return
		await rig.wait_frames(2)
		left -= 2.0 / 60.0


## Spin until the hero's facing stops moving, so a measurement that starts here
## measures the input rather than the last beat's camera.
func _settle_facing(rig, hero) -> void:
	var last: float = hero.facing_yaw
	var still := 0
	for i in 90:
		await rig.wait_frames(1)
		var now: float = hero.facing_yaw
		still = still + 1 if absf(wrapf(now - last, -PI, PI)) < deg_to_rad(0.3) else 0
		last = now
		if still >= 3:
			return


## Spin until the hero reaches `want`, or give up after `cap` frames. Returns
## either way; the caller asserts on the state itself.
func _wait_for_state(rig, hero, want: int, cap: int) -> void:
	for i in cap:
		if hero.state == want:
			return
		await rig.wait_frames(1)


## Stand the hero `range_m` out from the post, facing it. Along the line toward
## the middle of the room, not along +Z: straight +Z from PostA is the far wall,
## and a hero shoved out of geometry can neither walk nor dodge (p4_lunge.gd
## learned this the expensive way).
func _stand(hero, post: Node3D, range_m: float) -> void:
	var post_pos := post.global_position
	var inward := Vector3(-post_pos.x, 0.0, -post_pos.z)
	if inward.length() < 0.01:
		inward = Vector3(0.0, 0.0, 1.0)
	inward = inward.normalized()
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): heading is
	# (sin y, 0, cos y), so this is atan2(dx, dz) of hero -> post.
	_stand_at(hero, post_pos + inward * range_m, atan2(-inward.x, -inward.z))


## Put him exactly here, facing exactly this heading.
func _stand_at(hero, at: Vector3, yaw: float) -> void:
	hero.global_position = Vector3(at.x, maxf(at.y, 0.05), at.z)
	hero.set(&"facing_yaw", yaw)
	# Put the lens behind him too. A teleport moves the hero and NOT the camera
	# yaw, and nothing brings it round on its own — autoswing needs him to be
	# running, which he is not. Left out, every beat inherits wherever the last
	# one left the camera, and since acquisition is scored in SCREEN space that
	# decides whether the guard can even see the post it is meant to lock: this
	# beat passed four runs and then reported "acquired nothing" having changed
	# nothing but the beat before it.
	Bus.camera_recenter.emit()


## The lock-on button, and the 20 frames Targeting needs to act on it.
##
## This used to hand-build an `InputEventAction` here, because `rig.tap` went
## through `Input.action_press` alone, which dispatches no `InputEvent` at all
## (CLAUDE.md §3) — and Targeting reads the toggle in `_unhandled_input`, so the
## ordinary press toggled nothing. `rig.tap` sends the event itself now (#40).
## The GUARD below is deliberately not like this: it is polled, precisely so a
## held control cannot miss an edge.
func _z_target(rig) -> void:
	await rig.tap(["z_target"])
	await rig.wait_frames(20)


func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


## Planar metres between the hero and the post.
func _gap(hero, post: Node3D) -> float:
	var d: Vector3 = hero.global_position - post.global_position
	return Vector2(d.x, d.z).length()


func _name(n) -> String:
	return String(n.name) if n != null else "nothing"


func _check(what: String, ok: bool) -> void:
	if ok:
		print("GUARD ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("GUARD FAIL %s" % what)
