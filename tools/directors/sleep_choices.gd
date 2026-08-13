extends RefCounted
## The personal bed's complete player-facing sleep contract in the real garrison.
##
## It proves the Prompt/physics seam, the quilt and mote focus response, the
## exact nightfall/morning dialogue, the paused analog-clock transition, both
## destinations, successful recovery/autosave, and the raid interruption target.
## Every save-slot byte and every piece of campaign state changed here is put
## back before the director returns.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/sleep_choices.gd \
##     --out=/tmp/sleep-choices/sleep.png --warmup=60

const YOUR_BED_SHADER_PATH := "res://assets/shaders/your_bed.gdshader"
const NIGHTFALL_LABEL := "Sleep until nightfall"
const MORNING_LABEL := "Sleep until morning"
static var EXPECTED_LABELS := PackedStringArray([NIGHTFALL_LABEL, MORNING_LABEL])

var _save_backup: Dictionary = {}
var _active_slot_before: int = -1
var _clock_before: Dictionary = {}
var _garrison_before: Dictionary = {}
var _upgrades_before: Dictionary = {}
var _quarters_before: int = 0
var _temporary_overhealth_before: int = 0
var _stamina_before: float = 0.0
var _run_in_dungeon_before: bool = false
var _deliberate_rest_before: bool = false
var _prompt_blocked_before: bool = false
var _paused_before: bool = false
var _hero_before: Transform3D = Transform3D.IDENTITY
var _had_hero: bool = false


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the real garrison courtyard"):
		return
	if not rig.check(garrison.house != null and garrison.house.bed != null,
			"the real garrison contains the hero's house bed"):
		return
	if not rig.check(not Flow.busy and not rig.paused and not Prompt.blocked,
			"Flow and the garrison are settled before sleep proof begins"):
		return
	if not _backup_state(rig):
		return

	var rested_slots: Array[int] = []
	var rested_listener: Callable = func(slot: int) -> void:
		rested_slots.append(slot)
	Bus.rested.connect(rested_listener)

	await _exercise(rig, garrison, rested_slots)
	await _settle_owned_ui(rig)

	if Bus.rested.is_connected(rested_listener):
		Bus.rested.disconnect(rested_listener)
	_restore_state(rig)
	print("SLEEP CHOICES OK")


