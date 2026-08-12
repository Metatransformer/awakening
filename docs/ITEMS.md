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

**Status: design of record, and it runs.** All five verbs — the Bow, the
Hookshot, Burst, Sustain and Ballast — are rows in `ArmamentDb.NAMES` and stops
on `Game.RIGHT_POOL`; the Far Lantern's door exists; the twelve relics, the
twelve Blessings, the twenty ladders and all five stocks are code, and **a relic now
arrives broken** — `home` and `repair` columns on every row of `RelicDb.RELICS`,
the price on the Lanternkeeper's line, `Broken Tally-Ledger of Fair Weights` in
the bag (§8, D3, closed). Sustain and Ballast were the last two that were only
described here; they landed with §8's D5 (2026-08-11), so §1.5 and §1.6 now
describe something that runs.

**Numbers are not here.** They live in the DB scripts beside the rows they price
— `docs/SCOPE.md` §1 says so explicitly of `relic_db.gd`, `echo_db.gd` says it
of the Blessing tuning values, and `docs/METAGAME.md` opens with the reason: a doc
that restates a number is a doc that will disagree with the code. What this file
carries instead is the **citation**: every claim below names the symbol that
decides it, so a reader who doubts one can go and look. §9 says why it is the
symbol and not the line.

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
3. **Blessings** — twelve run-scoped boons, carried in the bag, ended by morning.
4. **The ladders** — nothing you pick up. Bought, permanent, on `Game.upgrades`.
5. **Stock** — arrows, charges, bottles, draughts, keys. Counted, not held.

The shelf decides the plumbing, and the plumbing is the design. A usable item is
`Game.has()` (`scripts/autoload/game_state.gd:~1082`) and nothing else; a relic
and a Blessing are `ItemDef` rows so that the bag's slot rule, full-bag rule, fee
rule and drop rule apply to them for free — `ItemDb._relic()` and
`ItemDb._echo()` (`scripts/items/item_db.gd:~194`, `:~221`), and `EchoDb`'s own
"why a Blessing is an `ItemDef` and not a second inventory"
(`scripts/items/echo_db.gd:~14-23`).

---

## 1. The six usable items

`docs/SCOPE.md` §1 freezes **usable items at 6**: Bow, Hookshot, Burst, Sustain,
Ballast, Far Lantern. Four are boss drops, two are relics the alchemist reads,
and one of the six has no button at all.

**The six are not the ring's six.** The ring's stops are sword, bow, hookshot,
Burst, Sustain, Ballast — the sword is a stop and not a manifest item; the Far
Lantern is a manifest item and not a stop. `Game.RIGHT_POOL`
(`scripts/autoload/game_state.gd:~185`) is the ring, and it holds **all six**
since §8's D5 closed. Six is the hard ceiling (`docs/SCOPE.md` §1), so that array
is now full: a seventh entry is an amendment, not a feature.

### 1.1 The three you already have

Sword, shield and rope. **They are not on the manifest's six** — they are the
starting kit, and since M1 the kit is literally empty (`Game.STARTER_KIT`,
`game_state.gd:~220`): the sword and the shield are unconditional in
`armament_owned()` and the rope is a menu verb, so none of the three needs a
grant.

- **The sword** answers everything, *and that is the problem*
  (`docs/BESTIARY.md` §2). In the puzzle kit it is the urn —
  `PuzzleAtoms.ATOMS[URN]`, `"verb": "the sword"`
  (`scripts/props/puzzle_atoms.gd:~121`, T0). It is **not** the lantern:
  `ATOMS[LANTERN]` reads `"verb": "any blow"` (`scripts/props/puzzle_atoms.gd:~188`,
  T0), and it is verb-agnostic on purpose — which is the whole reason
  `docs/PUZZLES.md` §3's *convert* combinator works, because a lantern only one
  answer can light is a lantern nothing else can be wired into.
  `docs/BESTIARY.md` §2's item table gives the lantern to the sword; that is §8,
  D16, and this document inherited the error from it.
- **The shield** is the one starting item with a verb the roster has to earn:
  the sun socket's beam (`PuzzleAtoms.ATOMS[SUN_SOCKET]`, `"verb": "your shield"`,
  `scripts/props/puzzle_atoms.gd:~171`, T0) and the Thrower's returned throw
  (`docs/BESTIARY.md` §3, behaviour 1). It is the cheapest row on that table and
  the most valuable, because it is owned from minute one.
- **The rope** owns **no combat verb and must keep owning none**
  (`docs/BESTIARY.md` §2). It is the extraction verb, it is deliberately not
  bindable to an item button, and one D-pad press that ends the run is exactly
  the fumble its hold exists to prevent (`EscapeRope`'s header,
  `scripts/items/escape_rope.gd:~26-27`).

### 1.2 The Bow — *for the thing that has not noticed you yet*

**Answers.** The **eye switch** (`PuzzleAtoms.ATOMS[EYE_SWITCH]`,
`scripts/props/puzzle_atoms.gd:~144`, T1, *"the bow"*) — and three bodies: the **Perched**
enemy that stands across a gap, the **Caller** before its shout lands, and the
**Guard** in the beat it turns (`docs/BESTIARY.md` §3, behaviours 3, 5, 2).

Note which beat that is. The arrow answers the Guard **because the plate is
somewhere else** — `docs/BESTIARY.md` §3 row 2 gives the fast answer as *"Burst —
or an arrow in the beat it turns"*, against a body whose plated front makes melee
ring off it. Burst is the answer to the plate; the arrow is the answer to the one
moment there is no plate in the way. An arrow into a plated front does nothing,
and a reading of this section that says otherwise has the mechanic backwards.

**Enters** at the Cistern Warden, floor 1 (`FloorDb.FLOORS[1]["boss_item"]`,
`scripts/world/floor_db.gd:~306`; `BossDb.BOSSES[&"cistern_warden"]["drop"]`,
`scripts/actors/enemies/boss_db.gd:~214`). Nothing before that: the bow left the
starting kit in M1 and its forge ladder left the smith's board with it —
`ShopDb.GATED_BY` puts `string` behind owning it and `SupplyDb.GATED_BY` does the
same for the `arrows` stock line, because a ladder for a weapon you have not found
is a spoiler and a dead row (the note above that table, `shop_db.gd`). **Two
tables and not one since card #91**: arrows moved from Smithing into the
quartermaster's **Trade** stock, while bag slots and hearts moved into her
**Upgrades**, when the smith went behind the floor 1 miniboss. The sieve is the
same sieve — it just runs across the two services now.

**Changes.** It converts the whole of floor 2 into a temple about itself
(`docs/PUZZLES.md` §1's diagonal), and it opens floor 1's shortcut —
`FloorDb.shortcut_key()` is that floor's own boss item (`floor_db.gd:~553`).

**It opens no vault, and it is the only one of the four that does not.**
`FloorDb.vault_key()` returns `boss_item(level + 1)` (`floor_db.gd:~563`): a
floor's vault is opened by the *next* floor's item. The Bow is floor **1's**
item, so it would be the key to floor **0**, and there is no floor 0. The three
vaults belong to the three items below, and each of them names its own.

Owning the bow also switches on a **resource** the player has to manage: arrows,
with three sources and no fourth (`docs/METAGAME.md` §4.6), one of which is the
bag recipe on Brannoc's forge board (`ShopDb.FLETCH`, `Fletching.RECIPE`,
`scripts/items/shop_db.gd`, `scripts/items/fletching.gd:~38`).

