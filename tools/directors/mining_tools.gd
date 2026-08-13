extends RefCounted
## Issue #184 -- generated mining, Pickaxe commitment, and run persistence.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/mining_tools.gd \
##     --out=/tmp/mining-tools/x.png --warmup=60

const SEED := 1842026
const LEVEL := 1
const MINING_VEIN_SCRIPT := "res://scripts/world/mining_vein.gd"
const WALL_INSET := 0.72
const PAYOUTS := {
	&"iron_scrap": 3,
	&"riveted_plate": 2,
	&"tension_coil": 1,
}

var _out := "/tmp/mining-tools"


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/mining-tools/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not rig.check(rig.scene().name == &"DungeonRun",
			"the proof is hosted by the real dungeon scene"):
		return

	Game.reset()
	Run.enter(SEED)
	Run.level = LEVEL
	var dungeon: Dungeon = await _rebuild(rig)
	if not rig.check(dungeon != null, "the fixed-seed Dungeon builds"):
		return
	rig.check(await _clear_enemies(rig, dungeon),
		"the generated floor is safely cleared for the interaction proof")

	var audit: Dictionary = _audit_floor(dungeon)
	rig.check(bool(audit.get("ordinary", false)),
		"veins occur only in ordinary non-entrance, non-maze rooms")
	rig.check(bool(audit.get("blank_wall", false)),
		"every generated vein stands on one of its room's blank walls")
	rig.check(bool(audit.get("maximum", false)),
		"every generated room contains at most one mining vein")
	rig.check(bool(audit.get("identity", false)),
		"every vein uses stable mining_vein:floor:x:y identity")
	rig.check(bool(audit.get("payout", false)),
		"every generated vein carries one exact authored payout pair")
	rig.check(is_equal_approx(Dungeon.MINING_VEIN_CHANCE, 0.65)
		and _reward_table_exact(),
		"generation uses deterministic 65 percent placement and 65/22/13 payouts")

	var veins: Array[Node3D] = _veins(dungeon)
	if not rig.check(not veins.is_empty(),
			"the fixed seed contains at least one generated vein"):
		return
	var vein: Node3D = veins[0]
	var cell: Vector2i = _cell_for_vein(dungeon, vein)
	var site_id := StringName(vein.get(&"site_id"))
	var reward_id := StringName(vein.get(&"reward_item_id"))
	var reward_count := int(vein.get(&"reward_count"))
	rig.check(site_id == StringName("mining_vein:%d:%d:%d" % [
		Run.level, cell.x, cell.y]), "the selected vein's identity matches its floor cell")
	rig.check(int(PAYOUTS.get(reward_id, 0)) == reward_count,
		"the selected fixed-seed vein has its exact reward id/count pair")

	# Call the real placer directly on a detached room root. It may or may not
	# place for this salted cell, but either outcome must leave the floor stream
	# untouched; that isolation is the contract under test here.
	var probe_root := Node3D.new()
	var rng_state_before: int = dungeon._rng.state
	dungeon._place_mining_vein(probe_root, cell)
	var rng_state_after: int = dungeon._rng.state
	rig.check(rng_state_after == rng_state_before,
		"a direct _place_mining_vein call does not advance Dungeon._rng.state")
	probe_root.free()

	var hero := rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	if not rig.check(hero != null and hero.combat != null,
			"the real Hero and HeroCombat are present"):
		return
	Game.tool_durabilities.erase(ToolDb.PICKAXE_ID)
	Game.items.erase(ToolDb.PICKAXE_ID)
	Game.grant(ToolDb.PICKAXE_ID)
	var pickaxe_maximum: int = Game.tool_max_durability(ToolDb.PICKAXE_ID)
	rig.check(pickaxe_maximum == 12
		and Game.tool_durability(ToolDb.PICKAXE_ID) == pickaxe_maximum,
		"the crafted Pickaxe begins at its exact 12 / 12 durability")
	rig.check(_pickaxe_outside_armament(hero),
		"the Pickaxe enters neither wheel nor armament graphs")

	var into_room: Vector3 = K.plane(vein.global_transform.basis.z).normalized()
	var along_wall: Vector3 = K.plane(vein.global_transform.basis.x).normalized()
	var camera := Camera3D.new()
	camera.fov = 48.0
	rig.scene().add_child(camera)
	camera.global_position = vein.global_position + into_room * 5.0 \
		+ along_wall * 3.0 + Vector3.UP * 3.2
	camera.look_at(vein.global_position + Vector3.UP * 0.8, Vector3.UP)
	camera.make_current()
	_stand_at(hero, vein.global_position + into_room * 1.75, vein.global_position)
	await rig.wait_physics_frames(6)
	rig.check(await rig.until(func() -> bool: return Prompt.focus == vein, 2.0),
		"moving the real Hero to the vein gives it prompt focus")
	await rig.capture(_out.path_join("mining_00_intact.png"))

	# The generated site doubles as the null control. A forced heavy hit clears
	# Hero's exact utility commitment before the authored impact; the same site is
	# then available for the successful held interaction below.
	var durability_before_cancel: int = Game.tool_durability(ToolDb.PICKAXE_ID)
	await rig.press(&"interact")
	var cancel_started: bool = await rig.until(func() -> bool:
		return hero.utility_working(ToolDb.PICKAXE_ID), 2.0)
	rig.check(cancel_started, "the first real hold begins Pickaxe work")
	if cancel_started:
		var hit := Hit.make(K.HEALTH_POINT,
			hero.global_position + into_room * 1.0, &"contact", 0.0, 0.45,
			&"MINING CONTROL")
		hit.odds_knockdown = 0.0
		hit.odds_stagger = 1.0
		rig.check(hero.take_hit(hit),
			"a real pre-impact heavy hit interrupts the Pickaxe commitment")
	rig.release(&"interact")
	await rig.wait_seconds(1.0)
	rig.check(not Run.is_resource_site_depleted(site_id)
		and Game.tool_durability(ToolDb.PICKAXE_ID) == durability_before_cancel
		and _motes(rig.scene()).is_empty() and bool(vein.get(&"enabled")),
		"pre-impact cancellation creates no loot, depletion, or wear")
	rig.check(not hero.utility_working(ToolDb.PICKAXE_ID)
		and hero.combat.pickaxe != null and not hero.combat.pickaxe.visible,
		"the interrupted Pickaxe is put away")
	Game.heal(Game.max_health_points)
	rig.check(await rig.until(func() -> bool: return hero.can_act(), 3.0),
		"the Hero recovers from the cancellation control")

	_stand_at(hero, vein.global_position + into_room * 1.75, vein.global_position)
	await rig.wait_physics_frames(5)
	rig.check(await rig.until(func() -> bool: return Prompt.focus == vein, 2.0),
		"the cancelled vein returns to real prompt focus")
	await rig.press(&"interact")
	var mining_started: bool = await rig.until(func() -> bool:
		return hero.utility_working(ToolDb.PICKAXE_ID), 2.0)
	rig.check(mining_started, "the successful real hold begins committed mining")
	if mining_started:
		rig.check(hero.combat.pickaxe != null and hero.combat.pickaxe.visible
			and not hero.combat.woodsman_axe.visible,
			"the visible Pickaxe replaces combat gear during its swing")
		camera.global_position = hero.global_position + along_wall * 3.0 \
			+ into_room * 1.2 + Vector3.UP * 1.8
		camera.look_at(hero.global_position + Vector3.UP * 1.05, Vector3.UP)
		await rig.wait_frames(2)
		await rig.capture(_out.path_join("mining_01_pickaxe_swing.png"))

	var depleted: bool = await rig.until(func() -> bool:
		return Run.is_resource_site_depleted(site_id), 2.0)
	rig.release(&"interact")
	# Move clear before LootMote arms. The reward remains a physical stack on the
	# floor for the depleted-result frame instead of being auto-collected.
	_stand_at(hero, hero.global_position + into_room * 3.0, vein.global_position)
	await rig.wait_physics_frames(2)
	rig.check(depleted, "the committed impact records stable site depletion")
	rig.check(Game.tool_durability(ToolDb.PICKAXE_ID) == pickaxe_maximum - 1,
		"the committed ore impact spends exactly one Pickaxe durability")
	var intact := vein.get_node_or_null(^"Intact") as Node3D
	var rubble := vein.get_node_or_null(^"Rubble") as Node3D
	var shape: CollisionShape3D = _interaction_shape(vein)
	rig.check(intact != null and not intact.visible and rubble != null and rubble.visible,
		"the depleted vein replaces intact ore with visible rubble")
	rig.check(not bool(vein.get(&"enabled")) and shape != null and shape.disabled,
		"depletion disables the vein's real interaction")
	var drops: Array[LootMote] = _motes(rig.scene())
	rig.check(drops.size() == 1 and drops[0].item_id == reward_id
		and drops[0].count == reward_count,
		"the impact creates one physical LootMote stack with exact id and count")
	camera.global_position = vein.global_position + along_wall * 4.0 \
		+ into_room * 3.2 + Vector3.UP * 2.7
	camera.look_at(vein.global_position + Vector3.UP * 0.55, Vector3.UP)
	await rig.wait_seconds(0.46)
	await rig.capture(_out.path_join("mining_02_depleted.png"))

	var valid_v3: Dictionary = Run.snapshot()
	var saved_sites: Array = valid_v3.get("depleted_resource_sites", [])
	rig.check(int(valid_v3.get("version", 0)) == 3 and saved_sites.has(site_id),
		"Run snapshot v3 writes the depleted stable site")
	var filtered_v3: Dictionary = valid_v3.duplicate(true)
	filtered_v3["depleted_resource_sites"] = [
		String(site_id),
		"not_a_site",
		"mining_vein:0:0:0",
		"mining_vein:01:0:0",
		77,
	]
	rig.check(Run.restore(filtered_v3)
		and Run.depleted_resource_sites.size() == 1
		and Run.is_resource_site_depleted(site_id),
		"Run v3 round-trip keeps the valid site and filters invalid ids")
	for old_version: int in [1, 2]:
		var old_snapshot: Dictionary = valid_v3.duplicate(true)
		old_snapshot["version"] = old_version
		old_snapshot["depleted_resource_sites"] = [String(site_id)]
		rig.check(Run.restore(old_snapshot)
			and Run.depleted_resource_sites.is_empty(),
			"Run v%d remains readable with empty depletion state" % old_version)
	rig.check(Run.restore(valid_v3) and Run.is_resource_site_depleted(site_id),
		"the valid v3 depletion round-trip restores after compatibility reads")

	var rebuilt: Dungeon = await _rebuild(rig)
	var rebuilt_vein: Node3D = _find_site(rebuilt, site_id)
	var rebuilt_rubble := rebuilt_vein.get_node_or_null(^"Rubble") as Node3D \
		if rebuilt_vein != null else null
	rig.check(rebuilt_vein != null and not bool(rebuilt_vein.get(&"enabled"))
		and rebuilt_rubble != null and rebuilt_rubble.visible,
		"the same fixed-seed rebuild restores the same site depleted")

	Run.enter(SEED)
	Run.level = LEVEL
	var fresh: Dungeon = await _rebuild(rig)
	var fresh_vein: Node3D = _find_site(fresh, site_id)
	var fresh_intact := fresh_vein.get_node_or_null(^"Intact") as Node3D \
		if fresh_vein != null else null
	var fresh_rubble := fresh_vein.get_node_or_null(^"Rubble") as Node3D \
		if fresh_vein != null else null
	rig.check(Run.depleted_resource_sites.is_empty()
		and fresh_vein != null and bool(fresh_vein.get(&"enabled"))
		and fresh_intact != null and fresh_intact.visible
		and fresh_rubble != null and not fresh_rubble.visible,
		"a new run clears depletion and rebuilds the same site intact")
	rig.check(fresh_vein != null
		and StringName(fresh_vein.get(&"reward_item_id")) == reward_id
		and int(fresh_vein.get(&"reward_count")) == reward_count,
		"the private salted stream repeats the selected site's exact payout")

	if rig.fails == 0:
		print("MINING TOOLS OK")


