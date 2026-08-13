# Mechanics, Dynamics, Aesthetics

MDA is the project's causal design lens:

- **Mechanics** are authored rules, actions, resources, and content.
- **Dynamics** are the behaviors and interactions observed during play.
- **Aesthetics** are the intended feelings and qualities of the experience.

Players encounter mechanics, which produce dynamics, which may produce an
aesthetic. Designers work backward: name the desired aesthetic, identify an
observable dynamic that could create it, then build the smallest mechanics that
could cause that dynamic.

This map is a hypothesis, not evidence. Only observed play can establish whether
the dynamics occur.

## Raid proof map

The raid test is
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

| Intended aesthetic | Observable dynamics | Minimum mechanics under test |
|---|---|---|
| **Responsibility:** the garrison feels like a home whose safety matters. | The player notices the warning, considers the garrison's state, and treats the outcome as a consequence of prior choices. | A living garrison, one authored warning sequence, one attack, and a visible recoverable theft. |
| **Tense agency:** staying and extracting both feel defensible. | The player weighs the current descent against ordinary extraction and makes an unprompted choice they can explain. | Afternoon and urgent warnings; current carried goals; the normal Escape Rope; no teleport or free exit. |
| **Prepared trust:** building changes what the player is willing to risk. | The player predicts what one defense can do, relies on it or returns despite it, and explains how it changed the decision. | One optional Bolt-Thrower; manual defense when present; deterministic absence outcomes with and without it. |
| **Recoverable consequence:** failure hurts without corrupting the campaign. | The player understands the empty relic mount, forms a recovery goal, and expects restoration rather than permanent loss. | Temporary suppression and theft of the Tally-Ledger; return to its original location; restoration without a second repair cost. |

The mechanics are deliberately bounded. More content cannot rescue a dominated
choice or turn a compulsory interruption into responsibility.

## Post-raid fishing/provisions hypothesis

The owner-directed fishing/provisions slice is implementation sequencing debt,
not evidence for the raid map above. Its precommitted human test is
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md),
and it does not become the active test until the Raid Loop Proof resolves or the
owner changes [NOW.md](NOW.md) again.

| Intended aesthetic | Observable dynamics | Minimum mechanics under test |
|---|---|---|
| **Belonging and care:** providing for a shared home feels like a voluntary act that connects a garrison visit to the next adventure. | The player chooses a pond detour, plans a small Fish reserve around supper, notices how supper affects residents and the next descent, and later returns without prompting. | One pond and bounded near/deep fishing interaction; three-unit reserve and daily yield; 20:00 supper; visible Warm/Fed/Connected morale; one-descent Well Fed benefit; read-only status on the existing Garrison page. |

The failure dynamic is **chore compulsion**: players treat fishing as mandatory
buff upkeep, optimize every day around it, or resent the return trip despite
understanding the action-to-supper-to-bonus chain. Adding catches, gear,
professions, or stronger rewards would intensify that failure rather than repair
it.

Issue #184 changes the pond's access and cost by making the Fishing Rod one of
Brannoc's durable utility tools. That implementation fact does not establish
that near and deep water create a meaningful choice; the evidence bar in the
Fishing Provisions Proof is unchanged.

## Utility tools and mining hypothesis

The dedicated test is
[design-tests/MINING_TOOLS_PROOF.md](design-tests/MINING_TOOLS_PROOF.md).

| Intended aesthetic | Observable dynamics | Minimum mechanics under test |
|---|---|---|
| **Resourceful preparation:** ordinary salvage becomes a set of explainable tradeoffs between present expedition value and future home capability. | The player compares incidental enemy Iron Scrap with spending Pickaxe durability for a larger deterministic vein payout; allocates Iron Scrap, Riveted Plate, and Tension Coil between tools, forge work, and the Bolt-Thrower; completes the grove-to-hearth prerequisite before forging a rod; and reforges a worn tool when its next use justifies the full cost. | Three fixed-durability utility tools at Brannoc; one successful-impact Axe spend, one resolved-attempt Rod spend, and one committed-impact Pickaxe spend; private deterministic 65% vein placement with three existing payouts; stable per-run depletion and physical loot. |

The failure dynamics are compulsory sweeping, opaque durability loss, or a
single dominant allocation that turns tools and metals into upkeep rather than
a preparation choice. Automated proof can establish the fixed mechanics; only
future player sessions can establish the intended dynamic.

## Field Notes proof map

The dedicated test is
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md), and the
bounded mechanics are owned by [FIELD_NOTES.md](FIELD_NOTES.md).

| Intended aesthetic | Observable dynamics | Minimum mechanics under test |
|---|---|---|
| **Earned learning and specific anticipation:** homecoming turns what happened underground into a concrete reason to return. | The player connects an awarded note to an observed event, compares finite doctrines, notices the chosen effect and later names a specific unearned observation or doctrine target. | Five fixed first-time Cistern observations; award only at extraction/death debrief; five total notes; three one-rank doctrines costing two notes each. |

This map states a hypothesis, not evidence. Implementation can prove the
mechanics function; only the precommitted human sessions can establish the
dynamic.

## Design check

For any proposed mechanic or story beat, ask:

1. Which intended aesthetic does it serve?
2. What observable player dynamic should it cause?
3. What interesting decision does that dynamic create?
4. Is the decision legible, consequential, recoverable, and free of a dominant
   answer?
5. What is the smallest test that could prove the hypothesis wrong?

If those answers are missing, the proposal is not ready. If play produces a
different dynamic, revise or cut the smallest responsible mechanic before adding
content. [MECHANICS.md](MECHANICS.md) remains the full player-facing mechanics
inventory.
