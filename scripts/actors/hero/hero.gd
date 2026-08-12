class_name Hero
extends CharacterBody3D
## P2 — the hero. Camera-relative locomotion on the OOT model.
##
## The three facts this is built on (refs/REFERENCE.md §3, docs/CONTRACT.md §2.5):
##
##   1. **There is no walk/run threshold.** Speed is a continuous curve of stick
##      magnitude — `K.speed_for_stick()`. The walk<->run *animation* is a blend
##      driven by speed, not a state transition. Nothing here branches on "is
##      walking". §3.2
##   2. **Reversing is a distinct move.** Past ~135° off the current heading OOT
##      does not steer, it kills speed and re-orients — which is why a sharp
##      about-face feels like its own action. That is the `ss_180_turn_01` case.
##      §3.3
##   3. **The roll is faster than the run** (6.55 vs 4.37 m/s) and it commits.
##      It is ground-covering with a hard recovery, not a cancel. §3.4
##
## Movement is camera-relative: the raw stick vector is rotated by the ACTIVE
## camera's yaw before it becomes world motion (docs/CONTRACT.md §4). The hero
## reads `get_viewport().get_camera_3d()`, so it never imports P1's script.

## Fires as each foot plants. P11 (feel) connects this for footstep audio/dust.
signal footstep(world_pos: Vector3, speed01: float)
## Fires the frame the hero regains the floor. `fall_speed` is m/s downward.
signal landed(fall_speed: float)
## Fires as a roll starts, so P4/P11 can hang i-frames and a whoosh off it.
signal roll_started
signal roll_finished
## Fires the frame an air slam reaches the floor, at the hero's feet. `fall_speed`
## is m/s downward at contact. HeroCombat hangs the damage, the dust and the
## bang off this — the hero owns the MOVE and never the blow (docs/CONTRACT.md
## §8), exactly as request_attack owns the pose and not the damage.
signal slammed(at: Vector3, fall_speed: float)

## SLAM is the air attack: a hang, a drive at the floor, and a rooted recovery
## once it arrives. It is its OWN state rather than an ATTACK variant because
## request_attack's first line refuses anything not standing on the floor, and
## relaxing that would let every swing in the kit be thrown mid-jump.
## HURT is the one state nothing here asks for: it is entered from OUTSIDE, in
## `take_hit`, on top of whatever the hero was doing. See `_enter_hurt`.
##
## It exists where `Swing.PARRY` deliberately does not have a MoveState of its
## own, and the difference is worth spelling out because the argument against
## that one reads like an argument against this one. A parry behaves EXACTLY like
## an ATTACK -- committed, timed, steered the same way -- so a state for it would
## be a state that exists to be forgotten in one of the six places `state` is
## matched on. HURT behaves like nothing else in the enum: it is the only state
## that can interrupt any other, the only one that takes no input at all, and the
## only one whose exit is a recovery the player is meant to feel.
enum MoveState { GROUND, TURN180, ROLL, ROLL_RECOVER, ATTACK, HOOK, SLAM, HURT }

## Which way a dodge goes, measured against the facing it KEEPS through it.
##
## Free — nothing locked, no guard — the roll *is* the turn, so this is always
## FORWARD and the other three never come up: an unpinned dodge cannot go
## backwards because the body has already turned to meet it. They exist for the
## stances that pin the facing, which is where OOT's roll/backflip/sidehop split
## lives too. See `_dodge_for`.
enum Dodge { FORWARD, BACK, LEFT, RIGHT }

## Which swing is being played. The hero owns the POSE; HeroCombat owns what the
## pose costs and what it does — see request_attack.
##
## The three lights are separate values rather than an index into one clip
## because the animation tree needs one node per variant (see _add_swing), and a
## node cannot be addressed by a number that only exists in the combat script.
##
## PARRY is in here despite doing no damage, and that is not a hack: everything
## `Swing` actually means is "a pose the hero is committed to for a while", and
## the parry is the most committed thing in the kit (`K.PARRY_RECOVER`). What it
## does NOT do is go through `HeroCombat._commit`, which is where a swing gets a
## hitbox — so the parry is a swing to the animation tree and to the state
## machine, and nothing at all to the damage system.
enum Swing { LIGHT1, LIGHT2, LIGHT3, SPIN, LUNGE, DASH, PARRY, FLURRY }

## The hero's voice — the one grunt of effort the project has, spent on the jump
## and on the backflip (`_fire_jump`, `_fire_dodge`).
##
## It is `weapon_full_charge_voice_male_1` because THAT IS THE ONLY VOCALISATION
## IN THE PROJECT THAT MAKES A SOUND. `audio/sfx/` ships a full human voice set —
## `human_male_attack_1/2`, `human_male_hurt`, `human_male_death`, and the female
## equivalents — and every one of them is digital silence on disk: -91.0 dBFS
## peak, four kilobytes of nothing, an ogg header and no samples. Wiring one of
## those is how you spend an afternoon on a jump that never makes a noise and a
## `_load` that never warns, because the file is right there.
##
## Named as a constant rather than typed at both call sites so that the day those
## files are replaced with real recordings, the hero's voice moves in one edit.
## `HeroCombat.sfx_yell` is the same clip on the spin release — two uses of one
## grunt is the price of having one grunt.
const VOICE_EFFORT := &"weapon_full_charge_voice_male_1"

@export_group("Rig")
@export var hero_model: PackedScene = preload("res://assets/characters/hero.fbx")
@export var anim_library: AnimationLibrary = preload("res://assets/animations/hero_anims.res")
## The source mesh is 1.0 units tall. K.HERO_SCALE lifts it to adult height.
@export var model_scale: float = K.HERO_SCALE
## Yaw correction, degrees, aligning the rig's facing with the body's -Z.
##
## Measured, not derived: tools/scenes/_facing.tscn renders four copies of the
## rig at 0/90/180/270 playing the same clip, next to a post marking -Z. At 180
## the hero shows his back and runs at the post; every other offset is visibly
## wrong. This holds for the idles AND the locomotion clips — one constant does
## serve the whole library.
##
## (An earlier version blended this on speed, on the theory that idles and runs
## differed by ~52 deg. That came from sampling the `mixamorig_Hips` rotation
## TRACK, which measures the bone's local pose against its rest orientation, not
## where the character is looking. The render disagrees with it. If you are
## tempted to reintroduce a per-clip correction, re-run _facing.tscn with that
## clip first — the image settles it in one frame.)
@export var model_yaw_offset: float = 180.0

@export_group("Locomotion")
@export var accel: float = K.ACCEL
@export var decel: float = K.DECEL
## Degrees/sec the body swings onto its heading. [tune] K.TURN_RATE.
@export var turn_rate: float = K.TURN_RATE
@export var gravity: float = K.GRAVITY
## Grace after leaving the floor before we treat the hero as properly airborne.
@export var coyote_time: float = 0.10
## [oot] Past this angle a reversal stops steering and becomes a 180. §3.3
@export var turnaround_angle_deg: float = 135.0
## Fraction of the run cap the hero must be carrying for a reversal to become a
## full 180 rather than an ordinary pivot.
@export var turnaround_min_speed01: float = 0.45
@export var turn180_time: float = 0.30

@export_group("Lunge")
## Ceiling on the leap's ground speed, m/s. Without it a lock on something far
## away turns the lunge into a teleport — the drive is "close this gap in this
## many seconds", and a big enough gap divides into an absurd number.
@export var lunge_max_speed: float = 12.0
## Metres of the gap the leap deliberately leaves. Landing ON the target shoves
## the hero through him, and a lunge that ends behind the enemy is a whiff the
## player will read as the hitbox being broken.
@export var lunge_stop_short: float = 1.0

@export_group("Roll")
@export var roll_speed: float = K.ROLL_SPEED
@export var roll_time: float = K.ROLL_TIME
## The backflip's speed, which is not the roll's: it is only walking-out-of-
## trouble quick (4.37 m/s against 6.55). [oot], and measured.
@export var backflip_speed: float = K.BACKFLIP_SPEED
# THERE IS NO SIDEHOP ANY MORE, and `K.SIDEHOP_SPEED` (6.19 m/s) / the 0.44 s
# hop window it used to pair with are deliberately not read here. They are OOT's
# numbers for a short hop out of the way, and the sideways dodge in this game is
# a full roll now (see `clip_roll_left`) — it travels at a roll's speed for a
# roll's duration in whatever direction it points, or the left-hand dodge is
# quietly worse than the forward one for no reason the player can see. i-frames
# run for exactly as long as the dodge does (`take_hit`), so that is not a
# cosmetic difference: it is the width of the window the button buys.
#
# The constant stays in `K`. It is measured footage, not a typo (§6), and it is
# what a real sidehop would be worth if a clip for one ever turns up.

## The backflip's own window, because it is not a sidehop. A flip has to leave
## the ground, invert and land, and 0.44 s of that is a blur nobody can read as
## a flip. It buys the flip its own identity in the one currency dodges trade in:
## i-frames run for exactly as long as the dodge does, so the backflip is the
## widest window short of a roll and the slowest to get you out of the way
## (4.37 m/s). That is the trade — safest, but least ground covered per second.
##
## 0.60 -> 0.50, and it is `backflip_start_offset` that paid for it. The old
## number was "the shortest window the clip stays legible in", and that was
## honestly measured but it was measuring the wrong clip: 0.45 s of what had to
## stay legible was an anticipation crouch the player never needed to see. With
## the gather cut, 0.50 s is all flip, and the sheet from
## tools/directors/_backflip_trace.gd at 0.50 has every beat in it — gather,
## launch, inversion, overhead, descent, absorb — with none of them blurred.
##
## 0.44 was shot in the same sweep and it also reads. It is not used because of
## what it costs OFF the sheet: the window is the i-frame window, so 0.44 is a
## 27% cut to what the button buys defensively, against 0.06 s of snap nobody
## asked for. 0.50 is a 17% cut and the move is already snappier than the ask
## from the head cut alone. [tune]
@export var backflip_time: float = 0.50
## The hard recovery. Input is locked and speed bleeds off through it.
@export var roll_recover_time: float = 0.20
## Seconds at the END of `roll_recover_time` in which a COMMITTED action may cut
## the recovery short: a swing, a parry, the shield, a bow, another dodge, a jump.
##
## THE THING IT DOES NOT LET YOU CANCEL INTO IS RUNNING, and that asymmetry is
## the whole design. `_tick_roll_recover` used to open "OOT's roll commits — you
## cannot cancel it into a run, and that is exactly why it reads as a move and
## not as a dodge-cancel", and that is still true and still what the recovery is
## for: a dodge you can sprint out of is a free repositioning tool, and one you
## can chain a decision out of is a dodge. So the window is checked by the
## `request_*` entry points and by `_try_start_roll` / `_try_start_jump`, and
## NOT by `_tick_ground` — hold the stick through the tail and you still stand
## there for the full 0.20, exactly as before.
##
## The other half is that the press is now OWED rather than eaten. A swing
## pressed at any point in the dodge was silently dropped (`HeroCombat._press`
## only buffered while a swing was already running), so the player pressed
## attack coming out of a roll, got nothing, and pressed again — which read as
## the recovery being a third of a second longer than it is. `HeroCombat`
## buffers it now and pays it out on the frame this window opens.
##
## 0.14 of 0.20 leaves 0.06 s of hard tail. That is deliberately not zero:
## `dodge_unwind_deg` walks a sideways roll's model yaw back onto the body over
## the whole 0.20, so a window that opened on the first frame of the recovery
## would let him swing while still visibly crabwise. [tune]
@export var dodge_cancel_time: float = 0.14
## Seconds a jump's LANDING RECOVERY is allowed to hold the body after touchdown
## before it is faded back into locomotion — and only once the player is asking
## for something (see `_tick_jump_cut`).
##
## The jump clips are the one commitment in this file that is NOT time-scaled
## onto its move: `ex_jump` is 1.67 s played from `jump_start_offset` (0.50) at
## 1x, and the airborne stretch it was cut to is ~0.60 s (K.JUMP_SPEED). That
## leaves ~0.57 s of absorb-and-stand playing OVER the locomotion the player has
## already got back, plus the one-shot's own 0.22 s fade — so a hero who lands
## running spends four fifths of a second finishing a landing he is no longer
## doing. Gameplay was never locked here; the BODY was, which is worse, because
## it looks like input is being ignored when it is being obeyed.
##
## Scaling the clip onto the landing instead was the other option and it is the
## wrong one: it would speed up the airborne stretch too, and that stretch is
## the arc `K.JUMP_SPEED` was chosen to match. Cutting the tail leaves the leap
## exactly as authored.
@export var jump_land_time: float = 0.12
## Degrees per second the model turns back onto the body after a sideways roll
## (see `_dodge_model_yaw`). 420 walks the 90-degree case back in 0.21 s, which
## is `roll_recover_time` — so the unwind IS the recovery, and he is square again
## on the frame he gets his input back. Slower and he stands up crabwise; faster
## and the last frame of the roll snaps, which is the exact pop this avoids.
@export var dodge_unwind_deg: float = 420.0
## [oot] roll/backflip/sidehop need a near-full stick deflection. §3.2
@export var roll_stick_gate: float = K.STICK_ACTION_GATE
## The roll is the i-frame button (roll grants K.ROLL_IFRAMES). Free i-frames
## make it the only button anyone presses, so it costs. See K.MAX_STAMINA.
@export var roll_stamina: float = K.STAMINA_ROLL

@export_group("Jump")
## Straight up, m/s. See K.JUMP_SPEED for what it buys against K.GRAVITY (0.96 m
## of apex, 0.59 s in the air) and why both numbers are the ones the clips want.
@export var jump_speed: float = K.JUMP_SPEED
## Seconds a `jump` press stays live. A press made in the last moments of a fall
## still jumps on touchdown rather than being eaten — without it the only way to
## chain jumps is to press exactly on the landing frame, and nobody can.
@export var jump_buffer_time: float = 0.12
## Ground speed at launch above which the RUNNING jump plays. Set at walking
## pace, not at the run cap: the standing clip's near-vertical arc reads wrong
## the moment the hero is visibly travelling, well before he is sprinting.
@export var jump_run_speed_gate: float = K.WALK_SPEED

@export_group("Slam")
## Seconds the hero HANGS before the drive, with the weapon coming overhead.
##
## The whole verb lives or dies on this. Without it the slam is instantaneous —
## press attack in the air and the hero is simply on the floor, with the impact
## already over by the time the player's eye reaches him — and an attack nobody
## can see wind up cannot be reacted to by anything, including the player who
## threw it. A sixth of a second is enough to read the pose and short enough that
## it never feels like a stall.
@export var slam_hang: float = 0.16
## Metres/sec straight down, once the hang is over. Deliberately far faster than
## a fall (K.GRAVITY tops a jump out at about 6.5 m/s): the drive is what makes
## this a strike rather than a landing, and at gravity's own speed it reads as
## the hero giving up mid-air.
@export var slam_speed: float = 16.0
## Seconds rooted after touchdown. This is the cost of the move and the only
## thing keeping it off the "press it constantly" list — it is longer than any
## swing's recovery, and it cannot be rolled out of.
@export var slam_recover: float = 0.42
## How far above the floor the slam may be STARTED. Below this there is not
## enough air for the hang to read, and what the player gets for the press is a
## hero who twitches and is immediately rooted for `slam_recover`.
@export var slam_min_height: float = 0.35

