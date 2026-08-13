extends RefCounted
## Deterministic behavior and visual proof for docs/GARRISON_LIFE.md.
##
## Run from the garrison:
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_life.gd \
##     --out=/tmp/garrison-life/life.png --warmup=60


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the garrison"):
		return
	Clock.running = false
	Clock.set_time(1, 8.0)
	Game.restore_garrison({})
	Menu.close()
	for who: StringName in StoryDb.INTRO_ORDER:
		Game.set_flag(StoryDb.arrival_flag(who))
		Game.set_flag(StoryDb.intro_flag(who))

	await _assignment_and_axe(rig)
	await _timber_view(rig, garrison)
	await _daily_state(rig)
	await _hearth_and_schedule(rig, garrison)
	await _morale_state(rig)
	await _well_fed_run(rig)
	await _menu(rig)

	Menu.close()
	Clock.running = true
	if rig.fails == 0:
		print("GARRISON LIFE OK")


func _assignment_and_axe(rig) -> void:
	var briefing := StoryDb.told_flag(&"elder", &"briefing")
	var duty := StoryDb.told_flag(&"elder", &"timber_duty")
	var haul := StoryDb.told_flag(&"elder", &"first_haul")
	Game.flags.erase(duty)
	Game.flags.erase(haul)
	for id: StringName in ToolDb.TOOL_IDS:
		Game.items.erase(id)
		Game.tool_durabilities.erase(id)
		Run.bag.erase(id)
		Game.stash.erase(id)
	Game.set_flag(briefing)
	Game.grant(StoryDb.SMITH_TOKEN)
	Game.gold_earned = maxi(Game.gold_earned, 300)

	for id: StringName in ToolDb.TOOL_IDS:
		var unmade: Dictionary = ToolDb.definition(id)
		rig.check(not Game.tool_known(id) and not Game.tool_usable(id)
			and not Game.has(id) and Game.tool_durability(id) == 0
			and not bool(unmade.get("known", true)),
			"%s starts unmade rather than broken" % unmade.get("display_name", id))

	var pending: Dictionary = StoryDb.pending(&"elder")
	rig.check(StringName(pending.get("id", &"")) == &"timber_duty",
		"Keep the Hearth takes priority over the eligible first-haul beat")
	rig.check(not ShopDb.stocked(ShopDb.WOODSMAN_AXE_ID),
		"the axe line is hidden before Aldric assigns the duty")
	StoryDb.mark_told(&"elder", &"timber_duty")
	rig.check(ShopDb.stocked(ShopDb.WOODSMAN_AXE_ID),
		"the axe line appears after the assignment")
	pending = StoryDb.pending(&"elder")
	rig.check(StringName(pending.get("id", &"")) == &"first_haul",
		"the first-haul beat remains waiting behind the duty")

	var yard := HarvestTree.new()
	Game.restore_garrison({})
	yard.activate(null)
	rig.check(not Game.carrying_firewood and Game.timber_completed_day == 0,
		"an assigned duty without an axe cannot cut a bundle")
	yard.free()

	# All three lines are the smith's actual public catalogue transactions. Tool
	# materials come from the returned run bag; only the Rod also reaches into
	# stored hearth stock, and every successful forge fills durability outright.
	var recipes := {
		ToolDb.WOODSMAN_AXE_ID: {"gold": 60, "scrap": 3, "firewood": 0, "max": 8},
		ToolDb.PICKAXE_ID: {"gold": 75, "scrap": 3, "firewood": 0, "max": 12},
		ToolDb.FISHING_ROD_ID: {"gold": 45, "scrap": 1, "firewood": 1, "max": 10},
	}
	Game.gold = 180
	Run.bag.clear()
	Run.bag[&"iron_scrap"] = 7
	Run.premium = 0
	Game.restore_garrison({"firewood_stock": 1})
	var wheel_before: Array[StringName] = Game.wheel.duplicate()
	for id: StringName in ToolDb.TOOL_IDS:
		var expected: Dictionary = recipes[id]
		var line := _catalogue_line(ShopDb.lines(), id)
		var parts: Dictionary = line.get("parts", {})
		var name := String(ToolDb.definition(id).get("display_name", id))
		rig.check(not line.is_empty() and int(line.get("cost", -1))
			== int(expected["gold"]), "%s has its exact gold recipe" % name)
		rig.check(parts.size() == 1 and int(parts.get(&"iron_scrap", 0))
			== int(expected["scrap"]),
			"%s has its exact returned-bag Iron Scrap recipe" % name)
		rig.check(int(line.get("stored_firewood", -1)) == int(expected["firewood"]),
			"%s has its exact stored-firewood recipe" % name)
		var gold_before: int = Game.gold
		var scrap_before: int = int(Run.bag.get(&"iron_scrap", 0))
		var firewood_before: int = Game.firewood_stock
		rig.check(ShopDb.can_buy(line), "%s's seeded bill is affordable" % name)
		rig.check(ShopDb.buy(line), "Brannoc forges %s" % name)
		rig.check(Game.gold == gold_before - int(expected["gold"])
			and int(Run.bag.get(&"iron_scrap", 0))
			== scrap_before - int(expected["scrap"])
			and Game.firewood_stock == firewood_before - int(expected["firewood"]),
			"%s consumes gold, returned-bag scrap, and stored firewood exactly" % name)
		rig.check(Game.tool_known(id) and Game.tool_usable(id) and Game.has(id)
			and Game.tool_durability(id) == int(expected["max"])
			and Game.tool_max_durability(id) == int(expected["max"]),
			"%s is forged at full durability" % name)
		var completed := _catalogue_line(ShopDb.lines(), id)
		rig.check(int(completed.get("cost", -1)) == 0
			and ShopDb.remaining(id) == 0,
			"the ready %s line cannot be crafted twice" % name)

	rig.check(Game.gold == 0 and not Run.bag.has(&"iron_scrap")
		and Game.firewood_stock == 0,
		"the combined three-tool bill is exactly 180g, seven Scrap, and one firewood")
	rig.check(Game.wheel == wheel_before and _tools_outside_equipment_graphs(rig),
		"utility tools never enter the wheel, bag, stash, hands, or combat armaments")

	# Spend a Rod through its public durability API. Known-at-zero is BROKEN,
	# unlike the never-crafted state above, and the smith exposes a fresh bill.
	while Game.tool_usable(ToolDb.FISHING_ROD_ID):
		Game.spend_tool_use(ToolDb.FISHING_ROD_ID)
	var broken: Dictionary = ToolDb.definition(ToolDb.FISHING_ROD_ID)
	var broken_line := _catalogue_line(ShopDb.lines(), ToolDb.FISHING_ROD_ID)
	rig.check(Game.tool_known(ToolDb.FISHING_ROD_ID)
		and not Game.tool_usable(ToolDb.FISHING_ROD_ID)
		and not Game.has(ToolDb.FISHING_ROD_ID)
		and Game.tool_durability(ToolDb.FISHING_ROD_ID) == 0
		and bool(broken.get("known", false))
		and String(broken_line.get("detail", "")).contains("BROKEN"),
		"a spent Rod is known BROKEN at 0 / 10, not unmade")
	Game.gold = 45
	Run.bag[&"iron_scrap"] = 1
	Game.restore_garrison({"firewood_stock": 1})
	rig.check(ShopDb.can_buy(broken_line) and ShopDb.buy(broken_line),
		"the public smith transaction reforges the broken Rod")
	rig.check(Game.tool_usable(ToolDb.FISHING_ROD_ID)
		and Game.tool_durability(ToolDb.FISHING_ROD_ID) == 10
		and Game.gold == 0 and not Run.bag.has(&"iron_scrap")
		and Game.firewood_stock == 0,
		"reforging pays the exact recipe and restores the Rod to full")
	rig.check(_tools_outside_equipment_graphs(rig),
		"reforging still leaves every utility tool outside equipment graphs")


