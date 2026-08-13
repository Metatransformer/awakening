# Bosses and minibosses — current combat contract

This file is the concise player-facing and acceptance contract for the four
floor bosses and four optional floor minibosses. Runtime authority is
`scripts/actors/enemies/boss_db.gd`, `boss.gd`, and
`scripts/world/boss_arena.gd`; if a number here disagrees with those files, the
runtime is the fact and this document must be corrected in the same change.

The roster cap remains four bosses and four minibosses. All eight reuse the
existing monster models, five attack shapes, shared actor, and shared arena.

## Critical assessment

The old combat was readable but inert and polite. Bosses walked to a fixed ring,
stopped completely for tells and recoveries, accepted unconditional chip damage,
and called recovery a “punish” even though the player had solved no
vulnerability. Item interactions were uneven or cosmetic. The player mostly
waited for a safe clock and subtracted a health bar.

The current structure is materially better. Orbiting and repositioning create
spatial pressure; charges, sweeps, leaps, thrown zones, bombs, summons, and arena
turns move the question around the room; and health damage now follows an
authored read-and-answer loop. That is stronger agency, not proof of fun.

The shared shell also creates a serious risk of ritual repetition: wait for the
named beat, use the floor item, spend one segment, repeat. Four different skins
can still feel like one boss. The flat-colour weak-point marker and whole-body hit
acceptance during true stagger are greybox readability compromises, not a final
fictional solution. Bomb fights can become trivial if the boss’s own projectile
is too easy to park beside its body. Automation can prove the shell is coherent;
only cold play can establish whether the fights are exciting, legible, and
distinct. “Structurally better” and “playtested fun” are separate claims.

## Shared fight loop

Every fight executes the same ordered beat:

1. Between attacks, the body runs, orbits, yields when crowded, closes when far,
   turns toward the player, and repositions for a mandatory authored duration.
2. `pick_beat` selects an in-range attack using phase-specific weights and a
   repeat penalty.
3. **Tell:** the boss roots, tracks slowly, changes pose and colour, plays the
   authored cue, and shows the shape marker where applicable. Tells do no damage.
4. **Commit:** an arc or slam resolves; a charge travels; a leap relocates the
   body before impact; a thrown zone flies, lands, and burns its fuse; or a
   summon creates its capped adds.
5. **Recover and punish:** the body roots through the authored tail and aperture.
   Ordinary recovery is still armoured. Only the row’s named beat and exposure
   show the weak-point marker.
6. The correct floor item breaks that timed weak point and enters a true
   vulnerable stagger. Health damage is accepted only during that stagger.
7. When the stagger timer or one-segment damage budget expires, armour returns,
   the body repositions, and the loop repeats.

Wrong items and ordinary attacks clang against armour and deal **0 HP**. The
same is true during an aperture if the hit kind does not match. Parry remains a
shorter post-commit poise/recovery interruption. It can bring the beat’s normal
recovery forward, but it never creates health vulnerability: the authored weak
point must still appear and the correct item must still break it.

### Segment budget and cycle count

A bare sword light chain deals `2 + 2 + 4 = 8` raw damage. Each row multiplies
that exact chain to one segment. A true stagger clamps all accepted damage to the
remaining segment capacity, so one window can never skip a cycle. Ending a
window early or landing only part of the chain can leave that segment unfinished
and require another exposure.

| Fight | HP | Full-window goal | Segment cap | Row multiplier | `8 × multiplier` |
|---|---:|---:|---:|---:|---:|
| Cistern Warden | 48 | 4 | 12 | 1.50 | 12 |
| Slag Ogre | 72 | 4 | 18 | 2.25 | 18 |
| Bellwake | 96 | 4 | 24 | 3.00 | 24 |
| Riven Knight | 128 | 4 | 32 | 4.00 | 32 |
| Sluice-Keeper | 24 | 3 | 8 | 1.00 | 8 |
| Bellows-Hand | 36 | 3 | 12 | 1.50 | 12 |
| Second Voice | 48 | 3 | 16 | 2.00 | 16 |
| Gate-Hound | 64 | 3 | 22 | 2.75 | 22; final segment is 20 |

Thus a boss needs four fully spent stagger windows and a miniboss needs three.
The count is a minimum under competent full-window play, not a promise that
partial use is rounded up for free.

### Two pressure phases

Every row changes at half health. Phase 2 keeps the same learned attacks and tell
timings, but raises movement speed and orbit strength, pulls the preferred orbit
closer, shortens reposition time, and gives more selection weight to the row’s
dangerous beat. There is one health bar.

