# The Lower Worlds: Awakening — Build Contract

Many agents build this game in parallel. This file exists so they do not collide
or drift. It fixes **units, names, interfaces, and file ownership** — nothing
else. How you implement your piece is yours to decide.

> **This supersedes the top-down Link's Awakening brief** kept at
> `docs/CONTRACT.topdown.old.md`. That brief is dead. Do not build to it.
>
> **`docs/METAGAME.md` supersedes §0's structure** — the one key-locked dungeon
> ending in a boss is replaced by a Moonlighter-style loop: a garrison with a vendor
> and a smith, and a procedural dungeon you leave by extracting. OOT remains the
> bar for camera, locomotion, combat feel, and everything in `refs/`. We changed
> what the game *is*, not how it *feels*. The currency is **gold**
> (`Game.gold`, `Bus.gold_changed`), not rupees.

---

## 0. What we're building

A **third-person, over-the-shoulder 3D dungeon crawler in the style of The
Legend of Zelda: Ocarina of Time (N64, 1998)**, in Godot 4.7, Forward+.

- Camera behind and above the hero; **Z-targeting / lock-on** is the centre of
  the whole design — combat, camera, and movement all change mode when it's on.
- WASD + mouse **and** full controller support, equivalently.
- Sword, shield, bow, hookshot, and the three workings (`docs/GDD.md` §6.5).
- **One cyclic, key-locked intro dungeon** ending in a boss.

**The bar is `refs/`.** Real Ocarina of Time screenshots in `refs/screens/`, the
measurable checklist in `refs/REFERENCE.md`, the dungeon-structure bar in
`refs/structure/dungeon_structure.md`. Nothing is "done" because it looks fine
on its own — it is done when it survives a blind A/B against `refs/`.

We are matching OOT's **feel, framing, pacing, and structure**. We are not
copying its assets, characters, or names. Our hero is a hooded warrior, not
Link. He is **Kael** *(tentative, 2026-08-10 — `docs/GDD.md` §1)*, he is male,
and **in code and comments he stays "the hero."** The class is `Hero`, the script
is `hero.gd`, and a rename buys nothing but a diff across every file that
touches him. The name belongs to the fiction — the receipt, the plaque, the
Lanternkeeper's board — not to the identifiers.

---

## 1. Units and scale — do not renegotiate these

Metric. 1 Godot unit = 1 metre. Gravity is `-Y`. The hero moves on the XZ plane.

| Thing | Value |
|---|---|
| Hero height | **1.65 m** (model is 1.0 units tall → `scale = 1.65`) |
| Hero capsule | radius **0.35**, height **1.5**, centred at y=0.75 |
| Eye / camera-look height | **1.35 m** above the hero's feet |
| `TILE` (authoring grid) | **2.0 m** |
| Corridor | 4 m wide (2 tiles), 5 m ceiling |
| Standard room | 16 x 16 m to 24 x 24 m, ceiling 7 m |
| Boss arena | 32 x 32 m, ceiling 12 m |
| Door opening | 2.4 m wide, 3.2 m tall |
| Chest | 1.15 wide x 0.61 deep x 0.74 tall (measured off `treasure_chest.glb` at `Chest.MODEL_SCALE`) |
| Arrow | 0.70 m long (`Arrow.MODEL_LEN`; the GLB is 1.50 m native and is scaled in `WeaponModels.SCALE_FIX`) |
| Pot | 0.5 diameter, 0.6 tall |
| Push block | 1 tile: 2.0 x 2.0 x 2.0 |

Constants live in `scripts/core/consts.gd` (`class_name K`). Use `K.TILE`, never
a literal `2.0`. **Anything you tune that another piece can see belongs in `K`.**

---

## 1b. The universal character model — one rig, three peoples, four suits

Everyone in the garrison is the SAME 24-bone rig (`Hips`, `Spine02`→`Spine01`→
`Spine`, `neck`, `Head`, the `Left*`/`Right*` limbs, and the leaf markers
`head_end`/`headfront`). Note the spine ordering: **`Spine02` is nearest the hips
and `Spine` nearest the neck**, which is backwards from every other rig in this
project, and reading it the obvious way puts a collar around the waist.

| What | Where | Notes |
|---|---|---|
| Race bodies | `assets/characters/races/*_base.glb` | Stoneborn 1.41 m, Reshi 1.65 m, Vyr 1.82 m. One mesh each, own baked atlas. |
| Shared clips | `assets/characters/races/_humanoid_anims.glb` | Rotation tracks only — see `RaceBody._shared_lib` for why the position tracks must be dropped. |
| Suits | `assets/characters/suits/<material>/` | `cloth`, `leather`, `mail`, `plate`. Each is `body_rigged.glb` + `head_rigged.glb` with its own basecolour maps. |

**A suit is a whole person, not a garment.** `body_rigged.glb` is the entire
dressed silhouette — collar to boot sole, gloves included — and `head_rigged.glb`
is the matching hood or helm. Wearing one REPLACES the body: `RaceBody.wear`
seats both halves and cuts the base body back to its head
(`SuitSeater.cut_to_head`). There is no per-slot layering and no `hides` table,
because there are no seams to close.

Suits are authored against one figure and worn by three.
`SuitSeater._fit_map` fits a similarity (uniform scale + translation) between the
suit's rest skeleton and the wearer's, and every Skin bind is rebased through it —
so the suit's vertices never move, only which bone claims them. That is the whole
reason one suit fits a 1.41 m Stoneborn and a 1.82 m Vyr with no per-race table.

Ported from Valenfeld's `ArmorSeater` + `HumanoidRig._equip_armor_simple_suit`.
**Do not port Valenfeld's `ClothingKit`/`ModularCharacter`** — those build its
PLACEHOLDER box character, and mistaking them for the clothing system cost this
repo a full build of procedurally-constructed garments that was then deleted.

Known limit: the whole skull survives the cut, because this rig carries no
cranium cut line (`headfront`/`head_end` have zero vertices weighted to them —
measured). The leather coif is a close cap and ends up inside the skull, so a
Stoneborn in leather reads bare-headed. Cloth's hood and plate's helm both sit
outside and render correctly.

---

## 2. The hero rig — already built, shared, read-only

Proven working. Do not rebuild this.

- **Model:** `res://assets/characters/hero.fbx` — textured, `Skeleton3D` with
  33 `mixamorig_*` bones, mesh is 1.0 units tall.
- **Animations:** `res://assets/animations/hero_anims.res`, a single
  `AnimationLibrary` of **117 clips on that exact skeleton — no retargeting
  needed**. Names are `<set>_<clip>`:
  - `ss_*` — sword & shield (51): `idle_01..04`, `walk_01/02`, `run_01/02`,
    `strafe_01..04`, `slash_01..05`, `attack_01..04`, `block_01/02`,
    `block_idle_01`, `impact_01..03`, `180_turn_01/02`, `turn_01/02`,
    `jump_01/02`, `kick_01`, `power_up_01`, `death_01/02`, `casting_01/02`,
    `draw_sword_1_01`, `sheath_sword_1_01`, `crouch*`
  - `ex_*` — extra (12): `running`, `fast_run`, `roll_to_run`, `backflip`,
    `dive_forward`, `jump`, `jump_running`, `sword_combo_light`,
    `sword_combo_heavy`, `cast_light`, `cast_heavy`, `hookshot_fire`.
    This set is where clips the sword-and-shield pack does not contain end up,
    and the list of what it does not contain is long: no roll, no 360, and no
    jump. `fast_run` is the sprint, `jump`/`jump_running` are the two jump arcs.
    **`running` is the RUN**, and it is not from that pack for a reason worth
    knowing before you reach for `ss_run_01`: the pack's own run holds the guard
    through the whole cycle, so it is a man jogging with a shield up rather than
    a man running. Photographed side by side in
    `tools/directors/run_lookdev.gd`. It also has the longer authored stride of
    the two (`tools/_clip_travel.gd`: 2.34 m/s of leg against 2.13), and it puts
    the run in the same family as the sprint that follows it.
  - `ax_*` — axe (1): `melee_attack_360_low`, the charged spin. One clip
    borrowed out of a whole moveset (`build_anim_lib.gd` §ONLY).
  - `mg_*` — magic (14): casts, hit reactions, `react_death_backward`
  - `bow_*` — longbow (39): `equip`/`disarm`, `draw_arrow`, `aim_overdraw`,
    `aim_recoil`, `aim_walk_*`, `aim_turn_*`, `shoot_*`, `reload_*`, `dodge_*`,
    `death_*`. **These are the archer's real clips — the old stand-in
    `ss_casting_01` is gone.** The four the rig actually reads are
    `aim_overdraw` (holding at full draw), `aim_walk_forward` (strafing at
    draw, and it LOOPS), `draw_arrow` (the charge — reach, nock, pull) and
    `aim_recoil` (the loose). The last two are one shot, in that order, and
    they abut: `draw_arrow` ends on the pose `aim_recoil` opens on. The rest
    are stock.
- **Binding** (the FBX ships a stub library you must evict first):
  ```gdscript
  var ap: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
  if ap.has_animation_library(""):
      ap.remove_animation_library("")
  ap.add_animation_library("", load("res://assets/animations/hero_anims.res"))
  ap.play("ss_idle_01")
  ```
- Clips are **stripped of hips XZ translation** — they play in place, the
  `CharacterBody3D` owns horizontal position. Vertical hip motion is kept.
- Rebuild the library with `godot --path . --headless -s tools/build_anim_lib.gd`
  (owned by the orchestrator; ask if you need a new set added).

Other assets available: `assets/monsters/*.glb` (goblin, skeleton, orc, ogre,
troll, golem, kobold, wraith, knight_iron + a brute animation set),
`assets/weapons/*.glb` (4 swords), `assets/props/altar.glb`,
`assets/textures/` (tiled rock wall + cobble, with normal maps),
`assets/shaders/` (51 shaders incl. `wall_stone`, `stone_floor`, `dissolve`,
`hero_rim`, `fx_*`), `audio/sfx/` + `audio/music/` (222 ogg files).

---

## 2.5 The reference is authoritative — and it contradicts intuition

`refs/REFERENCE.md` is derived from the **`zeldaret/oot` decompilation**, with
`file:line` citations, plus measurements off the real screenshots in
`refs/screens/`. `scripts/core/consts.gd` is derived from it: constants tagged
`[oot]` are **measured**, constants tagged `[tune]` are ours to move.

**Do not "correct" an `[oot]` number because it looks wrong. It looks wrong
because it is measured and your intuition is not.** If you believe one is
genuinely mistaken, cite `refs/REFERENCE.md` and tell the orchestrator.

OOT's logic runs at **20 Hz**, so raw decomp constants are per-50 ms tick, and
distances are in OOT units. `K` has already converted both — use `K`, and use
`K.from_units()` for anything else you pull out of the reference.

These nine facts are the ones clones get wrong. Build to them:

1. **There is no walk/run threshold.** Speed is a continuous curve of stick
   magnitude — deadzone below 0.333, ramping to the cap. Use
   `K.speed_for_stick()`. Do not branch on a "is walking" boolean.
   The separate `K.STICK_ACTION_GATE` (0.917) is what gates roll/backflip/sidehop.
2. **Dodges are faster than running** — roll 6.55 m/s and sidehop 6.19 m/s
   against a 4.37 m/s run. This is why OOT combat moves the way it does.
3. **Z-targeting is not "lock the nearest enemy."** It is a priority chain:
   category (Boss > Enemy > Bg) → ±60° cone off the hero's facing → range →
   on-screen with asymmetric leeway → line of sight → *facing-weighted* nearest.
4. **Lock range is short** — acquire at 8.49 m, break at 10.40 m. The ~22 %
   hysteresis is deliberate; without it the lock chatters.
5. **Dungeon cameras are tighter and flatter than outdoor ones** — 2.48–4.13 m
   at 5° pitch, not the 3.30–6.60 m at 10° used outdoors. FOV changes by mode:
   60° free, 50° locked on a hostile, 45° parallel/first-person.
6. **The HUD's B/A/C buttons are TOP-RIGHT**, arranged in the physical shape of
   the N64 C-pad. Only the gold counter (bottom-left) and minimap
   (bottom-right) are at the bottom. Hearts are top-left.
7. **A bomb hurts the hero too** — no owner exemption. Fuse 3.5 s, blast 1.94 m.
8. **The hookshot flies perfectly straight.** Gravity is never applied to it.
9. **OOT has no hit-stop.** It sells impact with camera quake and rumble. Our
   `K.HITSTOP_*` is a deliberate deviation because we have no rumble — it is our
   choice, not fidelity, and it is not evidence of anything about OOT.

---

## 3. Autoloads — owned by the orchestrator, do not edit `project.godot`

**Load order is part of the contract**, and the table is in that order:

| Autoload | Script | Purpose |
|---|---|---|
| `Bus` | `scripts/autoload/event_bus.gd` | sideways peer→peer signals |
| `Game` | `scripts/autoload/game_state.gd` | hearts, magic, keys, items, flags |
| `Run` | `scripts/autoload/run_state.gd` | the current delve; **after `Game`** — it spends and grants gold |
| `Heat` | `scripts/autoload/heat.gd` | the kill chain and what it is worth; **after `Game`** (it refunds stamina) and **after `Run`** (no chain outside the dungeon) |
| `Settings` | `scripts/autoload/settings.gd` | volumes, video, binds, and their persistence |
| `Saves` | `scripts/autoload/save_game.gd` | slots |
| `Music` | `scripts/autoload/music.gd` | picks the track and crossfades it; **after `Bus`** |
| `Sfx` | `scripts/autoload/sfx.gd` | implements `Bus.request_sfx`, owns the signal→sound table; **after `Bus`** |
| `Atlas` | `scripts/autoload/atlas.gd` | the floor's plan and its fog of war; **before `Hud`** (the minimap reads it on every repaint) and **before `Menu`** (the MAP screen connects to `Bus.map_changed` on `_ready`) |
| `Hud` | `scripts/ui/hud/hud.gd` | the overlay, `CanvasLayer` **50** |
| `Prompt` | `scripts/autoload/prompt.gd` | which Interactable owns the interact button |
| `Menu` | `scenes/ui/menu/pause_menu.tscn` | the pause menu, `CanvasLayer` **100** |
| `Flow` | `scripts/autoload/game_flow.gd` | garrison↔dungeon + the fade, `CanvasLayer` **200**; **loads LAST** |

The `CanvasLayer` numbers are a stack, not preferences: the HUD draws under the
pause menu, and Flow's fade covers both. A fade something can draw on top of is
not a fade. Two screens are not autoloads and take their place in the same stack —
`TradeScreen` at **60** and `RunEndScreen` at **150**, the latter deliberately
above the pause menu so Escape cannot open a menu behind the end of a run.

**Nothing opens a menu behind any of them, and it is not the layer that
enforces it.** Escape is bound to both `pause` and `ui_cancel`, and every
full-screen screen closes on either — so the press that closed the shop used to
raise the pause menu in the same frame. `PauseMenu` refuses to open while
`Prompt.screen_up` (a screen has called `Prompt.block`, as distinct from a fade,
which sets `Prompt.blocked` and must not count). One press, one response.

**The cursor belongs to whoever took the screen.** `GameCamera` GRABS it on
spawn and never releases it — every full-screen UI saves `Input.mouse_mode` on
the way in and restores exactly what it found on the way out (`PauseMenu`,
`TradeScreen`, `StashScreen`, `RunEndScreen`). The camera used to release it on
`pause` as well, and because unhandled input runs deepest-child-first the camera
got there before the autoload menu: the menu recorded "visible" as the state to
put back, restored "visible" on close, and mouse-look was dead for the rest of
the session.

`LoadingCard` (`scripts/ui/loading/loading_card.gd`) is not in that stack because
it is not a screen anyone opens: it is a child of Flow's own **200** layer, in
front of the fade veil, raised and freed by `Flow._go` on the two transitions
into the dungeon. Nothing else may instance one — it is opaque and full-screen,
and a second owner is a black rectangle nobody can dismiss. The world is
**paused** for the whole time it is up.

