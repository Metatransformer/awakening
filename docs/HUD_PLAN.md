# The HUD, designed rather than accumulated — the plan

Board card [#19](https://github.com/Metatransformer/awakening/issues/19). This is
a **plan**, not code. Nothing here has been implemented. There are twenty numbered
decisions; each names the rule it serves and the alternative it rejects, so a
reviewer can argue with one without re-opening the rest.

It exists because the screen currently draws **nineteen things** out of one
`_draw_hud`, and `docs/STYLEGUIDE.md` §5 describes a different HUD than the one
that ships — in both directions. Some of that is the code having drifted from a
rule. Most of it is the document having been overtaken by systems that landed
after it was written. **The central question, per element, is which of those two
it is.** "Reconcile by listing both" is not an answer; it is how §5.2 and §5.2b
ended up specifying a 32 px cell and a 34 px cell on the same page.

The test everything is measured against is the one §5.6 already states:

> *Anything that does not feed push-on-or-leave has no claim on permanent pixels.*

together with GDD §5.2 / §6.5 / §9, which say what the player's hands are doing
while they read it.

---

## 0. One thing in here is a bug, not a design question

**The draught row is drawn on top of the magic bar in the garrison and on top of
the heat bar in the dungeon.** This is arithmetic, not taste, and it is checkable
without a screenshot.

`Hud._pole_top(s, row)` walks the vitals stack — health 15, +4, stamina 8, +4,
magic 8, +4, heat 6 — so at 720p the four rows begin at y = 635 / 654 / 666 / 678.
`Hud._draw_draughts` does **not** call it. It writes its own sum:

```gdscript
var y := Pal.HEALTH_ORIGIN.y * s.y \
    + Pal.px(Pal.HEALTH_H + Pal.STAMINA_GAP + Pal.STAMINA_H + Pal.HEAT_GAP, s.y)
if Run != null and Run.in_dungeon:
    y += Pal.px(Pal.HEAT_H + Pal.HEAT_GAP, s.y)
```

`MAGIC_GAP + MAGIC_H` is missing. Garrison: y = 666, which is exactly the magic
bar's top — and `K.MAX_MAGIC` is 48, so the blue bar always draws. Dungeon:
y = 676 against heat's 678, a four-pixel overlap of two 6 px rows.

The function's own docstring warns about this, in these words: *"It was written
once as a short sum that left `HEALTH_H` out, and the row landed exactly ON the
stamina bar… Every check in `alchemy_loop.gd` passed while it did that, because
none of them can see a rectangle."* It happened again, one row lower, when the
magic bar was inserted into `_pole_top` and this second expression was not
updated. `alchemy_loop.gd` still passes.

That is the whole card in one defect: **two expressions for one stack, and no
proof that can see a rectangle.** Decisions 6 and 20 are the two halves of the
fix. Everything else here is the design work the card actually asked for.

---

## 1. The element inventory, with verdicts

Twenty-nine elements. `_draw_hud` calls nineteen functions; several draw more than
one thing, and three elements in the styleguide are drawn by nobody at all.

**Verdict key:** KEEP = ships as-is, the doc may need to catch up. CHANGE = code
moves. DELETE = comes off the screen, or off the page if it was never on the
screen. ADD = new pixels, argued.

| # | Element | Where | Verdict | Which document changes, and why |
|---|---|---|---|---|
| 1 | Health bar + heart/quarter ticks | vitals r0 | **KEEP** | Doc. §5.1 still specifies discrete cells; the code has overridden it since 2026-08-08 with the argument written into `hud.gd`. Fold the override in, delete the cell prose. |
| 2 | Damage ghost (RUST, hold 0.40, 4-step drain 0.25) | over r0 | **KEEP** | Neither. Doc and code agree. |
| 3 | Low-health pulse (≤3 q, VITAL↔BONE 2 Hz, track → VOID) | r0 | **KEEP** | Neither. This is §7.10's *sanctioned* low-health cue — see decision 13. |
| 4 | Stamina bar + roll ticks | r1 | **KEEP** | Neither. |
| 5 | Magic bar + spin ticks | r2 | **KEEP** | **Doc.** §5 does not mention it at all. It is the charged spin's cost (`K.MAGIC_SPIN`) and the only bar that never refills on its own. Add §5.1c. |
| 6 | Heat bar | r3, dungeon | **KEEP** | **Doc.** §5.6's "seven things" predates Heat entirely. |
| 7 | Heat multiplier label (`x1.6`) | right of r3 | **KEEP** | Doc, same reason. |
| 8 | Draught pips | r4 | **CHANGE** | Both. Code: the collision (§0) and the unbounded downward stack. Doc: undocumented. Decisions 6, 7. |
| 9 | Draught short-name text (`EMB`) | right of r4 | **DELETE** | Code. Decision 7. |
| 10 | Hand cells ×2, 64 px, MIDNIGHT@80% + 1 px ASH | cluster | **KEEP** | **Doc, twice.** §5.2 says 32×32/6, §5.2b says 34×34/6, `Pal.CELL` says 64/12 and argues why. Both doc numbers lose. |
| 11 | Shield block / parry flash (BONE raised, RUST blocked, GOLD parried) | left cell | **KEEP** | Doc. §5.2 knows about the block; the parry landed later. |
| 12 | Ammo numeral in the hand cell | left cell | **CHANGE** | Code. Route through `ArmamentDb.hand_count()`; promote 7 px → 10 px. Decisions 12, 19. |
| 13 | Item cell (bottle glyph, 2 px BONE when filled) | cluster | **KEEP** | Doc. §5.2b's "2 px BONE border on the cell holding the item currently in hand" was written about hands; the code puts it on the item cell when a potion is present, which is the honest reading for a one-cell cluster. |
| 14 | Bottle count `n/m` | item cell | **KEEP** | Code, size only. Decision 19. |
| 15 | Carets ← → ↓ | above cells | **KEEP** | **Doc.** §5.2b's "10×5 px" is a full extent; `CARET = 8.0` is a **half** extent, i.e. 16×16. The code's is right and the doc's number was never rendered. |
| 16 | Key caps on MIDNIGHT@80% plates | under cells | **KEEP** | Neither. |
| 17 | Loadout line `↑ PRIMARY` | under caps | **KEEP** | Neither. |
| 18 | Minimap | top-right | **KEEP** | Neither. §5.5b is current and correct. |
| 19 | Bag rim, coloured by best rarity | bottom-right | **CHANGE** | Code. Its right edge (0.978) is **outside** the safe margin (0.975). Decision 14. |
| 20 | Bag rim T2 gold halo | " | **KEEP** | Neither. |
| 21 | Value slips (histogram, ≤8, `+N`) | " | **KEEP** | Doc. §5.3 says 3 px slips; the code says 4. 4 px wins — a 3 px slip under a 2 px gutter is a dither, not a bar. |
| 22 | **The bag total (32 px number)** | — | **stays DELETED** | **Doc.** §5.3 still specifies it in four sub-clauses; §5.6 records that it was deleted on purpose, and why. §5.3 is contradicting its own page. Decision 17. |
| 23 | Extraction hold ring (54 px CYAN arc) | bottom-right | **CHANGE** | Both. It is centred on `BAG_NUM_BASELINE` — the anchor of the number in row 22. Decision 15. |
| 24 | Extraction sweep (1 px CYAN, y 0.5, 200 ms) | full width | **KEEP** | Neither. |
| 25 | Item toast (16 px, rarity colour) | 0.767 | **KEEP** | Neither. |
| 26 | Autosave notice | shares 0.767 | **KEEP** | Doc — undocumented in §5. |
| 27 | Interact prompt + hold gauge | centre 0.735 | **KEEP** | Doc — undocumented in §5. |
| 28 | Crosshair (four ticks around a hole) | screen centre | **KEEP** | Doc — undocumented in §5. |
| 29 | Lock-on brackets | on target | **CHANGE** | Code. Hard-coded `Pal.RUST` for every kind, which makes CYAN-is-the-way-out (§2) a lie the moment you lock a hookshot target. Decision 16. |
| 30 | Lock-on converge / break animation | — | **DELETE (doc)** | Doc. Never built. Decision 16. |
| 31 | Off-screen lock chevron | — | **DELETE (doc)** | Doc. Never built. Decision 16. |
| 32 | Enemy health bars (20×2, ×2.2 locked, LOS + 22 m) | on monsters | **KEEP** | Neither — §5.5 was amended alongside the code, correctly. |
| 33 | Garrison control legend (2 lines, ~150 chars) | 0.962 | **CHANGE** | Both. It fails §5.6's test outright, it crosses the bottom safe margin, and it is the only thing squeezing the vitals pole. Decision 8. |
| 34 | Floor card (name + level, fading plate) | top-left | **CHANGE** | Doc undocumented; and the code's level line never dims. Decision 18. |
| 35 | Room-name card (Jacquard 24, y 0.139) | — | **DELETE (doc)** | Doc. `Pal.ROOM_NAME_BASELINE` has zero callers, Jacquard was never wired (§3.1 admits it), and the floor card does this job better. |
| 36 | Damage-direction arc | — | **ADD** | Code. It replaces `Feel`'s undirected vignette. Decision 13. |
| 37 | `Feel.damage_vignette` (VITAL edge, every hit) | full screen | **DELETE** | Code. Decision 13. |
| 38 | Dead constants: `Pal.bag_color`, `SLIPS_TOP`, `ROOM_NAME_BASELINE`, `PREMIUM_BASELINE`, `BAG_NUM_BASELINE` | — | **DELETE** | Code. Five, not two: `PREMIUM_BASELINE` (0.735) is an abandoned attempt to put the heat premium in the money column and has never been called, and `BAG_NUM_BASELINE` survives only as the anchor for the ring decision 15 removes. A constant with no call site is a claim about the screen that nobody can check. |

### What was considered for deletion and kept

Being willing to delete means saying what survived the question.

- **The magic bar.** Four bars is a lot of pole. It stays because it is the only
  readout of a resource that *does not come back* — everything else in the pole
  either regenerates or is scored. "How much of this trip's power is left" is a
  push-on-or-leave question in the most literal sense.
- **The heat multiplier label.** It is a number, on a screen that has deleted two
  numbers for being numbers. It survives because it is not a *running total*: it is
  a discrete state (x1 / x1.25 / x1.6 / x2.2) that changes a few times a fight,
  which is a fact rather than arithmetic. The two deleted numbers moved on every
  pickup, which is what made reading them a habit.
- **The minimap.** §5.6 gave it the seventh always-on slot and the argument holds:
  how far you are from the stair is the other half of "can I afford one more room".
- **The loadout line.** Text, permanent, four characters of information. Kept for
  exactly the reason it is text: it says something you cannot look at and see.

---

## 2. Information hierarchy — 200 ms versus between fights

The failure this section prevents is the one `gamestack:ui-ux-and-feedback` names:
every element not serving the current decision is a tax paid in attention. The HUD
has three tiers and it must **separate them by construction**, not by intention.

**Tier 1 — read in 200 ms, mid-fight, without moving your eyes.** Health fill and
its ghost; the stamina fill's *colour*; the shield cell's fill; the enemy bars and
the lock brackets. Nothing here is text and nothing here requires a comparison.

**Tier 2 — glanced between beats, ~1 s, eyes move.** What is in each hand; the
ammo/charge numeral; magic; heat and its multiplier; the draught pips; the bag rim
and slips.

**Tier 3 — read when stopped.** Floor card, minimap, key caps, loadout line,
prompts, toasts, the autosave notice, the legend.

The four separations, written as construction rules rather than as intentions:

1. **Position.** Tier 1 lives in the two bottom corners and *on the target*. Tier 3
   lives along the top edge and on plates. The middle third stays empty because the
   over-the-shoulder camera puts the fight there — the crosshair and the interact
   prompt are the only exceptions, and both are *about* the middle third.
2. **Weight.** *Tier 1 is never text.* This is the rule with real teeth, and the
   current HUD breaks it once: the ammo numeral is 7 px, the **smallest text on
   screen**, and "how many arrows do I have" is asked mid-fight. Decision 19
   promotes it. Anything that must be read in 200 ms is a colour, a length or a
   position; if it has to be a number, it is Tier 2 by definition.
3. **Colour.** VITAL / RUST / GOLD are alarm colours and appear only on Tier 1 and
   on events. Tier 3 is MOTH and ASH, with BONE reserved for the *announcement*
   frame of a Tier 3 element and never for its resting state. The floor card breaks
   this today — its level line is BONE and deliberately never dims (decision 18).
4. **Motion.** Only Tier 1 and events move. A Tier 3 element that animates is
   stealing a channel it does not need. The two sanctioned resting pulses are the
   low-health pulse and heat's Blazing breath — both Tier 1/2, both carrying
   "something is about to change".

---

## 3. The type scale

**Decision 1 — §3.1's rounding rule is deleted. The code is right.**
§3.1 says *"All HUD sizes are `roundi(base_px * viewport_height / 720.0)`"*, and
`CanvasText.scale_for` deliberately does not round. The rule was correct when
`CanvasText` was `PixelFont`, a 5×7 bitmap drawn one `draw_rect` per lit pixel: a
bitmap glyph off the pixel grid is a smeared glyph. It has been wrong since
2026-08-10, when the HUD moved onto Cinzel, and the class documents the cost —
*"`Pal.px` rounds to a whole pixel… costs a 10px label 30% of its height at
720p"*. **Rejected:** round anyway, for the treatment's sake. That buys pixel-grid
alignment on a face that has no pixel grid, and pays for it in the legibility of
the smallest labels. Replace the sentence with the antialiasing and
subpixel-positioning note, which is the part of §3.1 that still binds.

**Decision 2 — the ladder is 10 / 14 / 16. Three sizes. §3.1's list loses; §3.1's
rule survives.**
The list (8/12/16/20/24/32) was authored for Departure Mono, which §3.1 itself
admits was never bought and never wired — it is a table of sizes for a face that
does not exist in this build. The *rule* under it — *"a HUD with seven sizes reads
as accreted rather than designed"* — is the part worth keeping, and it is about a
count, not about a particular set of integers. The shipped sizes are 7, 10, 14 and
16; three of those are already a coherent ladder and the fourth is a hierarchy
error (decision 19). So:

| px @720 | Used for |
|---|---|
| **10** | ammo / charge numeral, bottle count `n/m`, slips `+N`, heat multiplier, floor name, legend |
| **14** | key caps, loadout line, interact prompt, autosave notice |
| **16** | floor level, item toast |

A fourth entry is an amendment to this document, argued in the same breath.

**Decision 3 — text size is spelled one way: `CanvasText.scale_for(ref_px, h)`.**
Today the same 14 px is written `Pal.px(Pal.KEYCAP_SCALE, s.y)` in one function
and `CanvasText.scale_for(14.0, s.y)` in another, and `Pal.px(1.0, s.y)` means
7 px in a third. Only one of those spellings says what size it is. Two consequences
make this worth doing rather than merely tidy: the ladder becomes **greppable**,
and `scale_for` becomes the single place an assertion can catch a size that is not
on it (decision 20). `Pal.KEYCAP_SCALE` is deleted.

---

## 4. The three clusters as one system

The screen has three instrument groups — the **vitals pole**, the **control
cluster** and the **money pole** — and they must read as one author's work. They
already nearly do; the shared rules exist in the code but are written out longhand
at each site, which is how a third plate recipe got in. Name them:

**Decision 4 — five construction rules, stated once, obeyed everywhere.**

1. **The track.** Any meter is `draw_rect(rect.grow(px(1)), VOID)`, then
   `draw_rect(rect, Color(ASH, 0.6))`, then the fill. A 1 px VOID hairline
   *outside* an ASH@60% track. This is exactly what makes the draught row read as
   part of the pole rather than as a loose pip that wandered in.
2. **The tick.** A meter is ticked **iff** the ticks and the fill measure the same
   quantity. Health (quarters), stamina (rolls) and magic (spins) are ticked; heat
   is not, and `_draw_heat`'s comment is the argument — the fill is time, the tier
   is not, and four ticked segments under a nearly-full bar read as "4 of 4 tiers"
   at Warm. The draught pips are not ticked.
3. **The cell.** MIDNIGHT@80% fill, 1 px ASH border; 2 px BONE border when the cell
   is live. A cell's *fill* changes only for a Tier-1 state (shield raised, blocked,
   parried) — never for a Tier-2 one.
