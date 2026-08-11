# Puzzles and Echoes

**Status: §2 is built (M1). §4, §5.2, §5.3, §6 and §7 are built (M4).** The nine
atoms and the door that listens are in the code —
`scripts/props/puzzle_atoms.gd` (the table and the factory),
`scripts/props/puzzle_atom.gd` (the base body), the nine files under
`scripts/props/atoms/`, and `scripts/props/puzzle_gate.gd`, proved by
`tools/directors/puzzle_atoms.gd`. The spine on top of them — the chord edge, the
gate room, the treasure puzzle, the Sluice-Keeper and the Echo pedestal — is
proved end to end by `tools/directors/puzzle_loop.gd`. See **§9, as built**.

**§5.1 is built** — the shortcut door has stopped being a check. It is a
`ShortcutGate` (`scripts/props/shortcut_gate.gd`) watching an atom of **exactly
tier N**, proved by `tools/directors/shortcut_puzzle.gd`. Owning the Bow no
longer opens floor 1's; shooting the eye does. **And since 2026-08-11 it obeys
§0 rule 2 on both floors that have an ammunition cost**: floor 2's braced pillar
stands beside an urn of Burst charges (`scripts/world/charge_cache.gd`), proved
by `tools/directors/charge_supply.gd`. It shipped without one for a week, which
is `docs/ITEMS.md` §8 D13 and card #29.

Still design: phase 2's remaining three atoms.

**The lantern (§2) and coupling (§3, combinator 6) are built**, proved by
`tools/directors/lights_out.gd`. The lantern spends one of phase 2's four slots
rather than adding a ninth line to the ceiling. ~~Nothing yet *places* a
`LanternGrid` on a generated floor.~~ **False since the gate room's prefab table
landed; struck 2026-08-11.** `lights_out` is one of `Dungeon.GATE_PREFABS` and
`Dungeon._gate_lights_out` stands a 3×3 grid in the middle of the gate room; it
is **T0** (`_prefab_fits` asks only for `LANTERN`), so every floor can draw it.
§5.2a below has said *Built* all along, and this header said the opposite — which
is the worse of the two places to be wrong, because a reader who stops at the
status paragraph concludes that coupling is unreachable on a real floor.

**Chain (§3, combinator 7) is built**, proved by `tools/directors/chain_row.gd` —
`PuzzleAtom.propagate()` is the mechanic and `scripts/props/chain_row.gd` is the
row with the hole in it.

**Built but not placed, in one list** — checked against `scripts/world/dungeon.gd`
on 2026-08-11. They were scattered one caveat per paragraph, which is how the
grid's went stale without anyone noticing and how convert's never got written:

- **`ChainRow`.** `scripts/props/chain_row.gd` exists and nothing but
  `tools/directors/chain_row.gd` builds one. No gate, shortcut or treasure prefab
  places a row.
- **`convert` (§3.1, combinator 8).** The whole chain is in the code and none of
  it is on a floor: `Lantern.convert_kind()` and the `ConvertZone` it puts on
  `K.L_CONVERT` (`scripts/props/atoms/lantern.gd:~173`, `~348-355`),
  `Arrow._probe_convert` (`scripts/combat/arrow.gd:~239`) and `EyeSwitch.frozen`
  (`scripts/props/atoms/eye_switch.gd:~58`) all work, and `frozen` is set in
  exactly one place in the whole tree — `tools/directors/convert_arrow.gd:~173`.
  Lanterns *do* reach a generated floor now, through `lights_out`, so a fire
  arrow can be lit down there; nothing down there asks for one.
  **§10.5's worked floor-4 room is assembled from convert + nest + displace +
  reconfigure**, so that room is a design and not something the generator can
  currently build.

**§3.1 and §10 are design, added 2026-08-10** after reading the 1998 Player's
Guide end to end — `docs/OOT_CATALOGUE.md` is that pass. §3.1 adds three
combinators (6 → 9, priced in §8.1) and §10 is the **grammar**: the rule that says
which puzzles a floor may build, and why floor 4's are harder than floor 1's
without containing a word floor 1 did not have. Enemies and bosses came out of the
same pass and live in `docs/BESTIARY.md`.

This file owns the puzzle vocabulary, the grammar, the three shapes, and where
Echoes come from, and it owns nothing else.

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
| Push block | `scripts/props/atoms/push_block.gd` | shoved onto its mark, one 1.2 m step at a time — **held**, see below |
| Eye switch | `scripts/props/atoms/eye_switch.gd` | `apply_hit` with `kind == &"arrow"`, and nothing else |
| Cracked pillar | `scripts/props/atoms/cracked_pillar.gd` | `burst()` — **live since M5**; `BurstCast` walks group `&"burstable"` inside the blast |
| Hook ring | `scripts/props/atoms/hook_ring.gd` | `HookTarget.on_bitten`, from the firer |
| Sun socket | `scripts/props/atoms/sun_socket.gd` | guard up in the shaft, aimed at the socket |
| Lantern | `scripts/props/atoms/lantern.gd` | any `apply_hit` — and it **toggles**, so it can be un-solved |

**The block is held, not repeatedly bumped.** Lean into a face for 0.30 s and
the hero *takes hold of it*: he squares up on the centre-line and walks it along
at walking pace, cell after cell, for as long as the stick keeps pointing into
it — and lets go the instant it does not. That is Ocarina's block and it is the
difference between one decision and one chore per metre; a four-metre push is
four cells, and re-earning the lean and re-squaring up for each of them is the
version that makes the player argue with where they are standing instead of with
the puzzle. The delay is the price of *starting* and it is still there, so
brushing past a block does not move it. Rolling, swinging, being hit or opening
a screen all let go. Proved by `tools/directors/push_grip.gd`, which presses a
direction and never touches the block; `tools/directors/puzzle_atoms.gd` still
proves the seating the other way, by shoving it with no hero in the room.

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
| **2** | **Sequence** — trip N atoms in order | Three eyes, left to right. Built (2026-08-11, §3.2): `PuzzleGate.ordered` reading `PuzzleAtom.index`, placed by `Dungeon._gate_eye_row` |
| **3** | **Time** — solve inside a window or it resets | Hit the eye, reach the bars before they drop. **DESIGN, NOT BUILT** — there is no window, timer or reset anywhere in the puzzle stack, and §10.4 spends it on floors 3 and 4. See §3.3 |
| **4** | **Displace** — the atom is in one room, the door it opens is in another | The plate is in the room you already cleared. **DESIGN, NOT BUILT** — `PuzzleGate._adopt` walks the whole `puzzle_atom` group, so the *mechanism* is already there; **no placer puts an atom outside the gate's room.** See §3.3 |
| **5** | **Cycle** — the atom is on the *far* side, and solving it opens a two-way link | You come round the loop and blast the pillar from inside |
| **6** | **Couple** — solving one atom *un-solves* its neighbours | Lights out: strike a lantern and its four neighbours flip too |

| **7** | **Chain** — solving one atom solves its neighbours, if they are in line | A row of cracked pillars: burst the first and it walks down the row — but there is a **gap**, and you have to stand in it. Built: `PuzzleAtom.propagate()` + `scripts/props/chain_row.gd` |
| **8** | **Convert** — an atom does not solve; it **changes what your shot is** | Shoot an arrow through a lit lantern and it arrives burning, and *only* a burning arrow opens the frozen eye |
| **9** | **Reconfigure** — the atom moves walls, not doors | The maze room, and the floor-wide version of it |