func _audit_floor(dungeon: Dungeon) -> Dictionary:
	var ordinary := true
	var blank_wall := true
	var maximum := true
	var identity := true
	var payout := true
	var maze_cell: Variant = dungeon.pick_maze_cell()
	for cell: Vector2i in dungeon.rooms:
		var room := dungeon.rooms[cell].get("node") as Node3D
		if room == null:
			continue
		var room_veins: Array[Node3D] = _direct_veins(room)
		var excluded: bool = cell == dungeon.entrance \
			or (maze_cell is Vector2i and cell == maze_cell)
		if excluded:
			ordinary = ordinary and room_veins.is_empty()
		else:
			maximum = maximum and room_veins.size() <= 1
		for vein: Node3D in room_veins:
			ordinary = ordinary and not excluded
			blank_wall = blank_wall and _on_blank_wall(dungeon, cell, vein)
			var site_id := StringName(vein.get(&"site_id"))
			identity = identity and site_id == StringName(
				"mining_vein:%d:%d:%d" % [Run.level, cell.x, cell.y])
			var reward_id := StringName(vein.get(&"reward_item_id"))
			payout = payout and int(PAYOUTS.get(reward_id, 0)) \
				== int(vein.get(&"reward_count"))
	return {
		"ordinary": ordinary,
		"blank_wall": blank_wall,
		"maximum": maximum,
		"identity": identity,
		"payout": payout,
	}


