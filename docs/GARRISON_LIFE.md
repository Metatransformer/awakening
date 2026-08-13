# Garrison life

This document owns the garrison's civil rhythm, the built Firewood/Hearth and
fishing/provisions rules, derived morale, and the bounded raid proof. Detailed
descent economy belongs to [METAGAME.md](METAGAME.md); playtest criteria belong
to [design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md) and
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md).

## Home rhythm

The Highbridge garrison is a working expedition, not a menu ring or town
simulation. Its compact walled service compound and the wooded homestead between
the south gate and the Sunken Cut are one continuous surface: the player walks
through the raised portcullis and over the timber bridge without a loading seam.
The player walks to services, sees residents follow routines, and experiences
home as a contrasting mode between descents.

The civil clock is the only owner of day and time:

- **Daytime, 05:00–20:00:** residents work, services follow their established
  opening hours, and the outskirts grove can be worked.
- **Bonfire Time, 20:00–23:00:** services close; arrived residents gather at the
  central hearth and remain available for conversation.
- **Bedtime, 23:00–05:00:** residents retire to their authored sleeping places
  and the yard closes.

The personal bed is identified by its **SLEEP IN YOUR BED** prompt, focused
quilt glow, and warm motes. It offers **Sleep until nightfall** and **Sleep until
morning**.
Nightfall is the next strictly future 20:00; morning settles at 07:00, or 06:00
with Early Reveille. Before applying either jump, sleep pauses the world for a
2.4-second analog-clock presentation whose hands sweep linearly from the start
to the target. Sleeping and forward time jumps then resolve every crossed
boundary once. Save/load restores the current result without replaying it.
Weather and lighting share this civil day; they do not create a second calendar
or simulation.

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
- The top-right column shows a player-following minimap in authored exterior
  zones and the discovered dungeon floor plan underground. Directly beneath it,
  compact companion strips show **Day X**, the current time and moving sun/moon
  track, plus 15-degree heading ticks and eight compass points beneath a fixed
  player-bearing pointer.
- A sleep or time jump that crosses a boundary presents it once. Loading a save
  does not replay a boundary already resolved.

The raid horn is not a nightfall cue. It belongs only to the urgent raid alarm,
so ordinary evenings remain warm rather than falsely threatening. The reusable
ceremony is implemented and verified in the real garrison; it remains separate
from the raid proof.

The existing read-only Garrison page reports time, the next phase, carried
Firewood and aggregate Food cargo, stored Firewood/Hearth and Food/supper state,
Well Fed readiness, overall and per-resident morale with its causes, residents
and their activities, and active garrison effects. It points carried provisions
to the south-gate supply box and performs no remote action. Ordered duty state
is no longer duplicated there: the adjacent read-only Quests page owns that
question.

## Firewood and Hearth

Firewood is built and valid. It is a supporting warm-home vignette, not the
active proof and not a prerequisite for the raid.

- After Brannoc arrives, Aldric offers **Keep the Hearth**. `!` moves from
  Aldric to Brannoc, the current grove tree, and the supply box as each objective
  becomes current; READY returns `?` to Aldric until the player turns it in.
- Brannoc forges the permanent Woodsman's Axe for 60 gold and three Iron Scrap.
  It is a utility tool, not a weapon or hand slot.
- The wooded homestead clearing between the garrison bridge and the visible
  Sunken Cut mine holds a dense west-side grove of individually harvestable
  trees. Holding at one with the axe plays the work, fells that trunk to a
  stump, spends one use only at the successful impact, and yields at most one
  exact **Firewood Bundle** per campaign day during Daytime. The bundle enters
  the Run bag, stacks to **five per slot**, and is carried to the supply box just
  inside the south gate.
- The hearth stores at most three bundles and consumes at most one at Bonfire
  Time.
- A fueled bonfire grants Warmth for the next service window; an unfueled
  bonfire removes it. Chopping or depositing never changes prices immediately.
- Warmth affects only ordinary two-sided Trade. Permanent upgrades, crafting,
  artifacts, extraction, and other progression costs remain outside it.