@export_group("Animation")
@export var clip_idle: StringName = &"ss_idle_01"
@export var clip_walk: StringName = &"ss_walk_01"
## The run is `ex_running` — a FREE run, arms driving — and NOT `ss_run_01`, the
## sword-and-shield pack's own, which is what shipped here for a year on the
## reasoning that the idle and the walk came from that pack so the run should
## too. That reasoning picked a clip off its filename, which is the thing
## swing_lookdev exists to stop, and nobody had photographed it since.
##
## Photograph it (tools/directors/run_lookdev.gd, six frames, front and side,
## with the sword and shield mounted) and `ss_run_01` is not a run. The torso
## stays bolt upright, the knees barely pass each other, and both arms are
## PINNED — shield flat across the chest, sword held out stiff — for the whole
## cycle. It is a man jogging while holding a guard, and at K.RUN_SPEED, which is
## most of the seconds this game is ever looked at, it reads as a shuffle.
##
## `ex_running` leans, drives the knee through, and swings both arms; the sword
## and shield ride the hands they are bone-attached to and come along for free.
## Yes, that means the guard is down while he runs. That is what running is, and
## the guard is a button (`clip_block`) which puts it back up in 0.12 s.
##
## THE STRIDE SAYS THE SAME THING, and it is measured, not eyeballed —
## tools/_clip_travel.gd, which reads toe-to-toe separation off the posed
## skeleton because `build_anim_lib` strips the hips translation that would
## otherwise carry the answer:
##
##   ss_run_01     0.700 s  stride 0.747 m -> legs authored for 2.13 m/s
##   ex_running    0.633 s  stride 0.741 m -> legs authored for 2.34 m/s
##   ex_fast_run   0.533 s  stride 0.721 m -> legs authored for 2.70 m/s
##
## Same step, quicker cycle: `ex_running` covers 10% more ground per second than
## the clip it replaces, so against K.RUN_SPEED's 4.37 m/s it is the one that
## skates LESS. (Everything here is driven roughly 2x its authored speed. That is
## the hero being 1.65 m against Mixamo's actor and the speeds being OOT's; it is
## a whole-locomotion question and not this line's to answer.)
##
## And it closes a costume change that the blend space's own comment claims not
## to have: the SPRINT is already `ex_fast_run`, out of this same free-armed
## family. Guarded walk -> guarded run -> free sprint put the pose swap in the
## middle of the curve, at the speed the player crosses most often. Now the only
## seam left is walk -> run, where a hero lowering his guard as he opens up is
## the thing you would animate on purpose.
@export var clip_run: StringName = &"ex_running"
## The four dodges. **The Pro Sword and Shield Pack contains no roll of any
## kind** — 52 clips, not one of them a dodge — which is why every direction once
## played `ex_roll_to_run`, a 3.2 m forward shoulder dive, including the
## backstep. A hero sliding backwards through a forward roll is the single most
## visible thing wrong with the guard, and it is worth knowing that the fix below
## is not a return to that: three of the four still name that clip, but the model
## is TURNED to face where each one travels, which is the whole difference.
##
## LEFT and RIGHT are **the roll, turned sideways**, and they got there the long
## way round. They were `bow_dodge_left` / `bow_dodge_right` out of the longbow
## set, whose hips tracks are honest (+1.04 m and −1.07 m in clip space, read out
## of the raw FBX before `build_anim_lib` strips them — see
## tools/directors/dodge_lookdev.gd) and whose POSE is not a dodge at all: the
## hero stays bolt upright and slides, feet shuffling, like a man edging along a
## ledge. Photographed side by side with the forward dive
## (tools/directors/lt_moveset.gd) there is no argument to have about it.
##
## So all three of FORWARD, LEFT and RIGHT play `ex_roll_to_run` now. A roll is a
## roll whichever way it points, and the direction is carried by turning the
## MODEL rather than by finding a clip per compass point — see
## `_dodge_model_offset`. That also keeps the sideways dodge honest about its own
## cost: it is a full roll, so it takes a roll's time and covers a roll's ground
## (`_dodge_time`, `_dodge_speed_for`), rather than being the cheap 0.44 s hop
## that a shuffle could get away with pretending to be.
##
## They stay three separate exports pointing at one clip rather than collapsing
## into one, because they are three separate one-shots in the tree with their own
## time scales, and because a sideways clip that is actually a sidehop may still
## turn up — the pack has none today.
##
## BACK is a **backflip**, and it is the one dodge that keeps a clip of its own:
## `bow_dodge_back` is a backward shuffle-walk that never leaves the ground,
## which is a retreat, not an evade. `ex_backflip` crouches, launches, goes fully
## inverted overhead and lands in a deep absorb — and it is what
## `K.BACKFLIP_SPEED` has been named after since the day it was measured. It is
## also the one dodge that must NOT be turned: it is authored travelling
## backwards already.
@export var clip_roll: StringName = &"ex_roll_to_run"
@export var clip_roll_back: StringName = &"ex_backflip"
@export var clip_roll_left: StringName = &"ex_roll_to_run"
@export var clip_roll_right: StringName = &"ex_roll_to_run"
## Where in `ex_backflip` the flip starts, in seconds. `jump_start_offset`'s
## problem exactly, and worse here, because the hero is not standing still while
## the anticipation plays — he is travelling backwards at 4.37 m/s from the frame
## the button goes down.
##
## Measured, not guessed (tools/directors/_backflip_trace.gd, which shoots the
## dodge the GAME plays rather than the clip): uncut, the hero covered 1.31 m —
## HALF the backflip — with his hips still at crouch height, and did not leave
## the ground until 0.33 s into a 0.80 s move. Ten of the twenty-seven frames on
## that sheet are a man squatting while sliding backwards. That is the whole of
## what "the backflip feels sluggish" was.
##
## The clip's own hips track (tools/_clip_hips.gd) is where the number comes
## from: standing 0.523, crouch bottoms 0.366 @0.33, a slow unload to 0.423 @0.57,
## then the launch — steep from 0.57, apex 0.806 @1.13, down @1.35.
##
## 0.45 rather than 0.57, and the 0.12 s is deliberate. Cutting to the launch
## frame the way the jump does starts the clip on a body already extending, and
## the flip pops out of the guard with no gather at all; keeping the last slice
## of the unload buys one frame of compression to launch off. The jump can cut
## clean because it opens from a neutral stand — this opens from a raised shield.
@export var backflip_start_offset: float = 0.45
@export var clip_turn180: StringName = &"ss_180_turn_01"
## FALLING, not jumping. These two are what plays when the ground goes away
## underneath him — walking off a ledge, a pit, the end of a hookshot pull — and
## they stay on the sword-and-shield set because that is the stance he falls in.
## A deliberate jump plays clip_jump/clip_jump_run below instead, and suppresses
## both of these: those clips contain their own air pose AND their own landing.
@export var clip_air: StringName = &"ss_jump_01"
@export var clip_land: StringName = &"ss_jump_02"
## The two jumps. Standing and running are separate clips rather than one clip
## leaned on, because they are different ARCS, not the same arc at two speeds:
## the standing jump rises 0.57 in hip height and the running one 0.26, which is
## the difference between going up and going along.
##
## Both come from `extra`, which is where this project's non-sword-set clips
## live — the Pro Sword and Shield Pack has no jump in it either (see the note
## on the dodges above; it had no roll and no 360 for the same reason).
@export var clip_jump: StringName = &"ex_jump"
@export var clip_jump_run: StringName = &"ex_jump_running"
## Where in each clip the feet leave the ground, in seconds. Measured off the
## hips Y track — see the TRIM note in tools/build_anim_lib.gd for the full
## profile of both.
##
## THIS IS THE WHOLE TRICK, and it is worth understanding before changing it.
## Both clips open with an anticipation crouch — `ex_jump` spends 0.50 s
## gathering before it launches — and the game has no anticipation window at
## all: the hero is airborne on the frame the button goes down. Playing the
## crouch would mean either 0.50 s of input latency on every jump, or a hero who
## squats while already rising. So the clip is STARTED at its launch frame
## (AnimationNodeAnimation.start_offset) and the crouch is simply never seen.
##
## What is left runs at scale 1.0 and does not need compressing, because the
## airborne stretch of both clips (~0.60 s) is what K.JUMP_SPEED was picked to
## match.
##
## THE PARAGRAPH ABOVE WAS FALSE from the day it was written until the swings
## needed the same trick and an A/B caught it (tools/directors/swing_latency.gd).
## `start_offset` does nothing without `use_custom_timeline`, so both numbers
## below were dead, and every jump in this project has opened with the 0.50 s
## squat this comment says is never seen. `_anim_node` sets the four properties
## it actually takes now. The jump is half a second more responsive than it was,
## which is not a change of intent — it is this comment finally becoming true.
@export var jump_start_offset: float = 0.50
@export var jump_run_start_offset: float = 0.47
## The air slam, which is ONE clip cut into two one-shots — the dive and the
## impact — for the reason clip_air/clip_land are two: the game does not know how
## long the hero will be falling, so a single clip covering both would have to
## guess, and every guess is either a hero who lands out of a strike he never
## finished or one who plants his weapon in mid-air.
##
## Neither the sword-and-shield set nor `extra` has a downward strike in it —
## fifty-two clips of horizontal and diagonal — so this borrows from the axe set
## exactly as the spin does, and for the same reason.
##
## `ax_melee_run_jump_attack` is 3.67 s of run-up, gather, leap, strike, land and
## recovery. The offsets below were read off tools/directors/slam_lookdev.gd,
## which renders the clip at named seconds — NOT off the hips track, which can
## tell you where the body is and nothing at all about where the weapon is:
##
##   1.23  apex, tucked
##   1.50  descending, both arms overhead, blade up — THE DIVE POSE
##   1.70  contact, deep crouch, blade coming down across the body
##   1.83  the bottom of the compression
##   2.75  standing again; after this it is a man holding an axe
@export var clip_slam: StringName = &"ax_melee_run_jump_attack"
@export var slam_start_offset: float = 1.50
@export var slam_land_offset: float = 1.70
## The three steps of the light chain. Three DIFFERENT clips, not one replayed:
## a combo whose every hit is the same swing reads as a stutter, and the whole
## point of a chain is that the player can see how far into it they are.
##
## Chosen off the render, and chosen as a SEQUENCE: 01 comes down on the diagonal
## and ends low, 03 sweeps back up from there, 04 is a leaping overhead slam that
## finishes on one knee. Down, up, over — each one starts where the last ended,
## which is what makes three clips read as one sentence instead of three swings.
@export var clip_attack: StringName = &"ss_slash_01"
@export var clip_light2: StringName = &"ss_slash_03"
@export var clip_light3: StringName = &"ss_slash_04"
## The charged release: a full 360 spin, Zelda's. It is a DIFFERENT clip, not a
## slash time-scaled down — slowing ss_slash_01 to 0.9 s reads as the hero being
## tired, not as a blow that weighs something.
##
## It is also the only clip the hero plays that is not from the sword-and-shield
## set. That set has no 360 in it, so this is borrowed out of the axe moveset a
## clip at a time (tools/build_anim_lib.gd §ONLY) and trimmed to the sweep
## (§TRIM). PICKED OFF THE RENDER against the project's other two spins — see
## tools/directors/swing_lookdev.gd, where all three were photographed.
##
## The pose is what earns the 360 hitbox: he crouches into the turn and carries
## the blade out at arm's length the whole way round, so the circle the damage
## claims is a circle you can see him cut.
@export var clip_spin: StringName = &"ax_melee_attack_360_low"
## Seconds into `clip_attack` that the charge holds on. This is a FRAME PICKED
## OFF THE RENDER, not a fraction of the clip: see tools/directors/charge_pose.gd,
## which photographs the whole slash and then the live hold, because "the bottom
## of the swing" is a thing you can see and not a thing you can compute. It wants
## the frame where the follow-through has carried the blade out to his left and
## the shoulders have not started coming back yet.
@export var charge_pose_time: float = 0.70
## Seconds to ease the hold pose in and out of. Slower than the shield's, because
## the pose is arrived at out of a swing that is still finishing — snapping into
## it reads as the swing being cut off rather than settling.
@export var charge_pose_fade: float = 0.18
## The lock-on lunge. ss_attack_01 is the one clip in the library where the hero
## leaves the ground — a leap straight up into a downward slam that lands on one
## knee. That is why it made a terrible heavy (it shipped as one for a day and
## looked like a physics bug) and exactly the right leap at a locked target.
@export var clip_lunge: StringName = &"ss_attack_01"
## The dash attack — the stab out from behind the raised shield. Also PICKED OFF
## THE RENDER (tools/directors/dodge_lookdev.gd): ss_attack_03 coils low with the
## blade drawn back across the body, explodes into a deep split-legged lunge with
## the point extended straight down the facing, and recovers into the guard. It
## is the only clip in the library whose blade goes FORWARD rather than across —
## every `slash` is an arc, and an arc played on a lunge reads as a man swinging
## at the air beside the thing he just closed on.
@export var clip_dash: StringName = &"ss_attack_03"
## The parry. **It IS a block clip**, and the comment that used to sit here said
## the opposite in as many words — "NOT one of the two `ss_block_*` clips, which
## are a body absorbing something; this one is a body going to meet it".
##
## `tools/_clip_shield.gd` prints `ex_parry` and `ss_block_02` side by side and
## they agree to three decimals on every sample: 0.076 m of forearm excursion,
## 0.520 m/s peak, 0.070 m of hips rise. They are one Mixamo take exported under
## two filenames, and the filename is the whole of what the old comment was
## reasoning from. That is CLAUDE.md §4's rule about facing, in a different
## costume: the answer is in the render, not in the metadata.
##
## THE LIBRARY HAS NO SHIELD BASH. Every clip in `hero_anims.res` was ranked by
## left-forearm speed and the best forward extension of the shield arm anywhere
## in it is ~0.11 m (`bow_punch`, whose headline 3.67 m/s is the arm being pulled
## back ACROSS the body, not thrust out). So this is not a pick that can be
## improved by picking again, and it is left pointing at `ex_parry` on purpose:
## the raise it does play is a fine FIRST half. What it has no second half of is
## supplied by `_bash_pose` below, which is `Enemy._tick_windup`'s answer to the
## identical problem — that file's comment opens "the animation cannot carry
## this on its own and it never could".
##
## Card #89 holds the other option, which is sourcing a real bash clip.
@export var clip_parry: StringName = &"ex_parry"
## How far forward the MODEL is driven on a parry, in metres, and how far it
## pitches into the shove. See `_bash_pose`.
##
## The model and not the body: `request_parry` zeroes the velocity on purpose
## (a parry that closed distance would be strictly better than the dash at the
## dash's own job), so this has to read as commitment without being travel.
## 0.26 m is about a shield's width and it is the number the render was checked
## at — far enough to be a lunge from the game camera, near enough that the hero
## does not visibly detach from the capsule the world collides against.
@export var parry_bash_reach: float = 0.26
@export var parry_bash_pitch: float = 16.0
## The flurry attack — the leaping overhead the perfect dodge opens. A full
## crouch, a launch, a fall with the blade held overhead, a strike, and a
## landing on one knee with the point in the ground.
##
## It is a SECOND leaping strike in a library that already had two, and it earns
## the slot rather than duplicating them: `clip_lunge` (ss_attack_01) is a
## standing hop under a lock and `ax_melee_run_jump_attack` is cut to start
## mid-descent because the SLAM's leap is a real jump the player already made.
## This one carries its own anticipation and its own landing, which is exactly
## what a move thrown from a standing start out of slow-motion needs and what
## neither of the other two has.
@export var clip_flurry: StringName = &"ex_jump_attack"
## A bow shot is TWO clips, not one, and they fire from two separate one-shots.
##
## It was one for a while — `bow_aim_recoil` alone, time-scaled across the whole
## draw window — on the reasoning that the aim stance already holds him at full
## draw, so there was nothing left to pull. Rendered, that is not what it looks
## like. `bow_aim_recoil` is 0.70 s of loose-and-follow-through: the string hand
## snapping open past his ear and the arms settling. Stretched over a 0.44 s
## commitment it is the RECOVERY played in slow motion, and the shot has no
## wind-up at all — the arrow leaves 0.24 s into a clip that has not yet done
## anything a bow does. Every other committed move in this file (see
## `_SWING_FADE_IN`) is priced on its wind-up being legible; the bow was the one
## that had none.
##
## So: `bow_draw_arrow` (1.03 s — reach over the shoulder, nock, pull to full
## draw) is the charge, `bow_aim_recoil` is the loose, and the arrow leaves at
## the SEAM between them. The two clips abut cleanly because the first ends on
## exactly the pose the second opens on, which is why this pair and not, say,
## `bow_shoot_*`.
@export var clip_bow_draw: StringName = &"bow_draw_arrow"
## The loose. Opens at full draw — where `clip_bow_draw` left him — and snaps the
## string arm back.
@export var clip_bow_shot: StringName = &"bow_aim_recoil"
## Firing the hookshot. A brace-and-punch with the barrel out front, from
## Shooting.fbx; the bow clips would have him loosing an arrow off a grapple.
@export var clip_hook_shot: StringName = &"ex_hookshot_fire"
## The held aim, and the two ends of the aim-walk blend. These are what the
## over-the-shoulder stance looks like: `bow_aim_overdraw` is a sustained pull at
## full draw, and the aim-walk clips carry the bow through a step instead of
## sliding a statue across the floor.
@export var clip_aim_idle: StringName = &"bow_aim_overdraw"
@export var clip_aim_walk: StringName = &"bow_aim_walk_forward"
## Seconds the aim stance takes to blend in and out. Matches K.CAM_AIM_BLEND so
## the body and the camera arrive at the shoulder together.
@export var aim_fade: float = K.CAM_AIM_BLEND
@export var clip_block: StringName = &"ss_block_idle_01"
## Seconds the shield takes to come up and go down. Fast enough to be a
## reaction, slow enough that you can see it happen.
@export var block_fade: float = 0.12

## The seated pose he eats a ration in (`docs/METAGAME.md` §6.4). A HELD pose, so
## it blends rather than fires — the same arrangement `clip_block` gets, for the
## same reason: a one-shot would end on its own while the meal was still running.
##
## `ss_crouch_idle_01` is the library's only settled-on-the-ground loop and it is
## a placeholder with a real job. What the pose has to do is say *he is not
## fighting and he is not going anywhere*, from the game camera, in the corner of
## the player's eye, and a low crouched idle says it. A proper sit is one word
## change here and a re-import; nothing downstream reads the clip's name.
@export_group("Taking a hit")
## The two flinches and the knockdown pair. Card #130: the hero's outgoing blows
## have had four juice passes and the incoming direction had none, so none of
## these four clips had a reader -- `ss_impact_01/02/03` have been sitting in
## `hero_anims.res` unused since the library was first baked.
##
## LIGHT and HEAVY are the owner's own labelling of the sword-and-shield pack's
## two reactions; `ss_impact_01` is the third and is deliberately not wired,
## because two flinches that read as one flinch is worse than one.
@export var clip_flinch_light: StringName = &"ss_impact_02"
@export var clip_flinch_heavy: StringName = &"ss_impact_03"
@export var clip_knocked_down: StringName = &"ex_knocked_down"
@export var clip_getting_up: StringName = &"ex_getting_up"
## Seconds of `clip_getting_up` that are never played -- the same trick
## `jump_start_offset` and `_SWING_START_OFFSET` use, for a related reason.
##
## The clip opens with 0.30 s of the actor lying still before he starts to move
## (hips flat at 0.063, read off tools/_clip_hips.gd). The hero has ALREADY been
## lying still for `K.KNOCKDOWN_DOWN_TIME` by the time this fires, and playing
## that opening again is the rise visibly failing to start on the frame the game
## says it has. Trimmed at the far end instead, in build_anim_lib's TRIM table,
## because a tail is a tail wherever you cut it and a head is a delay.
@export var getup_start_offset: float = 0.28

@export_group("Stances")
@export var clip_rest: StringName = &"ss_crouch_idle_01"
## The full-body lift used by the item-get ceremony. It sits above Rest as a
## one-shot so the presentation pose wins over every locomotion or held stance.
@export var clip_item_get: StringName = &"ss_power_up_01"
## Seconds the seated pose takes to fold down into and to come up out of.
##
## Slower than the shield's 0.12 on purpose, and it is the only fade in this file
## tuned to be slow. Sitting down is the one thing the hero does that the player
## must never read as instant: the whole item is that eating costs you the twelve
## seconds AND the two beats at either end of it, and a hero who snapped into a
## crouch and back could be eaten mid-corridor with no felt cost at all.
@export var rest_fade: float = 0.30
## Speeds, in m/s, the walk and run clips are authored to read as.
@export var walk_blend_speed: float = K.WALK_SPEED
@export var run_blend_speed: float = K.RUN_SPEED
## The sprint's own clip and its point on the same speed axis. `ex_fast_run` has
## been sitting unused in the library since the day it was imported; it is a
## 0.53 s cycle against the run's 0.70 s, so the cadence comes from the CLIP
## rather than from playing the run faster, which is what stride-scaling a run
## into a sprint always looks like — a man doing the same thing on fast-forward.
##
## Adding it as a fourth blend point keeps §3.2 intact: one continuous curve of
## idle -> walk -> run -> sprint, still no branch anywhere in the locomotion.
@export var clip_sprint: StringName = &"ex_fast_run"
@export var sprint_blend_speed: float = K.SPRINT_SPEED
## Playback rate applied to the locomotion blend at a standstill and at the run
## cap. Keeps the feet from skating at in-between speeds.
@export var stride_scale_idle: float = 1.0
@export var stride_scale_run: float = 1.06

@export_group("Sprint")
## Top speed while the dodge button is held. See K.SPRINT_SPEED for why it is
## deliberately slower than a roll.
@export var sprint_speed: float = K.SPRINT_SPEED
## The tap window. `context` released inside it is a DODGE; still down when it
## expires, the press is a RUN and will never be a dodge, however it ends.
## Elden Ring's arrangement — tap to roll, hold to sprint, one button — and this
## is the *measuring* of it, which is the half that was missing.
##
## An earlier pass fired the dodge on the press and let the sprint start
## underneath it, on the reasoning that waiting to classify a press would put
## this much latency on the most reaction-critical button in the game. That is
## true, and the cost it bought was worse: every run in the game began with an
## involuntary roll, which spends a third of the stamina bar the run is about to
## need and throws the hero 3.2 m in whatever direction he happened to be
## pointing. You cannot start running without dodging first.
##
## The latency argument survives where it actually applies. `_context_resolves_now`
## fires the press INSTANTLY in every stance a run is withheld from — locked,
## guarding, aiming, airborne — so the reaction-critical dodge, the one you make
## with a sword coming at you, still costs nothing. Only the free-roam dodge,
## which you make out of a run against no immediate threat, waits to be
## classified. The window is one number and not two on purpose: the frame the
## sprint begins is the frame the dodge stops being possible, so there is no
## band in which a press means neither.
@export var sprint_hold_time: float = 0.18
## Stamina per second, spent while running. The bar is the whole limit on it —
## there is no separate sprint meter, so a run and a dodge come out of the same
## pocket and a player who sprints everywhere arrives with nothing to dodge on.
@export var sprint_stamina_rate: float = K.STAMINA_SPRINT
## Fraction of the bar that must come back before an exhausted run can restart.
## Without it a held button re-starts the sprint the instant one frame's worth of
## stamina regenerates, and the hero stutters between running and not.
@export var sprint_recover01: float = 0.25

@export_group("Footsteps")
## Metres of ground covered per footfall at walk speed and at the run cap.
@export var stride_walk: float = 0.72
@export var stride_run: float = 1.55

## Set by P3 when it parents a targeting node under the hero. Read-only here.
## docs/CONTRACT.md §8 — `get_first_node_in_group("player").targeting`.
var targeting: Node = null

var state: MoveState = MoveState.GROUND
## Which of the three reactions the blow in progress rolled. Only meaningful
## while `state == MoveState.HURT`; LIGHT never gets there (see `_enter_hurt`).
var _hurt_tier: Hit.Tier = Hit.Tier.HEAVY
## Has the knockdown handed over to the rise yet? The knockdown is two clips and
## one state -- the slam's arrangement, and for the slam's reason: they are two
## halves of one move, and a second MoveState for the second half would be a
## state that can only ever be reached from one place.
var _hurt_rising: bool = false
## Which way the blow threw him, world space and flat. `_tick_hurt` bleeds the
## residual speed along THIS and not along `_bleed_dir()`, which returns the
## hero's FACING when he is neither locked on nor guarding -- and his facing
## points at whatever just hit him, so bleeding along it would walk a staggered
## man back into the boss that staggered him.
var _hurt_dir: Vector3 = Vector3.ZERO
var facing_yaw: float = 0.0
## Set by HeroCombat while the shield button is held. Read-only elsewhere.
var blocking: bool = false
## Set by HeroCombat while the attack button is held for the spin. Read-only
## elsewhere. It drives the held wind-up pose and nothing else — whether the hold
## has ARMED is `HeroCombat.charged`, which is a different question.
var charging: bool = false
## True while the dodge button has been held past `sprint_hold_time` and the bar
## is paying for it. Public because the HUD and the camera both want to know the
## hero is running.
var sprinting: bool = false

## True for exactly ONE frame: the frame on which a press of `context` has
## resolved as a dodge rather than a run. Set by `_tick_context`, which is the
## only thing in the project that reads the raw button; `_try_start_roll` reads
## this instead, because a second opinion on how long a button was held is how a
## press comes out as two moves on one frame, or as neither.
##
## It had a second reader — the jump attack, back when that was the same button
## behind a guard. That is on the trigger now and reads its own press.
var context_tapped: bool = false

## The sword, shield and swing. Built in _ready; other packages reach combat
## through the hero rather than reaching into the scene tree for it.
var combat: HeroCombat = null

## The bow and the hookshot. Built here for the same reason combat is: an item
## bound to a D-pad button has to work in every scene that spawns a hero, and
## half the rooms in this project build theirs in code.
var ranged: HeroRanged = null

## The way out, carried on his belt. Built here for the same reason combat is:
## every scene that spawns a hero must spawn one who can leave.
var rope: EscapeRope = null

## Looking around out of his own eyes (GameCamera.set_first_person). He does not
## steer while it is up and his model is not drawn — the lens is inside his head,
## and half of what it would render is the back of his own face.
var _first_person: bool = false

## The block he has hold of, or null. Set by `grip_push` — see the shoulder
## section for what having hold of one costs him.
var _grip: Node3D = null
## The cardinal heading INTO the gripped block. Not re-derived per frame: the
## grip is the promise that the shove keeps going the way it started, and a
## direction taken live off the stick would let a player rotate a block round a
## corner without ever letting go.
var _grip_axis: Vector3 = Vector3.ZERO
## How fast the block walks. The BLOCK's number, handed over at the grip, so the
## two cannot drift apart — a hero who walked faster than the stone would spend
## every slide with his chest inside it.
var _grip_speed: float = 0.0

var _model: Node3D
## The parry's shove, held so it can be killed. See `_bash_pose`.
var _bash: Tween = null
## Where that shove starts from and returns to. Captured in `_build_rig`.
var _bash_rest: Vector3 = Vector3.ZERO
var _rig: Node3D
var _anim_player: AnimationPlayer
var _tree: AnimationTree
var _state_timer: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
## Whether the roll in flight was started from a stance that pins the facing —
## a lock, or a raised guard. Captured at the start because the shield DROPS for
## the roll, so the live flag says the opposite of what the dodge was.
var _roll_keeps_facing: bool = false
## Which of the four the dodge in flight is, and how fast it travels. The speed
## is stored rather than re-derived each tick because `_tick_roll` holds it flat
## for the whole move, and re-reading it off the direction would need the facing
## the dodge started with — which is exactly what `_roll_keeps_facing` exists to
## remember and exactly the bug it was written for.
var _dodge: int = Dodge.FORWARD
var _dodge_speed: float = 0.0
## Radians the MODEL is turned away from the body, and the whole trick behind a
## sideways roll. Locked or guarding, the BODY has to keep watching the target
## for the whole dodge — that is what the stance is — while the dive itself has
## to point where he is actually travelling. Those are two different directions,
## so they get two different nodes: `rotation.y` stays on the target and the
## model carries the difference. Unwound over `dodge_unwind_deg` once the roll is
## over, which is what makes him stand back up facing the thing he dodged.
var _dodge_model_yaw: float = 0.0
var _airborne_time: float = 0.0
## Upward velocity waiting to be applied, in m/s. A jump CANNOT write velocity.y
## directly: _apply_gravity runs after the state ticks and would clamp it away.
## See the note there — this is the channel that survives it.
var _jump_impulse: float = 0.0
## Seconds a `jump` press stays live. See `jump_buffer_time`.
var _jump_buffer: float = 0.0
## Whether the airborne pose has already been fired for the stretch of air the
## hero is currently in, so the coyote-time crossing in _after_move cannot fire
## a second one on top of a jump that already played its own.
var _air_fired: bool = false
## True from a deliberate jump's launch until it lands. What it gates is the
## LANDING: the jump clips carry their own touchdown, so `Land` must not fire on
## top of one. A fall the hero did not choose has no such clip and still does.
var _jumping: bool = false
## Which of the two jump one-shots is the one in flight, so the landing cut
## (`jump_land_time`) fades out the node that is actually playing. Read rather
## than re-derived from speed: `_fire_jump` chooses off the speed at LAUNCH, and
## by touchdown that speed is whatever the player did in the air.
var _jump_param: String = ""
## Seconds left of the post-touchdown hold before the jump clip's landing tail is
## faded out. Negative means there is nothing to cut. See `jump_land_time`.
var _jump_cut: float = -1.0
## Seconds of HANG left before the slam's drive starts. Above zero the hero is
## held at exactly his commit height; at zero he starts falling at `slam_speed`.
var _slam_hang_left: float = 0.0
## True once a slam has touched down: the state is then running out
## `slam_recover` on the floor and must not keep driving itself into it.
var _slam_landed: bool = false
## Seconds `context` has been held unbroken. The tap/hold split reads this.
var _context_held: float = 0.0
## True while the press in progress could still turn out to be a dodge. Cleared
## the moment it becomes a run, is claimed by a Prompt, or is spent — so a press
## can be paid out exactly once, and a press that became a run cannot cash in as
## a dodge when the button finally comes up.
var _context_armed: bool = false
## Last frame's raw button state, so the press EDGE survives a physics frame that
## `is_action_just_pressed` missed. The harness drives the button with
## `Input.action_press` from a render frame (CLAUDE.md §3) and the window renders
## uncapped, so both a doubled and a dropped just-pressed are real here.
var _context_down: bool = false
## NOTE for the next person who measures a jump and finds it short: it is not
## `floor_snap_length`. 0.45 m of snap looks exactly like the culprit — it is
## enough to swallow the last 0.08 s of the descent — and it is not, because
## Godot does not snap a body that left the floor travelling upward. This was
## A/B'd frame by frame with the suppression in and out and the landing frame is
## identical (tools/directors/_jump_trace.gd). Measure the arc before you fix it.
## Set when a sprint ends because the bar ran out, cleared when enough of it has
## come back. See `sprint_recover01`.
var _sprint_winded: bool = false
var _stride_accum: float = 0.0
var _speed: float = 0.0
## The lunge's forward drive: seconds left, which way, and how fast. Kept apart
## from `_speed` because the lunge does NOT bleed — it holds its speed for the
## leap and then stops dead, and folding it into the decel curve would give the
## hero a long powerless glide out of every one.
var _lunge_left: float = 0.0
var _lunge_dir: Vector3 = Vector3.FORWARD
var _lunge_speed: float = 0.0
## Seconds of damage immunity left. See take_hit().
var _invuln: float = 0.0
## Seconds since the current roll STARTED, and whether its perfect dodge has
## already been paid out.
##
## The age is what makes the dodge about timing rather than about being mid-roll:
## a dive travels, so without it an enemy swinging at the floor the hero has
## already left would reward a dodge thrown half a second early. See
## `K.DODGE_GRACE` and `take_hit`.
##
## Once per roll, because a pack is the common case: three goblins committing
## together would otherwise pay out three slow-motions inside one dive, and the
## second and third would be free.
var _roll_age: float = 0.0
var _perfect_spent: bool = false

