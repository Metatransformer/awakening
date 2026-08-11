# OOT REFERENCE — the measurable checklist

Target: **The Legend of Zelda: Ocarina of Time**, N64, 1998 (NTSC).

This is the document critics read when they cannot eyeball something. Every line is meant to be
**falsifiable**. If a number here is wrong, our build gets failed for the wrong reason — so the
sourcing discipline below is not decoration.

## How to read the tags

| Tag | Meaning |
|---|---|
| `[decomp]` | Read out of the `zeldaret/oot` decompilation. File + symbol given. Treat as fact. |
| `[derived]` | Arithmetic on `[decomp]` values. The arithmetic is shown so you can check it. |
| `[measured]` | Measured by me from a screenshot in `refs/screens/`. The file is named. Reproducible. |
| `[guide]` | Community walkthrough / wiki. Good for content and ordering, not for frame counts. |
| `UNVERIFIED:` | I could not source it. My estimate + reasoning is given. **Never fail a build on one of these.** |

Primary source throughout: <https://github.com/zeldaret/oot> (`main`). Paths are relative to the repo root.
Speed data cross-checked against <https://www.zeldaspeedruns.com/oot/generalknowledge/movement-speeds>.

---

## 0. The two constants that make every other number readable

**Read this section first or you will misread every speed in this document.**

### 0.1 The game runs at 20 Hz, and logic is locked to display

`R_UPDATE_RATE = 3` `[decomp: src/code/game.c:494]`. The scheduler holds each framebuffer for
`R_UPDATE_RATE` vertical retraces before swapping `[decomp: src/code/graph.c:337, src/code/sched.c:533-540]`.

- NTSC: 60 VI ÷ 3 = **20 Hz**, hard ceiling `[derived]`
- PAL: 50 ÷ 3 = **16.67 Hz** `[derived]`

**Game logic, animation and rendering all advance exactly once per displayed frame.** The commonly
repeated "20 fps display / 60 Hz internal logic" is **wrong**. Corroboration: `include/versions.h:45-49`
defines `FRAMERATE_CONST(value60Hz, value50Hz)` and every instance is a ×1.2 pair — PAL needs 1.2×
larger per-tick constants because it gets 1.2× fewer ticks per second `[decomp]`.

Throughout this document **"tick" = one 20 Hz game step = 50 ms**.

> **Implication for our build.** If we run at 60 fps we are running 3× more simulation steps per
> second than OOT. Every per-tick constant below must be divided by 3, or applied on a fixed 20 Hz
> logic tick with rendering interpolated. Do not paste OOT's per-tick numbers into a 60 Hz
> `_physics_process` — everything will be 3× too fast.

### 0.2 Velocity is per 1/30 s, and positions move at 1.5× velocity

`[decomp: src/code/z_actor.c:985-991]`
```c
void Actor_UpdatePos(Actor* actor) {
    f32 speedRate = R_UPDATE_RATE * 0.5f;          // = 1.5
    actor->world.pos.x += (actor->velocity.x * speedRate) + actor->colChkInfo.displacement.x;
```

So a `speedXZ` value of `6.0` moves the actor **9.0 units per tick** = **180 units/second**.

- **units/tick = raw × 1.5**
- **units/second = raw × 30**

This factor is invariant across update rates (at 60 Hz the multiplier is 0.5, and 60 × 0.5 = 30),
which is why it is easy to miss. Every derived range in §6 depends on it.

### 0.3 World scale

| Quantity | Adult | Child | Source |
|---|---|---|---|
| `Player_GetHeight` (camera / attention anchor) | **68.0** | **44.0** | `[decomp: src/code/z_actor.c:1129-1137]` |
| Body collider cylinder | r **12**, h **60** | same | `[decomp: z_player.c:10463-10481]` |
| `wallCheckRadius` | **18.0** | **14.0** | `[decomp: sAgeProperties, z_player.c:425/477]` |
| `ceilingCheckHeight` | **56.0** | **40.0** | `[decomp: z_player.c:411/464]` |
| Actor scale (both ages) | 0.01 | 0.01 | `[decomp: Actor_Init, z_actor.c:947]` |
| Camera near / far plane | 10.0 / 12800.0 | — | `[decomp: View_Init, z_view.c:63-64]` |

**`UNVERIFIED:` the "1 unit ≈ 1 cm" claim is not supported by anything in the decomp.** Triangulating
three independent anchors — Link 68 u ≈ 1.6 m (≈2.35 cm/u); Longshot reach 750 u vs the lore "20 m
chain" (≈2.67 cm/u); run speed 180 u/s × 2.35 cm ≈ 4.2 m/s ≈ 15 km/h, a plausible human run — my
estimate is **1 unit ≈ 2.4 cm, i.e. ~42 units per metre**. Child Link ≈ 1.05 m. Use this for intuition
only; never fail a build on it.

---

## 1. Camera

### 1.1 How the camera data works

Camera settings are integer tables in `src/code/z_camera_data.inc.c`, scaled at load. For
`Camera_Normal1` `[decomp: z_camera.c:1622-1639]`:
```c
f32 yNormal = (1.0f + CAM_YOFFSET_NORM - CAM_YOFFSET_NORM * (68.0f / playerHeight));
sp94 = yNormal * CAM_DATA_SCALED(playerHeight);      // CAM_DATA_SCALED(x) = x * 0.01f
roData->yOffset = GET_NEXT_RO_DATA(values) * sp94;
```
with `CAM_YOFFSET_NORM = -0.1f` `[decomp: z_camera.c:182]`. So:

- **adult** → `sp94 = 0.68` — camera distances scale with player height
- **child** → `sp94 = 0.464`

**This is the single most important structural fact about OOT's camera: distance is a multiple of
the player's height, not a fixed number.** Child Link's camera sits ~32 % closer than adult Link's,
automatically.

### 1.2 Free camera — `CAM_SET_NORMAL0` / `CAM_MODE_NORMAL`

Raw: `CAM_FUNCDATA_NORM1(-20, 200, 300, 10, 12, 10, 35, 60, 60, ...)`
`[decomp: z_camera_data.inc.c:223-226]`. Resolved for adult (×0.68) `[derived]`:

| Field | Raw | Adult | Child | Meaning |
|---|---|---|---|---|
| `yOffset` | −20 | **−13.6 u** | −9.3 u | look-at point = feet + height − 13.6 ≈ **54.4 u up** (adult) |
| `distMin` | 200 | **136 u** | 92.8 u | minimum eye→at distance |
| `distMax` | 300 | **204 u** | 139.2 u | maximum eye→at distance |
| `pitchTarget` | 10 | **10° above horizontal** | | camera sits above and looks down |
| `yawUpdateRateTarget` | 12 | 12 (inverse rate — higher = slower) | | |
| `xzUpdateRateTarget` | 10 | 10 | | |
| `maxYawUpdate` | 35 | 0.35 | | ×0.01 |
| **`fov`** | 60 | **60° vertical** | | |
| `atLerpStepScale` | 60 | 0.6 | | |

Two other shipped variants, same structure `[decomp: z_camera_data.inc.c:336-339, 405-408]`:

| Setting | Raw | Adult dist | Child dist | Use |
|---|---|---|---|---|
| `NORMAL1` | `(0, 200, 400, 10, 12, 20, 40, 60, 60)` | 136–272 u | 92.8–**185.6** u | wide outdoor areas |
| `DUNGEON0` | `(−10, 150, 250, 5, 10, 5, 30, 60, 60)` | 102–170 u | 69.6–116 u | **dungeons — tighter, lower pitch (5°)** |

**Note the dungeon camera is a deliberately different, tighter setting: 102–170 u vs 136–204 u, and
5° pitch vs 10°.** Corridors get a closer, flatter camera.

### 1.3 Independent verification from a real screenshot

`[measured: refs/screens/hud_gameplay_01.png, 1280×960 = exactly 4× the native 320×240 framebuffer]`

Child Link in Hyrule Field:

| Measurement | Value |
|---|---|
| Link bounding box | x 587–705, y 505–713 |
| **On-screen height** | 208 px of 960 = **21.7 % of screen height** |
| **Horizontal position** | centre x = 646 / 1280 = **50.5 % — essentially dead centre** |
| **Feet** | y = 713 / 960 = **74.3 % down the screen** |
| **Head top** | y = 505 / 960 = **52.6 % down** |
| **Body centre** | 63.4 % down — Link sits *below* screen centre, confirming the downward pitch |

Solving the perspective for eye→at distance at 60° vertical FOV with child height 44 u:

`d = 44 / (2 × 0.2167 × tan 30°) = ` **175.9 units** `[derived]`

Checked against every shipped camera setting:

| Candidate | Child distance | Predicted screen fraction | Error vs measured |
|---|---|---|---|
| `NORMAL0` distMax | 139.2 u | 0.274 | +26.3 % |
| `DUNGEON0` distMax | 116.0 u | 0.329 | +51.6 % |
| **`NORMAL1` distMax** | **185.6 u** | **0.205** | **−5.2 %** ✅ |

**The screenshot is consistent with `CAM_SET_NORMAL1` at maximum distance, and with nothing else.**
Independent confirmation that the decomp tables describe what actually ships.

### 1.4 FOV by mode `[decomp: z_camera_data.inc.c]`

`camera->fov` → `play->view.fovy` `[decomp: z_camera.c:8264]` → `guPerspective` `[decomp: z_view.c:342]`,
where `fovy` is **vertical** FOV in degrees. Aspect 4:3, framebuffer 320×240.

| Mode | FOV |
|---|---|
| Free / `NORMAL` | **60°** |
| Z-Parallel (Z held, no target) | **45°** |
| Z-target hostile (`Battle1`) | **50°** |
| Z-target friendly (`KeepOn1`) | **45°** |
| First-person aim (bow / slingshot / boomerang) | **45°** |
| Spin-attack charge pullback | 60° |

**Low health**: at `health <= 16` (≤ 1 heart) FOV is multiplied by **0.8** and a random yaw wiggle is
injected every 256 frames `[decomp: z_camera.c:1815-1823]`. A real, shippable detail.

### 1.5 Pitch limits and interpolation

- Free-camera pitch clamp `+0x38A4` … `−0x3C8C`, with the decomp's own comment:
  **"79.65 degrees to −85 degrees"** `[decomp: z_camera.c:1772-1778]`
- Battle-camera pitch clamp **±0x2AA8 = ±59.99°** `[decomp: z_camera.c:3005-3009]`
- All smoothing is `Camera_LERPCeilF/S` — exponential ease with a minimum-step "ceil" so it always
  converges rather than asymptoting. Global rates `[decomp: z_camera.c:136-188]`:

| Constant | Value |
|---|---|
| `CAM_XZ_OFFSET_UPDATE_RATE` | 0.05 |
| `CAM_Y_OFFSET_UPDATE_RATE` | 0.05 |
| `CAM_FOV_UPDATE_RATE` | 0.05 |
| `CAM_R_UPDATE_RATE_INV` | 20 |
| `CAM_PITCH_UPDATE_RATE_INV` | 16 |
| `CAM_UPDATE_RATE_STEP_SCALE_XZ` | 0.50 |
| `CAM_UPDATE_RATE_STEP_SCALE_Y` | 0.20 |
| `CAM_DEFAULT_ANIM_TIME` | 4 ticks |
| `CAM_MAX_PITCH` | 14500 |

**Interpolation is speed-gated**: step scales are multiplied by `camera->speedRatio`
`[decomp: z_camera.c:1688-1690]`. **The camera barely moves when Link stands still and swings quickly
when he runs.** This is the "lag/spring" feel — it is not a constant-rate spring, it is a spring whose
stiffness scales with player speed. Note also `Y` updates at 0.20 vs `XZ` at 0.50: **vertical follow is
2.5× lazier than horizontal**, which is why running down a slope makes the camera trail behind
vertically.

### 1.6 Walls

`Camera_BGCheck` line-tests at→eye every frame `[decomp: z_camera.c:431-439]`. On a hit,
`Camera_Normal1` **does not** move the eye to `eyeNext`; it latches `swingYawTarget` and sets
`startSwingTimer = -1`, entering a swing state that **arcs the camera around the obstruction rather
than snapping or pushing in** `[decomp: z_camera.c:1786-1795]`. `func_80043F94` extends the ray
**+8.0 units** past the target and nudges the eye **+1 unit** off a floor it is touching `[decomp]`.

