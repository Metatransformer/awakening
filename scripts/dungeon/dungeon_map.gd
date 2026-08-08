class_name DungeonMap
extends RefCounted
## The run's floor plan, generated before a single mesh exists.
##
## Deliberately a pure data structure with no scene-tree contact: a floor plan
## that can be generated and inspected headlessly is one you can actually test
## for "is every room reachable", which is the failure a room graph has.
##
## Layout is a random walk on an integer grid with a few branch stubs. That is
## the cheapest generator that still produces a shape the player can get lost
## in — a pure chain reads as a corridor, and full BSP is a lot of machinery for
## a twelve-room MVP.

enum Dir { N, E, S, W }

const DELTA := {
	Dir.N: Vector2i(0, -1),
	Dir.E: Vector2i(1, 0),
	Dir.S: Vector2i(0, 1),
	Dir.W: Vector2i(-1, 0),
}

static func opposite(d: Dir) -> Dir:
	match d:
		Dir.N: return Dir.S
		Dir.S: return Dir.N
		Dir.E: return Dir.W
		_: return Dir.E


## cell -> {exits: Array[Dir], index: int, band: int, has_chest: bool,
##          enemies: Array[StringName], cleared: bool, visited: bool}
var rooms: Dictionary = {}
## Walk order, so `index` reflects how deep into the run a room is.
var order: Array[Vector2i] = []
var entrance: Vector2i = Vector2i.ZERO

var _rng := RandomNumberGenerator.new()


func generate(seed_val: int, room_count: int = 12) -> void:
	_rng.seed = seed_val
	rooms.clear()
	order.clear()
	entrance = Vector2i.ZERO

	_carve_walk(room_count)
	_add_branches(maxi(room_count / 4, 1))
	_populate()


## The spine: a self-avoiding walk. When it boxes itself in it backtracks to an
## earlier room and continues from there, so it can never terminate short.
func _carve_walk(room_count: int) -> void:
	var cell := Vector2i.ZERO
	_new_room(cell)
	while order.size() < room_count:
		var options: Array[Dir] = []
		for d: Dir in DELTA:
			if not rooms.has(cell + DELTA[d]):
				options.append(d)
		if options.is_empty():
			# Boxed in — resume from a random earlier room.
			cell = order[_rng.randi_range(0, order.size() - 1)]
			var any := false
			for d: Dir in DELTA:
				if not rooms.has(cell + DELTA[d]):
					any = true
					break
			if not any:
				break
			continue
		var dir: Dir = options[_rng.randi_range(0, options.size() - 1)]
		var next: Vector2i = cell + DELTA[dir]
		_new_room(next)
		_link(cell, next, dir)
		cell = next


## Short dead-end spurs off the spine. These are where chests go — a reward the
## player has to choose to detour for is worth more than one on the critical path.
func _add_branches(count: int) -> void:
	var tries := count * 8
	var made := 0
	while made < count and tries > 0:
		tries -= 1
		var from: Vector2i = order[_rng.randi_range(0, order.size() - 1)]
		var options: Array[Dir] = []
		for d: Dir in DELTA:
			if not rooms.has(from + DELTA[d]):
				options.append(d)
		if options.is_empty():
			continue
		var dir: Dir = options[_rng.randi_range(0, options.size() - 1)]
		var next: Vector2i = from + DELTA[dir]
		_new_room(next)
		_link(from, next, dir)
		made += 1


func _new_room(cell: Vector2i) -> void:
	if rooms.has(cell):
		return
	rooms[cell] = {
		"exits": [] as Array,
		"index": order.size(),
		"band": 1,
		"has_chest": false,
		"enemies": [] as Array,
		"cleared": false,
		"visited": false,
	}
	order.append(cell)


func _link(a: Vector2i, b: Vector2i, dir: Dir) -> void:
	(rooms[a]["exits"] as Array).append(dir)
	(rooms[b]["exits"] as Array).append(opposite(dir))


## Enemies and chests by depth band. The entrance is deliberately left empty:
## arriving in a fight you did not choose is not a decision, it is an ambush.
func _populate() -> void:
	for cell in order:
		var r: Dictionary = rooms[cell]
		var idx: int = r["index"]
		var band := K.band_for_room(idx)
		r["band"] = band

		if cell == entrance:
			r["cleared"] = true
			continue

		var roster := _roster_for(band)
		var count := _rng.randi_range(1 + band / 2, 2 + band)
		var picks: Array = []
		for i in count:
			picks.append(roster[_rng.randi_range(0, roster.size() - 1)])
		r["enemies"] = picks

		# Dead ends are worth a chest; everything else rolls for one.
		var is_dead_end: bool = (r["exits"] as Array).size() <= 1
		r["has_chest"] = is_dead_end or _rng.randf() < 0.28


static func _roster_for(band: int) -> Array:
	match band:
		1: return [&"skeleton", &"goblin"]
		2: return [&"skeleton", &"goblin", &"kobold", &"orc"]
		_: return [&"kobold", &"orc", &"wraith"]


func room_at(cell: Vector2i) -> Dictionary:
	return rooms.get(cell, {})


func has(cell: Vector2i) -> bool:
	return rooms.has(cell)


func exits_of(cell: Vector2i) -> Array:
	var r: Dictionary = rooms.get(cell, {})
	return r.get("exits", [])


func size() -> int:
	return rooms.size()


## Every room reachable from the entrance. A generator that can strand a room is
## a generator that will eventually strand the exit.
func all_reachable() -> bool:
	if rooms.is_empty():
		return false
	var seen: Dictionary = {entrance: true}
	var queue: Array[Vector2i] = [entrance]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Dir in exits_of(c):
			var n: Vector2i = c + DELTA[d]
			if rooms.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == rooms.size()