Full bosses keep three beats, four damage cycles, and one arena turn at the same
half-health threshold. Minibosses keep two beats, three damage cycles, smaller
arenas and shorter pressure, and have no arena turn. Their actor phase changes
without adding a room event.

### Closed attack vocabulary

| Shape | Runtime meaning | Primary defensive read |
|---|---|---|
| `arc` | One cone query at commit, using authored reach and half-angle. | Leave the fan or block/parry when direction permits. |
| `slam` | One disc or annulus query at impact; some slams include a leap. | Read inner and outer radii, then cross to safe floor. |
| `charge` | The body travels a locked lane, hits each victim once, and stops at reach or a wall. | Leave or obstruct the lane; shoot only during the authored charge aperture. |
| `zone` | Projectiles fly to marked destinations, land, burn a fuse, then burst. | Move after the mark; for bomb apertures, deliberately bait a burst near the body. |
| `summon` | Ordinary enemies appear around the boss up to a live cap. | Manage the adds without losing the boss’s tell. |

## Floor bosses

### Floor 1 — The Cistern Warden

- **Identity:** `cistern_warden`; golem, 3.40 m, 48 HP.
- **Movement:** phase 1 `speed 2.5 / orbit 4.2 / strength 1.10 /
  reposition 0.75`; phase 2 `3.2 / 3.6 / 1.45 / 0.60`.
- **Break:** sword after **Cistern Drop** enters its recovery aperture; 2.8 s
  true stagger, four 12 HP segments.
- **Arena:** 11.0 m, no cover. At half health the seal shrinks to 8.5 m and
  pulls bodies out of the lost annulus before the inner fence rises.
- **Reward:** Bow in the great chest; loose `anvil_plate` relic.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| Sluice Sweep (`sluice_sweep`) | 1.05 s, rear/MOSS | arc, 4.6 m, 75° | 3; light KB, 0.24 s stun | 0.80 / 1.10 / 1.10 | 0–6.0 m | 3.0→2.2 |
| **Cistern Drop** (`cistern_drop`) | 1.30 s, rise/BONE | annular slam, 2.1–6.2 m; leap 0.78 s/2.2 m | 4; heavy KB, 0.36 s stun | 1.10 / 1.60 / 1.60 | 0–7.5 m | 3.0→4.8 |
| Drown Pool (`drown_pool`) | 0.95 s, tilt/COBALT | 2 zones, 2.6 m radius, 0.65 s flight/1.8 m arc, 1.10 s fuse | 3; light KB, 0.20 s stun | 0.55 / 1.35 / 1.60 | 0–14.0 m | 2.0→2.6 |

The phase weight shift makes the inward-answer leap more frequent while
movement closes the orbit. This fight teaches that the loudest ring may be
answered by moving toward the body.

### Floor 2 — The Slag Ogre

- **Identity:** `slag_ogre`; ogre, 3.80 m, 72 HP.
- **Movement:** phase 1 `2.7 / 4.8 / 1.15 / 0.75`; phase 2
  `3.5 / 4.1 / 1.50 / 0.55`.
- **Break:** Bow or Fire Arrow **during Bellows Charge travel**, not during its
  tell; 3.2 s true stagger, four 18 HP segments.
- **Arena:** 12.0 m with three cover posts. At half health two posts sink,
  leaving one and opening the charge lanes.
- **Reward:** Burst in the great chest; loose `kiln_core` relic.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| **Bellows Charge** (`bellows_charge`) | 0.90 s, tilt/RUST | charge, 11.0 m, 1.5 m radius, 13.0 m/s | 4; heavy KB, 0.40 s stun | 1.20 / 1.70 / 1.70 | 4.5–16.0 m | 3.0→4.8 |
| Slag Backhand (`slag_backhand`) | 0.72 s, rear/VITAL | arc, 4.2 m, 95° | 5; heavy KB, 0.30 s stun | 0.70 / 1.00 / 1.00 | 0–5.5 m | 4.0→4.5 |
| Tap the Ladle (`tap_the_ladle`) | 1.15 s, crouch/BONE | 3 zones, 2.3 m radius, 0.75 s flight/2.2 m arc, 1.30 s fuse | 4; light KB, 0.22 s stun | 0.90 / 1.45 / 1.70 | 0–16.0 m | 2.0→1.6 |

### Floor 3 — The Bellwake

- **Identity:** `bellwake`; wraith, 4.20 m, 96 HP.
- **Movement:** phase 1 `2.9 / 5.3 / 1.10 / 0.70`; phase 2
  `3.8 / 4.5 / 1.50 / 0.50`.
