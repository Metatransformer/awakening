# The Lower Worlds: Awakening — Visual Styleguide

Lo-fi PSX. This file is the source of truth for palette, type, render treatment
and HUD. Where it disagrees with `docs/CONTRACT.md` §7.1 (the OOT HUD replica),
**this file wins** — the game is a Moonlighter-shaped extraction crawler now, and
the HUD is explicitly modern rather than an Ocarina copy.

---

## 1. Thesis

> A cold, low-bit world of wet stone and dithered dark, where the only clean,
> saturated pixels on screen are the ones you are carrying out.

The core beat is **greed against the walk back to the exit**. Greed is an
abstraction until it has a colour, so colour is rationed and gold is the only
thing allowed to be bright. Dread is an abstraction until you cannot see how far
away the exit is, so fog is tuned as a draw-distance wall rather than as weather.

Material: damp stone, tarnished brass, dyed wool, bone.
Energy: long slow walk, short violent burst, long slow walk.

---

## 2. Palette

Twelve colours. Every channel byte is a multiple of 8, because the PSX
framebuffer was 15-bit RGB555 — 32 levels per channel. A hex that is not a
multiple of 8 is a colour the hardware could not show, and the quantizer will
move it anyway.

| Name | Hex | For |
|---|---|---|
| VOID | `#080810` | True background, deepest shadow, fog terminus deep down. Never `#000000`. |
| MIDNIGHT SLATE | `#181828` | Dungeon fog and clear colour. HUD panel fill at 80% alpha. The colour of "far away". |
| ASH | `#484050` | Mid surface: meter tracks, empty slots, HUD linework, town fog. |
| BONE | `#D8D0B8` | Primary text, HUD outlines, highlight flashes. The game's white. Never `#FFFFFF`. |
| MOTH | `#807868` | Muted text, disabled state, button glyphs, **and common-tier loot** — common items render in the "not worth reading" colour. |
| VITAL | `#E04038` | Health fill. Dirty arterial, not fire-engine. |
| RUST | `#B83818` | Danger: incoming damage, damage ghost, hostile lock-on, unaffordable cost. |
| GOLD | `#F8C038` | Currency, and **only** currency. The most saturated colour in the build. Not a torch, not a title, not a UI highlight. |
| EXTRACT CYAN | `#38D0C8` | The only cool saturated hue. Reserved for the way out: extraction nodes and the hookshot line — the two things that pull you somewhere. |
| MOSS | `#68A050` | Rarity: uncommon. |
| COBALT | `#5878C8` | Rarity: rare. |
| ARCANE | `#B060C0` | Rarity: legendary. Twice a run at most — a violet that shows up every room is decoration, not rarity. |

Rules that keep it dirty rather than clean:

- No colour appears that is not in this table or a dither of two entries. The
  named ones live in `Pal` under "derived dithers" so two systems reaching for
  the same mix cannot land on two colours: **FROST** `#48A8C8` (COBALT half and
  half with EXTRACT CYAN) is a body the hookshot has frozen — cyan alone is the
  hookshot's own hue but on a monster it reads as an extraction node with legs,
  and cobalt alone is cold stone rather than ice.
- Textures are authored at **≤16 unique colours** each (PSX 4-bit CLUT).
- The palette is an **authoring** constraint. The framebuffer quantizes to
  RGB555, not to twelve colours — palette-locking the framebuffer gives you a
  Game Boy, not a PlayStation.
- World surfaces sit between VOID and ASH with a texture saturation cap of
  ~0.25. GOLD and the rarity tiers are the only things above 0.6. **That gap is
  the art direction.**

---

## 3. Type

Two faces, both free to ship.

**Display — Jacquard 24** (Google Fonts, OFL). A bitmap-grid pixel blackletter.
Integer sizes only: 24 / 48 / 72. No smoothing, no subpixel positioning. Used
for exactly four things — the logo, the room name card, boss names, and the
death screen. It never appears in the HUD or a menu. Every PSX revival reaches
for a stencil-military face; a pixel blackletter is unmistakably ours.

**UI — Departure Mono** (OFL). Vector outlines drawn on a pixel grid: it looks
bitmap but scales to 1.5× cleanly, which matters because the HUD renders at
native resolution. Monospace tabular figures, because a gold counter that rolls
up must not reflow while it counts. Antialiasing **off**, subpixel positioning
**disabled**, sizes rounded to integers.

