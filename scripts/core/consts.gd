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
## Volumes a projectile is CHANGED by rather than stopped by -- combinator 8,
## convert (`docs/PUZZLES.md` §3.1). A lantern's flame is the only one so far.
##
## It has to be its own bit and cannot borrow `L_INTERACT`. `Arrow`'s flight
## query masks `L_WORLD | L_ENEMY | L_INTERACT` with `collide_with_areas` on, so
## a flame volume wearing the interact bit is a flame that STOPS the arrow -- the
## exact opposite of "you shoot *through* it". Nothing masks this bit but the
## arrow's second, separate probe, which is what makes the volume invisible to
## the sword's sweep, the hero's interact scan and the camera's collision alike.
const L_CONVERT := 1 << 8
## A world-looking boundary that only the hero masks. It lets the garrison gate
## bar the player without becoming raid navigation collision.
const L_PLAYER_BOUNDARY := 1 << 9

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
const CAM_FOV_LOW_HEALTH := 0.8    # multiplier at <= 4 HP

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
## Health is stored and presented as integer points; the smallest step is 1 HP.
const HEALTH_POINT := 1
const START_HEALTH_POINTS := 12
## One permanent health purchase adds the former container-sized amount.
const HEALTH_UPGRADE_POINTS := 4
## One one-rung Glint Statue awakening per permanent bar.
const GLINT_HEALTH_POINTS := 2
const GLINT_STAMINA_POINTS := 10.0
const GLINT_MAGIC_POINTS := 12
## Baseline magic remains 48; this is the shared permanent prototype ceiling.
const MAGIC_MAX := 60
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
##
## **A drink refills it now, and the paragraph above is what shaped the drink**
## (owner directive, 2026-08-11; `docs/SCOPE.md` §2 carries the amendment). Small
## Beer is `MEAL_MAGIC` = 12 = exactly this constant, so it buys back ONE spin and
## never a fraction of one, and it costs twelve seconds of sitting still that no
## fight will give you. What the argument above actually defends is "the fourth
## spin is a decision you can see coming" -- a drink that had to be bought in the
## garrison, carried down, and paid for in a room you have already cleared does
## not soften that; it moves the fourth spin's price from the walk home to the bag
## slot and the clock. What would break it is a refill that is FREE or FAST, and
## `MEAL_TIME` is the whole reason this one is neither.
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
## Blocking spends `hit.amount *` this value, so heavier blows cost more.
const STAMINA_BLOCK_PER_QUARTER := 4.0  # [tune]

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

# --- The weight of a blow ----------------------------------------------------
## **Everything an impact does reads off ONE number**, and `Hit.knockback` is
## already it: how hard this blow shoved. Every swing in the kit sets it, so
##
##     weight = (knockback - KNOCKBACK_LIGHT) / (KNOCKBACK_HEAVY - KNOCKBACK_LIGHT)
##
## clamped to 0..1, is 0 for a jab and 1 for anything the player paid commitment
## for -- the chain finisher, the overhead, the spin, the lunge, the slam. The
## burst at the impact site, the screen shake, the hit-stop and the chance of a
## launch are all scaled by that one number.
##
## One number rather than a per-move table on purpose. A table is a thing that
## goes stale the first time a move is retuned, and the failure it ships is a
## spin that shoves a body across the room under a jab's puff of dust. This
## cannot fall out of step with itself, because there is nothing to keep in step.
##
## Enemy contact hitboxes carry KNOCKBACK_LIGHT, so a monster's blow is always
## weight 0: monsters cannot launch each other, and the hero taking a hit does
## not get the crit treatment meant for landing one.

