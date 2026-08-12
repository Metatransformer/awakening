extends SceneTree
## Headless-ish screenshot harness.
##
## Loads a scene, lets it settle, optionally runs a "director" script that can
## drive input / advance state, and writes PNG frames to disk. This is the only
## way the visual critics ever see the game, so it must be deterministic.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/dungeon/room_a.tscn \
##       --out=/tmp/shot.png \
##       --warmup=45 \
##       --size=1280x720
##
## Optional:
##   --director=res://tools/directors/combat.gd   script with `func run(rig)`
##   --burst=8 --burst-gap=6                      contact sheet of N frames
##   --seed=12345                                 deterministic RNG
##   --max-fps=3                                  throttle the render, to
##                                                reproduce a loaded machine
##                                                (see `_throttle_the_render`)
##   --intro                                      let the garrison play its
##                                                opening (off by default --
##                                                see `_skip_the_opening`)
##   --fresh                                      do NOT stamp the keepers into
##                                                the yard (see
##                                                `_open_the_garrison`)
##   --meet                                       leave ONE introduction owed --
##                                                the first rung -- and mark the
##                                                rest met (off by default --
##                                                see `_skip_the_introductions`)

## The scratch config every harness run writes instead of `user://settings.cfg`.
## See `_sandbox_the_settings`.
const HARNESS_SETTINGS := "user://harness_settings.cfg"

## Must equal `Settings.HARNESS_META`, and it is spelled out here rather than
## read from that script ON PURPOSE. `preload("res://scripts/autoload/settings.gd")`
## compiles settings.gd as a dependency of THIS file, which happens before the
## autoloads are registered — so its reference to `Bus` fails to resolve and
## takes the whole harness down with it (CLAUDE.md §3, the "Identifier not
## found" row, which turns out to bite outside `--check-only` too). The two
## constants cannot drift silently: `_verify_sandbox` below fails the run.
const HARNESS_META := &"zl_harness_settings_path"

## The file the sandbox exists to keep this harness away from. Mirrors
## `Settings.DEFAULT_PATH`, for the same reason HARNESS_META is spelled out.
const PLAYER_SETTINGS := "user://settings.cfg"

## Exit code for "the director ran to the end and failed its own checks".
##
## Deliberately distinct from every status already read around here: `timeout`
## owns 124, signals own 128+n, `shoot.gd`'s setup failures own 2-6, and #63's
## SCRIPT ERROR gate owns 65. A run that fails a check AND printed a script
## error keeps 65 -- the wrapper sees the error first and an error is the bigger
## fact.
const EXIT_DIRECTOR_FAIL := 66

var _args := {}
var _out_paths: Array[String] = []

## Failures a director has reported through `fail()`. See `_harvest_failures`.
##
## **THE PROTOCOL, for anything written from 2026-08-11 on.** Before this
## existed a director had no way to say "I failed" except putting the word in
## its stdout, and `_run` ended in `quit(0)` unconditionally -- so sixteen of
## the 136 directors were failing checks they had written for themselves and all
## 136 exited 0 (card #72). An agent that wraps the command and reads `$?`, which
## is the normal thing to do, recorded a pass on a director printing nine
## failures.
var fails := 0


func _initialize() -> void:
	_parse_args()

	var seed_val := int(_args.get("seed", "20190920"))
	seed(seed_val)
	_sandbox_the_settings()
	_deafen_the_gamepad()
	_hush_the_speakers()
	_warn_if_launched_bare()
	_throttle_the_render()

	var size_str: String = _args.get("size", "1280x720")
	var wh := size_str.split("x")
	var win_size := Vector2i(int(wh[0]), int(wh[1]))
	root.content_scale_size = win_size
	_size_the_window(win_size)
	_park_the_window(win_size)

	_run.call_deferred()


## Make the OS window ACTUALLY `--size`, so a capture is 1:1 with what a player
## would see.
##
## **Every proof frame in this repo's history before this line was a ~20x
## supersample.** `project.godot` has `window/size/mode=2` -- WINDOW_MODE_MAXIMIZED
## -- so the window came up filling the display no matter what this script
## assigned to `root.size`, and `window/stretch/mode="canvas_items"` scales only
## the 2D and leaves the 3D rendering at the window's true backing resolution.
## Measured on this Mac: `win=6880x2756`, nineteen megapixels for a 1280x720
## canvas. `capture()` then Lanczos-downscales that to `--size`, which is textbook
## supersampling -- so aliasing, thin geometry and small HUD type all came out of
## a proof looking better than they will on screen. `enemy_bars.gd` put a number
## on it: an eight-stroke bracket that should be ~128 pixels of one exact palette
## colour survived the downscale as FIVE.
##
## `root.size` is not the knob and never was -- a maximized window ignores it, and
## the tell was two "different" `--size` runs reporting the same `vram_mb`.
## `window_set_mode(WINDOW_MODE_WINDOWED)` first, THEN `window_set_size`: the mode
## call is what releases the maximize, and a size set while still maximized is
## silently dropped. `perf_probe.gd --win=`, `enemy_bars.gd` and `hud_lookdev.gd`
## had each grown a local copy of these two lines; this is that fix, once, for
## every director (#35).
##
## `Settings.apply_video` will not undo it: it only ever leaves FULLSCREEN, and
## deliberately does not force a mode otherwise (see its comment).
##
## It prints what it GOT and not what it asked for, because a resize that does not
## take is exactly the failure this whole card is about, and it must not be silent.
func _size_the_window(win_size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win_size)
	root.size = win_size
	var got := DisplayServer.window_get_size()
	if got != win_size:
		push_warning("shoot.gd: asked for a %dx%d window and got %dx%d -- the "
			% [win_size.x, win_size.y, got.x, got.y]
			+ "capture will be resampled, so do not judge edges on it")
	print("shoot: rendering at %dx%d" % [got.x, got.y])


