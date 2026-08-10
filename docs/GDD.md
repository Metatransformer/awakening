# The Lower Worlds: Awakening — Game Design Document

The north star. When a decision is contested, it is settled here; the other docs
describe *how* this gets built, not *what* it is.

**`docs/SCOPE.md` is this document's enforcement arm.** The GDD says what the
game is; SCOPE says how much of it there is and what gets refused. A feature
that is consistent with this document but absent from SCOPE's manifest is *still
out of scope*. Read them together or you will build a bigger game than the one
we agreed to ship.

**Status.** The moment-to-moment and the metagame are built and playable: garrison,
vendor, smith, alchemist, forge ladders, bag, extraction, Heat, bottles, bow,
hookshot, arrows, and a seeded dungeon with six enemy kinds. What is *not* built
is everything in §5, §6 and §7 — the spine, the gates, the relics, the endings,
the three workings (§6.5) and the gear loop's expansion (§6.6).
`docs/METAGAME.md` is the design of record for what exists today and every number
in it is read from the code it names.

**Read §6.6 before §5 if you are here to build.** The gear loop — the ladders,
the armour paths, the jewelcrafter — is the reason the player descends, and it is
the half of this document with the most code already standing behind it. The
Descent is what the loop is *for*; the loop is what makes the Descent worth
repeating. A build that treats §5 as the game and §6.6 as shopping has the
weights backwards.

---

## 1. The pitch

A third-person action game with **Ocarina of Time's feel** and **Moonlighter's
structure**, played as an explorer in the Vale.

You are a member of the **Far Lantern Society**, and the Society's whole creed
is three clauses long: *go far, come home, tell true*. Under the frontier town
of **Valenfeld** there is a shaft into the works the **Vyr** built before they
withdrew to their sky-seat and left the world to fail without them. You make runs
into it. You take what the dead empire left. You decide, every time, when to
leave.

**You never see Valenfeld.** The hub you play in is the **Highbridge garrison**
— the walled camp the Highbridge people hold at the shaft head, a day's road
from the town proper. That is deliberate, and it is the reason the hub gets to
be four counters and a hole in the ground: a garrison is *supposed* to be small,
purposeful and short of comforts, so nobody has to explain why there is no inn,
no square and nobody to talk to who is not selling something. A town would have
owed you those. See §6.

The moment-to-moment is OOT: a boom camera, weighty camera-relative locomotion,
a committed roll, a shield, a telegraphed enemy you can read. The shape around
it is Moonlighter: a garrison, a counter, and a hole in the ground that gets
worse the further in you go.

**The one thing this game does that Moonlighter did not: the garrison changes.**

The shaft under Valenfeld is called **the Sunken Cut**. That is the name of the
*way down* — the one dungeon there is a way into — and the four authored floors
in §5 are the places it passes through: the Cistern, the Foundry, the Hushing
Choir, the Chord Gate. It is signed over the gate in the garrison, said on the
card the game shows you on the way in, and said again in the corner of the
screen every time you take a stair. A place you are going back to a hundred
times needs a name for the same reason the run report is a receipt and not a
score — "floor 7" is a depth reading, and "the Sunken Cut, level 7" is somewhere
you have been.

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

And it is **broken** (§6.4). It does nothing yet, it will cost gold at a counter
before it ever does, and it is still taking the slot and still paying the fee.
The hardest version of §2 is a decision about an object that is currently worth
less than the ore beside it.

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
happens **in the garrison, over a counter, after you got home**. That
indirection is what makes a great run a *decision* rather than an automatic one,
and it is the reason death costs something without costing progress.

**This pillar is the game's power curve, and §6.6 is how much of it there is.**
The counters are not a service on the side of the dungeon; climbing them is why
you go down. You delve to get rich and to find components, you spend both on
gear, and the gear is what lets you delve deeper. The dungeon supplies the
materials and the ladders supply the reason — neither half is the game on its
own.

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
ending cannot be published, and the relic/garrison/fork design in §3 and §6
needs authored space to live in.