Type scale is **8 / 12 / 16 / 20 / 24 / 32 only**. Nothing between. A HUD with
seven sizes reads as accreted rather than designed.

| Role | Face | px @1280×720 |
|---|---|---|
| Bag total (the big number) | Departure Mono | 32 |
| Pocket gold / town cash | Departure Mono | 20 |
| HUD numerals — ammo, extraction cost | Departure Mono | 16 |
| Item-name drop toast | Departure Mono | 16 |
| Body / tooltip | Departure Mono | 12 (line height 16, max 42 chars) |
| Vendor row name + price | Departure Mono | 20 |
| Vendor description | Departure Mono | 12 |
| Column header | Departure Mono | 12, +1px tracking, MOTH |
| Shop screen title | Jacquard 24 | 48 |
| Room name card | Jacquard 24 | 24, BONE @30% |

All HUD sizes are `roundi(base_px * viewport_height / 720.0)`. A 1.5× scale must
land on whole pixels or the glyph edges go soft and the treatment collapses.

---

## 4. The PSX treatment

These are what separate "PSX" from "low-poly indie": PSX artifacts come from the
**pipeline**, not from the models.

### 4.1 Vertex jitter

Snap in clip space, after projection, before the perspective divide, to the
internal framebuffer grid.

```glsl
// vertex()
vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
vec2 grid = jitter_res * 0.5;          // NDC spans -1..1
clip.xy   = round((clip.xy / clip.w) * grid) / grid * clip.w;
POSITION  = clip;
```

`POSITION` is writable in `vertex()` without `skip_vertex_transform`, so
`VERTEX`/`NORMAL` still take the standard path and lighting is unaffected.

**Tiered, not uniform** — see Departure 1:

| Tier | `jitter_res` | Affine UVs |
|---|---|---|
| World geometry | `(480, 270)` | yes |
| Actors (hero, enemies, boss) | `(1440, 810)` | no |
| Loot, chests, extraction nodes | none | no |

### 4.2 Affine texture mapping

Defeat perspective-correct interpolation by pre-multiplying UV by `w` and
dividing by an interpolated `w` in the fragment stage:

```glsl
varying float w_affine;
void vertex()   { /* jitter, POSITION set */ w_affine = clip.w; UV *= clip.w; }
void fragment() { vec2 uv = UV / w_affine; ALBEDO = texture(albedo, uv).rgb; }
```

**Two shader files, not one uniform** — `world_psx.gdshader` (affine) and
`actor_psx.gdshader` (not). Blending between a projective and an affine UV is
meaningless, and a warping enemy is an unreadable enemy.

**Geometry requirement, and this is the part people skip:** affine warping is
invisible on tessellated surfaces and catastrophic on big ones. Subdivide world
surfaces to **≤1.0 m quads** (`K.TILE * 0.5`). An untessellated 8 m wall swims
badly enough to read as a bug.

### 4.3 Sorting

**Keep the depth buffer. Do not fake per-face sorting.** The PSX's sorting
errors were a defect — polygons popping through each other frame to frame — and
nobody in 2026 reads flicker as style. They read it as broken, and it directly
costs combat readability, which is the one thing we do not trade.

Harvest the legible half of the same look instead:

- **Ban blended transparency in world geometry.** Alpha is 1-bit:
  `ALPHA_SCISSOR_THRESHOLD = 0.5`, `render_mode depth_draw_opaque`. Grates,
  chains, foliage, banners — all cutout. The hard-edged silhouette is *why* PSX
  scenes look the way they do.
- Allowlist for blended alpha, four things, each with explicit `render_priority`:
  fog volume (−10), hookshot line (5), extraction beam (5), HUD (own layer).

### 4.4 Dither and colour depth

**15-bit RGB555 — 5 bits per channel, 31 steps. Ordered 4×4 Bayer, never
noise.** Noise dither reads as film grain or TAA and is the fastest tell that a
PSX look is a filter rather than a pipeline.

Dither **at the internal resolution, before upscale**. One dither cell must equal
one internal pixel. Dithering after the upscale is a grain overlay and worthless.

