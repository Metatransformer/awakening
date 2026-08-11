# The Lower Worlds: Awakening — Visual Styleguide

Lo-fi PSX. This file is the source of truth for palette, type, render treatment
and HUD. Where it disagrees with `docs/CONTRACT.md` §7.1 (the OOT HUD replica),
**this file wins** — the game is a Moonlighter-shaped extraction crawler now, and
the HUD is explicitly modern rather than an Ocarina copy.

---

## 1. Thesis

> A warm, low-bit fantasy world of lamplit stone, where the light is generous
> enough to love the place and the only clean, saturated pixels on screen are
> the ones you are carrying out.

**Changed 2026-08-09 on the owner's instruction.** The thesis used to read "a
cold, low-bit world of wet stone and dithered dark", and the lighting was built
to serve it: ambient at 0.26, torch falloff at 1.6, stone albedo at 0.18–0.32.
The result was measurably faithful to that sentence and wrong for the game — the
hero rendered as a black cut-out between sconces, monsters could not be read at
the 8–10 m the combat design requires (§9), and the room was a string of
spotlights in a void. That is a horror crawler's look. This is a **magical
fantasy** game: Zelda-shaped, LOTR-earnest. Players should feel warm, not
afraid.

The core beat is still **greed against the walk back to the exit**, and colour
is still rationed so gold stays the brightest thing you own. What changed is
where the dread comes from: it is the fee, the walk and the monster, **not the
inability to see**. Fog is atmosphere and draw distance now, not a blindfold.

Three rules keep "brighter" from becoming "flatter", which is the failure mode
this pivot walked into once already:

1. **Contrast is range, not darkness.** Every frame must hold a real dark (a
   doorway, a corner, a turned-away face) and a real bright (a torch pool). A
   uniformly lit room is a *lower*-contrast image than a dark one, and lifting
   ambient alone produces exactly that — one beige sheet.
2. **Warm key, cool air.** Torches are warm (`KitStyle.FIRE_COLOR`); ambient
   and the dungeon fill light are cool blue-violet. Warmth reads as warmth only
   against something cooler, so the hue contrast is what sells "magical" — and
   it lets shadows stay *coloured* rather than crushing to black.
3. **Not cutesy.** Saturation sits at 1.12, not 1.5. The palette stays earthy
   stone, brass, wool and bone. No candy colours, no cel bands, no outline pass
   (§10.9).

Material: lamplit stone, tarnished brass, dyed wool, bone.
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
| ASH | `#484050` | Mid surface: meter tracks, empty slots, HUD linework, garrison fog. |
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

### 3.0 The split: the world is PSX, the menus are Gallery Vellum

**This section used to describe every glyph in the game and it no longer does.**
Everything below §3.1 governs the HUD and the world — the layer the player reads
while the game is running, at native resolution, on the RGB555 grid. The MENUS
are a different surface with a different job, and since the Gallery Vellum port
they are governed by `scripts/ui/ui_theme.gd`: a 12→32 scale declared as
`UITheme.TYPE_*` constants, and `apply_text_style()` rather than a raw
`add_theme_font_size_override`.

**The shipped list is two faces, and only two:**

| Face | Job | Loaded by |
|---|---|---|
| **Alegreya Sans** (OFL) | Everything the player READS — body copy, dialogue, buttons, labels, tooltips | `UITheme.body_font()`, and `ThemeDB.fallback_font`, so it is the default for every Control |
| **Cinzel SemiBold** (OFL) | Everything that TITLES — headers, kickers, key numbers, `MenuHeading` / `MenuValue` | `UITheme.display_font()`, via `"display": true` on a `TYPE_*` |

Cinzel is an inscriptional capitals face; its lowercase is a small-cap. Do not
set it below ~14px, where the flared serifs close up — that is the floor the
`TYPE_*` table already respects.

