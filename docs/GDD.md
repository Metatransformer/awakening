# The Lower Worlds: Awakening — Game Design Document

The north star. When a decision is contested, it is settled here; the other docs
describe *how* this gets built, not *what* it is.

**`docs/SCOPE.md` is this document's enforcement arm.** The GDD says what the
game is; SCOPE says how much of it there is and what gets refused. A feature
that is consistent with this document but absent from SCOPE's manifest is *still
out of scope*. Read them together or you will build a bigger game than the one
we agreed to ship.

**Status.** The moment-to-moment and the metagame are built and playable: town,
vendor, smith, alchemist, forge ladders, bag, extraction, Heat, bottles, bow,
hookshot, arrows, and a seeded dungeon with six enemy kinds. What is *not* built
is everything in §5, §6 and §7 — the spine, the gates, the relics, the endings.
`docs/METAGAME.md` is the design of record for what exists today and every number
in it is read from the code it names.

---

## 1. The pitch

A third-person action game with **Ocarina of Time's feel** and **Moonlighter's
structure**, played as an explorer in the Vale.

You are a member of the **Far Lantern Society**, and the Society's whole creed is
three clauses long: *go far, come home, tell true*. Under the frontier town of
**Valenfeld** there is a shaft into the works the **Vyr** built before they
withdrew to their sky-seat and left the world to fail without them. You make runs
into it. You take what the dead empire left. You decide, every time, when to
leave.

**You never see Valenfeld.** The hub you play in is the **Highbridge garrison**
— the walled camp the Highbridge people hold at the shaft head, a day's road from
the town proper. That is deliberate, and it is the reason the hub gets to be four
counters and a hole in the ground: a garrison is *supposed* to be small, purposeful
and short of comforts, so nobody has to explain why there is no inn, no square and
nobody to talk to who is not selling something. A town would have owed you those.
See §6.

The moment-to-moment is OOT: a boom camera, weighty camera-relative locomotion, a
committed roll, a shield, a telegraphed enemy you can read. The shape around it
is Moonlighter: a garrison, a counter, and a hole in the ground that gets worse
the further in you go.

**The one thing this game does that Moonlighter did not: the garrison changes.**

The shaft under Valenfeld is called **the Sunken Cut**. That is the name of the
*way down* — the one dungeon there is a way into — and the four authored floors
in §5 are the places it passes through: the Cistern, the Foundry, the Hushing
Choir, the Chord Gate. It is signed over the gate in town, said on the card the
game shows you on the way in, and said again in the corner of the screen every
time you take a stair. A place you are going back to a hundred times needs a name
for the same reason the run report is a receipt and not a score — "floor 7" is a
depth reading, and "the Sunken Cut, level 7" is somewhere you have been.

It lives in one constant, `Prog.NAME`, because there is one shaft (§5). **The
per-floor names in §5 are not wired up**: the card says THE SUNKEN CUT / LEVEL n
today, and the day the Cistern and the Foundry become real places rather than a
table in this document, `Prog` grows a name per level and the same two callers
draw it — the loading card and the HUD's floor card. Nothing else says the name,
by design.

---

## 2. The one question

> **Is what I am carrying worth more than the walk back?**

Every system exists to sharpen that question or to price it. When evaluating a
proposed feature, the test is not "is this fun in isolation" but **"does this
make that question harder to answer?"**

A feature that makes the answer obvious — infinite storage, a free teleport, a
heal you can carry without paying for it — is a feature that deletes the game.
Say no to it.

The question has **two axes**. *How deep* is the axis of space: the floors, the
fee, the walk back. *How fast* is the axis of time — Heat, the kill chain that
stamps a premium on loot swept while it is lit, pays in money and never in power,
and rides inside the bag so it raises the fee too. Going fast makes the walk home
more expensive. That is the one question asked a second way.

§3 adds the third and hardest form of it.

---

## 3. Why the player goes back down — three reasons, never the same reason

This is the design's spine, and it is the answer to "what actually makes the
dungeon addictive." Three things come out of the Descent, they satisfy three
different appetites, and **no one of them may ever be convertible into another**.

