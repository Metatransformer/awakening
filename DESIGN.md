# HUD Design System — The Lower Worlds: Awakening

Authority for every visual decision in `scripts/ui/**` and `scenes/ui/**` (P12 on the
board, "P10 hud" in `docs/CONTRACT.md` §7 — see §11, the numbering disagrees).

Same convention as `scripts/core/consts.gd`: numbers tagged **[measured]** were derived
from real frames or the reference and are not to be "corrected" by intuition. Numbers
tagged **[tune]** are ours to move.

---


---

> ## ⚠ SUPERSEDED — read this first
>
> This document was written against the repo as of `0dc3c07`, when the game was
> an Ocarina-style dungeon crawler with hearts, a magic meter and a C-pad. Commit
> `34318cf` landed the extraction loop — garrison, shop, bag value, extraction cost —
> and with it `docs/STYLEGUIDE.md`, which is the HUD's actual governing document.
>
> **The palette in §4 did not ship and should not be used.** `Pal`
> (`scripts/ui/style.gd`) is the palette: every channel byte a multiple of 8,
> because the PSX framebuffer was RGB555. The cold/warm split proposed here is
> incompatible with it, and `GOLD` and `CYAN` already have exclusive owners
> (currency, and the way out).
>
> **What did ship, from the owner's four instructions:**
>
> | Asked for | Where it lives now |
> |---|---|
> | A normal health bar | `Hud._draw_health` — a ticked bar. STYLEGUIDE §5.1 |
> | Stamina bar below it | `Hud._draw_stamina`, plus a real stamina cost on the roll. §5.1b |
> | Real icons | `tools/scenes/_iconbake.gd` → `assets/ui/icons/`, posterised into Pal |
> | Less margin | Already satisfied: `Pal.SAFE` is 0.025/0.031. The 8% this document complains about was the *old* HUD |
>
> Proof: `tools/directors/hud_vitals.gd` drives the bars through spend, refusal,
> regen, damage-ghost and low-health.
>
> What is still worth reading here: §2 (the frame measurements), §11 (the
> conflicts), and §13 (the decisions log). Everything prescriptive is stale.

## 0. Product context

- **What this is:** a third-person, over-the-shoulder 3D dungeon crawler in the framing
  and feel of Ocarina of Time, with a **roguelike run structure** on top: floors, rooms,
  and boons that build a run.
- **Who it's for:** players who know what a Z-target feels like and want a build.
- **Project type:** real-time 3D game HUD, Godot 4.7 Forward+, 1280×720 authoring
  resolution, keyboard+mouse and gamepad at parity.
- **The one memorable thing:** *the lock-on. Combat is legible.* Every decision below
  serves that. When a decision does not serve it, the decision loses.

---

## 1. The thesis

> **The HUD spends its attention budget on the fight and its persistence budget on
> almost nothing. Run state and the engagement cluster are never on screen together.**

Vitals are always present and always quiet. The engagement cluster (lock-on, threat,
telegraph) exists only while a fight is live and owns the eye completely while it does.
Run state (floor, room, boons, full map) owns transitions and then leaves.

---

## 2. The measurement everything rests on

Sampled from `runs/p1p2/{smoke,smoke2,smoke3,smoke4,_off_run}.png`, the real renders.

| Fact | Value | **[measured]** |
|---|---|---|
| Median screen luminance | **15 / 255** | every frame, within 0.2 |
| Dominant colour | `#1f0900` at **79%** of frame | octree quantise, 8 colours |
| Scene hue band (p5–p95 of lit pixels) | **15–30°** | 15° wide, all frames |
| Scene saturation (median) | **0.91** | |
| Pixels above L=150 | **0.76 – 1.91%** | these are the torch flames |
| **Cold pixels (hue 150–300°, sat > 0.15)** | **0.00%** | **every frame, zero** |

Three laws follow, and they are not stylistic preferences:

1. **Cold hue is a free channel.** The dungeon is physically incapable of emitting one.
   Anything cold is parsed as UI with a 100% signal-to-noise ratio, permanently, at no
   ongoing cost. **Therefore: everything that can kill you is cold.**
