extends RefCounted
## Quest authority, real action hooks, journal pixels, and world/dialogue markers.
##
##   timeout 240 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/quest_journal.gd \
##     --out=/tmp/quest-journal/quest.png --size=1280x720 --warmup=90

var _camera: Camera3D


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the real garrison courtyard"):
		return
	Clock.running = false
	Menu.close()

	_prove_state_machine(rig)
	await _prove_hearth_quest(rig, garrison)
	await _prove_builder_quest(rig, garrison)

	Clock.running = true
	print("QUEST JOURNAL OK")


func _prove_state_machine(rig) -> void:
	var definition: QuestDef = QuestDb.get_def(QuestDb.WEST_GATE_DEFENCE)
	var state := QuestState.new()
	rig.check(definition != null and not state.accept(definition),
		"a locked quest cannot be accepted without an offer")
	rig.check(state.offer(definition)
		and state.status(definition.id) == QuestState.Status.AVAILABLE,
		"an authored quest enters AVAILABLE exactly once")
	rig.check(state.accept(definition)
		and state.status(definition.id) == QuestState.Status.ACTIVE,
		"acceptance seeds the authored objective list")
	rig.check(state.complete_objective(definition, QuestDb.BUILD_BOLT_THROWER)
		and state.status(definition.id) == QuestState.Status.READY,
		"the last objective stops at READY instead of silently turning itself in")

	var encoded := JSON.stringify(state.snapshot())
	var decoded: Variant = JSON.parse_string(encoded)
	var restored := QuestState.new()
	restored.restore(decoded, QuestDb.all())
	rig.check(restored.status(definition.id) == QuestState.Status.READY
		and restored.progress(definition.id, QuestDb.BUILD_BOLT_THROWER) == 1,
		"READY status and exact progress survive a JSON round-trip")
	rig.check(restored.turn_in(definition)
		and restored.status(definition.id) == QuestState.Status.COMPLETED,
		"only an explicit turn-in makes a ready quest complete")
	rig.check(Saves.VERSION == 21,
		"the additive campaign quest payload is save version 21")


