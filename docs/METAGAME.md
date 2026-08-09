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

> ### ⚠ Partly superseded 2026-08-09 — the Descent is finite now
>
> `docs/GDD.md` §5 replaced the endless-only structure with **four authored
> floors, four bosses and an ending**. The endless dungeon is not deleted: it is
> the post-credits **Long Descent** (GDD §8), and every number in §7.1 below is
> still exactly what it does there.
>
> Two things in this file are now incomplete rather than wrong:
>
> - **§7.1 "There is no bottom."** True of the Long Descent, no longer true of
>   the main line. Floors 1–4 are authored anchors over the same generator, and
>   the deepest room's stair is a **boss door** (GDD §5.1).
> - **§4 and §6.5.** A third item class exists: **relics** (GDD §3, §6). They
>   ride in the bag under every rule a component obeys, but they are donated to a
>   fourth counter rather than spent at a bench, and they never sell.
>
> Everything else here — the bag, Heat, the fee, the receipt, the autosave, the
> forge, the alchemist, arrows — is unchanged and remains the design of record.
> **`docs/SCOPE.md` is what decides how much more of any of it gets built.**

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

Eight more items drop from the same tables and share the same bag, but they are
not ingredients and the vendor will not take them: they are **components**, and
they go to a workbench instead of the purse. Four belong to the forge (§6.5) and
four to the alchemist (§6.6). The split is a label on the item, not a second
system — every rule about how a component travels is the same for both benches.

---

## 4.6 Arrows — the only resource with three sources

Arrows live on `Game`, not in the bag. They cost no slot, carry no heat, are
worth no gold, and **survive death** — because they are supply, not merchandise.
Routing them through the bag would put ammunition on the extraction fee and make
a full bag refuse the one pickup an empty quiver most needs.

They arrive three ways, and each answers a different kind of empty:

| Source | Where | What it costs | Answers |
|---|---|---|---|
| **The smith** — `ARROWS X10` | Town (`shop_db.gd`) | 40 gold (4.0/arrow) | a purse, no bag |
| **Found** — `ArrowBundle` | Dungeon floors and chests | a short detour | early, poor, and dry |
| **Fletched** — `Fletching` | The POUCH screen, anywhere | 2 Cracked Flint + 2 Bone Shard → 5 arrows (4.8/arrow) | a full bag, no purse |

**Found**: `arrow_chance` on `Dungeon` puts a 6-arrow bundle on the floor of a
quarter of rooms; `arrow_chance` on `Chest` gives 40% of chests a 10-arrow one
on top of its picks. The chest roll is deliberately **not** an entry on
`ItemDb.CHEST_DROPS` — `_lift()` reweights that table with depth, and arrows
must not get rarer or commoner as you descend. The bow has to keep working at
the same rate on floor eight as on floor one.

A bundle you cannot take because the quiver is full **stays and pulses**, the
same as a refused mote — but it means something different. A refused mote is a
decision you made about slots; a refused bundle is just a thing to come back for
after the next fight.

**Fletched**: this is what makes the bow sustainable underground. Running dry on
floor six used to mean the bow was a decoration until you extracted, and "go home
to reload" is not a decision, it is a walk. The recipe eats the two commonest
ingredients on the enemy table — the two you have most of and were least glad to
see — so the trade is *the floor of my bag, for shots*, which is §5's question
(slots against worth) aimed at a second resource. It also runs the right way
round: fletching **frees slots**, so a nearly-full bag and an empty quiver solve
each other.

Priced above the smith on purpose. Convenience underground is the thing being
sold, and a recipe that undercut the shop would kill the shop line — which is
what a player with gold and no bag is supposed to reach for.

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
the wiring, not a special case. It is the same rule the rope channels under
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

The way out is the **Escape Rope** (`scripts/items/escape_rope.gd`): a
permanent key item, used from the pause menu's **POUCH** screen, under THE WAY
OUT — beside the bag's worth and the purse, because those three numbers are the
decision and they belong on one screen.

