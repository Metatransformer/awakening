extends RefCounted
## Deterministic proof for the one-raid MVP in docs/design-tests/RAID_LOOP_PROOF.md.
##
## Run from the real courtyard:
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_raid.gd \
##     --out=/tmp/garrison-raid/raid.png --warmup=90

var _camera: Camera3D


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the real garrison courtyard"):
		return
	Clock.running = false
	Menu.close()

	_prove_campaign_authority(rig)
	await _prove_warning_horn_and_sleep(rig, garrison)
	await _prove_live_gate_route_and_outcome(rig, garrison)
	await _prove_builder_and_defense(rig, garrison)

	Clock.running = true
	print("GARRISON RAID OK")


func _prove_campaign_authority(rig) -> void:
	var objective := _active_state(false)
	rig.check(objective.phase() == GarrisonRaidState.PHASE_ACTIVE
		and objective.living_count() == 4,
		"the authored wave is three kobolds and one orc")
	var first := StringName(objective.attacker_records()[0]["id"])
	var integrity_before := objective.integrity()
	rig.check(not objective.objective_attack(first)
		and objective.integrity() == integrity_before,
		"a raider outside the courtyard cannot damage GARRISON integrity")
	rig.check(objective.damage_attacker(first, 1)
		and objective.integrity() == integrity_before,
		"ordinary damage to a raider does not damage the garrison")
	var first_record := objective.attacker_record(first)
	objective.sync_attacker(first, int(first_record["hp"]), 1.0,
		GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL)
	rig.check(objective.objective_attack(first)
		and objective.integrity() == integrity_before - GarrisonRaidState.OBJECTIVE_DAMAGE,
		"only a completed attack at the courtyard objective spends integrity")

	var encoded := JSON.stringify(objective.snapshot())
	var decoded: Variant = JSON.parse_string(encoded)
	var restored := GarrisonRaidState.new()
	restored.restore(decoded as Dictionary)
	rig.check(restored.snapshot() == objective.snapshot(),
		"the active wave, integrity, route, and cooldown survive JSON round-trip")

	var late := _active_state(false)
	while late.is_active() and late.integrity() > 40:
		late.tick(0.1)
	rig.check(late.is_active() and late.integrity() > 0
		and late.integrity() <= 40,
		"an absent player can return to a damaged but unresolved garrison")
	for record: Dictionary in late.attacker_records():
		late.kill_attacker(StringName(record["id"]))
	rig.check(late.phase() == GarrisonRaidState.PHASE_WON
		and late.integrity() > 0,
		"killing the surviving wave before zero is a late rescue")

	var lost := _active_state(false)
	while lost.is_active():
		lost.tick(0.1)
	rig.check(lost.phase() == GarrisonRaidState.PHASE_LOST
		and lost.integrity() == 0 and lost.ledger_stolen(),
		"zero integrity with living raiders irreversibly loses the raid")
	for record: Dictionary in lost.attacker_records():
		lost.kill_attacker(StringName(record["id"]))
	rig.check(lost.phase() == GarrisonRaidState.PHASE_LOST
		and lost.integrity() == 0,
		"killing stragglers after zero cannot undo the loss")
	rig.check(not lost.arm(20, 8.0), "the authored raid cannot recur after loss")

	var defended := _active_state(true)
	while defended.is_active():
		defended.tick(0.1)
	rig.check(defended.phase() == GarrisonRaidState.PHASE_WON
		and defended.integrity() > 0,
		"the built bolt-thrower holds the same wave while Kael is absent")
	rig.check(not defended.arm(20, 8.0), "the authored raid cannot recur after victory")