- Arrived residents gather around a fueled or empty hearth alike. The social
  moment is not conditional on earning the economic benefit.

Carried Firewood persists in the home Run snapshot until deposited. Depositing
after a bonfire does not retroactively fuel it. A full hearth does not prevent
the daily tree from being worked: the supply box fills the remaining Firewood
capacity, leaves exact overflow in the bag, and accepts it after space opens.
Every harvestable tree still refuses work when the axe, time, daily availability,
or bag capacity rule is not satisfied; the grove is world interaction, never a
remote menu action.

The exact item, service, and economy contracts remain with
[ITEMS.md](ITEMS.md), [METAGAME.md](METAGAME.md), and
[CONTRACT.md](CONTRACT.md).

## Fishing and provisions

Exactly one spring-fed fishing pond on the east side of the garrison outskirts
owns the fishing interaction. Its dock, rod rack, creel, and water make the
opportunity readable. A river dock and south pond are scenic landmarks only:
they do not add interactions, catches, reserves, or another fishing mode. The
garrison bridge is the physical route between the compound and homestead;
cliffs, watercourses, and the enclosing mountain terrain bound the authored
surface. Brannoc forges or fully reforges the east pond's
durable Fishing Rod for 45 gold, one Iron Scrap, and one deposited Firewood
Bundle. It has ten uses, remains known and **BROKEN** at zero, and is not a
weapon, hand slot, bag item, wheel item, sale good, or combat verb.

Interacting enters **CASTING** directly; there is no target or species selection.
Releasing the cast rolls one named fish from the pond's spot-level table, then
the player reacts to its bite and reels while steering against its run and
managing tension. Water ripples are the bite language: quiet pulses mark the
wait and a bright, fast expansion counts down that species tier's hook window.
Once hooked, one dominant arrow shows the counter-steer input direction rather
than the fish's travel; its color reacts to correct or wrong steering beside
compact **TENSION** and **LAND** bars. A released reel safely eases tension, but
the fish steadily takes line back and the **LAND** bar recedes; easing is
recovery with a cost, not banked progress. Higher tiers strictly narrow the hook
window, change runs faster, begin at greater tension, recover more slowly, reel
in more slowly, escape faster, and gain more tension from neutral or wrong
steering.

The level-1 pond table is canonical:

| Species | Tier | Level-1 weight | Hook window |
|---|---:|---:|---:|
| Pond Shiner | 1 | 75 | 1.20 s |
| River Perch | 2 | 20 | 1.00 s |
| Silver Trout | 3 | 4 | 0.82 s |
| Crown Pike | 4 | 1 | 0.68 s |

A landed catch card names the exact species and shows one to four tier pips; an
escape or snapped line has a distinct failure emblem. Semantic bite, catch, and
failure SFX route through the shared pool. Authored cast, bite, hook, neutral
reel, directional strain, catch, and failure recordings voice the full attempt
without changing the interaction. Every species is exact Food cargo worth one
supper unit, stacks by its own ID to **six per bag slot**, has no sale value, and
leaves the bag only through the south-gate supply box. The resource rules are
exact:

- Food reserve capacity is **three units**, representing three suppers.
- At most **three Fish units per campaign day** may be caught. The daily cap is
  recorded at the catch; the garrison reserve is not.
- Stored reserve capacity never prevents fishing while the bag has room. A
  deposit fills only the remaining reserve capacity and leaves every overflow
  species and count exact in the bag.
- A successful or failed attempt advances the civil clock by **ten minutes**
  and spends one Rod use. Cancelling exits lawfully, advances no time, and
  spends no durability.
- At **20:00**, supper consumes at most one stored Food unit. A served supper makes
  the current Fed cause active and prepares Well Fed. An empty supper clears
  the current Fed cause but does not erase a previously prepared, unused Well
  Fed meal.

Well Fed applies to the next new descent only. Beginning that descent consumes
the prepared state and grants **+15 temporary maximum stamina** for the trip.
The active trip state survives a resumable dungeon save, then clears on
extraction or death. The bonus sits outside permanent Focus progression and
never becomes a purchase, upgrade rank, or permanent saved maximum.