4. **The plate — two recipes, not three.** MIDNIGHT@80%, 3 px pad, for anything
   **attached to a cell** (key caps, the loadout line). VOID@72%, 6 px pad, for
   anything **free over the world** (interact prompt, floor card). The floor card
   currently mixes its own VOID@62%→34% and the prompt uses a 7 px pad; both come
   onto the shared recipe, with the floor card's fade running 72% → 34%.
5. **One left edge, one right edge.** `0.031` for the vitals pole, the control
   cluster and the floor card; `0.969` for the slips, the toast and the minimap.
   This already holds everywhere except the bag rim (decision 14).

**Decision 5 — the tint assignment is the system, and it stays.** The vitals
pole's fill *is* the answer to that bar's one question (VITAL; BONE-or-RUST;
COBALT-or-MOTH; the heat ramp). The money pole's colour is always a rarity. The
control cluster is untinted except for state flashes. GOLD stays currency-only, and
its two current non-currency uses are both defensible and both stay: heat's Hot
tier — heat *is* money — and the parry flash, which is a beat rather than a
readout.

---

## 5. The vitals pole, and where the draught row goes

**Decision 6 — `_pole_top(s, row)` becomes the only expression for the stack, and
gains row 4.** `_draw_draughts` deletes its hand-rolled sum and calls it. The
garrison case — heat is dungeon-only, so the draughts move up into its slot — is
expressed by passing `3` instead of `4`, not by a second arithmetic branch. §0 is
the second time one stack with two expressions has shipped a collision, and this is
what stops the third. **Rejected:** fix the sum. That is what was done last time.

