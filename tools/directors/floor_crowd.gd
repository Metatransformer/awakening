extends RefCounted
## Card #42 — **how many bodies actually converge, when you walk in like a
## player.**
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/floor_crowd.gd \
##     --out=/tmp/crowd/x.png --warmup=60 --run-seed=4004
##
## `--run-seed=N` pins the floor. `--level=N` picks the floor (default 1).
## `--stand=N` is how many game seconds the standing-still beat holds for.
##
## ## Why this exists and `mvp_loop` does not answer it
##
## `mvp_loop` prints `MVP enemies=N` and N is 18-27 on floor 1. That number is
## **the whole floor**: every body in the `enemy` group, across six rooms, most
## of them two rooms away and asleep. Card #42 was opened on the reading that it
## was a crowd, and the thing a crowd means is *how many are on you at once* —
## which is a different number, has never been measured, and is the only one the
## player experiences.
##
## So this counts the number that is actually about the fight:
##
##   `engaged`  bodies not IDLE and not DEAD — `Enemy.is_engaged()`, the same
##              predicate `Music` uses to decide the floor is in combat.
##   `near`     bodies inside `NEAR_M` of the hero, which is the crowd you can
##              see and the crowd that can reach you.
##   `rooms`    how many DISTINCT rooms those engaged bodies came from. This is
##              the leash question stated as a number: one is the design (a room
##              is the encounter), two means a corridor pulled its neighbours in,
##              three means the floor is following you around.
##
## And it takes them while the hero **walks the floor**, held-input, at the frame
## rate the machine gives — not teleported into a room and stood still, which is
## what produced the reading on the card.
##
## ## The bounds, and where they come from
##
## `docs/GDD.md` §7 already states this budget and it is stated **per room**:
## *"a room never holds more than seven."* `Prog.pack` is that sentence in code —
## `mini(4 + l, 7)` — so the ceiling is enforced, not merely written down. What
## no doc stated until this card is the thing the ceiling is worth nothing
## without: **that a room's pack stays a room's pack when you walk between two of
## them.** Rooms sit on a 26 m grid and the corridor between two of them is 10 m
## long, so its midpoint is 13 m from both room centres while `detect` is 11-15 m
## and the scatter puts bodies up to 4.8 m off centre. Two rooms answering at
## once is arithmetically available. Whether it happens is what this measures.
##
##   `PACK_MAX`     no room may hold more than seven bodies. GDD §7, verbatim.
##   `ENGAGED_MAX`  no more than `PACK_MAX` may be engaged at any instant. A
##                  second room joining in is the failure this is shaped to
##                  catch, and it is deliberately NOT `PACK_MAX * 2`.
##   `ROOMS_MAX`    at most two rooms contribute at once. Two is not a
##                  concession: standing in a doorway and pulling the room you
##                  are about to walk into is correct, and a leash that stopped
##                  it would also stop a monster following you out of its room,
##                  which is the whole of `Enemy.LEASH`.
##
## Nothing here asserts on the FLOOR total. That is the card's number and it is
## the wrong unit: six rooms of four is not a crowd, it is a floor.

## Metres. Everything inside this of the hero is "on you" — a body at 6 m closes
## in about two seconds at `skeleton` speed, which is inside one swing.
const NEAR_M := 6.0

## `docs/GDD.md` §7 — "a room never holds more than seven".
const PACK_MAX := 7
const ENGAGED_MAX := 7
const ROOMS_MAX := 2

## How long the hero is given to cross one room-to-room leg, in game seconds.
## 26 m at `K.RUN_SPEED` (4.37 m/s) is 6 s; this is that with room for a doorway.
const LEG_SECONDS := 14.0

var out := ""
var _fails := 0
var _shot := 0

