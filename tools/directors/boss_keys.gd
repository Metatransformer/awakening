extends RefCounted
## Issue #149: the Boss Key route through a real generated authored floor.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/boss_keys.gd \
##     --out=/tmp/boss-key/x.png --warmup=60 --level=1 \
##     --gate-prefab=sun_nest
##
## Repeat with `--level=2`, `3`, and `4`. The command-line prefab override is
## Dungeon's authored director seam; this director asserts it was supplied and
## then solves the resulting sun socket through PuzzleAtom's public `solve()`.
## Traversal is deliberately absent: the generated topology and public gameplay
## APIs are the proof, while fixed cameras keep the four frames about their props.

const SEED := 20260809
const BOSS_KEY_SCRIPT := "res://scripts/props/atoms/boss_key.gd"
const BOSS_DOOR_SCRIPT := "res://scripts/world/boss_door.gd"
const OPENING_W := 5.4
const OPENING_H := 4.6

var _level := 1
var _failed := false
var _out := ""
var _checks := 0


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/boss-key/x.png").get_base_dir()
	_level = clampi(int(rig.arg("level", "1")), 1, 4)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.enter(SEED)
	Run.level = _level

	if not _check(rig, rig.scene().name == &"DungeonRun",
			"wrong host scene (%s); use res://scenes/rooms/dungeon.tscn"
			% rig.scene().name):
		_finish()
		return
	if not _check(rig, rig.arg("gate-prefab", "") == "sun_nest",
			"the invocation did not force --gate-prefab=sun_nest"):
		_finish()
		return

	var dungeon: Node = await _rebuild(rig)
	if not _check(rig, dungeon != null, "the real Dungeon did not rebuild"):
		_finish()
		return
	var hero := _hero(rig)
	if not _check(rig, hero != null, "the dungeon scene has no player body"):
		_finish()
		return

	var boss_keys := _script_nodes(dungeon, BOSS_KEY_SCRIPT)
	var boss_doors := _script_nodes(dungeon, BOSS_DOOR_SCRIPT)
	var chambers := _named(dungeon, &"BossChamber")
	var arenas := _named(dungeon, &"Arena")
	var topology_ok := true
	topology_ok = _check(rig, boss_keys.size() == 1,
		"expected exactly one BossKey, found %d" % boss_keys.size()) and topology_ok
	topology_ok = _check(rig, boss_doors.size() == 1,
		"expected exactly one BossDoor, found %d" % boss_doors.size()) and topology_ok
	topology_ok = _check(rig, chambers.size() == 1,
		"expected exactly one BossChamber, found %d" % chambers.size()) and topology_ok
	topology_ok = _check(rig, arenas.size() == 1,
		"expected exactly one Arena, found %d" % arenas.size()) and topology_ok
	var gate_cell: Vector2i = dungeon.call(&"anchor_cell", &"gate_room")
	var door_cell: Vector2i = dungeon.call(&"anchor_cell", &"boss_door")
	topology_ok = _check(rig, gate_cell != door_cell,
		"gate-room cell %s is also the boss-door cell" % gate_cell) and topology_ok
	if not topology_ok:
		_finish()
		return

	var key := boss_keys[0] as Node3D
	var door := boss_doors[0] as Node3D
	var chamber := chambers[0] as Node3D
	var arena := arenas[0] as Node3D
	var downs := _named_stairs(chamber, &"Down")
	if not _check(rig, downs.size() == 1,
			"expected exactly one Down stair in BossChamber, found %d" % downs.size()):
		_finish()
		return
	var down := downs[0] as Node3D
	var gate := dungeon.call(&"anchor_node", &"gate_room") as Node
	var approach := dungeon.rooms[door_cell].get("node") as Node
	var gate_root := dungeon.rooms[gate_cell].get("node") as Node
	if not _check(rig, gate != null and gate_root != null and approach != null,
			"the generated anchors do not resolve to their authored room roots"):
		_finish()
		return

	_check(rig, chamber.is_ancestor_of(arena),
		"Arena is not a descendant of BossChamber")
	_check(rig, not approach.is_ancestor_of(arena),
		"Arena was placed in the generated approach room")
	_check(rig, not down.visible and not bool(down.get(&"enabled")),
		"Down starts visible or enabled before the boss dies")

	var portal := _nearest_portal(approach, door)
	_check(rig, is_equal_approx(float(door.get(&"opening_w")), OPENING_W)
		and is_equal_approx(float(door.get(&"opening_h")), OPENING_H),
		"BossDoor is not the 5.4 x 4.6 opening (%.2f x %.2f)"
		% [float(door.get(&"opening_w")), float(door.get(&"opening_h"))])
	_check(rig, portal != null
		and is_equal_approx(float(portal.get(&"opening_w")), OPENING_W)
		and is_equal_approx(float(portal.get(&"opening_h")), OPENING_H),
		"the generated portal was not fitted to the BossDoor opening")

	_check(rig, not key.visible and not bool(key.get(&"armed")),
		"Boss Key did not start hidden and unarmed")
	_check(rig, not Game.has_boss_key,
		"Game.has_boss_key was true before the gate-room solve")
	_check(rig, not bool(door.call(&"is_open")),
		"BossDoor started open before the key was collected")
	_check(rig, String(door.call(&"refusal_line")).contains("BOSS KEY"),
		"BossDoor refusal does not name the Boss Key")
	door.call(&"activate", hero)
	await rig.wait_physics_frames(2)
	_check(rig, not bool(door.call(&"is_open")) and not Game.has_boss_key,
		"BossDoor opened or granted state when activated without the key")

	var socket := gate_root.get_node_or_null(^"GateSocket")
	if not _check(rig, socket != null,
			"forced sun_nest built no GateSocket in the gate room"):
		_finish()
		return
	var watched: Array = gate.call(&"atoms")
	_check(rig, watched.size() == 1 and watched[0] == key,
		"the normal gate is not watching exactly the Boss Key")
	socket.call(&"solve")
	var revealed: bool = await rig.until(func() -> bool:
		return key.visible and bool(key.get(&"armed")) \
			and bool(key.call(&"is_revealed")), 2.0)
	if not _check(rig, revealed,
			"solving the GateSocket did not reveal and arm the Boss Key"):
		_finish()
		return
	_check(rig, is_equal_approx(float(key.call(&"rest_scale")), 2.0),
		"Boss Key does not use its oversized 2.0 rest scale")
	await rig.wait_seconds(0.75)
	await _frame_key(rig, dungeon, key, gate_cell)
	await rig.capture(_out.path_join("01-key.png"))

	var small_keys_before: int = Game.small_keys
	if not _check(rig, key.has_method(&"_on_body_entered"),
			"Boss Key has no body-entered pickup behavior"):
		_finish()
		return
	# This is the Area3D callback itself. Calling it directly removes only the
	# physics-overlap timing noise; its player-group guard, grant and solve remain.
	key.call(&"_on_body_entered", hero)
	var gate_opened: bool = await rig.until(func() -> bool:
		return bool(gate.call(&"is_open")), 2.0)
	_check(rig, Game.has_boss_key,
		"the Boss Key body-entered path did not set Game.has_boss_key")
	_check(rig, bool(key.call(&"is_solved")),
		"the Boss Key pickup did not solve its authored atom")
	_check(rig, gate_opened,
		"the normal gate did not auto-open on Boss Key pickup")
	_check(rig, Game.small_keys == small_keys_before,
		"the normal gate spent a small key (%d -> %d)"
		% [small_keys_before, Game.small_keys])
	_check(rig, Game.has_boss_key,
		"the normal gate spent the Boss Key before the chamber door")
	_check(rig, Game.boss_key_level == _level,
		"the held Boss Key is not tagged to floor %d" % _level)
	var other_level := 2 if _level == 1 else 1
	Run.level = other_level
	_check(rig, not bool(door.call(&"unlocked")),
		"floor %d's Boss Key unlocked the floor %d door" % [_level, other_level])
	Run.level = _level
	_check(rig, bool(door.call(&"unlocked")) and Game.has_boss_key,
		"the Boss Key did not survive a backtrack to its owning floor")

	if not _check(rig, door is Interactable and door.has_method(&"activate"),
			"BossDoor does not expose the Interactable activation API"):
		_finish()
		return
	door.call(&"activate", hero)
	var door_opened: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 2.0)
	var door_flag: StringName = door.call(&"flag_id")
	_check(rig, door_opened, "BossDoor did not open through activate()")
	_check(rig, not Game.has_boss_key,
		"BossDoor did not consume Game.has_boss_key")
	_check(rig, Game.flag(door_flag),
		"BossDoor did not write its own persistent door flag %s" % door_flag)
	await rig.wait_seconds(1.1)
	await _frame_door(rig, dungeon, door, door_cell)
	await rig.capture(_out.path_join("02-door.png"))

	var boss := arena.call(&"boss") as Node3D
	var health: HealthComponent = boss.get(&"health") as HealthComponent \
		if boss != null else null
	if not _check(rig, boss != null and is_instance_valid(boss)
			and health != null and not health.dead and health.health_points > 0,
			"no living boss is present behind the opened BossDoor"):
		_finish()
		return
	_check(rig, chamber.is_ancestor_of(boss),
		"the living boss is not inside BossChamber")
	_check(rig, not down.visible and not bool(down.get(&"enabled")),
		"Down revealed before the boss died")
	await _frame_chamber(rig, chamber, boss, 68.0)
	await rig.capture(_out.path_join("03-chamber.png"))

	var boss_id := StringName(arena.get(&"boss_id"))
	var dead_flag := BossDoor.dead_flag(boss_id)
	var landed := health.apply_hit(Hit.make(health.health_points,
		boss.global_position + Vector3(0.0, 0.0, 3.0), &"director",
		0.0, 0.0, &"director"))
	_check(rig, landed and health.dead,
		"the fatal hit did not land through HealthComponent.apply_hit")
	var death_finished: bool = await rig.until(func() -> bool:
		return Game.flag(dead_flag) \
			and bool(arena.call(&"is_spent")) \
			and down.visible and bool(down.get(&"enabled")), 4.0)
	_check(rig, death_finished,
		"boss death listeners did not spend the arena and reveal Down")
	_check(rig, Game.flag(dead_flag),
		"the public boss-dead flag %s is false" % dead_flag)
	_check(rig, bool(door.call(&"is_open")) and Game.flag(door_flag),
		"BossDoor did not remain open on its own door flag after the kill")
	_check(rig, down.visible and bool(down.get(&"enabled")),
		"Down is not visible and enabled after the kill")
	var reward_ready: bool = await rig.until(func() -> bool:
		var reward := arena.call(&"boss_item_chest") as Node3D
		return reward != null and reward.visible and bool(reward.get(&"enabled")), 3.0)
	_check(rig, reward_ready,
		"the cleared chamber's boss reward did not finish arriving")
	await rig.wait_seconds(0.35)
	await _frame_cleared(rig, chamber, arena, down)
	await rig.capture(_out.path_join("04-cleared.png"))

	_finish()


