# Design test — Boss Dynamism Proof

- **Status:** Runtime and dedicated automation pass; human test pending
- **Owner:** Project owner
- **Implementation:** issue #203
- **Canon owners in scope:** [BOSSES.md](../BOSSES.md),
  [SCOPE.md](../SCOPE.md), [MECHANICS.md](../MECHANICS.md)

## Question

Do the four bosses and four minibosses create readable, active, and distinct
item-led fights, or does their shared armour/aperture/stagger shell reduce them
to the same repeated ritual?

## MDA frame

- **Target aesthetic:** earned mastery under spatial pressure—the player reads a
  dangerous body and room, deliberately creates vulnerability, and feels that
  each floor asks for a different kind of control.
- **Desired dynamics:** players move with orbit and arena pressure; identify the
  authored exposing attack; apply the correct floor item at the correct moment;
  exploit but cannot overrun a damage segment; notice phase 2; and describe the
  fights by different spatial and timing decisions.
- **Failure dynamics:** waiting passively for a highlighted orb; testing every
  item until one works; blaming damage on unreadable or unavoidable attacks;
  automatic self-staggers in bomb fights; long dead intervals; missing the phase
  transition; or describing all eight as the same four-hit ritual in different
  skins.
- **Mechanics under test:** the Boss grammar row in
  [MECHANICS.md](../MECHANICS.md): armoured body, timed attack-specific aperture,
  floor-item break, true stagger, three/four capped damage cycles, row-driven
  orbit/reposition, two pressure phases, and full-boss arena turns.

## Player-facing hypothesis

Given the floor’s current item and no explanation of the internal state machine,
a cold player will connect a specific attack to a timed item opportunity, use
movement and arena geometry to earn it, understand that a full stagger spends
one health segment, notice increased pressure at half health, and distinguish
the fights by more than model, colour, and attack names.

## Why it matters

The old fights were readable but inert: fixed ring movement, full stops,
unconditional chip damage, “punish” as ordinary recovery rather than a solved
vulnerability, and item interactions that were uneven or cosmetic. Issue #203
is structurally stronger, but its one shared shell may simply replace passive
chip with passive ritual. Passing the state machine cannot answer that design
question.

## Current evidence

- The runtime rows define four three-beat/four-cycle bosses and four
  two-beat/three-cycle minibosses, all with half-health pressure phases.
- `Boss` implements armour, item/beat/exposure matching, true stagger, per-window
  segment caps, orbit/reposition steering, charges, leaps, thrown zones and the
  bomb-bait fallback. `BossArena` implements the four full-boss arena turns.
- The flat-colour weak-point marker and whole-body vulnerable hit acceptance are
  acknowledged greybox readability compromises.
- `tools/directors/boss_dynamism.gd` passes all eight mappings, armour controls,
  segment arithmetic, three/four-cycle kills, movement comparison, phase changes,
  leap and thrown-zone lifecycle. `tools/directors/minibosses.gd` independently
  passes all four lower-tier fights and their arena/drop lifecycles. The issue
  #203 frame sheet has been reviewed at native 1280×720.
- No qualifying cold human session has tested recognition, attribution,
  downtime, phase perception, or sameness. Fun is unproven.

## Automated implementation gate

Run the dedicated issue #203 director coverage before recruiting players. A
human session on a mechanically failing build is invalid. Automation must prove
all of the following against runtime state, not just table values:

### State gates and mappings

- Ordinary sword, arrow, Burst/bomb and Hookshot interactions outside a true
  stagger deal 0 HP and emit armour feedback.
- A wrong item during every authored aperture deals 0 HP and does not enter
  true stagger.
- Each exact mapping works only in its named aperture:

  - Warden: sword after Cistern Drop;
  - Ogre: Bow/Fire Arrow during Bellows Charge travel;
  - Bellwake: Burst/bomb or a deliberately baited live Undertow burst;
  - Riven Knight: Hookshot after Call the Iron;
  - Sluice-Keeper: sword after Flood-Stomp;
  - Bellows-Hand: Bow/Fire Arrow during Plate-Advance travel;
  - Second Voice: Burst/bomb or a deliberately baited live Keening burst;
  - Gate-Hound: Hookshot during the thrown Overhand aperture.

