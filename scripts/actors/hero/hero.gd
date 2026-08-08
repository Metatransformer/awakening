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

enum MoveState { GROUND, TURN180, ROLL, ROLL_RECOVER, ATTACK }

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
## The roll is the i-frame button (roll grants K.ROLL_IFRAMES). Free i-frames
## make it the only button anyone presses, so it costs. See K.MAX_STAMINA.
@export var roll_stamina: float = K.STAMINA_ROLL

@export_group("Animation")
@export var clip_idle: StringName = &"ss_idle_01"
@export var clip_walk: StringName = &"ss_walk_01"
@export var clip_run: StringName = &"ss_run_01"
@export var clip_roll: StringName = &"ex_roll_to_run"
@export var clip_turn180: StringName = &"ss_180_turn_01"
@export var clip_air: StringName = &"ss_jump_01"
@export var clip_land: StringName = &"ss_jump_02"
@export var clip_attack: StringName = &"ss_slash_01"
@export var clip_block: StringName = &"ss_block_idle_01"
## Seconds the shield takes to come up and go down. Fast enough to be a
## reaction, slow enough that you can see it happen.
@export var block_fade: float = 0.12
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

var state: MoveState = MoveState.GROUND
var facing_yaw: float = 0.0
## Set by HeroCombat while the shield button is held. Read-only elsewhere.
var blocking: bool = false

## The sword, shield and swing. Built in _ready; other packages reach combat
## through the hero rather than reaching into the scene tree for it.
var combat: HeroCombat = null

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
## Seconds of damage immunity left. See take_hit().
var _invuln: float = 0.0

const _P_BLEND := "parameters/Loco/blend_position"
const _P_STRIDE := "parameters/LocoScale/scale"
const _P_ROLL_SCALE := "parameters/RollScale/scale"
const _P_TURN := "parameters/Turn180/request"
const _P_AIR := "parameters/Air/request"
const _P_ROLL := "parameters/Roll/request"
const _P_LAND := "parameters/Land/request"
const _P_ATTACK := "parameters/Attack/request"
const _P_ATTACK_SCALE := "parameters/AttackScale/scale"
const _P_BLOCK := "parameters/Block/blend_amount"


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
	targeting = find_child("Targeting", false, false)

	# The sword and shield live in their own node, but the hero owns their
	# lifetime so every scene that spawns a hero gets an armed one.
	combat = HeroCombat.new()
	combat.name = "Combat"
	add_child(combat)

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

	# The shield is a HELD pose, so it blends rather than fires: a one-shot would
	# end on its own while the button is still down.
	var block_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"BlockAnim", _anim_node(clip_block), Vector2(1000, 200))
	tree_root.add_node(&"Block", block_blend, Vector2(1100, 0))
	tree_root.connect_node(&"Block", 0, prev)
	tree_root.connect_node(&"Block", 1, &"BlockAnim")
	prev = &"Block"

	# The swing goes ON TOP of the block, so a slash reads even if the shield was
	# up the instant before it.
	var attack_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"AttackAnim", _anim_node(clip_attack), Vector2(1240, 260))
	tree_root.add_node(&"AttackScale", attack_scale, Vector2(1360, 260))
	tree_root.connect_node(&"AttackScale", 0, &"AttackAnim")
	var attack_shot := AnimationNodeOneShot.new()
	attack_shot.fadein_time = 0.04
	attack_shot.fadeout_time = 0.12
	tree_root.add_node(&"Attack", attack_shot, Vector2(1440, 0))
	tree_root.connect_node(&"Attack", 0, prev)
	tree_root.connect_node(&"Attack", 1, &"AttackScale")
	prev = &"Attack"

	prev = _add_oneshot(tree_root, &"Land", prev, _anim_node(clip_land), Vector2(1600, 0), 0.06, 0.20)
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
	_tree.set(_P_BLEND, 0.0)
	_tree.set(_P_STRIDE, 1.0)
	_tree.set(_P_BLOCK, 0.0)
	_tree.set(_P_ATTACK_SCALE, 1.0)


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


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)

	# A screen owning input means the hero reads NEUTRAL, not that he stops being
	# simulated -- he still falls, still slides to a halt, still finishes a roll.
	# Without this the shop's confirm key (space) is also the dodge key, and every
	# purchase throws the hero across the town square behind the panel.
	var locked := Prompt != null and Prompt.blocked
	var stick := Vector2.ZERO if locked \
		else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mag := clampf(stick.length(), 0.0, 1.0)
	var wish := _camera_relative(stick)

	if not locked:
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
	if Prompt != null and Prompt.blocked:
		return false
	if not Input.is_action_just_pressed(&"context"):
		return false
	if not is_on_floor():
		return false
	# [oot] a discrete action needs a near-full deflection — you cannot roll out
	# of a walk, only out of a committed run. §3.2 / K.STICK_ACTION_GATE.
	if mag < roll_stick_gate or wish == Vector3.ZERO:
		return false
	# Last gate, and deliberately last: every cheaper reason to refuse has already
	# run, so we never charge stamina for a roll that was not going to happen.
	if not Game.spend_stamina(roll_stamina):
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