| # | Floor | What it was | Boss | Model | Drops |
|---|---|---|---|---|---|
| 1 | **The Cistern** | Flooded Vyr intake works | The Cistern Warden | `golem` | **The Bow** + relic |
| 2 | **The Foundry** | Where the Imperium re-cut Vyr bronze | The Slag Ogre | `ogre` | **The Burst-Verse** + relic |
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
- **The Burst-Verse** — the only genuinely new mechanic in the plan. A thrown arc,
  a fused blast, and cracked walls. It is the game's one *destructive* answer and
  therefore the one that opens doors the others cannot. **It is cast, not
  thrown**: the Foundry is where the Imperium re-cut Vyr bronze, and what you take
  off the Slag Ogre is a written working rather than a satchel of powder. That is
  a change of noun and of particle colour — the arc, the fuse, the sphere query
  and the cracked walls are identical, and so is `docs/SCOPE.md`'s warning that
  none of it may become a physics feature.
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

**A working is a usable item and nothing more.** The Burst-Verse is a row in
`scripts/items/armament_db.gd`, it draws to the right hand, D-pad ← → reaches it,
RB and RT cast it, and the HUD cluster and the pouch's paper doll show it
because they already read `Game.armament()`. Its charges are the bow's arrows
with a different noun — a count in the HUD column, spent on cast, refilled only
in the garrison. There is no mana, no school, and no casting system:
`docs/CONTRACT.md` §4 already says *fire what is in the right hand*, and a
working is a thing that is in the right hand. The other two workings and the
rules that keep them from multiplying are §6.5.

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

The Highbridge garrison is one walled yard over the mine mouth: curtain walls
you cannot see out of, open sky above them, and a rail round the shaft head. It
gains
**one** counter and no new screens.

The walls are not scenery. Everything past them is placeholder ground that runs
flat to the horizon, and a visible empty world is worse than none — so the
boundary is load-bearing until there is something outside worth seeing. The sky
above it is equally load-bearing in the other direction: take that away and the
yard is a dungeon room whose ceiling failed to load, which is exactly what the
hub used to be.

**The Lanternkeeper** keeps the Far Lantern Society's hall against the east wall.
She does not buy and she does not sell: you hand her a relic and something in
the garrison changes. Mechanically she is a `Catalogue` subclass and a row in
`Npc.COUNTERS`, exactly like the smith and the alchemist, driven by the same
`TradeScreen` — a donation is a transaction whose price is **one relic and the
cost of making it work again** (§6.4). There is no fourth screen.

The vendor buys, the smith forges, the alchemist brews, the Lanternkeeper
records. Four counters, and that is the garrison.

### 6.1 The rule that keeps this small

> **A relic unlocks a row in an existing catalogue, a rung on an existing ladder,
> or a number in `K`. It never adds a screen, a system, or a fifth NPC.**

Every entry below is a one-line change to something that already works. That is
not a coincidence, it is the acceptance criterion.

### 6.2 The twelve

