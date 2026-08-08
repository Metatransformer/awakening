@tool
class_name KitTorch
extends Node3D
## The dungeon's only light source, in two bodies: a wall sconce and a free-standing
## floor torch modelled on refs/screens/dungeon_torch_01.png (tapered wooden post,
## iron bands, spiked iron crown).
##
## The lighting argument, which is the whole point of this file:
##
## OOT dungeons are DARK and WARM. They are not "a room with some orange lights in
## it" — they are black, with pools of fire that fall off hard enough that you can
## see where one torch's reach ends and the next begins. Three numbers do that:
##   * `light_range` short (~9 m, less than half the room), so the far wall is unlit
##   * `light_attenuation` above 1, which curves the falloff and gives the pool a
##     visible edge instead of an infinite soft gradient
##   * ambient in the Environment kept near zero, so "unlit" really means black
## Turning any one of them toward "sensible" gives you an evenly lit grey box.
##
## Shadows are OFF by default. The N64 had no dynamic shadows and the look survives
## without them; more practically, a room full of shadow-casting omni lights costs
## six cube renders per frame for detail nobody reads. Enable `cast_shadow` on the
## one or two torches nearest the camera, where the block relief actually pays off.

enum Mode {
	## Bracket bolted to a wall. Place at KitStyle.SCONCE_Y, facing out of the wall.
	SCONCE,
	## Free-standing post. Place on the floor.
	FLOOR,
}

@export var mode: Mode = Mode.SCONCE:
	set(v):
		mode = v
		_rebuild()
@export var light_color := KitStyle.FIRE_COLOR:
	set(v):
		light_color = v
		_apply_light()
@export var light_energy := KitStyle.FIRE_ENERGY:
	set(v):
		light_energy = v
		_apply_light()
@export var light_range := KitStyle.FIRE_RANGE:
	set(v):
		light_range = v
		_apply_light()
@export var light_attenuation := KitStyle.FIRE_ATTENUATION:
	set(v):
		light_attenuation = v
		_apply_light()
@export var cast_shadow := false:
	set(v):
		cast_shadow = v
		_apply_light()
@export_range(0.0, 1.0) var flicker := KitStyle.FIRE_FLICKER:
	set(v):
		flicker = v
@export var flicker_speed := KitStyle.FIRE_FLICKER_SPEED
@export var flame_size := Vector2(0.72, 1.05):
	set(v):
		flame_size = v
		_rebuild()
@export var embers := true:
	set(v):
		embers = v
		_rebuild()
## Post height for Mode.FLOOR. Ignored by the sconce.
@export var post_height := 1.45:
	set(v):
		post_height = v
		_rebuild()
@export var wood_material: Material:
	set(v):
		wood_material = v
		_rebuild()
@export var iron_material: Material:
	set(v):
		iron_material = v
		_rebuild()
@export var flame_material: Material:
	set(v):
		flame_material = v
		_rebuild()
@export var ember_material: Material:
	set(v):
		ember_material = v
		_rebuild()
## Decorrelates this torch's flame animation and flicker phase from its neighbours.
@export var rng_seed := 1:
	set(v):
		rng_seed = v
		_rebuild()

var _body: MeshInstance3D
var _flame: MeshInstance3D
var _light: OmniLight3D
var _embers: GPUParticles3D
var _phase := 0.0


func _ready() -> void:
	_rebuild()
	set_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if _light == null or flicker <= 0.001:
		return
	# Two incommensurate sines, not a random walk: a screenshot taken at frame 45 has
	# to look the same every run, and RNG-driven flicker would make every capture a
	# different frame of a different fire.
	var t := float(Time.get_ticks_msec()) * 0.001 * flicker_speed + _phase
	var f := sin(t) * 0.6 + sin(t * 1.71 + 1.3) * 0.4
	_light.light_energy = light_energy * (1.0 + f * flicker)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_phase = rng.randf() * TAU

	_ensure_children()
	_build_body()

	var fire_y := _fire_height()
	_flame.mesh = QuadMesh.new()
	(_flame.mesh as QuadMesh).size = flame_size
	_flame.material_override = flame_material
	_flame.position = Vector3(0.0, fire_y + flame_size.y * 0.42, _fire_z())
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.set_instance_shader_parameter(&"seed", rng.randf() * 100.0)

	_light.position = Vector3(0.0, fire_y + 0.22, _fire_z())
	_apply_light()

	_embers.visible = embers
	_embers.emitting = embers
	if embers:
		_build_embers(fire_y)


## Where the fire sits, in local Y.
func _fire_height() -> float:
	return 0.26 if mode == Mode.SCONCE else post_height + 0.18