# Peaks, carried across every beat so the summary is about the run and not a leg.
var _peak_engaged := 0
var _peak_near := 0
var _peak_rooms := 0
var _peak_where := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/crowd/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("CROWD FAIL wrong host scene (%s) -- pass "
			% rig.scene().name + "--scene=res://scenes/rooms/dungeon.tscn")
		return

	var level := int(rig.arg("level", "1"))
	var run_seed := int(rig.arg("run-seed", "4004"))
	var stand_for := float(rig.arg("stand", "30"))

	Game.reset()
	Run.enter(run_seed)
	var d := await _build(rig, level, run_seed)
	if d == null:
		print("CROWD FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	var cam := _camera(rig)
	if hero == null or cam == null:
		print("CROWD FAIL no hero or no GameCamera")
		return
	cam.make_current()
	await rig.wait_frames(20)

	# --- A. The census -------------------------------------------------------
	# What the floor holds, per room, which is the unit the design speaks in.
	var census := _census(rig, d, level)

	# --- B. Walk into each room that has anybody in it ------------------------
	#
	# **Not "walk the path to the deepest room", which was the first cut.** The
	# tree path runs through the MAZE, whose room is masonry wall to wall, so the
	# hero ran into it, stood there for the rest of the leg, and this director
	# reported a floor on which nobody ever woke up — a passing run that had
	# measured nothing. The unit is the room, so the approach is per room: put
	# him at the far end of the corridor his parent room feeds in through, and
	# walk him in through the doorway on held input.
	var deaths_before: int = Game.deaths
	var rooms_walked := _populated(d, census["per"])

	# The room, walked into, and then FOUGHT. A hero who never swings is not a
	# reading about the encounter, it is a reading about a statue -- and the
	# statue is what the card's evidence was.
	#
	# Healed to full first, and so is the standing beat below. Each beat is a
	# separate question and a hero who walks into the second room on the hearts
	# the first one left him is answering a THIRD one -- the first cut had the
	# statue beat starting at 6 of 12 because the fight beat had just happened,
	# and "died in 5.1 s" meant nothing at all.
	var fought := ""
	var cleared: Array = []
	var deaths_after_fight: int = deaths_before
	if not rooms_walked.is_empty() and Game.deaths == deaths_before:
		var cell: Vector2i = rooms_walked[0]
		var tag := "fight%s" % [cell]
		cleared.append(cell)
		Game.heal(Game.max_quarters)
		if await _approach(rig, d, hero, cell, tag):
			await _capture(rig, "arrived_fight")
			var hp0: int = Game.quarters
			var killed := await _fight(rig, d, hero, stand_for, tag)
			await _capture(rig, "fought")
			deaths_after_fight = Game.deaths
			fought = "%d of %d killed, hp %d -> %d, died=%s" % [
				killed, int(census["per"][cell]), hp0, Game.quarters,
				deaths_after_fight > deaths_before]
			print("CROWD %s: %s" % [tag, fought])

	# Then the corridor, which is where two rooms could answer at once.
	#
	# **The lethal beats go LAST, and the order is load-bearing.** `Run.die()`
	# ends the run: the hero is locked, the floor is gone, and every beat after
	# it measures wreckage while reporting numbers. On seed 1234 the corridor
	# beat killed him first and the two beats behind it printed "not reached"
	# and a hero pinned with 13 m to go -- a run that looked like a director bug
	# and was a dead player. The fight beat is the one that must not kill, so it
	# is the one that goes first.
	var corridor := ""
	# Excluding the room the fight beat just emptied: a corridor between a
	# cleared room and a full one is not the two-rooms-at-once question.
	var pair := _adjacent_pair(d, census["per"], cleared)
	if not pair.is_empty() and Game.deaths == deaths_before:
		Game.heal(Game.max_quarters)
		corridor = await _corridor_stand(rig, d, hero, pair[0], pair[1], stand_for)

	# And the card's own scenario at a real frame rate: walk in, then stand
	# there and do nothing at all. The pre-fix `mvp_loop` did this for 68 s at
	# 6 fps and died every time; whether it is lethal when the clock is honest
	# is the question, and it is a per-room question.
	var stood := ""
	var deaths_at_stand: int = Game.deaths
	if not rooms_walked.is_empty() and Game.deaths == deaths_before:
		var cell: Vector2i = rooms_walked[mini(1, rooms_walked.size() - 1)]
		var tag := "stand%s" % [cell]
		Game.heal(Game.max_quarters)
		if await _approach(rig, d, hero, cell, tag):
			await _capture(rig, "arrived_stand")
			var hp0: int = Game.quarters
			print("CROWD %s standing still for %.0f game seconds at hp=%d" % [
				tag, stand_for, hp0])
			await _sample_seconds(rig, d, hero, stand_for, tag)
			await _capture(rig, "stood")
			stood = "%d bodie(s), hp %d -> %d, died=%s" % [
				int(census["per"][cell]), hp0, Game.quarters,
				Game.deaths > deaths_at_stand]
			print("CROWD %s: %s" % [tag, stood])

	# --- The verdict ---------------------------------------------------------
	print("")
	print("CROWD floor %d seed %d -- %d in the `enemy` group: %d across %d room(s)"
		% [level, run_seed, census["total"], census["walked"], census["rooms"]]
		+ ", %d behind a door" % census["behind"])
	print("CROWD peak engaged=%d near(%.0fm)=%d rooms=%d  (%s)" % [
		_peak_engaged, NEAR_M, _peak_near, _peak_rooms, _peak_where])
	print("CROWD fighting:       %s"
		% ("not reached" if fought.is_empty() else fought))
	print("CROWD in the corridor: %s"
		% ("no adjacent pair" if corridor.is_empty() else corridor))
	print("CROWD standing still:  %s"
		% ("not reached" if stood.is_empty() else stood))
	_ck("no room holds more than %d (GDD §7)" % PACK_MAX,
		int(census["max_room"]) <= PACK_MAX)
	_ck("never more than %d engaged at once (peak %d)"
		% [ENGAGED_MAX, _peak_engaged], _peak_engaged <= ENGAGED_MAX)
	_ck("never more than %d room(s) engaged at once (peak %d)"
		% [ROOMS_MAX, _peak_rooms], _peak_rooms <= ROOMS_MAX)
	# The one survival claim worth making. **Not** "standing still survives":
	# a hero who refuses to defend himself is not a promise this design makes,
	# and asserting it would make the bar the statue rather than the player.
	_ck("a hero who walks in and swings survives the room",
		deaths_after_fight == deaths_before)

	if _fails == 0:
		print("CROWD ok -- the floor's total is not the encounter, "
			+ "and the encounter is a room")
	else:
		print("CROWD FAIL -- %d check(s) failed" % _fails)


# --- The census ---------------------------------------------------------------

## Bodies per room, which is the number the design budgets and the number
## `mvp_loop`'s floor total hides.
func _census(rig, d: Node, level: int) -> Dictionary:
	var rooms: Dictionary = d.get(&"rooms")
	# Room ROOT -> cell. `_spawn_foe` parents every body to the room root, so
	# this is the generator's own answer to "whose is it" — and a position-based
	# lookup is not: a body that has walked into the corridor is still its room's,
	# and attributing it by where it stands is what turns a conga line into a
	# tidy-looking census.
	var owner_of: Dictionary = {}
	for cell: Vector2i in rooms:
		var node: Node = rooms[cell]["node"]
		if node != null:
			owner_of[node] = cell
	var per: Dictionary = {}
	var total := 0
	# **The half of the total that is not on the floor you walk.** A body whose
	# parent is not a room root belongs to something the generator built beside
	# the room tree — the vault, the boss's arena, the miniboss's — and every one
	# of those is behind a door the player cannot open on the way past. They are
	# in the `enemy` group, so `mvp_loop`'s `MVP enemies=N` counts them, and that
	# is the single largest reason its number reads as a crowd.
	var sealed: Dictionary = {}
	for e in rig.scene().get_tree().get_nodes_in_group(&"enemy"):
		total += 1
		var home: Node = (e as Node).get_parent()
		if not owner_of.has(home):
			var where: String = home.name if home != null else "<none>"
			sealed[where] = int(sealed.get(where, 0)) + 1
			continue
		per[owner_of[home]] = int(per.get(owner_of[home], 0)) + 1
	var behind := 0
	# **These lines print before the per-room ones. That is a report layout and
	# NOT the group's iteration order** -- card #42 read it as one and card #60
	# was filed on the strength of it ("the Arena/Vault/MinibossArena bodies
	# iterate first on every seed"). Measured afterwards on 40 seeds: `foes[0]`
	# was a ROOM body on 40 of 40. `Vault` and `MinibossArena` hang off the
	# Dungeon rather than off a room root and are built after every room, so
	# they come LAST; the boss's `Arena` does precede its own room's pack, but
	# its room is the deepest and lands 3rd-5th in `rooms` while the first
	# populated room lands 1st or 2nd.
	# The order above is a fact about this loop, which walks `sealed` before it
	# reaches `per`. Do not quote it as a fact about the scene tree.
	for where: String in sealed:
		behind += int(sealed[where])
		print("CROWD %d bodie(s) under %s -- not on the walked floor"
			% [int(sealed[where]), where])
	var most := 0
	print("CROWD F%d pack=%s rooms=%d" % [
		level, FloorDb.pack(level), rooms.size()])
	for cell: Vector2i in rooms:
		var n: int = int(per.get(cell, 0))
		most = maxi(most, n)
		var tags: Array = (rooms[cell]["anchors"] as Dictionary).keys()
		print("CROWD F%d room %s dist=%d -> %d bodies%s%s" % [
			level, cell, rooms[cell]["dist"], n,
			"  [entrance]" if cell == d.get(&"entrance") else "",
			("  anchors=%s" % [tags]) if not tags.is_empty() else ""])
	print("CROWD F%d total=%d = %d in rooms + %d behind a door; busiest room=%d"
		% [level, total, total - behind, behind, most])
	return {"total": total, "rooms": rooms.size(), "max_room": most,
		"walked": total - behind, "behind": behind, "per": per}


# --- The walk -----------------------------------------------------------------

## Rooms with anybody in them, shallowest first — the order a player meets them.
func _populated(d: Node, per: Dictionary) -> Array:
	var rooms: Dictionary = d.get(&"rooms")
	var cells: Array = []
	for cell: Vector2i in per:
		if int(per[cell]) > 0:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(rooms[a]["dist"]) < int(rooms[b]["dist"]))
	return cells


