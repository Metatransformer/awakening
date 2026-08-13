# Items

This document owns item identities, their player-facing purpose, and where they
enter progression. It is a catalogue, not a development diary.

- [METAGAME.md](METAGAME.md) owns prices, supplies, bag rules, extraction, and
  upgrade ladders.
- [PUZZLES.md](PUZZLES.md) owns puzzle atoms, placements, and Blessing offers.
- [BESTIARY.md](BESTIARY.md) owns the enemies an item answers.
- [SCOPE.md](SCOPE.md) owns every content ceiling.
- The data tables beside the implementation own tuning values and lore strings.

## Design rule

> Every permanent item is an answer. If its whole effect is that a number rises,
> it belongs on an upgrade ladder instead.

The catalogue uses seven distinct shelves:

| Shelf | Meaning |
|---|---|
| Starting tools | Sword and shield; always available |
| Durable utility tools | Axe, Pickaxe, and Fishing Rod; permanent work access with finite uses |
| Usable items | Permanent verbs or locks earned through progression |
| Relics | Named, exposed artifacts carried home for one permanent consequence |
| Blessings | Run-only rule bends that cost bag space |
| Stock | Counted supplies such as Escape Ropes, arrows, charges, rations, bottles, and draughts |
| Run tokens | Floor-scoped Small Keys and the distinct authored Boss Key |

Ingredients and components are rewards, not usable items. Upgrade rungs are
progression, not objects. These categories share neither state nor conversion
rules merely because the UI can list them together.

### Boss Key

Each authored floor contains exactly one oversized golden Boss Key. It is a
floor-scoped progression token earned at the end of that floor's critical-path
puzzle, in a different room from the Boss Door. The 5.4 × 4.6 m Boss Door
consumes it once to admit the separate boss chamber. It is neither a Small Key
nor stock, never occupies the item ring or bag, persists in an active-run save,
and remains tagged to its owning floor while the player uses bidirectional
stairs. It clears when spent, extracted, killed, or starting a new run, and can
never open another floor's Boss Door.

## Starting tools

### Sword

The sword is the universal close-combat answer and the basic physical puzzle
verb. Its broad usefulness creates the need for later tools to answer distance,
armour, geometry, or timing more elegantly.

### Shield

The shield actively blocks inside a facing arc, parries on timing, redirects
specific attacks, and manipulates authored light puzzles. It is a verb, not a
passive armour number.

## Three durable utility tools

Brannoc forges and reforges exactly three permanent, non-combat utility tools.
They are a separate catalogue from starting tools and the six usable items.

| Tool | Maximum uses | Work answer | Forge/reforge bill |
|---|---:|---|---|
| **Woodsman's Axe** | **8** | One successful daily tree impact in the outskirts grove | **60 gold + 3 Iron Scrap** |
| **Pickaxe** | **12** | One committed impact on a generated dungeon vein | **75 gold + 3 Iron Scrap** |
| **Fishing Rod** | **10** | One resolved fishing attempt, successful or failed | **45 gold + 1 Iron Scrap + 1 stored Firewood bundle** |

The first forge and every reforge restore the tool to its full maximum. A known
tool at zero durability remains known, displays **BROKEN**, is removed from
`Game.items`, and may be reforged; it is not destroyed or bought again as a
different object. Positive durability mirrors into `Game.items` only for
compatibility with existing ownership readers.

Utility tools never occupy either hand, either loadout, the right-hand ring,
the kit wheel, a bag or document-case cell, the locker, a sale line, an
armament slot, or a combat attack. They are read-only entries on the Equipment
page and forge/reforge lines at Brannoc. Pre-v18 Axe ownership migrates at full
durability; v18 persists all three tools, including known broken zeroes.

Spend timing is part of each identity. The Axe spends only when a valid daily
tree chop reaches its successful impact. The Rod spends on every resolved
attempt—catch or failure—and never on cancel. The Pickaxe spends only on the
impact that commits a previously intact vein's depletion. Economy and resource
allocation belong to [METAGAME.md](METAGAME.md); implementation interfaces and
save shapes belong to [CONTRACT.md](CONTRACT.md).

## Six usable items

The six-item cap includes four boss rewards and two workings learned by reading
relics. The Far Lantern is a pure final lock and never occupies a ring stop.

| Item | Primary answer | Enters progression | Lasting change |
|---|---|---|---|
| **Bow** | Eye switches and distant or exposed targets | Floor 1 boss great chest | Adds precise ranged action and an arrow budget |
| **Burst** | Cracked structures, plated guards, and grouped threats | Floor 2 boss great chest | Adds the one scarce destructive working |
| **Hookshot** | Hook rings, gaps, and distant bodies | Floor 3 boss great chest | Changes reach and position without dealing damage |
| **Far Lantern** | The final authored door | Floor 4 boss great chest | Ends the expedition and opens the Long Descent |
| **Sustain** | A Heat chain about to break | Sustain-Verse, read at home | Preserves exactly one break, not a duration |
| **Ballast** | A dangerous blow while carrying value | Ballast-Verse, read at home | Burns the cheapest exposed stack for temporary protection |

### Ring contract

The right-hand ring has exactly six stops: sword, Bow, Hookshot, Burst,
Sustain, and Ballast. The Far Lantern is owned but not wielded. Adding a seventh
stop, a fourth working, or a casting subsystem requires an explicit scope
amendment.

### Progression contract

- A floor boss earns a persistent great chest containing its deterministic
  usable item and the shared item-get ceremony.
- The boss relic is a separate exposed pickup. The permanent verb never passes
  through bag pressure; the artifact does.
- A floor's boss item opens that floor's shortcut. The next floor's item opens
  its vault, so the Bow has no earlier vault to open and the Far Lantern has no
  later one.