const _P_BLEND := "parameters/Loco/blend_position"
const _P_STRIDE := "parameters/LocoScale/scale"
const _P_TURN := "parameters/Turn180/request"
const _P_AIR := "parameters/Air/request"
const _P_LAND := "parameters/Land/request"
const _P_JUMP := "parameters/Jump/request"
const _P_JUMP_RUN := "parameters/JumpRun/request"
const _P_SLAM := "parameters/Slam/request"
const _P_SLAM_SCALE := "parameters/SlamScale/scale"
const _P_SLAM_LAND := "parameters/SlamLand/request"
## The four incoming-hit one-shots. Card #130.
const _P_FLINCH_L := "parameters/FlinchLight/request"
const _P_FLINCH_L_SCALE := "parameters/FlinchLightScale/scale"
const _P_FLINCH_H := "parameters/FlinchHeavy/request"
const _P_FLINCH_H_SCALE := "parameters/FlinchHeavyScale/scale"
const _P_KNOCKDOWN := "parameters/KnockDown/request"
const _P_KNOCKDOWN_SCALE := "parameters/KnockDownScale/scale"
const _P_GETUP := "parameters/GetUp/request"
const _P_GETUP_SCALE := "parameters/GetUpScale/scale"
const _P_SLAM_LAND_SCALE := "parameters/SlamLandScale/scale"
## One animation-tree node per Dodge value, in enum order — same arrangement as
## _SWING_NODES below, and for the same reason (see _add_scaled_shot).
const _DODGE_NODES: Array[StringName] = [
	&"Roll", &"RollBack", &"RollLeft", &"RollRight",
]
## The roll gets the widest fade of the four: it is the longest move and the one
## that ends lying down, so snapping out of it pops the hero upright. The hops
## are quick steps and a slow fade on a quick step reads as lag.
const _DODGE_FADE_IN: Array[float] = [0.05, 0.05, 0.04, 0.04]
const _DODGE_FADE_OUT: Array[float] = [0.16, 0.14, 0.12, 0.12]
## NOTE: the backflip's dead tail is cut at BAKE time, in build_anim_lib's TRIM
## table, not here. `_fire_dodge` scales `clip_len / duration` so the one-shot
## ends exactly when the dodge does; trimming at this end would shorten the
## factor without shortening the clip, and the hero would stand in the clip's
## settle pose for 0.4 s after the game had already handed him back to
## locomotion. The invariant is *the clip's length is the move's length*.
## One animation-tree node per Swing value, in enum order. Indexed by `Swing`,
## so anything added to the enum has to be added here too — which is the point:
## a swing with no node fails loudly at build rather than silently not playing.
const _SWING_NODES: Array[StringName] = [
	&"Swing1", &"Swing2", &"Swing3", &"SwingSpin", &"SwingLunge", &"SwingDash",
	&"SwingParry", &"SwingFlurry",
]
## Fades, in seconds, per Swing. The mid-chain lights are the tightest because a
## chain that fades between steps reads as lag.
##
## The SPIN and the DASH share the tightest fade-in of the lot, for the same
## reason: their wind-up already happened. The dash comes out of a raised guard,
## a committed pose the player chose to be in; the spin comes out of a hold the
## player spent `charge_time` on, with a glowing blade saying so the whole time.
## Easing into either one spends the release on a blend — which on the spin is
## the worst place to spend it, because the first thing the clip does is turn,
## and a turn eased out of locomotion reads as the hero losing his footing.
##
## The PARRY has the tightest fade-in in the file, and it is the one place where
## that is a correctness question rather than a feel one: the move is live for
## `K.PARRY_WINDOW` (0.20 s), so a 0.06 s ease would spend nearly a third of the
## active window on a blend out of the guard pose. The player has to be able to
## see, on the frame they pressed, that the shield went out.
## The FLURRY is the loosest, for the opposite reason: it comes out of a dodge's
## recovery in slow-motion, where there is time to see the hero gather.
const _SWING_FADE_IN: Array[float] = [0.06, 0.04, 0.05, 0.04, 0.08, 0.04, 0.02, 0.09]
const _SWING_FADE_OUT: Array[float] = [0.16, 0.12, 0.18, 0.22, 0.20, 0.18, 0.14, 0.22]
## Seconds of each swing clip that are never played, indexed by Swing. This is
## the jump's trick (`jump_start_offset`) applied to the sword, and it is here
## for the same reason: the clip opens with an anticipation the game has no
## window for, and the choice is to skip it or to pay for it in input latency.
##
## Mixamo swings spend a THIRD TO A HALF of their length winding up. Compressing
## a clip onto `swing_time` does not fix that — it scales the anticipation down
## with everything else and keeps it at the same fraction of the swing. Measured
## with tools/_clip_windup.gd (the sword hand's travel in hips space; total bone
## rotation cannot see a wind-up, because a wind-up is bones moving briskly in
## the wrong direction), ss_slash_01 does not begin to STRIKE until 0.50 s of its
## 1.50 s, which at swing_time 0.60 put 0.20 s between the button and the blade.
## That is what "the swing feels laggy" was.
##
## Each number is picked so the blade starts travelling on the frame the HITBOX
## GOES LIVE — offset = (strike - f*len) / (1 - f), where f is the swing's
## `damage_window.x`. Before this the lights damaged things ~0.07 s before the
## sword visibly moved, which is the same bug seen from the other side.
##
##   swing   clip                     len   strike  live at  offset
##   LIGHT1  ss_slash_01             1.50    0.50    0.22     0.22
##   LIGHT2  ss_slash_03             1.67    0.73    0.22     0.46
##   LIGHT3  ss_slash_04             2.43    1.23    0.22     0.47*
##   SPIN    ax_melee_attack_360_low 1.35    0.73    0.34     0.41
##   LUNGE   ss_attack_01            2.33    0.93    0.46     0.00*
##   DASH    ss_attack_03            1.73    0.70    0.34     0.17
##
## * The two exceptions, and both are exceptions for the same reason — the
## formula is blind to the BODY, and these are the two clips whose body leaves
## the floor. LIGHT3's answer came out at 0.89, which is up at the top of the
## leap: the swing would have begun with the hero already airborne, popping
## 0.25 m upward on the first frame. 0.47 is where the launch crouch bottoms out
## (tools/_clip_hips.gd), so the leap survives intact and only the draw-back
## before it is cut. LUNGE needs no cut at all — ss_attack_01 already strikes at
## 0.40 of its length against a window that opens at 0.46, so it is the one clip
## in the set whose blade moves BEFORE it can hurt anything.
##
## Every offset was checked against the hips track for exactly the pop that
## caught LIGHT3: none of these starts more than 0.03 m off standing height.
##
## The two additions are the two places the formula does not apply, and for
## opposite reasons:
##
##   PARRY   has no damage window at all, so there is no `f` to solve for. What
##           it has instead is `K.PARRY_WINDOW`, which is live on the frame of
##           the press — so the number wanted is simply "where does the shield
##           start going forward", and that is 0.08 (`ex_parry` holds a braced
##           crouch for two frames before the hips begin to climb). Cutting more
##           than that pops the body 0.09 m upward on the first frame.
##   FLURRY  needs NO cut, like the lunge, and for the same reason plus a
##           better one. `ex_jump_attack` strikes at 1.20 of its 2.10 — 0.57 of
##           its length — and `flurry_damage_window` is set to 0.57 to match,
##           rather than the offset being solved to fit a window picked first.
##           That direction round is what keeps the anticipation crouch: it runs
##           to 0.37 and skipping into it would launch the hero from a pose that
##           is already 0.09 m off the floor. A wind-up you can see is worth
##           keeping on the one move in the kit that is thrown IN SLOW MOTION.
const _SWING_START_OFFSET: Array[float] = [
	0.22, 0.46, 0.47, 0.41, 0.00, 0.17, 0.08, 0.00,
]

const _P_BOW_DRAW := "parameters/BowDraw/request"
const _P_BOW_DRAW_SCALE := "parameters/BowDrawScale/scale"
const _P_RANGED := "parameters/Ranged/request"
const _P_RANGED_SCALE := "parameters/RangedScale/scale"
const _P_HOOK_SHOT := "parameters/HookShot/request"
const _P_HOOK_SCALE := "parameters/HookScale/scale"
const _P_AIM := "parameters/Aim/blend_amount"
const _P_AIM_HOOK := "parameters/HookAim/blend_amount"
const _P_AIM_BLEND := "parameters/AimLoco/blend_position"
const _P_BLOCK := "parameters/Block/blend_amount"
const _P_REST := "parameters/Rest/blend_amount"
const _P_ITEM_GET := "parameters/ItemGet/request"

## Every button that means "I am not sitting down any more". Spelled out here
## rather than inline in `_tick_meal_cancel` so the list is readable as a list:
## swing, heavy, shield, roll/sprint, jump. All five are the real action names in
## `project.godot` — `attack_heavy` and `parry` are NOT actions and a typo in here
## is a meal that cannot be interrupted by the button it names, which is a defect
## that shows up as "eating is overpowered" and never as an error.
const MEAL_BREAKERS: Array[StringName] = [
	&"attack", &"heavy", &"shield", &"context", &"jump",
]
const _P_CHARGE := "parameters/Charge/blend_amount"
const _P_CHARGE_FREEZE := "parameters/ChargeFreeze/scale"
const _P_CHARGE_SEEK := "parameters/ChargeSeek/seek_request"


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = K.L_PLAYER
	collision_mask = K.L_WORLD
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_block_on_wall = false
	slide_on_ceiling = true
	up_direction = Vector3.UP

	# `facing_yaw` is the HEADING yaw: heading == (sin y, 0, cos y). Godot's node
	# forward is -Z, so the body is rotated by yaw + PI and every other package
	# can read the hero's facing as -global_transform.basis.z like any Node3D.
	facing_yaw = rotation.y + PI
	_build_rig()
	_build_anim_tree()
	# Built here rather than authored into hero.tscn for the same reason combat
	# is: every scene that spawns a hero must get a lockable one, and half the
	# rooms in this project build their hero in code.
	targeting = find_child("Targeting", false, false)
	if targeting == null:
		targeting = Targeting.new()
		targeting.name = "Targeting"
		add_child(targeting)

	# The sword and shield live in their own node, but the hero owns their
	# lifetime so every scene that spawns a hero gets an armed one.
	combat = HeroCombat.new()
	combat.name = "Combat"
	add_child(combat)

	# After combat, and that ordering matters: HeroRanged reads `combat.bow` and
	# `combat.hookshot` to find the muzzle a shot leaves from, and those are
	# mounted in HeroCombat's own _ready.
	ranged = HeroRanged.new()
	ranged.name = "Ranged"
	add_child(ranged)

	rope = EscapeRope.new()
	rope.name = "Rope"
	add_child(rope)

	_build_key_light()

	Bus.first_person_changed.connect(_on_first_person_changed)

	Bus.player_spawned.emit(self)


## The camera moved into his head, or came back out. `GameCamera.set_first_person`
## owns that decision — nothing here toggles it.
##
## Hiding the model hides the sword and shield with it: they hang off bone
## attachments under `_rig`. That is correct rather than incidental, because the
## camera drops out of first person the moment anything is swung, so the hands
## are back before the swing is.
func _on_first_person_changed(on: bool) -> void:
	_first_person = on
	if _model != null:
		_model.visible = not on


## Whether the lens is inside his head. `HeroCombat` asks so the guard can stand
## down in there — see the `want_block` note.
func first_person() -> bool:
	return _first_person


## A short-range lamp that travels with the hero.
##
## "Torches make pools of light and the space between them is dark" is the right
## rule for the ROOM and the wrong rule for the character: between two sconces
## the hero rendered as a featureless black cut-out, and the player cannot read
## a guard or a roll off a silhouette. The range is deliberately under 4 m and
## the light casts no shadows, so it lights him and nothing else -- the room's
## darkness is untouched.
func _build_key_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "KeyLight"
	lamp.light_color = Color(1.0, 0.95, 0.88)
	lamp.light_energy = 2.1
	lamp.omni_range = 4.4
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 1.9, -0.6)
	add_child(lamp)


# --- Rig --------------------------------------------------------------------

func _build_rig() -> void:
	_model = get_node_or_null(^"Model") as Node3D
	if _model == null:
		_model = Node3D.new()
		_model.name = "Model"
		add_child(_model)
	_model.scale = Vector3.ONE * model_scale
	_model.rotation.y = deg_to_rad(model_yaw_offset)
	# Where the parry's shove returns to. Read off the node rather than assumed
	# to be the origin: `Model` may come from the scene with an authored offset
	# (the branch above only builds one when it does not), and a settle that
	# unwinds to a hard zero would silently re-home the rig on the first parry.
	# `Enemy` keeps `_model_rest` for the same reason.
	_bash_rest = _model.position

	_rig = hero_model.instantiate() as Node3D
	_rig.name = "Rig"
	_model.add_child(_rig)

	_anim_player = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		push_error("hero: rig has no AnimationPlayer")
		return
	# The imported FBX ships a stub "" library holding only the T-pose. Evict it
	# so the merged 72-clip library owns the unprefixed namespace.
	# (docs/CONTRACT.md §2)
	if _anim_player.has_animation_library(&""):
		_anim_player.remove_animation_library(&"")
	_anim_player.add_animation_library(&"", anim_library)


