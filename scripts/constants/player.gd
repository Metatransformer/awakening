class_name Player
extends RefCounted
## THE PLAYER'S TUNING FILE. Every number and every clip name that decides how
## the hero moves, swings, sounds and looks lives here, in one nested tree, the
## way a web app keeps `config/`.
##
## **This is config, not the actor.** The actor is `Hero` (`scripts/actors/hero/
## hero.gd`) and its sword is `HeroCombat`. Those two scripts still own the
## BEHAVIOUR; what they no longer own is the numbers. Their `@export`s default to
## the values below, so editing this file changes the game — and the exports stay
## exactly where they were, because the directors in `tools/` read them by name.
##
## ## Reading a path
##
##     Player.Animations.LIGHT_ATTACK[1]   the clip the chain's SECOND step plays
##     Player.Attack.Light.TIME[1]         how long that step lasts
##     Player.Attack.Spin.CHARGE_TIME      how long the trigger must be held
##     Player.Motion.Dodge.ROLL_TIME       how long a roll owns the hero
##
## Anything that comes in steps is an ARRAY indexed by step, and index 0 is the
## first one. Anything with a single value is a plain constant.
##
## ## The one knob most people want
##
## `Player.Attack.TIME_SCALE` multiplies every attack's duration at once. A
## swing's clip is TIME-SCALED ONTO its duration (`Hero.request_attack` divides
## the clip's length by it), so raising this slows the ANIMATION and not merely
## the lockout — which is the fix for "the attacks look uncanny". Damage windows
## are fractions of the duration, so the blade's live slice stays in the same
## place in the swing and the hit timing is unchanged in feel.
##
##     1.0   what is shipping
##     1.15  the smallest change you can see
##     1.25  a quarter slower; the clips read as swings rather than as twitches
##     1.5   deliberate and heavy; the chain stops being a chain
##
## To slow ONE attack instead, edit its own duration and leave the scale at 1.0.
##
## ## What is here and what is in `K`
##
## Numbers here were literals in `hero.gd` and `hero_combat.gd`: they are the
## hero's alone. Values written `K.SOMETHING` are shared VOCABULARY — enemies,
## props and the HUD read the same constant — so `scripts/core/consts.gd` owns
## them. Pick a different tier here; change what a tier MEANS there. Values `K`
## tags `[oot]` are measured off Ocarina of Time footage. They are not typos and
## they are not ours to "correct".


