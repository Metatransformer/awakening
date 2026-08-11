# BOSSES — four fight shapes, worked

**`docs/BESTIARY.md` §5 owns the encounter design**: which of Ocarina's five
shapes each boss is, why the diagonal reads the way it does, and the two rules
(no second health bar; the boss is a receptacle for something the player already
owns). **This file owns the working** — the beat that carries each shape, its
timings measured against the hero's own clock, where the parry and the roll land
inside it, what the arena does at the health threshold, and the exact rows to
paste.

When the two disagree, §5 says *what* and this says *how*. Two of §5's four
entries have already been corrected here rather than there, and §5 points at
both: the Warden does not hurl anything (§6.1) and the Bellwake has no pillar to
anchor to (§6.3).

It does **not** own stats. `BossDb` does, and a doc that restated the table would
disagree with it by Friday — so nothing below is copied out of the table except
where the arithmetic *is* the argument.

**Status: design, and one third of it is proven.** The twelve beats exist, but
only the Warden is built and photographed (`tools/directors/boss_cistern.gd`),
and the Warden throws an `arc`, a `slam` and a `zone` — so `charge` and `summon`,
which carry six of the twelve beats and three of the four fight shapes, have
never executed in front of a camera. **§9's opening note is the risk register for
that** and it should be read before this document is used to plan work.

What this document adds is **one `if`, one already-declared signal, and four
rooms** — `Bus.boss_phase_changed`, declared at `event_bus.gd:90` and emitted by
nothing today, is the signal, and §5 names it rather than leaving it implied. §8
checks the cost row by row against `docs/SCOPE.md` — §1 for most of it and §6 for
the beat and phase caps, which are not §1 rows. **Nothing here needs an owner's
amendment**, and the one change that would have — a real damage gate on the
Bellwake — is refused in §6.3 with the consequence recorded in §7 rather than
absorbed.

---

## 0. A fight shape is not an attack shape

`BossDb` has five **attack** shapes — `arc`, `slam`, `charge`, `zone`, `summon` —
and they answer *where does the damage go*. Ocarina's five are **fight** shapes,
and they answer *what is the sentence this whole fight is*: receptacle, exposed
weak point on a timer, reflect, positional, disarm
(`docs/OOT_CATALOGUE.md` §3).

A boss can have three perfectly readable attack shapes and no fight shape at all,
and that is what all four of ours had: three tells you learn to dodge and a
health bar you subtract. King Dodongo has two attacks and everybody remembers it,
because the sentence is *throw the thing you found in this dungeon into the open
mouth*.

**Naming one per boss must cost nothing**, and the three refusals that keep it
that way are, in the order they will be attacked:

1. **No fourth beat.** Twelve, hard cap, `BossDb.validate()` asserts exactly
   three per boss and `docs/SCOPE.md` §6 names "boss move sets balloon" as a
   likely failure. Every shape below is a re-reading of a beat that already
   exists in the table.
2. **No sixth attack shape.** `boss_db.gd`'s own header says *"five shapes.
   Implement each once; there are twelve beats and no thirteenth shape"*. This is
   the row that was actually at risk — reflect wanted a projectile — and §6.1 is
   the argument for why it did not get one.
3. **No second phase and no second health bar.** The escalation is the arena
   changing (§5). One signal, no new beats, no move-set change.

---

## 1. The twelve beats, re-read

§5 asks you to re-read the beats rather than write new ones, so here they are as
one table, ordered by floor. Nothing in it is authored here; the columns that
matter for the rest of the document are `recover` (what a parry can cut) and
`punish` (what every beat owes you).

| Boss | Beat | Attack shape | Tell | Pose / colour | Recover | Punish | Cooldown | Range gate |
|---|---|---|---|---|---|---|---|---|
| Warden | `sluice_sweep` | `arc` 4.6 m, 75° | 1.05 | rear / MOSS | 0.80 | 1.10 | 1.10 | 0–6.0 |
| Warden | **`cistern_drop`** | `slam` 2.1–6.2 m | 1.30 | rise / BONE | 1.10 | 1.60 | 1.60 | 0–7.5 |
| Warden | `drown_pool` | `zone` ×2, 2.6 m | 0.95 | tilt / COBALT | 0.55 | 1.35 | 1.60 | 0–14.0 |
| Ogre | **`bellows_charge`** | `charge` 11 m @ 13 | 0.90 | tilt / RUST | 1.20 | 1.70 | 1.70 | 4.5–16.0 |
| Ogre | `slag_backhand` | `arc` 4.2 m, 95° | 0.72 | rear / VITAL | 0.70 | 1.00 | 1.00 | 0–5.5 |
| Ogre | `tap_the_ladle` | `zone` ×3, 2.3 m | 1.15 | crouch / BONE | 0.90 | 1.45 | 1.70 | 0–16.0 |
| Bellwake | `first_toll` | `slam` 0–7.5 m | 1.20 | rise / ARCANE | 1.15 | 1.55 | 1.55 | 0–9.5 |
| Bellwake | **`hushing_choir`** | `summon` ×2 skeleton | 1.40 | spread / COBALT | 1.30 | 2.00 | 6.00 | 0–16.0 |
| Bellwake | `undertow` | `zone` ×1, 3.2 m | 1.00 | tilt / BONE | 0.60 | 1.20 | 1.40 | 0–16.0 |
| Knight | **`gate_lunge`** | `charge` 12 m @ 16 | 0.78 | crouch / VITAL | 1.05 | 1.35 | 1.35 | 1.0–16.0 |
| Knight | `riven_arc` | `arc` 4.0 m, 70° | 0.62 | rear / RUST | 0.65 | 0.90 | 0.90 | 0–5.5 |
| Knight | `call_the_iron` | `summon` ×2 wraith | 1.45 | spread / ARCANE | 1.40 | 2.10 | 8.00 | 0–16.0 |

**The four in bold are the fight-shape beats.** They were not chosen for their
fiction: three of the four are the beats with the longest `recover` in their own
fight, which §3 shows is exactly what makes a parry worth throwing, and the
fourth (`hushing_choir`) is the one beat in the game that **cannot** be parried
at all — which is why the Bellwake's answer had to be an area weapon rather than
a timing read (§6.3).

**What the ground marker actually draws** is part of the telegraph and it is not
uniform: `slam` draws its ring (inner and outer, so the donut is visible), `arc`
draws the **swept cone itself** — a filled sector at the beat's own `arc_deg` and
`reach` — `charge` draws a forward lane the width of its body, both parented to
the body so they turn as the boss tracks, and **`zone` and `summon` draw nothing
during the tell** — a zone's discs appear at the commit and grow over their own
fuse, and a summon's tell *is* the pose. Four different pictures for five shapes,
deliberately.

> **Fixed 2026-08-10, board card 21: the arc used to draw a bounding box.** Both
> the wind-up mark and the post-commit flash were `_lane_marker(reach, reach * 2 *
> sin(half))` — a rectangle — while `_shape_arc` resolved a cone. It was wrong at
> both ends of the range: at `slag_backhand`'s 95° half-angle the `sin` clamped
> and drew an 8.4 m slab over 4.2 m of reach for a 190° sweep that reaches round
> the boss's shoulders, and at `gate_shard`'s 22° it drew a 6.7 m wall for a 44°
> needle. A telegraph is a contract (GDD §4.1) and that one broke it in both
> directions at once — frightening the player off safe ground *and* saying nothing
> about lethal ground. `Boss._fan_marker` now draws the sector the damage test
> uses, and `tools/directors/arc_telegraph.gd` stands the hero six degrees either
> side of the drawn edge and reads his health: inside takes the beat's damage,
> outside takes nothing. Nothing about the *beats* changed — every number in §2
> and §3 is untouched.

---

## 2. The hero's clock

Every window below is measured in the only unit that matters — **how many times
the sword can land in it** — so the numbers it is measured against belong here
once rather than in four places.

From `HeroCombat`: `swing_time` 0.60 s, `chain_time_scale` (0.92, 1.65), and the
blade is live for `damage_window` (0.22, 0.62) of each swing. So, from a hero
already standing in reach who presses on the frame the window opens:

| Contact | Blade live | Costs |
|---|---|---|
| 1st light | **0.132 – 0.372 s** | — |
| 2nd light | **0.721 – 0.942 s** | the chain buffer |
| 3rd light — the finisher | **1.370 – 1.766 s** | +2 quarters, `KNOCKBACK_HEAVY` |

