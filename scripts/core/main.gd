class_name Main
extends Node
## The loop's spine. Owns the hero, the camera and the HUD — all of which
## persist — and swaps exactly one world child underneath them: Town or Dungeon.
##
## The hero surviving the swap is the point. A hero rebuilt per world would need
## his gear, health and bag re-applied on every transition, and one missed field
## is a silent loss of the player's run. Here the hero is simply moved.

const HERO_SCENE := "res://scenes/actors/hero/hero.tscn"
const CAMERA_SCENE := "res://scenes/camera/game_camera.tscn"

var hero: Hero = null
var camera: GameCamera = null
var hud: Hud = null
var world: Node3D = null

var _dungeon: Dungeon = null


func _ready() -> void:
	_build_hero()
	_build_camera()
	_build_hud()

	Bus.run_ended.connect(_on_run_ended)
	hero.hurt.connect(_on_hero_hurt)

	# Deferred: the world is a big subtree, and building it inside our own
	# _ready means adding it while this node is itself still being added.
	enter_town.call_deferred()


func _build_hero() -> void:
	hero = (load(HERO_SCENE) as PackedScene).instantiate() as Hero
	add_child(hero)


func _build_camera() -> void:
	camera = (load(CAMERA_SCENE) as PackedScene).instantiate() as GameCamera
	# The camera finds the hero itself, by group or by `player_spawned`. It is
	# added second on purpose so the group lookup in its _ready already resolves.
	add_child(camera)


func _build_hud() -> void:
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)


# --- World swapping ---------------------------------------------------------

func _clear_world() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null
	_dungeon = null


func enter_town() -> void:
	_clear_world()
	var town := Town.new()
	town.name = "Town"
	add_child(town)
	# The world must sort BEFORE the hero so the hero's _process (and the
	# camera's, which reads his transform) runs on a world that already exists.
	move_child(town, 0)
	world = town

	town.vendor_opened.connect(func() -> void: hud.open_vendor())
	town.smith_opened.connect(func() -> void: hud.open_smith())
	town.gate_entered.connect(_on_gate_entered)

	hero.global_position = Town.SPAWN
	hero.velocity = Vector3.ZERO
	hud.set_context(false)


func _on_gate_entered() -> void:
	if hud.is_panel_open():
		return
	enter_dungeon()


func enter_dungeon() -> void:
	Game.start_run()
	_clear_world()
	var dungeon := Dungeon.new()
	dungeon.name = "Dungeon"
	add_child(dungeon)
	move_child(dungeon, 0)
	world = dungeon
	_dungeon = dungeon
	dungeon.begin(hero)
	hud.set_context(true)


func _on_hero_hurt(_hit: Hit) -> void:
	if _dungeon != null and is_instance_valid(_dungeon):
		_dungeon.on_hero_hurt()


func _on_run_ended(reason: StringName, rooms: int) -> void:
	# Deferred: run_ended can fire from inside the dungeon's own signal handling,
	# and freeing a node mid-signal is how you get a use-after-free.
	call_deferred("_return_to_town", reason, rooms)


func _return_to_town(reason: StringName, rooms: int) -> void:
	enter_town()
	hud.show_run_summary(reason, rooms)
