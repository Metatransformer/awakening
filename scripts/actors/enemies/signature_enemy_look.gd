extends Node3D
## Primitive silhouette layer for the four tool-tier signature enemies.
## The imported, animated biped stays visible underneath; these pieces only add
## the shell, eye, plate, or mantle that communicates the alternate answer.

const READABILITY_LAYER := 1 << 2
const Palette := preload("res://scripts/ui/style.gd")

var _signature: StringName = &""
var _height: float = 1.7
var _exposed: bool = false
var _cold_opening: bool = false

var _knot_left: Node3D = null
var _knot_right: Node3D = null
var _knot: Node3D = null
var _seer_lid_top: Node3D = null
var _seer_lid_bottom: Node3D = null
var _seer_eye: Node3D = null
var _cinder_left: Node3D = null
var _cinder_right: Node3D = null
var _cinder_core: Node3D = null
var _mire_mantle: Node3D = null
var _mire_core: Node3D = null
var _mire_core_material: StandardMaterial3D = null
var _mire_core_light: OmniLight3D = null

var _seer_line: MeshInstance3D = null
var _seer_line_material: StandardMaterial3D = null
var _seer_line_target: Vector3 = Vector3.ZERO
var _seer_line_origin: Vector3 = Vector3.ZERO
var _seer_line_progress: float = 0.0
var _seer_line_active: bool = false


func build(signature: StringName, body_height: float) -> void:
	_signature = signature
	_height = body_height
	match _signature:
		&"knotback":
			_build_knotback()
		&"lantern_seer":
			_build_lantern_seer()
		&"cinder_automaton":
			_build_cinder_automaton()
		&"mirebell":
			_build_mirebell()
	set_exposure(false)


func set_exposure(exposed: bool, cold_opening: bool = false) -> void:
	_exposed = exposed
	_cold_opening = exposed and cold_opening
	match _signature:
		&"knotback":
			_shape_knotback()
		&"lantern_seer":
			_shape_lantern_seer()
		&"cinder_automaton":
			_shape_cinder_automaton()
		&"mirebell":
			_shape_mirebell()


## The danger line stores a world target and rebuilds after the parent has
## turned. Enemy writes its final yaw at the end of physics, so placing the line
## immediately in the setter would rotate an already-aimed line a second time.
func set_seer_charge_line(target_global: Vector3, progress: float) -> void:
	if _seer_line == null:
		return
	_seer_line_target = target_global
	_seer_line_progress = clampf(progress, 0.0, 1.0)
	_seer_line_active = true
	_seer_line.visible = true
	if _seer_line_material != null:
		_seer_line_material.emission_energy_multiplier = lerpf(0.45, 1.35,
			_seer_line_progress)


func hide_seer_charge_line() -> void:
	_seer_line_active = false
	if _seer_line != null:
		_seer_line.visible = false


func _process(_delta: float) -> void:
	if _seer_line_active:
		_place_seer_line()


func _build_knotback() -> void:
	var slime := _material(Palette.MOSS.darkened(0.35), 0.0, 0.92)
	var shell := _material(Palette.MOSS.darkened(0.18), 0.0, 0.78)
	var hot := _material(Palette.RUST.darkened(0.12), 0.85, 0.72)

	# Two low slime legs keep this an unmistakable biped even under the shell.
	_add_capsule(self, Vector3(-0.24, _height * 0.23, 0.02),
		0.20, _height * 0.46, slime, Vector3(1.05, 1.0, 1.12))
	_add_capsule(self, Vector3(0.25, _height * 0.22, 0.08),
		0.23, _height * 0.43, slime, Vector3(1.18, 0.92, 1.05))

	_knot_left = Node3D.new()
	_knot_left.position = Vector3(-0.22, _height * 0.62, 0.08)
	add_child(_knot_left)
	_add_sphere(_knot_left, Vector3.ZERO, 0.52, shell,
		Vector3(0.82, 1.18, 0.78))
	_knot_right = Node3D.new()
	_knot_right.position = Vector3(0.28, _height * 0.66, 0.12)
	_knot_right.rotation.z = deg_to_rad(-9.0)
	add_child(_knot_right)
	_add_sphere(_knot_right, Vector3.ZERO, 0.56, shell,
		Vector3(0.92, 1.26, 0.84))

	# +Z is the rear of an actor whose gameplay forward is -Z.
	_knot = Node3D.new()
	_knot.position = Vector3(0.16, _height * 0.66, 0.55)
	add_child(_knot)
	_add_torus(_knot, Vector3.ZERO, 0.08, 0.20, hot, Vector3(1.0, 1.3, 1.0))
	_add_sphere(_knot, Vector3(0.0, 0.0, 0.03), 0.10, hot,
		Vector3(1.0, 1.35, 0.75))
	_add_light(_knot, Palette.RUST, 0.75, 1.55)


