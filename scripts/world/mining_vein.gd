class_name MiningVein
extends Interactable
## One deterministic ore site. Dungeon chooses its stable identity and payout;
## this node owns only the work commitment, depletion and physical reward.

const MAT_STONE := preload("res://assets/materials/mat_wall.tres")

const SFX_IMPACT := &"weapon_impact_blunt_2h_heavy"
const WORK_HOLD: float = 0.85
const WORK_DURATION: float = 1.20
const WORK_IMPACT: float = 0.54

@export var site_id: StringName = &""
@export var reward_item_id: StringName = &""
@export_range(1, 99, 1) var reward_count: int = 1

var _intact: Node3D
var _rubble: Node3D
var _interaction_shape: CollisionShape3D
var _ore_material: StandardMaterial3D


## Dungeon-builder API. All three values are fixed before this enters the tree.
func configure(p_site_id: StringName, p_reward_item_id: StringName,
		p_reward_count: int) -> void:
	site_id = p_site_id
	reward_item_id = p_reward_item_id
	reward_count = p_reward_count


func _ready() -> void:
	prompt = "MINE VEIN"
	hold_time = WORK_HOLD
	radius = 2.35
	_build_visuals()
	super()
	_interaction_shape = _find_shape()
	if not _valid_config():
		push_error("MiningVein: invalid site/reward configuration")
		enabled = false
		if _interaction_shape != null:
			_interaction_shape.disabled = true
		return
	_apply_depleted(Run.is_resource_site_depleted(site_id))


func activate(by: Node3D) -> void:
	var refusal := _refusal()
	if not refusal.is_empty():
		Bus.request_message.emit(refusal)
		return
	var hero := by as Hero
	if hero == null:
		return
	if not hero.request_utility_work(ToolDb.PICKAXE_ID, WORK_DURATION,
			global_position + Vector3.UP * 0.55):
		return

	enabled = false
	_commit_at_impact(hero)


func _commit_at_impact(hero: Hero) -> void:
	await get_tree().create_timer(WORK_DURATION * WORK_IMPACT).timeout
	if not is_inside_tree() or not is_instance_valid(hero) \
			or not hero.utility_working(ToolDb.PICKAXE_ID):
		enabled = true
		return
	if not Game.tool_usable(ToolDb.PICKAXE_ID):
		enabled = true
		Bus.request_message.emit(_pickaxe_refusal())
		return

	# No await separates these two mutations. The site wins the idempotency race,
	# then the already re-checked tool pays exactly one use on the same frame.
	if not Run.commit_resource_site_depletion(site_id):
		_apply_depleted(true)
		return
	if not Game.spend_tool_use(ToolDb.PICKAXE_ID):
		push_error("MiningVein: committed %s without a usable pickaxe" % site_id)
		_apply_depleted(true)
		return

	Bus.request_sfx.emit(SFX_IMPACT, global_position + Vector3.UP * 0.45)
	Bus.request_shake.emit(0.48, 0.18)
	_apply_depleted(true)
	_drop_reward()

	var definition := ItemDb.get_def(reward_item_id)
	var item_name := definition.display_name.to_upper() if definition != null \
		else String(reward_item_id).to_upper()
	if Game.tool_durability(ToolDb.PICKAXE_ID) <= 0:
		Bus.request_message.emit("%d %s MINED. YOUR PICKAXE BROKE." \
			% [reward_count, item_name])
	else:
		Bus.request_message.emit("%d %s MINED. PICKAXE %d/%d." % [
			reward_count,
			item_name,
			Game.tool_durability(ToolDb.PICKAXE_ID),
			Game.tool_max_durability(ToolDb.PICKAXE_ID),
		])


func _refusal() -> String:
	if Run.is_resource_site_depleted(site_id):
		return "THIS VEIN IS DEPLETED."
	return _pickaxe_refusal()


func _pickaxe_refusal() -> String:
	if not Game.tool_known(ToolDb.PICKAXE_ID):
		return "YOU NEED A PICKAXE. HAVE ONE FORGED AT THE GARRISON."
	if Game.tool_durability(ToolDb.PICKAXE_ID) <= 0:
		return "YOUR PICKAXE IS BROKEN. REFORGE IT AT THE GARRISON."
	if not Game.tool_usable(ToolDb.PICKAXE_ID):
		return "YOUR PICKAXE IS NOT READY FOR WORK."
	return ""


func _drop_reward() -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var into_room := global_transform.basis.z.normalized()
	LootMote.drop(parent, reward_item_id,
		global_position + Vector3.UP * 0.42 + into_room * 0.52,
		into_room * 0.85, reward_count)


func _valid_config() -> bool:
	return site_id != &"" and reward_count > 0 \
		and ItemDb.get_def(reward_item_id) != null


func _apply_depleted(depleted: bool) -> void:
	if _intact != null:
		_intact.visible = not depleted
	if _rubble != null:
		_rubble.visible = depleted
	enabled = not depleted
	if _interaction_shape != null:
		_interaction_shape.set_deferred(&"disabled", depleted)


func _build_visuals() -> void:
	var definition := ItemDb.get_def(reward_item_id)
	var tint := definition.tint if definition != null else Color(0.62, 0.60, 0.58)
	_ore_material = StandardMaterial3D.new()
	_ore_material.albedo_color = tint
	_ore_material.metallic = 0.45
	_ore_material.roughness = 0.58

	_intact = Node3D.new()
	_intact.name = &"Intact"
	add_child(_intact)
	_rock(_intact, &"RockLarge", Vector3(0.0, 0.72, 0.0),
		Vector3(1.05, 1.38, 0.72), MAT_STONE)
	_rock(_intact, &"RockLeft", Vector3(-0.72, 0.43, 0.16),
		Vector3(0.72, 0.82, 0.58), MAT_STONE)
	_rock(_intact, &"RockRight", Vector3(0.70, 0.38, 0.13),
		Vector3(0.64, 0.72, 0.54), MAT_STONE)
	_ore(_intact, &"OreHigh", Vector3(-0.24, 1.08, 0.48),
		Vector3(0.18, 0.52, 0.13), -0.28)
	_ore(_intact, &"OreMid", Vector3(0.28, 0.66, 0.53),
		Vector3(0.22, 0.44, 0.14), 0.34)
	_ore(_intact, &"OreLow", Vector3(-0.48, 0.38, 0.43),
		Vector3(0.16, 0.34, 0.12), 0.20)

	_rubble = Node3D.new()
	_rubble.name = &"Rubble"
	add_child(_rubble)
	_rock(_rubble, &"RubbleLeft", Vector3(-0.48, 0.15, 0.18),
		Vector3(0.54, 0.28, 0.42), MAT_STONE)
	_rock(_rubble, &"RubbleCentre", Vector3(0.04, 0.12, 0.28),
		Vector3(0.46, 0.22, 0.38), MAT_STONE)
	_rock(_rubble, &"RubbleRight", Vector3(0.52, 0.13, 0.10),
		Vector3(0.42, 0.25, 0.34), MAT_STONE)
	_rubble.visible = false


func _rock(parent: Node3D, node_name: StringName, at: Vector3,
		rock_scale: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = rock_scale
	parent.add_child(instance)


func _ore(parent: Node3D, node_name: StringName, at: Vector3,
		size: Vector3, roll: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _ore_material
	instance.position = at
	instance.rotation.z = roll
	parent.add_child(instance)
