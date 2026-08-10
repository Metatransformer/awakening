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

## DELIBERATE DEVIATION, like the stamina bar below it: OOT has no jump button
## and no sprint. It has a contextual ledge-hop and one running speed, and BOTW
## — which is the game this project is actually chasing — has both on buttons.
##
## The sprint is deliberately SLOWER than the roll (6.55). The roll is the
## fastest the hero ever travels and it costs a third of the bar for half a
## second of it; a sprint that outran it would make the dodge a worse way to
## cover ground than the button it shares.
const SPRINT_SPEED := 250.0 * U    # 6.07 m/s [tune] 1.39x the run cap
## Straight up, m/s. Against GRAVITY = 22 this apexes at v^2/2g = 0.96 m and is
## airborne for 2v/g = 0.59 s. Both numbers are the point: 0.96 m clears a
## waist-high ledge on a 1.65 m hero, and 0.59 s is short enough that a jump is
## a step rather than a state you wait out.
const JUMP_SPEED := 6.5            # [tune]

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
## What one charged spin costs out of that 48.
##
## **This is the price of the power attack, and it exists because the spin was
## free.** Stamina was supposed to be its cost, and stamina is the wrong shape
## for the job: it refills in a couple of seconds on its own (STAMINA_REGEN),
## so the only thing it prices is how fast you may spin, never how often. A
## player who backed off for two seconds between releases could clear a floor
## with one button and never learn any other one -- which the player found
## immediately and reported as "can cheese with power attack".
##
## Magic is the right shape because it does NOT come back underground. Twelve
## against a 48 bar is **four spins per trip into the dungeon**, whatever route
## you take and however long you stay, and the bar is on screen the whole time
## so the fourth one is a decision you can see coming. Deeper floors do not
## grant more; going home is the only refill (`Run.enter`/`extract`/`die`).
##
## The spin is the only blow that pays it. The overhead, the leap and the dash
## are single-target and already priced in commitment; the air slam costs a jump
## you can be punished for taking. What made the spin different was that it is
## the one attack that answers a ROOM, and an unlimited answer to a room is the
## room not being a question. [tune]
const MAGIC_SPIN := 12
## [oot] 20 ticks of invulnerability after taking damage. **THE HERO'S NUMBER.**
const IFRAME_TIME := 20.0 * TICK    # 1.0 s

## A MONSTER'S, and it is a quarter of the hero's on purpose.
##
## The two are not the same rule wearing different hats. The hero's second is
## recovery time -- it is what lets you back out of a corner after a hit lands,
## and it is long because being surrounded should not be a death sentence you
## cannot escape. A monster's exists only to stop ONE blow being counted twice
## when two damage paths arrive together (a sword and an arrow in the same
## frame), because per-swing repeats are already handled where they belong:
## `HeroCombat._hit_this_swing` and `DamageArea._already_hit`.
##
## `Enemy` inherited `IFRAME_TIME` by leaving `HealthComponent.iframe_time` at
## its default, and a whole second is longer than the light chain. Step one
## landed, **step two was swallowed**, step three landed as the finisher -- the
## player's report was "the second attack isn't hitting even though the
## animation is going", and it was exactly right. The chain's blows are ~0.59 s
## apart at the tightest (contact at 0.22 of a 0.60 s swing, then 0.22 of a
## 0.55 s step two), so anything at or above that eats a step.
##
## 0.20 s is under the 0.22 s the struck body spends reeling (`Enemy._on_damaged`
## sets `_timer = maxf(hit.stun, 0.22)`), which is the honest line: a monster is
## hittable again the moment it has finished reeling from the last one, and
## never during. Do not raise this to "space out" a chain -- the thing that
## spaces a chain is the swing clock, and it is visible on screen.
const ENEMY_IFRAME_TIME := 4.0 * TICK   # 0.20 s

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
## Units/sec while sprinting -> 4.5 s of running from a full bar. Deliberately
## priced so a full bar is a SPRINT OR THREE ROLLS and not both: the run and the
## dodge share one pocket, which is the only thing stopping "hold the button
## always" from being the correct way to play. 4.5 s is also about a room and a
## half of this dungeon, so crossing open ground is a choice and not a commute.
const STAMINA_SPRINT := 22.0        # [tune]

