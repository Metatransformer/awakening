extends RefCounted
## Does the game get harder, and does the run survive going deeper?
##
## Walks floors 1 to 5 by taking the stair, and at each one reads the numbers
## that are supposed to have moved. The failures this exists to catch are the
## ones an endless curve fails at quietly:
##
##   * **The flat curve.** A scaling function exists, is unit-correct, and is
##     never called -- so floor 5 is floor 1 with a different layout. The health
##     and damage readings below are taken off REAL SPAWNED MONSTERS, not off
##     `Prog`, because `Prog` agreeing with itself proves nothing.
##   * **The wiped bag.** Descending reloads the dungeon scene, and anything
##     that treats a scene load as the start of a run empties the bag, heals the
##     hero, or resets the fee. Then going deeper is free and the whole decision
##     the stair exists for is gone.
##   * **The missing stair.** No way down in the deepest room, on some floor,
##     because the room that got the stair was picked by something that can be
##     empty. An endless game that dead-ends on floor 6 is not endless.
##   * **The same floor twice.** Seeding the generator off the run seed rather
##     than the run seed AND the level, so every floor of a run is identical.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/descend_curve.gd --out=/tmp/dive/x.png

const FLOORS := 5

var _fails: int = 0
## level -> what that floor actually spawned. Compared across floors at the end,
## because "harder than the last one" is the property, not any single reading.
var _seen: Array[Dictionary] = []


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/dive/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	# Something in the bag before the first descent, so "the bag survived" is a
	# real question on every floor rather than an empty dictionary staying empty.
	Run.collect(&"iron_scrap", 4)
	Run.collect(&"bone_shard", 7)
	var bag_at_start := Run.bag_value()
	print("DIVE start floor=%d bag=%d" % [Run.level, bag_at_start])

	for i in FLOORS:
		var last := i == FLOORS - 1
		_read_floor(rig)
		await rig.capture(out.path_join("dive_%02d_floor%d.png" % [i, Run.level]))
		if last:
			break
		if not await _take_the_stair(rig):
			break

	_compare()
	_elites(rig)

	if Run.bag_value() != bag_at_start:
		_fail("the bag did not survive the descent: %d -> %d. Going deeper is"
			% [bag_at_start, Run.bag_value()]
			+ " supposed to keep everything you are carrying")
	else:
		print("DIVE bag survived %d floors at %d" % [FLOORS, Run.bag_value()])

	# LAST, and after every reading is taken. It teleports the hero into the
	# deepest room of floor 5 to photograph the stair, and the first version of
	# this ran BEFORE the bag check -- the pack down there killed him in the 50
	# frames it waits, `Run.die` emptied the bag, and the director reported a bag
	# bug in the game that was entirely its own doing. A beat that moves the
	# subject around goes after the beats that measure it.
	await _look_at_the_stair(rig, out)

	if _fails == 0:
		print("DIVE OK")


