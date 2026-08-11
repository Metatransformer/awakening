# ITEMS — what each one answers, and where it enters the run

The design of record for items. `docs/BESTIARY.md` says what a body asks;
`docs/PUZZLES.md` says what a room asks. This says **what answers them**, where
the answer comes from, and what the player can do afterwards that they could not
do before.

> **Every item is an answer, and the answer is a verb.**
> **An item whose whole effect is that a number went up is a rung, and the
> smith already sells rungs.**

That is `docs/BESTIARY.md` §0 read from the other end, and it is GDD §5.2's rule
("verbs, not numbers") applied to everything on the list rather than only to the
four boss drops.

**Numbers are not here.** They live in the DB scripts beside the rows they price
— `docs/SCOPE.md` §1 says so explicitly of `relic_db.gd`, `echo_db.gd` says it
of the Echo tuning values, and `docs/METAGAME.md` opens with the reason: a doc
that restates a number is a doc that will disagree with the code. What this file
carries instead is the **citation**: every claim below names the file and line
that decides it, so a reader who doubts one can go and look.

**Where this document and the code disagree, §8 says so** rather than
reconciling it quietly. That list is a deliverable, not an appendix.

---

## 0. What this owns, and what it does not

| This file | The other file |
|---|---|
| What an item is **for**, and what owning it changes | What it **costs** — `docs/METAGAME.md` |
| Which body or which lock it answers | The body — `docs/BESTIARY.md`; the lock — `docs/PUZZLES.md` |
| Where it enters the run | Where the floor puts it — `scripts/world/floor_db.gd` |
| The rules that keep the lists from growing | The counts — `docs/SCOPE.md` §1 |
| — | Every stat, price, recipe and tuning value — the DB scripts |

**Five shelves, and a thing is on exactly one of them:**

1. **Usable items** — a stop on the right-hand ring, or a pure lock. Owned as a
   flag in `Game.items`, never in the bag.
2. **Relics** — twelve named objects, carried home in the bag, handed across a
   counter, then gone from the bag forever.
3. **Echoes** — twelve run-scoped boons, carried in the bag, dead by morning.
4. **The ladders** — nothing you pick up. Bought, permanent, on `Game.upgrades`.
5. **Stock** — arrows, charges, bottles, draughts, keys. Counted, not held.

The shelf decides the plumbing, and the plumbing is the design. A usable item is
`Game.has(id)` (`scripts/autoload/game_state.gd:1082`) and nothing else; a relic
and an Echo are `ItemDef` rows so that the bag's slot rule, full-bag rule, fee
rule and drop rule apply to them for free
(`scripts/items/item_db.gd:185`, `:210`; `scripts/items/echo_db.gd:14-23`).

---

## 1. The six usable items

`docs/SCOPE.md` §1 freezes **usable items at 6**: Bow, Hookshot, Burst, Sustain,
Ballast, Far Lantern. Four are boss drops, two are relics the alchemist reads,
and one of the six has no button at all.

**The six are not the ring's six.** The ring's stops are sword, bow, hookshot,
Burst, Sustain, Ballast — the sword is a stop and not a manifest item; the Far
Lantern is a manifest item and not a stop. `Game.RIGHT_POOL`
(`scripts/autoload/game_state.gd:185`) is the ring, and it holds four of the six
today because Sustain and Ballast are not built (§8, D5).

### 1.1 The three you already have

Sword, shield and rope. **They are not on the manifest's six** — they are the
starting kit, and since M1 the kit is literally empty
(`scripts/autoload/game_state.gd:220`): the sword and the shield are
unconditional in `armament_owned()` and the rope is a menu verb, so none of the
three needs a grant.

- **The sword** answers everything, *and that is the problem*
  (`docs/BESTIARY.md` §2). In the puzzle kit it is the urn and the lantern —
  `puzzle_atoms.gd:121`, `:188`, both T0.
