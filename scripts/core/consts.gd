class_name K
extends RefCounted
## Shared constants. Read-only for every work package — see docs/CONTRACT.md §1.
## Never hardcode a number that lives here.
##
## Metric: 1 unit = 1 metre. Gravity is -Y, the hero moves on the XZ plane.
##
## Numbers tagged [oot] are converted from the Ocarina of Time decompilation via
## refs/REFERENCE.md — that file cites file:line for each one. Numbers tagged
## [tune] are ours to move. DO NOT "clean up" an [oot] number because it looks
## odd; it looks odd because it is measured.
##
## OOT runs its logic at 20 Hz, so decomp constants are per 50 ms tick. Anything
## quoted here has already been converted to per-second. See TICK below.

# --- Conversion -------------------------------------------------------------
## OOT's logic and display tick. [oot] R_UPDATE_RATE=3 -> 20 Hz.
const TICK := 0.05
## Metres per OOT unit, anchored on OUR hero rather than a guessed ratio:
## adult Link is 68.0 units tall (Player_GetHeight), our hero is 1.65 m.
## Use this to convert any further number out of refs/REFERENCE.md.
const U := 1.65 / 68.0  # 0.024265 m/unit -> ~41.2 units/metre


static func from_units(units: float) -> float:
	## Convert an OOT unit distance out of refs/REFERENCE.md into metres.
	return units * U


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

const GRAVITY := 22.0  # [tune] OOT falls faster than earth-real 9.8

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
const HERO_H := 1.65               # [oot] 68 u
const HERO_RADIUS := 0.35          # [oot] body cylinder r=12 u -> 0.29; padded
const HERO_CAPSULE_H := 1.5
## Where the camera aims and where a lock-on reticle sits on the hero.
## [oot] look-at = feet + height - 13.6 u = 54.4 u up.
const HERO_EYE_Y := 1.32
const WALL_CHECK_RADIUS := 0.44    # [oot] 18 u
const CEILING_CHECK_H := 1.36      # [oot] 56 u

# --- Locomotion -------------------------------------------------------------
## [oot] THERE IS NO WALK/RUN THRESHOLD. Speed is a continuous curve of stick
## magnitude. The stick clamps to 0-60 raw; below 20 is deadzone. Normalised:
const STICK_DEADZONE := 20.0 / 60.0    # 0.333 [oot]
## Discrete actions (roll, backflip, sidehop) need a near-full deflection.
const STICK_ACTION_GATE := 55.0 / 60.0  # 0.917 [oot]

const RUN_SPEED := 180.0 * U       # 4.37 m/s [oot] adult run cap
const ROLL_SPEED := 270.0 * U      # 6.55 m/s [oot] — FASTER than running
const SIDEHOP_SPEED := 255.0 * U   # 6.19 m/s [oot]
const BACKFLIP_SPEED := 180.0 * U  # 4.37 m/s [oot]
## Kept for UI/labels only — the speed curve is continuous, do not branch on it.
const WALK_SPEED := 60.0 * U       # 1.46 m/s

const ACCEL := 28.0                # [tune]
const DECEL := 34.0                # [tune]
## Degrees/sec the hero's body turns to face his heading when unlocked.
const TURN_RATE := 900.0           # [tune]
const ROLL_TIME := 0.62            # [tune]
## [oot] roll grants 10 ticks of invulnerability starting at anim frame 8.
const ROLL_IFRAMES := 10.0 * TICK  # 0.5 s


