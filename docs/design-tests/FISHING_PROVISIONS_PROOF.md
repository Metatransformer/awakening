# Design test — Fishing Provisions Proof

- **Status:** Implementation complete — awaiting the precommitted inactive human test
- **Owner:** Project owner
- **Opened:** 2026-08-12
- **Canon owners in scope:** [../GDD.md](../GDD.md),
  [../GARRISON_LIFE.md](../GARRISON_LIFE.md), and [../SCOPE.md](../SCOPE.md)

## Question

> Does a small, voluntary fishing detour make providing for the garrison feel
> like care and useful preparation, without becoming mandatory buff upkeep?

## MDA frame

The separate causal map is in [../MDA.md](../MDA.md). The Raid Loop Proof
remains the active test.

- **Target aesthetic:** belonging and care for a shared frontier home.
- **Desired dynamics:** players voluntarily detour to fish, plan a bounded
  reserve around supper, understand how that meal affects residents and the
  next descent, and return to the pond later without prompting.
- **Failure dynamics:** chore compulsion, daily optimization around a buff,
  confusion about the action-to-supper-to-bonus chain, or indifference once
  the novelty passes.
- **Mechanics under test:** one near/deep fishing interaction, daily yield and
  reserve caps, 20:00 supper, derived morale causes, and one-descent Well Fed.

## Player-facing hypothesis

After discovering the pond and seeing one catch become supper, players will
understand that fishing can care for the garrison and prepare the next descent,
then voluntarily return when it suits their plans rather than treating the
Well Fed benefit as required upkeep.

## Why it matters

The bounded-home identity needs small acts that make returning meaningful. If
the only durable dynamic is compulsory buff maintenance, more daily-life or
profession content would turn the garrison into an obligation instead of a
home.

## Current evidence

- Issue #168 is an owner-authorised implementation slice alongside the active
  raid test freeze.
- Its rules are bounded in [../GARRISON_LIFE.md](../GARRISON_LIFE.md); it adds
  no profession, inventory rod, cooking system, service lock, or new screen.
- Implementation is in progress. No human session answers this question.
- This test must not begin until the Raid Loop Proof resolves or the owner
  explicitly changes [../NOW.md](../NOW.md).

## Smallest test

Run **five cold sessions** from a prepared save with the pond available, no
Fish stored, and enough ordinary play remaining to choose between fishing,
garrison business, and a descent. Each participant gets two unprompted garrison
visits spanning a 20:00 supper and the opportunity to begin the following
descent. They may fish near or deep, skip fishing, leave, return, or stop.

Do not identify Well Fed as an optimal route, ask participants to stock supper,
or prompt a second pond visit. After observed play, a neutral walkthrough may
expose any unobserved link only so comprehension can be measured separately
from voluntary behavior. Store raw notes in [../playtests/](../playtests/).

## Observation plan

For each session, record:

- whether and when the player notices the pond, near/deep choice, daily yield,
  reserve, supper, morale causes, and Well Fed state;
- every voluntary pond visit, return visit, skipped opportunity, and stated
  reason;
- the chosen target, attempt outcome, civil-time consequence, and Fish banked;
- whether the player predicts the 20:00 consumption and the next-descent bonus;
- whether the temporary maximum is noticed and understood to last one descent;
- whether route timing or reserve planning changes without researcher input;
- any language of care, belonging, optimization, obligation, maintenance,
  annoyance, or fear of descending without the buff;
- every researcher intervention, technical failure, and link explained after
  observation.

After play, ask:

1. What happened to the Fish you caught?
2. What did supper change for the garrison and for your next descent?
3. What would make you return to the pond, and when would you skip it?
4. Would you feel disadvantaged descending without Well Fed? Why?
5. Did fishing feel like care, preparation, a chore, or something else?

## Precommitted criteria

These rules apply to one batch of five valid cold sessions. Do not rewrite them
after testing starts.

### Pass

Pass only if no stop condition occurs and all are true:

- At least **4/5** players can explain catch → stored Fish → 20:00 supper →
  next-descent Well Fed without researcher correction.
- At least **3/5** make a voluntary fishing detour and later return to the pond
  without prompting, for a reason connected to supper, residents, or a planned
  descent rather than completionism alone.
- At least **4/5** understand that Well Fed is temporary and that fishing can be
  skipped.
- No more than **1/5** describes fishing primarily as mandatory buff upkeep.

A pass supports keeping this one bounded loop. It does not authorise another
pond, profession, resource, recipe system, morale consequence, or stronger
bonus.

### Revise

Revise the smallest relevant feedback, timing, or reward rule and run a fresh
five-session batch if no stop condition occurs and any is true:

- exactly **2–3/5** understand the full action-to-supper-to-bonus chain;
- exactly **2/5** voluntarily return after understanding the chain; or
- repeated reserve, supper, morale, or temporary-bonus confusion plausibly
  masks an otherwise voluntary care or planning dynamic.

Do not add collection volume, progression gear, or a larger buff to repair a
communication problem.

### Stop

Stop expansion and remove or fundamentally reconsider the benefit loop if any
is true:

- only **0–1/5** understands the action-to-supper-to-bonus chain after ordinary
  play;
- **0–1/5** voluntarily returns despite noticing and understanding fishing;
- at least **3/5** describes fishing primarily as mandatory upkeep or avoids a
  descent because Well Fed is unavailable; or
- at least **4/5** ignores the pond after its first exposure and says the act
  adds neither care nor useful planning.

### Invalid batch

The batch is invalid if fewer than five sessions yield both an unprompted
second-visit opportunity and usable evidence because of technical failure,
protocol contamination, or non-cold participants. Repair the test and run a
fresh valid batch; do not average invalid sessions into the decision.

## Result

Not tested.

## Decision

Pending.

## Canon changed

Owner-directed implementation amended current canon before this test; no
evidence-driven change yet.

## Follow-up

Keep this test inactive until the Raid Loop Proof resolves or the owner changes
[../NOW.md](../NOW.md).
