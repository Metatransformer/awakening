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

enum MoveState { GROUND, TURN180, ROLL, ROLL_RECOVER, ATTACK, HOOK }

## Which way a dodge goes, measured against the facing it KEEPS through it.
##
## Free — nothing locked, no guard — the roll *is* the turn, so this is always
## FORWARD and the other three never come up: an unpinned dodge cannot go
## backwards because the body has already turned to meet it. They exist for the
## stances that pin the facing, which is where OOT's roll/backflip/sidehop split
## lives too. See `_dodge_for`.
enum Dodge { FORWARD, BACK, LEFT, RIGHT }

## Which swing is being played. The hero owns the POSE; HeroCombat owns what the
## pose costs and what it does — see request_attack.
##
## The three lights are separate values rather than an index into one clip
## because the animation tree needs one node per variant (see _add_swing), and a
## node cannot be addressed by a number that only exists in the combat script.
enum Swing { LIGHT1, LIGHT2, LIGHT3, HEAVY, LUNGE, DASH }

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

@export_group("Lunge")
## Ceiling on the leap's ground speed, m/s. Without it a lock on something far
## away turns the lunge into a teleport — the drive is "close this gap in this
## many seconds", and a big enough gap divides into an absurd number.
@export var lunge_max_speed: float = 12.0
## Metres of the gap the leap deliberately leaves. Landing ON the target shoves
## the hero through him, and a lunge that ends behind the enemy is a whiff the
## player will read as the hitbox being broken.
@export var lunge_stop_short: float = 1.0

@export_group("Roll")
@export var roll_speed: float = K.ROLL_SPEED
@export var roll_time: float = K.ROLL_TIME
## The other two dodge speeds, which are NOT the roll's. All three are [oot] and
## all three are different — the roll is the ground-coverer (6.55 m/s), the
## sidehop is nearly as fast (6.19), and the backflip is only walking-out-of-
## trouble quick (4.37). They have sat unused in `K` since the roll was written,
## because until the facing was pinned there was no backwards to go.
@export var sidehop_speed: float = K.SIDEHOP_SPEED
@export var backflip_speed: float = K.BACKFLIP_SPEED
## Seconds a sidehop or a backstep owns the hero, against `roll_time`'s 0.62.
## Shorter because a hop IS shorter — it is a step out of the way, not a dive
## across the room — and because the i-frames run for exactly as long as the
## dodge does (see take_hit), so a hop buys a smaller window than a roll. [tune]
@export var hop_time: float = 0.44
## The backflip's own window, because it is not a sidehop. A flip has to leave
## the ground, inverct and land, and 0.44 s of that is a blur nobody can read as
## a flip. 0.60 s is the shortest window the clip stays legible in, and it buys
## the flip its own identity in the one currency dodges trade in: i-frames run
## for exactly as long as the dodge does, so the backflip is the widest window
## short of a roll and the slowest to get you out of the way (4.37 m/s). That is
## the trade — safest, but least ground covered per second. [tune]
@export var backflip_time: float = 0.60
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
## The four dodges. **The Pro Sword and Shield Pack contains no roll of any
## kind** — 52 clips, not one of them a dodge — which is why every direction used
## to play `ex_roll_to_run`, a 3.2 m forward shoulder dive, including the
## backstep. A hero sliding backwards through a forward roll is the single most
## visible thing wrong with the guard.
##
## The sidehops come from the LONGBOW set, which does ship a four-way dodge, and
## they were checked the only way this can be checked: by reading the hips
## translation out of the raw FBX before `build_anim_lib` strips it
## (tools/directors/dodge_lookdev.gd documents the run). dodge_left travels
## +1.04 m and dodge_right −1.07 m in clip space, where +Z is the model's forward
## and +X its left — so the filenames are honest, which is not something to
## assume (CLAUDE.md §4).
##
## FORWARD keeps the dive rather than taking the longbow set's forward hop: it is
## a real roll, it covers real ground, and it is the one dodge the pack's absence
## did not actually break.
##
## BACK is a **backflip**, and it is the one place the longbow set was not good
## enough: `bow_dodge_back` is a backward shuffle-walk that never leaves the
## ground, which is a retreat, not an evade. `ex_backflip` crouches, launches,
## goes fully inverted overhead and lands in a deep absorb — and it is what
## `K.BACKFLIP_SPEED` has been named after since the day it was measured.
@export var clip_roll: StringName = &"ex_roll_to_run"
@export var clip_roll_back: StringName = &"ex_backflip"
@export var clip_roll_left: StringName = &"bow_dodge_left"
@export var clip_roll_right: StringName = &"bow_dodge_right"
@export var clip_turn180: StringName = &"ss_180_turn_01"
@export var clip_air: StringName = &"ss_jump_01"
@export var clip_land: StringName = &"ss_jump_02"
## The three steps of the light chain. Three DIFFERENT clips, not one replayed:
## a combo whose every hit is the same swing reads as a stutter, and the whole
## point of a chain is that the player can see how far into it they are.
##
## Chosen off the render, and chosen as a SEQUENCE: 01 comes down on the diagonal
## and ends low, 03 sweeps back up from there, 04 is a leaping overhead slam that
## finishes on one knee. Down, up, over — each one starts where the last ended,
## which is what makes three clips read as one sentence instead of three swings.
@export var clip_attack: StringName = &"ss_slash_01"
@export var clip_light2: StringName = &"ss_slash_03"
@export var clip_light3: StringName = &"ss_slash_04"
## The heavy is a DIFFERENT clip, not the light slash time-scaled down. Slowing
## ss_slash_01 to 0.8 s reads as the hero being tired, not as a blow that weighs
## something — the wind-up has to be a real pose the player can learn to see.
##
## ss_attack_02 was PICKED OFF THE RENDER (tools/directors/swing_lookdev.gd), not
## off its name: it opens with the sword drawn back behind a turned shoulder —
## a wind-up you can read in one frame — and sweeps horizontally through. It is
## also the shortest of the attack clips at 1.30 s, so it compresses onto a
## 0.8 s swing barely at all, where ss_attack_03 would have to run at 2.2x.
@export var clip_heavy: StringName = &"ss_attack_02"
## The lock-on lunge. ss_attack_01 is the one clip in the library where the hero
## leaves the ground — a leap straight up into a downward slam that lands on one
## knee. That is why it made a terrible heavy (it shipped as one for a day and
## looked like a physics bug) and exactly the right leap at a locked target.
@export var clip_lunge: StringName = &"ss_attack_01"
## The dash attack — the stab out from behind the raised shield. Also PICKED OFF
## THE RENDER (tools/directors/dodge_lookdev.gd): ss_attack_03 coils low with the
## blade drawn back across the body, explodes into a deep split-legged lunge with
## the point extended straight down the facing, and recovers into the guard. It
## is the only clip in the library whose blade goes FORWARD rather than across —
## every `slash` is an arc, and an arc played on a lunge reads as a man swinging
## at the air beside the thing he just closed on.
@export var clip_dash: StringName = &"ss_attack_03"
## The loose. `bow_aim_recoil` opens at full draw and snaps the string arm back,
## so the shot itself is the whole clip — which is why the aim POSE below is a
## held blend rather than part of this: the hero is already drawn when he fires,
## and a one-shot that had to draw first would put the arrow half a second behind
## the button.
@export var clip_bow_shot: StringName = &"bow_aim_recoil"
## Firing the hookshot. A brace-and-punch with the barrel out front, from
## Shooting.fbx; the bow clips would have him loosing an arrow off a grapple.
@export var clip_hook_shot: StringName = &"ex_hookshot_fire"
## The held aim, and the two ends of the aim-walk blend. These are what the
## over-the-shoulder stance looks like: `bow_aim_overdraw` is a sustained pull at
## full draw, and the aim-walk clips carry the bow through a step instead of
## sliding a statue across the floor.
@export var clip_aim_idle: StringName = &"bow_aim_overdraw"
@export var clip_aim_walk: StringName = &"bow_aim_walk_forward"
## Seconds the aim stance takes to blend in and out. Matches K.CAM_AIM_BLEND so
## the body and the camera arrive at the shoulder together.
@export var aim_fade: float = K.CAM_AIM_BLEND
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

