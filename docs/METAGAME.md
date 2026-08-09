# The metagame

Moonlighter's structure on OOT's feel. The dungeon is where you take risk; the
town is where you turn it into permanence. Everything below is the design of
record for what is *implemented*, not a wishlist — every number here is read
from the code it describes, and the file it lives in is named.

> **`docs/GDD.md` is the north star**; this file is the economy underneath it.
> The structure here supersedes the "one cyclic, key-locked dungeon ending in a
> boss" in `docs/CONTRACT.md` §0 — but **everything else in the contract still
> holds**. OOT remains the bar for camera, locomotion, combat feel, and `refs/`.
> We changed what the game *is*, not how it *feels*.

---

## 1. The loop

```
        town                            dungeon
  ┌───────────────────┐           ┌────────────────────┐
  │  sell to vendor   │           │  clear rooms       │
  │  buy from smith   │  ──gate──▶│  kill, open chests │
  │  heal is free     │           │  fill the bag      │
  └───────────────────┘           └─────────┬──────────┘
            ▲                               │
            │                    ┌──────────┴───────────┐
            │                    │                      │
            └──── extract ───────┤              die ────┤
                 (pay a fee,     │         (bag lost,   │
                  keep the bag)  │          gold kept)  │
                                 └──────────────────────┘
```

The whole game is one question, asked over and over: **is what I am carrying
worth more than the walk back?** Every system below exists to sharpen that
question or to price it.

---

## 2. Gold, and the two things that hold value

There is one currency: **gold**. Two containers hold value, and they behave
differently on death, which is the entire tension.

| | Survives death | Where it lives |
|---|---|---|
| **Gold** | yes | `Game.gold` (`scripts/autoload/game_state.gd`) |
| **The bag** | **no** | `Run.bag` (`scripts/autoload/run_state.gd`) |
| **Permanent upgrades** | yes | `Game.bag_slots`, `sword_bonus`, `armour_level`, hearts |

Ingredients are never spent directly. They are sold, and gold buys upgrades.
That indirection is deliberate: it means a great run is not *automatically*
progress — you still have to get it home and choose what to spend it on.

---

## 3. The bag — the pressure valve

`START_BAG_SLOTS = 12` (`scripts/core/consts.gd`), each slot stacking up to the
item's own `stack` limit.

A full bag is a real event, not an error: `Run.collect()` returns how many
actually fit, and a mote that could not be picked up **stays on the floor and
pulses** rather than vanishing (`scripts/world/loot_mote.gd`). The player can
see exactly what they are leaving behind. That is the anti-hoarding pressure —
late in a run, picking up a Bone Shard means declining a Void Pearl.

Bag slots are purchasable (4 more, at rising cost), so the pressure eases as a
deliberate reward rather than disappearing.

---

## 4. Ingredients

Ten of them, three rarity bands, in `scripts/items/item_db.gd`. Value is what
the vendor pays per unit.

| Item | Value | Rarity | Stack |
|---|---|---|---|
| Bone Shard | 4 | common | 20 |
| Rot Moss | 6 | common | 20 |
| Cracked Flint | 8 | common | 20 |
| Grave Wax | 11 | common | 15 |
| Iron Scrap | 18 | uncommon | 12 |
| Ghost Silk | 24 | uncommon | 12 |
| Ember Gland | 32 | uncommon | 10 |
| Deep Amber | 55 | rare | 6 |
| Void Pearl | 78 | rare | 4 |
| King's Signet | 90 | rare | 2 |

Note the **inverse stack sizes**. A rare item is worth more *and* takes more
slots per unit of value, so a bag full of King's Signets is a genuine choice
against a bag full of Grave Wax, not a strictly better one.

Enemies roll from a weighted table; chests roll richer ones. Rarity also drives
the mote's glow radius, which is the only "look over here" the game does.

Four more items drop from the same tables and share the same bag, but they are
not ingredients and the vendor will not take them: the **components** the forge
eats. They are in §6.5.

---

## 4.5 Heat — what tempo is worth

Numbered `4.5` rather than `5` on purpose: extraction is §5 and several code
comments point at it by number. Do not renumber the sections below.

The economy above prices **how deep** you went. Heat prices **how fast**
(`scripts/autoload/heat.gd`, autoload `Heat`). Kills chain; the chain decays;
what the chain is worth gets **stamped onto the loot you sweep while it is lit**.

