class_name QuestState
extends RefCounted
## Mutable quest progress keyed only by stable catalogue ids.

signal changed(quest_id: StringName)

enum Status { LOCKED, AVAILABLE, ACTIVE, READY, COMPLETED, FAILED }

var _entries: Dictionary[StringName, Dictionary] = {}


func offer(definition: QuestDef) -> bool:
	if definition == null or definition.id == &"":
		return false
	var current: int = status(definition.id)
	if current != Status.LOCKED:
		return false
	_entries[definition.id] = {
		"status": Status.AVAILABLE,
		"objectives": {},
	}
	changed.emit(definition.id)
	return true


func accept(definition: QuestDef) -> bool:
	if definition == null or definition.id == &"":
		return false
	var current: int = status(definition.id)
	if current != Status.AVAILABLE:
		return false
	_entries[definition.id] = {
		"status": Status.ACTIVE,
		"objectives": _seed_objectives(definition),
	}
	changed.emit(definition.id)
	return true


func advance(definition: QuestDef, objective_id: StringName,
		amount: int = 1) -> bool:
	if definition == null or amount <= 0 or status(definition.id) != Status.ACTIVE:
		return false
	var authored: Dictionary = definition.objective_by_id(objective_id)
	if authored.is_empty():
		return false
	var quest_entry: Dictionary = _entries[definition.id]
	var objective_progress: Dictionary = quest_entry.get("objectives", {})
	var goal: int = int(authored.get("goal", 0))
	var before: int = clampi(int(objective_progress.get(objective_id, 0)), 0, goal)
	var after: int = mini(goal, before + amount)
	if after <= before:
		return false
	objective_progress[objective_id] = after
	quest_entry["objectives"] = objective_progress
	if _all_complete(definition, objective_progress):
		quest_entry["status"] = Status.READY
	_entries[definition.id] = quest_entry
	changed.emit(definition.id)
	return true


func complete_objective(definition: QuestDef, objective_id: StringName) -> bool:
	if definition == null:
		return false
	var authored: Dictionary = definition.objective_by_id(objective_id)
	if authored.is_empty():
		return false
	var goal: int = int(authored.get("goal", 0))
	return advance(definition, objective_id,
		goal - progress(definition.id, objective_id))


func turn_in(definition: QuestDef) -> bool:
	if definition == null or status(definition.id) != Status.READY:
		return false
	_entries[definition.id]["status"] = Status.COMPLETED
	changed.emit(definition.id)
	return true


func fail(definition: QuestDef) -> bool:
	if definition == null:
		return false
	var current: int = status(definition.id)
	if current != Status.AVAILABLE and current != Status.ACTIVE \
			and current != Status.READY:
		return false
	_entries[definition.id]["status"] = Status.FAILED
	changed.emit(definition.id)
	return true


func status(quest_id: StringName) -> int:
	if not _entries.has(quest_id):
		return Status.LOCKED
	return int(_entries[quest_id].get("status", Status.LOCKED))


func entry(quest_id: StringName) -> Dictionary:
	if not _entries.has(quest_id):
		return {}
	return _entries[quest_id].duplicate(true)


func progress(quest_id: StringName, objective_id: StringName) -> int:
	if not _entries.has(quest_id):
		return 0
	var objective_progress: Dictionary = _entries[quest_id].get("objectives", {})
	return maxi(0, int(objective_progress.get(objective_id, 0)))


func active_objective(definition: QuestDef) -> Dictionary:
	if definition == null or status(definition.id) != Status.ACTIVE:
		return {}
	for authored: Dictionary in definition.objectives:
		var objective_id := StringName(authored.get("id", &""))
		if progress(definition.id, objective_id) < int(authored.get("goal", 0)):
			return authored.duplicate(true)
	return {}


func snapshot() -> Dictionary:
	var saved: Dictionary = {}
	for quest_id: StringName in _entries:
		var quest_entry: Dictionary = _entries[quest_id]
		var saved_progress: Dictionary = {}
		var objective_progress: Dictionary = quest_entry.get("objectives", {})
		for objective_id: StringName in objective_progress:
			saved_progress[String(objective_id)] = int(objective_progress[objective_id])
		saved[String(quest_id)] = {
			"status": int(quest_entry.get("status", Status.LOCKED)),
			"objectives": saved_progress,
		}
	return saved


