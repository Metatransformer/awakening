extends RefCounted
## Are dungeon stairs bidirectional without turning a floor change into a rest?
##
## Proves the physical UP stair at both entrances, carries a wounded, magic-spent
## bag down and back through the real Flow scene transitions, verifies the ascent
## arrival contract at the canonical DOWN stair, then walks floor 1's same public
## activation seam into the shared priced extraction receipt and garrison path.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/ascend_stairs.gd \
##     --out=/tmp/ascend-stairs/x.png


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/ascend-stairs/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var ready: bool = await rig.until(func() -> bool:
		return _dungeon(rig) != null and _hero(rig) != null, 8.0)
	if not rig.check(ready, "ASCEND floor 1 never finished building"):
		return

	var dungeon := _dungeon(rig)
	var hero := _hero(rig)
	_freeze_enemies(rig)
	var up := _one_up(rig, dungeon, "floor 1")
	if up == null:
		return
	_check_in_entrance(rig, dungeon, up, "floor 1")
	rig.check(up.prompt == "EXIT",
		"ASCEND floor 1 UP prompt is '%s', wanted EXIT" % up.prompt)
	await _address_from_room(rig, up, hero)
	await _capture_stair(rig, dungeon, up,
		out.path_join("ascend_00_floor1_exit.png"))

	# Build a trip whose preservation is observable rather than an empty bag and
	# full meters surviving by coincidence. These public state operations are test
	# setup; the floor changes themselves happen only through Stairs.activate().
	Run.collect(&"iron_scrap", 4)
	Run.collect(&"deep_amber", 2)
	Game.heal(Game.max_quarters)
	Game.damage(K.HEART)
	Game.fill_magic()
	Game.spend_magic(K.MAGIC_SPIN)
	var run_seed := Run.seed_used
	var bag_before: Dictionary = Run.bag.duplicate(true)
	var bag_count := Run.bag_count()
	var bag_value := Run.bag_value()
	var health := Game.quarters
	var magic := Game.magic
	rig.check(not bag_before.is_empty(), "ASCEND test trip has no carried bag state")
	rig.check(health > 0 and health < Game.max_quarters,
		"ASCEND test trip health is not a live non-full value (%d/%d)"
		% [health, Game.max_quarters])
	rig.check(magic >= 0 and magic < Game.max_magic,
		"ASCEND test trip magic is not non-full (%d/%d)"
		% [magic, Game.max_magic])
	print("ASCEND trip seed=%d bag=%s value=%d health=%d magic=%d"
		% [run_seed, bag_before, bag_value, health, magic])

	var down := _one_canonical_down(rig, dungeon, "floor 1")
	if down == null:
		return
	var old_dungeon_id := dungeon.get_instance_id()
	down.activate(hero)
	if not await _wait_for_floor(rig, 2, old_dungeon_id):
		rig.fail("ASCEND canonical DOWN stair never completed the Flow transition to floor 2")
		return

	dungeon = _dungeon(rig)
	hero = _hero(rig)
	_freeze_enemies(rig)
	up = _one_up(rig, dungeon, "floor 2")
	if up == null:
		return
	_check_in_entrance(rig, dungeon, up, "floor 2")
	rig.check(up.prompt == "ASCEND",
		"ASCEND floor 2 UP prompt is '%s', wanted ASCEND" % up.prompt)
	await _capture_stair(rig, dungeon, up,
		out.path_join("ascend_01_floor2_up.png"))

	old_dungeon_id = dungeon.get_instance_id()
	up.activate(hero)
	if not await _wait_for_floor(rig, 1, old_dungeon_id):
		rig.fail("ASCEND floor 2 UP stair never completed the Flow transition to floor 1")
		return

	dungeon = _dungeon(rig)
	hero = _hero(rig)
	_freeze_enemies(rig)
	rig.check(Run.in_dungeon, "ASCEND returning to floor 1 ended the run")
	rig.check(Run.seed_used == run_seed,
		"ASCEND run seed changed across the trip: %d -> %d"
		% [run_seed, Run.seed_used])
	rig.check(_same_counts(Run.bag, bag_before),
		"ASCEND bag counts changed across the trip: %s -> %s"
		% [bag_before, Run.bag])
	rig.check(Run.bag_count() == bag_count,
		"ASCEND bag count changed across the trip: %d -> %d"
		% [bag_count, Run.bag_count()])
	rig.check(Run.bag_value() == bag_value,
		"ASCEND bag value changed across the trip: %d -> %d"
		% [bag_value, Run.bag_value()])
	rig.check(Game.quarters == health,
		"ASCEND health changed across the trip: %d -> %d"
		% [health, Game.quarters])
	rig.check(Game.magic == magic,
		"ASCEND magic changed across the trip: %d -> %d" % [magic, Game.magic])

	down = _one_arrival_down(rig, "returned floor 1")
	if down == null:
		return
	var wanted_position := down.arrival_position()
	var wanted_heading := down.arrival_heading()
	var actual_heading := -hero.global_basis.z
	actual_heading.y = 0.0
	actual_heading = actual_heading.normalized()
	var position_error := hero.global_position.distance_to(wanted_position)
	var heading_dot := actual_heading.dot(wanted_heading)
	rig.check(position_error <= 0.35,
		"ASCEND arrival is %.2f m from the canonical DOWN stair pose" % position_error)
	rig.check(heading_dot >= cos(deg_to_rad(8.0)),
		"ASCEND arrival faces away from the canonical DOWN stair (dot %.3f)"
		% heading_dot)
	rig.check(Saves.current_room == down.arrival_room_id(),
		"ASCEND save room is '%s', wanted arrival room '%s'"
		% [Saves.current_room, down.arrival_room_id()])
	await _capture_stair(rig, dungeon, down,
		out.path_join("ascend_02_floor1_arrival.png"))

	up = _one_up(rig, dungeon, "returned floor 1")
	if up == null:
		return
	var gold_before := Game.gold
	var expected_charge := Run.extract_charge()
	var expected_contents: Dictionary = Run.bag.duplicate(true)
	up.activate(hero)
	var receipt_ready: bool = await rig.until(func() -> bool:
		return not Run.in_dungeon and Flow.ending and _run_end(rig) != null, 8.0)
	if not rig.check(receipt_ready,
		"ASCEND floor-1 UP stair did not reach the shared run-end receipt"):
		return

	var summary := Run.summary
	rig.check(bool(summary.get("extracted", false)),
		"ASCEND floor-1 UP stair ended the run without extraction status")
	rig.check(int(summary.get("fee", -1)) == expected_charge,
		"ASCEND receipt fee is %d, wanted standard charge %d"
		% [int(summary.get("fee", -1)), expected_charge])
	rig.check(Game.gold == gold_before - expected_charge,
		"ASCEND purse changed by %d, wanted extraction charge %d"
		% [gold_before - Game.gold, expected_charge])
	var receipt_contents: Dictionary = summary.get("contents", {})
	rig.check(_same_counts(receipt_contents, expected_contents),
		"ASCEND receipt contents differ from the carried bag")
	rig.check(Game.quarters == Game.max_quarters,
		"ASCEND shared extraction did not restore health")
	rig.check(Game.magic == Game.max_magic,
		"ASCEND shared extraction did not restore magic")
	await rig.capture(out.path_join("ascend_03_receipt.png"))

	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	var home: bool = await rig.until(func() -> bool:
		return rig.scene() is Garrison and not Flow.busy and not Flow.ending, 12.0)
	rig.check(home, "ASCEND extraction receipt did not reach the garrison path")
	rig.check(not rig.paused, "ASCEND garrison path left the scene tree paused")

	if rig.fails == 0:
		print("ASCEND STAIRS OK")


