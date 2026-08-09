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

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, HURT, DEAD }

const LIBRARY := "res://assets/animations/monster_library.res"
const MODEL_DIR := "res://assets/monsters/"

## How far the body rears back over a wind-up, in degrees. Big enough to read
## across a dark room, small enough that it is a tell and not a backflip.
const WINDUP_LEAN_DEG := 17.0

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
var _flash := HitFlash.new()
var _recoil: Tween = null
## The model's rest pose, so the recoil and the wind-up lean can be measured
## from it rather than from wherever the last interrupted tween stopped.
var _model_rest: Vector3 = Vector3.ZERO


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


# --- Construction -----------------------------------------------------------

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var h: float = _def["height"]
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
		_model.scale = Vector3.ONE * (float(_def["height"]) / native)

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
	health.max_quarters = int(_def["health"])
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	_hitbox = DamageArea.new()
	_hitbox.name = "Claw"
	_hitbox.collision_layer = K.L_ENEMY_HITBOX
	_hitbox.collision_mask = K.L_PLAYER
	_hitbox.amount = int(_def["damage"])
	_hitbox.kind = &"contact"
	_hitbox.knockback = K.KNOCKBACK_LIGHT
	_hitbox.position = Vector3(0.0, float(_def["height"]) * 0.55, -float(_def["reach"]) * 0.7)
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

	match state:
		State.IDLE:
			_tick_idle()
		State.CHASE:
			_tick_chase(delta)
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
	var d := K.flat(_to_player())
	if d == Vector3.ZERO:
		return
	# The models face -Z like every other Node3D, so the heading yaw needs the
	# same +PI the hero applies.
	var want := atan2(d.x, d.z) + PI
	var err := wrapf(want - _facing, -PI, PI)
	var step := deg_to_rad(rate_deg) * delta
	_facing += clampf(err, -step, step)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# --- States -----------------------------------------------------------------

func _tick_idle() -> void:
	_stop()
	_play(&"idle", true)
	if _player != null and _distance() <= float(_def["detect"]):
		state = State.CHASE


func _tick_chase(delta: float) -> void:
	if _player == null:
		state = State.IDLE
		return
	var dist := _distance()
	if dist > float(_def["detect"]) * 1.35:
		state = State.IDLE
		return

	_face_player(delta)
	if dist <= float(_def["reach"]) and _cooldown <= 0.0:
		state = State.WINDUP
		_timer = float(_def["windup"])
		_struck = false
		_stop()
		_play(&"attack_1")
		return

	# Stop short of the hero's own capsule so a crowd does not shove him around.
	var stop_at: float = float(_def["reach"]) * 0.85
	if dist > stop_at:
		var dir := K.flat(_to_player())
		var speed: float = _def["speed"]
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_play(&"walk_fwd", true, clampf(speed / 2.2, 0.7, 1.6))
	else:
		_stop()
		_play(&"idle", true)


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
		_flash.glow(Pal.RUST, e * 0.55)

	if _timer <= 0.0:
		state = State.STRIKE
		_timer = 0.18
		_struck = true
		_hitbox.amount = int(_def["damage"])
		_hitbox.activate()
		# The commit itself: the glow snaps off as the body whips forward, so
		# "it is coming" and "it is here" are two different pictures.
		_flash.restore()
		_lunge_pose()
		# Weight, in one byte of data. A 1.95 m orc committing and a 1.25 m
		# goblin committing should not make the same noise, and height is
		# already the number that says which is which.
		Bus.request_sfx.emit(
			&"swing_heavy" if float(_def["height"]) >= 1.70 else &"swing",
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
		state = State.CHASE


func _tick_hurt(delta: float) -> void:
	_timer -= delta
	_knockback = _knockback.move_toward(Vector3.ZERO, 26.0 * delta)
	velocity.x = _knockback.x
	velocity.z = _knockback.z
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
	state = State.HURT
	_timer = maxf(hit.stun, 0.22)
	_play(&"hurt")

	# What a blow is made of, in the order the player receives it: the world
	# stops, the body goes white, it reels, the camera kicks, and it makes a
	# noise. Every one of these is a request -- Feel and Sfx own the answers, so
	# nothing here holds a player or a camera (docs/CONTRACT.md §8).
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.28, 0.16)
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
	var heft := clampf(1.5 / float(_def["height"]), 0.45, 1.5)
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
	Bus.request_shake.emit(0.42, 0.26)

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


## Rolls from `ItemDb.ENEMY_DROPS`, the same table the crawler pulls from, and
## drops physical motes rather than crediting the bag: the bag is the thing the
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
	var count := 1 + int(health_max / 7)
	for i in count:
		var id := ItemDb.roll(ItemDb.ENEMY_DROPS, Run.rng)
		if id == &"":
			continue
		var a := Run.rng.randf_range(0.0, TAU)
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.6,
			Vector3(sin(a), 0.0, cos(a)) * Run.rng.randf_range(0.5, 1.1))
