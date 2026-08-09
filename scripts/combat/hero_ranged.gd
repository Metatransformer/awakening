class_name HeroRanged
extends Node3D
## The hero's two ranged items: the bow and the hookshot. Everything either of
## them needs that is not presentation — the aim, the raycast, the ammo, and the
## hookshot's ownership of the hero while he is being dragged through the air.
##
## A sibling of `HeroCombat` rather than more of it. HeroCombat is about the
## sword arm: the swing, the block cone, the sockets every model hangs off. What
## an arrow does after it leaves has nothing to do with any of that, and the one
## thing the two genuinely share — which item is in the right hand — already
## lives on `Game`, where it survives the scene change. HeroCombat still owns the
## attack BUTTON (one reader, docs/CONTRACT.md §4) and calls `fire()` when the
## hand holding it is not holding the sword.
##
## ## Aim comes from the camera, not from the body
##
## The hero's facing is a yaw. A hookshot that can only be aimed in yaw cannot
## reach a ceiling ring, which is most of what a hookshot is for. The camera is
## the only thing in this game that carries a player-controlled PITCH (`_pitch`,
## clamped to ±55° in game_camera.gd), so the camera's forward is the aim — the
## same source movement already reads (docs/CONTRACT.md §4, camera-relative).
## Locked on, both items override that and shoot the target, because that is the
## whole promise of the lock.
##
## ## Aim mode
##
## Because the aim IS the camera, drawing one of these has to change the camera,
## or the player is aiming a weapon with a rig framed for running around. Bringing
## either item out therefore raises `Bus.aim_changed(true)`: the boom drops to the
## hero's shoulder, the FOV narrows, the HUD puts a crosshair on the middle of the
## screen, and the hero turns to face wherever the lens is pointed. This node is
## the only emitter — it is the one place that knows what is in his hands.

## Seconds a shot owns the hero, and the fraction of that at which the arrow
## actually leaves. He is committed for the rest — a bow you can fire while
## running is a bow with no cost. [tune]
const BOW_TIME := 0.44
const BOW_RELEASE := 0.55
## How long the hookshot's firing POSE is scaled to run for. It is not a
## commitment window — `hook_begin()` takes the hero over on the same frame, and
## the chain's flight is the real commitment. This only decides how fast the
## clip plays. [tune]
const HOOK_FIRE_TIME := 0.34

## Half-angle of the hookshot's aim-assist cone, degrees. Generous on purpose: a
## HookTarget is an AUTHORED promise that this is the anchor that matters, and
## demanding pixel aim across a chasm is how a traversal item becomes a chore.
const HOOK_ASSIST_CONE := 22.0

## The two items that put the camera on the shoulder. A set rather than a pair of
## comparisons so adding a third — a slingshot, a wand — is one entry.
const AIMED: Array[StringName] = [&"bow", &"hookshot"]

var _hero: Hero
var _tether: HookshotTether

## True while a ranged item is in the right hand. Mirrored onto the Bus; kept
## here so a late listener (a HUD rebuilt on a scene change) can ask.
var aiming: bool = false

## Counts up through BOW_TIME while a shot is in flight, or -1.0 when idle.
var _bow_t: float = -1.0
var _bow_fired: bool = false
var _bow_dir: Vector3 = Vector3.FORWARD

## The chain is out. `_hook_bit` distinguishes a shot that found an anchor from
## one that played out to maximum range and found nothing — both draw the chain,
## only one moves the hero.
var _hook_active: bool = false
var _hook_bit: bool = false
var _hook_pull: Vector3 = Vector3.ZERO

var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("HeroRanged must be a child of the Hero")
		return
	_tether = HookshotTether.new()
	_tether.name = "Tether"
	_hero.add_child(_tether)

	Bus.loadout_changed.connect(_on_loadout_changed)
	# Deferred: the hero is still being built, and the camera and the HUD that
	# listen for this have not necessarily reached their own _ready yet. A stance
	# announced into an empty room leaves the camera framed for running while the
	# bow is already in his hand, which is exactly the bug this signal exists for.
	_refresh_aiming.call_deferred()


func _on_loadout_changed(_set_index: int, _right: StringName, _left: StringName) -> void:
	_refresh_aiming()


## The sighted item, or &"" for none — what the hero's stance is built from.
func aim_item() -> StringName:
	var held := Game.armament(Game.HAND_RIGHT)
	return held if AIMED.has(held) else &""


## Recompute the stance from what is actually equipped, and announce a change.
func _refresh_aiming() -> void:
	var want := AIMED.has(Game.armament(Game.HAND_RIGHT))
	if want == aiming:
		return
	aiming = want
	Bus.aim_changed.emit(aiming)


