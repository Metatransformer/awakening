class_name ProvisionPickup
extends Area3D
## Counted carried provisions found in the dungeon. They go straight to `Game`:
## never through `Run.bag`, loot value, heat, or extraction settlement.
##
## `staged` plus `reveal()` lets a room hide one until its `RoomWatch.cleared`
## signal. The pickup owns only that wake-up motion; the Dungeon remains the
## later package's authority for choosing provision ids and rates.

const SUPPORTED_IDS: Array[StringName] = [
	&"escape_rope", &"hardtack", &"small_beer",
]
const ARM_TIME := 0.35
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.055
const SPIN_SPEED := 0.65
const REST_Y := 0.24
const LIGHT_Y := 0.56
const LIGHT_ENERGY := 0.38
const LIGHT_RANGE := 1.35
const REVEAL_RISE := 0.28
const REVEAL_TIME := 0.52

## Stable save/generator-facing identity and amount. A placer sets these before
## adding the pickup to the tree.
@export var provision_id: StringName = &"escape_rope"
@export_range(1, 20, 1) var count: int = 1
@export var staged: bool = false

var _rig: Node3D
var _light: OmniLight3D
var _materials: Array[StandardMaterial3D] = []
var _age: float = 0.0
var _refused: float = 0.0
var _reveal_offset: float = 0.0
var _revealed: bool = true
var _revealing: bool = false
var _taken: bool = false
var _reveal_tween: Tween


func _ready() -> void:
	if not SUPPORTED_IDS.has(provision_id):
		provision_id = &"escape_rope"
	count = maxi(count, 1)
	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.78
	collision.shape = sphere
	collision.position.y = 0.28
	add_child(collision)

	_build()
	if staged:
		stage()


## Put an already-instanced pickup away. Safe before or after `_ready()`.
func stage() -> void:
	staged = true
	_revealed = false
	_revealing = false
	visible = false
	monitoring = false


## Wake a staged clear reward with a compact rise. Idempotent, and never revives
## provision stock that has already been collected.
func reveal() -> void:
	if _taken or _revealed:
		return
	_revealed = true
	_revealing = true
	staged = false
	visible = true
	monitoring = true
	_reveal_offset = -REVEAL_RISE
	if _rig != null:
		_rig.scale = Vector3.ONE * 0.68
	if _light != null:
		_light.light_energy = LIGHT_ENERGY * 0.2
	if _reveal_tween != null:
		_reveal_tween.kill()
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, ^"_reveal_offset", 0.0, REVEAL_TIME)
	if _rig != null:
		_reveal_tween.tween_property(_rig, ^"scale", Vector3.ONE, REVEAL_TIME)
	if _light != null:
		_reveal_tween.tween_property(
			_light, ^"light_energy", LIGHT_ENERGY, REVEAL_TIME)
	_reveal_tween.chain().tween_callback(_finish_reveal)


func is_revealed() -> bool:
	return _revealed


func is_revealing() -> bool:
	return _revealing


func _finish_reveal() -> void:
	_reveal_offset = 0.0
	_revealing = false
	_reveal_tween = null


func _process(delta: float) -> void:
	if not _revealed or _taken or _rig == null:
		return
	_age += delta
	var bob := sin(_age * BOB_SPEED) * BOB_HEIGHT
	_rig.position.y = REST_Y + bob + _reveal_offset
	_rig.rotation.y += SPIN_SPEED * delta
	if _light != null:
		_light.position.y = LIGHT_Y + bob + _reveal_offset

	if _refused > 0.0:
		_refused = maxf(0.0, _refused - delta)
		_light.light_energy = LIGHT_ENERGY \
			+ (0.5 + 0.5 * sin(_age * 14.0)) * 0.65
		return
	_light.light_energy = LIGHT_ENERGY
	if _age < ARM_TIME:
		return
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			_take()
			return


## The only mutation door: Rope stock through its own counted provision seam,
## and food/drink through the ration seam. A full stack pulses, says why, and
## leaves the physical pickup available for later.
func _take() -> void:
	var got := 0
	match provision_id:
		&"escape_rope":
			got = Game.add_escape_ropes(count)
		&"hardtack", &"small_beer":
			got = Game.add_rations(provision_id, count)
	if got <= 0:
		_refused = 0.9
		Bus.request_message.emit("%s STOCK FULL" % _display_name().to_upper())
		return

	_taken = true
	Bus.request_sfx.emit(&"pickup", global_position)
	Bus.request_message.emit("%s  +%d" % [_display_name(), got])
	_pop()