func _exercise(rig, garrison: Garrison, rested_slots: Array[int]) -> void:
	var bed: Bed = garrison.house.bed
	Run.in_dungeon = false
	Game.upgrades[ElderUpgradeDb.BED_ID] = 2
	Game.upgrades.erase(ElderUpgradeDb.REVEILLE_ID)
	Game.health_points = K.HEALTH_POINT
	Game.set_temporary_overhealth(0)
	Game.stamina = 0.0
	Bus.player_health_changed.emit(Game.health_points, Game.max_health_points)
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	for slot in Saves.SLOTS:
		Saves.erase(slot)
	Saves.active_slot = -1

	var quilt := _find_quilt_material(bed)
	var motes := _find_motes(bed)
	rig.check(quilt != null, "the bed quilt uses a ShaderMaterial")
	rig.check(quilt != null and quilt.shader != null
		and quilt.shader.resource_path == YOUR_BED_SHADER_PATH,
		"the quilt uses the authored your_bed shader")
	rig.check(motes != null and motes.emitting,
		"warm bed motes exist and are emitting")
	if quilt == null or motes == null:
		return

	Prompt.drop_focus()
	await rig.wait_frames(2)
	var idle_focus_value: Variant = quilt.get_shader_parameter(&"focus")
	var idle_focus := float(idle_focus_value) if idle_focus_value != null else 0.0
	var idle_motes := motes.amount_ratio
	var prompt_lines: Array[String] = []
	var prompt_listener: Callable = func(text: String) -> void:
		if not text.is_empty():
			prompt_lines.append(text)
	Bus.prompt_changed.connect(prompt_listener)

	if not await _approach(rig, bed):
		if Bus.prompt_changed.is_connected(prompt_listener):
			Bus.prompt_changed.disconnect(prompt_listener)
		return
	await rig.wait_frames(18)
	if Bus.prompt_changed.is_connected(prompt_listener):
		Bus.prompt_changed.disconnect(prompt_listener)
	var focused_prompt := prompt_lines[-1] if not prompt_lines.is_empty() else ""
	rig.check(focused_prompt.contains("YOUR BED"),
		"the live Prompt identifies YOUR BED (%s)" % focused_prompt)
	var focused_focus_value: Variant = quilt.get_shader_parameter(&"focus")
	rig.check(focused_focus_value != null,
		"the bed focus writes the quilt shader's focus uniform")
	var focused_focus := float(focused_focus_value) \
		if focused_focus_value != null else idle_focus
	var focused_motes := motes.amount_ratio
	rig.check(focused_focus > idle_focus,
		"focus raises the quilt shader response (%.2f -> %.2f)"
		% [idle_focus, focused_focus])
	rig.check(focused_motes > idle_motes,
		"focus raises the warm-mote density (%.2f -> %.2f)"
		% [idle_motes, focused_motes])
	await rig.capture("sleep_00_your_bed.png")

	Clock.restore({"day": 3, "hour": 8.0, "running": false})
	var night_box := await _open_choices(rig, bed)
	if night_box == null:
		return
	rig.check(night_box.choice_labels() == EXPECTED_LABELS,
		"the bed offers exactly nightfall then morning (%s)"
		% [night_box.choice_labels()])
	await rig.capture("sleep_01_choices.png")

	Clock.running = true
	if not rig.check(await rig.talk(NIGHTFALL_LABEL),
			"real dialogue presses select Sleep until nightfall"):
		return
	var card_started: bool = await rig.until(
		func() -> bool: return _sleep_clock_card(rig) != null, 2.0)
	if not rig.check(card_started, "nightfall sleep opens the live SleepClockCard"):
		return
	var card: Node = _sleep_clock_card(rig)
	if not rig.check(card != null, "the live sleep clock remains inspectable"):
		return
	var target_absolute := Clock.absolute_hours(3, 20.0)
	rig.check(Flow.busy and Prompt.blocked and rig.paused,
		"Flow owns input and pauses the tree during the sleep clock")
	rig.check(is_equal_approx(float(card.get("to_absolute_hour")), target_absolute),
		"the analog clock targets exactly Day 3 20:00")

	var reached_early: bool = await rig.until(func() -> bool:
		return is_instance_valid(card) \
			and float(card.get("presentation_progress")) >= 0.18, 1.0)
	if not rig.check(reached_early, "sleep clock reaches its early visible point"):
		return
	var early_progress := float(card.get("presentation_progress"))
	var early_hour := float(card.call("current_absolute_hour"))
	rig.check(early_progress >= 0.15 and early_progress <= 0.25,
		"early capture is at 15-25%% progress (%.3f)" % early_progress)
	rig.check(early_hour > Clock.absolute_hours(3, 8.0)
		and early_hour < target_absolute,
		"the early hand has moved toward Day 3 20:00 (%.3f)" % early_hour)
	await rig.capture("sleep_02_clock_early.png")

	var reached_late: bool = await rig.until(func() -> bool:
		return is_instance_valid(card) \
			and float(card.get("presentation_progress")) >= 0.68, 1.5)
	if not rig.check(reached_late, "sleep clock reaches its late visible point"):
		return
	var late_progress := float(card.get("presentation_progress"))
	var late_hour := float(card.call("current_absolute_hour"))
	rig.check(late_progress >= 0.65 and late_progress <= 0.75,
		"late capture is at 65-75%% progress (%.3f)" % late_progress)
	rig.check(late_hour > early_hour and late_hour < target_absolute,
		"the late hand advances toward the same exact target (%.3f -> %.3f)"
		% [early_hour, late_hour])
	rig.check(is_equal_approx(late_hour, lerpf(
		float(card.get("from_absolute_hour")), target_absolute, late_progress)),
		"current_absolute_hour follows the public linear presentation progress")
	await rig.capture("sleep_03_clock_late.png")

	if not rig.check(await _wait_until_settled(rig, 14.0),
			"nightfall sleep and its crossed civil title settle"):
		return
	rig.check(Clock.day == 3 and is_equal_approx(Clock.hour, 20.0),
		"nightfall sleep lands on Day 3 at exactly 20:00")
	rig.check(Game.health_points == Game.max_health_points,
		"successful sleep fully restores real health")
	rig.check(is_equal_approx(Game.stamina, Game.max_stamina),
		"successful sleep fully restores stamina")
	rig.check(Game.temporary_overhealth == 2 * K.HEALTH_POINT,
		"Better Bed rank two grants two temporary HP")
	rig.check(Saves.active_slot == 0 and Saves.has_save(0)
		and rested_slots == [0],
		"successful sleep autosaves slot one and emits rested with that slot")

	Clock.restore({"day": 3, "hour": 21.0, "running": false})
	var morning: Dictionary[StringName, Variant] = \
		Clock.effective_sleep_destination(WorldClock.SLEEP_DESTINATION_MORNING)
	rig.check(int(morning.get(&"day", 0)) == 4 \
		and is_equal_approx(float(morning.get(&"hour", -1.0)), 7.0) \
		and not bool(morning.get(&"interrupted", true)),
		"the offered morning destination means next day at 07:00")
	Game.upgrades[ElderUpgradeDb.REVEILLE_ID] = 1
	morning = Clock.effective_sleep_destination(
		WorldClock.SLEEP_DESTINATION_MORNING)
	rig.check(int(morning.get(&"day", 0)) == 4 \
		and is_equal_approx(float(morning.get(&"hour", -1.0)), 6.0),
		"Early Reveille changes the offered morning destination to 06:00")
	Game.upgrades.erase(ElderUpgradeDb.REVEILLE_ID)

	_prove_raid_interruption_target(rig)