2. **Gold is the most contested channel on screen.** The torches own it, they are the
   only bright thing in the frame, and they flicker. **Therefore: gold carries run
   identity, never life-or-death state.**
3. **Brightness is scarce, so it is powerful, so it must be rationed.** An element at
   L≈200 is roughly 100× rarer than the median pixel. Total HUD ink budget is tiny.

> This inverts the obvious move. Matching the HUD to the art direction (warm gold on
> black, "diegetic feel") puts critical information into the one channel that already has
> competition. The measurement says do the opposite.

**Corollary, and a real loss:** Hodent's standard advice — *red for critical, orange for
warnings* — is unavailable here. The whole screen is orange. Warnings must be carried by
**shape and motion**, or shifted cold. Do not reach for an orange warning state.

---

## 3. The layer model

Three layers. Every element belongs to exactly one. This is the contract; the rest of the
document is how each layer looks.

| Layer | Temperature | When on screen | Contains |
|---|---|---|---|
| **Vitals** | cold | **always** | health bar, stamina bar, item slots, currency |
| **Engagement** | cold | only while a fight is live | lock brackets, target threat arc, telegraph rings, damage numbers |
| **Run** | warm | transitions, then fades — **except the floor card, which settles rather than leaving** | floor card, room pips, boon cards, full-opacity map |

Tiering follows `gamestack:ui-ux-and-feedback` §B.1: Tier-1 (can kill you inside a 3s
reaction window) is permanent and peripheral; Tier-2 is context-triggered; Tier-3 is in a
menu. **Health is Tier-1 and never leaves the screen for any reason**, including during a
boon choice, where it drops to 18% opacity rather than disappearing.