func _prove_warning_horn_and_sleep(rig, garrison: Garrison) -> void:
	await _clear_live_raiders(rig, garrison)
	Game.restore_garrison({})
	Game.set_flag(RelicDb.flag_donated(RelicDb.TALLY_LEDGER_ID))
	rig.check(Game.raid_arm(1, 8.0) and Game.raid_scheduled_day() == 2,
		"donating the Tally-Ledger arms one raid for the next day")

	var messages: Array[String] = []
	var cues: Array[StringName] = []
	var message_listener: Callable = func(value: String) -> void: messages.append(value)
	var cue_listener: Callable = func(value: StringName) -> void: cues.append(value)
	Bus.request_message.connect(message_listener)
	Bus.request_global_sfx.connect(cue_listener)

	Game.raid_observe_hour(2, 15)
	await rig.wait_frames(4)
	rig.check(messages.size() == 1 and messages[0].contains("23:00"),
		"15:00 delivers one simple advance warning")

	var hero := _hero(rig)
	var hero_before := hero.global_position if hero != null else Vector3.ZERO
	var bag_before: Dictionary = Run.bag.duplicate(true)
	var was_in_dungeon := Run.in_dungeon
	Run.in_dungeon = true
	Game.raid_observe_hour(2, 23)
	await rig.wait_frames(5)
	rig.check(cues.size() == 1 and cues[0] == &"raid_horn"
		and Sfx.last_global_cue == &"raid_horn",
		"23:00 plays the supplied raid horn exactly once through global SFX")
	rig.check(messages.size() == 2 and messages[1].contains("ESCAPE ROPE OR PRESS ON"),
		"the urgent underground call preserves the continue-or-extract choice")
	rig.check(Run.in_dungeon and Run.bag == bag_before
		and (hero == null or hero.global_position.is_equal_approx(hero_before)),
		"the raid call neither teleports Kael nor extracts his bag")
	Run.in_dungeon = was_in_dungeon

	if Bus.request_message.is_connected(message_listener):
		Bus.request_message.disconnect(message_listener)
	if Bus.request_global_sfx.is_connected(cue_listener):
		Bus.request_global_sfx.disconnect(cue_listener)

	await _clear_live_raiders(rig, garrison)
	Game.restore_garrison({"raid": _raid_payload(
		GarrisonRaidState.PHASE_WARNED, 100, false, false, 0.0)})
	Clock.restore({"day": 2, "hour": 22.0, "running": false})
	var reached_dawn := Clock.sleep_to_dawn()
	rig.check(not reached_dawn and Clock.day == 2 and is_equal_approx(Clock.hour, 23.0)
		and Game.raid_active(),
		"sleep crossing 23:00 stops at the raid instead of granting dawn recovery")


