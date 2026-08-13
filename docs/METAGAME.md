# The metagame

This document owns the current descent, reward, economy, extraction, and
garrison-service rules. It describes the player-facing contract, not the
history of how the contract was reached.

- [ITEMS.md](ITEMS.md) owns item identities, catalogues, and item-specific
  exceptions.
- [FIELD_NOTES.md](FIELD_NOTES.md) owns the five first-time observations, note
  economy and three doctrine definitions.
- [GARRISON_LIFE.md](GARRISON_LIFE.md) owns the civil rhythm, Firewood/Hearth,
  residents, and the bounded raid.
- [SCOPE.md](SCOPE.md) owns content ceilings and the production freeze.
- [CONTRACT.md](CONTRACT.md) owns implementation units, interfaces, input, and
  measured build rules.

## 1. Descent and home

The Sunken Cut is where the player risks temporary value. Highbridge garrison
is where recovered value becomes supplies, services, equipment, and visible
permanence.

A **trip** begins when the player crosses the Cut threshold. Taking a stair to
another floor in either direction continues the same trip: health, bag
contents, document-case contents, Heat premium, ammunition, bottle contents,
magic, and the extraction price all carry forward. Changing floors does not
bank loot, heal the player, or refill a resource.

The garrison is the preparation boundary. Bottles are brewed there, arrows and
charges are bought or made there, and the full magic allowance is restored
between trips. Stamina is different: it regenerates during play and prices the
next action rather than the next room.

The recurring decision is:

> Is what I am carrying worth more than the cost and danger of continuing?

The game keeps both answers viable. Going deeper offers richer possibilities;
ordinary extraction always remains available at a known price.

## 2. Value and loss lanes

There are two non-convertible currencies: **gold** and **Field Notes**. Reward
types do not convert into one another automatically.

| Lane | During a trip | On extraction | On death |
|---|---|---|---|
| Gold | Coins bank directly and use no bag slot | Kept, minus the extraction charge | Kept |
| Field Notes | First-time observation ids are pending run knowledge, not carried loot | New ids award permanent notes at debrief | New ids award permanent notes at debrief |
| Bag | Holds sale goods, components, relics, and temporary finds | Banked by item kind | Exposed contents are lost |
| Document case | Five secure cells within the bag limit | Banked with the rest | Banked; no extraction fee is charged |
| Components | Occupy bag cells until brought home | Move to their named workbench | Lost unless packed in the case |
| Relics | Unique, unsellable, and always exposed | Become available for their home transaction | Return to their authored recovery location |
| Permanent progress | Lives at home | Kept | Kept |

Coins from pots go directly to gold. Pot gems are ordinary sale goods and stay
at risk in the bag. The distinction is visible: safe currency never consumes
space; merchandise does.

Relics and run-only Echoes cannot enter the document case. The case protects
ordinary stacks and components, not the run's strongest risk objects. Item-level
rules belong to [ITEMS.md](ITEMS.md), and Echo placement and effects belong to
[PUZZLES.md](PUZZLES.md).

## 3. Bag pressure

The starting bag has **17 cells**. The document case uses five of those cells,
leaving **12 exposed hold cells** by default; it does not add capacity. Four
purchasable upgrades raise the hard maximum to **21 cells**.

Each item defines its own stack limit. A stack that exceeds its limit consumes
another cell. Common ingredients stack deeply, while rarer finds generally
stack less deeply, so higher unit value does not erase the capacity decision.
The exact catalogue and stack sizes are in [ITEMS.md](ITEMS.md).

When a pickup cannot fit, it remains on the floor and pulses. Nothing is
silently deleted. The player may leave it, spend something, or return after
making room where the item permits that choice.

Selecting an occupied Inventory cell and choosing **Drop** throws that one
displayed stack onto the floor in front of the hero as an ordinary pickup. A
stack dropped from the document case loses its protection. Dropping and
recollecting preserves its value and Heat premium rather than minting more.

