extends RefCounted
## Issue #78 — prove a monster's body remains readable for at least as long as
## the health bar above it at the 8–10 m combat distance.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/dungeon.tscn --director=res://tools/directors/enemy_readability.gd --out=/tmp/enemy78/x.png --warmup=60
##
## This is one frozen gameplay pose through the real GameCamera. The first PNG
## disables only `EnemyReadFill`; the second enables it. Because the light sees
## only Enemy.READABILITY_LAYER, a correct pair changes the skeleton and nothing
## else — including the health bar that makes the original defect obvious.

const SEED := 20260809
const SUBJECT_DISTANCE := 9.0
const WALL_STANDOFF := 1.15
const REGION_PAD := 6

## A body occupies only part of its projected AABB, so the whole rectangle's
## mean is intentionally a smaller number than the gain on pixels the light
## actually reaches. Both must move: one hot pixel cannot pass this proof.
const MIN_AFFECTED_GAIN := 8.0
const MIN_AFFECTED_PIXELS := 80
const MIN_AFFECTED_SHARE := 0.005
const OUTSIDE_INK := 8
const MAX_OUTSIDE_INK_SHARE := 0.005
const MAX_OUTSIDE_MEAN_DELTA := 2.0
const WHITE_LUMA := 245
const MIN_LUMA_RANGE := 8

const SIDE_ORDER: Array[StringName] = [&"n", &"e", &"s", &"w"]

var _ok: bool = true


