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

**Decision 14 — the bag rim moves to ~~0.975, the safe edge exactly~~ `0.969`.** Its
right edge is 0.978 today, which puts 4 px of a permanent element outside a margin
the styleguide defines and nothing enforces. Rejected: widen the safe area.

**Twice struck, and the second one is the plan contradicting itself.**

~~The margin exists for overscan and for the corner of a 16:10 display.~~
`display/window/stretch/aspect` is `keep` (§13.4): the canvas is letterboxed into an
exact 16:9 box at every resolution, so nothing is ever cropped and there is no 16:10
corner to lose. The hazard was gone before this sentence was written.

~~0.975.~~ **The number is `0.969`.** Decision 4.5 says *"one left edge, one right
edge… `0.969` for the slips, the toast and the minimap. This already holds
everywhere except the bag rim (decision 14)"* — it forward-references this decision
as the fix, and this decision then invents a **fourth** right edge 8 px outboard of
the other three, on the largest element in the corner. Snapping to the safe margin
was never the point; the safe margin only entered because the rim had wandered past
it. The point is decision 4.5's, and the money pole reads as ragged until the rim is
on the same edge as the three things it is supposed to be a column with.

A right reason matters because the next agent inherits the reason, not the number —
and here the wrong reason produced the wrong number.

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
not be a thing you read mid-fight.

~~7 px also sits below `CanvasText.MIN_SIZE`'s clamp.~~ **Struck: that is false,
and false permanently.** `scale_for(7.0, 720)` is `max(9 · 0.70 / 7, 1.0)` = 1.0,
and `size_of(1.0)` is `max(9, 10)` = 10 — above the clamp, not under it. The clamp
would only bite below a 648-tall canvas, and §13.4 shows the canvas is 720 tall in
every build on every display. The size rule stands on its own; it did not need a
second reason and the second reason was wrong. Checking it was the review, and it
is exactly the class of claim this document exists to stop.

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

**§13.12 replaces this list.** Two of the findings below have to land before item 1,
and one of them is the reason item 1's director exists.

---

# 13. The design review

Run against §§0–12 as they stood at commit `aa43e7b`, under `/plan-design-review`.
**The review was self-administered** — the same session that commissioned the plan
graded it — plus one independent voice given the plan, the styleguide, the GDD and
the code, and told to disprove rather than to agree. Where that voice and this
section agree the finding is marked; agreement between two readers of one document
is not evidence, and neither of us built the HUD.

**Four of the fourteen findings came from looking at rendered frames, and could not
have come from anywhere else.** The plan is 643 lines of careful reading of
`hud.gd`, and the defects it missed are the ones that are invisible in source and
obvious in a screenshot. That is CLAUDE.md §2's whole argument arriving on schedule:

```
timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
  --scene=res://scenes/rooms/training.tscn \
  --director=res://tools/directors/hud_lookdev.gd --out=/tmp/hd/x.png --warmup=60
```

`hud_lookdev.gd`'s own header opens *"An empty HUD always looks fine."* Finding 1 is
that sentence being wrong, in the director's own first frame, for the whole life of
the file.

## 13.1 The scores

| Dimension | Score | Why it is not a 10 |
|---|---|---|
| Information hierarchy | **6** | The three tiers are the best thing in the plan. It never checks its own pole against its own four separation rules, and the pole fails them. §13.5 |
| State coverage | **3** | Twelve permanent elements, no zero state specified for any of them. Four are empty in the first frame of every run. §13.2 |
| Accessibility | **2** | 643 lines, no mention of colour vision. The plan *removes* a redundant channel and *adds* a colour-only one. §13.3 |
| Responsive | **7** | Safe, but not for the reason the plan gives, and one real defect on the machine a pitch runs on. §13.4 |
| Internal consistency | **5** | Three places where the plan makes an argument and declines to apply it one line over. §13.10 |
| Implementability | **6** | Decision 20 is the linchpin and cannot be written as specified. §13.8 |
| Subtraction | **5** | Honest that ALWAYS is twelve. Converts one element, cuts none, and leaves standing the two its own decision 8 reaches. §13.10 |

A 10 on state coverage is every permanent element having a specified zero state that
*teaches the instrument*, which is an argument this codebase has already made and
won — see §13.2. A 10 on accessibility is every colour-only channel carrying a
redundant channel of shape or position. A 10 on hierarchy is the pole reading as two
groups without anyone being told it is two groups.

## 13.2 The screen is mostly empty and nobody had looked — CRITICAL

`h_00_fresh.png` is the dungeon at run start: the first frame of every run, and the
frame anyone shown this game sees first. In it:

- **The bag rim is a bare 209 × 92 px rectangle containing nothing.** It is the
  largest single element on the HUD and in the fresh state it holds no information
  at all. It does not read as an empty container; it reads as a panel that failed to
  load.
- **The heat bar is an empty track** with `X1.0` beside it — two of the twelve
  permanent elements spending pixels to say *nothing is happening*.
- **The draught row draws nothing whatsoever.** `_draw_draughts` opens
  `if live.is_empty(): return`.
- **The minimap is not there.**

So of twelve ALWAYS elements, four are blank and one of those is the biggest thing
on screen. The plan discusses the rim twice — move its right edge 4 px, redraw its
frame for the extraction hold — and never asks what is inside it.

**The codebase has already settled this question and the plan did not notice.**
`_draw_heat`, in its own comment:

> *The track is drawn even at zero, so the bar is a thing the player has seen before
> the first time it matters. An instrument that only appears once you are already
> doing well teaches nobody.*

