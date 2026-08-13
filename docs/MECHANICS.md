# Player-facing mechanics map

This file is a compact map of the decisions the current game asks the player
to make. It is not a status ledger, item catalogue, numerical specification,
or implementation contract.

Most importantly, this map is **not an authorization surface**:

- [NOW.md](NOW.md) names the only work authorised now.
- [SCOPE.md](SCOPE.md) caps the game and freezes expansion.
- [GDD.md](GDD.md) owns the north-star intent.
- [MDA.md](MDA.md) owns causal hypotheses about mechanics, dynamics, and
  aesthetics; those hypotheses are not repeated per mechanic here.

Follow the named owner for exact rules. Implementation units, inputs, and
interfaces belong to [CONTRACT.md](CONTRACT.md).

## Movement and combat

| Decision family | Player-facing question | Detail owner |
|---|---|---|
| Camera-relative movement | How quickly and precisely should I cross the current space? | [CONTRACT.md](CONTRACT.md) |
| Stamina economy | Is this run, dodge, guard action, jump, or committed attack worth the mobility it spends? | [CONTRACT.md](CONTRACT.md) |
| Targeting and facing | Which threat do I frame, and am I facing it well enough to defend? | [CONTRACT.md](CONTRACT.md) |
| Dodge, block, and parry | Do I evade, absorb inside the shield arc, or risk timing a punish? | [CONTRACT.md](CONTRACT.md), [BESTIARY.md](BESTIARY.md) |
| Sword commitments | Do I stop or continue the light chain, finish the two-hit Heavy combo, hold for the magic spin, or slam from the air? | [CONTRACT.md](CONTRACT.md) |
| Ranged and item answers | Is distance, armour, a group, or room geometry worth spending a prepared tool on? | [ITEMS.md](ITEMS.md), [PUZZLES.md](PUZZLES.md) |
| Enemy grammar | Can I read the wind-up, committed beat, recovery, formation, and disengagement route? | [BESTIARY.md](BESTIARY.md) |
| Boss grammar | What authored fight rule must I learn, and when does mastery open a permanent route or verb? | [BOSSES.md](BOSSES.md) |
| Heat tempo | Do I chase the next kill and cooling loot, or protect health and let the chain fall? | [METAGAME.md](METAGAME.md) |
| Mercy | Do I enable bounded resistance after repeated deaths without changing encounters or rewards? | [GDD.md](GDD.md), [CONTRACT.md](CONTRACT.md) |

Combat uses integer HP damage through one health path. Attacks have readable
commitment and recovery; defence depends on position, facing, and timing rather
than passive equipment alone. A blow taken is readable the same way: its weight
and the direction it came from are legible in the reaction, without reading the
health bar. Packs spread and leash so disengagement and ordinary extraction
remain possible choices.

Enemy variants and boss beats are content inside these families, not separate
mechanics in this map.

## Kit and items

| Decision family | Player-facing question | Detail owner |
|---|---|---|
| Two hand loadouts | Which prepared left- and right-hand pairing answers the next room? | [CONTRACT.md](CONTRACT.md) |
| Rings and kit wheel | Which owned item do I make quickly reachable without increasing capacity? | [CONTRACT.md](CONTRACT.md) |
| Sword, shield, bow, and hookshot | Do I commit to close combat, active defence, ranged precision, or changing distance? | [ITEMS.md](ITEMS.md) |
| Workings | Is a charge worth destruction, preserving Heat, or sacrificing carried value for safety? | [ITEMS.md](ITEMS.md) |
| Arrows and charges | Do I buy, craft, find, conserve, or spend a finite trip supply? | [METAGAME.md](METAGAME.md) |
| Bottles and draughts | Which finite heal or timed effect do I prepare, carry, and consume? | [METAGAME.md](METAGAME.md) |
| Rations | Is the room safe enough to risk slow, interruptible recovery? | [METAGAME.md](METAGAME.md) |
| Durable utility tools | Which work deserves a finite Axe, Pickaxe, or Fishing Rod use, and when is a full-cost reforge justified? | [ITEMS.md](ITEMS.md), [METAGAME.md](METAGAME.md) |
| Relics | Is a unique, exposed, unsellable discovery worth the slot and extraction cost? | [ITEMS.md](ITEMS.md) |
| Echoes | Which temporary rule bend is worth a bag slot for this run? | [PUZZLES.md](PUZZLES.md) |

