# BESTIARY — enemies, minibosses and bosses

**This file owns encounter design**: what a body asks the player, which item
answers it, and the rules the four bosses and four minibosses are built against.
It does **not** own which four minibosses floors 1–4 get — that is a reward-branch
decision and `docs/PUZZLES.md` §7 keeps it. It does not own stats; those are
`Enemy.DEFS` and `BossDb`, and a doc that restated them would disagree with them
by Friday. **It does not own the bosses' working either** — §5 names each fight's
shape and `docs/BOSSES.md` is the worked spec that carries the timings, the
parry-and-roll map, the arena's turn and the rows to paste.

Everything here is read off `docs/OOT_CATALOGUE.md` §3, which is the 1998 Player's
Guide gone through dungeon by dungeon and written down as mechanics.

**Status: design, except §3's number 4.** The **Thief is built** — see §3's
"Built" note. The other seven behaviours in §3 are still design. §5's boss shapes
are a re-reading of beats that already exist in `BossDb` — no new beats, no
second phase, no new models.

---

## 0. The one rule, and the diagnosis it comes from

> **Every enemy is a question. Every item is an answer.**
> **An enemy that only the sword answers has not been designed.**

Here is the state of the roster, honestly. `Enemy.DEFS` has seven rows —
`skeleton`, `goblin`, `kobold`, `orc`, `wraith`, `troll`, `knight_iron` — and
they differ in **health, damage, speed, height, detect, reach, windup, recover
and cooldown.** Nine numbers. Not one behaviour.

So every enemy in the game asks the same question — *can you swing back?* — and
the only answer is the sword. The bow, the Burst-Verse and the hookshot are
**puzzle-only items**: `docs/PUZZLES.md` gives all three a room to open and none
of them a body to beat. GDD §5.2 promises the hookshot "freezes the thing for a
second"; that is implemented, and nothing in the roster ever needs it.

That is the gap this document closes, and the good news in
`docs/OOT_CATALOGUE.md` §3 is how cheaply it closes: Ocarina's memorable enemies
are memorable because **each one names an item**, and almost none of them is a
new mesh.

---

## 1. Bipeds — the constraint that costs nothing

**Everything in `assets/monsters/` is already a humanoid**: `skeleton`, `goblin`,
`kobold`, `orc`, `wraith`, `troll`, `knight_iron`, `golem`, `ogre`. Nine bodies,
nine bipeds, one shared 81-clip `monster_library.res` rigging all of them.
`docs/SCOPE.md` says **new monster models: 0** and this document does not ask for
one.

So "stick to bipeds" is not a sacrifice here. It is a description. But it is also
**better design than the alternative**, and it is worth saying why, because the
temptation at floor 3 will be to reach for something with too many legs.

- **A biped has a front, so a guard is legible.** Positional weakness — get
  behind it — only reads as a rule if the player can see which way "behind" is.
  A silhouette with a face teaches its own weak side.
- **A biped has hands, so its threat is in its silhouette.** It can carry a
  shield, a torch, a bow, a plate — *or your bag*. Every behaviour in §3 is
  something you can see a body holding from across a room, which is
  `docs/STYLEGUIDE.md`'s readable-channel rule applied to encounters.
- **A biped shares the hero's animation grammar.** Wind-up, commit, recover reads
  the same on a body shaped like yours, so a telegraph learned on a skeleton
  transfers to a knight. GDD §7's 60% floor on telegraph compression only means
  something if telegraphs are comparable across the roster.
- **Ocarina agrees.** Its best-designed enemies are overwhelmingly bipeds —
  Stalfos, Lizalfos, Iron Knuckle, Gerudo guard, ReDead, Wolfos, Dark Link, Deku
  Scrub. The quadrupeds and the floaters are the trash mobs nobody remembers, and
  the genuinely non-humanoid things are bosses, which get an arena and four
  minutes to explain themselves.

**The one thing bipeds are bad at is being unsettling**, and Ocarina's answer is
not anatomy — it is behaviour. A ReDead is a humanoid that stands still and looks
at you. That is the scariest thing in the game.