func run(rig) -> void:
	var out_dir: String = rig.arg("out", "/tmp/enemy78/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not _check(rig, rig.scene().name == &"DungeonRun",
			"wrong host scene (%s); use scenes/rooms/dungeon.tscn" % rig.scene().name):
		_summary()
		return

	Game.reset()
	Run.enter(SEED)
	var dungeon: Node = await _rebuild(rig)
	if not _check(rig, dungeon != null, "the fixed first floor did not build"):
		_summary()
		return

	var hero: Node3D = _hero(rig)
	var camera: GameCamera = _game_camera(rig)
	if not _check(rig, hero != null and camera != null,
			"the scene has no hero or no real GameCamera"):
		_summary()
		return
	camera.make_current()

	var fill := camera.get_node_or_null(^"EnemyReadFill") as DirectionalLight3D
	if not _check(rig, fill != null, "GameCamera/EnemyReadFill is missing"):
		_summary()
		return
	_check(rig, fill.get_parent() == camera, "EnemyReadFill is not a GameCamera child")
	_check(rig, fill.light_cull_mask == Enemy.READABILITY_LAYER,
		"EnemyReadFill cull mask is %d, expected only enemy layer %d"
			% [fill.light_cull_mask, Enemy.READABILITY_LAYER])
	_check(rig, fill.light_specular > 0.0 and fill.light_specular <= 1.0,
		"EnemyReadFill specular is outside (0, 1] (%.3f)" % fill.light_specular)
	_check(rig, is_zero_approx(fill.light_indirect_energy),
		"EnemyReadFill contributes indirect light (%.3f)" % fill.light_indirect_energy)
	_check(rig, is_zero_approx(fill.light_volumetric_fog_energy),
		"EnemyReadFill contributes volumetric fog light (%.3f)"
			% fill.light_volumetric_fog_energy)
	_check(rig, not fill.shadow_enabled, "EnemyReadFill casts shadows")
	_check(rig, fill.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY,
		"EnemyReadFill also illuminates the sky/environment")

	_clear_generated_enemies(dungeon)
	await rig.wait_frames(4)

	var fixture: Dictionary = _fixture(dungeon)
	if not _check(rig, not fixture.is_empty(),
			"the fixed floor has no plain masonry wall for the fixture"):
		_summary()
		return

	var room: Node3D = fixture[&"room"]
	_darken_room(room)
	await rig.wait_frames(4)
	rig.still_the_frame()
	var inward_local: Vector3 = fixture[&"inward"]
	var wall_local: Vector3 = fixture[&"wall"]
	var enemy_at: Vector3 = room.to_global(wall_local + inward_local * WALL_STANDOFF)
	enemy_at.y += 0.05
	var inward: Vector3 = (room.global_transform.basis * inward_local).normalized()
	var hero_at: Vector3 = enemy_at + inward * SUBJECT_DISTANCE
	hero_at.y = enemy_at.y

	var skeleton := Enemy.new()
	skeleton.name = "ReadabilitySkeleton"
	skeleton.kind = &"skeleton"
	skeleton.behaviour = &"none"
	skeleton.drop_seed = 7801
	room.add_child(skeleton)
	skeleton.global_position = enemy_at
	await rig.wait_frames(10)

	var meshes: Array[MeshInstance3D] = _meshes(skeleton)
	_check(rig, not meshes.is_empty(), "the skeleton model has no mesh surfaces")
	for mesh: MeshInstance3D in meshes:
		_check(rig, (mesh.layers & Enemy.READABILITY_LAYER) != 0,
			"%s is missing enemy readability layer %d" % [mesh.get_path(), Enemy.READABILITY_LAYER])
		_check(rig, (mesh.layers & ~Enemy.READABILITY_LAYER) != 0,
			"%s lost its existing visual layer(s)" % mesh.get_path())
	for mesh: MeshInstance3D in _meshes(hero):
		_check(rig, (mesh.layers & Enemy.READABILITY_LAYER) == 0,
			"the hero mesh %s also carries enemy readability layer %d"
				% [mesh.get_path(), Enemy.READABILITY_LAYER])
	for node: Node in _all(rig.scene()):
		if node is not MeshInstance3D \
				or ((node as MeshInstance3D).layers & Enemy.READABILITY_LAYER) == 0:
			continue
		var owner: Node = node
		while owner != null and owner is not Enemy:
			owner = owner.get_parent()
		_check(rig, owner is Enemy,
			"the non-enemy mesh %s also carries enemy readability layer %d"
				% [node.get_path(), Enemy.READABILITY_LAYER])

	_pose_hero(hero, hero_at, enemy_at)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(10)
	await rig.wait_frames(30)

	# CHASE is the gameplay condition that publishes the health bar. Avoid a
	# synthetic hit here: HitFlash would make the control frame white and turn
	# this into a test of the damage pulse instead of distance readability.
	skeleton.state = Enemy.State.CHASE
	skeleton.global_position = enemy_at
	skeleton.velocity = Vector3.ZERO
	_face(skeleton, hero_at - enemy_at)
	skeleton.set_physics_process(false)
	hero.set_physics_process(false)
	camera.set_physics_process(false)
	hero.visible = false
	_freeze_motion(rig.scene())

	var distance: float = hero.global_position.distance_to(skeleton.global_position)
	_check(rig, distance >= 8.0 and distance <= 10.0,
		"subject distance is %.2f m, outside the 8–10 m gameplay band" % distance)
	_check(rig, not camera.is_position_behind(skeleton.head_point()),
		"the skeleton is behind the gameplay camera")

	await rig.wait_frames(8)

	var before_path: String = out_dir.path_join("enemy_read_before.png")
	var after_path: String = out_dir.path_join("enemy_read_after.png")
	var fill_energy: float = fill.light_energy
	fill.light_energy = 0.0
	await rig.wait_frames(4)
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 0.0
	await rig.capture(before_path)
	var before: Image = Image.load_from_file(before_path)
	Engine.time_scale = previous_scale

	fill.light_energy = fill_energy
	await rig.wait_frames(3)
	Engine.time_scale = 0.0
	await rig.capture(after_path)
	var after: Image = Image.load_from_file(after_path)
	Engine.time_scale = previous_scale

	if not _check(rig, before != null and after != null,
			"the before/after PNG pair could not be read back"):
		_summary()
		return
	if not _check(rig, before.get_size() == after.get_size(),
			"before/after PNG sizes differ (%s vs %s)" % [before.get_size(), after.get_size()]):
		_summary()
		return
	if before.get_format() != Image.FORMAT_RGB8:
		before.convert(Image.FORMAT_RGB8)
	if after.get_format() != Image.FORMAT_RGB8:
		after.convert(Image.FORMAT_RGB8)

	var region: Rect2i = _body_rect(camera, skeleton, before.get_size())
	if not _check(rig, region.size.x > 0 and region.size.y > 0,
			"the skeleton has no projected body region"):
		_summary()
		return

	var score: Dictionary = _score_pair(before, after, region)
	print(("ENEMY READ distance=%.2fm region=%s before=%.2f after=%.2f gain=%.2f; "
		+ "affected=%d/%d (%.2f%%) gain=%.2f range=%d..%d clipped=%d; "
		+ "outside>1=%d outside>=%d=%d/%d mean=%.3f max=%d") % [
		distance, region, score[&"before_mean"], score[&"after_mean"],
		score[&"region_gain"], score[&"affected_px"], score[&"region_px"],
		100.0 * float(score[&"affected_px"]) / float(score[&"region_px"]),
		score[&"affected_gain"], score[&"affected_min"], score[&"affected_max"],
		score[&"clipped_px"], score[&"outside_px"], OUTSIDE_INK,
		score[&"outside_ink"], score[&"outside_total"], score[&"outside_mean"],
		score[&"outside_max"]])

	_check(rig, int(score[&"affected_px"]) >= MIN_AFFECTED_PIXELS,
		"only %d enemy-region pixels brightened materially (minimum %d)"
			% [score[&"affected_px"], MIN_AFFECTED_PIXELS])
	_check(rig, float(score[&"affected_px"]) / float(score[&"region_px"])
			>= MIN_AFFECTED_SHARE,
		"only %.2f%% of the enemy region brightened materially (minimum %.2f%%)"
			% [100.0 * float(score[&"affected_px"]) / float(score[&"region_px"]),
				MIN_AFFECTED_SHARE * 100.0])
	_check(rig, float(score[&"affected_gain"]) >= MIN_AFFECTED_GAIN,
		"lit enemy pixels rose only %.2f luma (minimum %.2f)"
			% [score[&"affected_gain"], MIN_AFFECTED_GAIN])
	_check(rig, int(score[&"clipped_px"]) == 0,
		"%d affected enemy pixel(s) clipped at luma %d" % [score[&"clipped_px"], WHITE_LUMA])
	_check(rig, int(score[&"affected_max"]) - int(score[&"affected_min"])
			>= MIN_LUMA_RANGE,
		"the lit body flattened to a %d-level luma range (minimum %d)"
			% [int(score[&"affected_max"]) - int(score[&"affected_min"]), MIN_LUMA_RANGE])
	_check(rig, float(score[&"outside_ink"]) / float(score[&"outside_total"])
			<= MAX_OUTSIDE_INK_SHARE and float(score[&"outside_mean"])
			<= MAX_OUTSIDE_MEAN_DELTA,
		("pixels outside the enemy region changed materially (%d at delta >= %d "
			+ "of %d, mean %.3f, worst %d)") % [score[&"outside_ink"], OUTSIDE_INK,
			score[&"outside_total"], score[&"outside_mean"], score[&"outside_max"]])

	var bars: Dictionary = Hud.enemy_bar_rects()
	var bar: Rect2 = bars.get(skeleton.get_instance_id(), Rect2())
	_check(rig, bar.size.x > 0.0 and _rust_pixels(after, bar) > 0,
		"the engaged skeleton has no rendered health bar")

	_summary()