func _on_blank_wall(dungeon: Dungeon, cell: Vector2i, vein: Node3D) -> bool:
	var blank_sides: Array[StringName] = dungeon._ambient_pot_sides(cell)
	var size: float = dungeon.size_of(cell)
	for side: StringName in blank_sides:
		var wall: Dictionary = dungeon._sides_of(cell)[side]
		var yaw := float(wall["yaw"])
		var from_wall: Vector3 = vein.position - (wall["at"] as Vector3)
		var inward: float = from_wall.dot(Dungeon.facing_of(yaw))
		var lateral: float = absf(from_wall.dot(Dungeon.along_of(yaw)))
		if is_equal_approx(inward, WALL_INSET) \
				and lateral >= size * 0.20 - 0.01 \
				and lateral <= size * 0.28 + 0.01:
			return true
	return false


func _reward_table_exact() -> bool:
	var expected: Array[Dictionary] = [
		{"id": &"iron_scrap", "weight": 65, "amount": 3},
		{"id": &"riveted_plate", "weight": 22, "amount": 2},
		{"id": &"tension_coil", "weight": 13, "amount": 1},
	]
	if Dungeon.MINING_VEIN_REWARDS.size() != expected.size():
		return false
	for i: int in expected.size():
		var actual: Dictionary = Dungeon.MINING_VEIN_REWARDS[i]
		if StringName(actual.get("id", &"")) != StringName(expected[i]["id"]) \
				or int(actual.get("weight", 0)) != int(expected[i]["weight"]) \
				or int(actual.get("amount", 0)) != int(expected[i]["amount"]):
			return false
	return true