## Put the harness window in the far bottom-right corner, out of the owner's way.
##
## THE POINT IS THE OWNER'S KEYBOARD, and this is only the small half of it. A
## director run opens a real macOS window; several agents run directors here at
## once, and the windows came up over whatever was being typed into and took the
## keystrokes with it. The half that actually fixes that is `no_focus`, which is
## read once at window creation and so has to arrive before this script exists --
## see `tools/quiet.sh`. This just moves the window off the working area; it used
## to open at (40, 40), which on a Mac is directly on top of everything.
##
## DO NOT "IMPROVE" THIS BY MINIMISING THE WINDOW. It is the obvious next idea,
## it looks like it works, and it silently breaks every capture run. A minimised
## window still reports the right size and still answers `get_image()` with the
## right pixels when you poke it from a bare script -- which is exactly why this
## got written, landed, and had to be taken back out. Run a real director against
## one and it never produces a single frame: measured on `p2_walk_run_stop`,
## visible 23 s and 15 PNGs, minimised timed out at 75 s with 0 PNGs. The frames
## simply stop arriving. `no_focus` on a visible window has no such problem --
## same director, same 15 PNGs -- so take the keyboard fix and leave the window
## on screen.
func _park_the_window(win_size: Vector2i) -> void:
	var usable := DisplayServer.screen_get_usable_rect(root.current_screen)
	root.position = usable.position + usable.size - win_size - Vector2i(8, 8)


## Point `Settings` at a scratch config so a director can never write the
## player's own preferences.
##
## This has to happen here, in `_initialize`, because it is the last moment
## before the autoloads' `_ready` — Settings reads the meta there and an
## explicit `--settings=` on the command line still beats it.
##
## THIS IS NOT TIDINESS, IT IS THE FIX FOR A BUG THAT LANDED TWICE. A director
## that rebinds a key calls `Settings.rebind()`, which calls `save_settings()`,
## which wrote `user://settings.cfg` — the real one. `_menu_director.gd` puts
## `attack` on N to photograph the rebind flow, so the owner's config came out
## of a screenshot run with `attack` bound to N and the game booted with a dead
## sword button. Twice. The audio sliders leaked the same way: the same director
## drags Music to the floor, and the game came up silent.
##
## It is WORSE than a stray keybind, and `_deafen_the_gamepad` below is why. The
## pad bindings are gone from the InputMap by the time the director rebinds, so
## the bind that gets serialised has no pad event in it at all, and
## `Settings.apply_binds` erases an action before replaying it. One keyboard
## rebind in a menu test = RB permanently unbound from `attack` on the machine
## that ran it. Nothing the director does is wrong; writing it to the real file
## is. So the harness does not get the real file.
## Deleting it each run is not housekeeping either: this harness exists to be
## deterministic, and a scratch config that survived the last run would replay
## whatever that run's director happened to set. Every run starts from the
## shipped layout. A director that WANTS to carry state across runs passes its
## own `--settings=`, which this never touches.
func _sandbox_the_settings() -> void:
	Engine.set_meta(HARNESS_META, HARNESS_SETTINGS)
	if FileAccess.file_exists(HARNESS_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HARNESS_SETTINGS))


## Strip every joypad binding out of the InputMap for the life of this run.
##
## A controller plugged into the machine running the harness is an INPUT SOURCE
## the director does not control. This cost a long afternoon: a stick resting
## just outside its deadzone reported `move_up`, `move_right`, `cam_down` and
## `cam_left` held, the hero walked away from the garrison gate mid-hold,
## `Prompt` dropped focus, and the director reported five economy failures for a
## gate that had simply not been reached. It was intermittent because the drift
## wanders in and out, so it looked like a race in the game and not a joystick
## on somebody's desk.
##
## The InputMap edit is in-memory only -- `project.godot` is never written -- and
## keyboard events, which is all `Input.action_press` needs, are untouched.
## `--keep-pad` opts out, and exactly one kind of director needs it: one that is
## photographing what the pad's own bindings LOOK like (the HUD's key caps read
## the live InputMap through `Glyph`, so a stripped map draws blank caps and the
## sheet proves nothing). Do not pass it with a controller plugged in — the
## afternoon described above is what you get back.
func _deafen_the_gamepad() -> void:
	if _args.has("keep-pad"):
		print("shoot: --keep-pad, the gamepad's BINDINGS are live")
		return
	var stripped := 0
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
				stripped += 1
	if stripped > 0:
		print("shoot: ignoring the gamepad (%d joypad bindings stripped)" % stripped)


## Silence. **A harness run makes no noise, ever, unless you ask for it.**
##
## A director is not a playthrough — it is a batch job that somebody runs six of
## in a row while they are reading something else, and every one of them opens a
## window that starts playing the dungeon score and firing a bell at every atom.
## Six overlapping soundtracks out of a background task is not feedback, it is a
## machine shouting at whoever launched it, and there is nothing in a WAV that a
## screenshot or a `FAIL` line does not say better.
##
## The MASTER bus, not `Music` and `Sfx`. Two reasons: it is one call rather than
## a list that goes stale the day somebody adds an `Ambience` bus, and it is
## `set_bus_mute` rather than a volume, so `Settings.apply_audio` running later in
## the autoloads' `_ready` cannot quietly undo it by writing the sliders back.
##
## `--sound` opts in, for the one director that would ever want it: one proving
## that a cue FIRES. Nothing does today.
func _hush_the_speakers() -> void:
	if _args.has("sound"):
		print("shoot: --sound, the run is audible")
		return
	AudioServer.set_bus_mute(0, true)


