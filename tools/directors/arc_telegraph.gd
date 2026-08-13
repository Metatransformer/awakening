extends RefCounted
## Board card 21: **the arc telegraph is the cone it delivers**, and the proof is
## a hero standing either side of the line he was drawn.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_boss_test.tscn \
##     --director=res://tools/directors/arc_telegraph.gd \
##     --out=/tmp/arc/x.png --warmup=60
##
## `Boss._shape_arc` has always resolved a CONE -- `signed_angle_to` against the
## row's `arc_deg` as a half-angle -- and the mark drew a RECTANGLE, the smallest
## box that cone fits inside. The damage was never wrong; the picture was, and it
## was wrong in a way no check in this repo could see, because every probe that
## existed stood dead in front of the boss where a box and a cone agree.
##
## What it claims, in the order it proves them:
##
##   A  How many `arc` beats there are, what each one delivers, and -- printed
##      side by side -- the box the old line drew for it. Six beats across five
##      bodies, from a 44 degree needle to a 190 degree sweep.
##   B  The widest: the Slag Ogre's `slag_backhand`, 95 degrees over 4.2 m. The
##      wind-up photographed at the frame a player reads it, the mark MEASURED off
##      its own vertices, and then the two probes.
##   C  The narrowest: the Gate-Hound's `gate_shard`, 22 degrees over 9.0 m. The
##      same three things. Both ends of the range, because a 22 degree cone inside
##      a box is a different lie from a 190 degree one -- the needle was drawn as
##      a wall.
##
## **The probe is the card.** For each of the two, the hero is stood at a bearing
## measured off the DRAWN edge -- six degrees inside it, then six degrees outside
## -- and the health is read. Inside must take the row's damage; outside must take
## nothing. The bearing is not assumed: it is recorded on `beat_committed`, off
## the boss's own basis and the hero's own position on the frame the blow
## resolved, and compared with the drawn edge using the same `signed_angle_to`
## expression `_shape_arc` tests with. Same shape of assertion as
## `boss_cistern.gd` beat F, which stands the hero inside `cistern_drop`'s
## `safe_inner` and asserts a zero.
##
## The boss is re-parked EVERY frame through the tell. It tracks the player at
## `TELL_TRACK_DEG` (70 deg/s) for the whole wind-up, and a probe six degrees
## outside the mark would otherwise be eaten by the turn rather than by the shape
## -- the beat would land and the director would report a telegraph defect that
## was really a steering one. Tracking only ever pulls the bearing DOWN, so the
## bound this leaves is one rendered frame of turn (~3 degrees at this harness's
## 22 fps) in the direction that makes the outside probe safer to call.
##
## `Boss`, `BossArena` and the rest are reached through node handles and
## `load(path).new()`, never named: a `class_name` is not in the global class
## cache until the project is re-imported, and naming one mid-edit is a parse
## error that takes the run down before its first frame (the lesson at the bottom
## of `tools/directors/gate_locks.gd`).

## How far through a tell the shutter opens. The same figure `boss_cistern.gd`
## and `minibosses.gd` use, so the three sets of tell frames are comparable.
const TELL_SHOT_AT := 0.70

## Metres between the two bodies for the photographs.
const WATCH_DIST := 7.0

## Degrees either side of the DRAWN edge the two probes stand. Big enough to
## survive one frame of the boss's tracking, small enough that "just outside" is
## still an honest description of where the hero was standing.
const PROBE_MARGIN := 6.0

## How far out the probes stand, as a fraction of the beat's reach. Well inside
## the radius, so the only thing deciding the outcome is the ANGLE.
const PROBE_REACH := 0.55

