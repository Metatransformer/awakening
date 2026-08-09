class_name KitStyle
extends RefCounted
## The dungeon look, as numbers, plus the four zones the kit wears them in.
##
## `K` (scripts/core/consts.gd) is orchestrator-owned and holds what OTHER packages
## can see — sizes, layers, speeds. Nothing here crosses a package boundary: these
## are P6's own art defaults, referenced by the kit scripts so a critic changes a
## value once instead of hunting it through eleven .tscn overrides.
## See the `# NEEDS` note in the P6 report about promoting the torch colour to `K`
## if the item/feel packages end up wanting to match it.
##
## ## What the "Zone" half of this file is for
##
## `FloorDb.TINTS` has held four authored palettes since the Descent was planned
## and **nothing read them** — every floor rendered in the same beige. Four tints
## is the whole environmental variety budget for one kit (`docs/SCOPE.md` §1), so
## an unread tint table is not a missing polish pass, it is three quarters of the
## game's art direction sitting in a dictionary. The bottom half of this file is
## what reads it: one row of `FloorDb.TINTS` now drives the stone, the fire, the
## fill light, the air and the fog of every kit piece in the room.

# --- Masonry -----------------------------------------------------------------
## Height of one course of blocks. OOT dungeon blocks are BIG — roughly waist-high
## on a 1.65 m hero, so a wall is only 7-8 courses tall, not 20.
const COURSE_H := 0.92
## Nominal block width before per-block jitter (0.72x .. 1.34x).
const BLOCK_W := 1.55
## Recess on every side of a block. This gap is the mortar line.
const JOINT := 0.075
## How far the proudest block stands out from the backing slab, in metres.
const RELIEF := 0.17
## Metres of wall per UV unit. Only feeds the tangent basis (the stone shaders are
## world-space), but keep it consistent so normal-map depth reads the same everywhere.
const UV_SCALE := 0.5

const WALL_THICKNESS := 0.8
const FLOOR_THICKNESS := 0.6
const CEIL_THICKNESS := 0.7

# --- Contact ------------------------------------------------------------------
## Metres over which a surface recovers from touching the floor, and how dark it
## gets right at the joint. Wall bases, plinths, pillar plinths and prop bottoms
## all use these, so the whole room's contact shadows agree on one falloff.
##
## Before this existed EVERY surface in the dungeon met every other surface at
## full brightness and the room read as a blockout with a stone texture on it.
## A contact shadow is the cheapest possible cue that two solid things are
## touching, and its absence was most of what the critic saw.
const CONTACT_H := 1.05
const CONTACT_MIN := 0.40

# --- Torch fire ---------------------------------------------------------------
## Warm, slightly orange-red. OOT torchlight is never white and never yellow-green.
## Per-floor overrides live in `FloorDb.TINTS[...].fire`; this is the base the
## Cistern's own tint is measured against.
const FIRE_COLOR := Color(1.0, 0.76, 0.5)
## Energy of one torch's omni light.
##
## Was 9.5, which — against `FIRE_RANGE` 15 — put every surface of a 16 m room
## inside one torch's full-strength reach and produced the single beige sheet
## STYLEGUIDE §1 rule 1 names as the failure mode of the brightening pivot. The
## fix is not a darker room: it is a SHORTER one. At 6.0/10.5 the pools still
## overlap along a wall (you can walk sconce to sconce without crossing a hole)
## but the middle of a room, a corner and a doorway now fall back to ambient +
## fill, which is cool — so the frame holds warm light AND cool dark at once,
## which is what "contrast is range and hue" actually asks for.
const FIRE_ENERGY := 6.0
## Metres. A sconce reaches most of the way to the next sconce, not past it.
const FIRE_RANGE := 10.5
## >1 curves the falloff so the pool of light has a shape instead of a soft
## infinite gradient. This single number is most of the torchlit read.
##
## It used to be 1.6, which put a hard edge on every pool and dropped the space
## BETWEEN two sconces to black — the room was a string of spotlights in a void,
## which reads as a horror crawler and not as a lit place (STYLEGUIDE §1). It was
## then flattened to 1.3, which with the old energy/range flooded everything. 1.5
## is the middle the two failures bracket: a visible pool edge, no hole after it.
const FIRE_ATTENUATION := 1.5
const FIRE_FLICKER := 0.16
const FIRE_FLICKER_SPEED := 6.5
## Torchlight on wet, rough masonry is a diffuse bloom, not a glint. The shipped
## 0.35 put a specular hotspot on every proud block and that sheen is a large
## part of why the wall read as moulded plastic.
const FIRE_SPECULAR := 0.10

## Height above the floor a wall sconce's flame sits at.
const SCONCE_Y := 2.35


# ==============================================================================
# Zones — one row of FloorDb.TINTS, applied to the whole kit
# ==============================================================================