`Menu` is an autoload for the same reason `Hud` is — Escape has to work in
whatever scene the launcher picks. It shipped built but instanced only in
`scenes/ui/menu/_menu_test.tscn`, so for a while the harness had a pause menu and
the game had none. **There is one `PauseMenu` in the project**; drive that one,
do not instance a second.

Need a new autoload, input action, or project setting? **Ask the orchestrator.**
`project.godot` is the file every agent would otherwise fight over. Edit it only
from a claimed card, and commit that edit on its own — never bundle it into a
feature commit where a merge will silently pick a side.

Signals on `Bus` and fields on `Game` are **additive**: append yours, never
rename or remove someone else's.

---

## 4. Input actions — **Elden Ring layout**

The feel is OOT; the *buttons* are Elden Ring. This table is **dumped from the
running game**, not read off `project.godot` — the file is not the last word on
what the player's hands get (see "two ways this lies", below).

```bash
godot --path . --headless res://tools/scenes/_padnames.tscn
```

| Action | Keyboard / mouse | Gamepad | Elden Ring equivalent |
|---|---|---|---|
| `move_up/down/left/right` | WASD, arrows | left stick | move |
| `cam_up/down/left/right` | mouse motion (read in code) | right stick | camera |
| `attack` | **LMB** | **RB / R1** (pad10) | light attack — the chain, or fire what is in the right hand |
| `heavy` | **Shift+LMB** | **RT / R2** (axis5+) | heavy — one pull, one blow, on the **release**: **tap** = overhead, **hold** = spin, **airborne** = jump attack, **locked** = leap, or fire what is in the right hand. **The modifier only works because `attack` is read exactly** — see below |
| `shield` | **RMB** | **LT / L2** (axis4+) | guard — **held**, and it targets, and it recentres |
| `context` | **Space** | **B / Circle** (pad1) | **tap** = dodge — **hold** = run, and then it is not a dodge |
| `use_item` | **R** | **X / Square** (pad2) | drink the selected bottle — §4.1 |
| `jump` | **F** | **Y / Triangle** (pad3) | jump |
| `z_target` | **Q**, MMB | **R3** (pad8) | lock-on toggle / camera recentre |
| `interact` | E | **A / Cross** (pad0) | talk/open, and nothing else. **E and A are also `ui_accept`** — the confirm is the same press in the world and in a menu, see below |
| `ui_accept` | Enter, Space, **E** | **A** (pad0), **X** (pad2) | confirm — in menus only. E is registered at runtime, the same way the pad buttons are |
| `ui_cancel` | Esc | **B / Circle** (pad1) | close/back — in menus only |
| `ui_hold` | **Y** | **Y / Triangle** (pad3) | the menu's HOLD — in menus only. A goes forward, B goes back, and this is the press that must not be a press. Today: the escape rope on the POUCH screen (METAGAME §5). Shares Y with `jump`, which is safe because the tree is paused whenever it is read. **Not rebindable** — the `ui_` prefix is what enforces that (`Settings._capture_defaults` skips it). |
| `weapon_prev` / `weapon_next` | 1 / 3 | dpad ← / → | step the right hand through the weapons you own — §4.1 |
| `item_next` | 4 | dpad ↓ | step the selected item — §4.1 |
| `loadout_swap` | 2 | dpad ↑ | primary ↔ alternate — §4.1 |
| — | — | **LB** (pad9) | **deliberately empty in the world**, held for spells — it pages menu tabs, see below |
| `first_person` | **V** | **R3** (pad8) | look out of his own eyes — he roots. No Elden Ring equivalent; V because `use_item` took R |
| — | **X** | — | **deliberately unbound**, held for a crouch. Elden Ring's crouch key, and the one row of its layout this game has no ability for. CONTRACT §4: it stays unbound until the verb exists |
| `pause` / `inventory` / `map` | Esc / **I** / **M**, Tab | Start (pad6) / **Select** (pad4) / L3 (pad7) | menu / pouch / map |
| `ui_tab_prev` / `ui_tab_next` | **Q** / **R** | **LB** / **RB** | page ITEMS ↔ POUCH ↔ MAP — **in menus only**, see below. Next was E until E became the confirm |
| `dbg_reload` | F5 | — | — |

**A MODIFIED BINDING DOES NOT EXCLUDE THE UNMODIFIED ONE.** `attack` is plain
LMB and `heavy` is Shift+LMB, and Godot matches a modified press against BOTH —
it records the modifier mismatch as a separate `exact` flag rather than as a
failure to match. Probed on 4.7, not remembered:

|  pressed | `attack` loose | `attack` exact | `heavy` |
|---|---|---|---|
| LMB | true | **true** | false |
| Shift+LMB | true | **false** | true |

So every read of `attack` passes `HeroCombat.ATTACK_EXACT` (`hero_combat.gd`,
`game_camera.gd`). Without it one click throws the light chain *and* the heavy.
Two consequences worth writing down because neither is obvious:

- **The pad and every director are unaffected**, which is why this can be a
  blanket rule rather than a keyboard special case. An `InputEventJoypadButton`
  has no modifier mask to mismatch, so RB reports `exact=true` — and so does a
  bare `Input.action_press(&"attack")`, the path every harness in
  `tools/directors/` uses. Both were probed alongside the table above.
- **Anything else bound with a modifier inherits the problem.** Elden Ring's
  Ash of War is Shift+RMB; binding it naively would fire `shield` (plain RMB)
  at the same time, and `shield` would need the same exact read. See the note
  at the end of `project.godot`'s `[input]` block.

`Settings` serializes the modifier (`MOD_SHIFT` &c., `BIND_SCHEMA` 13). Before
it did, a player rebinding the heavy's *gamepad* half wrote the surviving mouse
event back as a bare LMB, and their next boot collapsed the heavy onto the light
attack — silently, out of the config file. `Glyph.long` / `Glyph.cap_for` print
the modifier for the same reason: without it the options screen and the HUD
legend both show "Mouse L" for two different verbs.

`tools/directors/keyboard_layout.gd` is the proof, and it is the only director
that presses **keys and mouse buttons** and lets the InputMap do the lookup —
the same argument `rb_swing.gd` makes for the pad. Its discriminator is timing:
the light swing lands on the PRESS and the heavy on the RELEASE, so a Shift+LMB
that is still not swinging two physics frames in is proof the light did not fire.

**The triggers are a pair and that is the layout's spine.** This is BOTW's
arrangement, and it is right: the left index finger holds a STANCE and the right
index finger fires what that stance is aimed at. LT raises the guard and takes
the lock; RT is the heavy swing, and whatever the right hand is holding takes it
over. Aiming a bow with a shoulder and loosing it with a thumb makes you let go
of the stick that was aiming.

**The sword is on the two right shoulders and the face buttons are verbs.** RB
is the light chain, RT is the heavy; A talks, B dodges, X drinks what you have
selected, Y jumps. One verb per button and no arbitration anywhere on the pad —
nothing here needs a rule to say which of two things a press meant.

**LB is bound to nothing, on purpose.** It is where spells go if they are ever
built: casting is a left-hand verb in every game this one borrows from, and an
unbound button is cheaper than a bound one that then has to move. Do not fill
it because it looks empty.

**The shoulders page the menu's tabs, and that does not contradict the line
above.** `ui_tab_prev` / `ui_tab_next` (LB/RB, Q/E) exist only while the pause
menu is open, where the world is paused and the hero receives no input at all —
so RB being the light attack, Q being lock-on and R being `use_item` cost
nothing. They are the
shoulders because that is where "previous page / next page" lives in every menu
on every console, and because the thumbs are already spending ↑↓←→ on focus.

Both are **registered at runtime** by `PauseMenu._ensure_pad_ui_actions()` and
appear in neither `project.godot` nor any `.tscn`. That is deliberate on two
counts: `--import` re-serialises `project.godot` and has eaten additions before
(§10), and `Settings` skips every `ui_`-prefixed action, so these cannot be
rebound onto a world verb and cannot be wiped by Reset to Defaults.

The right stick swings the lens and **clicking it (R3) locks on** — the standing
decision, the one that survives letting go of the trigger.

Both triggers are AXES (`InputEventJoypadMotion`, JoyAxis 4 and 5), not buttons,
so the action's 0.2 deadzone is how far the trigger travels before it counts as
pressed.

**The left trigger is OOT's Z**, and it carries everything Z carried on one
pull. An index finger on a shoulder is exactly what Z was, so it does all of it
at once: raises the guard, **acquires the best target**, pins the facing so the
stick becomes a strafe, and — with nothing lockable — puts the camera back
behind the hero. Let go and it all drops. The targeting half is in §8; the
facing half is Z-Parallel and lives in `Hero._tick_camera_facing`, the same tick
the bow uses, because the split is the same one (the body faces the camera, the
stick moves you). Without a pinned facing "roll backwards" has no backwards to
mean, which is why the backstep is part of the same change and not a separate
feature.

The guard and the recentre were briefly split across LB and LT, one button each.
That is the arrangement Elden Ring has, and it was wrong here: it asks the
player which of the four things Z did they want before they have learned that
they are the same thing. One trigger, four behaviours, no decision.

`z_target` keeps **R3** for the standing decision — a lock that survives you
letting go of the trigger. A thumb already resting on the right stick should not
have to travel to recentre what that stick just moved.

**The sword is on the two right shoulders and an item REPLACES it there.** That
is the design and not a collision: drawing something is what "temporarily"
means, and a player holding a bow should not have to remember which of two
attack buttons the bow answers to. Both `attack` and `heavy` reach the drawn item
(`HeroCombat._tick_item_trigger`, which runs before either swing tick so both can
open with a plain "an item owns the right hand" bail).

Drawing is **sticky**: a D-pad press puts the hookshot in his hand and it stays
there, so you can walk around carrying it, which OOT's momentary C-buttons never
allow. Carrying it is not *aiming* it — the sight belongs to the trigger, below.

A sticky mode needs an unconditional way out, and **the way out is the D-pad**.
The sword is a stop on the same weapon ring the bow is on, so ← or → hands it
back. `attack` used to be the escape hatch — it stowed the item and swung on the
same press — and that went when the ring arrived: the hatch existed because the
direction you drew with was a fact you had to remember, and a ring has no such
question. `Game.stow_item` survives with no callers and says so in its own
docstring.

**With an item in hand the trigger is HELD, not pressed.** Pull it and he raises the item
into its aim; let go and it fires. That is the only arrangement that works once
the button is a trigger and the aim is the camera: the item goes up, THEN you
move the stick, then you shoot. Firing on the press meant the shot was gone
before the aim began, and it also meant the hero had nowhere to stand between
shots — the stance now belongs to the button, so he lowers the item afterwards
and the next shot costs another pull. See §8 Ranged.

**`interact` and `context` are two buttons now, and the arbitration between them
is DELETED.** They shared A/Cross for one pass, refereed by
`Prompt.claims_press` / `claims_hold`: while something was in reach the thing in
reach owned the press and nothing rolled. Both of those functions are gone.

The argument for sharing was that a thumb at rest wants either "get out of the
way" or "talk to that", never both at once. True, and still not worth it: it put
a rule on the most reaction-critical button in the game, it cost you the roll
away from a chest, and the whole of it existed to keep B free for `ui_cancel` —
which B still is, because a menu is up or it is not. **A talks and B dodges**,
and `ui_cancel` lives on the same B without a rule, because nothing in the world
reads a button while a menu is open.

`interact` still shares A with `ui_accept`, which is safe for its own older
reason: `trade_screen`'s accept edge starts DISARMED, so the press that opens a
screen cannot also confirm inside it. That is the only arbitration left anywhere
on the pad, and it is a one-frame one inside a single screen.

**And E now shares the same pair on the keyboard.** The pad had confirm and
interact on one button from the start; the keyboard had E for the world and
Enter for menus, so a player who had spent a whole run pressing E to say yes to
a vendor pressed it at a menu row and paged the tabs instead. E is on
`ui_accept` (registered at runtime by `PauseMenu._ensure_pad_ui_actions`, with
the pad buttons and for the same reasons), Enter and Space still confirm, and
paging moved to Q / **R**. The disarm above is what makes it safe in both
directions.

**The jump attack came off A with the dodge.** It was "guard up, stick still, A"
— OOT's Z + A read literally, with a four-way stick table deciding between the
leap, the backflip and two dodges. It is `heavy` now: **airborne** it is the
slam, **locked on** it is the leap, and neither reads the stick at all. What the
stick table leaves behind is better — a neutral-stick dodge under a lock or a
guard is the **backstep**, on `context`, with nothing to fall between.

`Hero.stick_neutral()` still picks the backstep out of the dodges, and
`lunge_max_range` is still `K.LOCK_BREAK_RANGE` and not `K.LOCK_RANGE`: inside
the lock's hysteresis band the dodge has already stood down, so a leap that
refuses on range there would be a dead press.

**The dodge button is a tap OR a hold, and the two are exclusive.** `context` is
*measured*: released inside `Hero.sprint_hold_time` (0.18 s) the press was a
**dodge**, and it pays out on the release. Still down when the window expires, it
was a **run** — `K.SPRINT_SPEED`, 6.07 m/s against the 4.37 run cap, until the
button or the stamina bar gives out — and it will not roll when it finally comes
up. That is Elden Ring's arrangement and BOTW's B.

`Hero._tick_context` is the only thing that reads the raw button. It publishes
`Hero.context_tapped`, true for exactly one frame, and the dodge reads *that*
rather than the button. It had a second reader while the leap lived on this
button, and that is the reason the flag exists at all: two places measuring one
hold is how a press comes out as a leap and a roll on the same frame, or as
neither.

An intermediate pass fired the dodge on the press and started the run underneath
it, to keep the latency off the most reaction-critical button in the game (the
same argument the charge makes above for the sword coming out on the press).
The latency argument is right and the arrangement it bought was still wrong:
**every run in the game began with an involuntary roll**, which spends a third of
the bar the run is about to need and throws the hero 3.2 m in whatever direction
he was pointing. You could not start running without dodging first.

The latency argument survives where it applies. `Hero._context_resolves_now`
pays the press out **instantly** in every stance the run is withheld from —
locked, guarding, aiming, airborne (below) — so the dodge you make with a sword
coming at you costs nothing, and the leap under a raised guard is unchanged.
Only the free-roam dodge, the one you make out of a run against nothing in
particular, waits to be classified. The window is one number and not two on
purpose: the frame the sprint begins is the frame the dodge stops being
possible, so there is no band in which a press means neither.

The run is deliberately **slower than a roll** (6.55). The roll is the fastest
the hero ever travels and it costs a third of the bar for half a second; a
sprint that outran it would make the dodge a worse way to cover ground than the
button it shares. They come out of one pocket on purpose — there is no separate
sprint meter, so a player who runs everywhere arrives with nothing to dodge on.

It is withheld in three stances, each for its own reason: **locked** (the stick
is a circle-strafe there, and "run" has no direction to mean), **guarding** and
**aiming** (a run would have to drop a stance the player is holding a button
for). Those are exactly the three `_context_resolves_now` names, and they have to
be the same list: a stance with no run in it is a stance where the press is a
dodge the instant it is made, held or not. **Holding the button in all three is
just a dodge**, on the press frame, as it always was.

**Jump is real, and it is not OOT's contextual ledge-hop.** `K.JUMP_SPEED`
against `K.GRAVITY` gives 0.96 m of apex and 0.59 s in the air, with full air
control throughout. It is **buffered** (`jump_buffer_time`, so a press during a
fall lands and jumps) and **coyote-timed** off the same `coyote_time` the fall
animation already used, so walking off a ledge and pressing a frame late still
jumps.