That is the rule. It is right, it is written down, and exactly one of the four blank
elements obeys it.

**Decision 21 — every permanent element has a zero state, and the zero state is what
teaches the instrument.** Applied:

- **The draught row draws its three slots always, and the slots are fixed by kind** —
  slot 0 heart, slot 1 ironhide, slot 2 emberblood, in `PotionDb.IDS` order, each an
  empty ASH@60% track when that draught is not running. This replaces
  `if live.is_empty(): return` and it replaces packing live draughts leftward. Four
  things fall out of one change: the row has a constant silhouette, the pole's shape
  stops depending on inventory, **position becomes a channel** (§13.3), and the
  player has seen the instrument before the first draught they drink.
- **The rim's empty state is §13.7's slot marks**, which is a better answer than
  either hiding it or leaving it blank.
- **The minimap's absence in the fresh frame is unexplained and is now a question,
  not a decision.** §1 element 18 says KEEP and "§5.5b is current and correct", on a
  reading of the source. It is not on the screen. Whoever implements item 1 finds
  out why before touching it.

**Rejected:** hide the rim until the bag has something. It puts a 209 px element on
and off the screen during play, which is motion in Tier 3 (§2 rule 4), and it means
the corner that carries the extraction decision is unlearnable until you are already
carrying something worth extracting — heat's argument, exactly.

## 13.3 Colour is doing work nothing else does, and the plan takes away a crutch — CRITICAL

There is no mention of colour vision anywhere in the plan, the styleguide, or
`hud.gd`. That would be an omission on its own. What makes it a finding is the
direction the plan moves:

**Decision 7 deletes the draught captions.** Its argument is that
`PotionDb.tint_of` has already taught the colour. The three tints are:

| Draught | tint | |
|---|---|---|
| heart | `(0.88, 0.25, 0.22)` | red |
| ironhide | `(0.35, 0.47, 0.78)` | blue |
| emberblood | `(0.95, 0.55, 0.18)` | orange |

Heart and emberblood are two reds separated by hue and about 0.23 of relative
luminance. Under deuteranopia or protanopia they converge. The carrier is a **6 px
tall pip**, and the plan's fix deletes `HEART` / `HIDE` / `EMBER`, which is the only
other channel there was. That is a redundancy removal shipped as a decluttering.

**Decision 16 adds a new colour-only channel**: lock brackets take RUST hostile /
CYAN hookable / MOTH neutral, where today they are one colour. The decision is right
— CYAN-is-the-way-out is a §2 law and RUST on a hookshot target breaks it — but it
means the answer to *can I hook that* is hue and nothing else, on a bracket, mid-fight.

**Decision 21's fixed slots already solve the first one** at zero cost: with slot 0
always heart and slot 2 always emberblood, position is the primary channel and
colour is the redundant one, which is the right way round. The captions can go, and
they should — for the reason decision 7 gives, once the reason is true.

**Decision 22 — the lock bracket's kind is a shape, and the colour is the
redundancy.** Hostile keeps the four-corner bracket as drawn. Hookable draws the
same bracket with its corner arms turned **inward** — the same 8 px arm, mirrored —
which reads as a target closing rather than a target framed, and is the shape the
hookshot's own ring already uses. Neutral drops to two corners instead of four.
Three shapes, three colours, either one sufficient. This is `_draw_lock`'s existing
polygon with a sign flip and an arm count; it is not a new widget.

**Not in scope, and say so rather than let it look considered:** a colourblind mode,
a palette option, or any Settings row. SCOPE §1's one UI screen is spent. The point
of decisions 21 and 22 is that the fix is *construction*, not a toggle — and every
channel this HUD encodes in colour alone should get the same treatment as it is
touched, starting with the two the plan was already opening.

## 13.4 What the project's stretch settings actually guarantee

The plan specifies everything in fractions of viewport and says "scaled by viewport"
in three places. Measured from `ProjectSettings`, not from memory:

```
display/window/stretch/mode       = canvas_items
display/window/stretch/aspect     = keep
display/window/stretch/scale_mode = fractional
rendering/.../default_texture_filter = 1   (Linear)
rendering/2d/snap/snap_2d_transforms_to_pixel = false
```

`canvas_items` + `keep` means **the root viewport is 1280 × 720 in every build on
every display, and the canvas is letterboxed into a 16:9 box.** `_canvas` is a
`Control` at `PRESET_FULL_RECT`, so `_draw_hud`'s `s` is `(1280, 720)`, always.
Three consequences the plan does not know:

1. **Every fraction in §8 resolves to exactly one set of pixels, forever.** The
   anchor table is not a scaling scheme, it is a layout at one size. Decision 20's
   assertions can be written in absolute pixels with no viewport clause, which makes
   them simpler than §11 assumes.
2. **Decision 14's stated reason is void** — there is no 16:10 corner to lose.
   Corrected in place; the decision stands on decision 4.5.
3. **The one real responsive defect is `scale_mode = fractional` with a Linear
   filter.** On a 16:10 laptop at 1728 × 1117 the whole canvas is resampled by
   1.5514×, filtered. This HUD is built out of 1 px VOID hairlines, a 2 px rim and
   4 px slips; at 1.5514× with linear filtering some hairlines land on one pixel and
   some smear across two, and the pole shimmers when the window is resized. That is
   not a PSX treatment, it is a soft one.

