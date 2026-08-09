class_name Targeting
extends Node3D
## P3 — lock-on. A child of the Hero, built by `hero.gd`, reachable as
## `get_tree().get_first_node_in_group("player").targeting` (docs/CONTRACT.md §8).
##
## Everything downstream of this was already wired and had been dead since the
## project started: `Bus.target_acquired` / `Bus.target_lost` had no emitter,
## `GameCamera.set_target()` had no caller, and the HUD's reticle drew a target
## that was always null. `hero.targeting` resolved to null too, which is why
## `z_target` only ever recentred the camera. This is the missing piece.
##
## **It is a TOGGLE, not a hold**, and that is the deliberate departure from the
## Ocarina model the rest of the feel is built on. OOT holds Z because Z is an
## index finger on a shoulder. Elden Ring puts lock-on on R3, and you cannot hold
## a stick click and steer with the same thumb — a held R3 is not a control, it
## is a cramp. Press to lock, press again to let go, press with nothing lockable
## to recentre the camera behind the hero (which is the one OOT behaviour that
## survives, because ER does the same thing).
##
## Acquisition is scored in SCREEN space, not in hero space. The player's "that
## one" is the thing nearest the middle of the picture, and a body-space rule
## picks the goblin behind you over the one you are looking at.

## Mirrors of the Bus signals, for anything holding this node directly.
signal target_acquired(target: Node3D)
signal target_lost

## The locked target, or null. Read-only outside this script.
var current_target: Node3D = null
## True while a target is held. `current_target != null` says the same thing;
## both exist because docs/CONTRACT.md §8 promises both.
var is_locked: bool = false

@export_group("Acquisition")
## [oot] ATTENTION_RANGE_3. Acquire inside this, break outside LOCK_BREAK_RANGE;
## the ~22% band between them is what stops the lock chattering at the edge.
@export var range_acquire: float = K.LOCK_RANGE
@export var range_break: float = K.LOCK_BREAK_RANGE
## Half-angle of the forward search cone, measured from the CAMERA.
@export var cone_acquire: float = K.LOCK_CONE
## Once locked, switching widens the cone — you can flick to something you can
## see but would not have acquired from a standing start.
@export var cone_switch: float = K.LOCK_SWITCH_CONE
## Metres of distance worth one degree of screen angle when scoring candidates.
## Small: angle dominates, and distance only breaks near-ties.
@export var distance_weight: float = 1.6
## Chest height, used when a targetable does not implement `target_point()`.
@export var default_target_height: float = 1.0

@export_group("Break")
## Seconds the lock survives with the target out of sight. A lock that drops the
## instant a pillar crosses the line is worse than no lock — you fight the camera
## instead of the enemy — and one that never drops lets you track through walls.
@export var los_grace: float = 0.7

@export_group("Switching")
## Right-stick deflection that counts as a flick, and the value it must fall
## back under before another flick is allowed. Without the second number a held
## stick walks the target across the room one frame at a time.
@export var flick_on: float = 0.7
@export var flick_off: float = 0.35

var _hero: Node3D = null
var _los_lost: float = 0.0
var _flick_armed: bool = true
## Set by _unhandled_input, consumed in _physics_process. The press must not be
## read by polling: `is_action_just_pressed` is true for exactly one frame and
## is stamped with the frame it arrived in, so a physics tick slower than the
## render rate drops it outright. Prompt's `_armed` flag carries a longer note
## on the same hazard.
var _toggle_queued: bool = false
## -1 switch left, +1 switch right, 0 none. Same reasoning as above.
var _switch_queued: int = 0

var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_hero = get_parent() as Node3D
	if _hero == null:
		push_error("Targeting must be a child of the Hero")
		return
	_ray.collision_mask = K.L_WORLD
	_ray.collide_with_areas = false
	set_physics_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if Prompt != null and Prompt.blocked:
		return
	if event.is_action_pressed(&"z_target"):
		_toggle_queued = true
		get_viewport().set_input_as_handled()
		return
	# The mouse's target switch. Bound here rather than as an input action
	# because a wheel notch is not a thing anyone would rebind, and registering
	# two more actions to carry it would put them in the options list.
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and is_locked:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_switch_queued = 1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_switch_queued = -1


func _physics_process(delta: float) -> void:
	if _hero == null:
		return

	if Prompt != null and Prompt.blocked:
		# A screen owning input must not eat a queued press and fire it when the
		# screen closes, so the queue is dropped rather than held.
		_toggle_queued = false
		_switch_queued = 0
		return

	if _toggle_queued:
		_toggle_queued = false
		_toggle()

	_read_stick_flick()

	if is_locked:
		if _switch_queued != 0:
			_switch(_switch_queued)
		_validate(delta)
	_switch_queued = 0


# --- The button -------------------------------------------------------------