func _timber_view(rig, garrison: Garrison) -> void:
	var packed := load("res://scenes/rooms/garrison_outskirts.tscn") as PackedScene
	if not rig.check(packed != null, "the authored garrison outskirts scene loads"):
		return
	var original_hero := rig.root.get_tree().get_first_node_in_group(&"player") as Node3D
	var outskirts := packed.instantiate() as GarrisonOutskirts
	rig.root.add_child(outskirts)
	garrison.visible = false
	for player: Node in rig.root.get_tree().get_nodes_in_group(&"player"):
		var body := player as Node3D
		if body != null:
			body.visible = false
			body.remove_from_group(&"player")
	Prompt.drop_focus()
	Clock.set_time(1, 12.0)
	await rig.wait_frames(12)
	rig.check(outskirts.harvest_trees.size() == 10,
		"the exterior route contains a ten-tree working grove")
	rig.check(outskirts.port(&"grove").origin != Vector3.ZERO,
		"the grove entrance has an authored exterior port")

	var cam := Camera3D.new()
	cam.fov = 52.0
	outskirts.add_child(cam)
	cam.global_position = Vector3(-3.8, 9.4, 22.5)
	cam.look_at(outskirts.port(&"grove").origin + Vector3(0.0, 2.8, 0.0), Vector3.UP)
	cam.make_current()
	await rig.wait_frames(6)
	await rig.capture("life_00_grove.png")

	outskirts.queue_free()
	garrison.visible = true
	if original_hero != null:
		original_hero.visible = true
		original_hero.add_to_group(&"player")
	await rig.wait_frames(4)


