# Working in this repo

Godot 4.7, Forward+, GDScript with static types, macOS/Metal. Read this before
you touch anything. It is short because it is only the things that have actually
gone wrong here.

---

## 0. The rule that matters most: check before you build

**Two sessions once built the entire metagame in parallel** — two `Main` nodes,
two HUDs, two dungeons, two item databases, two garrison scenes — because
neither looked at what was already on `main`. Resolving it cost more than either
build.

Before you write a system, in this order:

1. `git log --oneline -20` on `main`. Someone may have just built it.
2. **Look at the board** (§1.1). If a card exists, claim it instead of starting a
   rival copy. If one doesn't, make one.
3. `ls scripts/` and grep for the class name. This repo is not big; look.

If the thing already exists and yours would be better, **replace it and delete
the loser**. Do not land both and wire a switch. One of each system, always.

---

## 1. Cards and worktrees

### 1.1 The board is on GitHub

**[The Lower Worlds: Awakening](https://github.com/orgs/Metatransformer/projects/8) —
org `Metatransformer`, project `8`.** That board is the record of what is being
built and by whom. A session's own `TaskList` is scratch: it dies with the
session, and §0's duplicated metagame happened precisely because one agent could
not see what another was doing. **Put it where the next session will look.**

There is no GitHub MCP here. `gh` is authenticated with the `project` scope and
that is all this needs:

```bash
gh project item-list 8 --owner Metatransformer --format json        # what exists
gh issue create --repo Metatransformer/awakening --title "…" --body "…"
gh project item-add 8 --owner Metatransformer --url <issue-url>
```

- **Cards are real issues in `Metatransformer/awakening`**, not draft items, so a
  commit can close one and the history joins up.
- **Status** is a single-select: `Backlog` → `Ready` → `In progress` →
  `In review` → `Done`. Move yours to **In progress** when you start and to
  **Done** only when §2's bar is met — not when the code is written. Setting it
  needs the ids, and `gh project field-list 8 --owner Metatransformer --format json`
  prints them.
- **`Ready` means specified enough to start cold.** If you have to re-derive the
  design before you can begin, the card belongs in `Backlog` with a pointer to
  the doc that owns it.
- **Write the card so a session with no context can act on it**: the file paths,
  the constraint, and what "done" looks like on screen. A card that only makes
  sense to the person who wrote it is a note, not a card.
- **Record finished design work as a closed card too.** Three documents landing
  on `main` is invisible unless something says so, and invisible work is the one
  failure this repo has actually paid for.

### 1.2 The rest

- **One card per unit of work.** Open it before starting, move it to
  `In progress` when you start, `Done` only when it is verified — not when the
  code is written.
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
tools/quiet.sh --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png --warmup=60
```

- `tools/directors/mvp_loop.gd` — the whole loop, end to end. Prints
  `MVP FAIL …` on any beat that did not happen.
- `tools/directors/monster_lookdev.gd` — the enemy roster, rendered.
- Write a new director for anything you add that has pixels.

**`tools/quiet.sh`, not bare `godot`. This machine has an owner sitting at it.**
A director run opens a real macOS window that comes up in front of whatever they
are typing into and takes the keystrokes with it, and four or five agents run
directors here at once — it made the machine unusable for anything else. The
wrapper delivers `display/window/size/no_focus`, which is read once at window
creation and so cannot be set from GDScript afterwards. The window still appears
(it has to — see the trap table), but it opens in a corner and never takes the
keyboard. Measured: 0 focused frames out of 240, with the director passing
unchanged.

It also delivers `--audio-driver Dummy`, so **a harness run is silent** — no
audio device is ever opened. `shoot.gd` separately mutes the MASTER bus, but
that only covers runs that go through `shoot.gd`: a scene harness launched as
`godot --path . res://tools/scenes/x.tscn` boots the autoloads and plays the
score out of the owner's speakers, and six overlapping soundtracks out of
background jobs is a machine shouting at whoever launched it. `AudioServer` is
unaffected — buses, volumes and `playing` all behave, and `music_beats`,
`sfx_moves` and `critic_menu` still assert exactly what they did. Pass `--sound`
to opt back in.

A bare `godot -s tools/shoot.gd` still runs and still passes; it just takes the
owner's keyboard while it does. `shoot.gd` now prints
`shoot: WARNING - launched as bare godot` when the `no_focus` flag is missing —
it cannot fix it from there (the flag is read before any script exists), so that
line is the whole remedy. If you see it in your own output, you typed `godot`.

**Never pass `--headless` to a screenshot run.** There is no rendering device
and every frame comes out empty — silently.

**Do not leave runs behind you.** A director that hangs holds a window, a GPU and
a share of everyone else's frame rate until someone kills it — there was a
nine-minute zombie on this Mac while the paragraph above was being written. Put
`timeout 400` in front of the command, and check `pgrep -f shoot.gd` before you
start a burst.

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
| A texture added *after* the model that references it | A flat untextured **white** prop, and `--import` says DONE having fixed nothing | The glTF importer substitutes a default white `StandardMaterial3D` when it cannot resolve a `uri`, and a scene `.import`'s `[deps]` lists only the source file — so landing the missing texture never invalidates the cached `.scn`. Delete the cached scene and import again: `p=$(grep '^path=' <model>.import \| cut -d'"' -f2); rm -f "${p#res://}" && godot --path . --import --headless`. `tools/directors/art_audit.gd` is what finds it. |
| A gamepad plugged into this Mac | Directors fail intermittently, in beats that look like game races | Sticks resting outside the deadzone report `move_*` / `cam_*` held. The hero walks off mid-beat. `shoot.gd` strips joypad bindings now — if you write a harness that does not go through it, do the same. |
| Minimising the harness window | Runs hang: zero PNGs, no `SHOT_OK`, timeout | The obvious way to keep the window out of the owner's way, and it silently kills capture. A minimised window still reports its size and still hands back correct pixels when a bare script asks, so it tests fine — then a real director produces nothing. `p2_walk_run_stop`: visible 23 s / 15 PNGs, minimised 75 s timeout / 0 PNGs. Use `no_focus` (`tools/quiet.sh`) and leave the window visible. |
| `Performance.TIME_PROCESS` read as "script time" | A script cost *larger than the whole frame* — and, read the other way, a tuning pass sent after `_process` when the GPU was the wall | It is the entire main-loop idle step, and `RenderingServer.draw()` is called from inside it, so it carries the draw submission and the wait on present too. Measured here: `med=17.17 ms` on frames whose wall clock was `16.25 ms`. It cannot separate GPU-bound from script-bound — that is exactly what it looks like it does. `TIME_PHYSICS_PROCESS` *is* honest. `perf_probe.gd` prints it as `idle_step_ms` for this reason. |
| `--import` rewrites `project.godot` | A clean diff you didn't make | It re-serialises the file: **every `;` comment is deleted**, and it drops settings it considers defaults — `window/size/resizable`, and **`audio/buses/default_bus_layout`, which silently unhooks the Music / SFX / UI buses and every volume slider with them**. The autoload load-order notes and the `#`-is-a-parse-error warning all vanish too. `git diff project.godot` after every `--import` — it is never a no-op — and restore from `git show HEAD:project.godot` + re-apply your line. |

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
| `docs/PUZZLES.md` | The puzzle verb ladder, the atoms and combinators, **the grammar** (§10 — how a floor gets harder), the three puzzle shapes, the four minibosses, and where Echoes come from. `docs/GDD.md` §5.3 is the summary; this is the design of record. |
| `docs/BESTIARY.md` | **Encounter design.** What a body asks the player and which item answers it: the enemy behaviours, the miniboss rules, and one fight shape per boss. Not stats — those are `Enemy.DEFS` and `BossDb`. |
| `docs/BOSSES.md` | **The four fights, worked.** The beat that carries each shape, its timings against the hero's clock, where the parry and the roll land inside it, what the arena does at the threshold, and the rows to paste. `docs/BESTIARY.md` §5 says *what* each boss is; this says *how*. Not stats — `BossDb` owns those. |
| `docs/ITEMS.md` | **Items.** For each one: which body or which lock it answers, where it enters the run, and what owning it changes. The six usable items, the twelve relics, the twelve Echoes, the twenty ladders, the stock. Not numbers — those are the DBs under `scripts/items/`. Its §8 is the standing list of places the docs and those DBs disagree. |
| `docs/OOT_CATALOGUE.md` | The source material. Ocarina dungeon by dungeon, as mechanics, with the twelve patterns worth stealing. **Owns nothing** — it is what `PUZZLES.md`, `BESTIARY.md`, `BOSSES.md` and `ITEMS.md` cite. Named rather than counted: this row used to say "the two docs above" and two later insertions made it false without touching it. |
| `docs/CONTRACT.md` | Interfaces, units, autoloads, collision layers, file ownership. |
| `docs/STYLEGUIDE.md` | Palette, type, the PSX treatment, the anti-slop list. |

Update the doc in the same commit as the code. A design doc describing something
the code no longer does is worse than no doc — the next agent will believe it.