> **Acceptance:** a camera that collides by shortening its boom (the naive spring-arm approach) is
> **wrong**. OOT swings around corners on the yaw axis.
>
> **This acceptance line is TRUE ABOUT OOT AND WE DELIBERATELY DO NOT FOLLOW IT WHILE THE PLAYER IS
> STEERING (card #81).** The reason is a control scheme, not taste. **N64 OOT has no free camera
> orbit** — §1.7 below is explicit that there is no recentre button and that Z-with-no-target is the
> whole of the player's yaw authority — so in OOT the arc can never be a second mover on a yaw the
> player is holding. We ship a right stick and a mouse, and `GameCamera` builds its look direction
> from `_yaw + _swing_bias_deg`, so importing the arc wholesale imported a conflict OOT could not
> have: in a 4 m corridor the arc walked the bias against the stick and cancelled it. Measured by
> `tools/directors/cam_hall_steer.gd` — **21% of the commanded turn reached the screen** over the
> worst 0.4 s window, against 100% on open ground, then a 6.2°/tick jump-cut when the bias saturated
> at `swing_max_deg`.
>
> So we keep the arc for what this section is actually describing — the camera moving **itself**,
> where nothing else owns the yaw and a shortening boom really is the worse-looking answer — and we
> stand it down while `_manual_timer > 0.0`. Geometry keeps the **distance** either way. Do not
> "restore fidelity" here by re-enabling the arc under the stick; that is the bug, and the director
> above is the gate that catches it.

### 1.7 Recentring behind Link

There is **no separate recentre button on N64** — the task brief's "L button re-centre" is the
GameCube/3DS control. On N64, pressing **Z with no valid target** enters Parallel mode, which
recentres. `[decomp: Camera_Parallel1, z_camera.c:2210-2216]`
```c
if (roData->interfaceField & PARALLEL1_FLAG_1) {
    // Rotate roData->yawTarget degrees from behind the player.
    rwData->yawTarget = (s16)(playerPosRot->rot.y - 0x7FFF) + roData->yawTarget;
}
```
`NORMAL0`'s parallel data sets `yawTarget = 0` with `FLAG_1`, so the camera targets **exactly behind
Link**. The ease runs over `animTimer = CAM_DEFAULT_ANIM_TIME = 4` ticks with triangular-number
weighting (`tangle = ((n+1)*n)>>1`) → **4 ticks ≈ 0.20 s** `[derived]`.

Resolved Parallel values (adult): `distTarget = 250 × 0.68 =` **170 u**, `yOffset = −13.6`,
pitch target **0°**, **FOV 45°**, letterbox MEDIUM.

Player side: `Player_SetParallel` stores `parallelYaw` and, if Link is against a wall within `0x2000`
(45°), **snaps him flush to it** `[decomp: z_player.c:3243-3253]`.

### 1.8 Targeting camera — `Camera_Battle1` (hostile lock-on)

`CAM_FUNCDATA_BATT1(-20, 180, 10, 80, 0, 10, 25, 50, 80, ..., -40, 25)`
`[decomp: z_camera_data.inc.c:246-249]`

| Field | Value |
|---|---|
| `yOffset` | −13.6 (scaled) |
| **`distance`** | **180 units — raw, NOT height-scaled** (unlike Normal1/Parallel1) |
| `swingYawInitial` → `swingYawFinal` | **10° → 80°** |
| `swingPitchInitial` → `swingPitchFinal` | 0° → 10° |
| `swingPitchAdj` | 0.25 |
| **FOV** | **50°** |
| at-lerp | 0.8 grounded / 0.25 airborne |
| `yOffsetOffGround` | −27.2 |

**How Link and the target are framed together** — the key formula `[decomp: z_camera.c:3062]`:

```
swingAngle = swingYawInit + (swingYawFinal − swingYawInit) × (1.1 − distRatio)
```

The camera's off-axis angle **interpolates with target distance**: a *close* target produces a wide
(→80°) swing so both bodies fit in frame; a *distant* target produces a nearly straight-behind (→10°)
camera. This is what produces the characteristic over-the-shoulder framing, and it is dynamic, not
fixed.

`NORMAL1`'s battle variant uses `distance = 250` `[decomp]`.

**Friendly targets** (`KeepOn1`, NPCs): `(-20, 120, 140, 25, 45, -5, 15, 15, 45, 50, ...)` →
eyeDist 120→140 raw, **FOV 45°** `[decomp]`.

Mode selection `[decomp: Player_UpdateCamAndSeqModes, z_player.c:11357-11430]`:
hostile → `CAM_MODE_Z_TARGET_UNFRIENDLY` (Battle1); friendly → `CAM_MODE_Z_TARGET_FRIENDLY` (KeepOn1);
no target → `CAM_MODE_Z_PARALLEL`.

**Spin-attack charge pullback** `[decomp: z_camera.c:2951-2975]`: while
`PLAYER_STATE1_CHARGING_SPIN_ATTACK`, `chargeTimer` counts 40 → −20; past −20 the camera overrides to
`distance = 250`, `swingPitch 50→40`, `fov = 60`. **60 ticks (3.0 s) of charge before the camera pulls
back.**

---

## 2. Z-targeting

### 2.1 Acquisition range

`[decomp: src/code/z_actor.c:1688-1702]`
```c
#define ATTENTION_RANGES(range, lockOnLeashRange)  { SQ(range), (f32)range / lockOnLeashRange }

AttentionRangeParams sAttentionRanges[ATTENTION_RANGE_MAX] = {
    ATTENTION_RANGES(70, 140),  ATTENTION_RANGES(170, 255),  ATTENTION_RANGES(280, 5600),
    ATTENTION_RANGES(350, 525),                      // ATTENTION_RANGE_3 — the default
    ATTENTION_RANGES(700, 1050), ATTENTION_RANGES(1000, 1500), ATTENTION_RANGES(100, 105.36842),
    ATTENTION_RANGES(140, 163.33333), ATTENTION_RANGES(240, 576), ATTENTION_RANGES(280, 280000),
};
```

Acquisition range is the **first** number, used directly (`Attention_ActorIsInRange` compares
`distSq < attentionRangeSq`).

**Default = `ATTENTION_RANGE_3` = 350 units** ≈ 8.4 m ≈ **5.1 adult-Link-heights**.

### 2.2 Break (leash) distance — and a correction worth knowing

The second column is stored as a *linear* ratio but applied to a *squared* distance
`[decomp: z_actor.c:1737]`:
```c
return !Attention_ActorIsInRange(actor, distSq * sAttentionRanges[...].lockOnLeashScale);
```
So the true break distance is `sqrt(range × leash)`, **not** the leash column. `[derived]`

| Type | Acquire | Leash column | **Actual break distance** |
|---|---|---|---|
| 0 | 70 | 140 | 99.0 |
| 1 | 170 | 255 | 208.2 |
| 2 | 280 | 5600 | 1252.2 |
| **3 (default)** | **350** | 525 | **428.7** |
| 4 | 700 | 1050 | 857.3 |
| 5 | 1000 | 1500 | 1224.7 |
| 6 | 100 | 105.37 | 102.6 |
| 7 | 140 | 163.33 | 151.2 |
| 8 | 240 | 576 | 371.8 |
| 9 | 280 | 280000 | 8854.4 (effectively infinite) |

**Default: acquire at 350 u, break at 429 u.** The ~22 % hysteresis band is deliberate — it stops the
lock flickering at the edge of range.

### 2.3 The search cone — it is *not* "nearest enemy"

`[decomp: Attention_WeightedDistToPlayerSq, z_actor.c:1655-1681]` — comments verbatim from the decomp:

- **No current lock-on:** `if (yawTempAbs > 0x2AAA) return MAXFLOAT;`
  → *"Player has to be facing less than ~60 degrees away from the actor."*
  **A ±60° cone off Link's facing — a 120° arc.**
- **Already locked on** (switching targets): the cone widens to `0x4000` = **±90°**, and distance is
  *weighted toward what you are facing*:
  *"At 90 degrees, 100% of the original distance will be returned. This scales down linearly to 60%
  when facing 0 degrees away."*
  `adjDistSq = distSq − distSq × 0.8f × ((0x4000 − yawTempAbs) / 0x8000)`

So a target dead ahead is treated as **40 % closer than it is** when choosing the next lock.

### 2.4 The other four acquisition filters

`[decomp: Attention_FindActorInCategory, z_actor.c:3471-3517]`. A candidate must satisfy **all** of:

1. `update != NULL` and `ACTOR_FLAG_ATTENTION_ENABLED`
2. Not the current focus actor
3. Nearest **weighted** distance so far (§2.3)
4. In range and in cone (§2.1–2.3)
5. **On screen, with asymmetric leeway** `[decomp: Attention_ActorOnScreen, z_actor.c:3432-3442]`:
   `X_LEEWAY 20`, `Y_LEEWAY 160` on a 320×240 screen → valid x ∈ [−20, 340], y ∈ [−160, 400].
   **Horizontally strict, vertically extremely loose** — you can lock something well above or below
   the frame but barely off the sides.
6. **Line of sight**: `BgCheck_CameraLineTest1` from `player->actor.focus.pos` to `actor->focus.pos`
   must not hit geometry, unless the poly is `SurfaceType_IsIgnoredByProjectiles`.

**Category priority** `[decomp: z_actor.c:3518-3521]`: Boss, Enemy, Bg are searched first; only if all
three yield nothing does it fall through to NPC, ItemAction, Chest, Switch, Prop, Misc, Door. An actor
with non-zero `attentionPriority` (lower = higher) beats plain nearest. The locked actor is forced to
`attentionPriority = 40` each frame `[decomp: z_player.c:3989]`.

> **Acceptance:** "lock the nearest enemy" is **wrong**. The correct algorithm is:
> category priority → ±60° cone → range → on-screen (asymmetric) → line-of-sight → facing-weighted
> nearest.

### 2.5 Hold vs. switch, and the acquisition grace period

`[decomp: z_player.c:3900-4020]`

- Mode read from `gSaveContext.zTargetSetting`; **Hold** when non-zero. Dark Link always forces Hold.
- On a new lock: `zTargetActiveTimer = 15`, decaying toward a floor of 5 while Z is held.
- `if (this->zTargetActiveTimer >= 6) ignoreLeash = true;` — decomp comment: *"During this 10 frame
  period, set `ignoreLeash` so that the lock-on will temporarily have an infinite leash distance. This
  gives time for the reticle to settle."*
  **10 ticks = 0.5 s of infinite leash on acquisition.**
- Pressing Z while locked cycles to `arrowHoverActor`; in Switch mode, pressing Z on the same actor
  releases.
- Holding **backward** on the stick suppresses the next-target arrow entirely
  `[decomp: z_actor.c:517-527]` — an explicit escape hatch out of lock-on loops.

**Release conditions** `[decomp: Attention_ShouldReleaseLockOn, z_actor.c:1726-1741]`:
`update == NULL` (target died), `ACTOR_FLAG_ATTENTION_ENABLED` cleared, or beyond the effective leash
(§2.2). Note: the yaw component here uses 60° but is unreachable in practice — the decomp itself flags
this. **Losing line of sight does NOT break an established lock** — only acquisition tests LOS.

### 2.6 The reticle

`[decomp: Attention_Update, z_actor.c:610-634]`

| Behaviour | Value |
|---|---|
| Zoom-in | radius **500 → 80**, step `CLAMP((500 − radius) × 3.0f, 30.0f, 100.0f)` |
| Settle time | ~**8 ticks ≈ 0.4 s** `[derived]` (starts at the 100 cap, tapers to the 30 floor) |
| Settled state | `reticleSpinCounter = (counter + 3) \| 0x80`; radius latches to **120.0**; reticle **spins** (0x80 × 0x200 = one full turn) |
| Release | radius expands back to 500 at **80/tick** |
| Trail | **three** reticle instances drawn for motion blur (`lockOnReticles[3]`) |
| SFX | `NA_SE_SY_LOCK_ON` hostile / `NA_SE_SY_LOCK_ON_HUMAN` otherwise |

The reticle (but **not** the lock-on) releases if the target leaves the projected frustum — the decomp
explicitly flags this as possibly a bug.

**Appearance** `[measured: refs/screens/ztarget_lockon_01.png, ztarget_lockon_02.png, ztarget_lockon_03.png]`:
the reticle is **four filled triangles** pointing inward at the target's cardinal points (top, bottom,
left, right) — not a circle, not a crosshair. **Colour encodes target type: yellow for enemies
(`ztarget_lockon_01`, `_03`), pale blue/lavender for friendly/informational targets
(`ztarget_lockon_02`, a Kokiri NPC).**