func _prove_hearth_quest(rig, garrison: Garrison) -> void:
	Game.items.erase(StoryDb.SMITH_TOKEN)
	Game.items.erase(ToolDb.WOODSMAN_AXE_ID)
	Game.tool_durabilities.erase(ToolDb.WOODSMAN_AXE_ID)
	Game.flags.erase(StoryDb.told_flag(&"elder", &"briefing"))
	Game.flags.erase(StoryDb.told_flag(&"elder", &"timber_duty"))
	Game.restore_quests({})
	Game.restore_garrison({})
	Run.reset()

	Game.set_flag(StoryDb.told_flag(&"elder", &"briefing"))
	Game.grant(StoryDb.SMITH_TOKEN)
	await rig.wait_frames(3)
	rig.check(Game.quest_status(QuestDb.KEEP_THE_HEARTH)
		== QuestState.Status.AVAILABLE
		and QuestDb.marker_for_npc(&"elder") == "!"
		and garrison.keeper.attention_marker.visible
		and garrison.keeper.attention_marker.text == "!",
		"meeting the timber prerequisites puts ! over its quest giver")
	Game.set_flag(StoryDb.told_flag(&"elder", &"timber_duty"))
	rig.check(Game.quest_accept(QuestDb.KEEP_THE_HEARTH)
		and QuestDb.marker_for_npc(&"smith") == "!",
		"accepting Keep the Hearth moves ! to Brannoc, its current target")

	Game.gold = 100
	Run.bag[&"iron_scrap"] = 3
	var axe_line := _line(ShopDb.lines(), ToolDb.WOODSMAN_AXE_ID)
	rig.check(not axe_line.is_empty() and ShopDb.buy(axe_line)
		and Game.quest_progress(QuestDb.KEEP_THE_HEARTH, QuestDb.FORGE_AXE) == 1
		and QuestDb.marker_for_target(QuestDb.TARGET_OUTSKIRTS_TREE) == "!",
		"crafting the axe advances the quest to its grove target")

	var tree := HarvestTree.new()
	tree.name = &"QuestProofTree"
	garrison.add_child(tree)
	await rig.wait_frames(3)
	rig.check(tree.attention_marker.visible and tree.attention_marker.text == "!",
		"an active harvest target owns a live ! marker")
	tree.queue_free()

	Clock.restore({"day": 1, "hour": 10.0, "running": false})
	rig.check(Game.chop_firewood(Clock.day, Clock.garrison_phase())
		and Game.quest_progress(QuestDb.KEEP_THE_HEARTH, QuestDb.FELL_TREE) == 1,
		"the real daytime tree action advances the second objective")
	await rig.wait_frames(3)
	rig.check(garrison.supply_box.attention_marker.visible
		and garrison.supply_box.attention_marker.text == "!",
		"the supply box receives ! when it becomes the current target")
	var receipt := Game.deposit_supplies()
	rig.check(int(receipt.get(&"firewood_units", 0)) == 1
		and Game.quest_status(QuestDb.KEEP_THE_HEARTH) == QuestState.Status.READY,
		"depositing the real Firewood cargo leaves the quest ready for turn-in")
	await rig.wait_frames(3)
	rig.check(QuestDb.marker_for_npc(&"elder") == "?"
		and garrison.keeper.attention_marker.visible
		and garrison.keeper.attention_marker.text == "?",
		"a ready quest replaces the elder's marker with ?")

	var payload: Dictionary = Game.quest_snapshot()
	var decoded: Variant = JSON.parse_string(JSON.stringify(payload))
	Game.restore_quests(decoded)
	rig.check(Game.quest_status(QuestDb.KEEP_THE_HEARTH) == QuestState.Status.READY,
		"Game restores a ready quest without auto-turning it in")
	await _show_journal(rig, "quest_00_hearth_ready.png")
	await _show_npc_marker(rig, garrison.keeper, "quest_01_elder_turn_in_marker.png")

	await _open_choices(rig, garrison.keeper)
	var box: Node = rig.dialogue()
	var labels: PackedStringArray = box.choice_labels() if box != null \
		else PackedStringArray()
	rig.check(not labels.is_empty() and labels[0] == "KEEP THE HEARTH",
		"the elder's first dialogue row is the ready quest turn-in")
	await rig.capture("quest_02_elder_turn_in_dialogue.png")
	await rig.tap(["ui_accept"])
	await rig.wait_frames(3)
	rig.check(Game.quest_status(QuestDb.KEEP_THE_HEARTH)
		== QuestState.Status.COMPLETED,
		"choosing the NPC row explicitly completes Keep the Hearth")
	await _close_dialogue(rig)