func _open_choices(rig, bed: Bed) -> Node:
	if not rig.check(Prompt.focus == bed,
			"the real bed owns Prompt before the held interaction"):
		return null
	await rig.hold_seconds(["interact"], 0.9)
	var opened: bool = await rig.until(func() -> bool: return rig.dialogue() != null)
	if not rig.check(opened, "holding real interact opens the bed DialogueBox"):
		return null
	var box: Node = rig.dialogue()
	for i in 64:
		if not is_instance_valid(box) or box.is_choosing():
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	if not rig.check(is_instance_valid(box) and box.is_choosing(),
			"real interact presses advance the bed question to its choices"):
		return null
	return box


func _approach(rig, bed: Bed) -> bool:
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Hero
	if not rig.check(hero != null, "the real garrison hero exists"):
		return false
	hero.global_position = bed.global_position + Vector3(1.2, 0.05, 0.0)
	var to_bed := K.flat(bed.global_position - hero.global_position)
	if to_bed != Vector3.ZERO:
		hero.facing_yaw = atan2(to_bed.x, to_bed.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	var focused: bool = await rig.until(func() -> bool: return Prompt.focus == bed)
	rig.check(focused, "the bed takes Prompt through its real physics trigger")
	if focused:
		await rig.wait_physics_frames(2)
	return focused


func _prove_raid_interruption_target(rig) -> void:
	var staged_garrison: Dictionary = _garrison_before.duplicate(true)
	staged_garrison["raid"] = {
		"phase": GarrisonRaidState.PHASE_WARNED,
		"scheduled_raid_day": 3,
		"integrity": GarrisonRaidState.INTEGRITY_MAX,
		"defense_built": false,
		"ledger_stolen": false,
		"attackers": [],
		"advance_notice_pending": false,
		"advance_notice_delivered": true,
		"urgent_notice_pending": false,
		"urgent_notice_delivered": false,
	}
	Game.restore_garrison(staged_garrison)
	Clock.restore({"day": 3, "hour": 21.0, "running": false})
	var destination: Dictionary[StringName, Variant] = \
		Clock.effective_sleep_destination(WorldClock.SLEEP_DESTINATION_MORNING)
	rig.check(bool(destination.get(&"interrupted", false))
		and int(destination.get(&"day", 0)) == 3
		and is_equal_approx(float(destination.get(&"hour", -1.0)), 23.0),
		"a warned Day 3 raid interrupts morning-bound sleep at Day 3 23:00")
	rig.check(Game.raid_phase() == GarrisonRaidState.PHASE_WARNED,
		"querying the interruption target does not start the raid encounter")
	Game.restore_garrison(_garrison_before)


func _sleep_clock_card(rig) -> Node:
	for node in _all(rig.root):
		if node.name == &"SleepClockCard" \
				and node.has_method(&"current_absolute_hour") \
				and _has_property(node, &"presentation_progress"):
			return node
	return null


func _find_quilt_material(bed: Bed) -> ShaderMaterial:
	for node in _all(bed):
		if not (node is MeshInstance3D):
			continue
		var material := (node as MeshInstance3D).material_override
		if material is ShaderMaterial and (material as ShaderMaterial).shader != null \
				and (material as ShaderMaterial).shader.resource_path \
				== YOUR_BED_SHADER_PATH:
			return material as ShaderMaterial
	return null


func _find_motes(bed: Bed) -> GPUParticles3D:
	for node in _all(bed):
		if node is GPUParticles3D:
			return node as GPUParticles3D
	return null


func _all(root_node: Node) -> Array[Node]:
	var found: Array[Node] = [root_node]
	for child: Node in root_node.get_children():
		found.append_array(_all(child))
	return found


func _has_property(node: Node, property_name: StringName) -> bool:
	for property: Dictionary in node.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


func _wait_until_settled(rig, seconds: float) -> bool:
	return await rig.until(func() -> bool:
		return not Flow.busy and not rig.paused and not Prompt.blocked \
			and _sleep_clock_card(rig) == null, seconds)


func _settle_owned_ui(rig) -> void:
	if rig.dialogue() != null:
		await rig.tap(["ui_cancel"])
		await rig.until(func() -> bool: return rig.dialogue() == null, 2.0)
	if Flow.busy or rig.paused or _sleep_clock_card(rig) != null:
		rig.check(await _wait_until_settled(rig, 16.0),
			"sleep UI settles before state restoration")


func _backup_state(rig) -> bool:
	_clock_before = Clock.snapshot().duplicate(true)
	_garrison_before = Game.garrison_snapshot().duplicate(true)
	_upgrades_before = Game.upgrades.duplicate(true)
	_quarters_before = Game.health_points
	_temporary_overhealth_before = Game.temporary_overhealth
	_stamina_before = Game.stamina
	_run_in_dungeon_before = Run.in_dungeon
	_deliberate_rest_before = Flow.deliberate_rest
	_prompt_blocked_before = Prompt.blocked
	_paused_before = rig.paused
	_active_slot_before = Saves.active_slot
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Hero
	_had_hero = hero != null
	if _had_hero:
		_hero_before = hero.global_transform

	for slot in Saves.SLOTS:
		var exists := FileAccess.file_exists(Saves.slot_path(slot))
		var bytes := PackedByteArray()
		if exists:
			var file := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
			if file == null:
				rig.fail("could not open real save slot %d for byte backup" % (slot + 1))
				return false
			bytes = file.get_buffer(file.get_length())
			file.close()
		_save_backup[slot] = {"exists": exists, "bytes": bytes}
	return true


func _restore_state(rig) -> void:
	Clock.restore(_clock_before)
	Game.restore_garrison(_garrison_before)
	Game.upgrades = _upgrades_before.duplicate(true)
	Game.health_points = _quarters_before
	Game.set_temporary_overhealth(_temporary_overhealth_before)
	Game.stamina = _stamina_before
	Bus.player_health_changed.emit(Game.health_points, Game.max_health_points)
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	Run.in_dungeon = _run_in_dungeon_before
	Flow.deliberate_rest = _deliberate_rest_before
	Prompt.blocked = _prompt_blocked_before
	rig.paused = _paused_before
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Hero
	if _had_hero and hero != null:
		hero.global_transform = _hero_before

	for slot in Saves.SLOTS:
		var saved: Dictionary = _save_backup.get(slot, {})
		if not bool(saved.get("exists", false)):
			Saves.erase(slot)
			rig.check(not FileAccess.file_exists(Saves.slot_path(slot)),
				"absent real save slot %d is restored as absent" % (slot + 1))
			continue
		var file := FileAccess.open(Saves.slot_path(slot), FileAccess.WRITE)
		if file == null:
			rig.fail("could not restore real save slot %d" % (slot + 1))
			continue
		var bytes: PackedByteArray = saved.get("bytes", PackedByteArray())
		file.store_buffer(bytes)
		file.close()
		rig.check(_read_slot_bytes(slot) == bytes,
			"real save slot %d bytes are restored exactly" % (slot + 1))
	Saves.active_slot = _active_slot_before


func _read_slot_bytes(slot: int) -> PackedByteArray:
	var file := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes
