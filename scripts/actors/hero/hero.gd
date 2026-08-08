class_name Hero
extends CharacterBody3D
## P2 — the hero. Camera-relative locomotion on the OOT model.
##
## The three facts this is built on (refs/REFERENCE.md §3, docs/CONTRACT.md §2.5):
##
##   1. **There is no walk/run threshold.** Speed is a continuous curve of stick
##      magnitude — `K.speed_for_stick()`. The walk<->run *animation* is a blend
##      driven by speed, not a state transition. Nothing here branches on "is
##      walking". §3.2
##   2. **Reversing is a distinct move.** Past ~135° off the current heading OOT
##      does not steer, it kills speed and re-orients — which is why a sharp
##      about-face feels like its own action. That is the `ss_180_turn_01` case.
##      §3.3
##   3. **The roll is faster than the run** (6.55 vs 4.37 m/s) and it commits.
##      It is ground-covering with a hard recovery, not a cancel. §3.4
##
## Movement is camera-relative: the raw stick vector is rotated by the ACTIVE
## camera's yaw before it becomes world motion (docs/CONTRACT.md §4). The hero
## reads `get_viewport().get_camera_3d()`, so it never imports P1's script.

## Fires as each foot plants. P11 (feel) connects this for footstep audio/dust.
signal footstep(world_pos: Vector3, speed01: float)
## Fires the frame the hero regains the floor. `fall_speed` is m/s downward.
signal landed(fall_speed: float)
## Fires as a roll starts, so P4/P11 can hang i-frames and a whoosh off it.
signal roll_started
signal roll_finished

## Fires when a swing's damage window opens, so P11 can hang a whoosh on it.
signal attack_started
## Fires when the hero is hurt, after the health component has taken it.
signal hurt(hit: Hit)

enum MoveState { GROUND, TURN180, ROLL, ROLL_RECOVER, ATTACK, HURT }

@export_group("Rig")
@export var hero_model: PackedScene = preload("res://assets/characters/hero.fbx")
@export var anim_library: AnimationLibrary = preload("res://assets/animations/hero_anims.res")
## The source mesh is 1.0 units tall. K.HERO_SCALE lifts it to adult height.
@export var model_scale: float = K.HERO_SCALE
## Yaw correction, degrees, aligning the rig's facing with the body's -Z.
##
## Measured, not derived: tools/scenes/_facing.tscn renders four copies of the
## rig at 0/90/180/270 playing the same clip, next to a post marking -Z. At 180
## the hero shows his back and runs at the post; every other offset is visibly
## wrong. This holds for the idles AND the locomotion clips — one constant does
## serve the whole library.
##
## (An earlier version blended this on speed, on the theory that idles and runs
## differed by ~52 deg. That came from sampling the `mixamorig_Hips` rotation
## TRACK, which measures the bone's local pose against its rest orientation, not
## where the character is looking. The render disagrees with it. If you are
## tempted to reintroduce a per-clip correction, re-run _facing.tscn with that
## clip first — the image settles it in one frame.)
@export var model_yaw_offset: float = 180.0

@export_group("Locomotion")
@export var accel: float = K.ACCEL
@export var decel: float = K.DECEL
## Degrees/sec the body swings onto its heading. [tune] K.TURN_RATE.
@export var turn_rate: float = K.TURN_RATE
@export var gravity: float = K.GRAVITY
## Grace after leaving the floor before we treat the hero as properly airborne.
@export var coyote_time: float = 0.10
## [oot] Past this angle a reversal stops steering and becomes a 180. §3.3
@export var turnaround_angle_deg: float = 135.0
## Fraction of the run cap the hero must be carrying for a reversal to become a
## full 180 rather than an ordinary pivot.
@export var turnaround_min_speed01: float = 0.45
@export var turn180_time: float = 0.30

@export_group("Roll")
@export var roll_speed: float = K.ROLL_SPEED
@export var roll_time: float = K.ROLL_TIME
## The hard recovery. Input is locked and speed bleeds off through it.
@export var roll_recover_time: float = 0.20
## [oot] roll/backflip/sidehop need a near-full stick deflection. §3.2
@export var roll_stick_gate: float = K.STICK_ACTION_GATE

@export_group("Attack")
## Total length of a swing, input-locked. Shorter than the source clip, which
## is compressed onto it by a TimeScale the same way the roll is.
@export var attack_time: float = 0.52
## Fraction of the swing the damage window opens and closes at. The blade only
## hurts between these — a hitbox that is live for the whole animation lets a
## player walk into an enemy and win, which is what makes clone combat feel bad.
@export var attack_hit_open: float = 0.28
@export var attack_hit_close: float = 0.62
## Metres the swing carries the hero forward. Small: it closes the last step of
## a gap, it is not a lunge attack.
@export var attack_step_speed: float = 2.6
## Centre of the damage volume, in metres ahead of and above the hero's origin.
@export var attack_reach: float = 1.15
@export var attack_height: float = 0.95
@export var attack_radius: float = 0.85

@export_group("Weapon socket")
## Bone the blade hangs off. Verified with tools/scenes/_rig_facts.tscn.
@export var grip_bone: StringName = &"mixamorig_RightHand"
## Local offset and rotation of the blade inside the grip.
##
## MEASURED BY RENDER, not derived (docs/CONTRACT.md §8): the rest pose numbers
## are in a rotated FBX space and reading them analytically gives a sword that
## floats beside the fist at a plausible-looking wrong angle. Change these by
## rendering tools/scenes/_weapon_lookdev.tscn, looking, and adjusting.
@export var grip_offset: Vector3 = Vector3(0.0, 0.045, 0.02)
@export var grip_rotation_deg: Vector3 = Vector3(-78.0, 0.0, 0.0)

@export_group("Animation")
@export var clip_idle: StringName = &"ss_idle_01"
@export var clip_walk: StringName = &"ss_walk_01"
@export var clip_run: StringName = &"ss_run_01"
@export var clip_roll: StringName = &"ex_roll_to_run"
@export var clip_turn180: StringName = &"ss_180_turn_01"
@export var clip_air: StringName = &"ss_jump_01"
@export var clip_land: StringName = &"ss_jump_02"
@export var clip_slash: StringName = &"ss_slash_01"
@export var clip_impact: StringName = &"ss_impact_01"
## Speeds, in m/s, the walk and run clips are authored to read as.
@export var walk_blend_speed: float = K.WALK_SPEED
@export var run_blend_speed: float = K.RUN_SPEED
## Playback rate applied to the locomotion blend at a standstill and at the run
## cap. Keeps the feet from skating at in-between speeds.
@export var stride_scale_idle: float = 1.0
@export var stride_scale_run: float = 1.06

@export_group("Footsteps")
## Metres of ground covered per footfall at walk speed and at the run cap.
@export var stride_walk: float = 0.72
@export var stride_run: float = 1.55

## Set by P3 when it parents a targeting node under the hero. Read-only here.
## docs/CONTRACT.md §8 — `get_first_node_in_group("player").targeting`.
var targeting: Node = null

## The hero's health, proxying onto Game so it survives a scene change.
var health: HealthComponent = null

var state: MoveState = MoveState.GROUND
var facing_yaw: float = 0.0

var _model: Node3D
var _rig: Node3D
var _anim_player: AnimationPlayer
var _tree: AnimationTree
var _state_timer: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
var _airborne_time: float = 0.0
var _stride_accum: float = 0.0
var _z_hold: float = 0.0
var _speed: float = 0.0

var _grip: BoneAttachment3D
var _blade: Node3D
var _hitbox: DamageArea
var _swing_open: bool = false
var _knockback: Vector3 = Vector3.ZERO

const _P_BLEND := "parameters/Loco/blend_position"
const _P_STRIDE := "parameters/LocoScale/scale"
const _P_ROLL_SCALE := "parameters/RollScale/scale"
const _P_TURN := "parameters/Turn180/request"
const _P_AIR := "parameters/Air/request"
const _P_ROLL := "parameters/Roll/request"
const _P_LAND := "parameters/Land/request"
const _P_SLASH := "parameters/Slash/request"
const _P_SLASH_SCALE := "parameters/SlashScale/scale"
const _P_IMPACT := "parameters/Impact/request"


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = K.L_PLAYER
	collision_mask = K.L_WORLD
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_block_on_wall = false
	slide_on_ceiling = true
	up_direction = Vector3.UP

	# `facing_yaw` is the HEADING yaw: heading == (sin y, 0, cos y). Godot's node
	# forward is -Z, so the body is rotated by yaw + PI and every other package
	# can read the hero's facing as -global_transform.basis.z like any Node3D.
	facing_yaw = rotation.y + PI
	_build_rig()
	_build_anim_tree()
	_build_weapon()
	_build_combat()
	_build_key_light()
	targeting = find_child("Targeting", false, false)
	Bus.player_spawned.emit(self)


# --- Rig --------------------------------------------------------------------

func _build_rig() -> void:
	_model = get_node_or_null(^"Model") as Node3D
	if _model == null:
		_model = Node3D.new()
		_model.name = "Model"
		add_child(_model)
	_model.scale = Vector3.ONE * model_scale
	_model.rotation.y = deg_to_rad(model_yaw_offset)

	_rig = hero_model.instantiate() as Node3D
	_rig.name = "Rig"
	_model.add_child(_rig)

	_anim_player = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		push_error("hero: rig has no AnimationPlayer")
		return
	# The imported FBX ships a stub "" library holding only the T-pose. Evict it
	# so the merged 72-clip library owns the unprefixed namespace.
	# (docs/CONTRACT.md §2)
	if _anim_player.has_animation_library(&""):
		_anim_player.remove_animation_library(&"")
	_anim_player.add_animation_library(&"", anim_library)


## Built in code rather than stored in the .tscn: the animation library is only
## bound at runtime (above), so an editor-authored tree would have no clips to
## reference and every blend point would show as broken.
func _build_anim_tree() -> void:
	if _anim_player == null:
		return
	var tree_root := AnimationNodeBlendTree.new()

	# idle -> walk -> run, blended on ground speed in m/s. §3.2: continuous.
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = run_blend_speed
	loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	loco.add_blend_point(_anim_node(clip_idle), 0.0, -1, &"idle")
	loco.add_blend_point(_anim_node(clip_walk), walk_blend_speed, -1, &"walk")
	loco.add_blend_point(_anim_node(clip_run), run_blend_speed, -1, &"run")
	tree_root.add_node(&"Loco", loco, Vector2(0, 0))

	var stride := AnimationNodeTimeScale.new()
	tree_root.add_node(&"LocoScale", stride, Vector2(220, 0))
	tree_root.connect_node(&"LocoScale", 0, &"Loco")

	# One-shots layered over the locomotion, cheapest first. Land is last so a
	# landing always reads over whatever else is still fading out.
	var prev := &"LocoScale"
	prev = _add_oneshot(tree_root, &"Turn180", prev, _anim_node(clip_turn180), Vector2(440, 0), 0.10, 0.22)
	prev = _add_oneshot(tree_root, &"Air", prev, _anim_node(clip_air), Vector2(660, 0), 0.10, 0.18)

	var roll_anim := _anim_node(clip_roll)
	var roll_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"RollAnim", roll_anim, Vector2(660, 200))
	tree_root.add_node(&"RollScale", roll_scale, Vector2(820, 200))
	tree_root.connect_node(&"RollScale", 0, &"RollAnim")
	var roll_shot := AnimationNodeOneShot.new()
	roll_shot.fadein_time = 0.05
	roll_shot.fadeout_time = 0.16
	tree_root.add_node(&"Roll", roll_shot, Vector2(880, 0))
	tree_root.connect_node(&"Roll", 0, prev)
	tree_root.connect_node(&"Roll", 1, &"RollScale")
	prev = &"Roll"

	# The swing, compressed onto attack_time by its own TimeScale exactly the
	# way the roll is. Layered ABOVE the roll so a swing always reads over
	# locomotion, and below Land so a landing still wins.
	var slash_anim := _anim_node(clip_slash)
	var slash_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"SlashAnim", slash_anim, Vector2(880, 400))
	tree_root.add_node(&"SlashScale", slash_scale, Vector2(1000, 400))
	tree_root.connect_node(&"SlashScale", 0, &"SlashAnim")
	var slash_shot := AnimationNodeOneShot.new()
	slash_shot.fadein_time = 0.04
	slash_shot.fadeout_time = 0.14
	tree_root.add_node(&"Slash", slash_shot, Vector2(1060, 0))
	tree_root.connect_node(&"Slash", 0, prev)
	tree_root.connect_node(&"Slash", 1, &"SlashScale")
	prev = &"Slash"

	prev = _add_oneshot(tree_root, &"Impact", prev, _anim_node(clip_impact), Vector2(1280, 0), 0.05, 0.18)
	prev = _add_oneshot(tree_root, &"Land", prev, _anim_node(clip_land), Vector2(1500, 0), 0.06, 0.20)
	tree_root.connect_node(&"output", 0, prev)

	_tree = AnimationTree.new()
	_tree.name = "AnimTree"
	add_child(_tree)
	_tree.tree_root = tree_root
	_tree.anim_player = _tree.get_path_to(_anim_player)
	# The library's tracks are authored relative to the FBX root ("Skeleton3D:
	# mixamorig_*"), so the mixer has to resolve from the rig, not from the hero.
	_tree.root_node = _tree.get_path_to(_rig)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_tree.active = true

	# Compress ex_roll_to_run (1.4 s of roll + recovery-into-run) onto our roll.
	var roll_len := 1.0
	if anim_library.has_animation(clip_roll):
		roll_len = anim_library.get_animation(clip_roll).length
	_tree.set(_P_ROLL_SCALE, roll_len / maxf(roll_time + roll_recover_time, 0.05))

	# Same trick for the swing: ss_slash_01 is 1.5 s of wind-up, cut and
	# recovery. Played at native speed the hero telegraphs for most of a second
	# and the fight goes to sleep.
	var slash_len := 1.0
	if anim_library.has_animation(clip_slash):
		slash_len = anim_library.get_animation(clip_slash).length
	_tree.set(_P_SLASH_SCALE, slash_len / maxf(attack_time, 0.05))

	_tree.set(_P_BLEND, 0.0)
	_tree.set(_P_STRIDE, 1.0)


func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


func _add_oneshot(tree_root: AnimationNodeBlendTree, id: StringName, base: StringName,
		shot: AnimationNode, pos: Vector2, fade_in: float, fade_out: float) -> StringName:
	var anim_id := StringName(String(id) + "Anim")
	tree_root.add_node(anim_id, shot, pos + Vector2(0, 200))
	var one := AnimationNodeOneShot.new()
	one.fadein_time = fade_in
	one.fadeout_time = fade_out
	tree_root.add_node(id, one, pos)
	tree_root.connect_node(id, 0, base)
	tree_root.connect_node(id, 1, anim_id)
	return id


# --- Weapon and combat ------------------------------------------------------

## Hang the blade off the grip bone.
##
## Structure is Skeleton3D -> BoneAttachment3D("Grip") -> Node3D("Socket") ->
## blade. The Socket exists because BoneAttachment3D overwrites its OWN local
## transform from the bone pose every frame — an offset written onto the
## attachment itself is silently discarded, which reads as "the offset export
## does nothing" and sends you looking for a bug in the wrong place.
func _build_weapon() -> void:
	var skel := _rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		push_error("hero: no Skeleton3D — cannot mount a weapon")
		return
	var idx := skel.find_bone(String(grip_bone))
	if idx < 0:
		push_error("hero: no bone '%s' on the rig" % grip_bone)
		return

	_grip = BoneAttachment3D.new()
	_grip.name = "Grip"
	_grip.bone_name = String(grip_bone)
	_grip.bone_idx = idx
	skel.add_child(_grip)

	var socket := Node3D.new()
	socket.name = "Socket"
	socket.position = grip_offset
	socket.rotation = Vector3(
		deg_to_rad(grip_rotation_deg.x),
		deg_to_rad(grip_rotation_deg.y),
		deg_to_rad(grip_rotation_deg.z))
	# The whole rig is scaled by K.HERO_SCALE, so anything parented inside it
	# inherits that. The weapon GLBs are already native metres (a 0.92 m sword),
	# so undo the character scale or the hero swings a 1.5 m greatsword.
	socket.scale = Vector3.ONE / maxf(model_scale, 0.001)
	_grip.add_child(socket)

	_equip_blade(Game.blade_tier)
	Bus.gear_changed.connect(_on_gear_changed)


func _equip_blade(tier: int) -> void:
	if _grip == null:
		return
	var socket := _grip.get_node_or_null(^"Socket") as Node3D
	if socket == null:
		return
	if _blade != null and is_instance_valid(_blade):
		_blade.queue_free()
	_blade = WeaponModels.make(String(Gear.blade_model(tier)))
	if _blade != null:
		socket.add_child(_blade)


func _on_gear_changed(track: int, tier: int) -> void:
	if track == int(Gear.Track.BLADE):
		_equip_blade(tier)


func _build_combat() -> void:
	health = HealthComponent.new()
	health.name = "Health"
	health.use_game_state = true
	health.use_iframes = true
	add_child(health)
	health.damaged.connect(_on_damaged)

	_hitbox = DamageArea.new()
	_hitbox.name = "SwordHitbox"
	_hitbox.collision_layer = K.L_PLAYER_HITBOX
	_hitbox.collision_mask = K.L_ENEMY
	_hitbox.kind = &"sword"
	# The body's -Z is the heading (see _after_move), so "in front" is -Z.
	_hitbox.position = Vector3(0.0, attack_height, -attack_reach)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = attack_radius
	col.shape = sphere
	_hitbox.add_child(col)
	add_child(_hitbox)


## A small warm lamp riding above and slightly in front of the hero.
##
## The dungeon's lighting rule is "torches make pools, ambient stays near zero"
## (assets/materials/env_dungeon.tres), and that rule is right for the ROOM. It
## is wrong for the character: between two torch pools the hero renders as a
## featureless black cut-out, and you cannot read a swing you cannot see. This
## is short-range and dim enough that it never lights a wall — it lights him,
## and whatever he is standing next to.
func _build_key_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "KeyLight"
	lamp.light_color = Color(1.0, 0.92, 0.82)
	lamp.light_energy = 1.5
	lamp.omni_range = 3.2
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 1.9, -0.6)
	add_child(lamp)


func _on_damaged(hit: Hit) -> void:
	_close_swing()
	var dir := K.flat(global_position - hit.from)
	if dir == Vector3.ZERO:
		dir = -_forward()
	_knockback = dir * maxf(hit.knockback, 1.0)
	state = MoveState.HURT
	_state_timer = maxf(hit.stun, 0.20)
	_speed = 0.0
	_fire(_P_IMPACT)
	Bus.request_shake.emit(0.35, 0.18)
	hurt.emit(hit)


func _close_swing() -> void:
	if _swing_open:
		_hitbox.deactivate()
		_swing_open = false


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mag := clampf(stick.length(), 0.0, 1.0)
	var wish := _camera_relative(stick)

	_track_z_target(delta)

	match state:
		MoveState.GROUND:
			_tick_ground(wish, mag, delta)
		MoveState.TURN180:
			_tick_turn180(delta)
		MoveState.ROLL:
			_tick_roll(delta)
		MoveState.ROLL_RECOVER:
			_tick_roll_recover(delta)
		MoveState.ATTACK:
			_tick_attack(delta)
		MoveState.HURT:
			_tick_hurt(delta)

	_apply_gravity(delta)
	var pre_fall := velocity.y
	move_and_slide()
	_after_move(pre_fall, delta)
	_drive_animation(delta)


## The one rule that makes a third-person game feel right: the stick is read in
## SCREEN space and rotated by the live camera's yaw. Never world axes.
func _camera_relative(stick: Vector2) -> Vector3:
	if stick == Vector2.ZERO:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return K.flat(Vector3(stick.x, 0.0, stick.y))
	var basis := cam.global_transform.basis
	var fwd := K.flat(-basis.z)
	var right := K.flat(basis.x)
	if fwd == Vector3.ZERO:
		# Camera aimed straight down: fall back to its up vector on the plane.
		fwd = K.flat(basis.y)
	# Stick +Y is "down" on the pad, so forward is -stick.y.
	return K.flat(right * stick.x - fwd * stick.y)


func _track_z_target(delta: float) -> void:
	if Input.is_action_just_pressed(&"z_target"):
		_z_hold = 0.0
	elif Input.is_action_pressed(&"z_target"):
		_z_hold += delta
	elif Input.is_action_just_released(&"z_target"):
		# A TAP of Z with nothing lockable is OOT's recentre. Whether a lock
		# exists is P3's call; until it lands, `targeting` is null and every tap
		# recentres. docs/CONTRACT.md §4, refs/REFERENCE.md §1.7.
		var locked: bool = targeting != null and bool(targeting.get(&"is_locked"))
		if _z_hold <= 0.28 and not locked:
			Bus.camera_recenter.emit()
		_z_hold = 0.0


# --- States -----------------------------------------------------------------

func _tick_ground(wish: Vector3, mag: float, delta: float) -> void:
	if _try_start_attack(wish):
		return
	if _try_start_roll(wish, mag):
		return

	# [oot] §3.2 — a continuous curve of stick magnitude, no walk/run branch.
	var target_speed := K.speed_for_stick(mag)
	var moving := target_speed > 0.0

	if moving and _speed > K.RUN_SPEED * turnaround_min_speed01:
		var away := absf(rad_to_deg(wrapf(atan2(wish.x, wish.z) - facing_yaw, -PI, PI)))
		if away >= turnaround_angle_deg:
			_start_turn180(wish)
			return

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_steer_to(wish, turn_rate, delta)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)

	_set_planar_velocity(_forward() * _speed)


func _try_start_roll(wish: Vector3, mag: float) -> bool:
	if not Input.is_action_just_pressed(&"context"):
		return false
	if not is_on_floor():
		return false
	# [oot] a discrete action needs a near-full deflection — you cannot roll out
	# of a walk, only out of a committed run. §3.2 / K.STICK_ACTION_GATE.
	if mag < roll_stick_gate or wish == Vector3.ZERO:
		return false
	state = MoveState.ROLL
	_state_timer = roll_time
	_roll_dir = wish
	facing_yaw = atan2(wish.x, wish.z)
	_speed = roll_speed
	_set_planar_velocity(_roll_dir * roll_speed)
	_fire(_P_ROLL)
	roll_started.emit()
	return true


## A swing. Unlike the roll this needs no stick deflection — you must be able to
## attack from a standstill — but it does snap the hero onto his input direction
## first, so you hit what you are pointing at rather than what you last faced.
func _try_start_attack(wish: Vector3) -> bool:
	if not Input.is_action_just_pressed(&"attack"):
		return false
	if not is_on_floor():
		return false
	if wish != Vector3.ZERO:
		facing_yaw = atan2(wish.x, wish.z)
	state = MoveState.ATTACK
	_state_timer = 0.0
	_swing_open = false
	# Read the blade tier at swing time, so a purchase takes effect on the very
	# next attack without anything having to push a value into the hero.
	_hitbox.amount = Gear.blade_damage(Game.blade_tier)
	_hitbox.knockback = K.KNOCKBACK_LIGHT + float(Game.blade_tier) * 0.8
	_fire(_P_SLASH)
	attack_started.emit()
	return true


func _tick_attack(delta: float) -> void:
	_state_timer += delta
	var t: float = _state_timer / maxf(attack_time, 0.01)

	# A short forward carry that dies off before the recovery, so the swing
	# closes a gap without turning into a dash.
	_speed = attack_step_speed * clampf(1.0 - t * 1.7, 0.0, 1.0)
	_set_planar_velocity(_forward() * _speed)

	if not _swing_open and t >= attack_hit_open and t < attack_hit_close:
		_swing_open = true
		_hitbox.activate()
	elif _swing_open and t >= attack_hit_close:
		_close_swing()

	if t >= 1.0:
		_close_swing()
		_speed = 0.0
		state = MoveState.GROUND


func _tick_hurt(delta: float) -> void:
	_state_timer -= delta
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	_set_planar_velocity(_knockback)
	if _state_timer <= 0.0:
		_knockback = Vector3.ZERO
		state = MoveState.GROUND


func _start_turn180(wish: Vector3) -> void:
	state = MoveState.TURN180
	_state_timer = turn180_time
	_roll_dir = wish
	_fire(_P_TURN)


func _tick_turn180(delta: float) -> void:
	_state_timer -= delta
	# [oot] §3.3 — the reversal does not steer, it kills speed and re-orients.
	_speed = move_toward(_speed, 0.0, decel * 2.5 * delta)
	_steer_to(_roll_dir, turn_rate * 1.4, delta)
	_set_planar_velocity(_forward() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND


func _tick_roll(delta: float) -> void:
	_state_timer -= delta
	_speed = roll_speed
	_set_planar_velocity(_roll_dir * roll_speed)
	if _state_timer <= 0.0:
		state = MoveState.ROLL_RECOVER
		_state_timer = roll_recover_time


## The hard recovery. OOT's roll commits — you cannot cancel it into a run, and
## that is exactly why it reads as a move and not as a dodge-cancel.
func _tick_roll_recover(delta: float) -> void:
	_state_timer -= delta
	_speed = move_toward(_speed, 0.0, decel * 1.6 * delta)
	_set_planar_velocity(_forward() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND
		roll_finished.emit()


# --- Helpers ----------------------------------------------------------------

func _forward() -> Vector3:
	return Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))


func _steer_to(dir: Vector3, rate_deg: float, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var want := atan2(dir.x, dir.z)
	var err := wrapf(want - facing_yaw, -PI, PI)
	var step := deg_to_rad(rate_deg) * delta
	facing_yaw += clampf(err, -step, step)


func _set_planar_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		# A whisker of downward bias so floor_snap_length keeps him welded to
		# the ledge steps instead of launching off each one.
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta


func _after_move(pre_fall: float, delta: float) -> void:
	if is_on_floor():
		if _airborne_time > coyote_time:
			var fall := absf(minf(pre_fall, 0.0))
			landed.emit(fall)
			if fall > 2.5:
				_fire(_P_LAND)
		_airborne_time = 0.0
	else:
		var was := _airborne_time
		_airborne_time += delta
		if was <= coyote_time and _airborne_time > coyote_time:
			_fire(_P_AIR)

	rotation.y = facing_yaw + PI
	_emit_footsteps(delta)


## Distance-driven rather than animation-driven: the shared 72-clip library is
## read-only (docs/CONTRACT.md §2), so it carries no Call Method tracks we could
## key a footfall to. Accumulating ground covered gives the same cadence, scales
## with speed for free, and stays deterministic for screenshots.
func _emit_footsteps(delta: float) -> void:
	if not is_on_floor() or state == MoveState.ROLL:
		_stride_accum = 0.0
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < K.WALK_SPEED * 0.35:
		_stride_accum = 0.0
		return
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	_stride_accum += planar * delta
	var stride := lerpf(stride_walk, stride_run, speed01)
	if _stride_accum >= stride:
		_stride_accum -= stride
		footstep.emit(global_position, speed01)


func _fire(param: String) -> void:
	if _tree != null:
		_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _drive_animation(delta: float) -> void:
	if _tree == null:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	_tree.set(_P_BLEND, clampf(planar, 0.0, run_blend_speed))
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	_tree.set(_P_STRIDE, lerpf(stride_scale_idle, stride_scale_run, speed01))

	# The rig's yaw correction is a fixed 180 (see model_yaw_offset) and is set
	# once in _build_rig — it does not vary with speed.
