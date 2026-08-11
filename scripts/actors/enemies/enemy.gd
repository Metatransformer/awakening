class_name Enemy
extends CharacterBody3D
## A simple melee dungeon enemy: idle -> chase -> wind up -> strike -> recover.
##
## Two things worth knowing before you change this.
##
## **Animation.** Every monster .glb ships a different, mostly-empty clip set
## (goblin has one 0.03 s "ArmatureAction"), but all nine share the SAME 24 bone
## NAMES under the same `Armature/Skeleton3D` path — verified with
## tools/scenes/_monster_tracks.tscn. Animation tracks resolve by name, not by
## bone index, so the shared 81-clip `monster_library.res` binds to all of them.
## The per-GLB library is evicted first, exactly like the hero's FBX stub
## (docs/CONTRACT.md §2), or Godot refuses the second library with an empty name.
##
## **No navmesh.** Rooms are open boxes with nothing to path around, so this
## steers straight at the hero. If rooms ever grow interior obstacles this wants
## a NavigationAgent3D — direct steering will walk into pillars and stick.

signal died_at(position: Vector3)

enum State { IDLE, CHASE, CIRCLE, WINDUP, STRIKE, RECOVER, HURT, LAUNCHED, FROZEN, DEAD }

const LIBRARY := "res://assets/animations/monster_library.res"
const MODEL_DIR := "res://assets/monsters/"

## How far the body rears back over a wind-up, in degrees. Big enough to read
## across a dark room, small enough that it is a tell and not a backflip.
const WINDUP_LEAN_DEG := 17.0

## How close two monsters have to be before they start pushing apart, in metres,
## and how hard they push. See `_separation`.
const CROWD_RADIUS := 1.5
const CROWD_PUSH := 3.4
## Metres between the top of a monster's head and anything the HUD hangs over it.
## Enough to clear the tallest idle pose without reading as a detached label.
const HEAD_CLEARANCE := 0.26

## How far from where it woke up a monster will follow before giving up. The
## rooms are 16 m across, so this is "anywhere in my room and a little past the
## doorway" and not "across the floor".
const LEASH := 17.0

## kind -> stats. Damage is in quarter-hearts, matching every other number in
## the project. Health is tuned against the blade ladder in docs/METAGAME.md §8:
## a tier-0 blade does 2, so a skeleton is a 3-hit kill on run one.
const DEFS := {
	&"skeleton": {
		"health": 6, "damage": 2, "speed": 2.2, "height": 1.70,
		"detect": 11.0, "reach": 1.7, "windup": 0.45, "recover": 0.55, "cooldown": 0.9,
	},
	&"goblin": {
		"health": 5, "damage": 2, "speed": 3.0, "height": 1.25,
		"detect": 12.0, "reach": 1.5, "windup": 0.32, "recover": 0.40, "cooldown": 0.7,
	},
	&"kobold": {
		"health": 8, "damage": 3, "speed": 3.2, "height": 1.35,
		"detect": 13.0, "reach": 1.6, "windup": 0.30, "recover": 0.42, "cooldown": 0.65,
	},
	&"orc": {
		"health": 14, "damage": 4, "speed": 2.3, "height": 1.95,
		"detect": 11.0, "reach": 2.0, "windup": 0.62, "recover": 0.75, "cooldown": 1.1,
	},
	&"wraith": {
		"health": 20, "damage": 5, "speed": 2.8, "height": 1.90,
		"detect": 15.0, "reach": 1.9, "windup": 0.48, "recover": 0.60, "cooldown": 0.8,
	},
	# --- The Chord Gate's two bodies ----------------------------------------
	# `FloorDb.FLOORS[4]` has named these since it was written and neither had a
	# row, which is not a gap you can see: `DEFS.get(kind, DEFS[&"skeleton"])`
	# below hands back SKELETON'S NUMBERS under the requested MODEL, so floor 4
	# was spawning 6-quarter, 2-damage, 1.70 m skeletons wearing troll and iron
	# knight meshes. Nothing logs that. `BossDb.validate()` refuses a summon of a
	# kind with no row for exactly this reason.
	#
	# THE ARITHMETIC, because a health number with no working shown is a number
	# nobody can safely change. A light swing is `2 + K.EDGE_DAMAGE[rung]`
	# (hero_combat.gd), so 2 q at blade rung 0 and 5 q at rung 3. These are
	# FLOOR-1 base numbers like every row above; floor 4 puts `Prog.health_mult(4)`
	# = 1.75 on the health and `Prog.damage_bonus(4)` = +1 on the damage:
	#
	#   troll        22 -> 39 q on floor 4.  rung 0 -> 20 swings.  rung 3 -> 8.
	#   knight_iron  19 -> 33 q on floor 4.  rung 0 -> 17 swings.  rung 3 -> 7.
	#
	# Seven or eight swings for the heaviest ordinary body, against six for a
	# floor-3 wraith (30 q at rung 3) and twenty-six for the Riven Knight itself
	# (`BossDb`, 128 q): the roster steps, the boss is still four times a monster.
	# The rung-0 column is meant to look awful. `docs/SCOPE.md` and BossDb both
	# say arriving at the Chord Gate with an unforged blade should be a wall, and
	# a wall is what twenty swings a body is.
	&"troll": {
		# The slow one. Longest reach and the longest wind-up in the roster --
		# it hits hardest of anything that is not a boss, and it tells you for
		# three quarters of a second first. That pairing is the whole design:
		# damage is only unfair when you could not read it coming.
		"health": 22, "damage": 6, "speed": 2.0, "height": 2.60,
		"detect": 12.0, "reach": 2.4, "windup": 0.72, "recover": 0.85, "cooldown": 1.15,
	},
	&"knight_iron": {
		# The fast one, and deliberately the SHORTER of the two: floor 4's threat
		# is not "everything got bigger", it is a heavy you can see over and a
		# soldier you cannot outpace. Quickest wind-up outside the goblins.
		"health": 19, "damage": 5, "speed": 2.7, "height": 2.10,
		"detect": 13.0, "reach": 1.9, "windup": 0.46, "recover": 0.58, "cooldown": 0.80,
	},
}

@export var kind: StringName = &"skeleton"
## Seeded by the dungeon so a run is reproducible from Game.run_seed.
@export var drop_seed: int = 0
## Which floor this one was built for. Everything that scales with depth reads it
## through `Prog`, and it is set by the dungeon rather than read off `Run` so a
## monster spawned by a director or a test scene is a floor-1 monster.
@export var level: int = Prog.FIRST
## A bigger, tougher single body. Deliberately not a stat nudge: a room of six
## ordinary monsters and a room of five plus one you can SEE coming are different
## rooms, and only the second one is a decision (scripts/core/progression.gd).
@export var elite: bool = false

var state: State = State.IDLE
var health: HealthComponent

