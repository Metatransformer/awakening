# Design test — Raid Loop Proof

- **Status:** Implementation complete — human test pending
- **Owner:** Project owner
- **Canon owners in scope:** [../GDD.md](../GDD.md),
  [../GARRISON_LIFE.md](../GARRISON_LIFE.md), and [../SCOPE.md](../SCOPE.md)

## Question

> When warned that the garrison will be raided, does the player make a deliberate
> stay-versus-extract decision, and does one built defense change that decision
> in a way they can explain?

## MDA frame

The causal map is in [../MDA.md](../MDA.md).

- **Target aesthetic:** responsibility for a home the player chose to build,
  with dread, agency, and relief rather than obligation.
- **Desired dynamics:** the player reads the warning, weighs the current descent
  against the garrison's preparation, makes an unprompted choice, and can explain
  why the Bolt-Thrower did or did not earn their trust.
- **Failure dynamics:** one answer dominates; the warning is treated as a
  teleport prompt; the defense is irrelevant or inscrutable; or the raid feels
  like a compulsory interruption to the adventure.

## Player-facing hypothesis

After donating the Tally-Ledger and choosing whether to build one defense, a
warning received during ordinary play creates a legible tradeoff between the
current descent and the garrison. The player chooses deliberately, and the
presence or absence of the Bolt-Thrower materially affects that choice.

## Why it matters

Raids connect dungeon risk, base building, and home consequence. If the
stay-versus-extract choice is dominated or resented, recurrence and additional
defenses would multiply interruption rather than deepen responsibility.

## Current evidence

- The implemented slice includes Tamsin the Builder and the optional West Gate
  Bolt-Thrower, the 15:00 warning and 23:00 horn, sleep interruption, and the
  four-raider main-gate route and wave.
- Its normal HUD reports authoritative GARRISON integrity; the raid wave and
  integrity persist across leaving and saving, and loss steals the recoverable
  Tally-Ledger and suppresses its benefit.
- The earlier Core Loop Proof was superseded before human testing. It has no
  pass or fail result.
- No human session answers this question.

## Precommitted MVP

Build one authored occurrence:

1. Donating the **Tally-Ledger** arms the sequence.
2. Add unvoiced **Tamsin the Builder** using her authored `NpcBody` and shared
   service patterns.
3. The Builder owns mechanisms and buildings. Aldric owns scouts, guards,
   staffing, and morale.
4. Offer one optional **West Gate Bolt-Thrower** build quest using existing gold
   and components.
5. Give one advance warning during the afternoon.
6. Give one urgent warning at **23:00**, using the dedicated raid horn rather
   than the ordinary nightfall cue. Interrupt sleep if the player is sleeping.
7. An underground player may continue or use the normal Escape Rope. The raid
   grants no summon, teleport, or free extraction; the descent ends normally.
8. Send one wave of **three kobolds and one orc** through the main gate.
9. Only a completed raider attack on the courtyard command standard reduces
   GARRISON integrity. Killing every raider while integrity remains above zero
   wins. Reaching zero while any raider lives is an irreversible loss, even if
   the remaining raiders later die.
10. If the player is present, resolve the defense through manual combat.
11. If the player is absent and the Bolt-Thrower exists, it holds. If the player
    is absent and it does not exist, the raid fails.
12. On failure, steal the donated Tally-Ledger. Suppress its benefit and show
    its mount empty. Return it to its original dungeon location.
13. Recovering the Ledger restores the prior donation and benefit without a
    second repair cost.
14. The sequence occurs once. Add no recurrence scheduler.

The slice adds no currency, UI screen, voiced line, or enemy model. It does not
include scouts, guards, watchtowers, multiple waves or routes, another defense,
freeform construction, destructible buildings, or barrel interactions.

## Smallest test

After the MVP is implementation-complete, run **five cold sessions**. Each
participant starts from a prepared save before the Tally-Ledger donation and is
free to build or skip the Bolt-Thrower, delve, extract, remain underground,
sleep, or stop.

Do not tell participants that returning is preferred. Do not explain the
absence-resolution rule before they decide. Record behavior first, then ask
neutral questions. Store each session in [../playtests/](../playtests/).

## Observation plan

For each session, record:

- whether the player noticed and understood the Builder's optional project;
- whether they built the Bolt-Thrower and why;
- location, current goal, carried value, and ordinary extraction cost at both
  warnings;
- the stay-versus-extract choice and the player's reason before the result;
- whether sleep was interrupted and understood;
- whether the player expected a teleport, summon, or free exit;
- present/absent defense outcome and whether the Bolt-Thrower's contribution was
  understood;
- whether failure, the empty mount, suppressed benefit, and recovery route were
  understood;
- every researcher intervention or technical failure.

After the outcome, ask:

1. Why did you stay or extract?
2. What did you believe would happen at the garrison if you were absent?
3. What difference did the Bolt-Thrower make?
4. Would your choice change if the Bolt-Thrower state were reversed? Why?
5. Did the raid deepen the adventure, interrupt it, or both?

## Precommitted criteria

These rules apply to one batch of five valid sessions. Do not rewrite them after
testing starts.

### Pass

Pass only if no stop condition occurs and all are true:

- At least **4/5** players make the stay-versus-extract choice without prompting
  and explain it using their current descent state, ordinary extraction, the
  garrison's risk, or prior preparation.
- At least **3/5** say the Bolt-Thrower's presence or absence affected their
  choice and accurately explain how.
- At least **4/5** understand that the warning itself did not teleport or extract
  them.
- At least **4/5** can explain the outcome, including the recoverable
  Tally-Ledger consequence when failure is observed or described after play.

A pass authorises a decision about the next proof. It does not authorise
recurring raids or more defenses.

### Revise

Revise the smallest relevant mechanic and repeat a fresh five-session batch if:

- exactly **2–3/5** players make and explain a deliberate choice;
- exactly **2/5** can explain how the Bolt-Thrower affected the choice; or
- a repeated warning, timing, extraction, defense-feedback, or consequence
  comprehension problem plausibly masks an otherwise meaningful decision.

Do not add content volume to repair a communication problem.

### Stop

Stop raid expansion and reconsider the premise if any is true:

- only **0–1/5** players make a deliberate stay-versus-extract choice;
- at least **4/5** choose the same answer and explain that the alternative is
  nonviable even when asked about the opposite defense state;
- at least **3/5** describe the raid primarily as a compulsory interruption they
  would remove, rather than a consequence worth planning around; or
- the Bolt-Thrower does not change any participant's reasoning despite being
  noticed and understood.

### Invalid batch

The batch is invalid if fewer than five sessions yield usable evidence because
of technical failure, protocol contamination, or non-cold participants. Repair
the test and run a fresh valid batch; do not average invalid sessions into the
decision.

## Result

Not tested.

## Decision

Pending.

## Canon changed

None pending evidence.
