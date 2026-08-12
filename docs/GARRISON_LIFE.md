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
  opening hours, and the outskirts grove can be worked.
- **Bonfire Time, 20:00–23:00:** services close; arrived residents gather at the
  central hearth and remain available for conversation.
- **Bedtime, 23:00–05:00:** residents retire to their authored sleeping places
  and the yard closes.

Sleeping and forward time jumps resolve every crossed boundary once. Save/load
restores the current result without replaying it. Weather and lighting share
this civil day; they do not create a second calendar or simulation.

The dawn boundary remains 05:00, but waking is a later settlement: deliberate
rest and the automatic dawn return both hand control back at the effective
service opening (07:00, or 06:00 with Early Reveille). Residents are already at
their counters when the player gets out of bed.

### Day and night ceremony

Dawn and nightfall each use the same three-second, full-screen transition. The
world pauses for the whole presentation; it is a staged civil-time card, not
three seconds of hidden simulation. One reusable component draws both variants:
an expanding field and horizon, then a rising sun or crescent, title, rule and
day, followed by the same eased exit. A quiet mechanical ticking bed follows
that animation beneath the louder owl or morning birds.

- At **20:00**, show **“Night falls”** and **“Day X”**, with a tawny-owl call.
- At **05:00**, show **“The sun rises”** and **“Day X”**, with a morning-bird
  song.
- The top-right civil instrument always shows **Day X**, the current time and a
  moving sun/moon day track. Its companion heading strip scrolls 15-degree ticks
  and eight compass points beneath a fixed player-bearing pointer.
- A sleep or time jump that crosses a boundary presents it once. Loading a save
  does not replay a boundary already resolved.

The raid horn is not a nightfall cue. It belongs only to the urgent raid alarm,
so ordinary evenings remain warm rather than falsely threatening. The reusable
ceremony is implemented and verified in the real garrison; it remains separate
from the raid proof.

The existing read-only Garrison page reports time, the next phase, current
Firewood/Hearth state, residents and their activities, and active garrison
effects. It performs no remote action.

## Firewood and Hearth

Firewood is built and valid. It is a supporting warm-home vignette, not the
active proof and not a prerequisite for the raid.

- After Brannoc arrives, Aldric assigns **Keep the Hearth**.
- Brannoc forges the permanent Woodsman's Axe for 60 gold and three Iron Scrap.
  It is a utility tool, not a weapon or hand slot.
- The cliff-partitioned outskirts between the garrison and the Sunken Cut holds
  a visible side grove of individually harvestable trees. Holding at one with
  the axe plays the work, fells that trunk to a stump, and yields at most one
  carried bundle per campaign day during Daytime. The player must carry it to
  the separate hearth.
- The hearth stores at most three bundles and consumes at most one at Bonfire
  Time.
- A fueled bonfire grants Warmth for the next service window; an unfueled
  bonfire removes it. Chopping or depositing never changes prices immediately.
- Warmth affects only ordinary two-sided Trade. Permanent upgrades, crafting,
  artifacts, extraction, and other progression costs remain outside it.
- Arrived residents gather around a fueled or empty hearth alike. The social
  moment is not conditional on earning the economic benefit.

A carried bundle persists until deposited. Depositing after a bonfire does not
retroactively fuel it. Every harvestable tree refuses work when the axe, time,
daily availability, carrying capacity, or hearth capacity rule is not
satisfied; the grove is world interaction, never a remote menu action.

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

The implemented prototype is one authored occurrence armed by donation of the
Tally-Ledger and scheduled for the next day. It warns at 15:00, sounds the raid
horn at 23:00, and interrupts sleep when the attack boundary is crossed.
Underground players choose between continuing and the ordinary Escape Rope;
the raid never summons, teleports, or grants free extraction.

One wave of three kobolds and one orc follows the main-gate route to the
courtyard command standard. Only a completed attack on that objective reduces
GARRISON integrity. A present player fights manually; away resolution uses the
same authoritative wave. Killing every raider above zero wins. Reaching zero
while any raider lives is an irreversible loss, even if the remaining raiders
later die. Saving, leaving, and returning preserve the surviving wave,
integrity, and result.

The player may build one optional West Gate Bolt-Thrower with existing
resources. It holds when the player is absent; without it, absence loses the
raid. Loss steals the Tally-Ledger, suppresses its benefit, leaves its mount
empty, and returns it to its original dungeon location. Recovery restores the
donation without another repair cost. The occurrence never repeats.

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