## Built in code rather than stored in the .tscn: the animation library is only
## bound at runtime (above), so an editor-authored tree would have no clips to
## reference and every blend point would show as broken.
func _build_anim_tree() -> void:
	if _anim_player == null:
		return
	var tree_root := AnimationNodeBlendTree.new()

	# idle -> walk -> run -> sprint, blended on ground speed in m/s. §3.2:
	# continuous, no walk/run branch — and the sprint joins the same curve rather
	# than becoming a mode, so coming off the button is a decel through the run
	# and not a costume change.
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = sprint_blend_speed
	loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	loco.add_blend_point(_anim_node(clip_idle), 0.0, -1, &"idle")
	loco.add_blend_point(_anim_node(clip_walk), walk_blend_speed, -1, &"walk")
	loco.add_blend_point(_anim_node(clip_run), run_blend_speed, -1, &"run")
	loco.add_blend_point(_anim_node(clip_sprint), sprint_blend_speed, -1, &"sprint")
	tree_root.add_node(&"Loco", loco, Vector2(0, 0))

	var stride := AnimationNodeTimeScale.new()
	tree_root.add_node(&"LocoScale", stride, Vector2(220, 0))
	tree_root.connect_node(&"LocoScale", 0, &"Loco")

	# The aim stances REPLACE locomotion rather than layering over it. A held pose
	# blended on top of a walk cycle is what the shield does, and it is the right
	# answer there because a shield only occupies one arm — a bow at full draw
	# occupies the whole body, and mixing it with a sword-and-shield stride gives
	# a hero drawing a bow with his legs out of a different animation.
	#
	# So the bow gets a second, parallel locomotion blend built out of the longbow
	# set's own clips. Same axis, same units, same `_P_BLEND`-shaped input — see
	# `_drive_animation`.
	var aim_loco := AnimationNodeBlendSpace1D.new()
	aim_loco.min_space = 0.0
	aim_loco.max_space = run_blend_speed
	aim_loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	aim_loco.add_blend_point(_anim_node(clip_aim_idle), 0.0, -1, &"aim_idle")
	aim_loco.add_blend_point(_anim_node(clip_aim_walk), walk_blend_speed, -1, &"aim_walk")
	# The pack has no aim RUN — you do not sprint at full draw. Reusing the walk
	# at the run end keeps the blend defined across the whole axis; the stride
	# scale in `_drive_animation` is what stops the feet skating.
	aim_loco.add_blend_point(_anim_node(clip_aim_walk), run_blend_speed, -1, &"aim_run")
	tree_root.add_node(&"AimLoco", aim_loco, Vector2(220, 400))

	var aim_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"Aim", aim_blend, Vector2(340, 0))
	tree_root.connect_node(&"Aim", 0, &"LocoScale")
	tree_root.connect_node(&"Aim", 1, &"AimLoco")

	# The hookshot gets its OWN stance, and it has to. Held in the bow's stance he
	# aims a grapple pistol with an archer's draw — both hands up beside his ear,
	# torso wound ninety degrees off the shot — and the giveaway is the longbow
	# slung on his back, which is pinned to Spine2 and swings out into open air
	# with the twist. It looked like the bow had come unstuck from the model. It
	# had not; he was drawing an invisible bow around it.
	#
	# One clip, held, rather than a blend: the pack has no hookshot walk, and a
	# brace is a brace whether or not the feet are moving.
	var hook_pose := _anim_node(clip_hook_shot)
	hook_pose.loop_mode = Animation.LOOP_LINEAR
	tree_root.add_node(&"HookAimAnim", hook_pose, Vector2(220, 600))
	var hook_aim := AnimationNodeBlend2.new()
	tree_root.add_node(&"HookAim", hook_aim, Vector2(460, 0))
	tree_root.connect_node(&"HookAim", 0, &"Aim")
	tree_root.connect_node(&"HookAim", 1, &"HookAimAnim")

	# One-shots layered over the locomotion, cheapest first. Land is last so a
	# landing always reads over whatever else is still fading out. They sit above
	# the stances so a roll or a hit reaction still reads while the bow is out.
	var prev := &"HookAim"
	prev = _add_oneshot(tree_root, &"Turn180", prev, _anim_node(clip_turn180), Vector2(440, 0), 0.10, 0.22)
	prev = _add_oneshot(tree_root, &"Air", prev, _anim_node(clip_air), Vector2(660, 0), 0.10, 0.18)

	# The two jumps sit ABOVE Air, so a deliberate jump reads over a fall that is
	# still fading out. Their fade-in is the tightest in the tree (0.04, the
	# dodges' number) for the dodges' reason: the launch is the entire read, and a
	# jump eased into over 0.10 s has already left the ground by the time the pose
	# arrives. The fade-OUT is long, because what it is fading is the landing
	# recovery back into locomotion, and that one wants to be soft.
	prev = _add_oneshot(tree_root, &"Jump", prev,
		_anim_node(clip_jump, jump_start_offset), Vector2(720, 0), 0.04, 0.22)
	prev = _add_oneshot(tree_root, &"JumpRun", prev,
		_anim_node(clip_jump_run, jump_run_start_offset), Vector2(790, 0), 0.04, 0.22)

	# The slam sits above both jumps, because it is what a jump BECOMES: the
	# player is mid-`ex_jump` when he presses attack, and the dive has to read
	# over the leap that is still running rather than under it.
	#
	# Time-scaled, unlike the jumps. A jump's airborne stretch is a fixed 0.60 s
	# and the clip matches it; a slam's is however long the drive takes from
	# wherever the hero happened to be, so `request_slam` measures the drop and
	# sizes both halves to it (see there). Hence _add_scaled_shot's shape, but
	# with the offset nodes _anim_node builds.
	prev = _add_scaled_jump_shot(tree_root, &"Slam", prev, clip_slam,
		slam_start_offset, slam_land_offset - slam_start_offset, Vector2(860, 0), 0.05, 0.14)
	# And the impact above the dive, for the same reason Land sits above Air.
	# Its fade-in is the shortest in the tree: this is the frame the dust and the
	# bang go off on, and a contact pose eased in over even 0.05 s arrives after
	# the thing it is supposed to be causing.
	prev = _add_scaled_jump_shot(tree_root, &"SlamLand", prev, clip_slam,
		slam_land_offset, _clip_length(clip_slam) - slam_land_offset,
		Vector2(930, 0), 0.02, 0.26)

	# Four dodges, four one-shots — not one node whose clip is reassigned, for the
	# reason _add_scaled_shot gives. They chain in Dodge order and they all sit
	# BELOW `Block`, which is load-bearing: the guard is a blend that would
	# otherwise replace whichever dodge is playing, and HeroCombat drops the
	# shield for the dodge precisely because of where these sit.
	#
	# BACK is the one that takes a window instead of a whole clip: `ex_backflip`
	# opens with an anticipation crouch the game has no room for, so it starts at
	# `backflip_start_offset` the way both jumps start at theirs. Everything
	# downstream of that has to agree about which seconds are being played —
	# `_dodge_skip` is the single answer, and `_fire_dodge` sizes the TimeScale
	# off it.
	for i in Dodge.size():
		var skip := _dodge_skip(i)
		if skip > 0.0:
			prev = _add_scaled_jump_shot(tree_root, _DODGE_NODES[i], prev, _dodge_clip(i),
				skip, _clip_length(_dodge_clip(i)) - skip,
				Vector2(880 + 90 * i, 0), _DODGE_FADE_IN[i], _DODGE_FADE_OUT[i])
		else:
			prev = _add_scaled_shot(tree_root, _DODGE_NODES[i], prev, _dodge_clip(i),
				Vector2(880 + 90 * i, 0), _DODGE_FADE_IN[i], _DODGE_FADE_OUT[i])

	# The shield is a HELD pose, so it blends rather than fires: a one-shot would
	# end on its own while the button is still down.
	var block_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"BlockAnim", _anim_node(clip_block), Vector2(1000, 200))
	tree_root.add_node(&"Block", block_blend, Vector2(1100, 0))
	tree_root.connect_node(&"Block", 0, prev)
	tree_root.connect_node(&"Block", 1, &"BlockAnim")
	prev = &"Block"

	# The charged wind-up is a HELD POSE, and it is one frame of the light slash
	# rather than a clip of its own: the bottom of the first swing, blade out to
	# his left, which is where the arm already is when the button stays down. OOT
	# does the same thing — Link finishes the swing and STAYS there, humming, and
	# that held silhouette is the only thing telling you the spin is coming.
	#
	# Frozen with a TimeScale of 0, and parked on the frame with a TimeSeek — NOT
	# with `start_offset`. The offset is what `_anim_node` takes and it is the
	# obvious thing to reach for here, but it is applied when the node STARTS, and
	# a node behind a zero time scale never starts: the pose came out as frame 0
	# of the slash no matter what the number said, which is a hero standing there
	# holding his sword up. The seek is absolute and lands every time.
	#
	# It goes UNDER the swings deliberately. The press that starts the hold also
	# throws a light swing, and that one-shot has to win while it is running —
	# blended in below, the pose is simply what is left when the swing ends, which
	# is exactly the moment the player should see him settle into it.
	tree_root.add_node(&"ChargeAnim", _anim_node(clip_attack), Vector2(1160, 260))
	tree_root.add_node(&"ChargeSeek", AnimationNodeTimeSeek.new(), Vector2(1260, 260))
	tree_root.connect_node(&"ChargeSeek", 0, &"ChargeAnim")
	tree_root.add_node(&"ChargeFreeze", AnimationNodeTimeScale.new(), Vector2(1360, 260))
	tree_root.connect_node(&"ChargeFreeze", 0, &"ChargeSeek")
	var charge_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"Charge", charge_blend, Vector2(1400, 0))
	tree_root.connect_node(&"Charge", 0, prev)
	tree_root.connect_node(&"Charge", 1, &"ChargeFreeze")
	prev = &"Charge"

	# The swings go ON TOP of the block, so a slash reads even if the shield was
	# up the instant before it. One one-shot per variant — see _add_swing for why
	# they are not one node with the clip reassigned.
	#
	# The fades widen as the blow gets heavier. A heavy that snaps into pose has
	# no wind-up to read, and the wind-up is the whole tell the player is being
	# asked to trade commitment for.
	for i in Swing.size():
		prev = _add_scaled_shot(tree_root, _SWING_NODES[i], prev, _swing_clip(i),
			Vector2(1440 + 80 * i, 0), _SWING_FADE_IN[i], _SWING_FADE_OUT[i],
			_SWING_START_OFFSET[i])

	# The three shot clips get one one-shot EACH rather than sharing a node whose
	# clip is swapped. Assigning `animation` on a live AnimationNodeAnimation the
	# same frame it is asked to play restarts the mixer's cache mid-blend and drops
	# the opening frames — which for the bow is the loose itself, the one frame the
	# whole shot is about. They sit above the swings because a bow is never held at
	# the same time as the sword: whichever fired last is the one that should read.
	#
	# The bow's charge goes on FIRST, so the loose above it wins the frame it
	# fires on. Two stacked one-shots and not one node fired twice: the loose has
	# to interrupt a charge that is still fading, and a node cannot cross-fade
	# with itself. The draw's own fade-out is short and almost never seen — the
	# loose is already at full blend over the top of it by the time it runs.
	prev = _add_scaled_shot(tree_root, &"BowDraw", prev, clip_bow_draw,
		Vector2(1760, 0), 0.08, 0.10)

	# The bow's fade-in is very short on purpose. `bow_aim_recoil` starts from the
	# same full draw `clip_bow_draw` just pulled him into, so there is nothing to
	# ease between — a longer fade just delays the string leaving his fingers.
	var ranged_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"RangedAnim", _anim_node(clip_bow_shot), Vector2(1840, 260))
	tree_root.add_node(&"RangedScale", ranged_scale, Vector2(1960, 260))
	tree_root.connect_node(&"RangedScale", 0, &"RangedAnim")
	var ranged_shot := AnimationNodeOneShot.new()
	ranged_shot.fadein_time = 0.03
	ranged_shot.fadeout_time = 0.18
	tree_root.add_node(&"Ranged", ranged_shot, Vector2(1840, 0))
	tree_root.connect_node(&"Ranged", 0, prev)
	tree_root.connect_node(&"Ranged", 1, &"RangedScale")
	prev = &"Ranged"

	var hook_scale := AnimationNodeTimeScale.new()
	tree_root.add_node(&"HookShotAnim", _anim_node(clip_hook_shot), Vector2(1940, 500))
	tree_root.add_node(&"HookScale", hook_scale, Vector2(2060, 500))
	tree_root.connect_node(&"HookScale", 0, &"HookShotAnim")
	var hook_shot := AnimationNodeOneShot.new()
	hook_shot.fadein_time = 0.06
	hook_shot.fadeout_time = 0.16
	tree_root.add_node(&"HookShot", hook_shot, Vector2(1940, 0))
	tree_root.connect_node(&"HookShot", 0, prev)
	tree_root.connect_node(&"HookShot", 1, &"HookScale")
	prev = &"HookShot"

	prev = _add_oneshot(tree_root, &"Land", prev, _anim_node(clip_land), Vector2(2160, 0), 0.06, 0.20)

	# **Taking a hit goes ON TOP of everything he could have been doing**, which
	# is the whole of why these four sit here rather than down beside the swings.
	# A blow arrives while he is mid-slash, mid-draw, mid-landing; the flinch has
	# to win that frame or the player watches his sword finish its arc through the
	# thing that just hit him. Only the seated pose is above them, and being hit
	# ends the meal before it ends anything else (`take_hit` calls
	# `Game.cancel_meal` first), so that blend is already on its way to zero.
	#
	# Four nodes and not one with the clip reassigned, for `_add_swing`'s reason:
	# writing `animation` on a live AnimationNodeAnimation the frame it is asked
	# to play restarts the mixer's cache and drops the opening frames -- which for
	# a flinch is the flinch.
	#
	# The fades widen with the blow. A light flinch that eased in would not read
	# at all inside its 0.28 s; the knockdown can afford 0.10 because the clip
	# opens with a third of a second of reel before the hips start to drop, so the
	# ease lands on the part nobody is looking at yet.
	prev = _add_scaled_shot(tree_root, &"FlinchLight", prev, clip_flinch_light,
		Vector2(2240, 0), 0.03, 0.14)
	prev = _add_scaled_shot(tree_root, &"FlinchHeavy", prev, clip_flinch_heavy,
		Vector2(2320, 0), 0.05, 0.18)
	# The knockdown pair are stacked in the order they play, exactly as the slam's
	# two halves are (`Slam` then `SlamLand`): the rise has to be able to interrupt
	# a fall that is still fading out, and a node cannot cross-fade with itself.
	#
	# `GetUp` carries `getup_start_offset` so the rise begins on the frame the
	# controller says it does -- see the export.
	prev = _add_scaled_shot(tree_root, &"KnockDown", prev, clip_knocked_down,
		Vector2(2400, 0), 0.10, 0.12)
	prev = _add_scaled_shot(tree_root, &"GetUp", prev, clip_getting_up,
		Vector2(2480, 0), 0.06, 0.22, getup_start_offset)

	# The seated pose, and it is the LAST thing in the tree — above the landing,
	# above the swings, above the stances. Every other held pose in here occupies
	# part of him (the shield is one arm, the aim is the upper body); sitting down
	# occupies all of him, and at a blend of 1.0 a Blend2 outputs its second input
	# and nothing else. Anywhere lower and a fading swing or a bow stance would
	# still be showing through a man who is eating a biscuit on the floor.
	#
	# It can afford to be a plain blend rather than a state because nothing can
	# reach it by accident: `Game.eating()` is only true between `begin_meal` and
	# `cancel_meal`, and every input that could contradict the pose calls the
	# second one (see `_tick_meal_cancel`).
	var rest_pose := _anim_node(clip_rest)
	rest_pose.loop_mode = Animation.LOOP_LINEAR
	tree_root.add_node(&"RestAnim", rest_pose, Vector2(2160, 300))
	var rest_blend := AnimationNodeBlend2.new()
	tree_root.add_node(&"Rest", rest_blend, Vector2(2280, 0))
	tree_root.connect_node(&"Rest", 0, prev)
	tree_root.connect_node(&"Rest", 1, &"RestAnim")
	prev = &"Rest"
	prev = _add_oneshot(tree_root, &"ItemGet", prev, _anim_node(clip_item_get),
		Vector2(2400, 0), 0.08, 0.24)

	tree_root.connect_node(&"output", 0, prev)

	_tree = AnimationTree.new()
	_tree.name = "AnimTree"
	add_child(_tree)
	_tree.tree_root = tree_root
	_tree.anim_player = _tree.get_path_to(_anim_player)
	# The library's tracks are authored relative to the FBX root ("Skeleton3D:
	# mixamorig_*"), so the mixer has to resolve from the rig, not from the hero.
	_tree.root_node = _tree.get_path_to(_rig)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_tree.active = true

	# The dodge time-scales are set per FIRE, not here: the four clips are 0.97 to
	# 1.63 s long and the roll runs for longer than a hop, so a single compression
	# factor would be wrong for three of the four. Same arrangement the swings
	# have used since the heavy landed — see _fire_dodge and request_attack.
	for i in Dodge.size():
		_tree.set(_dodge_scale_param(i), 1.0)
	_tree.set(_P_BLEND, 0.0)
	_tree.set(_P_STRIDE, 1.0)
	_tree.set(_P_BLOCK, 0.0)
	_tree.set(_P_REST, 0.0)
	_tree.set(_P_CHARGE, 0.0)
	# 0.0 is what makes the pose a POSE. The clip sits at charge_pose_time and
	# never moves off it.
	_tree.set(_P_CHARGE_FREEZE, 0.0)
	for i in Swing.size():
		_tree.set(_swing_scale_param(i), 1.0)
	for p in [_P_FLINCH_L_SCALE, _P_FLINCH_H_SCALE, _P_KNOCKDOWN_SCALE,
			_P_GETUP_SCALE]:
		_tree.set(p, 1.0)
	_tree.set(_P_AIM, 0.0)
	_tree.set(_P_AIM_HOOK, 0.0)
	_tree.set(_P_AIM_BLEND, 0.0)
	_tree.set(_P_BOW_DRAW_SCALE, 1.0)
	_tree.set(_P_RANGED_SCALE, 1.0)
	_tree.set(_P_HOOK_SCALE, 1.0)


## The clip each Swing plays. A match rather than an array of exports so the
## clips stay individually named in the inspector — `clip_light2` says what it
## is; `swing_clips[1]` needs this file open to read.
func _swing_clip(variant: int) -> StringName:
	match variant:
		Swing.LIGHT2: return clip_light2
		Swing.LIGHT3: return clip_light3
		Swing.SPIN: return clip_spin
		Swing.LUNGE: return clip_lunge
		Swing.DASH: return clip_dash
		Swing.PARRY: return clip_parry
		Swing.FLURRY: return clip_flurry
		_: return clip_attack


## Seconds cut off the FRONT of this dodge's clip. Only the backflip cuts any —
## see `backflip_start_offset`. Read by the tree builder (which sets the node's
## `start_offset`) and by `_fire_dodge` (which must not count skipped seconds
## when it sizes the TimeScale), because a disagreement between those two is the
## bug `_clip_scale`'s `skip` argument exists to prevent.
func _dodge_skip(dodge: int) -> float:
	return backflip_start_offset if dodge == Dodge.BACK else 0.0


## The clip each Dodge plays, same arrangement and same reasoning as _swing_clip.
func _dodge_clip(dodge: int) -> StringName:
	match dodge:
		Dodge.BACK: return clip_roll_back
		Dodge.LEFT: return clip_roll_left
		Dodge.RIGHT: return clip_roll_right
		_: return clip_roll


func _swing_param(variant: int) -> String:
	return "parameters/%s/request" % _SWING_NODES[variant]


func _dodge_param(dodge: int) -> String:
	return "parameters/%s/request" % _DODGE_NODES[dodge]


func _dodge_scale_param(dodge: int) -> String:
	return "parameters/%sScale/scale" % _DODGE_NODES[dodge]


func _swing_scale_param(variant: int) -> String:
	return "parameters/%sScale/scale" % _SWING_NODES[variant]


## A clip node, optionally started `offset` seconds in — which is how both the
## jumps and the swings skip their anticipation. See `jump_start_offset` and
## `_SWING_START_OFFSET` for why an anticipation the game has no window for is
## skipped rather than played, and tools/build_anim_lib.gd's TRIM note for where
## the jump numbers came from.
##
## SETTING `start_offset` ALONE DOES NOTHING, and it does nothing SILENTLY. The
## property is gated behind `use_custom_timeline`: with that off, `start_offset`
## is not even in the node's property list, so assigning it is not an error, does
## not warn, and is simply dropped. `jump_start_offset` was written this way and
## was a dead number for its whole life — every jump has been playing the 0.50 s
## anticipation crouch the comment on it says is never seen. It took an A/B of
## the swings (tools/directors/swing_latency.gd) to catch, because the only
## symptom is the thing looking exactly like it did before. Two sessions found
## this independently and from opposite ends — the jump's tell was the hero
## reaching his apex while the pose was still gathering into the crouch, and
## then performing the whole leap AND its landing standing on the floor 0.50 s
## late (tools/directors/jump_pose_trace.gd traces the pose's hips against the
## body's height on one timeline). Same gate, same silence, both times.
##
## The other three properties are not optional either:
##   timeline_length     defaults to 1.0 — NOT the clip's length. Left alone, a
##                       1.5 s slash is cut off at one second.
##   stretch_time_scale  defaults to TRUE, which squeezes the clip into
##                       timeline_length instead of playing it at its own rate.
##                       The TimeScale node above is what owns pacing here.
##   loop_mode           same gate. The custom timeline OVERRIDES the clip's own,
##                       so a clip that loops would restart under the OneShot
##                       instead of ending — that is the jump leaping a second
##                       time on touchdown. LOOP_NONE, always.
##
## What is left is a node SHORTER than its clip, so anything time-scaling it onto
## a duration has to divide by what remains (`_clip_scale`).
##
## `length` is for the one case that wants a WINDOW rather than a tail: the slam
## cuts two moves out of a single clip, and the first has to stop where the
## second starts. It defaults to "whatever is left after the offset", which is
## what every jump and every swing wants.
func _anim_node(clip: StringName, offset: float = 0.0,
		length: float = -1.0) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	if offset > 0.0 or length > 0.0:
		n.use_custom_timeline = true
		n.start_offset = offset
		var rest := _clip_length(clip) - offset
		n.timeline_length = maxf(rest if length < 0.0 else minf(length, rest), 0.05)
		n.stretch_time_scale = false
		n.loop_mode = Animation.LOOP_NONE
	return n


## Add one time-scaled one-shot: its clip, a TimeScale so the clip can be
## compressed onto the real move duration, and a OneShot layered over `base`.
## Returns the new top of the chain. Every swing and every dodge is one of these.
##
## `start_offset` skips the clip's opening seconds engine-side (see `_anim_node`),
## which makes the node shorter than its clip. Whoever passes one must divide by
## the REMAINING length when they set the TimeScale, or the move ends before the
## clip does — `_clip_scale` takes the same number for that reason.
##
## One node per variant, rather than one node whose `animation` is reassigned:
## assigning the clip on a LIVE AnimationNodeAnimation restarts the mixer's
## cache mid-blend and eats the first frames of the wind-up. That is the most
## expensive kind of animation bug here, because it looks like bad art. It is
## also why the four dodges are four nodes and not one node plus a direction —
## the eaten frames of a dodge are the launch, which is the whole read.
func _add_scaled_shot(tree_root: AnimationNodeBlendTree, id: StringName, base: StringName,
		clip: StringName, pos: Vector2, fade_in: float, fade_out: float,
		start_offset: float = 0.0) -> StringName:
	var anim_id := StringName(String(id) + "Anim")
	var scale_id := StringName(String(id) + "Scale")
	tree_root.add_node(anim_id, _anim_node(clip, start_offset), pos + Vector2(-200, 260))
	tree_root.add_node(scale_id, AnimationNodeTimeScale.new(), pos + Vector2(-80, 260))
	tree_root.connect_node(scale_id, 0, anim_id)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	tree_root.add_node(id, shot, pos)
	tree_root.connect_node(id, 0, base)
	tree_root.connect_node(id, 1, scale_id)
	return id


## One offset slice of a clip, time-scaled, as a one-shot. The two halves of the
## slam are both this: `_anim_node`'s custom timeline picks the SECONDS of the
## clip that are wanted, and the TimeScale in front of it compresses that slice
## onto however long the move actually takes this time.
##
## Kept apart from `_add_scaled_shot` rather than folded into it. That one takes
## a whole clip and is what every swing and dodge uses; this one takes a window,
## and a single function with an optional window is a function whose callers have
## to be read to know which of the two things it is doing.
func _add_scaled_jump_shot(tree_root: AnimationNodeBlendTree, id: StringName,
		base: StringName, clip: StringName, offset: float, length: float,
		pos: Vector2, fade_in: float, fade_out: float) -> StringName:
	var anim_id := StringName(String(id) + "Anim")
	var scale_id := StringName(String(id) + "Scale")
	tree_root.add_node(anim_id, _anim_node(clip, offset, length), pos + Vector2(-200, 340))
	tree_root.add_node(scale_id, AnimationNodeTimeScale.new(), pos + Vector2(-80, 340))
	tree_root.connect_node(scale_id, 0, anim_id)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	tree_root.add_node(id, shot, pos)
	tree_root.connect_node(id, 0, base)
	tree_root.connect_node(id, 1, scale_id)
	return id


func _add_oneshot(tree_root: AnimationNodeBlendTree, id: StringName, base: StringName,
		shot: AnimationNode, pos: Vector2, fade_in: float, fade_out: float) -> StringName:
	var anim_id := StringName(String(id) + "Anim")
	tree_root.add_node(anim_id, shot, pos + Vector2(0, 200))
	var one := AnimationNodeOneShot.new()
	one.fadein_time = fade_in
	one.fadeout_time = fade_out
	tree_root.add_node(id, one, pos)
	tree_root.connect_node(id, 0, base)
	tree_root.connect_node(id, 1, anim_id)
	return id


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)

	# A screen owning input means the hero reads NEUTRAL, not that he stops
	# being simulated -- he still falls, still slides to a halt, still finishes
	# a roll. Without this the shop's confirm key (space) is also the dodge key,
	# and every purchase throws the hero across the garrison square behind the
	# panel. Leaving roots him, by the same mechanism and for a related reason:
	# the rope's channel is only a decision if walking out of it is not free. He
	# still falls and still slides to a halt, he just does not steer. First
	# person roots him for the same reason the rope's channel does: it is a
	# stance you have chosen to stand still in. It is also the honest one -- his
	# model is hidden while the lens is inside his head, so a hero who could
	# walk in here would be an invisible hero walking.
	var busy := (Prompt != null and Prompt.blocked) \
		or (rope != null and rope.active()) \
		or _first_person
	# EATING roots him by the same mechanism and for the rope's exact reason: a
	# channel is only a decision if walking out of it is not free. The difference
	# is what "walking out" costs — the rope breaks, and a meal simply STOPS, with
	# whatever ticks already paid kept and the rest of the biscuit gone
	# (`Game.begin_meal`). `_tick_meal_cancel` is the half that notices.
	#
	# Cancelled BEFORE `locked` is read, so the frame the player pushes the stick
	# is the frame he stands up and starts moving, rather than one where he is
	# still rooted with the meal already over.
	_tick_meal_cancel(busy)
	var locked := busy or Game.eating()

	# Everything that is not standing on the floor in control of himself lets go
	# of the block, in one line and BEFORE the state match, so a roll, a swing, a
	# jump, a hookshot, a shop screen and a hit all break the grip through the
	# same door. Written as a release inside each of those instead, it would be
	# seven places to remember and the eighth would be the one that shipped.
	if _grip != null and (locked or state != MoveState.GROUND or not is_on_floor() \
			or not is_instance_valid(_grip)):
		_drop_grip()

	var stick := Vector2.ZERO if locked \
		else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mag := clampf(stick.length(), 0.0, 1.0)
	var wish := _camera_relative(stick)

	# Both button clocks run OUTSIDE the state match, and both have to. The jump
	# buffer exists precisely to survive the frames the hero is not free, and the
	# A button's clock has to keep counting through a state that cannot act on it
	# — a press made during an attack recovery is still a press whose LENGTH
	# decides what it meant (see `sprint_hold_time`).
	_tick_jump_buffer(delta, locked)
	_tick_context(delta, locked)

	match state:
		MoveState.GROUND:
			_tick_ground(wish, mag, delta)
		MoveState.TURN180:
			_tick_turn180(delta)
		MoveState.ROLL:
			_tick_roll(delta)
		MoveState.ROLL_RECOVER:
			_tick_roll_recover(wish, mag, delta)
		MoveState.ATTACK:
			_tick_attack(delta)
		MoveState.HOOK:
			_tick_hook(delta)
		MoveState.SLAM:
			_tick_slam(delta)
		MoveState.HURT:
			_tick_hurt(delta)

	# The hookshot flies perfectly straight and so does what it drags
	# (docs/CONTRACT.md §2.5 #8). Gravity applied during the pull would sag the
	# arc, and a hookshot that cannot lift you to a ledge above you is a rope.
	if state != MoveState.HOOK:
		_apply_gravity(delta)
	var pre_fall := velocity.y
	move_and_slide()
	_after_move(pre_fall, delta)
	_drive_animation(delta)


## **Anything that is not sitting still ends the meal.** WoW's rule, and it is the
## whole reason a ration is not simply a cheap potion: the twelve seconds have to
## be twelve seconds of doing nothing, or the item is a heal you press mid-fight
## with extra steps.
##
## Read as RAW input rather than as velocity, and that matters — velocity is zero
## while `locked` is holding him still, so a check on movement would never fire
## and the player would be pinned to the floor pushing a stick that did nothing.
## What ends it is the INTENT to do something else.
##
## The action buttons are polled with `is_action_pressed` rather than
## `just_pressed` for the same reason: a button already held when he sat down is
## still a player who wants to be fighting.
##
## **`use_item` is deliberately NOT in the list**, and it is the one absence worth
## writing down. It is the button that STARTS the meal, and a held press — which
## is every press, for a frame or two — would sit him down and stand him straight
## back up, an item that visibly does nothing. Pressing X again mid-meal is a
## silent no-op instead: `Game.begin_meal` refuses while one is running. Standing
## up is what the stick is for.
##
## `screen` cancels outright and does not wait for input. Opening a shop, taking
## the rope or dropping into first person are all "he is doing something else
## now", and a hero who kept eating through a trade screen would finish the meal
## while the player was reading a price list — which is the free version of the
## item this whole function exists to prevent.
func _tick_meal_cancel(screen: bool) -> void:
	if not Game.eating():
		return
	if screen:
		Game.cancel_meal()
		return
	# The same deadzone the locomotion uses, so "he stood up" and "he started
	# walking" are the same threshold. A drifting pad that could cancel a meal
	# without moving him is the gamepad trap in CLAUDE.md §3 wearing a new hat.
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if stick.length() > 0.2:
		Game.cancel_meal()
		return
	for action: StringName in MEAL_BREAKERS:
		if Input.is_action_pressed(action):
			Game.cancel_meal()
			return


