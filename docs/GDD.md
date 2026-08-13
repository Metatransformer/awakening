# The Lower Worlds: Awakening — Game Design Document

This document owns the north-star game design. Read [NOW.md](NOW.md) for the
active proof, [SCOPE.md](SCOPE.md) for the ceiling, and [README.md](README.md) for
focused system owners.

## 1. Elevator pitch

> An Ocarina of Time-style roguelite where you find artifacts, solve ancient
> puzzles, improve a living garrison, and defend what you built when monsters
> raid after dark.

The experience balances four strong flavors:

> base building <> warm campfire/home moments <> Indiana-Jones dungeon diving
> <> defending something built with real stakes

The Sunken Cut supplies danger, discovery, and salvage. The Highbridge garrison
turns it into capability, belonging, and something worth protecting. Neither
half is a lobby for the other.

## 2. Player fantasy

You are Kael, a silent cadet of the Far Lantern Society: explorer, puzzle-solver,
fighter, and increasingly trusted resident of a frontier expedition.

You descend into a dead civilization with a small kit and imperfect knowledge,
read rooms, improvise with physical systems, decide what risk is worth taking,
and bring singular discoveries home. At the garrison, they become tools,
services, routines, visible improvements, and defenses.

The fantasy is knowing the people, walking the yard, seeing what changed,
sleeping while others keep watch, and choosing whether to trust what everyone
built together—not command from a distant menu.

## 3. Design pillars

### Ocarina feel is non-negotiable

Movement, camera, targeting, combat, readable enemies, and item-driven puzzles
must feel deliberate and physical. New features do not excuse a weaker
moment-to-moment game. [CONTRACT.md](CONTRACT.md) owns measured implementation
rules.

### Adventure rewards curiosity

The player should want to look behind the wall, revisit an old route with a new
verb, test an interaction, and learn what a named object changes. Authored
anchors give discoveries identity; generated connective spaces keep routes from
becoming rote.

### Greed authors danger

Difficulty is partly a decision: go deeper, move faster, carry more, or leave.
The ordinary Escape Rope ends a descent, but using it has a known cost. The game
must preserve choices where caution and ambition are both defensible.

### Home is built, lived in, and defended

The garrison changes because of the player's expeditions, but it also has a
civil rhythm and responsibilities of its own. Its people work, gather, sleep,
build, and face consequences. A defense matters because it belongs to a home the
player has inhabited. Small acts such as tending the hearth, stocking supper,
and staying connected make care legible without turning residents into meters
to manage or services to unlock.

### Bright above, warm below

The visual target is PS2-era stylized realism. Exteriors are bright, welcoming
sunny places; dungeons are dark but shaped by warm local light, with threats,
routes, and puzzle verbs always readable. [STYLEGUIDE.md](STYLEGUIDE.md) owns
the reference roles and visual gates.

### Consequences are legible and recoverable

Warnings arrive before commitments. Losses are visible and attributable. A
setback should create a recovery story, not invalidate a save. The player should
be able to explain what happened, why, and how to put it right.

## 4. Game loop

1. **Prepare, build, and live.** Use the garrison's services, tend current
   responsibilities and provisions, choose equipment, and see what the outpost
   needs.
2. **Delve, explore, and loot.** Fight readable encounters, solve ancient
   mechanisms, find artifacts, decide whether a vein deserves Pickaxe
   durability, and choose what deserves scarce carrying space.
3. **Receive warning.** A raid warning may arrive while the player is safe,
   committed, or painfully close to a discovery.
4. **Choose.** Continue the descent, retrace the stairs, or use the normal
   Escape Rope and end the run normally. Floor 1's up stair reaches the same
   priced extraction settlement. A raid call never teleports the player and
   never provides a special free extraction.
5. **Defend or trust preparations.** Return and fight, or remain away and rely
   on the defenses and people already in place.
6. **Repair and recover.** Read the outcome in the garrison, restore what was
   lost, and adjust future preparations.
7. **Descend again.** A new curiosity, need, recovery goal, or ambition
   re-primes the loop.

The central decision is not simply “stay or go home.” It is “what matters most
right now, and what have I done to make either answer survivable?”

## 5. Magic moments

- A thrown explosive barrel starts a chain reaction through a room.
- A hanging lantern drops onto a barrel and turns observation into a plan.
- The world pauses as night falls or the sun rises: a brief full-screen title,
  the new day number, and one unmistakable natural sound mark the change.
- The raid warning arrives at the worst possible moment: deep, loaded, and near something the player badly wants.
- A distant horn tears the player out of sleep and into a garrison already moving.
- The first defense the player built fires when it matters.
- A stolen artifact leaves a visibly empty mount in the relic hall.
- After a successful defense, the player returns to the campfire and finds home bruised but alive.

These moments are promises, not permission to build every supporting system
now. [NOW.md](NOW.md) names the smallest active proof.

## 6. Game progression

Progression is a change in relationship to the same place, not an act-by-act
inventory.

### Arrival

The garrison is sparse and functional. Kael is briefed, learns its people and
services, and makes the first descent as a newcomer with little to lose.

### Belonging

Repeated returns create familiarity. New residents and routines make the yard
feel inhabited; artifacts and upgrades create visible, useful change. Warmth at
the hearth and a shared supper matter because the player knows the small,
voluntary work behind them.

### Responsibility

The player is trusted with needs larger than personal equipment. Building a
defense is optional, but the garrison's safety becomes a consequence the player
can influence.

