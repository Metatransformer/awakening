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
| `critic_menu_hold.gd`, `critic_menu_hold2.gd` | `Invalid access to property or key 'name' on a base object of type 'null instance'` — the loop that walks settings focus is null-guarded and the line after it is not. Both are pad-driven probes from `34318cf` that can no longer reach the rows (`--keep-pad` does not help; measured). **Card #70.** |
| `voices.gd` | `Invalid access to property or key of type 'String' on a base object of type 'Dictionary'` — `DialogueDb.SAID[&"elder"][first]` on a take id that is not a key. It is a symptom: the same run fails seven of its own checks. **Card #71.** |
| `_error_selftest.gd` | Wrong on purpose. It frees a node and casts the dangling reference from a *helper*, so the error aborts only the helper and `run` carries on to print `SELFTEST OK -- every check passed`. That is #47 exactly, and it is how you watch the gate fire. |

Those three are the whole of `tools/script_errors.allow` — per director **and**
per message, each row carrying the card that deletes it. There is deliberately no
switch that turns the gate off wholesale. An exempt error is still printed and
still counted; the row only withholds the exit code.

**Two things the survey found that are worse than the cast error it went looking
for.**

1. **A director's own `FAIL` never reaches the exit code.** Sixteen of the 136
   failed checks they had written for themselves — `relic_donate` failed nine,
   `voices` seven, `critic_menu` printed 26 FAIL lines — and **all 136 exited
   0**, because `shoot.gd._run` ends in `quit(0)` unconditionally. If you wrap a
   director in `timeout 400` and read `$?`, you are reading nothing at all. Card
   #72. Until it closes, **read the output; the status is not a verdict.**
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

Before you call something done: a clean `pnpm import`, clean boot, the relevant
director with no failures, and *your own eyes on the output*.

**`pnpm import` and not `godot --path . --import`**, which is what this line used
to say. Raw `--import` boots the editor — window, keyboard and all — and then
leaves you to remember the `project.godot` repair in §3 by hand. `tools/import.mjs`
passes `--headless`, puts `project.godot` back, tells you how many comment lines
the importer ate, and boots the project once to prove it still starts.

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
| A pixel diff between two captures of a scene frozen with `Engine.time_scale = 0` | Ink where nothing was drawn — a beat failing at 93 px on a door with no caption anywhere on it | **The freeze stops the game clock, and two things here do not run on it.** `KitTorch` swung its light off `Time.get_ticks_msec()` until card #45 (it accumulates `delta` now), and **Godot's volumetric fog is temporally reprojected with a per-frame jitter that never converges** — so a stopped room is never twice the same. Measured by `tools/directors/frame_repro.gd` on floor 1, 43 sconces: flames live, **654k of 921k px move and 111k pass the 0.02 the directors call ink**; flames held, the fog alone still moves 67k px. At native that fog jitter is a delta of **1/255** and nothing sees it — but §4.5's internal buffer quantizes to RGB555, whose step is 8/255, so under `internal_render` (**the default**) the same sub-LSB wobble crosses a step and **2.6k px clear the ink threshold**. Held still and un-reprojected, two frames are **bit-identical: 0 px**. `rig.still_the_frame()` does both; call it before any pair. The dither is NOT a suspect — it is fixed per output pixel and provably deterministic. **Read the quantizer as the general hazard and not as a fog one:** §4.5's step is 8/255, so *any* temporal wobble smaller than that — the next TAA-ish, accumulating or reprojected thing anyone turns on — is invisible at native and is ink under `internal_render`. The fog is the first one this bit, not the last. **It is a harness problem and NOT a game one, and that was looked at rather than assumed** — card #66 shot twelve consecutive 1280x720 frames at 1:1 and could not tell the worst adjacent pair apart at 4x zoom while holding a map of which pixels had moved. The dust is one step, never two, 12.4% of the densest 32x32 patch, and 0.8% of what a walking frame changes anyway. Do not re-open it off a pixel diff; `docs/STYLEGUIDE.md` §4.5 has the numbers and `tools/directors/fog_crawl.gd` is the instrument if you want to see for yourself. |
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
