extends RefCounted
## Runtime proof for Floor 1's generated Drowned Bronze visual layer.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/floor_lookdev.gd \
##     --out=/tmp/floor-lookdev/x.png --size=1280x720 --warmup=60

const SEED := 20260809
const EYE_HEIGHT := 1.65
const DARK_LUMA := 16
const DARK_MAX_SHARE := 35.0
const MEAN_LUMA_MIN := 28.0
const MEAN_LUMA_MAX := 48.0
const CLIPPED_MAX_SHARE := 1.0


func run(rig) -> void:
	var failures_before: int = rig.fails
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not rig.check(rig.scene().name == &"DungeonRun",
			"FLOOR LOOKDEV requires res://scenes/rooms/dungeon.tscn"):
		return

	Game.reset()
	Run.enter(SEED)
	var dungeon: Node3D = await _rebuild(rig)
	if not rig.check(dungeon != null, "Floor 1 rebuilt from the fixed lookdev seed"):
		return
	_clear_floor(rig)
	_hide_proof_only_clutter(rig)
	await rig.wait_frames(12)
	rig.still_the_frame()

	var rooms: Dictionary = dungeon.get(&"rooms")
	var look := dungeon.get_node_or_null(^"CisternLook") as Node3D
	if not rig.check(look != null, "CisternLook exists beneath the generated Dungeon"):
		return
	_prove_structure(rig, look, rooms)

	var entrance := _entrance_cell(rooms)
	var deepest := _deepest_cell(rooms)
	var gate: Variant = _placement_cell(dungeon, &"gate_room")
	var plain: Variant = _plain_cell(rooms, entrance, deepest, gate)
	if not rig.check(gate != null, "the generated gate-path room is identifiable"):
		return
	if not rig.check(plain != null, "the generated floor has a distinct plain room"):
		return
	var gate_cell: Vector2i = gate
	var plain_cell: Vector2i = plain
	var distinct: Dictionary = {
		entrance: true, plain_cell: true, gate_cell: true, deepest: true,
	}
	if not rig.check(distinct.size() == 4,
			"entrance, plain, gate-path, and deepest are four distinct rooms"):
		return
	_prove_landmark_rooms(rig, look, entrance, gate_cell, deepest)

	var hero := _hero(rig)
	if hero != null:
		hero.visible = false
	Bus.screen_opened.emit(&"floor_lookdev")
	var camera := Camera3D.new()
	camera.name = &"FloorLookdevCamera"
	camera.fov = 58.0
	rig.scene().add_child(camera)
	camera.make_current()
	# Hud restores itself after any node-added notification. Add the proof camera
	# first, let that deferred refresh finish, then hide it for every capture.
	await rig.wait_frames(2)
	if Hud != null:
		Hud.visible = false
	var out: String = rig.out_base().get_base_dir()

	await _capture_room(rig, camera, look, entrance, rooms[entrance],
		out.path_join("floor_look_01_entrance.png"))
	await _capture_room(rig, camera, look, plain_cell, rooms[plain_cell],
		out.path_join("floor_look_02_plain_room.png"))
	await _capture_room(rig, camera, look, gate_cell, rooms[gate_cell],
		out.path_join("floor_look_03_gate_path.png"), true)
	await _capture_room(rig, camera, look, deepest, rooms[deepest],
		out.path_join("floor_look_04_deepest.png"))
	await _capture_corridor(rig, camera, dungeon,
		out.path_join("floor_look_05_corridor.png"))
	Bus.screen_closed.emit(&"floor_lookdev")

	if rig.fails == failures_before:
		print("FLOOR LOOKDEV OK -- %d rooms, %d bays, %d overflow frames, 5 frames"
			% [rooms.size(), _named(look, &"CisternBay").size(),
				_named(look, &"OverflowFrame").size()])


