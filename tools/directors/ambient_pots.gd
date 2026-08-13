extends RefCounted
## Issue #107 -- generated ambient pots, their two reward lanes, and the smash.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/ambient_pots.gd \
##     --out=/tmp/ambient_pots/x.png --warmup=60
##
## Calibration: append `--sabotage=coin`. It adds one to the staged pickup
## after the placement audit, so exactly the direct-gold assertion must fail.
## No value is granted by the director: both rewards still travel through the
## Urn spill and their real Area3D/player overlap paths.

const SEED := 1072026
const LEVEL := 1
const COIN_SCRIPT := "res://scripts/world/coin_pickup.gd"
const APPROVED := {
	&"coins": 5,
	&"moss_agate": 1,
	&"health": 2,
	&"arrows": 3,
	&"tide_sapphire": 1,
	&"charges": 1,
	&"blood_ruby": 1,
}

var _out := "/tmp/ambient_pots"
var _fails := 0


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/ambient_pots/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var sabotage_coin: bool = String(rig.arg("sabotage", "")) == "coin"

	if rig.scene().name != &"DungeonRun":
		_check("the dungeon scene is the host", false)
		_finish()
		return

	Game.reset()
	Run.enter(SEED)
	var rupees_before: int = Game.rupees

	var first := await _rebuild(rig)
	if first == null:
		_check("the fixed-seed floor builds", false)
		_finish()
		return
	var first_cleared := await _clear_enemies(rig, first)
	var audit_a := _inspect_floor(first)

	# A new run clears atom flags as a real replay does. The Dungeon, seed and
	# floor are otherwise identical, so this is a reproduction and not a clone.
	Run.enter(SEED)
	var second := await _rebuild(rig)
	if second == null:
		_check("the deterministic rebuild completes", false)
		_finish()
		return
	var second_cleared := await _clear_enemies(rig, second)
	var audit_b := _inspect_floor(second)

	_check("both generated floors are safely cleared for the proof",
		first_cleared and second_cleared)
	_check("every eligible room with a blank wall has an AmbientUrn",
		bool(audit_a["coverage"]) and bool(audit_b["coverage"]))
	_check("entrance, boss arena and maze contain no ambient pot",
		bool(audit_a["excluded"]) and bool(audit_b["excluded"]))
	_check("rooms hold at most two ambient pots",
		bool(audit_a["maximum"]) and bool(audit_b["maximum"]))
	_check("each pot occupies one distinct blank wall centre, outside holes",
		bool(audit_a["sides"]) and bool(audit_b["sides"]))
	_check("every generated reward and amount belongs to the approved table",
		bool(audit_a["rewards"]) and bool(audit_b["rewards"]))
	_check("ambient atom ids are floor/cell/slot stable",
		bool(audit_a["identity"]) and bool(audit_b["identity"]))
	_check("the rebuild repeats every room/name/reward/amount/position signature",
		audit_a["signature"] == audit_b["signature"])

	var hero := _hero(rig)
	var camera := _game_camera(rig)
	if hero == null or camera == null:
		_check("the actual hero and GameCamera are available", false)
		_finish()
		return
	camera.make_current()

	var staged := await _stage_proof(rig, second, hero)
	if staged.is_empty():
		_check("an ordinary room accepts the proof composition", false)
		_finish()
		return
	var coin_pot := staged["coin"] as Node3D
	var gem_pot := staged["gem"] as Node3D

	await rig.capture(_out.path_join("01_intact_pots.png"))
	coin_pot.call(&"apply_hit", null)
	gem_pot.call(&"apply_hit", null)
	# Both reward tweens and all seven shards are near the crown of their arcs.
	await rig.wait_frames(8)
	await rig.capture(_out.path_join("02_smash_pop_midair.png"))
	await rig.wait_frames(32)
	await rig.capture(_out.path_join("03_rewards_settled.png"))

	var coin := _find_coin(rig.scene())
	var gem := _find_gem(rig.scene(), &"moss_agate")
	_check("the staged urns spill a coin pickup and a saleable gem mote",
		coin != null and gem != null)
	if coin == null or gem == null:
		_check("legacy rupees remain unchanged", Game.rupees == rupees_before)
		_finish()
		return

	var gold_before: int = Game.gold
	var bag_before: Dictionary = Run.bag.duplicate(true)
	if sabotage_coin:
		# Calibration changes the observed object, not the expected result. The
		# overlap still collects it honestly and only the +5 direct-gold proof fails.
		coin.set(&"amount", int(coin.get(&"amount")) + 1)
	await _walk_onto(rig, hero, coin, func() -> bool:
		return Game.gold != gold_before)
	_check("coin overlap adds 5 directly to Game.gold and creates no bag line",
		Game.gold == gold_before + 5 and Run.bag == bag_before)

	var gold_after_coin: int = Game.gold
	var gems_before := int(Run.bag.get(&"moss_agate", 0))
	await _walk_onto(rig, hero, gem, func() -> bool:
		return int(Run.bag.get(&"moss_agate", 0)) > gems_before)
	_check("gem overlap enters Run.bag once and does not increment gold",
		int(Run.bag.get(&"moss_agate", 0)) == gems_before + 1
		and Game.gold == gold_after_coin)
	_check("legacy rupees remain unchanged", Game.rupees == rupees_before)
	_finish()


