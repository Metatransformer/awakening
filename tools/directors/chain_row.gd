extends RefCounted
## **Combinator 7 — chain** (`docs/PUZZLES.md` §3.1, priced in §8.1), rendered and
## asserted. A row of cracked pillars with a hole in the middle.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_burst_test.tscn \
##     --director=res://tools/directors/chain_row.gd \
##     --out=/tmp/chain/x.png --warmup=60
##
## Prints `CHAIN FAIL …` on any beat that did not happen.
##
## The room is one sentence: five pillars in a line in front of a T2 gate, three
## of them close together, then an empty socket in the floor, then two more. The
## player has two charges and five pillars to bring down.
##
##   A  The row builds and the numbers are a puzzle rather than a decoration:
##      one blast is worth one pillar, a fall carries to a neighbour, and it does
##      NOT carry across the gap. Two segments, two casts. Photographed cold --
##      the socket in the floor is the only thing telling the player where the
##      answer is, so it has to be visible in the frame before anything happens.
##   B  **Line of sight, in the frame.** Two links 2.5 m apart with a wall
##      between them: the near one goes over and the far one stands. Without this
##      beat the radius is a sphere and "along a line of sight" is a comment.
##   C  One cast at the head of the row. The fall WALKS -- link by link, on
##      separate frames, photographed while it is half done -- and then it stops
##      dead at the gap with two pillars still standing. This is the beat the
##      whole combinator is for.
##   D  Where do I stand. A second cast, placed in the socket, takes the far
##      segment and the gate opens. Five pillars, two charges, none left.
##   E  A ring of four links, each in reach of the next, comes all the way round
##      to its own starting link. It finishes, every link falls, and each one
##      passes the fall on exactly once. That is the re-entrancy guard, and the
##      only way to see it is to build the shape that would hang without it.
##
## ## Why the blast is cast at the target rather than lobbed from the bow hand
##
## `tools/directors/burst_cast.gd` already owns the arc, the fuse, the ring and
## the charge spend, end to end, and it drives the real hero to do it. The
## subject HERE is what happens after a pillar cracks, so the mote is dropped on
## its target through `BurstCast.cast_from()` — the same call `HeroRanged` makes,
## the same blast, the same walk of group `burstable` — and the charge is spent
## through `Game.spend_ammo`, which is the same line one frame earlier. What that
## skips is a crosshair the director would have to steer onto a 0.42 m shaft at
## nine metres, twice, before the beat that can actually fail gets to run.

## Where the floor is in the proving ground. `burst_cast.gd` and `puzzle_atoms.gd`
## both use this number.
const CHAMBER_Y := 0.02
## The row's line, and where its middle sits. **Every address in this file is
## picked around the proving ground's own furniture**, which is not decoration
## once a line of sight is the mechanic: `PillarNW` at (-7, -5.5), `PillarSW` at
## (-7, 5.5) and the two step blocks are real `L_WORLD` bodies, and the first cut
## of beat E put a ring corner-to-corner straight through `PillarNW` and read the
## resulting broken chain as a bug in `chain_links()`. It was the mechanic
## working. Anything moved here has to be re-checked against `proving_ground.tscn`.
const ROW_X := -1.0
const ROW_Z := -1.0
## How high above a target the mote is dropped from. Above head height so the
## fall is visible in the frame, low enough that it lands where it was aimed.
const DROP_Y := 2.6

## Beat B's wall, and the two links it stands between. The west strip, clear of
## `PillarNW` and of the row.
const LOS_A := Vector3(-8.4, CHAMBER_Y, -1.0)
const LOS_B := Vector3(-8.4, CHAMBER_Y, -3.5)

## Beat E's ring. Four links on a square, each side inside the reach and each
## diagonal outside it, so the wave has to travel round rather than across. On
## the open floor south-east of the row, where nothing of the room's own stands
## on any of the four edges.
const RING_AT := Vector3(1.4, CHAMBER_Y, 6.6)
const RING_HALF := 1.2