## SWINGING COSTS STAMINA, which is Elden Ring and is a second deliberate
## deviation on top of the first. OOT's B button is free forever and the correct
## play there is to mash it; the moment a game has a guard, a dodge and a heavy,
## a free light swing makes all three of them optional.
##
## THE RULE IS NOT THE ROLL'S RULE. A roll is refused unless the whole cost is in
## the bar (STAMINA_ROLL), because a dodge that half happens is a death. A swing
## is allowed on ANY stamina above zero and the cost clamps at the floor -- so
## the bar never stops you mid-chain, it stops you AFTER, which is the shape
## Elden Ring uses and the reason its stamina reads as commitment rather than as
## a cooldown. `Game.spend_stamina(cost, true)` is the partial half of that.
##
## The numbers are priced against STAMINA_ROLL (34) and the 46/sec regen, so a
## full bar is roughly: eight light swings, OR three heavies, OR two spins, OR
## three rolls -- and in practice a mix, because the regen delay (0.45 s) means
## a chain thrown back to back is paid for out of one pocket. [tune]
const STAMINA_SWING := 12.0         # [tune] the light chain, per step
const STAMINA_HEAVY := 26.0         # [tune] the overhead on the trigger
const STAMINA_SPIN := 34.0          # [tune] the charged release -- one roll
const STAMINA_DASH := 18.0          # [tune] the stab out of the guard
const STAMINA_LUNGE := 20.0         # [tune] the jump attack, under a lock
const STAMINA_SLAM := 22.0          # [tune] the air slam

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

## Seconds a struck monster is held in its reel. **This is the flinch**, and it
## has to be read against the clip and not against the number: the shared roster
## library's `hurt` is 0.60 s, and `Enemy._play` cross-fades into it. So a reel
## shorter than the fade is a monster that never visibly leaves the pose it was
## already in.
##
## It shipped at ZERO, and that is the whole of the "there's no flinch off the
## first attack" report. `HeroCombat._maybe_hit` built its `Hit` without a stun
## argument -- every other blow in the kit passes one, the slam most obviously --
## so `Enemy._on_damaged` fell through to its own `maxf(hit.stun, 0.22)` floor,
## and 0.22 s of a 0.60 s clip entered through a 0.15 s fade is about a third of
## a blend. The white flash and the 0.05 s recoil kick were doing all the work.
##
## 0.30 is deliberately WELL UNDER the light chain's own rhythm -- consecutive
## steps land ~0.59 s apart -- so the flinch never becomes a stun-lock the player
## can stand in. What the chain does to a monster is three reels, not one long
## paralysis. [tune]
const STUN_LIGHT := 0.30
## The finisher, the overhead, the leap, the spin. Longer because those are the
## blows the player pays commitment for, and the reward for a committed blow is
## that the thing stops coming at you for a moment. Still under a second: a
## monster you can safely ignore is not a monster. [tune]
const STUN_HEAVY := 0.45

# --- Economy ----------------------------------------------------------------
## [tune] Enough gold to afford exactly two bail-outs at the minimum fee, so a
## new player who panics twice is broke and has to finish a run to recover.
## That first forced commitment is where the game teaches what it is about.
const START_GOLD := 30
## Slots, not items -- a stack shares a slot. Twelve is enough to fill on a good
## run and not enough to clear a floor with, which is what makes a bag a
## decision rather than a container. [tune]
const START_BAG_SLOTS := 12
## Slots in the footlocker in the hero's quarters (`scripts/props/footlocker.gd`).
##
## **Finite on purpose, and the reason is `docs/GDD.md` §2**, which names
## "infinite storage" as one of the three features that delete this game. The
## locker cannot be reached from underground, so it does not touch the walk-back
## question directly -- but a bottomless one turns every run into "keep
## everything, decide later", and deciding later is not deciding. Twice the bag
## is a footlocker: enough to hold back two runs' worth of picks you are saving,
## not enough to be a warehouse. [tune]
const STASH_SLOTS := 24

# --- Items ------------------------------------------------------------------
## [oot] Hookshot flies perfectly STRAIGHT — gravity is never applied to it.
const HOOK_RANGE := 360.0 * U       # 8.74 m
const HOOK_LONGSHOT_RANGE := 750.0 * U  # 18.20 m
const HOOK_SPEED := 34.0            # [tune]
const HOOK_PULL_SPEED := 14.0       # [tune]
## Seconds a monster stays frozen after the head bites it. The hookshot does NO
## damage to a body — the second is the entire reward, and it is a second because
## that is about one sword swing plus the walk into range. [tune]
const HOOK_FREEZE := 1.0
## The share of that second spent thawing. The tint holds flat for the first
## half and then bleeds out over the tail, so the freeze reads as two facts —
## "it is stopped" and then "it is about to move" — rather than as a fade that
## has been ending since it began. [tune]
const HOOK_THAW := 0.45
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
## Twelve ladders, three rungs each, bought with gold AND components at the
## smith -- four scalar ones and the armour's four pieces times two paths.
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
##
## **Superseded by the four PLATE_* tables below** (docs/GDD.md §6.6) and kept
## only as the number the split has to land on: this array's ceiling of 3 is what
## every enemy in the game is tuned against, and `SOAK_MAX` is measured from it.
## Nothing reads it any more. Do not add a reader.
const PLATE_SOAK: Array[int] = [0, 1, 2, 3]