**The count is on the bow's own cell whenever the arrows are not on a cell of
their own** (`ArmamentDb.hand_count_beside`, #53). `arrow` is a stop in
`Game.LEFT_POOL` and it is not the default one — the shield is — so the loadout
this item is actually fought in is bow-right with the guard up, and nothing in
the hero gates firing on the left hand. Until #53 that loadout had no readout of
the quiver anywhere on the HUD. The bow borrows the numeral there and gives it
back the moment the arrow cell is up, so the row never prints the same number
twice.

### 1.3 The Hookshot — *crosses a gap, or brings the gap to you*

**Answers.** The **hook ring** (`PuzzleAtoms.ATOMS[HOOK_RING]`,
`scripts/props/puzzle_atoms.gd:~162`, T3, *"the hookshot"*) — cross, or pull the block to you.
On a body it does **no damage**: it is the expensive answer to the **Perched**
enemy (close the gap, then melee), and it holds a body still for `K.HOOK_FREEZE`
(`scripts/core/consts.gd:~587`; applied in `HeroRanged`,
`scripts/combat/hero_ranged.gd:~613`).

**Enters** at the Bellwake, floor 3 (`floor_db.gd:~371`; `boss_db.gd:~426`). Its
`chain` ladder appears at the smith the same moment (`ShopDb.GATED_BY`,
`shop_db.gd:~61-65`).

**Opens floor 2's vault**, which holds the Sustain-Verse: `vault_key(2)` is floor
3's boss item, and floor 2's manifest puts `sustain_verse` in the vault slot
(`FloorDb.FLOORS[2]["relics"]`, `floor_db.gd:~344`). The one item on the six that
is not a puzzle verb sits behind the one item that is nothing but reach.

**Changes** where the player is allowed to stand. Every gap the room planner drew
as the edge of the map becomes a place to be, and every body that was safe
because it was far away stops being — the same press does both, because an item
that pulls you across a chasm and an item that buys you a beat answer the same
sentence, *I am not where I need to be yet* (GDD §5.2). That is why it has one
entry in the atom table and one column in the bestiary and they do not need to
agree about what it is for.

### 1.4 Burst — *the game's one destructive answer*

**Answers.** The **cracked pillar** (`PuzzleAtoms.ATOMS[CRACKED_PILLAR]`,
`scripts/props/puzzle_atoms.gd:~156`, T2, *"a burst"*) — the only atom that removes a wall
rather than opening a door. On a body it is the **guard-breaker** and the only
blow a **Riser** does not get up from (`docs/BESTIARY.md` §3, behaviours 2 and 7).

**Enters** at the Slag Ogre, floor 2 (`floor_db.gd:~336`). It is **cast, not
thrown**: what you take off the Ogre is a written working, and the change from
the old satchel is a noun rather than a mechanic — `CrackedPillar.burst()` was
named for the verb rather than the weapon, and its note says the naming was
vindicated exactly as predicted when the thing that arrived turned out to be a
working you cast (`scripts/props/atoms/cracked_pillar.gd:~45-51`). Mechanically
it is a row in `ArmamentDb` and nowhere else — a name
(`scripts/items/armament_db.gd:~26`), two letters instead of an icon because a
working has no model to bake one from (`ArmamentDb.LETTERS`, `:~46-50`), a blurb
(`ArmamentDb.BLURBS`, `:~62`), and an ammo counter (`ArmamentDb.ammo_of()`,
`:~124`). That row *is* the proof there is no casting layer.

**Opens floor 1's vault**, which holds the Cracked Still-Head. Floor 2's manifest
says so at the row itself rather than leaving it to be derived: this id *"is what
floor 1's VAULT door names in its refusal (`FloorDb.vault_key`)"*
(`floor_db.gd:~332-336`).

**Changes** the shape of a room rather than the reach across it, which is why
`docs/PUZZLES.md` gives it the only atom that can open a route the room planner
did not draw. Its charges are arrows with a different noun: a count in the HUD
column (`ArmamentDb.hand_count()`, `armament_db.gd:~141-145`), bought upstairs
(§5) and **never refilled underground, with one exception that is a gate and not
a supply** (`Game.charges`, `game_state.gd:~100-103`). Spending your last charge
on floor 2 is a statement about how deep you were planning to go — and it used to
be a way to be stuck, which was §8, D13. The exception is the `ChargeCache` in
the urn braced against floor 2's shortcut: the one door in the game whose only
answer is a Burst brings its own, the way the bow's eye brings its own arrows
(`docs/PUZZLES.md` §0 rule 2). Nothing else on any floor hands out a charge, and
the sentence above stays true everywhere else.

### 1.5 Sustain — *hold the Heat chain through one break*

**The verb**: the tempo chain survives a break it would otherwise lose, and the
Heat you kept rides out in the bag. `docs/GDD.md` §6.2 relic 6 is the row.
Mechanically it is a stop on the ring (`Game.RIGHT_POOL`), four rows in
`ArmamentDb` exactly like Burst's, one function on the hero
(`HeroRanged._cast_sustain`) and one flag on the chain it defends
(`Heat.sustained`, `Heat.sustain()`). **One break, not a duration** — a timed
ward would be something you cast before a fight, and this is something you cast
because you can feel the window running out.

**Answers** no body and no lock. `docs/PUZZLES.md` §1 is explicit: Sustain and
Ballast are **not puzzle verbs**, because neither manipulates a room.

**Enters** as **the Sustain-Verse**, a relic found in the Foundry vault and
**read** by the alchemist when committed through the Lanternkeeper's
**Artifacts** service rather than repaired (GDD §6.2, relic 6; §6.4). The relic
exists: `RelicDb.RELICS` places it at floor 2's vault
(`scripts/items/relic_db.gd:~192`) and `RelicDb.WORKING_RELICS` maps it to the
working (`relic_db.gd:~351`). It is the only class of item in the game that
arrives as one shelf and leaves as another.

**Changes** the price of tempo. Heat rides in the bag, so going fast raises the
fee — Sustain makes speed cheaper *and* the exit dearer, which is GDD §2's one
question asked twice in one button. **Both doors into a break are covered**: the
window running out and a blow landing are the same event to a player, so
`Heat._step_down` absorbs either one and refreshes the window, because a chain
that "held" and then expired on the next frame did not hold.

### 1.6 Ballast — *burn what you came for, to survive carrying it*

**The verb**: spend a stack out of the bag to soak a blow you would otherwise
take. `docs/GDD.md` §6.2 relic 7 is the row. `HeroRanged._cast_ballast` burns
`Run.burn_slot()` — the **cheapest** line in the hold, the thief's scan run from
the other end — and starts a window in `Game.draughts` under `Game.BALLAST_ID`
that `Game.armour_soak()` adds `K.BALLAST_SOAK` for. The case is never reachable,
for the same reason the thief cannot reach it (GDD §3.1).

**Answers** no body and no lock, for the same reason as Sustain.

**Enters** as **the Ballast-Verse**, the Choir's deep chest, read through the
same Artifacts route (GDD §6.2, relic 7). Placed at `relic_db.gd:~207` and
mapped by `RelicDb.WORKING_RELICS`.

**Changes** what the bag is. It is the sharpest form of §2 in the game: the
thing you came down for is the thing that keeps you alive, and casting it is
eating your own profit. It is also the reason the manifest can hold at three
workings — a fourth would have to be a *fourth* answer to "what are you willing
to spend", and there are only three things a player has to spend. **It burns the
cheapest line and never the dearest**, which is a decision and not an
optimisation: a working that ate your Deep Amber is a button a player learns
never to press, and the cost that has to bite is the slot, which bites whatever
was in it.

### 1.7 The Far Lantern — *the one with no button*

**Answers** exactly one thing: the last door. It is a **pure lock**, it never
gets a verb (`docs/PUZZLES.md` §1), and the door that names it already exists
(`LockedDoor.SIGILS[&"far_lantern"]` — `THE FAR LANTERN`, `Pal.ARCANE`,
`scripts/props/locked_door.gd:~122`).

**Enters** at the Riven Knight, floor 4 (`floor_db.gd:~407`; `boss_db.gd:~546`).

**Opens floor 3's vault**, which holds the Warp-Stone Fragment — the last of the
three, and the manifest's count of vaults is three (`docs/SCOPE.md` §1: *4
shortcuts, 3 vaults, 1 to the Long Descent*). **There is no fourth vault**, and
that is not a rule anybody wrote: *"`vault_key(4)` comes out empty on its own,
because there is no floor 5 to lend it a key"* (`floor_db.gd:~409-412`). Floor
4's boss room is the vault, and floor 4's manifest says so by having no
`&"vault"` slot rather than by a branch.