var out := ""
var _fails := 0
## Filled by `beat_committed` with the geometry the blow actually resolved
## against: the boss's forward, its position, and the hero's, on that frame.
var _geo: Dictionary = {}
## The hero's health the frame before the beat under test began. A MEMBER and not
## a local, because GDScript lambdas capture locals BY VALUE -- the probe loop
## writes this from inside a `Callable` and a captured `var before` would be
## re-read outside the closure with the value it had when the closure was made.
var _before: int = 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/arc/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.level = 1

	# The fixture's own arena is the Cistern Warden's, and it takes its boss with
	# it when it goes -- the body is built as a child of the arena. Freeing it is
	# what stops a second boss wandering through a measurement.
	var fixture: Node = rig.scene().get_node_or_null(^"Arena")
	if fixture != null:
		fixture.queue_free()
	await rig.wait_frames(10)

	if _hero(rig) == null:
		print("ARC FAIL there is no hero in the scene")
		return

	_table()
	await _fight(rig, 1, &"slag_ogre", &"slag_backhand")
	await _fight(rig, 2, &"gate_hound", &"gate_shard")

	if _fails == 0:
		print("ARC OK -- every check passed")
	else:
		print("ARC FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("ARC ok %s" % label)
	else:
		_fails += 1
		print("ARC FAIL %s" % label)


# --- A. Every arc in the game -------------------------------------------------

## Counted rather than assumed. Two of the six landed with the minibosses on
## 2026-08-10, after the card was written, and a fix aimed only at the beat the
## card names would have left a 22 degree needle drawn as a 6.7 m wall.
func _table() -> void:
	var problems := BossDb.validate()
	_ck("A0 BossDb.validate() is clean", problems.is_empty())
	for p in problems:
		print("ARC   the table says: %s" % p)

	var n := 0
	var owners: Dictionary = {}
	for group in [BossDb.all(), BossDb.all_minibosses()]:
		for id in group:
			for b in BossDb.beats(id):
				if b["shape"] != BossDb.SHAPE_ARC:
					continue
				n += 1
				owners[id] = true
				var reach := float(b["reach"])
				var half := deg_to_rad(float(b["arc_deg"]))
				# What the old line drew: `reach * 2 * sin(min(half, PI*0.49))`
				# across, `reach` deep. Printed because the size of the lie is the
				# argument -- at 95 degrees the `sin` clamps and the box stops
				# being even a bounding box of the right cone.
				var box := reach * 2.0 * sin(minf(half, PI * 0.49))
				print("ARC   %-14s %-14s %5.1f deg (%5.1f swept) to %.1f m -- the box was %.1f x %.1f m"
					% [id, b["id"], float(b["arc_deg"]), float(b["arc_deg"]) * 2.0,
						reach, box, reach])
	print("ARC %d arc beats, across %d bodies: %s" % [n, owners.size(), owners.keys()])
	_ck("A1 there are six arc beats in the game (%d)" % n, n == 6)


# --- B and C. One fight, one arc ----------------------------------------------

func _fight(rig, n: int, boss_id: StringName, beat_id: StringName) -> void:
	var b := BossDb.beat(boss_id, beat_id)
	if b.is_empty():
		_ck("%d.0 %s has a beat called %s" % [n, boss_id, beat_id], false)
		return
	print("ARC --- %d. %s / %s: %.1f deg to %.2f m, %d HP ---"
		% [n, boss_id, beat_id, float(b["arc_deg"]), float(b["reach"]),
			int(b["damage"])])

	# Out in the corridor first: an arena builds its trigger in `_ready`, and a
	# hero left standing in the middle of the room seals it on the frame it is
	# built.
	await _stand_at(rig, Vector3(0.0, 0.05, 18.0), Vector3.ZERO)
	var arena := _build_arena(rig, boss_id)
	await rig.wait_frames(30)
	var boss: Node = arena.call(&"boss")
	_ck("%d.1 the arena stood %s up" % [n, boss_id], boss != null)
	if boss == null:
		arena.queue_free()
		await rig.wait_frames(6)
		return
	# The geometry the blow resolved against, banked on the frame it resolved.
	# `beat_committed` is emitted at the end of `_commit()`, after the shape has
	# already been delivered and before any physics has moved either body, so
	# this is the arrangement the damage saw and not one a frame either side.
	boss.beat_committed.connect(func(cid: StringName) -> void:
		var hero := _hero(rig)
		if hero == null:
			return
		_geo = {
			"beat": cid,
			"fwd": K.flat(-(boss as Node3D).global_transform.basis.z),
			"boss": (boss as Node3D).global_position,
			"hero": hero.global_position,
		})

	# Walked in, so the room seals the way `Dungeon` relies on it sealing.
	await _mark_up(rig, arena, boss)
	_ck("%d.2 walking into the ring woke it" % n, boss.is_awake())

	var drawn := await _tell(rig, arena, boss, n, b)
	# The probes run off the DRAWN edge when there is one. If the mark is not a
	# cone at all the card is already failed above; falling back to the row keeps
	# the damage half of the run meaningful instead of skipping it.
	var edge := drawn.x if drawn.x > 0.0 else float(b["arc_deg"])
	await _probe(rig, arena, boss, n, b, edge, -PROBE_MARGIN, true)
	await _probe(rig, arena, boss, n, b, edge, PROBE_MARGIN, false)

	arena.queue_free()
	await rig.wait_frames(10)


## The wind-up, photographed at the frame a player reads it, and the mark it drew
## measured off its own vertices.
##
## Returns the drawn (half-angle in degrees, radius in metres), or `(-1, -1)` if
## what is on the floor is not a sector at all.
func _tell(rig, arena: Node3D, boss: Node, n: int, b: Dictionary) -> Vector2:
	var bid: StringName = b["id"]
	var tell: Dictionary = b["tell"]
	var total := maxf(float(tell["time"]), 0.001)
	Game.heal(999)
	boss.force_beat(bid)
	await _mark_up(rig, arena, boss)
	var arrived := await _until(rig, func() -> bool:
		return boss.current_beat() == bid and boss.state == Enemy.State.WINDUP, 600)
	if not arrived:
		_ck("%d.3 the boss threw %s" % [n, bid], false)
		return Vector2(-1.0, -1.0)
	_park_boss(arena, boss)
	# MEASURED off the fight's own countdown. This harness renders at about 22 fps
	# and a frame count here would be a measurement of the machine.
	await _until(rig, func() -> bool:
		return boss.state != Enemy.State.WINDUP \
			or boss._timer <= total * (1.0 - TELL_SHOT_AT), 240)
	var through := 1.0 - clampf(float(boss._timer) / total, 0.0, 1.0)
	# The HANDLE, not a lookup by name: `_clear_marker` queue_frees the last mark
	# and a freed-but-not-yet-removed sibling makes Godot rename the replacement,
	# so `get_node("Fan")` finds the corpse or nothing.
	var mark: Node3D = boss._marker
	var report := _mark_report(mark)
	print("ARC   %s mark: %s, %.0f%% through the tell" % [bid, report["says"], through * 100.0])
	_ck("%d.3 the %s tell is on screen and still winding up" % [n, bid],
		boss.state == Enemy.State.WINDUP and through > 0.45)
	# THE CARD, in one line. A box passes "there is a mark on the floor" and fails
	# this.
	_ck("%d.4 and what it drew is a cone (%s)" % [n, report["kind"]],
		report["kind"] == "fan")
	var drawn := Vector2(float(report["half_deg"]), float(report["reach"]))
	if report["kind"] == "fan":
		print("ARC   %s cone drawn %.1f deg to %.2f m, damage %.1f deg to %.2f m"
			% [bid, drawn.x, drawn.y, float(b["arc_deg"]), float(b["reach"])])
		_ck("%d.5 drawn at the half-angle the damage tests (%.1f vs %.1f deg)"
			% [n, drawn.x, float(b["arc_deg"])],
			absf(drawn.x - float(b["arc_deg"])) < 3.0)
		# The mark grows over the tell -- the root is scaled, the vertices are not
		# -- so this is the shape it arrives at, which is the shape the blow uses.
		_ck("%d.6 and out to the reach the damage tests (%.2f vs %.2f m)"
			% [n, drawn.y, float(b["reach"])],
			absf(drawn.y - float(b["reach"])) < 0.15)
	await rig.capture(out.path_join("a%d_1_%s_tell.png" % [n, bid]))
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 600)
	Game.heal(999)
	return drawn


