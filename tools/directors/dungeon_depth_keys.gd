extends RefCounted
## Issue #199: expanded depth, combat-only bonus rooms, the guaranteed ordinary
## key detour, and sparse counted provisions.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/dungeon_depth_keys.gd \
##     --out=/tmp/depth-keys/x.png --warmup=60

const SEEDS: Array[int] = [199031, 199117, 199263]
const LEVELS: Array[int] = [1, 2, 3, 4, 5]
const PROVISIONS: Array[StringName] = [
	&"escape_rope", &"hardtack", &"small_beer",
]

var _fails := 0
var _out := ""


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/depth-keys/x.png").get_base_dir()
	if rig.scene().name != &"DungeonRun":
		_fail("wrong host scene; pass res://scenes/rooms/dungeon.tscn")
		return
	Game.reset()
	Run.enter(SEEDS[0])

	var plans := {}
	for seed_value: int in SEEDS:
		for level: int in LEVELS:
			var d := await _rebuild(rig, level, seed_value)
			if d == null:
				_fail("level %d seed %d did not build" % [level, seed_value])
				continue
			_validate_plan(d, level, seed_value)
			plans[Vector2i(level, seed_value)] = _snapshot(d)

	# Replay one complete five-floor run seed. Layout, loop and provision rooms
	# are all part of the snapshot, so equality is stronger than a room count.
	for level: int in LEVELS:
		var replay := await _rebuild(rig, level, SEEDS[0])
		var expected: String = plans.get(Vector2i(level, SEEDS[0]), "")
		_ck("level %d deterministic room/key/provision replay" % level,
			replay != null and _snapshot(replay) == expected)

	_validate_provision_stream()
	await _live_key_loop(rig)

	print("DEPTH_KEYS OK -- every check passed" if _fails == 0 \
		else "DEPTH_KEYS FAILED (%d)" % _fails)


func _validate_plan(d: Node, level: int, seed_value: int) -> void:
	var prefix := "L%d S%d" % [level, seed_value]
	var base := FloorDb.base_rooms(level)
	var bonus := FloorDb.combat_bonus(level)
	var total := FloorDb.rooms(level)
	_ck("%s base=%d bonus=%d total=%d" % [prefix, base, bonus, total],
		base == ([6, 8, 9, 10][level - 1] if level <= 4 else Prog.rooms(level))
		and bonus == int(ceil(float(base) * 0.30))
		and d.rooms.size() == total)

	var bonus_cells: Array[Vector2i] = []
	var anchor_cells := {}
	for id: StringName in d.placements:
		anchor_cells[d.placements[id]["cell"]] = true
	for cell: Vector2i in d.rooms:
		var row: Dictionary = d.rooms[cell]
		if not bool(row.get("combat_only", false)):
			continue
		bonus_cells.append(cell)
		var watch := row.get("watch") as RoomWatch
		_ck("%s bonus %s has live combat watch" % [prefix, cell],
			watch != null and watch.live_count() >= d.enemies_min
			and int(row.get("enemy_count", 0)) >= d.enemies_min)
		_ck("%s bonus %s excluded from anchors/maze/deepest" % [prefix, cell],
			cell != d.entrance and cell != d.deepest
			and not anchor_cells.has(cell)
			and (d.maze_reserved == null or d.maze_reserved != cell))
		var provision: StringName = row.get("provision", &"")
		_ck("%s bonus %s provision uses authored pool" % [prefix, cell],
			provision == &"" or PROVISIONS.has(provision))
		if provision != &"":
			var pickup := row.get("provision_node") as Node
			_ck("%s provision %s is staged on its watch" % [prefix, provision],
				pickup != null and bool(pickup.get(&"staged"))
				and not bool(pickup.call(&"is_revealed")))
	_ck("%s tagged exactly %d bonus rooms" % [prefix, bonus],
		bonus_cells.size() == bonus)

	var loop: Dictionary = d.key_loop
	_ck("%s has one public key loop" % prefix, not loop.is_empty())
	if loop.is_empty():
		return
	var shallow: Vector2i = loop["shallow"]
	var deep: Vector2i = loop["deep"]
	var key_cell: Vector2i = loop["key_cell"]
	var host: Vector2i = loop["key_host"]
	var route: Array = loop["baseline_path"]
	var shallow_i := route.find(shallow)
	_ck("%s lock is a non-entrance critical-path edge" % prefix,
		shallow != d.entrance and shallow_i >= 1
		and shallow_i + 1 < route.size() and route[shallow_i + 1] == deep)
	_ck("%s key room is an off-path combat leaf" % prefix,
		bool(d.rooms[key_cell].get("combat_only", false))
		and (d.rooms[key_cell]["doors"] as Array).size() == 1
		and d.rooms[key_cell]["parent"] == host and not route.has(key_cell))
	_ck("%s key detour is reachable before the lock" % prefix,
		not d.path_to(key_cell).has(deep))
	_ck("%s loop built one key, gate and watch" % prefix,
		loop.get("key") is SmallKey and loop.get("gate") is PuzzleGate
		and loop.get("watch") is RoomWatch)
	if not d.chord.is_empty():
		var near: Vector2i = d.chord["near"]
		var far: Vector2i = d.chord["far"]
		_ck("%s chord excludes bonus endpoints and lock bypass" % prefix,
			not bool(d.rooms[near].get("combat_only", false))
			and not bool(d.rooms[far].get("combat_only", false))
			and d._behind_key_lock(near) == d._behind_key_lock(far))


