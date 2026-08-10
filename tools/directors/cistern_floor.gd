extends RefCounted
## M4, "Floor 1, whole" (docs/SCOPE.md §3). **This is the demo**, and this is the
## director that says whether it exists.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/cistern_floor.gd \
##     --out=/tmp/floor/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The floor is the MANIFEST'S floor. Six rooms because `FloorDb` says six,
##      a (2,4) pack because it defers to `Prog`, and every body in every room
##      drawn from that floor's own roster at that room's distance. `Dungeon` no
##      longer HAS a band table -- the constant is gone, which is checked rather
##      than asserted in prose.
##   B  All four anchors, in the rooms GDD §5.1 names, and the stair is where the
##      GDD moved it: OUT of the deepest room and into the landing behind the
##      boss door.
##   C  Every anchor is REACHABLE -- walked to from the entrance, room by room
##      along the tree, with the hero's own capsule swept through every doorway.
##      A node that exists in a sealed pocket of geometry passes an assertion and
##      fails a player.
##   D  The shortcut refuses by name without the Bow, opens with it, and what is
##      behind it is a `Stairs` that skips this floor -- floor 1's shortcut lands
##      you at the Foundry's mouth.
##   E  The vault refuses without the FOUNDRY's item (floor N+1's, GDD §5.3), and
##      behind it are three rooms, a harder pack, one relic and one rich chest.
##   F  The deep chest carries the relic `FloorDb` names for floor 1's
##      `deep_chest` slot, as a mote you walk over.
##   G  The Long Descent is untouched: level 5 generates with no anchors, no
##      locked doors, and its stair back in the deepest room.
##
## ## What "walked to" means here, precisely
##
## The hero is swept along the room tree with `CharacterBody3D.test_move` -- his
## real capsule, against the real collision, one 0.45 m step at a time, sliding
## when a chest or a pillar is in the way and FAILING when nothing gets him
## through. That is a claim about geometry, which is what reachability is.
##
## It is deliberately not synthetic stick input. Movement here is
## camera-relative, so an input walk across sixty metres of corridor measures the
## camera boom as much as the floor, and it is the one thing in this beat that
## can fail for a reason that is not the level. The presses that MATTER -- the
## refusals and the opens -- are real `interact` taps at the end of every walk.
##
## `Vault` is never NAMED. It is a `class_name` added in the same change as this
## file, so it is not in the global script class cache until somebody runs
## `--import`, and naming it is a parse error that takes the whole run down
## before its first frame (`tools/directors/gate_locks.gd` records the lesson).
## Everything below goes through node handles and public accessors.

## Forced so the floor is the same floor every run. `Dungeon.seed_override` no
## longer suppresses the manifest, which is the only reason this beat can force a
## layout AND check the room count in the same pass.
const SEED := 20260809

## One sweep step. Shorter than the 2.4 m doorway so a diagonal approach still
## fits through it, longer than the slide fallback needs to be useful.
const STEP := 0.45
## Sweep steps per rendered frame. The walk is a geometry test, not a stroll --
## at one step a frame a sixty-metre corridor is four hundred frames of nothing.
const STEPS_PER_FRAME := 8

var out := ""
var _fails := 0
var _notes: Array[String] = []