## The lens the row is photographed from: high on the east side, looking down and
## across. **Not down the row** -- five pillars in a line seen end-on are one
## pillar (`convert_arrow.gd` records the same mistake with a lantern) -- and not
## at ledge height either, which is where the first cut put it and came back with
## the bottom half of the frame filled by the ledge itself.
## It also has to stay under the chamber's ceiling slab at y = 7.
const ROW_CAM := Vector3(6.8, 5.4, 7.0)

var out := ""
var _fails := 0
var _hero: Node3D
var _gate: Node
var _row: ChainRow
var _cam: Camera3D
## Link index -> the millisecond it went over. Beat C's real claim is that these
## are DIFFERENT, which is the difference between a chain and one big prop.
var _fell_at: Dictionary = {}


func run(rig) -> void:
	out = rig.arg("out", "/tmp/chain/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# A run, so the atom flags start clean. A director inheriting a previous
	# session's flags would find its row already down.
	Run.enter(70414)
	Game.grant(&"burst")

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	_gate = rig.scene().get_node_or_null(^"Gate")
	if _hero == null or _gate == null:
		print("CHAIN FAIL the fixture is missing the hero or the gate")
		return

	await _a_the_row(rig)
	await _b_line_of_sight(rig)
	await _c_the_fall_walks(rig)
	await _d_where_do_i_stand(rig)
	await _e_the_ring(rig)

	if _fails == 0:
		print("CHAIN OK the fall walks the row, dies in the gap, and the ring does not")
	else:
		print("CHAIN FAIL %d checks failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("CHAIN FAIL %s" % label)


# --- A. The row -----------------------------------------------------------------

func _a_the_row(rig) -> void:
	# Out of the blast, out of shot, and out of the way of a row he is not walking
	# yet. `K.BOMB_HURTS_OWNER` is true and there is no owner check anywhere
	# (`docs/CONTRACT.md` §7), so a hero left standing on the row would be taking
	# two blasts across this director.
	_hero.global_position = Vector3(1.6, CHAMBER_Y + 0.05, 8.4)
	_hero.set(&"velocity", Vector3.ZERO)
	_hero.set(&"facing_yaw", PI)

	_row = ChainRow.new()
	_row.name = "PillarRow"
	# The fixture gate's own tag, so the DOOR adopts five pillars and counts them.
	# A row that gated through a wrapper would be a second way for a door to be
	# satisfied (`ChainRow`'s class note), and this is the line that proves there
	# is only the one.
	_row.puzzle_id = &"burstgate"
	_row.position = Vector3(ROW_X, CHAMBER_Y, ROW_Z)
	rig.scene().add_child(_row)

	_cam = Camera3D.new()
	_cam.name = "ChainCam"
	_cam.fov = 62.0
	rig.scene().add_child(_cam)
	_look_down_the_row()
	_cam.make_current()

	# `PuzzleAtom._offer` is DEFERRED, so adoption has not happened on the frame
	# the row was added.
	await rig.wait_physics_frames(10)

	_ck("the row built five links", _row.links().size() == 5)
	var problems := _row.problems()
	_ck("the four numbers are a puzzle rather than a decoration (%s)"
		% ", ".join(problems), problems.is_empty())
	# The three inequalities of the class note, said out loud in metres, because
	# "problems() is empty" is a green light with nothing behind it in the log.
	var d01 := _row.link(0).global_position.distance_to(_row.link(1).global_position)
	var d23 := _row.link(2).global_position.distance_to(_row.link(3).global_position)
	print("  ..   neighbour %.2f m, gap %.2f m, reach %.2f m, blast %.2f m"
		% [d01, d23, _row.link(0).chain_radius, K.BOMB_RADIUS])
	_ck("a link reaches its neighbour (%.2f m <= %.2f m)"
		% [d01, _row.link(0).chain_radius], d01 <= _row.link(0).chain_radius)
	_ck("and does NOT reach across the gap (%.2f m > %.2f m)"
		% [d23, _row.link(0).chain_radius], d23 > _row.link(0).chain_radius)
	_ck("one blast is worth one pillar (%.2f m apart, radius %.2f m)"
		% [d01, K.BOMB_RADIUS], d01 > K.BOMB_RADIUS)

	# The topology, asserted WITHOUT toppling anything -- which is the whole
	# reason `chain_links()` is separate from `propagate()`.
	var seg: Array = _row.segments()
	_ck("two segments, so the row costs two casts (%s)" % [seg],
		_row.casts_needed() == 2 and seg.size() == 2)
	_ck("link 0 can see link 1 and only link 1 (%d)"
		% _row.link(0).chain_links().size(), _row.link(0).chain_links().size() == 1)
	# Link 2 is the near lip of the gap. It sees backwards and nothing forwards,
	# which is the gap stated from inside the mechanic rather than in metres.
	var lip: Array = _row.link(2).chain_links()
	_ck("link 2 sees back across the row and nothing over the gap (%d)" % lip.size(),
		lip.size() == 1 and lip[0] == _row.link(1))

	var line: String = _gate.call(&"refusal_line")
	_ck("the gate adopted all five and counts them: \"%s\"" % line,
		line.contains("5") and line.contains("PILLAR"))
	_ck("and it is shut", not bool(_gate.call(&"is_open")))

	Game.add_charges(2)
	_ck("two charges for five pillars (%d/%d)" % [Game.charges, Game.max_charges],
		Game.charges == 2)
	await rig.wait_frames(12)
	await rig.capture(out.path_join("01_row_cold.png"))


# --- B. Line of sight -----------------------------------------------------------

## **The beat that makes the radius a sight line.** Two links 2.5 m apart -- well
## inside the reach -- with a wall between them. The near one goes over; the far
## one stands there.
##
## Built off to the side rather than inside the row, because the row's own job is
## the gap and a wall dropped into it would be two puzzles in one picture.
func _b_line_of_sight(rig) -> void:
	var wall := _build_wall((LOS_A + LOS_B) * 0.5 + Vector3.UP * 1.1)
	var near := _loose_link(rig, &"los", LOS_A, 0)
	var far := _loose_link(rig, &"los", LOS_B, 1)
	await rig.wait_physics_frames(6)

	var d := near.global_position.distance_to(far.global_position)
	_ck("the two links are inside the reach (%.2f m <= %.2f m)"
		% [d, near.chain_radius], d <= near.chain_radius)
	_ck("but the near one cannot SEE the far one through the wall",
		near.chain_links().is_empty())

	# The lens, three-quarters on. **Not square on to the pair**, which is where
	# the first cut put it: the sight line runs between the two links, so a camera
	# on that line looks at the 0.35 m EDGE of the wall and photographs a fence
	# post. Off to one side both links separate and the wall shows its face.
	_cam.global_position = Vector3(-4.2, 3.4, 1.4)
	_cam.look_at((LOS_A + LOS_B) * 0.5 + Vector3.UP * 1.0, Vector3.UP)
	near.solve()
	await rig.wait_seconds(1.4)
	_ck("the near link went over", bool(near.is_solved()))
	_ck("and the far one is still standing -- the chain does not go through walls",
		not bool(far.is_solved()))
	await rig.capture(out.path_join("02_line_of_sight.png"))
	wall.queue_free()
	near.queue_free()
	far.queue_free()
	await rig.wait_physics_frames(4)


# --- C. The fall walks, and then it stops ---------------------------------------

func _c_the_fall_walks(rig) -> void:
	_look_down_the_row()
	for i in _row.links().size():
		var idx := i
		_row.link(i).solved.connect(func(_a): _fell_at[idx] = Time.get_ticks_msec())

	var spent := Game.spend_ammo(&"charges")
	_ck("the first cast spends a charge (%d left)" % Game.charges, spent)
	# **Beside the pillar, not on it.** 1.1 m east of link 0's foot is inside the
	# blast (1.94 m) and 2.82 m from link 1, which is outside it -- so the cast is
	# worth exactly one pillar and everything that follows is the chain rather
	# than the sphere query reaching further than it should.
	var mote := _cast_at(rig, _row.link(0).global_position + Vector3(1.1, 0.0, 0.0))
	await _await_blast(rig, mote)

	# Photographed WHILE it is travelling. One `chain_delay` after the head goes,
	# link 1 is down and links 2..4 are up, and that half-toppled row is the only
	# frame that shows this is a chain rather than five pillars solved at once.
	await rig.wait_seconds(_row.link(0).chain_delay * 1.35)
	await rig.capture(out.path_join("03_fall_travelling.png"))

	# Long enough for the whole first segment and then some. If the gap leaked,
	# links 3 and 4 have had two delays' worth of time to go over.
	await rig.wait_seconds(2.4)
	_ck("link 0 is down -- the cast cracked it", bool(_row.link(0).is_solved()))
	_ck("link 1 followed it (nothing touched it but link 0)",
		bool(_row.link(1).is_solved()))
	_ck("and link 2, at the near lip of the gap", bool(_row.link(2).is_solved()))
	# **The gap.** Every check above would pass on a row with no hole in it.
	_ck("link 3, across the gap, is STANDING", not bool(_row.link(3).is_solved()))
	_ck("and so is link 4 behind it", not bool(_row.link(4).is_solved()))
	_ck("the gate is still shut with two pillars up",
		not bool(_gate.call(&"is_open")))

	# The fall TRAVELLED. Three links that solved in the same millisecond are one
	# prop with three meshes, whatever the frame looks like.
	var t0: int = _fell_at.get(0, 0)
	var t1: int = _fell_at.get(1, 0)
	var t2: int = _fell_at.get(2, 0)
	print("  ..   link 0 at %d ms, link 1 at +%d ms, link 2 at +%d ms"
		% [t0, t1 - t0, t2 - t1])
	_ck("the fall walked rather than happening at once (+%d ms, +%d ms)"
		% [t1 - t0, t2 - t1], t1 - t0 >= 200 and t2 - t1 >= 200)
	await rig.capture(out.path_join("04_stopped_at_the_gap.png"))


# --- D. Where do I stand --------------------------------------------------------

## The second cast, in the socket. The row's own `gap_position()` is the address
## -- which is the point: the answer to the puzzle is a square of floor, and the
## thing that tells the player where it is, is the empty base standing in it.
func _d_where_do_i_stand(rig) -> void:
	var gap := _row.gap_position()
	var to_far := gap.distance_to(_row.link(3).global_position)
	var to_near := gap.distance_to(_row.link(2).global_position)
	# **The socket is a socket.** A hole the fall cannot cross but a blast can is
	# the whole shape of the puzzle: the player's own cast is the missing link,
	# and it goes exactly where the missing pillar would have stood.
	_ck("a cast in the socket reaches BOTH lips (%.2f m and %.2f m, blast %.2f m)"
		% [to_near, to_far, K.BOMB_RADIUS],
		to_far <= K.BOMB_RADIUS and to_near <= K.BOMB_RADIUS)
	# And it is not just a wide blast: the pillar behind the far lip is out of it,
	# so link 4 can only be reached by the chain.
	var to_last := gap.distance_to(_row.link(4).global_position)
	_ck("and does not reach past it (%.2f m to link 4)" % to_last,
		to_last > K.BOMB_RADIUS)

	# He walks onto it, on his own feet. It is the frame the card is named for,
	# and a hero teleported onto the mark would be a picture of a mark rather than
	# of somebody standing on it.
	#
	# The camera is set FIRST and he is started on its own sight line, because
	# `hero.gd` steers off `get_viewport().get_camera_3d()` -- so "forward" means
	# whatever this lens is pointing at, and a director that placed the lens after
	# the walk would be pressing an arrow key at a camera it had not aimed yet.
	_cam.global_position = Vector3(2.6, 3.4, 4.2)
	_cam.look_at(gap + Vector3.UP * 0.9, Vector3.UP)
	var back := (_cam.global_position - gap)
	back.y = 0.0
	_hero.global_position = gap + back.normalized() * 3.5 + Vector3.UP * 0.05
	_hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_physics_frames(6)
	# Walked in in short steps rather than for a fixed time. A single hold tuned
	# against one run's walk speed is a director that overshoots the mark the day
	# somebody retunes `K.HERO_RUN`.
	for i in 24:
		if _hero.global_position.distance_to(gap) < 0.9:
			break
		await rig.hold_seconds(["move_up"], 0.12)
	await rig.wait_physics_frames(6)
	var stood := _hero.global_position.distance_to(gap)
	_ck("he walked to the socket and is standing in the hole (%.2f m off it)"
		% stood, stood < 1.6)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("05_standing_in_the_gap.png"))

	var spent := Game.spend_ammo(&"charges")
	_ck("the second cast spends the last charge (%d left)" % Game.charges,
		spent and Game.charges == 0)
	var mote := _cast_at(rig, gap)
	# Off the mark before it goes off. `K.BOMB_HURTS_OWNER` is true and there is no
	# owner check anywhere (`docs/CONTRACT.md` §7) -- you do not stand over your own
	# lit fuse, and the fuse runs from the CAST, so the walking-away is inside it.
	await rig.hold_seconds(["move_right"], 1.1)
	await _await_blast(rig, mote)
	await rig.wait_seconds(2.0)

	_ck("the link across the gap went over", bool(_row.link(3).is_solved()))
	_ck("and the chain took the last one with it", bool(_row.link(4).is_solved()))
	_ck("five pillars, no links left standing", _row.standing() == 0)
	_ck("two casts, and no charges left over (%d)" % Game.charges,
		Game.charges == 0)
	await rig.wait_seconds(1.0)
	_ck("the last link opened the gate by itself", bool(_gate.call(&"is_open")))
	_look_down_the_row()
	await rig.wait_frames(12)
	await rig.capture(out.path_join("06_row_down_gate_open.png"))


# --- E. The ring ----------------------------------------------------------------

## **The re-entrancy guard, which only a ring can show.** Four links on a square,
## each side inside the reach and each diagonal outside it: the wave leaves link
## 0, goes round both ways, and arrives back at link 0, which has been solved
## since the first frame. Without the guard that is either a run that never ends
## or, at `chain_delay = 0`, a stack that does.
##
## The check that matters is not "they all fell" -- it is that each link passed
## the fall on exactly once and the run came back at all.
func _e_the_ring(rig) -> void:
	var ring: Array[PuzzleAtom] = []
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		ring.append(_loose_link(rig, &"ring",
			RING_AT + Vector3(cos(a), 0.0, sin(a)) * RING_HALF * sqrt(2.0), i))
	await rig.wait_physics_frames(6)

	var side := ring[0].global_position.distance_to(ring[1].global_position)
	var diag := ring[0].global_position.distance_to(ring[2].global_position)
	print("  ..   ring side %.2f m, diagonal %.2f m, reach %.2f m"
		% [side, diag, ring[0].chain_radius])
	_ck("each side is inside the reach and each diagonal is outside it",
		side <= ring[0].chain_radius and diag > ring[0].chain_radius)
	_ck("so link 0 sees its two neighbours and not the far corner (%d)"
		% ring[0].chain_links().size(), ring[0].chain_links().size() == 2)

	# **Inside the room.** The first cut put this lens 4.4 m south of a ring that
	# is already 6.6 m south of the middle, which is 1 m the far side of the south
	# wall -- and the PNG came back solid black with every assertion passing. That
	# is the failure `CLAUDE.md` §2 is about: a director that prints OK without a
	# frame somebody looked at is not proof.
	_cam.global_position = RING_AT + Vector3(4.6, 4.0, -3.0)
	_cam.look_at(RING_AT + Vector3.UP * 0.9, Vector3.UP)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("07_ring_standing.png"))

	ring[0].solve()
	# Caught mid-wave, which is the frame that says it went ROUND: the far corner
	# is the LAST to go, and it can only have been reached through one of the two
	# beside it. A ring photographed only when it was over would look exactly like
	# four pillars solved at once.
	await rig.wait_seconds(ring[0].chain_delay * 1.4)
	await rig.capture(out.path_join("08_ring_travelling.png"))
	# Two delays is enough for a four-link ring to come all the way round. If the
	# guard were missing this is where the run would stop returning.
	await rig.wait_seconds(2.2)
	var down := 0
	for a in ring:
		if a.is_solved():
			down += 1
	# Reaching this line at all is half the beat: without the guard the ring never
	# stops passing the fall round and the director never gets here.
	_ck("the wave went round the ring and came back -- every link is down (%d/4)"
		% down, down == 4)
	# Each link chained once and only once. `_chained` latches when the pass-along
	# is SCHEDULED, so a ring that re-fired would show it having been re-armed.
	var armed := 0
	for a in ring:
		if bool(a.get(&"_chained")):
			armed += 1
	_ck("each of the four passed the fall on exactly once (%d)" % armed, armed == 4)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("09_ring_round.png"))