[ITEMS.md](ITEMS.md) is the catalogue owner. It defines the six usable-item
roles, relics, stocks, and what deliberately is not an item. This map does not
duplicate each item, Echo, relic, recipe, or numerical cap.

## Run, risk, and extraction

| Decision family | Player-facing question | Detail owner |
|---|---|---|
| Finite bag | Which stack earns scarce space, and what do I visibly leave behind? | [METAGAME.md](METAGAME.md) |
| Document case | Which eligible stacks deserve the three protected cells? | [METAGAME.md](METAGAME.md) |
| Reward lanes | Do I want safe gold, saleable ingredients, bench components, or a unique artifact consequence? | [METAGAME.md](METAGAME.md), [ITEMS.md](ITEMS.md) |
| Heat premium | Do I maintain tempo long enough to collect boosted value before it cools? | [METAGAME.md](METAGAME.md) |
| Change floors | Is another floor worth carrying current exposure deeper, or should I retrace the same live trip toward the entrance? | [METAGAME.md](METAGAME.md) |
| Ordinary Escape Rope | Can I create enough safety to commit to the hold, channel, and known fee? | [METAGAME.md](METAGAME.md) |
| Entrance extraction | Is walking back to floor 1's up stair preferable to paying the same settlement through the portable rope? | [METAGAME.md](METAGAME.md) |
| Extraction outcome | Is banking the full haul while carrying current health home worth the gold charge now? | [METAGAME.md](METAGAME.md) |
| Death outcome | What exposed value was lost, what did the case protect, and what recovery goal follows? | [METAGAME.md](METAGAME.md) |
| Receipt | Can I attribute the result to the stacks, route, and risks I chose? | [METAGAME.md](METAGAME.md) |
| Save continuity | Can I stop and resume the current state without turning saving into a rewind? | [METAGAME.md](METAGAME.md) |

Gold, bag contents, case contents, components, and relics remain distinct. The
ordinary rope always resolves; a poor purse can make extraction expensive but
cannot trap the player underground. Ordinary extraction preserves current
health; rest and sleep are the normal garrison recovery seam.

## Dungeon and puzzles

| Decision family | Player-facing question | Detail owner |
|---|---|---|
| Finite expedition | How do I clear four authored floors and bosses before choosing post-credits endless descent? | [GDD.md](GDD.md), [SCOPE.md](SCOPE.md) |
| Variable routes, stable anchors | What can I infer from generated rooms around fixed gates, shortcuts, vaults, deep chests, and bosses? | [PUZZLES.md](PUZZLES.md) |
| Critical path | Which owned verbs must solve progression without producing an impossible seed? | [PUZZLES.md](PUZZLES.md) |
| Optional risk | Is a shortcut, vault, treasure branch, miniboss, or richer chest worth the detour? | [PUZZLES.md](PUZZLES.md), [BOSSES.md](BOSSES.md) |
| Puzzle atoms | What does this key, urn, plate, block, eye, pillar, ring, socket, or lantern respond to? | [PUZZLES.md](PUZZLES.md) |
| Puzzle composition | How do sequence, cycle, coupling, conversion, chaining, and reconfiguration relate those atoms? | [PUZZLES.md](PUZZLES.md) |
| Supply guarantees | Does a route that requires a consumable also provide a cold-start answer? | [PUZZLES.md](PUZZLES.md), [ITEMS.md](ITEMS.md) |
| Map knowledge | Which rooms and useful markers have I personally revealed, and what route does that knowledge support? | [CONTRACT.md](CONTRACT.md) |
| Guarded rewards | What must be fought, solved, or deliberately explored before a prize exists? | [CONTRACT.md](CONTRACT.md), [ITEMS.md](ITEMS.md) |
| Mining veins | Do I rely on incidental enemy Iron Scrap, or spend Pickaxe durability now for a more efficient physical stack of existing metal? | [METAGAME.md](METAGAME.md), [CONTRACT.md](CONTRACT.md) |

Puzzle atoms, combinators, prefabs, locks, and graph edges are capped content
inside this grammar. Their counts and production status belong to
[SCOPE.md](SCOPE.md), not this map.

## Garrison and progression