## Trauma a jab asks for, against a committed blow. `Feel`'s own docstring sets
## the scale -- "0.2 a tap, 0.5 a solid hit" -- and `Enemy` was asking **0.52 for
## every landed blow including the cheapest jab in the game**. Trauma
## ACCUMULATES in Feel and the light chain lands three inside 1.2 s, so the
## cheapest attack available pinned the camera at maximum. A tap is a twitch.
## **In pixels, because trauma is squared and nobody can judge it otherwise.**
## `Feel` squares trauma before it moves anything and `MAX_OFFSET` is 1.4, so the
## image moves `t^2 * 1.4 * 37.5` px (`monster_feel.gd`'s measured PX_PER_OFFSET):
##
##   jab       0.26 ->  3.5 px      committed  0.20 ->  2.1 px
##   crit      0.72 -> 27.2 px      the old flat 0.52 -> 14.2 px, for everything
##
## The first cut of this put the tap at 0.16 and `monster_feel` caught it: 0.4 px
## is not a reeled-in shake, it is no shake, and the director that measures the
## image in pixels rather than in trauma is the only reason that was visible at
## all. A jab should be *cheap*, not absent.
##
## The accumulation is the other half. Three jabs land inside 1.2 s and Feel sums
## them: at 0.52 each that is 1.56, clamped to a saturated 1.0, so the cheapest
## attack in the game held the camera at maximum and left the spin nothing to
## escalate to. At 0.26 the same chain peaks under 0.8 and decays between steps.
const SHAKE_TAP := 0.26    # [tune]
const SHAKE_HIT := 0.20    # [tune]
## The crit. Above SHAKE_HIT because a launch is the one blow in the game where
## a body leaves the ground, and the screen should agree with the body. [tune]
const SHAKE_CRIT := 0.72

# --- Taking a hit ------------------------------------------------------------
## Card #130. The hero's outgoing blows have had four juice passes; the incoming
## direction had none, and a boss's heavy read exactly like a goblin's jab. These
## are the numbers that separate the three reactions. `Hit.force` is the input to
## all of them -- one number, decided once, so a beat retuned in `BossDb` moves
## the flinch, the stagger, the camera and the grunt together.

## **What decides which of the three reactions a blow earns**, and the only
## numbers anyone has to agree with to price a new monster. `Hit.tier_odds` is
## where they are read and `tools/directors/hurt_table.gd` prints the whole
## roster through them.
##
## The design rows, and they are the owner's words (card #130):
##
##   goblin  light swing   light knockback,  NEVER floors you
##   goblin  heavy swing   medium knockback, NEVER floors you
##   troll   light swing   medium knockback
##   troll / boss  heavy   medium knockback up to knocked flat
##
## So knockdown is the product of two gates and neither alone opens it:
##
##   * **heft** -- how far the attacker outweighs the hero. Zero at `MASS_FLOOR`,
##     which is the hero's OWN mass, so *a body no heavier than you cannot put
##     you on the ground* -- goblin, kobold and skeleton are exactly 0 and it is
##     a statement rather than a small number. Full at `MASS_FULL`, twice the
##     hero, which is where the floor-1 boss sits.
##   * **commitment** -- whether the move was a committed, telegraphed heavy at
##     all. Squared, so an ordinary swing spends almost none of the heft its body
##     has. This is what stops the troll flooring you with every twitch: it is a
##     2.6 m body, and a 2.6 m body SHOULD floor you, but only when it wound up
##     to do it.
##
## The not-LIGHT curve (stagger *or* knockdown) is a plain logistic on
## `mass * (0.6 + 0.4 * commitment)` -- mass-dominant, because "how hard was I
## rocked" is mostly about what hit you, and it is the channel that has to say
## *medium knockback* for a big thing's ordinary swing. Fitted through the goblin
## row (10% not-light) and the troll row (70%).
const KNOCKDOWN_CEIL := 0.85
## Mass at which knockdown becomes possible at all -- the hero's own. Mass is
## `height / LAUNCH_MASS_REF` and `LAUNCH_MASS_REF` is 1.70, so this is a 1.70 m
## creature against a 1.65 m hero.
const KNOCKDOWN_MASS_FLOOR := 1.0
## Mass at which heft is spent in full: twice the hero, the floor-1 boss.
const KNOCKDOWN_MASS_FULL := 2.0
## Heft's exponent. Above 1 so the middle of the roster stays well clear of the
## floor: it is the difference between an orc's swing at 3% and at 10%.
const KNOCKDOWN_HEFT_P := 1.4
## Commitment's exponent. Squared for the reason `Hit.tier_odds` gives -- a
## moveset only spans 0.6 to 1.0 and a linear read of that is barely a
## difference at all.
const KNOCKDOWN_COMMIT_P := 2.0
## The not-LIGHT curve. Its ceiling is a hair under 1 because a logistic never
## reaches its asymptote and a 1.0 here would make the fit unsolvable.
const STAGGER_CEIL := 0.97
const STAGGER_K := 3.512
const STAGGER_MID := 1.2429

