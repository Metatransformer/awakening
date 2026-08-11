# The metagame

Moonlighter's structure on OOT's feel. The dungeon is where you take risk; the
garrison is where you turn it into permanence. Everything below is the design of
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
        garrison                            dungeon
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

### What the trip resets, and what it does not

Three things are budgeted per TRIP rather than per second, and the arrow back to
the garrison is the only thing that refills them: the **bottles** you bought
before you left (§6.6), the **arrows** in the pouch (§4.6), and the **magic** the
charged spin is priced in (`K.MAX_MAGIC` 48, `K.MAGIC_SPIN` 12 — four spins).
`RunState.enter/extract/die` fill the blue bar; **descending a floor does not**,
because taking the stair is the same trip getting longer, and that is the trade
the stair is there to offer.

Stamina is the counter-example and the reason the distinction is worth naming: it
comes back on its own, in seconds, so it prices the next *dodge*. A per-trip
budget prices the next *room*. Nothing underground tops the blue bar up — there
is no font, no drop and no draught for it, and `GameState` has no partial-restore
API to hang one off.

---

## 2. Gold, and the two things that hold value

There is one currency: **gold**. Two containers hold value, and they behave
differently on death, which is the entire tension.

| | Survives death | Where it lives |
|---|---|---|
| **Gold** | yes | `Game.gold` (`scripts/autoload/game_state.gd`) |
| **The bag** | **no** | `Run.bag` (`scripts/autoload/run_state.gd`) |
| **The document case** | yes | `Run.cased` — three of the bag's slots (GDD §3.1) |
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
deliberate reward rather than disappearing. **Four is the whole ladder**
(`ShopDb.LIMITS[&"bag_slot"]`), so the biggest bag that can exist on any save,
ever, is **16 slots** — three of which are the document case (§5) and are counted
separately, which matters below.

## 3.1 What the bag is worth, floor by floor — and what a tier means