## Everything the sword, shield and boot do. Durations are in seconds and
## damage windows are FRACTIONS of the duration they belong to.
class Attack:

	## Multiplier over every attack duration in this block. See the header.
	const TIME_SCALE := 1.0

	## The light chain — RB, or LMB. Three steps, and every array below is
	## indexed by step: 0 is the opener, 2 is the finisher.
	class Light:
		## The clips these steps play are [member Player.Animations.LIGHT_ATTACK].
		##
		## Seconds each step owns the hero, animation included. Step two is
		## quicker than step one — a chain should accelerate — and step three is
		## much slower, because it is the one that hurts AND because its clip is
		## a 2.4 s leaping overhead that reads as a twitch at the opener's pace.
		const TIME: Array[float] = [0.60 * TIME_SCALE, 0.552 * TIME_SCALE, 0.99 * TIME_SCALE]
		## The slice of each step during which the blade can hurt something, as
		## fractions of that step's TIME. Before it is the wind-up, after it is
		## the recovery.
		const WINDOW: Array[Vector2] = [
			Vector2(0.22, 0.62), Vector2(0.22, 0.62), Vector2(0.22, 0.62),
		]
		## HP per slash. The finisher is the payoff for landing three in a row
		## instead of backing off after one.
		const DAMAGE: Array[int] = [2, 2, 4]
		## How hard each step shoves, how long it stops the world for, and how
		## long the victim reels. Three identical staggers would make the third
		## step a bigger number and nothing else.
		const KNOCKBACK: Array[float] = [
			K.KNOCKBACK_LIGHT, K.KNOCKBACK_LIGHT, K.KNOCKBACK_HEAVY,
		]
		const HITSTOP: Array[int] = [K.HITSTOP_LIGHT, K.HITSTOP_LIGHT, K.HITSTOP_HEAVY]
		const STUN: Array[float] = [K.STUN_LIGHT, K.STUN_LIGHT, K.STUN_HEAVY]
		## Stamina per step. Swinging costs, which is what stops the light chain
		## being the only button anyone presses.
		const STAMINA := K.STAMINA_SWING  # 12.0
		## Reach from the hero's centre, metres. The blade is 0.92 m; the arm adds.
		const REACH := 1.35
		## Degrees of arc in front of the hero the swing is credited with.
		const ARC := 130.0
		## Seconds after a step ends during which another press CONTINUES the
		## chain rather than starting a new one.
		const CHAIN_WINDOW := 0.34
		## Fraction of the current step after which a press is REMEMBERED rather
		## than dropped. Lower it and the chain obeys earlier presses.
		const BUFFER_FROM := 0.35
		## Seconds a press made DURING A DODGE stays owed on top of the dodge
		## itself. Zero switches the dodge buffer off entirely.
		const DODGE_BUFFER_GRACE := 0.20

	## The Heavy finisher — the overhead on RT, thrown after the dash opener.
	## It plays the light chain's third clip, which is why it is slow.
	class Heavy:
		const TIME := 0.99 * TIME_SCALE
		## Later and narrower than the light window: the clip leaps before it
		## lands, so an early window puts the blade live while he is still rising.
		const WINDOW := Vector2(0.34, 0.68)
		const DAMAGE := 4
		const KNOCKBACK := K.KNOCKBACK_HEAVY  # 8.0
		const HITSTOP := K.HITSTOP_HEAVY
		const STUN := K.STUN_HEAVY
		## More than twice a light swing. The point of a stamina bar is that the
		## big button is the one you cannot lean on.
		const STAMINA := K.STAMINA_HEAVY  # 26.0

	## The magic spin — what the trigger's HOLD releases into.
	class Spin:
		## Seconds the trigger must be HELD before the release becomes a spin.
		## Under it, the release advances the Heavy combo instead. An input
		## threshold, so it deliberately does NOT scale with TIME_SCALE.
		const CHARGE_TIME := 0.42
		## Longer than any other swing. This number IS the cost — you are
		## unsteerable and unable to guard for exactly this long.
		const TIME := 0.523 * TIME_SCALE
		## Opens LATE and stays open LONG, which is the opposite shape to every
		## other swing and is the point: the blade really does travel 360
		## degrees, so the window has to still be open when the far side of the
		## circle comes round.
		const WINDOW := Vector2(0.34, 0.86)
		## Not priced as a bigger single blow — priced as this blow, delivered
		## to a room.
		const DAMAGE := 5
		## How far the circle reaches, metres from the hero's centre. Wider than
		## the sword's forward REACH: catching the second attacker IS the move.
		const REACH := 2.1
		## 360 means the direction test never rejects anything, which makes this
		## the one attack you cannot be behind.
		const ARC := 360.0
		const KNOCKBACK := K.KNOCKBACK_HEAVY
		const HITSTOP := K.HITSTOP_HEAVY
		const STUN := K.STUN_HEAVY
		const STAMINA := K.STAMINA_SPIN  # 34.0 — one roll's worth

	## The dash-spin: the Heavy combo's short turning opener, and the counter a
	## landed parry buys. What it costs you is that it CLOSES without a lock.
	class Dash:
		const TIME := 0.62 * TIME_SCALE
		## Opens after the drive has ended, so the point lands at the END of the
		## lunge. Live earlier and the thrust sweeps everything it travelled past.
		const WINDOW := Vector2(0.34, 0.60)
		const DAMAGE := 3
		## A thrust does not launch, and shoving the enemy away undoes the
		## closing the move was for.
		const KNOCKBACK := K.KNOCKBACK_LIGHT
		const HITSTOP := K.HITSTOP_HEAVY
		const STUN := K.STUN_HEAVY
		## Seconds of forward drive, and how fast. 0.20 s at 8.0 m/s is 1.6 m of
		## closing: about the gap a guarded player stands off at.
		const DRIVE_TIME := 0.20
		const DRIVE_SPEED := 8.0
		const STAMINA := K.STAMINA_DASH
		## Seconds after a successful parry in which `attack` comes out as this.
		const RIPOSTE_WINDOW := K.RIPOSTE_WINDOW  # 1.20

	## The lock-on leaping attack. The leap itself is [member Player.Motion.Lunge].
	class Lunge:
		const STAMINA := K.STAMINA_LUNGE  # 20.0

	## The light button pressed IN THE AIR. It does not go through a damage
	## window: a slam is the floor being hit, which is instantaneous.
	class Slam:
		## Seconds the hero HANGS before the drive, weapon coming overhead. The
		## whole verb lives or dies on this — without it the slam is
		## instantaneous, and an attack nobody can see wind up cannot be reacted
		## to by anything, including the player who threw it.
		const HANG := 0.16
		## Metres/sec straight down once the hang is over. Far faster than a
		## fall: the drive is what makes this a strike rather than a landing.
		const DRIVE_SPEED := 16.0
		## Seconds rooted after touchdown. The cost of the move, and the only
		## thing keeping it off the press-it-constantly list.
		const RECOVER := 0.42
		## How far above the floor the slam may be STARTED, metres.
		const MIN_HEIGHT := 0.35
		## The heaviest single hit in the kit. It costs a jump to reach, it
		## cannot be aimed once committed, and RECOVER roots him afterwards.
		const DAMAGE := 6
		## Metres of the circle it damages, from the hero's feet. Wider than the
		## spin's: the spin is a blade at arm's length and this is the FLOOR.
		const RADIUS := 2.6
		## What the dust reads as, which is deliberately WIDER than the damage
		## and never narrower — a player who dodges the visible edge is safe.
		const FX_RADIUS := 3.1
		const KNOCKBACK := K.KNOCKBACK_HEAVY
		## Seconds the victims are stunned, which is what buys back RECOVER.
		const STUN := 0.5
		const STAMINA := K.STAMINA_SLAM

	## The leaping overhead thrown out of a PERFECT dodge — the biggest sword
	## blow in the kit outside the slam, because the price is the hardest
	## defensive read in the game.
	class Flurry:
		const TIME := 1.02 * TIME_SCALE
		## Opens at 0.57 because that is where `ex_jump_attack` strikes. The
		## window was fitted to the clip rather than the clip to the window —
		## see [member Player.Animations.FLURRY_START_OFFSET].
		const WINDOW := Vector2(0.57, 0.74)
		const DAMAGE := 5
		## It LAUNCHES, and that is most of the payoff.
		const KNOCKBACK := K.KNOCKBACK_HEAVY
		const HITSTOP := K.HITSTOP_HEAVY
		const STUN := K.STUN_HEAVY
		## Seconds of forward drive, and the hop off the floor in m/s up. 5.5
		## buys 0.69 m of rise against K.GRAVITY, which puts touchdown a breath
		## BEFORE the window opens — so the blow reads as the landing rather
		## than as a swing taken in mid-air.
		const DRIVE_TIME := 0.34
		const HOP := 5.5
		## How far short of the target the leap aims to land, metres.
		const STOP_SHORT := 1.5
		## How far and how wide the leap looks for something to land on when the
		## player is not locked on, which after a dodge is most of the time.
		const SEEK_RANGE := 6.0
		const SEEK_CONE := 75.0

	## The shield: the wall, and the meeting.
	class Shield:
		## Half-angle of the block cone, degrees. A blow from outside it is not
		## blocked.
		const BLOCK_CONE := 70.0
		## Half-angle of the PARRY cone. Tighter than the block on purpose: a
		## block is a wall and it is reasonable for it to stop anything the
		## shield is roughly pointed at; a parry is a read.
		const PARRY_CONE := 45.0
		## Seconds the parry is live, and the seconds of guard-DOWN a whiff
		## costs. The recovery is longer than the window, which is what keeps
		## the parry honest without also charging stamina for it.
		const PARRY_WINDOW := K.PARRY_WINDOW    # 0.20
		const PARRY_RECOVER := K.PARRY_RECOVER  # 0.42
		## How hard a parried body is thrown, and how long it is out of the
		## fight. A parry has to buy more than a finisher does or nobody takes
		## the risk over simply swinging.
		const PARRY_SHOVE := K.PARRY_SHOVE      # 11.0
		const PARRY_STAGGER := K.PARRY_STAGGER  # 0.95
		## The shield's forward jab on a parry: metres out, and degrees of
		## pitch. Model motion only — it hurts nothing.
		const BASH_REACH := 0.26
		const BASH_PITCH := 16.0