## **Commitment, 0.6 to 1.0, and 0.6 is an ordinary swing.** Not 0 to 1: a boss's
## lightest beat is still a boss hitting you, and `tier_odds` squares this before
## it is used, so a raw 0.3 would come out at 0.09 and price a boss's jab under a
## goblin's.
##
## Two things derive it and they mean the same thing. A boss reads it off the
## beat's damage and shove against its own heaviest (`Boss._commitment`) because
## it HAS a moveset to be a fraction of. A roster monster has exactly one attack,
## so there is nothing to compare it to -- it reads it off **the wind-up**
## (`Hit.commitment_of_tell`), which is the same claim the roster's own rows
## already make: the troll "tells you for three quarters of a second first", the
## kobold does not tell you at all. A move that telegraphs is a move that is
## committing, and that is exactly the move allowed to floor you.
const COMMIT_LIGHT := 0.6
## The wind-up that reads as no tell at all, and the one that reads as a fully
## telegraphed heavy. Bracketing the roster: kobold 0.30, troll 0.72.
const COMMIT_TELL_MIN := 0.28
const COMMIT_TELL_MAX := 0.75

## Floor on how long each reaction holds the hero, in seconds. `Hit.stun` is
## authored per beat (0.20-0.40 across `BossDb`) and had NO READER on the hero at
## all -- `Enemy._on_damaged` honoured it and `Hero.take_hit` never looked -- so
## these are floors under the authored number, exactly as the enemy's own
## `maxf(hit.stun, 0.22)` is.
const HURT_LIGHT_TIME := 0.22
const HURT_HEAVY_TIME := 0.42
## The knockdown, in two halves: how long he is DOWN, and how long getting up
## takes. Split because they are two clips and because only the first half is a
## punish -- the rise is a recovery the player can see coming to an end.
const KNOCKDOWN_DOWN_TIME := 0.70
const KNOCKDOWN_RISE_TIME := 1.00

## Hit-stop, in frames, at zero force and at full. The flat `HITSTOP_LIGHT` every
## incoming blow used to get is the low end; the top is `HITSTOP_HEAVY`, which is
## what landing a crit is worth and is the right price for a boss connecting.
const HURT_STOP_MIN := 3
const HURT_STOP_MAX := 9

## Camera trauma an incoming blow asks for, at zero force and at full. The old
## flat 0.80 is between them -- a goblin's jab was asking for more shake than the
## hero's own crit (`SHAKE_CRIT`, 0.72), which is why every hit in the game felt
## the same size.
const HURT_SHAKE_MIN := 0.30
const HURT_SHAKE_MAX := 0.90
## The DIRECTIONAL lurch away from the impact, in `Feel.punch` strength, and how
## long it takes to come home. Scaled by force like everything else here.
const HURT_PUNCH_MIN := 0.28
const HURT_PUNCH_MAX := 1.00
const HURT_PUNCH_TIME := 0.30