| Tier | Kills | Window | Multiplier | Magnet |
|---|---|---|---|---|
| 0 — Cold | 0 | — | ×1.00 | — |
| 1 — Warm | 2 | 4.0 s | ×1.25 | 2.5 m |
| 2 — Hot | 5 | 3.2 s | ×1.60 | 3.5 m |
| 3 — Blazing | 9 | 2.5 s | ×2.20 | 4.5 m |

`K.HEAT_TIER_KILLS`, `HEAT_TIER_WINDOW`, `HEAT_TIER_MULT`, `HEAT_MAGNET`.

**The window shrinks as the chain climbs.** That is the whole tension: the reward
for being fast is a shorter leash. A window that grew with the tier would make
Blazing the safe state and delete the decision.

**What breaks it:** the window running out, or **a blow that lands**. A blow you
*block* does not, because Heat watches `Bus.player_health_changed` and a blocked
blow never changes health — the shield being the tempo tool is a consequence of
the wiring, not a special case. It is the same rule the charm channels under
(§5), which is why it should feel familiar rather than new.

**Breaking steps down one tier, not to zero.** Zeroing makes one mistake at
Blazing cost nine kills, and makes the meter binary — the player never watches
the thing they are about to lose sliding away.

**Two things make a chain physically possible** at OOT's swing lengths, and both
are transient:

- a kill refunds `K.STAMINA_KILL = 40` stamina (against `STAMINA_ROLL = 34`), so
  a kill buys the roll that reaches the next enemy;
- motes are dragged toward the hero from the tier's magnet range, so sweeping the
  floor is not a separate, chain-killing errand.

**Heat pays money, never power.** No damage, no reach, no speed — GDD pillar 4.
A chain that made the hero stronger would quietly delete the smith.

### Where the money goes

A mote records the multiplier at the moment it *dropped*, and then **cools** over
`K.HEAT_COOL_TIME = 6 s` back toward ×1.00. Loot left on the floor while you go
and die somewhere is worth its base price again. Sweeping is the act that banks
it.

The extra is **not** a different item. It accumulates in `Run.premium`, a single
gold pot, and `Run.bag_value()` is `base_value() + premium`. That choice matters:
keying the bag by `(item, tier)` would double the row count and destroy the
value-per-slot comparison §3's pressure is built on. Selling a line pays its base
plus its proportional share of the pot (`Run.line_value()`), so the trade screen
names the gold that will actually land.

Because the premium sits inside `bag_value()`, **the extraction fee rises with
it** — `cost = max(15, bag_value × 0.25)`, unchanged, and no fee code knows Heat
exists. Going fast makes the walk home more expensive. That is the one question
(GDD §2) asked on the time axis.

**On the HUD:** the bar under stamina, filling with the window left and coloured
ash → moth → gold → breathing gold, with the live multiplier beside it; it flashes
rust when the chain breaks. The banked premium reads `+N HOT` in gold above the
bag corner, so the money is visible next to the number the fee is taken from.

Proof: `tools/directors/heat_flow.gd`.

---

## 5. Extraction — the priced decision

The way out is the **Homeward Charm** (`scripts/items/homeward_charm.gd`): a
permanent key item, used from the pause menu's ITEMS screen, under **USE**.

**Superseded 2026-08-08, on the owner's instruction: this was a rune pad you
stood on and held (`scripts/world/extract_node.gd`, deleted).** The pad made
leaving a *place*. That is the wrong noun — it turned the game's central
decision into a navigation problem, and a rich run could be lost to not
remembering where the door was. The decision was never "can I find my way back",
it was "is what I am carrying worth the fee".

The charm is **not consumable**. A stock you can run out of would strand a
player underground, and being stranded is the one thing this section rules out
below: you are never trapped. The fee is the price of leaving; the charm is just
where the button lives.

The pad's two real properties survive the move, because everything below is
built on them:

- **Leaving takes time and can be interrupted.** The pad was a *hold* so that a
  decision could not be made by fumbling a button. A menu press has neither
  property on its own — the menu is paused, so a "hold" in there is a slow
  click. So using the charm closes the menu and starts a **1.2 s channel in the
  world**: he is rooted, the ring closes around the bag total, and **a blow that
  lands breaks it**. A blow he *blocks* does not — standing your ground behind
  the shield while the charm works is a legitimate way to leave, and a better one
  than mashing a button was.
- **The fee comes out of the number you are protecting**, and the HUD says so.

It is deliberately **not bindable to an item button**. One D-pad press that ends
the run is precisely the fumble the hold existed to prevent.

```
cost = max(15, round(bag_value × 0.25))
```

`EXTRACT_MIN = 15`, `EXTRACT_RATE = 0.25` (`scripts/autoload/run_state.gd`).

