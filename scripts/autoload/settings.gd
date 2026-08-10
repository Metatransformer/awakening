extends Node
## Autoload `Settings`. Persistent player preferences: audio, graphics, controls.
##
## Lives in user://settings.cfg. Everything here applies immediately when set —
## the options UI just calls the setters and never touches AudioServer, the
## window, or the InputMap itself.
##
## The menu package owns the UI; this owns the truth and the persistence.

const DEFAULT_PATH := "user://settings.cfg"

## Bump this whenever the SHIPPED input layout in project.godot changes.
##
## Saved binds are replayed over the InputMap at boot and win, which means a
## stale `user://settings.cfg` silently outranks the layout the game ships. That
## is not hypothetical: a menu test once left `attack` on the N key with the
## mouse binding erased and the sword was dead on the owner's machine until
## somebody dumped the InputMap at runtime and found it. It happened again when
## the pad layout was renumbered -- the saved pad binding pinned `attack` to the
## old index, so the fix appeared not to work.
##
## A rebind is a preference about a layout. Change the layout and the preference
## no longer refers to anything, so it is dropped rather than replayed. Losing a
## custom bind on a layout change is a small, visible cost; shipping a build
## whose controls are quietly overridden is not.
##
## 3: attack moved RB -> A, interact A -> Y, shield LB -> left trigger (an AXIS,
##    not a button), and `heavy_attack` was added on X. A saved layout from 2
##    would pin attack back onto RB and leave the new A binding dead — which is
##    the second failure described above, verbatim.
## 4: attack moved A -> X, `heavy_attack` was DELETED (the heavy is now X held
##    rather than a button of its own), and `use_item` took the vacated A. A
##    saved layout from 3 is the worst case this const exists for: it would put
##    attack back on A, on top of use_item, so one press would swing the sword
##    and fire the hookshot at once.
## 5: the left trigger became the camera button -- `z_target` gained it, which
##    is OOT's Z -- so `shield` moved off the trigger and onto LB. `inventory`
##    was added on I / Select. A saved layout from 4 would put the guard back on
##    the trigger UNDERNEATH the recentre, so pulling LT to look behind you
##    would also raise the shield and freeze the hero's facing: two verbs, one
##    finger, and no way for the player to tell which one they asked for.
## 6: 5 undone. The split it describes was the mistake -- the guard, the lock and
##    the recentre are ONE intention and OOT put them on one button, so `shield`
##    took the left trigger back and `z_target` gave it up (it keeps R3). A saved
##    layout from 5 is the same collision as above with the roles reversed:
##    `shield` pinned to LB, so the trigger would target and recentre while the
##    guard sat on a bumper nobody was told about.
## 7: the BOTW pass. `use_item` moved A -> RT (an AXIS), which made the triggers
##    a pair -- left holds a stance, right fires what it is aimed at -- and
##    `interact` took the A it vacated. A saved layout from 6 would put use_item
##    back on A on top of interact, which is the exact collision the move was
##    made to remove: one press at a chest would open it and loose an arrow
##    through it.
## 8: `jump` was ADDED (Space, Y/Triangle) and `context` gave up Space for Shift
##    to make room for it. A saved layout from 7 is the collision this const is
##    for, and it is a nasty one because both halves still "work": Space would
##    come back on the dodge while `jump` kept it too, so one press would roll
##    the hero and launch him at the same time, and the pad's Y would sit there
##    doing nothing because 7 had nothing bound to it. Discarding is correct.
## 9: R3 changed hands. `z_target` gave up button 8 -- the left trigger is the
##    pad's Z and a second pad route to the same lock was a duplicate -- and
##    `first_person` took it, in the commit that built the mode. A saved layout
##    from 8 would hand R3 back to `z_target` AND leave `first_person` on it, so
##    one click would lock on and drop into the hero's head together.
## 10: `context` moved B -> A, onto the button `interact` already had, and B was
##     left holding nothing but `ui_cancel`. A saved layout from 9 is the quiet
##     kind of stale: everything would still "work", because the dodge would
##     simply be back on B and A would still talk — so the player would never
##     see a dead button, they would just never get the layout the game now
##     documents, and every prompt the HUD draws would name a button that does
##     something else. Discarding is correct.
## 11: THE SHOULDER PASS, and it moves or renames more than any entry above.
##     `attack` X -> RB. `use_item` was RENAMED to `heavy` and kept RT, gaining
##     the heavy swing, the charge and the jump attack. `context` A -> B.
##     `interact` kept A and lost everything else. `sheathe` was ADDED on X.
##     `item_left` / `item_right` were REPLACED by `loadout_prev` /
##     `loadout_next` on the same two D-pad directions.
##     A saved layout from 10 is the worst case this const has ever had to
##     catch, because most of it would still "work": the sword would be back on
##     X while RB did nothing, the dodge would be back on top of `interact` on A
##     with the arbitration that used to resolve it now deleted, and the two
##     renamed actions would simply not be in the file at all -- so the D-pad
##     would cycle nothing and the trigger would keep the item half of a button
##     that is now the whole sword. Discarding is correct.
## 12: the D-pad became CYCLES and the binding system was deleted. 11's
##     `loadout_prev` / `loadout_next` became `weapon_prev` / `weapon_next` on
##     the same two directions but stepping the RIGHT HAND through the weapons
##     you own; `item_up` became `loadout_swap`; `item_down` became `item_next`;
##     and 11's `sheathe` on X became `use_item` -- drink the selected bottle --
##     because with the sword a stop on the weapon ring there is nothing left to
##     sheathe. Five of the eleven names in 11 do not exist any more.
##     A saved layout from 11 is the FIRST one where discarding is obviously
##     right rather than arguably right: five actions would be missing outright,
##     so five of the game's inputs would be unbound on a pad that looks fully
##     configured. The interesting half is X -- a stale binding there would put
##     `sheathe` on it, an action nothing reads, so the player's flask button
##     would be silent in the fight they bought the flask for.
const BIND_SCHEMA := 12

