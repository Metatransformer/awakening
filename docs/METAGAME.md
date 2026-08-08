# The Lower Worlds — Metagame Design

The structure layer, in the style of **Moonlighter**: a town you return to, a
vendor who turns your haul into gold, a smith who turns gold and ingredients
into power, and a roguelike dungeon you leave *deliberately* rather than
finish.

This supersedes the "one cyclic, key-locked intro dungeon ending in a boss"
structure in `docs/CONTRACT.md` §0. **Everything else in the contract still
holds** — OOT remains the bar for camera, locomotion, combat feel, and the
`refs/` checklist. We changed what the game *is*, not how it *feels*.

---

## 1. The loop

```
        TOWN                                    DUNGEON
   ┌──────────────┐                        ┌──────────────┐
   │  Vendor      │ ingredients → gold     │  Room 1..N   │
   │  Smith       │ gold+ingr  → power     │  fight, open │
   │  Stash       │ unlimited              │  chests      │
   └──────┬───────┘                        └──────┬───────┘
          │            enter portal               │
          └──────────────────────────────────────▶│
                                                   │
          ◀────────── extract ───────────────────  │  push deeper?
             free: walk back to the entrance       │  (bag is filling)
             paid: teleport, priced by depth       ▼
          ◀────────── die ────────────────────── lose the bag
```

**The decision the whole game is built to produce:** your bag is nearly full,
you are five rooms deep, and you just found something good. Sell it or forge
with it? Carry it or drop something? Pay to leave now, walk back for free, or
push one more room?

## 2. The one idea

> **Every ingredient is both money and power.** The Wraith Core that buys your
> next blade is the same Wraith Core the blade recipe consumes. Holding wealth
> and gaining power are the same finite decision.

This is why there is **no gold in the dungeon**. Gold has exactly one faucet —
the vendor — so every coin you spend traces back to something you chose to sell
instead of forge.

## 3. Economy graph

Per `gamestack:rpg-systems`, every resource names its faucets and its drains.

| Resource | Faucets | Drains |
|---|---|---|
| **Ingredients** | enemy drops, chests | vendor sale, smith recipes, death (bag loss) |
| **Gold** | vendor sale *(only)* | extraction fee, smith recipes |
| **Hearts** | armor tiers | damage |

Both gold sinks are **desire-driven** — you pay to keep a haul, you pay to get
stronger. There is no punitive tax anywhere in the economy. Death destroys
ingredients but never gold, so a bad run costs you a haul, not your progress.

**Anti-hoarding:** the bag caps at 10 slots, so wealth cannot accumulate inside
a run. The town stash is unlimited — pressure lives in the dungeon, which is
where the interesting decision is.

## 4. Ingredients

Six, banded by depth. Depth band is fixed at authoring time and **enemies never
scale to the player** — early rooms become genuinely easy as you grow, and that
is the point.

| id | Name | Drops from | Band | Sell | Stack |
|---|---|---|---|---|---|
| `bone_shard` | Bone Shard | skeleton | 1 | 6 | 9 |
| `goblin_fang` | Goblin Fang | goblin | 1 | 10 | 9 |
| `kobold_ichor` | Kobold Ichor | kobold | 2 | 22 | 9 |
| `orc_plate` | Orc Scale-Plate | orc | 2 | 34 | 6 |
| `grave_ember` | Grave Ember | chests, band 2+ | 3 | 60 | 4 |
| `wraith_core` | Wraith Core | wraith | 3 | 110 | 3 |

**The baseline tier stays meaningful.** Bone Shard and Goblin Fang are consumed
by recipes at *every* tier, so a band-1 drop never decays into vendor trash.
That is the deliberate fix for slot-machine loot.

## 5. Depth bands

| Band | Rooms | Enemies | Chest contents |
|---|---|---|---|
| 1 | 1–3 | skeleton, goblin | band-1 ingredients |
| 2 | 4–7 | + kobold, orc | + grave_ember |
| 3 | 8+ | + wraith | + wraith_core |

## 6. Extraction

Two ways out, and choosing between them is a real decision.

**Free — walk back.** The entrance portal is always open. Cleared rooms stay
cleared, so the cost is time and the risk of what you walk into on the way.

**Paid — teleport.** Instant, from anywhere.

```
fee = EXTRACT_BASE + EXTRACT_PER_ROOM × rooms_cleared
    = 30 + 20 × rooms_cleared
```

Five rooms deep, leaving costs 130 gold. The fee rises exactly as your haul
gets more worth protecting — the price of safety tracks the value of what you
are protecting, which is what makes it bite.

Teleporting is a **3-second channel**. You must be standing still, and taking a
hit cancels it. You cannot buy your way out of a fight you are already losing.

## 7. Death

