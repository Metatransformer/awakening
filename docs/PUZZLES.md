# Puzzles and Echoes

**Status: §2 is built (M1). §4, §5.2, §5.3, §6 and §7 are built (M4).** The nine
atoms and the door that listens are in the code —
`scripts/props/puzzle_atoms.gd` (the table and the factory),
`scripts/props/puzzle_atom.gd` (the base body), the nine files under
`scripts/props/atoms/`, and `scripts/props/puzzle_gate.gd`, proved by
`tools/directors/puzzle_atoms.gd`. The spine on top of them — the chord edge, the
gate room, the treasure puzzle, the Sluice-Keeper and the Echo pedestal — is
proved end to end by `tools/directors/puzzle_loop.gd`. See **§9, as built**.

Still design: **§5.1**, the shortcut puzzle (the door exists and is a check; the
puzzle on it is M6), and phase 2's remaining three atoms.

**The lantern (§2) and coupling (§3, combinator 6) are built**, proved by
`tools/directors/lights_out.gd`. The lantern spends one of phase 2's four slots
rather than adding a ninth line to the ceiling; nothing yet *places* a
`LanternGrid` on a generated floor.

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
| **Lantern** — any blow *toggles* it, lit ⇄ dark | T0 sword | Every OOT dungeon (the crystal switch, plus the torch's fire) | **1** |
| **Torch** — carry fire from a lit one, on a timer | T0 | Deku Tree, Fire | 2 |
| **Timed bars** — solve inside T or it resets | — | Fire, Forest | 2 |
| **Sounding set** — N tokens scattered in one room | — | Spirit, Gerudo Training | 2 |

**Phase 1 is nine props** and it covers all four tiers plus the key, which is
the whole of §1's table. Phase 2 is the flavour and none of it is load-bearing.

The ninth, the lantern, was pulled forward out of phase 2 rather than added on
top of it: it is the crystal switch's *any blow* with the torch's lit/dark state,
and it is the only atom in the kit that goes **backwards on purpose** — which is
the whole reason combinator 6 below can exist. It costs the manifest one atom
(8 → 9) and phase 2 one slot (4 → 3).

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
| Lantern | `scripts/props/atoms/lantern.gd` | any `apply_hit` — and it **toggles**, so it can be un-solved |

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
count.** Six combinators over nine atoms is where the generated feel comes
from, and it is why this document does not contain a list of forty hand-authored
puzzle rooms.

| | Combinator | Example |
|---|---|---|
| **1** | **Nest** — one atom's reward is another's input | The key is in the chest behind the eye |
| **2** | **Sequence** — trip N atoms in order | Three eyes, left to right |
| **3** | **Time** — solve inside a window or it resets | Hit the eye, reach the bars before they drop |
| **4** | **Displace** — the atom is in one room, the door it opens is in another | The plate is in the room you already cleared |
| **5** | **Cycle** — the atom is on the *far* side, and solving it opens a two-way link | You come round the loop and blast the pillar from inside |
| **6** | **Couple** — solving one atom *un-solves* its neighbours | Lights out: strike a lantern and its four neighbours flip too |

Combinator 5 is the important one and it deserves its own section.

**Combinator 6 is the only one that changes what kind of thinking the room
asks for**, which is why it earned a row against a frozen list. Under 1–5 the
atoms stay independently solvable — three eyes can be shot in any order and you
never lose ground. Under coupling you can, so the board has to be read whole
before the first blow. It is built as `scripts/props/lantern_grid.gd`, and the
one thing to know about it is that **the scramble is generated by solving
backwards**: a board dealt cell-by-cell at random is, over GF(2), usually
*unsolvable*, so the grid starts from all-lit and applies N random legal presses.
Every press is its own inverse, so solvability is a property of construction at
any grid size. The grid is **not an atom** — it hands each lantern the gate's own
`puzzle_id` and the ordinary `PuzzleGate` count does the rest.

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
  sounding stone), **a chest**, and **the cycle back toward the entrance** (§4).
- **Shape:** cycle. Always.

**Every puzzle pays in loot, not only in passage.** The chest is the owner's
amendment of 2026-08-10 and it is a rule for all three shapes, not a prop for
this one: *a solved puzzle drops something you can carry out.* A door that opens
onto more corridor is a toll booth — the player paid attention and got permission
back. This game already answers "was it worth the walk" in one currency (GDD §2,
`docs/METAGAME.md`), and a puzzle that pays in Echoes and shortcuts alone is
paying in a currency the player cannot weigh against the walk home. So:

| Shape | Passage | Echo | Loot |
|---|---|---|---|
| **5.1** shortcut | the way down | +1 | the shortcut chest |
| **5.2** gate room | the boss approach + the cycle | +1 | **a chest**, floor table |
| **5.3** treasure | the miniboss chamber | +1 | the **rich** chest, + the miniboss's own drop |

It costs nothing new: `Chest` and `Prog.chest_picks` already exist and already
know what a floor's table is worth. What it buys is that the sentence *"I solved
that"* and the sentence *"I am carrying more than I was"* are the same sentence.

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

### 6.1 The twelve

**Relics are objects and Echoes are sounds.** That is the whole naming rule and
it is worth keeping: a relic is a thing you carry to a counter — Tally-Ledger,
Anvil-Plate, Cracked Still-Head — and an Echo is a tone you carried out of a
room. If a proposed Echo wants to be a noun you could put on a shelf, it is a
relic and it is in the wrong table.

Each one **bends a rule the game already runs**, and the rule it bends is named
so the next person can find it. None of them moves damage, speed, max health,
max stamina or soak (GDD §6.6) — check the right-hand column before adding a
thirteenth, because that is the boundary that keeps a found thing from quietly
replacing a bought one.

**How fast — the Heat axis (GDD §2)**

| | Echo | What it bends |
|---|---|---|
| 1 | **The Held Note** | Heat's window stops shrinking; every tier keeps Warm's leash. The reward for speed stops coming with a shorter one — `K.HEAT_TIER_WINDOW` |
| 2 | **The Answering Strike** | A blow you **block** advances the chain by one, as a kill does. The shield becomes a tempo tool rather than a wall, and it is the same wiring that already lets a blocked blow keep the chain alive (`docs/METAGAME.md` §4.5) |
| 3 | **The Slow Fade** | Motes never cool. A stamped multiplier holds until you sweep it, so a chain can be spent on fighting instead of on tidying — `K.HEAT_COOL_TIME` |
| 4 | **The Second Wind** | A kill refunds the **whole** stamina bar, not `K.STAMINA_KILL`. A rule about kills, not the size of the bar — the stat is untouched |
| 5 | **The Blazing Tithe** | At Blazing, a killed enemy drops a **second** mote. The top tier finally pays in quantity and not only in rate |

**How deep — the space axis (GDD §2)**

| | Echo | What it bends |
|---|---|---|
| 6 | **The Unbroken Rope** | The 1.2 s extraction channel cannot be broken by a blow that lands. You can always leave, so you can always go one room further — `docs/METAGAME.md` §5 |
| 7 | **The Cold Ledger** | The fee is charged on the bag's **base** value; Heat's stamp is not taxed. This is the one Echo that cuts §2's central coupling, and it does it for exactly one run |
| 8 | **The Deep Pocket** | Common-band ingredients stack twice as high. It does not add a slot — it changes what is worth bending down for, which is the more interesting half of the bag |
| 9 | **The Quiet Room** | The first enemy in each room you enter is held for a beat. Every room opens on your terms, and a floor gets about one room deeper |
| 10 | **The Returning Shaft** | Arrows are recovered from what they kill. The bow stops being rationed, so range becomes an option at depth rather than a budget — `docs/METAGAME.md` §4.6 |

**Both axes — the two that are about the Echoes themselves**

| | Echo | What it bends |
|---|---|---|
| 11 | **The Full Cup** | A bottle drunk while **Blazing** is not spent. Speed buys back the one thing you had to purchase in the garrison, and only while the leash is shortest |
| 12 | **The Long Chord** | Offered on floor 3 or deeper only. **Every other Echo in the bag stops taking a slot.** It costs one and refunds the rest, so it is worth nothing unless you already committed — the only Echo whose value is a function of the others |

### 6.2 Why these twelve and not others

**Five push on tempo, five on depth, two on the carrying itself.** That split is
the design, not an accident of listing: GDD §2 says the one question has two
axes, and an Echo pool that leaned one way would quietly make one of those axes
the real game.

**Number 12 is the one to protect.** The Long Chord is the only Echo that makes
the *slot cost* the subject, and it is what stops a pool of twelve small rule
bends from being twelve flavours of the same shrug. A player who has taken three
Echoes and is offered the Long Chord on floor 3 has a genuinely hard read on
whether a fourth floor is coming.