## The bow and the hookshot. Built here for the same reason combat is: an item
## bound to a D-pad button has to work in every scene that spawns a hero, and
## half the rooms in this project build theirs in code.
var ranged: HeroRanged = null

## The way out, carried on his belt. Built here for the same reason combat is:
## every scene that spawns a hero must spawn one who can leave.
var charm: HomewardCharm = null

var _model: Node3D
var _rig: Node3D
var _anim_player: AnimationPlayer
var _tree: AnimationTree
var _state_timer: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
## Whether the roll in flight was started from a stance that pins the facing —
## a lock, or a raised guard. Captured at the start because the shield DROPS for
## the roll, so the live flag says the opposite of what the dodge was.
var _roll_keeps_facing: bool = false
## Which of the four the dodge in flight is, and how fast it travels. The speed
## is stored rather than re-derived each tick because `_tick_roll` holds it flat
## for the whole move, and re-reading it off the direction would need the facing
## the dodge started with — which is exactly what `_roll_keeps_facing` exists to
## remember and exactly the bug it was written for.
var _dodge: int = Dodge.FORWARD
var _dodge_speed: float = 0.0
var _airborne_time: float = 0.0
var _stride_accum: float = 0.0
var _speed: float = 0.0
## The lunge's forward drive: seconds left, which way, and how fast. Kept apart
## from `_speed` because the lunge does NOT bleed — it holds its speed for the
## leap and then stops dead, and folding it into the decel curve would give the
## hero a long powerless glide out of every one.
var _lunge_left: float = 0.0
var _lunge_dir: Vector3 = Vector3.FORWARD
var _lunge_speed: float = 0.0
## Seconds of damage immunity left. See take_hit().
var _invuln: float = 0.0

const _P_BLEND := "parameters/Loco/blend_position"
const _P_STRIDE := "parameters/LocoScale/scale"
const _P_TURN := "parameters/Turn180/request"
const _P_AIR := "parameters/Air/request"
const _P_LAND := "parameters/Land/request"
## One animation-tree node per Dodge value, in enum order — same arrangement as
## _SWING_NODES below, and for the same reason (see _add_scaled_shot).
const _DODGE_NODES: Array[StringName] = [
	&"Roll", &"RollBack", &"RollLeft", &"RollRight",
]
## The roll gets the widest fade of the four: it is the longest move and the one
## that ends lying down, so snapping out of it pops the hero upright. The hops
## are quick steps and a slow fade on a quick step reads as lag.
const _DODGE_FADE_IN: Array[float] = [0.05, 0.05, 0.04, 0.04]
const _DODGE_FADE_OUT: Array[float] = [0.16, 0.14, 0.12, 0.12]
## NOTE: the backflip's dead tail is cut at BAKE time, in build_anim_lib's TRIM
## table, not here. `_fire_dodge` scales `clip_len / duration` so the one-shot
## ends exactly when the dodge does; trimming at this end would shorten the
## factor without shortening the clip, and the hero would stand in the clip's
## settle pose for 0.4 s after the game had already handed him back to
## locomotion. The invariant is *the clip's length is the move's length*.
## One animation-tree node per Swing value, in enum order. Indexed by `Swing`,
## so anything added to the enum has to be added here too — which is the point:
## a swing with no node fails loudly at build rather than silently not playing.
const _SWING_NODES: Array[StringName] = [
	&"Swing1", &"Swing2", &"Swing3", &"SwingHeavy", &"SwingLunge", &"SwingDash",
]
## Fades, in seconds, per Swing. They widen as the blow gets heavier: a heavy
## that snaps into pose has no wind-up to read, and the wind-up is the whole
## tell the player is being asked to trade commitment for. The mid-chain lights
## are the tightest because a chain that fades between steps reads as lag.
## The dash's fade-in is the tightest of the lot on purpose. It comes out of a
## raised guard, which is already a committed pose the player chose to be in —
## the wind-up happened before the press — so easing into it puts the shield back
## between the hero and the thing he is stabbing.
const _SWING_FADE_IN: Array[float] = [0.06, 0.04, 0.05, 0.10, 0.08, 0.04]
const _SWING_FADE_OUT: Array[float] = [0.16, 0.12, 0.18, 0.22, 0.20, 0.18]