Two things about it are worth knowing before touching it. First, the impulse is
applied inside `Hero._apply_gravity`, not by the code that decides to jump:
`is_on_floor()` reports the *last* `move_and_slide`, so it is still true on the
launch frame and the floor clamp would overwrite the launch velocity — giving a
hero who plays an entire jump animation standing on the ground. Second, both
`ex_jump` clips open with a ~0.5 s anticipation crouch that the game has no room
for, so they are started at their launch frame via `jump_start_offset`. Set that
to zero and the hero visibly squats while already 0.4 m in the air; it was A/B'd
in `tools/directors/_jump_trace.gd` and the two frames are not subtle.

**There IS a heavy-attack button now, and it is RT.** For most of this project's
life there was not: the heavy was the charge, held off the same light button, and
"the game's biggest ordinary blow" was locked behind two presses of a smaller
one. RB taps the light chain; RT throws the overhead, and *holding* RT winds up
the **spin**.

**One pull of RT is exactly one blow**, and both come out on the **release**. A
short pull is the overhead; a pull past `charge_time` (0.42 s) is the spin
*instead of* it. That is Elden Ring's R2, and `combat.charged` — public, up at
`charge_time` — is which of the two the release will pay out.

They used to be a **sequence** and it was wrong: the overhead fired on the press
and the charge kept running underneath it, so holding the trigger threw the
overhead *and* the spin off a single pull. Two power attacks, the second landing
while the first was still finishing, and a charge that was not a decision — it
was what happened to you if you did not let go fast enough. The argument for the
old ordering was latency, that a button waiting to see whether you meant a tap
costs `charge_time` on every heavy. It does not: a tap is however long the finger
is actually down, a frame or three, and the swing with no latency at all is RB.
A button that quietly does two things is the more expensive problem.

**Every sword swing costs stamina, and the rule is not the dodge's rule**
(`HeroCombat._can_swing`, `Game.spend_stamina(cost, partial := true)`). Any
stamina above zero buys the swing and the cost clamps at the floor, so a chain is
never interrupted between its own steps — it empties the bar and the NEXT press
is the one that finds nothing there. A dodge is the strict version: it is refused
unless the bar holds the whole of `Hero.roll_stamina`. Elden Ring prices them the
same two ways and the reason is legibility — a swing refused halfway through a
combo reads as a dropped input, an empty bar after the combo reads as a decision
you made. A refused swing is **silent**; the bar on screen already said so.

The release is a **360**, not a bigger forward swing, and that is a claim about
*direction* that the hitbox has to make good on. Every other swing on this node
shares one forward box; the spin declares its own through `_aim_hitbox` —
`spin_reach` 2.1 m centred **on the hero** with `spin_arc` 360°, against the
light chain's 130° cone out in front. Each swing re-aims before it commits and
nothing is restored afterwards, deliberately: a spin cut short by a death or a
scene change never reaches its own end, and the next light swing would inherit a
2.1 m sphere. `tools/directors/spin_attack.gd` is the proof — three posts on a
ring, and it fails if a *tap* reaches the one behind him.

The hold has a **pose**, and it is one frame of `ss_slash_01` held (`hero.gd`
§Charge: an `AnimationNodeAnimation` behind a `TimeSeek` and a `TimeScale` of 0,
blended in *under* the swings). It is the bottom of the light slash — crouched,
blade carried out to his left — so the press's own swing settles into the
wind-up instead of returning to idle and striking a pose afterwards.
`charge_pose_time` is a frame **picked off the render**
(`tools/directors/charge_pose.gd`), not a fraction of the clip. Note the seek:
`start_offset` is the obvious tool and it silently does nothing here, because it
is applied when a node starts and a node behind a zero time scale never starts.

The tell is `SpinVfx` (`scripts/combat/spin_vfx.gd`), driven every frame off the
hold clock: motes drawn **into** the blade, the blade taking on an azul emission
through `HitFlash`, an `OmniLight3D` riding the steel, and on release a trail
swept **clockwise** around him at 1.7 m. That trail is one small emitter on a
turning pivot leaving world-space motes behind it — the arc is where the emitter
has *been*, which is why it follows the blade instead of appearing around it.
Its colours are chosen for how they **stack**: the particles are additive, so a
pale blue clips to white the moment three of them overlap on an already-lit
floor, and the numbers in that file are the deep end of azul for that reason and
are not to be brightened without re-rendering. A hold with no tell is a hold
nobody can learn.

**The effect outlives the lockout on purpose.** `spin_swing_time` is 0.68 s, the
arc takes ~0.72 s to draw and its motes live another half-second after that, so
the hero has his feet back while the circle behind him is still burning. The
magic lags the sword.

Sound: `sword_charging` rises from the **press**, and both the release swipe and
the hero's yell fire on the **release**. The yell was on the arm-up at first,
which announced a commitment the player had not made yet.

**The dash attack is `attack` pressed with the guard already up**
(`HeroCombat._tick_light_button`, which opens with an `equipped != &""` bail
because a full hand owns both shoulders). It is a committed forward lunge — `Hero.request_dash`
drives him along `_forward()` at 8.0 m/s for `dash_drive_time` (0.20 s) under
the `SwingDash` one-shot, does 3 quarter-hearts, and resets the light chain so
it can never be step 2 of a combo. It reads as a *decision*: the guard drops,
he closes the gap, and the recovery is long enough to punish. It has no bearing
on the charge either way — that lives on the other shoulder now (§4), and a
guarded player pulling RT winds up a spin exactly as an unguarded one does. This
paragraph used to claim the dash "pre-empts the charge, so you cannot wind up a
heavy from behind the shield": true when the charge was held off this same
button, and stale since it moved.

**The air slam is on BOTH shoulders off the floor**, and it is the same move
either way: `HeroCombat._tick_light_button` throws it on the `attack` press, and
`_tick_heavy_button` throws it off a **held** `heavy`. Held rather than an edge,
deliberately — a player who wants to come down on something pulls RT on the way
up, not at the top of the arc, and an edge would have been spent on the ground as
an overhead before he ever left it. The same pull therefore throws the overhead
on the floor and the slam once he is off it. It is never buffered: a slam that
fires because you pressed attack a moment before you left the ground is a slam
you did not ask for.

`Hero.request_slam()` owns the move and refuses it from anywhere but `GROUND`
while airborne with at least `slam_min_height` (0.35 m) of floor below —
measured with a downward ray, not assumed, so a slam over a ledge cannot start
from a height that gives it nowhere to travel. It hangs for `slam_hang`
(0.16 s), drives down at `slam_speed` (16 m/s, and `_apply_gravity` hands the
SLAM state a fixed velocity rather than an acceleration, so the descent is the
same every time), then roots him for `slam_recover` (0.42 s).

The animation is **one clip cut into two windows**, both time-scaled, because
the fall is a different length every time: `ax_melee_run_jump_attack`
1.50→1.70 is the dive and is scaled to the drop the ray just measured, and
1.70→end is the impact and recovery and is scaled to `slam_recover`. See
`Hero.clip_slam` for the frame table — the offsets are picked off
`tools/directors/slam_lookdev.gd`, not read off the filename.

Damage is instantaneous and **not** an Area3D:
`HeroCombat._slam_targets` runs a `PhysicsShapeQueryParameters3D` sphere of
`slam_radius` (2.6 m) against `K.L_ENEMY | K.L_INTERACT` on the frame of
contact. An area's overlaps are resolved a frame late, and an impact is exactly
the question that cannot be answered a frame late.

The tell is `SlamVfx` (`scripts/combat/slam_vfx.gd`), four layers of MIX
billboards — crest, body, column, grit — spawned at the point of contact and
freed with the node. It is `PROCESS_MODE_ALWAYS` because the impact asks for
its own hit-stop and dust that froze with the world would appear only after the
freeze it caused. Its ring is deliberately sized to reach roughly where
`slam_radius` reaches; the numbers in that file are set against a render and
the note at the top says what happened when they were not.

Sound: `jump_slam` on contact, with `K.HITSTOP_HEAVY` and a 0.90 shake. One
hit-stop for the impact, never one per victim — a slam into four skeletons
would otherwise freeze the game four times over.

### The two ways this table has lied

**1. `button_index` is Godot's `JoyButton` enum, not the SDL/Xbox numbering.**
They disagree exactly where it matters — `5` is the Xbox HOME button, not RB;
`9` is LB, not R3. A pass that renumbered the pad from memory bound `attack` to
Home and `z_target` to LB, and the pad had no attack button at all. The enum is
printed by `_padnames.tscn` straight out of the engine. Do not derive it.

**2. `user://settings.cfg` is replayed over the InputMap at boot and wins.**
So the shipped layout and the layout the player gets are different questions,
and only the dump answers the second. A menu test once left `attack` on the `N`
key with the mouse binding erased; the sword was dead on the owner's machine
and `project.godot` looked perfectly correct the whole time. `Settings`
now stamps saved binds with `BIND_SCHEMA` and **discards** binds saved against
an older layout — bump it in any change that moves a shipped binding.

That happened a second time, and `BIND_SCHEMA` could not have caught it: the
poisoned bind was stamped with the *current* schema, because the run that wrote
it was running the current layout. The schema guards a layout CHANGE; it has
nothing to say about a save that should never have been written. The fix for
that half is the harness sandbox in §"traps" below. Two independent failures,
one symptom — when the sword dies, check the dump before the layout.

**The directors cannot see this class of bug and it is worth knowing why.**
Every combat director reaches the hero through `Input.action_press(&"attack")`
or `rig.hold(["attack"])`, which set action state directly and never consult the
InputMap. An `attack` with no button bound to it at all still swings for them.
`tools/directors/rb_swing.gd` is the one that presses a *button index* and lets
the InputMap do the lookup — the only test here that fails when the binding is
what broke. Run it with `--keep-pad`.

**Not yet bound, because the ability does not exist:** skills and spells. Do not
register an empty action for either; bind it in the same change that builds it.
RT/R2 was pencilled in for the skill and the heavy took it instead — the triggers
being a pair is worth more than reserving one for an ability nobody has designed.
**LB** is the one exception to "bind it when you build it" and it is not bound
either: it is left with no action at all, held for spells (§4).

`first_person` was the standing counter-example and it is now closed: it sat
bound to R (it is **V** now — `use_item` took R with the Elden Ring keyboard
layout), rebindable, read by nothing, with a `Bus.first_person_changed` that
had no emitter, for long enough that it had to be written down as a wart. It
shipped with the mode below, and it took R3 from `z_target` to do it — the left
trigger is the pad's Z and a second pad route to the same lock was a duplicate.

**First person is `GameCamera` with the boom at zero**, and that is the whole
implementation. The third-person camera's forward is `-_orbit_dir(_yaw, _pitch)`
— from the eye back down the boom at the hero — which is already exactly the
direction a head at the at-point wants to face, so `set_first_person` eases
`_fp01` to 1, `_place` lerps the eye onto `hero + K.HERO_EYE_Y` and the look
direction onto the *unbiased* orbit, and the mode inherits the stick handling,
the sensitivity and the pitch clamps for free. Nothing about it is a second
camera. The unbias matters: whatever swing or lift the wall logic had latched
must not ride into the head and leave the player facing 40° off where the stick
had them.

It is a **stance, not a way to play**: `Hero` roots himself and hides his own
model on `Bus.first_person_changed` (the sword and shield hang off bone
attachments under it and go with it). `attack` and `context` drop you out on the
press — the press still counts, `HeroCombat` polls the button and does not care
that the camera read it first. Anything else that claims the frame — a prompt, a
lock, a drawn bow — is **polled** out in `_tick_first_person` rather than hooked
per event, because three listeners is three places for the fourth path in to be
forgotten. `tools/directors/first_person.gd` is the proof, and it asserts that
he *can* walk once he is back out: "he did not move" passes just as loudly when
hero.gd failed to compile.

Read movement as
`Input.get_vector("move_left","move_right","move_up","move_down")` so stick and
keyboard behave identically. Movement is **camera-relative**: the input vector is
rotated by the camera's yaw before it becomes world motion.

**There are two ways to lock on and they are different on purpose.**

`z_target` is a **TOGGLE**, which is Elden Ring rather than OOT: press to lock,
press again to release, press with nothing lockable to recentre the camera
behind the hero. It is not held — holding a stick click and steering the camera
with the same thumb is a cramp, not a control.

`shield` is a **HOLD**, and it is OOT's Z exactly (above). It is deliberately
the *weaker* claim of the two: releasing the trigger drops only a lock the
trigger itself raised (`Targeting._lock_from_shield`), so a deliberate toggle
survives you guarding and un-guarding underneath it. Otherwise every block would
silently disarm the lock-on button. While it is held and nothing is locked it
keeps re-scanning every `guard_rescan` (0.15 s) — kill what you were locked to
without letting go and the guard finds the next one, which is what *hold to
target* means.

An empty guard recentres, but **only on the pull** (`Targeting._read_guard`'s
`pulled`). Firing it on the rescan tick instead would re-aim the camera four
times a second for as long as you stood in an empty room with the shield up, and
the player could never look anywhere; firing it once on the pull is the button
keeping its promise that it always does something.

The guard's edges are read by **diffing `is_action_pressed` against a stored
`_shield_down`**, not by `is_action_just_pressed`. A `just_pressed` is true for
one frame and stamped with the frame it arrived in, so a physics tick slower
than the render rate drops it. `z_target` solves that by queueing the press from
`_unhandled_input`; a hold cannot use that route, because it has to work for
polled and synthetic presses alike (`Input.action_press` dispatches no
`InputEvent` at all, which is why every director drives it — CLAUDE.md §3).
Diffing a held state cannot miss an edge either way.

### 4.1 The D-pad — three rings, no bindings

The D-pad does not hold items. It **steps rings**, and each direction owns one:

| Button | Action | Does |
|---|---|---|
| dpad ← (`weapon_prev`, key `1`) | `Game.cycle_weapon(-1)` | step the RIGHT HAND back through the weapons you own |
| dpad → (`weapon_next`, key `3`) | `Game.cycle_weapon(1)` | step it forward — sword, bow, hookshot, and the three workings |
| dpad ↓ (`item_next`, key `4`) | `Game.cycle_item(1)` | step the SELECTED BOTTLE |
| dpad ↑ (`loadout_swap`, key `2`) | `Game.swap_loadout()` | swap to the alternate set — both hands at once |

**There are no bindable slots.** There were: three directions each held an item
the player chose in a menu, exactly as Ocarina's C buttons do, and picking one up
auto-bound it to the first free button. It is all deleted — `quick_slots`,
`bind_quick`, `cycle_quick_bind`, `use_quick`, `Bus.quick_slots_changed`, the
ITEM BUTTONS card on the equipment screen, and the auto-bind on pickup.

What killed it was that it made every direction mean *whatever you last decided*,
which is only worth its cost when you own more things than you have buttons. This
game has three weapons and a shelf of bottles; a ring you can count is faster to
reach for than a binding you have to remember, and it costs no menu at all. Elden
Ring is the shape now, one direction per ring instead of one direction per slot.
The **left hand** is not on the D-pad, deliberately: ↑ swaps the pair, and the
place to edit a pair is the screen built for it.

**The weapon ring's ceiling is SIX stops, and it is a design constraint rather
than an implementation limit.** Sword, bow, hookshot and the three workings
(`docs/GDD.md` §6.5) fill it exactly. The argument above is the whole reason —
bindable slots were deleted because a ring you can *count* beats a binding you
have to remember, and that argument expires the moment the ring is long enough
that you stop counting and start hunting. Six is where a player still knows that
Burst is "→ twice" without looking at the cluster.

So: **a seventh stop costs a sixth.** `docs/SCOPE.md` §1 carries this as a row in
the frozen manifest and §4.2 as a debt, because the pressure will not arrive as a
request for a new system — it will arrive as one more spell that is "only a row",
and on that argument it is a row, and the row is the problem.

**Weapons cycle, bottles cycle, and they do not share a ring** — a bottle is
*used* (X/Square on the pad, **R** on the keyboard), a weapon is *held*. `Game.cycle_item` steps through empty bottles
too: a ring whose length changed every time you drank is a ring you cannot count.
`Game.selected_item()` / `selected_potion()` name what ↓ landed on; the HUD draws
one cell for it instead of the four the old C-pad needed. See §8 *Armaments*.

