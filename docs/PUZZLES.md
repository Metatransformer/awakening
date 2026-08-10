# Puzzles and Echoes

**Status: §2 is built (M1). Everything else is still design.** The eight phase-1
atoms and the door that listens are in the code — `scripts/props/puzzle_atoms.gd`
(the table and the factory), `scripts/props/puzzle_atom.gd` (the base body), the
eight files under `scripts/props/atoms/`, and `scripts/props/puzzle_gate.gd`,
proved by `tools/directors/puzzle_atoms.gd`. §3's combinators, §4's cycles, §5's
three shapes, §6's Echoes and §7's minibosses are M4 and later.

This file owns the puzzle vocabulary, the three shapes, and where Echoes come
from, and it owns nothing else.

It exists because `docs/GDD.md` §5.3 shipped a **lock** and called it a puzzle. A
door that opens because you own item X is a *check*. Zelda's verb is that the
item lets you see and change the room. That gap is what this document closes.

---

## 0. The two rules everything below obeys

> **1. A critical-path puzzle never asks for an item you do not own.**
> **2. A puzzle room supplies its own ammunition.**

Rule 1 is what keeps GDD pillar 2 alive: a cautious player is never blocked. It
is not "no puzzles on the critical path" — puzzles on the critical path are the
point — it is that the *verb* is always one you already earned.

Rule 2 is the pot. A bow puzzle you meet with zero arrows is a dead end, and a
bow puzzle that eats the arrows you were saving for the walk home is a tax on a
resource `docs/METAGAME.md` §4.6 already balances three ways. **Every puzzle room
is solvable from a cold start with an empty pouch**, because the urns beside it
hold exactly what it needs. This is how Ocarina does it and it is not a
coincidence.

---

## 1. The verb ladder

There are **four puzzle verbs and one key**, and there is no fifth. Everything
here is read off `docs/GDD.md` §5.2 — no new item exists to serve a puzzle.

| Tier | Verb | Owned from |
|---|---|---|
| **T0** | Sword, shield, body (push / stand), **key** | The start. Always |
| **T1** | **Bow** | The Cistern Warden |
| **T2** | **Burst** | The Slag Ogre |
| **T3** | **Hookshot** | The Bellwake |

The Far Lantern has no verb (GDD §5.2) and never gets one. It is the last door in
the game and a pure lock, which is the correct shape for a thing that ends Act I.
Sustain and Ballast are not puzzle verbs — they change tempo and soak, and
neither manipulates a room.

### What each floor may ask for

| Floor | Enter owning | Critical path uses | Shortcut needs | Boss gives |
|---|---|---|---|---|
| 1 The Cistern | T0 | **T0** — a key hunt | **T1** Bow | Bow |
| 2 The Foundry | T1 | **T1** Bow | **T2** Burst | Burst |
| 3 The Hushing Choir | T2 | **T2** Burst | **T3** Hookshot | Hookshot |
| 4 The Chord Gate | T3 | **T3** Hookshot | Far Lantern → §8 | Far Lantern |

**Read the diagonal.** Each floor's critical path is *the item the previous
floor's boss just handed you*. That is deliberate, and it repairs a real problem
in GDD §5: Ocarina puts the dungeon item at the **middle** of the dungeon so the
back half can be about it, and this design puts it at the **end**, so the toy you
just earned had nowhere to be used. Displacing it by one floor gets Ocarina's
shape back without moving a single boss — you kill the Warden, and the Foundry is
the temple that is *about* the bow.

**The shortcut pool is exactly tier N.** Not "N or above". Floor 1's shortcut
puzzle is drawn from the T1 pool, so it opens the moment the Warden dies, which
is what makes GDD §5.3's promise — *"on your fifth run you are at the Choir in
ninety seconds"* — true. Drawing from T1–T3 would let a seed put the Hookshot on
floor 1's shortcut and silently delay the whole payoff by two floors.

---

## 2. The atoms

Twelve, lifted from Ocarina, each one a prop and a signal. **Nothing here is a
mechanic** — every one of them is a body that emits `solved` and a door that
listens.

