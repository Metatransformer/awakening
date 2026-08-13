class_name GarrisonHearth
extends Interactable
## Presentation of the already-resolved bonfire state and its remaining reserve.

const ROCK_1: PackedScene = preload("res://assets/props/garrison_rocks/rock_1_tl.glb")
const ROCK_3: PackedScene = preload("res://assets/props/garrison_rocks/rock_3_br.glb")
const ROCK_6: PackedScene = preload("res://assets/props/garrison_rocks/rock_6_tr.glb")
const MAT_MOSSY_ROCK: StandardMaterial3D = preload(
	"res://assets/materials/mat_garrison_mossy_rock.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const BARK_DIFF := "res://assets/props/garrison_camp/pine_bark.jpg"
const BARK_NORM := "res://assets/props/garrison_camp/pine_bark_n.jpg"
const STUMP_SEAT_H := 0.55
const STUMP_BEHIND_OFFSET := 0.85
const FIRE_LIGHT_ENERGY := 2.4

var _stock_bundles: Array[Node3D] = []
var _embers: Node3D
var _flames: Node3D
var _fire_light: OmniLight3D
var _ember_material: StandardMaterial3D
var _soft_texture: GradientTexture2D
var _flicker_time := 0.0


func _ready() -> void:
	prompt = "CHECK HEARTH RESERVE"
	radius = 2.3
	super()
	_build()
	Game.garrison_changed.connect(_repaint)
	Clock.garrison_phase_changed.connect(_on_phase_changed)
	Clock.minute_changed.connect(_on_minute_changed)
	_repaint()


func activate(_by: Node3D) -> void:
	if Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE \
			and Game.last_supper_day == Clock.day:
		var fire_state := "FIRE LIT" if Game.warmth_active else "NO FIREWOOD"
		var food_state := "FISH SERVED" if Game.fed_active else "NO FISH"
		Bus.request_message.emit("SUPPER: %s; %s. DEPOSIT AT THE SOUTH-GATE SUPPLY BOX."
			% [fire_state, food_state])
		return
	Bus.request_message.emit("HEARTH RESERVE: %d / %d. DEPOSIT AT THE SOUTH-GATE SUPPLY BOX."
		% [Game.firewood_stock, Game.FIREWOOD_CAP])


func _on_phase_changed(_phase: StringName) -> void:
	_repaint()


func _on_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	_repaint()


func _process(delta: float) -> void:
	_flicker_time += delta
	var wave := sin(_flicker_time * 11.0) * 0.06 + sin(_flicker_time * 27.3) * 0.04
	_fire_light.light_energy = FIRE_LIGHT_ENERGY * (1.0 + wave * 1.4)


func _repaint() -> void:
	prompt = "CHECK SUPPER" \
		if Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE \
		else "CHECK HEARTH RESERVE"
	for i: int in _stock_bundles.size():
		_stock_bundles[i].visible = i < Game.firewood_stock
	var fueled: bool = Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE \
		and Game.last_bonfire_day == Clock.day and Game.warmth_active
	if _flames != null:
		_flames.visible = fueled
		for child: Node in _flames.get_children():
			var particles := child as GPUParticles3D
			if particles != null:
				particles.emitting = fueled
	if _embers != null:
		_embers.visible = true
	if _ember_material != null:
		_ember_material.emission_energy_multiplier = 1.6 if fueled else 0.0
	if _fire_light != null:
		_fire_light.visible = fueled
		_fire_light.light_energy = FIRE_LIGHT_ENERGY
	set_process(fueled)


func _build() -> void:
	var ring := Node3D.new()
	ring.name = &"StoneFireRing"
	add_child(ring)
	for i: int in 12:
		var angle: float = float(i) * TAU / 12.0
		var packed: PackedScene = _rock_scene(i)
		var rock := packed.instantiate() as Node3D
		rock.name = StringName("FireRingRock%02d" % (i + 1))
		rock.position = Vector3(cos(angle) * 1.1, 0.05, sin(angle) * 1.1)
		rock.rotation.y = angle
		rock.scale = Vector3.ONE * 0.34
		_make_imported_rock_decorative(rock)
		ring.add_child(rock)

	_embers = Node3D.new()
	_embers.name = &"ColdEmbers"
	add_child(_embers)
	var bark := _bark_material(Color(0.72, 0.62, 0.55))
	_add_log_bed(_embers, bark)

	_flames = Node3D.new()
	_flames.name = &"BonfireFlames"
	add_child(_flames)
	_add_fire_vfx(_flames)

	_fire_light = OmniLight3D.new()
	_fire_light.name = &"BonfireLight"
	_fire_light.light_color = Color(1.0, 0.52, 0.22)
	_fire_light.light_energy = FIRE_LIGHT_ENERGY
	_fire_light.omni_range = 9.0
	_fire_light.shadow_enabled = true
	_fire_light.position = Vector3(0.0, 1.0, 0.0)
	add_child(_fire_light)

	_build_stump_seats(_bark_material(Color.WHITE.lerp(Color(0.36, 0.26, 0.16) * 2.2, 0.25)))

	var stock := Node3D.new()
	stock.name = &"FirewoodStock"
	stock.position = Vector3(1.35, 0.0, 0.0)
	add_child(stock)
	for i: int in Game.FIREWOOD_CAP:
		var bundle := Node3D.new()
		bundle.name = StringName("Bundle%d" % (i + 1))
		bundle.position = Vector3(0.0, 0.17 + float(i) * 0.28, 0.0)
		stock.add_child(bundle)
		_stock_bundles.append(bundle)
		for z: float in [-0.18, 0.18]:
			var basis := Basis(Vector3.FORWARD, PI * 0.5)
			_cylinder(bundle, &"Log", MAT_WOOD, 0.13, 0.95,
				Transform3D(basis, Vector3(0.0, 0.0, z)), 8)


func _rock_scene(index: int) -> PackedScene:
	match index % 3:
		0:
			return ROCK_1
		1:
			return ROCK_3
		_:
			return ROCK_6


func _make_imported_rock_decorative(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.material_override = MAT_MOSSY_ROCK
	var collision_object := node as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	var collision_shape := node as CollisionShape3D
	if collision_shape != null:
		collision_shape.disabled = true
	var collision_polygon := node as CollisionPolygon3D
	if collision_polygon != null:
		collision_polygon.disabled = true
	for child: Node in node.get_children():
		_make_imported_rock_decorative(child)


func _add_log_bed(parent: Node3D, bark: Material) -> void:
	var logs := Node3D.new()
	logs.name = &"Logs"
	parent.add_child(logs)
	var char_black := _plain_material(Color(0.10, 0.08, 0.07), 0.9)

	_ember_material = StandardMaterial3D.new()
	_ember_material.albedo_color = Color(0.16, 0.09, 0.06)
	_ember_material.roughness = 1.0
	_ember_material.emission_enabled = true
	_ember_material.emission = Color(1.0, 0.36, 0.06)
	_ember_material.emission_energy_multiplier = 0.0
	_tapered_cylinder(logs, &"EmberBed", 0.52, 0.58, 0.10,
		Vector3(0.0, 0.05, 0.0), _ember_material, Vector3.ZERO, 14)

	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0 + 0.26
		var base := Vector3(cos(angle) * 0.72, 0.08, sin(angle) * 0.72)
		var apex := Vector3(cos(angle + 2.4) * 0.06, 1.05,
			sin(angle + 2.4) * 0.06)
		_log_between(logs, StringName("TeepeeLog%02d" % (i + 1)), base, apex,
			0.055, 0.075, bark if i % 3 != 0 else char_black)
	for i: int in 4:
		var angle: float = TAU * float(i) / 4.0 + 0.9
		var inner := Vector3(cos(angle) * 0.18, 0.09, sin(angle) * 0.18)
		var outer := Vector3(cos(angle) * 0.95, 0.11, sin(angle) * 0.95)
		_log_between(logs, StringName("FuelLog%02d" % (i + 1)), inner, outer,
			0.06, 0.07, bark)


func _log_between(parent: Node3D, node_name: StringName, a: Vector3, b: Vector3,
		top_radius: float, bottom_radius: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mesh.surface_set_material(0, material)
	instance.mesh = mesh
	var y_axis := (b - a).normalized()
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	instance.transform = Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)),
		(a + b) * 0.5)
	parent.add_child(instance)