The south-gate supply box is the single deposit transaction for both categories.
It stores at most three Firewood and three Food units, reports exact moved counts,
and makes a full no-op without deleting overflow cargo. Home saves preserve the
whole Run snapshot so undeposited provisions survive save/load. Beginning a new
descent deliberately starts a new Run and clears that home bag, so cargo must be
deposited before setting out if the player wants it added to garrison stores.

## Garden and orchard

The fenced garrison garden contains exactly **four** reusable crop beds and
**two** permanent fruit-tree sites. Gardening is a small civil-day responsibility,
not a remote timer menu: the quartermaster sells stackable planting stock, the
player plants it from the ordinary bag, and each live site physically shows bare
soil, wet soil, growth, ripe produce, young trees, mature crowns, and fruit.

The starting catalogue is deliberately narrow:

| Planting stock | Result | Watered dawns to grow | Harvest |
|---|---|---:|---:|
| Turnip Seed | Turnip | 2 | 1 |
| Cabbage Seed | Cabbage | 3 | 1 |
| Sunpepper Seed | Sunpepper | 4 | 1 |
| Apple Sapling | Apple tree | 4 | 2 Apples every 3 dawns |
| Pear Sapling | Pear tree | 5 | 2 Pears every 4 dawns |

A crop or young tree advances once at dawn only if it was watered, then dries.
Missed water costs a day but never kills or regresses the plant. A ripe crop
stays in its bed until picked; harvesting empties that bed for another seed.
Fruit trees remain planted after maturity, require no further watering, and
produce again on their authored cadence after each pick. Planting consumes one
exact seed or sapling. Harvesting is atomic: if the full yield does not fit, the
produce stays visibly ready rather than being partly lost.

Turnips, Cabbages, Sunpeppers, Apples, and Pears enter the ordinary Run bag as
named, stackable, zero-sale-value **Food** cargo. They are not eaten directly and
the vendor does not list them. Like fish, the player carries them to the one
south-gate supply box; all nine fish-and-garden IDs share the same three-meal Food
reserve, supper, Fed morale cause, and Well Fed preparation. The Garrison page
reports planted, thirsty, ripe, growing-tree, mature-tree, and fruit-ready counts
without mutating them. Garden state, tree maturity, and next-fruit days persist
inside the garrison save snapshot.

## Morale and care

Resident morale is derived from three visible causes rather than stored as a
separate economy:

- **Warm** is active when the last resolved bonfire was fueled.
- **Fed** is active when the last resolved supper served Fish.
- **Connected** is active after a substantive authored conversation through
  that campaign day and the following day. Repeated greetings and opening a
  service do not refresh it.

For each arrived resident, zero, one, two, or three active causes read as
**Low**, **Uneasy**, **Steady**, or **High** morale. The Garrison page also
reports an aggregate qualitative label across arrived residents. These labels
communicate care; they do not lock services, modify prices, kill or remove
residents, create relationship levels, or start a failure spiral.

## Builder and Elder

The one authorised sixth resident is an unvoiced Vyr Builder using the existing
generic Vyr body and shared service patterns. She has written greeting/leave
text and a painted dialogue portrait so her quest rows use the ordinary
conversation composition without adding recorded lines.

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
horn at 23:00, and interrupts sleep when the attack boundary is crossed; an
interrupted sleep grants no recovery and requests no autosave.
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

Arming the occurrence offers **West Gate Defence** at the Builder. Her `!`
remains while the bolt-thrower is the current target, becomes `?` after the real
works-board purchase, and clears only when the player chooses the turn-in row.

The complete authored slice and evidence rules live in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Expansion gates

- The bounded Firewood and fishing/provisions loop does not authorise another
  chore, fishing location, gathering profession, relationship ladder, town
  economy, or freeform base builder.
- Implementing one raid does not authorise recurrence.
- No scouts, watchtowers, guards, staffing, morale-based service locks or
  relationship progression, multiple raid routes or waves, additional
  defenses, destructible buildings, or barrel interactions are authorised.
- A human result may authorise the next design decision. It never authorises
  expansion automatically; [SCOPE.md](SCOPE.md) must change explicitly.