func _snapshot(d: Node) -> String:
	var ordered: Array[Dictionary] = []
	for cell: Vector2i in d.rooms:
		ordered.append({"cell": cell, "row": d.rooms[cell]})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["row"]["index"]) < int(b["row"]["index"]))
	var rows: Array[String] = []
	for entry: Dictionary in ordered:
		var row: Dictionary = entry["row"]
		rows.append("%s>%s:c%d:p%s" % [entry["cell"], row["parent"],
			1 if bool(row.get("combat_only", false)) else 0,
			String(row.get("provision", &""))])
	var loop: Dictionary = d.key_loop
	rows.append("K:%s:%s:%s:%s:%s" % [loop.get("tag", &""),
		loop.get("shallow", Vector2i.ZERO), loop.get("deep", Vector2i.ZERO),
		loop.get("key_host", Vector2i.ZERO), loop.get("key_cell", Vector2i.ZERO)])
	return "|".join(rows)


## Bounded direct sampling of the exact helper `_populate` calls. Two streams
## with the same seed must agree, and the sample must exercise all three authored
## ids; this catches both global randomness and a dead weighted row cheaply.
func _validate_provision_stream() -> void:
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var seen := {}
	var first: Array[StringName] = []
	var second: Array[StringName] = []
	for pass_i in 2:
		var d: Node = script.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 199199
		d._rng = rng
		var values: Array[StringName] = []
		for i in 320:
			var id: StringName = d._roll_provision()
			values.append(id)
			if id != &"":
				seen[id] = true
		if pass_i == 0:
			first = values
		else:
			second = values
	_ck("provision stream is deterministic", first == second)
	for id: StringName in PROVISIONS:
		_ck("bounded provision sample yields %s" % id, seen.has(id))


