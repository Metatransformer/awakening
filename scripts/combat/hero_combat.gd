class_name HeroCombat
extends Node3D
## The hero's sword, shield, and held item — the models, the swing, and the box
## that actually hurts things.
##
## Added as a child of the Hero by hero.gd. It keeps combat out of the movement
## script while still driving the hero's states, because the two genuinely are
## coupled: you cannot steer freely mid-swing, and that commitment is most of
## what makes a swing feel like it weighs something.
##
## Sockets are BoneAttachment3D on the real rig bones. The offsets below were
## found by RENDERING, not by arithmetic: the rig's rest pose is expressed in a
## rotated FBX space, so the bone matrices read as nonsense if you try to reason
## from them. tools/directors/p4_combat.gd is what settled each number.
##
## Note the scale compensation in `_mount`. The Model node is scaled by
## K.HERO_SCALE (1.65) to lift a 1.0-unit rig to adult height, and anything
## parented under a bone inherits that. A 0.92 m sword would otherwise render at
## 1.52 m — a greatsword — which is exactly the kind of error that looks like an
## art problem and is really a transform problem.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

## What the player asked for. Deliberately coarser than Hero.Swing: WHICH light
## swing a LIGHT becomes — step 1, 2 or 3 — is this script's decision, made from
## the chain state. Buffering an Intent rather than a Swing is what lets a press
## made during step 1 still become step 2 when it is finally honoured.
##
## LIGHT is RB. HEAVY is RT, and each Intent advances its own combo. Buffering an
## Intent rather than a concrete swing is what lets a Heavy release made during
## the opener become the overhead when it is finally honoured.
##
## SPIN is not a button either. It is what the trigger's HOLD releases into.
## DASH is the earned riposte counter. The same blade move is also step one of
## the Heavy combo, but that route remains HEAVY so it can advance the dedicated
## two-step chain. They stay Intents because the buffer is what makes them honest:
## a charge released during the swing that started it has to come out when that
## swing ends, not vanish.
## SLAM is the light button pressed in the AIR, and it is the one Intent that is
## never buffered: it is only legal while the hero is off the floor, and a press
## honoured two swings later would fire it at a hero standing still. See `_press`.
##
## PARRY is the light button pressed from behind a raised shield — the input the
## DASH used to have. It is the SECOND never-buffered Intent, and for a sharper
## version of the slam's reason: a parry is a claim about WHEN, and a claim about
## when that is honoured a third of a second late is not a late parry, it is a
## different one. See `_press`.
##
## The dash has two homes: step one of Heavy, and an attack press inside
## `_riposte_t`, the window a successful parry opens. Only a counter backed by
## that earned window carries i-frames for its whole duration. See `_dash_swing`.
##
## FLURRY is the leaping overhead, and it is what an attack press means in the
## window a PERFECT DODGE opens (`_flurry_t`). Not buffered either: the window it
## belongs to is short and running on a clock the buffer knows nothing about.
enum Intent { LIGHT, HEAVY, SPIN, DASH, SLAM, PARRY, FLURRY }

## Read `attack` with exact modifier matching. THIS IS WHAT MAKES THE HEAVY A
## SEPARATE BUTTON ON THE KEYBOARD, and without it the strong attack is unusable.
##
## `attack` is plain LMB and `heavy` is Shift+LMB (Elden Ring's layout). Godot
## does NOT treat those as two bindings that exclude each other: a modifier'd
## press matches the unmodified action too, and records the mismatch as a
## separate `exact` flag rather than as a failure to match. Probed on 4.7 rather
## than remembered — the numbers are in project.godot's note on `heavy`:
##
##     pressed LMB        attack loose=true  exact=true    heavy=false
##     pressed Shift+LMB  attack loose=true  exact=FALSE   heavy=true
##
## So the default loose read fires the light chain on every strong attack, and
## the player gets both swings for one click.
##
## IT IS SAFE FOR THE PAD AND FOR THE DIRECTORS, which is the only reason it can
## be a blanket rule instead of a keyboard special case: an InputEventJoypadButton
## has no modifier mask to mismatch, so RB reports exact=true, and so does a bare
## `Input.action_press(&"attack")` — the path every harness in tools/directors
## uses. Both were probed alongside the two lines above.
##
## `heavy` is NOT read exactly. Nothing else is bound to Shift+LMB, so there is
## no press it needs to reject, and reading it loosely means a player who is also
## holding some other modifier still gets their swing.
const ATTACK_EXACT := true

## Pitch multiplier per chain step. Two rises, three drops — the chain should
## sound like it is going somewhere, and the finisher is the heaviest thing in
## it. Cheapest honest way to make three swings read as one sentence.
const _CHAIN_PITCH: Array[float] = [1.0, 1.08, 0.86]

@export_group("Loadout")
@export var sword_id: String = "sword_knightly"
@export var shield_id: String = "shield_noble"
@export var bow_id: String = "bow_knightly"
@export var hookshot_id: String = "hookshot_pistol"

@export_group("Sword")
## HP per slash.
@export var damage: int = 2
## Seconds the whole swing owns the hero. The clips are 1.4-2.4 s, far too slow
## for OOT, so they are time-scaled onto this — `Hero.request_attack` divides the
## clip length by this number, so raising it slows the ANIMATION, not just the
## lockout, and `chain_time_scale` carries the change into steps 2 and 3.
##
## Was 0.46, and at that pace the chain read as a blur: three clips averaging
## 1.9 s each, crushed into roughly a second, and the finisher's leaping overhead
## in particular went past before you could see it was an overhead. 0.60 is that
## +30%. The damage windows are fractions of this, so the blade's live slice
## stays in the same place in the swing and the hit timing is unchanged in feel.
@export var swing_time: float = 0.60
## The slice of the swing during which the blade can hurt something, as
## fractions of swing_time. Before it is the wind-up, after it is the recovery.
@export var damage_window := Vector2(0.22, 0.62)
## Reach from the hero's centre, metres. The blade is 0.92 m and the arm adds.
@export var reach: float = 1.35
@export var arc_degrees: float = 130.0
@export var knockback: float = K.KNOCKBACK_LIGHT

@export_group("Heavy")
## The Heavy combo finisher — the swing the light chain also keeps behind two
## other presses. It plays Hero.Swing.LIGHT3, a leaping overhead, which is why it
## is slow: at the light chain's pace a 2.4 s clip goes past as a twitch.
##
## Priced at 4 HP, level with the lunge and under the spin. What it costs
## is the second of commitment and K.STAMINA_HEAVY, which is more than twice a
## light swing — the whole point of an Elden Ring stamina bar is that the big
## button is the one you cannot lean on.
@export var heavy_damage: int = 4
@export var heavy_swing_time: float = 0.99
## Later and narrower than the light window: the clip leaps before it lands, so a
## window opened at the light's 0.22 puts the blade live while he is still in the
## air on the way up.
@export var heavy_damage_window := Vector2(0.34, 0.68)
@export var heavy_knockback: float = K.KNOCKBACK_HEAVY

@export_group("Spin")
## Seconds the trigger must be HELD before the release becomes a magic spin.
## Under it, the release advances the Heavy combo; this is the line between the
## two paths.
##
## It is also, therefore, the worst-case latency on a tapped heavy, which is why
## it is 0.42 and not the half-second a "charge" usually is. Nobody holds a tap
## for four tenths of a second; the real cost on a tap is however long the finger
## is actually down, which is a frame or three. What 0.42 buys is the other side:
## a threshold short enough that committing to the spin does not feel like
## waiting, and long enough that a hurried press cannot fall into it by accident.
@export var charge_time: float = 0.42
## 5 HP, against the light swing's 2 HP. The spin is worth the
## commitment or nobody presses it twice.
##
## Note that this is what EVERYONE in the circle takes. The spin is not priced as
## a bigger single blow — it is priced as this blow, delivered to a room.
@export var spin_damage: int = 5
## Longer than any other swing in the kit. This number IS the cost — the whole
## trade is that you are unsteerable and unable to guard for this long.
##
## It ENDS BEFORE THE EFFECT DOES, on purpose. `SpinVfx` lays its arc down over
## 0.48 s — starting on the release frame, so the ring is now well ahead of this
## lockout rather than a hair behind it — and the motes it leaves live another
## half-second in world space, which is what still puts the last of the circle at
## ~1.0 s against this 0.523. The hero has his feet back while the circle behind
## him is burning; the lag is the mote lifetime, not the sweep rate. That
## split second is not sloppiness, it is the read: the magic lags the sword, the
## way it does in the game this is taken from. A lockout that outlasted the
## effect would make the recovery feel like the cost of the picture rather than
## the cost of the blow. [tune]
##
## Sped up 30% from 0.68 (2026-08-10): the release read as a stall. The mote lag
## above widens as a result — the sword is now further ahead of its own magic —
## which is the same read, only stronger. The window below is fractional, so the
## live slice scales with this and needs no edit.
@export var spin_swing_time: float = 0.523
## The live slice, as fractions of spin_swing_time. It opens LATE and stays open
## LONG, which is the opposite shape to every other swing here and is the whole
## point: the blade is genuinely travelling through 360 degrees, so the window
## has to be wide enough to still be open when the far side of the circle comes
## round. Measured against the clip — the sweep peaks at 0.87 s of a 1.35 s
## trim, which lands at 0.64 of the way through (tools/_clip_motion.gd).
@export var spin_damage_window := Vector2(0.34, 0.86)
@export var spin_knockback: float = K.KNOCKBACK_HEAVY
## How far the circle reaches, metres from the hero's centre. Wider than the
## sword's forward `reach` (1.35): a spin that only caught what a standing swing
## would have caught is a worse standing swing that costs you a hold.
##
## 2.1 m is a little over one enemy's width past the blade's tip, which is the
## distance a second attacker stands off at while the first one is engaging.
## Catching that second attacker IS the move.
@export var spin_reach: float = 2.1
## Degrees of arc the blade is credited with. 360 means the direction test in
## `_maybe_hit` never rejects anything, which is what makes this the one attack
## in the kit you cannot be behind. [tune]
@export var spin_arc: float = 360.0

@export_group("Combo")
## Seconds after a swing ends during which another press continues the chain
## instead of starting a new one. Short enough that you cannot wander off and
## come back to a finisher; long enough that the chain is not a rhythm test.
@export var chain_window: float = 0.34
## Fraction of the current swing after which a press is REMEMBERED rather than
## dropped. Before it, an input is the player mashing; after it, they have seen
## the swing and are asking for the next one. This buffer is the whole difference
## between a chain that obeys you and one that eats inputs made a frame early.
@export var chain_buffer_from: float = 0.35
## Seconds a press made DURING A DODGE stays owed ON TOP of the dodge it is
## waiting out. **Zero switches the dodge buffer off entirely** — which is what
## `tools/directors/dodge_cancel.gd` sets for its null case, because the buffer
## off is the game exactly as it was before this existed.
##
## A dodge is 0.82 s of hero (`K.ROLL_TIME` + `Hero.roll_recover_time`) and until
## now a press made anywhere inside it was EATEN, not owed: `_press` only buffered
## while a swing was already running, so `Hero.request_attack` refused and the
## input went nowhere. That is the larger half of "the roll takes too long" —
## the player presses attack coming out of a dodge, gets silence, and presses
## again, so the recovery reads as roughly twice its real length.
##
## GRACE, and not the whole lifetime, and the difference is the bug it fixes.
## This was a flat 0.25 s "how long a press stays owed", which sounds right and
## is not: the wait a press has to survive is however much dodge is left, and a
## swing pressed 0.30 s into a 0.82 s dodge needs 0.38 s of patience. It timed
## out 0.08 s short and was dropped — the buffer was there and the press still
## vanished. So the lifetime is `Hero.dodge_cancel_in()` (the hero is the only
## thing that knows it) and this is the slack on the far end: enough that a
## window arriving into a hitstun, a prompt or a landing does not throw the press
## away, short enough that it cannot come out at a fight that has moved on. [tune]
@export var dodge_buffer_grace: float = 0.20
## Multipliers on swing_time for steps 2 and 3. Two is faster than one — a chain
## should accelerate — and three is much slower, because it is the one that
## hurts AND because its clip is a 2.4 s leaping overhead: at step two's pace the
## whole slam would go past in a third of a second and read as a twitch.
@export var chain_time_scale := Vector2(0.92, 1.65)
## Extra HP on the finisher, and the shove it delivers. The payoff
## for landing three in a row instead of backing off after one.
@export var chain_finisher_bonus: int = 2
@export var chain_finisher_knockback: float = K.KNOCKBACK_HEAVY

@export_group("Dash")
## The Heavy combo's short turning opener, also reused by the earned riposte.
## It is not a better light swing and it is not the magic spin: what it buys is
## that it CLOSES without a lock. Priced between the two.
@export var dash_damage: int = 3
## Shorter than a spin (0.90). The commitment is most of the cost, because the
## drive has already thrown the hero somewhere he did not have to be.
##
## It used to sit clearly between a light (0.46) and the charged release; the
## light slowed to
## 0.60 and this did not follow, because the dash is one clip and not part of the
## chain the slowdown was for. So it is now barely longer than a light — the
## drive still prices it, but if it starts reading as free, this is the number.
## [tune]
@export var dash_swing_time: float = 0.62
## Opens after the drive has ended (see dash_drive_time), so the point lands at
## the END of the lunge. Live earlier and the thrust sweeps through everything it
## travelled past, which is a spin attack wearing a thrust's clip.
@export var dash_damage_window := Vector2(0.34, 0.60)
## A thrust does not launch. Shoving the enemy away is also self-defeating here —
## the whole move was about closing the gap that the knockback would reopen.
@export var dash_knockback: float = K.KNOCKBACK_LIGHT
## Seconds of forward drive, and how fast. 0.20 s at 8.0 m/s is 1.6 m of closing:
## about one enemy's width, which is the gap a guarded player actually stands
## off at. Fast enough to read as an explosion out of the guard rather than a
## walk. [tune]
@export var dash_drive_time: float = 0.20
@export var dash_speed: float = 8.0