func _daily_state(rig) -> void:
	Clock.set_time(1, 10.0)
	Game.restore_garrison({})
	rig.check(Game.chop_firewood(Clock.day, Clock.garrison_phase()),
		"the axe-holder can cut one daytime bundle")
	rig.check(not Game.chop_firewood(Clock.day, Clock.garrison_phase()),
		"a second bundle on the same day is refused")
	rig.check(Game.carrying_firewood and Game.firewood_stock == 0,
		"the cut bundle is carried, not teleported into the hearth")
	rig.check(Game.deposit_firewood(), "the separate hearth deposit succeeds")
	rig.check(not Game.carrying_firewood and Game.firewood_stock == 1,
		"deposit moves exactly one carried bundle into stock")

	Game.restore_garrison({
		"firewood_stock": 3,
		"carrying_firewood": true,
		"timber_completed_day": 1,
	})
	rig.check(not Game.deposit_firewood() and Game.firewood_stock == Game.FIREWOOD_CAP,
		"the hearth stock cap refuses overflow")

	Game.restore_garrison({})
	rig.check(Game.garrison_snapshot() == {
		"firewood_stock": 0,
		"carrying_firewood": false,
		"timber_completed_day": 0,
		"warmth_active": false,
		"last_bonfire_day": 0,
		"fish_stock": 0,
		"fish_caught_day": 0,
		"fish_units_today": 0,
		"fed_active": false,
		"last_supper_day": 0,
		"well_fed_ready": false,
		"well_fed_trip": false,
		"connected_days": {},
		"raid": _default_raid(),
	}, "an older save's absent garrison payload defaults empty and cold")
	var saved: Dictionary = {
		"firewood_stock": 2,
		"carrying_firewood": true,
		"timber_completed_day": 4,
		"warmth_active": true,
		"last_bonfire_day": 3,
		"fish_stock": 2,
		"fish_caught_day": 4,
		"fish_units_today": 2,
		"fed_active": true,
		"last_supper_day": 3,
		"well_fed_ready": true,
		"well_fed_trip": true,
		"connected_days": {"elder": 4},
		"raid": _default_raid(),
	}
	Game.restore_garrison(saved)
	var expected_saved: Dictionary = saved.duplicate(true)
	expected_saved["connected_days"] = {&"elder": 4}
	var restored_saved: Dictionary = Game.garrison_snapshot()
	rig.check(restored_saved == expected_saved,
		"Firewood, Fish, Fed, Well Fed, Connected, and raid state all round-trip")
	var restored_connected := restored_saved.get("connected_days", {}) as Dictionary
	var restored_keys: Array = restored_connected.keys()
	var restored_key: Variant = restored_keys[0] if not restored_keys.is_empty() else null
	rig.check(restored_key is StringName and restored_key == &"elder",
		"JSON-style Connected String keys restore as typed StringName keys")
	rig.check(Saves.VERSION == 16,
		"the durable-tool additive save contract is version 16")

	Game.restore_garrison({
		"fish_stock": 2,
		"fish_caught_day": 4,
		"fish_units_today": 0,
	})
	rig.check(Game.bank_fish(2, 4) == 0 and Game.fish_stock == 2,
		"fish banking refuses a partial reserve overflow")
	rig.check(Game.bank_fish(1, 4) == 1 and Game.fish_stock == Game.FISH_CAP,
		"fish banking fills the final reserve space exactly")
	rig.check(Game.bank_fish(1, 4) == 0,
		"a full fish reserve refuses every further yield")
	Game.restore_garrison({
		"fish_caught_day": 4,
		"fish_units_today": Game.FISH_DAILY_CAP,
	})
	rig.check(not Game.can_bank_fish(1, 4),
		"a fully spent daily yield refuses another bank on that day")
	rig.check(Game.fishing_remaining_today(5) == Game.FISH_DAILY_CAP
		and Game.fish_caught_day == 4 and Game.fish_units_today == Game.FISH_DAILY_CAP,
		"reading the next day's yield is full and does not mutate campaign state")
	rig.check(Game.bank_fish(Game.FISH_DAILY_CAP, 5) == Game.FISH_DAILY_CAP
		and Game.fish_caught_day == 5 and Game.fish_units_today == Game.FISH_DAILY_CAP
		and not Game.can_bank_fish(1, 5),
		"the first bank on a new day owns the rollover, fills its yield, then refuses more")

	Game.restore_garrison({})
	Game.grant(&"bow")
	Run.bag = {&"blood_ruby": 1}
	Run.premium = 0
	var cold_sell := Run.line_value(&"blood_ruby")
	var cold_arrows := int(_catalogue_line(SupplyDb.lines(), &"arrows").get("cost", -1))
	var cold_slot := int(_catalogue_line(SupplyDb.lines(), &"bag_slot").get("cost", -1))
	Game.restore_garrison({"warmth_active": true})
	var warm_sell := Run.line_value(&"blood_ruby")
	var warm_arrows := int(_catalogue_line(SupplyDb.lines(), &"arrows").get("cost", -1))
	var warm_slot := int(_catalogue_line(SupplyDb.lines(), &"bag_slot").get("cost", -1))
	rig.check(cold_sell == 46 and warm_sell == 51,
		"Warmth changes a 46-gold ordinary sale to 51 after one final rounding")
	rig.check(cold_arrows == 40 and warm_arrows == 36,
		"Warmth changes ordinary 40-gold Trade stock to 36")
	rig.check(cold_slot == warm_slot and cold_slot > 0,
		"Warmth does not discount the permanent bag-slot ladder")


