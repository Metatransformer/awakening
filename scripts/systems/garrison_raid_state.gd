class_name GarrisonRaidState
extends RefCounted
## Persistent campaign authority for the authored garrison raid. Live actors
## mirror these records; they never become a second owner of the outcome.

signal changed

const PHASE_DORMANT: StringName = &"dormant"
const PHASE_ARMED: StringName = &"armed"
const PHASE_WARNED: StringName = &"warned"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_WON: StringName = &"won"
const PHASE_LOST: StringName = &"lost"

const ADVANCE_WARNING_HOUR: int = 15
const ATTACK_HOUR: int = 23
const INTEGRITY_MAX: int = 100
const ROUTE_TRAVEL_DURATION: float = 7.0
const OBJECTIVE_ATTACK_INTERVAL: float = 3.0
const OBJECTIVE_DAMAGE: int = 5
const BOLT_DEFENSE_INTERVAL: float = 3.5

const _VALID_PHASES: Array[StringName] = [
	PHASE_DORMANT, PHASE_ARMED, PHASE_WARNED, PHASE_ACTIVE, PHASE_WON,
	PHASE_LOST,
]
const _ROSTER: Array[Dictionary] = [
	{"id": &"kobold_1", "kind": &"kobold", "max_hp": 8},
	{"id": &"kobold_2", "kind": &"kobold", "max_hp": 8},
	{"id": &"kobold_3", "kind": &"kobold", "max_hp": 8},
	{"id": &"orc_1", "kind": &"orc", "max_hp": 14},
]

var _phase: StringName = PHASE_DORMANT
var _scheduled_raid_day: int = 0
var _integrity: int = INTEGRITY_MAX
var _defense_built: bool = false
var _ledger_stolen: bool = false
var _attackers: Array[Dictionary] = []
var _bolt_cooldown: float = BOLT_DEFENSE_INTERVAL

var _advance_notice_pending: bool = false
var _advance_notice_delivered: bool = false
var _urgent_notice_pending: bool = false
var _urgent_notice_delivered: bool = false

## Scene ownership is deliberately runtime-only. Restoring a save must resume
## offscreen simulation until a newly loaded garrison scene claims it.
var _live_scene_owns_simulation: bool = false


func arm(at_day: int, _at_hour: float) -> bool:
	if _phase != PHASE_DORMANT:
		return false
	_phase = PHASE_ARMED
	_scheduled_raid_day = maxi(1, at_day) + 1
	changed.emit()
	return true


func observe_time(at_day: int, at_hour: float) -> void:
	if _phase == PHASE_DORMANT or is_terminal():
		return
	var now: float = _absolute_hour(at_day, at_hour)
	var attack_at: float = _absolute_hour(_scheduled_raid_day, ATTACK_HOUR)
	if (_phase == PHASE_ARMED or _phase == PHASE_WARNED) and now >= attack_at:
		_start_raid()
		return
	var warning_at: float = _absolute_hour(
		_scheduled_raid_day, ADVANCE_WARNING_HOUR)
	if _phase == PHASE_ARMED and now >= warning_at:
		_phase = PHASE_WARNED
		if not _advance_notice_delivered:
			_advance_notice_pending = true
		changed.emit()


func tick(delta: float) -> void:
	if _phase != PHASE_ACTIVE or _live_scene_owns_simulation or delta <= 0.0:
		return

	var objective_time: Dictionary[StringName, float] = {}
	for attacker in _attackers:
		if not bool(attacker["alive"]):
			continue
		var old_progress: float = float(attacker["route_progress"])
		var travel_left: float = (1.0 - old_progress) * ROUTE_TRAVEL_DURATION
		attacker["route_progress"] = minf(
			1.0, old_progress + delta / ROUTE_TRAVEL_DURATION)
		objective_time[attacker["id"]] = maxf(0.0, delta - travel_left)

	if _defense_built:
		_bolt_cooldown -= delta
		while _bolt_cooldown <= 0.0 and _phase == PHASE_ACTIVE:
			var target_index: int = _first_living_index()
			if target_index < 0:
				break
			_kill_at(target_index)
			_bolt_cooldown += BOLT_DEFENSE_INTERVAL
	if _phase != PHASE_ACTIVE:
		return

	for attacker in _attackers:
		if not bool(attacker["alive"]):
			continue
		var raider_id: StringName = attacker["id"]
		var attack_time: float = objective_time.get(raider_id, 0.0)
		if attack_time <= 0.0:
			continue
		attacker["objective_cooldown"] = \
			float(attacker["objective_cooldown"]) - attack_time
		while float(attacker["objective_cooldown"]) <= 0.0 \
				and _phase == PHASE_ACTIVE and bool(attacker["alive"]):
			attacker["objective_cooldown"] = \
				float(attacker["objective_cooldown"]) + OBJECTIVE_ATTACK_INTERVAL
			objective_attack(raider_id)
		if _phase != PHASE_ACTIVE:
			return


