# Scope

[GDD.md](GDD.md) says what the game is. This document says how much may be
built. [NOW.md](NOW.md) is narrower still: it authorises the current work.

The cap is a ceiling, not a backlog. A feature can fit the game and remain
unauthorised.

## Hard caps

| Surface | Cap |
|---|---:|
| Dungeon floors | **4**, plus the existing post-credits endless mode |
| Generated rooms per authored floor | **8 / 11 / 12 / 13** on floors 1–4 |
| Bosses | **4** |
| Minibosses | **4**, one per floor |
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
| Mandatory Small Key loops | **4**, one floor-scoped combat-detour loop per authored floor |
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

Issue #199 is an explicit owner-authorised vertical expansion alongside the
freeze. It raises the authored floor totals to **8 / 11 / 12 / 13**; every added
room is combat only; and exactly one added combat detour per floor awards that
floor's Small Key before the player cycles back to spend it at a locked
critical-path gate. It also authorises live ordinary/Boss lock and key telemetry
on the existing two map surfaces, counted Escape Rope stock, and sparse
combat-room clear rewards drawn only from Escape Rope, Hardtack and Small Beer.
It authorises no fifth floor, new enemy, direct health drop, new map, new
currency, extra key loop, or non-combat added room.

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

Issue #199 is separately owner-authorised implementation sequencing debt: the
fixed 8/11/12/13 combat-expanded floor shapes, one floor-key loop per authored
floor, sparse counted provision clear rewards, shared map lock/key telemetry,
and counted Escape Rope named above. It does not supersede or satisfy either
active human proof.

Raid, Field Notes, fishing/provisions, #184's bounded tool/mining work, and
#199's bounded dungeon/provision expansion are implementation-complete; their
applicable precommitted human tests remain pending.
Floors 2–4, bosses 2–4, production content, another fishing location or
minigame, and every expansion below remain frozen.

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
- Level-scaled enemies, direct underground health or magic drops,
  dungeon-accessible storage, free fast travel, or a checkpoint/rewind history.
  Issue #199's sparse counted Hardtack and Small Beer provision stock is the
  narrow exception: it still requires the ordinary interruptible meal and does
  not heal or restore magic on pickup.
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
play can answer either design question. A result from one cannot prove the
other. After a result, update the owning design test first, then amend current
canon only where the decision requires it.
