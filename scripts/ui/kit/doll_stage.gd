class_name DollStage
extends Control
## A 3D figure, lit and framed, inside a menu.
##
##     ┌───────────────┐
##     │   ░░░░░░░░    │  ← UITheme.model_backdrop(): a painted pool of light
##     │    ▟█▙        │  ← the rig, in a transparent SubViewport over it
##     │   ▟███▙       │
##     └───────────────┘
##
## Ported from valenfeld's InventoryTab doll viewport + InventoryDollPresenter.
## What came across is the part that is not about its character system: the
## transparent own-world SubViewport, the three-point studio rig, and the AABB
## fit that makes a 1.65 m hero and a 3 m boss both land in the same box.
##
## **`own_world_3d` is not optional.** Without it the SubViewport renders the
## game world — the garrison, the sky, whatever the hero is standing in front of
## — behind the doll, at a camera the menu did not place. It looks like a bug in
## the backdrop and it is very hard to read as "wrong world".
##
## **`UPDATE_WHEN_PARENT_VISIBLE` is not optional either.** An always-on 3D pass
## behind a closed menu is a second full render every frame, and on this Mac
## (unified memory, Metal) idle passes are what feed fence-timeout stalls. The
## mode re-renders while the container is visible and stops the moment it is not.
##
## The stage does not know what a hero is. `hero_rig()` is the one place that
## does, so the pouch card and the equipment screen mount the same figure with
## the same pose rather than each building their own.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

## The hero's art and the merged 72-clip library, the same two `hero.gd` loads.
## Preloaded rather than looked up: a menu that silently showed a T-pose because
## a path moved is exactly the failure this screen exists to make visible.
const HERO_FBX: PackedScene = preload("res://assets/characters/hero.fbx")
const HERO_ANIMS: AnimationLibrary = preload("res://assets/animations/hero_anims.res")
## `hero.gd`'s `clip_idle`. A menu doll standing in the loop is worth the frames:
## a frozen figure reads as a still image of the hero, and a breathing one reads
## as the hero.
const IDLE_CLIP := &"ss_idle_01"

## How much taller than the figure the frame is. 1.0 crops the crown; the fit is
## the *larger* of the height and the footprint, so a wide pose does not push the
## head out of shot either.
const FIT_MARGIN := 1.35
## Camera height as a fraction of the figure. Slightly above the middle, so the
## head sits in the upper third rather than dead centre.
const EYE_OF_H := 0.52

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _viewport != null:
		return
	_build()


## Turn the figure. 0 is square to the camera, which is where an identification
## screen wants it: valenfeld's note on retiring its turntable is that an
## automatic spin regularly left the menu showing a cramped back view that reads
## as a broken doll.
func set_yaw(radians: float) -> void:
	if _pivot != null:
		_pivot.rotation.y = radians


## Put a figure on the stage, replacing whatever is there, and frame it.
##
## Framing is deferred a frame on purpose: a rig whose meshes are still streaming
## reports a zero AABB, and a camera placed off that lands inside the figure.
func mount(rig: Node3D) -> void:
	if _pivot == null:
		_build()
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	if rig == null:
		return
	_pivot.add_child(rig)
	frame_next_frame()


## The mounted figure, or null. The equipment screen uses it to hang a weapon off
## the rig's own sockets rather than drawing a second copy beside it.
func rig() -> Node3D:
	if _pivot == null or _pivot.get_child_count() == 0:
		return null
	return _pivot.get_child(0) as Node3D


func frame_next_frame() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree.process_frame.is_connected(_frame_pending):
		tree.process_frame.connect(_frame_pending, CONNECT_ONE_SHOT)


func _frame_pending() -> void:
	frame_model(rig(), _camera)


# --- the hero -----------------------------------------------------------------

## The hero as a menu figure: the rig, the animation library bound the way
## `hero.gd` binds it, and the idle running.
##
## The FBX ships a stub "" library holding only the T-pose (docs/CONTRACT.md §2).
## Evicting it before adding the real one is not tidying — leave it in and the
## unprefixed clip names resolve to the stub, and the doll stands in a T.
##
## No yaw correction here. The stage's camera sits on +Z looking back at the
## origin, and this art faces +Z, so the raw rig already faces the viewer.
## `hero.gd`'s `model_yaw_offset` of 180 is for the opposite case: in the world
## the body is aimed by `-basis.z` (CLAUDE.md §4), so it needs the flip.
## Measured on the frame, not derived — see tools/directors/doll_lookdev.gd.
static func hero_rig() -> Node3D:
	var rig := HERO_FBX.instantiate() as Node3D
	rig.scale = Vector3.ONE * K.HERO_SCALE
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error("[DollStage] reason=the hero rig has no AnimationPlayer; doll will stand in its rest pose")
		return rig
	if player.has_animation_library(&""):
		player.remove_animation_library(&"")
	player.add_animation_library(&"", HERO_ANIMS)
	if player.has_animation(IDLE_CLIP):
		player.play(IDLE_CLIP)
	else:
		push_warning("[DollStage] clip='%s' reason=not in the library; doll will stand in its rest pose"
			% IDLE_CLIP)
	return rig


