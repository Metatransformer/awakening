class_name GameCamera
extends Node3D
## P1 — the third-person camera rig.
##
## Structure: this node is the PIVOT (it chases the hero's eye height), a
## SpringArm3D hangs off it (it owns wall collision), and the Camera3D sits at
## the end of the arm. Nothing else in the project moves the Camera3D directly.
##
## Three facts out of refs/REFERENCE.md this is built on:
##
##   1. **Dungeon cameras are tighter and flatter than outdoor ones** — 2.48 to
##      4.13 m at 5 degrees, not the 3.30-6.60 m at 10 degrees used outdoors.
##      K.CAM_DIST_MIN/MAX/PITCH. A boom at a "normal" 6 m third-person distance
##      is the single most common tell of a clone.
##   2. **FOV changes by mode** — 60 free, 50 locked onto a hostile, 45 parallel
##      and first-person. The zoom-in on lock is most of what sells the lock.
##   3. **A tap of Z with no target recentres** the camera behind the hero; a
##      hold with a target locks on. The hero emits `Bus.camera_recenter` for
##      the tap case (it owns the hold timing) and we answer it here.
##
## The rig runs in `_process`, not `_physics_process`: it is visual smoothing,
## and running it on the physics tick makes it judder at any framerate that is
## not an exact multiple of the tick rate.

## Metres the arm keeps between the camera and whatever it hits.
@export var collision_margin: float = 0.28
## Degrees/sec the right stick sweeps the camera.
@export var stick_speed: float = 180.0
## Degrees per pixel of mouse motion, before Settings.camera_sensitivity.
@export var mouse_speed: float = 0.16
## Seconds for a recentre to swing the camera behind the hero.
@export var recenter_time: float = 0.35
## Seconds the FOV takes to reach the mode's target.
@export var fov_blend: float = 0.18

var _pivot_target: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = K.CAM_PITCH
var _hero: Node3D = null
var _arm: SpringArm3D
var _cam: Camera3D
var _recenter_t: float = 0.0
var _recenter_from: float = 0.0
var _recenter_to: float = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	_arm = get_node_or_null(^"SpringArm3D") as SpringArm3D
	if _arm == null:
		_arm = SpringArm3D.new()
		_arm.name = "SpringArm3D"
		add_child(_arm)
	# The arm collides with world geometry only. Including the player layer here
	# is the classic mistake: the hero is always inside the boom, so the camera
	# would slam to the pivot every frame.
	_arm.collision_mask = K.L_WORLD
	_arm.spring_length = K.CAM_DIST_MAX
	_arm.margin = collision_margin

	_cam = _arm.get_node_or_null(^"Camera3D") as Camera3D
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "Camera3D"
		_arm.add_child(_cam)
	_cam.fov = K.CAM_FOV
	_cam.current = true
	_cam.near = 0.08

	Bus.camera_recenter.connect(_on_recenter)
	Bus.player_spawned.connect(_on_player_spawned)
	# The hero may already be in the tree — player_spawned fired before we
	# connected. Look for him rather than waiting for a signal that has passed.
	var p := get_tree().get_first_node_in_group(&"player")
	if p is Node3D:
		_on_player_spawned(p)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_player_spawned(p: Node3D) -> void:
	_hero = p
	_yaw = p.rotation.y
	_pivot_target = _eye()
	global_position = _pivot_target
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative
	elif event.is_action_pressed(&"pause"):
		# Hand the cursor back so a pause menu is clickable. Whoever owns the
		# menu re-captures on resume.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		return

	_aim(delta)
	_follow(delta)
	_apply_rotation()
	_blend_fov(delta)


# --- Aim --------------------------------------------------------------------

