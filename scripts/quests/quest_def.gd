class_name QuestDef
extends RefCounted
## Immutable authored quest data. Mutable campaign progress belongs to QuestState.
##
## Like ItemDef, definitions live in a small in-code catalogue: there is no
## Inspector workflow that would benefit from .tres files, and the authored rows
## remain reviewable as ordinary GDScript.

var id: StringName
var title: String
var category: String
var summary: String
var giver_npc_id: StringName
var turn_in_npc_id: StringName
var offer_pages: PackedStringArray
var turn_in_pages: PackedStringArray
var objectives: Array[Dictionary] = []


static func make(p_id: StringName, p_title: String, p_category: String,
		p_summary: String, p_giver_npc_id: StringName,
		p_turn_in_npc_id: StringName, p_offer_pages: PackedStringArray,
		p_turn_in_pages: PackedStringArray,
		p_objectives: Array[Dictionary]) -> QuestDef:
	var definition := QuestDef.new()
	definition.id = p_id
	definition.title = p_title
	definition.category = p_category
	definition.summary = p_summary
	definition.giver_npc_id = p_giver_npc_id
	definition.turn_in_npc_id = p_turn_in_npc_id
	definition.offer_pages = p_offer_pages.duplicate()
	definition.turn_in_pages = p_turn_in_pages.duplicate()
	for authored: Dictionary in p_objectives:
		definition.objectives.append(authored.duplicate(true))
	return definition


static func objective(p_id: StringName, p_label: String,
		p_target: StringName, p_goal: int) -> Dictionary:
	assert(p_id != &"")
	assert(p_target != &"")
	assert(p_goal > 0)
	return {
		"id": p_id,
		"label": p_label,
		"target": p_target,
		"goal": p_goal,
	}


func objective_by_id(objective_id: StringName) -> Dictionary:
	for authored: Dictionary in objectives:
		if StringName(authored.get("id", &"")) == objective_id:
			return authored.duplicate(true)
	return {}


func objective_at(index: int) -> Dictionary:
	if index < 0 or index >= objectives.size():
		return {}
	return objectives[index].duplicate(true)


func objective_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for authored: Dictionary in objectives:
		ids.append(StringName(authored.get("id", &"")))
	return ids