## OOT's continuous speed curve: normalised stick magnitude -> m/s.
## Below the deadzone he stands still; above it, speed ramps linearly to the cap.
static func speed_for_stick(magnitude: float) -> float:
	if magnitude < STICK_DEADZONE:
		return 0.0
	var t := (magnitude - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	return RUN_SPEED * clampf(t, 0.0, 1.0)


# --- Camera -----------------------------------------------------------------
## [oot] FOV is VERTICAL degrees. Three modes, and a low-health squeeze.
const CAM_FOV := 60.0              # free
const CAM_FOV_LOCK := 50.0         # locked onto a hostile
const CAM_FOV_PARALLEL := 45.0     # Z held with no target, and first-person
const CAM_FOV_LOW_HEALTH := 0.8    # multiplier at <= 1 heart

## [oot] DUNGEON0 camera set — dungeons are TIGHTER and FLATTER than outdoors.
## Distance is a range the rig lives within, not a fixed boom length.
const CAM_DIST_MIN := 102.0 * U    # 2.48 m
const CAM_DIST_MAX := 170.0 * U    # 4.13 m
const CAM_PITCH := 5.0             # degrees above horizontal, looking down
## [oot] NORMAL1 outdoor set, for reference if we ever leave the dungeon.
const CAM_DIST_MIN_OUTDOOR := 136.0 * U  # 3.30 m
const CAM_DIST_MAX_OUTDOOR := 272.0 * U  # 6.60 m
const CAM_PITCH_OUTDOOR := 10.0

## Seconds for the rig to catch up to the hero. Higher = laggier, floatier.
const CAM_LAG := 0.18              # [tune]
## How fast the camera drifts back behind the hero while he runs.
const CAM_AUTOSWING := 1.1         # [tune]
## [oot] battle-camera pitch clamp is +/-59.99 degrees.
const CAM_MIN_PITCH := -55.0
const CAM_MAX_PITCH := 55.0

## Over-the-shoulder, for the bow and the hookshot. Not [oot] — Ocarina aims the
## bow in first person, and this game's hero is a body you watch rather than a
## pair of hands, so the reference here is the third-person shooter framing every
## player already reads as "you are aiming": boom in tight, eye off one shoulder,
## FOV narrowed so the crosshair means something at range.
const CAM_DIST_AIM := 1.55         # [tune] metres, well inside CAM_DIST_MIN
const CAM_FOV_AIM := 42.0          # [tune] tighter than Parallel; this is a sight
## Metres the eye slides toward the hero's right and rises, so his body sits in
## the left of frame instead of on top of the thing being shot at. Right, because
## the hookshot is in his right hand and the bow is drawn across to the right.
const CAM_AIM_SHOULDER := 0.62     # [tune]
const CAM_AIM_RISE := 0.16         # [tune]
## Seconds to slide in and out of the shoulder. Fast — this is a stance change,
## and a lazy one reads as the camera being broken rather than as weight.
const CAM_AIM_BLEND := 0.16        # [tune]

# --- Z-targeting ------------------------------------------------------------
## [oot] ATTENTION_RANGE_3, the default: acquire at 350 u, break at 429 u.
## The ~22% hysteresis band is deliberate — it stops the lock chattering.
const LOCK_RANGE := 350.0 * U        # 8.49 m
const LOCK_BREAK_RANGE := 428.7 * U  # 10.40 m
## [oot] Half-angle of the forward search cone: a 120-degree arc.
const LOCK_CONE := 60.0
## [oot] Once locked, switching targets widens the cone to +/-90.
const LOCK_SWITCH_CONE := 90.0
## [oot] Height of each cinematic letterbox bar, and its slide-in time
## (27 scanlines of 240 = 11.25%, animated over 3 ticks).
const LETTERBOX_FRAC := 0.1125
const LETTERBOX_TIME := 3.0 * TICK  # 0.15 s

# --- Health -----------------------------------------------------------------
## [oot] A heart is 16 internal units; the smallest displayed step is a quarter.
const QUARTER := 1
const HEART := 4
const START_HEARTS := 3
const MAX_MAGIC := 48
## [oot] 20 ticks of invulnerability after taking damage.
const IFRAME_TIME := 20.0 * TICK    # 1.0 s

# --- Stamina ----------------------------------------------------------------
## DELIBERATE DEVIATION: OOT has NO stamina. Link rolls forever, and that is
## correct for OOT, where a roll is locomotion. Here a roll is the i-frame
## button (ROLL_IFRAMES), and an i-frame button with no cost is the only button
## you ever press. Stamina is what makes the dodge a decision. Do not let a
## critic "correct" this into an OOT fact — see HITSTOP_LIGHT above for the
## same argument.
const MAX_STAMINA := 100.0
const STAMINA_ROLL := 34.0          # [tune] three rolls from full, not four
## Seconds after spending before regen starts. The pause IS the tell that you
## are winded; regen with no delay reads as no system at all.
const STAMINA_DELAY := 0.45         # [tune]
const STAMINA_REGEN := 46.0         # [tune] units/sec -> full in ~2.2 s
## [oot] 8 ticks of invulnerability when a shield block is released.
const SHIELD_IFRAMES := 8.0 * TICK  # 0.4 s

# --- Heat (momentum) --------------------------------------------------------
## Kills chain into heat, and heat is worth MONEY, never power. A dungeon drop
## that made the hero stronger would delete the smith (docs/GDD.md §4, pillar 4),
## so every number below buys value or tempo and none of them buys damage.
##
## Indexed by tier 0..3 -- Cold, Warm, Hot, Blazing. TYPED arrays, not bare
## ones: indexing an untyped const returns Variant, which is the inference trap
## in CLAUDE.md §3. Not Packed* either, tempting as it looks -- the parser
## cannot constant-fold `PackedFloat32Array([...])`, so a const built that way
## reads as <null> at parse time in any OTHER script that indexes it with a
## literal, and the failure is a parse error in the innocent file.
const HEAT_TIERS := 4
## Chain length at which each tier starts. [tune]
const HEAT_TIER_KILLS: Array[int] = [0, 2, 5, 9]
## Seconds a tier survives without a kill. It SHRINKS as you climb: the better
## you are doing, the less slack you have, and that is what turns a bonus into a
## rhythm. Index 0 is unused -- a cold chain still runs on tier 1's window, so a
## single kill does not sit lit forever. [tune]
const HEAT_TIER_WINDOW: Array[float] = [4.0, 4.0, 3.2, 2.5]
## What the vendor pays for loot swept at this tier, as a multiplier. [tune]
const HEAT_TIER_MULT: Array[float] = [1.0, 1.25, 1.6, 2.2]
## Metres a mote is dragged toward the hero from, per tier. Removing the
## stop-and-vacuum tax is the single change that makes a chain survivable --
## without it the loop is kill, halt, hoover, and the window is already gone.
const HEAT_MAGNET: Array[float] = [0.0, 2.5, 3.5, 4.5]
const HEAT_MAGNET_SPEED := 9.0     # [tune] m/s, faster than the hero can run
## Stamina a kill hands straight back. STAMINA_ROLL is 34, so a kill buys the
## roll that carries you to the next body. This is the whole reason a chain is
## physically possible at OOT's swing lengths -- see docs/METAGAME.md §10.
const STAMINA_KILL := 40.0         # [tune]
## Seconds a mote on the floor keeps the heat it was killed at. After this it is
## worth base value: the loot cools whether or not you do. [tune]
const HEAT_COOL_TIME := 6.0

# --- Feel -------------------------------------------------------------------
## DELIBERATE DEVIATION: OOT has NO hit-stop. It sells impact with camera quake
## and rumble instead. We keep a little hit-stop because we have no rumble and
## a 60 Hz display — but it is our choice, not fidelity. Do not let a critic
## "correct" this into existence as an OOT fact.
const HITSTOP_LIGHT := 4
const HITSTOP_HEAVY := 9
const KNOCKBACK_LIGHT := 4.0
const KNOCKBACK_HEAVY := 8.0

# --- Economy ----------------------------------------------------------------
## [tune] Enough gold to afford exactly two bail-outs at the minimum fee, so a
## new player who panics twice is broke and has to finish a run to recover.
## That first forced commitment is where the game teaches what it is about.
const START_GOLD := 30
## Slots, not items -- a stack shares a slot. Twelve is enough to fill on a good
## run and not enough to clear a floor with, which is what makes a bag a
## decision rather than a container. [tune]
const START_BAG_SLOTS := 12

# --- Items ------------------------------------------------------------------
## [oot] Hookshot flies perfectly STRAIGHT — gravity is never applied to it.
const HOOK_RANGE := 360.0 * U       # 8.74 m
const HOOK_LONGSHOT_RANGE := 750.0 * U  # 18.20 m
const HOOK_SPEED := 34.0            # [tune]
const HOOK_PULL_SPEED := 14.0       # [tune]
## [oot] 70-tick fuse; blast grows to ~80 u and deals half a heart.
## Link is NOT exempt from his own bomb (AT_TYPE_ALL, no owner check).
const BOMB_FUSE := 3.5
const BOMB_RADIUS := 80.0 * U       # 1.94 m
const BOMB_DAMAGE := 2 * QUARTER
const BOMB_HURTS_OWNER := true
## [oot] arrows cross the whole 8.5 m lock range in ~1 tick — near hitscan.
const ARROW_SPEED := 42.0
const ARROW_GRAVITY := 6.0          # [tune] OOT arrows barely drop at this range


# --- The forge (docs/METAGAME.md §6.5) --------------------------------------
## Five ladders, three rungs each, bought with gold AND components at the smith.
## Every array is indexed by LEVEL 0..FORGE_MAX, so index 0 is the un-upgraded
## piece and the arrays are read as absolutes rather than as deltas -- a table
## that lists the level-0 value cannot drift from the thing it is upgrading.
##
## TYPED arrays for the reason HEAT_TIER_MULT is typed: indexing an untyped
## const returns Variant and the inference trap in CLAUDE.md §3 bites in the
## innocent file, not this one.
##
## The rule every rung obeys: **one number, and the player can feel it inside
## one run.** No percentages, no stat sticks, nothing you have to take on faith.
const FORGE_MAX := 3
## Quarter-hearts added to every sword swing, light and heavy alike. [tune]
const EDGE_DAMAGE: Array[int] = [0, 1, 2, 3]
## Quarter-hearts taken off every blow that lands, floored at one by `Hero.hurt`.
## Armour makes you last longer; it never makes you safe. [tune]
const PLATE_SOAK: Array[int] = [0, 1, 2, 3]
## Half-angle of the shield's guard arc, degrees. The shield's upgrade is not
## "less damage" -- damage it already stops completely -- it is WHICH blows it
## stops. Widening the arc buys back the flank, and it stays strictly frontal at
## every level, because being punished for turning away is the point. [tune]
const GUARD_ARC: Array[float] = [70.0, 85.0, 100.0, 115.0]
## Seconds a shot owns the hero. NOT arrow damage: arrow.gd is explicit that the
## bow's advantage is reach and a bow that out-damages the blade is the only
## weapon anyone brings. What the bow costs is commitment, so what you buy back
## is commitment. [tune]
const BOW_DRAW: Array[float] = [0.44, 0.38, 0.32, 0.26]
## Hookshot reach in metres. The rungs walk [oot]'s own two lengths: rung 0 is
## the Hookshot and rung 3 is exactly the Longshot, with two even steps between.
## Length is the only thing a hookshot has, which is why it is the one track the
## owner named by its number.
const CHAIN_REACH: Array[float] = [
	HOOK_RANGE, 11.89, 15.05, HOOK_LONGSHOT_RANGE,
]


# --- Metagame (docs/METAGAME.md) --------------------------------------------
## Slots in the dungeon bag. This number IS the game's core tension: it is what
## forces "sell it or forge with it" to be answered while you are still in
## danger. Raising it does not make the game more generous, it makes it flatter.
const BAG_SLOTS := 10
## The first N bag slots are the belt pouch, which survives death. Small enough
## that putting something in it is a real choice.
const BELT_SLOTS := 3

## Paid extraction: fee = EXTRACT_BASE + EXTRACT_PER_ROOM * rooms_cleared.
## The price of leaving rises exactly as the haul becomes worth protecting.
const EXTRACT_BASE := 30
const EXTRACT_PER_ROOM := 20
## Seconds the teleport channels. Standing still, and a hit cancels it — you
## cannot buy your way out of a fight you are already losing.
const EXTRACT_CHANNEL := 3.0

## Rooms at which the depth band steps up. Band 1 is rooms 0..2, band 2 is
## 3..6, band 3 is 7+. Fixed at authoring time: enemies never scale to the
## player, so cleared ground genuinely becomes easy.
const BAND_2_ROOM := 3
const BAND_3_ROOM := 7


## Depth band (1..3) for a number of rooms cleared this run.
static func band_for_room(rooms_cleared: int) -> int:
	if rooms_cleared >= BAND_3_ROOM:
		return 3
	if rooms_cleared >= BAND_2_ROOM:
		return 2
	return 1


## Cost in gold to teleport out having cleared `rooms_cleared` rooms.
static func extract_fee(rooms_cleared: int) -> int:
	return EXTRACT_BASE + EXTRACT_PER_ROOM * maxi(rooms_cleared, 0)


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