func objective_attack(raider_id: StringName) -> bool:
	if _phase != PHASE_ACTIVE:
		return false
	var at: int = _attacker_index(raider_id)
	if at < 0:
		return false
	var attacker: Dictionary = _attackers[at]
	if not bool(attacker["alive"]) or float(attacker["route_progress"]) < 1.0:
		return false
	_integrity = maxi(0, _integrity - OBJECTIVE_DAMAGE)
	if _integrity == 0 and living_count() > 0:
		_phase = PHASE_LOST
		_ledger_stolen = true
	changed.emit()
	return true


func attacker_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for attacker in _attackers:
		out.append(attacker.duplicate(true))
	return out


func attacker_record(raider_id: StringName) -> Dictionary:
	var at: int = _attacker_index(raider_id)
	return _attackers[at].duplicate(true) if at >= 0 else {}


func sync_attacker(raider_id: StringName, hp: int, route_progress: float,
		objective_cooldown: float) -> bool:
	if _phase != PHASE_ACTIVE and _phase != PHASE_LOST:
		return false
	var at: int = _attacker_index(raider_id)
	if at < 0:
		return false
	var attacker: Dictionary = _attackers[at]
	attacker["route_progress"] = _safe_float(route_progress, 0.0, 0.0, 1.0)
	attacker["objective_cooldown"] = _safe_float(
		objective_cooldown, OBJECTIVE_ATTACK_INTERVAL, 0.0,
		OBJECTIVE_ATTACK_INTERVAL)
	if not bool(attacker["alive"]):
		return true
	var synchronized_hp: int = clampi(hp, 0, int(attacker["max_hp"]))
	if synchronized_hp == 0:
		_kill_at(at)
	else:
		attacker["hp"] = synchronized_hp
	return true


func damage_attacker(raider_id: StringName, amount: int) -> bool:
	if amount <= 0 or (_phase != PHASE_ACTIVE and _phase != PHASE_LOST):
		return false
	var at: int = _attacker_index(raider_id)
	if at < 0 or not bool(_attackers[at]["alive"]):
		return false
	var hp: int = maxi(0, int(_attackers[at]["hp"]) - amount)
	if hp == 0:
		_kill_at(at)
	else:
		_attackers[at]["hp"] = hp
	return true


func kill_attacker(raider_id: StringName) -> bool:
	if _phase != PHASE_ACTIVE and _phase != PHASE_LOST:
		return false
	var at: int = _attacker_index(raider_id)
	if at < 0 or not bool(_attackers[at]["alive"]):
		return false
	_kill_at(at)
	return true


func living_count() -> int:
	var count: int = 0
	for attacker in _attackers:
		if bool(attacker["alive"]):
			count += 1
	return count


func phase() -> StringName:
	return _phase


func scheduled_raid_day() -> int:
	return _scheduled_raid_day


func integrity() -> int:
	return _integrity


func integrity_fraction() -> float:
	return float(_integrity) / float(INTEGRITY_MAX)


func is_active() -> bool:
	return _phase == PHASE_ACTIVE


func is_terminal() -> bool:
	return _phase == PHASE_WON or _phase == PHASE_LOST


func defense_built() -> bool:
	return _defense_built


func ledger_stolen() -> bool:
	return _ledger_stolen


func status() -> Dictionary:
	return {
		"phase": _phase,
		"scheduled_raid_day": _scheduled_raid_day,
		"attack_hour": ATTACK_HOUR,
		"integrity": _integrity,
		"integrity_fraction": integrity_fraction(),
		"living_raiders": living_count(),
		"active": is_active(),
		"terminal": is_terminal(),
		"defense_built": _defense_built,
		"ledger_stolen": _ledger_stolen,
	}