## The one rule that makes a third-person game feel right: the stick is read in
## SCREEN space and rotated by the live camera's yaw. Never world axes.
func _camera_relative(stick: Vector2) -> Vector3:
	if stick == Vector2.ZERO:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return K.flat(Vector3(stick.x, 0.0, stick.y))
	var basis := cam.global_transform.basis
	var fwd := K.flat(-basis.z)
	var right := K.flat(basis.x)
	if fwd == Vector3.ZERO:
		# Camera aimed straight down: fall back to its up vector on the plane.
		fwd = K.flat(basis.y)
	# Stick +Y is "down" on the pad, so forward is -stick.y.
	return K.flat(right * stick.x - fwd * stick.y)


## The locked target, or null. `z_target` itself belongs to Targeting now — the
## hero only ever asks who is being locked, never who pressed what.
func lock_target() -> Node3D:
	if targeting == null:
		return null
	if not bool(targeting.get(&"is_locked")):
		return null
	# **Check, THEN cast.** The other order — which this was — reads
	# `... as Node3D` first, and `as` on a freed instance raises
	# `Trying to cast a freed object` before the `is_instance_valid` it was
	# written to defer to ever runs (issue #59). A cast is not free on a dead
	# reference, and a guard written after one is a guard that never fires.
	# `Targeting` clears `current_target` on `tree_exiting` now, so nothing
	# dangling should arrive here at all; this is the second line, and the point
	# of it is that it cannot itself be the thing that raises.
	var t: Variant = targeting.get(&"current_target")
	if t == null or not is_instance_valid(t):
		return null
	return t as Node3D


## Heading yaw that points the hero at `t`. Heading convention, not node
## rotation: heading == (sin y, 0, cos y). See `facing_yaw`.
func _yaw_to(t: Node3D) -> float:
	var to := K.flat(t.global_position - global_position)
	if to == Vector3.ZERO:
		return facing_yaw
	return atan2(to.x, to.z)


# --- States -----------------------------------------------------------------

func _tick_ground(wish: Vector3, mag: float, delta: float) -> void:
	if _try_start_roll(wish, mag):
		return

	# Deliberately does NOT return: a jump is not a state, it is an impulse, and
	# the hero keeps steering the whole way up and down. Air control in a game
	# with no aerial attacks is just the ability to land where you aimed.
	_try_start_jump()

	# AFTER the roll and the jump, so both are still ways out of a grip — a dodge
	# backwards off a block is how you stop pushing it in a hurry, and a grip you
	# could only leave by releasing the stick would be a grip that ate the one
	# button the player reaches for when something is coming at them. BEFORE the
	# lock-on and the guard, because having hold of a block outranks both: the
	# stone is where his hands are.
	if _grip != null:
		_tick_push(delta)
		return

	# [oot] §3.2 — a continuous curve of stick magnitude, no walk/run branch.
	var target_speed := _target_speed(mag)
	var moving := target_speed > 0.0

	var target := lock_target()
	if target != null:
		_tick_locked(wish, target_speed, moving, target, delta)
		return

	# Aiming and guarding hold the body the same way, so they share a tick. See
	# _tick_camera_facing for why the shield belongs in it.
	if aiming() or blocking:
		_tick_camera_facing(wish, target_speed, moving, delta)
		return

	if moving and _speed > K.RUN_SPEED * turnaround_min_speed01:
		var away := absf(rad_to_deg(wrapf(atan2(wish.x, wish.z) - facing_yaw, -PI, PI)))
		if away >= turnaround_angle_deg:
			_start_turn180(wish)
			return

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_steer_to(wish, turn_rate, delta)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)

	_set_planar_velocity(_forward() * _speed)


## Locked on: the body points at the target and the stick moves you around it.
##
## This is the whole difference between a lock-on and a camera hint, and it is
## what was missing. Unlocked, heading and travel are the same vector — the hero
## goes where he faces, and steering IS turning. Locked, they come apart:
## `facing_yaw` is owned by the target and the stick drives velocity directly,
## so pulling left circles the enemy while still looking at him.
##
## Two consequences worth naming, because both are load-bearing:
##
##   * The 135-degree reversal (§3.3) is suppressed. It exists to make an
##     about-face read as its own move, which only makes sense when the body
##     turns to travel. Locked, the body never turns, so a reversal is just
##     backing off — and firing a 180 clip there would spin the hero away from
##     the thing he is supposed to be watching.
##   * Speed is NOT reduced for backing up or side-stepping. Elden Ring does
##     slow a backward walk, and doing that here needs strafe clips the library
##     ships but nobody has identified (tools/directors/strafe_lookdev.gd), so
##     it is deliberately left alone rather than tuned against the wrong
##     animation.
func _tick_locked(wish: Vector3, target_speed: float, moving: bool,
		target: Node3D, delta: float) -> void:
	# Faster than the free turn rate: the lock is a promise that he keeps facing
	# the thing, and a lazy swing off that promise reads as the lock slipping.
	_steer_to(Vector3(sin(_yaw_to(target)), 0.0, cos(_yaw_to(target))),
		turn_rate * 1.8, delta)

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_set_planar_velocity(wish.normalized() * _speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)
		# Bleed off along whatever direction he was already travelling, not
		# along his facing — locked, those are different, and using the facing
		# here slides him into the enemy every time he lets go of the stick.
		var travel := K.flat(velocity)
		if travel == Vector3.ZERO:
			_set_planar_velocity(Vector3.ZERO)
		else:
			_set_planar_velocity(travel.normalized() * _speed)


## Aiming or guarding, unlocked: the body points where the LENS points and the
## stick moves you around, which is the same split `_tick_locked` makes and for
## the same reason. Here the thing being faced is the camera rather than an enemy.
##
## For the BOW this is what stops the shot lying. Without it the hero runs where
## the stick says while the camera sits on his shoulder looking somewhere else,
## and the bow — held in the hands of a body facing away from the shot — visibly
## points at nothing the arrow will hit. The aim is the camera's (see
## hero_ranged.gd), so the body has to agree with it.
##
## For the SHIELD it is OOT's Z-Parallel, which is the half of holding Z that
## has nothing to do with locking onto anything: the guard pins your facing and
## the stick becomes a strafe. That is what makes the shield a stance rather than
## a toggle you carry around — you sidestep round a thing while watching it, back
## off from it in a straight line, and the backstep in `_try_start_roll` has a
## direction to be the opposite OF. Without a facing to hold, "roll backwards"
## means nothing, because backwards is wherever you last happened to run.
##
## The 135° reversal is suppressed for the same reason it is under a lock: the
## body never turns to travel here, so an about-face is a backstep, and firing a
## 180 clip would spin him off whatever he is facing.
func _tick_camera_facing(wish: Vector3, target_speed: float, moving: bool, delta: float) -> void:
	_steer_to(_camera_heading(), turn_rate * 1.8, delta)

	if moving:
		_speed = move_toward(_speed, target_speed, accel * delta)
		_set_planar_velocity(wish.normalized() * _speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * delta)
		var travel := K.flat(velocity)
		if travel == Vector3.ZERO:
			_set_planar_velocity(Vector3.ZERO)
		else:
			_set_planar_velocity(travel.normalized() * _speed)


## Hands on the stone. The tick that makes a block a thing you HOLD rather than
## a thing you repeatedly walk into.
##
## Three things happen here and each is one of the reasons the grip exists:
##
##   * **The facing is the axis.** Square to the face, not wherever the stick
##     last wandered, so the shove reads as a shove.
##   * **He walks at the block's pace, always.** Not at the stick's — pressing
##     harder does not shove harder, and running at a block he is already
##     touching is what used to jitter him against its face. While the stone is
##     still, this velocity is simply eaten by the collision and he strains; the
##     instant it gives, he is already moving at exactly its speed and travels
##     with it. That is the whole trick, and it is why nothing here tweens him.
##   * **He is pulled onto the centre-line.** Sideways only, and gently. Without
##     it, a grip taken off a diagonal lean leaves him on the corner, and four
##     shoves later he has slid off the edge of a block he never let go of.
##
## Note what is NOT read: the stick. Lateral deflection does nothing while he
## has hold, which is exactly what "stuck to it" means. The block owns the
## question of whether the player is still pressing (`PushBlock` senses it, the
## same way it always sensed the lean) and lets go on his behalf.
func _tick_push(delta: float) -> void:
	_steer_to(_grip_axis, turn_rate * 1.8, delta)
	_speed = move_toward(_speed, _grip_speed, accel * delta)
	var v := _grip_axis * _speed
	if _grip.has_method(&"grip_anchor"):
		var to_block := K.flat(_grip.call(&"grip_anchor") - global_position)
		var side := to_block - _grip_axis * to_block.dot(_grip_axis)
		v += side.limit_length(GRIP_CENTRE_SPEED / GRIP_CENTRE_GAIN) * GRIP_CENTRE_GAIN
	_set_planar_velocity(v)


## The camera's forward, flattened, as a heading direction — or the hero's
## current facing when there is no camera, so a director rendering a bare hero
## does not spin him to world north.
func _camera_heading() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := K.flat(-cam.global_transform.basis.z)
		if f != Vector3.ZERO:
			return f.normalized()
	return _forward()


## The speed the stick is asking for, sprint included. One function so that
## every tick that reads a target speed reads the same one — the locked tick and
## the camera-facing tick call this too, and they get the plain curve back
## because `sprinting` is never true in either (see _tick_context).
func _target_speed(mag: float) -> float:
	var s := K.speed_for_stick(mag)
	# Any deflection at all becomes a full run, rather than scaling the curve.
	# That is BOTW's answer and it is the right one: the button means "run", and
	# a half-pushed stick under a held run button that produced a jog would make
	# the player negotiate with two analogue inputs for one intention.
	if sprinting and s > 0.0:
		s = sprint_speed
	# The armour, on top of the curve — never inside it. `K.RUN_SPEED` and
	# `K.SPRINT_SPEED` are [oot]/[tune] numbers this project does not renegotiate
	# (docs/GDD.md §6.6 says so in as many words), so a heavy suit multiplies what
	# they produced and a Swift ring multiplies it back. `Game.speed_mult()` is
	# 1.0 on a fresh save and clamps at 1.0 above, so this line is a no-op until
	# somebody buys armour and can never make the hero faster than the source.
	#
	# HERE, and not in the roll: `ROLL_SPEED` is the i-frame dodge and the whole
	# reason the speed cost is a real cost is that the hero still has it. Slowing
	# the roll as well would make heavy armour a strictly worse purchase rather
	# than a trade.
	return s * Game.speed_mult()


## The whole A button, measured: how long it was held is what decides whether the
## press was a DODGE or a RUN, and this is the only place that reads it. Both
## payouts leave through `context_tapped`; the sprint leaves through `sprinting`.
##
## The three ways a press ends:
##
##   1. It cannot become a run at all (`_context_resolves_now`) — paid out on the
##      PRESS frame, no latency, exactly as it always was. That is the dodge you
##      make with something swinging at you.
##   2. It is released before `sprint_hold_time` — paid out on the RELEASE frame.
##      Press and release inside one physics frame is the same path: `pressed` is
##      already false on the frame the edge is seen, and the tap falls out below.
##   3. It is still down when the window expires — disarmed, forever. The run
##      starts and the button will not roll when it eventually comes up. Note
##      this is decided by the CLOCK and not by whether the run materialised: a
##      hold refused by an empty stamina bar is still a hold, and paying it out
##      as a late dodge would be a roll the player asked for a third of a second
##      ago and has stopped expecting.
##
## THIS BUTTON IS B AND IT IS SHARED WITH NOTHING. It used to be A, on top of
## `interact`, arbitrated by `Prompt.claims_press` / `claims_hold` — holding A at
## the dungeon gate had to fill the gate's ring without also winding the hero up
## to run at it. Both of those functions are gone with the layout that needed
## them (see the `context` note in project.godot): a dodge that has to ask a
## shopkeeper for permission is a dodge with a rule on it, and this is the one
## button in the game that cannot afford one.
func _tick_context(delta: float, input_locked: bool) -> void:
	context_tapped = false
	var pressed := not input_locked and Input.is_action_pressed(&"context")
	# The edge, taken from BOTH sources: `just_pressed` alone drops a press the
	# physics frame did not see, and the raw rising edge alone drops a press and
	# release that landed inside one frame.
	var began := (pressed and not _context_down) \
		or (not input_locked and Input.is_action_just_pressed(&"context"))
	_context_down = pressed

	if input_locked:
		_context_held = 0.0
		_context_armed = false
		sprinting = false
		return

	if began:
		_context_held = 0.0
		_context_armed = true
	if pressed:
		_context_held += delta

	if _context_armed:
		if _context_resolves_now():
			# Nothing to wait for: this press has no run in it.
			context_tapped = true
			_context_armed = false
		elif not pressed:
			context_tapped = true
			_context_armed = false
		elif _context_held >= sprint_hold_time:
			_context_armed = false

	if not pressed:
		sprinting = false
		return

	# Free locomotion only, and each exclusion is its own reason:
	#   locked   — the stick is a circle-strafe there, and "run" has no direction
	#              to mean when the body is owned by a target.
	#   guarding — a sprint would have to drop the shield, and dropping a stance
	#              the player is holding a button for is worse than not running.
	#   aiming   — same, plus the pack has no aim-run to play (see AimLoco).
	# These are the same stances `_context_resolves_now` names, and they have to
	# be: a stance that withholds the run is a stance where the press is a dodge
	# the instant it is made.
	if lock_target() != null or blocking or aiming() or not is_on_floor():
		sprinting = false
		return
	if _context_held < sprint_hold_time:
		sprinting = false
		return

	if _sprint_winded:
		if Game.stamina < Game.max_stamina * sprint_recover01:
			sprinting = false
			return
		_sprint_winded = false

	# Charged per frame, so the run ends exactly when the bar does. spend_stamina
	# also holds regen off for K.STAMINA_DELAY on every call, which is the
	# behaviour we want and not a side effect to route around: a run must not
	# refill the bar it is emptying.
	sprinting = Game.spend_stamina(sprint_stamina_rate * delta)
	if not sprinting:
		_sprint_winded = true


## Is there any run in this press? If not, it is a dodge NOW and the tap window
## never runs — that is what keeps the reaction-critical half of the button at
## zero latency (see `sprint_hold_time`).
##
## Read every frame rather than latched at the press, because the answer can
## change under a held button: raise the shield mid-hold and the run stops being
## available, which retires the wait and pays the press out as a dodge. The
## reverse — a lock breaking mid-hold — cannot resurrect a wait that has already
## been paid, since `_context_armed` is false by then.
##
## Airborne is in the list for a duller reason than the other three: a dodge is
## refused off the floor anyway, so waiting would hold a press that has nowhere
## to go and then cash it in on landing, a third of a second after it was made.
func _context_resolves_now() -> bool:
	return lock_target() != null or blocking or aiming() or not is_on_floor()