func _rebuild(rig) -> Node:
	Run.level = Prog.FIRST
	var scene: Node = rig.scene()
	var old: Node = scene.get_node_or_null(^"Dungeon")
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
	await rig.wait_frames(14)
	return dungeon


func _clear_generated_enemies(dungeon: Node) -> void:
	for node: Node in _all(dungeon):
		if node is Enemy:
			node.queue_free()


func _darken_room(room: Node) -> void:
	# The reported frame is a far wall between sconce pools. Suppress this one
	# fixture room's animated local torches so the pair proves that exact worst
	# case without altering the authored wall, environment or gameplay camera.
	for node: Node in _all(room):
		if node is KitTorch:
			(node as KitTorch).visible = false


## A normal 16 m generated room and one wall with no doorway or authored anchor.
## The wall is real dungeon masonry; no director-only backdrop is manufactured.
func _fixture(dungeon: Node) -> Dictionary:
	var rooms: Dictionary = dungeon.get(&"rooms")
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		ordered.append(cell)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(rooms[a]["index"]) < int(rooms[b]["index"]))
	for cell: Vector2i in ordered:
		var row: Dictionary = rooms[cell]
		var size: float = float(row["size"])
		if size > 18.0 or cell == dungeon.get(&"entrance"):
			continue
		var room := row["node"] as Node3D
		if room == null:
			continue
		var doors: Array = row["doors"]
		var anchors: Dictionary = row["anchors"]
		for side: StringName in SIDE_ORDER:
			if doors.has(side) or anchors.has(side):
				continue
			var inward: Vector3 = _inward(side)
			return {
				&"room": room,
				&"inward": inward,
				&"wall": -inward * (size * 0.5),
				&"cell": cell,
				&"side": side,
			}
	return {}