var _def: Dictionary = {}
var _model: Node3D
var _anim: AnimationPlayer
var _hitbox: DamageArea
var _player: Node3D
var _timer: float = 0.0
var _cooldown: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _facing: float = 0.0
var _rng := RandomNumberGenerator.new()
var _struck: bool = false
## `Hit.kind` of the last blow that damaged this body -- `&"sword"`, `&"arrow"`,
## `&"bomb"`, `&"contact"`, `&"fire"` (`docs/CONTRACT.md` §8). Written by
## `_on_damaged` and read once, by `_die`, for the Returning Shaft.
var _last_hit_kind: StringName = &""
## Which way the last blow pushed, and how hard it was (`blow_weight`). Stamped
## by `_on_damaged` and read by `_on_died`, which launches every corpse along the
## blow that killed it — so a body jabbed to death slumps and one finished with
## the spin sails. `_knockback` cannot be used for this: `_launch` zeroes it, and
## on a killing crit it is already zero by the time `died` fires.
var _last_hit_dir: Vector3 = Vector3.ZERO
var _last_hit_weight: float = 0.0
## What this one hits for, after the floor's curve and the elite bonus. Resolved
## once in `_build_combat` because the wind-up re-arms the hitbox on every swing
## and two places computing the same curve is one place to forget it.
var _damage: int = 0
var _flash := HitFlash.new()
var _recoil: Tween = null
## Where it woke up. The leash is measured from here, so a monster lured out of
## its room walks back to it rather than joining the conga line behind the hero.
var _anchor: Vector3 = Vector3.ZERO
## Which way it circles, +1 or -1. Fixed per monster rather than rerolled each
## time, so a pack splits and goes both ways round instead of all orbiting
## together like a carousel.
var _orbit: float = 1.0
## The model's rest pose, so the recoil and the wind-up lean can be measured
## from it rather than from wherever the last interrupted tween stopped.
var _model_rest: Vector3 = Vector3.ZERO
## True while the wind-up telegraph is holding the body's emission. See the
## guard at the top of `_physics_process`.
var _glowing: bool = false
## True while the freeze is holding the body's ALBEDO as well. Tracked separately
## from `_glowing` for the same reason it exists at all: leaving FROZEN is the
## only thing that can take the ice back down, and there are three ways out of it
## (the timer, a sword, dying). See the guard at the top of `_physics_process`.
var _frozen: bool = false
## Seconds of freeze left. Counts the whole of it, thaw included, so
## `_tick_frozen` can read one number for both "am I still stopped" and "how
## blue am I".
var _freeze_left: float = 0.0
var _freeze_total: float = 0.0

# --- The launch -------------------------------------------------------------
## True from the moment a blow throws this body until it comes to rest.
##
## Tracked as a FLAG and not read off the state, because the two states that can
## be airborne want completely different things from the rest of this file:
## LAUNCHED is a living body that will get up, and DEAD is a corpse that will
## not. Both fly on the same arc, and `_tick_flight` is the one piece of code
## that knows how.
var _airborne: bool = false
## Seconds this body has been off the ground. Only used to keep the landing check
## from firing on the launch frame itself, where `is_on_floor()` is still true.
var _air: float = 0.0
## Radians/sec the MODEL tumbles while airborne, signed. On the model and never
## on the body, for the reason `_flinch` gives: the body's yaw is the facing
## contract everything else reads (`docs/CONTRACT.md` §2.5).
var _tumble: float = 0.0
## One bounce, ever. See `_tick_flight`.
var _bounced: bool = false
## Seconds a landed body stays down before it gets up. Living bodies only.
var _down: float = 0.0


static func spawn(parent: Node3D, p_kind: StringName, at: Vector3, seed_val: int) -> Enemy:
	var e := Enemy.new()
	e.kind = p_kind
	e.drop_seed = seed_val
	parent.add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	_def = _resolve_def()
	_rng.seed = drop_seed if drop_seed != 0 else randi()

	add_to_group(&"enemy")
	add_to_group(&"targetable")
	collision_layer = K.L_ENEMY
	collision_mask = K.L_WORLD
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(55.0)

	_build_body()
	_build_model()
	_build_combat()
	_facing = rotation.y
	_anchor = global_position
	_orbit = 1.0 if _rng.randf() < 0.5 else -1.0


## Where a readout sits above this one's head, in world space.
##
## Public, and measured, because the HUD needs it and `_height()` is this class's
## business. The roster runs 1.25 m (goblin) to 1.95 m (orc), and an elite is
## `Prog.ELITE_SCALE` on top of that -- so a single constant offset in the HUD
## would float a hand above a goblin and cut through an orc's jaw. Same reason
## the model scale is fitted by measurement rather than tabled (`_build_model`).
func head_point() -> Vector3:
	return global_position + Vector3(0.0, _height() + HEAD_CLEARANCE, 0.0)


## Is this thing in a fight right now? Everything except asleep and dead.
##
## Lives here because the states are this class's business. `Music` used to carry
## a `[1, 2, 3, 4]` array of raw enum indices instead, which was not a style
## choice: there were two enemy scripts with different enums, and 1..4 was the
## range where they happened to agree. That roster is gone, and the magic numbers
## went with it -- they were also quietly wrong, because for THIS enum 1..4 stops
## at STRIKE, so a monster staggered by a hit or recovering from a swing counted
## as not fighting and only the linger timer kept the combat music up.
func is_engaged() -> bool:
	return state != State.IDLE and state != State.DEAD


## How tall this one stands. An elite is the same monster made BIGGER, which is
## the whole reason the variant works without any per-kind art: height is already
## the number the flinch, the swing sound and the hitbox all read, so one number
## makes an elite land heavier, sound heavier and reach further, and reads as a
## threat from across a dark room before it has done anything.
func _height() -> float:
	return float(_def["height"]) * (Prog.ELITE_SCALE if elite else 1.0)


# --- Construction -----------------------------------------------------------

## Where this body's stats come from. An ordinary monster reads `DEFS`; `Boss`
## reads `BossDb` instead, because a boss's health and reach are authored for one
## floor and are not a row in this table (`BossDb`'s executor contract, §2).
##
## An INSTANCE method and not a static, and the difference is not style: a bare
## static call written inside this class binds to `Enemy`'s copy at parse time
## and the subclass's override never runs, silently (`CLAUDE.md` §3). Virtual
## dispatch is only a property of instance methods.
##
## The `DEFS.get(kind, ...)` fallback is deliberately a FALLBACK and not an
## error: a director or a test scene may drop an unnamed body into a room and it
## should still be a monster. It is also the trap that hid the missing `troll`
## and `knight_iron` rows for as long as it did -- see the comment on those rows.
func _resolve_def() -> Dictionary:
	return DEFS.get(kind, DEFS[&"skeleton"])


## Last chance to touch the model's SURFACES before `HitFlash` binds them. A
## no-op here; `Boss` paints its authored tint in it.
##
## The ordering is the whole reason this hook exists rather than the caller doing
## it afterwards. `bind()` records each surface's colour as the baseline that
## `restore()` returns to, so a tint applied after binding is erased by the first
## landed blow -- the body flashes white and then reverts to a stock grey mesh
## for the rest of the fight, and the frame that shows it is the frame after the
## player's first hit.
func _style_model() -> void:
	pass


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var h := _height()
	cap.radius = clampf(h * 0.22, 0.22, 0.55)
	cap.height = maxf(h * 0.92, cap.radius * 2.0 + 0.05)
	col.shape = cap
	col.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(col)


