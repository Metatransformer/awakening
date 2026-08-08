class_name TrainingPost
extends StaticBody3D
## A practice dummy. Lock onto it, hit it, and see exactly what you did.
##
## This is a TEST FIXTURE as much as a prop: it is how you tell, by looking,
## whether a sword swing connected, what it dealt, where the hit registered,
## and whether Z-targeting will hold a lock. Every other package can validate
## against it before enemies exist.
##
## It is deliberately forward-compatible with the damage contract
## (docs/CONTRACT.md §8): it answers `apply_hit(hit)` with the same signature a
## HealthComponent does, so when P4's sword lands it will already work here.
## When P4 ships `health_component.gd`, this can delegate to one instead.

## Emitted on every registered hit, for anything that wants to count.
signal struck(amount: int, from: Vector3)

@export_group("Body")
@export var post_height: float = 1.8
@export var post_radius: float = 0.16
## The strike target — the bound bundle the sword is meant to meet.
@export var pad_height: float = 0.55
@export var pad_radius: float = 0.34

@export_group("Reaction")
## Degrees the post rocks away from a full-strength hit.
@export var wobble_deg: float = 14.0
## Seconds for the rocking to settle. It is a spring, so it overshoots.
@export var wobble_time: float = 0.9
@export var flash_time: float = 0.12
## Show floating damage numbers and a running total. Off for a scenic prop.
@export var show_readout: bool = true
## Seconds of no hits before the running total clears itself.
@export var readout_reset: float = 4.0

@export_group("Audio")
@export var hit_sfx: AudioStream = preload("res://audio/sfx/block_impact_1.ogg")

var total_damage: int = 0
var hit_count: int = 0

var _pivot: Node3D
var _pad: MeshInstance3D
var _pad_mat: StandardMaterial3D
var _readout: Label3D
var _sfx: AudioStreamPlayer3D
var _wobble_vel: Vector2 = Vector2.ZERO   ## angular velocity, x=pitch z=roll
var _wobble_ang: Vector2 = Vector2.ZERO   ## current lean
var _flash: float = 0.0
var _idle: float = 0.0


func _ready() -> void:
	add_to_group(&"targetable")
	add_to_group(&"hurtbox")
	collision_layer = K.L_WORLD | K.L_INTERACT
	collision_mask = 0
	_build()


## Where a lock-on reticle sits. docs/CONTRACT.md §8 — every targetable has this.
func target_point() -> Vector3:
	return global_position + Vector3(0, post_height * 0.82, 0)


## The damage contract's entry point. `hit` is P4's Hit resource, but this only
## reads `amount` and `from`, so it also accepts anything duck-typed to those —
## which is what lets it work before P4 exists.
func apply_hit(hit) -> void:
	var amount: int = 0
	var from: Vector3 = global_position + Vector3(0, 1, 1)
	if hit != null:
		if "amount" in hit:
			amount = int(hit.amount)
		if "from" in hit:
			from = hit.from
	_register(amount, from)


## Convenience for anything that has not built a Hit yet.
func strike(amount: int, from: Vector3) -> void:
	_register(amount, from)


func _register(amount: int, from: Vector3) -> void:
	hit_count += 1
	total_damage += amount
	_idle = 0.0
	_flash = 1.0

	# Rock away from the striker, scaled by how hard it was hit. A quarter-heart
	# tap should visibly differ from a spin attack.
	var dir := K.flat(global_position - from)
	if dir == Vector3.ZERO:
		dir = -global_transform.basis.z
	var force := clampf(float(maxi(amount, 1)) / float(K.HEART), 0.25, 2.0)
	var kick := deg_to_rad(wobble_deg) * force / maxf(wobble_time * 0.25, 0.01)
	_wobble_vel += Vector2(dir.z, -dir.x) * kick

	if _sfx:
		_sfx.pitch_scale = randf_range(0.92, 1.08)
		_sfx.play()
	if show_readout:
		_popup(amount)
		_refresh_readout()

	struck.emit(amount, from)
	Bus.hit_landed.emit(self, amount, target_point())


