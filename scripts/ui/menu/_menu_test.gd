extends Node3D
## Harness for `res://scenes/ui/menu/_menu_test.tscn` — the pause menu over a
## scrap of torch-lit dungeon, with nothing else in the project running.
##
## It exists so the menu can be screenshotted and driven by a director without
## the hero, the camera rig or the dungeon being finished
## (docs/CONTRACT.md §9).

## Fill slots 1 and 2 with a plausible run so the save screen has something to
## draw. Only ever writes slots that are already EMPTY — a real save is never
## clobbered by opening this scene.
@export var seed_demo_saves: bool = true
## Capture the pointer first, the way the camera rig will, so opening the menu
## has something to release and closing it has something to restore.
@export var capture_mouse_on_start: bool = false

## The autoload instance, not a local one. This scene used to instance its own
## pause_menu.tscn, which is how the project ended up with a menu that existed
## only here: the harness had one, the game had none. There is now exactly one
## PauseMenu in the project and this harness drives it.
@onready var menu: PauseMenu = Menu


func _ready() -> void:
	if seed_demo_saves:
		_seed_slots()
	if capture_mouse_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The instance carried `open_on_ready`; the autoload boots closed for every
	# other scene, so this harness asks for it explicitly.
	menu.open.call_deferred()
	menu.quit_to_title_requested.connect(
		func() -> void: print("MENU_TEST quit_to_title_requested"))
	menu.load_requested.connect(
		func(slot: int, dest: Dictionary) -> void:
			print("MENU_TEST load_requested slot=%d dest=%s" % [slot, dest]))


func _seed_slots() -> void:
	var restore_room := Saves.current_room
	var restore_scene := Saves.current_scene_path

	if bool(Saves.peek(0).get("empty", true)):
		_stage(20, 20, 137, 2, &"entrance_hall")
		Saves.save(0)
	if bool(Saves.peek(1).get("empty", true)):
		_stage(12, 12, 44, 1, &"west_corridor")
		Saves.save(1)

	Game.reset()
	Saves.current_room = restore_room
	Saves.current_scene_path = restore_scene
	Saves.active_slot = -1


func _stage(max_health_points: int, health_points: int,
		rupees: int, keys: int, room: StringName) -> void:
	Game.max_health_points = max_health_points
	Game.health_points = health_points
	Game.rupees = rupees
	Game.small_keys = keys
	# `&"bombs"` for a while, which was never an item id at all -- the count was
	# `Game.bombs` and the OWNED thing was the bag. It granted nothing for as
	# long as it stood here. The working is a real id (`docs/GDD.md` §6.5).
	Game.grant(&"burst")
	Game.grant(&"bow")
	Saves.current_room = room
	Saves.current_scene_path = "res://scenes/rooms/proving_ground.tscn"
