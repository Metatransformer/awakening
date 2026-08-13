# Scope

[GDD.md](GDD.md) says what the game is. This document says how much may be
built. [NOW.md](NOW.md) is narrower still: it authorises the current work.

The cap is a ceiling, not a backlog. A feature can fit the game and remain
unauthorised.

## Hard caps

| Surface | Cap |
|---|---:|
| Dungeon floors | **4**, plus the existing post-credits endless mode |
| Bosses | **4**, three beats each, one health bar, two behaviour phases |
| Minibosses | **4**, one per floor, two beats each, two behaviour phases |
| Enemy kinds in rotation | **9** |
| New monster models | **0** |
| Dungeon kits | **1**, used in four tints |
| Usable items | **6** |
| Durable utility tools | **3**: Woodsman's Axe, Pickaxe, Fishing Rod |
| Right-hand ring stops | **6** |
| Kit wheel slots | **8** |
| New gameplay mechanics | **4**: working, puzzle, daily-life loop, authored raid |
| Locked doors | **8** |
| Vault prefabs | **3** |
| Puzzle atoms | **9** |
| Puzzle prefabs | **12** |
| Puzzle combinators | **9** |
| Enemy behaviours | **8**, with four currently committed |
| Added dungeon graph edges | **1 per floor** |
| Blessings | **12** |
| Relics | **12** |
| Garrison NPCs | **6**: the existing five plus one Vyr Builder |
| Authored build quests | **1**: West Gate Bolt-Thrower |
| Authored defensive structures | **1**: West Gate Bolt-Thrower |
| Authored raid occurrences | **1**, with no scheduler |
| Player stats | **5** |
| Upgrade tracks | **26**: the existing 23 plus 3 one-rank Field Notes doctrines |
| Armour pieces | **4** |
| Jewelry slots | **4** |
| Armour or jewelry art | **0** |
| Garrison surface scenes | **2** |
| New UI screens | **3** |
| Endings | **2** |
| Currencies | **2**: gold and Field Notes |
| Ingredients / components | **10 / 8**, with no new rarity band |
| Forge ladders | **12** |
| Draughts | **3** |
| Dialogue trees | **0** |
| Voiced lines | **15** |
| Gameplay cutscenes | **1 reusable item-get ceremony** |

The raid amendment changes no currency, UI-screen, voiced-line, enemy-kind, or
enemy-model cap. The Builder is unvoiced, uses the existing generic Vyr body,
and uses shared service patterns. The raid reuses kobolds, an orc, the main
gate, and existing resources.

The daily-life loop already counted in the four-mechanic cap contains the built
Firewood/Hearth vignette and exactly one owner-authorised fishing/provisions
slice: one pond and minigame, persistent Fish, derived Morale, and the temporary
Well Fed state. This consumes the existing daily-life-loop count; it is not a
fifth gameplay mechanic and does not raise any other cap.

Issue #184 is the explicit owner override for the three durable utility tools
named above and one bounded mining rule: independent deterministic vein chances
in ordinary non-entrance, non-maze rooms, paying only existing Iron Scrap,
Riveted Plate, or Tension Coil. Utility tools are not usable items, ring stops,
wheel slots, bag or locker goods, armaments, currencies, or combat equipment.
The amendment adds no room, gate, map marker, reward id, UI screen, or broader
profession system. Its bounded resource-working extension remains inside the
already-counted daily-life-loop mechanic and does not raise the four-mechanic
cap.

The Field Notes amendment adds one finite, non-convertible permanent currency
and three one-rank doctrine tracks. It adds no item, pickup, UI screen, NPC,
stat category, dialogue tree or repeatable system. The exact five-observation,
five-note boundary is owned by [FIELD_NOTES.md](FIELD_NOTES.md).

Issue #203 amends boss behaviour without raising a content cap: the roster stays
at four bosses and four minibosses, uses zero new monster models, adds no item,
and retains the existing five attack shapes. “One phase” is no longer the cap.
Each row has one health bar and two behaviour phases at half health; phase 2
reuses the same three boss beats or two miniboss beats while increasing movement
and selection pressure. Only full bosses turn the arena. Exact mappings and
cycle counts are owned by [BOSSES.md](BOSSES.md), and the evidence boundary is
[design-tests/BOSS_DYNAMISM_PROOF.md](design-tests/BOSS_DYNAMISM_PROOF.md).