**Decision 23 — `display/window/stretch/scale_mode` becomes `integer`.** The canvas
then scales by whole numbers only, every 1 px hairline is exactly N px wide, and the
posterised icon bakes stop being resampled into mush. The cost is a slightly smaller
image inside a slightly larger border on non-integer displays, which is the correct
trade for a game whose entire visual argument is that pixels are deliberate.
`project.godot` is orchestrator-owned (CONTRACT §3) and this belongs with card #20's
render-setting pass, not with the HUD commits — **recorded here so it does not stay
invisible**, and flagged because the HUD is the surface that shows the defect.

## 13.5 The pole reads as four of the same instrument — HIGH

§2 says the tiers must be separated *"by construction, not by intention"* and lists
the four separators: position, weight, colour, motion. Then §4's decision 4 gives
every meter one track recipe and one tick rule. Put the two together against the
actual pole and:

| Row | Tier | h | recipe | ticked | left edge |
|---|---|---|---|---|---|
| Stamina | **1** | 8 | VOID hairline / ASH@60% / fill | yes | 0.031 |
| Magic | **2** | 8 | identical | yes | 0.031 |

Two adjacent rows, same height, same construction, same tick treatment, same edge,
differing in hue and in 35 px of width. **None of §2's four separators separates
them.** `_draw_magic`'s own comment says *"Two bars that behave that differently must
not look identical, which is what the blue is for"* — which concedes that colour is
carrying it alone, and §13.3 is what that costs. In `z_pole_fresh.png` the four bars
read as one instrument in four colours.

**Decision 24 — the pole is built as two groups: `MAGIC_H` 8 → 6 and `MAGIC_GAP`
4 → 6.** That is the whole change.

```
health 15 ─┐ Tier 1: two rows, 4 px apart, 15 and 8 tall
stamina  8 ─┘
           ── 6 px ──          the break
magic    6 ─┐
heat     6 ─┤ Tier 2: three rows, 4 px apart, all 6 tall
draughts 6 ─┘
```

Gestalt proximity does the tier separation and uniform weight does the rest. **It
costs nothing:** magic's top moves 666 → 668 and its bottom stays at 674, so heat
(678), the draught row (688) and the pole bottom (694) do not move by a pixel, and
the 4 px of safe-margin slack in §8's table is unchanged. Magic keeps its ticks — at
6 px a 1 px VOID tick still reads, and the fill/ticks-measure-the-same-quantity rule
(decision 4.2) is why it has them.

**Rejected:** widen the Tier 1 / Tier 2 gap by adding pixels. The pole has 4 px of
slack and §0 is what happens when it runs out.

## 13.6 At low health the health bar borrows the stamina bar's colour — HIGH

From `h_08_low.png`, caught mid-pulse: at ≤3 quarters the health fill alternates
VITAL ↔ BONE at 2 Hz, and **BONE is exactly the stamina fill's colour, in the row
directly underneath.** For half of every cycle the most urgent state in the game is
the same hue as a full stamina bar 19 px below it. Worse, BONE is *brighter* than
VITAL, so the bar gets lighter as the player gets closer to death — the alarm
inverted. §1 element 3 marks this KEEP with no comment, because it is invisible in
source.

**Decision 25 — the low-health pulse is VITAL ↔ VOID, not VITAL ↔ BONE.** The fill
blinks to the track colour: the bar reads as failing rather than as brightening, it
never borrows another row's colour, and it stays inside §7.4 because a blink is a
pulse and not an ease. RUST was the other candidate and is rejected — it is stamina's
*exhausted* colour, which trades one collision for another.

## 13.7 The plan applies §5.6's test in one direction only — HIGH

§5.6's test is *"anything that does not feed push-on-or-leave has no claim on
permanent pixels."* The plan runs all twenty-nine elements through it and asks, each
time, *should this go?* It never once runs it the other way: **is anything that does
feed push-on-or-leave missing?**

It is. `HUDCHECK` prints `slots=8/12`, and `RunState` splits those twelve into a
3-slot **case** that comes home when you die and a 9-slot **hold** that does not.
That is the most push-on-or-leave fact in the game — it is literally what you lose —
and no pixel on the screen says it. The rim says the best rarity, the slips say the
distribution of value, and nothing says *how full* or *how much of this survives*.

Meanwhile `z_bag_rich.png` shows the same corner in the plan's own richest state: 38
items, 1130 value, seven slips crowded into the top 42 px of the rim, and **the
bottom 50 px of a 92 px box empty**. The rim spans y 566 → 658; the slips' bottom is
authored at 0.845 = 608. Those two numbers are on the same page of §8's anchor table
and they do not fit each other. That is the §5.2-versus-§5.2b failure this document
opens by criticising, recurring inside the document's own replacement table.

**Decision 26 — the dead band under the slips becomes the slot readout.** One row of
twelve marks along the rim's bottom inside edge: the first three (the case) full
height, the other nine half height, each filled when its slot is used and an empty
ASH@60% notch when it is not. Then, in one change:

- the rim's empty state has content and teaches the histogram before the player has
  one (§13.2, and heat's argument);
- the void under the slips is filled in **every** state, not just the empty one;
- the slips stop floating and get a floor to sit on;
- *how full is the bag* and *what does the case save* arrive on screen, both of them
  push-on-or-leave questions, in pixels that were already being spent;
- **no new element, no new corner, no new screen** — SCOPE §1 does not move.

It also gives decision 15's CYAN frame something to enclose, which the empty box did
not.

**Rejected:** a `n/12` numeral. This corner deleted two numbers on purpose (§1
element 22) and the argument holds — twelve marks is a shape you read without
counting, which is the whole reason the slips are a histogram.

## 13.8 Decision 20 cannot be written as specified — HIGH

Decision 20 is the linchpin: it is what makes §0 impossible a third time, and it is
item 1 of the order of work. Two holes.

**Assertion 1 — "nothing permanent overlaps anything permanent", pairwise
`Rect2.intersects`.** Written literally it fires on the first frame, because the HUD
is full of *deliberate* overlap: the ammo numeral inside the hand cell, the key caps
plate under the cells, the damage ghost over the health bar, the parry flash on the
cell fill, the slips inside the rim, the `X1.0` beside the heat track, and — after
decision 26 — the slot marks inside the rim. An implementer meeting this discovers
the assertion is unwritable, and the likely repair is an allowlist of pairs, which is
a second table describing the layout: §0 in a new place.

**Decision 27 — `layout_rects()` returns a tree, not a list.** Each entry carries its
parent key (`""` for a root). Assertion 1 is then *no two rects with the same parent
intersect, and every child is contained by its parent* — which is stronger than the
flat version, catches everything the flat version was meant to catch, and needs no
exemptions because containment is declared by the same code that draws, exactly as
decision 20 requires. Roots: the vitals pole, the control cluster, the money pole,
the floor card, the minimap. The ammo numeral's parent is the hand cell; the slot
marks' parent is the rim; the ghost's parent is the health bar.

**Assertion 3 — "every text size is on the ladder", enforced inside
`CanvasText.scale_for`.** It cannot see the one element on the screen that renders
off the ladder. `_draw_controls` calls `scale_for(10.0, s.y)` — which passes — and
then does `scale *= avail / widest` when the legend is wider than the safe area. The
rendered size is an arbitrary fraction of 10 px and the assertion is blind to it, so
it reports a clean ladder while the largest block of text on the HUD sits off it.

**Decision 28 — the legend wraps instead of shrinking.** 10 px is the bottom of the
ladder; there is nothing under it, so a legend that does not fit at 10 px has too
many words on a line, not type that is too big. Replace `scale *= avail / widest`
with `CanvasText.wrap(..., max_lines: 3)`. Decision 8 already makes the legend draw
upward into empty floor and already makes it transient, so a third line is free —
and the ladder assertion becomes true rather than merely unfalsifiable.

## 13.9 The damage arc needs a projection and a collision rule — MEDIUM

Decision 13 is the plan's best idea and is under-specified in the two places that
decide whether it works.

**The projection is never stated.** "At the bearing from the hero to the blow" does
not say bearing in what frame. It must be **camera-relative yaw**, or the arc points
at world north. And the convention has to be written down, because it is the whole
feature: a hit from directly in front puts the arc at the **top** of the circle, and
a hit from directly behind puts it at the **bottom** — which a player will read as
"below me" unless the game has taught otherwise. It is the near-universal convention
and it is fine; it is not fine to leave it to whoever writes the function.

**Simultaneous hits are not addressed.** Two blows inside 300 ms from different
bearings is common — it is what a pack does. One arc that jumps, two arcs at once,
or the newer one restarting the older one's clock are three different feels.

**Decision 29 — camera-relative yaw, 0° at the top of the circle, clockwise; up to
three concurrent arcs, each on its own 300 ms clock; a fourth replaces the oldest.**
Three because a fourth simultaneous bearing is not information a player can use, and
because `Hud` already runs one animation clock and this is a small array on it.
`Bus.hero_struck(from: Vector3)` is unchanged.

## 13.10 Three arguments the plan declines to apply one line over — MEDIUM

1. **Decision 8 makes the garrison legend transient** because controls are reference
   material and fail §5.6's test. The **key caps and the loadout line are the same
   information by the same test** and stay permanent, unargued. The plan should
   either say why a 4-character cap under a cell survives a test a 150-character
   line fails — and there is a real answer, that the cap is *attached to the thing it
   names* and so is read as part of the cell rather than as a sentence — or it should
   cut them. **Write the answer down.** An unstated distinction is how §5.2b happened.
2. **`_draw_heat`'s zero-state argument** is applied to heat and to nothing else.
   §13.2, decision 21.
3. **The plan's own opening complaint** — two numbers on one page for one thing —
   recurs in §8's anchor table for the rim and the slips. §13.7, decision 26.

## 13.11 What the review did not move

Said plainly, because a review that finds fault everywhere has not read carefully.
§0's collision is real and the arithmetic checks. Decision 6 is the right fix and
decision 9's refusal to bottom-anchor the pole is right for the right reason.
Decisions 10–12 are correct and the `hand_count` route is the one that makes a
working cost zero HUD changes. Decision 13's trade — a full-screen wash out, a
directional cue in — is the best single change in the document. Decision 17's
deletion of the slip slide-in, and decision 16's refusal of the lock-on converge, are
both §7.4 applied against the author's own instinct, which is the hard direction.
The type ladder is right and decision 3's greppability argument is the reason it will
survive. And §11's diagnosis — *no proof that can see a rectangle* — is the correct
root cause of §0; only its two assertions needed repair, not its thesis.

## 13.12 The revised order of work

1. **The zero states and the pole grouping** (21, 24, 25): fixed draught slots, the
   VITAL ↔ VOID pulse, `MAGIC_H` 6 / `MAGIC_GAP` 6. **This lands before the
   collision fix**, because decision 21 deletes the early return and the leftward
   packing that decision 7 was going to rewrite anyway, and because the pole is one
   commit's worth of thinking, not two.
2. **The collision** (6, 7) + `hud_pole.gd` + assertion 1 **as decision 27's tree**.
   Make the director fail on the old code first. `hud_pole.gd` runs both scenes and
   photographs 0 / 1 / 2 / 3 draughts, which is now also the proof of decision 21.
3. **The tables** (10–12). Unchanged. Coordinate with the Burst session.
4. **The type ladder** (1–3, 19) + assertion 3 + **decision 28's wrap**, which has to
   land in the same commit or assertion 3 ships blind.
5. **The plates and the edges** (4, 14, 15) + assertion 2 + the five dead constants.
6. **The bag** (17, 26): the slot marks, the T3 breath onto the rim, §5.3 rewritten.
   Promoted above the legend — it is the corner a stranger looks at first.
7. **The legend** (8).
8. **The vignette → the arc** (13, 29), including `Bus.hero_struck`.
9. **Lock-on colour and shape** (16, 22) + the `enemy_bars.gd` beat, which now asserts
   three shapes as well as three colours.
10. **The floor card** (18).
11. **The styleguide**, §9's list plus §13's decisions, in the same commits as the
    code each item names.

`scale_mode = integer` (decision 23) is **not on this list** — it is card #20's,
recorded in §13.4 so the tuning pass knows the HUD is what shows the defect.

**§14 amends this list.** Read it before starting item 1.

---

# 14. The independent voice

§13 was graded by the session that commissioned the plan. This is the other reader:
given the plan, the styleguide, the GDD and the code, told to disprove rather than
agree, and told that vague objections are as worthless as vague praise. Its scores
were harsher than §13.1's on every dimension (hierarchy 4, coverage 3, accessibility
1, responsive 2, consistency 4, implementability 4, subtraction 5).

