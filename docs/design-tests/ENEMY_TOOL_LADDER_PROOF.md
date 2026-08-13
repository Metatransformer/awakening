# Design test — Enemy Tool-Ladder Proof

- **Status:** Implementation proof complete; human result pending
- **Owner:** Issue [#200](https://github.com/Metatransformer/awakening/issues/200)
- **Opened:** 2026-08-13
- **Canon owners in scope:** [`../BESTIARY.md`](../BESTIARY.md),
  [`../NOW.md`](../NOW.md), [`../SCOPE.md`](../SCOPE.md)

## Question

Do players distinguish the four signature variants, discover each opening and
voluntarily use the newest tool because it shortens the fight, without treating
that tool as a hard requirement?

## MDA frame

- **Target aesthetic:** Discovery and mastery.
- **Desired dynamics:** Players name the opening and voluntarily use the newest
  tool because it shortens the fight.
- **Failure dynamics:** Players miss or confuse the cues, brute-force every
  variant, wait for a prompt, or read all four encounters as the same timing.
- **Mechanics under test:** Four behavior-bearing variants with temporary
  primitive kitbash silhouettes: Knotback/Sword, Lantern Seer/Bow, Cinder
  Automaton/Burst and Mirebell/Hookshot. Ordinary damage remains a slower answer
  to each.

## Player-facing hypothesis

After one or two encounters with each signature variant, players will identify
its opening and choose the intended tool without a prompt because that answer
ends the fight faster, while an off-tool encounter remains defeatable.

## Why it matters

The four variants are worth retaining only if they turn item acquisition into
recognisable combat mastery without adding hard locks, unreadable encounters or
four bespoke enemy systems.

## Canon and thematic contract (when applicable)

- **Parent canon entity ids:** None; this test creates no lore roots beyond the
  four variant names.
- **Ludic contract:** Read the opening and use the newest tool for the fast
  answer, or finish with ordinary damage more slowly.
- **Narrative contract:** None under test.
- **Alignment:** `ALIGNED`
- **Player-facing reveal:** The temporary room-range silhouette and the opening
  it presents; no prompt or new screen.

## Current evidence

### Automated implementation facts

The deterministic automated proof establishes only:

- ordinary damage always makes progress and can finish each fight;
- the intended tool has a measurable advantage;
- no ordinary room contains more than one signature variant;
- each temporary silhouette and its relevant states render.

`tools/directors/signature_enemies.gd` exercises the shared damage seam, every
opening/tool advantage, repeated closed-shell completion, and all five rendered
states. `tools/directors/cistern_floor.gd` checks generated rooms against the
floor signature row and rejects multiple, elite, or boss-summon signatures.
These facts prove implementation only. Directors do not prove that players can
read the silhouettes, discover the openings, prefer the tool answer or enjoy the
encounters.

### Human evidence

None. The player-facing question and result are pending observed play.

## Smallest test

After the automated facts pass, run five cold players through one fixed sequence
of four ordinary rooms in acquisition order, with one signature variant per
room. Include one assigned off-tool case after the player has met that variant.

## Observation plan

- Record when each player first distinguishes each silhouette at room range,
  what they call the opening, which tool they choose without prompting, time to
  defeat, and whether the off-tool case remains completable.
- Ask neutrally: "What did you notice?", "What made you choose that action?",
  "What changed the length of the fight?", and "What else could have worked?"
- Any tool hint, control correction during combat, failed render, unavailable
  tool or room containing multiple signatures is an intervention and blocks
  that session.
- Store raw notes under `docs/playtests/enemy-tool-ladder/`.

## Precommitted criteria

Write these before testing. Do not edit them after testing starts.

### Pass

- Players distinguish all four temporary silhouettes at ordinary-room range.
- After one or two encounters, players can name each opening in their own words.
- Players choose the intended newest tool without a prompt because it shortens
  the fight.
- Players can still defeat the assigned off-tool case with ordinary damage.

### Revise

- A silhouette or opening cue is repeatedly missed or confused.
- Ordinary brute force is so dominant that players do not voluntarily change
  tools.
- The four loops have samey timing despite their different silhouettes and
  tool answers.

### Stop

- The only workable version requires a hard tool lock.
- The four variants require four bespoke systems that damage encounter
  readability.

### Unknown

- Fewer than five unblocked cold sessions complete all four rooms and the
  assigned off-tool case.
- Implementation facts fail, a required tool is unavailable, or prompting or
  technical failure changes a player's choice.

---

## Result

Pending human sessions.

## Decision

Pending.

## Canon changed

None pending a human result.

## Follow-up

Run the five cold sessions.
