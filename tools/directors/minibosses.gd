extends RefCounted
## Board card 23: **all four minibosses, built, telegraphed and killed**
## (`docs/PUZZLES.md` §7). `tools/directors/puzzle_loop.gd` beats G0-G13 prove
## the Sluice-Keeper inside the floor it stands in; nothing proved the other
## three, and for three of the four the reason was that they did not exist.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_boss_test.tscn \
##     --director=res://tools/directors/minibosses.gd \
##     --out=/tmp/mb/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The table is sound and the MANIFEST is checked. `BossDb.validate()`
##      returns nothing and `miniboss_for()` answers for every one of floors 1-4.
##      That last line IS the card: before it, `miniboss_for(2..4)` answered
##      `&""`, `Dungeon._place_chamber` returned on its first line without a
##      word, and three floors' treasure chambers were empty with nothing
##      anywhere saying so. A director that called `validate()` and photographed
##      floor 1 saw nothing at all wrong.
##   B  **No two of the twenty beats in the game are the same picture.** Twelve
##      boss beats and eight miniboss beats, printed as (pose, colour) pairs and
##      counted. `validate()` asserts it; this prints the working, because the
##      claim is about what a player can tell apart and a boolean is a poor way
##      to read that.
##   C  Every telegraph clears GDD §7's 60% floor. Per attack shape, deepest
##      miniboss tell over shallowest, with the arithmetic printed.
##   D  Each of the four builds: the row's rules (exactly two beats, an empty
##      drop, a model that is not that floor's boss's) and then the BODY --
##      fitted to the authored height by measurement, with the art-space 180 on
##      the model node (`CLAUDE.md` §4).
##   E  Both of its tells, photographed at the frame they are readable, with the
##      pose asserted to have moved something and to differ from the fight's
##      other beat, the floor mark asserted to be the picture its shape draws,
##      and the punish window MEASURED off the fight rather than read back out
##      of the table.
##   F  It dies, it drops NOTHING, and its arena comes up spent.
##
## ## Why it builds its own arenas
##
## `_boss_test.tscn` is the Cistern Warden's fixture and carries one `Arena`
## wired to `cistern_warden`. That one is freed on the first beat and four fresh
## arenas are built into the same chamber, one at a time -- which is also part of
## what is under test: `Dungeon._place_chamber` builds a miniboss arena exactly
## this way (`script.new()`, `boss_id`, `relic_slot = &""`, no door), so a row
## that cannot be stood up from a bare script is a row the dungeon cannot place.
##
## Freeing the fixture's ARENA takes its boss with it -- the body is built as a
## child of the arena, which is `BossArena._build_boss`'s whole construction
## contract -- so there is no second Warden wandering through a measurement.
##
## `BossArena` is loaded by PATH and never named, for the reason
## `tools/directors/gate_locks.gd` records at the bottom of its own file: a
## `class_name` is not in the global cache until the project is re-imported, and
## naming one that is mid-edit is a parse error that takes the run down before
## its first frame.

## How far through a tell the shutter opens. Not 1.0: the pose is at its extreme
## just before the commit, and a frame taken ON the commit is a photograph of the
## blow rather than of the warning. Same figure `boss_cistern.gd` uses.
const TELL_SHOT_AT := 0.70

## Metres between the two bodies for every photograph. Close enough that a
## 2.3-2.6 m body and a 1.65 m hero are in one frame at the game camera's own
## focal length, and far enough that the Gate-Hound's 9 m lane and the Second
## Voice's 7.5 m ring are both still drawn on floor the camera can see.
const WATCH_DIST := 7.0

## Where the body stands for its cold portrait, on the arena's own Z. Forward of
## centre, so the hero can be `WATCH_DIST` behind it and still be outside the
## widest of the four seal triggers (9.0 m x 0.82 = 7.4 m; the mark lands at 10).
const PORTRAIT_Z := 3.0

## Degrees off the axis the portrait mark stands at. The chase camera sits behind
## the hero along his own facing, so a hero standing square in front of the body
## puts his shoulders across its legs and every portrait is a head and a chest.
## Twenty degrees is enough to clear him and little enough that the four frames
## are still the same shot. The distance stays exactly `WATCH_DIST`.
const PORTRAIT_YAW := 20.0

