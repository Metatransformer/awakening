# Field Notes

## Status and authority

This document is the canonical owner for the bounded **Field Notes** system.
Implementation is authorised and tracked by
[issue #112](https://github.com/Metatransformer/awakening/issues/112); its
precommitted human gate is
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md).
The bounded implementation and deterministic proof are complete. The five cold
human sessions remain pending and are the only route through that gate.

Only the five observations and three doctrines specified here are authorised.
They are bounded dungeon progression, not authority for a larger skill tree,
repeatable currency or production content. Implementation cannot prove the
human hypothesis.

## Problem and fantasy

The document case protects a chosen fraction of a failed run's haul, but a death
can still return a player without a new permanent consequence. The intended
cadence is smaller and more specific than consolation loot: **Kael returns
knowing something about the Cistern, records it with the Society and turns a
finite body of field knowledge into one lasting drill.**

Field Notes reward first-time observation, not repetition or performance. They
leave bag loss intact because nothing is picked up, carried or recovered. The
player is not paid for dying; extraction and death are simply the two occasions
on which Aldric can debrief what the run actually revealed.

## Laws

1. **Currency, never loot.** Field Notes are a permanent, non-convertible
   currency. They are not items, drops or pickups; they never enter the bag or
   document case and are never lost.
2. **Observe during the run; award at debrief.** A run records stable
   observation ids. Only garrison debrief after extraction or death converts
   newly observed, never-before-awarded ids into permanent notes.
3. **First-time knowledge only.** Repeated kills, rooms, routes, performance and
   shallow farming award nothing.
4. **Five fixed observations.** Each observation awards exactly one note. There
   is no sixth observation.
5. **Hidden until observed.** Unobserved entries never appear as objectives,
   checklist rows, silhouettes or completion fractions.
6. **Three fixed doctrines.** Each doctrine has one rank, costs two notes and
   cannot be refunded or respecced. There is no fourth doctrine.
7. **A real first choice.** A typical first descent awards at least two notes at
   its first debrief, making one doctrine affordable immediately.
8. **Finite opportunity cost.** Five total notes can buy at most two of the
   three doctrines. One doctrine must remain unbought on a completed save.
9. **Reuse the home loop.** Field Notes use the existing return receipt,
   Aldric's service, `Catalogue`/`TradeScreen`, `Game` save architecture,
   `Game.upgrades` and event bus.
10. **No parallel system.** Add no autoload, screen, NPC, scene/map, item,
    pickup, dialogue tree, quest marker, stat category or new player verb.
11. **One owner per fact.** Static definitions own ids and effects; the run owns
    pending observations; `Game` owns permanent notes, awarded ids and bought
    doctrines. UI and world presentation own no truth.
12. **Signals and stable ids.** Observation, debrief and purchase changes are
    event-driven, saved and idempotent. Replaying a signal or debrief cannot
    duplicate a note or doctrine.

## Economy — faucet, transform and drain

Field Notes are a closed finite economy, not a renewable grind currency.

| Stage | Rule | Rate / cap |
|---|---|---:|
| **Faucet** | First award of an authored observation id at garrison debrief | 1 note × 5 ids = **5 total** |
| **Transform** | A run's pending, never-before-awarded observation id becomes a permanent note and awarded id | Once per id; extraction or death debrief only |
| **Drain** | Buy one one-rank doctrine from Aldric | 2 notes × at most 2 affordable purchases |
| **Remainder** | The finite cap prevents full convergence | 1 note remains after two purchases |

The faucet rate is encounter-shaped rather than hourly: a typical first descent
must expose the descent and mandatory Cistern gate-cycle observations, yielding
at least two notes at first debrief. No repeatable action increases the rate.
The drain is desirable permanent power with an explicit trade-off, not a tax.

## Fixed observations

Unobserved rows in this table are authoring truth only. The player sees a row
only after its id has been observed and awarded.

| Stable id | First-time observation | Award |
|---|---|---:|
| `first_descent_debrief` | First debrief after a descent | 1 note |
| `cistern_gate_cycle_solved` | Solve the Cistern gate cycle | 1 note |
| `cistern_shortcut_opened` | Open the Cistern shortcut | 1 note |
| `cistern_warden_defeated` | Defeat the Cistern Warden | 1 note |
| `fair_weights_ledger_home` | Bring home the Tally-Ledger of Fair Weights | 1 note |

`first_descent_debrief` becomes pending when the first descent begins and is
awarded only when that run reaches a garrison debrief. The ledger observation
is recorded only when the relic actually comes home; dying with it in the bag
does not satisfy the observation.

## Fixed doctrines

These rows appear in Aldric's **Field Notes** service. They are ordinary
`Catalogue`/`TradeScreen` transactions backed by `Game.upgrades`, not a new
skill-tree screen or stat category.

| Stable id | Doctrine | Cost | One-rank effect |
|---|---|---:|---|
| `doctrine_rope_drill` | **Rope Drill** | 2 notes | Extraction world channel falls from **1.2 seconds to 1.0 second**. |
| `doctrine_measured_breath` | **Measured Breath** | 2 notes | Stamina regeneration is **5% faster**. |
| `doctrine_sweep_pattern` | **Sweep Pattern** | 2 notes | Heat magnet radius is **+0.5 m at Warm or above**. |

There is no refund or respec. A bought row is complete at rank 1 and cannot be
bought again.

## Player flow

