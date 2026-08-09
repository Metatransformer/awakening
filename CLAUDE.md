# Working in this repo

Godot 4.7, Forward+, GDScript with static types, macOS/Metal. Read this before
you touch anything. It is short because it is only the things that have actually
gone wrong here.

---

## 0. The rule that matters most: check before you build

**Two sessions once built the entire metagame in parallel** — two `Main` nodes,
two HUDs, two dungeons, two item databases, two town scenes — because neither
looked at what was already on `main`. Resolving it cost more than either build.

Before you write a system, in this order:

1. `git log --oneline -20` on `main`. Someone may have just built it.
2. `TaskList`. If a card exists, claim it (`TaskUpdate` with `owner`) instead of
   starting a rival copy. If one doesn't, make one.
3. `ls scripts/` and grep for the class name. This repo is not big; look.

If the thing already exists and yours would be better, **replace it and delete
the loser**. Do not land both and wire a switch. One of each system, always.

---

## 1. Cards and worktrees

- **One card per unit of work.** `TaskCreate` before starting, `in_progress`
  when you start, `completed` only when it is verified — not when the code is
  written.
- **One worktree per card** when work is parallel. Worktrees live in
  `.claude/worktrees/`. Never `git checkout` a branch that another worktree has.
- **Never `git checkout HEAD -- <file>` or `git restore` a shared file** to undo
  someone. That clobbers another agent's uncommitted work. Revert surgically —
  a targeted edit, or `git apply -R` on a filtered patch.
- **Commit as soon as the tree is consistent.** A merge resolution sat
  uncommitted here and was wiped by a stray `git reset --hard`. Hours, gone.
  Commit, then continue.
- **Sweeping up another agent's uncommitted work is fine. Commit anyway.** The
  primary worktree is shared and usually has two or three streams half-written
  in it, often in the same file, sometimes in a binary like
  `assets/animations/hero_anims.res` that no hunk-level split can separate.
  Do not stall on that. A commit does not damage anyone's work — the files stay
  exactly as they are on disk, and an untidy commit is recoverable in a way that
  §0's duplicated-metagame outcome is not. Stage what you can attribute, say in
  the message what else came along for the ride, and land it. The thing that has
  actually cost this repo time is work that stayed invisible, never a shared
  commit.

  This is not a licence to *destroy*: the `git checkout HEAD -- <file>` rule
  above still stands, because that one removes work rather than recording it.
- **Land it on `main` when the card is done. Do not wait to be asked.** A
  verified branch sitting in a worktree is not finished work — it is work the
  next session cannot see, and this repo has already paid for that once: two
  agents built the entire metagame twice because neither could see the other's
  branch (§0). Merging is what makes §0's `git log --oneline -20` tell the
  truth.

  `main` is checked out in the primary worktree, so merge from **there** —
  never `git checkout main` inside a worktree:

  ```bash
  cd /Users/nickbryant/zeldalike && git merge <your-branch>
  ```

  Plain `git merge`. Not `--ff-only`, not "I'll ask first", not a summary of
  what you *would* have merged. If `main` moved under you, that is the normal
  case in this repo, not an incident.

- **Conflicts are yours to resolve. They are not a reason to stop.** You have
  both sides in front of you and you know what your half was for; nobody is
  better placed to merge it than you are, and a session that hands a conflict
  back has turned twenty minutes of reading into a blocked card. Read both
  sides, keep both intents, delete neither silently, and say in the merge
  message what you reconciled and why. If a conflict is genuinely a design
  collision — two answers to one question, §0 — pick the better one, delete the
  loser, and say so. That is a decision you are allowed to make.

  The only thing a conflict changes is the proof: a resolved merge is new code
  that has never run. Re-run the directors on the *merged* tree. A clean rebase
  is not a passing one.

- **Do not leave verified work sitting for permission.** "Should I merge?" is
  not a question this repo wants asked — the answer is always yes, and asking
  it costs a round-trip during which another session starts building your
  feature again. Merge it, then say what you merged. If it turns out wrong,
  `git revert` is one command; the duplicated metagame in §0 took days.

  Land only what you have actually verified — the bar in §2 is the bar for
  merging, not just for saying you are done. That is the *only* gate. "It might
  conflict", "someone else has files open", "main moved" are not gates.

---

## 2. Proving your work — you do not get to say it looks good

**Look at the frames.** Testing is not the default proof here; the default proof
is exercising the thing and reporting what you saw. Every real bug in this
project's history was found by looking, and several were *hidden* by logs that
said everything passed.