Combinator 5 is the important one and it deserves its own section.

**Combinators 2 and 6 are the two that change what kind of thinking the room
asks for**, which is why 6 earned a row against a frozen list. Under 1, 4 and 5
the atoms stay independently solvable and you never lose ground. Under coupling
and under sequence you can, and the difference between those two is worth
keeping: **coupling asks you to read the whole board before the first blow;
sequence asks you to read one thing off the row and then not be greedy.** A
player who walks into a lights-out grid cannot see the answer, and a player who
walks into an ordered row can — the ordering is left to right along a wall, and
the door says which one is next. That is why sequence is a floor-2 puzzle and
coupling is not a floor-4 one; neither is *harder*, they are different questions.

(This paragraph read *"combinator 6 is the ONLY one … three eyes can be shot in
any order and you never lose ground"* until 2026-08-11, and it was true of the
code when it was written: `_gate_eye_row`'s own header said *"sequence, relaxed
to 'all of them'"*. §3.2 is what changed it.)

Coupling is built as `scripts/props/lantern_grid.gd`, and the
one thing to know about it is that **the scramble is generated by solving
backwards**: a board dealt cell-by-cell at random is, over GF(2), usually
*unsolvable*, so the grid starts from all-lit and applies N random legal presses.
Every press is its own inverse, so solvability is a property of construction at
any grid size. The grid is **not an atom** — it hands each lantern the gate's own
`puzzle_id` and the ordinary `PuzzleGate` count does the rest.

**Solvable is not the same as finishable, and a playtest found the gap
(2026-08-10).** A player worked a board down to one dark lantern, swung at it,
and watched it light and its four neighbours go out. That board is not one press
from done — on a 3×3 it is four or five, none of them on the dark lantern — but
it *looks* like the last step, so the room reads as a puzzle that undoes itself.
Every state is solvable (3×3 is non-singular, all 512 boards), which means the
room was never stuck; the player was, and from inside the room those are the same
thing. Two changes, both in `lantern_grid.gd`:

- **The deal presses distinct CORNERS.** A corner's cross is three cells, so the
  board reads as L-shapes rather than noise; the answer is then corners all the
  way down, so **the last step is always a corner**; and corner presses are
  closed over corners and edges, so a player who only hits corners stays in a
  16-board subspace that always contains the solved board and **can never reach
  the one-dark trap**. Boards come out 2–3 presses deep, which is the right size
  for a T0 gate on floor 1.
- **After eight presses that do not finish it, the grid points** — one lantern's
  brass breathes, re-picked after each blow, preferring a corner. Coupling is the
  combinator that lets you lose ground, and an action game hands the player no
  notepad.

Also: **one swing is one press for the board**, not just per post. `HeroCombat`
damages everything under the blade in a single pass and the spin's sphere is
2.1 m across a full circle, so without the guard one spin in the middle of a
2.3 m grid presses four lanterns at once. A light swing cannot — the sphere
reaches 1.14 m past its centre — which is exactly why it would have shipped.

### 3.1 Combinators 7–9 — read off Ocarina, 2026-08-10

**Design, not built.** These three came out of reading the 1998 Player's Guide
end to end and writing down every puzzle in all nine dungeons —
`docs/OOT_CATALOGUE.md` is that pass, and its §4 is the shortlist these three
were drawn from. They move `docs/SCOPE.md`'s combinator count from **6 to 9**,
which is scope creep by that document's own definition; §8 below states the bill
rather than absorbing it.

**Nothing here adds an atom.** That is the test they were chosen to pass. Ocarina
is not a game with many props — it is a game that says a lot with few, and every
one of these three is a new *sentence*, not a new *word*.

**7 — Chain. BUILT, 2026-08-10** — §9's table has the files and
`tools/directors/chain_row.gd` is the proof. One atom's solve propagates to the
next along a line of sight, inside a radius. Dodongo's Cavern runs a row of bomb
flowers this way and puts a **deliberate gap** in the middle, so the player has
to supply one link themselves. That gap is the whole puzzle: without it, chain is
a domino topple you watch. With it, chain is *where do I stand*, which is the one
question none of combinators 1–6 asks. It is also the natural home for the T2
cracked pillar, which was one prop that did one thing.

The mechanic is `PuzzleAtom.propagate()` and it is one rule: everything in group
`puzzle_atom` that shares this link's `chain_id`, is inside `chain_radius`, and
can be reached by a ray on `L_WORLD` drawn between the two atoms' chest heights,
gets `solve()` called on it. **It is delayed by `chain_delay` (0.45 s)** — a row
that goes over in one frame is a single prop with five meshes, and what makes
chain a combinator is that the player watches the answer walk away from them down
the row. The delay also unrolls the recursion across frames, so the re-entrancy
guard §8.1 priced is belt and braces rather than the only thing holding a ring
together; it is still there, because `chain_delay` is an export and a placer may
set it to zero.

`ChainRow` is what makes it a *puzzle*, and it is a placer, not an atom — the
same shape `LanternGrid` has and for the same reason: it hands each link the
gate's own `puzzle_id` and the ordinary `PuzzleGate` count does the rest. **Four
numbers, in one narrow window:**

```
K.BOMB_RADIUS  <  spacing  <=  chain_radius  <  gap  <=  2 * K.BOMB_RADIUS
     1.94            2.6            3.0          3.7          3.88
```

One blast is never worth two pillars; a fall carries to its neighbour; a fall
does **not** carry across the hole; and a player standing in the hole can reach
both lips of it, which is what "supply the missing link yourself" means when the
thing you are holding is the Burst-Verse. `ChainRow.problems()` checks all four,
because a gap 0.2 m too wide is a room that generates, builds, photographs
perfectly and has no puzzle in it.

The window is narrow on purpose and it has a consequence: **the hole is always
less than two normal spacings wide**, which reads as five unevenly spaced pillars
rather than as a hole. So the row leaves the *base* of the missing link standing
in the gap — the same mark a fallen pillar leaves (`CrackedPillar`: *the base
stays; it is the thing that says a pillar USED to be here*). The gap then says,
before the player has toppled anything, the sentence the rubble says afterwards.

What it costs the player is the actual design: **a five-link row with one gap is
two casts.** Not five, which is what it costs with no chain, and not one, which is
what it costs with no gap.

**8 — Convert, and it is the important one. BUILT, 2026-08-10** — §9's table has
the files and `tools/directors/convert_arrow.gd` is the proof. An atom that is not a lock. You
shoot *through* it and your arrow arrives as something else; the lock on the far
side only accepts the something else. Ocarina does this twice — Forest Temple's
ice-covered eye switch and the Water Temple's torches — and both times the effect
is the same: **a lower-tier item answers a higher-tier question.**

That is worth more to this design than it was to Ocarina, because §0 rule 1 is a
real constraint here and convert is the only thing in the catalogue that relaxes
it honestly. A floor-2 room may pose a question that *looks* like it needs Burst,
and be answerable with the Bow the player already has plus a lantern on the sight
line. The player has not been handed a shortcut; they have been handed a longer
sentence in a vocabulary they already own. **This is the mechanic that makes a
four-verb game feel like a nine-verb game**, and it costs one flag on `HitInfo`
and one prop that already exists.

**9 — Reconfigure, which we have already built and never named.** The atom moves
*walls*, not doors: §5.4's maze room is exactly this and it shipped without the
word. Naming it is not bookkeeping — it is what makes the **floor-scale** version
sayable. The Water Temple sets three water levels from three stations and every
door in the dungeon changes meaning; the Forest Temple's basement spins a whole
ring of walls. The room-scale version is on disk. The floor-scale version is one
lever that re-runs `Dungeon`'s barred-passage pass, and it is the single biggest
"this floor is not like the last one" available for the price.

> **The rule that keeps this at nine.** A proposed combinator must change *what
> the player is thinking about*, not what they are aiming at. Couple earned its
> row because it made the board something you read before your first blow. Chain
> asks where to stand, convert asks what route the shot takes, reconfigure asks
> which room to make. A tenth that is "sequence but harder" is sequence.

### 3.2 Combinator 2 — sequence, built 2026-08-11 (card #44)

**Built.** The seam was already cut and read by nothing: `PuzzleAtom.index` was
exported and already set by `lantern_grid.gd`, `chain_row.gd` and `maze_room.gd`,
and its own comment said *"only the flag reads it"*. Now the door reads it too.

| Piece | Where |
|---|---|
| The switch | `PuzzleGate.ordered` — off by default, and a **no-op unless a placer sets distinct indices**, because every atom in the kit is born at `index = 0` |
| The rule | `PuzzleGate._out_of_turn()` — an atom answered out of turn is one with something of **its own kind**, lower in the run, still unsolved |
| The punishment | `PuzzleGate._break_the_sequence()` — the whole run goes back, not just the offender |
| Going backwards at all | `PuzzleAtom.reset()`, and it **erases the `atom_*` flag** with the light. `unsolve()` refuses a latching atom on purpose; a third case was needed, and a flag left written would bring the row back lit on the next rebuild inside the run |
| The eye shutting | `EyeSwitch.on_unsolved()` — it slams, in half the time the open takes and with no overshoot, because the read is *you lost that* |
| The line | `PuzzleAtoms.refusal_next_for()` → *THE 1ST OF 3 EYES IS NEXT*, reached through `PuzzleAtom.refusal_next()` so a variant can override it |
| The room | `Dungeon._gate_eye_row` — `gate.ordered = true`, the eyes handed to the door with `watch()`, `index` running **left to right as the player reads the wall** |
| The proof | `tools/directors/gate_eye_row.gd` beats **J** (right to left: the row goes dark, the door names the 1st of 3, and a lit eye is taken back off you) and **K** (left to right: the key wakes) |

**No count in `docs/SCOPE.md` moved.** Sequence was already one of the nine §8
commits to; this is a row of that manifest being made true, not a tenth of
anything. No new atom, no new prop, no new placer — `_gate_eye_row` already
existed and gained four lines.

**Two decisions worth not re-deriving.**

- **The order is per KIND, not across the gate's whole set.** A gate room's set is
  three eyes *and* a small key; ordering those together would mean picking up the
  key out of turn undid the row that produced it. Two runs of different atoms in
  one gate are independent sequences.
- **The eyes join the door's atom set, and §9's fourth decision says the sun
  socket must not.** Both halves of that decision invert here. A sequence has to
  be counted somewhere and `PuzzleGate` is the thing in this project that counts
  atoms; and the gate room's key is `visible = false` until the row is finished,
  so there is no key in sight for the eye to be *the wrong half of*. The door
  names an eye while the row is unfinished and the key the moment it is not, and
  that handover is automatic — `PuzzleGate._the_sequence()` skips a kind with one
  member.

### 3.3 Combinators 3 and 4 — time and displace, **design, not built**

Stated here in the same voice §3.1 uses for 7–9, because §3's table above is
written in the present indicative and a reader of §10 was entitled to believe it.
Card #44 is the audit that found them.

**3 — Time. No mechanism at all.** There is no window, no timer and no reset
anywhere in `puzzle_atom.gd`, `puzzle_gate.gd` or `puzzle_atoms.gd` — a grep for
*reset / Timer / timeout / window* over the three returns one hit, and it is
combinator 7's `chain_delay`. It is also the only member of §10.3's **Temporal**
kind, so an entire kind of the grammar has zero mechanism while §10.4 budgets it
"maybe" on floor 3 and "yes" on floor 4. Both of those cells now say so.

It is deliberately **not** built alongside sequence. The obvious body for it is
phase 2's `Timed bars`, which §8's manifest has never committed and which §8.1
offers up as the *deletion* that pays for chain and convert — so building time
means either reopening that atom or inventing a ninth-and-a-half prop, and either
one is a `docs/SCOPE.md` decision rather than an implementation.

**4 — Displace. The mechanism exists; nothing places it.** `PuzzleGate._adopt`
walks the whole `puzzle_atom` group by `puzzle_id` and does not care which room a
match is standing in, and `watch()` is public for exactly the case where a gate's
atoms live somewhere else. What is missing is a placer: **every prefab in
`Dungeon` puts its atoms in the gate's own room.** This is the cheapest of the
three unbuilt rows and the one with the largest design question attached — an
atom in a room you already cleared is only fair if the room told you it mattered,
which is the thing §10.5's worked room leans on hardest.

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

**As built.** `Dungeon._place_shortcut` builds a `ShortcutGate` and one atom
beside it; `tools/directors/shortcut_puzzle.gd` is the proof, 54 checks.

- **The pool is three prefabs, not four**, and that is §1 rather than an
  omission. Floor N's shortcut key is floor N's boss item, and tiers 1/2/3 hold
  exactly one gating atom each — so `_shortcut_pool()` returns a single answer
  per floor and there is nothing to roll. **Floor 4 stays a plain `LockedDoor`:**
  the Far Lantern has no verb and never gets one, so its shortcut is a pure lock.
  Three is under §8's ceiling of 12 and moves no number.
- **The gesture does not vary by seed**, unlike `GATE_PREFABS`. GDD §5.3 asks for
  *ninety seconds on your fifth run*, and a shortcut that re-rolls its verb every
  descent is a shortcut you have to read every time.
- **It never promises what it cannot pay.** `LockedDoor` flips its prompt to
  *TO OPEN* the moment you acquire the key item; `ShortcutGate` overrides
  `_on_item_acquired` so the door goes on naming the atom — *THE EYE IS SHUT* —
  with the Bow in hand and the eye unshot.
- **The flag is `LockedDoor`'s, not `PuzzleGate`'s.** `door_open_shortcut_N` is
  permanent and saved, so a shortcut proved once stays open for ever, while the
  eye beside it is `atom_…` and resets every run with the rest of them. The door
  refuses to be re-adopted once open, so the reset atom cannot re-lock it.
- **Wall-mounted atoms stand off the masonry** — `Dungeon.WALL_STANDOFF`. See
  §9's decisions.

| Floor | Key | Atom | Prefab |
|---|---|---|---|
| 1 | Bow | `eye_switch` | `eye_high` — eye at 2.05 m, above the sword's reach, with an urn of arrows beside it (§0 rule 2) |
| 2 | Burst | `cracked_pillar` | `pillar_brace` — a pillar standing in the door's own mouth; the fall is the opening. An urn of **charges** stands wide of the doorway (§0 rule 2, and see below) |
| 3 | Hookshot | `hook_ring` | `ring_span` — a ring over the lintel |
| 4 | Far Lantern | — | none; a plain lock (§1) |

**Rule 2 is not decoration on the eye row, and floor 2 shipped a week without
it** (card #29, `docs/ITEMS.md` §8 D13). Burst charges are sold in the garrison
and nowhere else, so `pillar_brace` was a gate whose only answer could not be
obtained underground — the exact dead end §0 forbids. It now carries a
`ShortcutCache`: an `Urn` with `holds = &"charges"`, spilling a `ChargeCache`
(`scripts/world/charge_cache.gd`, `ArrowBundle`'s shape for the working).

Three things about it are load-bearing and none is obvious:

- **It stands clear of the blast.** 2.66 m from the pillar against a 1.94 m
  `K.BOMB_RADIUS` — an urn inside the radius is an urn destroyed by the cast that
  needed what was in it, which is the dead end again with one extra step.
- **It holds two, not one.** One charge and one missed arc puts the player back
  in front of the pillar with nothing. Two is still under `AlchemyDb`'s batch of
  three, so the floor is not a cheaper counter.
- **A sword opens it, because a sword is all a cold start guarantees** — and the
  ring has to be stepped back onto the sword to swing, since a drawn working owns
  both shoulder buttons (`HeroCombat._tick_light_button`).

`tools/directors/charge_supply.gd` is the proof and it grants itself nothing:
`Game.reset()`, the item but never its ammunition, and every charge it spends came
off the floor.

**It pays §5.2's amendment**, which is a rule for all three shapes: the landing
behind the door holds the way down, **a chest**, and a sounding stone offering
three Echoes. Both land on `opened`, and both are restored on a later run where
the door comes up already open and `opened` never fires — §6 pays the Echo for
*taking* the shortcut, not for having once solved it.

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


### 5.2a The gate room's prefabs

**Built.** `Dungeon.GATE_PREFABS`, one placer function each, picked by
`PuzzleAtoms.pool(tier)` so a prefab never appears on a floor whose verb the
player cannot own (§0 rule 1).

| Prefab | Tier | The puzzle |
|---|---|---|
| `sun_nest` | T0 | A beam off the grate, bounced off the **shield** into a socket |
| `lights_out` | T0 | A 3×3 lantern grid, §3's *couple* |
| `eye_row` | T1 | Three eyes along **the wall opposite the door**, shot back down the room with the **bow**, **left to right and in that order** (§3.2), with an urn of arrows beside the gate (§0 rule 2) |

**Rule 2 is harder here than at either shortcut, and `eye_row` shipped without
it** (card #43). A shortcut is optional by construction — a player who cannot
open it walks the long way — but the gate stands *in the doorway the floor
continues through*, so a bow puzzle with no arrows in the room is a floor that
ends. Arrows do reach a generated floor by other routes (`Dungeon.arrow_chance`
per room, chests, `Fletching.RECIPE`) and every one of them is a **probability**,
which is exactly what §0 rule 2 exists to refuse; card #29 made the same argument
about scattering Burst charges.

`GateUrn` holds **`Dungeon.EYE_ROW_ARROWS` = two per eye, six**, and the ratio is
`ShortcutCache`'s applied to a row of three: every required shot may be missed
once. It is written as `EYE_ROW_EYES * 2` rather than as `6` or as
`ArrowBundle.FLOOR_COUNT` — which happens to be the same number today — because
that constant is tagged `[tune]`, and a pass that took it to four would silently
thin the critical path with nothing in either file saying the two were related.
Six is still the *tightest* urn in the game per shot it pays for:
`_shortcut_eye_high` hands the same six over for a single eye.

It stands 2.6 m off the door line (clear of the doorway the floor continues
through and of the leaves' swing) and 2.2 m out from the gate on the near side —
in the same look as the refusal — which is 13.3 m behind the row it supplies, so
it is never in the firing line. `tools/directors/gate_eye_row.gd` is the proof and
it grants itself nothing: `Game.reset()`, the Bow but never its ammunition, the
quiver photographed at zero *before* the urn, and every arrow it fires came off
the floor and went through the real trigger.

**Every prefab ends by waking the key**, and that invariant is what makes the
table safe to add under a shipped door. The gate keeps watching one key and keeps
`needs_key`. The room varies; the reward path does not.

**`eye_row` is the one prefab whose door counts more than the key**, since §3.2:
a sequence has to be counted somewhere, and the door is the counter this project
has. It is still `needs_key`, it still spends the key at the door, and the
refusal still names the only thing the player can act on — while the row is
unfinished that is an eye (*THE 1ST OF 3 EYES IS NEXT*), and the frame the row
completes the key appears and the line becomes *NEEDS A KEY*. The other two
prefabs are unchanged and their doors still count exactly one atom.

`--gate-prefab=<name>` forces one, because the pick is seed-driven and a director
that could only photograph its own seed's draw would ship the other two unproven.

---

### 5.4 The maze room — *the map is not the answer*

**Built.** `scripts/world/maze.gd` (the carve, no nodes), `scripts/props/maze_room.gd`
(the same grid stood up in `KitWall` masonry), proved by `tools/directors/maze.gd`.

- **Where:** a room of the floor's own tree, not an anchor — but built **wider
  than the rest of it**, `Dungeon.MAZE_ROOM` (27 m square, ~3x the ordinary
  room's floor), the way the deepest room is built wider for a boss. It still
  costs the §8 manifest nothing: no new anchor kind, no new atom, no new
  mechanic. The room is chosen in `Dungeon._plan_maze`, before `_build`, because
  a room's masonry is laid to a width and a maze cannot be dropped into a room
  that was already built too small for it.
- **Shape:** a perfect maze (recursive backtracker — long corridors, few
  junctions, because a maze you read by *walking* is the one the minimap cannot
  hand you), carved so that the prize in the deepest cell is **walled off as
  dealt**. 5 by 5 cells at `MazeRoom.CELL`.
- **Scale, and why it was wrong at first.** `CELL` was 3.1 m and the grid 4 x 3,
  both of them dictated by fitting inside a 16 m room. That is a hedge maze: a
  2.6 m corridor against a 1.65 m hero keeps both walls inside the camera's boom
  the whole time, and nine cells means every cell is a turn. The cell is 4.03 m
  now — **30% wider**, ~3.5 m of clear floor — and the room is sized to the maze
  instead of the maze to the room. Long enough between decisions that the layout
  registers as a layout.
- **The verb:** two lanterns (§2) by the mouth. Striking one opens the wall it
  owns and **shuts the next one along** — §3's *couple*, the same combinator the
  lights-out grid uses, so the player cannot simply open everything.
- **One doorway, and the mouth turned to face it.** The rim closes the grid on all
  four sides and cuts **exactly one hole** — the mouth — and `Maze.plan`'s
  solvability proof is about *that* room. So the maze takes only a room of the tree
  with a single doorway, and `Dungeon.place_maze` rotates it so its hole faces that
  doorway. Two holes would be a different room and a different proof; see the
  paragraph below on floor 3.
  This is the leaf the shape already assumed — "the reward is on the far side and
  the lock is the geometry" only reads as a puzzle in a room you enter and leave by
  the mouth — and until 2026-08-11 nothing enforced it. The cost is that a floor
  whose spare rooms all have two doorways gets no maze; `_plan_maze`'s warning says
  so, with the counts, and `_room_for(&"mid_ring")` breaks its own ties away from
  one-doorway rooms so the treasure anchor does not take the only candidate.
- **The apron:** a band of clear floor on the mouth side, `MazeRoom.APRON`, that
  the lantern row stands in. It is a named constant and `Dungeon.pick_maze_cell`
  asks `MazeRoom.fits` about it, because the depth of the maze and the depth of
  the apron come out of the same room and the version of this that did not count
  it put both lanterns **through the room's south wall on every floor**.

**A plain maze is not a puzzle in this game and shipping one would be a mistake.**
This game has a minimap: it answers a static maze for free, and what is left is
the walk. The room is a puzzle only because something *changes* it — the map
shows the maze that is, and the question is which maze to make.

**The trap, which is the mirror of the lights-out one.** A gate layout can be
legal-looking and unsolvable: `MazeRoom` opens the pressed gate and shuts the
next, so the configurations a player can actually build are *all-shut* and
*exactly-one-open* — and nothing else. A layout whose only solution needs two
gates open at once generates, builds, lights, and refuses forever, and every
frame of it looks right. `Maze.plan` therefore tests the reachable set, not
"every gate open", and re-deals until the layout is both shut as dealt and
solvable through a press. The director walks the hero mouth to prize against the
real colliders, because a corridor this narrow cannot be photographed.

**And the grid is not the room — the two ways that bit, 2026-08-10.** `Maze` is
integers and `MazeRoom` is masonry, and the room shipped for a while disagreeing
with the proof in two places at once, both of them invisible in every frame:

- **The lanterns stood outside the room.** They were planted a flat 3 m past the
  mouth with nothing checking the room had 3 m to give, and on a 16 m room they
  landed a metre behind the south wall. Unreachable, so the maze could not be
  opened, so the chest — which hangs on `opened` — never landed. The minimap
  marked a chest in a room that had none. Fixed by `MazeRoom.APRON` and
  `MazeRoom.fits`, and by beats `G3a`/`G3b`, which put the hero on his feet and
  make him *walk* to a lantern instead of pressing it by reference.
- **The maze had no south or east rim.** `Maze.walls` stores a north bit and a
  west bit per cell, which covers the interior exactly once and cannot express
  the two far edges — so they were never built, and the maze stood open along two
  of its four sides while `Maze.reach`, which only ever steps between cells,
  proved a sealed one. Fixed by `MazeRoom._build_rim`, and beat `A3` counts the
  rim off the **wall nodes' positions** rather than off the grid, because every
  beat that asks the grid agreed with the grid.
- **And the third, 2026-08-11: the room the maze took had four doorways.** One
  rim hole, four openings — so the rim stood across the other three. On floor 3 the
  maze landed on the path to the Bellwake and sealed the west door the critical
  path arrives by *and* the east door to the leaf behind it: the boss chamber, the
  deep chest and the way down all unreachable on foot, in the game, not just for a
  director. `cistern_floor --level=3` reported eleven red checks of which one was
  the fault and ten were a hero stranded at `W_5_2`. Fixed by the one-doorway rule
  above and by rotating the mouth, both asserted in `maze.gd` beats `G3c`/`G3d`.
  This is the same failure as the two above — the grid's proof describing a room
  nobody built — arrived at from outside the room instead of inside it.

**Enemies come after, not instead.** Monsters in a static maze are a tax on a
walk, not a puzzle — they do not stop the minimap answering it. Corridors are
sized to swing a sword in for when they arrive.

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
| 4 Chord Gate | **The Gate-Hound** | `kobold`, ×1.4, iron-dark | **Retreat.** Backs across a gap and lobs from the far side. **Hookshot** closes it ~~, or freezes it where it stands~~ (GDD §5.2) — the freeze half was never built and should not be; see the fourth departure below | **Overhand.** A heavy committed slam. Rolled, not blocked — the one beat in the set the shield does not answer |

**The Placeholder column is a sketch, and `BossDb.MINIBOSSES` is the record.**
All four rows are built (2026-08-10) and ~~three of them departed~~ **four things
in the table above departed** from what shipped, each time for a reason the table
writes down at the row:

- **The multipliers are not heights.** `kobold` ×1.4 is 1.89 m, which is
  *shorter than an ordinary orc*, and the whole point of a miniboss is that it
  reads as bigger than the roster. The Gate-Hound is authored at **2.30 m**. The
  table stores metres, never a factor.
- **The Second Voice has no pillar.** A resonating pillar is a *puzzle atom*
  standing in an arena, which needs a new prop and a new `arena` key, and §8.1
  caps the atoms at nine. "Cannot be touched" is an invulnerability gate, which
  is a new mechanic. So the ring it sings **is** the wall — a floor band with a
  wide safe middle, answered by the Burst from outside it.
- **The Bellows-Hand's plate is a distance, not an invulnerability.** Its
  advance only comes out from 5 m, which is where the bow lives and the sword
  does not.
- **The Gate-Hound is not frozen where it stands** *(added 2026-08-11 — the row
  above advertised a freeze that nothing has ever built)*. `Boss.freeze()`
  (`scripts/actors/enemies/boss.gd:~1117-1120`) overrides the chain to play
  `hit_armor` and return — *"the barb rings off the plate and buys nothing"* — on
  the same poise argument that refuses every blow: a hookshot that could cut a
  tell short is a beat the player can delete, and one that could cut a punish
  short takes the window away from them. **The pull is the answer and the freeze
  is not**, which is what `BossDb`'s `gate_shard` beat says at its own row: the
  `min_range` of 5.0 IS the lock, because a beat that cannot be picked from
  inside five metres is deleted by closing the gap rather than merely survived.

**Every telegraph obeys GDD §7**: it never compresses past 60% however deep the
floor is. A miniboss that becomes unreadable at depth is a miniboss that has
stopped being a design and started being a wall. Measured across the built rows
(`tools/directors/minibosses.gd`, section C): arc 73.9%, zone 76.2%, slam 121%.

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
| Combinators | **9** | Was 6. Nest, sequence, time, displace, cycle, couple, **+ chain, convert, reconfigure** (§3.1, 2026-08-10). One of the three is already on disk under another name — §5.4's maze room *is* reconfigure. **7 of the 9 are built**: *time* has no mechanism at all and *displace* has no placer (§3.3, card #44). The ceiling is still 9 |
| Puzzle shapes | **3** | Shortcut, critical, treasure |
| Puzzle prefabs | **12** | 4 tiers × 3 shapes. The generator picks by (floor, shape, owned verb). **6 built**: `Dungeon.GATE_PREFABS` — sun nest (T0), lights out (T0), eye row (T1); `Dungeon.SHORTCUT_PREFABS` — eye high (T1), pillar brace (T2), ring span (T3). The shortcut shape is **three, not four**, and stays three: floor 4's key is the Far Lantern, which §1 gives no verb (§5.1) |
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
Nine atoms, nine combinators, twelve prefabs, twelve Echoes, four minibosses.
A proposal that moves one of those numbers is back to needing a deletion.

### 8.1 The 6 → 9 combinator amendment, priced

`docs/SCOPE.md` §4.2 wants the bill stated, so: **three combinators, no new
atoms, no new items, no new screens, no new models.** The bill is engineering and
it is small, which is exactly the argument every bad amendment also makes — so
here is the specific work, per row, so it can be checked rather than believed.

| | Combinator | What it actually costs | Free because |
|---|---|---|---|
| 7 | **Chain** | One `propagate()` on `PuzzleAtom`: a radius, a line-of-sight ray, and a re-entrancy guard so a ring of atoms does not stack-overflow | The atoms already emit `solved`; chain is a second listener on a signal that exists |
| 8 | **Convert** | One `StringName` on the projectile's `HitInfo` (`arrow` → `arrow_fire`), one `Area3D` on `Lantern` that rewrites it in flight, and one `refusal` string on the atom that only accepts the rewritten kind | `EyeSwitch` already refuses on `kind != &"arrow"`. Convert is that same check with a different constant |
| 9 | **Reconfigure** | **Zero at room scale — it is shipped.** `MazeRoom` moves walls and colliders off a lantern press today. The floor-scale version is one lever that re-runs `Dungeon`'s barred-passage pass | §5.4 |

#### What row 8 actually cost, once built (2026-08-10)

The bill above was right about the shape and short by three items. Written down
so the next amendment is priced against what building one really costs.

| | Priced? | What it was |
|---|---|---|
| `Hit.ARROW` / `Hit.ARROW_FIRE`, and `Arrow._kind` | yes | One `StringName`, exactly as quoted |
| `Lantern.ConvertZone` + `convert_kind()` | yes | One `Area3D`, and the "only while lit" rule lives on the lantern rather than in the projectile |
| `EyeSwitch.frozen` + its `refusal()` override | yes | The same tier check with a different constant. **A variant, not a row** — the kit is still nine and `PuzzleAtoms.validate()` still asserts it |
| **Collision layer 9, `K.L_CONVERT`** | **no** | `Arrow`'s flight query masks `interact` and *stops* on it. A convert volume on any existing bit is a flame the arrow sticks in. One bit, one extra ray a frame (`Arrow._probe_convert`) |
| **`Lantern`'s collider shortened to the post** | **no** | It was one cylinder over post *and* cage, so "shoot **through** it" was geometrically impossible. The cage is a window now. The post is still 1.55 m of obstacle and the sword still finds it — `sword_contact`, `lights_out`, `maze` and `puzzle_atoms` all pass unchanged |
| **`PuzzleGate.refusal_line` asks the atom** | **no** | It composed its line from the static table, so an overridden `refusal()` was written, correct and **unreachable** — CLAUDE.md §3's static-dispatch row. Without it a door onto a frozen eye says *THE EYE IS SHUT* to a player who has just put an arrow in it, which is the exact failure GDD pillar 3 forbids, and no assertion made on the prop can see it |

#### What row 7 actually cost, once built (2026-08-10)

Closer to its quote than row 8 was, and the two things it was short by are both
about the puzzle rather than the mechanic.

| | Priced? | What it was |
|---|---|---|
| `PuzzleAtom.propagate()` — radius, sight ray, guard | yes | Exactly as quoted, plus `chain_links()` split off it so a proof can assert the topology without toppling the row it is asking about |
| `chain_id` beside `chain_radius` | **no** | `puzzle_id` cannot key a chain — a gate room's whole point is that its atoms share one tag, so two rows in one room would be one chain. One `StringName`, empty by default |
| `chain_delay`, and the fall being a WALK | **no** | A row that topples in one frame is one prop with five meshes. It is also what unrolls the recursion the guard was priced for |
| **`ChainRow`, the placer** | **no** — and it is the row's real cost | The mechanic is not the puzzle. The gap, the four-number window that makes it a gap, and the empty socket that makes the gap legible are ~200 lines, and none of it is a prop: `ChainRow` builds nine atoms it did not invent and the gate counts them without knowing it exists |

The last one is the honest correction to the quote: **"one method on `PuzzleAtom`"
was the price of the mechanic, not of the combinator.** A combinator is still not
allowed a prop of its own — `ChainRow` places, it does not exist in the kit and
`PuzzleAtoms.validate()` still asserts nine — but it is allowed a placer, exactly
as coupling has `LanternGrid`. Price the next one that way.

The three unpriced items in row 8 are all *plumbing that already disagreed with
the design*, not scope: a projectile that could only ever be stopped, a lantern that
could only ever be hit, and a door that could only ever read a table. None of
them is a prop and none of them is a verb.

**What it does not buy, and must not be allowed to buy:** a tenth atom. Every one
of the three is a way to make the nine props on disk say more, and the moment a
combinator arrives needing a prop of its own it has stopped being a combinator.
That is the ceiling this amendment is willing to be held to.

**The honest counter-argument, written down so nobody has to rediscover it:**
this is the *third* amendment to a manifest whose own §4.2 says a third should be
hard. The defence is that combinators are the cheapest variety this project can
buy — §3 opens by saying so, and the twelve-prefab count only survives because
combinators do the work forty hand-authored rooms would otherwise do. If that
argument is not good enough, **the deletion available is phase 2's three
remaining atoms** (torch, timed bars, sounding set, §2), which were never
committed and which chain and convert make largely redundant: a lantern that
converts a shot *is* the torch, and chain across a timer *is* timed bars.

---

## 9. As built (M4)

The spine, and the file that owns each piece. `tools/directors/puzzle_loop.gd`
walks all of it in one run — beats **A** (the tables validate) through **G** (the
Sluice-Keeper dies and the second stone lights).

| §  | Piece | Where |
|---|---|---|
| 4 | The chord edge | `Dungeon._plan_chord` / `_build_chord`; one per floor, ranked on (depth, span) |
| 4 | Barred from the near side only | `scripts/props/barred_passage.gd` — `BarredPassage`, refuses with *BARRED FROM THE OTHER SIDE* |
| 5.1 | The shortcut door, no longer a check | `scripts/props/shortcut_gate.gd` — `ShortcutGate`, a `PuzzleGate` keeping `LockedDoor`'s **permanent** flag |
| 5.1 | The pool, exactly tier N | `Dungeon._shortcut_pool` / `_shortcut_tier`; one atom per floor, no seed roll |
| 5.1 | The three prefabs | `Dungeon.SHORTCUT_PREFABS` — `_shortcut_eye_high` (T1), `_shortcut_pillar_brace` (T2), `_shortcut_ring_span` (T3) |
| 5.1 | The room that brings its own ammunition | `_shortcut_eye_high`'s `ShortcutUrn`, `_shortcut_pillar_brace`'s `ShortcutCache` and `_gate_eye_row`'s `GateUrn` — §0 rule 2 at both shortcuts *and* on the critical path |
| 5.1 | Charges on a floor | `scripts/world/charge_cache.gd` — `ChargeCache`, `Urn.holds = &"charges"`; proved by `tools/directors/charge_supply.gd` |
| 5.1 | The landing's chest and stone | `Dungeon._land_shortcut_rewards`, on `opened`, with the already-open restore |
| 5.2 | `gate_room` anchor | `Dungeon._room_for(&"gate_path")` — 0.7 along the route to `deepest`, never either end |
| 5.2 | The gate itself | A `PuzzleGate` **in the doorway the floor continues through**, not on a blank wall |
| 5.2 | Floor 1's key hunt | `Dungeon._place_gate_room` — sun socket → key → door, §3's *nest* |
| 5.2 | Arrows for the eye row | `_gate_eye_row`'s `GateUrn` — `Dungeon.EYE_ROW_ARROWS`, two per eye; proved by `tools/directors/gate_eye_row.gd` beats E–I |
| 5.2 | The chest | `Dungeon._land_prize`, on `opened` |
| 5.3 | `puzzle_room` anchor | `Dungeon._room_for(&"mid_ring")`, off the critical path, always |
| 5.3 | Floor 1's treasure puzzle | `Dungeon._place_puzzle_room` — plate + block, §3's *nest* again, different atoms |
| 5.3 | The chamber behind it | `Dungeon._place_chamber` / `_build_chamber`; arena, rich chest, stone |
| 6 | The Echo pedestal | `scripts/world/sounding_stone.gd`; three `LootMote`s and three name plates |
| 6 | The twelve | `scripts/items/echo_db.gd`, `ItemDb` rows, `Run.echoes_held()` |
| 7 | The Sluice-Keeper | `BossDb.MINIBOSSES`; two beats, a scaled troll, `relic_slot = &""` |
| 3.1 | **Chain** — one solve carries to the next | `PuzzleAtom.propagate()` / `chain_links()` / `_can_see()`; `chain_radius`, `chain_id`, `chain_delay` |
| 3.1 | The row with the hole in it | `scripts/props/chain_row.gd` — `ChainRow`, and `problems()` is the four-number window |
| 3.1 | The mark that says where the link is missing | `ChainRow._build_socket()` — the base of the pillar that is not there |
| 3.1 | **Convert** — the shot rewritten in flight | `Arrow._probe_convert` / `_ignite`, `Hit.ARROW_FIRE`, `K.L_CONVERT` |
| 3.1 | The furnace it is rewritten by | `Lantern.convert_kind()` and its `ConvertZone`; **lit only** |
| 3.1 | The lock that wants the rewrite | `EyeSwitch.frozen` — a variant, not a tenth atom |
| 3.1 | The refusal that names the verb | `EyeSwitch.refusal()`, reached through `PuzzleGate.refusal_line`'s handle |
| 3.2 | **Sequence** — trip N atoms in order | `PuzzleGate.ordered` / `_out_of_turn()` / `_break_the_sequence()`, over `PuzzleAtom.index`; per **kind**, not across the set |
| 3.2 | Going backwards, flag and all | `PuzzleAtom.reset()` — the third case beside `solve()` and `unsolve()`, and it erases `atom_*` |
| 3.2 | The eye that shuts again | `EyeSwitch.on_unsolved()` |
| 3.2 | The line that names the next one | `PuzzleAtoms.refusal_next_for()` via `PuzzleAtom.refusal_next()` — *THE 1ST OF 3 EYES IS NEXT* |
| 3.2 | The ordered room | `Dungeon._gate_eye_row` — `index` left to right; proved by `tools/directors/gate_eye_row.gd` beats J–K, **both directions** |

### Four decisions worth not re-deriving

- **A burning arrow is a change of SHAPE, not a brighter arrow.** CLAUDE.md §3
  records that emissive over near-black photographs as an opaque slab at every
  opacity, so a converted shot grows a plume of real geometry: five splayed licks
  and a hot core, tapering *backward* off the head, which makes the burning arrow
  a ~1.0 m streak where a plain one is a 0.7 m splinter. Length is what survives
  ten metres; width does not. The first pass built the cones nose-forward and
  they nested into one clean outline — the frame came back with an orange traffic
  cone on the front of the arrow, and only the broadside lens said so. The core
  is RUST dithered toward BONE because a mid-orange plume in a torchlit hall is
  a shape you have to already know is there.

- **A wall-mounted atom flush against `KitWall` renders perfectly and cannot be
  hit.** `KitWall` collides with one box covering the slab *and its relief*
  (`kit_wall.gd`), so the stone stands 0.26 m proud of the visible face over the
  whole height, not just along the plinth course it is named for. The shortcut's
  eye sat 0.12 m out and passed every wiring check in `shortcut_puzzle.gd` — it
  was in the room, it faced the player, it was above the sword's reach, and it
  answered `apply_hit` the instant anything handed it one. Then the beat fired a
  real `Arrow` and the eye stayed dark, because the ray had ended on the room's
  own wall body a centimetre short of the pupil. `Dungeon.WALL_STANDOFF` is the
  fix and `_clear_line` is the check that would have caught it on the first run:
  **poking a prop by hand proves the wiring and says nothing about whether the
  verb can arrive.** The hook ring had the same defect and no symptom at all,
  because the hookshot snaps by angle and never casts a ray.

- **The gate stands in the doorway, not on a wall.** A critical-path puzzle is
  critical *by construction* that way — there is no version of the floor where
  the player walks round it. `puzzle_loop`'s beat B3 asserts the door's forward
  agrees with the route's next step.
- **The socket is not one of the gate's atoms.** The key cannot be reached
  without it, so watching both is redundant, and the refusal would name the wrong
  half — *THE SOCKET IS DARK* beside a key you can see.

  **`eye_row`'s eyes are, and the exception is the rule read carefully** (§3.2,
  card #44). Both halves of the sentence above invert for an ordered row: the
  count is not redundant, because a sequence has to be counted somewhere and this
  is the thing that counts atoms; and there is no key in sight to be the wrong
  half of, because the gate room's key is `visible = false` until the row is
  finished. Redundant watching is still refused — `sun_nest` and `lights_out`
  keep single-atom doors.
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

---

## 10. The grammar — what makes floor 4 harder than floor 1

**Design, 2026-08-10.** §2 and §3 are the vocabulary. This section is the
*syntax*: the rule that says which sentences the generator is allowed to build on
which floor, and why floor 4's sentences are harder than floor 1's without
containing a single word floor 1 did not have.

It exists because "harder deeper" has three cheap answers and all three are
wrong, and the catalogue is what proves they are wrong.

### 10.1 The three wrong axes

| The cheap answer | Why Ocarina does not do it |
|---|---|
| **More atoms.** Five eyes on floor 4 instead of three on floor 1 | Five is not harder than three, it is *longer* than three. The Deku Tree already asks for three of a thing |
| **Tighter timers.** The same puzzle, less clock | GDD §7 forbids compressing a telegraph past 60% for exactly this reason, and a puzzle timer is a telegraph. It converts a design into an execution test |
| **Rarer atoms.** Save the interesting prop for floor 4 | This is the trap `docs/OOT_CATALOGUE.md` §4 pattern 11 catches: the Fire Temple's rusted switches are not a *late* prop, they are an *early* prop that the hammer switched on. The player's inventory is the difficulty curve |

### 10.2 The right axis: verbs per room

The single most useful sentence in the whole guide-reading is that the Spirit
Temple's hardest room does not contain a hard atom. It contains **four verbs** —
a ground-pound, a set of struck doors, an arrow into an eye switch, and a climb —
and every one of them is something you learned two dungeons ago.

> **Depth is how much of your kit one room asks for at once.**

That is the axis, and it is the only one that gets harder without getting meaner.
It also happens to be the axis this project already wants for a second reason:
GDD pillar 2 says a cautious player is never blocked, and a room that asks for
three things you own can never block anybody.

### 10.3 The production rule

Three lines. This is the whole grammar.

```
room       := gate( goal )
goal       := atom | logical( goal, goal… ) | spatial( goal ) | temporal( goal )
atom       := any row of PuzzleAtoms.pool(tier)
```

**The nine combinators sort into three kinds, and the kind is what makes the
grammar finite instead of a soup.** This is the taxonomy the generator branches
on; §3's table is the same nine in the order they were invented.

| Kind | Combinators | What it varies | Arity | Built? |
|---|---|---|---|---|
| **Logical** | nest, sequence, couple, **chain**, **convert** | how the atoms relate to *each other* | 2+ | **yes, all five** (sequence since 2026-08-11, §3.2) |
| **Spatial** | displace, cycle, **reconfigure** | where the atoms are relative to the door | 1 | cycle and reconfigure yes; **displace has no placer** (§3.3) |
| **Temporal** | time | when the solve has to land | 1 | **NO. The kind has zero mechanism** (§3.3) |

**The generator cannot emit a Temporal node today**, and the budget table below
spends one on floors 3 and 4. Anything reading §10 as a build order should read
that row as the first thing standing between this grammar and a generator.

**One logical, at most one spatial, at most one temporal, and no kind twice.**
That rule is the whole brake, and it is what stops the generator emitting
`nest(nest(nest(eye)))` — a legal sentence that reads as one puzzle wearing three
coats. It also means the tree is at most three deep, which is the depth a player
can hold in their head standing in a doorway.

**Weight**, for the budget table below, is the node count: `weight(atom) = 1`,
`weight(combinator(g…)) = 1 + Σ weight(g)`.

### 10.4 The budget, per floor

| Floor | Pool (§1) | Atoms | Verbs asked | Logical | Spatial | Temporal | Weight |
|---|---|---|---|---|---|---|---|
| **1** The Cistern | T0 | 1–2 | **1** | 1 | — | — | ≤ 3 |
| **2** The Foundry | T0–T1 | 2–3 | **2** | 1 | 1 | — | ≤ 5 |
| **3** The Choir | T0–T2 | 3–4 | **2–3** | 1 | 1 | maybe *(unbuilt)* | ≤ 7 |
| **4** The Chord Gate | T0–T3 | 3–5 | **3** | 1 | 1 | yes *(unbuilt)* | ≤ 9 |

**The Temporal column is a budget for a kind that has no mechanism** (§3.3, §10.3
— card #44). It is left in the table rather than struck out because it is the
design and the design has not changed; the parenthesis is there so nobody plans a
floor around a cell the code cannot spend. The Spatial column is honest for
floors 2–4 only through `cycle` and `reconfigure` — `displace`, its third member,
has no placer either.

The **verbs asked** column is the one that matters and the **atoms** column is
the one that will be tempted upward in tuning. Resist it in that order.

`PuzzleAtoms.pool(max_tier)` already returns *everything at or below* the tier —
it was written that way for §0 rule 1, and it turns out to be pattern 11 for
free. Nothing needs changing for retro-unlock to work; it is already the
behaviour.

### 10.5 A floor-4 room, worked

**It is a worked design, not a buildable one.** It is assembled from convert +
nest + displace + reconfigure, and `displace` has no placer (§3.3) — so the room
below cannot be generated today, and the one piece missing is *"the block is in
the room you cleared two rooms ago"*. Said here because a reader who took this
section for a spec would find that out three rooms in.

Because the budget table is abstract and the point it is making is not.
`docs/PUZZLES.md` §5.2 caps the gate room at **tier ≤ N−1**, so floor 4's
critical-path puzzle may not ask for the hookshot at all.

> **The Long Note** — floor 4, gate room.
>
> A frozen eye switch sits in an alcove behind a fixed grate. There is no angle
> from anywhere in the room that puts an arrow through the grate *and* on the
> eye, and the eye is iced over besides, so a plain arrow would bounce.
>
> A lantern stands on the one sight line that works. Lit, it converts a shot
> passing through it — **`convert`** — and a burning arrow is the only thing the
> frozen eye takes.
>
> The lantern is dark, and it is on a plate that has to stay held. The only
> weight on the floor is a push block, and it is in the room you cleared two
> rooms ago — **`nest`** under **`displace`**.
>
> The eye, struck, retracts the grate ring and opens the wall behind it —
> **`reconfigure`** — and what is behind it comes out near the entrance, which is
> §4's cycle and the walk home.

**Verbs asked: three.** Push, hold, shoot. **Tier used: T1.** The hookshot the
player is carrying — the newest, shiniest thing they own — is not the answer to a
single beat of it.

That is the whole design, and it is worth being blunt about why it is right
rather than disappointing: **the hookshot is what the floor pays you for solving
this**, because the cycle it opens is the one you cross with it and the shortcut
on this floor is drawn from exactly tier N (§1). The newest item is the *reward
path*, never the *lock*. A game that makes the last item the answer to the last
puzzle has built a corridor and called it a temple.

### 10.6 Two answers, from floor 3 down

**A puzzle at depth has more than one solution, and neither one is the real one.**
The Fire Temple's Flare Dancer takes a bomb, a hookshot, or a hammer; the Spirit
Temple's *Trial by fire* is solved with Fire Arrows or by leading the enemy into a
fire wall that was already burning. Ocarina stops insisting somewhere around the
fifth dungeon and the game gets better at exactly that point.

It is not generosity. A single-solution puzzle at weight 7 is a **knowledge
check** — you either see it or you stand there — and GDD pillar 3 already rules
knowledge checks out for combat. A second answer that is slower, or costs more
arrows, or asks you to fight something you could have avoided, converts "I am
stuck" into "I am paying more than I should have to", which is a sentence this
game is entirely built to have with the player.

**Cheapest implementation, and it needs no new anything:** the second answer to a
`convert` chain is to bring your own fire — which is the T2 Burst — and the second
answer to a held plate is a monster baited onto it (`docs/OOT_CATALOGUE.md` §2.9,
and `plate_weight` is already a group any body can join). Both are the *expensive*
answer. That is the design.

### 10.7 The Chord Gate should be trials round a hub — and three is enough

Ganon's Castle is **a hub with one trial per temple around it**, each a short exam
in that temple's verb. For a game whose floors are generated and whose items are
earned one per floor, that is the correct finale shape and it is nearly the only
finale shape that pays off a run-based inventory.

**The expensive version is not on the manifest and should not go on it** — six
authored trial rooms is six prefabs and a new anchor kind.

**The cheap version costs no new anchors.** Floor 4 already gets three puzzle
anchors: the shortcut, the gate room and the treasure room. Draw them **one per
verb — T1, T2, T3 — instead of by the normal rule**, and the Chord Gate becomes
the floor that asks for the bow, the Burst and the hookshot in three separate
rooms before it asks for the Riven Knight. It is the difference between a fourth
floor and a finale.

~~That is a change to one selection function in `Dungeon`.~~ **It is not, and
this was re-priced against the tree on 2026-08-11.** The gate room can only build
what `Dungeon.GATE_PREFABS` holds, and that is `sun_nest` (T0), `lights_out` (T0)
and `eye_row` (T1) — `_prefab_fits` asks for `LANTERN`, `EYE_SWITCH` or
`SUN_SOCKET` and for nothing else. **There is no T2 gate prefab and no T3 gate
prefab**, so a floor 4 told to draw its gate room at the Burst or the hookshot
draws nothing at all and `_gate_prefab` refuses loudly. The real price is
**two prefabs that do not exist**, written on the pattern `_gate_lights_out`
sets, *and then* the selection change.

The other two anchors are the cheap part, and are worth separating out so the
next reader prices the right thing: the shortcut is already picked by tier rather
than by seed (`SHORTCUT_PREFABS` is T1/T2/T3 in order), and the treasure room
already clamps to tier N and gates on whatever atom the pool hands it. The
shortcut has a different bill instead — §1 gives floor 4's the **Far Lantern**,
which has no verb, so `_shortcut_pool` comes back empty and that anchor is a
plain `LockedDoor` today. Drawing it at a verb means taking the Far Lantern's
door off it, which is a §1 design decision and not a selection function.

---

## 11. Enemies, minibosses and bosses

**`docs/BESTIARY.md` owns them**, including the design rules §7's four minibosses
are built against and the item-answer vocabulary the roster is missing. §7 above
keeps what it has always owned — *which* four minibosses floors 1–4 get, and why
they sit behind the treasure puzzle — because that is a reward-branch decision and
this is the reward-branch document.
