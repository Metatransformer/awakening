extends RefCounted
## Card #27 — **the gate room's eye row, at a height a bow is aimed at and
## looking into the room.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/gate_eye_row.gd \
##     --out=/tmp/eyes/x.png --warmup=60 --gate-prefab=eye_row
##
## `Dungeon.GATE_PREFABS` has three entries and the seed picks one, so this file
## forces `eye_row` on the command line for the same reason `--gate-prefab`
## exists at all: a director that photographed whichever prefab its seed drew
## would leave the other two shipping unproven.
##
## `CLAUDE.md` §4 is the whole reason this file exists, and its last line is the
## instruction: **render it and look.** This project has shipped art facing the
## wrong way three times — the hero rig, the weapon socket, the entire monster
## roster — and every one of them did it under a code comment asserting the
## facing was already right. So nothing here is asked of the placer's arithmetic.
## Every claim is made against the built node's own `global_transform`, or
## against a ray fired through the world, or against the frame.
##
## What it claims, in the order it proves them:
##
##   A  Floor 2's gate room drew the eye row: three `EyeSwitch`es, named
##      `GateEye0..2`, all three of them inside the room's own footprint rather
##      than in the masonry at either end of the wall they are spread along.
##   B  Every eye stands at **2.05 m** — `Dungeon.EYE_Y`, the same height the
##      shortcut's eye and `convert_arrow.gd`'s pair use. Above the sword's
##      reach, below the sconces, and where a bow is already aimed. They were
##      at `y = 0`, which is a switch lying on the floor.
##   C  Every pupil looks INTO the room. Measured twice and derived never: the
##      node's own forward (`-basis.z`) against the way to the middle of the
##      room, and a ray fired out of the eye along that forward, which is a
##      metre and a half of clear air when it is right and four centimetres of
##      stone when it is not.
##   D  A hero standing where the puzzle is answered from has an unblocked line
##      to all three (`Dungeon.WALL_STANDOFF` — card #5's lesson: an atom flush
##      to `KitWall` renders perfectly and cannot be hit).
##   E  A real arrow, fired from the hero's own muzzle, opens the eye it was
##      aimed at. Not `solve()` — that is the check every buried atom passes.
##   F  The three of them lit wake the gate's key, which is the beat
##      `puzzle_loop.gd` owns and this file must not break.

## Floor 2 rather than floor 1: the gate room's verb ceiling is tier N-1
## (`Dungeon._gate_tier`), so floor 1's gate is T0 and the eye row cannot appear
## on it at all. Floor 2 is the first floor that draws this prefab.
const LEVEL := 2

## The same floor layout the other dungeon directors force, so all of them are
## describing one dungeon.
const SEED := 20260809

## `Dungeon.EYE_Y`, and the window this file will accept around it. Spelled out
## rather than read off `Dungeon`: this script is loaded with `-s` and a
## `preload` of anything that names an autoload takes the harness down before the
## autoloads exist (`CLAUDE.md` §3).
const EYE_Y := 2.05
const EYE_Y_TOL := 0.05

## Above the sword's reach. The looser bound, and the one that says what the
## height is FOR — `shortcut_puzzle.gd` makes the same check with the same
## number about the same atom.
const BOW_HEIGHT := 1.8

## The hero's bow muzzle, off `convert_arrow.gd`'s constant.
const MUZZLE_Y := 1.30