The HUD groups carried value into three thresholds:

| Tier | Bag value | Meaning |
|---|---:|---|
| T1 | **250** | A meaningful shallow-floor haul |
| T2 | **1,000** | A run worth actively protecting |
| T3 | **2,000** | Deep value the player can ill afford to lose |

These tiers communicate risk; they do not add power. Bag value includes any
banked Heat premium and is also the value used by extraction.

## 4. What recovered things are for

### Ingredients

The ten ingredients are saleable merchandise. They occupy bag cells, can be
lost, and become gold only when sold at the quartermaster. Selling is a choice:
some common ingredients can instead be consumed by a named supply recipe such
as fletching. Iron Scrap retains that ordinary sale-good lane, but Brannoc's
three utility-tool recipes may consume it directly from the returned bag; this
is the explicit reason not to sell every unmarked stack automatically.

### Components

Components are crafting materials, not currency. They share the bag and loss
rules with ingredients, but the quartermaster does not buy them. Extraction or
a protected document-case return moves each component to its named bench.

Forge, alchemy, and jewellery components remain separate recipe families. A
component has one bench and does not appear in another counter's recipes. Exact
component identities, stack sizes, and catalogue roles belong to
[ITEMS.md](ITEMS.md).

Riveted Plate feeds Brannoc's forge and, together with Tension Coil, the
Builder's already-authored West Gate Bolt-Thrower. Those shared metal demands
create allocation; mining does not create a new material family or currency.

### Durable utility tools and mining

Brannoc's utility-tool transactions are fixed:

| Tool | Full durability | First forge or full reforge |
|---|---:|---|
| Woodsman's Axe | **8 uses** | **60 gold + 3 Iron Scrap** |
| Pickaxe | **12 uses** | **75 gold + 3 Iron Scrap** |
| Fishing Rod | **10 uses** | **45 gold + 1 Iron Scrap + 1 stored Firewood bundle** |

A reforge is the same full bill and restores the maximum; there is no prorated
repair. A known zero-use tool remains **BROKEN** and eligible for reforge.
Positive durability mirrors into ordinary item ownership only for compatibility,
and utility tools never become carried stock, bag value, sale goods, armaments,
or combat equipment.

The three durability spends occur only at the work's commitment point: a
successful daily tree impact for the Axe, every resolved success or failure for
the Rod with no spend on cancel, and a committed intact-vein impact for the
Pickaxe. The Rod's Firewood is removed from the stored hearth, so the player
must complete the ordinary daily grove-to-hearth loop before forging or
reforging it.

Every ordinary non-entrance, non-maze room independently has a deterministic
**65%** vein chance. Mining pays one physical existing-item stack:

| Payout | Chance within a placed vein | Yield |
|---|---:|---:|
| Iron Scrap | **65%** | **3** |
| Riveted Plate | **22%** | **2** |
| Tension Coil | **13%** | **1** |

Enemy Iron Scrap drops remain unchanged and are the less-efficient fallback.
A vein becomes rubble and throws a physical LootMote stack, so bag room, case
protection, extraction, and loss stay ordinary decisions. Stable floor/cell
depletion survives room and floor rebuilds and resumable Run v3 saves, then
clears on a new run. Mining adds no map marker, gate, room, currency, item id,
or automatic banking.

The resulting chain is deliberate: choose incidental enemy iron or Pickaxe
durability for efficient mining; allocate metals between tool forging,
Brannoc's forge, and Bolt-Thrower construction; chop and deposit wood before a
Rod transaction; and decide when a worn tool warrants a full-cost reforge.

### Relics and the Artifacts service

Relics are named, unique artifacts rather than random drops. They occupy one
exposed bag cell, never sell, and are charged for during ordinary extraction.
At home they are repaired or read through the Lanternkeeper's **Artifacts**
service, then donated to produce their existing consequence and light their
physical display.