func _physics_process(delta: float) -> void:
	# Critically-damped-ish spring back to upright: stiff enough to settle inside
	# wobble_time, slack enough to overshoot once so it reads as wood, not rubber.
	var omega := TAU / maxf(wobble_time, 0.05)
	_wobble_vel -= (_wobble_ang * omega * omega + _wobble_vel * 2.0 * omega) * delta
	_wobble_ang += _wobble_vel * delta
	var cap := deg_to_rad(wobble_deg * 2.0)
	_wobble_ang = _wobble_ang.limit_length(cap)
	if _pivot:
		_pivot.rotation.x = _wobble_ang.x
		_pivot.rotation.z = _wobble_ang.y

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta / maxf(flash_time, 0.01))
		if _pad_mat:
			_pad_mat.emission_energy_multiplier = _flash * 3.0

	if show_readout and hit_count > 0:
		_idle += delta
		if _idle > readout_reset:
			hit_count = 0
			total_damage = 0
			_refresh_readout()


# --- Construction -----------------------------------------------------------
# Built in code so a post can be dropped anywhere with no .tscn wiring, and so
# the dimensions above actually drive the geometry instead of drifting from it.

func _build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.29, 0.20, 0.13)
	wood.roughness = 0.92

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = post_radius * 0.85
	pm.bottom_radius = post_radius
	pm.height = post_height
	pm.radial_segments = 8  # N64-era silhouette: faceted, not smooth
	post.mesh = pm
	post.material_override = wood
	post.position.y = post_height * 0.5
	_pivot.add_child(post)

	# The bound straw bundle you actually aim at.
	_pad_mat = StandardMaterial3D.new()
	_pad_mat.albedo_color = Color(0.68, 0.55, 0.28)
	_pad_mat.roughness = 1.0
	_pad_mat.emission_enabled = true
	_pad_mat.emission = Color(1.0, 0.86, 0.6)
	_pad_mat.emission_energy_multiplier = 0.0

	_pad = MeshInstance3D.new()
	var padm := CylinderMesh.new()
	padm.top_radius = pad_radius
	padm.bottom_radius = pad_radius
	padm.height = pad_height
	padm.radial_segments = 10
	_pad.mesh = padm
	_pad.material_override = _pad_mat
	_pad.position.y = post_height * 0.82
	_pivot.add_child(_pad)

	for i in 2:
		var rope := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = pad_radius * 0.97
		rm.outer_radius = pad_radius * 1.10
		rm.rings = 10
		rope.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.16, 0.12, 0.08)
		rope.material_override = rmat
		rope.position.y = post_height * 0.82 + (0.14 if i == 0 else -0.14)
		_pivot.add_child(rope)

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.16, 0.7)
	base.mesh = bm
	base.material_override = wood
	base.position.y = 0.08
	add_child(base)

	# One capsule covering post and pad — the sword should connect anywhere
	# sensible, not only on a thin cylinder.
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(pad_radius, post_radius) * 0.95
	cap.height = post_height
	col.shape = cap
	col.position.y = post_height * 0.5
	add_child(col)

	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = hit_sfx
	_sfx.bus = &"SFX"
	_sfx.unit_size = 6.0
	_sfx.position.y = post_height * 0.8
	add_child(_sfx)

	if show_readout:
		_readout = Label3D.new()
		_readout.font_size = 64
		_readout.pixel_size = 0.0022
		_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_readout.no_depth_test = true
		_readout.modulate = Color(1, 0.92, 0.6)
		_readout.outline_size = 18
		_readout.position.y = post_height + 0.42
		add_child(_readout)
		_refresh_readout()


func _refresh_readout() -> void:
	if _readout == null:
		return
	if hit_count == 0:
		_readout.text = ""
		return
	# Damage is in quarter-hearts (K.HEART == 4), so report both — the raw number
	# a system passed, and what it means in the currency the HUD draws.
	_readout.text = "%d hit%s   %d q  (%.2f ♥)" % [
		hit_count, "" if hit_count == 1 else "s",
		total_damage, float(total_damage) / float(K.HEART),
	]


## A single damage number that floats up and fades, so a fast combo still reads.
func _popup(amount: int) -> void:
	var l := Label3D.new()
	l.text = str(amount)
	l.font_size = 96
	l.pixel_size = 0.0020
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 20
	l.modulate = Color(1.0, 0.42, 0.32) if amount > 0 else Color(0.65, 0.65, 0.7)
	l.position = Vector3(randf_range(-0.28, 0.28), post_height * 0.9, randf_range(-0.1, 0.1))
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.1, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.85).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)
