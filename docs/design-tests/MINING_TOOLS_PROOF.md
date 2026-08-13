# Design test — Mining and Utility Tools Proof

- **Status:** Implementation complete — awaiting the precommitted inactive human test
- **Owner:** Project owner, issue #184
- **Opened:** 2026-08-13
- **Canon owners in scope:** [../NOW.md](../NOW.md),
  [../SCOPE.md](../SCOPE.md), [../ITEMS.md](../ITEMS.md),
  [../METAGAME.md](../METAGAME.md), and [../CONTRACT.md](../CONTRACT.md)

## Question

> Do three finite utility tools turn ordinary salvage, home work, and dungeon
> veins into explainable preparation choices, or do they become compulsory
> upkeep and exhaustive room sweeping?

## MDA hypothesis

- **Target aesthetic:** resourceful preparation—the player feels that an
  ordinary returned haul can become several different kinds of future agency.
- **Desired dynamics:** players compare incidental enemy Iron Scrap with
  spending Pickaxe durability for efficient mining; allocate metals between
  tools, Brannoc's forge, and the Bolt-Thrower; complete the grove-to-hearth
  prerequisite before a Rod transaction; and reforge when the next expected
  work justifies paying the full bill.
- **Failure dynamics:** every room is swept for veins regardless of the run,
  durability is experienced as opaque breakage, metal allocation has one
  dominant answer, or reforge costs become resented maintenance.
- **Minimum mechanics:** three fixed-durability non-combat tools, three distinct
  commitment points, private deterministic vein placement and payouts, stable
  per-run depletion, and existing physical loot/economy paths.

## Player contract

Brannoc forges and fully reforges:

| Tool | Uses | Full forge/reforge bill | Use is spent |
|---|---:|---|---|
| Woodsman's Axe | **8** | **60 gold + 3 Iron Scrap** | Only on a successful daily tree impact |
| Pickaxe | **12** | **75 gold + 3 Iron Scrap** | Only at the committed impact on an intact vein |
| Fishing Rod | **10** | **45 gold + 1 Iron Scrap + 1 stored Firewood bundle** | On every resolved success or failure; never on cancel |

A first forge and every reforge restore the full maximum. A known zero-use tool
remains known, is removed from compatibility ownership in `Game.items`, displays
**BROKEN**, and can be reforged. Positive durability mirrors into `Game.items`
only for compatibility. Tools never enter hands, loadouts, rings, the wheel,
bag, document case, locker, Trade sale, armaments, or combat.

Pre-v18 Axe ownership migrates at full durability. Save v18 persists all three
tools, including known broken zeroes.

## Fixed mining tuning

Every ordinary non-entrance, non-maze room independently has a deterministic
**65%** vein chance. A private floor/cell-salted RNG stream chooses presence,
blank wall, offset, and payout without advancing the floor generator's `_rng`.

| Existing payout id | Weight | Yield |
|---|---:|---:|
| Iron Scrap | **65** | **3** |
| Riveted Plate | **22** | **2** |
| Tension Coil | **13** | **1** |

A mined vein becomes rubble and drops one physical LootMote stack. Its stable
floor/cell depletion survives deterministic rebuilds, floor backtracking, and a
resumable Run v3 save, then clears on a new run. Mining adds no map marker,
gate, room, currency, item id, or automatic banking. Existing enemy Iron Scrap
drops remain unchanged as the less-efficient fallback.

Iron Scrap and Riveted Plate feed Brannoc. Riveted Plate and Tension Coil retain
their existing BuilderDb use in West Gate Bolt-Thrower construction. The Rod's
wood comes only from the existing daily grove-to-hearth loop.

## Player decision chain under test

1. Notice that incidental enemy iron remains available, then decide whether a
   visible vein is worth one Pickaxe use for its larger existing-metal stack.
2. Carry and protect the physical payout through the ordinary bag, case,
   extraction, and death rules.
3. Allocate Iron Scrap, Riveted Plate, and Tension Coil among utility tools,
   Brannoc's forge work, and the Builder's Bolt-Thrower rather than treating any
   one sink as automatic.
4. Chop and deposit a Firewood bundle before asking Brannoc to forge or reforge
   the Fishing Rod.
5. Decide whether the remaining expected work on a worn or broken tool warrants
   paying its whole reforge bill now.

This chain changes access and cost around fishing. It does **not** validate the
near/deep fishing choice; that hypothesis and its evidence bar remain open in
[FISHING_PROVISIONS_PROOF.md](FISHING_PROVISIONS_PROOF.md).

## Smallest human test

Run **five cold sessions** from a prepared campaign with Brannoc, the Builder,
grove, hearth, pond, and dungeon available. Give each player an ordinary
descent and two unprompted garrison visits. The prepared state must expose a
limited Pickaxe, at least one worn or broken tool, a meaningful but insufficient
set of metal for every available sink, an empty stored-hearth requirement for
the Rod, and a deterministic floor containing both enemies and eligible veins.

