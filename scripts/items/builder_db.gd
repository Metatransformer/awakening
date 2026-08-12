class_name BuilderDb
extends Catalogue
## The Builder's one authorised garrison mechanism. The catalogue stays visible
## after construction so the works board records what now guards the west gate.

const DEFENSE_ID: StringName = &"west_gate_bolt_thrower"
const COST: int = 150
const PARTS := {&"riveted_plate": 2, &"tension_coil": 1}


static func emblem() -> StringName:
	return &"upgrade"


static func craft_verb() -> String:
	return "BUILD"


static func lines() -> Array[Dictionary]:
	var built := Game.raid_defense_built()
	return [{
		"id": DEFENSE_ID,
		"label": "WEST GATE BOLT-THROWER",
		"cost": 0 if built else COST,
		"tally": "BUILT" if built else "",
		"parts": PARTS,
		"blurb": "A crank-drawn garrison mechanism trained across the west gate.",
		"detail": "Fires on raiders even while Kael is away.",
	}]


static func groups() -> Array[Dictionary]:
	return [{
		"title": "DEFENCES",
		"tracks": [{
			"name": "",
			"line": 0,
			"owned": 1 if Game.raid_defense_built() else 0,
			"rungs": 1,
		}],
	}]


static func remaining(id: StringName) -> int:
	if id != DEFENSE_ID:
		return -1
	return 0 if Game.raid_defense_built() else 1


static func can_buy(line: Dictionary) -> bool:
	if StringName(line.get("id", &"")) != DEFENSE_ID or Game.raid_defense_built():
		return false
	if Game.raid_phase() != GarrisonRaidState.PHASE_ARMED \
			and Game.raid_phase() != GarrisonRaidState.PHASE_WARNED:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


static func refusal(line: Dictionary) -> String:
	if Game.raid_defense_built():
		return "ALREADY BUILT"
	if Game.raid_phase() == GarrisonRaidState.PHASE_ACTIVE:
		return "THE RAID HAS BEGUN"
	if Game.raid_terminal():
		return "THE RAID IS OVER"
	var parts: Dictionary = line.get("parts", {})
	for id: StringName in parts:
		if Game.component_count(id) < int(parts[id]):
			var def := ItemDb.get_def(id)
			var what: String = def.display_name if def != null else String(id)
			return "NOT ENOUGH %s" % what.to_upper()
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Checked then charged like the forge: the complete bill is known affordable
## before either purse moves, and the raid state changes only after it is paid.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var parts: Dictionary = line.get("parts", {})
	if not Game.spend_gold(int(line["cost"])):
		return false
	for id: StringName in parts:
		Game.spend_component(id, int(parts[id]))
	if not Game.raid_build_defense():
		push_error("BuilderDb.buy: paid construction could not be recorded")
		return false
	Bus.item_acquired.emit(DEFENSE_ID)
	return true
