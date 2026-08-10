# BESTIARY — enemies, minibosses and bosses

**This file owns encounter design**: what a body asks the player, which item
answers it, and the rules the four bosses and four minibosses are built against.
It does **not** own which four minibosses floors 1–4 get — that is a reward-branch
decision and `docs/PUZZLES.md` §7 keeps it. It does not own stats; those are
`Enemy.DEFS` and `BossDb`, and a doc that restated them would disagree with them
by Friday.

Everything here is read off `docs/OOT_CATALOGUE.md` §3, which is the 1998 Player's
Guide gone through dungeon by dungeon and written down as mechanics.

**Status: design.** Nothing in §3 is built. §5's boss shapes are a re-reading of
beats that already exist in `BossDb` — no new beats, no second phase, no new
models.

---

## 0. The one rule, and the diagnosis it comes from

> **Every enemy is a question. Every item is an answer.**
> **An enemy that only the sword answers has not been designed.**

Here is the state of the roster, honestly. `Enemy.DEFS` has seven rows —
`skeleton`, `goblin`, `kobold`, `orc`, `wraith`, `troll`, `knight_iron` — and
they differ in **health, damage, speed, height, detect, reach, windup, recover
and cooldown.** Nine numbers. Not one behaviour.

So every enemy in the game asks the same question — *can you swing back?* — and
the only answer is the sword. The bow, the Burst-Verse and the hookshot are
**puzzle-only items**: `docs/PUZZLES.md` gives all three a room to open and none
of them a body to beat. GDD §5.2 promises the hookshot "freezes the thing for a
second"; that is implemented, and nothing in the roster ever needs it.

That is the gap this document closes, and the good news in
`docs/OOT_CATALOGUE.md` §3 is how cheaply it closes: Ocarina's memorable enemies
are memorable because **each one names an item**, and almost none of them is a
new mesh.

---

## 1. Bipeds — the constraint that costs nothing

**Everything in `assets/monsters/` is already a humanoid**: `skeleton`, `goblin`,
`kobold`, `orc`, `wraith`, `troll`, `knight_iron`, `golem`, `ogre`. Nine bodies,
nine bipeds, one shared 81-clip `monster_library.res` rigging all of them.
`docs/SCOPE.md` says **new monster models: 0** and this document does not ask for
one.

So "stick to bipeds" is not a sacrifice here. It is a description. But it is also
**better design than the alternative**, and it is worth saying why, because the
temptation at floor 3 will be to reach for something with too many legs.

- **A biped has a front, so a guard is legible.** Positional weakness — get
  behind it — only reads as a rule if the player can see which way "behind" is.
  A silhouette with a face teaches its own weak side.
- **A biped has hands, so its threat is in its silhouette.** It can carry a
  shield, a torch, a bow, a plate — *or your bag*. Every behaviour in §3 is
  something you can see a body holding from across a room, which is
  `docs/STYLEGUIDE.md`'s readable-channel rule applied to encounters.
- **A biped shares the hero's animation grammar.** Wind-up, commit, recover reads
  the same on a body shaped like yours, so a telegraph learned on a skeleton
  transfers to a knight. GDD §7's 60% floor on telegraph compression only means
  something if telegraphs are comparable across the roster.
- **Ocarina agrees.** Its best-designed enemies are overwhelmingly bipeds —
  Stalfos, Lizalfos, Iron Knuckle, Gerudo guard, ReDead, Wolfos, Dark Link, Deku
  Scrub. The quadrupeds and the floaters are the trash mobs nobody remembers, and
  the genuinely non-humanoid things are bosses, which get an arena and four
  minutes to explain themselves.

**The one thing bipeds are bad at is being unsettling**, and Ocarina's answer is
not anatomy — it is behaviour. A ReDead is a humanoid that stands still and looks
at you. That is the scariest thing in the game.

---

## 2. What each item should answer

The left column is built. **The right column is almost entirely empty**, and that
is the whole finding.

| Item | Puzzle verb — built | Combat verb it should own |
|---|---|---|
| **Sword** | urn, lantern | everything, and that is the problem |
| **Shield** | sun socket beam | **send a thrown thing back.** Nothing in the roster throws anything |
| **Bow** (T1) | eye switch | **the body that has not noticed you**, and the only stagger that lands on a guard |
| **Burst** (T2) | cracked pillar | **the guard-breaker**, and the only blow a riser does not get up from |
| **Hookshot** (T3) | hook ring | **close a gap you did not choose** — pull yourself to a perched body, or freeze one mid-beat |
| **Rope** | — | none, and it should stay none. It is the extraction verb and GDD §2 needs it uncomplicated |