- Parry creates only the shorter poise/recovery interruption. It never directly
  enables HP damage and still requires the authored item break.

### Damage and phase arithmetic

- A bare `2 + 2 + 4` chain, after the row multiplier, exactly reaches one
  segment for every row, including Gate-Hound’s 22 HP cap and 20 HP final
  segment.
- One true stagger never removes more than one segment, even under oversized or
  repeated hits. Partial use remains partial and can require an extra exposure.
- A fully spent boss takes exactly four stagger windows; a fully spent miniboss
  takes exactly three.
- Phase 2 fires once at `health / max_health <= 0.50`, retains the same beat IDs
  and tell timings, selects from phase-2 weights, and uses the phase-2 movement
  row. Each full boss applies its one arena turn before emitting the phase event;
  no miniboss applies a room turn.

### Motion and lifecycle

- Sampled chase positions show non-zero orbit and reposition displacement,
  wall-direction reversal, closer phase-2 orbit, higher phase-2 speed/strength,
  and respect for the live arena boundary.
- Both charges travel their authored lane, damage each victim at most once, and
  end on reach, wall collision, or correct arrow break.
- Every leap records start, bounded target, horizontal displacement, visible arc,
  landing commit, marker placement at the promised destination, and cleanup on
  stagger/death.
- Every thrown zone records projectile creation, flight, landing, fuse growth,
  burst, victim query, and cleanup. The own-projectile bomb fallback passes only
  when the player-marked destination is deliberately placed within burst radius
  of the body; a control cast away from the body must not self-stagger.
- Summons respect kind, count, cap, floor scaling, and cleanup without allowing
  capped selection to freeze the boss.

### Representative frame sheet

Capture at native requested resolution with the project’s quiet wrapper. The
sheet must include, at minimum:

- all eight named weak-point apertures and all eight true-stagger states;
- one clear orbit/reposition comparison before and after phase 2;
- charge tell/travel, leap tell/apex/landing, and thrown-zone
  flight/land/fuse/burst sequences;
- the Warden shrink, Ogre topple, Bellwake douse, and Riven keystone turns;
- one negative control with armour clang and one bomb cast that does not
  self-stagger.

A green log without readable frames is not a pass. A frame sheet without state
assertions is not a pass. Any failed mapping, damage leak, skipped segment,
incorrect phase, missing displacement, lifecycle leak, or misleading
representative frame is an immediate **fix-before-human-test** result.

## Smallest human test

Run at least **five cold sessions with five different players**. Participants
must not have designed, implemented, reviewed, or watched issue #203. Give them
a prepared build with the relevant floor item available and normal control
instructions only; do not name the exposing beat, aperture, required item,
cycle count, phase threshold, or bomb fallback.

Each player fights four encounters in a counterbalanced order: two full bosses
and two minibosses spanning all four item answers. Across the five-player batch,
each of the eight rows must be observed at least twice, each player must see one
bomb-bait fight, and no player may see a miniboss immediately before its same-
floor boss. If a participant wins too quickly to observe phase 2, replay that
same row from a half-health prepared state after the first attempt; record the
replay separately.

Players may stop at any time. Do not rescue a fight with hints. A hint makes all
later aperture-recognition evidence for that fight prompted rather than cold.

## Observation plan

For every encounter, log:

- every damaging failure, death, and major knockback; the player’s immediate
  attribution before any interviewer explanation; and whether the responsible
  tell and damage area were visible in the recording;
- every authored aperture opportunity, whether the player looked toward it,
  which item they tried, whether they succeeded, and whether success was cold,
  exploratory, accidental, or prompted;
- true-stagger count, full versus partial segment spend, total exposures to
  victory or stop, and the player’s prediction of remaining cycles after their
  second successful stagger;
- whether and when the player spontaneously identifies the half-health pressure
  change, plus what changed in their words;
- every dead-time interval over 3.0 seconds in which there is no readable attack,
  live hazard/add, aperture setup, meaningful reposition, or arena decision;
- for bomb rows, player position at mark and burst, boss position, whether the
  own projectile broke the weak point, and whether the player describes it as a
  deliberate bait;
- after all four fights, which encounters they can distinguish by movement,
  arena, item timing, or risk; any fight pair they call interchangeable; and a
  direct 1–5 sameness rating where 1 means wholly distinct and 5 means the same
  ritual with different presentation.

