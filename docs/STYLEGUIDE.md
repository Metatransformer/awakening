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

**One exception, and it is the dialogue option list.** `DialogueBox` contains
two genuinely different kinds of choice and must show the difference. A
service or menu entry is navigation: give it the service icon and a chevron. A
dialogue topic remains a dialogue/read choice, without service chrome. Do not
flatten both kinds into identical Trade/Leave rows, and do not promote a topic
merely because it is first. If you add a new list of things a character says,
its topics stay in one face.

Retired in the same change, and not to be re-added without a reason written at
`UITheme.BODY_TTF`: **Alegreya** (the variable serif that was the display face —
Cinzel does that job now, and two serifs on one panel is drift, not hierarchy)
and **Pixel Operator Bold** (its `keycap_font()` had no callers at all).

The HUD is on the same two faces. `scripts/ui/canvas_text.gd` paints
`UITheme.display_font()` onto a CanvasItem for everything drawn rather than
typeset — the vitals, the floor card, the key caps, the world prompts. Until 2026-08-10 that file was a 5×7 bitmap of its own, which made the
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
| **10** | ammo / charge numeral, bottle count `n/m`, slips `+N`, heat multiplier, floor name |
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

**A HUD line that does not fit is not shrunk.** There is nothing under 10 px, so
a line too wide for the safe area has too many entries on it, not type that is
too big — and shrinking could not work anyway: `CanvasText.size_of` clamps the em
at `MIN_SIZE`, so past a point the scale keeps falling while the glyphs do not,
and the line renders *wider* than the width it was asked to fit. Break between
entries and balance the rows.

