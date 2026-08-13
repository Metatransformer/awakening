class_name ScreenPresent
extends Node
## Legacy migration diagnostic: the world renders into a fixed
## **480 x 270** buffer and is presented to the window sharp-bilinear, with
## a Bayer RGB555 quantizer applied at that internal resolution, while the
## HUD, the menus and Flow's fade stay at native.
##
## Owned by `Settings` (it is instanced in `Settings._ready` and driven from
## `Settings.apply_video`), because **there is no autoload slot for it**:
## `project.godot` is orchestrator-owned (`docs/CONTRACT.md` §3) and a render
## pipeline is not worth an `[autoload]` line that every agent then merges around.
## `Settings.apply_video` already owned `msaa_3d`, `scaling_3d_scale` and the
## shadow atlas, and those three now have to land on whichever viewport is
## actually drawing 3D -- so this is the same knob's new address, not a new one.
##
## ## Why the world is NOT reparented into the SubViewport
##
## The obvious build is to move `current_scene` under the SubViewport. It is
## wrong here for two reasons, and the second one is fatal:
##
##  1. Two things attach the scene -- `Flow` calls `change_scene_to_file` and
##     `tools/shoot.gd` calls a plain `root.add_child` -- so a reparent has to be
##     a poll, and a poll means every scene in the game takes an extra
##     `_exit_tree` / `_enter_tree` pair it was never written to survive.
##  2. `unproject_position` returns coordinates in the CAMERA'S viewport. Move
##     the camera into a 480 x 270 SubViewport and every world-anchored HUD
##     widget -- the lock brackets, the enemy bars, the damage numbers,
##     `Targeting`'s screen-space tie-break, `Feel`'s shake -- starts computing
##     480 x 270 positions and painting them on a 1280 x 720 canvas. Nine call
##     sites, all silent, all wrong by 2.67x.
##
## So the scene never moves. The SubViewport **shares the root's `World3D`** (a
## SubViewport with `own_world_3d = false` inherits its parent viewport's world),
## carries a proxy `Camera3D` that mirrors the live one every frame, and the root
## window gets `disable_3d = true` so the same scenario is not drawn twice. The
## real `GameCamera` stays exactly where it was, in the root viewport at
## 1280 x 720, and every unprojection above keeps answering in native pixels --
## which is correct, because the internal buffer covers the identical rectangle.
##
## ## The one thing to know before changing it
##
## `Settings.internal_render` is the single field. False restores the native
## renderer exactly: `disable_3d` off, the present layer hidden, the SubViewport
## parked. Nothing else in the project branches on it.

## Fixed legacy comparison buffer. PSX was 320x240 = 76.8k px; this is 129.6k,
## the smallest buffer where the over-the-shoulder camera still resolves an enemy
## wind-up at the 9 m lock-on range.
const INTERNAL := Vector2i(480, 270)

const PRESENT_SHADER := "res://assets/shaders/present_psx.gdshader"

## Below `Hud` (50), below anything a scene puts on layer 0, and below Flow's
## fade (200). The present rect is the floor of the canvas stack.
const LAYER := -100

var _root: Window = null
var _layer: CanvasLayer = null
var _rect: TextureRect = null
var _sub: SubViewport = null
var _cam: Camera3D = null
var _mat: ShaderMaterial = null
var _on: bool = false


func _ready() -> void:
	# The mirror has to run after whatever moved the camera this frame --
	# `GameCamera._process`, `Feel`'s shake -- or the world lags the HUD by a
	# frame on every camera move. Priority is "later", not "sooner".
	process_priority = 1000
	# `Menu` and `LoadingCard` pause the tree and the world still has to be on
	# screen behind them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = get_tree().root
	_build()
	set_enabled(false)