**It converged with §13 on the two criticals** — colour doing unredundant work, and
the run's first minute never being drawn — which is worth something, since neither
reader saw the other's notes. Everything below is what it found that §13 did not,
or found harder. **It also caught an error in §13's own edit**, which is recorded
here rather than quietly fixed, because a review that hides its corrections is
selling the same false confidence §11 diagnoses.

## 14.1 The draught pips are the two bars above them, exactly — CRITICAL

§13.3 said heart and emberblood converge under deuteranopia. That was the weaker half
of the finding. The stronger half:

| | | |
|---|---|---|
| `heart_draught` tint | `(0.88, 0.25, 0.22)` | `Pal.VITAL` is `e04038` = `(0.878, 0.251, 0.220)` |
| `ironhide_draught` tint | `(0.35, 0.47, 0.78)` | `Pal.COBALT` is `5878c8` = `(0.345, 0.471, 0.784)` |

**They are the same colours, to the precision the palette is written in.** So the
pip row — under decision 4.1's mandate to use the identical VOID-hairline-over-ASH
construction, on the identical left edge, 12 px below — is a red bar under the red
bar and a blue bar under the blue bar. Under a Heart Draught the player reads a
second health bar draining. That is not a legibility risk, it is a false readout.

And decision 7's argument fails on its own terms independently of colour: *"the same
colour the bottle glyph in the item cell has already taught"* — the item cell shows
the **selected** bottle, which need not be, and usually is not, the draught that is
running.

**Decision 30 — the draught row is not a bar.** Three fixed slots (decision 21) that
**empty** rather than drain, each carrying a one-glyph mark — a heart outline, a hide
chevron, a flame — so identity is a shape and the row is visibly not a meter. The
tints stay as the redundant channel and stop being the only one. This also settles
decision 7 honestly: the captions can go, because a glyph replaced them, not because
a colour was asserted to have taught them.

Two corrections to decision 7's own text while it is open: the short names are
`HEART` / `HIDE` / `EMBER`, not `EMB` / `IRO` — five characters, so the captions the
decision deletes are ~60% wider than the example it argues with; and in the garrison
the row takes heat's slot at y 678–684 while the legend's first line has its cap top
at 677.64. **Only x separation saves them, the legend is centre-anchored, and its
width is set by live bindings.** `hud_pole.gd` must run the garrison beat *with the
legend up*, at three draughts, on keyboard **and** on pad, and assert non-intersection.
`Pal.HEALTH_ORIGIN`'s comment about the two "growing towards each other" — which the
plan quotes — is about exactly this pair, and §13 did not check it either.

## 14.2 Six colour-only channels, and the worst pair is not the one §13 found

Counted: bag-rim rarity (4 states), slip rarity (4), draught identity (3, stripped by
decision 7), lock-on kind (3, **created** by decision 16), stamina affordability,
magic affordability, shield state. The worst collision is `MOSS` (`68a050`) against
`MOTH` (`807868`) — mid-green against mid-khaki at near-identical luminance, the
textbook deutan pair — carried by the **bag rim**, whose entire information content
is that hue. A colour-blind player cannot tell *I am carrying something uncommon*
from *I am carrying junk*, which is the one thing that corner exists to whisper.

**Decision 31 — every colour-coded state carries a second channel, stated as a
construction rule in §4 rather than fixed per element.** Rarity gets rim thickness
(2 px common / 2 px + 1 px inner rule uncommon / 3 px rare / 3 px + dithered ring
legendary) — the T2 halo already proves that vocabulary exists. Slips get a 1 px VOID
notch count, 0–3, at their left end. Lock brackets get arm length (8 px hostile /
12 px hookable / 5 px neutral) **as well as** §13's decision 22 shapes.

