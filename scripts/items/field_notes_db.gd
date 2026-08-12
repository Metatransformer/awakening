class_name FieldNotesDb
extends Catalogue
## The Society's Field Notes: five permanent observations and the three
## one-rank doctrines those notes can buy. Definitions live only here; `Game`
## owns the saved balance and awarded set, while doctrine ranks use the existing
## `Game.upgrades` store shared by every other permanent purchase.

const FIRST_DESCENT_DEBRIEF_ID: StringName = &"first_descent_debrief"
const CISTERN_GATE_CYCLE_SOLVED_ID: StringName = &"cistern_gate_cycle_solved"
const CISTERN_SHORTCUT_OPENED_ID: StringName = &"cistern_shortcut_opened"
const CISTERN_WARDEN_DEFEATED_ID: StringName = &"cistern_warden_defeated"
const FAIR_WEIGHTS_LEDGER_HOME_ID: StringName = &"fair_weights_ledger_home"

const ROPE_DRILL_ID: StringName = &"doctrine_rope_drill"
const MEASURED_BREATH_ID: StringName = &"doctrine_measured_breath"
const SWEEP_PATTERN_ID: StringName = &"doctrine_sweep_pattern"

const OBSERVATION_IDS: Array[StringName] = [
	FIRST_DESCENT_DEBRIEF_ID,
	CISTERN_GATE_CYCLE_SOLVED_ID,
	CISTERN_SHORTCUT_OPENED_ID,
	CISTERN_WARDEN_DEFEATED_ID,
	FAIR_WEIGHTS_LEDGER_HOME_ID,
]
const DOCTRINE_IDS: Array[StringName] = [
	ROPE_DRILL_ID,
	MEASURED_BREATH_ID,
	SWEEP_PATTERN_ID,
]

const NOTE_VALUE: int = 1
const DOCTRINE_COST: int = 2
const DOCTRINE_RANKS: int = 1

const EXTRACTION_CHANNEL_REDUCTION: float = 0.2
const STAMINA_REGEN_MULTIPLIER: float = 1.05
const HEAT_MAGNET_BONUS: float = 0.5
const WARM_HEAT_TIER: int = 1

const OBSERVATIONS: Dictionary = {
	FIRST_DESCENT_DEBRIEF_ID: {
		"id": FIRST_DESCENT_DEBRIEF_ID,
		"label": "First debrief after a descent",
		"notes": NOTE_VALUE,
	},
	CISTERN_GATE_CYCLE_SOLVED_ID: {
		"id": CISTERN_GATE_CYCLE_SOLVED_ID,
		"label": "Solved the Cistern gate cycle",
		"notes": NOTE_VALUE,
	},
	CISTERN_SHORTCUT_OPENED_ID: {
		"id": CISTERN_SHORTCUT_OPENED_ID,
		"label": "Opened the Cistern shortcut",
		"notes": NOTE_VALUE,
	},
	CISTERN_WARDEN_DEFEATED_ID: {
		"id": CISTERN_WARDEN_DEFEATED_ID,
		"label": "Defeated the Cistern Warden",
		"notes": NOTE_VALUE,
	},
	FAIR_WEIGHTS_LEDGER_HOME_ID: {
		"id": FAIR_WEIGHTS_LEDGER_HOME_ID,
		"label": "Brought home the Tally-Ledger of Fair Weights",
		"notes": NOTE_VALUE,
	},
}

const DOCTRINES: Dictionary = {
	ROPE_DRILL_ID: {
		"id": ROPE_DRILL_ID,
		"label": "Rope Drill",
		"cost": DOCTRINE_COST,
		"ranks": DOCTRINE_RANKS,
		"blurb": "extraction channel 0.2 seconds shorter",
	},
	MEASURED_BREATH_ID: {
		"id": MEASURED_BREATH_ID,
		"label": "Measured Breath",
		"cost": DOCTRINE_COST,
		"ranks": DOCTRINE_RANKS,
		"blurb": "stamina regeneration 5% faster",
	},
	SWEEP_PATTERN_ID: {
		"id": SWEEP_PATTERN_ID,
		"label": "Sweep Pattern",
		"cost": DOCTRINE_COST,
		"ranks": DOCTRINE_RANKS,
		"blurb": "Heat magnet radius +0.5 m at Warm or above",
	},
}


static func is_observation(id: StringName) -> bool:
	return OBSERVATIONS.has(id)


static func is_doctrine(id: StringName) -> bool:
	return DOCTRINES.has(id)


static func has_definition(id: StringName) -> bool:
	return is_observation(id) or is_doctrine(id)


static func observation_definition(id: StringName) -> Dictionary:
	if not is_observation(id):
		return {}
	return (OBSERVATIONS[id] as Dictionary).duplicate(true)


static func doctrine_definition(id: StringName) -> Dictionary:
	if not is_doctrine(id):
		return {}
	return (DOCTRINES[id] as Dictionary).duplicate(true)


