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

## 3. Boss and miniboss combat catalogue

The five-shape summary that used to sit here was useful as an abstraction and
false as a catalogue. It erased locomotion, arena pressure, attack grammar, the
actual opening loop, and phase structure. It also made the incorrect claim that
Ocarina’s bosses effectively have one phase. Several have explicit multi-stage
structure: Barinade has four functional stages; Phantom Ganon and Twinrova have
two major sections; Volvagia alternates grounded exposure and aerial hazard
cycles. A single health bar does not mean a single behaviour phase.

These entries paraphrase observed mechanics and strategy documentation; they do
not reproduce guide prose. Useful cross-checks are the
[complete Ocarina of Time boss list](https://www.zeldadungeon.net/wiki/index.php?mobileaction=toggle_view_desktop&title=Ocarina_of_Time_Bosses),
[Phantom Ganon strategy](https://www.zeldadungeon.net/wiki/index.php?mobileaction=toggle_view_desktop&title=Phantom_Ganon_%28Ocarina_of_Time%29),
and [Iron Knuckle entry](https://www.zeldadungeon.net/wiki/Iron_Knuckle).

### 3.1 Main bosses

#### Queen Gohma

- **Locomotion / arena:** Gohma crosses the circular floor, climbs the walls and
  ceiling, and relocates the threat above the player rather than remaining at a
  fixed combat radius.
- **Attack grammar:** on the ground she lunges and drops onto Link; from the
  ceiling she lays eggs that hatch into Gohma Larvae if not cleared.
- **Weak-point exposure:** the eye turns red before an attack or while she
  prepares the ceiling cycle.
- **Stun / damage loop:** a Slingshot seed, Deku Nut, or other valid eye hit
  stuns or drops her; sword damage is dealt while she is down, then she recovers
  and relocates.
- **Phases / escalation:** there is no hard half-health transformation, but the
  loop alternates ground pressure with a ceiling/add cycle. Fast recognition can
  prevent the adds; slow recognition makes the next cycle busier.
- **Transferable lesson:** the first boss teaches the whole sentence—read a
  body cue, hit a specific target with the dungeon verb, then spend a bounded
  melee window—while missed execution changes encounter pressure.

#### King Dodongo

- **Locomotion / arena:** he walks the lava-ring arena and, after a damage
  window, curls up and rolls about half the perimeter before stopping.
- **Attack grammar:** a long inhale precedes fire breath; the roll turns the
  circular arena itself into a timed lane. Corner Bomb Flowers renew the answer.
- **Weak-point exposure:** the open mouth during the inhale is a receptacle, not
  a general damage zone.
- **Stun / damage loop:** throw a bomb into the mouth, let the internal blast
  topple him, strike with sword or stick, then survive the roll and repeat.
- **Phases / escalation:** the same authored cycle repeats; this is one of the
  genuinely single-section fights.
- **Transferable lesson:** a boss can test an item’s spatial verb rather than
  its damage, and an arena can supply a renewable answer without executing it
  for the player.

#### Barinade

- **Locomotion / arena:** it begins tethered to the ceiling, then settles into
  the floor and finally moves rapidly around the circular chamber behind rotating
  Bari screens.
- **Attack grammar:** electrical beams and contact punish approach; successive
  Bari rings orbit as moving armour; the bare body later rams and spins through
  the room.
- **Weak-point exposure:** first the three ceiling tendrils, then the main body
  through gaps in the orbiting Bari.
- **Stun / damage loop:** sever tendrils with the Boomerang; thereafter stun the
  body with the Boomerang, kill Bari or strike the body during paralysis, and
  widen the next opening by thinning the rotating screen.
- **Phases / escalation:** four functional stages: detach the three ceiling
  tethers; dismantle the first Bari ring; fight the faster mobile body and second
  Bari ring by creating gaps; then finish the exposed, enraged body as it
  rams and fires electricity.
- **Transferable lesson:** damage to supporting actors can change the geometry
  and difficulty of the next opening. A phase can escalate by reconfiguring a
  shield rather than adding a new health bar.

#### Phantom Ganon

- **Locomotion / arena:** six paintings surround the room. He first gallops down
  painted roads, then abandons the horse and floats over the arena.
- **Attack grammar:** the painting section presents a real rider and a false
  rider, with the real exit followed by room lightning. The floating section
  uses energy orbs volleyed back and forth, plus a rare direct charge.
- **Weak-point exposure:** the real rider at the painting threshold in section
  one; the floating body only after its own orb wins the volley in section two.
- **Stun / damage loop:** shoot the real rider with Bow or Hookshot for the first
  three successful hits. Then return an orb with the sword until it strikes him,
  rush the fallen body, and spend the melee window.
- **Phases / escalation:** two explicit major sections with different
  locomotion, target-reading, attack grammar, and vulnerability rules.
- **Transferable lesson:** a phase change can retest the same broad principle—
  identify and create an opening—through a completely different player verb.

#### Volvagia

- **Locomotion / arena:** nine holes puncture a small lava-surrounded platform.
  Volvagia emerges from them, flies around the arena, or climbs to the ceiling.
- **Attack grammar:** grounded emergence threatens a close fire breath or head
  strike; aerial cycles either chase Link with fire or dislodge falling rocks.
  Later emergence sequences include false holes before the real appearance.
- **Weak-point exposure:** the head is reachable only during a real grounded
  emergence.
- **Stun / damage loop:** hammer the exposed head, then slash during the stun;
  survive an aerial hazard cycle before another hole becomes live.
- **Phases / escalation:** it alternates grounded damage cycles and aerial
  survival cycles throughout, with more deceptive hole timing as health falls.
  That is not one inert phase even though the core damage rule persists.
- **Transferable lesson:** off-screen relocation and survival interludes can
  pace a vulnerability loop, but false starts must remain readable rather than
  becoming memorization traps.

#### Morpha

- **Locomotion / arena:** the nucleus moves through a central pool and forms
  water tentacles among small platforms and a spiked perimeter. Corners provide
  safer long sight lines than the central islands.
- **Attack grammar:** tentacles rise, reach, grab, carry, and throw Link into
  damaging geometry; additional arms appear as the fight progresses.
- **Weak-point exposure:** the nucleus is visible in the water but becomes
  safely punishable only when pulled onto dry ground.
- **Stun / damage loop:** target the nucleus with the Longshot, pull it out of
  the water column, strike it before it returns, then reset distance.
- **Phases / escalation:** no explicit section break; escalation comes from more
  simultaneous tentacle pressure and less comfortable targeting space.
- **Transferable lesson:** the dungeon item can solve enemy position rather
  than armour. The arena must prevent a safe corner from trivializing the loop.

#### Bongo Bongo

- **Locomotion / arena:** Link stands on a giant drum whose impacts bounce the
  player and disrupt aim. Two detached hands act independently while the main
  body remains invisible without the Lens of Truth.
- **Attack grammar:** hands drum, sweep, punch, crush, grab, and throw; once both
  are disabled, the hidden body charges down the centre line.
- **Weak-point exposure:** stunning both hands exposes the eye during the
  body’s charge; the Lens makes that target legible.
- **Stun / damage loop:** shoot each hand, reveal and shoot the charging eye,
  then strike the fallen eye with the sword before the hands recover.
- **Phases / escalation:** the multi-step cycle repeats without a major
  transformation, but every attempt shifts from two-target control to a narrow
  reaction shot and then melee.
- **Transferable lesson:** a readable boss can require a sequence of distinct
  state gates, while arena motion taxes execution without changing the answer.

#### Twinrova

- **Locomotion / arena:** Koume and Kotake circle and hover around separated
  platforms; after fusing, Twinrova controls the air above the same arena.
- **Attack grammar:** the sisters fire opposed fire and ice beams. The fused
  form fires alternating elemental attacks and punishes mixing charges.
- **Weak-point exposure:** in the first section each sister is vulnerable to
  the other’s reflected element; in the second, the fused body is vulnerable
  only after the shield releases a stored same-element charge.
- **Stun / damage loop:** aim one sister’s beam at the other with the Mirror
  Shield. After fusion, absorb three consecutive attacks of one element; taking
  the other element resets the charge. Discharge to stun, then melee.
- **Phases / escalation:** two explicit major sections: paired cross-reflection,
  then one fused target with accumulation and reset pressure.
- **Transferable lesson:** a second section can deepen an already learned verb
  by adding resource accumulation and error reset instead of replacing it.

#### Ganondorf

- **Locomotion / arena:** he floats across a high platform while ground pounds
  damage and remove parts of the floor, degrading safe movement around Link.
- **Attack grammar:** single energy orbs create a return volley; a charged
  multi-orb burst floods lanes; the ground strike creates a radial shock and
  breaks arena tiles.
- **Weak-point exposure:** winning the volley disrupts his electrical guard;
  a Light Arrow then brings him down.
- **Stun / damage loop:** return an orb with sword, hammer, or bottle until it
  hits; shoot the stunned target with a Light Arrow; cross the damaged arena and
  strike with the sword before he rises.
- **Phases / escalation:** one major combat grammar with pressure escalation
  through arena loss and higher-volume attacks rather than a formal second
  section.
- **Transferable lesson:** a late boss can compose a familiar reflect test,
  secondary item confirmation, traversal under time, and melee spend without
  inventing a new verb.

#### Ganon

- **Locomotion / arena:** a ring of fire encloses a close arena. Ganon turns and
  advances with huge reach while Link must get behind him; the Master Sword is
  initially knocked outside the ring.
- **Attack grammar:** paired sword sweeps and slams dominate the front. Light
  Arrows or repeated Longshot impacts can stun the head, while rolling between
  the legs is a positional route to the rear.
- **Weak-point exposure:** the tail, reached by stunning or outmanoeuvring him.
- **Stun / damage loop:** reach the tail and damage it with available weapons;
  after the mid-fight collapse, recover the Master Sword and repeat. Other
  weapons can advance the fight, but the Master Sword must deliver the finish.
- **Phases / escalation:** two sections divided by Ganon falling and the fire
  ring dropping long enough to reclaim the Master Sword. The second section
  restores the same positional loop with the required finishing tool available.
- **Transferable lesson:** temporary disarm can force kit breadth, but the
  recovery beat must be staged and the final-tool requirement made unmistakable.

### 3.2 Lower-level miniboss catalogue

Minibosses generally get fewer beats than main bosses, but their best designs
still change targeting, spacing, or turn-taking rather than merely adding HP.

| Miniboss | Locomotion / arena | Attack and opening loop | Escalation / transferable lesson |
|---|---|---|---|
| Lizalfos / Dinolfos | Leap between platforms, retreat after short exchanges, and alternate aggression when fought in pairs rather than attacking together. | Sword lunges and evasive jumps pressure lock-on. Block a committed strike to make one lose footing, or use a Deku Nut, then counter before it disengages. Dinolfos is the later, tougher/faster expression. | Turn-taking makes a pair readable; a brief commitment error is a better opening than passive low defence. |
| Big Octo | Runs around a circular room and rotating spiked platform, occasionally reversing direction. | Contact and the moving hazard punish pursuit. Boomerang-stun it, use another stun to control which way it faces, then hit the rear knob before it turns back. | The arena communicates direction and makes “get behind it” an active control problem. |
| Stalfos | Advances, retreats, circles, and guards in compact arenas; paired encounters transfer initiative instead of swarming. | Shield defence answers frontal sword pressure; committed slashes and jump attacks create counter windows. Paired Stalfos can rebuild if the survivor is left too long. | Defensive enemies need visible commitment and bounded pair pressure, not inflated health or simultaneous attacks. |
| Poe Sisters | Three hide in paintings or behind a reconstructed portrait; Meg occupies the centre and creates four images. | Shoot hosted paintings to force manifestation; solve Amy’s block portrait; identify Meg’s real body among copies, then shoot or strike during visibility. | A miniboss set can vary the information gate while keeping one ghost combat vocabulary. |
| Flare Dancer | Spins around the room inside a mobile flame body; the exposed core runs away and reverses as it loses health. | Flame contact and radial fire deny approach. Bomb, Hookshot, or hammer interaction strips the shell; chase and strike the core before it re-forms and explodes outward. | Provide multiple valid tools for one exposure, then make locomotion—not a longer stun timer—the execution test. |
| White Wolfos | Circles at the edge of a small icy arena, guards its front, then leaps or swipes through an approach. | Frontal attacks meet guard. Evade or block the committed attack and punish the back/flank during recovery. | Orbiting matters when it creates a facing question and a short positional opening. |
| Dark Link | Mirrors Link across a featureless shallow-water arena and becomes more opaque and aggressive as the duel proceeds. | It copies or blocks ordinary sword approaches and counters repeated habits. Non-mirrored items or attacks timed after its commitment break the symmetry. | A mirror duel tests player habits; it needs enough asymmetry to avoid becoming an obscure knowledge check. |
| Dead Hand | Numerous floor hands hold fixed positions while the main body stays buried until a grab is triggered, then rises and approaches. | Hands grab and restrain; the body lowers its head to bite. Escape, strike the lowered head during its approach/recovery, then repeat after it burrows. | The dangerous grab can also be the authored trigger for an opening, but failure attribution must stay clear. |
| Gerudo fighter | Strafes, guards, backflips, and closes quickly in a small prison chamber. | Fast sword strings and a spinning jump punish passive guard; block or sidestep the commitment and counter its recovery. A clean special hit can end the exchange by capturing Link. | High stakes come from a clearly telegraphed outcome and reset, not unreadable speed. |
| Iron Knuckle | Slow armoured pursuit controls a chamber with a huge axe; swings can destroy nearby props. At roughly half health the outer armour falls away and movement accelerates. | Wide horizontal and overhead axe blows deal extreme damage but leave the guard open. Bait a swing, leave its arc, and punish recovery; bombs offer a ranged option early. | This is an explicit two-state miniboss: shedding armour trades defence for speed. The silhouette and locomotion change make escalation readable without a new moveset. |

The old five labels—receptacle, timed weak point, reflect, positional, disarm—
remain useful tags. They are not exhaustive fight descriptions and should not be
used to infer phase count. The transferable pattern is broader: locomotion and
arena establish pressure; an attack exposes a specific answer; the answer earns
a bounded damage window; later stages change the conditions under which that
same learned contract is executed.

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