**Decision 7 — the draughts are one row of up to three pips, and they lose their
short-name labels.**
SCOPE §1 caps draughts at 3. The current code stacks them downward at `h + 2` per
row from a pole that is already 4 px off the bottom safe margin, so three live
draughts put the last row at y 704 — past the 0.969 limit. Growing *downward* out
of the one corner with no room is the same defect as the legend running off both
edges; the fix is the one used everywhere else in this file (grow into empty
screen, or do not grow). One row of three pips at 0.44× pole width fits with room
to spare and has a hard bound. The `EMB` / `IRO` captions go with the second row:
three tinted pips need no labels, because `PotionDb.tint_of` is the same colour the
bottle glyph in the item cell has already taught. **Rejected:** keep the stack,
shrink the pips. That trades a collision for illegibility and still has no bound.

**Decision 8 — the garrison control legend becomes transient.**
It is the largest block of text on the HUD — two lines, ~150 characters — it is
permanently on screen in the garrison, and by §5.6's test it fails outright: it
feeds nothing about push-on-or-leave. It descends past the bottom safe margin (cap
top 0.962 + 10 px = 0.976 against a 0.969 limit). And it is the sole reason the
vitals pole has four pixels of slack: `Pal.HEALTH_ORIGIN`'s own comment records
that the pole and the legend "grow towards each other".