static func definition(id: StringName) -> Dictionary:
	if is_observation(id):
		return observation_definition(id)
	return doctrine_definition(id)


static func display_text(id: StringName) -> String:
	var row: Dictionary = definition(id)
	return String(row.get("label", ""))


static func doctrine_effect_text(id: StringName) -> String:
	var row: Dictionary = doctrine_definition(id)
	return String(row.get("blurb", ""))


static func observation_note_value(id: StringName) -> int:
	if not is_observation(id):
		return 0
	return NOTE_VALUE


static func observation_for_puzzle(puzzle_id: StringName) -> StringName:
	var observation_id: StringName = &""
	match puzzle_id:
		&"gate_1":
			observation_id = CISTERN_GATE_CYCLE_SOLVED_ID
		&"shortcut_1":
			observation_id = CISTERN_SHORTCUT_OPENED_ID
		_:
			pass
	return observation_id


static func observation_for_boss(boss_id: StringName) -> StringName:
	if boss_id == &"cistern_warden":
		return CISTERN_WARDEN_DEFEATED_ID
	return &""


static func doctrine_rank(id: StringName) -> int:
	if not is_doctrine(id):
		return 0
	return clampi(int(Game.upgrades.get(id, 0)), 0, DOCTRINE_RANKS)


static func doctrine_owned(id: StringName) -> bool:
	return doctrine_rank(id) >= DOCTRINE_RANKS


static func extraction_channel_time(base_seconds: float) -> float:
	if not doctrine_owned(ROPE_DRILL_ID):
		return base_seconds
	return maxf(0.0, base_seconds - EXTRACTION_CHANNEL_REDUCTION)


static func stamina_regen(regen_per_second: float) -> float:
	if not doctrine_owned(MEASURED_BREATH_ID):
		return regen_per_second
	return regen_per_second * STAMINA_REGEN_MULTIPLIER


static func heat_magnet_range(base_range: float, heat_tier: int) -> float:
	if heat_tier < WARM_HEAT_TIER or not doctrine_owned(SWEEP_PATTERN_ID):
		return base_range
	return base_range + HEAT_MAGNET_BONUS


## The service sells doctrines only. Observation definitions are queried by the
## return receipt after award and never become advance objectives on this board.
static func lines() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: StringName in DOCTRINE_IDS:
		if not doctrine_owned(id):
			rows.append(_doctrine_line(id))
	return rows


static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at: Dictionary[StringName, int] = {}
	for i: int in rows.size():
		var id: StringName = rows[i]["id"]
		at[id] = i

	var doctrines: Array[Dictionary] = []
	for id: StringName in DOCTRINE_IDS:
		doctrines.append({
			"name": display_text(id),
			"line": int(at.get(id, -1)),
			"owned": doctrine_rank(id),
			"rungs": DOCTRINE_RANKS,
		})
	return [{"title": "METHODS", "tracks": doctrines}]


static func remaining(id: StringName) -> int:
	if is_observation(id):
		return 0
	if is_doctrine(id):
		return DOCTRINE_RANKS - doctrine_rank(id)
	return -1


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = _line_id(line)
	return is_doctrine(id) and not doctrine_owned(id) \
		and Game.field_notes >= DOCTRINE_COST


static func refusal(line: Dictionary) -> String:
	var id: StringName = _line_id(line)
	if not is_doctrine(id):
		return "NOT A DOCTRINE"
	if doctrine_owned(id):
		return "ALREADY LEARNED"
	if Game.field_notes < DOCTRINE_COST:
		return "NEED %d FIELD NOTES" % DOCTRINE_COST
	return ""


static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = _line_id(line)
	# The authored definition owns the price. Never trust a catalogue row handed
	# back by a caller, because changing its `cost` would otherwise mint a doctrine.
	Game.field_notes -= DOCTRINE_COST
	Game.upgrades[id] = DOCTRINE_RANKS
	Bus.doctrine_purchased.emit(id, Game.field_notes)
	Bus.item_acquired.emit(id)
	return true


static func crafts(_line: Dictionary) -> bool:
	return false


static func currency_label() -> String:
	return "Field Notes"


static func currency_balance() -> int:
	return Game.field_notes


static func format_currency(amount: int) -> String:
	return "%d Field Note%s" % [amount, "" if amount == 1 else "s"]


static func currency_icon() -> StringName:
	return &"read"


static func emblem() -> StringName:
	return &"read"


static func craft_verb() -> String:
	return "LEARN"


static func _doctrine_line(id: StringName) -> Dictionary:
	var row: Dictionary = doctrine_definition(id)
	return {
		"id": id,
		"kind": &"doctrine",
		"label": String(row["label"]),
		"cost": DOCTRINE_COST,
		"parts": {},
		"blurb": String(row["blurb"]),
		"detail": String(row["blurb"]),
	}


static func _line_id(line: Dictionary) -> StringName:
	var raw_id: Variant = line.get("id", &"")
	if raw_id is StringName or raw_id is String:
		return StringName(raw_id)
	return &""