```glsl
const float bayer[16] = float[16](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0);
ivec2 p = ivec2(mod(floor(UV * src_size), 4.0));
float b = (bayer[p.y * 4 + p.x] / 16.0) - 0.5;
c = floor(c * 31.0 + b + 0.5) / 31.0;
```

**`rendering/anti_aliasing/quality/use_debanding = false`.** Godot's debanding is
a noise dither over the whole frame and it fights ours pixel for pixel.

The HUD is quantized to RGB555 but **not dithered** — it is authored in palette
colours already, so dithering only adds mush.

### 4.5 Internal resolution and upscale

3D SubViewport at **480 × 270**, fixed. (PSX was 320×240 = 76.8k pixels;
480×270 = 129.6k, the smallest buffer where an over-the-shoulder camera can still
resolve an enemy wind-up at 9 m, which is the lock-on acquisition range.)

`msaa_3d = DISABLED`, `screen_space_aa = DISABLED`, `scaling_3d_scale = 1.0`,
`use_hdr_2d = false`, `texture_filter = NEAREST`.

Present with **sharp-bilinear**, not raw nearest and not integer-only. Raw
nearest at a non-integer scale (720p is 2.67×) shimmers on every camera move;
integer-only forces pillarboxing at 720p.

```glsl
vec2 px = UV * src_size;
vec2 fl = floor(px) + 0.5;
vec2 uv = (fl + clamp(px - fl, -0.5, 0.5) / fwidth(px)) / src_size;
```

### 4.6 Fog as a draw-distance tool

Fog is the far clip plane wearing a coat. **Fog colour must be a palette entry
and must equal the camera clear colour exactly** — any mismatch draws a visible
horizon line, which is the thing fog exists to hide.

| Property | Dungeon | Town |
|---|---|---|
| `fog_mode` | `FOG_MODE_DEPTH` | `FOG_MODE_DEPTH` |
| `fog_light_color` | MIDNIGHT SLATE `#181828` | ASH `#484050` |
| `fog_depth_begin` | 6.0 m | 14.0 m |
| `fog_depth_end` | 22.0 m | 60.0 m |
| `fog_depth_curve` | 1.0 | 1.0 |
| `fog_sun_scatter` | 0.0 | 0.0 |
| Camera `far` | 26.0 m | 80.0 m |

Rooms are 16–24 m, so at `end = 22 m` you can just make out the far door of a
standard room and cannot see the far wall of the boss arena. Camera `far` sits
past `fog_end` so geometry never pops out of visible fog.

Deeper floors pull `fog_light_color` toward VOID and `fog_depth_end` to 16 m.
Depth is communicated by how much of the room you are allowed to have.

**Live hook:** `fog_light_color` lerps toward GOLD by 8% at bag tier 2 and 15% at
tier 3. See Departure 2.

### 4.7 Textures and lighting

| | Cap |
|---|---|
| World surfaces | 128 × 128 |
| Props | 64 × 64 |
| Characters | 256 × 256, one atlas each |
| UI icons | 16 × 16, hand-authored |

- **Texel density fixed at 32 texels/metre, everywhere.** Mixed density is the
  number one asset-flip signature.
- Import: Filter **Nearest**, Mipmaps **ON**, Anisotropic **OFF**, Compress
  **Lossless**.
  - Mipmaps ON is a deliberate deviation from real PSX, which crawled. At
    480×270 an unmipped nearest floor texture shimmers hard enough to obscure
    enemy positions. We simulate the console's look, not its bugs.
  - Lossless because BPTC/DXT on a 64px texture saves nothing and shreds a
    16-colour palette.
- **`render_mode vertex_lighting, specular_disabled, diffuse_lambert`.**
  Per-pixel lighting on a 128px texture at 480×270 is exactly what "low-poly
  indie" looks like. Contrast lives in the texture, not the light.
- **No real-time shadows in the dungeon.** Actors get a blob shadow: a 1-bit
  alpha unshaded quad decal, 0.7 m across, scaled by ground proximity.
- Tri budgets: hero ≤900, standard enemy ≤500, boss ≤2000, chest ≤120, wall ≤32.

---

## 5. The HUD