func _build_model() -> void:
	var path := MODEL_DIR + String(kind) + ".glb"
	if not ResourceLoader.exists(path):
		push_error("enemy: no model at %s" % path)
		return
	_model = (load(path) as PackedScene).instantiate() as Node3D
	# MEASURED BY RENDER, not derived (docs/CONTRACT.md §2.5). The steering math
	# is right -- `rotation.y = heading + PI` makes the BODY's -Z point at the
	# player, which is what the rest of this file reads as facing -- but every
	# monster GLB is authored looking down +Z, so without this the mesh inside
	# that correct body showed the player its back. Same correction the hero's
	# FBX needs (`model_yaw_offset = 180`), for the same reason.
	#
	# Fix it HERE and not by dropping the +PI: `-basis.z is forward` is the
	# contract every other system reads an actor's facing through, and paying
	# for an art-space quirk by breaking that would move the bug rather than
	# remove it. tools/directors/monster_lookdev.gd is the render that settles
	# it -- the monsters must look AT the hero standing in front of them.
	_model.rotation.y = PI
	add_child(_model)

	# Scale by MEASUREMENT, not a hardcoded factor: the nine GLBs come from
	# different sources at different native sizes, and a table of per-monster
	# scale numbers is a table that goes stale the first time one is reimported.
	var native := _model_height(_model)
	if native > 0.001:
		_model.scale = Vector3.ONE * (_height() / native)

	# Recorded AFTER the art-space +PI and the scale fit, because those are the
	# rest pose as far as everything downstream is concerned. The recoil and the
	# wind-up lean both tween rotation.x/z back to this, never to zero -- zeroing
	# would undo the 180° the GLBs need and turn every struck monster around to
	# face away mid-flinch (docs/CONTRACT.md §2.5).
	_model_rest = _model.rotation
	# Before `bind`, never after. See `_style_model`.
	_style_model()
	_flash.bind(self, _model)

	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	# Evict the GLB's own stub library before adding the shared one, or Godot
	# rejects it: "Can't add animation library twice with name: ''".
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	var lib := load(LIBRARY) as AnimationLibrary
	if lib != null:
		_anim.add_animation_library(&"", lib)
	_play(&"idle", true)


func _build_combat() -> void:
	health = HealthComponent.new()
	health.name = "Health"
	# Bands, not level-scaling: this reads the FLOOR, never the player's power.
	# That is what keeps floor 1 genuinely easy on your fiftieth run and what
	# keeps the forge worth buying (docs/GDD.md §5).
	var mult := Prog.health_mult(level) * (Prog.ELITE_HEALTH if elite else 1.0)
	health.max_quarters = maxi(int(roundf(float(_def["health"]) * mult)), 1)
	# **A monster's i-frames are not the hero's**, and leaving this at the default
	# is what made the light chain's second step do nothing (see
	# K.ENEMY_IFRAME_TIME for the arithmetic). Set explicitly rather than by
	# changing the component's default, because the hero's second is right for the
	# hero and `HealthComponent` is shared.
	health.iframe_time = K.ENEMY_IFRAME_TIME
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	_hitbox = DamageArea.new()
	_hitbox.name = "Claw"
	_hitbox.collision_layer = K.L_ENEMY_HITBOX
	_hitbox.collision_mask = K.L_PLAYER
	_damage = int(_def["damage"]) + Prog.damage_bonus(level) \
		+ (Prog.ELITE_DAMAGE if elite else 0)
	_hitbox.amount = _damage
	_hitbox.kind = &"contact"
	# What the run-ending screen prints after "KILLED BY". The elite prefix is on
	# the name and not only on the stats because "ELITE ORC" is the whole story of
	# that death -- an ordinary orc and the bigger one you could see coming are
	# different rooms (see `elite`), and a screen that called both of them ORC
	# would flatten the one distinction the roster is built on.
	_hitbox.source = StringName(("ELITE " if elite else "") + String(kind).to_upper())
	_hitbox.knockback = K.KNOCKBACK_LIGHT
	_hitbox.position = Vector3(0.0, _height() * 0.55, -float(_def["reach"]) * 0.7)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(_def["reach"]) * 0.62
	col.shape = sphere
	_hitbox.add_child(col)
	add_child(_hitbox)


static func _model_height(n: Node3D) -> float:
	var acc := AABB()
	var first := true
	for mi in _meshes(n):
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			acc = b
			first = false
		else:
			acc = acc.merge(b)
	return acc.size.y


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## `blend` is the cross-fade INTO `clip`, in seconds. 0.15 everywhere by default,
## because walking into a wind-up should ease -- but a flinch passes something
## much shorter, and that is not a detail. A blow is the one thing in this file
## that has to CUT: a 0.15 s fade into a reel the body only holds for 0.30 s
## spends half of it still standing in the pose it was already in, which is what
## "there's no flinch off the first attack" looked like from the player's seat.
func _play(clip: StringName, loop: bool = false, speed: float = 1.0,
		blend: float = 0.15) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == String(clip) and loop:
		return
	_anim.play(String(clip), blend, speed)
	var a := _anim.get_animation(clip)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


## The `speed` that makes `clip` last exactly `seconds`. 1.0 when the clip is
## missing or the window is nonsense, so a body with a short library plays at its
## own pace rather than at infinity.
func _clip_speed(clip: StringName, seconds: float) -> float:
	if _anim == null or not _anim.has_animation(clip) or seconds <= 0.01:
		return 1.0
	var a := _anim.get_animation(clip)
	if a == null or a.length <= 0.01:
		return 1.0
	return a.length / seconds


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		# A corpse that was thrown finishes its arc. `_on_died` launches every
		# kill, so this is the usual path and not the exception -- and it has to
		# be checked BEFORE the line below, which zeroes the horizontal velocity
		# and would drop every launched body straight down out of the air.
		if _airborne:
			_tick_flight(delta)
		else:
			velocity = Vector3(0, velocity.y - K.GRAVITY * delta, 0)
		move_and_slide()
		# NOT `rotation.y = _facing`: a corpse mid-flight is being tumbled by
		# `_tick_flight` and re-stamping the yaw here is harmless, but the DEAD
		# branch has always returned before that line and the sink tween below
		# depends on nothing else touching this transform.
		return

	_cooldown = maxf(_cooldown - delta, 0.0)
	_player = _find_player()

	# The wind-up glow is written every frame by `_tick_windup` and owns no timer,
	# so leaving the wind-up is the only thing that can take it back down. Doing
	# that here, off the state itself, rather than at each exit, means the next
	# person to add a way out of WINDUP cannot forget to -- and the failure they
	# would ship is a monster standing in a quiet room glowing hot for ever.
	# `_on_damaged` clears the flag before calling `_flash.hit()`, because the
	# white flash supersedes the glow and must not be wiped by this the next frame.
	if _glowing and state != State.WINDUP:
		_glowing = false
		_flash.restore()
	# The same guard, for the same reason, over the ice. There are three ways out
	# of FROZEN — the timer runs out, a sword lands, the thing dies — and only one
	# of them goes through `_tick_frozen`. Clearing it here, off the state itself,
	# means the next person to add a fourth cannot ship a monster that is blue for
	# the rest of the run. Both `_on_damaged` and `_on_died` drop the flag before
	# writing their own colour, so this cannot wipe them the next frame.
	if _frozen and state != State.FROZEN:
		_thaw_body()
		_flash.restore()

	match state:
		State.IDLE:
			_tick_idle()
		State.CHASE:
			_tick_chase(delta)
		State.CIRCLE:
			_tick_circle(delta)
		State.WINDUP:
			_tick_windup(delta)
		State.STRIKE:
			_tick_strike(delta)
		State.RECOVER:
			_tick_recover(delta)
		State.HURT:
			_tick_hurt(delta)
		State.LAUNCHED:
			_tick_launched(delta)
		State.FROZEN:
			_tick_frozen(delta)

	# ONE owner for the vertical, chosen by whether this body is in the air.
	#
	# The `_airborne` arm is not defensive. A launch is set up on a frame where
	# the body is still standing ON the ground, so the floor clamp below would
	# overwrite the upward velocity between the blow and the next frame -- and
	# every launch in the game would be a monster sliding along the floor.
	if _airborne:
		_tick_flight(delta)
	elif not is_on_floor():
		velocity.y -= K.GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	rotation.y = _facing


func _find_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _to_player() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	return _player.global_position - global_position


func _distance() -> float:
	if _player == null:
		return INF
	return Vector2(_to_player().x, _to_player().z).length()