const _P_RANGED := "parameters/Ranged/request"
const _P_RANGED_SCALE := "parameters/RangedScale/scale"
const _P_HOOK_SHOT := "parameters/HookShot/request"
const _P_HOOK_SCALE := "parameters/HookScale/scale"
const _P_AIM := "parameters/Aim/blend_amount"
const _P_AIM_HOOK := "parameters/HookAim/blend_amount"
const _P_AIM_BLEND := "parameters/AimLoco/blend_position"
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
	# Built here rather than authored into hero.tscn for the same reason combat
	# is: every scene that spawns a hero must get a lockable one, and half the
	# rooms in this project build their hero in code.
	targeting = find_child("Targeting", false, false)
	if targeting == null:
		targeting = Targeting.new()
		targeting.name = "Targeting"
		add_child(targeting)

	# The sword and shield live in their own node, but the hero owns their
	# lifetime so every scene that spawns a hero gets an armed one.
	combat = HeroCombat.new()
	combat.name = "Combat"
	add_child(combat)

	# After combat, and that ordering matters: HeroRanged reads `combat.bow` and
	# `combat.hookshot` to find the muzzle a shot leaves from, and those are
	# mounted in HeroCombat's own _ready.
	ranged = HeroRanged.new()
	ranged.name = "Ranged"
	add_child(ranged)

	charm = HomewardCharm.new()
	charm.name = "Charm"
	add_child(charm)

	_build_key_light()

	Bus.player_spawned.emit(self)


## A short-range lamp that travels with the hero.
##
## "Torches make pools of light and the space between them is dark" is the right
## rule for the ROOM and the wrong rule for the character: between two sconces
## the hero rendered as a featureless black cut-out, and the player cannot read
## a guard or a roll off a silhouette. The range is deliberately under 4 m and
## the light casts no shadows, so it lights him and nothing else -- the room's
## darkness is untouched.
func _build_key_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "KeyLight"
	lamp.light_color = Color(1.0, 0.94, 0.86)
	lamp.light_energy = 1.4
	lamp.omni_range = 3.4
	lamp.omni_attenuation = 1.7
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 1.9, -0.6)
	add_child(lamp)


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

	# The aim stances REPLACE locomotion rather than layering over it. A held pose
	# blended on top of a walk cycle is what the shield does, and it is the right
	# answer there because a shield only occupies one arm — a bow at full draw
	# occupies the whole body, and mixing it with a sword-and-shield stride gives
	# a hero drawing a bow with his legs out of a different animation.
	#
	# So the bow gets a second, parallel locomotion blend built out of the longbow
	# set's own clips. Same axis, same units, same `_P_BLEND`-shaped input — see
	# `_drive_animation`.
	var aim_loco := AnimationNodeBlendSpace1D.new()
	aim_loco.min_space = 0.0
	aim_loco.max_space = run_blend_speed
	aim_loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	aim_loco.add_blend_point(_anim_node(clip_aim_idle), 0.0, -1, &"aim_idle")
	aim_loco.add_blend_point(_anim_node(clip_aim_walk), walk_blend_speed, -1, &"aim_walk")
	# The pack has no aim RUN — you do not sprint at full draw. Reusing the walk
	# at the run end keeps the blend defined across the whole axis; the stride
	# scale in `_drive_animation` is what stops the feet skating.
	aim_loco.add_blend_point(_anim_node(clip_aim_walk), run_blend_speed, -1, &"aim_run")
	tree_root.add_node(&"AimLoco", aim_loco, Vector2(220, 400))

	var aim_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"Aim", aim_blend, Vector2(340, 0))
	tree_root.connect_node(&"Aim", 0, &"LocoScale")
	tree_root.connect_node(&"Aim", 1, &"AimLoco")

	# The hookshot gets its OWN stance, and it has to. Held in the bow's stance he
	# aims a grapple pistol with an archer's draw — both hands up beside his ear,
	# torso wound ninety degrees off the shot — and the giveaway is the longbow
	# slung on his back, which is pinned to Spine2 and swings out into open air
	# with the twist. It looked like the bow had come unstuck from the model. It
	# had not; he was drawing an invisible bow around it.
	#
	# One clip, held, rather than a blend: the pack has no hookshot walk, and a
	# brace is a brace whether or not the feet are moving.
	var hook_pose := _anim_node(clip_hook_shot)
	hook_pose.loop_mode = Animation.LOOP_LINEAR
	tree_root.add_node(&"HookAimAnim", hook_pose, Vector2(220, 600))
	var hook_aim := AnimationNodeBlend2.new()
	tree_root.add_node(&"HookAim", hook_aim, Vector2(460, 0))
	tree_root.connect_node(&"HookAim", 0, &"Aim")
	tree_root.connect_node(&"HookAim", 1, &"HookAimAnim")

	# One-shots layered over the locomotion, cheapest first. Land is last so a
	# landing always reads over whatever else is still fading out. They sit above
	# the stances so a roll or a hit reaction still reads while the bow is out.
	var prev := &"HookAim"
	prev = _add_oneshot(tree_root, &"Turn180", prev, _anim_node(clip_turn180), Vector2(440, 0), 0.10, 0.22)
	prev = _add_oneshot(tree_root, &"Air", prev, _anim_node(clip_air), Vector2(660, 0), 0.10, 0.18)

	# Four dodges, four one-shots — not one node whose clip is reassigned, for the
	# reason _add_scaled_shot gives. They chain in Dodge order and they all sit
	# BELOW `Block`, which is load-bearing: the guard is a blend that would
	# otherwise replace whichever dodge is playing, and HeroCombat drops the
	# shield for the dodge precisely because of where these sit.
	for i in Dodge.size():
		prev = _add_scaled_shot(tree_root, _DODGE_NODES[i], prev, _dodge_clip(i),
			Vector2(880 + 90 * i, 0), _DODGE_FADE_IN[i], _DODGE_FADE_OUT[i])

	# The shield is a HELD pose, so it blends rather than fires: a one-shot would
	# end on its own while the button is still down.
	var block_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"BlockAnim", _anim_node(clip_block), Vector2(1000, 200))
	tree_root.add_node(&"Block", block_blend, Vector2(1100, 0))
	tree_root.connect_node(&"Block", 0, prev)
	tree_root.connect_node(&"Block", 1, &"BlockAnim")
	prev = &"Block"

	# The swings go ON TOP of the block, so a slash reads even if the shield was
	# up the instant before it. One one-shot per variant — see _add_swing for why
	# they are not one node with the clip reassigned.
	#
	# The fades widen as the blow gets heavier. A heavy that snaps into pose has
	# no wind-up to read, and the wind-up is the whole tell the player is being
	# asked to trade commitment for.
	for i in Swing.size():
		prev = _add_scaled_shot(tree_root, _SWING_NODES[i], prev, _swing_clip(i),
			Vector2(1440 + 80 * i, 0), _SWING_FADE_IN[i], _SWING_FADE_OUT[i])

	# The two shots get one one-shot EACH rather than sharing a node whose clip is
	# swapped. Assigning `animation` on a live AnimationNodeAnimation the same
	# frame it is asked to play restarts the mixer's cache mid-blend and drops the
	# opening frames — which for the bow is the loose itself, the one frame the
	# whole shot is about. They sit above the swings because a bow is never held at
	# the same time as the sword: whichever fired last is the one that should read.
	#
	# The bow's fade-in is very short on purpose. `bow_aim_recoil` starts from the
	# same full draw the `Aim` stance is already holding, so there is nothing to
	# ease between — a longer fade just delays the string leaving his fingers.
	var ranged_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"RangedAnim", _anim_node(clip_bow_shot), Vector2(1840, 260))
	tree_root.add_node(&"RangedScale", ranged_scale, Vector2(1960, 260))
	tree_root.connect_node(&"RangedScale", 0, &"RangedAnim")
	var ranged_shot := AnimationNodeOneShot.new()
	ranged_shot.fadein_time = 0.03
	ranged_shot.fadeout_time = 0.18
	tree_root.add_node(&"Ranged", ranged_shot, Vector2(1840, 0))
	tree_root.connect_node(&"Ranged", 0, prev)
	tree_root.connect_node(&"Ranged", 1, &"RangedScale")
	prev = &"Ranged"

	var hook_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"HookShotAnim", _anim_node(clip_hook_shot), Vector2(1940, 500))
	tree_root.add_node(&"HookScale", hook_scale, Vector2(2060, 500))
	tree_root.connect_node(&"HookScale", 0, &"HookShotAnim")
	var hook_shot := AnimationNodeOneShot.new()
	hook_shot.fadein_time = 0.06
	hook_shot.fadeout_time = 0.16
	tree_root.add_node(&"HookShot", hook_shot, Vector2(1940, 0))
	tree_root.connect_node(&"HookShot", 0, prev)
	tree_root.connect_node(&"HookShot", 1, &"HookScale")
	prev = &"HookShot"

	prev = _add_oneshot(tree_root, &"Land", prev, _anim_node(clip_land), Vector2(2160, 0), 0.06, 0.20)
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

	# The dodge time-scales are set per FIRE, not here: the four clips are 0.97 to
	# 1.63 s long and the roll runs for longer than a hop, so a single compression
	# factor would be wrong for three of the four. Same arrangement the swings
	# have used since the heavy landed — see _fire_dodge and request_attack.
	for i in Dodge.size():
		_tree.set(_dodge_scale_param(i), 1.0)
	_tree.set(_P_BLEND, 0.0)
	_tree.set(_P_STRIDE, 1.0)
	_tree.set(_P_BLOCK, 0.0)
	for i in Swing.size():
		_tree.set(_swing_scale_param(i), 1.0)
	_tree.set(_P_AIM, 0.0)
	_tree.set(_P_AIM_HOOK, 0.0)
	_tree.set(_P_AIM_BLEND, 0.0)
	_tree.set(_P_RANGED_SCALE, 1.0)
	_tree.set(_P_HOOK_SCALE, 1.0)


