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

	var size_str: String = _args.get("size", "1280x720")
	var wh := size_str.split("x")
	var win_size := Vector2i(int(wh[0]), int(wh[1]))
	root.content_scale_size = win_size
	root.size = win_size
	# Park the window off in a corner so bursts of captures don't strobe the
	# user's desktop any more than they have to.
	root.position = Vector2i(40, 40)

	_run.call_deferred()


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

	# Deferred, and then waited on. A direct `root.add_child()` here can land
	# while root is busy setting up its own children; it fails with "parent is
	# busy setting up children", `current_scene` never gets set, and the whole
	# shot silently becomes a black frame with no scene in it.
	var instance := packed.instantiate()
	var tries := 0
	while instance.get_parent() == null:
		root.add_child.call_deferred(instance)
		await process_frame
		tries += 1
		if tries > 60:
			push_error("shoot.gd: could not parent the scene to root")
			quit(5)
			return
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
func hold(actions: Array, frames: int) -> void:
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