# --- framing ------------------------------------------------------------------

## Sit the figure on the floor of the frame, centred, and pull the camera back
## until all of it fits.
##
## The model is MOVED rather than the camera being aimed at it: every stage then
## shares one camera transform, so two dolls of different heights read as two
## figures at the same distance instead of two shots of the same figure.
static func frame_model(model: Node3D, camera: Camera3D) -> void:
	if not is_instance_valid(model) or not is_instance_valid(camera):
		return
	var box := local_aabb(model)
	if box.size == Vector3.ZERO:
		return
	var centre := box.position + box.size * 0.5
	model.position = Vector3(-centre.x, -box.position.y, -centre.z)
	var height := box.size.y
	var fit: float = maxf(height, maxf(box.size.x, box.size.z) * 0.8)
	camera.fov = 30.0
	var dist := (fit * 0.5) / tan(deg_to_rad(camera.fov) * 0.5) * FIT_MARGIN
	var eye := height * EYE_OF_H
	camera.position = Vector3(0.0, eye, dist)
	camera.rotation_degrees = Vector3.ZERO
	var target := Vector3(0.0, eye, 0.0)
	if camera.is_inside_tree():
		camera.look_at(target, Vector3.UP)
	else:
		# `look_at` needs tree registration; the transform form does not, and the
		# stage frames once before it is shown.
		camera.transform = camera.transform.looking_at(target, Vector3.UP)


## The union of every visible mesh under `root`, in the space `root.position` is
## measured in — its PARENT's, with the origin at the rig.
##
## Not the rig's own local space, which is the obvious reading and is wrong:
## `hero_rig()` scales the figure by `K.HERO_SCALE` (the FBX is authored one unit
## tall), so a box measured inside the rig comes back 1.65× short. Framing off
## that put the camera at the hero's chest and cropped his head — visibly, in the
## first frame the doll lookdev ever took.
##
## Skinned meshes report their REST bounds, which is what we want: a doll framed
## off the current animation frame would breathe in and out of its own crop.
static func local_aabb(root: Node3D) -> AABB:
	var to_local := Transform3D(root.basis, Vector3.ZERO) \
		* root.global_transform.affine_inverse()
	var out := AABB()
	var any := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var vis := node as VisualInstance3D
		if vis == null:
			continue
		var box := (to_local * vis.global_transform) * vis.get_aabb()
		out = box if not any else out.merge(box)
		any = true
	return out


# --- construction -------------------------------------------------------------

func _build() -> void:
	var backdrop := UITheme.model_backdrop()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var host := SubViewportContainer.new()
	# stretch drives the SubViewport's size from this container, so the doll is
	# rendered at the resolution it is displayed at rather than scaled up from a
	# fixed one — which on this palette shows as banding across the backdrop.
	host.stretch = true
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	host.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 0.95, 4.0)
	_viewport.add_child(_camera)

	# Without a WorldEnvironment an own-world viewport's ambient is pure black,
	# and the two directional lights alone crush the shadow side to a silhouette.
	# BG_COLOR with a transparent colour, not BG_CLEAR_COLOR — CLAUDE.md §3.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.68, 0.82)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)

	# Three points: a warm key off the left shoulder, a cool fill opposite it to
	# keep the shadow side readable, and a rim from high and behind so the figure
	# separates from the backdrop instead of sinking into it.
	_viewport.add_child(_light(Vector3(-42, 150, 0), 1.4, Color(1.0, 0.96, 0.88)))
	_viewport.add_child(_light(Vector3(-15, -40, 0), 0.55, Color(0.80, 0.86, 0.98)))
	var rim := _light(Vector3(-60, -12, 0), 1.0, Color(1.0, 0.90, 0.76))
	rim.light_specular = 1.3
	_viewport.add_child(rim)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)


static func _light(euler: Vector3, energy: float, tint: Color) -> DirectionalLight3D:
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = euler
	lamp.light_energy = energy
	lamp.light_color = tint
	# No shadows. One figure on an empty stage casts nothing worth the map, and a
	# 4096 shadow atlas per open menu is the cost of drawing nothing.
	lamp.shadow_enabled = false
	return lamp