func _shape_knotback() -> void:
	if _knot_left == null or _knot_right == null or _knot == null:
		return
	_knot_left.position.x = -0.39 if _exposed else -0.22
	_knot_left.rotation.z = deg_to_rad(18.0 if _exposed else 0.0)
	_knot_right.position.x = 0.45 if _exposed else 0.28
	_knot_right.rotation.z = deg_to_rad(-27.0 if _exposed else -9.0)
	_knot.position.z = 0.72 if _exposed else 0.55
	_knot.scale = Vector3.ONE * (1.32 if _exposed else 1.0)


func _build_lantern_seer() -> void:
	var mantle := _material(Palette.ASH.darkened(0.18), 0.0, 0.82)
	var crest := _material(Palette.RUST.darkened(0.34), 0.18, 0.75)
	var bone := _material(Palette.BONE, 0.38, 0.72)
	var pupil := _material(Palette.RUST, 1.0, 0.66)

	_add_capsule(self, Vector3.ZERO + Vector3.UP * (_height * 0.58),
		0.32, _height * 1.08, mantle, Vector3(0.9, 1.0, 0.72))
	# A high, split crest makes the silhouette taller than the roster body below.
	_add_cylinder(self, Vector3(-0.18, _height * 1.04, 0.02),
		0.02, 0.20, _height * 0.48, crest, Vector3(0.8, 1.0, 0.72),
		deg_to_rad(-13.0))
	_add_cylinder(self, Vector3(0.18, _height * 1.07, 0.04),
		0.02, 0.17, _height * 0.54, crest, Vector3(0.8, 1.0, 0.72),
		deg_to_rad(13.0))

	_seer_eye = Node3D.new()
	_seer_eye.position = Vector3(0.0, _height * 0.76, -0.34)
	add_child(_seer_eye)
	_add_sphere(_seer_eye, Vector3.ZERO, 0.23, bone, Vector3(1.0, 1.22, 0.34))
	_add_sphere(_seer_eye, Vector3(0.0, 0.0, -0.075), 0.09, pupil,
		Vector3(0.72, 1.08, 0.24))
	_add_light(_seer_eye, Palette.RUST, 0.70, 1.6)

	_seer_lid_top = Node3D.new()
	_seer_lid_top.position = Vector3(0.0, _height * 0.80, -0.42)
	add_child(_seer_lid_top)
	_add_box(_seer_lid_top, Vector3.ZERO, Vector3(0.53, 0.13, 0.12), crest)
	_seer_lid_bottom = Node3D.new()
	_seer_lid_bottom.position = Vector3(0.0, _height * 0.72, -0.42)
	add_child(_seer_lid_bottom)
	_add_box(_seer_lid_bottom, Vector3.ZERO, Vector3(0.53, 0.13, 0.12), crest)

	_seer_line_material = _material(Palette.RUST.darkened(0.12), 0.45, 0.9)
	_seer_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_seer_line = MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.035, 0.025, 1.0)
	_seer_line.mesh = line_mesh
	_seer_line.material_override = _seer_line_material
	_seer_line.layers |= READABILITY_LAYER
	_seer_line.visible = false
	add_child(_seer_line)
	_seer_line_origin = Vector3(0.0, _height * 0.76, -0.47)


func _shape_lantern_seer() -> void:
	if _seer_lid_top == null or _seer_lid_bottom == null or _seer_eye == null:
		return
	var gap := _height * 0.105 if _exposed else 0.0
	_seer_lid_top.position.y = _height * 0.76 + gap
	_seer_lid_bottom.position.y = _height * 0.76 - gap
	_seer_lid_top.rotation.z = deg_to_rad(-9.0 if _exposed else 0.0)
	_seer_lid_bottom.rotation.z = deg_to_rad(9.0 if _exposed else 0.0)
	_seer_eye.scale = Vector3.ONE * (1.12 if _exposed else 0.82)