> **Decided 2026-08-11 (card #49). This is a session's call, made while the repo
> owner was asleep, and it is REVERSIBLE**: the change is one constant, `Pal.T3`
> in `scripts/ui/style.gd`, from `3000` to `2000`, and the frame that proves it
> re-shoots in three minutes (`tools/directors/hud_lookdev.gd`, beat `h_09_t3`).
> If the owner disagrees, put `3000` back; nothing else in the economy reads it.

The HUD reads the bag through three thresholds — `Pal.T1/T2/T3` and `Pal.tier()`
in `scripts/ui/style.gd` — and they drive real behaviour, not just a colour. Two
things, exactly, both in `scripts/ui/hud/hud.gd`: **at T2** a dithered GOLD halo
one ring outboard of the bag rim (`_draw_rim`), and **at T3** a 0.5 Hz brightness
breath over the whole slip stack (`_draw_slips`), which is also the one thing on
this HUD that holds `busy` and keeps it repainting frame by frame. Card #49's own
description — "the fog lerp" — is wrong; nothing in the renderer reads
`Pal.tier`, and `docs/HUD_PLAN.md` decision 33 ranks the two effects above as the
T2 and T3 rungs of the rim's precedence ladder.

Until this section existed **nothing said what a tier was meant to represent**,
which is why nobody noticed that T3 was set to a number the game does not
produce.

**A tier is a floor of the Descent.** Each threshold sits at roughly the median
bag a player is holding when they take a stair:

| Tier | Bag value | What it says | Where a run crosses it |
|---|---|---|---|
| T0 | under 250 | pocket change — under 60 the fee is still the `EXTRACT_MIN` floor of 15 | the first rooms |
| **T1** | **250** | a floor's worth. Worth the walk home. | partway through floor 1 (median at the stair: 351) |
| **T2** | **1000** | two floors' worth. The run is worth protecting now. | the end of floor 2 (median 1052) |
| **T3** | **2000** | the deep half. More than you can afford to lose. | the end of floor 3 on a bought bag (median 2068), or floor 4 (median 2239 for a player who chose what to carry) |

### The curve those numbers are read off

`tools/bag_curve.gd` is the evidence and it is re-runnable —
`godot --path . --headless -s tools/bag_curve.gd`, no GPU, about ten seconds. It
does not build a dungeon; it rebuilds the *counts* one produces (`FloorDb.rooms`
/ `pack` / `roster`, `Dungeon.chest_chance` 0.55, `Prog.chest_picks`,
`Prog.drop_rolls`, `Enemy.DEFS` health), rolls them through the real
`ItemDb.roll` tables, and pushes every mote through the real `Run.collect` — so
the slot arithmetic is the shipped one, case-first and all. 400 seeds, bag
carried down all four floors because the stair carries it.

Three readings, because one would hide the argument. **SWEPT** is a player who
walks over everything: their bag fills with whatever fell first and then refuses
the good stuff, and since there is no drop verb that is a real ceiling for them,
not a strawman. **BEST** is the best selection of slots out of everything that
fell on floors 1..N — nobody plays that well, it needs foresight about which
motes to step around, so it is an upper bound on careful play. **HOT** is BEST
plus the heat premium a strong chain stamps on body loot (§4.5), modelled at a
generous ×1.4 sustained.

Bag value at the moment the stair is taken, median across 400 seeds:

| | floor 1 | floor 2 | floor 3 | floor 4 |
|---|---|---|---|---|
| **12 slots** — swept | 351 | 1052 | 1611 | 1795 |
| **12 slots** — careful | 356 | 1141 | 1782 | 2239 |
| **12 slots** — careful + hot | 420 | 1426 | 2292 | 2829 |
| **16 slots** — swept | 359 | 1287 | 2068 | 2372 |
| **16 slots** — careful | 359 | 1307 | 2172 | 2792 |
| **16 slots** — careful + hot | 422 | 1634 | 2788 | 3560 |

Two things fall out of that table and they are the whole of the decision.

**The top of the ladder has to be out of reach on the shallow half, and 2000
is.** Floor 1 never approaches it — the best bag in 400 seeds was 746. Floor 2's
*median* is 1052 on a starting bag and 1287 on a bought one, and its 90th
percentile is 1596 / 1862; only the extreme tail touches T3 at all, and that tail
is a specific run — a maxed sixteen-slot save that held a chain across the whole
floor, topping out at 2177. A player who did that is carrying more than the floor
usually gives up and the breath is not a lie about them. Put T3 anywhere lower
and it stops being the deep half; the next round number down, 1500, is inside
floor 2's ordinary spread.

**And the deep half sits squarely on either side of it**, which is what makes
2000 a threshold rather than a wall: the sweeper who took every Bone Shard on the
way down ends floor 4 at 1795 and does *not* get the breath; the same run played
with §3's pressure respected ends at 2239 and does. T3 is therefore a statement
about how you filled the bag as well as how far down you went — which is the
question §3 exists to ask.

### Why 3000 was unreachable, and why the reason matters

Card #49 reported the ceiling of a starting bag as 3960 — twelve slots of Deep
Amber at 55 × 6 — and concluded that "the best bag in the game barely clears
3000". **The arithmetic is right and the conclusion is the wrong shape**, in both
directions, which is worth writing down because the corrected version is a
stronger argument:

- The best bag in the game is not twelve slots, it is **sixteen** (above), whose
  Deep Amber ceiling is 5280. T3 was never "barely clearable".
- But a monoculture ceiling is not evidence about anything. 3960 needs
  **seventy-two Deep Amber**, which drop from chests at weight 12 of 166 — about
  0.5 per floor. The number that bounds real play is the best *distinct* stacks a
  bag can hold, and `bag_curve.gd` prints it: **2782 for twelve slots, 3312 for
  sixteen**. So a starting bag could not reach a T3 of 3000 **at all**, by any
  route the drop tables can supply, and a fully bought one had to be filled
  almost perfectly. That is a harder failure than "barely clears it".

The behaviour behind T3 was therefore dead code for every player who had not
bought four bag slots, and close to it for those who had. The alternative
resolution — declare the thresholds to be about a late bag and say so in the
docs — was considered and rejected: it would leave the game's top HUD state
gated on a shop purchase rather than on the run, and a rung the player reaches by
*shopping* is not a reading of the bag. The number moved instead.

`Pal.T1` and `Pal.T2` are unchanged. They were already sitting where the measured
curve puts them (T1 under floor 1's 351, T2 on floor 2's 1052), which is the
other half of why only T3 moved.

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
| **The smith** — `ARROWS X10` | Garrison (`shop_db.gd`) | 40 gold (4.0/arrow) | a purse, no bag |
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
  decision could not be made by fumbling a button *and* so that something
  chasing you was a real problem. Those are two guarantees, and only one of them
  can be kept inside a paused menu, so the rope keeps them in two places.
  - **The channel, in the world.** Using the rope closes the menu and starts a
    **1.2 s channel**: he is rooted, the ring closes around the bag total, and
    **a blow that lands breaks it**. A blow he *blocks* does not — standing your
    ground behind the shield while the rope works is a legitimate way to leave,
    and a better one than mashing a button was.
  - **The hold, in the menu.** The POUCH row does not fire on A. It is **held on
    Y (`ui_hold`) for 0.9 s**, anywhere on that screen, with the same gauge every
    other hold in the game draws (`HoldGauge`). That is the fumble guard, and it
    is on a different button from the A that fletches arrows one row above it —
    the accident being prevented is the press you make while reading something
    else. A on the row says "Hold Y" rather than doing nothing, because a control
    that ignores the universal confirm is a control that gets filed as broken.
- **The fee comes out of the number you are protecting**, and the HUD says so.

It is deliberately **not on any ring**. It is not in `RIGHT_POOL` and it is not a
bottle, so no D-pad direction can ever land on it — one press that ends the run
is precisely the fumble the hold existed to prevent.

```
toll   = max(15, round(bag_value × 0.25))
charge = min(toll, gold)          # what actually leaves the purse
```

`EXTRACT_MIN = 15`, `EXTRACT_RATE = 0.25` (`scripts/autoload/run_state.gd`).

The fee is a **share of what you are carrying**, not a flat toll and not a
function of depth. Three consequences, all intended:

- A poor run is cheap to abandon. You are never trapped by your own poverty.
- A rich run costs real money to bank — the greed curve bends but never breaks.
- **The toll can never exceed your gold.** `Run.extract_charge()` caps it there,
  so a bag worth more than your purse takes *all* of it and the rope still works.
  You walk into the garrison with the haul and nothing else, and now you have to sell it.

### The cap, and why it replaced a refusal — 2026-08-09

Until this date the third bullet read the other way: `can_extract()` gated on
`Game.gold >= cost` and the rope refused below it, on the theory that being too
poor to leave was "a legible failure state rather than a soft-lock". **It was a
soft-lock.** The `mvp_loop` director found it on any seed that rolled a rich bag:

```
MVP pre_extract gold=26 fee=36 value=145
MVP FAIL the rope refused to start
MVP FAIL no ending screen after the rope
```

Read what that state actually offers a player. The fee rises with the bag and
falls with nothing — **there is no shop underground**, so a bag you cannot afford
to carry out is one you can only make heavier. Dropping loot is not implemented
and would not be a fix if it were: the point of the fee is that the haul is what
you pay for, and shedding it to make the toll payable means the fee no longer
prices anything. The only exit left is dying, which destroys the entire bag the
toll was charged against. So the refusal punished exactly one player — the one
having the best run of the night — and offered them nothing to do about it.

Four rules were considered. The owner picked the cap:

| Rule | Why not |
|---|---|
| **Cap the fee at your gold** ✅ | Chosen. Costs everything, forfeits nothing, always resolves. |
| Forfeit loot to cover the shortfall | The fee stops pricing the haul once the haul can pay it. |
| Extract into debt | A second currency and a second screen, to model a bank the game does not have. |
| Drop items to lower the fee | Turns the decision into inventory sudoku at the exit, and needs a drop UI. |

**What the cap costs the design, honestly:** past the point where the toll meets
the purse, the greed curve *flattens* — extra loot is free to carry home. That is
a real softening and it is the price of never dead-ending. It is bounded, though,
and the bound is the interesting part: reaching that point means you leave with
**zero gold**, so the next run starts with no smith, no arrows, no bag slots, and
a bag you must sell before you can do anything at all. The pressure moved from
"can I leave" to "what does leaving leave me with", and only the second one is a
decision the player can act on.

**What the player sees**, because a dead end with no feedback was the worst part:

- **The HUD says it once, not continuously.** There is no `EXTRACT <charge>`
  line in the corner — a standing figure gets read constantly, and a player
  watching the fee tick is doing bookkeeping in a dungeon instead of playing
  one. What fires instead is the screen-wide CYAN sweep, at the moment the toll
  eats the purse (`Hud.set_extract_dear`). That moment is *usually* once per run
  and stays — nothing sells underground, so the purse cannot grow — but fletching
  (§4.6) burns real value out of the bag, so the toll can fall back under the
  purse and the sweep fire again when the bag climbs back. That is intended: the
  fact it announces really did change back.
- The POUCH row says it in words: *"The rope wants 36 and you have 26. It will
  take all of it."* The hold gauge stays drawn under it, because the hold works.
- `Bus.extract_refused` is **deleted**, along with the HUD's `NEED n` flash and
  its `craft_fail` cue. No code can reach that state, and a signal that cannot
  fire reads to the next agent as a failure state the game still has.

Proof: `tools/directors/mvp_loop.gd`, which now spends the purse down to one gold
under the toll before using the rope, so the expensive exit is exercised on every
seed instead of on the unlucky ones.

Extracting also **heals you to full**, and it is the only *free* heal in the
game. That is what makes leaving feel like relief instead of retreat, and it is
what stops a player from farming one safe room forever.

The Heart Draught (§6.6) is the only other way to get health back, and it is
deliberately built so it cannot replace this one: it heals two hearts, not full,
there are at most four bottles, and every one of them was paid for in the
garrison before the run. Healing underground is a **stock you brought with
you**, which is a different decision from leaving — and when the stock is gone,
leaving is still the only answer.

**Death** (`Run.die()`) takes the bag **except the document case** and nothing
else. Gold and every upgrade bought with it survive. You wake in the garrison at
full health — leaving you at zero would just kill you again before you could
sell.

The case is `Run.CASE_SLOTS = 3` of the twelve (GDD §3.1). What is in it is
banked exactly as an extraction banks it — components to the bench, the rest to
the vendor's stock — and the fee is *not* charged on it, because you did not
buy a ride home. What is in the other nine is gone. `Run.die()` is also the only
place that counts a death: `Game.deaths += 1`, which is the dial §7.1 turns, and
it is counted here rather than off `Bus.player_died` because that signal fires
for a death in the garrison too.

### Both endings stop and show you the receipt

Either ending — the rope or the killing blow — raises **one** screen over the
floor the run ended on: `RunEndScreen` (`scripts/ui/run_end/`), off
`Bus.run_ended` via `Flow`. It names the floor, what killed you, how many
monsters you killed, and every stack you were carrying priced line by line, with
components marked TO THE BENCH because the vendor will never pay gold for one.
The tree is **paused** under it and the only control on it is BACK TO THE
GARRISON; that button is what calls `Flow.to_garrison()`, so the ride home is a
press and not a timer.

One screen for both endings, and the death version is the *same list* with a
cross struck through it. That is the whole design: the loss has to be legible as
the specific things you decided to keep carrying — the deep amber you went one
room too far for — and not as a number going to zero. Two screens would have
been two places for the loot list and the arithmetic to drift apart, and would
have made the two endings read as different games instead of two outcomes of one
decision.

**A death draws two columns** (2026-08-10, with the case): WHAT THE FLOOR KEPT,
struck through, beside THE CASE BROUGHT HOME in cyan, and the total block gains
a CAME HOME line under LOST. The extraction keeps its one column, because on the
way out there is no line to draw — everything came back. Two columns is what
makes the case a *decision the receipt reports on* rather than a rule the player
is told about: the three stacks on the right are the ones they chose, sitting
next to the nine they chose against.

It also replaced a `Label3D` in the garrison yard that had never once been
visible (it sat about sixty degrees above the arrival camera's view centre), and
a ride home on a timer that ended the run in a room the player never got to look
at. A run that ends underground says so underground.

### The run is not savable, and that is what the autosave protects

`Flow` autosaves on **every** scene transition — entering the dungeon, taking
the stair down, and coming home whether you walked out or were carried — and the
HUD says **AUTOSAVING…** bottom-right as the world fades back in.

What it writes is `Game`: gold, hearts, upgrades, forge rungs, key items. What
it never writes is `Run`: no bag, no floor, no run seed, no `in_dungeon`. A save
you could reload from the third floor would let a player undo the extraction
decision this whole section is built on, and the fee would stop being a decision
— so `save()` records **garrison** as the scene whenever `Run.in_dungeon`.

So the autosave is not a safety net under the run. It is a safety net under the
*metagame*: everything the run was being gambled **for** is committed to disk at
the exact four moments it changes hands, and the gamble itself still resolves
the way you played it.

An autosave will never overwrite a save you made by hand — it takes the slot you
are already playing, or the first empty one, or it declines and says nothing
(`save_game.gd autosave()`).

**There is a fifth moment, and it is the bed.** Everything the player does *in
garrison* — the selling, the forging, the brewing, the gem-setting, the stashing
— happens between transitions and is therefore on nobody's disk until the next
one. Sleeping in the hero's quarters calls the same `Saves.autosave()` by hand.
It is §6.8, and it is the only autosave a player asks for rather than receives.

---

## 6. The garrison

One walled courtyard (`scripts/world/garrison.gd`) with five counters and a gate
in it.

### Who is in it, and when

**A new save's yard is two people and a hole.** Aldric — the elder, who is also
the Lanternkeeper — and Kessa at the quartermaster's stall. The other three arrive
as you dig, in the order their counters become worth anything (`StoryDb.UNLOCKS`,
owner's call 2026-08-10):

| Who | Arrives after | Because |
|---|---|---|
| Aldric, the Lanternkeeper | — | he sent for you |
| Kessa, the quartermaster | — | you cannot bank a run without her |
| Brannoc, the smith | 1 boss | the forge eats components you do not have on day one |
| Ysolt, the alchemist | 2 bosses | a draught prices a deep run, and there are none yet |
| Marisel, the jewelcrafter | 3 bosses | §6.7's ceiling means nothing before the plate has cost you something |

A keeper who has not arrived **is not in the yard at all** — no booth, no lamp,
no sign. The alternative, five people standing there with three counters refusing
to open, was rejected: it makes an outpost that is visibly finished on the first
frame, and it turns the reward for a boss into a shop that stops saying no. A
trader walking in is the only pacing the garrison has.

Arrival **latches** to a flag the first time the metric is met, so nobody can
un-arrive. `tools/directors/roster.gd` is the proof, and it is the one director
run with `--fresh` — every other one gets all five counters from `shoot.gd`.

### What the counters say

Talking is not the same as trading. TALK opens a dialogue box; the counter is one
option inside it (`docs/CONTRACT.md`, *Dialogue*). What a person says grows with
the save: `StoryDb` holds an ordered run of once-only **beats** per person and a
list of repeatable **topics** you can ask about, gated on two numbers and nothing
else — how many of the four bosses are dead, and `Game.gold_earned`, the LIFETIME
total. Lifetime and not the purse, so that buying a sharpening cannot take one of
Aldric's stories back off you.

Aldric's first beat is the game's only briefing: what the outpost is (a mining
expedition sworn jointly to the Crown and the Explorer's Guild of Valenfeld),
what is below it, that Kessa buys, that the footlocker at the foot of the bed is
the only thing your pack does not eat (§6.8), and what happened to the cadet
before you. It is stapled to his "I've been expecting you" so a player who walks
straight to the gate still gets it.

- **The vendor.** Sells nothing; buys everything. The trade screen
  (`scripts/ui/shop/trade_screen.gd`) lists the bag sorted by value with a
  "sell everything" line, because the common case is dumping the lot and the UI
  should not make that tedious.
- **The smith.** Fifteen permanent lines (`scripts/items/shop_db.gd`), priced
  against the drop tables — a good run extracts with roughly 250–450 gold of
  ingredients, so cheap lines land after one run and dear ones after two or
  three.

  | Line | Base cost | Growth | Limit | Also costs |
  |---|---|---|---|---|
  | Arrows ×10 | 40 | — | unlimited | — |
  | Bag slot | 140 | ×1.6 | 4 | — |
  | Heart container | 320 | ×1.5 | 3 | — |
  | Sharpen the blade | 120 | ×2.1 | 3 | components |
  | Chest/legs/arms/boots — heavy | 65 | ×1.9 | 3 each | components |
  | Chest/legs/arms/boots — light | 35 | ×1.8 | 3 each | components |
  | Bind the shield | 110 | ×2.2 | 3 | components |
  | String the bow | 130 | ×2.1 | 3 | components |
  | Lengthen the chain | 150 | ×2.1 | 3 | components |

  The top three are stock: things the smith HAS, and money is the whole
  transaction. The rest are the **forge** (§6.5) and gold alone will not buy
  them. **There is no armourer** — the plate ladder is the armour system, and it
  is the smith's.

  Every line changes a number the player can feel inside one run. Nothing here
  is a stat-stick you have to take on faith.
- **The alchemist.** Four lines (`scripts/items/alchemy_db.gd`): one bottle and
  three things to put in it. Same transaction as the forge — gold **and**
  materials — over the same kind of counter, driven by the same screen. She is
  §6.6.
- **The jewelcrafter.** Four blanks and eight paths (`scripts/items/jewel_db.gd`),
  on the west of the plaza. She is §6.7.
- **The hero's quarters.** Not a counter — nobody stands in it, and nothing in it
  takes gold. A lean-to in the south-west corner with a cot you sleep in and a
  footlocker you stash in. It is §6.8, and `docs/SCOPE.md` §2 records why the
  no-list's housing entry let it through.
- **The gate.** Into the dungeon, and back out again on the arrival pad. It is a
  **gatehouse** (`scripts/props/gatehouse.gd`) cut through the north curtain —
  two crenellated towers, a voussoir arch, a raised portcullis, and a roofed
  passage with a wellhead and a timber headframe at the back of it. The cold
  light comes up out of that shaft, not off a panel hung in the arch, which is
  what it used to be and why it photographed as a poster.

**The five counters ring a paved circle** (`scripts/props/plaza.gd`) in the
middle of the yard, and the loop is what sets each bearing. The smith and the
quartermaster take the two north quarters, flanking the approach to the gate,
because they are the counters you visit with a full bag. The alchemist and the
jewelcrafter take east and west, on the walk from the plaza back down to the
arch — what they sell is spent on the way back *down*, and the frame you see when
you extract has to contain them or they do not exist, which is the exact mistake
the jewelcrafter's first placement made. Both are swung a little north of true
east/west for that reason and no other: at a true beam they fall outside the
arrival camera's 40°.

**The Lanternkeeper stands on the middle of the circle**, with the First Lantern
carved in stone at her back (`scripts/props/statue.gd`). Hers is the only reward
that is not on the screen you just closed — it is a lamp fifteen metres away — so
turning away from her has to face the yard, and from the centre it faces the yard
in every direction.

Each of them is a person of one of the Vale's peoples (`scripts/world/race_body.gd`)
standing behind a booth full of their own trade (`scripts/props/shop_booth.gd`):
a **Stoneborn** at the forge, hearth and anvil and quench barrel behind him; a
**Reshi** under a canopied market stall, coin pile and pouch on the counter; a
**Vyr** at an apothecary's bench with a cauldron and a wall of bottles. They
were three tapered boxes until the loop worked, and the swap changed nothing
below the mesh — the counters, the catalogues and the one trade screen are
exactly as described above. **This is dressing, and it has no rules.** A booth
has no state and no interaction of its own; a fourth counter is still a
`Catalogue` subclass and a row in `Npc.COUNTERS`, plus a row in `Npc.LOOKS` for
who stands at it.

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
first hour. So the gear that matters climbs ladders whose rungs cost **gold and
components**, and components only exist underground.

### The twelve ladders

Four rungs each: rung 0 is the piece as it comes out of the box, and there are
three to buy. The numbers live in `scripts/core/consts.gd` and the gear reads
them back through accessors on `Game` — `sword_bonus()`, `armour_soak()`,
`guard_arc()`, `bow_draw_time()`, `hook_reach()`, `speed_mult()` — so a rung IS
the effect, and there is no per-track special case anywhere in the shop.

| Track | Gear | What the rung moves | 0 → 3 |
|---|---|---|---|
| `edge` | sword | damage, in quarter-hearts | +0 → +3 |
| `guard` | shield | block arc, in degrees | 70° → 115° |
| `string` | bow | draw time, in seconds | 0.44 → 0.26 |
| `chain` | hookshot | **reach**, in metres | 8.74 → 18.20 |

**There is no `plate` track.** Armour is four pieces — chest, legs, arms, boots
— and each piece picks **one of two paths** and climbs that. Eight track ids,
`plate_{chest,legs,arms,boots}_{heavy,light}`, built by `Game.plate_track()` so
nothing spells them by hand except `ShopDb.LIMITS` (a `static var` initialiser
runs before the autoloads exist, so it cannot loop `Game.PLATE_TRACKS`; the
forge director's beat P0 exists to catch the typo that invites).

| Path | Soak per piece, rung 0 → 3 | Speed per piece, rung 0 → 3 |
|---|---|---|
| heavy | 0.0 → 1.0 quarters | ×1.0 → ×0.97937 |
| light | 0.0 → 0.5 quarters | ×1.0 (no cost) |

Read it as sums, not as rows: **four heavy pieces at rung 3 soak exactly 4.00
quarters and move you at exactly 0.9200**; four light pieces soak exactly 2.00
and cost nothing. `4 × 0.92^(1/4)` is where `PLATE_HEAVY_SPEED` comes from, and
the per-piece soak table is fractional for the same reason: the naïve thing —
four copies of the old `PLATE_SOAK` `[0,1,2,3]` — would soak twelve quarters
against a bestiary tuned for three. Both totals are asserted by
`tools/directors/forge_loop.gd` (P1–P4), because a table whose comment claims a
sum is the kind of thing that drifts.

**A path, once bought, is committed.** Buying a rung on `plate_chest_heavy`
drops `plate_chest_light`'s ceiling to zero: `Game.path_closed()` says so,
`ShopDb.cap_of()` returns 0, the row leaves the board, and the refusal reads
`THAT PIECE IS ALREADY COMMITTED`. The other three pieces stay open — the
decision is per piece, which is the whole point of splitting it.

**REFORGE undoes it, for no gold** (2026-08-10, GDD §6.6). A row per piece at
the bottom of the smith's board, held like any other commit: it hands back every
component the piece ever cost, erases the track, and reopens the fork. The price
is the gold, which does not come back, and the walk it stood for. A piece that
never took a rung has no row.

`Hero.hurt` still floors damage at one quarter, so `SOAK_MAX = 4.0` is a
ceiling on the *number*, not a promise of invulnerability.

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

The alchemist's four (§6.6) and the jewelcrafter's two (§6.7) are the same kind
and obey every one of those rules. What separates them is `ItemDef.bench`, a
label the item carries so the pouch can tell you which counter wants it.
`ItemDb.components(bench)` filters on it; an unfiltered `components()` is all
ten, and code that means "the forge's" must say so.

**No component id may appear in two counters' recipes.** The pouch prints one
bench name per material, so a shared ingredient would print a lie. That rule is
written on `ItemDef.bench` and asserted by `jewel_loop` beat A.

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
- **Death takes them — unless they were packed.** Components in the hold die
  with the bag; components already on the bench are permanent, like gold. A
  component in the **document case** banks on death exactly as it would on
  extraction (`die()` calls `bank_components()` on the case's contents), which
  is the one route a component has out of a lost run and the reason packing one
  is a real trade against packing a Void Pearl.

### The pouch

`scripts/ui/menu/pouch_panel.gd`, on the pause menu under Equipment. It draws
`Game.bag_slots` cells — not a list — because a list of six rows and a list of
twelve rows look the same at a glance and the difference between them is the
entire pressure in §3. Stacks occupy one cell until they overflow, exactly as
`Run.slots_used()` counts them, so the picture and the arithmetic cannot
disagree. The right-hand column names what is under the cursor; the WORKBENCH
runs the full width underneath, read-only: this screen shows what you have, the
smith spends it.

**Two grids, since 2026-08-10.** THE DOCUMENT CASE · COMES HOME is three cells
across the top in cyan; CARRIED · DIES WITH YOU is the nine below it. The cells
are the same cell and the count is one count — `slots_used()` sums both regions,
so a stack that straddles the line costs a cell on each side and the picture
still agrees with the header. Drawing the case as its own captioned grid rather
than tinting the top row of one grid is the whole point: the line between what
comes home and what does not is the screen's subject, and a border is a weaker
claim than a heading.

The right column also carries the screen's two **verbs**, in the order they
argue: the **fletching bench** (§4.6) and then the **escape rope** (§5).
Both spend the bag; one spends it on staying in and the other on getting out.
Neither is a verb on an item — a cell's only verb is **A, which moves that stack
across the case line** and is a statement about where the stack sits rather than
anything done to the item. These act on the bag as a whole, which is why they
are cards beside the grid and not entries in
it, and why the bench is here rather than at the smith: the recipe eats the
cheapest two things in the grid to its left, so the price and the stock are the
same picture.

Left of the grid is **WORN** — a drawn silhouette of the hero with the left
hand, the right hand and the bottle cell filled in from `Game.armament()` and
`Game.selected_potion()`, in the viewer's order, matching ITEMS and the HUD
cluster. It is a **paper doll, not an equipment screen**: nothing on it is
pressable, and the hint line says so (`Hands change on ITEMS`). The figure is
drawn in `scripts/ui/menu/paper_doll.gd` with `draw_circle`/`draw_line` rather
than being a portrait sprite, for the reason in STYLEGUIDE §5 — the menu owns no
art, and a silhouette that is obviously a diagram never has to survive a
comparison with the model on screen behind it.

It earns the column because the pouch is where you go to ask *what am I carrying
into the next room*, and until it was here that question needed two screens: the
bag on this one and the hands on ITEMS. The doll answers it without making the
answer editable, which is the distinction the next paragraph is about.

It is a separate screen from **Items**, which is what you are *holding* and what
the D-pad cycles. Carrying and holding are different questions and a player who
conflates them is a player who thinks the bag can be equipped. The doll shows
holding on the carrying screen precisely because it cannot be used to change it.

---

## 6.6 The alchemist — the only thing you take down with you

*Numbered 6.6 for the same reason §6.5 is 6.5. Do not renumber.*

> **⏳ Extended, not superseded — `docs/GDD.md` §6.5, not built.** This counter
> gains two jobs at M5. She **reads** the two Verse relics (GDD §6.2), and she
> sells **charges** for the three workings — the same stock-you-bought-in-garrison
> relationship the bottles below have, priced the same way, refilled only here.
> Everything in this section is true today and stays true; nothing below changes.
> Charges are a HUD counter beside the arrows, never a bag slot.
>
> **"Refilled only here" is now "refilled here, and once on floor 2"** (card #29,
> 2026-08-11). It is not a softening of the rule above and it is not an arrow
> supply: **nothing rolls charges into a room or a chest**, and the walk home is
> still spent with what you bought. There is exactly one `ChargeCache`
> underground and it is inside the urn braced against floor 2's shortcut, because
> that door is a cracked pillar and a cracked pillar has no other answer — a
> player who descended with an empty pouch met a gate he could not open and could
> not earn (`docs/PUZZLES.md` §0 rule 2, `docs/ITEMS.md` §8 D13). The room
> supplies the verb it demands. It supplies nothing else.

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
changes under you) and **X/Square — R on the keyboard — drinks** the selected one
(`Game.use_selected_item`).
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
workbench, three counters spending from it.

### What the HUD says

The selected bottle draws in the cluster's third cell — body, neck, lip — with
the draught's colour filling the lower two-thirds, and an outline only when it is
empty. A live draught adds a draining bar to the health/stamina/heat column, in
the potion's own colour, because it is the same kind of fact as the bars above
it: true now, and shortly not. Nothing is drawn when nothing is running.

Bottles and their contents are in the save file (`VERSION = 4`). The draught
clocks are **not**: a 45-second buff that survives quitting is a buff you can
bank, and the point of the timer is that it is spent in the room you drank it in.

---

## 6.7 The jewelcrafter — the ceiling belongs to the number

The fifth counter, in the west gap of the garrison yard, forward of where you
arrive. `JewelDb extends Catalogue`, one row in `Npc.COUNTERS`, and the **same
`TradeScreen`** every other counter uses — SCOPE §1 freezes new UI screens at
zero and this did not need one.

Four slots, each of which you must first **buy blank** for gold alone:

| Slot | Blank | Path A | Path B |
|---|---|---|---|
| Amulet | 220 g | **Vigor** — +0.5 heart container a rung | **Focus** — +15 stamina a rung |
| First Ring | 150 g | **Edge** — +0.25 quarters a swing | **Swift** — ×1.0101 speed |
| Second Ring | 150 g | Edge | Swift |
| Bracelet | 190 g | **Ward** — +0.5 quarters soaked | **Wind** — +0.1 stamina regen |

Once the blank is owned, its two path rows appear and the slot climbs
`JEWEL_MAX = 4` rungs — one more than the forge, because a jewel rung is a
smaller step. Committing to a path closes the sibling exactly as the plate
pieces do. Buying a blank is a **tap**; buying a rung is a **hold**, the same
grammar as everywhere else.

**RECUT undoes it one rung at a time, and the stone does not come back**
(2026-08-10, GDD §6.6). A row per slot at the bottom of her board, no gold: it
drops the track a rung and refunds nothing, so walking a rung-4 amulet back to a
free slot is four holds and four Cut Gemstones. She stays the harder commitment
than the smith on purpose — metal is conserved and stone is not — and she can
afford to, because two ring slots drawing on the same pair already give the
player a hedge the plate pieces do not have. `Game.resync_maxima()` recomputes
hearts and stamina from `upgrades` afterwards, so the maxima come down with the
rung instead of the purchase arithmetic being run backwards.

**The ceiling belongs to the number, not to each faucet.** Soak has two sources
(heavy plate and Ward) and they share `K.SOAK_MAX = 4.0`. Damage has two (the
`edge` ladder and two Edge rings) and they share `K.EDGE_MAX = 5`. Speed has two
(heavy plate costs it, Swift buys it back) and the product is clamped to 1.0 in
`Game.speed_mult()` — you cannot out-run your unarmoured self. Stamina's ceiling
is `K.STAMINA_MAX = 160`, which is `MAX_STAMINA` plus exactly four Focus rungs.
`jewel_loop` beats F0–F4 open both faucets on each number and assert the cap
holds.

Jewel rungs are **not** rationed by `RelicDb.forge_rungs_known()`. Relics ration
the smith; the jewelcrafter is her own economy, and gating her behind the same
counter would make one relic drop control two counters.

### Her two components

| Component | Value | Rarity | Stack | Drops from |
|---|---|---|---|---|
| Silver Wire | 15 | common | 8 | bodies and chests |
| Cut Gemstone | 95 | rare | 3 | **chests only** |

Two rather than four, and new rather than borrowed: converting the vendor's
three rare ingredients would have stripped his best sale lines in the middle of
loop validation. The ladder is `2 → 4 → 6+1 gem → 8+2 gem` wire, at
`90 / 180 / 340 / 620` gold — flat by rung, not scaled by what you already own,
because each rung is a separate small purchase rather than one ladder's fourth
step.

### The stat block

`scripts/ui/menu/equip_panel.gd` draws **five stats and no sixth** — damage,
speed, max health, stamina, soak — in a THE HERO card under the item detail.
Every one is read back through a `Game` accessor and **never recomputed in the
panel**; a panel that does its own arithmetic is a second source of truth that
drifts the first time a ladder changes. Soak prints the applied integer and, when
they differ, the exact fraction in brackets, because `-1 quarter (1.2)` is the
only honest way to say "you have bought 1.2 and the game floors it".

---

## 6.8 The hero's quarters — the bed and the footlocker

*Numbered 6.8 for the reason §6.5 gives: these numbers are cited from code
comments and directors. Do not renumber them.*

A lean-to in the courtyard's south-west corner (`scripts/world/house.gd`), built
by `Garrison._build_house`. Three walls, a sloped roof, a lantern, and two
props: a cot and a chest. It costs nothing, it upgrades into nothing, and it is
not a counter — nobody stands in it. `docs/SCOPE.md` §2 refuses housing and this
is the argued exception; the reason is that **both props close a hole the
metagame already had**, not that the hero wanted somewhere to live.

### The bed writes the save

`Flow._go` autosaves on scene transitions and only on scene transitions (§5,
above). That covers the four moments a *run* passes through and none of the time
between them — which is where the entire garrison lives. Sell the bag, forge two
rungs, blow a bottle, set a gem, quit: as of the last autosave, none of it
happened. The cot is where a player says *keep this*, in the gesture every game
of this shape has used to say it.

Holding **E** on the cot fades to black for 0.9 s, heals to full, refills
stamina, and calls `Saves.autosave()`. The HUD's own **AUTOSAVING…** notice is
what confirms it; when three slots are full of hand-made saves the autosave
declines, and the bed says `RESTED. NO SLOT FREE TO SAVE.` rather than fading to
black and silently doing nothing.

**The heal costs the design nothing**, which is the only reason it is allowed to
exist next to GDD §2's refusal of "a heal you can carry without paying for it".
Both doors into the garrison already heal to full — `Run.extract` and `Run.die`
each call
`Game.heal(Game.max_quarters)` — so there is no state in which a hero reaches
this cot hurt. It heals so the object does what the object says, not because it
moves a number anyone can reach. **And it is refused outright while
`Run.in_dungeon`** (`bed.gd activate`), because the rule it enforces is not "the
cot is in the garrison", it is §5's *you cannot save your way out of a run*.

**No clock advances.** `Garrison._build_env` pins the sky to one afternoon on
purpose (SCOPE §1 freezes the mechanic count), and a bed that skipped to morning
would be a day/night system arriving through a prop.

### The footlocker stops the garrison destroying goods

`Run.enter()` clears the bag. That is correct and it stays — the bag is the
pressure valve (§3) and a run must start empty. But it meant that anything
carried home and *not sold before the next descent* was deleted without a word:
the four Deep Amber you were saving for a heavy-chest rung went into the dark the
moment you touched the gate. Silent destruction is not a decision, it is a bug.

The locker is `K.STASH_SLOTS` = **24 slots**, counted by exactly the bag's rule —
`ceil(count / stack)` per item kind, so a stack of ten Bone Shards is one slot,
not ten. It is stored in `Game.stash` (survives death; banked with components and
relics, §6.5 "How they get home") and written to the save under `stash`.

| | Bag (`Run.bag`) | Locker (`Game.stash`) | Pouch (`Game.components`) |
|---|---|---|---|
| Slots | 8 → 12, priced | 24, fixed | uncapped |
| Survives death | no | yes | yes |
| Reachable underground | it *is* the run | **no** | read-only, for forging |
| Cleared by `Run.enter` | yes | no | no |

**24 is finite for the same reason the bag is.** SCOPE §2: a shelf that never
fills is a shelf that answers *is what I am carrying worth more than the walk
back* on the player's behalf, forever. When the locker is full you sell
something, and the screen says `THE LOCKER IS FULL` in the refusal colour rather
than quietly dropping the transfer.

`StashScreen` (`scripts/ui/stash/stash_screen.gd`) is the one new UI screen in
the plan and SCOPE §1 records why. One row per item kind, two columns —
**STORED** and **CARRIED** — `←` stows, `→` retrieves, held for the whole stack,
`ESC` leaves. Both directions go through `Run.consume` and `Run.collect` rather
than touching `Run.bag` directly, so the bag's slot arithmetic and the heat
premium (§4.5) stay in the one file that owns them: **stowing a premium
ingredient prorates the premium out exactly as selling it would**, and there is
no way to launder heat value through the shelf.

The row *order* is frozen when the screen opens. It used to re-sort
carried-first on every transfer, which moved the row out from under the cursor
mid-hold and emptied a stack the player never chose — found by
`house_rest.gd` on its first run, and the reason the sort and the refresh are two
functions now.

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
| Run state, bag, the document case, extraction, death | `scripts/autoload/run_state.gd` |
| The mercy dial and the death count | `scripts/autoload/game_state.gd` (`mercy_rate`, `deaths`), `scripts/autoload/settings.gd` (`mercy`) |
| Persistent gold, forge rungs, workbench stock | `scripts/autoload/game_state.gd` |
| Garrison↔dungeon transition and fade | `scripts/autoload/game_flow.gd` |
| The end-of-run receipt, both endings | `scripts/ui/run_end/run_end_screen.gd` |
| Ingredients, components and drop tables | `scripts/items/item_db.gd` |
| The bag's value tiers (§3.1), and the curve they are read off | `scripts/ui/style.gd` (`Pal.T1/T2/T3`), `tools/bag_curve.gd` |
| The smith's catalogue, and the forge recipes | `scripts/items/shop_db.gd` |
| The alchemist's catalogue, and the brew recipes | `scripts/items/alchemy_db.gd` |
| The jewelcrafter's slots, paths and rungs | `scripts/items/jewel_db.gd` |
| The hero's five stats, drawn | `scripts/ui/menu/equip_panel.gd` |
| What a draught is called and what it does | `scripts/items/potion_db.gd` |
| Bottles, their contents and the draught clocks | `scripts/autoload/game_state.gd` |
| The upgrade ladders, rung by rung | `scripts/core/consts.gd` (`K.EDGE_DAMAGE` …) |
| The difficulty curve, every floor of it | `scripts/core/progression.gd` |
| The way down | `scripts/world/stairs.gd` |
| The pouch — the bag, drawn as slots | `scripts/ui/menu/pouch_panel.gd` |
| Vendor / smith screen | `scripts/ui/shop/trade_screen.gd` |
| HUD | `scripts/ui/hud/hud.gd` |
| Garrison | `scripts/world/garrison.gd`, `scenes/rooms/garrison.tscn` |
| The shopkeepers themselves — who stands where | `scripts/world/npc.gd` (`COUNTERS`, `LOOKS`) |
| A person of one of the races, dressed and idling | `scripts/world/race_body.gd` |
| The forge, the stall and the apothecary's bench | `scripts/props/shop_booth.gd` |
| Dungeon | `scripts/world/dungeon.gd`, `scenes/rooms/dungeon.tscn` |
| The way out | `scripts/items/escape_rope.gd` |
| Drops on the floor, and their heat stamp | `scripts/world/loot_mote.gd` |
| The chain, its tiers and what they are worth | `scripts/autoload/heat.gd` |
| Chests — the model, the lid, what comes out | `scripts/world/chest.gd` |
| Arrows on the floor, and the pickup | `scripts/world/arrow_bundle.gd` |
| The fletching recipe, and its refusals | `scripts/items/fletching.gd` |

The game boots into **garrison** (`run/main_scene`). `Flow` is the only thing
that ever calls `change_scene_to_file`; if a second caller appears, the fade
stops being a guarantee and starts being a suggestion.

---

## 9. Proving it still works

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
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
MVP home        scene=Garrison in_dungeon=false gold=182 bag=95 hearts=12/12
```

The garrison's people have two, and the second is the only run in the repo that
declines `shoot.gd`'s unlock-everybody default:

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/dialogue.gd --out=/tmp/dlg/x.png --warmup=40
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/roster.gd --fresh --out=/tmp/roster/x.png --warmup=40
```

`dialogue.gd` walks the box itself — the tables, the typing, one typeface across
the option list, a nine-page briefing that only counts as read when it is read to
the end, and a topic that can be asked twice. `roster.gd` photographs the yard
with three counters missing, sets one boss flag, rebuilds it, and photographs the
smith standing in the corner that was grass.

Arrows have two, because the supply chain has two halves — the objects, and the
floor that has to contain them (§4.6):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/arrow_supply.gd --out=/tmp/arrows/x.png --warmup=60
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
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/autosave.gd --out=/tmp/save/x.png --warmup=60
```

It drives all three transitions and asserts a slot was written each time, that
every one of those saves points at **garrison** rather than at the floor it was
taken on, and that with all three slots full of hand-made saves the autosave
declines and the HUD stays quiet. It photographs the notice as the world comes
back. It backs up the three real slots and puts them back, so running it cannot
cost you a save.

The quarters have one (§6.8):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/house_rest.gd --out=/tmp/house/x.png --warmup=60
```

It measures the billet against the relic ring, moves a stack both ways through
`Run.consume` / `Run.collect`, fills the shelf to 24/24 and photographs the
refusal, runs `Run.enter()` to prove the shelf survives what the bag does not,
then wounds the hero, sleeps, and reloads the written slot to prove the stash
came off the disk. `HOUSE FAIL …` on any claim that did not hold. It backs up
the three real slots and puts them back, like `autosave.gd`. Last run:

```
ok  SLEEP is inside the walls (-12.2, 8.4)
ok  OPEN is inside the walls (-8.1, 8.6)
ok  the nearest relic lamp is 2.0 m clear of the furniture
ok  the cot did not steal the button from four metres away
ok  holding stowed the rest of the stack (bag has 0, shelf has 4)
ok  the shelf filled to its cap (24/24 slots off 24 stacks)
ok  a full locker refused the silk (3 still carried)
ok  the run cleared the bag, as it always has
ok  and the two pearls are still on the shelf (2)
ok  he woke up whole (8 -> 12/12)
ok  the rest wrote a slot (0)
ok  the shelf came back off the disk (2 pearls)
HOUSE OK
```

The forge and the pouch have theirs (§6.5):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/forge_loop.gd --out=/tmp/forge/x.png --warmup=60
```

It reads the catalogue, opens the pouch, is refused a rung it cannot pay for in
components, buys all fifteen rungs and watches the gear's own accessors move,
descends, walks over three component motes with **no button pressed**, extracts,
dies on purpose to prove the bench survives what the bag does not, and finally
saves, wipes and reloads to prove a forged rung survives quitting the game.
`FORGE FAIL …` on any claim that did not hold. Last run:

```
PLATE full-heavy soak=4.00 speed=0.9200
PLATE full-light soak=2.00 speed=1.0000
FORGE base       edge=+0 plate=-0 guard=70 draw=0.44 reach=8.74
FORGE full       edge=+3 plate=-4 guard=115 draw=0.26 reach=18.20
FORGE swept      bag=3 value=62        (walked over, nothing pressed)
FORGE pre_extract bag=140 fee=35
FORGE home       bench={grit:86 plate:53 coil:78 core:112} bag={void_pearl:1}
FORGE after_death bench_cores=112 bag=0
FORGE reloaded   rungs={edge:3 guard:3 string:3 chain:3
                        plate_*_heavy:3 plate_*_light:0} slots=12
FORGE rungs taught=3 of 3 (relics donated: 2)
FORGE pouch frame=1220x703 viewport=1280x720
FORGE OK
```

The two `PLATE` lines are the whole reason beats P1–P4 exist: they are the sums
§6.5 claims, printed rather than asserted-in-silence, so a drift shows up in the
log instead of in the difficulty three months later. `plate=-4` on the full line
is the four heavy pieces at rung 3, at the `SOAK_MAX` ceiling.

**B4 was red for a long time and is green as of 2026-08-09.** It has been red in
two different directions, which is why the check earns its place.

First it was too **tall**: 1060x772, 52 px past the bottom of the screen, with the
Back button and the foot of the WORKBENCH card rendering off it. That was the
right column, which stacked four cards — detail, fletching, the way out, and the
bench. The bench moved to the left side, which is where it still is.

Then it was too **wide**: 1362 in a 1280 viewport, the moment the WORN doll
(§6.4) arrived on the left in the same week the bench did and the two shared a
row — doll 156 + bag 600 + bench 160 + gaps against a 776 px budget. The bench
went *under* the grid rather than beside it, and widened from two stock columns
to four now that it has the whole width. 1220x637, and both numbers have room.

**Neither fix took anything off the screen, and the next one probably has to.**
The two cheap moves — spending vertical slack on the left, spending horizontal
room the doll's column freed — are now spent. A ninth material costs the bench a
quarter of a row instead of half of one, so that is not the thing to fear; a
fifth card in either column is. If B4 goes red again, the answer is a card off
the screen, not another 2 px of padding.

The document case spent 66 px of what was left: **1220x703 as of 2026-08-10**,
the case's three cells and its caption above the nine. 17 px of vertical slack
remain, so the warning above is now the operating instruction rather than a
prediction.

The alchemist has hers (§6.6):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/alchemy_loop.gd --out=/tmp/alchemy/x.png --warmup=60
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
alchemist's four materials joined the forge's four, which is why that list is a
grid rather than a column at all — two columns then, four now that the card runs
the full width under the bag. A rectangle in the wrong place is not a thing an assertion can
see.

The jewelcrafter has hers (§6.7):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/jewel_loop.gd --out=/tmp/jewel/x.png --warmup=60
```

It checks her two stones are on her own bench and on nobody else's, finds her in
the yard and measures her clear of the relic ring, opens her board through TALK,
watches it go four blank rows → five → eight as slots are bought, commits a path
and watches the sibling leave, buys every rung and reads the numbers back
through the accessors, opens **both faucets on each capped number** to prove the
cap belongs to the number, checks she is not rationed by the smith's relics, and
photographs the stat block. `JEWEL FAIL …` on any claim that did not hold. Last
run:

```
JEWEL stones=[silver_wire, cut_gemstone]
JEWEL she stands at (-11.25, 0.00, 1.10) facing 90 deg
JEWEL nearest relic post = 2.30 m
JEWEL widest board = 8 rows
JEWEL full-A edge=+2 soak=2.00 hearts=5 stamina=100
JEWEL full-B speed=1.0000 regen=64.40 stamina=160
JEWEL both soak faucets open = 4.00 (cap 4.00)
JEWEL swift-only raw=1.0837 clamped=1.0000
JEWEL both edge faucets open = +5 (cap 5)
JEWEL smith knows 1 rungs; she offers 4
JEWEL stat block { damage: "+1 quarter", speed: "98.6%", health: "4 hearts",
                   stamina: "100", soak: "-1 quarter  (1.2)" }
JEWEL equip frame=1220x604 viewport=1280x720
JEWEL OK
```

`swift-only raw=1.0837 clamped=1.0000` is the line worth keeping: the ladder
genuinely computes a number above 1.0 and the clamp is what makes it a ceiling.
Printing the raw value is how we know the clamp is doing work rather than the
ladder happening to stop short.

The forgiveness pass has one, and it is one director for four systems because
they are one argument (GDD §3.1, §6.6, §7.1):

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/forgive_loop.gd --out=/tmp/forgive/x.png --warmup=60
```

Six beats. **A** packs a bag, dies, and checks that the case came home and the
hold did not — including the heat premium, which follows the merchandise rather
than the player. **B** opens the pouch and measures the two grids against the
viewport. **C** kills the run twice, once each way, and counts the columns on
the receipt. **D** and **E** buy a commitment at the smith and at the
jeweller and then undo it, checking that the metal comes back and the stone does
not, and that the fork reopens. **F** drives the mercy dial: that it is off
until asked, that it climbs with deaths and caps, that a one-quarter blow still
lands, that over forty blows it forgives what the caption advertises, that the
Cut is exactly as dangerous either way, and that `deaths` survives the save file
while the toggle stays in `settings.cfg`. `FORGIVE FAIL …` on anything that did
not hold. Last run:

```
FORGIVE bag={deep_amber:1 tally_ledger:1 bone_shard:14 whetstone_grit:5 tension_coil:7}
        cased={deep_amber:1 bone_shard:14 whetstone_grit:5}
FORGIVE after death bag={bone_shard:14 deep_amber:1}
FORGIVE pouch frame=1220x703 viewport=1280x720
FORGIVE receipt grids=2 kept={deep_amber:2 bone_shard:12 tension_coil:4}
FORGIVE mercy base=0.050  capped=0.300
FORGIVE mercy took 113 of 160, expected about 112
FORGIVE OK
```

`took 113 of 160` is the line that earns its place: 30% of a 4-quarter blow is
1.2, and an engine that rounds per hit forgives 1 every time and lands on 120.
The carry is what makes an integer resistance charge the fraction it printed.

The two counter frames are the reason `_shoot_counter` moves the cursor before
it captures. REFORGE and RECUT are deliberately the **last** rows on boards that
are taller than the frame, so a photograph of the top of either board would
prove nothing about the row the beat exists for. The mercy frame has the same
problem one screen over and the same fix — focus the row, then scroll to the
bottom so the caption with the live percentage is in shot too.

One trap worth naming, because both these directors fell in it and the symptom
blamed the wrong system. `game_flow.gd` autosaves at the **end** of a
transition, after the fade in — so a beat that waits a fixed number of frames
after `Run.die()` or `Run.extract()` can return while that autosave is still
coming. The save beat then calls `Saves.save(2)`, which makes 2 the active slot,
and the late autosave lands *there*. Arrive after the beat's `Game.reset()` and
the slot holds the wiped state: the reload checks fail and every sentence in
them blames the save format. Wait for `Flow.busy` to clear, the way
`autosave.gd`'s `_settle` does. A fixed frame count only moves the odds.

A second one, from the same seam and found by `forgive_loop`: ending a run does
not only write a save. `Flow._on_run_ended` **pauses the tree, sets
`Prompt.blocked`, and raises its own `RunEndScreen`** — so a director that kills
a run and then walks to a counter is standing in a paused world behind a screen
it did not open, and the `interact` press meant for the smith dismisses that
screen instead. The symptom is a counter that never opens, and every sentence in
it blames the counter. `forgive_loop._settle` frees the leftover screen,
unpauses and clears the block; anything that ends a run mid-director needs the
same. Copy `Run.summary` **before** settling — the ride home clears it.

**Do not pass `--headless`.** There is no rendering device in headless mode and
every frame comes out empty.