func _face_player(delta: float, rate_deg: float = 420.0) -> void:
	_face_heading(K.flat(_to_player()), delta, rate_deg)


## Turn toward a flat direction. The models face -Z like every other Node3D, so
## the heading yaw needs the same +PI the hero applies (docs/CONTRACT.md §2.5).
func _face_heading(d: Vector3, delta: float, rate_deg: float = 420.0) -> void:
	if d == Vector3.ZERO:
		return
	var want := atan2(d.x, d.z) + PI
	var err := wrapf(want - _facing, -PI, PI)
	var step := deg_to_rad(rate_deg) * delta
	_facing += clampf(err, -step, step)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# --- States -----------------------------------------------------------------

## Push apart from the other monsters nearby.
##
## Without this a pack is not a pack. Every one of them steers at the same point
## with the same rule, so they converge on the hero's face and stack into a
## single silhouette -- you cannot tell three goblins from one, you cannot tell
## which of them is winding up, and the wind-up tell built in the last commit is
## wasted because it is happening inside another body. Six lines of repulsion is
## the difference between a crowd and a smear.
##
## Linear in the number of monsters and run per monster, so quadratic overall --
## which is fine at the 13 a floor spawns and would not be at 300. If a room ever
## holds a swarm this wants a grid; it does not want a NavigationAgent3D, because
## the problem is spacing and not pathing.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group(&"enemy"):
		if other == self:
			continue
		var body := other as Node3D
		if body == null or not is_instance_valid(body):
			continue
		# K.plane, not K.flat: flat normalises, so `d` would be 1.0 for every
		# monster on the floor and this would shove between rooms at full strength.
		var away := K.plane(global_position - body.global_position)
		var d := away.length()
		if d > CROWD_RADIUS or d <= 0.001:
			continue
		# Falls off with distance, so a monster just inside the radius drifts and
		# one standing inside another shoves hard.
		push += away.normalized() * (1.0 - d / CROWD_RADIUS)
	return push * CROWD_PUSH


## Walk `dir` at `speed`, with the crowd shove folded in. Everything that moves
## goes through here so no state can forget the spacing.
func _steer(dir: Vector3, speed: float) -> void:
	var want := dir * speed + _separation()
	velocity.x = want.x
	velocity.z = want.z


func _tick_idle() -> void:
	_play(&"idle", true)
	if _player != null and _distance() <= float(_def["detect"]):
		state = State.CHASE
		return

	# Nothing to fight: go back to where you woke up. A monster lured across the
	# floor and then abandoned used to stand wherever the chase ended, so a
	# cleared room slowly filled with other rooms' monsters standing in doorways.
	var home := K.plane(_anchor - global_position)
	if home.length() > 1.0:
		_face_heading(home, get_physics_process_delta_time(), 200.0)
		_steer(home.normalized(), float(_def["speed"]) * 0.55)
		_play(&"walk_fwd", true, 0.8)
	else:
		_stop()


func _tick_chase(delta: float) -> void:
	if _player == null:
		state = State.IDLE
		return
	var dist := _distance()
	# Two ways to lose interest, and the leash is the one that matters. Detection
	# alone means a monster follows the hero to the far side of the floor and
	# stays there, so every room he passes through donates its monsters to the
	# room he is standing in and the last room of a run holds all of them.
	if dist > float(_def["detect"]) * 1.35 \
			or K.plane(global_position - _anchor).length() > LEASH:
		state = State.IDLE
		return

	_face_player(delta)
	if dist <= float(_def["reach"]) and _cooldown <= 0.0:
		state = State.WINDUP
		# Compressed with depth, but never past Prog.WINDUP_FLOOR. The telegraph
		# is what makes a fight fair, so it is the one number with a hard floor --
		# a wind-up you cannot react to is a coin flip, not difficulty.
		_timer = float(_def["windup"]) * Prog.windup_scale(level)
		_struck = false
		_stop()
		_play(&"attack_1")
		return

	# Stop short of the hero's own capsule so a crowd does not shove him around.
	var stop_at: float = float(_def["reach"]) * 0.85
	if dist > stop_at:
		var speed: float = _def["speed"]
		_steer(K.flat(_to_player()), speed)
		_play(&"walk_fwd", true, clampf(speed / 2.2, 0.7, 1.6))
	else:
		# In reach but still on cooldown. Keep the spacing anyway -- standing
		# perfectly still here is what let a second monster walk inside the
		# first one while it waited.
		_steer(Vector3.ZERO, 0.0)
		_play(&"idle", true)


## Circle the hero at reach instead of walking straight back in.
##
## Without this, a pack QUEUES. Everyone runs to the same point, everyone is on
## the same cooldown clock, and the fight becomes a line of monsters taking turns
## at the front while the ones behind stand still -- which is both boring and
## easy, because you only ever fight one at a time. Circling spreads them around
## the hero, so the threat becomes positional: the one you can see is not the one
## about to hit you, and turning to face it is a real decision.
##
## It is a beat between attacks and not a permanent state; `_timer` ends it and
## the cooldown is what decides whether the next one is a swing.
func _tick_circle(delta: float) -> void:
	if _player == null:
		state = State.IDLE
		return
	_timer -= delta
	var dist := _distance()
	if _timer <= 0.0 or dist > float(_def["detect"]):
		state = State.CHASE
		return

	# Keep looking at him while sidestepping -- a monster that turns its back to
	# orbit reads as having lost interest, and it is about to attack.
	_face_player(delta, 260.0)

	var to_hero := K.flat(_to_player())
	if to_hero == Vector3.ZERO:
		return
	var inward := to_hero.normalized()
	# Perpendicular, in the fixed direction this monster picked at spawn.
	var side := Vector3(-inward.z, 0.0, inward.x) * _orbit
	# Hold station at a comfortable ring: drift in if it has fallen back, out if
	# it is crowding, so the orbit does not spiral into or away from him.
	var ring: float = float(_def["reach"]) * 1.5
	var correct := inward * clampf((dist - ring) * 0.8, -1.0, 1.0)
	_steer((side + correct).normalized(), float(_def["speed"]) * 0.75)
	_play(&"walk_fwd", true, 0.95)


## The tell. A wind-up the player can read is the difference between a fight and
## a coin flip — the enemy stands still and telegraphs before it commits.
##
## The animation cannot carry this on its own and it never could. Every monster
## GLB ships a near-empty clip set (the goblin's is 0.03 s), and the shared
## `monster_library` clips are not cut to each kind's wind-up length — so
## `attack_1` finishes long before an orc's 0.62 s commit and the frame the
## player actually has to read is a monster standing perfectly still. That is
## what the capture showed: a wind-up you cannot see is not a tell, it is a coin
## flip with extra steps.
##
## So the telegraph is driven here, from the timer that actually governs it: the
## body rears BACK over the wind-up and glows hot, both scaled by how far through
## the commit it is. It reads in a dark room, at a distance, on any of the nine
## models, and it cannot fall out of sync with the thing it is warning about.
func _tick_windup(delta: float) -> void:
	_stop()
	_timer -= delta
	# Still tracks during the wind-up, but slowly, so sidestepping works.
	_face_player(delta, 130.0)

	if _model != null:
		var windup: float = maxf(float(_def["windup"]), 0.001)
		# 0 at the start of the commit, 1 at the moment it lands.
		var t := clampf(1.0 - _timer / windup, 0.0, 1.0)
		# Eased so the last third of the wind-up is where most of the movement
		# is: a linear rear-back reads as a slow lean, and the player needs the
		# spike, not the drift.
		var e := t * t
		_model.rotation.x = _model_rest.x - deg_to_rad(WINDUP_LEAN_DEG) * e
		# 0.22, not the 0.55 this started at. At 0.55 the telegraph works too
		# well: the body goes to a flat, featureless orange silhouette, and a
		# monster you cannot read the pose of is not a monster you can react to.
		# A tell should tint the thing, not replace it.
		_flash.glow(Pal.RUST, e * 0.22)
		_glowing = true

	if _timer <= 0.0:
		state = State.STRIKE
		_timer = 0.18
		_struck = true
		_hitbox.amount = _damage
		_hitbox.activate()
		# The commit itself: the glow snaps off as the body whips forward, so
		# "it is coming" and "it is here" are two different pictures.
		_glowing = false
		_flash.restore()
		_lunge_pose()
		# Weight, in one byte of data. A 1.95 m orc committing and a 1.25 m
		# goblin committing should not make the same noise, and height is
		# already the number that says which is which.
		Bus.request_sfx.emit(
			&"swing_heavy" if _height() >= 1.70 else &"swing",
			global_position)