It becomes: **fades in on garrison entry, holds 10 s, fades out — and re-shows on
`Bus.input_device_changed`.** The device-change re-show is the half that matters:
picking up a pad is precisely the moment every cap in the player's head goes wrong,
the signal already exists, and `Hud` already repaints on it. The permanent
reference is Options → Controls, a screen that already ships (§8's bind rows), so
this costs no new UI screen (SCOPE §1).

**Rejected:** move the legend to the top of the screen. That fills the one region
the over-the-shoulder camera needs, and trades a permanent block at the bottom for
a permanent block in the fight.

**Decision 9 — the pole keeps its top anchor.** Bottom-anchoring it and growing
upward, the way the control cluster already does, would mean never again editing
two constants in sympathy — tempting after §0. Rejected: the health bar's position
is the one thing on this screen that must never move. It is read peripherally, by
shape and place, and a bar that slides up the frame when a fourth meter is added is
a bar the player has to find. The real defect was never the anchor scheme; it was
the second expression (decision 6) and the absence of a check that can see a
rectangle (decision 20).

---

## 6. The workings' charges

GDD §5.2 and §6.5 promise the charges as *"a count in the HUD column"*, spent on
cast, refilled only in the garrison — *"charges are arrows with a different noun"*.
`Hud.KIT_ICON` / `KIT_ACTION` / `KIT_LABEL` have rows only for sword, shield,
hookshot and bow, so an unlisted armament draws no icon, no key cap and a `"?"`.

The answer is already most of the way built, by another session, in the right
place. `ArmamentDb` carries `NAMES` / `ICONS` / `LETTERS` / `BLURBS` with a `burst`
row, plus the two functions this needs:

```gdscript
static func ammo_of(id: StringName) -> StringName    # what it SPENDS
static func hand_count(id: StringName) -> StringName # what it IS   → &"charges"
```

**Decision 10 — `hud.gd` stops keeping its own copy of that table.** `KIT_ICON` and
`KIT_LABEL` are byte-for-byte duplicates of `ArmamentDb.ICONS` and
`ArmamentDb.LETTERS`. `ArmamentDb`'s own header names this as the drift it was
created to end: *"they did, once, when the HUD carried its own KIT_ICON table and
the menu did not exist yet."* Both constants are deleted; `_draw_item_glyph` calls
`ArmamentDb.icon()` and `ArmamentDb.letter()`.

**Decision 11 — `KIT_ACTION` moves to `ArmamentDb.action_of(id)`.** It is the last
of the four tables and it is the same kind of fact — the player-facing face of an
armament id. The equipment screen wants it too, and a second copy is the one that
goes stale.

**Decision 12 — the in-cell numeral is `ArmamentDb.hand_count(id)`, not
`id == &"arrow"`.** One branch, one numeral path — no second numeral path, which is
what the card asked. Burst / Sustain / Ballast then need **zero** HUD changes: three
rows in `ArmamentDb` and one `hand_count` case each. That is what "a working is a
row in a table" was supposed to mean, and it is why this section adds nothing to
the frame.

**Open question, flagged rather than planned around.** `Game.charges` is a single
`int`. GDD §6.5's table gives each of the three workings its own bought charge
stock, so this has to become a per-working count before the second working ships.
`hand_count` already returns a `StringName` **key**, so the HUD is indifferent to
which shape wins — this is a `Game` decision, not a HUD one, and it wants making
before Sustain rather than after.

---

## 7. `Feel`'s vignette versus §7.10

§7.10 bans *"a red screen vignette at low health"*. `Feel.damage_vignette(0.55)`
draws a VITAL edge vignette on **every** damage event, not gated on low health — so
the letter of the rule is intact and the spirit is not. An undifferentiated red
edge is §7.10's other banned item, "white-flash-on-hit as the only impact cue", in
a different colour. It also duplicates a cue that is already better said: the health
bar already turns and pulses (element 3).

**Decision 13 — the rule stands; the vignette goes, and its budget buys the
damage-direction arc §5.6 has been promising all along.**

Replace `Feel`'s full-screen `ColorRect` with the arc §5.6 and §5.7 already
specify: **3 px RUST, 40°, radius `0.28h` about screen centre, 300 ms**, drawn at
the bearing from the hero to the blow. This is a straight trade — one full-screen
overlay out, one 3 px arc in — and it converts a cue that says *"you were hit"*,
which the player already knows, into one that says *"from behind you, on the
left"*, which an over-the-shoulder camera cannot otherwise tell them.

It needs a bearing. `Hit.from` is already the world position a blow came from, and
nothing carries it to the HUD: `Bus.player_health_changed` has neither a delta nor
a direction, and `Bus.hit_landed` is emitted by enemies about themselves. So this
costs **one signal** — `Bus.hero_struck(from: Vector3)`, emitted where the hero
applies a `Hit` — and the arc rides `Hud`, which already has the camera and already
runs an animation clock. `Feel` keeps hit-stop, slow-motion and shake, and loses its
`CanvasLayer`, its `ColorRect` and its shader.

**Rejected:** amend §7.10 to permit an every-hit vignette. Refused because that
rule is one of the few in §7 about *readability* rather than about costume — a
full-screen red wash at the exact moment you need to read a telegraph is the cue
fighting the fight.

---

## 8. The anchor table — replaces STYLEGUIDE §5.7 entire

Fractions of viewport, origin top-left; px at 1280×720. Every row says whether it
moved. **Rows that vanished from §5.7 are listed at the bottom, with why.**

Safe area: x ∈ [0.025, 0.975] (32 … 1248), y ∈ [0.031, 0.969] (22 … 698).

### The vitals pole — one left edge at x 0.031 (40); rows from `_pole_top` only

| Row | Element | top y | h | w | Moved? |
|---|---|---|---|---|---|
| 0 | Health bar | **0.882** (635) | 15 | 0.268w (343) | §5.7 said 0.899. **Doc stale by exactly one bar row** — the pole moved up 12 px when magic was inserted. Code wins. |
| 1 | Stamina bar | r0 bottom + 4 (654) | 8 | 0.62× (213) | No. |
| 2 | Magic bar | r1 bottom + 4 (666) | 8 | 0.52× (178) | **New row.** §5.7 never had one. |
| 3 | Heat bar (dungeon only) | r2 bottom + 4 (678) | 6 | 0.44× (151) | **New row.** |
| 3′ | Heat multiplier | bar right + 22 (213) | 10 px, centred on r3 | — | **New row.** |
| 4 | Draught pips (≤3, one row) | r3 bottom + 4 (688); **r3's slot (678) in garrison** | 6 | 0.44× (151): 3 pips, 4 px gaps | **Moved.** Was a downward stack from 666 (garrison) / 676 (dungeon) — on top of magic and heat respectively. §0, decisions 6–7. |
| — | pole bottom, dungeon | 694 | — | — | 4 px inside the safe margin. The tightest thing on the screen; decision 20 asserts it rather than trusting it. |

### The control cluster — same left edge, laid out upward from `CLUSTER_BOTTOM`

| Element | x | y | Size | Moved? |
|---|---|---|---|---|
| Cluster baseline (`CLUSTER_BOTTOM`) | — | **0.855** (616) | — | §5.7 said "baseline 0.872". **Doc stale by the same one bar row.** Code wins. |
| Caret band | above every cell | 490 → 511 | 21 tall (8·2 + 5) | Doc said "swap caret 10×5 px"; `CARET` is a **half** extent, so they are 16×16 triangles. Code wins — the doc's number was never rendered. |
| Left hand cell | 0.031 (40) | 511 | 64 × 64 | Doc said 32×32 (§5.2) and 34×34 (§5.2b). **Both lose.** |
| Right hand cell | + cell + 12 (116) | 511 | 64 × 64 | ← → carets over this one, always, even owning only the sword. |
| Item cell | + cell + `CLUSTER_GAP` 22 (202) | 511 | 64 × 64 | ↓ caret over it; `X` cap under it. |
| Key caps | centred under each cell | cell bottom + 4 (579) | 14 px on MIDNIGHT@80%, pad 3 | No. |
| Loadout line | right-aligned to the item cell (266) | caps bottom + 9 (602) | 14 px on MIDNIGHT@80%, pad 3 | No. |

### The money pole — one right edge at x 0.969 (1240)

| Element | x | y | Size | Moved? |
|---|---|---|---|---|
| Value slips | right-align 0.969, max w 0.094 (120) | bottom **0.845** (608), stacking up | 4 px + 2 gutter, ≤8 | Doc said 3 px and 0.803 → 0.858. 4 px wins; the top is derived from the count, not authored. |
| Slip overflow `+N` | right-align 0.969 | above the last slip | 10 px MOTH | Was 7 px. Decision 19. |
| Bag rim | **0.812 → 0.975** (1039 → 1248) | 0.786 → 0.914 (566 → 658) | 2 px | **Moved.** The right edge was 0.978 — 4 px **outside** the safe margin. Snapped to the safe edge exactly. Decision 14. |
| Item toast / autosave | right-align 0.969 | 0.767 (552) | 16 px toast / 14 px autosave | No. |
| Extraction hold | **the rim itself** | — | the rim's own 2 px frame redrawn CYAN, clockwise from top-left, over 1.5 s | **Moved.** Was a 54 px arc centred on `BAG_NUM_BASELINE`, the anchor of a number deleted in 2026-08-09. Decision 15. |

### Top edge

| Element | x | y | Size | Moved? |
|---|---|---|---|---|
| Floor card | 0.031 (40) | 0.052 (37) | name 10 px over level 16 px, VOID@72%→34% plate, pad 6 | Plate recipe unified (decision 4.4); both lines now dim (decision 18). |
| Minimap frame | right-align 0.969 (1240) | 0.052 (37) | 148 × 148, 8 px pad, VOID@88% on 1 px ASH | No. |

### Centre and full-screen

| Element | x | y | Size | Moved? |
|---|---|---|---|---|
| Crosshair | screen centre, quantized to 480×270 | " | gap 7 (5 locked), arm 5, 1 px | New row — undocumented until now. |
| Interact prompt | centre 0.500 | 0.735 (529) | 14 px on VOID@72%, pad **6** | New row. Pad was 7; unified. |
| Prompt hold gauge | inside the plate | plate's bottom edge | `HoldGauge.BAR_H` | New row. |
| Extraction sweep | 0.0 → 1.0 | 0.500 | 1 px CYAN, 200 ms | No. |
| Damage-direction arc | centre 0.500 | centre 0.500 | r = 0.28h (202), 3 px RUST, 40°, 300 ms, at `Hit.from`'s bearing | **New — replaces `Feel`'s vignette.** Decision 13. |
| Legend (garrison, transient) | centre 0.500 | up from 0.962 (693); 2 lines, step 15 | 10 px ASH | **Moved to transient.** Decision 8. Its second line reaches 0.976, past the safe margin — acceptable for 10 s, not acceptable permanently. |

### World-anchored (these obey the world's rules, not the frame's)

| Element | Size | Moved? |
|---|---|---|
| Lock brackets | half-extent (26, 34), arm 8, 2 px, quantized to 480×270 | **Colour changes**: RUST hostile / CYAN hookable / MOTH neutral. Decision 16. |
| Enemy health bar | 20 × 2 px (×2.2 locked), 1 px frame (BONE if elite), ASH@85% track, RUST fill, ≤22 m, LOS-gated, quantized | No. |

### Rows deleted from §5.7

| Row | Why |
|---|---|
| Bag numeral baseline (0.900) | The number was deleted 2026-08-09; §5.6 records it and §5.3 never caught up. `Pal.BAG_NUM_BASELINE` goes with it. |
| Extraction hold ring (r 54) | Replaced by the rim (decision 15). |
| Room name baseline (0.139) | Never drawn; `Pal.ROOM_NAME_BASELINE` has zero callers; Jacquard was never wired. The floor card is the announcement. |
| Cross origin / 34×34 cell | There is no D-pad cross. One item cell, at cluster width. |

---

## 9. The remaining decisions, and the document edits they authorise

Code and doc land in the same commit, per CLAUDE.md §7.

**Decision 14 — the bag rim moves to 0.975, the safe edge exactly.** Its right edge
is 0.978 today, which puts 4 px of a permanent element outside a margin the
styleguide defines and nothing enforces. Rejected: widen the safe area. The margin
exists for overscan and for the corner of a 16:10 display; the rim is the thing
that is wrong.

**Decision 15 — the extraction hold is drawn on the rim, not as a floating arc.**
The arc is 54 px, centred on the anchor of a number that no longer exists. The
styleguide's argument for it — *"you are literally drawing a ring around your
money"* — is right, and the rim **is** that ring: it already frames the bag, it is
already 2 px, and it is already the thing whose colour says what is at stake.
Redraw its frame in CYAN, clockwise from the top-left, as the hold fills; unwind
over 150 ms on release. This deletes a widget and an anchor rather than moving
them. `HoldGauge` gains a `frame(rect, t01, colour)` beside its existing `ring` and
`bar`, so all three "keep holding" surfaces still speak one language.

**Decision 16 — lock-on: the doc wins on colour, the code wins on animation.**
The brackets take the target's kind — RUST hostile, EXTRACT CYAN hookable /
interactable, MOTH neutral — because CYAN-is-the-way-out is a §2 law and RUST on a
hookshot target breaks it. The converge-from-1.4×-over-90 ms and the fly-outward
break are **deleted from the doc**: acquisition is already announced by the bracket
appearing and by the crosshair changing colour and closing its gap in the same
frame, and a 90 ms scale animation is the one place easing would get back into this
HUD (§7.4). The off-screen chevron is **deleted from the doc** too: the camera sits
behind the hero, so a locked target leaves the frame only when the player has
turned away from it on purpose, and a chevron then is the HUD arguing with the
camera about where to look.

**Decision 17 — §5.3 is rewritten around what is actually there.** Delete
component 1 (the number) and everything that belonged to it: the 300 ms roll, the
gold floater, the 1.2 s death count-down. What remains is the slips, the rim and
"nothing under it". Two riders:
- **The T3 breath moves to the rim**, at 0.5 Hz. It was specified for the number;
  the rim is the only thing left in that corner, and "the game reminds you what is
  at stake at the instant you are hurt" is worth keeping. The 2-frame GOLD flicker
  on damage moves with it.
- **The slip slide-in is deleted, not moved.** A 120 ms slide with the others
  re-proportioning is eased HUD motion and §7.4 bans it. The 1-frame rim flash in
  the drop's rarity colour already carries the event, and it is instant.

**Decision 18 — the floor card's level line dims with the name.** Both lines go
BONE on announcement and MOTH once settled. Today the level line never dims, on
the argument that it is the half carrying the information — which is true, and is
exactly why it is Tier 3: it is a question you ask *between* rooms, when you have a
second to read MOTH on a plate. A permanent BONE line in the top-left corner is a
Tier 3 element wearing Tier 1's brightness, competing with the fight for the same
channel. The plate (decision 4.4) is what makes MOTH legible over torchlit brick;
that was always the plate's job.

**Decision 19 — the ammo/charge numeral, the bottle count and the slips' `+N` go
from 7 px to 10 px.** Section 2's second rule: the smallest text on the screen must
not be a thing you read mid-fight. 7 px also sits below `CanvasText.MIN_SIZE`'s
clamp, so it is already being rendered at an em size the layout does not think it
asked for.

### The styleguide edits

- **§3.1** — delete the rounding sentence; replace the size list with decision 2's
  ladder; keep the "seven sizes reads as accreted" rule.
- **§5.1** — fold in the bar override; delete the discrete-cell prose.
- **§5.1c / §5.1d / §5.1e (new)** — the magic bar; the heat bar and its multiplier;
  the draught pips.
- **§5.2 / §5.2b** — **merge them.** They describe one cluster and disagree about
  its cell size. One cell size (64 / gap 12 / cluster gap 22), one caret spec
  (16 px, half-extent 8), one caret rule.
- **§5.3** — decision 17.
- **§5.5** — decision 16.
- **§5.6** — rewrite the ALWAYS list from §1's table. It is **twelve**, not seven:
  health, stamina, magic, heat\*, draughts\*, the three cells, the bag rim, the
  slips, the minimap\*, the floor card\*. (\* = dungeon only.) Delete the room-name
  card from FADES IN; add the damage arc, the autosave notice and the interact
  prompt.
- **§5.7** — replaced wholesale by §8 above.
- **§7.2** — unchanged; **the code changes.** `_draw_hands` and `_draw_cpad` pass
  `Color.BLACK` as `invert_to`. It never reaches a pixel today (`inverted` is only
  true for the raised shield, where the argument is `Pal.MIDNIGHT`), which makes it
  a trap that is armed and not fired. Pass `Pal.VOID`. The point of the rule is that
  `grep -r 'Color.BLACK' scripts/ui` must be able to answer the question.
- **§7.10** — unchanged. `Feel`'s vignette goes (decision 13).
- **§8 — delete the `hud.gd` bullet.** It says *"`scripts/ui/hud/hud.gd` is a full
  replacement, not an edit. What survives is the architecture: autoload + `_draw`,
  screen-fraction coordinates, repaint on signal rather than per frame, and the
  `player`-group visibility gate."* **The replacement already happened**, and the
  current file is exactly that list: `extends CanvasLayer` as autoload `Hud`, one
  `Control` drawing in `_draw`, every coordinate a `Pal` fraction, `set_process`
  gated on live animations, `_refresh_visibility` gated on group `player`. There
  are no hearts, no OOT magic meter, no N64 C-pad. The bullet is stale, and a reader
  would believe a rewrite is still owed. The last fossil is a function name:
  `_draw_cpad` draws one item cell and should be `_draw_item_cell`.
- **`docs/CONTRACT.md` §7.1** — still mandates the OOT HUD replica. §8's third
  bullet has been asking for that amendment for weeks and other agents build against
  it. Out of scope for this card; recorded here so it does not stay invisible.

---

## 10. Explicitly not in scope

- **No new UI screen.** SCOPE §1 says 1, and the exception is spent on
  `StashScreen`. Decision 8's permanent home for the legend is Options → Controls,
  which exists. Nothing in this plan opens a panel.
- **No easing.** §7.4. This kills the slip slide-in, the bag-number roll (with its
  number), the lock-on converge, and any temptation to tween the new arc's radius.
  Instant, or four discrete steps, or a pulse. The arc fades on a linear alpha over
  300 ms — the same construction the item toast already uses.
- **No bloom or glow.** §7.5. The T2 rim halo stays a 1 px dithered GOLD ring at
  18% — a dither, not a glow — and the T3 breath is a brightness lerp on an existing
  2 px frame.
- **No vector icons.** §7.10. Every glyph stays a baked model render posterised into
  the Pal ramp (`_iconbake.gd`), a drawn polygon (the carets, the bottle, the map
  markers), or two letters. The workings deliberately have **no** icon and never
  will: `ArmamentDb.LETTERS` already records why — the baker bakes *models*, and a
  working has no model, so `BU` is the honest cell rather than a placeholder that
  would have to be un-drawn the day someone asked what it was.
- **No change to the minimap** (§5.5b is current), **the enemy bars** (§5.5 was
  amended alongside the code), or **the bag's histogram semantics**.

---

## 11. The proof

Today `tools/directors/hud_lookdev.gd` photographs nine states and prints one
line — `HUDCHECK bag=… value=… slots=… fee=… gold=…` — **and asserts nothing about
the screen.** Every number on that line comes from `Run` and `Game`; not one of
them would differ if the HUD drew nothing at all. `hud_vitals.gd` is the only HUD
director with a hard assertion, and it is about the *hero* (a roll must be
refused), not about the frame.

That is why §0's collision shipped, and why the draught row landed on the stamina
bar the first time, under a comment that says so.

**Decision 20 — the HUD exposes its layout, and the directors assert on
rectangles.** `Hud` gains a debug-only `layout_rects() -> Dictionary[StringName,
Rect2]`, populated during `_draw_hud` **by the same code that draws** — not a
second table, which would be §0 again in a new place. Then three assertions:

1. **Nothing permanent overlaps anything permanent.** Pairwise `Rect2.intersects`.
   This one assertion catches §0's collision, the historical
   caps-through-the-health-bar bug, and the legend-off-both-edges bug. They are one
   class of defect and there has never been a check for it.
2. **Everything permanent is inside the safe area** — x ∈ [32, 1248],
   y ∈ [22, 698] at 720p, scaled by viewport. Catches the bag rim at 0.978 and the
   legend's second line at 0.976.
3. **Every text size is on the ladder.** `CanvasText.scale_for` pushes an error in
   debug builds when `ref_px` ∉ {10, 14, 16}. This is the only check that can see
   *call sites*, which is why it belongs in the function and not in a director.

**Which director proves which claim:**

| Director | Status | Proves |
|---|---|---|
| `hud_lookdev.gd` | **extend** | Its nine existing states, plus assertions 1 and 2 on each. Two new beats: a working in the right hand at charges > 0 and at charges = 0 (the numeral must draw both times and `"?"` must never appear), and the extraction hold at 0.65 now filling the **rim**. |
| `hud_pole.gd` | **new** | The vitals pole, garrison **and** dungeon, at 0 / 1 / 2 / 3 live draughts, at each heat tier, with magic full and spent. Assertions 1 and 2 every frame. **This is the beat that would have caught §0** — and it must run in both scenes, because the collision is a different one in each. |
| `hud_vitals.gd` | keep | The stamina claim: a roll at 32/100 is refused and the hero does not roll. Unchanged. |
| `alchemy_loop.gd` | **extend** | Add assertion 1. It passed for the entire life of the previous draught-row collision, which is the evidence that a director without a rectangle check is not proof. |
| `enemy_bars.gd` | **extend** | Bracket colour by target kind: lock a hostile, a hookshot target and a neutral in turn, assert three different colours. The code hard-codes RUST and no capture has ever disagreed, because nobody has photographed a hookable lock. |
| `heat_flow.gd` | keep | The break flash and the tier ramp. |
| `mvp_loop.gd` | keep | End to end — it is what says the HUD still comes up at all. |

And the bar that is not a director, from CLAUDE.md §2: a clean
`godot --path . --import`, a clean boot, and **your own eyes on the output**. For
this card specifically, on the garrison frame with three draughts running and a pad
plugged in — the single frame that exercises the pole, the transient legend, the
device-change re-show and the key caps at once.

---

## 12. Order of work

Each of these leaves the tree consistent and is one commit.

1. **The collision** (6, 7) + `hud_pole.gd` + assertion 1. Land the proof and the
   fix together, and make the director fail on the old code first.
2. **The tables** (10–12): `KIT_ICON` / `KIT_LABEL` / `KIT_ACTION` out of `hud.gd`,
   `hand_count` numeral in. Coordinate with the session adding the burst rows —
   this deletes the table they are editing, and the deletion is the point.
3. **The type ladder** (1–3, 19) + assertion 3.
4. **The plates and the edges** (4, 14, 15): two plate recipes, rim to the safe
   edge, hold onto the rim, and the five dead constants deleted. + assertion 2.
5. **The legend** (8).
6. **The vignette → the arc** (13), including `Bus.hero_struck`.
7. **Lock-on colour** (16) + the `enemy_bars.gd` beat.
8. **The bag and the floor card** (17, 18).
9. **The styleguide**, §9's list, in the same commits as the code each item names.
