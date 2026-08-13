extends RefCounted
## The Heavy button is one two-hit combo: dash-spin, then leaping overhead.
## LT and lock-on do not select another move; holding Heavy still substitutes the
## charged magic spin for the tap path.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/heavy_combo.gd \
##     --out=/tmp/heavy_combo/x.png --warmup=60

const ST_ATTACK := 4 # Hero.MoveState.ATTACK
const CLIP_DASH := &"parameters/SwingDash/active"
const CLIP_FINISHER := &"parameters/Swing3/active"
const CLIP_LUNGE := &"parameters/SwingLunge/active"
const CLIP_SPIN := &"parameters/SwingSpin/active"
const HEAVY_CLIPS: Array[StringName] = [
	CLIP_DASH, CLIP_FINISHER, CLIP_LUNGE, CLIP_SPIN,
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/heavy_combo/x.png").get_base_dir()
	var hero := rig.scene().get_node_or_null(^"Hero") as Hero
	if hero == null or hero.combat == null:
		rig.fail("HEAVY COMBO no real Hero/HeroCombat in training.tscn")
		return
	var combat: HeroCombat = hero.combat
	var tree: AnimationTree = hero.get(&"_tree") as AnimationTree
	if tree == null:
		rig.fail("HEAVY COMBO no AnimationTree")
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _reset(rig, hero, combat)
	await _neutral_buffered_combo(rig, hero, combat, tree, out)
	await _guarded_combo(rig, hero, combat, tree, out)
	await _locked_opener(rig, hero, combat, tree)
	await _held_magic_spin(rig, hero, combat, tree, out)
	print("HEAVY COMBO done -- %d failed checks" % rig.fails)


## Tap once, then buffer the second release during the opener. A third tap after
## completion must wrap to the opener rather than inventing a third step.
func _neutral_buffered_combo(rig, hero: Hero, combat: HeroCombat,
		tree: AnimationTree, out: String) -> void:
	await rig.tap([&"heavy"])
	var first: StringName = await _next_heavy_clip(rig, hero, tree, 60)
	if first != CLIP_DASH:
		rig.fail("HEAVY COMBO neutral first tap played %s, wanted SwingDash" % first)
		return

	# The input is made while step one still owns the hero. `_press` must buffer it
	# and resolve HEAVY only after the opener, when `_heavy_step` is already one.
	var late: bool = await rig.until(func() -> bool:
		return float(combat.get(&"_swing_t")) / maxf(
			float(combat.get(&"_swing_dur")), 0.01) >= combat.chain_buffer_from, 0.8)
	if not late:
		rig.fail("HEAVY COMBO opener never reached its buffer window")
		return
	await rig.tap([&"heavy"])
	var second: StringName = await _wait_for_clip(rig, hero, tree, CLIP_FINISHER, 100)
	if second != CLIP_FINISHER:
		rig.fail("HEAVY COMBO buffered second tap did not play Swing3")
		return
	await rig.capture(out.path_join("heavy_02_leaping_finisher.png"))
	await _wait_idle(rig, hero)
	if int(combat.get(&"_heavy_step")) != 0:
		rig.fail("HEAVY COMBO did not reset after step two")

	await rig.tap([&"heavy"])
	var third: StringName = await _next_heavy_clip(rig, hero, tree, 60)
	if third != CLIP_DASH:
		rig.fail("HEAVY COMBO third tap played %s, wanted the opener again" % third)
	else:
		await rig.capture(out.path_join("heavy_01_dash_opener.png"))
	await _wait_idle(rig, hero)


## Keep LT down for both pulls. The exact same clips must play in the exact same
## order, and the press itself must only wind up: the short release starts step 1.
func _guarded_combo(rig, hero: Hero, combat: HeroCombat,
		tree: AnimationTree, out: String) -> void:
	await _reset(rig, hero, combat)
	await rig.press(&"shield")
	var guarded: bool = await rig.until(func() -> bool: return combat.blocking, 0.5)
	if not guarded:
		rig.fail("HEAVY COMBO LT never raised the guard")
		return

	await rig.press(&"heavy")
	await rig.wait_physics_frames(2)
	if hero.state == ST_ATTACK:
		rig.fail("HEAVY COMBO guard changed Heavy into an immediate press attack")
	if float(combat.get(&"_charge_t")) < 0.0:
		rig.fail("HEAVY COMBO guarded Heavy did not arm the shared wind-up")
	rig.release(&"heavy")
	var first: StringName = await _next_heavy_clip(rig, hero, tree, 60)
	if first != CLIP_DASH:
		rig.fail("HEAVY COMBO guarded first tap played %s, wanted SwingDash" % first)
	await _wait_idle(rig, hero)

	await rig.tap([&"heavy"])
	var second: StringName = await _next_heavy_clip(rig, hero, tree, 90)
	if second != CLIP_FINISHER:
		rig.fail("HEAVY COMBO guarded second tap played %s, wanted Swing3" % second)
	else:
		await rig.capture(out.path_join("heavy_03_guarded_finisher.png"))
	rig.release(&"shield")
	await _wait_idle(rig, hero)


## Lock a real target and prove it cannot replace Heavy step one with SwingLunge.
func _locked_opener(rig, hero: Hero, combat: HeroCombat, tree: AnimationTree) -> void:
	await _reset(rig, hero, combat)
	await rig.tap([&"z_target"])
	var locked: bool = await rig.until(func() -> bool:
		return hero.lock_target() != null, 1.0)
	if not locked:
		rig.fail("HEAVY COMBO lock control acquired no training post")
		return
	await rig.tap([&"heavy"])
	var clip: StringName = await _next_heavy_clip(rig, hero, tree, 60)
	if clip == CLIP_LUNGE:
		rig.fail("HEAVY COMBO lock-on still replaced Heavy with SwingLunge")
	elif clip != CLIP_DASH:
		rig.fail("HEAVY COMBO locked first tap played %s, wanted SwingDash" % clip)
	await _wait_idle(rig, hero)
	await rig.tap([&"z_target"])


## Holding is the alternative path: no ordinary swing during the hold and one
## charged spin on release, with the two-hit chain still at its opener afterward.
func _held_magic_spin(rig, hero: Hero, combat: HeroCombat,
		tree: AnimationTree, out: String) -> void:
	await _reset(rig, hero, combat)
	Game.fill_magic()
	var magic_before: int = Game.magic
	await rig.press(&"shield")
	await rig.wait_frames(4)
	await rig.press(&"heavy")
	await rig.wait_seconds(combat.charge_time + 0.18)
	if hero.state == ST_ATTACK or _active(tree, CLIP_DASH) or _active(tree, CLIP_FINISHER):
		rig.fail("HEAVY COMBO held Heavy fired an ordinary combo step during the hold")
	if not combat.charged:
		rig.fail("HEAVY COMBO held Heavy never armed the magic spin")
	await rig.capture(out.path_join("heavy_04_magic_charge.png"))
	rig.release(&"heavy")
	var clip: StringName = await _next_heavy_clip(rig, hero, tree, 60)
	if clip != CLIP_SPIN:
		rig.fail("HEAVY COMBO charged release played %s, wanted SwingSpin" % clip)
	else:
		await rig.capture(out.path_join("heavy_05_magic_spin.png"))
	await _wait_idle(rig, hero)
	if Game.magic != magic_before - K.MAGIC_SPIN:
		rig.fail("HEAVY COMBO charged release spent %d magic, wanted %d"
			% [magic_before - Game.magic, K.MAGIC_SPIN])
	if int(combat.get(&"_heavy_step")) != 0:
		rig.fail("HEAVY COMBO magic spin left the ordinary combo advanced")
	await rig.wait_seconds(combat.chain_window + 0.1)
	if hero.state == ST_ATTACK:
		rig.fail("HEAVY COMBO charged pull paid out a second attack")
	rig.release(&"shield")


func _next_heavy_clip(rig, _hero: Hero, tree: AnimationTree,
		max_frames: int) -> StringName:
	for _i in max_frames:
		for path: StringName in HEAVY_CLIPS:
			if _active(tree, path):
				return path
		await rig.wait_frames(1)
	return &""


func _wait_for_clip(rig, _hero: Hero, tree: AnimationTree,
		want: StringName, max_frames: int) -> StringName:
	for _i in max_frames:
		if _active(tree, want):
			return want
		await rig.wait_frames(1)
	return &""


func _active(tree: AnimationTree, path: StringName) -> bool:
	return bool(tree.get(path))


func _wait_idle(rig, hero: Hero) -> void:
	var finished: bool = await rig.until(func() -> bool:
		return hero.state != ST_ATTACK, 2.0)
	if not finished:
		rig.fail("HEAVY COMBO attack never returned control")
	await rig.wait_physics_frames(2)


func _reset(rig, hero: Hero, combat: HeroCombat) -> void:
	rig.release(&"heavy")
	rig.release(&"shield")
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	combat.call(&"_reset_heavy_combo")
	combat.set(&"_buffer", -1)
	combat.set(&"_buffer_t", 0.0)
	await _wait_idle(rig, hero)
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	hero.velocity = Vector3.ZERO
	hero.facing_yaw = PI
	await rig.wait_physics_frames(2)
	await rig.wait_seconds(combat.chain_window + 0.08)