- Any critical route that requires ammunition also provides a cold-start supply
  answer. Ambient drops may help but never replace that guarantee.

## Twelve relics

Relics are named, unique, hand-placed artifacts. They never roll from a generic
drop table, never sell, never enter the document case, and never become a
currency.

A recovered relic occupies one exposed bag cell and contributes a uniform
artifact weight to the ordinary extraction calculation. Death returns it to its
authored location. At Highbridge it arrives broken—or, for a Verse, unread—and
becomes active only through the Lanternkeeper's Artifacts service.

Each relic must change one existing catalogue, ladder, rule, verb, or
wayfinding signal through one bounded consequence. It also lights one physical
garrison prop, so collecting artifacts changes home visibly as well as
mechanically.

| Relic | Source | Consequence |
|---|---|---|
| **Tally-Ledger of Fair Weights** | Floor 1 deep chest | Smith learns rung 2 of every forge ladder |
| **Imperium Anvil-Plate** | Floor 1 boss | Smith learns rung 3 of every forge ladder |
| **Cracked Still-Head** | Floor 1 vault | Alchemist learns Ironhide Draught |
| **Cinder-Retort** | Floor 2 deep chest | Alchemist learns Emberblood Draught |
| **Glass-Kiln Core** | Floor 2 boss | Bottles 3 and 4 can be made |
| **The Sustain-Verse** | Floor 2 vault | Teaches Sustain |
| **The Ballast-Verse** | Floor 3 deep chest | Teaches Ballast |
| **Sounding-Rod** | Floor 3 boss | The floor's deep chest hums on arrival |
| **Warp-Stone Fragment** | Floor 3 vault | A trip may start at an opened shortcut |
| **Rope-Drum** | Floor 4 deep chest | Ordinary extraction rate falls from 25% to 20% |
| **Pillar-Shard** | Floor 4 boss | The square lights and ordinary sale value rises 10% |
| **The Riven Chord** | Long Descent floor 10 | Enables the completionist Chord ending when the collection is complete |

Relic boundaries:

- Repair gold activates the artifact; it does not purchase or sell the relic.
- A relic cannot directly raise damage, health, speed, stamina, or soak.
- The two Verses are the only relics permitted to grant a new verb.
- Relics are not required for the ordinary Lantern ending. The complete set
  matters only to the Chord ending.
- A lost or raid-stolen unique relic must remain recoverable. No valid save can
  permanently lose one.

## Twelve Blessings

Blessings are zero-value, run-only boons offered by Votive Courts. Each occupies
one bag cell, bends a rule the game already runs, and disappears on returning
home or dying.

They never directly change the five standing stats: damage, speed, maximum
health, maximum stamina, or soak. A Blessing also cannot be a weaker copy of a
permanent usable item or relic. [PUZZLES.md](PUZZLES.md) owns the twelve-entry
pool, offer composition, and placement.

The decision is capacity: accepting more temporary possibility leaves less
room for sale goods, components, and artifacts.

## Ingredients and components

Sale goods and crafting materials compete for the same bag cells but have
different home uses:

- **Ingredients and pot gems** are ordinary merchandise. Trade buys them unless
  a named recipe consumes them first.
- **Forge components** bank to Brannoc's bench.
- **Alchemy materials** bank to Ysolt's bench.
- **Jewellery materials** bank to Marisel's bench.

One component belongs to one bench. Components do not sell, and recipes do not
share materials across professions. Rare finishing materials come from authored
chest supply rather than becoming a body-drop grind. Exact values, stacks, and
recipes live in the item and service data; [METAGAME.md](METAGAME.md) owns how
they travel and are spent.

## Stock

Stock is counted outside the bag and never carries sale value or Heat premium.

| Stock | Role |
|---|---|
| **Arrows** | Persistent bow ammunition bought, found, or fletched |
| **Burst charges** | Scarce destructive uses bought at home or supplied at required routes |
| **Escape Ropes** | Counted carried provision stock, bought or found, maximum 9 |
| **Rations** | Slow, interruptible recovery purchased at Trade |
| **Bottles and draughts** | Finite prepared healing or timed effects |

The Escape Rope is used from the Equipment/character page and consumed when
its world channel begins. It is not permanent, a starting tool, an Inventory or
run-bag line, a ration, an item-ring stop, or saleable merchandise. Its purchase,
channel, interruption and extraction rules are owned by
[METAGAME.md](METAGAME.md).

Small Keys are floor-scoped run tokens. Each one belongs only to the floor where
it was found and is spent at that floor's locked critical-path gate; it is not
carried stock and cannot open another floor's lock. The separate golden Boss Key
keeps the authored rule above.

Supply amounts, costs, caps, and recovery behavior belong to
[METAGAME.md](METAGAME.md).

## Upgrade ladders are not items

Forge, armour, jewellery, capacity, and convenience rungs are permanent choices
sold by services. They may change numbers because the ladder is the game's
explicit home for numerical growth.

Mutually exclusive armour and jewellery paths must expose their tradeoff and
their reversal rule. All sources that affect the same stat share the same final
ceiling. [METAGAME.md](METAGAME.md) owns the ladders and [SCOPE.md](SCOPE.md)
owns their total count.

## Boundaries

- No seventh usable item, seventh right-hand ring stop, fourth working,
  thirteenth relic, or thirteenth Blessing.
- No generic relic drops, random relic effects, relic sales, or permanent
  unique-artifact loss.
- No second inventory for Blessings or components.
- No fourth durable utility tool, utility-tool combat use, gear collection, or
  profession ladder.
- No armour or jewellery object catalogue while their art cap remains zero.
- New entries require an interesting decision, a named owner, a smallest proof,
  and an explicit scope amendment. This catalogue does not authorise work;
  [NOW.md](NOW.md) does.