func _build_cinder_automaton() -> void:
	var iron := _material(Palette.ASH.darkened(0.28), 0.0, 0.48, 0.72)
	var edge := _material(Palette.MOTH.darkened(0.34), 0.0, 0.58, 0.58)
	var heat := _material(Palette.RUST, 1.05, 0.62)

	# Oversized shoulders and a hard rectangular chest separate this from every
	# organic shell even before the vents move.
	_add_box(self, Vector3(-0.45, _height * 0.77, 0.0),
		Vector3(0.43, 0.32, 0.52), iron, Vector3(1.0, 1.0, 1.0), deg_to_rad(-10.0))
	_add_box(self, Vector3(0.45, _height * 0.77, 0.0),
		Vector3(0.43, 0.32, 0.52), iron, Vector3(1.0, 1.0, 1.0), deg_to_rad(10.0))
	_add_torus(self, Vector3(-0.49, _height * 0.73, 0.04), 0.10, 0.22, edge)
	_add_torus(self, Vector3(0.49, _height * 0.73, 0.04), 0.10, 0.22, edge)

	_cinder_left = Node3D.new()
	_cinder_left.position = Vector3(-0.17, _height * 0.58, -0.28)
	add_child(_cinder_left)
	_add_box(_cinder_left, Vector3.ZERO, Vector3(0.34, _height * 0.58, 0.16), iron)
	_cinder_right = Node3D.new()
	_cinder_right.position = Vector3(0.17, _height * 0.58, -0.28)
	add_child(_cinder_right)
	_add_box(_cinder_right, Vector3.ZERO, Vector3(0.34, _height * 0.58, 0.16), iron)

	_cinder_core = Node3D.new()
	_cinder_core.position = Vector3(0.0, _height * 0.58, -0.39)
	add_child(_cinder_core)
	_add_cylinder(_cinder_core, Vector3.ZERO, 0.13, 0.13, 0.25, heat,
		Vector3(1.0, 1.0, 0.48), deg_to_rad(90.0))
	_add_torus(_cinder_core, Vector3.ZERO, 0.13, 0.24, edge,
		Vector3(1.0, 1.0, 0.55))
	_add_light(_cinder_core, Palette.RUST, 0.9, 1.75)

	# Short exhaust stacks carry the heat language above the shoulders without
	# using transparent smoke or additive slabs.
	_add_cylinder(self, Vector3(-0.31, _height * 0.99, 0.16),
		0.08, 0.11, 0.37, edge)
	_add_cylinder(self, Vector3(0.31, _height * 0.99, 0.16),
		0.08, 0.11, 0.37, edge)


func _shape_cinder_automaton() -> void:
	if _cinder_left == null or _cinder_right == null or _cinder_core == null:
		return
	_cinder_left.position.x = -0.34 if _exposed else -0.17
	_cinder_right.position.x = 0.34 if _exposed else 0.17
	_cinder_left.rotation.y = deg_to_rad(-28.0 if _exposed else 0.0)
	_cinder_right.rotation.y = deg_to_rad(28.0 if _exposed else 0.0)
	_cinder_core.scale = Vector3.ONE * (1.30 if _exposed else 0.72)


func _build_mirebell() -> void:
	var mire := _material(Palette.MOSS.darkened(0.42), 0.0, 0.96)
	var rim := _material(Palette.MOTH.darkened(0.40), 0.0, 0.9)
	_mire_core_material = _material(Palette.BONE.darkened(0.12), 0.46, 0.82)

	_mire_mantle = Node3D.new()
	_mire_mantle.position = Vector3(0.0, _height * 0.68, 0.02)
	add_child(_mire_mantle)
	_add_cylinder(_mire_mantle, Vector3.ZERO, 0.34, 0.73, _height * 0.70, mire,
		Vector3(1.0, 1.0, 0.88))
	_add_torus(_mire_mantle, Vector3(0.0, -_height * 0.34, 0.0),
		0.55, 0.76, rim, Vector3(1.0, 0.56, 0.88))
	# Uneven drops make the broad skirt read as ooze rather than metal.
	_add_sphere(_mire_mantle, Vector3(-0.42, -_height * 0.32, 0.05),
		0.23, mire, Vector3(1.0, 1.35, 0.88))
	_add_sphere(_mire_mantle, Vector3(0.38, -_height * 0.35, -0.02),
		0.27, mire, Vector3(1.0, 1.42, 0.92))

	_mire_core = Node3D.new()
	_mire_core.position = Vector3(0.0, _height * 0.29, -0.10)
	add_child(_mire_core)
	_add_sphere(_mire_core, Vector3.ZERO, 0.17, _mire_core_material,
		Vector3(0.82, 1.38, 0.72))
	_add_cylinder(_mire_core, Vector3(0.0, 0.21, 0.0),
		0.045, 0.07, 0.34, rim)
	_mire_core_light = _add_light(_mire_core, Palette.BONE, 0.42, 1.45)