## Say so when this run was started as bare `godot` instead of `tools/quiet.sh`.
##
## THIS IS THE ONE THING THIS SCRIPT CANNOT FIX FOR ITSELF. `no_focus` is read
## once, at window creation, which is before `_initialize` exists — a window
## born without it can never be talked into giving the keyboard up later
## (measured: 0/240 focused frames when the flag arrives via override.cfg,
## 16/240 when set from here). So a bare `godot -s tools/shoot.gd` opens a real
## window in front of whatever the owner is typing into and takes the
## keystrokes, and does it silently, which is exactly how the habit survives:
## the run passes, the director is green, and the only person who finds out is
## the one whose sentence went into the harness.
##
## Four agents run directors on this machine at once and three of the four
## commands in flight when this was written said bare `godot`. A wrapper nobody
## reaches for is not a fix, so the harness reports its own launch.
func _warn_if_launched_bare() -> void:
	if bool(ProjectSettings.get_setting("display/window/size/no_focus", false)):
		return
	printerr("shoot: WARNING - launched as bare `godot`, so this window WILL "
		+ "steal the owner's keyboard. Use `tools/quiet.sh` in place of "
		+ "`godot` (CLAUDE.md §2).")


## `--max-fps=N` — render this slowly on purpose.
##
## **This is the reproduction lever for the busy-machine failures**, and it exists
## because "run it again when four other agents are rendering" is not a test
## anybody can repeat. Godot clamps how many physics steps one rendered frame is
## allowed to catch up (`physics/common/max_physics_steps_per_frame`, default 8),
## so below ~7.5 fps the GAME CLOCK falls behind the wall clock and cannot get
## back: measured on the garrison at `--max-fps=5`, 1.00 s of wall time bought
## 0.67 s of game time, every slice, for eight slices. That ratio is the whole of
## issue #33 — a director whose deadlines were denominated in wall seconds got a
## third less of the thing it was actually waiting for.
##
## It is a knob and not a default because a throttled run is a SLOWER run in
## every other respect too; reach for it when a beat only fails on somebody
## else's machine, and to prove that a watchdog can still fire.
func _throttle_the_render() -> void:
	var cap := int(_args.get("max-fps", "0"))
	if cap <= 0:
		return
	Engine.max_fps = cap
	print("shoot: --max-fps=%d, the render is throttled and the game clock will "
		% cap + "lag the wall clock below ~7.5 fps")


## Put `instance` under the root and wait until it is really in the tree.
##
## `root.add_child()` cannot be called while the root is mid-way through adding
## its own children, and that is exactly when _run gets to run: an autoload's
## _ready (Settings.apply_video) calls into DisplayServer, macOS pumps the event
## queue inside that call, and Godot runs a nested main-loop iteration which
## flushes the deferred queue AND emits process_frame. So neither call_deferred
## nor `await process_frame` is a safe moment -- both fire inside the nested
## iteration, and a deferred add_child that lands there fails silently and is
## NOT retried, which hangs the harness forever.
##
## Settings.apply_video no longer re-asserts the window mode at boot, which
## removes the cause. This retries anyway: a capture rig that deadlocks when an
## unrelated autoload touches the window is a trap waiting for the next author.
func _attach_scene(instance: Node) -> void:
	for attempt in 240:
		if instance.is_inside_tree():
			return
		root.add_child(instance)
		await process_frame
	push_error("shoot.gd: could not attach the scene to the root")
	quit(5)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq == -1:
			_args[body] = "1"
		else:
			_args[body.substr(0, eq)] = body.substr(eq + 1)


## Fail the run if `Settings` is still pointed at the player's real config.
##
## `_sandbox_the_settings` sets a meta key that Settings reads by name, so the
## two spellings are only joined by a string. This is the joint, checked once
## per run now that the autoloads are up: if it ever comes apart, the harness
## stops instead of quietly going back to writing `user://settings.cfg`. A
## silent version of this check is worth nothing — silence is how a screenshot
## run unbound the sword from RB and nobody noticed for a day.
## `Settings` is fetched by path, not written as an identifier: this file is a
## MainLoop launched with `-s`, and autoload NAMES do not resolve at compile
## time there. Spelling it `Settings.path` costs the whole harness with
## "Identifier not found: Settings" — the same family of trap as the preload
## above, one layer out.
func _verify_sandbox() -> void:
	var s: Node = root.get_node_or_null(^"Settings")
	if s == null:
		# Not "nothing to check" — the autoload this guards has gone missing or
		# been renamed, so the guard is not guarding. Say so; a check that goes
		# quiet when it loses its subject is the bug it was written against.
		push_warning("shoot.gd: no /root/Settings — the settings sandbox is unverified")
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings="):
			return  # the caller named a file; that is their business
	if str(s.get(&"path")) != PLAYER_SETTINGS:
		return
	push_error("shoot.gd: Settings is still on %s -- the sandbox did not take. "
		% PLAYER_SETTINGS
		+ "shoot.gd's HARNESS_META must equal Settings.HARNESS_META. Refusing "
		+ "to run: a director could overwrite the player's real preferences.")
	quit(6)


## The flag `Garrison._open_the_game` reads. Spelled out rather than reached for
## through `Garrison.INTRO_FLAG`, for the reason `HARNESS_META` is: naming a
## `class_name` here compiles that script -- and everything it references -- as a
## dependency of this file, before the autoloads exist. `tools/directors/voices.gd`
## is what would fail if the two ever drift, and it says so.
const INTRO_FLAG := &"reported_for_duty"

## The flags `StoryDb.unlocked` latches when a keeper's gate is first met.
##
## Spelled out here for the same reason `INTRO_FLAG` is: naming `StoryDb` compiles
## it, and everything it references, as a dependency of this file before the
## autoloads it reads (`Game`) exist. `StoryDb.arrival_flag` is the one that must
## not drift from these five strings.
const ARRIVED_FLAGS: Array[StringName] = [
	&"garrison_elder_arrived",
	&"garrison_quartermaster_arrived",
	&"garrison_smith_arrived",
	&"garrison_alchemist_arrived",
	&"garrison_jewelcrafter_arrived",
]