**The minimap belongs to the Run layer, not Vitals.** You do not navigate mid-fight. It
sits at 38% while a target is locked and returns to 100% otherwise. This converges with
the source material rather than fighting it: OOT's minimap was already the one cold
element in an otherwise warm HUD (`refs/REFERENCE.md` §7.2, "translucent filled teal with
a bright cyan 1px border").

---

## 4. Colour

### Scene reference — measured, never used for UI

```
--ink        #1f0900   79% of the frame
--stone      #562808
--stone-lit  #975620   brightest large surface
--torch      #fde49b   flame; flickers; the only real competitor
```

### Vitals + Engagement — cold

```
--vital      #C8E4EF   hue 197°   hearts, lock brackets, slot glyphs
--vital-dim  #5E7F8C   hue 197°   empty tracks, slot rims, inactive
--threat     #FF6B8F   hue 345°   damage taken, enemy health, closing telegraph
--focus      #4FD6C4   hue 172°   the resource formerly called magic; minimap rules
```

### Run — warm, deliberately inside the dungeon's own voice

```
--relic      #E8A13C   hue  35°   floor titles, room pips, currency
--relic-hi   #FFD98A   hue  41°   emphasis
--rare       #7FB6D9   hue 203°   boon tier: cold, because rare should feel *other*
--legendary  #FFB347   hue  35°   boon tier + shimmer 1.0
```

### Measured contrast **[measured]**

| element | hue | clear of scene band | on ink | on stone | on lit stone | on torch |
|---|---|---|---|---|---|---|
| vital | 197° | 167° | **14.4** | 9.3 | 4.3 | *1.1* |
| vital-dim | 197° | 167° | 4.5 | 2.9 | *1.3* | 3.4 |
| threat | 345° | 30° | 7.1 | 4.6 | *2.1* | 2.1 |
| focus | 172° | 142° | **10.7** | 6.9 | 3.2 | *1.4* |
| relic | 35° | 5° | 8.7 | 5.6 | *2.6* | 1.7 |
| rare | 203° | 172° | 8.7 | 5.6 | *2.6* | 1.7 |
| legendary | 35° | 5° | **10.7** | 6.9 | 3.2 | *1.4* |

*Italic = below the 3.0 UI-component floor.* Every one of those failures is against a
**torch flame or lit stone**, and every one is solved by the same rule:

### The outline rule — not optional, applies to every element

> **Every HUD element carries a 1px `#140800` outline (or drop-shadow of the same
> colour).** The outline scores **15.7:1 against a torch flame [measured]**, which
> rescues every cold element at once. Without it, `vital` on flame is 1.1:1, i.e.
> invisible. This is the same trick `refs/REFERENCE.md` §7.2 records on OOT's own
> minimap ("dark outer drop-shadow"). Verified visually in the design study.

Implementation: a `CanvasItem` outline shader, or `feMorphology`-equivalent dilate; for
`Label`, use `theme_override_constants/outline_size = 2` with
`font_outline_color = Color("140800")`.

### The colour rule the player can actually learn

> **Your health is cold. The thing hurting it is hot.**

On damage, the struck heart flashes `--threat` for 6 frames, then settles back to
`--vital`. This is what makes the temperature split legible as a *rule* rather than an
arbitrary palette. Do not use `--threat` for anything that is not damage or danger.

---

## 5. Typography

> **The world talks in serif. The system talks in sans.** Two voices, one rule. A player
> can tell which layer they are reading before they read it.

| Role | Face | Why |
|---|---|---|
| Display — boon names, floor titles, death | **Instrument Serif** | High-contrast display serif, sharp, carved when letterspaced. Deliberately *not* Cinzel or Trajan, which is the fantasy-game convergence trap and reads as stock. |
| System — all labels, all numbers | **Geist**, tabular-nums | Instrument-panel voice. Clean without being Inter. |
| Counters that tick — ammo, currency | **Geist Mono** | Tabular by construction; digits do not shimmy as they count. |

**Godot import, non-negotiable:** `FontFile` with
`multichannel_signed_distance_field = true`. `Settings.resolution_scale` exists and will
turn raster fonts to mush at anything other than 1.0.

**Scale**, in the 320×180 grid (px at 1280×720 in parentheses):

| token | grid | @720p | use |
|---|---|---|---|
| `display` | 8.5 | 34 | floor title, boon name |
| `body` | 3.25 | 13 | boon description |
| `label` | 2.9 | 11.5 | uppercase, tracked +0.14em |
| `micro` | 2.5 | 10 | tier labels, tracked +0.22em |
| `counter` | 5.75 | 23 | currency |

---

## 6. Grid, layout, spacing

**Author in a 320×180 virtual grid** — the 16:9 sibling of OOT's 320×240 — so every
measurement in `refs/REFERENCE.md` §7.1 converts directly. Base unit **4** (16px @720p).

**Safe margin: 3.1% of width** (40px @720p, 10 grid units), 34px vertical.

The reference's own margin is **8%** (hearts at x≈25.75/320 = 8.05%, rupees at
x≈27.5/320 = 8.6%; they share it) — that number is a **1998 CRT overscan allowance**, not
a design decision, and this is not shipping to a CRT. Held at 8% the HUD reads as a
floating widget with a gutter around it; at 3.1% it reads as part of the frame. The
measured value is kept in `refs/REFERENCE.md` as history; `K.HUD_MARGIN` is ours.

| Element | Layer | Anchor | Position |
|---|---|---|---|
| Health bar | Vitals | top-left | x **3.1%**, y **4.7%**; 344×23px, segmented every `K.HEART` (4 quarters) |
| Stamina bar | Vitals | top-left | directly below health, 6px gap; **0.62× the health width**, 13px tall |
| Currency | Vitals | bottom-left | x 3.1%, y 92% |
| Item slots ×3 | Vitals | bottom-right | right-aligned to 96.9%, centre y 88%; equipped r=44, stowed r=32 |
| Minimap | Run | top-right | right edge at 96.9%, y 5.5–25% |
| Floor card | Run | **top-left** | x 3.1%, y 5.2%; "THE SUNKEN CUT" over "LEVEL n" on a VOID plate. Announces lit on `Bus.floor_arrived`, settles over 0.9s; the level line never dims. **Shipped here, not top-right**: the button cluster took that corner, and this is the only text on the HUD with lit brick behind it — hence the plate |
| Lock brackets | Engagement | world | corner brackets on the target's screen AABB, inset 26px |
| Target threat arc | Engagement | world | 62px radius arc, centred above the bracket box |
| Telegraph ring | Engagement | world | at the **attacker's** feet, not the hero's — the danger is where the blow lands |