The rule was written about the garrison control legend, which is deleted (card
#121, 2026-08-12). It outlives it: every one of the 10 px labels above is a line
whose width is set by its content, and the answer to any of them overflowing is
fewer entries.

**The 10 px floor became load-bearing on 2026-08-11** (card #55) and it is worth
knowing why. Every HUD frame judged before that date was rendered at 6880 × 2756
and downscaled into the PNG, so a label authored a size too small still came back
crisp — a ~20× supersample was quietly rescuing it, and it will not be there in
the shipped build. Captures are 1:1 now. Type was re-checked at 3× nearest zoom
at 720p under the new harness and is fine as it stands: Cinzel's serifs survive
at 10 px and the floor card's name line is fully legible. But there is no longer any
margin under the floor, and no viewport AA setting can add one — §4.8 measured
this: the HUD canvas is *pixel-identical* under MSAA, FXAA, TAA and `msaa_2d`
alike. Font rasterisation is the only antialiasing 2D type will ever get, so the
answer to an illegible label is fewer entries or a bigger size, never a knob.

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
- **If it is billboarded, it was interface all along — draw it on the canvas.**
  This is the criterion, and it is greppable: `billboard = BILLBOARD_ENABLED` on
  a `Label3D` says the text turns to face the player, which is a thing no object
  in a world does. A carved sign does not turn. §4.5 renders the world at
  480 × 270 and a `Label3D` goes into that buffer with the masonry, so a
  billboarded caption gets 5.25 px of type where §3.1b's floor is 10 and no
  font size fixes it — the buffer, not the glyph, is the limit. Making it big
  enough to survive would put a plate the size of a road sign in the courtyard,
  which §5.5b and §7.10 both refuse for the same reason.

  `scripts/ui/world_caption.gd` is the answer: a `Node3D` that carries text and
  a world position, drawn by `Hud` at native resolution through the same
  `unproject_position` the enemy bars and lock brackets already use (§4.5's
  "never reparent the world scene" is what keeps that answering in native
  pixels). Four moved — the keeper's sign, the training-post readout, its damage
  numbers, and the Echo plates. **Three did not**, and they are the honest half
  of the rule: the gatehouse lintel, the statue's inscription and the locked
  door's tablet are cut into their objects, do not billboard, and are *supposed*
  to go soft with distance — `statue.gd` was already asking for that in a
  comment before this card existed.

  A fifth was **born** here rather than moved: the name on a dropped
  `LootMote` (card #123). It never existed as a `Label3D`, and it is written
  down next to the four because it is the first caption authored after the rule
  and it is what says the rule is usable rather than merely true — everything
  it needed was already a property on `WorldCaption`. What it adds is a
  **budget**, which the four did not need: a keeper is one of a handful in a
  yard, and a cleared floor holds a dozen motes. `LootMote.NAME_RANGE` (4.5 m
  from the hero) and `LootMote.NAME_MAX` (three, nearest first) are that
  budget, and §7.10 is why there is one. `tools/directors/loot_names.gd` proves
  all three claims at the game camera.

  What it costs, said out loud: a canvas caption **does not shrink with
  distance** (the range gate in `WorldCaption.opacity_at` is a clutter limit
  now, not perspective), and occlusion is one LOS ray for the whole caption
  rather than per-pixel depth — a wall edge can no longer cut a name in half.
  `TrainingPost.POPUP_CLEAR` keeps its placement job and loses its clearance
  one. The deeper price is a sentence about the world: a name over a booth is
  now interface *about* a thing rather than a thing. That is the trade §4.5
  forced, and it is **this session's call, made while the repo owner was asleep,
  and REVERSIBLE** — one class swap per caption.

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
a noise dither over the whole frame and it fights ours pixel for pixel. It is set
on the internal SubViewport in code (`screen_present.gd`) rather than in
`project.godot`, which is orchestrator-owned.

**Where it runs, as built (2026-08-11, #58):** in the *present* pass, in
`assets/shaders/present_psx.gdshader`, alongside the sharp-bilinear filter — one
pass, not two. The cell index is read off `UV * src_size`, so one Bayer cell is
4 × 4 **internal** pixels exactly as this section demands; the present pass is
the last place in the frame where "one internal pixel" is still a knowable
quantity. Do it after the upscale and each cell covers 2.67 output pixels at
720p, which is the grain overlay this section spends a paragraph refusing.

The HUD is quantized to RGB555 but **not dithered** — it is authored in palette
colours already, so dithering only adds mush. *Not built:* the HUD is drawn on a
canvas layer above the present pass and is not quantized at all today. It is
authored in `Pal` entries, every one of which is already on the RGB555 grid (§2's
multiple-of-8 rule), so the quantizer would be a no-op on everything except the
alpha blends of the plates — which is why this is a note rather than a card.

### 4.5 Internal resolution and upscale

> **BUILT 2026-08-11 (card #58), and it is now OFF by default.** The pipeline
> below is real and still works — the SubViewport, the sharp-bilinear present and
> §4.4's quantizer are all in `scripts/core/screen_present.gd`. It shipped ON for
> a day, made while the repo owner was asleep, and the owner turned it off on
> 2026-08-11: `Settings.internal_render` now defaults to `false`, so the game
> renders at the window's resolution as it did before #58. Everything below
> describes what you get by setting that field back to `true`; nothing else in
> the project branches on it, and the directors that want §4.5 (`frame_repro`,
> `fog_crawl`, `internal_res`, `msaa_clamp`) each turn it on themselves.

3D SubViewport at **480 × 270**, fixed. (PSX was 320×240 = 76.8k pixels;
480×270 = 129.6k, the smallest buffer where an over-the-shoulder camera can still
resolve an enemy wind-up at 9 m, which is the lock-on acquisition range.)

`msaa_3d = DISABLED`, `screen_space_aa = DISABLED`, `scaling_3d_scale = 1.0`,
`use_hdr_2d = false`, `use_debanding = false`, `texture_filter = NEAREST`.

Present with **sharp-bilinear**, not raw nearest and not integer-only. Raw
nearest at a non-integer scale (720p is 2.67×) shimmers on every camera move;
integer-only forces pillarboxing at 720p.

```glsl
vec2 px = UV * src_size;
vec2 fl = floor(px) + 0.5;      // the texel centre this fragment is inside
vec2 d  = px - fl;              // −0.5 .. 0.5, in texels
vec2 w  = max(fwidth(px), vec2(1e-6));   // texels crossed per OUTPUT pixel
vec2 r  = max(vec2(0.5) - w * 0.5, vec2(0.0));
vec2 uv = (fl + (d - clamp(d, -r, r)) / w) / src_size;   // sample LINEAR
```

**Those are not the four lines this section used to give, and the old ones did
not work.** They read
`uv = (fl + clamp(px - fl, -0.5, 0.5) / fwidth(px)) / src_size` — the clamp
applied *before* the divide, where it can never fire, because `px - fl` is
already inside ±0.5 by construction. The divide then scales it to ±1.33 texels
at 720p, which walks the sample past the *next* texel's centre and blends two
neighbours the fragment is not inside. It does not sharpen; it smears, doubled.
The clamp has to act on the already-divided distance — equivalently, on `d`
against a region that shrinks by half an output pixel, which is the form above.
It is the Retroarch/Themaister sharp-bilinear, and this is the first time anyone
compiled it here.

The present sampler is **LINEAR**, which is not a contradiction of the `NEAREST`
in the list above. Sharp bilinear *is* a bilinear tap: the shader snaps the
sample to the texel centre and lets it cross the boundary over exactly one output
pixel, and it needs the hardware blend to do that. Set the present rect to
NEAREST and the shader degenerates to raw nearest, which is what this section
rules out. `NEAREST` governs the SubViewport's own 2D and the world's materials.

#### How it is built, and the one thing not to do

`scripts/core/screen_present.gd`, instanced by `Settings` (it has no `[autoload]`
line of its own — `project.godot` is orchestrator-owned, `docs/CONTRACT.md` §3,
and this needed no edit to it). The SubViewport **shares the root's `World3D`**
and carries a proxy `Camera3D` that mirrors the live one every frame; the root
window gets `disable_3d = true` so the same scenario is not drawn twice.

**The world scene is never reparented into the SubViewport**, and that is the
load-bearing decision. `unproject_position` answers in the *camera's* viewport —
move the camera into a 480 × 270 buffer and every world-anchored HUD widget
starts computing 480 × 270 positions and painting them on a 1280 × 720 canvas:
the lock brackets, the enemy bars, `Targeting`'s screen-space tie-break, `Feel`'s
shake, `hero_ranged`'s aim. Nine call sites, all silent, all wrong by 2.67×.
Sharing the world instead leaves the real `GameCamera` in the root viewport at
native, so every one of them keeps answering in native pixels — which is correct,
because the internal buffer covers the identical rectangle.

#### What it actually looks like

Shot at a true 1280 × 720 with `tools/directors/internal_res.gd`, which
photographs one pose under both pipelines inside one process and composites the
pair. The world is paused across each pair and the flames pinned, or the two
halves are two different moments.

- **The dungeon is the case for it.** At native, the 128 px stone is mipmapped
  and linearly filtered into a soft brown wall — the texel grid §4.7 exists to
  protect is *invisible*, smeared below one screen pixel. At 480 × 270 the same
  wall is a crisp block-pixel wall with the Bayer dither visible in the torch
  falloff. §4.7's mipmaps-ON deviation stops being decorative and starts doing
  the job it was written for. `d_plain_room_zoom.png` is the frame that settles
  this and it is not close.
- **Silhouettes survive.** All five monsters read at 9 m in the lineup
  (`mon_00_lineup.png`) — skeleton, goblin, kobold, orc and wraith are still told
  apart by shape, which is the number this section's 480 × 270 was chosen for.
- **The edges become a decision.** There is nothing left to antialias: an edge is
  a 2.67 px step and reads as intent rather than as a defect. This is the answer
  §4.8 said the edge question was waiting for.
- **The HUD is untouched and it is the whole point.** Cinzel key caps, the 10 px
  legend, the vitals ticks, the minimap's 1 px linework — all pixel-identical to
  the native frame, because they never enter the buffer. `E TO TALK` is crisp
  over a courtyard made of blocks.
- **Departure 3 got louder.** The pixel-art busts and the vellum panel over a
  genuinely chunky PSX courtyard is the register change §3.0 describes, and it
  had been half-invisible while the world was as sharp as the panel.
- **The dither is loud on large flat surfaces and that is correct.** The sky
  above the curtain wall and the shortcut door's flat boards both carry a visible
  4 × 4 checker at 3× zoom — 5 bits per channel across a slow gradient is a lot
  of dithering, and this is precisely what a PS1 gradient looked like. At 1:1 it
  reads as surface texture, not as noise. Do not "fix" it by softening the
  quantizer: §4.4's whole argument is that a *visible ordered* cell is the tell
  that separates a pipeline from a filter.

#### The cost, because a recommendation without one is not a decision

`gpu_ms` reads all-zero on this Metal driver (#55/#20), so this rests on the wall
clock, on the renderer's own CPU submission, and on VRAM.

| Pose (paused, one process, 300 samples) | frame_ms med | cpu_ms | draws |
|---|---|---|---|
| garrison arrive — native | 5.94 | 0.96 | 647 |
| garrison arrive — 480×270 | **5.47** | **0.51** | 650 |
| dungeon, shut shortcut door — native | 9.98 | 3.05 | 1479 |
| dungeon, shut shortcut door — 480×270 | **8.82** | **1.51** | 1480 |
| dungeon, plain room — native | 13.27 | 5.71 | 5254 |
| dungeon, plain room — 480×270 | **11.49** | **2.41** | 4583 |

**The renderer's own CPU time halves, in every pose, every run.** That is the one
number that moves reliably: 0.96 → 0.51, 3.05 → 1.51, 5.71 → 2.41. Draw calls
barely move — the scene is submitted exactly as it was, plus one call for the
present quad — so §4.5 buys almost nothing on the CPU-side *scene walk*, which is
what this project is actually bound by. Where it does move (5254 → 4583 in the
busiest room) it is LOD and shadow culling: `mesh_lod_threshold` is measured in
**pixels**, so a 480 × 270 target crosses it far sooner. Rasterised primitives
fall 23% at 1080p on the same mechanism (236,705 → 183,013). Frame time improves
by ~10% and that is *inside* the noise floor of a Mac running five directors at
once; read the deltas, not the absolutes.

**VRAM at 1080p: 297.0 MB native → 248.1 MB, −48.9 MB.** That is half of what
#55 measured 4× MSAA costing, given back. The saving is only visible across two
*processes*: a build with the field on never allocates the native-resolution 3D
targets at all, whereas flipping the field at runtime leaves the ones already
made, so a paired run reports VRAM unchanged. Card #20's budget is unaffected
either way; this is not a perf change, it is a look change that happens not to
cost anything. **Do not quote #20's median *or its p95* — see the note at §4.8's
budget citation, where #65 struck both on 2026-08-11.** The VRAM figures above
are counts, not timings, and stand — they are the part of this section a pitch
can actually use.

#### What it breaks, and it is one thing

**World-space `Label3D` text is illegible.** `LANTERNKEEPER` over the keeper's
booth, the training post's readout (`1 hit 3 q (0.75 ♥)`) and its damage number
are all 3D geometry wearing a glyph atlas, so they go through the buffer and come
out as noise at anything past a couple of metres. `tools/directors/world_labels.gd`
still passes — it counts pixels, and the pixels are all there — which is exactly
how this would have shipped unnoticed. Carded separately (#61). Nothing the
player must *act* on is affected: the interact prompt, the key caps and every
number in §5 are HUD and stay sharp.

> **FIXED 2026-08-11 (card #61) — §4.3's caption rule below is the answer, and
> the fix was to move four captions onto the canvas rather than to fight the
> buffer.** Measured at 1280 × 720, 1:1: `JEWELCRAFTER` at 3.8 m went from **0.8
> px of cap height to 14.0**, against §3.1b's 10 px floor. The director can now
> fail on legibility instead of on presence — it measures cap height *through
> the rasterisation buffer the caption actually lives in*, so the same file run
> against the pre-#61 build reports three FAILs (0.8 / 3.8 / 4.9 px). This is
> **this session's call and REVERSIBLE**: the four captions are `WorldCaption`
> nodes and the three that stayed are still `Label3D`s, so reverting one is
> swapping a class back, not unpicking a pipeline.

Two things §4.4 asks for that this does **not** do yet: the HUD is not quantized
to RGB555 (it is drawn after the present pass, in palette colours already), and
`Pal`'s dithered derivations are unchanged. Both are cosmetic against the buffer
and neither is worth a second full-screen pass; noted here rather than left as a
silent divergence.

#### The volumetric fog crawls one colour step through it — and it does not read

> **Measured, LOOKED AT, and closed as not a defect — card #66, 2026-08-11.**
> Nothing was changed. This subsection exists so that the next session to run a
> pixel differ over a frozen dungeon finds the answer instead of re-opening the
> question, which is the whole reason the card was worth spending.

**The finding.** Godot's volumetric fog is temporally reprojected with a
per-frame jitter that never converges, so a *stopped* room is never twice the
same. At native that wobble is 1/255 and nothing can see it. §4.5's buffer
quantizes to RGB555, whose step is 8/255, so the same sub-LSB wobble lands on
the far side of a colour step and becomes a real, countable change. Card #62
found it with a differ; #66 went and looked at it.

**How it was looked at, because a still frame cannot show a temporal artefact.**
`tools/directors/fog_crawl.gd` photographs **twelve consecutive 1280 × 720
frames at 1:1** (not the pre-#35 supersample, which would average the artefact
away) under six conditions from one pinned hero pose, in one process.
`tools/fog_crawl.py` turns each sequence into the per-pixel temporal range —
unamplified and at gain 12 — a magnified flipbook of the hottest neighbourhood,
and a panel with every moving pixel painted red so the artefact can be judged
*knowing exactly where it is*. Floor 1, 44 sconces:

| condition | px crossing a step, per frame pair | share of frame |
|---|---|---|
| **the fog alone** — world frozen, flames held, §4.5 on | **5,112** | 0.55% |
| the same with `volumetric_fog_temporal_reprojection_enabled = false` | 0 | 0 |
| the same at native (`internal_render = false`) | 0 (max delta **1**/255) | 0 |
| **standing still in a live room** — torches burning, hero idle | 107,464 | 11.7% |
| **walking forward** | 646,096 | 70.1% |
| walking forward, reprojection off | 655,314 | 71.1% |

(The floor is a fresh roll each run and the fog row moves with the room — 5.1k,
5.9k and 7.9k over three runs of 42–44 sconces. The finding is an order of
magnitude, not a constant, and every row above comes from one process so the
comparisons inside it are like for like. A second run put the walking pair at
652,107 against 652,073, which is the same answer with the difference gone
entirely.)

**The verdict is that it is invisible, and here is why rather than merely that.**
The moving pixels never move by more than **one** step (worst delta 9/255,
never two). They are an even, structureless dust — no bank, no edge, no shape —
covering 1.7% of the frame across twelve frames, and the **densest 32 × 32
neighbourhood anywhere in the frame is 12.4% moving pixels**, so there is
nowhere it gathers into a patch. Each speck is one 480 × 270 texel (clustered
fraction 0.96, which is the 2.67 px present block) toggling on roughly one
frame boundary in three, irregularly — the statistics of a quantizer boundary,
not of moving air. And it is 4.8% of what already changes when you *stand still*
in a room with the torches lit, and 0.8% of what changes when you walk.

Looked at: consecutive full frames at 1:1; four consecutive frames of the
hottest 320 × 180 window at 2× nearest; the worst adjacent pair of the hottest
160 × 90 window at 4× nearest; and that same pair beside its red-marked
difference map. **At 4× magnification, on the worst pair in the frame, having
just been shown a map of exactly which pixels moved, the two frames could not be
told apart.** The unamplified range image is black.

**What the alternatives would have cost, since one was nearly taken.**

- *Turn the fog's temporal reprojection off.* It is bit-exact and, in a still
  frame at 4× against the shipping build, indistinguishable — reprojection is a
  temporal accumulator and a stopped camera converges either way. Its cost is
  meant to be paid in motion, and the walking pair above says it buys nothing
  there either: 655,314 px/pair against 646,096, a 1.4% *increase*. So the
  remedy is cheap and it is also pointless — it removes an artefact nobody can
  see and gives up the accumulator on a fog this project may yet make thicker.
- *Dither the fog before quantization rather than after.* A second full-screen
  pass, a new shader, and §4.4's argument turned inside out — the ordered cell
  is deliberate here (see "the dither is loud on large flat surfaces and that is
  correct", above). Rejected on cost against a benefit of zero.
- *Accept it as a deliberate look.* Also wrong, in the other direction: PSX-era
  dithered volumetrics genuinely crawled, but that crawl was visible and this
  one is not, so calling it a look would be claiming credit for something the
  player never sees.

**Read the quantizer as the general hazard and not the fog as a special one.**
§4.5's step is 8/255, so *any* temporal wobble smaller than that — the next
accumulating, reprojected or TAA-ish thing anyone switches on — is invisible at
native and countable here. The fog is the first case, not the last, and the
instrument for the next one is `fog_crawl.gd` plus a pair of eyes, not a differ.
The harness's own answer is separate and unaffected: `rig.still_the_frame()`
turns reprojection off for *directors*, which is correct and stays (card #62).

> **Reversible, the way §4.8 is.** If the owner looks at a dark room on a good
> panel and sees the crawl, the one-line change is
> `env.volumetric_fog_temporal_reprojection_enabled = false` in
> `assets/materials/env_dungeon.tres` — the only environment in the project with
> volumetric fog at all — and nothing else in the game branches on it.

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

    **This started being true on 2026-08-11** (#58), and the frames are the
    argument. While the game rendered at native, a 128 px wall texture sat below
    one screen pixel per texel at any distance and the mipmap chain smeared it
    into a soft brown sheet — the texel grid this table exists to protect was
    invisible in the shipped renderer and the deviation was buying nothing. At
    480 × 270 the same wall reads as a crisp block-pixel wall and the mip
    selection is what stops the far half of it crawling. `d_plain_room_zoom.png`
    off `tools/directors/internal_res.gd` is the pair.
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
- **Enemy bodies remain readable for as long as their health bars do.** Every
  enemy mesh keeps its normal visual layer(s) and also carries visual layer 3;
  `GameCamera/EnemyReadFill` is a cool blue-violet, 1.5-energy, shadowless
  directional light culled to that layer with zero indirect or fog contribution.
  Its broad specular response is load-bearing for the skeleton's fully metallic,
  fully rough authored material. Normal world lighting and the texture still
  sculpt the body — this is not a rim, emissive, outline, cel band or unshaded
  material. Its cost is one extra directional-light evaluation on enemy meshes
  only; room lighting is unchanged and no HUD information is faded or hidden to
  conceal an unreadable actor.
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
  histograms do not move. **The flank sconces do not cast shadows** — a room gets
  two shadow-casters at most and they stay on the solid walls. Measured at the
  entrance-room pose: 955 draw calls with the flanks casting, **564 without**,
  against 556 for the room as it was built before the card. The fire is close to
  free; the shadows were not.
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

### 4.8 Anti-aliasing — the decision, and why it had never been made

> **Decided 2026-08-11 (card #55). This is a session's call, made while the
> repo owner was asleep, and it is REVERSIBLE** — one field in
> `scripts/autoload/settings.gd` and the frames below can be re-shot in four
> minutes. If the owner disagrees, the change to revert is `Settings.msaa`
> back to `2`; nothing else here touches the renderer.

**The decision.** Ship with **no anti-aliasing on the 3D viewport**:
`msaa_3d = DISABLED`, `screen_space_aa = DISABLED`, `use_taa = false`. The
aliased silhouette is part of the treatment, not a defect to be papered over.
The MSAA row stays in the options menu for the player who wants it; it is the
*default* that moves, 4× → off. Nothing changes for 2D type (see below), and
**no post-process AA pass — FXAA or TAA — ships in this project, ever** (§7,
item 11).

**Why this was never actually decided.** Until 2026-08-11 `tools/shoot.gd`
rendered 6880 × 2756 and Lanczos-downscaled into the requested PNG, so every
proof frame this project has ever judged carried a ~20× supersample that nobody
chose, nobody paid for and nobody could ship. Meanwhile `project.godot` said
`msaa_3d=0` and `Settings.msaa = 2` silently overrode it at boot. The look was
inherited twice over. It is now measured.

**The instrument** is `tools/directors/aa_compare.gd` — one garrison pose
(`garrison_look.tl_01_arrive`: curtain-wall merlons against flat sky, the
`LANTERNKEEPER` Label3D, the HUD's Cinzel caps, the vitals pips) photographed
under eight configurations inside a single process, so machine noise is
common-mode. Run at 1280×720 and again at 1920×1080. (That plate is a
`WorldCaption` on the canvas since #61, so the pose no longer holds a sample of
type-rendered-as-geometry at all. Nothing below turns on it — the plate aliased
like geometry and MSAA smoothed it like geometry, which was one more instance of
the merlons, not a separate finding.)

**What the frames show.**

- **MSAA at 2×/4×/8× is not visually distinguishable from none** at 3–5×
  nearest zoom, on merlons, on the statue silhouette, or on the Label3D.
  Quantitatively it inserts *one* partial-coverage pixel per silhouette edge
  and drops hard edge steps over a fixed box by about 6% (2090 → 1960). It
  cannot touch texture crawl, interior contrast, or type — the three things
  that actually read as "rough" here.
- **8× MSAA is 4× MSAA on this Metal driver.** Identical VRAM to 0.1 MB at
  both resolutions and edge statistics inside noise. The options menu presented
  it as a fourth distinct choice and on macOS it is not one. Carded separately
  as #57 and **settled there — see the box below.**

> **#57, 2026-08-11: it is a clamp, and the row is gone on Apple silicon.**
> Identical VRAM and an edge histogram inside noise were consistent with a clamp
> and *also* with "8× is real and its extra samples land in the same places" —
> two different claims, and only one justifies deleting a menu row. The
> distinguishing measurement is the frame itself, and
> `tools/directors/msaa_clamp.gd` takes it: freeze the garrison, render the pose
> at each level, subtract.
>
> | pair | native | 480×270 |
> |---|---|---|
> | null (4× → 4×, nothing touched) | 0–3 px | 0–2 px |
> | off → 2× | 45,048 px | 96,035 px |
> | 2× → 4× | 45,420 px | 87,575 px |
> | **4× → 8×** | **0 px** | **0 px** |
>
> of 921,600. Eight samples and four cannot resolve to a **bit-identical** frame
> unless the driver handed back the same framebuffer, and the two rows above it
> are what make that zero mean something rather than mean the instrument
> (CLAUDE.md §2, both directions).
>
> So `Settings.max_msaa()` returns 2 on an **Apple** adapter and 3 elsewhere,
> `apply_video()` clamps the stored value to it, and the options row is built
> from a slice of `MSAA_NAMES` with a caption naming the GPU. Gated on the
> adapter **vendor** and not on `OS.get_name()`: Apple is what was photographed,
> and hiding a working setting on an Intel Mac would be the other half of the
> same mistake.
- **FXAA halves the hard edge steps (2090 → 1036) and visibly blurs the
  128 px nearest-filtered stone**, and softens the world-space label. That is
  a direct fight with §4.7 (Nearest, no anisotropy) and with §7 item 6. It buys
  a smoother edge by destroying the texel grid the whole look is built on.
- **TAA blurs comparably and is structurally incompatible with §4.1's
  per-frame vertex snapping** — a jitter accumulator fed deliberately unstable
  vertices is a smear generator.
- **No viewport AA mode reaches the 2D canvas.** The HUD crop is
  *pixel-identical* across all eight configs, including `msaa_2d = 4×`. So
  "the type looks rough" was never an AA-setting question; see §3.1b.

**The cost, because a recommendation without one is not a decision.**

| Config | VRAM @1080p | Δ | VRAM @720p | Δ |
|---|---|---|---|---|
| none | 290.1 MB | — | 254.8 MB | — |
| MSAA 2× | 340.5 MB | +50.4 | 277.8 MB | +23.0 |
| MSAA 4× | 393.1 MB | **+103.0** | 301.0 MB | +46.2 |
| MSAA 8× *(= 4×, #57)* | 393.1 MB | +103.0 | 301.0 MB | +46.2 |
| FXAA | 290.3 MB | +0.2 | — | — |
| TAA | 347.2 MB | +57.1 | — | — |

Frame time is the honest disappointment: at 1080p the medians ran 6.25–9.47 ms
across the eight configs **with the ordering inverted** (some MSAA rows faster
than none), and at 720p 5.76–7.59 ms. On a Mac shared with four other agents'
director windows, the AA delta is below the noise floor — which is itself the
finding. *MSAA is not costing frames here; it is costing 103 MB of VRAM and
buying one pixel.* Card #20's budget is unaffected either way.

> **Do not quote card #20's median in a pitch — card #65, 2026-08-11.** #20's
> headline was *"~8.7–9.6 ms median at 1080p, 105–115 fps, ~7 ms of headroom"*.
> Card #50 then ran the control #20 had asked for and could not get, on a Mac
> with `ps -Ao pid,comm | grep -i godot` reading **zero**: the 9-draw-call
> `_lookdev` scene measured a **13.87 ms** median against the 720-draw-call
> garrison's 12.19–14.02. Eighty times the geometry for no time at all, which
> means a scene-independent floor is setting the median, not the game.
>
> What survives, and it is most of it: **the method** — `perf_probe --stall=300`
> injects a 300 ms block and `frame_ms` reports `max=305.29` at the exact sample,
> so `frame_ms` is a sound basis for a budget (#50). **The p95** — #20 read
> 16.5–17.4 ms, five runs on the current tree read 17.12–18.06; that band has not
> moved and does not track the floor. **The counts** — 720 draw calls, 182,989
> primitives, 236.8 MB VRAM, down from #20's 431.8 thanks to §4.5.
>
> Only the median is in doubt, and it is in doubt because a Mac running dozens of
> agents has a CPU and a compositor that no `comm` grep can see.
>
> **#65 ran, the control failed again, and the p95 above does not survive it
> either — 2026-08-11, on `23d7a47`, 1920×1080, `--warmup=90`, 240 samples:**
>
> | scene | draw calls | `frame_ms` med | `frame_ms` p95 | `cpu_ms` med |
> |---|---|---|---|---|
> | `_lookdev` | 9 | 10.92 | **19.02** | 0.13 |
> | `garrison` | 720 | 11.01 | **16.30** | 0.54 |
>
> Eighty times the geometry for **0.09 ms**. Two things follow, and the second
> is new:
>
> 1. **`cpu_ms` scales 4× with the scene while `frame_ms` does not move at all.**
>    That is the cleanest statement of the problem yet: the engine's own work
>    responds to the scene exactly as it should, and the frame time ignores it.
>    The ~11 ms wall is not the game. Earlier runs could only show the floor;
>    this one shows the game moving *underneath* it.
> 2. **The p95 is contaminated too, so strike it as a pitch number.** The
>    paragraph above says the p95 "does not track the floor". A 9-draw-call scene
>    posting a p95 **2.7 ms worse** than a 720-draw-call one is not a number
>    about geometry, and 16.30 also falls outside the 17.12–18.06 band cited
>    there. Both readings cannot be right; the honest conclusion is that the tail
>    is noise-dominated on a contended machine.
>
> **The precondition cannot be met from inside a Claude session.** #65 asks for
> "no Claude agents running at all"; this run had `load average 8.37` and 17
> Claude processes, none of them stoppable without destroying other sessions'
> work — and one of them is always the agent doing the measuring. Like §4.1's
> M4 gate, **this is a bar only a human at an otherwise-idle Mac can clear.**
>
> **What is safe to quote in a pitch, and it is not nothing:** the counts —
> 720 draw calls, 182,989 primitives, 974 objects — and **236.8 MB VRAM against
> 431.8 before §4.5**, which is a real 45% saving and contention-independent
> because it is a memory figure, not a time. `cpu_ms` (0.54 ms median, 0.67 p95
> on the garrison) is the one *time* that demonstrably tracks the scene, but it
> is root + the 480×270 buffer and not a whole-frame cost, so quote it as what
> it is or not at all. **No frame-rate or headroom claim survives this machine.**

**What the real answer to "the edges are rough" is.** §4.5 — the 480 × 270
internal buffer with a sharp-bilinear present. At 480 × 270 the edge question
changes shape entirely (there is nothing to antialias into), and the pixel grid
becomes deliberate rather than incidental. Turning MSAA off is the cheap half of
the right answer and the same direction of travel.

> **That half landed the same night** (2026-08-11, card #58). §4.5 is built and
> on, and this section's conclusion survives it unchanged: with a 2.67 px edge
> step there is nothing for MSAA to insert a partial-coverage pixel into, so the
> `Settings.msaa = 0` default is *more* right after #58 than before it. The MSAA
> row still applies — to the internal buffer now, routed there by
> `Settings.apply_video` — and a player who wants it can still have it.

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

The last row of the pole, and the only one that is **not a bar**. Three slots
today, one per *effect* that has a clock — `Game.LASTING_IDS`, and the third of
them is not a draught at all — fixed by kind forever. Each slot is a
VOID-hairlined ASH@60% track holding a **mark** on a VOID chip — identity, a
shape — and **four tiles** that go out one at a time — time, a count.

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
and never to `Game.start_draught` — a slot for it would be a container that can
never fill.

**The Ballast window does** (#39), and it is not a potion: eight seconds of soak
bought with a bag stack, which before this row grew was legible only as a health
bar that did not move. The row is derived from `Game.LASTING_IDS` — everything
that has a clock — so membership grows for free; the **mark and the hue do not**,
and `docs/HUD_PLAN.md` §15.16 records that the older claim of "a slot the day a
third one is brewed, with no edit to `hud.gd`" was never true of either half.

Each slot is divided by its **own** span (`Game.draught_span`): a draught runs 45
seconds and Ballast eight, and one shared divisor would open Ballast's slot at one
tile of four.

| | |
|---|---|
| Origin | x `0.031` (40), top y heat bottom + 4 px (688); **heat's own slot (678) in the garrison, where heat is not drawn** |
| Row | `0.44 ×` health width (151 px) × 6 px, slots split evenly with a 4 px gap — 47 px each at three |
| Mark | 6 × 6 chip, VOID @85%, shape inset 1 px: ■ Ironhide (a plate), ▲ Emberblood (a point), ▄ Ballast (a weight, sitting on the floor of the chip, in ARCANE), ✚ the fallback for the next one |
| Tiles | 4 per slot, 2 px apart (8 px wide at three slots); lit in the effect's tint, spent as a VOID @30% notch |

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
   hue**: 2 px common, 2 px with an inner rule uncommon, 3 px rare, 3 px with a
   dithered inner ring legendary. Four weights, four hues, either channel
   sufficient on its own.

   The pair this exists for is **common against rare** — MOTH `807868` khaki
   against COBALT `5878c8` blue, which a deuteranope sees **0.1%** apart in
   luminance, i.e. as the same rim. (This paragraph used to name MOSS against
   MOTH; measured through the matrix, that pair separates by 30%. See HUD_PLAN
   §15.15.) Common/rare passes on its thickness alone, and the assertion that
   requires it reads the ladder out of `Hud.rarity_weight`, so flattening the
   weights in the drawing code turns the check red rather than silently
   removing the only channel a colour-blind player has.
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

- **Three kinds, three channels, any one sufficient.** Hue alone was the whole
  answer once, and RUST against CYAN is the commonest colour-blind pair there is —
  on the one widget the player looks directly at while fighting. So each kind
  differs in hue, corner count *and* arm length:

  | kind | hue | corners | arms |
  |---|---|---|---|
  | hostile | RUST | four, arms **inward** along the edges | 8 px |
  | hookable | CYAN | four, arms **outward** off the corners | 12 px |
  | neutral | MOTH | **two** (top-left, bottom-right) | 5 px |

  2 px thick, framing the target's projected AABB at half-extents (26, 34).
- **Every stroke sits on a 1 px VOID keyline.** This is the only widget whose
  background is *whatever the player is aiming at*, and without the keyline the
  neutral bracket was invisible in the garrison — MOTH is a mid-khaki and so is
  sunlit grass. Same fix as the enemy bar's frame and the damage arc's underline;
  deliberately not a longer arm or a brighter hue, because both of those are
  already carrying meaning in the table above.
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
- **It follows the hero.** He is pinned to the middle of the square and the floor
  scrolls under him, at a fixed pitch of 3.4 cells across the box
  (`MapDraw.FOLLOW_SPAN`). The MAP tab still fits the whole floor, and the two
  wanting opposite things is the point: a full-floor fit is the right picture
  when you have stopped to read it, and the wrong one at 132 px in a corner,
  where a six-room floor puts every room under 40 px and "where am I" has to be
  answered by finding a 5 px arrow. Following answers it by never moving the
  arrow. The square is a clip as well as a frame; rooms are cut at its edge and
  glyphs are dropped whole rather than sliced.
- **Fogged rooms are not drawn at all.** Not greyed, not outlined: absent. Which
  means the blank space IS the information.
- **A corridor to a room you have seen is drawn whole; one to a room you have not
  is a stub** that stops short of it. A promise that there is more that way, and
  no claim about what. A locked door gets the same treatment — a gap in the wall
  and a stub — because what is behind it is on the map too (`docs/CONTRACT.md`
  §8, annexes), fogged until you walk in like everything else.
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
floaters; the perfect-dodge counter-attack prompt — the live attack cap in a BONE
circular button beside `COUNTER ATTACK`, on the World plate in the centre prompt
slot, existing exactly while the combat flurry window is available.

**There is no control legend.** A transient one lived at the bottom of the
garrison frame — 0.6 s in, 10 s, 0.6 s out, on boot, device change and run end —
and it was **deleted on 2026-08-12 (card #121)** on the owner's instruction:
*"we need to remove the controls from the bottom of the screen, they're not
important."* Nothing on the HUD names a button the player is not already looking
at. The only reference is **Options → Controls**, which lists every live binding
for the device in hand. Do not reinstate a bottom-of-frame legend without
re-opening that card.

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
| Floor card | 0.031 (40) | 0.052 (37) | name 10 px over level 16 px, **both BONE announcing and both MOTH settled**, world plate fading 72% → 34% |
| Minimap frame | right-align 0.969 (1240) | 0.052 (37) | 148 × 148, 8 px pad, VOID@88% on 1 px ASH |

#### Centre and full-screen

| Element | x | y | Size |
|---|---|---|---|
| Crosshair | screen centre, quantized to 480×270 | " | gap 7 (5 locked), arm 5, 1 px |
| Interact prompt | centre 0.500 | 0.735 (529) | 14 px on the world plate, pad **6** |
| Counter-attack prompt (**transient**, overrides interact) | centre 0.500 | 0.735 (529) | live attack cap at 14 px in a BONE circular button beside `COUNTER ATTACK` at 16 px, on the World plate; exactly while the flurry window is available |
| Prompt hold gauge | inside the plate | the plate's bottom edge | `HoldGauge.BAR_H` |
| Extraction sweep | 0.0 → 1.0 | 0.500 | 1 px CYAN, 200 ms |
| Legend (garrison, **transient**) | left edge derived from the vitals pole's right + `KEYS_GUTTER` | up from 0.942 (678) | **4 balanced rows**, step 15, 10 px BONE on a `PLATE_WORLD` plate |

#### World-anchored (these obey the world's rules, not the frame's)

| Element | Size |
|---|---|
| Lock brackets | half-extent (26, 34), 2 px on a 1 px VOID keyline, quantized to 480×270; arm 8 inward / 12 outward / 5 on two corners (§5.5) |
| Enemy health bar | 20 × 2 px (×2.2 locked), 1 px frame (BONE if elite), ASH@85% track, RUST fill, ≤ 22 m, LOS-gated |
| World caption (`WorldCaption`) | §3.1b type at its own `ref_px` (14 body / 16 damage), World plate, cap TOP on the anchor, quantized to 480×270, ≤ `max_range` (18 m default) with a 3 m fade, LOS-gated, behind-camera culled, **de-collided against the other captions on the frame**. Billboarded captions only — see §4.3 |

#### The caption de-collide — what does not shrink does not get out of the way

> **Decided 2026-08-11 (card #68). This is a session's call and it is
> REVERSIBLE** — delete the three passes in `Hud._draw_world_captions` and the
> two constants above them (`CAPTION_STACK_GAP`, `CAPTION_STACK_MAX`), and every
> caption is drawn at its own anchor again exactly as before. Nothing else reads
> them; `WorldCaption.declutter` goes with them. `tools/directors/echo_plates.gd`
> re-shoots the evidence in four minutes.

§4.5 moved billboarded captions onto the canvas (card #61) because a `Label3D`
came out of the 480×270 buffer as a smear. The bill for that arrives here: a
canvas caption is the same width at 3 m and at 9 m, so a cluster the perspective
used to pull apart now arrives as full-width strings on one baseline. The
sounding stone hangs three Echo names 1.30 m apart on one drum and from the game
camera **THE SECOND WIND was drawn straight through THE RETURNING SHAFT**.

The HUD lays them out instead. Captions are gathered, sorted by their projected
anchor top-down, and any that would overlap one already placed is pushed **down**
a row — the direction perspective picks anyway, since for captions at one height
the nearer one already projects lower. A caption with nothing near it does not
move at all, and nothing moves sideways: the anchor in x is what says which prop
a name belongs to. Past `Hud.CAPTION_STACK_MAX` rows the caption is dropped
rather than parked somewhere misleading — the same bargain `max_range` makes.

Two answers were not taken, and both are the obvious ones:

- **Shrink with distance.** It un-does card #61 — a caption is on the canvas
  precisely because it was illegible when it was small — and there is no room
  under §3.1b's 10 px floor to shrink into. A 14 px name that shrank the way the
  old `Label3D` did would be about 6 px at the stone.
- **A vertical stagger authored into the prop.** It fixes one drum. The defect
  belongs to captions, not to sounding stones, and a per-prop fix is one this
  repo re-pays every time it adds a cluster (CLAUDE.md §0).

Measured on `echo_plates` at 1280×720, 1:1: beat D's three plates went from
`[5311, 4876, 4504]` to `[5720, 5538, 4706]` and now agree with the lookdev
lens's `[5719, 5537, 4706]` **to within a pixel** — the same captions at 5 m and
at 3.2 m putting the same ink on the frame, which is what canvas type not
shrinking is supposed to mean.

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
11. **No post-process anti-aliasing. No FXAA, no TAA, ever** (§4.8, measured
    2026-08-11). Both buy a smoother silhouette by blurring the 128 px nearest
    texel grid §4.7 exists to preserve, and TAA additionally fights §4.1's
    per-frame vertex snapping. MSAA is *permitted* — it ships off by default and
    stays as a player option — because it touches geometric edges only and
    cannot smear a texture. If edges need fixing, the fix is §4.5's internal
    resolution, not a filter over the top.

---

## 8. Open deltas against the repo

- ~~`project.godot` currently pushes the opposite way and needs: `msaa_3d=0`,
  `screen_space_aa=0`,~~ **the AA half of this delta is CLOSED (2026-08-11,
  #55), and it turned out not to be a `project.godot` problem at all.** Both
  keys already read `0` there and had for some time; what actually shipped 4×
  MSAA was `Settings.msaa = 2`, applied by `Settings.apply_video()` at boot,
  *after* the project setting is read. The default is `0` now — one field, the
  sanctioned runtime path, no edit to the orchestrator-owned file. §4.8 holds
  the frames and the cost. What remains open from this bullet: directional
  shadow size 8192 → 1024 (or off), `soft_shadow_filter_quality=0`, and
  `default_texture_filter=0`. **`use_debanding` came off this list on 2026-08-11
  (#58)**, by the same route again: the world's 3D is drawn by a SubViewport
  built in code now, so `screen_present.gd` sets `use_debanding = false` on the
  viewport that matters and the project key no longer governs anything this
  document cares about. `project.godot` is orchestrator-owned per CONTRACT §3.
- ~~**§4.5's internal-resolution pipeline is authored and unbuilt.**~~
  **CLOSED 2026-08-11 (#58).** The 480 × 270 SubViewport, the sharp-bilinear
  present and the Bayer dither at internal resolution are built and on, behind
  `Settings.internal_render`, and needed no edit to `project.godot`. §4.5 holds
  the frames, the cost and the one thing it breaks. The four lines of shader this
  document had been carrying were wrong and are corrected there.

  ~~What this delta became, rather than what it closed: **world-space `Label3D`
  text is illegible through the buffer** — the keeper name plates and the
  training post's readout. Card #61.~~ **CLOSED 2026-08-11 (#61).** A
  billboarded caption is interface, so it is drawn on the canvas now
  (`scripts/ui/world_caption.gd`); the three carved signs stayed in the world.
  §4.3's caption bullet holds the criterion and the cost, §4.5 the measurement.

  **The HUD's half of the texture-filter delta is done** and did not need the
  project key: `Hud`'s canvas sets `TEXTURE_FILTER_NEAREST` on itself. The item
  icons are baked at HUD resolution, so linear filtering bought no antialiasing
  and only smeared their VOID dilation into a halo. Type is unaffected either way
  (`draw_string` rasterises its own glyphs) and 3D materials carry their own
  filter, so the global key remains open for whatever OTHER 2D this project grows.
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
  replacing eight identical full-width buttons); and all five staffed counters,
  which share one NPC service screen class (`TradeScreen` remains the internal
  compatibility name) with two layouts: **Trade** is a dual-inventory shop with
  NPC stock on one side, the player's bag on the other and shared item details;
  quartermaster and jewelcrafter **Upgrades**, **Smithing**, **Alchemy** and
  **Artifacts** use the linear slot/rung progression layout. This is one shared
  implementation, not a claim that every service is Trade; and the footlocker
  (`StashScreen`), whose
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