**The shield row is the cheapest and the most valuable.** It is owned from minute
one, it already has a raycast that bounces a beam (`SunSocket`), and Ocarina uses
it on its *first enemy* and on *three of its bosses*. One enemy that throws
something blockable turns a wall into a verb for the entire game.

---

## 3. Eight behaviours, and not one new model

Each is a key on an existing `Enemy.DEFS` row plus a small behaviour on `Enemy`.
The **Wears** column is which body carries it, chosen so the silhouette already
suggests the behaviour.

**Every behaviour has two answers** — the fast one and the expensive one — for
the reason `docs/PUZZLES.md` §10.6 gives: a single-answer enemy at depth is a
knowledge check, and GDD pillar 3 rules those out.

| | Behaviour | What the body does | Fast answer | Expensive answer | Wears | From |
|---|---|---|---|---|---|---|
| **1** | **Thrower** | Lobs something on a slow arc. The throw is **blockable and it returns** | **Shield**, on the beat | close the distance and eat one | `goblin` | Deku Scrub |
| **2** | **Guard** | Plated front; melee rings off it and does nothing | **Burst** — or an **arrow** in the beat it turns | circle to the back, slowly | `knight_iron` | Stalfos, Iron Knuckle |
| **3** | **Perched** | Stands across a gap or on a ledge and throws down | **Bow** | **Hookshot** to close, then melee | `kobold` | Gerudo archer |
| **4** | **Thief** | Grabs, and **takes one bag slot**, then runs for the nearest door | kill it — it drops what it took | let it go and eat the loss | `goblin` | Like Like, Dead Hand |
| **5** | **Caller** | Does not fight. Winds up a shout that wakes the room | **Bow**, before the shout lands | run it down and accept the room | `skeleton` | Gerudo alert |
| **6** | **Gaze** | Stands still. Looking at it **roots you for a beat**; then it closes | kill it at range | break line of sight and go around | `wraith` | ReDead |
| **7** | **Riser** | Gets back up once, after a few seconds, unless the killing blow was **Burst** | **Burst** the finish | kill it twice | `skeleton` | Stalfos |
| **8** | **Ledworthy** | Heavy, slow, trivially baited — and it counts as `plate_weight` | lead it onto the plate | push a block instead | `troll` | Armos |

### Build four, not eight

**Committed: 1 Thrower, 2 Guard, 3 Perched, 4 Thief.** One per item, which is the
point — the four together are the sentence *"the bow, the shield, the Burst and
the hookshot each beat something."* The other four are flavour and are not
committed, exactly the way `docs/PUZZLES.md` §2's phase 2 is not committed.

### Number 4 is the one this game should build first

The **Thief** is the only entry on the list that is not borrowed thinking. GDD §2
asks *is what I am carrying worth more than the walk back*, and a monster that
takes a bag slot and runs for the door asks that question **in the middle of a
fight**, with a real answer on either side. Chase it and you are spending Heat and
stamina on loot you already had; let it go and the run just got cheaper to
extract.

Everything it needs exists: the bag is `Run`'s, `LootMote` already knows how to
drop a stack on the floor, and "run for the nearest exit" is the leash logic
inverted. **It is the cheapest new *decision* available anywhere in the project.**

### The rule that keeps this at eight

> **A behaviour must name an item, and the item must be one of the six.**

Not "hits harder", not "moves in a pattern", not "spawns adds" — those are stats
and beats, and `Enemy.DEFS` and `BossDb` already own them. A ninth behaviour that
does not put a specific item in the player's hand is a stat with a name on it.

---

## 4. Minibosses — the wall, and the second way over it

`docs/PUZZLES.md` §7 owns the four and their beats. Three rules from the
catalogue that the four should be built against, and one audit finding.

**4.1 — The wall must be visible before it is relevant.** The Bellows-Hand's
bellows have to be readable from the doorway, not discovered on the third circuit.
Ocarina always shows you the weak point first and the guard second: Skulltula
turns its armoured face toward you and its soft back is *right there* the whole
time.

**4.2 — There is always a second, worse way over the wall.** The Flare Dancer
takes a bomb, a hookshot *or* a hammer, and the Spirit Temple's *Trial by fire*
can be solved by leading the enemy into a fire that was already burning. The
floor's own verb stays the *fast* answer — §7's design is intact — but a player
who has not worked it out is paying more, not standing still.

**4.3 — Two beats, two tools.** §7's shape is already this and it should stay:
one beat the shield answers and one it does not. A fight that both beats answer
the same way is one beat played twice.

**The audit.** Against `docs/OOT_CATALOGUE.md` §3's five boss shapes, the four
minibosses cover two:

| Miniboss | Floor verb | Shape it takes |
|---|---|---|
| Sluice-Keeper | T0 | **Positional** — block, then roll |
| Bellows-Hand | T1 bow | **Exposed weak point** — the bellows, when it turns |
| Second Voice | T2 burst | **Positional** — break the pillar it anchors to |
| Gate-Hound | T3 hookshot | **Positional** — it retreats, you close |

Three of four are the same shape wearing different verbs. That is fine for a
miniboss — it is the *floor's* verb that varies, and that is what the branch is
for — but it means **receptacle and reflect have to come from the bosses**, which
is §5.

---

## 5. Bosses — one fight shape each, and no new beats

`BossDb` has five *attack* shapes (`arc`, `slam`, `charge`, `zone`, `summon`) and
twelve authored beats. Ocarina's five are not attack shapes, they are **fight
shapes** — the sentence the whole fight is — and our four have never had one
named.

Naming one per boss costs nothing: **it is a re-reading of a beat that already
exists, not a fourth beat and not a second phase.** `docs/SCOPE.md` §1's one-phase
three-beat cap is untouched, and so is *new monster models: 0*.

| Boss | Floor | The player is carrying | Fight shape | The beat that carries it |
|---|---|---|---|---|
| **The Cistern Warden** | 1 | sword, shield, rope | **Reflect** — it hurls sluice debris; blocked on the beat, it goes back and staggers it | `cistern_drop` |
| **The Slag Ogre** | 2 | **the Bow** | **Receptacle** — the bellows draw before it charges; an arrow in the open intake stops the charge before it starts | `bellows_charge` |
| **The Bellwake** | 3 | **the Burst** | **Exposed weak point, on a timer** — it anchors to a resonating pillar to sing; Burst the pillar and the core is open until it finds another | `hushing_choir` |
| **The Riven Knight** | 4 | **the Hookshot** | **Disarm and reposition** — it takes the gate ring and holds the far side; hookshot is both the way across and the way back | `gate_lunge` |

**Read that table the same way `docs/PUZZLES.md` §1 asks you to read its
diagonal.** Every boss's fight shape is answered by the item the *previous* boss
dropped. The Warden — floor 1, nothing earned yet — is answered by the shield,
which the player has always had and has never been asked to use offensively. That
is where the shield stops being a wall.

**Four of Ocarina's five shapes, one per floor.** The fifth is *disarm* in its
full form — Ganon knocking the Master Sword out of the ring — and it belongs to
the Riven Knight at the Chord Gate or to nothing at all. A boss that takes the
sword away is a boss that has to be answerable without it, and floor 4 is the only
floor where the player owns enough to be answerable without it.

### The two rules the catalogue is emphatic about

**No second health bar, ever.** Not one Ocarina boss has one. The escalation is
always **the arena changing** — Ganon rings the floor with fire, Volvagia takes to
the air, Morpha withdraws the nucleus. `docs/SCOPE.md` §1 caps us at one phase for
budget reasons and it turns out to be the *design* answer too: an arena that
changes at a health threshold costs one signal and no new beats, and it reads as a
turn in the fight rather than as a longer fight.

**The boss is a receptacle for something the player already owns.** King Dodongo
is a bomb you throw into a mouth. That is the entire fight, it is the second
dungeon in the game, and it is still the most-remembered boss in it — because the
player is not learning a boss, they are **discovering that the toy from the
dungeon works on the thing at the end of it.** That is what the middle column of
the table above is for.

---

## 6. What this costs the manifest

`docs/SCOPE.md` §1 speaks in counts, so:

| | Count | Moved? |
|---|---|---|
| **New monster models** | **0** | **No.** §1's biped rule is why, and it is the row this document exists to protect |
| Enemy kinds in rotation | **9** | **No.** A behaviour is a key on a row, not a tenth row |
| Boss beats | **12** | **No.** §5 re-reads four beats that already exist |
| Boss phases | **1** | **No** |
| Minibosses | **4** | **No** |
| New UI screens | **0** | **No** |
| **Enemy behaviours** | **8**, of which **4 committed** | **New row.** This is the one to argue about |

**The bill, stated rather than absorbed.** Four behaviours is four small
additions to `Enemy` — a blockable projectile, a front-facing damage gate, a
ledge-preferring spawn rule, and a grab that moves one bag row and flees. None of
them is a new system, none needs a save field, and all four are provable by one
director that walks a hero past four bodies with four items. That is
`docs/SCOPE.md` §4.3's three questions answered: it makes GDD §2's question
*harder* (the Thief asks it mid-fight), it is a key on an existing table, and one
director proves it.

**What it must not become.** A behaviour that needs its own model, its own screen,
or its own arena is a miniboss, and there are four of those and no fifth.
