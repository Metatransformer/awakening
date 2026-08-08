class_name GameCamera
extends Camera3D
## P1 — the Ocarina-of-Time third-person camera.
##
## Structure, straight out of refs/REFERENCE.md §1:
##
##   * The rig orbits an **at-point** (the hero's eye, K.HERO_EYE_Y) at an
##     azimuth `_yaw` and an elevation `_pitch_deg` measured ABOVE horizontal.
##     Dungeons use the DUNGEON0 set: 2.48–4.13 m at 5°, not the flatter/further
##     outdoor NORMAL1 set. §1.2
##   * Smoothing is exponential and **speed-gated** — the camera barely moves
##     while the hero stands still and swings hard while he runs — and vertical
##     follow is 2.5x lazier than horizontal (CAM_UPDATE_RATE_STEP_SCALE_Y 0.20
##     vs _XZ 0.50). §1.5
##   * Walls: `Camera_BGCheck` line-tests at->eye every frame and, on a hit,
##     latches a swing yaw and **arcs around the obstruction**. The reference is
##     explicit that shortening the boom is the wrong primary answer (§1.6), so
##     we swing first and only pull the boom in when no yaw within
##     `swing_max_deg` is clear — which is exactly the corridor-through-a-doorway
##     case, where there is no angle that works.
##   * Z with no target is Parallel mode: recentre exactly behind the hero over
##     ~4 ticks and drop FOV to 45°. §1.7
##
## Targeting framing (Camera_Battle1) is P3's. The seam is `set_target()` /
## `clear_target()` plus the Bus signals — this script only uses a live target to
## decide that Parallel mode does NOT apply.

## Explicit hero to follow. Left empty, the camera finds the "player" group.
@export var target_path: NodePath

@export_group("Boom")
## [oot] DUNGEON0 distMax. The boom lives between min_distance and this.
@export var distance: float = K.CAM_DIST_MAX
## [oot] DUNGEON0 distMin — the shortest boom we will rest at voluntarily.
@export var min_distance: float = K.CAM_DIST_MIN
## Absolute floor when geometry forces us in. Below this we would be inside him.
@export var hard_min_distance: float = 1.35
## Degrees the eye sits ABOVE the at-point. [oot] DUNGEON0 pitchTarget = 5.
@export var pitch_deg: float = K.CAM_PITCH
@export var fov_free: float = K.CAM_FOV
@export var fov_parallel: float = K.CAM_FOV_PARALLEL
@export var fov_blend_time: float = 0.25

@export_group("Follow")
## Seconds for the rig to catch up. Higher = laggier.
@export var lag: float = K.CAM_LAG
## [oot] §1.5 — the follow rate is multiplied by the hero's speed ratio, so the
## camera barely moves at a standstill and hauls itself along at a run. These
## two scale the base 1/lag rate at each end. Keeping the run end well above 1
## is what stops the hero sliding up-frame and shrinking while he sprints.
@export var lag_idle_scale: float = 0.45
@export var lag_run_scale: float = 2.4
## Vertical follow rate as a fraction of horizontal. [oot] 0.20/0.50 = 0.4.
@export var vertical_lag_scale: float = 0.4
## Hard leash — the at-point never trails the hero by more than this.
@export var at_leash: float = 2.2

@export_group("Look")
@export var mouse_sensitivity: float = 0.0035
@export var stick_speed_deg: float = 170.0
## Seconds after the player stops steering before autoswing takes over again.
@export var manual_hold_time: float = 0.85
## Fraction of the yaw error closed per second while the hero runs.
@export var autoswing: float = K.CAM_AUTOSWING
@export var autoswing_max_deg: float = 110.0
## Autoswing fades out between these two yaw errors and is dead beyond the second.
##
## This is not a polish knob, it is what stops the camera and the hero chasing
## each other. Input is camera-relative, so the hero steers toward the camera's
## yaw while autoswing steers the camera toward the hero's heading. Hold "back"
## and those two rules have no fixed point — the pair spins at the autoswing rate
## and the hero corkscrews across the room, which is precisely how he used to end
## up pinned to a corridor wall on the reversal. A large error means the player
## is deliberately running toward or across the lens, so the camera leaves it
## alone; small errors are just drift while running away, and those still close.
@export var autoswing_fade_from_deg: float = 70.0
@export var autoswing_fade_to_deg: float = 110.0
## [oot] Parallel recentres over CAM_DEFAULT_ANIM_TIME = 4 ticks.
@export var recenter_time: float = 4.0 * K.TICK
@export var capture_mouse: bool = true
## Mouse motion only steers while the cursor is actually grabbed. Without this
## the camera keeps spinning after the player frees the cursor for the pause
## menu or alt-tabs away, and under the screenshot harness — which deliberately
## never grabs the cursor — every stray desktop mouse movement walks the yaw,
## which quietly ruins a director run. p1_orbit.gd is the one caller that turns
## this off, so it can push synthetic motion down the real input path.
@export var mouse_look_requires_capture: bool = true
## Claim the viewport on spawn. Rooms ship with their own framing cameras (the
## proving ground has five); the gameplay camera has to win regardless of the
## order the scenes were instanced in.
@export var take_over_on_ready: bool = true