Counts rise only through an explicit scope amendment. By default, an addition
must delete something of comparable cost in the same decision. Implementing a
feature does not authorise another instance, variant, or supporting system.

## Now

Two bounded proofs are authorised:

- The raid slice in
  [design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md) is
  implementation-complete and awaits five cold human sessions:

  - one Builder;
  - one optional Bolt-Thrower project;
  - one warning sequence;
  - one wave through one route;
  - one manual-defense case and one absence-resolution rule;
  - one recoverable Tally-Ledger theft;
  - one occurrence.

- Field Notes implementation under
  [issue #112](https://github.com/Metatransformer/awakening/issues/112) is
  authorised within [FIELD_NOTES.md](FIELD_NOTES.md): five fixed first-time
  Cistern observations, five total debrief-awarded notes and three one-rank
  doctrines costing two notes each. Its dedicated human test is
  [design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md).

Issue #168 is separately owner-authorised implementation sequencing debt:
exactly one pond/minigame in the existing outskirts, the three-meal Fish reserve
and daily yield, supper-derived Fed state, Warm/Fed/Connected morale, one-descent
Well Fed state, and their read-only presentation on the existing Garrison page.
Its future test is
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md),
but it does not supersede the authorised human proofs above.

Issue #184 is separately owner-authorised implementation sequencing debt:
three forgeable/reforgeable durable utility tools and deterministic depletable
veins under [design-tests/MINING_TOOLS_PROOF.md](design-tests/MINING_TOOLS_PROOF.md).
It supersedes the prior mining and fishing-gear exclusion only for that fixed
slice. It does not supersede the authorised human proofs above or satisfy the
near/deep evidence bar in
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md).

Issue #203 is separately owner-authorised boss/miniboss refinement and proof.
It may change only the behaviour and evidence for the existing four-plus-four
roster inside the attack, model, item, and floor caps above. Runtime
implementation and the dedicated automated gate pass; the five-session human
gate remains tracked in
[design-tests/BOSS_DYNAMISM_PROOF.md](design-tests/BOSS_DYNAMISM_PROOF.md).

Raid, Field Notes, fishing/provisions, #184's bounded tool/mining implementation,
and #203's boss runtime refinement are present; their precommitted human tests
remain pending. Floors 2–4 production content, any fifth boss or miniboss, any
new boss model/item/attack shape, another fishing location or minigame, and
every expansion below remain frozen.

## Later, only if proven

These are candidates, not promises:

- production work that stays inside the caps above;
- recurring raids;
- scouts, watchtowers, guards, staffing, or broader morale consequences;
- more waves, routes, attackers, or defensive structures;
- the explosive-barrel and hanging-lantern interaction family;
- another home-life responsibility, resource-gathering loop, or profession.

Each needs its own design question, smallest proof, and explicit scope decision.
A passed raid test authorises planning; it does not automatically authorise this
list.

## Not planned

- Freeform construction, building placement, destructible buildings, or a
  settlement simulation.
- A second garrison, open overworld, alternate dungeon, or fifth floor.
- Multiplayer or co-op.
- Joinable factions, character creation, races, classes, or skill trees.
- Farming, hunting, broader mining or cooking systems, mounts, romance, fishing
  gear beyond #184's single durable rod, collections, profession expansion, or
  a housing economy.
- A spell school, spell levels, a fourth working, or a seventh ring stop.
- Procedural bosses, a second dungeon kit, or new monster models.
- Relics as random drops, sellable relics, or permanent loss of a unique relic.
- Level-scaled enemies, underground healing drops, dungeon-accessible storage,
  free fast travel, or a checkpoint/rewind history.
- A special raid teleport, summon, or free extraction.
- New Game+, ascension, prestige, daily challenges, or a third ending.
- Linux, console, localization, or Steam Deck verification for the first
  release.

## Production freeze

The current build contains more implemented work than has been validated by
human evidence. That is sequencing debt, not permission to continue.

Do not expand production until the pending five-session human tests are
resolved.
Directors and automated checks can prove implementation; only observed human
play can answer each design question. A result from one cannot prove another.
After a result, update the owning design test first, then amend current canon
only where the decision requires it.
