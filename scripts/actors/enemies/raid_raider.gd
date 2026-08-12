class_name RaidRaider
extends Enemy
## One saved garrison attacker made live. Game owns the campaign record; this
## body mirrors it while the courtyard scene owns simulation.

const SYNC_INTERVAL := 0.25
const ROUTE_POINT_EPSILON := 0.32

var raid_id: StringName = &""
var route_progress: float = 0.0
var objective_cooldown: float = GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL

var _route: Array[Vector3] = []
var _route_length: float = 0.0
var _objective: GarrisonRaidObjective
var _sync_left: float = SYNC_INTERVAL
var _last_synced_hp: int = -1
var _last_synced_progress: float = -1.0
var _last_synced_cooldown: float = -1.0
var _objective_swing_left: float = 0.0


## Called before entering the tree. The copied record is the only saved state
## this actor restores; the route and objective are authored scene references.
func configure(record: Dictionary, world_route: Array[Vector3],
		objective: GarrisonRaidObjective) -> void:
	var saved: Dictionary = record.duplicate(true)
	raid_id = StringName(saved.get("id", &""))
	kind = StringName(saved.get("kind", &"kobold"))
	level = Prog.FIRST
	behaviour = &"none"
	drop_seed = absi(hash(raid_id)) + 1
	_route = world_route.duplicate()
	_objective = objective
	route_progress = clampf(float(saved.get("route_progress", 0.0)), 0.0, 1.0)
	objective_cooldown = clampf(
		float(saved.get("objective_cooldown",
			GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL)),
		0.0, GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL)
	_last_synced_hp = maxi(0, int(saved.get("hp", 1)))
	_measure_route()


func _ready() -> void:
	super()
	add_to_group(&"raid_raider")
	if _route.size() >= 2:
		global_position = _route_position(route_progress)
	if _objective != null:
		_anchor = _objective.global_position
	health.quarters = clampi(_last_synced_hp, 1, health.max_quarters)
	health.dead = false
	state = State.IDLE
	_last_synced_hp = health.quarters
	_last_synced_progress = route_progress
	_last_synced_cooldown = objective_cooldown


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		super(delta)
		return

	_player = _find_player()
	var player_close: bool = _player != null \
		and _distance() <= float(_def["detect"])
	if player_close or state != State.IDLE:
		super(delta)
		_tick_sync(delta)
		return

	_tick_authored_route(delta)
	_tick_sync(delta)


func _tick_chase(delta: float) -> void:
	# Enemy's ordinary 17 m room leash is shorter than the authored run from the
	# south gate to this objective. The objective remains the persistent anchor;
	# while Kael is already inside interest range, use the present point only for
	# the inherited leash check so the ordinary chase/attack machine can engage.
	var objective_anchor := _anchor
	if _player != null and _distance() <= float(_def["detect"]) * 1.35:
		_anchor = global_position
	super(delta)
	_anchor = objective_anchor


func _tick_authored_route(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _objective_swing_left > 0.0:
		_objective_swing_left = maxf(0.0, _objective_swing_left - delta)

	if route_progress < 1.0 and _route_length > 0.001:
		var next_progress := minf(
			1.0, route_progress + delta / GarrisonRaidState.ROUTE_TRAVEL_DURATION)
		var target := _route_position(next_progress)
		var heading := K.plane(target - global_position)
		if heading.length() > 0.001:
			var speed := _route_length / GarrisonRaidState.ROUTE_TRAVEL_DURATION
			_face_heading(heading.normalized(), delta, 260.0)
			_steer(heading.normalized(), speed)
			_play(&"walk_fwd", true, clampf(speed / 2.2, 0.75, 1.65))
		else:
			_stop()
		route_progress = next_progress
	else:
		_tick_objective(delta)

	if not is_on_floor():
		velocity.y -= K.GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if _ragdoll != null:
		_ragdoll.drive(global_position, delta)
	rotation.y = _facing


func _tick_objective(delta: float) -> void:
	if _objective == null:
		_stop()
		return
	var to_objective := K.plane(_objective.global_position - global_position)
	if to_objective.length() > ROUTE_POINT_EPSILON:
		var speed := _route_length / GarrisonRaidState.ROUTE_TRAVEL_DURATION
		_face_heading(to_objective.normalized(), delta, 220.0)
		_steer(to_objective.normalized(), speed)
		_play(&"walk_fwd", true, clampf(speed / 2.2, 0.75, 1.65))
		return
	_stop()
	if _objective_swing_left <= 0.0:
		_play(&"idle", true)
	if not Game.raid_active():
		return

	objective_cooldown -= delta
	if objective_cooldown > 0.0:
		return
	objective_cooldown += GarrisonRaidState.OBJECTIVE_ATTACK_INTERVAL
	_objective_swing_left = 0.42
	_play(&"attack_1")
	Bus.request_sfx.emit(
		&"swing_heavy" if _height() >= 1.70 else &"swing", global_position)
	if Game.raid_objective_attack(raid_id):
		_objective.strike()
	_sync_campaign(true)


func _measure_route() -> void:
	_route_length = 0.0
	for i in maxi(0, _route.size() - 1):
		_route_length += _route[i].distance_to(_route[i + 1])


func _route_position(progress: float) -> Vector3:
	if _route.is_empty():
		return global_position
	if _route.size() == 1 or _route_length <= 0.001:
		return _route[0]
	var left := clampf(progress, 0.0, 1.0) * _route_length
	for i in _route.size() - 1:
		var segment := _route[i].distance_to(_route[i + 1])
		if left <= segment or i == _route.size() - 2:
			var t := left / segment if segment > 0.001 else 0.0
			return _route[i].lerp(_route[i + 1], clampf(t, 0.0, 1.0))
		left -= segment
	return _route.back()


func _tick_sync(delta: float) -> void:
	_sync_left -= delta
	if _sync_left > 0.0:
		return
	_sync_left = SYNC_INTERVAL
	_sync_campaign(false)


func _sync_campaign(force: bool) -> void:
	if raid_id == &"" or health == null or health.dead:
		return
	var hp_changed := health.quarters != _last_synced_hp
	var route_changed := absf(route_progress - _last_synced_progress) >= 0.01
	var cooldown_changed := absf(objective_cooldown - _last_synced_cooldown) >= 0.05
	if not force and not hp_changed and not route_changed and not cooldown_changed:
		return
	if Game.raid_sync_attacker(
			raid_id, health.quarters, route_progress, objective_cooldown):
		_last_synced_hp = health.quarters
		_last_synced_progress = route_progress
		_last_synced_cooldown = objective_cooldown


func sync_now() -> void:
	_sync_campaign(true)


func discard_mirror() -> void:
	# Used only when a save is about to replace campaign authority. Clearing the
	# stable id makes the queued node's _exit_tree deliberately silent.
	raid_id = &""


func _on_damaged(hit: Hit) -> void:
	super(hit)
	# HealthComponent has already spent the hit. Mirroring that total here avoids
	# applying the same blow a second time to campaign state.
	if health.quarters > 0:
		_sync_campaign(true)


func _on_died() -> void:
	# The stable id reaches campaign authority before Enemy begins its inherited
	# death presentation (which awaits before cleanup).
	Game.raid_report_kill(raid_id)
	super()


func _drop_loot() -> void:
	pass


func _exit_tree() -> void:
	if health != null and not health.dead:
		_sync_campaign(true)