func _hearth_and_schedule(rig, garrison: Garrison) -> void:
	var port_ids: Array[StringName] = [&"hearth"]
	for who: StringName in [&"quartermaster", &"smith", &"alchemist", &"elder", &"jewelcrafter"]:
		for suffix: String in ["day", "bonfire", "sleep"]:
			port_ids.append(StringName("%s_%s" % [who, suffix]))
	for id: StringName in port_ids:
		rig.check(garrison.compound.has_port(id), "compound has authored port %s" % id)

	Clock.restore({"day": 2, "hour": 12.0, "running": false})
	Game.restore_garrison({"firewood_stock": 2, "fish_stock": 2})
	await rig.wait_frames(5)
	var cam := Camera3D.new()
	cam.fov = 55.0
	garrison.add_child(cam)
	cam.global_position = Vector3(8.5, 6.8, 9.5)
	cam.look_at(garrison.hearth.global_position + Vector3.UP * 1.0, Vector3.UP)
	cam.make_current()
	await rig.wait_frames(5)
	await rig.capture("life_01_hearth_day.png")

	var cold_before := Game.warmth_active
	Clock.set_time(2, 19.99)
	rig.check(Game.warmth_active == cold_before and Game.firewood_stock == 2,
		"stocking wood before 20:00 does not grant an immediate price bonus")
	Clock.set_time(2, 20.0)
	await rig.wait_frames(6)
	rig.check(Game.warmth_active and Game.fed_active
		and Game.firewood_stock == 1 and Game.fish_stock == 1
		and Game.last_bonfire_day == 2 and Game.last_supper_day == 2
		and Game.well_fed_ready,
		"20:00 consumes one wood and one Fish, activates Warm and Fed, and readies Well Fed")
	Game.resolve_bonfire(2)
	rig.check(Game.firewood_stock == 1 and Game.fish_stock == 1,
		"the same campaign day's supper consumes neither wood nor Fish twice")

	var roster: Array[Npc] = [garrison.vendor, garrison.smith, garrison.alchemist,
		garrison.keeper, garrison.jeweller]
	for npc: Npc in roster:
		rig.check(npc != null, "all five arrived NPCs are present for the schedule proof")
		if npc == null:
			continue
		rig.check(npc.current_activity() == Npc.ACTIVITY_BONFIRE,
			"%s gathers at Bonfire Time" % npc.name)
		rig.check(not npc.current_services_open() and npc.enabled,
			"%s remains talkable while services are closed" % npc.name)
	await rig.capture("life_02_bonfire.png")

	var before_restore := Game.garrison_snapshot()
	Clock.restore({"day": 2, "hour": 20.5, "running": false})
	Game.restore_garrison(before_restore)
	await rig.wait_frames(2)
	rig.check(Game.garrison_snapshot() == before_restore,
		"restoring a 20:30 save does not replay the bonfire")

	Game.restore_garrison({
		"fed_active": true,
		"last_bonfire_day": 2,
		"last_supper_day": 2,
		"well_fed_ready": true,
	})
	rig.check(Game.resolve_bonfire(3), "the next empty supper resolves once")
	rig.check(not Game.fed_active and Game.well_fed_ready
		and Game.last_supper_day == 3,
		"an empty later supper clears Fed but preserves an unused ready meal")

	Clock.set_time(2, 23.0)
	await rig.wait_frames(4)
	for npc: Npc in roster:
		if npc != null:
			rig.check(npc.current_activity() == Npc.ACTIVITY_SLEEP and not npc.enabled,
				"%s retires at Bedtime" % npc.name)

	Game.restore_garrison({"firewood_stock": 2, "last_bonfire_day": 2})
	Clock.restore({"day": 3, "hour": 8.0, "running": false})
	Clock.set_time(5, 20.0)
	rig.check(Game.firewood_stock == 0 and not Game.warmth_active
		and Game.last_bonfire_day == 5,
		"multi-night jumps resolve each bonfire chronologically and end cold")


