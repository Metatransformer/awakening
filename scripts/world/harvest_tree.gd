class_name HarvestTree
extends Interactable
## One reusable tree-cutting interaction. Game owns whether a bundle may exist;
## this node owns only the selected tree's prompt, collider and presentation.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")

const SFX_AXE_HIT := &"axe_tree_hit"
const SFX_TREE_FALL := &"tree_fall"
const CHOP_HOLD: float = 0.85
const CHOP_DURATION: float = 1.20
const CHOP_IMPACT: float = 0.54
const FALL_DURATION: float = 0.62
const BASE_TRUNK_HEIGHT: float = 3.5
const BASE_TRUNK_RADIUS: float = 0.24
const BASE_STUMP_HEIGHT: float = 0.34

var _index: int = 0
var _grove_count: int = 1
var _packed_visual: PackedScene
var _scale_factor: float = 1.0
var _display_day: int = 0
var _visual_pivot: Node3D
var _visual_model: Node3D
var _trunk_body: StaticBody3D
var _trunk_collision: CollisionShape3D
var _stump: MeshInstance3D
var _fall_tween: Tween


## Route-builder API. Configure before adding the node to the tree; calls made
## after `_ready` are also accepted and rebuild only this tree's presentation.
func configure(index: int, grove_count: int, packed: PackedScene,
		scale_factor: float = 1.0) -> void:
	_index = maxi(index, 0)
	_grove_count = maxi(grove_count, 1)
	_packed_visual = packed
	_scale_factor = maxf(scale_factor, 0.0001)
	if is_node_ready():
		call_deferred(&"_rebuild")


func _ready() -> void:
	prompt = "CHOP TREE"
	hold_time = CHOP_HOLD
	radius = 2.35
	super()
	_rebuild()
	Clock.minute_changed.connect(_on_minute_changed)


func activate(by: Node3D) -> void:
	var refusal := _refusal()
	if not refusal.is_empty():
		Bus.request_message.emit(refusal)
		return
	var hero := by as Hero
	if hero == null:
		return
	if not hero.request_woodsman_chop(CHOP_DURATION,
			global_position + Vector3.UP * BASE_STUMP_HEIGHT):
		return

	enabled = false
	_commit_at_impact(hero)


func _commit_at_impact(hero: Hero) -> void:
	await get_tree().create_timer(CHOP_DURATION * CHOP_IMPACT).timeout
	if not is_inside_tree() or not is_instance_valid(hero) or not hero.woodsman_chopping():
		enabled = true
		return
	# This is the sole mutation. The checks above are presentation-time feedback;
	# Game still gets the last word on the exact frame the axe meets the trunk.
	if not Game.chop_firewood(Clock.day, Clock.garrison_phase()):
		enabled = true
		return
	Game.spend_tool_use(ToolDb.WOODSMAN_AXE_ID)

	# Both cues belong to the contact point. The utility animation can be
	# cancelled before this frame, while this is the one frame the tree commits.
	Bus.request_sfx.emit(SFX_AXE_HIT, global_position)
	_disable_trunk()
	_stump.visible = true
	_fall_away_from(hero.global_position)
	Bus.request_sfx.emit(SFX_TREE_FALL, global_position)
	var remaining: int = Game.tool_durability(ToolDb.WOODSMAN_AXE_ID)
	var durability: String = "AXE BROKEN — BRANNOC MUST REFORGE IT." \
		if remaining <= 0 else "AXE %d / %d" % [remaining,
			Game.tool_max_durability(ToolDb.WOODSMAN_AXE_ID)]
	Bus.request_message.emit("FIREWOOD CUT. CARRY IT TO THE GARRISON HEARTH. · " \
		+ durability)