- **Break:** Burst/bomb during a live **Undertow** zone aperture; 3.2 s true
  stagger, four 24 HP segments. Its own Undertow burst is the renewable fallback
  only when the player lures the marked destination close enough to the body.
- **Arena:** 13.0 m, no cover. At half health the room sconces douse to 15% while
  unshaded danger marks and the strongly tinted body remain readable.
- **Reward:** Hookshot in the great chest; loose `sounding_rod` relic.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| The First Toll (`first_toll`) | 1.20 s, rise/ARCANE | solid slam, 7.5 m; leap 0.95 s/3.0 m | 5; heavy KB, 0.34 s stun | 1.15 / 1.55 / 1.55 | 0–9.5 m | 3.0→4.2 |
| The Hushing Choir (`hushing_choir`) | 1.40 s, spread/COBALT | summon 2 skeletons, cap 4, radius 8.0 m | 0; no KB/stun | 1.30 / 2.00 / 6.00 | 0–16.0 m | 1.0→0.7 |
| **Undertow** (`undertow`) | 1.00 s, tilt/BONE | 1 zone, 3.2 m radius, 0.80 s flight/2.6 m arc, 1.20 s fuse | 5; light KB, 0.26 s stun | 0.60 / 1.20 / 1.40 | 0–16.0 m | 3.0→4.8 |

### Floor 4 — The Riven Knight

- **Identity:** `riven_knight`; iron knight, 3.60 m, 128 HP.
- **Movement:** phase 1 `3.2 / 4.4 / 1.30 / 0.60`; phase 2
  `4.3 / 3.7 / 1.80 / 0.45`.
- **Break:** Hookshot after **Call the Iron** enters recovery; 3.4 s true
  stagger, four 32 HP segments.
- **Arena:** 12.5 m with two cover pylons. At half health a 3.0 × 2.4 × 3.0 m
  keystone drops at centre with a hook target on top.
- **Reward:** Far Lantern in the great chest; loose `pillar_shard` relic.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| Gate Lunge (`gate_lunge`) | 0.78 s, crouch/VITAL | charge, 12.0 m, 1.2 m radius, 16.0 m/s | 6; heavy KB, 0.38 s stun | 1.05 / 1.35 / 1.35 | 1.0–16.0 m | 3.0→4.2 |
| Riven Arc (`riven_arc`) | 0.62 s, rear/RUST | arc, 4.0 m, 70° | 6; heavy KB, 0.32 s stun | 0.65 / 0.90 / 0.90 | 0–5.5 m | 4.0→5.0 |
| **Call the Iron** (`call_the_iron`) | 1.45 s, spread/ARCANE | summon 2 wraiths, cap 2, radius 9.0 m | 0; no KB/stun | 1.40 / 2.10 / 8.00 | 0–16.0 m | 1.0→2.5 |

## Floor minibosses

These are optional treasure-branch fights. Each has two beats, a smaller arena,
no arena turn, and three fully spent damage cycles. They still use the same
armour, aperture, true-stagger, segment-cap, movement, phase, and selection
rules as the bosses.

### Floor 1 — The Sluice-Keeper

- **Identity:** `sluice_keeper`; troll, 2.60 m, 24 HP.
- **Movement:** phase 1 `2.0 / 3.7 / 0.85 / 0.75`; phase 2
  `2.6 / 3.2 / 1.10 / 0.65`.
- **Break:** sword after **Flood-Stomp** recovery; 2.5 s stagger, three 8 HP
  segments. Arena 7.5 m, no cover. Grants the `makers_mark` progress token.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| Wheel-Swing (`wheel_swing`) | 1.15 s, rear/COBALT | arc, 4.0 m, 42° | 3; heavy KB, 0.28 s stun | 0.85 / 1.35 / 1.35 | 0–5.5 m | 3.0→2.0 |
| **Flood-Stomp** (`flood_stomp`) | 0.95 s, crouch/MOSS | solid slam, 5.0 m; leap 0.70 s/1.3 m | 3; light KB, 0.22 s stun | 0.60 / 1.15 / 1.40 | 0–7.0 m | 2.0→4.2 |

### Floor 2 — The Bellows-Hand

- **Identity:** `bellows_hand`; orc, 2.55 m, 36 HP.
- **Movement:** phase 1 `2.2 / 4.2 / 0.90 / 0.75`; phase 2
  `2.9 / 3.6 / 1.20 / 0.60`.
- **Break:** Bow or Fire Arrow during **Plate-Advance** travel; 2.9 s stagger,
  three 12 HP segments. Arena 8.0 m with two cover posts. No direct drop.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| **Plate-Advance** (`plate_advance`) | 1.00 s, crouch/RUST | charge, 8.0 m, 1.4 m radius, 8.0 m/s | 3; heavy KB, 0.30 s stun | 1.10 / 1.45 / 1.45 | 5.0–16.0 m | 3.0→4.3 |