@export_group("Slam")
## The air slam's blow. It is the heaviest single hit in the kit — 1 HP
## more than the charged spin — and it is priced that way on purpose: it costs a
## jump to reach, it cannot be aimed once committed, and `slam_recover` roots the
## hero on the floor afterwards with no roll out of it. Everything else in here
## can be thrown from where you already are. [tune]
@export var slam_damage: int = 6
## Metres of the circle it damages, measured from the hero's feet. Deliberately
## wider than the spin's 2.1: the spin is a blade at arm's length and this is the
## FLOOR moving, so the thing that hits you is not the weapon.
@export var slam_radius: float = 2.6
## What the dust reads as, which is not what the damage is. The ring is drawn a
## little past the edge of the blow — a shockwave whose visible crest stops
## exactly where the damage does reads as a hitbox, and a player who takes the
## picture literally will stand a hand's width outside it and be right.
##
## The direction of the lie matters: the FX is wider than the damage, never
## narrower. Wide, a player who dodges the visible edge is safe and the effect
## simply looks generous; narrow, a player standing clearly outside the dust
## takes a hit he had every reason to think he had avoided.
@export var slam_fx_radius: float = 3.1
## Everything it hits goes flying. Same as the spin's — the two are the kit's
## "get off me" moves and a crowd that scatters differently from each would make
## one of them feel weaker than its damage says it is.
@export var slam_knockback: float = K.KNOCKBACK_HEAVY
## Seconds the victims are stunned. The spin does not stun and this does, which
## is the other half of what the recovery buys back: the hero is rooted for
## `slam_recover` (0.42), so without a stun the slam's own reward would be a ring
## of enemies free to hit him while he stands in his own dust.
@export var slam_stun: float = 0.5

@export_group("Shield")
## Half-angle of the block cone, degrees. A blow from outside it is not blocked.
@export var block_cone: float = 70.0
## Half-angle of the PARRY cone, degrees. Tighter than the block, and that is the
## only thing about the parry that is harsher than the guard it comes out of.
##
## A block is a wall — it is reasonable for it to stop anything the shield is
## roughly pointed at. A parry is a meeting: the hero throws the shield at one
## specific thing, and catching a blow arriving from 65 degrees off that would
## read as the game being generous with a move that is supposed to be a read.
## Still wide enough that aiming is not the skill being tested; the timing is.
@export var parry_cone: float = 45.0

@export_group("Flurry")
## The leaping overhead thrown out of a perfect dodge. It is the biggest single
## sword blow in the kit outside the slam, and it should be: the price is the
## hardest defensive read in the game, and a reward smaller than the charged spin
## would make the correct play "dodge, then do the thing you could always do".
@export var flurry_damage: int = 5
## Longer than the lunge's 0.78, because this leap carries its own anticipation
## crouch (`Hero.clip_flurry`) where the lunge's clip does not. It is also thrown
## in slow motion more often than not, so the wall-clock cost is smaller than the
## number looks. [tune]
@export var flurry_swing_time: float = 1.02
## Opens at 0.57 because that is where `ex_jump_attack` strikes — 1.20 of its
## 2.10 — and the window was fitted to the clip rather than the clip to the
## window. See `Hero._SWING_START_OFFSET` for why that direction round.
@export var flurry_damage_window := Vector2(0.57, 0.74)
## It LAUNCHES, and that is most of the payoff. `K.KNOCKBACK_HEAVY` is weight 1
## on the impact scale, so a goblin caught by this goes up nearly every time
## (docs/BESTIARY.md §3.5) — which is precisely the "sent flying" this whole
## reaction system exists for, arriving on the move you had to earn.
@export var flurry_knockback: float = K.KNOCKBACK_HEAVY
## Seconds of forward drive and the hop off the floor. The drive is longer than
## the lunge's 0.24 because the leap is higher and the clip spends real time in
## the air. See `Hero.request_flurry`.
@export var flurry_drive_time: float = 0.34
## Metres per second UP, and it is priced against the clip rather than picked.
## `K.GRAVITY` is 22, so 5.5 buys 0.69 m of rise and about half a second of air —
## which puts touchdown a breath BEFORE `flurry_damage_window` opens at 0.57, so
## the blow reads as the landing rather than as a swing taken in mid-air. It
## started at 2.4, matching the lunge's hop, and 2.4 is 0.13 m: a jump attack
## that never visibly left the floor. [tune]
@export var flurry_hop: float = 5.5
## How far short of the target the leap aims to land, metres. Also doubles as the
## stride when there is genuinely nothing in front — see `Hero.request_flurry`.
@export var flurry_stop_short: float = 1.5
## How far and how wide the leap looks for something to land on when the player
## is not locked on, which after a dodge is most of the time. See `_leap_target`.
@export var flurry_seek_range: float = 6.0
@export var flurry_seek_cone: float = 75.0

@export_group("Audio")
@export var sfx_swing: AudioStream = preload("res://audio/sfx/swing.ogg")
@export var sfx_impact: AudioStream = preload("res://audio/sfx/weapon_impact_sword_1.ogg")
# THE BLOCK SOUND IS NOT HERE. `on_blocked` emits `Bus.shield_blocked` and `Sfx`
# owns which clang that is (`shield_block`), because a sound that only ever plays
# on a signal the whole game can hear belongs in the table with the rest of them.
## The wind-up hum, started on the PRESS and cut on the release. It is a rise
## that reaches full body at about 0.35 s, which is why `charge_time` (0.42) can
## stay where it is: the sound is all the way up a hair before the charge arms.
##
## Stopped rather than left to finish, and that matters — the stream is 1.9 s
## against a 0.42 s hold, so a hum allowed to run out would still be winding up
## a second after the spin it belonged to had already landed.
@export var sfx_charging: AudioStream = preload("res://audio/sfx/sword_charging.ogg")
## The release: the sword, and the hero.
##
## BOTH play on the release and NEITHER plays when the charge arms, which is the
## fix to the thing that was wrong here. The yell used to fire the instant the
## hold passed `charge_time` — so the hero shouted while standing still, holding
## a button, and then swung in silence. A yell is the sound of effort being
## spent, not of effort being stored.
##
## What tells the player the charge is READY is now entirely visual: the blade
## takes on light and starts pulling motes in (SpinVfx). That is a better tell
## than the ping was — it is legible at a glance, it is legible WHILE you are
## reading the room, and it does not go off in a corridor you were sneaking down.
@export var sfx_spin: AudioStream = preload("res://audio/sfx/sword_release.ogg")
@export var sfx_yell: AudioStream = preload(
	"res://audio/sfx/weapon_full_charge_voice_male_1.ogg")
## The right hand changing what is in it -- the blade going onto the hip, the bow
## coming off the back. `equip.ogg` is the leather-and-buckle sound the pickup cue
## already uses, which is the right family: a weapon swap is gear being handled,
## not a swing.
##
## It matters more than a swap sound usually would, because D-pad ← / → are the
## one input in the game with NO other feedback on a controller: the model
## changes in the corner of the eye and the HUD cell changes off-screen. The
## sound is what tells a player mid-fight that the press landed.
@export var sfx_swap: AudioStream = preload("res://audio/sfx/equip.ogg")

## True while the swing is inside its damage window.
var swinging: bool = false
var blocking: bool = false
## True once the attack button has been held past `charge_time`. Public so the
## HUD and a director can both see the wind-up without timing it themselves.
var charged: bool = false

## Which item is in the hero's hands right now, or &"" for sword and shield.
var equipped: StringName = &""
var _hero: Hero
var _skel: Skeleton3D
## The mounted models. Public so a director can sweep their placement.
var sword: Node3D
## The water-sheet sword ribbon. Public so its proof director can distinguish
## each accepted stroke from moves that happen to use the same sword or clip.
var slash_trail: SwordSlashTrail
## The same blade, on his hip. Exactly one of this and `sword` is visible, and
## the pair is what makes "the bow is out" read as a place the sword WENT rather
## than as the sword ceasing to exist — which is what drawing the bow used to
## look like.
##
## THERE IS NO SHEATHE BUTTON and this is not one: the hip is simply where the
## sword lives while the hand is full, derived from `equipped` every repaint. X
## was a sheathe toggle for one afternoon, and it went when the weapon ring
## arrived -- with ← / → stepping through the weapons you own, "put the sword
## away" is a direction, and a button whose whole job is a look is a button on a
## pad that has better uses.
var sword_stow: Node3D
var shield: Node3D
var bow: Node3D
var hookshot: Node3D
## Utility-only right-hand mount. It has no item id and is never read by the
## weapon cycling code below.
var woodsman_axe: Node3D
var pickaxe: Node3D
var _utility_models: Dictionary[StringName, Node3D] = {}
var _active_utility_tool: StringName = &""
## id -> {"hand": Node3D, "stow": Node3D}. Exactly one of the pair is visible.
var _items: Dictionary = {}
## Exact mounted-model visibility while a presentation temporarily clears the
## hero's silhouette. Kept here because the sockets are children of `_skel`, not
## of this component, so hiding `HeroCombat` itself does not hide the gear.
var _presentation_visibility: Dictionary = {}
var _utility_visibility: Dictionary = {}
var _hitbox: Area3D
var _swing_t: float = -1.0
## The numbers of the swing currently in flight, captured when it starts. A
## swing has to finish on the terms it began on — reading the exports live would
## mean a spin that landed while `equipped` changed could pay out light damage.
var _swing_dur: float = 0.0
var _swing_window := Vector2.ZERO
var _swing_damage: int = 0
var _swing_knock: float = 0.0
## Seconds the victim reels. Captured per swing beside the knockback because it
## is the same KIND of number -- what the blow does to the body rather than to
## its health -- and because it was the one of the three that never existed. See
## K.STUN_LIGHT for what its absence looked like.
var _swing_stun: float = K.STUN_LIGHT
var _swing_hitstop: int = K.HITSTOP_LIGHT
## The arc this swing is allowed to reach around, degrees. Captured like every
## other number above, and for the same reason: the spin reshapes the hitbox on
## its way out, and a swing that read `arc_degrees` live would be judged against
## whatever the LAST swing left behind.
var _swing_arc: float = 130.0
## Which light comes next: 0, 1, 2. Reset when `_chain_timer` runs out.
var _chain_step: int = 0
var _chain_timer: float = 0.0
## Which Heavy comes next: 0 is the dash-spin opener, 1 the leaping overhead.
## Kept separate from the light chain so neither button can advance the other.
var _heavy_step: int = 0
var _heavy_timer: float = 0.0
## An Intent pressed mid-swing or mid-dodge and owed to the player, or -1.
var _buffer: int = -1
## Seconds the owed Intent has left before it lapses. It used to be implicit —
## the buffer could only be set during a swing and was paid out on the first
## frame after it, so it could not outlive the swing that set it. A press
## buffered during a DODGE has no such ceiling: it waits for a state the hero may
## never reach (`Prompt` opens, he is hit, he falls off something), so it needs
## an expiry of its own or it comes out minutes later at the wrong enemy.
var _buffer_t: float = 0.0
## Seconds into the parry, or -1.0 when there is no parry running. Its own clock
## and not `_swing_t`, because the parry has no hitbox, no damage window and
## nothing for `_advance_swing` to do — the two share only the fact that both
## commit the hero.
var _parry_t: float = -1.0
## Seconds left in the two windows a successful reaction opens. Both make the
## SAME BUTTON mean something else for a moment, which is the whole idea: the
## player does not learn a new input, they learn that the one they have gets
## better when they read the fight correctly.
##
##   `_riposte_t`  a parry landed -> `attack` is the DASH (`K.RIPOSTE_WINDOW`)
##   `_flurry_t`   a dodge landed -> `attack` is the LEAP (`K.FLURRY_WINDOW`)
##
## Both are spent by the swing they authorise (`_dash_swing`, `_flurry_swing`)
## and not merely allowed to run out. One read, one reward.
var _riposte_t: float = 0.0
var _flurry_t: float = 0.0
var _hit_this_swing: Dictionary = {}
## Seconds the attack button has been held, or -1.0 when it is not down. The
## sentinel matters: 0.0 is a legitimate reading on the frame of the press.
var _charge_t: float = -1.0
## Everything the charge and the spin LOOK like — the blade's glow, the motes it
## draws in, and the ring the release throws off. Driven from the hold clock
## below; it decides nothing on its own.
var _vfx: SpinVfx
## The blade's own hitbox shape, kept so the spin can widen and re-centre it.
## Reshaped per swing rather than given a second Area3D: two hitboxes is two
## `monitoring` flags to keep in step, and the one that gets left on is the one
## that damages things during a roll.
var _hit_shape: CollisionShape3D
var _hit_sphere: SphereShape3D
var _swing_player: AudioStreamPlayer3D
var _impact_player: AudioStreamPlayer3D
## The wind-up hum. One player, held across the whole hold so it can be STOPPED
## on release — a hum fired and forgotten outlives the charge by a second and a
## half (see `sfx_charging`).
var _charging_player: AudioStreamPlayer3D
var _spin_player: AudioStreamPlayer3D
var _yell_player: AudioStreamPlayer3D
## The right hand changing. One player -- see `_on_loadout_changed`.
var _swap_player: AudioStreamPlayer3D


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("HeroCombat must be a child of the Hero")
		return
	_skel = _hero.skeleton()
	if _skel == null:
		push_error("HeroCombat: no Skeleton3D on the rig")
		return
	# Sharpening is bought in the garrison and has to survive the scene change,
	# so the permanent part lives on Game and the export is only the base blade.
	damage += Game.sword_bonus()
	# Sharpening is sharpening. A whetstone that only improved the light swing
	# would quietly make the spin the worse button the more you spent in the
	# garrison.
	spin_damage += Game.sword_bonus()
	# And the slam, for the same reason. A blow the whetstone skipped would get
	# quietly worse every time the player spent gold in the garrison.
	slam_damage += Game.sword_bonus()
	# And the heavy. Every blow the sword makes is sharpened or none of them are.
	heavy_damage += Game.sword_bonus()
	# The shield's ladder widens the arc it covers (K.GUARD_ARC). Read as a
	# DELTA off the export rather than assigned, so the export stays what it
	# says it is -- the bare kite shield -- and a director that hands this node a
	# different base shield still gets the player's forge work on top of it.
	block_cone += Game.guard_arc() - K.GUARD_ARC[0]
	_mount_loadout()
	_build_hitbox()
	_build_audio()
	_build_vfx()

	# The air slam's blow hangs off the hero's own touchdown, because he is the
	# only thing that knows which frame the feet arrived on. Same division as
	# every other attack here: the hero owns the MOVE, this owns what it costs and
	# what it does (docs/CONTRACT.md §8).
	_hero.slammed.connect(_slam_impact)

	Bus.loadout_changed.connect(_on_loadout_changed)
	# Finding a bow has to put it on his back the same moment the chest opens,
	# not the next time a hand changes. See the ownership gate in _show_equipped.
	Bus.item_acquired.connect(func(_id: StringName) -> void: _show_equipped())
	# Adopt whatever Game already holds. A hero spawned into a fresh dungeon
	# after an extraction must come up wearing the set the player left with,
	# and waiting for the next button press to sync would arm him wrongly for
	# the first room.
	_on_loadout_changed(Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT))


