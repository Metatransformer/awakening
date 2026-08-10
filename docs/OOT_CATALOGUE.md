# The Ocarina catalogue — the source material, dungeon by dungeon

**This file owns nothing.** It is the evidence `docs/PUZZLES.md` and
`docs/BESTIARY.md` cite, read off the 1998 Nintendo Player's Guide page by page
and written down as *mechanics* — what the room asks, what answers it. No guide
prose is reproduced here and none of it needs to be: a puzzle is a rule, and a
rule is a fact.

It exists because the alternative is arguing from memory. Everyone on this
project has played Ocarina and everyone remembers a different game, and the
version we all remember is the one where every puzzle was clever. Most of them
are two atoms and a combinator. **That is the good news** — it is the whole
reason `docs/PUZZLES.md` can promise Zelda-grade rooms out of nine props.

Read §4 first if you only read one section. §1–§3 are the working.

---

## 1. The items, as verbs

Ocarina has about twenty usable items and roughly **eleven distinct verbs**
between them. The rest are numbers, tiers and keys.

| Item | The verb it actually adds | We have it? |
|---|---|---|
| Deku Stick | melee, **and a carried flame** — lights from any fire, burns on a timer, dies in water | no |
| Deku Nut | a flash that **stuns** — and fails on several enemies on purpose | no |
| Slingshot / Fairy Bow | **hit a thing you are not standing next to** | **yes** — the Bow |
| Bombs | **break cracked geometry**; also *place* and *throw into a receptacle* | **yes** — the Burst-Verse |
| Bombchu | a bomb that **drives along floors and walls** — reaches what a throw cannot | no |
| Boomerang | **arcs around cover**; stuns; **freezes a moving part** for a window; collects | no |
| Fire / Ice / Light arrow | the shot **carries an element** | no |
| Hookshot / Longshot | **pull yourself to an anchor**; pull an item; stun | **yes** |
| Megaton Hammer | heavy strike — **rusted switches**, cracked stone, a ground shockwave | no |
| Lens of Truth | reveals **false walls and invisible objects** | no |
| Din's Fire | radial fire — **lights every torch around you at once** | no |
| Ocarina songs | Song of Time **moves blocks**; Sun's Song toggles day/night; songs as keys | no |
| Shield | **reflects projectiles**; the material matters — Deku burns, Hylian does not | **yes** |
| Gauntlets / Boots | change the **strength or movement model** — lift bigger, sink, skate | no |

### What we own that this list flatters

Six of the eleven verbs are already ours in some form. Ranged hit is the Bow;
break-geometry is the Burst-Verse; traversal-pull is the Hookshot; reflect is the
Shield; melee is the sword. `docs/SCOPE.md` caps ring stops at **6** and that
ceiling is not up for negotiation, so this table is not a shopping list.

**Two things we already own are under-used, and they are the cheapest wins here.**

