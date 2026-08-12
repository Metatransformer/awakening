# SCOPE — the prototype boundary and release ceiling

`docs/GDD.md` says what the game is. **This document says how much of it there
may be, and it is the one that gets to say no.** `docs/NOW.md` is narrower: it
says which part of that ceiling the current stage authorises us to touch.

It exists because this project's failure mode is not "we cannot build it." Every
system in `docs/METAGAME.md` is built and works. The failure mode is that the
game is *interesting*, and an interesting game invites one more floor, one more
item, one more vendor, forever, until there is no version of it that is finished.

So: everything below is a **count**. Counts can be checked. "Is this scope creep"
is an argument; "is this number in the manifest" is not.

The manifest is a ceiling, not a backlog. A row below can be valid for the
eventual prologue and still be the wrong thing to build in pre-production.

**Current freeze — 2026-08-11.** M4's first-floor prototype is built, but its
human fun gate is unpassed. M5 exists beyond that gate as accepted sequencing
debt. **M6 and all production-content expansion are frozen** while
`docs/design-tests/CORE_LOOP_PROOF.md` tests whether one descent creates a
specific voluntary desire for another.

> **The two tests for any proposal:**
> 1. *Does `docs/NOW.md` authorise it at this stage?*
> 2. *Is it on the manifest in §1? If no, it is out unless an approved design
>    decision deletes something of equal size (§4.2).*

---

## 1. The manifest

This table is frozen. **If a number in it goes up, that is scope creep, by
definition**, and §4.2 applies.

