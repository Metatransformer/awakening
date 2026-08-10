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
##   * Lock-on with nothing lockable is Parallel mode: recentre exactly behind
##     the hero over ~4 ticks and drop FOV to 45°. §1.7
##   * Lock-on WITH a target is Battle1 (`_apply_battle`): the eye eases onto the
##     hero→target line so the enemy is dead ahead down the middle of the frame,
##     and FOV pulls to K.CAM_FOV_LOCK.
##
## `Targeting` drives that through `set_target()` / `clear_target()` and the Bus
## signals. Note that lock-on is a TOGGLE, so nothing here may poll `z_target` —
## a held R3 is no longer a state, and the poll that used to live in
## `_apply_parallel` would have jammed the camera in Parallel under a resting
## thumb.

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
## Seconds for the battle framing to settle onto the hero->target line. Slower
## than the recentre on purpose: the target moves, and a rig that tracked it
## tightly would swing the whole world every time a goblin side-stepped.
@export var battle_frame_time: float = 0.55
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

@export_group("Aim")
## Over-the-shoulder framing while a bow or a hookshot is out. `HeroRanged` owns
## the stance and announces it on `Bus.aim_changed`; nothing here decides.
##
## The eye slides sideways rather than the boom rotating, so the crosshair ray
## stays PARALLEL to the boom axis and simply passes beside the hero. That is
## what makes screen-centre a usable sight: `HeroRanged._aim_from` raycasts down
## exactly this ray to find what the crosshair is over, and a rig that converged
## on the hero instead would put the crosshair on his shoulder blade.
##
## And in this stance the eye PITCHES IN PLACE — see `_boom_pitch`.
@export var aim_distance: float = K.CAM_DIST_AIM
@export var aim_shoulder: float = K.CAM_AIM_SHOULDER
@export var aim_rise: float = K.CAM_AIM_RISE
@export var aim_fov: float = K.CAM_FOV_AIM
@export var aim_blend_time: float = K.CAM_AIM_BLEND

@export_group("First person")
## Seconds to fall into the hero's eyes and back out again. Short on purpose:
## this is a toggle the player uses to READ a room, and a long dolly makes them
## wait twice for every glance.
@export var fp_blend_time: float = 0.18
## K.CAM_FOV_PARALLEL is already documented in consts.gd as "Z held with no
## target, and first-person". 45° vertical is about 73° horizontal at 16:9 — a
## shade tighter than the free camera, which is what makes looking across a room
## feel like looking rather than panning.
@export var fp_fov: float = K.CAM_FOV_PARALLEL

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

## The aim stance, and its 0..1 ease. Everything about the shoulder framing is
## scaled by `_aim01` rather than switched, so drawing the bow slides the rig in
## instead of cutting to it.
var _aiming: bool = false
var _aim01: float = 0.0
## The guard stance. Only autoswing reads it — there is no framing change and no
## ease, because raising a shield is not a change of shot.
var _guarding: bool = false

## First person, and its 0..1 ease. `_fp` is the player's decision; `_fp01` is
## how far the eye has travelled toward the hero's head.
var _fp: bool = false
var _fp01: float = 0.0
## Whether the move stick is allowed to eject the player yet. See
## `set_first_person` — it is false until the stick has been seen at rest.
var _fp_stick_armed: bool = false

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
	Bus.aim_changed.connect(set_aiming)
	Bus.guard_changed.connect(set_guarding)

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
	elif event.is_action_pressed(&"first_person"):
		set_first_person(not _fp)
	# `attack` exactly (HeroCombat.ATTACK_EXACT): plain LMB is the light swing and
	# Shift+LMB is `heavy`, and a loose read here would leave first person on the
	# strong attack too — harmless in itself, but it would disagree with the hero,
	# who does not swing on a loose `attack` any more. One rule, read the same way
	# on both sides of the same press.
	elif _fp and (event.is_action_pressed(&"attack", false, HeroCombat.ATTACK_EXACT)
			or event.is_action_pressed(&"heavy")
			or event.is_action_pressed(&"context")):
		# Any verb drops you out. The hero is rooted and his model is hidden in
		# here, so a swing or a roll taken from first person would be a move
		# nobody can see. Leaving on the same frame as the press means the press
		# itself still counts — `HeroCombat` polls the button and does not care
		# that the camera read it first.
		set_first_person(false)
	# THERE WAS A `pause` BRANCH HERE THAT RELEASED THE CURSOR, AND IT IS WHY THE
	# MOUSE STOPPED STEERING AFTER THE FIRST PAUSE OF EVERY SESSION.
	#
	# Unhandled input runs deepest-child-first, and `PauseMenu` is an autoload
	# under `root` while this camera is down in the current scene — so this ran
	# FIRST. It set MOUSE_MODE_VISIBLE, and the menu then opened, recorded
	# `_prev_mouse = VISIBLE` as the state to put back, and faithfully restored
	# "visible" on close. The pointer never came back for the rest of the run and
	# the camera had no right stick.
	#
	# Releasing the cursor belongs to whoever took the screen, because only that
	# node knows when to give it back. The camera GRABS it (`_ready`) and does not
	# arbitrate: `PauseMenu` save/restores around its own open/close, and the
	# full-screen screens do the same around their lifetime.