## Put the hero at the far end of the corridor that feeds `cell` and walk him in.
##
## The teleport is the fixture and the walk is the measurement: he is placed in
## the CORRIDOR, outside the room and outside every `detect` radius in it, and
## everything after that is held input through a real doorway. That is the
## difference between this and the reading on the card, which was taken with the
## hero set down in the middle of the room by a harness.
func _approach(rig, d: Node, hero: Node3D, cell: Vector2i, tag: String) -> bool:
	var rooms: Dictionary = d.get(&"rooms")
	var parent: Vector2i = rooms[cell]["parent"]
	var centre := _cell_world(d, cell)
	if parent == cell:
		# The entrance has no parent to come in through. Nothing spawns there,
		# so this is unreachable today and cheap to be honest about.
		return false
	var step := parent - cell
	var dir := Vector3(float(step.x), 0.0, float(step.y)).normalized()
	# Half the room plus most of the corridor: 8 m of masonry and 5 of the 10 m
	# gap, which puts him beyond the 11-15 m `detect` of everything inside.
	var from := centre + dir * 13.0
	hero.velocity = Vector3.ZERO
	hero.global_position = from + Vector3(0.0, 0.15, 0.0)
	await _face(rig, hero, centre)
	print("CROWD %s approaching from %.0f m down the corridor" % [tag, 13.0])
	await _walk_to(rig, d, hero, centre, tag + " approach")
	return K.plane(centre - hero.global_position).length() <= 4.0