| # | Relic | Where it is | Home | What it does |
|---|---|---|---|---|
| 1 | Tally-Ledger of Fair Weights | Cistern deep chest | Smith | The smith **learns rung 2** on every forge ladder |
| 2 | Imperium Anvil-Plate | Warden (boss 1) | Smith | The smith **learns rung 3** on every forge ladder |
| 3 | Cracked Still-Head | Cistern vault | Alchemist | The alchemist **learns the Ironhide Draught** |
| 4 | Cinder-Retort | Foundry deep chest | Alchemist | The alchemist **learns the Emberblood Draught** |
| 5 | Glass-Kiln Core | Slag Ogre (boss 2) | Alchemist | The alchemist can **blow bottles 3 and 4** |
| 6 | **The Sustain-Verse** | Foundry vault | Alchemist | She **reads** it: you learn the working **Sustain** (§6.5) |
| 7 | **The Ballast-Verse** | Choir deep chest | Alchemist | She **reads** it: you learn the working **Ballast** (§6.5) |
| 8 | Sounding-Rod | Bellwake (boss 3) | Lanternkeeper | The deep chest **hums** on arrival — the floor's only wayfinding |
| 9 | Warp-Stone Fragment | Choir vault | Lanternkeeper | **Shortcuts work from the garrison.** Start a run on any floor whose shortcut you have opened |
| 10 | Rope-Drum | Chord Gate deep chest | Lanternkeeper | Extraction fee **25% → 20%** |
| 11 | Pillar-Shard | Riven Knight (boss 4) | Lanternkeeper | **The square lights.** A lit market pays: vendor prices **+10%** |
| 12 | The Riven Chord | **Long Descent, floor 10** | Lanternkeeper | The last one. See §8 |

Four from bosses, four from deep chests, three from vaults, one from the endless
mode. Eleven are reachable in Act I; the twelfth is the reason to keep going
after it.

