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

### 0.1 Keep tiny fixes tiny

When the requested result is an obvious local edit — a label, constant, typo,
or similarly bounded one-file change — make it directly. Do not create a card,
worktree, worker package, plan, documentation sweep, or repository-wide audit.
Do not reinterpret a visual or copy request as a gameplay-system change.

Verification must be proportional: use the smallest relevant check or capture
that proves the edit. Do not run unrelated directors. If the change genuinely
needs broader semantics or multiple owners, say why before expanding its scope.

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

**Start every player-facing aesthetic, UI, level-presentation, or gameplay-
design task with an independent critic who did not author the choice.** Give the
critic the relevant GDD, NOW, MDA and STYLEGUIDE context, the named gameplay
question, and native-resolution frames or playable behavior. Tell them to
disprove the choice against the project's ideals, not to praise it. Review the
proposal early enough to change it, then review the real frames or behavior
before acceptance; one late pass is enough only for a truly small change.

Resolve blocking contradictions or record the evidence for rejecting them in
the issue or design test. Critique and debate do not belong in canonical docs,
and an outside critic does not replace a cold human playtest. Exact local fixes
with no design discretion remain exempt under §0.1.

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

**And for a year nobody typed it — they pasted it, out of this repo.** The rule
above has been here the whole time and the owner was still losing the keyboard,
because a rule loses to a copy-paste block every time: **102 of the 142 director
headers opened with `godot --path . -s tools/shoot.gd`**, `pnpm shot` in
`package.json` ran bare `godot`, `DESIGN.md` printed a bare block, and §2 of this
file — four paragraphs below this one — *instructed* you to write new headers
that way. An agent following the documentation to the letter produced a
focus-stealing run. Every windowed header now reads `tools/quiet.sh`; the
`--headless` ones still say `godot`, because a headless run opens no window and
there is nothing to steal.

The lesson generalises past this wrapper: **if the repo tells you to do a thing
and also hands you a paste that does the opposite, the paste wins.** When you fix
a hazard here, grep for the command that causes it and fix every copy, or you
have written a rule and not a fix.