**Health is a bar, not a heart row.** The model is unchanged — `Game.quarters` /
`Game.max_quarters`, `K.HEART == 4` — but it draws as a single continuous bar with a
**1.8px `--outline` tick at every heart boundary**, cutting through the fill and breaking
the plate top and bottom. That keeps what the heart row was actually for (you can count
your remaining hits at a glance, and the count survives colour removal) while scaling to a
roguelike's max-health growth, which a row of glyphs does not: at 12 containers a heart row
is 37% of the screen width, a bar is still 344px with denser ticks.

**Stamina sits directly below health**, deliberately shorter — 0.62× the width — so the
two never read as one two-line meter, and so peripheral vision can tell which bar moved
without foveating. It fills `--focus`; health fills `--vital`. Both share the plate, the
bevel, and the leading-edge highlight, so they read as one instrument with two channels.
A `--vital-dim` bracket on the left binds them into a single object.

**Slot icons are rendered from the real item models**, not drawn as vectors — the same
thing OOT did, whose C-button icons are rendered item models. `tools/scenes/_iconbake.gd`
bakes them from the GLBs through `WeaponModels.make()`, so the icon is always the thing you
are holding and can never drift from it. The bake is **two-pass**: render once, read the
alpha bounds the renderer actually produced, then recentre and rezoom. One pass is not
enough — a skinned mesh reports its *bind-pose* AABB, which on `hookshot_pistol` is mostly
empty air and frames the icon as a 39px speck.

**Item slots keep 3** (`Game.c_items`, `item_left/up/right`), arranged in the physical
shape of **the player's actual controller face cluster** — `item_up` top, `item_right`
right, `item_left` left — read through `Settings.label_for()` so the glyphs follow the
active device. OOT's C-pad shape was diegetic to the N64 pad; this is the same idea
applied to the pad the player is actually holding, not a reproduction of a 1998 artifact.

Ammo counts render **only on the slot whose item consumes ammo**, because
`Game.arrows`/`bombs` are meaningless until that item is owned.

---

## 7. Motion

| Event | Motion | Why |
|---|---|---|
| Damage | bar drops **instantly**, no tween; fill flashes `--threat` 6 frames | Damage is a fact. Tweening it softens the one thing that must land. |
| Heal | 180ms ease-out fill | Relief is a process. Deliberately asymmetric with damage. |
| Stamina spend | drops instantly; refills 260ms ease-out after a 400ms hold | The hold is the tell that you are still winded. |
| Lock acquired | brackets snap in over **4 frames** with 1.15 scale overshoot | 4 frames = `K.HITSTOP_LIGHT`; the HUD and the combat feel agree. |
| Lock lost | 100ms fade, no scale | Losing a lock should not be an event. |
| Telegraph | cold track, hot sweep closing over the wind-up window | The sweep *is* the timer. |
| Room entry | 240ms in → **2.5s hold** → 400ms out | Long enough to read, short enough to not become furniture. |
| Boon offered | scrim to 72%, cards rise 240ms staggered 60ms | The only time the game stops for the HUD. |
| Legendary card | continuous shimmer, `ui_boon_frame.shimmer = 1.0` | The only moving thing on screen. Movement wins the eye before colour does. |
| Low health | fill turns `--threat` **and** the bar is short | Never colour alone — the length carries it with colour removed. |

`--relic` currency sits at **45% opacity** and pops to 100% for 1.5s on change. Ambient
but not gone.

---

## 8. Feedback vocabulary

Per `gamestack:ui-ux-and-feedback` §C.1: every state change gets **visual + audio synced
within 15ms**. Test by playing with the display off; if you cannot tell a hit from a
block from a kill, the audio layer is unfinished.