**Decision 32 — assertion 4.** No permanent element's state may be distinguishable by
hue alone: render `hud_lookdev`'s states through a deuteranope matrix and assert the
two rarity rims differ in luminance by more than 15%. This is the only one of the
four assertions that cannot be written from `layout_rects()`, and it is the one that
would have caught MOSS-against-MOTH, which has been shipping since the rim was built.

## 14.3 The rim is being asked to say five things and decision 26 makes it six — HIGH

`_draw_rim` already carries rarity colour, the T2 dithered halo, and the 1-frame drop
flash. Decision 15 adds the extraction hold (CYAN, clockwise, 1.5 s). Decision 17
adds the T3 breath at 0.5 Hz and the 2-frame GOLD damage flicker. §13's decision 26
adds the slot marks. **Nothing arbitrates.** At T3, holding to extract, with a
legendary in the bag, taking a hit as a drop lands, the one rectangle that means *how
much you stand to lose* is asked to say six things in one frame — and the CYAN hold,
the only one that is a live response to a button the player is holding down, is the
one that loses, because it is the only one driven by an animation clock rather than
by state.

**Decision 33 — one function, one stated precedence ladder:** hold (CYAN sweep) >
drop flash (1 frame) > damage flicker (2 frames) > T3 breath > T2 halo > rarity. The
hold suppresses everything below it for its whole duration. The slot marks are
**not** on this ladder — they are inside the rim, not on its frame, which is the
second reason decision 26 puts them where it does.

And **the T3 breath moves off the rim to the slips.** Decision 17 relocated it there
because the rim was "the only thing left in that corner"; a 0.5 Hz brightness lerp on
a 2 px frame 209 px across is invisible, and it is now the fifth thing competing for
that frame. The slips breathing as a block is legible and is already a group.

## 14.4 Assertion 3 breaks a shipping screen the day it lands — HIGH

`CanvasText` is not HUD-only; its own docstring names *"the loading card, the
world-facing prompts and the run-end tally"*. `scripts/ui/loading/loading_card.gd:107`
calls `scale_for(TITLE_PX)` with `TITLE_PX = 32.0`. Decision 20's assertion 3, sitting
inside `scale_for` and erroring off the {10, 14, 16} ladder, pushes an error on every
loading screen in the game.

**Decision 34 — the ladder is a HUD rule, so the check is on a HUD-scoped wrapper.**
`Hud._text(ref_px)` asserts and forwards; `CanvasText.scale_for` stays unguarded.
§13's decision 28 (the legend wraps instead of shrinking) is still what makes the
assertion true rather than merely unfalsifiable — but it is now the only exception
that needed removing, rather than one of two.

## 14.5 Assertion 1 fails today on geometry that is not a bug — HIGH

§13's decision 27 made `layout_rects()` a tree, which fixes the deliberate-nesting
half. Three things it did not fix:

- **Which rectangle does an element report?** `_draw_health` issues at least four
  `draw_rect`s — grown hairline, track, fill, ticks. Health's hairline bottom is 651
  and stamina's hairline top is 653; report the ink and you have 2 px of margin,
  report the hairline and you have none to spare. **Report the outermost rectangle
  the element paints, hairline and plate included** — the conservative choice, and
  the one that would have caught §0 a row earlier.
- **What tolerance?** `Rect2.intersects` excludes borders by default, so a shared
  edge passes and a 0.4 px overlap fails — and fractional layout guarantees 0.4 px
  cases. Use `a.grow(-0.5).intersects(b.grow(-0.5))`.
- **It already fails.** At 8 stacks, slip 8 spans y 562.4 → 566.4 and the rim's top
  frame spans 565.92 → 567.92 — a half-pixel overlap between two permanent elements,
  today, by design. An implementer who meets that before meeting the real bug will
  add a fudge factor and lose both. Under decision 27's tree the slips are children
  of the rim and this resolves correctly; **say so explicitly**, because it is the
  first thing the new director will report.

**Decision 35 — assertions 1 and 2 are scoped to everything drawn in the frame under
test, not to the permanent set.** Decision 20 sells assertion 1 on three defects —
§0's collision, the caps-through-the-health-bar bug, and the legend running off both
edges — and decision 8 then makes the legend transient, which exempts it from the
check it is evidence for. It also exempts the legend's 0.976 second line from
assertion 2, which decision 8 waves through as *"acceptable for 10 s"*. A transient
element that overlaps a permanent one for ten seconds is a bug for ten seconds. The
directors photograph the transient states — legend up, prompt up, toast up — as their
own beats.

## 14.6 The arc crosses the fight, and §2 rule 1 is the plan's own objection — HIGH

Decision 13 rejects amending §7.10 because *"a full-screen red wash at the exact
moment you need to read a telegraph is the cue fighting the fight."* Its replacement
is a RUST arc at `r = 0.28h` = 202 px, which passes through y 158–562 and x 438–842:
straight across the middle third that §2 rule 1 keeps empty *"because the
over-the-shoulder camera puts the fight there"*. The radius was authored in §5.6 for
a HUD that did not yet have a crosshair or an interact prompt in the centre.

**Decision 36 — `r = 0.42h` (302 px).** Near the frame edge, where a directional cue
belongs, and clear of the telegraph.

And the bearing, which §13's decision 29 got half right. It named camera-relative yaw
and did not name the expression, in a repo whose CONTRACT §2.5 exists because facing
has been got wrong three times:

```gdscript
var local := cam.global_transform.basis.inverse() * (hit.from - hero.global_position)
var bearing := atan2(local.x, -local.z)   # 0 at the top of the circle, clockwise
```