## The clip each Swing plays. A match rather than an array of exports so the
## clips stay individually named in the inspector — `clip_light2` says what it
## is; `swing_clips[1]` needs this file open to read.
func _swing_clip(variant: int) -> StringName:
	match variant:
		Swing.LIGHT2: return clip_light2
		Swing.LIGHT3: return clip_light3
		Swing.HEAVY: return clip_heavy
		Swing.LUNGE: return clip_lunge
		Swing.DASH: return clip_dash
		_: return clip_attack


## The clip each Dodge plays, same arrangement and same reasoning as _swing_clip.
func _dodge_clip(dodge: int) -> StringName:
	match dodge:
		Dodge.BACK: return clip_roll_back
		Dodge.LEFT: return clip_roll_left
		Dodge.RIGHT: return clip_roll_right
		_: return clip_roll


func _swing_param(variant: int) -> String:
	return "parameters/%s/request" % _SWING_NODES[variant]


func _dodge_param(dodge: int) -> String:
	return "parameters/%s/request" % _DODGE_NODES[dodge]


func _dodge_scale_param(dodge: int) -> String:
	return "parameters/%sScale/scale" % _DODGE_NODES[dodge]


func _swing_scale_param(variant: int) -> String:
	return "parameters/%sScale/scale" % _SWING_NODES[variant]


func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


## Add one time-scaled one-shot: its clip, a TimeScale so the clip can be
## compressed onto the real move duration, and a OneShot layered over `base`.
## Returns the new top of the chain. Every swing and every dodge is one of these.
##
## One node per variant, rather than one node whose `animation` is reassigned:
## assigning the clip on a LIVE AnimationNodeAnimation restarts the mixer's
## cache mid-blend and eats the first frames of the wind-up. That is the most
## expensive kind of animation bug here, because it looks like bad art. It is
## also why the four dodges are four nodes and not one node plus a direction —
## the eaten frames of a dodge are the launch, which is the whole read.
func _add_scaled_shot(tree_root: AnimationNodeBlendTree, id: StringName, base: StringName,
		clip: StringName, pos: Vector2, fade_in: float, fade_out: float) -> StringName:
	var anim_id := StringName(String(id) + "Anim")
	var scale_id := StringName(String(id) + "Scale")
	tree_root.add_node(anim_id, _anim_node(clip), pos + Vector2(-200, 260))
	tree_root.add_node(scale_id, AnimationNodeTimeScale.new(), pos + Vector2(-80, 260))
	tree_root.connect_node(scale_id, 0, anim_id)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	tree_root.add_node(id, shot, pos)
	tree_root.connect_node(id, 0, base)
	tree_root.connect_node(id, 1, scale_id)
	return id


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
	# Leaving roots him, by the same mechanism and for a related reason: the
	# charm's channel is only a decision if walking out of it is not free. He
	# still falls and still slides to a halt, he just does not steer.
	var locked := (Prompt != null and Prompt.blocked) \
		or (charm != null and charm.active())
	var stick := Vector2.ZERO if locked \
		else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mag := clampf(stick.length(), 0.0, 1.0)
	var wish := _camera_relative(stick)

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
		MoveState.HOOK:
			_tick_hook(delta)

	# The hookshot flies perfectly straight and so does what it drags
	# (docs/CONTRACT.md §2.5 #8). Gravity applied during the pull would sag the
	# arc, and a hookshot that cannot lift you to a ledge above you is a rope.
	if state != MoveState.HOOK:
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


## The locked target, or null. `z_target` itself belongs to Targeting now — the
## hero only ever asks who is being locked, never who pressed what.
func lock_target() -> Node3D:
	if targeting == null:
		return null
	if not bool(targeting.get(&"is_locked")):
		return null
	var t := targeting.get(&"current_target") as Node3D
	return t if t != null and is_instance_valid(t) else null


