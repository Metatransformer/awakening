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
const FIRE_COLOR := Color(1.0, 0.76, 0.5)
## Energy of one torch's omni light. High, because the falloff is still curved.
const FIRE_ENERGY := 9.5
## Metres. A sconce now reaches the next sconce.
const FIRE_RANGE := 15.0
## >1 curves the falloff so the pool of light has a shape instead of a soft
## infinite gradient. This single number is most of the torchlit read.
##
## It used to be 1.6, which put a hard edge on every pool and dropped the space
## BETWEEN two sconces to black — the room was a string of spotlights in a void,
## which reads as a horror crawler and not as a lit place (STYLEGUIDE §1). At
## 1.3 the pools still fall off visibly, but they overlap, so the floor between
## them is dim warm stone you can read a roll on rather than a hole.
const FIRE_ATTENUATION := 1.3
const FIRE_FLICKER := 0.16
const FIRE_FLICKER_SPEED := 6.5

## Height above the floor a wall sconce's flame sits at.
const SCONCE_Y := 2.35