| Atom | Verb | Where it comes from | Phase |
|---|---|---|---|
| **Locked door + small key** | T0 key | Every OOT dungeon | **1** |
| **Urn** — breaks, drops arrows/hearts | T0 sword | Every OOT dungeon | **1** |
| **Pressure plate** — a body or a block holds it | T0 | Forest, Fire | **1** |
| **Push block** — grid-stepped, into a hole or onto a plate | T0 | Forest, Spirit, Shadow | **1** |
| **Eye switch** — opens when struck at range | T1 bow | Deku Tree, Forest, Water | **1** |
| **Cracked pillar / floor** — the slab it holds drops | T2 burst | Dodongo's Cavern | **1** |
| **Hookshot target** — cross, or pull the block to you | T3 hookshot | Forest, Water, Shadow | **1** |
| **Sun switch + beam** — reflected off the shield | T0 shield | Spirit (Mirror Shield) | **1** |
| **Crystal switch** — any blow trips it | T0 sword | Every OOT dungeon | 2 |
| **Torch** — carry fire from a lit one, on a timer | T0 | Deku Tree, Fire | 2 |
| **Timed bars** — solve inside T or it resets | — | Fire, Forest | 2 |
| **Sounding set** — N tokens scattered in one room | — | Spirit, Gerudo Training | 2 |

**Phase 1 is eight props** and it covers all four tiers plus the key, which is
the whole of §1's table. Phase 2 is the flavour and none of it is load-bearing.

### As built (M1)

| Atom | Script | Solved by |
|---|---|---|
| Small key | `scripts/props/atoms/small_key.gd` | walking onto it; `Game.add_key(1)` |
| Urn | `scripts/props/atoms/urn.gd` | any `apply_hit` — spills arrows or hearts |
| Pressure plate | `scripts/props/atoms/pressure_plate.gd` | the hero, or anything in group `plate_weight` |
| Push block | `scripts/props/atoms/push_block.gd` | shoved onto its mark, one 1.2 m step at a time |
| Eye switch | `scripts/props/atoms/eye_switch.gd` | `apply_hit` with `kind == &"arrow"`, and nothing else |
| Cracked pillar | `scripts/props/atoms/cracked_pillar.gd` | `burst()` — **inert until M5** |
| Hook ring | `scripts/props/atoms/hook_ring.gd` | `HookTarget.on_bitten`, from the firer |
| Sun socket | `scripts/props/atoms/sun_socket.gd` | guard up in the shaft, aimed at the socket |

The table itself is `scripts/props/puzzle_atoms.gd` — tier, verb, script, refusal,
plural, `latching` and `gates`, one row each — and `PuzzleAtoms.pool(max_tier)`
is rule 1 of §0 in a single function: it takes the minimum of the shape's ceiling
and what `Game.has()` says the player owns.

**The door that listens is `PuzzleGate`** (`scripts/props/puzzle_gate.gd`), a
`LockedDoor` subclass. It adopts every atom carrying its `puzzle_id`, refuses
with the atom's own line — *"2 OF 3 EYES STILL SHUT"* — and opens itself when the
last one lands, unless `needs_key` says the key has to be spent at the door.
Atom flags are cleared by `Run.enter()`, so a floor re-entered inside one run
stays solved and run two gets its puzzle back (§5.2).

**The shield reflect is in phase 1 on purpose.** Floor 1's critical path is
T0-only (§1), and without it every Cistern puzzle is a key, a plate or a block —
haulage. A Vyr light-beam bounced off the shield into a socket is the only T0
atom that asks the player to *aim* rather than to carry, it needs no item that
does not already exist, and it is available in the first ten minutes of the game.
It is also the one atom that makes the shield a tool rather than a wall, which
GDD pillar 1 wants anyway.

---

## 3. The combinators

Atoms are boring alone and that is fine — **the variety is here, not in the prop
count.** Five combinators over seven atoms is where the generated feel comes
from, and it is why this document does not contain a list of forty hand-authored
puzzle rooms.

| | Combinator | Example |
|---|---|---|
| **1** | **Nest** — one atom's reward is another's input | The key is in the chest behind the eye |
| **2** | **Sequence** — trip N atoms in order | Three eyes, left to right |
| **3** | **Time** — solve inside a window or it resets | Hit the eye, reach the bars before they drop |
| **4** | **Displace** — the atom is in one room, the door it opens is in another | The plate is in the room you already cleared |
| **5** | **Cycle** — the atom is on the *far* side, and solving it opens a two-way link | You come round the loop and blast the pillar from inside |

Combinator 5 is the important one and it deserves its own section.

---

## 4. Cycles — why the loop is the design

`scripts/world/dungeon.gd` builds a **tree**: every room has one `parent`, so
every route is out-and-back and nothing can ever surprise you spatially. That is
the mechanical reason the floors feel like a corridor with rooms on it.

The fix is one extra edge. Pick two rooms whose `dist` differs by ≥ 3, connect
them, and **block the connection from the near side only**. The far side is a
cracked pillar, a bolted bar, a ledge you can hookshot back across.