Do not tell players to mine, preserve materials, build the Bolt-Thrower, chop
wood, forge the Rod, or reforge anything. After observed play, a neutral
walkthrough may expose an unseen link only so comprehension can be separated
from voluntary behavior. Store raw observations in [../playtests/](../playtests/).

For each session, record:

- veins noticed, mined, skipped, or searched for, and the stated reason;
- whether the player distinguishes enemy Iron Scrap from the more efficient
  Pickaxe-funded payout;
- every tool use, cancel, break, forge, reforge, and durability prediction;
- every metal allocation or deliberate deferral among tools, forge work, and
  Bolt-Thrower construction;
- whether the player independently connects chop → deposit → stored
  Firewood → Rod forge/reforge;
- whether physical payout, bag pressure, extraction risk, rubble, and resumed
  depletion are understood;
- language of preparation, opportunity cost, maintenance, compulsion,
  exhaustive clearing, confusion, or annoyance;
- every researcher intervention and technical failure.

After play, ask:

1. When does each tool lose a use, and what happens at zero?
2. Why did you mine or skip the veins you encountered?
3. What were your alternatives for getting or spending those metals?
4. What has to happen before Brannoc can make the Fishing Rod?
5. When would you reforge a worn tool, and when would you wait?

## Precommitted criteria

These rules apply to one batch of five valid cold sessions. Do not rewrite them
after testing starts.

### Pass

Pass only if no stop condition occurs and all are true:

- At least **4/5** players can explain the Pickaxe-use versus incidental-enemy-
  iron choice and identify mining as the more efficient but durability-limited
  route.
- At least **4/5** correctly explain all three spend moments, including no Rod
  spend on cancel and no Axe or Pickaxe spend before successful impact.
- At least **3/5** make and explain both a vein decision and a later
  metal/wood/reforge allocation without prompting.
- At least **4/5** understand that payouts remain physical ordinary loot and
  that a mined stable site stays depleted only for the current run.
- No more than **1/5** describes mining or reforging primarily as compulsory
  upkeep or feels required to sweep every eligible room.

A pass supports keeping this exact slice. It does not authorise another tool,
ore, payout, gathering site, profession ladder, mining room, marker, or fishing
location.

### Revise

Revise the smallest relevant feedback, placement, or cost rule and run a fresh
five-session batch if no stop condition occurs and any is true:

- exactly **2–3/5** understand the Pickaxe-versus-enemy fallback or the three
  commitment points;
- exactly **2/5** make an explainable downstream allocation after mining; or
- repeated durability, payout, rubble, hearth-stock, or reforge confusion
  plausibly masks an otherwise deliberate preparation choice.

Do not add ore varieties, tool tiers, a marker, a profession screen, or larger
payouts to repair a communication problem.

### Stop

Stop expansion and remove or fundamentally reconsider the smallest responsible
part of the loop if any is true:

- only **0–1/5** understands why Pickaxe mining differs from enemy Iron Scrap
  after ordinary play;
- **0–1/5** makes any explainable tool, metal, wood, or reforge allocation after
  the links are visible;
- at least **3/5** treats exhaustive vein clearing or full-durability upkeep as
  mandatory; or
- at least **4/5** ignores the tool/mining chain after exposure and says it adds
  neither useful preparation nor an interesting opportunity cost.

### Invalid batch

The batch is invalid if fewer than five sessions provide an unprompted vein
opportunity and a later garrison allocation opportunity, or if technical
failure, protocol contamination, or non-cold participants prevent usable
evidence. Repair the test and run a fresh batch; do not average invalid sessions
into the decision.

## Evidence status

### Implemented facts

The source implements the three-entry `ToolDb`, full forge/reforge transactions,
known-broken zero durability, positive-only `Game.items` compatibility, v18
tool persistence and pre-v18 Axe migration, the three commitment points, private
salted 65% placement, the fixed existing-item payout table, rubble plus physical
LootMote delivery, and Run v3 stable depletion.

### Instrumented facts

Brannoc's rows, the Equipment **TOOLS** list, Garrison Axe status, Fishing Rod
overlay/results, work messages, rubble, and physical motes expose the relevant
state to players and automated directors. The fixed-seed mining, garrison-life,
grove-cutting, and fishing-provisions directors pass, including cancellation,
break/reforge, exact payout, exact wear, physical loot, and Run v1-v3 migration
checks. Import, headless parse/boot, save/load-position, outskirts, and lore
validation also pass.

### Human-session claims

No human session has tested the MDA hypothesis. Nothing implemented or
instrumented above proves that players notice the fallback, make an interesting
allocation, avoid compulsory sweeping, or value the reforge decision.

## Result

Automated implementation proof passed. The five cold human sessions have not
run, so the player-facing hypothesis remains untested.

## Decision

Pending.

## Canon changed

Issue #184 explicitly amended current canon before human evidence. No
evidence-driven expansion is authorised.

## Follow-up

Keep this test inactive until the owner schedules it. Preserve the separate
near/deep evidence bar in the Fishing Provisions Proof.
