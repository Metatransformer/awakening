# Design tests

A design test resolves one uncertain player-experience claim. It connects an
MDA hypothesis to observed behaviour and a decision without turning canonical
design documents into diaries.

Use one of these statuses:

- `Draft`
- `Ready to test`
- `Testing`
- `Accepted`
- `Revised`
- `Rejected`

Every test includes the question, target aesthetic, desired dynamics, mechanics
under test, current evidence, smallest test, observation plan, precommitted
pass/revise/stop criteria, result, decision, canon changed and follow-up.

Create a test from [`TEST_TEMPLATE.md`](TEST_TEMPLATE.md). Once testing begins,
do not rewrite the original hypothesis or criteria to fit the observations.
Append the result and decision beneath the frozen test plan. If the claim
changes materially, mark the test `Revised` and open a new test for the new
claim.

Only one design test is active during pre-production. The current test is
[`CORE_LOOP_PROOF.md`](CORE_LOOP_PROOF.md).