---

## 2. What each item should answer

The left column is built. **The right column is almost entirely empty**, and that
is the whole finding.

| Item | Puzzle verb — built | Combat verb it should own |
|---|---|---|
| **Sword** | urn, lantern | everything, and that is the problem |
| **Shield** | sun socket beam | **send a thrown thing back.** Nothing in the roster throws anything |
| **Bow** (T1) | eye switch | **the body that has not noticed you**, and the only stagger that lands on a guard |
| **Burst** (T2) | cracked pillar | **the guard-breaker**, and the only blow a riser does not get up from |
| **Hookshot** (T3) | hook ring | **close a gap you did not choose** — pull yourself to a perched body, or freeze one mid-beat |
| **Rope** | — | none, and it should stay none. It is the extraction verb and GDD §2 needs it uncomplicated |

**The shield row is the cheapest and the most valuable.** It is owned from minute
one, it already has a raycast that bounces a beam (`SunSocket`), and Ocarina uses
it on its *first enemy* and on *three of its bosses*. One enemy that throws
something blockable turns a wall into a verb for the entire game.

---

## 3. Eight behaviours, and not one new model

Each is a key on an existing `Enemy.DEFS` row plus a small behaviour on `Enemy`.
The **Wears** column is which body carries it, chosen so the silhouette already
suggests the behaviour.

**Every behaviour has two answers** — the fast one and the expensive one — for
the reason `docs/PUZZLES.md` §10.6 gives: a single-answer enemy at depth is a
knowledge check, and GDD pillar 3 rules those out.

| | Behaviour | What the body does | Fast answer | Expensive answer | Wears | From |
|---|---|---|---|---|---|---|
| **1** | **Thrower** | Lobs something on a slow arc. The throw is **blockable and it returns** | **Shield**, on the beat | close the distance and eat one | `goblin` | Deku Scrub |
| **2** | **Guard** | Plated front; melee rings off it and does nothing | **Burst** — or an **arrow** in the beat it turns | circle to the back, slowly | `knight_iron` | Stalfos, Iron Knuckle |
| **3** | **Perched** | Stands across a gap or on a ledge and throws down | **Bow** | **Hookshot** to close, then melee | `kobold` | Gerudo archer |
| **4** | **Thief** | Grabs, and **takes one bag slot**, then runs for the nearest door | kill it — it drops what it took | let it go and eat the loss | `goblin` | Like Like, Dead Hand |
| **5** | **Caller** | Does not fight. Winds up a shout that wakes the room | **Bow**, before the shout lands | run it down and accept the room | `skeleton` | Gerudo alert |
| **6** | **Gaze** | Stands still. Looking at it **roots you for a beat**; then it closes | kill it at range | break line of sight and go around | `wraith` | ReDead |
| **7** | **Riser** | Gets back up once, after a few seconds, unless the killing blow was **Burst** | **Burst** the finish | kill it twice | `skeleton` | Stalfos |
| **8** | **Ledworthy** | Heavy, slow, trivially baited — and it counts as `plate_weight` | lead it onto the plate | push a block instead | `troll` | Armos |

### Build four, not eight

**Committed: 1 Thrower, 2 Guard, 3 Perched, 4 Thief.** One per item, which is the
point — the four together are the sentence *"the bow, the shield, the Burst and
the hookshot each beat something."* The other four are flavour and are not
committed, exactly the way `docs/PUZZLES.md` §2's phase 2 is not committed.

### Number 4 is the one this game should build first

The **Thief** is the only entry on the list that is not borrowed thinking. GDD §2
asks *is what I am carrying worth more than the walk back*, and a monster that
takes a bag slot and runs for the door asks that question **in the middle of a
fight**, with a real answer on either side. Chase it and you are spending Heat and
stamina on loot you already had; let it go and the run just got cheaper to
extract.

Everything it needs exists: the bag is `Run`'s, `LootMote` already knows how to
drop a stack on the floor, and "run for the nearest exit" is the leash logic
inverted. **It is the cheapest new *decision* available anywhere in the project.**

