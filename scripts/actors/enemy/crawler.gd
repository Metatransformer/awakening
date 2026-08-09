class_name Crawler
extends CharacterBody3D
## The one enemy the MVP has. Sees you, walks at you, winds up, lunges.
##
## Deliberately simple, and deliberately TELEGRAPHED: it rears back and holds
## for 0.45 s before every lunge. That pause is the entire fight -- it is the
## window to block, roll or hit it first -- and it is why an enemy this basic is
## still a fight rather than a damage tax. A crawler that just touched you for
## damage would make the dungeon a maze with a health drain in it.
##
## Built from boxes in code, like the dungeon kit, so it needs no imported asset
## and matches the kit's hard-edged silhouette.

enum State { IDLE, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

@export_group("Body")
@export var body_color: Color = Color(0.30, 0.26, 0.34)
@export var carapace_color: Color = Color(0.16, 0.14, 0.20)
@export var eye_color: Color = Pal.VITAL
@export var body_scale: float = 1.0

@export_group("Health")
## Three sword hits at 2 quarters each. Enough that a swing feels like progress
## and not enough that a room of four is a chore. [tune]
@export var max_quarters: int = 6

@export_group("Senses")
@export var aggro_range: float = 9.0
## Hysteresis, like the lock-on band: without it a crawler at exactly the aggro
## distance flickers between walking at you and forgetting you exist.
@export var deaggro_range: float = 14.0

@export_group("Movement")
@export var speed: float = 2.5
@export var turn_rate: float = 320.0
@export var gravity: float = K.GRAVITY

@export_group("Attack")
@export var strike_range: float = 1.7
@export var windup_time: float = 0.45
@export var lunge_time: float = 0.20
@export var lunge_speed: float = 8.5
@export var recover_time: float = 0.65
@export var damage: int = 2 * K.QUARTER
@export var knockback: float = K.KNOCKBACK_LIGHT

@export_group("Loot")
## Rolls from ItemDb.ENEMY_DROPS. 1 means every kill pays something, which is
## what keeps clearing a room worth doing when the chest is the real prize.
@export var drops: int = 1

var state: State = State.IDLE
var health: HealthComponent

var _body: Node3D
var _mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _timer: float = 0.0
var _facing: float = 0.0
var _lunge_dir: Vector3 = Vector3.FORWARD
var _hit_this_lunge: bool = false
var _flash: float = 0.0
var _stun: float = 0.0
var _knock: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"targetable")
	add_to_group(&"hurtbox")
	collision_layer = K.L_ENEMY
	collision_mask = K.L_WORLD
	floor_snap_length = 0.4
	up_direction = Vector3.UP
	_facing = rotation.y

	health = HealthComponent.new()
	health.name = "Health"
	health.max_quarters = max_quarters
	health.iframe_time = 0.12
	add_child(health)
	health.died.connect(_on_died)

	_build()


## Where a lock-on reticle sits. docs/CONTRACT.md §8.
func target_point() -> Vector3:
	return global_position + Vector3(0.0, 0.85 * body_scale, 0.0)


## The damage contract's entry point (docs/CONTRACT.md §8). `take_hit` is the
## name `DamageArea._deliver` looks for, and it has to exist here or the crawler
## is hurt THROUGH its HealthComponent child instead of through this function --
## which lands the damage and silently skips the flash, the knockback, the stun
## and the wind-up cancel below. `HeroCombat` and `Arrow` find `apply_hit` on the
## node first and so were never affected, which is exactly why that would have
## looked like "the crawler flinches from the sword but not from anything else".
func take_hit(hit: Hit) -> bool:
	return apply_hit(hit)


func apply_hit(hit: Hit) -> bool:
	if state == State.DEAD:
		return false
	if not health.apply_hit(hit):
		return false
	_flash = 1.0
	# The same impact the monsters ask for, so the shallow-water fight and the
	# roster fight land with the same weight. Feel and Sfx own the answers.
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	Bus.request_shake.emit(0.50, 0.14)
	Bus.hit_landed.emit(self, hit.amount, global_position)
	_stun = maxf(_stun, hit.stun if hit.stun > 0.0 else 0.22)
	var away := K.flat(global_position - hit.from)
	if away == Vector3.ZERO:
		away = -_forward()
	_knock = away * maxf(hit.knockback, 3.0)
	# Being hit while winding up cancels the lunge. That is the reward for
	# reading the telegraph and going first.
	if state == State.WINDUP:
		state = State.RECOVER
		_timer = recover_time * 0.6
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	_flash = maxf(0.0, _flash - delta * 6.0)
	_mat.emission_energy_multiplier = _flash * 3.2

	if _knock != Vector3.ZERO:
		velocity.x = _knock.x
		velocity.z = _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, 46.0 * delta)
	if _stun > 0.0:
		_stun -= delta
		move_and_slide()
		return

	var hero := _hero()
	match state:
		State.IDLE: _tick_idle(hero)
		State.CHASE: _tick_chase(hero, delta)
		State.WINDUP: _tick_windup(delta)
		State.LUNGE: _tick_lunge(delta)
		State.RECOVER: _tick_recover(delta)

	rotation.y = _facing
	move_and_slide()


# --- States -----------------------------------------------------------------

func _tick_idle(hero: Node3D) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if hero != null and global_position.distance_to(hero.global_position) <= aggro_range:
		state = State.CHASE


