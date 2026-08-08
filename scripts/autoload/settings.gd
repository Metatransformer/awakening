extends Node
## Autoload `Settings`. Persistent player preferences: audio, graphics, controls.
##
## Lives in user://settings.cfg. Everything here applies immediately when set —
## the options UI just calls the setters and never touches AudioServer, the
## window, or the InputMap itself.
##
## The menu package owns the UI; this owns the truth and the persistence.

const PATH := "user://settings.cfg"

signal changed(section: StringName, key: StringName, value: Variant)

# --- Audio (0.0 .. 1.0 linear, converted to dB on the way to the bus) -------
var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ui_volume: float = 0.8

# --- Graphics ---------------------------------------------------------------
## 0 = windowed, 1 = borderless fullscreen
var fullscreen: bool = false
var vsync: bool = true
var resolution_scale: float = 1.0  ## 0.5 .. 1.0, renders below native and upscales
var msaa: int = 2                  ## 0=off 1=2x 2=4x 3=8x
var shadow_quality: int = 2        ## 0=off 1=low 2=med 3=high
var fov_offset: float = 0.0        ## added to K.CAM_FOV, -10 .. +15

# --- Gameplay / accessibility ----------------------------------------------
var invert_camera_y: bool = false
var camera_sensitivity: float = 1.0
var rumble: bool = true
var camera_shake: float = 1.0      ## 0 disables shake entirely
var letterbox_on_target: bool = true

# --- Controls ---------------------------------------------------------------
## action name -> array of serialized InputEvents overriding the defaults.
var _binds: Dictionary = {}
## The InputMap as shipped, captured at boot so "reset to defaults" is honest.
var _defaults: Dictionary = {}


func _ready() -> void:
	_capture_defaults()
	load_settings()
	apply_all()


# --- Persistence ------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # first run: keep the defaults above
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	ui_volume = cfg.get_value("audio", "ui", ui_volume)

	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	resolution_scale = cfg.get_value("video", "resolution_scale", resolution_scale)
	msaa = cfg.get_value("video", "msaa", msaa)
	shadow_quality = cfg.get_value("video", "shadow_quality", shadow_quality)
	fov_offset = cfg.get_value("video", "fov_offset", fov_offset)

	invert_camera_y = cfg.get_value("game", "invert_camera_y", invert_camera_y)
	camera_sensitivity = cfg.get_value("game", "camera_sensitivity", camera_sensitivity)
	rumble = cfg.get_value("game", "rumble", rumble)
	camera_shake = cfg.get_value("game", "camera_shake", camera_shake)
	letterbox_on_target = cfg.get_value("game", "letterbox", letterbox_on_target)

	_binds = cfg.get_value("controls", "binds", {})


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ui", ui_volume)

	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "resolution_scale", resolution_scale)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "fov_offset", fov_offset)

	cfg.set_value("game", "invert_camera_y", invert_camera_y)
	cfg.set_value("game", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("game", "rumble", rumble)
	cfg.set_value("game", "camera_shake", camera_shake)
	cfg.set_value("game", "letterbox", letterbox_on_target)

	cfg.set_value("controls", "binds", _binds)
	cfg.save(PATH)


func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_binds()


# --- Audio ------------------------------------------------------------------

func set_volume(bus_name: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match bus_name:
		&"Master": master_volume = linear
		&"Music": music_volume = linear
		&"SFX": sfx_volume = linear
		&"UI": ui_volume = linear
	apply_audio()
	changed.emit(&"audio", bus_name, linear)
	save_settings()


func get_volume(bus_name: StringName) -> float:
	match bus_name:
		&"Master": return master_volume
		&"Music": return music_volume
		&"SFX": return sfx_volume
		&"UI": return ui_volume
	return 1.0


func apply_audio() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", sfx_volume)
	_set_bus(&"UI", ui_volume)


func _set_bus(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# A slider at 0 must be silence, not -60 dB of audible hiss.
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


# --- Video ------------------------------------------------------------------

func apply_video() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(resolution_scale, 0.5, 1.0)
		vp.msaa_3d = clampi(msaa, 0, 3) as Viewport.MSAA
		vp.positional_shadow_atlas_size = [0, 1024, 2048, 4096][clampi(shadow_quality, 0, 3)]
	# Directional shadows are a project setting, so they move via RenderingServer.
	RenderingServer.directional_shadow_atlas_set_size(
		[0, 2048, 4096, 8192][clampi(shadow_quality, 0, 3)], true
	)


# --- Controls ---------------------------------------------------------------

func _capture_defaults() -> void:
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		_defaults[action] = InputMap.action_get_events(action)


## Actions the options screen offers to rebind, in display order.
func rebindable_actions() -> Array[StringName]:
	return [
		&"move_up", &"move_down", &"move_left", &"move_right",
		&"z_target", &"attack", &"shield", &"context", &"interact",
		&"item_left", &"item_up", &"item_right", &"first_person",
		&"pause", &"map",
	]


## Replace every event on `action` with `event`. Returns false if that key is
## already taken by another rebindable action — the UI should say so.
func rebind(action: StringName, event: InputEvent) -> bool:
	for other in rebindable_actions():
		if other == action:
			continue
		for e in InputMap.action_get_events(other):
			if e.is_match(event, true):
				return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_binds[action] = _serialize(action)
	save_settings()
	changed.emit(&"controls", action, event)
	return true


func reset_binds() -> void:
	for action in _defaults:
		InputMap.action_erase_events(action)
		for e in _defaults[action]:
			InputMap.action_add_event(action, e)
	_binds.clear()
	save_settings()
	changed.emit(&"controls", &"*", null)


func apply_binds() -> void:
	for action in _binds:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d in _binds[action]:
			var e := _deserialize(d)
			if e:
				InputMap.action_add_event(action, e)


## Human-readable label for the first event on an action, for the options list.
func label_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode)
		if e is InputEventMouseButton:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "Mouse L"
				MOUSE_BUTTON_RIGHT: return "Mouse R"
				MOUSE_BUTTON_MIDDLE: return "Mouse M"
	return "—"


# ConfigFile cannot hold InputEvent objects, so binds round-trip as dictionaries.
func _serialize(action: StringName) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append({"t": "key", "c": (e as InputEventKey).physical_keycode})
		elif e is InputEventMouseButton:
			out.append({"t": "mb", "c": (e as InputEventMouseButton).button_index})
		elif e is InputEventJoypadButton:
			out.append({"t": "jb", "c": (e as InputEventJoypadButton).button_index})
		elif e is InputEventJoypadMotion:
			out.append({
				"t": "jm",
				"c": (e as InputEventJoypadMotion).axis,
				"v": (e as InputEventJoypadMotion).axis_value,
			})
	return out


func _deserialize(d: Dictionary) -> InputEvent:
	match d.get("t", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = d.get("c", 0)
			return k
		"mb":
			var m := InputEventMouseButton.new()
			m.button_index = d.get("c", 0)
			return m
		"jb":
			var j := InputEventJoypadButton.new()
			j.button_index = d.get("c", 0)
			return j
		"jm":
			var a := InputEventJoypadMotion.new()
			a.axis = d.get("c", 0)
			a.axis_value = d.get("v", 1.0)
			return a
	return null