A relic changes an existing catalogue, ladder, number, verb, or wayfinding
rule. It does not create an independent economy. The twelve-item catalogue and
each consequence are owned by [ITEMS.md](ITEMS.md); the total is capped by
[SCOPE.md](SCOPE.md).

### Field Notes and doctrines

Field Notes are a permanent, finite learning currency awarded only when an
extraction or death debrief resolves a newly observed Cistern event. The
receipt pairs every new note with the event that produced it. The note balance,
awarded observation ids and bought doctrine ranks persist through save/load and
death. Unobserved entries stay hidden, and repetition awards nothing.

Aldric's **Field Notes** service reuses the existing catalogue and trade
presentation. Exactly three one-rank doctrines cost two notes each:

- **Rope Drill:** shortens the extraction world channel from **1.2 seconds to
  1.0 second**.
- **Measured Breath:** increases stamina regeneration by **5%**.
- **Sweep Pattern:** adds **0.5 m** to the Heat pickup magnet at Warm or above.

Five fixed observations yield five total notes, so at most two doctrines can be
bought and one permanently remains unchosen. There is no repeatable faucet,
conversion, checklist, item, refund, respec or separate UI screen. Exact
observation and doctrine tables, stable ids and transaction rules belong only
to [FIELD_NOTES.md](FIELD_NOTES.md).

## 5. Heat

Heat prices tempo. Kills extend a chain; the chain window shrinks as it rises;
a landed blow or an expired window steps the chain down one tier. A blocked
blow does not break Heat.

| Tier | Kills | Window | Loot multiplier | Pickup magnet |
|---|---:|---:|---:|---:|
| Cold | 0 | — | x1.00 | — |
| Warm | 2 | **4.0 s** | x1.25 | **2.5 m** |
| Hot | 5 | **3.2 s** | x1.60 | **3.5 m** |
| Blazing | 9 | **2.5 s** | x2.20 | **4.5 m** |

A kill refunds **40 stamina**, enough to fund the **34-stamina** dodge that can
reach the next target. The active magnet pulls nearby loot toward the player so
collection can remain part of the chain.

Heat pays value, never combat strength. Loot records the multiplier when it
drops, then cools toward base value over **6 seconds**. Collected bonus value is
stored as one premium in the bag rather than as duplicate item stacks. Selling
a line pays its proportional premium, and the extraction fee includes it.

## 6. Arrows, charges, rations, and draughts

These are preparation resources, not merchandise. They do not add bag value or
Heat premium.

### Arrows

Arrows live outside the bag, survive death, and have three supply routes:

| Source | Amount | Cost or placement |
|---|---:|---|
| Quartermaster | 10 | **40 gold**; requires the bow |
| Dungeon floor bundle | 6 | A **25%** per-room placement chance |
| Chest bundle | 10 | A **40%** per-chest chance |
| Pot bundle | 3 | A small ambient supply |
| Fletching | 5 | **2 Cracked Flint + 2 Bone Shard** at Brannoc |

Found arrows do not occupy a bag cell. A bundle refused by a full quiver stays
on the floor. Fletching consumes saleable ingredients and frees their bag space;
its ingredient value is deliberately above the quartermaster's per-arrow price.

### Burst charges

The quartermaster sells **3 charges for 90 gold** after Burst is owned. A
required Burst route supplies its authored charge cache, and ambient pots may
rarely provide one. There is no general underground refill that replaces
preparation.

### Rations

| Ration | Trade bundle | Effect | Carry cap |
|---|---:|---|---:|
| Hardtack | 5 for **25 gold** | Restores **4 HP** over 12 seconds | 20 |
| Small Beer | 5 for **45 gold** | Restores **12 magic**, exactly one spin, over 12 seconds | 20 |

Eating roots the player in a seated channel with four ticks, one every three
seconds. Movement, combat, interaction, opening a screen, or taking a hit ends
the meal. The ration is spent when the player sits, so interruption never
refunds the unused portion.