### 2.7 The letterbox bars

`[decomp: Camera_UpdateInterface, z_camera.c:929-955]`

| Constant | Scanlines | Used by |
|---|---|---|
| `CAM_LETTERBOX_SMALL` | 26 | |
| **`CAM_LETTERBOX_MEDIUM`** | **27** | **all Z-targeting and first-person aim modes** |
| `CAM_LETTERBOX_LARGE` | 32 | cutscenes, `TALK` |
| `CAM_LETTERBOX_NONE` | 0 | |

Applied as a **scissor inset**, not an overlay quad `[decomp: z_view.c:176-197]`:
```c
uly = view->viewport.topY + letterboxSize;
lry = view->viewport.bottomY - letterboxSize;
gDPSetScissor(POLY_OPA_DISP++, G_SC_NON_INTERLACE, ulx, uly, lrx, lry);
```

**Slide-in** `[decomp: src/code/shrink_window.c, Letterbox_Update(R_UPDATE_RATE)]`:
```c
if (updateRate == 3) { step = 10; } else { step = 30 / updateRate; }
```

`[derived]` At `updateRate = 3` the size steps **0 → 10 → 20 → 27**: **3 ticks = 0.15 s** to fully
deploy, same to retract.

At full deployment: **27 / 240 = 11.25 % of screen height at each edge**; the playfield shrinks to
**186 of 240 lines (77.5 %)**, giving a **visible aspect of 320:186 ≈ 1.72:1**.

**Screenshot cross-check** `[measured]`. Two independent captures:

| File | Top bar | Bottom bar |
|---|---|---|
| `item_hookshot_firstperson_aim_01.png` (912×684 PNG) | 48 px = 7.02 % | 57 px = **8.33 %** |
| `ztarget_lockon_03.png` (365×273 JPEG) | 20 px = 7.33 % | 22 px = **8.06 %** |

**8.33 % is exactly 20/240 — step 2 of the 0→10→20→27 slide.** Both frames were captured
mid-animation. The ~1 % top/bottom asymmetry is consistent with a few scanlines of overscan cropped
at the top by the capture. This corroborates the *animation steps*; **use the decomp's 27 scanlines
(11.25 %) as the target for the settled state.**

### 2.8 "No target" mode (Z held with nothing lockable)

`Player_SetParallel` `[decomp: z_player.c:3243]`, setting `PLAYER_STATE1_PARALLEL`. Effects:

- camera recentres exactly behind Link over 4 ticks (§1.7) at **FOV 45°**
- **MEDIUM letterbox deploys anyway** — the bars are not exclusive to having a target
- Link strafes relative to the stored `parallelYaw`
- movement switches to `SPEED_MODE_LINEAR` — **the 20-unit stick deadzone disappears** (§3.2)
- wall-snap if Link is within 45° of a wall

---

## 3. Movement

All raw values below are `speedXZ`. **× 1.5 = units/tick, × 30 = units/second** (§0.2).

### 3.1 Speed caps — `[decomp: sBootData, src/code/z_player_lib.c:31-151]`

| Boots | `R_RUN_SPEED_LIMIT` | Raw | units/tick | **units/sec** |
|---|---|---|---|---|
| **Kokiri (adult)** | 600 | 6.0 | 9.0 | **180** |
| Kokiri (child) | 550 | 5.5 | 8.25 | **165** |
| Iron | 300 | 3.0 | 4.5 | 90 |
| Hover | 550 | 5.5 | 8.25 | 165 |
| Indoor | 500 | 5.0 | 7.5 | **150** |
| Iron underwater | 550 | 5.5 | 8.25 | 165 |

**Note the "Indoor" boot entry: Link is 17 % slower inside buildings/dungeons than outdoors.**

Other registers from the same table `[decomp]`: `R_DECELERATE_RATE = 800` → **8.0 units/tick² hard
stop**; `REG(19) = 200` → **accel 2.0**; `REG(68) = −100` → gravity −1.0 (−1.6 with Iron Boots);
`REG(27) = 2000` turn rate → **~11°/tick ≈ 220°/s**.

Independently confirmed: zeldaspeedruns datamines "Kokiri Boots max run = 9 units/frame at 20 fps"
and notes internal velocity reads ⅔ lower — exactly the ×1.5 factor. **Two independent sources agree.**

### 3.2 Analog stick — there is no walk/run threshold