func _prove_builder_quest(rig, garrison: Garrison) -> void:
	Game.restore_garrison({})
	Game.set_flag(RelicDb.flag_donated(RelicDb.TALLY_LEDGER_ID))
	rig.check(Game.raid_arm(1, 8.0),
		"arming the authored raid offers West Gate Defence")
	await rig.wait_frames(6)
	var builder: Npc = garrison.builder
	if not rig.check(builder != null, "the donated Ledger brings the Builder into the yard"):
		return
	# The authored workshop is deliberately dense with posts and hanging works.
	# Use the same live NPC at her bonfire port so the proof frame can actually
	# show the person and the mark it is judging.
	builder.global_transform = garrison.compound.global_transform \
		* garrison.compound.port(&"builder_bonfire")
	await rig.wait_frames(3)
	rig.check(Game.quest_status(QuestDb.WEST_GATE_DEFENCE)
		== QuestState.Status.AVAILABLE
		and builder.attention_marker.visible and builder.attention_marker.text == "!",
		"the available defence quest puts ! over its giver")
	await _show_npc_marker(rig, builder, "quest_03_builder_offer_marker.png")

	await _open_choices(rig, builder)
	var box: Node = rig.dialogue()
	var labels: PackedStringArray = box.choice_labels() if box != null \
		else PackedStringArray()
	rig.check(not labels.is_empty() and labels[0] == "WEST GATE DEFENCE",
		"the Builder offers the quest before the works-board service")
	await rig.capture("quest_04_builder_offer_dialogue.png")
	await rig.tap(["ui_accept"])
	await rig.wait_frames(3)
	rig.check(Game.quest_status(QuestDb.WEST_GATE_DEFENCE)
		== QuestState.Status.ACTIVE
		and QuestDb.marker_for_target(QuestDb.TARGET_BUILDER) == "!",
		"accepting the Builder's row makes the works target active")
	await _close_dialogue(rig)

	Game.gold = BuilderDb.COST
	Game.components.clear()
	for part_id: StringName in BuilderDb.PARTS:
		Game.add_component(part_id, int(BuilderDb.PARTS[part_id]))
	var defense_line: Dictionary = BuilderDb.lines()[0]
	rig.check(BuilderDb.buy(defense_line)
		and Game.quest_status(QuestDb.WEST_GATE_DEFENCE) == QuestState.Status.READY,
		"the real works-board purchase advances the defence quest to READY")
	await rig.wait_frames(4)
	rig.check(builder.attention_marker.visible and builder.attention_marker.text == "?",
		"the Builder switches from target ! to turn-in ?")
	await _show_npc_marker(rig, builder, "quest_05_builder_turn_in_marker.png")
	await _show_journal(rig, "quest_06_two_row_journal.png")

	await _open_choices(rig, builder)
	box = rig.dialogue()
	labels = box.choice_labels() if box != null else PackedStringArray()
	rig.check(not labels.is_empty() and labels[0] == "WEST GATE DEFENCE",
		"the ready defence quest is the Builder's first turn-in row")
	await rig.capture("quest_07_builder_turn_in_dialogue.png")
	await rig.tap(["ui_accept"])
	await rig.wait_frames(3)
	rig.check(Game.quest_status(QuestDb.WEST_GATE_DEFENCE)
		== QuestState.Status.COMPLETED and not builder.attention_marker.visible,
		"turning in the defence quest clears its world marker")
	await _close_dialogue(rig)


func _show_journal(rig, shot: String) -> void:
	if Menu.is_open:
		Menu.close()
	Menu.open()
	await rig.wait_frames(5)
	Menu.call(&"_push", {"screen": PauseMenu.Screen.QUESTS})
	await rig.wait_frames(8)
	var panel := Menu.get_node("Root/Screens/QuestScreen") as MenuQuestPanel
	rig.check(panel.visible and not panel.tab_row().is_empty(),
		"the Quests page opens inside the shared pause-menu ring")
	await rig.capture(shot)
	Menu.close()
	await rig.wait_frames(4)


func _show_npc_marker(rig, npc: Npc, shot: String) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 50.0
		rig.scene().add_child(_camera)
	var forward := npc.global_transform.basis.z.normalized()
	var right := npc.global_transform.basis.x.normalized()
	_camera.global_position = npc.global_position + forward * 3.4 + right * 1.8 \
		+ Vector3.UP * 2.25
	_camera.look_at(npc.global_position + Vector3.UP * 1.45, Vector3.UP)
	_camera.make_current()
	await rig.wait_frames(5)
	await rig.capture(shot)


func _open_choices(rig, npc: Npc) -> void:
	await _close_dialogue(rig)
	npc.activate(null)
	var opened: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 3.0)
	if not rig.check(opened, "%s opens a dialogue box" % npc.name):
		return
	var box: Node = rig.dialogue()
	for _i in 4:
		if box == null or box.is_choosing():
			break
		await rig.tap(["interact"])
		await rig.wait_frames(3)
	rig.check(box != null and box.is_choosing(),
		"%s reaches its dialogue choices" % npc.name)


func _close_dialogue(rig) -> void:
	for _i in 5:
		if rig.dialogue() == null:
			return
		await rig.tap(["ui_cancel"])
		await rig.wait_frames(2)


func _line(lines: Array[Dictionary], id: StringName) -> Dictionary:
	for line: Dictionary in lines:
		if StringName(line.get("id", &"")) == id:
			return line
	return {}
