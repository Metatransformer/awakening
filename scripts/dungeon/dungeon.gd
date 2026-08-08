class_name Dungeon
extends Node3D
## A run. Owns the floor plan, builds exactly ONE room at a time, and owns the
## two ways out.
##
## One room in memory is a deliberate choice, not a budget compromise: rooms are
## sealed until cleared anyway, so nothing off-screen needs to be simulated, and
## it keeps a twelve-room run as cheap as a single room to render.
##
## The two exits are the design (docs/METAGAME.md §6):
##   * the **portal** in the entrance room, free, but you have to walk back;
##   * the **pendant** (`item_up`), instant, priced by depth, and channelled so
##     it cannot be used to escape a fight already going badly.

signal room_changed(cell: Vector2i, index: int)

@export var room_count: int = 12
## Ingredients that hit the floor when the bag is full stay put — but a room
## unload would delete them silently. Carry them to the next room instead? No:
## they are LOST, and the player should learn that. See `_on_exit_taken`.
@export var warn_on_leaving_loot: bool = true

var map := DungeonMap.new()
var current_cell: Vector2i = Vector2i.ZERO
var room: DungeonRoom = null

var _hero: Node3D = null
var _channel: float = -1.0
var _channel_from: Vector3 = Vector3.ZERO
## True while the extract key is held but the channel was refused, so the
## refusal is stated once rather than once per frame.
var _refused: bool = false


func _ready() -> void:
	add_to_group(&"dungeon")
	# On the Dungeon and not on the room: rooms are destroyed and rebuilt as you
	# walk, and an environment that blinks out for a frame on every doorway is
	# a visible flash of the engine's default grey.
	var we := WorldEnvironment.new()
	we.environment = load("res://assets/materials/env_dungeon.tres") as Environment
	add_child(we)

	var s: int = Game.run_seed if Game.run_seed != 0 else randi()
	map.generate(s, room_count)
	if not map.all_reachable():
		push_warning("Dungeon: generated a floor plan with unreachable rooms (seed %d)" % s)
	Bus.player_died.connect(_on_player_died)


## Called by Main once the hero exists, so the room can place him.
func begin(hero: Node3D) -> void:
	_hero = hero
	_enter(map.entrance, -1)


# --- Rooms ------------------------------------------------------------------

func _enter(cell: Vector2i, from_dir: int) -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
		room = null

	current_cell = cell
	var data: Dictionary = map.room_at(cell)
	var first_visit: bool = not bool(data.get("visited", false))
	data["visited"] = true

	room = DungeonRoom.new()
	room.name = "Room_%d_%d" % [cell.x, cell.y]
	# Seed per cell so re-entering a room rebuilds it identically — a chest that
	# moves when you walk back through is worse than no chest at all.
	room.setup(data, cell, hash(Vector2i(cell.x, cell.y)) ^ Game.run_seed)
	room.exit_taken.connect(_on_exit_taken)
	room.room_cleared.connect(_on_room_cleared.bind(cell, first_visit))
	add_child(room)

	if _hero != null:
		# Arriving from direction d means walking IN through the door on the
		# opposite side of the new room.
		var side: int = DungeonMap.opposite(from_dir) if from_dir >= 0 else DungeonMap.Dir.S
		_hero.global_position = room.entry_point(side)
		if _hero is CharacterBody3D:
			(_hero as CharacterBody3D).velocity = Vector3.ZERO

	if cell == map.entrance:
		_build_portal()

	room_changed.emit(cell, int(data.get("index", 0)))


func _on_exit_taken(dir: int) -> void:
	var next: Vector2i = current_cell + DungeonMap.DELTA[dir]
	if not map.has(next):
		return
	_cancel_channel(&"moved")
	_enter(next, dir)


func _on_room_cleared(cell: Vector2i, first_visit: bool) -> void:
	# Only the FIRST clear counts toward depth. Otherwise walking back and forth
	# would inflate both the band and the extraction fee for free.
	if first_visit and cell != map.entrance:
		Game.room_cleared()


# --- The free way out -------------------------------------------------------

func _build_portal() -> void:
	var portal := Area3D.new()
	portal.name = "ExitPortal"
	portal.collision_layer = K.L_INTERACT
	portal.collision_mask = K.L_PLAYER
	portal.position = Vector3(0, 1.0, 0)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.5
	shape.height = 2.6
	col.shape = shape
	portal.add_child(col)

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.45
	cyl.height = 2.4
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.42, 0.78, 1.0, 0.20)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.82, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	portal.add_child(mesh)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.5, 0.8, 1.0)
	lamp.light_energy = 3.0
	lamp.omni_range = 7.0
	portal.add_child(lamp)

	room.add_child(portal)
	portal.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group(&"player"):
			_leave(false))


# --- The paid way out -------------------------------------------------------

## Polled, not event-driven. "Hold this down for three seconds" is a state, and
## reading it as a state means one place decides whether the channel is alive
## instead of two edge handlers that can disagree.
func _poll_channel() -> void:
	var held := Input.is_action_pressed(&"item_up")
	if not held:
		_refused = false
		if _channel >= 0.0:
			_cancel_channel(&"released")
		return
	if _channel < 0.0 and not _refused:
		_begin_channel()


func _begin_channel() -> void:
	if _channel >= 0.0 or _hero == null:
		return
	var fee := Game.extract_fee()
	if not Game.can_afford_extract():
		# Latch, or the refusal message reprints every frame the key is down.
		_refused = true
		Bus.request_message.emit("The pendant needs %d gold. You have %d." % [fee, Game.gold])
		return
	_channel = 0.0
	_channel_from = _hero.global_position
	Bus.extraction_started.emit(fee)


func _cancel_channel(why: StringName) -> void:
	if _channel < 0.0:
		return
	_channel = -1.0
	Bus.extraction_cancelled.emit(why)


func _process(delta: float) -> void:
	if not Game.in_dungeon:
		return
	_poll_channel()
	if _channel < 0.0 or _hero == null:
		return
	# Standing still is the whole condition. A pendant you can run with turns
	# every bad fight into a free escape and the depth decision stops existing.
	if _hero.global_position.distance_to(_channel_from) > 0.6:
		_cancel_channel(&"moved")
		return
	_channel += delta
	Bus.extraction_progress.emit(clampf(_channel / K.EXTRACT_CHANNEL, 0.0, 1.0))
	if _channel >= K.EXTRACT_CHANNEL:
		_channel = -1.0
		_leave(true)


## A hit breaks the channel. Wired by Main, which owns the hero.
func on_hero_hurt() -> void:
	_cancel_channel(&"hurt")


# --- Ending the run ---------------------------------------------------------

func _leave(paid: bool) -> void:
	if not Game.in_dungeon:
		return
	Game.end_run_extracted(paid)


func _on_player_died() -> void:
	if not Game.in_dungeon:
		return
	_cancel_channel(&"died")
	Game.end_run_died()
