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
##     --out=/tmp/glint-mvp/garrison/x.png --size=1280x720 --warmup=60 \
##     --glint-mvp
##
## Garrison boundary:
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/glint_trial_mvp.gd \
##     --out=/tmp/glint-mvp/garrison-boundary/x.png --size=1280x720 --warmup=60

const DEFAULT_SEED := 20260813
const SAVE_SLOT := 4
const DUNGEON_SCRIPT := "res://scripts/world/dungeon.gd"
const BOSS_DOOR_SCRIPT := "res://scripts/world/boss_door.gd"
const BOSS_KEY_SCRIPT := "res://scripts/props/atoms/boss_key.gd"

var _checks := 0
var _failed := false
var _out := ""
var _seed := DEFAULT_SEED
var _logic_only := false


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/glint-mvp/x.png").get_base_dir()
	_seed = int(rig.arg("seed", str(DEFAULT_SEED)))
	_logic_only = OS.get_cmdline_user_args().has("--logic-only")
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

	# Use the same seed seam as production. A raw seed_override would build a
	# different floor than Flow.resume, whose Dungeon reads Run.floor_seed().
	var dungeon := await _rebuild_dungeon(rig, 0)
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
	var captions := _named(dungeon, &"GlintTrialCaption")
	var sockets := _named(dungeon, &"GlintTrialSocket")
	var rewards := _named(dungeon, &"GlintTrialReward")
	var boss_arenas := _named(dungeon, &"Arena")
	var boss_chambers := _named(dungeon, &"BossChamber")
	var topology_ok := true
	topology_ok = _ck(rig, doors.size() == 1, "expected one BossDoor, found %d" % doors.size()) and topology_ok
	topology_ok = _ck(rig, keys.size() == 1, "expected one GuardianBossKey, found %d" % keys.size()) and topology_ok
	topology_ok = _ck(rig, guardians.size() == 1, "expected one GlintGuardianArena, found %d" % guardians.size()) and topology_ok
	topology_ok = _ck(rig, bars_nodes.size() == 1, "expected one GlintTrialBars, found %d" % bars_nodes.size()) and topology_ok
	topology_ok = _ck(rig, captions.size() == 1
		and String(captions[0].get(&"text")) == "OPTIONAL GLINT TRIAL",
		"the Glint bars do not carry their optional-trial caption") and topology_ok
	topology_ok = _ck(rig, sockets.size() == 1, "expected one GlintTrialSocket, found %d" % sockets.size()) and topology_ok
	topology_ok = _ck(rig, rewards.size() == 1, "expected one GlintTrialReward, found %d" % rewards.size()) and topology_ok
	topology_ok = _ck(rig, boss_arenas.size() == 1 and boss_chambers.size() == 1,
		"the real boss chamber/arena is absent or duplicated") and topology_ok
	topology_ok = _ck(rig, dungeon.call(&"anchor_node", &"glint_trial") != null,
		"the Glint Trial anchor did not resolve") and topology_ok
	topology_ok = _ck(rig, _atlas_has_glint_annex(dungeon),
		"Atlas did not publish the Glint annex side for the deepest cell") and topology_ok
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
	var refused_focus := await _address(rig, hero, door)
	_ck(rig, refused_focus, "the locked BossDoor did not take Prompt focus")
	if refused_focus:
		await rig.tap(["interact"])
	await rig.wait_physics_frames(3)
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
	if not _logic_only:
		await _frame_fork(rig, dungeon, door, bars)
		await rig.capture(_out.path_join("01-fork.png"))

	hero.global_position = key.global_position + Vector3.UP * 0.08
	hero.set(&"velocity", Vector3.ZERO)
	var picked_up: bool = await rig.until(func() -> bool:
		return Game.has_boss_key_for(1) and bool(key.call(&"is_solved")), 3.0)
	_ck(rig, picked_up,
		"the real GuardianBossKey pickup did not grant the floor Boss Key")
	var keyed_focus := await _address(rig, hero, door)
	_ck(rig, keyed_focus, "the keyed BossDoor did not take Prompt focus")
	if keyed_focus:
		await rig.tap(["interact"])
	var opened: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 3.0)
	_ck(rig, opened and not Game.has_boss_key,
		"the real BossDoor did not open and consume the Boss Key")
	_ck(rig, Game.solved_glint_trials.is_empty()
		and boss != null and is_instance_valid(boss)
		and not (boss.get(&"health") as HealthComponent).dead,
		"taking the boss route solved the trial or removed the living boss")

	var save_probe := {"attempts": 0}
	var fail_save := func() -> bool:
		save_probe["attempts"] = int(save_probe["attempts"]) + 1
		return false
	var failure_messages: Array[String] = []
	var collect_message := func(text: String) -> void:
		failure_messages.append(text)
	Bus.request_message.connect(collect_message)
	reward.call(&"_director_set_save_commit", fail_save)
	await _drive_sun_socket(rig, hero, socket, "failed commit")
	if Bus.request_message.is_connected(collect_message):
		Bus.request_message.disconnect(collect_message)
	_ck(rig, int(save_probe["attempts"]) == 1
		and not bool(reward.call(&"claimed"))
		and not bool(reward.call(&"cameo_visible"))
		and reward.get_node_or_null(^"GlintCameo") == null
		and not Game.solved_glint_trials.get(
			GlintDb.CISTERN_SUN_GLINT_ID, false)
		and Game.glimmer_balance() == 0
		and not bool(socket.call(&"is_solved")),
		"a failed save left a claim, cameo, solved id, balance or latched socket")
	_ck(rig, failure_messages.any(func(line: String) -> bool: return \
		line.contains("SAVE SLOT REQUIRED") and line.contains("NOT CLAIMED")),
		"a failed save did not clearly say the Glimmer was not claimed")

	reward.call(&"_director_set_save_commit", Callable())
	await _drive_sun_socket(rig, hero, socket, "production retry")
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
	var saved_trial_position := hero.global_position
	var saved_trial_cell: Vector2i = dungeon.call(&"anchor_cell", &"glint_trial")
	var saved_trial_side: StringName = (dungeon.get(&"placements") as Dictionary) \
		.get(&"glint_trial", {}).get("side", &"")
	var saved_chamber := _named(dungeon, &"GlintTrialChamber")[0] as Node3D
	var saved_chamber_position := saved_chamber.global_position
	if not _logic_only:
		await _frame_reward(rig, reward)
		await rig.capture(_out.path_join("02-reward.png"))

	Game.reset()
	Run.reset()
	var resumed: bool = await Flow.continue_game(SAVE_SLOT)
	var resumed_scene: Node = rig.scene()
	var resumed_dungeon: Node = resumed_scene.get_node_or_null(^"Dungeon") \
		if resumed_scene != null else null
	var resumed_hero := _hero(rig)
	_ck(rig, resumed and resumed_scene != null
		and resumed_scene.name == &"DungeonRun"
		and resumed_dungeon != null and resumed_hero != null,
		"Flow.continue_game did not restore the saved dungeon and hero")
	if resumed_dungeon == null or resumed_hero == null:
		_cleanup_save()
		return
	_ck(rig, Run.in_dungeon and Run.seed_used == _seed and Run.level == 1
		and Game.solved_glint_trials.get(
			GlintDb.CISTERN_SUN_GLINT_ID, false)
		and Game.glimmer_balance() == 1
		and Game.flag(GlintDb.cistern_sun_run_flag()),
		"production resume lost the run, solved id, Glimmer or socket flag")
	var resumed_chambers := _named(resumed_dungeon, &"GlintTrialChamber")
	var resumed_sockets := _named(resumed_dungeon, &"GlintTrialSocket")
	var resumed_rewards := _named(resumed_dungeon, &"GlintTrialReward")
	var resumed_placement: Dictionary = (resumed_dungeon.get(&"placements") \
		as Dictionary).get(&"glint_trial", {})
	_ck(rig, resumed_dungeon.call(&"anchor_node", &"glint_trial") != null
		and resumed_dungeon.call(&"anchor_cell", &"glint_trial") == saved_trial_cell
		and resumed_placement.get("side", &"") == saved_trial_side
		and resumed_chambers.size() == 1 and resumed_sockets.size() == 1
		and resumed_rewards.size() == 1,
		"the solved run did not regenerate its exact Glint annex")
	var resumed_chamber := resumed_chambers[0] as Node3D \
		if not resumed_chambers.is_empty() else null
	var resumed_socket := resumed_sockets[0] as Node3D \
		if not resumed_sockets.is_empty() else null
	var resumed_reward := resumed_rewards[0] as Node3D \
		if not resumed_rewards.is_empty() else null
	await rig.wait_physics_frames(6)
	_ck(rig, resumed_chamber != null
		and resumed_chamber.global_position.is_equal_approx(saved_chamber_position)
		and resumed_hero.global_position.distance_to(saved_trial_position) < 0.35
		and _walkable_ground_below(resumed_hero),
		"the saved trial transform resumed without its original walkable floor")
	_ck(rig, resumed_socket != null and bool(resumed_socket.call(&"is_solved"))
		and resumed_reward != null and not bool(resumed_reward.call(&"claimed"))
		and not bool(resumed_reward.call(&"cameo_visible")),
		"resume reset the socket or replayed the one-shot Glint reward")
	var resumed_doors := _script_nodes(resumed_dungeon, BOSS_DOOR_SCRIPT)
	var resumed_boss_arenas := _named(resumed_dungeon, &"Arena")
	var resumed_boss: Node3D = resumed_boss_arenas[0].call(&"boss") as Node3D \
		if not resumed_boss_arenas.is_empty() else null
	_ck(rig, resumed_doors.size() == 1
		and bool(resumed_doors[0].call(&"is_open"))
		and resumed_boss != null and is_instance_valid(resumed_boss)
		and not (resumed_boss.get(&"health") as HealthComponent).dead,
		"the resumed annex stranded the hero from the live boss route")

	Run.enter(_seed + 1)
	Run.level = 1
	_ck(rig, not Game.flag(GlintDb.cistern_sun_run_flag()),
		"starting a fresh run retained the solved run's socket flag")
	var rebuilt := await _rebuild_dungeon(rig, 0)
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
	var flagged := OS.get_cmdline_user_args().has("--glint-mvp")
	var hero := _hero(rig)
	var garrison := rig.scene() as Garrison
	var statue: Statue = garrison.statue if garrison != null else null
	if not flagged:
		_ck(rig, hero != null and statue != null,
			"the no-flag garrison lacks its real hero or plaza statue")
		if hero != null and statue != null:
			_ck(rig, not statue.glint_service and not statue.enabled,
				"the no-flag plaza statue exposed the Glint service")
			await _address(rig, hero, statue)
			_ck(rig, Prompt.focus != statue,
				"the disabled no-flag statue took Prompt focus")
			await rig.tap(["interact"])
			await rig.wait_frames(8)
		_ck(rig, _type_nodes(rig.scene(), TradeScreen).is_empty(),
			"a no-flag garrison interaction opened a Glint TradeScreen")
		_cleanup_save()
		return

	_ck(rig, flagged, "the full garrison proof omitted --glint-mvp")
	_ck(rig, not Game.solve_glint_trial(&"not_a_trial"),
		"an unknown trial id was accepted")
	_ck(rig, Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID)
		and Game.glimmer_balance() == 1,
		"the authored trial did not grant one derived Glimmer")

	var statues: Array[Node] = []
	for node in _all(rig.scene()):
		if node is Statue and bool(node.get(&"glint_service")):
			statues.append(node)
	if not _ck(rig, hero != null and statues.size() == 1,
			"the real garrison hero/Glint statue is absent or duplicated"):
		_cleanup_save()
		return
	statue = statues[0] as Statue
	var statue_focus := await _address(rig, hero, statue)
	_ck(rig, statue_focus, "the Glint statue did not take Prompt focus")
	if statue_focus:
		await rig.tap(["interact"])
	await rig.wait_frames(8)
	var screens := _type_nodes(rig.scene(), TradeScreen)
	if not _ck(rig, screens.size() == 1, "the statue opened no unique TradeScreen"):
		_cleanup_save()
		return
	var screen := screens[0] as TradeScreen
	var rows: Array = screen.get(&"_rows") as Array
	var ladder := screen.get(&"_ladder") as UpgradeLadder
	_ck(rig, screen.title == "THE GLINT STATUE — CHOOSE ONE"
		and screen.service_label == "Glimmer"
		and screen.catalogue == GlintDb
		and GlintDb.currency_balance() == 1,
		"the real screen does not publish the Glint title, catalogue and balance")
	_ck(rig, rows.size() == 3 and ladder != null and ladder.row_count() == 3
		and GlintDb.lines().map(func(line: Dictionary): return line.get("id"))
			== [GlintDb.HEALTH_ID, GlintDb.STAMINA_ID, GlintDb.MAGIC_ID],
		"the statue does not show exactly health, stamina and magic")
	_ck(rig, GlintDb.lines().all(func(line: Dictionary) -> bool:
		return String(line.get("blurb", "")).contains("permanently")),
		"a Glint choice does not say its Glimmer is spent permanently")
	if not _logic_only:
		await rig.capture(_out.path_join("03-statue.png"))

	var health_before := Game.health_points
	var max_health_before := Game.max_health_points
	var stamina_before := Game.stamina
	var max_stamina_before := Game.max_stamina
	var magic_before := Game.magic
	var max_magic_before := Game.max_magic
	var health_line: Dictionary = GlintDb.lines()[0]
	_ck(rig, GlintDb.crafts(health_line)
		and is_equal_approx(float(screen.call(&"_hold_time", screen.get(&"_cursor"))),
			TradeScreen.CRAFT_HOLD),
		"the selected Glint choice does not require the generic TradeScreen hold")
	await rig.tap(["ui_accept"])
	await rig.wait_frames(8)
	_ck(rig, int(Game.upgrades.get(GlintDb.HEALTH_ID, 0)) == 0
		and Game.glimmer_balance() == 1
		and Game.max_health_points == max_health_before,
		"a short accept tap bought the irreversible health choice")
	await rig.hold_seconds(["ui_accept"], TradeScreen.CRAFT_HOLD + 0.2)
	var bought: bool = await rig.until(func() -> bool:
		return int(Game.upgrades.get(GlintDb.HEALTH_ID, 0)) == 1, 2.0)
	_ck(rig, bought, "the held health offering refused one Glimmer")
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
	_ck(rig, not GlintDb.can_buy(health_line) and not GlintDb.can_buy(stamina_line)
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


func _walkable_ground_below(hero: Node3D) -> bool:
	if hero == null or not is_instance_valid(hero) or hero.get_world_3d() == null:
		return false
	var from := hero.global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from,
		from + Vector3.DOWN * 2.5, K.L_WORLD, [hero.get_rid()])
	var hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() \
		and hero.global_position.y - float((hit.get("position", Vector3.ZERO) \
			as Vector3).y) < 1.2


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