| | Count | Notes |
|---|---|---|
| Dungeon floors | **4** | + 1 endless mode, already built |
| Bosses | **4** | Warden, Slag Ogre, Bellwake, Riven Knight |
| **New monster models** | **0** | Bosses are scaled/re-tinted `golem`, `ogre`, `wraith`, `knight_iron`. The four **minibosses** take four of the five the bosses leave — `troll`, `orc`, `skeleton`, `kobold` — the same way, and their move sets are the design, not the silhouettes. **No floor's miniboss shares a model with its boss**; that is the rule that picks these four |
| Enemy kinds in rotation | **9** | Everything in `assets/monsters/`. No tenth. |
| Dungeon kits | **1** | The P6 kit, four tints |
| Usable items | **6** | Bow, Hookshot, **Burst**, **Sustain**, **Ballast** — all built, the last two on 2026-08-11 (`docs/ITEMS.md` §8, D5) — and the Far Lantern, which has no verb |
| **Ring stops** | **6** | Sword, bow, hookshot, Burst, Sustain, Ballast. **Hard ceiling** — `docs/CONTRACT.md` §4.1. `Game.RIGHT_POOL` holds all six now, so this row is no longer a plan: a seventh entry in that array is an amendment |
| **Kit wheel slots** | **8** | New row, 2026-08-11, owner's call. Hold LB, point, release — `docs/CONTRACT.md` §4.2. **Eight is short of the ten a player can own on purpose** (6 ring stops + 4 bottles), because a wheel with room for everything is a hotbar nobody curates. It adds no screen (a card on the existing Items panel), no new id vocabulary (armament ids and `bottle_N` tokens) and no new field the D-pad did not already write. A ninth slot is an amendment to the sentence above, not a constant. |
| **New mechanics** | **2** | The working, and **the puzzle**. Was 1. See §4.2's fourth ledger line — this is an owner's amendment, not an absorption. **The kit wheel is not a third**: it is a faster door onto `Game.loadout` and `Game.item_selected`, both of which the D-pad already wrote. |
| Locked doors | **8** | 4 shortcuts, 3 vaults, 1 to the Long Descent. **They are puzzles now, not checks** — `docs/PUZZLES.md`, GDD §5.3 |
| Vault prefabs | **3** | Three rooms each |
| **Puzzle atoms** | **9** | Phase 1: key door, urn, plate, push block, eye switch, cracked pillar, hookshot target, sun switch, **lantern**. The lantern was pulled forward out of phase 2 (2026-08-10), leaving three there, uncommitted |
| **Puzzle prefabs** | **12** | 4 verb tiers × 3 shapes (shortcut, gate room, treasure) |
| **Puzzle combinators** | **9** | Was 6. Nest, sequence, time, displace, cycle, **couple** (lights out), **chain**, **convert**, **reconfigure**. This is where the variety lives, which is why the prefab count is 12 and not 40 — and why the 6 → 9 amendment bought no new atoms. `docs/PUZZLES.md` §3.1, §8.1 |
| **Enemy behaviours** | **8**, 4 committed | New row, 2026-08-10. A behaviour is a key on an existing `Enemy.DEFS` row that names **which item answers this body** — thrower/shield, guard/burst, perched/bow-or-hookshot, thief/chase. Not a tenth enemy kind and not a model. `docs/BESTIARY.md` §3 |
| **Chord edges** | **1 / floor** | The cycle. `dungeon.gd` builds a tree today; one extra edge per floor is the whole change |
| **Blessings** | **12** | Six patrons × two. Run-scoped, 1 bag slot, worth 0 gold, ends with the run — no thirteenth |
| **Minibosses** | **4** | One per floor, behind the treasure puzzle, **two** beats each (a boss gets three). None drops a verb or a relic; floor 1's drops the **maker's mark**, a progress token and nothing you can use (`BossDb.PROGRESS_TOKENS`, `docs/PUZZLES.md` §4) |
| Relics | **12** | Named, hand-placed, non-rolling. **Two are Verses; all twelve arrive broken** — GDD §6.4 |
| Garrison NPCs | **5** | Five counters — vendor, smith, alchemist, Lanternkeeper, Jewelcrafter — and that is everybody. Was 6 for one day: **the village elder went in as a sixth, non-counter person and came back out the same day, folded into the Lanternkeeper** (GDD §1, §6), who now carries his three recorded lines. The count returns to 5 without a counter being added or removed. **There is no sixth counter**, and that is the half of this number that was ever the brake — see §4.2's fifth ledger line. Since 2026-08-10 they **arrive** rather than all standing there on frame one (`StoryDb.UNLOCKS`, `docs/METAGAME.md` §6): two at the start, the smith on the **maker's mark** the floor 1 miniboss drops (card #91, so he is reachable on the first descent), the alchemist and the jewelcrafter at one and two bosses. That is a gate on the same five, not a sixth. Each one is **introduced** on arrival — a two-hander with Aldric and a camera pan, `StoryDb.INTRODUCTIONS`; that is a table and ~20 lines (`scripts/world/introduction.gd`), not a cutscene system. **Six counters at five people since card #91**: the quartermaster grew a second board, THE STORES, when the smith moved behind the miniboss and took arrows, bag slots and heart containers with him. The brake was never the number of boards — it is the number of PEOPLE, and a board is still a `Catalogue` subclass and a row in `Npc.COUNTERS`. |
| **Stats** | **5** | Damage, speed, max health, stamina, soak. GDD §6.6. No sixth. |
| **Upgrade tracks** | **20** | 4 gear (edge, guard, string, chain) + 8 armour (4 pieces × 2 paths) + 8 jewel (4 slots × 2 paths) |
| Armour pieces | **4** | Chest, legs, arms, boots. ×2 paths, ×4 rungs (rung 0 free, 3 bought — `K.FORGE_MAX`) |
| Jewelry slots | **4** | Amulet, 2 rings, bracelet. ×2 paths, ×5 rungs (base + 4 bought) |
| **Armour / jewelry art** | **0** | Every piece is a number. No modular meshes, no icons beyond the existing catalogue rows. |
| Garrison scenes | **1** | The courtyard. There is no second settlement. |
| **New UI screens** | **2** | `StashScreen`, plus the owner's 2026-08-11 Votive Court modal. The latter replaces three world pickups with one diegetic six-god choice and keeps the rendered shrine visible behind its lower panel. |
| Endings | **2** | Lantern, Chord |
| Currencies | **1** | Gold. Components and relics are items, not money. |
| Ingredients / components | **10 / 8** | As built. No new rarity band. |
| Forge ladders | **12** | At the smith: 4 gear + 8 armour. Was 5; `plate` became 8. ×4 rungs |
| Draughts | **3** | As built |
| Dialogue trees | **0** | NPCs have counters, not conversations. **Unmoved by the voice lines below** — a line you cannot answer is not a tree. **And unmoved by the dialogue BOX** (2026-08-10, owner's call): addressing a keeper now opens `DialogueBox` with their line typed under their face and two options on the end of it, Trade and Leave. That is a menu with a portrait, not a tree — no state, no memory, no branch that outlives the press, and the same two options at every counter. A third option, an answer that changes what they say next, or anything that remembers what you picked, is a tree and is an amendment |
| Quests | **0** | The relic list is the quest log |
| Voiced lines | **15** | Was 0, recorded 2026-08-10 and **this is all of them**: 1 narrator, 3 elder, 3 each for smith / quartermaster / jewelcrafter, 2 alchemist. The table in `scripts/autoload/voice.gd` is the manifest and a sixteenth is an amendment. The elder's three are the Lanternkeeper's, those two being one man since the same day; the alchemist still has no sale line |
| Cutscenes | **1 reusable ceremony** | Owner amendment, 2026-08-11: all four boss items share one item-get camera/pose/fanfare/text presentation. It is one system and no item may author a bespoke scene. The two endings remain in-engine sequences. **The opening is not another**: it is a still painting held on the existing `Flow` layer under one recorded line, no camera, choreography or actor (`scripts/ui/title/cutscene.gd`) |

### What "new" actually costs, and why the zeroes matter

The two zeroes and the small integer are the reason this plan is small enough to
finish. The integer moved from 1 to 2 on 2026-08-10 and **the zeroes did not**,
which is the thing to check first when the next amendment is proposed.

**Zero new monster models.** Ten `.glb` files are already imported, rigged
against the shared 81-clip `monster_library.res`, and proven by
`monster_lookdev.gd`. Four of them become bosses by scale, tint and an authored
move set, and **four more become minibosses the same way** — a different four, so
no floor's miniboss shares a silhouette with its boss. Commissioning or
generating eight of them — and rigging them, and fixing the facing bug that has
bitten this project three times (`CLAUDE.md` §4) — is weeks, and it buys
silhouettes the player sees for four minutes each.

**The move set is the design; the model is a placeholder.** That is the whole
reason this row survived the 2026-08-10 amendment without moving: a miniboss is
two authored beats and a telegraph, and none of that is art.

**Two authored UI screens.** `StashScreen` is the first exception; the Votive
Court modal is the second, added by explicit owner direction on 2026-08-11.
`TradeScreen` already drives two catalogues that behave differently (gold-only
rows, gold-and-materials rows, held confirms, affordability colouring, refusal
footers). A donation is a row whose price is one relic. The Lanternkeeper is a
subclass and a row in `Npc.COUNTERS` — the contract in `docs/METAGAME.md` §6.6
says so explicitly: *"a third counter is a `Catalogue` subclass and a row in
`Npc.COUNTERS`, nothing else."*

`StashScreen` is the exception and it is worth naming why, because the next
person will want to make it a third one. Every `Catalogue` row is *a thing with a
price you either can or cannot pay*; the footlocker has no price and no
affordability, and it needs a column the trade screen has nowhere to put — what
is on the shelf, beside what is in the bag, moving both ways. Bending
`TradeScreen` into that would have cost more than the 200 lines it saved and
would have left the smith's counter carrying a branch for a case it never sees.
The Votive Court does not fit `TradeScreen` either: it is a one-of-three choice
among six fixed gods, three of whom must remain visibly silent, over live world
figures. The second screen is recorded in §4.2 rather than hidden as a panel.

**Two new mechanics** *(was one, amended 2026-08-10 — §4.2's fourth line)*. The
working — a thrown arc, a fuse, a sphere query, a cracked wall. And the puzzle —
nine props that emit `solved`, nine combinators, and one extra edge in the room
planner. Everything else in the plan is still a *gate on*, a *number in*, or an
*arrangement of* something that already runs, and that includes the two things
that arrived alongside the puzzle and are **not** mechanics: a Blessing is a bag row
worth zero, and the shield reflect is a raycast off a shield that exists.

### Why "usable items" went 4 → 6 and nothing else moved

Because a working is a **usable item**, not a system. `armament_db.gd` already
holds the right hand; `Game.cycle_weapon` already steps it; CONTRACT §4 already
says RB and RT *fire what is in the right hand*; the bow already spends a
counted resource bought in the garrison. Burst, Sustain and Ballast are rows in
that table with a charge count where the arrows go. There is no mana, no school,
no casting layer, and no new save field beyond the ones an owned item and a
counted resource already need (GDD §6.5).

The **ring stops** row is the honest cap, and it is the one to defend. Scope
pressure on magic will not arrive as "add a system" — it will arrive as a fourth
spell that is only a row. Six stops is where a ring stops being countable, which
is the whole argument CONTRACT §4.1 used to delete bindable slots in the first
place. **This row is why there is no fourth working.**

### Broken relics cost nothing on this table

GDD §6.4 — every relic arrives broken and is repaired (or, for a Verse, read) at
a home counter for gold — moves **no number here**. Relics stay 12, garrison
NPCs stay 4, and this change adds no UI screen. It is a price and a home on rows in
`relic_db.gd` that the plan already required, plus a description string. It
*removes* a special case: the Lanternkeeper stops being the one counter whose
transaction costs no gold.

**Built, and it cost exactly that** (`docs/ITEMS.md` §8, D3). This paragraph said
"a price and a `broken` flag"; the flag turned out to be one column too many —
all twelve arrive broken, so the state is `not RelicDb.donated(id)` and a column
saying `true` twelve times is a second copy of it with a way to disagree. Two
columns landed, `home` and `repair`, and no count moved.

---

## 2. The no-list

These will be proposed. Several of them are good ideas. They are refused for
this release, with reasons, so that the refusal does not have to be re-argued
every time someone has the idea again.

**Refused because they are a different game:**

- Multiplayer or co-op of any kind.
- A second garrison, an overworld, a hub outside Valenfeld.
- Player-joinable factions. The Vale has fourteen of them in the lore. That is a
  reason to keep the lore, not a reason to build the game the lore implies.
- Character creation, races, classes, skill trees.
- **A spell school, a mana bar, a spell level, or a fourth working.** The game
  has magic — three usable items with charges, GDD §6.5 — and that is all the
  magic it has. Every one of those four is the first step of the multi-class game
  the line above already refuses.

  **A blue bar shipped anyway, and the refusal still stands** (owner directive,
  2026-08-10). It is a **price on the charged spin and nothing else**: 48 points,
  12 a spin, four spins a trip, refilled only on entering, extracting or dying
  (`RunState`). Read the shape of it, because the shape is the whole defence —
  it has no spells, no ranks, no school, no casting input, no shop that sells it,
  and no way to top it up underground. `GameState` deliberately has **no
  `restore_magic`**: an API that hands back *some* magic is how a potion, then a
  font, then a school gets in. The one thing that may spend it is a sword swing
  the player already had.

  **`restore_magic` now exists, and it is a fence rather than a hole** (owner
  directive, 2026-08-11, card #98). The quartermaster sells **Small Beer**, a
  ration you sit down for; it is the drink half of `docs/METAGAME.md` §6.4. The
  paragraph above was right that an accessor which hands back *some* magic is how
  a potion gets in, so the accessor shipped with the potion's whole shape refused
  around it, and every clause of that is checkable rather than promised:

  - **One caller, and it is named.** `RationDb.apply_tick` is the only thing in
    the project that calls it. If rations go, so does the accessor. Anything that
    wants to be the second caller is a SCOPE amendment, not a patch.
  - **Nothing underground refills the bar.** No drop, no font, no chest roll, no
    pickup. You buy the cup in the yard or you do not have it. The clause above
    that refuses this is *unchanged and was not amended*.
  - **Nothing pays without a clock in front of it.** Twelve seated seconds
    (`K.MEAL_TIME`), cancelled by a step, a swing or a blow. A mana potion is a
    button; this is a decision to stop playing for twelve seconds.
  - **One spin, exactly.** `K.MEAL_MAGIC == K.MAGIC_SPIN`, asserted by
    `tools/directors/rations.gd` beat E8. A cup buys back one of the trip's four
    spins, so "how many spins does this trip get" still has an answer.

  What this line still refuses, unchanged: a second thing that spends the bar, a
  spell bound to it, a rank on that spell, and anything underground that refills
  it. The first of those is the one that will actually be proposed, and it is the
  one that turns a price into a resource system.
- Mounts, fishing, farming, **housing**, cooking.

  **Cooking is still refused and rations are not it** (card #98). There is no
  recipe, no ingredient, no station and no skill: hardtack and small beer are two
  rows on a shop board that put a fixed number back into a bar you already have.
  What this line refuses is food as a *system* — things you combine, a bench you
  combine them at, buffs with durations and names. If a ration ever gains an
  ingredient it has become cooking and this line applies to it again.

  **Housing shipped anyway, in one room, and the refusal still stands.** The
  hero's quarters (`scripts/world/house.gd`) is a lean-to in the courtyard's
  south-west corner with a bed and a footlocker in it. What this line refuses is
  *housing as a system* — a plot you buy, rooms you place, furniture you
  purchase and arrange, a decoration economy, a second interior to author and
  light. None of that exists and none of it is planned. What shipped is two
  props in an alcove, at the same budget as the smith's anvil: it takes no gold,
  it has no upgrade ladder, and it has nothing you can put in it that is not an
  item you already own.

  It was allowed through because both props close holes the garrison already had.
  The bed **writes the save on demand** — transitions and five minutes of active,
  unpaused play both autosave now, but resting remains the immediate manual
  affordance after selling, forging or brewing (`scripts/props/bed.gd`). The footlocker
  **stops the garrison silently destroying goods** — `Run.enter` clears the bag, so
  ingredients carried home and not sold before the next descent were deleted
  without a word. Neither is a feature anyone asked for as housing; both are
  bugs wearing furniture.

  See §2's "delete a tension" entry below for the storage half of the argument,
  and `docs/METAGAME.md` §9 for the numbers.

**Refused because they multiply the authoring cost of everything else:**

- **Hover boots.** A traversal item needs gaps to traverse in every room forever.
  See `docs/GDD.md` §10.
- **A fifth floor, or an alternate floor behind a fork.** A fork is a door and a
  three-room prefab. When it wants a tint and a roster it has become a floor.
- **Procedurally generated bosses.** Four authored move sets are the point.
- **A second dungeon kit / biome.** The four tints are the variety budget.
- **NPC schedules, day/night, weather.**

**Refused because they delete a tension the game is built on:**

- A relic that can be sold, or that rolls from a table (GDD §6.3).
- A bag upgrade past the four already priced (GDD §10).
- **Storage the dungeon can reach.** The footlocker holds `K.STASH_SLOTS` = 24
  slots and it is nailed to the floor of a room in the garrison. GDD §2 refuses
  "infinite storage" because the question the whole game turns on is *is what I
  am carrying worth more than the walk back* — and a shelf you can reach from
  floor three answers it for you, forever. So: no portable chest, no
  send-to-stash, no "bank it from the vault", and no second locker underground.
  The 24 is finite for the same reason the bag is; when it fills you sell
  something, which is the decision the cap exists to force.
- Healing items found underground (GDD §10).
- Fast travel that is not a shortcut door you unlocked.
- **A separate checkpoint/rewind system.** Mid-run save/load is allowed
  (`docs/METAGAME.md` §5), but each slot owns only its current state and a save
  overwrites it; there is no checkpoint stack or parallel history to retreat
  through.
- Level-scaled enemies (GDD §7).

**Refused because they are how software projects die:**

- A test suite written to "lock in" behaviour that a director already proves.
- A refactor of a working system that no card asked for.
- An engine, renderer, or Godot version change after M1.
- A second implementation of anything that has one (`CLAUDE.md` §0).

**Deferred to a sequel, explicitly and without shame:** hover boots, a second
dungeon, the Listening College as a joinable faction, Aelvyrenn, boss rematches,
New Game+. Write them down here when they come up. A named deferral is how an
idea stops costing you attention.

---

## 3. The build record and intended order

This table records what was built and the dependency order the release plan
expects. A checkmark proves implementation, not player value, and completing a
later row does not waive an earlier human gate. **`docs/NOW.md` owns the next
authorised move.**

Each implementation milestone is closed by **a director that runs, produces
frames, and prints no `FAIL`** (`CLAUDE.md` §2). Human design gates are closed by
playtests against a precommitted design test, never by a director or an agent's
opinion.

| M | What | Closed by |
|---|---|---|
| **M0** | **The freeze.** Land this doc + the GDD. Annotate `METAGAME.md` where it is superseded. No code. | Docs merged to `main` |
| **MF** ✅ | **The forgiveness pass. Landed 2026-08-10.** Four independent changes to systems that are already built, and **none of them depends on anything else in this table**: the document case (GDD §3.1), Reforge and Recut (§6.6), the receipt's second column, and the mercy toggle (§7.1). Lettered rather than numbered because it does not sit in the dependency chain — but it lands **before M4**, because the demo is a design instrument and a stranger's first hour is exactly what forgiveness is for. | `forgive_loop.gd` ✅ |
| **M1** | **Gates and gear.** `Game.has()`. Sword + shield + rope at start; bow and hookshot removed from the starting kit; their forge ladders hidden at the smith until owned. **The atom kit** — the eight phase-1 puzzle props (`docs/PUZZLES.md` §2), each a body that emits `solved` and a door that listens, with a refusal that names the verb. This replaces the locked-door prop that used to be this row: a door keyed to an item id is the check §5.3 stopped being. | `gate_locks.gd`, `puzzle_atoms.gd` |
| **M2** | **One boss.** The Cistern Warden. Boss door replaces the deepest room's stair; arena; a three-beat telegraphed move set; a separate relic pickup; and an earned great chest whose Bow is granted only on open through the reusable item-get ceremony. The door stays open and the fight never returns. | `boss_cistern.gd` |
| **M3** | **The relic and the hall.** `RelicDb` as a `Catalogue`; the Lanternkeeper NPC; donation on the existing `TradeScreen`; relics ride in the bag, are charged the fee, die with the bag and return to their room; **they arrive broken, name their home counter in the description, and cost gold to repair (GDD §6.4) — the first is free**; the first three unlocks live; one garrison prop lights per donation. | `relic_donate.gd` |
| **M4** | **Floor 1, whole.** The Cistern's manifest: room count, band table, tint, boss door, shortcut door, vault door, deep chest. The vault prefab. **Plus the whole puzzle spine, proven once**: the chord edge in `dungeon.gd`'s planner, the `gate_room` and `puzzle_room` anchors, the Cistern's T0 gate room (a key hunt) with its cycle back to the entrance, its treasure puzzle, **the Sluice-Keeper**, and the Votive Court. **This is the demo.** | `cistern_floor.gd`, `puzzle_loop.gd` |
| — | **🛑 THE GATE. Play M4 for an hour. See §4.1.** — **still unpassed as of 2026-08-11, and M5 below it is ✅.** Say that out loud rather than let a reader infer it from the marks: M4's *build* is complete and proven (`cistern_floor.gd` and `puzzle_loop.gd` pass end to end; #67 was its last blocker), but the gate is not a build check and no ✅ on this table can close it. Agents cannot pass it — §4.1's four questions are about whether an hour of it is *fun*, and an agent reporting that its own floor is fun is worth nothing. It needs a person at the keyboard. Everything landed past this line is therefore built **on an untested premise**, which is a known and accepted debt, not an oversight. | A human, playing |
| **M5** ✅ | **The workings.** Burst: throw arc, fuse, blast, damage, cracked walls. Then Sustain and Ballast as rows on it, and charges on the alchemist's board. **This is also what switches the T2 atoms on** — the cracked pillar is built in M1 and inert until here, which is the correct order: a prop with no verb is a prop, and a verb with no prop is a dead end. **Landed whole, 2026-08-11.** The arc, the fuse, the blast, the damage and the cracked pillar are `scripts/combat/burst_cast.gd`, proven by `tools/directors/burst_cast.gd`. **Sustain and Ballast are cast, not pending** — `HeroRanged._cast_sustain` / `_cast_ballast`, refusals owned by `Heat.sustain()`, four `ArmamentDb` rows each, and the ring full at six stops; proven by `relic_donate.gd`, which grew 319 lines for exactly that. This row read "still rows to write" until 2026-08-11, eleven days after they shipped. | `burst_cast.gd` ✅, `relic_donate.gd` ✅ |
| **M6** | **Floors 2–4, bosses 2–4, minibosses 2–4.** Repetition of M2 and M4 with the pattern proven. Three manifests, three boss move sets, three miniboss move sets, two vault prefabs, six doors, three gate rooms, three treasure puzzles. **Invent nothing here.** | `foundry_floor.gd`, `choir_floor.gd`, `chord_floor.gd` |
| **M7** | **The endings.** Lantern ending + credits; the Long Descent gate and the floor-10 relic; the plaque; the Chord ending. Relics 4–12 wired. | `endings.gd` |
| **M8** | **Audio.** `Bus.request_sfx` is emitted today and nothing listens (`GDD` §8, as it stood). Music, ambience, the whole SFX vocabulary. This is a ship blocker, not a polish item. | `sfx_cues.gd`, extended |
| **M9** | **Ship.** Settings, rebinding, export presets, controller glyphs on every platform, save migration, the store page, the trailer. | A build a stranger can install |

### Why M6 is one milestone and not three

Because floors 2, 3 and 4 must be *the same work three times*. If floor 2 needs a
new system, the pattern from M2/M4 was wrong and the fix is to go back and change
the pattern — not to give floor 2 a special case. **A special case in M6 is the
single most likely way this project fails**, because it is the point where the
game is fun, the shape is proven, and inventing feels safe.

### Why the demo is M4 and not M9

A demo built from the first floor of a finished game is a marketing task. A demo
built at M4 is a *design instrument*: it is the cheapest possible answer to
"is this actually addictive," and it arrives before the expensive half of the
plan. Put it in front of people.

---

## 4. The four rules

### 4.1 The gate: prove M4 before production starts

The original gate was one designer playing for an hour. That remains useful
self-play, but it is weak evidence for desire because the designer already knows
what comes next. **`docs/design-tests/CORE_LOOP_PROOF.md` now owns the
gate:** five cold first-hour sessions, observed and assessed against criteria
written before the sessions. `docs/PLAYTESTING.md` owns the method.

At M4 the game is one floor, one boss, one item, one vault, three relics and a
garrison that visibly changed three times. These remain the four diagnostic
questions after each session:

1. Did you want to go back down? *Why* — name the specific thing you wanted.
2. Did you ever leave with a relic and feel the walk? Did you ever lose one?
3. Did the garrison changing register at all, or did you have to be told?
4. **The gate room: was it a puzzle or a chore?** And when the cycle opened, did
   you recognise where you had come out — or did you just walk through a door?
   That recognition is the entire claim `docs/PUZZLES.md` §4 makes, and M4 is the
   only cheap place to find out it is false.

If the answers are weak, **the fix is at M4, not at M6.** Three more floors of a
loop that is not compelling is three times the content and none of the fun, and
it is the most expensive mistake available in this plan. Floors 2–4 are the
*amplifier*. They amplify whatever floor 1 is.

This is the only place in the schedule where stopping and redesigning is the
correct move. Everywhere else, redesign is creep.

### 4.2 Equal deletion

Anything added to the manifest requires deleting something of comparable size
from it, in the same commit, named in the commit message.

Not "we'll cut something later." Later never comes; that is the entire mechanism
by which scope grows. A fifth floor costs a vault and two relics. A new monster
model costs an existing one. If nothing feels worth deleting, the addition was
not worth adding.

**The ledger. Every addition to §1 gets a line here, with what paid for it.**

| Added | Paid for by | Where |
|---|---|---|
| The Sustain-Verse, the Ballast-Verse (2 relics) | **Fletcher's Jig** and **Waterwheel Gear**, deleted | GDD §6.2 |
| Usable items 4 → 6 | Nothing — a working is a row in `armament_db.gd`, and the **ring stops** ceiling was added in the same commit to cap it | §1 |
| **The gear loop.** Garrison NPCs 4 → 5, forge ladders 5 → 12, 8 jewel tracks, 5 named stats | **Nothing. This is an owner's amendment to the manifest, made deliberately and with the cost known.** | GDD §6.6 |
| **Puzzles, Blessings and minibosses.** New mechanics 1 → 2, 9 atoms, 12 prefabs, 12 Blessings, 4 minibosses, 2 anchor kinds, 1 chord edge per floor | **Nothing. The second owner's amendment, 2026-08-10.** The jewelcrafter's 8 tracks were offered as the deletion and the owner declined | `docs/PUZZLES.md` |
| **The voices and the elder.** Voiced lines 0 → 15, garrison NPCs 5 → 6, and an opening that is not a cutscene | **Nothing to delete: the lines were already recorded when they arrived.** The owner made them and asked for them to be wired; the manifest's job here is to write down the ceiling, not to relitigate a finished asset | §1, `scripts/autoload/voice.gd` |
| **The Ocarina pass.** Puzzle combinators 6 → 9, enemy behaviours 0 → 8 (4 committed) | **Phase 2's three uncommitted atoms are on the table** — chain and convert make the torch and the timed bars redundant. Everything else on both rows is a key on a table that exists. **Zero new atoms, models, screens, items or beats** | `docs/PUZZLES.md` §3.1/§8.1, `docs/BESTIARY.md`, `docs/OOT_CATALOGUE.md` |
| **The Votive Court.** Echo pedestal → six-god shrine; new UI screens 1 → 2 | **Nothing deleted: explicit owner-directed replacement, 2026-08-11.** The screen is the requested readable choice; the old three-mote presentation and world-caption proof were deleted in the same change | `docs/PUZZLES.md` §6, issue #101 |

The first line is the rule working as intended: the two deleted relics were the
only entries on GDD §6.2's table that were numbers on a subsystem rather than
changes to the garrison, which is the §3 test a relic exists to pass. The
addition paid for itself *and* raised the average.

The second line is the rule being **honest about a hole**. Two usable items
arrived without a deletion, because they genuinely cost no new system — and that
is exactly the argument every future addition will make. The ring-stops ceiling
is the price: from here, a seventh stop costs a sixth.

The third line is the biggest single change this manifest has taken, and it is
recorded without a deletion **on purpose**. The owner's position is that
upgrading gear, crafting jewelry and brewing is *the core loop* — the reason to
delve, not a service beside it — and a manifest that refuses the core loop is
measuring the wrong game. That is a call the owner gets to make and this document
does not.

What the ledger asks in return is that the cost is not pretended away:

- **It is not free, and most of it is not code.** The mechanism is small — the
  branch is two track ids and a ceiling (GDD §6.6) — but 20 tracks is roughly 60
  authored rungs, each needing a price, a recipe and a sentence of detail text.
  That is the real bill and it is paid in tuning, not in engineering.
- **The component economy has to be re-tuned, not extended.** Armour alone goes
  from 3 purchases to 12. `ShopDb`'s own comment says prices are set against the
  drop tables — those tables now have four times the demand on them.
  `docs/SCOPE.md` §1 still says **Ingredients / components 10 / 8, no new rarity
  band**, and that row is the one to defend: the answer to a longer ladder is
  *drops per run*, never a fifth component.
- **The ceilings in §1 are now doing the work §4.2 used to.** Five stats, four
  pieces, four slots, no sixth NPC, zero armour art. Those counts are the whole
  brake, so a proposal that moves one of them is back to needing a deletion.
  *(Read "no sixth NPC" as **no sixth counter** — that is what it always meant,
  and the fifth ledger line is where the distinction got tested.)*

The fourth line is the same call made a second time, and it needs the same
honesty. The owner's position is that **a locked door standing in for a puzzle**
was the design borrowing Zelda's noun without paying for Zelda's verb, and that
the gate room — a puzzle you must solve to walk the critical path — is the
differentiator rather than a garnish. The jewelcrafter was put on the table to
pay for it and was declined, on the same grounds as the third line: the gear loop
is *why you delve*, not a service beside it.

What it costs, stated rather than pretended away:

- **The bill is art and tuning, not engineering.** Eight props, four miniboss
  move sets and twelve prefabs. The mechanism is genuinely small — the atoms are
  bodies that emit `solved` and doors that listen, the cycle is one extra edge in
  `dungeon.gd`'s planner, and a Blessing is a bag row worth zero.
- **This is the second amendment in two days.** That is the number to watch. Two
  is a pattern forming, and the rule §4.2 exists to enforce has now been set
  aside twice by the only person allowed to set it aside. A third should be
  hard, and the counts in §1 are what make it hard.
- **`New mechanics` is now 2 and that row is the one to defend.** The puzzle is
  a whole mechanic; the Blessing is not, because it is a bag row and a shrine, and
  the shield reflect is not, because it is a raycast off a shield that exists.
  Anything that claims to be free the way those two are should have to prove it
  the way those two did.

The fifth line is the smallest of the four amendments and the one most likely to
be misread as a precedent, so: **what moved is not what the ceiling was
guarding.**

- **The number that mattered was counters, and it did not move.** "Garrison NPCs
  5, there is no sixth" was written to stop a *sixth catalogue* — another screen,
  another price table, another draw on the same drop tables (the third ledger
  line's second bullet is the whole argument). The elder had no `counter` key, no
  `ShopBooth`, no `Catalogue`, and touched gold nowhere. At that point new UI
  screens stayed 1; the later Votive Court amendment moves the current ceiling to 2,
  currencies stay 1, components stay 10 / 8.

  **And then he stopped being a separate person at all** (2026-08-10, later the
  same day): the authored body that arrived for the Far Lantern is a hooded
  white-bearded old man, so the owner merged the elder into the Lanternkeeper.
  The headcount is 5 again and his three lines moved onto a row that already had
  a counter. Worth recording because it is the *opposite* of the drift this
  ledger exists to catch — an amendment that gave the number back.
- **Fifteen lines is a closed set, and the file says so.** `Voice.LINES` is the
  manifest, one row per recording, and a speaker with no take for a cue is
  silently skipped rather than covered by somebody else's line — which is why the
  alchemist has no sale line and the Lanternkeeper has none at all. **That
  silence is the ceiling doing its job.** A sixteenth line is an amendment here,
  not a commit.
- **This is where "voiced" would grow if it grew, and it must not.** The bill for
  voice is never the wiring; it is that every future counter, every new screen
  and every rewritten line owes a recording session, and a line that goes missing
  is worse than one that never existed. Fifteen lines is a garrison that speaks.
  A hundred is a game that needs a script, a cast and a pipeline, and
  `Dialogue trees 0` is the row that stops it.
- **The opening is one line over the layer `Flow` already owns.** No camera, no
  cut, no authored beat — `Flow.new_game` raises a `Cutscene` (a `TextureRect`, a
  `Label` and a clock) on the same CanvasLayer the fade and the loading card use,
  and `Game.flags` makes it once per save. It gained a PAINTING and its words on
  screen on 2026-08-10 and it is still not a cutscene by this table's meaning:
  nothing moves. That is why the opening does not increment `Cutscenes`. The one
  authorised gameplay cutscene is the reusable boss-item ceremony in §1; a
  camera move added anywhere else is another cutscene and needs an amendment.
- **`Cutscene` is a subtitle clock, and that is the ceiling.** One still, a list
  of lines, one recorded clip per line — a clip covering several lines is split
  evenly between them, which is what the opening's single take does today. The
  moment it wants a second image, a transition between them, or a speaker who is
  not the narrator, it has stopped being this and the row above applies.

The sixth line is the first one on this table that **arrives with a deletion
offered rather than declined**, and that is the only reason it is a ledger line
and not an amendment.

- **What it buys is sentences, not words.** Nine props were already on disk. The
  three new combinators are ways to say more with those nine — a row of cracked
  pillars that detonates down the line, an arrow that catches fire on the way
  through a lantern, a lever that moves walls. `docs/PUZZLES.md` §8.1 prices each
  one and none of them needs a prop of its own. **The moment a combinator asks
  for an atom, it has stopped being a combinator**, and that is the ceiling this
  line is held to.
- **The deletion is real and it is phase 2.** The three uncommitted atoms —
  torch, timed bars, sounding set — were flavour, and two of the three are now
  strictly worse versions of something on the combinator list: a lantern that
  converts a shot *is* the torch, and chain under `time` *is* timed bars. If the
  count has to come back down, that is where it comes from, and nothing built
  moves.
- **Enemy behaviours is a new row on the manifest and it should be read
  narrowly.** It is not "enemies get more interesting" — it is *four keys that
  each name one of the six ring stops*, because `docs/BESTIARY.md` §0's diagnosis
  is that three of the four earned items have a room to open and no body to beat.
  The row is capped at 8, only 4 are committed, and **new monster models is still
  0** — which is the row that was actually at risk here and the one to check when
  the next encounter proposal arrives.
- **The pass that produced this line deleted nothing else and built nothing.**
  It is three documents. That is worth recording because the failure mode
  `CLAUDE.md` §0 names is two sessions building the same system twice, and a
  design pass that lands as docs on `main` is the cheapest possible defence
  against it.

### 4.3 Three questions before any new system

Ask all three. Any *no* kills it.

1. **Does it make "is what I am carrying worth the walk back?" harder to answer?**
   (GDD §2. A feature that makes the answer obvious deletes the game.)
2. **Is it a row in an existing catalogue, a rung on an existing ladder, or a
   number in `K`?** If it needs a new screen, a new autoload or a new save field,
   it is a system, and the systems budget is spent.
3. **Can one director prove it?** If you cannot describe the frames that show it
   working, you cannot tell when it is done, and a thing that cannot be done
   cannot be shipped.

### 4.4 One card, one worktree, land it

Unchanged from `CLAUDE.md` §1, restated because it is the process half of scope
control: a card on **[the board](https://github.com/orgs/Metatransformer/projects/8)**
before starting, `In progress` when you start, `Done` only when the director
passes, and **merge to `main` the moment it does.** A verified branch sitting in
a worktree is invisible work, and invisible work is how this repo built its
metagame twice.

**The board is also where scope gets caught.** §4.2's ledger only works if a
proposal is visible before it is built, and a card in `Backlog` is the cheapest
place to notice that something wants a tenth atom or a sixth counter. A card that
moves a number in §1 says so in its body.

---

## 5. What "published" means

The finish line, stated concretely so it can be reached rather than approached.

**The build:** Windows and macOS, Steam, single player, controller and
keyboard/mouse, English only. **No Linux, no Deck verification, no console, no
localisation** in this release — each is real work and none of them is the game.

**The store page needs, and this is the whole list:** capsule art, six
screenshots, a 60-second trailer, a description, a genre tag set, and a price.
Nothing on that list requires code, and **all of it can be built at M4** from the
demo. Do it at M4, not at M9, because a store page that exists early is a
deadline that pulls the rest of the plan forward.

**The demo is floor 1** — the Cistern, the Warden, the Bow, the vault, three
relics, and the garrison lighting three times. It ends on the boss door to the
Foundry. That is a complete arc, it is the M4 build with a wall at the end of
it, and it costs nothing extra to produce.

**Definition of shipped:** a stranger installs it, plays to the Lantern Ending
without reading anything you wrote, and the credits roll. That is the bar. Not
"content complete," not "all relics balanced" — *the credits roll for someone who
is not you*.

---

## 6. What will actually go wrong

Named in advance so that when it happens it is a known problem rather than a
surprise, and so nobody rebuilds the plan around it.

| Risk | Why it is likely | What to do |
|---|---|---|
| **Boss move sets balloon** | Four beats feel better than three, and phase two feels better than one phase. Then four bosses are sixteen behaviours. | Three beats, one phase, hard cap. A boss is a *readable* fight, not a long one. |
| **Burst drags in physics** | Thrown arcs invite rigid bodies, then bounce, then chain reactions, then destructible terrain. | It is a timed projectile with a fixed arc and a sphere query. It is not a physics feature. |
| **The workings breed** | Three spells is a *list*, and a list wants a fourth. Each new one is genuinely only a row, so each one is genuinely cheap, and that is the trap. | The ring stops row in §1 and CONTRACT §4.1. A seventh stop costs a sixth. Refuse at the row, not at the system. |
| **Repair prices become a grind gate** | A gold cost is the easiest dial in the game to turn, and turning it up "adds pressure" without anyone having to design anything. | GDD §6.4: the first is free, none exceeds one good run, and §6.3's *no relic gates the ending* is the acceptance test. If a repair is ever worth farming for, it is priced wrong. |
| **M6 gets special cases** | See §3. This is the big one. | Any floor 2–4 requirement that is not in a manifest goes back to M2/M4 as a pattern change, or it is cut. |
| **The relic unlocks get "designed"** | Twelve one-line changes are unsatisfying to write; each one wants to become a feature. | The table in GDD §6.2 is the spec. A relic that needs more than a line is the wrong relic. |
| **The gear loop eats the component economy** | 20 tracks draw on four components tuned for 5. The obvious fix — a fifth component, a new rarity band — is the wrong one and it will look right. | Tune **drops per run** and the recipes. §1's `Ingredients / components 10 / 8` does not move. If the ladders cannot be fed, shorten the ladders. |
| **Armour wants to become visible** | Four pieces with names is one step from four meshes, and it will be argued as "it's just a model swap". | §1: **armour / jewelry art 0**. It is four meshes × two paths × four rungs against a rig this project has fixed three times (`CLAUDE.md` §4). It is a sequel's. |
| **A sixth stat** | Every new track wants a number nothing else owns — crit, luck, poise, cast speed. | GDD §6.6: five stats, each one felt inside a run. A stat needing a tooltip is a stat that does not matter. |
| **Audio slips to never** | It is M8, it has no gameplay, and nothing fails without it. | It is a ship blocker. A silent action game reads as a prototype and no store page survives it. |
| **The endless mode absorbs the project** | It is already built, it is genuinely fun, and it has no bottom — so it can always be improved instead of finishing floors 2–4. | It is post-credits content. It gets the floor-10 relic and the plaque and **nothing else** until M9. |
| **Lore gravity** | `~/valenfeld` has 109 characters, 172 places, 59 factions and 90 quests, all good. | The game uses: the Society, the College, the Vyr, Valenfeld, the Sundering, and **Highbridge** as the reason the shaft is there. **Six** nouns — Highbridge was added 2026-08-09 when the hub became a garrison rather than the town itself (GDD §6), and it earns its place by explaining why the hub is four counters and a hole. It is the last one. Everything else is flavour text on a relic, at most. |

---

## 7. The one-paragraph version

Four floors, four bosses built from monsters already on disk, one new mechanic —
the working, a thrown arc and a fuse, carrying three spells on a six-stop weapon
ring — twelve hand-placed relics that come up broken, are repaired or read at
the counter whose thing they change, and each alter one line in the garrison, a
gear loop of twenty upgrade tracks across five counters moving five stats and no
sixth, eight locked doors following two rules, two endings, and the endless
dungeon that already works as the post-credits mode. The demo is floor 1 and it
exists at the halfway point. Everything not on that list is a sequel, and the
way we know we are still building this game and not another one is that the
numbers in §1 have not moved.