## Read what this floor ACTUALLY built. Everything here comes off live nodes.
func _read_floor(rig) -> void:
	var dungeon := _dungeon(rig)
	if dungeon == null:
		_fail("floor %d has no Dungeon in it -- the descent loaded the wrong scene"
			% Run.level)
		return

	var foes: Array = rig.get_nodes_in_group(&"enemy")
	var health := 0
	var damage := 0
	var elites := 0
	var kinds: Dictionary = {}
	for n in foes:
		var e := n as Enemy
		if e == null:
			continue   # nothing in the group is anything else today; see below
		# The BOSS is an `Enemy` in the enemy group like everything else, and it
		# is the wrong body to measure this curve with: `BossDb` sets its health
		# and it is four to five times a rank-and-file monster. Counted, floor 1
		# reads as 48 q against bossless floor 5's 44 q and `_compare` reports
		# that the game got EASIER with depth -- which is a lie about the curve
		# told by a body that is not on the curve. Skipped by where it stands,
		# not by kind: an arena has exactly one occupant.
		if _under(e, "Arena"):
			continue
		health = maxi(health, e.health.max_quarters)
		damage = maxi(damage, e._damage)
		kinds[e.kind] = true
		if e.elite:
			elites += 1

	# The stair is the only thing that makes the next floor reachable, so its
	# absence is fatal rather than a note.
	#
	# Counted OUTSIDE the shortcut landing. Since M4 an authored floor builds two
	# `Stairs`: the way down, now behind the boss door on `BossLanding` instead of
	# loose in the deepest room (GDD §5.3), and the shortcut's, on
	# `ShortcutLanding`, which skips a floor and is a different promise entirely.
	# "Exactly one stair" was true when there was one kind of stair; the invariant
	# that survived is "exactly one way DOWN".
	var stairs := 0
	for n in dungeon.find_children("*", "Stairs", true, false):
		if _under(n, "ShortcutLanding"):
			continue
		stairs += 1
	if stairs != 1:
		_fail("floor %d has %d ways down, wanted exactly 1" % [Run.level, stairs])

	var row := {
		"level": Run.level,
		"rooms": dungeon.rooms.size(),
		"foes": foes.size(),
		"health": health,
		"damage": damage,
		"elites": elites,
		"kinds": kinds.keys().size(),
		"cells": _shape(dungeon),
	}
	_seen.append(row)
	print("DIVE floor=%d rooms=%d foes=%d toughest=%dq hardest=%dq elites=%d kinds=%d"
		% [row["level"], row["rooms"], row["foes"], row["health"], row["damage"],
			row["elites"], row["kinds"]])


## Is `n` anywhere below a node of this name? Both users of this ask a question
## about WHERE a thing stands -- which is the only honest way to tell a boss from
## a monster, or the way down from the shortcut, without a second table saying so.
func _under(n: Node, ancestor: String) -> bool:
	var at := n.get_parent()
	while at != null:
		if at.name == ancestor:
			return true
		at = at.get_parent()
	return false


## The generator, which is a CHILD of the scene root -- dungeon.tscn's root is
## `DungeonRun`, holding the environment, the hero, the camera and this.
func _dungeon(rig) -> Dungeon:
	var root: Node = rig.scene()
	if root == null:
		return null
	if root is Dungeon:
		return root as Dungeon
	for c in root.find_children("*", "Dungeon", true, false):
		return c as Dungeon
	return null


## A cheap fingerprint of the layout, so two floors being the SAME floor is
## visible. The room cells, sorted -- same tree, same string.
func _shape(dungeon: Dungeon) -> String:
	var cells: Array[String] = []
	for cell: Vector2i in dungeon.rooms:
		cells.append("%d,%d" % [cell.x, cell.y])
	cells.sort()
	return "|".join(cells)


func _take_the_stair(rig) -> bool:
	var dungeon := _dungeon(rig)
	if dungeon == null:
		_fail("no Dungeon on floor %d to take a stair out of" % Run.level)
		return false
	var found := dungeon.find_children("*", "Stairs", true, false)
	if found.is_empty():
		_fail("no stair on floor %d -- the run dead-ends here" % Run.level)
		return false

	var before := Run.level
	# Called rather than walked into on purpose. Whether the hero can path to the
	# deepest room is `mvp_loop`'s question; this director is about what happens
	# to a run when it goes down, and a pathing failure here would report itself
	# as a broken curve.
	(found[0] as Stairs).activate(null)

	# The descent is a scene load behind a fade, so wait for the world rather
	# than for a frame count -- see the note in mvp_loop._descend about fixed
	# waits reporting other people's failures as their own.
	for _i in 240:
		await rig.wait_frames(1)
		if not Flow.busy and Run.level > before and _dungeon(rig) != null:
			await rig.wait_frames(6)
			return true

	_fail("the stair on floor %d never took: level is still %d" % [before, Run.level])
	return false