`-local.z` because `-basis.z` is forward — the contract, spelled out, so nobody
derives it again. §13's three-concurrent-arcs rule is **overturned**: one arc ever,
a second blow replaces it and restarts the 300 ms. Three arcs at 302 px is three
RUST strokes around the frame at the moment the player is being hit twice, which is
decision 13's own objection a third time.

## 14.7 Four factual errors in the plan, and one that the branch overtook

1. **`hud.gd:1336` already reads `ArmamentDb.hand_count(id)`.** Element 12 and
   decision 12 describe a change that has since shipped — `ce6d723`, the Burst
   commit, generalised the arrow branch exactly as decision 12 asked. The plan was
   right when written and the branch overtook it. Only the 7 px → 10 px half of
   element 12 remains. **This is the good outcome**, and it is the evidence for
   decision 12's claim that a working costs zero HUD changes: it did.
2. **Decision 10's "byte-for-byte" is true of `KIT_ICON` and false of `KIT_LABEL`.**
   The empty-hand row differs — `&""` maps to `""` in the HUD and to `"—"` in the db.
   Harmless today because `_draw_item_glyph` early-returns on `id == &""`, but an
   implementer told the tables are identical will not check, and an em-dash in an
   empty cell is what would arrive.
3. **`Pal.KEYCAP_SCALE` has four call sites in three functions** (`hud.gd:1240`,
   `1242`, `1272`, `1408`), not the one decision 3 counts. The decision is right; its
   budget is low.
4. **The draught short names are `HEART` / `HIDE` / `EMBER`.** §14.1.
5. **Decision 19's `MIN_SIZE` claim** — independently found, already struck in place.

## 14.8 Where the two readers disagree, and what this plan does about it

- **Tier separation in the pole.** §13's decision 24 does it with height and gap
  (`MAGIC_H` 6, `MAGIC_GAP` 6, zero net pixels). The independent voice proposes
  dropping the `grow(1)` VOID hairline from magic, heat and the draughts instead, so
  Tier 2 is a lighter *construction*. **Decision 24 stands and the hairline stays.**
  The hairline is what keeps a 6 px row legible over torchlit brick, and §13.2's
  whole argument is that these rows must read when they are *empty* — an empty ASH
  track with no hairline over a lit floor is not a track, it is a smudge. The
  proposal is recorded because it is the better idea if the empty states ever get
  cut, and it should not have to be re-derived.
- **Where the ammo numeral is drawn is a real hit and is adopted.** Decision 19
  promotes it to 10 px because it is read mid-fight, and leaves it `Pal.MOTH`
  (`hud.gd:1343`) — the colour §2 rule 3 reserves for Tier 3. **Decision 37: the
  ammo/charge numeral is `Pal.BONE`.** Changing the size and not the colour is half a
  decision.
- **Cutting the magic bar** — the independent voice's strongest subtraction argument,
  and the one this plan declines. Magic is 48 with `MAGIC_SPIN` 12, i.e. a count of
  four, and charges are also a resource that does not come back and get 10 px of text
  in a cell; the same fact gets a 178 px meter in one case and eight pixels in the
  other. **The inconsistency is real and the resolution goes the other way.** Spins
  are spent *mid-swing*, on a trigger hold, with no menu and no pause — a length read
  peripherally is the right instrument for that, and a numeral is not. Charges are
  spent deliberately, at a distance, on a thing you aimed at. Two resources that do
  not refill, spent in two different tempos, correctly get two different instruments.
  **What was wrong is that neither document said so** — written into §5.1c.
  Recorded, not resolved: `Game.charges` is still one `int` for three workings.
- **Decision 8's missing signal is adopted.** There is no `garrison_entered` on
  `Bus`, and booting straight into the garrison is the one time the legend matters
  most. **Decision 38: show on `_refresh_visibility` going visible while
  `not Run.in_dungeon`, plus `Bus.input_device_changed`, plus `Bus.run_ended`** —
  boot, return-from-run and pad pickup, with no new signal. The 10 s hold pauses with
  the game; a legend that burns its window inside the Options screen is one nobody saw.

## 14.9 The order of work, amended

