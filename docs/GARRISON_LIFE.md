# Garrison life

This document owns the garrison's civil rhythm, the built Firewood/Hearth
vignette, and the bounded raid proof. Detailed descent economy belongs to
[METAGAME.md](METAGAME.md); playtest criteria belong to
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Home rhythm

The Highbridge garrison is a working expedition, not a menu ring or town
simulation. The player walks to services, sees residents follow routines, and
experiences home as a contrasting mode between descents.

The civil clock is the only owner of day and time:

- **Daytime, 05:00–20:00:** residents work, services follow their established
  opening hours, and the Timber Yard can operate.
- **Bonfire Time, 20:00–23:00:** services close; arrived residents gather at the
  central hearth and remain available for conversation.
- **Bedtime, 23:00–05:00:** residents retire to their authored sleeping places
  and the yard closes.

Sleeping and forward time jumps resolve every crossed boundary once. Save/load
restores the current result without replaying it. Weather and lighting share
this civil day; they do not create a second calendar or simulation.

### Day and night ceremony

Dawn and nightfall each use the same five-second, full-screen transition. The
world pauses for the whole presentation; it is a title card, not five seconds
of hidden simulation.

- At **20:00**, show **“Night falls”** and **“Day X”**, with a tawny-owl call.
- At **05:00**, show **“The sun rises”** and **“Day X”**, with a morning-bird
  song.
- The compact clock widget always shows both **Day X** and the current time.
- A sleep or time jump that crosses a boundary presents it once. Loading a save
  does not replay a boundary already resolved.

The raid horn is not a nightfall cue. It belongs only to the urgent raid alarm,
so ordinary evenings remain warm rather than falsely threatening. This
presentation is specified here but belongs to its own implementation card, not
the raid proof.

The existing read-only Garrison page reports time, the next phase, current
Firewood/Hearth state, residents and their activities, and active garrison
effects. It performs no remote action.

## Firewood and Hearth

Firewood is built and valid. It is a supporting warm-home vignette, not the
active proof and not a prerequisite for the raid.

- After Brannoc arrives, Aldric assigns **Keep the Hearth**.
- Brannoc's permanent Woodsman's Axe is a tool, not a weapon or hand slot.
- The Timber Yard yields at most one carried bundle per campaign day during
  Daytime. The player must carry it to the separate hearth.
- The hearth stores at most three bundles and consumes at most one at Bonfire
  Time.
- A fueled bonfire grants Warmth for the next service window; an unfueled
  bonfire removes it. Chopping or depositing never changes prices immediately.
- Warmth affects only ordinary two-sided Trade. Permanent upgrades, crafting,
  artifacts, extraction, and other progression costs remain outside it.
- Arrived residents gather around a fueled or empty hearth alike. The social
  moment is not conditional on earning the economic benefit.

A carried bundle persists until deposited. Depositing after a bonfire does not
retroactively fuel it. The yard refuses work when the axe, time, daily
availability, carrying capacity, or hearth capacity rule is not satisfied.

The exact item, service, and economy contracts remain with
[ITEMS.md](ITEMS.md), [METAGAME.md](METAGAME.md), and
[CONTRACT.md](CONTRACT.md).

## Builder and Elder

The one authorised sixth resident is an unvoiced Vyr Builder using the existing
generic Vyr body and shared service patterns.

- **Builder:** mechanisms, buildings, and the one West Gate Bolt-Thrower
  project.
- **Aldric:** command, scouts, guards, staffing, and morale.

This split prevents the Builder from becoming a second commander and prevents
Aldric's dialogue from becoming a construction catalogue. Only the Builder and
the Bolt-Thrower are authorised; the ownership split does not authorise the
systems named under Aldric.

## One-raid prototype

Raid gameplay is not implemented. The active prototype is one authored
occurrence armed by donation of the Tally-Ledger.

It provides an afternoon warning and an urgent 23:00 horn alarm that can
interrupt sleep. Underground players choose between continuing and the
ordinary Escape Rope; the raid never summons, teleports, or grants free
extraction.

The player may build one optional West Gate Bolt-Thrower with existing
resources. A present player fights the single attack manually. If absent, the
Bolt-Thrower holds; without it, the garrison loses. Failure removes the
Tally-Ledger's benefit, leaves its mount visibly empty, and returns it to its
original dungeon location. Recovering it restores the existing donation without
a second repair cost.

The complete authored slice and evidence rules live in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Expansion gates

- Firewood does not authorise another chore, relationship ladder, profession,
  town economy, or freeform base builder.
- Implementing one raid does not authorise recurrence.
- No scouts, watchtowers, guards, staffing, morale, multiple routes, multiple
  waves, additional defenses, destructible buildings, or barrel interactions
  belong to this slice.
- A human result may authorise the next design decision. It never authorises
  expansion automatically; [SCOPE.md](SCOPE.md) must change explicitly.