## The flags `StoryDb.pending_introduction` reads -- `StoryDb.intro_flag`, spelled
## out for the third time for the reason above.
##
## These are NOT the same thing as `ARRIVED_FLAGS` and the pair has to be settable
## separately: arrived is "she has been earned", met is "the elder has already
## introduced her". A director that stamps the first and not the second gets a
## yard that opens a four-page conversation over whatever it was about to
## photograph, one and a bit seconds in.
##
## **In ladder order** (`StoryDb.INTRO_ORDER`), because `--meet` slices this list
## and the slice has to leave the FIRST rung owed -- see `_skip_the_introductions`.
const MET_FLAGS: Array[StringName] = [
	&"met_quartermaster",
	&"met_smith",
	&"met_alchemist",
	&"met_jewelcrafter",
]


## Do not play the opening at a director, unless the director asked for it.
##
## The garrison narrates itself the first time a save sees it: fifteen seconds of
## voice over an opaque veil with the world paused. That is correct for a player
## and ruinous for a harness -- every garrison director starts from a fresh
## `Game`, so every one of them would open by photographing a black screen and
## then wait a quarter of a minute to be allowed to press anything.
##
## So it is off here by default and `--intro` turns it back on, which is the same
## bargain as the settings sandbox above: the harness is made safe whether or not
## the author of the next director thought about it, and the one director that
## needs the real thing says so out loud.
func _skip_the_opening() -> void:
	if _args.has("intro"):
		return
	var game: Node = root.get_node_or_null(^"Game")
	if game == null:
		push_warning("shoot.gd: no /root/Game -- cannot skip the opening")
		return
	game.call(&"set_flag", INTRO_FLAG)


## Put all five keepers in the yard, whatever this save has killed.
##
## Same bargain as `_skip_the_opening`: a director starts from a fresh `Game`, and
## a fresh `Game` has three of the five counters still on the road (`StoryDb`).
## Every garrison director in this repo photographs the smith, the alchemist or
## the jewelcrafter, and none of them is about the unlock — so the harness is made
## normal by default, and the one director that cares about the empty yard says so
## with `--fresh`.
##
## `--fresh` clears nothing; it only declines to stamp. The opening flag is a
## separate switch (`--intro`) because the two are wanted separately: `mvp_loop`
## wants the shops without the fifteen-second narration.
func _open_the_garrison() -> void:
	if _args.has("fresh"):
		return
	var game: Node = root.get_node_or_null(^"Game")
	if game == null:
		push_warning("shoot.gd: no /root/Game -- cannot open the garrison")
		return
	for flag: StringName in ARRIVED_FLAGS:
		game.call(&"set_flag", flag)


## Do not introduce anybody at a director, unless the director asked.
##
## The yard plays a four-page scene with a camera move in it the first time you
## come home after somebody new arrives (`Garrison._do_the_rounds`), and
## `_open_the_garrison` above has just made every keeper new. Without this, EVERY
## garrison director would sit through an introduction starting one and a bit
## seconds after the scene loads, which is exactly when most of them take their
## first frame.
##
## **`--meet` leaves exactly ONE owed -- the first rung -- and marks the rest**,
## which is a stronger promise than the "stamp nothing" it used to make, and card
## #115 is why it had to become one. A keeper is now built only once they have
## been INTRODUCED (`StoryDb.present`), so stamping no `met_` at all no longer
## means "five people in the yard, four scenes queued": it means **two people in
## the yard**, and `npc_intro.gd`'s long-pan beat would have been photographing a
## smith who was never constructed. Both directors that pass `--meet` already
## stamped the other three by hand as their first act (`npc_intro`,
## `save_load_position`) precisely because four back-to-back scenes were
## unwatchable -- so this is their own setup, moved to where it happens before
## `_ready` instead of after it.
##
## The slice is `MET_FLAGS[1..]` and that list is in ladder order on purpose. Same
## shape as `--intro` and for the same reason: the harness is quiet by default
## whether or not the author of the next director knew this existed.
func _skip_the_introductions() -> void:
	var game: Node = root.get_node_or_null(^"Game")
	if game == null:
		push_warning("shoot.gd: no /root/Game -- cannot skip the introductions")
		return
	var flags := MET_FLAGS.slice(1) if _args.has("meet") else MET_FLAGS
	for flag: StringName in flags:
		game.call(&"set_flag", flag)


func _run() -> void:
	_verify_sandbox()
	_skip_the_opening()
	_open_the_garrison()
	_skip_the_introductions()

	var scene_path: String = _args.get("scene", "")
	if scene_path.is_empty():
		push_error("shoot.gd: --scene= is required")
		quit(2)
		return

	if not ResourceLoader.exists(scene_path):
		push_error("shoot.gd: scene not found: %s" % scene_path)
		quit(3)
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("shoot.gd: not a PackedScene: %s" % scene_path)
		quit(3)
		return

	var instance := packed.instantiate()
	await _attach_scene(instance)
	current_scene = instance

	var warmup := int(_args.get("warmup", "45"))
	await _wait_frames(warmup)

	var director_path: String = _args.get("director", "")
	if not director_path.is_empty():
		if not ResourceLoader.exists(director_path):
			push_error("shoot.gd: director not found: %s" % director_path)
			quit(4)
			return
		# A director with a parse error loads as null, and `null.new()` used to
		# leave the harness sitting here until its outer `timeout` killed it --
		# with the actual "Parse Error:" line scrolled off the top and no
		# SHOT_OK to mark the end. Two runs and eight minutes went into working
		# out that a hang was a typo. Say which script, and stop.
		var director_script := load(director_path) as GDScript
		if director_script == null:
			push_error("shoot.gd: director failed to parse: %s (look further up "
				% director_path + "this log for the Parse Error line)")
			quit(4)
			return
		var director = director_script.new()
		if director.has_method("run"):
			var returned = await director.run(self)
			_harvest_failures(director, returned)
		else:
			push_error("shoot.gd: director has no run(rig): %s" % director_path)
			quit(4)
			return
	else:
		var burst := int(_args.get("burst", "1"))
		var gap := int(_args.get("burst-gap", "6"))
		for i in burst:
			await capture(_indexed_out(i, burst))
			if i < burst - 1:
				await _wait_frames(gap)

	print("SHOT_OK %s" % ", ".join(_out_paths))

	# ONE canonical verdict line, whatever the director spelled its own failures.
	# The eight spellings in the tree (`RELIC FAIL -- 9 check(s) failed`,
	# `PAD FAIL z_target has no pad cap`, `HOUSE FAILED (3)`, prose, ...) are why
	# card #72 rejected gating on a grep for "FAIL": that is a guess about a
	# convention which does not exist, and the word also appears in directors'
	# own legend text. This line is the convention.
	if fails > 0:
		print("DIRECTOR FAIL %d" % fails)
		quit(EXIT_DIRECTOR_FAIL)
		return
	print("DIRECTOR OK")
	quit(0)


