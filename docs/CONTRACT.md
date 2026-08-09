# The Lower Worlds: Awakening — Build Contract

Many agents build this game in parallel. This file exists so they do not collide
or drift. It fixes **units, names, interfaces, and file ownership** — nothing
else. How you implement your piece is yours to decide.

> **This supersedes the top-down Link's Awakening brief** kept at
> `docs/CONTRACT.topdown.old.md`. That brief is dead. Do not build to it.
>
> **`docs/METAGAME.md` supersedes §0's structure** — the one key-locked dungeon
> ending in a boss is replaced by a Moonlighter-style loop: a town with a vendor
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
| `Settings` | `scripts/autoload/settings.gd` | volumes, video, binds, and their persistence |
| `Saves` | `scripts/autoload/save_game.gd` | slots |
| `Music` | `scripts/autoload/music.gd` | picks the track and crossfades it; **after `Bus`** |
| `Sfx` | `scripts/autoload/sfx.gd` | implements `Bus.request_sfx`, owns the signal→sound table; **after `Bus`** |
| `Hud` | `scripts/ui/hud/hud.gd` | the overlay, `CanvasLayer` **50** |
| `Prompt` | `scripts/autoload/prompt.gd` | which Interactable owns the interact button |
| `Menu` | `scenes/ui/menu/pause_menu.tscn` | the pause menu, `CanvasLayer` **100** |
| `Flow` | `scripts/autoload/game_flow.gd` | town↔dungeon + the fade, `CanvasLayer` **200**; **loads LAST** |

The three `CanvasLayer` numbers are a stack, not preferences: the HUD draws under
the pause menu, and Flow's fade covers both. A fade something can draw on top of
is not a fade.

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
| `attack` | **LMB** | **RB / R1** (pad10) | light attack |
| `shield` | **RMB** | **LB / L1** (pad9) | guard |
| `context` | **Space** | **B / Circle** (pad1) | roll / backstep |
| `z_target` | **Q**, MMB | **R3** (pad8) | lock-on |
| `interact` | E | **A / Cross** (pad0) | event action |
| `item_left` / `item_up` / `item_right` | 1 / 2 / 3 | dpad L / U / R | armaments — §4.1 |
| `first_person` | R | — | — |
| `pause` / `map` | Esc / Tab | Start (pad6) / L3 (pad7) | menu / map |
| `dbg_reload` | F5 | — | — |

A/Cross is ER's jump. This game has no jump, so the event action takes it and
the roll takes B/Circle, where the source material has it.

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

**Not yet bound, because the ability does not exist:** heavy attack (RT/R2,
`Shift`+LMB), skill (LT/L2, `Shift`+RMB), and jump. Do not register empty
actions for these; bind them in the same change that builds them.

Read movement as
`Input.get_vector("move_left","move_right","move_up","move_down")` so stick and
keyboard behave identically. Movement is **camera-relative**: the input vector is
rotated by the camera's yaw before it becomes world motion.

`z_target` is a **TOGGLE**, which is Elden Ring rather than OOT: press to lock,
press again to release, press with nothing lockable to recentre the camera
behind the hero. It is not held — holding a shoulder button and steering the
camera with the same thumb is the thing R3 exists to avoid.

### 4.1 The item buttons — the D-pad is the C-pad

Three of the four directions are **bindable item buttons**, the way Ocarina's C
buttons are. What is on them is the player's choice, made in the Items screen:

| Button | Does |
|---|---|
| dpad ← (`item_left`, key `1`) | draw whatever is bound here; press again to put it away |
| dpad ↑ (`item_up`, key `2`) | as above |
| dpad → (`item_right`, key `3`) | as above |
| dpad ↓ (`item_down`, key `4`) | swap to the **alternate loadout** — bow and arrows by default |

**Nothing cycles in play.** Cycling lives entirely in the menu, because a button
you have to watch to use is not a button you can reach for — the whole value of
a bound item is that your thumb knows where it is. `Game.quick_slots` owns the
bindings and `Game.loadout` owns the hands; see §8 *Armaments*.

Finding an item **auto-binds it to the first free button**, as the source
material does. Being made to open a menu before you can shoot a bow you just
found is the one thing Ocarina never does to you.

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

`Game.c_items` is **gone**. It was the half-built C-button idea — three slots,
an auto-assign on pickup, and nothing that read them. It is now
`Game.quick_slots` and it is wired to actual buttons. Saves written under the
old `"c_items"` key still load.

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

var quick_slots: Array[StringName] = [&"", &"", &""]   # C-buttons ←, ↑, →