## The grain maps. Grayscale on purpose: they are NEUTRAL multipliers centred on
## 1.0, so they can add stone grain and can never add colour — the procedural
## stone plus the floor's `stone` tint own the hue, and STYLEGUIDE §2 caps world
## surfaces at ~0.25 saturation. Baked from `~/valenfeld/.../rock_grey` and
## `rocky_ground` at 128 px over a 4 m tile = 32 texels/metre (STYLEGUIDE §4.7),
## posterised to 16 levels (the PSX 4-bit CLUT).
const GRAIN_STONE: Texture2D = preload("res://assets/textures/stone_grain.png")
const GRAIN_STONE_N: Texture2D = preload("res://assets/textures/stone_grain_n.png")
const GRAIN_FLAG: Texture2D = preload("res://assets/textures/flag_grain.png")
const GRAIN_FLAG_N: Texture2D = preload("res://assets/textures/flag_grain_n.png")

## Uniform overrides applied to every zone material, keyed by shader file.
##
## **Why these live here and not in the .tres.** `assets/materials/mat_wall.tres`
## and friends are the AUTHORED BASE — the stone this kit is cut from, and the
## thing `FloorDb`'s `stone` multiply is documented as multiplying against. This
## table is the ZONE LAYER on top of it: the new grain/AO/contact machinery that
## did not exist when those materials were authored, plus the two knobs that were
## actively fighting the look. A zone material is a duplicate, so the base .tres
## is never mutated and still means what it says.
##
## The two corrections, and why they are corrections rather than taste:
##   * `block_brightness_variation` 0.44 -> 0.14. At 0.44 each block was painted a
##     visibly different shade from its neighbour by a hash that knows nothing
##     about where the block is or which way it faces, which is exactly the
##     "patchwork of coloured Lego" read. The variation the eye wants is a
##     LIGHTING variation, and `KitGeo.block_field` now bakes that from the
##     block's real protrusion.
##   * `specular` down hard. See `FIRE_SPECULAR`.
static var ZONE_UNIFORMS := {
	"wall_stone.gdshader": {
		&"block_brightness_variation": 0.14,
		&"specular": 0.06,
		&"grout_darkening": 0.30,
		&"zone_grain": GRAIN_STONE,
		&"zone_grain_normal": GRAIN_STONE_N,
		&"zone_grain_scale": 0.25,
		&"zone_grain_amount": 0.30,
		&"zone_grain_normal_depth": 0.55,
		&"zone_ao_strength": 1.0,
	},
	"stone_floor.gdshader": {
		&"tile_brightness_variation": 0.18,
		&"specular": 0.10,
		&"zone_grain": GRAIN_FLAG,
		&"zone_grain_normal": GRAIN_FLAG_N,
		&"zone_grain_scale": 0.25,
		&"zone_grain_amount": 0.22,
		&"zone_grain_normal_depth": 0.45,
		&"zone_ao_strength": 1.0,
	},
	"prop_stone.gdshader": {
		&"brightness_variation": 0.14,
		&"specular": 0.08,
		&"zone_grain": GRAIN_STONE,
		&"zone_grain_normal": GRAIN_STONE_N,
		&"zone_grain_scale": 0.6,
		&"zone_grain_amount": 0.26,
		&"zone_grain_normal_depth": 0.5,
		&"zone_ao_strength": 1.0,
	},
}

## Which uniforms on each shader carry stone colour and therefore take the
## floor's `stone` multiply. Everything else in the material is geometry.
static var TINTED_UNIFORMS := {
	"wall_stone.gdshader": [&"base_color_a", &"base_color_b", &"grime_color"],
	"stone_floor.gdshader": [&"base_color_a", &"base_color_b", &"grime_color"],
	"prop_stone.gdshader": [&"base_color_a", &"base_color_b", &"grime_color"],
}

## level|material-rid -> the dressed duplicate. Two walls on the same floor share
## one material and therefore one draw call; without the cache every kit piece in
## the room would hold its own copy of the same thing.
static var _mat_cache := {}
## level -> the dressed Environment.
static var _env_cache := {}
## Guards `request_air` so the first kit piece into the tree paints the air and
## the other forty do not. "<tree id>|<level>".
static var _air_token := ""


## The floor this node should dress for. `override` wins when non-zero, which is
## how the lookdev director photographs floor 3 without starting a run.
##
## `Run` is fetched off the tree and never NAMED: these are `@tool` scripts, and
## in the editor there is no autoload to name. Runtime falls back to floor 1,
## which is also what every lookdev scene and the proving ground want.
static func zone_of(node: Node, override: int = 0) -> int:
	if override > 0:
		return override
	if node == null or not node.is_inside_tree():
		return 1
	var run := node.get_tree().root.get_node_or_null(^"Run")
	if run == null:
		return 1
	return maxi(int(run.get(&"level")), 1)


static func tint_of(level: int) -> Dictionary:
	var t: Dictionary = FloorDb.tint(level)
	return t if not t.is_empty() else FloorDb.TINTS[&"drowned_bronze"]