After observation, ask neutral questions:

1. What made the boss able to take damage?
2. What did you look for before using the floor item?
3. How many more openings did you expect after the second successful one?
4. What, if anything, changed around half health?
5. Which two fights asked you to move or time things most differently? Why?
6. During the thrown-zone fight, what caused the stagger?

Store raw records under `docs/playtests/`. Preserve failed attempts and exact
interventions; do not replace them with post-session summaries.

## Precommitted criteria

These thresholds apply to one batch of five valid sessions. They are decision
rules, not statistical claims, and must not be rewritten after the first session
starts.

### Pass

Pass only if the automated gate is completely green, no stop condition occurs,
and all of the following are true:

- At least **4/5 players** independently break the correct aperture in at least
  **3 of their 4 fights**, and at least **70% of all post-first-opportunity
  apertures** across the batch are recognized and answered with the correct item.
- At least **4/5** correctly explain that health requires item break followed by
  true stagger, and predict the remaining cycle count within one after their
  second successful stagger.
- At least **80% of damaging failures** are attributed to the correct attack or
  positioning error before interview explanation, with zero recorded deaths
  whose causal tell or damage area is absent from the capture.
- At least **3/5** spontaneously notice phase 2 in at least two of their full-boss
  observations and name movement, closeness, attack frequency/weight, or the
  arena turn rather than only “less health.”
- The batch median dead-time interval is **3.0 seconds or less**, and no repeated
  non-decision interval over **5.0 seconds** occurs for three or more players on
  the same row.
- At least **4/5** describe three or more fights by distinct spatial/item/timing
  decisions, no more than **1/5** gives a sameness rating of 4–5, and the median
  sameness rating is **2 or lower**.
- In bomb rows, at least **3/5** players who attempt the renewable fallback
  describe and execute it as a lure rather than reading it as an automatic cast
  outcome.

### Fix and rerun

Fix the smallest responsible cue, timing, movement, arena, or mapping and
precommit a fresh five-player batch if no stop condition occurs but any pass
threshold misses. Mandatory fix cases include:

- two or more players repeatedly use the correct item at the wrong part of the
  correct beat, or three or more need random item cycling to discover the rule;
- failure attribution falls below 80%, any death lacks a visible causal tell, or
  a marker promises safe ground that the damage query hits;
- phase recognition misses because the transition or pressure delta is not
  perceptible;
- repeated dead time exceeds the threshold;
- an own-projectile break happens accidentally more often than deliberately, or
  the fallback is either effectively automatic or too obscure for four of five
  players to explain after seeing it;
- players understand the shared shell but cannot distinguish at least one fight
  pair because movement, weights, or arena pressure do not materially change
  their decisions.

Do not add a fifth boss, third miniboss beat, fourth boss beat, sixth attack
shape, new item, or new model to rescue a miss.

### Stop

Stop and reject the current shared-shell direction if, after one bounded fix
batch, any of the following remains true:

- **3/5 or more** players rate sameness 4–5 or explicitly describe the optimal
  play as waiting for the same highlighted opening and repeating one segment;
- **3/5 or more** make no meaningful movement, arena, or timing distinction
  among their four fights despite correctly understanding the rules;
- fewer than **3/5** can independently create correct apertures in at least half
  their fights, with no single bounded readability obstruction explaining the
  miss;
- the bomb fallback remains a dominant automatic self-stagger or a bait that
  cannot be made both readable and risky without changing the shared shell.

Stopping rejects this implementation pattern, not the fixed four-boss/four-
miniboss content cap. Return to design before producing content around it.

### Invalid batch

The batch is invalid if fewer than five different cold players produce usable
sessions; if row coverage falls below two observations each; if technical
failure changes attacks, items, damage, phase, or input; if the researcher hints
before the relevant observation; or if a build fails the automated gate. Repair
the protocol/build and run a fresh batch. Do not average invalid sessions into a
decision.

---

## Result

Not tested. Automation and five cold human sessions remain pending.

## Decision

Pending.

## Canon changed

None from evidence. Issue #203’s owner override updated current canon before
human validation; this test determines whether that structure is kept, revised,
or rejected.
