class_name ToolDb
extends RefCounted
## Presentation-only catalogue of permanent utility tools. Ownership stays in
## `Game.items`; this manifest never grants, equips, drops, or sells anything.

const TOOL_IDS: Array[StringName] = [ShopDb.WOODSMAN_AXE_ID]

const DEFS := {
	ShopDb.WOODSMAN_AXE_ID: {
		"display_name": "WOODSMAN'S AXE",
		"category": "TOOL",
		"blurb": "Cuts one daily bundle at the exterior Timber Yard.",
	},
}


static func definition(id: StringName) -> Dictionary:
	if not DEFS.has(id):
		return {}
	var out: Dictionary = (DEFS[id] as Dictionary).duplicate()
	out["id"] = id
	out["name"] = out["display_name"]
	out["owned"] = Game.has(id)
	return out


static func summary(id: StringName) -> Dictionary:
	return definition(id)


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in TOOL_IDS:
		out.append(definition(id))
	return out
