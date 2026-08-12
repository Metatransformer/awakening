# Garrison Life Prototype: Timber, Bonfire, and Status

**Status:** Built and deterministically verified; awaiting the human fun gate

**Owner decision:** 2026-08-12  
**Related:** issue #114 (landed day/night foundation), issue #136 (this prototype)

## Why this exists

The current loop has one meaningful verb: descend. Returning home collapses into
sell everything, buy the next rung, and immediately descend again. Quests still
send the player back through that same loop, so they do not create the sense of
living at or building the garrison.

This prototype asks one narrower question before any Portia-sized town system is
approved:

> Does a small, optional daily responsibility make the garrison feel like a place
> the player helps sustain, and make time at home feel meaningfully different from
> time underground?

## The complete prototype loop

1. Earn Brannoc's arrival through the existing maker's-mark gate.
2. On the next eligible conversation with Aldric, receive the ongoing duty
   **Keep the Hearth**: have Brannoc make an axe, then keep firewood stocked.
3. Craft the permanent Woodsman's Axe at Brannoc's forge.
4. During **Daytime**, visit the Timber Yard on the bounded exterior approach.
5. Hold the existing interact action to chop one bundle. This can be completed
   once per campaign day.
6. Carry the bundle back to the garrison and deposit it at the central hearth.
   The hearth stores at most three bundles.
7. At **Bonfire Time** (20:00), the garrison consumes one stored bundle exactly
   once. A fueled bonfire grants **Garrison Warmth**; an empty hearth removes it.
8. From 20:00–23:00, every arrived NPC gathers at the bonfire. Services remain
   closed, but people remain available for conversation.
9. At **Bedtime** (23:00), NPCs retire to their existing sleeping places.
10. Warmth remains active until the next bonfire resolves. While active, Kessa
   pays 10% more for ordinary loot and charges 10% less for ordinary Trade stock.

The causal delay is the design: chopping or depositing never changes a price.
Only the next bonfire can create Warmth, and vendors are already closed when it
happens. The earliest economic payoff is the following service window.

## Duty and axe gate

The chore is not available from the opening frame. It is introduced as work the
player is trusted with when the garrison gains the person who can make the tool:

1. `StoryDb.UNLOCKS[&"smith"]` remains the sole arrival gate: the Sluice-Keeper's
   maker's mark brings Brannoc to the garrison.
2. Add `StoryDb.BEATS[&"elder"]` beat `&"timber_duty"` immediately after the
   briefing and before `first_haul`. Its needs are the existing maker's mark and
   the completed briefing. Therefore it is Aldric's first eligible beat after
   Brannoc can arrive, even if the player also crossed a gold threshold.
3. Aldric tells the player the garrison is burning through its stores, Brannoc
   will make an axe, the yard is outside the gate, and a bundle must be stacked at
   the central hearth before Bonfire Time. Completing the last page uses the
   existing `told_elder_timber_duty` flag as the assignment state.
4. Brannoc then stocks one progression line: **WOODSMAN'S AXE**, 60 gold and 3
   Iron Scrap from the returned run bag, one craft, held because it consumes
   materials. This is deliberately the first reason not to flatten every return
   with **Sell All**. The line is hidden
   before the assignment and remains as a completed one-rung line afterward.
5. Crafting calls `Game.grant(ShopDb.WOODSMAN_AXE_ID)`. The axe lives in the
   existing permanent `Game.items` equipment store and existing save payload. It
   never enters `Game.upgrades` or the run bag, so it cannot be dropped, sold,
   lost on death, cleared on descent, or charged an extraction fee.
6. Add the axe to an ordered `ToolDb` manifest and to a compact read-only **TOOLS**
   section on the existing EQUIP page. It is not a hand-ring stop,
   wheel binding, combat armament, or loadout slot; the Equipment page is where
   permanent tools are stored and inspected, not where this one is wielded.
7. The Timber Yard is always visible, but chopping refuses with **YOU NEED AN
   AXE. SPEAK TO ALDRIC.** before assignment and **BRANNOC HAS YOUR AXE ORDER.**
   after assignment but before crafting.