func _tick_jump_buffer(delta: float, input_locked: bool) -> void:
	if not input_locked and Input.is_action_just_pressed(&"jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)


## Leave the ground. Returns whether it did — `_tick_roll_recover` reads the
## answer now, because out of a dodge's cancel window a jump DOES interrupt
## something and the recovery tick must not go on bleeding him to a stop
## underneath it.
func _try_start_jump() -> bool:
	if _jump_buffer <= 0.0:
		return false
	# Coyote, and it reuses the grace the Air one-shot already runs on rather
	# than inventing a second window: walking off a ledge and pressing jump a
	# frame later is a press the player meant, and refusing it is the single
	# most common complaint about a jump that is technically correct.
	if not is_on_floor() and _airborne_time > coyote_time:
		return false
	# LAST, after both refusals, so a press that was never going to leave the
	# ground does not also end a dodge recovery for nothing. It is a no-op unless
	# the hero is standing in `dodge_cancel_time`.
	_cancel_dodge()
	_jump_buffer = 0.0
	_jump_impulse = jump_speed
	_jumping = true
	# The jump clip contains its own airborne pose, so the coyote crossing in
	# _after_move must not fire `Air` over the top of it a tenth of a second in.
	_air_fired = true
	_fire_jump()
	return true


## Which of the two jumps this is. Read off `_speed` — the speed he is CARRYING —
## rather than off the stick, because the arc is decided by momentum: a hero at a
## dead stop who slams the stick forward on the launch frame is still going
## straight up, and the flat running arc under him would read as a glitch.
func _fire_jump() -> void:
	_jump_param = _P_JUMP_RUN if _speed >= jump_run_speed_gate else _P_JUMP
	_fire(_jump_param)
	# A second jump re-arms the clip from the top, so any cut still owed for the
	# LAST landing has to go — left running it would fade this leap out 0.12 s
	# after it started, which on a chained hop is at the apex.
	_jump_cut = -1.0
	Bus.request_sfx.emit(VOICE_EFFORT, global_position)


## Is the stick at rest this frame? A planted dodge with no direction asked for
## is the BACKSTEP (`_try_start_roll`), and this is the deadzone test that says
## so.
##
## It used to be the seam between two files: behind a guard the dodge button was
## also the jump attack, neutral leapt and deflected rolled, and the two halves
## had to answer this identically or the press fell between them. The leap has
## its own trigger now, so this has one caller again — kept as a function because
## the deadzone it reads (K.STICK_DEADZONE) is the same one every other "is the
## player asking for a direction" question in this file uses.
##
## Read raw rather than through `_camera_relative`, because a rotation cannot
## change a length.
func stick_neutral() -> bool:
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	return stick.length() < K.STICK_DEADZONE


func _try_start_roll(wish: Vector3, mag: float) -> bool:
	if Prompt != null and Prompt.blocked:
		return false
	# NOT the raw button: `context_tapped` is the press AFTER `_tick_context` has
	# measured how long it lasted and ruled that it was a dodge and not a run. On
	# the release of a long hold it is false, and the hero keeps running instead
	# of coming out of the sprint in a roll he stopped asking for.
	if not context_tapped:
		return false
	if not is_on_floor():
		return false

	var target := lock_target()
	var dir := wish

	if target != null or blocking:
		# LOCKED OR GUARDING, A NEUTRAL STICK IS THE BACKSTEP. Both stances pin
		# the facing (_tick_camera_facing), so "no direction" has an unambiguous
		# one: straight back from what you are watching.
		#
		# The locked half of this used to REFUSE instead, standing down so that
		# the same press could come out as the jump attack — [oot] Z+A, neutral
		# leaps and back flips. The leap is on the trigger now (`heavy`), so there
		# is nothing left to stand down for, and what replaces a stick rule the
		# player had to learn is the move Elden Ring gives a neutral dodge anyway.
		#
		# The stick gate does not apply in either stance: this is a deliberate
		# press made from a planted position, not something you fall into out of
		# a run, so gating it on a near-full deflection would eat half of them.
		if stick_neutral():
			dir = -_forward()
	else:
		# [oot] a discrete action needs a near-full deflection — you cannot roll
		# out of a walk, only out of a committed run. §3.2 / K.STICK_ACTION_GATE.
		if mag < roll_stick_gate or wish == Vector3.ZERO:
			return false

	# Last gate, and deliberately last: every cheaper reason to refuse has already
	# run, so we never charge stamina for a roll that was not going to happen.
	if not Game.spend_stamina(roll_stamina):
		return false
	# AFTER the stamina and BEFORE `_dodge` is reassigned below, and both halves
	# of that matter. After, so a dodge refused for stamina does not end the
	# recovery of the one before it; before, because `_cancel_dodge` fades out
	# whichever one-shot `_dodge` currently names, and two frames from now that
	# will be the NEW dodge. Chaining backflip into roll without this left the
	# flip playing under the dive for the rest of its clip.
	_cancel_dodge()
	state = MoveState.ROLL
	_roll_age = 0.0
	_perfect_spent = false
	_roll_dir = dir.normalized()
	_roll_keeps_facing = target != null or blocking
	# Locked or guarding, the body keeps watching through the whole dodge; the
	# roll moves him without turning him. Free, the roll IS the turn — and
	# spinning the hero to face his own backstep is precisely the failure this
	# guards against, since a backstep's direction is behind him by definition.
	if not _roll_keeps_facing:
		facing_yaw = atan2(dir.x, dir.z)
	# AFTER the facing is settled, never before: which dodge this is means
	# "which way relative to where he will be looking", and free the answer is
	# always FORWARD *because* the line above just made it so.
	_dodge = _dodge_for(_roll_dir)
	_dodge_model_yaw = _dodge_model_offset(_dodge, _roll_dir)
	_state_timer = _dodge_time(_dodge)
	_dodge_speed = _dodge_speed_for(_dodge)
	_speed = _dodge_speed
	_set_planar_velocity(_roll_dir * _dodge_speed)
	# The clip is compressed onto the dodge AND its recovery, not onto the dodge
	# alone: all four end by standing back up, and cramming that into the travel
	# leaves the hero holding a finished pose through the whole recovery.
	_fire_dodge(_dodge, _state_timer + roll_recover_time)
	roll_started.emit()
	return true


## Which of the four `dir` is, read against the facing the hero holds through the
## dodge. See the Dodge enum for why the free case can only ever answer FORWARD.
func _dodge_for(dir: Vector3) -> int:
	var f := _forward()
	var ahead := dir.dot(f)
	# Hero-local RIGHT, and the sign here is the whole function. Heading yaw h has
	# forward (sin h, 0, cos h); turning that -90 degrees about Y gives
	# (-cos h, 0, sin h) == (-f.z, 0, f.x). Sanity-check it at h = 0: forward is
	# +Z, the body's rotation.y is PI (CONTRACT §2.5 — -basis.z is forward), and
	# basis.x is therefore (-1, 0, 0). Which agrees. The obvious-looking
	# (f.z, 0, -f.x) is the hero's LEFT, and it shipped for one render: the
	# sidehops travelled correctly and played each other's clip, so he hopped
	# right while crossing his legs to the left.
	#
	# Derived from the heading convention rather than read off `basis`, because
	# `facing_yaw` leads the body: the basis is still catching up on the frame a
	# dodge starts, and a sidehop picked off a stale basis picks the wrong side.
	var side := dir.dot(Vector3(-f.z, 0.0, f.x))
	if absf(ahead) >= absf(side):
		return Dodge.FORWARD if ahead >= 0.0 else Dodge.BACK
	return Dodge.RIGHT if side >= 0.0 else Dodge.LEFT


## How far the MODEL is turned off the body for this dodge, in radians.
##
## Only the sideways pair turn. FORWARD is already pointing where it travels;
## BACK is the backflip, which is authored travelling backwards and would come
## out facing the wrong way if it were turned. And a dodge that does not pin the
## facing turned the BODY instead (`_roll_keeps_facing`), which leaves nothing
## for the model to carry — it can only ever be FORWARD in that case anyway.
##
## Derived as a DIFFERENCE rather than from the basis, which is what keeps it out
## of CLAUDE.md §4's way: whatever `rotation.y = facing_yaw + PI` means, a body
## turned to `heading` instead of `facing_yaw` differs from this one by exactly
## `heading - facing_yaw`, and the model is a child of the body. So adding that
## to the model's own local yaw aims the dive exactly where a whole-body turn
## would have aimed it, with no sign to get wrong and nothing to re-derive if the
## facing convention ever moves.
func _dodge_model_offset(dodge: int, dir: Vector3) -> float:
	if dodge != Dodge.LEFT and dodge != Dodge.RIGHT:
		return 0.0
	return wrapf(atan2(dir.x, dir.z) - facing_yaw, -PI, PI)


## Two answers, not three: the backflip is its own move and everything else is
## the roll, pointed somewhere. See `clip_roll_left` for why the sidehop's own
## number stopped being read.
func _dodge_speed_for(dodge: int) -> float:
	match dodge:
		Dodge.BACK: return backflip_speed
		_: return roll_speed


## How long the hero belongs to this dodge — which is also how long he is
## invulnerable, since take_hit reads `state == MoveState.ROLL` and nothing finer.
func _dodge_time(dodge: int) -> float:
	match dodge:
		Dodge.BACK: return backflip_time
		_: return roll_time


## Is the hero standing in the tail of a dodge that a committed action may cut
## short? See `dodge_cancel_time` for what "committed" buys and what it does not.
##
## Deliberately NOT true during `MoveState.ROLL`. The travel is the i-frame
## window — `take_hit` refuses everything for as long as `state == ROLL` — so a
## dodge you could swing out of early would be a dodge whose defensive value the
## player pays for and then throws away by pressing the button they came here to
## press. The recovery is the part that buys nothing, and it is the part that
## moves.
func dodge_cancellable() -> bool:
	return state == MoveState.ROLL_RECOVER and _state_timer <= dodge_cancel_time


## Is a committed action legal from where he is standing? The bar every
## `request_*` in this file used to spell as `state != MoveState.GROUND or not
## is_on_floor()`, plus the dodge's cancel window.
##
## One function rather than six copies because the window has to arrive in all
## six at once: a hero who can swing out of a roll tail but cannot raise a bow
## out of it has a rule the player cannot learn.
func can_act() -> bool:
	return is_on_floor() and (state == MoveState.GROUND or dodge_cancellable())


## Is the hero inside a dodge that has not yet reached its cancel window? What
## reads it is `HeroCombat`, to tell "refuse this press" from "owe it" — a press
## made here pays out on the frame `dodge_cancellable` turns true, instead of
## being dropped on the floor as it was.
func mid_dodge() -> bool:
	return (state == MoveState.ROLL or state == MoveState.ROLL_RECOVER) \
		and not dodge_cancellable()


## Seconds from now until `dodge_cancellable` turns true — 0.0 if it already is,
## and -1.0 if he is not in a dodge at all.
##
## `HeroCombat` sizes an owed press off this rather than off a constant of its
## own, and the constant is what it replaced: a flat 0.25 s lifetime expired
## while the hero was still mid-dive, so a swing pressed 0.30 s into a 0.82 s
## dodge was buffered, timed out 0.08 s before the window opened, and was dropped
## exactly as it had been before the buffer existed. The wait is not a fixed
## length; it is however much dodge is left, and only this file knows that.
func dodge_cancel_in() -> float:
	match state:
		MoveState.ROLL:
			# The dive still has `_state_timer` to run, and then all of the
			# recovery except the window at its end.
			return _state_timer + maxf(roll_recover_time - dodge_cancel_time, 0.0)
		MoveState.ROLL_RECOVER:
			return maxf(_state_timer - dodge_cancel_time, 0.0)
	return -1.0


## End a dodge recovery NOW, because something committed is taking over.
##
## A no-op outside the window, which is what lets every caller call it
## unconditionally rather than each re-deriving the same test.
##
## The one-shot is FADED OUT rather than left running. Everything in this file
## has only ever fired one-shots (`_fire`), and the tree's stacking order made
## that survivable — a swing sits above the dodges and simply covers whichever
## one is still playing. It is not survivable for the two cancels that do NOT
## fire a node above the dodge: a jump out of a roll tail, and the shield coming
## back up. Both left the roll's remaining ~0.5 s of clip playing at full weight
## under a hero who was already doing something else.
func _cancel_dodge() -> void:
	if not dodge_cancellable():
		return
	state = MoveState.GROUND
	_state_timer = 0.0
	_fade_out(_dodge_param(_dodge))
	# The signal is what the recovery's END means, and callers of it (VFX, the
	# stamina regen delay) must not be able to tell a cancelled dodge from one
	# that ran out — a dodge ended early is still a dodge that ended.
	roll_finished.emit()


## Play the dodge, compressed onto `duration`. The clips run 0.97–2.17 s and the
## moves they serve run 0.44–0.82 s, so each needs its own factor — see the note
## in _build_anim_tree about why this cannot be set once.
##
## The `skip` is not optional here even though it is zero for three of the four:
## the backflip plays a WINDOW of `ex_backflip` rather than the whole of it
## (`_dodge_skip`), and sizing that window off the full length would run it 45%
## fast and strand the hero in a finished pose for the rest of his lockout.
func _fire_dodge(dodge: int, duration: float) -> void:
	if _tree != null:
		_tree.set(_dodge_scale_param(dodge),
			_clip_scale(_dodge_clip(dodge), duration, _dodge_skip(dodge)))
	_fire(_dodge_param(dodge))
	# THE SPLIT IS THE SAME ONE THE CLIPS MAKE. Three of the four dodges are the
	# roll (`clip_roll` is `ex_roll_to_run` for FORWARD, LEFT and RIGHT), and a
	# roll is a body going over the ground — cloth and scuffed stone. BACK is the
	# backflip, which never touches the ground at all: it is a leap, and it gets
	# what the jump gets, because the sound of a man launching himself backwards
	# is not the sound of one rolling.
	#
	# Hung here rather than on `roll_started` for exactly that reason: the signal
	# fires once for all four and does not say which, and a backflip that scuffs
	# was the first version of this.
	if dodge == Dodge.BACK:
		Bus.request_sfx.emit(VOICE_EFFORT, global_position)
	else:
		Bus.request_sfx.emit(&"dodge_roll", global_position)


func _start_turn180(wish: Vector3) -> void:
	state = MoveState.TURN180
	_state_timer = turn180_time
	_roll_dir = wish
	_fire(_P_TURN)


func _tick_turn180(delta: float) -> void:
	_state_timer -= delta
	# [oot] §3.3 — the reversal does not steer, it kills speed and re-orients.
	_speed = move_toward(_speed, 0.0, decel * 2.5 * delta)
	_steer_to(_roll_dir, turn_rate * 1.4, delta)
	_set_planar_velocity(_forward() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND


func _tick_roll(delta: float) -> void:
	_state_timer -= delta
	_roll_age += delta
	_track_lock(delta)
	_speed = _dodge_speed
	_set_planar_velocity(_roll_dir * _dodge_speed)
	if _state_timer <= 0.0:
		state = MoveState.ROLL_RECOVER
		_state_timer = roll_recover_time


## A swing commits. The hero keeps his facing and bleeds off whatever speed he
## carried in, which is what makes the blade feel like it weighs something —
## being able to steer through a swing is the single biggest tell of a clone.
func _tick_attack(delta: float) -> void:
	_state_timer -= delta
	_track_lock(delta)
	# The lunge drives, then the swing bleeds like any other. The drive is short
	# on purpose: it is over before the damage window opens, so the blow lands at
	# the END of the leap rather than sweeping through everything on the way.
	if _lunge_left > 0.0:
		_lunge_left -= delta
		_speed = _lunge_speed
		_set_planar_velocity(_lunge_dir * _lunge_speed)
	else:
		_speed = move_toward(_speed, 0.0, decel * 2.2 * delta)
		_set_planar_velocity(_bleed_dir() * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND


## Keep the body on the target through a move that owns the hero. Without this a
## swing or a dodge freezes the facing, and an enemy that side-steps mid-attack
## ends up behind a hero who is still supposedly locked onto him.
func _track_lock(delta: float) -> void:
	var target := lock_target()
	if target == null:
		return
	var yaw := _yaw_to(target)
	_steer_to(Vector3(sin(yaw), 0.0, cos(yaw)), turn_rate * 1.8, delta)


## Which way residual speed bleeds off. Unlocked these are the same thing, but
## locked the hero faces the target while travelling somewhere else entirely --
## and bleeding along the FACING there walks him into the enemy at the end of
## every backstep.
func _bleed_dir() -> Vector3:
	# Aiming and guarding have the same split as a lock — facing is the camera,
	# travel is the stick — so they bleed the same way. Without this a shot fired
	# while strafing sideways slides him forward along the bow instead of
	# coasting to a stop, and a guarded backstep coasts back into what he just
	# stepped away from.
	if lock_target() == null and not aiming() and not blocking:
		return _forward()
	var travel := K.flat(velocity)
	return travel.normalized() if travel != Vector3.ZERO else _forward()


## The air slam: hang, drive at the floor, and be rooted when it arrives.
##
## Returns false — having done nothing — if the hero is not airborne with room
## beneath him, so a press made a frame after touchdown is silence rather than a
## hero who plants himself for `slam_recover` at ankle height.
##
## The DROP IS MEASURED, with a ray, before anything is fired. Both halves of the
## clip are then sized to what that measurement says will happen: the dive is
## compressed onto `hang + drop / slam_speed` so the blade arrives overhead and
## comes down over exactly the air the hero has left, and the impact half is
## sized to `slam_recover` so he is standing again on the frame the state ends.
## Guessing either one is how you get a strike that finishes in mid-air on a
## short hop and one that is still winding up on a drop from a ledge.
func request_slam() -> bool:
	if state != MoveState.GROUND or is_on_floor():
		return false
	var drop := _drop_below()
	if drop < slam_min_height:
		return false

	state = MoveState.SLAM
	_state_timer = 0.0
	_slam_hang_left = slam_hang
	_slam_landed = false
	# A slam kills the horizontal entirely — it goes straight down, at whatever
	# is under him, and a slam that carries a run's momentum lands a metre past
	# what the player aimed it at.
	_speed = 0.0
	_lunge_left = 0.0
	_set_planar_velocity(Vector3.ZERO)
	# The jump's own landing must not fire underneath this one. `_air_fired` is
	# already true if this came out of a jump; set it for the case it did not,
	# which is a slam thrown out of an ordinary fall off a ledge.
	_air_fired = true
	_jumping = true

	var target := lock_target()
	if target != null:
		facing_yaw = _yaw_to(target)

	if _tree != null:
		var air := slam_hang + drop / maxf(slam_speed, 0.1)
		_tree.set(_P_SLAM_SCALE,
			(slam_land_offset - slam_start_offset) / maxf(air, 0.05))
		_tree.set(_P_SLAM_LAND_SCALE,
			(_clip_length(clip_slam) - slam_land_offset) / maxf(slam_recover, 0.05))
	_fire(_P_SLAM)
	return true


## Metres of clear air under the hero's feet, out to 40 m. Used by the slam to
## size its own animation, so it asks the same collision layer the body falls
## through (K.L_WORLD) and nothing else — an enemy standing underneath is
## something to land ON, not a floor to stop the ray.
func _drop_below() -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.05
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0,
		K.L_WORLD, [self])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 40.0
	return maxf(from.y - float((hit.position as Vector3).y), 0.0)


## The slam, frame by frame: hang, then drive, then be rooted. The one state in
## the file that changes what gravity does — see `_apply_gravity`.
func _tick_slam(delta: float) -> void:
	if _slam_landed:
		_state_timer -= delta
		# Rooted, not frozen: he keeps sliding to a stop if the impact shoved him.
		_speed = move_toward(_speed, 0.0, decel * 3.0 * delta)
		_set_planar_velocity(_bleed_dir() * _speed)
		if _state_timer <= 0.0:
			state = MoveState.GROUND
		return

	_track_lock(delta)
	if _slam_hang_left > 0.0:
		_slam_hang_left = maxf(_slam_hang_left - delta, 0.0)
	# The floor test is `_after_move`'s job and it has already run for this frame,
	# so touchdown is handled there (see `_land_slam`). Nothing else to do here:
	# the drive itself is velocity, and velocity is _apply_gravity's.
	_set_planar_velocity(Vector3.ZERO)


# --- Taking a hit ------------------------------------------------------------

## Put the hero into the reaction `tier` earned, on top of whatever he was doing.
##
## **The one state that is entered from outside the state machine**, and it has to
## be: a blow does not wait for a swing to finish. So this is also the only place
## in the file that has to tidy up after every other state at once, which is why
## the cleanup is written as an unconditional list rather than as a match -- a
## match here is a table with one row per state and the row that ships broken is
## whichever one was added last and forgotten.
##
## LIGHT never arrives here. It plays its clip and leaves the hero in charge --
## see `take_hit`.
func _enter_hurt(tier: Hit.Tier, stun: float) -> void:
	# The chain in flight, the drive, the grip, the dodge's cancel window. Each of
	# these is a thing some other state is holding, and every one of them outlives
	# the state if it is not put down here: a hookshot cut short by a blow that
	# did not clear `_hook_travelling` leaves `HeroRanged` polling `hooking()` for
	# a pull that will never arrive.
	_hook_travelling = false
	_hook_timeout = 0.0
	_lunge_left = 0.0
	_perfect_spent = false
	_drop_grip()
	# The block goes down. It is not a decision he gets to keep having made while
	# he is being knocked off his feet, and `_physics_process` would drop the grip
	# for us next frame anyway -- doing it here means the shield is already down in
	# the frame the flinch starts, rather than one frame into it.
	blocking = false

	state = MoveState.HURT
	_hurt_tier = tier
	_hurt_rising = false

	if tier == Hit.Tier.KNOCKDOWN:
		_state_timer = K.KNOCKDOWN_DOWN_TIME
		# **I-frames for the WHOLE of it, rise included.** A knockdown is the most
		# expensive thing the game does to the player -- about two seconds during
		# which he cannot answer -- and a second blow landing inside it is not
		# difficulty, it is the controller being taken away twice for one mistake.
		# This is the standard answer and it is the reason the roll can be as
		# generous as it is: being on the floor has to be survivable or the tell
		# stops being a read and starts being a death.
		#
		# `grant_iframes` and not `_invuln =`, so it can never SHORTEN the second
		# a landed blow already bought.
		grant_iframes(K.KNOCKDOWN_DOWN_TIME + K.KNOCKDOWN_RISE_TIME)
		_fire_knockdown()
	else:
		# The authored `Hit.stun` is the floor's own statement of how long this
		# beat should hold you, and until card #130 **nothing on the hero read it**
		# -- `Enemy._on_damaged` honoured it and `take_hit` never looked, so twelve
		# hand-tuned numbers in `BossDb` were decorating a field with no reader.
		# K.HURT_HEAVY_TIME is a floor under it, exactly as the enemy's own
		# `maxf(hit.stun, 0.22)` is.
		_state_timer = maxf(stun, K.HURT_HEAVY_TIME)
		_fire_flinch(true, _state_timer)
	# Whatever he was carrying, he is not carrying it in the direction he chose any
	# more. The knockback shove is written by `take_hit` AFTER this runs.
	_speed = 0.0


## Fire one of the two flinch clips, sized onto `seconds`.
##
## The scale is `clip_len / seconds` like every other one-shot here, and the clips
## are TRIMMED to their reel in build_anim_lib -- 0.45 s and 0.55 s of 0.97 and
## 0.70 -- so this is compressing a reaction and not a reaction plus a settle.
func _fire_flinch(heavy: bool, seconds: float) -> void:
	if _tree == null:
		return
	var clip := clip_flinch_heavy if heavy else clip_flinch_light
	var scale := _clip_length(clip) / maxf(seconds, 0.05)
	_tree.set(_P_FLINCH_H_SCALE if heavy else _P_FLINCH_L_SCALE, scale)
	_fire(_P_FLINCH_H if heavy else _P_FLINCH_L)


## The fall, sized onto `K.KNOCKDOWN_DOWN_TIME`.
func _fire_knockdown() -> void:
	if _tree == null:
		return
	_tree.set(_P_KNOCKDOWN_SCALE,
		_clip_length(clip_knocked_down) / maxf(K.KNOCKDOWN_DOWN_TIME, 0.05))
	_fire(_P_KNOCKDOWN)


## The rise, sized onto `K.KNOCKDOWN_RISE_TIME`.
##
## The clip's own dead head is skipped by `getup_start_offset`, so the length this
## has to fit is what is LEFT of it -- get that wrong and the rise runs at a scale
## computed for a third of a second the hero never sees, finishing early and
## leaving him standing in the settle pose while the controller still says HURT.
func _fire_getup() -> void:
	if _tree == null:
		return
	var playable := maxf(_clip_length(clip_getting_up) - getup_start_offset, 0.05)
	_tree.set(_P_GETUP_SCALE, playable / maxf(K.KNOCKDOWN_RISE_TIME, 0.05))
	_fire(_P_GETUP)


## Serving the reaction. Rooted, unsteered, and -- for the knockdown -- in two
## halves on one timer.
##
## He is ROOTED rather than frozen: a blow that shoved him keeps sliding, and the
## slide is most of what says the blow had weight. The decel is gentler than the
## swing's (`_tick_attack` uses 2.2) because a man knocked off his feet should not
## stop like a man who chose to.
func _tick_hurt(delta: float) -> void:
	_state_timer -= delta
	_speed = move_toward(_speed, 0.0, decel * 1.4 * delta)
	_set_planar_velocity(_hurt_dir * _speed)
	if _state_timer > 0.0:
		return

	if _hurt_tier == Hit.Tier.KNOCKDOWN and not _hurt_rising:
		# The fall is over and he is on the floor. Hand over to the rise on the
		# SAME frame the fall's clip ends -- the one-shot would otherwise begin
		# fading back to a standing idle, which is the hero getting up by
		# teleporting into his own locomotion pose.
		_hurt_rising = true
		_state_timer = K.KNOCKDOWN_RISE_TIME
		_fire_getup()
		return

	state = MoveState.GROUND
	_state_timer = 0.0


## Touchdown. Called from `_after_move` — the only place that knows the floor was
## reached on THIS move rather than a frame ago.
func _land_slam(fall_speed: float) -> void:
	_slam_landed = true
	_state_timer = slam_recover
	_speed = 0.0
	if _tree != null:
		_fire(_P_SLAM_LAND)
	slammed.emit(global_position, fall_speed)


## Start a swing lasting `duration` seconds. Returns false if the hero is busy —
## rolling, turning, or already mid-swing — so the caller does not play a
## whoosh for a swing that never happened.
##
## `variant` picks which clip plays and nothing else: the timing, the damage and
## the commitment all live in HeroCombat, because they are combat numbers. This
## owns the pose and the facing, exactly as it does for the light swing.
func request_attack(duration: float, variant: int = Swing.LIGHT1) -> bool:
	if not can_act():
		return false
	# A no-op unless he is standing in a dodge's cancel window, in which case it
	# ends the recovery and fades the dive out from under the swing. It has to run
	# BEFORE `state` is assigned below: `_cancel_dodge` tests `state` to decide
	# whether there is anything to cancel, and by the next line there is not.
	_cancel_dodge()
	state = MoveState.ATTACK
	_state_timer = duration
	# Any ordinary swing cancels a leftover drive. request_lunge re-arms it after
	# calling through here, which is why this clear is safe to do unconditionally.
	_lunge_left = 0.0

	# Locked, the swing goes at the target -- that is the entire promise of the
	# lock, and letting the stick redirect it means a player circling an enemy
	# swings past him. Unlocked, face where the stick is pointing at the instant
	# of the swing, so an attack aims where the player is looking rather than
	# where he last ran.
	var target := lock_target()
	if target != null:
		facing_yaw = _yaw_to(target)
	elif not blocking:
		var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if stick.length() > 0.3:
			var wish := _camera_relative(stick)
			if wish != Vector3.ZERO:
				facing_yaw = atan2(wish.x, wish.z)
	# Guarding is the third case and it does NOTHING, which is the point: the
	# raised shield already pins the facing to the lens (_tick_camera_facing), so
	# the stick there is a strafe and not an aim. Letting it re-face the swing
	# meant a guarded sidestep-and-stab lunged off sideways, at ninety degrees to
	# the thing the player was watching over the top of the shield.

	# The slash clips run 1.4-2.4 s. OOT's swing is about half a second, so the
	# clip is compressed onto the real swing rather than the swing being slowed
	# to the clip — the animation serves the timing, not the other way round.
	#
	# What is compressed is the clip MINUS its wind-up: `_SWING_START_OFFSET` has
	# already been spent at build time on the node, so the swing gets to spend
	# its whole `duration` on the part with a sword in it.
	if _tree != null:
		_tree.set(_swing_scale_param(variant), _clip_scale(
			_swing_clip(variant), duration, _SWING_START_OFFSET[variant]))
	_fire(_swing_param(variant))
	return true


## The lock-on lunge: the same swing, plus a burst of drive at the locked target
## and a hop off the floor, because clip_lunge is the one clip in the library
## where the hero's feet leave the ground.
##
## Returns false — and swings nothing — if there is no lock. That refusal is the
## feature: the lunge is what Z-targeting BUYS you, and a version of it that
## also fired unlocked would just be a better standing attack.
##
## `drive_time` and `hop` are HeroCombat's, like every other number about the
## blow. What this owns is the arithmetic that turns "there is an enemy 4 m away"
## into a speed, because that is a movement question.
func request_lunge(duration: float, drive_time: float, hop: float) -> bool:
	var target := lock_target()
	if target == null:
		return false
	if not request_attack(duration, Swing.LUNGE):
		return false

	# request_attack has already pointed the body at the target, so the leap goes
	# where the hero is now facing rather than where he was standing a frame ago.
	#
	# Flattened by hand, NOT with K.flat: K.flat NORMALISES. Reading a distance
	# off it gives 1.0 for every target in the world, which made the gap
	# arithmetic below produce a leap speed of zero and a lunge that stood still.
	var delta := target.global_position - global_position
	var to := Vector3(delta.x, 0.0, delta.z)
	var dist := to.length()
	_lunge_dir = to.normalized() if dist > 0.001 else _forward()
	var gap := maxf(dist - lunge_stop_short, 0.0)
	_lunge_speed = minf(gap / maxf(drive_time, 0.05), lunge_max_speed)
	_lunge_left = drive_time
	_speed = _lunge_speed
	velocity.y = hop
	return true


## The dash attack: a swing with a short forward drive behind it, and the one
## attack in the kit that closes distance WITHOUT a lock.
##
## That is the whole difference from `request_lunge`, and it is deliberate. The
## lunge is what Z-targeting buys you, so it refuses without a target; the dash
## is what the SHIELD buys you, and the shield has already earned the right to a
## direction — guarding pins the facing to the lens (`_tick_camera_facing`), so
## "forward" here is a heading the player chose and is still looking down.
##
## It drives along the facing rather than at anything, for the same reason: there
## may be nothing there. A dash attack that whiffs into open floor is a dash
## attack the player mistimed, not a button that failed to do its job.
func request_dash(duration: float, drive_time: float, speed: float) -> bool:
	if not request_attack(duration, Swing.DASH):
		return false
	# request_attack cleared the drive; re-arm it, exactly as request_lunge does.
	_lunge_dir = _forward()
	_lunge_speed = speed
	_lunge_left = drive_time
	_speed = speed
	return true


## Hand the hero back to locomotion NOW, cutting short whatever commitment he is
## serving. The one caller is the landed parry (`HeroCombat.on_parried`): the
## recovery it cancels is a punish for MISSING, and a player who did not miss
## should not be standing in it while the body they just threw is still in
## the air.
##
## It does not touch the animation. The one-shot in flight fades out on its own
## `_SWING_FADE_OUT`, which is a shield arm settling back down over a fifth of a
## second — and the alternative, snapping the pose off on the frame of the catch,
## would cut the most legible thing on screen at the moment it is most worth
## looking at.
##
## Deliberately narrow: it refuses anything that is not an ATTACK, so it can
## never be the thing that yanks the hero out of a roll or off a hookshot chain.
func end_commitment() -> void:
	if state != MoveState.ATTACK:
		return
	state = MoveState.GROUND
	_state_timer = 0.0
	_lunge_left = 0.0


## The parry: the shield thrown forward, and the hero planted behind it.
##
## It goes through `request_attack` like every other commitment, which is what
## gives it the thing it most needs — you cannot steer out of it. `MoveState`
## has no PARRY value and does not want one: the difference between this and a
## swing is entirely what HeroCombat does with the window, and a state that
## behaves identically to ATTACK is a state that exists to be forgotten in one
## of the six places `state` is matched on.
##
## Rooted rather than driven. The dash explodes out of the guard and this does
## not, because a parry that also closed distance would be strictly better than
## the dash at the dash's own job — and because the whole move is a bet that the
## thing in front of you is about to arrive where you are already standing.
func request_parry(duration: float) -> bool:
	if not request_attack(duration, Swing.PARRY):
		return false
	_speed = 0.0
	_set_planar_velocity(Vector3.ZERO)
	_bash_pose()
	return true


## The shove, driven from here because no clip in the library contains one.
##
## This is `Enemy._tick_windup`'s trade made in the other direction. That file
## drives a monster's tell from code because the monster GLBs ship near-empty
## clip sets; this drives the hero's because the clip he does have is a BLOCK
## (see `clip_parry`) — 0.076 m of forearm over 0.13 s and then a static hold
## for the remaining two thirds of the move. Played at the 0.677x `_clip_scale`
## hands it, the shield goes out at 0.352 m/s against a standing idle's 0.279:
## the most committed action in the kit was reading as a man breathing.
##
## The MODEL, not the body, for the reason `parry_bash_reach` gives — and the
## same split `Enemy._lunge_pose` makes, which shoves a monster's model through
## a blow the physics body never travels.
##
## Three beats, sized off the windows that already exist rather than off numbers
## picked to look nice:
##
##   out    `K.PARRY_WINDOW * 0.5` — the shield is where it is claiming to be by
##          the middle of the window it is live for, not after it. EASE_OUT so
##          the throw is front-loaded; a shove that accelerates is a reach.
##   held   to the end of `K.PARRY_WINDOW`. This is the frame a caught blow
##          lands on, and it should land on a hero who has arrived.
##   back   all of `K.PARRY_RECOVER`, EASE_IN_OUT. The recovery is the price of
##          missing and it is the longest part of the move, so it is the part
##          that has to look like a price: he does not snap back, he unwinds.
##
## The settle is NOT cancelled when a parry lands. `HeroCombat.on_parried` calls
## `end_commitment` to hand the hero back early, and the pose unwinding under
## the riposte he throws is correct — the same reasoning `end_commitment`'s own
## comment gives about leaving the one-shot to fade rather than snapping it off
## on the frame of the catch.
func _bash_pose() -> void:
	if _model == null:
		return
	# One tween per property, killed before the next: two parries inside one
	# settle would otherwise stack and fight over `position:z`, and the loser
	# leaves the model parked off-centre for the rest of the run.
	_kill_bash()
	# FORWARD IS -Z AND THE FIRST CUT OF THIS SHOVED HIM BACKWARDS, under a
	# comment claiming the opposite had been "checked on the render". It had not
	# been: `parry_lookdev` measured `model.position.z - rest` and reported the
	# MAGNITUDE of a local axis, which is the same number whichever way the body
	# went, and the render it was supposedly checked against is a chase camera
	# sitting behind the hero — where a backwards lunge reads as him getting
	# BIGGER, which is what the frames actually showed once anyone looked.
	# CLAUDE.md §4, fourth time: facing is measured, not derived.
	#
	# `position` is in the PARENT's space and the model's own 180 does not touch
	# it. The hero body carries `rotation.y = facing_yaw + PI`, so hero-local -Z
	# is the heading (docs/CONTRACT.md §2.5) and the shove is NEGATIVE z.
	#
	# The PITCH is positive and that is not an inconsistency: `rotation.x` IS
	# taken through the model's own basis, Godot composes Euler as Y*X*Z, and the
	# 180 about Y flips the X axis — so +16 tips the top toward parent -Z, which
	# is forward. Two properties on the same node, two different frames. The
	# director below now measures both against the hero's world heading instead
	# of trusting either.
	# SEQUENTIAL, with `parallel()` marking the individual tweeners that ride
	# alongside the one before them. The first cut of this built the same five
	# steps out of `set_parallel(true)` plus two `chain()` calls and came out
	# MANGLED: `parry_lookdev` measured the shove reaching 0.126 m of its 0.26
	# and the pitch reaching 15.6 deg of its 16 — two halves of one parallel pair
	# ending in different places, which is only possible if they were not a pair.
	# The settle then never ran at all and left the model parked 0.127 m in front
	# of its own collision capsule.
	#
	# `chain()` and `set_parallel()` are the same knob reached from two
	# directions and interleaving them is how that happened. One default, set
	# once, and `parallel()` per exception.
	var out_t := K.PARRY_WINDOW * 0.5
	_bash = create_tween()
	_bash.tween_property(_model, ^"position:z", _bash_rest.z - parry_bash_reach,
			out_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bash.parallel().tween_property(_model, ^"rotation:x",
			deg_to_rad(parry_bash_pitch), out_t) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bash.tween_interval(K.PARRY_WINDOW - out_t)
	_bash.tween_property(_model, ^"position:z", _bash_rest.z, K.PARRY_RECOVER) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_bash.parallel().tween_property(_model, ^"rotation:x", 0.0, K.PARRY_RECOVER) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Stop a bash settle and put the model back where every other pose expects it.
##
## `_bash_pose` is the ONLY caller, and this comment said "called on death and
## on a scene handover as well" until the claim was checked. It is not, and it
## does not need to be: the hero has no death routine to hang it off — `Game.damage`
## emits `player_died`, `Flow` changes the scene, and the node is freed with the
## old one. A Tween created by `create_tween()` is bound to the node that made it
## and dies with it, so there is nothing left running to strand a pose.
##
## `Enemy._kill_recoil` DOES have those call sites, and the difference is that a
## monster survives its own states — it is frozen, launched and revived inside one
## scene, and each of those transitions is a place a running tween would fight the
## next pose. The hero's parry has exactly one such transition, which is a second
## parry inside the first one's settle, and that is the call above.
func _kill_bash() -> void:
	if _bash != null and _bash.is_valid():
		_bash.kill()
	_bash = null
	if _model != null:
		_model.position.z = _bash_rest.z
		_model.rotation.x = 0.0


## The flurry attack: a leap onto whatever is in front, thrown out of the window
## a perfect dodge opens.
##
## The lunge's machinery with the lock requirement removed, and that removal is
## the design rather than a shortcut. `request_lunge` refuses without a target
## because the leap is what Z-targeting BUYS; this one has already been paid for
## by the dodge, so demanding a lock as well would mean the reward for the
## hardest defensive read in the game silently did nothing whenever the player
## had not also pressed the shoulder button.
##
## It still aims at a `target` when there is one — `HeroCombat._leap_target()`
## picks it, the lock if the player has one and the nearest body in front if not
## — for the same reason `request_attack` turns the body: a leap that lands
## somewhere other than where the player was looking is a leap they will read as
## broken, and after a dodge the hero is very often facing away from the thing
## he just dodged. WHO to jump at is a combat question; this only does the
## arithmetic that turns "there is a goblin 1.9 m away" into a speed.
func request_flurry(duration: float, drive_time: float, hop: float,
		stop_short: float, target: Node3D = null) -> bool:
	if not request_attack(duration, Swing.FLURRY):
		return false
	var to := _forward()
	var dist := 0.0
	if target != null:
		# Flattened by hand, NOT with K.flat — that normalises, and a distance read
		# off it is 1.0 for everything in the world. `request_lunge` carries the
		# same note and the same bug behind it.
		var delta := target.global_position - global_position
		var flat := Vector3(delta.x, 0.0, delta.z)
		dist = flat.length()
		if dist > 0.001:
			to = flat / dist
			facing_yaw = atan2(to.x, to.z)
	_lunge_dir = to
	# With no target there is nothing to close on, so the leap covers a fixed
	# stride instead of a computed gap. `stop_short` is doing double duty as that
	# stride, which is honest: it is the distance the hero wants to end up from
	# whatever he jumped at, and with nothing there that is the whole jump.
	var gap := maxf(dist - stop_short, 0.0) if target != null else stop_short * 1.6
	_lunge_speed = minf(gap / maxf(drive_time, 0.05), lunge_max_speed)
	_lunge_left = drive_time
	_speed = _lunge_speed
	# THROUGH `_jump_impulse`, NOT `velocity.y`. Writing the vertical here does
	# nothing at all: `is_on_floor()` still reports the last `move_and_slide`, so
	# on the frame the leap starts it is true and `_apply_gravity` overwrites the
	# launch with its -0.5 snap bias before the body has moved a millimetre. The
	# jump is applied inside `_apply_gravity` for exactly this reason and the
	# comment there says so.
	#
	# `request_lunge` above still writes `velocity.y` and is still wrong in the
	# same way — left alone here because the lock-on leap is a separate move with
	# its own director, and a silent fix riding along in this commit is how the
	# next session ends up debugging a change nobody recorded.
	_jump_impulse = maxf(hop, 0.0)
	return true


## The stick in world space, as the hero reads it. Public because the lunge is
## distinguished from a standing swing by exactly one thing — whether the player
## is asking to move TOWARD what they are locked onto — and HeroCombat cannot ask
## that question without the camera-relative rotation this applies.
func wish_dir() -> Vector3:
	return _camera_relative(
		Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))


# --- The shoulder -------------------------------------------------------------
#
# A push block is the one prop in the game the hero is ATTACHED to, and the
# attachment is the mechanic: lean on a block and you have hold of it until you
# let go of the stick. That is Ocarina's, and it is not a nicety — a block you
# had to re-approach and re-lean on for every metre of a four-metre push is a
# block that spends the whole puzzle arguing with the player about whether they
# are standing in the right place.
#
# The split with `PushBlock`: the BLOCK senses (it already read `wish_dir` to
# know it was being leaned on, and that is the same question as "is he still
# holding on"), the HERO obeys. Nothing here reads input, and nothing here names
# `PushBlock` — the calls go both ways through `has_method`, so a future thing
# with a face and a grid can be pushed by the same shoulder.

## How hard he is pulled back onto the face's centre-line, and the ceiling on it
## in metres per second. Fast enough to have squared him up inside one shove,
## slow enough that it never looks like the block is magnetic.
const GRIP_CENTRE_GAIN := 4.0
const GRIP_CENTRE_SPEED := 1.2


## Take hold of `block`. `axis` is the cardinal heading INTO it and `speed` the
## pace its slide travels at, both the block's to decide.
##
## Refused off the floor or out of GROUND, which is the same bar `request_attack`
## and the bow draw hold: a hero mid-roll has not got a free hand, and a grip
## taken during one would be silently dropped by `_physics_process` on the very
## next frame anyway. Returning false lets the block fall back to shoving him
## nothing — see `PushBlock._take_grip`.
func grip_push(block: Node3D, axis: Vector3, speed: float) -> bool:
	if state != MoveState.GROUND or not is_on_floor():
		return false
	if block == null or axis == Vector3.ZERO or speed <= 0.0:
		return false
	_grip = block
	_grip_axis = K.flat(axis).normalized()
	_grip_speed = speed
	return true


## Let go, because the BLOCK says so — the stick came off it, or it seated on its
## mark. Silent by design: the caller is the block, and calling back into it here
## is how you write an infinite loop.
func release_push(_block: Node3D = null) -> void:
	_grip = null
	_grip_axis = Vector3.ZERO
	_grip_speed = 0.0


## Let go, because the HERO says so — he rolled, swung, was hit, or a screen took
## his input. Tells the block, so it stops driving itself off a grip that no
## longer exists and goes back to needing a fresh lean.
func _drop_grip() -> void:
	var block := _grip
	release_push()
	if block != null and is_instance_valid(block) and block.has_method(&"release_grip"):
		block.call(&"release_grip")


## Whether he has hold of something. For a director, and for anything that wants
## to know why he is walking into a wall.
func gripping() -> bool:
	return _grip != null


## Raise into the pull: `draw_time` seconds of it. Returns false if he cannot
## draw right now — mid-roll, mid-swing, off the ground.
##
## **This is not a commitment, and that is the change the trigger made.** The
## pull is held for as long as the player holds the button (`HeroRanged` owns
## that clock), and a stance you can be locked into indefinitely is a stance you
## have to be able to WALK in — which is exactly what `AimLoco` was built for and
## what the old draw-and-loose-in-one-window never once played. So this fires the
## clip and hands the body straight back; `_tick_camera_facing` already points
## him down the lens for the whole time the bow is out, which was the only other
## thing the commitment was doing here.
##
## Only the CHARGE is fired. `HeroRanged` owns the clock that decides when the
## arrow leaves and calls `bow_loose` — the same clock the arrow itself is
## spawned off, so the string leaving his fingers and the arrow leaving the bow
## cannot drift apart. Firing both here on a timer of the hero's own is exactly
## the drift the one-clip version had.
func request_bow_draw(draw_time: float) -> bool:
	if not can_act():
		return false
	_cancel_dodge()
	if _tree != null:
		_tree.set(_P_BOW_DRAW_SCALE, _clip_scale(clip_bow_draw, draw_time))
	_fire(_P_BOW_DRAW)
	return true


## The loose, `loose_time` seconds of it, down `aim`. Called by `HeroRanged` when
## the trigger comes up on a bow at full draw.
##
## Deliberately NOT a request: the string is at his ear and the one thing that
## cannot happen is that the shot silently evaporates. It TAKES the commitment
## rather than asking for it — the follow-through is the only part of a bow shot
## the hero is owned for now, and `_commit_ranged` refusing (he was knocked out
## of it on the same frame) still leaves the clip playing over whatever he is
## doing instead, which is the honest reading.
func bow_loose(loose_time: float, aim: Vector3) -> void:
	_commit_ranged(loose_time, aim)
	if _tree != null:
		_tree.set(_P_RANGED_SCALE, _clip_scale(clip_bow_shot, loose_time))
	_fire(_P_RANGED)


## Commit to a hookshot shot lasting `duration` seconds, turning to face `aim`.
## One phase, not two: the chain's flight is the commitment (see
## `HeroRanged.HOOK_FIRE_TIME`) and this clip is only the punch that starts it.
func request_hookshot(duration: float, aim: Vector3) -> bool:
	if not _commit_ranged(duration, aim):
		return false
	if _tree != null:
		_tree.set(_P_HOOK_SCALE, _clip_scale(clip_hook_shot, duration))
	_fire(_P_HOOK_SHOT)
	return true


## Commit to a CAST — the Burst-Verse's arm, thrown down `aim` (`docs/GDD.md`
## §6.5). Same shape as the hookshot's: one phase, and the mote's flight is the
## rest of it.
##
## **It fires the hookshot's one-shot on purpose.** `clip_hook_shot`
## (`ex_hookshot_fire`) is an arm punched out along the aim with nothing visible
## in the hand, which is exactly what casting a working looks like — and the
## working renders NO model at all, so there is nothing in the frame that could
## give the borrowed clip away. The alternative is a second copy of the same
## third of a second of arm, authored and imported, for a pose the player cannot
## tell apart. If the two ever need different arms, this one line is the split.
func request_cast(duration: float, aim: Vector3) -> bool:
	return request_hookshot(duration, aim)


## Raise the acquired item. The ceremony owns rooting and timing; Hero only owns
## the pose layered over its existing animation output.
func request_item_get() -> void:
	_fire(_P_ITEM_GET)


## The half of a shot that is the same for every ranged item: take the hero for
## `duration` seconds and point him down the aim. False if he is busy, exactly as
## `request_attack` is.
##
## It reuses `MoveState.ATTACK` rather than adding a state of its own: what the
## hero's BODY does here is identical — no steering, bleed off whatever speed he
## carried in — and the only difference is which clip plays. A separate state
## would be two copies of `_tick_attack` waiting to drift apart.
##
## `aim` is a full 3D direction because it comes from the camera, which has a
## pitch; only its yaw reaches the body, because the hero does not lean.
func _commit_ranged(duration: float, aim: Vector3) -> bool:
	if not can_act():
		return false
	_cancel_dodge()
	state = MoveState.ATTACK
	_state_timer = duration

	# Shooting where you are looking, always. Unlike the sword there is no stick
	# gate here: the aim came from the camera, and the camera IS the player
	# saying where the shot goes.
	var flat_aim := K.flat(aim)
	if flat_aim != Vector3.ZERO:
		facing_yaw = atan2(flat_aim.x, flat_aim.z)
	return true


## The TimeScale that fits `clip` onto `duration` seconds — the invariant every
## committed move in this file holds, that the clip's length IS the move's
## length. A missing clip scales to 1.0 rather than dividing by a guess.
##
## `skip` is the node's `start_offset`: those seconds are never played, so they
## are not part of what has to fit. Scaling off the whole length with an offset
## set runs the clip too fast and strands the hero in a finished pose for the
## rest of his lockout — the light swing skips 0.22 s of a 1.50 s clip, so
## getting this wrong would run it 17% fast. Not a rounding error.
func _clip_scale(clip: StringName, duration: float, skip: float = 0.0) -> float:
	return maxf(_clip_length(clip) - skip, 0.05) / maxf(duration, 0.05)


## A clip's length in seconds, post-TRIM (tools/build_anim_lib.gd bakes the trim
## into the resource, so this is the length of the move and not of the export).
## A missing clip answers 1.0 rather than 0.0, so a caller dividing by it gets a
## harmless scale instead of an error. One reader, because "the clip is missing"
## has to answer the same way everywhere it is asked.
func _clip_length(clip: StringName) -> float:
	if anim_library != null and anim_library.has_animation(clip):
		return anim_library.get_animation(clip).length
	return 1.0


## True while a bow or a hookshot is out. Owned by `HeroRanged`, which is the
## only thing that knows what is in his hands; the hero asks rather than
## duplicating the rule, so there is one answer and the camera, the HUD and the
## body cannot disagree about whether he is aiming.
func aiming() -> bool:
	return ranged != null and ranged.aiming


## Which ranged item is RAISED, or &"" for none. The bow and the hookshot hold
## the body in genuinely different shapes — a full draw versus a two-handed brace
## — so the stance has to know which, not merely that he is aiming.
##
## Narrower than `aiming()` on purpose, and the gap between them is the whole of
## "he goes back to a resting position after the shot": `aiming()` is true for as
## long as the item is in his hand (the camera is on his shoulder, the crosshair
## is up), while this is true only while the trigger is actually down. Drawn but
## not pulled, he stands in ordinary locomotion holding the bow — which is the
## rest pose, already authored, and it was simply never reachable while the
## stance was equipment-driven.
func aim_item() -> StringName:
	return ranged.aim_item() if ranged != null else &""


# --- The hookshot pull -------------------------------------------------------
## HeroRanged owns the raycast, the anchor and the chain; this owns the body.
## The split is the same one the rope uses — whoever decides is not whoever
## moves — and it is what keeps the hookshot out of the movement script.

## Seconds a pull is allowed to take before the hero is released regardless.
## A pull that ends against a lip the raycast could not see would otherwise root
## him forever, and being stuck is worse than arriving in the wrong place.
const HOOK_TIMEOUT_PAD := 0.6

var _hook_point: Vector3 = Vector3.ZERO
## False while the chain is still outbound and the hero is rooted; true once it
## has bitten and he is being dragged.
var _hook_travelling: bool = false
var _hook_timeout: float = 0.0


## Root the hero for the chain's flight. Refused for the same reasons a swing
## is, so a hookshot cannot be fired out of a roll.
func hook_begin() -> bool:
	if state != MoveState.GROUND and state != MoveState.ATTACK:
		return false
	state = MoveState.HOOK
	_hook_travelling = false
	_hook_timeout = 0.0
	_speed = 0.0
	velocity = Vector3.ZERO
	return true


## The head bit something. Drag him to `point` at K.HOOK_PULL_SPEED.
func hook_pull_to(point: Vector3) -> void:
	if state != MoveState.HOOK:
		return
	_hook_point = point
	_hook_travelling = true
	_hook_timeout = global_position.distance_to(point) / maxf(K.HOOK_PULL_SPEED, 0.1) \
		+ HOOK_TIMEOUT_PAD
	# Face the anchor. Being dragged backwards through the air is the single
	# clearest tell that a hookshot was bolted on rather than built in.
	var flat := K.flat(point - global_position)
	if flat != Vector3.ZERO:
		facing_yaw = atan2(flat.x, flat.z)


func hook_end() -> void:
	if state != MoveState.HOOK:
		return
	state = MoveState.GROUND
	_hook_travelling = false
	_speed = 0.0
	velocity = Vector3.ZERO


## True while the chain is out or the hero is on it. HeroRanged polls this to
## know when the pull has finished rather than being told, because the pull can
## end on arrival OR on the timeout and only the hero knows which.
func hooking() -> bool:
	return state == MoveState.HOOK


func _tick_hook(delta: float) -> void:
	if not _hook_travelling:
		# Rooted while the chain flies out. Held still rather than merely
		# unsteered: the shot reads as an aimed thing, and drifting out from
		# under your own chain looks like the anchor moved.
		velocity = Vector3.ZERO
		return

	_hook_timeout -= delta
	var to := _hook_point - global_position
	# Arrival is generous. The pull point stands off a wall by a hero radius, so
	# insisting on reaching it exactly means arriving is decided by whether
	# move_and_slide let him touch geometry — which is not a thing to hang a
	# state transition on.
	if to.length() <= 0.45 or _hook_timeout <= 0.0:
		hook_end()
		return
	velocity = to.normalized() * K.HOOK_PULL_SPEED


## Raise or drop the shield. HeroCombat owns the decision; this owns the pose.
##
## Raising it is the one cancel that does not go through a `request_*`: the guard
## is a held blend, not a one-shot, so there is nothing above the dodge in the
## tree to cover it. Without the cancel the shield came up at full weight over a
## roll that was still playing underneath — which is the exact "he slid backwards
## across the floor in a standing block pose" that `HeroCombat`'s `rolling` flag
## was written to prevent, arriving through the cancel window instead.
func set_blocking(on: bool) -> void:
	if on and not blocking:
		_cancel_dodge()
	blocking = on


## Take a blow. The ONE place damage reaches the player, so i-frames, the shield
## and knockback are decided once rather than in every attacker.
##
## Health lives in `Game` rather than a HealthComponent because it has to survive
## the scene change that extracting causes -- a component on the hero dies with
## the dungeon, and the whole point of extracting is that you keep what you had.
## The i-frame clock lives here because it is a property of the body, and the
## body is what gets replaced when a new scene loads.
##
## Returns true if the blow actually landed.
func take_hit(hit: Hit) -> bool:
	if hit == null or hit.amount <= 0 or Game.quarters <= 0:
		return false

	# **A blow ends the meal, and it ends it BEFORE anything below decides whether
	# the blow lands.** A parry or a roll he was in the middle of is a hero who was
	# never eating in the first place (both buttons are in `MEAL_BREAKERS`), so
	# there is no case where this cancels a meal the hit was going to be denied
	# by — and putting it under the parry check would mean the one blow he catches
	# on the shield is the one that lets him keep eating.
	Game.cancel_meal()

	# THE PARRY IS CHECKED FIRST, ahead of the i-frames and ahead of the roll.
	#
	# Ahead of the i-frames because a parry has to be able to catch the SECOND
	# blow of a flurry: `K.SHIELD_IFRAMES` is 0.4 s and `K.PARRY_WINDOW` is 0.2,
	# so a parry thrown at a two-hit combo would have been swallowed by the
	# immunity its own first catch granted, and the player would have watched a
	# correctly-timed press do nothing.
	#
	# It cannot collide with the roll below: `HeroCombat` refuses the press
	# unless the hero is on the ground and standing (`request_parry` goes through
	# `request_attack`, which requires MoveState.GROUND), so `parries()` is false
	# for every frame of a dive.
	if combat != null and combat.parries(hit.from):
		combat.on_parried(hit)
		_invuln = K.SHIELD_IFRAMES
		return false

	# The dodge, and the one thing that separates a PERFECT one from an ordinary
	# roll: a blow actually arrived, and the roll was fresh enough to have been an
	# answer to it. A roll thrown too early does not fail here — the blow simply
	# misses in space and never calls this at all, which is the honest version of
	# "you dodged too soon" and costs nothing to implement.
	if state == MoveState.ROLL:
		if not _perfect_spent and _roll_age <= K.DODGE_GRACE and combat != null:
			_perfect_spent = true
			combat.on_perfect_dodge(hit)
		return false
	if _invuln > 0.0:
		return false

	# The shield is a direction, not a toggle: blocking with your back turned is
	# just standing still. HeroCombat owns the arc because it owns the shield.
	if combat != null and combat.blocks(hit.from):
		Game.spend_stamina(hit.amount * K.STAMINA_BLOCK_PER_QUARTER, true)
		combat.on_blocked(hit.from, K.flat(hit.from - global_position))
		_invuln = K.SHIELD_IFRAMES
		var shove := K.flat(global_position - hit.from) * 2.4
		_set_planar_velocity(shove)
		return false

	_invuln = K.IFRAME_TIME
	# You do not get to walk out of a fight you are losing. This is the property
	# the rune pad's hold existed to protect (METAGAME §5) and the only reason
	# the rope channels at all rather than teleporting on the menu press.
	#
	# A BLOCKED blow does not break it -- that path returns above. Standing your
	# ground behind the shield while the rope works is a legitimate way to
	# leave, and it is a better one than mashing the button was.
	#
	# The Unbroken Rope (`EchoDb.UNBROKEN_ROPE`) is the one exception, and it is
	# a rule bend rather than a power: you can always leave, so you can always go
	# one room further (`docs/PUZZLES.md` §6.1, row 6). The blow still lands and
	# still costs health -- what it stops doing is interrupting the channel.
	if rope != null and not Run.has_echo(EchoDb.UNBROKEN_ROPE):
		rope.cancel()
	# Who hit him, recorded BEFORE the damage lands. `Game.damage` is what emits
	# `player_died`, and Run.die() -- which builds the ending screen's summary --
	# runs inside that emission, so a line written after this call is a line
	# written after the screen has already asked. Every blow overwrites it, which
	# is exactly right: what the screen wants is the LAST one.
	Run.last_attacker = hit.source
	# Armour never zeroes a blow. A build that cannot be hurt turns the whole
	# extraction decision into a formality.
	Game.damage(maxi(K.QUARTER, hit.amount - Game.armour_soak()))

	# --- Card #130: what the blow is worth, decided once ---------------------
	#
	# `force` is the CONTINUOUS half and drives everything the screen does; `tier`
	# is the DISCRETE half and drives what his body does. They are separate
	# because they answer different questions -- two players eating the same boss
	# slam always see the same camera, and may or may not end up on the floor.
	#
	# **Rolled exactly once, here.** `Hit.roll_tier` says so in capitals and this
	# is the reason: ask twice and the animation plays one reaction while the
	# controller times another.
	var force := hit.force()
	var tier := hit.roll_tier()

	# The shove, away from whatever threw it. Scaled by the reaction rather than
	# taken flat: a knockdown that did not also send him backwards would be a man
	# lying down where he was standing, and the clip is authored travelling.
	var away := K.flat(global_position - hit.from)
	if away == Vector3.ZERO:
		# A blow with no direction -- a pool centred on his own feet, a floor
		# spike. Thrown forward off his own facing rather than nowhere, so the
		# knockdown still has somewhere to travel.
		away = -_forward()

	# The three screen channels, all off `force`. The flat pair this replaced --
	# `HITSTOP_LIGHT` and a trauma of 0.80 -- were the whole of the complaint: a
	# goblin's jab froze the game for the same four frames as a boss's slam and
	# asked for MORE camera shake than the hero's own crit (`K.SHAKE_CRIT`, 0.72).
	Bus.request_hitstop.emit(int(roundf(lerpf(
		float(K.HURT_STOP_MIN), float(K.HURT_STOP_MAX), force))))
	Bus.request_shake.emit(lerpf(K.HURT_SHAKE_MIN, K.HURT_SHAKE_MAX, force), 0.18)
	# And the one that says WHERE, which no other cue in the game does. `away`
	# points from the impact towards the hero, which is the way his head goes.
	Bus.request_punch.emit(away, lerpf(K.HURT_PUNCH_MIN, K.HURT_PUNCH_MAX, force),
		K.HURT_PUNCH_TIME)
	Bus.hero_hurt.emit(force, tier, global_position)

	# What his BODY does. LIGHT deliberately does not enter `MoveState.HURT`: it
	# plays its reel over whatever he was doing and leaves him in charge, because
	# a floor of goblins that each root you for a quarter-second is a floor you
	# cannot move through. HEAVY and KNOCKDOWN take the controller away, which is
	# what makes them mean something.
	var shove := maxf(hit.knockback, 0.0) * Hit.knock_scale(tier)
	if tier == Hit.Tier.LIGHT:
		_fire_flinch(false, K.HURT_LIGHT_TIME)
		# A nudge and not a slide. He still has the stick, so a shove that
		# persisted would be the game and the player steering the same body in
		# two directions -- and `_tick_ground` bleeds residual speed along his
		# FACING, which points at whatever just hit him. One frame of velocity is
		# what a jab is worth.
		_set_planar_velocity(away * shove)
		_speed = 0.0
	else:
		# **The shove is applied AFTER `_enter_hurt`, which ends by zeroing
		# `_speed`.** Written before it, the whole knockback was silently deleted
		# one line later and the hero was knocked flat exactly where he had been
		# standing -- which reads as fainting rather than as being hit.
		_enter_hurt(tier, hit.stun)
		_hurt_dir = away
		_speed = shove
		_set_planar_velocity(away * shove)
	# WHERE it came from, which nothing else on the bus carries. The HUD draws one
	# arc at that bearing (HUD_PLAN decision 36) in place of the full-screen red
	# wash this used to get. Emitted here and not earlier on purpose: every branch
	# above is a blow the player ANSWERED, and an arc for a parried hit would be
	# the game arguing with them about what just happened.
	#
	# **After `hero_hurt`, and the HUD depends on that.** `Hud._on_hero_hurt`
	# banks the force and `Hud._on_hero_struck` is what actually starts the arc,
	# so swapping these two lines would draw every arc at the PREVIOUS blow's
	# weight. See `Hud.ARC_SPAN`.
	Bus.hero_struck.emit(hit.from)
	return true


func is_invulnerable() -> bool:
	return _invuln > 0.0


## Hand the hero i-frames a MOVE has earned, rather than ones a blow granted.
##
## The clock is the same one `take_hit` writes after a hit and reads before
## everything except the parry and the roll, which is the whole reason this is a
## setter and not a second timer: a move-granted immunity and a hit-granted one
## are the same fact about the body, and two clocks would mean two places to ask
## and one of them eventually gets forgotten.
##
## NEVER SHORTENS. `maxf`, not assignment: the caller is a swing that lasts a
## fraction of `K.IFRAME_TIME`, so a bare write would mean a hero who riposted
## right after taking a hit threw away most of the second the hit bought him —
## a reward that makes you MORE killable, which is the exact opposite of what a
## window a player earned is for.
##
## The roll does not come through here. Its immunity is read off
## `state == MoveState.ROLL` in `take_hit` and so ends with the dive whatever
## the clock says, which is correct for a move that can be cut short. A swing
## cannot be cut short by the player, so a clock is enough for it — with one
## exception worth knowing about: `end_commitment` hands the hero back early
## after a landed parry, and i-frames granted before that call would outlive the
## move. Nothing does that today (the parry grants none), and anything that
## starts to must clear them itself.
func grant_iframes(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)


func skeleton() -> Skeleton3D:
	if _rig == null:
		return null
	return _rig.find_child("Skeleton3D", true, false) as Skeleton3D


## The recovery. OOT's roll commits — you cannot cancel it into a RUN, and that
## is exactly why it reads as a move and not as a dodge-cancel. What you can do,
## in the last `dodge_cancel_time` of it, is commit to something else: swing,
## parry, guard, draw, dodge again, jump. See `dodge_cancel_time` for why those
## two halves are not the same permission.
##
## The two cancels handled HERE are the ones that are not `request_*` calls —
## another dodge and a jump. They are tried in `_tick_ground`'s order, and for
## `_tick_ground`'s reason: the dodge is the discrete move and gets first
## refusal, and both bail out of the bleed below rather than falling through it,
## because `_set_planar_velocity` at the end of this function would otherwise
## overwrite the velocity the new move just set.
func _tick_roll_recover(wish: Vector3, mag: float, delta: float) -> void:
	if dodge_cancellable():
		if _try_start_roll(wish, mag):
			return
		if _try_start_jump():
			return
	_state_timer -= delta
	_track_lock(delta)
	_speed = move_toward(_speed, 0.0, decel * 1.6 * delta)
	# Along the roll, not along the facing. Locked or guarding those differ, and
	# a backstep that bled along the facing would coast the hero straight back
	# into the thing he just dodged away from.
	# Read off the flag captured when the roll STARTED, not off `blocking` now:
	# the shield comes down for the roll (hero_combat drops it, so the dive is
	# not played underneath a block pose), and asking the live flag here would
	# make every guarded backstep bleed along a facing it was dodging away from.
	_set_planar_velocity((_roll_dir if _roll_keeps_facing else _forward()) * _speed)
	if _state_timer <= 0.0:
		state = MoveState.GROUND
		roll_finished.emit()


# --- Helpers ----------------------------------------------------------------

func _forward() -> Vector3:
	return Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))