@export_group("Walls")
## Radius of the probe swept from the at-point to the eye.
@export var collide_radius: float = 0.3
## Largest yaw detour we will take to get around an obstruction.
@export var swing_max_deg: float = 78.0
@export var swing_step_deg: float = 9.0
## Degrees/sec the latched swing bias eases in and back out again.
@export var swing_rate_deg: float = 200.0
## When no yaw clears either — backed into a corner, or reversing into a wall —
## climb instead. [oot] Battle1 does the same thing with swingPitch 0->10; a
## steeper boom needs less horizontal room for the same length, so lifting is
## what buys the distance back rather than jamming the lens into his shoulders.
@export var lift_max_deg: float = 34.0
@export var lift_step_deg: float = 8.5
@export var lift_rate_deg: float = 110.0
## Metres/sec the boom is allowed to extend again once the wall is gone.
@export var push_out_speed: float = 3.2

var _hero: Node3D = null
var _target: Node3D = null

var _yaw: float = 0.0
var _pitch: float = K.CAM_PITCH
var _at: Vector3 = Vector3.ZERO
var _dist: float = K.CAM_DIST_MAX
var _swing_bias_deg: float = 0.0
var _lift_bias_deg: float = 0.0
var _look_input: Vector2 = Vector2.ZERO
var _manual_timer: float = 0.0
var _recenter_timer: float = 0.0
var _initialised: bool = false

var _probe: SphereShape3D = SphereShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	fov = fov_free
	_pitch = pitch_deg
	_dist = distance
	_probe.radius = collide_radius
	_shape_query.shape = _probe
	_shape_query.collision_mask = K.L_WORLD
	_shape_query.collide_with_areas = false
	_shape_query.margin = 0.02

	Bus.camera_recenter.connect(_on_recenter_requested)
	Bus.target_acquired.connect(set_target)
	Bus.target_lost.connect(clear_target)
	Bus.player_spawned.connect(_on_player_spawned)

	# The screenshot harness runs windowed; grabbing the cursor there would
	# hijack the machine mid-capture. Its SceneTree carries a script, the
	# shipping one does not — that is the cheapest reliable discriminator.
	if capture_mouse and get_tree().get_script() == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if take_over_on_ready:
		make_current.call_deferred()
	set_physics_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if mouse_look_requires_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var mm := event as InputEventMouseMotion
		_look_input += mm.relative * mouse_sensitivity
	elif event.is_action_pressed(&"pause") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Seam for P3 (targeting) ------------------------------------------------

## P3 calls this (or emits Bus.target_acquired) when a lock is made. This script
## only uses it to suppress Parallel mode — Battle1 framing belongs to P3.
func set_target(t: Node3D) -> void:
	_target = t


func clear_target() -> void:
	_target = null


## The yaw, in radians, that places the eye directly behind the hero.
func behind_yaw() -> float:
	if _hero == null:
		return _yaw
	var f := K.flat(-_hero.global_transform.basis.z)
	if f == Vector3.ZERO:
		return _yaw
	return atan2(-f.x, -f.z)


## Snap-free recentre, the OOT Parallel ease. Also used by Bus.camera_recenter.
func recenter() -> void:
	_recenter_timer = recenter_time
	_manual_timer = 0.0


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_hero = _resolve_hero()
	if _hero == null:
		return

	var want_at := _hero.global_position + Vector3.UP * K.HERO_EYE_Y
	if not _initialised:
		_at = want_at
		_yaw = behind_yaw()
		_dist = distance
		_initialised = true
		global_position = _at + _orbit_dir(_yaw, _pitch) * _dist

	var speed01 := _hero_speed01()

	_follow_at(want_at, speed01, delta)
	_apply_look(delta)
	_apply_parallel(delta)
	_apply_autoswing(speed01, delta)
	_place(delta)