func _prove_live_gate_route_and_outcome(rig, garrison: Garrison) -> void:
	await _clear_live_raiders(rig, garrison)
	Clock.restore({"day": 2, "hour": 23.0, "running": false})
	var hero := _hero(rig)
	if hero != null:
		hero.global_position = garrison.to_global(Vector3(-18.0, 0.05, -13.0))
	Game.restore_garrison({"raid": _raid_payload(
		GarrisonRaidState.PHASE_ACTIVE, 100, false, false, 0.0)})
	await rig.wait_frames(5)
	rig.check(garrison.raid_raiders.size() == 4,
		"the saved four-raider wave materializes outside the main gate")
	rig.check(garrison.raid_raiders.filter(
		func(raider: RaidRaider) -> bool: return raider.kind == &"kobold").size() == 3
		and garrison.raid_raiders.filter(
		func(raider: RaidRaider) -> bool: return raider.kind == &"orc").size() == 1,
		"the live wave keeps the three-kobold, one-orc composition")

	_camera = Camera3D.new()
	_camera.fov = 55.0
	garrison.add_child(_camera)
	_add_enemy_read_fill(_camera)
	_camera.make_current()
	await rig.wait_seconds(1.25)
	_frame_live_raiders(garrison, Vector3(6.0, 3.5, 7.0))
	var outside := true
	for raider: RaidRaider in garrison.raid_raiders:
		outside = outside and garrison.to_local(raider.global_position).z > 15.4
	rig.check(outside, "the wave begins on the road outside the south gate")
	rig.check(Hud.layout_rects().has(&"garrison_integrity"),
		"the normal HUD publishes its persistent GARRISON integrity bar")
	await rig.capture("raid_00_approaching_gate.png")

	await rig.wait_seconds(3.0)
	var entered := false
	for raider: RaidRaider in garrison.raid_raiders:
		entered = entered or garrison.to_local(raider.global_position).z < 15.0
	rig.check(entered, "the physical wave crosses the main gate into the courtyard")
	_frame_live_raiders(garrison, Vector3(0.0, 7.0, 2.0))
	await rig.wait_frames(5)
	await rig.capture("raid_01_entering_courtyard.png")

	Game.restore_garrison({"raid": _raid_payload(
		GarrisonRaidState.PHASE_ACTIVE, 35, false, false, 0.82)})
	await rig.wait_frames(6)
	var restored_records := Game.raid_attacker_records()
	rig.check(Game.raid_integrity() == 35 and Game.raid_active(),
		"loading in the live courtyard restores the damaged unresolved raid")
	rig.check(garrison.raid_raiders.size() == 4,
		"the load replaces old live mirrors with exactly the four saved raiders")
	var resumed_at_saved_route := restored_records.size() == 4
	for record: Dictionary in restored_records:
		resumed_at_saved_route = resumed_at_saved_route \
			and float(record["route_progress"]) >= 0.82
	rig.check(resumed_at_saved_route,
		"old mirror teardown cannot overwrite the newly loaded route state")
	_camera.global_position = garrison.to_global(Vector3(-5.5, 4.8, -13.5))
	_camera.look_at(garrison.raid_objective.global_position + Vector3.UP, Vector3.UP)
	await rig.capture("raid_02_late_rescue.png")
	_kill_live_wave(garrison)
	await rig.wait_frames(4)
	rig.check(Game.raid_phase() == GarrisonRaidState.PHASE_WON
		and Game.raid_integrity() == 35,
		"manual combat saves a damaged garrison while integrity remains")
	await rig.capture("raid_03_secure.png")

	await _clear_live_raiders(rig, garrison)
	Game.restore_garrison({"raid": _raid_payload(
		GarrisonRaidState.PHASE_LOST, 0, false, true, 1.0)})
	await rig.wait_frames(6)
	rig.check(Game.raid_phase() == GarrisonRaidState.PHASE_LOST
		and Game.raid_ledger_stolen(),
		"a loaded failed raid restores its authoritative lost result")
	await rig.capture("raid_04_lost.png")
	_kill_live_wave(garrison)
	await rig.wait_frames(4)
	rig.check(Game.raid_phase() == GarrisonRaidState.PHASE_LOST,
		"clearing the courtyard after zero leaves GARRISON LOST")
	rig.check(not RelicDb.donated(RelicDb.TALLY_LEDGER_ID)
		and RelicDb.outstanding(RelicDb.TALLY_LEDGER_ID),
		"loss suppresses the Ledger benefit and returns it to its dungeon source")
	rig.check(RelicDb.recover(RelicDb.TALLY_LEDGER_ID)
		and RelicDb.donated(RelicDb.TALLY_LEDGER_ID)
		and not Game.raid_ledger_stolen(),
		"recovering the Ledger restores its paid donation without a second repair")
	rig.check(Game.raid_phase() == GarrisonRaidState.PHASE_LOST
		and not Game.raid_arm(8, 8.0),
		"Ledger recovery does not schedule a second raid")


func _prove_builder_and_defense(rig, garrison: Garrison) -> void:
	await _clear_live_raiders(rig, garrison)
	Game.restore_garrison({})
	Game.set_flag(RelicDb.flag_donated(RelicDb.TALLY_LEDGER_ID))
	Game.raid_arm(3, 10.0)
	Clock.restore({"day": 3, "hour": 12.0, "running": false})
	await rig.wait_frames(5)
	var builder_body: NpcBody
	if garrison.builder != null:
		builder_body = garrison.builder._person as NpcBody
	rig.check(builder_body != null and builder_body._who == "builder",
		"the unvoiced Builder is present as Tamsin's authored NpcBody")
	# `voice_id()` is the dialogue person key, including written-only speakers.
	rig.check(garrison.builder != null and garrison.builder.voice_id() == &"builder",
		"the raid Builder retains Tamsin's production dialogue identity")

	Game.gold = BuilderDb.COST
	Game.components.clear()
	for id: StringName in BuilderDb.PARTS:
		Game.components[id] = int(BuilderDb.PARTS[id])
	var line: Dictionary = BuilderDb.lines()[0]
	rig.check(BuilderDb.can_buy(line) and BuilderDb.buy(line),
		"the one-rung build quest consumes the existing gold-and-components bill")
	await rig.wait_frames(5)
	rig.check(Game.gold == 0 and Game.components.is_empty()
		and Game.raid_defense_built() and garrison.bolt_thrower != null,
		"the completed West Gate Bolt-Thrower is saved and appears in the courtyard")
	rig.check(not BuilderDb.buy(BuilderDb.lines()[0]),
		"the single defensive structure cannot be built twice")

	_camera.global_position = garrison.bolt_thrower.global_position + Vector3(3.2, 2.8, -5.0)
	_camera.look_at(garrison.bolt_thrower.global_position + Vector3.UP, Vector3.UP)
	await rig.capture("raid_05_bolt_thrower.png")
	var hero := _hero(rig)
	if hero != null:
		hero.global_position = garrison.to_global(Vector3(8.0, 0.05, -8.5))
	await rig.wait_frames(4)
	var builder_box := _world_box(garrison.builder)
	var builder_center := builder_box.get_center()
	var front := garrison.builder.global_transform.basis * Vector3.FORWARD
	_camera.global_position = builder_center + front * 3.2 + Vector3.UP * 0.45
	_camera.look_at(builder_center, Vector3.UP)
	await rig.capture("raid_06_builder.png")

	Game.restore_garrison({"raid": _raid_payload(
		GarrisonRaidState.PHASE_ACTIVE, 100, false, false, 0.0)})
	rig.check(not BuilderDb.can_buy(BuilderDb.lines()[0]),
		"construction closes when the raid has already begun")


