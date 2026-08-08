class_name K
extends RefCounted
## Shared constants. Read-only for every work package — see docs/CONTRACT.md §1.
## Never hardcode a number that lives here.
##
## Metric: 1 unit = 1 metre. Gravity is -Y, the hero moves on the XZ plane.
## Numbers marked TUNE are starting values the critics are expected to move.

# --- Space ------------------------------------------------------------------
const TILE := 2.0
const CORRIDOR_W := 2 * TILE  # 4.0
const CEIL_CORRIDOR := 5.0
const CEIL_ROOM := 7.0
const CEIL_ARENA := 12.0
const DOOR_W := 2.4
const DOOR_H := 3.2

# Screen-space directions on the XZ plane, with the camera looking down +Z.
const NORTH := Vector3(0, 0, -1)
const SOUTH := Vector3(0, 0, 1)
const WEST := Vector3(-1, 0, 0)
const EAST := Vector3(1, 0, 0)
const UP := Vector3(0, 1, 0)

const GRAVITY := 22.0  # TUNE — OOT falls faster than earth-real 9.8

# --- Collision layers (bit masks, see docs/CONTRACT.md §6) ------------------
const L_WORLD := 1 << 0
const L_PLAYER := 1 << 1
const L_ENEMY := 1 << 2
const L_PLAYER_HITBOX := 1 << 3
const L_ENEMY_HITBOX := 1 << 4
const L_INTERACT := 1 << 5
const L_PIT := 1 << 6
const L_HOOK := 1 << 7

# --- Hero body --------------------------------------------------------------
## The source mesh is 1.0 units tall; this scales it to adult-Link height.
const HERO_SCALE := 1.65
const HERO_H := 1.65
const HERO_RADIUS := 0.35
const HERO_CAPSULE_H := 1.5
## Where the camera aims and where a lock-on reticle sits on the hero.
const HERO_EYE_Y := 1.35

# --- Locomotion (TUNE — the movement critic owns these) ---------------------
const WALK_SPEED := 1.6
const RUN_SPEED := 4.8
## Analog magnitude above which the hero runs instead of walks.
const RUN_THRESHOLD := 0.62
const ACCEL := 28.0
const DECEL := 34.0
## Degrees/sec the hero's body turns to face his heading when unlocked.
const TURN_RATE := 900.0
const ROLL_SPEED := 7.0
const ROLL_TIME := 0.62
const BACKFLIP_SPEED := 6.0
const SIDEHOP_SPEED := 6.5

# --- Camera (TUNE — the camera critic owns these) ---------------------------
const CAM_FOV := 60.0
## Metres behind the hero, and metres above his feet, when free.
const CAM_DIST := 4.2
const CAM_HEIGHT := 1.9
## Seconds for the rig to catch up to the hero. Higher = laggier, floatier.
const CAM_LAG := 0.18
## How fast the camera drifts back behind the hero while he runs.
const CAM_AUTOSWING := 1.1
## Targeting camera: pulled back to frame hero AND target together.
const CAM_LOCK_DIST := 5.0
const CAM_LOCK_HEIGHT := 2.2
const CAM_MIN_PITCH := -34.0
const CAM_MAX_PITCH := 22.0

# --- Z-targeting (TUNE — the targeting critic owns these) -------------------
const LOCK_RANGE := 18.0
## Half-angle, in degrees, of the forward cone a target must fall inside.
const LOCK_CONE := 62.0
## Lock breaks past this — hysteresis, so it is wider than LOCK_RANGE.
const LOCK_BREAK_RANGE := 22.0
## Height of each cinematic letterbox bar as a fraction of screen height.
const LETTERBOX_FRAC := 0.11
const LETTERBOX_TIME := 0.22

# --- Health -----------------------------------------------------------------
## Health is counted in QUARTER hearts, like the source material.
const QUARTER := 1
const HEART := 4
const START_HEARTS := 3
const MAX_MAGIC := 48
const IFRAME_TIME := 1.2

# --- Feel -------------------------------------------------------------------
## Frames of freeze on a landed hit, at 60fps.
const HITSTOP_LIGHT := 4
const HITSTOP_HEAVY := 9
const KNOCKBACK_LIGHT := 4.0
const KNOCKBACK_HEAVY := 8.0

# --- Items (TUNE — the item critics own these) ------------------------------
const HOOK_SPEED := 34.0
const HOOK_RANGE := 22.0
const HOOK_PULL_SPEED := 14.0
const BOMB_FUSE := 2.5
const BOMB_RADIUS := 3.0
const ARROW_SPEED := 42.0
const ARROW_GRAVITY := 6.0


static func snap_to_tile(p: Vector3) -> Vector3:
	return Vector3(
		roundf(p.x / TILE) * TILE,
		p.y,
		roundf(p.z / TILE) * TILE
	)


## Signed yaw, in radians, that rotates `from` onto `to` about +Y.
static func yaw_between(from: Vector3, to: Vector3) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	return a.angle_to(b)


## Flatten to the XZ plane and normalise. Zero stays zero.
static func flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.ZERO