# --- The launch --------------------------------------------------------------
## Nothing in this game could leave the ground before this: `Enemy._tick_hurt`
## wrote velocity.x and velocity.z and never y, so the heaviest blow in the kit
## shoved a body a metre along the floor and it walked back at you.
##
## The body height a launch is tuned against -- the skeleton, the middle of the
## roster. Everything below scales by `LAUNCH_MASS_REF / _height()`, so mass
## needs no table: `Enemy._height()` already separates a 1.25 m goblin from a
## 2.60 m troll, and an elite is that height times `Prog.ELITE_SCALE`, so the
## bigger variant resists being thrown for free.
const LAUNCH_MASS_REF := 1.70
## Chance a committed blow sends a REFERENCE-mass body flying, scaled by the
## SQUARE of the mass ratio. Squared, where the speeds below are linear, because
## "less common for the big guys" should read more strongly than "less far" --
## at 0.38 that is roughly two heavy blows in three on a goblin, one in three on
## a skeleton, and one in seven on a troll.
const LAUNCH_CHANCE := 0.38        # [tune]
## Nothing is ever certain and nothing is ever impossible. A guaranteed launch
## stops being an event; a troll that can never be thrown teaches the player the
## move does not work on big bodies, which is not true.
const LAUNCH_CHANCE_MIN := 0.05
const LAUNCH_CHANCE_MAX := 0.85
## Straight up, m/s, at reference mass. Against GRAVITY = 22 this apexes at
## v^2/2g = 0.99 m and stays airborne 2v/g = 0.60 s -- deliberately just past the
## hero's own JUMP_SPEED arc (0.96 m, 0.59 s), so a launched body plainly
## outflies anything he can do on his own legs. A goblin scales it by 1.36
## (1.83 m, 0.82 s) and a troll by 0.65 (0.42 m, 0.39 s): one sails, one hops.
const LAUNCH_UP := 6.6             # [tune]
## And away from the blow, m/s, at reference mass. Over a 0.60 s flight that is
## 3.3 m of ground -- a fifth of a 16 m room, so a launched body lands somewhere
## you have to walk to rather than back at your feet.
const LAUNCH_OUT := 5.5            # [tune]
## Degrees/sec the model tumbles while airborne, at reference mass. About two
## turns across a goblin's flight and under one across a troll's, which is most
## of the difference between reading as *thrown* and reading as *shoved*.
const LAUNCH_SPIN := 780.0         # [tune]
## How much of the landing speed comes back as a second, smaller hop. **One
## bounce only** -- see `Enemy._tick_flight`. A body that pinballs is a physics
## bug wearing a feature, and the second hop is what sells the first as weight.
const LAUNCH_BOUNCE := 0.34        # [tune]
## Seconds a LIVING body lies there after it lands before it gets up. This is the
## reward for the launch and the reason it is worth spending a committed swing
## on: the thing is out of the fight for a moment, and you chose where it went.
const LAUNCH_DOWN := 0.55          # [tune]

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

# --- The two reactions ------------------------------------------------------
#
# The kit has always had a guard and a dodge, and both of them were ways of
# NOT being hit. Neither one paid anything back, so the correct play against
# every telegraph in the game was to walk out of its arc — which is why the
# hero's most expensive animations were the ones nobody ever needed.
#
# These two turn both defences into openings, and they are deliberately
# opposites so a player can want each of them at different moments:
#
#   THE PARRY is aggressive and it is punished. Shield held, A pressed — it has
#   its own button now rather than a modifier on the sword's, so the sword is
#   reachable straight out of a guard. Get it right
#   and the thing that swung at you is thrown off its feet; get it wrong and
#   your guard is DOWN for the rest of the move. It is the read.
#
#   THE PERFECT DODGE is safe and it is passive. It costs a dodge you were
#   allowed to throw anyway, and if you mistime it nothing bad happens — the
#   attack simply misses or connects as it always did. It is the reflex.
#
# One pays in risk, the other pays in stamina, and neither is a strict upgrade
# on the other. See docs/BESTIARY.md §3.6.

