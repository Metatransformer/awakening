# Canon bridge — Awakening and Valenfeld

**The Lower Worlds: Awakening is a leaf of Valenfeld's world, not a second
world bible.** The typed canon in the sibling Valenfeld project owns shared
people, places, factions, history and cosmology. This project owns the
prologue's game design, the subset it reveals, and prologue-only details that do
not contradict those roots.

Parent-canon front door:
[`../../valenfeld/world/LORE_INDEX.md`](../../valenfeld/world/LORE_INDEX.md).
The entity JSON files it indexes are authoritative over summaries here.

## The bridge rule

Every shared lore claim carries a parent entity id and one status:

- **Matched** — Awakening uses the parent fact without changing it.
- **Prologue-only** — the detail is local to this game and does not alter a
  parent fact.
- **Collision** — the two projects currently assert incompatible roots. Do not
  spread either version into new dialogue, items or environmental text until
  the owner decides it.

Awakening may reveal less than the parent canon, but it may not invent a new
root while writing a surface artifact. A retcon is made and logged in the
Valenfeld project first; this file then records the resolved dependency.

## Open bridge audit — 2026-08-11

| Parent entity | Awakening currently says | Parent canon currently says | Status / decision needed |
|---|---|---|---|
| `place.the-sunken-cut` | The Sunken Cut is a four-floor route into ancient Vyr works, reached through a purpose-built garrison. | It is a flooded silver prospect a short walk southwest of Valenfeld, driven by Alder Venn and later held by the Silt Hands. | **Collision.** Decide first whether this is the same place and when Awakening occurs. |
| `faction.the-far-lantern-society` | Kael's creed is “Dive deep, Unearth treasures and Return safely”; the expedition owns what comes out of the shaft. | The Society's creed is “Go far. Come home. Tell true.” It explicitly claims no ownership merely because a member found something. | **Collision.** Decide whether Awakening depicts an earlier/local doctrine, a compromised expedition, or a parent-canon retcon. |
| `place.highbridge` | A “Highbridge garrison” at the shaft head is a day's road from Valenfeld. | Highbridge is the lower world's human capital and major trade city; the canonical Cut is attached to Valenfeld. | **Collision.** Decide who actually sponsors and names the outpost. |
| `concept.race-vyr` and `concept.the-vallen-imperium` | The Vyr built the works beneath the Cut and are treated as the dead empire behind the salvage. | Vyr artifice and the Vallen Imperium's Old Work are distinct traditions, although the Vyr caused the Sundering. | **Collision.** Assign the Cut's mine, buried machinery and deeper structure to their canonical makers separately. |
| `place.vallenfield-town` | Valenfeld stays off-screen and the garrison carries the whole home loop. | Valenfeld is the starting frontier town and the canonical Cut is one of its nearby delves. | **Potential match.** This works if the time, geography and outpost relationship above are reconciled. |

These are design dependencies, not permission to expand the lore. The first
question after the Core Loop Proof design test closes should be the prologue's
temporal and geographic relationship to the canonical Sunken Cut; that answer
will resolve most of the table. Do not open a second active design test while
core-loop proof is running.

## Matched pantheon subset — the Votive Court

The Votive Court is a **prologue-only arrangement** of existing parent-canon
figures, not a new unified pantheon or a tidy domain chart. The identities and
the small rites that shape their prototype effigies are matched roots:

| Parent entity | Awakening reveals | Status |
|---|---|---|
| `character.the-lady-of-the-long-water` | **The Lady of the Long Water**; a basin for the god who keeps what is lost beneath deep water | **Matched** |
| `character.the-unnamed-third` | **The Last Guest**; a closed door and extinguished lamp for the god of properly finished endings | **Matched** |
| `concept.old-harrow` | **Old Harrow**; a spade and leaning field figure for the turned year, growth and useful rot | **Matched** |
| `concept.the-old-man-under-the-mountain` | **The Old Man Under the Mountain**; a cairn for stone, patience and the deep that should remain shut | **Matched** |
| `concept.the-good-neighbor` | **The Good Neighbor**; an empty chair at the hearth for hospitality and the kept threshold | **Matched** |
| `concept.the-grey-walker` | **The Grey Walker**; a staff and roadside cairn for true roads, fords and waymarks | **Matched** |
| `character.vallen` | **Vallen, the Wright**; the broken central maker. He is dead, cannot answer, and is never selected | **Matched** |

The court offering one temporary run blessing from three randomly answering
patrons is **Prologue-only gameplay framing**. It does not assert that these six
normally share a church, priesthood, hierarchy or doctrine. Athra and every
other parent deity remain outside Awakening's current reveal budget.

## Surface-artifact contract

Before approving dialogue, item text, an environmental clue or a story beat:

1. Cite at least one parent entity id or mark the detail `Prologue-only`.
2. State what the player should infer; never expose the whole source entry.
3. Use the smallest delivery channel that works: environment or item first,
   enacted beat second, exposition only when the critical path would otherwise
   be unclear.
4. Do not ship an `Undecided` root as mystery. A mystery needs a decided hidden
   truth and at least two visible anchors.
5. Check the artifact against every open collision above.