## Use whatever is in the right hand. Returns false when the press should be
## ignored — no ammo, nothing hookable, or a shot already in progress — so the
## caller does not play a noise for a shot that never happened.
func fire(id: StringName) -> bool:
	if _bow_t >= 0.0 or _hook_active:
		return false
	match id:
		&"bow": return _fire_bow()
		&"hookshot": return _fire_hookshot()
	return false


func busy() -> bool:
	return _bow_t >= 0.0 or _hook_active


# --- The bow ----------------------------------------------------------------

func _fire_bow() -> bool:
	if Game.arrows <= 0:
		# Deliberately audible, unlike an unbound button: you asked for a shot
		# with a bow you are holding, and silence there reads as a dropped input
		# rather than as an empty quiver.
		Bus.request_sfx.emit(&"craft_fail", _hero.global_position)
		return false
	_bow_dir = _aim_at_target_or_camera()
	if not _hero.request_ranged(BOW_TIME, _bow_dir):
		return false
	_bow_t = 0.0
	_bow_fired = false
	Bus.request_sfx.emit(&"bow_draw", _hero.global_position)
	return true


## The arrow leaves. Ammo is spent HERE and not on the press, so a shot
## interrupted before release costs nothing — the arrow that was never loosed is
## still in the quiver, which is the only reading that is not a lie.
func _release_arrow() -> void:
	_bow_fired = true
	if not Game.spend_ammo(&"arrows"):
		return
	# Re-aimed at release rather than reused from the press: the lock can move,
	# and half a second is long enough for a circling enemy to leave the line
	# the shot was aimed down.
	var dir := _aim_at_target_or_camera()
	var arrow := Arrow.new()
	arrow.name = "Arrow"
	# Parented to the scene, not to the hero. An arrow under the hero inherits
	# his yaw and his 1.65 scale, which would both bend the flight and render a
	# 1 m arrow.
	_scene_root().add_child(arrow)
	arrow.launch(_muzzle(&"bow"), dir, _hero)
	Bus.request_sfx.emit(&"bow_shoot", _hero.global_position)


# --- The hookshot -----------------------------------------------------------

