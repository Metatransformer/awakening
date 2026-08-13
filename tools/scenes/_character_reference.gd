extends Node3D
## Render one authored NpcBody source model in its imported bind pose.
##
## Must run windowed; a headless run has no rendering device and saves an empty
## image. The SubViewport owns its world, so neither the game environment nor the
## window clear colour can leak into the transparent reference.
##
##   timeout 400 tools/quiet.sh --path . res://tools/scenes/_character_reference.tscn -- \
##     --who=lanternkeeper --out=/tmp/character_reference.png

const SIZE := 1024
const PAD := 1.30
const DEFAULT_WHO := "lanternkeeper"
const DEFAULT_OUT := "/tmp/character_reference.png"
const EXIT_USAGE := 2
const EXIT_RENDER := 3

var _who := DEFAULT_WHO
var _out_path := DEFAULT_OUT


func _ready() -> void:
	_parse_args()
	_run.call_deferred()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--who="):
			_who = arg.substr(6)
		elif arg.begins_with("--out="):
			_out_path = arg.substr(6)


func _run() -> void:
	if not NpcBody.PEOPLE.has(_who):
		_fail("unknown --who='%s' (have %s)" % [_who, NpcBody.PEOPLE.keys()], EXIT_USAGE)
		return
	if not _valid_output_path(_out_path):
		_fail("--out must be an absolute or res:// PNG path, got '%s'" % _out_path, EXIT_USAGE)
		return

	var row: Dictionary = NpcBody.PEOPLE[_who]
	var source_path := NpcBody.DIR + str(row.get("fbx", ""))
	print("CHARACTER_REFERENCE model=%s" % _who)
	print("CHARACTER_REFERENCE source=%s" % source_path)
	print("CHARACTER_REFERENCE output=%s" % _out_path)

	if str(row.get("fbx", "")).is_empty() or not ResourceLoader.exists(source_path):
		_fail("authored model is missing at %s" % source_path, EXIT_USAGE)
		return
	var packed := load(source_path) as PackedScene
	if packed == null:
		_fail("authored model did not load as a PackedScene: %s" % source_path, EXIT_USAGE)
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		_fail("authored model root is not Node3D: %s" % source_path, EXIT_USAGE)
		return
	# Reference what ships in the game, including a measured per-model axis fix.
	# This matters when a future concept chooses Tamsin herself as its required
	# existing-character reference: her raw Tripo export is +X-facing, while the
	# integrated NpcBody contract is +Z.
	model.rotation.y = float(row.get("yaw", NpcBody.MODEL_YAW))

	var viewport := _make_viewport()
	add_child(viewport)
	viewport.add_child(model)
	_hold_imported_bind_pose(model)

	var measured := _measure_bounds(model)
	var mesh_count: int = measured["mesh_count"]
	if mesh_count == 0:
		_fail("authored model has no visible meshes: %s" % source_path, EXIT_RENDER)
		return
	var bounds: AABB = measured["bounds"]
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		_fail("authored model has invalid bounds %s at %s" % [bounds, source_path], EXIT_RENDER)
		return
	print("CHARACTER_REFERENCE bounds position=%s size=%s meshes=%d" % [
		bounds.position, bounds.size, mesh_count])

	_add_environment(viewport)
	_add_lighting(viewport, bounds)
	_add_camera(viewport, bounds)

	# Two completed draws avoid capturing the allocation/compile frame while all
	# animation sources remain disabled, so every run photographs the same pose.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if image == null or image.is_empty():
		_fail("viewport rendered no image", EXIT_RENDER)
		return
	if image.get_size() != Vector2i(SIZE, SIZE):
		_fail("viewport returned %s instead of %dx%d" % [image.get_size(), SIZE, SIZE], EXIT_RENDER)
		return
	if not _corners_are_transparent(image):
		_fail("render background is not transparent", EXIT_RENDER)
		return
	if image.get_used_rect().size == Vector2i.ZERO:
		_fail("model rendered no visible pixels", EXIT_RENDER)
		return

	var absolute_out := ProjectSettings.globalize_path(_out_path) if _out_path.begins_with("res://") else _out_path
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_out.get_base_dir())
	if mkdir_error != OK:
		_fail("could not create output directory for %s (%d)" % [_out_path, mkdir_error], EXIT_RENDER)
		return
	var save_error := image.save_png(_out_path)
	if save_error != OK:
		_fail("could not save %s (%d)" % [_out_path, save_error], EXIT_RENDER)
		return
	print("CHARACTER_REFERENCE OK model=%s size=%dx%d output=%s" % [
		_who, image.get_width(), image.get_height(), _out_path])
	get_tree().quit()


func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "ReferenceViewport"
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.use_taa = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return viewport


func _hold_imported_bind_pose(model: Node3D) -> void:
	for node in _all_nodes(model):
		var tree := node as AnimationTree
		if tree != null:
			tree.active = false
		var player := node as AnimationPlayer
		if player != null:
			player.stop()
		var skeleton := node as Skeleton3D
		if skeleton != null:
			skeleton.clear_bones_global_pose_override()
			skeleton.reset_bone_poses()


func _measure_bounds(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var mesh_count := 0
	for node in _all_nodes(model):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = mesh_bounds if mesh_count == 0 else bounds.merge(mesh_bounds)
		mesh_count += 1
	return {"bounds": bounds, "mesh_count": mesh_count}


func _add_camera(viewport: SubViewport, bounds: AABB) -> void:
	var center := bounds.get_center()
	var depth := maxf(bounds.size.length() * 2.0, 1.0)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(bounds.size.x, bounds.size.y) * PAD
	# NpcBody's integrated contract is +Z-facing. A camera on +Z looking down its
	# native -Z therefore sees the corrected authored front.
	camera.position = Vector3(center.x, center.y, bounds.end.z + depth)
	camera.near = 0.01
	camera.far = depth + bounds.size.z + 1.0
	viewport.add_child(camera)
	camera.make_current()


func _add_lighting(viewport: SubViewport, bounds: AABB) -> void:
	var center := bounds.get_center()
	var reach := maxf(bounds.size.length(), 1.0)
	var key := _directional_light(
		center + Vector3(-2.5, 3.5, 4.0) * reach,
		center,
		2.2,
		Color(1.0, 0.86, 0.70))
	key.name = "WarmKey"
	viewport.add_child(key)

	var rim := _directional_light(
		center + Vector3(2.5, 2.0, -4.0) * reach,
		center,
		1.4,
		Color(0.70, 0.84, 1.0))
	rim.name = "CoolRim"
	viewport.add_child(rim)


func _directional_light(
		position: Vector3, target: Vector3, energy: float, color: Color
	) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	# The light is configured before it enters the tree. `look_at()` refuses that
	# ordering; the explicit form derives the same basis without a live parent.
	light.look_at_from_position(position, target, Vector3.UP)
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = false
	return light


func _add_environment(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.46, 0.54)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ACES"
	world_environment.environment = environment
	viewport.add_child(world_environment)


func _corners_are_transparent(image: Image) -> bool:
	var last := SIZE - 1
	for point in [Vector2i.ZERO, Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		if image.get_pixelv(point).a > 0.001:
			return false
	return true


func _valid_output_path(path: String) -> bool:
	return (path.begins_with("/") or path.begins_with("res://")) and path.get_extension().to_lower() == "png"


func _all_nodes(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_all_nodes(child))
	return found


func _fail(message: String, exit_code: int) -> void:
	push_error("character_reference: %s" % message)
	print("CHARACTER_REFERENCE FAIL: %s" % message)
	get_tree().quit(exit_code)
