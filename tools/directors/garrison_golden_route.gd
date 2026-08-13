extends RefCounted
## Real-controller traversal proof for the authored garrison floor plan.
##
## This director never replaces the production chase camera and never teleports
## between rooms. The one initial placement is the fixture; every doorway,
## garden opening, aisle, open gate, bridge, and homestead path are exercised through
## the Hero's live camera-relative action-state controller.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_golden_route.gd \
##     --out=/tmp/garrison-golden/x.png --size=1280x720 --warmup=60

const TARGET_RADIUS := 0.72
const STALL_SECONDS := 1.15
const STALL_PROGRESS := 0.22

var _out := ""
var _garrison: Garrison
var _compound: GarrisonCompound
var _outskirts: GarrisonOutskirts
var _hero: Hero


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "golden route loaded the real Garrison"):
		return
	_garrison = garrison
	_compound = garrison.compound
	_outskirts = garrison.outskirts
	_hero = garrison.get_tree().get_first_node_in_group(&"player") as Hero
	var camera := garrison.get_node_or_null("GameCamera") as GameCamera
	if not rig.check(_compound != null and _outskirts != null and _hero != null,
			"golden route has the live compound, outskirts, and Hero"):
		return
	if not rig.check(camera != null and camera.current
			and _hero.get_viewport().get_camera_3d() == camera,
			"the production GameCamera is current"):
		return

	Clock.running = false
	Clock.set_time(1, 12.0)
	_out = rig.out_base().get_base_dir()
	_stage_at_arrival()
	await rig.wait_physics_frames(6)

	# Arrival threshold -> Elder. The player's first sightline and first service
	# prompt must survive the rebuilt gate plaza.
	if not await _walk_many(rig, "arrival to Elder", [
		Vector3(0.0, 0.0, 9.7), Vector3(-0.9, 0.0, 9.25),
	]):
		return
	if not await _expect_prompt(rig, garrison.keeper, "Elder"):
		return
	await _shot(rig, "route_00_elder.png")

	# Enter the garden through its east opening, meet the alchemist beneath the
	# trellis, then leave through the separate north opening.
	if not await _walk_many(rig, "garden east opening", [
		Vector3(-2.4, 0.0, 6.4), Vector3(-3.2, 0.0, 1.5),
		Vector3(-4.75, 0.0, 0.0), Vector3(-7.2, 0.0, -1.0),
	]):
		return
	if not await _expect_prompt(rig, garrison.alchemist, "garden alchemist"):
		return
	if not await _walk_many(rig, "garden north opening", [
		Vector3(-7.7, 0.0, -3.45), Vector3(-7.7, 0.0, -5.25),
	]):
		return
	await _shot(rig, "route_01_garden_openings.png")

	# Barracks east door, sleeping-room aisle, and back out the same real door.
	if not await _walk_many(rig, "barracks entry", [
		Vector3(-11.8, 0.0, -6.0), Vector3(-12.4, 0.0, -10.2),
		Vector3(-15.15, 0.0, -10.2), Vector3(-16.45, 0.0, -12.15),
	]):
		return
	await _shot(rig, "route_02_barracks.png")
	if not await _walk_many(rig, "barracks exit", [
		Vector3(-15.15, 0.0, -10.2), Vector3(-12.35, 0.0, -10.2),
	]):
		return

	# The table's south circulation line was a prior obstruction risk. Reaching
	# within one controller radius of this named point proves the aisle, not a
	# teleport into the furniture collision.
	if not await _walk_many(rig, "mess hall entry and table aisle", [
		Vector3(-10.4, 0.0, -9.4), Vector3(-6.9, 0.0, -10.25),
		Vector3(-6.9, 0.0, -12.15), Vector3(-4.05, 0.0, -12.15),
	]):
		return
	# Use a tighter final controller target here: the usual route radius is
	# intentionally generous, but crossing the old bench line is the measurement.
	if not await _walk_to(rig, Vector3(-5.6, 0.0, -13.58),
			"mess hall table clearance", 0.16):
		return
	if not rig.check(_flat_gap(Vector3(-5.6, 0.0, -13.45)) <= TARGET_RADIUS,
			"the Hero crossed the mess aisle near (-5.6, -13.45)"):
		return
	await _shot(rig, "route_03_mess_hall.png")
	if not await _walk_many(rig, "mess hall exit", [
		Vector3(-5.6, 0.0, -12.15), Vector3(-6.9, 0.0, -12.15),
		Vector3(-6.9, 0.0, -10.25),
	]):
		return

	# Cross the north court and enter the Elder's private room through its south
	# doorway; the rug is walkable while the desk and bed remain solid.
	if not await _walk_many(rig, "leader room", [
		Vector3(-3.5, 0.0, -8.1), Vector3(4.0, 0.0, -8.0),
		Vector3(10.8, 0.0, -8.1), Vector3(12.7, 0.0, -9.0),
		Vector3(12.7, 0.0, -11.0), Vector3(13.35, 0.0, -12.65),
	]):
		return
	await _shot(rig, "route_04_leader_room.png")
	if not await _walk_many(rig, "leader room exit", [
		Vector3(12.7, 0.0, -11.0), Vector3(12.7, 0.0, -8.8),
	]):
		return

	# West craft rooms are intentionally separate destinations, approached from
	# the yard and entered through their own doors rather than a line of booths.
	if not await _walk_many(rig, "smithy", [
		Vector3(7.0, 0.0, -7.2), Vector3(0.0, 0.0, -7.2),
		Vector3(-10.8, 0.0, -7.0), Vector3(-13.2, 0.0, -3.75),
		Vector3(-15.85, 0.0, -3.75), Vector3(-16.3, 0.0, -4.65),
	]):
		return
	if not await _expect_prompt(rig, garrison.smith, "smith service"):
		return
	await _shot(rig, "route_05_smithy.png")
	if not await _walk_many(rig, "smithy exit", [
		Vector3(-15.85, 0.0, -3.75), Vector3(-13.2, 0.0, -3.75),
		Vector3(-12.1, 0.0, -2.0),
	]):
		return

	if not await _walk_many(rig, "jewelcrafter aisle", [
		Vector3(-12.1, 0.0, 3.55), Vector3(-15.25, 0.0, 3.55),
		Vector3(-16.3, 0.0, 3.55),
	]):
		return
	if not await _expect_prompt(rig, garrison.jeweller, "jewelcrafter service"):
		return
	if not rig.check(_flat_gap(Vector3(-16.3, 0.0, 3.55)) <= TARGET_RADIUS,
			"the Hero reached the jeweller aisle at z=3.55"):
		return
	await _shot(rig, "route_06_jewelcrafter.png")
	if not await _walk_many(rig, "jewelcrafter exit", [
		Vector3(-15.2, 0.0, 3.55), Vector3(-12.0, 0.0, 3.55),
	]):
		return

	# Builder, west supply, east supply, and quartermaster are four distinct
	# interior beats around the south half of the court.
	if not await _walk_many(rig, "builder workshop", [
		Vector3(-12.0, 0.0, 7.4), Vector3(-12.0, 0.0, 11.1),
		Vector3(-14.55, 0.0, 11.1),
	]):
		return
	# Builder recruitment is later progression and the screenshot harness does
	# not force it. Traverse the room regardless; prove the prompt when present.
	if garrison.builder != null \
			and not await _expect_prompt(rig, garrison.builder, "builder service"):
		return
	await _shot(rig, "route_07_builder.png")
	if not await _walk_many(rig, "builder exit and west supply", [
		# The west supply room forms the north jamb of this shared service lane;
		# leave through the builder door's clear southern half.
		Vector3(-14.0, 0.0, 10.4), Vector3(-12.0, 0.0, 10.4),
		Vector3(-9.95, 0.0, 10.8),
		Vector3(-9.95, 0.0, 13.05),
	]):
		return
	await _shot(rig, "route_08_west_supply.png")
	if not await _walk_many(rig, "west supply exit", [
		Vector3(-9.95, 0.0, 10.75), Vector3(-4.5, 0.0, 9.8),
		# The deposit crate deliberately anchors the east side of the gate plaza.
		# Follow the open court around its south face instead of clipping through it.
		Vector3(2.6, 0.0, 8.2),
	]):
		return
	if not await _walk_many(rig, "east supply", [
		Vector3(5.8, 0.0, 8.2), Vector3(7.0, 0.0, 9.5),
		Vector3(10.05, 0.0, 10.75),
		Vector3(10.05, 0.0, 13.05),
	]):
		return
	await _shot(rig, "route_09_east_supply.png")
	if not await _walk_many(rig, "east supply exit and quartermaster", [
		Vector3(10.05, 0.0, 10.75), Vector3(11.5, 0.0, 8.6),
		Vector3(11.5, 0.0, 4.3), Vector3(14.2, 0.0, 4.3),
	]):
		return
	if not await _expect_prompt(rig, garrison.vendor, "quartermaster service"):
		return
	await _shot(rig, "route_10_quartermaster.png")

	# The former loading seam is now a real route. Cross the open portcullis and
	# timber bridge, follow the authored spine to the mine, then prove both civil
	# branches from the clearing without ever changing scenes or teleporting.
	if not await _walk_many(rig, "gate approach", [
		Vector3(11.5, 0.0, 4.3), Vector3(9.8, 0.0, 8.6),
		Vector3(5.8, 0.0, 8.2), Vector3(2.6, 0.0, 8.2),
		Vector3(1.5, 0.0, 12.0),
		Vector3(0.0, 0.0, 15.0),
	]):
		return
	if not await _walk_to(rig, Vector3(0.0, 0.0, 17.8), "open gate threshold"):
		return
	var spine: Array = []
	# The path contract runs threshold -> mine. Stop at the authored approach;
	# MINE_MOUTH itself is deliberately behind the dark portal collision.
	for point_index: int in GarrisonOutskirts.PATH_POINTS.size() - 1:
		var point := GarrisonOutskirts.PATH_POINTS[point_index]
		if point.is_equal_approx(OutskirtsHomestead.CLEARING_CENTER):
			# The statue occupies the mathematical route centre. The visible round
			# path is the route, so exercise its south arc instead of its plinth.
			spine.append(_outside(Vector3(-3.4, 0.0, -3.2)))
			spine.append(_outside(Vector3(3.4, 0.0, -3.2)))
		else:
			spine.append(_outside(point))
	if not await _walk_many(rig, "bridge and mine spine", spine):
		return
	if not await _walk_to(rig, _outside(OutskirtsHomestead.MINE_APPROACH),
			"Sunken Cut approach", 0.9):
		return
	if not await _expect_prompt(rig, _garrison.sunken_cut, "Sunken Cut descent"):
		return
	await _shot(rig, "route_11_sunken_cut.png")

	var return_to_clearing: Array = []
	for point_index: int in range(GarrisonOutskirts.PATH_POINTS.size() - 2, 7, -1):
		return_to_clearing.append(_outside(GarrisonOutskirts.PATH_POINTS[point_index]))
	return_to_clearing.append(_outside(Vector3(3.4, 0.0, -3.2)))
	if not await _walk_many(rig, "mine return to clearing", return_to_clearing):
		return
	if not await _walk_many(rig, "clearing to grove", [
		_outside(Vector3(5.8, 0.0, -5.5)),
		_outside(Vector3(0.0, 0.0, -8.5)),
		_outside(Vector3(-7.0, 0.0, -6.0)),
		_outside(Vector3(-12.5, 0.0, -3.0)),
	]):
		return
	await _shot(rig, "route_12_harvest_grove.png")
	if not await _walk_many(rig, "grove to east fishing dock", [
		_outside(Vector3(-7.0, 0.0, -6.0)),
		_outside(Vector3(0.0, 0.0, -8.5)),
		_outside(Vector3(5.8, 0.0, -5.5)),
		_outside(Vector3(8.0, 0.0, 5.0)),
		_outside(Vector3(13.0, 0.0, 7.0)),
		_outside(Vector3(20.0, 0.0, 4.5)),
	]):
		return
	# The public port faces from the dock's dry edge toward the pond. Stop at
	# that real timber lip instead of asking the capsule to enter the water.
	if not await _walk_to(rig,
			_outside(OutskirtsHomestead.FISHING_CENTER + Vector3(0.5, 0.0, 3.0)),
			"east fishing dock edge", 1.4):
		return
	if not await _expect_prompt(rig, _outskirts.fishing_hole, "east fishing dock"):
		return
	await _shot(rig, "route_13_east_fishing_dock.png")
	print("GARRISON GOLDEN ROUTE OK")