**Number 7 is the one to watch in tuning.** The Cold Ledger unpicks the coupling
GDD §2 calls *the one question asked a second way* — Heat rides in the bag, so
going fast raises the fee. Cutting that is powerful and it is *meant* to be, but
it dies with the run and costs a slot, which is the whole reason found power is
allowed to exist here at all. If it proves too strong, the fix is the floor it is
offered on, never a percentage on the effect.

**What was deliberately not written:** nothing that gates, points at, or reveals a
chest — that is relic #8, the Sounding-Rod (GDD §6.2), and one drop must not do
another's job. Nothing that holds a Heat chain through a break — that is the
Sustain working (GDD §6.5). Nothing that burns a stack for soak — that is
Ballast. Nothing that changes a price at a counter — that is relic #11. **Four
near-misses, all of them rejected for the same reason: an Echo may not be a
weaker copy of something permanent.**

**The tuning values are not in this document.** "Twice as high", "a beat", "the
whole bar" become numbers in `scripts/items/echo_db.gd` beside the rows they
describe, for the reason `docs/METAGAME.md` opens with — a doc that restates a
number is a doc that will disagree with the code.

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
| Puzzle atoms | **9** | Phase 1 + the lantern, pulled forward. Phase 2's remaining three are flavour and are not committed |
| Combinators | **6** | Nest, sequence, time, displace, cycle, couple |
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
Nine atoms, six combinators, twelve prefabs, twelve Echoes, four minibosses.
A proposal that moves one of those numbers is back to needing a deletion.

---

## 9. As built (M4)

The spine, and the file that owns each piece. `tools/directors/puzzle_loop.gd`
walks all of it in one run — beats **A** (the tables validate) through **G** (the
Sluice-Keeper dies and the second stone lights).

| §  | Piece | Where |
|---|---|---|
| 4 | The chord edge | `Dungeon._plan_chord` / `_build_chord`; one per floor, ranked on (depth, span) |
| 4 | Barred from the near side only | `scripts/props/barred_passage.gd` — `BarredPassage`, refuses with *BARRED FROM THE OTHER SIDE* |
| 5.2 | `gate_room` anchor | `Dungeon._room_for(&"gate_path")` — 0.7 along the route to `deepest`, never either end |
| 5.2 | The gate itself | A `PuzzleGate` **in the doorway the floor continues through**, not on a blank wall |
| 5.2 | Floor 1's key hunt | `Dungeon._place_gate_room` — sun socket → key → door, §3's *nest* |
| 5.2 | The chest | `Dungeon._land_prize`, on `opened` |
| 5.3 | `puzzle_room` anchor | `Dungeon._room_for(&"mid_ring")`, off the critical path, always |
| 5.3 | Floor 1's treasure puzzle | `Dungeon._place_puzzle_room` — plate + block, §3's *nest* again, different atoms |
| 5.3 | The chamber behind it | `Dungeon._place_chamber` / `_build_chamber`; arena, rich chest, stone |
| 6 | The Echo pedestal | `scripts/world/sounding_stone.gd`; three `LootMote`s and three name plates |
| 6 | The twelve | `scripts/items/echo_db.gd`, `ItemDb` rows, `Run.echoes_held()` |
| 7 | The Sluice-Keeper | `BossDb.MINIBOSSES`; two beats, a scaled troll, `relic_slot = &""` |

### Three decisions worth not re-deriving

- **The gate stands in the doorway, not on a wall.** A critical-path puzzle is
  critical *by construction* that way — there is no version of the floor where
  the player walks round it. `puzzle_loop`'s beat B3 asserts the door's forward
  agrees with the route's next step.
- **The socket is not one of the gate's atoms.** The key cannot be reached
  without it, so watching both is redundant, and the refusal would name the wrong
  half — *THE SOCKET IS DARK* beside a key you can see.
- **The treasure chamber's chest and stone are outside the arena's seal ring**
  (`CHAMBER_SKIRT = 10.0`). A player sealed in with the Sluice-Keeper can see both
  rewards and reach neither. That is geometry doing a lock's job, which costs no
  code and cannot desync.

### The one atom flag that is not permanent

`PuzzleGate.flag_id()` overrides `LockedDoor`'s to write `atom_door_*` instead of
`door_open_*`. `LockedDoor`'s flag is permanent on purpose — a shortcut you opened
stays open across saves — and a **puzzle** gate wearing it would leave the gate
room open from run two onward over a puzzle that `PuzzleAtom.clear_run_flags()`
had just reset. §5.2's promise is that the gate room is a puzzle every run.