- **The shield** is the one starting item with a verb the roster has to earn:
  the sun socket's beam (`puzzle_atoms.gd:171`, T0, *"your shield"*) and the
  Thrower's returned throw (`docs/BESTIARY.md` §3, behaviour 1). It is the
  cheapest row on that table and the most valuable, because it is owned from
  minute one.
- **The rope** owns **no combat verb and must keep owning none**
  (`docs/BESTIARY.md` §2). It is the extraction verb, it is deliberately not
  bindable to an item button, and one D-pad press that ends the run is exactly
  the fumble its hold exists to prevent (`scripts/items/escape_rope.gd:26-27`).

### 1.2 The Bow — *for the thing that has not noticed you yet*

**Answers.** The **eye switch** (`puzzle_atoms.gd:144`, T1, *"the bow"*) — and
three bodies: the **Perched** enemy that stands across a gap, the **Caller**
before its shout lands, and the **Guard** in the beat it turns
(`docs/BESTIARY.md` §3, behaviours 3, 5, 2). It is the only stagger that lands
on a plated front without Burst.

**Enters** at the Cistern Warden, floor 1 (`floor_db.gd:306`,
`boss_db.gd:214`). Nothing before that: the bow left the starting kit in M1 and
its forge ladder left the smith's board with it — `string` and the `arrows`
stock line are both gated on owning it (`shop_db.gd:62-63`), because a ladder
for a weapon you have not found is a spoiler and a dead row (`shop_db.gd:44-52`).