### Preparedness

Knowledge, tools, shortcuts, supplies, and authored defenses let the player plan
for deeper risks. Preparation expands viable choices without erasing danger.

### Mastery

The player reads combat and puzzles fluently, makes confident risk decisions,
recovers from setbacks, and completes the expedition knowing the garrison
became capable through their actions.

## 7. Feature set

### Core

- Weighty third-person movement, targeting, sword-and-shield combat, committed dodges, and readable enemy telegraphs.
- One finite descent built from generated rooms and authored floors, puzzles, encounters, shortcuts, bosses, and unique artifacts.
- Bidirectional floor stairs that preserve the live trip; only floor 1's up
  stair extracts, using the ordinary priced settlement.
- A constrained bag, ordinary extraction, recoverable loss, and distinct uses for gold, components, and artifacts.
- Item verbs that open combat and puzzle possibilities rather than merely raising numbers.
- Three bounded non-combat utility tools that turn ordinary metal and home work
  into visible preparation choices without entering the combat kit.
- Existing explosive barrels may be picked up one at a time and thrown through
  the ordinary combat shoulders; Burst and the carried barrel share one
  world-space lob landing marker under issue #198.
- One living garrison where services, upgrades, artifacts, civil time, bounded
  Firewood/Hearth and fishing/provisions routines, and visible change make
  returning a mode of play without becoming a settlement simulation.
- A finite expedition with an ending; the existing endless descent remains
  post-credits play.

Focused owners in [README.md](README.md) specify these systems.

### Prove next

Only the authored one-raid vertical slice in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md): one warning
sequence, one optional defense, one attack, one recoverable theft, and one
occurrence.

The implemented slice uses a normal HUD **GARRISON** integrity bar. Only
completed attacks on the courtyard command standard reduce it. Killing every
raider while integrity remains above zero wins; reaching zero while any raider
lives is an irreversible loss, even if stragglers die afterward. Leaving and
returning preserves the same surviving wave and integrity. Five cold human
sessions remain the active proof.

### Later only if proven

- Production expansion within the hard caps in [SCOPE.md](SCOPE.md).
- More raid cadence, defenses, routes, attackers, or garrison roles only after
  the active choice proves interesting and a separate scope decision authorises
  each addition.
- Any barrel-and-lantern expansion beyond #198's single player-throw extension
  and shared Burst/barrel marker; it is not part of the raid slice.
- Further home-life responsibilities only when Firewood/Hearth or a successor
  test shows that they deepen belonging without becoming chores.
- Any mining or utility-tool expansion only after the fixed #184 slice produces
  human evidence of explainable allocation rather than compulsory sweeping.

### Not planned

- Freeform construction or a settlement-placement game.
- A second garrison, open overworld, housing economy, farming, romance, factions,
  classes, skill trees, or multiplayer.
- Level-scaled enemies, portable or dungeon-accessible storage, free fast
  travel, permanent loss of unique artifacts, or a special raid extraction.
- A spell school, a fourth working, procedural bosses, or production content
  without an approved proof.

## 8. Lore premise

Valenfeld stands over the buried works of the Vyr, an ancient people who
withdrew to their sky-seat and left dangerous machinery, unanswered puzzles,
and stolen history below.

The playable home is not Valenfeld itself. It is Highbridge garrison, a small
walled expedition at the head of the Sunken Cut. Highbridge holds the ground;
the Explorer's Guild funds the dig; the Far Lantern Society sends people like
Kael to descend, recover the truth, and return safely.

Aldric Vane commands the outpost and keeps the Society's relic record. The
garrison's limited cast, services, and comforts are a feature of the premise:
this is a working frontier home beside a dangerous shaft, not a compressed
city.

The Vyr ruins should invite discovery more often than explanation. Lore appears
through places, mechanisms, artifacts, and short human reactions. Shared world
canon belongs to [CANON_BRIDGE.md](CANON_BRIDGE.md); local story discipline
belongs to [LORE_AND_STORY.md](LORE_AND_STORY.md).

## Legacy citation index

Code comments may still cite the former GDD numbering. Use this map until those
citations are naturally touched.

| Old citation | Current owner |
|---|---|
| §1 Pitch | GDD §§1–2 and §8 |
| §§2–3 Risk, rewards, document case | [METAGAME.md](METAGAME.md) |
| §4 Pillars and combat answers | GDD §3; [BESTIARY.md](BESTIARY.md) |
| §5.1 Descent structure | [SCOPE.md](SCOPE.md); [PUZZLES.md](PUZZLES.md) |
| §5.2 Items | [ITEMS.md](ITEMS.md) |
| §5.3 Forks and puzzles | [PUZZLES.md](PUZZLES.md) |
| §§6.1–6.6 Relics, workings, gear, economy | [METAGAME.md](METAGAME.md); [ITEMS.md](ITEMS.md) |
| §6.7 Garrison life | [GARRISON_LIFE.md](GARRISON_LIFE.md) |
| §§7–7.1 Difficulty and mercy | [BESTIARY.md](BESTIARY.md); [MECHANICS.md](MECHANICS.md) |
| §8 Endgame | GDD §§6–7; [SCOPE.md](SCOPE.md) |
| §9 Input | [CONTRACT.md](CONTRACT.md) |
| §10 Rejections | [SCOPE.md](SCOPE.md) |
| §11 Proof | [NOW.md](NOW.md); [MDA.md](MDA.md); [design-tests/](design-tests/) |