---

## 5. Groups

`player`, `enemy`, `boss`, `hurtbox`, `hitbox`, `targetable`, `hookshot_target`,
`pushable`, `door`, `switch`, `interactable`, `chest`.

`targetable` is what Z-targeting scans — enemies **and** some props (signs,
NPCs). Query with `get_tree().get_nodes_in_group(&"targetable")`.

## 6. Collision layers

| Bit | Layer | |
|---|---|---|
| 1 | world | walls, floors, static geometry, camera collision |
| 2 | player body | |
| 3 | enemy body | |
| 4 | player hitbox | sword, arrow, bomb blast |
| 5 | enemy hitbox | contact, projectiles |
| 6 | interact | triggers, chests, switches |
| 7 | pit | floor hazards |
| 8 | hookshot_target | wooden/grate surfaces the hookshot bites |

---

## 7. File ownership

**Only edit files your work package owns.** If you need something from another
package, code against the interface described here and leave a `# NEEDS:` note
in your report — do not reach into their folder and "fix" it.

| Package | Owns |
|---|---|
| P1 camera | `scripts/camera/**`, `scenes/camera/**` |
| P2 hero | `scripts/actors/hero/**`, `scenes/actors/hero/**` |
| P3 targeting | `scripts/targeting/**`, `scenes/targeting/**` |
| P4 combat | `scripts/combat/**`, `scenes/combat/**` |
| P5 items | `scripts/items/**`, `scenes/items/**` |
| P6 look | `scripts/kit/**`, `scenes/kit/**`, `assets/materials/**` |
| P7 dungeon | `scripts/dungeon/**`, `scenes/rooms/**`, `data/dungeon/**` |
| P8 enemies | `scripts/actors/enemies/**`, `scenes/actors/enemies/**` |
| P9 boss | `scripts/actors/boss/**`, `scenes/actors/boss/**` |
| P10 hud | `scripts/ui/**`, `scenes/ui/**` |
| P11 feel | `scripts/feel/**`, `assets/audio/**` |
| P14 menu | `scripts/ui/menu/**`, `scenes/ui/menu/**` |
| P15 garrison | `scripts/world/**`, `scripts/props/**`, `scripts/ui/stash/**` |
| orchestrator | `project.godot`, `docs/**`, `tools/**`, `scripts/core/**`, `scripts/autoload/**`, `refs/**`, `progress.html`, `assets/characters/**`, `assets/animations/**` |

Shared read-only for everyone: `scripts/core/consts.gd`, `refs/**`, `assets/**`.

---

## 8. Interfaces every piece touches

### Damage — one path, no second one

One **deliverer**, `DamageArea._deliver`. Two **victim entry points**, and that
is deliberate:

| Victim | Entry point | Why |
|---|---|---|
| Enemies, props | a `HealthComponent` child | health dies with the body |
| The hero | `Hero.take_hit(hit) -> bool` | his health lives in `Game` so it survives the scene change extracting causes |

`DamageArea` asks for `take_hit` first and falls back to the component. **Do not
reach around it** — the box-built placeholder enemy (`Crawler`, since deleted)
did, calling `hero.take_hit` itself, and that is the only reason it was the one
enemy in the game that could hurt you: the GLB monsters all swing `DamageArea`s,
which knew about `HealthComponent` alone and had therefore been harmless from the
day the roster landed until this was fixed. A blow that lands
returns true; a blow the shield or an i-frame ate returns false, and only the
first is announced on `connected`.

`HealthComponent` (`scripts/combat/health_component.gd`, owned by P4):

```gdscript
class_name Hit extends RefCounted
var amount: int          # in QUARTER hearts (K.QUARTER); 4 = one heart
var from: Vector3        # world position the hit came from
var knockback: float     # metres/sec applied away from `from`
var stun: float          # seconds the victim is stunned
var kind: StringName     # &"sword" &"arrow" &"bomb" &"contact" &"fire"
var source: StringName   # who threw it, ready to print: &"SKELETON", &"ELITE WRAITH"

# on HealthComponent:
func apply_hit(hit: Hit) -> void
signal damaged(hit: Hit)
signal died
```

Anything that deals damage puts a `DamageArea` in group `hitbox` and opens its
window. **Do not invent a second damage path.**

`source` is set once, on the `DamageArea` (`@export var source`), and `Enemy`
fills its contact hitbox in from its own kind. It exists so the end-of-run screen
can say *what* killed you — `Hero.take_hit` stashes it in `Run.last_attacker`
**before** calling `Game.damage`, because `Game.damage` emits `player_died`
synchronously and `Run.die()` builds the summary off the back of it. An attacker
that never stamps itself is not an error: the screen says `KILLED BY THE DARK`
rather than inventing one. Anything new that can kill the hero should set it,
including traps and falls when they arrive.

### Feel — ask for it, never own it

```gdscript
Bus.request_hitstop.emit(K.HITSTOP_LIGHT)   # frames at 60 Hz
Bus.request_shake.emit(0.45, 0.18)          # trauma 0..1, seconds to bleed off
Bus.request_sfx.emit(&"hit_flesh", position)
```

`Feel` (`scripts/autoload/feel.gd`) implements the first two, `Sfx` the third.
Nothing else may stop time or move the camera — a second owner is how you get
two hit-stops stacking into a freeze. `Feel`'s hit-stop is **global** on purpose:
one hero, one room, so the honest impact frame is the cheap one. Shake obeys
`Settings.camera_shake`; hit-stop and sound do not, because shake is the one
that makes people ill.

### Holds — every required hold shows a gauge, and there is one gauge

**A hold the player can fail must draw its progress, from the moment the hold
becomes possible.** This is not a style preference. A required hold is the only
input in the game that can be performed correctly for most of its duration and
still do nothing, and the silence at 80% does not read as "not yet" — it reads
as a broken button. The garrison gate shipped saying `A TO DESCEND`, a player
tapped it, and the bug report was "A to descend doesn't work".

```gdscript
# scripts/ui/hold_gauge.gd — the only two shapes a hold is ever drawn in.
HoldGauge.bar(canvas, rect, t01, col)                  # anything with a box
HoldGauge.ring(canvas, centre, radius, t01, width, col) # anything without one
```

`bar()` draws its empty track at `t01 = 0` on purpose: that is the pre-press
tell that this prompt is a hold at all. `ring()` draws nothing at 0 — an
unfilled circle over the HUD reads as a reticle.

For an `Interactable`, the wiring is free and cannot be forgotten — set
`hold_time` and `Prompt` does the rest:

```gdscript
# Prompt drives BOTH channels from one number, every frame of the hold.
signal Bus.hold_changed(t01: float, required: bool)   # the HUD's gauge
func on_hold(t01: float)                              # the prop's own tell
```

`required` is separate from the number so the HUD can draw the empty track
before the player has pressed anything. `Hud` mirrors both, so a director can
read `Hud._hold01` / `Hud._hold_required` and assert what was drawn.

Holds that are not `Interactable` still owe a gauge: the extraction hold draws a
`ring` around the bag number, the trade screen draws a `bar` along the row it is
about, and the charged swing ramps the blade's glow through `_vfx.charge(t01)`.
A hold with no channel of its own is a bug, not a shortcut.

### Collections of things — one grid, and it is the bag's

```gdscript
# scripts/ui/common/item_grid.gd — a GridContainer, not a screen.
signal cell_focused(index: int)     # the cursor landed here; draw the detail
signal cell_activated(index: int)   # a real press on a cell that has an index
func set_cells(entries: Array, capacity: int = 0) -> void
func cell_at(i: int) -> Button      # null off the end
func count() -> int
func focus_first() -> bool
var spill_down: Control             # where the bottom row hands focus on
```

An entry is a Dictionary: `label` (required), `sub`, `tint`, `mark` (prefix ◆),
`dim`, `index`. `capacity` pads with dimmed empty cells — the bag's and the
locker's case, where the number of cells you own IS the information.

**Every screen that shows more than one thing uses it.** The pouch, both sides of
`TradeScreen`, the footlocker and the run-end receipt. Until 2026-08-09 only the
pouch was a grid and the rest were columns of `PixelFont` text, so the same deep
amber was a tinted cell in your bag, a line of type at the vendor, and a third
thing again on the receipt that took it away from you. The cell is the pouch's
cell: the item's own `tint` as a chip, the name, and one line saying whatever
this screen is about — `×6` in the bag, `120 ◇` at a counter, `2 ⇄ 3` at the
locker.

It owns no state past a `set_cells()` call, never reads `Game` or `Run`, and
decides nothing. A grid that reached for the bag itself would be a second place
the bag is interpreted. It is a **control**, not a screen — SCOPE §1 freezes new
screens at zero and this adds none.

Left/right wraps inside a row; the bottom row hands focus to `spill_down`. Both
halves are load-bearing: Godot's spatial focus finds nothing to the right of a
row's last cell, so without the wrap the stick dies every fourth cell, and
without the spill the grid is a trap you can only leave with B.

### The figure — one paper doll, two sizes of it

```gdscript
# scripts/ui/menu/paper_doll.gd — a Control that draws; nothing here takes focus.
var full: bool    # set BEFORE add_child; _ready reads it to pick a minimum size
```

`full = false` is the pouch's card: the body, the two hands, the bound bottle.
`full = true` is the equipment screen's WORN column: the same body with the eight
worn slots in two plate columns — plate down the left, her stones down the right
— each plate wired to the part of the body it is worn on.

One control, not two. A second doll is the duplication CLAUDE.md §0 is about:
the two agree the day they are written and disagree the second time a slot moves.

The full doll draws **no** hand boxes and no belt. They are not missing — they
are four cards two columns to the right on the same screen, big enough to read a
weapon's name off, and drawn on the figure as well they were a third copy of a
fact the screen already makes twice, sitting exactly where the ARMS and RING
leaders come in.

**Which path a slot committed to is not stored.** It is answered by asking which
of the two sibling tracks has a rung in it (`game_state.gd`, over
`PLATE_PIECES`). One reader of that rule per screen; the doll's is `_draw_plate`.

### Ladders — the same cell, arranged as the progression it is

```gdscript
# scripts/ui/common/item_cell.gd — the cell itself, as two statics.
enum Size { FULL, RUNG, NAMED }
static func make(shape: Size = Size.FULL) -> Button
static func paint(b: Button, e: Dictionary) -> void

# scripts/ui/common/upgrade_ladder.gd — a VBoxContainer, not a screen.
signal cell_focused(line: int)      # -1 for a rung that is not buyable
signal cell_activated(line: int)    # never emitted for -1
func set_board(groups: Array, cells: Array) -> void
func slot_of_line(line: int) -> int # catalogue line -> flat cell position
func order() -> Array[int]          # the buyable lines, in BOARD order
func row_of_line(line: int) -> int
func first_line_of_row(row: int) -> int
func row_count() -> int
var spill_down: Control
```

`ItemGrid` and `UpgradeLadder` are two arrangements of **one** cell — `ItemCell`
is statics rather than a class because a cell has no state and both containers
wanted the same button. A rung on the smith's board and a stack in your bag are
painted by the same function and cannot drift.

A counter's BUY side is a ladder; its SELL side is a grid. The board comes from
`Catalogue.groups()`:

```gdscript
static func groups() -> Array[Dictionary]
# a group is one row:   {"title": String, "tracks": Array}
# a track is one chain: {"name": String, "line": int, "owned": int, "rungs": int}
```

