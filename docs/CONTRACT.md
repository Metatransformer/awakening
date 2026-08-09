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
| `attack` | **LMB** | **X / Square** (pad2) | light attack (**hold** = charge, **+guard** = dash) |
| `use_item` | **F** | **RT / R2** (axis5+) | use the item the D-pad drew |
| `shield` | **RMB** | **LT / L2** (axis4+) | guard — **held**, and it targets, and it recentres |
| `context` | **Shift** | **B / Circle** (pad1) | roll / backstep / sidehop — **hold** = run |
| `jump` | **Space** | **Y / Triangle** (pad3) | jump |
| `z_target` | **Q**, MMB | — (LT does it) | lock-on toggle / camera recentre |
| `interact` | E | **A / Cross** (pad0) | context — talk/open, **+guard** = jump attack, else stow item |
| `item_left` / `item_up` / `item_right` | 1 / 2 / 3 | dpad L / U / R | armaments — §4.1 |
| `first_person` | R | **R3** (pad8) | look out of his own eyes — he roots |
| `pause` / `inventory` / `map` | Esc / **I** / Tab | Start (pad6) / **Select** (pad4) / L3 (pad7) | menu / pouch / map |
| `dbg_reload` | F5 | — | — |

**The triggers are a pair and that is the layout's spine.** This is BOTW's
arrangement, and it is right: the left index finger holds a STANCE and the right
index finger fires what that stance is aimed at. LT raises the guard and takes
the lock; RT uses whatever the D-pad drew. Aiming a bow with a shoulder and
loosing it with a thumb makes you let go of the stick that was aiming.

The face buttons are the swings and the verbs: X swings, B rolls, A is context.
The right stick swings the lens and **clicking it (R3) drops you into his eyes**
— BOTW's arrangement again, and the thumb is already there doing the same job;
everything else the camera does is under the left index finger.

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

The sword is on **X**, permanently, and it is the *only* thing on it. That is
OOT's arrangement — the sword lives on one button forever and the items live on
the C-pad — and it is what makes a drawn item safe to leave drawn. Drawing here
is **sticky**: a D-pad press puts the hookshot in his hand and it stays there,
so you can walk around aiming it, which OOT's momentary C-buttons never allow.
A sticky mode needs an unconditional way out, and `attack` is it: pressing it
with an item drawn stows the item **and swings on the same press**
(`HeroCombat._begin`, `Game.stow_item`). Not the next press — the same one.

`use_item` took the A/Cross the sword vacated. It is the "do the thing you are
holding" button: it fires the drawn bow or hookshot, and with the sword out and
something locked it is the lunge. With the sword out and nothing locked it is
**silent**, deliberately — that is OOT's A, where the jump attack exists only
under Z.

`interact` sits on Y/Triangle because A was spoken for twice over. It cannot
share A with `use_item`: `interact` already shares A with `ui_accept`, which is
safe only because `trade_screen`'s accept edge starts DISARMED, and nothing
equivalent guards the world — `hero_combat` polls its buttons every physics
frame, so one press at a chest would open it and loose an arrow through it. The
roll keeps B/Circle, where the source material has it.

**The dodge button is a tap AND a hold.** Tap `context` and the hero rolls,
exactly as before. Hold it past `Hero.sprint_hold_time` (0.18 s) and he **runs**
— `K.SPRINT_SPEED`, 6.07 m/s against the 4.37 run cap — until the button or the
stamina bar gives out. That is Elden Ring's arrangement and BOTW's B, and the
consequence is theirs too: a held button rolls and *then* runs, because the roll
still fires on the **press**. Waiting to see whether a press was a tap would put
0.18 s of latency on the most reaction-critical button in the game, which is the
same argument the charge makes above for the sword coming out on the press.

The run is deliberately **slower than a roll** (6.55). The roll is the fastest
the hero ever travels and it costs a third of the bar for half a second; a
sprint that outran it would make the dodge a worse way to cover ground than the
button it shares. They come out of one pocket on purpose — there is no separate
sprint meter, so a player who runs everywhere arrives with nothing to dodge on.

It is withheld in three stances, each for its own reason: **locked** (the stick
is a circle-strafe there, and "run" has no direction to mean), **guarding** and
**aiming** (a run would have to drop a stance the player is holding a button
for). Holding the button still rolls in all three; only the run is refused.

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

**There is no heavy-attack button.** The heavy is the charge: tap X for the
light chain, *hold* X to wind up, release to **spin**. The light swing comes out
on the **press**, never on the release — a button that waits to see whether you
meant a tap puts `charge_time` (0.42 s) of latency on every ordinary swing. So
the wind-up costs the recovery you were spending anyway, and a mashed chain
never charges anything. `combat.charged` is public and goes up at `charge_time`.

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