# --- The fixture ----------------------------------------------------------------

## One cast, landing on the floor point `at`. Dropped from above rather than
## lobbed -- see the class note; the arc is `burst_cast.gd`'s subject, not this
## one's. Returns immediately, with the fuse burning: `K.BOMB_FUSE` runs from the
## CAST and not from the landing, and the 3.5 s in between is where the hero gets
## clear of his own blast.
func _cast_at(rig, at: Vector3) -> BurstCast:
	var mote := BurstCast.cast_from(rig.scene(), at + Vector3.UP * DROP_Y,
		Vector3.DOWN, _hero as CollisionObject3D)
	_ck("the cast produced a mote", mote != null)
	return mote


## Wait the fuse out. Sampled rather than slept, so a fuse that is retuned later
## does not silently turn every beat below it into a check on a pillar that has
## not been blasted yet.
func _await_blast(rig, mote: BurstCast) -> void:
	if mote == null:
		return
	for i in 500:
		await rig.wait_frames(1)
		if not is_instance_valid(mote):
			break
		if bool(mote.get(&"_spent")):
			break
	await rig.wait_frames(3)


## One chain link standing on its own, off the row. `tag` keeps beat B's pair and
## beat E's ring in separate chains -- two loose links sharing the empty default
## `chain_id` would be one chain with a wall in it.
func _loose_link(rig, tag: StringName, at: Vector3, idx: int) -> PuzzleAtom:
	var link := PuzzleAtoms.make(PuzzleAtoms.CRACKED_PILLAR, &"") as PuzzleAtom
	if link == null:
		_ck("a loose link builds", false)
		return null
	# Before the tree: the pillar reads `global_position` while it builds.
	link.position = at
	link.index = idx
	link.chain_radius = ChainRow.REACH
	link.chain_id = tag
	link.name = "Loose_%s_%d" % [tag, idx]
	rig.scene().add_child(link)
	return link


## The row's own lens, restored between beats that borrow it.
func _look_down_the_row() -> void:
	_cam.global_position = ROW_CAM
	_cam.look_at(Vector3(ROW_X, 0.9, ROW_Z - 0.5), Vector3.UP)


## A plain slab on `K.L_WORLD`, with a mesh so the frame shows what blocked the
## sight line. A director that asserted an invisible occluder would be asserting
## about a number.
func _build_wall(at: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "SightWall"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	body.position = at
	var size := Vector3(2.2, 2.2, 0.35)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.26, 0.25, 0.27)
	m.roughness = 0.96
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	body.add_child(mi)
	_hero.get_parent().add_child(body)
	return body