The magic bar holds **48 magic** and a charged spin costs **12**. Small Beer is
the one carried partial refill; no font, ordinary pickup, or draught restores
magic.

### Bottles and draughts

The player starts with **1 bottle** and can reach a hard maximum of **4**.
Bottles and their contents persist until used; descending does not refill them.

| Draught | Gold | Materials | Effect |
|---|---:|---|---|
| Health Draught | 55 | 3 Bitter Root | Restore **8 HP** immediately |
| Ironhide | 85 | 2 Ash Resin + 2 Bitter Root | Reduce each blow by **2 HP** for **45 s** |
| Emberblood | 95 | 3 Ash Resin | Add **2 HP** per swing for **45 s** |

The three added bottles cost gold on a **110 x 2.4** ladder and require,
respectively, **4 Fired Cullet**; **8 Cullet + 2 Resin**; and
**14 Cullet + 1 Mourning Dew**. Timed draught effects do not survive saving and
loading.

## 7. Ordinary extraction and death

The **Escape Rope** is the portable way to reach the ordinary extraction
settlement. It is a permanent key item on the Inventory screen, not consumable,
and not placed on a combat ring. Walking back to the **floor 1 up stair** reaches
the same settlement, pays the same charge, and produces the same receipt.

An up stair on a deeper floor returns to the preceding seeded floor beside its
canonical down stair. It does not extract, bank, heal, or reset the trip.

Leaving has two deliberate commitments:

1. Hold **Y / `ui_hold` for 0.9 seconds** on the Inventory screen.
2. After the menu closes, remain rooted through a **1.2-second** world channel,
   reduced to **1.0 second** by Rope Drill.

A landed blow breaks the world channel. A blocked blow does not. The channel
makes safety matter; the menu hold prevents an accidental run-ending press.

The ordinary extraction price, whether reached by rope or the floor 1 stair,
is:

```text
toll   = max(15, round(bag_value x 0.25))
charge = min(toll, current_gold)
```

The rope always works. If the calculated toll exceeds the purse, extraction
takes all current gold and still brings the haul home. Extraction banks the
whole bag by item kind and preserves current health. Rest and sleep are the
normal garrison recovery seam: every completed sleep restores real health to
maximum, and purchased bed ranks grant 1 temporary HP each on top.

Death loses the exposed bag, banks the document case, preserves gold and
permanent progression, and returns the player to the garrison at full health.
Unique lost relics return to their authored recovery locations.

The bounded raid interaction is owned only by
[GARRISON_LIFE.md](GARRISON_LIFE.md) and
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md). It does not
change the ordinary Escape Rope, its cost, its channel, or either run outcome.

## 8. Receipts and saves

Extraction and death use the same run-end receipt over the floor where the run
ended. It reports the floor, killer where applicable, kills, carried stacks,
and line values. Components are marked for their bench. Death separates what
the floor kept from what the document case brought home. The game remains
paused until the player chooses **Back to the Garrison**.

Autosave occurs on every scene transition and after each five minutes of
active, unpaused play while the player exists. Entering the Cut, descending,
ordinary extraction, and death therefore all protect the resulting current
state. The HUD reports **AUTOSAVING...** as the destination fades in.

A save may continue an active descent. It records the current run seed, floor
and depth, bag and case, counters, visited rooms, player position, magic, and
stamina, then rebuilds the generated floor deterministically on load. Loading
does not refill the trip or create a checkpoint history.

Each save slot contains one current state. Autosave uses the active slot, then
the first empty slot, and never overwrites another occupied slot on the
player's behalf. **Continue** shows the three readable slots ordered by most
recent play. The bed invokes the same autosave policy as a deliberate manual
rest affordance.

## 9. Four floors and the Long Descent