**The dash attack is `attack` pressed with the guard already up**, and it is the
one modified swing on the button (`HeroCombat._tick_attack_button`: `if blocking
and equipped == &""`). It is a committed forward lunge — `Hero.request_dash`
drives him along `_forward()` at 8.0 m/s for `dash_drive_time` (0.20 s) under
the `SwingDash` one-shot, does 3 quarter-hearts, and resets the light chain so
it can never be step 2 of a combo. It reads as a *decision*: the guard drops,
he closes the gap, and the recovery is long enough to punish. Note it takes the
press, so it pre-empts the charge — you cannot wind up a heavy from behind the
shield, which is deliberate, because a shielded charge is a stance with no
answer to it.

**The air slam is `attack` pressed off the floor** — the second modified swing
on the button, and the same gate reads it (`HeroCombat._tick_attack_button`:
`if not _hero.is_on_floor() and equipped == &""`). It takes the press before
anything else can, and it is never buffered: a slam that fires because you
pressed attack a moment before you left the ground is a slam you did not ask
for.

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

**Not yet bound, because the ability does not exist:** skill. Do not register an
empty action for it; bind it in the same change that builds it. RT/R2 was
pencilled in for the skill and `use_item` took it instead — the triggers being a
pair is worth more than reserving one for an ability nobody has designed.

`first_person` was the standing counter-example and it is now closed: it sat
bound to R, rebindable, read by nothing, with a `Bus.first_person_changed` that
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

# on HealthComponent:
func apply_hit(hit: Hit) -> void
signal damaged(hit: Hit)
signal died
```

Anything that deals damage puts a `DamageArea` in group `hitbox` and opens its
window. **Do not invent a second damage path.**

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

**`Game.STARTER_KIT` is `[test]` scaffolding.** The bow and the hookshot are
granted in `Game._ready()`, with arrows, so both are reachable from a cold boot
without playing a run to the chest that holds them. `grant()`'s own auto-bind is
what puts them on dpad ← and dpad ↑; nothing here binds a button by hand. It is
in `_ready()` and deliberately **not** in `reset()` — `reset()` means "a fresh
save owns nothing", several directors assert exactly that, and a kit that
reappeared on every reset would make the assertion untestable rather than true.
Delete the two constants to ship.

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
- **Components bank on extraction, not on pickup.** `Run.bank_components()` is
  called by `extract()` after the fee, and deliberately **not** by `die()`.
- New on `Bus`: `components_changed(stock)`, `components_banked(moved)`,
  `gear_forged(track, level)`.
- New on the pause menu: `PauseMenu.Screen.POUCH`, `Root/Screens/PouchScreen`
  (`scripts/ui/menu/pouch_panel.gd`). It is read-only — the bag has no verbs.

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
  `locked` flag as `Prompt.blocked`, and `hero_combat.gd` locks the item buttons
  but deliberately **not** the shield.
- **It is not bindable.** It is not in `QUICK_POOL` and must not be added to it.
- **Only `Run` decides whether leaving is possible.** The rope asks
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
| spin | `ax_melee_attack_360_low` | attack **held** past `charge_time`, on release | 5, all round |
| lunge | `ss_attack_01` | use_item, **locked on** | 4 |
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

**The heavy is a hold, not a button** (§4). The press that starts the hold still
throws its light swing; the release throws the heavy, buffered like any other
intent if the light is still running. A heavy ENDS the chain rather than
counting as a step in it.

**The lunge is what Z-targeting buys.** It refuses without a lock, on purpose;
a version that also fired unlocked would just be a better standing attack. It
has no stick gate and no chain gate — both existed to tell a leap apart from an
ordinary swing pressed with the same thumb, and on a dedicated button a hidden
rule is just a button that intermittently does nothing.

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
BUTTONS (one reader, §4) and calls `fire()` on a `use_item` press when the right
hand is not holding the sword.

```gdscript
hero.ranged.fire(&"bow" | &"hookshot") -> bool   # false = the press did nothing
hero.ranged.busy() -> bool                        # a shot is mid-flight
hero.ranged.aiming -> bool                        # a sighted item is out
hero.ranged.aim_item() -> StringName              # &"bow" &"hookshot" or &""
```

**A bow shot is two clips and one clock.** `K.BOW_DRAW[level]` seconds of charge
(`bow_draw_arrow`), then `HeroRanged.BOW_LOOSE` seconds of loose
(`bow_aim_recoil`), and the arrow leaves at the seam. `HeroRanged` owns the
clock; the hero owns the body and is committed for both halves:

```gdscript
hero.request_bow(draw_time, loose_time, aim) -> bool  # commits, fires the CHARGE
hero.bow_loose(loose_time)                            # the seam — not a request
hero.request_hookshot(duration, aim) -> bool          # one phase, not two
```

Only `HeroRanged` calls these, and it fires `bow_loose` off the same frame it
spawns the arrow — the string leaving his fingers and the arrow leaving the bow
are one event, and two things counting to it separately is how they come apart.
Proof is `tools/directors/bow_charge_release.gd`, which photographs the shot
across both clips: a boolean saying two nodes played is not a drawn bow.

**Aim mode has exactly one author.** Bringing out the bow or the hookshot drops
the camera to the shoulder, draws a crosshair, and changes how the body moves.
Three systems, one decision — and if the camera, the HUD and the hero each
decided for themselves what counts as aiming they would disagree the first frame
one of them was wrong. `HeroRanged` is the one place that knows what is in his
hands, so it decides and says so:

```gdscript
Bus.aim_changed(active: bool)          # emitted by HeroRanged, nobody else