func _morale_state(rig) -> void:
	Game.restore_garrison({})
	rig.check(Game.morale_causes(&"elder", 5) == PackedStringArray()
		and Game.morale_label(&"elder", 5) == "Low",
		"zero morale causes report Low")
	Game.restore_garrison({"warmth_active": true})
	rig.check(Game.morale_causes(&"elder", 5) == PackedStringArray(["Warm"])
		and Game.morale_label(&"elder", 5) == "Uneasy",
		"Warm is first in cause order and one cause reports Uneasy")
	Game.restore_garrison({"warmth_active": true, "fed_active": true})
	rig.check(Game.morale_causes(&"elder", 5) == PackedStringArray(["Warm", "Fed"])
		and Game.morale_label(&"elder", 5) == "Steady",
		"Warm then Fed is stable cause order and two causes report Steady")
	rig.check(Game.record_substantive_conversation(&"elder", 5),
		"a substantive conversation records Connected on its civil day")
	rig.check(Game.morale_causes(&"elder", 5)
		== PackedStringArray(["Warm", "Fed", "Connected"])
		and Game.morale_label(&"elder", 5) == "High",
		"Connected follows Warm and Fed and three causes report High")
	rig.check(Game.morale_causes(&"elder", 6)
		== PackedStringArray(["Warm", "Fed", "Connected"]),
		"Connected remains active on the next civil day")
	rig.check(Game.morale_causes(&"elder", 7) == PackedStringArray(["Warm", "Fed"])
		and Game.morale_label(&"elder", 7) == "Steady",
		"Connected expires after the next day without disturbing other causes")