### Built — and what the build settled

`"behaviour": &"thief"` is a key on the existing `goblin` row of `Enemy.DEFS`,
with an `@export var behaviour` on `Enemy` so any body can be given one in a
scene. **A key and not a boolean**, because this table hangs *two* behaviours off
that same goblin row (1 Thrower, 4 Thief) and a `is_thief` flag would have made
the second one a schema change. No new kind, no new model — `docs/SCOPE.md` §1's
counts do not move.

**A behaviour is worn by a SHARE of a kind, not by the kind** (`share` on the
row, `K.THIEF_SHARE` = 0.25, rolled in `Enemy._ready` off the body's own seeded
RNG). This paragraph used to stop at the line above, and the omission deleted the
goblin: the key was an unconditional default, nothing ever set `Enemy.behaviour`,
and **a thief cannot swing** — `_tick_chase` checks the grab before the wind-up —
so every goblin in the game spent its life reaching, whiffing and circling
without ever attacking (card #86). The table two sections up was always the
argument against "all of them": it hangs two behaviours off this one row. An
explicit `Enemy.behaviour` skips the roll, because a spawner or a director asking
for a thief must get one every time.

Five things the build had to decide that the table above does not say:

- **It only reaches when there is something to reach for** (`Run.stealable()`,
  the dry counterpart of `burnable()`), and otherwise it swings like any other
  goblin. Not a special case: GDD §2's question is *is what I am carrying worth
  more than the walk back*, and a body that asks it of a player carrying nothing
  is asking nothing at all. Without this the grab check — which sits ahead of
  the wind-up — turned an empty-handed run into a monster that could not attack.
- **The grab is a distance check, not a hitbox.** It costs a bag slot and no
  HP. That is what makes stepping out of the tell the whole defence — the
  player is not trading health for loot, they are choosing whether to be there.
- **The telegraph is `K.THIEF_GRAB` = 0.75 s**, more than twice a goblin's 0.32 s
  swing, scaled by `Prog.windup_scale(level)` like every other beat, so it floors
  at 60% (0.45 s) at depth — GDD §7's rule, not a second one.
- **It is distinguished from the swing by the direction of the lean, not the
  colour.** Same `Pal.RUST` wind-up glow; the swing leans *back*
  (`K.WINDUP_LEAN_DEG`), the grab leans *forward* (`K.THIEF_LEAN_DEG`). §1's one
  grammar, and CLAUDE.md §3's "change the shape, not the material". `Pal.GOLD` is
  currency and `Pal.CYAN` is the way out; neither was available.
- **What it took and where it went are both world-space objects**, because a HUD
  toast was not available (`Bus.request_message` has emitters and no listener).
  The sack on its chest is literally `LootMote`'s prism, tinted and lit with the
  stolen item's own colour, so a player who has picked that item up already knows
  what is being carried away; the door it picked wears a `Pal.CYAN` ring **and a
  vertical beam**. The ring alone was the first cut and the render is what
  rejected it — in the garrison it sat behind a knee-high planter.

It steals the **richest reachable slot in the HOLD only**. The five-slot document
case is never touched (`docs/METAGAME.md` — that is what the case is *for*), and
relics and Echoes are refused outright. Kill it and one `LootMote` carrying the
whole stack drops where it fell; let it reach the door and the loss is permanent.

Proven by `tools/directors/thief.gd` — which now **asks for** the behaviour
rather than inheriting it, because a share makes the default a coin flip.

And by `tools/directors/goblin_melee.gd`, which exists because none of the above
could see the failure that mattered. Every beat in `thief.gd` names the thief it
wants, so all of them passed while the behaviour was eating the whole kind.
`goblin_melee` asks the two questions from the other side — *does a goblin ever
swing* (with a skeleton in the same room as its control) and *how many of them
are thieves* — and the second one is the beat that fails the day the share goes
back to 1.0.

### The rule that keeps this at eight

> **A behaviour must name an item, and the item must be one of the six.**

Not "hits harder", not "moves in a pattern", not "spawns adds" — those are stats
and beats, and `Enemy.DEFS` and `BossDb` already own them. A ninth behaviour that
does not put a specific item in the player's hand is a stat with a name on it.

---

## 3.5 The reaction — one number, four channels

A behaviour is what a body *asks*. This is what it does when the answer lands,
and it is deliberately **not** per-enemy design: one number, derived from the
blow, drives every channel, so they can never fall out of step.

```
weight = (hit.knockback - K.KNOCKBACK_LIGHT) / (K.KNOCKBACK_HEAVY - K.KNOCKBACK_LIGHT)
```

Clamped `0..1`. A jab is `0`; a committed swing or the spin is `1`. Every enemy
contact hitbox carries `KNOCKBACK_LIGHT`, so **monsters can never launch each
other** — the weight is zero by construction, not by a check.

That one number scales, together:

| Channel | Light (0) | Heavy (1) |
|---|---|---|
| Scuff burst at the contact point (`ImpactVfx`) | 8 motes | 26 motes |
| Hit-stop | `K.HITSTOP_LIGHT` | `K.HITSTOP_HEAVY` |
| Screen shake | `K.SHAKE_TAP` | `K.SHAKE_HIT` |
| Launch odds and launch force | never | `K.LAUNCH_CHANCE` × mass² |

**The crit *is* the launch.** There is no second roll and no separate crit
stat — when a body leaves the ground it gets the gold starburst, `SHAKE_CRIT`
and a full `HITSTOP_HEAVY`, because that is the frame worth holding. A jab can
never produce one.

**Mass resists it for free.** The odds scale by the *square* of
`height / K.LAUNCH_MASS_REF` and the speeds only *linearly*, so a goblin
(1.25 m) goes up often and far, a troll (2.60 m) rarely and barely — and an
elite, being `Prog.ELITE_SCALE` taller, resists harder with no extra code. Death
always launches; that is BOTW's rule and it is the one the player reads as
"I killed it" rather than "it stopped".

Bosses override `_can_launch()` to `false`. Their impact still scales — a heavy
blow on a boss shakes and bursts like a heavy blow — but the **state** does not
move. That is poise, and it is the difference between a set-piece and a mob.

Proven by `tools/directors/monster_launch.gd`.

---

## 3.6 The two answers — the parry and the perfect dodge

§3.5 is what a body does when the player's blow lands. This is what the player
does when the *body's* blow lands, and there are exactly two answers because a
telegraph (§0) is worth reading only if reading it pays.

They are **deliberate opposites**, and every number below follows from that:

| | Parry — `shield` + `attack` | Perfect dodge — roll into the blow |
|---|---|---|
| Asks for | a commitment, before the blow | nothing; the roll you already threw |
| Window | `K.PARRY_WINDOW` 0.20 s from the press | `K.DODGE_GRACE` 0.30 s from the roll's start |
| Costs | no stamina — the recovery *is* the price | the roll's stamina, and nothing more |
| Gets it wrong | `K.PARRY_RECOVER` 0.42 s with **no guard** | nothing; you were rolling anyway |
| Pays | throws the attacker, opens the riposte — which cannot be interrupted | slows the world, opens the flurry |

**The parry is aggressive and punished.** Pressing it drops the shield on the
same frame — `blocking` goes false and `guard_changed` fires — so a miss is a
0.42 s hole in the middle of a fight, taking blows at full price. That hole is
why the move costs no stamina: a resource price *and* a timing price would make
it a thing nobody throws. What it buys is the one thing nothing else in the
hero's kit buys, which is **an opening on a body that had the initiative**:
`stagger()` cancels the swing mid-frame, shoves the attacker `K.PARRY_SHOVE`
back, and opens `K.RIPOSTE_WINDOW` — 1.20 s in which the attack button comes out
as the dash, closing the gap the shove just made.

**The riposte carries i-frames, for exactly as long as it commits you**
(`dash_swing_time` 0.62 s, granted in `HeroCombat._dash_swing`). This is the
only swing in the kit that does, and the reason is the room rather than the
move: a parry is a read on ONE monster and it is thrown in a room that holds
three, so a 0.62 s commitment spent inside a pack was a reward the pack
collected. Without them the correct play against a gang was to *decline* the
opening you had just paid a 0.42 s recovery for, which made the game's best
defensive read a duelling-only move. No tail beyond the swing, by the same rule
the dodges live by — the frame the hero gets his input back is the frame he can
be hit on. The window is also **spent by the swing**, so one parry buys one
riposte and not the two that 1.20 s of window and a 0.62 s swing left room to
mash out.

The **flurry does not** carry them, and that asymmetry is not settled design —
it is a longer commitment (1.02 s) thrown from the same crowded room, and the
slow-mo it opens under is not the same thing as immunity. If a pack starts
eating perfect dodges the way it used to eat parries, this is the row to
revisit.

**A parry moves a boss.** It is the *only* thing that does — §3.5's poise rule
holds against every blow the sword can throw. `Boss.stagger()` cuts the beat
short into `RECOVER`, which is the beat's own authored punish window opening
early, so the reward is the fight's existing vocabulary rather than a new one.
The exemption is safe precisely because the parry can only be thrown *after* the
boss has committed.

**The perfect dodge is safe and passive.** It asks for no prediction at all: the
reward fires only when a blow genuinely reached the hero during the roll's first
`K.DODGE_GRACE`. Roll early and the blow misses in space and never calls in;
roll late and it hits. Once per roll, so a pack cannot pay out three times.
The payoff is `K.SLOWMO_SCALE` 0.34 for `K.SLOWMO_TIME` 0.55 s — enough to see
the opening — and `K.FLURRY_WINDOW` 1.40 s in which the attack button becomes
the **jump attack**: a hopping, driving overhead that carries `KNOCKBACK_HEAVY`
and therefore, by §3.5, launches.

Slow-mo and hit-stop share one writer (`Feel._apply_time_scale`) and **a stop
outranks a dip**, both timed on the wall clock. A dip that a hit-stop could
cancel would read as a stutter, and every reaction VFX runs on the wall clock
for the same reason — a tween gets delta 0 at `time_scale = 0`.

The two are told apart at a glance, on purpose: the parry is a **gold burst** at
the shield — a spinning ring and an eight-spike star, the same gold as a crit
launch, plus a `SHAKE_CRIT` and the HUD's guard pip flashing gold. The dodge is
a **cold ring on the floor**, frost to cyan, no star, no sparks, barely a shake.
One is a hit; the other is time bending.

Proven by `tools/directors/parry_dodge.gd`.

---

## 3.7 The third answer — none, and what that costs

§3.6 is what the player does when he reads the telegraph. This is what happens
when he does not, and it is the mirror of §3.5: **one price, several channels,
derived from the blow rather than authored per monster.**

`Hit.force()` — damage, knockback, attacker mass and how committed the swing was
— scales the hit-stop, the shake, a directional camera lurch and the HUD's damage
arc. A second, discrete draw picks a **flinch**, a **stagger** or being **knocked
flat**, and being knocked flat needs *both* a body heavy enough and a swing
committed enough:

| | flinch | stagger | flat |
|---|---|---|---|
| goblin | 90 | 10 | **0** |
| skeleton | 78 | 22 | **0** |
| orc | 64 | 33 | 3 |
| troll, ordinary swing | 39 | 54 | 8 |
| troll, telegraphed heavy | 29 | 36 | 35 |
| Warden's sweep | 16 | 76 | 8 |
| Warden's telegraphed drop | 9 | 6 | 85 |

**Nothing the hero's own size or smaller can put him on the ground at all** — not
rarely, *never*. Being floored is what a body twice your weight does when it
winds up to do it, and the roster below the hero's mass has no access to it at
any commitment. That is the whole reason the tier is worth reading.

**A monster's mass is therefore its defence *and* its threat**, off the same
`height / K.LAUNCH_MASS_REF` figure §3.5 already uses: the troll that barely
launches is the troll that puts you on your back. And what separates one swing
from another is **the length of the tell** — the roster's `windup`, the same
number that makes a blow readable, is what tells the pricing it was committed.
Nothing new is authored to make either true.

**The troll is the only roster body with two beats**, and it has them because it
needed them. With one swing at `damage 6 HP / windup 0.72` its every attack
read as a fully committed heavy and floored the player 31% of the time — a tax,
not a telegraph. Split, the pairing is the mechanic rather than a note about it:

| | tell | damage (HP) | shove | floors you |
|---|---|---|---|---|
| ordinary swing | 0.50 s | 4 | light | 8% |
| heavy | 1.05 s | 7 | heavy | 35% |

The heavy rears 1.55× as far, glows hotter, and **roars** (`monster_attack`,
where the ordinary swing gets `attack_prepare`) — four channels, because in a
pack the player is looking at one monster at a time. `Enemy._heavy_row` owns the
schema: an optional `"heavy"` block on any `DEFS` row, every key falling back to
the ordinary swing's, so giving the iron knight a shield-bash is five numbers and
no code. `tools/directors/troll_heavy.gd` proves both beats are thrown and that
the heavy stamps its own damage, shove and commitment through the shared hitbox.

`docs/CONTRACT.md` “Taking a hit” owns the rule and the override pair for the
exceptions. `tools/directors/hurt_table.gd` prints every blow in the game through
it; `tools/directors/hero_struck.gd` photographs the receiving end.

---

## 4. Minibosses — the wall, and the second way over it

`docs/PUZZLES.md` §7 owns the four and their beats. Three rules from the
catalogue that the four should be built against, and one audit finding.

**4.1 — The wall must be visible before it is relevant.** The Bellows-Hand's
bellows have to be readable from the doorway, not discovered on the third circuit.
Ocarina always shows you the weak point first and the guard second: Skulltula
turns its armoured face toward you and its soft back is *right there* the whole
time.

**4.2 — There is always a second, worse way over the wall.** The Flare Dancer
takes a bomb, a hookshot *or* a hammer, and the Spirit Temple's *Trial by fire*
can be solved by leading the enemy into a fire that was already burning. The
floor's own verb stays the *fast* answer — §7's design is intact — but a player
who has not worked it out is paying more, not standing still.

**4.3 — Two beats, two tools.** §7's shape is already this and it should stay:
one beat the shield answers and one it does not. A fight that both beats answer
the same way is one beat played twice.

**4.4 — No miniboss drops a verb or a relic.** The chest behind it is the reward;
what the body leaves is at most a **progress token** — an object with no use, no
row on any counter and no bag slot, whose only job is to be a key somewhere else
(`BossDb.PROGRESS_TOKENS`). Floor 1's Sluice-Keeper leaves the **maker's mark**,
and that is what brings the smith back to the yard. This used to read "they drop
nothing but the chest behind them", and card #91 is the amendment: a token is
still not a verb and still not power, so the rule the sentence was protecting is
intact. `docs/PUZZLES.md` §4 owns it.

**The audit.** The minibosses now teach the same Zelda-style grammar at a
lower tier: two learned attacks, one authored item aperture, three damage
segments, and a movement-pressure phase change at half health. They do not add
a second health bar or an arena turn.

| Miniboss | Floor verb | Authored break |
|---|---|---|
| Sluice-Keeper | sword | Strike after `flood_stomp` enters recovery |
| Bellows-Hand | Bow | Shoot during live `plate_advance` travel |
| Second Voice | Burst/bomb | Break during live thrown `keening` zones; a baited self-burst is the renewable fallback |
| Gate-Hound | Hookshot | Hook during the thrown `overhand` aperture |

This is deliberately a compressed rehearsal, not four disposable health bars:
the lower health, shorter windows, smaller arenas, and three-cycle promise let
the branch teach the floor verb without spending the full boss's four-cycle
arc.

---

## 5. Bosses — one health bar, two pressure phases

`BossDb` still has five attack shapes (`arc`, `slam`, `charge`, `zone`,
`summon`) and twelve authored boss beats. The issue #203 refinement changes
how those existing pieces are sequenced: bosses now run and orbit between
beats, commit moving charges, leaps, sweeps and thrown hazards, expose one
item-specific weak point, and accept health damage only during true stagger.

| Boss | Floor tool | Authored break | Full-window goal |
|---|---|---|---:|
| **The Cistern Warden** | sword | Strike after `cistern_drop` recovery | 4 |
| **The Slag Ogre** | Bow | Shoot during live `bellows_charge` travel | 4 |
| **The Bellwake** | Burst/bomb | Break during a live `undertow` zone; baiting its own burst is the renewable fallback | 4 |
| **The Riven Knight** | Hookshot | Hook after `call_the_iron` recovery | 4 |

The floor sequence is therefore Sword → Bow → Bombs/Burst → Hookshot. The
correct tool breaks the aperture for zero HP, after which a short vulnerable
stagger accepts one capped damage segment. Wrong tools, ordinary attacks, and
parries outside true stagger deal zero HP. Parry remains useful for poise and
timing, but it does not bypass the authored solve.

At half health every encounter enters phase 2 on the same health bar. Movement
gets faster, the preferred orbit closes, reposition time shortens, and dangerous
beats receive more weight. Full bosses also turn their arena at that threshold;
minibosses do not. Phase 2 preserves the learned counter instead of replacing
it with an unrelated trick.

The catalogue comparison in `docs/OOT_CATALOGUE.md` is a vocabulary source,
not a claim that these greybox fights reproduce Ocarina encounter-for-
encounter. Gohma and King Dodongo support expose-then-punish and receptacle
solves; Phantom Ganon and Ganondorf support projectile timing before a damage
window; Volvagia and Bongo Bongo support spatial alternation and explicit
vulnerability; Iron Knuckle supports a pressure-changing second half. The
current implementation selects mechanics that remain answerable with the
four-item floor sequence and the existing five attack shapes.

**No second health bar.** The escalation is behavior and arena state, not a
reset. There are two pressure phases, four fully spent stagger windows for a
boss, and three for a miniboss. Partial staggers are not rounded up: failure to
spend a segment can require another exposure.

**Boss lore is not catalogue data.** Encounter prose previously stored on
`BossDb` rows had no consuming surface and remains removed. If a future
approved surface needs it, author copy to that surface's real moment and length.

The worked timings, segment caps, movement rows, critical quality assessment,
and mechanical proof contract live in `docs/BOSSES.md`. When this bestiary
summary and that file disagree, `docs/BOSSES.md` owns combat truth.

---

## 6. What this costs the manifest

`docs/SCOPE.md` §1 speaks in counts, so:

| | Count | Moved? |
|---|---|---|
| **New monster models** | **0** | **No.** §1's biped rule is why, and it is the row this document exists to protect |
| Enemy kinds in rotation | **9** | **No.** A behaviour is a key on a row, not a tenth row |
| Boss beats | **12** | **No.** Issue #203 sequences the existing vocabulary into authored apertures |
| Boss phases | **2 pressure phases per row** | **Yes, inside issue #203's fixed roster amendment** |
| Minibosses | **4** | **No** |
| New UI screens | **0** | **No** |
| **Enemy behaviours** | **8**, of which **4 committed** | **New row.** This is the one to argue about |

**The bill, stated rather than absorbed.** Four behaviours is four small
additions to `Enemy` — a blockable projectile, a front-facing damage gate, a
ledge-preferring spawn rule, and a grab that moves one bag row and flees. None of
them is a new system, none needs a save field, and all four are provable by one
director that walks a hero past four bodies with four items. That is
`docs/SCOPE.md` §4.3's three questions answered: it makes GDD §2's question
*harder* (the Thief asks it mid-fight), it is a key on an existing table, and one
director proves it.

**What it must not become.** A behaviour that needs its own model, its own screen,
or its own arena is a miniboss, and there are four of those and no fifth.

---

## 7. The roster budget — and the unit it is counted in

**The encounter is a room. It is never a floor.** That sentence is the whole of
this section and it is here because a card was opened on the other reading
(#42): `tools/directors/mvp_loop.gd` printed `MVP enemies=24`, twenty-four
sounded like a swarm, and the number is not a swarm and never was.

### The budget

| | Owned by | Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|---|---|
| Rooms | `FloorDb.FLOORS[n].rooms` | 6 | 8 | 9 | 10 |
| Bodies per room | `FloorDb.pack` → `Prog.pack` | **2–4** | 2–5 | 3–6 | **2–4** (authored) |
| Rooms that hold none | `Dungeon._populate` | 3 | 3 | 3 | 3 |
| **Bodies on the walked floor** | the two rows above | **6–12** | 10–25 | 18–36 | 14–28 |

Three rooms on every floor hold nobody, and each has a reason already written
down: the **entrance** (the way in is not a fight), the **boss's chamber** (§5 —
three beats plus four bodies is unreadable), and the **maze**, which is masonry
wall to wall. On a six-room floor that is half the floor, which is why floor 1's
walked total is so much smaller than `6 × 4` suggests.

**The ceiling is `docs/GDD.md` §7, verbatim: *"a room never holds more than
seven."*** `Prog.pack`'s `mini(4 + l, 7)` is that sentence in code, and floor
4 buys back below it on purpose (`FloorDb`, floor 4's `pack` note) because seven
iron knights is a different problem from seven skeletons. **This document adds no
number to that** — it names the unit the number is counted in, which is the half
that was missing.

### What the `enemy` group total is not

`get_nodes_in_group(&"enemy")` on floor 1 answers **18–27**. Measured across
three seeds, the split is:

| seed | in rooms | behind a door | total |
|---|---|---|---|
| 4004 | 10 | 14 | 24 |
| 1234 | 6 | 12 | 18 |
| 777 | 9 | 15 | 24 |

**Ten to fifteen of them are behind a locked door on every seed** — the vault's
guards (the vault is opened by floor 2's boss item, so on floor 1 it cannot be
opened at all), the boss in its arena behind the boss door, and the miniboss in
its arena behind the treasure puzzle. None of them can be walked into, and the
group total counts all of them. `mvp_loop` prints the split now rather than the
sum, because a number that has to be explained every time it is read is a number
that will be misread again.

### What actually converges

Measured by `tools/directors/floor_crowd.gd`, which walks the hero in down a
corridor on held input rather than setting him down in the middle of a room:

- **Peak bodies engaged at one instant: 2–4.** That is `Prog.pack(1)` exactly —
  the room, and nothing but the room.
- **Peak rooms contributing at one instant: 2**, and only while standing in a
  doorway or a corridor. A corridor midpoint is 13 m from both room centres
  against an 11–15 m `detect`, so this is the leash and the grid behaving, not
  failing. Three has never been seen.
- **A hero who walks in and swings clears a 3–4 body room in 3–6 s**, losing 2–6
  of 12 HP — and the director's hero never blocks, never rolls and
  never parries, so that is the floor of what a player does, not the ceiling.
- **A hero who walks in and does nothing at all dies in 11–13 s.** That is not a
  bug and it is not in tension with GDD §7's *"the Cistern's mouth stays easy
  forever"*: easy means a fight you win with the verbs you have on run one, and
  four bodies beating a statue in twelve seconds is the fight being a fight.

### The rule

> **A body budget is per room, and a per-floor total is not a design number.**

If a floor ever reads as crowded, the thing to change is `FloorDb`'s `pack` row
for that floor — one number, in the manifest, which is where floor 4 already
does it. Not the detect radius, not the leash, and **not a navmesh** —
`Enemy`'s own header says why, and it is still true: a room is an open box with
nothing to path around, so the problem four bodies pose is *spacing*, and
`Enemy._separation` is the six lines that already answer it. A navmesh is a new
system, it is not on `docs/SCOPE.md`'s manifest, and it would be answering a
question the measurement above says nobody asked.