# --- Loadout ----------------------------------------------------------------

func _mount_loadout() -> void:
	# Right hand holds the sword. Mixamo's hand bone runs along the fingers, so
	# the blade is rolled onto that axis and pitched forward to clear the wrist.
	# Right hand holds the sword. The z=-90 is the roll that stands the blade up
	# out of the fist; without it the blade lies over at 45 degrees and the whole
	# pose reads off-kilter even though the grip is in exactly the right place.
	#
	# x=-6 is the spin about the BLADE's own axis, and it is the one number here
	# that is a look decision rather than a fit. At -96 the sword was carried
	# edge-on to the camera: correct for a swordsman, and from behind the hero —
	# the only angle the game ever shows — a 92 cm blade with no width at all,
	# indistinguishable from the hookshot's chain. Ninety degrees of spin turns
	# the flat to the camera, and the silhouette becomes a sword again. The grip
	# does not move; tools/directors/sword_grip.gd shoots the four spins.
	sword = _mount(sword_id, &"mixamorig_RightHand",
		Vector3(0.0, 0.04, 0.02), Vector3(-6.0, 6.0, -90.0))
	# The scabbard. Same bone the hookshot stows on and the mirror side of it —
	# the hookshot rides his right hip, so the sword takes his left, which is the
	# side a right-handed draw reaches across to.
	#
	# MEASURED BY RENDERING (tools/directors/sheathe_lookdev.gd), and the numbers
	# it replaced are the reason that director had to be written: the old mount
	# carried this same "measured" comment and had never been rendered once. It
	# held the sword HORIZONTAL through his hip, jutting a metre out sideways like
	# a spit, in a state the player used to reach almost never — and now reaches
	# with one press of D-pad →.
	#
	# The Hips bone's local axes are in the rotated FBX space this file's opening
	# note warns about, and BOTH of the old comment's claims about them were
	# backwards. The frames say:
	#   x is his DEPTH   (more x = further forward; 0.0 puts it in the hip plane)
	#   y is his HEIGHT  (0.02 hangs the grip at the belt)
	#   z is his LATERAL (negative is his LEFT; -0.11 clears the leg by ~4 cm
	#                     without the blade floating off the body)
	# and the roll that matters is z=180: at 0 the blade stands point-UP out of
	# his waist. The x=12 is the lean that tips the tip off the leg so the blade
	# is not buried in the tunic in the flank view.
	#
	# Do not re-derive any of this from the bone matrix. Render it.
	sword_stow = _mount(sword_id, &"mixamorig_Hips",
		Vector3(0.0, 0.06, -0.11), Vector3(12.0, 0.0, 180.0))
	# The shield rides the left forearm, not the hand — that is how it sits in
	# the block clips, and hanging it off the hand makes it swing like a paddle.
	# Its origin is the CENTRE of the disc, so it needs pushing off the arm.
	#
	# The POSITION is not a silhouette judgement any more. It was one for a
	# while — x and y were nudged until the disc looked well placed against the
	# body from three metres — and what that produced was a shield the arm was
	# INSIDE: the boards passed through the sleeve, and of the two strap bands on
	# the inner face only one had any arm under it. Both are 2 cm relationships
	# that no body-scale frame can show, so they were measured instead, in the
	# shield's OWN frame (tools/directors/shield_arm_fit.gd, which prints them):
	#
	#   the two bands sit at shield x=-0.11 and x=+0.09, 20 cm apart, and the
	#   forearm is 21 cm elbow-to-wrist. That is not a coincidence — the model is
	#   built for the arm to lie ACROSS the width with the elbow at one band and
	#   the hand at the other — so there is exactly one seat across the width and
	#   it is the one that centres the arm between them.
	#
	#   the boards are dished. Their inner surface runs +0.028 at the boss out to
	#   -0.021 at the rim and the bands stand proud of it to -0.049, so the
	#   tunnel the arm goes through is about z -0.04 .. +0.02. The seat shipped
	#   with the arm at z=0.000 — in the shell, not under it.
	#
	# In the bone's frame (x is DOWN the arm, y is his RIGHT, z is BEHIND him —
	# shield_lookdev.gd --sweep=pos prints that mapping) the two corrections are:
	#   y=0.124 (was -0.03) slides it 15 cm along the arm's own direction, which
	#         is inboard in the poses the shield is held in. This is the "only
	#         one strap fits" fix, and it is nearly all of the change.
	#   z=-0.030 (was 0.0) lifts the boards off the sleeve — 3 cm out along the
	#         shield's face normal, which is forward of him while he guards.
	#   x=0.04 is unchanged: where the arm crosses the shield ALONG its length is
	#         what decides how low the point hangs, and that was already right.
	#
	# TWO axes were wrong, which is why the first fix only half worked.
	#   y=180 decides which face meets the blow. At 0 the hero presents the
	#         wooden inner face and its arm straps to the enemy.
	#   z=-90 decides which way the kite point hangs. At 0 the shield lies on its
	#         side with the point sticking out sideways -- the "off kilter" read.
	#         At +90 it stands up but INVERTED, point at the sky. -90 is the one
	#         that hangs the point at the hero's knee, where it belongs.
	# tools/directors/shield_lookdev.gd renders the roll candidates side by side.
	shield = _mount(shield_id, &"mixamorig_LeftForeArm",
		Vector3(0.04, 0.063, -0.018), Vector3(0.0, 180.0, -90.0))

	# The hookshot and the bow each get TWO mounts: one in the hand for when
	# they are equipped, one stowed on the body for when they are not. Carrying
	# the gear visibly is most of what makes a character read as an adventurer
	# rather than a man who happens to be holding a sword, and it means the item
	# buttons have something to animate between instead of a pop-in.
	# The hookshot's three numbers were all wrong, and each one was wrong in a way
	# only tools/directors/hookshot_grip.gd could show:
	#
	#   z=90  is the roll. At 0 the pistol lay flat on its side in his palm — the
	#         same class of error as the shield's, and the same fix the sword's
	#         z=-90 makes. It rolls the OTHER way to the sword because the mesh
	#         hangs off one side of its own origin: -90 swings the whole body up
	#         above his fist, +90 drops it through the fingers where a grip goes.
	#   x=-66 is the pitch. At -96 the barrel sat 27 degrees off his facing, so
	#         the thing visibly pointed across his body while the chain flew
	#         straight ahead. -66 brings that to under 3.
	#   pos   seats it. Rolling about the barrel moved the body clean out of his
	#         hand, and +0.07 on x with +0.03 on y is what puts it back through
	#         the fist rather than floating beside it.
	_mount_item(&"hookshot", hookshot_id,
		&"mixamorig_RightHand", Vector3(0.07, 0.08, 0.02), Vector3(-66.0, 6.0, 90.0),
		&"mixamorig_Hips", Vector3(-0.16, 0.02, 0.10), Vector3(0.0, 0.0, -90.0))
	# The bow was in his fist BACKWARDS, and it took a render to see which way.
	# The hand rotation shipped at (-96, 0, 90) — the -96 pitch copied off the
	# hookshot above, where it is right — and that is a quarter turn about the
	# bow's own limbs. The limbs stood up correctly (15° off vertical, which is
	# the draw's own lean) so the silhouette from behind looked fine, but the bow
	# was edge-on to the shot: its plane lay ALONG the arrow instead of across it,
	# which from his flank is a flat stave with the string cutting through it and
	# from any other angle is a bow strung the wrong way round.
	#
	# (6, 180, -90) is that same mount spun +90° about the model's own +Y, which
	# is the only spin that turns the plane without tipping the limbs over. The
	# sign is the whole answer and it is not derivable: the bow's local +X is the
	# STRING side, not the back — the mesh runs from the grip at the origin out to
	# the tips at +0.235, and on a strung bow the tips are where the string is —
	# so the correct grip has +X pointing back at the ARCHER. -90° spins it the
	# other way and gives a bow whose limbs curve into his own chest, which
	# measures just as well (8.5° vs 171.5° off the shot) and is wrong. Only the
	# frame says which. tools/directors/bow_grip.gd shoots the sweep.
	#
	# The slung bow's z is its stand-off from the spine: -0.09, not the -0.16 it
	# shipped with. At 16 cm the bow rode a hand's width clear of his back and
	# off to one side of it — from behind, a bow travelling alongside the hero
	# rather than on him. 9 cm is the rung that touches without swallowing the
	# lower limb; at 6 cm the limb goes through the sash. bow_stow_lookdev.gd
	# shoots the ladder, and shoots it from his flank, where a stand-off is a
	# gap you can see instead of a depth the camera has flattened.
	_mount_item(&"bow", bow_id,
		&"mixamorig_LeftHand", Vector3(0.0, 0.04, 0.0), Vector3(6.0, 180.0, -90.0),
		&"mixamorig_Spine2", Vector3(0.0, 0.06, -0.09), Vector3(0.0, 0.0, 28.0))
	hookshot = _items[&"hookshot"]["hand"]
	bow = _items[&"bow"]["hand"]
	woodsman_axe = _mount_woodsman_axe()
	pickaxe = _mount_pickaxe()
	_utility_models[ToolDb.WOODSMAN_AXE_ID] = woodsman_axe
	_utility_models[ToolDb.PICKAXE_ID] = pickaxe
	_show_equipped()


## Both mounts for one swappable item. Two model instances rather than one that
## gets reparented: reparenting a node out from under a BoneAttachment3D mid-
## frame leaves it at a stale transform for a frame, which reads as the bow
## teleporting through the hero's chest every time you press the button.
func _mount_item(id: StringName, model_id: String,
		hand_bone: StringName, hand_pos: Vector3, hand_rot: Vector3,
		stow_bone: StringName, stow_pos: Vector3, stow_rot: Vector3) -> void:
	_items[id] = {
		"hand": _mount(model_id, hand_bone, hand_pos, hand_rot),
		"stow": _mount(model_id, stow_bone, stow_pos, stow_rot),
	}


## Put `id` in the hero's RIGHT hand, or pass &"" for the empty hand.
##
## Kept as the low-level "show this model" call. The armament decision lives on
## Game so it survives the scene change that extracting causes; this only makes
## the rig agree with it.
func equip(id: StringName) -> void:
	equipped = id
	_show_equipped()


## Clear every mounted weapon for a full-body presentation, then restore the
## exact pre-presentation state. The item-get model is a separate display; a
## second bow on the hero's back and a sword through the raised-hand pose turn
## the acquisition silhouette into ordinary combat clutter.
func set_presentation_hidden(hidden: bool) -> void:
	if hidden:
		if not _presentation_visibility.is_empty():
			return
		for model: Node3D in _all_presentation_models():
			_presentation_visibility[model] = model.visible
			model.visible = false
		return
	if _presentation_visibility.is_empty():
		return
	for model: Node3D in _presentation_visibility:
		if is_instance_valid(model):
			model.visible = bool(_presentation_visibility[model])
	_presentation_visibility.clear()


## Temporarily replace every ordinary mounted loadout model with one utility
## tool, restoring the exact visibility snapshot when the commitment ends.
func set_utility_tool_visible(tool_id: StringName, visible: bool) -> bool:
	var requested: Node3D = _utility_models.get(tool_id)
	if requested == null:
		return false
	if visible:
		if _active_utility_tool == tool_id:
			return true
		if _active_utility_tool != &"":
			set_utility_tool_visible(_active_utility_tool, false)
		_utility_visibility.clear()
		for model: Node3D in _presentation_models():
			_utility_visibility[model] = _desired_visibility(model)
			_set_desired_visibility(model, false)
		for model: Node3D in _utility_models.values():
			_set_desired_visibility(model, model == requested)
		_active_utility_tool = tool_id
		if blocking:
			blocking = false
			_hero.set_blocking(false)
			Bus.guard_changed.emit(false)
		return true
	if _active_utility_tool != tool_id:
		return false
	for model: Node3D in _utility_models.values():
		_set_desired_visibility(model, false)
	for model: Node3D in _utility_visibility:
		if is_instance_valid(model):
			_set_desired_visibility(model, bool(_utility_visibility[model]))
	_utility_visibility.clear()
	_active_utility_tool = &""
	return true


## Compatibility surface retained for the grove and its proof director.
func set_woodsman_axe_visible(visible: bool) -> void:
	set_utility_tool_visible(ToolDb.WOODSMAN_AXE_ID, visible)


func _desired_visibility(model: Node3D) -> bool:
	if _presentation_visibility.has(model):
		return bool(_presentation_visibility[model])
	return model.visible


func _set_desired_visibility(model: Node3D, visible: bool) -> void:
	if _presentation_visibility.has(model):
		_presentation_visibility[model] = visible
		model.visible = false
	else:
		model.visible = visible


func _presentation_models() -> Array[Node3D]:
	var models: Array[Node3D] = []
	for model: Node3D in [sword, sword_stow, shield]:
		if model != null and not models.has(model):
			models.append(model)
	for value: Dictionary in _items.values():
		for key: StringName in [&"hand", &"stow"]:
			var model := value.get(key) as Node3D
			if model != null and not models.has(model):
				models.append(model)
	return models


func _all_presentation_models() -> Array[Node3D]:
	var models := _presentation_models()
	for model: Node3D in _utility_models.values():
		if model != null and not models.has(model):
			models.append(model)
	return models


## Mirror Game's live loadout onto the rig.
func _on_loadout_changed(_set_index: int, right: StringName, left: StringName) -> void:
	# A set may name gear the player has not found: the alternate set defaults
	# to bow and arrows on a brand new game, which is the point -- the slot is
	# reserved, the bow is not owned yet. Falling back to the sword means dpad-up
	# on an unfilled set leaves you armed rather than holding an invisible bow
	# that also refuses to swing (see the `equipped != &""` gate in _try_swing).
	# The equipment screen is where "(not owned)" gets said out loud.
	var held := right if Game.armament_owned(right) else &"sword"
	var off := left if Game.armament_owned(left) else &""
	# The swap sound, on a REAL change only. This signal also fires for a set swap
	# that lands on the same weapon and for the announce `Game.reset()` makes, and
	# a buckle click on those is the rig congratulating itself for nothing.
	#
	# Guarded on the incoming id rather than on `equipped`, because `equipped`
	# folds the sword into &"" and the two directions of a sword <-> unowned-bow
	# step would then read as no change at all.
	var was: StringName = equipped
	var now: StringName = &"" if held == &"sword" else held
	if was != now and _swap_player != null and is_inside_tree():
		_swap_player.play()
	# The right hand is the one that swings, so it drives `equipped` -- which is
	# what _try_swing and the HUD both read. &"sword" IS the empty-item state
	# here for historical reasons: `equipped == &""` has always meant "sword and
	# shield", and every caller of it predates the loadout.
	equip(&"" if held == &"sword" else held)
	_show_left(off)


func _show_equipped() -> void:
	for id: StringName in _items:
		var pair: Dictionary = _items[id]
		var in_hand := id == equipped
		if pair["hand"] != null:
			(pair["hand"] as Node3D).visible = in_hand
		if pair["stow"] != null:
			# Stowed, but only if he actually has one. Both mounts are built at
			# _ready because BoneAttachment3D is not something to be creating
			# mid-run, so without this gate the hero starts the game wearing a
			# bow and a hookshot he has never found -- and the ownership check
			# in Game.cycle_armament then refuses to equip the bow the player
			# can plainly see on his own back.
			(pair["stow"] as Node3D).visible = not in_hand and Game.has(id)
	# You cannot hold a bow and a sword — and the sword he is not holding is on
	# his hip, never nowhere. `drawn` is the single answer both mounts read, so
	# the two can never both be visible (a hero with two swords) or both hidden
	# (a swordsman who has mislaid it).
	var drawn := equipped == &""
	if sword != null:
		sword.visible = drawn
	if sword_stow != null:
		sword_stow.visible = not drawn
	_hide_loadout_for_utility()


## The left hand. Only the shield has a model, so anything else empties the arm
## rather than mounting a placeholder -- an untextured cube on the forearm reads
## as a bug, and "arrows" is a count on the HUD, not a thing you hold up.
func _show_left(left: StringName) -> void:
	if shield != null:
		# The bow is mounted on the LEFT hand (that is where a bow is held) while
		# the shield rides the left forearm, so drawing the bow out of the primary
		# set used to leave both on the same arm -- a kite shield growing out of a
		# bowstring. You cannot draw a bow with a shield strapped to the hand that
		# holds it, so the shield comes off for as long as the bow is out.
		shield.visible = left == &"shield" and equipped != &"bow"
	_hide_loadout_for_utility()


func _hide_loadout_for_utility() -> void:
	if _active_utility_tool == &"":
		return
	for model: Node3D in _presentation_models():
		model.visible = false


## Primitive geometry gives the utility axe a known pommel/grip convention:
## origin in the fist, handle and head along +Y like WeaponModels' swords.
func _mount_woodsman_axe() -> Node3D:
	var idx := _skel.find_bone(&"mixamorig_RightHand")
	if idx < 0:
		push_error("HeroCombat: no bone 'mixamorig_RightHand' on the rig")
		return null

	var socket := BoneAttachment3D.new()
	socket.name = &"Socket_WoodsmanAxe"
	socket.bone_name = "mixamorig_RightHand"
	socket.bone_idx = idx
	_skel.add_child(socket)

	var holder := Node3D.new()
	holder.name = &"WoodsmanAxe"
	holder.position = Vector3(0.0, 0.04, 0.02)
	holder.rotation_degrees = Vector3(-6.0, 6.0, -90.0)
	var world_scale := socket.global_transform.basis.get_scale()
	var scale_mean := (world_scale.x + world_scale.y + world_scale.z) / 3.0
	if scale_mean > 0.0001:
		holder.scale = Vector3.ONE / scale_mean

	_axe_box(holder, &"Handle", MAT_WOOD, Vector3(0.055, 0.84, 0.055),
		Vector3(0.0, 0.16, 0.0))
	_axe_box(holder, &"Poll", MAT_IRON, Vector3(0.34, 0.17, 0.10),
		Vector3(0.07, 0.53, 0.0))
	_axe_box(holder, &"Blade", MAT_IRON, Vector3(0.18, 0.14, 0.045),
		Vector3(0.30, 0.52, 0.0))
	holder.visible = false
	socket.add_child(holder)
	return holder


## Same hand convention as the axe, but a long two-sided iron head makes the
## requested tool readable even while both share the downward work reel.
func _mount_pickaxe() -> Node3D:
	var idx := _skel.find_bone(&"mixamorig_RightHand")
	if idx < 0:
		push_error("HeroCombat: no bone 'mixamorig_RightHand' on the rig")
		return null

	var socket := BoneAttachment3D.new()
	socket.name = &"Socket_Pickaxe"
	socket.bone_name = "mixamorig_RightHand"
	socket.bone_idx = idx
	_skel.add_child(socket)

	var holder := Node3D.new()
	holder.name = &"Pickaxe"
	holder.position = Vector3(0.0, 0.04, 0.02)
	holder.rotation_degrees = Vector3(-6.0, 6.0, -90.0)
	var world_scale := socket.global_transform.basis.get_scale()
	var scale_mean := (world_scale.x + world_scale.y + world_scale.z) / 3.0
	if scale_mean > 0.0001:
		holder.scale = Vector3.ONE / scale_mean

	_axe_box(holder, &"Handle", MAT_WOOD, Vector3(0.055, 0.88, 0.055),
		Vector3(0.0, 0.17, 0.0))
	_axe_box(holder, &"Head", MAT_IRON, Vector3(0.68, 0.11, 0.10),
		Vector3(0.0, 0.56, 0.0))
	_pickaxe_tip(holder, &"PointLeft", -1.0)
	_pickaxe_tip(holder, &"PointRight", 1.0)
	holder.visible = false
	socket.add_child(holder)
	return holder


func _pickaxe_tip(parent: Node3D, node_name: StringName, side: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = 0.075
	mesh.height = 0.28
	mesh.radial_segments = 5
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = MAT_IRON
	instance.position = Vector3(side * 0.47, 0.56, 0.0)
	instance.rotation.z = -side * PI * 0.5
	parent.add_child(instance)


func _axe_box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)


## Attach a weapon model to `bone`, undoing the rig's scale so the model keeps
## the true size WeaponModels gave it.
func _mount(id: String, bone: StringName, offset: Vector3, rot_deg: Vector3) -> Node3D:
	var idx := _skel.find_bone(bone)
	if idx < 0:
		push_error("HeroCombat: no bone '%s' on the rig" % bone)
		return null

	var socket := BoneAttachment3D.new()
	socket.name = "Socket_" + String(bone)
	socket.bone_name = String(bone)
	socket.bone_idx = idx
	_skel.add_child(socket)

	var model := WeaponModels.make(id)
	if model == null:
		return null

	var holder := Node3D.new()
	holder.name = id
	holder.position = offset
	holder.rotation_degrees = rot_deg
	# Measure the accumulated scale rather than assuming K.HERO_SCALE: the rig
	# may carry its own import scale on top of the Model node's.
	var world_scale := socket.global_transform.basis.get_scale()
	var s := (world_scale.x + world_scale.y + world_scale.z) / 3.0
	if s > 0.0001:
		holder.scale = Vector3.ONE / s
	holder.add_child(model)
	socket.add_child(holder)
	return holder


# --- Hitbox -----------------------------------------------------------------

func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.name = "SwordHitbox"
	_hitbox.add_to_group(&"hitbox")
	_hitbox.collision_layer = K.L_PLAYER_HITBOX
	# Enemies AND the world's interactables, so a training post registers before
	# a single enemy exists.
	_hitbox.collision_mask = K.L_ENEMY | K.L_INTERACT
	_hitbox.monitoring = false
	_hitbox.monitorable = false

	_hit_shape = CollisionShape3D.new()
	_hit_sphere = SphereShape3D.new()
	_hit_shape.shape = _hit_sphere
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)
	_aim_hitbox(reach * 0.62, reach * 0.55, arc_degrees)


## Point the blade's box at what the swing about to go out is claiming to cut.
##
## `forward` is how far IN FRONT of the hero the sphere sits. For every ordinary
## swing that is most of the reach, because a sphere on the origin hits things
## BEHIND him — which is how a clone ends up with a sword that damages what it
## visibly missed. The spin is the one swing that wants exactly that, so it
## passes 0.0 and gets the omnidirectional box the other four are guarding
## against.
##
## `arc` is the other half of the same claim and is enforced separately, in
## `_maybe_hit`: the sphere decides what is in RANGE, the arc decides what is in
## FRONT. Widening one without the other is how you get a spin that reaches 2 m
## and still only hits the thing the hero happens to be facing.
func _aim_hitbox(radius: float, forward: float, arc: float) -> void:
	_hit_sphere.radius = radius
	# Chest height, so a sphere sized for reach does not scrape the floor.
	_hit_shape.position = Vector3(0.0, 1.0, -forward)
	_swing_arc = arc


func _build_audio() -> void:
	_swing_player = AudioStreamPlayer3D.new()
	_swing_player.stream = sfx_swing
	_swing_player.bus = &"SFX"
	_swing_player.unit_size = 5.0
	add_child(_swing_player)

	_impact_player = AudioStreamPlayer3D.new()
	_impact_player.stream = sfx_impact
	_impact_player.bus = &"SFX"
	_impact_player.unit_size = 6.0
	add_child(_impact_player)

	_charging_player = AudioStreamPlayer3D.new()
	_charging_player.stream = sfx_charging
	_charging_player.bus = &"SFX"
	_charging_player.unit_size = 6.0
	add_child(_charging_player)

	_spin_player = AudioStreamPlayer3D.new()
	_spin_player.stream = sfx_spin
	_spin_player.bus = &"SFX"
	_spin_player.unit_size = 7.0
	add_child(_spin_player)

	_yell_player = AudioStreamPlayer3D.new()
	_yell_player.stream = sfx_yell
	_yell_player.bus = &"SFX"
	# Louder than the steel. It is a person, and the whole reason it moved to the
	# release is that a spin attack is the hero committing to something.
	_yell_player.unit_size = 9.0
	add_child(_yell_player)

	_swap_player = AudioStreamPlayer3D.new()
	_swap_player.stream = sfx_swap
	_swap_player.bus = &"SFX"
	# Quieter than the steel. It is a thing he does with his hands, not a blow.
	_swap_player.unit_size = 4.0
	add_child(_swap_player)


## The charge's look. A child of this node rather than of the sword, because the
## release's ring belongs to the FLOOR around the hero and only the blade half
## rides the hand — SpinVfx sorts that out once it has the holder.
func _build_vfx() -> void:
	if sword == null:
		return
	slash_trail = SwordSlashTrail.new()
	slash_trail.name = "SwordSlashTrail"
	add_child(slash_trail)
	slash_trail.bind(sword)
	_vfx = SpinVfx.new()
	_vfx.name = "SpinVfx"
	add_child(_vfx)
	_vfx.bind(sword)


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _hero == null:
		return

	# A shop or a fade owns the buttons while it is up. The swing already in
	# flight still finishes below -- cancelling it would leave the hitbox on.
	#
	# The escape rope's channel locks the same buttons: swapping your loadout halfway
	# out of the dungeon is not a thing that should typecheck. The SHIELD is the
	# exception and is handled below -- guarding through the channel is the one
	# defence he has left while rooted.
	var locked := (Prompt != null and Prompt.blocked) \
		or _active_utility_tool != &""
	var leaving := _hero.rope != null and _hero.rope.active()

	# The shield is held, not toggled, and it drops the moment you commit to
	# anything else — even the counter thrown from the stance cannot keep it up
	# through the attack, and neither can a dive roll.
	#
	# The roll clause is not cosmetic even though it looks it. `Block` is a
	# BLEND sitting above the roll one-shot in the animation tree, so a guard
	# held at amount 1.0 does not layer over the dive, it REPLACES it — the hero
	# slid backwards across the floor in a standing block pose. It also makes the
	# roll's recovery honestly vulnerable, which is what the recovery is for.
	# The button is still down, so the guard comes straight back up once the hero
	# is grounded and otherwise eligible.
	#
	# `mid_dodge` and not the two states written out, which is the difference the
	# cancel window makes: the shield comes back up in the last
	# `Hero.dodge_cancel_time` of the recovery rather than waiting for the state
	# to end. Everything the comment above says still holds for the part that
	# matters — the guard is still down for the whole DIVE, so the dodge is never
	# played underneath a block pose and the recovery is still honestly vulnerable
	# for the part of it that is a recovery. `Hero.set_blocking` ends the dodge on
	# the way up, so the roll is not left playing under the raised shield.
	var rolling := _hero.mid_dodge()
	#
	# AND ONLY ON THE FLOOR. A jump lowers the active guard on its takeoff frame,
	# and shield input cannot raise it again anywhere in the arc. The parent Hero
	# moves before this dynamically-added child, so `is_on_floor()` already holds
	# the current result of the launch frame's `move_and_slide()` here. Keeping the
	# trigger held lets the ordinary guard eligibility restore it after landing.
	#
	# AND NOT IN FIRST PERSON, which is the one place this button means something
	# else. The left trigger (and RMB, its keyboard twin) is OOT's Z and does four
	# things at once; from inside the hero's own head only two of them survive.
	# Locking on still does — pull it at a goblin and `Targeting` acquires, which
	# drops you back out into the lock, and that is the right way out. But the
	# guard itself does not: his model is not drawn, so the shield is a pose
	# nobody can see, and `Hero._tick_camera_facing` would spin his rooted body to
	# wherever the player had just glanced. That last part is not merely untidy —
	# it EATS the recentre. Pull the trigger at an empty corridor and the fourth
	# thing Z does is put the camera back behind him, and a hero who turns to the
	# lens at the same time leaves that ease with no error to close. So in here
	# the button is the camera half of Z and nothing else.
	#
	# AND NOT DURING A PARRY, which is the entire price of the move. The window is
	# 0.20 s and the recovery behind it is 0.42, and for all 0.62 the shield is
	# DOWN even though the button is still held — that is what "get it wrong and
	# you are vulnerable" is, expressed as the one line that makes it true. It
	# also makes a landed parry honest in the other direction: you cannot catch a
	# blow and be back behind the guard for the next one on the same press.
	var want_block := _hero.is_on_floor() and not locked and not rolling \
		and not _hero.first_person() \
		and Input.is_action_pressed(&"shield") and _swing_t < 0.0 and _parry_t < 0.0
	if want_block != blocking:
		blocking = want_block
		_hero.set_blocking(blocking)
		# The camera needs to know: guarding pins the hero's facing to the lens
		# (Hero._tick_camera_facing), and autoswing pins the lens to behind the
		# hero. Left running, the two chase each other and a guarded strafe
		# slowly rotates the player 30-odd degrees off what he was watching.
		Bus.guard_changed.emit(blocking)

	if not locked and not leaving:
		_tick_dpad()
		_tick_use_item_button()
		# The item trigger FIRST, so the two swing ticks below can each open with
		# a plain "an item owns the right hand" bail instead of both carrying half
		# the ranged state machine.
		_tick_item_trigger()
		# BEFORE the two swing ticks, because it is the only one of the three
		# that can be refused by a swing already running (`_press` does not
		# buffer a PARRY) and the only one whose window is worth frames. Order
		# does not otherwise matter — they read three different buttons now.
		_tick_parry_button()
		_tick_light_button()
		_tick_heavy_button(delta)
	else:
		# A shop opening mid-wind-up must not leave the charge armed behind the
		# panel, waiting to come out at whatever is standing there when the
		# player closes it again. A held bow is the same shape of bug and worse,
		# because the trigger coming up behind the panel would LOOSE it.
		_release_charge(false)
		if _hero.ranged != null:
			_hero.ranged.cancel_use()

	# The chain window is the gap BETWEEN swings, so it only runs while nothing is
	# swinging. Ticking it through the swing was the first version, and it made
	# the chain silently impossible: the window (0.34 s) is shorter than the swing
	# it was started by (0.46 s), so `_chain_step` reset before the swing that set
	# it had even finished and every press came out as step one.
	#
	# Ticked outside the `locked` gate on purpose: a shop that opens mid-chain
	# should let the chain lapse, not freeze the player one press from a finisher.
	if _swing_t < 0.0 and _chain_timer > 0.0:
		_chain_timer = maxf(_chain_timer - delta, 0.0)
		if _chain_timer == 0.0:
			_chain_step = 0
	if _swing_t < 0.0 and _heavy_timer > 0.0:
		_heavy_timer = maxf(_heavy_timer - delta, 0.0)
		if _heavy_timer == 0.0:
			_heavy_step = 0

	# Pay out a press made during the recovery — but only on a frame AFTER the
	# swing ended, never on the boundary frame itself. The hero clears
	# MoveState.ATTACK in his own _physics_process, and the swing clock runs one
	# frame ahead of his: this node is his CHILD, so on the frame a swing starts
	# the hero has already ticked and the swing has not. Firing the buffer at the
	# end of _advance_swing therefore asked a hero who was still mid-attack, he
	# refused, and the press vanished — the chain could not reach step two at all.
	#
	# Consumed before _begin runs, so a swing that gets refused for a real reason
	# does not leave the press owed forever.
	#
	# AND NOT WHILE HE IS STILL IN THE DODGE. A press buffered mid-roll pays out
	# on the frame `Hero.dodge_cancel_time` opens, not before — paid out earlier it
	# would reach `request_attack`, be refused, and be consumed by the refusal,
	# which is the exact eaten press the dodge buffer exists to stop.
	if _buffer >= 0:
		_buffer_t = maxf(_buffer_t - delta, 0.0)
		if _buffer_t == 0.0:
			_buffer = -1
	if _swing_t < 0.0 and _buffer >= 0 and not _hero.mid_dodge():
		var queued := _buffer
		_buffer = -1
		_buffer_t = 0.0
		_begin(queued)

	if _swing_t >= 0.0:
		_advance_swing(delta)

	# The parry's own clock and the two windows a landed reaction opens. Ticked
	# OUTSIDE the `locked` gate, exactly as the chain window above is and for the
	# same reason: a shop opening mid-parry should let the move finish and the
	# windows lapse, not freeze the player behind a panel holding a shield out.
	if _parry_t >= 0.0:
		_parry_t += delta
		if _parry_t >= K.PARRY_WINDOW + K.PARRY_RECOVER:
			_parry_t = -1.0
	_riposte_t = maxf(_riposte_t - delta, 0.0)
	_flurry_t = maxf(_flurry_t - delta, 0.0)


## The D-pad, which is the whole equipment screen: three cycles and no bindings.
##
##   ← / →  step the RIGHT HAND through the weapons you own. The sword is a stop
##          on that ring like anything else, which is what makes "give me my
##          sword back" a direction rather than a button.
##   ↓      step the selected ITEM. Selecting is not using — X uses.
##   ↑      swap the loadout SET under the ring.
##
## NOTHING HERE FIRES ANYTHING. That split is the whole scheme, and it is the one
## thing Ocarina got to live with rather than fix: a C-button there both equipped
## AND fired, so pulling the bow out was also loosing an arrow at whatever you
## happened to be facing.
##
## Game owns what is in which hand and which bottle is selected; this only
## presses the buttons.
func _tick_dpad() -> void:
	if Input.is_action_just_pressed(&"weapon_prev"):
		Game.cycle_weapon(-1)
	if Input.is_action_just_pressed(&"weapon_next"):
		Game.cycle_weapon(1)
	# **The ring is frozen while a meal is running**, and that is a rule about the
	# HUD rather than about what a seated hero may do. `Game.begin_meal` was handed
	# `selected_item()`, and the item cell draws the meal's twelve seconds inside
	# the SELECTED item's frame (`Hud._draw_item_cell`) on the strength of those
	# two being the same id. Let the ring turn under a live meal and the gauge is
	# filling in a cell showing a bottle the hero is not drinking. The alternative
	# -- draw `Game.meal_id` in the cell regardless of the selection -- makes the
	# D-pad press do nothing visible, which is the same lie told from the far end.
	#
	# It costs the player nothing: the meal is twelve seconds and a step in any
	# direction ends it (`Hero._tick_meal_cancel`), so "I need the other bottle
	# NOW" is already answered by standing up.
	if Input.is_action_just_pressed(&"item_next") and not Game.eating():
		# The blip is refused on a ring of one, because there `cycle_item` is a
		# no-op and a click that says "moved" when nothing moved is worse than
		# silence -- the player looks at the HUD for a change that is not there.
		#
		# `carry_count`, not `bottle_count`: the ring is bottles AND rations now
		# (`Game.carry_ids`), so a hero with one bottle and a stack of hardtack has
		# two stops and both of them have to click.
		if Game.carry_count() > 1:
			_select_blip()
		Game.cycle_item(1)
	if Input.is_action_just_pressed(&"loadout_swap"):
		_select_blip()
		Game.swap_loadout()


## The D-pad's selection click.
##
## ONLY ↓ and ↑ ring it, and that is not an oversight. ← / → already speak:
## `_on_loadout_changed` plays `sfx_swap` whenever the right hand's model
## actually changes, and doubling a leather-and-buckle equip with a UI click on
## the same press turns one clear event into mush. What ↓ and ↑ had was nothing
## at all -- a bottle selection is invisible on a controller (the HUD cell is in
## the corner of the eye) and a set swap that lands on the same right-hand weapon
## changes nothing on screen whatsoever. Those are the two presses that could
## land and leave the player unsure whether they had.
##
## Non-positional in spirit but played at the hero, because `Sfx` is 3D-only and
## the hero is where the listener is; the same thing every menu cue here does.
func _select_blip() -> void:
	if _hero != null:
		Bus.request_sfx.emit(&"ui_move_selection", _hero.global_position)


## X — use what is selected. One press, no draw, no aim.
##
## **What "use" means is the selection's business, not this button's**
## (`Game.use_selected_item`): a bottle is swallowed and a ration sits him down
## for twelve seconds. Everything below describes the bottle, and every word of it
## is deliberately false for a ration — that is the item, not an inconsistency.
##
## Elden Ring's X and it is the reason items and weapons are on different inputs
## at all: a flask is a thing you swallow, and the two-press version of it (take
## it out, then use it) puts the slowest input in the game on the button you
## reach for when you are about to die.
##
## It does NOT interrupt or get interrupted. Drinking mid-swing is fine and
## drinking mid-roll is fine; the potion is state (`Game.drink_bottle`) rather
## than an animation, and gating it on the hero being idle would make the button
## unreliable in exactly the fight it exists for.
##
## X was the sheathe button for one afternoon. Sheathing has no button now —
## the sword is a stop on the weapon ring, so the way back to it is D-pad ← or →.
func _tick_use_item_button() -> void:
	if not Input.is_action_just_pressed(&"use_item"):
		return
	Game.use_selected_item()


## RB AND RT, when an item is in the right hand: the item's trigger.
##
## BOTH shoulder buttons, because "the right hand" is what those two buttons are
## for and an item has replaced the sword in it. A player holding a bow should
## not have to remember which of the two attack buttons the bow answers to —
## there is only one thing in the hand and it does one thing.
##
## HELD, not tapped, and that is not a detail: it used to fire on the press,
## which meant a player pulling the trigger to AIM had already shot before they
## touched the stick. Down draws, up looses.
func _tick_item_trigger() -> void:
	if _hero.ranged == null:
		return
	# `attack` is read EXACTLY here and in `_tick_light_button` — see ATTACK_EXACT.
	# It matters even on this line, where both buttons do the same thing: without
	# it a Shift+LMB draw would arrive as two presses in one frame, so `edge`
	# would fire `use_press` and the bow would loose on the pull that was meant to
	# aim it.
	var down := Input.is_action_pressed(&"heavy") \
		or Input.is_action_pressed(&"attack", ATTACK_EXACT)
	var edge := (Input.is_action_just_pressed(&"heavy")
		or Input.is_action_just_pressed(&"attack", ATTACK_EXACT))
	if equipped != &"" and edge:
		_hero.ranged.use_press(equipped)
		return
	if not down:
		# Unconditional, not gated on an item being out: the item can leave his
		# hand mid-hold (D-pad ← / → step the weapon out from under the draw), and
		# a `_using` flag that only ever gets cleared by the hand that set it is a
		# bow stuck at full draw the next time one is drawn.
		_hero.ranged.use_release()


## RB — the light chain, and the two swings that are the same press in a
## different situation.
##
## No charge is armed here any more. The wind-up moved to the trigger with the
## rest of the heavy (`_tick_heavy_button`), which is what lets this button be
## mashed as fast as the chain will accept without ever storing anything.
func _tick_light_button() -> void:
	# An item owns both shoulder buttons while it is drawn (`_tick_item_trigger`,
	# which has already run this frame). There is no sword half to reach.
	if equipped != &"":
		return
	if not Input.is_action_just_pressed(&"attack", ATTACK_EXACT):
		return
	# In the air the light button is the SLAM, and it is checked before
	# everything below because none of the rest of the kit can be thrown off
	# the floor anyway — request_attack refuses them, so without this the
	# press in mid-air was silence.
	if not _hero.is_on_floor():
		_press(Intent.SLAM)
		return
	# THE TWO EARNED WINDOWS, ahead of everything else including the guard.
	#
	# Both are short, both were paid for with a read the player got right, and
	# both make this one button mean something better for a moment. Checking them
	# first is what stops the reward being silently eaten by a stance the player
	# happens to be in — a hero who parries and then raises his shield again while
	# the enemy is still on its back must not press attack and get another parry.
	#
	# FLURRY outranks RIPOSTE when both are somehow live. It is the rarer read and
	# the bigger blow, and a player who has just done both should be shown the
	# better of the two.
	if _flurry_t > 0.0:
		_press(Intent.FLURRY)
		return
	if _riposte_t > 0.0:
		_press(Intent.DASH)
		return
	# THE GUARD DOES NOT CHANGE WHAT THIS BUTTON MEANS. RB out of a raised shield
	# is the light swing, exactly as it is from neutral. Heavy owns its own combo,
	# also unchanged by the stance.
	#
	# It used to be the PARRY, and before that the dash, all three fighting over
	# one attack button because a raised shield was the only modifier anyone had.
	# That is over: the parry has its own button now (`_tick_parry_button`), so
	# nothing here has to ask what stance the player is in.
	#
	# What that buys is the thing the modifier cost: the sword is reachable out
	# of a guard. Under the old arrangement a guarded player who pressed attack
	# got a 0.62 s commitment with no hitbox, so the only way to swing at the
	# thing you were guarding against was to let the shield down FIRST and press
	# on a later frame — a whole button's worth of latency charged to the stance
	# you adopt when something is about to hit you.
	_press(Intent.LIGHT)


## A — THE PARRY, and only from behind a raised shield.
##
## It is on `interact` rather than on the attack button, and the guard is what
## tells the two apart: shield up, A is the parry; shield down, A is the same
## "talk to that / open that" it has always been. `Prompt` owns the other half of
## that split and refuses the press for as long as the guard is up, so one press
## can never both catch a blow and open the chest behind it.
##
## WHY IT MOVED. The parry is a claim about a moment, and the moment it is a
## claim about is the quarter-second before a blow lands — which is precisely
## when the player is holding the guard and watching a wind-up. Sharing the
## attack button meant the two things a guarded player might want, "catch this"
## and "hit it", were one press arbitrated by a stance, and the sword lost:
## attacking out of a block was unreachable without dropping the guard first.
## Splitting them across two fingers costs nothing — the left index holds the
## stance, the right index swings, and the thumb, which was doing nothing at all
## behind a raised shield, catches.
##
## THE GUARD GATE IS THE WHOLE BINDING. There is no parry from neutral, which is
## what keeps A meaning one thing at a time and keeps the move a bet you have to
## already be committed to.
func _tick_parry_button() -> void:
	# An item drawn takes the shield off the arm (`_mount_left`), so there is no
	# shield to throw. `_begin` would swallow this anyway — it refuses every
	# Intent while something is equipped — but bailing here keeps the refusal
	# where the reason for it is, and matches how the two swing ticks open.
	if equipped != &"":
		return
	if not blocking:
		return
	if not Input.is_action_just_pressed(&"interact"):
		return
	_press(Intent.PARRY)


## RT — the heavy, and everything the heavy becomes:
##
##   on the ground  -> the wind-up, on the press. NOTHING swings yet.
##   released short -> Heavy step one (dash-spin), then step two (overhead).
##   released armed -> the spin. One pull, one blow, and WHICH blow is the
##                     length of the pull.
##   IN THE AIR     -> the jump attack. Same slam RB throws off a jump, on the
##                     button the player is already holding for the heavy.
##
## ONE PULL IS ONE BLOW, and that is the whole feel of the button. It used to
## throw the overhead on the PRESS and keep charging underneath it, so a player
## who held the trigger got the overhead AND the spin off a single pull — two
## power attacks nobody asked for, the second one arriving while the first was
## still landing. The charge stopped being a choice: it was what happened to you
## if you did not let go fast enough.
##
## So the blow moved to the release: tap it to advance the two-hit Heavy combo,
## or hold it for the charged spin. Those paths are alternatives. The cost is
## `charge_time` of latency on a tapped heavy in the
## worst case — which is exactly what a tap-length hold is, a fraction of a
## second — and that is the price of the trigger meaning one thing. The button
## with no latency at all is RB, and it is right there.
func _tick_heavy_button(delta: float) -> void:
	if equipped != &"":
		# An item owns this trigger while it is drawn (`_tick_item_trigger`), so
		# there is no sword half to run — and any wind-up that was already in
		# flight is dropped rather than left armed. The only way to be mid-hold
		# with an item out is a D-pad press made during the hold, and paying that
		# out as a spin on release would be a swing with an invisible sword.
		if _charge_t >= 0.0:
			_release_charge(false)
		return

	# THE JUMP ATTACK, off the HELD trigger rather than off the press edge. A
	# player who wants to come down on something pulls RT on the way up, not at
	# the top of the arc, and an edge would have been spent on the ground as an
	# Heavy opener before he ever left it. Reading the held state means the same
	# pull advances Heavy on the floor and throws the slam once he is off it.
	#
	# Held also makes the mid-air press work, so both readings of "hold RT in the
	# air" land on the same move. `_press` is safe to call every frame — an
	# Intent already in flight is not restarted (`_begin` -> `request_slam`).
	if not _hero.is_on_floor():
		if Input.is_action_pressed(&"heavy"):
			_press(Intent.SLAM)
		# The wind-up cannot survive the jump: a charge armed on the ground and
		# released after landing is a spin the player asked for in a different
		# situation. Dropped silently, without firing.
		if _charge_t >= 0.0:
			_release_charge(false)
		return

	if Input.is_action_just_pressed(&"heavy"):
		_charge_t = 0.0
		# The hum starts on the PRESS, not when the charge arms. It is a rise, and
		# a rise that begins at the top is a beep.
		if _charging_player != null:
			_charging_player.play()
		return
	if Input.is_action_just_released(&"heavy"):
		# The one place either path is asked for. `_release_charge` fires the magic
		# spin when the wind-up armed; otherwise the short pull advances Heavy.
		# Exactly one attack comes from one pull, every time.
		#
		# `_charge_t >= 0.0` is what makes that "every time" honest. A hold can be
		# TAKEN from the player mid-pull — a shop opening, an item drawn, the
		# ground leaving his feet — and each of those calls `_release_charge(false)`
		# and parks the clock at -1. The finger is still down; the release edge is
		# still coming. Without this the edge would land an overhead a second after
		# the wind-up it belonged to was cancelled, which is the same bug as the
		# double blow wearing a different hat.
		var live := _charge_t >= 0.0
		var armed := charged
		_release_charge(armed)
		if live and not armed:
			_press(Intent.HEAVY)
		return
	if _charge_t < 0.0:
		return
	_charge_t += delta
	# The held pose, from the first frame of the hold rather than from the arm-up:
	# it eases in (hero.gd §Charge) rather than snapping, so a tap never reads as
	# a pose at all, and a real hold is already visibly winding up well before the
	# charge arms. A pose that waited for `charge_time` would tell the player the
	# thing they can already see coming and nothing on the way there.
	_hero.charging = true
	# **An empty blue bar cannot arm.** See `_can_spin`: the hold still happens and
	# the release still advances Heavy, but nothing winds up and nothing
	# glows, which is the player being told what they can afford by looking at the
	# hero instead of at the HUD.
	if not charged and _charge_t >= charge_time and _can_spin():
		_set_charged(true)
	# Every frame, not just at the threshold: the glow and the motes ARE the
	# "nearly there" tell now that the ping has moved to the release, and a tell
	# that only exists at the moment it completes tells you nothing on the way up.
	#
	# Gated on the same affordability, and that is the point of drawing it here
	# rather than at the arm-up: a blade that gathered light for four tenths of a
	# second and then refused to arm would be a promise the bar cannot keep.
	if _vfx != null and _can_spin():
		_vfx.charge(clampf(_charge_t / maxf(charge_time, 0.01), 0.0, 1.0))


## Let go of the wind-up, spinning if `fire`. Safe to call on a frame where
## nothing was being held, which is why the shop gate can call it blindly.
##
## The hum is cut here whether or not anything is swung, and that is the whole
## reason it is one held player rather than a fire-and-forget: the stream is
## 1.9 s long against a hold that is usually half a second.
func _release_charge(fire: bool) -> void:
	if _charging_player != null and _charging_player.playing:
		_charging_player.stop()
	# Dropped here rather than in the tick, so every way out of a hold — the
	# release, the shop, an item drawn mid-wind-up — puts the pose down. A flag
	# only cleared on the happy path is a hero who stands frozen in a swing.
	_hero.charging = false
	if fire:
		# The yell, the swipe and the ring all live in `_spin_swing`, not here.
		# A release is a REQUEST, and a request made in the back half of the light
		# swing that started the hold is buffered — up to `swing_time` minus
		# `charge_time` before it actually comes out. Playing them here put the ring
		# on the floor and the shout in the air while the hero was still finishing
		# the swing before, and left both hanging if the spin was refused outright.
		# The blade stays lit across that gap on its own: nothing clears the glow
		# between here and the swing.
		_press(Intent.SPIN)
	elif _vfx != null:
		# A hold abandoned without a spin gives the light straight back rather
		# than fading it, so the blade cannot be caught glowing while the hero
		# stands there holding nothing.
		_vfx.clear()
	_charge_t = -1.0
	_set_charged(false)


## The charge has armed, or been given up. Public state only — what it LOOKS
## like is `_vfx.charge`, driven per frame, and what it SOUNDS like is the
## release. Nothing fires here any more; the ping that used to lives in
## `_release_charge` as the yell.
func _set_charged(on: bool) -> void:
	if charged == on:
		return
	charged = on


## Can he afford to swing at all?
##
## THE SWING RULE IS NOT THE DODGE RULE, and the asymmetry is the whole design
## (K.STAMINA_SWING). A roll is refused unless the bar holds all of
## `Hero.roll_stamina`; a swing goes out on any stamina above zero and the cost
## clamps at the floor. So the bar never interrupts a chain in the middle — it
## empties, and the NEXT press is the one that finds nothing there. That is Elden
## Ring's arrangement and the reason its stamina reads as commitment rather than
## as a cooldown: you are never told "no" during a move you already committed to.
##
## A refused swing is SILENT. No buzzer, no whiff animation — the bar is empty on
## screen and the player emptied it, which is the same argument
## `Game.use_selected_item` makes about an empty bottle: a noise about a thing
## you already know is the game shouting at you.
func _can_swing() -> bool:
	return Game.stamina > 0.0


## Is there magic in the bar for a spin?
##
## **The spin is the one blow in the kit that costs something the dungeon will
## not give back** (K.MAGIC_SPIN). It is asked in two places and they do
## different jobs: `_tick_heavy_button` asks it to decide whether the wind-up may
## ARM at all, and `_spin_swing` asks it again as it pays.
##
## The first of those is the whole tell. An empty bar means the blade never
## lights and the motes never gather, so a player holding the trigger can SEE
## that the charged release is not available before they commit to waiting for
## it -- and the hold then advances Heavy on release, through the
## `live and not armed` path that a short tap already uses. No new refusal, no
## buzzer, no dead button: the trigger still means "hit it hard", and an empty
## bar only changes how hard.
func _can_spin() -> bool:
	return Game.magic >= K.MAGIC_SPIN


## An Intent the player has asked for. Mid-swing it is remembered rather
## than dropped — but only in the back half of the swing, because a press on the
## first frame is the player mashing, not the player asking for the next step.
func _press(intent: int) -> void:
	if _swing_t >= 0.0:
		# A slam is never owed. Every other Intent describes a move the hero could
		# make from where he is standing whenever it is finally honoured; this one
		# is only legal in the air, and the air is gone by the time a buffered
		# press pays out. Buffered, it came out as a hero snapping into a dive
		# pose on the floor and rooting himself there for no reason the player
		# could connect to the button they pressed a swing ago.
		# A PARRY is never owed either, and for a sharper version of the same
		# reason. Every other Intent describes a move the hero could make whenever
		# it is finally honoured; a parry is a claim about a specific moment, and
		# one paid out a third of a second late is not a late parry — it is the
		# guard dropping for 0.62 s at a moment the player did not choose.
		#
		# The FLURRY is not buffered for a third reason: its window is running on
		# a clock the buffer cannot see, so a press owed across a long swing could
		# pay out a leap after the window that authorised it had closed.
		if _bufferable(intent) and _swing_t / maxf(_swing_dur, 0.01) >= chain_buffer_from:
			_buffer = intent
			# The swing that owes it, plus a frame or two. Exact rather than a
			# constant, because it must never be SHORTER than the wait it covers:
			# the longest swing in the kit is `flurry_swing_time` (1.02 s) and
			# `chain_buffer_from` allows a press with 0.65 of it left to run, so any
			# flat number small enough to be a sensible dodge buffer would silently
			# break the chain on the slow swings.
			_buffer_t = _swing_dur - _swing_t + 0.10
		return

	# MID-DODGE, the press is OWED rather than dropped. `Hero.request_attack`
	# refuses for the whole 0.82 s of a dodge, and `_begin` has no way to tell a
	# refusal from a swing that happened — so before this, every press made in a
	# roll simply vanished. It is the same argument the chain buffer above already
	# won, applied to the other commitment in the game that eats presses.
	#
	# Same three exclusions, and they hold here for the same reasons: a SLAM needs
	# air the hero has not got, a PARRY is a claim about a moment, and a FLURRY's
	# authorising window runs on a clock this buffer cannot see.
	if _hero.mid_dodge() and _bufferable(intent) and dodge_buffer_grace > 0.0:
		_buffer = intent
		_buffer_t = _hero.dodge_cancel_in() + dodge_buffer_grace
		return
	_begin(intent)


## Is this Intent one that survives being paid out late? See the two buffer sites
## above for what each exclusion costs if it is dropped.
func _bufferable(intent: int) -> bool:
	return intent != Intent.SLAM and intent != Intent.PARRY \
		and intent != Intent.FLURRY


## Turn an Intent into an actual swing. Everything that decides WHICH swing —
## the lock, the chain position, whether an item is in the hand — lives here, so
## the buffered path and the live path cannot drift apart.
func _begin(intent: int) -> void:
	# AN ITEM IS OUT: nothing swings. Both shoulder buttons belong to whatever is
	# in the right hand (`_tick_item_trigger`), and neither of the two swing ticks
	# even reaches `_press` while something is drawn -- so the only way in here is
	# a LIGHT buffered before the draw, paying out after it.
	#
	# THE ESCAPE HATCH USED TO LIVE HERE and it is worth saying why it went. A
	# LIGHT with an item out stowed the item and swung on the same press, so a
	# hookshot drawn by mistake cost you one button you were already reaching for.
	# It existed because drawing was sticky and the D-pad direction you drew with
	# was a fact you had to remember. The D-pad steps a RING now: the sword is a
	# stop on it, ← or → hands it back, and there is nothing to remember. Keeping
	# the hatch would mean a press buffered a quarter-second ago silently stowing
	# the bow the player has just chosen.
	if equipped != &"":
		return

	match intent:
		Intent.SLAM:
			# Priced like the rest of the kit, and gated the same way: the check is
			# before `request_slam` so a refused slam is not also a refund problem,
			# and the spend is after it so a slam refused for height costs nothing.
			if _can_swing() and _hero.request_slam():
				_reset_heavy_combo()
				# The dive clip is scaled to this measured commit-to-contact interval.
				# Sample all of it: unlike ordinary swings, the airborne strike has no
				# narrower damage slice, and held-heavy retries are refused by SLAM.
				if slash_trail != null:
					slash_trail.begin_stroke(
						_hero.slam_strike_time, Vector2(0.0, 1.0), true)
				Game.spend_stamina(K.STAMINA_SLAM, true)
		Intent.SPIN:
			_spin_swing()
		Intent.DASH:
			_dash_swing(true)
		Intent.PARRY:
			_parry()
		Intent.FLURRY:
			_flurry_swing()
		Intent.HEAVY:
			_heavy_combo_swing()
		_:
			_light_swing(_chain_step)


## The charged release: a full 360 with the blade out at arm's length, and the
## only blow in the kit that does not care which way the hero is facing.
##
## It is the one swing that reshapes the hitbox. Everything else in here fights
## to keep the sword from hitting what it visibly missed; this one is asking for
## precisely the omnidirectional box the others guard against, so it says so out
## loud rather than letting a wide `arc_degrees` leak into the light chain.
func _spin_swing() -> void:
	if not _can_swing():
		# The charge is spent for nothing, and the blade is still lit — same
		# cleanup the refusal below does, for the same reason.
		if _vfx != null:
			_vfx.clear()
		return
	# The blue bar, checked a second time on the way past. `_tick_heavy_button`
	# will not arm a charge this cannot afford, so reaching here with an empty bar
	# means the magic went somewhere between the arm-up and the release — and the
	# answer to that is the current Heavy step, exactly as a short pull would have
	# given. The trigger still means "hit it hard" and only the bar decides how.
	if not _can_spin():
		if _vfx != null:
			_vfx.clear()
		_heavy_combo_swing()
		return
	if not _hero.request_attack(spin_swing_time, Hero.Swing.SPIN):
		# Refused, so the charge is spent for nothing — and the blade is still
		# carrying the light the hold put into it, because the release deliberately
		# leaves it lit for the buffered case. Give it back here or he walks away
		# glowing.
		if _vfx != null:
			_vfx.clear()
		return
	# Voice, steel and the ring, all on the frame the spin actually starts. The
	# yell used to fire at the top of the HOLD, which announced a commitment the
	# player had not made yet.
	if _spin_player != null:
		_spin_player.pitch_scale = randf_range(0.96, 1.04)
		_spin_player.play()
	if _yell_player != null:
		_yell_player.pitch_scale = randf_range(0.97, 1.03)
		_yell_player.play()
	if _vfx != null:
		_vfx.fire()
	# Paid AFTER the hero has agreed to swing, like every other cost in this file:
	# a spin refused by `request_attack` must not also empty a quarter of the bar.
	Game.spend_magic(K.MAGIC_SPIN)
	Game.spend_stamina(K.STAMINA_SPIN, true)
	# A spin ENDS the chain rather than counting as a step in it. It is the other
	# half of the same button; letting it slot into the light chain would make the
	# finisher something you reach by pressing whatever, which is not a combo.
	_chain_step = 0
	_chain_timer = 0.0
	_reset_heavy_combo()
	_aim_hitbox(spin_reach, 0.0, spin_arc)
	# Pitched down, the cheapest honest way to make the swings sound like
	# different amounts of effort.
	_commit(spin_swing_time, spin_damage_window, spin_damage, spin_knockback,
		K.HITSTOP_HEAVY, randf_range(0.68, 0.78), K.STUN_HEAVY)


## THE DASH-SPIN: Heavy's opener, also reused by the counter a landed parry buys.
## It asks for no target — see Hero.request_dash for why facing is enough.
##
## `starts_heavy_combo` distinguishes the ordinary Heavy opener from the riposte
## input. Both share the move; only Heavy advances to the overhead.
func _dash_swing(earned_riposte: bool, starts_heavy_combo: bool = false) -> void:
	if not _can_swing():
		return
	if not _hero.request_dash(dash_swing_time, dash_drive_time, dash_speed):
		return
	# An earned window is spent, exactly as `_flurry_swing` spends its own. Spend
	# it HERE rather than at the press so a riposte the hero refused (mid-swing,
	# off the floor, no stamina) does not eat the reward. Both returns above are
	# that refusal. The ordinary Heavy opener does not touch an earned window.
	#
	# It went unspent for as long as the dash has lived in this window, and that
	# was survivable while the dash was only damage: 1.20 s of window against a
	# 0.62 s swing is room for two, so a parry bought a stab and a bit. With the
	# i-frames below it is not survivable — the same mash would buy 1.24 s of
	# uninterruptible immunity off one read, which is a stronger thing than the
	# parry was ever priced to grant.
	if earned_riposte:
		_riposte_t = 0.0
	# THE I-FRAMES belong only to the earned riposte. Heavy's always-available
	# opener is a committed sword attack, not a free dodge.
	#
	# For EXACTLY as long as the swing commits him, and that rule is the one the
	# dodges already live by: "i-frames run for exactly as long as the dodge
	# does" (`Hero.backflip_time`, `K.ROLL_IFRAMES`). No tail, deliberately — a
	# bubble that outlives the animation is a bubble the player cannot see the
	# edge of, and this way the frame he gets his input back on is the frame he
	# can be hit on.
	#
	# This does NOT stack into a second riposte: `_riposte_t` is spent above.
	# It is the flurry that has no i-frames — see `_flurry_swing`.
	if earned_riposte:
		_hero.grant_iframes(dash_swing_time)
	Game.spend_stamina(K.STAMINA_DASH, true)
	# It never advances the light chain. The Heavy route below advances only the
	# dedicated two-step chain; the riposte route resets it.
	_chain_step = 0
	_chain_timer = 0.0
	if starts_heavy_combo:
		_heavy_step = 1
		_heavy_timer = chain_window
	else:
		_reset_heavy_combo()
	_aim_sword()
	# The counter is a real blade thrust, so it owns the same short world-space
	# ribbon family as the light chain. Start it only after request_dash accepts;
	# wiring from the DASH intent or shared clip would also trail refused swings.
	if slash_trail != null:
		slash_trail.begin_stroke(dash_swing_time, dash_damage_window, true)
	_commit(dash_swing_time, dash_damage_window, dash_damage, dash_knockback,
		K.HITSTOP_HEAVY, randf_range(0.86, 0.94), K.STUN_HEAVY)


## The parry: the shield thrown out to meet a blow that has not landed yet.
##
## It is the only move in the file that does not go through `_commit`, and that
## is the definition of it rather than an omission — `_commit` is what gives a
## move a hitbox and a damage window, and a parry damages nothing. What it has
## instead is `_parry_t`, a window `Hero.take_hit` asks about (`parries`).
##
## IT COSTS NO STAMINA, deliberately, and it is the only committed move in the
## kit that does not. The price is already paid in `K.PARRY_RECOVER` — 0.42 s
## with the guard down — and that price is the mechanic. A stamina cost on top
## would mean a player who reads the fight correctly is also poorer for it, and
## a bar that decides whether a REACTION is available turns a timing move into a
## resource move. See K's note on the two reactions.
func _parry() -> void:
	# A parry already running does not restart. Mashing must not refresh the
	# window — that would turn the one move in the game with a real punish into a
	# button you hold down.
	if _parry_t >= 0.0:
		return
	if not _hero.request_parry(K.PARRY_WINDOW + K.PARRY_RECOVER):
		return
	_reset_heavy_combo()
	_parry_t = 0.0
	# The guard comes down NOW rather than on the next frame's `want_block` pass.
	# One frame of a raised shield inside a parry is one frame in which a blow
	# would be BLOCKED instead of parried, and it is the first frame — the one a
	# player aiming at the front of the window is most likely to hit.
	if blocking:
		blocking = false
		_hero.set_blocking(false)
		Bus.guard_changed.emit(false)
	# The chain does not survive it. A parry is not step one of anything.
	_chain_step = 0
	_chain_timer = 0.0
	# A SHIELD noise, and not the sword's.
	#
	# This used to play `_swing_player` at pitch 1.18-1.28 under a comment saying
	# it is a shield being shoved and not a blade -- which is the right sentence
	# and the wrong sound. A pitched-up whoosh is still the whoosh a sword makes,
	# and the press that throws thirty kilos of kite shield at something is the
	# one input in the kit that should not be arriving on the sword's channel.
	# `shield_bash` is on disk and had never been wired to anything.
	#
	# Positional rather than through `_swing_player`, so it rings where the
	# shield is rather than flat on the camera -- the same reason `on_parried`
	# takes a contact point.
	Bus.request_sfx.emit(&"shield_bash", _hero.global_position + Vector3(0.0, 1.0, 0.0))


## True while a blow arriving from `from_pos` would be PARRIED rather than
## merely survived. Asked by `Hero.take_hit`, which owns the order the defences
## are tried in.
##
## Two gates, and the cone is the less interesting one. The window is what this
## is: `_parry_t` counts from the press, and only its first `K.PARRY_WINDOW` are
## live. Everything after that is the recovery, during which this returns false
## and `blocks()` also returns false — which is the hole, stated twice, in the
## two functions that would otherwise fill it.
func parries(from_pos: Vector3) -> bool:
	if _parry_t < 0.0 or _parry_t > K.PARRY_WINDOW or _hero == null:
		return false
	var to := K.flat(from_pos - _hero.global_position)
	if to == Vector3.ZERO:
		return false
	var fwd := -_hero.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(to)) <= parry_cone


## A blow was caught. Everything a successful parry IS happens here.
##
## The order is the order the player receives it, which is the same order
## `Enemy._on_damaged` uses: the world stops, the thing that swung is thrown, the
## burst goes off, the camera kicks, and the window opens.
func on_parried(hit: Hit) -> void:
	var at := _hero.global_position + Vector3(0.0, 1.0, 0.0) \
		+ K.flat(hit.from - _hero.global_position) * 0.55
	# The hardest stop in the game, on the one frame that most deserves it. A
	# parry is a read that came off and it should land like the game agreeing
	# with you.
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	Bus.request_shake.emit(K.SHAKE_CRIT, 0.22)
	FlourishVfx.parry(get_tree().current_scene, at)
	# THE OPENING, which is the thing that was actually asked for. The attacker
	# is thrown and staggered rather than damaged — a parry that also hurt would
	# be a free attack, and what makes it worth the risk is the second you get
	# afterwards, not the HP.
	var body := _parried_body(hit.from)
	if body != null:
		body.call(&"stagger", _hero.global_position, K.PARRY_STAGGER, K.PARRY_SHOVE)
	_riposte_t = K.RIPOSTE_WINDOW
	# The parry itself is over the instant it lands. Leaving the recovery to run
	# would mean the reward window opened onto a hero who could not use it — and
	# the recovery is a punish for MISSING, which this did not.
	_parry_t = -1.0
	_hero.end_commitment()
	Bus.parried.emit(at, body)
	# `parry_clang` and NOT `shield_block`, which is what this emitted for its
	# whole life. A parry's entire reward is that it is not a block -- the world
	# stops, the attacker is thrown, and a second of riposte opens -- and it was
	# confirming all of that with the exact sound a block makes. The one moment
	# in a fight the player most needs told apart from the ordinary one was the
	# one moment that sounded identical to it.
	#
	# NOT routed through `Bus.shield_blocked`: that signal means "the guard
	# stopped something" and `Sfx.CUES` owns its sound. Two different events.
	Bus.request_sfx.emit(&"parry_clang", at)


## WHO to throw, found from where the blow came from rather than from the blow.
##
## `Hit` carries `source` as a NAME and not a node, and the note on it explains
## why: the only other thing that reads it is the run-ending screen, which draws
## after the floor and everything standing on it has been freed. A node reference
## added for this would be a field that is valid for one frame and dangling for
## the one that matters. So this asks the world instead.
##
## Nearest body to `hit.from` wins, and the radius is tight — a swing's `from` is
## the attacker's own position (see `DamageArea`), so the nearest enemy to it is
## the attacker unless two are standing inside each other. Returning null is a
## perfectly good outcome: an arrow, a spike floor or a hazard can all be parried
## and none of them can be knocked over.
func _parried_body(from: Vector3) -> Node:
	var best: Node = null
	var best_d := 1.4
	for group in [&"enemy", &"boss"]:
		for n in get_tree().get_nodes_in_group(group):
			var body := n as Node3D
			if body == null or not body.has_method(&"stagger"):
				continue
			var d := body.global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = body
	return best


## A roll went through a live blow inside `K.DODGE_GRACE`. The dodge's whole
## reward, which is deliberately the opposite shape to the parry's: nothing is
## thrown, nothing is staggered, and the hero gets TIME instead.
##
## No hit-stop. A stop and a dip are both "the world slows down" and firing them
## together reads as a stutter into slow motion rather than as slow motion —
## `Feel._apply_time_scale` would hold the freeze first and the dip would begin
## from behind it. The dodge is the one reaction in the game whose feedback is
## not an impact, because nothing was impacted.
func on_perfect_dodge(_hit: Hit) -> void:
	Feel.slowmo(K.SLOWMO_SCALE, K.SLOWMO_TIME)
	FlourishVfx.dodge(get_tree().current_scene, _hero.global_position)
	# Gentle, and it is the only shake in the file below a landed jab. Something
	# happened — but what happened is that nothing hit you, and a camera kick
	# would say the opposite.
	Bus.request_shake.emit(K.SHAKE_TAP * 0.7, 0.18)
	_flurry_t = K.FLURRY_WINDOW
	Bus.perfect_dodge.emit(_hero.global_position)


## The leaping overhead the dodge opens. The lunge's shape without the lock, and
## the heaviest sword blow that does not need a jump under it.
##
## The window is spent whether or not this connects, which is the same rule the
## rest of the kit lives by — a swing that whiffs is still a swing. What it is
## NOT spent by is a refusal: `request_flurry` bails before anything happens if
## the hero is mid-swing or off the floor, and eating the reward for a press the
## game declined to honour is the one version of this that would feel unfair.
func _flurry_swing() -> void:
	if not _can_swing():
		return
	if not _hero.request_flurry(flurry_swing_time, flurry_drive_time, flurry_hop,
			flurry_stop_short, _leap_target()):
		return
	_flurry_t = 0.0
	Game.spend_stamina(K.STAMINA_LUNGE, true)
	_chain_step = 0
	_chain_timer = 0.0
	_reset_heavy_combo()
	if _yell_player != null:
		_yell_player.pitch_scale = randf_range(0.97, 1.03)
		_yell_player.play()
	_aim_sword()
	_commit(flurry_swing_time, flurry_damage_window, flurry_damage, flurry_knockback,
		K.HITSTOP_HEAVY, randf_range(0.72, 0.80), K.STUN_HEAVY)