func _atlas_has_glint_annex(dungeon: Node) -> bool:
	var deepest: Vector2i = dungeon.get(&"deepest")
	if dungeon.call(&"anchor_cell", &"glint_trial") != deepest:
		return false
	var placements: Dictionary = dungeon.get(&"placements")
	var placement: Dictionary = placements.get(&"glint_trial", {})
	var side: StringName = placement.get("side", &"")
	for annex: Dictionary in Atlas.annexes:
		if annex.get("cell", Vector2i.ZERO) == deepest \
				and annex.get("dir", &"") == side:
			return true
	return false


func _address(rig, hero: Node3D, prop: Node3D) -> bool:
	if hero == null or prop == null:
		return false
	var toward_room := prop.global_transform.basis.z
	toward_room.y = 0.0
	if toward_room.length_squared() < 0.001:
		toward_room = Vector3.BACK
	hero.global_position = prop.global_position + toward_room.normalized() * 2.1
	hero.global_position.y = prop.global_position.y + 0.08
	hero.set(&"velocity", Vector3.ZERO)
	_face_at(hero, prop.global_position)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	return await rig.until(func() -> bool: return Prompt.focus == prop, 3.0)


func _drive_sun_socket(rig, hero: Node3D, socket: Node3D,
		beat: String) -> void:
	var game_camera := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	var catch: Vector3 = socket.call(&"catch_point")
	var behind := catch - socket.global_position
	behind.y = 0.0
	if behind.length_squared() < 0.001:
		behind = Vector3.BACK
	var camera := Camera3D.new()
	camera.name = "GlintSocketInputCamera"
	rig.scene().add_child(camera)
	camera.global_position = catch + behind.normalized() * 4.0 + Vector3.UP * 2.4
	camera.look_at(socket.global_position + Vector3.UP, Vector3.UP)
	camera.make_current()

	hero.global_position = catch + Vector3.UP * 0.05
	hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_physics_frames(12)
	_ck(rig, not bool(socket.call(&"is_solved")),
		"the %s SunSocket solved with the guard down" % beat)
	await rig.hold_seconds(["shield"], SunSocket.HOLD_TIME + 0.18)
	await rig.wait_physics_frames(3)
	camera.queue_free()
	if game_camera != null:
		game_camera.make_current()
		Bus.camera_recenter.emit()
	await rig.wait_frames(6)


func _face_at(hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.set(&"facing_yaw", atan2(to.x, to.z))
	hero.rotation.y = float(hero.get(&"facing_yaw")) + PI


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
	var centre: Vector3 = dungeon.call(&"centre_of", dungeon.get(&"deepest"))
	var midpoint := door.global_position.lerp(bars.global_position, 0.5)
	var toward := midpoint - centre
	toward.y = 0.0
	if toward.length_squared() < 0.001:
		toward = Vector3.FORWARD
	var hero := _hero(rig)
	if hero != null:
		hero.global_position = centre - toward.normalized() * 2.6 + Vector3.UP * 0.08
		hero.set(&"velocity", Vector3.ZERO)
		_face_at(hero, midpoint)
	var game_camera := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	_ck(rig, game_camera != null, "the fork frame has no real GameCamera")
	if game_camera != null:
		game_camera.make_current()
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(12)
	await rig.wait_frames(18)


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
	# Offset off the shaft's axis. Looking straight through that translucent volume
	# makes a narrow beam fill the foreground and hides the Glint it rewarded.
	var eye := chamber.to_global(Vector3(-3.2, 2.45, reward.position.z - 6.2))
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
