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

**Status: design.** The twelve beats exist and the Warden is built and proven
(`tools/directors/boss_cistern.gd`). Everything this document adds is one `if`,
one signal and four rooms, and §8 checks all of it against a count in
`docs/SCOPE.md` §1. **Nothing here needs an owner's amendment.**

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
uniform: `slam` draws its ring (inner and outer, so the donut is visible),
`arc` and `charge` draw a forward lane parented to the body so it turns as the
boss tracks, and **`zone` and `summon` draw nothing during the tell** — a zone's
discs appear at the commit and grow over their own fuse, and a summon's tell *is*
the pose. Three different pictures for five shapes, deliberately.

> **Known defect, and it is a telegraph defect: the arc lane is a bounding box,
> not the cone it delivers** — board card 21. At `slag_backhand`'s 95° half-angle
> the mark is 8.4 m wide over 4.2 m of reach while the damage is a 190° cone that
> reaches around the boss's shoulders. Everything §6 says about "roll backwards,
> never sideways" out of an arc is *already* the truth; the mark is what disagrees
> with it. Fix the mark, not the beat.

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

**1.37 s is the finisher line**, and it is the number a punish window should be
authored against. Six of the twelve beats clear it (`cistern_drop`,
`bellows_charge`, `tap_the_ladle`, `first_toll`, `hushing_choir`,
`call_the_iron`). **Two miss it by 0.02 s** — `drown_pool` and `gate_lunge` both
pay 1.35 s — which is almost certainly nobody's decision, and 1.40 would make
them the fights they read as. [tune]

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

**1. The window a parry buys is `recover − 0.627`, and nothing else.** So:

| Beat | `recover` | Parry buys | Plus |
|---|---|---|---|
| `bellows_charge` | 1.20 | **+0.57 s** | the rest of an 11 m charge, up to 0.85 s |
| `first_toll` | 1.15 | **+0.52 s** | — |
| `cistern_drop` | 1.10 | **+0.47 s** | — |
| `gate_lunge` | 1.05 | **+0.42 s** | the rest of a 12 m charge, up to 0.75 s |
| `sluice_sweep` | 0.80 | +0.17 s | — |
| `slag_backhand` | 0.70 | +0.07 s | — |
| `riven_arc` | 0.65 | **+0.02 s** | — |
| the three `zone` beats | — | **nothing** | see below |
| the two `summon` beats | — | **nothing at all** | they deal no damage |

Read the bottom of that table honestly: **at floor 4 the parry stops being a
window and becomes a refusal.** Parrying `riven_arc` buys 0.02 s of recovery —
what it actually pays is the damage you did not take and the 1.20 s riposte dash,
which against a boss that has just spent its fastest beat is worth more than two
hundredths of a second anyway. It is a different move by the end of the game,
and the fight it belongs to is the one that gives the sword the least room.

**2. A `zone` cannot be parried into an opening, by construction.** `Boss._land`
passes the *disc centre* as the blow's origin for a zone, and
`HeroCombat._parried_body` looks for something with a `stagger()` within **1.4 m
of that origin** — which the boss is not. The blow is refused and the i-frames
are granted; nothing is staggered. And the first disc of every zone is placed
under the hero, so when a standing hero is caught by it the direction from the
blow is zero and `parries()` and `blocks()` both return false: **the shield does
not answer a pool you are standing in.** That is not a bug to fix. It is the
reason every boss in the game has a zone beat — it is the beat the shield has no
answer to, and the roll does.

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

**The arc line is 0.01 s past the promise.** 60% of the Warden's 1.05 s sweep is
**0.630 s**; `riven_arc`'s tell is **0.620 s**. Sixteen milliseconds nobody will
ever feel — and that is exactly why it should be 0.63 rather than argued about:
a contract stated as a number is only worth having if it is checked as one.
`validate()` can assert it in four lines, and the number to change is one.

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
`docs/SCOPE.md` §1's one-phase cap turns out to be the design answer rather than
only the budget one.

**The mechanism, once.** `BossArena` — which already builds the seal and the
cover posts off the row — watches the boss's health and, the first time it is at
or under `arena.turn.at` of maximum, applies `arena.turn` and sets a bool. One
threshold for all four, `0.50`, because four thresholds is four tunings nobody
can compare against each other.