**1.37 s is the finisher line.** What it gets measured against is *not* a beat's
`punish` on its own, and an earlier draft of this section made exactly that
mistake: it counted six beats as clearing the line and called `drown_pool` and
`gate_lunge` "0.02 s short" at 1.35 s each. `_tick_recover` is the correction,
and it is one function — `recover` and `punish` are **one state**, the boss is
`_stop()`ed and rooted through both, and poise (§3) means it is hittable through
both. The clock a finisher runs against opens at the top of the recover, not at
the top of the window. So the number is `recover + punish`, and **all twelve
beats clear 1.37 s.** The tightest is `riven_arc` at 0.65 + 0.90 = **1.55 s**;
the two that looked short are nowhere near it — `drown_pool` gives **1.90 s**
rooted and `gate_lunge` **2.40 s**.

The caveat is a positioning one rather than an arithmetic one, and it is the
part worth designing to: **the recover half is only free for a beat that leaves
the boss where the hero already is.** After an `arc` or a `slam` it does. After a
charge it does not — `gate_lunge` overshoots twelve metres and its recover is
what the player spends walking back — so the two charges really do pay their
third contact out of the punish alone, and the two `arc`s hand it over. That is a
difference between beats, not a defect in a number, and no single `punish` figure
can say it.

Worth recording, since the "fix" was drafted before it was checked: `validate()`
asserts `cooldown >= punish`, and `gate_lunge` is authored `punish: 1.35,
cooldown: 1.35`. Raising that punish to 1.40 would have failed the project's own
validator on the way in.

The rest of the kit, from `K`: the parry is live `PARRY_WINDOW` 0.20 s from the
press inside a 45° cone, costs `PARRY_RECOVER` 0.42 s guardless when it misses,
and opens `RIPOSTE_WINDOW` 1.20 s of dash. The perfect dodge fires only when a
blow genuinely reached the hero inside `DODGE_GRACE` 0.30 s of the roll starting,
and pays `SLOWMO_SCALE` 0.34 for 0.55 s plus `FLURRY_WINDOW` 1.40 s of leaping
overhead.

**A starting hero holds 12 quarters** (`K.START_HEARTS` × `K.HEART`). The
Warden's beats take 3 and 4 of them; the Riven Knight's take 6. Floor 4 is two
blows from a hero who never bought a heart, and that is the ladder stated in one
number rather than a difficulty setting.

---

## 3. What a parry is worth, per beat

**The parry is the only thing that moves a boss** (`docs/BESTIARY.md` §3.6), and
what it moves is fixed: `Boss.stagger` spends two thirds of `K.PARRY_STAGGER`,
so the beat is cut into a **0.627 s** recovery and then opens its own authored
`punish` exactly as it would have. The reward is the fight's existing vocabulary,
brought forward — never a new opening.

Two consequences the design has to be built around, and neither is obvious from
reading `stagger()`:

**1. The window a parry buys is `COMMIT_TIME + recover − 0.627`, and the commit
half of that is the half everybody forgets.** `_commit()` sets
`_timer = _commit_seconds(_beat)` and *then* calls `_deliver_shape` — and for an
`arc` or a `slam`, `_deliver_shape` reaches `_land` → `DamageArea._deliver` →
the hero's `take_hit` → `HeroCombat.on_parried` → `Boss.stagger` **synchronously,
inside that same call**, two lines after the timer was written. `stagger`
overwrites `state` and `_timer` both. So the 0.22 s commit never runs either: a
parry on an `arc` or a `slam` skips the commit **as well as** the recover.

The two charges are the exception, and they are the exception in the other
direction. `_commit_seconds` returns `reach / speed + 0.05` for a
`SHAPE_CHARGE` — **0.90 s** for `bellows_charge` and **0.80 s** for `gate_lunge`
— and the blow does not land at the commit, it lands when the body arrives
partway through that travel. What a charge parry cancels is therefore the travel
that was *left*, which is bounded above by those numbers and is never the whole
of them.

| Beat | `recover` | Parry buys | Plus |
|---|---|---|---|
| `first_toll` | 1.15 | **+0.74 s** | — |
| `cistern_drop` | 1.10 | **+0.69 s** | — |
| `bellows_charge` | 1.20 | **+0.57 s** | the travel it had left, up to 0.90 s |
| `gate_lunge` | 1.05 | **+0.42 s** | the travel it had left, up to 0.80 s |
| `sluice_sweep` | 0.80 | **+0.39 s** | — |
| `slag_backhand` | 0.70 | +0.29 s | — |
| `riven_arc` | 0.65 | +0.24 s | — |
| the three `zone` beats | — | **nothing** | see below |
| the two `summon` beats | — | **nothing at all** | they deal no damage |

Read that as a curve and not as a cliff: **the parry's window narrows with depth
and never closes.** Floor 1's `cistern_drop` hands back 0.69 s, which is most of
a second and a whole extra light contact. Floor 4's `riven_arc` hands back
0.24 s, which is a third of that and still a real opening — the difference
between two contacts and two contacts with room to leave afterwards. Not quite
three to one across four floors is a good shape for that curve, and it is the
shape the beats already have — nobody has to author it.

**An earlier draft of this section said the opposite, and it was wrong twice
over.** It measured the window as `recover − 0.627`, which drops the commit from
every row, and it got +0.02 s on `riven_arc` — then built a punchline on the
rounding error: *"at floor 4 the parry stops being a window and becomes a
refusal."* +0.24 does not support that sentence and nothing else does either.
There is no floor at which the parry stops paying an opening. What is true, and
duller, is that the opening gets smaller as the beats get faster, so at floor 4
the damage refused and the 1.20 s riposte dash are the larger share of what the
press bought — but they were the larger share on floor 1 too, and the honest
version of the old claim is a change of proportion rather than a change of kind.

**2. A `zone` is very nearly unparryable into an opening — but "by construction"
was overstated, and here is the band where it stops being true.** `Boss._land`
passes the *disc centre* as the blow's origin for a zone, and
`HeroCombat._parried_body` looks for something with a `stagger()` within **1.4 m
of that origin**. Across the arena the boss is not within 1.4 m of a disc and
nothing is staggered — which is the case the design wants. At melee range it is:
the first disc of every zone is placed at the hero's own position, the Warden's
capsule radius is `height * 0.20` = **0.68 m**, so a hero pressed against it has
his centre about 0.98 m from the boss's. **Anywhere from roughly 0.98 m to 1.4 m
of the boss's centre, a parried disc does stagger it.** The scattered discs can
land inside that radius too, at random.

The second half is stronger but still not absolute. When a hero who has not moved
is caught by the disc drawn under him, the direction from the blow is zero and
both `parries()` and `blocks()` return false — **the shield does not answer a
pool you are standing in.** That is `K.flat`'s epsilon rather than an exact
comparison: it bails when the flat offset is under **0.01 m**, so it is "a hero
who has not moved a centimetre in the fuse's 1.1–1.3 s", not "a hero who happens
to be standing".

Neither of those is a bug to fix, and the beat's job survives both: the zone is
the beat the shield has no *reliable* answer to, and the roll does, which is why
every boss in the game has one. But **§6's per-beat advice must not be written as
if the code refused a zone parry**, because at contact range it does not. If a
guarantee is ever wanted rather than a tendency, it is one line — a
`shape == SHAPE_ZONE` bail at the top of `_parried_body`'s caller — and it should
be taken as a deliberate change with a director beat behind it, not assumed.

Which gives the rule the whole of §6 is built on, and it is one line:

> **A boss's `arc`, `slam` and `charge` are the shield's beats. Its `zone` is the
> roll's. Its `summon` is neither, and the punish it pays is the price of that.**

---

## 4. Timing, depth, and the 60% floor

**Boss beats do not scale with depth, and that is the design.**
`boss_db.gd`'s contract §3 is explicit: *`Prog.windup_scale` does not apply. The
tell is the fight. It is the same length on run one and run fifty.* A boss is
authored for exactly one floor, so a curve on top of it would be curving numbers
that already are that floor's numbers.

The 60% floor GDD §7 promises is `Prog.WINDUP_FLOOR = **0.6**`, and it applies to
`Enemy` — the generated roster, and the bodies a boss summons. Two numbers worth
having, because both are routinely mis-stated:

- `Prog.windup_scale(4) = **0.91**`. At the Chord Gate a roster body's wind-up is
  compressed by nine percent, not by forty. **The 0.6 clamp is never reached
  anywhere in the four authored floors** — it first engages at **floor 15** of the
  Long Descent (floor 14 computes 0.61; floor 15 computes 0.58 and is clamped).
- A boss's summoned adds *should* carry the boss's floor — `_shape_summon` sets
  `e.level` — but **they do not today**: `Enemy.spawn` has already added the child
  and run `_build_combat` before the level is written, so every chorister and
  every called wraith arrives with floor-1 stats (board card 22). Intended, a
  `call_the_iron` wraith is 35 quarters and 6 damage; built, it is 20 and 5.
  Nothing in §6 depends on the bug being fixed, but §6.4's balance note does.