func _build_stump_seats(bark: Material) -> void:
	var seats := Node3D.new()
	seats.name = &"StumpSeats"
	add_child(seats)
	var sawn := _sawn_wood_material()
	_add_stump_seat(seats, &"QuartermasterStumpSeat", Vector3(-3.0, 0.0, 0.8), bark, sawn)
	_add_stump_seat(seats, &"SmithStumpSeat", Vector3(-1.8, 0.0, -2.5), bark, sawn)
	_add_stump_seat(seats, &"AlchemistStumpSeat", Vector3(1.8, 0.0, -2.5), bark, sawn)
	_add_stump_seat(seats, &"ElderStumpSeat", Vector3(3.0, 0.0, 0.8), bark, sawn)
	_add_stump_seat(seats, &"JewelcrafterStumpSeat", Vector3(0.0, 0.0, 3.1), bark, sawn)
	_add_stump_seat(seats, &"BuilderStumpSeat", Vector3(0.0, 0.0, -3.2), bark, sawn)


func _add_stump_seat(parent: Node3D, node_name: StringName, standing: Vector3,
		bark: Material, sawn: Material) -> void:
	var seat := Node3D.new()
	seat.name = node_name
	seat.position = standing + standing.normalized() * STUMP_BEHIND_OFFSET
	parent.add_child(seat)
	_tapered_cylinder(seat, &"Bark", 0.40, 0.46, STUMP_SEAT_H,
		Vector3(0.0, STUMP_SEAT_H * 0.5, 0.0), bark, Vector3.ZERO, 12)
	_tapered_cylinder(seat, &"SawnTop", 0.385, 0.385, 0.025,
		Vector3(0.0, STUMP_SEAT_H + 0.005, 0.0), sawn, Vector3.ZERO, 12)


