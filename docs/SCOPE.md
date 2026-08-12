# Scope

[GDD.md](GDD.md) says what the game is. This document says how much may be
built. [NOW.md](NOW.md) is narrower still: it authorises the current work.

The cap is a ceiling, not a backlog. A feature can fit the game and remain
unauthorised.

## Hard caps

| Surface | Cap |
|---|---:|
| Dungeon floors | **4**, plus the existing post-credits endless mode |
| Bosses | **4** |
| Minibosses | **4**, one per floor |
| Enemy kinds in rotation | **9** |
| New monster models | **0** |
| Dungeon kits | **1**, used in four tints |
| Usable items | **6** |
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
| Upgrade tracks | **23** |
| Armour pieces | **4** |
| Jewelry slots | **4** |
| Armour or jewelry art | **0** |
| Garrison surface scenes | **2** |
| New UI screens | **3** |
| Endings | **2** |
| Currencies | **1**: gold |
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

Counts rise only through an explicit scope amendment. By default, an addition
must delete something of comparable cost in the same decision. Implementing a
feature does not authorise another instance, variant, or supporting system.

## Now

Only the bounded slice in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md) is
authorised:

- one Builder;
- one optional Bolt-Thrower project;
- one warning sequence;
- one wave through one route;
- one manual-defense case and one absence-resolution rule;
- one recoverable Tally-Ledger theft;
- one occurrence.

Raid gameplay is not implemented. Floors 2–4, bosses 2–4, production content,
and every expansion below remain frozen while this slice is built and tested.

## Later, only if proven

These are candidates, not promises:

- production work that stays inside the caps above;
- recurring raids;
- scouts, watchtowers, guards, staffing, or morale;
- more waves, routes, attackers, or defensive structures;
- the explosive-barrel and hanging-lantern interaction family;
- another home-life responsibility.

Each needs its own design question, smallest proof, and explicit scope decision.
A passed raid test authorises planning; it does not automatically authorise this
list.

## Not planned

- Freeform construction, building placement, destructible buildings, or a
  settlement simulation.
- A second garrison, open overworld, alternate dungeon, or fifth floor.
- Multiplayer or co-op.
- Joinable factions, character creation, races, classes, or skill trees.
- Farming, fishing, mounts, romance, cooking, or a housing economy.
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

Do not expand production until the active five-session test is resolved.
Directors and automated checks can prove implementation; only observed human
play can answer the design question. After a result, update the owning design
test first, then amend current canon only where the decision requires it.