**What stands in for the curve is authored compression across the four fights**,
and it should be checkable rather than felt. Same attack shape, floor 1 against
floor 4:

| Shape | Floor 1 | Floor 2 | Floor 3 | Floor 4 | F4 / F1 |
|---|---|---|---|---|---|
| `arc` | 1.05 | 0.72 | — | 0.62 | **59.0%** |
| `slam` | 1.30 | — | 1.20 | — | 92.3% |
| `charge` | — | 0.90 | — | 0.78 | 86.7% |
| `zone` | 0.95 | 1.15 | 1.00 | — | — |
| `summon` | — | — | 1.40 | 1.45 | — |

**That last column is not a 60% line, however much it looks like one, and an
earlier draft of this section read it as one.** GDD §7's promise — *the telegraph
never compresses past 60%* — is `Prog.WINDUP_FLOOR` clamping
`Prog.windup_scale(level)`, and what that curve does is compress **one authored
body as it descends floors**. `docs/PUZZLES.md` §7 states it in the only form
it has: *"it never compresses past 60% however deep the floor is."* Boss beats
have no depth axis at all — the first paragraph of this section is that fact, and
`boss.gd` reads `_beat["tell"]["time"]` raw, with no `Prog` anywhere near it. So
`riven_arc`'s 0.620 s measured against `sluice_sweep`'s 1.05 s is 59% of *a
different body, on a different floor, authored by a different hand*. There is no
promise in the project it can be past, and 0.63 is not a fix because there was
nothing to fix. **`riven_arc` stays at 0.62.**

The version of that mistake which got as far as a proposed `validate()`
assertion is worth naming so nobody re-proposes it: *no beat's tell under 60% of
the shallowest tell of the same attack shape*. That manufactures five per-shape
floors out of nothing, each anchored to whichever row happens to be shallowest
today, and every one of them moves the moment somebody retunes a **floor-1**
beat — an assertion that fires on an edit to a beat it is not about is worse than
no assertion, because the next agent will believe it is protecting something.
A contract stated as a number is only worth checking when the number means
something; this one would mean "the Warden's sweep, until it doesn't".

**What the F4 / F1 column actually is** is a taste measure — how much faster the
last fight reads than the first — and it should be read as one and never asserted
on. 59% on the arc is the intended shape of the ladder: the Chord Gate's cheapest
beat comes at you in six tenths of a second and floor 1's comes in a second, and
that is what floor 4 is for.

The zone row going *up* with depth is correct and not a slip: a zone's tell is
not its warning. The discs carry their own `fuse` (1.10 / 1.30 / 1.20 s) which is
drawn on the floor after the commit, so a zone's real read is tell + fuse —
2.05 s at the Cistern and 2.45 s at the Foundry.

---

## 5. The turn — one signal, four rooms

Every boss escalates once, at half health, and **the escalation is the room**.
Not a phase, not a bar, not a beat: `docs/OOT_CATALOGUE.md` §3 is emphatic that
not one Ocarina boss has a second health bar and that the change is always Ganon
ringing the floor with fire or Volvagia taking to the air, and
`docs/SCOPE.md` §6's one-phase cap (*"Three beats, one phase, hard cap"* — it is
in the risk table, not the manifest) turns out to be the design answer rather
than only the budget one.

**The mechanism, once, and it is more wiring than the first draft of this
section priced.** `BossArena` builds the seal and the cover posts off the row
today — but it has **no `_process`, no `_physics_process` and no reference to
the boss's health at all**, so "watches the boss's health" is new plumbing and
not a threshold read off a row. What it actually is: `_build_boss` connects
`(_boss as Enemy).health.damaged` (`HealthComponent` already emits it, and a
signal is right where a poll would be wrong — the fraction only moves when
something hits it), the handler reads `health.fraction()`, compares it to
`arena.turn.at`, sets a bool so it fires once, and dispatches on `turn.kind`.
That is a connect, a handler, a bool and four small effects — still small, but it
is four things and the §8 row should say four rather than "a threshold".

One threshold for all four bosses, `0.50`, because four thresholds is four
tunings nobody can compare against each other.

**And the signal has a name already: `Bus.boss_phase_changed(phase: int)`,
declared at `scripts/autoload/event_bus.gd:90` and emitted by nothing.** This
document has said "one signal" three times — the header, §0's third refusal and
this section's own title — without ever naming it, which is exactly how a
declared-and-dead signal stays dead. **The turn emits it**, `phase` 1, on the
frame it applies — that is what it was declared for, it costs one line, and it
gives the director an event to photograph either side of instead of diffing two
screenshots and hoping. It does **not** make the turn a phase: nothing listens
today, `pick_beat` never sees it, and §5's "what a turn may touch" list is
unchanged. If a later listener tries to change a move set off the back of it,
that listener is the amendment, not this emit.

**What a turn may touch: the fence radius, the cover posts, the room's light.**
Nothing else, ever. It may not touch a beat's numbers, the move set, `pick_beat`,
the health bar or the tint — every one of those is a second phase wearing a room.

**Four kinds, one per boss, and that is the cap.** A fifth is a proposal to make
the room a mechanic, and it goes to the owner rather than into this table.

| Boss | Kind | The change | What it costs |
|---|---|---|---|
| Warden | `shrink` | the fence walks in: 11.0 → 8.5 m | a second seal ring raised at the smaller radius, `Boss.set_arena_radius()`, **and the annulus guard below** — the most expensive of the four |
| Slag Ogre | `topple` | two of three slag pillars slump: `cover_count` 3 → 1 | `queue_free` on two named children. Genuinely cheap: `_build_cover` names them `"Cover%d"` |
| Bellwake | `douse` | the Choir's sconces go out | **no handle exists** — see below. This is the one with an open question in it, not a cost |
| Riven Knight | `keystone` | the broken keystone drops into the middle of the arena | one `StaticBody3D` with a `HookTarget` on it. Cheap and correct — but see §6.4 on when it exists |

Four implementation notes an implementer should not have to re-derive, and the
first two are the ones that make `shrink` the expensive turn rather than the
obvious one:

- **`shrink` needs `Boss.arena_radius()` to follow it.** `_shape_zone` scatters
  its discs inside `arena_radius() - radius`, read off the row, so a Warden whose
  fence has moved would still be drowning the floor of the room it used to be in.
  Add a `set_arena_radius()` beside the `set_arena_center()` the arena already
  calls, and have the turn call it. The seal itself is easiest as a *second*
  fence built at 8.5 m and raised — scaling a ring of fixed-width panels leaves
  daylight at every joint, which is the bug `boss_arena.gd`'s own comment records
  having shipped once already.
- **`shrink` must not raise a wall through the hero, and by default it would.**
  The seal is a `StaticBody3D` on `K.L_WORLD` — solid, and raised by moving a
  node, not by enabling a shape. Raising a second one at 8.5 m while the hero is
  standing at 9–11 m either shuts him into an annulus he cannot leave or shoves
  him out through the outer fence, and **the Warden's turn is aimed at precisely
  that player**: the whole argument for `shrink` (§6.1) is that it takes the far
  half of the arena away from someone who has been kiting in it. The fix is one
  of two, and either is fine as long as one of them is there:
  - *Pull, then raise.* Before `_move_seal`, tween any body in `K.L_PLAYER`
    that is outside the new radius to a point just inside it, then raise. Reads
    as the water pulling him in with it, which is also the fiction.
  - *Refuse, then retry.* Do not raise while a player body is in the annulus;
    re-check on the next `damaged` and raise the first frame the annulus is
    clear. Cheaper, and it costs a moment of the turn's timing.

  The pull is the better one — the refusal hands a kiting player a way to
  postpone the turn indefinitely, which is the behaviour the turn exists to
  punish — but **the unguarded version is not an option**, and §9 has a beat for
  it.
- **`douse` is the one turn that needs a handle `BossArena` does not have**, and
  it has no fallback path in code either. A generated room's lights belong to the
  room. If they cannot be reached from the arena, the fallback is `shrink` to
  10.0 m — which then inherits the annulus guard above, so the fallback is not
  free. Try `douse` first, because it is the only turn of the four that costs no
  geometry and it is the one the fiction is asking for.
- **`keystone` is the cheap one and it is also the late one.** One body, one
  `HookTarget`, no guard needed — the arena has 12.5 m of radius and the mass is
  3 m across at the centre, where nothing stands. What it costs is elsewhere: see
  §6.4 on the first sixty-four quarters.

**Why `douse` is safe at all**, since GDD pillar 5 says a silhouette you cannot
read is a bug and not atmosphere: the beats' floor markers are built
`SHADING_MODE_UNSHADED` precisely so that *"a warning that dims where the room is
dim is a warning you miss where you most need it"* (`boss.gd`, `_mark_mat`), and
the Bellwake's own body is the most emissive of the four. The turn cashes in a
decision the code already made. **The director's job is to photograph it and
prove the claim**, not to take this paragraph's word for it.