## One probe: the hero stood `off_deg` off the drawn edge, and the health read.
##
## `expect_hit` says which side of the line he is on, and the assertion is the
## card's own sentence -- inside takes the row's damage, outside takes nothing.
func _probe(rig, arena: Node3D, boss: Node, n: int, b: Dictionary,
		edge_deg: float, off_deg: float, expect_hit: bool) -> void:
	var bid: StringName = b["id"]
	var reach := float(b["reach"])
	var want := int(b["damage"]) if expect_hit else 0
	var side := "inside" if expect_hit else "outside"
	var tag := "%d.%s" % [n, "7" if expect_hit else "8"]
	var bearing := deg_to_rad(edge_deg + off_deg)

	_geo = {}
	boss.force_beat(bid)
	_park_boss(arena, boss)
	var body := boss as Node3D
	var park_at: Vector3 = body.global_position
	var dist := reach * PROBE_REACH
	Bus.camera_recenter.emit()

	# One loop, holding the arrangement until the blow resolves, and the hero is
	# placed off the boss's LIVE forward every frame rather than at a fixed point
	# in the room.
	#
	# That is not a flourish, it is the only thing that works. `Enemy` writes
	# `rotation.y = _facing` on every physics tick, so a yaw stamped from a
	# director survives less than one frame -- and the boss tracks the player
	# through the whole wind-up at `TELL_TRACK_DEG` (70 deg/s). The first cut of
	# this probe parked the yaw and stood the hero at a fixed spot 28 degrees
	# outside the mark; by the commit the Gate-Hound had turned the whole 28
	# degrees onto him and the beat landed at a measured 0.0 degrees off its own
	# nose. That is a steering result being reported as a telegraph one.
	#
	# Moving the hero instead makes the turn self-defeating: the boss closes at
	# most `70 * frame` (about 3 degrees at this harness's 22 fps) before the next
	# frame re-opens the bearing, so the angle at the commit is within a few
	# degrees of the one asked for -- inside `PROBE_MARGIN` either way. And it is
	# never assumed: what gets asserted below is the bearing that was MEASURED on
	# the frame the blow resolved.
	_before = Game.health_points
	var ran := await _until(rig, func() -> bool:
		# The commit is checked FIRST and returns before anything else runs. It
		# used to be the last line, under the heal -- and the heal fired on the
		# very frame the blow landed, because by then the state has already left
		# WINDUP. Every probe reported a clean zero and the director called the
		# damage side of the card proven while measuring nothing at all.
		if _geo.has("beat") and StringName(_geo["beat"]) == bid:
			return true
		# Position parked so the pair cannot walk down the room; heading left
		# alone, for the reason above.
		body.global_position = park_at
		var fwd_now := K.flat(-body.global_transform.basis.z)
		var yaw := atan2(fwd_now.x, fwd_now.z)
		var at := park_at + Vector3(sin(yaw + bearing), 0.0,
			cos(yaw + bearing)) * dist
		at.y = 0.05
		_teleport(rig, at, park_at)
		if boss.current_beat() != bid or boss.state != Enemy.State.WINDUP:
			Game.heal(999)
			_before = Game.health_points
		return false, 900)
	if not ran:
		_ck("%s the boss threw %s %s the mark" % [tag, bid, side], false)
		return

	# The same expression `_shape_arc` tests with, read off the same frame's
	# numbers. Not the bearing we asked for: the bearing it got.
	var hero_at: Vector3 = _geo["hero"]
	var boss_at: Vector3 = _geo["boss"]
	var fwd: Vector3 = _geo["fwd"]
	var to := K.plane(hero_at - boss_at)
	var got_deg := rad_to_deg(absf(to.normalized().signed_angle_to(fwd, Vector3.UP)))
	# Past the commit and the hit-stop, so the health has settled.
	await rig.wait_seconds(0.5)
	var took := _before - Game.health_points
	print("ARC   %s at %.1f deg off the drawn %.1f deg edge, %.2f m out: %d -> %d HP (took %d, the row says %d)"
		% [side, got_deg, edge_deg, to.length(), _before, Game.health_points, took,
			int(b["damage"])])
	# Inconclusive rather than passing: if the tracking swung the hero back inside
	# the mark, the probe never asked the question and must not report an answer.
	_ck("%sa the %s probe really is %s the drawn edge (%.1f vs %.1f deg)"
		% [tag, bid, side, got_deg, edge_deg],
		(got_deg < edge_deg) == expect_hit)
	_ck("%s %s %s the drawn edge takes %d HP (took %d)"
		% [tag, bid, side, want, took], took == want)
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 600)
	Game.heal(999)