```text
enter the Cistern
  -> the run records first-time observations as stable pending ids
  -> extract or die; bag rules resolve exactly as they do now
  -> arrive at the garrison return receipt / debrief
  -> newly observed ids not already in Game.awarded are awarded once
  -> receipt pairs each awarded note with the observation that produced it
  -> Aldric's Field Notes service shows three doctrines and the note balance
  -> compare doctrines; spend two notes on one permanent rank or save them
  -> descend again for a named unearned observation / doctrine choice
```

The first debrief must make the source legible. The service does not reveal the
names or count of observations that have not happened.

## Data ownership

| Owner | Responsibility |
|---|---|
| Static Field Notes definition owner | The five observation ids and display text; the three doctrine ids, costs, ranks and exact effects. It is ordinary static data, not an autoload. |
| Existing run state | A set of pending observation ids for the current descent. It does not own permanent currency or purchases. |
| `Game` / existing save architecture | Permanent note balance, awarded observation ids and bought one-rank doctrines in `Game.upgrades`; save/load and migration truth. |
| Existing return/debrief path | Atomically resolve pending ids against awarded ids, present newly awarded rows and request the existing save path. |
| Aldric `Catalogue` / `TradeScreen` | Read definitions and `Game` state, compare/confirm purchases and present balances; own no duplicate economy state. |
| World triggers and UI | Emit observation intent or render authoritative state; never decide whether an award or purchase is valid. |

The award operation is set-based: `new_ids = pending_ids - awarded_ids`. It adds
exactly `new_ids.size()` to the balance and unions the same ids into the awarded
set before saving. Running the operation again produces an empty set.

## Presentation ownership

```text
Garrison (existing scene root)
├── ReturnReceipt (existing Control)       # debrief + newly awarded note rows
└── AldricCounter (existing Node3D)        # Field Notes interaction
    └── TradeScreen (existing Control)
        └── Catalogue (existing grammar)   # three doctrine rows + note balance
```

No child above is a new screen, NPC or source of truth. The receipt and
catalogue populate existing presentation grammar from `Game` and the static
definitions.

| Node / surface | Responsibility |
|---|---|
| `Garrison` | Hosts the existing arrival, receipt and Aldric interaction flow. |
| `ReturnReceipt` | Shows which newly observed events became notes during this debrief; hides unobserved definitions. |
| `AldricCounter` | Opens the existing Field Notes service; contains no balance or doctrine truth. |
| `TradeScreen` | Reuses existing focus, affordability and held-confirm behaviour for note purchases. |
| `Catalogue` | Builds exactly three doctrine rows from static definitions and authoritative `Game` state. |

## Signal map

Signal names are target contracts; implementation connects them through the
existing event bus rather than polling world or UI state.

| Event | Source | Consumer | Payload / purpose |
|---|---|---|---|
| `field_observation_recorded` | Existing Cistern/descent events | Run state | Stable observation id; add to the pending set idempotently. |
| Existing extraction / death return event | Existing run flow | Garrison debrief | Cause one debrief after normal bag/extraction resolution. |
| `field_notes_awarded` | `Game` during debrief | Return receipt, Aldric catalogue, save path | Newly awarded ids and new balance; refresh presentation and persist once. |
| `doctrine_purchased` | Aldric catalogue transaction | `Game`, event bus | Stable doctrine id and cost; validate, deduct and set its rank to 1 atomically. |
| Existing upgrade change event | `Game` after purchase | Affected gameplay systems and catalogue | Refresh the extraction, stamina or Heat effect without polling. |

## Data-flow traces

### Extraction

```text
world events add stable ids to Run.pending_field_observations
  -> extraction resolves fee and carries the bag home through existing rules
  -> a carried Tally-Ledger adds fair_weights_ledger_home before debrief
  -> garrison debrief computes pending minus Game.awarded_field_observations
  -> Game adds one note per new id and unions those ids into awarded truth
  -> existing save path persists balance, awarded ids and doctrines
  -> event bus refreshes the receipt and Aldric's existing catalogue
  -> Run pending observations clear only after the award transaction succeeds
```

### Death

```text
world events add stable ids to Run.pending_field_observations
  -> death resolves case retention and bag loss exactly as it does now
  -> no lost bag item, including the Tally-Ledger, becomes an observation
  -> garrison debrief computes pending minus already-awarded ids
  -> Game awards only the new ids and saves the same atomic state
  -> receipt explains what was learned while the ordinary loss receipt remains
  -> Run pending observations clear only after the award transaction succeeds
```

Both paths call the same idempotent debrief operation. Extraction and death do
not maintain separate award arithmetic.

## Explicit non-goals

- No item, drop, pickup, bag slot, case slot or sale conversion.
- No note for repeated kills, rooms, routes, speed, damage, depth, death count
  or performance.
- No random observation, repeatable faucet, daily, challenge or grind track.
- No revealed objective list, journal, checklist, quest marker or completion
  percentage for unobserved entries.
- No fourth doctrine, second rank, refund, respec or way to buy all three.
- No skill tree, new stat category, class, level or experience system.
- No new autoload, screen, NPC, scene/map, dialogue tree, input or player verb.
- No change to bag loss, document-case rules, relic loss or extraction pricing
  beyond the bought Rope Drill effect.
- No production floors, additional observations or additional doctrines.

## MDA and falsification

The intended aesthetic is **homecoming as learning** and **specific
anticipation**. The required dynamic is that a player connects a note to
something they actually observed, weighs at least two doctrine uses, makes a
finite opportunity-cost choice and later names a specific doctrine as a reason
to pursue another first-time observation. The mechanic is the five-id finite
faucet, debrief transform and three two-note drains.

This is a hypothesis, not evidence. The precommitted behavioral thresholds,
session protocol and eventual decision live only in
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md).