---

## 6. The four fights

### 6.1 The Cistern Warden — **Reflect**

> **The blow you were told to walk away from is the blow you can catch.**

Floor 1. The player is carrying the sword, the shield and the rope, and has never
been asked to use the shield for anything but standing still.

**The beat that carries it: `cistern_drop`.** It is the only beat in the fight
whose damage band the player *chooses* to stand in — a donut, safe under the
chin at 2.1 m, lethal out to 6.2 m — so it is the only beat where "take the blow
on the shield" is a decision rather than a consequence of being caught.

**What actually goes back is the force, not an object, and that is not a
compromise — it is the only version of reflect this game can build.** Nothing in
the five attack shapes throws anything: `arc` is a cone resolved at the commit,
`slam` is a ring, `charge` is the body itself, `zone` marks the floor and
`summon` spawns. A hurled, blockable, returning piece of debris needs a **sixth
attack shape**, a sixth arm on `_deliver_shape`, and a projectile with an owner,
a flight path and a return — against a header that says there is no thirteenth
beat and no sixth shape. **Say no here.** Note that the game gets
reflect-with-an-object anyway and cheaper: `docs/BESTIARY.md` §3 behaviour 1, the
Thrower, is a committed goblin behaviour and already on the manifest. The Warden
does not need to be the one that throws.

| | Tell | Commit | Recover | Punish | Cooldown |
|---|---|---|---|---|---|
| `sluice_sweep` | 1.05 | 0.22 | 0.80 | 1.10 → **2 contacts** | 1.10 |
| `cistern_drop` | 1.30 | 0.22 | 1.10 | 1.60 → **3, the finisher lands** | 1.60 |
| `drown_pool` | 0.95 (+1.10 fuse) | 0.22 | 0.55 | 1.35 → 2, and **3** counting the recover (§2) | 1.60 |

Depth: none. Floor 1 numbers are the authored numbers (§4), and the 60% floor is
`Prog`'s curve on the generated roster — not a line these beats can be measured
against at all (§4).

**Three telegraphs, three pictures.** One arm hauled back over the shoulder,
green from the elbow out, with a 150°-wide *fan* on the floor in front of it. Both fists
locked overhead and dead still — the only moment it is taller than it walks —
pale, with a *ring* on the floor that has a hole in the middle. A hard sideways
cant and a flat palm at the floor, cold blue, with **no mark at all** until the
commit, when two discs bloom under the hero's feet and grow for a second before
they burst. Rear/green/fan, rise/white/ring, tilt/blue/nothing: no two share a
pose, a colour or a mark.

**The answer: the shield, and the second way over is to walk toward it.**

- *Fast:* parry `cistern_drop` from inside the ring band. It opens the beat's
  1.60 s punish **0.69 s** early — the commit and most of the recover, §3 — and
  hands over a 1.20 s riposte dash on top. The best single opening on floor 1,
  and the second-widest fixed parry window in the game behind the Bellwake's
  `first_toll`.
- *Worse, and always available:* step inside 2.1 m and take nothing at all. The
  Warden's arena has no cover for exactly this reason; its own row says a pillar
  here would teach the player to solve beat two by hiding, and beat two's answer
  is to walk into it. **The inside is not a rest position** — `sluice_sweep`
  reaches 4.6 m and `drown_pool`'s first disc is drawn wherever the hero is
  standing — so the safe answer costs you the next beat's positioning, which is
  what makes the greedy one worth learning.

**Parry and dodge, per beat.** `sluice_sweep`: parryable, buys **0.39 s**, which
is a whole extra light contact and not just a riposte; rolling is still the
ordinary answer and the roll goes *backwards*, not sideways — the cone is 150°
wide and, since card 21, the mark on the floor says so. `cistern_drop`: the fight's
parry, above. `drown_pool`: **roll, always** — a parried disc almost never
staggers anything, because the origin the parry looks from is the disc centre and
not the body (§3), and a disc centred on a hero who has not moved a centimetre is
not even blocked. *Almost*: inside about 1.4 m of the Warden it does stagger, so
a hero who parries a pool while standing on the boss will occasionally get an
opening the rest of the fight is not teaching him to expect. That is a quirk to
photograph, not a rule to build on.

**The turn, at 24 of 48 quarters: `shrink`, 11.0 → 8.5 m.** The intake it has
been guarding for four hundred years finally gives, the standing water drops, and
the fence walks in two and a half metres. Everything that follows is arithmetic
already in the table, not a new rule: past 7.5 m `drown_pool` is the only
eligible beat, and after the turn there is barely anywhere past 7.5 m to stand;
the scatter ring for those discs closes from 8.4 m to 5.9 m so the floor the
player has left is the floor that gets drowned; and the donut's 6.2 m outer ring
becomes most of the room, so *walk toward it* stops being the clever answer and
becomes the only one. **No new beat, no number in the move set touched.**

**The row.** Only `arena` changes; every other key stays exactly where it is.

```gdscript
"arena": {
	"radius": 11.0,
	# No cover, deliberately. This is the first boss in the game and the
	# lesson is *read the tell*, not *find the pillar*.
	"cover": false, "cover_count": 0,
	# The turn (docs/BOSSES.md §5). The intake gives and the room closes in:
	# above 7.5 m `drown_pool` is the only beat that qualifies, so taking the
	# far half of the arena away is how the fight stops being kiteable without
	# a fourth beat and without touching a number in the move set.
	"turn": {"at": 0.50, "kind": &"shrink", "radius": 8.5},
},
```

---

### 6.2 The Slag Ogre — **Receptacle**

> **The intake is open for nine tenths of a second, and one arrow in it is the
> whole charge.**

Floor 2. The player is carrying **the Bow**, taken off the Warden, and the
Foundry is the floor that is about it (`docs/PUZZLES.md` §1).

**The beat that carries it: `bellows_charge`.** It is the beat with the widest
`min_range` in the game — 4.5 m, against `gate_lunge`'s 1.0 m, which is the only
other one — so it is the beat that *happens where the bow lives*: it cannot be
thrown at contact range, and the player it is thrown at is by definition standing
where a bow is the weapon in hand. King Dodongo inhales and you throw a bomb into
the mouth; the Ogre lights the bellows and you put an arrow in them.

**The rule, exactly, so nobody has to derive it — and read the state, because it
is the whole design:**

> While `bellows_charge` is in `State.STRIKE` **with `_charging` true** — that is,
> after the commit, while eleven metres of ogre are actually moving — a `Hit`
> whose `kind` is `Hit.ARROW` or `Hit.ARROW_FIRE` calls
> `stagger(hit.from, K.PARRY_STAGGER, 0.0)` instead of falling through to the
> ordinary poise path. **Not during the tell.**

`Boss._on_damaged` already receives the whole `Hit`, `Hit.kind` already
distinguishes an arrow from a sword, and `state` and `_charging` are both fields
on the same object — this is still one `if` in a function that exists. The
consequences are all the fight's own vocabulary, and they are the *parry's*
vocabulary specifically: `stagger` already calls `_end_charge()`, so the charge
stops dead where the arrow found it; the body drops into `RECOVER` for 0.627 s;
and then the beat's authored **1.70 s** punish opens with `punish_opened` exactly
as it would have. `beat_committed` fires normally, because the beat committed.

**Why the tell is the wrong window, which is where an earlier draft of this
section had it.** `boss.gd`'s poise comment gives two grounds for refusing every
interruption, not one: *a beat the player can interrupt is a beat they can
delete*, **and** *a tell that never lands makes the telegraph a lie*. An
arrow-into-the-tell answers the first — the punish is paid in full and
immediately — and simply ignores the second. It also breaks the scoping
`docs/BESTIARY.md` §3.6 uses to license the parry at all, which is **ordering**:
*"safe precisely because the parry can only be thrown after the boss has
committed."* And it puts the project in the position of granting an arrow a
tell-cut that §6.4 approvingly records `Boss.freeze` **refusing the hookshot** —
*"a barb that could cut a tell short would let the player delete a beat they were
supposed to read."* Two items, one rule, opposite answers, scoped by which item
is holding it. That is not a design; that is an exception with a name on it.

**Scoped to the travel instead, every one of those objections goes away**, and
none of the fight's value does. The tell lands: the ogre commits, the lane is
real, the eleven metres begin. The player is answering something already in the
air, which is the parry's exact shape and §3.6's exact licence. And the read is
*better*, not worse — a tell you shoot on sight is a reflex, a charge you shoot
while it crosses the floor at you is a nerve test with a counted resource on it.
What keeps it from becoming *"the bow cancels bosses"* is unchanged and now
sharper: one beat on one boss, and the beat has to have started.

