extends RefCounted
## Deterministic behavioral and visual proof for named fishing cargo.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here --scene=res://scenes/rooms/garrison_outskirts.tscn \
##     --director=res://tools/directors/fishing_provisions.gd \
##     --out=/tmp/fishing-provisions/proof.png --warmup=60


func run(rig) -> void:
	var outskirts := rig.scene() as GarrisonOutskirts
	if not rig.check(outskirts != null, "scene is the authored garrison outskirts"):
		return
	Clock.running = false
	Clock.set_time(1, 9.0)
	Game.restore_garrison({})
	Run.reset()
	await rig.wait_frames(6)

	var fishing := outskirts.fishing_hole as FishingHole
	if not rig.check(fishing != null, "outskirts exposes a live fishing_hole"):
		return
	var fishing_sfx_events: Array[StringName] = []
	var observe_fishing_sfx: Callable = func(id: StringName, _position: Vector3) -> void:
		if Sfx.FISHING_CUES.has(id):
			fishing_sfx_events.append(id)
	Bus.request_sfx.connect(observe_fishing_sfx)
	for semantic: StringName in Sfx.FISHING_CUES:
		var resolved: StringName = Sfx.resolve_semantic_cue(semantic)
		rig.check(Sfx.semantic_cue_exists(semantic),
			"%s resolves centrally to existing %s audio" % [semantic, resolved])

	var hero := outskirts.get_node_or_null("Hero") as CharacterBody3D
	if hero != null:
		hero.global_position = fishing.to_global(Vector3(0.0, 0.9, 1.4))
		hero.look_at(fishing.to_global(Vector3(0.0, 0.5, -2.25)), Vector3.UP)
		await rig.wait_frames(5)
	var cam := Camera3D.new()
	cam.fov = 55.0
	outskirts.add_child(cam)
	cam.global_position = fishing.to_global(Vector3(0.0, 5.4, 5.0))
	cam.look_at(fishing.to_global(Vector3(0.0, 0.45, -2.25)), Vector3.UP)
	cam.make_current()
	await rig.wait_frames(6)

	_check_catalogue(rig)
	await _check_direct_start_and_cancel(rig, fishing)
	await _check_hook_windows(rig, fishing)
	await _check_named_catch(rig, fishing, fishing_sfx_events)
	await _check_missed_window(rig, fishing, fishing_sfx_events)

	var outcome_events: Array[StringName] = []
	for event: StringName in fishing_sfx_events:
		if event in [&"fishing_catch", &"fishing_fail"]:
			outcome_events.append(event)
	rig.check(outcome_events == [&"fishing_catch", &"fishing_fail"],
		"named catch and missed hook emit exactly one catch and one fail cue")
	if Bus.request_sfx.is_connected(observe_fishing_sfx):
		Bus.request_sfx.disconnect(observe_fishing_sfx)
	Clock.running = true
	if rig.fails == 0:
		print("FISHING PROVISIONS OK")


func _check_catalogue(rig) -> void:
	var expected_windows: Array[float] = [1.20, 1.00, 0.82, 0.68]
	var previous: Dictionary = {}
	for i: int in SupplyCargoDb.FISH_IDS.size():
		var fish_id: StringName = SupplyCargoDb.FISH_IDS[i]
		var tuning := SupplyCargoDb.tuning(fish_id)
		rig.check(SupplyCargoDb.tier_of(fish_id) == i + 1,
			"%s is catalogue tier %d" % [fish_id, i + 1])
		rig.check(is_equal_approx(float(tuning.get("hook_window", 0.0)),
			expected_windows[i]), "tier %d hook window is exactly %.2f seconds"
			% [i + 1, expected_windows[i]])
		if not previous.is_empty():
			rig.check(float(tuning["hook_window"]) < float(previous["hook_window"])
				and float(tuning["run_interval"]) < float(previous["run_interval"])
				and float(tuning["initial_tension"]) > float(previous["initial_tension"])
				and float(tuning["tension_recovery"]) < float(previous["tension_recovery"])
				and float(tuning["correct_reel_rate"]) < float(previous["correct_reel_rate"])
				and float(tuning["no_reel_escape_rate"]) > float(previous["no_reel_escape_rate"])
				and float(tuning["wrong_tension_gain"]) > float(previous["wrong_tension_gain"])
				and float(tuning["neutral_tension_gain"]) > float(previous["neutral_tension_gain"]),
				"tier %d is strictly harder than tier %d on every fight dimension"
				% [i + 1, i])
		previous = tuning

	var weights := SupplyCargoDb.tier_weights_for_spot(1)
	rig.check(weights == [75, 20, 4, 1],
		"spot level 1 tier weights are exactly 75 / 20 / 4 / 1")
	var rng := RandomNumberGenerator.new()
	rng.seed = 188016
	var sample_size := 20000
	var counts: Array[int] = [0, 0, 0, 0]
	for _sample: int in sample_size:
		var rolled := SupplyCargoDb.roll_fish(1, rng)
		var index := SupplyCargoDb.FISH_IDS.find(rolled)
		if index >= 0:
			counts[index] += 1
	var close := true
	for i: int in counts.size():
		var observed := 100.0 * float(counts[i]) / float(sample_size)
		if absf(observed - float(weights[i])) > 1.0:
			close = false
	rig.check(close, "seeded 20,000-cast sample stays within one percentage point: %s"
		% [counts])