Insert into §13.12: decisions 30, 31 and 37 land with item 1 (they are the pole and
the pips, and 30 replaces the row's construction rather than adjusting it).
Decision 34 lands with item 4 and **before** assertion 3, or the loading screen
starts erroring. Decisions 33 and 36 land with items 6 and 8 respectively. Decision
35 rescopes assertions 1 and 2 wherever they appear. Decision 32's assertion 4 is its
own commit after item 9, because it needs a colour-matrix pass no director has today
and it is the only assertion that is not about rectangles.

---

# 15. What the build found — decisions the frames changed

§§0–12 are the plan, §13 is its self-administered review and §14 is the
independent reader. **This section is the implementation**, and it exists for the
reason §14.7 gives: a document that quietly diverges from the code it authorises
is worse than no document, and §13.8 had already found one decision that could
not be written as specified. Each entry names the decision, what was built, and
the evidence.

## 15.1 The draught row has two slots, not three — decision 21

**Decision 21 asks for three fixed slots: "slot 0 heart, slot 1 ironhide, slot 2
emberblood, in `PotionDb.IDS` order". Heart Draught has no clock.**
`PotionDb.apply` sends `heart_draught` to `Game.heal()` and never to
`Game.start_draught`, so `Game.draught_left(&"heart_draught")` is `0.0` for the
entire life of the game. Slot 0 would be a container that can never fill — a
worse lie than the empty row decision 21 was written to replace, and one that
would be on screen permanently.

**Built:** the row is every draught that *has* a clock, in `PotionDb.IDS` order.
Two today. `Hud._draught_slots` derives it from `Game.DRAUGHT_PLATE_ID` /
`Game.DRAUGHT_EDGE_ID` rather than listing it, so the row grows by a slot the day
a third lasting draught is brewed with no edit to `hud.gd` — decision 10's
argument at a smaller scale.

Decision 21's own reasoning survives intact and one clause of §13.3's does not.
§13.3 argued that fixed slots fix the heart-vs-emberblood deutan convergence by
making position primary; heart is not in the row at all, so that pair never
appears in it, and the remaining pair — Ironhide blue against Emberblood orange —
was never the confusable one. The redundancy still had to be built, for the reason
§14.1 gives instead, which is the stronger one anyway: **the tints are the bars
above, not each other.**

## 15.2 The marks are a plate, a point and a cross — decision 30

Decision 30 specifies "a heart outline, a hide chevron, a flame". **At six pixels
a heart outline is a blob**, and the row is 6 px tall by decision 24, which is not
negotiable because the 4 px of slack under the pole is what §0 was about.

**Built:** ■ Ironhide (a solid plate — the shape of something that stops arguing
with what hits it), ▲ Emberblood (a point — the flame, and equally the edge it is
put on), ✚ reserved for a Heart Draught that is ever given a clock. Chosen for
*separation at 6 px* rather than for iconography, on the same principle §5.6's
minimap markers already use.

Two things the first render changed, and neither could have been decided from
source:

- **The mark needs a chip.** Drawn straight onto the ash track it is the same
  colour and about the same size as the tiles beside it, and the slot came out as
  five blocks in a row with no way to tell which was the label. It now sits on a
  VOID@85% chip, which makes it read as the slot's name instead of as its first
  step.
- **A spent tile is a VOID notch at 30%, not 55%.** At 55% an *empty* row — which
  is the row's commonest state and the entire reason decision 21 draws it — came
  out as two black bars under the pole rather than as two empty containers. The
  zero state is the state this row has to get right.

## 15.3 The legend's shrink cannot make the legend fit — decision 28

§13.8 says `_draw_controls`'s `scale *= avail / widest` renders the legend at "an
arbitrary fraction of 10 px" and that assertion 3 is blind to it. Both true, and
**the shrink does not even work.** `CanvasText.size_of` clamps the em size at
`MIN_SIZE`, so once the computed scale falls under that floor the line renders at
a size the layout did not choose and *wider than `avail`* — which is why the
garrison capture at `4c04427` has the first line running from x≈0 to x≈1280,
off both edges, with the words overlapping each other.

So decision 28's wrap is not only what makes the ladder assertion true; it is the
only thing that makes the legend fit at all. Recorded because the plan justifies
the wrap on tidiness grounds and the actual defect is a functional one.

## 15.4 The geometry claim in decision 24, measured

Decision 24 claims `MAGIC_H` 8→6 and `MAGIC_GAP` 4→6 cost zero pixels. Measured
at x=60 in `res://scenes/rooms/dungeon.tscn` at 1280×720, before and after:

| Row | Before | After |
|---|---|---|
| Health | 635–650 | 635–650 |
| Stamina | 654–662 | 654–662 |
| Magic | 666–674 | **668**–674 |
| Heat | 678–684 | 678–684 |
| Draughts | — (not drawn) | 688–694 |
| Pole bottom | 694 | 694 |

The claim holds exactly: magic's top moves by 2 px, its bottom does not move, and
nothing below it moves at all.

## 15.5 The slips are not inside the rim — §14.5 is wrong, and the frame says so

§14.5 rescopes assertions 1 and 2 and adds, of the bag slips:

> under decision 27's tree the slips are children of the rim and this resolves
> correctly; say so explicitly.

Saying so explicitly is what this section is. It does not resolve. Measured in
`hud_lookdev`'s `h_09_t3` — the only frame in any director that reaches eight
stacks:

| Rect | Top | Bottom |
|---|---|---|
| `rim` | 563.92 | 660.08 |
| `slips` (8 stacks) | **560.40** | 608.40 |

The stack grows *upward* from `Pal.SLIPS_BOTTOM`, so its height is a function of
how many stacks are in the bag while the rim's top is a constant. At one to seven
stacks the containment holds and every director passes; at eight it clears the
rim's top frame by 3.5 px. The bag caps at twelve, so this is not an edge case
the player has to work for — it is the second half of a normal run.

This is §13.7's complaint arriving as a number. The rim's anchors and the slips'
anchors sit on the same page of §8's table and were authored independently, so
there is no expression anywhere that makes one follow the other; they agree by
coincidence for the first seven stacks and stop.

**The fix belongs to item 6, and it is to derive the slips' extent from the
rim** — the same move `_pole_top` already makes for the vitals stack, where one
function is the sole expression for where each row sits and nothing else is
allowed an opinion. What it is *not* is a larger `SLACK`: §14.5 warns in the same
breath that "an implementer who meets that before meeting the real bug will add a
fudge factor and lose both", and a tolerance wide enough to swallow 3.5 px is
also wide enough to swallow the four-pixel draught collision that assertion 1
exists to catch.

The check is landed failing on this, deliberately. §13.12 orders the assertions
before the fixes, and an assertion that is written after the thing it checks is
an assertion written to pass.