**Superseded 2026-08-08, on the owner's instruction: this was a rune pad you
stood on and held (`scripts/world/extract_node.gd`, deleted).** The pad made
leaving a *place*. That is the wrong noun — it turned the game's central
decision into a navigation problem, and a rich run could be lost to not
remembering where the door was. The decision was never "can I find my way back",
it was "is what I am carrying worth the fee".

The rope is **not consumable**. A stock you can run out of would strand a
player underground, and being stranded is the one thing this section rules out
below: you are never trapped. The fee is the price of leaving; the rope is just
where the button lives.

The pad's two real properties survive the move, because everything below is
built on them:

- **Leaving takes time and can be interrupted.** The pad was a *hold* so that a
  decision could not be made by fumbling a button. A menu press has neither
  property on its own — the menu is paused, so a "hold" in there is a slow
  click. So using the rope closes the menu and starts a **1.2 s channel in the
  world**: he is rooted, the ring closes around the bag total, and **a blow that
  lands breaks it**. A blow he *blocks* does not — standing your ground behind
  the shield while the rope works is a legitimate way to leave, and a better one
  than mashing a button was.
- **The fee comes out of the number you are protecting**, and the HUD says so.

It is deliberately **not on any ring**. It is not in `RIGHT_POOL` and it is not a
bottle, so no D-pad direction can ever land on it — one press that ends the run
is precisely the fumble the hold existed to prevent.

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

Extracting also **heals you to full**, and it is the only *free* heal in the
game. That is what makes leaving feel like relief instead of retreat, and it is
what stops a player from farming one safe room forever.

The Heart Draught (§6.6) is the only other way to get health back, and it is
deliberately built so it cannot replace this one: it heals two hearts, not full,
there are at most four bottles, and every one of them was paid for in town
before the run. Healing underground is a **stock you brought with you**, which
is a different decision from leaving — and when the stock is gone, leaving is
still the only answer.

**Death** (`Run.die()`) takes the whole bag and nothing else. Gold and every
upgrade bought with it survive. You wake in town at full health — leaving you at
zero would just kill you again before you could sell.

### Both endings stop and show you the receipt

Either ending — the rope or the killing blow — raises **one** screen over the
floor the run ended on: `RunEndScreen` (`scripts/ui/run_end/`), off
`Bus.run_ended` via `Flow`. It names the floor, what killed you, how many
monsters you killed, and every stack you were carrying priced line by line, with
components marked TO THE BENCH because the vendor will never pay gold for one.
The tree is **paused** under it and the only control on it is BACK TO TOWN; that
button is what calls `Flow.to_town()`, so the ride home is a press and not a
timer.

One screen for both endings, and the death version is the *same list* with a
cross struck through it. That is the whole design: the loss has to be legible as
the specific things you decided to keep carrying — the deep amber you went one
room too far for — and not as a number going to zero. Two screens would have
been two places for the loot list and the arithmetic to drift apart, and would
have made the two endings read as different games instead of two outcomes of one
decision.

