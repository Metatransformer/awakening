extends RefCounted
## Issue #203: live proof of the shared boss/miniboss combat grammar.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_boss_test.tscn \
##     --director=res://tools/directors/boss_dynamism.gd \
##     --out=/tmp/boss-dynamism/x.png --warmup=60
##
## Calibration: append `--sabotage=bypass-armour`. The first Warden control
## blow is sent to the health child instead of the actor contract; B1 must fail
## while the fixture is restored immediately afterwards and every other check
## stays honest.
##
## Boss is loaded by path rather than named here. A director is often the first
## consumer compiled after a class-cache change, and naming a newly-added
## `class_name` is the parse failure recorded by boss_cistern.gd's header.

const BOSS_SCRIPT := "res://scripts/actors/enemies/boss.gd"
const SABOTAGE := "bypass-armour"
const START_BOSS := Vector3(0.0, 0.05, -3.0)
const START_HERO := Vector3(0.0, 0.05, 3.0)
const CHAIN: Array[int] = [2, 2, 4]

const IDS: Array[StringName] = [
	&"cistern_warden", &"slag_ogre", &"bellwake", &"riven_knight",
	&"sluice_keeper", &"bellows_hand", &"second_voice", &"gate_hound",
]

## Literal expected answers on purpose. Comparing BossDb to a second lookup
## generated from BossDb would only prove that a dictionary agrees with itself.
static var EXPECTED := {
	&"cistern_warden": {"kind": &"sword", "beat": &"cistern_drop",
		"open": &"recover", "goal": 4},
	&"slag_ogre": {"kind": &"arrow", "beat": &"bellows_charge",
		"open": &"charge", "goal": 4},
	&"bellwake": {"kind": &"bomb", "beat": &"undertow",
		"open": &"zones", "goal": 4},
	&"riven_knight": {"kind": &"hookshot", "beat": &"call_the_iron",
		"open": &"recover", "goal": 4},
	&"sluice_keeper": {"kind": &"sword", "beat": &"flood_stomp",
		"open": &"recover", "goal": 3},
	&"bellows_hand": {"kind": &"arrow", "beat": &"plate_advance",
		"open": &"charge", "goal": 3},
	&"second_voice": {"kind": &"bomb", "beat": &"keening",
		"open": &"zones", "goal": 3},
	&"gate_hound": {"kind": &"hookshot", "beat": &"overhand",
		"open": &"zones", "goal": 3},
}

