# Measurable Design Records

A **Measurable Design Record (MDR)** is a small ADR-like record for one uncertain
player-experience claim. It connects a hypothesis to observed behavior and a
decision without turning canonical design documents into diaries.

Use one of these statuses:

- `Draft`
- `Ready to test`
- `Testing`
- `Accepted`
- `Revised`
- `Rejected`

Every MDR includes the question, player-facing hypothesis, why it matters,
current evidence, smallest test, observation plan, precommitted pass/revise/stop
criteria, result, decision, canon changed and follow-up.

Create a record from [`MDR_TEMPLATE.md`](MDR_TEMPLATE.md). Once testing begins,
do not rewrite the original hypothesis or criteria to fit the observations.
Append the result and decision beneath the frozen test plan. If the claim
changes materially, mark the record `Revised` and open a new record for the new
claim.

Only one MDR is active during pre-production. The current record is
[`MDR-001-PROVE-THE-CORE-LOOP.md`](MDR-001-PROVE-THE-CORE-LOOP.md).