func set_live_scene_ownership(owns_simulation: bool) -> void:
	_live_scene_owns_simulation = owns_simulation


## Spend the same saved firing clock the offscreen simulation uses, but leave
## the damage to the live mechanism and the ordinary HealthComponent path.
func live_defense_target(delta: float) -> StringName:
	if _phase != PHASE_ACTIVE or not _defense_built \
			or not _live_scene_owns_simulation or delta <= 0.0:
		return &""
	_bolt_cooldown -= delta
	if _bolt_cooldown > 0.0:
		return &""
	var target_index: int = _first_living_index()
	if target_index < 0:
		return &""
	_bolt_cooldown += BOLT_DEFENSE_INTERVAL
	return StringName(_attackers[target_index]["id"])


func build_defense() -> bool:
	if _defense_built or (_phase != PHASE_ARMED and _phase != PHASE_WARNED):
		return false
	_defense_built = true
	changed.emit()
	return true


func restore_ledger() -> bool:
	if not _ledger_stolen:
		return false
	_ledger_stolen = false
	changed.emit()
	return true


func consume_advance_notice() -> bool:
	if not _advance_notice_pending:
		return false
	_advance_notice_pending = false
	_advance_notice_delivered = true
	changed.emit()
	return true


func consume_urgent_notice() -> bool:
	if not _urgent_notice_pending:
		return false
	_urgent_notice_pending = false
	_urgent_notice_delivered = true
	changed.emit()
	return true


func crosses_attack_boundary(from_day: int, from_hour: float, to_day: int,
		to_hour: float) -> bool:
	if _phase != PHASE_ARMED and _phase != PHASE_WARNED:
		return false
	var from_time: float = _absolute_hour(from_day, from_hour)
	var to_time: float = _absolute_hour(to_day, to_hour)
	var attack_time: float = _absolute_hour(_scheduled_raid_day, ATTACK_HOUR)
	return attack_time > from_time and attack_time <= to_time


func snapshot() -> Dictionary:
	return {
		"phase": _phase,
		"scheduled_raid_day": _scheduled_raid_day,
		"integrity": _integrity,
		"defense_built": _defense_built,
		"ledger_stolen": _ledger_stolen,
		"attackers": attacker_records(),
		"bolt_cooldown": _bolt_cooldown,
		"advance_notice_pending": _advance_notice_pending,
		"advance_notice_delivered": _advance_notice_delivered,
		"urgent_notice_pending": _urgent_notice_pending,
		"urgent_notice_delivered": _urgent_notice_delivered,
	}


func restore(data: Dictionary) -> void:
	var restored_phase: StringName = StringName(
		str(data.get("phase", PHASE_DORMANT)))
	_phase = restored_phase if _VALID_PHASES.has(restored_phase) else PHASE_DORMANT
	_scheduled_raid_day = _safe_int(
		data.get("scheduled_raid_day", 0), 0, 0, 2_147_483_647)
	if _phase != PHASE_DORMANT:
		_scheduled_raid_day = maxi(1, _scheduled_raid_day)
	_integrity = _safe_int(data.get("integrity", INTEGRITY_MAX),
		INTEGRITY_MAX, 0, INTEGRITY_MAX)
	_defense_built = _safe_bool(data.get("defense_built", false), false)
	_ledger_stolen = _safe_bool(
		data.get("ledger_stolen", _phase == PHASE_LOST), _phase == PHASE_LOST)
	if _phase != PHASE_LOST:
		_ledger_stolen = false
	_bolt_cooldown = _safe_float(data.get("bolt_cooldown", BOLT_DEFENSE_INTERVAL),
		BOLT_DEFENSE_INTERVAL, 0.0, BOLT_DEFENSE_INTERVAL)
	_live_scene_owns_simulation = false

	_advance_notice_delivered = _safe_bool(
		data.get("advance_notice_delivered", false), false)
	_advance_notice_pending = _safe_bool(
		data.get("advance_notice_pending", false), false) \
		and not _advance_notice_delivered
	_urgent_notice_delivered = _safe_bool(
		data.get("urgent_notice_delivered", false), false)
	_urgent_notice_pending = _safe_bool(
		data.get("urgent_notice_pending", false), false) \
		and not _urgent_notice_delivered

	_attackers = []
	if _phase == PHASE_ACTIVE or is_terminal():
		_restore_attackers(data.get("attackers", []))
	if _phase == PHASE_LOST:
		_integrity = 0
	elif _phase == PHASE_WON:
		_integrity = maxi(1, _integrity)
		for attacker in _attackers:
			attacker["hp"] = 0
			attacker["alive"] = false
		_ledger_stolen = false
	elif _phase == PHASE_ACTIVE:
		if _integrity == 0:
			_phase = PHASE_LOST
			_ledger_stolen = true
		elif living_count() == 0:
			_phase = PHASE_WON

	_sanitize_notice_state()