## Whip the body through the blow and let it settle. Not a knockback and not the
## clip -- it is the 0.18 s the hitbox is open, made visible.
func _lunge_pose() -> void:
	if _model == null:
		return
	_kill_recoil()
	_model.rotation.x = _model_rest.x + deg_to_rad(WINDUP_LEAN_DEG * 0.7)
	_recoil = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_recoil.tween_property(_model, ^"rotation:x", _model_rest.x, 0.26)


func _tick_strike(delta: float) -> void:
	_stop()
	_timer -= delta
	if _timer <= 0.0:
		if _struck:
			_hitbox.deactivate()
			_struck = false
		state = State.RECOVER
		_timer = float(_def["recover"])


func _tick_recover(delta: float) -> void:
	_stop()
	_timer -= delta
	if _timer <= 0.0:
		_cooldown = float(_def["cooldown"])
		# Most of the time, back off and circle rather than walking straight
		# back into reach. Not always: an orc that never once pressed forward
		# would be trivially kited, and the roster needs kinds that come at you.
		# The slow heavy ones re-engage more often, the quick ones dance more --
		# so speed, which is already the number that separates them, doubles as
		# their temperament and no per-kind table is needed.
		var dances := clampf(float(_def["speed"]) / 5.0, 0.25, 0.75)
		if _rng.randf() < dances:
			state = State.CIRCLE
			_timer = _rng.randf_range(0.5, 1.1)
		else:
			state = State.CHASE


func _tick_hurt(delta: float) -> void:
	_timer -= delta
	_knockback = _knockback.move_toward(Vector3.ZERO, 26.0 * delta)
	# The shove wins while it lasts, but the crowd rule still applies underneath
	# it -- two monsters knocked into the same spot should not end up inside each
	# other and stay there once the knockback has bled off.
	var push := _separation()
	velocity.x = _knockback.x + push.x
	velocity.z = _knockback.z + push.z
	if _timer <= 0.0:
		_knockback = Vector3.ZERO
		state = State.CHASE


# --- The launch -------------------------------------------------------------
## What a committed blow does that a jab does not: it takes the body off the
## ground. This is the game's critical hit — there is no separate crit roll and
## no crit multiplier, because a launch already IS the thing a crit is for. The
## screen shakes harder, the world stops longer, a star goes off at the contact
## point and the monster is out of the fight while it flies and while it gets up.
##
## Two ways in, and they are deliberately different:
##
##   * **A living body** is launched by CHANCE, on committed blows only, and the
##     odds are the square of the mass ratio (`K.LAUNCH_CHANCE`). A goblin flies
##     two heavy blows in three; a troll flies one in seven.
##   * **A death always launches**, with no roll, because the force is already
##     continuous — a body killed by a jab barely leaves the floor and one killed
##     by the spin sails. A coin flip on top of that would only mean some kills
##     end with a corpse standing perfectly still, which is the one thing a kill
##     must never look like.

## May this body be thrown at all? True for a monster; `Boss` says no.
##
## An INSTANCE method, not a static, and CLAUDE.md §3 is why: a bare static call
## written inside this class binds to `Enemy`'s copy at parse time and the
## subclass's override never runs, silently. Same reason `_resolve_def` is one.
##
## A boss is a set-piece in an authored arena — it has poise (`Boss._on_damaged`
## does not even take the state), its beats are what the fight is, and a body
## that can be knocked out of one is a fight the player can delete. The corpse
## does not fly either: the arena unseals around it and the drop is placed where
## it fell, so a boss sliding into a wall is a relic behind the scenery.
func _can_launch() -> bool:
	return true


## Thrown off its feet without being hurt. **This is the parry's whole payout**,
## and it is the one thing in this file that moves a body without damaging it.
##
## `from` is where the shove came from — the hero's position, not the blow's,
## because the blow being parried was the MONSTER'S and its `from` is this
## body's own feet.
##
## It borrows the launch roll rather than reimplementing a knockback, which is
## what makes a parried goblin behave exactly like a critically-struck one:
## `weight` 0.95 is nearly the top of the impact scale (docs/BESTIARY.md §3.5),
## so the small bodies go up almost every time and a troll takes the stagger
## standing. That mass rule is the reason a parry does not need a per-enemy
## table — it already reads differently against every body in the roster.
##
## A launched body does NOT also get the HURT state: `_launch` has taken the
## state, and setting HURT over it would land the thing mid-flight into a reel
## it should be in the air for. Same rule `_on_damaged` follows.
func stagger(from: Vector3, seconds: float, shove: float) -> void:
	if state == State.DEAD:
		return
	# The wind-up it was in is over. `_struck` guards a live contact hitbox, and
	# a monster parried mid-commit that kept its box would go on to hit the hero
	# with the swing he just caught.
	if _struck:
		_hitbox.deactivate()
		_struck = false
	var away := K.flat(global_position - from)
	if away == Vector3.ZERO:
		away = Vector3(0, 0, 1).rotated(Vector3.UP, _facing)
	_last_hit_dir = away
	_last_hit_weight = 1.0
	_knockback = away * shove
	if not _try_launch(away, 0.95):
		state = State.HURT
		_timer = seconds
		var clip := &"hurt_heavy"
		_play(clip, false, _clip_speed(clip, seconds), 0.04)
		_flinch(away)
	# The opening, stated as a number the AI obeys: it does not get to swing
	# again the instant it is upright. Longer than the stagger itself, which is
	# the difference between "it stopped" and "you have a moment".
	_cooldown = maxf(_cooldown, seconds + 0.5)
	_glowing = false
	_thaw_body()
	_flash.hit()


## How hard `knock` shoved, as 0..1. See `K.SHAKE_TAP` for why every channel of
## an impact reads this one number. Public and static so a director can assert on
## the same value the game used, rather than on a re-derivation of it.
static func blow_weight(knock: float) -> float:
	var span := K.KNOCKBACK_HEAVY - K.KNOCKBACK_LIGHT
	if span <= 0.0:
		return 0.0
	return clampf((knock - K.KNOCKBACK_LIGHT) / span, 0.0, 1.0)


## `K.LAUNCH_MASS_REF / _height()`. Above 1 for the small bodies, below 1 for the
## big ones, and an elite is scaled taller so it resists for free.
func _mass_ratio() -> float:
	return K.LAUNCH_MASS_REF / maxf(_height(), 0.4)


## Roll for it. True if this blow threw the body, in which case the caller must
## not also put it into HURT — `_launch` has already taken the state.
func _try_launch(away: Vector3, weight: float) -> bool:
	if weight <= 0.0 or state == State.DEAD or not _can_launch():
		return false
	var odds := clampf(K.LAUNCH_CHANCE * pow(_mass_ratio(), 2.0) * weight,
		K.LAUNCH_CHANCE_MIN, K.LAUNCH_CHANCE_MAX)
	if _rng.randf() > odds:
		return false
	_launch(away, weight)
	return true