The fee is a **share of what you are carrying**, not a flat toll and not a
function of depth. Three consequences, all intended:

- A poor run is cheap to abandon. You are never trapped by your own poverty.
- A rich run costs real money to bank — the greed curve bends but never breaks.
- You cannot extract with gold you do not have. `can_extract()` gates on it, and
  the refusal is surfaced (`Bus.extract_refused`), so being too poor to leave
  with treasure is a legible failure state rather than a soft-lock.

Extracting also **heals you to full**, and it is the only heal in the game. That
is what makes leaving feel like relief instead of retreat, and it is what stops
a player from farming one safe room forever.

**Death** (`Run.die()`) takes the whole bag and nothing else. Gold and every
upgrade bought with it survive. You wake in town at full health — leaving you at
zero would just kill you again before you could sell.

---

## 6. The town

One walled courtyard (`scripts/world/town.gd`) with three things in it.

- **The vendor.** Sells nothing; buys everything. The trade screen
  (`scripts/ui/shop/trade_screen.gd`) lists the bag sorted by value with a
  "sell everything" line, because the common case is dumping the lot and the UI
  should not make that tedious.
- **The smith.** Eight permanent lines (`scripts/items/shop_db.gd`), priced
  against the drop tables — a good run extracts with roughly 250–450 gold of
  ingredients, so cheap lines land after one run and dear ones after two or
  three.

  | Line | Base cost | Growth | Limit | Also costs |
  |---|---|---|---|---|
  | Arrows ×10 | 40 | — | unlimited | — |
  | Bag slot | 140 | ×1.6 | 4 | — |
  | Heart container | 320 | ×1.5 | 3 | — |
  | Sharpen the blade | 120 | ×2.1 | 3 | components |
  | Temper the armour | 140 | ×2.1 | 3 | components |
  | Bind the shield | 110 | ×2.2 | 3 | components |
  | String the bow | 130 | ×2.1 | 3 | components |
  | Lengthen the chain | 150 | ×2.1 | 3 | components |

  The top three are stock: things the smith HAS, and money is the whole
  transaction. The bottom five are the **forge** (§6.5) and gold alone will not
  buy them.

  Every line changes a number the player can feel inside one run. Nothing here
  is a stat-stick you have to take on faith.
- **The gate.** Into the dungeon, and back out again on the arrival pad.

The costs scale with how many you have already bought, so the shop keeps pace
instead of being solved by one lucky run. The limits are what stop the smith
from being an infinite gold sink that makes the dungeon irrelevant.

---

## 6.5 The forge — the only upgrades that are not bought

*Numbered 6.5 rather than 7 for the same reason §4.5 is: the sections below it
are referenced from code comments and directors. Do not renumber them.*

Gold is a grind. A grind is solvable by patience, and a metagame whose whole
ladder is solvable by patience stops asking anything of the player after the
first hour. So the five pieces of gear that matter each climb a ladder whose
rungs cost **gold and components**, and components only exist underground.

### The five ladders

Four rungs each: rung 0 is the piece as it comes out of the box, and there are
three to buy. The numbers live in `scripts/core/consts.gd` and the gear reads
them back through accessors on `Game` — `sword_bonus()`, `armour_soak()`,
`guard_arc()`, `bow_draw_time()`, `hook_reach()` — so a rung IS the effect, and
there is no per-track special case anywhere in the shop.

| Track | Gear | What the rung moves | 0 → 3 |
|---|---|---|---|
| `edge` | sword | damage, in quarter-hearts | +0 → +3 |
| `plate` | armour | damage soaked off every hit, floor of one quarter | −0 → −3 |
| `guard` | shield | block arc, in degrees | 70° → 115° |
| `string` | bow | draw time, in seconds | 0.44 → 0.26 |
| `chain` | hookshot | **reach**, in metres | 8.74 → 18.20 |

The top of the chain ladder is exactly `K.HOOK_LONGSHOT_RANGE` — [oot]'s
Longshot, measured, not invented. That is asserted by the director, because a
table whose comment claims a source and whose numbers have drifted off it is
worse than one with no comment.

### The four components

They live in `scripts/items/item_db.gd` alongside the ingredients and share the
bag with them, but they are `ItemDef.Kind.COMPONENT`, and everything downstream
branches on that one bit: the pouch marks them ◆, the vendor's "sell everything"
leaves them alone, and extraction moves them to the workbench instead of the
purse.

