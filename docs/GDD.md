# The Lower Worlds: Awakening — Game Design Document

The north star. When a decision is contested, it is settled here; the other docs
describe *how* this gets built, not *what* it is.

**Status: MVP loop playable end to end.** Boot the game and you can sell, buy,
descend, fight, loot, and buy your way back out. Everything in §8 that is marked
"not built" is honestly not built.

---

## 1. The pitch

A third-person action game with **Ocarina of Time's feel** and **Moonlighter's
structure**. You are not clearing a dungeon. You are making runs into one and
deciding, every time, when to leave.

The moment-to-moment is OOT: a boom camera, weighty camera-relative locomotion, a
committed roll, a shield, a telegraphed enemy you can read. The shape around it
is Moonlighter: a town, a vendor, a smith, and a hole in the ground that gets
worse the further in you go.

---

## 2. The one question

> **Is what I am carrying worth more than the walk back?**

Every system exists to sharpen that question or to price it. When evaluating a
proposed feature, the test is not "is this fun in isolation" but **"does this
make that question harder to answer?"**

A feature that makes the answer obvious — infinite storage, a free teleport, a
heal you can carry — is a feature that deletes the game. Say no to it.

---

## 3. The loop

```
   TOWN  ──────────────▶  DUNGEON  ──────────────▶  TOWN
   sell the haul          clear rooms                richer, or
   buy permanence         fill the bag               poorer and wiser
        ▲                 decide when to leave           │
        └───────────────────────────────────────────────┘
```

Two ways out, and the difference between them is the whole game:

- **Extract** — stand on the pad, hold the button, pay a share of what you are
  carrying. Keep the bag. Heal to full.
- **Die** — lose the entire bag. Keep your gold and everything it bought.

Death is not a rewind. It is a *bad trade*, and you can see it coming.

---

## 4. Pillars

**1. The feel is not negotiable.** OOT is the bar for camera, locomotion, and
combat, and `refs/` is authoritative over intuition (`docs/CONTRACT.md` §2.5).
There is no walk/run toggle — speed is a curve. The roll is faster than the run
and it commits. A reversal past ~135° is its own move, not steering.

**2. Greed is the difficulty slider.** The game does not ask you to pick easy or
hard. It asks how deep you want to go, and pricing your own exit is how you
answer. A cautious player is never blocked; a greedy one is never safe.

**3. Loss is legible.** You always knew the risk. Enemies telegraph before they
commit. A full bag refuses visibly, with the mote left pulsing on the floor
rather than vanishing. The extract fee is on screen before you pay it.

**4. Permanence is bought, never found.** No dungeon drop makes you stronger.
Ingredients are sold; gold buys upgrades; upgrades survive death. That
indirection is what makes a great run a *decision* rather than an automatic one.

**5. Darkness is a material.** Torches make pools with black between them. The
one exception is the actors — the hero and anything trying to kill him carry
enough light to be read. A silhouette you cannot read is not atmosphere, it is a
bug (and it was one).

---

## 5. Difficulty comes from depth, not from you

**Bands, never level-scaling.** Rooms carry a distance from the entrance, and
that distance alone chooses what spawns: crawlers and goblins at the mouth,
skeletons and kobolds further, orcs deeper, a wraith at the bottom.

Monsters get harder because *you walked further*, not because you got stronger.
Scaling the world to the player flattens the map into wallpaper, makes a tenth
run's entrance exactly as dangerous as a first run's, and quietly deletes the
reward for every upgrade the player bought. Oblivion's own designer called it a
mistake. We are not repeating it.

The corollary: **the entrance must stay easy forever.** That is what makes a
short cautious run a real option instead of a wasted one.

---

## 6. The economy in one paragraph

One currency: gold. Ten ingredients across three rarity bands, with **inverse
stack sizes** so rare items cost more slots per unit of value — a bag of King's
Signets is a genuine choice against a bag of Grave Wax, not a strictly better
one. Twelve bag slots to start, four more purchasable. The extract fee is
`max(15, 25% of bag value)`, so a poor run is cheap to abandon and a rich one
costs real money to bank. Five permanent upgrade lines, all limited, all priced
so a good run buys one cheap thing or part of an expensive one.

Full numbers, and the reasoning behind each: **`docs/METAGAME.md`**.

---

## 7. What the player does with their hands

Camera-relative movement on the left stick. Sword on one button, shield on
another, a committed roll, and lock-on. Interact is a single button that
`Prompt` arbitrates so only one thing ever claims it. Extraction is a **hold** —
a decision you can make by fumbling a button is not a decision.

Full input map and the pad bindings: `docs/CONTRACT.md` §4.

---

## 8. Built vs. not built

**Built and playable:** town with vendor and smith, trade screens, the full
ten-ingredient economy, five permanent upgrade lines, a seeded room-graph
dungeon with corridors and chests, six enemy kinds across depth bands, physical
loot drops with a refusing bag, the extraction pad, death, the fade transition,
HUD, pause menu, saves.

**Not built, and named honestly:**

- **Crafting.** Ingredients are only sold today. The name "ingredient" is a
  promise the game has not yet kept — the smith should eventually want *items*,
  not only gold, so that a rare drop has a use besides its price.
- **More than one dungeon.** One biome, one enemy roster, one kit.
- **A boss**, and any reason to reach the bottom other than the loot there.
- **Depth beyond one level.** `Run.descend()` exists; nothing calls it.
- **Audio.** `Bus.request_sfx` is emitted and nothing listens.

**Deliberately rejected:**

- Level-scaled enemies (§5).
- A bag upgrade path that removes bag pressure entirely — the cap is the game.
- Consumable healing carried into a run. Extraction is the only heal, and that
  is what stops a player farming one safe room forever.
- A second scene-change path. `Flow` owns transitions; a fade that something can
  bypass is not a guarantee.

---

## 9. How we know it works

Not by a test suite. By running it and looking:

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

`mvp_loop.gd` walks sell → buy → descend → fight → loot → chest → hold the pad →
home, prints what it observed at each seam, and says `MVP FAIL` when a beat did
not happen. `monster_lookdev.gd` does the same job for the roster.

See `CLAUDE.md` §2. The frames are the proof.