func _tick_chase(hero: Node3D, delta: float) -> void:
	if hero == null:
		state = State.IDLE
		return
	var to := K.flat(hero.global_position - global_position)
	var dist := global_position.distance_to(hero.global_position)
	if dist > deaggro_range:
		state = State.IDLE
		return

	_steer(to, delta)
	if dist <= strike_range:
		state = State.WINDUP
		_timer = windup_time
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# Only walk once roughly pointed the right way, so it turns THEN moves rather
	# than crabbing sideways at you.
	var aim := absf(wrapf(atan2(to.x, to.z) - _facing, -PI, PI))
	var gate: float = 1.0 if aim < 0.9 else 0.25
	velocity.x = to.x * speed * gate
	velocity.z = to.z * speed * gate


func _tick_windup(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_timer -= delta
	# Rears back: pulls AWAY from the target for the whole telegraph, so the
	# read is a silhouette change and not a colour change.
	var t := 1.0 - clampf(_timer / maxf(windup_time, 0.01), 0.0, 1.0)
	_body.position.y = 0.10 * sin(t * PI) * body_scale
	_body.rotation.x = deg_to_rad(-22.0) * sin(t * PI)
	if _timer <= 0.0:
		state = State.LUNGE
		_timer = lunge_time
		_lunge_dir = _forward()
		_hit_this_lunge = false


func _tick_lunge(delta: float) -> void:
	_timer -= delta
	velocity.x = _lunge_dir.x * lunge_speed
	velocity.z = _lunge_dir.z * lunge_speed
	_body.rotation.x = deg_to_rad(18.0)
	if not _hit_this_lunge:
		_try_connect()
	if _timer <= 0.0:
		state = State.RECOVER
		_timer = recover_time
		_body.rotation.x = 0.0


func _tick_recover(delta: float) -> void:
	_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	_body.position.y = 0.0
	_body.rotation.x = 0.0
	if _timer <= 0.0:
		state = State.CHASE


func _try_connect() -> void:
	var hero := _hero()
	if hero == null:
		return
	if global_position.distance_to(hero.global_position) > strike_range * 1.15:
		return
	_hit_this_lunge = true
	var hit := Hit.make(damage, global_position, &"contact", knockback, 0.0)
	if hero.has_method("take_hit"):
		hero.take_hit(hit)


# --- Death ------------------------------------------------------------------

func _on_died() -> void:
	state = State.DEAD
	collision_layer = 0
	remove_from_group(&"targetable")
	remove_from_group(&"hurtbox")
	# A kill is heavier than a hit, and reads the same for both enemy types.
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	Bus.request_shake.emit(0.62, 0.24)
	Bus.enemy_died.emit(self, global_position)

	for i in maxi(drops, 0):
		var id := ItemDb.roll(ItemDb.ENEMY_DROPS, Run.rng)
		if id == &"":
			continue
		var a := Run.rng.randf_range(0.0, TAU)
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.6,
			Vector3(sin(a), 0.0, cos(a)) * Run.rng.randf_range(0.5, 1.1))

	# Collapses into the floor rather than exploding: the kit has no gib pass and
	# a sink reads as "gone" without needing one.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "scale", Vector3(1.3, 0.06, 1.3) * body_scale, 0.30) \
		.set_ease(Tween.EASE_IN)
	tw.tween_property(_body, "position:y", -0.35, 0.30)
	tw.chain().tween_callback(queue_free)


# --- Helpers ----------------------------------------------------------------

func _hero() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _forward() -> Vector3:
	return Vector3(sin(_facing), 0.0, cos(_facing))


func _steer(dir: Vector3, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var want := atan2(dir.x, dir.z)
	var err := wrapf(want - _facing, -PI, PI)
	var step := deg_to_rad(turn_rate) * delta
	_facing += clampf(err, -step, step)


# --- Construction -----------------------------------------------------------

func _build() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42 * body_scale
	cap.height = 1.05 * body_scale
	col.shape = cap
	col.position.y = 0.53 * body_scale
	add_child(col)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = body_color
	_mat.roughness = 0.95
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.emission_enabled = true
	_mat.emission = Pal.BONE
	_mat.emission_energy_multiplier = 0.0

	var shell := StandardMaterial3D.new()
	shell.albedo_color = carapace_color
	shell.roughness = 0.8
	shell.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# Squat trunk, low and wide -- it should read as something that scuttles, and
	# a tall box reads as a person.
	var trunk := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.74, 0.52, 0.92) * body_scale
	trunk.mesh = tm
	trunk.material_override = _mat
	trunk.position.y = 0.52 * body_scale
	_body.add_child(trunk)

	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.82, 0.20, 0.78) * body_scale
	plate.mesh = pm
	plate.material_override = shell
	plate.position = Vector3(0.0, 0.80, -0.04) * body_scale
	_body.add_child(plate)

	var snout := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.40, 0.30, 0.34) * body_scale
	snout.mesh = sm
	snout.material_override = shell
	snout.position = Vector3(0.0, 0.50, 0.56) * body_scale
	_body.add_child(snout)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = eye_color
	_eye_mat.emission_enabled = true
	_eye_mat.emission = eye_color
	_eye_mat.emission_energy_multiplier = 2.6
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.09, 0.07, 0.05) * body_scale
		eye.mesh = em
		eye.material_override = _eye_mat
		eye.position = Vector3(0.11 * sx, 0.57, 0.72) * body_scale
		_body.add_child(eye)

	# Six stubby legs. They do not animate; the body's rear-and-lunge carries the
	# motion, and six static legs still fix the silhouette as "not a person".
	for i in 6:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.11, 0.30, 0.11) * body_scale
		leg.mesh = lm
		leg.material_override = shell
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var row := float(i / 2) - 1.0
		leg.position = Vector3(0.40 * side, 0.16, row * 0.34) * body_scale
		leg.rotation.z = deg_to_rad(14.0 * side)
		_body.add_child(leg)
