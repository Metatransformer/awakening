extends Node
## Autoload `Flow`. Owns the two scenes the game actually has and the fade
## between them.
##
## Town and dungeon are separate scenes rather than one streamed world because
## the transition IS the mechanic: extracting has to feel like arriving
## somewhere, and dying has to feel like waking up somewhere. A seamless walk
## between them would make both of those into a corridor.
##
## Nothing else calls `change_scene_to_file`. If a second caller appears, the
## fade stops being a guarantee and starts being a suggestion.

const TOWN := "res://scenes/rooms/town.tscn"
const DUNGEON := "res://scenes/rooms/dungeon.tscn"

const FADE_OUT := 0.35
const FADE_IN := 0.45
## Beat between the extract flash / death and the screen going dark, so the
## player sees the thing that happened to them.
const HOLD := 0.45

## True while a transition is in flight. Everything that could start another one
## checks this -- a second extract press during the fade would re-enter town.
var busy: bool = false

## The run that just ended, stashed for whoever arrives next. `run_ended` fires
## in the dungeon, during the fade, before the town exists -- so without this the
## only run result the player could ever see is one that ended in town.
## {"extracted": bool, "contents": Dictionary, "value": int}. Town clears it.
var last_result: Dictionary = {}

var _layer: CanvasLayer
var _veil: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	# Above the pause menu (100) and the HUD (50): a fade that something can draw
	# on top of is not a fade.
	_layer.layer = 200
	add_child(_layer)

	_veil = ColorRect.new()
	_veil.color = Color(Pal.VOID, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_veil)

	Bus.player_died.connect(_on_player_died)
	Bus.run_ended.connect(_on_run_ended)


# --- Entry points -----------------------------------------------------------

func enter_dungeon(run_seed: int = 0) -> void:
	if busy:
		return
	Run.enter(run_seed)
	_go(DUNGEON, 0.0)


func to_town() -> void:
	if busy:
		return
	_go(TOWN, 0.0)


## Take the stair down. The run CONTINUES: same bag, same health, same fee
## climbing. Only the floor is new.
##
## It reloads the same dungeon scene rather than loading a different one, which
## is what "endless" means here -- there is no floor 8 scene to run out of. The
## layout differs because `Run.descend_floor` moves the level and the generator
## seeds off `Run.floor_seed()`, so a given run seed still replays identically
## all the way down (scripts/world/dungeon.gd).
func descend() -> void:
	if busy or not Run.in_dungeon:
		return
	Run.descend_floor()
	_go(DUNGEON, 0.0)


# --- The two things that end a run ------------------------------------------

func _on_player_died() -> void:
	if busy:
		return
	if Run.in_dungeon:
		# Run.die clears the bag and emits run_ended(false), which is what
		# actually sends us home. Death does not know about scenes.
		Run.die()
	else:
		Game.heal(Game.max_quarters)


func _on_run_ended(extracted: bool, contents: Dictionary, value: int) -> void:
	last_result = {"extracted": extracted, "contents": contents, "value": value}
	if busy:
		return
	_go(TOWN, HOLD if extracted else HOLD * 1.6)


# --- Transition -------------------------------------------------------------

func _go(path: String, hold: float) -> void:
	busy = true
	Prompt.blocked = true
	if hold > 0.0:
		await get_tree().create_timer(hold, true, false, true).timeout

	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_veil, "color:a", 1.0, FADE_OUT)
	await tw.finished

	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Flow: could not load %s (%d)" % [path, err])
		busy = false
		Prompt.blocked = false
		_veil.color.a = 0.0
		return

	# One frame for the new scene's _ready to run, so the fade lifts on the
	# built world rather than on the old one's last frame.
	await get_tree().process_frame
	await get_tree().process_frame

	Prompt.blocked = false
	busy = false
	var tin := create_tween().set_ignore_time_scale(true)
	tin.tween_property(_veil, "color:a", 0.0, FADE_IN)