func _add_fire_vfx(parent: Node3D) -> void:
	var core := _particles(&"FireVFX", 30, 0.75, Vector3(0.0, 0.22, 0.0))
	var core_process := _flame_process(0.42, 1.1, 2.0, 0.55, 1.1)
	core_process.color_ramp = _ramp(
		PackedFloat32Array([0.0, 0.3, 0.7, 1.0]),
		PackedColorArray([Color(1.0, 0.95, 0.55, 0.95), Color(1.0, 0.62, 0.10, 0.92),
			Color(0.92, 0.22, 0.02, 0.62), Color(0.35, 0.03, 0.0, 0.0)]))
	core_process.scale_curve = _curve(
		PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.55, 0.72), Vector2(1.0, 0.18)]))
	core.process_material = core_process
	core.draw_pass_1 = _fire_quad(Color(1.0, 0.72, 0.2), 0.55, 3.2, true)
	parent.add_child(core)

	var licks := _particles(&"FlameLicksVFX", 12, 0.85, Vector3(0.0, 0.3, 0.0))
	var licks_process := _flame_process(0.42, 0.7, 1.2, 0.8, 1.1)
	licks_process.color_ramp = _ramp(
		PackedFloat32Array([0.0, 0.5, 1.0]),
		PackedColorArray([Color(1.0, 0.55, 0.12, 0.55), Color(0.85, 0.28, 0.03, 0.42),
			Color(0.3, 0.04, 0.0, 0.0)]))
	licks_process.scale_curve = _curve(
		PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.4, 1.0), Vector2(1.0, 0.3)]))
	licks.process_material = licks_process
	licks.draw_pass_1 = _fire_quad(Color(1.0, 0.5, 0.12), 0.8, 1.8, true)
	parent.add_child(licks)

	var embers := _particles(&"EmberVFX", 20, 1.9, Vector3(0.0, 0.3, 0.0))
	var embers_process := _flame_process(0.5, 1.2, 2.4, 0.16, 0.3)
	embers_process.spread = 9.0
	embers_process.tangential_accel_min = 0.4
	embers_process.tangential_accel_max = 1.1
	embers_process.turbulence_enabled = true
	embers_process.turbulence_noise_strength = 0.55
	embers_process.turbulence_noise_scale = 3.2
	embers_process.color_ramp = _ramp(
		PackedFloat32Array([0.0, 0.4, 0.8, 1.0]),
		PackedColorArray([Color(1.0, 0.82, 0.3, 1.0), Color(1.0, 0.42, 0.06, 0.9),
			Color(0.7, 0.12, 0.01, 0.55), Color(0.3, 0.03, 0.0, 0.0)]))
	embers.process_material = embers_process
	embers.draw_pass_1 = _fire_quad(Color(1.0, 0.6, 0.15), 0.085, 4.0, true)
	parent.add_child(embers)

	var smoke := _particles(&"SmokeVFX", 14, 4.2, Vector3(0.0, 1.1, 0.0))
	var smoke_process := _flame_process(0.22, 0.5, 0.95, 0.6, 1.0)
	smoke_process.spread = 14.0
	smoke_process.gravity = Vector3(0.0, 0.22, 0.0)
	smoke_process.damping_min = 0.2
	smoke_process.damping_max = 0.5
	smoke_process.turbulence_enabled = true
	smoke_process.turbulence_noise_strength = 0.35
	smoke_process.turbulence_noise_scale = 1.6
	smoke_process.color_ramp = _ramp(
		PackedFloat32Array([0.0, 0.18, 0.65, 1.0]),
		PackedColorArray([Color(0.36, 0.34, 0.32, 0.0), Color(0.4, 0.38, 0.36, 0.5),
			Color(0.46, 0.45, 0.44, 0.32), Color(0.5, 0.5, 0.5, 0.0)]))
	smoke_process.scale_curve = _curve(
		PackedVector2Array([Vector2(0.0, 0.45), Vector2(1.0, 1.9)]))
	smoke.process_material = smoke_process
	smoke.draw_pass_1 = _fire_quad(Color(0.42, 0.4, 0.38), 0.7, 0.0, false)
	smoke.fixed_fps = 20
	parent.add_child(smoke)