The authored beat is onboarding; **Keep the Hearth** is ongoing work and never
turns into a completed quest that disappears. The Garrison page always shows its
current step after assignment: Craft the axe, Chop today's bundle, Carry it home,
Hearth stocked, or Return tomorrow.

## Daily phases

The surface sky still owns atmospheric dawn/day/dusk/night. The garrison adds a
separate schedule with exactly three player-facing phases:

| Phase | Hours | Garrison behavior |
|---|---:|---|
| Daytime | 05:00–20:00 | Timber Yard available if not completed today; NPC services follow their existing 07:00 opening (06:00 with Early Reveille) |
| Bonfire Time | 20:00–23:00 | Services closed; arrived NPCs gather and remain talkable; one stored bundle resolves |
| Bedtime | 23:00–05:00 | NPCs occupy their authored bunks or Elder quarters; work and Timber Yard closed |

Skipping across 20:00 by sleeping or a debug time jump still resolves each crossed
bonfire. Resolution is idempotent per day so loading a 20:xx save cannot consume a
second bundle.

`Clock.day` is the one-based campaign day. A forward jump resolves crossed 20:00
boundaries in chronological order: each boundary consumes one bundle if available
and overwrites Warmth with that boundary's fueled/unfueled result. For example, a
three-night skip with two bundles ends cold. Backward debug jumps never replay a
day whose number is at or below `last_bonfire_day`.

## State and save contract

The campaign saves one `garrison` payload:

```text
firewood_stock: int       # 0..3 deposited bundles
carrying_firewood: bool   # chopped but not deposited
timber_completed_day: int # the campaign day last chopped
warmth_active: bool       # result of the most recently resolved bonfire
last_bonfire_day: int     # idempotency guard
```

New games start empty and cold. Older readable saves default to the same state.
The clock remains the sole owner of day and time; no duplicate garrison clock is
saved.

A carried bundle persists across days and prevents another chop until deposited.
Deposit is allowed in every phase when stock is below three, but a deposit after
20:00 never retroactively fuels that day's already-resolved bonfire. Chopping is
refused when stock is already three, when a bundle is already carried, outside
Daytime, or after that day's chop.

## Price boundary

Warmth affects only the Quartermaster's ordinary two-sided **Trade** service:

- sell prices: multiply the final merchandise value (including heat premium and
  the Pillar-Shard market effect) by 1.10, then round once to nearest whole gold;
- Trade stock prices: multiply by 0.90, round once to nearest whole gold, and
  clamp a non-zero price to at least 1 gold;
- minimum non-zero purchase price remains 1 gold.

Warmth does not change extraction fees, forge/jewel/alchemy/QoL progression costs,
artifact repair costs, project requirements, or Field Note costs. The Garrison
screen lists each active price contributor so Pillar-Shard and Warmth do not look
like one unexplained modifier.

“Ordinary Trade stock” is exactly `SupplyDb.STOCK_IDS`. “Ordinary loot” is every
bag line for which the existing `Run.line_value(id)` can produce a positive sale;
components, relics, and wishlisted lines keep their existing sell protections.

## Garrison status menu

Add **GARRISON** as the fourth read-only inspection page in the existing
focusable tab strip:

`EQUIP | INVENTORY | MAP | GARRISON`

The page rebuilds from authoritative state whenever opened and provides:

- current day, time, schedule phase, and next transition;
- hearth stock (0–3), carried bundle, whether tonight can be fueled, current
  Warmth, and the exact buy/sell modifiers;
- Timber Yard availability/completion for the current day;
- current **Keep the Hearth** step once Aldric assigns it;
- arrived NPC roster with personal name, role, current activity/location, and
  service open/closed state; unarrived slots are shown as **Undiscovered** without
  revealing names;
- active garrison-wide effects from recorded artifacts;
- owned Elder improvements and their current ranks/effects.

The authoritative joins are fixed:

| Slot | Identity source | Role | Day / bonfire / sleep ports |
|---|---|---|---|
| `elder` | `DialogueDb.PEOPLE` | Lanternkeeper / commander | `elder_day` / `elder_bonfire` / `elder_sleep` |
| `quartermaster` | `DialogueDb.PEOPLE` | Quartermaster | `quartermaster_day` / `quartermaster_bonfire` / `quartermaster_sleep` |
| `smith` | `DialogueDb.PEOPLE` | Smith | `smith_day` / `smith_bonfire` / `smith_sleep` |
| `alchemist` | `DialogueDb.PEOPLE` | Alchemist | `alchemist_day` / `alchemist_bonfire` / `alchemist_sleep` |
| `jewelcrafter` | `DialogueDb.PEOPLE` | Jewelcrafter | `jewelcrafter_day` / `jewelcrafter_bonfire` / `jewelcrafter_sleep` |

Roster presence follows card #115 rather than merely earned arrival: an NPC is
shown after their introduction flag, plus the one unlocked-but-unintroduced body
actually present for the current homecoming. The page never calls the latching
`StoryDb.unlocked()` predicate. Artifact effects iterate `RelicDb.all()` in
catalogue order and include rows where `RelicDb.donated(id)` is true, using the
row's `name` and `detail`.
Elder improvements iterate `ElderUpgradeDb.UPGRADE_IDS` in authored order and show
only ranks above zero, using `_line`'s player-facing meaning through a new public
read-only summary helper rather than duplicating its labels in UI code.

The page has no remote actions. It cannot chop, deposit, buy, turn in artifacts,
or move time. Back is its only focusable body control, matching the Map page's
gamepad contract. Content scrolls inside the existing 1280×720 frame.

Card #120 removed Q/R and LB/RB paging before this page landed. The tab strip is
the keyboard, controller and mouse selector: Up from Back reaches the active tab,
Left/Right walks and wraps the four pages, and Down returns to the page body.
Opening the page always focuses Back, and Back remains outside the scroll
viewport.

## World presentation

- The Timber Yard is a compact landmark beside the upper exterior route: chopping
  block, stacked rounds, axe, and a depleted state after the day's chop.
- The central hearth is a visible fire ring and wood stack in the parade yard.
  Deposited stock changes the stack; Bonfire Time shows flame when fueled and
  embers when empty.
- Chopping is a 1.2-second hold using the existing prompt/hold bar. It yields one
  bundle. This deliberately tests the home-loop value before funding a standalone
  timing minigame.
- The player receives explicit messages for successful chop/deposit and every
  refusal: already completed today, stock full, already carrying, or wrong phase.

Both landmarks are built from procedural primitives and existing wood, iron,
stone, ember, and light materials. No new art or audio asset is required. The
existing `Prompt` owns range, release-to-cancel, input arbitration, and the hold
bar; the Timber Yard only supplies `hold_time = 1.2` and visual axe travel through
`on_hold(t01)`.

The five bonfire ports form a fixed ring around a new `hearth` port in the parade
yard and face its centre. Missing named ports are build errors, not runtime
fallbacks; the director asserts all eleven schedule/hearth ports before testing
movement.

At exactly 20:00, the crossed-boundary signal resolves state before the garrison
repaints the hearth/NPC schedule and before any save callback can snapshot it. A
20:xx load restores the saved result without emitting another crossed-boundary
event.

## Acceptance criteria

1. Before Brannoc arrives there is no duty or axe line. Aldric's first eligible
   post-arrival beat assigns **Keep the Hearth**; only then does Brannoc show the
   60 gold + 3 Iron Scrap Woodsman's Axe line.
2. Crafting the axe grants one permanent `Game.items` tool shown in Equipment.
   It cannot be dropped, sold, lost with the run, equipped to a hand, or crafted
   a second time.
3. Without the axe the Timber Yard never yields a bundle. With it, Daytime
   chopping succeeds once per campaign day and never more than once, including
   across save/load.
4. A chopped bundle is not hearth stock until deposited at the separate garrison
   interaction; stock clamps at three.
5. Crossing 20:00 consumes at most one bundle for that campaign day. Fuel sets
   Warmth active; no fuel sets it inactive.
6. Warmth cannot affect a transaction before the bonfire that activates it.
7. Active Warmth makes ordinary Trade sell prices 10% better and ordinary Trade
   stock prices 10% cheaper, while all named exclusions remain unchanged.