The reference is Joris Dormans' mission/space separation (2010) and the cyclic
dungeon generation shipped in **Unexplored** (2017), which is still the only game
that has convincingly generated Zelda-grade puzzles. The move: **generate the
logical sequence first, then embed it in space.** `_plan_anchors()` and
`FloorDb.anchors()` are already half of that embedder.

**The critical-path cycle is the walk home.** This is the part that makes cycles
belong in *this* game rather than in a general Zelda-like: the loop you open by
solving the gate room comes out near the entrance, so beating the puzzle
physically shortens the extraction walk. GDD §2 asks *is what I am carrying worth
more than the walk back*, and a puzzle that answers it with **less walk** is a
puzzle that pays in the game's own currency instead of in power.

---

## 5. The three shapes

### 5.1 Shortcut puzzle — *prove you have done this, and never do it again*

- **Anchor:** the existing `shortcut_door`, near the entrance.
- **Verb:** exactly tier N (§1).
- **Reward:** the way to floor N+1, skipping this floor. **+1 Echo, always.**
- **Shape:** a straight solve, not a cycle. You already own the item; the puzzle
  is the receipt, not the challenge.

### 5.2 Critical-path puzzle — *the gate room*

- **Anchor:** new, `gate_room` — on the path to `deepest`, around 0.7 of the way.
- **Verb:** tier ≤ N−1. **Never anything you do not own** (§0 rule 1).
- **Reward:** the approach to the boss door, **+1 Echo** (choice of three at a
  sounding stone), and **the cycle back toward the entrance** (§4).
- **Shape:** cycle. Always.

Floor 1's is a key hunt, because T0 is all it may ask for and a key hunt is the
honest T0 puzzle. That is correct, not a placeholder: Ocarina's first dungeon is
also mostly a key and a ladder.

### 5.3 Treasure puzzle — *optional, richer, harder*

- **Anchor:** new, `puzzle_room`, off the mid-ring; and the existing `vault_door`
  keeps its GDD §5.3 rule (tier N+1, holds a relic).
- **Verb:** tier ≤ N.
- **Reward:** **the floor's miniboss** (§7) and a rich chest, **and +1 Echo**.
- **Shape:** nest or sequence. This is where two atoms get combined.

**Nothing here is on the critical path**, so a floor is always completable
without it, and GDD §5.1's *"walking into the Cistern, filling twelve slots and
roping out is a complete, correct, profitable run"* survives intact.

---

## 6. Echoes

An **Echo** is a run-scoped boon. The Cut still rings — the Hushing Choir is a
resonance hall that has not stopped (GDD §5) — and an Echo is a tone you carry
out of a room.

> **An Echo costs a bag slot, and that is the only thing it costs.**

- **It is worth 0 gold.** It cannot be sold, so it does not raise the extraction
  fee. The price is capacity, not coin.
- **It does not survive the run.** Home, garrison or death — it goes quiet. GDD
  pillar 4 is about *permanence*, and an Echo is not permanent, so it does not
  touch it.
- **It never moves one of the five stats.** Those are the smith's and the
  jeweller's, and that boundary is what protects GDD §6.6. An Echo changes a
  *rule* — Heat's window stops shrinking, the first blow in a room is blocked,
  motes magnetise from twice as far, a roll leaves a burst behind it.
- **It does not fit in the document case**, for the same reason a relic does not.
  Moot in practice, since it dies anyway, but write it down before someone asks.
- **You may refuse it and you may drop it.** It arrives as a mote on a pedestal
  and behaves like every other mote when the bag is full: it stays and pulses.

### Where they come from

| Route | Echoes |
|---|---|
| Take the shortcut, skip the floor | **1** |
| Play the floor — the gate room | **1** |
| Play the floor — the treasure puzzle | **+1** |

**Minimum one per floor, maximum two.** Four to eight across Act I, each one a
slot, against a bag of twelve. A player who takes every Echo on offer walks into
the Chord Gate carrying almost nothing worth selling, and that is the decision.

**Every Echo pickup is a choice of three.** One prefab — a sounding stone with
three motes over it — used at all three sites. It is the Slay the Spire beat and
it costs nothing beyond the prefab that already had to exist.

---

## 7. The minibosses — four, and each one teaches the floor's verb

One per floor, behind the treasure puzzle (§5.3). **Optional, always.** A player
who never solves a treasure puzzle never meets one, and that is correct: this is
the branch of the floor that pays extra for extra work.

**Models are placeholder.** Each is a scaled, re-tinted roster enemy exactly the
way GDD §5 does the four bosses, and the four they use are four the bosses do
*not*: the bosses take `golem`, `ogre`, `wraith` and `knight_iron`, leaving
`skeleton`, `goblin`, `kobold`, `orc` and `troll` on the shelf. **New monster
models stays 0.** The move sets below are the real design and they are what gets
built; the silhouettes are a later, separable problem.