func _live_key_loop(rig) -> void:
	Game.flags.clear()
	Run.level = 1
	Game.set_small_keys_for_floor(1, 0, false)
	Game.set_small_keys_for_floor(2, 2, false)
	var d := await _rebuild(rig, 1, 199911)
	if d == null or d.key_loop.is_empty():
		_fail("live key-loop floor did not build")
		return
	var gate := d.key_loop["gate"] as PuzzleGate
	var key := d.key_loop["key"] as SmallKey
	var watch := d.key_loop["watch"] as RoomWatch
	var hero := _hero(rig)
	_ck("live loop starts with hidden disarmed key",
		key != null and not key.visible and not key.armed and not key.is_revealed())
	_ck("live loop starts on Atlas as a closed ordinary lock",
		gate != null and Atlas.locks.has(d.key_loop["tag"])
		and Atlas.locks[d.key_loop["tag"]]["kind"] == Atlas.LOCK_SMALL)
	gate.activate(hero)
	await rig.wait_frames(2)
	_ck("gate blocks at zero keys", not gate.is_open() and Game.small_keys == 0)
	await _door_frame(rig, gate, "k_00_locked_door.png")

	var key_root: Node = d.rooms[d.key_loop["key_cell"]]["node"]
	for foe: Node in _all(key_root):
		if foe is Enemy:
			foe.queue_free()
	await rig.wait_frames(5)
	_ck("clearing the detour reveals and arms its key",
		watch.is_clear() and key.visible and key.armed and key.is_revealed())
	await _key_frame(rig, key, "k_01_key_detour.png")

	key.call(&"_on_body_entered", hero)
	await rig.wait_frames(2)
	_ck("revealed pickup grants exactly one current-floor key",
		key.is_solved() and Game.small_keys == 1)
	gate.activate(hero)
	await rig.wait_frames(2)
	_ck("gate spends exactly one key and opens", gate.is_open()
		and Game.small_keys == 0)
	_ck("opening removes the live Atlas icon",
		not Atlas.locks.has(d.key_loop["tag"]))
	Run.level = 2
	_ck("other-floor key stock survives a floor switch", Game.small_keys == 2)
	Run.level = 1
	_ck("spent floor remains spent after switching back", Game.small_keys == 0)

	# Same run, same stable puzzle ids: both the collected key and opened gate
	# restore, and an already-open door publishes no stale lock record.
	var rebuilt := await _rebuild(rig, 1, 199911)
	var rebuilt_gate := rebuilt.key_loop["gate"] as PuzzleGate
	var rebuilt_key := rebuilt.key_loop["key"] as SmallKey
	_ck("rebuild restores collected key and opened gate",
		rebuilt_key.is_solved() and rebuilt_gate.is_open()
		and not Atlas.locks.has(rebuilt.key_loop["tag"]))


func _door_frame(rig, door: Node3D, file_name: String) -> void:
	var cam := Camera3D.new()
	cam.name = "DepthKeyCamera"
	rig.scene().add_child(cam)
	cam.global_position = door.global_position + door.global_transform.basis.z * 7.0 \
		+ Vector3.UP * 2.4
	cam.look_at(door.global_position + Vector3.UP * 1.5, Vector3.UP)
	cam.make_current()
	await rig.wait_frames(8)
	await rig.capture(_out.path_join(file_name))
	cam.queue_free()


func _key_frame(rig, key: Node3D, file_name: String) -> void:
	var cam := Camera3D.new()
	cam.name = "DepthKeyCamera"
	rig.scene().add_child(cam)
	var room: Node3D = key.get_parent() as Node3D
	var room_centre := room.global_position if room != null else key.global_position
	# Stay inside the room: the key sits near one wall, so an arbitrary positive
	# offset can put the proof camera behind that wall on half the generated plans.
	cam.global_position = key.global_position.lerp(room_centre, 0.78) \
		+ Vector3.UP * 2.6
	cam.look_at(key.global_position + Vector3.UP * 0.8, Vector3.UP)
	cam.make_current()
	await rig.wait_frames(8)
	await rig.capture(_out.path_join(file_name))
	cam.queue_free()


func _rebuild(rig, level: int, seed_value: int) -> Node:
	Run.level = level
	var old: Node = rig.scene().get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = seed_value
	rig.scene().add_child(d)
	await rig.wait_frames(3)
	return d


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _all(root: Node) -> Array:
	var found := [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("DEPTH_KEYS ok %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_fails += 1
	print("DEPTH_KEYS FAIL %s" % label)