func _check(label: String, ok: bool) -> void:
	if ok:
		print("AMBIENT_POTS ok %s" % label)
	else:
		_fails += 1
		print("AMBIENT_POTS FAIL %s" % label)


func _finish() -> void:
	if _fails == 0:
		print("AMBIENT_POTS ok -- every check passed")
	else:
		print("AMBIENT_POTS FAIL -- %d check(s) failed" % _fails)


# --- Generated-floor proof ---------------------------------------------------

func _inspect_floor(d: Node) -> Dictionary:
	var out := {
		"coverage": true,
		"excluded": true,
		"maximum": true,
		"sides": true,
		"rewards": true,
		"identity": true,
		"signature": [] as Array[String],
	}
	var signature := out["signature"] as Array[String]
	var maze_cell = d.call(&"pick_maze_cell")
	var has_boss: bool = d.placements.has(&"boss_door")
	var boss_cell = d.call(&"anchor_cell", &"boss_door") if has_boss else null

	for cell: Vector2i in d.rooms:
		var room: Node3D = d.rooms[cell]["node"]
		if room == null:
			continue
		var pots := _ambient_in(room)
		var blank := _blank_sides(d, cell)
		var excluded: bool = cell == d.entrance \
			or (has_boss and cell == boss_cell) or cell == maze_cell
		if excluded:
			out["excluded"] = bool(out["excluded"]) and pots.is_empty()
			continue
		if not blank.is_empty() and pots.is_empty():
			out["coverage"] = false
		if pots.size() > 2:
			out["maximum"] = false

		var used := {}
		for pot: Node3D in pots:
			var side := _side_for(d, cell, pot.position)
			if side == &"" or not blank.has(side) or used.has(side) \
					or not _at_wall_centre(d, cell, side, pot.position):
				out["sides"] = false
			used[side] = true

			var holds := StringName(pot.get(&"holds"))
			var amount := int(pot.get(&"amount"))
			if not APPROVED.has(holds) or int(APPROVED.get(holds, -1)) != amount:
				out["rewards"] = false

			var slot := int(pot.get(&"index"))
			var expected_name := "AmbientUrn%d" % slot
			var expected_tag := StringName("ambient_pot_f%d_%d_%d_%d"
				% [Run.level, cell.x, cell.y, slot])
			if String(pot.name) != expected_name \
					or StringName(pot.get(&"puzzle_id")) != expected_tag:
				out["identity"] = false

			signature.append("%d,%d/%s/%s/%d/%.3f,%.3f,%.3f" % [
				cell.x, cell.y, pot.name, holds, amount,
				pot.position.x, pot.position.y, pot.position.z,
			])
	signature.sort()
	return out