# --- Helpers ------------------------------------------------------------------

## What is actually on the floor, whatever it is. Reads the mark's own meshes
## rather than the row that asked for it, and names the SHAPE it found -- a
## sector, a box, a disc -- so this director says the same true thing before the
## fix and after it. A check that could only describe the shape it expected is
## how the box survived two directors.
func _mark_report(mark: Node3D) -> Dictionary:
	var none := {"kind": "none", "says": "nothing on the floor",
		"half_deg": -1.0, "reach": -1.0}
	if mark == null:
		return none
	for c in mark.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.mesh as BoxMesh
		if box != null:
			return {"kind": "box", "half_deg": -1.0, "reach": -1.0,
				"says": "a %.1f x %.1f m BOX" % [box.size.x, box.size.z]}
		var cyl := mi.mesh as CylinderMesh
		if cyl != null:
			return {"kind": "disc", "half_deg": -1.0, "reach": cyl.top_radius,
				"says": "a %.1f m disc" % cyl.top_radius}
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		if arrays.is_empty():
			continue
		# `Boss._fan_marker` builds one triangle fan with its apex on the boss, so
		# the widest vertex bearing off `-Z` is the drawn half-angle and the
		# longest is the drawn reach. Unaffected by the grow tween, which scales
		# the marker ROOT and leaves these vertices where they were authored.
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var wide := 0.0
		var far := 0.0
		for v in verts:
			var r := Vector2(v.x, v.z).length()
			if r < 0.001:
				continue
			far = maxf(far, r)
			# `atan2(-x, -z)`, so the fan's own `(-sin a, 0, -cos a)` reads back as
			# `a` -- the bearing off the forward the damage measures from.
			wide = maxf(wide, absf(atan2(-v.x, -v.z)))
		return {"kind": "fan", "half_deg": rad_to_deg(wide), "reach": far,
			"says": "a %.1f deg CONE to %.2f m (%d triangles)"
				% [rad_to_deg(wide), far, verts.size() / 3]}
	return none