**The organising idea is two poles and a control surface.** Bottom-left is YOU —
health and stamina, one instrument. Bottom-right is THE MONEY — bag value and the
way out, one instrument. Opposite corners on purpose: in a panic your eye has to
travel from "how alive am I" to "how much am I about to lose", and that eye
movement *is* the game's central decision.

**Top-right is WHAT YOU PRESS** (§5.2, §5.2b): the two hands and the three item
buttons, one cluster, every cell captioned with the key that fires it. It is not
a readout and it does not belong to either pole — it is a control surface, and a
control surface sits where the *thumb* thinks, not where the body's numbers live.

The hands were bottom-left until 2026-08-09, above health, on the reasoning that
what he is holding is a fact about his body. That was true and it was still the
wrong corner: every cell in the cluster answers *"what do I press"*, and splitting
that one question across two corners meant answering it with two glances.

Everything else at the top stays empty except transient state, because the
over-the-shoulder camera puts the action in the upper-middle third.

Design space is 1280×720; all coordinates are fractions of viewport, origin
top-left. Safe area: nothing within `0.025w` / `0.031h` of an edge.

### 5.1 Health — a ticked bar, not hearts and not cells

**Superseded 2026-08-08, on the owner's instruction: this was a row of discrete
quarter cells and is now a continuous bar.** The cells' argument was
countability — under pressure the player needs "three left", not "about a fifth"
— and that argument was right, so the countability is carried over by other
means rather than dropped: a **2 px VOID tick at every heart boundary and a 1 px
tick at every quarter**, cut *through* the fill. You can still count what is
left; the fill is continuous between the ticks.

What did **not** come across from the bar idiom is easing. §7.4 still stands:
the bar moves instantly on damage and drains its ghost in the same 4 discrete
steps the cells did. "Bar" here is the shape, not the animation.

One horizontal bar, fixed width. The width does **not** grow with max health —
a bar that lengthens as you buy containers walks across the screen and stops
being a shape you recognise peripherally. More containers means denser ticks.

| | |
|---|---|
| Origin | x `0.031` (40), top y `0.899` (647) |
| Bar | `0.268` w (343 px) × 15 px, fixed at every max-health value |
| Ticks | 2 px VOID full height at heart boundaries; 1 px VOID at 45% height at quarters |
| Filled | VITAL | Empty | ASH @60% |
| Container | 1 px VOID hairline, 1 px outside the bar |

### 5.1b Stamina — directly below health

Added 2026-08-08 with the roll cost (`K.STAMINA_ROLL`). Shares health's left
edge and sits `4 px` under it, deliberately **shorter** (`0.62×` the width) so
the two never read as one two-line meter in peripheral vision.

The one fact this bar exists to carry is *can I dodge right now*, so that is the
thing it says loudest: the fill is BONE while a roll is affordable and turns
**RUST** the moment it drops below one — the answer is a colour, not a
measurement the player has to take. Boundaries are drawn at each roll still
affordable, so the bar reads in **dodges**, not in percent, which is the only
unit it is ever spent in.

| | |
|---|---|
| Origin | x `0.031` (40), top y health bottom + 4 px |
| Bar | `0.62 ×` health width × 8 px |
| Filled | BONE, or RUST below `K.STAMINA_ROLL` | Empty | ASH @60% |
| Ticks | 1 px VOID at each affordable roll boundary |

- **Damage ghost:** cells just lost stay lit in RUST for 400 ms, then drain
  right-to-left over 250 ms in 4 discrete steps. *How much you just lost* is the
  information; the new total is secondary.
- **Low health (≤3 quarters):** empty cells go VOID, filled cells pulse
  VITAL↔BONE at 2 Hz. No red screen vignette.
- **Extraction restore:** cells refill left-to-right at 40 ms/cell with a 1-frame
  BONE flash each — a full bar takes 0.8 s. The heal is the reward for leaving
  and it should be watched and counted, not granted in a frame.

### 5.2 The hands — left and right, beside the D-pad

**Superseded 2026-08-08: this was a fixed four-cell kit strip (sword, shield,
hookshot, bow) and is now two cells, the hands.** The strip was a lie by the time
the loadout landed — it drew four items you always had, in a game where you find
the hookshot and the bow, and where the right hand can hold any of them. Two
cells that say *what he is holding right now* is the same pixel budget spent on
a fact that changes.