## Heading yaw that points the hero at `t`. Heading convention, not node
## rotation: heading == (sin y, 0, cos y). See `facing_yaw`.
func _yaw_to(t: Node3D) -> float:
	var to := K.flat(t.global_position - global_position)
	if to == Vector3.ZERO:
		return facing_yaw
	return atan2(to.x, to.z)


# --- States -----------------------------------------------------------------

func _tick_ground(wish: Vector3, mag: float, delta: float) -> void:
	if _try_start_roll(wish, mag):
		return

	# [oot] §3.2 — a continuous curve of stick magnitude, no walk/run branch.
	var target_speed := K.speed_for_stick(mag)
	var moving := target_speed > 0.0

	var target := lock_target()
	if target != null:
		_tick_locked(wish, target_speed, moving, target, delta)
		return

	# Aiming and guarding hold the body the same way, so they share a tick. See
	# _tick_camera_facing for why the shield belongs in it.
	if aiming() or blocking:
		_tick_camera_facing(wish, target_speed, moving, delta)
		return

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


## Locked on: the body points at the target and the stick moves you around it.
##
## This is the whole difference between a lock-on and a camera hint, and it is
## what was missing. Unlocked, heading and travel are the same vector — the hero
## goes where he faces, and steering IS turning. Locked, they come apart:
## `facing_yaw` is owned by the target and the stick drives velocity directly,
## so pulling left circles the enemy while still looking at him.
##
## Two consequences worth naming, because both are load-bearing:
##
##   * The 135-degree reversal (§3.3) is suppressed. It exists to make an
##     about-face read as its own move, which only makes sense when the body
##     turns to travel. Locked, the body never turns, so a reversal is just
##     backing off — and firing a 180 clip there would spin the hero away from
##     the thing he is supposed to be watching.
##   * Speed is NOT reduced for backing up or side-stepping. Elden Ring does
##     slow a backward walk, and doing that here needs strafe clips the library
##     ships but nobody has identified (tools/directors/strafe_lookdev.gd), so
##     it is deliberately left alone rather than tuned against the wrong
##     animation.
func _tick_locked(wish: Vector3, target_speed: float, moving: bool,
		target: Node3D, delta: float) -> void:
	# Faster than the free turn rate: the lock is a promise that he keeps facing
	# the thing, and a lazy swing off that promise reads as the lock slipping.
	_steer_to(Vector3(sin(_yaw_to(target)), 0.0, cos(_yaw_to(target))),
		turn_rate * 1.8, delta)

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_set_planar_velocity(wish.normalized() * _speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)
		# Bleed off along whatever direction he was already travelling, not
		# along his facing — locked, those are different, and using the facing
		# here slides him into the enemy every time he lets go of the stick.
		var travel := K.flat(velocity)
		if travel == Vector3.ZERO:
			_set_planar_velocity(Vector3.ZERO)
		else:
			_set_planar_velocity(travel.normalized() * _speed)


## Aiming or guarding, unlocked: the body points where the LENS points and the
## stick moves you around, which is the same split `_tick_locked` makes and for
## the same reason. Here the thing being faced is the camera rather than an enemy.
##
## For the BOW this is what stops the shot lying. Without it the hero runs where
## the stick says while the camera sits on his shoulder looking somewhere else,
## and the bow — held in the hands of a body facing away from the shot — visibly
## points at nothing the arrow will hit. The aim is the camera's (see
## hero_ranged.gd), so the body has to agree with it.
##
## For the SHIELD it is OOT's Z-Parallel, which is the half of holding Z that
## has nothing to do with locking onto anything: the guard pins your facing and
## the stick becomes a strafe. That is what makes the shield a stance rather than
## a toggle you carry around — you sidestep round a thing while watching it, back
## off from it in a straight line, and the backstep in `_try_start_roll` has a
## direction to be the opposite OF. Without a facing to hold, "roll backwards"
## means nothing, because backwards is wherever you last happened to run.
##
## The 135° reversal is suppressed for the same reason it is under a lock: the
## body never turns to travel here, so an about-face is a backstep, and firing a
## 180 clip would spin him off whatever he is facing.
func _tick_camera_facing(wish: Vector3, target_speed: float, moving: bool, delta: float) -> void:
	_steer_to(_camera_heading(), turn_rate * 1.8, delta)

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_set_planar_velocity(wish.normalized() * _speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)
		var travel := K.flat(velocity)
		if travel == Vector3.ZERO:
			_set_planar_velocity(Vector3.ZERO)
		else:
			_set_planar_velocity(travel.normalized() * _speed)


## The camera's forward, flattened, as a heading direction — or the hero's
## current facing when there is no camera, so a director rendering a bare hero
## does not spin him to world north.
func _camera_heading() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := K.flat(-cam.global_transform.basis.z)
		if f != Vector3.ZERO:
			return f.normalized()
	return _forward()


func _try_start_roll(wish: Vector3, mag: float) -> bool:
	if Prompt != null and Prompt.blocked:
		return false
	if not Input.is_action_just_pressed(&"context"):
		return false
	if not is_on_floor():
		return false

	var target := lock_target()
	var dir := wish

	if target != null:
		# Locked, a neutral stick is not "no roll" — it is the BACKSTEP, which
		# is the single most used defensive move in the source material. The
		# stick gate does not apply either: locked, a dodge is a deliberate
		# press rather than something you fall into out of a run, so gating it
		# on a near-full deflection would eat half of them.
		if wish == Vector3.ZERO or mag < K.STICK_DEADZONE:
			dir = -K.flat(target.global_position - global_position)
			if dir == Vector3.ZERO:
				dir = -_forward()
			dir = dir.normalized()
	elif blocking:
		# Guarding with nothing locked is the same stance minus a target
		# (_tick_camera_facing): the facing is pinned to the camera, so a
		# neutral stick backsteps straight away from what you are looking at.
		# Same reasoning as the lock for the missing gate — this is a press you
		# make from behind a raised shield, not one you fall into out of a run.
		if wish == Vector3.ZERO or mag < K.STICK_DEADZONE:
			dir = -_forward()
	else:
		# [oot] a discrete action needs a near-full deflection — you cannot roll
		# out of a walk, only out of a committed run. §3.2 / K.STICK_ACTION_GATE.
		if mag < roll_stick_gate or wish == Vector3.ZERO:
			return false

	# Last gate, and deliberately last: every cheaper reason to refuse has already
	# run, so we never charge stamina for a roll that was not going to happen.
	if not Game.spend_stamina(roll_stamina):
		return false
	state = MoveState.ROLL
	_roll_dir = dir.normalized()
	_roll_keeps_facing = target != null or blocking
	# Locked or guarding, the body keeps watching through the whole dodge; the
	# roll moves him without turning him. Free, the roll IS the turn — and
	# spinning the hero to face his own backstep is precisely the failure this
	# guards against, since a backstep's direction is behind him by definition.
	if not _roll_keeps_facing:
		facing_yaw = atan2(dir.x, dir.z)
	# AFTER the facing is settled, never before: which dodge this is means
	# "which way relative to where he will be looking", and free the answer is
	# always FORWARD *because* the line above just made it so.
	_dodge = _dodge_for(_roll_dir)
	_state_timer = _dodge_time(_dodge)
	_dodge_speed = _dodge_speed_for(_dodge)
	_speed = _dodge_speed
	_set_planar_velocity(_roll_dir * _dodge_speed)
	# The clip is compressed onto the dodge AND its recovery, not onto the dodge
	# alone: all four end by standing back up, and cramming that into the travel
	# leaves the hero holding a finished pose through the whole recovery.
	_fire_dodge(_dodge, _state_timer + roll_recover_time)
	roll_started.emit()
	return true


