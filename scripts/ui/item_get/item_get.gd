class_name ItemGet
extends Node
## A short, non-pausing item ceremony for an item the player already owns.

const SCREEN_ID := &"item_get"
const MIN_DISMISS_TIME := 2.2
## HOW HIGH HE HOLDS IT, in metres above his own origin. The hero is 1.65 m
## (CLAUDE.md §6), so this is 40 cm of clearance over the top of his head and the
## item's own lower edge lands about 14 cm clear of it.
##
## **It was 2.28 and the playtest note was "floating way too high up on the
## screen"** (card #127): 63 cm over his head, which at this distance is most of
## a body length of empty air between the man and the thing he supposedly just
## lifted out of a box. Picked by photographing five candidates against the same
## chest in the same room -- `tools/directors/item_get_frame.gd --sweep=1`, which
## carries the old value as its first row so the comparison is a pair of frames
## and not a memory. 1.95 was tried and is too low: the halo washes over his head
## and the bow crosses the chest's top rim.
const DISPLAY_HEIGHT := 2.05
const DISPLAY_EXTENT := 0.78
const CAMERA_DISTANCE := 4.2
## THE SHOT, and these three move WITH `DISPLAY_HEIGHT` and never on their own.
## Lowering the item without re-aiming drops it toward the middle of the frame,
## where it is competing with the hero's face; these were swept alongside it and
## put the item back in the upper third (measured at y=0.23 of the frame height
## by `item_get_frame` A4) with the hero's feet still clear of the lower letterbox
## bar at 0.68.
const CAMERA_HEIGHT := 1.85
const CAMERA_TARGET_HEIGHT := 1.28
## Two degrees wider than #108's 38. The camera came DOWN with the item, and at
## 38 the hero's boots went behind the lower bar; the widening is what buys them
## back without moving the camera further off.
const CAMERA_FOV := 40.0
const ROTATION_SPEED := 0.42
const BOB_HEIGHT := 0.055
const BOB_SPEED := 2.4

var item_id: StringName = &""

var _hero: Hero
var _previous_camera: Camera3D
var _previous_hero_facing := 0.0
var _previous_hero_rotation := 0.0
var _camera: Camera3D
var _display_anchor: Node3D
var _display: Node3D
var _display_base: Vector3
var _display_scale := Vector3.ONE
var _aura: RewardVfx.Aura
var _overlay_root: Control
var _age := 0.0
var _started := false
var _finished := false


## Present one ceremony at a time. Repeated calls while one is active return it.
static func present(host: Node, new_item_id: StringName, hero: Hero) -> ItemGet:
	var tree: SceneTree = host.get_tree()
	if tree != null:
		var active := tree.get_first_node_in_group(&"item_get") as ItemGet
		if active != null:
			return active

	var ceremony := ItemGet.new()
	ceremony.name = "ItemGet"
	ceremony.item_id = new_item_id
	ceremony._hero = hero
	host.add_child(ceremony)
	return ceremony


func _enter_tree() -> void:
	add_to_group(&"item_get")


func _ready() -> void:
	if _hero == null or not is_instance_valid(_hero):
		push_warning("ItemGet: presentation needs a live Hero")
		queue_free()
		return

	_previous_camera = _hero.get_viewport().get_camera_3d()
	_build_display()
	_build_camera()
	_build_overlay()

	_started = true
	Prompt.block(self)
	Bus.screen_opened.emit(SCREEN_ID)
	Bus.item_get_started.emit(item_id, _hero.global_position)
	if _hero.combat != null and is_instance_valid(_hero.combat):
		_hero.combat.set_presentation_hidden(true)
	_hero.request_item_get()
	_camera.make_current()
	_reveal_display()


func _exit_tree() -> void:
	_finish()


func _process(delta: float) -> void:
	_age += delta
	if _display != null and is_instance_valid(_display):
		_display.rotation.y = wrapf(_display.rotation.y + ROTATION_SPEED * delta, -PI, PI)
		_display_anchor.global_position = _display_base \
			+ Vector3.UP * sin(_age * BOB_SPEED) * BOB_HEIGHT

	if ready_to_dismiss() and (Input.is_action_just_pressed(&"interact") \
			or Input.is_action_just_pressed(&"ui_accept")):
		dismiss()


## Close after the minimum hold. Early calls deliberately do nothing.
func dismiss() -> void:
	if _finished or not ready_to_dismiss():
		return
	_finish()
	queue_free()


func ready_to_dismiss() -> bool:
	return not _finished and _age >= MIN_DISMISS_TIME