| | What it is | Renewable? | Appetite it feeds |
|---|---|---|---|
| **Gold** | Sold ingredients | Infinitely | *a number should go up* |
| **Components** | Forge and brew materials, chest-gated | Slowly | *the ladder should move* |
| **Relics** | Vyr salvage. **Twelve. Hand-placed. Unique.** | **Never** | *the world should change* |

Gold is the grind, and a grind is solvable by patience — which is why it can
never be the only reason. Components are the pacing gate: a Cold Iron Core never
falls off a body, so no amount of farming room one finishes a ladder.

**Relics are the hook.** Gold and components change your character sheet. A relic
changes *the place you come home to*. A player will grind a number for an hour
and a world for a hundred, and the specific failure this design is built to avoid
is Moonlighter's: a town that looked exactly the same on hour forty as on hour
one, so that late-game runs were payroll.

Every relic is a **named object with a named consequence**, and it is handed to a
person rather than sold (§6). Twelve of them. There is no thirteenth, there is no
generic relic, and there is no relic drop table. If it is not on the list in §6.2
it does not exist.

### The relic is also the sharpest form of §2

A relic sits **in the bag**. It costs a slot, it is charged the extraction fee,
and **it dies with the bag.** You are carrying the only one of these there is,
five rooms from the rope, with eleven slots of Deep Amber you would also like to
keep.

That is the hardest version of the one question the game can ask, and it is why
relics live in the bag rather than being granted on pickup.

**A relic lost on death goes back where it came from.** It is never destroyed —
it returns to the room it was placed in, and you can go down and get it again.
The sting is the walk, not the loss. A permanently missable unique in a game with
a death-loses-everything rule is not tension, it is a corrupt save.

---

## 4. Pillars

**1. The feel is not negotiable.** OOT is the bar for camera, locomotion, and
combat, and `refs/` is authoritative over intuition (`docs/CONTRACT.md` §2.5).
There is no walk/run toggle — speed is a curve. The roll is faster than the run
and it commits. A reversal past ~135° is its own move, not steering.

**2. Greed is the difficulty slider.** The game does not ask you to pick easy or
hard. It asks how deep you want to go, and pricing your own exit is how you
answer. A cautious player is never blocked; a greedy one is never safe.

**3. Loss is legible.** You always knew the risk. Enemies telegraph before they
commit. A full bag refuses visibly, with the mote left pulsing on the floor
rather than vanishing. The extract fee is on screen before you pay it. The
end-of-run receipt names every stack you lost, line by line.

**4. Permanence is bought or given, never found.** No dungeon drop makes you
stronger *by being picked up*. Ingredients are sold, gold buys upgrades,
components buy rungs, relics are donated — and every one of those transactions
happens **in town, over a counter, after you got home**. That indirection is what
makes a great run a *decision* rather than an automatic one, and it is the reason
death costs something without costing progress.

The boss items in §5 are the one deliberate exception, and they are an exception
about *verbs*, not about power: a bow you own is a thing you can now do, not a
number that went up. See §5.2.

**5. Light is a material.** Torches make warm pools, and the stone between them
is *dimmer*, not black — a lit place with shape, not a string of spotlights in a
void. The actors always carry enough light to be read: a silhouette you cannot
read is not atmosphere, it is a bug (and it was one, twice). Contrast is carried
by *range* and by *hue* — warm fire against cool air — never by an absence of
light. `docs/STYLEGUIDE.md` §1.

**6. One of each system.** One shop screen, one transition owner, one bag, one
receipt. A second is a second place for the arithmetic to drift. This repo has
paid for the alternative (`CLAUDE.md` §0) and will not pay again.

---

## 5. The Descent — four floors, four bosses, and an ending

**Superseding the endless-only structure.** The Descent is now **finite**: four
authored floors, each ending in a boss, and then the game *ends*. The endless
descent is not deleted — it becomes the post-credits mode (§8). A game with no
ending cannot be published, and the relic/town/fork design in §3 and §6 needs
authored space to live in.

| # | Floor | What it was | Boss | Model | Drops |
|---|---|---|---|---|---|
| 1 | **The Cistern** | Flooded Vyr intake works | The Cistern Warden | `golem` | **The Bow** + relic |
| 2 | **The Foundry** | Where the Imperium re-cut Vyr bronze | The Slag Ogre | `ogre` | **The Bomb Bag** + relic |
| 3 | **The Hushing Choir** | A resonance hall that still rings | The Bellwake | `wraith` | **The Hookshot** + relic |
| 4 | **The Chord Gate** | The threshold over Caer Vallen | The Riven Knight | `knight_iron` | **The Far Lantern** + relic |