## Sconces stand off the wall face; floor torches are centred.
func _fire_z() -> float:
	return 0.30 if mode == Mode.SCONCE else 0.0


func _build_body() -> void:
	var mesh := ArrayMesh.new()
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 1.6

	if mode == Mode.FLOOR:
		# Tapered post in four chunky stages — the hard step between stages IS the
		# silhouette in the reference shot; a smooth cone loses it.
		var h := post_height
		var stages := 4
		for i in stages:
			var y0 := h * float(i) / float(stages)
			var y1 := h * float(i + 1) / float(stages)
			var w0: float = lerpf(0.19, 0.115, float(i) / float(stages))
			var w1: float = lerpf(0.19, 0.115, float(i + 1) / float(stages))
			KitGeo.taper(wood, 0.0, 0.0, y0, y1, w0, w1, s)
			# Iron band over each joint.
			var bw: float = w1 + 0.022
			KitGeo.box(iron, Vector3(-bw, y1 - 0.035, -bw), Vector3(bw, y1 + 0.035, bw), s)
		# Crown: eight spikes around the rim, plus the rim itself.
		var r := 0.135
		KitGeo.box(iron, Vector3(-r - 0.02, h, -r - 0.02), Vector3(r + 0.02, h + 0.05, r + 0.02), s)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var cx := cos(a) * r
			var cz := sin(a) * r
			KitGeo.box(iron,
				Vector3(cx - 0.032, h + 0.03, cz - 0.032),
				Vector3(cx + 0.032, h + 0.03 + (0.20 if i % 2 == 0 else 0.13), cz + 0.032), s)
	else:
		# Sconce: back plate flush to the wall, a short arm, a spiked iron cup.
		KitGeo.box(iron, Vector3(-0.17, -0.30, 0.0), Vector3(0.17, 0.30, 0.07), s)
		KitGeo.box(iron, Vector3(-0.055, -0.06, 0.05), Vector3(0.055, 0.06, 0.30), s)
		var cx := 0.30
		KitGeo.box(iron, Vector3(-0.15, 0.02, cx - 0.15), Vector3(0.15, 0.10, cx + 0.15), s)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var px := cos(a) * 0.13
			var pz := cx + sin(a) * 0.13
			KitGeo.box(iron,
				Vector3(px - 0.028, 0.08, pz - 0.028),
				Vector3(px + 0.028, 0.08 + (0.16 if i % 2 == 0 else 0.10), pz + 0.028), s)
		# A stub of charred wood in the cup.
		KitGeo.taper(wood, 0.0, cx, 0.06, 0.24, 0.075, 0.055, s)

	wood.generate_tangents()
	wood.set_material(wood_material)
	wood.commit(mesh)
	iron.generate_tangents()
	iron.set_material(iron_material)
	iron.commit(mesh)
	_body.mesh = mesh
	# The torch never shadows itself: an omni light sitting inside its own bracket
	# throws a huge black cone across the wall behind it, which is the single ugliest
	# artefact this scene can produce and is not something OOT ever showed.
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_embers(fire_y: float) -> void:
	_embers.position = Vector3(0.0, fire_y + 0.2, _fire_z())
	_embers.amount = 10
	_embers.lifetime = 1.9
	_embers.preprocess = 2.0
	_embers.randomness = 0.6
	_embers.explosiveness = 0.0
	_embers.local_coords = false
	_embers.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.0, 0.22, 0.0)
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.scale_min = 0.35
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color = Color(1.0, 0.55, 0.18, 1.0)
	_embers.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	_embers.draw_pass_1 = q
	_embers.material_override = ember_material


func _apply_light() -> void:
	if _light == null:
		return
	_light.light_color = light_color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = light_attenuation
	_light.shadow_enabled = cast_shadow
	_light.shadow_bias = 0.04
	_light.shadow_normal_bias = 1.4
	_light.light_specular = 0.35


func _ensure_children() -> void:
	_body = get_node_or_null(^"Body") as MeshInstance3D
	if _body == null:
		_body = MeshInstance3D.new()
		_body.name = "Body"
		add_child(_body)
	_flame = get_node_or_null(^"Flame") as MeshInstance3D
	if _flame == null:
		_flame = MeshInstance3D.new()
		_flame.name = "Flame"
		add_child(_flame)
	_light = get_node_or_null(^"Light") as OmniLight3D
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "Light"
		add_child(_light)
	_embers = get_node_or_null(^"Embers") as GPUParticles3D
	if _embers == null:
		_embers = GPUParticles3D.new()
		_embers.name = "Embers"
		add_child(_embers)