`line` indexes `lines()` and is the NEXT buyable rung, or -1 when there is none.
`rungs == 1` means a repeatable — a draught, a bundle of arrows — and draws as a
plain named cell rather than a numeral. The base `groups()` returns `[]`, which
the screen reads as "one row holding every line", i.e. the flat grid the counters
had before; `Catalogue.flat_group()` builds that row for a subclass that wants
part of its board flat (the alchemist's DRAUGHTS).

**That default lives in `TradeScreen._board()`, not in `Catalogue`, and cannot
move.** A `lines()` written bare inside `Catalogue.groups()` binds to
`Catalogue.lines()` at parse time and hands back the base class's empty list —
the same no-virtual-dispatch trap as `craft_verb` below. The screen holds the
subclass handle, so the call dispatches there and only there. This was not
hypothetical: `RelicDb` took the contract at its word, overrode `lines()` and
nothing else, and the Lanternkeeper's counter drew a **blank left pane** — twelve
rows in `_rows`, a detail pane describing them, and no board. The screen's
"nothing here" label keys off the BOARD for the same reason: a pane with no cells
on it says so, whatever `lines()` claims.

The ladder knows nothing about gold, components or `Game` — the cursor, prices,
affordability and the commit all stay in `TradeScreen`, exactly as when the board
was a grid. It is a **control**, not a screen; SCOPE §1 adds none.

The cursor walks `order()`, never `lines()`: the smith's board reorders what
`lines()` hands over, and its LENGTH depends on what the player owns (`arrows`
does not appear until you own a bow). **No fixed press count into a counter is
ever safe** — `mvp_loop` walks the board by `TradeScreen.cursor_label()` for that
reason, having once silently bought a heart container instead of a bag slot.

### Counters — one screen, one contract, a subclass per shop

```gdscript
# scripts/items/catalogue.gd — everything TradeScreen knows about a shop.
static func lines() -> Array[Dictionary]
static func groups() -> Array[Dictionary]         # [] = one flat row
static func remaining(id: StringName) -> int      # -1 = unlimited
static func can_buy(line: Dictionary) -> bool
static func refusal(line: Dictionary) -> String   # "" = affordable
static func buy(line: Dictionary) -> bool
static func craft_verb() -> String                # FORGE, BREW, …
static func emblem() -> StringName                # assets/icons/actions/<name>
static func crafts(line: Dictionary) -> bool      # concrete: has `parts`
```

`emblem()` is the glyph on the counter's header plate, and it is asked of the
catalogue for the same reason `craft_verb()` is: **`TradeScreen` never learns
which counter it is standing at.** A `match` on the db handle inside the screen
would be exactly that knowledge, smuggled in as art.

`ShopDb` and `AlchemyDb` are `Catalogue` subclasses and `TradeScreen` holds
whichever it was opened with. **A new shopkeeper is a `Catalogue` subclass plus
a row in `Npc.COUNTERS` — never a second screen and never a new branch.** The
recipe column, the per-token affordability colouring, the refusal footer and the
hold-to-craft gauge are written once; the last time this project grew a second
copy of a system it cost more than either copy (CLAUDE.md §0).

Call the overridable statics **through the catalogue you were handed**
(`_db().craft_verb()`). A bare static call inside `Catalogue` binds to
`Catalogue` at parse time — there is no virtual dispatch back down to `ShopDb`,
and the smith spent a build saying `HOLD ENT TO CRAFT` because of it.

### Targeting — read-only for everyone but P3

```gdscript
# Targeting is a child of the hero, discoverable as:
var t := get_tree().get_first_node_in_group(&"player").targeting
t.current_target   # Node3D or null
t.is_locked        # bool
signal target_acquired(t: Node3D)
signal target_lost
```

Anything that wants to be lockable joins group `targetable` and exposes
`func target_point() -> Vector3` (where the reticle sits — usually chest height).

**Two buttons drive it and they are not interchangeable** — see §4. `z_target`
toggles; `shield` holds and re-scans every `guard_rescan` (0.15 s) while it is
down with nothing locked. `_lock_from_shield` records which of the two raised
the live lock, and the trigger's release drops only its own. Leaving the
`targetable` group is how a lock ends — that is the path a death takes out of
`_validate`, so nothing needs a separate "my target died" hook.

### Items — the bottle ring

```gdscript
# scripts/items/item.gd, owned by P5
class_name Item extends Resource
@export var id: StringName        # &"bow" &"hookshot" &"burst" &"sustain" &"ballast"
@export var icon: Texture2D
@export var magic_cost: int       # CHARGES, not mana — the bow's arrow count with
                                  # another name. Bought from the alchemist, spent
                                  # on cast, refilled in the garrison only. GDD §6.5.
func use(hero: Node3D) -> void
func release(hero: Node3D) -> void   # for held/charged items
```

`Game.c_items` is **gone**, and so is `Game.quick_slots`, the bindable-slot
system that replaced it. Two attempts at the same idea — a small set of buttons
holding whatever the player put there — and both went for the reason in §4.1:
this game has fewer things than the scheme needs to be worth its menu. Items are
one ring now (`item_selected`, `cycle_item`, `selected_item`, `use_selected_item`),
stepped with D-pad ↓ and drunk with X. Saves written under either old key still
load; neither is written back.

### Armaments — two loadouts, two hands

```gdscript
# scripts/autoload/game_state.gd
const PRIMARY := 0
const ALTERNATE := 1
const HAND_RIGHT := &"right"
const HAND_LEFT  := &"left"

var loadout: Array[Dictionary] = [
    {HAND_RIGHT: &"sword", HAND_LEFT: &"shield"},   # PRIMARY
    {HAND_RIGHT: &"bow",   HAND_LEFT: &"arrow"},    # ALTERNATE
]
var loadout_set: int = PRIMARY

const RIGHT_POOL: Array[StringName] = [&"sword", &"bow", &"hookshot"]
const LEFT_POOL:  Array[StringName] = [&"shield", &"arrow", &""]

func armament(hand: StringName) -> StringName     # what is in that hand, now
func armament_in(set_index: int, hand) -> StringName
func swap_loadout() -> void                       # dpad ↑, and the Swap Set button
func cycle_armament(hand: StringName, dir := 1, set_index := -1)   # the menu
func cycle_weapon(dir := 1) -> void               # dpad ← / →, the right hand
func stow_item() -> bool                          # no callers; see the docstring
```

`cycle_weapon` is a thin wrapper over `cycle_armament(HAND_RIGHT, dir)`, so the
button and the equipment screen are **the same code** and cannot drift apart. The
ring skips what you do not own (`armament_owned`), which is what makes ← and →
safe to press blind: a ring that stopped on a bow you have never found would be a
ring that lies about your inventory. `&""` in `LEFT_POOL` is a legitimate stop —
dropping the shield to two-hand the sword is a decision, not a broken state.

`swap_loadout()` has exactly two callers, the button and the screen, for the same
reason.

Two sets rather than one, because the primary answers "something is in front of
me" and the alternate answers "something is not" — and a weapon switch you have
to open a menu for is a weapon switch nobody makes.

Rules that are not negotiable:

- **Ids, not Resources.** The save file is ids (`save_game.gd` round-trips
  `loadout` and `loadout_set`). A `Resource` reference here would not survive the
  scene change that extraction *is*.
- **`Game` decides, the rig agrees.** `cycle_armament` / `swap_loadout` emit
  `Bus.loadout_changed(set_index, right, left)`. `hero_combat.gd` listens and
  makes the models match. Nothing else may set `equipped` to disagree with
  `Game`, and `hero_combat` re-reads `Game` on `_ready` so a hero spawned into a
  fresh dungeon comes up wearing what the player left with.
- **Ownership is checked in `Game`, not in the UI**, because the UI is not the
  only caller. `&""`, `&"sword"` and `&"shield"` are always available; `&"arrow"`
  requires the bow — arrows you cannot fire are a slot that lies.
- **`equipped == &""` means sword-and-shield.** Historical, and every caller of
  it predates the loadout, so `_on_loadout_changed` maps `&"sword"` → `&""`
  rather than renaming it under them.

**`Game.STARTER_KIT` is empty, and that is the M1 gate.** It used to hand over
the bow, the hookshot and arrows in `Game._ready()` so all three were reachable
from a cold boot. That kit was costing every gate in the game: `Game.has()` is
the ownership check the smith, the locked doors and the boss drops all read, and
a kit granted on frame one made it answer yes before anything had been earned.
The hero now starts with the sword, the shield and the rope — the first two are
unconditional in `armament_owned()`, the third is a menu verb, so none of the
three needs a row in the array. `STARTER_ARROWS` is deleted outright; a quiver
you cannot fire is a slot that lies, which is the rule
`armament_owned(&"arrow")` already keeps.

The constant itself survives, empty, as the place the *next* boot grant goes (a
demo build, a debug loadout). `_grant_starter_kit()` still runs, because
`K.BOTTLE_START` is a design number rather than scaffolding and did not go with
the kit — see the note at that constant.

**The gate is spelled `Game.has(id)`.** There is no `has_item()` alias; a second
name for one boolean is exactly the duplication `CLAUDE.md` §0 exists to stop.

**A director that needs a bow must grant one.** Roughly twenty directors were
written against the old boot kit and now need `Game.grant(&"bow")` /
`Game.grant(&"hookshot")` at the top. `_grant_starter_kit` is called from
`_ready()` and deliberately **not** from `reset()` — `reset()` means "a fresh
save owns nothing", several directors assert exactly that, and a kit that
reappeared on every reset would make the assertion untestable rather than true.

### The forge — five rungs, and the gear reads them

```gdscript
# scripts/autoload/game_state.gd
const FORGE_EDGE   := &"edge"     # the sword
const FORGE_PLATE  := &"plate"    # the armour
const FORGE_GUARD  := &"guard"    # the shield
const FORGE_STRING := &"string"   # the bow
const FORGE_CHAIN  := &"chain"    # the hookshot
const FORGE_TRACKS: Array[StringName] = [...]

var components: Dictionary[StringName, int] = {}   # the workbench, survives death

func forge_level(track: StringName) -> int         # 0..K.FORGE_MAX, clamped

func sword_bonus() -> int        # K.EDGE_DAMAGE[level]   quarter-hearts
func armour_soak() -> int        # K.PLATE_SOAK[level]    quarter-hearts
func guard_arc() -> float        # K.GUARD_ARC[level]     degrees
func bow_draw_time() -> float    # K.BOW_DRAW[level]      seconds
func hook_reach() -> float       # K.CHAIN_REACH[level]   metres

func component_count(id: StringName) -> int
func add_component(id: StringName, n := 1) -> void          # emits components_changed
func spend_component(id: StringName, n: int) -> bool        # check-and-transaction
func can_afford_parts(parts: Dictionary) -> bool
```

The rungs live in `Game.upgrades` beside the shop's other counters; the numbers
they index live in `scripts/core/consts.gd`. **Rung 0 is the un-upgraded piece**,
so the arrays are the whole truth and there is no "base + bonus" arithmetic to
drift. `K.CHAIN_REACH[3]` is `K.HOOK_LONGSHOT_RANGE` on purpose.

Rules:

- **Ask `Game`, do not cache the number.** `hero_combat.gd` and `hero_ranged.gd`
  read the accessor — in `_ready` for what the rig is built out of, per shot for
  the bow's draw and the hookshot's reach. A hero spawned into a fresh dungeon
  comes up with what the player forged, which is exactly what a rung is for.
- **Read arcs and cones as a delta** (`Game.guard_arc() - K.GUARD_ARC[0]`) when
  the value is also an `@export`, so the exported number still means "the bare
  kite shield" in the inspector.
- **`ItemDef.Kind.COMPONENT` is the only thing that distinguishes a component**
  from an ingredient. `ItemDb.is_component(id)` and `ItemDef.is_component()`
  answer it; the vendor, the pouch and `Run.bank_components()` all branch on
  that one bit and nothing else.
- **`ItemDef.bench` says which counter wants it, and nothing else.** It is
  `BENCH_FORGE` or `BENCH_ALCHEMY`, it exists so the pouch can send the player
  to the right place, and it changes no rule: both benches bank on extraction,
  die with the bag, and spend out of the one `Game.components`.
  `ItemDb.components()` is **all eight**; pass a bench to get four. Code that
  means "the forge's four" must say so — `forge_loop.gd` asserted a count of
  four against the unfiltered call and had to be corrected when this landed.
- **Components bank on extraction, not on pickup.** `Run.bank_components()` is
  called by `extract()` after the fee, and deliberately **not** by `die()`.
- New on `Bus`: `components_changed(stock)`, `components_banked(moved)`,
  `gear_forged(track, level)`.
- New on the pause menu: `PauseMenu.Screen.POUCH`, `Root/Screens/PouchScreen`
  (`scripts/ui/menu/pouch_panel.gd`). It is read-only — the bag has no verbs.

### The footlocker — a third pile, and the only one that is finite by design

```gdscript
# scripts/autoload/game_state.gd
var stash: Dictionary[StringName, int] = {}   # the hero's quarters, survives death

func stash_count(id: StringName) -> int
func stash_slots_used() -> int            # ceil(n / def.stack) per kind -- the BAG's rule
func stash_full() -> bool                 # slots_used >= K.STASH_SLOTS
func stash_room_for(id: StringName) -> int  # slack in the part stack + free slots x stack
func stash_add(id: StringName, n: int) -> int    # returns how many FIT
func stash_take(id: StringName, n: int) -> int   # returns how many CAME OUT
```

There are now three places an item can be, and they are not interchangeable:
`Run.bag` dies with the run, `Game.components` is uncapped and spendable only at
a bench, and `Game.stash` is **24 slots** (`K.STASH_SLOTS`) that survive death
and are unreachable from underground. `docs/METAGAME.md` §6.8 has the table and
the reason the cap exists.

Rules:

- **`stash_add` and `stash_take` return a count, not a bool.** Both are partial
  by design — a locker with room for two takes two of your four. A caller that
  treats the return as success/failure will destroy items, which is the exact
  bug the footlocker was built to fix.
- **Nothing moves in or out except through `Run.consume` / `Run.collect`.**
  `StashScreen` never touches `Run.bag`. Slot arithmetic and the heat premium
  (METAGAME §4.5) live in `run_state.gd` and stowing has to pay the same
  proration selling does, or the shelf becomes a way to launder heat value.
- **The stash is not cleared by `Run.enter()` and not banked by `extract()`.** It
  has no dungeon-side half at all; that is the point.
- New on `Bus`: `stash_changed(stock)`, `rested(slot)`.
- New on the save: a `stash` key. It arrived at `VERSION = 3` and rides in v4;
  see "Settings and saves" below for why v3 itself is no longer readable.

### Sleeping — `Flow.blink` fades without changing scene

```gdscript
Flow.blink(during: Callable, dark := 0.9) -> void   # fade out, pause, call, unpause, fade in
```

`Flow` owns the veil (CanvasLayer 200) and, per §10, is the only thing that may
call `change_scene_to_file`. `blink` is the fade *without* the transition, for
the case that has no scene on the other side of it: it takes `Flow.busy` and
`Prompt.blocked` the same way `_go` does, pauses the tree, runs `during` behind
the black, and lifts. It is a no-op while `busy` or `ending`.

It exists so `bed.gd` does not build a second veil on a second CanvasLayer.
Anything else that wants a black screen with no room behind it — an ending
beat, a cutscene wipe — calls this rather than tweening its own. The callable
runs **paused and in the dark**, so it is the right place for anything the
player should find already true when the lights come up: `Bed._sleep` autosaves
there specifically because `Saves.save` reads the hero out of the live tree and
should record him standing by his own cot.

### Bottles and draughts — the array's size is the count

```gdscript
# scripts/autoload/game_state.gd
var bottle_contents: Array[StringName] = []   # SIZE is how many bottles he owns
var draughts: Dictionary[StringName, float] = {}   # potion -> seconds left

func bottle_count() -> int
func bottle(i: int) -> StringName             # &"" for empty, &"" when out of range
func empty_bottles() -> int
func add_bottle() -> bool                     # false at K.BOTTLE_MAX; auto-binds if a slot is free
func fill_bottle(potion: StringName) -> int   # index filled, or -1
func drink_bottle(i: int) -> bool             # the bottle empties and STAYS
static func bottle_id(i: int) -> StringName   # &"bottle_0" ...
func bottle_index(id: StringName) -> int      # -1 if not an owned bottle

func draught_left(id: StringName) -> float
func start_draught(id: StringName, seconds: float) -> void
```

Rules:

- **There is no bottle count.** `bottle_contents.size()` is it. A separate
  integer is a second source of truth that will disagree with this one.
- **A bottle is USED, never drawn**, and that asymmetry is the whole reason
  items and weapons sit on different inputs. `Game.use_selected_item()` (X)
  drinks `item_selected` and nothing enters the hand. Making a draught a
  two-press item — take it out, then pull a trigger — would put the slowest
  input in the game on the button you reach for when you are about to die.
- **The item ring steps empties too** (`cycle_item`). A ring whose length
  changed every time you drank is a ring you cannot count, and counting is what
  makes ↓ usable without looking. `_clamp_item()` keeps the index honest rather
  than every caller doing it: bottles are bought, emptied, and rearranged at the
  alchemist, so an index that was valid when it was set does not stay valid.
- **The lasting draughts are folded into the forge's accessors**
  (`sword_bonus()`, `armour_soak()`), not into a parallel buff system. That is
  why nothing downstream needed changing, and it is why a new draught that
  changes a number should find the accessor that number already comes from.
- **Ask `ArmamentDb`, not `PotionDb`, when you are drawing a held or selected
  thing.** `name_of` / `slot_name` / `letter` / `blurb` answer for bottles too,
  so the HUD cluster and the Items screen never grow a bottle branch. `slot_name` is the
  short one, for cards; `name_of` is for a detail pane with a column to itself.
- New on `Bus`: `bottles_changed(contents)`, `potion_drunk(potion)`,
  `draught_changed(potion, seconds_left)`.
- **Bottles and contents are saved (`VERSION = 3`); the draught clocks are not.**
  Rebuild the array element by element with `StringName(c)` on load — JSON has
  no StringName, and a String-keyed reload draws a full bottle that refuses to
  be drunk.
- `AlchemyDb` exposes the identical five statics `ShopDb` does, and
  `TradeScreen.open(host, mode, title, db)` takes whichever. **Add a method to
  one and you add it to the other.**

### The way out — the Escape Rope

```gdscript
# scripts/items/escape_rope.gd, built by hero.gd as `hero.rope`
Bus.escape_rope_used.emit()      # the POUCH screen, after closing the menu
hero.rope.begin() -> bool        # or drive it directly, as directors do
hero.rope.active() -> bool       # rooted, mid-channel
hero.rope.cancel()               # a blow landed; emits Bus.escape_rope_broken
```

There is no extraction node and no exit room. `ExtractNode` is **deleted** —
do not add a second way out (METAGAME §5).

- **The rope channels, it does not teleport.** `CHANNEL_TIME` seconds rooted in
  the world, cancelled by a blow that *lands*. A blocked blow does not cancel it.
- **The hero is rooted by the same mechanism a shop uses**, so he still falls and
  still slides to a halt — `hero.gd` folds `rope.active()` into the same
  `locked` flag as `Prompt.blocked`, and `hero_combat.gd` locks the D-pad and
  the swing buttons but deliberately **not** the shield.
- **It is not on any ring.** It is not in `RIGHT_POOL` and must not be added —
  the way out of a run is a decision made from a menu, not a thing you can step
  onto with a D-pad press mid-fight.
- **Only `Run` decides whether leaving is possible, and money is not one of its
  reasons.** The fee is capped at the purse (`Run.extract_charge()`), so a toll
  bigger than your gold takes all of it and the rope still works. `can_extract()`
  is `in_dungeon` and nothing else. **Do not add an affordability check** — one
  here and one in `Run.extract()` were between them the game's only dead end, and
  the player they caught was always the one holding the best bag of the night.
  `Run.extract_cost()` is the toll, `Run.extract_charge()` is what leaves the
  purse, and **every UI that names a price shows the charge**.
- **Unowned gear is not on the body.** The bow and the hookshot each have two
  mounts, both built at `_ready` (a `BoneAttachment3D` is not something to be
  creating mid-run). The stow mount is shown only when `Game.has(id)` — without
  that gate the hero starts the game wearing a bow he has never found, while
  `cycle_armament` refuses to equip it.

Verified by `tools/directors/loadout_switch.gd`.

### Weapon and item models — built, read-only outside the orchestrator

Never load a weapon `.glb` yourself. The `weapons_hq` models carry **no embedded
images** — their diffuse ships beside them as
`assets/weapons/textures/<id>_diff.jpg` — so a raw load gives a flat grey wedge
that reads as a lighting bug. Two others need a scale correction. Both problems
are handled here:

```gdscript
# scripts/items/weapon_models.gd
WeaponModels.make("sword_knightly")   # -> Node3D, textured, correctly scaled
WeaponModels.extent(model)            # -> longest side in metres
```

Ids: `sword_knightly|noble|elegant|common|crude` (0.92 m),
`shield_knightly|noble|elegant|common|crude` (0.61–0.94 m), `kite_shield`,
`hookshot_pistol` (0.30 m).

Grip convention, **verified by render**, not by reading the GLB:

| | origin | axis |
|---|---|---|
| sword | the pommel | blade along +Y |
| shield | the **centre of the disc**, not the rim | front face +Z |
| hookshot | the grip | barrel along +Z, the way it fires |

Do not compute a bone-socket offset analytically. The rest-pose numbers are in a
rotated FBX space and will mislead you. Render it, look, adjust, render again.

### The sword — three lights, a heavy, and a lunge

`HeroCombat` owns what a blow COSTS and DOES; `Hero` owns the pose and the
facing. The split is why `Hero.Swing` exists at all: the animation tree needs one
`AnimationNodeOneShot` per variant, and a node cannot be addressed by a number
that only lives in the combat script.

```gdscript
enum Swing { LIGHT1, LIGHT2, LIGHT3, SPIN, LUNGE, DASH }   # on Hero
hero.request_attack(duration: float, variant := Swing.LIGHT1) -> bool
hero.request_lunge(duration: float, drive_time: float, hop: float) -> bool
hero.wish_dir() -> Vector3          # the stick, camera-relative, in world space
```

| Move | Clip | Button | Damage (quarter-hearts) |
|---|---|---|---|
| light 1 | `ss_slash_01` | attack | 2 |
| light 2 | `ss_slash_03` | attack, again inside `chain_window` | 2 |
| light 3 (finisher) | `ss_slash_04` | attack, again | 4 |
| heavy | `ss_slash_04` | heavy, **tapped** — on the release | 4 |
| spin | `ax_melee_attack_360_low` | heavy **held** past `charge_time`, on release, *instead of* the heavy | 5, all round |
| lunge | `ss_attack_01` | heavy, tapped, **locked on** and in range | 4 |
| dash | `ss_attack_03` | attack, with the **guard already up** | 3 |

The clips were picked off `tools/directors/swing_lookdev.gd`, which renders
every frame of every swing in the library — not off their filenames, which carry
no information at all. The three lights are a SEQUENCE (down, up, overhead), and
`ss_attack_01` is the only clip in which the hero's feet leave the ground, which
is why it is the lunge and was a terrible heavy.

The spin is the **only** clip in the kit borrowed from another character's
moveset: the sword-and-shield set has no 360 in it, so `build_anim_lib.gd`'s
`ONLY` allowlist takes exactly one clip from the axe set and leaves the rest.
It beat `ax_melee_attack_360_high` and `gs_high_spin_attack_1` in that same
sheet — the high one carries the blade behind the body and the greatsword one is
posed around a two-handed hilt. Its Mixamo tail is trimmed to 1.35 s (measured
with `tools/_clip_motion.gd`, not eyeballed) so `clip.length` still means "how
long this move takes".

**The chain's pace is `swing_time` (0.60 s) and it is also its animation
speed.** `Hero.request_attack` scales each clip by `clip_len / duration`, so the
number that owns the hero and the number that plays the swing are the same one —
there is no separate animation knob, and raising `swing_time` slows the picture
as well as the lockout. It was 0.46; at that pace three clips averaging 1.9 s
each were crushed into about a second and the finisher's leaping overhead went
past before you could see it was an overhead. `chain_time_scale` (0.92, 1.65)
multiplies it, so steps 2 and 3 move with it, and the damage windows are
fractions of it, so the blade's live slice sits in the same place in the swing.

**The chain is buffered.** A press in the back half of a swing
(`chain_buffer_from`) is remembered and paid out one frame AFTER the swing ends
— never on the boundary frame, because `HeroCombat` is the hero's CHILD and its
swing clock runs a frame ahead of his `MoveState.ATTACK`. Ask him on the
boundary frame and he refuses, and the press vanishes.

**The heavy and the spin are one pull** (§4). The press starts the wind-up and
throws nothing; the release throws whichever of the two `combat.charged` says,
buffered like any other intent if a swing is still running. Both END the chain
rather than counting as a step in it.

A wind-up **taken** from the player mid-pull — a shop opening, an item drawn, the
ground leaving his feet — pays out nothing at all, and the release edge that
arrives afterwards is swallowed (`_charge_t < 0`). Otherwise a cancelled hold
comes back as an overhead a second later, which is the same double-blow bug
wearing a different hat.

**The lunge is what Z-targeting buys.** It refuses without a lock, on purpose;
a version that also fired unlocked would just be a better standing attack. It
has no stick gate and no chain gate — both existed to tell a leap apart from an
ordinary swing pressed with the same thumb, and on a dedicated button a hidden
rule is just a button that intermittently does nothing.

**And no near range gate.** There was one — `lunge_min_range`, 1.9 m — whose
argument was that point blank there is no gap to close, so the leap reads as
hopping on the spot. 1.9 m is *inside sword range*: it is where you stand when
you are fighting something, so the button did nothing at the only distance
anyone presses it from, and that is precisely how it got reported as broken.
Point blank the leap now comes out with no travel (`request_lunge` clamps the
gap at zero), the clip's own jump carries the read, and the blow lands. The far
gate is the **lock's** reach — `K.LOCK_BREAK_RANGE`, the number the lock itself
breaks at rather than the one it acquires at — for the same reason the near one
went: if you can lock it you can leap at it, and anything shorter is a second
invisible range to learn. Inside the hysteresis band between the two the dodge
has already stood down for the leap (§4), so a leap refusing there would be a
dead press rather than a fallback. `lunge_max_speed` is what stops a long lock becoming a
teleport. Swept at 1.4 / 2.6 / 4.2 / 6.5 m by `tools/directors/lt_moveset.gd`.

Proved by `tools/directors/p4_combo.gd` (the chain, in damage),
`tools/directors/p4_charge.gd` (the hold: a tap is a tap, a short hold is a tap,
a long hold arms and pays) and `tools/directors/p4_lunge.gd` (the leap, in
metres closed against an unlocked control). The chain directors photograph
almost nothing — `capture()` stalls the game clock for longer than the chain
window, so a director that screenshots mid-chain breaks the thing it is
measuring. The poses are `swing_lookdev`'s job.

### Ranged — `HeroRanged` owns the bow and the hookshot

`scripts/combat/hero_ranged.gd`, a child of the hero and a **sibling of
`HeroCombat`**, not more of it. HeroCombat is the sword arm: the swing, the
block cone, the sockets every model hangs off. What an arrow does after it
leaves has nothing to do with any of that. HeroCombat still owns the combat
BUTTONS (one reader, §4) and hands the shoulders' two edges straight to it when
the right hand is not holding the sword (`HeroCombat._tick_item_trigger`).

**A drawn item is fired by a HELD shoulder, not a press.** Down raises and aims,
up fires. Either shoulder works — `attack` and `heavy` are ORed on both the edge
and the hold, because a player carrying a bow should not have to remember which
of two attack buttons a bow answers to (§4). Held rather than pressed is not
negotiable: these are AIMED items, and a button that fires on the press cannot be
aimed with — pulling RT to bring the bow up spent the arrow before the stick had
moved. The stance follows the button too,
so the shot ends with the item LOWERED and still in his hand, and the next shot
costs another pull.

```gdscript
hero.ranged.use_press(&"bow" | &"hookshot") -> bool  # raise it; false = ignored
hero.ranged.use_release()                            # loose it; safe when idle
hero.ranged.cancel_use()                             # put it down, fire nothing
hero.ranged.busy() -> bool                           # a shot is mid-flight
hero.ranged.aiming -> bool                           # a sighted item is OUT
hero.ranged.aim_item() -> StringName                 # ...and RAISED, or &""
```

`use_release()` is called **unconditionally** whenever neither shoulder is down,
not only while an item is out: D-pad ← / → can step the weapon out from under a
live draw, and a `_using` flag cleared only by the hand that set it is a bow
stuck at full draw the next time one is drawn.

`aiming` and `aim_item()` are deliberately different questions. The first is the
item being in his hand — the camera and the crosshair belong to that. The second
is the trigger being down — the POSE belongs to that. Letting go puts the bow
down without putting it away.

**A bow shot is two clips and one clock.** `K.BOW_DRAW[level]` seconds of pull
(`bow_draw_arrow`), then `HeroRanged.BOW_LOOSE` seconds of loose
(`bow_aim_recoil`), and the arrow leaves at the seam. Held past full draw the
clock STALLS at the seam rather than running on; released early it does not cut
the pull short, so a tap is exactly a full-strength shot and a mashed trigger is
never faster than an aimed one — which is what keeps `Game.bow_draw_time()`, the
forge ladder, meaning what it says.

**Only the LOOSE commits the hero.** The pull is a stance he can walk in
(`AimLoco`), because a hold has no length anybody knows in advance and rooting a
player for an unbounded one is a freeze with a button attached.

```gdscript
hero.request_bow_draw(draw_time) -> bool   # fires the PULL clip; commits nothing
hero.bow_loose(loose_time, aim)            # the seam — takes the commitment
hero.request_hookshot(duration, aim) -> bool          # one phase, not two
```

Only `HeroRanged` calls these, and it fires `bow_loose` off the same frame it
spawns the arrow — the string leaving his fingers and the arrow leaving the bow
are one event, and two things counting to it separately is how they come apart.
Proof is `tools/directors/bow_charge_release.gd`, which photographs the shot
across both clips: a boolean saying two nodes played is not a drawn bow.

**Aim mode has exactly one author, and the TRIGGER is what raises it.** Pulling
the bow or the hookshot drops the camera to the shoulder, draws a crosshair, and
changes how the body moves; letting go drops all three again. Three systems, one
decision — and if the camera, the HUD and the hero each decided for themselves
what counts as aiming they would disagree the first frame one of them was wrong.
`HeroRanged` is the one place that knows what is in his hands *and whether it is
up*, so it decides and says so:

*Selecting* the item does none of that, and used to. The stance was equipment-
driven, so choosing the bow on the D-pad put the game in a 42° sight with a
crosshair up and left it there for as long as you carried the thing. Carrying a
bow is not aiming a bow. `aiming` and `aim_item()` are therefore the same fact
now — one drops the item's name — and they are deliberately the same fact.

```gdscript
Bus.aim_changed(active: bool)          # emitted by HeroRanged, nobody else

camera.set_aiming(on)                  # connected to it in GameCamera._ready
camera.aiming() -> bool
hero.aiming() -> bool                  # both read through HeroRanged
hero.aim_item() -> StringName          # the same fact plus which item — true
                                       # only while the trigger is actually down

Bus.guard_changed(active: bool)        # emitted by HeroCombat, nobody else
camera.set_guarding(on)                # connected to it in GameCamera._ready
hero.blocking -> bool                  # set by HeroCombat.set_blocking
```

**The eye slides sideways; the boom does not turn.** Over-the-shoulder framing
offsets the camera's PIVOT laterally (`K.CAM_AIM_SHOULDER`) rather than yawing
the boom, so the screen-centre ray stays *parallel* to the boom axis. Yaw the
boom instead and the crosshair stops being where the camera raycast goes, which
is the whole thing the convergent aim above exists to guarantee. The blend is a
single `0..1` over `K.CAM_AIM_BLEND` driving distance, FOV and the offset
together; autoswing is suppressed for its duration (the player is aiming — the
camera does not get an opinion).

**And the boom does not pitch either — the eye tilts in place.** Free-look puts
the eye on an arm and swings it: pitch up and the camera drops behind you, which
is exactly right for a running third-person shot. At 1.55 m over the shoulder
that same arm is a disaster. Pulling the stick down to aim at something at your
feet lifted the eye to 2.75 m — over the hero's head, looking at his hair — and
pulling up dropped it to 0.32 m, below his knees, both while the crosshair swept
a modest arc. The player reads that as the reticle moving "from the wrong centre
point", because it is: the centre was a metre and a half behind him.
So `_place` splits the two pitches. The eye is *placed* at `_boom_pitch()`,
which blends the free pitch toward the rig's neutral `pitch_deg` on `_aim01` and
also feeds the wall sweep and the lift; only the look direction reads `_pitch`.
The wall's swing and lift bias fade out of the *view* on the same `_aim01` for
the same reason — a boom shoving itself past a pillar must not walk the shot.

Look gain scales with the lens (`_fov_gain`, the ratio of half-FOV tangents,
floored at 0.35). A stick that moves the world at a fixed rate in radians moves
it *three times faster across the screen* at 42° than at 75°, so without this the
sight is unusable at exactly the moment precision is the point.

While aiming the hero **strafes**: he faces where the camera faces, at ~1.8×
turn rate, and moves independently of that facing. This is the same shape as
lock-on and sits in the same place in `_tick_ground`, right after it.

**A raised shield takes the same tick** (`Hero._tick_camera_facing`, which is
`if aiming() or blocking`). That is OOT's Z-Parallel, and it is not a cosmetic
share: with the facing pinned, "backwards" finally means something, so a neutral
stick and `context` is a **backstep** — `_try_start_roll` sends him along
`-_forward()` with no stick gate, because this is a press you make from behind a
raised shield rather than one you fall into out of a run.

Guarding with nothing *locked*, that is. Once there is a lock the neutral press
belongs to the jump attack and the backflip costs a pull backwards (§4). The
no-target case keeps the backstep because the leap has nothing to leap at
there — a press only stands down for a move that is going to happen.

**The dodge has four directions, and which one you get is measured off the
facing, not off the stick.** `Hero._dodge_for` projects the committed
`_roll_dir` onto the facing and onto hero-right — `(-f.z, 0, f.x)`, and getting
that sign backwards is hero-*left*, which plays each sidehop as the other one
while the travel stays correct, so the frames are the only thing that catches
it. Whichever axis dominates picks the clip and the speed:

| `Dodge` | Clip | Speed | Duration | Model turned |
|---|---|---|---|---|
| `FORWARD` | `ex_roll_to_run` | `K.ROLL_SPEED` 6.55 | `roll_time` 0.62 | — |
| `BACK` | `ex_backflip` | `K.BACKFLIP_SPEED` 4.37 | `backflip_time` 0.50 | — |
| `LEFT` / `RIGHT` | `ex_roll_to_run` | `K.ROLL_SPEED` 6.55 | `roll_time` 0.62 | ±90° |

**The sideways dodge is the roll, turned.** It was `bow_dodge_left` / `_right`
out of the longbow set at `K.SIDEHOP_SPEED` for `hop_time`, and the travel was
right while the pose was not: the hero stayed bolt upright and *slid*, feet
shuffling like a man edging along a ledge. So LEFT and RIGHT play the forward
dive now, and the direction is carried by turning the **model** — `Hero`'s
`_dodge_model_yaw`, a difference between the roll's heading and `facing_yaw`
applied to the `Model` node, unwound at `dodge_unwind_deg` (420 °/s ≈ one
`roll_recover_time`) so he stands back up square. The body itself never turns:
locked or guarding, `rotation.y` stays on the target for the whole dodge, which
is what makes it a *strafe* dodge rather than a roll that breaks the lock.

That is also why the sidehop's own numbers stopped being read. i-frames are
literally `state == MoveState.ROLL`, so a shorter dodge is a narrower window —
leaving 0.44 s on a move that visibly dives would make the left-hand dodge
quietly worse than the forward one for no reason the player can see.
`K.SIDEHOP_SPEED` stays in `K`; it is measured footage (§6), and it is what a
real sidehop would be worth if a clip for one ever shows up.

Two more things about that table. The remaining speeds are the `[oot]` measured
constants. And each direction is still its **own** `AnimationNodeOneShot` +
`AnimationNodeTimeScale` pair (`Hero._DODGE_NODES`) even though three of them now
name one clip — reassigning `animation` on one live `AnimationNodeAnimation`
restarts the mixer cache and eats the wind-up frames.

And `BACK` is a **backflip**, which is the one row the longbow set could not
fill: `bow_dodge_back` is a backward shuffle-walk that never leaves the ground,
and a retreat is not an evade. It also owns the only duration that is neither
the roll's nor the hop's, because a flip has to launch, invert and land, and
0.44 s of that is a blur — which makes the backflip the widest i-frame window
short of a roll *and* the least ground covered per second. That is the trade
between the three: safest, fastest, furthest, pick one.

That duration was 0.60 and is 0.50. The old number was measured as "the shortest
window the clip stays legible in" and it was honest, but it was measuring a clip
that spent its first 0.45 s crouching (see the front-trim note below). With the
gather skipped, 0.50 s is all flip and every beat still reads.

Its source clip has 0.72 s of dead settle after the landing, cut in
`build_anim_lib`'s `TRIM` table rather than at the call site. That placement is
load-bearing: `Hero._fire_dodge` scales `clip_length / move_duration` so the
one-shot ends exactly when the dodge does, so **a clip's length has to mean the
move's length**. Trim the factor instead of the clip and the hero stands in the
export's settle pose for 0.4 s after the controller has already handed him back
to locomotion.

It has dead time on the **front** too, and that one is not trimmed at bake time —
it is skipped at play time by `Hero.backflip_start_offset` (0.45 s), exactly as
both jumps skip their anticipation crouch with `jump_start_offset`. The reason
for the difference: a trim changes the clip for everyone, and `dodge_lookdev`
wants the whole export. The reason it is skipped at all is
`tools/directors/_backflip_trace.gd`, which shoots the dodge the *game* plays
rather than the clip — uncut, the hero covered **1.31 m of a 2.53 m backflip
with his hips still at crouch height**, and did not leave the ground until
0.33 s into a 0.80 s move. A third of the move was a man squatting while sliding
backwards. Cut, he is airborne at 0.13 s.

`BACK` is therefore the one dodge whose one-shot is built by
`_add_scaled_jump_shot` (a *window* of a clip) rather than `_add_scaled_shot` (a
whole clip). `Hero._dodge_skip` is the single answer to "which seconds are being
played", read by both the tree builder and `_fire_dodge` — they must not
disagree, or the TimeScale is sized off seconds nobody is playing.

Because the i-frame window is literally `state == MoveState.ROLL` in
`take_hit`, the duration column *is* the invulnerability column: the backflip is
a shorter dodge than the roll, not just a slower one.

Two more things follow, and both were got wrong first:

- **The roll drops the guard** (`HeroCombat`: `not rolling and …`). `Block` is a
  blend sitting ABOVE the roll one-shot in the animation tree, so a guard held
  at amount 1.0 does not layer over the dive, it *replaces* it — the hero slides
  backwards across the floor in a standing block pose. Dropping it also makes
  the recovery honestly vulnerable, which is what the recovery is for. The
  button is still down, so the guard comes back up on landing.
- **Because the guard drops, `blocking` is the wrong thing to read once the roll
  is in flight.** `Hero._roll_keeps_facing` is captured when the roll *starts*
  and is what `_tick_roll_recover` bleeds along. Ask the live flag instead and
  every guarded backstep coasts back along the facing into the thing it just
  dodged away from.
- **The guard kills camera autoswing**, exactly as aiming does, via
  `Bus.guard_changed` → `GameCamera.set_guarding`. Autoswing drifts the lens to
  behind the hero while the hero steers to the lens: two rules writing one angle,
  with no error to close, so a guarded strafe walks the pair round together —
  measured at 31° off in half a second, in slow motion, with the stick never
  asking for a turn. Unlike `aim_changed` this does **not** recentre; a shield
  going up is not a change of shot.

Verified by `tools/directors/guard_lock.gd`, and note *what* it measures: the
turn **relative to the lens**, because the pinned facing follows the camera by
construction and the camera still arcs around obstructions. Unguarded, holding
left turns him 111°, of which 101° is his own. Guarded, the same input turns him
6°, of which 3° is his own — he only follows the shot. The rig's `_yaw` moves 0°
across the whole guarded strafe, which is what says the autoswing suppression is
doing the work rather than the threshold.

The four dodges and the dash are verified by `tools/directors/guard_moveset.gd`,
which asserts the `Dodge` that fired, the dominant travel axis, and — for the
dash — that `SwingDash` is active and the shield has dropped. It runs each move
**twice**: once measured with no captures, once photographed. That is not
redundancy. `rig.capture()` consumes game time, so a window that samples travel
and shoots frames in the same pass runs past the end of the dodge and reports a
2 m hop as a 0.3 m one. Its staging comment is worth reading before you move the
mark: the clearance that matters is the **camera's**, not the hero's — a mark
with 3 m of floor in front of it still shoots four unusable beats if the lens,
4 m behind, is inside a wall and gets pushed into his hair.

| clip | when |
|---|---|
| `bow_aim_overdraw` | bow out, standing — the held draw |
| `bow_aim_walk_forward` | bow out, moving — blended by planar speed |
| `ex_hookshot_fire` | hookshot out — **looped as a held brace**, not a one-shot |
| `bow_aim_recoil` | the loose, time-scaled onto the shot duration |

The hookshot needs its own held pose for a reason worth remembering: run it
through the bow's `Aim` blend and he braces a pistol in the full-draw archer
stance, both hands at his ear and the torso wound 90° off the shot. Two items,
two stances, two `Blend2`s — selected by `aim_item()`.

**Aim comes from the camera, and converges on what it is looking AT.** The
camera is the only thing carrying a player-controlled pitch (§4), so it is the
aim source; locked on, the bow overrides it and shoots the target. The muzzle is
the item's own model — the bow in the left hand, the hookshot in the right — so
it sits ~0.6 m off his centre line. **Aim parallel to the camera and every shot
travels its whole flight 0.6 m to one side of what the player lined up.** So the
camera raycasts for the point under the crosshair and the muzzle is aimed at
*that point*. Exact at every distance, which a fixed convergence distance is not.

```gdscript
# scripts/combat/arrow.gd — raycast-stepped, NOT an Area3D.
Arrow.new(); arrow.launch(from, dir, shooter)
```

At `K.ARROW_SPEED` an arrow steps 0.7 m per frame, further than a goblin is
wide. An Area3D only reports what it overlaps on the frame it is sampled, so it
passes through thin enemies about as often as it hits them — and the misses look
like bad aim. Each frame it raycasts the **segment** it is about to travel.
Ammo is spent at **release**, not on the press: a shot interrupted before the
arrow leaves costs nothing.

The shaft is `assets/weapons/arrow.glb` (`Arrow.MODEL_ID`), turned once by
`Arrow.MODEL_PITCH` onto the -Z this node flies down. The art-space fix is on
the **model node**, never on the Arrow's own basis — `-basis.z is forward` is
what the flight, the raycast and `_face_travel` all read (CLAUDE.md §4).

```gdscript
# scripts/world/arrow_bundle.gd — arrows on the floor. NOT a LootMote.
ArrowBundle.drop(parent, at, count, fling := Vector3.ZERO) -> ArrowBundle
```

Arrows live on `Game`, so a bundle grants ammo directly and never touches the
bag: no slot, no heat, no gold, no extraction fee, and a full bag cannot refuse
one. Walk-over, like a mote, with no pick-up button. A full **quiver** refuses
and the bundle stays lit on the floor rather than vanishing. Chests
(`Chest.arrow_chance`) and dungeon rooms (`Dungeon.arrow_chance`) place them;
the chest's roll happens **before** its loot rolls and always, whether or not it
lands, so adding it cannot shift a seed's contents.

```gdscript
# scripts/items/fletching.gd — arrows out of the bag, anywhere.
Fletching.can_fletch() -> bool      # short() is empty AND quiver_room() > 0
Fletching.fletch() -> int           # arrows made; 0 means it refused
Fletching.refusal() -> String       # why, in a sentence; "" when it will
Fletching.cost_line() -> String     # "2/2 Cracked Flint  +  0/2 Bone Shard"
```

It spends through `Run.consume(id, n)`, which is the **only** writer of the bag
besides `collect`/`sell` — the premium share leaves with what it takes, exactly
as a sale does. The card that draws it is on the POUCH screen (§ pouch, and
docs/METAGAME.md §4.6).

```gdscript
# scripts/items/hookshot_tether.gd — presentation only; the firer owns the
# raycast, the target choice, and moving the hero.
var t := HookshotTether.new()          # add as a child of the hero
t.begin(from, impact, pull_target)     # flies at K.HOOK_SPEED, fixed speed
t.advance(delta, from) -> bool         # true on the tick it arrives
t.update_pull(from)                    # while the hero travels
t.clear()
t.preview(from, impact, 0.0..1.0)      # one instant, for a director

# scripts/props/hook_target.gd — an authored ring the aim-assist prefers.
# Joins group `hookable`. Any surface in K.HOOK_RANGE stays a valid fallback.
ring.pull_point()    # where the hero lands: nudged up and out off the anchor
ring.anchor_point()  # where the head bites — what the reticle wants
```

Fixed **speed**, not fixed duration. A fixed duration makes near shots crawl and
far shots streak, which is the giveaway tell of a clone.

**A shot that lands on a monster is a third outcome.** The firing raycast reads
`L_WORLD | L_HOOK | L_ENEMY`, and a hit on `L_ENEMY` neither damages nor pulls:

```gdscript
foe.freeze(K.HOOK_FREEZE)   # 1.0 s, State.FROZEN, zero quarters of damage
foe.is_frozen() -> bool
```

Zero damage is the design, not a gap — `HealthComponent.apply_hit` refuses a
zero-quarter blow anyway, so nothing is sent down the damage path at all
(§ "one damage path"). The hero is handed straight back rather than dragged,
because reeling him into the thing he just stopped would spend the shot's reward
on closing the distance he wanted. `freeze` interrupts whatever the monster was
doing, takes an in-flight claw out of the air with it, holds `_cooldown` past the
thaw so it cannot swing the instant it comes back, and **stops the animation
clock** (`speed_scale = 0.0`) — a body still working through its idle loop is not
frozen however cold it looks. Three ways out of `FROZEN` — the timer, a blow, or
death — and `Enemy._thaw_body` is the one that all three go through, because
`_physics_process` returns before the state guard when the monster is `DEAD`.

Proof: `tools/directors/hook_freeze.gd`.

The hero side of it — `scripts/actors/hero/hero.gd`:

```gdscript
hero.request_ranged(duration, aim, hook := false) -> bool  # commits him, faces him down the aim
hero.hook_begin() -> bool                   # the hookshot takes him over
hook.hook_pull_to(point)                    # …and drags him there
hero.hook_end()
hero.hooking() -> bool
```

`request_ranged` reuses `MoveState.ATTACK` on purpose: the body does the same
thing during a draw as during a swing, and a second state would be two copies of
`_tick_attack` waiting to drift apart. The pull is its own `MoveState.HOOK`,
because that one really is different — **gravity is not applied while it runs**
(§ "the hookshot flies perfectly straight" applies to the hero too), and it ends
on arrival or on a timeout so a hook into moved geometry cannot strand him.

Proof: `tools/directors/ranged_kit.gd` (the loop, including the shoulder
camera), `tools/directors/ranged_anim_lookdev.gd` (the poses),
`tools/directors/bow_stow_lookdev.gd` (where the slung bow sits — read its
header before you decide it looks wrong).

The slam's half of the same boundary:

```gdscript
hero.request_slam() -> bool                 # refuses on the floor, and below slam_min_height
signal slammed(at: Vector3, fall_speed: float)   # the frame of contact, once
```

`slammed` is the seam, and it is what keeps the damage out of `hero.gd`. The
hero owns the body — the hang, the drive, the root, the two animation windows —
and knows nothing about what a hit is worth; `HeroCombat` listens for the signal
and does the dust, the sound, the shake and the sphere query. The alternative,
`hero.gd` reaching for `Hit.make`, is how the controller ends up owning the
damage table.

Proof: `tools/directors/slam_attack.gd` (measures the hang, the drive and the
root, then photographs the impact and checks a post takes damage),
`tools/directors/slam_lookdev.gd` (the clip, seeked and rendered, which is where
the two offsets came from).

### Music — picks itself, and nobody calls it

`Music` decides what is playing from the state the game is already in. **Do not
call it to start a track.** It reads:

- the current scene's path — `garrison` → `CALM`, anything else → `DELVE`;
- the enemy roster — any node in group `enemy` whose `state` is 1..4
  (CHASE/WINDUP/STRIKE/RECOVER, the range both enemy scripts agree on) → `FIGHT`,
  held for `FIGHT_LINGER` after the last one disengages;
- `Bus.boss_engaged` / `Bus.boss_defeated` → `BOSS`;
- no node in group `player` → `SILENT`, so lookdev and tool scenes stay quiet.

```gdscript
Music.mood_name()        # "SILENT" "CALM" "DELVE" "FIGHT" "BOSS" — for directors
Music.current_track()    # res:// path of what is playing, or ""
```

Every music import is **`loop=false` on purpose**: there are 3 dungeon, 7 combat
and 4 boss tracks, and the pool rotates without repeating rather than looping one
cue forever. If you set `loop=true` on one, it will never hand off and that mood
will play one track for the rest of the run. Volume is the `Music` bus, which
belongs to `Settings` — `Music` never touches `AudioServer`.

### Sound effects — emit, do not own a player

**Nothing outside `Sfx` should hold an `AudioStreamPlayer` for a world sound.**
Want a noise? Emit the interface that was already declared for it:

```gdscript
Bus.request_sfx.emit(&"chest_open", global_position)   # id = a file in audio/sfx/
```

`Sfx` also maps the events that already say what happened — `chest_opened`,
`door_opened`, `item_acquired`, `loot_gained`, `items_sold`, `puzzle_solved`,
`hit_landed`, `shield_blocked`, `enemy_died`, `player_died`, `target_acquired`,
`run_started`, `run_ended`, `bag_full` — so those need no emit
at all. Add a row to `Sfx.CUES` rather than a player to a prop.

`shield_blocked` is the one that had it the other way round and was corrected:
`HeroCombat.on_blocked` built a fresh `AudioStreamPlayer3D` per block and freed
it on `finished`, which is exactly the rule above. It emits and nothing else now.

The hero's own MOVES are the other half, and they are `request_sfx` emitters
rather than table rows, because none of them is a `Bus` signal: the jump and the
backflip grunt (`Hero.VOICE_EFFORT`), the other three dodges scuff
(`dodge_roll`), and the hookshot's three beats are `hookshot_load` on the brace,
`hit_armor` / `arrow_body_impact` on the bite, and `hookshot_pull` on the reel.

Two traps the table has already hit:

- **Some sounds only exist as `_N` variants.** `coin_trade` is on disk as
  `coin_trade_1..3` and `doom_stinger` as `doom_stinger_1` alone — the bare name
  resolves to nothing. List it in `Sfx.VARIANTS` with its count, including a
  count of 1.
- **A missing file is silent, not loud.** `Sfx._load` warns and returns null, and
  the game plays on. `tools/directors/sfx_cues.gd` fires every cue and asserts a
  voice actually started; `tools/directors/sfx_moves.gd` does the same for the
  hero's moves, through the buttons, and reads the ids back BY NAME so a right
  sound on the wrong move fails. Run them when you add one.
- **The human voice set on disk is silent.** `human_male_attack_1/2`,
  `human_male_hurt`, `human_male_death` and the female equivalents are all
  4 KB of digital silence — an ogg header and no samples, -91 dBFS peak. They
  resolve, they warn about nothing, and they play nothing. The project's only
  working vocalisation is `weapon_full_charge_voice_male_1`, which is what
  `Hero.VOICE_EFFORT` names.

Not wired, and deliberately: **footsteps**. `audio/sfx/footsteps/` has 14 material
folders, and using them needs a step event off the hero's animation plus a read
of what is underfoot. That is a system, not a table row.

### Settings and saves — built, tested, and read-only for everyone but P14

Two more autoloads exist. **The options UI never touches `AudioServer`, the
window, or the `InputMap` itself** — it calls these, which own persistence and
application:

```gdscript
Settings.set_volume(&"Music", 0.7)      # Master / Music / SFX / UI, 0..1 linear
Settings.rebind(&"attack", event)       # false if that key is already taken
Settings.reset_binds()
Settings.label_for(&"attack")           # "J" — for drawing the controls list
Settings.apply_video()                  # fullscreen, vsync, msaa, shadows, scale
Settings.changed                        # signal(section, key, value)
# fields: master/music/sfx/ui_volume, fullscreen, vsync, resolution_scale, msaa,
#   shadow_quality, fov_offset, invert_camera_y, camera_sensitivity, rumble,
#   camera_shake, letterbox_on_target
```

```gdscript
Saves.peek(slot)        # header for the slot list; {empty:true} if unused
Saves.save(slot)        # captures Game + hero position + current room
Saves.load_slot(slot)   # restores Game, RETURNS {scene, room, pos, yaw}
Saves.erase(slot)       # 3 slots, 0..2
Saves.autosave()        # Flow calls this on EVERY transition; false = declined
Saves.autosaved         # signal(slot) -- slot is -1 when it declined
```

The save file is at **`VERSION = 4`**, and `READABLE` — not `VERSION` — is what
`load_slot` checks. v2 added `bag_slots`, `upgrades` and `components` on top of
v1; v3 added `stash` and `max_stamina`; v4 is the gear split, where `plate`
stopped being one rung and became eight tracks. **v3 is refused rather than
migrated** and `READABLE` holds `[4]` alone, because a v3 `plate` key means
something the v4 accessors would read as a different piece of armour. An
*additive* version bump can be readable alongside its predecessor; this one was
not additive. `save_game.gd`'s header comment carries the full argument.

Every one of those dictionaries is rebuilt on load with `StringName` keys — JSON
hands back `String` keys, and a `String` key makes `forge_level(&"edge")` and
`stash_count(&"void_pearl")` miss silently, so every forged rung and everything
on the shelf vanishes.

`Saves.load_slot()` deliberately does **not** change scenes — it hands back
where the hero belongs and lets the caller transition however it wants.
Whoever owns room transitions should set `Saves.current_room` as rooms change.

**Autosaving is `Flow`'s, and it is unconditional.** The last thing `_go` does,
after the fade lifts, is call `Saves.autosave()` — there is no per-caller flag,
because all four ways through that function (in, down, home paid, home in a box)
are moments a player would be furious to replay, and a rule with no exceptions
cannot be forgotten by the fifth caller. It runs at the *end* on purpose:
`Saves.save` reads the hero out of the live tree, and the notice it raises is
drawn by the HUD, so announcing it behind a black screen announces it to nobody.

Two rules the format enforces, both proved by `tools/directors/autosave.gd`:

- **A recorded scene is never a dungeon.** `_save_scene()` returns `Flow.GARRISON`
  whenever `Run.in_dungeon`. A slot holds `Game` and nothing of `Run`
  (METAGAME §5), so a save pointing underground reloaded into a generated floor
  with no bag, no fee and no run behind it. That predates the autosave and was
  reachable by saving manually in the dungeon.
- **An autosave never overwrites a save made by hand.** It takes the active slot
  if there is one, else the first empty slot (which it then keeps), else it
  declines and emits `autosaved(-1)`. Picking a slot to sacrifice for a player
  who manages three by hand is the autosave deciding which of their saves
  mattered least.

`Hud` listens on `autosaved` and draws **AUTOSAVING…** bottom-right for 2.2 s on
the toast's baseline, in `MOTH` — the HUD talking about itself, not about the
world. It is a separate signal from `saved` because a manual save is made with
the menu open and needs no notice at all.

Audio buses `Master / Music / SFX / UI` exist in `default_bus_layout.tres`.
Anything that plays a sound must route to `SFX`, `Music`, or `UI` — never
straight to `Master`, or the volume sliders will not affect it.

### The floors — one row each, and `Prog` is still the only curve

`scripts/world/floor_db.gd` (`FloorDb`) owns the four authored floors of the
Descent (GDD §5): name and subtitle, room count, the per-distance roster table,
the tint, the boss and its item, the four anchor rules, and which relic lies in
which slot. It is **pure data** — no node building, no scene-tree reference, no
gameplay logic — and the acceptance test for changing a floor is one row, never
one `if`.

```gdscript
# scripts/world/floor_db.gd — read by Dungeon, BossDb, RelicDb, the kit.
FloorDb.floor_count() -> int              # 4, and SCOPE §1 freezes it there
FloorDb.is_authored(level) -> bool
FloorDb.get_floor(level) -> Dictionary    # never empty; past 4 it is ENDLESS
FloorDb.name_of(level) / .subtitle_of(level) -> String
FloorDb.rooms(level) -> int               # authored, or defers to Prog
FloorDb.pack(level) -> Vector2i           # authored, or defers to Prog
FloorDb.bands(level) -> Dictionary        # room distance -> pool of kinds
FloorDb.roster(level, room_dist) -> Array
FloorDb.tint(level) -> Dictionary         # .tint_key(level) -> StringName
FloorDb.boss(level) / .boss_item(level) -> StringName
FloorDb.shortcut_key(level) -> StringName # == boss_item(level)
FloorDb.vault_key(level) -> StringName    # == boss_item(level + 1)
FloorDb.has_vault(level) -> bool
FloorDb.anchors(level) -> Dictionary      # .anchor(level, id) -> Dictionary
FloorDb.relics(level) -> Dictionary       # .relic_in(level, slot) -> StringName
```

Three boundaries this file must not cross, each of which is a rule from
elsewhere that a manifest is uniquely well placed to break:

- **It carries no difficulty curve.** `scripts/core/progression.gd` still owns
  health, damage, wind-up, elite share, drop rolls and chest picks. `rooms` and
  `pack` are shape, not difficulty, and a row that does not want to author them
  says `ROOMS_FROM_PROG` / `PACK_FROM_PROG` and defers. Two curves is how a floor
  ends up with tougher monsters and worse loot (GDD §7).
- **The two fork rules are one line each.** `shortcut_key` is this floor's own
  boss item and `vault_key` is floor N+1's, exactly as GDD §5.3 words them.
  "Floor 4 has no vault" is written nowhere — it falls out of there being no
  floor 5 to lend it a key, and it must stay that way.
- **Four tints, and none of them dims the room.** `TINTS.size()` is SCOPE §1's
  variety budget. Every `stone` entry is a multiply with a channel at 1.00, and
  every `air` is *lighter* than the shipped `env_dungeon.tres` fog — contrast is
  range and hue, never an absence of light (GDD pillar 5, STYLEGUIDE §1).

`RelicDb` owns what a relic does; `FloorDb` owns only where it lies. `BossDb`
owns the move sets; `FloorDb` owns only the id. The Long Descent (GDD §8) is one
extra row, `ENDLESS`, returned for every level past 4 — plus
`LONG_DESCENT_RELIC`, which is a named row rather than a field on `ENDLESS`
because a relic in that row would drop on floor 5, 6, 7 and forever.

### The map — one plan, two sizes, and the fog is the room trigger

There is **one** map in this game. `Atlas` holds the plan; `MapDraw.draw_map` is
the only thing that draws it, and it is called twice — by `Hud._draw_minimap`
into a 148 px square in the top-right corner, and by `MenuMapPanel` into the MAP
tab of the pause menu. The only difference between them is the size of the box.
Do not write a second map; a menu map that re-derived the layout is the one that
goes stale.

`Dungeon._publish()` is the **only writer** of the room graph, and it writes it
in the same pass that builds the geometry. Markers go on from `_populate` and
from the objects themselves: `Chest.activate` swaps `M_CHEST` → `M_CHEST_OPEN`,
`ArrowBundle._take` clears `M_ARROWS`. Both go through `Atlas.replace_at(world
position, from, to)` and **not** by name — `Bus.chest_opened` carries a node
name, and that name is `Chest` in every room on the floor.

Fog of war is `Atlas.seen`, written by the room trigger `Dungeon._add_room_trigger`
already had. A room is on the map for exactly the same reason it counts toward
the extraction fee: **the player walked into it.** `Atlas.see()` sits outside the
trigger's `visited` gate so the two rules stay independent. Nothing may reveal a
room by proximity, by line of sight, or by owning an item — that would be a
second definition of "have I been here" sitting next to `Run.descend()`'s.

The plan is not persisted and does not survive the run: `open_floor` wipes the
previous floor, and `Bus.run_ended` wipes it entirely. `Atlas.bounds()` is the
whole floor including fogged rooms, deliberately — fitting to the explored subset
would re-scale and re-centre the map every time a door opened, which makes the
one instrument whose job is orientation the least stable thing on screen.

Markers are drawn shapes in `Pal` colours, not textures. At 6 px on the minimap
a photograph of a chest is four brown pixels; a gold box with a dark band is a
chest. `Atlas`'s marker ids and `MapDraw.MARK_ORDER` are two halves of one list —
an id with no glyph draws nothing, silently. Add to both.

---

## 9. Proving your work — you do not get to say it looks good

You produce **frames**, and the critic compares them to `refs/`.

```bash
godot --path . -s tools/shoot.gd -- \
  --scene=res://scenes/rooms/room_01.tscn \
  --out=/abs/path/shot.png --warmup=45 --size=1280x720
```

Add `--burst=8 --burst-gap=4` for a sequence, or
`--director=res://tools/directors/foo.gd` for a script that drives real input:

```gdscript
func run(rig):
    await rig.hold(["move_up"], 40)       # walk forward 40 frames
    await rig.capture("f1.png")
    await rig.hold(["z_target"], 6)       # lock on
    await rig.hold(["move_left", "z_target"], 30)   # strafe while locked
    await rig.capture("f2.png")
    await rig.tap(["attack"])
```

Contact sheet, and blind A/B against a real OOT screenshot:

```bash
python3 tools/ab.py sheet 'out/f_*.png' --out out/sheet.png
python3 tools/ab.py ab --ours out/shot.png --ref refs/screens/ztarget_01.png \
    --out out/ab.png --key out/.key.json --seed 7
```

**Camera, movement, and feel cannot be judged from one frame.** If your piece
moves, deliver a contact sheet driven by a director. A critic who is handed a
single static frame for a motion piece will fail you for that alone.

Before you report done, the project must open clean:

```bash
godot --path . --headless --import >/dev/null 2>&1
godot --path . --headless --quit-after 5 2>&1 | grep -iE "error|script.*failed" || echo CLEAN
```

Adding a script with a new `class_name`? Re-import first or the global class
will not resolve.

---

## 10. Rules

- Godot 4.7 / GDScript, **static types**, Forward+.
- **Before implementing any Godot system, invoke the matching `godot-prompter:*`
  skill.** Knowing the class is not knowing the pattern.
- No placeholder art you intend to replace later. The look **is** the
  deliverable — build geometry and materials to the bar now.
- Tunable numbers go in `@export` vars or `K`, never buried as literals. The
  critic will ask you to change one.
- Do not `git add` or `git commit`. The orchestrator reviews and commits.
- Do not "fix" a file outside your allowlist, and never revert a shared file.

### Traps that have already cost us time

- **Autoloads do not exist under `godot -s`.** A SceneTree script replaces the
  main loop, so `Bus`/`Game`/`Settings`/`Saves` are simply absent. Anything that
  touches them runs as a real scene: `godot --path . --headless res://tools/scenes/x.tscn`.
- **A new `class_name` is invisible until you rescan.** Run
  `godot --path . --headless --import` or every reference is "not declared".
- **`class_name` only resolves for scripts inside the project.** A test in the
  scratchpad cannot see `K`.
- **`K.flat()` NORMALISES.** It is a direction helper, not a projection:
  `K.flat(a - b).length()` is `1.0` for every pair of points in the world. The
  lunge's leap speed and its range gate were both computed that way and came out
  as "every target is exactly 1 m away" — the leap stood still and the range gate
  admitted everything. Flatten by hand when you want a DISTANCE:
  `var d := a - b; var dist := Vector2(d.x, d.z).length()`.
- **`/` is reserved** as the library/animation separator. Namespace clips with `_`.
- **An imported FBX ships a stub `""` AnimationLibrary.** Evict it before adding
  a merged one, or you get "Can't add animation library twice with name: ''".
- **Comments in `project.godot` must start with `;`.** A `#` comment is a parse
  error that silently **eats the assignment directly after it**. This cost an
  afternoon: `ui_accept` fell back to the engine default while `ui_cancel`, one
  line further down past the damage, applied fine — an asymmetry that reads as an
  engine quirk and invites a completely wrong theory.
- **A test cannot write the real `user://settings.cfg` any more, and that is a
  mechanism now rather than a rule.** `shoot.gd` points `Settings.path` at
  `user://harness_settings.cfg` before the autoloads are ready, deletes that
  file at the head of every run so each run starts from the shipped layout, and
  `_verify_sandbox` fails the run if the redirect ever stops taking. Pass
  `--settings=user://your.cfg` to name a different file; it still wins.

  This used to be the advice "pass `--settings=`", and the advice was followed
  exactly zero times by the director that needed it. A menu test left `attack`
  bound to `N` and the sword was dead — **twice**, months apart. The second time
  was worse than the first: `shoot.gd` strips the pad bindings for the run
  (below), so the bind that got saved had no pad event in it at all, and
  `Settings.apply_binds` erases an action before replaying it. One keyboard
  rebind in a screenshot run unbound **RB** from `attack` permanently. A doc
  comment asking the next author to remember a flag is not a control.
- **A gamepad plugged into the machine drives the harness too.** Sticks resting
  just outside the deadzone report `move_up`, `move_right`, `cam_down` and
  `cam_left` HELD, with nothing pressed. The hero walks off his mark mid-beat,
  `Prompt` drops focus, and the director reports failures in the *system it was
  testing* rather than in the input it never controlled. It is intermittent
  because the drift wanders, so it reads as a race in the game. `shoot.gd`
  strips joypad bindings from the InputMap at startup (in memory —
  `project.godot` is untouched); any harness that does not go through it must do
  the same.
- **`OS.get_keycode_string()` returns `""`** for Enter, Space and the arrows in
  this build while working for Escape. Print raw keycodes in diagnostics; a
  half-working readout invents bugs that are not there.
- **A weapon socket has TWO axes that can be wrong, and fixing one hides the
  other.** The shield took three passes because each pass swept a single axis:
  yaw picks which face meets the blow, roll picks whether the point hangs down
  or stands at the sky, and a shield with the right face and the wrong roll
  still looks broken. When a mount reads wrong, sweep every axis at 90-degree
  steps in one pass and put them on a contact sheet.
- **`DisplayServer.window_set_mode()` runs a nested main-loop iteration on
  macOS.** It flushes the deferred queue AND emits `process_frame`, so anything
  awaiting either can be resumed in the middle of an autoload's `_ready`, while
  the scene tree root is still adding children. `Settings.apply_video` did this
  at boot and broke every `tools/shoot.gd` capture with "parent node is busy
  setting up children". Never re-assert a window mode that is already set.
- **`window/size/mode=2` is MAXIMIZED, not WINDOWED.** Code that forces
  `WINDOW_MODE_WINDOWED` as "not fullscreen" shrinks the window on every launch.