| Component | Value | Rarity | Stack | Drops from |
|---|---|---|---|---|
| Whetstone Grit | 14 | common | 8 | bodies and chests |
| Riveted Plate | 22 | uncommon | 6 | bodies and chests |
| Tension Coil | 26 | uncommon | 6 | bodies and chests |
| Cold Iron Core | 100 | rare | 2 | **chests only** |

Read the recipes in `ShopDb.PARTS` by column, not by row: grit is the cheap tax
on the two melee ladders, plate is the armour's spine and the shield's second
ingredient, and coil belongs to the two things under tension — the bow and the
chain. **Every third rung wants a Cold Iron Core.** That is the pacing gate: the
core never drops off a body, so no amount of grinding room one finishes a
ladder, and which ladder gets the core you found is the only genuinely hard
spending decision the smith ever poses.

### How they get home

Exactly like everything else, which is the point:

- They **drop as motes** and you pick them up by **walking over them**. There is
  no pick-up button — `LootMote` is an Area3D and the overlap is the pickup.
- They sit **in the bag**, taking slots, counted by `Run.slots_used()` and
  valued by `Run.bag_value()`. A pocket full of grit is a pocket you cannot put
  a Void Pearl in, and the extraction fee is charged on the components too.
- **Extraction banks them** (`Run.bank_components()`): the fee comes off the
  whole bag first, then components move to `Game.components` and the rest stays
  for the vendor. `Bus.components_banked` says what moved.
- **Death takes them.** `die()` does not bank. Components in the bag die with
  the bag; components already on the bench are permanent, like gold.

### The pouch

`scripts/ui/menu/pouch_panel.gd`, on the pause menu under Equipment. It draws
`Game.bag_slots` cells — not a list — because a list of six rows and a list of
twelve rows look the same at a glance and the difference between them is the
entire pressure in §3. Stacks occupy one cell until they overflow, exactly as
`Run.slots_used()` counts them, so the picture and the arithmetic cannot
disagree. The right-hand column names what is under the cursor and shows the
workbench stock, read-only: this screen shows what you have, the smith spends
it.

It is a separate screen from **Items**, which is what you are *holding* and what
the D-pad equips. Carrying and holding are different questions and a player who
conflates them is a player who thinks the bag can be equipped.

---

## 7. The dungeon

A seeded room graph (`scripts/world/dungeon.gd`) built from the P6 kit at run
time: rooms, connecting corridors, torches in pools with dark between them,
enemies scattered on a ring so a group is not one clump you can clear with a
single swing, and chests carrying the richer rolls.

Enemies are `Crawler` (`scripts/actors/enemy/crawler.gd`) in the shallow rooms
and `Enemy` (`scripts/actors/enemies/enemy.gd`) deeper: see you, close, **rear
back and hold**, swing, recover. That telegraph is the entire fight — it is the
window to block, roll, or hit first — and it is why an enemy this simple is
still a fight rather than a health tax. A pack keeps itself spread out, circles
rather than stacking, and gives up and walks home if you leave — which is what
makes disengaging a real option and therefore what makes the charm's channel
survivable.

### 7.1 Going deeper

The deepest room of every floor holds the best chest and, beside it, **the way
down** (`scripts/world/stairs.gd`) — a lit pit with a `DESCEND` prompt. Taking
it keeps everything: the same bag, the same health, the same fee climbing. It
banks nothing and heals nothing. The only way to bank is to go home, and the
stair is deliberately placed at the end of the longest walk, next to the reward,
so the moment you *can* go deeper is the moment you have the most to lose.

There is no bottom. `Flow.descend()` reloads the same dungeon scene with
`Run.level` one higher, and the generator seeds off `Run.floor_seed()` — the
same run seed still replays identically all the way down, but every floor of a
run is a different floor.

Everything that gets harder or richer with depth is a pure function of the floor
and lives in **`scripts/core/progression.gd`** (`Prog`). Nothing else gets a
curve of its own. Per floor:

| Moves | How much | Stops at |
|---|---|---|
| Monster health | +25% of the authored value | never |
| Monster damage | +1 quarter every 3 floors | never |
| Wind-up | −3%, so the telegraph tightens | 60% — a wind-up you cannot react to is a coin flip, not difficulty |
| Rooms on the floor | +1 every 2 floors | 12 |
| Pack size | grows both ends | 7 in a room |
| Elites | from floor 3, +5% a room | 35% |
| Drop rolls off a body | +1 every 3 floors | never |
| Chest picks | +1 every 3 floors | 7 |
| Rare weighting in the tables | flattens toward uniform | 0.6 of the way |