| Decision family | Player-facing question | Detail owner |
|---|---|---|
| Walk-up services | Which resident or physical place turns this haul into the next capability? | [METAGAME.md](METAGAME.md) |
| Trade and storage | What do I sell, protect for a recipe, or place in finite home storage before the next trip? | [METAGAME.md](METAGAME.md) |
| Supplies versus permanence | Do I spend gold on the next trip, bag/health capacity, or a lasting ladder rung? | [METAGAME.md](METAGAME.md) |
| Field Notes and doctrines | Which observed Cistern lesson earned this note, which finite doctrine do I choose, and what specific lesson would bring me back? | [FIELD_NOTES.md](FIELD_NOTES.md) |
| Forge and jewellery paths | Which mutually exclusive equipment direction fits how I play, and when is reversal worth its loss? | [METAGAME.md](METAGAME.md) |
| Alchemy | Which bottle capacity and draught recipe supports the next descent? | [METAGAME.md](METAGAME.md) |
| Artifacts | Which recovered relic do I repair or read, donate, and see change the garrison? | [ITEMS.md](ITEMS.md), [METAGAME.md](METAGAME.md) |
| Civil day | Which service can I reach before work, Bonfire Time, sleep, or dawn changes the yard? | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Firewood and Hearth | Is the bounded home responsibility worth completing for the next service window? | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Fishing and Fish reserve | Is a near or deep catch worth its difficulty, civil time, daily yield, and limited reserve space? | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Supper and Well Fed | Do I stock the next shared supper now for a temporary advantage on the following descent? | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Morale causes | Which visible acts of warmth, provision, and connection are currently supporting each resident? | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Residents and story | Who has arrived, what do they now know, and what has visibly changed because of progress? | [GARRISON_LIFE.md](GARRISON_LIFE.md), [LORE_AND_STORY.md](LORE_AND_STORY.md) |
| Rest and recovery | Do I close the day, accept its time cost, recover purchased benefits, and save? | [METAGAME.md](METAGAME.md), [GARRISON_LIFE.md](GARRISON_LIFE.md) |

The garrison is a lived place with bounded services, not a settlement-placement
or remote-management game. Upgrade tracks, residents, currencies, interfaces,
and home systems cannot expand beyond [SCOPE.md](SCOPE.md).

Issue #184 makes one preparation chain explicit: compare incidental enemy iron
with Pickaxe-funded mining; allocate Iron Scrap, Riveted Plate, and Tension Coil
between Brannoc's work and the Builder's Bolt-Thrower; chop and deposit a
Firewood bundle before asking Brannoc for a Fishing Rod; then decide when a worn
tool's remaining work justifies paying to reforge it to full. The tools never
enter hands, rings, the wheel, bag, locker, sale, armament, or combat decisions.

## Active proofs

The raid stay-versus-extract question remains pending in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md). Its current
authorization is stated in [NOW.md](NOW.md), and its home-side rules are owned
by [GARRISON_LIFE.md](GARRISON_LIFE.md).

The proof is one bounded authored occurrence. It tests whether a warning and
one optional defense create a deliberate, explainable choice. The warning does
not teleport, summon, or grant special extraction; an underground player keeps
the ordinary continue-or-Escape-Rope decision owned by
[METAGAME.md](METAGAME.md).

Raid gameplay is implemented and awaiting human observation. Its presence does
not authorize new variants or surrounding systems. The separately
owner-authorised fishing/provisions implementation is sequencing debt, not raid
evidence; its post-raid hypothesis is recorded in
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md).
Human observations, criteria, and eventual decisions stay in their design tests
rather than becoming status prose here.

Raid implementation is complete, but its five cold human sessions are pending.
Existing mechanics may be reused for the slice, but their presence does not
authorize new variants or surrounding systems.

The separate Field Notes question is pending in
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md), with the
bounded system owned by [FIELD_NOTES.md](FIELD_NOTES.md). Its implementation is
authorised under issue #112: five first-time observations, five total debrief
awards and three one-rank doctrines, with no repeatable faucet or new screen.
Neither implementation proves its human hypothesis. Observation, criteria and
eventual decisions stay in the dedicated design tests.

Issue #184's separate utility-tool and mining question is pending in
[design-tests/MINING_TOOLS_PROOF.md](design-tests/MINING_TOOLS_PROOF.md).
Its implemented access and cost changes do not validate fishing depth; the
near/deep hypothesis and evidence bar remain in the Fishing Provisions Proof.