## Throw this body along `away` at a force set by the blow and the body's mass.
##
## Safe to call on a corpse — `_on_died` does exactly that — and the state is
## only taken for a LIVING one, because DEAD outranks it and a corpse must not be
## resurrected into LAUNCHED by its own killing blow.
func _launch(away: Vector3, weight: float) -> void:
	var dir := K.flat(away)
	if dir == Vector3.ZERO:
		dir = Vector3(0, 0, 1).rotated(Vector3.UP, _facing)
	var mass := _mass_ratio()
	# Linear in the mass ratio where the ODDS are squared: "less far for big
	# guys" is real but it is the smaller half of the read. See K.LAUNCH_CHANCE.
	var force := mass * (0.45 + 0.55 * weight)

	velocity.x = dir.x * K.LAUNCH_OUT * force
	velocity.z = dir.z * K.LAUNCH_OUT * force
	velocity.y = K.LAUNCH_UP * force

	_airborne = true
	_air = 0.0
	_bounced = false
	_knockback = Vector3.ZERO
	# Which way it spins is which way it was hit, so a body knocked to the left
	# and one knocked to the right do not perform the same canned somersault.
	var right := Vector3(cos(_facing), 0.0, -sin(_facing))
	var side := signf(right.dot(dir))
	if side == 0.0:
		side = 1.0
	_tumble = deg_to_rad(K.LAUNCH_SPIN) * mass * side

	# The wind-up is off the table: a monster thrown mid-commit must not land
	# still holding the swing. Same argument as `freeze`, and the same fix.
	if _struck and _hitbox != null:
		_hitbox.deactivate()
		_struck = false
	_kill_recoil()
	if state != State.DEAD:
		state = State.LAUNCHED
		# It cannot swing the instant it gets up either -- the launch is supposed
		# to buy the player the moment it costs to land one.
		_cooldown = maxf(_cooldown, K.LAUNCH_DOWN + 0.35)


## Alive and in the air. The arc is `_tick_flight`'s; this only decides what
## happens once it stops, which is the half a corpse does not want.
func _tick_launched(delta: float) -> void:
	if _airborne:
		return
	# Down, then up. `_down` is set by `_land`.
	_down -= delta
	_stop()
	if _down <= 0.0:
		state = State.CHASE


## The arc, shared by a living body and a corpse. Owns the vertical while
## `_airborne` is set — see the call site in `_physics_process`.
##
## Horizontal velocity is left ALONE rather than damped: air does not slow a
## thrown goblin down enough to matter over 0.8 s, and `_separation`'s crowd
## shove is deliberately not applied here. A launched body being nudged by the
## monsters it flies past is an arc that bends for no reason the player can see.
func _tick_flight(delta: float) -> void:
	_air += delta
	velocity.y -= K.GRAVITY * delta
	if _model != null:
		_model.rotation.x += _tumble * delta

	# `_air` guards the launch frame, where the body has upward velocity but has
	# not left the ground yet and `is_on_floor()` is still true.
	if _air < 0.05 or not is_on_floor():
		return

	# One bounce, and only off a landing hard enough to earn it. A second would
	# be a body pinballing around the room, which reads as a physics bug rather
	# than as weight.
	var speed := absf(velocity.y)
	if not _bounced and speed > 3.0:
		_bounced = true
		_air = 0.0
		velocity.y = speed * K.LAUNCH_BOUNCE
		velocity.x *= 0.45
		velocity.z *= 0.45
		_tumble *= 0.4
		Bus.request_sfx.emit(&"land", global_position)
		return
	_touch_down()


## Down, and everything the landing owes the player.
func _touch_down() -> void:
	_airborne = false
	_air = 0.0
	_tumble = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_down = K.LAUNCH_DOWN
	# Back to rest, always. A body left at whatever pitch the tumble stopped on
	# is a monster that gets up and walks around lying on its side.
	if _model != null:
		_kill_recoil()
		_recoil = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_recoil.tween_property(_model, ^"rotation:x", _model_rest.x, 0.3)
	# The landing is the punchline of the launch and it needs a noise and a
	# nudge, or a body arrives back on the floor silently and the throw ends on
	# nothing. Heavier bodies land harder -- height is already the number that
	# says which is which, exactly as it is for the swing sound.
	var heavy := _height() >= 1.70
	Bus.request_sfx.emit(&"land_hard" if heavy else &"land", global_position)
	Bus.request_shake.emit(0.24 if heavy else 0.16, 0.16)


## Where on the body a blow landed, in world space: the point on its near surface
## facing whatever hit it, at chest height.
##
## `Hit.from` is the ATTACKER's hitbox centre, not a contact point — a sword's
## DamageArea is a sphere hanging off the hero, so drawing the burst there would
## put it on the hero's blade rather than on the thing that got hit. The radius
## below is `_build_body`'s capsule radius, so the mark sits on the silhouette.
func _impact_point(from: Vector3) -> Vector3:
	var chest := global_position + Vector3.UP * (_height() * 0.55)
	var toward := K.flat(from - chest)
	if toward == Vector3.ZERO:
		return chest
	return chest + toward * clampf(_height() * 0.22, 0.22, 0.55)


# --- The freeze -------------------------------------------------------------
## What the hookshot does to a body. Not damage — `HealthComponent.apply_hit`
## refuses a zero-quarter blow outright, and it should: a chain with a barb on
## the end that chips a monster's health would make the hookshot a bad bow, when
## what it actually is is the thing that buys you the swing.
##
## Deliberately NOT a state of its own in some parallel status-effect machine.
## The one thing a freeze has to be able to do is INTERRUPT — a monster caught
## mid-wind-up must not resume that wind-up when it thaws, or the freeze is a
## pause button on an attack that is still coming — and interrupting is what
## `state = ...` already means in this file.

## Stop this thing dead for `seconds`, doing no damage. Safe to call on a corpse
## and safe to call on something already frozen, which REFRESHES rather than
## stacks: two hooks in a second are two seconds of freeze end to end, never a
## body that has to thaw twice.
func freeze(seconds: float = K.HOOK_FREEZE) -> void:
	if state == State.DEAD or seconds <= 0.0:
		return
	# Whatever it was doing, it is not doing it now. A swing already in the air
	# is taken out of the air with it — the hitbox is open for 0.18 s and a
	# frozen monster whose claw still lands is the freeze doing nothing.
	if _struck:
		_hitbox.deactivate()
		_struck = false
	_stop()
	_knockback = Vector3.ZERO
	# Hooked out of the air. The arc ends where the chain caught it and the body
	# drops rather than completing the throw — leaving `_airborne` set would have
	# `_tick_flight` keep flying it across the room while it sat there frozen and
	# blue, which is the freeze visibly not working.
	_airborne = false
	_air = 0.0
	_tumble = 0.0
	_kill_recoil()
	if _model != null:
		# Back to rest before the ice, not left mid-lean: the pose a body holds
		# for a whole second is a pose the player reads, and half a wind-up frozen
		# solid reads as "still winding up".
		_model.rotation = _model_rest
	state = State.FROZEN
	_freeze_total = seconds
	_freeze_left = seconds
	# The white flash and the wind-up glow both lose to this, so drop their flags
	# rather than letting the guards in `_physics_process` restore over the ice.
	_glowing = false
	_frozen = true
	# It cannot swing the instant it thaws either. Without this a monster frozen
	# mid-wind-up comes back with a spent cooldown and commits immediately, and
	# the second you paid a shot for buys you nothing but a delay.
	_cooldown = maxf(_cooldown, seconds + 0.25)
	# Stop the CLOCK, do not change the clip. The first cut of this played `idle`
	# and the render caught it out immediately: the body stood there working
	# through the idle loop, waving its arms, tinted blue. A thing that is still
	# moving is not frozen however cold it looks, and a blue monster in motion
	# reads as a status effect you can ignore. Stopping the clock instead also
	# leaves it caught in whatever pose the freeze interrupted — mid-stride,
	# mid-reach — which is the picture ice is supposed to make. `_play` would
	# have been worse than useless here anyway: a blend of 0.15 s cannot advance
	# on a clock that is not running, so it would have stuck the body halfway
	# between two clips for the whole second.
	if _anim != null:
		_anim.speed_scale = 0.0
	# The hit's weight without the hit: the world stops for a few frames and the
	# chain rings off bone. Sfx owns which sound (docs/CONTRACT.md §8); this only
	# says what happened and where.
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	# `arrow_body_impact`, not the smith's `craft_clang` that was here: the only
	# caller of `freeze` is the hookshot biting a monster (hero_ranged.gd), and
	# that is a metal head arriving in a body, not iron on an anvil. The anchor
	# case, which really is metal on stone, rings `hit_armor` at the impact
	# point instead — the two halves of the shot no longer share one wrong sound.
	Bus.request_sfx.emit(&"arrow_body_impact", global_position)