func _stage_at_arrival() -> void:
	_release_stick()
	Input.action_release(&"jump")
	_hero.velocity = Vector3.ZERO
	_hero.global_position = _compound.to_global(_compound.port(&"arrival").origin)


func _walk_many(rig, tag: String, local_points: Array) -> bool:
	for point: Vector3 in local_points:
		if not await _walk_to(rig, point, tag):
			return false
	return true


func _walk_to(rig, local_target: Vector3, tag: String,
		target_radius: float = TARGET_RADIUS) -> bool:
	var target := _compound.to_global(local_target)
	var initial_gap := K.plane(target - _hero.global_position).length()
	var budget := clampf(initial_gap / 2.4 + 2.4, 3.5, 11.0)
	var elapsed := 0.0
	var stall_elapsed := 0.0
	var stall_at := _hero.global_position
	while elapsed < budget:
		var wish := K.plane(target - _hero.global_position)
		if wish.length() <= target_radius:
			_release_stick()
			await rig.wait_physics_frames(2)
			return true
		_press_stick(wish.normalized())
		await rig.wait_physics_frames(1)
		var delta := 1.0 / float(Engine.physics_ticks_per_second)
		elapsed += delta
		stall_elapsed += delta
		if stall_elapsed >= STALL_SECONDS:
			if K.plane(_hero.global_position - stall_at).length() < STALL_PROGRESS:
				_release_stick()
				rig.fail("GARRISON ROUTE %s stalled at (%.2f, %.2f), %.2f m short of (%.2f, %.2f); ray blocker=%s" % [
					tag, _local().x, _local().z, wish.length(), local_target.x,
					local_target.z, _blocker_toward(target),
				])
				return false
			stall_at = _hero.global_position
			stall_elapsed = 0.0
	_release_stick()
	rig.fail("GARRISON ROUTE %s timed out %.2f m short of (%.2f, %.2f)" % [
		tag, _flat_gap(local_target), local_target.x, local_target.z,
	])
	return false