## Seconds the parry is LIVE from the frame of the press. Anything the shield
## would have blocked in this window is parried instead.
##
## 0.20 is twelve frames, which is generous next to Dark Souls (~5) and about
## right next to Breath of the Wild — the reference this game is aimed at is
## "fun to kill", and a parry that only a frame counter can land is a mechanic
## most players will conclude is broken. What keeps it honest is the recovery
## below, not the width of this. [tune]
const PARRY_WINDOW := 0.20
## And the price. Seconds the hero is rooted with his guard DOWN after the
## window closes — a whiffed parry is a hole, and this is the size of it.
##
## Deliberately longer than the window it follows: a player who mashes the
## button is guardless more than half the time, which is the whole reason the
## parry does not also cost stamina. Two prices for one press would just make
## it a move nobody throws. [tune]
const PARRY_RECOVER := 0.42
## How hard a parried body is thrown, in the same units as KNOCKBACK_HEAVY.
## Above it, because this is the one blow in the game that costs the player
## real risk to land and it should read as the biggest shove they own.
const PARRY_SHOVE := 11.0
## Seconds the parried body is out of the fight. This is "you created an
## opening", stated as a number: comfortably longer than STUN_HEAVY (0.45),
## because a parry has to buy more than a finisher does or nobody will take
## the risk over simply swinging. [tune]
const PARRY_STAGGER := 0.95
## Seconds after a successful parry in which `attack` comes out as the DASH —
## the stab out of the guard, which is exactly the move a body knocked away
## from you asks for. This is where the dash LIVES now: it used to be on
## shield+attack, which the parry took and then gave back — the parry is on A
## behind a raised shield, and shield+attack is a plain light swing again. The
## dash stays here regardless: this window is a better home for it than any
## stance modifier was. [tune]
const RIPOSTE_WINDOW := 1.20

## How fresh a roll has to be for the blow it eats to count as a PERFECT dodge,
## in seconds since the roll started.
##
## Without this, any blow refused by the roll's i-frames would pay out — and a
## dive travels, so an enemy swinging at where you *were* would reward a dodge
## thrown half a second too early. With it, the dodge has to have been an
## answer to the blow rather than a thing that happened to be running. [tune]
const DODGE_GRACE := 0.30
## Seconds after a perfect dodge in which `attack` comes out as the FLURRY —
## the leaping overhead. Longer than RIPOSTE_WINDOW because the slow-motion
## eats into it: 1.4 s of game time with 0.55 s of it at a third speed is about
## a second of thinking, which is the point of the reward. [tune]
const FLURRY_WINDOW := 1.40

## What a perfect dodge does to time, and for how long on the WALL clock.
##
## "A slight bit", which is what was asked for and also what the reference
## does: BOTW's flurry-rush window is a dip and not a stop. A third speed is
## unmistakable without being a cutscene, and half a second is long enough to
## re-aim and short enough that it never feels like the game took the controller
## off you. [tune]
const SLOWMO_SCALE := 0.34
const SLOWMO_TIME := 0.55

# --- The Thief (docs/BESTIARY.md §3, behaviour 4) ---------------------------
## Seconds the grab telegraphs before it lands, at floor 1. **More than twice a
## goblin's 0.32 s swing, and the asymmetry is the design**: a claw costs you
## health, which the walk home gives back; a grab costs you a bag slot, which
## nothing does. A cost you cannot heal has to be one you can see coming from
## further away.
##
## Read through `Prog.windup_scale(level)` exactly like `DEFS["windup"]`, so it
## compresses 3% a floor and stops at 60% of this — 0.45 s at the Chord Gate.
## GDD §7's floor is a floor for the telegraph that matters most, not only for
## the ones that were easy to leave alone. [tune]
const THIEF_GRAB := 0.75
## Multiplier on the body's own speed once it is carrying your loot. A goblin
## runs 3.0 m/s and flees at 4.5, which is faster than the hero walks and slower
## than he sprints: catchable, and only if you commit to catching it. Any
## slower and letting it go is never a real option, which would delete the
## decision this whole behaviour exists to pose (GDD §2). [tune]
const THIEF_FLEE := 1.5
## Metres from the doorway it picked at which a fleeing thief is through it and
## gone. Roughly the door's own half-span, so it disappears IN the opening
## rather than a stride short of it. [tune]
const THIEF_DOOR := 1.7
## Seconds before a thief whose grab closed on empty air tries again. Longer
## than the swing cooldown it replaces: a whiffed grab is the player having read
## the tell and stepped out of it, and the reward for reading a tell is time.
## [tune]
const THIEF_REGRAB := 1.6
## How far the body leans FORWARD over a grab, in degrees.
##
## The number is bigger than `Enemy.WINDUP_LEAN_DEG`'s 17 and it points the
## other way, and that is the whole tell: a swing rears BACK and a grab reaches
## FORWARD, so the two commits are told apart by the direction of the lean at
## any distance and in any light. Same glow, same colour, same grammar
## (docs/BESTIARY.md §1) — only the shape differs, which is the lesson in
## `CLAUDE.md` §3's last row. [tune]
const THIEF_LEAN_DEG := 26.0
## What fraction of goblins actually wear the behaviour.
##
## **It was 1.0 by omission and that deleted the goblin.** `"behaviour": &"thief"`
## went on the `DEFS` row as an unconditional default, nothing anywhere ever set
## `Enemy.behaviour`, and `_tick_chase` reaches for the bag BEFORE it checks the
## swing — so every goblin in the game stopped being able to attack. What the
## player saw was a body that closed, posed, orbited and never once hit them
## (`tools/directors/goblin_melee.gd`, which measures a skeleton in the same room
## as its control: 4 swings to the goblin's 0).
##
## A share and not a boolean, because `docs/BESTIARY.md` §3's table hangs TWO
## behaviours off the goblin row — 1 Thrower and 4 Thief — so "all of them" was
## never what that table said. A quarter is enough that a room of four usually
## holds one and a player learns the tell within a floor, and low enough that a
## goblin is still a goblin. [tune]
const THIEF_SHARE := 0.25