func _check(rig, ok: bool, message: String) -> bool:
	_checks += 1
	if ok:
		print("BOSS KEY ok check %02d" % _checks)
		return true
	_failed = true
	rig.fail("BOSS KEY FAIL %s" % message)
	return false


func _finish() -> void:
	if _failed:
		print("BOSS KEY FAIL floor=%d -- one or more checks failed" % _level)
	else:
		print("BOSS KEY ok floor=%d" % _level)


func _rebuild(rig) -> Node:
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	if script == null:
		return null
	var dungeon: Node = script.new()
	dungeon.name = "Dungeon"
	dungeon.set(&"seed_override", SEED)
	scene.add_child(dungeon)
	await rig.wait_frames(12)
	return dungeon


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] as Node3D if not players.is_empty() else null


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_all(child))
	return found


func _script_nodes(root: Node, path: String) -> Array[Node]:
	var found: Array[Node] = []
	var wanted := load(path) as Script
	if wanted == null:
		return found
	for node in _all(root):
		if node.get_script() == wanted:
			found.append(node)
	return found


func _named(root: Node, wanted: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in _all(root):
		if node.name == wanted:
			found.append(node)
	return found


func _named_stairs(root: Node, wanted: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in _all(root):
		if node.name == wanted and node is Stairs:
			found.append(node)
	return found


func _nearest_portal(root: Node, door: Node3D) -> Node3D:
	var nearest: Node3D = null
	var nearest_d := INF
	for child in root.get_children():
		if not child is KitDoorway:
			continue
		var portal := child as Node3D
		var distance := portal.global_position.distance_to(door.global_position)
		if distance < nearest_d:
			nearest = portal
			nearest_d = distance
	return nearest if nearest_d < 0.2 else null


func _proof_camera(rig) -> Camera3D:
	var camera := rig.scene().get_node_or_null(^"BossKeyProofCamera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "BossKeyProofCamera"
		rig.scene().add_child(camera)
	return camera


func _pose_camera(rig, at: Vector3, look: Vector3, fov: float) -> void:
	var camera := _proof_camera(rig)
	camera.fov = fov
	camera.global_position = at
	camera.look_at(look, Vector3.UP)
	camera.make_current()
	await rig.wait_frames(10)


func _flat_toward(from: Vector3, to: Vector3, fallback: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else fallback


func _frame_key(rig, dungeon: Node, key: Node3D, cell: Vector2i) -> void:
	var centre: Vector3 = dungeon.call(&"centre_of", cell)
	var inward := _flat_toward(key.global_position, centre, Vector3.BACK)
	await _pose_camera(rig, key.global_position + inward * 4.8 + Vector3.UP * 2.5,
		key.global_position + Vector3.UP * 0.9, 52.0)


func _frame_door(rig, dungeon: Node, door: Node3D, cell: Vector2i) -> void:
	var centre: Vector3 = dungeon.call(&"centre_of", cell)
	var inward := _flat_toward(door.global_position, centre, door.global_basis.z)
	await _pose_camera(rig, door.global_position + inward * 8.0 + Vector3.UP * 3.0,
		door.global_position + Vector3.UP * 2.1, 60.0)


func _frame_chamber(rig, chamber: Node3D, boss: Node3D, fov: float) -> void:
	var at := chamber.to_global(Vector3(0.0, 5.6, 6.0))
	await _pose_camera(rig, at, boss.global_position + Vector3.UP * 1.2, fov)


func _frame_cleared(rig, chamber: Node3D, arena: Node3D, down: Node3D) -> void:
	var at := chamber.to_global(Vector3(0.0, 5.8, 6.0))
	var reward_centre := arena.global_position.lerp(down.global_position, 0.55)
	await _pose_camera(rig, at, reward_centre + Vector3.UP * 1.0, 74.0)