## Let go of everything the freeze is HOLDING — the flag and the stopped
## animation clock — without deciding what colour the body should be next. The
## three ways out of FROZEN each want a different answer to that (the guard
## restores, a blow flashes white, a death clears), and only the clock is common.
##
## Not folded into the guard in `_physics_process`, because `_on_died` returns
## from that function before the guard is reached: a monster killed while frozen
## would keep `speed_scale = 0.0` and its death clip would never play a frame.
func _thaw_body() -> void:
	_frozen = false
	if _anim != null:
		_anim.speed_scale = 1.0


## True while this one is iced. Public because the hookshot needs to know
## whether a second shot is a refresh, and because a director has to be able to
## assert on it.
func is_frozen() -> bool:
	return state == State.FROZEN


## Hold still and thaw. The tint is written EVERY frame rather than tweened, for
## the reason `_tick_windup` writes the glow every frame: a tween that outlives
## the state it belongs to is a body stuck at whatever colour the tween was on.
func _tick_frozen(delta: float) -> void:
	_stop()
	_freeze_left -= delta
	if _freeze_left <= 0.0:
		# Out into CHASE, not back into whatever was interrupted. `_cooldown`
		# above is what stops that from being a free swing.
		state = State.CHASE
		return
	# 1.0 for the solid half, then down to 0 across the tail — the thaw.
	var thaw := maxf(K.HOOK_THAW * _freeze_total, 0.001)
	_flash.ice(Pal.FROST, clampf(_freeze_left / thaw, 0.0, 1.0))


# --- Damage and death -------------------------------------------------------

func _on_damaged(hit: Hit) -> void:
	if state == State.DEAD:
		return
	# Stamped on every landed blow, read once by `_die`. It is what made the
	# killing blow, which is the only question the Returning Shaft asks -- see
	# there for why the LAST one and not "was it ever shot".
	_last_hit_kind = hit.kind
	if _struck:
		_hitbox.deactivate()
		_struck = false
	var dir := K.flat(global_position - hit.from)
	if dir == Vector3.ZERO:
		dir = Vector3(0, 0, 1).rotated(Vector3.UP, _facing)
	_knockback = dir * maxf(hit.knockback, 1.0)
	# Interrupting a wind-up is the reward for reading the tell and going first.
	# Without the cooldown push a monster struck mid-commit recovers into another
	# commit immediately, so hitting it first bought nothing and the telegraph
	# was decoration. The push NEVER shortens an existing cooldown -- `maxf` --
	# or a flurry of light hits would be a way to make an orc attack faster.
	var interrupted := state == State.WINDUP
	_last_hit_dir = dir

	# **How hard this one hit, as one number** (`K.SHAKE_TAP`). Everything below
	# is scaled by it, so a jab and the spin cannot end up wearing each other's
	# feedback and there is no per-move table to keep in step.
	var weight := blow_weight(hit.knockback)
	_last_hit_weight = weight
	# The crit IS the launch. Rolled before the feedback rather than after,
	# because every channel below wants to know: a blow that threw the body gets
	# the star, the longer stop and the bigger shake, and one that did not gets a
	# scuff. Two rolls would be two answers to one question.
	var crit := _try_launch(dir, weight)

	if not crit:
		state = State.HURT
		_timer = maxf(hit.stun, 0.22)
	_cooldown = maxf(_cooldown, maxf(_timer, 0.22) + (0.45 if interrupted else 0.2))
	# Two reels, and which one is the size of the blow rather than the name of the
	# attack. `hurt_heavy` is 0.87 s against `hurt`'s 0.60 -- a bigger movement, so
	# a finisher, a spin or an overhead reads as a different event from a jab
	# without the roster needing a per-attack table. A whole heart is the line
	# because that is what separates the light chain's steps (2 quarters) from
	# everything the player pays commitment for (4 and up).
	#
	# Sped up to fit the reel it is given, never left to run at its own pace: both
	# clips outlast the stun, and a body still swinging back through its recovery
	# while `_tick_hurt` has already handed it to CHASE is the stagger visibly
	# disagreeing with the state machine.
	#
	# The length is ASKED FOR, not written down. A literal here is a number that
	# is right until somebody retrims the shared library, and the failure it would
	# ship is a reel that plays at the wrong speed in a file that never mentions
	# animation lengths.
	var heavy := hit.amount >= K.HEART
	var clip: StringName = &"hurt_heavy" if heavy else &"hurt"
	_play(clip, false, _clip_speed(clip, maxf(_timer, 0.22)), 0.04)

	# What a blow is made of, in the order the player receives it: the world
	# stops, the body goes white, it reels, the camera kicks, and it makes a
	# noise. Every one of these is a request -- Feel and Sfx own the answers, so
	# nothing here holds a player or a camera (docs/CONTRACT.md §8).
	#
	# **All of it scales with `weight` now, and the shake is why.** This asked for
	# 0.52 trauma on EVERY landed blow including the cheapest jab in the game --
	# and `Feel` accumulates trauma while the light chain lands three hits inside
	# 1.2 s, so the weakest attack available pinned the camera at maximum and
	# there was nothing left for the spin to escalate to. Feel's own scale reads
	# "0.2 a tap, 0.5 a solid hit"; a tap is now a twitch and the committed blows
	# have the top of the range to themselves.
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY if crit
		else int(roundf(lerpf(float(K.HITSTOP_LIGHT), float(K.HITSTOP_HEAVY), weight))))
	Bus.request_shake.emit(
		K.SHAKE_CRIT if crit else lerpf(K.SHAKE_TAP, K.SHAKE_HIT, weight),
		lerpf(0.12, 0.2, weight))
	# The mark at the spot, which is the one channel that says WHERE it landed
	# rather than only that it did. Parented to the scene and not to this body:
	# a launched monster leaves at 6 m/s and a burst riding its chest would fly
	# away with it, when the whole point is that the hit happened HERE.
	ImpactVfx.spawn(get_tree().current_scene, _impact_point(hit.from), weight, crit)
	# Cleared before the flash, not after: the white supersedes any wind-up glow
	# and any ice, and leaving a flag set would have the guard restore over it
	# next frame. Hitting a frozen monster therefore THAWS it — it takes the blow
	# and reels, which is the honest reading of a body that just got hit, and the
	# `state = State.HURT` above has already taken it out of FROZEN anyway.
	_glowing = false
	_thaw_body()
	_flash.hit()
	# Not on a crit: the reel is a tween on the model's rotation and the tumble is
	# writing that same property every frame. Two owners of one transform is a
	# body that twitches in mid-air instead of somersaulting.
	if not crit:
		_flinch(dir)
	# The noise is NOT requested here. `hit_landed` already says exactly what
	# happened and where, and Sfx owns the signal->sound table -- an enemy that
	# picked its own impact sound is how the goblin ends up louder than the orc
	# (scripts/autoload/sfx.gd). The training post emits this too, and gets the
	# same sound for free.
	Bus.hit_landed.emit(self, hit.amount, global_position)


