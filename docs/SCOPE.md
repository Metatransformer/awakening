# SCOPE — the shipping contract

`docs/GDD.md` says what the game is. **This document says how much of it there
is, and it is the one that gets to say no.**

It exists because this project's failure mode is not "we cannot build it." Every
system in `docs/METAGAME.md` is built and works. The failure mode is that the
game is *interesting*, and an interesting game invites one more floor, one more
item, one more vendor, forever, until there is no version of it that is finished.

So: everything below is a **count**. Counts can be checked. "Is this scope creep"
is an argument; "is this number in the manifest" is not.

> **The test, for any proposal, in one line:**
> *Is it on the manifest in §1? If no, it is out — unless you are deleting
> something of equal size in the same breath (§4.2).*

---

## 1. The manifest

This table is frozen. **If a number in it goes up, that is scope creep, by
definition**, and §4.2 applies.

| | Count | Notes |
|---|---|---|
| Dungeon floors | **4** | + 1 endless mode, already built |
| Bosses | **4** | Warden, Slag Ogre, Bellwake, Riven Knight |
| **New monster models** | **0** | Bosses are scaled/re-tinted `golem`, `ogre`, `wraith`, `knight_iron` — all on disk |
| Enemy kinds in rotation | **9** | Everything in `assets/monsters/`. No tenth. |
| Dungeon kits | **1** | The P6 kit, four tints |
| Usable items | **4** | Bow (built), Hookshot (built), **Bomb Bag (new)**, Far Lantern (no verb) |
| **New mechanics** | **1** | The Bomb Bag. That is the entire mechanical invention budget. |
| Locked doors | **8** | 4 shortcuts, 3 vaults, 1 to the Long Descent |
| Vault prefabs | **3** | Three rooms each |
| Relics | **12** | Named, hand-placed, non-rolling |
| Town NPCs | **4** | Vendor, smith, alchemist, **Lanternkeeper (new)** |
| Town scenes | **1** | The courtyard. There is no second settlement. |
| **New UI screens** | **0** | The Lanternkeeper is a `Catalogue` on the existing `TradeScreen` |
| Endings | **2** | Lantern, Chord |
| Currencies | **1** | Gold. Components and relics are items, not money. |
| Ingredients / components | **10 / 8** | As built. No new rarity band. |
| Forge ladders | **5** | As built, ×4 rungs |
| Draughts | **3** | As built |
| Dialogue trees | **0** | NPCs have counters, not conversations |
| Quests | **0** | The relic list is the quest log |
| Voiced lines | **0** | |
| Cutscenes | **0** | Two ending sequences, in-engine, no camera authoring beyond a pan |

### What "new" actually costs, and why the zeroes matter

The three zeroes are the reason this plan is small enough to finish.

**Zero new monster models.** Ten `.glb` files are already imported, rigged
against the shared 81-clip `monster_library.res`, and proven by
`monster_lookdev.gd`. Four of them become bosses by scale, tint and an authored
move set. Commissioning or generating four boss models — and rigging them, and
fixing the facing bug that has bitten this project three times
(`CLAUDE.md` §4) — is weeks, and it buys silhouettes the player sees for four
minutes each.

**Zero new UI screens.** `TradeScreen` already drives two catalogues that behave
differently (gold-only rows, gold-and-materials rows, held confirms, affordability
colouring, refusal footers). A donation is a row whose price is one relic. The
Lanternkeeper is a subclass and a row in `Npc.COUNTERS` — the contract in
`docs/METAGAME.md` §6.6 says so explicitly: *"a third counter is a `Catalogue`
subclass and a row in `Npc.COUNTERS`, nothing else."*

**One new mechanic.** Bombs. Everything else in the plan is a *gate on*, a
*number in*, or an *arrangement of* something that already runs.

---

## 2. The no-list

These will be proposed. Several of them are good ideas. They are refused for
this release, with reasons, so that the refusal does not have to be re-argued
every time someone has the idea again.

**Refused because they are a different game:**

- Multiplayer or co-op of any kind.
- A second town, an overworld, a hub outside Valenfeld.
- Player-joinable factions. The Vale has fourteen of them in the lore. That is a
  reason to keep the lore, not a reason to build the game the lore implies.
- Character creation, races, classes, skill trees.
- Mounts, fishing, farming, housing, cooking.

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
- Healing items found underground (GDD §10).
- Fast travel that is not a shortcut door you unlocked.
- A save you can reload from mid-run (`docs/METAGAME.md` §5).
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

## 3. The build order