## Close on the nearest body and swing at it until the room is clear or the
## clock runs out. Returns how many died.
##
## **A crude player, and crude on purpose.** It never blocks, never rolls, never
## parries and never backs off — it walks at the nearest thing and presses the
## sword. That is the FLOOR of what a hand on a keyboard does, so a survival it
## reports is a survival a real player beats, and a death it reports is a real
## question about the encounter rather than about the director's tactics.
##
## `rig.tap`, not `Input.action_press`: `attack` is read as an event, and a
## press that dispatches no `InputEvent` is the trap in CLAUDE.md §3 that made
## eleven of twelve swings vanish out of `mvp_loop`.
func _fight(rig, d: Node, hero: Node3D, secs: float, tag: String) -> int:
	var deaths0: int = Game.deaths
	var alive0 := _alive_near(hero, 30.0)
	var gone := 0.0
	while gone < secs:
		var foe := _nearest(hero)
		if foe == null:
			print("CROWD %s room clear after %.1f s" % [tag, gone])
			break
		var to := K.plane(foe.global_position - hero.global_position)
		var reach := 1.9
		if to.length() > reach:
			_press_stick(hero, to.normalized())
			await rig.wait_physics_frames(1)
			gone += get_physics_delta()
			_sample(d, hero, tag)
		else:
			_release_stick()
			hero.facing_yaw = atan2(to.x, to.z)
			# A swing is 0.60 game seconds (`HeroCombat.swing_time`) and a press
			# in the front half of one is dropped as a mash, so the sampling
			# after the tap is what keeps the cadence honest as well as what
			# takes the reading.
			await rig.tap(["attack"])
			var swing := 0.0
			while swing < 0.62:
				await rig.wait_physics_frames(1)
				swing += get_physics_delta()
				_sample(d, hero, tag)
			gone += swing
		if Game.deaths > deaths0:
			print("CROWD %s died fighting after %.1f s" % [tag, gone])
			break
	_release_stick()
	return maxi(alive0 - _alive_near(hero, 30.0), 0)


