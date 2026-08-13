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
	Game.tool_durabilities.erase(ToolDb.FISHING_ROD_ID)
	Game.items.erase(ToolDb.FISHING_ROD_ID)
	Game.grant(ToolDb.FISHING_ROD_ID)
	var rod_maximum: int = Game.tool_max_durability(ToolDb.FISHING_ROD_ID)
	rig.check(rod_maximum == 10
		and Game.tool_durability(ToolDb.FISHING_ROD_ID) == rod_maximum,
		"the granted Fishing Rod begins at its exact 10 / 10 durability")
	await rig.wait_frames(6)

	var fishing := outskirts.fishing_hole as FishingHole
	if not rig.check(fishing != null, "outskirts exposes a live fishing_hole"):
		return
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
	var durability_before_cancel: int = Game.tool_durability(ToolDb.FISHING_ROD_ID)
	rig.check(fishing.begin_for_test(&"near"), "near water enters the fishing FSM")
	rig.check(fishing.state_name() == &"choose" and Prompt.blocked,
		"begin_for_test enters CHOOSE and blocks Prompt")
	rig.check(_civil_minute() == before_begin_cancel,
		"opening the fishing choice costs no civil time")
	await rig.wait_frames(3)
	var choose_text := " ".join(_all_text(fishing))
	rig.check(choose_text.contains("ROD %d / %d" % [durability_before_cancel,
		rod_maximum]), "the live fishing overlay reports Rod durability")
	await rig.capture("fishing_01_choose.png")
	var before_cancel: int = _civil_minute()
	await rig.tap([&"ui_cancel"])
	var cancelled: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 1.0)
	rig.check(cancelled and not Prompt.blocked,
		"real ui_cancel exits to IDLE and releases Prompt")
	rig.check(_civil_minute() == before_cancel,
		"a cancelled attempt costs zero civil minutes")
	rig.check(Game.tool_durability(ToolDb.FISHING_ROD_ID) == durability_before_cancel,
		"a cancelled attempt spends no Rod durability")

	Game.restore_garrison({})
	Clock.set_time(1, 9.0)
	var durability_before_near: int = Game.tool_durability(ToolDb.FISHING_ROD_ID)
	var near_started: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"near"), "a fresh near attempt begins")
	rig.check(_civil_minute() == near_started,
		"beginning the near attempt does not move civil time")
	await rig.wait_frames(3)
	var before_near_cast: int = _civil_minute()
	await rig.tap([&"interact"])
	var near_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(near_waiting, "real interact press and release casts into near water")
	rig.check(_civil_minute() == before_near_cast,
		"casting the near line costs no civil time before its outcome")
	var before_near_bite: int = _civil_minute()
	fishing.debug_force_bite()
	rig.check(fishing.state_name() == &"bite", "the deterministic seam forces a near bite")
	rig.check(_civil_minute() == before_near_bite,
		"forcing the near bite does not alter civil time")
	var before_near_hook: int = _civil_minute()
	await rig.tap([&"interact"])
	var near_hooked: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"hooked", 1.0)
	rig.check(near_hooked, "the real hook press enters HOOKED")
	rig.check(_civil_minute() == before_near_hook,
		"hooking the near fish does not charge time early")
	await rig.wait_frames(3)
	await rig.capture("fishing_02_hooked.png")
	var before_near_land: int = _civil_minute()
	fishing.debug_land_catch()
	rig.check(fishing.state_name() == &"result", "landing enters RESULT")
	rig.check(Game.fish_stock == 1 and Game.fish_units_today == 1,
		"a near catch banks exactly one Fish and one daily unit")
	rig.check(_civil_minute() == before_near_land + 10,
		"the near outcome advances civil time by exactly ten minutes")
	rig.check(Game.tool_durability(ToolDb.FISHING_ROD_ID)
		== durability_before_near - 1,
		"the resolved near catch spends exactly one Rod durability")
	await rig.wait_frames(4)
	await rig.capture("fishing_03_result_creel.png")
	var near_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(near_closed and not Prompt.blocked,
		"the near RESULT exits and releases Prompt after its result delay")

	Game.restore_garrison({})
	Clock.set_time(2, 11.0)
	var durability_before_deep: int = Game.tool_durability(ToolDb.FISHING_ROD_ID)
	var deep_started: int = _civil_minute()
	rig.check(fishing.begin_for_test(&"deep"), "deep water begins on a fresh day and state")
	rig.check(_civil_minute() == deep_started,
		"beginning the deep attempt does not move civil time")
	await rig.wait_frames(3)
	var before_deep_cast: int = _civil_minute()
	await rig.tap([&"interact"])
	var deep_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(deep_waiting, "real interact press and release casts into deep water")
	rig.check(_civil_minute() == before_deep_cast,
		"casting the deep line costs no civil time before its outcome")
	var before_deep_bite: int = _civil_minute()
	fishing.debug_force_bite()
	rig.check(fishing.state_name() == &"bite", "the deterministic seam forces a deep bite")
	rig.check(_civil_minute() == before_deep_bite,
		"forcing the deep bite does not alter civil time")
	var before_deep_hook: int = _civil_minute()
	await rig.tap([&"interact"])
	var deep_hooked: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"hooked", 1.0)
	rig.check(deep_hooked, "the real hook press enters deep HOOKED")
	rig.check(_civil_minute() == before_deep_hook,
		"hooking the deep fish does not charge time early")
	var before_deep_land: int = _civil_minute()
	fishing.debug_land_catch()
	rig.check(Game.fish_stock == 2 and Game.fish_units_today == 2,
		"a deep catch banks exactly two Fish and two daily units")
	rig.check(_civil_minute() == before_deep_land + 10,
		"the deep outcome advances civil time by exactly ten minutes")
	rig.check(Game.tool_durability(ToolDb.FISHING_ROD_ID)
		== durability_before_deep - 1,
		"the resolved deep catch spends exactly one Rod durability")
	var deep_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(deep_closed and not Prompt.blocked,
		"the deep RESULT exits and releases Prompt after its result delay")

	# A missed bite is a resolved attempt too: no fish enters the reserve, while
	# the same outcome transaction spends ten civil minutes and one Rod use.
	Game.restore_garrison({})
	Clock.set_time(3, 12.0)
	var failure_stock_before: int = Game.fish_stock
	var failure_time_before: int = _civil_minute()
	var failure_durability_before: int = Game.tool_durability(
		ToolDb.FISHING_ROD_ID)
	rig.check(fishing.begin_for_test(&"near"),
		"a deterministic failure attempt begins through the real Rod gate")
	await rig.wait_frames(3)
	await rig.tap([&"interact"])
	var failure_waiting: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"waiting", 1.0)
	rig.check(failure_waiting, "the failure probe casts through real input")
	fishing.debug_force_bite()
	var failure_resolved: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"result", 2.0)
	rig.check(failure_resolved and Game.fish_stock == failure_stock_before,
		"letting the deterministic bite expire resolves failure without a catch")
	rig.check(_civil_minute() == failure_time_before + 10,
		"the resolved failure advances civil time by exactly ten minutes")
	rig.check(Game.tool_durability(ToolDb.FISHING_ROD_ID)
		== failure_durability_before - 1,
		"the resolved failure spends exactly one Rod durability")
	var failure_closed: bool = await rig.until(
		func() -> bool: return fishing.state_name() == &"idle", 3.0)
	rig.check(failure_closed and not Prompt.blocked,
		"the failed RESULT exits and releases Prompt after its result delay")

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

	Clock.running = true
	if rig.fails == 0:
		print("FISHING PROVISIONS OK")


func _civil_minute() -> int:
	return (Clock.day - 1) * 24 * 60 + int(floor(Clock.hour * 60.0 + 0.0001))


func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var label := root as Label
	if label != null and not label.text.strip_edges().is_empty():
		out.append(label.text)
	for child: Node in root.get_children():
		out.append_array(_all_text(child))
	return out
