# Mechanics, Dynamics, Aesthetics

MDA is the design lens for **The Lower Worlds: Awakening**. It connects what we
put in the game to what players actually do and, finally, to what the game feels
like.

- **Mechanics** are the rules, actions, resources, constraints and authored
  content the designer gives the player.
- **Dynamics** are the behaviours and system interactions that emerge during
  play. They are observed in playtests, not established by design intent.
- **Aesthetics** are the intended emotional and experiential qualities of play.
  Here, “aesthetic” does not mean visual art style.

Players encounter the game in the order **Mechanics → Dynamics → Aesthetics**.
Designers work mainly in the opposite direction: choose an **Aesthetic**, name
the **Dynamics** that could produce it, then select the smallest **Mechanics**
that could cause those dynamics.

If the intended aesthetic does not appear, first identify the dynamic that
actually occurred. Then change the smallest mechanic likely to alter that
dynamic and test again. Adding content before locating that break only makes the
unproven design more expensive.

MDA is not three headings filled in after a feature has already been chosen. It
is a causal hypothesis that playtesting can disprove. The complete mechanic
inventory lives in [`MECHANICS.md`](MECHANICS.md); each row traces into this
model instead of receiving a shallow standalone MDA document.

## Current MDA map — Core Loop Proof

This map is the current hypothesis, not proven truth. The active design test is
[`design-tests/CORE_LOOP_PROOF.md`](design-tests/CORE_LOOP_PROOF.md).

| Intended aesthetic | Required observable dynamics | Existing mechanics under test |
|---|---|---|
| **Specific anticipation:** after returning, the player voluntarily wants another descent for a named in-game reason. | The player notices what changed at home, chooses a concrete next goal and begins or asks for another descent without prompting. | Distinct gold, component and relic rewards; garrison counters, upgrades and relic changes; the return to the garrison; the first-floor reward structure. |
| **Tense, self-authored risk:** “I could keep going, but I might lose what matters.” | The player weighs pushing deeper against returning, and prioritises what belongs in the secure document case versus the exposed bag. No answer dominates every run. | Finite bag slots; the document case; death loss; extraction cost and return walk; Heat; differentiated reward categories. |
| **Readable mastery:** danger feels learnable, and success feels earned rather than arbitrary. | The player reads encounters, improves timing and uses combat options deliberately enough that risk decisions are about the expedition rather than confusion. | Readable first-floor encounters and telegraphs; committed attacks, defence and Heat; the existing combat verbs and feedback. |
| **Homecoming and consequence:** returning feels like bringing something meaningful back. | The player connects a completed run to a visible persistent change in the garrison and understands how the run changed future possibilities. | Garrison counters, upgrades, relic repair/donation and persistent state changes fed by returned rewards. |
| **Satisfying growth:** the haul creates agency rather than merely raising numbers. | The player converts rewards into a chosen capability, feels its effect and forms a concrete preparation goal for the next descent. | Separate gold/component uses; stores, forge, armour, jewellery, alchemy and loadout choices; bounded upgrade caps. |
| **Curiosity about Valenfeld:** the prologue leaves a compelling promise larger than its current slice. | The player forms a question or goal grounded in what they encountered and wants to descend for discovery, not merely because more content exists. | The tightly budgeted first-floor reveal, environmental and item storytelling, and the unresolved promise delivered through the descent/home loop. |

These rows overlap deliberately. A relic can create carry pressure during the
descent, visible consequence at home and curiosity about the larger world. That
interlock is valuable only if players exhibit the dynamics above.

## Design check

For any proposed mechanic or story beat, ask:

1. Which intended aesthetic does it serve?
2. What observable player dynamic should it cause?
3. What interesting decision does that dynamic create?
4. Is the decision legible, consequential and free of a dominant answer?
5. What is the smallest test that could prove us wrong?

If those answers are missing, the proposal is not ready to build. If play shows
a different dynamic, revise or cut the mechanic before adding content around it.
Any added or materially changed mechanic must update
[`MECHANICS.md`](MECHANICS.md) in the same change.