**What a turn may touch: the fence radius, the cover posts, the room's light.**
Nothing else, ever. It may not touch a beat's numbers, the move set, `pick_beat`,
the health bar or the tint — every one of those is a second phase wearing a room.

**Four kinds, one per boss, and that is the cap.** A fifth is a proposal to make
the room a mechanic, and it goes to the owner rather than into this table.

| Boss | Kind | The change | What it costs |
|---|---|---|---|
| Warden | `shrink` | the fence walks in: 11.0 → 8.5 m | a second seal ring, built at the smaller radius and raised |
| Slag Ogre | `topple` | two of three slag pillars slump: `cover_count` 3 → 1 | `queue_free` on two named children |
| Bellwake | `douse` | the Choir's sconces go out | a light tween — see the caveat |
| Riven Knight | `keystone` | the broken keystone drops into the middle of the arena | one `StaticBody3D` with a `HookTarget` on it |

Two implementation notes an implementer should not have to re-derive:

- **`shrink` needs `Boss.arena_radius()` to follow it.** `_shape_zone` scatters
  its discs inside `arena_radius() - radius`, read off the row, so a Warden whose
  fence has moved would still be drowning the floor of the room it used to be in.
  Add a `set_arena_radius()` beside the `set_arena_center()` the arena already
  calls, and have the turn call it. The seal itself is easiest as a *second*
  fence built at 8.5 m and raised — scaling a ring of fixed-width panels leaves
  daylight at every joint, which is the bug `boss_arena.gd`'s own comment records
  having shipped once already.
- **`douse` is the one turn that needs a handle `BossArena` does not have.** A
  generated room's lights belong to the room. If they cannot be reached from the
  arena, the fallback is `shrink` to 10.0 m and the Bellwake loses nothing
  structural — but try `douse` first, because it is the only turn of the four
  that costs no geometry and it is the one the fiction is asking for.

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
| `drown_pool` | 0.95 (+1.10 fuse) | 0.22 | 0.55 | 1.35 → 2, misses the finisher by 0.02 | 1.60 |

Depth: none. Floor 1 numbers are the authored numbers (§4), and the 60% floor —
0.6 of a tell — is what the rest of the roster is measured against, never this.

**Three telegraphs, three pictures.** One arm hauled back over the shoulder,
green from the elbow out, with a *lane* on the floor in front of it. Both fists
locked overhead and dead still — the only moment it is taller than it walks —
pale, with a *ring* on the floor that has a hole in the middle. A hard sideways
cant and a flat palm at the floor, cold blue, with **no mark at all** until the
commit, when two discs bloom under the hero's feet and grow for a second before
they burst. Rear/green/lane, rise/white/ring, tilt/blue/nothing: no two share a
pose, a colour or a mark.

**The answer: the shield, and the second way over is to walk toward it.**

- *Fast:* parry `cistern_drop` from inside the ring band. It opens the beat's
  1.60 s punish 0.47 s early and hands over a 1.20 s riposte dash on top — the
  best single opening on floor 1.
- *Worse, and always available:* step inside 2.1 m and take nothing at all. The
  Warden's arena has no cover for exactly this reason; its own row says a pillar
  here would teach the player to solve beat two by hiding, and beat two's answer
  is to walk into it. **The inside is not a rest position** — `sluice_sweep`
  reaches 4.6 m and `drown_pool`'s first disc is drawn wherever the hero is
  standing — so the safe answer costs you the next beat's positioning, which is
  what makes the greedy one worth learning.

**Parry and dodge, per beat.** `sluice_sweep`: parryable, buys 0.17 s, so throw
it for the riposte; rolling is the ordinary answer and the roll goes *backwards*,
not sideways — the cone is 150° wide however narrow the drawn lane looks (card
21). `cistern_drop`: the fight's parry, above. `drown_pool`: **roll, always** —
a parried disc refuses the damage and staggers nothing (§3), and a disc centred
on a hero who has not moved is not even blocked.

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

**The beat that carries it: `bellows_charge`.** It is the only beat in the game
with a `min_range` — 4.5 m — so it is the only beat that *happens where the bow
lives*. King Dodongo inhales and you throw a bomb into the mouth; the Ogre draws
and you put an arrow in the draw.

**The rule, exactly, so nobody has to derive it:**

