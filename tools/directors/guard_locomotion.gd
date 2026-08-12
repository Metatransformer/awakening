extends RefCounted
## Rendered proof that a raised shield keeps a live locomotion cycle instead of
## replacing a translating hero with the full-body `ss_block_idle_01` pose.
## The guarded clips are forward-authored, so side and backward beats prove the
## frozen slide is gone; they do not claim directional guard clips exist.
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

const START := Vector3(0.0, 0.15, 2.5)
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

	hero.global_position = START
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
	_check(rig, _param(tree, P_GUARD_BLEND) < 0.05,
		"guarded idle started away from the standing clip")
	await rig.capture(out.path_join("guard_00_idle.png"))

	# 0.55 is the same analogue walk probe used by p2_walk_run_stop. The action
	# API is used directly because the harness press helper is intentionally
	# digital and cannot express a partial stick.
	Input.action_press(&"move_up", SLOW_STICK)
	await rig.wait_seconds(SETTLE)
	var walk_point: float = float(hero.get(&"walk_blend_speed"))
	var run_point: float = float(hero.get(&"run_blend_speed"))
	var slow_blend := _param(tree, P_GUARD_BLEND)
	_check(rig, slow_blend > 0.25 and slow_blend < walk_point,
		"slower forward input missed the guarded slower-clip region (%.2f)" % slow_blend)
	_check_stride(rig, tree, "slower forward")
	_print_state("slow_forward", hero, tree)
	await _burst(rig, out, "guard_01_slow_forward")

	Input.action_release(&"move_up")
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(SETTLE)
	var run_blend := _param(tree, P_GUARD_BLEND)
	_check(rig, run_blend >= run_point - 0.12,
		"full forward input missed the guarded run endpoint (%.2f / %.2f)"
		% [run_blend, run_point])
	_check_stride(rig, tree, "full forward")
	_print_state("run_forward", hero, tree)
	await _burst(rig, out, "guard_02_run_forward")

	# These clips are forward-authored. What matters for this package is that a
	# planar strafe or retreat still selects a nonzero, time-scaled guarded cycle
	# instead of restoring the frozen block pose while the body translates.
	await _direction_beat(rig, hero, tree, out, &"move_right", "guard_03_side")
	await _direction_beat(rig, hero, tree, out, &"move_down", "guard_04_back")

	Input.action_release(&"move_down")
	await rig.wait_seconds(0.35)
	_check(rig, _param(tree, P_GUARD_BLEND) < 0.05,
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
	await _burst(rig, out, "guard_06_free_run")

	_release_inputs(rig)
	await rig.wait_seconds(0.25)
	print("GUARD LOCO done")


func _direction_beat(rig, hero: Node3D, tree: AnimationTree, out: String,
		action: StringName, tag: String) -> void:
	_release_movement()
	# Each beat starts in the open centre. The preceding forward burst otherwise
	# reaches the training-room wall before the retreat probe and collision turns
	# a valid full-stick input into a zero measured velocity.
	hero.global_position = START
	hero.velocity = Vector3.ZERO
	Input.action_press(action, 1.0)
	await rig.wait_seconds(SETTLE)
	var blend := _param(tree, P_GUARD_BLEND)
	_check(rig, blend > 0.5,
		"%s movement returned to the frozen guarded idle (%.2f)" % [tag, blend])
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


func _print_state(tag: String, hero: Node3D, tree: AnimationTree) -> void:
	var velocity: Vector3 = hero.velocity
	print("GUARD LOCO %-18s speed=%.2f guard=%.2f scale=%.3f block=%.2f free=%.2f"
		% [tag, Vector2(velocity.x, velocity.z).length(),
			_param(tree, P_GUARD_BLEND), _param(tree, P_GUARD_SCALE),
			_param(tree, P_BLOCK), _param(tree, P_LOCO_BLEND)])


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