func _nearest(hero: Node3D) -> Node3D:
	var best: Node3D = null
	var far := -1.0
	for n in hero.get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var hp = e.get("health")
		if hp != null and bool(hp.dead):
			continue
		var dist := K.plane(e.global_position - hero.global_position).length()
		# Only what is in this room. The vault's twelve are 30 m away behind a
		# locked door and picking one as "nearest" would walk the hero into a
		# wall for the whole beat.
		if dist > 14.0:
			continue
		if far < 0.0 or dist < far:
			far = dist
			best = e
	return best


func _alive_near(hero: Node3D, within: float) -> int:
	var n := 0
	for x in hero.get_tree().get_nodes_in_group(&"enemy"):
		var e := x as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var hp = e.get("health")
		if hp != null and bool(hp.dead):
			continue
		if K.plane(e.global_position - hero.global_position).length() <= within:
			n += 1
	return n


## Two populated rooms that share a wall, if the floor drew any.
func _adjacent_pair(d: Node, per: Dictionary, except: Array) -> Array:
	var rooms: Dictionary = d.get(&"rooms")
	for a: Vector2i in _populated(d, per):
		if except.has(a):
			continue
		for b: Vector2i in _populated(d, per):
			if a == b or except.has(b):
				continue
			if rooms[b]["parent"] == a or rooms[a]["parent"] == b:
				return [a, b]
	return []


## Stand in the middle of the corridor between two populated rooms.
##
## **This is the arithmetic the card is really about.** Rooms sit on a 26 m grid
## and are 16 m across, so the corridor between two of them is 10 m long and its
## midpoint is 13 m from both centres, while `detect` runs 11-15 m and the spawn
## scatter puts bodies up to 4.8 m off centre. Two rooms answering at once is
## available on paper. Whether they do is what this stands there to find out.
func _corridor_stand(rig, d: Node, hero: Node3D, a: Vector2i, b: Vector2i,
		secs: float) -> String:
	var mid := (_cell_world(d, a) + _cell_world(d, b)) * 0.5
	hero.velocity = Vector3.ZERO
	hero.global_position = mid + Vector3(0.0, 0.15, 0.0)
	await _face(rig, hero, _cell_world(d, b))
	print("CROWD corridor between %s and %s -- standing %.0f s in the middle"
		% [a, b, secs])
	var hp: int = Game.quarters
	var deaths0: int = Game.deaths
	await _sample_seconds(rig, d, hero, secs, "corridor %s|%s" % [a, b])
	await _capture(rig, "corridor")
	var line := "%s(%d) + %s(%d), hp %d -> %d, died=%s" % [
		a, _per_now(hero, _cell_world(d, a)), b, _per_now(hero, _cell_world(d, b)),
		hp, Game.quarters, Game.deaths > deaths0]
	print("CROWD corridor stood %.0f s: %s" % [secs, line])
	return line


