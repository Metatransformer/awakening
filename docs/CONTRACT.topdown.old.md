# Build Contract

Several agents build this game in parallel. This file exists so they do not
collide or drift. It fixes **units, names, and file ownership** — nothing else.
How you implement your piece is yours to decide.

---

## 0. What we're building

A Zelda-style dungeon vertical slice in Godot 4.7, Forward+, **3D rendered,
top-down 2D gameplay** — the Link's Awakening (Switch, 2019) diorama look.
Keyboard: WASD move, sword + shield combat. Nonlinear dungeon with keys, chests,
puzzles, one dungeon item, and a boss.

**The bar is `refs/`.** Real screenshots in `refs/screens/`, the measurable look
checklist in `refs/REFERENCE.md`, the dungeon-structure bar in
`refs/structure/dungeon_structure.md`. Nothing is "done" because it looks fine on
its own — it is done when it survives a blind A/B against `refs/`.

---

## 1. Units and scale — do not renegotiate these

| Thing | Value |
|---|---|
| `TILE` | **2.0 m** — one floor tile |
| Room | **10 x 8 tiles** = 20 x 16 m, floor plane at `y = 0` |
| Wall height | 3.0 m, wall band occupies the outer half-tile of the room |
| Door opening | 2 tiles wide (4.0 m), centered on a room edge |
| Link | capsule radius 0.6, body height 1.9, eyes/cap top ≈ 2.0 |
| Chest | 1.6 wide x 1.4 deep x 1.2 tall |
| Pot | 0.9 diameter, 1.0 tall |
| Push block | exactly 1 tile: 2.0 x 2.0 x 2.0 |
| Gravity | default down `-Y`. Movement happens on the XZ plane. |

`+Z` is screen-down, `+X` is screen-right, `-Z` is screen-up. "North" = `-Z`.

Constants live in `scripts/core/consts.gd` (`class_name K`). Use `K.TILE`, never
a literal `2.0`.

---

## 2. Autoloads — owned by the orchestrator, do not edit `project.godot`

| Autoload | Script | Purpose |
|---|---|---|
| `Bus` | `scripts/autoload/event_bus.gd` | sideways peer→peer signals |
| `Game` | `scripts/autoload/game_state.gd` | hearts, keys, items, flags |

Need a new autoload, a new input action, or a project setting? **Ask the
orchestrator.** Do not edit `project.godot` yourself — it is the one file every
agent would fight over.

Signals on `Bus` are additive: append yours, never rename or remove someone
else's. Same rule for `Game`.

---

## 3. Input actions (already registered)

`move_up` `move_down` `move_left` `move_right` — W A S D **and** arrow keys
`attack` — J and Space (sword)
`shield` — K and Shift (hold to raise shield)
`use_item` — L and E (the dungeon item)
`interact` — F and Enter (open chest / read / lift)
`pause` — Escape
`dbg_reload` — F5

Read input through `Input.get_vector("move_left","move_right","move_up","move_down")`
so keyboard and any future pad behave identically.

---

## 4. Groups

`player`, `enemy`, `hurtbox`, `hitbox`, `pushable`, `door`, `switch`,
`interactable`, `boss`. Query with `get_tree().get_first_node_in_group(...)`.

## 5. Collision layers

| Bit | Layer |
|---|---|
| 1 | world (walls, blocks, static) |
| 2 | player body |
| 3 | enemy body |
| 4 | player hitbox (sword, item) |
| 5 | enemy hitbox (contact, projectiles) |
| 6 | interactable / trigger volumes |
| 7 | pits and floor hazards |

---

## 6. File ownership

**Only edit files your work package owns.** If you need something from another
package, code against the interface described here and leave a `# NEEDS:` note in
your report — do not reach into their folder and "fix" it.

| Package | Owns |
|---|---|
| P1 look | `scenes/kit/**`, `scripts/kit/**`, `assets/materials/**`, `scenes/rooms/_lookdev.tscn` |
| P2 link | `scenes/actors/link/**`, `scripts/actors/link/**` |
| P3 combat | `scenes/actors/enemies/**`, `scripts/actors/enemies/**`, `scripts/combat/**` |
| P4 dungeon | `scenes/rooms/**` (except `_lookdev`), `scripts/dungeon/**`, `data/dungeon/**` |
| P5 puzzles | `scenes/props/**`, `scripts/props/**` |
| P6 item | `scenes/items/**`, `scripts/items/**` |
| P7 boss | `scenes/actors/boss/**`, `scripts/actors/boss/**` |
| P8 hud/feel | `scenes/ui/**`, `scripts/ui/**`, `scripts/feel/**`, `assets/audio/**` |
| orchestrator | `project.godot`, `docs/**`, `tools/**`, `scripts/core/**`, `scripts/autoload/**`, `refs/**`, `progress.html` |

Shared read-only for everyone: `scripts/core/consts.gd`, `refs/**`.

---

## 7. The one interface everyone touches: damage

Anything that can be hurt exposes a `HealthComponent`
(`scripts/combat/health_component.gd`, owned by P3) with:

```gdscript
func apply_hit(hit: Hit) -> void   # Hit: {amount:int, from:Vector3, knockback:float, stun:float}
signal damaged(hit: Hit)
signal died
```

Anything that deals damage puts an `Area3D` in group `hitbox` and calls
`apply_hit`. Do not invent a second damage path.

---

## 8. Proving your work

You do not get to say it looks good. You produce frames:

```bash
godot --path . -s tools/shoot.gd -- \
  --scene=res://scenes/rooms/_lookdev.tscn \
  --out=/abs/path/shot.png --warmup=45 --size=1280x720
```

Add `--burst=8 --burst-gap=4` for a motion sequence, or
`--director=res://tools/directors/foo.gd` for a script that drives input
(`await rig.hold(["move_up"], 30)`, `await rig.tap(["attack"])`,
`await rig.capture("f1.png")`). Contact sheet:

```bash
python3 tools/ab.py sheet 'out/f_*.png' --out out/sheet.png
```

**Animation and feel cannot be judged from one frame.** If your piece moves,
deliver a contact sheet.

Before you report done: the project must open clean. After adding any script
with a new `class_name`, re-import first or the global class won't resolve.

```bash
godot --path . --headless --import >/dev/null 2>&1
godot --path . --headless --quit-after 3 2>&1 | grep -iE "error|script.*failed" || echo CLEAN
```

---

## 9. Rules

- Godot 4.7 / GDScript, static types, Forward+.
- Before implementing any Godot system, invoke the matching `godot-prompter:*`
  skill. Knowing the class is not knowing the pattern.
- No placeholder art that you intend to replace later — the look **is** the
  deliverable. Build geometry and materials to the bar now.
- Do not `git add` or `git commit`. The orchestrator reviews and commits.
- Do not "fix" a file outside your allowlist, and never revert a shared file.