func _build() -> void:
	_sub = SubViewport.new()
	_sub.name = &"InternalWorld"
	_sub.size = INTERNAL
	# `own_world_3d` stays FALSE: that is what makes this viewport draw the same
	# scenario the scene's nodes registered into. Turning it on gives a black
	# frame and no error.
	_sub.own_world_3d = false
	_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sub.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_sub.transparent_bg = false
	# The diagnostic viewport is created in code and gets none of
	# `project.godot`'s rendering defaults for free.
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.msaa_2d = Viewport.MSAA_DISABLED
	_sub.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	_sub.use_taa = false
	# Godot's debanding is a noise dither over the whole frame and it fights the
	# diagnostic quantizer pixel for pixel.
	_sub.use_debanding = false
	_sub.use_hdr_2d = false
	_sub.scaling_3d_scale = 1.0
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub.gui_disable_input = true
	_sub.audio_listener_enable_3d = false
	add_child(_sub)

	_cam = Camera3D.new()
	_cam.name = &"PresentCamera"
	_cam.current = false
	_sub.add_child(_cam)

	_mat = ShaderMaterial.new()
	_mat.shader = load(PRESENT_SHADER) as Shader
	_mat.set_shader_parameter(&"src_size", Vector2(INTERNAL))
	_mat.set_shader_parameter(&"quantize", true)

	_rect = TextureRect.new()
	_rect.name = &"Present"
	_rect.texture = _sub.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **LINEAR, deliberately; the diagnostic SubViewport's own 2D is NEAREST.**
	# Sharp bilinear IS a bilinear tap -- the shader snaps the sample to the texel
	# centre and only lets it cross the boundary over one output pixel, and it
	# needs the hardware blend to do that. Set NEAREST here and the shader
	# degenerates to raw nearest and shimmers at 720p's 2.67x. NEAREST is what the
	# SubViewport's own 2D uses, above.
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rect.material = _mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	_layer = CanvasLayer.new()
	_layer.name = &"PresentLayer"
	_layer.layer = LAYER
	_layer.visible = false
	_layer.add_child(_rect)
	add_child(_layer)


## The one switch. `Settings.internal_render` is its only caller.
func set_enabled(on: bool) -> void:
	_on = on
	if _root != null:
		_root.disable_3d = on
	_layer.visible = on
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
		else SubViewport.UPDATE_DISABLED
	_cam.current = on
	if on:
		_sync()


func enabled() -> bool:
	return _on


## The internal buffer's real size, for a director that wants to print it.
func internal_size() -> Vector2i:
	return _sub.size if _sub != null else Vector2i.ZERO


## The SubViewport's RID, so a director can put
## `RenderingServer.viewport_set_measure_render_time` on the viewport that is
## actually drawing the world. With the diagnostic on, the ROOT's measured
## render time is the cost of one textured quad and says nothing about the frame.
func viewport_rid() -> RID:
	return _sub.get_viewport_rid() if _sub != null else RID()


## `Settings.apply_video`'s three viewport knobs, mirrored onto the diagnostic
## viewport. Called whether or not the pipeline is on, so flipping the field does
## not lose the player's shadow or MSAA choice.
func apply_video(msaa: int, shadow_atlas: int, scale_3d: float) -> void:
	if _sub == null:
		return
	_sub.msaa_3d = clampi(msaa, 0, 3) as Viewport.MSAA
	_sub.positional_shadow_atlas_size = shadow_atlas
	_sub.scaling_3d_scale = clampf(scale_3d, 0.5, 1.0)


## Turn the RGB555 quantizer off without leaving the internal buffer, so a
## director can photograph the upscale and the colour depth as two claims.
func set_quantize(on: bool) -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"quantize", on)


func _process(_delta: float) -> void:
	if _on:
		_sync()


## Copy the live camera onto the proxy.
##
## Everything here is a property the game actually animates: `GameCamera` blends
## `fov` every frame (free / parallel / aim / first-person, plus the player's own
## `Settings.fov_offset`), and `Feel` moves the transform for shake. A proxy that
## only copied the transform would photograph the right place through the wrong
## lens the moment the hero raised the bow.
func _sync() -> void:
	var src := _root.get_camera_3d() if _root != null else null
	if src == null:
		return
	_cam.global_transform = src.global_transform
	_cam.projection = src.projection
	_cam.fov = src.fov
	_cam.size = src.size
	_cam.near = src.near
	_cam.far = src.far
	_cam.keep_aspect = src.keep_aspect
	_cam.cull_mask = src.cull_mask
	_cam.h_offset = src.h_offset
	_cam.v_offset = src.v_offset
	if _cam.attributes != src.attributes:
		_cam.attributes = src.attributes
	if _cam.environment != src.environment:
		_cam.environment = src.environment