func _resolve_hero() -> Node3D:
	if _hero != null and is_instance_valid(_hero):
		return _hero
	if not target_path.is_empty():
		var n := get_node_or_null(target_path)
		if n is Node3D:
			return n as Node3D
	var p := get_tree().get_first_node_in_group(&"player")
	return p as Node3D


func _on_player_spawned(p: Node3D) -> void:
	_hero = p
	_initialised = false


func _on_recenter_requested() -> void:
	recenter()


func _hero_speed01() -> float:
	if not (_hero is CharacterBody3D):
		return 0.0
	var v: Vector3 = (_hero as CharacterBody3D).velocity
	return clampf(Vector2(v.x, v.z).length() / K.RUN_SPEED, 0.0, 1.0)


## Exponential ease toward the hero's eye, speed-gated, with a lazier Y and a
## hard leash so a spawn or a teleport can never leave the rig behind. §1.5
func _follow_at(want: Vector3, speed01: float, delta: float) -> void:
	var rate := (1.0 / maxf(lag, 0.001)) * lerpf(lag_idle_scale, lag_run_scale, speed01)
	var kxz := 1.0 - exp(-rate * delta)
	var ky := 1.0 - exp(-rate * vertical_lag_scale * delta)
	_at.x = lerpf(_at.x, want.x, kxz)
	_at.z = lerpf(_at.z, want.z, kxz)
	_at.y = lerpf(_at.y, want.y, ky)
	# "LERPCeil" — converge instead of asymptoting.
	if absf(want.x - _at.x) < 0.005: _at.x = want.x
	if absf(want.z - _at.z) < 0.005: _at.z = want.z
	if absf(want.y - _at.y) < 0.005: _at.y = want.y
	var off := _at - want
	if off.length() > at_leash:
		_at = want + off.normalized() * at_leash


func _apply_look(delta: float) -> void:
	var stick := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	var look := _look_input
	_look_input = Vector2.ZERO
	look += stick * deg_to_rad(stick_speed_deg) * delta
	if look.length_squared() <= 0.0:
		_manual_timer = maxf(_manual_timer - delta, 0.0)
		return
	var invert := -1.0 if Settings.invert_camera_y else 1.0
	look *= maxf(Settings.camera_sensitivity, 0.05)
	_yaw -= look.x
	_pitch = clampf(_pitch + look.y * invert, K.CAM_MIN_PITCH, K.CAM_MAX_PITCH)
	_manual_timer = manual_hold_time
	# Steering by hand cancels a recentre in progress — the camera must never
	# fight the player's own input.
	_recenter_timer = 0.0


## Z held with nothing lockable = OOT's Parallel camera: hard behind the hero,
## FOV 45. Z with a live target is P3's Battle1 and we stay out of its way.
func _apply_parallel(delta: float) -> void:
	var parallel := Input.is_action_pressed(&"z_target") and _target == null
	if parallel:
		_recenter_timer = recenter_time
	# Settings.fov_offset is the player's accessibility FOV nudge (P14 owns it).
	var want_fov := (fov_parallel if parallel else fov_free) + Settings.fov_offset
	fov = lerpf(fov, want_fov, 1.0 - exp(-(1.0 / maxf(fov_blend_time, 0.001)) * delta))

	if _recenter_timer <= 0.0:
		return
	_recenter_timer = maxf(_recenter_timer - delta, 0.0)
	var err := wrapf(behind_yaw() - _yaw, -PI, PI)
	_yaw += err * clampf(delta / maxf(recenter_time, 0.001), 0.0, 1.0)


## Slow drift to behind the hero while he runs — never while the player steers.
func _apply_autoswing(speed01: float, delta: float) -> void:
	if _manual_timer > 0.0 or _recenter_timer > 0.0 or speed01 < 0.12:
		return
	var err := wrapf(behind_yaw() - _yaw, -PI, PI)
	var fade := 1.0 - smoothstep(deg_to_rad(autoswing_fade_from_deg),
			deg_to_rad(autoswing_fade_to_deg), absf(err))
	if fade <= 0.0:
		return
	var k := clampf(autoswing * speed01 * fade * delta, 0.0, 1.0)
	var step := err * k
	var cap := deg_to_rad(autoswing_max_deg) * delta
	_yaw += clampf(step, -cap, cap)