**One exception, and it is the dialogue option list.** `VerbRow` promotes the
first row of a panel to the display face (`primary`), which is right on a shop
menu where one row is the verb and the rest are exits. It is wrong in a
`DialogueBox`: those rows are all things ONE PERSON can say, and `TRADE` in
Cinzel over `Leave` in the body face reads as two different kinds of object
rather than as two answers (owner's call, 2026-08-10). `DialogueBox._ask` passes
`primary: false` for every row and the lit edge stays the only cursor. If you add
a new list of things a character says, it goes in one face too.

Retired in the same change, and not to be re-added without a reason written at
`UITheme.BODY_TTF`: **Alegreya** (the variable serif that was the display face —
Cinzel does that job now, and two serifs on one panel is drift, not hierarchy)
and **Pixel Operator Bold** (its `keycap_font()` had no callers at all).

The HUD is on the same two faces. `scripts/ui/canvas_text.gd` paints
`UITheme.display_font()` onto a CanvasItem for everything drawn rather than
typeset — the vitals, the legend, the floor card, the key caps, the world
prompts. Until 2026-08-10 that file was a 5×7 bitmap of its own, which made the
HUD the one surface in the build that ignored the shipped pair.

Two reasons this is an amendment and not a betrayal:

1. **Departure Mono and Jacquard 24 were never wired.** Every menu in this game
   has rendered in `SystemFont` "Trebuchet MS" since `_build_theme.gd` was
   written — see its `FONT_NAMES`. This section described an intention, and the
   next agent to read it would have believed the code already did it.
2. **A pause menu is not diegetic.** The PSX treatment is about what the WORLD
   looks like through a 1998 renderer. A menu is the reader's surface, not the
   world's; making it fight the same pixel grid costs legibility and buys a
   consistency nobody experiences, because the two are never on screen sharp
   against each other.

The HUD stays on this page's rules. If you are typesetting something that
overlays play, read on. If you are typesetting a panel, read `docs/CONTRACT.md`
and `UITheme`.

### 3.1 The world faces

**Neither of these is wired, and neither ships.** The HUD and the world draw
through `scripts/ui/canvas_text.gd`, which sets §3.0's display face — Cinzel —
on a CanvasItem. What follows is the intention this section was written with;
treat the sizes as the type scale the HUD still obeys, and the two names as
unbought. If you wire either one, delete this paragraph.

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

### 3.1b The HUD type ladder

**Three sizes. 10 / 14 / 16, in reference px at 720p.** A HUD with seven sizes
reads as accreted rather than designed — that rule is the part of the old scale
worth keeping, and it is about a *count*, not about a particular set of integers.

| px @720 | Used for |
|---|---|
| **10** | ammo / charge numeral, bottle count `n/m`, slips `+N`, heat multiplier, floor name, legend |
| **14** | key caps, loadout line, interact prompt, autosave notice, cell lettering |
| **16** | floor level, item toast |

~~Type scale is **8 / 12 / 16 / 20 / 24 / 32 only**.~~ That list was authored for
Departure Mono, which the paragraph above admits was never bought and never
wired — a table of sizes for a face that does not exist in this build. The
shipped sizes were 7, 10, 14 and 16; three of those were already a coherent
ladder and the fourth was a hierarchy error. **7 px is gone**: it set the ammo
count, the bottle count and the slips' `+N`, which made the smallest text on the
screen also the text you read mid-fight (§2's second rule).

**Spelled one way, and enforced.** Every size in the HUD is `Hud._text(ref_px)`,
never `Pal.px(some_scale, h)` and never `CanvasText.scale_for` directly. The same
14 px used to be written three ways, one of which was the constant `2.0`, and a
ladder you cannot grep for is a ladder nobody can keep. `_text` pushes an error
and records the offender for `tools/directors/_hud_layout.gd`, which reports it
as assertion 3 beside the rectangle checks. The check lives on the HUD wrapper
and **not** inside `CanvasText.scale_for`, because the loading card legitimately
sets 32 px through the same function and the ladder has no authority over it.

~~All HUD sizes are `roundi(base_px * viewport_height / 720.0)`.~~ **Deleted.**
That was correct when this text was a 5×7 bitmap drawn one `draw_rect` per lit
pixel — a bitmap glyph off the pixel grid is a smeared glyph. It has been wrong
since the HUD moved onto Cinzel: `CanvasText.scale_for` deliberately does not
round, because rounding buys pixel-grid alignment on a face that has no pixel
grid and pays for it in the legibility of the smallest labels (it costs a 10 px
label 30% of its height at 720p). What still binds from that paragraph is the
antialiasing and subpixel-positioning note above it.

**A legend that does not fit is not shrunk.** There is nothing under 10 px, so a
line too wide for the safe area has too many entries on it, not type that is too
big — and shrinking could not work anyway: `CanvasText.size_of` clamps the em at
`MIN_SIZE`, so past a point the scale keeps falling while the glyphs do not, and
the line renders *wider* than the width it was asked to fit. Break between
entries and balance the rows.

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
- **A world-space `Label3D` is depth-tested. `no_depth_test = true` is never the
  fix for a caption swallowed by its own prop.** The flag does not mean "draw
  over the thing I hang off" — it means *draw over the world*, and the world
  includes every wall between the label and the camera. This has now been found
  four times in four places: an Echo's name painted on the shut shortcut door it
  was hidden behind (card #26), a shopkeeper's name plate readable through six
  metres of garrison curtain wall, and the training post's readout and damage
  numbers alongside it (card #37). What the flag is reaching for is real — a
  caption inside its own geometry is no caption — and the answer is the same one
  §4.3 gives everywhere else: **move the label, keep the depth buffer.**
  `SoundingStone.PLATE_DROP` and `TrainingPost.POPUP_CLEAR` are what that looks
  like in code. `tools/directors/echo_plates.gd` and
  `tools/directors/world_labels.gd` prove both halves by subtracting the labels
  back out of a frozen frame, which is the only instrument that works here —
  every property involved is identical in the broken and the fixed build.
  The two deliberate exceptions are `impact_vfx.gd` and `flourish_vfx.gd`, whose
  flashes are depth-tested *on purpose* and carry notes saying why.

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

> **Retuned 2026-08-09 with the §1 pivot.** Dungeon `fog_density` went 0.0115 →
> 0.0055 and the fog colour was lifted and pushed violet
> (`Color(0.16, 0.142, 0.175)`), because fog that is *darker* than the geometry
> reads as dread and fog that is slightly lighter reads as depth. The live values
> are in `assets/materials/env_dungeon.tres`; the depth-based table below is the
> older garrison-side treatment and the dungeon now uses exponential density.

| Property | Dungeon | Garrison |
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
  indie" looks like.
- **Contrast lives in the texture *and* in the light** (changed 2026-08-09, §1).
  It used to live in the texture alone, which is why stone albedo was authored
  at 0.18–0.32 — near-black paint. A dark material cannot return light, so the
  room stayed dark no matter what the lamps did, and that single fact was most
  of the old look. Wall/floor albedo now sits at **0.24–0.40**. Do not push it
  past ~0.45: above that the torch pools stop reading as light sources because
  the wall is already as bright as they are.
- **The dungeon carries one shadowless `DirectionalLight3D` fill**
  (`scenes/kit/dungeon_env.tscn`), cool and low-energy. It is not a sun — it is
  there so every block has a lit face and a turned-away face. Ambient alone
  raises all surfaces equally, which lifts the black *and* flattens the masonry
  into one sheet; "brighter" and "lower contrast" otherwise arrive together.
- **Every room carries at least four sconces of its own** (added 2026-08-11,
  card #38). The placement rule is *a walled side gets two, a holed side gets
  none* — an exit should read as the dark hole it is, and a locked door's cold
  lamp should not have a torch beside it. That rule had no floor under it, and
  the number of unlit sides is the number of exits: floor 1's **entrance room**,
  three doorways and the shortcut-door anchor on its fourth wall, was built with
  **zero**. Measured on the demo path, world area only: **72–76% of the frame
  under luminance 8, mean 8.6/255**, against the gate room's 0.6% and 45.2 off
  the same generator and the same `env_dungeon.tres`. Rule 1's black cut-out,
  exactly. A room short of the floor now lights the **flanks** of its holes —
  `_build_side` already splits a holed wall into two runs either side of the gap,
  so a pool at each end leaves the doorway the darkest thing in shot and an exit
  becomes a silhouette rather than a hole in a black wall. Anchored side first
  (it is the wall the room is *about*), then the side facing it, so the fire is
  at two ends. Rooms with two or more solid sides are untouched and their
  histograms do not move.
- **The measurement is `tools/directors/room_range.gd`,** and it is the thing to
  re-run before changing any of the numbers above. Five-band luma histogram of
  the top 70% of the frame — the HUD band is excluded, or you are scoring the UI
  — over seven poses on the demo path, against three bounds: no frame more than
  half under luminance 8, at least 3% above 64, mean at least 18. The second and
  third are what stop "fix the dark" being answered with lifted ambient; one
  beige sheet clears the first bound trivially and §1 rule 1 calls that a
  *lower*-contrast image than the black one.
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

**Bottom-left, directly above health, is WHAT YOU PRESS** (§5.2, §5.2b): the two
hands and the item cell, one cluster, every cell captioned with the key that
fires it.

**Top-right is WHERE YOU ARE** (§5.5b): the minimap. It is the only readout on
the screen that is about the ROOM rather than about the hero, and it is the one
thing that wants the corner the over-the-shoulder camera leaves emptiest.

The cluster has been in both corners and the reasoning each way is worth keeping,
because the second move is not the first one undone. It sat bottom-left until
2026-08-09 and moved to the top-right that day, on the argument that every cell
answers *"what do I press"* and a control surface belongs where the thumb thinks.
It came back down the same day, and the thing that settled it was not taste: the
map has to go somewhere, a map is a picture and needs a square of its own, and
the only square on a 1280×720 screen big enough to hold one is the top-right
corner. Given that, the cluster is better under health than beside a map — what
he is holding and how alive he is are one glance, and neither of them is
navigation.

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
| Origin | x `0.031` (40), top y `0.882` (635) |
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
- **Low health (≤3 quarters):** the track goes VOID and the fill pulses
  **VITAL↔VOID** at 2 Hz. No red screen vignette.

  It was VITAL↔BONE until 2026-08-10 and that was wrong in two ways a rendered
  frame shows and a reading of the source does not. BONE is *exactly* the stamina
  fill's colour in the row 19 px below, so for half of every cycle the most
  urgent state in the game wore another instrument's hue; and BONE is *brighter*
  than VITAL, so the bar got lighter as the player got closer to death — the
  alarm running backwards. Blinking to the track colour reads as the bar failing,
  which is the sentence. RUST was the other candidate and is stamina's
  *exhausted* colour, which trades one collision for the same one a row down.
- **Extraction restore:** cells refill left-to-right at 40 ms/cell with a 1-frame
  BONE flash each — a full bar takes 0.8 s. The heal is the reward for leaving
  and it should be watched and counted, not granted in a frame.

### 5.1c Magic — the only bar that does not come back

Third in the pole, under stamina. It is the charged spin's cost (`K.MAGIC_SPIN`,
a budget of four) and **the only meter here that never refills on its own** —
`Game.fill_magic` is called on entering a dungeon, on extracting and on dying,
and nowhere else. COBALT, which is also `Pal.RARITY`'s rare tier; the reuse is
safe because rarity colour appears on item names and loot rims and never as a
meter in this pole, and COBALT is the only saturated blue that is not CYAN, which
is reserved for the way out. The fill drops to MOTH below one spin: you have not
lost anything, you have simply spent your spins, so RUST would overstate it.

Ticked, at each spin still in the bar, because here the fill and the ticks
measure the same quantity — the rule in §5.1d's second paragraph.

**Why a bar and not a numeral, when charges are a numeral.** Both are resources
that do not come back, and they get a 178 px meter and eight pixels of text
respectively, which looks like an inconsistency and is a real one until you say
why. Spins are spent *mid-swing*, on a trigger hold, with no menu and no pause; a
length read peripherally is the right instrument for that and a numeral is not.
Charges are spent deliberately, at a distance, on a thing you aimed at. Two
resources that do not refill, spent at two tempos, correctly get two instruments.
Neither document said so before 2026-08-10 and that omission is what made it look
like drift.

| | |
|---|---|
| Origin | x `0.031` (40), top y stamina bottom + 6 px (668) |
| Bar | `0.52 ×` health width (178 px) × **6 px** |
| Filled | COBALT, or MOTH below `K.MAGIC_SPIN` | Empty | ASH @60% |
| Ticks | 1 px VOID at each `K.MAGIC_SPIN` boundary |

### 5.1d Heat — dungeon only, and deliberately not ticked

The fill is **time** — how much of the window is left before the chain steps down
— and the number beside it is **money**, what loot swept right now is worth. They
are adjacent because the decision the bar exists to provoke is the trade between
them: the multiplier is only worth chasing for as long as the fill lasts, and the
fill gets *shorter* the higher the multiplier goes.

**No tier ticks.** This was tried the other way first and photographed: health
and stamina are both ticked, so ticking this looked like consistency — but on
those two the fill and the ticks measure the *same quantity*, and here they would
not. Four ticked segments under a nearly-full bar read as "4 of 4 tiers" at Warm,
which is the exact opposite of true.

**The track is drawn at zero.** This is the rule the whole of §5.6's ALWAYS list
now obeys, and it was written here first: *an instrument that only appears once
you are already doing well teaches nobody.* The multiplier is drawn at `x1.0` for
the same reason — hiding it until tier 1 means the player meets it for the first
time in the middle of a fight.

| | |
|---|---|
| Origin | x `0.031` (40), top y magic bottom + 4 px (678) |
| Bar | `0.44 ×` health width (151 px) × 6 px |
| Fill | dim cold, MOTH at Warm, GOLD from Hot, breathing toward BONE at Blazing; RUST for 350 ms on a break |
| Multiplier | 10 px, bar right + 22 px, centred on the row, in the fill's colour |

### 5.1e The draught row — slots, not a meter

The last row of the pole, and the only one that is **not a bar**. Two slots
today, one per draught that has a clock, in `PotionDb.IDS` order and fixed by
kind forever. Each slot is a VOID-hairlined ASH@60% track holding a **mark** on a
VOID chip — identity, a shape — and **four tiles** that go out one at a time —
time, a count.

Three rules, each of which replaced something that had shipped:

1. **It is drawn when it is empty**, per §5.1d. It used to draw nothing at all
   until the first draught was drunk, so the player met the instrument in the one
   moment they had no attention to spare for learning it.
2. **The slots never pack.** Live draughts used to be collected and drawn
   leftmost-first, so a slot's position carried no information — the first slot
   meant Ironhide or Emberblood depending on what else happened to be running.
   Fixed slots make position the identity channel and colour the redundant one.
3. **It is not a meter, and that is why it is tiles.** `heart_draught`'s tint is
   `(0.88, 0.25, 0.22)` and `Pal.VITAL` is `(0.878, 0.251, 0.220)`;
   `ironhide_draught`'s is `(0.35, 0.47, 0.78)` and `Pal.COBALT` is
   `(0.345, 0.471, 0.784)`. To the precision this palette is written in, a
   draining tinted bar in this column *is* the health bar's colour and the magic
   bar's colour repeated 12 px lower — a false readout, not merely a legibility
   risk. Four discrete steps is what §7.4 permits where it bans a lerp, and a row
   that empties in steps is visibly not one of the bars above it.

**Heart Draught has no slot**, because `PotionDb.apply` sends it to `Game.heal()`
and never to `Game.start_draught` — a third slot would be a container that can
never fill. The row is derived from which draughts have a clock, so it grows by a
slot the day a third one is brewed, with no edit to `hud.gd`.

| | |
|---|---|
| Origin | x `0.031` (40), top y heat bottom + 4 px (688); **heat's own slot (678) in the garrison, where heat is not drawn** |
| Row | `0.44 ×` health width (151 px) × 6 px, slots split evenly with a 4 px gap |
| Mark | 6 × 6 chip, VOID @85%, shape inset 1 px: ■ Ironhide (a plate), ▲ Emberblood (a point), ✚ reserved for a Heart Draught given a clock |
| Tiles | 4 per slot, 2 px apart; lit in the draught's tint, spent as a VOID @30% notch |

### 5.2 The hands — left and right, beside the item

**Superseded 2026-08-08: this was a fixed four-cell kit strip (sword, shield,
hookshot, bow) and is now two cells, the hands.** The strip was a lie by the time
the loadout landed — it drew four items you always had, in a game where you find
the hookshot and the bow, and where the right hand can hold any of them. Two
cells that say *what he is holding right now* is the same pixel budget spent on
a fact that changes.

Two cells in the bottom-left cluster, immediately left of the item cell and
sharing its top edge. No radial, no wheel. **Left cell is the left hand,
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

### 5.2b The item cell, and the carets that say what cycles

**Superseded 2026-08-09: this was four bindable cells in the physical shape of
the D-pad — ▲ above, ◄ ► below, a ▼ caret under the cross — and it is now one
cell.** The cross was a picture of a control that no longer exists: the D-pad
binds nothing, it *steps rings* (`docs/CONTRACT.md` §4.1), so four cells drawing
"what you put on each direction" were four cells drawing a lie. What replaced it
is the third cell in a row of three: **[left hand] [right hand] [selected item]**,
all `Pal.CELL` = 64 reference px, all sharing one top and one bottom.

**THE CARET RULE, and it is the whole cluster's grammar:** a caret ABOVE a cell
is the D-pad direction that cycles that cell. **← →** sit over the right hand,
**↓** sits over the item, and nothing else in the cluster draws a triangle — so a
triangle always means "a direction changes this". The band above the cells is
`CARET * 2 + CARET_GAP` tall and every cell is pushed down by it whether or not it
has a caret, which is what keeps the tops in a line.

The right hand's carets are drawn **always**, even when the player owns nothing
but the sword. A ring of one is still the ring, and a caret that only appears the
moment you pick up a bow is a control the player has to notice arriving — the
question the old bindable cross answered loudly ("which direction is my bow on?")
would come back as a quieter one.

**↑ is a line of text, not a cell.** Under the cluster, right-aligned on a
MIDNIGHT @80% plate: `↑ PRIMARY` or `↑ ALTERNATE`. A set is not a thing with an
icon — it is which pair of hands you are looking at — and the two cells above it
already show it. It is plated because it sits over the world with nothing else
behind it, and it uses a thin `↑` rather than ▲: neither is in Cinzel, both
arrive from the system fallback, and the solid triangle looms over the word
beside it at cap height.

**Only the item cell carries a key cap that fires it** — `X`, read from the live
`InputMap` like every other cap (§5.2). The hands are not fired from the cluster;
the shoulders do that, and a cap on the sword cell would be claiming a button the
sword shares with whatever you draw.

The cluster is laid out **from its left edge and up from its baseline**
(`Pal.CLUSTER_LEFT`, sharing `HEALTH_ORIGIN.x` so the HUD has one left edge and
not two; `Pal.CLUSTER_BOTTOM` is the baseline of its last row, clear of health at
`0.899`). Both anchors point at the corner it is in — the six-cell version of
this cluster once overflowed the screen because it was laid out from the edge it
was *not* anchored to. Anchor the thing that must not overflow.

Growing **upward** from a bottom baseline is also why `Hud._cluster_top` makes no
allowance for the caret band above the cells. Top-anchored, a caret drawn above a
cell would have gone off the frame and the origin had to reserve it; from the
bottom the band extends into empty screen.

| | |
|---|---|
| Cross origin | x `0.031` + two cells + gutter, baseline y `0.872` |
| Cell | 34×34 px, 6 px gutter |
| Fill | MIDNIGHT @80%, 1 px ASH border |
| Drawn now | 2 px BONE border on the cell holding the item currently in hand |
| Ammo numeral | 16 px MOTH on a bound bow, right-aligned inside the cell |
| Swap caret | 10×5 px ASH triangle, centred under the ▲ column |

### 5.3 The bag — the most important object on screen

Bottom-right, right-anchored at x `0.969` (1240). **One rectangle with three
things in it, and not a single figure anywhere.** HUD_PLAN decisions 14, 17, 26
and 33; `Hud._draw_bag`.

The number this section used to open with is gone. It was 32 px, it rolled up on
every pickup, and it was the most-read thing on the screen — which is the case
against it. A player watching a running total is doing bookkeeping in the middle
of a dungeon, and the extraction decision degrades from *is this worth the walk
back* into *has the number gone up*. The figure did not disappear; it moved to
the pouch and the vendor's counter, which is where you go to think about money.
What is left out here is the part that is about **risk** rather than arithmetic.

1. **The rim.** A frame from `(0.812, 0.786)` to `(0.969, 0.914)`, coloured by
   the rarity of the single most valuable thing you carry. Silent, permanent,
   peripheral — it is how the bag whispers. **Rarity is a thickness as well as a
   hue**, because the pair this has to separate hardest is MOSS `68a050` against
   MOTH `807868`, mid-green on mid-khaki at near-identical luminance and the
   textbook deutan collision: 2 px common, 2 px with an inner rule uncommon, 3 px
   rare, 3 px with a dithered inner ring legendary. Four weights, four hues,
   either channel sufficient on its own.
2. **The slot marks**, along the rim's bottom inside edge. One mark per bag slot:
   the first `Run.CASE_SLOTS` at full height (8 px), the rest at half. The case
   is the part you keep when you die, so *what does the case save* and *how full
   am I* are one row read two ways — and again that is a **height**, not a hue.
   Unused slots draw as ASH notches rather than as nothing, or a half-full bag
   and a small bag look identical. The count is read from `Run`, not hard-coded:
   the player buys slots, and `mvp_loop` is at 13 by the second shop.
   **This is what the empty rim was missing.** A rim with nothing in it is a bare
   rectangle in the corner for the whole first half of a run, and an instrument
   that only appears once you are already doing well teaches nobody.
3. **The value stack**, sitting on the marks and growing upward. Up to 8 slips,
   4 px tall, 2 px gutter, max width `0.094` of the screen, coloured by rarity
   tier with 0–3 hairline notches cut into the **left** end — the end that moves.
   Width is that stack's share, normalised **to the largest stack, not to the
   bag total**: against the total, eight roughly-even stacks are eight 14 px
   stubs and the histogram says nothing. The 9th and beyond collapse into `+N`
   in MOTH at 10 px. This is a value histogram, not an inventory list — the
   useful thought is "most of my money is that one violet slip", and no list
   gives you that in a glance.

Every one of those three derives its geometry from the rim rect. There is no
second anchor for the slips and none for the marks; `Pal.SLIPS_BOTTOM` was one
and it drifted 3.5 px outside the rim at eight stacks before the layout
assertions caught it (HUD_PLAN §15.5).

**When a drop lands:** a 1-frame full-rim fill in the drop's rarity colour, a new
slip appearing while the others re-proportion, and a 16 px item-name toast
right-aligned at baseline y `0.767` in the rarity colour, holding 1.6 s then
fading over 200 ms.

**As the bag gets valuable** — thresholds T1/T2/T3 at 250 / 1000 / 3000:

- T1: nothing out here. The tier is real but it is the *quietest* one, and it is
  legible in the pouch.
- T2: a 1 px dithered GOLD halo 2 px outboard of the frame, **and
  `fog_light_color` lerps 8% toward GOLD**. The dungeon warms up because you are
  rich in it. The halo is about VALUE and sits outside the frame; the legendary
  ring is about RARITY and sits inside it, so both can be on screen and still be
  two sentences.
- T3: the **slips** breathe in brightness at 0.5 Hz. It moved off the frame,
  where the T3 breath was specified and where it was invisible under 2 px of
  everything else. It is the one Tier 3 element allowed to move, and it moves
  only at T3.

**Every hit you take triggers a 2-frame GOLD flicker on the rim** — the game
reminding you what is at stake at the exact instant losing it becomes possible.
Underground only; in the garrison there is nothing at stake to remind anyone of.

**Six things want this one rectangle**, so they are ranked (decision 33), and the
order is written down because at T3, holding to extract, with a legendary in the
bag, taking a hit as a drop lands, all six are true at once:

> hold > drop flash > damage flicker > T3 breath > T2 halo > rarity

The hold wins outright and suppresses the rest for its whole duration: it is the
only one driven by a button the player is holding down right now rather than by
state, and a CYAN sweep under a gold halo and a rarity ring is unreadable.

**On death the bag does not just vanish.** `Bus.run_ended` carries the contents
and the value, and `scripts/ui/run_end/run_end_screen.gd` itemises what was lost.
The receipt is somewhere you have *stopped*, which is the same argument as the
number's: the loss is worth watching, and the corner of a live dungeon is not
where you watch it.

### 5.4 Extraction affordance

**Nothing standing.** There is no `EXTRACT <charge>` line, and the y `0.940`
baseline it sat on is gone from the layout. A figure pinned to the corner of the
screen gets read constantly, and a player watching the fee tick is doing
bookkeeping in the middle of a dungeon instead of playing one — the same reason
the 32 px bag total went (§5.3). Two numbers there was worse than one: a pair
invites arithmetic.

The fee is not hidden, it is *somewhere you have stopped*. The pouch says it in
words ("The rope wants 36 and you have 26. It will take all of it."), the rope's
verb meta carries the charge, the pause menu's **Way out** row names it, and the
receipt says what was paid. Everything below is an EVENT, not a readout.

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
    draws nothing, so an unlit room keeps its secrets (`docs/GDD.md` §4,
    pillar 5) and a bar never spoils an ambush.
  - **Only in line of sight**, by a raycast from the camera against world
    geometry. A bar anchored in the world obeys the world; without this the
    feature is an x-ray that reads monsters through walls.
  - **Only within 22 m.** Past that a 20 px bar is a smear, and a floor of smears
    is the icon vomit this section exists to prevent.

  Positions quantize to the 480×270 grid like the brackets, and the fill **never
  eases** — anti-slop §7.4 stands.
- Off-screen locked target: an 8 px RUST chevron on the screen edge at the
  target's bearing, inset `0.028`.

### 5.5b The minimap — line art, and only underground

A 148 px square, top-right, VOID @88% on a 1 px ASH border. Drawn by
`MapDraw.draw_map` — the **same** routine that fills the pause menu's MAP tab,
called with a smaller box. There is one map in this game; see
`docs/CONTRACT.md` §8, "The map".

**It is a schematic and never a rendered camera.** Room outlines, corridors, a
gap in a wall where a door is, and one small symbol per thing worth walking to.
A top-down render of the floor is a picture of the same masonry the player is
already looking at, it cannot do fog of war without a second visibility system,
and it is not line art.

- **It only exists underground**, and only once at least one room is off the fog.
  In the garrison there is no floor and the corner is empty — an empty corner is correct,
  not a gap to fill.
- **Fogged rooms are not drawn at all.** Not greyed, not outlined: absent. The
  map is fitted to the whole floor's bounds so it does not re-scale as it fills
  in, which means the blank space IS the information.
- **A corridor to a room you have seen is drawn whole; one to a room you have not
  is a stub** that stops short of it. A promise that there is more that way, and
  no claim about what.
- **The room you are standing in draws a heavier, brighter outline** (2 px BONE
  against 1 px MOTH). That is the "you are here" that survives at this size — the
  hero arrow is 5 px and reads as a dot from a normal seat.
- **The hero is a BONE triangle over a darker one**, at his real position inside
  his real room, pointed by `-basis.z` and never by `rotation.y`
  (`docs/CONTRACT.md` §2.5). The backing triangle is the same trick the enemy
  bars' frame uses: the marker has to survive being over a lit floor fill, over a
  gold chest glyph, and over the VOID outside the rooms.
- **Markers are drawn shapes, not icons.** Chest = GOLD box with a VOID lid band
  and a hasp. Stair = three CYAN treads descending (CYAN is the way out and
  nothing else — §2 — and the stair down is the way on). Arrows = MOSS broadhead.
  Entrance = a hollow MOTH ring, hollow because it is the one marker that is a
  landmark rather than something to go and get. At 6 px a baked render of a chest
  is four brown pixels; a gold box with a lid is a chest.
- Lines are `draw_rect`, not `draw_line`. At 1–2 px `draw_line` lands on half
  pixels and comes out soft, which is the treatment collapsing (§1).

The one glyph set this project did NOT use: `~/valenfeld`'s map icons. They are
256 px painterly round world-map POI tokens in a warmer palette, they are
illegible at 6 px, and the set contains no chest and no staircase — the two the
map most needed.

### 5.6 Always visible vs. transient

**ALWAYS — seven things, nothing else:** the health bar, the stamina bar, the
hands, the item buttons, the bag (rim and slips — no total), ammo numerals, and
— underground only — the minimap. Each is a number or a binding the player must
be able to consult unprompted, because each feeds the single recurring decision
— push on, or leave. The minimap earns the seventh slot on that same test: how
far from the stair you are is the other half of "can I afford one more room".
Anything that does not feed that decision has no claim on permanent pixels.

This list has *shrunk* twice, both times by deleting a figure: the bag total
(§5.3) and the extraction line (§5.4). Both were the most-read things on the
screen, which is exactly what was wrong with them — a running number turns the
recurring decision into arithmetic. The money still gets said, in the pouch and
at the counter, where you have stopped to think about it.

**FADES IN:** item toasts; lock-on brackets and target health; the extraction
promotion and sweep; the room name card (Jacquard 24 @24 px, BONE 30%, centre
x `0.5`, baseline y `0.139`, 1.4 s on room entry); damage-direction arc (3 px
RUST, 40°, radius **`0.42h`** about centre, 300 ms, camera-relative bearing with
0° at the top and clockwise — one arc, a second blow replaces it); interaction prompts; gold
floaters; **and the garrison control legend** — 0.6 s in, 10 s, 0.6 s out, on
three moments only: the overlay coming up in a garrison, a device change, and a
run ending. It is the largest block of text on the HUD and it feeds nothing about
push-on-or-leave, so it has no claim on permanent pixels; the permanent reference
is Options → Controls. Picking up a pad is the re-show that matters, because that
is the instant every cap in the player's head goes wrong.

**NEVER:** quest text, objective markers, floating damage numbers, an XP bar.

**Superseded 2026-08-09, on the owner's instruction: this list began "a minimap"
and there is now one in the top-right corner (§5.5b).** The old argument was that
a corner minimap trains the player to navigate by abstraction, which destroys
fog-as-draw-distance as a tension device outright. That argument is still true of
the minimap it was written about — a rendered top-down view of the floor around
you, updating live, showing rooms you have not entered. It is not true of the one
that got built, and the difference is the whole design:

- **It shows only rooms you have stood in.** It cannot tell you what is ahead,
  because it does not know. Fog-as-draw-distance is intact: the map is a record
  of where you have been, not a preview of where you are going.
- **It is a schematic, not the floor.** Boxes and lines. Nothing about a room's
  contents, its light, or what is in it beyond one symbol for the chest.
- **It is fitted to the floor's full bounds**, so the blank space says how much
  is left without saying anything about what is in it.

What it buys is the thing a room-based dungeon with a fee for leaving actually
needs: "which way is the stair, and have I already been down that corridor". The
`map` action (M / Tab / L3) opens the same plan larger, on a paused tab of the
pause menu, with a legend.

### 5.7 Anchor table

Fractions of viewport, origin top-left; px at 1280×720. **Replaced entire by
`docs/HUD_PLAN.md` §8**, which is where the reasoning for each row lives; this is
the table itself, kept here because §5 is where an implementer looks.

`display/window/stretch/mode` is `canvas_items` and `stretch/aspect` is `keep`,
so the canvas is 1280 × 720 in every build on every display and letterboxed into
an exact 16:9 box. Every fraction below resolves to exactly one set of pixels,
forever, and nothing is ever cropped.

Safe area: x ∈ [0.025, 0.975] (32 … 1248), y ∈ [0.031, 0.969] (22 … 698).
`tools/directors/_hud_layout.gd` asserts it on every captured frame — this table
is checked now, not merely written down.

#### The vitals pole — one left edge at x 0.031 (40); rows from `_pole_top` only

| Row | Element | top y | h | w |
|---|---|---|---|---|
| 0 | Health bar | 0.882 (635) | 15 | 0.268w (343) |
| 1 | Stamina bar | r0 bottom + 4 (654) | 8 | 0.62× (213) |
| 2 | Magic bar | r1 bottom + **6** (668) | **6** | 0.52× (178) |
| 3 | Heat bar (dungeon only) | r2 bottom + 4 (678) | 6 | 0.44× (151) |
| 3′ | Heat multiplier | bar right + 22 | 10 px, centred on r3 | — |
| 4 | Draught slots (2, one row) | r3 bottom + 4 (688); **r3's slot (678) in the garrison** | 6 | 0.44× (151) |
| — | pole bottom, dungeon | 694 | — | 4 px inside the safe margin |

The 15 / 8 then 6 / 6 / 6 break is decision 24 and it is the whole reason the
pole reads as two instruments: Tier 1 is read mid-fight without moving your eyes,
Tier 2 is glanced between beats, and before this the only thing separating them
was hue — the one channel a colour-blind player does not have.

**`Hud._pole_top(s, row)` is the sole expression for this column.** Do not write
the stack sum anywhere else; a second one put the draught row through the magic
bar in the garrison and four pixels into the heat bar underground.

#### The control cluster — same left edge, laid out upward from `CLUSTER_BOTTOM`

| Element | x | y | Size |
|---|---|---|---|
| Cluster baseline | — | 0.855 (616) | — |
| Caret band | above every cell | 490 → 511 | 21 tall (8·2 + 5); `CARET` is a HALF extent, so 16×16 triangles |
| Left hand cell | 0.031 (40) | 511 | 64 × 64 |
| Right hand cell | + cell + 12 (116) | 511 | 64 × 64; ← → carets over this one always |
| Item cell | + cell + 22 (202) | 511 | 64 × 64; ↓ caret over it |
| Ammo / charge numeral | cell right − 3 | cell bottom − 3 − its own height | **10 px** BONE |
| Key caps | centred under each cell | cell bottom + 4 (579) | 14 px on the cell plate |
| Loadout line | right-aligned to the item cell (266) | caps bottom + 9 (602) | 14 px on the cell plate |

#### The money pole — one right edge at x 0.969 (1240)

| Element | x | y | Size |
|---|---|---|---|
| Value slips | right-align 0.969, max w 0.094 (120) | bottom 0.845 (608), stacking up | 4 px + 2 gutter, ≤ 8 |
| Slip overflow `+N` | right-align 0.969 | above the last slip | **10 px** MOTH |
| Bag rim | 0.812 → **0.969** (1039 → 1240) | 0.786 → 0.914 (566 → 658) | 2 px (3 px at rarity ≥ 2) |
| Item toast / autosave | right-align 0.969 | 0.767 (552) | 16 px toast / 14 px autosave |
| Extraction hold | **the rim itself** | — | the rim's own frame redrawn CYAN, clockwise from the top-left |

The rim's right edge was 0.978 — 5.8 px outside the safe margin, on the largest
permanent element in the corner. It is `Pal.BAG_RIGHT` now, the same edge as the
slips, the toast and the minimap: snapping it to the safe margin was never the
point, and a fourth right edge is what made the column read as ragged.

#### Top edge

| Element | x | y | Size |
|---|---|---|---|
| Floor card | 0.031 (40) | 0.052 (37) | name 10 px over level 16 px, world plate fading 72% → 34% |
| Minimap frame | right-align 0.969 (1240) | 0.052 (37) | 148 × 148, 8 px pad, VOID@88% on 1 px ASH |

#### Centre and full-screen

| Element | x | y | Size |
|---|---|---|---|
| Crosshair | screen centre, quantized to 480×270 | " | gap 7 (5 locked), arm 5, 1 px |
| Interact prompt | centre 0.500 | 0.735 (529) | 14 px on the world plate, pad **6** |
| Prompt hold gauge | inside the plate | the plate's bottom edge | `HoldGauge.BAR_H` |
| Extraction sweep | 0.0 → 1.0 | 0.500 | 1 px CYAN, 200 ms |
| Legend (garrison, **transient**) | left edge derived from the vitals pole's right + `KEYS_GUTTER` | up from 0.942 (678) | **4 balanced rows**, step 15, 10 px BONE on a `PLATE_WORLD` plate |

#### World-anchored (these obey the world's rules, not the frame's)

| Element | Size |
|---|---|
| Lock brackets | half-extent (26, 34), arm 8, 2 px, quantized to 480×270 |
| Enemy health bar | 20 × 2 px (×2.2 locked), 1 px frame (BONE if elite), ASH@85% track, RUST fill, ≤ 22 m, LOS-gated |

#### Rows deleted from the old table, and why

| Row | Why |
|---|---|
| Bag numeral baseline (0.900) | The 32 px gold total was deleted 2026-08-09. It went on anchoring the extraction ring for a year afterwards — a ring around a number that was not there. `Pal.BAG_NUM_BASELINE` is gone with it. |
| Extraction hold ring (r 54) | It is the rim's own frame now. A widget and an anchor deleted rather than moved. |
| Room name baseline (0.139) | Replaced by the top-left floor card, which anchors off its own constants. `Pal.ROOM_NAME_BASELINE` gone. |
| Slips top (0.803) | The stack grows UPWARD from its bottom; the top is derived from the count and was never authored. `Pal.SLIPS_TOP` gone. |
| Heat premium baseline (0.735) | The premium is drawn beside the heat bar in the vitals pole, where a state of the body belongs. `Pal.PREMIUM_BASELINE` gone. |
| Damage arc | **Built, at r = 0.42h.** `0.28h` passes through x 438–842 and y 158–562 — straight across the middle third §2 rule 1 keeps empty for the fight, on a HUD that has since gained a prompt and a crosshair there. `Feel.damage_vignette` is deleted and `Feel` is no longer a `CanvasLayer`; the bearing rides `Bus.hero_struck(from)`. |

#### The two plate recipes

Two, not three, and which one you get is decided by a single question.

| Recipe | Fill | Pad | For |
|---|---|---|---|
| **Cell** | MIDNIGHT@80% | 3 px | anything attached to a cell — the key caps, the loadout line |
| **World** | VOID@72% | 6 px | anything floating over the world — the interact prompt, the floor card |

A plate is how text survives something it does not control. The cell recipe is
the cells’ own fill, so a cap reads as part of the cluster rather than as a label
that landed near it; the world recipe is darker and wider because a lit wall at
this end of the palette is brighter than MOTH, and 6 px is what keeps a descender
off the brick outside the plate at 720p.

---

## 6. Three deliberate departures

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

### Departure 3 — the talking heads are PIXEL ART, in a polygon world

**The norm:** a 3D game shows a 3D speaker — the model you are standing in front
of, framed to the shoulders, sometimes lip-synced. It never disagrees with the
world, and it costs no art.

**What we do:** the dialogue box (`scripts/ui/dialogue/dialogue_box.gd`) draws
hand-made pixel-art busts, one per person, over the live courtyard. That is a
deliberate register change and the only place in the game where one happens: two
drawn faces in a polygon frame, the same way a JRPG cuts from its field map to a
portrait. It sits with §3.0's split rather than against it — the world is PSX,
and everything *addressed to the player* is allowed to be legible.

**Why it serves this game:** the garrison's five keepers are the whole cast, and
they have to be worth walking back to. The rigs could hold a pose but not an
expression — the first cut of this box put a mannequin with its arms out beside
every line of dialogue in the game. The drawings have eye contact. The rule this
breaks is a real one and the trade was made once, on purpose; it is not licence
for 2D art anywhere else.

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
- `scripts/ui/menu/_build_theme.gd` and `scenes/ui/menu/menu_theme.tres` were
  the SystemFont theme §3.0 replaces. **They are deleted.** `PauseMenu._ready`
  puts `UITheme.theme()` on Root and every panel inherits it; there is one menu
  theme in this project and it is built in code.

  On the kit: the paper doll and its slot tiles; the pause menu's ROOT
  screen (plate header, a live stat band, and `VerbRow`s with a meta column,
  replacing eight identical full-width buttons); and all five counters, which
  are one screen — the pawnbroker, the smith, the alchemist, the setting bench
  and the Far Lantern (`TradeScreen`); and the footlocker (`StashScreen`), whose
  refusal moved off the hint line and into a `FooterToast`, so "← STOW
  RETRIEVE →" no longer vanishes at the moment a refused transfer has the player
  hunting for it; the Items screen (`EquipPanel`), whose three columns are
  divided by `section_rule` rather than nested cards — three `style_panel`
  cards' worth of 22px margins pushed the frame past `MenuUtil.FRAME_SIZE` and
  it silently filled the viewport; and the pouch (`MenuPouchPanel`), where the
  header's one right-aligned string became a four-cell `StatBand` — SLOTS, BAG,
  PURSE, TO LEAVE — so the extraction decision is four numbers read at once
  instead of a sentence parsed, with the fee no longer stranded two feet from
  the purse it is measured against; and the map (`MenuMapPanel`), whose floor
  label and "6 of 8 rooms walked" subtitle became a four-cell band of their own
  — FLOOR, ROOMS, CHESTS, STAIR — counted off the same `Atlas.marks` the plan
  is drawn from, so the numbers cannot claim a chest the map is not showing;
  the save/load screen (`MenuSavesPanel` + `MenuSlotRow`), where an empty slot
  in LOAD mode is the refusal law rendered on a card rather than a row — 38%,
  "Nothing here to load." at full DANGER, and still in its place; and the one
  modal (`MenuConfirm`), which carries the kit's paint itself rather than
  inheriting Root's, because it is raised over converted and unconverted
  screens both and a modal that changes face depending on who asked is a modal
  the player stops reading; and Options, with its four tabs on the kit's one
  underline voice, `section_rule` for every group heading, and the slider,
  choice and bind rows on the shared row plate (`UiKit.style_row_button` →
  `VerbRow.row_box`, so a settings row and a verb row are the same plate by
  construction); and the receipt (`RunEndScreen`), the last one — its verdict is
  a `PlateHeader` whose title carries the ending's own colour (`title_color`,
  the one sanctioned tint on a headline: VITAL for "You Died", CYAN for
  "Recovered"), the killer line sits under it, and the four-row stat tally
  became a band — ROOMS, SLAIN, FEE, STACKS. The two loot columns kept their
  captions as coloured Labels rather than `section_rule`s, because "WHAT THE
  FLOOR KEPT" and "THE CASE BROUGHT HOME" are told apart by colour and a rule
  paints both the same.

  The last thing off the old theme was not a panel at all: the REBIND overlay
  in `PauseMenu._build_listen_overlay`, which wore `MenuFrame` / `MenuList` /
  `MenuTitle` / `MenuHint`. It is a `hover_card` now, the same face `MenuConfirm`
  wears, because it is the other thing this menu RAISES over a screen rather
  than being one, and two raised surfaces with two faces is two modal languages.

  What survives of the old theme is five names — `MenuSlot`, `MenuSlotStat`,
  `MenuValue`, `MenuHeading`, `MenuMuted` — redefined in kit tokens by
  `UITheme._style_shared_cells`. That is not leftover scaffolding: it is now the
  ONLY definition of those names, and it is what keeps `ItemCell` and
  `UpgradeLadder` painted without editing them. The item menu is the one screen
  the owner asked us not to touch, so the cells kept their code and changed only
  what they render through.

  Two things were AUTHORED for that, not ported — valenfeld has no settings
  screen and so no answer for either. `UITheme._style_sliders` gives HSlider a
  hairline groove, a spent-run fill and an off-white stone nub; note the nub is
  an **icon**, not a StyleBox, which is the one theme item on Slider that is a
  Texture2D — a StyleBox handed to `grabber` is silently ignored and you inherit
  whatever ancestor theme still has an icon for it. And `VerbRow.row_box` is now
  public, because a row that owns an HSlider is not a composition the kit can
  build, but it is the same PLATE, and a settings row painted a second way puts
  two row voices on one screen.

  The pouch's Fletch and Escape Rope rows are the documented exception to the
  refusal law: they use `UiKit.verb_meta` to write the shortfall into the meta
  column and stay FOCUSABLE, rather than `VerbRow`'s `refused` state, which is
  not. This screen answers "what am I short of" in the detail pane, and a row
  you cannot focus is a pane you cannot open.

  The bag grid — `ItemGrid` / `ItemCell` — is NOT on the list; it stays as it
  is. What it renders THROUGH moved, though: `MenuSlot`, `MenuSlotStat`,
  `MenuValue`, `MenuHeading` and `MenuMuted` are defined in `UITheme.theme()`
  now (`_style_shared_cells`), painted in kit tokens, so a shared cell looks the
  same on a converted screen and an unconverted one. That bridge only ever
  shrinks — do not add names to it to avoid writing a composite.