func _dungeon(rig) -> Dungeon:
	var root: Node = rig.scene()
	if root == null:
		return null
	if root is Dungeon:
		return root as Dungeon
	for child in root.find_children("*", "Dungeon", true, false):
		return child as Dungeon
	return null


func _hero(rig) -> Hero:
	var heroes: Array = rig.get_nodes_in_group(&"player")
	if heroes.is_empty():
		return null
	return heroes[0] as Hero


func _stairs(dungeon: Dungeon, direction: Stairs.Direction) -> Array[Stairs]:
	var found: Array[Stairs] = []
	for node in dungeon.find_children("*", "Stairs", true, false):
		var stair := node as Stairs
		if stair != null and stair.direction == direction:
			found.append(stair)
	return found


func _one_up(rig, dungeon: Dungeon, label: String) -> Stairs:
	var found := _stairs(dungeon, Stairs.Direction.UP)
	if not rig.check(found.size() == 1,
		"ASCEND %s has %d UP stairs, wanted exactly 1" % [label, found.size()]):
		return null
	return found[0]


func _check_in_entrance(rig, dungeon: Dungeon, up: Stairs, label: String) -> void:
	var entrance_row: Dictionary = dungeon.rooms.get(dungeon.entrance, {})
	var entrance_node := entrance_row.get("node") as Node
	rig.check(entrance_node != null and up.get_parent() == entrance_node,
		"ASCEND %s UP stair is not in the entrance room" % label)