| Ember-Cough (`ember_cough`) | 1.05 s, spread/VITAL | 3 zones, 2.2 m radius, 0.65 s flight/1.7 m arc, 1.20 s fuse | 3; light KB, 0.20 s stun | 0.75 / 1.30 / 1.55 | 0–16.0 m | 2.0→2.0 |

### Floor 3 — The Second Voice

- **Identity:** `second_voice`; skeleton, 2.55 m, 48 HP.
- **Movement:** phase 1 `2.4 / 4.6 / 0.90 / 0.70`; phase 2
  `3.1 / 3.9 / 1.20 / 0.55`.
- **Break:** Burst/bomb during live **Keening** zones; 2.8 s stagger, three 16 HP
  segments. Its own Keening burst is renewable only if baited beside the body.
  Arena 9.0 m, no cover. No direct drop.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| The Sounding Ring (`sounding_ring`) | 1.15 s, spread/BONE | annular slam, 3.0–7.5 m; leap 0.85 s/1.7 m | 4; heavy KB, 0.32 s stun | 1.00 / 1.40 / 1.65 | 0–16.0 m | 3.0→2.0 |
| **The Keening** (`keening`) | 0.95 s, rise/COBALT | 2 zones, 2.4 m radius, 0.70 s flight/1.8 m arc, 1.05 s fuse | 4; light KB, 0.26 s stun | 0.70 / 1.20 / 1.20 | 0–8.0 m | 3.0→4.4 |

### Floor 4 — The Gate-Hound

- **Identity:** `gate_hound`; kobold, 2.30 m, 64 HP.
- **Movement:** phase 1 `2.7 / 4.0 / 1.00 / 0.65`; phase 2
  `3.6 / 3.4 / 1.40 / 0.50`.
- **Break:** Hookshot during the thrown **Overhand** zone aperture; 3.0 s
  stagger, three segments capped at 22 HP. Arena 8.5 m, no cover. No direct drop.

| Beat | Tell | Commit | Damage / impact | Recover / punish / cooldown | Range | Weight P1→P2 |
|---|---:|---|---:|---|---|---:|
| Gate-Shard (`gate_shard`) | 0.85 s, tilt/VITAL | arc, 9.0 m, 22° | 4; light KB, 0.22 s stun | 0.60 / 1.15 / 1.40 | 5.0–16.0 m | 3.0→2.0 |
| **The Overhand** (`overhand`) | 0.80 s, rear/BONE | 1 zone, 3.0 m radius, 0.75 s flight/2.1 m arc, 0.95 s fuse | 6; heavy KB, 0.34 s stun | 0.85 / 1.40 / 1.40 | 0–6.0 m | 4.0→4.6 |

## Renewable bomb fallback

Bellwake and Second Voice do not require remaining Burst ammunition. During the
authored Undertow or Keening aperture, one of their own thrown zones may break
the bomb weak point if its burst radius actually reaches the body. The first
destination is the player’s position at commit, so the player must bait the
throw, preserve the live aperture, and leave before detonation. It is not an
automatic self-stagger and must never be documented or tuned as one.

This fallback is a skill test with a narrow safety margin. If ordinary orbiting
or a forgiving radius makes “stand beside it, walk away” reliable without
reading flight and fuse, the bomb fights have lost their resource decision and
need positioning or timing revision.

## Acceptance and proof contract

The implementation is accepted mechanically only when automated proof covers
all eight rows and demonstrates:

- armour, wrong-item, ordinary-hit, and parry gates; exact item/beat/exposure
  mappings; true-stagger timers; segment caps; and minimum three/four-cycle kills;
- phase transition at half health, unchanged beat sets, changed movement and
  weights, and one room turn for each full boss but none for minibosses;
- measurable orbit/reposition displacement, charge travel and wall stops, leap
  displacement/landing, thrown projectile flight/landing/fuse/burst, summons and
  caps, and the deliberately baited own-projectile fallback;
- representative frames showing each weak-point aperture, true stagger, motion
  family, and arena turn with readable silhouettes and danger marks.

Passing automation proves state and presentation contracts, not enjoyment. The
human gate is the precommitted five-session test in
[design-tests/BOSS_DYNAMISM_PROOF.md](design-tests/BOSS_DYNAMISM_PROOF.md). Until
that gate passes, the correct status is **implemented and structurally stronger;
fun and distinctness unproven**.