func _toggle() -> void:
	if is_locked:
		_release()
		return
	var best := _best_candidate(cone_acquire, null)
	if best != null:
		_acquire(best)
	else:
		# Nothing lockable. This is OOT's Parallel recentre, and Elden Ring does
		# the same thing with an empty R3 — the button always does something.
		Bus.camera_recenter.emit()


func _acquire(t: Node3D) -> void:
	current_target = t
	is_locked = true
	_los_lost = 0.0
	target_acquired.emit(t)
	Bus.target_acquired.emit(t)


func _release() -> void:
	if not is_locked:
		return
	current_target = null
	is_locked = false
	_los_lost = 0.0
	target_lost.emit()
	Bus.target_lost.emit()


# --- Holding it -------------------------------------------------------------

## Drop the lock when the target stops being a thing worth locking. Death and
## despawn are checked first and hardest: `Enemy` leaves the `targetable` group
## as it dies, so the group is the authority on "still a target", not liveness.
func _validate(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		_release()
		return
	if not current_target.is_inside_tree() \
			or not current_target.is_in_group(&"targetable"):
		_release()
		return
	if _hero.global_position.distance_to(current_target.global_position) > range_break:
		_release()
		return

	# Line of sight is allowed to lapse briefly. See `los_grace`.
	if _has_los(current_target):
		_los_lost = 0.0
	else:
		_los_lost += delta
		if _los_lost >= los_grace:
			_release()


# --- Switching --------------------------------------------------------------

## A right-stick flick while locked moves the lock, it does not steer the
## camera. Re-arming on the way back through `flick_off` is what makes it one
## target per flick instead of a sweep across the whole room.
func _read_stick_flick() -> void:
	if not is_locked:
		_flick_armed = true
		return
	var x := Input.get_axis(&"cam_left", &"cam_right")
	if absf(x) < flick_off:
		_flick_armed = true
	elif _flick_armed and absf(x) >= flick_on:
		_flick_armed = false
		_switch_queued = 1 if x > 0.0 else -1


func _switch(dir: int) -> void:
	var next := _best_candidate(cone_switch, current_target, dir)
	if next != null:
		_acquire(next)


# --- Candidates -------------------------------------------------------------

## The best thing to lock, or null.
##
## `exclude` is the target we already hold. When `side` is non-zero the search is
## restricted to candidates on that side OF THAT TARGET on screen, which is what
## makes a flick right pick the next enemy rightward rather than the best one
## overall — that would just snap back to where it started.
func _best_candidate(cone_deg: float, exclude: Node3D, side: int = 0) -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null

	var cam_pos := cam.global_position
	var cam_fwd := -cam.global_transform.basis.z
	var origin := _hero.global_position
	var pivot_x := 0.0
	if side != 0 and exclude != null and is_instance_valid(exclude):
		if cam.is_position_behind(exclude.global_position):
			return null
		pivot_x = cam.unproject_position(exclude.global_position).x

	var best: Node3D = null
	var best_score := INF

	for node in get_tree().get_nodes_in_group(&"targetable"):
		var t := node as Node3D
		if t == null or t == exclude or t == _hero or not is_instance_valid(t):
			continue
		if _hero.is_ancestor_of(t):
			continue
		if origin.distance_to(t.global_position) > range_acquire:
			continue

		var point := target_point_of(t)
		if cam.is_position_behind(point):
			continue
		var to := point - cam_pos
		if to == Vector3.ZERO:
			continue
		var angle := rad_to_deg(cam_fwd.angle_to(to))
		if angle > cone_deg:
			continue
		if not _has_los(t):
			continue

		if side != 0:
			var sx := cam.unproject_position(point).x
			# A strict inequality, so a candidate stacked exactly on the current
			# target cannot be "the next one to the right" of itself.
			if side > 0 and sx <= pivot_x:
				continue
			if side < 0 and sx >= pivot_x:
				continue

		# Screen angle dominates; distance only separates near-ties. The player
		# means "that one", and "that one" is whatever is nearest the middle of
		# the picture they are looking at.
		var score := angle + origin.distance_to(t.global_position) * distance_weight
		if score < best_score:
			best_score = score
			best = t

	return best


## Where the reticle sits. docs/CONTRACT.md §8 asks every targetable for
## `target_point()`, and `training_post.gd` provides it — but the whole enemy
## roster predates that promise and does not, so the fallback is chest height
## rather than an error. A missing method must not make an enemy unlockable.
func target_point_of(t: Node3D) -> Vector3:
	if t.has_method(&"target_point"):
		return t.call(&"target_point") as Vector3
	return t.global_position + Vector3.UP * default_target_height


## Eye-to-chest, world geometry only. Enemy and player bodies are deliberately
## not in the mask: a crawler standing between you and the orc behind it should
## not make the orc unlockable, only a wall should.
func _has_los(t: Node3D) -> bool:
	_ray.from = _hero.global_position + Vector3.UP * K.HERO_EYE_Y
	_ray.to = target_point_of(t)
	_ray.exclude = [_hero.get_rid()] if _hero is CollisionObject3D else []
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(_ray).is_empty()