**A run with a `SCRIPT ERROR` in it is not proof, and `tools/quiet.sh` now
refuses it — exit 65.** GDScript cannot see its own error stream, so no director
can fail itself on one, and for most of this project's life nothing looked:
card #47's `boss_cistern.gd` printed `SCRIPT ERROR: Trying to cast a freed
object` out of `Hero.lock_target` and `BOSS OK -- every check passed` in the same
output, and the bug shipped. The wrapper reads the run's own log (godot's
`--log-file`, not a pipe — your terminal gets exactly the bytes it always did),
prints a count and one line per distinct site, and fails the run. `timeout` owns
124, signals own 128+n and `shoot.gd` owns 2–6, so 65 collides with nothing; a
run that already failed on its own keeps its own status.

**`SCRIPT ERROR` and nothing wider.** Every one of the 136 runs below ended with
`ERROR: N resources still in use at exit` and `WARNING: N ObjectDB instances were
leaked at exit`, so a gate on the bare `ERROR:` prefix would have failed the
entire harness on its first day. `push_error` prints `USER ERROR`, so the
harness's own deliberate refusals do not trip it. Parse and compile failures
*do* come under this prefix, which is wanted — see the note about in-flight edits
below.

**The survey, 2026-08-11, `main` at `661582b`** — every director in
`tools/directors/` run once, 136 runs, 34 minutes of GPU:

| | |
|---|---|
| Clean | **132.** Including `boss_cistern.gd`: #47's cast failure is gone, #59 fixed it, and the `Lambda capture at index 0 was freed` shape its comment warns about did not fire once in 136 runs. |
| `critic_menu_hold.gd`, `critic_menu_hold2.gd` | Both raw-pad probes could no longer reach the settings rows and dereferenced null focus. **Resolved by #70:** the obsolete probes and their exemptions were deleted. |
| `voices.gd` | The elder take lookup threw while seven conversation checks failed. **Resolved by #71:** the NPC service split restored the flow, guarded lookups now report a named failed check, and the exemption was deleted. |
| `_error_selftest.gd` | Wrong on purpose. It frees a node and casts the dangling reference from a *helper*, so the error aborts only the helper and `run` carries on to print `SELFTEST OK -- every check passed`. That is #47 exactly, and it is how you watch the gate fire. |

`tools/script_errors.allow` is now empty of exemptions. It remains a per-director,
per-message debt ledger; there is deliberately no switch that turns the gate off
wholesale. An exempt error would still be printed and counted, with its row only
withholding the exit code.

**Two things the survey found that are worse than the cast error it went looking
for.**

1. **A director's own `FAIL` reaches the exit code now.** Cards #72 and #141 are
   CLOSED: `shoot.gd._run` ends `quit(EXIT_DIRECTOR_FAIL)` (66) when `fails > 0`,
   and prints one canonical `DIRECTOR FAIL n` line so the eight spellings in the
   tree do not have to be grepped for.

   A director reaches that counter through `rig.fail()` / `rig.check()`, an int
   `return` from `run()`, or a declared `_fails` / `_fail` / `fails` the harness
   harvests. `tools/director_selftally.sh` audits those routes and exits non-zero
   if any assertion-bearing director only prints `FAIL` / `ABORT`. Measured on
   2026-08-12: **138 of 185 runnable directors are self-tallied, 47 are explicitly
   observation-only, and zero print a failure they cannot deliver to the gate.**
   The observation bucket is named on purpose: those sheets produce frames or
   tables for a human judgement and have no binary claim to weaken into green.

   So exit 66 means the director reported a failed check, and exit 0 means every
   check it makes passed. **Read the output anyway, and look at the frames** — an
   observation-only sheet can still show the wrong thing, and a bad instrument
   can still assert the wrong answer.

   When migrating an old director, replace `print("X FAIL …")` with
   `rig.fail("…")` and DELETE its own counter, because the two routes add.
2. **Five directors were dirty only because another agent was mid-edit.**
   `hookshot_grip`, `monster_feel`, `p4_combo`, `p4_lunge` and `p4_probe` caught
   `hud.gd` and `enemy.gd` in states that would not parse; all five are clean on
   a checked-out `main`. The whole HUD was failing to load and the directors
   photographed it and said OK. That is the shared worktree working normally —
   so when a `SCRIPT ERROR` is a `Parse Error` in `scripts/`, it is somebody
   else's half-saved file and not your bug. **Re-run it against a clean
   worktree before you believe it**, and do not put it in the allow file.

Twelve directors carry no invocation in their header comment, so there is no
record of which scene they want; `p1_*`, `p2_*`, `p4_probe`, `hud_vitals` and the
`critic_*` probes had to be guessed at for the sweep. If you touch one, write the
`tools/quiet.sh --path . -s tools/shoot.gd -- …` block the other 124 have.
**`tools/quiet.sh` and not `godot`** — this line used to say `godot`, and it is
how the bare command kept being reproduced into new files faster than anyone
removed it.

**Never pass `--headless` to a screenshot run.** There is no rendering device
and every frame comes out empty — silently.

**Do not leave runs behind you.** A director that hangs holds a window, a GPU and
a share of everyone else's frame rate until someone kills it — there was a
nine-minute zombie on this Mac while the paragraph above was being written. Put
`timeout 400` in front of the command, and check `pgrep -f shoot.gd` before you
start a burst.

**A director reporting a failure is a suspect, not a witness.** The rule at the
top of this section cuts both ways: an instrument can invent a bug as easily as
it can hide one, and this repo has paid for that six times now — the proof frames
were the wrong size *and* the wrong camera (#35, #40); a beat failed on an arrow
counter that **was** drawn, in a frame that turned out to be of a shield (#52);
the garrison's performance alarm was the instrument (#20); the harness rendered
nineteen megapixels and called it 720p; a HUD mask was 86% fog noise (#62); and
card #50 existed at all because a latched monitor reported a 371 ms stall that
never happened. `perf_probe.gd` alone carries five defects in its own header.

So when a director says something alarming, **the first hypothesis is the
director** — and the cheapest way to settle it is the same as everywhere else
here: make the instrument measure something whose answer you already know.
`perf_probe --stall=300` blocks the main thread for exactly 300 ms so the frame
timer has to prove it can see one; that one flag turned #50 from a hunt for a
phantom hitch into an afternoon.

**That is only half the calibration, and it is the half that cannot catch a
false positive.** `--stall=300` proves an instrument can *see* something that is
there; it would not have caught a single one of the six failures above, because
every one of them was a director reporting something that was **not**. The other
half is a null case — point it at a scene where the honest answer is *nothing*
and check that nothing is what it says. `frame_repro.gd` freezes the world with
the flames and the fog stopped and reports **0 differing pixels of 921,600**
(#62); that number is what makes its non-zero readings mean anything. Whichever
direction your director's suspected defect runs, the control runs the other way:
#64 is a suspected false positive, so a null case is what will settle it, not a
stall.

**A director you have never pointed at a known answer has never been tested**,
however many times it has passed.

Before you call something done: a clean `pnpm run import`, clean boot, the
relevant director with no failures, and *your own eyes on the output*.

**`pnpm run import` and not `godot --path . --import`**, which is what this line
used to say. Raw `--import` boots the editor — window, keyboard and all — and
then leaves you to remember the `project.godot` repair in §3 by hand.
`tools/import.mjs` passes `--headless`, puts `project.godot` back, tells you how
many comment lines the importer ate, and boots the project once to prove it
still starts.

**`pnpm run import`, with the `run`.** Bare `pnpm import` is one of pnpm's OWN
built-in commands — it generates a `pnpm-lock.yaml` from another lockfile — and
it shadows the script of the same name. There is no lockfile here, so it exits
`ERR_PNPM_LOCKFILE_NOT_FOUND` having imported nothing. That is a loud failure
today, but the moment this repo grows a lockfile it becomes a silent one: the
importer never runs and you go on to judge a frame off a cold cache.

---

## 3. Godot traps that have each cost real time here

| Trap | What you see | The truth |
|---|---|---|
| `Environment.background_mode = 0` | `background_color` ignored | `0` is `BG_CLEAR_COLOR`. You want `1` (`BG_COLOR`). |
| No `WorldEnvironment` in the scene | Default grey through every doorway | An authored `.tres` that nothing instances does nothing. |
| `Input.action_press()` | A button the game reads in `_unhandled_input` does nothing at all | It sets action state and dispatches **no** `InputEvent`, so `_unhandled_input` never runs — the z-target toggle, every pause-menu key and the first-person toggle were all unreachable from a director, and two sessions wrote down readings taken through it. `Input.parse_input_event()` on an `InputEventAction` does both; `rig.tap`/`rig.hold` do that for you now (`shoot.gd._send`). Write a harness that does not go through them and you get the old silence back. |
| A menu that polls `ui_left/right/up/down` **and** lets its cells take focus | One press steps the cursor **two** cells, so on a board with an even number of rows half of them can never be selected at all | **Two things move the cursor and only one of them is yours.** Godot's `Viewport` reads the arrows off the InputEvent for the focused Control and walks it to `focus_neighbor_*`; if `focus_entered` is wired back to "the cursor follows the cell" — which is what makes the mouse work — that is a second mover on the same press. `TradeScreen` polled *and* did this, so RIGHT ran 0,2,4,6,8,10,0 over the Lanternkeeper's twelve relics and **six of them could not be selected, so six of the twelve could not be donated**. It read as "the hold never commits" (#74) because the hold completed on whatever row the cursor had been snapped back to and was refused there. Fix: take the four arrows in `_input` and `set_input_as_handled()` — the GUI phase sits between `_input` and `_unhandled_input`, and marking it handled leaves the ACTION STATE alone, so the poll still sees the press. Confirm it is the game and not your harness by driving it with a real `InputEventKey`, not an `InputEventAction`. |
| `screen._cursor = i` from a director | The cursor is on the row you asked for, for exactly one frame | `_point_at` is the other half of a move and it is the half that calls `grab_focus`, which is **deferred** — the `focus_entered` lands a frame later and puts `_cursor` back on the row the last `_refresh` left the focus on. `mvp_loop` sold Iron Scrap instead of holding SELL EVERYTHING this way (#40); `relic_donate` held half a second on the wrong relic and nine checks went red (#74). Press the D-pad, or at minimum call `_point_at`. Seven directors still assign the field. |
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
| A proof frame from before 2026-08-11 | Smoother edges and a wider yard than the game has | `project.godot` has `window/size/mode=2` (**maximized**), so the window filled the display whatever `shoot.gd` assigned to `root.size`, and `window/stretch/mode="canvas_items"` scaled only the 2D and left the **3D at the window's true backing resolution** — `win=6880x2756` on this Mac. Every frame was therefore a 19 MP render Lanczos-downscaled to `--size`: a ~20x supersample **and**, because 2.5:1 does not fit 16:9 and Camera3D keeps its HEIGHT, ~40% more world sideways squashed into the PNG. `shoot.gd._size_the_window` resizes the real window to `--size` now, so a capture is 1:1 — but **every reference image and every eyeballed verdict older than that is a photograph of a different camera**. Re-shoot before you compare. |
| `Performance.TIME_PROCESS` read as "script time" | A script cost *larger than the whole frame* — and, read the other way, a tuning pass sent after `_process` when the GPU was the wall | It is the entire main-loop idle step, and `RenderingServer.draw()` is called from inside it, so it carries the draw submission and the wait on present too. It cannot separate GPU-bound from script-bound — that is exactly what it looks like it does. |
| `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` sampled per frame | A 371 ms stall in a 20 ms frame; `p95 == max`, reproducibly, on 240 samples | **Both are refreshed once a SECOND and hold the WORST step of that second in between** — sampling per frame gets you two or three real numbers repeated ~100 times each, so `p95 == max` is arithmetic, not an outlier. Worse, the first window carries engine boot, scene load and shader compiles: measured at `--settle=0`, `691.11 ms` of "physics" on a scene whose real step is `0.90 ms`. This row used to end "`TIME_PHYSICS_PROCESS` *is* honest" — it is honest about *what* it measures and latched exactly the same way about *when*. Card #50. **`frame_ms` is the only per-frame series and the only one a budget may be quoted from**; `perf_probe.gd --stall=300` proves it sees an injected stall to the exact sample, and prints the other two as `idle_peak_ms` / `physics_peak_ms` with every window whose second reaches back before the first sample struck out — which is **more than window zero**, because a boundary first *observed* at sample 0 was *latched* up to a second earlier. See `_peak_row`. And note card #65: an empty `ps -Ao pid,comm \| grep -i godot` does not certify a quiet Mac — a 9-draw-call scene and a 720-draw-call one both read ~13.9 ms median here with no Godot process anywhere, so run `_lookdev` as a control before quoting any median. |
| A pixel diff between two captures of a scene frozen with `Engine.time_scale = 0` | Ink where nothing was drawn — a beat failing at 93 px on a door with no caption anywhere on it | **The freeze stops the game clock, and two things here do not run on it.** `KitTorch` swung its light off `Time.get_ticks_msec()` until card #45 (it accumulates `delta` now), and **Godot's volumetric fog is temporally reprojected with a per-frame jitter that never converges** — so a stopped room is never twice the same. Measured by `tools/directors/frame_repro.gd` on floor 1, 43 sconces: flames live, **654k of 921k px move and 111k pass the 0.02 the directors call ink**; flames held, the fog alone still moves 67k px. At native that fog jitter is a delta of **1/255** and nothing sees it — but `ScreenPresent`'s legacy internal buffer quantizes to RGB555, whose step is 8/255, so with `internal_render` enabled the same sub-LSB wobble crosses a step and **2.6k px clear the ink threshold**. Held still and un-reprojected, two frames are **bit-identical: 0 px**. `rig.still_the_frame()` does both; call it before any pair. The dither is NOT a suspect — it is fixed per output pixel and provably deterministic. **Read the quantizer as the general hazard and not as a fog one:** the legacy buffer's step is 8/255, so *any* temporal wobble smaller than that — the next TAA-ish, accumulating or reprojected thing anyone turns on — is invisible at native and is ink under `internal_render`. The fog is the first one this bit, not the last. **It is a harness problem and NOT a game one, and that was looked at rather than assumed** — card #66 shot twelve consecutive 1280x720 frames at 1:1 and could not tell the worst adjacent pair apart at 4x zoom while holding a map of which pixels had moved. The dust is one step, never two, 12.4% of the densest 32x32 patch, and 0.8% of what a walking frame changes anyway. Do not re-open it off a pixel diff; `tools/directors/fog_crawl.gd` is the instrument if you want to see for yourself. |
| A director that opens a screen the GAME also opens | Every check passes — the widget is visible, anchored, correctly placed — and the PNG shows nothing there | `Run.extract()` / `Run.die()` start the real ending, and the real ending opens its **own** `RunEndScreen` a second later, on the same layer and later in the scene, so it draws over the one your beat opened. The director then reads a live widget that no pixel of reaches the frame. This cost an afternoon on card #156's receipt beat and `forgive_loop._settle` already knew: stand the ride home down (`Flow.ending = false`, free every `RunEndScreen` in the scene) BEFORE opening your own, and assert there is exactly one. Generalises past the receipt — any screen the game opens on its own can be the one you are photographing. **The frame is what caught it; the checks all said OK.** |
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
- **Game UI is terse.** Prefer short noun labels such as `DOCUMENT CASE` and
  `BAG`. Do not turn headings into explanations (`COMES HOME`, `DIES WITH YOU`,
  `CARRIED`) or repeat system consequences in every notice. A status notice
  reports the action (`Iron Scrap packed.`); tutorials or tooltips explain a
  consequence only when the player needs it to make a decision.
- Health uses integer **health points (HP)**. Runtime fields are `health_points`
  and `max_health_points`; `K.HEALTH_POINT` = 1, `K.START_HEALTH_POINTS` = 12,
  `K.HEALTH_UPGRADE_POINTS` = 4, `K.JEWEL_VIGOR_HEALTH_POINTS` = 2 per rung,
  and `K.MAX_HEALTH_POINTS` = 32.
- Metric: 1 unit = 1 m. Hero is 1.65 m. Shared constants live in
  `scripts/core/consts.gd` (`K`); per-system TUNING lives in `scripts/constants/`
  (§6.1).
- Values tagged `[oot]` in `K` are **measured from reference footage**. They are
  not typos and they are not yours to "correct".
- Comments explain *why*, and especially why the obvious thing is wrong. Match
  the density already in the file — this codebase comments its traps on purpose.
- `Flow` is the only thing that calls `change_scene_to_file`. Do not add a second.

### 6.1 Tuning is configuration, and it lives in `scripts/constants/`

**Every system you build here has to be tunable without opening its code.** The
hero's numbers used to be `@export` defaults buried in a 4,000-line `hero.gd`
and a 2,400-line `hero_combat.gd`; editing the pace of an attack meant hunting
exports across two files, and there was no way at all to slow *every* attack at
once. That is the failure this convention exists to stop.

`scripts/constants/` is the game's config directory — one file per system, each
a `class_name` that acts as the namespace, each holding a tree of nested inner
classes so a path reads like a config object:

```gdscript
Player.Animations.LIGHT_ATTACK[1]   # the clip the chain's SECOND step plays
Player.Attack.Light.TIME[1]         # how long that step lasts
Player.Attack.TIME_SCALE            # one multiplier over every attack
Player.Motion.Dodge.ROLL_TIME
```

Rules, all of them load-bearing:

- **Nested inner classes, not a `Dictionary` tree.** All four of the mechanics
  this depends on were probed on 4.7 rather than assumed: inner classes nest,
  `const` arrays may be typed, a `const` may reference `K.X` or another class's
  `const`, and an inner class may read the enclosing class's consts. A const
  `Dictionary` buys the same dotted-ish paths and loses static types,
  autocomplete and the parse error on a typo'd key — and §3's trap table already
  has two rows about const `Dictionary` indexing.
- **Anything that comes in steps is an ARRAY**, indexed from 0. The light chain
  is `TIME[0..2]`, not `swing_time` plus a `Vector2` of multipliers.
- **The system's script keeps its `@export`s and its behaviour; only the numbers
  move.** Exports default to the config (`@export var swing_time: float =
  Player.Attack.Light.TIME[0]`), which is what keeps every director in `tools/`
  working — they read these properties by name.
- **A number `K` owns stays in `K`.** The config references it (`const KNOCKBACK
  := K.KNOCKBACK_HEAVY`) when enemies, props or the HUD read the same constant.
  Two sources of truth is worse than one hop.
- **Timings are seconds; windows and audio cues are FRACTIONS of the move they
  belong to**, so they stay in the same place in the animation when the duration
  changes.
- **A scene must not store an override for a wired export.** `hero.tscn`
  deliberately stores no properties: an override saved in a `.tscn` silently
  wins over the config, and the symptom is "I edited the constant and nothing
  happened".

New system with numbers in it? Add `scripts/constants/<system>.gd` in the same
shape. Do not scatter literals through the implementation and do not invent a
second convention.

---

## 7. Design work and documentation

Start at **`docs/README.md`**, which owns the authority map. Then read
**`docs/NOW.md` before proposing or implementing gameplay work**. The GDD and
SCOPE describe the game we may make; NOW says what this stage authorises us to
learn and change.

The current stage is **Pre-production — Core Loop Proof**. The first-floor M4
prototype exists, but its human fun gate has not passed. M5 also exists; that is
accepted sequencing debt, not permission to continue. **Do not begin M6,
production content, or broad lore expansion until the active design test is
resolved.**

For uncertain design work:

1. Read `docs/MDA.md` and `docs/MECHANICS.md`, then open one design test under
   `docs/design-tests/`.
2. Name the target aesthetic, observable dynamics and minimum mechanics, then
   state the player-facing hypothesis and pass/revise/stop criteria before
   changing the build.
3. Build only the smallest test that could change the decision.
4. Put raw observations in `docs/playtests/`; put the decision and result in the
   design test; update canon only after the decision.

Canonical docs describe **current truth, not the history of arriving at it**.
Edit the governing rule in place. Do not append dated debates, implementation
diaries, or duplicate summaries to the GDD and system docs; those belong in a
design test, the archive, or git history. A fact has one document owner and
every other document links to it.

Update the owning doc in the same commit as code that changes its truth. A
design doc describing something the code no longer does is worse than no doc —
the next agent will believe it.