**Two entries were deleted to pay for the two Verses** (`docs/SCOPE.md` §4.2):
*Fletcher's Jig* (fletching yields 7 arrows instead of 5) and *Waterwheel Gear*
(the smith's stock lines cost −15%). Both were numbers on a subsystem rather than
changes to the place you come home to, which is the §3 test a relic has to pass;
they were the only two on the table that failed it. **Pillar-Shard moved** from
the Choir's deep chest to the Riven Knight to fill the freed boss slot, and it is
better there — the square coming on is the largest visible change in the game and
it now lands on the last boss of Act I.

**The vendor is nobody's home counter.** He buys everything already, so he has
nothing a relic could unlock, and inventing one for the sake of symmetry is how
§6.1 gets broken.

**Each donation also lights one thing in the courtyard** — a lamp, the well, the
mill wheel, the College's window. Twelve dark props, twelve of them come on. The
garrison "thrives" at the cost of a prop swap and a light, and by relic twelve
the first frame of the game and the last frame of the game are visibly different
places. That contrast *is* the reward; do not spend more than a prop on it.

### 6.3 What the relics deliberately do not do

- **No relic sells.** The vendor refuses them, the way he already refuses
  components. A relic the player can turn into gold is a relic the player will
  convert into the grind, and §3's whole point is that the three currencies do
  not touch. **The repair price in §6.4 is not a violation of this** — it runs
  the other way. Gold buys a relic's *effect*, the way it already buys a forge
  rung; it can never buy the relic, and the relic can never become gold.
- **No relic is a stat.** Look at the table: catalogues, recipes, prices, two
  workings, one wayfinding hum. The closest thing to power is the fee cut, and
  that is a discount on leaving, not a bigger sword. The two Verses are the §5.2
  rule applied to relics — **a verb you did not have, never a number that went
  up.** Sustain and Ballast do not raise anything; they are two more things you
  can decide to do, and both of them cost you something you were carrying.
- **No relic gates the ending.** You can kill the Riven Knight having donated
  none of them. The relics are the reason to keep playing, not a toll on the
  plot.

### 6.4 Broken on arrival — the home counter

**A relic you find does not work.** It comes up out of the Cut as
`BROKEN TALLY-LEDGER`, its description reads *Take it to the smith*, and it does
nothing at all until you have carried it home, walked it to the right counter and
paid to have it repaired — or, for a Verse, **read**. The Home column above is
that counter, and the rule that generates it needs no table of its own:

> **A relic's home is the counter whose thing it changes.**

This is not an extra system bolted onto the donation; it is the donation losing
its special case. Pillar 4 says permanence is *bought or given, in the garrison,
over a counter, after you got home*, and a relic that worked the moment you
touched it was the one thing in the design quietly breaking that. Now the
Lanternkeeper prices a repair the way the smith prices a rung, and all four
counters are the same transaction.

It also sharpens §2 one more turn. A broken relic is worth **nothing** until you
pay for it, and it still costs a bag slot and still pays the fee on the way out.
You are carrying twelve slots of Deep Amber and one object that is currently
worth less than the Amber, five rooms from the rope.

**The prices are small and they are not a gate.**

- **The first repair is free.** The Tally-Ledger is the game teaching you what
  the counter does, and a tutorial you cannot afford is not a tutorial.
- The rest scale with the floor the relic came from, and **none of them is more
  than one good run's takings.** A repair is a ritual and a delay, never a grind.
  §6.3 still holds: no relic gates the ending.
- The numbers live in `scripts/items/relic_db.gd` beside the rows they price, not
  in this document, for the reason `docs/METAGAME.md` opens with — a doc that
  restates a number is a doc that will disagree with the code.

**The wall in the hall is the quest log.** The Lanternkeeper's board shows all
twelve slots: empty, broken, or lit. That is where "what is still out there" is
answered, it is why `docs/SCOPE.md` can keep Quests at 0, and it is a
`Catalogue`'s existing row list rather than a screen.

### 6.5 The workings — charges, not mana

Three workings, and the number three is load-bearing.

| Working | From | Charges | What it does |
|---|---|---|---|
| **Burst** | The Slag Ogre (§5.2) | Bought | The thrown arc, the fuse, the cracked wall |
| **Sustain** | The Sustain-Verse, read | Bought | The Heat chain holds through **one** break (§2) |
| **Ballast** | The Ballast-Verse, read | Bought | Burn the cheapest stack in the bag for a soak window |

**They are usable items.** Each is a stop on the right-hand ring, cast with RB or
RT like the bow, selected with D-pad ← →. Nothing about the input layer changes.

**Charges are arrows.** You buy them from the alchemist — she is already *the
only thing you take down with you* (`docs/METAGAME.md` §6.6), and a charge is a
stock you paid for in the garrison before you left, exactly like a bottle.
**They do not refill underground.** There is no rest, there cannot be one (the
run is not savable, `docs/METAGAME.md` §5), and a resource that comes back
mid-run softens the walk home. Spending your last charge on floor 2 is a
statement about how deep you were planning to go.

**Charges live in the HUD column with arrows and stamina, never in the bag.** The
bag is the pressure valve and it does not get taxed twice.

**Sustain and Ballast both sharpen §2 rather than softening it.** Sustain makes
speed cheaper *and* raises the fee, because Heat rides in the bag — the one
question asked twice in one button. Ballast is the sharpest form of it in the
game: the thing you came down for is the thing that keeps you alive, and casting
it is eating your own profit.

**The ceiling is the ring, not the manifest.** Sword, bow, hookshot, Burst,
Sustain, Ballast is **six stops**, and `docs/CONTRACT.md` §4.1 chose rings over
bindable slots on the grounds that a ring you can *count* beats a binding you
have to remember. Six is where counting stops being free. **There is no fourth
working**, and the reason is a thumb rather than a budget.

---

### 6.6 The gear loop — what the gold and the components are for

Pillar 4 says permanence is bought. This is the shop.

**Five stats, and there is no sixth.** Damage, speed, max health, stamina, soak.
Every one of them is a number the player can feel inside one run, which is the
rule `scripts/core/consts.gd` already states over the forge ladders: *no
percentages, no stat sticks, nothing you have to take on faith*. A stat that
needs a tooltip explaining why it matters is a stat that does not matter.

They are listed on the equipment screen, beside the paper doll that already
draws what you are holding — a THE HERO card of exactly five rows, every one of
them read back through a `Game` accessor and **never recomputed in the panel**.
A panel that does its own arithmetic is a second source of truth, and it drifts
the first time a ladder changes.

**And the doll is the whole build, not just the hands.** The WORN column on that
screen is the figure with all eight slots hung off it — the four plate pieces
down the left, her four stones down the right, each plate saying which path it
committed to and how many of its rungs are bought, each wired by a leader line
to the part of the body it is worn on. It is the only place in the game the
eight appear together: the smith knows about plate and she knows about stones,
and neither counter can answer *what am I wearing, all of it, at once.*
Read-only, because there is nothing to set — a piece of plate is a ladder you
climbed and it does not come off.

> **Built, 2026-08-09.** Everything in §6.6 is in the code and asserted by
> `tools/directors/forge_loop.gd` and `tools/directors/jewel_loop.gd`. The
> numbers below are the shipped ones, not targets. `docs/METAGAME.md` §6.5 and
> §6.7 carry the tables and the recipes.

#### The armour — four pieces, two paths

`plate` was one ladder. It is now **four**: chest, legs, arms, boots. There is
no modular armour art and there is not going to be — the hero's model is the
hero's model, and every one of these is a number (`Game.armour_soak()` is
already exactly that today).