# --- Economy ----------------------------------------------------------------
## [tune] Enough gold to afford exactly two bail-outs at the minimum fee, so a
## new player who panics twice is broke and has to finish a run to recover.
## That first forced commitment is where the game teaches what it is about.
const START_GOLD := 30
## Slots, not items -- a stack shares a slot. Seventeen is five protected
## document-case cells plus twelve exposed hold cells: enough to fill on a good
## run and not enough to clear a floor with. [tune]
const START_BAG_SLOTS := 17
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
const BOMB_DAMAGE := 2 * HEALTH_POINT
const BOMB_HURTS_OWNER := true
## [oot] arrows cross the whole 8.5 m lock range in ~1 tick — near hitscan.
const ARROW_SPEED := 42.0
const ARROW_GRAVITY := 6.0          # [tune] OOT arrows barely drop at this range

# --- The Burst-Verse (docs/GDD.md §5.2, §6.5) --------------------------------
# **The four BOMB_* numbers above are Burst's.** GDD §5.2 changed the NOUN — you
# cast a written working, you do not throw a satchel — and said in the same
# breath that "the arc, the fuse, the sphere query and the cracked walls are
# identical". So the [oot] measurements stay where they are and stay named for
# what they were measured from; a second BURST_FUSE beside BOMB_FUSE would be
# two numbers for one fact, and the one below it would be the one nobody
# updated. What is here is only what the working needs and the satchel did not.

## Charges you can carry. `max_arrows` with a different noun (GDD §6.5), and
## deliberately less than half of it: an arrow is the answer to one body and a
## charge is the answer to one WALL, so a dozen is several floors' worth of
## doors and still not enough to burst your way past thinking. Bought from the
## alchemist, never refilled underground. [tune]
const BURST_CHARGES_MAX := 12
## Metres per second the mote leaves his hand at. Slower than an arrow by a
## factor of three and a half on purpose — the arc is the aim, and a throw you
## cannot see travel is a throw you cannot lead. [tune]
const BURST_THROW_SPEED := 12.0
## Share of the world's gravity the mote falls under. FULL, unlike the arrow's
## tenth: an arrow that drops reads as a bad shot and a working that drops reads
## as a lob, which is the whole difference between the two verbs.
const BURST_GRAVITY_SCALE := 1.0
## Seconds of arm the cast takes. Matched to `HeroRanged.HOOK_FIRE_TIME` because
## it is the same one-shot (`Hero.request_cast`) — see that method's note.
const BURST_CAST_TIME := 0.34
## How hard the blast throws what it catches, in `KNOCKBACK_*` units. Heavier
## than the sword's light blow and lighter than its committed one: a blast is
## not a swing, and a body launched across the room by it would out-carry the
## move the whole kit is built around.
const BURST_KNOCKBACK := 6.0


