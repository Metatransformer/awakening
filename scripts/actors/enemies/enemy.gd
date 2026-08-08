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
func _tick_windup(delta: float) -> void:
	_stop()
	_timer -= delta
	# Still tracks during the wind-up, but slowly, so sidestepping works.
	_face_player(delta, 130.0)
	if _timer <= 0.0:
		state = State.STRIKE
		_timer = 0.18
		_struck = true
		_hitbox.amount = int(_def["damage"])
		_hitbox.activate()


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
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.22, 0.12)


func _on_died() -> void:
	state = State.DEAD
	_stop()
	if _struck:
		_hitbox.deactivate()
	_hitbox.queue_free()
	collision_layer = 0
	remove_from_group(&"targetable")
	_play(&"death")

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