## Which of the four `dir` is, read against the facing the hero holds through the
## dodge. See the Dodge enum for why the free case can only ever answer FORWARD.
func _dodge_for(dir: Vector3) -> int:
	var f := _forward()
	var ahead := dir.dot(f)
	# Hero-local RIGHT, and the sign here is the whole function. Heading yaw h has
	# forward (sin h, 0, cos h); turning that -90 degrees about Y gives
	# (-cos h, 0, sin h) == (-f.z, 0, f.x). Sanity-check it at h = 0: forward is
	# +Z, the body's rotation.y is PI (CONTRACT §2.5 — -basis.z is forward), and
	# basis.x is therefore (-1, 0, 0). Which agrees. The obvious-looking
	# (f.z, 0, -f.x) is the hero's LEFT, and it shipped for one render: the
	# sidehops travelled correctly and played each other's clip, so he hopped
	# right while crossing his legs to the left.
	#
	# Derived from the heading convention rather than read off `basis`, because
	# `facing_yaw` leads the body: the basis is still catching up on the frame a
	# dodge starts, and a sidehop picked off a stale basis picks the wrong side.
	var side := dir.dot(Vector3(-f.z, 0.0, f.x))
	if absf(ahead) >= absf(side):
		return Dodge.FORWARD if ahead >= 0.0 else Dodge.BACK
	return Dodge.RIGHT if side >= 0.0 else Dodge.LEFT


func _dodge_speed_for(dodge: int) -> float:
	match dodge:
		Dodge.BACK: return backflip_speed
		Dodge.LEFT, Dodge.RIGHT: return sidehop_speed
		_: return roll_speed


## How long the hero belongs to this dodge — which is also how long he is
## invulnerable, since take_hit reads `state == MoveState.ROLL` and nothing finer.
## Three different answers because these are three different moves.
func _dodge_time(dodge: int) -> float:
	match dodge:
		Dodge.BACK: return backflip_time
		Dodge.LEFT, Dodge.RIGHT: return hop_time
		_: return roll_time


## Play the dodge, compressed onto `duration`. The clips run 0.97–2.17 s and the
## moves they serve run 0.44–0.82 s, so each needs its own factor — see the note
## in _build_anim_tree about why this cannot be set once.
func _fire_dodge(dodge: int, duration: float) -> void:
	var clip := _dodge_clip(dodge)
	var clip_len := 1.0
	if anim_library.has_animation(clip):
		clip_len = anim_library.get_animation(clip).length
	if _tree != null:
		_tree.set(_dodge_scale_param(dodge), clip_len / maxf(duration, 0.05))
	_fire(_dodge_param(dodge))


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
	_track_lock(delta)
	_speed = _dodge_speed
	_set_planar_velocity(_roll_dir * _dodge_speed)
	if _state_timer <= 0.0:
		state = MoveState.ROLL_RECOVER
		_state_timer = roll_recover_time


