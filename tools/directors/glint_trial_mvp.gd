extends RefCounted
## Issue #206: the bounded Glint Trial vertical slice, through real world seams.
##
## Dungeon:
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/glint_trial_mvp.gd \
##     --out=/tmp/glint-mvp/dungeon/x.png --size=1280x720 --warmup=60 \
##     --glint-mvp
##
## Garrison:
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/glint_trial_mvp.gd \
##     --out=/tmp/glint-mvp/garrison/x.png --size=1280x720 --warmup=60

const DEFAULT_SEED := 20260813
const SAVE_SLOT := 4
const DUNGEON_SCRIPT := "res://scripts/world/dungeon.gd"
const BOSS_DOOR_SCRIPT := "res://scripts/world/boss_door.gd"
const BOSS_KEY_SCRIPT := "res://scripts/props/atoms/boss_key.gd"

var _checks := 0
var _failed := false
var _out := ""
var _seed := DEFAULT_SEED


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/glint-mvp/x.png").get_base_dir()
	_seed = int(rig.arg("seed", str(DEFAULT_SEED)))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if rig.scene().name == &"DungeonRun":
		await _dungeon(rig)
	elif rig.scene().name == &"Garrison":
		await _garrison(rig)
	else:
		_ck(rig, false, "unsupported host scene %s" % rig.scene().name)
	_finish(rig.scene().name)


