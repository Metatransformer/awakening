# The metagame

Moonlighter's structure on OOT's feel. The dungeon is where you take risk; the
town is where you turn it into permanence. Everything below is the design of
record for what is *implemented*, not a wishlist — every number here is read
from the code it describes, and the file it lives in is named.

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

---

## 5. Extraction — the priced decision

The way out is a rune pad you stand on and **hold**
(`scripts/world/extract_node.gd`). It is a hold and not a press because a
decision you can make by fumbling a button is not a decision, and because the
hold can be interrupted — leaving with something chasing you is its own problem.

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
- **The smith.** Five permanent lines (`scripts/items/shop_db.gd`), priced
  against the drop tables — a good run extracts with roughly 250–450 gold of
  ingredients, so cheap lines land after one run and dear ones after two or
  three.

  | Line | Base cost | Growth | Limit |
  |---|---|---|---|
  | Arrows ×10 | 40 | — | unlimited |
  | Bag slot | 140 | ×1.6 | 4 |
  | Sharpen blade | 220 | ×1.7 | 3 |
  | Temper armour | 260 | ×1.8 | 2 |
  | Heart container | 320 | ×1.5 | 3 |

  Every line changes a number the player can feel inside one run. Nothing here
  is a stat-stick you have to take on faith.
- **The gate.** Into the dungeon, and back out again on the arrival pad.

The costs scale with how many you have already bought, so the shop keeps pace
instead of being solved by one lucky run. The limits are what stop the smith
from being an infinite gold sink that makes the dungeon irrelevant.

---

## 7. The dungeon

A seeded room graph (`scripts/world/dungeon.gd`) built from the P6 kit at run
time: rooms, connecting corridors, torches in pools with dark between them,
enemies scattered on a ring so a group is not one clump you can clear with a
single swing, and chests carrying the richer rolls.

Enemies are `Crawler` (`scripts/actors/enemy/crawler.gd`): see you, walk at you,
**rear back and hold for 0.45 s**, lunge, recover. That telegraph is the entire
fight — it is the window to block, roll, or hit first — and it is why an enemy
this simple is still a fight rather than a health tax.

---

## 8. Where it lives

| Concern | File |
|---|---|
| Run state, bag, extraction, death | `scripts/autoload/run_state.gd` |
| Persistent gold and upgrades | `scripts/autoload/game_state.gd` |
| Town↔dungeon transition and fade | `scripts/autoload/game_flow.gd` |
| Ingredients and drop tables | `scripts/items/item_db.gd` |
| The smith's catalogue | `scripts/items/shop_db.gd` |
| Vendor / smith screen | `scripts/ui/shop/trade_screen.gd` |
| HUD | `scripts/ui/hud/hud.gd` |
| Town | `scripts/world/town.gd`, `scenes/rooms/town.tscn` |
| Dungeon | `scripts/world/dungeon.gd`, `scenes/rooms/dungeon.tscn` |
| The way out | `scripts/world/extract_node.gd` |
| Drops on the floor | `scripts/world/loot_mote.gd` |

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
pick up a drop → open a chest → **hold the pad** → home. It prints the gold, bag
and health it observed at each seam, and prints `MVP FAIL …` if a beat did not
happen. Last run:

```
MVP after_sell  gold=346 bag=0
MVP after_buy   gold=206 slots=13
MVP descended   in_dungeon=true  rooms=6 enemies=15
MVP after_chest bag=3 value=28 fee=15
MVP home        scene=Town in_dungeon=false gold=191 bag=28 hearts=12/12
```

**Do not pass `--headless`.** There is no rendering device in headless mode and
every frame comes out empty.