func run(rig) -> void:
	out = rig.arg("out", "/tmp/floor/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.enter(SEED)

	# The host scene, checked out loud, because getting it wrong does not look
	# like getting it wrong. This beat ADDS a `Dungeon` to whatever scene it was
	# pointed at, so run against garrison.tscn it generates a floor on top of
	# the garrison -- and the garrison's south curtain wall stands across the
	# first corridor at z=10.7. The result is seventeen failures that read
	# exactly like a broken level: unreachable vault, unreachable boss, an
	# unopened chest. One wrong --scene cost an hour of reading level-generation
	# code that was fine. Say it in one line instead.
	if rig.scene().name != &"DungeonRun":
		print("FLOOR FAIL wrong host scene (%s) -- this beat replaces the "
			% rig.scene().name
			+ "'Dungeon' child of res://scenes/rooms/dungeon.tscn. Pass "
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	var d := await _rebuild(rig, 1)
	if d == null:
		print("FLOOR FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	if hero == null:
		print("FLOOR FAIL there is no hero in the scene")
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()
	await rig.wait_frames(20)

	_manifest(d)
	_anchors(d)
	# Off the floor before the walks: a pack that follows the hero into the next
	# beat turns a reachability measurement into a fight. The BOSS stays -- it is
	# the one body this beat is about.
	_clear_the_floor(d)
	await rig.wait_frames(6)

	await _shortcut_refuses(rig, d, hero)
	await _vault_refuses(rig, d, hero)
	await _the_boss(rig, d, hero)
	await _deep_chest(rig, d, hero)
	await _way_down(rig, d, hero)
	await _shortcut_opens(rig, d, hero)
	await _the_vault(rig, d, hero)
	await _endless(rig, hero)

	for n in _notes:
		print("FLOOR note %s" % n)
	if _fails == 0:
		print("FLOOR ok -- every check passed")
	else:
		print("FLOOR FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("FLOOR ok %s" % label)
	else:
		_fails += 1
		print("FLOOR FAIL %s" % label)


# --- Fixture ------------------------------------------------------------------

## Replace the scene's `Dungeon` with a seeded one. The scene's own node builds
## in `_ready`, before any director exists, off a run seed taken from the wall
## clock -- so the floor a director photographs would otherwise be a different
## floor every time it ran.
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


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


## Is `n` anywhere under a node called `name`?
func _under(n: Node, ancestor: String) -> bool:
	var at := n.get_parent()
	while at != null:
		if at.name == ancestor:
			return true
		at = at.get_parent()
	return false


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


# --- A. The manifest ------------------------------------------------------------

func _manifest(d: Node) -> void:
	var want_rooms := FloorDb.rooms(1)
	var want_pack := FloorDb.pack(1)
	print("FLOOR %s -- %d rooms, pack %s, tint %s"
		% [FloorDb.name_of(1), want_rooms, want_pack, FloorDb.tint_key(1)])
	_ck("A0 the Cistern is %d rooms and the floor built %d"
		% [want_rooms, d.rooms.size()], d.rooms.size() == want_rooms)
	_ck("A1 the pack is the manifest's %s (%d..%d)"
		% [want_pack, d.enemies_min, d.enemies_max],
		d.enemies_min == want_pack.x and d.enemies_max == want_pack.y)
	# `FloorDb` defers floor 1's pack to the curve on purpose (the Cistern's mouth
	# has to stay easy forever, GDD §7). If those two ever disagree, one of them
	# grew a second curve.
	_ck("A2 and the manifest deferred it to Prog (%s)" % Prog.pack(1),
		want_pack == Prog.pack(1))

	# The deletion, checked. `Dungeon.BANDS` and `Dungeon.BAND_DEEP` duplicated
	# `FloorDb.bands()`; CLAUDE.md §0 says delete the loser rather than land both.
	var consts: Dictionary = d.get_script().get_script_constant_map()
	_ck("A3 Dungeon.BANDS is gone", not consts.has("BANDS"))
	_ck("A4 Dungeon.BAND_DEEP is gone", not consts.has("BAND_DEEP"))

	# Every body, against the roster for ITS room's distance. A generator that
	# read the table but keyed it on the wrong number would pass every check
	# above and spawn the entrance room's monsters at the bottom of the floor.
	var wrong := 0
	var seen := 0
	for cell: Vector2i in d.rooms:
		var root: Node = d.rooms[cell].get("node")
		if root == null:
			continue
		var dist := int(d.rooms[cell]["dist"])
		var pool: Array = FloorDb.roster(1, dist)
		for e in _every(root, func(n: Node) -> bool: return n is Enemy):
			# The Warden is an `Enemy` too, and it is a golem no band of the
			# Cistern has ever heard of -- rightly, because `BossDb` chose it and
			# not the band table. Counted, it read as the generator spawning
			# off-roster bodies at the bottom of the floor.
			if _under(e, "Arena"):
				continue
			seen += 1
			if not pool.has((e as Enemy).kind):
				wrong += 1
				print("FLOOR   %s at dist %d is not in %s"
					% [(e as Enemy).kind, dist, pool])
	_ck("A5 all %d bodies came out of the Cistern's own roster" % seen,
		seen > 0 and wrong == 0)


# --- B. The four anchors ---------------------------------------------------------

func _anchors(d: Node) -> void:
	# The layout itself, printed. A reachability failure forty metres in is a
	# question about which room is next to which, and reading it out of the frame
	# is guesswork -- this is four lines and it answers it.
	for cell: Vector2i in d.rooms:
		var r: Dictionary = d.rooms[cell]
		print("FLOOR   room %s dist %d size %.0f doors %s parent %s"
			% [cell, r["dist"], d.size_of(cell), r["doors"], r["parent"]])
	var vault: Node3D = d.get_node_or_null(^"Vault")
	if vault != null:
		print("FLOOR   vault mouth %.1f,%.1f running %.2f,%.2f"
			% [vault.global_position.x, vault.global_position.z,
				vault.global_transform.basis.z.x, vault.global_transform.basis.z.z])
	for id: StringName in [&"boss_door", &"deep_chest", &"shortcut_door",
			&"vault_door"]:
		var n: Node = d.anchor_node(id)
		var p: Dictionary = d.placements.get(id, {})
		print("FLOOR anchor %s -> %s in room %s, side %s"
			% [id, n.name if n != null else "MISSING", d.anchor_cell(id),
				p.get("side", &"-")])
		_ck("B0 %s was placed" % id, n != null)

	_ck("B1 the boss door is in the deepest room",
		d.anchor_cell(&"boss_door") == d.deepest)
	_ck("B2 the deep chest is beside it, in the same room",
		d.anchor_cell(&"deep_chest") == d.deepest)
	_ck("B3 the shortcut is at the entrance",
		d.anchor_cell(&"shortcut_door") == d.entrance)
	var mid: Vector2i = d.anchor_cell(&"vault_door")
	var mid_dist := int(d.rooms[mid]["dist"])
	var deep_dist := int(d.rooms[d.deepest]["dist"])
	_ck("B4 the vault is in the middle ring (dist %d of %d)"
		% [mid_dist, deep_dist], mid_dist > 0 and mid_dist < deep_dist)

	# The two fork rules, off the table so they cannot drift from GDD §5.3.
	var sc: Node = d.anchor_node(&"shortcut_door")
	var vd: Node = d.anchor_node(&"vault_door")
	_ck("B5 the shortcut takes floor 1's OWN boss item (%s)"
		% sc.key_item, sc != null and sc.key_item == FloorDb.boss_item(1))
	_ck("B6 the vault takes floor 2's (%s)" % vd.key_item,
		vd != null and vd.key_item == FloorDb.boss_item(2))

	# GDD §5.1: the boss door REPLACES the stair. Both halves of that.
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var in_room := _every(deep_root, func(n: Node) -> bool: return n is Stairs)
	_ck("B7 there is no stair left in the deepest room (%d)" % in_room.size(),
		in_room.is_empty())
	var landing: Node = d.get_node_or_null(^"BossLanding")
	var behind := _every(landing, func(n: Node) -> bool: return n is Stairs) \
		if landing != null else []
	_ck("B8 the way down is in the landing behind the boss door",
		behind.size() == 1)

	# The arena is the deepest room, so the room had to be built to hold the ring
	# the table authored. A 16 m room and an 11 m radius is a fight through a wall.
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	_ck("B9 the deepest room has the arena in it", arena != null)
	if arena != null:
		var r: float = arena.radius()
		var half: float = d.size_of(d.deepest) * 0.5
		print("FLOOR arena radius %.1f m in a %.1f m chamber" % [r, half * 2.0])
		_ck("B10 the seal ring fits inside the masonry (%.1f < %.1f)" % [r, half],
			r < half)


## Free every ordinary body on the floor. See the call site.
func _clear_the_floor(d: Node) -> void:
	var boss: Node = null
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	if arena != null:
		boss = arena.boss()
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		# The vault's pack is behind a locked door and cannot walk into a
		# measurement, and beat E is about to count it.
		if e == boss or _under(e, "Vault"):
			continue
		freed += 1
		e.queue_free()
	print("FLOOR cleared %d bodies for the reachability walks" % freed)


# --- C. Walking it ----------------------------------------------------------------

## Put the hero back where he arrives and walk the tree to `cell`, then stop a
## stride and a half in front of `face` (a door, a chest) looking at it.
func _walk_to(rig, d: Node, hero: Node3D, cell: Vector2i, face: Node3D) -> bool:
	var ok := await _walk_rooms(rig, d, hero, cell)
	if face != null and ok:
		# 1.9 m out along the prop's own facing. A `LockedDoor`'s leaves face into
		# the room down its -basis.z... which is the CONTRACT's forward, so the
		# side the player stands on is +basis.z (docs/CONTRACT.md §2.5).
		var stop := face.global_position + face.global_transform.basis.z * 1.9
		stop.y = 0.15
		ok = await _sweep(rig, hero, [stop])
	if face != null and ok:
		var to := K.flat(face.global_position - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	return ok


## Walk the room tree from the entrance to `cell`, threading each DOORWAY on its
## own axis instead of cutting from room centre to room centre.
##
## The corner-cutting version is why the first honest run of this file called the
## boss chamber unreachable. `door_span` is 6 m but the kit doorway standing in
## the hole narrows it: measured against the hero's own capsule, the gap he fits
## through is about a metre either side of the axis. So the metre of drift he
## picks up walking round one chest is a hero who arrives at the wall BESIDE the
## opening -- and then rubs along it for four hundred steps, because a sweep has
## no eyes and slides the same way every time. A player looks at the door. This
## tells the sweep where it is.
##
## Room centres are deliberately NOT waypoints: the straight line from one
## doorway to the next crosses open floor, and the middle of a room is where the
## furniture is.
func _walk_rooms(rig, d: Node, hero: Node3D, cell: Vector2i) -> bool:
	hero.global_position = d.centre_of(d.entrance) + Vector3(0.0, 0.15, 0.0)
	await rig.wait_frames(2)

	var up := Vector3(0.0, 0.15, 0.0)
	var cells: Array[Vector2i] = d.path_to(cell)
	var route: Array[Vector3] = []
	for i in maxi(cells.size() - 1, 0):
		var a: Vector2i = cells[i]
		var b: Vector2i = cells[i + 1]
		var step: Vector2i = b - a
		var ax := Vector3(float(step.x), 0.0, float(step.y))
		# Measured off each room's OWN half-width. The deepest room is 26 m and
		# its neighbours are 16, so "half the spacing" is wrong on exactly the
		# corridor that matters.
		var face_a: Vector3 = d.centre_of(a) + ax * (d.size_of(a) * 0.5)
		var face_b: Vector3 = d.centre_of(b) - ax * (d.size_of(b) * 0.5)
		route.append(face_a - ax * 1.6 + up)
		route.append((face_a + face_b) * 0.5 + up)
		route.append(face_b + ax * 1.6 + up)
	route.append(d.centre_of(cell) + up)
	# 0.3 m: a gate you thread, not a place you arrive. The last leg relaxes back
	# to a stride (see `_sweep`) because the destination is a room, not a hole.
	return await _sweep(rig, hero, route, 0.3)


## The walk itself: the hero's real capsule, stepped through the real collision.
##
## Two ways it gives up, and they mean different things -- which is why they are
## reported differently. **Walled in** is geometry: nothing in front, nothing to
## either side, the leg is closed. **Sliding** is a hero rubbing along masonry --
## a target he cannot stand on, or a hole he is beside rather than in front of.
## The first run of this file spent 500 steps doing the second and reported it as
## the first; a silent step budget cannot tell you which one you have.
func _sweep(rig, hero: Node3D, route: Array[Vector3], tol: float = 0.7) -> bool:
	var n := 0
	for leg in route.size():
		var target: Vector3 = route[leg]
		# The last waypoint is a destination and the ones before it are gates.
		var near := tol if leg < route.size() - 1 else maxf(tol, 0.7)
		var guard := 0
		# Consecutive steps that went sideways rather than forward.
		var blocked := 0
		var best := INF
		while guard < 400:
			guard += 1
			# `K.plane`, NOT `K.flat`. `flat` normalises -- its own docstring in
			# `consts.gd` says so and counts the three bugs it has already caused
			# -- so `K.flat(target - here).length()` is 1.0 everywhere in the
			# world, the arrival test never fires, and a hero standing 100 mm from
			# the door reports himself a metre short of it. This was the fourth.
			var to := K.plane(target - hero.global_position)
			best = minf(best, to.length())
			if to.length() < near:
				break
			var step := to.limit_length(STEP)
			# Zeroed every step. We are teleporting a `CharacterBody3D` that is
			# still running its own `move_and_slide`, and the velocity it had when
			# it last touched a wall will keep shoving it sideways between our
			# frames -- which reads in the trace as a hero drifting out of a
			# doorway he was already lined up with.
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
				blocked = 0
			else:
				# Something small is in the way -- a chest, a pillar, the corner
				# of a doorway reveal. Try either side of it before giving up; a
				# walk that failed on the first chest would report the floor
				# unreachable because it has furniture in it.
				blocked += 1
				var side := Vector3(-step.z, 0.0, step.x).normalized() * STEP
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				elif not hero.test_move(hero.global_transform, -side):
					hero.global_position -= side
				else:
					_leg_failed("walled in", leg, route.size(), hero, target, best)
					return false
				# Sliding is for getting round furniture. Thirty strides of it in
				# a row is not a detour, it is a hero rubbing along a wall.
				if blocked > 30:
					_leg_failed("sliding, not advancing", leg, route.size(),
						hero, target, best)
					return false
			n += 1
			if n % STEPS_PER_FRAME == 0:
				await rig.wait_frames(1)
		if guard >= 400:
			_leg_failed("out of steps", leg, route.size(), hero, target, best)
			return false
	await rig.wait_frames(2)
	return true


func _leg_failed(why: String, leg: int, legs: int, hero: Node3D, target: Vector3,
		best: float) -> void:
	print("FLOOR   %s on leg %d/%d: at %.1f,%.1f, %.1f m short of %.1f,%.1f "
		% [why, leg + 1, legs, hero.global_position.x, hero.global_position.z,
			K.plane(target - hero.global_position).length(), target.x, target.z]
		+ "(closest approach %.1f m)" % best)


## Wait for `prop` to own the interact button. The hero has usually just left
## another prop's trigger and the exit takes a physics frame or two, during which
## `Prompt.focus` is still the thing he walked away from -- a `focus != null`
## wait breaks instantly on the wrong one (gate_locks.gd learned this).
func _focus(rig, prop: Node) -> bool:
	for _i in 90:
		if Prompt.focus == prop:
			return true
		await rig.wait_frames(2)
	return false


# --- D. The shortcut ---------------------------------------------------------------

func _shortcut_refuses(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		_ck("C0 the shortcut door is reachable", false)
		return
	var walked := await _walk_to(rig, d, hero, d.anchor_cell(&"shortcut_door"), door)
	_ck("C0 the shortcut door is reachable on foot from the entrance", walked)
	_ck("C1 and it owns the interact button", await _focus(rig, door))

	var said: String = Hud._prompt
	print("FLOOR shortcut locked prompt=\"%s\"" % said)
	_ck("D0 the hero does not own the Bow yet", not Game.has(&"bow"))
	_ck("D1 the refusal NAMES the bow (\"%s\")" % said, said.contains("BOW"))
	_ck("D2 and does not just say LOCKED", not said.contains("LOCKED"))
	await rig.capture(out.path_join("f_01_shortcut_locked.png"))

	await rig.tap(["interact"])
	await rig.wait_frames(24)
	_ck("D3 pressing it opened nothing", not door.is_open())


func _shortcut_opens(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		return
	_ck("D4 the Warden's death handed over the Bow", Game.has(&"bow"))
	await _walk_to(rig, d, hero, d.anchor_cell(&"shortcut_door"), door)
	if not await _focus(rig, door):
		_ck("D5 the shortcut door owns the button again", false)
		return
	var said: String = Hud._prompt
	print("FLOOR shortcut unlocked prompt=\"%s\"" % said)
	_ck("D5 the prompt is a verb now (\"%s\")" % said, said.contains("OPEN"))

	var announced: Array[StringName] = []
	door.opened.connect(func(where: StringName) -> void: announced.append(where))
	await rig.tap(["interact"])
	await rig.wait_frames(9)
	await rig.capture(out.path_join("f_08_shortcut_swinging.png"))
	await rig.wait_frames(90)
	_ck("D6 the shortcut opened", door.is_open())
	_ck("D7 and told the placer where it goes (%s)" % [announced],
		announced.size() == 1)

	# Through it, to what is on the other side.
	var landing: Node = d.get_node_or_null(^"ShortcutLanding")
	var stairs: Array = _every(landing, func(n: Node) -> bool: return n is Stairs) \
		if landing != null else []
	_ck("D8 there is a way down behind the shortcut", stairs.size() == 1)
	if stairs.is_empty():
		return
	var down: Node3D = stairs[0]
	var walked := await _sweep(rig, hero, [
		door.global_position - door.global_transform.basis.z * 3.0
			+ Vector3(0.0, 0.15, 0.0),
		down.global_position - down.global_transform.basis.z * 2.6
			+ Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("D9 and it is reachable through the opened door", walked)
	_ck("D10 the stair offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, down))
	await rig.capture(out.path_join("f_09_shortcut_stair.png"))

	# "Skips floor N" is the level going up by one without the rest of the floor
	# being walked. `Stairs.activate` calls `Flow.descend`, which is
	# `Run.descend_floor` and then a scene change -- the scene change would take
	# this director down with it, so the half that carries the CLAIM is called
	# directly and the half that loads a floor is left to Flow (CLAUDE.md §6).
	_ck("D11 the shortcut sits at depth 0, twenty metres from the way in",
		int(d.rooms[d.anchor_cell(&"shortcut_door")]["dist"]) == 0)
	Run.descend_floor()
	print("FLOOR shortcut lands on level %d -- %s"
		% [Run.level, FloorDb.name_of(Run.level)])
	_ck("D12 taking it skips the Cistern and lands on the Foundry",
		Run.level == 2 and FloorDb.name_of(2) == "The Foundry")
	# Back, because the beats after this one are still about floor 1. Emitted as
	# well as assigned: the HUD's depth card reads the signal, not the field.
	Run.level = 1
	Bus.level_changed.emit(1)


# --- E. The vault --------------------------------------------------------------------

func _vault_refuses(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"vault_door")
	if door == null:
		_ck("E0 the vault door is reachable", false)
		return
	var walked := await _walk_to(rig, d, hero, d.anchor_cell(&"vault_door"), door)
	_ck("E0 the vault door is reachable on foot from the entrance", walked)
	_ck("E1 and it owns the interact button", await _focus(rig, door))

	var key := FloorDb.vault_key(1)
	var said: String = Hud._prompt
	print("FLOOR vault key=%s locked prompt=\"%s\"" % [key, said])
	_ck("E2 it wants the FOUNDRY's item, not the Cistern's (%s)" % key,
		key == FloorDb.boss_item(2) and key != FloorDb.boss_item(1))
	_ck("E3 the hero does not own it", not Game.has(key))
	await rig.tap(["interact"])
	await rig.wait_frames(24)
	_ck("E4 and it stays shut", not door.is_open())
	await rig.capture(out.path_join("f_02_vault_locked.png"))
	# The refusal is drawn, but it cannot name the Bomb Bag: `LockedDoor.SIGILS`
	# has rows for the bow and the hookshot only, so every other key falls through
	# to SIGIL_DEFAULT's "A KEY". That is one row in a table this card does not
	# own -- reported rather than hidden, and rather than failed, because the
	# door is correct and the table is short.
	if not said.contains("BOMB"):
		_notes.append("the vault says \"%s\" -- LockedDoor.SIGILS has no "
			% said + "`bomb_bag` row, so GDD pillar 3's named refusal is one "
			+ "line short. scripts/props/locked_door.gd, not this card.")


func _the_vault(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"vault_door")
	var vault: Node = d.get_node_or_null(^"Vault")
	_ck("E5 the prefab is built behind the door", vault != null)
	if vault == null or door == null:
		return

	# Three rooms, and they are the prefab's, not a floor's.
	var floors := _every(vault, func(n: Node) -> bool:
		return n is Node3D and n.name.begins_with("Floor"))
	print("FLOOR vault %d slabs, %.1f m deep" % [floors.size(),
		vault.last_room().z + 5.5])
	_ck("E6 it is three rooms (last room centre %.1f m in)"
		% vault.last_room().z, vault.last_room().z > 30.0)

	var bodies := _every(vault, func(n: Node) -> bool: return n is Enemy)
	var levels: Array[int] = []
	var kinds: Array[StringName] = []
	for b in bodies:
		levels.append((b as Enemy).level)
		if not kinds.has((b as Enemy).kind):
			kinds.append((b as Enemy).kind)
	var floor_max := FloorDb.pack(1).y
	print("FLOOR vault pack=%d over 3 rooms (floor caps at %d/room), kinds=%s, "
		% [bodies.size(), floor_max, kinds] + "level=%s" % [levels.slice(0, 3)])
	_ck("E7 the vault's bodies are a floor deeper than the floor (%d)"
		% (levels[0] if not levels.is_empty() else 0),
		not levels.is_empty() and levels.min() == 2)
	# Its identity is still the Cistern's. A vault with a roster of its own has
	# become floor 5, and floor 5 is out of scope (SCOPE §2).
	var deep_pool: Array = FloorDb.roster(1, 99)
	var alien := 0
	for k: StringName in kinds:
		if not deep_pool.has(k):
			alien += 1
	_ck("E8 and they are still the Cistern's own %s" % [deep_pool], alien == 0)

	var chest: Chest = vault.rich_chest()
	var deep: Chest = d.anchor_node(&"deep_chest")
	# It asks the curve the FLOOR BELOW's deepest-chest question, and the honest
	# claim is that and not "more picks". `Prog.chest_picks` steps once every
	# three floors, so on floor 1 the count ties the deep chest at 3 -- the vault
	# is richer because those three picks roll a level-2 table with a level-2
	# `rarity_lift` behind it, and demanding a bigger NUMBER here would be a
	# second curve invented in a director (SCOPE §2).
	var want_picks := Prog.chest_picks(2, true)
	_ck("E9 the rich chest rolls the floor below's deepest table (%d picks, "
		% (chest.picks if chest != null else -1)
		+ "the deep chest's own is %d)" % (deep.picks if deep != null else -1),
		chest != null and deep != null and chest.picks == want_picks
		and chest.picks >= deep.picks)

	# Nothing is lying in it yet, and that is the point: a `LootMote` is a live
	# pickup, and one minted at floor build sits in a room nobody can enter,
	# answering "is there loot near you" through the door. `Vault.reveal()` has
	# the rest of the reasoning; `mvp_loop.gd` found it by hauling the relic out
	# of a vault it never opened.
	var want := FloorDb.relic_in(1, &"vault")
	_ck("E10 the prize is not on the floor while the door is shut",
		vault.relic_mote() == null and RelicDb.outstanding(want))

	# Open it and walk in. The Bomb Bag is M5's; granting it here is the same
	# move gate_locks makes with the Bow, and it is the only way to photograph
	# what the door is for.
	Game.grant(FloorDb.vault_key(1))
	await rig.wait_frames(8)
	await _walk_to(rig, d, hero, d.anchor_cell(&"vault_door"), door)
	_ck("E11 the vault door owns the button with the key in the bag",
		await _focus(rig, door))
	print("FLOOR vault unlocked prompt=\"%s\"" % Hud._prompt)
	await rig.tap(["interact"])
	await rig.wait_frames(100)
	_ck("E12 the vault opened", door.is_open())
	var relic: LootMote = vault.relic_mote()
	_ck("E12a and opening it put %s in the last room" % want,
		relic != null and relic.item_id == want)
	await rig.capture(out.path_join("f_10_vault_open.png"))

	var walked := await _sweep(rig, hero, [
		door.global_position - door.global_transform.basis.z * 4.0
			+ Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(0)) + Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(1)) + Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(2)) + Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("E13 all three rooms are reachable through the door", walked)
	await rig.capture(out.path_join("f_11_vault_prize.png"))


# --- The boss, and the way down ------------------------------------------------------

func _the_boss(rig, d: Node, hero: Node3D) -> void:
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	var door: Node3D = d.anchor_node(&"boss_door")
	if arena == null or door == null:
		_ck("G0 the deepest room holds an arena and a boss door", false)
		return

	# Into the room, not up to the door -- the door is outside the seal, which is
	# the whole point of it.
	var walked := await _walk_rooms(rig, d, hero, d.deepest)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)
	_ck("G0 the deepest room is reachable on foot from the entrance", walked)
	_ck("G1 walking in sealed it", arena.is_sealed())
	var boss: Node = arena.boss()
	_ck("G2 the Warden is awake", boss != null and boss.is_awake())
	await rig.capture(out.path_join("f_03_sealed.png"))

	# The door refuses by naming what is holding it, not by saying LOCKED.
	_ck("G3 the boss door is still shut", not door.is_open())
	print("FLOOR boss door refusal=\"%s\"" % door._seal_line())
	_ck("G4 and it names the Warden (\"%s\")" % door._seal_line(),
		door._seal_line().contains("WARDEN"))

	if boss == null:
		return
	# Killed off the real damage path, paced past the i-frames, with the hero
	# healed between blows -- he is standing in a live boss fight and dying here
	# would end the run in the middle of a measurement.
	var swings := 0
	while boss.health.quarters > 0 and swings < 40:
		if boss.health.apply_hit(Hit.make(12, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		Game.heal(999)
		await rig.wait_seconds(K.IFRAME_TIME + 0.06)
	await rig.wait_frames(60)
	_ck("G5 the Warden died (%d landed blows)" % swings,
		boss == null or not is_instance_valid(boss)
		or boss.health.quarters == 0)
	_ck("G6 the seal came down", not arena.is_sealed())
	_ck("G7 the arena is spent", arena.is_spent())
	_ck("G8 the boss door opened", door.is_open())
	_ck("G9 and the Bow is the hero's (GDD §5.2)", Game.has(FloorDb.boss_item(1)))
	await rig.capture(out.path_join("f_04_boss_dead.png"))


func _deep_chest(rig, d: Node, hero: Node3D) -> void:
	var chest: Node3D = d.anchor_node(&"deep_chest")
	if chest == null:
		return
	var want := FloorDb.relic_in(1, &"deep_chest")
	_ck("F0 floor 1's deep-chest relic is %s" % want, want != &"")
	_ck("F1 and it is still down here", RelicDb.outstanding(want))

	# 1.2 m, and a tight arrival, because a `Chest` reaches 1.7 m (`chest.gd`
	# sets it) where a `LockedDoor` reaches 2.9. Standing the usual two metres off
	# put the hero OUTSIDE the only prop on this floor with a short reach: he was
	# beside the chest, in frame with it, and it never offered itself.
	var walked := await _sweep(rig, hero, [
		chest.global_position + chest.global_transform.basis.z * 1.2
			+ Vector3(0.0, 0.15, 0.0)], 0.35)
	var to := K.flat(chest.global_position - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("F2 the deep chest is reachable, beside the boss door", walked)
	_ck("F3 and it offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, chest))
	await rig.capture(out.path_join("f_05_deep_chest.png"))

	await rig.tap(["interact"])
	# Polled, and not "wait forty frames then look". The hero is standing inside
	# the mote's own pickup reach, so a relic spat onto the floor is his about a
	# second later -- a fixed wait photographed an empty floor and called the
	# chest empty. This catches it on the frame it lands.
	var motes: Array = []
	for _i in 24:
		motes = _every(rig.scene(), func(n: Node) -> bool:
			return n is LootMote and (n as LootMote).item_id == want)
		if not motes.is_empty():
			break
		await rig.wait_frames(2)
	_ck("F4 opening it put the relic on the floor as a mote", motes.size() == 1)
	await rig.capture(out.path_join("f_06_relic_mote.png"))

	# Walk over it -- if it has not already rolled onto him. He is standing a
	# stride from the chest, which is inside a mote's own pickup reach, so the
	# relic is often his before this line runs; that is the beat happening early,
	# not the beat not happening, and the claim below is about where it ENDED UP.
	if not motes.is_empty() and is_instance_valid(motes[0]):
		var mote: Node3D = motes[0]
		await _sweep(rig, hero, [mote.global_position + Vector3(0.0, 0.15, 0.0)],
			0.35)
	await rig.wait_frames(30)
	# The relic rides in the bag like everything else -- it is not granted
	# (docs/GDD.md §3, and relic_donate.gd proves the rest of that trip).
	_ck("F5 it went into the bag and not into Game.items",
		Run.bag.get(want, 0) == 1 and not Game.items.has(want))

	# One relic, not two. `RelicPickup` refuses to mint a second copy of a unique,
	# and a chest that can be activated twice is how that rule would get broken.
	chest.activate(hero)
	await rig.wait_frames(30)
	var again := _every(rig.scene(), func(n: Node) -> bool:
		return n is LootMote and (n as LootMote).item_id == want)
	_ck("F6 and re-opening the chest mints no second copy (%d loose, %d in the bag)"
		% [again.size(), Run.bag.get(want, 0)],
		again.is_empty() and Run.bag.get(want, 0) == 1)


func _way_down(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"boss_door")
	var landing: Node = d.get_node_or_null(^"BossLanding")
	if door == null or landing == null:
		_ck("G10 there is a landing behind the boss door", false)
		return
	var stairs := _every(landing, func(n: Node) -> bool: return n is Stairs)
	if stairs.is_empty():
		_ck("G10 there is a way down behind the boss door", false)
		return
	var down: Node3D = stairs[0]
	var walked := await _sweep(rig, hero, [
		door.global_position + door.global_transform.basis.z * 2.4
			+ Vector3(0.0, 0.15, 0.0),
		door.global_position - door.global_transform.basis.z * 3.0
			+ Vector3(0.0, 0.15, 0.0),
		down.global_position - down.global_transform.basis.z * 2.6
			+ Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("G10 the way down is reachable through the opened boss door", walked)
	_ck("G11 the stair offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, down))
	await rig.capture(out.path_join("f_07_way_down.png"))


# --- G. The Long Descent is untouched ---------------------------------------------

## The endless row authors nothing, so an unauthored floor has to come out of
## this generator exactly as it did before the Descent existed: no anchors, no
## locked doors, and the stair back in the deepest room. A manifest that had
## quietly become mandatory would break the post-credits mode and nothing else
## would say so.
func _endless(rig, hero: Node3D) -> void:
	var d := await _rebuild(rig, 5)
	if d == null:
		return
	hero.global_position = d.centre_of(d.entrance) + Vector3(0.0, 0.15, 0.0)
	Bus.camera_recenter.emit()
	print("FLOOR level 5 -- %s, %d rooms, anchors %s"
		% [FloorDb.name_of(5), d.rooms.size(), d.placements.keys()])
	_ck("H0 level 5 is the Long Descent",
		FloorDb.name_of(5) == "The Long Descent")
	_ck("H1 its length is the curve's, not a manifest's (%d)" % d.rooms.size(),
		d.rooms.size() == Prog.rooms(5))
	_ck("H2 it authors no anchors", d.placements.is_empty())
	_ck("H3 so there are no locked doors on it",
		_every(d, func(n: Node) -> bool: return n is LockedDoor).is_empty())
	var deep_root: Node = d.rooms[d.deepest]["node"]
	_ck("H4 and the stair is back in the deepest room",
		_every(deep_root, func(n: Node) -> bool: return n is Stairs).size() == 1)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("f_12_endless.png"))