## A swing commits. The hero keeps his facing and bleeds off whatever speed he
## carried in, which is what makes the blade feel like it weighs something —
## being able to steer through a swing is the single biggest tell of a clone.
func _tick_attack(delta: float) -> void:
	_state_timer -= delta
	_track_lock(delta)
	# The lunge drives, then the swing bleeds like any other. The drive is short
	# on purpose: it is over before the damage window opens, so the blow lands at
	# the END of the leap rather than sweeping through everything on the way.
	if _lunge_left > 0.0:
		_lunge_left -= delta
		_speed = _lunge_speed
		_set_planar_velocity(_lunge_dir * _lunge_speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * 2.2 * delta)
		_set_planar_velocity(_bleed_dir() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND


## Keep the body on the target through a move that owns the hero. Without this a
## swing or a dodge freezes the facing, and an enemy that side-steps mid-attack
## ends up behind a hero who is still supposedly locked onto him.
func _track_lock(delta: float) -> void:
	var target := lock_target()
	if target == null:
		return
	var yaw := _yaw_to(target)
	_steer_to(Vector3(sin(yaw), 0.0, cos(yaw)), turn_rate * 1.8, delta)


## Which way residual speed bleeds off. Unlocked these are the same thing, but
## locked the hero faces the target while travelling somewhere else entirely --
## and bleeding along the FACING there walks him into the enemy at the end of
## every backstep.
func _bleed_dir() -> Vector3:
	# Aiming and guarding have the same split as a lock — facing is the camera,
	# travel is the stick — so they bleed the same way. Without this a shot fired
	# while strafing sideways slides him forward along the bow instead of
	# coasting to a stop, and a guarded backstep coasts back into what he just
	# stepped away from.
	if lock_target() == null and not aiming() and not blocking:
		return _forward()
	var travel := K.flat(velocity)
	return travel.normalized() if travel != Vector3.ZERO else _forward()


## Start a swing lasting `duration` seconds. Returns false if the hero is busy —
## rolling, turning, or already mid-swing — so the caller does not play a
## whoosh for a swing that never happened.
##
## `variant` picks which clip plays and nothing else: the timing, the damage and
## the commitment all live in HeroCombat, because they are combat numbers. This
## owns the pose and the facing, exactly as it does for the light swing.
func request_attack(duration: float, variant: int = Swing.LIGHT1) -> bool:
	if state != MoveState.GROUND or not is_on_floor():
		return false
	state = MoveState.ATTACK
	_state_timer = duration
	# Any ordinary swing cancels a leftover drive. request_lunge re-arms it after
	# calling through here, which is why this clear is safe to do unconditionally.
	_lunge_left = 0.0

	# Locked, the swing goes at the target -- that is the entire promise of the
	# lock, and letting the stick redirect it means a player circling an enemy
	# swings past him. Unlocked, face where the stick is pointing at the instant
	# of the swing, so an attack aims where the player is looking rather than
	# where he last ran.
	var target := lock_target()
	if target != null:
		facing_yaw = _yaw_to(target)
	elif not blocking:
		var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if stick.length() > 0.3:
			var wish := _camera_relative(stick)
			if wish != Vector3.ZERO:
				facing_yaw = atan2(wish.x, wish.z)
	# Guarding is the third case and it does NOTHING, which is the point: the
	# raised shield already pins the facing to the lens (_tick_camera_facing), so
	# the stick there is a strafe and not an aim. Letting it re-face the swing
	# meant a guarded sidestep-and-stab lunged off sideways, at ninety degrees to
	# the thing the player was watching over the top of the shield.

	# The slash clips run 1.4-2.4 s. OOT's swing is about half a second, so the
	# clip is compressed onto the real swing rather than the swing being slowed
	# to the clip — the animation serves the timing, not the other way round.
	var clip := _swing_clip(variant)
	var clip_len := 1.0
	if anim_library.has_animation(clip):
		clip_len = anim_library.get_animation(clip).length
	if _tree != null:
		_tree.set(_swing_scale_param(variant), clip_len / maxf(duration, 0.05))
	_fire(_swing_param(variant))
	return true


## The lock-on lunge: the same swing, plus a burst of drive at the locked target
## and a hop off the floor, because clip_lunge is the one clip in the library
## where the hero's feet leave the ground.
##
## Returns false — and swings nothing — if there is no lock. That refusal is the
## feature: the lunge is what Z-targeting BUYS you, and a version of it that
## also fired unlocked would just be a better standing attack.
##
## `drive_time` and `hop` are HeroCombat's, like every other number about the
## blow. What this owns is the arithmetic that turns "there is an enemy 4 m away"
## into a speed, because that is a movement question.
func request_lunge(duration: float, drive_time: float, hop: float) -> bool:
	var target := lock_target()
	if target == null:
		return false
	if not request_attack(duration, Swing.LUNGE):
		return false

	# request_attack has already pointed the body at the target, so the leap goes
	# where the hero is now facing rather than where he was standing a frame ago.
	#
	# Flattened by hand, NOT with K.flat: K.flat NORMALISES. Reading a distance
	# off it gives 1.0 for every target in the world, which made the gap
	# arithmetic below produce a leap speed of zero and a lunge that stood still.
	var delta := target.global_position - global_position
	var to := Vector3(delta.x, 0.0, delta.z)
	var dist := to.length()
	_lunge_dir = to.normalized() if dist > 0.001 else _forward()
	var gap := maxf(dist - lunge_stop_short, 0.0)
	_lunge_speed = minf(gap / maxf(drive_time, 0.05), lunge_max_speed)
	_lunge_left = drive_time
	_speed = _lunge_speed
	velocity.y = hop
	return true


## The dash attack: a swing with a short forward drive behind it, and the one
## attack in the kit that closes distance WITHOUT a lock.
##
## That is the whole difference from `request_lunge`, and it is deliberate. The
## lunge is what Z-targeting buys you, so it refuses without a target; the dash
## is what the SHIELD buys you, and the shield has already earned the right to a
## direction — guarding pins the facing to the lens (`_tick_camera_facing`), so
## "forward" here is a heading the player chose and is still looking down.
##
## It drives along the facing rather than at anything, for the same reason: there
## may be nothing there. A dash attack that whiffs into open floor is a dash
## attack the player mistimed, not a button that failed to do its job.
func request_dash(duration: float, drive_time: float, speed: float) -> bool:
	if not request_attack(duration, Swing.DASH):
		return false
	# request_attack cleared the drive; re-arm it, exactly as request_lunge does.
	_lunge_dir = _forward()
	_lunge_speed = speed
	_lunge_left = drive_time
	_speed = speed
	return true


## The stick in world space, as the hero reads it. Public because the lunge is
## distinguished from a standing swing by exactly one thing — whether the player
## is asking to move TOWARD what they are locked onto — and HeroCombat cannot ask
## that question without the camera-relative rotation this applies.
func wish_dir() -> Vector3:
	return _camera_relative(
		Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))


## Commit to a shot lasting `duration` seconds, turning to face `aim`. Returns
## false if the hero is busy, exactly as `request_attack` does.
##
## It reuses `MoveState.ATTACK` rather than adding a state of its own: what the
## hero's BODY does here is identical — no steering, bleed off whatever speed he
## carried in — and the only difference is which clip plays. A separate state
## would be two copies of `_tick_attack` waiting to drift apart.
##
## `aim` is a full 3D direction because it comes from the camera, which has a
## pitch; only its yaw reaches the body, because the hero does not lean.
##
## `hook` picks which of the two shot clips plays. The bow and the hookshot have
## separate one-shots — see `_build_anim_tree` — so this is a choice of node, not
## a clip swap.
func request_ranged(duration: float, aim: Vector3, hook: bool = false) -> bool:
	if state != MoveState.GROUND or not is_on_floor():
		return false
	state = MoveState.ATTACK
	_state_timer = duration

	# Shooting where you are looking, always. Unlike the sword there is no stick
	# gate here: the aim came from the camera, and the camera IS the player
	# saying where the shot goes.
	var flat_aim := K.flat(aim)
	if flat_aim != Vector3.ZERO:
		facing_yaw = atan2(flat_aim.x, flat_aim.z)

	var clip: StringName = clip_hook_shot if hook else clip_bow_shot
	var clip_len := 1.0
	if anim_library.has_animation(clip):
		clip_len = anim_library.get_animation(clip).length
	if _tree != null:
		_tree.set(_P_HOOK_SCALE if hook else _P_RANGED_SCALE,
			clip_len / maxf(duration, 0.05))
	_fire(_P_HOOK_SHOT if hook else _P_RANGED)
	return true


## True while a bow or a hookshot is out. Owned by `HeroRanged`, which is the
## only thing that knows what is in his hands; the hero asks rather than
## duplicating the rule, so there is one answer and the camera, the HUD and the
## body cannot disagree about whether he is aiming.
func aiming() -> bool:
	return ranged != null and ranged.aiming