func _orbit_dir(yaw: float, pitch_degrees: float) -> Vector3:
	var p := deg_to_rad(pitch_degrees)
	var c := cos(p)
	return Vector3(sin(yaw) * c, sin(p), cos(yaw) * c)


## Sweep a sphere from the at-point toward `dir` and report how far the eye may
## travel. A start-overlap (hero jammed into a corner) degrades to a plain ray
## so we still get the best distance the raw geometry allows.
func _clear_distance(dir: Vector3, want: float) -> float:
	var space := get_world_3d().direct_space_state
	_shape_query.transform = Transform3D(Basis(), _at)
	_shape_query.motion = dir * want
	var res := space.cast_motion(_shape_query)
	if res.size() == 2 and res[0] > 0.001:
		return want * res[0]
	var rq := PhysicsRayQueryParameters3D.create(_at, _at + dir * want)
	rq.collision_mask = K.L_WORLD
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return want
	return maxf(_at.distance_to(hit.position) - collide_radius, 0.0)


func _place(delta: float) -> void:
	var want := distance
	var base_pitch := _pitch + _lift_bias_deg
	var clear := _clear_distance(_orbit_dir(_yaw + deg_to_rad(_swing_bias_deg), base_pitch), want)

	# Being nudged from distMax down toward distMin is inside the shipped dungeon
	# range and needs no drama. Only an obstruction that would force the boom
	# BELOW distMin is worth reacting to (§1.6).
	var swing_target := 0.0
	var lift_target := 0.0
	if clear < min_distance - 0.03:
		# 1. Arc around it on the yaw axis — the OOT answer.
		var sign_first := 1.0 if _swing_bias_deg >= 0.0 else -1.0
		var off := swing_step_deg
		while off <= swing_max_deg and swing_target == 0.0:
			for s: float in [sign_first, -sign_first]:
				var cand := _yaw + deg_to_rad(off * s)
				if _clear_distance(_orbit_dir(cand, _pitch), want) >= min_distance:
					swing_target = off * s
					break
			off += swing_step_deg
		# 2. Nothing arced clear: climb, and take whatever height buys back.
		if swing_target == 0.0:
			var lift := lift_step_deg
			while lift <= lift_max_deg:
				var p := minf(_pitch + lift, K.CAM_MAX_PITCH)
				if _clear_distance(_orbit_dir(_yaw, p), want) >= min_distance:
					lift_target = lift
					break
				lift += lift_step_deg
			if lift_target == 0.0:
				lift_target = lift_max_deg

	_swing_bias_deg = move_toward(_swing_bias_deg, swing_target, swing_rate_deg * delta)
	_lift_bias_deg = move_toward(_lift_bias_deg, lift_target, lift_rate_deg * delta)

	var dir := _orbit_dir(_yaw + deg_to_rad(_swing_bias_deg),
			minf(_pitch + _lift_bias_deg, K.CAM_MAX_PITCH))
	clear = _clear_distance(dir, want)

	# 3. Still blocked: pull in. Immediately on the way in — a lagged pull-in is
	# a clipped frame — and smoothly on the way back out.
	#
	# `hard_min_distance` is a comfort floor, NOT a licence to ignore the sweep.
	# Reversing at the corridor's end wall produces exactly the case where the
	# only clear distance is under a metre; clamping up to the comfort floor
	# there plants the eye a metre inside the wall and the player sees straight
	# through the level. An uncomfortably tight shoulder shot is survivable;
	# rendering the back side of the world is not. So geometry wins, always, and
	# the floor only applies while there is room for it.
	var allowed := minf(want, clear)
	if clear >= hard_min_distance:
		allowed = maxf(allowed, hard_min_distance)
	allowed = maxf(allowed, near * 2.0)
	if allowed < _dist:
		_dist = allowed
	else:
		_dist = move_toward(_dist, allowed, push_out_speed * delta)

	global_position = _at + dir * _dist
	if global_position.distance_squared_to(_at) > 0.0004:
		look_at(_at, Vector3.UP)