# --- Seam for P3 (targeting) ------------------------------------------------

## P3 calls this (or emits Bus.target_acquired) when a lock is made. This script
## only uses it to suppress Parallel mode — Battle1 framing belongs to P3.
func set_target(t: Node3D) -> void:
	_target = t


func clear_target() -> void:
	_target = null


# --- Seam for the ranged items ----------------------------------------------

## `HeroRanged` calls this through `Bus.aim_changed` when the trigger raises a
## bow or a hookshot, and again when the shot is over.
##
## It does NOT recentre, and it used to. That was written when the stance began
## on the D-pad — one recentre, on the frame you selected the bow, to stop a
## permanent sight opening with the lens pointed off at whatever you had last
## looked at. The stance begins on the TRIGGER now, and a recentre there is the
## camera swinging out from under the player at the exact instant they decided to
## shoot: they have already put the lens on the thing: that is why they pulled.
func set_aiming(on: bool) -> void:
	if on == _aiming:
		return
	_aiming = on


func aiming() -> bool:
	return _aiming


## The shield went up or came down. Deliberately does NOT recentre the way
## `set_aiming` does: drawing a bow is the player choosing a new shot, and a
## raised shield is the player standing his ground in the shot he already has.
func set_guarding(on: bool) -> void:
	_guarding = on


# --- First person -----------------------------------------------------------

## BOTW's right-stick click: the boom collapses to nothing and the player looks
## out of the hero's own head.
##
## There is no new look code here, and that is the point. The third-person
## camera's forward is `-_orbit_dir(_yaw, _pitch)` — the direction from the eye
## back down the boom at the hero — and that is EXACTLY the direction a head
## sitting at the at-point wants to face. So first person is this camera with
## `_dist` eased to zero: same yaw, same pitch, same stick handling, same
## sensitivity, and entering it can be a blend instead of a cut.
##
## What it is NOT is a stance the hero can act from. `Hero` roots him and hides
## his model on `Bus.first_person_changed`, because the alternative — a visible
## hero walking around with the lens inside his skull — is the inside of a head,
## every frame.
func set_first_person(on: bool) -> void:
	if on == _fp:
		return
	_fp = on
	if on:
		# Entering with the stick already held is the ordinary case — you press
		# R3 out of a run — and the eject below would cancel that press on the
		# very next frame, so the toggle would read as broken. It arms only once
		# the stick has come back to rest, which is also the moment the hero has
		# finished sliding to a halt.
		_fp_stick_armed = _move_stick().length() < K.STICK_DEADZONE
	Bus.first_person_changed.emit(on)


func first_person() -> bool:
	return _fp


