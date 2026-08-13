class_name DevPuzzleCatalogue
extends RefCounted
## Stable developer fixtures for the puzzle console. This registry is deliberately
## separate from `PuzzleAtoms` and Dungeon's placement tables: these are authored
## test rooms, never production generator candidates.

static var FIXTURES: Array[Dictionary] = [
	{
		"id": &"eye_sequence",
		"display_name": "Eye Sequence",
		"description": "Shoot three wall eyes from left to right; a wrong shot resets the row.",
		"required_tier": PuzzleAtoms.T1,
		"required_item": &"bow",
	},
	{
		"id": &"lantern_coupling",
		"display_name": "Lantern Coupling",
		"description": "A 3x3 lights-out board where each blow toggles its orthogonal neighbours.",
		"required_tier": PuzzleAtoms.T0,
		"required_item": &"",
	},
	{
		"id": &"pillar_chain",
		"display_name": "Pillar Chain",
		"description": "Topple two linked pillar runs by supplying the missing link at the gap.",
		"required_tier": PuzzleAtoms.T2,
		"required_item": &"burst",
	},
	{
		"id": &"plate_nest",
		"display_name": "Plate Nest",
		"description": "Push the loose block across the room to hold the reversible pressure plate.",
		"required_tier": PuzzleAtoms.T0,
		"required_item": &"",
	},
	{
		"id": &"small_key",
		"display_name": "Small Key",
		"description": "Collect the key, then spend it at the watched gate.",
		"required_tier": PuzzleAtoms.tier(&"small_key"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"small_key")],
	},
	{
		"id": &"urn",
		"display_name": "Urn",
		"description": "Break the supply urn with a blow.",
		"required_tier": PuzzleAtoms.tier(&"urn"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"urn")],
	},
	{
		"id": &"pressure_plate",
		"display_name": "Pressure Plate",
		"description": "Stand on the reversible plate to hold its gate open.",
		"required_tier": PuzzleAtoms.tier(&"pressure_plate"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"pressure_plate")],
	},
	{
		"id": &"push_block",
		"display_name": "Push Block",
		"description": "Push the block north onto its marked floor socket.",
		"required_tier": PuzzleAtoms.tier(&"push_block"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"push_block")],
	},
	{
		"id": &"eye_switch",
		"display_name": "Eye Switch",
		"description": "Shoot the north-wall eye with an arrow.",
		"required_tier": PuzzleAtoms.tier(&"eye_switch"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"eye_switch")],
	},
	{
		"id": &"cracked_pillar",
		"display_name": "Cracked Pillar",
		"description": "Topple the cracked pillar with Burst.",
		"required_tier": PuzzleAtoms.tier(&"cracked_pillar"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"cracked_pillar")],
	},
	{
		"id": &"hook_ring",
		"display_name": "Hook Ring",
		"description": "Catch the ring above the gate with the hookshot.",
		"required_tier": PuzzleAtoms.tier(&"hook_ring"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"hook_ring")],
	},
	{
		"id": &"sun_socket",
		"display_name": "Sun Socket",
		"description": "Reflect the light shaft into the sun socket.",
		"required_tier": PuzzleAtoms.tier(&"sun_socket"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"sun_socket")],
	},
	{
		"id": &"lantern",
		"display_name": "Lantern",
		"description": "Strike the lantern to toggle it alight.",
		"required_tier": PuzzleAtoms.tier(&"lantern"),
		"required_item": PuzzleAtoms.TIER_ITEM[PuzzleAtoms.tier(&"lantern")],
	},
]


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fixture in FIXTURES:
		out.append(fixture.duplicate(true))
	return out


static func has_fixture(id: StringName) -> bool:
	for fixture in FIXTURES:
		if fixture["id"] == id:
			return true
	return false


static func row(id: StringName) -> Dictionary:
	for fixture in FIXTURES:
		if fixture["id"] == id:
			return fixture.duplicate(true)
	return {}


static func summary_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for fixture in FIXTURES:
		var item: StringName = fixture["required_item"]
		var requirement := "T%d" % int(fixture["required_tier"])
		if item != &"":
			requirement += " / %s" % item
		out.append("%s — %s [%s] — %s" % [
			fixture["id"], fixture["display_name"], requirement,
			fixture["description"],
		])
	return out
