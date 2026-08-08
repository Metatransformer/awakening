class_name KitStyle
extends RefCounted
## The dungeon look, as numbers. One place to turn a knob.
##
## `K` (scripts/core/consts.gd) is orchestrator-owned and holds what OTHER packages
## can see — sizes, layers, speeds. Nothing here crosses a package boundary: these
## are P6's own art defaults, referenced by the kit scripts so a critic changes a
## value once instead of hunting it through eleven .tscn overrides.
## See the `# NEEDS` note in the P6 report about promoting the torch colour to `K`
## if the item/feel packages end up wanting to match it.

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

# --- Torch fire ---------------------------------------------------------------
## Warm, slightly orange-red. OOT torchlight is never white and never yellow-green.
const FIRE_COLOR := Color(1.0, 0.74, 0.47)
## Energy of one torch's omni light. High, because the falloff is deliberately sharp.
const FIRE_ENERGY := 9.0
## Metres. Beyond this the room is black — that is the point.
const FIRE_RANGE := 12.0
## >1 curves the falloff so the pool of light has a defined edge instead of a
## soft infinite gradient. This single number is most of the "OOT dungeon" read.
const FIRE_ATTENUATION := 1.6
const FIRE_FLICKER := 0.16
const FIRE_FLICKER_SPEED := 6.5

## Height above the floor a wall sconce's flame sits at.
const SCONCE_Y := 2.35