## Everything that means "the player is doing something else now" kicks them
## out, and it is POLLED rather than hooked onto each of those events. A shop
## can open from a prompt, a lock can be taken by the trigger, a bow can be
## drawn from the D-pad — three unrelated paths into "not looking around any
## more", and a listener on each is three places for the fourth one to be
## forgotten. The head is only allowed to stay while nothing else has claimed
## the frame.
##
## Wanting to WALK is the fourth path, and the most common one: the player has
## read the room and now wants to go there. It has to be polled rather than
## hooked because a held direction is a state, not an event — `move_*` fires no
## `InputEvent` while it stays down, and under the harness `Input.action_press`
## fires none at all (CLAUDE.md §3).
func _tick_first_person(delta: float) -> void:
	if _fp:
		# K.STICK_DEADZONE is [oot]-measured and generous (0.33), which is what
		# keeps a resting gamepad from throwing you out of the stance.
		var steering := _move_stick().length() >= K.STICK_DEADZONE
		if not steering:
			_fp_stick_armed = true
		if ((Prompt != null and Prompt.blocked) or _aiming
				or (_target != null and is_instance_valid(_target))
				or (_fp_stick_armed and steering)):
			set_first_person(false)
	_fp01 = move_toward(_fp01, 1.0 if _fp else 0.0,
			delta / maxf(fp_blend_time, 0.001))


## The hero's move stick, read the same way `Hero` reads it. The camera does not
## steer with it — it only wants to know whether the player is asking to leave.
func _move_stick() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## The head. Taken off the hero directly rather than off `_at`, because `_at` is
## deliberately laggy (§1.5) — a boom is allowed to trail him, a skull is not.
func _fp_eye() -> Vector3:
	if _hero == null:
		return _at
	return _hero.global_position + Vector3.UP * K.HERO_EYE_Y


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

	_aim01 = move_toward(_aim01, 1.0 if _aiming else 0.0,
			delta / maxf(aim_blend_time, 0.001))
	_tick_first_person(delta)

	_follow_at(want_at, speed01, delta)
	_apply_look(delta)
	_apply_parallel(delta)
	_apply_battle(delta)
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
	look *= maxf(Settings.camera_sensitivity, 0.05) * _fov_gain()
	_yaw -= look.x
	# `look` is RADIANS and `_pitch` is DEGREES — the two ends of this function do
	# not share a unit, and for a long time this line pretended they did. Yaw was
	# right (it is radians throughout) and the pitch was 57x too slow: a full stick
	# held for a second and a half moved the aim about six degrees, which reads
	# exactly like a camera that cannot be pitched at all. That is why the hookshot
	# could not be aimed at a ceiling ring.
	_pitch = clampf(_pitch + rad_to_deg(look.y) * invert,
			K.CAM_MIN_PITCH, K.CAM_MAX_PITCH)
	_manual_timer = manual_hold_time
	# Steering by hand cancels a recentre in progress — the camera must never
	# fight the player's own input.
	_recenter_timer = 0.0


## Look sensitivity, scaled for how much lens is in front of it.
##
## `stick_speed_deg` is an ANGULAR rate, and the player does not steer in angles
## — they steer by watching something cross the screen. Narrow the lens without
## touching the rate and the same thumb movement throws the crosshair further,
## because every degree is now worth more pixels: at the sight's 42° against the
## free camera's 60°, the crosshair crossed the frame half again as fast in the
## one stance that exists to place it precisely. Overshooting a goblin's head at
## 12 m and hunting back and forth over it is the other half of "the right stick
## moves the crosshair around weird".
##
## The ratio of half-FOV TANGENTS is the exact correction — that is the screen
## width a degree buys — so this holds the crosshair's speed across the FRAME
## constant no matter what the lens is doing. Read off the live `fov`, so it also
## covers first person and the lock's pull-in, and so it needs no second knob to
## keep in step with `aim_fov` or the player's own `Settings.fov_offset`.
##
## Clamped at 0.35 rather than left open: a future scope narrow enough to want a
## quarter rate wants a deliberate number, not this function's arithmetic.
func _fov_gain() -> float:
	var base := tan(deg_to_rad(maxf(fov_free, 1.0) * 0.5))
	return clampf(tan(deg_to_rad(maxf(fov, 1.0) * 0.5)) / base, 0.35, 1.0)