## How the hero moves when he is not swinging. The jump ATTACK is
## [member Player.Attack.Slam], with the rest of the attacks.
class Motion:

	## The rig itself.
	class Body:
		## The source mesh is 1.0 units tall; this lifts it to adult height.
		const SCALE := K.HERO_SCALE  # 1.65 m
		## Yaw correction aligning the rig's facing with the body's -Z, degrees.
		## MEASURED by rendering four copies of the rig, not derived — see the
		## note on `Hero.model_yaw_offset` before you touch it, and see
		## docs/CONTRACT.md §2.5.
		const YAW_OFFSET := 180.0

	## Running about.
	class Ground:
		const WALK_SPEED := K.WALK_SPEED      # 1.46 m/s [oot]
		const RUN_SPEED := K.RUN_SPEED        # 4.37 m/s [oot] adult run cap
		const ACCEL := K.ACCEL                # 28.0
		const DECEL := K.DECEL                # 34.0
		## Degrees/sec the body swings onto its heading.
		const TURN_RATE := K.TURN_RATE        # 900.0
		const GRAVITY := K.GRAVITY            # 22.0 — falls faster than earth
		## Grace after leaving the floor before he counts as properly airborne.
		const COYOTE_TIME := 0.10
		## Metres of travel per footfall, walking and running.
		const STRIDE_WALK := 0.72
		const STRIDE_RUN := 1.55

	## The turn on the spot. [oot] Past TURNAROUND_ANGLE a reversal stops
	## steering and becomes a 180 — but only above TURNAROUND_MIN_SPEED01 of the
	## run cap, because a standing hero has nothing to reverse.
	class Turn:
		const TURNAROUND_ANGLE := 135.0
		const TURNAROUND_MIN_SPEED01 := 0.45
		const TIME := 0.30

	class Sprint:
		const SPEED := K.SPRINT_SPEED  # 6.07 m/s [tune] 1.39x the run cap
		## Seconds the run has to be held before it becomes a sprint.
		const HOLD_TIME := 0.36
		## Stamina per second while sprinting.
		const STAMINA_RATE := K.STAMINA_SPRINT  # 22.0
		## Fraction of the bar that has to come back before a winded hero may
		## sprint again.
		const RECOVER01 := 0.25

	class Jump:
		## Straight up, m/s. Against Ground.GRAVITY this buys 0.96 m of apex and
		## 0.59 s of air, which is the arc the jump clips were cut for.
		const SPEED := K.JUMP_SPEED  # 6.5
		## Seconds a `jump` press stays live, so a press made just before
		## touchdown still jumps rather than being eaten.
		const BUFFER_TIME := 0.12
		## Ground speed at launch above which the RUNNING jump plays. Set at
		## walking pace: the standing clip's near-vertical arc reads wrong the
		## moment the hero is visibly travelling.
		const RUN_SPEED_GATE := K.WALK_SPEED  # 1.46
		## Seconds the landing recovery may hold the body after touchdown before
		## it is faded back into locomotion. The jump clips are NOT time-scaled
		## onto the move, so without this cut he finishes a landing he is no
		## longer doing.
		const LAND_TIME := 0.12

	## Roll, backflip, side roll. i-frames run for exactly as long as the dodge
	## does, so these durations are not cosmetic — they are the width of the
	## window the button buys.
	class Dodge:
		const ROLL_SPEED := K.ROLL_SPEED  # 6.55 m/s [oot] — FASTER than running
		const ROLL_TIME := K.ROLL_TIME    # 0.62
		## The backflip is only walking-out-of-trouble quick, and it owns the
		## widest i-frame window short of a roll. That is the trade: safest,
		## least ground covered per second.
		const BACKFLIP_SPEED := K.BACKFLIP_SPEED  # 4.37 m/s [oot]
		const BACKFLIP_TIME := 0.50
		## The hard recovery. Input is locked and speed bleeds off through it.
		const RECOVER_TIME := 0.20
		## Seconds at the END of the recovery in which a COMMITTED action may
		## cut it short — a swing, a parry, the shield, a bow, another dodge, a
		## jump. NOT running: a dodge you can sprint out of is a repositioning
		## tool, and one you can chain a decision out of is a dodge.
		const CANCEL_TIME := 0.14
		## Degrees/sec the model turns back onto the body after a sideways roll.
		## 420 walks the 90-degree case back in 0.21 s, which is RECOVER_TIME —
		## so he is square again on the frame he gets his input back.
		const UNWIND_DEG := 420.0
		## [oot] A dodge needs a near-full stick deflection.
		const STICK_GATE := K.STICK_ACTION_GATE  # 0.917
		## The roll is the i-frame button, so it costs.
		const STAMINA := K.STAMINA_ROLL  # 34.0 — three rolls from full
		const IFRAMES := K.ROLL_IFRAMES  # 0.50 s
		## How fresh a roll has to be for the blow it eats to count as PERFECT,
		## and what a perfect dodge then buys.
		const PERFECT_GRACE := K.DODGE_GRACE       # 0.30 s
		const PERFECT_WINDOW := K.FLURRY_WINDOW    # 1.40 s to throw the flurry
		const PERFECT_SLOWMO := K.SLOWMO_SCALE     # 0.34x time
		const PERFECT_SLOWMO_TIME := K.SLOWMO_TIME # 0.55 s on the wall clock

	## The leap a lock-on attack takes. What it does when it lands is
	## [member Player.Attack.Lunge].
	class Lunge:
		## Ceiling on the leap's ground speed, m/s. Without it a lock on
		## something far away turns the lunge into a teleport.
		const MAX_SPEED := 12.0
		## Metres of the gap the leap deliberately leaves. Landing ON the target
		## shoves the hero through him.
		const STOP_SHORT := 1.0


