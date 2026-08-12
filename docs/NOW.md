# Now

**Stage: Pre-production — Raid Loop and Field Notes Proof**

## Pending Raid Loop human question

> When warned that the garrison will be raided, does the player make a deliberate
> stay-versus-extract decision, and does one built defense change that decision
> in a way they can explain?

The Fair-Weights Forge / smith quest was superseded by the raid pivot before any
human sessions were run. That supersession does not apply to Field Notes.

Implementation is complete and awaiting the precommitted five cold sessions.
The raid test and its criteria are in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Implemented raid slice awaiting test

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

## Authorized Field Notes implementation

> Do players connect awarded notes to observed Cistern events, compare finite
> doctrines, notice the chosen effect, and name another observation or doctrine
> as a reason to descend again?

Field Notes are authorised dungeon progression work under
[issue #112](https://github.com/Metatransformer/awakening/issues/112).
Implementation and deterministic proof are complete; its five cold human
sessions remain pending.
The canonical bounded system is [FIELD_NOTES.md](FIELD_NOTES.md); the
precommitted human gate is
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md).

Implement exactly five fixed first-time Cistern observations, debrief awards on
extraction or death, five total permanent notes and three one-rank doctrines at
Aldric costing two notes each. Reuse the existing receipt, service and save
surfaces. This authorises no production floors, additional observations,
additional doctrines, repeatable faucet, checklist, item or new screen.

## Frozen

- Recurring raids or a recurrence scheduler.
- Scouts, watchtowers, guards, staffing, or morale systems.
- Multiple waves, routes, raid types, or defensive structures.
- Freeform construction or placement.
- Destructible buildings.
- The explosive-barrel and hanging-lantern interaction system.
- Any currency beyond gold and Field Notes, UI screen, voiced line, or enemy
  model.
- Floors, bosses, production content, broad lore, or unrelated polish.

Implementation proves only that each bounded system works. It does not prove
either human hypothesis. Expansion remains frozen until the pending human tests
are resolved and [SCOPE.md](SCOPE.md) is amended.