**Every boss model already exists in `assets/monsters/`.** A boss is a scaled,
re-tinted existing monster with an authored three-beat move set and an arena —
not new art. This is the single largest scope saving available to the project and
it is free. See `docs/SCOPE.md` §1.

### 5.1 Authored anchors, procedural fill

Floors stay **seeded and generated** (`scripts/world/dungeon.gd`). Hand-authoring
four floors is weeks of work that also deletes the run-to-run variety the loop
depends on. Instead each floor gets a small **manifest** — room count, band
table, tint, and four guaranteed placements:

- the **boss door**, in the deepest room, where the stair is today;
- the **shortcut door**, near the entrance;
- the **vault door**, in the middle ring;
- the **deep chest**, beside the boss door, carrying that floor's relic.

Generated rooms, authored anchors. This is the standard fix for procedural
sameness and it costs one dictionary per floor.

**The boss door replaces the stair.** Behind the boss is the way down. So the
floor's deepest room is still where the best chest and the commitment are, and
`scripts/world/stairs.gd` keeps its job.

**A boss you have killed stays dead.** Its door hangs open and the arena is
empty forever after. The game never asks you to re-fight something you have
already beaten — this loop is about loot, not about repetition.

**You can leave before the boss.** The boss is a wall to *depth*, never a wall to
the loop. Walking into the Cistern, filling twelve slots, and roping out without
ever seeing the Warden is a complete, correct, profitable run.

### 5.2 The four items — verbs, not numbers

Boss items are the one thing the dungeon hands you directly, and the rule that
keeps pillar 4 intact is that **each one is a verb you did not have**. None of
them raises a stat. The stats are still the smith's.

- **The Bow** — for the thing that has not noticed you yet. Arrows, fletching and
  the `string` forge ladder already exist and simply become unreachable until the
  Warden is dead.
- **The Bomb Bag** — the only genuinely new mechanic in the plan. A thrown arc, a
  fused blast, and cracked walls. It is the game's one *destructive* answer and
  therefore the one that opens doors the others cannot.
- **The Hookshot** — crosses a gap, or brings the gap to you. Fired at a monster
  it does no damage; it freezes the thing for a second. An item that pulls you
  across a chasm and an item that buys you a beat are the same item, because both
  answer "I am not where I need to be yet."
- **The Far Lantern** — the Society's own. It is not a weapon and it has no
  button. It is the thing you were sent for, it ends Act I, and it opens the Long
  Descent (§8).

**The hero starts with the sword, the shield and the rope. Nothing else.** The
bow and the hookshot come out of the starting kit and become earned. Their forge
ladders do not appear at the smith until the item is owned. This converts systems
that are already built into progression, at the cost of one `Game.has()`
check, and it is what makes §5.3 mean anything.

### 5.3 The forks — two rules, eight doors

The fantasy is: *the dungeon reshapes itself around what you have proved you can
do.* The implementation is two sentences.

> **The shortcut on floor N is opened by floor N's own boss item, and skips
> floor N.**
>
> **The vault on floor N is opened by floor N+1's boss item, and holds a relic.**

That is all of it. Eight doors, one rule each.

**The shortcut says: prove you have done this, and never do it again.** Once the
Warden is dead you own the Bow, and a bow-locked door twenty metres from the
Cistern's entrance drops you at the Foundry's mouth. On your fifth run you are at
the Choir in ninety seconds.

**The vault says: come back with the thing from downstairs.** It is the classic
Zelda backtrack and it is what makes floor 1 worth re-entering on hour ten. Three
rooms, a harder pack than the floor around it, one relic, one rich chest.

Floor 4 has no vault — the boss room is the vault. Floor 4's shortcut is opened
by the Far Lantern and leads to the Long Descent.

**A fork is a door and a three-room prefab. It is not an alternate level.** The
moment a fork wants its own tint, its own roster or its own boss, it has stopped
being a fork and started being floor 5, and floor 5 is out of scope.

---