## Read the director's failure count out of whichever place it keeps one.
##
## Three routes, and the second and third exist only because 136 directors were
## written before the first one did:
##
##  1. `rig.fail("...")` -- the protocol. New directors use this and nothing else.
##  2. `return N` from `run()` -- an int return is a count of failures.
##  3. an int `_fails` / `_fail` / `fails` on the director itself -- harvested,
##     because 66 directors already keep one under one of those three names and
##     rewriting all 66 in a single commit is how you get a silent typo in 66
##     files. The other 51 print a failure and tally nothing; those have to be
##     migrated to `fail()` one at a time, and until a director is migrated it
##     still cannot fail its own run. `tools/director_selftally.sh` lists which.
##
## **A migrated director must DELETE its own counter**, because these add. That
## is safe to state as a rule today: `fail()` is new, so nothing increments both.
func _harvest_failures(director, returned) -> void:
	if returned is int and returned > 0:
		fails += returned

	# `get()` on an absent property returns null quietly, but only for a property
	# the class never declared -- so read the declaration list instead of
	# guessing, and never confuse "declared 0" with "not declared".
	var declared := {}
	for p in director.get_property_list():
		declared[p.get("name", "")] = true
	for name in [&"_fails", &"_fail", &"fails"]:
		if not declared.has(String(name)):
			continue
		var n = director.get(name)
		if n is int and n > 0:
			fails += n
		# One counter per director. Two would be the same failures counted twice.
		break


# --- API available to director scripts -------------------------------------

## Report a failed check. THIS is how a director fails its run (card #72).
##
## Prints the message with a stable prefix and counts it, so `_run` can end in a
## non-zero status. A director that only `print`s its failures exits 0 and is
## read as a pass by anything that checks the status instead of the prose.
func fail(message: String) -> void:
	fails += 1
	print("FAIL %s" % message)


## Assert `ok`, reporting `message` if it does not hold. Returns `ok`, so a beat
## can stop rather than cascade -- see `mvp_loop`'s abort comment for why four
## downstream failures caused by one upstream cause is worse than one.
func check(ok: bool, message: String) -> bool:
	if not ok:
		fail(message)
	return ok

## Wait n rendered frames.
##
## **A rendered frame is not a unit of anything the GAME measures in.** Physics
## runs at its own rate, and the ratio between the two is a property of the
## machine: 1:1 on a 60 Hz panel, 1:2 on the 120 Hz one this project is built on,
## and anything at all while a shader compiles. So `wait_frames` is the right
## instrument for "let the picture settle before a capture" and the wrong one for
## every "wait until the game has done X" -- use `until` for those.
func wait_frames(n: int) -> void:
	await _wait_frames(n)


## Wait n PHYSICS ticks. The unit for anything driven by the physics step:
## an Area3D noticing a body, a CharacterBody3D settling onto the floor.
func wait_physics_frames(n: int) -> void:
	for i in maxi(n, 1):
		await physics_frame


## Wait n seconds of game time.
func wait_seconds(s: float) -> void:
	await create_timer(s).timeout