func _start_raid() -> void:
	_phase = PHASE_ACTIVE
	_integrity = INTEGRITY_MAX
	_ledger_stolen = false
	_attackers = _fresh_roster()
	_bolt_cooldown = BOLT_DEFENSE_INTERVAL
	if not _advance_notice_delivered:
		_advance_notice_pending = false
	_urgent_notice_pending = not _urgent_notice_delivered
	changed.emit()


func _kill_at(at: int) -> void:
	_attackers[at]["hp"] = 0
	_attackers[at]["alive"] = false
	if _phase == PHASE_ACTIVE and living_count() == 0 and _integrity > 0:
		_phase = PHASE_WON
	changed.emit()


func _first_living_index() -> int:
	for i in _attackers.size():
		if bool(_attackers[i]["alive"]):
			return i
	return -1


func _attacker_index(raider_id: StringName) -> int:
	for i in _attackers.size():
		if StringName(_attackers[i]["id"]) == raider_id:
			return i
	return -1


func _fresh_roster() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for template in _ROSTER:
		var max_hp: int = int(template["max_hp"])
		out.append({
			"id": StringName(template["id"]),
			"kind": StringName(template["kind"]),
			"max_hp": max_hp,
			"hp": max_hp,
			"alive": true,
			"route_progress": 0.0,
			"objective_cooldown": OBJECTIVE_ATTACK_INTERVAL,
		})
	return out


func _restore_attackers(raw_value: Variant) -> void:
	var raw_attackers: Array = raw_value if raw_value is Array else []
	for template in _ROSTER:
		var raw: Dictionary = {}
		for candidate in raw_attackers:
			if candidate is Dictionary \
					and StringName(candidate.get("id", &"")) == template["id"]:
				raw = candidate
				break
		var max_hp: int = int(template["max_hp"])
		var hp: int = _safe_int(raw.get("hp", max_hp), max_hp, 0, max_hp)
		var alive: bool = _safe_bool(raw.get("alive", hp > 0), hp > 0) and hp > 0
		if not alive:
			hp = 0
		_attackers.append({
			"id": StringName(template["id"]),
			"kind": StringName(template["kind"]),
			"max_hp": max_hp,
			"hp": hp,
			"alive": alive,
			"route_progress": _safe_float(raw.get("route_progress", 0.0),
				0.0, 0.0, 1.0),
			"objective_cooldown": _safe_float(
				raw.get("objective_cooldown", OBJECTIVE_ATTACK_INTERVAL),
				OBJECTIVE_ATTACK_INTERVAL, 0.0, OBJECTIVE_ATTACK_INTERVAL),
		})


func _sanitize_notice_state() -> void:
	if _phase == PHASE_DORMANT or _phase == PHASE_ARMED:
		_advance_notice_pending = false
		_advance_notice_delivered = false
		_urgent_notice_pending = false
		_urgent_notice_delivered = false
		return
	if _phase == PHASE_WARNED:
		_urgent_notice_pending = false
		_urgent_notice_delivered = false
		_advance_notice_pending = not _advance_notice_delivered
		return
	_advance_notice_pending = false
	_urgent_notice_pending = not _urgent_notice_delivered


static func _absolute_hour(at_day: int, at_hour: float) -> float:
	return float(maxi(1, at_day) - 1) * 24.0 + at_hour


static func _safe_float(value: Variant, fallback: float, minimum: float,
		maximum: float) -> float:
	if not (value is int or value is float):
		return fallback
	var number: float = float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return clampf(number, minimum, maximum)


static func _safe_int(value: Variant, fallback: int, minimum: int,
		maximum: int) -> int:
	if not (value is int or value is float):
		return fallback
	var number: float = float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return clampi(int(number), minimum, maximum)


static func _safe_bool(value: Variant, fallback: bool) -> bool:
	return bool(value) if value is bool else fallback