# --- The other two workings (docs/GDD.md §6.5) -------------------------------
# Sustain and Ballast. **They spend the same `Game.charges` Burst does** and
# there is no second pool: GDD §6.5 says "charges are arrows", and a quiver is
# one number however many things draw from it. Three counted resources bought
# at one counter would also be three lines on the alchemist's catalogue and
# three cells in the HUD column, which is a system where the design asked for a
# stock.
#
# Neither has a speed, a gravity or a knockback, because neither leaves his
# hand -- both are cast at the hero. That is why there is no BALLAST_THROW_*
# beside the Burst block above.

## Seconds the Ballast soak window lasts. Short on purpose and much shorter than
## `DRAUGHT_TIME`'s 45: a draught is a decision you made in the garrison and this
## is a decision you made in the half second before a blow lands. Long enough to
## cover the swing you saw coming and the one behind it, and not long enough to
## be a stance. [tune]
const BALLAST_TIME := 8.0
## HP the window takes off every blow, on top of armour and any
## draught. Three, which is `PLATE_SOAK`'s whole ceiling -- the point of eating
## your own profit is that it is worth more than a rung of plate for those eight
## seconds, or nobody would ever pay for it. `Hero.hurt` still floors a blow at
## 1 HP, so this is never immunity. [tune]
const BALLAST_SOAK := 3


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
## HP added to every sword swing, light and heavy alike. [tune]
const EDGE_DAMAGE: Array[int] = [0, 1, 2, 3]
## HP taken off every blow that lands, floored at one by `Hero.hurt`.
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
## Twelve buyable heavy rungs have to add up to about 4 HP, which
## is `PLATE_SOAK`'s old ceiling and the number the whole bestiary is tuned
## against (GDD §6.6 is explicit: sixteen rungs of `[0,1,2,3]` would be twelve
## HP, `Hero.hurt`'s 1 HP floor would eat the entire difficulty
## curve, and §7's *difficulty comes from depth* would be dead).
##
## Four HP across twelve rungs is a third of an HP per rung. There is
## no integer table that does that, so the pieces carry fractions and
## `Game.armour_soak()` floors the SUM. A rung is still a number the player can
## feel -- the shop line prints "1.4 -> 1.7 HP soaked" and the equipment
## screen prints the floored total -- but the thing that moves is the total,
## because the total is what a blow is measured against.
##
## Do not "fix" these into integers. That was tried in the design and it is what
## the paragraph above is about.
const PLATE_PIECE_COUNT := 4
## Soak, in HP, contributed by ONE piece at rung 0..FORGE_MAX.
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
## quartermaster's health line and Vigor both add max HP. Each pair is clamped here,
## once, so adding a third faucet later cannot quietly raise a ceiling the
## bestiary was tuned against (GDD §6.6).
##
## Draughts are deliberately OUTSIDE these caps and stay additive on top, exactly
## as they were: a draught is 45 seconds long and gone, and capping a consumable
## against a permanent ladder would make Ironhide worthless to the player who
## most needs it.
const SOAK_MAX := 4.0          ## HP, all permanent sources
const EDGE_MAX := 5            ## HP a swing, forge + rings
const MAX_HEALTH_POINTS := 34  ## 12 start + 12 quartermaster + 8 Vigor + 2 Glint
const STAMINA_MAX := 170.0     ## 100 start + 60 Focus + 10 Glint; Well Fed is temporary

