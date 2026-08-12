class_name WorldClock
extends Node
## Persistent campaign time. Register this script as `/root/Clock` after the
## foundation lands; consumers intentionally discover it dynamically.

signal minute_changed(day: int, hour: int, minute: int)
signal phase_changed(phase: StringName)
signal dawn_started(day: int)
signal service_availability_changed(available: bool)
signal garrison_phase_changed(phase: StringName)
signal bonfire_started(day: int)

const HOURS_PER_REAL_SECOND: float = 1.0 / 80.0
const HOURS_PER_DAY: float = 24.0
const MINUTES_PER_DAY: int = 1440
const DAWN_HOUR: float = 5.0
const SERVICE_OPEN_HOUR: float = 7.0
const REVEILLE_OPEN_HOUR: float = 6.0
const SERVICE_CLOSE_HOUR: float = 20.0
const BONFIRE_HOUR: float = 20.0
const BEDTIME_HOUR: float = 23.0

const GARRISON_DAYTIME: StringName = &"daytime"
const GARRISON_BONFIRE: StringName = &"bonfire"
const GARRISON_BEDTIME: StringName = &"bedtime"

var day: int = 1
var hour: float = 8.0
var running: bool = true

var _last_absolute_minute: int = -1
var _last_phase: StringName = &""
var _last_garrison_phase: StringName = &""
var _last_service_available: bool = false
var _last_day: int = -1


func _ready() -> void:
	bonfire_started.connect(Game.resolve_bonfire)
	_prime_observed_state()


func _process(delta: float) -> void:
	if running and not get_tree().paused:
		advance_hours(delta * HOURS_PER_REAL_SECOND)
	else:
		# Service hours can change when the reveille upgrade is purchased even
		# while the clock itself is stopped.
		_emit_state_changes()


func set_time(new_day: int, new_hour: float, emit_dawn: bool = false) -> void:
	_set_time(new_day, new_hour, emit_dawn, true)


func _set_time(new_day: int, new_hour: float, emit_dawn: bool,
		replay_crossings: bool) -> void:
	var old_absolute_hour: float = _absolute_hour()
	var requested: float = float(new_day - 1) * HOURS_PER_DAY + new_hour
	var normalized: float = maxf(0.0, requested)
	day = int(floor(normalized / HOURS_PER_DAY)) + 1
	hour = fposmod(normalized, HOURS_PER_DAY)
	if replay_crossings and normalized > old_absolute_hour:
		_emit_crossed_boundaries(old_absolute_hour, normalized, emit_dawn)
	_emit_state_changes()


func advance_hours(hours: float) -> void:
	if is_zero_approx(hours):
		_emit_state_changes()
		return
	set_time(day, hour + hours, hours > 0.0)


func sleep_to_dawn() -> void:
	var target_day: int = day if hour < DAWN_HOUR else day + 1
	# The target contains exactly one dawn crossing, including when sleep begins
	# before dawn on the same calendar day.
	set_time(target_day, DAWN_HOUR, true)


func services_available() -> bool:
	var opening_hour: float = SERVICE_OPEN_HOUR
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		var upgrades_value: Variant = game.get("upgrades")
		if upgrades_value is Dictionary:
			var upgrades: Dictionary = upgrades_value
			if int(upgrades.get(&"elder_reveille", 0)) > 0:
				opening_hour = REVEILLE_OPEN_HOUR
	return hour >= opening_hour and hour < SERVICE_CLOSE_HOUR


func garrison_phase() -> StringName:
	return garrison_phase_of(hour)


static func garrison_phase_of(at_hour: float) -> StringName:
	var normalized_hour: float = fposmod(at_hour, HOURS_PER_DAY)
	if normalized_hour >= DAWN_HOUR and normalized_hour < BONFIRE_HOUR:
		return GARRISON_DAYTIME
	if normalized_hour >= BONFIRE_HOUR and normalized_hour < BEDTIME_HOUR:
		return GARRISON_BONFIRE
	return GARRISON_BEDTIME


func next_garrison_transition() -> Dictionary:
	if hour < DAWN_HOUR:
		return {"phase": GARRISON_DAYTIME, "day": day, "hour": DAWN_HOUR}
	if hour < BONFIRE_HOUR:
		return {"phase": GARRISON_BONFIRE, "day": day, "hour": BONFIRE_HOUR}
	if hour < BEDTIME_HOUR:
		return {"phase": GARRISON_BEDTIME, "day": day, "hour": BEDTIME_HOUR}
	return {"phase": GARRISON_DAYTIME, "day": day + 1, "hour": DAWN_HOUR}


func snapshot() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"running": running,
	}


func restore(data: Dictionary) -> void:
	var restored_day: int = maxi(1, int(data.get("day", 1)))
	var restored_hour: float = float(data.get("hour", 8.0))
	_set_time(restored_day, restored_hour, false, false)
	running = bool(data.get("running", true))


func _absolute_hour() -> float:
	return float(day - 1) * HOURS_PER_DAY + hour


func _minute_of_day() -> int:
	return int(floor(hour * 60.0 + 0.0001)) % MINUTES_PER_DAY


func _emit_crossed_boundaries(from_absolute_hour: float, to_absolute_hour: float,
		emit_dawn: bool) -> void:
	var dawn_index: int = int(floor((from_absolute_hour - DAWN_HOUR) / HOURS_PER_DAY)) + 1
	var dawn_absolute_hour: float = float(dawn_index) * HOURS_PER_DAY + DAWN_HOUR
	var bonfire_index: int = int(floor(
		(from_absolute_hour - BONFIRE_HOUR) / HOURS_PER_DAY)) + 1
	var bonfire_absolute_hour: float = float(bonfire_index) * HOURS_PER_DAY + BONFIRE_HOUR
	while true:
		var next_dawn: float = dawn_absolute_hour if emit_dawn else INF
		var next_boundary: float = minf(next_dawn, bonfire_absolute_hour)
		if next_boundary > to_absolute_hour:
			return
		if next_dawn < bonfire_absolute_hour:
			dawn_started.emit(dawn_index + 1)
			dawn_index += 1
			dawn_absolute_hour += HOURS_PER_DAY
		else:
			bonfire_started.emit(bonfire_index + 1)
			bonfire_index += 1
			bonfire_absolute_hour += HOURS_PER_DAY


func _prime_observed_state() -> void:
	_last_absolute_minute = (day - 1) * MINUTES_PER_DAY + _minute_of_day()
	_last_phase = SkyCycle.phase_of(hour)
	_last_garrison_phase = garrison_phase()
	_last_service_available = services_available()
	_last_day = day


func _emit_state_changes() -> void:
	var minute_of_day: int = _minute_of_day()
	var absolute_minute: int = (day - 1) * MINUTES_PER_DAY + minute_of_day
	var phase: StringName = SkyCycle.phase_of(hour)
	var schedule_phase: StringName = garrison_phase()
	var available: bool = services_available()
	var day_changed: bool = day != _last_day

	if absolute_minute != _last_absolute_minute or day_changed:
		var whole_hour: int = int(floor(float(minute_of_day) / 60.0))
		minute_changed.emit(day, whole_hour, minute_of_day % 60)
	if phase != _last_phase:
		phase_changed.emit(phase)
	if schedule_phase != _last_garrison_phase:
		garrison_phase_changed.emit(schedule_phase)
	if available != _last_service_available:
		service_availability_changed.emit(available)

	_last_absolute_minute = absolute_minute
	_last_phase = phase
	_last_garrison_phase = schedule_phase
	_last_service_available = available
	_last_day = day