Two cells in the top-right cluster, immediately left of the D-pad cross and
centred against its two rows. No radial, no wheel. **Left cell is the left hand,
right cell the right hand** — the reading order is the body, not an inventory
order. Either can be empty: bow-and-arrows empties the shield arm, and an empty
cell is correct there rather than a gap to fill.

**Every cell carries the key that fires what is in it**, read from the live
`InputMap` at repaint (`Hud._hotkey`) and never from a table. This is not
politeness about rebinding — `user://settings.cfg` is replayed over the InputMap
at boot and wins (`docs/CONTRACT.md`, "the two ways this table has lied" #2), so
a printed "LMB" is a claim about the shipped layout, not about the one under the
player's hand. The caption is keyed by the ITEM, not by the hand or the cell:
two-handing the sword moves it to the other hand and the button that swings it
does not change.

**Glyphs are renders of the real models**, baked by `tools/scenes/_iconbake.gd`
and posterised into the Pal ramp, so the cell always shows the thing you are
actually holding and cannot drift from it. This is not a hole in §7.10: that
rule bans bought vector icon sets and demands glyphs authored *in the palette*,
and quantising a render to four Pal values with a 1 px VOID dilation is how a
render earns that. Lettering ("SW", "SH") survives only as the fallback for a
missing bake — an empty cell would read as "you have no sword", which is a lie.

The rule the bake taught: **thin items do not survive 32 px.** A whole sword is a
three-pixel scratch, so its icon crops to the guard and pommel rather than
dutifully showing the entire blade. `bow_knightly` is the one that still reads
poorly, because a bow is edge-on from every axis.

| | |
|---|---|
| Row origin | x `0.031` (40), top y `0.826` (595) |
| Cell | 32×32 px, 6 px gutter → 70 px total |
| Fill | MIDNIGHT SLATE @80%, 1 px ASH border |
| Ammo numeral | 16 px MOTH, right-aligned at +29, +30 |

Beyond naming the armament, these cells carry **state nothing else surfaces**:

- **A shield in the left cell** fills BONE while blocking and flashes RUST for
  2 frames on a blocked hit. This is the only place block timing is visible, and
  it is the one thing the old strip did that nothing else does — it survived the
  strip on that ground alone.
- **Arrows in the left cell** carry the count and dim to 30% at zero.

Not built, still wanted: a 2 px combo-window tick draining along the sword cell's
bottom edge, and the hookshot cell brightening to BONE when a hookable target is
in range and in the reticle. Both were written here before the loadout existed
and neither has ever been drawn — they are intent, not description.

### 5.2b The item buttons — a picture of the D-pad, top-right

Three cells in the physical arrangement of the D-pad: **▲ above, ◄ and ► below
it**, with a small ASH ▼ caret under the cross. Whatever the player bound to a
direction in the Items screen is what that cell shows (`docs/CONTRACT.md` §4.1).

**The arrangement is the label.** A row of three cells would need three direction
glyphs printed on them, and the player would still be translating "cell 2" into
"up" every time they reached for it. In the cross shape there is nothing to
translate: the cell is where the thumb is.

**An unbound button is drawn empty, not skipped.** A gap would break the cross,
and the cross is the whole point — three cells in a row plus one missing reads as
a rendering fault, not as a free slot.

The ▼ is a caret rather than a fourth cell because it is not bindable: it swaps
the primary and alternate sets. Drawing it as a cell would invite the player to
try to bind it — which is also why it is the one thing in the cluster with no key
cap under it.

**Cells are `Pal.CELL` = 64 reference px**, roughly double what they were until
2026-08-09, and the hand cell and the button cell are now the *same* size. They
used to differ by 2 px (32 vs 34), which at that scale nobody could see; doubled,
a 4 px difference stops reading as deliberate and starts reading as a bug.

The cluster is laid out **from its right edge** (`Pal.CLUSTER_RIGHT`, sharing the
bag's margin so the HUD has one right edge and not two), never from a left-edge
fraction. At the old size a left origin was safe. Doubled, the cross alone is 216
reference px and the old `0.886` left edge put it 82 px off the side of a 1280
screen. Anchor the thing that must not overflow.

| | |
|---|---|
| Cross origin | x `0.886` (1134), top y `0.044` (32) — the ▲ cell's row |
| Cell | 34×34 px, 6 px gutter |
| Fill | MIDNIGHT @80%, 1 px ASH border |
| Drawn now | 2 px BONE border on the cell holding the item currently in hand |
| Ammo numeral | 16 px MOTH on a bound bow, right-aligned inside the cell |
| Swap caret | 10×5 px ASH triangle, centred under the ▲ column |

### 5.3 The bag — the most important object on screen

Bottom-right, right-anchored at x `0.969` (1240). Four components, bottom-up.

1. **The number.** Running sale value. 32 px tabular, right-aligned, baseline
   y `0.900` (648), followed by a 16 px `◇` in GOLD. Below tier 1 it renders in
   BONE; from tier 1 up in GOLD — "you now have something to lose" should be a
   colour change you notice without reading.
2. **The value stack.** A right-aligned column of up to 8 slips, 3 px tall, 2 px
   gutter, bottom y `0.858`, top `0.803`. One slip per carried stack; **slip
   width is proportional to that stack's share of total value**, max 120 px; slip
   colour is the rarity tier. This is a value histogram, not an inventory list —
   the useful thought is "most of my money is that one violet slip", and no list
   gives you that in a glance. The 9th and beyond collapse into `+N` in MOTH.
3. **The rim.** A 2 px frame from `(0.740, 0.786)` to `(0.978, 0.958)`, coloured
   by the rarity of the single most valuable thing you carry. Silent, permanent,
   peripheral. It is how the bag whispers.
4. **The extraction line.** §5.4 — the bottom tier of the same cluster.

**When a drop lands:** 1-frame full-rim fill in the drop's rarity colour; a new
slip slides in from the right over 120 ms while the others re-proportion; the
number **rolls up over 300 ms, ease-out — never snaps** (the roll is the
dopamine, take the 300 ms); a 16 px item-name toast right-aligned at baseline
y `0.767` in the rarity colour holds 1.6 s then fades over 200 ms; a GOLD floater
rises 24 px over 600 ms from the loot's screen position.

**As the bag gets valuable** — thresholds T1/T2/T3 at 250 / 1000 / 3000:

- T1: number goes BONE → GOLD.
- T2: the cluster gains a 1 px dithered GOLD halo, **and `fog_light_color` lerps
  8% toward GOLD**. The dungeon warms up because you are rich in it.
- T3: the number breathes in brightness at 0.5 Hz, and **every hit you take
  triggers a 2-frame GOLD flicker on the number** — the game reminds you what is
  at stake at the exact instant you are hurt. Fog lerp goes to 15%.

**On death the number does not vanish.** The death card holds and the number
counts down to 0 over 1.2 s in RUST. Losing it has to be watched, not elided
into a fade.

### 5.4 Extraction affordance

Same cluster, bottom tier, right-aligned, baseline y `0.940` (677) — because the
decision is a comparison between two numbers and they must be adjacent.

| State | Render |
|---|---|
| Unavailable | `EXTRACT  340◇` — 12 px, label MOTH, cost GOLD |
| Unaffordable | Cost in RUST. On press: `NEED 340◇` for 1.2 s, no arc |
| Available | Promotes to 16 px EXTRACT CYAN, 2 px cyan left rule, button glyph |

**The "you can leave now" moment:** entering a node's radius sweeps a 1 px
EXTRACT CYAN rule across the full screen width at y `0.500` over 200 ms, once,
then gone. One screen-wide event then silence — a permanent banner nags, and a
sound alone is missable in combat.

**Hold to extract:** holding `interact` fills a cyan arc **around the bag number
itself** over 1.5 s (radius ~54 px, 3 px stroke). You are literally drawing a
ring around your money while the world stays live and enemies keep coming.
Release early and it unwinds over 150 ms. The cost is paid out of the thing you
are protecting, and the UI should say so.

### 5.5 Lock-on and targeting

Not a fairy, not a triangle.

- **Four corner brackets**, 8 px arms, 2 px thick, framing the target's projected
  AABB. RUST hostile, EXTRACT CYAN hookable/interactable, MOTH neutral.
- **Bracket positions quantize to the 480×270 internal grid before scaling up**,
  so the reticle jitters in lockstep with the world's vertex snapping. This is
  the cohesion detail that sells the treatment: the UI element that touches the
  world obeys the world's rules; the corner instruments do not.
- Acquire: brackets converge from 1.4× over 90 ms. Break: fly outward, fade over
  120 ms.
- **Enemy health:** a 2 px bar over the monster's **head**, 20 px wide, with a
  1 px VOID frame (BONE if the monster is an elite) over an ASH track and a RUST
  fill. **The locked target gets the same bar at 2.2× width** — the bracket
  frames it, and the emphasis is size rather than a second bar somewhere else.
  There is exactly one bar per monster and one code path that draws it.

  This **replaces** the old rule, which put a bracket-width bar 6 px *below* the
  bracket, only while locked, and ended "never a floating bar over every enemy".
  Changed on the owner's instruction. What the old rule was protecting is kept as
  three conditions, and they are load-bearing, not decoration:

  - **Only monsters in the fight.** Engaged, or already bleeding. An unwoken room
    draws nothing, so darkness stays a material (`docs/GDD.md` §4, pillar 5) and
    a bar never spoils an ambush.
  - **Only in line of sight**, by a raycast from the camera against world
    geometry. A bar anchored in the world obeys the world; without this the
    feature is an x-ray that reads monsters through walls.
  - **Only within 22 m.** Past that a 20 px bar is a smear, and a floor of smears
    is the icon vomit this section exists to prevent.

  Positions quantize to the 480×270 grid like the brackets, and the fill **never
  eases** — anti-slop §7.4 stands.
- Off-screen locked target: an 8 px RUST chevron on the screen edge at the
  target's bearing, inset `0.028`.

### 5.6 Always visible vs. transient

**ALWAYS — seven things, nothing else:** the health bar, the stamina bar, the
hands, the item buttons, bag total, extraction line, ammo numerals. Each is a
number or a binding the player must be able to
consult unprompted, because each feeds the single recurring decision — push on,
or leave. Anything that does not feed that decision has no claim on permanent
pixels.

**FADES IN:** item toasts; lock-on brackets and target health; the extraction
promotion and sweep; the room name card (Jacquard 24 @24 px, BONE 30%, centre
x `0.5`, baseline y `0.139`, 1.4 s on room entry); damage-direction arc (3 px
RUST, 40°, radius `0.28h` about centre, 300 ms); interaction prompts; gold
floaters.

**NEVER:** a minimap, quest text, objective markers, floating damage numbers, an
XP bar. No minimap specifically, because the dungeon is room-based and legible,
and a corner minimap trains the player to navigate by abstraction — which
destroys fog-as-draw-distance as a tension device outright. The `map` action
opens a **full-screen** map instead, and does not pause.

### 5.7 Anchor table

Fractions of viewport, origin top-left; px at 1280×720.

| Element | x | y | Size |
|---|---|---|---|
| Health bar origin | 0.031 (40) | 0.899 (647) | 0.268 w (343) × 15 |
| Stamina bar origin | 0.031 (40) | health bottom + 4 | 0.62× health w × 8 |
| D-pad cross origin | right-align 0.969 (1240) | 0.044 (32) | cell 64×64, gutter 12 |
| Hands origin | cross left − 22 | centred on cross | cell 64×64, gutter 12 |
| Key caps | centred under cell | cell bottom + 4 | PixelFont ×2 (14 tall) |
| Bag numeral baseline | right-align 0.969 | 0.900 (648) | 32 px |
| Value slips | right-align 0.969, max w 0.094 | 0.803→0.858 | 3 px + 2 gutter |
| Item toast baseline | right-align 0.969 | 0.767 (552) | 16 px |
| Extraction baseline | right-align 0.969 | 0.940 (677) | 12 / 16 px |
| Bag rim | 0.740 → 0.978 | 0.786 → 0.958 | 2 px |
| Room name baseline | centre 0.500 | 0.139 (100) | 24 px Jacquard |
| Extraction sweep | 0.0 → 1.0 | 0.500 | 1 px, 200 ms |
| Damage arc | centre 0.500 | centre 0.500 | r = 0.28h, 3 px |
| Safe margin | 0.025 w | 0.031 h | |

---

## 6. Two deliberate departures

### Departure 1 — the crunch is tiered, not uniform

**The norm:** every PSX revival applies jitter, affine warp and low resolution
uniformly, because that is what the hardware did. The result is that enemies
wobble, wind-up frames smear, and the genre quietly gives up on precise combat —
which is why almost every PSX revival is a walking sim, a horror game, or a slow
shooter.

**What we do:** three tiers (§4.1). World geometry gets full crunch. Actors get a
3× finer snap grid and perspective-correct UVs. Loot, chests, extraction nodes
and reticle brackets get none. One extra shader file and one uniform.

**Why it serves this game:** we have Z-targeting, a hookshot with a straight-line
flight, a shield with block timing, and enemies you must read at 8–10 m. Combat
precision is load-bearing. The artifact is a costume, and a costume that stops
you fighting is a bad costume. The scene still reads as PSX because the
environment is 90% of the pixels — the player just never loses the enemy.

### Departure 2 — colour is currency, and the world warms as you get rich

**The norm:** PSX revivals are uniformly desaturated dread. Everything is
grey-green fog and everything is *equally* muted, including the treasure. Gold
ends up as one more brown.

**What we do:** chroma is rationed. World surfaces cap at ~0.25 saturation. GOLD
and the four rarity tiers are the only colours permitted above 0.6, and GOLD is
reserved for money alone. Then we make it dynamic: as bag value crosses tiers,
**the environment's fog colour itself lerps toward GOLD**, the bag rim takes the
colour of your best item, and the number starts to breathe.

**Why it serves this game:** the walk back has no dread unless the thing you are
protecting is visible in your peripheral vision the whole way. This gives the run
a literal chromatic arc — you enter grey, you accumulate colour, the world warms
around you, and then either you extract and the screen goes calm, or you die and
it counts down to zero in RUST. The palette becomes the score.

---

## 7. Anti-slop list

1. **No CRT layer.** No scanlines, barrel distortion, phosphor mask, chromatic
   aberration, VHS tracking. We simulate a console's framebuffer, not somebody's
   1998 Trinitron. Doing both is wearing two costumes, and scanlines are the
   single most common tell of a filter bolted onto a normal-looking game.
2. **No `#000000` and no `#FFFFFF`, anywhere.** Black is VOID, white is BONE.
3. **No engine default font.** Open Sans in a PSX dungeon is the loudest
   "unfinished" signal available.
4. **No smoothly lerped HUD meters.** Instant or 4-step transitions. Continuous
   easing on a health bar reads as a web dashboard. Health and stamina are bars
   as of 2026-08-08 (§5.1) and this rule is exactly what survived that change —
   the shape moved, the easing ban did not.
5. **No bloom, glow or emissive.** The PSX had none. Dither toward BONE and let
   the 5-bit depth do the work.
6. **No normal maps, PBR metallic/roughness, SSAO, SSR, or screen-space
   anything.** Flat vertex-lit albedo.
7. **No mixed texel density.** 32 texels/metre everywhere.
8. **No un-decimated imports.** A 12k-tri purchased GLB gets decimated or does
   not ship.
9. **No toon shader, outline pass, rim light or cel bands.** That is a different
   genre's costume.
10. **No vector icon sets, emoji, or Font Awesome/Material glyphs.** Every HUD
    glyph is drawn procedurally as polygons or hand-authored at 16×16 in the
    palette. Also banned here: white-flash-on-hit as the only impact cue, a red
    screen vignette at low health, and a two-row heart layout.

---

## 8. Open deltas against the repo

- `project.godot` currently pushes the opposite way and needs: `msaa_3d=0`,
  `screen_space_aa=0`, directional shadow size 8192 → 1024 (or off),
  `soft_shadow_filter_quality=0`, plus `use_debanding=false` and
  `default_texture_filter=0`. `project.godot` is orchestrator-owned per
  CONTRACT §3.
- `scripts/ui/hud/hud.gd` is a full replacement, not an edit. What survives is
  the architecture: autoload + `_draw`, screen-fraction coordinates, repaint on
  signal rather than per frame, and the `player`-group visibility gate.
- `docs/CONTRACT.md` still describes an OOT-fidelity crawler with a key-locked
  dungeon and mandates the OOT HUD in §7.1. That section is superseded here and
  the contract needs amending rather than silently diverging, because other
  agents build against it.
