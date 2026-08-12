# Design test — Field Notes Proof

- **Status:** Implementation complete / human test pending
- **Owner:** Project owner
- **Implementation:** [issue #112](https://github.com/Metatransformer/awakening/issues/112)
- **Canon owner in scope:** [FIELD_NOTES.md](../FIELD_NOTES.md)

## Question

Do players connect awarded Field Notes to observed dungeon events, compare the
finite doctrines, notice the bought doctrine's effect, and later name another
observation or doctrine as a reason to descend again?

## MDA frame

- **Target aesthetic:** homecoming as earned learning and specific anticipation
  for another descent.
- **Desired dynamics:** players attribute each award to something they saw,
  compare at least two permanent opportunity-cost choices, notice the chosen
  effect in play and form a specific next target.
- **Failure dynamics:** players read notes as loot or death compensation, buy
  without comparison, miss the effect, expect a repeatable grind or continue
  only from prompting or abstract completionism.
- **Mechanics under test:** five fixed first-time Cistern observations, debrief
  awards after extraction or death, five total notes and three one-rank
  doctrines costing two notes each at Aldric.

## Player-facing hypothesis

After a cold player observes Cistern events and reaches a garrison debrief, the
receipt will make the source of each awarded note legible; Aldric's finite
doctrine choice will provoke comparison; the bought effect will be noticeable;
and a specific unearned observation or doctrine will voluntarily re-prime the
descent loop.

## Current evidence

- The bounded implementation is complete under issue #112.
- `tools/directors/field_notes.gd` proves the five-id award cap, extraction and
  death debriefs, save/load idempotency, two-of-three doctrine economy, exact
  effects, receipt and Aldric board. It does not supply human evidence.
- No qualifying five-session cold-playtest batch has been recorded.
- Directors and automated checks may prove award, persistence, purchase and
  effect contracts. **They cannot pass this human gate.**
- Implementation is not evidence that players form the intended connection,
  comparison, perception or motivation.

## Smallest test

Run **five cold sessions** on the bounded first-floor/Cistern slice. Participants
must not have helped design or build Field Notes. Tell each player they may stop
whenever they choose; do not suggest that another descent is expected, name an
unearned observation or point out a doctrine effect.

Each valid session must reach a debrief with at least two awarded notes, allow
the player to use Aldric's Field Notes service and give them an ordinary chance
to experience a bought doctrine's effect. Use observed behaviour first, then a
short neutral interview.

## Observation plan

For each session, record:

- the observed events that become pending and awarded notes;
- whether the player correctly connects each visible award to an event they
  experienced, without help;
- which doctrines the player examines or discusses before buying, and whether
  at least two are meaningfully compared;
- whether they buy or save, their stated reason and any expectation of refund,
  repetition or eventually buying all three;
- whether later behaviour or unsolicited speech shows that they noticed the
  bought doctrine's effect;
- whether they voluntarily begin or ask for another descent, and the exact
  stated observation or doctrine target, if any;
- any checklist interpretation, grind expectation, onboarding block,
  researcher intervention or technical failure;
- friction tags from [PLAYTESTING.md](../PLAYTESTING.md).

After observation, ask neutral questions without naming the expected answer:

1. What did each Field Note represent?
2. What, if anything, did you compare at Aldric's counter?
3. What, if anything, felt different after your choice?
4. What would you choose to do next, if anything? Why that specifically?
5. How do you think more notes could be earned, and what would you use them for?

Store raw session records in `docs/playtests/` and synthesise only after all
five valid sessions. Record interventions exactly; a prompted answer is not an
observed connection or voluntary reason.

## Precommitted criteria

These thresholds are pragmatic decision rules for this five-session batch, not
claims of statistical certainty. Do not rewrite them after testing starts.

### Pass

Both core thresholds must be true:

- At least **3/5** correctly connect a Field Note to an observed event **and**
  compare at least two doctrines before buying.
- At least **2/5** later name earning further notes for a specific doctrine as a
  reason for another descent.

Doctrine-effect notice remains a reported diagnostic, not a third core
threshold. It cannot rescue a miss on either criterion above.

### Revise

Revise the smallest responsible part and precommit a fresh batch when either
core threshold misses but behaviour shows a credible connection, comparison or
specific next target; when effect perception misses; or when one repeated,
bounded readability, control, timing or onboarding problem plausibly masks the
intended behaviour.

Do not add observations, doctrines, ranks, a checklist or production content to
rescue a miss with volume.

### Stop

Stop and cut the bounded system when **0–1/5** players connect an award to an
observed event or compare doctrines, or when **0–1/5** name a note-backed reason
for another descent, provided the absence is not explained by one repeated,
bounded test obstruction. Also stop if players consistently understand the
system but read it as repeatable compensation or say it gives them no reason to
return after one bounded revision.

### Invalid batch

The result is invalid if fewer than five sessions produce usable evidence
because of technical failure, protocol contamination, researcher prompting,
participants who were not cold or a build that does not expose the authorised
two-note first-debrief choice. Repair the test and run a fresh five-session
batch; do not average invalid sessions into the decision.

---

## Result

Not tested.

## Decision

Pending.