# --- The armour, split (docs/GDD.md §6.6) ------------------------------------
## Four pieces -- chest, legs, arms, boots -- each committed to ONE of two paths,
## each with `FORGE_MAX` rungs to buy on top of the rung 0 it comes in.
##
## ## Why these are floats when health is an integer
##
## Twelve buyable heavy rungs have to add up to about FOUR quarter-hearts, which
## is `PLATE_SOAK`'s old ceiling and the number the whole bestiary is tuned
## against (GDD §6.6 is explicit: sixteen rungs of `[0,1,2,3]` would be twelve
## quarters, `Hero.hurt`'s one-quarter floor would eat the entire difficulty
## curve, and §7's *difficulty comes from depth* would be dead).
##
## Four quarters across twelve rungs is a third of a quarter per rung. There is
## no integer table that does that, so the pieces carry fractions and
## `Game.armour_soak()` floors the SUM. A rung is still a number the player can
## feel -- the shop line prints "1.4 -> 1.7 quarters soaked" and the equipment
## screen prints the floored total -- but the thing that moves is the total,
## because the total is what a blow is measured against.
##
## Do not "fix" these into integers. That was tried in the design and it is what
## the paragraph above is about.
const PLATE_PIECE_COUNT := 4
## Soak, in quarter-hearts, contributed by ONE piece at rung 0..FORGE_MAX.
## Four pieces at full heavy: 4.0. Four at full light: 2.0. [tune]
const PLATE_HEAVY_SOAK: Array[float] = [0.0, 0.4, 0.7, 1.0]
const PLATE_LIGHT_SOAK: Array[float] = [0.0, 0.2, 0.35, 0.5]

## Speed multiplier contributed by ONE heavy piece, MULTIPLIED across the four.
##
## `0.92 ** (k / 12)`, so four pieces at rung 3 come to exactly 0.92 -- the −8%
## GDD §6.6 authored, reached by multiplication rather than by a special case
## watching for the fourth piece. Light costs nothing and has no table: the
## absence IS the light path's whole selling point.
##
## THIS IS NOT A LICENCE TO EDIT `RUN_SPEED`. That constant is [oot], measured,
## and pillar 1 says the feel is not negotiable. The penalty is a multiplier
## applied on top of `speed_for_stick`, in `Hero._target_speed`, and nowhere else.
const PLATE_HEAVY_SPEED: Array[float] = [1.0, 0.993076, 0.986199, 0.979370]

# --- The jewelcrafter (docs/GDD.md §6.6) -------------------------------------
## Four slots -- amulet, two rings, bracelet -- eight paths between them. One
## rung deeper than a forge ladder, because a jewel has no rung 0 you already own.
const JEWEL_MAX := 4

## **Ceilings belong to the NUMBER, not to the faucet.** Armour and Ward both
## pour into soak; the forge's `edge` and an Edge ring both pour into damage; the
## smith's heart line and Vigor both pour into hearts. Each pair is clamped here,
## once, so adding a third faucet later cannot quietly raise a ceiling the
## bestiary was tuned against (GDD §6.6).
##
## Draughts are deliberately OUTSIDE these caps and stay additive on top, exactly
## as they were: a draught is 45 seconds long and gone, and capping a consumable
## against a permanent ladder would make Ironhide worthless to the player who
## most needs it.
const SOAK_MAX := 4.0          ## quarter-hearts, all permanent sources
const EDGE_MAX := 5            ## quarter-hearts a swing, forge + rings
const HEART_MAX := 8           ## heart containers: 3 start + 3 smith + 2 Vigor
const STAMINA_MAX := 160.0     ## MAX_STAMINA 100 + four Focus rungs

## **The slider that goes the other way** (GDD §7.1). A fraction of every blow
## the hero takes, forgiven, when the player has switched mercy on in options.
##
## It starts small and climbs with `Game.deaths`, so it only ever reaches the
## player who is actually stuck -- that is the whole design, and it is why there
## is no difficulty menu on the title card. The cap is well short of invulnerable
## and deliberately so: at 30% a wraith still takes four hearts off a careless
## hero, and a mercy that made the Cut survivable by standing in it would have
## deleted the extraction decision instead of softening it.
##
## 5% at nought deaths, +2.5 points a death, at the ceiling after ten. Ten deaths
## is roughly where a stuck player is genuinely stuck rather than learning, and
## the whole ramp fits inside a first evening for the player who needs it. [tune]
const MERCY_BASE := 0.05
const MERCY_PER_DEATH := 0.025
const MERCY_MAX := 0.30