## 6. The garrison — twelve relics, twelve consequences

The Highbridge garrison is one walled yard over the mine mouth: curtain walls you
cannot see out of, open sky above them, and a rail round the shaft head. It gains
**one** counter and no new screens.

The walls are not scenery. Everything past them is placeholder ground that runs
flat to the horizon, and a visible empty world is worse than none — so the
boundary is load-bearing until there is something outside worth seeing. The sky
above it is equally load-bearing in the other direction: take that away and the
yard is a dungeon room whose ceiling failed to load, which is exactly what the
hub used to be.

**The Lanternkeeper** keeps the Far Lantern Society's hall against the east wall.
She does not buy and she does not sell: you hand her a relic and something in the
garrison changes. Mechanically she is a `Catalogue` subclass and a row in
`Npc.COUNTERS`, exactly like the smith and the alchemist, driven by the same
`TradeScreen` — a donation is a transaction whose price is one relic and zero
gold. There is no fourth screen.

The vendor buys, the smith forges, the alchemist brews, the Lanternkeeper
records. Four counters, and that is the garrison.

### 6.1 The rule that keeps this small

> **A relic unlocks a row in an existing catalogue, a rung on an existing ladder,
> or a number in `K`. It never adds a screen, a system, or a fifth NPC.**

Every entry below is a one-line change to something that already works. That is
not a coincidence, it is the acceptance criterion.

### 6.2 The twelve

| # | Relic | Where it is | What it does |
|---|---|---|---|
| 1 | Tally-Ledger of Fair Weights | Cistern deep chest | The smith **learns rung 2** on every forge ladder |
| 2 | Imperium Anvil-Plate | Warden (boss 1) | The smith **learns rung 3** on every forge ladder |
| 3 | Cracked Still-Head | Cistern vault | The alchemist **learns the Ironhide Draught** |
| 4 | Cinder-Retort | Foundry deep chest | The alchemist **learns the Emberblood Draught** |
| 5 | Glass-Kiln Core | Slag Ogre (boss 2) | The alchemist can **blow bottles 3 and 4** |
| 6 | Fletcher's Jig | Foundry vault | Fletching yields **7 arrows** instead of 5 |
| 7 | Pillar-Shard | Choir deep chest | **The square lights.** A lit market pays: vendor prices **+10%** |
| 8 | Sounding-Rod | Bellwake (boss 3) | The deep chest **hums** on arrival — the floor's only wayfinding |
| 9 | Warp-Stone Fragment | Choir vault | **Shortcuts work from town.** Start a run on any floor whose shortcut you have opened |
| 10 | Rope-Drum | Chord Gate deep chest | Extraction fee **25% → 20%** |
| 11 | Waterwheel Gear | Riven Knight (boss 4) | **The mill turns.** The smith's stock lines cost **−15%** |
| 12 | The Riven Chord | **Long Descent, floor 10** | The last one. See §8 |

Four from bosses, four from deep chests, three from vaults, one from the endless
mode. Eleven are reachable in Act I; the twelfth is the reason to keep going
after it.

**Each donation also lights one thing in the courtyard** — a lamp, the well, the
mill wheel, the College's window. Twelve dark props, twelve of them come on. The
town "thrives" at the cost of a prop swap and a light, and by relic twelve the
first frame of the game and the last frame of the game are visibly different
places. That contrast *is* the reward; do not spend more than a prop on it.

### 6.3 What the relics deliberately do not do

- **No relic sells.** The vendor refuses them, the way he already refuses
  components. A relic with a gold price is a relic the player will convert into
  the grind, and §3's whole point is that the three currencies do not touch.
- **No relic is a stat.** Look at the table: catalogues, recipes, prices, one
  wayfinding hum. The closest thing to power is the fee cut, and that is a
  discount on leaving, not a bigger sword.
- **No relic gates the ending.** You can kill the Riven Knight having donated
  none of them. The relics are the reason to keep playing, not a toll on the
  plot.

---

## 7. Difficulty comes from depth, not from you

**Bands, never level-scaling.** Rooms carry a distance from the entrance, and
that distance and the floor's own manifest choose what spawns. Skeletons and
goblins in the Cistern; kobolds and orcs in the Foundry; wraiths in the Choir;
trolls and iron knights at the Chord Gate.