Each milestone is closed by **a director that runs, produces frames, and prints
no `FAIL`** — this repo's bar, not a checkbox (`CLAUDE.md` §2). One card per
milestone; land it on `main` when it closes.

**The order is not negotiable, and the reason is M4.**

| M | What | Closed by |
|---|---|---|
| **M0** | **The freeze.** Land this doc + the GDD. Annotate `METAGAME.md` where it is superseded. No code. | Docs merged to `main` |
| **M1** | **Gates and gear.** `Game.has_item()`. Sword + shield + rope at start; bow and hookshot removed from the starting kit; their forge ladders hidden at the smith until owned. Locked-door prop, keyed to an item id, with a refusal that names the item. | `gate_locks.gd` |
| **M2** | **One boss.** The Cistern Warden. Boss door replaces the deepest room's stair; arena; a three-beat telegraphed move set; the drop (Bow + relic); the door stays open and the arena stays empty forever after. | `boss_cistern.gd` |
| **M3** | **The relic and the hall.** `RelicDb` as a `Catalogue`; the Lanternkeeper NPC; donation on the existing `TradeScreen`; relics ride in the bag, are charged the fee, die with the bag and return to their room; the first three unlocks live; one town prop lights per donation. | `relic_donate.gd` |
| **M4** | **Floor 1, whole.** The Cistern's manifest: room count, band table, tint, boss door, shortcut door, vault door, deep chest. The vault prefab. **This is the demo.** | `cistern_floor.gd` |
| — | **🛑 THE GATE. Play M4 for an hour. See §4.1.** | A human, playing |
| **M5** | **Bombs.** Throw arc, fuse, blast, damage, cracked walls. The one new mechanic. | `bomb_throw.gd` |
| **M6** | **Floors 2–4 and bosses 2–4.** Repetition of M2 and M4 with the pattern proven. Three manifests, three move sets, two vault prefabs, six doors. **Invent nothing here.** | `foundry_floor.gd`, `choir_floor.gd`, `chord_floor.gd` |
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

### 4.1 The gate: M4 must be fun before M5 starts

At M4 the game is one floor, one boss, one item, one vault, three relics and a
town that visibly changed three times. **Play it for an hour. Then answer, in
writing, in the card:**

1. Did you want to go back down? *Why* — name the specific thing you wanted.
2. Did you ever leave with a relic and feel the walk? Did you ever lose one?
3. Did the town changing register at all, or did you have to be told?

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
control: `TaskCreate` before starting, `in_progress` when you start, `completed`
only when the director passes, and **merge to `main` the moment it does.** A
verified branch sitting in a worktree is invisible work, and invisible work is
how this repo built its metagame twice.

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
relics, and the town lighting three times. It ends on the boss door to the
Foundry. That is a complete arc, it is the M4 build with a wall at the end of it,
and it costs nothing extra to produce.

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
| **The Bomb Bag drags in physics** | Thrown arcs invite rigid bodies, then bounce, then chain reactions, then destructible terrain. | It is a timed projectile with a fixed arc and a sphere query. It is not a physics feature. |
| **M6 gets special cases** | See §3. This is the big one. | Any floor 2–4 requirement that is not in a manifest goes back to M2/M4 as a pattern change, or it is cut. |
| **The relic unlocks get "designed"** | Twelve one-line changes are unsatisfying to write; each one wants to become a feature. | The table in GDD §6.2 is the spec. A relic that needs more than a line is the wrong relic. |
| **Audio slips to never** | It is M8, it has no gameplay, and nothing fails without it. | It is a ship blocker. A silent action game reads as a prototype and no store page survives it. |
| **The endless mode absorbs the project** | It is already built, it is genuinely fun, and it has no bottom — so it can always be improved instead of finishing floors 2–4. | It is post-credits content. It gets the floor-10 relic and the plaque and **nothing else** until M9. |
| **Lore gravity** | `~/valenfeld` has 109 characters, 172 places, 59 factions and 90 quests, all good. | The game uses: the Society, the College, the Vyr, Valenfeld, and the Sundering as the reason the shaft is there. Five nouns. Everything else is flavour text on a relic, at most. |

---

## 7. The one-paragraph version

Four floors, four bosses built from monsters already on disk, one new mechanic
(bombs), twelve hand-placed relics that each change one line in the town, eight
locked doors following two rules, two endings, and the endless dungeon that
already works as the post-credits mode. The demo is floor 1 and it exists at the
halfway point. Everything not on that list is a sequel, and the way we know we
are still building this game and not another one is that the numbers in §1 have
not moved.