func _refusal() -> String:
	if not Game.tool_known(ToolDb.WOODSMAN_AXE_ID):
		if not Game.flag(StoryDb.told_flag(&"elder", &"timber_duty")):
			return "YOU NEED A WOODSMAN'S AXE. SPEAK TO ALDRIC."
		return "BRANNOC FORGES THE WOODSMAN'S AXE."
	if not Game.tool_usable(ToolDb.WOODSMAN_AXE_ID):
		return "THE WOODSMAN'S AXE IS BROKEN. BRANNOC MUST REFORGE IT."
	if Clock.garrison_phase() != WorldClock.GARRISON_DAYTIME:
		return "CHOP FIREWOOD DURING DAYTIME."
	if Game.carrying_firewood:
		return "YOU ARE ALREADY CARRYING FIREWOOD."
	if Game.firewood_stock >= Game.FIREWOOD_CAP:
		return "THE GARRISON HEARTH IS FULL."
	if Game.timber_completed_day == Clock.day:
		return "TODAY'S BUNDLE IS ALREADY CUT."
	return ""


func _on_minute_changed(day: int, _hour: int, _minute: int) -> void:
	if day != _display_day:
		_apply_saved_state()


func _rebuild() -> void:
	_clear_built_nodes()

	var trunk_height := BASE_TRUNK_HEIGHT
	var trunk_radius := BASE_TRUNK_RADIUS
	_trunk_body = StaticBody3D.new()
	_trunk_body.name = &"SolidTrunk"
	_trunk_body.collision_layer = K.L_WORLD
	_trunk_body.collision_mask = 0
	_trunk_body.position.y = trunk_height * 0.5
	add_child(_trunk_body)
	_trunk_collision = CollisionShape3D.new()
	_trunk_collision.name = &"TrunkCollision"
	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	_trunk_collision.shape = shape
	_trunk_body.add_child(_trunk_collision)

	_visual_pivot = Node3D.new()
	_visual_pivot.name = &"FallPivot"
	_visual_pivot.position.y = BASE_STUMP_HEIGHT
	add_child(_visual_pivot)
	if _packed_visual != null:
		_visual_model = _packed_visual.instantiate() as Node3D
		_visual_model.name = &"TreeVisual"
		_visual_model.position.y = -_visual_pivot.position.y
		_visual_model.scale = Vector3.ONE * _scale_factor
		_visual_pivot.add_child(_visual_model)
	else:
		_visual_model = _primitive_visual(trunk_radius, trunk_height)

	_stump = MeshInstance3D.new()
	_stump.name = &"Stump"
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = trunk_radius * 1.08
	stump_mesh.bottom_radius = trunk_radius * 1.12
	stump_mesh.height = BASE_STUMP_HEIGHT
	stump_mesh.radial_segments = 9
	_stump.mesh = stump_mesh
	_stump.material_override = MAT_WOOD
	_stump.position.y = stump_mesh.height * 0.5
	add_child(_stump)

	_apply_saved_state()


func _primitive_visual(radius: float, height: float) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.name = &"TreeVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	instance.mesh = mesh
	instance.material_override = MAT_WOOD
	instance.position.y = height * 0.5 - _visual_pivot.position.y
	_visual_pivot.add_child(instance)
	return instance


func _apply_saved_state() -> void:
	_display_day = Clock.day
	if _fall_tween != null and _fall_tween.is_valid():
		_fall_tween.kill()
	if _visual_pivot == null:
		return
	_visual_pivot.rotation = Vector3.ZERO
	var saved_stump := Game.timber_completed_day == Clock.day \
		and _index == posmod(Clock.day - 1, _grove_count)
	_visual_pivot.visible = not saved_stump
	_stump.visible = saved_stump
	_trunk_collision.disabled = saved_stump
	enabled = not saved_stump


func _disable_trunk() -> void:
	if _trunk_collision != null:
		_trunk_collision.set_deferred(&"disabled", true)


func _fall_away_from(hero_position: Vector3) -> void:
	var world_away := global_position - hero_position
	world_away.y = 0.0
	if world_away.length_squared() <= 0.0001:
		world_away = -global_transform.basis.z
	world_away = world_away.normalized()
	var local_away := global_transform.basis.inverse() * world_away
	_visual_pivot.rotation.y = atan2(local_away.x, local_away.z) + PI
	_fall_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_fall_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall_tween.tween_property(_visual_pivot, ^"rotation:x", -PI * 0.5, FALL_DURATION)


func _clear_built_nodes() -> void:
	var built: Array[Node] = [_visual_pivot, _trunk_body, _stump]
	for node: Node in built:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_visual_pivot = null
	_visual_model = null
	_trunk_body = null
	_trunk_collision = null
	_stump = null
