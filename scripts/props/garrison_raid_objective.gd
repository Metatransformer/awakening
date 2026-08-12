class_name GarrisonRaidObjective
extends Node3D
## The visible command standard for Game's garrison integrity. It deliberately
## owns no HealthComponent and no second durability value.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

var _standard: Node3D
var _banner_material: StandardMaterial3D
var _light: OmniLight3D
var _strike_tween: Tween


func _ready() -> void:
	_build()


func strike() -> void:
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	_standard.position = Vector3.ZERO
	_standard.rotation = Vector3.ZERO
	_banner_material.emission_enabled = true
	_banner_material.emission = Pal.BONE
	_banner_material.emission_energy_multiplier = 4.2
	_light.light_color = Pal.BONE
	_light.light_energy = 4.0
	Bus.request_sfx.emit(&"weapon_impact_blunt_2h_heavy", global_position + Vector3.UP)

	_strike_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strike_tween.set_parallel(true)
	_strike_tween.tween_property(_standard, ^"position:x", 0.16, 0.06)
	_strike_tween.tween_property(_standard, ^"rotation:z", deg_to_rad(-6.0), 0.06)
	_strike_tween.tween_property(
		_banner_material, ^"emission_energy_multiplier", 0.0, 0.22)
	_strike_tween.tween_property(_light, ^"light_energy", 1.15, 0.24)
	_strike_tween.tween_property(_light, ^"light_color", Pal.GOLD, 0.24)
	_strike_tween.chain().tween_property(_standard, ^"position:x", 0.0, 0.16)
	_strike_tween.parallel().tween_property(_standard, ^"rotation:z", 0.0, 0.16)


func _build() -> void:
	var base := Node3D.new()
	base.name = &"GroundedBase"
	add_child(base)
	_cylinder(base, &"StoneFoot", _flat(Pal.BONE.darkened(0.62)),
		0.58, 0.16, Vector3(0.0, 0.08, 0.0), 10)
	_cylinder(base, &"IronCollar", MAT_IRON, 0.34, 0.18,
		Vector3(0.0, 0.22, 0.0), 10)

	_standard = Node3D.new()
	_standard.name = &"CommandStandard"
	add_child(_standard)
	_cylinder(_standard, &"Mast", MAT_WOOD, 0.085, 2.75,
		Vector3(0.0, 1.55, 0.0), 10)
	_box(_standard, &"Crosspiece", MAT_IRON, Vector3(1.15, 0.09, 0.09),
		Vector3(0.0, 2.55, 0.0))
	_box(_standard, &"MastCap", MAT_IRON, Vector3(0.16, 0.18, 0.16),
		Vector3(0.0, 2.96, 0.0))

	_banner_material = _flat(Pal.RUST)
	_banner_material.roughness = 0.86
	_box(_standard, &"Banner", _banner_material, Vector3(0.86, 0.58, 0.035),
		Vector3(0.0, 2.22, 0.0))
	_box(_standard, &"BannerBone", _flat(Pal.BONE), Vector3(0.54, 0.055, 0.045),
		Vector3(0.0, 2.22, -0.024))

	_light = OmniLight3D.new()
	_light.name = &"WarmCommandLight"
	_light.position = Vector3(0.0, 2.72, 0.12)
	_light.light_color = Pal.GOLD
	_light.light_energy = 1.15
	_light.omni_range = 4.2
	_light.shadow_enabled = false
	_standard.add_child(_light)
	_cylinder(_standard, &"Lamp", _glow(Pal.GOLD), 0.10, 0.18,
		Vector3(0.0, 2.72, 0.08), 8)


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, at: Vector3, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _glow(color: Color) -> StandardMaterial3D:
	var material := _flat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	return material