## **The slider that goes the other way** (GDD §7.1). A fraction of every blow
## the hero takes, forgiven, when the player has switched mercy on in options.
##
## It starts small and climbs with `Game.deaths`, so it only ever reaches the
## player who is actually stuck -- that is the whole design, and it is why there
## is no difficulty menu on the title card. The cap is well short of invulnerable
## and deliberately so: at 30% a wraith still takes 16 HP off a careless
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
## Two rings at four rungs is +2 HP, on top of the forge's +3. [tune]
const JEWEL_EDGE_DAMAGE := 0.25
## Multiplier per rung, MULTIPLIED like the plate penalty. Two Swift rings at
## rung 4 come to 1.0834, which is more than enough to undo a full heavy suit --
## and `Game.speed_mult()` clamps the product at 1.0 so it can never make the
## hero faster than [oot]'s measured run. Buying speed BACK is the promise; going
## past the source material is not. [tune]
const JEWEL_SWIFT_SPEED := 1.0101
## Max HP per rung. Every purchase applies immediately. [tune]
const JEWEL_VIGOR_HEALTH_POINTS := 2
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

## HP a Health Draught puts back. Eight against a starting twelve: a draught is
## a second chance at the fight you are in, not a top-up you
## sip between rooms. It is also the only healing in the game that is not the
## walk home (docs/METAGAME.md §5), which is why it costs a slot and a brew.
const DRAUGHT_HEAL := 8
## Seconds the two lasting draughts run for. Long enough to cover a room and its
## fight, short enough that you cannot drink one in the garrison and still have
## it at the stair. [tune]
const DRAUGHT_TIME := 45.0
## HP Emberblood adds to a swing, and Ironhide soaks off a blow.
## Both are read through the SAME accessors the forge feeds (`Game.sword_bonus`,
## `Game.armour_soak`), so a draught is worth exactly two rungs for its 45 s and
## nothing downstream needed a line of code to know potions exist.
const DRAUGHT_EDGE := 2
const DRAUGHT_PLATE := 2


# --- Rations (docs/METAGAME.md §6.4) ----------------------------------------
## The quartermaster's food and drink, and every number below exists to keep them
## BELOW the alchemist rather than beside him. A ration is the stopgap you carry
## on the trip before you own a bottle: it is cheap, it stacks, and it costs the
## one thing a draught never asks for, which is time standing still.
##
## How many of one ration you may carry. Twenty, and it is a stack rather than a
## bottle's slot on purpose: what limits a draught is the GLASS (BOTTLE_MAX), and
## if food were limited the same way it would be a fifth bottle that heals less.
## Rations are limited by the clock instead -- twenty of them is over four minutes
## of sitting down, which nothing underground will give you. [tune]
const RATION_STACK := 20
## Escape Ropes are carried provision stock, separate from rations and the run
## bag. Nine is enough to provision several descents without making the counter
## irrelevant for long.
const ESCAPE_ROPE_STACK := 9
## How many come in one purchase at the counter. Five, so filling a stack is four
## presses rather than twenty, and so the price the player reads is a trip's worth
## rather than a mouthful's.
const RATION_BATCH := 5

## Seconds one ration takes to finish, and how often it pays out inside that.
##
## Twelve seconds is the whole design of the thing. A Health Draught is instant and
## is the answer to the fight you are IN; food is the answer to the corridor
## AFTER it, and twelve seconds is comfortably longer than any enemy in the game
## will leave you alone for. Any hit, any step and any swing cancels it (see
## `Game.cancel_meal`), so the cost of eating is a room you have already cleared.
##
## The tick is what makes a cancelled meal partial rather than wasted: stand up
## after nine seconds and you keep three ticks of it. Without that the button
## would be all-or-nothing on a channel the player cannot always control, which
## is the shape that teaches people never to press it. [tune]
const MEAL_TIME := 12.0
const MEAL_TICK := 3.0

## What one whole ration puts back, spread across the four ticks above.
##
## Food restores 4 HP, against the Health Draught's 8, and takes
## twelve seconds to do what the draught does in a frame. That ratio is the
## sentence "a weak version of a potion" written as numbers.
##
## Drink is TWELVE points of the blue bar, which is exactly `MAGIC_SPIN`: one
## drink buys one charged spin back and never a fraction of one. A number that did
## not divide into the spin would make the bar something you sip at rather than
## something you spend, and the spin is the only thing that spends it.
const MEAL_HEAL := 4
const MEAL_MAGIC := 12


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