func _shape_mirebell() -> void:
	if _mire_mantle == null or _mire_core == null or _mire_core_material == null:
		return
	_mire_mantle.position.y = _height * (0.83 if _exposed else 0.68)
	_mire_mantle.scale = Vector3(1.12, 0.78, 1.12) if _exposed else Vector3.ONE
	_mire_core.scale = Vector3.ONE * (1.34 if _exposed else 0.70)
	var core_color: Color = Palette.FROST if _cold_opening else Palette.BONE
	_mire_core_material.albedo_color = core_color.darkened(0.12)
	_mire_core_material.emission = core_color
	_mire_core_material.emission_energy_multiplier = 1.0 if _cold_opening else 0.46
	if _mire_core_light != null:
		_mire_core_light.light_color = core_color
		_mire_core_light.light_energy = 0.92 if _cold_opening else 0.42


func _place_seer_line() -> void:
	if _seer_line == null:
		return
	var origin := to_global(_seer_line_origin)
	var toward := _seer_line_target - origin
	var length := toward.length()
	if length <= 0.02:
		_seer_line.visible = false
		return
	var up := Vector3.FORWARD if absf(toward.normalized().dot(Vector3.UP)) > 0.98 \
		else Vector3.UP
	_seer_line.global_position = origin + toward * 0.5
	_seer_line.global_basis = Basis.looking_at(toward.normalized(), up)
	_seer_line.scale = Vector3(lerpf(0.65, 1.35, _seer_line_progress),
		lerpf(0.65, 1.35, _seer_line_progress), length)
	_seer_line.visible = true


func _material(color: Color, emission_energy: float = 0.0,
		roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _mesh(parent: Node3D, primitive: PrimitiveMesh, at: Vector3,
		material: StandardMaterial3D, mesh_scale: Vector3 = Vector3.ONE,
		roll: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = primitive
	instance.material_override = material
	instance.position = at
	instance.scale = mesh_scale
	instance.rotation.z = roll
	instance.layers |= READABILITY_LAYER
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, at: Vector3, size: Vector3,
		material: StandardMaterial3D, mesh_scale: Vector3 = Vector3.ONE,
		roll: float = 0.0) -> MeshInstance3D:
	var primitive := BoxMesh.new()
	primitive.size = size
	return _mesh(parent, primitive, at, material, mesh_scale, roll)


func _add_sphere(parent: Node3D, at: Vector3, radius: float,
		material: StandardMaterial3D, mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var primitive := SphereMesh.new()
	primitive.radius = radius
	primitive.height = radius * 2.0
	primitive.radial_segments = 12
	primitive.rings = 6
	return _mesh(parent, primitive, at, material, mesh_scale)


func _add_capsule(parent: Node3D, at: Vector3, radius: float, capsule_height: float,
		material: StandardMaterial3D, mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var primitive := CapsuleMesh.new()
	primitive.radius = radius
	primitive.height = maxf(capsule_height, radius * 2.0)
	primitive.radial_segments = 10
	primitive.rings = 4
	return _mesh(parent, primitive, at, material, mesh_scale)


func _add_cylinder(parent: Node3D, at: Vector3, top_radius: float,
		bottom_radius: float, cylinder_height: float, material: StandardMaterial3D,
		mesh_scale: Vector3 = Vector3.ONE, roll: float = 0.0) -> MeshInstance3D:
	var primitive := CylinderMesh.new()
	primitive.top_radius = top_radius
	primitive.bottom_radius = bottom_radius
	primitive.height = cylinder_height
	primitive.radial_segments = 10
	primitive.rings = 1
	return _mesh(parent, primitive, at, material, mesh_scale, roll)


func _add_torus(parent: Node3D, at: Vector3, inner_radius: float,
		outer_radius: float, material: StandardMaterial3D,
		mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var primitive := TorusMesh.new()
	primitive.inner_radius = inner_radius
	primitive.outer_radius = outer_radius
	primitive.rings = 8
	primitive.ring_segments = 5
	return _mesh(parent, primitive, at, material, mesh_scale)


func _add_light(parent: Node3D, color: Color, energy: float,
		light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.7
	light.shadow_enabled = false
	parent.add_child(light)
	return light
