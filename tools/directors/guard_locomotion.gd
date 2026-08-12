extends RefCounted
## Rendered proof that a raised shield keeps a live locomotion cycle instead of
## replacing a translating hero with the full-body `ss_block_idle_01` pose, AND
## that the cycle it keeps is the one facing the way he is actually travelling.
##
## The second half is new, and it is the half that matters. Every check in the
## first cut of this director read the guarded blend as a MAGNITUDE — "not zero"
## — which is satisfied just as well by a backpedal played while running forward
## as by a run. It passed on exactly that. `GuardLoco` is a BlendSpace2D now and
## the beats below assert the SIGN of each axis, so a clip mapped to the wrong
## direction fails here instead of shipping.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/guard_locomotion.gd \
##     --out=/tmp/guard_locomotion/x.png --warmup=60 --size=1280x720

const P_LOCO_BLEND: String = "parameters/Loco/blend_position"
const P_LOCO_SCALE: String = "parameters/LocoScale/scale"
const P_GUARD_BLEND: String = "parameters/GuardLoco/blend_position"
const P_GUARD_SCALE: String = "parameters/GuardScale/scale"
const P_BLOCK: String = "parameters/Block/blend_amount"

## Open floor in the proving ground, and it took three tries to find. Every beat
## starts CLEARANCE metres upwind of its own travel and runs for SETTLE, which at
## K.RUN_SPEED covers about 1.5 m — so the beats live inside x in [-3.5, 1.5],
## z in [-6.5, -1.5], which is clear of ALL of the following:
##
##   the +X ledge and its stairs (x from ~2.1)   `BlockTall`  (-5.4, 2,   3.6)
##   `PillarNW` (-7, 0, -5.5)                    `BlockLow`   (-2.9, 1.05, 5.4)
##   `PillarSW` (-7, 0,  5.5)                    walls at x,z = +-10
##
## Both earlier choices photographed the room instead of the blend, in the two
## ways this can go wrong, and neither announced itself:
##
##   * Run into something and the measured velocity is ZERO — which is exactly
##     what the frozen-idle regression this director exists to catch looks like.
##   * Start on top of `BlockLow` — a 1 m crate — and the hero runs off its edge
##     mid-beat. `want_block` requires `is_on_floor()` ON PURPOSE (you cannot
##     hold a shield up through a jump), so the guard came down and the beat
##     photographed FREE locomotion while reporting a guard failure. The game
##     was right and the director was wrong; `_stand_guarded` asserts the floor
##     height now so a future prop cannot repeat it quietly.
const CENTRE := Vector3(-1.0, 0.15, -4.0)
const CLEARANCE := 2.5
## Standing on the floor and not on a crate. The floor is y=0 and the hero rests a
## hair above it; `BlockLow` put him at y=1.05.
const FLOOR_Y := 0.35
## Below this the hero is against something and the beat measured nothing. Named
## separately from the blend checks so an instrument fault cannot be read as a
## finding — CLAUDE.md §2, the director is a suspect before the game is.
const MOVING := 1.0
const SLOW_STICK := 0.55
const SETTLE := 0.45
const BURST_FRAMES := 4
const BURST_GAP := 0.09


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/guard_locomotion/x.png").get_base_dir()
	_release_inputs(rig)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		rig.fail("GUARD LOCO no real Hero in training.tscn")
		_release_inputs(rig)
		return
	var hero: Node3D = players[0] as Node3D
	var tree: AnimationTree = hero.find_child("AnimTree", false, false) as AnimationTree
	var combat: Node = hero.get(&"combat") as Node
	if tree == null or combat == null:
		rig.fail("GUARD LOCO the real Hero has no AnimationTree or HeroCombat")
		_release_inputs(rig)
		return

	# Stand the training posts down. They are a fixture for lock-on framing and
	# they are two separate hazards here: they are colliders in the middle of the
	# floor, and PostA sits inside K.LOCK_RANGE — the shield button is OOT's Z, so
	# guarding beside one can acquire it, and `HeroCombat`'s `want_block` refuses
	# to raise the guard while something else owns the buttons. Both read as the
	# frozen-idle regression from the outside.
	for post in rig.get_nodes_in_group(&"lockable"):
		post.queue_free()
	for post: Node in [hero.get_parent().get_node_or_null(^"PostA"),
			hero.get_parent().get_node_or_null(^"PostB"),
			hero.get_parent().get_node_or_null(^"PostC")]:
		if post != null:
			post.queue_free()
	await rig.wait_frames(2)

	hero.global_position = CENTRE
	hero.velocity = Vector3.ZERO
	hero.set(&"facing_yaw", PI)
	Bus.camera_recenter.emit()
	await rig.wait_seconds(0.4)

	# Idle first: the shield and Block blend must both be fully raised while the
	# guarded speed axis stays on its standing pose.
	await rig.press(&"shield")
	await rig.wait_seconds(0.25)
	_check(rig, bool(combat.get(&"blocking")), "shield never raised at idle")
	_check(rig, _param(tree, P_BLOCK) > 0.95,
		"Block blend did not reach the guarded input at idle")
	_check(rig, _guard(tree).length() < 0.05,
		"guarded idle started away from the standing clip")
	await rig.capture(out.path_join("guard_00_idle.png"))

	# 0.55 is the same analogue walk probe used by p2_walk_run_stop. The action
	# API is used directly because the harness press helper is intentionally
	# digital and cannot express a partial stick.
	await _stand_guarded(rig, hero, combat, CENTRE + Vector3(0.0, 0.0, CLEARANCE), "slow forward")
	Input.action_press(&"move_up", SLOW_STICK)
	await rig.wait_seconds(SETTLE)
	var walk_point: float = float(hero.get(&"walk_blend_speed"))
	var run_point: float = float(hero.get(&"run_blend_speed"))
	var slow_blend := _guard(tree)
	_check(rig, slow_blend.y > 0.25 and slow_blend.y < walk_point,
		"slower forward input missed the guarded slower-clip region (%.2f)" % slow_blend.y)
	# The sign is the point. Forward is +y, and a backward clip selected here is
	# what the player saw as the hero moon-walking behind his shield.
	_check(rig, absf(slow_blend.x) < 0.25,
		"slower forward input leaked onto the strafe axis (%.2f)" % slow_blend.x)
	_check_stride(rig, tree, "slower forward")
	_print_state("slow_forward", hero, tree)
	await _burst(rig, out, "guard_01_slow_forward")

	Input.action_release(&"move_up")
	await _stand_guarded(rig, hero, combat, CENTRE + Vector3(0.0, 0.0, CLEARANCE), "full forward")
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(SETTLE)
	_check(rig, _param(tree, P_BLOCK) > 0.95,
		"full forward movement dropped the Block blend")
	var run_blend := _guard(tree)
	_check(rig, run_blend.y >= run_point - 0.12,
		"full forward input missed the guarded FORWARD run endpoint (%.2f / %.2f)"
		% [run_blend.y, run_point])
	_check(rig, absf(run_blend.x) < 0.25,
		"full forward input leaked onto the strafe axis (%.2f)" % run_blend.x)
	_check_stride(rig, tree, "full forward")
	_print_state("run_forward", hero, tree)
	await _burst(rig, out, "guard_02_run_forward")

	# Each direction now has its own authored clip, so each beat asserts which
	# way the blend went and not merely that it went somewhere. `axis` is the
	# component that must be positive; the other one must stay near zero.
	await _direction_beat(rig, hero, tree, out, &"move_right",
		Vector2(1.0, 0.0), "guard_03_right")
	await _direction_beat(rig, hero, tree, out, &"move_left",
		Vector2(-1.0, 0.0), "guard_04_left")
	await _direction_beat(rig, hero, tree, out, &"move_down",
		Vector2(0.0, -1.0), "guard_05_back")

	Input.action_release(&"move_down")
	await rig.wait_seconds(0.35)
	_check(rig, _guard(tree).length() < 0.05,
		"releasing movement did not return the guarded blend to idle")
	_check(rig, _param(tree, P_BLOCK) > 0.95,
		"releasing movement lowered the shield instead of keeping guarded idle")
	_print_state("released_to_idle", hero, tree)
	await rig.capture(out.path_join("guard_05_released_idle.png"))

	# Lower the shield while actually moving so Block=0 proves the free
	# locomotion chain is visible, rather than merely exchanging one idle for
	# another.
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(SETTLE)
	rig.release(&"shield")
	await rig.wait_seconds(0.25)
	_check(rig, not bool(combat.get(&"blocking")), "shield state stayed raised after release")
	_check(rig, _param(tree, P_BLOCK) < 0.05,
		"releasing shield did not return Block to zero/free locomotion")
	_check(rig, _param(tree, P_LOCO_BLEND) >= run_point - 0.12,
		"free locomotion was not at its run region after Block returned to zero")
	_print_state("free_run", hero, tree)
	await _burst(rig, out, "guard_07_free_run")

	_release_inputs(rig)
	await rig.wait_seconds(0.25)
	print("GUARD LOCO done")


