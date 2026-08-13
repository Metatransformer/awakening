extends RefCounted
## Deterministic behavioral and visual proof for the fishing/provisions slice.
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
	rig.check(outskirts.port(&"fishing_hole").origin != Vector3.ZERO,
		"fishing_hole retains a non-zero authored port")
	rig.check(outskirts.blocked_path != null
		and outskirts.port(&"blocked_path").origin != Vector3.ZERO,
		"the farther blocked_path and its authored port remain")
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
	await rig.capture("fishing_00_pond_wide.png")

	var before_begin_cancel: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"near"), "near water enters the fishing FSM")
	rig.check(fishing.state_name() == &"choose" and Prompt.blocked,
		"begin_for_test enters CHOOSE and blocks Prompt")
	rig.check(_civil_minute() == before_begin_cancel,
		"opening the fishing choice costs no civil time")
	await rig.wait_frames(3)
	rig.check(fishing.feedback_mode_name() == &"choose",
		"CHOOSE exposes the compact selection feedback mode")
	await rig.capture("fishing_01_choose.png")
	var before_cancel: int = _civil_minute()
	await rig.tap([&"ui_cancel"])
	var cancelled: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 1.0)
	rig.check(cancelled and not Prompt.blocked,
		"real ui_cancel exits to IDLE and releases Prompt")
	rig.check(_civil_minute() == before_cancel,
		"a cancelled attempt costs zero civil minutes")

	Game.restore_garrison({})
	Clock.set_time(1, 9.0)
	var near_started: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"near"), "a fresh near attempt begins")
	rig.check(_civil_minute() == near_started,
		"beginning the near attempt does not move civil time")
	await rig.wait_frames(3)
	var before_near_cast: int = _civil_minute()
	var cast_events_before: int = fishing_sfx_events.count(&"fishing_cast")
	await rig.tap([&"interact"])
	var near_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(near_waiting, "real interact press and release casts into near water")
	rig.check(_civil_minute() == before_near_cast,
		"casting the near line costs no civil time before its outcome")
	rig.check(fishing_sfx_events.count(&"fishing_cast") == cast_events_before + 1,
		"release into WAITING emits exactly one authored cast cue")
	rig.check(fishing.feedback_mode_name() == &"waiting",
		"WAITING exposes the ripple feedback mode")
	_check_no_old_visual_prose(rig, fishing, "WAITING")
	await rig.wait_frames(4)
	await rig.capture("fishing_02_waiting_ripple.png")
	var before_near_bite: int = _civil_minute()
	var bite_events_before: int = fishing_sfx_events.count(&"fishing_bite")
	fishing.debug_force_bite()
	rig.check(fishing.state_name() == &"bite", "the deterministic seam forces a near bite")
	rig.check(_civil_minute() == before_near_bite,
		"forcing the near bite does not alter civil time")
	rig.check(fishing.feedback_mode_name() == &"bite",
		"BITE exposes the emphatic ripple and action-emblem mode")
	rig.check(Sfx.last_positional_semantic_cue == &"fishing_bite"
		and fishing_sfx_events.count(&"fishing_bite") == bite_events_before + 1,
		"entering BITE emits exactly one semantic fishing_bite cue")
	_check_no_old_visual_prose(rig, fishing, "BITE")
	await rig.wait_frames(2)
	await rig.capture("fishing_03_bite_ripple.png")
	var before_near_hook: int = _civil_minute()
	var hook_events_before: int = fishing_sfx_events.count(&"fishing_hook")
	await rig.tap([&"interact"])
	var near_hooked: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"hooked", 1.0)
	rig.check(near_hooked, "the real hook press enters HOOKED")
	rig.check(_civil_minute() == before_near_hook,
		"hooking the near fish does not charge time early")
	rig.check(fishing_sfx_events.count(&"fishing_hook") == hook_events_before + 1,
		"entering HOOKED emits exactly one authored hook cue")
	await rig.wait_frames(3)
	rig.check(fishing.feedback_mode_name() == &"hooked"
		and fishing.feedback_reaction_name() == &"neutral",
		"HOOKED begins with a neutral counter-steer arrow")
	rig.check(fishing.desired_steer_direction() == -fishing.fish_run_direction(),
		"the dominant arrow points opposite the fish run")
	rig.check(fishing.feedback_visual_text() == "L R TENSION LAND",
		"HOOKED retains only key glyphs and compact TENSION/LAND labels")
	_check_no_old_visual_prose(rig, fishing, "HOOKED")
	await rig.capture("fishing_04_hooked_neutral.png")
	var reel_events_before: int = fishing_sfx_events.count(&"fishing_reel")
	await rig.press(&"interact")
	await rig.wait_frames(3)
	rig.check(fishing_sfx_events.count(&"fishing_reel") == reel_events_before + 1,
		"held reel without steering emits the authored neutral reel cue")
	rig.release(&"interact")
	await rig.wait_frames(2)

	var desired: int = fishing.desired_steer_direction()
	var correct_action: StringName = &"move_left" if desired < 0 else &"move_right"
	var wrong_action: StringName = &"move_right" if desired < 0 else &"move_left"
	await rig.press(&"interact")
	await rig.press(correct_action)
	await rig.wait_frames(3)
	rig.check(fishing.actual_steering() == desired
		and fishing.feedback_reaction_name() == &"correct",
		"real counter-steer input turns the arrow response correct")
	await rig.capture("fishing_05_hooked_correct.png")
	rig.release(correct_action)
	rig.release(&"interact")
	await rig.wait_frames(2)

	await rig.press(&"interact")
	await rig.press(wrong_action)
	await rig.wait_frames(3)
	rig.check(fishing.actual_steering() == -desired
		and fishing.feedback_reaction_name() == &"wrong",
		"real with-run input turns the arrow response wrong")
	await rig.capture("fishing_06_hooked_wrong.png")
	rig.release(wrong_action)
	rig.release(&"interact")
	await rig.wait_frames(2)
	var before_near_land: int = _civil_minute()
	var catch_events_before: int = fishing_sfx_events.count(&"fishing_catch")
	fishing.debug_land_catch()
	rig.check(fishing.state_name() == &"result", "landing enters RESULT")
	rig.check(Game.fish_stock == 1 and Game.fish_units_today == 1,
		"a near catch banks exactly one Fish and one daily unit")
	rig.check(_civil_minute() == before_near_land + 10,
		"the near outcome advances civil time by exactly ten minutes")
	rig.check(fishing.feedback_mode_name() == &"result_success"
		and Sfx.last_positional_semantic_cue == &"fishing_catch"
		and fishing_sfx_events.count(&"fishing_catch") == catch_events_before + 1,
		"the near RESULT reveals x1 and emits exactly one semantic catch cue")
	_check_no_old_visual_prose(rig, fishing, "RESULT success x1")
	await rig.wait_frames(4)
	await rig.capture("fishing_07_result_success_x1.png")
	var near_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(near_closed and not Prompt.blocked,
		"the near RESULT exits and releases Prompt after its result delay")

	Game.restore_garrison({})
	Clock.set_time(2, 11.0)
	var deep_started: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"deep"), "deep water begins on a fresh day and state")
	rig.check(_civil_minute() == deep_started,
		"beginning the deep attempt does not move civil time")
	await rig.wait_frames(3)
	var before_deep_cast: int = _civil_minute()
	cast_events_before = fishing_sfx_events.count(&"fishing_cast")
	await rig.tap([&"interact"])
	var deep_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(deep_waiting, "real interact press and release casts into deep water")
	rig.check(_civil_minute() == before_deep_cast,
		"casting the deep line costs no civil time before its outcome")
	rig.check(fishing_sfx_events.count(&"fishing_cast") == cast_events_before + 1,
		"the deep cast emits its authored cue once")
	_check_no_old_visual_prose(rig, fishing, "deep WAITING")
	var before_deep_bite: int = _civil_minute()
	bite_events_before = fishing_sfx_events.count(&"fishing_bite")
	fishing.debug_force_bite()
	rig.check(fishing.state_name() == &"bite", "the deterministic seam forces a deep bite")
	rig.check(_civil_minute() == before_deep_bite,
		"forcing the deep bite does not alter civil time")
	rig.check(Sfx.last_positional_semantic_cue == &"fishing_bite"
		and fishing_sfx_events.count(&"fishing_bite") == bite_events_before + 1,
		"the deep BITE emits its semantic cue once")
	_check_no_old_visual_prose(rig, fishing, "deep BITE")
	var before_deep_hook: int = _civil_minute()
	hook_events_before = fishing_sfx_events.count(&"fishing_hook")
	await rig.tap([&"interact"])
	var deep_hooked: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"hooked", 1.0)
	rig.check(deep_hooked, "the real hook press enters deep HOOKED")
	rig.check(_civil_minute() == before_deep_hook,
		"hooking the deep fish does not charge time early")
	rig.check(fishing_sfx_events.count(&"fishing_hook") == hook_events_before + 1,
		"the deep hook emits its authored cue once")
	_check_no_old_visual_prose(rig, fishing, "deep HOOKED")
	var before_deep_land: int = _civil_minute()
	catch_events_before = fishing_sfx_events.count(&"fishing_catch")
	fishing.debug_land_catch()
	rig.check(Game.fish_stock == 2 and Game.fish_units_today == 2,
		"a deep catch banks exactly two Fish and two daily units")
	rig.check(_civil_minute() == before_deep_land + 10,
		"the deep outcome advances civil time by exactly ten minutes")
	rig.check(fishing.feedback_mode_name() == &"result_success"
		and Sfx.last_positional_semantic_cue == &"fishing_catch"
		and fishing_sfx_events.count(&"fishing_catch") == catch_events_before + 1,
		"the deep RESULT reveals x2 and emits exactly one semantic catch cue")
	_check_no_old_visual_prose(rig, fishing, "RESULT success x2")
	await rig.wait_frames(4)
	await rig.capture("fishing_08_result_success_x2.png")
	var deep_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(deep_closed and not Prompt.blocked,
		"the deep RESULT exits and releases Prompt after its result delay")

	Game.restore_garrison({})
	Clock.set_time(3, 12.0)
	var failure_started: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"near"),
		"a failure probe begins through the ordinary capacity gate")
	await rig.wait_frames(3)
	cast_events_before = fishing_sfx_events.count(&"fishing_cast")
	await rig.tap([&"interact"])
	var failure_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(failure_waiting and _civil_minute() == failure_started,
		"the failure probe reaches WAITING without charging time")
	rig.check(fishing_sfx_events.count(&"fishing_cast") == cast_events_before + 1,
		"the failed attempt still voices its one cast beat")
	bite_events_before = fishing_sfx_events.count(&"fishing_bite")
	fishing.debug_force_bite()
	rig.check(fishing_sfx_events.count(&"fishing_bite") == bite_events_before + 1,
		"the failed attempt still voices its one BITE beat")
	var failure_stock_before: int = Game.fish_stock
	var failure_minutes_before: int = _civil_minute()
	var fail_events_before: int = fishing_sfx_events.count(&"fishing_fail")
	fishing.debug_fail_attempt()
	rig.check(fishing.state_name() == &"result"
		and fishing.feedback_mode_name() == &"result_failure",
		"the failure seam enters the real failure RESULT presentation")
	rig.check(Game.fish_stock == failure_stock_before and Game.fish_units_today == 0,
		"a failed attempt banks no Fish")
	rig.check(_civil_minute() == failure_minutes_before + 10,
		"a failed attempt advances civil time by exactly ten minutes")
	rig.check(Sfx.last_positional_semantic_cue == &"fishing_fail"
		and fishing_sfx_events.count(&"fishing_fail") == fail_events_before + 1,
		"the failure outcome emits exactly one semantic fishing_fail cue")
	_check_no_old_visual_prose(rig, fishing, "RESULT failure")
	await rig.wait_frames(4)
	await rig.capture("fishing_09_result_failure.png")
	var failure_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(failure_closed and not Prompt.blocked,
		"the charged failure RESULT closes cleanly")

	Clock.set_time(3, 13.0)
	Game.restore_garrison({
		"fish_stock": 2,
		"fish_caught_day": 3,
		"fish_units_today": 0,
	})
	var before_deep_refusal: int = _civil_minute()
	rig.check(not fishing.begin_for_test(&"deep"),
		"deep water refuses rather than partially overflowing a reserve at two")
	rig.check(fishing.state_name() == &"idle" and not Prompt.blocked,
		"the deep overflow refusal leaves IDLE and input unblocked")
	rig.check(_civil_minute() == before_deep_refusal,
		"the deep overflow refusal costs zero civil time")
	var before_near_allowed: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"near"),
		"near water remains available when exactly one reserve space remains")
	rig.check(fishing.state_name() == &"choose" and Prompt.blocked,
		"the allowed near start owns input normally")
	rig.check(_civil_minute() == before_near_allowed,
		"the allowed near start does not move civil time")
	var before_near_cleanup: int = _civil_minute()
	await rig.tap([&"ui_cancel"])
	var near_cleanup: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 1.0)
	rig.check(near_cleanup and not Prompt.blocked,
		"the allowed near capacity probe cancels cleanly")
	rig.check(_civil_minute() == before_near_cleanup,
		"cancelling the capacity probe costs zero civil time")

	Game.restore_garrison({
		"fish_caught_day": 3,
		"fish_units_today": Game.FISH_DAILY_CAP,
	})
	var before_spent_refusal: int = _civil_minute()
	rig.check(not fishing.begin_for_test(&"near"),
		"all spent daily yield refuses a new fishing attempt")
	rig.check(fishing.state_name() == &"idle" and not Prompt.blocked,
		"the spent-water refusal leaves IDLE and input unblocked")
	rig.check(_civil_minute() == before_spent_refusal,
		"the spent-water refusal costs zero civil time")

	var outcome_sfx_events: Array[StringName] = []
	for event: StringName in fishing_sfx_events:
		if event != &"fishing_reel" and event != &"fishing_strain":
			outcome_sfx_events.append(event)
	var expected_outcome_sfx: Array[StringName] = [
		&"fishing_cast", &"fishing_bite", &"fishing_hook", &"fishing_catch",
		&"fishing_cast", &"fishing_bite", &"fishing_hook", &"fishing_catch",
		&"fishing_cast", &"fishing_bite", &"fishing_fail",
	]
	rig.check(outcome_sfx_events == expected_outcome_sfx,
		"cast/bite/hook/catch/fail cues occur only at their authored beats")
	rig.check(fishing_sfx_events.count(&"fishing_reel") >= 1
		and fishing_sfx_events.count(&"fishing_strain") >= 1,
		"neutral reeling and directional pull each voice their authored cue")
	Bus.request_sfx.disconnect(observe_fishing_sfx)

	Clock.running = true
	if rig.fails == 0:
		print("FISHING PROVISIONS OK")


func _civil_minute() -> int:
	return (Clock.day - 1) * 24 * 60 + int(floor(Clock.hour * 60.0 + 0.0001))


func _check_no_old_visual_prose(rig, fishing: FishingHole, beat: String) -> void:
	var visible_text: String = fishing.feedback_visual_text().to_upper()
	for phrase: String in [
			"WATCH THE WATER", "FISH RUNS", "STEER RIGHT", "STEER LEFT",
			"HOLD INTERACT", "PRESS INTERACT", "WAIT FOR THE SPLASH",
			"CANCEL CLOSE", "CANCEL: CLOSE", "HOOK NOW", "RELEASE TO EASE"]:
		rig.check(not visible_text.contains(phrase),
			"%s visual text omits '%s'" % [beat, phrase])