func _steer_to(dir: Vector3, rate_deg: float, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var want := atan2(dir.x, dir.z)
	var err := wrapf(want - facing_yaw, -PI, PI)
	var step := deg_to_rad(rate_deg) * delta
	facing_yaw += clampf(err, -step, step)


func _set_planar_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


func _apply_gravity(delta: float) -> void:
	# The jump is applied HERE, not by the code that decided to jump, and this is
	# not tidiness — it is the only place it survives. `is_on_floor()` reports the
	# LAST move_and_slide, so on the frame a jump starts it is still true, and the
	# -0.5 clamp below would overwrite the launch velocity before the body ever
	# moved. The hero would play a full jump animation standing on the floor.
	if _jump_impulse > 0.0:
		velocity.y = _jump_impulse
		_jump_impulse = 0.0
		return
	# The slam OWNS its vertical, and gravity is not consulted for either half of
	# it. The hang is a hard zero rather than a small upward push, because the one
	# thing the pose has to say is "this is deliberate" and a hero still drifting
	# up through his own wind-up says the opposite; the drive is a hard speed
	# rather than an impulse, so a slam from a ledge arrives at the same speed as
	# one from a hop and the impact is worth the same both times.
	if state == MoveState.SLAM and not _slam_landed:
		velocity.y = 0.0 if _slam_hang_left > 0.0 else -slam_speed
		return
	if is_on_floor():
		# A whisker of downward bias so floor_snap_length keeps him welded to
		# the ledge steps instead of launching off each one.
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta


func _after_move(pre_fall: float, delta: float) -> void:
	if is_on_floor():
		# A slam's touchdown is its own event and it is not conditional on
		# `coyote_time` the way an ordinary landing is: the hero committed to this
		# one, and a slam thrown a hand's breadth off the floor still has to go
		# off. Handled before the block below so the ordinary landing sees a hero
		# who has already dealt with his own arrival.
		if state == MoveState.SLAM and not _slam_landed:
			_land_slam(absf(minf(pre_fall, 0.0)))
		if _airborne_time > coyote_time:
			var fall := absf(minf(pre_fall, 0.0))
			landed.emit(fall)
			# `landed` still fires for a jump — the dust, the sound and the camera
			# all want it. The Land CLIP does not: a jump plays one clip that
			# already contains its own touchdown and recovery (build_anim_lib's
			# TRIM cuts it at the end of the recovery, not at the end of the leap),
			# so firing Land over it lands the hero twice.
			if fall > 2.5 and not _jumping:
				_fire(_P_LAND)
		# Arm the tail cut on the touchdown frame, while `_jumping` still says this
		# was a leap he chose. An ordinary fall has no jump one-shot to cut.
		if _jumping:
			_jump_cut = jump_land_time
		_airborne_time = 0.0
		_air_fired = false
		_jumping = false
	else:
		var was := _airborne_time
		_airborne_time += delta
		if was <= coyote_time and _airborne_time > coyote_time and not _air_fired:
			_air_fired = true
			_fire(_P_AIR)

	rotation.y = facing_yaw + PI
	_tick_jump_cut(delta)
	_emit_footsteps(delta)


## Cut a jump clip's landing recovery short once the player wants the body back.
## See `jump_land_time` for why the tail is ~0.57 s long in the first place.
##
## THE INPUT TEST IS THE WHOLE DESIGN, and it is why this is not simply a shorter
## clip. A hero who lands and stands there should finish the landing — it is a
## good pose and nothing is waiting on it. A hero who lands running, swinging or
## rolling has already been given control and should look like it. So the cut
## fires on the first frame after the hold in which he is doing something, and
## a player who never asks gets the clip as authored.
##
## `_jump_cut` is not cleared when the test fails, only when it fires: the ask
## can arrive at any point in the tail, and a cut that expired at
## `jump_land_time` would only ever catch a player who was already moving on the
## landing frame. Once the clip ends on its own the request is a no-op, which is
## what retires it in the standing case.
func _tick_jump_cut(delta: float) -> void:
	if _jump_cut < 0.0:
		return
	# Clamped at zero rather than left to run negative, because negative is the
	# "nothing owed" sentinel this function opens on: decremented past it, an
	# armed cut would disarm itself one frame after the hold expired and only
	# ever catch a player who was already moving on the landing frame.
	_jump_cut = maxf(_jump_cut - delta, 0.0)
	if _jump_cut > 0.0:
		return
	if state == MoveState.GROUND and stick_neutral():
		return
	_fade_out(_jump_param)
	_jump_cut = -1.0


## Distance-driven rather than animation-driven: the shared 72-clip library is
## read-only (docs/CONTRACT.md §2), so it carries no Call Method tracks we could
## key a footfall to. Accumulating ground covered gives the same cadence, scales
## with speed for free, and stays deterministic for screenshots.
func _emit_footsteps(delta: float) -> void:
	if not is_on_floor() or state == MoveState.ROLL:
		_stride_accum = 0.0
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < K.WALK_SPEED * 0.35:
		_stride_accum = 0.0
		return
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	_stride_accum += planar * delta
	var stride := lerpf(stride_walk, stride_run, speed01)
	if _stride_accum >= stride:
		_stride_accum -= stride
		footstep.emit(global_position, speed01)


func _fire(param: String) -> void:
	if _tree != null:
		_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Blend a one-shot back out over its own `fadeout_time`, as if its clip had just
## ended. The counterpart to `_fire`, and until the dodge cancel there was no
## caller for it — every commitment in this file ran its clip to the end.
##
## FADE_OUT and not ABORT, and they are not interchangeable: ABORT drops the node
## to zero weight on the frame it is set, which on a dodge is the hero snapping
## from a crouched roll-out to a standing idle in one frame. Aborting is right
## for a pose nobody should see the end of; there is nothing like that here.
func _fade_out(param: String) -> void:
	if _tree != null:
		_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _drive_animation(delta: float) -> void:
	if _tree == null:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	# Loco's axis now runs to the SPRINT speed, so the clamp has to as well —
	# left at run_blend_speed the fourth blend point would be unreachable and the
	# sprint clip would never play a frame.
	_tree.set(_P_BLEND, clampf(planar, 0.0, sprint_blend_speed))
	# The aim stance rides the same speed axis, so a strafe at the shoulder blends
	# through the aim-walk at the pace the sword stance would have walked at.
	_tree.set(_P_AIM_BLEND, clampf(planar, 0.0, run_blend_speed))
	var speed01 := clampf(planar / K.RUN_SPEED, 0.0, 1.0)
	_tree.set(_P_STRIDE, lerpf(stride_scale_idle, stride_scale_run, speed01))

	# The stances ease in and out with the camera, not instantly: drawing the bow
	# is a move he makes, and the rig sliding to the shoulder over a body that
	# snapped into a full draw a frame earlier reads as two unrelated events.
	#
	# Two independent amounts rather than one and a clip swap, for the reason the
	# two shot one-shots are separate: a live AnimationNodeAnimation whose clip is
	# reassigned restarts the mixer's cache mid-blend.
	var item := aim_item()
	_ease_blend(_P_AIM, 1.0 if item == &"bow" else 0.0, delta)
	_ease_blend(_P_AIM_HOOK, 1.0 if item == &"hookshot" else 0.0, delta)

	# The shield eases in and out rather than snapping, so raising it is a
	# visible action instead of a costume change between frames.
	var want := 1.0 if blocking else 0.0
	var now: float = _tree.get(_P_BLOCK)
	_tree.set(_P_BLOCK, move_toward(now, want, delta / maxf(block_fade, 0.01)))

	# Sitting down and getting back up, on the same easing and off `Game.eating()`
	# rather than off an edge. A flag polled every frame cannot be left stuck by a
	# missed signal, a scene change or a load — and a hero frozen in a crouch with
	# no meal running is the exact failure this pose could ship.
	var sit_now: float = _tree.get(_P_REST)
	_tree.set(_P_REST, move_toward(sit_now, 1.0 if Game.eating() else 0.0,
		delta / maxf(rest_fade, 0.01)))

	# The wind-up pose, eased the same way. `charging` is set by HeroCombat every
	# frame the button is down; it is a flag rather than a request because the
	# hold has no duration anybody knows in advance.
	var pose_now: float = _tree.get(_P_CHARGE)
	_tree.set(_P_CHARGE, move_toward(pose_now, 1.0 if charging else 0.0,
		delta / maxf(charge_pose_fade, 0.01)))
	# Re-parked every frame of the hold rather than once on the edge. The request
	# is consumed by the tree the frame it lands, and it costs one float — against
	# a whole class of bug where a rebuild, a blend restart or a missed edge
	# leaves the pose showing the wrong frame with nothing to say so.
	if charging:
		_tree.set(_P_CHARGE_SEEK, charge_pose_time)

	_drive_model_yaw(delta)


## The model's own yaw. Its correction is a fixed 180 (see `model_yaw_offset`)
## and does not vary with speed — the only thing that ever moves it off that is a
## sideways roll, which points the dive without turning the body underneath it.
##
## The unwind runs everywhere EXCEPT the roll itself, rather than only during the
## recovery, so a roll cut short by a hit, a scene change or a death cannot leave
## the hero permanently walking crabwise. Costs one comparison a frame; the class
## of bug it removes is the kind that only ever shows up in someone's recording.
func _drive_model_yaw(delta: float) -> void:
	if state != MoveState.ROLL and _dodge_model_yaw != 0.0:
		_dodge_model_yaw = move_toward(_dodge_model_yaw, 0.0,
			deg_to_rad(dodge_unwind_deg) * delta)
	if _model != null:
		_model.rotation.y = deg_to_rad(model_yaw_offset) + _dodge_model_yaw


## Walk a Blend2's amount toward `want` over `aim_fade` seconds.
func _ease_blend(param: String, want: float, delta: float) -> void:
	var now: float = _tree.get(param)
	_tree.set(param, move_toward(now, want, delta / maxf(aim_fade, 0.01)))