## A swing commits. The hero keeps his facing and bleeds off whatever speed he
## carried in, which is what makes the blade feel like it weighs something —
## being able to steer through a swing is the single biggest tell of a clone.
func _tick_attack(delta: float) -> void:
	_state_timer -= delta
	_speed = move_toward(_speed, 0.0, decel * 2.2 * delta)
	_set_planar_velocity(_forward() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND


## Start a swing lasting `duration` seconds. Returns false if the hero is busy —
## rolling, turning, or already mid-swing — so the caller does not play a
## whoosh for a swing that never happened.
func request_attack(duration: float) -> bool:
	if state != MoveState.GROUND or not is_on_floor():
		return false
	state = MoveState.ATTACK
	_state_timer = duration

	# Face where the stick is pointing at the instant of the swing, so an attack
	# aims where the player is looking rather than where he last ran.
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if stick.length() > 0.3:
		var wish := _camera_relative(stick)
		if wish != Vector3.ZERO:
			facing_yaw = atan2(wish.x, wish.z)

	# The slash clips run 1.4-2.4 s. OOT's swing is about half a second, so the
	# clip is compressed onto the real swing rather than the swing being slowed
	# to the clip — the animation serves the timing, not the other way round.
	var clip_len := 1.0
	if anim_library.has_animation(clip_attack):
		clip_len = anim_library.get_animation(clip_attack).length
	if _tree != null:
		_tree.set(_P_ATTACK_SCALE, clip_len / maxf(duration, 0.05))
	_fire(_P_ATTACK)
	return true


## Raise or drop the shield. HeroCombat owns the decision; this owns the pose.
func set_blocking(on: bool) -> void:
	blocking = on


## Take a blow. The ONE place damage reaches the player, so i-frames, the shield
## and knockback are decided once rather than in every attacker.
##
## Health lives in `Game` rather than a HealthComponent because it has to survive
## the scene change that extracting causes -- a component on the hero dies with
## the dungeon, and the whole point of extracting is that you keep what you had.
## The i-frame clock lives here because it is a property of the body, and the
## body is what gets replaced when a new scene loads.
##
## Returns true if the blow actually landed.
func take_hit(hit: Hit) -> bool:
	if hit == null or hit.amount <= 0 or Game.quarters <= 0:
		return false
	if _invuln > 0.0 or state == MoveState.ROLL:
		return false

	# The shield is a direction, not a toggle: blocking with your back turned is
	# just standing still. HeroCombat owns the arc because it owns the shield.
	if combat != null and combat.blocks(hit.from):
		combat.on_blocked(hit.from, K.flat(hit.from - global_position))
		_invuln = K.SHIELD_IFRAMES
		var shove := K.flat(global_position - hit.from) * 2.4
		_set_planar_velocity(shove)
		return false

	_invuln = K.IFRAME_TIME
	# Armour never zeroes a blow. A build that cannot be hurt turns the whole
	# extraction decision into a formality.
	Game.damage(maxi(K.QUARTER, hit.amount - Game.armour_level))
	if hit.knockback > 0.0:
		var away := K.flat(global_position - hit.from)
		if away == Vector3.ZERO:
			away = -_forward()
		_set_planar_velocity(away * hit.knockback)
		_speed = 0.0
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.45, 0.18)
	return true


func is_invulnerable() -> bool:
	return _invuln > 0.0


func skeleton() -> Skeleton3D:
	if _rig == null:
		return null
	return _rig.find_child("Skeleton3D", true, false) as Skeleton3D


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

	# The shield eases in and out rather than snapping, so raising it is a
	# visible action instead of a costume change between frames.
	var want := 1.0 if blocking else 0.0
	var now: float = _tree.get(_P_BLOCK)
	_tree.set(_P_BLOCK, move_toward(now, want, delta / maxf(block_fade, 0.01)))

	# The rig's yaw correction is a fixed 180 (see model_yaw_offset) and is set
	# once in _build_rig — it does not vary with speed.