## The curve itself. Floor 1 versus the deepest floor reached, because a
## per-floor delta can legitimately be zero -- damage steps once every three
## floors by design -- while the whole span cannot.
func _compare() -> void:
	if _seen.size() < 2:
		_fail("only reached %d floor(s); nothing to compare" % _seen.size())
		return
	var first: Dictionary = _seen[0]
	var last: Dictionary = _seen.back()

	if int(last["health"]) <= int(first["health"]):
		_fail("monsters did not get tougher: floor %d toughest is %dq,"
			% [first["level"], first["health"]]
			+ " floor %d is %dq" % [last["level"], last["health"]])
	if int(last["damage"]) <= int(first["damage"]):
		_fail("monsters did not start hitting harder: %dq -> %dq over %d floors"
			% [first["damage"], last["damage"], _seen.size()])
	if int(last["rooms"]) < int(first["rooms"]):
		_fail("the floors got SMALLER: %d rooms -> %d"
			% [first["rooms"], last["rooms"]])

	# Every floor of one run must be a different floor.
	var shapes: Dictionary = {}
	for row in _seen:
		var key: String = row["cells"]
		if shapes.has(key):
			_fail("floor %d has the same layout as floor %d -- the generator is"
				% [row["level"], shapes[key]]
				+ " seeded off the run and not off the floor")
		shapes[key] = row["level"]

	# The drop table has to move too, or a deep floor is all cost and no reward.
	var shallow := ItemDb.enemy_drops(int(first["level"]))
	var deep := ItemDb.enemy_drops(int(last["level"]))
	var rare := &"ghost_silk"
	var lift := float(deep.get(rare, 0)) / maxf(float(shallow.get(rare, 1)), 1.0)
	print("DIVE rare-drop weight x%.2f from floor %d to %d"
		% [lift, first["level"], last["level"]])
	if lift <= 1.0:
		_fail("the drop table never opened up: '%s' is weighted %s on floor %d"
			% [rare, shallow.get(rare, 0), first["level"]]
			+ " and %s on floor %d" % [deep.get(rare, 0), last["level"]])


func _fail(msg: String) -> void:
	_fails += 1
	print("DIVE FAIL %s" % msg)


## Build one elite and one ordinary of the same kind on the same floor and
## compare them.
##
## Done by construction rather than by counting what the floors happened to
## spawn, because the elite roll is a 5-15% chance per room: five floors of it
## coming up zero is a one-in-seven run, and a beat that only fails one time in
## seven is a beat that reports "fine" on a variant that never worked at all.
## This run was one of those -- every floor above reported elites=0.
func _elites(rig) -> void:
	var scene: Node = rig.scene()
	if scene == null:
		return
	var pair: Array[Enemy] = []
	for is_elite in [false, true]:
		var e := Enemy.new()
		e.kind = &"skeleton"
		e.drop_seed = 31337
		e.level = 5
		e.elite = is_elite
		scene.add_child(e)
		# Well away from the hero and each other: this is a measurement of what
		# they were BUILT as, and a fight would start changing the numbers.
		e.global_position = Vector3(80.0 + (12.0 if is_elite else 0.0), 0.05, 80.0)
		pair.append(e)

	var plain := pair[0]
	var big := pair[1]
	print("DIVE elite skeleton %dq/%dq vs plain %dq/%dq"
		% [big.health.max_quarters, big._damage,
			plain.health.max_quarters, plain._damage])

	if big.health.max_quarters <= plain.health.max_quarters:
		_fail("an elite is no tougher than an ordinary one (%dq vs %dq)"
			% [big.health.max_quarters, plain.health.max_quarters])
	if big._damage <= plain._damage:
		_fail("an elite hits no harder than an ordinary one (%dq vs %dq)"
			% [big._damage, plain._damage])
	# The size is the whole tell. An elite you cannot pick out of the room before
	# it swings is a stat block, not an encounter.
	if big._height() <= plain._height() * 1.05:
		_fail("an elite is not visibly bigger: %.2f m vs %.2f m"
			% [big._height(), plain._height()])

	for e in pair:
		e.queue_free()