## Reel away from the blow. On the MODEL, never on the body: the body's yaw is
## the facing contract everything else reads (docs/CONTRACT.md §2.5) and its
## position is being driven by the knockback in the same breath.
##
## Rapid hits REPLACE the recoil rather than stack it -- three tweens fighting
## over one rotation is a body that vibrates instead of one that reels.
func _flinch(away: Vector3) -> void:
	if _model == null:
		return
	_kill_recoil()
	# Which way it rocks depends on which side the blow came from, so a flurry
	# from one direction does not look like the same canned twitch each time.
	var right := Vector3(cos(_facing), 0.0, -sin(_facing))
	var side := signf(right.dot(away))
	if side == 0.0:
		side = 1.0
	# Bigger bodies barely move. A 1.25 m goblin is thrown about; a 1.95 m orc
	# takes the hit and leans, which is most of what makes them feel different
	# to fight without a single line of per-kind feedback code.
	var heft := clampf(1.5 / _height(), 0.45, 1.5)
	var roll := deg_to_rad(15.0) * heft * side
	var pitch := deg_to_rad(10.0) * heft

	_recoil = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recoil.set_parallel(true)
	_recoil.tween_property(_model, ^"rotation:z", _model_rest.z + roll, 0.05)
	_recoil.tween_property(_model, ^"rotation:x", _model_rest.x + pitch, 0.05)
	_recoil.chain().tween_property(_model, ^"rotation:z", _model_rest.z, 0.24)
	_recoil.parallel().tween_property(_model, ^"rotation:x", _model_rest.x, 0.24)


func _kill_recoil() -> void:
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	_recoil = null


func _on_died() -> void:
	state = State.DEAD
	_stop()
	# Guarded, because a body is allowed not to have one. `Boss` builds no contact
	# hitbox at all -- every quarter-heart it deals comes from an authored beat's
	# shape -- and an unguarded `queue_free()` here killed it on the frame it died,
	# taking the drop and `Bus.boss_defeated` down with it.
	if _hitbox != null:
		if _struck:
			_hitbox.deactivate()
		_hitbox.queue_free()
	collision_layer = 0
	remove_from_group(&"targetable")
	_play(&"death")
	# Settle the body before the death clip runs. Without this a monster killed
	# mid-flash is a corpse frozen white, one killed mid-wind-up dies still
	# glowing the warning colour for a blow it never threw, and one killed while
	# iced dies blue and stays that way — `clear()` is the only thing that puts
	# the albedo back, so the flag has to come down with it.
	_kill_recoil()
	_glowing = false
	_thaw_body()
	_flash.clear()
	if _model != null:
		_model.rotation = _model_rest

	# **Every kill throws the body**, along the blow that killed it and scaled by
	# how hard that blow was — so a monster jabbed to death crumples where it
	# stood and one finished with the spin is launched across the room. No roll
	# here, unlike a living body (`_try_launch`): the force is already continuous,
	# and a coin flip on top of it would only mean some kills end with a corpse
	# standing perfectly still, which is the one thing a kill must never look
	# like.
	#
	# Guarded, because the killing blow may ALREADY have launched this body as a
	# crit while it was alive. Re-launching would add a second impulse to a corpse
	# mid-flight and bend the arc in the air.
	if not _airborne and _can_launch():
		# `+ 0.35` so even a jab-kill leaves the floor a little. A corpse that
		# only ever slumps when you finish it cheaply is honest; one that never
		# moves at all reads as the body freezing on the frame it died.
		_launch(_last_hit_dir, minf(_last_hit_weight + 0.35, 1.0))

	# A kill is a heavier event than a hit and has to feel like one. Sfx already
	# answers `enemy_died`; this is the part of it the screen does. Scaled by the
	# killing blow like everything else -- see `_on_damaged`.
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	Bus.request_shake.emit(lerpf(0.38, 0.68, _last_hit_weight), 0.26)

	_drop_loot()
	# The Returning Shaft (`EchoDb.RETURNING_SHAFT`): an arrow is recovered from
	# what it killed. `_last_hit_kind` is the killing blow's -- an enemy softened
	# with the sword and finished with an arrow gives one back, one shot with the
	# bow and finished with the sword does not, which is the honest reading of
	# "from what it killed". The bow stops being rationed, so range becomes an
	# option at depth rather than a budget (`docs/METAGAME.md` §4.6).
	if _last_hit_kind == &"arrow":
		var back := int(Run.echo(EchoDb.RETURNING_SHAFT))
		if back > 0:
			Game.add_arrows(back)
	died_at.emit(global_position)
	Bus.enemy_died.emit(self, global_position)

	# Let the death animation read before the body goes. Sinking it out rather
	# than popping it: a corpse that vanishes mid-frame reads as a bug.
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	await tree.create_timer(2.2).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(self, ^"position:y", position.y - 1.6, 0.9)
	await tw.finished
	queue_free()


## Rolls from `ItemDb.ENEMY_DROPS` and drops physical motes rather than
## crediting the bag: the bag is the thing the
## player is deciding about, and a number that moves while you are still
## swinging teaches nothing (docs/METAGAME.md §3).
##
## Motes are parented to `current_scene`, not to this enemy -- the corpse sinks
## into the floor and frees itself, and a drop parented to it would go with it.
##
## Bigger things pay more. `drops` scales with the kind's health so a wraith is
## worth walking back to and a goblin is not, which is what makes the roster a
## difficulty curve rather than a skin swap.
func _drop_loot() -> void:
	var health_max: int = _def.get("health", 6)
	# Two curves multiplied, on purpose. The kind's health is WHAT it is worth,
	# and the floor is HOW MUCH the floor pays -- a goblin stays a goblin's worth
	# of loot relative to a wraith, all the way down. Without the floor half,
	# going deeper would be strictly worse: the extraction fee scales with what
	# you are carrying, so a deep floor would cost more and pay the same.
	var count := (1 + int(health_max / 7)) * Prog.drop_rolls(Run.level)
	if elite:
		count += 1
	# The Blazing Tithe (`EchoDb.BLAZING_TITHE`): at the top rung of the chain a
	# killed body leaves one MORE. The top tier finally pays in quantity and not
	# only in rate -- and it is the one Echo whose value the player has to keep
	# earning, because a chain that lapses stops paying it (`docs/PUZZLES.md`
	# §6.1, row 5).
	if Heat.blazing():
		count += int(Run.echo(EchoDb.BLAZING_TITHE))
	var table := ItemDb.enemy_drops(Run.level)
	for i in count:
		var id := ItemDb.roll(table, Run.rng)
		if id == &"":
			continue
		var a := Run.rng.randf_range(0.0, TAU)
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.6,
			Vector3(sin(a), 0.0, cos(a)) * Run.rng.randf_range(0.5, 1.1))