## Per rung. Ward is HALF a heavy plate rung, so a full bracelet (2.0) plus full
## light armour (2.0) reaches heavy's ceiling of 4 -- the light build buys its
## soak back with a slot instead of with speed, which is the decision GDD §6.6
## wants the jewelcrafter to pose. [tune]
const JEWEL_WARD_SOAK := 0.5
## Two rings at four rungs is +2 quarters, on top of the forge's +3. [tune]
const JEWEL_EDGE_DAMAGE := 0.25
## Multiplier per rung, MULTIPLIED like the plate penalty. Two Swift rings at
## rung 4 come to 1.0834, which is more than enough to undo a full heavy suit --
## and `Game.speed_mult()` clamps the product at 1.0 so it can never make the
## hero faster than [oot]'s measured run. Buying speed BACK is the promise; going
## past the source material is not. [tune]
const JEWEL_SWIFT_SPEED := 1.0101
## Heart containers per rung: two rungs buy one. Four rungs, two hearts. [tune]
const JEWEL_VIGOR_HEARTS := 0.5
## Stamina points per rung. Four rungs takes 100 -> 160. [tune]
const JEWEL_FOCUS_STAMINA := 15.0
## Fraction of the base regen added per rung. Four rungs is +40%. [tune]
const JEWEL_WIND_REGEN := 0.1
## Half-angle of the shield's guard arc, degrees. The shield's upgrade is not
## "less damage" -- damage it already stops completely -- it is WHICH blows it
## stops. Widening the arc buys back the flank, and it stays strictly frontal at
## every level, because being punished for turning away is the point. [tune]
const GUARD_ARC: Array[float] = [70.0, 85.0, 100.0, 115.0]
## Seconds of DRAW — the pull, up to the frame the arrow leaves. Not the whole
## shot: `HeroRanged.BOW_LOOSE` is the follow-through on the end of it, and the
## hero is committed for both. This is the half the smith sells, because pulling
## faster is the thing a better string does.
##
## NOT arrow damage: arrow.gd is explicit that the bow's advantage is reach and a
## bow that out-damages the blade is the only weapon anyone brings. What the bow
## costs is commitment, so what you buy back is commitment. [tune]
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


# --- Bottles and draughts (docs/METAGAME.md §6.6) ---------------------------
## How many bottles the alchemist will ever blow you, and how many you start
## with. The cap is the whole design of the thing: a bottle is a SLOT, and four
## of them is enough to plan a run around and few enough that filling the fourth
## with the wrong draught is a decision you regret. [tune]
const BOTTLE_MAX := 4
## How many bottles you own on a cold boot, and it is a DESIGN number, not
## scaffolding (docs/METAGAME.md §6.6): the alchemist will not brew into thin
## air, so a hero with no bottle cannot use his counter until he has bought
## one, and his counter is meant to be somewhere you can go on your first trip.
##
## This used to be tagged [test] and promised to expire "the same day the
## starter kit is". The starter kit is now gone — Game.STARTER_KIT is an empty
## array and the bow, the hookshot and the arrows went with it — and this
## deliberately STAYED. It is the one thing `_grant_starter_kit` still hands
## over. Do not delete it looking for the other half of a pair.
const BOTTLE_START := 1

## Quarter-hearts a Heart Draught puts back. Two whole hearts against a starting
## three: a draught is a second chance at the fight you are in, not a top-up you
## sip between rooms. It is also the only healing in the game that is not the
## walk home (docs/METAGAME.md §5), which is why it costs a slot and a brew.
const DRAUGHT_HEAL := 8
## Seconds the two lasting draughts run for. Long enough to cover a room and its
## fight, short enough that you cannot drink one in the garrison and still have
## it at the stair. [tune]
const DRAUGHT_TIME := 45.0
## Quarter-hearts Emberblood adds to a swing, and Ironhide soaks off a blow.
## Both are read through the SAME accessors the forge feeds (`Game.sword_bonus`,
## `Game.armour_soak`), so a draught is worth exactly two rungs for its 45 s and
## nothing downstream needed a line of code to know potions exist.
const DRAUGHT_EDGE := 2
const DRAUGHT_PLATE := 2


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
##
## **This throws the length away.** `K.flat(a - b).length()` is 1.0 for every
## pair of points in the world, and it does not error -- it quietly answers a
## distance question with a direction. That has cost this project three separate
## bugs now (the hero's lunge stood still, the target sweep saw every enemy at
## 1 m, and the monster pack shoved across whole rooms). If you want a gap, a
## radius or a leash, you want `plane` below.
static func flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.ZERO


## Flatten to the XZ plane, length preserved. The one to reach for when the
## answer is a distance.
static func plane(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
