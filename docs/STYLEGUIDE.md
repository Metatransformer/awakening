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

- No colour appears that is not in this table or a dither of two entries.
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

**The organising idea is two poles.** Bottom-left is YOU — health and kit, one
instrument. Bottom-right is THE MONEY — bag value and the way out, one
instrument. Opposite corners on purpose: in a panic your eye has to travel from
"how alive am I" to "how much am I about to lose", and that eye movement *is* the
game's central decision. The top stays empty except for transient state, because
the over-the-shoulder camera puts the action in the upper-middle third.

Design space is 1280×720; all coordinates are fractions of viewport, origin
top-left. Safe area: nothing within `0.025w` / `0.031h` of an edge.

### 5.1 Health — segmented quarter cells, not hearts

One horizontal row of discrete cells, one per quarter-heart, grouped in fours by
a wider gutter.

Because: discrete cells are **countable** at a glance and a smooth bar is not —
under pressure the player needs "three left", not "about a fifth". It preserves
the existing quarter granularity with no partial-shape clipping. It scales: the
OOT layout wraps to a second row at 11 hearts and the second row is a lie; a cell
row just gets denser. And it is unmistakably not Ocarina of Time.

| | |
|---|---|
| Origin | x `0.031` (40), top y `0.899` (647) |
| Cell | 6×20 px, 2 px gutter, **5 px gutter every 4th** (the heart grouping) |
| 5 hearts | 172 px wide. Cap total at `0.336`; past that cell width drops 6→4→3 and the group gutter carries the reading |
| Filled | VITAL | Empty | ASH @60% |
| Container | 1 px VOID hairline, 1 px outside the cells |

- **Damage ghost:** cells just lost stay lit in RUST for 400 ms, then drain
  right-to-left over 250 ms in 4 discrete steps. *How much you just lost* is the
  information; the new total is secondary.
- **Low health (≤3 quarters):** empty cells go VOID, filled cells pulse
  VITAL↔BONE at 2 Hz. No red screen vignette.
- **Extraction restore:** cells refill left-to-right at 40 ms/cell with a 1-frame
  BONE flash each — a full bar takes 0.8 s. The heal is the reward for leaving
  and it should be watched and counted, not granted in a frame.

### 5.2 Kit strip — sword / shield / hookshot / bow

Four permanent cells above health, sharing its left edge, so body and tools read
as one bottom-left instrument. No radial, no wheel.

| | |
|---|---|
| Row origin | x `0.031` (40), top y `0.826` (595) |
| Cell | 32×32 px, 6 px gutter → 146 px total |
| Fill | MIDNIGHT SLATE @80%, 1 px ASH border |
| Selected | 2 px BONE underline flush to cell bottom |
| Ammo numeral | 16 px MOTH, right-aligned at +29, +30 |

These cells show **state, not equipment** — sword and shield are never
unequipped, so an "equipped" indicator is dead pixels:

- **Shield cell** fills BONE while blocking; flashes RUST 2 frames on a blocked
  hit. The only place block timing is surfaced.
- **Sword cell** carries a 2 px combo-window tick along its bottom edge that
  drains over the window. The only place attack cadence is visible.
- **Bow cell** dims to 30% at 0 arrows. **Hookshot cell** brightens to BONE when
  a hookable target is in range and in the reticle — that is a targeting fact and
  it belongs on the tool, not floating in the world.

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
- **Target health:** a 2 px bar 6 px below the bracket, bracket-width, only while
  locked and only once the target has taken damage. Never a floating bar over
  every enemy.
- Off-screen locked target: an 8 px RUST chevron on the screen edge at the
  target's bearing, inset `0.028`.

### 5.6 Always visible vs. transient

**ALWAYS — five things, nothing else:** health cells, kit strip, bag total,
extraction line, ammo numerals. Each is a number the player must be able to
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
| Health row origin | 0.031 (40) | 0.899 (647) | cell 6×20, gutter 2/5 |
| Kit strip origin | 0.031 (40) | 0.826 (595) | cell 32×32, gutter 6 |
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
4. **No smoothly lerped HUD meters.** Discrete cells, instant or 4-step
   transitions. Continuous easing on a health bar reads as a web dashboard.
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