**Changes** nothing about a fight or a room, and that is correct for a thing
that ends an act. What it opens besides the vault is floor 4's shortcut, and
floor 4's shortcut is the Long Descent — which falls out of `shortcut_key()`
rather than being special-cased, because the Far Lantern *is* floor 4's boss item
(`floor_db.gd:~550-552`). A pure lock is the right shape here precisely because
the reward is the ending, not a new press.

---

## 2. The twelve relics

`docs/SCOPE.md` §1 freezes **relics at 12**, named, hand-placed, non-rolling —
**two of them Verses, and all twelve arriving broken**. The moment a relic can
roll it stops being a thing you remember finding (`RelicDb`'s header,
`scripts/items/relic_db.gd:~8-12`).

**Answers:** nothing in a fight and nothing in a room. A relic answers a
question about the *garrison*, and GDD §6.1 (`docs/GDD.md:582`) states the rule
that is supposed to generate the whole list:

> **A relic unlocks a row in an existing catalogue, a rung on an existing
> ladder, or a number in `K`. It never adds a screen, a system, or a fifth NPC.**

**That is two tests, and only one of them holds for all twelve.**

- **The shape test — all twelve pass.** *One accessor, one call site.* That is
  `relic_db.gd`'s own formulation, and the `bites` column is it made checkable:
  every row names the accessor and the call site its one line of change lands on
  (`relic_db.gd:~91-93`). If you cannot write a proposed relic as one accessor
  and one call site, it is the wrong relic. This is the test with teeth, and it
  is the one to apply first.
- **The target test — ten pass, and two are an argued exception.** *A catalogue
  row, a ladder rung, or a number in `K`.* Ten relics land on one of those three.
  The **Sustain-Verse** and the **Ballast-Verse** do not: what they unlock is a
  usable item and a stop on `Game.RIGHT_POOL`, through
  `RelicDb.knows_working()` (`relic_db.gd:~880`) — and both rows' `bites` strings
  say exactly that. A ring stop is not a catalogue row, not a rung, and not a
  number.

The exception is deliberate, and the GDD argues it three sections later: §6.3
says the two Verses are *"the §5.2 rule applied to relics — a verb you did not
have, never a number that went up"* (`docs/GDD.md:635-640`). §6.1 was simply
never updated to admit them. So the honest statement of the generating rule is:
**one accessor and one call site, landing on a catalogue, a ladder or `K` — or,
twice and only twice, on a verb the ring already knows how to hold.** A rule that
does not generate two of its own twelve is not predictive, and a rule that is not
predictive cannot be used to refuse a thirteenth.

**Enters** at one of four anchors and nowhere else — deep chest, vault, boss, and
the Long Descent's single chest (`RelicDb.SOURCE_DEEP_CHEST` and its three
siblings, `relic_db.gd:~288-291`; the note above them says why there is no
fifth). Four from bosses, four from deep chests, three from vaults, one from the
endless mode; eleven are reachable in Act I and the twelfth is the reason to keep
going after it.

**Changes** the place you come home to, and it changes it **twice**: the unlock,
and a dark prop in the courtyard coming on (the `prop` column,
`relic_db.gd:~96-99`; read by `RelicDb.props_lit()`). Twelve dark props, twelve
lights. By the twelfth the first frame of the game and the last frame are visibly
different places, and that contrast *is* the reward — it must not cost more than
a prop.

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

**Built** (§8, D3, closed). Every row of `RelicDb.RELICS` carries a `home` and a
`repair`; `RelicDb.lines()` prices the line at `repair` and drops it to 0 once
the relic is in, so the board's tick is never buried under a price that is no
longer owed; `can_buy()` reads the purse and `refusal()` says
`REPAIR COSTS 140 ◇` — after `NOT RECOVERED`, because *where it is* is the
useful answer for eleven of the twelve rows. `ItemDb._relic()` builds the bag's
copy from `RelicDb.arrival_name()` / `arrival_hint()`, so a relic is picked up as
`Broken Tally-Ledger of Fair Weights`, described *Take it to the smith.*

**There is no `broken` column and there should not be.** All twelve arrive
broken, so the state is `not RelicDb.donated(id)`; a column that said `true`
twelve times would be a second copy of that with a way to disagree. Likewise
`is_verse()` is derived from `WORKING_RELICS` rather than authored — the table
naming which relic teaches which working already **is** the list of Verses.

**The home is the sign-post, not the till.** The **Artifacts** interaction is the
Lanternkeeper's, and GDD §6.4 says so outright. Paying at the home counter
would mean a fourth kind of line — with its own refusal — on the vendor's, the
smith's and the alchemist's catalogues, which is three systems bought to save one
walk across the yard.

### 2.2 What a relic is worth on the way up

Nothing, and it is charged for anyway. `ItemDb._relic()`
(`scripts/items/item_db.gd:~194`) gives all twelve the same `ItemDb.RELIC_TOLL`
(`item_db.gd:~168`) — **not a sale price**: the vendor pays 0 and refuses the sale
outright, and the toll exists only so that GDD §3's sentence *"a relic is charged
the extraction fee"* is true rather than decorative. Uniform across all twelve
**on purpose**: a per-relic toll would be a hidden ranking of which unique is
worth the trip, and there is no such ranking.

One slot, always. That slot is the sharpest form of the one question, and it is
also why the Thief refuses to steal one (`docs/BESTIARY.md` §3).

### 2.3 The three things a relic must never do