- **The shield is a verb and we treat it as a wall.** Ocarina uses it to solve
  puzzles (bounce a beam), to beat an enemy (send a Deku Scrub's own nut back),
  and to beat *three bosses* (Phantom Ganon, Ganondorf, Twinrova). We use it for
  one atom. See `docs/BESTIARY.md` §5.
- **The rope has never been a puzzle verb.** It is extraction furniture. Ocarina
  has no equivalent, which means there is no catalogue entry to copy — but a tool
  every player owns from minute one, with a physical anchor point, is exactly the
  shape `docs/PUZZLES.md` §1 wants more of at T0.

---

## 2. Dungeon by dungeon

Ordered as the game orders them. The heading names the item the dungeon is
*about*, because that is the structure worth stealing: **Ocarina puts the item at
the middle and spends the back half on it.**

### 2.1 Inside the Deku Tree — the carried flame

The tutorial dungeon, and it is already doing three-atom composition.

- A Deku Scrub spits nuts at you. **Block, and the nut goes back**; it surrenders
  and tells you something. The shield's first use is offensive.
- Shoot a **ladder release** across a room to drop the way up. A switch you can
  only reach at range.
- Bars drop and lock you in a room with **one lit torch and one dark one**. Carry
  the fire across. The bars lift.
- **Burn the web floor** to fall to the basement — but the carried flame burns out
  on a timer and **dies in water**, so the route to the web is the puzzle.
- The web that matters needs a **block pushed first** to make a dry stepping
  stone, so the flame survives the crossing. *Block → carry fire → burn.* Three
  atoms, nested, in the first dungeon.
- An **underwater switch drains the room — briefly.** Inside the window you push
  a block that is otherwise submerged. A timer that changes what the room *is*.
- An **eye switch, shot at range**, opens a barred door.
- Three Deku Scrubs must be beaten in **an order taught elsewhere in the dungeon**.
  Information as a key.
- **Gohma:** its eye flashes before it strikes — a ranged hit into the flash stuns
  it, then melee. It retreats to the ceiling and **spawns adds** when pressured.

### 2.2 Dodongo's Cavern — bombs

The purest "the item is the dungeon" of the three child dungeons.

- Bomb **cracked walls and cracked doors**. This is the whole floor's grammar.
- A **pressure plate that only holds while weighted** — and nothing you own is
  heavy enough, so you **push an Armos statue onto it**. This is our plate-plus-
  block nest, verbatim, in 1998.
- A **row of bomb flowers detonates in a chain** — with a gap in the middle that
  you bridge by placing a bomb of your own. Propagation, plus one deliberate hole
  in the propagation.
- A **blade-trap corridor** on a fixed cycle with safe alcoves. Then a block you
  **pull out of a wall** to climb on.
- A **wall of fire blocks the exit; an eye switch sits above it.** Shoot the eye,
  the fire dies. *The answer to the hazard is never the hazard.*
- **Drop a bomb through a hole in a bridge into a giant skull's eye socket**, and
  the mouth below opens as a door. A receptacle you cannot see from where you
  stand.
- A square hole in a floor that a block fits; the only block is two rooms away.
- The **Hylian shield survives Fire Keese and the Deku shield burns off your
  back.** Equipment as a gate, and the failure is loud.
- **King Dodongo:** it inhales. **Throw a bomb into the open mouth** — it stuns,
  then sword. *The boss is a receptacle for an atom you already have.*

### 2.3 Inside Jabu-Jabu's Belly — the boomerang

The escort dungeon, and the one with the two best "no straight line" puzzles.

- **You carry Princess Ruto and cannot jump while carrying her.** She has to be
  thrown up to a ledge first, then you climb. A traversal tax with a body.
- **Crates hold a switch down** — the weighted plate again, third dungeon running.
- A **rising vertebra** as a moving platform; **suction holes** as a flow hazard.
- A tentacle whose weak point is its **thin base**, not its head.
- Bigocto: **outrun it and hit its back.** Positional, not reflexive.
- **The boomerang freezes the wagging appendages** long enough to walk across
  them. A ranged tool that stops a moving part for a window.
- **The boomerang's arc reaches a switch behind a wall of web** — a switch with no
  line of sight to anywhere you can stand.
- **Barinade:** strip its Bari shell with the boomerang, hit the exposed nucleus
  **before the shell reforms.** A timer inside a boss.

### 2.4 Forest Temple — the bow

The densest dungeon in the game for compositional puzzles, and the one that
matters most to us: it is the temple that is *about* a ranged item.

- **Twin Stalfos miniboss.** Killing both materialises the key chest. Stalfos
  ignore Deku Nuts and Din's Fire — **only steel works**, and that refusal is the
  design.
- A carved block moved by **Song of Time** reveals a door.
- Hookshot balcony to balcony. A switch **drains a well** to expose a key.
- **Pull-then-push blocks:** pull one out of its slot, walk around it, push it
  from the far side. Two of these, on two floors.
- **The twisted corridor.** An eye switch sits above the door. Shoot it and *the
  corridor untwists* — every room beyond it is now at a different orientation.
  **An atom that transforms geometry, not a door.**
- **Shoot an arrow through a standing flame and it arrives as a fire arrow**,
  melting an ice-covered eye switch. This is the single best mechanic in the
  guide: it does not light a second torch, it **changes what the projectile is.**
- A ceiling that smashes down **with holes in it** — stand where a hole will land.
- **Poes.** Shoot the *painting* and the ghost hops to another painting; three
  hits materialise it. The third one wants **four blocks pushed together to
  assemble a picture**. The fourth is **the real one among three fakes**, and only
  the real one gives you a target.
- **The rotating basement.** Push blocks to spin an entire ring of walls, aligning
  its openings with switches in the side rooms. Hit every switch and the door
  opens. *The room's connectivity is the variable.*
- **Phantom Ganon:** pick the real rider out of the paintings and shoot it, then
  **deflect its lightning back with the sword** — four times in a row — then melee.

### 2.5 Fire Temple — the hammer

The dungeon that proves "earned items retro-unlock the world."

- **Free the captive Gorons**, one per cell, scattered through the floor. Each one
  pays out. A collection quest that is also the map.
- **A switch temporarily kills the fire at the top of the stairs.** Hit it, then
  race up before it returns.
- **Rusted switches, stone idols and hieroglyph platforms are inert until you have
  the Megaton Hammer** — and then half the dungeon you already walked through has
  new things in it. This is the shape the whole project wants.
- The **Goron Tunic** is required to survive the heat at all. Equipment as a gate.
- **Flare Dancer** has **two answers**: bomb or hookshot the core when it is
  exposed, *or* ground-pound it with the hammer. At depth, Ocarina stops insisting
  on one solution.
- **Volvagia** pops from one of several holes — hammer its head as it emerges,
  then survive the flight phase.

### 2.6 The Bottom of the Well and the Ice Cavern — the two short ones

- **Lens of Truth reveals false walls, invisible floors and hidden chests.** An
  item whose entire verb is *information*.
- **Dead Hand:** hands grab and hold you; the head is only exposed while a hand
  has you. **The grab is the opening.**
- **ReDead** paralyse you with a look. Being rooted next to one is the whole
  threat; killing them at range is the whole answer.
- **Blue fire in a bottle melts red ice.** A consumable as a key, carried between
  rooms.

### 2.7 Water Temple — the longshot, and the water levels

The most structurally ambitious dungeon in the game.

- **Three water levels**, set at three stations scattered across the floor. Each
  setting **reconfigures reachability for the entire dungeon** — doors above the
  line, doors below it, a shaft that is a swim or a climb depending. This is a
  *dungeon-scale* version of what a switch does room-scale.
- **Iron Boots to sink, Hover Boots to skate.** The movement model itself is the
  item.
- **Arrows shot through a standing flame arrive hot** and light torches across the
  room. Second dungeon to use it — it is a real pattern, not a one-off.
- **Dark Link** mirrors your moveset and blocks everything you throw. He is beaten
  by the tools that are not the sword.
- **Morpha:** hookshot the nucleus *out of* its water column and cut it on dry
  ground. The item is the answer to the boss's positioning, not to its health.

### 2.8 Shadow Temple — the lens

- Invisible floors, illusory walls, paths that exist only through the Lens. The
  dungeon is a **trust problem**.
- Guillotines and scythes on fixed cycles; a fan that pushes you off a ledge.
- A stone boat ride with beats along it.
- **Bongo Bongo:** its hands are the threat and the eye is the target, and neither
  is visible without the Lens.

### 2.9 Spirit Temple — the mirror shield

The densest single page in the guide, and the one that answers the most design
questions we have.

- **The Cobra Mirror.** A rotatable statue reflects a shaft of light. Aim it at
  **several different sun switches** around the room: one opens the door, another
  **spawns a treasure chest**, another **spawns an enemy**. *One aimable source,
  many targets, a different outcome at each.*
- **Hammer a rusted switch** and a lift comes down — a shortcut back to the
  entrance, opened from the far side.
- ***Trial by fire*** has two answers: **lure an Anubis into a wall of fire** so
  the hazard kills it, or just shoot it with Fire Arrows.
- **Bait an Armos onto a switch that must be held down.** The weighted plate for
  the fourth time, except the weight is a monster and it has to be led there.
- **The Mirror Shield bounces light from a high window onto a sun switch.**
- A **climbing wall of moving blocks** — the platform is the puzzle.
- **The "key of fire" room needs four distinct verbs in one room:** a hammer
  ground-pound, hammer blows on doors, an arrow into an eye switch, and a climb
  onto ice to reach a switch. This is what depth looks like — not a harder atom,
  **more verbs per room.**
- **Iron Knuckle:** an armoured biped with an axe. Its armour comes off in pieces
  as you fight, and it gets *faster* as it gets lighter.
- **Twinrova:** two witches, fire and ice. **Absorb three shots of one element
  with the Mirror Shield and fire them back at the other sister.**

### 2.10 Gerudo Fortress and the Training Ground

- Patrolled halls with sight lines. **Guards are stunned by arrows and by nothing
  else**; being seen puts you in a cell.
- **Free four captives**, one at a time, each behind a different route.
- The Training Ground is a set of **timed challenge rooms** — silver rupees under
  blades, on a clock.

### 2.11 Ganon's Castle — the finale shape

**Six trials arranged around a central hub, one per temple**, each a compressed
exam in that temple's verb. Clear them and the bridge to the tower forms.

- **Ganondorf** returns the shield's verb one last time: deflect his energy back,
  repeatedly, then Light Arrow, then sword.
- **Ganon** knocks the Master Sword out of the arena and rings it with fire.
  **Blind him with a Light Arrow, hammer the tail**, and only once the arena
  subsides can you recover the sword and finish it. *The boss takes your best tool
  away and hands the fight to your second-best.*

---

## 3. Enemies and bosses, keyed to the item that answers them

The important column is the third one. Ocarina's roster is not "monsters with
health" — **most of its memorable enemies exist to ask for a specific item**, and
the ones that do not are the ones nobody remembers.

| Enemy | What it does | What answers it |
|---|---|---|
| Deku Scrub | spits a nut | **shield** — send it back |
| Skulltula | armoured face, soft back | **position** — get behind it |
| Lizalfos | fast, aggressive, hard to pin | **stun**, then strike |
| Stalfos | shielded, parries, **immune to stun and to fire** | **steel only** — the refusal is the design |
| Iron Knuckle | armoured biped, huge axe, armour sheds as it takes hits | patience; it speeds up as it lightens |
| ReDead | **paralysing gaze**, then a lethal grab | range, or break line of sight |
| Gerudo guard | patrols, alerts, cannot be staggered in melee | **arrow only** |
| Like Like / Dead Hand | **grabs you and takes your equipment** | kill it and it gives the gear back |
| Wolfos | circles, guards its front | wait for the swipe, hit the flank |
| Poe | invisible or fake; hops between hosts | ranged, at the *right* host |
| Dark Link | **mirrors your moveset**, blocks the sword | everything that is not the sword |
| Beamos | rotating eye, fires on sight | bomb the base; it cannot be melee'd |
| Armos | statue that wakes and charges — **and can be led** | **bait it onto a plate** |
| Flare Dancer | core exposed only in a window | **two answers**, both fine |

### The five boss shapes, all of them

Every boss in the game is one of these, and three of the five are things we can
build out of props that already exist.

1. **Receptacle.** The boss opens and you put an atom in it. *King Dodongo.*
2. **Exposed weak point on a timer.** A beat strips its cover; hit the thing under
   it before the cover comes back. *Barinade, Gohma, Morpha.*
3. **Reflect.** It throws something and the shield sends it back. *Phantom Ganon,
   Ganondorf, Twinrova.*
4. **Positional.** The boss is unreachable where it stands; an item moves it or
   moves you. *Morpha (hookshot the nucleus out), Volvagia (the holes).*
5. **Disarm.** It takes your primary weapon away and the fight is fought with the
   rest of the kit. *Ganon.*

**None of the five is a damage race, and none of them has a second health bar.**
Ocarina's escalation is *the arena changing*, not the numbers going up. That is
worth writing on the wall: `docs/SCOPE.md` §1 caps us at one phase and three
beats, and Ocarina never needed more than that either.

---

## 4. What repeats — the twelve patterns worth stealing

If you read nothing else here, read this. **A pattern is on this list because it
appears in at least two dungeons**, which is the difference between a design and
a set piece.

| | Pattern | Seen in |
|---|---|---|
| **1** | **Carry fire from one flame to another, on a timer, and water kills it** | Deku Tree, Fire, Spirit, Water |
| **2** | **A switch held only while weighted — so bring a weight, or bait one** | Dodongo, Jabu-Jabu, Spirit |
| **3** | **A switch with no line of sight — the answer is a tool that curves** | Jabu-Jabu, Spirit |
| **4** | **Shoot the thing above the hazard; the hazard is never the answer** | Dodongo (fire wall), Forest (twisted corridor) |
| **5** | **A projectile passes through a hazard and arrives as something else** | Forest, Water |
| **6** | **Reflect it back at the sender** | Deku Tree, Forest, Water, Spirit, Ganon's Castle ×2 |
| **7** | **A timer that changes the room, not the clock** — drained water, dead fire | Deku Tree, Forest, Fire |
| **8** | **A single lever reconfigures reachability across the whole dungeon** | Water (levels), Forest (rotating basement, twisting corridor) |
| **9** | **Equipment as a gate: the wrong gear fails loudly and visibly** | Dodongo (shields burn), Fire (tunic), Water (boots) |
| **10** | **At depth, two answers — and neither is the "real" one** | Fire (Flare Dancer), Spirit (*Trial by fire*) |
| **11** | **A new item makes props you already walked past newly meaningful** | Fire (rusted switches), whole-game (hookshot targets) |
| **12** | **Free the captives, one per route** | Fire (Gorons), Gerudo Fortress (carpenters) |

### The three that change how we should build

**Pattern 5 — transmutation — is the one to take first.** It is the only mechanic
in the guide that lets a *lower-tier* item answer a *higher-tier* lock, which is
exactly the constraint `docs/PUZZLES.md` §0 rule 1 fights with on every floor. See
`docs/PUZZLES.md` §3's **convert**.

**Pattern 8 is what "depth" actually means.** Not harder atoms — a room whose
*shape* is the variable. `MazeRoom` is already a small version of it and nobody
named it; §3's **reconfigure** names it.

**Pattern 11 is the whole pitch.** *"Dungeons that respect your earned items"* is
pattern 11, and it is nearly free for us: `PuzzleAtoms.pool(max_tier)` already
draws from every tier at or below the player's, so a floor-4 room can be built out
of a T0 atom under three combinators. The bow does not stop mattering on floor 3;
it becomes an ingredient.