## Stand at the way down and photograph it.
##
## Every other beat in this director is a number, and the stair is the one new
## piece of geometry in the whole slice -- "exactly 1 Stairs node exists" says
## nothing about whether it reads as a staircase or as a pile of boxes in a dark
## room. It has to be recognisable as the way down from across the room, without
## a marker, or the deepest room is a dead end with a prop in it.
func _look_at_the_stair(rig, out: String) -> void:
	var dungeon := _dungeon(rig)
	if dungeon == null:
		return
	var found := dungeon.find_children("*", "Stairs", true, false)
	if found.is_empty():
		return
	var down := found[0] as Node3D

	var heroes: Array = rig.get_nodes_in_group(&"player")
	if heroes.is_empty():
		return
	var hero := heroes[0] as Hero
	if hero == null:
		return

	# Stop the pack first. This drops the hero into the deepest room of floor 5,
	# where 45 monsters live -- left running they mob him inside the 50 frames the
	# camera needs, and a death here is not a quiet one: `Run.die` empties the bag
	# and `Flow` fades to GARRISON, so the "stair" photo comes out a picture of the
	# market square.
	# Hidden as well as frozen: the deepest room opens with a wraith, it spawns
	# near the chest, and in the first shot of this it was standing squarely in
	# front of the stair. A lookdev frame of a prop should contain the prop.
	for e in rig.get_nodes_in_group(&"enemy"):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		(e as Node3D).visible = false

	# Back off INTO THE ROOM rather than along world -Z. The stair sits off the
	# room's centre by a fixed offset, so the room's own origin is the one
	# direction guaranteed to be open floor -- backing off along an axis put the
	# hero inside a wall, where `move_and_slide` quietly shoved him somewhere else.
	var room := (down.get_parent() as Node3D)
	var back := K.flat(room.global_position - down.global_position) \
		if room != null else Vector3(0.0, 0.0, -1.0)
	if back == Vector3.ZERO:
		back = Vector3(0.0, 0.0, -1.0)
	hero.global_position = down.global_position + back * 4.2 + Vector3.UP * 0.05
	# heading == (sin y, 0, cos y), and a Node3D's forward is -basis.z, so the body
	# yaw is the heading plus PI (docs/CONTRACT.md §2.5).
	hero.facing_yaw = atan2(-back.x, -back.z)
	hero.rotation.y = hero.facing_yaw + PI
	await rig.wait_frames(20)

	# Can he actually address it from where the geometry lets him stand? The pit
	# has a solid kerb, so the hero stops about 2.1 m short of the node's origin,
	# and the trigger sphere has to reach past that. Every other beat in this
	# director would pass on a stair nobody can press the button on: the numbers
	# scale, the layouts differ, `activate()` works when called -- and the run
	# still dead-ends on floor 1 because the prompt never appears.
	hero.global_position = down.global_position + back * 2.6 + Vector3.UP * 0.05
	await rig.wait_frames(12)
	if not (down as Interactable).player_inside:
		_fail("the stair cannot be reached: standing as close to it as the kerb"
			+ " allows, the hero is outside its %.1f m trigger"
			% (down as Interactable).radius)
	elif Prompt.focus != down:
		_fail("standing at the stair, the prompt is '%s', not DESCEND"
			% ("nothing" if Prompt.focus == null else Prompt.focus.prompt))
	else:
		print("DIVE the stair prompts DESCEND from where the hero can stand")

	# Photograph it on a camera of my own rather than through the game's.
	#
	# `camera_recenter` was the obvious way and it does not work here: the follow
	# rig refuses to sit inside a wall, so in the deepest room -- which has one
	# right behind the stair -- it swings to whatever yaw is clear and the stair
	# ends up at the edge of frame. Three shots came back that way. The game
	# camera's job is to keep the PLAYER framed while the world gets in the way;
	# a lookdev shot wants the opposite, so it gets its own camera and puts it
	# exactly where the question is asked from.
	var eye := Camera3D.new()
	dungeon.add_child(eye)
	eye.global_position = down.global_position + back * 7.5 + Vector3.UP * 4.6
	eye.look_at(down.global_position + Vector3.UP * 0.4, Vector3.UP)
	eye.fov = 60.0
	eye.make_current()
	await rig.wait_frames(6)
	await rig.capture(out.path_join("dive_10_stair.png"))
	eye.queue_free()