**The intake is the charge**, and the pull-quote is not being retrofitted to say
so — `_commit_seconds` for `bellows_charge` is `11.0 / 13.0 + 0.05` = **0.90 s**,
which is the travel time, and it is the same nine tenths of a second the tell
takes. The bellows are what drives the run; the run is the window.

**The receptacle is a window in time, not a hitbox in space**, and that is
deliberate. This project has no per-limb hitboxes — a boss does not even have a
contact hitbox — and adding one is a new system, which `docs/SCOPE.md` §4.3's
second question refuses. There is no aim gate either, and with the rule scoped to
the travel it does not need one: the thing you are shooting is a body crossing
the floor at 13 m/s, and geometry supplies what a cone check would have. What the
player reads is the commit itself — the whole body lit RUST, the lane drawn
forward, the bellows-scar the brightest line on it.

| | Tell | Commit | Recover | Punish | Cooldown |
|---|---|---|---|---|---|
| `bellows_charge` | 0.90 | **0.90 travel** (`11.0 / 13.0 + 0.05`) | 1.20 | 1.70 → **3 contacts** | 1.70 |
| `slag_backhand` | 0.72 | 0.22 | 0.70 | 1.00 → 2 | 1.00 |
| `tap_the_ladle` | 1.15 (+1.30 fuse) | 0.22 | 0.90 | 1.45 → **3** | 1.70 |

Depth: none, per §4. The authored compression from floor 1 is 86.7% on the charge
and 68.6% on the arc — a taste measure of how much faster this fight reads than
the Cistern, and not a line anything is "clear of" (§4).

**Three telegraphs.** A dropped head and a planted back foot with one hard orange
line down the body and a **narrow 3 m lane** drawn forward — the tell is a
direction, which no other tell in this fight is, and it is a direction because
the answer to it happens *along* that lane rather than at its start. A fist
cocked behind the head,
the cooled crust splitting red along the knuckles, and a **190° fan** that wraps
past both shoulders: the shortest tell in the fight and the widest arc in the
game. A squat — the only time it is shorter than the hero — white-hot, with **no
mark until the commit**, when three rings burn into the flagstones on a 1.30 s
fuse. Tilt/rust/narrow lane, rear/red/wide fan, crouch/white/nothing.

**The answer: an arrow, and there are two other ways over the wall.**

- *Fast:* the arrow in the intake, thrown into the charge and not into the
  wind-up. It costs one arrow and stops the fight's hardest beat eleven metres
  short of wherever it was going, paying the 1.70 s punish on the spot.
- *Worse, and free:* sidestep and hit the back. The 1.70 s punish is the longest
  in the fight for exactly this reason — the row says it overshoots and has to
  turn around — and the beat's own comment calls sidestep-and-hit-the-back the
  intended answer.
- *Worse still, and already built:* put a slag pillar in the lane.
  `_advance_charge` ends the commit on `is_on_wall()` and the punish still opens,
  so a charge into cover is a charge that bought the player a window for nothing.
  This is what the arena's three pillars are for and it is live code today.

**Parry and dodge.** `bellows_charge` is the **hardest and richest parry in the
game**: the blow lands when the body arrives, so the timing depends on where the
player is standing — at 13 m/s a 0.20 s window is ±2.6 m of position error — and
landing it calls `_end_charge()`, stopping eleven metres of ogre dead and opening
0.57 s early on top of the 1.70, **plus whatever travel was left of the 0.90 s**.
It is the same window the arrow buys, bought with timing instead of ammunition,
and the two answers being the same shape is the point rather than a duplication.
`slag_backhand` is a 190° cone at 4.2 m, so it cannot be side-stepped: the answer
is backwards past 4.2 m, a roll through it for the perfect dodge, or the shield —
and the parry there is worth **0.29 s**, which is small but is a real extra
contact, so throw it for the opening as well as for the refusal.
`tap_the_ladle`: roll, and walk out early; three discs on a 1.30 s fuse is the
most floor-reading the game asks for anywhere.

**The turn, at 36 of 72 quarters: `topple`, cover 3 → 1.** The crucible above the
arena lets go and two of the three slag pillars slump into puddles that are no
longer tall enough to break a lane. The fight's own decision — *spend a pillar or
take the charge* — gets scarcer rather than louder, and the arrow answer and the
sidestep are both untouched, so no answer is removed. **One loop over named
children; no beat changes.**

**The row.**

```gdscript
"arena": {
	"radius": 12.0,
	# Three slag pillars, and they are load-bearing design rather than set
	# dressing: this is the fight that introduces `charge`, and a charge lane
	# with nothing to break it is a fight decided by footspeed.
	"cover": true, "cover_count": 3,
	# The turn (docs/BOSSES.md §5). Two pillars go and one stays: the charge's
	# cheapest answer gets rarer without any of its answers being deleted --
	# the arrow into the intake and the sidestep are both untouched.
	"turn": {"at": 0.50, "kind": &"topple", "cover_count": 1},
},
```

---

### 6.3 The Bellwake — **Exposed weak point, on a timer**

> **It sings through the choir it calls, and the Burst is the only thing that
> takes a chorus out in one breath.**

Floor 3. The player is carrying **the Burst**, taken off the Slag Ogre, and the
Choir is the floor that is about it.

**`docs/BESTIARY.md` §5 says "it anchors to a resonating pillar; Burst the pillar
and the core is open until it finds another". That cannot be built, and it should
not be.** Three reasons, in increasing order of how much they matter:

1. **There is no pillar.** The Bellwake's arena is authored `cover: false` and
   its row says why: beat one is a ring that fills the arena, and a pillar would
   turn *the note reaches everywhere* into *stand behind the pillar*.
2. **A pillar would not even do that.** `_shape_slam` is a pure distance query
   and ignores geometry, so a player sheltering behind a pillar would take
   `first_toll` through it. That is a telegraph that teaches a false rule, which
   is the same failure mode board card 21 recorded for the arc's bounding box —
   and that one is now fixed, so this is the shape of defect to keep watching for
   rather than one the game still ships.
3. **The pillar is already spoken for, one branch away.** The floor-3 *miniboss*
   — the Second Voice, `docs/PUZZLES.md` §7 — is *"it anchors to a resonating
   pillar and cannot be touched while the pillar sings. Burst the pillar."*
   Giving the boss the same wall is the floor asking one question twice, which is
   §4.3's rule applied at floor scale instead of beat scale.

**The beat that carries it, unchanged: `hushing_choir`.** The shell is the
choristers. The intended sentence is Barinade's, exactly — strip the shell, hit
the thing under it before the shell reforms — and **two of the three words in it
are not currently true, so read the next two paragraphs before building to it.**

**"The core is open" is not a state the code has.** `Boss._on_damaged` has no
invulnerability branch and no add-count check; it scales the impact and leaves
the state alone, and that is the whole of it. The Bellwake's core is open before
the choir is called, open while two choristers are standing on the floor, and
open if the player never fires the Burst at all. **So the Burst removes two
skeletons and opens nothing** — there is no wall, and this section should not be
read as if there were one.

The version with a wall in it is `if _summons_alive() > 0: refuse the damage`,
five lines in the function that already receives the `Hit`. It is refused here,
and the reason is not that it is hard: a boss that cannot be hurt while its adds
live is **a new mechanic**, it is the second one in this document after the
receptacle, and `docs/SCOPE.md` §1's `New mechanics 2` is the row §4.2 names as
the one to defend. A fight shape that costs a manifest row is not the "naming one
per boss must cost nothing" claim §0 makes; it is a different claim. §7 records
what taking the free option costs the diagonal, and it is not nothing.

**"Before the shell reforms" is not a 6.00 s clock either.** `hushing_choir`
carries `weight: 1.0` against `first_toll`'s 3.0 and `undertow`'s 3.0, so when
the cooldown expires the choir is a **1-in-7 roll, about 14%** — and the very
first roll after it is nearer **3%**, because `REPEAT_WEIGHT` (0.22) softens the
beat that just played. The shell does not come back on a timer. It comes back
when the dice say so, and most of the time they do not.

**The timer, worked in seconds**, because "on a timer" is only a design if the
seconds exist — and these are the seconds that *do*:

- Commit → 1.30 s recover → **2.00 s punish**, the longest window in the game.
- The two choristers appear 8.0 m from the boss at the commit and walk at 2.2 m/s
  with a 1.7 m reach (`skeleton`), so 6.3 m of walking: a hero standing on the
  boss has **2.86 s** before the first one is on him. The punish opens 1.52 s
  after the commit and shuts at 3.52 s, so the choir arrives about **six tenths
  of a second before the window closes**. The window is free and then it is not.