func _inward(side: StringName) -> Vector3:
	match side:
		&"n":
			return Vector3.FORWARD
		&"s":
			return Vector3.BACK
		&"w":
			return Vector3.RIGHT
		&"e":
			return Vector3.LEFT
		_:
			return Vector3.ZERO


func _pose_hero(hero: Node3D, at: Vector3, look: Vector3) -> void:
	hero.global_position = at
	if hero is CharacterBody3D:
		(hero as CharacterBody3D).velocity = Vector3.ZERO
	var heading: Vector3 = K.flat(look - at).normalized()
	var yaw: float = atan2(heading.x, heading.z)
	hero.set(&"facing_yaw", yaw)
	hero.rotation.y = yaw + PI


func _face(enemy: Enemy, heading: Vector3) -> void:
	var flat: Vector3 = K.flat(heading).normalized()
	if flat != Vector3.ZERO:
		enemy.rotation.y = atan2(flat.x, flat.z) + PI


func _body_rect(camera: Camera3D, enemy: Enemy, size: Vector2i) -> Rect2i:
	var top: Vector2 = camera.unproject_position(enemy.head_point() + Vector3.UP * 0.35)
	var bottom: Vector2 = camera.unproject_position(enemy.global_position)
	var height: float = absf(bottom.y - top.y)
	if height < 1.0:
		return Rect2i()
	var centre_x: float = (top.x + bottom.x) * 0.5
	var half_width: float = height * 0.36
	var from := Vector2i(floori(centre_x - half_width) - REGION_PAD,
		floori(minf(top.y, bottom.y)) - REGION_PAD)
	var to := Vector2i(ceili(centre_x + half_width) + REGION_PAD,
		ceili(maxf(top.y, bottom.y)) + REGION_PAD)
	return Rect2i(from, to - from).intersection(Rect2i(Vector2i.ZERO, size))