> While `bellows_charge` is in `State.WINDUP`, **and only then**, a `Hit` whose
> `kind` is `Hit.ARROW` or `Hit.ARROW_FIRE` calls
> `stagger(hit.from, K.PARRY_STAGGER, 0.0)` instead of falling through to the
> ordinary poise path.

`Boss._on_damaged` already receives the whole `Hit`, and `Hit.kind` already
distinguishes an arrow from a sword — this is one `if` in a function that exists.
The consequences are all the fight's own vocabulary: `_commit` never runs so the
charge never happens and `beat_committed` never fires, the body drops into
`RECOVER` for 0.627 s, and then the beat's authored **1.70 s** punish opens with
`punish_opened` exactly as it would have.

**Why this does not break poise, which is the objection it will get.** `boss.gd`
refuses every other interruption on two grounds: a beat the player can interrupt
is a beat they can delete, and a tell that never lands makes the telegraph a lie.
Neither applies here. The beat is not deleted — **its punish is paid in full and
immediately**, so the player buys the window early rather than skipping it, which
is precisely the shape of the parry exemption §3.6 already argued for. And the
telegraph is not made a lie: the tell is the thing being answered, not the thing
being cancelled. What it costs is a **counted resource bought in the garrison**,
which is a price the parry does not even have. What keeps it from becoming *"the
bow cancels bosses"* is that it is one beat on one boss: an arrow into
`slag_backhand`'s tell does nothing, an arrow during a punish is just damage, and
the other three bosses have no receptacle at all.

**The receptacle is a window in time, not a hitbox in space**, and that is
deliberate. This project has no per-limb hitboxes — a boss does not even have a
contact hitbox — and adding one is a new system, which `docs/SCOPE.md` §4.3's
second question refuses. What the player reads is the tell itself: the whole body
lights RUST over 0.90 s and the bellows-scar is the brightest line on it.

| | Tell | Commit | Recover | Punish | Cooldown |
|---|---|---|---|---|---|
| `bellows_charge` | 0.90 | 0.85 travel | 1.20 | 1.70 → **3 contacts** | 1.70 |
| `slag_backhand` | 0.72 | 0.22 | 0.70 | 1.00 → 2 | 1.00 |
| `tap_the_ladle` | 1.15 (+1.30 fuse) | 0.22 | 0.90 | 1.45 → **3** | 1.70 |

Depth: none, per §4. The authored compression from floor 1 is 86.7% on the charge
and 68.6% on the arc, both clear of the 0.6 line by a distance.

**Three telegraphs.** A dropped head and a planted back foot with one hard orange
line down the body and a **narrow 3 m lane** drawn forward — the tell is a
direction, which no other tell in this fight is. A fist cocked behind the head,
the cooled crust splitting red along the knuckles, and a **wide lane**: the
shortest tell in the fight and the widest arc in the game. A squat — the only
time it is shorter than the hero — white-hot, with **no mark until the commit**,
when three rings burn into the flagstones on a 1.30 s fuse. Tilt/rust/narrow
lane, rear/red/wide lane, crouch/white/nothing.

**The answer: an arrow, and there are two other ways over the wall.**

- *Fast:* the arrow in the intake. It costs one arrow and deletes the fight's
  hardest beat.
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
0.57 s early on top of the 1.70. `slag_backhand` is a 190° cone at 4.2 m, so it
cannot be side-stepped: the answer is backwards past 4.2 m, a roll through it for
the perfect dodge, or the shield — and the parry there is worth 0.07 s of window,
so throw it for the riposte and the refusal, not for the opening.
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
   is the same failure mode board card 21 records for the arc lane.
3. **The pillar is already spoken for, one branch away.** The floor-3 *miniboss*
   — the Second Voice, `docs/PUZZLES.md` §7 — is *"it anchors to a resonating
   pillar and cannot be touched while the pillar sings. Burst the pillar."*
   Giving the boss the same wall is the floor asking one question twice, which is
   §4.3's rule applied at floor scale instead of beat scale.

**The beat that carries it, unchanged: `hushing_choir`.** The shell is the
choristers. This is Barinade, exactly: strip the shell, hit the thing under it
before the shell reforms — and the reform is not a new timer, it is the beat's
own `cooldown` of **6.00 s** and its `cap` of 4.

**The timer, worked in seconds**, because "on a timer" is only a design if the
seconds exist:

- Commit → 1.30 s recover → **2.00 s punish**, the longest window in the game.
- The two choristers appear 8.0 m from the boss at the commit and walk at 2.2 m/s
  (`skeleton`), so a hero standing on the boss has roughly **3.1 s** before the
  first one is on him — i.e. the choir arrives about three tenths of a second
  before the punish closes. The window is free and then it is not.
- After the punish, 4.00 s of cooldown remain. **That is the strip window**: six
  seconds from the moment the boss goes open, in which the player has to spend
  the free hits *and* clear two bodies, and only one thing in the kit does both.

**Why the Burst and not the sword.** At floor 3 the Burst is the player's only
area answer, and the choristers converge on the hero — which is what makes them a
single target rather than two. Clearing them with the blade costs the punish
window it was supposed to protect.

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
  the 6 s.
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

**Parry and dodge.** `first_toll` is parryable from inside 7.5 m and buys 0.52 s
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
| `gate_lunge` | 0.78 | 0.75 travel | 1.05 | 1.35 → 2, misses the finisher by 0.02 | 1.35 |
| `riven_arc` | 0.62 | 0.22 | 0.65 | 0.90 → 2 | 0.90 |
| `call_the_iron` | 1.45 | 0.22 | 1.40 | 2.10 → **3** | 8.00 |

Depth: none. The authored compression against floor 1 is 86.7% on the charge and
**59.0% on the arc, which is 0.01 s past GDD §7's 60% line** — 0.63 s is the
number, `riven_arc` says 0.62, and §4 recommends the one-character fix.

**Three telegraphs.** It sinks onto its back leg and levels the blade at hip
height with one red line running the length of it — **the line is the lane**, and
it is the shortest tell of the three and tells you the most. The sword comes over
the shoulder in a single frame and then *holds*, dead still, with the split down
the breastplate glowing through the gap in the plate — it is the stillness that
reads, not the movement. It plants the sword point-down and opens both gauntlets
away from the hilt while a horn carries. Crouch/red/narrow lane, rear/rust/wide
lane, spread/violet/no mark.

**The answer: the hookshot, and there are two other ways over the wall.**

- *Fast:* the keystone. After the turn there is a `HookTarget` at the centre of
  the arena, and a hookshot to it is the fastest exit from a 1.2 m lane in the
  game — and the fastest way back in afterwards, which is the half that makes it
  a reposition rather than an escape.
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
charge on the shortest tell — and it pays 0.42 s plus up to three quarters of a
second of aborted travel. `riven_arc` is the beat that shows what the parry
becomes at floor 4: 0.02 s of window, so what you are buying is six quarters of
damage refused and a 1.20 s dash into a body that has just spent its fastest
move. `call_the_iron` is unparryable and undodgeable, like every summon, and pays
the longest punish in the game (2.10 s) for it.

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
floors. Walked one floor at a time, **it holds three and a half times out of
four**, and here is the half.

| Floor | Carrying | Fight shape | Answered by | Through |
|---|---|---|---|---|
| 1 Warden | shield (always owned) | Reflect | the parry on `cistern_drop` | **the body** |
| 2 Slag Ogre | **Bow** ← Warden | Receptacle | an arrow in `bellows_charge`'s tell | **the body** |
| 3 Bellwake | **Burst** ← Ogre | Exposed weak point on a timer | a blast into the choir | **the adds** |
| 4 Riven Knight | **Hookshot** ← Bellwake | Positional | the keystone anchor | **the room** |

**Floors 1 and 2 are the claim in its strong form.** The item acts on the boss
itself, on a specific beat, with a visible cue and an immediate consequence, and
in both cases the boss is *worse off* for it. This is the shape the other two
should be measured against.

**Floor 3 is one step weaker but still honest.** The Burst does not touch the
Bellwake; it deletes what the Bellwake is hiding behind, which is exactly
Barinade's shell and exactly what "exposed weak point" means. The thing it is
hiding behind happens to be alive.

**Floor 4 is where it breaks, and it breaks quietly.** The hookshot answers the
Riven Knight through *arena furniture the arena did not have until half health*.
The Knight would fight identically if the player had no hookshot — a sidestep
answers `gate_lunge` and always did — so floor 4 is the one fight where the
diagonal is a convenience rather than a lock. Three reasons it is still the right
call: `Boss.freeze` refusing the barb is load-bearing poise and must not be
softened to rescue a table; the alternative (disarm) is four ceilings deep
(§6.4); and a floor-4 boss that *requires* a counted-charge item is a boss that
can be arrived at unanswerable, which pillar 2 forbids.

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

