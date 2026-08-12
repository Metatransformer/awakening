class_name BossItemChest
extends Chest
## The deterministic great chest earned from a floor boss.
##
## Its item waits here until the lid opens. It never rolls `ItemDb`, touches
## `Run.rng`, adds arrows, or shares the corpse-floor relic's bag risk.

@export var item_id: StringName = &""

const ROOT_SCALE := 1.55
const REVEAL_TIME := 0.34


func _ready() -> void:
	scale = Vector3.ONE * ROOT_SCALE
	super()
	prompt = "OPEN GREAT CHEST"
	_build_great_trim()


func activate(by: Node3D) -> void:
	if not _begin_open():
		return

	var awarded_item := item_id
	var hero := by as Hero
	var tree := get_tree()
	if tree == null:
		push_warning("BossItemChest: opened outside a SceneTree")
		_pay_item(awarded_item, hero, null)
		_finish_open(by, &"great_chest", false)
		return

	var host := tree.current_scene
	await tree.create_timer(REVEAL_TIME).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_pay_item(awarded_item, hero, host if host == tree.current_scene else null)
	_finish_open(by, &"great_chest", false)


func _pay_item(awarded_item: StringName, hero: Hero, host: Node) -> void:
	if awarded_item == &"":
		push_warning("BossItemChest: opened without an item_id")
		return
	Game.grant(awarded_item)
	if hero == null or not is_instance_valid(hero):
		push_warning("BossItemChest: non-Hero opener received %s without presentation"
			% awarded_item)
		return
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		push_warning("BossItemChest: scene changed before %s could be presented"
			% awarded_item)
		return
	ItemGet.present(host, awarded_item, hero)


func _build_great_trim() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Pal.GOLD
	gold.metallic = 0.82
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Pal.GOLD * 0.42
	gold.emission_energy_multiplier = 1.35

	_add_trim_box("UpperBand", Vector3(1.18, 0.055, 0.045),
		Vector3(0.0, 0.50, 0.335), gold)
	_add_trim_box("LowerBand", Vector3(1.18, 0.055, 0.045),
		Vector3(0.0, 0.18, 0.335), gold)

	var crest_mesh := CylinderMesh.new()
	crest_mesh.top_radius = 0.15
	crest_mesh.bottom_radius = 0.15
	crest_mesh.height = 0.05
	var crest := MeshInstance3D.new()
	crest.name = "GreatChestCrest"
	crest.mesh = crest_mesh
	crest.material_override = gold
	crest.position = Vector3(0.0, 0.34, 0.365)
	crest.rotation.x = PI * 0.5
	add_child(crest)

	var light := OmniLight3D.new()
	light.name = "GreatChestLight"
	light.light_color = Pal.GOLD
	light.light_energy = 0.8
	light.omni_range = 3.4
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.95, 0.15)
	add_child(light)


func _add_trim_box(node_name: String, size: Vector3, at: Vector3,
		material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