The drop side of that table is not decoration. The extract fee scales with what
you are carrying, so if the carrying did not scale too, going deeper would be
strictly worse than farming floor 1.

An **elite** is one bigger body rather than a stat nudge — 1.8× health, +1
damage, 1.22× the height, at most one to a room. A room of six monsters and a
room of five plus one you can *see* coming are different rooms, and only the
second one is a decision.

---

## 8. Where it lives

| Concern | File |
|---|---|
| Run state, bag, extraction, death | `scripts/autoload/run_state.gd` |
| Persistent gold, forge rungs, workbench stock | `scripts/autoload/game_state.gd` |
| Town↔dungeon transition and fade | `scripts/autoload/game_flow.gd` |
| Ingredients, components and drop tables | `scripts/items/item_db.gd` |
| The smith's catalogue, and the forge recipes | `scripts/items/shop_db.gd` |
| The upgrade ladders, rung by rung | `scripts/core/consts.gd` (`K.EDGE_DAMAGE` …) |
| The difficulty curve, every floor of it | `scripts/core/progression.gd` |
| The way down | `scripts/world/stairs.gd` |
| The pouch — the bag, drawn as slots | `scripts/ui/menu/pouch_panel.gd` |
| Vendor / smith screen | `scripts/ui/shop/trade_screen.gd` |
| HUD | `scripts/ui/hud/hud.gd` |
| Town | `scripts/world/town.gd`, `scenes/rooms/town.tscn` |
| Dungeon | `scripts/world/dungeon.gd`, `scenes/rooms/dungeon.tscn` |
| The way out | `scripts/items/homeward_charm.gd` |
| Drops on the floor, and their heat stamp | `scripts/world/loot_mote.gd` |
| The chain, its tiers and what they are worth | `scripts/autoload/heat.gd` |

The game boots into **town** (`run/main_scene`). `Flow` is the only thing that
ever calls `change_scene_to_file`; if a second caller appears, the fade stops
being a guarantee and starts being a suggestion.

---

## 9. Proving it still works

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

`tools/directors/mvp_loop.gd` walks the whole loop through the real interaction
paths and photographs every beat: sell one → sell all → buy → descend → fight →
pick up a drop → open a chest → **channel the charm** → home. It prints the gold,
bag and health it observed at each seam, and prints `MVP FAIL …` if a beat did not
happen. Last run:

```
MVP after_sell  gold=346 bag=0
MVP after_buy   gold=206 slots=13
MVP descended   in_dungeon=true  rooms=6 enemies=17
MVP after_chest bag=4 value=95 fee=24
MVP home        scene=Town in_dungeon=false gold=182 bag=95 hearts=12/12
```

The economy of tempo has its own director (§4.5):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/dungeon.tscn --director=res://tools/directors/heat_flow.gd --out=/tmp/heat/x.png --warmup=60
```

It climbs the ladder kill by kill, photographs every tier, drops loot at full
heat and lets the magnet sweep it, then breaks the chain with a landed blow and
lets the rest cool. `HEAT FAIL …` on any claim that did not hold. Last run:

```
HEAT kill 9      -> kills=9 tier=3 mult=2.20
HEAT after_sweep bag=222 premium=114 fee=56   (was value=0 fee=15)
HEAT premium 114 vs 130 uncooled -- the gap IS the cooling
HEAT struck      tier 3 -> 2
HEAT OK
```

The forge and the pouch have theirs (§6.5):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/forge_loop.gd --out=/tmp/forge/x.png --warmup=60
```

It reads the catalogue, opens the pouch, is refused a rung it cannot pay for in
components, buys all fifteen rungs and watches the gear's own accessors move,
descends, walks over three component motes with **no button pressed**, extracts,
dies on purpose to prove the bench survives what the bag does not, and finally
saves, wipes and reloads to prove a forged rung survives quitting the game.
`FORGE FAIL …` on any claim that did not hold. Last run:

```
FORGE base       edge=+0 plate=-0 guard=70 draw=0.44 reach=8.74
FORGE full       edge=+3 plate=-3 guard=115 draw=0.26 reach=18.20
FORGE swept      bag=3 value=62        (walked over, nothing pressed)
FORGE pre_extract bag=140 fee=35
FORGE home       bench={grit:92 plate:82 coil:78 core:115} bag={void_pearl:1}
FORGE after_death bench_cores=115 bag=0
FORGE reloaded   rungs={edge:3 plate:3 guard:3 string:3 chain:3} slots=12
FORGE OK
```

**Do not pass `--headless`.** There is no rendering device in headless mode and
every frame comes out empty.