8. From 20:00–23:00, all arrived NPCs are positioned around the hearth, services
   are closed, and TALK remains usable. At 23:00 they move to their existing beds.
9. The focusable pause tab strip pages in both directions through EQUIP,
   INVENTORY, MAP, and GARRISON by keyboard arrows, controller D-pad/stick, and
   mouse tab clicks.
10. The Garrison page accurately shows current work step, schedule, hearth, Timber
    Yard, arrived and undiscovered roster entries, active artifact effects, and
    owned Elder upgrades.
11. The Garrison page fits at 1280×720, scrolls rather than clipping, and places
   focus on Back when opened.
12. New and v11 saves load with valid default garrison state; the full new state
    round-trips through a v12 save.
13. Headless import reports no script/resource errors. A deterministic director
    proves daily gating, deposit, bonfire idempotency, price boundaries, roster
    schedule, focusable-tab paging, and save restoration.

The director starts from a reset day-1 08:00 fixture, stamps all five arrival
flags, and captures `life_00_timber.png`, `life_01_hearth_day.png`,
`life_02_bonfire.png`, and `life_03_garrison_menu.png` at 1280×720. Assertions
cover: assignment priority against an eligible `first_haul`; hidden/visible/owned
axe line and Equipment tool row; no-axe refusal; second chop refusal; separate
deposit; stock cap; one and multi-night
crossings; no double consumption after restore at 20:30; exact warmed/unwarmed
buy and sell values; all five bonfire transforms and talkability with closed
services; Bedtime transforms; four-page wraparound tab paging; Back focus; and
v11 defaults plus v12 round-trip helpers.

## Verification result

`tools/directors/garrison_life.gd` passes at 1280×720 and produces the four named
captures. `pnpm run import` boots clean. This is implementation evidence only:
the prototype is not permission for another chore until a human playtest answers
the question at the top of this document.

## Files expected to change

| File | Responsibility |
|---|---|
| `scripts/autoload/world_clock.gd` | Three-phase garrison schedule and crossed-bonfire signal |
| `scripts/autoload/game_state.gd` | Authoritative firewood/Warmth state and price helpers |
| `scripts/autoload/save_game.gd` | v12 garrison payload and v11 defaults |
| `scripts/world/timber_yard.gd` | Exterior hold-to-chop interaction and landmark |
| `scripts/world/garrison_hearth.gd` | Deposit interaction, stock/fire presentation |
| `scripts/world/garrison_outskirts.gd` | Timber Yard placement |
| `scripts/world/garrison_compound.gd` | Hearth and NPC bonfire ports |
| `scripts/world/garrison.gd` | Phase-driven staffing and hearth placement |
| `scripts/world/npc.gd` | Talkable bonfire schedule state without services |
| `scripts/autoload/run_state.gd` | Compose Warmth with ordinary sell prices |
| `scripts/items/supply_db.gd` | Warmth discount for ordinary Trade stock only |
| `scripts/world/story_db.gd` | Aldric's post-smith ongoing-duty assignment beat |
| `scripts/items/shop_db.gd` | One-time Woodsman's Axe forge line and assignment gate |
| `scripts/items/tool_db.gd` | Ordered permanent-tool presentation manifest |
| `scripts/ui/menu/equip_panel.gd` | Read-only Equipment tools section |
| `scripts/ui/menu/garrison_panel.gd` | Read-only status page |
| `scripts/ui/menu/pause_menu.gd` | Fourth inspection page integration |
| `scenes/ui/menu/pause_menu.tscn` | Garrison panel node/resource |
| `tools/directors/garrison_life.gd` | Deterministic behavior and visual proof |

## Out of scope

- relationship points, gifts, romance, or new dialogue content;
- additional chores, farming, mining, crafting professions, caravans, or a town
  economy;
- Valenfeld town construction or freeform base building;
- a dedicated chopping timing minigame, axe combat/wielding, skill tree, random yields,
  or failure penalties;
- remote management from the Garrison page;
- Field Notes or Expedition Works implementation;
- changing the existing atmospheric sky phases or the length of the day.

## Rollback

Revert the slice. v12 is additive: the previous build will reject a v12 save under
its existing version guard, while this build continues to read v11. No migration
or external data store is involved.