func _aim(delta: float) -> void:
	var sens: float = Settings.camera_sensitivity
	var invert: bool = Settings.invert_camera_y
	if sens <= 0.0:
		sens = 1.0

	# Mouse is a per-frame delta already; the stick is a rate.
	var yaw_d := -_mouse_delta.x * mouse_speed * sens
	var pitch_d := -_mouse_delta.y * mouse_speed * sens
	_mouse_delta = Vector2.ZERO

	var stick := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	yaw_d += -stick.x * stick_speed * sens * delta
	pitch_d += -stick.y * stick_speed * sens * delta

	if invert:
		pitch_d = -pitch_d

	if absf(yaw_d) > 0.0001 or absf(pitch_d) > 0.0001:
		# Any manual input cancels an in-flight recentre — fighting the player
		# for the stick is the worst thing a camera can do.
		_recenter_t = 0.0

	if _recenter_t > 0.0:
		_recenter_t = maxf(_recenter_t - delta, 0.0)
		var t := 1.0 - (_recenter_t / recenter_time)
		# Smoothstep, so the swing eases out instead of arriving at full speed.
		_yaw = lerp_angle(_recenter_from, _recenter_to, t * t * (3.0 - 2.0 * t))
	else:
		_yaw = wrapf(_yaw + deg_to_rad(yaw_d), -PI, PI)
		_autoswing(delta)

	_pitch = clampf(_pitch + pitch_d, K.CAM_MIN_PITCH, K.CAM_MAX_PITCH)


## While the hero runs and the player is not steering the camera, the rig drifts
## back behind him. K.CAM_AUTOSWING. This is what stops a third-person camera
## from needing constant manual correction.
func _autoswing(delta: float) -> void:
	var v: Vector3 = _hero.velocity if _hero is CharacterBody3D else Vector3.ZERO
	var planar := Vector2(v.x, v.z).length()
	if planar < K.WALK_SPEED:
		return
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	var behind := _hero.rotation.y
	_yaw = lerp_angle(_yaw, behind, clampf(K.CAM_AUTOSWING * speed01 * delta, 0.0, 1.0))


func _on_recenter() -> void:
	if _hero == null:
		return
	_recenter_from = _yaw
	# The hero's body faces -Z, and rotation.y already carries the +PI the hero
	# applies (see hero.gd _after_move), so "behind him" is simply his yaw.
	_recenter_to = _hero.rotation.y
	_recenter_t = recenter_time


# --- Follow -----------------------------------------------------------------

func _eye() -> Vector3:
	return _hero.global_position + Vector3.UP * K.HERO_EYE_Y


func _follow(delta: float) -> void:
	_pivot_target = _eye()
	# Exponential damping expressed as a half-life, so the feel is identical at
	# 60 and 144 fps. A raw `lerp(a, b, speed * delta)` is framerate-dependent.
	var k := 1.0 - exp(-delta / maxf(K.CAM_LAG, 0.001))
	global_position = global_position.lerp(_pivot_target, k)

	# Lock-on pulls the boom in a little so both fighters stay framed.
	var want := K.CAM_DIST_MAX
	if _locked_target() != null:
		want = lerpf(K.CAM_DIST_MIN, K.CAM_DIST_MAX, 0.45)
	_arm.spring_length = lerpf(_arm.spring_length, want, k)


func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	# Pitch lives on the arm so the pivot stays a clean yaw-only frame — the
	# hero reads the camera basis for movement and only wants its yaw.
	_arm.rotation = Vector3(deg_to_rad(-_pitch), 0.0, 0.0)


# --- FOV --------------------------------------------------------------------

func _locked_target() -> Node3D:
	var t: Object = _hero.get(&"targeting")
	if t == null:
		return null
	if not bool(t.get(&"is_locked")):
		return null
	return t.get(&"current_target") as Node3D


func _blend_fov(delta: float) -> void:
	var want := K.CAM_FOV
	if _locked_target() != null:
		want = K.CAM_FOV_LOCK
	elif Input.is_action_pressed(&"z_target"):
		# Z held with nothing to lock: OOT's "parallel" mode.
		want = K.CAM_FOV_PARALLEL

	# [oot] the view squeezes in at one heart or less.
	if Game.max_quarters > 0 and Game.quarters <= K.HEART:
		want *= K.CAM_FOV_LOW_HEALTH

	want += Settings.fov_offset
	var k := 1.0 - exp(-delta / maxf(fov_blend, 0.001))
	_cam.fov = lerpf(_cam.fov, want, k)


## Where the camera actually is, for anything that needs to aim from the view.
func camera() -> Camera3D:
	return _cam