## Where preferences persist. A test or a screenshot director that rebinds keys
## MUST NOT write to the player's real settings — an earlier menu test left
## `attack` bound to N in the shipped config, and the game booted with a dead
## sword button until it was found. Pass `--settings=user://scratch.cfg` after
## the `--` separator to sandbox a run.
##
## THAT WAS ONCE ADVICE AND IT WAS NOT ENOUGH: the same director did it a second
## time, because a doc comment asking every future harness to remember a flag is
## not a mechanism. `shoot.gd` now sets `HARNESS_META` before the autoloads are
## ready and this reads it, so a harness run is sandboxed whether or not its
## author thought about it. An explicit `--settings=` still wins over both.
##
## The second round did more damage than the first, and the reason is worth
## keeping: shoot.gd strips every joypad binding out of the InputMap for the
## life of a run (its own §"deafen the gamepad"). A rebind under the harness
## therefore serialises an action whose pad event is ALREADY GONE, and
## `apply_binds` erases before it replays — so one keyboard rebind in a menu
## test silently unbound RB from `attack` in the player's real config, for good.
## Sandboxing the file is what makes that unreachable.
var path: String = DEFAULT_PATH

## Set by `tools/shoot.gd` in `_initialize()` — i.e. before any autoload's
## `_ready` — to the scratch config a harness run should write instead of the
## player's. On `Engine` rather than a global because Settings is itself an
## autoload: there is no node to read at that point in the boot.
const HARNESS_META := &"zl_harness_settings_path"

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


## True while the player is on a gamepad. Not a preference and never saved — it
## is what they touched last, and it decides which button every on-screen prompt
## names. See `_input` for why the two thresholds below exist.
var using_pad: bool = false

## Stick travel before a joypad axis counts as the player MOVING it. A resting
## stick reports motion events forever — that is the drift documented in
## CLAUDE.md §3 that once walked the hero out of a director run — and at a lower
## threshold a pad merely plugged in would flip every prompt on the HUD while
## the player was typing.
const PAD_MOTION_WAKE := 0.5
## Pixels of mouse travel before the mouse counts as being used. The camera
## captures the pointer, so a desk bump is not the player choosing a keyboard.
const MOUSE_WAKE := 3.0