func armament(hand: StringName) -> StringName     # what is in that hand, now
func armament_in(set_index: int, hand) -> StringName
func swap_loadout() -> void                       # dpad ↓
func cycle_armament(hand: StringName, dir := 1, set_index := -1)   # menu only

func quick(slot: int) -> StringName               # what is on that C-button
func bind_quick(slot: int, item_id: StringName) -> bool   # menu only
func cycle_quick_bind(slot: int, dir := 1) -> void        # menu only
func use_quick(slot: int) -> void                 # dpad ← / ↑ / →
```

`use_quick` puts the bound item in the **right hand**, and puts it away again on
a second press. That is what a C-button does: C-right with the bow *draws the
bow*. `Bus.quick_slots_changed(slots)` fires on every bind.

**One item, one button.** Binding something already on another slot MOVES it —
two buttons that draw the same bow is two buttons doing one button's job.

`bind_quick` refuses anything unowned, and refuses anything outside
`QUICK_POOL`. A button that draws a bow you have never found is a button lying
about your inventory.

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

### The way out — the Homeward Charm

```gdscript
# scripts/items/homeward_charm.gd, built by hero.gd as `hero.charm`
Bus.homeward_used.emit()          # the ITEMS screen, after closing the menu
hero.charm.begin() -> bool        # or drive it directly, as directors do
hero.charm.active() -> bool       # rooted, mid-channel
hero.charm.cancel()               # a blow landed; emits Bus.homeward_broken
```

There is no extraction node and no exit room. `ExtractNode` is **deleted** —
do not add a second way out (METAGAME §5).

- **The charm channels, it does not teleport.** `CHANNEL_TIME` seconds rooted in
  the world, cancelled by a blow that *lands*. A blocked blow does not cancel it.
- **The hero is rooted by the same mechanism a shop uses**, so he still falls and
  still slides to a halt — `hero.gd` folds `charm.active()` into the same
  `locked` flag as `Prompt.blocked`, and `hero_combat.gd` locks the item buttons
  but deliberately **not** the shield.
- **It is not bindable.** It is not in `QUICK_POOL` and must not be added to it.
- **Only `Run` decides whether leaving is possible.** The charm asks
  `Run.can_extract()` before it starts and `Run.extract()` when it finishes; the
  fee moves with the bag, so both checks are load-bearing.
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

### Hookshot — chain and anchors, ready for P7

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

### Music — picks itself, and nobody calls it

`Music` decides what is playing from the state the game is already in. **Do not
call it to start a track.** It reads:

- the current scene's path — `town` → `CALM`, anything else → `DELVE`;
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
`enemy_died`, `player_died`, `target_acquired`, `run_started`, `run_ended`,
`bag_full`, `extract_refused` — so those need no emit at all. Add a row to
`Sfx.CUES` rather than a player to a prop.

Two traps the table has already hit:

- **Some sounds only exist as `_N` variants.** `coin_trade` is on disk as
  `coin_trade_1..3` and `doom_stinger` as `doom_stinger_1` alone — the bare name
  resolves to nothing. List it in `Sfx.VARIANTS` with its count, including a
  count of 1.
- **A missing file is silent, not loud.** `Sfx._load` warns and returns null, and
  the game plays on. `tools/directors/sfx_cues.gd` fires every cue and asserts a
  voice actually started; run it when you add one.

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
```

`Saves.load_slot()` deliberately does **not** change scenes — it hands back
where the hero belongs and lets the caller transition however it wants.
Whoever owns room transitions should set `Saves.current_room` as rooms change.

Audio buses `Master / Music / SFX / UI` exist in `default_bus_layout.tres`.
Anything that plays a sound must route to `SFX`, `Music`, or `UI` — never
straight to `Master`, or the volume sliders will not affect it.

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
- **`/` is reserved** as the library/animation separator. Namespace clips with `_`.
- **An imported FBX ships a stub `""` AnimationLibrary.** Evict it before adding
  a merged one, or you get "Can't add animation library twice with name: ''".
- **Comments in `project.godot` must start with `;`.** A `#` comment is a parse
  error that silently **eats the assignment directly after it**. This cost an
  afternoon: `ui_accept` fell back to the engine default while `ui_cancel`, one
  line further down past the damage, applied fine — an asymmetry that reads as an
  engine quirk and invites a completely wrong theory.
- **Never let a test write the real `user://settings.cfg`.** Pass
  `--settings=user://scratch.cfg` after the `--` separator. A menu test once left
  `attack` bound to `N` and the game shipped with a dead sword button.
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
