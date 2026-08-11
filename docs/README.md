# Design documentation

Start here. This page says where each kind of truth lives; it does not repeat
that truth.

| If you need… | Read… |
|---|---|
| The work authorised now | [`NOW.md`](NOW.md) |
| Game identity, player experience and pillars | [`GDD.md`](GDD.md) |
| Prototype boundary, release ceiling and milestone record | [`SCOPE.md`](SCOPE.md) |
| Economy and the descent/garrison loop | [`METAGAME.md`](METAGAME.md) |
| Puzzle design | [`PUZZLES.md`](PUZZLES.md) |
| Encounters and boss fight shapes | [`BESTIARY.md`](BESTIARY.md) and [`BOSSES.md`](BOSSES.md) |
| Items and where they enter the loop | [`ITEMS.md`](ITEMS.md) |
| Implementation contract, units and interfaces | [`CONTRACT.md`](CONTRACT.md), then [`../CLAUDE.md`](../CLAUDE.md) |
| Visual style and HUD authority | [`STYLEGUIDE.md`](STYLEGUIDE.md) |
| Evidence and reference material | [`OOT_CATALOGUE.md`](OOT_CATALOGUE.md) and [`../refs/REFERENCE.md`](../refs/REFERENCE.md) |
| How mechanics should produce the intended experience | [`MDA.md`](MDA.md) |
| How design work proceeds | [`DESIGN_PROCESS.md`](DESIGN_PROCESS.md) |
| How playtests are run | [`PLAYTESTING.md`](PLAYTESTING.md) and [`playtests/`](playtests/) |
| Design hypotheses, tests and decisions | [`design-tests/`](design-tests/) |
| Story and lore discipline | [`LORE_AND_STORY.md`](LORE_AND_STORY.md) |
| Shared canon between Awakening and Valenfeld | [`CANON_BRIDGE.md`](CANON_BRIDGE.md) |
| Historical or superseded material | [`archive/`](archive/) |

## Authority rules

- `NOW.md` says what is authorised now. It never describes everything the game
  may someday contain.
- The GDD, SCOPE and system documents are current canon, not chronological
  diaries. Edit the owner of a changed fact in place.
- `MDA.md` maps intended aesthetics to hypothesised dynamics and the mechanics
  expected to produce them. It is a model to test, not evidence that they occur.
- Files under `design-tests/` hold uncertain hypotheses, rationale,
  precommitted criteria, results and decisions.
- Files under `playtests/` hold observations, timecodes and player quotes. They
  do not hold design conclusions.
- A fact has one owner. Other documents link to that owner instead of copying
  it.
- Do not bulk-move the named documents above. Code comments and tools cite their
  stable paths.

## Historical paths

These files remain where existing references expect them, but they are not
current authority:

- [`../DESIGN.md`](../DESIGN.md) is the superseded HUD design. Current visual
  and HUD authority is `docs/STYLEGUIDE.md`; implementation truth remains in the
  code and `docs/CONTRACT.md`.
- [`HUD_PLAN.md`](HUD_PLAN.md) is a historical HUD planning and decision record.
  Current authority is `docs/STYLEGUIDE.md` plus the as-built code.
- [`CONTRACT.topdown.old.md`](CONTRACT.topdown.old.md) is the superseded
  top-down build contract. Current authority is `docs/CONTRACT.md`.