func _direction_beat(rig, hero: Node3D, tree: AnimationTree, out: String,
		action: StringName, axis: Vector2, tag: String) -> void:
	_release_movement()
	# Upwind of this beat's own travel, so the run happens in open floor. The hero
	# faces facing_yaw = PI, so his forward is world -Z and his right is world +X
	# (`Hero._dodge_dir` sets out that derivation) — which is the mapping from the
	# hero-local axis this beat asserts to the world offset it needs.
	await _stand_guarded(rig, hero, hero.get(&"combat") as Node,
		CENTRE - Vector3(axis.x, 0.0, -axis.y) * CLEARANCE, tag)
	Input.action_press(action, 1.0)
	await rig.wait_seconds(SETTLE)
	var speed := Vector2(hero.velocity.x, hero.velocity.z).length()
	_check(rig, speed > MOVING,
		"%s probe never got moving (%.2f m/s) -- it is against something, so this beat measured the room and not the blend"
		% [tag, speed])
	var blend := _guard(tree)
	_check(rig, blend.length() > 0.5,
		"%s movement returned to the frozen guarded idle (%.2f)" % [tag, blend.length()])
	# Along the axis, and with the right sign: a right-step that selected the
	# left clip has the same length as one that selected the right clip.
	_check(rig, blend.dot(axis) > 0.5,
		"%s movement selected the wrong guarded direction (%s)" % [tag, blend])
	var off := blend - axis * blend.dot(axis)
	_check(rig, off.length() < 0.5 * maxf(blend.dot(axis), 0.001),
		"%s movement leaked onto the other guarded axis (%s)" % [tag, blend])
	_check(rig, _param(tree, P_GUARD_SCALE) > 0.1,
		"%s movement stopped the guarded cycle" % tag)
	_check(rig, _param(tree, P_BLOCK) > 0.95,
		"%s movement dropped the Block blend" % tag)
	_check_stride(rig, tree, tag)
	_print_state(tag, hero, tree)
	await _burst(rig, out, tag)