var out := ""
var _fails := 0
var _sabotage := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/boss-dynamism/x.png").get_base_dir()
	_sabotage = rig.arg("sabotage", "")
	if _sabotage != "" and _sabotage != SABOTAGE:
		_ck("unknown --sabotage=%s (expected %s)" % [_sabotage, SABOTAGE], false)
		return
	if _sabotage == SABOTAGE:
		print("DYNAMISM CALIBRATION --sabotage=%s -- B1 is SUPPOSED to fail"
			% _sabotage)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Game.reset()
	Run.level = 1
	await _clear_fixture(rig)

	_table_contract()
	await _movement_contract(rig)
	await _segment_cap_control(rig)
	for id in IDS:
		await _row_fight(rig, id)

	if _fails == 0:
		print("DYNAMISM OK -- every check passed")
	else:
		print("DYNAMISM FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("DYNAMISM ok %s" % label)
	else:
		_fails += 1
		print("DYNAMISM FAIL %s" % label)


# --- A/D. The authored contracts ---------------------------------------------

func _table_contract() -> void:
	var problems := BossDb.validate()
	for problem in problems:
		_ck("A0 BossDb: %s" % problem, false)
	_ck("A0 BossDb.validate() is clean", problems.is_empty())
	_ck("A1 the roster contains exactly four bosses and four minibosses",
		BossDb.all().size() == 4 and BossDb.all_minibosses().size() == 4)

	for id in IDS:
		var row := BossDb.get_boss(id)
		var authored: Dictionary = row.get("stagger", {})
		var expected: Dictionary = EXPECTED[id]
		var exact: bool = authored.get("kind", &"") == expected["kind"] \
			and authored.get("beat", &"") == expected["beat"] \
			and authored.get("open", &"") == expected["open"] \
			and int(authored.get("goal", 0)) == int(expected["goal"])
		_ck("A2 %s item=%s beat=%s exposure=%s goal=%d"
			% [id, expected["kind"], expected["beat"], expected["open"],
				int(expected["goal"])], exact)

		var movement: Dictionary = row.get("movement", {})
		var p1: Dictionary = movement.get("phase_1", {})
		var p2: Dictionary = movement.get("phase_2", {})
		_ck("D0 %s phase 2 is faster, closer, and presses harder" % id,
			float(p2.get("speed", 0.0)) > float(p1.get("speed", 0.0))
			and float(p2.get("orbit_radius", INF)) < float(p1.get("orbit_radius", 0.0))
			and float(p2.get("orbit_strength", 0.0)) \
				> float(p1.get("orbit_strength", 0.0)))
		var weak := BossDb.beat(id, expected["beat"])
		_ck("D1 %s dangerous beat weight changes upward in phase 2" % id,
			float(weak.get("phase_2_weight", 0.0)) > float(weak.get("weight", 0.0)))


# --- D/E. Deterministic live movement ---------------------------------------

func _movement_contract(rig) -> void:
	var p1 := await _motion_sample(rig, false)
	var p2 := await _motion_sample(rig, true)
	print("DYNAMISM movement Warden: phase1 %.3f m -> r %.3f; "
		% [float(p1["moved"]), float(p1["radius"])]
		+ "phase2 %.3f m -> r %.3f" % [float(p2["moved"]), float(p2["radius"])])
	_ck("D2 live phase 2 displacement exceeds phase 1 (%.3f > %.3f)"
		% [float(p2["moved"]), float(p1["moved"])],
		float(p2["moved"]) > float(p1["moved"]) * 1.12)
	_ck("E1 live phase 2 closes its orbit further (%.3f < %.3f)"
		% [float(p2["radius"]), float(p1["radius"])],
		float(p2["radius"]) < float(p1["radius"]) - 0.05)
	_ck("E2 neither phase stands on a static ring",
		float(p1["moved"]) > 0.45 and float(p2["moved"]) > 0.60)


func _motion_sample(rig, phase_two: bool) -> Dictionary:
	var boss := await _spawn_boss(rig, &"cistern_warden", Vector3(0.0, 0.05, -6.0))
	var hero := _hero(rig)
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	if phase_two:
		boss.enter_phase_two()
	boss.wake()
	var start: Vector3 = boss.global_position
	await rig.wait_seconds(0.48)
	var result := {
		"moved": K.plane(boss.global_position - start).length(),
		"radius": K.plane(boss.global_position - hero.global_position).length(),
	}
	await _discard(rig, boss)
	return result


# --- B/C. Actor gate, true stagger, segments, and exact kill -----------------

func _segment_cap_control(rig) -> void:
	var boss := await _spawn_boss(rig, &"cistern_warden", START_BOSS)
	boss.wake()
	await _stage(rig, boss)
	boss.force_beat(&"cistern_drop")
	var opened := await _until(rig, func() -> bool: return boss.is_weakpoint_open(), 700)
	_ck("C0 cap fixture opened the authored aperture", opened)
	if not opened:
		await _discard(rig, boss)
		return
	var before: int = boss.health.health_points
	boss.apply_hit(Hit.make(1, _hero(rig).global_position, &"sword"))
	_ck("C0b cap fixture entered true stagger without weak-point damage",
		boss.is_vulnerable() and boss.health.health_points == before)
	boss.apply_hit(Hit.make(999, _hero(rig).global_position, &"sword"))
	await rig.wait_frames(2)
	var loss: int = before - boss.health.health_points
	_ck("C1 oversized hit spends one segment only (%d HP, cap %d)"
		% [loss, boss.segment_capacity()],
		loss == boss.segment_capacity() and boss.health.health_points > 0)
	_ck("C2 cap closes the stagger at exactly its budget",
		boss.segment_damage() == boss.segment_capacity() and not boss.is_vulnerable())
	await _discard(rig, boss)


func _row_fight(rig, id: StringName) -> void:
	var expected: Dictionary = EXPECTED[id]
	var boss := await _spawn_boss(rig, id, START_BOSS)
	var phases: Array[int] = []
	boss.phase_changed.connect(func(value: int) -> void: phases.append(value))
	boss.wake()
	await _stage(rig, boss)

	var full_hp: int = boss.health.health_points
	var control := Hit.make(1, _hero(rig).global_position, &"sword")
	if _sabotage == SABOTAGE and id == &"cistern_warden":
		boss.health.apply_hit(control)
	else:
		boss.apply_hit(control)
	_ck("B1 %s ordinary root hit outside true stagger changes HP by 0" % id,
		boss.health.health_points == full_hp)
	# The sabotage changes only the routing check. Restore this disposable fixture
	# before the actual grammar proof so later failures cannot be its echo.
	if boss.health.health_points != full_hp:
		boss.health.health_points = full_hp
		await rig.wait_seconds(0.24)

	var goal := int(expected["goal"])
	_ck("C3 %s public goal is %d" % [id, goal], boss.stagger_goal() == goal)
	var cap: int = boss.segment_capacity()
	var crossed_half := false
	for window in goal:
		if boss.health.dead:
			_ck("C4 %s survived until promised window %d" % [id, goal], false)
			break
		Game.heal(999)
		await _stage(rig, boss)
		boss.force_beat(expected["beat"])

		var began := await _until(rig, func() -> bool:
			return boss.current_beat() == expected["beat"] \
				and boss.state == Enemy.State.WINDUP, 700)
		_ck("C4 %s window %d forced the live %s beat"
			% [id, window + 1, expected["beat"]], began)
		if not began:
			continue

		if id == &"cistern_warden" and window == 0:
			await _warden_leap(rig, boss)
		var opened := await _until(rig, func() -> bool:
			return boss.is_weakpoint_open(), 700)
		_ck("B2 %s window %d opened its live %s aperture"
			% [id, window + 1, expected["open"]], opened)
		if not opened:
			continue

		if id == &"bellwake" and window == 0:
			await _bellwake_throw(rig, boss)
		if window == 0:
			await _capture(rig, "%s_weakpoint.png" % id)
		if id == &"cistern_warden" and window == 0:
			await _capture(rig, "warden_03_weakpoint.png")
		if id == &"gate_hound" and window == 0:
			await _capture(rig, "miniboss_gate_hound_01_weakpoint.png")

		var hp_before_break: int = boss.health.health_points
		if window == 0:
			var wrong := _wrong_kind(expected["kind"])
			boss.apply_hit(Hit.make(9, _hero(rig).global_position, wrong))
			_ck("B3 %s wrong %s hit leaves aperture open and HP unchanged"
				% [id, wrong], boss.health.health_points == hp_before_break
				and boss.is_weakpoint_open() and not boss.is_vulnerable())

		_break_aperture(boss, expected["kind"])
		_ck("B4 %s correct %s breaks aperture for 0 HP"
			% [id, expected["kind"]], boss.health.health_points == hp_before_break
			and boss.is_vulnerable() and not boss.is_weakpoint_open())
		_ck("C5 %s true stagger count is %d/%d"
			% [id, window + 1, goal], boss.stagger_count() == window + 1)

		if window == 0:
			await _capture(rig, "%s_stagger.png" % id)
			if id == &"cistern_warden":
				await _capture(rig, "warden_04_stagger.png")
		elif id == &"bellwake":
				await _capture(rig, "bellwake_03_stagger.png")
		elif id == &"gate_hound":
				await _capture(rig, "miniboss_gate_hound_02_stagger.png")

		var hp_before_chain: int = boss.health.health_points
		for amount in CHAIN:
			boss.apply_hit(Hit.make(amount, _hero(rig).global_position, &"sword",
				0.0, 0.0, &"director"))
			await rig.wait_seconds(0.23)
		var spent: int = hp_before_chain - boss.health.health_points
		var promised: int = mini(cap, hp_before_chain)
		_ck("C6 %s bare 2+2+4 chain spends one segment (%d/%d HP)"
			% [id, spent, promised], spent == promised)
		_ck("C7 %s cannot lose a second segment in window %d"
			% [id, window + 1], boss.segment_damage() == promised)

		await rig.wait_frames(5)
		if not crossed_half and boss.health.health_points * 2 \
				<= boss.health.max_health_points:
			crossed_half = true
			_ck("D3 %s half-health phase emits value 2 once" % id,
				phases == [2] and boss.current_phase() == 2)
			if id == &"cistern_warden":
				await _stage(rig, boss)
				await _capture(rig, "warden_05_phase2.png")
		elif not crossed_half:
			_ck("D3 %s remains phase 1 above half health" % id,
				phases.is_empty() and boss.current_phase() == 1)

		if window < goal - 1:
			_ck("C8 %s is alive before final promised window" % id,
				not boss.health.dead and boss.health.health_points > 0)

	_ck("C9 %s dies exactly on promised window %d" % [id, goal],
		boss.health.dead and boss.health.health_points == 0
		and boss.stagger_count() == goal)
	_ck("D4 %s phase 2 occurred once and remained public" % id,
		phases == [2] and boss.current_phase() == 2)
	await _discard(rig, boss)


func _break_aperture(boss: Node, kind: StringName) -> void:
	if kind == &"hookshot":
		boss.freeze(1.0)
	else:
		boss.apply_hit(Hit.make(1, _hero_from_node(boss).global_position, kind,
			0.0, 0.0, &"director"))


func _wrong_kind(wanted: StringName) -> StringName:
	return &"arrow" if wanted != &"arrow" else &"sword"


# --- F/G/H. Live leap, thrown zone, and representative game-camera frames ---

func _warden_leap(rig, boss: Node) -> void:
	var start: Vector3 = boss.global_position
	var marker := boss._marker as Node3D
	_ck("F1 Warden leap tell owns a target marker",
		is_instance_valid(marker) and marker.visible)
	await _until(rig, func() -> bool:
		return boss.state == Enemy.State.WINDUP and boss._timer \
			<= boss._tell_total * 0.35, 240)
	await _capture(rig, "warden_01_leap_tell.png")
	var airborne := await _until(rig, func() -> bool:
		return boss.state == Enemy.State.STRIKE and boss._leaping \
			and boss._model.position.y > boss._fit_pos.y + 0.75, 300)
	_ck("F2 Warden model rises on the authored leap", airborne)
	if airborne:
		await _capture(rig, "warden_02_leap_airborne.png")
	var landed := await _until(rig, func() -> bool: return not boss._leaping, 300)
	var moved := K.plane(boss.global_position - start).length()
	_ck("F3 Warden actor lands at meaningful XZ displacement (%.2f m)" % moved,
		landed and moved > 3.0)
	await rig.wait_frames(2)
	_ck("F4 leap target marker is cleared on landing",
		not is_instance_valid(boss._marker))


func _bellwake_throw(rig, boss: Node) -> void:
	_ck("G1 Bellwake committed at least one live thrown zone",
		boss._zones.size() > 0)
	if boss._zones.is_empty():
		return
	var zone: Dictionary = boss._zones[0]
	var fuse_start := float(zone["fuse_left"])
	var flight := float(zone["flight"])
	var midair := await _until(rig, func() -> bool:
		return not bool(zone["landed"]) \
			and float(zone["flight_elapsed"]) >= flight * 0.40, 240)
	var projectile_ref: Variant = zone["projectile"]
	var source: Vector3 = zone["from"]
	var destination: Vector3 = zone["at"]
	var projectile_high := false
	if is_instance_valid(projectile_ref):
		projectile_high = (projectile_ref as Node3D).global_position.y \
			> maxf(source.y, destination.y) + 0.45
	_ck("G2 projectile exists airborne before landing", midair and projectile_high)
	_ck("G3 fuse does not burn during flight",
		is_equal_approx(float(zone["fuse_left"]), fuse_start))
	await _capture(rig, "bellwake_01_zone_flight.png")
	await _capture(rig, "bellwake_02_weakpoint.png")

	var landed := await _until(rig, func() -> bool: return bool(zone["landed"]), 300)
	await rig.wait_seconds(0.22)
	_ck("G4 projectile disappears after landing", landed
		and not is_instance_valid(zone["projectile"]))
	_ck("G5 zone fuse advances only after landing",
		float(zone["fuse_left"]) < fuse_start - 0.10)


# --- Fixture helpers ---------------------------------------------------------

func _clear_fixture(rig) -> void:
	var scene: Node = rig.scene()
	for name in [^"Arena", ^"BossDoor"]:
		var node := scene.get_node_or_null(name)
		if node != null:
			node.queue_free()
	await rig.wait_frames(6)


func _spawn_boss(rig, id: StringName, at: Vector3) -> CharacterBody3D:
	var script := load(BOSS_SCRIPT) as GDScript
	var boss := script.new() as CharacterBody3D
	boss.name = "Dynamism_%s" % id
	boss.set(&"boss_id", id)
	boss.set(&"drop_seed", 203)
	boss.position = at
	rig.scene().add_child.call_deferred(boss)
	await _until(rig, func() -> bool: return boss.is_inside_tree(), 120)
	boss.set_arena_center(Vector3.ZERO)
	return boss


func _discard(rig, boss: Node) -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	await rig.wait_frames(4)
	# Boss relics are immediate live drops parented to current_scene. They are not
	# part of this proof and would otherwise photobomb the next row's fixture.
	for child in rig.scene().get_children():
		if child is LootMote:
			child.queue_free()
	await rig.wait_frames(2)


func _stage(rig, boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	boss.global_position = START_BOSS
	boss.rotation.y = PI
	boss._facing = PI
	boss.velocity = Vector3.ZERO
	var hero := _hero(rig)
	hero.global_position = START_HERO
	var to := K.flat(boss.global_position - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	var cam := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	if cam != null:
		cam.make_current()
	Bus.camera_recenter.emit()
	await rig.wait_frames(4)


func _capture(rig, filename: String) -> void:
	await rig.capture(out.path_join(filename))


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return null if players.is_empty() else players[0] as Node3D


func _hero_from_node(node: Node) -> Node3D:
	var players := node.get_tree().get_nodes_in_group(&"player")
	return null if players.is_empty() else players[0] as Node3D


func _until(rig, predicate: Callable, frames: int) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await rig.wait_frames(1)
	return false