## Compare actual RGB8 PNG bytes. `affected` means the fill increased luma and
## moved at least one channel by more than one byte; the outside count uses that
## same one-byte tolerance so harmless readback rounding cannot masquerade as a
## room-lighting change.
func _score_pair(before: Image, after: Image, region: Rect2i) -> Dictionary:
	var width: int = before.get_width()
	var height: int = before.get_height()
	var a: PackedByteArray = before.get_data()
	var b: PackedByteArray = after.get_data()
	var region_px: int = region.size.x * region.size.y
	var before_sum: int = 0
	var after_sum: int = 0
	var affected_px: int = 0
	var affected_gain_sum: int = 0
	var affected_min: int = 255
	var affected_max: int = 0
	var clipped_px: int = 0
	var outside_px: int = 0
	var outside_ink: int = 0
	var outside_sum: int = 0
	var outside_total: int = width * height - region_px
	var outside_max: int = 0

	for y: int in height:
		for x: int in width:
			var pixel: int = y * width + x
			var i: int = pixel * 3
			var before_luma: int = _luma(a[i], a[i + 1], a[i + 2])
			var after_luma: int = _luma(b[i], b[i + 1], b[i + 2])
			var delta: int = maxi(absi(int(a[i]) - int(b[i])), maxi(
				absi(int(a[i + 1]) - int(b[i + 1])),
				absi(int(a[i + 2]) - int(b[i + 2]))))
			if region.has_point(Vector2i(x, y)):
				before_sum += before_luma
				after_sum += after_luma
				if delta > 1 and after_luma > before_luma:
					affected_px += 1
					affected_gain_sum += after_luma - before_luma
					affected_min = mini(affected_min, after_luma)
					affected_max = maxi(affected_max, after_luma)
					if after_luma >= WHITE_LUMA:
						clipped_px += 1
			else:
				outside_sum += delta
				outside_max = maxi(outside_max, delta)
				if delta > 1:
					outside_px += 1
				if delta >= OUTSIDE_INK:
					outside_ink += 1

	return {
		&"region_px": region_px,
		&"before_mean": float(before_sum) / float(maxi(region_px, 1)),
		&"after_mean": float(after_sum) / float(maxi(region_px, 1)),
		&"region_gain": float(after_sum - before_sum) / float(maxi(region_px, 1)),
		&"affected_px": affected_px,
		&"affected_gain": float(affected_gain_sum) / float(maxi(affected_px, 1)),
		&"affected_min": affected_min if affected_px > 0 else 0,
		&"affected_max": affected_max,
		&"clipped_px": clipped_px,
		&"outside_px": outside_px,
		&"outside_ink": outside_ink,
		&"outside_total": outside_total,
		&"outside_mean": float(outside_sum) / float(maxi(outside_total, 1)),
		&"outside_max": outside_max,
	}


func _luma(r: int, g: int, b: int) -> int:
	return (r * 299 + g * 587 + b * 114) / 1000


func _rust_pixels(image: Image, rect: Rect2) -> int:
	var box: Rect2i = Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var count: int = 0
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var pixel: Color = image.get_pixel(x, y)
			if absi(int(roundf(pixel.r * 255.0)) - int(roundf(Pal.RUST.r * 255.0))) <= 1 \
					and absi(int(roundf(pixel.g * 255.0)) - int(roundf(Pal.RUST.g * 255.0))) <= 1 \
					and absi(int(roundf(pixel.b * 255.0)) - int(roundf(Pal.RUST.b * 255.0))) <= 1:
				count += 1
	return count


func _hero(rig) -> Node3D:
	var players: Array[Node] = rig.get_nodes_in_group(&"player")
	return players[0] as Node3D if not players.is_empty() else null


func _game_camera(rig) -> GameCamera:
	for node: Node in _all(rig.scene()):
		if node is GameCamera:
			return node as GameCamera
	return null


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in _all(root):
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			found.append(node as MeshInstance3D)
	return found


func _freeze_motion(root: Node) -> void:
	for node: Node in _all(root):
		if node is AnimationTree:
			(node as AnimationTree).active = false
		elif node is AnimationPlayer:
			(node as AnimationPlayer).pause()
		elif node is GPUParticles3D:
			(node as GPUParticles3D).speed_scale = 0.0


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found


func _check(rig, condition: bool, message: String) -> bool:
	if condition:
		return true
	_ok = false
	rig.fail("ENEMY READ " + message)
	return false


func _summary() -> void:
	print("ENEMY READ OK — body lift is isolated and the health bar remains visible"
		if _ok else "ENEMY READ FAIL — see failed checks above")