## How many living bodies are standing within a room's half-width of `centre`.
## Reported beside the corridor result so the line says what the two rooms were
## worth, rather than leaving the reader to go back up to the census for it.
func _per_now(hero: Node3D, centre: Vector3) -> int:
	var n := 0
	for x in hero.get_tree().get_nodes_in_group(&"enemy"):
		var e := x as Node3D
		if e == null or not is_instance_valid(e):
			continue
		if K.plane(e.global_position - centre).length() <= 8.0:
			n += 1
	return n

## Steer to `to` on held input, sampling the crowd every physics frame.
##
## Held input via `Input.action_press`, which is correct HERE and wrong for a
## button: movement is polled out of `Input` every physics frame, so no
## `InputEvent` is needed (CLAUDE.md §3 — the row is about `_unhandled_input`,
## which movement never goes near).
##
## **Re-aimed every frame, and the first cut was not.** Pressing `move_up` once
## and holding it walks the hero in the CAMERA's forward, and the camera swings
## behind him as he goes; over 26 m that drift was enough to put him into the
## doorframe instead of through the 2.4 m doorway, where he stood pushing at
## masonry for ten seconds while this director recorded a floor with nobody
## awake on it. A player corrects. So does this: `_press_stick` solves the stick
## that `Hero._camera_relative` would turn into the direction we want, which is
## the same closed loop a hand on a pad is.
func _walk_to(rig, d: Node, hero: Node3D, to: Vector3, tag: String) -> void:
	await _face(rig, hero, to)
	var deaths0: int = Game.deaths
	var left := LEG_SECONDS
	var stuck := 0.0
	var was := hero.global_position
	while left > 0.0:
		var want := K.plane(to - hero.global_position)
		if want.length() <= 1.6:
			break
		_press_stick(hero, want.normalized())
		await rig.wait_physics_frames(1)
		left -= get_physics_delta()
		_sample(d, hero, tag)
		# A hero pinned on geometry is a result, not a hang: say so and move on
		# rather than spending the whole leg budget on it.
		stuck += get_physics_delta()
		if stuck >= 1.0:
			if K.plane(hero.global_position - was).length() < 0.30:
				print("CROWD %s pinned at %.1f,%.1f with %.1f m to go"
					% [tag, hero.global_position.x, hero.global_position.z,
						want.length()])
				break
			was = hero.global_position
			stuck = 0.0
		if Game.deaths > deaths0:
			break
	_release_stick()
	await rig.wait_physics_frames(2)
	var gap := K.plane(to - hero.global_position).length()
	print("CROWD %s stopped %.1f m short after %.1f s (hp=%d)" % [
		tag, gap, LEG_SECONDS - left, Game.quarters])


## Hold the four move actions at the strengths whose camera-relative sum is
## `dir`. `Input.get_vector` reads (right - left, down - up) and `Hero` turns
## that into `right * x + fwd * -y`, so the stick we want is the projection of
## `dir` onto the camera's own basis.
func _press_stick(hero: Node3D, dir: Vector3) -> void:
	var cam := hero.get_viewport().get_camera_3d()
	var fwd := K.plane(Vector3.FORWARD)
	var right := K.plane(Vector3.RIGHT)
	if cam != null:
		fwd = K.plane(-cam.global_transform.basis.z)
		right = K.plane(cam.global_transform.basis.x)
	if fwd == Vector3.ZERO or right == Vector3.ZERO:
		return
	var stick := Vector2(dir.dot(right.normalized()),
		-dir.dot(fwd.normalized())).normalized()
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
	for a: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func get_physics_delta() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


# --- The measurement ----------------------------------------------------------