## One `BossArena`, built the way `Dungeon._place_chamber` builds one: from the
## script, with the row's id and no door. `relic_slot` is emptied so a fight this
## director never finishes cannot leave a floor's relic lying in the fixture.
func _build_arena(rig, id: StringName) -> Node3D:
	var script := load("res://scripts/world/boss_arena.gd") as GDScript
	var arena := script.new() as Node3D
	arena.name = "ArcArena_%s" % id
	arena.set(&"boss_id", id)
	arena.set(&"relic_slot", &"")
	arena.set(&"boss_offset", Vector3(0.0, 0.0, -WATCH_DIST * 0.5))
	rig.scene().add_child(arena)
	return arena


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return null if players.is_empty() else players[0] as Node3D


## Put the hero somewhere, facing something. Nothing waits on it -- the probe
## loop calls this every frame to hold him on his mark while the boss winds up.
##
## `facing_yaw` as well as `rotation.y`: the hero turns toward his own heading
## every frame, so setting only the node is undone before the next tick
## (`docs/CONTRACT.md` §2.5 -- facing is measured, not derived). The `+ PI` is the
## same contract from the other side.
func _teleport(rig, at: Vector3, look_at: Vector3) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = at
	var to := K.flat(look_at - at)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI


func _stand_at(rig, at: Vector3, look_at: Vector3) -> void:
	_teleport(rig, at, look_at)
	Bus.camera_recenter.emit()
	await rig.wait_frames(14)


## Put the boss back on its half of the mark. `-basis.z` is forward, so a body
## looking down `+Z` -- at the hero's half -- has `rotation.y = PI`. The
## art-space 180 is NOT this rotation and must not be folded into it: that one
## lives on the model node (`CLAUDE.md` §4).
##
## `_facing` as well as `rotation.y`, and this is the half the other two boss
## directors leave out. `Enemy._physics_process` writes `rotation.y = _facing`
## every tick, so the node yaw on its own is undone before the next frame -- it
## looks like it works only because those directors stand the hero exactly where
## the boss was already looking. Facing is measured, not derived
## (`docs/CONTRACT.md` §2.5), and this is the same rule from the writing side.
func _park_boss(arena: Node3D, boss: Node) -> void:
	var body := boss as Node3D
	var at := arena.global_position + Vector3(0.0, 0.0, -WATCH_DIST * 0.5)
	at.y = body.global_position.y
	body.global_position = at
	body.rotation.y = PI
	boss._facing = PI


func _mark_up(rig, arena: Node3D, boss: Node) -> void:
	_park_boss(arena, boss)
	var at := arena.global_position + Vector3(0.0, 0.05, WATCH_DIST * 0.5)
	await _stand_at(rig, at, (boss as Node3D).global_position)


func _until(rig, pred: Callable, frames: int) -> bool:
	for _i in frames:
		if pred.call():
			return true
		await rig.wait_frames(1)
	return false