func _prove_structure(rig, look: Node3D, rooms: Dictionary) -> void:
	var bays: Array[Node] = _named(look, &"CisternBay")
	var runnels: Array[Node] = _named(look, &"WaterRunnel")
	var frames: Array[Node] = _named(look, &"OverflowFrame")
	var service_drains: Array[Node] = _named(look, &"ServiceDrain")
	var damp_courses: Array[Node] = _named(look, &"DampCourse")
	rig.check(bays.size() == rooms.size(),
		"exactly one CisternBay exists per generated room (%d/%d)"
		% [bays.size(), rooms.size()])
	rig.check(runnels.size() == rooms.size(),
		"exactly one water runnel exists per generated room (%d/%d)"
		% [runnels.size(), rooms.size()])
	rig.check(frames.size() >= 3,
		"at least three full OverflowFrame landmarks exist (%d)" % frames.size())
	rig.check(service_drains.size() == bays.size() - frames.size(),
		"every non-landmark bay owns one ServiceDrain (%d/%d)"
		% [service_drains.size(), bays.size() - frames.size()])
	rig.check(damp_courses.size() == rooms.size(),
		"exactly one DampCourse exists per generated room (%d/%d)"
		% [damp_courses.size(), rooms.size()])
	for frame: Node in frames:
		rig.check(_named(frame, &"OverflowBucket").size() == 1,
			"OverflowFrame %s owns one suspended OverflowBucket" % frame.get_path())

	for cell: Vector2i in rooms:
		var cell_bays := 0
		var cell_water := 0
		var cell_damp := 0
		for node: Node in bays:
			if node.get_meta(&"cell", Vector2i(9999, 9999)) == cell:
				cell_bays += 1
				cell_water += _named(node, &"WaterRunnel").size()
				cell_damp += _named(node.get_parent(), &"DampCourse").size()
		rig.check(cell_bays == 1 and cell_water == 1 and cell_damp == 1,
			"room %s owns one bay, runnel, and damp course" % cell)

	var collision_count := 0
	for node: Node in _all(look):
		if node is CollisionObject3D:
			collision_count += 1
	rig.check(collision_count == 0,
		"CisternLook contains no CollisionObject3D (%d)" % collision_count)

	var white_materials: Array[String] = []
	var unhandled_materials: Array[String] = []
	for node: Node in _all(look):
		if not node is MeshInstance3D:
			continue
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface: int in instance.mesh.get_surface_count():
			var material: Material = instance.get_active_material(surface)
			if not material is StandardMaterial3D:
				unhandled_materials.append("%s[%d]" % [instance.name, surface])
				continue
			var standard := material as StandardMaterial3D
			if standard.albedo_texture == null and standard.albedo_color.r > 0.95 \
					and standard.albedo_color.g > 0.95 \
					and standard.albedo_color.b > 0.95:
				white_materials.append("%s[%d]" % [instance.name, surface])
	rig.check(unhandled_materials.is_empty(),
		"every added mesh uses a sanitized StandardMaterial3D (%s)"
		% [unhandled_materials])
	rig.check(white_materials.is_empty(),
		"no material beneath CisternLook is fallback white (%s)" % [white_materials])


func _prove_landmark_rooms(rig, look: Node3D, entrance: Vector2i,
		gate: Vector2i, deepest: Vector2i) -> void:
	for pair: Array in [
		["entrance", entrance], ["gate-path", gate], ["deepest", deepest],
	]:
		var bay := _bay_for(look, pair[1])
		var has_frame := bay != null and not _named(bay, &"OverflowFrame").is_empty()
		rig.check(has_frame, "%s room carries its full OverflowFrame" % pair[0])
		if bay == null:
			continue
		var role := StringName(bay.get_meta(&"landmark_role", &""))
		var expected: StringName = {
			"entrance": &"entrance", "gate-path": &"gate", "deepest": &"deepest",
		}[pair[0]]
		rig.check(role == expected,
			"%s room carries its unique %s silhouette role" % [pair[0], expected])
	var entrance_bay := _bay_for(look, entrance)
	var gate_bay := _bay_for(look, gate)
	var deepest_bay := _bay_for(look, deepest)
	rig.check(entrance_bay != null and _named(entrance_bay, &"EntranceCrown").size() == 1,
		"entrance landmark owns one stepped EntranceCrown")
	rig.check(gate_bay != null and _named(gate_bay, &"GateCounterweight").size() == 1,
		"gate landmark owns one asymmetric GateCounterweight")
	rig.check(deepest_bay != null and _named(deepest_bay, &"DeepestHood").size() == 1,
		"deepest landmark owns one broad DeepestHood")


func _capture_room(rig, camera: Camera3D, look: Node3D, cell: Vector2i,
		room: Dictionary, path: String, gate_view: bool = false) -> void:
	var bay := _bay_for(look, cell)
	if not rig.check(bay != null, "room %s has a bay to frame" % cell):
		return
	var composition: Dictionary
	if gate_view:
		composition = _gate_route_composition(rig, camera, bay, room)
	elif not _named(bay, &"ServiceDrain").is_empty():
		composition = _plain_room_composition(rig, bay, room)
	else:
		composition = _landmark_route_composition(rig, bay, room)
	if composition.is_empty():
		return
	camera.fov = float(composition[&"fov"])
	camera.global_position = composition[&"origin"] as Vector3
	camera.look_at(composition[&"aim"] as Vector3, Vector3.UP)
	await rig.wait_frames(8)
	_hide_proof_only_clutter(rig)
	if Hud != null:
		Hud.visible = false
	await rig.capture(path)
	_prove_luma(rig, path)