func _check_direct_start_and_cancel(rig, fishing: FishingHole) -> void:
	var before := _civil_minute()
	rig.check(fishing.debug_force_next_fish(SupplyCargoDb.POND_SHINER_ID),
		"a named Pond Shiner can be forced before casting")
	rig.check(fishing.begin_for_test(), "fishing begins through the ordinary gate")
	rig.check(fishing.state_name() == &"casting" and Prompt.blocked,
		"begin enters CASTING directly and owns input")
	rig.check(fishing.feedback_mode_name() == &"casting"
		and fishing.feedback_visual_text() == "CAST",
		"direct CASTING presents only the compact cast instrument")
	await rig.wait_frames(3)
	await rig.capture("fishing_01_casting.png")
	await rig.tap([&"ui_cancel"])
	var cancelled: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 1.0)
	rig.check(cancelled and not Prompt.blocked,
		"real cancel exits direct CASTING and releases input")
	rig.check(_civil_minute() == before, "cancelling direct CASTING costs zero minutes")


func _check_hook_windows(rig, fishing: FishingHole) -> void:
	for fish_id: StringName in SupplyCargoDb.FISH_IDS:
		var before := _civil_minute()
		if not rig.check(fishing.debug_force_next_fish(fish_id),
				"%s can be forced before its tuning probe" % fish_id):
			continue
		if not rig.check(fishing.begin_for_test(), "%s tuning probe starts" % fish_id):
			continue
		await rig.wait_frames(2)
		await rig.tap([&"interact"])
		var waiting: bool = await rig.until(
			func() -> bool: return fishing.state_name() == &"waiting", 1.0)
		rig.check(waiting and fishing.current_fish_id() == fish_id,
			"released cast selects the forced exact fish %s" % fish_id)
		var authored := SupplyCargoDb.tuning(fish_id)
		rig.check(is_equal_approx(fishing.current_hook_window(),
			float(authored.get("hook_window", -1.0))),
			"%s live attempt uses its exact SupplyCargoDb hook window" % fish_id)
		await rig.tap([&"ui_cancel"])
		await rig.until(func() -> bool: return fishing.state_name() == &"idle", 1.0)
		rig.check(_civil_minute() == before,
			"cancelling %s before an outcome costs zero minutes" % fish_id)


