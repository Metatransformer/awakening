class_name BossDb
extends RefCounted
## The four bosses, as data. Twelve beats, five shapes, one shared behaviour loop.
##
## `docs/GDD.md` §5 and `docs/SCOPE.md` §1: a boss is an existing monster GLB,
## fitted to a bigger height, re-tinted, and given an authored move set. Zero new
## models. Nothing in this file loads a scene, spawns a node or ticks a timer --
## it is a table, and the Boss node (P9) is a loop over it.
##
## ============================================================================
## ## THE CONTRACT FOR THE EXECUTOR
## ============================================================================
##
## Read this instead of guessing. Every rule below is here because doing the
## obvious thing instead produces a fight that is wrong in a way no log shows.
##
## **1. Build the body from the row, in this order.**
##
##   a. `load(MODEL_DIR + model + ".glb")`, instantiate, `rotation.y = PI` on the
##      MODEL node. Every monster GLB in this project is authored looking down
##      +Z; the body's `-basis.z` stays the facing contract (`docs/CONTRACT.md`
##      §2.5, `CLAUDE.md` §4). This has bitten the project three times. Do not
##      "fix" it by dropping the +PI in the steering.
##   b. Fit the model to `height` **by measurement**, exactly as
##      `Enemy._build_model` does: `model.scale = ONE * (height / _model_height(model))`.
##      There is deliberately no `scale` key in this table — the four GLBs come
##      from four sources at four native sizes, so a scale FACTOR would mean four
##      different things and would rot the first time one is reimported. `height`
##      is metres, the same unit and the same contract as `Enemy.DEFS[...]["height"]`.
##   c. **Apply `tint` to the surface override materials BEFORE calling
##      `HitFlash.bind()`.** `bind()` records each surface's colour as the
##      baseline that `restore()` returns to, so a tint applied after binding is
##      erased by the first landed blow — the boss goes white, then reverts to a
##      grey stock golem for the rest of the fight, and the frame that shows it
##      is the frame after the player's first hit. `mi.get_active_material()`
##      returns the override, so tinting first is enough: `bind()` duplicates the
##      already-tinted material and remembers the right baseline.
##
## **2. Health and damage are ABSOLUTE. Do not run them through `Prog`.**
## `Prog.health_mult`, `Prog.damage_bonus` and `Prog.ELITE_*` exist to curve the
## generated roster against the floor it spawned on. A boss is authored for
## exactly one floor and its numbers are already that floor's numbers.
##
## **3. `Prog.windup_scale` does not apply either.** The tell is the fight. It is
## the same length on run one and run fifty.
##
## **4. One beat is exactly this sequence, and nothing may reorder it:**
##
##   `pick_beat()` -> TELL (`tell.time`) -> COMMIT -> RECOVER (`recover`)
##   -> either the authored weak-point APERTURE or a moving REPOSITION
##
##   * **TELL** — hold still, track the hero slowly, hold `tell.pose`, and drive
##     `HitFlash.glow(tell.color, t * tell.energy)` **every frame** off the tell's
##     own timer (a tween here survives its own interruption and leaves the body
##     lit; see `Enemy._tick_windup`). Emit `tell.sfx` once, on the first frame.
##     Nothing is damaging during a tell.
##   * **COMMIT** — the instant the tell expires: drop the glow, emit `sfx`,
##     deliver `shape` (§5 below) for `damage` HP with `knockback`
##     and `stun`, and `Bus.request_hitstop.emit(K.HITSTOP_HEAVY)`.
##   * **RECOVER** — rooted, hitboxes closed, no new tell. This is the beat's
##     animation tail.
##   * **APERTURE** — only a weak point authored as `recover` stays rooted for
##     `punish` seconds. Correct item input converts it into the true stagger;
##     every other blow clangs for 0 HP.
##   * **REPOSITION** — every other beat returns to orbit after `recover`.
##     `punish` is its minimum visible movement breath and `cooldown` gates the
##     next tell; both count down while the boss runs. A live thrown-zone weak
##     point also blocks the next tell until its last fuse closes or it breaks.
##     This is deliberately not a stationary fake opening.
##
## **5. Five shapes. Implement each once; there are twelve beats and no
## thirteenth shape.** Read only the keys listed — a beat carries the keys its
## shape needs and no others.
##
##   | `shape`  | keys | what it is |
##   |---|---|---|
##   | `arc`    | `reach`, `arc_deg` | a cone in front of the boss, `reach` m long, `arc_deg` HALF-angle either side of `-basis.z`. Resolved once at commit. |
##   | `slam`   | `radius`, `safe_inner` | a ring centred on the boss: hurts between `safe_inner` and `radius`. `safe_inner == 0` is a solid disc. |
##   | `charge` | `reach`, `radius`, `speed` | the boss travels up to `reach` m at `speed` m/s along the heading it locked at commit, damaging bodies within `radius` of its path. Once per charge, per body. Stops on a wall. |
##   | `zone`   | `radius`, `fuse`, `count` | `count` destinations marked at commit; authored throws travel there, then burn `fuse`. They hurt the player and nothing else. |
##   | `summon` | `kind`, `count`, `cap`, `radius` | `count` ordinary `Enemy`s of `kind` at `radius` from the boss. Deals no damage. Refuse the beat if `cap` of its summons are already alive. |
##
##   `kind` is always a key of `Enemy.DEFS`, and it has to be: `Enemy._ready`
##   does `DEFS.get(kind, DEFS[&"skeleton"])`, so summoning a `troll` — whose
##   GLB exists but whose stats do not — silently spawns a troll-shaped skeleton.
##   `validate()` checks this.
##
## **5b. ARMOUR AND THE AUTHORED WEAK POINT.** Each row names one floor-item
## interaction, one beat, and one exposure (`recover`, `charge`, or `zones`).
## Correct input consumes that aperture and opens the true stagger window;
## everything else rings off. Parry's public `stagger()` remains a short poise
## interruption and never substitutes for the item interaction.
##
## **6. Choosing is `pick_beat`, not a sequence.** Call it; do not re-implement
## the weights, the repeat penalty or the range gate anywhere else. A scripted
## order is a memorised loop, and a memorised loop is a knowledge check
## (`gamestack` combat-design; GDD pillar 3). Pass the flat boss-to-hero distance
## in metres and the id of the beat that just finished.
##
## **7. Two pressure phases, one move set and one health bar.** Phase two changes
## movement and authored selection weights only. It never adds or removes a beat,
## and tell durations remain identical, so the learned vocabulary stays valid.
##
## **8. Music picks itself.** Emit `Bus.boss_engaged(self)` on the first frame of
## the fight and `Bus.boss_defeated` on death. Do **not** call `Music`, and do
## **not** load `music` and play it: `Music` is the only thing in the project
## that owns an `AudioStreamPlayer` for a track (`docs/CONTRACT.md` §8), it
## already listens to both of those signals, and a boss that started its own
## track would be a second soundtrack fighting the crossfade.
##
##   So what is the `music` field for? There are exactly four boss tracks and
##   exactly four bosses, and `Music.POOLS[Mood.BOSS]` currently draws one at
##   random — so the Warden can get the Riven Knight's cue. The pairing is a
##   design decision and it belongs in the design table, which is here. Nothing
##   reads it today, deliberately: wiring it is a one-line `prefer(path)` on
##   `Music` and that file is orchestrator-owned. **`# NEEDS:` a `Music.prefer()`
##   that a boss can hand a path to before it emits `boss_engaged`.** Until then
##   this field is the authored answer sitting where the answer goes, not a
##   feature that half-exists.
##
## **9. On death:** a floor boss reveals a great chest holding `drop.item`, while
## a miniboss grants its progress-token item immediately. Place `drop.relic` on
## the floor (it goes in the BAG, GDD §3 — it is not a grant), emit
## `Bus.boss_defeated`, and never rebuild the fight (GDD §5.1). An unclaimed
## great chest may remain in the spent arena. This file owns none of that; it
## only says which ids.

const MODEL_DIR := "res://assets/monsters/"

# --- The closed vocabularies -------------------------------------------------
# Small on purpose. Twelve beats sharing five shapes and five poses is the
# design; twelve bespoke beats is the failure the scope doc names.

const SHAPE_ARC := &"arc"
const SHAPE_SLAM := &"slam"
const SHAPE_CHARGE := &"charge"
const SHAPE_ZONE := &"zone"
const SHAPE_SUMMON := &"summon"

const SHAPES: Array[StringName] = [
	SHAPE_ARC, SHAPE_SLAM, SHAPE_CHARGE, SHAPE_ZONE, SHAPE_SUMMON,
]

const OPEN_RECOVER := &"recover"
const OPEN_CHARGE := &"charge"
const OPEN_ZONES := &"zones"
const EXPOSURES: Array[StringName] = [OPEN_RECOVER, OPEN_CHARGE, OPEN_ZONES]

const STAGGER_SWORD := &"sword"
const STAGGER_ARROW := &"arrow"
const STAGGER_BOMB := &"bomb"
const STAGGER_HOOKSHOT := &"hookshot"
const STAGGER_KINDS: Array[StringName] = [
	STAGGER_SWORD, STAGGER_ARROW, STAGGER_BOMB, STAGGER_HOOKSHOT,
]

## Bare sword chain damage: 2 + 2 + 4 HP. Each row's vulnerability multiplier
## scales that one complete chain to exactly one health segment, so a competent
## opening always closes one of the promised three/four cycles while partial
## strings still leave work for the next exposure.
const STAGGER_BASE_CHAIN_DAMAGE := 8.0

## What the body DOES during a tell. Five poses, each implemented once by the
## executor as a pose on the MODEL node (never on the body — the body's yaw is
## the facing contract, and `Enemy._flinch` explains why at length).
##
## `Enemy.WINDUP_LEAN_DEG` is 17 degrees, which is right for a 1.7 m skeleton
## across a dark room. A boss is 3.4-4.2 m in a lit arena and gets more: these
## are gross silhouette changes, readable in a STILL FRAME, not nudges.
const POSE_REAR := &"rear"       ## hauls back and up — the classic overhead cock
const POSE_CROUCH := &"crouch"   ## sinks and gathers; the body gets shorter
const POSE_TILT := &"tilt"       ## drops one shoulder and points; asymmetric
const POSE_RISE := &"rise"       ## stands to full height / lifts off the floor
const POSE_SPREAD := &"spread"   ## arms wide, dead still, glow travelling out

const POSES: Array[StringName] = [
	POSE_REAR, POSE_CROUCH, POSE_TILT, POSE_RISE, POSE_SPREAD,
]

## What a boss's ONE escalation does to the room. `docs/BOSSES.md` §5.
##
## Separate from the actor's pressure phase: a `turn` may touch **the fence
## radius, the cover posts and the room's light, and nothing else, ever**.
##
## Four kinds, one per boss, and that is the cap. A fifth is a proposal to make
## the room a mechanic and it goes to the owner rather than into this list.
const TURN_SHRINK := &"shrink"    ## the seal walks in; a second fence at `to` m
const TURN_TOPPLE := &"topple"    ## cover posts slump; `cover_count` -> `to`
const TURN_DOUSE := &"douse"      ## the room's sconces go out
const TURN_KEYSTONE := &"keystone"  ## a hookable mass drops into the middle

const TURN_KINDS: Array[StringName] = [
	TURN_SHRINK, TURN_TOPPLE, TURN_DOUSE, TURN_KEYSTONE,
]

## One threshold for all four bosses, and it is `0.50` on every row rather than a
## constant here so that the row still reads as the whole fight. Four different
## thresholds would be four tunings nobody can compare against each other, which
## is why §5 fixes it at half health and why `validate()` only checks the RANGE:
## a row is allowed to be wrong here in a way a reader can see, and not in a way
## that puts the turn after the kill.
const TURN_AT := 0.50

## No two of the twelve beats share a (pose, colour) pair, and no boss uses a
## pose twice. That is the whole readability budget spent deliberately: three
## beats a player cannot tell apart is one beat with extra steps, and a fight
## whose three tells differ only in duration is a fight you learn by dying.
## `validate()` enforces both rules so a future edit cannot quietly break them.
##
## Two palette entries are NOT available to a tell, and this is not fussiness:
## GOLD is currency and only currency, and EXTRACT CYAN is the way out — the
## hookshot line and the extraction node (`docs/STYLEGUIDE.md` §2). A boss that
## flashes cyan before it kills you has taught the player that the exit colour
## means danger. FROST is out for the same reason at one remove: it is what a
## hookshot-frozen body looks like (`Pal.FROST`, `HitFlash.ice`).


# --- The table ----------------------------------------------------------------
## `static var`, not `const`. The rows hold `Pal.*` colours and `SHAPE_*`
## StringNames, and a const Dictionary holding another class's constants is not a
## constant expression (`CLAUDE.md` §3). A static var is still built once and
## still shared.
static var BOSSES := {
	# =========================================================================
	&"cistern_warden": {
		"floor": 1,
		"title": "THE CISTERN WARDEN",
		"model": &"golem",
		# Metres. An orc, the tallest thing in the ordinary roster, is 1.95 m.
		# Just under twice that is the smallest scale-up that still reads as
		# "this is not one of those" from the doorway.
		"height": 3.40,
		# Drowned bronze. The albedo goes cold and slightly blue-green (the
		# Cistern is standing water over Vyr metal); the emission is the
		# verdigris in its seams, which is also its tell colour on beat one.
		"tint": {
			"albedo": Pal.COBALT, "albedo_mix": 0.34,
			"emission": Pal.MOSS, "energy": 0.22,
		},
		# Four 12 HP stagger segments. Outside a true stagger the armour takes no
		# health damage, and a single opening can never remove more than one.
		"health": 48,
		"movement": {
			"phase_1": {"speed": 2.5, "orbit_radius": 4.2,
				"orbit_strength": 1.10, "reposition": 0.75},
			"phase_2": {"speed": 3.2, "orbit_radius": 3.6,
				"orbit_strength": 1.45, "reposition": 0.60},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_SWORD, "beat": &"cistern_drop", "open": OPEN_RECOVER,
			"goal": 4, "window": 2.8, "multiplier": 1.50, "color": Pal.VITAL,
		},
		"arena": {
			"radius": 11.0,
			# No cover, deliberately. This is the first boss in the game and the
			# lesson is *read the tell*, not *find the pillar*. A pillar here
			# would teach the player to solve beat two by standing behind
			# something, and beat two's answer is to walk INTO it.
			"cover": false, "cover_count": 0,
			# THE TURN (`docs/BOSSES.md` §5, §6.1). The fence walks in from 11.0
			# to 8.5 m at half health, and it is aimed at exactly one player: the
			# one who has spent the first half of the fight kiting in the far
			# side of the room.
			#
			# **8.5 IS THE NUMBER THE OUTER BAND CAN AFFORD, AND IT IS MEASURED**
			# (board card 47, `boss_cistern.gd` §M). What the shrink can delete is
			# not the donut's hole -- that is `safe_inner`, a fact about the beat,
			# and no fence reaches it -- but the ring of floor OUTSIDE the 6.2 m
			# slam, which is the only other place in the room a hero may stand.
			# A seal is twenty 0.45 m panels centred ON the radius, so the floor
			# stops ~0.23 m inside the number and a 0.35 m hero stops 0.35 further
			# in: the band is `to - 0.58 - 6.2` metres wide. Measured at 8.5 it is
			# 1.72 m, against 4.22 m at 11.0. It closes to NOTHING at about 6.8 m,
			# and a Warden below that is a fight with one answer instead of two.
			#
			# The expensive one of the four. See `BossArena._turn_shrink`: it
			# needs a SECOND fence (scaling a ring of fixed-width panels leaves
			# daylight at every joint), `Boss.set_arena_radius()` behind it, and
			# the annulus guard in front of it.
			"turn": {"kind": TURN_SHRINK, "at": TURN_AT, "to": 8.5},
		},
		"drop": {"item": &"bow", "relic": &"anvil_plate"},
		"music": "res://audio/music/boss_1.ogg",
		"beats": [
			{
				"id": &"sluice_sweep", "name": "Sluice Sweep",
				"tell": {
					"time": 1.05, "pose": POSE_REAR,
					"color": Pal.MOSS, "energy": 0.55,
					"sfx": &"craft_grind",
					"read": "It hauls one arm back across its body until the "
						+ "shoulder is above the head, and the verdigris in its "
						+ "seams lights green from the elbow outward. The sheet "
						+ "of water coming off that arm hangs in the air.",
				},
				"shape": SHAPE_ARC, "reach": 4.6, "arc_deg": 75.0,
				"damage": 3, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.24,
				"sfx": &"weapon_impact_blunt",
				"recover": 0.80, "punish": 1.10, "cooldown": 1.10,
				"weight": 3.0, "phase_2_weight": 2.2,
				"min_range": 0.0, "max_range": 6.0,
			},
			{
				"id": &"cistern_drop", "name": "Cistern Drop",
				"tell": {
					"time": 1.30, "pose": POSE_RISE,
					"color": Pal.BONE, "energy": 0.75,
					"sfx": &"spell_charge",
					"read": "It stands to full height with both fists locked "
						+ "over its head and stops moving entirely — the only "
						+ "beat in the fight where it is taller than it walks. "
						+ "Pale light runs down the cracks from the shoulders "
						+ "to the floor and pools around its feet.",
				},
				# A donut: safe under its chin, lethal at the ring. The whole
				# teaching value of this boss is in `safe_inner` — the answer to
				# the biggest, loudest attack is to walk toward it, and the
				# 1.60 s punish is the reward for having done that.
				"shape": SHAPE_SLAM, "radius": 6.2, "safe_inner": 2.1,
				"leap": {"time": 0.78, "height": 2.2},
				"damage": 4, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.36,
				"sfx": &"jump_slam",
				"recover": 1.10, "punish": 1.60, "cooldown": 1.60,
				"weight": 3.0, "phase_2_weight": 4.8,
				"min_range": 0.0, "max_range": 7.5,
			},
			{
				"id": &"drown_pool", "name": "Drown Pool",
				"tell": {
					"time": 0.95, "pose": POSE_TILT,
					"color": Pal.COBALT, "energy": 0.45,
					"sfx": &"spell_charge_frost",
					"read": "It cants hard to one side and points a flat palm "
						+ "at the floor. Two discs of water go mirror-still and "
						+ "grow a bright blue rim, a full second before either "
						+ "of them bursts, and they are drawn where the hero IS.",
				},
				"shape": SHAPE_ZONE, "radius": 2.6, "fuse": 1.10, "count": 2,
				"throw": {"flight": 0.65, "height": 1.8},
				"damage": 3, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.20,
				"sfx": &"spell_impact_frost",
				# Cooldown outruns the punish here: it has to walk back into
				# range afterwards, and watching a stone thing wade toward you
				# is the rest beat this fight needs between two committed swings.
				#
				# This is also the Warden's only beat with reach, so between
				# 7.5 m and 14 m it is the ONLY eligible pick and `pick_beat`
				# returns it every time. That is the intended read and not a
				# gate that has gone wrong: a kiting hero gets the floor drowned
				# under him while a stone thing wades closer, and the moment it
				# is inside 7.5 m all three beats are live again. A director
				# logging "drown_pool x4" at range has caught the design.
				"recover": 0.55, "punish": 1.35, "cooldown": 1.60,
				"weight": 2.0, "phase_2_weight": 2.6,
				"min_range": 0.0, "max_range": 14.0,
			},
		],
	},

	# =========================================================================
	&"slag_ogre": {
		"floor": 2,
		"title": "THE SLAG OGRE",
		"model": &"ogre",
		"height": 3.80,
		# Cooling iron: a dark rust body with molten red in the cracks. Hotter
		# emission energy than the Warden because the Foundry is the one floor
		# whose own light is orange — a dim tint would vanish into the room.
		"tint": {
			"albedo": Pal.RUST, "albedo_mix": 0.30,
			"emission": Pal.VITAL, "energy": 0.34,
		},
		# Four 18 HP stagger segments. Weapon strength changes how much of each
		# window is needed, never how many fully exploited windows can kill it.
		"health": 72,
		"movement": {
			"phase_1": {"speed": 2.7, "orbit_radius": 4.8,
				"orbit_strength": 1.15, "reposition": 0.75},
			"phase_2": {"speed": 3.5, "orbit_radius": 4.1,
				"orbit_strength": 1.50, "reposition": 0.55},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_ARROW, "beat": &"bellows_charge", "open": OPEN_CHARGE,
			"goal": 4, "window": 3.2, "multiplier": 2.25, "color": Pal.COBALT,
		},
		"arena": {
			"radius": 12.0,
			# Three slag pillars, and they are load-bearing design rather than
			# set dressing: this is the fight that introduces `charge`, and a
			# charge lane with nothing to break it is a fight decided by
			# footspeed. The pillars are what make the charge a decision.
			"cover": true, "cover_count": 3,
			# THE TURN (`docs/BOSSES.md` §5, §6.2). Two of the three pillars
			# slump into the slag and the lane opens up: the same charge, with
			# two thirds of its answer taken away. It escalates the fight by
			# subtracting the player's tool rather than by adding the boss a
			# move, which is the cheapest honest reading of "the escalation is
			# the room" -- and `_build_cover` already names the posts `Cover%d`,
			# so it is `to` posts kept and the rest sunk.
			"turn": {"kind": TURN_TOPPLE, "at": TURN_AT, "to": 1},
		},
		# `kiln_core`, not `glass_kiln_core`. GDD §6.2 calls the object the
		# "Glass-Kiln Core" and the obvious id is the wrong one: `RelicDb` is the
		# catalogue that owns relic ids (GDD §6.1) and it spells this one
		# `kiln_core`. Checked against `RelicDb`, not against the GDD's prose.
		"drop": {"item": &"burst", "relic": &"kiln_core"},
		"music": "res://audio/music/boss_2.ogg",
		"beats": [
			{
				"id": &"bellows_charge", "name": "Bellows Charge",
				"tell": {
					"time": 0.90, "pose": POSE_TILT,
					"color": Pal.RUST, "energy": 0.70,
					"sfx": &"ogre_alert",
					"read": "It drops its head and its left shoulder and plants "
						+ "one foot behind. The bellows-scar down its back opens "
						+ "into a single hard orange line, and that line points "
						+ "exactly where it is about to go — the tell is a "
						+ "direction, not just a warning.",
				},
				# **THE RECEPTACLE** (§5b, `docs/BOSSES.md` §6.2). This is the beat
				# the floor's verb answers, and the numbers are why: 11.0 / 13.0 is
				# 0.85 s of travel, and `min_range` 4.5 is the widest in the game --
				# it cannot be thrown at contact range, so the player it is thrown at
				# is by definition standing where a bow is the weapon in hand. An
				# arrow into that travel stops it dead. Not into the tell.
				"shape": SHAPE_CHARGE, "reach": 11.0, "radius": 1.5,
				"speed": 13.0,
				"damage": 4, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.40,
				"sfx": &"weapon_impact_blunt_2h_heavy",
				# Its longest post-commit movement breath: a missed arrow still
				# leaves time to reset spacing, but the armoured back is not a
				# second health-damage answer.
				"recover": 1.20, "punish": 1.70, "cooldown": 1.70,
				"weight": 3.0, "phase_2_weight": 4.8,
				"min_range": 4.5, "max_range": 16.0,
			},
			{
				"id": &"slag_backhand", "name": "Slag Backhand",
				"tell": {
					"time": 0.72, "pose": POSE_REAR,
					"color": Pal.VITAL, "energy": 0.60,
					"sfx": &"attack_prepare_1",
					"read": "It cocks one arm behind its head and the cooled "
						+ "crust on that fist splits open along the knuckles. "
						+ "For three quarters of a second the brightest thing in "
						+ "the arena is a fist at chest height, off to one side.",
				},
				# The widest arc in the game and the shortest tell. This is the
				# beat that punishes standing in front of it out of habit. Its
				# one-second moving breath is deliberately the smallest of the
				# three: the cheap attack buys the cheap reset.
				"shape": SHAPE_ARC, "reach": 4.2, "arc_deg": 95.0,
				"damage": 5, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.30,
				"sfx": &"weapon_impact_mace_1",
				"recover": 0.70, "punish": 1.00, "cooldown": 1.00,
				"weight": 4.0, "phase_2_weight": 4.5,
				"min_range": 0.0, "max_range": 5.5,
			},
			{
				"id": &"tap_the_ladle", "name": "Tap the Ladle",
				"tell": {
					"time": 1.15, "pose": POSE_CROUCH,
					"color": Pal.BONE, "energy": 0.80,
					"sfx": &"spell_charge_fire",
					"read": "It squats — the only time it is shorter than the "
						+ "hero — scoops the floor with both hands and comes up "
						+ "holding a sagging white-hot double handful. Three "
						+ "white rings are already burnt into the flagstones "
						+ "where it will put them.",
				},
				"shape": SHAPE_ZONE, "radius": 2.3, "fuse": 1.30, "count": 3,
				"throw": {"flight": 0.75, "height": 2.2},
				"damage": 4, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.22,
				"sfx": &"spell_impact_fire",
				"recover": 0.90, "punish": 1.45, "cooldown": 1.70,
				"weight": 2.0, "phase_2_weight": 1.6,
				"min_range": 0.0, "max_range": 16.0,
			},
		],
	},

	# =========================================================================
	&"bellwake": {
		"floor": 3,
		"title": "THE BELLWAKE",
		"model": &"wraith",
		# The tallest of the four and the only one that does not touch the
		# floor. Height is the number the hitbox, the head marker and the
		# silhouette all read, so this one number is most of "it hangs".
		"height": 4.20,
		# The wraith GLB is already emissive; `HitFlash` records that as the
		# baseline and restores to it, which is why the energy here is the
		# highest of the four and still reads as the body's own light rather
		# than as a tell. Violet, and violet is otherwise legendary-rarity only
		# — one boss in the game gets to borrow it, and this is the one.
		"tint": {
			"albedo": Pal.MIDNIGHT, "albedo_mix": 0.42,
			"emission": Pal.ARCANE, "energy": 0.46,
		},
		# Four 24 HP stagger segments. Its own thrown Undertow can break the bomb
		# weak point when it bursts close, so the loop never depends on ammunition.
		"health": 96,
		"movement": {
			"phase_1": {"speed": 2.9, "orbit_radius": 5.3,
				"orbit_strength": 1.10, "reposition": 0.70},
			"phase_2": {"speed": 3.8, "orbit_radius": 4.5,
				"orbit_strength": 1.50, "reposition": 0.50},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_BOMB, "beat": &"undertow", "open": OPEN_ZONES,
			"goal": 4, "window": 3.2, "multiplier": 3.00, "color": Pal.MOSS,
		},
		"arena": {
			"radius": 13.0,
			# The largest arena and no cover. Beat one is a ring that fills it,
			# and a pillar would turn "the note reaches everywhere" into "stand
			# behind the pillar" — which would delete the only shape this boss
			# has that the other three do not.
			"cover": false, "cover_count": 0,
			# THE TURN (`docs/BOSSES.md` §5, §6.3). The Choir's sconces go out.
			# The only one of the four that costs no geometry, and board card 6
			# settled that it stays `douse` rather than being promoted to a
			# `shrink` -- this fight's escalation is that you can no longer see
			# the room you are being asked to read the ring across.
			#
			# Safe against GDD pillar 5 for a reason the code already decided:
			# the floor markers are built SHADING_MODE_UNSHADED (`boss.gd`,
			# `_mark_mat`) precisely so a warning does not dim with the room, and
			# this body is the most emissive of the four. `boss_cistern.gd` §L
			# photographs it rather than taking that on trust -- and the
			# photograph is why `energy` is 0.15 and not 0. A true blackout was
			# built first and it is a BLACK FRAME with a health bar in it: no
			# floor, no hero, nothing left with an edge. §6.3's row already said
			# 0.15 and it was right. What the turn takes away is the room's
			# READING light, so the ring and the disc are the only edges left.
			"turn": {"kind": TURN_DOUSE, "at": TURN_AT, "energy": 0.15},
		},
		"drop": {"item": &"hookshot", "relic": &"sounding_rod"},
		"music": "res://audio/music/boss_3.ogg",
		"beats": [
			{
				"id": &"first_toll", "name": "The First Toll",
				"tell": {
					"time": 1.20, "pose": POSE_RISE,
					"color": Pal.ARCANE, "energy": 0.85,
					"sfx": &"glint_bell",
					"read": "It rises a body-length with its arms folded in, and "
						+ "a violet ring the width of the arena is scratched onto "
						+ "the floor beneath it. The ring TIGHTENS as the note "
						+ "gathers — the tell is not that something is coming, it "
						+ "is a drawing of exactly how far.",
				},
				# Solid disc, no safe inner: the answer is to be outside it, and
				# the tell has just drawn where outside is. Deliberately the
				# mirror of the Warden's donut so the two slams are not one
				# attack in two hues.
				"shape": SHAPE_SLAM, "radius": 7.5, "safe_inner": 0.0,
				"leap": {"time": 0.95, "height": 3.0},
				"damage": 5, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.34,
				"sfx": &"spell_impact_dark",
				"recover": 1.15, "punish": 1.55, "cooldown": 1.55,
				"weight": 3.0, "phase_2_weight": 4.2,
				"min_range": 0.0, "max_range": 9.5,
			},
			{
				"id": &"hushing_choir", "name": "The Hushing Choir",
				"tell": {
					"time": 1.40, "pose": POSE_SPREAD,
					"color": Pal.COBALT, "energy": 0.50,
					"sfx": &"cast_conjuration",
					"read": "It opens both arms to their full span and holds "
						+ "perfectly still — the longest tell in the game. Two "
						+ "blue outlines of standing figures fade up against the "
						+ "far wall a full beat before they have bodies, so you "
						+ "know where they will be and can be somewhere else.",
				},
				# `skeleton`, because it is a key of `Enemy.DEFS`. `troll` and
				# `knight_iron` have GLBs but no stat rows, and Enemy silently
				# falls back to skeleton's numbers under the wrong model — a
				# boss that summons a 14 HP troll-looking 6 HP
				# skeleton is a fight nobody can tune. See `validate()`.
				"shape": SHAPE_SUMMON, "kind": &"skeleton", "count": 2,
				"cap": 4, "radius": 8.0,
				"damage": 0, "knockback": 0.0, "stun": 0.0,
				"sfx": &"cast_conjuration_1",
				# Two seconds of guaranteed reposition and six seconds before the
				# next tell. A summon on a short clock is a boss you lose to
				# arithmetic rather than to reading, and the whole cost of
				# adding bodies is paid here as room to handle the adds.
				"recover": 1.30, "punish": 2.00, "cooldown": 6.00,
				"weight": 1.0, "phase_2_weight": 0.7,
				"min_range": 0.0, "max_range": 16.0,
			},
			{
				"id": &"undertow", "name": "Undertow",
				"tell": {
					"time": 1.00, "pose": POSE_TILT,
					"color": Pal.BONE, "energy": 0.40,
					"sfx": &"glint_hiss",
					"read": "It cants sideways and extends one long hand at the "
						+ "floor. A pale hairline circle scratches itself into "
						+ "the flagstones under the hero and starts to hum "
						+ "audibly before anything about the body has changed.",
				},
				"shape": SHAPE_ZONE, "radius": 3.2, "fuse": 1.20, "count": 1,
				"throw": {"flight": 0.80, "height": 2.6},
				"damage": 5, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.26,
				"sfx": &"spell_impact",
				"recover": 0.60, "punish": 1.20, "cooldown": 1.40,
				"weight": 3.0, "phase_2_weight": 4.8,
				"min_range": 0.0, "max_range": 16.0,
			},
		],
	},

	# =========================================================================
	&"riven_knight": {
		"floor": 4,
		"title": "THE RIVEN KNIGHT",
		"model": &"knight_iron",
		# The SHORTEST of the four, and on purpose. Three bosses have been
		# bigger than the last one; the last boss being man-sized and faster
		# than all of them is the only silhouette surprise the roster has left,
		# and it costs nothing.
		"height": 3.60,
		# Cold iron with one hot line down the split. The albedo goes toward the
		# deepest thing in the palette so the crack is the only saturated pixel
		# on the body — this fight is read off a single red seam.
		"tint": {
			"albedo": Pal.VOID, "albedo_mix": 0.38,
			"emission": Pal.VITAL, "energy": 0.30,
		},
		# Four 32 HP stagger segments. The hookshot opens the planted-sword weak
		# point after Call the Iron; the adds complicate access, not the arithmetic.
		"health": 128,
		"movement": {
			"phase_1": {"speed": 3.2, "orbit_radius": 4.4,
				"orbit_strength": 1.30, "reposition": 0.60},
			"phase_2": {"speed": 4.3, "orbit_radius": 3.7,
				"orbit_strength": 1.80, "reposition": 0.45},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_HOOKSHOT, "beat": &"call_the_iron",
			"open": OPEN_RECOVER, "goal": 4, "window": 3.4,
			"multiplier": 4.00, "color": Pal.BONE,
		},
		"arena": {
			"radius": 12.5,
			# Two broken gate pylons. Same reason the Foundry has cover: this is
			# the other charge in the game, and it is faster and longer. Without
			# something to put between you and the lane, floor 4's best beat is
			# a footrace.
			"cover": true, "cover_count": 2,
			# THE TURN (`docs/BOSSES.md` §5, §6.4). The broken keystone comes
			# down in the middle of the arena, and it is the only turn of the
			# four that ADDS the player something: a `HookTarget` in a fight
			# whose boss holds the far side of the room. Before the turn the
			# hookshot has nothing in here to bite -- §6.4 is emphatic that the
			# failed press is half the fight, and §9 asks for a photograph of it.
			#
			# `HookTarget`, not `HookRing`. SCOPE §1's puzzle-atom count is 9 and
			# this does not move it: the target is the FIRER's contract, and the
			# atom is the ring that reports being bitten.
			"turn": {"kind": TURN_KEYSTONE, "at": TURN_AT},
		},
		# `pillar_shard`, not `waterwheel_gear`. GDD §6.2 deleted the Waterwheel
		# Gear and moved the Pillar-Shard onto this boss to fill the freed slot,
		# and this row was still naming the deleted one -- an id no longer in
		# `RelicDb.RELICS`, so boss 4 was dropping an object the Lanternkeeper
		# had never heard of. `validate()` below has caught exactly this class of
		# error since the Glass-Kiln Core was misspelled; it only ever runs when
		# a director asks it to, which is why `RelicDb.validate()` now asks the
		# same question from the relic side as well.
		"drop": {"item": &"far_lantern", "relic": &"pillar_shard"},
		"music": "res://audio/music/boss_4.ogg",
		"beats": [
			{
				"id": &"gate_lunge", "name": "Gate Lunge",
				"tell": {
					"time": 0.78, "pose": POSE_CROUCH,
					"color": Pal.VITAL, "energy": 0.65,
					"sfx": &"sword_charging",
					"read": "It sinks onto its back leg and levels the blade at "
						+ "hip height, and one red line runs the whole length of "
						+ "that blade. The line is the lane. It is the shortest "
						+ "tell of the three and it tells you the most.",
				},
				"shape": SHAPE_CHARGE, "reach": 12.0, "radius": 1.2,
				"speed": 16.0,
				"damage": 6, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.38,
				"sfx": &"weapon_impact_stab_1",
				"recover": 1.05, "punish": 1.35, "cooldown": 1.35,
				"weight": 3.0, "phase_2_weight": 4.2,
				"min_range": 1.0, "max_range": 16.0,
			},
			{
				"id": &"riven_arc", "name": "Riven Arc",
				"tell": {
					"time": 0.62, "pose": POSE_REAR,
					"color": Pal.RUST, "energy": 0.55,
					"sfx": &"spell_charge_dark_3",
					"read": "The sword comes over the shoulder in a single frame "
						+ "and then HOLDS, dead still, while the split down the "
						+ "breastplate glows through the gap in the plate. It is "
						+ "the stillness that reads, not the movement.",
				},
				# The tightest numbers in the game: 0.62 s of tell and 0.90 s of
				# moving reset. Still above `Prog.WINDUP_FLOOR` territory; the
				# health opening remains Call the Iron's hookshot stagger.
				"shape": SHAPE_ARC, "reach": 4.0, "arc_deg": 70.0,
				"damage": 6, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.32,
				"sfx": &"weapon_impact_blade",
				"recover": 0.65, "punish": 0.90, "cooldown": 0.90,
				"weight": 4.0, "phase_2_weight": 5.0,
				"min_range": 0.0, "max_range": 5.5,
			},
			{
				"id": &"call_the_iron", "name": "Call the Iron",
				"tell": {
					"time": 1.45, "pose": POSE_SPREAD,
					"color": Pal.ARCANE, "energy": 0.70,
					"sfx": &"order_horn",
					"read": "It plants the sword point-down and opens both "
						+ "gauntlets away from the hilt — the one beat where it "
						+ "is not holding its weapon. A horn note carries, and "
						+ "two violet shapes are already pacing in from the wall "
						+ "while its hands are still empty.",
				},
				# `wraith` is the hardest kind `Enemy.DEFS` actually defines
				# (20 HP, 5 damage). Two of them, capped at two, on an 8 s clock:
				# the adds are a complication the player clears, never a tide.
				"shape": SHAPE_SUMMON, "kind": &"wraith", "count": 2,
				"cap": 2, "radius": 9.0,
				"damage": 0, "knockback": 0.0, "stun": 0.0,
				"sfx": &"cast_divinity",
				"recover": 1.40, "punish": 2.10, "cooldown": 8.00,
				"weight": 1.0, "phase_2_weight": 2.5,
				"min_range": 0.0, "max_range": 16.0,
			},
		],
	},
}


# --- The minibosses -----------------------------------------------------------
## `docs/PUZZLES.md` §7. One per floor, **behind the treasure puzzle and
## therefore optional, always**. A player who never solves a treasure puzzle
## never meets one, and that is correct: this is the branch of the floor that
## pays extra for extra work.
##
## **Same row shape as `BOSSES`, deliberately**, so `Boss` and `BossArena`
## execute one of these with no code of their own -- `get_boss()` below reads
## both tables and neither node can tell the difference. A parallel `Miniboss`
## node would have been a second implementation of the beat loop, the tell, the
## five shapes and the punish promise, and `CLAUDE.md` §0 is a section about what
## this repo pays for two of something.
##
## What differs is three rules, and each one is checked by `validate()`:
##
## **1. TWO beats, not three.** A boss gets three (GDD §5); a miniboss gets two,
##    and one of them is answered by the floor's own verb:
##
##    > A miniboss's first beat is a wall that the floor's own verb opens.
##
##    So the treasure branch is where the game teaches *in combat* what the gate
##    room taught in a puzzle.
##
## **2. It drops no VERB and no RELIC.** GDD pillar 4 holds here exactly as it
##    does everywhere else: the chest behind it is the reward and the Echo on that
##    branch comes from the puzzle, not from the kill. The empty `relic` half of
##    the `drop` row is what makes `BossArena`'s relic replacement skip it.
##
##    **This rule read "it drops NOTHING" until 2026-08-11**, and it was that
##    strict for one reason, which is written into `validate()`: an item here
##    would put something the player NEEDS behind an optional puzzle, and floor 1
##    would stop being completable without solving one. That reason is about
##    verbs and keys — a bow, a hookshot, a Burst — and it does not reach a token
##    that only moves the METAGAME. The owner's call (card #91) is that the
##    Sluice-Keeper drops a Vyr maker's mark and the mark is what brings the smith
##    up the road; a player who never solves a treasure puzzle can still finish
##    every floor, they just run the whole descent without a forge, which is the
##    branch paying extra for extra work exactly as §7 intends.
##
##    So the rule is now a list: `PROGRESS_TOKENS` names what a miniboss may hand
##    over, `validate()` refuses anything else, and a relic is still refused
##    outright. **Do not put a kit item on this list.**
##
## **3. No floor's miniboss shares a model with its boss.** Floor 3's boss is a
##    `wraith`, so a `wraith` miniboss there would be two fights against one
##    silhouette in one descent, and a player who cannot tell at a glance which
##    they are looking at cannot tell which move set to expect. The bosses take
##    `golem`, `ogre`, `wraith` and `knight_iron`; the minibosses draw from what
##    is left. **New monster models stays 0.**
##
## ## Three places the fiction asked for something the vocabulary cannot deliver
##
## `docs/PUZZLES.md` §7's table is the design of record and the four rows below
## are it, worked. Three cells were corrected on the way down, each for the reason
## `docs/BOSSES.md` §6.1 and §6.3 correct two of `docs/BESTIARY.md` §5's: the
## sentence needs an attack shape, a prop or a mechanic that does not exist, and
## this file's own header says there is no sixth shape. Written down rather than
## absorbed, because a row that quietly does something other than the doc it cites
## is how the next session learns the doc is a lie.
##
## **1. The Bellows-Hand's plate is not a damage gate.** §7 says *"melee rings off
## it"*, which is `docs/BESTIARY.md` §3 behaviour 2 -- a front-facing damage gate
## on `Enemy`, uncommitted, and not a thing a row here can express. What IS
## expressible, and does the same job, is **`min_range`**: the advance only
## happens from 5 m out, which is where the bow lives and where the sword does
## not. The wall is the distance, not an invulnerable plate.
##
## **2. The Second Voice has no pillar.** §7 says it *"anchors to a resonating
## pillar and cannot be touched while the pillar sings"*. `CrackedPillar` is a
## PUZZLE ATOM, not an arena feature: standing one in a `BossArena` needs a new
## `arena` key and a prop placer, and the expensive half -- *cannot be touched* --
## is an invulnerability gate, a new mechanic against `docs/SCOPE.md` §4.3 and the
## same refusal `docs/BOSSES.md` §6.3 makes for the Bellwake one branch away.
## `docs/PUZZLES.md` §8.1's ceiling is explicit that nothing on this ledger may
## buy a tenth prop. So **the ring it sings IS the wall**, drawn on the floor as a
## `slam` band with a wide `safe_inner`, and the Burst is what answers it from
## outside the band.
##
## **3. The Gate-Hound backs away through the shared orbit.** Its smaller authored
## ring still yields when crowded, while beat two's `KNOCKBACK_HEAVY` opens the
## larger gap. Closing it quickly remains the hookshot's job.
## The only ids a miniboss's `drop.item` may name. See rule 2.
##
## **A token, and never a verb.** Everything on this list has to be a thing that
## changes the garrison and nothing else: no kit item, no door key, nothing
## `Game.wheel_bindable` will put on the ring, or floor 1 becomes uncompletable
## without an optional puzzle. There is one, and one is a reasonable ceiling.
##
## `static var` and not `const`: the value is another class's constant, which the
## parser will not take in a `const` initialiser (CLAUDE.md §3). Read off
## `StoryDb` rather than spelled again, because the id has to be identical in both
## files or the smith never arrives and nothing says why.
static var PROGRESS_TOKENS: Array[StringName] = [StoryDb.SMITH_TOKEN]

static var MINIBOSSES := {
	# =========================================================================
	&"sluice_keeper": {
		"floor": 1,
		"title": "THE SLUICE-KEEPER",
		"model": &"troll",
		# 2.60 m. A troll at about 1.2x, which puts it a head over the tallest
		# thing in the ordinary roster (the 1.95 m orc) and a clear THREE QUARTERS
		# of a metre under the Warden. That gap is the design: a miniboss must
		# read as "this one is bigger" and never as "this is the floor boss", and
		# height is the number the hitbox, the head marker and the silhouette all
		# share.
		"height": 2.60,
		# Wet bronze. The same drowned-metal family as the Warden -- they are the
		# same floor and the same water -- but the mix is lighter and the emission
		# is COBALT rather than MOSS, so the two are cousins in a still frame
		# instead of twins.
		"tint": {
			"albedo": Pal.COBALT, "albedo_mix": 0.28,
			"emission": Pal.COBALT, "energy": 0.20,
		},
		# Three 8 HP stagger segments: the shared grammar at optional-branch scale.
		"health": 24,
		"movement": {
			"phase_1": {"speed": 2.0, "orbit_radius": 3.7,
				"orbit_strength": 0.85, "reposition": 0.75},
			"phase_2": {"speed": 2.6, "orbit_radius": 3.2,
				"orbit_strength": 1.10, "reposition": 0.65},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_SWORD, "beat": &"flood_stomp", "open": OPEN_RECOVER,
			"goal": 3, "window": 2.5, "multiplier": 1.00, "color": Pal.VITAL,
		},
		"arena": {
			"radius": 7.5,
			# No cover. Beat two is a ring you roll out of and a pillar would
			# teach the player to solve it by standing behind something, which is
			# the same reason the Warden's arena is bare.
			"cover": false, "cover_count": 0,
		},
		# **A Vyr maker's mark, and it is the only thing any miniboss hands over**
		# (rule 2, `PROGRESS_TOKENS`). Not a verb, not a stat, not a relic: it is a
		# stamped disc of a metal nobody in Valenfeld can name, Aldric sends it up
		# the road, and the Guild sends back the man who can read it
		# (`StoryDb.UNLOCKS`, card #91).
		#
		# It hangs off THIS body rather than off floor 1's boss because of what the
		# smith is for. His counter is where a bent Vyr thing becomes a working one,
		# and the treasure branch is the part of the floor that is made of bent Vyr
		# things; a player who works for the optional room is the player who has
		# something to take to him.
		#
		# `relic` stays empty and must. See `_place_chamber` in `dungeon.gd`: the
		# arena is built with `relic_slot = &""` so `BossArena._replace_lost_relic`
		# cannot put floor 1's BOSS relic on the floor of this room.
		"drop": {"item": &"makers_mark", "relic": &""},
		"music": "",
		"beats": [
			{
				# THE WALL, and floor 1's verb is T0 -- sword, shield, body, key
				# (`docs/PUZZLES.md` §1). So the wall is answered by the SHIELD,
				# which is also the atom the gate room taught with (the sun
				# socket is the one T0 atom that asks the player to aim a guard).
				#
				# A blocked blow never changes health, so `Heat` never sees a
				# step-down and the shield is how a chain survives this fight
				# (`docs/METAGAME.md` §4.5). That is the lesson, and it is taught
				# by a beat that is generous about it: 1.15 s of tell is the
				# longest overhead in the game.
				"id": &"wheel_swing", "name": "Wheel-Swing",
				"tell": {
					"time": 1.15, "pose": POSE_REAR,
					"color": Pal.COBALT, "energy": 0.60,
					"sfx": &"craft_grind",
					"read": "It hauls both hands over its head as though it were "
						+ "still turning the wheel, and holds them there a full "
						+ "beat while the water runs off its forearms in two "
						+ "sheets. Blue light gathers in the knuckles. It is the "
						+ "slowest thing in the room and it is aimed straight "
						+ "down the line you are standing on.",
				},
				# Narrow, so the blow is a LINE rather than a sweep: a 42-degree
				# arc is something a player can also side-step, and a wall whose
				# only answer is the shield would be a check rather than a beat.
				"shape": SHAPE_ARC, "reach": 4.0, "arc_deg": 42.0,
				"damage": 3, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.28,
				"sfx": &"weapon_impact_blunt",
				"recover": 0.85, "punish": 1.35, "cooldown": 1.35,
				"weight": 3.0, "phase_2_weight": 2.0,
				"min_range": 0.0, "max_range": 5.5,
			},
			{
				# THE THREAT. Rolled, never blocked -- the shield answers beat one
				# and pointedly does not answer this one, which is what stops the
				# fight from being "hold block".
				"id": &"flood_stomp", "name": "Flood-Stomp",
				"tell": {
					"time": 0.95, "pose": POSE_CROUCH,
					"color": Pal.MOSS, "energy": 0.70,
					"sfx": &"jump_slam",
					"read": "It plants both feet and sinks, and the standing "
						+ "water pulls BACK off them in a widening green rim. "
						+ "The rim is the attack, drawn on the floor a second "
						+ "before it is thrown, and there is no middle to it.",
				},
				# A solid disc: `safe_inner` 0.0, so there is no walk-toward-it
				# answer. That is the deliberate mirror of the Warden's donut --
				# the two slams on this floor must not be one attack in two hues,
				# and the miniboss is where the player learns that a ring can go
				# either way.
				"shape": SHAPE_SLAM, "radius": 5.0, "safe_inner": 0.0,
				"leap": {"time": 0.70, "height": 1.3},
				"damage": 3, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.22,
				"sfx": &"spell_impact_frost",
				"recover": 0.60, "punish": 1.15, "cooldown": 1.40,
				"weight": 2.0, "phase_2_weight": 4.2,
				"min_range": 0.0, "max_range": 7.0,
			},
		],
	},

	# =========================================================================
	&"bellows_hand": {
		"floor": 2,
		"title": "THE BELLOWS-HAND",
		"model": &"orc",
		# 2.55 m. `docs/PUZZLES.md` §7 writes this as "orc, x1.3", and the orc is
		# 1.95 m in `Enemy.DEFS`, so x1.3 is 2.535 and this is that rounded to the
		# centimetre. **The metres are the contract and the multiplier is the
		# sketch** -- there is deliberately no `scale` key in this table (executor
		# contract §1b), and the rule the number has to satisfy is that a miniboss
		# reads as *bigger than anything in the roster* (the orc's own 1.95 m is the
		# tallest) and *clearly not the floor boss* (the Slag Ogre is 3.80, so the
		# gap is a metre and a quarter).
		"height": 2.55,
		# Iron plate over cooling slag, and deliberately NOT the Slag Ogre's scheme:
		# the Ogre is a rust body with molten VITAL in the cracks, so a second
		# rust-and-red thing on the same floor would be the Sluice-Keeper's
		# cousins-not-twins problem all over again. This one is grey plate carrying
		# rust in its seams.
		"tint": {
			"albedo": Pal.ASH, "albedo_mix": 0.36,
			"emission": Pal.RUST, "energy": 0.24,
		},
		# Three 12 HP stagger segments, below the Slag Ogre in both health and motion.
		"health": 36,
		"movement": {
			"phase_1": {"speed": 2.2, "orbit_radius": 4.2,
				"orbit_strength": 0.90, "reposition": 0.75},
			"phase_2": {"speed": 2.9, "orbit_radius": 3.6,
				"orbit_strength": 1.20, "reposition": 0.60},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_ARROW, "beat": &"plate_advance", "open": OPEN_CHARGE,
			"goal": 3, "window": 2.9, "multiplier": 1.50, "color": Pal.COBALT,
		},
		"arena": {
			"radius": 8.0,
			# Two slag posts are defensive cover, not a damage answer:
			# `Boss._advance_charge` ends the commit on `is_on_wall()`. That stops
			# the hit but also closes the arrow aperture, so the player chooses safe
			# cover or the riskier shot during travel.
			"cover": true, "cover_count": 2,
		},
		# Nothing. Rule 2 above -- the empty row is load-bearing, not a gap.
		"drop": {"item": &"", "relic": &""},
		"music": "",
		"beats": [
			{
				# THE WALL, and floor 2's verb is T1 -- the BOW (`docs/PUZZLES.md`
				# §1), which is what the Warden dropped and what the Foundry's gate
				# room teaches on an eye switch.
				#
				# **`min_range` 5.0 is the wall.** This is the only beat the fight has
				# past five metres, so a hero at bow range is a hero being walked at
				# behind a plate with nothing but the bow in reach -- the same trick
				# `bellows_charge` uses to be "the only beat that happens where the bow
				# lives" (`docs/BOSSES.md` §6.2), one branch earlier and half the size.
				#
				# **The slower answer is survival, not health damage**
				# (`docs/BESTIARY.md` §4.2). Sidestep or put a slag post in the lane;
				# either avoids the blow and buys a moving reset. The arrow during
				# travel is still the only action that converts the beat into stagger.
				#
				# **The fast way over is BUILT** (§5b above, `Boss.apply_hit`),
				# and this beat carries it because it is a charge: an arrow into the
				# TRAVEL stops the plate where it finds it. This comment used to be a
				# `# NEEDS:` asking for the branch during `State.WINDUP`, which is the
				# window `docs/BOSSES.md` §6.2 examines and rejects -- a tell-cut for the
				# bow is the thing `Boss.freeze` refuses the hookshot. The shipped rule
				# is scoped to the commit.
				"id": &"plate_advance", "name": "Plate-Advance",
				"tell": {
					"time": 1.00, "pose": POSE_CROUCH,
					"color": Pal.RUST, "energy": 0.75,
					"sfx": &"ogre_alert",
					"read": "It drops in behind the plate until the plate is most of "
						+ "what there is of it -- the one beat where it is shorter than "
						+ "the hero -- and the slag in the seams down its arm goes from "
						+ "ember to orange. A narrow lane burns onto the flagstones in "
						+ "front of it, and the lane is where it is going.",
				},
				# Slow, and that is the difference between an advance and a charge. The
				# Slag Ogre crosses eleven metres at 13 m/s; this crosses eight at 8, so
				# the commit is a full second of a plate coming at you rather than a hit
				# you either read or did not. A wall you can walk out of is a wall; a
				# wall you cannot is a check.
				"shape": SHAPE_CHARGE, "reach": 8.0, "radius": 1.4,
				"speed": 8.0,
				"damage": 3, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.30,
				"sfx": &"weapon_impact_blunt_2h_heavy",
				"recover": 1.10, "punish": 1.45, "cooldown": 1.45,
				"weight": 3.0, "phase_2_weight": 4.3,
				"min_range": 5.0, "max_range": 16.0,
			},
			{
				# THE THREAT, and it is a `zone` rather than the cone §7's prose asks
				# for. `docs/BESTIARY.md` §4.3 wants one beat the shield answers and one
				# it does not, and `docs/BOSSES.md` §3 says which is which: *arc, slam
				# and charge are the shield's beats; zone is the roll's*. An `arc` here
				# would have been a second shield beat, and a fight both of whose beats
				# answer the same way is one beat played twice.
				#
				# So the cough is read as WHERE THE EMBERS LAND rather than as the
				# breath that threw them: three fires start, the first under the hero,
				# and they burn up over their own fuse. Same fiction, and the only
				# version of it the five shapes can deliver.
				"id": &"ember_cough", "name": "Ember-Cough",
				"tell": {
					"time": 1.05, "pose": POSE_SPREAD,
					"color": Pal.VITAL, "energy": 0.62,
					"sfx": &"spell_charge_fire",
					"read": "The bellows on its back fill, and it opens both arms away "
						+ "from the plate to let them -- the one beat where the plate is "
						+ "not between you and it, and the widest the body ever gets. The "
						+ "whole thing lights red from the spine outward, and nothing is "
						+ "drawn on the floor at all until it coughs.",
				},
				"shape": SHAPE_ZONE, "radius": 2.2, "fuse": 1.20, "count": 3,
				"throw": {"flight": 0.65, "height": 1.7},
				"damage": 3, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.20,
				"sfx": &"spell_impact_fire",
				# 1.30 s is two contacts and misses the finisher line (1.37 s,
				# `docs/BOSSES.md` §2) on purpose: the cheap beat buys the cheap
				# opening, and the wall's 1.45 s is where the third swing lands.
				"recover": 0.75, "punish": 1.30, "cooldown": 1.55,
				"weight": 2.0, "phase_2_weight": 2.0,
				"min_range": 0.0, "max_range": 16.0,
			},
		],
	},

	# =========================================================================
	&"second_voice": {
		"floor": 3,
		"title": "THE SECOND VOICE",
		"model": &"skeleton",
		# 2.55 m. §7's "skeleton, x1.5" against `Enemy.DEFS`' 1.70 m skeleton is
		# 2.55 exactly. Half a metre over the roster's tallest and a metre and a
		# half under the Bellwake's 4.20 -- and the Bellwake does not touch the
		# floor, which is most of what tells the two apart before either moves.
		"height": 2.55,
		# Pale. The Choir's own body is MIDNIGHT under ARCANE; this is the opposite
		# reading of the same room -- bleached bone lit cold -- so the two floor-3
		# silhouettes are a white one and a violet one and never two shades of the
		# same dark.
		#
		# The mix is high and the energy is LOW, and both numbers were moved after
		# looking at the frame rather than authored from the palette. At the
		# table's usual 0.34/0.26 the emission simply wins: `Boss._style_model`
		# lerps the albedo but ASSIGNS the emission outright, so a quarter of a
		# unit of COBALT over a dark cave floods the whole mesh and the body came
		# out the same saturated blue as the floor-1 Sluice-Keeper -- two floors
		# apart, so never side by side, but "a white one" was a claim the render
		# flatly contradicted. 0.55 of BONE is what makes it bleached; 0.16 of
		# COBALT is a cast over it rather than a colour of its own.
		#
		# It also has to stay dark enough for `sounding_ring` to read: the tell
		# glows BONE at 0.72, and a body already lit bone-white would telegraph
		# its biggest beat by getting very slightly brighter.
		"tint": {
			"albedo": Pal.BONE, "albedo_mix": 0.55,
			"emission": Pal.COBALT, "energy": 0.16,
		},
		# Three 16 HP stagger segments. The two Keening bombs renew the floor-3
		# answer even when the player's Burst has no charge left.
		"health": 48,
		"movement": {
			"phase_1": {"speed": 2.4, "orbit_radius": 4.6,
				"orbit_strength": 0.90, "reposition": 0.70},
			"phase_2": {"speed": 3.1, "orbit_radius": 3.9,
				"orbit_strength": 1.20, "reposition": 0.55},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_BOMB, "beat": &"keening", "open": OPEN_ZONES,
			"goal": 3, "window": 2.8, "multiplier": 2.00, "color": Pal.VITAL,
		},
		"arena": {
			"radius": 9.0,
			# No cover, and for a sharper reason than the Bellwake's. Beat one is a
			# BAND with safe floor on both sides of it, so the fight is already about
			# where you stand; a post would add a third safe place that the `slam` --
			# a pure distance query -- would reach straight through anyway.
			# `docs/BOSSES.md` §6.3's second reason, one branch over: a mark that
			# teaches a false rule is worse than no mark.
			"cover": false, "cover_count": 0,
		},
		"drop": {"item": &"", "relic": &""},
		"music": "",
		"beats": [
			{
				# THE WALL, and floor 3's verb is T2 -- the BURST
				# (`docs/PUZZLES.md` §1), taken off the Slag Ogre.
				#
				# **The ring is the wall.** A band from 3.0 m to 7.5 m in a 9.0 m room:
				# there is safe floor under its feet and a metre and a half of safe rim
				# at the wall, and everything a sword can reach from is in between. The
				# question the beat asks is *which side of the note are you on*, and the
				# fast answer is the one that needs to be on neither -- **the Burst
				# reaches across the band from the rim**, and at floor 3 it is the only
				# thing in the kit that does area damage at range.
				#
				# **The second way over** (`docs/BESTIARY.md` §4.2): walk THROUGH the
				# band and be inside 3.0 m before the tell ends. That is the Warden's
				# donut, which floor 1 already taught -- and it costs more here, because
				# `keening` reaches 7.0 m straight in front and the inside of the ring
				# is not a rest position. Slower still, and always available: the bow
				# from the rim, one arrow at a time.
				#
				# Read `Boss._shape_slam` before touching `safe_inner`: it hurts
				# BETWEEN inner and outer, so beyond `radius` is safe, and that outer
				# rim is half the design.
				"id": &"sounding_ring", "name": "The Sounding Ring",
				"tell": {
					"time": 1.15, "pose": POSE_SPREAD,
					"color": Pal.BONE, "energy": 0.72,
					"sfx": &"glint_bell",
					"read": "It opens its arms to their full span and goes completely "
						+ "still, and the note it has been holding becomes visible: a "
						+ "white band scratched onto the floor with a hole in the middle "
						+ "of it and clear stone outside. The band is drawn before it is "
						+ "thrown and it does not move. The standing wave has a node at "
						+ "its own feet.",
				},
				"shape": SHAPE_SLAM, "radius": 7.5, "safe_inner": 3.0,
				"leap": {"time": 0.85, "height": 1.7},
				"damage": 4, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.32,
				"sfx": &"spell_impact_dark",
				"recover": 1.00, "punish": 1.40, "cooldown": 1.65,
				"weight": 3.0, "phase_2_weight": 2.0,
				"min_range": 0.0, "max_range": 16.0,
			},
			{
				# THE THREAT, and §7's line about it is a fact about the game rather
				# than a feature to build: *it lands as a blow, so it breaks Heat.*
				# Every blow does (`docs/METAGAME.md` §4.5), which is the point -- the
				# chain is what makes this optional branch cost something even when it
				# is won, and nothing in this row has to arrange it.
				#
				# Two thrown notes make this the roll beat and provide the renewable
				# bomb fallback. The 8.0 m gate preserves its original range pressure.
				"id": &"keening", "name": "The Keening",
				"tell": {
					"time": 0.95, "pose": POSE_RISE,
					"color": Pal.COBALT, "energy": 0.66,
					"sfx": &"cast_conjuration",
					"read": "It draws itself up a head taller than it stands, and the "
					+ "jaw comes open and stays open. Cold blue runs up the ribs to "
					+ "the throat, then two bright charges lift from its hands. Their "
					+ "landing circles are already burning on the floor.",
				},
				"shape": SHAPE_ZONE, "radius": 2.4, "fuse": 1.05, "count": 2,
				"throw": {"flight": 0.70, "height": 1.8},
				"damage": 4, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.26,
				"sfx": &"spell_impact",
				"recover": 0.70, "punish": 1.20, "cooldown": 1.20,
				"weight": 3.0, "phase_2_weight": 4.4,
				"min_range": 0.0, "max_range": 8.0,
			},
		],
	},

	# =========================================================================
	&"gate_hound": {
		"floor": 4,
		"title": "THE GATE-HOUND",
		"model": &"kobold",
		# 2.30 m, and this is the one height of the four that is NOT §7's
		# multiplier. "kobold, x1.4" against `Enemy.DEFS`' 1.35 m kobold is
		# **1.89 m** -- shorter than an ordinary orc, which fails the one rule the
		# placeholder column exists to serve: a miniboss has to read as *bigger than
		# the roster* from the doorway. The metres are the contract (there is no
		# `scale` key here, executor contract §1b) and the multiplier was a sketch,
		# so the sketch loses. 2.30 m is a kobold at about x1.7: a clear head over
		# the orc, a full 1.30 m under the Riven Knight, and still the SHORTEST of
		# the four minibosses -- which mirrors the Riven Knight being the shortest of
		# the four bosses, and costs nothing.
		"height": 2.30,
		# Iron-dark, with the Chord Gate's own violet in the seams. The Riven Knight
		# is VOID under VITAL -- one red seam on black -- so this is the same black
		# wearing the other hue, and the two are told apart by COLOUR rather than by
		# asking a player to judge 2.30 m against 3.60 m through a doorway.
		"tint": {
			"albedo": Pal.VOID, "albedo_mix": 0.40,
			"emission": Pal.ARCANE, "energy": 0.22,
		},
		# Three stagger segments with `ceil(64 / 3) == 22` HP capacity. The final
		# segment is 20 HP, so it still cannot die before the third full opening.
		"health": 64,
		"movement": {
			"phase_1": {"speed": 2.7, "orbit_radius": 4.0,
				"orbit_strength": 1.00, "reposition": 0.65},
			"phase_2": {"speed": 3.6, "orbit_radius": 3.4,
				"orbit_strength": 1.40, "reposition": 0.50},
		},
		"phase": {"at": 0.50},
		"stagger": {
			"kind": STAGGER_HOOKSHOT, "beat": &"overhand", "open": OPEN_ZONES,
			"goal": 3, "window": 3.0, "multiplier": 2.75, "color": Pal.MOSS,
		},
		"arena": {
			"radius": 8.5,
			# **No cover, and the asymmetry with the Bellows-Hand is principled.** A
			# post breaks a `charge`, because `_advance_charge` ends the commit on
			# `is_on_wall()` -- live code. It does NOT break an `arc`, which is a
			# distance-and-angle query resolved once at the commit and blind to
			# geometry, so a pylon here would draw a shadow the shard goes straight
			# through. That is board card 21's failure mode wearing a prop instead of
			# a mark, and `docs/BOSSES.md` §6.3 refuses it for the same reason.
			"cover": false, "cover_count": 0,
		},
		"drop": {"item": &"", "relic": &""},
		"music": "",
		"beats": [
			{
				# THE WALL, and floor 4's verb is T3 -- the HOOKSHOT
				# (`docs/PUZZLES.md` §1), taken off the Bellwake.
				#
				# **`min_range` 5.0 IS the lock and the hookshot IS the key.** The beat
				# cannot be picked from inside five metres -- `pick_beat`'s range gate
				# refuses it and only the overhand is left -- so closing the gap does
				# not merely make the lob easier to survive, it DELETES it. Nothing in
				# the kit closes five metres in one press except the hookshot.
				#
				# §7's *"or freezes it where it stands"* is the other half and it is
				# deliberately NOT built: `Boss.freeze` refuses the chain on poise
				# grounds and that argument is good -- a hookshot that could cut a tell
				# short is a beat the player can delete, and one that could cut a punish
				# short takes the window away from them. **The pull is the answer; the
				# freeze is not, and should not be made one here.**
				#
				# **The second way over** (`docs/BESTIARY.md` §4.2): run it down on
				# foot, eating shards on the way in -- or block them. An `arc` is a
				# shield beat (`docs/BOSSES.md` §3) and `docs/BESTIARY.md` §2 gives the
				# shield *send a thrown thing back* as its combat verb, so the guard is
				# a real answer here. It just spends the whole walk behind it.
				#
				# 22 degrees: the narrowest cone in the game, and a near-line rather
				# than a sweep. What is thrown is one piece of the Gate and it goes
				# exactly where the fan is drawn -- which since board card 21 is a
				# 44-degree wedge on the floor and no longer a 6.7 m box round it.
				"id": &"gate_shard", "name": "Gate-Shard",
				"tell": {
					"time": 0.85, "pose": POSE_TILT,
					"color": Pal.VITAL, "energy": 0.68,
					"sfx": &"glint_hiss",
					"read": "It cants hard onto one shoulder and cocks the arm back "
						+ "across its body, and the shard in that hand goes from "
						+ "gate-violet to hot red -- the one red thing on a black body. A "
						+ "narrow wedge opens from its feet toward yours and stops "
						+ "there. It is nearly a line, and the line is aimed.",
				},
				"shape": SHAPE_ARC, "reach": 9.0, "arc_deg": 22.0,
				"damage": 4, "knockback": K.KNOCKBACK_LIGHT, "stun": 0.22,
				"sfx": &"weapon_impact_stab_1",
				"recover": 0.60, "punish": 1.15, "cooldown": 1.40,
				"weight": 3.0, "phase_2_weight": 2.0,
				"min_range": 5.0, "max_range": 16.0,
			},
			{
				# THE THREAT, and §7 is emphatic: *rolled, not blocked -- the one beat
				# in the set the shield does not answer.* `docs/BOSSES.md` §3 says which
				# shape that is and there is exactly one: a `zone`, whose first disc is
				# drawn under the hero, so a standing hero is caught by a blow whose
				# direction is zero and `blocks()` and `parries()` both return false.
				# **A `slam` would have been blockable and the doc's line would have
				# been wrong**; this is the overhand's landing spot marked on the stone
				# on a short fuse, which is the same picture and the only unblockable
				# one.
				#
				# `KNOCKBACK_HEAVY` is not flavour here, it is the fight's engine. Six
				# HP and a heavy shove put the hero back outside beat one's 5.0 m
				# gate, where the lob is the only thing left, and closing again is the
				# hookshot's job. That loop is what "it backs across a gap" comes out as
				# when nothing in the executor retreats.
				"id": &"overhand", "name": "The Overhand",
				"tell": {
					"time": 0.80, "pose": POSE_REAR,
					"color": Pal.BONE, "energy": 0.70,
					"sfx": &"attack_prepare_1",
					"read": "Both arms go over and behind the head and the whole body "
						+ "comes up with them, pale white, for four fifths of a second. "
					+ "Its pale landing disc appears under whoever it aimed at, then the "
					+ "thrown mass crosses the gap before the fuse begins.",
				},
				"shape": SHAPE_ZONE, "radius": 3.0, "fuse": 0.95, "count": 1,
				"throw": {"flight": 0.75, "height": 2.1},
				"damage": 6, "knockback": K.KNOCKBACK_HEAVY, "stun": 0.34,
				"sfx": &"jump_slam",
				# 1.40 s clears the 1.37 s finisher line (`docs/BOSSES.md` §2) and it is
				# the only window in this fight that does. The Chord Gate's dog gives
				# the third swing away exactly once a cycle, and takes 6 HP for
				# it.
				"recover": 0.85, "punish": 1.40, "cooldown": 1.40,
				"weight": 4.0, "phase_2_weight": 4.6,
				"min_range": 0.0, "max_range": 6.0,
			},
		],
	},
}

## The floor-item grammar, written once for validation. These are the only
## interactions that may open health damage; parry remains a poise interruption.
static var STAGGER_EXPECTED := {
	&"cistern_warden": {"kind": STAGGER_SWORD, "beat": &"cistern_drop",
		"open": OPEN_RECOVER, "goal": 4},
	&"slag_ogre": {"kind": STAGGER_ARROW, "beat": &"bellows_charge",
		"open": OPEN_CHARGE, "goal": 4},
	&"bellwake": {"kind": STAGGER_BOMB, "beat": &"undertow",
		"open": OPEN_ZONES, "goal": 4},
	&"riven_knight": {"kind": STAGGER_HOOKSHOT, "beat": &"call_the_iron",
		"open": OPEN_RECOVER, "goal": 4},
	&"sluice_keeper": {"kind": STAGGER_SWORD, "beat": &"flood_stomp",
		"open": OPEN_RECOVER, "goal": 3},
	&"bellows_hand": {"kind": STAGGER_ARROW, "beat": &"plate_advance",
		"open": OPEN_CHARGE, "goal": 3},
	&"second_voice": {"kind": STAGGER_BOMB, "beat": &"keening",
		"open": OPEN_ZONES, "goal": 3},
	&"gate_hound": {"kind": STAGGER_HOOKSHOT, "beat": &"overhand",
		"open": OPEN_ZONES, "goal": 3},
}

static var STAGGER_COLORS: Array[Color] = [
	Pal.VITAL, Pal.RUST, Pal.BONE, Pal.MOSS, Pal.COBALT, Pal.ARCANE,
]

static var LEAP_BEATS: Array[StringName] = [
	&"cistern_drop", &"first_toll", &"flood_stomp", &"sounding_ring",
]


# --- Reading the table --------------------------------------------------------

## Every boss id, in floor order. The array is rebuilt from the table rather than
## written out beside it, because a hand-kept parallel list is a list that is one
## day missing a boss nobody notices for a month.
static func all() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k in BOSSES.keys():
		ids.append(k as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(BOSSES[a]["floor"]) < int(BOSSES[b]["floor"]))
	return ids


## Every miniboss id, in floor order. The same shape as `all()` and for the same
## reason -- a hand-kept parallel list is the one that is one day missing a row.
static func all_minibosses() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k in MINIBOSSES.keys():
		ids.append(k as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(MINIBOSSES[a]["floor"]) < int(MINIBOSSES[b]["floor"]))
	return ids


static func is_miniboss(id: StringName) -> bool:
	return MINIBOSSES.has(id)


## `id`'s one escalation, or an empty Dictionary when it has none.
##
## **The minibosses have no room turn, and the empty row is the answer rather
## than a gap.** Their actor still enters phase two through `Boss`'s health
## fallback, but an optional chamber never rebuilds its room halfway through.
static func turn(id: StringName) -> Dictionary:
	var row := get_boss(id)
	if row.is_empty():
		return {}
	# ANNOTATED: indexing an untyped Dictionary hands back Variant, and `:=` on
	# one is the "Cannot infer the type of X" parse error in CLAUDE.md §3.
	var arena: Dictionary = row.get("arena", {})
	var t: Dictionary = arena.get("turn", {})
	return t


## One row, or an empty Dictionary. Empty rather than a fallback boss: a floor
## that asks for a boss that does not exist has a broken manifest, and quietly
## handing it the Warden would ship that bug into the Chord Gate.
##
## **Both tables, one accessor.** `Boss` and `BossArena` read a row and execute
## it; neither has any business knowing which table it came from, and giving them
## a second lookup would be the point at which a miniboss started needing its own
## code path. The ids cannot collide -- `validate()` checks that too.
static func get_boss(id: StringName) -> Dictionary:
	return BOSSES.get(id, MINIBOSSES.get(id, {}))


## Which miniboss stands behind floor `level`'s treasure puzzle, or `&""`. The
## mirror of `for_floor`, and the dungeon asks this rather than carrying its own
## floor->miniboss table.
static func miniboss_for(level: int) -> StringName:
	for id in all_minibosses():
		if int(MINIBOSSES[id]["floor"]) == level:
			return id
	return &""


## Which boss guards floor `level`, or `&""`. The dungeon asks this rather than
## carrying its own floor->boss table, so the pairing in GDD §5 has one home.
static func for_floor(level: int) -> StringName:
	for id in all():
		if int(BOSSES[id]["floor"]) == level:
			return id
	return &""


## `id`'s three beats, in authored order. The order is for the director's log
## and for reading the file — `pick_beat` is what the fight uses, and it does
## not walk this in sequence.
static func beats(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var row := get_boss(id)
	if row.is_empty():
		return out
	# Annotated: indexing an untyped Dictionary hands back Variant, which is the
	# inference trap in CLAUDE.md §3.
	var list: Array = row["beats"]
	for b in list:
		out.append(b as Dictionary)
	return out


## One beat by id, or an empty Dictionary.
static func beat(id: StringName, beat_id: StringName) -> Dictionary:
	for b in beats(id):
		if b["id"] == beat_id:
			return b
	return {}


# --- Choosing the next beat ---------------------------------------------------

## What the beat it just threw is worth on the next roll, as a multiplier on its
## weight. **Not zero, and the difference is the whole fight.**
##
## This started as a hard "never the same beat twice running", which is the rule
## everybody writes, and printing the distribution killed it in one line. A boss
## has three beats and the range gate usually makes two of them eligible; strike
## the previous one from a set of two and exactly one candidate remains, so the
## "weighted" choice is deterministic and the fight is a forced A-B-A-B loop —
## precisely the memorised sequence the weights exist to prevent. The Slag Ogre
## in the hero's face alternated backhand, ladle, backhand, ladle for three
## thousand consecutive rolls, and its 4:2 weighting never once applied.
##
## A soft penalty fixes both halves. With three eligible the repeat is rare but
## possible, so "it just slammed, therefore it cannot slam" stops being free
## information the player can act on. With two eligible the weights survive and
## the choice stays a coin the player cannot call. 0.22 is tuned so a doubled
## beat is uncommon enough to read as pressure rather than as the boss being
## stuck. [tune]
const REPEAT_WEIGHT := 0.22

## Pick `id`'s next beat, as data. **This is the only implementation of the
## choice rule; the Boss node must call it rather than re-deriving it.**
##
## Two rules, and each one exists because the fight is worse without it:
##
##  1. **Range gate.** A beat is eligible only when `distance` (flat metres,
##     boss to hero) falls in `[min_range, max_range]`. This is what makes the
##     charge a thing that happens across the arena and the backhand a thing
##     that happens in your face, without a single `if` in the executor. A boss
##     that slams at fourteen metres is a boss whose attacks are noise.
##  2. **Weights, softened against a repeat** (see `REPEAT_WEIGHT`). Never a
##     sequence: a memorised loop is a knowledge check, not a fight
##     (`docs/SCOPE.md` §6, GDD pillar 3).
##
## The range gate is RELAXED rather than allowed to return nothing — a boss that
## stands still because no beat qualified is a boss you outlast. `&""` comes back
## only for an id with no beats at all.
##
## **A summon this returns may still be refused.** `pick_beat` cannot see how
## many of a beat's summons are alive, and it should not: that is world state,
## not design. When `cap` is already met, the executor throws the pick away and
## calls again with `last_id` set to the refused beat's id — `REPEAT_WEIGHT` then
## makes the second roll something else with near-certainty. That is why the two
## summon beats are rare in play without needing a tiny weight: `cap` is the
## structural limit and the weight is only the flavour of it.
static func pick_beat(id: StringName, rng: RandomNumberGenerator,
		last_id: StringName = &"", distance: float = 0.0, phase: int = 1) -> StringName:
	var list := beats(id)
	if list.is_empty():
		return &""

	var pool: Array[Dictionary] = []
	for b in list:
		if distance >= float(b["min_range"]) and distance <= float(b["max_range"]):
			pool.append(b)
	# Out of position, or a table someone has narrowed: pick from everything and
	# let the executor walk. Silence is not an option a boss gets.
	if pool.is_empty():
		pool = list

	# Built once and reused for the roll, so the penalty cannot be applied in the
	# total and forgotten in the walk — which is the classic way a weighted pick
	# ends up biased toward whatever is last in the array.
	var weights: Array[float] = []
	var total := 0.0
	for b in pool:
		var weight_key := "phase_2_weight" if phase >= 2 else "weight"
		var w := maxf(float(b.get(weight_key, b["weight"])), 0.0)
		if b["id"] == last_id:
			w *= REPEAT_WEIGHT
		weights.append(w)
		total += w
	if total <= 0.0:
		return pool[0]["id"]

	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]["id"]
	# Float error only. The last entry is the honest answer, not an error case.
	return pool[pool.size() - 1]["id"]


# --- Proving the table --------------------------------------------------------

static func _is_numeric(value: Variant) -> bool:
	var kind := typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT


static func _dynamic_row_errors(id: StringName, row: Dictionary,
		miniboss: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var movement: Dictionary = row.get("movement", {})
	if movement.is_empty():
		out.append("%s: missing movement configuration" % id)
	else:
		for phase_key: String in ["phase_1", "phase_2"]:
			var values: Dictionary = movement.get(phase_key, {})
			if values.is_empty():
				out.append("%s: movement.%s is missing" % [id, phase_key])
				continue
			for field: String in ["speed", "orbit_radius", "orbit_strength", "reposition"]:
				var value: Variant = values.get(field)
				if not _is_numeric(value) or float(value) <= 0.0:
					out.append("%s: movement.%s.%s must be a positive number"
						% [id, phase_key, field])
		var p1: Dictionary = movement.get("phase_1", {})
		var p2: Dictionary = movement.get("phase_2", {})
		if not p1.is_empty() and not p2.is_empty():
			if float(p2.get("speed", 0.0)) <= float(p1.get("speed", 0.0)):
				out.append("%s: phase 2 movement speed must exceed phase 1" % id)
			if float(p2.get("orbit_strength", 0.0)) <= \
					float(p1.get("orbit_strength", 0.0)):
				out.append("%s: phase 2 orbit pressure must exceed phase 1" % id)
			if float(p2.get("orbit_radius", 0.0)) >= float(p1.get("orbit_radius", 0.0)):
				out.append("%s: phase 2 orbit radius must press inside phase 1" % id)

	var phase: Dictionary = row.get("phase", {})
	if phase.is_empty() or not _is_numeric(phase.get("at")) \
			or not is_equal_approx(float(phase.get("at", -1.0)), 0.50):
		out.append("%s: phase.at must be 0.50" % id)

	var authored: Dictionary = row.get("stagger", {})
	var expected: Dictionary = STAGGER_EXPECTED.get(id, {})
	if authored.is_empty():
		out.append("%s: missing stagger configuration" % id)
		return out
	var kind: StringName = authored.get("kind", &"")
	var beat_id: StringName = authored.get("beat", &"")
	var exposure: StringName = authored.get("open", &"")
	var goal := int(authored.get("goal", 0))
	if not STAGGER_KINDS.has(kind):
		out.append("%s: stagger kind %s is not in the vocabulary" % [id, kind])
	if not EXPOSURES.has(exposure):
		out.append("%s: stagger exposure %s is invalid" % [id, exposure])
	if not expected.is_empty() and (kind != expected["kind"] \
			or beat_id != expected["beat"] or exposure != expected["open"]):
		out.append("%s: stagger interaction does not match its floor item mapping" % id)
	var expected_goal := 3 if miniboss else 4
	if goal != expected_goal or (not expected.is_empty() and goal != int(expected["goal"])):
		out.append("%s: stagger goal must be %d" % [id, expected_goal])
	var window: Variant = authored.get("window")
	# The bare chain is 2.142 s before input/swap slack. An authored aperture
	# shorter than that makes the promised one-chain segment impossible in play.
	var window_min := 2.5 if miniboss else 2.8
	var window_max := 3.0 if miniboss else 3.4
	if not _is_numeric(window) or float(window) < window_min or float(window) > window_max:
		out.append("%s: stagger window must be in [%.1f, %.1f]"
			% [id, window_min, window_max])
	var segment_capacity := ceilf(float(int(row.get("health", 0))) \
		/ float(maxi(goal, 1)))
	var expected_multiplier := segment_capacity / STAGGER_BASE_CHAIN_DAMAGE
	if not _is_numeric(authored.get("multiplier")) or not is_equal_approx(
			float(authored.get("multiplier", 0.0)), expected_multiplier):
		out.append("%s: stagger multiplier must make the bare sword chain spend "
			% id + "one segment (expected %.2f)" % expected_multiplier)
	var color: Variant = authored.get("color")
	if typeof(color) != TYPE_COLOR or not STAGGER_COLORS.has(color):
		out.append("%s: stagger color must be a readable Pal color" % id)
	var weak_beat := beat(id, beat_id)
	if weak_beat.is_empty():
		out.append("%s: stagger beat %s does not exist" % [id, beat_id])
	else:
		var shape: StringName = weak_beat.get("shape", &"")
		if exposure == OPEN_CHARGE and shape != SHAPE_CHARGE:
			out.append("%s: charge exposure is not on a charge beat" % id)
		if exposure == OPEN_ZONES and shape != SHAPE_ZONE:
			out.append("%s: zones exposure is not on a zone beat" % id)
	return out


static func _beat_modifier_errors(id: StringName, b: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var bid: StringName = b.get("id", &"")
	var shape: StringName = b.get("shape", &"")
	var phase_weight: Variant = b.get("phase_2_weight")
	if not _is_numeric(phase_weight) or float(phase_weight) <= 0.0:
		out.append("%s/%s: phase_2_weight must be positive" % [id, bid])
	if b.has("leap"):
		var leap: Dictionary = b.get("leap", {})
		if shape != SHAPE_SLAM:
			out.append("%s/%s: leap is only legal on a slam" % [id, bid])
		if not _is_numeric(leap.get("time")) or float(leap.get("time", 0.0)) <= 0.0 \
				or not _is_numeric(leap.get("height")) \
				or float(leap.get("height", 0.0)) <= 0.0:
			out.append("%s/%s: leap time and height must be positive" % [id, bid])
	elif LEAP_BEATS.has(bid):
		out.append("%s/%s: authored leap is missing" % [id, bid])
	if b.has("throw"):
		var throw: Dictionary = b.get("throw", {})
		if shape != SHAPE_ZONE:
			out.append("%s/%s: throw is only legal on a zone" % [id, bid])
		if not _is_numeric(throw.get("flight")) \
				or float(throw.get("flight", 0.0)) <= 0.0 \
				or not _is_numeric(throw.get("height")) \
				or float(throw.get("height", 0.0)) <= 0.0:
			out.append("%s/%s: throw flight and height must be positive" % [id, bid])
	elif shape == SHAPE_ZONE:
		out.append("%s/%s: every zone requires a throw" % [id, bid])
	return out

## Every rule this file claims about itself, checked. Returns one line per
## problem and an empty array when the table is sound.
##
## It exists because all of the invariants below are the kind that a plausible,
## well-meaning edit breaks silently: a fourth beat, a summon of a kind with no
## stat row, a punish longer than the cooldown that contains it, two beats whose
## tells are the same picture. None of those raise an error, and none of them are
## visible in a frame until someone plays the fight and cannot say why it reads
## badly. A boss director should call this and fail on a non-empty result.
static func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var seen_tells: Dictionary = {}

	for id in all():
		var row := get_boss(id)
		var list := beats(id)
		out.append_array(_dynamic_row_errors(id, row, false))

		# SCOPE §1: the four models are on disk and there is no fifth.
		var model_path: String = MODEL_DIR + String(row["model"]) + ".glb"
		if not ResourceLoader.exists(model_path):
			out.append("%s: no model at %s" % [id, model_path])

		# The relic id is checked against the CATALOGUE, never against GDD §6.2's
		# prose, and this is not belt-and-braces: writing the obvious id off the
		# printed name ("Glass-Kiln Core" -> `glass_kiln_core`) is exactly how
		# this row was wrong when it was first authored, and `RelicDb` spells it
		# `kiln_core`. Nothing would have raised — a boss would simply have
		# dropped an object the Lanternkeeper had never heard of, and the first
		# person to notice would have been a player on floor 2.
		#
		# This is the ONLY place in the file that touches another package's
		# table. The rows themselves stay dependency-free.
		var relic: StringName = row["drop"]["relic"]
		if not RelicDb.is_relic(relic):
			out.append("%s: drops %s, which is not one of the twelve relics"
				% [id, relic])
		else:
			var placed := RelicDb.relic_at(int(row["floor"]), &"boss")
			if placed.is_empty() or placed["id"] != relic:
				out.append("%s: drops %s, but RelicDb puts %s on floor %d's boss"
					% [id, relic,
						placed.get("id", &"nothing"), int(row["floor"])])

		# The room turn remains a separate half-health effect. The actor's phase
		# uses the same threshold but owns movement and selection, while the turn
		# still owns only the room. The kind is in the vocabulary, and the
		# threshold is a fraction of a health bar rather than a number of
		# HP. A `turn.at` of 0 never fires and one of 1 fires on the first
		# blow, and both are the kind of typo that reads as "the turn is broken"
		# from a director rather than as a bad row.
		#
		# The third assertion an earlier draft proposed -- no beat's tell under
		# 60% of the shallowest tell of its shape -- is deliberately NOT here:
		# §4 is the argument for why it would be checking a number it invented.
		var t := turn(id)
		if not t.is_empty():
			var kind: StringName = t.get("kind", &"")
			if not TURN_KINDS.has(kind):
				out.append("%s: turn kind %s is not one of the four (BOSSES §5)"
					% [id, kind])
			var at := float(t.get("at", -1.0))
			if at <= 0.0 or at >= 1.0:
				out.append("%s: turn.at is %.2f — it is a health FRACTION and "
					% [id, at] + "must be in (0, 1)")

		# Three beats across both pressure phases, hard cap.
		if list.size() != 3:
			out.append("%s: %d beats — the cap is exactly 3 (SCOPE §6)"
				% [id, list.size()])

		var poses: Dictionary = {}
		for b in list:
			var bid: StringName = b["id"]
			var tell: Dictionary = b["tell"]
			out.append_array(_beat_modifier_errors(id, b))

			if not SHAPES.has(b["shape"]):
				out.append("%s/%s: shape %s is not in the vocabulary"
					% [id, bid, b["shape"]])
			if not POSES.has(tell["pose"]):
				out.append("%s/%s: pose %s is not in the vocabulary"
					% [id, bid, tell["pose"]])

			# One boss, three poses. Three beats that hold the same shape are
			# one beat with three timers.
			if poses.has(tell["pose"]):
				out.append("%s/%s: reuses pose %s within the same fight"
					% [id, bid, tell["pose"]])
			poses[tell["pose"]] = true

			# And across the whole game, no two beats are the same picture.
			var key := "%s|%s" % [tell["pose"], (tell["color"] as Color).to_html()]
			if seen_tells.has(key):
				out.append("%s/%s: same (pose, colour) as %s"
					% [id, bid, seen_tells[key]])
			seen_tells[key] = "%s/%s" % [id, bid]

			# Every beat buys a readable breath: a rooted aperture only on the
			# authored recover weak point, otherwise movement. Cooldown contains
			# that budget so the next tell cannot start before it is paid.
			if float(b["punish"]) <= 0.0:
				out.append("%s/%s: no post-commit breath" % [id, bid])
			if float(b["cooldown"]) < float(b["punish"]):
				out.append("%s/%s: cooldown %.2f is shorter than punish %.2f"
					% [id, bid, b["cooldown"], b["punish"]])
			if float(tell["time"]) <= 0.0:
				out.append("%s/%s: no tell" % [id, bid])

			# The silent-fallback trap: Enemy._ready swaps an unknown kind for
			# skeleton's STATS while keeping the requested MODEL.
			if b["shape"] == SHAPE_SUMMON and not Enemy.DEFS.has(b["kind"]):
				out.append("%s/%s: summons %s, which has no row in Enemy.DEFS"
					% [id, bid, b["kind"]])

	# The manifest is four. Not three, and emphatically not five.
	if all().size() != 4:
		out.append("the manifest says 4 bosses; this table has %d"
			% all().size())

	# --- The minibosses ------------------------------------------------------
	# `docs/PUZZLES.md` §7's three rules, each checked because each one is the
	# kind a plausible edit breaks silently: a third beat, a relic drop that
	# would make an optional branch mandatory, and a silhouette a player cannot
	# tell from the floor's boss.
	# **Rule 0: four of them, and one per floor.** This check is here because its
	# absence is what card 23 was: `BOSSES` had a manifest count from the day it
	# was written and `MINIBOSSES` had none, so a table holding ONE row passed
	# `validate()` clean for as long as it took somebody to open the file.
	# Nothing raised -- `miniboss_for(2)`, `(3)` and `(4)` answered `&""`,
	# `Dungeon._place_chamber` returned on the first line without a word, and
	# three quarters of the treasure branch was simply not in the game. A
	# director that called `validate()` and photographed floor 1 saw nothing at
	# all wrong.
	#
	# **A bare count of four is not enough**, which is the second half of the
	# lesson: two minibosses on floor 2 and none on floor 3 also counts to four,
	# and it fails in exactly the same silent way -- `miniboss_for(3)` answers
	# `&""`, one chamber comes up empty, and the other floor's `for` loop returns
	# whichever of its two rows `Dictionary.keys()` happened to order first. So
	# the floors are counted, not the rows.
	if all_minibosses().size() != 4:
		out.append("the manifest says 4 minibosses; this table has %d"
			% all_minibosses().size())
	for level: int in range(1, 5):
		var on_floor: Array[StringName] = []
		for id in all_minibosses():
			if int(MINIBOSSES[id]["floor"]) == level:
				on_floor.append(id)
		if on_floor.size() != 1:
			out.append("floor %d has %d miniboss(es) %s -- exactly one per floor, "
				% [level, on_floor.size(), on_floor]
				+ "always (PUZZLES §7). A floor with none builds an empty "
				+ "treasure chamber and says nothing about it")

	for id in all_minibosses():
		var row := get_boss(id)
		var list := beats(id)
		var level := int(row["floor"])
		out.append_array(_dynamic_row_errors(id, row, true))

		var model_path: String = MODEL_DIR + String(row["model"]) + ".glb"
		if not ResourceLoader.exists(model_path):
			out.append("%s: no model at %s" % [id, model_path])
		if BOSSES.has(id):
			out.append("%s: is both a boss and a miniboss -- get_boss() would "
				% id + "answer with whichever table was read first")

		# Rule 1: two beats, and one of them is the wall the floor's verb opens.
		if list.size() != 2:
			out.append("%s: %d beats — a miniboss gets exactly 2 (PUZZLES §7)"
				% [id, list.size()])

		# Rule 2: no verb and no relic. An arbitrary item here would put something
		# GDD pillar 4 cares about behind an OPTIONAL puzzle, and floor 1 would
		# stop being completable without solving one — which is why the item half
		# is an allow-list and not a free field.
		var drop: Dictionary = row.get("drop", {})
		var token := StringName(drop.get("item", &""))
		if token != &"" and not PROGRESS_TOKENS.has(token):
			out.append("%s: drops %s — a miniboss may only hand over a "
				% [id, token] + "PROGRESS_TOKENS id, never a verb (PUZZLES §7)")
		if StringName(drop.get("relic", &"")) != &"":
			out.append("%s: drops a relic — the chest behind it is the reward "
				% id + "(PUZZLES §7)")

		# Rule 3: not the same silhouette as its own floor's boss.
		var boss_id := for_floor(level)
		if boss_id != &"" and BOSSES[boss_id]["model"] == row["model"]:
			out.append("%s: shares the model %s with floor %d's boss %s"
				% [id, row["model"], level, boss_id])
		if boss_id != &"":
			var mini_move: Dictionary = row.get("movement", {})
			var boss_move: Dictionary = BOSSES[boss_id].get("movement", {})
			for phase_key: String in ["phase_1", "phase_2"]:
				var mini_phase: Dictionary = mini_move.get(phase_key, {})
				var boss_phase: Dictionary = boss_move.get(phase_key, {})
				if not mini_phase.is_empty() and not boss_phase.is_empty():
					if float(mini_phase.get("speed", INF)) >= \
							float(boss_phase.get("speed", 0.0)):
						out.append("%s: %s speed must stay below %s"
							% [id, phase_key, boss_id])
					if float(mini_phase.get("orbit_strength", INF)) >= \
							float(boss_phase.get("orbit_strength", 0.0)):
						out.append("%s: %s orbit pressure must stay below %s"
							% [id, phase_key, boss_id])

		var mini_poses: Dictionary = {}
		for b in list:
			var bid: StringName = b["id"]
			var tell: Dictionary = b["tell"]
			out.append_array(_beat_modifier_errors(id, b))
			if not SHAPES.has(b["shape"]):
				out.append("%s/%s: shape %s is not in the vocabulary"
					% [id, bid, b["shape"]])
			if not POSES.has(tell["pose"]):
				out.append("%s/%s: pose %s is not in the vocabulary"
					% [id, bid, tell["pose"]])
			if mini_poses.has(tell["pose"]):
				out.append("%s/%s: reuses pose %s within the same fight"
					% [id, bid, tell["pose"]])
			mini_poses[tell["pose"]] = true
			# The same-picture rule, against the bosses AND the other
			# minibosses: `seen_tells` is still the one map, so a miniboss tell
			# that matched a boss's is caught here rather than in play.
			var key := "%s|%s" % [tell["pose"], (tell["color"] as Color).to_html()]
			if seen_tells.has(key):
				out.append("%s/%s: same (pose, colour) as %s"
					% [id, bid, seen_tells[key]])
			seen_tells[key] = "%s/%s" % [id, bid]
			if float(b["punish"]) <= 0.0:
				out.append("%s/%s: no post-commit breath" % [id, bid])
			if float(b["cooldown"]) < float(b["punish"]):
				out.append("%s/%s: cooldown %.2f is shorter than punish %.2f"
					% [id, bid, b["cooldown"], b["punish"]])
			if float(tell["time"]) <= 0.0:
				out.append("%s/%s: no tell" % [id, bid])
	return out