func _dungeon(rig) -> void:
	Saves.erase(SAVE_SLOT)
	Saves.active_slot = SAVE_SLOT
	Game.reset()
	Run.enter(_seed)
	Run.level = 1
	_ck(rig, OS.get_cmdline_user_args().has("--glint-mvp"),
		"dungeon invocation omitted --glint-mvp")

	var dungeon := await _rebuild_dungeon(rig, _seed)
	if not _ck(rig, dungeon != null, "the real Dungeon did not rebuild"):
		_cleanup_save()
		return
	var hero := _hero(rig)
	if not _ck(rig, hero != null, "the dungeon has no live hero"):
		_cleanup_save()
		return

	_ck(rig, bool(dungeon.call(&"glint_mvp_enabled")),
		"Floor 1 did not latch the Glint MVP flag")
	_ck(rig, dungeon.call(&"anchor_node", &"gate_room") == null
		and dungeon.call(&"anchor_node", &"puzzle_room") == null,
		"the MVP layered over a standard gate or treasure puzzle")
	_ck(rig, not (dungeon.get(&"key_loop") as Dictionary).is_empty()
		and _named(dungeon, &"SmallKeyGate").size() == 1
		and _named(dungeon, &"SmallKeyDetour").size() == 1,
		"the MVP lost #199's guaranteed floor-scoped Small Key cycle")

	var doors := _script_nodes(dungeon, BOSS_DOOR_SCRIPT)
	var keys := _named(dungeon, &"GuardianBossKey")
	var guardians := _named(dungeon, &"GlintGuardianArena")
	var bars_nodes := _named(dungeon, &"GlintTrialBars")
	var sockets := _named(dungeon, &"GlintTrialSocket")
	var rewards := _named(dungeon, &"GlintTrialReward")
	var boss_arenas := _named(dungeon, &"Arena")
	var boss_chambers := _named(dungeon, &"BossChamber")
	var topology_ok := true
	topology_ok = _ck(rig, doors.size() == 1, "expected one BossDoor, found %d" % doors.size()) and topology_ok
	topology_ok = _ck(rig, keys.size() == 1, "expected one GuardianBossKey, found %d" % keys.size()) and topology_ok
	topology_ok = _ck(rig, guardians.size() == 1, "expected one GlintGuardianArena, found %d" % guardians.size()) and topology_ok
	topology_ok = _ck(rig, bars_nodes.size() == 1, "expected one GlintTrialBars, found %d" % bars_nodes.size()) and topology_ok
	topology_ok = _ck(rig, sockets.size() == 1, "expected one GlintTrialSocket, found %d" % sockets.size()) and topology_ok
	topology_ok = _ck(rig, rewards.size() == 1, "expected one GlintTrialReward, found %d" % rewards.size()) and topology_ok
	topology_ok = _ck(rig, boss_arenas.size() == 1 and boss_chambers.size() == 1,
		"the real boss chamber/arena is absent or duplicated") and topology_ok
	topology_ok = _ck(rig, dungeon.call(&"anchor_node", &"glint_trial") != null,
		"the Glint Trial anchor did not resolve") and topology_ok
	if not topology_ok:
		_cleanup_save()
		return

	var door := doors[0] as Node3D
	var key := keys[0] as Node3D
	var guardian := guardians[0] as Node3D
	var bars := bars_nodes[0] as Node3D
	var socket := sockets[0] as Node3D
	var reward := rewards[0] as Node3D
	var boss_arena := boss_arenas[0] as Node3D
	var boss := boss_arena.call(&"boss") as Node3D
	_ck(rig, not key.visible and not bool(key.get(&"armed"))
		and not bool(key.call(&"is_revealed")),
		"the Guardian Boss Key did not start hidden and inert")
	_ck(rig, not bool(bars.call(&"is_open"))
		and bars.get_node_or_null(^"Blocker") != null,
		"the Glint annex was traversable before the guardian")
	_ck(rig, not bool(door.call(&"is_open")) and not Game.has_boss_key,
		"the boss route started open or already keyed")
	door.call(&"activate", hero)
	await rig.wait_physics_frames(2)
	_ck(rig, not bool(door.call(&"is_open")) and not Game.has_boss_key,
		"the BossDoor could be cheesed before the guardian")
	_ck(rig, boss != null and is_instance_valid(boss)
		and (boss.get(&"health") as HealthComponent) != null
		and not (boss.get(&"health") as HealthComponent).dead,
		"no living floor boss exists behind the real BossDoor")

	var guardian_boss := guardian.call(&"boss") as Node3D
	var guardian_health := guardian_boss.get(&"health") as HealthComponent \
		if guardian_boss != null else null
	if not _ck(rig, guardian_boss != null and guardian_health != null
		and not guardian_health.dead, "the guardian has no live HealthComponent"):
		_cleanup_save()
		return
	var landed := guardian_health.apply_hit(Hit.make(
		guardian_health.health_points,
		guardian_boss.global_position + Vector3(0.0, 0.0, 3.0),
		&"director", 0.0, 0.0, &"director"))
	_ck(rig, landed and guardian_health.dead,
		"the fatal guardian hit did not land through HealthComponent")
	var released: bool = await rig.until(func() -> bool:
		return Game.flag(&"atom_glint_guardian_1") \
			and key.visible and bool(key.get(&"armed")) \
			and bool(key.call(&"is_revealed")) \
			and bool(bars.call(&"is_open")), 4.0)
	_ck(rig, released, "guardian death did not reveal the key and lift the bars")
	_ck(rig, not Game.has_boss_key and not bool(door.call(&"is_open")),
		"guardian death bypassed the real Boss Key/BossDoor transaction")
	await rig.wait_seconds(1.15)
	await _frame_fork(rig, dungeon, door, bars)
	await rig.capture(_out.path_join("01-fork.png"))

	key.call(&"_on_body_entered", hero)
	_ck(rig, Game.has_boss_key_for(1) and bool(key.call(&"is_solved")),
		"the real GuardianBossKey pickup did not grant the floor Boss Key")
	door.call(&"activate", hero)
	var opened: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 3.0)
	_ck(rig, opened and not Game.has_boss_key,
		"the real BossDoor did not open and consume the Boss Key")
	_ck(rig, Game.solved_glint_trials.is_empty()
		and boss != null and is_instance_valid(boss)
		and not (boss.get(&"health") as HealthComponent).dead,
		"taking the boss route solved the trial or removed the living boss")

	socket.call(&"solve")
	var awarded: bool = await rig.until(func() -> bool:
		return bool(reward.call(&"claimed")) \
			and bool(reward.call(&"cameo_visible")), 2.0)
	_ck(rig, awarded, "the socket solve did not claim and present the Glimmer")
	_ck(rig, Game.solved_glint_trials.size() == 1
		and Game.solved_glint_trials.get(GlintDb.CISTERN_SUN_GLINT_ID, false)
		and Game.glimmer_balance() == 1,
		"one solve did not produce exactly one permanent id and Glimmer")
	var cameo := reward.get_node_or_null(^"GlintCameo") as Node3D
	_ck(rig, cameo != null and not bool(cameo.call(&"using_fallback")),
		"the reward did not use the imported Glint model")
	_ck(rig, not Game.solve_glint_trial(&"not_a_trial")
		and not Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID)
		and Game.glimmer_balance() == 1,
		"invalid or duplicate solves changed the derived balance")
	await _frame_reward(rig, reward)
	await rig.capture(_out.path_join("02-reward.png"))

	Run.enter(_seed + 1)
	Run.level = 1
	var rebuilt := await _rebuild_dungeon(rig, _seed + 1)
	if _ck(rig, rebuilt != null, "the post-solve Floor 1 did not rebuild"):
		_ck(rig, rebuilt.call(&"anchor_node", &"glint_trial") == null
			and _named(rebuilt, &"GlintTrialBars").is_empty()
			and _named(rebuilt, &"GlintTrialSocket").is_empty()
			and _named(rebuilt, &"GlintTrialReward").is_empty(),
			"a solved trial respawned its anchor or annex")
		_ck(rig, _script_nodes(rebuilt, BOSS_DOOR_SCRIPT).size() == 1
			and _named(rebuilt, &"GlintGuardianArena").size() == 1
			and _named(rebuilt, &"GuardianBossKey").size() == 1,
			"omitting the solved trial removed the boss/guardian route")
	_cleanup_save()


