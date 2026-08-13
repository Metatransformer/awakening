# Design documentation

Read these three files in order. A cold reader should understand the game, its
current proof, and its boundary in under ten minutes.

1. [GDD.md](GDD.md) — the north-star game design.
2. [NOW.md](NOW.md) — the one question authorised now.
3. [SCOPE.md](SCOPE.md) — the cap table and production boundary.

This page is the authority map. It points to truth instead of repeating it.

## Required design reading

| Owner | Owns |
|---|---|
| [GDD.md](GDD.md) | Pitch, fantasy, pillars, loop, progression, feature intent, and lore premise |
| [NOW.md](NOW.md) | The active human questions and the work currently authorised |
| [SCOPE.md](SCOPE.md) | Hard caps, the production freeze, and what is later or not planned |

## Focused references

A reference may be long only when its subject is narrow.

| Subject | Named owner |
|---|---|
| Descent, rewards, economy, and services | [METAGAME.md](METAGAME.md) |
| Bounded first-time observations, Field Notes, and doctrines | [FIELD_NOTES.md](FIELD_NOTES.md) |
| Garrison rhythm, Firewood/Hearth, and the bounded raid | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| Player-facing mechanics inventory | [MECHANICS.md](MECHANICS.md) |
| Items and their place in the loop | [ITEMS.md](ITEMS.md) |
| Puzzle grammar | [PUZZLES.md](PUZZLES.md) |
| Ordinary enemies | [BESTIARY.md](BESTIARY.md) |
| Boss encounters | [BOSSES.md](BOSSES.md) |
| Story and local lore | [LORE_AND_STORY.md](LORE_AND_STORY.md) |
| Shared Valenfeld canon | [CANON_BRIDGE.md](CANON_BRIDGE.md) |
| World art and HUD presentation principles | [STYLEGUIDE.md](STYLEGUIDE.md) |
| Renderer, UI, units, interfaces, input, and implementation contracts | [CONTRACT.md](CONTRACT.md) |
| Character asset production | [CHARACTER_PIPELINE.md](CHARACTER_PIPELINE.md) |
| Design method | [DESIGN_PROCESS.md](DESIGN_PROCESS.md) |
| Playtest method | [PLAYTESTING.md](PLAYTESTING.md) |

## Evidence and history

- [MDA.md](MDA.md) states the current causal hypothesis; it is not evidence.
- [design-tests/](design-tests/) holds precommitted questions, criteria, results,
  and decisions. The current dedicated human gates are
  [RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md) and
  [FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md). The bounded,
  owner-authorised Glint experiment has its own pending gate in
  [GLINT_TRIAL_MVP.md](design-tests/GLINT_TRIAL_MVP.md).
- [playtests/](playtests/) holds observations, timecodes, and player words.
- [archive/](archive/) holds intentionally retained superseded material.
- Git history is the archive for replaced text. Do not create snapshot copies.
- [OOT_CATALOGUE.md](OOT_CATALOGUE.md) and
  [../refs/REFERENCE.md](../refs/REFERENCE.md) hold reference evidence.
- [../refs/style/README.md](../refs/style/README.md) catalogues the owner-supplied
  visual frames and the one job each is allowed to do.

## Hard rules

- One fact has one owner. Every other document links to that owner.
- Active documents state current truth only.
- Discussion, rationale, raw observation, and superseded material belong in
  design tests, playtests, the archive, issues, or git history.
- Links beat copied summaries.
- Keep the stable paths named here; code comments and tools cite them.

Historical compatibility paths such as [../DESIGN.md](../DESIGN.md),
[HUD_PLAN.md](HUD_PLAN.md), and
[CONTRACT.topdown.old.md](CONTRACT.topdown.old.md) are not active authority.