func _ready() -> void:
	# Order matters: the harness default is applied first so that an explicit
	# `--settings=` on the command line still overrides it.
	if Engine.has_meta(HARNESS_META):
		path = str(Engine.get_meta(HARNESS_META))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings="):
			path = arg.substr(11)
	# The device watcher has to keep running while the menu has the tree paused:
	# the pause screen is exactly where a player switches to a pad, and a paused
	# node is not offered input at all.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	load_settings()
	apply_all()
	# A pad already connected at boot is the likeliest single-controller case —
	# somebody who plays on a pad plugged it in before launching. Start there and
	# let the first keypress say otherwise.
	using_pad = not Input.get_connected_joypads().is_empty()


## Watch what the player is actually touching.
##
## `_input`, not `_unhandled_input`: this is an observer, and half the inputs it
## cares about are consumed before they reach the unhandled path — `Targeting`
## eats the lock-on button, the camera eats mouse motion, and the menu eats
## everything while it is open.
func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > PAD_MOTION_WAKE:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_WAKE:
			pad = false
	if pad == using_pad:
		return
	using_pad = pad
	Bus.input_device_changed.emit(pad)


# --- Persistence ------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
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

	# Binds from an older layout are discarded, not replayed. See BIND_SCHEMA.
	var schema: int = int(cfg.get_value("controls", "schema", 1))
	if schema == BIND_SCHEMA:
		_binds = cfg.get_value("controls", "binds", {})
	else:
		var stale: Dictionary = cfg.get_value("controls", "binds", {})
		if not stale.is_empty():
			print("Settings: dropping %d rebind(s) saved against input layout v%d (now v%d): %s"
				% [stale.size(), schema, BIND_SCHEMA, ", ".join(PackedStringArray(stale.keys()))])
		_binds = {}
		save_settings()


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

	cfg.set_value("controls", "schema", BIND_SCHEMA)
	cfg.set_value("controls", "binds", _binds)
	cfg.save(path)


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
	# Only touch the window mode if it is actually wrong. On macOS a
	# window_set_mode call pumps the OS event queue, which runs a NESTED main
	# loop iteration -- and if that happens during an autoload's _ready, other
	# scripts get resumed while the scene tree root is still mid-setup. That
	# broke tools/shoot.gd for every capture. Re-asserting a mode the window is
	# already in is pure cost, so the guard removes the hazard at boot without
	# changing what the settings menu can do.
	var mode := DisplayServer.window_get_mode()
	if fullscreen:
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		# Only leave fullscreen. MAXIMIZED is the project's default launch mode
		# (window/size/mode=2) and is a perfectly good "not fullscreen" -- forcing
		# WINDOWED here shrank the window on every single boot.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
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
		&"z_target", &"attack", &"heavy", &"shield", &"context", &"interact",
		&"use_item", &"jump", &"weapon_prev", &"weapon_next", &"item_next",
		&"loadout_swap", &"first_person",
		&"pause", &"inventory", &"map",
	]


## Rebind `action` to `event`, replacing only bindings of the SAME KIND —
## rebinding a key must not silently drop the gamepad binding, and vice versa.
## Returns false if that input is already taken by another rebindable action;
## the UI is expected to say so rather than fail silently.
func rebind(action: StringName, event: InputEvent) -> bool:
	for other in rebindable_actions():
		if other == action:
			continue
		for e in InputMap.action_get_events(other):
			if e.is_match(event, true):
				return false
	for e in InputMap.action_get_events(action):
		if _same_device_class(e, event):
			InputMap.action_erase_event(action, e)
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


## Keyboard and mouse are one class (what a keyboard player rebinds); joypad
## buttons and axes are the other. A rebind only displaces its own class.
func _same_device_class(a: InputEvent, b: InputEvent) -> bool:
	var a_pad := a is InputEventJoypadButton or a is InputEventJoypadMotion
	var b_pad := b is InputEventJoypadButton or b is InputEventJoypadMotion
	return a_pad == b_pad


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