func _pickaxe_outside_armament(hero: Hero) -> bool:
	if Game.wheel.has(ToolDb.PICKAXE_ID) \
			or Game.RIGHT_POOL.has(ToolDb.PICKAXE_ID) \
			or Game.LEFT_POOL.has(ToolDb.PICKAXE_ID) \
			or Game.carry_ids().has(ToolDb.PICKAXE_ID) \
			or Run.bag.has(ToolDb.PICKAXE_ID) \
			or Game.stash.has(ToolDb.PICKAXE_ID) \
			or hero.combat._items.has(ToolDb.PICKAXE_ID):
		return false
	for set_data: Dictionary in Game.loadout:
		if set_data.values().has(ToolDb.PICKAXE_ID):
			return false
	return true


func _rebuild(rig) -> Dungeon:
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = &"DungeonOld"
		old.queue_free()
		var gone: bool = await rig.until(func() -> bool:
			return scene.get_node_or_null(^"DungeonOld") == null, 5.0)
		if not gone:
			return null
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	if script == null:
		return null
	var dungeon := script.new() as Dungeon
	if dungeon == null:
		return null
	dungeon.name = &"Dungeon"
	dungeon.seed_override = SEED
	scene.add_child(dungeon)
	await rig.wait_frames(14)
	return dungeon


func _clear_enemies(rig, dungeon: Dungeon) -> bool:
	for node: Node in _all(dungeon):
		if node is Enemy:
			node.queue_free()
	return await rig.until(func() -> bool:
		for node: Node in _all(dungeon):
			if node is Enemy:
				return false
		return true, 3.0)


func _veins(root: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node in _all(root):
		var body := node as Node3D
		var script := node.get_script() as Script
		if body != null and script != null \
				and script.resource_path == MINING_VEIN_SCRIPT:
			out.append(body)
	return out


func _direct_veins(room: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child: Node in room.get_children():
		var body := child as Node3D
		var script := child.get_script() as Script
		if body != null and script != null \
				and script.resource_path == MINING_VEIN_SCRIPT:
			out.append(body)
	return out


func _cell_for_vein(dungeon: Dungeon, vein: Node3D) -> Vector2i:
	for cell: Vector2i in dungeon.rooms:
		if dungeon.rooms[cell].get("node") == vein.get_parent():
			return cell
	return Vector2i(999999, 999999)


func _find_site(dungeon: Dungeon, site_id: StringName) -> Node3D:
	if dungeon == null:
		return null
	for vein: Node3D in _veins(dungeon):
		if StringName(vein.get(&"site_id")) == site_id:
			return vein
	return null


func _interaction_shape(vein: Node3D) -> CollisionShape3D:
	for child: Node in vein.get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			return shape
	return null


func _motes(scene: Node) -> Array[LootMote]:
	var out: Array[LootMote] = []
	for node: Node in scene.get_tree().get_nodes_in_group(LootMote.NAME_GROUP):
		var mote := node as LootMote
		if mote != null and is_instance_valid(mote):
			out.append(mote)
	return out


func _stand_at(hero: Hero, where: Vector3, target: Vector3) -> void:
	hero.global_position = Vector3(where.x, target.y + 0.05, where.z)
	hero.velocity = Vector3.ZERO
	var to: Vector3 = K.plane(target - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI


func _all(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child: Node in root.get_children():
		out.append_array(_all(child))
	return out
