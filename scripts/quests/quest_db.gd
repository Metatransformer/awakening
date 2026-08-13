class_name QuestDb
extends RefCounted
## The authored quest catalogue. Definitions are shared read-only; progress is Game's.

const KEEP_THE_HEARTH: StringName = &"keep_the_hearth"
const WEST_GATE_DEFENCE: StringName = &"west_gate_defence"

const FORGE_AXE: StringName = &"forge_axe"
const FELL_TREE: StringName = &"fell_tree"
const STORE_FIREWOOD: StringName = &"store_firewood"
const BUILD_BOLT_THROWER: StringName = &"build_bolt_thrower"

const TARGET_SMITH: StringName = &"smith"
const TARGET_OUTSKIRTS_TREE: StringName = &"outskirts_tree"
const TARGET_SUPPLY_BOX: StringName = &"supply_box"
const TARGET_BUILDER: StringName = &"builder"

static var _definitions: Array[QuestDef] = []


static func all() -> Array[QuestDef]:
	_ensure_definitions()
	var out: Array[QuestDef] = []
	out.append_array(_definitions)
	return out


static func get_def(id: StringName) -> QuestDef:
	_ensure_definitions()
	for definition: QuestDef in _definitions:
		if definition.id == id:
			return definition
	return null


static func journal_ids() -> Array[StringName]:
	_ensure_definitions()
	var ready: Array[StringName] = []
	var active: Array[StringName] = []
	var terminal: Array[StringName] = []
	for definition: QuestDef in _definitions:
		match Game.quest_status(definition.id):
			QuestState.Status.READY:
				ready.append(definition.id)
			QuestState.Status.ACTIVE:
				active.append(definition.id)
			QuestState.Status.COMPLETED, QuestState.Status.FAILED:
				terminal.append(definition.id)
			_:
				pass
	ready.append_array(active)
	ready.append_array(terminal)
	return ready


static func offered_for_npc(who: StringName) -> Array[StringName]:
	_ensure_definitions()
	var offered: Array[StringName] = []
	for definition: QuestDef in _definitions:
		if definition.giver_npc_id == who \
				and Game.quest_status(definition.id) == QuestState.Status.AVAILABLE:
			offered.append(definition.id)
	return offered


static func ready_for_npc(who: StringName) -> Array[StringName]:
	_ensure_definitions()
	var ready: Array[StringName] = []
	for definition: QuestDef in _definitions:
		if definition.turn_in_npc_id == who \
				and Game.quest_status(definition.id) == QuestState.Status.READY:
			ready.append(definition.id)
	return ready


static func marker_for_npc(who: StringName) -> String:
	if not ready_for_npc(who).is_empty():
		return "?"
	if not offered_for_npc(who).is_empty():
		return "!"
	return marker_for_target(who)


static func marker_for_target(target: StringName) -> String:
	_ensure_definitions()
	for definition: QuestDef in _definitions:
		if Game.quest_status(definition.id) != QuestState.Status.ACTIVE:
			continue
		var objective: Dictionary = Game.quest_active_objective(definition.id)
		if StringName(objective.get("target", &"")) == target:
			return "!"
	return ""


static func status_label(status: int) -> String:
	match status:
		QuestState.Status.AVAILABLE:
			return "Available"
		QuestState.Status.ACTIVE:
			return "Active"
		QuestState.Status.READY:
			return "Ready"
		QuestState.Status.COMPLETED:
			return "Complete"
		QuestState.Status.FAILED:
			return "Failed"
		_:
			return ""


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return
	var hearth_objectives: Array[Dictionary] = [
		QuestDef.objective(FORGE_AXE, "Forge a woodsman's axe", TARGET_SMITH, 1),
		QuestDef.objective(FELL_TREE, "Fell one tree", TARGET_OUTSKIRTS_TREE, 1),
		QuestDef.objective(STORE_FIREWOOD, "Store the firewood", TARGET_SUPPLY_BOX, 1),
	]
	_definitions.append(QuestDef.make(
		KEEP_THE_HEARTH,
		"KEEP THE HEARTH",
		"GARRISON",
		"Learn the timber duty that keeps the garrison hearth supplied.",
		&"elder",
		&"elder",
		PackedStringArray([
			"Good. Brannoc is expecting you at the forge.",
		]),
		PackedStringArray([
			"The hearth is supplied. Keep to the timber duty.",
		]),
		hearth_objectives))
	var defense_objectives: Array[Dictionary] = [
		QuestDef.objective(BUILD_BOLT_THROWER,
			"Build the west gate bolt-thrower", TARGET_BUILDER, 1),
	]
	_definitions.append(QuestDef.make(
		WEST_GATE_DEFENCE,
		"WEST GATE DEFENCE",
		"GARRISON",
		"Build the Builder's bolt-thrower before the raiders strike.",
		&"builder",
		&"builder",
		PackedStringArray([
			"Raiders are coming. Build the west gate bolt-thrower at my works board.",
		]),
		PackedStringArray([
			"The bolt-thrower stands ready at the west gate.",
		]),
		defense_objectives))
