class_name GlintDb
extends Catalogue
## The Glint Statue's finite prototype ladder. Trial completion is the only
## source of Glimmer; ranks remain in Game.upgrades with every other permanent
## purchase, so there is no mutable currency counter that can drift from them.

const CISTERN_SUN_GLINT_ID: StringName = &"cistern_sun_glint"
const CISTERN_SUN_RUN_PUZZLE_ID: StringName = &"glint_cistern_sun_run"
const CISTERN_SUN_RUN_ATOM_INDEX: int = 0
const HEALTH_ID: StringName = &"glint_health"
const STAMINA_ID: StringName = &"glint_stamina"
const MAGIC_ID: StringName = &"glint_magic"

const TRIAL_IDS: Array[StringName] = [CISTERN_SUN_GLINT_ID]
const UPGRADE_IDS: Array[StringName] = [HEALTH_ID, STAMINA_ID, MAGIC_ID]
const RANKS: int = 1
const COST: int = 1


## The latching socket flag distinguishes "this solved run was resumed" from a
## genuinely new run. The permanent trial id alone cannot do that: suppressing
## the annex from it would restore a saved hero into geometry that no longer
## exists. `Run.enter()` clears this atom flag, so only the next run omits it.
static func cistern_sun_run_flag() -> StringName:
	return StringName("atom_%s_%s_%d" % [CISTERN_SUN_RUN_PUZZLE_ID,
		PuzzleAtoms.SUN_SOCKET, CISTERN_SUN_RUN_ATOM_INDEX])


static func lines() -> Array[Dictionary]:
	return [
		_line(HEALTH_ID),
		_line(STAMINA_ID),
		_line(MAGIC_ID),
	]


static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at: Dictionary[StringName, int] = {}
	for i: int in rows.size():
		var id: StringName = rows[i]["id"]
		at[id] = i
	return [{
		"title": "GLINT",
		"icon": "glint_orb",
		"tracks": [
			_track(at, HEALTH_ID, "HEALTH"),
			_track(at, STAMINA_ID, "STAMINA"),
			_track(at, MAGIC_ID, "MAGIC"),
		],
	}]


static func remaining(id: StringName) -> int:
	if not UPGRADE_IDS.has(id):
		return -1
	return RANKS - _rank(id)


static func can_buy(line: Dictionary) -> bool:
	var id := _line_id(line)
	return UPGRADE_IDS.has(id) and _rank(id) < RANKS \
		and not _at_stat_ceiling(id) and Game.glimmer_balance() >= COST


static func refusal(line: Dictionary) -> String:
	var id := _line_id(line)
	if not UPGRADE_IDS.has(id):
		return "NOT A GLINT OFFERING"
	if _rank(id) >= RANKS:
		return "ALREADY AWAKENED"
	if _at_stat_ceiling(id):
		return "ALREADY AT THE LIMIT"
	if Game.glimmer_balance() < COST:
		return "NEED 1 GLIMMER"
	return ""


## The balance and rank are rechecked immediately before mutation. After the
## maxima are derived, only the stat named by this purchase is filled; buying
## one Glint cannot heal either of the other two bars.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id := _line_id(line)
	Game.upgrades[id] = _rank(id) + 1
	Game.resync_maxima(false)
	match id:
		HEALTH_ID:
			Game.health_points = Game.max_health_points
			Bus.player_health_changed.emit(
				Game.health_points, Game.max_health_points)
		STAMINA_ID:
			Game.stamina = Game.max_stamina
			Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
		MAGIC_ID:
			Game.magic = Game.max_magic
			Bus.magic_changed.emit(Game.magic, Game.max_magic)
		_:
			return false
	Bus.item_acquired.emit(id)
	return true


static func crafts(_line: Dictionary) -> bool:
	return true


static func currency_label() -> String:
	return "Glimmer"


static func currency_balance() -> int:
	return Game.glimmer_balance()


static func format_currency(amount: int) -> String:
	return "%d Glimmer%s" % [amount, "" if amount == 1 else "s"]


static func currency_icon() -> StringName:
	return &"upgrade"


static func emblem() -> StringName:
	return &"upgrade"


static func craft_verb() -> String:
	return "AWAKEN"


static func _track(at: Dictionary[StringName, int], id: StringName,
		name: String) -> Dictionary:
	return {
		"name": name,
		"line": int(at.get(id, -1)),
		"owned": _rank(id),
		"rungs": RANKS,
		"rung_names": [name],
	}


static func _line(id: StringName) -> Dictionary:
	match id:
		HEALTH_ID:
			return {
				"id": id,
				"label": "HEALTH",
				"cost": COST,
				"parts": {},
				"blurb": "Spend 1 Glimmer permanently. Strengthen the body.",
				"detail": "%d -> %d max HP" % [Game.max_health_points,
					mini(Game.max_health_points + K.GLINT_HEALTH_POINTS,
						K.MAX_HEALTH_POINTS)],
			}
		STAMINA_ID:
			var current := _permanent_stamina_max()
			return {
				"id": id,
				"label": "STAMINA",
				"cost": COST,
				"parts": {},
				"blurb": "Spend 1 Glimmer permanently. Deepen endurance.",
				"detail": "%d -> %d max stamina" % [int(round(current)),
					int(round(minf(current + K.GLINT_STAMINA_POINTS,
						K.STAMINA_MAX)))],
			}
		MAGIC_ID:
			return {
				"id": id,
				"label": "MAGIC",
				"cost": COST,
				"parts": {},
				"blurb": "Spend 1 Glimmer permanently. Widen the magic reserve.",
				"detail": "%d -> %d max magic" % [Game.max_magic,
					mini(Game.max_magic + K.GLINT_MAGIC_POINTS, K.MAGIC_MAX)],
			}
	return {}


static func _rank(id: StringName) -> int:
	if not UPGRADE_IDS.has(id):
		return 0
	return clampi(int(Game.upgrades.get(id, 0)), 0, RANKS)


static func _at_stat_ceiling(id: StringName) -> bool:
	match id:
		HEALTH_ID:
			return Game.max_health_points >= K.MAX_HEALTH_POINTS
		STAMINA_ID:
			return _permanent_stamina_max() >= K.STAMINA_MAX
		MAGIC_ID:
			return Game.max_magic >= K.MAGIC_MAX
	return true


static func _permanent_stamina_max() -> float:
	return maxf(K.MAX_STAMINA, Game.max_stamina - Game.well_fed_bonus())


static func _line_id(line: Dictionary) -> StringName:
	var raw_id: Variant = line.get("id", &"")
	if raw_id is StringName or raw_id is String:
		return StringName(raw_id)
	return &""