It also replaced a `Label3D` in the town yard that had never once been visible
(it sat about sixty degrees above the arrival camera's view centre), and a ride
home on a timer that ended the run in a room the player never got to look at. A
run that ends underground says so underground.

### The run is not savable, and that is what the autosave protects

`Flow` autosaves on **every** scene transition — entering the dungeon, taking
the stair down, and coming home whether you walked out or were carried — and the
HUD says **AUTOSAVING…** bottom-right as the world fades back in.

What it writes is `Game`: gold, hearts, upgrades, forge rungs, key items. What
it never writes is `Run`: no bag, no floor, no run seed, no `in_dungeon`. A save
you could reload from the third floor would let a player undo the extraction
decision this whole section is built on, and the fee would stop being a
decision — so `save()` records **town** as the scene whenever `Run.in_dungeon`.

So the autosave is not a safety net under the run. It is a safety net under the
*metagame*: everything the run was being gambled **for** is committed to disk at
the exact four moments it changes hands, and the gamble itself still resolves
the way you played it.

An autosave will never overwrite a save you made by hand — it takes the slot you
are already playing, or the first empty one, or it declines and says nothing
(`save_game.gd autosave()`).

---

## 6. The town

One walled courtyard (`scripts/world/town.gd`) with four things in it.

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
- **The alchemist.** Four lines (`scripts/items/alchemy_db.gd`): one bottle and
  three things to put in it. Same transaction as the forge — gold **and**
  materials — over the same kind of counter, driven by the same screen. She is
  §6.6.
- **The gate.** Into the dungeon, and back out again on the arrival pad.

The vendor and the smith share the far wall either side of the gate, because
they are the two counters you visit with a full bag. The alchemist stands nearer
the arrival spot: what she sells is spent on the way back *down*, and the frame
you see when you extract has to contain her or she does not exist.

The costs scale with how many you have already bought, so the shop keeps pace
instead of being solved by one lucky run. The limits are what stop the smith
from being an infinite gold sink that makes the dungeon irrelevant.

### What is held, and what is tapped

**A commit that eats materials is held for half a second; everything else is one
press.** Forging a rung, blowing a bottle, brewing a draught and SELL EVERYTHING
are the four, and they share one reason: gold is grindable and a single row is
re-buyable, but a Cold Iron Core is a thing you *found* (§6.5) and a bag is one
press from empty. Spending either because the cursor sat a row from where you
thought it did is the only shop mistake this game cannot give back.

Arrows, a bag slot, a heart container and selling one stack stay taps. A hold on
every line would be ceremony, and a player who holds through twelve harmless
confirms has stopped reading the one that mattered.

The held rows say so twice — `HOLD ENT TO FORGE` in the footer, and a gauge
filling along the row (docs/CONTRACT.md §8, "Holds"). The word and the bar are
one statement in two languages, and this project has shipped the bug that each
one alone leaves behind.

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

### The forge's four components

They live in `scripts/items/item_db.gd` alongside the ingredients and share the
bag with them, but they are `ItemDef.Kind.COMPONENT`, and everything downstream
branches on that one bit: the pouch marks them ◆, the vendor's "sell everything"
leaves them alone, and extraction moves them to the workbench instead of the
purse.

The alchemist's four (§6.6) are the same kind and obey every one of those rules.
What separates them is `ItemDef.bench`, a label the item carries so the pouch can
tell you which counter wants it. `ItemDb.components(bench)` filters on it; an
unfiltered `components()` is all eight, and code that means "the forge's" must
say so.

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

The right column also carries the screen's two **verbs**, in the order they
argue: the **fletching bench** (§4.6) and then the **escape rope** (§5).
Both spend the bag; one spends it on staying in and the other on getting out.
Neither is a verb on an item — a *cell* still does nothing when you press it,
because there is nothing you can do to one thing in the bag. These act on the
bag as a whole, which is why they are cards beside the grid and not entries in
it, and why the bench is here rather than at the smith: the recipe eats the
cheapest two things in the grid to its left, so the price and the stock are the
same picture.

It is a separate screen from **Items**, which is what you are *holding* and what
the D-pad cycles. Carrying and holding are different questions and a player who
conflates them is a player who thinks the bag can be equipped.

---

## 6.6 The alchemist — the only thing you take down with you

*Numbered 6.6 for the same reason §6.5 is 6.5. Do not renumber.*

The forge sells **permanence**: you buy a rung and it is yours. The alchemist
sells a **stock** — four glass bottles, and what is in them at the moment you
step through the gate. Everything below follows from that one difference.

The transaction is the same as the smith's, deliberately: **gold and materials,
over a counter**. `scripts/items/alchemy_db.gd` and `scripts/items/shop_db.gd`
are both `Catalogue` subclasses — the contract is a base class now rather than a
promise in a comment (docs/CONTRACT.md §8) — and `TradeScreen` holds whichever
one it was opened with. There is one shop screen in this game and there will go
on being one; a second would be a second place for the recipe column, the
affordability colours and the refusal footer to drift apart. **A third counter
is a `Catalogue` subclass and a row in `Npc.COUNTERS`, nothing else.**

### The bottle

| | |
|---|---|
| Start with | **1** (`K.BOTTLE_START`, `[test]`) |
| Ceiling | **4** (`K.BOTTLE_MAX`) |
| Gold | 110, ×2.4 per bottle already owned |
| Glass | 4 Cullet → 8 Cullet + 2 Resin → 14 Cullet + 1 Dew |

The first bottle is granted at boot so the brew lines are reachable before you
have found any glass; it is tagged `[test]` in `game_state.gd` and it comes out
when the game has a tutorial. The other three are earned, and the **fourth wants
Mourning Dew, which never falls off a body** — the same pacing gate the Cold Iron
Core is, for the same reason.

`Game.bottle_contents` is the whole model: **the array's size is how many
bottles there are** and each element is what is in that one, `&""` for empty.
There is no separate count to disagree with it. Bottles are a RING: D-pad ↓ steps
the selection (`Game.cycle_item`, empties included, so the ring's length never
changes under you) and **X drinks** the selected one (`Game.use_selected_item`).
A bottle is used, never drawn — the one thing in the cluster that behaves that
way, which is why the Items screen says so in words.

### The three draughts

`scripts/items/potion_db.gd`. Every number below is generated from `K`, so the
shop's own description of what a draught does cannot drift from what it does.

| Draught | Gold | Materials | Effect |
|---|---|---|---|
| Heart Draught | 55 | 3 Root | +2 hearts, at once |
| Ironhide Draught | 85 | 2 Resin + 2 Root | −2 quarters off every blow, 45 s |
| Emberblood Draught | 95 | 3 Resin | +2 quarters a swing, 45 s |

The two that last are folded into `Game.sword_bonus()` and `Game.armour_soak()`
— the same accessors the forge's ladders feed. Nothing downstream needed a line
of code: the swing, the enemy's health bar, the hero's own `hurt`, and the
smith's before/after text all picked the draught up for free. Ironhide cannot
become immunity because `Hero.hurt` floors damage at one quarter.

Prices are **flat**, unlike the smith's, because a draught is gone by the next
room and the tenth one costing more than the first is nonsense. What limits
brewing is not price — it is the four slots and what the floor gave you.

### The four materials

| Material | Value | Rarity | Stack | Drops from |
|---|---|---|---|---|
| Fired Cullet | 12 | common | 8 | bodies and chests |
| Bitter Root | 16 | common | 8 | bodies and chests |
| Ash Resin | 25 | uncommon | 6 | bodies and chests |
| Mourning Dew | 85 | rare | 2 | **chests only** |

Read `AlchemyDb.BREW_PARTS` by column: root is the cheap tax on the heal, and
**resin is what both lasting draughts are made of** — so a run that found resin
is a run that gets to choose between offence and defence, rather than one that
is handed both.

They ride home exactly as the forge's do: motes on the floor, picked up by
walking over them, taking bag slots, charged the extraction fee, banked to
`Game.components` on the way out and **lost with the bag on death**. One
workbench, two counters spending from it.

### What the HUD says

The selected bottle draws in the cluster's third cell — body, neck, lip — with
the draught's colour filling the lower two-thirds, and an outline only when it is
empty. A live draught adds a draining bar to the health/stamina/heat column, in
the potion's own colour, because it is the same kind of fact as the bars above
it: true now, and shortly not. Nothing is drawn when nothing is running.

Bottles and their contents are in the save file (`VERSION = 3`). The draught
clocks are **not**: a 45-second buff that survives quitting is a buff you can
bank, and the point of the timer is that it is spent in the room you drank it in.

---

## 7. The dungeon

A seeded room graph (`scripts/world/dungeon.gd`) built from the P6 kit at run
time: rooms, connecting corridors, torches in pools with dark between them,
enemies scattered on a ring so a group is not one clump you can clear with a
single swing, chests carrying the richer rolls, and bundles of arrows on a
quarter of the floors (§4.6).

Chests are `treasure_chest.glb` — authored art, not the six-box version that
preceded it, which read as a crate. The lid is a separate node hinged on the
chest's own back edge, which is what makes it a chest rather than a barrel: it
opens where a lid opens. The gold seam of light at the lid line is still built
in code, and it is still the whole "there is something in here" read — no
floating icon, no beam, no exclamation mark.

Every enemy is an `Enemy` (`scripts/actors/enemies/enemy.gd`) driven by one of
the monster models, shallow rooms included: see you, close, **rear back and
hold**, swing, recover. That telegraph is the entire fight — it is the
window to block, roll, or hit first — and it is why an enemy this simple is
still a fight rather than a health tax. A pack keeps itself spread out, circles
rather than stacking, and gives up and walks home if you leave — which is what
makes disengaging a real option and therefore what makes the rope's channel
survivable.

### 7.1 Going deeper

The deepest room of every floor holds the best chest and, beside it, **the way
down** (`scripts/world/stairs.gd`) — a lit pit with a `DESCEND` prompt. Taking
it keeps everything: the same bag, the same health, the same fee climbing. It
banks nothing and heals nothing. The only way to bank is to go home, and the
stair is deliberately placed at the end of the longest walk, next to the reward,
so the moment you *can* go deeper is the moment you have the most to lose.

There is no bottom — **in the Long Descent**. On floors 1–4 the deepest room's
stair is behind a boss door, and the floor's manifest fixes the room count, the
band table and the tint (GDD §5.1). The mechanism below is the same one; only
the ceiling changed.

`Flow.descend()` reloads the same dungeon scene with
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
| The end-of-run receipt, both endings | `scripts/ui/run_end/run_end_screen.gd` |
| Ingredients, components and drop tables | `scripts/items/item_db.gd` |
| The smith's catalogue, and the forge recipes | `scripts/items/shop_db.gd` |
| The alchemist's catalogue, and the brew recipes | `scripts/items/alchemy_db.gd` |
| What a draught is called and what it does | `scripts/items/potion_db.gd` |
| Bottles, their contents and the draught clocks | `scripts/autoload/game_state.gd` |
| The upgrade ladders, rung by rung | `scripts/core/consts.gd` (`K.EDGE_DAMAGE` …) |
| The difficulty curve, every floor of it | `scripts/core/progression.gd` |
| The way down | `scripts/world/stairs.gd` |
| The pouch — the bag, drawn as slots | `scripts/ui/menu/pouch_panel.gd` |
| Vendor / smith screen | `scripts/ui/shop/trade_screen.gd` |
| HUD | `scripts/ui/hud/hud.gd` |
| Town | `scripts/world/town.gd`, `scenes/rooms/town.tscn` |
| Dungeon | `scripts/world/dungeon.gd`, `scenes/rooms/dungeon.tscn` |
| The way out | `scripts/items/escape_rope.gd` |
| Drops on the floor, and their heat stamp | `scripts/world/loot_mote.gd` |
| The chain, its tiers and what they are worth | `scripts/autoload/heat.gd` |
| Chests — the model, the lid, what comes out | `scripts/world/chest.gd` |
| Arrows on the floor, and the pickup | `scripts/world/arrow_bundle.gd` |
| The fletching recipe, and its refusals | `scripts/items/fletching.gd` |

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
pick up a drop → open a chest → **channel the rope** → home. It prints the gold,
bag and health it observed at each seam, and prints `MVP FAIL …` if a beat did not
happen. Last run:

```
MVP after_sell  gold=346 bag=0
MVP after_buy   gold=206 slots=13
MVP descended   in_dungeon=true  rooms=6 enemies=17
MVP after_chest bag=4 value=95 fee=24
MVP home        scene=Town in_dungeon=false gold=182 bag=95 hearts=12/12
```

Arrows have two, because the supply chain has two halves — the objects, and the
floor that has to contain them (§4.6):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/arrow_supply.gd --out=/tmp/arrows/x.png --warmup=60
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/dungeon.tscn --director=res://tools/directors/dungeon_supply.gd --out=/tmp/dun/d.png --warmup=60
godot --path . -s tools/shoot.gd -- --scene=res://scenes/ui/menu/_menu_test.tscn --director=res://tools/directors/fletch_screen.gd --out=/tmp/fletch/f.png --warmup=50
```

`arrow_supply.gd` opens a chest and photographs the lid, measures the chest and
the arrow against the sizes §2 of `docs/CONTRACT.md` promises, walks a body onto
a bundle, and checks that a full quiver refuses **without** eating the bag.
`dungeon_supply.gd` generates eight floors and counts what landed in the rooms,
because a 25% roll cannot be judged from one floor. `fletch_screen.gd` drives
the POUCH card and walks the D-pad down it, because a new card between the grid
and the rope is exactly the change that orphans the way out. Last runs:

```
SIZE chest extent=1.15m        SIZE arrow extent=0.68m
CHEST bundle count=10          CHEST pickup +10 arrows (quiver 10)
FULL quiver refused the bundle and it stayed on the floor
BENCH full quiver refused and the bag was untouched
TOTAL rooms=48 chests=25 bundles=11 loose_arrows=66
RATE bundles/room=0.23 (arrow_chance=0.25)
FOCUS walk reached [Cell_0, Cell_4, Cell_8, Fletch, Rope]
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

The autosave has one too (§5):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/autosave.gd --out=/tmp/save/x.png --warmup=60
```

It drives all three transitions and asserts a slot was written each time, that
every one of those saves points at **town** rather than at the floor it was
taken on, and that with all three slots full of hand-made saves the autosave
declines and the HUD stays quiet. It photographs the notice as the world comes
back. It backs up the three real slots and puts them back, so running it cannot
cost you a save.

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
FORGE pouch frame=1060x772 viewport=1280x720
FORGE FAIL B4 the pouch frame fits on the screen
FORGE FAIL -- 1 check(s) failed
```

**B4 is red and it is a real bug, not a flaky check.** The POUCH frame is 52 px
taller than the screen, so the Back button and the bottom of the WORKBENCH card
render past the edge. It is not the alchemist's doing — three runs on `main`
before this branch existed fail it at exactly the same 1060x772 — and the
suspect is the fourth section the right column grew, THE WAY OUT. It has its own
card. Everything else in the director is green, and the line stays printed here
rather than quietly re-run until it passes.

The alchemist has hers (§6.6):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/alchemy_loop.gd --out=/tmp/alchemy/x.png --warmup=60
```

It reads the catalogue, opens her board, is refused a draught for want of root
and then for want of an empty bottle, brews into the one bottle he starts with,
blows glass up to the ceiling, steps the bottle ring with D-pad ↓ (proving it
wraps back to where it started) and **drinks with X**, watching health and the two accessors the gear reads
move and then expire, descends, sweeps three materials off the floor with
nothing pressed, extracts to prove they bank, and saves/wipes/reloads to prove
the glass and what is in it survive quitting. `ALCHEMY FAIL …` on any claim that
did not hold. Last run:

```
ALCHEMY brewed   bottles=[heart_draught] gold=40000 -> 39945 root=40 -> 37
ALCHEMY bottles=4 contents=[heart_draught, "", "", ""]
ALCHEMY drank heart quarters=2 -> 10 bottle0=
ALCHEMY draughts=[ironhide, emberblood] edge=+0 -> +2 soak=-0 -> -2
ALCHEMY expired  edge=+0 soak=-0
ALCHEMY home     bench={cullet:1 root:1 resin:1} bag={}
ALCHEMY reloaded [heart_draught, "", "", ""]
ALCHEMY OK
```

Three of its frames are the whole reason it takes them. `a_04b_equip.png` is
where a bottle's name was found printing across its neighbours' cards;
`a_06_column.png` is the dungeon HUD stack — health, stamina, heat, then the
draughts — where the first version of that row was found drawn **on top of the
stamina bar** with every check in the run green; and `a_04a_pouch.png` is where
the WORKBENCH list was found running off the bottom of the screen once the
alchemist's four materials joined the forge's four, which is why that list is
two columns now. A rectangle in the wrong place is not a thing an assertion can
see.

One trap worth naming, because both these directors fell in it and the symptom
blamed the wrong system. `game_flow.gd` autosaves at the **end** of a
transition, after the fade in — so a beat that waits a fixed number of frames
after `Run.die()` or `Run.extract()` can return while that autosave is still
coming. The save beat then calls `Saves.save(2)`, which makes 2 the active slot,
and the late autosave lands *there*. Arrive after the beat's `Game.reset()` and
the slot holds the wiped state: the reload checks fail and every sentence in
them blames the save format. Wait for `Flow.busy` to clear, the way
`autosave.gd`'s `_settle` does. A fixed frame count only moves the odds.

**Do not pass `--headless`.** There is no rendering device in headless mode and
every frame comes out empty.