func _garrison(rig) -> void:
	Saves.erase(SAVE_SLOT)
	Saves.active_slot = SAVE_SLOT
	Game.reset()
	Run.reset()
	_ck(rig, not Game.solve_glint_trial(&"not_a_trial"),
		"an unknown trial id was accepted")
	_ck(rig, Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID)
		and Game.glimmer_balance() == 1,
		"the authored trial did not grant one derived Glimmer")

	var hero := _hero(rig)
	var statues: Array[Node] = []
	for node in _all(rig.scene()):
		if node is Statue and bool(node.get(&"glint_service")):
			statues.append(node)
	if not _ck(rig, hero != null and statues.size() == 1,
			"the real garrison hero/Glint statue is absent or duplicated"):
		_cleanup_save()
		return
	var statue := statues[0] as Statue
	statue.activate(hero)
	await rig.wait_frames(8)
	var screens := _type_nodes(rig.scene(), TradeScreen)
	if not _ck(rig, screens.size() == 1, "the statue opened no unique TradeScreen"):
		_cleanup_save()
		return
	var screen := screens[0] as TradeScreen
	var rows: Array = screen.get(&"_rows") as Array
	var ladder := screen.get(&"_ladder") as UpgradeLadder
	_ck(rig, screen.title == "THE GLINT STATUE"
		and screen.service_label == "Glimmer"
		and screen.catalogue == GlintDb
		and GlintDb.currency_balance() == 1,
		"the real screen does not publish the Glint title, catalogue and balance")
	_ck(rig, rows.size() == 3 and ladder != null and ladder.row_count() == 3
		and GlintDb.lines().map(func(line: Dictionary): return line.get("id"))
			== [GlintDb.HEALTH_ID, GlintDb.STAMINA_ID, GlintDb.MAGIC_ID],
		"the statue does not show exactly health, stamina and magic")
	await rig.capture(_out.path_join("03-statue.png"))

	var health_before := Game.health_points
	var max_health_before := Game.max_health_points
	var stamina_before := Game.stamina
	var max_stamina_before := Game.max_stamina
	var magic_before := Game.magic
	var max_magic_before := Game.max_magic
	var health_line: Dictionary = GlintDb.lines()[0]
	_ck(rig, GlintDb.buy(health_line), "the health offering refused one Glimmer")
	_ck(rig, Game.max_health_points == max_health_before + K.GLINT_HEALTH_POINTS
		and Game.health_points == Game.max_health_points,
		"health did not gain and fill exactly one +2 rung")
	_ck(rig, Game.stamina == stamina_before and Game.max_stamina == max_stamina_before
		and Game.magic == magic_before and Game.max_magic == max_magic_before,
		"buying health changed stamina or magic")
	_ck(rig, int(Game.upgrades.get(GlintDb.HEALTH_ID, 0)) == 1
		and Game.glimmer_balance() == 0
		and Game.solved_glint_trials.size() == Game.glint_spent() + Game.glimmer_balance(),
		"the purchase broke solved = spent + balance")
	var stamina_line: Dictionary = GlintDb.lines()[1]
	_ck(rig, not GlintDb.buy(health_line) and not GlintDb.buy(stamina_line)
		and GlintDb.refusal(stamina_line) == "NEED 1 GLIMMER",
		"duplicate/zero-balance purchases were not refused honestly")
	_ck(rig, health_before <= Game.health_points,
		"the selected health purchase reduced current health")

	screen.close()
	await rig.wait_frames(8)
	_ck(rig, Saves.save(SAVE_SLOT) and Saves.has_save(SAVE_SLOT),
		"save v22 did not write director slot 4")
	Game.reset()
	Run.reset()
	var destination: Dictionary = Saves.load_slot(SAVE_SLOT)
	_ck(rig, not destination.is_empty()
		and Game.solved_glint_trials.get(GlintDb.CISTERN_SUN_GLINT_ID, false)
		and int(Game.upgrades.get(GlintDb.HEALTH_ID, 0)) == 1
		and Game.max_health_points == K.START_HEALTH_POINTS + K.GLINT_HEALTH_POINTS
		and Game.glimmer_balance() == 0,
		"the solved id, rank, maximum or conservation failed save/load")

	Game.reset()
	Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID)
	Game.max_health_points = K.MAX_HEALTH_POINTS
	_ck(rig, GlintDb.refusal(GlintDb.lines()[0]) == "ALREADY AT THE LIMIT",
		"a capped stat does not explain its refusal")
	Game.reset()
	Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID)
	Game.upgrades[Game.jewel_track(&"amulet", &"focus")] = K.JEWEL_MAX
	Game.well_fed_trip = true
	Game.resync_maxima(false)
	var fed_line: Dictionary = GlintDb.lines()[1]
	_ck(rig, Game.max_stamina > K.STAMINA_MAX
		and GlintDb.can_buy(fed_line)
		and GlintDb.refusal(fed_line).is_empty(),
		"temporary Well Fed stamina falsely capped the permanent rung")
	_cleanup_save()


