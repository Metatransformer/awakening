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

The active test is
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

| Intended aesthetic | Observable dynamics | Minimum mechanics under test |
|---|---|---|
| **Responsibility:** the garrison feels like a home whose safety matters. | The player notices the warning, considers the garrison's state, and treats the outcome as a consequence of prior choices. | A living garrison, one authored warning sequence, one attack, and a visible recoverable theft. |
| **Tense agency:** staying and extracting both feel defensible. | The player weighs the current descent against ordinary extraction and makes an unprompted choice they can explain. | Afternoon and urgent warnings; current carried goals; the normal Escape Rope; no teleport or free exit. |
| **Prepared trust:** building changes what the player is willing to risk. | The player predicts what one defense can do, relies on it or returns despite it, and explains how it changed the decision. | One optional Bolt-Thrower; manual defense when present; deterministic absence outcomes with and without it. |
| **Recoverable consequence:** failure hurts without corrupting the campaign. | The player understands the empty relic mount, forms a recovery goal, and expects restoration rather than permanent loss. | Temporary suppression and theft of the Tally-Ledger; return to its original location; restoration without a second repair cost. |

The mechanics are deliberately bounded. More content cannot rescue a dominated
choice or turn a compulsory interruption into responsibility.

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