## Quarter-hearts a director swing takes. Six blows kills the biggest of the
## four, which keeps the whole run inside one `timeout 400`.
const SWING := 12

var out := ""
var _fails := 0
var _defeated := 0
## "<miniboss>/<beat>" -> the punish window the fight actually held open.
var _punish: Dictionary = {}


func run(rig) -> void:
	out = rig.arg("out", "/tmp/mb/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.level = 1
	Bus.boss_defeated.connect(func() -> void: _defeated += 1)

	var fixture: Node = rig.scene().get_node_or_null(^"Arena")
	if fixture != null:
		fixture.queue_free()
	await rig.wait_frames(10)

	if _hero(rig) == null:
		print("MB FAIL there is no hero in the scene")
		return

	_table()
	_pictures()
	_compression()

	var n := 0
	for id in BossDb.all_minibosses():
		n += 1
		await _one(rig, n, id)

	if _fails == 0:
		print("MB OK -- every check passed")
	else:
		print("MB FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("MB ok %s" % label)
	else:
		_fails += 1
		print("MB FAIL %s" % label)


# --- A. The table and the manifest --------------------------------------------

func _table() -> void:
	var problems := BossDb.validate()
	for p in problems:
		_ck("A0 the table says: %s" % p, false)
	_ck("A0 BossDb.validate() is clean", problems.is_empty())

	var ids := BossDb.all_minibosses()
	print("MB minibosses: %s" % [ids])
	_ck("A1 there are four of them (%d)" % ids.size(), ids.size() == 4)

	for level in range(1, 5):
		var want := BossDb.miniboss_for(level)
		var row := BossDb.get_boss(want)
		print("MB floor %d -> %s \"%s\", beside boss %s"
			% [level, want, row.get("title", "?"), BossDb.for_floor(level)])
		# THE CARD. An empty answer here is not an error anywhere in the game:
		# `Dungeon._place_chamber` reads it, returns, and builds a chamber with
		# nothing in it.
		_ck("A2.%d floor %d has a miniboss" % [level, level], want != &"")


# --- B. Twenty beats, twenty pictures -----------------------------------------

## `validate()` refuses a repeated (pose, colour) pair across the whole game, and
## this is that rule with its working shown. Five poses and six usable tell
## colours is thirty pictures for twenty beats; printing them is the only way to
## see how little room is left before the next beat has to take a colour off
## something that already owns it.
func _pictures() -> void:
	var seen: Dictionary = {}
	var dupes := 0
	var groups: Array = [["boss", BossDb.all()], ["mini", BossDb.all_minibosses()]]
	for pair in groups:
		var which: String = pair[0]
		var ids: Array = pair[1]
		for id in ids:
			for b in BossDb.beats(id):
				var tell: Dictionary = b["tell"]
				var hex := (tell["color"] as Color).to_html(false)
				var key := "%s|%s" % [tell["pose"], hex]
				if seen.has(key):
					dupes += 1
					print("MB   CLASH %s/%s is the same picture as %s"
						% [id, b["id"], seen[key]])
				seen[key] = "%s/%s" % [id, b["id"]]
				print("MB   %-4s %-14s %-14s %-6s #%s"
					% [which, id, b["id"], tell["pose"], hex])
	var total := _beat_count()
	print("MB %d beats, %d distinct (pose, colour) pictures" % [total, seen.size()])
	_ck("B0 every beat in the game is its own picture (%d/%d)"
		% [seen.size(), total], dupes == 0 and seen.size() == total)

	# And no fight repeats a pose inside itself, which is the rule that stops a
	# fight's two beats reading as one attack with two timers.
	for id in BossDb.all_minibosses():
		var poses: Dictionary = {}
		for b in BossDb.beats(id):
			poses[b["tell"]["pose"]] = true
		_ck("B1 %s holds two different poses (%s)" % [id, poses.keys()],
			poses.size() == BossDb.beats(id).size())


func _beat_count() -> int:
	var n := 0
	for id in BossDb.all():
		n += BossDb.beats(id).size()
	for id in BossDb.all_minibosses():
		n += BossDb.beats(id).size()
	return n


# --- C. The 60% floor ---------------------------------------------------------

## GDD §7: *the telegraph never compresses past 60%*. `Prog.windup_scale` does
## not touch an authored fight (`boss_db.gd`'s executor contract §3), so what the
## promise means here is `docs/BOSSES.md` §4's reading of it -- the authored
## compression from the shallowest floor to the deepest, per attack shape,
## checked as a number rather than felt.
func _compression() -> void:
	var by_shape: Dictionary = {}
	for id in BossDb.all_minibosses():
		var deep := int(BossDb.get_boss(id)["floor"])
		for b in BossDb.beats(id):
			var shape: StringName = b["shape"]
			var rows: Array = by_shape.get(shape, [])
			rows.append([deep, float(b["tell"]["time"]), String(b["id"])])
			by_shape[shape] = rows
	for shape: StringName in by_shape:
		var rows: Array = by_shape[shape]
		rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		var lo: Array = rows[0]
		var hi: Array = rows[rows.size() - 1]
		var ratio := float(hi[1]) / maxf(float(lo[1]), 0.001)
		print("MB %-6s floor %d %s %.2f s -> floor %d %s %.2f s = %.1f%%"
			% [shape, int(lo[0]), lo[2], float(lo[1]),
				int(hi[0]), hi[2], float(hi[1]), ratio * 100.0])
		# A shape that appears on one floor only has nothing to compress
		# against, and a shape that gets SLOWER with depth is fine -- which is
		# why this is a floor and not a band (`docs/BOSSES.md` §4 says the same
		# about the bosses' zone row).
		_ck("C0 %s never compresses past 60%% (%.1f%%)" % [shape, ratio * 100.0],
			rows.size() < 2 or ratio >= 0.60)


# --- D, E, F. One miniboss ----------------------------------------------------

func _one(rig, n: int, id: StringName) -> void:
	var row := BossDb.get_boss(id)
	var level := int(row["floor"])
	var boss_id := BossDb.for_floor(level)
	var boss_row := BossDb.get_boss(boss_id)
	var list := BossDb.beats(id)
	var arena_row: Dictionary = row["arena"]
	print("MB --- %d. %s (%s), floor %d ---" % [n, row.get("title", "?"), id, level])
	print("MB   model=%s h=%.2f hp=%d arena_r=%.1f cover=%s"
		% [row["model"], float(row["height"]), int(row["health"]),
			float(arena_row["radius"]), arena_row["cover"]])

	# The row's three rules. Checked here as well as inside `validate()` on
	# purpose: `validate()` is one verdict for the whole table, and a director
	# that only asked it could not say WHICH row was wrong in the line a reader
	# is looking at when a frame looks off.
	_ck("D%d.0 %s has exactly two beats (§7)" % [n, id], list.size() == 2)
	var drop: Dictionary = row.get("drop", {})
	_ck("D%d.1 and drops nothing (item=\"%s\" relic=\"%s\")"
		% [n, drop.get("item", &"?"), drop.get("relic", &"?")],
		StringName(drop.get("item", &"")) == &""
		and StringName(drop.get("relic", &"")) == &"")
	_ck("D%d.2 and is not the same silhouette as floor %d's boss (%s vs %s)"
		% [n, level, row["model"], boss_row.get("model", &"?")],
		row["model"] != boss_row.get("model", &""))
	print("MB   %d q against %s's %d q (%.2fx)"
		% [int(row["health"]), boss_id, int(boss_row.get("health", 0)),
			float(row["health"]) / maxf(float(boss_row.get("health", 1)), 1.0)])

	# Out in the corridor first (the fixture's own start, z = 18, well outside any
	# of the four arena radii). An arena builds its trigger in `_ready`, so a hero
	# left standing where the previous fight ended is a hero already inside the
	# next ring, and the room seals on the frame it is built.
	await _stand_at(rig, Vector3(0.0, 0.05, 18.0), Vector3.ZERO)
	var arena: Node3D = _build_arena(rig, id)
	await rig.wait_frames(30)
	var boss: Node = arena.call(&"boss")
	_ck("D%d.3 the arena stood it up from a bare script" % n, boss != null)
	if boss == null:
		arena.queue_free()
		await rig.wait_frames(6)
		return
	boss.punish_closed.connect(func(bid: StringName, measured: float) -> void:
		_punish["%s/%s" % [id, bid]] = measured)

	_ck("D%d.4 it is asleep until the room seals" % n, not boss.is_awake())
	_ck("D%d.5 with the %d q the row authored (%d)"
		% [n, int(row["health"]), boss.health.max_quarters],
		boss.health.max_quarters == int(row["health"]))
	# Executor contract §1b: the fit is MEASURED, never a magic factor. Proving
	# the NUMBER and not the code path -- the rendered mesh has to actually be
	# that tall or the division did nothing.
	var native: float = Enemy._model_height(boss._model)
	var fitted: float = native * boss._model.scale.y
	print("MB   %s native=%.3f m, fitted=%.3f m (table says %.2f)"
		% [row["model"], native, fitted, boss._height()])
	_ck("D%d.6 fitted to %.2f m by measurement (got %.2f)"
		% [n, float(row["height"]), fitted],
		absf(fitted - float(row["height"])) < 0.05)
	# The rule this project has been bitten by three times (CLAUDE.md §4): the
	# art-space 180 goes on the MODEL node and never into the steering.
	_ck("D%d.7 the art-space 180 is on the model node" % n,
		absf(wrapf(boss._model.rotation.y - PI, -PI, PI)) < 0.01)

	# The roster frame: all four at the same distance and the same angle, so the
	# four PNGs are a contact sheet and "you can tell them apart at a glance" is
	# something a reader can check rather than take.
	#
	# Taken COLD -- asleep, unsealed, the room's own torchlight on it. The first
	# cut photographed it after the seal and every portrait came out as a
	# saturated single-colour blob: within a second of waking the boss has begun
	# its first beat, and `_flash.glow` floods the whole body with that beat's
	# tell colour and drops a mark on the floor. Four silhouettes were four
	# lozenges of light. A tell is a fine thing to photograph -- E below does it
	# twice per fight -- but it is the opposite of a silhouette.
	await _portrait(rig, arena, boss)
	await rig.capture(out.path_join("m%d_0_%s.png" % [n, id]))

	# WALKED IN, not `seal()`-ed from the director. The first cut called
	# `arena.seal()` directly and asserted D.4 above with the hero still standing
	# where the LAST fight left him -- which is inside the next arena's trigger,
	# so the room sealed on the frame it was built and "asleep until the room
	# seals" failed on three of the four. The failure was right and the director
	# was wrong: the hero waits in the corridor while the arena is built, and the
	# seal here is the one `Dungeon` actually relies on -- a body entering a ring.
	await _mark_up(rig, arena, boss)
	_ck("D%d.8 walking into the ring seals it and wakes it" % n,
		bool(arena.call(&"is_sealed")) and boss.is_awake())

	var i := 0
	var shapes: Dictionary = {}
	for b in list:
		i += 1
		await _tell(rig, arena, boss, id, b, "E%d.%d" % [n, i],
			out.path_join("m%d_%d_%s_%s.png" % [n, i, id, b["id"]]), shapes)

	await _kill(rig, arena, boss, id, n, int(row["health"]))


## One `BossArena`, built the way `Dungeon._place_chamber` builds one: from the
## script, with the row's id, `relic_slot = &""` and no door. The chamber's
## middle is the world origin in this fixture (walls at +/-13), which is where
## the arena's own tscn comment says the pivot belongs.
func _build_arena(rig, id: StringName) -> Node3D:
	var script := load("res://scripts/world/boss_arena.gd") as GDScript
	var arena := script.new() as Node3D
	arena.name = "MinibossArena_%s" % id
	arena.set(&"boss_id", id)
	# `&""`, not the default `&"boss"`. Without it a spent miniboss chamber puts
	# the floor's BOSS relic on the floor behind an optional puzzle -- which is
	# the case `boss_arena.gd`'s own export comment was written for.
	arena.set(&"relic_slot", &"")
	arena.set(&"boss_offset", Vector3(0.0, 0.0, -WATCH_DIST * 0.5))
	rig.scene().add_child(arena)
	return arena


## One tell, photographed at the frame it is readable, with the pose and the
## floor mark asserted as well as shot -- "the two beats look different" is a
## claim about pixels, and a `pose` StringName is only an input to it.
func _tell(rig, arena: Node3D, boss: Node, id: StringName, b: Dictionary,
		tag: String, path: String, shapes: Dictionary) -> void:
	var bid: StringName = b["id"]
	var tell: Dictionary = b["tell"]
	var total := maxf(float(tell["time"]), 0.001)
	Game.heal(999)
	# Queued FIRST, while the boss may still be finishing whatever it rolled for
	# itself, then both bodies put back on the mark. A director that positioned
	# first would be positioning into a wind-up that had already started.
	boss.force_beat(bid)
	await _mark_up(rig, arena, boss)
	var arrived := await _until(rig, func() -> bool:
		return boss.current_beat() == bid and boss.state == Enemy.State.WINDUP, 600)
	if not arrived:
		_ck("%s the boss threw %s" % [tag, bid], false)
		return
	# Back on the mark: `_tick_chase` closes to `ROAM_RING` (3.8 m) before it
	# begins a beat, so without this every frame is taken from inside the arm.
	_park_boss(arena, boss)
	# MEASURED off the fight's own countdown, never counted in frames: this
	# harness renders at about 22 fps and a frame count here would be measuring
	# the machine.
	await _until(rig, func() -> bool:
		return boss.state != Enemy.State.WINDUP \
			or boss._timer <= total * (1.0 - TELL_SHOT_AT), 240)
	var through := 1.0 - clampf(float(boss._timer) / total, 0.0, 1.0)
	# Annotated, every one of them: `boss` is untyped here (the class is loaded by
	# path, never named), so `boss._model.scale.y` comes back `Variant` and an
	# inferred `:=` is the "Cannot infer the type of X" parse error the trap table
	# in `CLAUDE.md` §3 lists for indexing an untyped const Dictionary. Same cause,
	# different door in.
	var model: Node3D = boss._model
	var lean: float = model.rotation.x
	var roll: float = model.rotation.z
	var tall: float = model.scale.y
	var wide: float = model.scale.x
	# The marker HANDLE, not a node lookup by name: `_clear_marker` queue_frees
	# the last one and a freed-but-not-yet-removed sibling makes Godot rename the
	# replacement, so `get_node("Mark")` finds the corpse or nothing.
	var mark: Node3D = boss._marker
	print("MB   tell %s: pose=%s %.0f%% through, rx=%.2f rz=%.2f sy=%.2f sx=%.2f, mark=%s"
		% [bid, tell["pose"], through * 100.0, lean, roll, tall, wide,
			mark.name if mark != null else "none"])
	_ck("%s the %s tell is on screen and still winding up" % [tag, bid],
		boss.state == Enemy.State.WINDUP and through > 0.45)
	# A pose that moved nothing is a tell nobody can read. SPREAD moves X and Z
	# scale and NOTHING else, so it has to be in this comparison -- checking only
	# rotation and height would pass a body standing perfectly still.
	_ck("%sp %s holds a pose the rest pose does not" % [tag, bid],
		absf(lean - boss._model_rest.x) > 0.05
		or absf(roll - boss._model_rest.z) > 0.05
		or absf(tall - boss._fit_scale.y) > 0.02
		or absf(wide - boss._fit_scale.x) > 0.02)
	var key := "%.2f|%.2f|%.2f|%.2f" % [lean, roll, tall, wide]
	_ck("%ss and one the fight's other beat does not" % tag, not shapes.has(key))
	shapes[key] = bid

	# The mark has to be the picture its own shape draws (`docs/BOSSES.md` §1):
	# a slam draws its ring inner AND outer so the safe middle is visible, an arc
	# and a charge draw a forward lane, and a zone draws NOTHING during the tell
	# because its discs land where the hero is standing at the commit.
	match b["shape"]:
		BossDb.SHAPE_SLAM:
			var span := _ring_extent(mark) if mark != null else Vector2.ZERO
			print("MB   %s ring drawn %.2f..%.2f m, damage %.2f..%.2f m"
				% [bid, span.x, span.y, float(b["safe_inner"]), float(b["radius"])])
			_ck("%sr and the ring is drawn where the damage is" % tag,
				mark != null and absf(span.x - float(b["safe_inner"])) < 0.3
				and absf(span.y - float(b["radius"])) < 0.3)
		BossDb.SHAPE_ARC:
			# The cone, not a box round it -- board card 21. Measured off the mesh
			# and compared with the row, because "a mark is present" is what this
			# line used to claim and an 8.4 m rectangle satisfied it.
			var fan := _fan_extent(mark) if mark != null else Vector2.ZERO
			print("MB   %s fan drawn %.1f deg to %.2f m, damage %.1f deg to %.2f m"
				% [bid, fan.x, fan.y, float(b["arc_deg"]), float(b["reach"])])
			_ck("%sr and the cone is drawn where the damage is" % tag,
				mark != null and String(mark.name).begins_with("Fan")
				and absf(fan.x - float(b["arc_deg"])) < 3.0
				and absf(fan.y - float(b["reach"])) < 0.15)
		BossDb.SHAPE_CHARGE:
			_ck("%sr and a lane is drawn in front of it" % tag,
				mark != null and String(mark.name).begins_with("Lane"))
		_:
			_ck("%sr and a zone draws nothing until the commit" % tag, mark == null)
	await rig.capture(path)

	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 600)
	var window := float(_punish.get("%s/%s" % [id, bid], -1.0))
	print("MB   window %s: authored %.2f s, measured %.2f s"
		% [bid, float(b["punish"]), window])
	_ck("%sw and it held its %.2f s window open (measured %.2f s)"
		% [tag, float(b["punish"]), window],
		absf(window - float(b["punish"])) < 0.15)


## It dies, and it leaves nothing behind but the chest that is not in this
## fixture.
func _kill(rig, arena: Node3D, boss: Node, id: StringName, n: int,
		authored: int) -> void:
	var before := _defeated
	var start_q: int = boss.health.quarters
	_ck("F%d.0 it comes to the kill on the row's %d q (%d)" % [n, authored, start_q],
		start_q == authored)
	var hero := _hero(rig)
	var swings := 0
	var tries := 0
	while boss.health.quarters > 0 and tries < 40:
		tries += 1
		if boss.health.apply_hit(Hit.make(SWING, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		if boss.health.quarters == 0:
			break
		# The hero is standing in a live fight for as long as this takes, and
		# killing him would end the run in the middle of a measurement.
		Game.heal(999)
		await rig.wait_seconds(K.ENEMY_IFRAME_TIME + 0.06)
	print("MB   killed with %d landed blows of %d q (%d q, %d expected)"
		% [swings, SWING, start_q, ceili(start_q / float(SWING))])
	_ck("F%d.1 it dies (%d blows)" % [n, swings],
		is_instance_valid(boss) and boss.health.quarters == 0)
	await rig.wait_seconds(1.2)
	_ck("F%d.2 Bus.boss_defeated fired once for it (%d)" % [n, _defeated - before],
		_defeated - before == 1)
	_ck("F%d.3 the arena is spent and the seal came down" % n,
		bool(arena.call(&"is_spent")) and not bool(arena.call(&"is_sealed")))
	# §7's whole reason for the empty `drop` row: nothing on the floor, and
	# nothing in the item list either. `Boss._drop_loot` reads both keys, and a
	# non-empty one would be a verb or a relic handed out behind an OPTIONAL
	# puzzle -- the thing the miniboss branch is defined by not doing.
	var motes := _motes(rig.scene())
	print("MB   %d mote(s) anywhere in the scene after the kill" % motes.size())
	_ck("F%d.4 it left no relic and no item (%s)" % [n, motes], motes.is_empty())
	await rig.capture(out.path_join("m%d_9_%s_down.png" % [n, id]))
	arena.queue_free()
	await rig.wait_frames(10)


# --- Helpers ------------------------------------------------------------------

func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return null if players.is_empty() else players[0] as Node3D


## Stand the hero somewhere, facing something, with the boom asked to recentre.
##
## `facing_yaw` as well as `rotation.y`: the hero turns toward his own heading
## every frame, so setting only the node is undone before the shutter opens
## (`docs/CONTRACT.md` §2.5 -- facing is measured, not derived). The `+ PI` is
## the same contract read from the other side.
func _stand_at(rig, at: Vector3, look_at: Vector3) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = at
	var to := K.flat(look_at - at)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(14)


## Put the boss back on its half of the mark. `-basis.z` is forward, so a body
## looking down `+Z` -- at the hero's half -- has `rotation.y = PI`. The
## art-space 180 is NOT this rotation and must not be folded into it: that one
## lives on the model node (`CLAUDE.md` §4).
func _park_boss(arena: Node3D, boss: Node, z: float = -WATCH_DIST * 0.5) -> void:
	var body := boss as Node3D
	var at := arena.global_position + Vector3(0.0, 0.0, z)
	at.y = body.global_position.y
	body.global_position = at
	body.rotation.y = PI


## The cold portrait: the body pulled to the near side of the ring and the hero
## kept `WATCH_DIST` behind it but OUTSIDE the trigger, so the pair are framed
## exactly as they are during a fight and nothing has woken up.
##
## `PORTRAIT_Z` is what buys that. `BossArena` shuts the room when the player
## crosses `TRIGGER_FRACTION` (0.82) of the radius, and the smallest of the four
## rings is 7.5 m -- so the camera mark at 10 m is outside every one of them,
## and pulling the boss forward to +3 m is what keeps the lens length the same
## as the fight frames rather than photographing it across the whole chamber.
func _portrait(rig, arena: Node3D, boss: Node) -> void:
	_park_boss(arena, boss, PORTRAIT_Z)
	var stood := (boss as Node3D).global_position
	var a := deg_to_rad(PORTRAIT_YAW)
	var at := stood + Vector3(sin(a), 0.0, cos(a)) * WATCH_DIST
	at.y = arena.global_position.y + 0.05
	await _stand_at(rig, at, stood)


## Both bodies on the mark, facing each other, camera given time to arrive.
## Staged rather than followed: the boss closes to `ROAM_RING` between beats, so
## a director that placed only the hero would walk the pair down the room and
## photograph the second fight through a doorway.
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


## The inner and outer radius a slam's floor mark actually covers.
##
## Two builds, because `_ring_marker` has two: a `safe_inner` of 0 is ONE
## cylinder (a solid disc -- there is no safe middle to draw), and anything else
## is twenty-eight boxes laid tangentially round a circle. Measured off the mesh
## rather than read back off the beat, so this says what is on the floor and not
## what the table asked for. Unaffected by the grow tween, which scales the
## marker ROOT and leaves the children where they were authored.
func _ring_extent(mark: Node3D) -> Vector2:
	var lo := INF
	var hi := 0.0
	for c in mark.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var cyl := mi.mesh as CylinderMesh
		if cyl != null:
			return Vector2(0.0, cyl.top_radius)
		var box := mi.mesh as BoxMesh
		if box == null:
			continue
		var half: Vector3 = box.size * 0.5
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p: Vector3 = mi.position \
					+ mi.transform.basis * Vector3(half.x * sx, 0.0, half.z * sz)
				var d := Vector2(p.x, p.z).length()
				lo = minf(lo, d)
				hi = maxf(hi, d)
	return Vector2(lo, hi)


## The half-angle in DEGREES and the radius in metres an arc's floor mark
## actually covers, read off the sector's own vertices. `Boss._fan_marker` builds
## one `ArrayMesh` triangle fan whose apex sits on the boss, so the widest vertex
## bearing off `-Z` is the drawn half-angle and the longest is the drawn reach.
##
## Off the MESH and never off the row: the row is what the mark is supposed to
## say, and the whole of board card 21 was a mark that said something else.
## Unaffected by the grow tween, which scales the marker ROOT.
func _fan_extent(mark: Node3D) -> Vector2:
	var wide := 0.0
	var far := 0.0
	for c in mark.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var r := Vector2(v.x, v.z).length()
			if r < 0.001:
				continue
			far = maxf(far, r)
			# `atan2(-x, -z)`, so that the fan's own `(-sin a, 0, -cos a)` reads
			# back as `a` -- the bearing off the forward the damage measures from.
			wide = maxf(wide, absf(atan2(-v.x, -v.z)))
	return Vector2(rad_to_deg(wide), far)


func _motes(root: Node) -> Array[StringName]:
	var found: Array[StringName] = []
	for n in _all(root):
		if n is LootMote:
			found.append((n as LootMote).item_id)
	return found


func _all(root: Node) -> Array:
	var found: Array = [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