Monsters get harder because *you walked further*, not because you got stronger.
Scaling the world to the player flattens the map into wallpaper, makes a tenth
run's entrance exactly as dangerous as a first run's, and quietly deletes the
reward for every upgrade you bought. Oblivion's own designer called it a mistake.
We are not repeating it.

The corollary: **the Cistern's mouth stays easy forever.** That is what makes a
short cautious run a real option instead of a wasted one.

The per-floor curve lives in one file, `scripts/core/progression.gd`, and nothing
else gets a curve of its own. It stops in exactly the places where continuing
would make the game unreadable: the telegraph never compresses past 60%, and a
room never holds more than seven.

---

## 8. The endgame

Two endings, both cheap, and neither one is a grind wall.

**The Lantern Ending** — kill the Riven Knight and take the Far Lantern. You come
home and tell true. Credits. This is the end of the game as advertised, it is
reachable in a single evening's play by a good player, and **it is the ending the
store page promises.**

It also unlocks **the Long Descent**: the endless generated dungeon that already
exists, entered from floor 4's shortcut door. Bands mix, the `Prog` curve runs
without a ceiling, and how deep you got is the score — carved on a plaque in the
square that names your record. The twelfth relic, **the Riven Chord**, is in a
chest on floor 10, which gives the mode a finish line for players who want one
and a scoreboard for players who don't.

**The Chord Ending** — donate all twelve relics and buy every ladder to rung 3.
The College fires the resonance-pillar, every lamp in Valenfeld comes on at once,
and the game ends a second time, properly. This is the completionist ending and
it is the only thing in the design that asks for all of anything.

That is the whole endgame. **There is no third ending, no New Game+, no
ascension, no prestige, no daily.** The honest answer to "what happens when you
have everything" is: the credits roll, the plaque has your name on it, and the
game is over. A game that refuses to end is a game that cannot be finished, and
this one ships.

---

## 9. What the player does with their hands

Camera-relative movement on the left stick. Both right shoulders are the sword —
RB the light chain, RT the heavy — and whatever you draw takes them over. LT is
the guard and the lock. The face buttons are one verb each: A talks, B dodges and
holds to run, X drinks the selected bottle, Y jumps. The D-pad steps rings rather
than holding bindings: ← → walk the right hand through the weapons you own, ↓
steps the bottle, ↑ swaps the whole loadout. Extraction is a **hold** — a
decision you can make by fumbling a button is not a decision.

The **air slam** is the one verb with no button of its own: either sword button,
pressed while airborne and unarmed, hangs the hero for a beat and drives him into
the floor. Jump is already the commitment — you are in the air with no way to
change your mind — and the slam only charges for what that commitment was already
costing.

Full input map and pad bindings: `docs/CONTRACT.md` §4.

---

## 10. Deliberately rejected

Each of these has a reason, and the reason is the point. `docs/SCOPE.md` §2 holds
the longer list and the rule for adding to it.

- **Level-scaled enemies** (§7).
- **A bag upgrade path that removes bag pressure entirely.** The cap is the game.
- **Consumable healing found underground.** Bottles are a stock you *bought* in
  town before you left. When the stock is gone, leaving is still the only answer.
- **A second scene-change path.** `Flow` owns transitions.
- **Hover boots.** They tax the authoring of every room in the game — a traversal
  item needs gaps to traverse, everywhere, forever — and they open no door the
  Bomb Bag cannot. The fantasy is real and it is a sequel's.
- **A map screen.** The floors are ten rooms and the Sounding-Rod is the answer
  to "where is the good chest." A map is a system that makes a small place feel
  like it needs one.
- **Relics as a drop table.** Twelve named objects in twelve named places. The
  moment a relic can *roll*, it stops being a thing you remember finding.
- **A thirteenth relic.**

---

## 11. How we know it works

Not by a test suite. By running it and looking:

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

`mvp_loop.gd` walks sell → buy → descend → fight → loot → chest → hold the pad →
home, prints what it observed at each seam, and says `MVP FAIL` when a beat did
not happen. `monster_lookdev.gd` does the same job for the roster. Every
milestone in `docs/SCOPE.md` §3 names the director that closes it.

See `CLAUDE.md` §2. The frames are the proof.
