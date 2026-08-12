# Now

**Stage: Pre-production — Raid Loop Proof**

## Only active question

> When warned that the garrison will be raided, does the player make a deliberate
> stay-versus-extract decision, and does one built defense change that decision
> in a way they can explain?

The earlier Core Loop Proof was superseded by the base-defense pivot before any
human sessions were run. It has no pass or fail result.

Implementation is complete and awaiting the precommitted five cold sessions.
The active test and its criteria are in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Built slice awaiting test

Test exactly one implemented vertical slice:

- Trigger it after donation of the Tally-Ledger.
- Add one unvoiced Vyr Builder using the existing generic Vyr body and shared
  service patterns.
- Add one optional West Gate Bolt-Thrower build quest using existing gold and
  components.
- Give one afternoon warning and one urgent 23:00 warning; the urgent warning
  interrupts sleep.
- Let underground players continue or use the ordinary Escape Rope. The raid
  provides no summon, teleport, or free extraction.
- Run one attack through the main gate: three kobolds and one orc.
- Show authoritative GARRISON integrity in the normal HUD. Only completed
  attacks on the courtyard command standard reduce it; all raiders dead above
  zero wins, while zero with any raider alive is irreversible loss.
- Let the built bolt-thrower hold if the player is absent. Without it, absence
  fails the raid. A present player fights manually.
- On failure, suppress and return the donated Tally-Ledger to its original
  dungeon location. Recovery restores the donation without another repair cost.
- Allow the event to occur once. Do not add recurrence scheduling.

This slice may reuse existing enemies, currencies, UI, dialogue presentation,
services, and garrison spaces. It may add only what the slice requires.

## Frozen

- Recurring raids or a recurrence scheduler.
- Scouts, watchtowers, guards, staffing, or morale systems.
- Multiple waves, routes, raid types, or defensive structures.
- Freeform construction or placement.
- Destructible buildings.
- The explosive-barrel and hanging-lantern interaction system.
- New currency, UI screen, voiced line, or enemy model.
- Floors, bosses, production content, broad lore, or unrelated polish.

Implementation proves only that the slice works. Expansion remains frozen until
five human sessions resolve the active test and [SCOPE.md](SCOPE.md) is amended.