func _particles(node_name: StringName, amount: int, lifetime: float,
		at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.fixed_fps = 30
	particles.position = at
	return particles


func _flame_process(ring_radius: float, velocity_min: float, velocity_max: float,
		scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3.UP
	material.emission_ring_radius = ring_radius
	material.emission_ring_inner_radius = 0.0
	material.emission_ring_height = 0.08
	material.direction = Vector3.UP
	material.spread = 7.0
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = Vector3(0.0, 0.5, 0.0)
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.hue_variation_min = -0.03
	material.hue_variation_max = 0.03
	return material


func _ramp(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _curve(points: PackedVector2Array) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _fire_quad(color: Color, size: float, energy: float, additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 1.35)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = _soft_fire_texture()
	material.disable_receive_shadows = true
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 0.4
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.emission_enabled = true
		material.emission = color
		material.emission_texture = _soft_fire_texture()
		material.emission_energy_multiplier = energy
	quad.material = material
	return quad


func _soft_fire_texture() -> GradientTexture2D:
	if _soft_texture != null:
		return _soft_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.5),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_soft_texture = GradientTexture2D.new()
	_soft_texture.gradient = gradient
	_soft_texture.fill = GradientTexture2D.FILL_RADIAL
	_soft_texture.fill_from = Vector2(0.5, 0.5)
	_soft_texture.fill_to = Vector2(0.5, 0.0)
	_soft_texture.width = 64
	_soft_texture.height = 64
	return _soft_texture


func _bark_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = load(BARK_DIFF) as Texture2D
	var normal := load(BARK_NORM) as Texture2D
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.8
	material.roughness = 0.95
	material.metallic = 0.0
	return material


func _sawn_wood_material() -> StandardMaterial3D:
	return _plain_material(Color(0.62, 0.5, 0.34), 0.85)


func _plain_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _tapered_cylinder(parent: Node3D, node_name: StringName, top_radius: float,
		bottom_radius: float, height: float, at: Vector3, material: Material,
		rotation_degrees: Vector3, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.surface_set_material(0, material)
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation_degrees
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, local_transform: Transform3D,
		sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = local_transform
	parent.add_child(instance)
	return instance