## How far the ray out of an eye's own forward has to travel before it is
## allowed to hit anything. An eye turned into the wall stops in about four
## centimetres — the standoff is 0.55 m and its own plate reaches 0.20 m forward
## — so a metre is far more than enough to tell the two cases apart and far less
## than the room is deep.
const CLEAR_AHEAD := 1.0

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/eyes/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("EYES FAIL wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	Game.reset()
	Run.enter(SEED)
	# The bow, because `PuzzleAtoms.pool` takes the minimum of the shape's
	# ceiling and what the player owns (§0 rule 1) -- without it the eye row is
	# not in the pool and the room draws the sun nest instead.
	Game.grant(&"bow")

	var d := await _rebuild(rig, LEVEL)
	if d == null:
		print("EYES FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	var cam := _game_camera(rig)
	if hero == null or cam == null:
		print("EYES FAIL no hero or no GameCamera in the scene")
		return
	cam.make_current()
	_clear_the_floor(d)
	await rig.wait_frames(20)

	var gate: Node = d.anchor_node(&"gate_room")
	_ck("A0 floor %d has a gate room" % LEVEL, gate != null)
	if gate == null:
		return
	var cell: Vector2i = d.anchor_cell(&"gate_room")
	var root: Node3D = d.rooms[cell]["node"]
	var half: float = float(d.size_of(cell)) * 0.5

	var eyes: Array[Node3D] = []
	for i in 3:
		var e := root.get_node_or_null(NodePath("GateEye%d" % i)) as Node3D
		if e != null:
			eyes.append(e)
	_ck("A1 it drew the eye row -- three eyes (%d)" % eyes.size(),
		eyes.size() == 3)
	if eyes.size() != 3:
		print("EYES FAIL pass --gate-prefab=eye_row; this floor drew "
			+ "something else")
		return

	# In the ROOM, not in the wall at either end of it. The row is spread 3.2 m
	# apart along a wall whose half-width is `half`, so a room that ever gets
	# smaller puts the outer two inside the masonry -- and that failure looks
	# exactly like the two facing bugs this file is here about.
	var inside := 0
	for e: Node3D in eyes:
		var local := root.to_local(e.global_position)
		if absf(local.x) < half - 0.5 and absf(local.z) < half - 0.5:
			inside += 1
	_ck("A2 and all three stand inside the room's %.1f m footprint (%d/3)"
		% [half * 2.0, inside], inside == 3)

	# --- B and C. Height and facing ------------------------------------------
	var high := 0
	var looking := 0
	var clear_ahead := 0
	for i in eyes.size():
		var e: Node3D = eyes[i]
		# The node's own forward, off the transform the renderer uses. Not the
		# yaw the placer wrote, and not a bone rest pose (`CLAUDE.md` §4).
		var fwd := -e.global_transform.basis.z
		# The way from the eye to the middle of the room it is supposed to be
		# watching. `root` sits at the room's centre (`Dungeon._build_room`).
		var into := K.flat(root.global_position - e.global_position).normalized()
		var dot := fwd.dot(into)
		var ahead := _ray(e, e.global_position, fwd * (CLEAR_AHEAD + 0.2))
		print("EYES GateEye%d at %.2f,%.2f,%.2f  fwd %.2f,%.2f  "
			% [i, e.global_position.x, e.global_position.y, e.global_position.z,
				fwd.x, fwd.z]
			+ "into-room %.2f,%.2f  dot %.2f  clear ahead %.2f m"
			% [into.x, into.z, dot, ahead])
		if absf(e.global_position.y - EYE_Y) < EYE_Y_TOL \
				and e.global_position.y > BOW_HEIGHT:
			high += 1
		if dot > 0.9:
			looking += 1
		if ahead >= CLEAR_AHEAD:
			clear_ahead += 1
	_ck("B0 every eye stands at %.2f m, above the sword and at the bow (%d/3)"
		% [EYE_Y, high], high == 3)
	_ck("C0 every pupil's own forward points into the room (%d/3)" % looking,
		looking == 3)
	_ck("C1 and there is a clear metre of air in front of each of them, "
		+ "not stone (%d/3)" % clear_ahead, clear_ahead == 3)

	# The wide shot: the hero standing where the row is answered from, with all
	# three eyes and the gate door in one frame. This is the frame `CLAUDE.md`
	# §4 asks for and no check replaces it -- an eye in the wall photographs as
	# a wall.
	await _stand_off(rig, hero, eyes[1], 7.0)
	await rig.capture(out.path_join("g_01_eye_row.png"))
	await _stand_off(rig, hero, eyes[1], 3.4)
	await rig.capture(out.path_join("g_02_eye_close.png"))

	# --- D. Reachable --------------------------------------------------------
	await _stand_off(rig, hero, eyes[1], 6.0)
	var reachable := 0
	for i in eyes.size():
		if _clear_line(hero, eyes[i]):
			reachable += 1
	_ck("D0 an arrow can actually get to all three from one spot (%d/3)"
		% reachable, reachable == 3)

	# --- E. A real arrow -----------------------------------------------------
	var target: Node3D = eyes[1]
	var from := hero.global_position + Vector3.UP * MUZZLE_Y
	var arrow := Arrow.new()
	arrow.name = "DirectorArrow"
	# Parented to the SCENE, exactly as `HeroRanged._release_arrow` does it: an
	# arrow under the hero inherits his yaw and his 1.65 scale.
	rig.scene().add_child(arrow)
	arrow.launch(from, (target.global_position - from).normalized(),
		hero as CollisionObject3D)
	var lit: bool = await rig.until(func() -> bool:
		return bool(target.call(&"is_solved")), 4.0)
	_ck("E0 a real arrow, aimed at the middle eye, opened it", lit)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("g_03_one_lit.png"))

	# --- F. The key ----------------------------------------------------------
	var key: Node = root.get_node_or_null(^"GateKey")
	_ck("F0 the room has a small key", key != null)
	if key != null:
		_ck("F1 and one eye of three has NOT woken it (§3, all of them)",
			not key.visible)
	for e: Node3D in eyes:
		if not bool(e.call(&"is_solved")):
			e.call(&"apply_hit", null)
	await rig.wait_frames(30)
	if key != null:
		_ck("F2 all three lit wakes it", key.visible
			and bool(key.get(&"armed")))
	await _stand_off(rig, hero, eyes[1], 7.0)
	await rig.capture(out.path_join("g_04_row_lit.png"))

	if _fails == 0:
		print("EYES ok -- every check passed")
	else:
		print("EYES FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("EYES ok %s" % label)
	else:
		_fails += 1
		print("EYES FAIL %s" % label)


# --- Rays ---------------------------------------------------------------------

## How far a ray gets out of `at` along `span` before something stops it.
## Returns the full length when nothing does.
func _ray(in_world: Node3D, at: Vector3, span: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.new()
	q.from = at
	q.to = at + span
	q.collision_mask = K.L_WORLD | K.L_INTERACT
	q.collide_with_areas = true
	# The eye's own body is on both of those layers and is 0.28 m thick around
	# the origin this fires from, so without this the answer is always "zero".
	q.exclude = _bodies_under(in_world)
	var seen := in_world.get_world_3d().direct_space_state.intersect_ray(q)
	if seen.is_empty():
		return span.length()
	return at.distance_to(seen["position"] as Vector3)


## Is there daylight between the hero's muzzle and `target`? Lifted from
## `shortcut_puzzle.gd`, and phrased the same way -- as *what stops the ray
## first*, because an atom buried in `KitWall`'s collider answers `apply_hit`
## happily and can never be shot (card #5, `Dungeon.WALL_STANDOFF`).
func _clear_line(hero: Node3D, target: Node3D) -> bool:
	var from := hero.global_position + Vector3.UP * MUZZLE_Y
	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = target.global_position
	q.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	q.collide_with_areas = true
	q.exclude = [(hero as CollisionObject3D).get_rid()]
	var seen := hero.get_world_3d().direct_space_state.intersect_ray(q)
	var span := from.distance_to(target.global_position)
	if seen.is_empty():
		print("EYES line to %s: clear, %.2f m" % [target.name, span])
		return true
	var b := seen["collider"] as Node
	if b == target or target.is_ancestor_of(b):
		print("EYES line to %s: clear, %.2f m (landed on its own body)"
			% [target.name, span])
		return true
	print("EYES line to %s BLOCKED by %s (%s) %.2f m short"
		% [target.name, b.name, b.get_class(),
			(seen["position"] as Vector3).distance_to(target.global_position)])
	return false


func _bodies_under(n: Node) -> Array[RID]:
	var rids: Array[RID] = []
	for b in _every(n, func(x: Node) -> bool: return x is CollisionObject3D):
		rids.append((b as CollisionObject3D).get_rid())
	return rids


# --- Fixture ------------------------------------------------------------------

func _rebuild(rig, level: int) -> Node:
	Run.level = level
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	scene.add_child(d)
	await rig.wait_frames(12)
	return d


func _clear_the_floor(d: Node) -> void:
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		freed += 1
		e.queue_free()
	print("EYES cleared %d bodies" % freed)


## Out along the atom's own FORWARD, which is the side an atom aimed at the
## player stands on -- the opposite of a door's convention, and getting the two
## the wrong way round puts the camera inside masonry (`puzzle_loop.gd` has the
## same pair of helpers and the same note).
func _stand_off(rig, hero: Node3D, at: Node3D, back: float) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = at.global_position \
		- at.global_transform.basis.z * back
	hero.global_position.y = 0.15
	var to := K.flat(at.global_position - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _every(root: Node, pred: Callable) -> Array:
	var found: Array = []
	for n in _all(root):
		if pred.call(n):
			found.append(n)
	return found