## Which ranged item is sighted, or &"" for none. The bow and the hookshot hold
## the body in genuinely different shapes — a full draw versus a two-handed brace
## — so the stance has to know which, not merely that he is aiming.
func aim_item() -> StringName:
	return ranged.aim_item() if ranged != null else &""


# --- The hookshot pull -------------------------------------------------------
## HeroRanged owns the raycast, the anchor and the chain; this owns the body.
## The split is the same one the charm uses — whoever decides is not whoever
## moves — and it is what keeps the hookshot out of the movement script.

## Seconds a pull is allowed to take before the hero is released regardless.
## A pull that ends against a lip the raycast could not see would otherwise root
## him forever, and being stuck is worse than arriving in the wrong place.
const HOOK_TIMEOUT_PAD := 0.6

var _hook_point: Vector3 = Vector3.ZERO
## False while the chain is still outbound and the hero is rooted; true once it
## has bitten and he is being dragged.
var _hook_travelling: bool = false
var _hook_timeout: float = 0.0


## Root the hero for the chain's flight. Refused for the same reasons a swing
## is, so a hookshot cannot be fired out of a roll.
func hook_begin() -> bool:
	if state != MoveState.GROUND and state != MoveState.ATTACK:
		return false
	state = MoveState.HOOK
	_hook_travelling = false
	_hook_timeout = 0.0
	_speed = 0.0
	velocity = Vector3.ZERO
	return true


## The head bit something. Drag him to `point` at K.HOOK_PULL_SPEED.
func hook_pull_to(point: Vector3) -> void:
	if state != MoveState.HOOK:
		return
	_hook_point = point
	_hook_travelling = true
	_hook_timeout = global_position.distance_to(point) / maxf(K.HOOK_PULL_SPEED, 0.1) \
		+ HOOK_TIMEOUT_PAD
	# Face the anchor. Being dragged backwards through the air is the single
	# clearest tell that a hookshot was bolted on rather than built in.
	var flat := K.flat(point - global_position)
	if flat != Vector3.ZERO:
		facing_yaw = atan2(flat.x, flat.z)


func hook_end() -> void:
	if state != MoveState.HOOK:
		return
	state = MoveState.GROUND
	_hook_travelling = false
	_speed = 0.0
	velocity = Vector3.ZERO


## True while the chain is out or the hero is on it. HeroRanged polls this to
## know when the pull has finished rather than being told, because the pull can
## end on arrival OR on the timeout and only the hero knows which.
func hooking() -> bool:
	return state == MoveState.HOOK


func _tick_hook(delta: float) -> void:
	if not _hook_travelling:
		# Rooted while the chain flies out. Held still rather than merely
		# unsteered: the shot reads as an aimed thing, and drifting out from
		# under your own chain looks like the anchor moved.
		velocity = Vector3.ZERO
		return

	_hook_timeout -= delta
	var to := _hook_point - global_position
	# Arrival is generous. The pull point stands off a wall by a hero radius, so
	# insisting on reaching it exactly means arriving is decided by whether
	# move_and_slide let him touch geometry — which is not a thing to hang a
	# state transition on.
	if to.length() <= 0.45 or _hook_timeout <= 0.0:
		hook_end()
		return
	velocity = to.normalized() * K.HOOK_PULL_SPEED


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
	# You do not get to walk out of a fight you are losing. This is the property
	# the rune pad's hold existed to protect (METAGAME §5) and the only reason
	# the charm channels at all rather than teleporting on the menu press.
	#
	# A BLOCKED blow does not break it -- that path returns above. Standing your
	# ground behind the shield while the charm works is a legitimate way to
	# leave, and it is a better one than mashing the button was.
	if charm != null:
		charm.cancel()
	# Armour never zeroes a blow. A build that cannot be hurt turns the whole
	# extraction decision into a formality.
	Game.damage(maxi(K.QUARTER, hit.amount - Game.armour_soak()))
	if hit.knockback > 0.0:
		var away := K.flat(global_position - hit.from)
		if away == Vector3.ZERO:
			away = -_forward()
		_set_planar_velocity(away * hit.knockback)
		_speed = 0.0
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.80, 0.18)
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
	_track_lock(delta)
	_speed = move_toward(_speed, 0.0, decel * 1.6 * delta)
	# Along the roll, not along the facing. Locked or guarding those differ, and
	# a backstep that bled along the facing would coast the hero straight back
	# into the thing he just dodged away from.
	# Read off the flag captured when the roll STARTED, not off `blocking` now:
	# the shield comes down for the roll (hero_combat drops it, so the dive is
	# not played underneath a block pose), and asking the live flag here would
	# make every guarded backstep bleed along a facing it was dodging away from.
	_set_planar_velocity((_roll_dir if _roll_keeps_facing else _forward()) * _speed)
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
	# The aim stance rides the same speed axis, so a strafe at the shoulder blends
	# through the aim-walk at the pace the sword stance would have walked at.
	_tree.set(_P_AIM_BLEND, clampf(planar, 0.0, run_blend_speed))
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	_tree.set(_P_STRIDE, lerpf(stride_scale_idle, stride_scale_run, speed01))

	# The stances ease in and out with the camera, not instantly: drawing the bow
	# is a move he makes, and the rig sliding to the shoulder over a body that
	# snapped into a full draw a frame earlier reads as two unrelated events.
	#
	# Two independent amounts rather than one and a clip swap, for the reason the
	# two shot one-shots are separate: a live AnimationNodeAnimation whose clip is
	# reassigned restarts the mixer's cache mid-blend.
	var item := aim_item()
	_ease_blend(_P_AIM, 1.0 if item == &"bow" else 0.0, delta)
	_ease_blend(_P_AIM_HOOK, 1.0 if item == &"hookshot" else 0.0, delta)

	# The shield eases in and out rather than snapping, so raising it is a
	# visible action instead of a costume change between frames.
	var want := 1.0 if blocking else 0.0
	var now: float = _tree.get(_P_BLOCK)
	_tree.set(_P_BLOCK, move_toward(now, want, delta / maxf(block_fade, 0.01)))

	# The rig's yaw correction is a fixed 180 (see model_yaw_offset) and is set
	# once in _build_rig — it does not vary with speed.


## Walk a Blend2's amount toward `want` over `aim_fade` seconds.
func _ease_blend(param: String, want: float, delta: float) -> void:
	var now: float = _tree.get(param)
	_tree.set(param, move_toward(now, want, delta / maxf(aim_fade, 0.01)))