The main expedition is finite: **four authored floors and four bosses** over
the shared generated-dungeon grammar. Each floor has fixed authored anchors,
and its critical-path puzzle awards one floor-scoped Boss Key in a different
room from its oversized Boss Door. That door opens into a separate boss chamber;
defeating the boss reveals the chamber's deep chest and down stair. Up and down
stairs preserve the trip and revisit the same seeded floors, while boss death
permanently preserves the cleared chamber and its available descent.

After the credits, the existing endless mode remains as the **Long Descent**.
It continues the same carry, risk, extraction, and progression rules rather
than becoming a second economy. Content quantities and the four-floor ceiling
belong to [SCOPE.md](SCOPE.md); dungeon and puzzle structure belongs to
[PUZZLES.md](PUZZLES.md).

## 10. Garrison services

Highbridge is a place the player walks through, not a remote menu. The current
resident rhythm, Firewood/Hearth, and arrival rules belong to
[GARRISON_LIFE.md](GARRISON_LIFE.md). This section owns what the economy-facing
services do.

### Service day

The civil day lasts **32 real minutes**.

- Dawn is **05:00**.
- Ordinary services open at **07:00**, or **06:00** with Early Reveille.
- Services close at **20:00** for Bonfire Time.
- Bonfire Time runs **20:00–23:00**; residents remain available for talk, not
  trade.
- Bedtime runs **23:00–05:00**.

Bed sleep advances to the chosen nightfall or morning destination. Every
crossed civil boundary resolves once; loading does not replay it. Missing dawn
on the surface returns the player to the bunk. Missing dawn underground uses
the ordinary death-loss outcome and never becomes free extraction.

### Service ownership

| Service | Role | Player-facing contract |
|---|---|---|
| Trade | Quartermaster | Buy expendables; sell ingredients and sale goods; never buy components or relics |
| Upgrades | Quartermaster | Four bag cells and three +4 HP health upgrades |
| Smithing | Brannoc | Gold-plus-component forge ladders, three utility-tool forge/reforge lines, and fletching |
| Alchemy | Ysolt | Bottle capacity and three draught recipes |
| Artifacts | Lanternkeeper | Repair/read and donate the twelve relics |
| Field Notes | Aldric | Review awarded observations and spend the finite note balance on one-rank doctrines |
| QoL Upgrades | Lanternkeeper | Bed recovery, locker shelves, and Early Reveille |
| Upgrades | Marisel | Jewellery blanks and mutually exclusive paths |
| Bed and locker | Hero's quarters | Rest/save and finite persistent storage |

Trade is the only two-sided buy/sell service. Permanent and material-spending
services are linear ladders. A transaction that consumes components, blows a
bottle, brews a draught, or sells all unmarked bag lines requires a visible **0.5-second hold**;
ordinary purchases and single-stack sales are taps.

### Quartermaster ladders

| Line | Base cost | Growth | Purchases |
|---|---:|---:|---:|
| Bag cell | 140 | x1.6 | 4 |
| Health upgrade (+4 HP) | 320 | x1.5 | 3 |

Trade also carries arrows, charges, Hardtack, and Small Beer at the prices in
§6. **Sell Unmarked** protects components, relics, and stacks needed by current
or pinned recipes.

### Forge ladders

The three utility-tool lines above share Brannoc's counter but are not upgrade
tracks: each is either ready, known and **BROKEN**, or never forged, and a
transaction always returns it to full durability. They therefore do not change
the 12-track forge-ladder or 26-track total caps.

Each forge track begins at rung 0 and has **three purchasable rungs**. Every
rung costs gold and forge components.

| Track | Base cost | Growth | Rank-3 effect |
|---|---:|---:|---|
| Sword edge | 120 | x2.1 | +3 HP per hit |
| Shield guard | 110 | x2.2 | 115-degree block arc, from 70 degrees |
| Bow string | 130 | x2.1 | 0.26-second draw, from 0.44 |
| Hookshot chain | 150 | x2.1 | 18.20 m reach, from 8.74 m |
| Each heavy armour piece | 65 | x1.9 | +1 HP soak and x0.97937 speed per piece |
| Each light armour piece | 35 | x1.8 | +0.5 HP soak and no speed cost per piece |