`docs/SCOPE.md` §1 speaks in counts, so:

| | Count | Moved? |
|---|---|---|
| Bosses | **4** | No |
| **Boss beats** | **12** | **No.** All four shapes are re-readings of `cistern_drop`, `bellows_charge`, `hushing_choir`, `gate_lunge` |
| **Boss phases** | **1** | **No.** The turn changes the room. No beat, no stat, no move-set change, no second bar — §5 lists exactly what a turn may touch |
| **New monster models** | **0** | No |
| **Puzzle atoms** | **9** | **No.** The keystone carries a `HookTarget` (the firer's contract), not a `HookRing` |
| **New mechanics** | **2** | **No.** The receptacle is one `if` in a function that exists; the turn is one threshold and a room. Both are held to the same test the Echo and the shield reflect passed |
| Usable items / ring stops | **6 / 6** | No |
| Enemy behaviours | **8**, 4 committed | No |
| Minibosses | **4** | No |
| New UI screens | **1** | No |
| **Boss attack shapes** | **5** | **No — and this is the row that was at risk.** Reflect-with-an-object wanted a sixth and did not get one (§6.1) |

**Nothing here needs an owner's amendment**, which is the point: §5 said naming a
fight shape should cost nothing, and this is that claim checked line by line.

**The one thing that would.** A Warden that genuinely hurls debris needs a sixth
attack shape and a projectile with an owner, a flight and a return. It is not on
any row in §1 today, so it would arrive as a *new row* plus a move on
`New mechanics 2 → 3` — which is the row §4.2's fourth ledger line says is the
one to defend. Do not absorb it. If it is wanted, price it and take it to the
owner, and note first that the game already gets reflect-with-an-object for free
from the Thrower behaviour that is on the manifest.

**Three code changes, named, so nobody thinks this is only prose:**

1. `Boss._on_damaged` — the arrow-into-the-tell branch, one `if` (§6.2).
2. `BossArena` — the turn: a threshold read off the row, a bool, and four small
   effects (§5). Plus `Boss.set_arena_radius()`, one setter beside the
   `set_arena_center()` the arena already calls.
3. `BossDb` — an `arena.turn` sub-dictionary on four rows, and one tell of
   0.62 → 0.63 (§4). `validate()` should grow three assertions with it:
   `turn.kind` is one of the four, `turn.at` is in (0, 1), and no beat's tell is
   under 60% of the shallowest tell of the same attack shape.

---

## 9. What a director has to show

`CLAUDE.md` §2: the proof is exercising the thing and looking at the frames, and
`tools/directors/boss_cistern.gd` already does A–I for the Warden. Each new fight
gets its own director on that pattern — `boss_foundry.gd`, `boss_choir.gd`,
`boss_chord.gd` — and what §6 adds beyond A–I is small and specific:

- **All four:** the turn fires **once**, at the authored fraction, and the frame
  before and the frame after are different pictures. Photograph both.
- **Warden:** the same beat, twice — once parried, once not — and
  `punish_opened` measured off the fight's own clock, 0.47 s apart. And the
  donut's second answer still works after the shrink.
- **Slag Ogre:** an arrow into `bellows_charge`'s wind-up, after which
  `beat_committed` **never fires for that beat**, `punish_opened` fires with
  1.70, and the hero's health is unchanged. Then the same beat with no arrow, for
  the contrast frame.
- **Bellwake:** one blast clears both choristers; the boss takes measurable
  damage inside the 6.00 s; and the capped case — four alive, the beat refused by
  `_choose`, the fight visibly picking something else. **No director in the
  project currently throws a `summon` at all** (board card 22), so this is new
  ground and it is where the add-level bug will show.
- **Riven Knight:** a charge into the keystone ends early and the punish opens
  anyway; the hookshot pulls the hero to the keystone; and the boss does **not**
  stall behind it — thirty seconds of fight after the turn with beats still
  landing.

And `--warmup`, `timeout 400`, and `tools/quiet.sh` rather than bare `godot`,
for the reasons `CLAUDE.md` §2 gives at length.