## Wait until `test` answers true, and say whether it ever did.
##
## THE UNIT OF A WAIT IS THE THING WAITED FOR. Almost nothing a director waits on
## is a number of rendered frames: it is a state -- a prompt taking focus, a
## screen finishing its close, a body being noticed by the trigger it was
## teleported into. Those arrive on the physics clock, or on a timer, or on a
## signal, and a director that guesses a frame count instead is a director whose
## pass/fail depends on the refresh rate of the panel it ran on.
##
## `mvp_loop`'s sell beat cost this project a long session for exactly that: it
## teleported the hero at the vendor, waited 20 RENDERED frames, and pressed. The
## vendor's `Interactable.player_inside` is set by an Area3D and arrives about two
## PHYSICS ticks after the teleport -- render frames 3 to 5 at 60 Hz physics on a
## 120 Hz panel, and 20 to 24 when the ratio moves. When it missed, the one press
## the beat had went into a world where nothing was focused, the shop never
## opened, and four later beats reported failures they had not caused.
##
## **TWO CLOCKS, TWO LIMITS — and `seconds` is the GAME one.** This used to count
## its whole deadline in `Time.get_ticks_msec()`, on the argument quoted below:
## a watchdog cannot be counted on a clock that may have stopped. That argument
## is right about the watchdog and wrong about the budget, and the difference is
## issue #33.
##
## Everything a director waits on through here is a game-clock event: a windup
## finishing, a body walking to a place at its own speed, a screen easing shut.
## Godot clamps how many physics steps one rendered frame may catch up
## (`physics/common/max_physics_steps_per_frame`, default 8), so on a machine
## rendering below ~7.5 fps the game clock falls behind the wall clock and never
## catches up. Measured with `--max-fps=5`: 1.00 s of wall time, 0.67 s of game
## time, eight slices out of eight. A `until(grab_started, 8.0)` was therefore
## worth 8 s on an idle machine and 5.4 s on a busy one — so `thief.gd` printed
## "the goblin never reached for the bag in 8 s" and then went on to photograph
## the theft it had just declared impossible. A check that gets stricter the
## busier the machine is is a check that cries wolf exactly when somebody is
## least able to look into it, and this repo's proof discipline (CLAUDE.md §2)
## is worth precisely what a FAIL line is worth.
##
## So the budget is spent in game seconds — counted off `Engine.get_physics_frames()`
## rather than accumulated process deltas, because the physics frame IS the tick
## the world moves on, and it is the one the clamp starves. The wall clock stays,
## demoted to what it always claimed to be: the outer "the game has stopped"
## watchdog, generous enough (4x + 3 s, the same allowance `hold_seconds` uses)
## that it can only fire on a game that has genuinely stalled — and it SAYS SO
## when it fires, naming both clocks, so the next reader can tell a stalled game
## from an event that never arrived.
##
## **A PAUSED TREE STOPS THE PHYSICS FRAME COUNTER**, so a wait that is going to
## fail while a screen has the tree paused (`RunEndScreen`, the pause menu) spends
## no game time at all and runs to the wall watchdog instead — several seconds
## rather than `seconds`. That is the honest answer, because a paused world is a
## world in which the thing being waited for genuinely cannot happen, and the
## watchdog line says `paused=true` so nobody has to guess. It costs a failing
## beat a few seconds; it costs a passing one nothing, because the predicate is
## still polled every rendered frame.
func until(test: Callable, seconds: float = 3.0) -> bool:
	var step := root.get_physics_process_delta_time()
	var ticks0 := Engine.get_physics_frames()
	var wall0 := Time.get_ticks_msec()
	# 4x the budget plus 3 s. The worst game:wall ratio this project has measured
	# is 0.67 at 5 fps; 0.25 is well past anything a machine with four directors
	# on it produces, so a run that reaches this line is stalled and not merely busy.
	var wall_deadline := wall0 + int(seconds * 4000.0) + 3000
	while true:
		if test.call():
			return true
		var spent := float(Engine.get_physics_frames() - ticks0) * step
		if spent >= seconds:
			return false
		if Time.get_ticks_msec() >= wall_deadline:
			print(("shoot: until() gave up on the WALL clock after %.1f s having "
				+ "spent only %.2f s of game time out of %.2f -- the game is not "
				+ "advancing (Engine.time_scale=%.2f, paused=%s)")
				% [float(Time.get_ticks_msec() - wall0) / 1000.0, spent, seconds,
					Engine.time_scale, paused])
			return false
		await process_frame
	return false


## Capture the current frame to `path` (absolute, or relative to --out's dir).
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	# The OS may hand back a hiDPI-scaled backbuffer; force the exact requested
	# resolution so every A/B comparison is pixel-comparable with the refs.
	var wh := arg("size", "1280x720").split("x")
	var want := Vector2i(int(wh[0]), int(wh[1]))
	if img.get_size() != want:
		img.resize(want.x, want.y, Image.INTERPOLATE_LANCZOS)
	var abs_path := path
	if not abs_path.begins_with("/") and not abs_path.begins_with("res://"):
		abs_path = _out_dir().path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("shoot.gd: failed to save %s (%d)" % [abs_path, err])
	else:
		_out_paths.append(abs_path)


## Hold a set of input actions down for `frames`, then release.
## Actions are Input Map action names, e.g. ["move_up", "attack"].
##
## The leading `await process_frame` is load-bearing. Input stamps a synthetic
## press with the CURRENT frame number, and `is_action_just_pressed` compares
## that stamp against the frame it is called in -- so a press issued from a
## `frame_post_draw` resume (which is what every `capture()` leaves you on) is
## already one frame stale before any node's `_process` runs, and every polled
## button in the game silently ignores it. Pressing at the top of a frame puts
## the stamp and the poll in the same frame, wherever the caller resumed from.
func hold(actions: Array, frames: int) -> void:
	await process_frame
	for a in actions:
		_send(a, true)
	await _wait_frames(frames)
	for a in actions:
		_send(a, false)


## Tap actions for a single frame.
func tap(actions: Array) -> void:
	await hold(actions, 2)


## Put a button DOWN and leave it there. Pair with `release`.
##
## `hold` and `hold_seconds` own the whole press, which is what a beat wants
## almost always -- but not when the beat has to WATCH something while the button
## is down: sample a gauge every frame and let go on a reading, or take the
## shutter mid-fill and carry the same press on through the commit. Those wrote
## `Input.action_press` inline instead, and that is CLAUDE.md §3's most expensive
## row: it sets action state and dispatches **no** `InputEvent`, so a screen read
## through `_unhandled_input` never hears it. `_send` is the fix and this is the
## door to it, so nobody has to reach past the rig to hold a button open.
##
## The `await process_frame` is `hold`'s, for `hold`'s reason -- see its
## docstring. A press issued from a `frame_post_draw` resume (where `capture()`
## leaves you) is stamped with a frame that is already spent, and every
## `is_action_just_pressed` in the game ignores it.
func press(action: StringName) -> void:
	await process_frame
	_send(action, true)


## Let a button that `press` put down back up.
func release(action: StringName) -> void:
	_send(action, false)