Every rung is a **choice of two**:

> **Heavy** buys more soak and costs a little speed. **Light** buys less soak,
> costs no speed, and is cheaper in components.

That is the whole fork, and it is a real decision because speed in this game is
not a convenience — the roll is the defence (`docs/CONTRACT.md` §4), and a hero
who rolls slower dies to things he used to beat. Four pieces means you are not
picking *one* answer, you are picking a mix: heavy chest and light boots is a
build, and so is the opposite.

**A piece commits.** Once a piece has taken a rung on one path, the other path is
closed for that piece — you cannot buy three heavy rungs and then re-spec light.
Implementation: the two paths are two track ids and the sibling's ceiling drops
to zero, so `Game.upgrades` stays `{track: int}` and nothing new is stored.

**The speed cost never touches `K.RUN_SPEED`.** That constant is `[oot]`,
measured, and pillar 1 says the feel is not negotiable. The penalty is a
multiplier applied on top of the curve, and **all four pieces at full heavy caps
at −8%** — enough to feel in a corridor, not enough to stop being Ocarina.

**Rung 0 is the piece you start in, and there are three to buy** — `K.FORGE_MAX`,
same as every other ladder, so the split changes the table's width and not its
height.

**The constraint that matters more than any starting value: the four pieces
*together* must land about where the one `plate` ladder landed.** `K.PLATE_SOAK`
is `[0, 1, 2, 3]` today — a maximum of three quarter-hearts off a blow — and
every enemy in the game is tuned against that ceiling. Four pieces each running
0→3 would be **twelve**, which is not four times better armour, it is the floor
in `Hero.hurt` (never lighter than one quarter) absorbing the whole difficulty
curve. Every hit in the game would land for one quarter and §7's *difficulty
comes from depth* would be dead.

So: **full heavy across all four pieces totals exactly 4, and full light exactly
2.** The per-piece tables are fractional for that reason — heavy runs
`0 / 0.4 / 0.7 / 1.0` quarters and light `0 / 0.2 / 0.35 / 0.5` — and nothing
carried over from `PLATE_SOAK`, which was written for one piece. `forge_loop`
beats P1 and P3 print the sums every run.

The speed multiplier is the safer half: per-piece heavy rungs multiply, and four
pieces at heavy rung 3 come to **exactly 0.92** because `PLATE_HEAVY_SPEED` is
`0.92^(k/12)`. Multiplication rather than a special case that watches for the
fourth piece.

#### The jewelcrafter — four slots, eight specializations

A fifth counter, and the only new NPC this game gets. She is a `Catalogue`
subclass and a row in `Npc.COUNTERS`, on the same `TradeScreen` as the other
four (`docs/SCOPE.md` §1 keeps **new UI screens at 0**, and this does not break
it).

