extends SceneTree
## Headless-ish screenshot harness.
##
## Loads a scene, lets it settle, optionally runs a "director" script that can
## drive input / advance state, and writes PNG frames to disk. This is the only
## way the visual critics ever see the game, so it must be deterministic.
##
##   godot --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/dungeon/room_a.tscn \
##       --out=/tmp/shot.png \
##       --warmup=45 \
##       --size=1280x720
##
## Optional:
##   --director=res://tools/directors/combat.gd   script with `func run(rig)`
##   --burst=8 --burst-gap=6                      contact sheet of N frames
##   --seed=12345                                 deterministic RNG

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

var _args := {}
var _out_paths: Array[String] = []


func _initialize() -> void:
	_parse_args()

	var seed_val := int(_args.get("seed", "20190920"))
	seed(seed_val)
	_sandbox_the_settings()
	_deafen_the_gamepad()
	_hush_the_speakers()

	var size_str: String = _args.get("size", "1280x720")
	var wh := size_str.split("x")
	var win_size := Vector2i(int(wh[0]), int(wh[1]))
	root.content_scale_size = win_size
	root.size = win_size
	# Park the window off in a corner so bursts of captures don't strobe the
	# user's desktop any more than they have to.
	root.position = Vector2i(40, 40)

	_run.call_deferred()


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


func _run() -> void:
	_verify_sandbox()

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
			await director.run(self)
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
	quit(0)


# --- API available to director scripts -------------------------------------

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
## The timeout is REAL seconds on purpose: it is a watchdog, not a measurement.
## A game clock that has stopped is one of the things it exists to catch, so it
## cannot be counted on the game clock.
func until(test: Callable, seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while true:
		if test.call():
			return true
		if Time.get_ticks_msec() >= deadline:
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
		if InputMap.has_action(a):
			Input.action_press(a)
	await _wait_frames(frames)
	for a in actions:
		if InputMap.has_action(a):
			Input.action_release(a)


## Tap actions for a single frame.
func tap(actions: Array) -> void:
	await hold(actions, 2)


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
		if InputMap.has_action(a):
			Input.action_press(a)
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
		if InputMap.has_action(a):
			Input.action_release(a)


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