- After the punish, 4.00 s of cooldown remain. **That is the strip window**: six
  seconds from the moment the boss goes open, in which the player has to spend
  the free hits *and* clear two bodies, and only one thing in the kit does both.

**Why the Burst and not the sword**, given that neither of them opens anything.
At floor 3 the Burst is the player's only area answer, and the choristers
converge on the hero — which is what makes them a single target rather than two.
Clearing them with the blade costs the punish window the clearing was supposed to
protect, and that trade is real whether or not a damage gate ever exists. It is a
**pressure** answer rather than a **wall** answer, and §7 grades it as one.

| | Tell | Commit | Recover | Punish | Cooldown |
|---|---|---|---|---|---|
| `first_toll` | 1.20 | 0.22 | 1.15 | 1.55 → **3 contacts** | 1.55 |
| `hushing_choir` | 1.40 | 0.22 | 1.30 | 2.00 → **3** | 6.00 |
| `undertow` | 1.00 (+1.20 fuse) | 0.22 | 0.60 | 1.20 → 2 | 1.40 |

Depth: none. 1.40 s is the longest tell in the game and 1.20 s is the longest
`slam` tell after the Warden's — floor 3 is *slower* than floor 2 on purpose,
because what got harder is the number of things on the floor, not the reading.

**Three telegraphs.** It rises a body length with its arms folded in and scratches
a violet ring the width of the arena onto the floor — **and the ring tightens as
the note gathers**, so the tell is not "something is coming" but a drawing of
exactly how far. It opens both arms to their span and holds perfectly still while
two blue outlines fade up against the wall a beat before they have bodies. It
cants sideways and points one long hand at the floor, and a pale hairline circle
scratches itself in under the hero and hums. Rise/violet/tightening ring,
spread/blue/no mark, tilt/white/no mark until the commit.

**The answer: the Burst, and the second way over is to let them live.**

- *Fast:* one blast into the pair as they close, then back onto the boss inside
  the 6 s. What that buys is the rest of the strip window spent on the boss
  instead of on two skeletons — not access to a core that was shut, because it
  never was.
- *Worse, and it is already in the code:* clear nothing. `cap` is 4, so the
  second cast tops the choir out and the third is **refused** — `Boss._choose`
  throws a capped summon away and re-rolls, and `REPEAT_WEIGHT` makes the second
  roll something else almost every time. A player who tanks the choir converts
  the Bellwake's rarest beat into a beat it can no longer throw, and pays for it
  with four bodies in a 13 m arena that has a 7.5 m ring slam in it. That is the
  expensive answer §4.2 and OOT pattern 10 ask for, and it costs nothing to
  build because it is the cap doing its job.

Worth knowing and not guessing: **the boss's own beats never hurt its adds.**
`_victims()` returns the player group only, so nobody should design around
walking a chorister into `first_toll`.

**Parry and dodge.** `first_toll` is parryable from inside 7.5 m and buys
**0.74 s**, the widest fixed parry window in the game
— the deliberate mirror of the Warden's donut, where the Warden asks you to step
*in* and the Bellwake asks you to step *out*, and both can be answered with the
shield instead by the player who would rather stand and read.
`hushing_choir` **cannot be parried, blocked, dodged or interrupted** — it deals
no damage, so nothing ever reaches the hero to react to. That is the single
reason this boss's answer is an area weapon rather than a timing read, and it is
what stops the four fights from all being *parry the big one*. `undertow`: one
disc, drawn under the hero, on a 1.20 s fuse — roll, and note that standing still
behind a raised shield takes all five quarters (§3).

**The turn, at 48 of 96 quarters: `douse`.** The Choir's sconces go out. The room
is read by the boss's own violet emission and by the unshaded marks on the floor,
which is the reason the marks were built unshaded in the first place. The fight's
numbers do not move at all; what changes is that the tightening ring of
`first_toll` and the hairline circle of `undertow` become the *only* things in the
room with edges. **If the arena cannot reach the room's lights, fall back to
`shrink` at 10.0 m and lose nothing structural** (§5).

**The row.**

```gdscript
"arena": {
	"radius": 13.0,
	# The largest arena and no cover. Beat one is a ring that fills it, and a
	# pillar would turn "the note reaches everywhere" into "stand behind the
	# pillar" -- which `_shape_slam` would not even honour, since it is a
	# distance query. See docs/BOSSES.md §6.3: this is also why the boss's
	# weak point is the CHOIR and not a pillar. The pillar belongs to floor
	# 3's miniboss (docs/PUZZLES.md §7).
	"cover": false, "cover_count": 0,
	# The turn (docs/BOSSES.md §5). The sconces go out and the room is read
	# off the boss's own light and the beats' own marks, which are UNSHADED
	# for exactly this reason (`Boss._mark_mat`). Fallback if the arena
	# cannot reach the room's lights: {"kind": &"shrink", "radius": 10.0}.
	"turn": {"at": 0.50, "kind": &"douse", "energy": 0.15},
},
```

---

### 6.4 The Riven Knight — **Positional: it holds the far side**

> **It has been holding this door for four hundred years, and the only thing in
> the kit that crosses a room in one press is the thing the Bellwake dropped.**

Floor 4. The player is carrying **the Hookshot**.