## WHICH CLIP EACH MOVE PLAYS, and how it blends.
##
## A clip is a KEY into LIBRARY, not a file path — the library is one baked
## resource holding every take. `tools/build_anim_lib.gd` builds it from
## `assets/animations/`, and that script's TRIM table is where a clip's dead
## head or tail is cut. To see the keys:
##
##     grep -o 'name=\"[^\"]*\"' assets/animations/hero_anims.res | sort -u
##
## FADE_IN / FADE_OUT are seconds of blend on and off the one-shot.
## START_OFFSET is seconds of the clip that are never played — the wind-up the
## game has no window for. Getting an offset wrong pops the body: every one
## below was checked against the hips track. See `Hero._SWING_START_OFFSET`.
class Animations:

	## Every clip below is a key into this library.
	const LIBRARY := "res://assets/animations/hero_anims.res"
	## The rig the library is played on.
	const MODEL := "res://assets/characters/hero.fbx"

	# --- The light chain, indexed by step ------------------------------------
	## Step three is a leaping overhead, which is why it is the slow one.
	const LIGHT_ATTACK: Array[StringName] = [
		&"ss_slash_01", &"ss_slash_03", &"ss_slash_04",
	]
	## The mid-chain step has the tightest fade of the three: a chain that fades
	## between steps reads as lag.
	const LIGHT_ATTACK_FADE_IN: Array[float] = [0.06, 0.04, 0.05]
	const LIGHT_ATTACK_FADE_OUT: Array[float] = [0.16, 0.12, 0.18]
	## Mixamo swings spend a third to a half of their length winding up. Each
	## number is picked so the blade starts travelling on the frame the HITBOX
	## GOES LIVE. Step three's is the exception: the solved answer (0.89) was up
	## at the top of the leap, so 0.47 is where the launch crouch bottoms out.
	const LIGHT_ATTACK_START_OFFSET: Array[float] = [0.22, 0.46, 0.47]

	# --- The rest of the sword -----------------------------------------------
	## The Heavy finisher plays the light chain's third clip — the Heavy chain
	## reaches the same payoff after its own opener.
	const HEAVY_ATTACK := LIGHT_ATTACK[2]

	const SPIN_ATTACK := &"ax_melee_attack_360_low"
	## The spin shares the tightest fade-in with the dash, for the same reason:
	## its wind-up already happened. Easing into the release spends it on a
	## blend, and the first thing this clip does is TURN — a turn eased out of
	## locomotion reads as the hero losing his footing.
	const SPIN_ATTACK_FADE_IN := 0.04
	const SPIN_ATTACK_FADE_OUT := 0.22
	const SPIN_ATTACK_START_OFFSET := 0.41
	## Seconds into the opener's clip that the CHARGE pose holds on, and how
	## long it takes to fade there. A frame picked by eye, not a computed one.
	const CHARGE_POSE_TIME := 0.70
	const CHARGE_POSE_FADE := 0.18

	const LUNGE_ATTACK := &"ss_attack_01"
	const LUNGE_ATTACK_FADE_IN := 0.08
	const LUNGE_ATTACK_FADE_OUT := 0.20
	## No cut: this clip already strikes at 0.40 of its length against a window
	## that opens at 0.46, so it is the one whose blade moves BEFORE it can hurt.
	const LUNGE_ATTACK_START_OFFSET := 0.00

	const DASH_ATTACK := &"ss_attack_03"
	const DASH_ATTACK_FADE_IN := 0.04
	const DASH_ATTACK_FADE_OUT := 0.18
	const DASH_ATTACK_START_OFFSET := 0.17

	const PARRY := &"ex_parry"
	## The tightest fade-in in the file, and the one place that is a correctness
	## question rather than a feel one: the move is live for 0.20 s, so a 0.06 s
	## ease would spend nearly a third of the active window on a blend out of
	## the guard pose.
	const PARRY_FADE_IN := 0.02
	const PARRY_FADE_OUT := 0.14
	## Where the shield starts going forward. Cutting more pops the body 0.09 m.
	const PARRY_START_OFFSET := 0.08

	const FLURRY := &"ex_jump_attack"
	## The loosest fade in the file, for the opposite reason to the parry's: it
	## comes out of a dodge's recovery in slow motion, where there is time to
	## see the hero gather.
	const FLURRY_FADE_IN := 0.09
	const FLURRY_FADE_OUT := 0.22
	## No cut: the anticipation crouch runs to 0.37 and skipping into it would
	## launch him from a pose already 0.09 m off the floor. A wind-up you can
	## see is worth keeping on the one move thrown IN SLOW MOTION.
	const FLURRY_START_OFFSET := 0.00

	const SLAM := &"ax_melee_run_jump_attack"
	const SLAM_START_OFFSET := 1.50
	const SLAM_LAND_OFFSET := 1.70

	# --- Dodges, indexed like Hero.Dodge: forward, back, left, right ---------
	## The sideways dodge is a full ROLL, not a hop: it travels at a roll's
	## speed for a roll's duration, or the left-hand dodge is quietly worse than
	## the forward one for no reason the player can see.
	const DODGE: Array[StringName] = [
		&"ex_roll_to_run", &"ex_backflip", &"ex_roll_to_run", &"ex_roll_to_run",
	]
	## The roll gets the widest fade of the four: it is the longest move and the
	## one that ends lying down, so snapping out of it pops the hero upright.
	const DODGE_FADE_IN: Array[float] = [0.05, 0.05, 0.04, 0.04]
	const DODGE_FADE_OUT: Array[float] = [0.16, 0.14, 0.12, 0.12]
	## Only the backflip cuts any: 0.45 s of it was an anticipation crouch the
	## player never needed to see.
	const DODGE_START_OFFSET: Array[float] = [0.0, 0.45, 0.0, 0.0]

	# --- Locomotion ----------------------------------------------------------
	const IDLE := &"ss_idle_01"
	const WALK := &"ss_walk_01"
	const RUN := &"ex_running"
	const SPRINT := &"ex_fast_run"
	const TURN180 := &"ss_180_turn_01"
	## Ground speeds the locomotion blend treats as walk / run / sprint.
	const WALK_BLEND_SPEED := K.WALK_SPEED
	const RUN_BLEND_SPEED := K.RUN_SPEED
	const SPRINT_BLEND_SPEED := K.SPRINT_SPEED
	## Playback rate of the locomotion blend, standing and at full run. The run
	## is nudged past 1.0 so the feet stop skating.
	const STRIDE_SCALE_IDLE := 1.0
	const STRIDE_SCALE_RUN := 1.06

	# --- Jumping -------------------------------------------------------------
	const AIR := &"ss_jump_01"
	const LAND := &"ss_jump_02"
	const JUMP := &"ex_jump"
	const JUMP_RUN := &"ex_jump_running"
	## Both jumps skip their gather: the game has no window for an anticipation
	## the player did not ask for.
	const JUMP_START_OFFSET := 0.50
	const JUMP_RUN_START_OFFSET := 0.47

	# --- Guard ---------------------------------------------------------------
	const BLOCK := &"ss_block_idle_01"
	const BLOCK_FADE := 0.12
	## Strafing behind a raised shield: forward, back, right, left, each at
	## walk and at run.
	const GUARD_FWD_WALK := &"ss_walk_01"
	const GUARD_FWD_RUN := &"ss_run_01"
	const GUARD_BACK_WALK := &"ss_walk_02"
	const GUARD_BACK_RUN := &"ss_run_02"
	const GUARD_RIGHT_WALK := &"ss_strafe_01"
	const GUARD_RIGHT_RUN := &"ss_strafe_04"
	const GUARD_LEFT_WALK := &"ss_strafe_02"
	const GUARD_LEFT_RUN := &"ss_strafe_03"

	# --- Ranged and tools ----------------------------------------------------
	const BOW_DRAW := &"bow_draw_arrow"
	const BOW_SHOT := &"bow_aim_recoil"
	const AIM_IDLE := &"bow_aim_overdraw"
	const AIM_WALK := &"bow_aim_walk_forward"
	const AIM_FADE := K.CAM_AIM_BLEND  # 0.16
	const HOOK_SHOT := &"ex_hookshot_fire"
	const WOODSMAN_CHOP := &"ax_melee_attack_downward"

	# --- Taking a hit --------------------------------------------------------
	const FLINCH_LIGHT := &"ss_impact_02"
	const FLINCH_HEAVY := &"ss_impact_03"
	const KNOCKED_DOWN := &"ex_knocked_down"
	const GETTING_UP := &"ex_getting_up"
	const GETUP_START_OFFSET := 0.28

	# --- Stances -------------------------------------------------------------
	const REST := &"ss_crouch_idle_01"
	const REST_FADE := 0.30
	const ITEM_GET := &"ss_power_up_01"