| Event | Visual | Audio | Camera |
|---|---|---|---|
| Hero takes damage | heart flash `--threat`, screen edge pulse | hit | shake, scaled to `Hit.amount` |
| Shield block | spark at contact normal | block | none |
| Hit landed | damage number `--vital`, target arc drops | impact by `Hit.kind` | `K.HITSTOP_LIGHT` |
| Killing blow | arc collapses, brackets release | death | `K.HITSTOP_HEAVY` |
| Lock acquired | brackets snap | soft cold tone | FOV 60→50 (`K.CAM_FOV_LOCK`) |
| Low health (≤1 heart) | vignette; hearts pulse at 0.8Hz | heartbeat | FOV × `K.CAM_FOV_LOW_HEALTH` |

**Pulse rate is capped at 0.8Hz.** The photosensitivity floor is 3Hz; nothing in this HUD
goes near it. Everything vestibular routes through `Settings.camera_shake` and must
actually respect it — including boss abilities. A setting that 90% works is a bug.

---

## 9. Accessibility

- **Every colour signal carries a redundant shape channel.** Hearts are heart-shaped with
  **quarter-tick marks cut into the glyph**, so health reads with colour removed
  entirely. Boon rarity carries a text tier label, not just a frame colour. Minimap uses
  a red arrowhead **plus** a distinct yellow facing cone (already in the reference).
- **Never encode enemy/ally or safe/danger by hue alone.** Telegraphs use a *closing
  sweep*; the geometry is the signal, the colour is reinforcement.
- Text size slider, minimum 3 steps. Test against `smoke4.png` (darkest) **and** a torch
  flame (brightest) — the effective contrast range is the whole design problem.
- `Settings` already owns `camera_shake`, `rumble`, `letterbox_on_target`. Any new
  toggle belongs there, not in HUD code.

---

## 10. Godot implementation spec

```
HUD (CanvasLayer, layer = 1)
├── Vitals (Control, full rect, mouse_filter = IGNORE)
│   ├── HealthBar     (TextureProgressBar + tick overlay; step = 0.0)
│   ├── StaminaBar    (TextureProgressBar, 0.62× width, directly below)
│   ├── Currency      (HBoxContainer: icon + Label, Geist Mono)
│   └── ItemSlots     (Control ×3, pad-face cluster; ui_radial_gauge for cooldown sweep)
├── Engagement (Control, full rect)
│   ├── LockBrackets  (4 × NinePatch/Line2D, follows target screen AABB)
│   ├── TargetArc     (ui_radial_gauge, inner_radius 0.62)
│   ├── Telegraphs    (pool; ground_decal.gdshader at the attacker's feet)
│   └── DamageNumbers (pooled Labels; world→screen via get_viewport().get_canvas_transform())
├── Run (Control, full rect)
│   ├── Minimap       (SubViewport + TextureRect, UPDATE_ALWAYS)
│   ├── FloorTitle    (Label, Instrument Serif) + RoomPips (HBoxContainer)
│   └── BoonChoice    (3 × PanelContainer, ui_boon_frame.gdshader)
└── Overlays (CanvasLayer, layer = 10) — pause/map, above everything
```

**Rules from `godot-prompter:hud-system` that apply here:**
- Everything under a `CanvasLayer`. No HUD node in the world tree.
- `mouse_filter = MOUSE_FILTER_IGNORE` on every non-interactive node.
- Bind to signals; never poll state in `_process`.
- `tween.kill()` before starting a new one, or rapid damage stacks animations.
- Damage-number pool must outlive its own tween duration.

**Shaders already in the repo, imported from `~/valenfeld`, most of them still unused.**
These were written for exactly this and their own header comments describe these use
cases. `ui_title_backdrop` is the one that has since been instanced — its header had
described the loading frame it now draws since the foundation commit:

| Shader | Use |
|---|---|
| `ui_radial_gauge.gdshader` | target threat arc, item cooldown sweep (`inner_radius = 0`), dodge ring |
| `ui_boon_frame.gdshader` | boon cards; drive `accent` / `glow` / `shimmer` from rarity only |
| `ui_carved_panel.gdshader` | pause and map panels |
| `ui_spell_sigil.gdshader` | item slot socket backing, behind the baked icon |
| `ui_title_backdrop.gdshader` | **in use** — `LoadingCard`, the named screen on the way into the Sunken Cut |
| `ground_decal` / `nova_decal` | telegraph rings |

### Bus signals — all four the HUD needs already exist

`player_health_changed`, `magic_changed`, `ammo_changed`, `rupees_changed`,
`c_items_changed`, `target_acquired`, `target_lost`, `room_entered`, `hit_landed`,
`enemy_died`, `boss_phase_changed`.

**One gap: there is no stamina.** `scripts/autoload/game_state.gd` has `magic`/`max_magic`
but no stamina field, and `Bus` has no `stamina_changed`. The stamina bar in the study is
drawing a number that does not exist yet. It needs the orchestrator additions below before
the HUD work package can bind to it.

**`# NEEDS:` (orchestrator, per CONTRACT §7 — do not add these yourself):**

```gdscript
# scripts/autoload/event_bus.gd — append only
signal boon_offered(choices: Array)      # Run layer: raise the card screen
signal boon_taken(boon_id: StringName)   # Run layer: collapse and resume
signal floor_changed(floor: int, rooms_total: int)
signal enemy_telegraph(enemy: Node3D, window: float)   # Engagement: telegraph ring
signal stamina_changed(stamina: float, max_stamina: float)
```

```gdscript
# scripts/autoload/game_state.gd — append only
var max_stamina: float = K.MAX_STAMINA
var stamina: float = K.MAX_STAMINA
```

```gdscript
# scripts/core/consts.gd — append only
const HUD_GRID := Vector2i(320, 180)   # [tune] 16:9 sibling of OOT's 320x240
const HUD_MARGIN := 0.031              # [tune] 40px @720p. The reference's 8% is CRT
                                       # overscan allowance, not a design decision.
const HUD_MARGIN_Y := 0.047            # [tune] 34px @720p
const HUD_BAR_W := 0.269               # [tune] 344px @720p, health bar
const HUD_BAR_H := 0.032               # [tune] 23px @720p
const HUD_STAMINA_RATIO := 0.62        # [tune] stamina width as a fraction of health
const MAX_STAMINA := 100.0             # [tune] no stamina model exists yet
const HUD_OUTLINE := Color("140800")   # [measured] 15.7:1 against a torch flame
const HUD_ENTRY_HOLD := 2.5            # [tune]
const HUD_DAMAGE_FLASH := 6            # [tune] frames
```

### Proving it, per CONTRACT §9

The HUD is a **motion** piece. A single static frame will not pass, and should not.
Deliver a contact sheet driven by a director that covers: lock acquire → strafe →
take a hit → kill → room transition.

```bash
tools/quiet.sh --path . -s tools/shoot.gd -- \
  --scene=res://scenes/rooms/training.tscn --director=res://tools/directors/p12_hud.gd \
  --out=/abs/out/hud_.png --burst=8 --burst-gap=4 --size=1280x720
python3 tools/ab.py sheet 'out/hud_*.png' --out out/sheet.png
```

**Do not A/B the HUD against `refs/screens/hud_gameplay_01.png`.** It will fail, by
design. See §11.

---

## 11. What this contradicts, and what to do about it

This design **deliberately breaks** two things. Both are orchestrator-owned files
(`docs/**`, `refs/**`), so this document does not edit them. **Someone needs to make
these edits before a critic runs, or the critic will correctly fail work that is
correctly built.**

1. **`docs/CONTRACT.md` §2.5, fact 6** — "The HUD's B/A/C buttons are TOP-RIGHT… Hearts
   are top-left." Hearts stay top-left. The item slots move to **bottom-right**, because
   top-right is now the Run layer's home and because the slot cluster should mirror the
   pad the player is holding. Fact 6 needs rewriting or scoping to "OOT does this; we
   deliberately do not."