func _well_fed_run(rig) -> void:
	var focus_track: StringName = Game.jewel_track(&"amulet", &"focus")
	var had_focus: bool = Game.upgrades.has(focus_track)
	var focus_before: int = int(Game.upgrades.get(focus_track, 0))
	var gold_before: int = Game.gold
	var deaths_before: int = Game.deaths
	var quarters_before: int = Game.quarters
	var stamina_before: float = Game.stamina
	var flow_busy_before: bool = Flow.busy

	Run.reset()
	Game.end_well_fed_trip()
	Game.upgrades[focus_track] = maxi(2, focus_before)
	Game.resync_maxima(false)
	var permanent_max: float = Game.max_stamina
	Game.restore_garrison({"well_fed_ready": true})
	Game.stamina = 1.0
	Run.enter(168001)
	var effective_max: float = Game.max_stamina
	rig.check(not Game.well_fed_ready and Game.well_fed_trip,
		"Run.enter consumes the ready meal into this trip")
	rig.check(is_equal_approx(effective_max,
		permanent_max + Game.WELL_FED_STAMINA),
		"Well Fed adds exactly 15 outside the permanent Focus maximum")
	rig.check(is_equal_approx(Game.stamina, effective_max),
		"Run.enter fills stamina to the effective Well Fed maximum")

	var resumable: Dictionary = Run.snapshot()
	resumable["stamina"] = effective_max + 50.0
	Game.stamina = 0.0
	rig.check(Run.restore(resumable), "the live run snapshot restores without a real slot")
	rig.check(is_equal_approx(Game.stamina, effective_max),
		"a resumable run clamps restored stamina to the effective maximum")

	Game.gold = maxi(Game.gold, 100)
	Flow.busy = true
	rig.check(Run.extract(), "the Well Fed run extracts through the public contract")
	rig.check(not Run.in_dungeon and not Game.well_fed_trip
		and is_equal_approx(Game.max_stamina, permanent_max)
		and Game.stamina <= permanent_max,
		"extraction clears the trip and restores and clamps the permanent maximum")

	Game.restore_garrison({"well_fed_ready": true})
	Run.enter(168002)
	Game.stamina = Game.max_stamina
	Run.die()
	rig.check(not Run.in_dungeon and not Game.well_fed_trip
		and is_equal_approx(Game.max_stamina, permanent_max)
		and Game.stamina <= permanent_max,
		"death clears the trip and restores and clamps the permanent maximum")

	Run.reset()
	Flow.busy = flow_busy_before
	Game.gold = gold_before
	Game.deaths = deaths_before
	Game.quarters = quarters_before
	if had_focus:
		Game.upgrades[focus_track] = focus_before
	else:
		Game.upgrades.erase(focus_track)
	Game.restore_garrison({})
	Game.resync_maxima(false)
	Game.stamina = minf(stamina_before, Game.max_stamina)
	rig.check(not Run.in_dungeon and not Game.well_fed_trip,
		"the run proof leaves lawful non-dungeon state for later beats")


