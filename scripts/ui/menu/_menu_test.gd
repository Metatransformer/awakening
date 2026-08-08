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

@onready var menu: PauseMenu = $PauseMenu


func _ready() -> void:
	if seed_demo_saves:
		_seed_slots()
	if capture_mouse_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu.quit_to_title_requested.connect(
		func() -> void: print("MENU_TEST quit_to_title_requested"))
	menu.load_requested.connect(
		func(slot: int, dest: Dictionary) -> void:
			print("MENU_TEST load_requested slot=%d dest=%s" % [slot, dest]))


func _seed_slots() -> void:
	var restore_room := Saves.current_room
	var restore_scene := Saves.current_scene_path

	if bool(Saves.peek(0).get("empty", true)):
		_stage(5, 20, 137, 2, &"entrance_hall")
		Saves.save(0)
	if bool(Saves.peek(1).get("empty", true)):
		_stage(3, 12, 44, 1, &"west_corridor")
		Saves.save(1)

	Game.reset()
	Saves.current_room = restore_room
	Saves.current_scene_path = restore_scene
	Saves.active_slot = -1


func _stage(hearts: int, quarters: int, rupees: int, keys: int, room: StringName) -> void:
	Game.max_quarters = hearts * K.HEART
	Game.quarters = quarters
	Game.rupees = rupees
	Game.small_keys = keys
	Game.grant(&"bombs")
	Game.grant(&"bow")
	Saves.current_room = room
	Saves.current_scene_path = "res://scenes/rooms/proving_ground.tscn"