func _fire_hookshot() -> bool:
	var from := _muzzle(&"hookshot")
	var aim := _camera_forward()
	var anchor := from + aim * K.HOOK_RANGE
	var pull := Vector3.ZERO
	var bit := false

	# An authored ring first. It is the designer saying "this one", and it wins
	# over whatever wall happens to be behind it.
	var ring := _best_hookable(from, aim)
	if ring != null:
		anchor = ring.anchor_point()
		pull = ring.pull_point()
		bit = true
	else:
		_query.from = from
		_query.to = from + aim * K.HOOK_RANGE
		_query.collision_mask = K.L_WORLD | K.L_HOOK
		_query.collide_with_bodies = true
		_query.collide_with_areas = false
		_query.exclude = [_hero.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(_query)
		if not hit.is_empty():
			anchor = hit["position"] as Vector3
			var normal := hit["normal"] as Vector3
			# Land ON the surface the head bit, standing off it along its own
			# normal. Without the stand-off the pull ends inside the wall and
			# move_and_slide spends the next second squeezing him back out.
			pull = anchor + normal * (K.HERO_RADIUS + 0.25)
			# A shot into a ceiling would otherwise leave him hanging in the air
			# under it; drop the landing to where his feet can be.
			if normal.y > 0.6:
				pull.y = anchor.y + 0.05
			elif normal.y < -0.6:
				pull = anchor + Vector3.DOWN * (K.HERO_H + 0.2)
			bit = true

	if not _hero.request_ranged(HOOK_FIRE_TIME, aim, true):
		return false

	_hook_active = true
	_hook_bit = bit
	_hook_pull = pull
	_hero.hook_begin()
	_tether.begin(from, anchor, pull)
	Bus.request_sfx.emit(&"crossbow_shoot", _hero.global_position)
	return true


## The `hookable` nearest the aim line, or null. Scored on ANGLE off the aim,
## not on distance: the player is pointing at something, and the nearest ring is
## regularly not the one they are looking at.
func _best_hookable(from: Vector3, aim: Vector3) -> HookTarget:
	var best: HookTarget = null
	var best_angle := HOOK_ASSIST_CONE
	for node in get_tree().get_nodes_in_group(&"hookable"):
		var ring := node as HookTarget
		if ring == null or not is_instance_valid(ring):
			continue
		var to := ring.anchor_point() - from
		var dist := to.length()
		if dist < 0.5 or dist > K.HOOK_RANGE:
			continue
		var angle := rad_to_deg(aim.angle_to(to))
		# The snap radius is the ring's own tolerance in METRES, converted to the
		# angle it subtends from here — a generous ring stays generous close up
		# and does not become a wall-sized target across the room.
		var allowed := minf(HOOK_ASSIST_CONE, rad_to_deg(atan2(ring.snap_radius, dist)) + 6.0)
		if angle > allowed or angle > best_angle:
			continue
		best_angle = angle
		best = ring
	return best


func _end_hook() -> void:
	_hook_active = false
	_hook_bit = false
	_tether.clear()


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _hero == null:
		return
	_tick_bow(delta)
	_tick_hook(delta)


func _tick_bow(delta: float) -> void:
	if _bow_t < 0.0:
		return
	_bow_t += delta
	if not _bow_fired and _bow_t >= BOW_TIME * BOW_RELEASE:
		_release_arrow()
	if _bow_t >= BOW_TIME:
		_bow_t = -1.0


func _tick_hook(delta: float) -> void:
	if not _hook_active:
		return
	var from := _muzzle(&"hookshot")

	if _tether.is_extending():
		if not _tether.advance(delta, from):
			return
		# The chain arrived. A shot that found nothing has now shown the player
		# exactly how far the hookshot reaches, which is the whole information
		# content of a miss; there is nothing left to do but let go.
		if not _hook_bit:
			_hero.hook_end()
			_end_hook()
			return
		Bus.request_sfx.emit(&"craft_clang", _tether.impact_position)
		_hero.hook_pull_to(_hook_pull)
		return

	# Travelling. The tether redraws from the moving hero, so the chain retracts
	# into the anchor with no second animation clock (see hookshot_tether.gd).
	_tether.update_pull(from)
	if not _hero.hooking():
		_end_hook()


# --- Aim --------------------------------------------------------------------

## Where the shot comes FROM. The real model if it is mounted and visible, so
## the chain leaves the hookshot's barrel rather than the hero's sternum; his
## eye line otherwise, which is what a director rendering a bare hero gets.
func _muzzle(id: StringName) -> Vector3:
	var model: Node3D = null
	if _hero.combat != null:
		model = _hero.combat.hookshot if id == &"hookshot" else _hero.combat.bow
	if model != null and model.is_inside_tree() and model.is_visible_in_tree():
		return model.global_position
	return _hero.global_position + Vector3.UP * K.HERO_EYE_Y \
		+ (-_hero.global_transform.basis.z) * 0.35


## The locked target's chest, else wherever the camera is pointed.
func _aim_at_target_or_camera(id: StringName = &"bow") -> Vector3:
	var muzzle := _muzzle(id)
	var target := _hero.lock_target()
	if target != null:
		var to := target.global_position + Vector3.UP * 0.9 - muzzle
		if to.length_squared() > 0.01:
			return to.normalized()
	return _aim_from(muzzle)


## The aim vector from `muzzle` toward whatever the camera is looking AT.
##
## Not parallel to the camera's forward — *convergent on its target*, and the
## difference is the difference between a bow that works and one that does not.
## The bow is held in the left hand and the hookshot in the right, so a muzzle
## sits ~0.6 m off the hero's centre line. Firing parallel meant every shot
## travelled its whole flight 0.6 m to one side of the thing the player had
## lined up: it missed a training post it was visibly pointed at, and that reads
## as the bow being broken rather than as an origin being offset.
##
## The fix is the one every third-person shooter uses. Ask the camera what its
## crosshair is actually over — one raycast down its ray — and aim the muzzle at
## that POINT. Exact at every distance, which a fixed convergence distance is
## not: converging at 8 m leaves a half-metre error on a target 2 m away, and
## point blank is exactly where a miss is least forgivable.
func _aim_from(muzzle: Vector3) -> Vector3:
	var fallback := -_hero.global_transform.basis.z
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return fallback
	var look := -cam.global_transform.basis.z
	if look.length_squared() < 0.0001:
		return fallback
	look = look.normalized()

	# Far enough to be past anything either item can reach, so an unobstructed
	# ray still yields a focus point rather than nothing.
	var reach := K.HOOK_RANGE * 2.0
	var focus := cam.global_position + look * reach
	_query.from = cam.global_position
	_query.to = focus
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT | K.L_HOOK
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	# The hero is between the camera and the crosshair. Without this the ray
	# stops on his own back and every shot aims at his shoulder blades.
	_query.exclude = [_hero.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		focus = hit["position"] as Vector3

	var to := focus - muzzle
	# Degenerate only when the crosshair is on something inside the muzzle.
	return to.normalized() if to.length_squared() > 0.0001 else fallback


## The aim for a hookshot shot, which leaves the barrel in his right hand.
##
## The lock wins here for the same reason it wins for the bow: holding a target
## and then having the chain sail past it because the crosshair was a few degrees
## off reads as the lock being decorative. The ring assist in `_best_hookable`
## still runs on top of whatever this returns, so an authored anchor beside the
## locked enemy is still the thing that gets grabbed.
func _camera_forward() -> Vector3:
	return _aim_at_target_or_camera(&"hookshot")


func _scene_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root