func _one_canonical_down(rig, dungeon: Dungeon, label: String) -> Stairs:
	var found: Array[Stairs] = []
	for stair in _stairs(dungeon, Stairs.Direction.DOWN):
		if stair.receives_ascent and stair.is_in_group(Stairs.ARRIVAL_GROUP):
			found.append(stair)
	if not rig.check(found.size() == 1,
		"ASCEND %s has %d canonical DOWN stairs, wanted exactly 1"
		% [label, found.size()]):
		return null
	return found[0]


func _one_arrival_down(rig, label: String) -> Stairs:
	var found: Array[Stairs] = []
	for node in rig.get_nodes_in_group(Stairs.ARRIVAL_GROUP):
		var stair := node as Stairs
		if stair != null and stair.direction == Stairs.Direction.DOWN \
				and stair.receives_ascent:
			found.append(stair)
	if not rig.check(found.size() == 1,
		"ASCEND %s has %d DOWN stairs in ARRIVAL_GROUP, wanted exactly 1"
		% [label, found.size()]):
		return null
	return found[0]


func _address_from_room(rig, up: Stairs, hero: Hero) -> void:
	var room_side := -up.global_basis.z
	room_side.y = 0.0
	room_side = room_side.normalized()
	hero.velocity = Vector3.ZERO
	hero.global_position = up.global_position + room_side * 2.55 + Vector3.UP * 0.05
	hero.facing_yaw = atan2(-room_side.x, -room_side.z)
	hero.rotation.y = hero.facing_yaw + PI
	var focused: bool = await rig.until(func() -> bool:
		return up.player_inside and Prompt.focus == up, 3.0)
	rig.check(up.to_local(hero.global_position).z < -1.0,
		"ASCEND floor-1 hero is not on the UP stair's room-facing side")
	rig.check(up.player_inside,
		"ASCEND floor-1 hero cannot physically enter the UP stair trigger")
	rig.check(focused,
		"ASCEND floor-1 hero cannot focus/address the UP stair")


func _wait_for_floor(rig, wanted_level: int, old_dungeon_id: int) -> bool:
	return await rig.until(func() -> bool:
		var dungeon := _dungeon(rig)
		return not Flow.busy and Run.in_dungeon and Run.level == wanted_level \
			and Flow.get("_card") == null and dungeon != null \
			and dungeon.get_instance_id() != old_dungeon_id, 12.0)


func _freeze_enemies(rig) -> void:
	for node in rig.get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = false


func _capture_stair(rig, dungeon: Dungeon, stair: Stairs, path: String) -> void:
	var room_side := -stair.global_basis.z
	room_side.y = 0.0
	room_side = room_side.normalized()
	var eye := Camera3D.new()
	eye.name = "AscendDirectorCamera"
	dungeon.add_child(eye)
	eye.global_position = stair.global_position + room_side * 7.2 + Vector3.UP * 4.5
	var target_height := 1.5 if stair.direction == Stairs.Direction.UP else 0.45
	eye.look_at(stair.global_position + Vector3.UP * target_height, Vector3.UP)
	eye.fov = 56.0
	eye.make_current()
	await rig.wait_frames(6)
	await rig.capture(path)
	eye.queue_free()


func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if int(a[key]) != int(b.get(key, -1)):
			return false
	return true


func _run_end(rig) -> RunEndScreen:
	var root: Node = rig.scene()
	if root == null:
		return null
	for node in _walk(root):
		if node is RunEndScreen:
			return node as RunEndScreen
	return null


func _walk(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_walk(child))
	return found