2. **`refs/REFERENCE.md` §7** — remains accurate and stays the authority on *what OOT
   did*. It is no longer the target for *what we build*. Add a note at the top of §7 to
   that effect, so a future critic does not treat it as a pass/fail bar.

There is also a **numbering collision worth fixing while you are in there**:
`docs/CONTRACT.md` §7 lists HUD as **P10** and enemies unassigned; `progress.html` lists
**P10 = Enemies** and **P12 = HUD**. Two agents reading different files will claim
different packages.

---

## 12. Open questions

- **No ambient boon readout.** Checking your build mid-fight requires a `map` hold, which
  is a real interruption in a game with no safe moments. If playtests show players
  pausing to check boons, the fix is a collapsed sigil row on the bottom edge at ~30%
  opacity — but ship without it first and see.
- **Cold hearts are a genuine convention break.** Red hearts are the most established
  health signal in games. The temperature rule (cold health, hot damage) is what earns
  it. If a playtester cannot identify their health in under 0.5s, the rule loses and the
  hearts go red — at which point `--threat` needs a new hue.

---

## 13. Decisions log

| Date | Decision | Rationale |
|---|---|---|
| 2026-08-08 | Roguelike-first layout over OOT replica | User decision. The run layer needs information architecture the OOT HUD has nowhere to put. |
| 2026-08-08 | Critical = cold, run = warm | **[measured]** 0.00% cold pixels across all frames. Cold is a free channel; gold is the contested one. |
| 2026-08-08 | Run layer and engagement layer never coexist | Serves "combat is legible" — steady-state combat screen is nearly empty. |
| 2026-08-08 | Vitals are a third layer, always on screen | Caught while building the study: the first draft dropped hearts during room entry. Health is Tier-1 and never leaves. |
| 2026-08-08 | 1px `#140800` outline on every element, mandatory | **[measured]** cold-on-flame is 1.1:1; outline-on-flame is 15.7:1. Same trick as OOT's minimap. |
| 2026-08-08 | Health stays top-left; minimap kept | User declined the feet-arc and no-minimap risks. Recovers the reference's corners. |
| 2026-08-08 | Minimap joins the Run layer, dims to 38% in combat | You do not navigate mid-fight. Converges with OOT, whose minimap was already cold. |
| 2026-08-08 | Screen-space, not ground-plane, for anything hero-anchored | `K.CAM_PITCH = 5.0`. A true ground decal at 5° pitch is edge-on and unreadable. |
| 2026-08-08 | Health is a segmented bar, not a heart row | User decision. Keeps the quarter-heart model and the countability; scales to roguelike max-health growth, which a glyph row does not. |
| 2026-08-08 | Stamina bar directly below health, 0.62× width | User decision. The width difference is what stops the two reading as one two-line meter in peripheral vision. |
| 2026-08-08 | Margin 8% → 3.1% | User decision. 8% is a 1998 CRT overscan allowance; at 8% the HUD reads as a floating widget with a gutter. |
| 2026-08-08 | Slot icons baked from the real GLBs | User decision. Same as OOT, whose C-button icons are rendered item models. The icon cannot drift from the item. |
| 2026-08-08 | Icon bake is two-pass, refit to rendered alpha | Skinned meshes report bind-pose AABBs; `hookshot_pistol` framed at a 39px speck on one pass. |
| 2026-08-08 | Instrument Serif + Geist, not Cinzel/Trajan | Fantasy-serif is the category convergence trap. Serif = world, sans = system. |

---

*Created by `/design-consultation`, 2026-08-08. **This is a design document — the HUD is
not implemented.** `scripts/ui/` and `scenes/ui/` do not exist yet; the only running code
this produced is `tools/scenes/_iconbake.gd`. Measurements are reproducible from
`runs/p1p2/*.png`. Design study: `hudmock/index.html` (scratchpad).
Review was self-administered — no second model reviewed this document.*