camera.set_aiming(on)                  # connected to it in GameCamera._ready
camera.aiming() -> bool
hero.aiming() -> bool                  # both read through HeroRanged
hero.aim_item() -> StringName          # which stance the body holds

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

While aiming the hero **strafes**: he faces where the camera faces, at ~1.8×
turn rate, and moves independently of that facing. This is the same shape as
lock-on and sits in the same place in `_tick_ground`, right after it.

**A raised shield takes the same tick** (`Hero._tick_camera_facing`, which is
`if aiming() or blocking`). That is OOT's Z-Parallel, and it is not a cosmetic
share: with the facing pinned, a neutral stick and `context` is a **backstep**
— `_try_start_roll` sends him along `-_forward()` with no stick gate, exactly as
it does under a lock, because this is a press you make from behind a raised
shield rather than one you fall into out of a run.

**The dodge has four directions, and which one you get is measured off the
facing, not off the stick.** `Hero._dodge_for` projects the committed
`_roll_dir` onto the facing and onto hero-right — `(-f.z, 0, f.x)`, and getting
that sign backwards is hero-*left*, which plays each sidehop as the other one
while the travel stays correct, so the frames are the only thing that catches
it. Whichever axis dominates picks the clip and the speed:

| `Dodge` | Clip | Speed | Duration |
|---|---|---|---|
| `FORWARD` | `ex_roll_to_run` | `K.ROLL_SPEED` 6.55 | `roll_time` 0.62 |
| `BACK` | `ex_backflip` | `K.BACKFLIP_SPEED` 4.37 | `backflip_time` 0.60 |
| `LEFT` / `RIGHT` | `bow_dodge_left` / `_right` | `K.SIDEHOP_SPEED` 6.19 | `hop_time` 0.44 |

Four things about that table. The speeds are the `[oot]` measured constants,
which had sat in `K` unused since they were taken — the sidehop and the backflip
were always going to be their own moves. The sidehops come from the **longbow**
set, not the sword-and-shield set: the Pro Sword and Shield pack has 52 clips
and not one roll, dodge, evade or dive among them, so anything looking there for
a backwards roll will find nothing and should stop looking. Each direction is
its **own** `AnimationNodeOneShot` + `AnimationNodeTimeScale` pair
(`Hero._DODGE_NODES`) — reassigning `animation` on one live
`AnimationNodeAnimation` restarts the mixer cache and eats the wind-up frames.

And `BACK` is a **backflip**, which is the one row the longbow set could not
fill: `bow_dodge_back` is a backward shuffle-walk that never leaves the ground,
and a retreat is not an evade. It also owns the only duration that is neither
the roll's nor the hop's, because a flip has to launch, invert and land, and
0.44 s of that is a blur — which makes the backflip the widest i-frame window
short of a roll *and* the least ground covered per second. That is the trade
between the three: safest, fastest, furthest, pick one.

Its source clip has 0.72 s of dead settle after the landing, cut in
`build_anim_lib`'s `TRIM` table rather than at the call site. That placement is
load-bearing: `Hero._fire_dodge` scales `clip_length / move_duration` so the
one-shot ends exactly when the dodge does, so **a clip's length has to mean the
move's length**. Trim the factor instead of the clip and the hero stands in the
export's settle pose for 0.4 s after the controller has already handed him back
to locomotion.

Because the i-frame window is literally `state == MoveState.ROLL` in
`take_hit`, the duration column *is* the invulnerability column: the sidehops
and the backstep are shorter dodges than the roll, not just faster ones.

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
Saves.autosave()        # Flow calls this on EVERY transition; false = declined
Saves.autosaved         # signal(slot) -- slot is -1 when it declined
```

The save file is at **`VERSION = 2`**: it carries `bag_slots`, `upgrades` and
`components` on top of v1. On load, both dictionaries are rebuilt with
`StringName` keys — JSON hands back `String` keys, and a `String` key makes
`forge_level(&"edge")` miss silently and every forged rung vanish.

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

- **A recorded scene is never a dungeon.** `_save_scene()` returns `Flow.TOWN`
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
  as "every target is exactly 1 m away" — the leap stood still and the range band
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
- **Never let a test write the real `user://settings.cfg`.** Pass
  `--settings=user://scratch.cfg` after the `--` separator. A menu test once left
  `attack` bound to `N` and the game shipped with a dead sword button.
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