**Changes.** It converts the whole of floor 2 into a temple about itself
(`docs/PUZZLES.md` §1's diagonal), it opens floor 1's shortcut
(`FloorDb.shortcut_key` = that floor's own boss item, `floor_db.gd:546`), and it
is the key to floor 1's vault, which is opened by floor N+1's item
(`floor_db.gd:556`). Owning it also switches on a **resource** the player has to
manage: arrows, with three sources and no fourth (`docs/METAGAME.md` §4.6), one
of which is the bag itself (`scripts/items/fletching.gd:38`).

### 1.3 The Hookshot — *crosses a gap, or brings the gap to you*

**Answers.** The **hook ring** (`puzzle_atoms.gd:162`, T3, *"the hookshot"*) —
cross, or pull the block to you. On a body it does **no damage**: it is the
expensive answer to the **Perched** enemy (close the gap, then melee), and it
holds a body still for `K.HOOK_FREEZE` (`consts.gd:587`; applied at
`hero_ranged.gd:613`).

**Enters** at the Bellwake, floor 3 (`floor_db.gd:367`, `boss_db.gd:426`). Its
`chain` ladder appears at the smith the same moment (`shop_db.gd:64`).

**Changes.** An item that pulls you across a chasm and an item that buys you a
beat are the same item, because both answer *I am not where I need to be yet*
(GDD §5.2). That is why it has one entry in the atom table and one column in the
bestiary and they do not need to agree about what it is for.

### 1.4 Burst — *the game's one destructive answer*

**Answers.** The **cracked pillar** (`puzzle_atoms.gd:156`, T2, *"a burst"*) —
the only atom that removes a wall rather than opening a door. On a body it is
the **guard-breaker** and the only blow a **Riser** does not get up from
(`docs/BESTIARY.md` §3, behaviours 2 and 7).

**Enters** at the Slag Ogre, floor 2 (`floor_db.gd:336`). It is **cast, not
thrown**: what you take off the Ogre is a written working, and the change from
the old satchel is a noun and a particle colour, not a mechanic
(GDD §5.2; `cracked_pillar.gd:49-50`). Mechanically it is a row in
`armament_db.gd` and nowhere else — a name (`:26`), two letters instead of an
icon because a working has no model to bake one from (`:46-50`), a blurb
(`:62`), and an ammo counter (`:124`). That row *is* the proof there is no
casting layer.

**Changes.** It is the first thing the player owns that **changes the shape of a
room** rather than reaching across it, which is why `docs/PUZZLES.md` gives it
the only atom that can open a route the room planner did not draw. Its charges
are arrows with a different noun: a count in the HUD column
(`armament_db.gd:141-145`), spent on cast, and **never refilled underground**
(`game_state.gd:100-103`). Spending your last charge on floor 2 is a statement
about how deep you were planning to go.

### 1.5 Sustain — *the chain holds through one break*

**Answers** no body and no lock. `docs/PUZZLES.md` §1 is explicit: Sustain and
Ballast are **not puzzle verbs**, because neither manipulates a room.

**Enters** as **the Sustain-Verse**, a relic found in the Foundry vault and
**read** at the alchemist's counter rather than repaired (GDD §6.2, relic 6;
§6.4). It is the only class of item in the game that arrives as one shelf and
leaves as another.

**Changes** the price of tempo. Heat rides in the bag, so going fast raises the
fee — Sustain makes speed cheaper *and* the exit dearer, which is GDD §2's one
question asked twice in one button. **Not built** (§8, D5).

### 1.6 Ballast — *burn what you came for, to survive carrying it*

**Answers** no body and no lock, for the same reason as Sustain.

**Enters** as **the Ballast-Verse**, the Choir's deep chest, read at the same
counter (GDD §6.2, relic 7).

**Changes** what the bag is. It is the sharpest form of §2 in the game: the
thing you came down for is the thing that keeps you alive, and casting it is
eating your own profit. It is also the reason the manifest can hold at three
workings — a fourth would have to be a *fourth* answer to "what are you willing
to spend", and there are only three things a player has to spend. **Not built**
(§8, D5).

### 1.7 The Far Lantern — *the one with no button*

**Answers** exactly one thing: the last door. It is a **pure lock**, it never
gets a verb (`docs/PUZZLES.md` §1), and the door that names it already exists
(`locked_door.gd:123` — `THE FAR LANTERN`, `Pal.ARCANE`).

**Enters** at the Riven Knight, floor 4 (`floor_db.gd:400`, `boss_db.gd:538`).

**Changes** nothing about a fight or a room, and that is correct for a thing
that ends an act. What it opens is floor 4's shortcut, and floor 4's shortcut is
the Long Descent (`floor_db.gd:543-545`). A pure lock is the right shape here
precisely because the reward is the ending, not a new press.

---

## 2. The twelve relics

`docs/SCOPE.md` §1 freezes **relics at 12**, named, hand-placed, non-rolling —
**two of them Verses, and all twelve arriving broken**. The moment a relic can
roll it stops being a thing you remember finding (`relic_db.gd:8-12`).

**Answers:** nothing in a fight and nothing in a room. A relic answers a
question about the *garrison*, and the rule that generates the whole list is one
line (GDD §6.1):

> **A relic unlocks a row in an existing catalogue, a rung on an existing
> ladder, or a number in `K`. It never adds a screen, a system, or a fifth NPC.**

`relic_db.gd`'s `bites` column is that rule made checkable: every row names the
accessor and the call site its one line of change lands on (`relic_db.gd:74-77`).
If you cannot write a proposed relic as one accessor and one call site, it is the
wrong relic.

**Enters** at one of four anchors and nowhere else — deep chest, vault, boss, and
the Long Descent's single chest (`relic_db.gd:255-258`). Four from bosses, four
from deep chests, three from vaults, one from the endless mode; eleven are
reachable in Act I and the twelfth is the reason to keep going after it.

**Changes** the place you come home to, and it changes it **twice**: the unlock,
and a dark prop in the courtyard coming on (`relic_db.gd:79-82`). Twelve dark
props, twelve lights. By the twelfth the first frame of the game and the last
frame are visibly different places, and that contrast *is* the reward — it must
not cost more than a prop.

### 2.1 Broken on arrival, and why that is the design and not a tax

A relic you find **does not work**. It comes up out of the Cut broken, its
description tells you which counter to walk it to, and it does nothing until it
has been repaired — or, for a Verse, **read** (GDD §6.4). The home counter needs
no table:

> **A relic's home is the counter whose thing it changes.**

This is not a system bolted onto the donation; it is the donation losing its
special case. Every other counter takes gold for a permanent change, and the
Lanternkeeper was the one that did not. It also sharpens the walk home: a broken
relic is worth nothing until you pay, and it still costs a bag slot and still
pays the toll on the way out. Five rooms from the rope you are carrying twelve
slots of amber and one object currently worth less than the amber.

**Unbuilt** — there is no `broken` flag, no repair price and no `home` column in
`relic_db.gd`, and every donation line is priced at zero (`relic_db.gd:557`).
§8, D4.

### 2.2 What a relic is worth on the way up

Nothing, and it is charged for anyway. `ItemDb._relic` (`item_db.gd:185`) gives
all twelve the same `RELIC_TOLL` (`item_db.gd:168`) — **not a sale price**: the
vendor pays 0 and refuses the sale outright, and the toll exists only so that
GDD §3's sentence *"a relic is charged the extraction fee"* is true rather than
decorative. Uniform across all twelve **on purpose**: a per-relic toll would be a
hidden ranking of which unique is worth the trip, and there is no such ranking.

One slot, always. That slot is the sharpest form of the one question, and it is
also why the Thief refuses to steal one (`docs/BESTIARY.md` §3).

### 2.3 The three things a relic must never do

- **No relic sells.** There is no `value` column and the vendor never sees one
  (`relic_db.gd:42-45`). Gold buys a relic's *effect* — that runs the other way
  and is not a violation — but gold can never buy the relic and the relic can
  never become gold.
- **No relic is a stat.** Read the `bites` column: catalogues, recipes, prices,
  two workings, one wayfinding hum. The closest thing to power is the extraction
  discount, which is a discount on *leaving* (`relic_db.gd:46-48`).
- **No relic gates the ending.** `all_donated()` exists for the completionist
  Chord ending only (`relic_db.gd:49-51`, `:467`).

---

## 3. The twelve Echoes

`docs/SCOPE.md` §1 freezes **Echoes at 12**. `docs/PUZZLES.md` §6 is the design
of record for which twelve and why; this section is what an Echo is *for* beside
the other shelves.

> **An Echo costs a bag slot, and that is the only thing it costs.**

**Answers** neither a body nor a lock — an Echo **bends a rule the game already
runs** (`echo_db.gd:8-12`). That is the boundary that keeps a found thing from
quietly replacing a bought one, and `EchoDb.validate()` (`echo_db.gd:265`)
enforces the shape of the pool rather than trusting a listing: twelve rows, five
on tempo, five on depth, two on the carrying itself, no duplicate names, a
catalogue row for every id, value 0 and stack 1 on every one of them.

**Enters** from a sounding stone on a pedestal, as **a choice of three**
(`echo_db.gd:49`), at three sites: the shortcut, the gate room and the treasure
puzzle. Minimum one per floor, maximum two. One Echo — the Long Chord — is
withheld until floor 3 (`echo_db.gd:54`), because it is worth nothing to a player
who has not already committed slots.

**Changes** how a *single run* is played, and then stops existing. Home, garrison
or death — it goes quiet (`Run.bank_echoes`, mirrored on `bank_relics`). GDD
pillar 4 is about permanence and an Echo is not permanent, so it does not touch
it. What it does touch is the bag: a player who takes every Echo on offer walks
into the Chord Gate carrying almost nothing worth selling, **and that is the
decision**.

**The four near-misses are the useful part of the list.** `docs/PUZZLES.md` §6.2
rejects, by name, an Echo that reveals a chest (relic 8's job), one that holds a
Heat chain through a break (Sustain's), one that burns a stack for soak
(Ballast's) and one that changes a price at a counter (relic 11's). All four for
the same reason: **an Echo may not be a weaker copy of something permanent.**
That is the test to apply to a thirteenth, and the reason there is no thirteenth.

---

## 4. The ladders — the items that are not objects

`docs/SCOPE.md` §1 freezes **upgrade tracks at 20**: 4 gear (edge, guard, string,
chain) + 8 armour (4 pieces × 2 paths) + 8 jewel. GDD §6.6 is the design of
record for the loop; what belongs here is that **a rung is an item too**, and it
is the one kind the player chooses rather than finds.

**Answers** the same questions as everything above, in the same units. `edge` and
Emberblood answer *this thing does not die fast enough*; `guard` and Ward and
Ironhide answer *this thing hits too hard*. That overlap is deliberate and it is
capped on the **number**, never per faucet — `K.SOAK_MAX`, `K.EDGE_MAX`,
`K.STAMINA_MAX`, and the clamp inside `Game.speed_mult()` (`jewel_db.gd:31-37`).
Two taps on one number is a build; two ceilings on one number is a bug that adds
up to twice the cap.

**Enters** at a counter, for gold and materials, after you got home. Two of the
four gear ladders are gated on owning the item they are about
(`shop_db.gd:61-65`), which is what turns two systems that were already built
into progression.

**Changes** what you are willing to carry, because every rung on the armour is a
**fork**: heavy buys soak and costs a little speed, light buys less and costs
none. `docs/SCOPE.md` §1 freezes **jewelry at 4 slots × 2 paths × 5 rungs** —
one deeper than a forge ladder, because a jewel has no rung 0 you already own
(`jewel_db.gd:17-19`, `:107`, `:118`) — and the jeweller is where the speed heavy
plate took is bought back. That is the loop's one genuinely hard standing
question and it is the same shape as §2's.

**A piece commits, and both counters sell the undo.** REFORGE at the smith
(`shop_db.gd:163`) and RECUT at the jeweller (`jewel_db.gd:123`) are priced at
zero gold on the face of the card, because the price is paid in the currency that
costs time rather than progress: **metal is conserved and stone is not**. Neither
row is a track and neither reaches `Game.upgrades`.

---

## 5. Stock — the things that are counted, not held

`docs/SCOPE.md` §1 freezes **currencies at 1**. Gold. Components and relics are
items, not money — and the reason is GDD §3: the three do not touch, so a player
can never grind one into another.

| Stock | Lives on | Enters | The decision it creates |
|---|---|---|---|
| **Arrows** | `Game.arrows` | Three sources, no fourth — `docs/METAGAME.md` §4.6 | Fletching runs the right way round: it **frees** slots (`fletching.gd:38`, `:48`) |
| **Charges** | `Game.charges` | Bought in the garrison, never refilled below (`game_state.gd:103`) | How deep you were planning to go |
| **Bottles** | `Game.bottle_contents` | Blown at the alchemist, capped by a relic (`alchemy_db.gd:26`, `:168`) | The fourth bottle is an event, not a purchase |
| **Draughts** | in a bottle | Brewed — three, and only three (`potion_db.gd:23`) | Which of the smith's three numbers you want for 45 seconds |
| **Small keys** | `Game.small_keys` | The T0 atom (`puzzle_atoms.gd:111`) | Which door, when there is more than one |

**The draughts are the forge's own numbers on a timer, on purpose**
(`potion_db.gd:5-12`). Emberblood adds to `Game.sword_bonus()` and Ironhide to
`Game.armour_soak()`, so a draught is worth two rungs for its duration and not
one consumer of either number knows potions exist. A potion that did something no
rung does would be a fourth kind of good for the player to learn. Their short
names are `HEART`, `HIDE` and `EMBER` (`potion_db.gd:30`, `:36`, `:43`) — five
characters at most, because the HUD cell is 64 px and a longer word stops being a
word.

**Re-drinking replaces the clock rather than stacking it** (`potion_db.gd:113`).
Stacking would make the answer to every hard fight *drink all four*, which is the
one thing four slots must not be for.

---

## 6. What is deliberately not an item

- **Ingredients and components.** Merchandise and material. They are `ItemDef`
  rows and they compete for the same bag slot as everything else, which is the
  competition the economy actually needs (`item_def.gd:17-34`). No id appears in
  two counters' recipes — the pouch prints one bench name per material, and a
  coil the jewelcrafter also ate would send the player to the smith holding her
  price (`item_def.gd:51-59`).
- **The rope.** §1.1.
- **Armour and jewelry art.** Every piece is a number. `docs/SCOPE.md` §1 holds
  armour/jewelry art at 0 and GDD §6.6 gives the reason: four meshes × two paths
  × four rungs, against a hero rig this project has already had to fix three
  times.
- **A fourth working, a thirteenth relic, a thirteenth Echo, a ninth jewel path,
  a sixth stat.** Each is refused by a count in `docs/SCOPE.md` §1 and by a rule
  in this file. The ceiling on the workings is a **thumb**, not a budget: six ring
  stops is where a ring you can count stops being countable.

---

## 7. The three questions, in one table

Every row is answered above; this is the index, not a second source.

| Item | Answers | Enters | Changes |
|---|---|---|---|
| Bow | eye switch; Perched, Caller, Guard-on-the-turn | Cistern Warden, floor 1 | Range, and a resource to ration |
| Hookshot | hook ring; Perched (the expensive answer) | The Bellwake, floor 3 | Position, and one held beat |
| Burst | cracked pillar; Guard, Riser | The Slag Ogre, floor 2 | The shape of the room |
| Sustain | — (not a puzzle verb) | Sustain-Verse, Foundry vault — **read** | The price of tempo |
| Ballast | — (not a puzzle verb) | Ballast-Verse, Choir deep chest — **read** | The bag becomes armour |
| Far Lantern | the last door | The Riven Knight, floor 4 | The act ends |
| A relic | a question about the garrison | 4 anchors, broken | One catalogue row, one lit prop |
| An Echo | a rule the game already runs | a pedestal, choice of three | One run, then silence |
| A rung | the same questions, in the same units | a counter, after you got home | What you are willing to carry |

---

## 8. Defects — where a doc and the code disagree

Found by reading the fourteen scripts under `scripts/items/` against GDD,
SCOPE, METAGAME, PUZZLES and BESTIARY. "Believe" names the reading that looks
intended; it is a recommendation to whoever picks the card up, not a decision
taken.

**D1, D2, D3 and D4 are closed** (issue #25). Their entries are kept, struck
through, with what was actually done — a defect list whose closed rows are
deleted is a list that cannot tell you whether a thing was decided or merely
forgotten. D5–D12 are open and unreconciled.

### ~~D1 — the twelve relics in code are not the twelve in the GDD~~ *(closed)*

`scripts/items/relic_db.gd:122-243` held twelve rows, and two of them were
`fletchers_jig` and `waterwheel_gear`. GDD §6.2 says both were **deleted** to pay
for the Sustain-Verse and the Ballast-Verse, and `docs/SCOPE.md` §1 records the
outcome as *"Two are Verses"*. Neither Verse had a row anywhere in the codebase.

**Closed by believing the docs.** `sustain_verse` (Foundry vault) and
`ballast_verse` (Choir deep chest) are rows in `RELICS` now and the two deleted
rows are gone. The effects that existed only to serve them went with them rather
than being left pointing at ids nothing can donate: `FLETCH_WITH_JIG` /
`fletch_yield()` and `SMITH_MULT_MILL` / `smith_stock_mult()` are deleted, and
their two call sites (`Fletching.batch()`, `ShopDb._stock()`) read the base
number with no accessor in the way. `RelicDb.knows_working()` replaces them: it
is the one thing a Verse does in code, and it is the same shape as
`knows_draught()`. **The two workings are still not built** — that is D5, which
stays open, and this row is the manifest being right rather than the ring gaining
two stops.

### D2 — the Pillar-Shard is on the wrong floor, and boss 4 drops a deleted relic *(severe)*

`relic_db.gd:184-186` places `pillar_shard` on **floor 3's deep chest**; GDD
§6.2 row 11 moved it to **the Riven Knight**, and says why — the square coming on
is the largest visible change in the game and it should land on the last boss of
Act I. Consistent with the stale table, `scripts/actors/enemies/boss_db.gd:538`
has the Riven Knight dropping `waterwheel_gear`.

**Believe the GDD.** Same edit as D1; listed separately because it is a different
table and a fix to D1 that forgets this one leaves boss 4 dropping nothing.

### D3 — GDD §6.4 is unbuilt, and points at numbers that do not exist *(severe)*

GDD §6.4 says every relic arrives broken, is repaired (or read) at a home
counter, that the first repair is free, that the rest scale with the floor, and
— explicitly — that *"the numbers live in `scripts/items/relic_db.gd` beside the
rows they price"*. They do not. `RELICS` has no `broken` flag, no price and no
`home` column (`relic_db.gd:122-243`), and every donation line is authored at
`"cost": 0` (`relic_db.gd:557`). `docs/SCOPE.md` §1's "Broken relics cost nothing
on this table" paragraph describes the same unbuilt thing as though it were a
settled implementation detail.

**Believe the GDD** — it is the newer design and SCOPE has already priced it at
zero movement. But the sentence "the numbers live in `relic_db.gd`" is a doc
describing what the code does not do, which CLAUDE.md §7 calls worse than no doc.
Until the flag lands, that line should read *will live*.

### D4 — nothing in the game sells Burst charges *(severe)*

GDD §6.5 says charges are bought from the alchemist, and
`scripts/autoload/game_state.gd:100-103` repeats it. `AlchemyDb.lines()`
(`alchemy_db.gd:83-89`) offers one bottle line and three brew lines and nothing
else. `Game.add_charges()` (`game_state.gd:510`) has exactly one caller in the
whole repo — `tools/directors/burst_cast.gd:139`, a director that grants itself
three. A player who kills the Slag Ogre owns an item they can never load.

**Believe the GDD.** This is the one defect on the list that makes a shipped
item unusable in a real run.

### D5 — two of the six usable items do not exist in any form

Sustain and Ballast have no row in `ArmamentDb.NAMES` (`armament_db.gd:15-27`),
no stop in `Game.RIGHT_POOL` (`game_state.gd:185`, whose own comment says it
holds "four of the ring's six stops"), and no relic to arrive from (D1). Burst is
built; the other two are not started.

**Not a contradiction — a gap**, recorded because the manifest counts six and the
code can reach four. Listed so that a reader of §1 does not mistake §1.5 and §1.6
for descriptions of something that runs.

### D6 — GDD's status paragraph is stale

GDD lines 12-17 say what is *not* built includes "the relics and the
Lanternkeeper in §6" and "the three workings (§6.5)". The Lanternkeeper is a row
in `Npc.COUNTERS` and a live `Catalogue` subclass (`scripts/world/npc.gd:106`,
`relic_db.gd:1-2`), the twelve relic rows exist and are placed by the floor
manifests, and Burst casts (`scripts/combat/burst_cast.gd`, `armament_db.gd:26`).

**Believe the code.** One of the three workings and most of the relic plumbing
have landed since that paragraph was written.

### D7 — the Slag Ogre's drop is still spelled `bomb_bag`

`boss_db.gd:323` drops `&"bomb_bag"`; `floor_db.gd:336` says floor 2's
`boss_item` is `&"burst"`, and every gate compares against the latter. The two
are reconciled by a translation on the way in
(`game_state.gd:1058`), which the author flagged `[debt]` at `:1055` with the
reason — the file was owned by another agent that day.

**Believe `&"burst"`.** Harmless today because `grant()` translates, and worth
closing anyway: it is a one-word change, and the second id is the kind of thing
that survives into a table nobody thought to translate.

### D8 — a code comment claims the docs say `Game.has_item()`

`game_state.gd:1066-1070` says *"docs/GDD.md §5.2 and docs/SCOPE.md M1 both name
the check `Game.has_item()` in prose … The docs are what should move."* They have
moved: GDD §5.2 (`docs/GDD.md:453`) and SCOPE M1 (`docs/SCOPE.md:243`) both write
`Game.has()`, and `docs/CONTRACT.md:1461` states the rule outright.

**Believe the docs.** The comment is the stale half now.

### D9 — SCOPE contradicts its own manifest about the garrison

`docs/SCOPE.md` §1 counts garrison NPCs at **5** and new UI screens at **1**; the
"Broken relics cost nothing on this table" paragraph twelve rows further down
says the same edit leaves *"garrison NPCs … 4, new UI screens … 0"*.
`relic_db.gd:15` cites the older zero as current.

**Believe the manifest rows** — they carry the jewelcrafter and the
`StashScreen` exception, both of which are built. The paragraph was written
before either landed.

### D10 — a relic reports its rarity as "Common"

`ItemDb._relic` casts the tier to a fourth, ARCANE, that `ItemDef.Rarity` does
not name, and `ItemDef.rarity_name()` (`item_def.gd:134-138`) has no arm for it —
so the pouch's caption calls every relic Common. Self-documented at
`item_db.gd:180-184`.

**Believe the intent** (a relic is legendary); the fix is one arm in
`rarity_name()`.

### D11 — all twelve relic lore strings are clipped mid-word on the counter

`CanvasText.wrap()` takes a `max_lines` that defaults to 2 and
`scripts/ui/shop/trade_screen.gd` does not pass one, so every entry in `RELICS`
is truncated on the Lanternkeeper's board — and the smith's and the alchemist's
blurbs with them. Self-documented with a `# NEEDS:` at `relic_db.gd:108-121`,
caught by `relic_donate.gd`'s `r_21_hold.png`.

**Believe the panel has the room**; the fix is one argument at the call site, not
twelve shortened strings.

### D12 — the ownership table this file was asked to join is not in the GDD

The card and the brief both name *"`docs/GDD.md` §7's ownership table"*. GDD §7
is *Difficulty comes from depth, not from you*, and the GDD has no table of doc
owners. The table is **CLAUDE.md §7**, and it is missing a row for
`docs/BOSSES.md` as well as for this file.

**Believe CLAUDE.md §7 is the table.** This commit adds the `docs/ITEMS.md` row
there and a pointer from GDD §5.2 and §6.5; the missing `docs/BOSSES.md` row is
left for that document's owner rather than added on their behalf.

---

## 9. Proving a change to this file

There are no frames here — an item doc has no pixels of its own. **The proof is
the citation.** A claim in this file that could carry a `file.gd:line` and does
not is a claim someone guessed, and this project has been bitten by exactly that
(`potion_db.gd`'s short names were asserted as `EMB`/`IRO` in a plan; they are
`HEART`, `HIDE` and `EMBER`, `potion_db.gd:30`, `:36`, `:43`).

When an item changes, the directors that already watch one are
`tools/directors/burst_cast.gd`, `forge_loop.gd`, `jewel_loop.gd`,
`alchemy_loop.gd`, `relic_donate.gd`, `thief.gd` and `puzzle_atoms.gd`. Run the
one that owns the shelf you touched, and update this file in the same commit —
including §8, which is the part most likely to go stale, because the good outcome
for every entry on it is that it stops being true.
