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

enum State { IDLE, CHASE, CIRCLE, WINDUP, STRIKE, RECOVER, HURT, DEAD }

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


static func spawn(parent: Node3D, p_kind: StringName, at: Vector3, seed_val: int) -> Enemy:
	var e := Enemy.new()
	e.kind = p_kind
	e.drop_seed = seed_val
	parent.add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	_def = DEFS.get(kind, DEFS[&"skeleton"])
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


func _play(clip: StringName, loop: bool = false, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == String(clip) and loop:
		return
	_anim.play(String(clip), 0.15, speed)
	var a := _anim.get_animation(clip)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector3(0, velocity.y - K.GRAVITY * delta, 0)
		move_and_slide()
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

	if not is_on_floor():
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


# --- Damage and death -------------------------------------------------------

func _on_damaged(hit: Hit) -> void:
	if state == State.DEAD:
		return
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
	state = State.HURT
	_timer = maxf(hit.stun, 0.22)
	_cooldown = maxf(_cooldown, _timer + (0.45 if interrupted else 0.2))
	_play(&"hurt")

	# What a blow is made of, in the order the player receives it: the world
	# stops, the body goes white, it reels, the camera kicks, and it makes a
	# noise. Every one of these is a request -- Feel and Sfx own the answers, so
	# nothing here holds a player or a camera (docs/CONTRACT.md §8).
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.52, 0.16)
	# Cleared before the flash, not after: the white supersedes any wind-up glow,
	# and leaving the flag set would have the guard restore over it next frame.
	_glowing = false
	_flash.hit()
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
	if _struck:
		_hitbox.deactivate()
	_hitbox.queue_free()
	collision_layer = 0
	remove_from_group(&"targetable")
	_play(&"death")
	# Settle the body before the death clip runs. Without this a monster killed
	# mid-flash is a corpse frozen white, and one killed mid-wind-up dies still
	# glowing the warning colour for a blow it never threw.
	_kill_recoil()
	_flash.clear()
	if _model != null:
		_model.rotation = _model_rest
	# A kill is a heavier event than a hit and has to feel like one. Sfx already
	# answers `enemy_died`; this is the part of it the screen does.
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	Bus.request_shake.emit(0.68, 0.26)

	_drop_loot()
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
	var table := ItemDb.enemy_drops(Run.level)
	for i in count:
		var id := ItemDb.roll(table, Run.rng)
		if id == &"":
			continue
		var a := Run.rng.randf_range(0.0, TAU)
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.6,
			Vector3(sin(a), 0.0, cos(a)) * Run.rng.randf_range(0.5, 1.1))