**Disarm — Ocarina's fifth shape — is not built, and this is the refusal.**
`docs/BESTIARY.md` §5 already hedges it (*"belongs to the Riven Knight at the
Chord Gate or to nothing at all"*), and it is *nothing at all*, because a boss
that takes the sword away needs four things and every one of them is on a
ceiling:

1. A beat that disarms — a **fourth beat**, or a replaced one. Capped at three.
2. A hero state with no sword — a loadout state, a HUD state, the weapon ring and
   the pouch's paper doll, all of which read `Game.armament()`.
3. A way to get it back — a prop, in an arena that is authored as a circle.
4. A fight that is answerable *without* it — and the three items that are not the
   sword all spend **counted charges**. A hero out of arrows and out of charges,
   with no sword, is a hero who is stuck, and GDD pillar 2 says a cautious player
   is never blocked.

So the Knight is Ocarina's shape 4, positional, and **§7 records what that costs
the set honestly.** The fiction keeps the inversion: `call_the_iron` is *"the one
beat where it is not holding its weapon"* — the boss disarms itself, and the two
wraiths are the price it pays for the window. That is a sentence, not a mechanic,
and it is labelled as one here so nobody builds it by accident.

**The beat that carries it: `gate_lunge`.** Twelve metres at 16 m/s down a 1.2 m
lane, on the shortest tell of the three. It is the beat that says *you are not
where you need to be*, and the hookshot is the item whose whole verb is that
sentence (GDD §5.2).

| | Tell | Commit | Recover | Punish | Cooldown |
|---|---|---|---|---|---|
| `gate_lunge` | 0.78 | **0.80 travel** (`12.0 / 16.0 + 0.05`) | 1.05 | 1.35 → 2, and **3** counting the recover — but see §2 | 1.35 |
| `riven_arc` | 0.62 | 0.22 | 0.65 | 0.90 → 2 | 0.90 |
| `call_the_iron` | 1.45 | 0.22 | 1.40 | 2.10 → **3** | 8.00 |

`gate_lunge` is the beat §2's caveat is about: 1.05 + 1.35 = 2.40 s of rooted,
hittable boss, which clears the 1.37 s finisher line twice over — and the boss
spends the first of those seconds twelve metres away, because it just charged
past. The recover is real time and it is time the player walks in. Two contacts
is the honest expectation and the third is what closing fast buys.

Depth: none. The authored compression against floor 1 is 86.7% on the charge and
**59.0% on the arc** — which is a taste measure and not a 60% breach, because
GDD §7's floor is `Prog`'s per-depth curve on the generated roster and no boss
beat is on it (§4). `riven_arc` stays at 0.62.

**Three telegraphs.** It sinks onto its back leg and levels the blade at hip
height with one red line running the length of it — **the line is the lane**, and
it is the shortest tell of the three and tells you the most. The sword comes over
the shoulder in a single frame and then *holds*, dead still, with the split down
the breastplate glowing through the gap in the plate — it is the stillness that
reads, not the movement. It plants the sword point-down and opens both gauntlets
away from the hilt while a horn carries. Crouch/red/narrow lane, rear/rust/140°
fan, spread/violet/no mark.

**The answer: the hookshot, and there are two other ways over the wall.**

- *Fast:* the keystone. After the turn there is a `HookTarget` at the centre of
  the arena, and a hookshot to it is the fastest exit from a 1.2 m lane in the
  game — and the fastest way back in afterwards, which is the half that makes it
  a reposition rather than an escape. **"After the turn" is doing a great deal of
  work in that sentence, and it should be said out loud: the keystone is the only
  `HookTarget` in the arena, the turn puts it there at half health, and the
  Knight's bar is 128 quarters. For the first 64 of them — half the fight, and
  the half in which the player is learning it — the item the whole floor-4
  diagonal is built on has nothing in the room to attach to.** The hookshot is
  not useless before the turn (it is still a freeze on a wraith and still a pull
  to the pylons if the pylons ever carry a target), but the *answer to this fight*
  arrives in the second half of it. §7 counts that against the diagonal, and so
  should anyone reading this section for a build order.
- *Worse, and free:* sidestep. A 1.2 m lane at 16 m/s is readable off a 0.78 s
  tell and the roll is faster than the run.
- *Worse still, and built:* the two broken gate pylons. `is_on_wall()` ends the
  commit and the punish still opens, which is what `cover_count: 2` is for.

**The hookshot does nothing to the boss itself, and that is on purpose.**
`Boss.freeze` is overridden to a `hit_armor` clang and no state change — a barb
that could cut a tell short would let the player delete a beat they were supposed
to read, and one that could cut a *punish* short would take the window away from
them. So the hookshot answers this fight through the **room**, never through the
body. That is the weakest link in the diagonal and §7 says so.

**Parry and dodge.** `gate_lunge` is the game's hardest parry — the fastest
charge on the shortest tell — and it pays 0.42 s plus whatever was left of
**0.80 s** of travel. `riven_arc` is the beat that shows what the parry becomes
at floor 4, and what it becomes is *smaller, not different*: **0.24 s** of window
— a third of what `cistern_drop` hands over on floor 1, still an extra contact,
and on top of it six quarters of damage refused and a 1.20 s dash into a body
that has just spent its fastest move. The parry never stops being worth throwing;
it stops being worth throwing *for the window alone*. `call_the_iron` is
unparryable and undodgeable, like every summon, and pays the longest punish in
the game (2.10 s) for it.

**Balance note, and it is the honest one about this fight.** Intended, the two
called wraiths are 35 quarters and 6 damage each at floor 4 — **55% of the boss's
own 128-quarter bar, standing next to it.** Built, they are 20 and 5, because of
board card 22. Whichever number is true, `cap: 2` and an 8.00 s cooldown are the
only things holding the fight's length down, and this is the beat to watch when
the Chord Gate is first played end to end.

**The turn, at 64 of 128 quarters: `keystone`.** The Chord Gate's broken keystone
comes down into the middle of the arena — one mass about 3 m across, with a
`HookTarget` at 2.4 m on it. Three consequences, all of them already in the code:
`gate_lunge` can no longer cross the middle of the room, because
`_advance_charge` ends the commit on a wall and the punish opens anyway; the
arena becomes an annulus, so the called wraiths path around it and the fight
stops being a straight line; and the fastest exit from the lane is now in the
centre of the room instead of at its edge. **It uses a `HookTarget`, which is the
firer's contract and not the `HookRing` puzzle atom** (`hook_ring.gd`'s own
header: *"this atom is a `HookTarget` that happens to count, and every other ring
in the game is one that does not"*), so **`Puzzle atoms 9` does not move.**

The one thing a director must check about this turn: the boss must not stall
behind the keystone. `_tick_chase` steers straight at the hero and slides, which
should be enough, and "should be enough" is not the bar this repo uses.

**The row.**

```gdscript
"arena": {
	"radius": 12.5,
	# Two broken gate pylons. Same reason the Foundry has cover: this is the
	# other charge in the game, and it is faster and longer.
	"cover": true, "cover_count": 2,
	# The turn (docs/BOSSES.md §5). The keystone drops into the middle: the
	# 12 m lunge can no longer cross the room (`is_on_wall` ends the commit
	# and the punish still opens), and the hookshot gets an anchor at the
	# centre of the arena. `hook` is a HookTarget -- the firer's contract, not
	# the HookRing puzzle atom -- so `Puzzle atoms 9` does not move.
	"turn": {"at": 0.50, "kind": &"keystone", "radius": 1.5, "hook_y": 2.4},
},
```

---

## 7. The diagonal, walked

`docs/BESTIARY.md` §5 claims each boss's fight shape is answered by the item the
*previous* boss dropped, the same way `docs/PUZZLES.md` §1 claims it for the
floors. Walked one floor at a time against what the code actually does,
**it holds once cleanly, once partially, and twice not at all** — and an earlier
draft of this section said "three and a half times out of four", which was the
count you get by grading floors 1 and 3 on their prose instead of on their
`if`s.

| Floor | Carrying | Fight shape | Answered by | Through | Holds? |
|---|---|---|---|---|---|
| 1 Warden | shield (always owned) | Reflect | the parry on `cistern_drop` | **the body** | the verb is universal |
| 2 Slag Ogre | **Bow** ← Warden | Receptacle | an arrow into `bellows_charge`'s travel | **the body** | **yes** |
| 3 Bellwake | **Burst** ← Ogre | Exposed weak point on a timer | a blast into the choir | **the adds** | no wall today |
| 4 Riven Knight | **Hookshot** ← Bellwake | Positional | the keystone anchor | **the room** | furniture, and late |

**Floor 2 is the claim in its strong form, and it is the only one.** Four clauses
have to hold — the item acts on the boss itself, on a specific beat, with a
visible cue, and the boss is measurably worse off. The arrow into the charge
satisfies all four, and it does so through a branch that names one beat by
`shape` and one hit by `kind`. This is the shape the other three get measured
against.

**Floor 1 is a teaching diagonal, not a mechanical one, and two of those four
clauses fail.** What the design substitutes for "the shield answers the Warden"
is `HeroCombat.on_parried` → `Boss.stagger`, and that path is **identical on all
twelve boss beats and on every ordinary enemy in the game**. Nothing in it knows
`cistern_drop` from `sluice_sweep`, or the Warden from a goblin — so "on a
specific beat" is simply false, and "the item acts on the boss itself" is true
only in the sense in which it is true of a skeleton. What *is* true, and is worth
having, is that `cistern_drop` is the beat best shaped to **teach** the parry: a
donut whose safe band the player chooses to stand in, on the first boss in the
game, with the widest window on floor 1 behind it (§3). Teaching is a real job.
It is not the same job as the other rows in this table, and the table should not
have implied it was.

The alternative — giving `cistern_drop` a parry reward the other eleven beats do
not get, a longer stagger or a beat-specific opening — is rejected, and not on
cost: §3's whole rule is that a parry brings forward *the beat's own authored
punish* and never invents an opening, and a per-beat parry bonus would be the
second reward vocabulary the fight has. Floor 1 keeps the universal verb and this
row keeps the honest grade.

**Floor 3 has no wall at all today**, which is the same grade floor 4 gets and
for a plainer reason. §6.3 works it: `Boss._on_damaged` has no invulnerability
branch and no add-count check, so the Bellwake's core is open before the choir is
called, during it, and if the Burst is never fired. The Burst removes two
skeletons out of a 2.00 s punish window and **opens nothing**. That is a real
reason to be carrying it — two bodies converging on you inside the longest window
in the game is pressure the blade cannot clear without spending the window — but
it is pressure, not a lock, and "exposed weak point on a timer" describes a lock.
The gate that would make it true is five lines and it is refused in §6.3 on the
`New mechanics 2` row, deliberately and with the cost named.

**Floor 4 breaks quietly, and in two places rather than one.** The hookshot
answers the Riven Knight through *arena furniture the arena did not have until
half health* — and for the first 64 of 128 quarters it does not have it at all
(§6.4), so the item arrives as an answer only once the fight is half over. The
Knight would also fight identically if the player had no hookshot, because a
sidestep answers `gate_lunge` and always did. Three reasons it is still the right
call: `Boss.freeze` refusing the barb is load-bearing poise and must not be
softened to rescue a table; the alternative (disarm) is four ceilings deep
(§6.4); and a floor-4 boss that *requires* a counted-charge item is a boss that
can be arrived at unanswerable, which pillar 2 forbids.

**What that leaves is a set with one strong row in it**, and saying so is the
point of the section. `docs/BESTIARY.md` §5's diagonal is a good claim about the
*floors* (`docs/PUZZLES.md` §1 earns it there, with locked doors and verbs) and a
mostly aspirational one about the *bosses*. Nobody should read §5 and expect four
locks, and no card should be closed on the strength of the table above without
reading these five paragraphs under it.

**And the audit `docs/BESTIARY.md` §4.3 started, finished.** Across all eight
authored fights:

| Ocarina shape | Who has it |
|---|---|
| Receptacle | Slag Ogre |
| Exposed weak point on a timer | Bellwake, Bellows-Hand |
| Reflect | Cistern Warden |
| Positional | **Riven Knight, Sluice-Keeper, Second Voice, Gate-Hound** |
| Disarm | **nobody** |

Four of the five, one per floor at boss level, which is what §5 promised. But
**positional is now five of the eight fights in the game**, and disarm is zero.
That is the honest shape of the set and it is not fixable inside the ceilings:
the minibosses get two beats each and positional is what two beats naturally are.
The place to spend a fix, if one is ever wanted, is a *miniboss* — the Gate-Hound
already lobs from across a gap (`docs/PUZZLES.md` §7), and a lob that returns is
the Thrower behaviour that is already on the manifest.

---

## 8. What this costs the manifest

`docs/SCOPE.md` §1 speaks in counts — but **not in all of these counts**, and an
earlier draft of this table presented every row as if it were §1's. Two of them
are not. `docs/SCOPE.md` §1 has no `Boss beats` row and no `Boss phases` row;
both caps live in §6's risk table, under *"Boss move sets balloon"*, whose answer
is *"Three beats, one phase, hard cap."* They are cited here as §6 accordingly,
and they are no less binding for it — `BossDb.validate()` enforces the beat cap
in code, which §1 does for nothing.

| | Count | Where it lives | Moved? |
|---|---|---|---|
| Bosses | **4** | §1 | No |
| **Boss beats** | **3 per boss, 12** | **§6**, and `validate()` | **No.** All four shapes are re-readings of `cistern_drop`, `bellows_charge`, `hushing_choir`, `gate_lunge` |
| **Boss phases** | **1** | **§6** | **No.** The turn changes the room. No beat, no stat, no move-set change, no second bar — §5 lists exactly what a turn may touch, and the `boss_phase_changed` emit is an announcement with no listener that acts on it |
| **New monster models** | **0** | §1 | No |
| **Puzzle atoms** | **9** | §1 | **No.** The keystone carries a `HookTarget` (the firer's contract), not a `HookRing` |
| **New mechanics** | **2** | §1 | **No** — and this is the row that is now doing the work. The receptacle is one `if` in a function that exists; the turn is a connect, a handler, a bool and four effects. **The Bellwake's damage gate would have been the third and it is refused in §6.3**, which is the whole reason §7 grades floor 3 the way it does |
| Usable items / ring stops | **6 / 6** | §1 | No |
| Enemy behaviours | **8**, 4 committed | §1 | No |
| Minibosses | **4** | §1 | No |
| New UI screens | **1** | §1 | No |
| **Boss attack shapes** | **5** | `boss_db.gd`'s header | **No — and this is the row that was at risk.** Reflect-with-an-object wanted a sixth and did not get one (§6.1) |

**Nothing here needs an owner's amendment**, which is the point: §5 said naming a
fight shape should cost nothing, and this is that claim checked line by line.

**The one thing that would.** A Warden that genuinely hurls debris needs a sixth
attack shape and a projectile with an owner, a flight and a return. It is not on
any row in §1 today, so it would arrive as a *new row* plus a move on
`New mechanics 2 → 3` — which is the row §4.2's fourth ledger line says is the
one to defend. Do not absorb it. If it is wanted, price it and take it to the
owner, and note first that the game already gets reflect-with-an-object for free
from the Thrower behaviour that is on the manifest.

**Three code changes, named, and priced at what they actually are** — the second
one was under-priced as "one threshold" for two drafts and it is the largest of
the three:

1. `Boss._on_damaged` — the arrow-into-the-**travel** branch, one `if` on
   `state`, `_charging` and `hit.kind` (§6.2). Genuinely one `if`.
2. `BossArena` — the turn, and it is **not** a threshold read off a row, because
   this node has no `_process`, no `_physics_process` and no reference to the
   boss's health today. It is: a `health.damaged` connect in `_build_boss`; a
   handler that reads `fraction()`, compares, and latches a bool; the
   `Bus.boss_phase_changed(1)` emit; a dispatch on `turn.kind`; and four effects
   behind it, of which **`shrink` needs the annulus guard in §5 and `douse` has
   no handle at all yet**. Plus `Boss.set_arena_radius()`, one setter beside the
   `set_arena_center()` the arena already calls. Call it a day's work with a
   director on the end of it, not a line.
3. `BossDb` — an `arena.turn` sub-dictionary on four rows. **No tell changes**:
   the 0.62 → 0.63 edit an earlier draft asked for was answering a 60% line that
   does not apply to boss beats (§4). `validate()` should grow **two** assertions
   with it — `turn.kind` is one of the four, and `turn.at` is in (0, 1). It
   should *not* grow the third one that was proposed (no beat's tell under 60% of
   the shallowest tell of its shape); §4 is the argument for why that assertion
   would be checking a number it invented.

---

## 9. What a director has to show

> **Read this before anything else in §9, because it is the largest risk in the
> document.** `SHAPE_CHARGE` and `SHAPE_SUMMON` have **zero runtime coverage**.
> No file anywhere in `tools/` references `bellows_charge`, `gate_lunge`,
> `hushing_choir`, `call_the_iron`, `SHAPE_CHARGE` or `SHAPE_SUMMON`, and
> `boss_cistern.gd` is the only boss director in the project — the Warden throws
> an `arc`, a `slam` and a `zone`, and those three shapes are the entirety of
> what has ever executed with a screenshot on the end of it.
>
> So: **six of the twelve beats and three of the four fight shapes in this
> document rest on code paths that have never run.** `_advance_charge`,
> `_end_charge`, `_shape_summon`, `_summons_alive`, the `cap` refusal in
> `_choose`, and `_commit_seconds`'s charge branch are all read-and-reasoned-about
> here and unexercised in fact. Every number in §3's charge rows, §6.2's whole
> answer and §6.3's whole timer is arithmetic off a table, not a measurement off
> a frame.
>
> That is also **why board card 22 was found by reading rather than by running**
> — `_shape_summon` writes `e.level` after `Enemy.spawn` has already built the
> combat block, and nothing has ever spawned a boss add to notice. Assume there
> is a second card 22 in the charge path and write the directors expecting to
> find it.

`CLAUDE.md` §2: the proof is exercising the thing and looking at the frames, and
`tools/directors/boss_cistern.gd` already does A–I for the Warden. Each new fight
gets its own director on that pattern — `boss_foundry.gd`, `boss_choir.gd`,
`boss_chord.gd` — and what §6 adds beyond A–I is small and specific:

- **All four:** the turn fires **once**, at the authored fraction,
  `Bus.boss_phase_changed` is emitted **exactly once** with it, and the frame
  before and the frame after are different pictures. Photograph both.
- **Warden, the parry:** the same beat, twice — once parried, once not — and
  `punish_opened` measured off the fight's own clock, **0.69 s apart** (§3: the
  0.22 s commit plus 1.10 s of recover, less the 0.627 s stagger). A director
  that asserts 0.47 is asserting the arithmetic this document had wrong for two
  drafts; it is the one number in §9 worth checking against §3 before you type
  it.
- **Warden, the shrink:** stand the hero at **10 m — outside the new 8.5 m
  fence** — and take the boss to half health there. The hero must end up inside
  the new ring, on the floor, able to move, with the fight still running. This is
  the §5 annulus guard and it is the beat most likely to fail: an unguarded
  `shrink` either seals him into a two-and-a-half-metre gap he cannot leave or
  pushes him through the outer fence. Photograph the frame after. And the donut's
  second answer still works after the shrink.
- **Slag Ogre:** let `bellows_charge` commit, then put an arrow into it **while
  it is travelling**. `beat_committed` **does** fire (the beat committed — that
  is the design, §6.2); the charge stops short of its 11 m; `punish_opened` fires
  with 1.70; and the hero's health is unchanged. Then an arrow into the same
  beat's **wind-up**, which must do nothing but damage — that is the negative
  case, and it is the one that proves the rule is scoped by ordering and not by
  weapon. Then the beat with no arrow at all, for the contrast frame. **This is
  the first `SHAPE_CHARGE` any director has ever thrown.**
- **Bellwake:** one blast clears both choristers; the boss takes measurable
  damage inside the 6.00 s; and the capped case — four alive, the beat refused by
  `_choose`, the fight visibly picking something else. Also assert the thing
  §6.3 and §7 are honest about, so no later reader has to rediscover it: **the
  boss takes full damage with two choristers alive**, because there is no gate.
  **No director in the project currently throws a `summon` at all** (board card
  22), so this is new ground and it is where the add-level bug will show.
- **Riven Knight:** a charge into the keystone ends early and the punish opens
  anyway; the hookshot pulls the hero to the keystone; **the arena has no
  `HookTarget` in it before the turn** (§6.4 — photograph the failed press, it is
  half the fight); and the boss does **not** stall behind the keystone — thirty
  seconds of fight after the turn with beats still landing.

And `--warmup`, `timeout 400`, and `tools/quiet.sh` rather than bare `godot`,
for the reasons `CLAUDE.md` §2 gives at length.