```bash
godot --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/town.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

- `tools/directors/mvp_loop.gd` — the whole loop, end to end. Prints
  `MVP FAIL …` on any beat that did not happen.
- `tools/directors/monster_lookdev.gd` — the enemy roster, rendered.
- Write a new director for anything you add that has pixels.

**Never pass `--headless` to a screenshot run.** There is no rendering device
and every frame comes out empty — silently.

Before you call something done: clean `godot --path . --import`, clean boot, the
relevant director with no failures, and *your own eyes on the output*.

---

## 3. Godot traps that have each cost real time here

| Trap | What you see | The truth |
|---|---|---|
| `Environment.background_mode = 0` | `background_color` ignored | `0` is `BG_CLEAR_COLOR`. You want `1` (`BG_COLOR`). |
| No `WorldEnvironment` in the scene | Default grey through every doorway | An authored `.tres` that nothing instances does nothing. |
| `Input.action_press()` | Held actions never fire | It sets action state but dispatches **no** `InputEvent`. `_unhandled_input` never runs. Poll instead. |
| `await get_tree().process_frame` then `add_child` | "Parent node is busy setting up children" | You resumed *inside* the tree's process loop, where `root` is locked. Use `add_child.call_deferred()` in a retry loop. |
| Untyped `const` Dictionary indexing | "Cannot infer the type of X" | Indexing returns `Variant`. Annotate: `var next: Vector2i = D[k]`. |
| A `const` Dictionary holding a `class_name` or another class's enum | "Assigned value for constant isn't a constant expression" | Those are not const expressions. `static var` — still built once, still shared. |
| A bare static call inside a base class | The subclass's override never runs, silently | `foo()` written inside `Base` binds to `Base.foo` at parse time; there is no virtual dispatch for statics. Call it through the handle: `db.foo()`. The smith's counter said `HOLD ENT TO CRAFT` for a build because of this. |
| `--check-only --script` | "Identifier not found: Bus" | Autoloads aren't registered for that mode. False positive. |
| Emissive / alpha / `BLEND_MODE_ADD` over near-black | Opaque slab at every opacity | Alpha does not attenuate ADD. Change the *shape*, not the material. |
| Cold `.godot/imported/` | Missing `.ctex`, text-fallback HUD icons | Run `--import` before judging a frame. |
| A gamepad plugged into this Mac | Directors fail intermittently, in beats that look like game races | Sticks resting outside the deadzone report `move_*` / `cam_*` held. The hero walks off mid-beat. `shoot.gd` strips joypad bindings now — if you write a harness that does not go through it, do the same. |
| `--import` rewrites `project.godot` | A clean diff you didn't make | It re-serialises the file: **every `;` comment is deleted**, and it dropped `window/size/resizable`. The autoload load-order notes and the `#`-is-a-parse-error warning all vanish. `git diff project.godot` after every `--import`, and restore from `git show HEAD:project.godot` + re-apply your line. |

---

## 4. Facing is measured, not derived — see `docs/CONTRACT.md` §2.5

This has bitten the project **three times**: the hero rig, the weapon socket,
and the whole monster roster (every model walked at the player backwards under a
code comment asserting they faced the right way).

- Heading yaw means `h = (sin y, 0, cos y)`. A Node3D's forward is `-basis.z`,
  so `rotation.y = heading + PI` points the body at the target.
- Imported art usually faces `+Z` anyway, which needs a **separate 180° on the
  model node** — `hero.gd`'s `model_yaw_offset`, `enemy.gd`'s `_model.rotation.y`.
- Fix art-space quirks **on the model**. `-basis.z is forward` is the contract
  everything else reads facing through; do not break it to save a rotation.
- Never reason this out from rest-pose bone tracks. **Render it and look.**

---

## 5. Before implementing any Godot system

Invoke the matching `godot-prompter:*` skill first — `player-controller`,
`state-machine`, `inventory-system`, `ai-navigation`, `hud-system`,
`camera-system`, and so on. This applies to subagents writing Godot code too.
"I already know how CharacterBody3D works" is not an exemption; knowing the
class is not knowing the pattern.

---

## 6. House style

- Static types everywhere. `snake_case` files, `PascalCase` classes.
- Health is in **quarter-hearts** (`K.QUARTER` = 1, `K.HEART` = 4).
- Metric: 1 unit = 1 m. Hero is 1.65 m. Constants live in `scripts/core/consts.gd` (`K`).
- Values tagged `[oot]` in `K` are **measured from reference footage**. They are
  not typos and they are not yours to "correct".
- Comments explain *why*, and especially why the obvious thing is wrong. Match
  the density already in the file — this codebase comments its traps on purpose.
- `Flow` is the only thing that calls `change_scene_to_file`. Do not add a second.

---

## 7. The docs, and which one owns what

| File | Owns |
|---|---|
| `docs/GDD.md` | What the game is. The north star; everything else serves it. |
| `docs/SCOPE.md` | **How much of it there is.** The frozen manifest, the no-list, the build order. It is the doc that gets to say no — check it before you build anything the GDD merely permits. |
| `docs/METAGAME.md` | The economy: loot, bag, gold, extraction, the shops. |
| `docs/CONTRACT.md` | Interfaces, units, autoloads, collision layers, file ownership. |
| `docs/STYLEGUIDE.md` | Palette, type, the PSX treatment, the anti-slop list. |

Update the doc in the same commit as the code. A design doc describing something
the code no longer does is worse than no doc — the next agent will believe it.