`[decomp: Lib_GetControlStickData, src/code/z_lib.c:229-237]`
```c
*outMagnitude = sqrtf(SQ(relX) + SQ(relY));
*outMagnitude = (60.0f < *outMagnitude) ? 60.0f : *outMagnitude;
```
**Magnitude is clamped to 0–60**, not 0–127. (The brief's "0–127" is the raw hardware range; the
game's post-centering values saturate near 60.)

`[decomp: Player_CalcSpeedAndYawFromControlStick, z_player.c:4040-4104]`, with the decomp's own comment:
> *"Curved mode drops any input below 20 units of magnitude, resulting in zero for target speed.
> Beyond 20 units, a gradual curve slowly moves up until around the 40 unit mark when target speed
> ramps up very quickly."*

```c
// SPEED_MODE_CURVED (free roam)
*outSpeedTarget -= 20.0f;
if (*outSpeedTarget < 0.0f) { *outSpeedTarget = 0.0f; }
else { temp = 1.0f - Math_CosS(*outSpeedTarget * 450.0f);
       *outSpeedTarget = (SQ(temp) * 30.0f) + 7.0f; }
// SPEED_MODE_LINEAR (Z-strafe): *outSpeedTarget *= 0.8f;
// both then: *outSpeedTarget = (*outSpeedTarget * 0.14f) - (8.0f * slope²);  CLAMP(0, speedCap)
```

> **This is the single most-often-got-wrong movement fact.** There is **no discrete walk/run state**.
> Speed is a continuous curve of stick magnitude: **< 20 → standing still (deadzone)**; 20–40 → slow
> ramp; **> 40 → rapid ramp to the cap**. The walk↔run *animation* is a continuous blend driven by
> speed, not a state machine transition.

Separately, `Player_ProcessControlStick` requires **magnitude ≥ 55** to register a discrete cardinal
direction `[decomp: z_player.c:2214]` — **that** is the threshold for roll / backflip / sidehop /
turn-around detection.

Uphill penalty: `− 8.0f × sin(floorPitch)²`, sine clamped to 0.6 `[decomp]`.

### 3.3 Acceleration and deceleration

| Context | Accel | Decel | Source |
|---|---|---|---|
| Generic ground move (`func_8083DF68`) | **2.0** | 1.5 | `[decomp: z_player.c:7165]` |
| Running (`Player_Action_8084193C`) | **2.0** | 3.0 | `[decomp: z_player.c:8651]` |
| Stick released (`Player_DecelerateToZero`) | — | **8.0** | `[decomp: z_player.c:4113]` |
| Yaw > `0x6000` (~135°) from target | speed snapped toward 0 at 1.0/tick, then reorients | | `[decomp: z_player.c:7177]` |

`[derived]` Accel 2.0 raw/tick to a 6.0 cap = **3 ticks (0.15 s) from standstill to full sprint**.
Decel 8.0 on stick release = **under 1 tick** to stop from full speed.

**The skid/slide when you stop from a sprint is therefore not a deceleration ramp** — the *velocity*
stops almost instantly. The visible skid is the animation (`Player_Action` landing/brake states)
playing out over its own length while the character is already at rest. Reproduce it as an animation,
not as friction.

The **turn-around** is the `0x6000` (~135°) rule: reversing direction does not steer, it kills speed
at 1.0/tick and then re-orients — which is why sharp reversals in OOT feel like a distinct move.

### 3.4 Roll, backflip, sidehop `[decomp: z_player.c:6375, 9753-9765, 9697-9699]`

| Move | Raw speed | units/tick | **units/sec** | i-frames |
|---|---|---|---|---|
| **Roll** (A while running) | walk target × 1.5, min 3.0 | **13.5** at cap | **270** | **10** (NTSC) / 8 (PAL), from anim frame 8 |
| **Backflip** (Z + back + A) | 6.0 | 9.0 | 180 | none found |
| **Sidehop** (Z + left/right + A) | 8.5 | **12.75** | **255** | none found |

```c
this->speedXZ = !(controlStickDirection & 1) ? 6.0f : 8.5f;   // even = backflip, odd = sidehop
```
Roll ends at animation frame 20. All three cross-confirmed against zeldaspeedruns' datamined
13.5 / 9 / 12.75.

> **Sidehop (255 u/s) and roll (270 u/s) are both faster than running (180 u/s).** This is why
> speedrunners sidehop everywhere, and it is a real property of the game, not an exploit — if our
> dodges are slower than our run, the movement will not feel like OOT.

Roll invulnerability `[decomp: z_player.c:9697-9699]`:
```c
if (LinkAnimation_OnFrame(&this->skelAnime, 8.0f)) {
    Player_SetInvulnerability(this, FRAMERATE_CONST(-10, -8));
}
```
The decomp distinguishes **invulnerability** (negative timer — blocks damage only) from
**intangibility** (positive timer — blocks damage *and* reactions like knockback)
`[decomp: z_player.c:4559-4591]`.

`UNVERIFIED:` the **roll's shoulder-bash into walls**. I found the roll speed and i-frames but not a
distinct wall-impact damage/stun. My estimate: it is the ordinary roll collider meeting the wall and
triggering the standard bonk reaction, not a special attack. Do not fail a build on this line.

---

## 4. Combat

### 4.1 Sword damage is defined per-enemy, not per-sword

This is structural and worth getting right. Link's melee colliders carry **only a damage-type
bitflag, no number** `[decomp: func_80837918, z_player.c:4498-4506]`:
```c
this->meleeWeaponQuads[quadIndex].elem.atDmgInfo.dmgFlags = dmgFlags;
```
The flags `[decomp: include/collision_check.h:412-451]`: `DMG_SLASH_KOKIRI/MASTER/GIANT` (bits 8-10),
`DMG_SPIN_KOKIRI/GIANT/MASTER` (22-24), `DMG_JUMP_KOKIRI/GIANT/MASTER` (25-27), plus `DMG_EXPLOSIVE`,
`DMG_ARROW_*`, `DMG_HOOKSHOT`, `DMG_DEKU_STICK`, `DMG_HAMMER_*`, `DMG_MIR_RAY`.

**Each enemy owns a `DamageTable` mapping flag → `DMG_ENTRY(damage, reaction)`.** Representative —
Stalfos, health 10 `[decomp: ovl_En_Test/z_en_test.c:224-256]`:

| Weapon | Slash | **Jump attack** | Spin attack |
|---|---|---|---|
| Kokiri Sword | 1 | **2** | 1 |
| Master Sword | 2 | **4** | 2 |
| Giant's Knife / Biggoron | 4 | **8** | 4 |

**Jump attack is a clean 2× multiplier. Spin attack is 1× — no damage bonus at all**; its value is
area coverage, not power.

`UNVERIFIED:` whether spin = slash holds for *every* enemy. This is one representative table; enemies
can define arbitrary armour/weakness. Also `UNVERIFIED:` whether these integers map onto Link's
16-units-per-heart scale — they are points off that actor's own HP pool.

### 4.2 The attack set and how each is triggered

| Attack | Trigger | Notes |
|---|---|---|
| Vertical / horizontal slash | B, un-targeted | direction varies with animation state |
| **Stab** | **Z-targeted + forward on stick + B** | only available while targeted |
| **Jump attack** | **Z-targeted + B** from neutral, or run + B untargeted | 2× damage (§4.1) |
| Spin attack | hold B to charge, release (§4.3) | or full stick rotation for an instant spin |

Jump-attack launch velocities `[decomp: z_player.c:6338-6345, 6398-6400]`:
**un-targeted xz 3.0 / y 4.5; Z-targeted xz 5.0 / y 5.0.**

> **Targeting changes the attack set**, it does not merely lock the camera. The stab and the
> forward-lunging jump attack exist only in the targeted stance.

### 4.3 Spin attack `[decomp: z_player.c:9870, 9826, 4362-4364, 9833, 9894, 4376]`

| Property | Value |
|---|---|
| Charge meter `unk_858` | steps toward 1.0 at **+0.02/tick** |
| Full spin threshold | **≥ 0.85** → `PLAYER_MWA_BIG_SPIN_*`; below → weak spin |
| **Time to full charge** | 0.85 / 0.02 = **43 ticks ≈ 2.15 s** `[derived]` |
| Time to max meter | 50 ticks = 2.5 s `[derived]` |
| Minimum for any spin | 0.1 = **5 ticks** |
| **I-frames on release** | **8 ticks = 0.4 s** |
| Quick spin | `Player_CanSpinAttack` detects a **full stick rotation → instant spin, no charge** |

Note the camera does not pull back until **60 ticks (3.0 s)** of charge (§1.8) — i.e. *after* the spin
is already fully charged at 43 ticks. The pullback is a flourish, not a readiness cue.

### 4.4 Invincibility, knockback, flash

**Link's i-frames after taking damage: 20 ticks = 1.0 second.** Passed as the literal `20` at every
standard damage site `[decomp: z_player.c:4877-4878, and 4954, 4969, 9145, 9788, 13902]`:
```c
func_80837C0C(play, this, knockbackResponse[this->knockbackType - 1], this->knockbackSpeed,
              this->knockbackYVelocity, this->knockbackRot, 20);
```
`func_808382BC` floors it at 20 if lower. A big-fall impact grants **40 ticks** `[decomp: z_player.c:9511]`.

Damage flicker: `damageFlickerAnimCounter += CLAMP(50 − invincibilityTimer, 8, 40)`, driving a red fog
pulse `[decomp: z_player.c:12272-12275]`.

**Enemy flash-on-hit**: `Actor_SetColorFilter(actor, colorFlag, intensityMax, bufFlag, duration)` sets
`colorFilterTimer` — **per-enemy, no global constant** `[decomp: z_actor.c:4198-4206]`. Observed call
sites: **5** (Gohma), **8** (Stalfos, Dinolfos, Gerudo, Anubis — the common case), 10, 12, 20, 24,
35–42 (Deku Baba), 40 (Keese), 60, 80. **Typical 8–12 ticks = 0.4–0.6 s.**

### 4.5 Hit-stop — OOT does not have it

`UNVERIFIED-by-absence:` a grep across `z_actor.c`, `z_collision_check.c` and `z_player.c` found **no
global pause-on-impact mechanism**. What OOT does on impact instead is **camera quake**
(`Player_RequestQuake` / `Camera_RequestQuake`) and Rumble Pak pulses.

> I am flagging this rather than inventing a frame count. If our build wants hit-stop for feel, that is
> a deliberate *deviation* from OOT and should be argued as one — not defended as fidelity.
> Bomb explosion quake for calibration: `Camera_RequestQuake(&play->mainCamera, 2, 11, 8)`
> `[decomp: z_en_bom.c:336]`.

### 4.6 Shield

`UNVERIFIED:` I could not source the shield's **block cone half-angle**. Reasoning for an estimate:
Link auto-blocks while standing still with a shield equipped and not attacking, and blocking is
implemented as a collider on the shield quad rather than an angular test, so the effective cone is the
shield's geometric coverage — plausibly **±45°–60° off facing**. Treat as an estimate.
Sourced and related: `Player_SetParallel` wall-snap uses `0x2000` = 45° `[decomp]`, which is at least
evidence that 45° is the engine's habitual "facing roughly at" tolerance.

Visual reference: `refs/screens/combat_link_blocking_01.png`, `refs/screens/art_link_shield_pose_01.png`.

---

## 5. Items

### 5.1 Hookshot and Longshot `[decomp: ovl_Arms_Hook/z_arms_hook.c]`

`ArmsHook_Wait`, lines 95-106:
```c
s32 length = (player->heldItemAction == PLAYER_IA_HOOKSHOT) ? 13 : 26;
Actor_SetProjectileSpeed(&this->actor, 20.0f);
this->timer = length;
```
Flight uses `Actor_MoveXZGravity` (line 284) **with gravity never set → perfectly straight, no arc.**
`DECR(timer) == 0` (line 189) switches to retract, so flight lasts `length − 1` ticks.

`[derived]` speed 20.0 × 1.5 = **30 units/tick**:

| | Timer | Flight ticks | **Max reach** | ≈ metres @ 2.4 cm/u |
|---|---|---|---|---|
| **Hookshot** | 13 | 12 | **~360 units** | ~8.6 m |
| **Longshot** | 26 | 25 | **~750 units** | ~18 m |

Also `[decomp]`: detach if the hooked actor drifts **> 50 units**; retract speeds **30** (pulling Link)
/ **50** (with an attached actor) / **200** (empty, no hit) units per tick.

> **Pull semantics:** the retract speed differs by case — 30 when Link is being pulled to a fixed
> anchor, 50 when an actor is being pulled to Link. Which one happens is decided by whether the hooked
> actor is flagged grabbable/heavy, not by the hookshot.

Visual reference: `refs/screens/item_hookshot_firstperson_aim_01.png` shows the first-person aim with
the reticle and the **red laser dot** on the target surface, plus the letterbox.

### 5.2 Bombs `[decomp: ovl_En_Bom/z_en_bom.c]`

| Quantity | Value | Line |
|---|---|---|
| **Fuse** | `this->timer = 70;` → **70 ticks = 3.5 s** | 112 |
| Explosion phase | `timer = 10` → **10 ticks = 0.5 s** | 341 |
| **Blast radius growth** | `worldSphere.radius += shape.rot.z + 8;` = **+8 units/tick** (`rot.z = 0` for normal bombs) | 191 |
| **Peak blast radius** | **~80 units (~1.9 m)** `[derived: 8 × 10]` | |
| **Damage** | `{ 0x00000008, ..., 0x08 }` = **8 raw units** | 71 |
| **In hearts** | 16 units = 1 heart → **8 = ½ heart = 2 quarter-hearts** | `z_parameter.c` |
| **Can Link hurt himself?** | **YES** — collider is `AT_ON \| AT_TYPE_ALL` with **no owner exemption** | 82-88 |
| Bomb body collider | radius 6, height 11, yShift 14 | `sCylinderInit` |
| Gravity / bounce / friction | −1.2 per tick; wall rebound ×0.7; ground friction 1.0/tick | 246, 155, 159 |
| Screen shake | `Camera_RequestQuake(&play->mainCamera, 2, 11, 8)` | 336 |
| **Bombchu** | timer **120 ticks = 6.0 s**; ground speed 8.0 raw = **12 units/tick**; spawns a real `EN_BOM` with `timer = 0` to detonate | `z_en_bom_chu.c:107, 248, 123` |

### 5.3 Bow and arrows `[decomp: ovl_En_Arrow/z_en_arrow.c:203-210, 273-274]`

```c
if (this->actor.params >= ARROW_SEED) { Actor_SetProjectileSpeed(&this->actor, 80.0f);  this->timer = 15; }
else                                  { Actor_SetProjectileSpeed(&this->actor, 150.0f); this->timer = 12; }
...
if (this->timer < 7.2000003f) { this->actor.gravity = -0.4f; }
```

`[derived]` (×1.5):

| | Raw | units/tick | Flight ticks | Max range | Arc |
|---|---|---|---|---|---|
| **Arrow** (all types) | 150.0 | **225** | 11 | **~2475 u (~59 m)** | **flat for ~4 ticks**, then −0.4/tick² for ~7 |
| **Slingshot seed / thrown Deku Nut** | 80.0 | **120** | 14 | ~1680 u (~40 m) | same rule |

> **Arrows are effectively hitscan at combat range.** An arrow crosses the entire 350-unit Z-target
> acquisition range in **under 2 ticks**, before gravity engages at all. Drop only becomes visible past
> roughly 900 units. Do not model a visible arc at normal engagement distance.

**First-person aim mode**: camera `CAM_MODE_AIM_ADULT`,
`CAM_FUNCDATA_SUBJ3(-7, 14, 50, 10, 0, -30, -5, 45, ...)` → **FOV 45°, MEDIUM letterbox**
`[decomp: z_camera_data.inc.c:260-284]`. Child/slingshot variant `(-7, 14, 50, 10, -9, -63, -30, 45)`.

Boomerang throw speed **12.0 raw = 18 units/tick** `[decomp: z_en_boom.c:161]`.

Ammo: quiver 30 / 40 / 50; bomb bag 20 / 30 / 40 `[guide]`.

---

## 6. Dungeon structure

**The full room-by-room graph, loop analysis and acceptance rules live in
`refs/structure/dungeon_structure.md`.** Summary of the numbers a critic needs here:

| | Inside the Deku Tree (`ydan`) | Forest Temple (`Bmori1`) |
|---|---|---|
| Rooms in scene | **12** `[decomp: ydan.xml]` | **23** `[decomp: Bmori1.xml]` |
| Boss scene rooms | 2 (`ydan_boss`) | 2 (`moribossroom`) |
| **Small keys** | **0** | **5** |
| **Locked doors** | **0** | **5** |
| Boss Key | none (plain barred door) | 1 key, 1 door |
| Dungeon item | Fairy Slingshot | **Fairy Bow** |
| Chests | 6 | 13 |
| Gold Skulltulas | 4 | 5 |

**The load-bearing structural facts:**

1. **`keys == locks`, exactly.** Forest Temple: 5 = 5. No spare keys, no spare locks.
2. **All five locks sit on one linear chain**, and every room on that chain has exactly two doors
   (one in, one out). There is no branch on which a key can be spent wrongly — the dungeon is
   **softlock-proof by topology**, not by a safety check.
3. **The dungeon item sits at the midpoint of the key chain.** Locks 1–3 are pre-Bow; locks 4–5 are
   post-Bow, and *both* of their keys are themselves Bow-gated.
4. **The item retroactively unlocks ≥ 3 things already walked past** — two rooms of Poe paintings, a
   grey eye switch, a fenced gold eye switch, a frozen eye switch.
5. **The map loops back on itself constantly.** Nine identified cycles (F1–F9), including **three
   one-way drops that land you in an *earlier* room**, one shortcut opened from the far side, and
   **toggleable topology** (the twisted corridor is straightened and re-twisted with the same switch).
6. **Rooms do double duty.** `[decomp/rando]` `Lower Stalfos Pot 1/2` and `Upper Stalfos Pot 1–4` are
   **both in room 6** — the Fairy Bow arena is the upper storey of the room where you fought two
   Stalfos in the first ten minutes, and falling during the Bow fight drops you back to the early
   game. **A 23-room count vastly overstates how many distinct spaces the player experiences.**
7. Map and Compass are **off** the critical path; the Boss Key is **on** it, behind the dungeon item.
8. The boss always lives in a **separate scene** with its own small room count (2 in both dungeons).

---

## 7. HUD

The N64 HUD is authored in a **320×240** space. All native coordinates below are
`[measured: refs/screens/hud_gameplay_01.png]`, which is **1280×960 = exactly 4× native**, so native
values are the measured pixels ÷ 4. Percentages are resolution-independent and are what a critic
should check.

> **Correction to a common misconception (and to the task brief):** in OOT on N64 the B button and the
> three C-buttons are at the **TOP-RIGHT**, not the bottom-right. Only the rupee counter and the
> minimap live at the bottom. Verified in `hud_gameplay_01.png`, `ztarget_lockon_02.png`,
> `item_hookshot_firstperson_aim_01.png`, `combat_stalfos_01.png` and `dungeon_block_puzzle_01.png`.

### 7.1 Element positions

| Element | Native (320×240) | % of screen | Notes |
|---|---|---|---|
| **Hearts** — block origin | x **25.75**, y **22.5** | x 8.05 %, y 9.4 % | top-left |
| Heart glyph size | **8.25 × 7** px | 2.6 % of width | |
| **Heart pitch (horizontal)** | **10.0 px** | 3.13 % of width | measured across 10 columns |
| Heart pitch (vertical) | **8.75 px** | 3.65 % of height | |
| Hearts per row | **10**, wrapping to a second row below | | 20 hearts max |
| **Magic bar** — green fill | x **26.25–121.75**, y **46.5–50.5** | x 8.2–38.0 %, y 19.4–21.0 % | directly under the hearts; **~96 px long, ~4 px tall** at full double-magic |
| **Rupee counter** — icon | x **27.5–40.75**, y **207–220** | x 8.6–12.7 %, y 86.3–91.7 % | bottom-left; digits immediately right at x ≈ 43–57 |
| **B button** (sword) centre | x **174**, y **30** | 54.4 %, 12.5 % | green disc |
| **A button** (context label) centre | x **207.5**, y **29.5** | 64.8 %, 12.3 % | blue disc; label text to its right ("Put Away", "Speak", "Grab", "Open", "Return") |
| **C-Left** centre | x **240**, y **30** | 75.1 %, 12.5 % | |
| **C-Down** centre | x **261**, y **46** | 81.6 %, 19.3 % | **lower and between** C-Left and C-Right |
| **C-Right** centre | x **284**, y **30.5** | 88.8 %, 12.7 % | |
| Item button disc diameter | ~**26 px** | ~8 % of width | |
| **Minimap** | x 228–292, y 154–219 | x 71.2–91.2 %, y 64.2–91.2 % | bottom-right; cyan wireframe |

### 7.2 Layout rules worth stating explicitly

- **The left margin is shared.** Hearts (x ≈ 25.75) and the rupee counter (x ≈ 27.5) sit on
  essentially the same left edge, ~26 px in — **8 % of screen width**.
- **The three C-buttons are arranged in the physical shape of the N64 C-pad**: C-Left and C-Right at
  the same height, C-Down lower and horizontally between them. This is diegetic — the HUD mirrors the
  controller.
- **Vertical stack on the left is hearts → magic bar**, with the magic bar starting at the same x as
  the hearts.
- The minimap is a **translucent filled teal shape with a bright cyan 1px border**, dark outer
  drop-shadow, and thin cyan interior lines marking paths/features — *not* a wireframe outline, and
  *not* opaque. The player marker is a **red arrowhead with a yellow facing-cone** attached
  `[measured: hud_gameplay_01.png]`.
- A timer, when active, appears under the magic bar at native y ≈ 55 with a clock icon
  (`item_hookshot_firstperson_aim_01.png`).

---

## 8. Look and lighting

Sources are `[measured]` from the dungeon and boss screenshots in `refs/screens/` unless tagged
otherwise. These are the numbers that make an art-direction critique falsifiable.

### 8.1 Resolution, aspect and filtering

| Property | Value |
|---|---|
| Framebuffer | **320 × 240**, 4:3 `[decomp: SCREEN_WIDTH/SCREEN_HEIGHT]` |
| Vertical FOV | 60° free / 50° battle / 45° parallel & aim (§1.4) |
| Near / far plane | **10.0 / 12800.0** `[decomp: z_view.c:63-64]` |
| Texture filtering | bilinear with the N64's **3-point** sampling — visibly triangular, not box |
| Texture resolution | N64 TMEM is 4 KB; typical world textures are **32×32 or 64×32 at 4-bit/8-bit CI**. `UNVERIFIED:` per-texture sizes vary; this is the platform envelope, not a measured average. |
| Lighting model | **vertex lighting**, no per-pixel lights; shading is baked into vertex colours plus a small number of dynamic point lights |
| Fog | per-room, colour and near/far set per scene; used heavily to hide the draw distance and to tint |

### 8.2 Measured dungeon lighting

Mean linear-luminance and saturation over the full frame, across the dungeon interiors I downloaded
`[measured]`:

| Statistic across all 24 `dungeon_*` frames | Value |
|---|---|
| **Median mean-luminance** | **41.4 / 255 (16.2 %)** |
| Luminance range | **31.5** (Deku Tree interior) … **110.9** (sunlit Deku Tree 3F) — only **1 of 24** frames exceeds 90 |
| **Median mean-saturation** | **0.52** |
| Saturation range | **0.22** (Water Temple) … **0.83** (Dodongo false wall) |
| **Warm bias `mean(R) − mean(B)`** | **positive in 22 of 24** frames; the two exceptions are `dungeon_forest_temple_exterior_01` (−2.2) and `dungeon_shadow_scythes_01` (−0.4), both essentially neutral |

Per-theme, the hue commitment is the signature:

| Frame | mean RGB | luminance | R−B | saturation |
|---|---|---|---|---|
| `dungeon_deku_tree_interior_01` | (44.5, 29.8, 10.1) | 31.5 | **+34.4** | 0.79 |
| `dungeon_deku_tree_f1_01` | (52.1, 41.6, 16.5) | 42.1 | **+35.6** | 0.69 |
| `dungeon_dodongos_cavern_01` | (41.4, 35.5, 9.8) | 34.9 | **+31.6** | 0.79 |
| `dungeon_false_wall_dodongo_01` | (120.3, 36.8, 19.9) | 53.3 | **+100.5** | 0.83 |
| `dungeon_fire_temple_01` | (66.8, 44.2, 13.3) | 46.8 | **+53.5** | 0.80 |
| `dungeon_spirit_temple_01` | (89.1, 57.3, 40.0) | 62.8 | **+49.1** | 0.53 |
| `dungeon_ganons_castle_01` | (73.9, 42.4, 12.6) | 47.0 | **+61.4** | 0.61 |
| `boss_king_dodongo_chamber_01` | (69.5, 31.3, 9.6) | 37.9 | **+60.0** | 0.84 |
| `boss_volvagia_01` | (77.2, 17.9, 4.4) | 29.5 | **+72.9** | 0.95 |
| `dungeon_forest_entrance_hall_01` | (35.8, 38.7, 31.9) | 37.6 | +3.9 | 0.32 |
| `dungeon_shadow_temple_01` | (26.3, 36.0, 21.4) | 32.9 | +4.8 | 0.40 |
| `dungeon_water_temple_01` | (52.9, 51.3, 47.5) | 51.4 | +5.4 | **0.22** |
| `boss_phantom_ganon_01` | (23.3, 33.1, 25.7) | 30.5 | **−2.5** | 0.38 |
| `boss_morpha_01` | (37.9, 77.7, 94.4) | 70.4 | **−56.5** | 0.63 |
| `boss_bongo_bongo_02` | (31.0, 33.9, 57.1) | 34.9 | **−26.2** | 0.71 |

> **Falsifiable acceptance criteria for our dungeon lighting**, each stated so that **every one of the
> 24 reference frames passes it** — a criterion that fails real OOT is worse than no criterion:
>
> - **Mean frame luminance 30–70 of 255 (12–27 %).** 23 of 24 reference frames land in this band. The
>   one exception (`dungeon_deku_tree_f3_01`, 110.9) is a room with direct sunlight through the canopy,
>   so **a frame above 90 needs a visible in-world light source to justify it.**
> - **Mean saturation 0.22–0.85, median ≈ 0.5.** Do **not** impose a 0.4 floor: the grey-stone rooms
>   (Water Temple 0.22, Forest arena 0.25, Shadow Temple room 0.26, block puzzle 0.28) are genuinely
>   desaturated. The correct statement is that **saturation tracks the theme** — fire/wood rooms run
>   0.6–0.95, stone/water rooms run 0.22–0.40.
> - **The dominant channel is the theme's channel.** Torchlit stone/wood interiors show
>   `mean(R) − mean(B)` between **+30 and +100**. Forest (+4), Shadow (+5) and Water (+5) sit near
>   neutral. Water-boss (Morpha, −57) and Shadow-boss (Bongo Bongo, −26) go **cold**.
>   So the rule is *not* "everything is orange" — it is "each dungeon commits hard to one hue, and
>   torchlit interiors commit to warm."
> - **The reliable cross-theme invariant is darkness, not colour**: 24 of 24 frames have mean luminance
>   under 111, and 23 of 24 under 71. **If our dungeon frame averages brighter than that, it is wrong
>   regardless of palette.**

### 8.3 Silhouette and geometry

`UNVERIFIED:` exact polygon counts. The platform envelope is the reliable statement: N64 titles of
this era run roughly **500–1500 triangles for a hero character** and comparable budgets per room, with
Link's model widely cited in the ~700–900 tri range. Treat as an order of magnitude, not a target to
fail a build on.

What *is* directly checkable from `refs/screens/`:
- **Hard-edged, low-vertex silhouettes** with no bevels — see `enemy_stalfos_01.png`,
  `enemy_lizalfos_01.png`, `enemy_redead_01.png`, `enemy_armos_01.png`.
- **Texture detail carries the geometry.** Compare `dungeon_deku_tree_f1_01.png`: the wall relief,
  the vine curtain and the bark are *all texture*; the room is a handful of flat quads.
- **Strong per-room colour identity** — each dungeon's palette is nearly monochromatic around its
  theme hue (see §8.2), which is how OOT keeps a 320×240 frame readable.

---

## 9. Screenshot manifest — `refs/screens/`

**79 PNG files**, all verified as real images (`file` reports PNG/JPEG, size > 10 KB) and converted to
PNG. Categories:

| Prefix | Count | What it is |
|---|---|---|
| `dungeon_*` | 24 | dungeon interiors: Deku Tree floors 1–3 + basements ×2, Forest/Fire ×2/Water/Shadow ×3/Spirit temples, Dodongo's Cavern, Jabu-Jabu, Ganon's Castle, twisted passage, elevator, block puzzle, false wall, Poe sisters |
| `boss_*` | 10 | Forest Temple arena, King Dodongo's chamber, Phantom Ganon ×2, Volvagia ×2, Morpha, Barinade, Bongo Bongo ×2 |
| `anim_*` | 9 | model-rip animation poses: slash ×2, spin ×2, roll, run, ledge-hang, block-push, bomb-hold |
| `camera_*` | 8 | third-person framing: Hyrule Field, open room with vines, interior room, Door of Time, Great Fairy fountain, false wall, Song of Storms, adult-Link framing |
| `enemy_*` | 6 | enemy silhouettes: Stalfos, Lizalfos, ReDead, Armos, Peahat, blade trap |
| `combat_*` | 6 | in-game combat with HUD: Stalfos, Dead Hand, Iron Knuckle, Ganon, magic spin attack, shield block |
| `map_*` | 4 | dungeon maps (Forest ×2, Fire, Dodongo's Cavern) |
| **`ztarget_*`** | **3** | **genuine lock-on frames with the reticle** — Deku Scrub (yellow reticle), Kokiri NPC (blue reticle), Wolfos (yellow reticle + letterbox) |
| `item_*` | 2 | hookshot first-person aim (reticle + laser dot + letterbox), hookshot third-person |
| `prop_*` | 2 | torch, bomb flower |
| `art_*` | 2 | official artwork — **labelled as art, not screenshots** |
| `hud_*` | 2 | `hud_gameplay_01.png` (1280×960 = 4× native) is the frame all §7 measurements come from; `hud_ingame_02.png` is a second, lower-resolution confirmation |
| `look_*` | 1 | warm interior lighting reference |
| **Total** | **79** | all verified PNG, all > 10 KB |

> Godot's editor has generated a `.import` sidecar next to each PNG (158 files on disk, 79 images).
> That is the engine's asset database, not extra references — count `*.png` only.

**Honesty notes on the set:**
- `anim_*`, `enemy_*`, `prop_*` and `art_*` are **model rips or official artwork, not gameplay
  frames.** They were originally downloaded under gameplay-sounding names and I renamed them so a
  critic cannot mistake them for framing/HUD references. Use them for silhouette and pose only.
- **Gap: no bow first-person aim frame.** The hookshot first-person frame
  (`item_hookshot_firstperson_aim_01.png`) is the closest available and shows the same camera mode
  (`FOV 45°`, MEDIUM letterbox) and the same reticle-plus-laser-dot treatment.
- **Gap: no bomb-in-flight / mid-explosion frame.** §5.2 numbers are decomp-sourced, not
  screenshot-derived.
- Several 1920×1080 frames are high-resolution emulator captures of the original N64 geometry, not
  the 3DS remake. Files named `OoT3D*` upstream were **excluded**; anything remaining that says
  `OoT3D` would be a bug — there are none.

---

## 10. The ten numbers most likely to be used to fail a build

1. **20 Hz.** Logic and display are locked together at 20 Hz NTSC (`R_UPDATE_RATE = 3`). Every
   per-tick constant here is per 50 ms.
2. **×1.5.** `Actor_UpdatePos` moves actors at `velocity × 1.5` per tick. units/sec = raw × 30.
3. **Camera distance scales with player height** (`sp94 = 0.68` adult / `0.464` child). Free camera
   136–204 u adult; dungeon camera 102–170 u; pitch 10° / 5°.
4. **FOV: 60° free, 50° hostile lock-on, 45° parallel and first-person aim** (vertical).
5. **Z-target: acquire at 350 u inside a ±60° cone; break at 429 u** (hysteresis), with 0.5 s of
   infinite leash on acquisition.
6. **Letterbox = 27 scanlines (11.25 % of screen height) each edge, sliding 0→10→20→27 in 3 ticks
   (0.15 s).** Playfield shrinks to 77.5 %.
7. **No walk/run threshold.** Stick magnitude clamps to 60; < 20 is deadzone; speed is a continuous
   curve. Run cap 6.0 raw = **180 u/s** adult.
8. **Roll 270 u/s, sidehop 255 u/s, backflip 180 u/s — dodges are faster than running.** Roll has
   10 i-frames from animation frame 8.
9. **Bomb fuse 70 ticks = 3.5 s; blast grows +8 u/tick to ~80 u; deals ½ heart; Link is not exempt
   from his own bomb.** Hookshot reach ~360 u, Longshot ~750 u, both perfectly straight.
10. **Forest Temple: 5 keys, 5 locks, one linear lock chain, dungeon item at the midpoint, 9 loops,
    room 6 used twice.** `keys == locks` exactly.