func _ambient_in(room: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child: Node in room.get_children():
		if child is Node3D and String(child.name).begins_with("AmbientUrn"):
			out.append(child as Node3D)
	return out


func _blank_sides(d: Node, cell: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	var doors: Array = d.rooms[cell]["doors"]
	var anchors: Dictionary = d.rooms[cell]["anchors"]
	var sides: Dictionary = d.call(&"_sides_of", cell)
	for side: StringName in sides:
		if not doors.has(side) and not anchors.has(side):
			out.append(side)
	return out


func _side_for(d: Node, cell: Vector2i, at: Vector3) -> StringName:
	var closest := INF
	var found := &""
	var sides: Dictionary = d.call(&"_sides_of", cell)
	for side: StringName in sides:
		var wall: Dictionary = sides[side]
		var distance: float = at.distance_to(wall["at"])
		if distance < closest:
			closest = distance
			found = side
	return found


func _at_wall_centre(d: Node, cell: Vector2i, side: StringName,
		at: Vector3) -> bool:
	var wall: Dictionary = d.call(&"_sides_of", cell)[side]
	var yaw := float(wall["yaw"])
	var facing := Vector3(sin(yaw), 0.0, cos(yaw))
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var delta: Vector3 = at - wall["at"]
	var inset := delta.dot(facing)
	return absf(delta.dot(along)) < 0.01 and inset > 0.4 and inset < 1.5


# --- Deliberately staged visual and overlap proof ----------------------------

func _stage_proof(rig, d: Node, hero: Node3D) -> Dictionary:
	var cell = _ordinary_cell(d)
	if cell == null:
		return {}
	var room: Node3D = d.rooms[cell]["node"]
	for pot: Node3D in _ambient_in(room):
		pot.queue_free()
	await rig.wait_frames(2)

	var blank := _blank_sides(d, cell)
	var side: StringName = blank[0]
	var wall: Dictionary = d.call(&"_sides_of", cell)[side]
	var yaw := float(wall["yaw"])
	var facing := Vector3(sin(yaw), 0.0, cos(yaw))
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var base: Vector3 = wall["at"] + facing * 1.15

	var coin := PuzzleAtoms.make(PuzzleAtoms.URN, &"ambient_pots_proof_coin")
	var gem := PuzzleAtoms.make(PuzzleAtoms.URN, &"ambient_pots_proof_gem")
	if coin == null or gem == null:
		return {}
	coin.name = "ProofCoinUrn"
	coin.set(&"holds", &"coins")
	coin.set(&"amount", 5)
	coin.position = base - along * 1.5
	room.add_child(coin)
	gem.name = "ProofGemUrn"
	gem.set(&"holds", &"moss_agate")
	gem.set(&"amount", 1)
	gem.position = base + along * 1.5
	room.add_child(gem)

	hero.velocity = Vector3.ZERO
	hero.global_position = room.to_global(wall["at"] + facing * 4.5) \
		+ Vector3.UP * 0.15
	_face_at(hero, (coin.global_position + gem.global_position) * 0.5)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(8)
	await rig.wait_frames(36)
	return {"coin": coin, "gem": gem}


func _ordinary_cell(d: Node):
	var maze_cell = d.call(&"pick_maze_cell")
	var has_boss: bool = d.placements.has(&"boss_door")
	var boss_cell = d.call(&"anchor_cell", &"boss_door") if has_boss else null
	var fallback = null
	for cell: Vector2i in d.rooms:
		if cell == d.entrance or (has_boss and cell == boss_cell) \
				or cell == maze_cell:
			continue
		if _blank_sides(d, cell).is_empty():
			continue
		if fallback == null:
			fallback = cell
		var claimed := false
		for placement: Dictionary in d.placements.values():
			if placement["cell"] == cell:
				claimed = true
				break
		if not claimed and (d.rooms[cell]["anchors"] as Dictionary).is_empty():
			return cell
	return fallback


func _find_coin(root: Node) -> Node3D:
	for node: Node in _all(root):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == COIN_SCRIPT:
			return node as Node3D
	return null


func _find_gem(root: Node, id: StringName) -> Node3D:
	for node: Node in _all(root):
		if node is LootMote and StringName(node.get(&"item_id")) == id:
			return node as Node3D
	return null


## Move the real CharacterBody3D in short collision-tested steps. The pickup's
## own process loop must observe its Area3D overlap and perform the transaction.
func _walk_onto(rig, hero: Node3D, pickup: Node3D, done: Callable) -> bool:
	var target := pickup.global_position
	for _i in 240:
		if done.call():
			return true
		var to := K.plane(target - hero.global_position)
		if to.length() > 0.18:
			var step := to.limit_length(0.18)
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
			else:
				var side := Vector3(-step.z, 0.0, step.x).normalized() * 0.18
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				else:
					hero.global_position -= side
		await rig.wait_frames(2)
	return done.call()


func _face_at(hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.facing_yaw = atan2(to.x, to.z)
	hero.rotation.y = hero.facing_yaw + PI


# --- Scene plumbing ----------------------------------------------------------

func _rebuild(rig) -> Node:
	Run.level = LEVEL
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		var gone: bool = await rig.until(func() -> bool:
			return scene.get_node_or_null(^"DungeonOld") == null, 5.0)
		if not gone:
			return null
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	if script == null:
		return null
	var d: Node = script.new()
	d.name = "Dungeon"
	d.set(&"seed_override", SEED)
	scene.add_child(d)
	await rig.wait_frames(14)
	return d


func _clear_enemies(rig, d: Node) -> bool:
	for node: Node in _all(d):
		if node is Enemy:
			node.queue_free()
	var cleared := func() -> bool:
		for node: Node in _all(d):
			if node is Enemy:
				return false
		return true
	return await rig.until(cleared, 3.0)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for node: Node in _all(rig.scene()):
		if node is GameCamera:
			return node
	return null


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found