## WHAT to leap at. The lock if there is one, otherwise the nearest body in front.
##
## The fallback is the whole reason this exists, because **after a dodge there is
## almost never a lock**: the perfect dodge is thrown mid-panic, and asking the
## player to have also been holding the shoulder button would make the reward for
## the game's hardest read pay out into thin air most of the times it was earned.
##
## Without it, an unlocked leap covered a fixed stride — `flurry_stop_short * 1.6`
## — and that number is 2.4 m, which is FURTHER than the range anything attacks
## the hero from. The director caught it exactly: airborne, 0.68 m of rise, a
## clean arc, and a goblin standing at full health behind the hero's back when the
## blade came down.
##
## `seek_cone` is generous where `parry_cone` is tight, and deliberately so. A
## parry is a claim about a direction the player chose; this is a leap the player
## has already earned and only needs aimed.
func _leap_target() -> Node3D:
	var locked := _hero.lock_target()
	if locked != null:
		return locked
	var here := _hero.global_position
	var face := -_hero.global_transform.basis.z
	var best: Node3D = null
	var best_d := flurry_seek_range
	for group in [&"enemy", &"boss"]:
		for n in get_tree().get_nodes_in_group(group):
			var body := n as Node3D
			if body == null:
				continue
			var to := K.flat(body.global_position - here)
			if to == Vector3.ZERO:
				continue
			if rad_to_deg(acos(clampf(to.dot(K.flat(face)), -1.0, 1.0))) > flurry_seek_cone:
				continue
			var d := body.global_position.distance_to(here)
			if d < best_d:
				best_d = d
				best = body
	return best


## The ordinary forward box, which is every swing except the spin. Called by
## each of them rather than restored at the END of the spin: a spin cancelled
## by a scene change or a death never reaches its own end, and the next swing
## after that one would inherit a 2.1 m sphere centred on the hero.
func _aim_sword() -> void:
	_aim_hitbox(reach * 0.62, reach * 0.55, arc_degrees)


func _light_swing(step: int) -> void:
	var variant := Hero.Swing.LIGHT1
	var dur := swing_time
	var dmg := damage
	var knock := knockback
	var hitstop := K.HITSTOP_LIGHT
	# The finisher reels a body for longer, exactly as it shoves harder and stops
	# the world for longer. Three identical staggers would make the chain's third
	# step a bigger number and nothing else.
	var stun := K.STUN_LIGHT
	match step:
		1:
			variant = Hero.Swing.LIGHT2
			dur = swing_time * chain_time_scale.x
		2:
			variant = Hero.Swing.LIGHT3
			dur = swing_time * chain_time_scale.y
			dmg += chain_finisher_bonus
			knock = chain_finisher_knockback
			hitstop = K.HITSTOP_HEAVY
			stun = K.STUN_HEAVY
	if not _can_swing():
		return
	# Only commit the swing's numbers once the hero has agreed to swing — he
	# refuses while rolling or turning, and a half-armed swing left behind by a
	# refusal would pay out on whatever landed next.
	if not _hero.request_attack(dur, variant):
		return
	_reset_heavy_combo()
	# Only this accepted-light path starts the ribbon. LIGHT3 is also the Heavy
	# finisher's clip, so triggering from `_commit` or from the animation variant
	# would put the same ordinary trail on Heavy, spin, dash and flurry.
	if slash_trail != null:
		slash_trail.begin_stroke(dur, damage_window, step == 2)
	Game.spend_stamina(K.STAMINA_SWING, true)
	# Wraps back to 0 after the finisher: the chain is a loop, not a staircase
	# you fall off the end of.
	_chain_step = (step + 1) % 3
	_chain_timer = chain_window
	_aim_sword()
	_commit(dur, damage_window, dmg, knock, hitstop,
		randf_range(0.94, 1.07) * _CHAIN_PITCH[step], stun)

## Advance the dedicated two-hit Heavy chain. Resolve the step only when the
## Intent is honoured so a release buffered during the opener becomes step two.
func _heavy_combo_swing() -> void:
	if _heavy_step == 0:
		_dash_swing(false, true)
	else:
		_heavy_swing()


func _reset_heavy_combo() -> void:
	_heavy_step = 0
	_heavy_timer = 0.0


## The heavy finisher: the leaping overhead, thrown after the dash-spin opener.
##
## It plays Hero.Swing.LIGHT3 rather than a clip of its own, and that is not
## thrift — the light chain's third step IS this swing. The Heavy chain reaches
## the same payoff after its own short dash-spin opener.
##
## It ends the dedicated Heavy chain. The light chain remains separate: mixing
## the two would make either finisher something you reach by pressing whatever,
## which is not a combo.
func _heavy_swing() -> void:
	if not _can_swing():
		return
	if not _hero.request_attack(heavy_swing_time, Hero.Swing.LIGHT3):
		return
	Game.spend_stamina(K.STAMINA_HEAVY, true)
	_chain_step = 0
	_chain_timer = 0.0
	_reset_heavy_combo()
	_aim_sword()
	# LIGHT3 is shared with the chain finisher, but this accepted Heavy-finisher path
	# has its own timing window. Trigger here so the held spin and every other
	# LIGHT3 user remain outside the ordinary blade ribbon.
	if slash_trail != null:
		slash_trail.begin_stroke(heavy_swing_time, heavy_damage_window, true)
	# The lowest pitch in the kit outside the spin. Three swings that sound
	# identical are three swings the player cannot tell apart with their eyes on
	# the enemy.
	_commit(heavy_swing_time, heavy_damage_window, heavy_damage, heavy_knockback,
		K.HITSTOP_HEAVY, randf_range(0.74, 0.82), K.STUN_HEAVY)


## The air slam has arrived. Everything the blow IS happens here, on the one
## frame the hero's feet touch — `Hero.slammed` is the only thing that knows
## which frame that is.
##
## It does not go through `_commit` and it has no damage window, and that is the
## difference between this and every other attack in the file. A swing is a blade
## travelling through an arc over time, so it is scanned across a window; a slam
## is the floor being hit, which is instantaneous, omnidirectional, and over.
## Giving it a window would mean a hero who keeps damaging things for a third of
## a second while standing in his own crater.
func _slam_impact(at: Vector3, fall_speed: float) -> void:
	# Presentation first, and specifically before the damage: `apply_hit` can kill
	# something, and a death takes its own hit-stop and its own sound. The dust
	# and the bang belong to the LANDING, which happened first.
	SlamVfx.spawn(_hero.get_parent(), at + Vector3.UP * 0.06, slam_fx_radius)
	Bus.request_sfx.emit(&"jump_slam", at)
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	# The heaviest shake in the game outside taking a hit. Feel SQUARES this
	# before it moves anything (see its docstring), so the number is not the
	# fraction of the screen it moves — 0.9 here is a hard jolt, not a wobble.
	Bus.request_shake.emit(0.90, 0.24)

	for victim in _slam_targets(at):
		var hit := Hit.make(slam_damage, at, &"sword", slam_knockback, slam_stun)
		var landed = victim.apply_hit(hit)
		if landed == false:
			continue
		# Deliberately NO per-victim hit-stop or impact sound. The landing has
		# already spent both, and a slam into four enemies that fired four
		# hit-stops would freeze the game for a fifth of a second and play the
		# steel sound as a burst of noise. One blow, one bang.
		if _impact_player != null and not _impact_player.playing:
			_impact_player.pitch_scale = randf_range(0.72, 0.80)
			_impact_player.play()
	# Silence the unused argument without dropping it from the signal: how fast
	# he was going is exactly what a future scaling of this blow would read, and
	# a signal that carries it is cheaper to keep than to re-add.
	if fall_speed < 0.0:
		return


## Everything damageable inside `slam_radius` of `at`, each listed once.
##
## A direct shape query rather than the swing hitbox, and not because it is
## tidier: `_hitbox` is an Area3D, and an Area3D's overlaps are resolved by the
## physics server on ITS schedule — turning monitoring on and reading the
## overlaps in the same frame returns the previous frame's answer, or nothing at
## all on the first. An impact that must be exact on one named frame cannot ask a
## question that is answered a frame late.
func _slam_targets(at: Vector3) -> Array[Node]:
	var out: Array[Node] = []
	var space := _hero.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = slam_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	# Chest height, for the reason `_aim_hitbox` puts the sword's sphere there: a
	# sphere sitting on the floor catches the geometry and misses the bodies.
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.7)
	q.collision_mask = K.L_ENEMY | K.L_INTERACT
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [_hero.get_rid()]

	var seen := {}
	for touch in space.intersect_shape(q, 32):
		var node := touch.get("collider") as Node
		if node == null or node == _hero or _hero.is_ancestor_of(node):
			continue
		var victim := _damageable(node)
		if victim == null:
			continue
		var id := victim.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		out.append(victim)
	return out


## Arm the swing the hero has just agreed to. Called only after a successful
## request_*, so the numbers in flight always describe a swing that is happening.
##
## `stun` defaults to the light reel rather than to zero, which is the shape the
## bug this argument was added for had: a blow with no stun is a blow the victim
## does not visibly take, and "forgot to pass it" must not be spelled the same
## way as "this blow deliberately does not stagger".
func _commit(dur: float, window: Vector2, dmg: int, knock: float,
		hitstop: int, pitch: float, stun: float = K.STUN_LIGHT) -> void:
	_swing_dur = dur
	_swing_window = window
	_swing_damage = dmg
	_swing_knock = knock
	_swing_stun = stun
	_swing_hitstop = hitstop
	_swing_t = 0.0
	_hit_this_swing.clear()
	_swing_player.pitch_scale = pitch
	_swing_player.play()


func _advance_swing(delta: float) -> void:
	_swing_t += delta
	var frac := _swing_t / maxf(_swing_dur, 0.01)

	var live := frac >= _swing_window.x and frac <= _swing_window.y
	if live != swinging:
		swinging = live
		_hitbox.monitoring = live
	if live:
		_scan()

	if frac >= 1.0:
		_swing_t = -1.0
		swinging = false
		_hitbox.monitoring = false


## Damage anything overlapping, once per swing, and only if it is actually in
## front of the hero. The sphere is generous on purpose so a near-miss connects;
## the arc test is what stops it becoming an omnidirectional aura.
func _scan() -> void:
	for body in _hitbox.get_overlapping_bodies():
		_maybe_hit(body)
	for area in _hitbox.get_overlapping_areas():
		_maybe_hit(area)


func _maybe_hit(node: Node) -> void:
	if node == null or node == _hero or _hero.is_ancestor_of(node):
		return
	var id := node.get_instance_id()
	if _hit_this_swing.has(id):
		return

	var target := node as Node3D
	if target == null:
		return
	var to := K.flat(target.global_position - _hero.global_position)
	if to != Vector3.ZERO:
		var fwd := -_hero.global_transform.basis.z
		# `_swing_arc`, not `arc_degrees`: the spin sets 360, and `angle_to` tops
		# out at 180, so a half-angle of 180 rejects nothing and the circle is
		# whole. Every other swing passes the export straight through.
		if rad_to_deg(fwd.angle_to(to)) > _swing_arc * 0.5:
			return

	var victim := _damageable(target)
	if victim == null:
		return

	_hit_this_swing[id] = true
	var hit := Hit.make(_swing_damage, _hero.global_position, &"sword", _swing_knock,
		_swing_stun)
	var landed = victim.apply_hit(hit)
	# apply_hit returns bool on a HealthComponent and null on the duck-typed
	# props that predate it, so absence of a false is treated as a landed blow.
	if landed == false:
		return

	_impact_player.pitch_scale = randf_range(0.92, 1.08)
	_impact_player.play()
	Bus.request_hitstop.emit(_swing_hitstop)


## Find whatever on, under, or OVER `node` answers the damage contract. Props
## built before HealthComponent existed implement apply_hit directly, and the
## training posts are exactly that case.
##
## **The parent step is the one that was missing**, and its absence is why the
## puzzle kit was unswingable. `TrainingPost` *is* a StaticBody3D with `apply_hit`
## on it, so a scan that only looked down worked perfectly against the one target
## anything was ever proved against. Every atom in `scripts/props/atoms/` is built
## the other way -- a plain Node3D that owns a child body called "Body" or "Post"
## -- so what the blade's Area3D reports overlapping is the CHILD, and the child
## answers nothing. `Lantern` was therefore scenery (the lights-out grid could not
## be pressed, the maze room's chest stayed walled off), and `Urn` was breakable
## by arrows only, under a comment claiming the opposite.
##
## `Arrow._damageable` has always walked up, which is exactly why the two
## diverged without anyone noticing: the same prop answered one weapon and not
## the other, and no proof swung a sword at either. Kept as a copy of that shape
## rather than shared, because the two run against different queries -- but they
## are the same three questions in the same order, and they must stay that way.
func _damageable(node: Node) -> Node:
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	# One level, not a walk to the root. A prop owns its own body; anything
	# further up is the ROOM, and a sword that found a room's `apply_hit` would
	# damage the floor it is standing on.
	var parent := node.get_parent()
	if parent != null and parent.has_method(&"apply_hit"):
		return parent
	return null


# --- Queries for other packages ---------------------------------------------

## Would a blow arriving from `from_pos` be stopped by the raised shield?
## The cone is generous but strictly frontal — OOT does not let you block your
## own back, and being punished for turning away is the point of the shield.
func blocks(from_pos: Vector3) -> bool:
	if not blocking or _hero == null or Game.stamina <= 0.0:
		return false
	var to := K.flat(from_pos - _hero.global_position)
	if to == Vector3.ZERO:
		return false
	var fwd := -_hero.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(to)) <= block_cone


## Tell the world a blow was stopped. The blocker calls this so a blocked blow
## reads differently from one that never arrived.
##
## It used to build an `AudioStreamPlayer3D` per block and free it on `finished`,
## which is exactly the thing CONTRACT §8 forbids — a prop holding a player for a
## world sound. `Sfx` hangs `shield_block` off this signal now, so the clang is
## chosen in one place with everything else and a fight full of parries allocates
## nothing. All this function does is say what happened and where.
func on_blocked(at: Vector3, normal: Vector3) -> void:
	Bus.shield_blocked.emit(at, normal)