func _check_named_catch(rig, fishing: FishingHole,
		fishing_sfx_events: Array[StringName]) -> void:
	Run.reset()
	Game.restore_garrison({})
	Clock.set_time(2, 11.0)
	var fish_id := SupplyCargoDb.CROWN_PIKE_ID
	rig.check(Run.collect(fish_id, 1) == 1,
		"one Crown Pike seeds the real bag stack")
	var before := _civil_minute()
	var catch_before := fishing_sfx_events.count(&"fishing_catch")
	if not await _cast_named(rig, fishing, fish_id):
		return
	rig.check(fishing.feedback_mode_name() == &"waiting",
		"named cast reaches the waiting ripple instrument")
	await rig.capture("fishing_02_waiting.png")
	fishing.debug_force_bite()
	rig.check(fishing.state_name() == &"bite"
		and fishing.feedback_mode_name() == &"bite",
		"forced named bite enters the real tier-timed hook window")
	await rig.wait_frames(2)
	await rig.capture("fishing_03_bite.png")
	await rig.tap([&"interact"])
	var hooked: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"hooked", 1.0)
	if not rig.check(hooked, "real hook press enters HOOKED for the Crown Pike"):
		return
	rig.check(fishing.current_fish_id() == fish_id
		and fishing.current_fish_tier() == 4,
		"HOOKED retains the exact Crown Pike and tier 4 tuning")
	await rig.wait_frames(3)
	await rig.capture("fishing_04_hooked.png")

	var desired := fishing.desired_steer_direction()
	var correct_action: StringName = &"move_left" if desired < 0 else &"move_right"
	var wrong_action: StringName = &"move_right" if desired < 0 else &"move_left"
	var line_before_gain := fishing.line_progress()
	await rig.press(&"interact")
	await rig.press(correct_action)
	await rig.wait_frames(12)
	var line_after_gain := fishing.line_progress()
	rig.check(fishing.actual_steering() == desired
		and fishing.feedback_reaction_name() == &"correct"
		and line_after_gain < line_before_gain,
		"correct counter-steer gains LAND progress")
	rig.release(correct_action)
	rig.release(&"interact")
	await rig.wait_frames(18)
	var line_after_ease := fishing.line_progress()
	rig.check(line_after_ease > line_after_gain and line_after_ease <= 1.0,
		"releasing the reel eases tension while the fish takes LAND progress back")
	await rig.press(&"interact")
	await rig.press(wrong_action)
	await rig.wait_frames(3)
	rig.check(fishing.actual_steering() == -desired
		and fishing.feedback_reaction_name() == &"wrong",
		"with-run steering produces the distinct wrong response")
	rig.release(wrong_action)
	rig.release(&"interact")
	await rig.wait_frames(2)

	fishing.debug_land_catch()
	rig.check(fishing.state_name() == &"result"
		and fishing.feedback_mode_name() == &"result_success",
		"landing enters the named success card")
	rig.check(fishing.caught_fish_id() == fish_id
		and int(Run.bag.get(fish_id, 0)) == 2,
		"caught Crown Pike stacks by exact ID in the Run bag")
	rig.check(Game.fish_stock == 0 and Game.fish_units_today == 1,
		"catch records daily yield without teleporting food into garrison stock")
	rig.check(_civil_minute() == before + 10,
		"successful named catch advances exactly ten civil minutes")
	rig.check(fishing.feedback_visual_text() == "CROWN PIKE • • • •",
		"success card names Crown Pike and shows its four tier pips")
	rig.check(fishing_sfx_events.count(&"fishing_catch") == catch_before + 1,
		"named success emits exactly one catch cue")
	await rig.wait_frames(4)
	await rig.capture("fishing_05_named_success.png")
	await rig.until(func() -> bool: return fishing.state_name() == &"idle", 3.0)

	rig.check(Game.record_fish_catch(SupplyCargoDb.POND_SHINER_ID, Clock.day)
		and Game.record_fish_catch(SupplyCargoDb.RIVER_PERCH_ID, Clock.day),
		"two further exact fish fill the three-unit daily catch allowance")
	rig.check(Game.fish_units_today == Game.FISH_DAILY_CAP
		and not Game.record_fish_catch(SupplyCargoDb.SILVER_TROUT_ID, Clock.day),
		"daily cap refuses a fourth exact fish without changing its bag count")
	var spent_before := _civil_minute()
	rig.check(not fishing.begin_for_test() and fishing.state_name() == &"idle"
		and not Prompt.blocked,
		"spent daily water refuses a new attempt without taking input")
	rig.check(_civil_minute() == spent_before, "daily-cap refusal costs zero minutes")


func _check_missed_window(rig, fishing: FishingHole,
		fishing_sfx_events: Array[StringName]) -> void:
	Run.reset()
	Game.restore_garrison({})
	Clock.set_time(3, 12.0)
	var before := _civil_minute()
	var fail_before := fishing_sfx_events.count(&"fishing_fail")
	if not await _cast_named(rig, fishing, SupplyCargoDb.POND_SHINER_ID):
		return
	fishing.debug_force_bite()
	var hook_window := fishing.current_hook_window()
	var wall_start := Time.get_ticks_msec()
	var escaped: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"result", hook_window + 0.5)
	var elapsed := float(Time.get_ticks_msec() - wall_start) / 1000.0
	rig.check(escaped and elapsed >= hook_window * 0.85,
		"unanswered %.2f-second hook window escapes on real elapsed time (%.2f s)"
		% [hook_window, elapsed])
	rig.check(fishing.feedback_mode_name() == &"result_failure"
		and int(Run.bag.get(SupplyCargoDb.POND_SHINER_ID, 0)) == 0,
		"missed hook reaches failure and adds no fish cargo")
	rig.check(_civil_minute() == before + 10,
		"missed hook advances exactly ten civil minutes")
	rig.check(fishing_sfx_events.count(&"fishing_fail") == fail_before + 1,
		"missed hook emits exactly one fail cue")
	await rig.wait_frames(4)
	await rig.capture("fishing_06_named_fail.png")
	await rig.until(func() -> bool: return fishing.state_name() == &"idle", 3.0)


func _cast_named(rig, fishing: FishingHole, fish_id: StringName) -> bool:
	if not rig.check(fishing.debug_force_next_fish(fish_id),
			"%s can be forced before casting" % fish_id):
		return false
	if not rig.check(fishing.begin_for_test(), "%s attempt begins in CASTING" % fish_id):
		return false
	await rig.wait_frames(2)
	await rig.tap([&"interact"])
	var waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	return rig.check(waiting and fishing.current_fish_id() == fish_id,
		"released cast selects exact %s cargo" % fish_id)


func _civil_minute() -> int:
	return (Clock.day - 1) * 24 * 60 + int(floor(Clock.hour * 60.0 + 0.0001))