**No floor's miniboss shares a model with its boss.** That is the rule that picks
which four, and it is not fussiness — floor 3's boss is a `wraith`, so a `wraith`
miniboss on floor 3 is two fights against the same silhouette in one descent, and
a player who cannot tell at a glance which one they are looking at cannot tell
which move set to expect. `docs/STYLEGUIDE.md` treats silhouette as the readable
channel and this is that rule applied to encounters.

**Two beats, not three.** A boss gets three (GDD §5); a miniboss gets two, and
one of them is answered by the floor's verb. That is the whole design rule:

> **A miniboss's first beat is a wall that the floor's own verb opens.**

So the treasure branch is where the game *teaches in combat* what the gate room
taught in a puzzle. The bow that opened the eye is the bow that gets behind the
guard. Neither one is a tutorial and neither one is skippable-and-then-required.

| Floor | Miniboss | Placeholder | Beat 1 — the wall | Beat 2 — the threat |
|---|---|---|---|---|
| 1 Cistern | **The Sluice-Keeper** | `troll`, ×1.2, wet bronze | **Wheel-swing.** A full-beat overhead wind-up. *Blockable*, and blocking is the answer — a blocked blow never changes health, so the shield is how a Heat chain survives this fight (`docs/METAGAME.md` §4.5) | **Flood-stomp.** He plants and the water pulls back off his feet; a floor-tracking ring that must be rolled, never blocked |
| 2 Foundry | **The Bellows-Hand** | `orc`, ×1.3, slag-red | **Guard.** Advances behind a plate; melee rings off it. The bellows on his back is exposed when he turns — **one arrow opens him** | **Ember-cough.** The bellows swell for a beat, then a cone of sparks |
| 3 Choir | **The Second Voice** | `skeleton`, ×1.5, pale | **Ring.** It anchors to a resonating pillar and cannot be touched while the pillar sings. **Burst the pillar** | **Keening.** A sustained cone. It lands as a blow, so it breaks Heat — the fight is a race against your own chain |
| 4 Chord Gate | **The Gate-Hound** | `kobold`, ×1.4, iron-dark | **Retreat.** Backs across a gap and lobs from the far side. **Hookshot** closes it, or freezes it where it stands (GDD §5.2) | **Overhand.** A heavy committed slam. Rolled, not blocked — the one beat in the set the shield does not answer |

**Every telegraph obeys GDD §7**: it never compresses past 60% however deep the
floor is. A miniboss that becomes unreadable at depth is a miniboss that has
stopped being a design and started being a wall.

**They drop nothing but the chest behind them.** No miniboss drops an item, a
stat or a relic — GDD pillar 4 holds here exactly as it does everywhere else. The
Echo on that branch comes from the puzzle, not from the kill.

---

## 8. What this adds to the manifest

`docs/SCOPE.md` §1 speaks in counts, so this does too. **These are the numbers to
argue about**, and every one of them is a ceiling.

| | Count | Note |
|---|---|---|
| Puzzle verbs | **4** | Bow, Burst, Hookshot, + T0. No fifth. Nothing new is invented to serve a puzzle |
| Puzzle atoms | **8** | Phase 1. Phase 2's four are flavour and are not committed |
| Combinators | **5** | Nest, sequence, time, displace, cycle |
| Puzzle shapes | **3** | Shortcut, critical, treasure |
| Puzzle prefabs | **12** | 4 tiers × 3 shapes. The generator picks by (floor, shape, owned verb) |
| New anchor kinds | **2** | `gate_room`, `puzzle_room` |
| Chord edges per floor | **1** | The cycle |
| **Echoes** | **12** | Named. No thirteenth, same discipline as the relics |
| **Minibosses** | **4** | One per floor, two beats each, behind the treasure puzzle |
| New UI screens | **0** | The sounding stone is a world prop, not a screen |
| New monster models | **0** | A miniboss is a scaled roster enemy, exactly as GDD §5 does bosses |

**This is a new mechanic against a manifest that said one, and it was added
without a deletion.** That is an owner's amendment, made deliberately on
2026-08-10, and it is recorded as the fourth line of `docs/SCOPE.md` §4.2's
ledger with the cost stated rather than absorbed. The jewelcrafter was on the
table to pay for it and the owner declined: the gear loop is the reason to
delve (GDD §6.6), not a service beside it.

**What the ledger asks in return is that the ceilings above do the braking.**
Eight atoms, five combinators, twelve prefabs, twelve Echoes, four minibosses.
A proposal that moves one of those numbers is back to needing a deletion.