func _rebuild_dungeon(rig, seed_value: int) -> Node:
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load(DUNGEON_SCRIPT) as GDScript
	if script == null:
		return null
	var dungeon: Node = script.new()
	dungeon.name = "Dungeon"
	dungeon.set(&"seed_override", seed_value)
	scene.add_child(dungeon)
	await rig.wait_frames(14)
	return dungeon


func _cleanup_save() -> void:
	Saves.erase(SAVE_SLOT)
	if Saves.active_slot == SAVE_SLOT:
		Saves.active_slot = -1


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] as Node3D if not players.is_empty() else null


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_all(child))
	return found


func _named(root: Node, wanted: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in _all(root):
		if node.name == wanted:
			found.append(node)
	return found


func _script_nodes(root: Node, path: String) -> Array[Node]:
	var found: Array[Node] = []
	var wanted := load(path) as Script
	if wanted == null:
		return found
	for node in _all(root):
		if node.get_script() == wanted:
			found.append(node)
	return found


func _type_nodes(root: Node, type_script: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node in _all(root):
		if is_instance_of(node, type_script):
			found.append(node)
	return found


func _proof_camera(rig) -> Camera3D:
	var camera := rig.scene().get_node_or_null(^"GlintMvpProofCamera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "GlintMvpProofCamera"
		rig.scene().add_child(camera)
	return camera


func _pose_camera(rig, eye: Vector3, target: Vector3, fov: float) -> void:
	var camera := _proof_camera(rig)
	camera.fov = fov
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	await rig.wait_frames(10)


func _frame_fork(rig, dungeon: Node, door: Node3D, bars: Node3D) -> void:
	var cell: Vector2i = dungeon.call(&"anchor_cell", &"boss_door")
	var centre: Vector3 = dungeon.call(&"centre_of", cell)
	var midpoint := door.global_position.lerp(bars.global_position, 0.5)
	var away := centre - midpoint
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.BACK
	await _pose_camera(rig, centre + away.normalized() * 2.8 + Vector3.UP * 4.0,
		midpoint + Vector3.UP * 1.55, 70.0)


func _frame_reward(rig, reward: Node3D) -> void:
	var chamber := reward.get_parent() as Node3D
	if chamber == null:
		await _pose_camera(rig, reward.global_position + Vector3.BACK * 5.4
			+ Vector3.UP * 2.5, reward.global_position + Vector3.UP * 1.25, 48.0)
		return
	# WorldCaption correctly keys range from the player, not the proof camera.
	# Put the real hero in the annex so the frame exercises the gameplay view.
	var hero := _hero(rig)
	if hero != null:
		hero.global_position = chamber.to_global(
			Vector3(-2.2, 0.08, reward.position.z - 4.2))
		await rig.wait_physics_frames(2)
	var eye := chamber.to_global(Vector3(0.0, 2.45, reward.position.z - 6.2))
	await _pose_camera(rig, eye, reward.global_position + Vector3.UP * 1.25, 48.0)


func _ck(rig, ok: bool, message: String) -> bool:
	_checks += 1
	if ok:
		print("GLINT MVP ok check %02d" % _checks)
		return true
	_failed = true
	rig.fail("GLINT MVP FAIL %s" % message)
	return false


func _finish(host: StringName) -> void:
	if _failed:
		print("GLINT MVP FAIL %s -- one or more checks failed" % host)
	else:
		print("GLINT MVP OK %s" % ("dungeon" if host == &"DungeonRun" else "garrison"))