- **No relic sells.** There is no `value` column and the vendor never sees one
  (`RelicDb`'s header, `relic_db.gd:~44-47`). Gold buys a relic's *effect* — that
  runs the other way and is not a violation — but gold can never buy the relic
  and the relic can never become gold.
- **No relic is a stat.** Read the `bites` column. Two documents describe what is
  in it and they do not agree: `relic_db.gd:~50-52` says *"catalogues, recipes,
  prices, one wayfinding hum"*, and `docs/GDD.md:635-636` says *"catalogues,
  recipes, prices, two workings, one wayfinding hum"*. **The GDD is the one the
  table now agrees with** — `sustain_verse` and `ballast_verse` both carry
  `RelicDb.knows_working()` in `bites` — so the code comment is the stale half
  (§8, D15). Either way the point survives: the closest thing to power is the
  extraction discount, which is a discount on *leaving*.
- **No relic gates the ending.** `RelicDb.all_donated()` exists for the
  completionist Chord ending only (`relic_db.gd:~53-55`, `:~584`).

---

## 3. The twelve Blessings

`docs/SCOPE.md` §1 freezes **Blessings at 12**. `docs/PUZZLES.md` §6 is the design
of record for which twelve and why; this section is what a Blessing is *for* beside
the other shelves.

> **A Blessing costs a bag slot, and that is the only thing it costs.**

**Answers** neither a body nor a lock. A Blessing bends a rule the game already
runs — and the half of that sentence that does any work is the rest of it:
*"it never moves damage, speed, max health, max stamina or soak, **which is the
boundary** that keeps a found thing from quietly replacing a bought one"*
(`EchoDb`'s header, `scripts/items/echo_db.gd:~8-12`). The five stats are the
boundary. "Bends a rule the game already runs" excludes nothing — a forge rung
bends a rule the game already runs, and so does a jewel — so it is a description
of the shelf, not a test a proposal can fail.

`EchoDb.validate()` (`echo_db.gd:~265`) enforces the shape of the pool rather
than trusting a listing: twelve rows, five on tempo, five on depth, two on the
carrying itself, no duplicate names, a catalogue row for every id, value 0 and
stack 1 on every one of them.

**Enters** from the Votive Court as **three answering gods from six**, each with
one offered rule bend (`PatronDb.offer`), at three sites: the shortcut, the gate
room and the treasure puzzle. Minimum one per floor, maximum two. One Blessing —
The Road Remembers — is withheld until floor 3
(`EchoDb.LONG_CHORD_FLOOR`, `echo_db.gd:~54`), because it is worth nothing to a
player who has not already committed slots.

**Changes** how a *single run* is played, and then stops existing. Home, garrison
or death — it ends (`Run.bank_echoes`, mirrored on `bank_relics`). GDD
pillar 4 is about permanence and a Blessing is not permanent, so it does not touch
it. What it does touch is the bag: a player who takes every Blessing on offer walks
into the Chord Gate carrying almost nothing worth selling, **and that is the
decision**.

**The four near-misses are the useful part of the list.** `docs/PUZZLES.md` §6.2
rejects, by name, a Blessing that reveals a chest (relic 8's job), one that holds a
Heat chain through a break (Sustain's), one that burns a stack for soak
(Ballast's) and one that changes a price at a counter (relic 11's). All four for
the same reason: **a Blessing may not be a weaker copy of something permanent.**

**That test is a filter, not a generator.** It tells you whether a proposed
thirteenth is *allowed*, and it will happily pass a dozen of them. The reason
there is no thirteenth is not the test — it is `docs/SCOPE.md` §1's count, which
says twelve and says *"no thirteenth, same discipline as the relics"*, and which
`EchoDb.validate()` asserts on every run of the puzzle director. Design refuses
the bad ones; the manifest refuses the rest.

---

## 4. The ladders — the items that are not objects

`docs/SCOPE.md` §1 freezes **upgrade tracks at 20**: 4 gear (edge, guard, string,
chain) + 8 armour (4 pieces × 2 paths) + 8 jewel. GDD §6.6 is the design of
record for the loop; what belongs here is that **a rung is an item too**, and it
is the one kind the player chooses rather than finds.

**Answers** the same questions as everything above, in the same units. `edge` and
Emberblood answer *this thing does not die fast enough*; `guard` and Ward and
Ironhide answer *this thing hits too hard*. That overlap is deliberate and it is
capped on the **number**, never per faucet — `JewelDb`'s header names
`K.SOAK_MAX`, `K.EDGE_MAX` and the clamp inside `Game.speed_mult()`
(`scripts/items/jewel_db.gd:~31-37`). `K.STAMINA_MAX`
(`scripts/core/consts.gd:~718`) is the same rule on the fourth number, and it is
the one that block does not name. Two taps on one number is a build; two ceilings
on one number is a bug that adds up to twice the cap.

**Enters** at a counter, for gold and materials, after you got home. Two of the
four gear ladders are gated on owning the item they are about (`ShopDb.GATED_BY`,
`scripts/items/shop_db.gd:~61-65`), which is what turns two systems that were
already built into progression.

**Changes** what you are willing to carry, because every rung on the armour is a
**fork**: heavy buys soak and costs a little speed, light buys less and costs
none. `docs/SCOPE.md` §1 freezes **jewelry at 4 slots × 2 paths × 5 rungs** —
one deeper than a forge ladder, because a jewel has no rung 0 you already own
(`jewel_db.gd:~17-19`; `JewelDb.PARTS_LADDER` and `JewelDb.GOLD_LADDER`, `:~107`,
`:~118`) — and the jeweller is where the speed heavy plate took is bought back.
That is the loop's one genuinely hard standing question and it is the same shape
as §2's.

**A piece commits, and both counters sell the undo.** `ShopDb.REFORGE`
(`shop_db.gd:~163`) and `JewelDb.RECUT` (`jewel_db.gd:~123`) are priced at zero
gold on the face of the card, because the price is paid in the currency that
costs time rather than progress: **metal is conserved and stone is not**. Neither
row is a track and neither reaches `Game.upgrades`.

---

## 5. Stock — the things that are counted, not held

`docs/SCOPE.md` §1 freezes **currencies at 1**. Gold. Components and relics are
items, not money — and the reason is GDD §3: the three do not touch, so a player
can never grind one into another.

| Stock | Lives on | Enters | The decision it creates |
|---|---|---|---|
| **Arrows** | `Game.arrows` | Three sources, no fourth — including Brannoc's forge recipe (`ShopDb.FLETCH`; `docs/METAGAME.md` §4.6) | Fletching gives Flint and Bone a town use and runs the right way round: it **frees** slots (`Fletching.RECIPE` and `Fletching.batch()`, `scripts/items/fletching.gd:~38`, `:~64`) |
| **Charges** | `Game.charges` | Bought from the quartermaster's **Trade** stock once the Burst is owned (`SupplyDb._board()`, `scripts/items/supply_db.gd`), never refilled below except the one `ChargeCache` on floor 2 (D13) | How deep you were planning to go |
| **Rations** | `Game.rations` | Bought from the quartermaster's **Trade** stock, five at a time, twenty to a stack (`RationDb`, `scripts/items/ration_db.gd`) | Whether the room is quiet enough to sit down for twelve seconds |
| **Bottles** | `Game.bottle_contents` | Blown at the alchemist, capped by a relic (`RelicDb.bottle_cap()`, `relic_db.gd:~889`, read by `AlchemyDb.remaining()`) | The fourth bottle is an event, not a purchase |
| **Draughts** | in a bottle | Brewed — three, and only three (`PotionDb.IDS`, `scripts/items/potion_db.gd:~23`) | Which of the smith's three numbers you want for 45 seconds |
| **Small keys** | `Game.small_keys` | The T0 atom (`PuzzleAtoms.ATOMS[SMALL_KEY]`, `scripts/props/puzzle_atoms.gd:~111`) | Which door, when there is more than one |

**The draughts are the forge's own numbers on a timer, on purpose**
(`PotionDb`'s header, `potion_db.gd:~5-12`). Emberblood adds to
`Game.sword_bonus()` and Ironhide to `Game.armour_soak()`, so a draught is worth
two rungs for its duration and not one consumer of either number knows potions
exist. A potion that did something no rung does would be a fourth kind of good
for the player to learn. Their short names are `HEART`, `HIDE` and `EMBER`
(`PotionDb.DEFS`, `potion_db.gd:~30`, `:~36`, `:~43`) — five characters at most,
because the HUD cell is 64 px and a longer word stops being a word.

**Re-drinking replaces the clock rather than stacking it** (`PotionDb.apply()`,
`potion_db.gd:~113`). Stacking would make the answer to every hard fight *drink
all four*, which is the one thing four slots must not be for.

**A ration is not a cheap draught, and the twelve seconds is what makes it one
thing rather than the other** (card #98, `docs/METAGAME.md` §6.4). Hardtack pays
one heart and Small Beer one spin's worth of magic, both over `K.MEAL_TIME`
seconds of **sitting down**, and a step, a swing, a guard, a jump, a screen or a
blow ends it (`Hero.MEAL_BREAKERS`, `Hero._tick_meal_cancel`). The ration is
spent when you sit, not when you finish, so an interrupted meal has cost you the
whole biscuit — refunding it would make interruption free, and interruption is
the design. It is a **stopgap and it is meant to stop mattering**: the hero
starts with one bottle and meets the alchemist only after a boss is dead, and by
the time you own three bottles twelve seconds is a price you stop paying.

Small Beer is the only thing in the game that puts magic back outside a run
boundary. It exists by owner directive (`docs/SCOPE.md` §2, 2026-08-11) with a
fence: one caller (`RationDb.apply_tick`), no underground source, nothing that
pays without a clock in front of it, and `K.MEAL_MAGIC == K.MAGIC_SPIN` so a cup
is exactly one of the trip's four spins.

---

## 6. What is deliberately not an item

- **Ingredients and components.** Merchandise and material. They are `ItemDef`
  rows and they compete for the same bag slot as everything else, which is the
  competition the economy actually needs (`ItemDef.Kind`,
  `scripts/items/item_def.gd:~17-34`). No id appears in two counters' recipes —
  the pouch prints one bench name per material, and a coil the jewelcrafter also
  ate would send the player to the smith holding her price (`ItemDef.bench`,
  `item_def.gd:~51-59`).
- **The rope.** §1.1.
- **Armour and jewelry art.** Every piece is a number. `docs/SCOPE.md` §1 holds
  armour/jewelry art at 0 and GDD §6.6 gives the reason: four meshes × two paths
  × four rungs, against a hero rig this project has already had to fix three
  times.
- **A fourth working, a thirteenth relic, a thirteenth Blessing, a ninth jewel path,
  a sixth stat.** Each is refused by a count in `docs/SCOPE.md` §1 and by a rule
  in this file. The ceiling on the workings is a **thumb**, not a budget: six ring
  stops is where a ring you can count stops being countable.

---

## 7. The three questions, in one table

Every row is answered above; this is the index, not a second source. ~~**⚠ marks
a row that describes design with no code behind it** — an index is what a reader
lands on, and it must not be the one place the gap is invisible.~~ **Dropped
2026-08-11: no row carried the mark and none has anything left to carry it for.**
It arrived on 2026-08-10 marking three rows — **⚠ Sustain**, **⚠ Ballast** and
the relic row's *arriving broken is unbuilt* — and D3 and D5 took all three marks
off it without taking the legend with them. Both Verses are rows in `ArmamentDb`
and `RelicDb.RELICS` now, like the other four, and every remaining row here —
relic, Blessing, rung, Far Lantern — has code under it. A legend for a glyph the table does not use is itself something a
reader lands on and believes, which is the failure the legend existed to
prevent. **If a row ever loses its code, bring the mark back with it.**

| Item | Answers | Enters | Changes |
|---|---|---|---|
| Bow | eye switch; Perched, Caller, Guard-on-the-turn | Cistern Warden, floor 1 | Range, a resource to ration — and **no vault** |
| Hookshot | hook ring; Perched (the expensive answer) | The Bellwake, floor 3 | Position, one held beat; floor 2's vault |
| Burst | cracked pillar; Guard, Riser | The Slag Ogre, floor 2 | The shape of the room; floor 1's vault |
| Sustain | — (not a puzzle verb) | Sustain-Verse, Foundry vault — **read** | The price of tempo. One break of the chain, kept |
| Ballast | — (not a puzzle verb) | Ballast-Verse, Choir deep chest — **read** | The bag becomes armour. The cheapest stack burns |
| Far Lantern | the last door | The Riven Knight, floor 4 | The act ends; floor 3's vault, and there is no fourth |
| A relic | a question about the garrison | 4 anchors, and it arrives **broken** (§2.1) | One catalogue row, one repair price, one lit prop |
| A Blessing | never the five stats | the Votive Court, three gods answer from six | One run, then it ends |
| A rung | the same questions, in the same units | a counter, after you got home | What you are willing to carry |

---

## 8. Defects — where a doc and the code disagree

Found by reading the fourteen scripts under `scripts/items/` against GDD,
SCOPE, METAGAME, PUZZLES and BESTIARY, and re-checked against the tree each time
this file is revised. "Believe" names the reading that looks intended; it is a
recommendation to whoever picks the card up, not a decision taken.

**D1, D2, D3 and D4 are closed** (issue #25), **D13 is closed** (issue #29,
2026-08-11), **D5 is closed** (issue #30, 2026-08-11), and **D11 is closed**
(2026-08-11, by the trade-screen rebuild rather than by a card of its own). Their
entries are kept, struck through, with what was actually done — a defect list
whose closed rows are deleted is a list that cannot tell you whether a thing was
decided or merely forgotten. **D6–D10, D12 and D14–D17 are open and
unreconciled.**

### ~~D1 — the twelve relics in code are not the twelve in the GDD~~ *(closed)*

`RelicDb.RELICS` held twelve rows, and two of them were `fletchers_jig` and
`waterwheel_gear`. GDD §6.2 says both were **deleted** to pay for the
Sustain-Verse and the Ballast-Verse, and `docs/SCOPE.md` §1 records the outcome
as *"Two are Verses"*. Neither Verse had a row anywhere in the codebase.

**Closed by believing the docs.** `sustain_verse` (Foundry vault) and
`ballast_verse` (Choir deep chest) are rows in `RELICS` now and the two deleted
rows are gone. The effects that existed only to serve them went with them rather
than being left pointing at ids nothing can donate: `FLETCH_WITH_JIG` /
`fletch_yield()` and `SMITH_MULT_MILL` / `smith_stock_mult()` are deleted, and
their two call sites (`Fletching.batch()`, `SupplyDb._board()`) read the base
number with no accessor in the way. `RelicDb.knows_working()` replaces them: it
is the one thing a Verse does in code, and it is the same shape as
`knows_draught()`. **The two workings were not built here** — that was D5, and
this row is the manifest being right rather than the ring gaining two stops. D5
closed a day later and `knows_working()` is what its ownership gate asks.

### ~~D2 — the Pillar-Shard is on the wrong floor, and boss 4 drops a deleted relic~~ *(closed)*

`RELICS` placed `pillar_shard` on **floor 3's deep chest**; GDD §6.2 row 11 moved
it to **the Riven Knight**, and says why — the square coming on is the largest
visible change in the game, and it should land on the last boss of Act I.
Consistent with the stale table, `BossDb` had the Riven Knight dropping
`waterwheel_gear`.

**Closed by believing the GDD.** `pillar_shard` is `4`/`boss` in `RELICS`
(`relic_db.gd:~255`), floor 4's manifest puts it on the boss slot
(`floor_db.gd:~415`), and `BossDb.BOSSES[&"riven_knight"]["drop"]` hands it over
(`boss_db.gd:~546`).

**This defect under-specified its own fix, and that is the part worth keeping.**
D1 and D2 as written named two tables, `relic_db.gd` and `boss_db.gd`. **There
are three.** `FloorDb.FLOORS`' per-floor `relics` dicts are the third, and at the
time these were filed that table carried `fletchers_jig` on floor 2's vault,
`waterwheel_gear` on floor 4's boss, and `pillar_shard` on floor 3's deep chest.
`BossDb.validate()` cross-checked `RelicDb` against the drop tables and **never
saw `floor_db.gd` at all** — so a session acting on D1 and D2 exactly as written
would have fixed two files, passed the validator, and shipped a floor 2 vault
holding a relic that no longer existed. §0's own table says *"Where the floor
puts it — `scripts/world/floor_db.gd`"*, and both entries omitted it.

The session that took the card caught it anyway and fixed all three, then closed
the hole the omission came through: `RelicDb.validate()` (`relic_db.gd:~956`) now
walks `FloorDb.relics()` in **both** directions — a placement naming an id with
no row, *and* a row nothing places, which is the same bug wearing the other hat
and is invisible in every frame of the game — as well as re-asking the drop
question from this side. The standing sentence for the next reader: **three
tables carry a relic's placement, not two, and until #25 the validator checked
the first against the third and never saw the second.**

### ~~D3 — GDD §6.4 is unbuilt, and points at numbers that do not exist~~ *(closed)*

GDD §6.4 said every relic arrives broken, is repaired (or read) at a home
counter, that the first repair is free, that the rest scale with the floor, and
— explicitly — that *"the numbers live in `scripts/items/relic_db.gd` beside the
rows they price"*. They did not. `RelicDb.RELICS` had no price and no `home`
column, and `RelicDb.lines()` priced every donation at zero.

**Closed by building it, not by amending the doc** — GDD §6.4 scoped itself as a
price and a description string, `docs/SCOPE.md` §1 priced it at zero movement,
and that is what it cost: two columns on the twelve rows, four accessors
(`home_of`, `repair_cost`, `is_verse`, `arrival_name` / `arrival_hint`), the
price wired through `lines()` / `can_buy()` / `refusal()` / `buy()`, and
`ItemDb._relic()` reading the bag's name and description off them. **No new
screen and no new state**: the transaction is the board that already existed, and
"broken" is `not donated(id)` rather than a thirteenth column.

**One direction was chosen where §6.4 read two ways, and §6.4 now says which.**
"Walked it to the right counter and paid" implied the money changes hands at the
smith or the alchemist; "the Lanternkeeper prices a repair the way the smith
prices a rung" implied her board. Her board won, and §6.4 gained a paragraph
saying the home is the sign-post and she is the till — paying at three counters
would have put a fourth kind of line, with its own refusal, on three catalogues
that sell nothing of the sort, which is the fourth screen arriving in
instalments.

**Proved on frames**, `relic_donate.gd` beats A8–A13 and `r_20_counter.png`: the
board carries eleven prices and the Tally-Ledger free, a relic you are holding
and cannot afford is refused with `REPAIR COSTS 80 ◇`, and the pickup toast in
`r_01_inbag.png` reads BROKEN TALLY-LEDGER OF FAIR WEIGHTS.

### ~~D4 — nothing in the game sells Burst charges~~ *(closed)*

GDD §6.5 says charges are bought from the alchemist, and `Game.charges`
(`game_state.gd:~100-103`) repeated it. `AlchemyDb.lines()` offered one bottle
line and three brew lines and nothing else, and `Game.add_charges()`
(`game_state.gd:~510`) had no caller outside `tools/directors/` — directors
granting themselves a handful so their own beats could run. A player who killed
the Slag Ogre owned an item they could never load.

**Closed by believing the GDD.** `AlchemyDb` sells `CHARGES X3` for flat gold,
with no `parts` — a charge is stock you paid for before you left, not something
brewed out of what the floor dropped. The line is **gated on `Game.has(&"burst")`
and absent until then**, which is the sieve `SupplyDb.GATED_BY` already runs the
arrow line through: ammunition for a verb you have never seen is a spoiler and a
slot that lies. It is a **tap**, not a hold, for the same reason the smith's
`ARROWS X10` is — `Catalogue.crafts()` makes a line a hold when it eats found
materials, and gold you can earn again.

Proved by playing to it: `tools/directors/charge_buy.gd` walks up to the
alchemist in the garrison, presses what the prompt names, buys the bundle, takes
the shaft down and casts it. `/tmp/charge/c_00_before.png` and `c_01_after.png`
are the same row and the same camera reading `0 / 12 charges` and `3 / 12
charges`; `c_03_hud.png` is the HUD's working cell carrying the 3; `c_07_blast.png`
is the Burst going off on floor 1 with the cell reading 2.

**It was not the whole hole, and the rest was D13** — closed 2026-08-11. Buying
charges upstairs does not help a player who descends with none and meets floor
2's `pillar_brace` shortcut; the floor supplies them now. See D13.

**And it was not the whole hole in the other direction either** (card #98,
2026-08-11). The counter above was the *alchemist's*, and he does not stand in
the yard until a boss is dead (`StoryDb.UNLOCKS`) — so "you can buy a charge the
moment you own Burst" was true only by the coincidence that Burst comes off the
Slag Ogre, and would have stopped being true the moment a working entered the run
any other way. The line is the **quartermaster's** now: same bundle, same 90 gold,
same gate on owning the working, behind a face that is in the yard on frame one.
`charge_buy.gd` walks to her instead; the paragraph above is otherwise unchanged
and its frames still say what they said.

### ~~D5 — two of the six usable items do not exist in any form~~ *(closed)*

Sustain and Ballast had no row in `ArmamentDb.NAMES` and no stop in
`Game.RIGHT_POOL`, whose own comment said it held "four of the ring's six stops".
`RelicDb.WORKING_RELICS` had landed with D1 and nothing called it — so the game
told a player they had learned a working and then offered no way to perform one.
A donated Verse paid out nothing playable.

**Closed by copying Burst's path and inventing nothing** (issue #30, 2026-08-11).
Burst is four rows in `ArmamentDb` (name, letters, blurb, ammo), one entry in
`Game.RIGHT_POOL`, one arm in `Game.armament_owned()` and two functions on
`HeroRanged`. Sustain and Ballast are the same four rows, the same array, the
same two functions each, and **the same charges** — GDD §6.5's "charges are
arrows", and a quiver is one number however many things draw from it. The ring is
six stops now and `docs/SCOPE.md` §1's ceiling is reached rather than exceeded;
no count moved.

Three things in it are decisions rather than copies, and each is written where it
lives:

- **They cast on the PRESS, not the release** (`HeroRanged.SELF_CAST`). The three
  held items are held because the hold is the aim. Neither of these has a target,
  so a hold would be a delay, and these are cast in the half second where a delay
  is the whole cost. The input layer is unchanged — same two shoulders, same
  `ArmamentDb.action_of`.
- **Ballast's window rides in `Game.draughts`** under `Game.BALLAST_ID`. That
  dictionary is the game's one table of "true now, not shortly", with one tick
  and one signal; a second timer for a working would be a second `_tick_draughts`
  to forget to call. **It has the third slot on the HUD's draught row** (#39):
  that row is derived from `Game.LASTING_IDS` — everything that rides in
  `draughts` and therefore everything with a clock — and not from `PotionDb.IDS`,
  which is what used to keep a non-potion out of it. Storage is still one table;
  what changed is only who reads it.
- **Ownership is asked once**, in `Game.armament_owned()`, which routes the two
  Verses to `RelicDb.knows_working()`. `has()` would answer no forever: a Verse is
  read, not picked up.

**Proved** by `tools/directors/relic_donate.gd`'s K beats, which press the D-pad
and the shoulder rather than calling the functions underneath them — the defect
was that the functions existed and no button reached them. The negative case is
photographed too (`r_30_*`, `r_31_ring_refused.png`): before the donation the
ring walks four stops and `draw_weapon` never lands on either Verse. After it,
six (`r_35_*`), and `r_42`–`r_44` are the chain warded, held through a blow and
then broken by the next one, `r_52`–`r_54` the burned stack and the same blow
costing less and then full price again.

**~~What is still open, and it is small~~: closed by #39.** The window has an
instrument: the third slot on the HUD's draught row, a weight mark in ARCANE and
four tiles that go out one at a time over the eight seconds. The row is derived
from `Game.LASTING_IDS` rather than from `PotionDb.IDS`, so teaching it about a
non-potion took no fork — see `docs/HUD_PLAN.md` §15.16, which also records that
the seam §15.1 promised this would slot into did not exist as described.
Photographed running, half spent and **absent** in `hud_lookdev.gd`'s
`h_17`–`h_20`.

### D6 — GDD's status paragraph is stale

GDD lines 12-17 say what is *not* built includes "the relics and the
Lanternkeeper in §6" and "the three workings (§6.5)". The Lanternkeeper is a row
in `Npc.COUNTERS` and a live `Catalogue` subclass (`scripts/world/npc.gd:~103`;
`relic_db.gd:1-2`), the twelve relic rows exist and are placed by the floor
manifests, and Burst casts (`scripts/combat/burst_cast.gd`; `armament_db.gd:~26`).

**Believe the code.** One of the three workings and most of the relic plumbing
have landed since that paragraph was written.

### D7 — the Slag Ogre's drop is still spelled `bomb_bag`

`BossDb.BOSSES[&"slag_ogre"]["drop"]` (`boss_db.gd:~323`) drops `&"bomb_bag"`;
floor 2's `boss_item` is `&"burst"` (`floor_db.gd:~336`), and every gate compares
against the latter. The two are reconciled by a translation on the way in
(`Game.grant()`, `game_state.gd:~1058`), which the author flagged `[debt]` at
`:~1055` with the reason — the file was owned by another agent that day.

**Believe `&"burst"`.** Harmless today because `grant()` translates, and worth
closing anyway: it is a one-word change, and the second id is the kind of thing
that survives into a table nobody thought to translate.

### D8 — a code comment claims the docs say `Game.has_item()`

`Game.has()`'s doc comment (`game_state.gd:~1066-1070`) says *"docs/GDD.md §5.2
and docs/SCOPE.md M1 both name the check `Game.has_item()` in prose … The docs
are what should move."* They have moved: GDD §5.2 (`docs/GDD.md:458`) and SCOPE
M1 (`docs/SCOPE.md:243`) both write `Game.has()`, and `docs/CONTRACT.md:1461`
states the rule outright.

**Believe the docs.** The comment is the stale half now.

### D9 — SCOPE contradicts its own manifest about the garrison

`docs/SCOPE.md` §1 counts garrison NPCs at **5** (`docs/SCOPE.md:45`) and new UI
screens at **1** (`:52`); the "Broken relics cost nothing on this table"
paragraph sixteen table rows further down (`:126-127`) says the same edit leaves
*"garrison NPCs … 4, new UI screens … 0"*. `relic_db.gd:15` cites the older zero
as current.

**Believe the manifest rows** — they carry the jewelcrafter and the
`StashScreen` exception, both of which are built. The paragraph was written
before either landed.

### D10 — a relic reports its rarity as "Common"

`ItemDb._relic()` casts the tier to a fourth, ARCANE, that `ItemDef.Rarity` does
not name, and `ItemDef.rarity_name()` (`scripts/items/item_def.gd:~134-138`) has
no arm for it — so the pouch's caption calls every relic Common. Self-documented
at `item_db.gd:~180-184`.

**Believe the intent** (a relic is legendary); the fix is one arm in
`rarity_name()`.

### ~~D11 — all twelve relic lore strings are clipped mid-word on the counter~~ *(closed 2026-08-11)*

`CanvasText.wrap()` took a `max_lines` that defaulted to 2 and
`scripts/ui/shop/trade_screen.gd` did not pass one, so every entry in `RELICS`
was truncated on the Lanternkeeper's board — and the smith's and the alchemist's
blurbs with them. Caught by `relic_donate.gd`'s `r_21_hold.png`.

**Closed, and not the way this entry expected.** It was not one argument at the
call site: the trade screen was rebuilt out of Control nodes, so the blurb is a
`Label` with `AUTOWRAP_WORD_SMART` and `SIZE_EXPAND_FILL`
(`trade_screen.gd:~443`, `~460`) and wraps to the panel with no line cap at all —
which re-wraps when the panel resizes, as a measured-once `PackedStringArray`
never could. That left `CanvasText.wrap()` with no callers and **it is deleted**;
`scripts/ui/canvas_text.gd:84-102` is the tombstone, and it carries the warning
for anyone about to reinstate it for a HUD line — `Hud._pack_legend` does not
want word wrapping, because a HUD row is a list of entries that each contain a
space ("LMB SWORD") and breaking on spaces splits a cap from its verb. The
`# NEEDS:` note above `RELICS` is struck through in place
(`relic_db.gd:~125-138`).

**Verified 2026-08-11 (issue #31), by rendering all of it.** The paragraph above
was written from the diff, and a rebuild that removes the mechanism is not the
same claim as *the text fits* — nobody had drawn the twelve. `lore_panes.gd`
does: every row of the Lanternkeeper's board cold (twelve `_unwritten` lines) and
again with all twelve in hand (twelve lore lines), then the smith's twelve and
the alchemist's four, forty panes in all. **Nothing clips.** The longest is the
Sustain-Verse at six wrapped lines; the tightest pane still had eight lines
spare, and the card holds eighteen at 720p. So the headroom question this entry's
card asked is answered with a number rather than a shrug, and no string was
shortened to get it.

Two things that only came out of pointing the instrument at a known-bad case
first, and which are the reason there is a director here at all:

- **The pane does not clip — it grows.** `SIZE_EXPAND_FILL` plus autowrap means
  the `Label`'s minimum size follows the wrap, so a blurb past the card's
  capacity pushes the card taller and leaves by the bottom of the *screen* with
  every line still counted as drawn. A check written as
  `get_visible_line_count() < get_line_count()` therefore passes on a paragraph
  that is 1160 px off screen. `lore_panes._fits` measures both.
- **`RelicDb.lines()` is the only reader of `lore` in the codebase**
  (`grep '\["lore"\]' scripts/ tools/` returns one line). `BossDb` authors a
  `lore` per boss and nothing draws it — which is a separate question about the
  bestiary, not about wrapping, and is not filed here.

**The lore was never cut down to fit the bug**, and that is the part of this
entry worth keeping: shortening twelve entries to work around a wrap default is
a change that is hard to undo and easy to forget, and it would have outlived the
default by a mile.

### D12 — the ownership table this file was asked to join is not in the GDD

The card and the brief both name *"`docs/GDD.md` §7's ownership table"*. GDD §7
is *Difficulty comes from depth, not from you*, and the GDD has no table of doc
owners. The table is **CLAUDE.md §7**.

**Believe CLAUDE.md §7 is the table.** The `docs/ITEMS.md` row landed there when
this file did, and **the missing `docs/BOSSES.md` row landed with this
revision** — leaving a one-line omission in a table already being edited "for
that document's owner" was the wrong call. Adding it falsified the row below it,
which is D17.

### D13 — there is no underground source of charges, and a shortcut door needs one *(severe, new 2026-08-10; **CLOSED** 2026-08-11, card #29)*

Two sessions found the same hole from opposite ends on the same night, which is
why this is a row rather than a footnote on D4.

> **Closed as prescribed.** `ChargeCache` (`scripts/world/charge_cache.gd`) is
> the charge pickup, on `ArrowBundle`'s pattern and through
> `Game.add_charges()`; `Urn.holds` gained a `&"charges"` row so the contents
> stay the placer's decision; and `Dungeon._shortcut_pillar_brace` stands one urn
> wide of floor 2's doorway and outside `K.BOMB_RADIUS`. **Nothing rolls it** —
> there is no `charge_chance` and there must not be, for the reason the last
> paragraph below gives. `tools/directors/charge_supply.gd` walks a hero from an
> empty pouch to an open shortcut without granting itself a charge anywhere.
> No number in `docs/SCOPE.md` §1 moved: no item row, no new atom (the urn is
> the atom), no screen, no mechanic.

The rest of this entry is the defect as it was found, kept because the argument
in it is what the fix had to obey.

- **From the item side** (D4, above): nothing sold charges at all. That half is
  closed — the alchemist sells them now.
- **From the door side** (card #5, `d93bb6e`): floor 2's shortcut prefab is
  `pillar_brace`, a cracked pillar filling the doorway, and its only answer is a
  Burst. A player who descends with an empty pouch is standing in front of a
  door with **no legal way through**, which `docs/PUZZLES.md` §0 rule 2 and GDD
  pillar 2 both exist to forbid: *a floor must be solvable from a cold start.*

**Selling charges in the garrison is necessary and not sufficient.** Charges do
not refill underground by design (GDD §6.5) and that design is right — a
resource that comes back mid-run softens the walk home. What is missing is the
same thing the bow already has: **the room supplies the verb it demands.**
`ArrowBundle` (`scripts/world/arrow_bundle.gd`) is a walk-over floor pickup that
goes on `Game` rather than in the bag, placed by `Dungeon` on a per-room roll and
coughed up by `Chest`; `PuzzleAtoms.ATOMS[URN]`'s own comment
(`scripts/props/puzzle_atoms.gd:~116-119`) states the rule outright — *"solvable
from a cold start with an empty pouch, because the urns beside it hold exactly
what it needs"* — and card #5's `eye_high` prefab puts an urn of arrows beside
the eye for exactly this reason. **There is no charge equivalent anywhere in the
repo**: `Game.add_charges()`'s only non-director caller is the alchemist's line.

**Believe the rule, not the convenience.** The fix is a charge pickup on the
`ArrowBundle` pattern, placed by the prefab that demands one rather than rolled
across every room — a floor that scattered charges would undo the "how deep were
you planning to go" decision that `Game.charges` (`game_state.gd:~100-103`) is
written to protect. Its own card: it is `scripts/props/`,
`scripts/world/dungeon.gd` and a prefab table, none of which #25 touches, and it
is a placement rule rather than a data defect.

### D14 — GDD §6.1's generating rule says "a fifth NPC", and the fifth is built

The rule at `docs/GDD.md:582` ends *"It never adds a screen, a system, or a fifth
NPC."* `docs/SCOPE.md` §1 freezes garrison NPCs at **5** and names all five —
vendor, smith, alchemist, Lanternkeeper, Jewelcrafter — and says *"There is no
sixth counter"* (`docs/SCOPE.md:45`). The Jewelcrafter is built and carries her
own note saying she is the fifth and the last (`scripts/world/npc.gd:~109-111`).

**Believe SCOPE.** The clause should read *"a sixth NPC"*. Logged rather than
fixed: this file does not own the GDD, and the rule it belongs to is quoted in
§2, where the two-part restatement now stands beside it.

### D15 — `relic_db.gd`'s header lists a `bites` column the table no longer has

`relic_db.gd:~50-52` says the column reads *"catalogues, recipes, prices, one
wayfinding hum"*. `docs/GDD.md:635-636` says *"catalogues, recipes, prices, two
workings, one wayfinding hum"*. Since D1 closed, **the table matches the GDD**:
`sustain_verse` and `ballast_verse` both carry
`RelicDb.knows_working() -> Game.RIGHT_POOL's … stop` in `bites`. The code
comment is the stale one.

Worth recording for a second reason. An earlier draft of §2.3 rendered the
comment as a near-verbatim quotation with the GDD's *"two workings"* spliced into
it and only the code cited — a quotation that was true of neither source. **Two
disagreeing sources get two citations, or the disagreement disappears into a
sentence that reads as fact.** §2.3 cites both now.

**Believe the GDD and the table.** The fix is three words in a comment.

### D16 — `docs/BESTIARY.md` §2 gives the lantern to the sword

Its item table reads `| **Sword** | urn, lantern | everything, and that is the
problem |`. `PuzzleAtoms.ATOMS[LANTERN]` says `"verb": "any blow"`
(`scripts/props/puzzle_atoms.gd:~188`) and is verb-agnostic deliberately — the
atom's own note explains that an atom which could only ever be answered one way
could not be coupled to anything, which is what `docs/PUZZLES.md` §3's *convert*
combinator is built on.

**Believe the atom table.** The sword owns the urn; the lantern is owned by no
single item, and that is its design. §1.1 of this file carried the same error
until it was traced back here. Flagged rather than fixed: `docs/BESTIARY.md` is
not this file's to edit.

### D17 — CLAUDE.md §7's `OOT_CATALOGUE.md` row counts the docs above it

The row read *"Owns nothing — it is what the two docs above cite"*, which was
true when the two were `PUZZLES.md` and `BESTIARY.md`. Inserting the `ITEMS.md`
row made it three, and adding the `BOSSES.md` row (D12) made it four — neither
edit touched the sentence that was counting them.

**Fixed here**, and fixed by naming the four rather than counting them, so the
next insertion cannot falsify it again. Recorded rather than silently corrected
because it is the same failure this whole section exists for: a true sentence
about a table, invalidated by an edit to the table that had no reason to look at
it.

---

## 9. Proving a change to this file

There are no frames here — an item doc has no pixels of its own. **The proof is
the citation.** A claim in this file that could name the symbol deciding it and
does not is a claim someone guessed, and this project has been bitten by exactly
that (`potion_db.gd`'s short names were asserted as `EMB`/`IRO` in a plan; they
are `HEART`, `HIDE` and `EMBER` — `PotionDb.DEFS`, `potion_db.gd:~30`, `:~36`,
`:~43`).

**Cite the symbol. The line number is a hint, and it is written as one:**

> `` `RelicDb.knows_working()` (`relic_db.gd:~880`) ``

Not because a line number is useless — it lands the reader within a screen of the
right place — but because in this repo they rot on a timescale of **hours**, and
they rot **silently**. The first draft of this document was written against
`7728db3`. Card #25's edits landed the same evening and moved a dozen of its
citations inside `relic_db.gd`, `floor_db.gd` and `boss_db.gd`; two of the moved
ones still named one function while pointing at a different one, which is the
worst available failure, because the reader believes what they land on. While
*this* revision was being written, `relic_db.gd` grew another hundred lines and
moved them all again. A grep for `knows_working` survives every one of those. A
`:750` does not.

Two rules fall out of it:

1. **Prefer a `const`, a `func` or a table key.** Those are greppable, and they
   are what the next reader would search for anyway — `RelicDb.RELICS`,
   `ShopDb.GATED_BY`, `PuzzleAtoms.ATOMS[HOOK_RING]`, `Game.RIGHT_POOL`. A
   citation to a symbol name is durable in a way a citation to a line is not.
2. **A citation into a comment block is the fragile kind.** Four of the five
   wrongest citations in the first draft pointed at prose inside a `##` header —
   prose that any session touching the file rewrites wholesale, and that has no
   symbol to anchor to. Cite the symbol the comment sits above, and quote the
   sentence itself when the wording is the point.

**Path-qualify anything ambiguous.** There are two files named `puzzle_atoms.gd`
— `scripts/props/puzzle_atoms.gd` (the atom table) and
`tools/directors/puzzle_atoms.gd` (the director that photographs it) — and
`cracked_pillar.gd` lives at `scripts/props/atoms/`, not `scripts/props/`.

When an item changes, the directors that already watch one are
`tools/directors/burst_cast.gd`, `charge_buy.gd`, `forge_loop.gd`,
`jewel_loop.gd`, `alchemy_loop.gd`, `relic_donate.gd`, `thief.gd` and
`tools/directors/puzzle_atoms.gd`. Run the one that owns the shelf you touched,
and update this file in the same commit — including §8, which is the part most
likely to go stale, because the good outcome for every entry on it is that it
stops being true.