## WHICH SOUND EACH ATTACK MAKES AND WHEN IT FIRES.
##
## `*_AT` is a cue time expressed as a FRACTION of the attack it belongs to, so
## a cue stays in the same place in the swing when you change the attack's
## duration or [member Player.Attack.TIME_SCALE]. 0.0 fires on the frame the
## swing commits; -1.0 means the cue never fires at all.
##
##     WHOOSH_AT = 0.0    the blade is heard the instant the button is read
##     WHOOSH_AT = 0.22   it is heard as the blade goes live (Light.WINDOW.x)
##
## The impact sound is NOT a cue: it fires when the blade actually touches
## something, which is an event and not a time.
##
## `*_PITCH` multiplies the stream's pitch — pitching a swing down is the
## cheapest honest way to make it sound like more effort. `*_WOBBLE` is the
## random range multiplied over it, so two swings never ring identically.
class Audio:

	const SFX_SWING := "res://audio/sfx/swing.ogg"
	const SFX_IMPACT := "res://audio/sfx/weapon_impact_sword_1.ogg"
	const SFX_CHARGING := "res://audio/sfx/sword_charging.ogg"
	const SFX_RELEASE := "res://audio/sfx/sword_release.ogg"
	const SFX_YELL := "res://audio/sfx/weapon_full_charge_voice_male_1.ogg"
	const SFX_SWAP := "res://audio/sfx/equip.ogg"

	## The blade landing, whatever threw it. Random pitch only.
	const IMPACT_WOBBLE := Vector2(0.92, 1.08)

	## The light chain, indexed by step. Two rises then a drop: the chain should
	## sound like it is going somewhere, and the finisher is the heaviest thing
	## in it. Cheapest honest way to make three swings read as one sentence.
	class Light:
		const WHOOSH_AT: Array[float] = [0.0, 0.0, 0.0]
		const WHOOSH_PITCH: Array[float] = [1.0, 1.08, 0.86]
		const WHOOSH_WOBBLE := Vector2(0.94, 1.07)

	## The lowest pitch in the kit outside the spin. Three swings that sound
	## identical are three swings the player cannot tell apart with their eyes
	## on the enemy.
	class Heavy:
		const WHOOSH_AT := 0.0
		const WHOOSH_WOBBLE := Vector2(0.74, 0.82)

	class Spin:
		## The hum starts on the PRESS, not when the charge arms — it is a rise,
		## and a rise that begins at the top is a beep.
		const CHARGE_LOOP_ON_PRESS := true
		const WHOOSH_AT := 0.0
		const WHOOSH_WOBBLE := Vector2(0.68, 0.78)
		## The release ring, and the hero's effort. Both on the release frame.
		const RELEASE_AT := 0.0
		const RELEASE_WOBBLE := Vector2(0.96, 1.04)
		const YELL_AT := 0.0
		const YELL_WOBBLE := Vector2(0.97, 1.03)

	class Dash:
		const WHOOSH_AT := 0.0
		const WHOOSH_WOBBLE := Vector2(0.86, 0.94)

	class Flurry:
		const WHOOSH_AT := 0.0
		const WHOOSH_WOBBLE := Vector2(0.72, 0.80)
		const YELL_AT := 0.0
		const YELL_WOBBLE := Vector2(0.97, 1.03)

	## The slam's own landing bang, which is not the sword's impact.
	class Slam:
		const IMPACT_WOBBLE := Vector2(0.72, 0.80)
