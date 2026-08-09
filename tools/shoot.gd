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

var _args := {}
var _out_paths: Array[String] = []


func _initialize() -> void:
	_parse_args()

	var seed_val := int(_args.get("seed", "20190920"))
	seed(seed_val)
	_deafen_the_gamepad()

	var size_str: String = _args.get("size", "1280x720")
	var wh := size_str.split("x")
	var win_size := Vector2i(int(wh[0]), int(wh[1]))
	root.content_scale_size = win_size
	root.size = win_size
	# Park the window off in a corner so bursts of captures don't strobe the
	# user's desktop any more than they have to.
	root.position = Vector2i(40, 40)

	_run.call_deferred()


## Strip every joypad binding out of the InputMap for the life of this run.
##
## A controller plugged into the machine running the harness is an INPUT SOURCE
## the director does not control. This cost a long afternoon: a stick resting
## just outside its deadzone reported `move_up`, `move_right`, `cam_down` and
## `cam_left` held, the hero walked away from the town gate mid-hold, `Prompt`
## dropped focus, and the director reported five economy failures for a gate
## that had simply not been reached. It was intermittent because the drift
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


func _run() -> void:
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
		var director_script := load(director_path) as GDScript
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
func wait_frames(n: int) -> void:
	await _wait_frames(n)


## Wait n seconds of game time.
func wait_seconds(s: float) -> void:
	await create_timer(s).timeout


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


## Hold actions for `seconds` of game time.
##
## Anything the GAME measures in seconds -- a hold-to-activate prompt, a charge,
## a channel -- must be driven this way. The window here is uncapped, so a hold
## counted in frames is a hold of unknown duration, and a director written that
## way passes or fails depending on how busy the machine is.
func hold_seconds(actions: Array, seconds: float) -> void:
	await process_frame
	for a in actions:
		if InputMap.has_action(a):
			Input.action_press(a)
	await create_timer(seconds, true, false, true).timeout
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