You lose **every ingredient in the bag except the first three slots** — the
belt pouch. You keep your gold, your stash, your gear, and you wake in town at
full health.

The belt is the reason death is a design feature and not just a punishment:
when you find the Wraith Core, you get to decide *right then* whether to spend
a belt slot on it. That is a good decision, and it is available on every run.

## 8. Crafting — the smith

Two tracks. Both spend gold **and** ingredients, so advancement always costs
something finite.

**Blade** — damage in quarter-hearts (`K.QUARTER`; 4 = one heart).

| Tier | Model | Damage | Cost |
|---|---|---|---|
| 0 | `sword_crude` | 2 | *starting gear* |
| 1 | `sword_common` | 3 | 120g + 6 bone_shard + 4 goblin_fang |
| 2 | `sword_elegant` | 4 | 320g + 8 goblin_fang + 5 kobold_ichor |
| 3 | `sword_noble` | 6 | 700g + 6 orc_plate + 3 grave_ember |
| 4 | `sword_knightly` | 8 | 1500g + 4 grave_ember + 2 wraith_core |

**Armor** — each tier adds a heart container.

| Tier | Max hearts | Cost |
|---|---|---|
| 0 | 3 | *starting* |
| 1 | 4 | 100g + 8 bone_shard |
| 2 | 5 | 300g + 6 kobold_ichor + 4 orc_plate |
| 3 | 6 | 700g + 5 orc_plate + 3 grave_ember |
| 4 | 7 | 1400g + 3 grave_ember + 2 wraith_core |

Model ids match `WeaponModels.make()` (`docs/CONTRACT.md` §8), so a tier-up is
visible in the hero's hand immediately.

## 9. Pacing target

A four-room run yields roughly 8–12 ingredients, worth ~100–150 gold if sold
outright. Blade 1 costs 120g *plus* ingredients you could have sold — so the
first upgrade lands around run 2–3, and every upgrade after it is a choice
between the two tracks rather than a queue.

## 10. What is deliberately *not* in the MVP

Named so nobody builds them by accident, and so the absences read as decisions:

- **No player-run shop.** Moonlighter's price-discovery minigame is the other
  half of that game; here the vendor pays a fixed, posted price.
- **No legendary tier.** Nothing in this table is a build-definer — the blade
  tiers are honest stat upgrades, which is the correct shape for a four-tier
  MVP ladder. A legendary tier needs a hand-authored manifest and a global cap
  (`gamestack:rpg-systems` C6) before it earns its place.
- **No boss.** The run ends when you extract, not when you win. Adding a boss
  later means adding a *reason to stay*, which is a different design problem.
- **No potions or consumables.** Health returns only in town, so the depth you
  reach is limited by the health you still have — which is what makes the
  extraction decision urgent instead of arithmetic.

## 11. Where it lives, and how to run it

`scenes/main.tscn` is the game. `Main` (`scripts/core/main.gd`) owns the hero,
the camera and the HUD — all three persist — and swaps exactly one world child
beneath them: `Town` or `Dungeon`. The hero is *moved*, never rebuilt, so no
transition can drop his gear, health or bag.

| Piece | File |
|---|---|
| Loop spine, world swap | `scripts/core/main.gd` |
| Town, stalls, gate | `scripts/town/town.gd`, `scripts/town/station.gd` |
| Floor plan (pure data) | `scripts/dungeon/dungeon_map.gd` |
| One room, built from the P6 kit | `scripts/dungeon/dungeon_room.gd` |
| Run, both exits, the channel | `scripts/dungeon/dungeon.gd` |
| Ingredients, drop tables | `scripts/items/loot_db.gd`, `loot_item.gd` |
| Bag and belt | `scripts/items/bag.gd` |
| Gear ladders | `scripts/items/gear.gd` |
| Enemies | `scripts/actors/enemies/enemy.gd` |
| Chests | `scripts/props/chest.gd` |
| Hearts, gold, bag, shop panels | `scripts/ui/hud.gd`, `hearts_bar.gd`, `bag_view.gd` |
| Economy truth | `scripts/autoload/game_state.gd` |

Two ways to prove it without playing:

```
godot --path . --headless tools/scenes/_loop_test.tscn
```

drives town → dungeon → kill → loot → extract → sell → forge → death and prints
a pass/fail line per assertion. It is the fast check; run it after touching
anything in the table above.

```
godot --path . -s tools/shoot.gd -- --scene=res://scenes/main.tscn \
    --out=/tmp/tour/00.png --director=res://tools/directors/metagame_tour.gd \
    --warmup=60 --size=1280x720
```

photographs all twelve screens of the loop. Note the **absence** of `--headless`
— there is no rendering device under it, and every frame comes out empty.