## One sample. `is_engaged()` and not "distance < detect": the state machine is
## what decides whether a body is in the fight, and a monster inside the radius
## that has not woken is not pressure.
func _sample(d: Node, hero: Node3D, tag: String) -> void:
	var engaged := 0
	var near := 0
	var homes := {}
	for n in hero.get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var dist := K.plane(e.global_position - hero.global_position).length()
		if dist <= NEAR_M:
			near += 1
		if e.has_method("is_engaged") and bool(e.call("is_engaged")):
			engaged += 1
			# The room it was SPAWNED in, not the one it is standing in: a body
			# that has followed the hero out of its room is still that room's,
			# and counting where it stands would report the conga line as one
			# room and hide exactly the failure this counts.
			homes[e.get_parent()] = true
	if engaged > _peak_engaged or near > _peak_near or homes.size() > _peak_rooms:
		_peak_where = tag
	_peak_engaged = maxi(_peak_engaged, engaged)
	_peak_near = maxi(_peak_near, near)
	_peak_rooms = maxi(_peak_rooms, homes.size())


## Seconds of GAME clock, not rendered frames. The whole of card #14 was a beat
## whose deadline was denominated in frames on a machine rendering at 6 fps.
##
## The death test is against a BASELINE taken here and not against zero. Written
## against zero, every beat after the first death returned on its first frame
## and reported "died after 0.0 s" for a hero who was standing in an empty
## corridor -- a measurement of nothing, printed as the strongest result in the
## log.
func _sample_seconds(rig, d: Node, hero: Node3D, secs: float, tag: String) -> void:
	var deaths0: int = Game.deaths
	var gone := 0.0
	var shot_at := 0.0
	while gone < secs:
		await rig.wait_physics_frames(1)
		gone += get_physics_delta()
		_sample(d, hero, tag)
		# A frame every ten seconds, so the standing beat is a strip and not a
		# claim: "he was fine" and "he was surrounded" look identical in a log.
		if gone - shot_at >= 10.0:
			shot_at = gone
			await _capture(rig, "%s_%02ds" % [tag, int(gone)])
		if Game.deaths > deaths0:
			print("CROWD %s died after %.1f s of standing still" % [tag, gone])
			return


# --- Fixture ------------------------------------------------------------------

func _build(rig, level: int, run_seed: int) -> Node:
	Run.level = level
	var scene: Node = rig.scene()
	# **Wait until the scene's own floor is REALLY gone.** `dungeon.tscn` builds
	# a dungeon in its own `_ready`, off a wall-clock seed, before any director
	# exists. Renaming it and calling `queue_free()` is not enough: for the two
	# frames the first cut of this waited, fourteen of that floor's monsters were
	# still in the `enemy` group and — worse, because it is invisible in a count
	# — its WALLS were still in the physics world. The hero pinned himself on a
	# corridor belonging to a floor that no longer existed, 7.2 m short of a room
	# he could see, and the run reported a floor with nobody awake on it.
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		var swept := func() -> bool:
			return scene.get_node_or_null(^"DungeonOld") == null \
				and scene.get_tree().get_nodes_in_group(&"enemy").is_empty()
		var gone: bool = await rig.until(swept, 5.0)
		if not gone:
			print("CROWD FAIL the scene's own floor would not go away")
			return null
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	# `Run.floor_seed()` mixes the level in, which is what makes floor 2 of a
	# seed differ from floor 1 of it. `seed_override` is the same knob
	# `--run-seed` reaches through `Run.enter`, so a run of this director and a
	# run of mvp_loop on the same number get the same floor.
	d.seed_override = Run.floor_seed()
	scene.add_child(d)
	await rig.wait_frames(14)
	return d


func _cell_world(d: Node, cell: Vector2i) -> Vector3:
	var spacing: float = float(d.get(&"spacing"))
	return Vector3(float(cell.x) * spacing, 0.0, float(cell.y) * spacing)


## Point the hero at `at` and put the camera behind him, so `move_up` is
## forward. `facing_yaw` is the HEADING yaw and the body is `+ PI` off it —
## CLAUDE.md §4, and the reason this is two assignments and not one.
func _face(rig, hero: Node3D, at: Vector3) -> void:
	var to := K.plane(at - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(20)


func _capture(rig, stem: String) -> void:
	await rig.capture(out.path_join("c_%02d_%s.png" % [_shot, stem]))
	_shot += 1


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("CROWD ok %s" % label)
	else:
		_fails += 1
		print("CROWD FAIL %s" % label)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