func restore(raw: Variant, definitions: Array[QuestDef]) -> void:
	var previous: Dictionary[StringName, Dictionary] = _entries.duplicate(true)
	var restored: Dictionary[StringName, Dictionary] = {}
	var definitions_by_id: Dictionary[StringName, QuestDef] = {}
	for definition: QuestDef in definitions:
		if definition != null and definition.id != &"":
			definitions_by_id[definition.id] = definition
	if raw is Dictionary:
		for raw_quest_id: Variant in (raw as Dictionary):
			if raw_quest_id is not String and raw_quest_id is not StringName:
				continue
			var quest_id := StringName(raw_quest_id)
			if not definitions_by_id.has(quest_id):
				continue
			var raw_entry: Variant = (raw as Dictionary)[raw_quest_id]
			if raw_entry is not Dictionary:
				continue
			var raw_status: Variant = (raw_entry as Dictionary).get(
				"status", Status.LOCKED)
			if raw_status is not int and raw_status is not float:
				continue
			var restored_status := int(raw_status)
			if restored_status < Status.LOCKED or restored_status > Status.FAILED:
				continue
			if restored_status == Status.LOCKED:
				continue
			var definition: QuestDef = definitions_by_id[quest_id]
			var restored_progress: Dictionary[StringName, int] = {}
			if restored_status != Status.AVAILABLE:
				restored_progress = _restore_progress(
					(raw_entry as Dictionary).get("objectives", {}), definition)
			if restored_status == Status.ACTIVE or restored_status == Status.READY:
				restored_status = Status.READY \
					if _all_complete(definition, restored_progress) else Status.ACTIVE
			restored[quest_id] = {
				"status": restored_status,
				"objectives": restored_progress,
			}
	_entries = restored
	_emit_restore_changes(previous, definitions)


func reset() -> void:
	if _entries.is_empty():
		return
	var changed_ids: Array[StringName] = _entries.keys()
	_entries.clear()
	for quest_id: StringName in changed_ids:
		changed.emit(quest_id)


func _seed_objectives(definition: QuestDef) -> Dictionary[StringName, int]:
	var seeded: Dictionary[StringName, int] = {}
	for authored: Dictionary in definition.objectives:
		var objective_id := StringName(authored.get("id", &""))
		if objective_id != &"":
			seeded[objective_id] = 0
	return seeded


func _restore_progress(raw: Variant,
		definition: QuestDef) -> Dictionary[StringName, int]:
	var restored: Dictionary[StringName, int] = _seed_objectives(definition)
	if raw is not Dictionary:
		return restored
	for authored: Dictionary in definition.objectives:
		var objective_id := StringName(authored.get("id", &""))
		var raw_value: Variant = (raw as Dictionary).get(
			String(objective_id), (raw as Dictionary).get(objective_id, 0))
		if raw_value is not int and raw_value is not float:
			continue
		restored[objective_id] = clampi(
			int(raw_value), 0, int(authored.get("goal", 0)))
	return restored


func _all_complete(definition: QuestDef, objective_progress: Dictionary) -> bool:
	for authored: Dictionary in definition.objectives:
		var objective_id := StringName(authored.get("id", &""))
		if int(objective_progress.get(objective_id, 0)) \
				< int(authored.get("goal", 0)):
			return false
	return true


func _emit_restore_changes(previous: Dictionary[StringName, Dictionary],
		definitions: Array[QuestDef]) -> void:
	var announced: Dictionary[StringName, bool] = {}
	for definition: QuestDef in definitions:
		if definition == null:
			continue
		var quest_id: StringName = definition.id
		if previous.get(quest_id, {}) != _entries.get(quest_id, {}):
			announced[quest_id] = true
			changed.emit(quest_id)
	for quest_id: StringName in previous:
		if not announced.has(quest_id) and not _entries.has(quest_id):
			changed.emit(quest_id)