func display_node() -> Node3D:
	return _display


func camera_node() -> Camera3D:
	return _camera


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if not _started:
		return
	if _previous_camera != null and is_instance_valid(_previous_camera) \
			and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	if _hero != null and is_instance_valid(_hero) and _hero.is_inside_tree():
		_hero.facing_yaw = _previous_hero_facing
		_hero.rotation.y = _previous_hero_rotation
		if _hero.combat != null and is_instance_valid(_hero.combat):
			_hero.combat.set_presentation_hidden(false)
	Bus.item_get_finished.emit(item_id)
	Bus.screen_closed.emit(SCREEN_ID)


func _build_camera() -> void:
	# Start on the same side of the hero as the live gameplay camera. The chest,
	# relic and newly opened boss door are all directly in front of him when this
	# begins; putting a cinematic camera there means putting it through the reward
	# geometry. The gameplay camera has already solved that occlusion problem.
	var camera_side := Vector3.ZERO
	if _previous_camera != null and is_instance_valid(_previous_camera):
		camera_side = _previous_camera.global_position - _hero.global_position
	camera_side.y = 0.0
	if camera_side.length_squared() <= 0.0001:
		camera_side = _hero.global_basis.z
	camera_side = camera_side.normalized()

	_camera = Camera3D.new()
	_camera.name = "ItemGetCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = 0.08
	_camera.far = 80.0
	add_child(_camera)
	_camera.top_level = true
	_camera.global_position = _hero.global_position + camera_side * CAMERA_DISTANCE \
		+ Vector3.UP * CAMERA_HEIGHT
	_camera.look_at(_hero.global_position + Vector3.UP * CAMERA_TARGET_HEIGHT, Vector3.UP)

	# The live camera normally watches the hero's back. For the item pose he turns
	# to the lens, then returns to the exact gameplay facing on dismissal.
	_previous_hero_facing = _hero.facing_yaw
	_previous_hero_rotation = _hero.rotation.y
	var to_camera := camera_side
	_hero.facing_yaw = atan2(to_camera.x, to_camera.z)
	_hero.rotation.y = _hero.facing_yaw + PI


func _build_display() -> void:
	_display_anchor = Node3D.new()
	_display_anchor.name = "ItemGetDisplayAnchor"
	add_child(_display_anchor)
	_display_anchor.top_level = true
	_display_base = _hero.global_position + Vector3.UP * DISPLAY_HEIGHT
	_display_anchor.global_position = _display_base

	_display = Node3D.new()
	_display.name = "Display"
	_display_anchor.add_child(_display)

	var model := _make_item_visual()
	_display.add_child(model)
	var bounds := _local_aabb(_display)
	if bounds.size.length_squared() > 0.0001:
		model.position -= bounds.get_center()
		var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var scale_factor := clampf(DISPLAY_EXTENT / maxf(longest, 0.01), 0.25, 2.6)
		_display_scale = Vector3.ONE * scale_factor

	# THE ITEM'S OWN LIGHT (card #127). This was a bare OmniLight3D hung a metre
	# off to one side, which lit the model and did nothing at all for the frame:
	# from the ceremony camera the bow was a well-lit object with no reason to be
	# in the air. `RewardVfx.aura` is the same light plus the two things that make
	# it read as glowing -- a soft disc standing behind it and a slow drift of
	# motes around it -- and it lives there so the reward vocabulary stays in one
	# file (#127 says so explicitly).
	#
	# Sized off the item and not off a constant: `DISPLAY_EXTENT` is the longest
	# edge every model is fitted to, so a halo a little wider than half of it sits
	# around the silhouette rather than behind it like a plate.
	_aura = RewardVfx.aura(_display_anchor, DISPLAY_EXTENT * 0.62)


func _make_item_visual() -> Node3D:
	var model: Node3D
	match item_id:
		&"bow":
			model = WeaponModels.make("bow_knightly")
			if model != null:
				model.rotation = Vector3(0.9, 0.9, 0.4)
		&"hookshot":
			model = WeaponModels.make("hookshot_pistol")
			if model != null:
				model.rotation = Vector3(0.35, 0.55, 0.0)
	if model != null:
		return model
	return _make_fallback()