func _add_enemy_read_fill(camera: Camera3D) -> void:
	# Match the real gameplay camera's enemy-only fill so proof views preserve
	# the same nighttime combat readability the player sees.
	var fill := DirectionalLight3D.new()
	fill.name = &"EnemyReadFill"
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	fill.light_color = Color(0.66, 0.74, 0.95)
	fill.light_energy = 1.5
	fill.light_indirect_energy = 0.0
	fill.light_volumetric_fog_energy = 0.0
	fill.shadow_enabled = false
	fill.light_cull_mask = 4
	camera.add_child(fill)


func _frame_live_raiders(garrison: Garrison, local_offset: Vector3) -> void:
	var center := Vector3.ZERO
	var count := 0
	for raider: RaidRaider in garrison.raid_raiders:
		if is_instance_valid(raider) and raider.health != null and not raider.health.dead:
			center += raider.global_position
			count += 1
	if count == 0:
		return
	center /= float(count)
	_camera.global_position = center + garrison.global_basis * local_offset
	_camera.look_at(center + Vector3.UP, Vector3.UP)


func _active_state(with_defense: bool) -> GarrisonRaidState:
	var state := GarrisonRaidState.new()
	state.arm(1, 8.0)
	if with_defense:
		state.build_defense()
	state.observe_time(2, 23.0)
	return state


func _raid_payload(phase: StringName, integrity: int, defense: bool,
		stolen: bool, progress: float) -> Dictionary:
	var attackers: Array[Dictionary] = []
	for row: Dictionary in [
		{"id": &"kobold_1", "kind": &"kobold", "max_hp": 8},
		{"id": &"kobold_2", "kind": &"kobold", "max_hp": 8},
		{"id": &"kobold_3", "kind": &"kobold", "max_hp": 8},
		{"id": &"orc_1", "kind": &"orc", "max_hp": 14},
	]:
		attackers.append({
			"id": row["id"], "kind": row["kind"], "max_hp": row["max_hp"],
			"hp": row["max_hp"], "alive": true, "route_progress": progress,
			"objective_cooldown": GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL,
		})
	return {
		"phase": phase,
		"scheduled_raid_day": 2,
		"integrity": integrity,
		"defense_built": defense,
		"ledger_stolen": stolen,
		"attackers": attackers,
		"bolt_cooldown": GarrisonRaidState.BOLT_DEFENSE_INTERVAL,
		"advance_notice_pending": false,
		"advance_notice_delivered": true,
		"urgent_notice_pending": false,
		"urgent_notice_delivered": true,
	}


func _kill_live_wave(garrison: Garrison) -> void:
	for raider: RaidRaider in garrison.raid_raiders:
		if is_instance_valid(raider) and raider.health != null and not raider.health.dead:
			raider.health.apply_hit(Hit.make(
				raider.health.max_health_points, raider.global_position + Vector3.BACK,
				&"sword", 0.0, 0.0, &"DIRECTOR"))


func _clear_live_raiders(rig, garrison: Garrison) -> void:
	for node: Node in rig.root.get_tree().get_nodes_in_group(&"raid_raider"):
		node.queue_free()
	await rig.wait_frames(3)
	garrison.raid_raiders.clear()


func _hero(rig) -> Node3D:
	return rig.root.get_tree().get_first_node_in_group(&"player") as Node3D


func _world_box(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for node in _all(root):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var drawn: AABB = mesh.global_transform * mesh.get_aabb()
		box = drawn if first else box.merge(drawn)
		first = false
	return box


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_all(child))
	return found