func _menu(rig) -> void:
	Game.restore_garrison({
		"firewood_stock": 2,
		"timber_completed_day": 6,
		"warmth_active": true,
		"last_bonfire_day": 5,
		"fish_stock": 2,
		"fish_caught_day": 6,
		"fish_units_today": 1,
		"fed_active": true,
		"last_supper_day": 5,
		"well_fed_ready": true,
		"connected_days": {"elder": 6},
	})
	Clock.restore({"day": 6, "hour": 12.5, "running": false})
	Menu.open()
	Menu.call(&"_open_onto", PauseMenu.Screen.GARRISON)
	await rig.wait_frames(5)
	var panel := Menu.get_node("Root/Screens/GarrisonScreen") as MenuGarrisonPanel
	rig.check(panel != null and panel.visible, "the root command opens GARRISON")
	if panel == null:
		return
	var page_text := " ".join(_all_text(panel))
	for phrase: String in ["Day", "Bonfire", "Garrison Warmth", "PROVISIONS & MORALE",
			"Fish reserve", "Fed", "Well Fed", "Overall morale", "KEEP THE HEARTH",
			"ROSTER", "DONATED RELIC EFFECTS", "ELDER IMPROVEMENTS"]:
		rig.check(page_text.contains(phrase), "the Garrison page reports %s" % phrase)
	var focus: Control = rig.root.gui_get_focus_owner()
	rig.check(focus != null and focus.name == &"Back",
		"opening GARRISON places focus on Back")
	var scroll := panel.get_node("Center/Frame/Col/StatusScroll") as ScrollContainer
	var provisions := _label_with_text(panel, "PROVISIONS & MORALE")
	rig.check(scroll != null and scroll.scroll_vertical == 0,
		"opening the expanded Garrison page begins at the top without scrolling")
	rig.check(scroll != null and provisions != null
		and provisions.get_global_rect().intersects(scroll.get_global_rect()),
		"the Provisions & Morale section is visibly present in the opening viewport")
	await rig.capture("life_03_garrison_menu.png")

	var strip := _first_tabs(panel)
	rig.check(strip != null and strip.get_child_count() == 4,
		"the focusable four-page tab strip is present")
	if strip != null:
		strip.focus_home()
		_key(KEY_RIGHT)
		await rig.wait_frames(3)
		var equip := Menu.get_node("Root/Screens/EquipScreen") as Control
		rig.check(equip.visible, "right from GARRISON wraps to EQUIP")
		var equip_text := " ".join(_all_text(equip))
		rig.check(equip_text.contains("TOOLS") and equip_text.contains("WOODSMAN'S AXE"),
			"Equipment stores the permanent Woodsman's Axe in its read-only Tools section")
		var tools := equip.find_child("Tools", true, false) as Control
		var frame := equip.find_child("Frame", true, false) as Control
		rig.check(tools != null and tools.visible and frame != null
			and tools.global_position.y + tools.size.y <= frame.global_position.y + frame.size.y,
			"the owned tool row remains inside Equipment's 1280x720 frame")
		_key(KEY_LEFT)
		await rig.wait_frames(3)
		rig.check(panel.visible, "left from EQUIP wraps back to GARRISON")
		focus = rig.root.gui_get_focus_owner()
		rig.check(focus != null and scroll != null and scroll.scroll_vertical == 0,
			"tab wrapping preserves valid focus and the top scroll position")


func _catalogue_line(lines: Array[Dictionary], id: StringName) -> Dictionary:
	for line: Dictionary in lines:
		if StringName(line.get("id", &"")) == id:
			return line
	return {}


func _tools_outside_equipment_graphs(rig) -> bool:
	var players: Array = rig.get_nodes_in_group(&"player")
	var hero: Hero = players[0] as Hero if not players.is_empty() else null
	if hero == null or hero.combat == null:
		return false
	var combat_items: Dictionary = hero.combat._items
	for id: StringName in ToolDb.TOOL_IDS:
		if Game.wheel.has(id) or Run.bag.has(id) or Game.stash.has(id) \
				or Game.carry_ids().has(id) or Game.RIGHT_POOL.has(id) \
				or Game.LEFT_POOL.has(id) or combat_items.has(id):
			return false
		for set_data: Dictionary in Game.loadout:
			if set_data.values().has(id):
				return false
	return true


func _default_raid() -> Dictionary:
	return {
		"phase": GarrisonRaidState.PHASE_DORMANT,
		"scheduled_raid_day": 0,
		"integrity": GarrisonRaidState.INTEGRITY_MAX,
		"defense_built": false,
		"ledger_stolen": false,
		"attackers": [],
		"bolt_cooldown": GarrisonRaidState.BOLT_DEFENSE_INTERVAL,
		"advance_notice_pending": false,
		"advance_notice_delivered": false,
		"urgent_notice_pending": false,
		"urgent_notice_delivered": false,
	}


func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var label := root as Label
	if label != null and not label.text.strip_edges().is_empty():
		out.append(label.text)
	for child: Node in root.get_children():
		out.append_array(_all_text(child))
	return out


func _label_with_text(root: Node, wanted: String) -> Label:
	var label := root as Label
	if label != null and label.text.contains(wanted):
		return label
	for child: Node in root.get_children():
		var found := _label_with_text(child, wanted)
		if found != null:
			return found
	return null


func _first_tabs(root: Node) -> MenuPageTabs:
	var tabs := root as MenuPageTabs
	if tabs != null:
		return tabs
	for child: Node in root.get_children():
		var found := _first_tabs(child)
		if found != null:
			return found
	return null


func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