## Press or release one action so BOTH kinds of reader see it.
##
## **`Input.action_press` sets action state and dispatches no `InputEvent` at
## all** (CLAUDE.md §3), so until this existed, every action the game reads in
## `_unhandled_input` was UNREACHABLE from a director: the press was issued,
## nothing was delivered, and the beat silently measured the game not doing the
## thing. `Targeting` (the z_target toggle), `PauseMenu` (inventory, map, pause,
## the tab keys, ui_cancel) and `GameCamera` (first person) are all read that way
## -- on purpose, so a toggle cannot miss an edge -- and all three were deaf.
##
## It cost two wrong readings before it was carded as #40. `p1_orbit`'s recentre
## step photographed a camera that never moved for as long as it was written the
## obvious way, and card #34's Slag Ogre session spent a run chasing arrows that
## missed a body seven metres off, because `tap(["z_target"])` never locked on and
## `HeroRanged._aim_at_target_or_camera` fell through to a crosshair raycast. Five
## directors had each grown their own two-line copy of the block below; this is
## that fix, once, where every director gets it.
##
## BOTH calls, and in this order. `parse_input_event` alone would satisfy the
## event readers, but `Input.use_accumulated_input` is on by default, so the event
## sits in the buffer until the main loop's next flush -- and a poller reading
## `is_action_just_pressed` in THIS frame would miss an edge that the old code
## delivered (`hold`'s docstring below the `await` explains why that frame matters
## and is still correct). `action_press` puts the state in immediately; the event
## arrives a flush later for the `_unhandled_input` readers.
##
## It cannot double-fire a poller. `Input` only stamps `pressed_process_frame` on
## a not-pressed -> pressed transition, and the state is already pressed by the
## time the event lands, so `is_action_just_pressed` is true in exactly one frame.
func _send(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Put `id` in the hero's right hand by PRESSING D-pad →, the way a player does.
##
## Every director that wanted the bow out used to tap one D-pad direction, because
## the bow lived on a bound quick slot and its direction was a fact you could
## assert. That system is gone: the D-pad steps a RING now, so "draw the bow" is
## no longer one press of a known button — it is however many presses of → the
## ring needs, and the count depends on what the player owns.
##
## It goes through `tap` rather than setting `Game.loadout` directly on purpose.
## A director that assigns the hand is testing the renderer; one that presses the
## button is testing the button, and the button is the thing that broke last
## time. Returns false (and the caller should fail) when the ring never lands on
## `id` — which is what "you do not own it" looks like from out here.
## `Game` is fetched off the tree and never NAMED. This file is loaded with
## `-s`, and autoloads are not registered as identifiers for that mode
## (CLAUDE.md §3) -- so `Game.armament(...)` is not a runtime problem, it is a
## COMPILE error that takes the whole harness down with it, and every director
## in the project dies at load with "Identifier not found: Game" before its
## first frame. A director is the only proof this repo accepts, so this is the
## one file where naming an autoload costs everything.
func draw_weapon(id: StringName, limit: int = 8) -> bool:
	var game := root.get_node_or_null(^"Game")
	if game == null:
		push_error("shoot.gd: draw_weapon needs the Game autoload")
		return false
	for i in limit:
		if game.armament(game.HAND_RIGHT) == id:
			return true
		await tap(["weapon_next"])
	return game.armament(game.HAND_RIGHT) == id


## Hold actions for `seconds` of game time.
##
## Anything the GAME measures in seconds -- a hold-to-activate prompt, a charge,
## a channel -- must be driven this way. The window here is uncapped, so a hold
## counted in frames is a hold of unknown duration, and a director written that
## way passes or fails depending on how busy the machine is.
##
## Counted on THE CLOCK THE RECEIVER COUNTS ON, which is the scaled process
## delta: every hold in the game is a `_hold += delta` in someone's `_process`
## (`Prompt._process`, `TradeScreen._tick_input`). This used to be a timer built
## with `ignore_time_scale = true`, so a hold that overlapped a hit-stop --
## `Feel.hitstop` sets `Engine.time_scale = 0` -- spent its whole budget of real
## seconds while the gauge it was filling did not move at all. The two clocks
## agree at time_scale 1, which is why it survived: the disagreement only shows
## up in the beats that are hardest to reproduce.
##
## The wall-clock cap is a WATCHDOG and not the measurement. A game clock that
## has stopped for good would otherwise hang the harness with no output at all,
## which is the worst thing a capture rig can do; this says so and moves on.
func hold_seconds(actions: Array, seconds: float) -> void:
	await process_frame
	for a in actions:
		_send(a, true)
	var spent := 0.0
	var deadline := Time.get_ticks_msec() + int(seconds * 4000.0) + 3000
	while spent < seconds:
		await process_frame
		spent += root.get_process_delta_time()
		if Time.get_ticks_msec() >= deadline:
			print(("shoot: HELD %s for %.2f s of game time out of %.2f before the"
				+ " wall clock ran out -- the game is not advancing"
				+ " (Engine.time_scale=%.2f, paused=%s)")
				% [actions, spent, seconds, Engine.time_scale, paused])
			break
	for a in actions:
		_send(a, false)


## The `DialogueBox` that is up, or null.
##
## Found by DUCK TYPING and never by class. This file is loaded with `-s`, where
## a named `class_name` is compiled before the autoloads exist and takes the whole
## harness down with it (see `draw_weapon`) -- so the box's five reader methods are
## the interface, and `choice_labels` is the one this looks for.
func dialogue() -> Node:
	var stack: Array[Node] = [current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null:
			continue
		# A box that has already been closed does not count. `close()` is a
		# `queue_free`, so the node is still a child for the rest of the frame --
		# and a director that sees it there presses `interact` at it ONE MORE TIME.
		# That press lands a frame later, when the block has come off and the
		# keeper has the button back, and re-opens the conversation that was just
		# ended. It reads as "the box would not go away".
		#
		# Asked of the ANCESTORS and not just the node: the box frees its own
		# CanvasLayer, so the flag is on the parent and the box itself answers no.
		if n.has_method(&"choice_labels") and n.has_method(&"is_choosing") \
				and not _dying(n):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


## True if `n` or anything above it is on its way out of the tree this frame.
func _dying(n: Node) -> bool:
	var at: Node = n
	while at != null:
		if at.is_queued_for_deletion():
			return true
		at = at.get_parent()
	return false


## Hold the conversation that a press just opened, and pick `option` off the end
## of it. Answers false if there was never a box, if it never offered options, or
## if `option` is not one of them.
##
## Every director that addresses a counter needs this and needs it identically:
## since 2026-08-10 `interact` on a keeper opens a `DialogueBox`, and the shop is
## behind the Trade option rather than behind the press. One implementation here
## rather than the same eight-line dance pasted into seven directors -- and it is
## driven with real presses (`tap`), not by calling the box's own methods, because
## a director that reaches into a screen is testing the screen's fields and not
## its buttons.
func talk(option: String = "Trade", seconds: float = 6.0) -> bool:
	# Polled by hand rather than through `until`, because the thing being waited
	# for is also the thing being FETCHED: a GDScript lambda captures a local by
	# value, so a closure assigning `box` would leave it null out here.
	var box: Node = dialogue()
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while box == null and Time.get_ticks_msec() < deadline:
		await process_frame
		box = dialogue()
	if box == null:
		print("shoot: talk('%s') -- nothing opened a dialogue box" % option)
		return false

	# Turn pages until the question is on screen. The cap is a runaway guard, not
	# a page count: two presses per page (fill the line, then turn it). It was 16 —
	# eight pages — while every conversation in the game was one sentence long.
	# `StoryDb` beats are up to nine pages (the elder's briefing), so a cap that
	# tight now reads as "the box never offered any options" the first time a
	# director meets somebody who has something to say.
	for i in 64:
		if not is_instance_valid(box) or box.is_choosing():
			break
		await tap(["interact"])
		await _wait_frames(2)
	if not is_instance_valid(box):
		print("shoot: talk('%s') -- the box closed before it offered anything" % option)
		return false
	if not box.is_choosing():
		print("shoot: talk('%s') -- the box never offered any options" % option)
		return false

	var labels: PackedStringArray = box.choice_labels()
	var want := -1
	for i in labels.size():
		if labels[i] == option:
			want = i
	if want < 0:
		print("shoot: talk('%s') -- the options were %s" % [option, labels])
		return false

	# Walked with the stick, one row at a time, the way a pad player reaches it.
	for i in labels.size():
		if box.choice_index() == want:
			break
		await tap(["ui_down"])
		await _wait_frames(2)
	if box.choice_index() != want:
		print("shoot: talk('%s') -- the cursor would not land on it" % option)
		return false

	await tap(["interact"])
	await _wait_frames(4)
	return true


## Make the frame reproducible, for any director that subtracts one capture from
## another. Call it once, after the scene is built, before the first pair.
##
## **`Engine.time_scale = 0` is not enough and never was — CLAUDE.md §3 has the
## row.** Card #62 shot the same frozen dungeon twice and diffed it, and two
## things move in a world that has stopped:
##
##  1. **The volumetric fog.** Godot reprojects it from the previous frame with a
##     per-frame jitter, so it never converges: 74k px of a 921k frame differ
##     between two captures of a stopped scene. At native that is a delta of
##     **1/255** and no director's threshold sees it — but §4.5's internal buffer
##     quantizes to RGB555, one step of which is 8/255, so the same sub-LSB
##     jitter lands on the wrong side of a step and **2.6k px cross the 0.02 both
##     `echo_plates.gd` and `world_labels.gd` call ink**, on a floor where a
##     failing beat is 93 px. `internal_render` defaults to FALSE as of 2026-08-11,
##     so this is now the hazard a director hits only when it turns §4.5 on
##     itself — which `frame_repro.gd` and `fog_crawl.gd` both do.
##  2. **The flames**, historically. `KitTorch` read the wall clock; it
##     accumulates game time as of card #45, so the freeze now holds them. The
##     `flicker = 0` below is belt and braces for a director that photographs a
##     pair WITHOUT stopping the world, and it is what `echo_plates.gd` and
##     `room_range.gd` each used to keep a private copy of.
##
## Both are set for the rest of the process. Nothing here is worth restoring: a
## harness run ends at the last capture, and a director that wants the fog's
## temporal filter back is a director measuring something this cannot help with.
func still_the_frame() -> void:
	var fires := 0
	var airs := 0
	for n in _walk(root):
		if n is KitTorch:
			n.set(&"flicker", 0.0)
			# The setter runs `_apply_light`, which is the only thing that puts
			# the nominal energy back after `_process` has been multiplying it.
			n.set(&"light_energy", n.get(&"light_energy"))
			fires += 1
		elif n is WorldEnvironment:
			var env: Environment = (n as WorldEnvironment).environment
			if env != null:
				env.volumetric_fog_temporal_reprojection_enabled = false
				airs += 1
	print("shoot: still_the_frame -- %d flame(s) held, %d fog volume(s) "
		% [fires, airs] + "un-reprojected (see CLAUDE.md §3)")


func _walk(from: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## The live scene root.
func scene() -> Node:
	return current_scene


func out_base() -> String:
	return _args.get("out", "/tmp/shot.png")


func arg(name: String, fallback: String = "") -> String:
	return _args.get(name, fallback)


# --- internals --------------------------------------------------------------

func _wait_frames(n: int) -> void:
	for i in maxi(n, 1):
		await process_frame


func _out_dir() -> String:
	return out_base().get_base_dir()


func _indexed_out(i: int, total: int) -> String:
	var base := out_base()
	if total <= 1:
		return base
	var stem := base.get_basename()
	return "%s_%02d.%s" % [stem, i, base.get_extension()]
