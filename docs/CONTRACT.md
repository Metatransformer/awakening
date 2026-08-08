# The Lower Worlds: Awakening — Build Contract

Many agents build this game in parallel. This file exists so they do not collide
or drift. It fixes **units, names, interfaces, and file ownership** — nothing
else. How you implement your piece is yours to decide.

> **This supersedes the top-down Link's Awakening brief** kept at
> `docs/CONTRACT.topdown.old.md`. That brief is dead. Do not build to it.

---

## 0. What we're building

A **third-person, over-the-shoulder 3D dungeon crawler in the style of The
Legend of Zelda: Ocarina of Time (N64, 1998)**, in Godot 4.7, Forward+.

- Camera behind and above the hero; **Z-targeting / lock-on** is the centre of
  the whole design — combat, camera, and movement all change mode when it's on.
- WASD + mouse **and** full controller support, equivalently.
- Sword, shield, bow, bombs, hookshot.
- **One cyclic, key-locked intro dungeon** ending in a boss.

**The bar is `refs/`.** Real Ocarina of Time screenshots in `refs/screens/`, the
measurable checklist in `refs/REFERENCE.md`, the dungeon-structure bar in
`refs/structure/dungeon_structure.md`. Nothing is "done" because it looks fine
on its own — it is done when it survives a blind A/B against `refs/`.

We are matching OOT's **feel, framing, pacing, and structure**. We are not
copying its assets, characters, or names. Our hero is a hooded warrior, not
Link. Refer to him as **the hero** in code and comments.

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
| Chest | 1.1 wide x 0.8 deep x 0.8 tall |
| Pot | 0.5 diameter, 0.6 tall |
| Push block | 1 tile: 2.0 x 2.0 x 2.0 |

Constants live in `scripts/core/consts.gd` (`class_name K`). Use `K.TILE`, never
a literal `2.0`. **Anything you tune that another piece can see belongs in `K`.**

---

## 2. The hero rig — already built, shared, read-only

Proven working. Do not rebuild this.

- **Model:** `res://assets/characters/hero.fbx` — textured, `Skeleton3D` with
  33 `mixamorig_*` bones, mesh is 1.0 units tall.
- **Animations:** `res://assets/animations/hero_anims.res`, a single
  `AnimationLibrary` of **72 clips on that exact skeleton — no retargeting
  needed**. Names are `<set>_<clip>`:
  - `ss_*` — sword & shield (51): `idle_01..04`, `walk_01/02`, `run_01/02`,
    `strafe_01..04`, `slash_01..05`, `attack_01..04`, `block_01/02`,
    `block_idle_01`, `impact_01..03`, `180_turn_01/02`, `turn_01/02`,
    `jump_01/02`, `kick_01`, `power_up_01`, `death_01/02`, `casting_01/02`,
    `draw_sword_1_01`, `sheath_sword_1_01`, `crouch*`
  - `ex_*` — extra (7): `running`, `fast_run`, `roll_to_run`,
    `sword_combo_light`, `sword_combo_heavy`, `cast_light`, `cast_heavy`
  - `mg_*` — magic (14): casts, hit reactions, `react_death_backward`
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

## 3. Autoloads — owned by the orchestrator, do not edit `project.godot`

| Autoload | Script | Purpose |
|---|---|---|
| `Bus` | `scripts/autoload/event_bus.gd` | sideways peer→peer signals |
| `Game` | `scripts/autoload/game_state.gd` | hearts, magic, keys, items, flags |

Need a new autoload, input action, or project setting? **Ask the orchestrator.**
Do not edit `project.godot` — it is the one file every agent would fight over.

Signals on `Bus` and fields on `Game` are **additive**: append yours, never
rename or remove someone else's.

---

## 4. Input actions (already registered — keyboard AND pad)

| Action | Keyboard / mouse | Gamepad | OOT equivalent |
|---|---|---|---|
| `move_up/down/left/right` | WASD, arrows | left stick | control stick |
| `cam_up/down/left/right` | (mouse motion, read in code) | right stick | C-buttons / free look |
| `z_target` | **Q**, right mouse | **L trigger**, LB | **Z** — hold, not toggle |
| `attack` | **J**, left mouse | **X** | B — sword |
| `shield` | **K**, Ctrl | **R trigger**, RB | R — hold to raise |
| `context` | **Space** | **A** | A — roll / climb / jump |
| `interact` | E, F, Enter | A | A — open / talk / lift |
| `item_left` / `item_up` / `item_right` | **1 / 2 / 3** | dpad-left / Y / B | **C-left / C-up / C-right** |
| `first_person` | R | dpad-up | C-up look |
| `pause` / `map` | Esc / Tab | Start / dpad-right | — |
| `dbg_reload` | F5 | — | — |

Read movement as
`Input.get_vector("move_left","move_right","move_up","move_down")` so stick and
keyboard behave identically. Movement is **camera-relative**: the input vector is
rotated by the camera's yaw before it becomes world motion.

`z_target` is **held**, exactly like OOT's Z. Tapping it with no valid target
recentres the camera behind the hero; holding it with a target locks on.

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
| orchestrator | `project.godot`, `docs/**`, `tools/**`, `scripts/core/**`, `scripts/autoload/**`, `refs/**`, `progress.html`, `assets/characters/**`, `assets/animations/**` |

Shared read-only for everyone: `scripts/core/consts.gd`, `refs/**`, `assets/**`.

---

## 8. Interfaces every piece touches

### Damage — one path, no second one

Anything that can be hurt has a `HealthComponent`
(`scripts/combat/health_component.gd`, owned by P4):

```gdscript
class_name Hit extends RefCounted
var amount: int          # in QUARTER hearts (K.QUARTER); 4 = one heart
var from: Vector3        # world position the hit came from
var knockback: float     # metres/sec applied away from `from`
var stun: float          # seconds the victim is stunned
var kind: StringName     # &"sword" &"arrow" &"bomb" &"contact" &"fire"

# on HealthComponent:
func apply_hit(hit: Hit) -> void
signal damaged(hit: Hit)
signal died
```

Anything that deals damage puts an `Area3D` in group `hitbox` and calls
`apply_hit`. **Do not invent a second damage path.**

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

### Items — C-button slots

```gdscript
# scripts/items/item.gd, owned by P5
class_name Item extends Resource
@export var id: StringName        # &"bow" &"bombs" &"hookshot"
@export var icon: Texture2D
@export var magic_cost: int
func use(hero: Node3D) -> void
func release(hero: Node3D) -> void   # for held/charged items
```

`Game.c_items: Array[StringName]` of length 3 is what the HUD draws and what
`item_left/up/right` fires.

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