Four slots: **an amulet, two rings, and a bracelet.** Each is bought as a plain
base, then specialized once, then climbed **four rungs** — one deeper than a
forge ladder, because a jewel has no rung 0 you already own.

The same soak warning applies to **Ward** and the same speed warning to
**Swift**: a jewel path and an armour path that both move the same stat are two
faucets on one number, and the ceiling is the number's, not each faucet's. In
code that is `K.SOAK_MAX`, `K.EDGE_MAX`, `K.STAMINA_MAX`, and the 1.0 clamp
inside `Game.speed_mult()` — never a cap per ladder. `jewel_loop` beats F0–F4
open both faucets on each and assert the cap holds.

Her rungs are **not** rationed by `RelicDb.forge_rungs_known()`. Relics ration
the smith; one relic drop must not control two counters.

| Slot | Path A | Path B |
|---|---|---|
| Amulet | **Vigor** — max health | **Focus** — max stamina |
| Ring (×2, same pair) | **Edge** — damage | **Swift** — speed |
| Bracelet | **Ward** — soak | **Wind** — stamina regen |

The two rings draw on the same pair on purpose: two Edge rings and one of each
are different builds, and that is where the variety comes from without a ninth
path existing.

**Jewelry is where speed is bought back.** Armour trades speed for soak; a Swift
ring trades a damage slot for it. That is the loop's one genuinely hard standing
question, and it is the same shape as §2's — *what are you willing to carry?*

#### What this loop deliberately does not become

- **No relic is a stat** (§6.3). Relics change the garrison; the ladders change you.
  The moment a relic grants soak, the twelve stop being the reason to keep
  playing and become twelve more rungs.
- **No re-spec, no refund.** A path you committed is a path you committed. A
  build you can undo for gold is not a build, it is a menu.
- **No sixth stat, no ninth path, no second jewelcrafter.** `docs/SCOPE.md` §1
  carries all three as counts.
- **No armour visuals.** Every piece is a number. Modular armour art is four
  meshes times two paths times four rungs, against a hero rig this project has
  already had to fix three times (`CLAUDE.md` §4).

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
  garrison before you left. When the stock is gone, leaving is still the only answer.
- **A second scene-change path.** `Flow` owns transitions.
- **Hover boots.** They tax the authoring of every room in the game — a traversal
  item needs gaps to traverse, everywhere, forever — and they open no door the
  Burst-Verse cannot. The fantasy is real and it is a sequel's.
- **A spell school, a mana bar, or a fourth working.** Magic in this game is
  three usable items with charges (§6.5). The moment it has a resource of its
  own it wants ranks, then schools, then a class — and `docs/SCOPE.md` §2 has
  already refused classes. The cap is the ring: six stops, `docs/CONTRACT.md`
  §4.1.
- **A relic that works when you pick it up.** §6.4. It was the one thing in the
  design breaking pillar 4.
- **A map screen.** The floors are ten rooms and the Sounding-Rod is the answer
  to "where is the good chest." A map is a system that makes a small place feel
  like it needs one.
- **Relics as a drop table.** Twelve named objects in twelve named places. The
  moment a relic can *roll*, it stops being a thing you remember finding.
- **A thirteenth relic.**
- **A sixth stat, a ninth upgrade path, a re-spec, and armour you can see.** All
  four are §6.6, which holds the reasons. The short forms: a stat that needs a
  tooltip does not matter; a build you can undo for gold is a menu; and modular
  armour art is four meshes × two paths × four rungs against a rig this project
  has already had to fix three times.

---

## 11. How we know it works

Not by a test suite. By running it and looking:

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

`mvp_loop.gd` walks sell → buy → descend → fight → loot → chest → hold the pad →
home, prints what it observed at each seam, and says `MVP FAIL` when a beat did
not happen. `monster_lookdev.gd` does the same job for the roster. Every
milestone in `docs/SCOPE.md` §3 names the director that closes it.

See `CLAUDE.md` §2. The frames are the proof.