## FOV, and the recentre ease.
##
## `z_target` used to be POLLED here, on the assumption it was held like OOT's Z.
## It is a toggle now (Targeting owns it, docs/CONTRACT.md §4), so a held button
## is no longer a state anything can read — an empty press arrives as
## `Bus.camera_recenter` instead, which is what `_recenter_timer` already ran on.
## Polling it after the toggle landed would have pinned the camera to Parallel
## for exactly as long as a thumb rested on R3.
func _apply_parallel(delta: float) -> void:
	# Locked: pull in a little, the way Battle1 does. Otherwise the free FOV.
	# Settings.fov_offset is the player's accessibility FOV nudge (P14 owns it).
	var base := fov_free
	if _target != null and is_instance_valid(_target):
		base = K.CAM_FOV_LOCK
	elif _recenter_timer > 0.0:
		base = fov_parallel
	# Sighting down a weapon is the narrowest the frame ever gets, and it wins
	# over the lock's own pull-in: aiming at a locked target is still aiming.
	base = lerpf(base, aim_fov, _aim01)
	# Last, and it wins outright: the two stances are mutually exclusive
	# (`_tick_first_person` drops the head the moment a bow comes out), so this
	# only ever blends against a `_aim01` that is on its way to zero.
	base = lerpf(base, fp_fov, _fp01)
	var want_fov := base + Settings.fov_offset
	fov = lerpf(fov, want_fov, 1.0 - exp(-(1.0 / maxf(fov_blend_time, 0.001)) * delta))

	# A recentre landing while the player is looking around from inside his own
	# head would swing the whole world under a thumb that was not asking for it.
	if _recenter_timer <= 0.0 or _fp01 > 0.0:
		return
	_recenter_timer = maxf(_recenter_timer - delta, 0.0)
	var err := wrapf(behind_yaw() - _yaw, -PI, PI)
	_yaw += err * clampf(delta / maxf(recenter_time, 0.001), 0.0, 1.0)