func _display_name() -> String:
	if provision_id == &"escape_rope":
		return "Escape Rope"
	return RationDb.name_of(provision_id)


## Rise and actually fade, rather than relying on scale alone to imply it.
func _pop() -> void:
	monitoring = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rig, ^"position:y", _rig.position.y + 0.72, 0.28) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, ^"scale", Vector3.ONE * 0.12, 0.28) \
		.set_ease(Tween.EASE_IN)
	if _light != null:
		tween.tween_property(_light, ^"light_energy", 0.0, 0.28)
	for material: StandardMaterial3D in _materials:
		tween.tween_property(material, ^"albedo_color:a", 0.0, 0.28)
	tween.chain().tween_callback(queue_free)


# --- Compact procedural silhouettes ----------------------------------------

func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Provision"
	_rig.position.y = REST_Y
	add_child(_rig)

	match provision_id:
		&"escape_rope": _build_rope()
		&"hardtack": _build_hardtack()
		&"small_beer": _build_small_beer()

	_light = OmniLight3D.new()
	_light.name = "ProvisionLight"
	_light.light_color = _provision_hue()
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 2.4
	_light.shadow_enabled = false
	_light.position.y = LIGHT_Y
	add_child(_light)


## Two offset loops and a crossing tie: a coil from every camera angle, without
## registering a Rope item asset or falling back to a proxy block.
func _build_rope() -> void:
	var rope := _material(Color(0.36, 0.25, 0.14), 0.05)
	var tie := _material(Color(0.18, 0.12, 0.075))
	_add_torus("LoopLeft", Vector3(-0.035, 0.0, 0.0), rope)
	_add_torus("LoopRight", Vector3(0.035, 0.018, 0.0), rope)
	_add_box("Tie", Vector3(0.075, 0.075, 0.36),
		Vector3(0.0, 0.035, 0.0), Vector3(0.0, 0.22, 0.0), tie)


## A low round biscuit with dark crossed score marks. The flat edge is the
## silhouette; the scoring keeps it from reading as a coin.
func _build_hardtack() -> void:
	var biscuit := _material(Color(0.58, 0.43, 0.24), 0.035)
	var score := _material(Color(0.20, 0.13, 0.075))
	_add_cylinder("Biscuit", 0.25, 0.25, 0.085, Vector3.ZERO, biscuit, 10)
	_add_box("ScoreA", Vector3(0.38, 0.012, 0.025),
		Vector3(0.0, 0.049, 0.0), Vector3.ZERO, score)
	_add_box("ScoreB", Vector3(0.025, 0.012, 0.38),
		Vector3(0.0, 0.049, 0.0), Vector3.ZERO, score)


## A squat bottle, narrow neck and oversized stopper. Its height and stepped
## shoulder separate it cleanly from both the flat biscuit and horizontal coil.
func _build_small_beer() -> void:
	var glass := _material(Color(0.16, 0.28, 0.24), 0.06)
	var cork := _material(Color(0.43, 0.27, 0.13))
	_add_cylinder("Bottle", 0.16, 0.19, 0.34,
		Vector3(0.0, 0.03, 0.0), glass, 9)
	_add_cylinder("Neck", 0.075, 0.105, 0.17,
		Vector3(0.0, 0.285, 0.0), glass, 9)
	_add_cylinder("Stopper", 0.09, 0.09, 0.07,
		Vector3(0.0, 0.405, 0.0), cork, 8)


func _provision_hue() -> Color:
	match provision_id:
		&"escape_rope": return Pal.BONE.lerp(Pal.RUST, 0.35)
		&"hardtack": return Pal.BONE.lerp(Pal.GOLD, 0.18)
		&"small_beer": return Pal.MOSS.lerp(Pal.BONE, 0.30)
	return Pal.BONE


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials.append(material)
	return material


func _add_torus(node_name: String, at: Vector3,
		material: StandardMaterial3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.255
	torus.rings = 12
	torus.ring_segments = 8
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = torus
	mesh.material_override = material
	mesh.position = at
	_rig.add_child(mesh)


func _add_cylinder(node_name: String, top: float, bottom: float, height: float,
		at: Vector3, material: StandardMaterial3D, segments: int) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	_rig.add_child(mesh)


func _add_box(node_name: String, size: Vector3, at: Vector3, rotation: Vector3,
		material: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.rotation = rotation
	_rig.add_child(mesh)