func _landmark_route_composition(rig, bay: Node3D, room: Dictionary) -> Dictionary:
	var room_node := room.get("node") as Node3D
	if room_node == null:
		return {}
	var doors: Array = room.get("doors", [])
	if not rig.check(not doors.is_empty(),
			"landmark room exposes a generated retreat route"):
		return {}
	var doorway := _doorway_pose(room, doors[0] as StringName)
	if doorway.is_empty():
		return {}
	var route_focus: Vector3 = doorway[&"centre"] + Vector3.UP * 1.55
	var bay_focus := bay.global_position + Vector3.UP * 2.10
	var room_eye := room_node.global_position + Vector3.UP * EYE_HEIGHT
	var to_bay := (bay_focus - room_eye).normalized()
	var to_route := (route_focus - room_eye).normalized()
	var aim_direction := (to_bay + to_route).normalized()
	if aim_direction.is_zero_approx():
		aim_direction = to_bay
	return {
		&"origin": room_eye,
		&"aim": room_eye + aim_direction * float(room.get("size", 16.0)),
		# The fixed proof must show both the landmark mass and a retreat door,
		# even when generation places them on opposite walls.
		&"fov": 78.0,
	}


func _plain_room_composition(rig, bay: Node3D, room: Dictionary) -> Dictionary:
	var drains: Array[Node] = _named(bay, &"ServiceDrain")
	if not rig.check(drains.size() == 1,
			"plain room owns one ServiceDrain to compose (%d)" % drains.size()):
		return {}
	var drain := drains[0] as Node3D
	var closest_edge := Vector3.ZERO
	var closest_distance := INF
	var found_doorway := false
	var doors: Array = room.get("doors", [])
	for side: StringName in doors:
		var doorway: Dictionary = _doorway_pose(room, side)
		if doorway.is_empty():
			continue
		var centre: Vector3 = doorway[&"centre"]
		var along: Vector3 = doorway[&"along"]
		var half_span := float(doorway[&"opening_w"]) * 0.5
		for edge_sign: float in [-1.0, 1.0]:
			var edge := centre + along * edge_sign * half_span
			var distance := edge.distance_squared_to(drain.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_edge = edge
				found_doorway = true
	if not rig.check(found_doorway,
			"plain room exposes a generated route doorway to frame with its drain"):
		return {}

	var room_node := room.get("node") as Node3D
	if room_node == null:
		return {}
	var drain_focus := drain.global_position + Vector3.UP * 1.55
	var edge_focus := closest_edge + Vector3.UP * 1.65
	var room_eye := room_node.global_position + Vector3.UP * EYE_HEIGHT
	var room_size := float(room.get("size", 16.0))
	var to_drain := (drain_focus - room_eye).normalized()
	var to_edge := (edge_focus - room_eye).normalized()
	var aim_direction := (to_drain + to_edge).normalized()
	# The angular bisector, rather than a world-space midpoint, keeps both the
	# drain and jamb at equal visual weight on their opposite room walls. The
	# centre point keeps the hydraulic work close enough to read as architecture.
	return {
		&"origin": room_eye,
		&"aim": room_eye + aim_direction * room_size,
		&"fov": 58.0,
	}


func _gate_route_composition(rig, camera: Camera3D, bay: Node3D,
		room: Dictionary) -> Dictionary:
	var targets: Array[Vector3] = _landmark_targets(bay)
	if not rig.check(not targets.is_empty(),
			"gate room exposes OverflowFrame silhouette targets"):
		return {}
	var doors: Array = room.get("doors", [])
	if not rig.check(not doors.is_empty(),
			"gate room exposes at least one generated gameplay route"):
		return {}
	var room_node := room.get("node") as Node3D
	if room_node == null:
		return {}
	var aim := Vector3.ZERO
	for target: Vector3 in targets:
		aim += target
	aim /= float(targets.size())

	var best: Dictionary = {}
	var best_clear := -1
	var best_axis_distance := INF
	var route_depth := K.CORRIDOR_W * 0.65
	for side: StringName in doors:
		var doorway: Dictionary = _doorway_pose(room, side)
		if doorway.is_empty():
			continue
		var centre: Vector3 = doorway[&"centre"]
		var outward: Vector3 = doorway[&"outward"]
		var along: Vector3 = doorway[&"along"]
		var route_offset := minf(K.CORRIDOR_W * 0.32,
			float(doorway[&"opening_w"]) * 0.34)
		for offset: float in [0.0, -route_offset, route_offset]:
			var origin := centre + outward * route_depth + along * offset \
				+ Vector3.UP * EYE_HEIGHT
			var clear := _clear_landmark_rays(camera, origin, targets)
			var view_axis := (aim - origin).normalized()
			var centre_at_eye := room_node.global_position + Vector3.UP * EYE_HEIGHT
			var centre_delta := centre_at_eye - origin
			var axis_distance := (centre_delta
				- view_axis * centre_delta.dot(view_axis)).length()
			if clear > best_clear or (clear == best_clear
					and axis_distance < best_axis_distance):
				best = {&"origin": origin, &"aim": aim, &"fov": 52.0}
				best_clear = clear
				best_axis_distance = axis_distance
	if best.is_empty():
		rig.check(false, "gate route camera resolves to a generated doorway")
		return {}
	var required_score := maxi(targets.size() - 1, 1)
	if not rig.check(best_clear >= required_score,
			"gate route clears %d/%d landmark silhouette rays"
			% [best_clear, targets.size()]):
		return {}
	return best


func _doorway_pose(room: Dictionary, side: StringName) -> Dictionary:
	var room_node := room.get("node") as Node3D
	if room_node == null:
		return {}
	var local_outward := _door_outward(side)
	var expected := room_node.to_global(
		local_outward * float(room.get("size", 16.0)) * 0.5)
	var doorway: KitDoorway = null
	var closest := INF
	for child: Node in room_node.get_children():
		if not child is KitDoorway:
			continue
		var candidate := child as KitDoorway
		var distance := candidate.global_position.distance_squared_to(expected)
		if distance < closest:
			closest = distance
			doorway = candidate
	if doorway == null:
		return {}
	return {
		&"centre": doorway.global_position,
		&"outward": (room_node.global_transform.basis * local_outward).normalized(),
		&"along": doorway.global_transform.basis.x.normalized(),
		&"opening_w": doorway.opening_w,
	}


func _door_outward(side: StringName) -> Vector3:
	match side:
		&"n": return Vector3(0.0, 0.0, -1.0)
		&"s": return Vector3(0.0, 0.0, 1.0)
		&"w": return Vector3(-1.0, 0.0, 0.0)
		_: return Vector3(1.0, 0.0, 0.0)


func _landmark_targets(bay: Node3D) -> Array[Vector3]:
	var targets: Array[Vector3] = []
	var frames: Array[Node] = _named(bay, &"OverflowFrame")
	if frames.is_empty():
		return targets
	var frame := frames[0] as Node3D
	var inward := bay.global_transform.basis.z.normalized()
	targets.append(frame.global_position + inward * 0.42 + Vector3.UP * 1.50)
	for pier: Node in _named(frame, &"OverflowPier"):
		targets.append((pier as Node3D).global_position + inward * 0.20 + Vector3.UP * 1.45)
	var lintels: Array[Node] = _named(frame, &"BronzeLintel")
	if not lintels.is_empty():
		targets.append((lintels[0] as Node3D).global_position + inward * 0.10)
	return targets


func _clear_landmark_rays(camera: Camera3D, origin: Vector3,
		targets: Array[Vector3]) -> int:
	var clear := 0
	for target: Vector3 in targets:
		var query := PhysicsRayQueryParameters3D.create(origin, target, K.L_WORLD)
		var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 0.60:
			clear += 1
	return clear


func _capture_corridor(rig, camera: Camera3D, dungeon: Node3D,
		path: String) -> void:
	var corridor: Node3D = null
	for child: Node in dungeon.get_children():
		if child is Node3D and child.name.begins_with("Corr_"):
			corridor = child as Node3D
			break
	if not rig.check(corridor != null, "a generated corridor exists for the support frame"):
		return
	var floor_slab: KitSlab = null
	for child: Node in corridor.get_children():
		if child is KitSlab and not (child as KitSlab).ceiling:
			floor_slab = child as KitSlab
			break
	if not rig.check(floor_slab != null, "the corridor has its generated floor slab"):
		return
	var running_z := floor_slab.size.y >= floor_slab.size.x
	var axis := Vector3(0.0, 0.0, 1.0) if running_z else Vector3(1.0, 0.0, 0.0)
	camera.global_position = corridor.global_position + axis * 5.0 \
		+ Vector3.UP * 1.50
	camera.fov = 66.0
	camera.look_at(corridor.global_position - axis * 4.2 + Vector3.UP * 1.30,
		Vector3.UP)
	await rig.wait_frames(8)
	if Hud != null:
		Hud.visible = false
	await rig.capture(path)
	_prove_luma(rig, path)


func _prove_luma(rig, path: String) -> void:
	var image := Image.load_from_file(path)
	if not rig.check(image != null, "%s can be read back for luma proof" % path):
		return
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	var bytes := image.get_data()
	var pixels := image.get_width() * image.get_height()
	var dark := 0
	var sum := 0
	var clipped := 0
	var i := 0
	while i < bytes.size():
		var luma: int = (int(bytes[i]) * 299 + int(bytes[i + 1]) * 587 \
			+ int(bytes[i + 2]) * 114) / 1000
		sum += luma
		if luma < DARK_LUMA:
			dark += 1
		if luma > 224:
			clipped += 1
		i += 3
	var dark_share := 100.0 * float(dark) / float(maxi(pixels, 1))
	var mean := float(sum) / float(maxi(pixels, 1))
	var clipped_share := 100.0 * float(clipped) / float(maxi(pixels, 1))
	print("FLOOR LUMA %s dark<%d=%.2f%% mean=%.2f clipped>224=%.2f%%"
		% [path.get_file(), DARK_LUMA, dark_share, mean, clipped_share])
	rig.check(dark_share <= DARK_MAX_SHARE,
		"%s preserves readable shadow (dark<%d %.2f%% <= %.2f%%)"
		% [path.get_file(), DARK_LUMA, dark_share, DARK_MAX_SHARE])
	rig.check(mean >= MEAN_LUMA_MIN and mean <= MEAN_LUMA_MAX,
		"%s carries dark-warm range (mean %.2f in %.2f..%.2f)"
		% [path.get_file(), mean, MEAN_LUMA_MIN, MEAN_LUMA_MAX])
	rig.check(clipped_share <= CLIPPED_MAX_SHARE,
		"%s preserves highlight shape (clipped>224 %.2f%% <= %.2f%%)"
		% [path.get_file(), clipped_share, CLIPPED_MAX_SHARE])


func _rebuild(rig) -> Node3D:
	Run.level = 1
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = &"DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var dungeon := script.new() as Node3D
	if dungeon == null:
		return null
	dungeon.name = &"Dungeon"
	dungeon.set(&"seed_override", SEED)
	scene.add_child(dungeon)
	await rig.wait_frames(12)
	return dungeon


func _clear_floor(rig) -> void:
	var cleared := 0
	for node: Node in _all(rig.scene()):
		if node is Enemy or node is Arrow or node is BurstCast:
			node.queue_free()
			cleared += 1
	print("FLOOR LOOKDEV cleared %d enemies/projectiles" % cleared)


func _hide_proof_only_clutter(rig) -> void:
	var hidden := 0
	for node: Node in _all(rig.scene()):
		var proof_clutter := node is ExplosiveBarrel or node.name == &"RoomChest" \
			or node.name.begins_with("AmbientUrn")
		if proof_clutter and node is Node3D and (node as Node3D).visible:
			(node as Node3D).visible = false
			hidden += 1
	print("FLOOR LOOKDEV proof-only clutter hidden: %d" % hidden)


func _entrance_cell(rooms: Dictionary) -> Vector2i:
	for cell: Vector2i in rooms:
		if int(rooms[cell]["index"]) == 0:
			return cell
	return Vector2i.ZERO


func _deepest_cell(rooms: Dictionary) -> Vector2i:
	var deepest := Vector2i.ZERO
	var distance := -1
	for cell: Vector2i in rooms:
		var candidate := int(rooms[cell]["dist"])
		if candidate > distance:
			distance = candidate
			deepest = cell
	return deepest


func _placement_cell(dungeon: Node, id: StringName) -> Variant:
	var placements: Dictionary = dungeon.get(&"placements")
	if placements.has(id):
		return placements[id].get("cell")
	return null


func _plain_cell(rooms: Dictionary, entrance: Vector2i, deepest: Vector2i,
		gate: Variant) -> Variant:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(rooms[a]["index"]) < int(rooms[b]["index"]))
	for cell: Vector2i in cells:
		if cell == entrance or cell == deepest or (gate != null and cell == gate):
			continue
		var anchors: Dictionary = rooms[cell].get("anchors", {})
		if anchors.is_empty():
			return cell
	return null


func _bay_for(look: Node, cell: Vector2i) -> Node3D:
	for node: Node in _named(look, &"CisternBay"):
		if node.get_meta(&"cell", Vector2i(9999, 9999)) == cell:
			return node as Node3D
	return null


func _hero(rig) -> Node3D:
	var heroes: Array = rig.get_nodes_in_group(&"player")
	return heroes[0] as Node3D if not heroes.is_empty() else null


func _named(root: Node, node_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in _all(root):
		if node.name == node_name:
			found.append(node)
	return found


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found
