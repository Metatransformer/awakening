# Glint Trial MVP

**Status: implementation authorised; human result pending.**

Issue: [#206](https://github.com/Metatransformer/awakening/issues/206)

This test exists to decide whether a finite puzzle detour belongs beside the
combat descent. It does not test a four-floor scheduler, a puzzle catalogue, or
whether more content is always welcome.

## Question

> After the Floor-1 guardian falls and the Boss Door is visibly available, do
> players deliberately choose the one-time Glint Trial detour, understand that
> its Glimmer buys permanent growth, and still experience going straight to the
> boss as a complete and valid run?

## Hypothesis

- **Aesthetic:** curiosity without obligation; a small moment of wonder after
  the combat peak.
- **Dynamic:** the player sees the boss route and side arch together, makes an
  explicit detour-or-boss choice, solves the trial once, and later spends its
  Glimmer on one understood permanent stat choice.
- **Mechanic:** one post-guardian optional annex, one existing authored puzzle,
  one stable solved id, one Glint receipt, and three one-rank choices at the
  existing garrison statue.

The falsifier is not merely that someone dislikes the puzzle. Revise or stop if
players believe it is mandatory, cannot find the boss route, enter only because
they fear losing power, do not understand the reward, or resent returning to a
solved annex.

## Prototype boundary

Run Floor 1 with the explicit user argument `--glint-mvp`. Without that
argument, the normal dungeon and its existing proofs are unchanged.

The prototype contains exactly:

- one real guardian antechamber with the Boss Door and optional side arch
  readable from the same decision point;
- one fixed `sun_nest` trial, available only after the guardian dies;
- one abandon route back to the boss choice;
- one idempotent permanent solve committed only when its immediate autosave
  succeeds; a refused save awards nothing and restores the puzzle for retry;
- one run-lifetime rule: a solved annex remains generated and solved when that
  run is resumed, then disappears only after the player starts a new run;
- one Glint cameo using the transferred Valenfeld model and existing Glint SFX;
- one derived Glimmer (`solved trials - purchased ranks`);
- one explicitly permanent health, stamina, or magic choice at the existing
  garrison statue, requiring a confirmation hold.

Do not add a random bag, drought rule, four-floor content, key-cycle rewrite,
new screen, new autoload, repeatable reward, or balance migration to this test.

## Cold-session procedure

Run five first-time sessions. Do not explain the fork, reward, or statue before
play. Start each player before the guardian and allow them to stop after their
next garrison visit.

Record, in the player's own words:

1. what each opened route appeared to lead toward;
2. why they chose boss, trial, or hesitation first;
3. whether the trial felt optional;
4. what the Glimmer was for and where they expected to spend it;
5. why they chose one stat over the other two;
6. whether a later solved visit behaved as expected.

Also record time from guardian death to route choice, wrong-route turns,
attempts to reopen or reclaim the trial, any request to skip or repeat it, and
whether the large gold `OPTIONAL GLINT TRIAL` caption made the detour feel more
important than the physically larger Boss Door. The independent implementation
critic passed the experiment but identified that salience bias as the main
question the cold sessions still need to answer.

## Precommitted decision

**Pass** only if at least four of five players identify the boss route before
entering the annex, describe the trial as optional, explain the permanent reward
without prompting, and make a reasoned statue choice. No player may believe the
trial must be repeated or discover a duplicate reward.

**Revise** if the choice is understood but the arch, reward, abandon route, or
statue comparison is unclear; change only the failed presentation and rerun five
cold sessions.

**Stop** the Glint direction if two or more players treat the annex as an
obligatory tax, if the permanent reward makes voluntary skipping feel irrational,
or if the post-combat puzzle reliably breaks the desired combat flow even when
clearly optional. A director can reject a broken implementation; it cannot pass
this human gate.

## Evidence

Automated implementation proof on 2026-08-13:

- the canonical rendered dungeon route passed 49 checks, including a live
  guardian, barred annex, real body-entered Boss Key pickup, Prompt/input-driven
  Boss Door, living floor boss, Atlas annex publication, and a real-GameCamera
  frame showing `OPTIONAL GLINT TRIAL` beside the sealed boss route;
- the shield verb first passed through a forced save refusal: no claim, cameo,
  solved id, balance, latched atom, or solved presentation survived. A second
  real shield hold used production autosave. After a full `Game`/`Run` reset,
  the production `Flow.continue_game` path regenerated the same annex cell,
  side, transform and solved socket under the restored hero; a world collision
  ray proved walkable ground and the open Boss Door still led to a living boss.
  Starting the next run cleared the run-scoped socket flag and omitted the
  annex while retaining the guardian, Boss Key and boss route;
- the flagged garrison route passed 21 checks through real Prompt, interact and
  Trade-screen input, including short-tap refusal, hold-to-confirm, exact stat
  mutation, conservation, cap refusal, Well Fed, and a save/reload round trip;
- the default no-flag garrison passed four boundary checks: its monument cannot
  take Prompt focus or open the Glint service;
- eight distinct Floor-1 run seeds passed the complete 48-check real-input logic
  proof through production floor seeding and resume. Flagged generation rerolls
  a folded base plan unless it has two distinct doorway walls and one complete
  boss-depth ray, then protects every viable annex ray from bonus-room growth;
  a bounded straight-tree is the fallback. Default unflagged generation does
  neither and consumes the same RNG calls as before;
- the default five-floor key-depth/replay suite, live Small Key loop, Floor-1
  Boss Key suite, map-lock suite, Field Notes economy/save suite, import, and
  clean boot remained green.

`puzzle_loop.gd` still reports its same five pre-existing failures on default
generation (C9, C12, C12a, E0 and G6); this prototype adds no sixth failure and
does not claim that legacy director as green.

The human result is still pending. Store five cold-session observations under
`docs/playtests/` and link them here before changing this status or enabling the
prototype by default.
