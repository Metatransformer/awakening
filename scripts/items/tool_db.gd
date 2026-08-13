class_name ToolDb
extends RefCounted
## Authoritative catalogue of durable utility tools. Definitions live here;
## mutable durability and compatibility ownership live on `Game`.

const WOODSMAN_AXE_ID := &"woodsman_axe"
const PICKAXE_ID := &"pickaxe"
const FISHING_ROD_ID := &"fishing_rod"

const TOOL_IDS: Array[StringName] = [
	WOODSMAN_AXE_ID,
	PICKAXE_ID,
	FISHING_ROD_ID,
]

const DEFS := {
	WOODSMAN_AXE_ID: {
		"display_name": "WOODSMAN'S AXE",
		"category": "TOOL",
		"max_durability": 8,
		"gold": 60,
		"parts": {&"iron_scrap": 3},
		"stored_firewood": 0,
		"blurb": "Fells one tree each day in the outskirts grove.",
	},
	PICKAXE_ID: {
		"display_name": "PICKAXE",
		"category": "TOOL",
		"max_durability": 12,
		"gold": 75,
		"parts": {&"iron_scrap": 3},
		"stored_firewood": 0,
		"blurb": "A durable mining tool for working stone and ore.",
	},
	FISHING_ROD_ID: {
		"display_name": "FISHING ROD",
		"category": "TOOL",
		"max_durability": 10,
		"gold": 45,
		"parts": {&"iron_scrap": 1},
		"stored_firewood": 1,
		"blurb": "A balanced rod for fishing the garrison pond.",
	},
}


static func has(id: StringName) -> bool:
	return DEFS.has(id)


static func max_durability(id: StringName) -> int:
	if not has(id):
		return 0
	return int((DEFS[id] as Dictionary).get("max_durability", 0))


static func definition(id: StringName) -> Dictionary:
	if not has(id):
		return {}
	var out: Dictionary = (DEFS[id] as Dictionary).duplicate(true)
	out["id"] = id
	out["name"] = out["display_name"]
	out["known"] = Game.tool_known(id)
	out["usable"] = Game.tool_usable(id)
	out["owned"] = out["usable"]
	out["durability"] = Game.tool_durability(id)
	return out


static func summary(id: StringName) -> Dictionary:
	return definition(id)


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in TOOL_IDS:
		out.append(definition(id))
	return out