func _check_stride(rig, tree: AnimationTree, tag: String) -> void:
	var guard_scale := _param(tree, P_GUARD_SCALE)
	var loco_scale := _param(tree, P_LOCO_SCALE)
	_check(rig, absf(guard_scale - loco_scale) < 0.001,
		"%s guard stride %.3f differs from locomotion stride %.3f"
		% [tag, guard_scale, loco_scale])


func _check(rig, ok: bool, message: String) -> void:
	if not ok:
		rig.fail("GUARD LOCO %s" % message)


func _param(tree: AnimationTree, path: String) -> float:
	return float(tree.get(path))


## The guarded blend position, in the hero's own frame: +x is his right, +y is
## his forward, both in m/s. A Vector2 and not a float since `GuardLoco` became a
## BlendSpace2D -- see the header.
func _guard(tree: AnimationTree) -> Vector2:
	# Assigned into a typed local rather than `as Vector2`: `get()` hands back a
	# Variant and CLAUDE.md §3's "Cannot infer the type" row is the same trap.
	var v: Vector2 = tree.get(P_GUARD_BLEND)
	return v


func _print_state(tag: String, hero: Node3D, tree: AnimationTree) -> void:
	var velocity: Vector3 = hero.velocity
	var guard := _guard(tree)
	var combat: Node = hero.get(&"combat") as Node
	print("GUARD LOCO %-18s speed=%.2f guard=(%+.2f right, %+.2f fwd) scale=%.3f block=%.2f free=%.2f blocking=%s pos=%.1f,%.1f"
		% [tag, Vector2(velocity.x, velocity.z).length(),
			guard.x, guard.y, _param(tree, P_GUARD_SCALE),
			_param(tree, P_BLOCK), _param(tree, P_LOCO_BLEND),
			combat.get(&"blocking"),
			hero.global_position.x, hero.global_position.z])


func _burst(rig, out: String, tag: String) -> void:
	for i in BURST_FRAMES:
		await rig.capture(out.path_join("%s_%d.png" % [tag, i]))
		await rig.wait_seconds(BURST_GAP)


func _release_movement() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)


func _release_inputs(rig) -> void:
	_release_movement()
	rig.release(&"shield")


## Put the hero down at `at` and do not come back until he is standing on the
## floor with the shield actually up.
##
## Both halves were learned the hard way and neither is paranoia.
##
##   * **Footing.** `want_block` requires `is_on_floor()`, deliberately — you
##     cannot hold a shield up through a jump. A teleport costs a few airborne
##     frames, and the guard is down for every one of them.
##   * **The button.** Holding `shield` once at the top of the director is not
##     enough. The action state does not reliably survive a whole run — a
##     window focus change releases every pressed action at the OS level, and
##     `tools/quiet.sh` runs an unfocused window on a machine with an owner at
##     it. Measured: the full-forward beat ran with `is_action_pressed("shield")`
##     FALSE from its first frame, so it photographed free locomotion and the
##     old director's forward beats — which never asserted `Block` — passed
##     anyway. Re-press per beat; `_send` only stamps an edge on a real
##     transition, so a press that is already down is free.
##
## Fails loudly rather than warning: a beat that could not get the guard up has
## not measured guarded locomotion, whatever its blend position says.
func _stand_guarded(rig, hero: Node3D, combat: Node, at: Vector3, tag: String) -> void:
	hero.global_position = at
	hero.velocity = Vector3.ZERO
	await rig.press(&"shield")
	for _i in 40:
		await rig.wait_frames(1)
		if hero.is_on_floor() and bool(combat.get(&"blocking")):
			_check(rig, hero.global_position.y < FLOOR_Y,
				"%s started at y=%.2f -- that is a prop, not the floor, and the beat will run off its edge"
				% [tag, hero.global_position.y])
			return
	rig.fail("GUARD LOCO %s never got the guard up on solid floor (floor=%s blocking=%s btn=%s)"
		% [tag, hero.is_on_floor(), combat.get(&"blocking"),
			Input.is_action_pressed(&"shield")])
