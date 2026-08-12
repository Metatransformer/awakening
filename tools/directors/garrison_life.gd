extends RefCounted
## Deterministic behavior and visual proof for docs/GARRISON_LIFE.md.
##
## Run from the garrison:
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
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
	await _menu(rig)

	Menu.close()
	Clock.running = true
	print("GARRISON LIFE OK")


func _assignment_and_axe(rig) -> void:
	var briefing := StoryDb.told_flag(&"elder", &"briefing")
	var duty := StoryDb.told_flag(&"elder", &"timber_duty")
	var haul := StoryDb.told_flag(&"elder", &"first_haul")
	Game.flags.erase(duty)
	Game.flags.erase(haul)
	Game.items.erase(ShopDb.WOODSMAN_AXE_ID)
	Game.set_flag(briefing)
	Game.grant(StoryDb.SMITH_TOKEN)
	Game.gold_earned = maxi(Game.gold_earned, 300)

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

	var axe_line := _catalogue_line(ShopDb.lines(), ShopDb.WOODSMAN_AXE_ID)
	rig.check(not axe_line.is_empty(), "Brannoc has a Woodsman's Axe line")
	rig.check(int(axe_line.get("cost", -1)) == 60,
		"the Woodsman's Axe costs 60 gold")
	var parts: Dictionary = axe_line.get("parts", {})
	rig.check(int(parts.get(&"iron_scrap", 0)) == 3,
		"the Woodsman's Axe asks for three Iron Scrap")

	var yard := TimberYard.new()
	Game.restore_garrison({})
	yard.activate(null)
	rig.check(not Game.carrying_firewood and Game.timber_completed_day == 0,
		"an assigned duty without an axe cannot cut a bundle")
	yard.free()

	Game.gold = 100
	Run.bag[&"iron_scrap"] = 3
	Run.premium = 0
	var wheel_before: Array[StringName] = Game.wheel.duplicate()
	rig.check(ShopDb.can_buy(axe_line), "the seeded axe recipe is affordable")
	rig.check(ShopDb.buy(axe_line), "Brannoc crafts the Woodsman's Axe")
	rig.check(Game.gold == 40 and not Run.bag.has(&"iron_scrap"),
		"crafting consumes 60 gold and the returned bag's three Iron Scrap")
	rig.check(Game.has(ShopDb.WOODSMAN_AXE_ID),
		"the Woodsman's Axe is permanent equipment")
	rig.check(Game.wheel == wheel_before and not Game.wheel.has(ShopDb.WOODSMAN_AXE_ID),
		"the tool never enters the hand wheel")
	var tool: Dictionary = ToolDb.definition(ShopDb.WOODSMAN_AXE_ID)
	rig.check(bool(tool.get("owned", false)), "Equipment's tool manifest sees the axe")
	var completed := _catalogue_line(ShopDb.lines(), ShopDb.WOODSMAN_AXE_ID)
	rig.check(int(completed.get("cost", -1)) == 0
		and ShopDb.remaining(ShopDb.WOODSMAN_AXE_ID) == 0,
		"the completed one-rung axe line cannot be crafted twice")


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
	rig.check(outskirts.timber_yard != null, "the exterior route contains the Timber Yard")
	rig.check(outskirts.port(&"timber_yard").origin != Vector3.ZERO,
		"the Timber Yard has an authored exterior port")

	var cam := Camera3D.new()
	cam.fov = 52.0
	outskirts.add_child(cam)
	cam.global_position = Vector3(-3.8, 9.4, 22.5)
	cam.look_at(outskirts.timber_yard.global_position + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	cam.make_current()
	await rig.wait_frames(6)
	await rig.capture("life_00_timber.png")

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
		"raid": _default_raid(),
	}, "an older save's absent garrison payload defaults empty and cold")
	var saved := {
		"firewood_stock": 2,
		"carrying_firewood": true,
		"timber_completed_day": 4,
		"warmth_active": true,
		"last_bonfire_day": 3,
		"raid": _default_raid(),
	}
	Game.restore_garrison(saved)
	rig.check(Game.garrison_snapshot() == saved, "all garrison state round-trips")
	rig.check(Saves.VERSION == 12, "the additive save contract is version 12")

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
	Game.restore_garrison({"firewood_stock": 2})
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
	rig.check(Game.warmth_active and Game.firewood_stock == 1
		and Game.last_bonfire_day == 2,
		"20:00 consumes one bundle and activates Warmth")
	Game.resolve_bonfire(2)
	rig.check(Game.firewood_stock == 1,
		"the same campaign day's bonfire cannot consume twice")

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


func _menu(rig) -> void:
	Game.restore_garrison({
		"firewood_stock": 2,
		"timber_completed_day": 6,
		"warmth_active": true,
		"last_bonfire_day": 5,
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
	for phrase: String in ["Day", "Bonfire", "Garrison Warmth", "KEEP THE HEARTH",
			"ROSTER", "DONATED RELIC EFFECTS", "ELDER IMPROVEMENTS"]:
		rig.check(page_text.contains(phrase), "the Garrison page reports %s" % phrase)
	var focus: Control = rig.root.gui_get_focus_owner()
	rig.check(focus != null and focus.name == &"Back",
		"opening GARRISON places focus on Back")

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

	await rig.capture("life_03_garrison_menu.png")


func _catalogue_line(lines: Array[Dictionary], id: StringName) -> Dictionary:
	for line: Dictionary in lines:
		if StringName(line.get("id", &"")) == id:
			return line
	return {}


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
