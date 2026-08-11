# MDR-001 — Prove the core loop

- **Status:** Ready to test
- **Owner:** Project owner
- **Opened:** 2026-08-11
- **Canon owners in scope:** `docs/GDD.md` §§2–4, `docs/SCOPE.md` §4.1

## Question

Does finishing one descent create a specific, voluntary desire for another?

## Player-facing hypothesis

After completing the existing first-floor descent and returning to the
garrison, a cold player who is explicitly free to stop will voluntarily begin
or ask for another descent because a specific in-game goal has re-primed the
loop.

## Why it matters

Floors 2–4 would amplify this loop. If one floor does not make another feel
desirable, adding production content multiplies cost without proving the game.
Only a passed core-loop gate can authorise production planning.

## Current evidence

- The M4 first-floor core-loop prototype is built and playable.
- Its implementation directors prove seams and frames, not human desire.
- M4's human fun gate has not passed.
- M5 exists as accepted sequencing debt and is not evidence for the hypothesis.
- No qualifying five-session cold-playtest batch has been recorded.

## Smallest test

Run five cold first-hour sessions on the existing M4 slice. Participants must
not have helped design or build it. Tell each player they may stop whenever they
choose; do not suggest that a second descent is expected. Use observed behavior
first, followed by a short interview.

Do not add production content for this test. Make only changes required to let a
cold player reach, perceive and exercise the existing first-floor loop.

## Observation plan

For each session, record:

- timecodes for descent, meaningful bag checks, extraction or death, garrison
  return, persistent changes noticed, and any second-descent action or request;
- what the player was carrying when they chose to continue or return;
- the player's exact stated reason for another descent, if any;
- whether the player encountered and understood a carry-versus-return decision;
- whether they noticed or later recalled a persistent garrison change without
  being told;
- every intervention and whether onboarding blocked progress;
- friction tags from `docs/PLAYTESTING.md`.

After observation, ask neutral recall and counterfactual questions. Store each
session in `docs/playtests/`; synthesize only after all five valid sessions.

### Diagnostic prompts

These preserve the four questions from `docs/SCOPE.md` §4.1 as diagnostics.
They do not replace the behavioral criteria and should not reveal the expected
answer.

1. What, if anything, would you choose to do next? Why that specifically?
2. Describe any moment when you considered continuing or returning. What were
   you carrying, and what happened to any relic you carried or lost?
3. What, if anything, changed in the garrison?
4. How would you describe the gate room? When its cycle opened, where did you
   think you had emerged?

## Precommitted criteria

These thresholds are pragmatic decision rules for this five-session batch, not
claims of statistical certainty. Do not rewrite them after testing starts.

### Pass — `Proven`

All four must be true:

- At least **3/5** players voluntarily begin or ask for a second descent while
  explicitly free to stop, and can name a specific in-game reason.
- At least **3/5** experience and understand a carry-versus-return decision.
- At least **3/5** unaided notice or recall a persistent garrison change.
- Onboarding blocks no more than **1/5** players. A block means the researcher
  must teach or take over so the player can continue the loop.

Passing resolves this MDR as `Accepted` and authorises production planning. It
does not automatically authorise production.

### Revise — `Promising`

Revise when behavior shows a credible loop but the batch misses the full pass:

- exactly **2/5** players show specific voluntary second-descent desire; or
- the desire threshold passes but one supporting threshold misses; or
- a repeated control, comprehension, readability, decision or pace friction
  plausibly masks the intended behavior.

Make the smallest correction supported by the batch and precommit another test.
Do not reward a promising result with floors, bosses or content volume.

### Stop — `Disproven`

Stop production expansion and reconsider the core loop when **0–1/5** players
who complete and understand it show specific voluntary second-descent desire,
and the absence is not explained by one repeated, bounded onboarding or
readability failure. Also stop if players consistently understand the rewards
and persistent change but say neither gives them a reason to return.

### Unknown

The result is unknown if fewer than five sessions produce usable evidence
because of technical failure, protocol contamination or participants who were
not actually cold. Repair the test and complete a fresh valid batch; do not
average invalid sessions into the decision.

---

## Result

Not tested yet.

## Decision

Pending.

## Canon changed

None.

## Follow-up

Run five cold first-hour sessions using
`docs/playtests/PLAYTEST_TEMPLATE.md`, then append the batch result here.