## The zone-dressed version of an authored kit material. Returns `base` unchanged
## for anything that is not one of the three stone shaders — iron, wood and flame
## are the same in every zone, because a tint that recoloured the ironwork would
## be a filter over the room rather than a place with its own stone.
static func zone_material(base: Material, level: int) -> Material:
	var sm := base as ShaderMaterial
	if sm == null or sm.shader == null:
		return base
	var file := sm.shader.resource_path.get_file()
	if not ZONE_UNIFORMS.has(file):
		return base

	var key := "%d|%d" % [level, sm.get_instance_id()]
	if _mat_cache.has(key):
		return _mat_cache[key]

	var out := sm.duplicate() as ShaderMaterial
	var tint := tint_of(level)
	var stone: Color = tint.get("stone", Color.WHITE)
	var tinted: Array = TINTED_UNIFORMS[file]
	for name: StringName in tinted:
		var c: Color = _param(sm, name)
		out.set_shader_parameter(name, Color(c.r * stone.r, c.g * stone.g, c.b * stone.b, c.a))
	var zone: Dictionary = ZONE_UNIFORMS[file]
	for name: StringName in zone:
		out.set_shader_parameter(name, zone[name])
	_mat_cache[key] = out
	return out


## Read a shader parameter, falling back to the shader's own default when the
## .tres does not override it. `get_shader_parameter` returns null in that case,
## and multiplying null by a tint is how a wall comes out black.
static func _param(sm: ShaderMaterial, name: StringName) -> Color:
	var v = sm.get_shader_parameter(name)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), name)
	return v if v is Color else Color.WHITE


## Re-dress every kit piece, light and Environment under `root` for `level`.
##
## This is the lookdev/floor-change entry point. In a normal run nobody calls it:
## each piece asks `zone_of` at `_ready` and the air is painted by `request_air`.
static func apply_zone(root: Node, level: int) -> void:
	if root == null or not root.is_inside_tree():
		return
	for n in root.get_tree().get_nodes_in_group(&"kit_zone"):
		if n.has_method(&"zone_apply"):
			n.call(&"zone_apply", level)
	paint_air(root, level)


## First kit piece into the tree paints the room's air; the rest are no-ops.
##
## The Environment and the fill light live in `scenes/kit/dungeon_env.tscn`, which
## is a resource holder with no script — and the room scenes that instance it
## belong to another package (`docs/CONTRACT.md` §8 file ownership). So the kit
## paints the air, because the kit is the thing that knows which zone it is.
## Deferred, because at a piece's `_ready` the WorldEnvironment sibling may not be
## in the tree yet.
static func request_air(piece: Node) -> void:
	if piece == null or not piece.is_inside_tree():
		return
	var tree := piece.get_tree()
	var level := zone_of(piece)
	var token := "%d|%d" % [tree.get_instance_id(), level]
	if _air_token == token:
		return
	_air_token = token
	_paint_air_deferred.call_deferred(tree, level)


static func _paint_air_deferred(tree: SceneTree, level: int) -> void:
	if tree == null or tree.current_scene == null:
		return
	paint_air(tree.current_scene, level)


## Apply the floor's air, ambient and fill to whatever WorldEnvironment is under
## `root`.
static func paint_air(root: Node, level: int) -> void:
	var we := _find(root, "WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	var tint := tint_of(level)
	we.environment = zone_env(we.environment, level)

	var fill := _find(we, "DirectionalLight3D") as DirectionalLight3D
	if fill != null:
		fill.light_color = tint.get("fill", Color(0.66, 0.74, 0.95))


## The floor's Environment: the authored `env_dungeon.tres` with this zone's air
## in it. Duplicated rather than mutated — `env_dungeon.tres` is an ExtResource
## shared by three scenes, and writing the Cistern's fog into it would leave the
## Foundry looking like the Cistern the moment anyone loaded both.
static func zone_env(base: Environment, level: int) -> Environment:
	if base == null:
		return null
	if _env_cache.has(level):
		return _env_cache[level]
	var tint := tint_of(level)
	var env := base.duplicate() as Environment
	var air: Color = tint.get("air", Color(0.1255, 0.1569, 0.1882))
	# ONE value drives both, and that is the whole point of the `air` field.
	# STYLEGUIDE §4.6: fog colour must equal the camera clear colour exactly, or
	# the mismatch draws the visible horizon line that fog exists to hide. The
	# shipped .tres had them disagreeing (0.055,0.048,0.062 against
	# 0.16,0.142,0.175) — a near-black background behind violet fog, which is why
	# every doorway in the gate captures reads as a hole punched in the world.
	env.background_color = air
	env.fog_light_color = air
	env.fog_density = float(tint.get("fog_density", 0.0062))
	env.volumetric_fog_density = env.fog_density
	env.ambient_light_color = tint.get("ambient", Color(0.30, 0.34, 0.47))
	env.ambient_light_energy = float(tint.get("ambient_energy", 0.38))
	_env_cache[level] = env
	return env


## First descendant of `root` (inclusive) whose class matches. Used instead of a
## node path because the room scenes each nest `dungeon_env.tscn` differently.
static func _find(root: Node, cls: String) -> Node:
	if root == null:
		return null
	if root.is_class(cls):
		return root
	for c in root.get_children():
		var hit := _find(c, cls)
		if hit != null:
			return hit
	return null