func _make_fallback() -> Node3D:
	var plaque := Node3D.new()
	plaque.name = "FallbackPlaque"

	var accent := UITheme.ACCENT
	if item_id == &"burst":
		accent = Pal.ARCANE
	elif item_id == &"far_lantern":
		accent = Color(0.95, 0.72, 0.32)

	var frame_mat := _material(accent, 0.72, accent * 0.22)
	var face_mat := _material(Color(0.055, 0.052, 0.05), 0.18, Color.BLACK)
	_make_box(plaque, Vector3(0.76, 0.56, 0.07), Vector3.ZERO, frame_mat)
	_make_box(plaque, Vector3(0.66, 0.46, 0.085), Vector3(0.0, 0.0, 0.018), face_mat)

	var mark := Label3D.new()
	mark.name = "Mark"
	mark.text = ArmamentDb.letter(item_id)
	mark.font = UITheme.display_font()
	mark.font_size = 96
	mark.pixel_size = 0.0042
	mark.modulate = UITheme.TEXT
	mark.outline_size = 8
	mark.outline_modulate = Color(0.02, 0.02, 0.02, 0.9)
	mark.position = Vector3(0.0, -0.01, 0.07)
	plaque.add_child(mark)
	return plaque


func _material(color: Color, metallic: float, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.38
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat


func _make_box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = material
	parent.add_child(mesh)


func _local_aabb(root: Node3D) -> AABB:
	var to_local := root.global_transform.affine_inverse()
	var out := AABB()
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var box: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()
		out = out.merge(box) if found else box
		found = true
	return out


func _reveal_display() -> void:
	_display.scale = _display_scale * 0.04
	_display.position = Vector3(0.0, -0.24, 0.0)
	var reveal := create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_display, "scale", _display_scale, 0.68)
	reveal.tween_property(_display, "position", Vector3.ZERO, 0.58) \
		.set_trans(Tween.TRANS_CUBIC)
	# The halo opens WITH the item. Left at full size it is a gold disc hanging in
	# the frame for two thirds of a second before the thing it belongs to arrives,
	# which reads as the light being the reward.
	#
	# The Aura's own `_process` writes its DISC's scale; this scales the Aura
	# node, and the two multiply. Tweening the disc from here instead would have
	# the breathing overwrite the reveal on the next frame.
	if _aura != null:
		_aura.scale = Vector3.ONE * 0.15
		reveal.tween_property(_aura, "scale", Vector3.ONE, 0.62) \
			.set_trans(Tween.TRANS_CUBIC)


func _build_overlay() -> void:
	UITheme.prewarm()
	var layer := CanvasLayer.new()
	layer.name = "ItemGetOverlay"
	layer.layer = 70
	add_child(layer)

	_overlay_root = Control.new()
	_overlay_root.name = "Root"
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.theme = UITheme.theme()
	layer.add_child(_overlay_root)
	_fit_overlay()
	get_viewport().size_changed.connect(_fit_overlay)

	var top_bar := ColorRect.new()
	top_bar.name = "TopBar"
	top_bar.color = Color(0.0, 0.0, 0.0, 0.9)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.12
	_overlay_root.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.color = Color(0.0, 0.0, 0.0, 0.92)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.anchor_top = 0.68
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	_overlay_root.add_child(bottom_bar)

	var panel := Panel.new()
	panel.name = "MessagePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.13
	panel.anchor_top = 0.70
	panel.anchor_right = 0.87
	panel.anchor_bottom = 0.96
	panel.add_theme_stylebox_override("panel", UITheme.hud_box(
		Color(0.045, 0.044, 0.043, 0.95), 24, 14, 24, 14))
	_overlay_root.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "You got the %s!" % _ceremony_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.anchor_left = 0.04
	title.anchor_top = 0.06
	title.anchor_right = 0.96
	title.anchor_bottom = 0.50
	# The official item names include qualifiers such as "Knightly" and "Far".
	# H1 keeps the whole sentence on one line at the 1280-wide proof viewport.
	UITheme.apply_text_style(title, UITheme.TYPE_H1)
	panel.add_child(title)

	var blurb := Label.new()
	blurb.name = "Blurb"
	blurb.text = ArmamentDb.blurb(item_id)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blurb.anchor_left = 0.08
	blurb.anchor_top = 0.52
	blurb.anchor_right = 0.92
	blurb.anchor_bottom = 0.94
	UITheme.apply_text_style(blurb, UITheme.TYPE_PARAGRAPH_2)
	panel.add_child(blurb)


func _fit_overlay() -> void:
	if _overlay_root == null:
		return
	_overlay_root.position = Vector2.ZERO
	_overlay_root.size = get_viewport().get_visible_rect().size


func _ceremony_name() -> String:
	var display_name := ArmamentDb.name_of(item_id)
	return display_name.trim_prefix("The ") if display_name.begins_with("The ") \
		else display_name