Chest, legs, arms, and boots each choose heavy or light independently, creating
eight armour tracks and **12 forge tracks** total. Four maxed heavy pieces give
**4.00 HP** of soak at **0.9200 speed**; four maxed light pieces give
**2.00 HP** at full speed. Choosing one path closes its sibling for that
piece.

Every third forge rung requires a chest-only **Cold Iron Core**. **Reforge**
clears one armour-piece commitment, refunds all components spent on that piece,
and does not refund gold.

### Jewellery ladders

Each of four jewellery slots first buys a blank, then commits to one of two
paths with **four purchasable rungs**:

| Slot | Blank | Path A | Path B |
|---|---:|---|---|
| Amulet | 220 | Vigor: +2 HP per rung | Focus: +15 stamina per rung |
| First Ring | 150 | Edge: +0.25 HP per swing | Swift: x1.0101 speed per rung |
| Second Ring | 150 | Edge: +0.25 HP per swing | Swift: x1.0101 speed per rung |
| Bracelet | 190 | Ward: +0.5 HP soak per rung | Wind: +0.1 stamina regeneration per rung |

Rungs cost **90 / 180 / 340 / 620 gold** and use
**2 / 4 / 6 + 1 gem / 8 + 2 gems** from the jewellery bench. **Recut** removes
one rung without refunding its stone.

All sources share their final stat ceilings: total added edge caps at **+5**,
soak at **4.0 HP**, speed at **1.0**, and maximum stamina at **160**. Health
starts at **12 HP**; each of the quartermaster's three health upgrades adds
**4 HP**, each Vigor rung adds **2 HP**, and maximum health is capped at
**32 HP**. The equipment screen reports only damage, speed, maximum health,
stamina, and soak.

### Home convenience ladders

- **Better Bed:** three ranks, 1 temporary HP granted per rank when
  sleeping; this overhealth absorbs damage before real health and does not raise
  maximum health.
- **Locker shelves:** starts at **24 cells**; two ranks add six each, for a hard
  maximum of **36**.
- **Early Reveille:** one rank; services open at **06:00** instead of 07:00.

The locker is persistent, survives death, and cannot be reached underground.
It uses the same stack-to-cell arithmetic as the bag. A full locker refuses a
transfer visibly. Starting a new trip clears the run bag, so anything the player
wants to keep unsold must first be sold, crafted, or moved into the locker.

The personal bed requires a hold and is identified by its **SLEEP IN YOUR BED**
prompt, focused quilt glow, and warm motes. It offers **Sleep until nightfall**
and **Sleep until morning**: nightfall means the next strictly future 20:00, while
morning settles at 07:00 or at 06:00 with Early Reveille. Sleep pauses the world
for a 2.4-second analog clock whose hands sweep linearly from the starting time
to the target before the jump is applied. A successful sleep fully restores real
health and stamina, grants purchased Better Bed overhealth, and requests an
autosave. A raid boundary at 23:00 can interrupt either destination; interrupted
sleep grants no recovery and requests no autosave. The bed is unavailable during
a descent.

## 11. Boundaries

- This document may clarify the current economy; it does not authorise new
  content. [NOW.md](NOW.md) authorises work.
- The number of currencies, items, ladders, residents, floors, and services may
  not rise without an explicit change to [SCOPE.md](SCOPE.md).
- Item entries and item-specific exceptions change in [ITEMS.md](ITEMS.md), not
  here.
- Civil life, Firewood/Hearth, and the raid change in
  [GARRISON_LIFE.md](GARRISON_LIFE.md), not here.
- Implementation names and interfaces change in [CONTRACT.md](CONTRACT.md), not
  here.