func _expect_prompt(rig, subject: Interactable, tag: String) -> bool:
	if not rig.check(subject != null and is_instance_valid(subject), "%s exists" % tag):
		return false
	var seen: bool = await rig.until(func() -> bool: return Prompt.focus == subject)
	if not seen:
		rig.fail("GARRISON ROUTE %s was traversable but its service prompt never took focus" % tag)
		return false
	await rig.wait_physics_frames(2)
	return true


func _press_stick(dir: Vector3) -> void:
	var camera := _hero.get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		forward = K.plane(-camera.global_transform.basis.z).normalized()
		right = K.plane(camera.global_transform.basis.x).normalized()
	var stick := Vector2(dir.dot(right), -dir.dot(forward)).normalized()
	_hold(&"move_right", stick.x)
	_hold(&"move_left", -stick.x)
	_hold(&"move_down", stick.y)
	_hold(&"move_up", -stick.y)


func _hold(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _release_stick() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)


func _local() -> Vector3:
	return _compound.to_local(_hero.global_position)


func _outside(local_position: Vector3) -> Vector3:
	return _compound.to_local(_outskirts.to_global(local_position))


func _flat_gap(local_target: Vector3) -> float:
	return K.plane(local_target - _local()).length()


func _blocker_toward(world_target: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(
		_hero.global_position + Vector3.UP * 0.8,
		world_target + Vector3.UP * 0.8, K.L_WORLD)
	query.exclude = [_hero.get_rid()]
	var hit := _hero.get_world_3d().direct_space_state.intersect_ray(query)
	var blocker := hit.get("collider") as Node
	return str(blocker.get_path()) if blocker != null else "<none>"


func _shot(rig, file_name: String) -> void:
	await rig.wait_frames(5)
	await rig.capture(_out.path_join(file_name))