## Battle1: frame the hero and what he is locked onto.
##
## The eye is placed on the far side of the hero from the target, so the shot
## reads hero-in-front-of-enemy down a single line. That one rule is what makes
## a lock-on shot legible — the player's screen-space "toward the enemy" is
## always straight up the middle, so the stick directions mean the same thing
## for the whole fight.
##
## Manual look still wins for `manual_hold_time`. A camera that cannot be
## nudged while locked is a camera that fights you the moment the framing picks
## the wrong side of a pillar, and the wall-swing in `_place` cannot solve every
## one of those.
func _apply_battle(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _hero == null:
		return
	if _manual_timer > 0.0 or _recenter_timer > 0.0:
		return
	var to := K.flat(_target.global_position - _hero.global_position)
	if to == Vector3.ZERO:
		return
	# Behind the hero on the hero->target line: the orbit yaw whose eye sits
	# opposite the target. Same convention as behind_yaw().
	var want := atan2(-to.x, -to.z)
	var err := wrapf(want - _yaw, -PI, PI)
	var k := clampf(delta / maxf(battle_frame_time, 0.001), 0.0, 1.0)
	_yaw += err * k


## Slow drift to behind the hero while he runs — never while the player steers.
func _apply_autoswing(speed01: float, delta: float) -> void:
	# `_fp01` first: the hero is rooted in first person so `speed01` is already
	# zero, but the tail of the blend OUT is not, and a head that drifts toward
	# behind-the-hero on its way back to the boom is a head that turns itself.
	if _fp01 > 0.0 or _manual_timer > 0.0 or _recenter_timer > 0.0 or speed01 < 0.12:
		return
	# Never while aiming. The hero turns to face the lens in this stance, so
	# "drift toward behind the hero" and "the hero faces the camera" are the same
	# pair of rules that corkscrewed the camera before (see autoswing_fade_from_deg)
	# — except here they agree perfectly and the pair has no error to close, so
	# every stray metre of strafing would drag the crosshair off the target the
	# player is holding it on. Aim is steered by hand, full stop.
	#
	# A raised guard is the same stance and gets the same answer. Measured:
	# strafing left for half a second behind a shield rotated the hero 31° off
	# what he was facing, in slow motion, with the stick never asking him to
	# turn — the camera crept toward behind-him, he steered to the camera, and
	# the pair walked away together. Z-Parallel means the facing does not move.
	if _aiming or _guarding:
		return
	# Locked, `_apply_battle` owns the yaw. The two rules mostly agree — the
	# hero faces the target, so "behind the hero" and "behind the hero on the
	# target line" are the same ray — but they stop agreeing the instant he is
	# knocked or shoved off that line, and two rules writing one value is how
	# the camera-vs-hero corkscrew documented above got built the first time.
	if _target != null and is_instance_valid(_target):
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
## `origin` is the point the boom pivots on. It is the at-point normally, and the
## SHOULDER-OFFSET at-point while aiming: the eye is what has to stay out of the
## wall, and sweeping from the hero's centre while the eye sits 0.6 m to one side
## clears a corridor the eye is not actually in.
func _clear_distance(dir: Vector3, want: float, origin: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	_shape_query.transform = Transform3D(Basis(), origin)
	_shape_query.motion = dir * want
	var res := space.cast_motion(_shape_query)
	if res.size() == 2 and res[0] > 0.001:
		return want * res[0]
	var rq := PhysicsRayQueryParameters3D.create(origin, origin + dir * want)
	rq.collision_mask = K.L_WORLD
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return want
	return maxf(origin.distance_to(hit.position) - collide_radius, 0.0)


func _place(delta: float) -> void:
	var want := lerpf(distance, aim_distance, _aim01)
	# The boom the wall logic is defending. Aiming asks for a boom well inside
	# distMin on purpose, and comparing a deliberate 1.55 m against a 2.48 m floor
	# would have the rig arcing and climbing to escape an obstruction that is not
	# there — every frame, for the whole time the bow is out.
	var floor_dist := minf(min_distance, want)
	var pivot := _aim_pivot()
	# The pitch the EYE is placed at, which stops being the pitch it LOOKS at as
	# soon as a weapon comes up. Everything below that decides where the eye goes
	# — the wall sweep, the arc, the climb — reads `rest`; only `view`, right at
	# the bottom, reads `_pitch`.
	var rest := _boom_pitch()
	var base_pitch := rest + _lift_bias_deg
	var clear := _clear_distance(
			_orbit_dir(_yaw + deg_to_rad(_swing_bias_deg), base_pitch), want, pivot)

	# Being nudged from distMax down toward distMin is inside the shipped dungeon
	# range and needs no drama. Only an obstruction that would force the boom
	# BELOW distMin is worth reacting to (§1.6).
	var swing_target := 0.0
	var lift_target := 0.0
	# Not once the eye is most of the way into his head. The wall logic exists to
	# keep a BOOM out of geometry and first person has no boom, so letting it run
	# there would rotate the player's own view to dodge something that is nowhere
	# near where they are looking from.
	if clear < floor_dist - 0.03 and _fp01 < 0.5:
		# 1. Arc around it on the yaw axis — the OOT answer.
		var sign_first := 1.0 if _swing_bias_deg >= 0.0 else -1.0
		var off := swing_step_deg
		while off <= swing_max_deg and swing_target == 0.0:
			for s: float in [sign_first, -sign_first]:
				var cand := _yaw + deg_to_rad(off * s)
				if _clear_distance(_orbit_dir(cand, rest), want, pivot) >= floor_dist:
					swing_target = off * s
					break
			off += swing_step_deg
		# 2. Nothing arced clear: climb, and take whatever height buys back.
		if swing_target == 0.0:
			var lift := lift_step_deg
			while lift <= lift_max_deg:
				var p := minf(rest + lift, K.CAM_MAX_PITCH)
				if _clear_distance(_orbit_dir(_yaw, p), want, pivot) >= floor_dist:
					lift_target = lift
					break
				lift += lift_step_deg
			if lift_target == 0.0:
				lift_target = lift_max_deg

	_swing_bias_deg = move_toward(_swing_bias_deg, swing_target, swing_rate_deg * delta)
	_lift_bias_deg = move_toward(_lift_bias_deg, lift_target, lift_rate_deg * delta)

	var dir := _orbit_dir(_yaw + deg_to_rad(_swing_bias_deg),
			minf(rest + _lift_bias_deg, K.CAM_MAX_PITCH))
	clear = _clear_distance(dir, want, pivot)

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

	# Where the lens POINTS, as opposed to where it sits.
	#
	# Off the aim stance these are the same ray and this is exactly `dir` — the
	# camera looks back down its own boom, which is the whole third-person rig.
	# In the aim stance they come apart twice over. The pitch comes apart in
	# `_boom_pitch`. The wall's swing and lift come apart here, and for the same
	# reason: an obstruction is allowed to move the EYE, it is not allowed to move
	# the crosshair. A rig that let it would drag a held sight off the goblin
	# because a pillar clipped the boom, and the player would have no idea why.
	var view := _orbit_dir(
			_yaw + deg_to_rad(_swing_bias_deg) * (1.0 - _aim01),
			_pitch + _lift_bias_deg * (1.0 - _aim01))
	# First person: the eye walks from the end of the boom to the hero's head, and
	# the LOOK direction unwinds to the UNBIASED orbit at the same rate — whatever
	# swing or lift the wall logic had latched when the toggle came in must not
	# ride into the head with it and leave the player facing 40° off where the
	# stick had them.
	var eye := pivot + dir * _dist
	if _fp01 > 0.0:
		view = view.lerp(_orbit_dir(_yaw, _pitch), _fp01).normalized()
		eye = eye.lerp(_fp_eye(), _fp01)
	global_position = eye

	# `eye - view`, not the pivot. `dir` points from the pivot OUT to the eye, so
	# the camera's forward is `-dir` and aiming one metre down that ray is the
	# same rotation the old `look_at(pivot)` produced at every boom length except
	# zero -- where the pivot IS the position and there is nothing to aim at.
	look_at(eye - view, Vector3.UP)


## The elevation the EYE is placed at, which is `_pitch` until a weapon comes up
## and then eases to the rig's resting `pitch_deg` and stays there.
##
## This is the difference between a camera that pitches and a camera that ORBITS,
## and it is the whole of "the right stick moves the crosshair around wrong".
##
## Off the aim stance, orbiting is correct and is the reference behaviour (§1.1):
## looking down swings the eye up and over the hero, which is how you see what he
## is standing on. In the aim stance the boom is 1.55 m and the pivot is at his
## shoulder, so the same rule swung the eye through an arc a metre and a half
## across. Measured, before this: full up-look put the eye at y=0.32 — under his
## knees, looking up past his hip — and full down-look put it at y=2.75, a
## bird's-eye over the top of his head. Two and a half metres of camera travel
## for a thumb movement that was only ever asking to tilt the sight. The world
## heaved, the hero swam across the frame, and the crosshair — which is nailed to
## screen centre and was the one thing behaving — read as the thing at fault,
## because it was visibly rotating about a point out in front of the lens.
##
## Freezing the placement pitch is what every third-person sight does: the eye
## sits behind the shoulder at a fixed height and only the LOOK tilts. The stick
## then moves the crosshair and nothing else, which is the entire promise of a
## sight.
##
## `pitch_deg` rather than zero, so the stance settles onto the rig's own resting
## elevation and the blend in and out of it has nothing to travel at rest.
func _boom_pitch() -> float:
	return lerpf(_pitch, pitch_deg, _aim01)


## The at-point the boom actually pivots on: the hero's eye, slid toward his
## right shoulder and lifted a little, in proportion to the aim ease.
##
## The offset is taken in the ORBIT's frame rather than the camera's own basis,
## because the camera's basis is what this function is about to decide — reading
## it here would use last frame's, and the lag shows up as the crosshair swimming
## whenever the player turns.
func _aim_pivot() -> Vector3:
	if _aim01 <= 0.0:
		return _at
	# The boom's own yaw, +90°: the horizontal direction to the eye's right when
	# it is looking back down the boom at the hero.
	var yaw := _yaw + deg_to_rad(_swing_bias_deg)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return _at + right * (aim_shoulder * _aim01) + Vector3.UP * (aim_rise * _aim01)
